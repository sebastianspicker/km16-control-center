// Targeted, non-exclusive input capture. No output/feature report writes.
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_REPORT_BYTES 65536
#define MAX_CAPTURE_BYTES (8ULL * 1024ULL * 1024ULL)
#define MAX_CAPTURE_REPORTS 20000UL

enum capture_failure {
    CAPTURE_OK,
    CAPTURE_REPORT_LIMIT,
    CAPTURE_BYTE_LIMIT,
    CAPTURE_INPUT_ERROR,
    CAPTURE_INVALID_REPORT,
    CAPTURE_OUTPUT_ERROR,
};

static volatile sig_atomic_t stopped;
static unsigned long reports;
static uint64_t payload_bytes;
static enum capture_failure failure;
static uint32_t failure_code;
static CFIndex invalid_length;

#ifndef HID_CAPTURE_UNIT_TEST
static void interrupt_handler(int sig) { (void)sig; stopped = 1; }
#endif
static void fail_capture(enum capture_failure reason, uint32_t code) {
    if (failure == CAPTURE_OK) {
        failure = reason;
        failure_code = code;
    }
    stopped = 1;
}
static enum capture_failure report_rejection(const uint8_t *data, CFIndex len) {
    if (len < 0 || len > MAX_REPORT_BYTES || (len > 0 && data == NULL))
        return CAPTURE_INVALID_REPORT;
    if (reports >= MAX_CAPTURE_REPORTS)
        return CAPTURE_REPORT_LIMIT;
    if (payload_bytes >= MAX_CAPTURE_BYTES ||
        (uint64_t)len > MAX_CAPTURE_BYTES - payload_bytes)
        return CAPTURE_BYTE_LIMIT;
    return CAPTURE_OK;
}
static void record_report(CFIndex len) {
    reports++;
    payload_bytes += (uint64_t)len;
    if (reports >= MAX_CAPTURE_REPORTS)
        fail_capture(CAPTURE_REPORT_LIMIT, 0);
    else if (payload_bytes >= MAX_CAPTURE_BYTES)
        fail_capture(CAPTURE_BYTE_LIMIT, 0);
}
#ifndef HID_CAPTURE_UNIT_TEST
static long number(const char *s, int base, long max) {
    char *end = NULL;
    errno = 0;
    long n = strtol(s, &end, base);
    if (errno || end == s || *end || n < 0 || n > max) {
        fprintf(stderr, "Invalid numeric argument: %s\n", s);
        exit(2);
    }
    return n;
}
static void match_number(CFMutableDictionaryRef d, CFStringRef key, int value) {
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &value);
    CFDictionarySetValue(d, key, n);
    CFRelease(n);
}
#endif
static void input(void *context, IOReturn result, void *sender,
                  IOHIDReportType type, uint32_t id, uint8_t *data, CFIndex len) {
    (void)context; (void)sender;
    if (stopped)
        return;
    if (result != kIOReturnSuccess) {
        fail_capture(CAPTURE_INPUT_ERROR, (uint32_t)result);
        return;
    }
    enum capture_failure rejection = report_rejection(data, len);
    if (rejection != CAPTURE_OK) {
        invalid_length = len;
        fail_capture(rejection, 0);
        return;
    }
    struct timespec now;
    if (clock_gettime(CLOCK_REALTIME, &now) != 0) {
        fail_capture(CAPTURE_OUTPUT_ERROR, (uint32_t)errno);
        return;
    }
    size_t capacity = (size_t)len * 2 + 192;
    char *line = malloc(capacity);
    if (line == NULL) {
        fail_capture(CAPTURE_OUTPUT_ERROR, ENOMEM);
        return;
    }
    int header = snprintf(line, capacity,
        "{\"unix_ns\":\"%lld%09ld\",\"type\":%d,\"report_id\":%u,\"hex\":\"",
        (long long)now.tv_sec, now.tv_nsec, type, id);
    if (header < 0 || (size_t)header >= capacity) {
        free(line);
        fail_capture(CAPTURE_OUTPUT_ERROR, EIO);
        return;
    }
    static const char hex[] = "0123456789abcdef";
    size_t pos = (size_t)header;
    for (CFIndex i = 0; i < len; i++) {
        line[pos++] = hex[data[i] >> 4];
        line[pos++] = hex[data[i] & 0x0f];
    }
    memcpy(line + pos, "\"}\n", 3);
    pos += 3;
    if (fwrite(line, 1, pos, stdout) != pos || fflush(stdout) == EOF) {
        uint32_t error_code = (uint32_t)(errno ? errno : EIO);
        free(line);
        fail_capture(CAPTURE_OUTPUT_ERROR, error_code);
        return;
    }
    free(line);
    record_report(len);
}
#ifndef HID_CAPTURE_UNIT_TEST
int main(int argc, char **argv) {
    if (argc != 6 || !strcmp(argv[1], "--help")) {
        fprintf(stderr, "Usage: %s VID PID USAGE_PAGE USAGE SECONDS\n"
                "IDs are hexadecimal; seconds decimal (1..3600).\n"
                "Example: %s 28e9 3145 ff60 61 30\n"
                "Input reports only; opens one matching interface without seizing it.\n",
                argv[0], argv[0]);
        return argc == 2 && !strcmp(argv[1], "--help") ? 0 : 2;
    }
    int vid = (int)number(argv[1], 16, 65535), pid = (int)number(argv[2], 16, 65535);
    int page = (int)number(argv[3], 16, 65535), usage = (int)number(argv[4], 16, 65535);
    int seconds = (int)number(argv[5], 10, 3600);
    if (!seconds) { fputs("Seconds must be positive.\n", stderr); return 2; }
    IOHIDManagerRef manager = IOHIDManagerCreate(NULL, kIOHIDOptionsTypeNone);
    CFMutableDictionaryRef match = CFDictionaryCreateMutable(NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    match_number(match, CFSTR(kIOHIDVendorIDKey), vid);
    match_number(match, CFSTR(kIOHIDProductIDKey), pid);
    match_number(match, CFSTR(kIOHIDPrimaryUsagePageKey), page);
    match_number(match, CFSTR(kIOHIDPrimaryUsageKey), usage);
    IOHIDManagerSetDeviceMatching(manager, match);
    CFRelease(match);
    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    CFIndex count = devices ? CFSetGetCount(devices) : 0;
    if (count != 1) {
        fprintf(stderr, "Expected exactly one matching interface, found %ld.\n", count);
        if (devices) CFRelease(devices);
        CFRelease(manager);
        return 3;
    }
    IOHIDDeviceRef device = NULL;
    CFSetGetValues(devices, (const void **)&device);
    IOReturn result = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
        fprintf(stderr, "Open failed: 0x%08x. Check connection and macOS device/Input Monitoring access.\n", result);
        CFRelease(devices); CFRelease(manager); return 4;
    }
    uint8_t buffer[MAX_REPORT_BYTES];
    IOHIDDeviceRegisterInputReportCallback(device, buffer, sizeof(buffer), input, NULL);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    signal(SIGINT, interrupt_handler);
    signal(SIGTERM, interrupt_handler);
    fprintf(stderr, "Opened %04x:%04x page=%04x usage=%04x for %ds (non-exclusive).\n",
            vid, pid, page, usage, seconds);
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);
    do {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
        clock_gettime(CLOCK_MONOTONIC, &now);
    } while (!stopped && (now.tv_sec - start.tv_sec + (now.tv_nsec - start.tv_nsec) / 1e9) < seconds);
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    CFRelease(devices); CFRelease(manager);
    if (failure == CAPTURE_REPORT_LIMIT) {
        fprintf(stderr, "Capture stopped: report quota reached (%lu reports); output is partial.\n",
                MAX_CAPTURE_REPORTS);
    } else if (failure == CAPTURE_BYTE_LIMIT) {
        fprintf(stderr, "Capture stopped: payload quota reached (%llu bytes); output is partial.\n",
                (unsigned long long)MAX_CAPTURE_BYTES);
    } else if (failure == CAPTURE_INPUT_ERROR) {
        fprintf(stderr, "Capture failed: input callback error 0x%08x; retained %lu reports.\n",
                failure_code, reports);
    } else if (failure == CAPTURE_INVALID_REPORT) {
        fprintf(stderr, "Capture failed: invalid callback report length %lld; retained %lu reports.\n",
                (long long)invalid_length, reports);
    } else if (failure == CAPTURE_OUTPUT_ERROR) {
        fprintf(stderr, "Capture failed: output error %u (%s); retained %lu reports.\n",
                failure_code, strerror((int)failure_code), reports);
    } else {
        fprintf(stderr, "Capture finished: %lu reports (%llu payload bytes). Zero reports does not prove event delivery.\n",
                reports, (unsigned long long)payload_bytes);
    }
    return failure == CAPTURE_OK ? 0 : 5;
}
#endif
