# Lab 06 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Running other people's software is a big part of real ops work: you don't write Gitea or Uptime Kuma, but you deploy, configure, secure, monitor, upgrade, and back them up. Each tool here also teaches something:

| Tool | Teaches |
|---|---|
| **Gitea** | Configuration through environment variables, CLI-driven setup, SSH alongside HTTP |
| **Uptime Kuma** | Monitoring basics: probes, intervals, alerts, and what "up" really means |
| **Portainer** | How much power the Docker socket gives, and how to limit who has it |

## Core concepts

### Self-hosting trade-offs

| You gain | You take on |
|---|---|
| Control over your data, no per-user fees | Updates, security patches |
| Learning how the software really works | Backups and restore tests |
| Customization | Uptime: you're the on-call engineer |

Rule: **don't self-host what you can't back up and restore.** Every tool here keeps its state in a Docker volume, which lab 03 will back up.

### Configuring apps through the environment

- Gitea maps `GITEA__<section>__<KEY>` variables into its `app.ini` on startup. For example, `GITEA__server__ROOT_URL` becomes `[server] ROOT_URL`.
- `INSTALL_LOCK=true` skips the web installer, so the setup is **reproducible**: the same compose file always gives the same server. That's the idea behind Infrastructure as Code (labs 09–10).
- Secrets the app generates itself (Gitea's `SECRET_KEY`, `INTERNAL_TOKEN`) end up in `app.ini` inside the config volume. That volume needs backing up too.

### `ROOT_URL` and running behind a proxy

Apps behind a reverse proxy often need to know their **public** URL, to build links, redirects, clone URLs, and webhooks. Gitea listens on `:3000` over plain HTTP, but users reach it at `https://git.opsforge.localhost/`. If `ROOT_URL` is wrong, you get clone URLs with the wrong host, and redirect loops.

### Git over HTTPS vs SSH

| | HTTPS | SSH |
|---|---|---|
| Port | 443, through Traefik | 2222, published directly |
| Auth | Username + token | SSH key (lab 01's key auth) |
| Proxy | Traefik routes it by `Host` | Traefik's HTTP routers can't. SSH has no `Host` header, so it needs its own port (or a Traefik TCP router) |

The rootless Gitea image runs its **own built-in SSH server** on 2222, separate from any host `sshd`.

### Rootless containers

`gitea/gitea:*-rootless` runs Gitea as an unprivileged user inside the container, unlike the regular image, which starts as root and then drops privileges. Same idea as `USER nonroot` in lab 04: less damage if the app is compromised.

### Monitoring basics

- **Probe:** a check made from the outside: an HTTP request, a TCP connect, ping, DNS lookup, or a keyword in the response.
- **Interval / retries:** how often to check, and how many failures before declaring "down". This trades detection speed against false alarms.
- **What to probe:** a **health endpoint** (`/api/healthz`, `/ready`) tells you more than `/`. hello-api's `/ready` fails when the database is down; `/` wouldn't.
- **Where the probe runs matters:**

| Probe from | Tests | Misses |
|---|---|---|
| The same Docker network (container name) | The app itself | DNS, TLS, Traefik, the firewall |
| Outside (public URL) | The whole path the user takes | Can't tell which layer failed |

  Good setups use both. A monitor on the same server as the app also has a blind spot: if the server dies, so does the monitor. Real setups monitor from somewhere else, too.
- **Black-box vs white-box:** Uptime Kuma checks from the outside (black-box). Prometheus in lab 11 collects metrics from inside (white-box).

### DNS inside containers

- Containers use **Docker's embedded DNS** (`127.0.0.11`), which knows container names and service names on shared networks.
- `*.localhost` working in your browser is a feature of **your Mac's** browser and resolver. Inside a container, `git.opsforge.localhost` gets no answer.
- So service-to-service traffic uses container or service names: `http://gitea-gitea-1:3000`.
- Compose names containers `<project>-<service>-<n>` (e.g. `gitea-gitea-1`).

### The Docker socket, again, and why Portainer is risky

- Traefik mounted the socket **read-only** and only *reads* container labels.
- Portainer mounts it **read-write**, because managing containers is its job. Anyone with Portainer admin can run

  ```
  docker run -v /:/host --privileged …
  ```

  which is root on the host.
- Defenses: don't expose it publicly; put strong auth in front (Traefik middleware, SSO); use an SSH tunnel; or use a read-only tool for viewing (e.g. Dozzle for logs).
- The 5-minute setup timeout exists so a fresh, unconfigured Portainer can't be claimed by a stranger.

### Resource budgeting

On a 2 vCPU / 4 GB VPS, every tool costs RAM. Check `docker stats` and set limits (`mem_limit` / `deploy.resources.limits.memory` in Compose) so one tool can't starve the others. This matters more once the monitoring stack (lab 11) and K3s (lab 12) arrive.

## Key terms

| Term | Meaning |
|---|---|
| `INSTALL_LOCK` | Gitea setting that disables the web installer |
| `ROOT_URL` | The public URL an app uses to build its own links |
| Rootless image | Container whose main process never runs as root |
| Probe / check | A request made to test whether a service is up |
| Health endpoint | A URL designed to report the app's health (`/healthz`, `/ready`) |
| Black-box monitoring | Testing from the outside, like a user |
| Embedded DNS | Docker's DNS server at `127.0.0.11` inside containers |
| SSH tunnel | Forwarding a remote port to your machine over SSH (`ssh -L`) |

## Commands to know

| Command | What it does |
|---|---|
| `docker compose exec gitea gitea admin user create …` | Create a Gitea user from the CLI |
| `docker compose exec gitea gitea admin user list` | List users |
| `git remote add <name> <url>` / `git remote -v` | Add / list remotes |
| `ssh -T -p 2222 git@localhost` | Test SSH auth against Gitea |
| `docker network inspect proxy` | See which containers share the proxy network |
| `docker stats --no-stream` | CPU and RAM per container |
| `docker volume ls` / `docker volume inspect <v>` | Find where each tool keeps its data |
| `ssh -L 9000:localhost:9000 <host>` | Reach a server's port 9000 locally without exposing it |

## Before you start, can you answer these?

1. Why does Gitea need `ROOT_URL` when Traefik already handles the hostname?
2. Why can't Traefik's HTTP routers handle Git over SSH?
3. Why should Uptime Kuma check `http://gitea-gitea-1:3000/…` here instead of `https://git.opsforge.localhost`?
4. What's the difference between Traefik's and Portainer's access to the Docker socket?
5. Which volumes would you need to restore Gitea completely on a new server?

## After the lab, check yourself

1. What did `/etc/gitea/app.ini` contain that you never wrote yourself?
2. How long did Uptime Kuma take to mark Gitea as down, and what decides that?
3. What would a monitor on the *same* server fail to tell you?
4. How would you give yourself access to Portainer on a VPS without exposing it at all?
5. How much RAM did each tool use, and would all of them fit on a 4 GB VPS with the monitoring stack later?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Gitea docs](https://docs.gitea.com/)
- [Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Portainer security](https://docs.portainer.io/advanced/security)
- [Google SRE book: Monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Docker: daemon attack surface](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
