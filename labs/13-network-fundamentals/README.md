# Lab 13 — Network fundamentals

- **Phase:** 6 — Networking
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS (lab 09) and Docker on the Mac
- **Builds on:** Labs 01, 02, 05

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Understand what actually happens on the wire: addresses, routing, TCP, DNS, and TLS, seen with your own packet captures.

## Done when

- [ ] Explain IPv4/IPv6 addressing, CIDR, subnets, and the routing table (`ip addr`, `ip route`) of the fake VPS
- [ ] Capture and annotate a TCP 3-way handshake, a DNS query, and a TLS handshake with `tcpdump` (open them in Wireshark)
- [ ] Trace a request with `dig`, `traceroute`/`mtr`, and `curl -v`, and explain each hop
- [ ] Explain `ss -tlnp` output: listening sockets, states (`ESTABLISHED`, `TIME_WAIT`), and which process owns each
- [ ] Debug three broken setups on purpose: wrong port, firewall drop vs reject, and DNS pointing to the wrong IP

## Steps

## Code

## What broke

## Lessons learned

## References
