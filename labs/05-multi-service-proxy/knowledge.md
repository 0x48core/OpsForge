# Lab 05 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

A server has one public IP and one port 443, but you want many services on it: an API, Git, monitoring, dashboards. A reverse proxy in front receives every request and sends it to the right container, **by hostname**. It also handles HTTPS for all of them in one place.

In lab 02 you wrote an Nginx config by hand for each site. With containers that come and go, that gets tedious. **Traefik** watches Docker and configures itself from **labels** on each container. You add a service, and its route appears.

## Core concepts

### Traefik's building blocks

```
Request ──▶ ENTRYPOINT ──▶ ROUTER ──▶ MIDDLEWARES ──▶ SERVICE ──▶ container
            :80, :443      matches     auth, redirect,   load balancer
                           Host(...)   headers…          to the server(s)
```

| Piece | What it does | In this lab |
|---|---|---|
| **Entry point** | A port Traefik listens on | `web` (:80), `websecure` (:443) |
| **Router** | A rule that matches requests | `Host(\`api.opsforge.localhost\`)` |
| **Middleware** | Changes the request or response on the way | basic auth, HTTP→HTTPS redirect |
| **Service** | Where matched requests go, load-balanced across servers | hello-api container, port 8000 |
| **Provider** | Where Traefik gets its config from | Docker labels, and files in `dynamic/` |

Compare with Nginx: an entry point is like `listen`, a router like `server_name` + `location`, a service like `proxy_pass` or `upstream`, and middlewares like directives such as `auth_basic` or `return 301`.

### Static vs dynamic configuration

| | Static | Dynamic |
|---|---|---|
| What | Entry points, providers, logging, API | Routers, services, middlewares, TLS certificates |
| Where | `traefik.yml` (or command-line flags) | Docker labels, files in `dynamic/` |
| Changes | Need a **restart** | Reload **live** |

Mixing these up is the most common Traefik mistake: putting a router in `traefik.yml` does nothing.

### Docker labels as configuration

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.whoami.rule=Host(`whoami.opsforge.localhost`)
  - traefik.http.routers.whoami.entrypoints=websecure
  - traefik.http.services.whoami.loadbalancer.server.port=80
```

- Labels are key/value metadata on a container. Traefik reads them through the **Docker socket**.
- **`exposedByDefault: false`** means Traefik ignores containers unless they have `traefik.enable=true`, so you don't expose a database by accident.
- If a container exposes exactly one port, Traefik detects it. Otherwise, set `loadbalancer.server.port`.
- The `@docker`, `@file`, and `@internal` suffixes say which provider defined something (`dashboard-auth@file`, `api@internal`).
- **Typos fail silently**: the router simply doesn't appear. The dashboard is your best debugging tool.

### The Docker socket

`/var/run/docker.sock` is the API of the Docker daemon. Whoever can talk to it can start a container with the host filesystem mounted, which is **effectively root on the host**. Mounting it read-only (`:ro`) prevents writes to the socket *file*, but API calls still work. Ways to harden:

- Keep Traefik up to date, and don't expose its dashboard without auth.
- Use a **socket proxy** (e.g. `tecnativa/docker-socket-proxy`) that only allows read-only API calls.

### Shared networks

- Each Compose project gets its own default network, and containers on different networks can't talk.
- Traefik must reach every web container, so they all join one **external** network, `proxy`.
- Databases stay **only** on their project's default network, so Traefik and other stacks can't reach them.
- `providers.docker.network: proxy` tells Traefik which network's IP to use when a container is on several networks.

### Name-based virtual hosting and SNI

- **HTTP:** the router reads the `Host` header (as with Nginx's `server_name` in lab 02).
- **HTTPS:** the certificate is chosen *before* any HTTP header is sent. The client names the host it wants in the TLS handshake. This is **SNI (Server Name Indication)**, and it's how one IP serves certificates for many domains.

### `*.localhost`

RFC 6761 reserves `localhost` and every name under it for the local machine. Chrome, Firefox, and curl resolve `anything.localhost` to `127.0.0.1` without DNS or `/etc/hosts`. That makes it perfect for local multi-domain testing.

### Certificates in this lab

| Stage | Certificate | Trusted? |
|---|---|---|
| Default | `TRAEFIK DEFAULT CERT`, self-signed and generated at startup | ❌ browser warning, `curl` needs `-k` |
| Local | mkcert wildcard `*.opsforge.localhost` | ✅ on your Mac only |
| VPS | Let's Encrypt via Traefik's ACME resolver | ✅ everywhere, renewed automatically |

A **wildcard certificate** (`*.opsforge.localhost`) covers one level of subdomain: `api.opsforge.localhost` yes, `a.b.opsforge.localhost` no.

**ACME challenges** (how Let's Encrypt checks you own a domain):
- **HTTP-01**: serves a token on port 80. Simple, but no wildcards.
- **DNS-01**: creates a TXT record through your DNS provider's API. Needed for wildcards, and works for servers that aren't public.
- **TLS-ALPN-01**: answers on port 443.

### Forwarded headers

The backend sees Traefik as its client, so Traefik passes the original details along:

| Header | Value |
|---|---|
| `X-Forwarded-For` | Client IP (a list, if there are several proxies) |
| `X-Real-Ip` | Client IP |
| `X-Forwarded-Proto` | `https` |
| `X-Forwarded-Host` | The original `Host` |
| `X-Forwarded-Port` | `443` |

`whoami` prints them all, so it's the quickest way to see what a proxy does to a request.

### Compose override files

`docker compose -f compose.yaml -f compose.traefik.yaml up` **merges** the files left to right: maps are merged, and later values win. Some fields, such as `ports`, are *added together*, so `!reset []` is needed to remove what the base file defined. This keeps one base stack usable both standalone (lab 04) and behind Traefik (lab 05).

## Key terms

| Term | Meaning |
|---|---|
| Entry point | A listening port in Traefik |
| Router | A rule that matches requests (Host, Path…) and sends them to a service |
| Middleware | A request/response transformation (auth, redirect, headers, rate limit) |
| Provider | A source of dynamic configuration (Docker, file, Kubernetes…) |
| SNI | Hostname sent in the TLS handshake so the server picks the right certificate |
| Wildcard certificate | A certificate for `*.domain`, one level deep |
| ACME | The protocol Let's Encrypt uses to issue certificates automatically |
| External network | A Docker network created outside any one Compose project |

## Commands to know

| Command | What it does |
|---|---|
| `docker network create proxy` / `docker network inspect proxy` | Create / inspect the shared network (who's attached) |
| `docker compose -f a.yaml -f b.yaml config` | Show the merged result of override files |
| `docker logs -f traefik-traefik-1` | Access log and errors |
| `curl -sk -u admin https://traefik.opsforge.localhost/api/http/routers` | Routers as JSON from the API |
| `curl -v --resolve api.opsforge.localhost:443:127.0.0.1 https://api.opsforge.localhost/` | Test a hostname against a specific IP |
| `openssl s_client -connect 127.0.0.1:443 -servername <host>` | See which certificate is served for a name (SNI) |
| `htpasswd -nB <user>` | Create a bcrypt basic-auth entry |
| `mkcert -install` / `mkcert <names>` | Install the local CA / create a certificate |

## Before you start, can you answer these?

1. What are the roles of an entry point, a router, a middleware, and a service?
2. Which goes in `traefik.yml`, and which in labels? Why does it matter?
3. Why do all web stacks share the `proxy` network, while databases don't?
4. How does Traefik know which certificate to present when one IP serves many hostnames?
5. Why is mounting the Docker socket into a container a security concern?

## After the lab, check yourself

1. Draw the path of a request to `https://api.opsforge.localhost/visits`, naming each Traefik component and network.
2. What did `whoami` show for `RemoteAddr` vs `X-Real-Ip`, and why do they differ?
3. Stopping hello-api gave a 404, not a 502 like Nginx. Why?
4. What did `ports: !reset []` do, and how would you check the merged config?
5. What would you change in `traefik.yml` and the labels to move this setup to a VPS with Let's Encrypt?
6. Why would a typo in a label not produce an error, and how do you find it?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Traefik: concepts overview](https://doc.traefik.io/traefik/getting-started/concepts/)
- [Traefik: configuration discovery](https://doc.traefik.io/traefik/providers/overview/)
- [Traefik: ACME / Let's Encrypt](https://doc.traefik.io/traefik/https/acme/)
- [Let's Encrypt: challenge types](https://letsencrypt.org/docs/challenge-types/)
- [RFC 6761: special-use domain names](https://www.rfc-editor.org/rfc/rfc6761)
- [Docker socket security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
