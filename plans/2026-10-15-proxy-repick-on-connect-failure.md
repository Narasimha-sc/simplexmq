# Agent: choose another proxy when connecting to the chosen proxy fails

## Problem

With private routing, a connection can stay at "connecting…", or a join can fail on every "Retry", until the app restarts. The sending agent chooses one proxy for each destination relay and keeps it. If the connection to that proxy fails (the proxy is offline or unreachable), every retry uses the same proxy. After a restart of the app a proxy is chosen again, and the connection then completes in seconds.

A proxy that is reachable but cannot forward to the destination relay is a separate failure, handled in the next PR of this stack.

## Cause

`smpProxiedRelays` in `Agent/Client.hs` maps the destination session to the chosen proxy. `getSMPProxyClient` reuses the entry when it exists; otherwise it uses the server from `getNextServer`, or the proxy it was given (the #1178 retry after `PROXY NO_SESSION`). The entry is removed when creating the proxied relay session (PRXY) fails with an error other than a host error (`newProxiedRelay`), when the proxy connection is closed (`smpClientDisconnected`), and when the agent is closed.

When the connection to the proxy itself fails, there is no proxy connection to close, so the entry stays. A failed connection's error is kept for `persistErrorInterval` (3 s), then the agent connects again, to the same chosen proxy, until the proxy is reachable again or the app restarts.

## Fix

In `getSMPProxyClient`, delete the choice of the proxy for this destination when getting a connection to the proxy fails, so that a proxy is chosen again on the next attempt. The choice is deleted only while it still contains the proxy that failed, so a late failure of an earlier choice cannot delete a newer choice of another proxy.

A request that only waits for a connection started by another request (e.g. another send via this proxy, or a subscription to the proxy's server) does not delete the choice when its wait times out (`BROKER _ TIMEOUT`, which only a wait produces; a connection's own connect timeout is `BROKER _ NETWORK`). If the connection fails while the request waits, the request gets the connection's error and deletes the choice.

An interactive request waits 15 s for a connection on the first attempt, while a connection started by a subscription or a delivery has a longer timeout. If that connection hangs, the interactive request ends with the wait timeout and the choice is kept; a background proxy request then deletes it. If a subscription started the connection, a proxy request within `persistErrorInterval` gets its error and deletes the choice; a later request connects again and deletes the choice if that connection fails.

The agent connects to a proxy only when it has no open connection to it, and a disconnect already deletes the choices for the destinations it had sessions to. So this proxy normally has not received this destination under the current choice, and choosing again is another random draw: the proxies that receive the destination address are chosen from the same set as with the first choice. This also holds when the client's own network is down: the old connection is dropped and the choice deleted, as before.

A network attacker who blocks the connections to every proxy except one makes the sender choose again until that proxy is chosen; before, the blocked proxy remained the choice until the app restarted. On master the same attacker can already make the sender choose another proxy by allowing the connection to be established and closing it after the PRXY (`smpClientDisconnected` deletes the choice), and then every proxy whose connection was closed has received the destination address. A proxy to which the connection failed has not received the destination address.

Not changed: a host error reported by the proxy about the relay (PRXY) keeps the entry, as before. A host error connecting to the proxy itself deletes the choice.

## Verification

Test (`SMPProxyTests`): "chooses another proxy when the chosen proxy is offline". The agent's server RNG is seeded, and the first choice is set to a proxy nothing listens on; direct sending is prohibited, so the connection completes only through the other proxy. The test fails without the fix: the choice stays and the connection does not complete within 10 s.

The check that the choice still contains the failed proxy and the exemption for wait timeouts are not covered by tests: they need a second connection that fails while another request waits for it.

Desktop and Android results are in the PRs.
