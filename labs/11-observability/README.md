# Lab 11 — Observability stack

- **Phase:** 5 — Observability & Kubernetes
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker Desktop on the Mac, behind the Traefik stack from lab 05

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

See what the server and every service are doing (metrics, logs, dashboards), and be told when something is wrong (alerts), without logging in and running `docker ps`.

## Done when

- [ ] Prometheus scrapes host (node-exporter), containers (cAdvisor), Traefik, and hello-api; all targets **up**
- [ ] hello-api exposes `/metrics`, and Prometheus finds it through Docker labels
- [ ] Grafana shows the provisioned **OpsForge overview** dashboard with live data
- [ ] Loki has the logs of every container; you found a hello-api error in Grafana → Explore
- [ ] An alert went **pending → firing → resolved**, and you saw it in Alertmanager
- [ ] Optional: the alert arrived on Telegram or Discord
- [ ] RAM used by the whole stack noted in "Lessons learned"

## Architecture

```
                         ┌──────────── proxy network ────────────┐
Browser ─HTTPS─▶ Traefik ┼─▶ grafana.  ──▶ Grafana ─┬─▶ Prometheus ◀─ scrape ─┬─ Traefik :8082
                         ├─▶ prometheus. (basic auth)│                         ├─ hello-api :8000/metrics (Docker labels)
                         └─▶ alertmanager. (auth)    └─▶ Loki ◀── push ── Alloy │
                                                                   │            ├─ node-exporter (host)
                         observability network:                    │            └─ cAdvisor (containers)
                         socket-proxy (read-only Docker API) ◀─────┴─ Prometheus, Alloy, cAdvisor
                         Prometheus ── alerts ──▶ Alertmanager ──▶ (Telegram / Discord)
```

| Service | Role | Image |
|---|---|---|
| Prometheus | Scrapes and stores metrics, evaluates alert rules | `prom/prometheus:v3.15.0` |
| Alertmanager | Groups and routes alerts to notifications | `prom/alertmanager:v0.34.1` |
| node-exporter | Host CPU, RAM, disk, network | `prom/node-exporter:v1.12.1` |
| cAdvisor | Per-container CPU and RAM | `ghcr.io/google/cadvisor:v0.60.6` |
| Loki | Stores logs, indexed only by labels | `grafana/loki:3.7.8` |
| Alloy | Reads container logs, pushes them to Loki | `grafana/alloy:v1.20.1` |
| socket-proxy | Read-only Docker API (no socket mounted into Prometheus or Alloy) | `tecnativa/docker-socket-proxy:v0.5.0` |
| Grafana | Dashboards and log exploration, provisioned from files | `grafana/grafana:13.2.3` |

Files: [stacks/observability/](../../stacks/observability/). App metrics: [apps/hello-api/metrics.go](../../apps/hello-api/metrics.go).

## Measured while preparing this lab

| Check | Result |
|---|---|
| Config validation | promtool (config + **6 rules**), amtool, `loki -verify-config`, `alloy fmt`: all pass |
| Targets | prometheus, node, cadvisor, traefik, hello-api: all **up** |
| Dashboard | provisioned (18 panels); every panel query returns data (5xx: once errors happen) |
| Logs | hello-api lines in Loki, labels `project`, `service`, `container` |
| Alert test | stopped hello-api → `ServiceMissing` pending → firing (90 s) → in Alertmanager → resolved after restart |
| RAM | ~780 MiB for the whole stack (Alloy ~210, Loki ~205, cAdvisor ~120, Grafana ~110, Prometheus ~80) |

## Steps

### 0. Prerequisites

```bash
docker network ls | grep proxy || docker network create proxy
cat stacks/traefik/secrets/dashboard-users     # must contain admin:$2y$…; if empty: lab 05 step 2
(cd stacks/traefik && docker compose up -d)
(cd stacks/hello-api && docker compose -f compose.yaml -f compose.traefik.yaml up -d --build --wait)
```

hello-api is rebuilt because it now has a `/metrics` endpoint. Look at it:

```bash
curl -sk -H 'Host: api.opsforge.localhost' https://127.0.0.1/ >/dev/null
# hello-api is distroless (no curl inside), so look from a throwaway container on the proxy network:
docker run --rm --network proxy curlimages/curl:8.11.1 -s http://hello-api-app-1:8000/metrics | grep -E '^(http_requests_total|hello_api)'
```

### 1. Start the stack

```bash
cd stacks/observability
cp .env.example .env            # set GRAFANA_ADMIN_PASSWORD
docker compose up -d
docker compose ps
```

### 2. Prometheus: targets and queries

Open `https://prometheus.opsforge.localhost` (dashboard login from lab 05).
- **Status → Targets:** all up? Note how `traefik` and `hello-api` were found: **Docker labels** (`prometheus.scrape=true`) through the socket proxy.
- **Alerts:** the 6 rules from [alerts.yml](../../stacks/observability/prometheus/alerts.yml), all inactive.
- In **Query**, try these, one at a time:

```promql
up
rate(http_requests_total{job="hello-api"}[1m])
sum by (route, code) (http_requests_total{job="hello-api"})
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job="hello-api"}[5m])))
sum by (service, code) (rate(traefik_service_requests_total[1m]))
topk(5, container_memory_working_set_bytes{name!=""})
1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
```

Generate traffic in another terminal and watch the numbers move:

```bash
while true; do curl -sk -o /dev/null -X POST -H 'Host: api.opsforge.localhost' https://127.0.0.1/visits; sleep 0.2; done
```

### 3. Grafana

Open `https://grafana.opsforge.localhost` and log in as `admin` with the password from `.env`.
- **Dashboards → OpsForge → OpsForge overview.** Find each panel's query: **Edit** → see the PromQL.
- **Connections → Data sources:** Prometheus and Loki are there, read-only. They came from [provisioning files](../../stacks/observability/grafana/provisioning/), not clicks, so a rebuilt server gets the same Grafana.
- Optional: **Dashboards → New → Import → ID `1860`** (Node Exporter Full), with Prometheus as the data source.

### 4. Logs in Loki

**Explore → Loki**, then try:

```logql
{project="hello-api", service="app"}
{project="hello-api", service="app"} |= "POST /visits"
{project="observability"} |~ "(?i)error"
sum by (service) (count_over_time({project="hello-api"}[1m]))
```

Notice that ~90% of hello-api's log lines are `GET /health` (from Docker, Traefik, and Prometheus). That's the log noise you noted in lab 04. Filter it out: `{service="app"} != "/health"`.

### 5. Break something, get an alert

Make hello-api fail with 5xx errors:

```bash
(cd ../hello-api && docker compose -f compose.yaml -f compose.traefik.yaml stop db)
for i in $(seq 1 20); do curl -sk -o /dev/null -w '%{http_code} ' -X POST -H 'Host: api.opsforge.localhost' https://127.0.0.1/visits; done
```

Find the errors in three places: the **5xx** dashboard panel, `{service="app"} |= "failed"` in Loki, and `http_requests_total{code="500"}` in Prometheus. Then start the DB again.

Now stop the app entirely:

```bash
(cd ../hello-api && docker compose -f compose.yaml -f compose.traefik.yaml stop app)
```

In Prometheus **Alerts**, watch `ServiceMissing` go **pending** (the `for: 1m` window) and then **firing**. Open `https://alertmanager.opsforge.localhost` and see it there. Then start the app again and watch it **resolve**.

Why `ServiceMissing` and not `TargetDown`? Check `up{job="hello-api"}` while the app is stopped. See "What broke".

### 6. Optional: notifications to Telegram or Discord

1. Telegram: create a bot with **@BotFather**, then `echo '<token>' > alertmanager/secrets/telegram-token`, and get your chat id from **@userinfobot**.
   Discord: **Server settings → Integrations → Webhooks**, then `echo '<url>' > alertmanager/secrets/discord-webhook`.
2. In [alertmanager.yml](../../stacks/observability/alertmanager/alertmanager.yml), uncomment that receiver and set `route.receiver` to its name.
3. Check and apply it:

```bash
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
docker compose restart alertmanager
```

Repeat step 5. The message arrives after `group_wait` (30 s) once the alert fires, and again when it resolves.

### 7. Look at the cost

```bash
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | grep observability
```

Add it up, and compare with a 4 GB VPS that also runs Traefik, hello-api, Gitea, and (lab 12) K3s.

### 8. Clean up

```bash
docker compose down              # keeps data; add -v to delete metrics, logs, and Grafana state
```

## On the VPS

The same stack works there. Two differences:
- node-exporter measures the **real** server instead of Docker Desktop's VM. You can use `/:/host:ro,rslave`.
- `DOMAIN` comes from `.env`, so you get `grafana.<your-domain>` with a Let's Encrypt certificate.

Adding it to the Ansible `opsforge` role (copy the stack, write `.env` from the vault, `docker compose up`) is a good exercise.

## Code

- [stacks/observability/](../../stacks/observability/)
- [apps/hello-api/metrics.go](../../apps/hello-api/metrics.go) (+ test in `main_test.go`)
- Traefik metrics: [stacks/traefik/traefik.yml](../../stacks/traefik/traefik.yml); scrape labels in [stacks/traefik/compose.yaml](../../stacks/traefik/compose.yaml) and [stacks/hello-api/compose.yaml](../../stacks/hello-api/compose.yaml)

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **node-exporter: `path / is mounted on / but it is not a shared or slave mount`:** Docker Desktop's VM doesn't support `rslave`. Used `/:/host:ro`.
- **hello-api not scraped:** Prometheus' Docker discovery uses only a container's *first* network by default (`match_first_network: true`), and hello-api is on two. Fixed with `match_first_network: false`.
- **cAdvisor saw no containers (3 problems in a row):**
  1. `/var/run` on Docker Desktop is shared from macOS, so the socket was a broken symlink. Pointed cAdvisor at the socket proxy instead.
  2. The proxy answered **403**: cAdvisor needs `/info`. Allowed `INFO: 1` (still read-only).
  3. Docker 29 keeps images in containerd. Mounted `/run/containerd/containerd.sock:ro`.
- **Alloy near its memory limit** (238 of 256 MiB): raised to 384m. Limits need measuring, not guessing.
- **No alert when hello-api stopped:** a stopped container *disappears* from Docker discovery, so `up == 0` never fires. Added `ServiceMissing` with `absent(up{job="hello-api"})`.
- `curl $G/...` with options in a variable failed in zsh again. Use functions for repeated commands.

## Lessons learned

## References

- [Prometheus: getting started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus: docker_sd_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#docker_sd_config)
- [Alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) and [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Loki: LogQL](https://grafana.com/docs/loki/latest/query/)
- [Grafana Alloy: loki.source.docker](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/)
- [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
