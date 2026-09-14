#include "KM16ProcessSupport.h"
#include <spawn.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <crt_externs.h>

/* Set a process group atomically at spawn, avoiding a parent/exec setpgid race. */
int km16_spawn_group(const char *executable, char *const argv[], const char *directory, int output_fd, pid_t *child) {
    posix_spawnattr_t attributes;
    posix_spawn_file_actions_t actions;
    int result = posix_spawnattr_init(&attributes);
    if (result) return result;
    result = posix_spawn_file_actions_init(&actions);
    if (result) { posix_spawnattr_destroy(&attributes); return result; }
    sigset_t mask, defaults;
    sigemptyset(&mask);
    sigemptyset(&defaults);
    sigaddset(&defaults, SIGTERM);
    sigaddset(&defaults, SIGINT);
    sigaddset(&defaults, SIGPIPE);
    if (!(result = posix_spawnattr_setpgroup(&attributes, 0)) &&
        !(result = posix_spawnattr_setsigmask(&attributes, &mask)) &&
        !(result = posix_spawnattr_setsigdefault(&attributes, &defaults)) &&
        /* Child commands receive only descriptors explicitly installed below. */
        !(result = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT)) &&
        !(result = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)) &&
        !(result = posix_spawn_file_actions_adddup2(&actions, output_fd, STDOUT_FILENO)) &&
        !(result = posix_spawn_file_actions_adddup2(&actions, output_fd, STDERR_FILENO))) {
        if (directory) result = posix_spawn_file_actions_addchdir_np(&actions, directory);
        if (!result) result = posix_spawn(child, executable, &actions, &attributes, argv, *_NSGetEnviron());
    }
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attributes);
    return result;
}
