# Lab 16 — WireGuard VPN and private access

- **Phase:** 6 — Networking
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Two fake VPS containers; later the real VPS and your Mac
- **Builds on:** Labs 01, 09, 13

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Put admin access behind a private network: a WireGuard tunnel, so SSH, Grafana, and Portainer are never exposed to the internet.

## Done when

- [ ] WireGuard tunnel between two hosts, with keys generated and stored safely
- [ ] Admin services (SSH, Prometheus, Portainer) reachable only over the tunnel
- [ ] The public firewall allows only 80/443 and the WireGuard UDP port
- [ ] Routing between two private subnets through the tunnel (site-to-site)
- [ ] WireGuard set up by an Ansible role (extends lab 09); compare with Tailscale in "Lessons learned"

## Steps

## Code

## What broke

## Lessons learned

## References
