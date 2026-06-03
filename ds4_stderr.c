#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>
#include <stdlib.h>

#define DS4_STDERR_NO_REDEFINE
#include "ds4_stderr.h"

FILE *ds4_stderr = NULL;
static bool ds4_stderr_needs_close = false;

static ds4_abort_fn g_abort_fn = NULL;
static void *g_abort_ud = NULL;

static void ds4_stderr_cleanup(void) {
    if (ds4_stderr && ds4_stderr_needs_close) {
        fclose(ds4_stderr);
    }
    ds4_stderr = NULL;
    ds4_stderr_needs_close = false;
}

/* ds4_set_stderr sets a custom FILE pointer.
 * The caller retains ownership of the FILE pointer and is responsible for closing it. */
void ds4_set_stderr(FILE *fp) {
    ds4_stderr_cleanup();
    ds4_stderr = fp;
}

/* ds4_set_stderr_fd creates a FILE pointer from a file descriptor using fdopen.
 * The library dups the provided fd internally and takes ownership of the dup (not the
 * caller's original fd number). It will close the dup (implicitly affecting the underlying
 * open file description) when the stream is reset or closed. The stream is set to be
 * unbuffered (_IONBF) so that logs flush immediately.
 *
 * Pass fd = -1 to reset back to the default stderr.
 *
 * On failure the caller retains their original fd and the global is left unset
 * (falls back to real stderr). The dup ensures that passing e.g. STDERR_FILENO (2)
 * or any fd the caller still needs will not cause the library to close the caller's
 * fd on cleanup/reset. Callers may close their original fd after this call if they
 * no longer need a direct reference. */
void ds4_set_stderr_fd(int fd) {
    ds4_stderr_cleanup();
    if (fd != -1) {
        int dupfd = dup(fd);
        if (dupfd < 0) {
            /* Dup failed (e.g. EMFILE); leave global unchanged. */
            return;
        }
        ds4_stderr = fdopen(dupfd, "w");
        if (ds4_stderr) {
            setvbuf(ds4_stderr, NULL, _IONBF, 0);
            ds4_stderr_needs_close = true;
            /* We own only dupfd; do not close(fd) here. Caller retains their fd
             * (which shares the file description with our dup). */
        } else {
            /* fdopen failed on the dup; close dupfd only. Caller keeps their fd. */
            close(dupfd);
        }
    }
}

/* ds4_abort_set registers a fatal invariant callback.
 * Pass NULL to restore the default (no handler - just exits/aborts). */
void ds4_abort_set(ds4_abort_fn fn, void *ud) {
    g_abort_fn = fn;
    g_abort_ud = ud;
}

void ds4_abort_helper(const char *msg) {
    if (ds4_stderr) {
        fflush(ds4_stderr);
    }
    fflush(stderr);

    if (g_abort_fn) {
        g_abort_fn(g_abort_ud, msg);
    }

    // Default fallback is to call the real abort()
    abort();
}

void ds4_exit_helper(int code) {
    if (ds4_stderr) {
        fflush(ds4_stderr);
    }
    fflush(stderr);

    if (g_abort_fn) {
        g_abort_fn(g_abort_ud, "ds4: process exit requested");
    }

    // Default fallback is to call the real exit()
    exit(code);
}
