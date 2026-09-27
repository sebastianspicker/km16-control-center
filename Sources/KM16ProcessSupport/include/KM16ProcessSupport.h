#ifndef KM16_PROCESS_SUPPORT_H
#define KM16_PROCESS_SUPPORT_H
#include <sys/types.h>
int km16_spawn_group(const char *executable, char *const argv[], const char *directory, int output_fd, pid_t *child);
#endif
