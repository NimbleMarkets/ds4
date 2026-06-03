#ifndef DS4_STDERR_H
#define DS4_STDERR_H

#include <stdio.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void ds4_set_stderr(FILE *fp);
void ds4_set_stderr_fd(int fd);

static inline FILE *ds4_get_stderr_helper(void) {
    extern FILE *ds4_stderr;
    return ds4_stderr ? ds4_stderr : stderr;
}

#ifndef DS4_STDERR_NO_REDEFINE
#undef stderr
#define stderr ds4_get_stderr_helper()
#endif

#ifdef __cplusplus
}
#endif

#endif /* DS4_STDERR_H */
