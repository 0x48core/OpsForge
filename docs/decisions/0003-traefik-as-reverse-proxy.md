# 0003 — Traefik as the reverse proxy for container services

- **Status:** accepted
- **Date:** 2026-10-08

## Context

From lab 05 on, several containerized services run on one server, each on its own subdomain with HTTPS. Lab 02 used Nginx configured by hand; doing that for every new container doesn't scale well.

## Options

| Option | Config | Certificates | Fits containers |
|---|---|---|---|
| **Nginx (hand-written)** | One config file per site | Certbot, separate | Manual: edit config for each new container |
| **Nginx Proxy Manager** | Web UI, state in its own DB | Built in | Good, but config lives in a UI, not in git |
| **Caddy** | `Caddyfile` | Built in, automatic | Good; Docker support via a plugin |
| **Traefik** | Docker labels plus small YAML files | Built in (ACME) | Native: discovers containers automatically |

## Decision

Use **Traefik v3** for container services.

- Routing lives **next to each service** as labels in its `compose.yaml`, so it's in git and reviewed with the service.
- New services need **no proxy config change or restart**.
- Built-in Let's Encrypt, a dashboard, and an access log.
- The same concepts (routers, services, middlewares, entry points) carry over to Kubernetes Ingress in lab 12, where Traefik is K3s's default ingress controller.

## Consequences

- Traefik needs the **Docker socket**, which is root-equivalent. It's mounted read-only, and a socket proxy is an option to harden it later.
- Labels are verbose and typos fail silently (the router just doesn't appear). Check the dashboard after changes.
- Nginx skills from lab 02 still matter: for static sites and non-container apps, Nginx remains a fine choice.
