# Lab 06 — Self-hosted tools

- **Phase:** 2 — Containers
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker Desktop on the Mac, behind the Traefik stack from [lab 05](../05-multi-service-proxy/)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Self-host three tools you'll actually use, all behind Traefik: a Git server, uptime monitoring, and a Docker UI.

## Done when

- [ ] Gitea at `https://git.opsforge.localhost`, admin created from the CLI, registration disabled
- [ ] This repo pushed to Gitea over SSH (port 2222) as a second remote
- [ ] Uptime Kuma at `https://status.opsforge.localhost` monitoring every running service
- [ ] A monitor alert seen: stop a service, watch it go **down**, start it, watch it recover
- [ ] Portainer at `https://portainer.opsforge.localhost` with an admin account, and you can explain why it must never be public without strong auth
- [ ] Every tool's data volume listed in the table below, ready for backups in [lab 03](../03-automated-backup/)

## Services

| Tool | URL | Container (for monitors) | Data volume | Image |
|---|---|---|---|---|
| Gitea | `https://git.opsforge.localhost`, SSH `localhost:2222` | `gitea-gitea-1:3000` | `gitea_gitea-data`, `gitea_gitea-config` | `gitea/gitea:1.25.5-rootless` |
| Uptime Kuma | `https://status.opsforge.localhost` | `uptime-kuma-uptime-kuma-1:3001` | `uptime-kuma_uptime-kuma-data` | `louislam/uptime-kuma:2.5.5` |
| Portainer | `https://portainer.opsforge.localhost` | `portainer-portainer-1:9000` | `portainer_portainer-data` | `portainer/portainer-ce:2.45.2` |

Stacks: [stacks/gitea](../../stacks/gitea/), [stacks/uptime-kuma](../../stacks/uptime-kuma/), [stacks/portainer](../../stacks/portainer/)

## Steps

### 0. Traefik must be running

```bash
docker network ls | grep proxy || docker network create proxy
cd stacks/traefik && docker compose up -d && cd ../..
```

If `secrets/dashboard-users` is empty, the Traefik dashboard won't log you in. That only affects the dashboard; see lab 05 step 2.

### 1. Gitea

```bash
cd stacks/gitea
docker compose up -d
docker compose logs -f          # wait for "Starting new Web server", then Ctrl+C
curl -sk https://git.opsforge.localhost/api/healthz
```

There's no web installer: `INSTALL_LOCK=true` and the `GITEA__…` environment variables configure everything. Look at the generated config:

```bash
docker compose exec gitea cat /etc/gitea/app.ini
```

Create the admin user with the CLI. It prints a random password once, so save it in your password manager:

```bash
docker compose exec gitea gitea admin user create \
  --admin --username opsadmin --email <you@example.com> \
  --random-password --must-change-password=false
```

Log in at `https://git.opsforge.localhost` (accept the certificate warning unless you did lab 05 step 5).

### 2. Push this repo to Gitea over SSH

1. In Gitea: **Settings → SSH / GPG Keys → Add Key**, and paste your public key (`cat ~/.ssh/id_ed25519.pub`).
2. Create a repository named `OpsForge`: **+ → New Repository**, private.
3. Add it as a second remote and push:

```bash
cd ~/personal/OpsForge
git remote add gitea ssh://git@localhost:2222/opsadmin/OpsForge.git
git push gitea main
git remote -v                    # origin = GitHub, gitea = your own server
```

The first connection asks you to confirm the host key. That's the `known_hosts` check from lab 01.

Why `localhost:2222` and not `git.opsforge.localhost`? Traefik is only routing HTTP here, so SSH goes straight to Gitea's published port 2222. And `ssh` uses the macOS resolver, which may not resolve `*.localhost` names.

### 3. Uptime Kuma

```bash
cd stacks/uptime-kuma
docker compose up -d
```

Open `https://status.opsforge.localhost`:
1. First run asks for a **database**: choose **SQLite** (simple, one file in the volume).
2. Create the admin account.
3. Add monitors, type **HTTP(s)**, interval 20 s:

| Name | URL |
|---|---|
| Gitea | `http://gitea-gitea-1:3000/api/healthz` |
| Portainer | `http://portainer-portainer-1:9000/` (after step 4) |
| whoami | `http://whoami-whoami-1/` (if the lab 05 stack is running) |
| hello-api | `http://hello-api-app-1:8000/ready` (if running with `compose.traefik.yaml`) |

> ⚠️ **Don't use `https://git.opsforge.localhost` in monitors.** Inside a container, `*.localhost` doesn't resolve to your Mac. Uptime Kuma sees only Docker's DNS, so use **container names** on the shared `proxy` network. On a VPS with real DNS, you'd *also* add monitors for the public URLs, to test the whole path including TLS.

**See an alert happen:**

```bash
(cd stacks/gitea && docker compose stop)    # watch the Gitea monitor turn red
(cd stacks/gitea && docker compose start)   # …and recover
```

Optional: **Settings → Notifications**, add Telegram or Discord, and repeat. You'll set up proper alerting in lab 11.

### 4. Portainer

```bash
cd stacks/portainer
docker compose up -d
```

Open `https://portainer.opsforge.localhost` **within 5 minutes** and create the admin user. For security, Portainer locks the setup page after 5 minutes. If you see a timeout message, run `docker compose restart` and try again.

Then look around **Containers**, **Volumes**, **Networks**: everything from labs 04–06 is visible. Find the `proxy` network and see which containers are attached.

Now think about what you just did: Portainer has the **read-write Docker socket**. Anyone who logs in can start a privileged container that mounts the host's `/` and gets root on the server. On a VPS:
- never expose it without strong auth (Traefik basic auth or SSO in front, plus Portainer's own login)
- or don't expose it at all, and reach it through an SSH tunnel: `ssh -L 9000:localhost:9000 opsforge`

### 5. Inspect what you built

```bash
docker network inspect proxy --format '{{range .Containers}}{{.Name}} {{end}}'
docker volume ls | grep -E 'gitea|uptime-kuma|portainer'
docker stats --no-stream        # how much RAM do these tools use? (matters on a 4 GB VPS)
```

Record the RAM usage in "Lessons learned".

### 6. Clean up (optional)

`down` keeps the data; `down -v` deletes the volumes, meaning your Gitea repos and monitor history.

```bash
for s in gitea uptime-kuma portainer; do (cd stacks/$s && docker compose down); done
```

## Code

- [stacks/gitea/](../../stacks/gitea/), [stacks/uptime-kuma/](../../stacks/uptime-kuma/), [stacks/portainer/](../../stacks/portainer/)

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **Monitors via `https://*.opsforge.localhost` fail inside containers** (no DNS answer). Fixed by monitoring container names on the `proxy` network.

## Lessons learned

## References

- [Gitea: installation with Docker (rootless)](https://docs.gitea.com/installation/install-with-docker-rootless)
- [Gitea: config cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [Uptime Kuma wiki](https://github.com/louislam/uptime-kuma/wiki)
- [Portainer: install CE on Docker](https://docs.portainer.io/start/install-ce/server/docker/linux)
