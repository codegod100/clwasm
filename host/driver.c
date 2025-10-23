/* driver.c -- Minimal host program that boots ECL and calls into the Lisp code */

#include <ecl/ecl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#else
#define EMSCRIPTEN_KEEPALIVE
#endif

#include "clwasm-init.h"

static bool g_booted = false;
static char g_result[256];

static int clamp_limit(int value) {
    if (value < 1) {
        return 1;
    }
    if (value > 92) {
        return 92; /* prevent 64-bit overflow in the demo fib */
    }
    return value;
}

static void ensure_boot(int argc, char **argv) {
    if (!g_booted) {
    cl_boot(argc, argv);
        clwasm_register_modules();
        g_booted = true;
    }
}

static const char *run_demo_with_limit(int limit) {
    int clamped = clamp_limit(limit);
    char buffer[128];
    snprintf(buffer, sizeof buffer, "(clwasm:entry-point %d)", clamped);

    cl_object form = c_string_to_object(buffer);
    cl_object result = si_safe_eval(3, form, ECL_NIL, ECL_NIL);

    if (!ECL_BASE_STRING_P(result)) {
        static const char error_message[] = "clwasm:entry-point did not return a base-string";
        strncpy(g_result, error_message, sizeof g_result - 1);
        g_result[sizeof g_result - 1] = '\0';
        return g_result;
    }

    const char *string_result = (const char *)ecl_base_string_pointer_safe(result);
    strncpy(g_result, string_result, sizeof g_result - 1);
    g_result[sizeof g_result - 1] = '\0';
    return g_result;
}

static void shutdown_runtime(void) {
    if (g_booted) {
        cl_shutdown();
        g_booted = false;
    }
}

EMSCRIPTEN_KEEPALIVE
const char *clwasm_entry_string(int limit) {
    if (!g_booted) {
        char *argv[] = { "clwasm", NULL };
        ensure_boot(1, argv);
    }
    return run_demo_with_limit(limit);
}

static int parse_limit(int argc, char **argv) {
    if (argc < 2) {
        return 10;
    }
    return clamp_limit(atoi(argv[1]));
}

int main(int argc, char **argv) {
    ensure_boot(argc, argv);

    int limit = parse_limit(argc, argv);
    const char *result = run_demo_with_limit(limit);

    fputs(result, stdout);

    shutdown_runtime();
    return 0;
}
