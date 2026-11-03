# Listen on IPv4 when the kernel has no IPv6

## Problem

On a host with IPv6 disabled in the kernel (`ipv6.disable=1`):
- desktop: "Link a mobile" shows the error "thread blocked indefinitely in an STM transaction";
- SMP, XFTP and notification servers do not start: "Address family not supported by protocol".

## Cause

`startTCPServer` resolves the listening address and opens a socket for the IPv6 address whenever one is resolved. For the wildcard address, `::` is resolved also when the kernel has no IPv6, and `socket(AF_INET6)` fails with `EAFNOSUPPORT`.

## Fix

`startTCPServer` opens the IPv6 socket first. When that fails with `EAFNOSUPPORT` and an IPv4 address was resolved, it opens the IPv4 socket instead. Other errors are rethrown.

## Scope

TCP listeners that use `startTCPServer`:
- SMP, XFTP and notification servers (wildcard address);
- the remote control TLS server of the desktop (wildcard address);
- `runLocalTCPServer` (`127.0.0.1`, IPv4 only, unchanged).

Unchanged: the static site server (Warp) and the remote control discovery listener (UDP, IPv4).
