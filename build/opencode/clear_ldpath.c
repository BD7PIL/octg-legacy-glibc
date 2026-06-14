/*
 * clear_ldpath.c — Statically linked LD_PRELOAD shim.
 *
 * When loaded via LD_PRELOAD, the constructor unsets LD_PRELOAD so it does
 * not propagate to child processes.  Compiled as a statically linked .so
 * (musl-gcc -shared -static) so it has zero external dependencies.
 */

#include <stdlib.h>

__attribute__((constructor))
static void clear_preload(void) {
    unsetenv("LD_PRELOAD");
}
