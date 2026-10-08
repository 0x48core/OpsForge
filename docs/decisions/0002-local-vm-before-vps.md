# 0002 — Use a local VM until a VPS is rented

- **Status:** accepted
- **Date:** 2026-10-08

## Context

No VPS is rented yet, but labs 01–03 need a Linux server to practice on.

## Options

1. Wait for the VPS.
2. Docker containers on the Mac: no real systemd, so a poor fit for server labs.
3. A local Ubuntu VM with Multipass: full Ubuntu 24.04, systemd, ufw, and a private IP.

## Decision

Option 3: a Multipass VM named `opsforge` (2 vCPU / 4 GB / 20 GB), using `.test` domains via `/etc/hosts`.

## Consequences

- Labs 01–03 can be done now with the same commands as on a real VPS.
- Anything that needs the public internet is deferred to the VPS: Let's Encrypt certificates, real DNS, the provider firewall, and fail2ban against real attackers.
- Local HTTPS uses mkcert instead of Let's Encrypt.
