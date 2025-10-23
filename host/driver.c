/* driver.c -- Minimal host program that boots ECL and calls into the Lisp code */

#include <ecl/ecl.h>
#include <stdio.h>
#include <stdlib.h>

/* This name is configured in scripts/build.lisp. */
extern void init_clwasm(cl_object);

static int parse_limit(int argc, char **argv) {
    if (argc < 2) {
        return 10;
    }
    int value = atoi(argv[1]);
    if (value < 1) {
        value = 1;
    }
    if (value > 92) {
        value = 92; /* prevent 64-bit overflow in the demo fib */
    }
    return value;
}

int main(int argc, char **argv) {
    cl_boot(argc, argv);

    ecl_init_module(NULL, init_clwasm);

    int limit = parse_limit(argc, argv);
    char buffer[128];
    snprintf(buffer, sizeof buffer, "(clwasm:entry-point %d)", limit);

    cl_object form = c_string_to_object(buffer);
    cl_object result = si_safe_eval(3, form, ECL_NIL, ECL_NIL);

    if (!ECL_BASE_STRING_P(result)) {
        fputs("clwasm:entry-point did not return a base-string\n", stderr);
        cl_shutdown();
        return 1;
    }

    fputs((const char *)ecl_base_string_pointer_safe(result), stdout);

    cl_shutdown();
    return 0;
}
