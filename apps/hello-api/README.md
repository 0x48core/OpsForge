# hello-api

A tiny JSON HTTP app used as the deploy target across OpsForge labs. Written in Go and built as a single static binary. PostgreSQL and Redis are optional.

| Endpoint | Returns |
|---|---|
| `GET /` | app name, version, hostname, time, client IP |
| `GET /health` | liveness: `{"status":"ok"}` when the process is up |
| `GET /ready` | readiness: status of Postgres and Redis; `503` if a configured one is unreachable |
| `GET /visits` | visit count from Redis and total rows from Postgres |
| `POST /visits` | record a visit in both (needs Postgres and Redis) |

It shuts down gracefully on `SIGTERM`, so in-flight requests finish when systemd or Docker stops it.

## Run locally

```bash
make run
curl localhost:8000/health
```

Config via environment:

| Variable | Default | Notes |
|---|---|---|
| `HOST` | `127.0.0.1` | `0.0.0.0` in the container image |
| `PORT` | `8000` | |
| `DATABASE_URL` | unset | e.g. `postgres://user:pass@db:5432/hello?sslmode=disable`; creates the `visits` table on start |
| `REDIS_URL` | unset | e.g. `redis://cache:6379/0` |

The version is set at build time from `git describe`.

`./hello-api healthcheck` exits 0 if `/health` answers. The Docker `HEALTHCHECK` uses it, because the distroless image has no curl.

## Build for a server

```bash
make build-linux              # linux/arm64 → bin/hello-api-linux-arm64 (Multipass on Apple Silicon)
make build-linux ARCH=amd64   # linux/amd64 → most VPSs
make docker-build             # container image hello-api:<version>
```

To run with Postgres and Redis, use the Compose stack in [stacks/hello-api](../../stacks/hello-api/).

## Used in

- [Lab 02](../../labs/02-nginx-ssl-reverse-proxy/): runs as a `systemd` service ([hello-api.service](hello-api.service)) behind Nginx
- [Lab 04](../../labs/04-dockerize-app/): multi-stage [Dockerfile](Dockerfile) (distroless, non-root, ~22 MB) and a Compose stack
