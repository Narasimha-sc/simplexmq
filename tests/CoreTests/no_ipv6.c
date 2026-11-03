#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <sys/socket.h>

static __thread int ipv6_unsupported = 0;

void set_ipv6_unsupported(int unsupported) {
    ipv6_unsupported = unsupported;
}

int socket(int domain, int type, int protocol) {
    static int (*real_socket)(int, int, int);
    if (ipv6_unsupported && domain == AF_INET6) {
        errno = EAFNOSUPPORT;
        return -1;
    }
    if (!real_socket) real_socket = (int (*)(int, int, int))dlsym(RTLD_NEXT, "socket");
    return real_socket(domain, type, protocol);
}
