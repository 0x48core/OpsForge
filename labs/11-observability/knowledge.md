# Lab 11 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

So far, you've found problems by running `docker ps`, `docker logs`, and `curl`, *after* you noticed something was wrong. In production you want to:

1. **Know before users tell you**: alerts.
2. **See what "normal" looks like**, so you notice "abnormal": dashboards and history.
3. **Find the cause quickly**: metrics show *what* and *when*; logs show *why*.

**Monitoring** asks known questions ("is it up? is the disk full?"). **Observability** is being able to answer *new* questions from the data you collect, without shipping new code.

## Core concepts

### The three signals

| Signal | What | Example | Tool here |
|---|---|---|---|
| **Metrics** | Numbers over time, cheap to store and fast to query | `http_requests_total`, CPU % | Prometheus |
| **Logs** | Text events with details | `POST /visits 500: connection refused` | Loki |
| **Traces** | One request's path through many services, with timings | API → DB → cache | (not in this lab: Tempo, Jaeger) |

Typical flow: an **alert** fires on a metric → the **dashboard** shows when it started and what else changed → **logs** from that time explain why.

### Prometheus: pull-based metrics

```
Prometheus ──every 15 s: GET /metrics──▶ target
           ◀── plain text ────────────── http_requests_total{route="GET /health",code="200"} 151
```

- Prometheus **pulls** (scrapes) each target. Targets just expose `/metrics`.
- If a scrape fails, Prometheus records `up = 0` for that target. That's free availability monitoring.
- Data is a **time series**: a metric name plus **labels** identify it, and each scrape adds a (time, value) sample.
- **Exporters** translate things that don't speak Prometheus: node-exporter (the Linux host), cAdvisor (containers). Traefik and hello-api expose metrics natively.

### Metric types

| Type | Behaves | Use for | Query with |
|---|---|---|---|
| **Counter** | Only goes up (resets to 0 on restart) | Requests, errors, visits | `rate(x[5m])`, `increase(x[1h])` |
| **Gauge** | Up and down | Memory, temperature, queue length | The value itself |
| **Histogram** | Counts observations in buckets | Latency, sizes | `histogram_quantile(0.95, …)` |

Never graph a raw counter: it just climbs. `rate()` turns it into "per second", and handles resets.

### Labels and cardinality

Every unique combination of label values is a **separate time series**, costing memory and disk. hello-api labels requests by `route` (the *pattern*, like `GET /visits`), not the raw path. If `/nope`, `/nope2`, … each became a label value, an attacker or a crawler could create millions of series and take Prometheus down. The test checks unknown paths become `route="unmatched"`.

Rules: **labels for things with few values** (method, route, status code, service). **Never** user IDs, request IDs, emails, or full URLs. Those belong in logs.

### RED and USE

Two checklists for "what should I graph?":

| Method | For | Measure |
|---|---|---|
| **RED** | Services (requests) | **R**ate, **E**rrors, **D**uration |
| **USE** | Resources (CPU, disk, network) | **U**tilization, **S**aturation, **E**rrors |

The OpsForge dashboard has RED from Traefik and hello-api, and USE from node-exporter and cAdvisor.

### Percentiles, not averages

An average latency of 50 ms can hide that 5% of users wait 2 seconds. **p95** means "95% of requests are faster than this". Histograms let Prometheus estimate any percentile: `histogram_quantile(0.95, sum by (le) (rate(..._bucket[5m])))`.

### Service discovery

Static targets (`node-exporter:9100`) are fine for fixed services. hello-api's container name changes on every deploy (lab 08), and there can be two replicas at once. **Docker service discovery** asks the Docker API which containers carry `prometheus.scrape=true`, and scrapes each one. **Relabeling** turns Docker metadata into the target address and labels.

⚠️ With discovery, **a stopped container isn't "down", it's gone**. No target means no `up` series, so `up == 0` can't fire. Pair it with `absent(up{job="…"})`.

### Logs with Loki

- Loki indexes **only labels** (`project`, `service`, `container`), not the log text. It's cheap to run, and you filter text at query time (`|= "error"`).
- The same cardinality rules apply: few labels, low cardinality.
- **Alloy** discovers containers through the Docker API and ships their stdout/stderr. Apps just print logs; they don't need to know about Loki.
- **LogQL**: `{selector} |= "text" | json | line_format …`, and metric queries like `count_over_time(...[1m])`.

### Alerting

```
Prometheus rule: expr true ──for: 1m──▶ FIRING ──▶ Alertmanager: group, dedupe, route ──▶ Telegram / Discord
                 (meanwhile: PENDING)                 silence, inhibit, repeat_interval
```

- **`for:`** avoids alerting on a single bad scrape (flapping).
- **Alertmanager** groups related alerts into one message, routes by labels (`severity`), handles **silences** during maintenance, and sends **resolved** notices.
- Good alerts are **actionable** and about **symptoms users feel** ("5% of requests fail"), not every cause ("CPU 80%"). Too many alerts and people ignore them (alert fatigue).

### Least privilege with the Docker API

Prometheus, Alloy, and cAdvisor need to *read* container information. Mounting `/var/run/docker.sock` would give them full control of Docker, which is root on the host (labs 05–07). The **socket proxy** exposes only read-only endpoints (`CONTAINERS`, `NETWORKS`, `INFO`; `POST: 0`) on an internal network. A request it doesn't allow gets `403 Forbidden`, which you saw when cAdvisor first asked for `/info`.

### Provisioning: dashboards as code

Grafana data sources and dashboards come from files in git. Rebuild the server (lab 09) and Grafana comes back identical. No "I clicked it together once" dashboards that disappear with the server.

### Observability isn't free

Every component uses CPU, RAM, and disk (~780 MiB RAM here). Retention (`15d` metrics, `7d` logs) and `mem_limit`s keep it bounded. Measure, then set limits: Alloy needed more than first guessed.

## Key terms

| Term | Meaning |
|---|---|
| Scrape | Prometheus fetching `/metrics` from a target |
| Target | Something Prometheus scrapes |
| Exporter | Adapter exposing another system's metrics |
| Time series | One metric name + one label combination over time |
| Cardinality | Number of distinct time series |
| PromQL / LogQL | Query languages of Prometheus / Loki |
| Recording / alerting rule | A query Prometheus evaluates on a schedule, to store / to alert |
| Pending / firing / resolved | Alert states |
| Silence | Temporarily muting matching alerts |

## Commands to know

| Command / query | What it does |
|---|---|
| `up` | Which targets are reachable |
| `rate(http_requests_total[5m])` | Requests per second |
| `sum by (code) (rate(...))` | Aggregate by a label |
| `histogram_quantile(0.95, sum by (le) (rate(x_bucket[5m])))` | p95 latency |
| `absent(up{job="x"})` | 1 when no such series exists |
| `{service="app"} \|= "error"` | Loki: log lines containing "error" |
| `promtool check config` / `check rules` | Validate Prometheus files |
| `amtool check-config` | Validate Alertmanager config |
| `docker stats --no-stream` | RAM and CPU per container |

## Before you start, can you answer these?

1. What's the difference between a counter and a gauge, and why do counters need `rate()`?
2. Why does hello-api label requests with the route pattern instead of the URL path?
3. What do metrics tell you that logs don't, and the other way round?
4. Why does an alert have a `for:` duration?
5. Why do Prometheus and Alloy talk to a socket proxy instead of the Docker socket?

## After the lab, check yourself

1. Write the PromQL for "hello-api 5xx errors per second".
2. Why didn't `up == 0` fire when hello-api was stopped, and what did?
3. What fraction of hello-api's logs were health checks? How would you reduce that?
4. Which panel would you look at first if users said "the site is slow"?
5. How much RAM did the stack use, and what would you drop on a smaller VPS?
6. What would you change to monitor the server from *outside* (if the whole VPS goes down, so does this stack)?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Prometheus: overview](https://prometheus.io/docs/introduction/overview/)
- [Google SRE book: Monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [The RED method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
- [The USE method (Brendan Gregg)](https://www.brendangregg.com/usemethod.html)
- [Prometheus: instrumentation best practices](https://prometheus.io/docs/practices/instrumentation/)
- [Grafana Loki: label best practices](https://grafana.com/docs/loki/latest/get-started/labels/bp-labels/)
