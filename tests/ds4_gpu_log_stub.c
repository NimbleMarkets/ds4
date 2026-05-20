/* Standalone ds4_gpu_log() for tests that link ds4_cuda.o (or ds4_metal.o)
 * without the full engine — currently just tests/cuda_long_context_smoke.
 *
 * The real implementation in ds4.c routes diagnostics through the installable
 * log callback (ds4_log_set).  This stub mirrors what the *default* callback
 * would do — write the formatted line directly to stderr — so kernel
 * diagnostics still surface during the smoke test.  The `type` argument is
 * unused: no TTY colorization here, since smoke runs are usually piped. */

#include <stdarg.h>
#include <stdio.h>

void ds4_gpu_log(int type, const char *fmt, ...) {
    (void)type;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
}
