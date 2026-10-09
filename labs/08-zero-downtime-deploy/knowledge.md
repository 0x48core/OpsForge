# Lab 08 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

If every deploy causes errors, people deploy less often, changes pile up, releases get bigger and riskier, and deploys cause even more problems. **Zero-downtime deploys break that cycle**: shipping becomes boring and safe, so you can do it many times a day. In lab 07, a single deploy failed about a third of requests for a few seconds. Here you remove that, and you measure it.

## Core concepts

### Deployment strategies

| Strategy | How | Downtime | Extra capacity | Rollback |
|---|---|---|---|---|
| **Recreate** | Stop old, start new | ✅ yes | None | Redeploy old |
| **Rolling** | Replace instances one by one, new before old | None | +1 instance during deploy | Roll again with the old version |
| **Blue-green** | Run a full new copy ("green"), switch all traffic at once | None | 2× during deploy | **Instant**: switch back to blue |
| **Canary** | Send a small % of traffic to the new version, increase if healthy | None | Small | Shift traffic back |

This lab implements **rolling** (one instance → two → one). Blue-green with Traefik would be two always-running services plus a **weighted service** in a dynamic file that you flip from `blue: 100` to `green: 100`. Canary is the same file with `blue: 90, green: 10`.

### What has to be true for zero downtime

1. **There's always at least one instance that can serve.** Start the new one before stopping the old.
2. **The proxy only sends traffic to instances that are ready.** Healthchecks, and Traefik ignoring containers that aren't healthy.
3. **An instance stops getting new traffic *before* it stops accepting it.** Drain, then shut down.
4. **In-flight requests finish.** Graceful shutdown (`srv.Shutdown`, lab 02).
5. **A bad version never takes traffic, and never removes the good one.** Health-gated deploys.

Each piece in this lab covers one of these. Removing any of them brings errors back, which the guide's step 5 lets you see.

### Why a drain delay is needed

```
without drain                          with drain (SHUTDOWN_DELAY=5)
t=0  SIGTERM → app closes port         t=0  SIGTERM → /health returns 503, app still serves
t=0+ Traefik still routes here → 502   t≈2  Traefik health check fails → server removed
t≈1  Traefik notices, removes it       t=5  app closes port, nobody is sending to it ✅
```

The proxy learns about changes **asynchronously** (Docker events, health-check intervals). There's always a window where it still believes the old instance is fine. Draining makes that window harmless. Kubernetes has the same problem, and the common fix is a `preStop` hook that sleeps for a few seconds.

### Liveness, readiness, and draining

Lab 04 separated `/health` (liveness) from `/ready` (readiness). Draining adds one more state: "alive, but please stop sending me work". hello-api signals it by failing `/health` while draining. In Kubernetes (lab 12), you'd fail the **readiness** probe, so the pod leaves the Service endpoints without being restarted.

### Retries: a safety net, not a fix

- Traefik's `retry` middleware retries **only network errors** (connection refused or reset), never HTTP error responses such as a 500.
- Retries are safe here because a connection that failed before the request reached the app did no work.
- ⚠️ Retrying requests that might have *reached* the app is risky for non-idempotent operations such as `POST /visits`: the visit could be counted twice. Prefer to prevent errors (draining) rather than retry them away.

### Health-gated deploys and automatic abort

`deploy.sh` waits for the new container to be `healthy`. If it isn't within `HEALTH_TIMEOUT`, it removes the new container and exits 1. The old version never stopped, so a broken release causes **no outage**, and CI shows the deploy as failed. Only successful deploys are written to `.deploy-history`, so `rollback.sh` never "rolls back" to a broken tag.

### Rollback

- **Rollback = deploying a known-good previous artifact.** That's only possible because lab 07 builds immutable `sha-…` images: the old version still exists, unchanged, in the registry.
- **Roll forward vs roll back:** sometimes the fix is a quick new deploy. Rolling back is for "stop the bleeding now, investigate later".
- ⚠️ **Database migrations** are what make rollback hard. If v2 changes the schema in a way v1 can't read, rolling back the app breaks it. The usual rule is **expand → migrate → contract**: first add new columns or tables in a backward-compatible way, deploy code that uses them, and remove the old ones only in a later release. hello-api's `CREATE TABLE IF NOT EXISTS` is trivially compatible.

### Measuring instead of believing

"Zero downtime" is a claim, so you prove it with a **load test during the deploy**:
- `hey -z 30s -c 10` keeps 10 concurrent clients busy, and reports every status code and error.
- Run a **control** (no deploy) to know the baseline: some tools report errors at the very end of a timed run.
- Check that the test actually ran. A "perfect" result from a test that didn't run is the most dangerous kind (see "What broke" in the README).

## Key terms

| Term | Meaning |
|---|---|
| Rolling deploy | Replace instances gradually, starting new ones before stopping old ones |
| Blue-green | Two full environments; switch traffic between them at once |
| Canary | Send a small share of traffic to the new version first |
| Draining | Stop accepting new work but finish current work before exiting |
| Health-gated | The deploy continues only once the new version passes health checks |
| Idempotent | Safe to repeat: doing it twice has the same effect as once (GET yes, POST /visits no) |
| Expand/contract | Schema changes in backward-compatible steps, so rollback stays possible |

## Commands to know

| Command | What it does |
|---|---|
| `stacks/hello-api/deploy.sh <tag>` | Rolling, health-gated deploy |
| `stacks/hello-api/rollback.sh` | Deploy the previous successful tag |
| `hey -z 30s -c 10 -host <name> <url>` | Load test for 30 s with 10 concurrent clients |
| `docker inspect --format '{{.State.Health.Status}}' <c>` | `starting`, `healthy`, or `unhealthy` |
| `docker inspect --format '{{json .State.Health}}' <c>` | Healthcheck history with output |
| `docker compose up -d --no-recreate --scale app=2 app` | Add a second instance without touching the first |
| `docker stop --time 30 <c>` | SIGTERM, then SIGKILL after 30 s |

## Before you start, can you answer these?

1. Why did lab 07's deploy produce `404`s, not only `502`s?
2. What are the five conditions for zero downtime, and which file handles each one?
3. Why must the app fail `/health` *before* it stops listening?
4. Why is retrying `POST /visits` riskier than retrying `GET /`?
5. What makes a rollback impossible even when the old image still exists?

## After the lab, check yourself

1. How many requests failed with the old deploy, and with the new one?
2. What happened in the old container's logs between SIGTERM and exit?
3. Which piece, when removed, brought errors back? Why that one?
4. Why does `rollback.sh` never pick the broken tag from step 4?
5. How would you build blue-green with Traefik instead? What would rollback look like then?
6. What extra capacity does a rolling deploy need, and does it matter on a 4 GB VPS?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Martin Fowler: Blue-green deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Martin Fowler: Canary release](https://martinfowler.com/bliki/CanaryRelease.html)
- [Traefik: weighted round robin (blue-green, canary)](https://doc.traefik.io/traefik/routing/services/#weighted-round-robin-service)
- [Kubernetes: rolling updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Expand and contract pattern](https://martinfowler.com/bliki/ParallelChange.html)
