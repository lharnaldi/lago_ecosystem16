#include <stdio.h>
#include "extras.h"

void suggest(const char *prog) {
	fprintf(stderr, "Try '%s -h' for more information.\n", prog);
}
void requires(const char *prog, const char *arg) {
	fprintf(stderr, "%s: option \"-%s\" requires an argument\n", prog, arg);
	suggest(prog);
}
void requirespar(const char *prog, const char *arg) {
	fprintf(stderr, "%s: option \"%s\" requires an argument\n", prog, arg);
	suggest(prog);
}
void requiresval(const char *prog, const char *arg) {
	fprintf(stderr, "%s: option \"%s\" requires a value\n", prog, arg);
	suggest(prog);
}
void missing(const char *prog, const char *arg) {
	fprintf(stderr, "%s: missing option \"-%s\"\n", prog, arg);
	suggest(prog);
}
void missingval(const char *prog) {
        fprintf(stderr, "%s: missing value to write\n", prog);
        suggest(prog);
}
void invalid(const char *prog, char arg) {
	fprintf(stderr, "%s: invalid option \"-%c\"\n", prog, arg);
	suggest(prog);
}
void unexpected(const char *prog, const char *arg) {
	fprintf(stderr, "%s: unexpected option \"%s\"\n", prog, arg);
	suggest(prog);
}
