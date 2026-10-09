# Lab 14 — Container networking by hand

- **Phase:** 6 — Networking
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS (privileged container)
- **Builds on:** Labs 04, 05, 13

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Build container networking yourself with network namespaces, veth pairs, a bridge, and NAT, then recognise exactly what Docker and Kubernetes do.

## Done when

- [ ] Two network namespaces talk to each other through a veth pair
- [ ] Several namespaces share a Linux bridge and reach the internet through NAT (nftables)
- [ ] A port on the host is forwarded into a namespace (DNAT), like `docker run -p`
- [ ] Explain from the nftables/iptables rules why Docker-published ports bypass ufw (labs 01, 04)
- [ ] Find the rules kube-proxy creates for a Kubernetes Service in the k3d cluster (lab 12)

## Steps

## Code

## What broke

## Lessons learned

## References
