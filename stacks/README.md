# stacks

Docker Compose stacks, one folder per stack (`stacks/<name>/compose.yaml`, plus `.env.example` when it needs config).

| Stack | What | Lab |
|---|---|---|
| [traefik](traefik/) | Reverse proxy and single entry point (ports 80/443) | 05 |
| [hello-api](hello-api/) | hello-api + PostgreSQL + Redis; `compose.traefik.yaml` puts it behind Traefik | 04, 05 |
| [whoami](whoami/) | Echoes request headers; for testing the proxy | 05 |

Web-facing stacks join the shared external `proxy` network (`docker network create proxy`) and are routed by Traefik labels.
