# stacks

Docker Compose stacks, one folder per stack (`stacks/<name>/compose.yaml`, plus `.env.example` when it needs config).

| Stack | What | Lab |
|---|---|---|
| [traefik](traefik/) | Reverse proxy and single entry point (ports 80/443) | 05 |
| [hello-api](hello-api/) | hello-api + PostgreSQL + Redis; `compose.traefik.yaml` puts it behind Traefik; `compose.deploy.yaml` + `deploy.sh` run the GHCR image on a server | 04, 05, 07 |
| [whoami](whoami/) | Echoes request headers; for testing the proxy | 05 |
| [gitea](gitea/) | Self-hosted Git server (`git.`), SSH on 2222 | 06 |
| [uptime-kuma](uptime-kuma/) | Uptime monitoring (`status.`) | 06 |
| [portainer](portainer/) | Docker management UI (`portainer.`); read-write Docker socket | 06 |

Web-facing stacks join the shared external `proxy` network (`docker network create proxy`) and are routed by Traefik labels.
