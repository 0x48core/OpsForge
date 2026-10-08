# hello-api

A tiny JSON HTTP app used as the deploy target across OpsForge labs. Go standard library only, built as a single static binary.

| Endpoint | Returns |
|---|---|
| `GET /` | app name, version, hostname, time, client IP |
| `GET /health` | `{"status":"ok"}` |

It shuts down gracefully on `SIGTERM`, so in-flight requests finish when systemd or Docker stops it.

## Run locally

```bash
make run
curl localhost:8000/health
```

Config via environment: `HOST` (default `127.0.0.1`), `PORT` (default `8000`). The version is set at build time from `git describe`.

## Build for a server

```bash
make build-linux              # linux/arm64 → bin/hello-api-linux-arm64 (Multipass on Apple Silicon)
make build-linux ARCH=amd64   # linux/amd64 → most VPSs
```

## Used in

- [Lab 02](../../labs/02-nginx-ssl-reverse-proxy/): runs as a `systemd` service ([hello-api.service](hello-api.service)) behind Nginx
- Lab 04: gets a multi-stage Dockerfile
