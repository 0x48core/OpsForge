# Lab 15 — DNS deep dive

- **Phase:** 6 — Networking
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker on the Mac
- **Builds on:** Labs 10, 13

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Run your own DNS: a caching resolver and an authoritative server for a zone, and understand caching, TTLs, and delegation.

## Done when

- [ ] Explain recursive vs authoritative DNS, and follow a lookup with `dig +trace`
- [ ] Run a caching resolver (Unbound) and measure the cache with repeated queries
- [ ] Serve your own zone (CoreDNS or Knot) with A, AAAA, CNAME, MX, TXT, and a wildcard
- [ ] Show TTL effects: change a record and observe old answers until the TTL expires
- [ ] Split-horizon DNS: internal clients get a private IP, external clients the public one

## Steps

## Code

## What broke

## Lessons learned

## References
