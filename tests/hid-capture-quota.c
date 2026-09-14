#define HID_CAPTURE_UNIT_TEST
#include "../scripts/capture/hid-capture.c"

#include <assert.h>

static void reset_state(void) {
    stopped = 0;
    reports = 0;
    payload_bytes = 0;
    failure = CAPTURE_OK;
    failure_code = 0;
    invalid_length = 0;
}

int main(void) {
    uint8_t byte = 0;

    reset_state();
    assert(report_rejection(&byte, -1) == CAPTURE_INVALID_REPORT);
    assert(report_rejection(&byte, MAX_REPORT_BYTES + 1) == CAPTURE_INVALID_REPORT);
    assert(report_rejection(NULL, 1) == CAPTURE_INVALID_REPORT);
    assert(report_rejection(NULL, 0) == CAPTURE_OK);

    reset_state();
    input(NULL, kIOReturnError, NULL, kIOHIDReportTypeInput, 0, &byte, 1);
    assert(stopped == 1);
    assert(failure == CAPTURE_INPUT_ERROR);
    input(NULL, kIOReturnSuccess, NULL, kIOHIDReportTypeInput, 0, NULL, 1);
    assert(failure == CAPTURE_INPUT_ERROR);
    assert(reports == 0);

    reset_state();
    input(NULL, kIOReturnSuccess, NULL, kIOHIDReportTypeInput, 0, NULL, 1);
    assert(stopped == 1);
    assert(failure == CAPTURE_INVALID_REPORT);
    assert(invalid_length == 1);

    reset_state();
    reports = MAX_CAPTURE_REPORTS - 1;
    assert(report_rejection(&byte, 1) == CAPTURE_OK);
    record_report(1);
    assert(stopped == 1);
    assert(failure == CAPTURE_REPORT_LIMIT);
    assert(reports == MAX_CAPTURE_REPORTS);

    reset_state();
    payload_bytes = MAX_CAPTURE_BYTES - 1;
    assert(report_rejection(&byte, 2) == CAPTURE_BYTE_LIMIT);
    assert(report_rejection(&byte, 1) == CAPTURE_OK);
    record_report(1);
    assert(stopped == 1);
    assert(failure == CAPTURE_BYTE_LIMIT);
    assert(payload_bytes == MAX_CAPTURE_BYTES);

    reset_state();
    fail_capture(CAPTURE_INPUT_ERROR, 0x1234);
    fail_capture(CAPTURE_INPUT_ERROR, 0x5678);
    assert(failure == CAPTURE_INPUT_ERROR);
    assert(failure_code == 0x1234);
    return 0;
}
