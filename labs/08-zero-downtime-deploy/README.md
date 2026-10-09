# Lab 08 — Zero-downtime deployment

- **Phase:** 3 — CI/CD
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker Desktop on the Mac (Traefik from lab 05); the same scripts run on the VPS via CI (lab 07)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Deploy a new version while users keep getting answers, roll back with one command, and survive a broken release without an outage.

## Done when

- [ ] Measured the old deploy (lab 07) under load: how many requests failed?
- [ ] Rolling deploy under load with **zero** failed requests
- [ ] One-command rollback under load with zero failed requests
- [ ] A broken release fails the deploy, and the old version keeps serving
- [ ] Explained in "Lessons learned" why each piece is needed: healthcheck, drain delay, Traefik health check, retry

## How it works

```
                      Traefik (routes only to healthy containers)
                         │                       │
   1. start new  ──▶  [old v1] ◀── traffic   [new v2] starting… (not routed)
   2. new healthy ─▶  [old v1] ◀── traffic ──▶ [new v2]
   3. SIGTERM old ─▶  [old v1] draining: /health = 503, still serving
                      Traefik health check removes it ──▶ [new v2] gets all traffic
   4. old exits   ─▶                          [new v2]
```

| Piece | Where | Why it's needed |
|---|---|---|
| **Run old and new side by side** | [deploy.sh](../../stacks/hello-api/deploy.sh) (`--scale app=2 --no-recreate`) | There's never a moment with zero containers |
| **Fast Docker healthcheck** | [Dockerfile](../../apps/hello-api/Dockerfile) (`--start-interval=1s`) | The new container is marked healthy in seconds; Traefik only routes to healthy containers |
| **Drain on SIGTERM** | [main.go](../../apps/hello-api/main.go) (`SHUTDOWN_DELAY=5` in [compose.traefik.yaml](../../stacks/hello-api/compose.traefik.yaml)) | `/health` fails first, so Traefik stops sending traffic *before* the app closes its port |
| **Traefik health check** | `compose.traefik.yaml` (`/health` every 2 s) | Notices the draining container and removes it from the load balancer |
| **Retry middleware** | [middlewares.yml](../../stacks/traefik/dynamic/middlewares.yml) | Safety net: a request that hits a closing connection is retried on the other container |
| **Abort if unhealthy** | `deploy.sh` (`wait_healthy`) | A broken release is removed, and the old one never stopped |
| **Deploy history** | `.deploy-history` (git-ignored) + [rollback.sh](../../stacks/hello-api/rollback.sh) | Rollback = deploy the previous tag, with the same zero-downtime path |

## Measured while preparing this lab

`hey -z 30s -c 10` against Traefik, on Docker Desktop:

| Scenario | Requests | Failed |
|---|---|---|
| Lab 07 `deploy.sh` (recreate) | 231,757 | **74,746** (74,000 × `404`, 746 × `502`) |
| Rolling, no drain delay yet | 109,150 | 3 × `502` |
| No deploy (control) | 267,689 | 0 |
| **Rolling deploy** v1 → v2 | 333,726 | **0** |
| **Rollback** v2 → v1 | 300,328 | **0** |
| **Broken release** (deploy aborted) | 320,391 | **0**, v1 kept serving |

The `404`s happened while no container was healthy: Traefik removes the router entirely (the lab 05 behaviour). The `502`s came from the old container closing its port while Traefik still sent it requests, which the drain delay fixed.

## Steps

### 0. Setup

```bash
brew install hey                         # HTTP load generator
docker network ls | grep proxy || docker network create proxy
(cd stacks/traefik && docker compose up -d)
```

Build two versions locally to deploy (or pull two real `sha-…` tags from GHCR after lab 07):

```bash
for t in sha-v1test sha-v2test; do
  docker build --build-arg VERSION=$t -t ghcr.io/0x48core/hello-api:$t apps/hello-api
done
```

The `hey` command used below sends 10 parallel requests for 30 seconds to Traefik, with the right `Host` header:

```bash
hey -z 30s -c 10 -host api.opsforge.localhost https://127.0.0.1/
```

### 1. Measure the problem first

Save the lab 07 version of `deploy.sh` (commit `9e37407`) next to the compose files, and use it for one deploy under load:

```bash
git show 9e37407:stacks/hello-api/deploy.sh > stacks/hello-api/deploy-recreate.sh && chmod +x stacks/hello-api/deploy-recreate.sh

PULL=0 stacks/hello-api/deploy.sh sha-v1test                          # first deploy, nothing to replace
hey -z 30s -c 10 -host api.opsforge.localhost https://127.0.0.1/ > /tmp/before.txt &
sleep 8; PULL=0 stacks/hello-api/deploy-recreate.sh sha-v2test; wait
grep -A4 'Status code distribution' /tmp/before.txt
rm stacks/hello-api/deploy-recreate.sh
```

Write the numbers in "What broke". Which status codes did you get, and why?

### 2. Rolling deploy under load

Read [deploy.sh](../../stacks/hello-api/deploy.sh) first. Then:

```bash
hey -z 30s -c 10 -host api.opsforge.localhost https://127.0.0.1/ > /tmp/rolling.txt &
sleep 6; PULL=0 stacks/hello-api/deploy.sh sha-v1test; wait
grep -A4 'Status code distribution' /tmp/rolling.txt
```

In a second terminal during the deploy, watch the containers overlap:

```bash
watch -n 0.5 'docker ps --filter name=hello-api-app --format "{{.Names}}  {{.Image}}  {{.Status}}"'
```

You'll see two app containers at once, the new one going `health: starting` → `healthy`, then the old one disappearing. Look at the old container's logs for `draining for 5s` → `shutting down`.

### 3. Rollback under load

```bash
cat stacks/hello-api/.deploy-history
hey -z 30s -c 10 -host api.opsforge.localhost https://127.0.0.1/ > /tmp/rollback.txt &
sleep 6; PULL=0 stacks/hello-api/rollback.sh; wait
grep -A4 'Status code distribution' /tmp/rollback.txt
curl -sk -H 'Host: api.opsforge.localhost' https://127.0.0.1/      # which version now?
```

### 4. Deploy a broken release

Make an image whose healthcheck always fails:

```bash
printf 'FROM ghcr.io/0x48core/hello-api:sha-v2test\nHEALTHCHECK --interval=1s --retries=2 CMD ["/hello-api", "nope"]\n' \
  | docker build -t ghcr.io/0x48core/hello-api:sha-broken -
hey -z 30s -c 10 -host api.opsforge.localhost https://127.0.0.1/ > /tmp/broken.txt &
sleep 4; HEALTH_TIMEOUT=20 PULL=0 stacks/hello-api/deploy.sh sha-broken; echo "exit: $?"; wait
grep -A4 'Status code distribution' /tmp/broken.txt
tail -1 stacks/hello-api/.deploy-history       # broken tag NOT recorded
```

In CI, that non-zero exit marks the `deploy` job red, so you'd see it immediately.

### 5. Remove one piece at a time (optional, but the best way to learn)

Repeat step 2 after each change, then undo it:

| Remove | Expected effect |
|---|---|
| `SHUTDOWN_DELAY` in `compose.traefik.yaml` | A few `502`s when the old container stops |
| `retry@file` from the router | More of them |
| `--start-interval=1s` in the Dockerfile (rebuild) | The deploy takes ~10 s longer; still zero errors |
| The `sleep 3` in `deploy.sh` | Possible errors if Traefik hasn't picked up the new container yet |

### 6. Clean up

```bash
(cd stacks/hello-api && APP_VERSION=x docker compose -f compose.yaml -f compose.traefik.yaml -f compose.deploy.yaml down -v)
rm -f stacks/hello-api/.deploy-history
docker rmi ghcr.io/0x48core/hello-api:sha-v1test ghcr.io/0x48core/hello-api:sha-v2test ghcr.io/0x48core/hello-api:sha-broken
```

## On the VPS

Nothing changes: CI's `deploy` job (lab 07) calls the same `deploy.sh`. To roll back on the server:

```bash
ssh opsforge '~/opsforge/stacks/hello-api/rollback.sh'
```

or re-run an older successful `hello-api` workflow run's deploy job in GitHub Actions.

## Code

- [stacks/hello-api/deploy.sh](../../stacks/hello-api/deploy.sh), [stacks/hello-api/rollback.sh](../../stacks/hello-api/rollback.sh)
- [apps/hello-api/main.go](../../apps/hello-api/main.go) (drain), [Dockerfile](../../apps/hello-api/Dockerfile) (`--start-interval`)
- [stacks/hello-api/compose.traefik.yaml](../../stacks/hello-api/compose.traefik.yaml), [stacks/traefik/dynamic/middlewares.yml](../../stacks/traefik/dynamic/middlewares.yml)

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- A first load-test run reported "0 errors" because zsh ran `$H` (a whole command in one variable) as a single program name, so `hey` never ran. **Always check the raw output of a test that "passes".** Fixed by using a shell function.
- Container names keep counting up (`hello-api-app-5`): each deploy scales to 2 and removes the old one. Harmless, but don't hard-code container names in scripts or monitors.

## Lessons learned

## References

- [Traefik: retry middleware](https://doc.traefik.io/traefik/middlewares/http/retry/)
- [Traefik: service health checks](https://doc.traefik.io/traefik/routing/services/#health-check)
- [Dockerfile HEALTHCHECK](https://docs.docker.com/reference/dockerfile/#healthcheck)
- [Kubernetes: container lifecycle hooks (preStop)](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [hey](https://github.com/rakyll/hey)
