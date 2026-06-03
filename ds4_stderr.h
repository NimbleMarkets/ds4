#ifndef DS4_STDERR_H
#define DS4_STDERR_H

#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

void ds4_set_stderr(FILE *fp);
void ds4_set_stderr_fd(int fd);

#ifndef DS4_ABORT_FN_DEFINED
#define DS4_ABORT_FN_DEFINED
typedef void (*ds4_abort_fn)(void *ud, const char *msg);
#endif
void ds4_abort_set(ds4_abort_fn fn, void *ud);

void ds4_abort_helper(const char *msg) __attribute__((noreturn));
void ds4_exit_helper(int code) __attribute__((noreturn));

static inline FILE *ds4_get_stderr_helper(void) {
    extern FILE *ds4_stderr;
    return ds4_stderr ? ds4_stderr : stderr;
}

#ifndef DS4_STDERR_NO_REDEFINE
#undef stderr
#define stderr ds4_get_stderr_helper()

#undef exit
#define exit(code) ds4_exit_helper(code)

#undef abort
#define abort() ds4_abort_helper("ds4: process abort requested")
#endif

#ifdef __cplusplus
}
#endif

#endif /* DS4_STDERR_H */
