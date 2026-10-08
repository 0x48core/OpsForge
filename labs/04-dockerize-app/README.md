# Lab 04 — Dockerize an app

- **Phase:** 2 — Containers
- **Status:** 🟨 in progress
- **Started / finished:** 2026-10-08 / —
- **Environment:** Docker Desktop on the Mac (no server needed)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Package [hello-api](../../apps/hello-api/) as a small, production-ready image and run it with PostgreSQL and Redis using Docker Compose.

## Done when

- [x] Multi-stage Dockerfile; image size noted before and after (naive vs final)
- [x] Container runs as a non-root user
- [x] `compose.yaml` runs app + PostgreSQL + Redis
- [x] Data persists in named volumes across `down`/`up`; `down -v` wipes it
- [x] Healthchecks defined; the app waits for healthy dependencies
- [x] Only the app is published, and only on `127.0.0.1`
- [ ] Explained (in "Lessons learned") what happens to `/ready` and `/visits` when the DB is down

## Files

| File | What it is |
|---|---|
| [apps/hello-api/Dockerfile](../../apps/hello-api/Dockerfile) | Multi-stage build → distroless, non-root image |
| [apps/hello-api/.dockerignore](../../apps/hello-api/.dockerignore) | Keeps the build context small and secret-free |
| [stacks/hello-api/compose.yaml](../../stacks/hello-api/compose.yaml) | App + Postgres + Redis |
| [stacks/hello-api/.env.example](../../stacks/hello-api/.env.example) | Config template; copy to `.env` |

hello-api endpoints used in this lab:

| Endpoint | Purpose |
|---|---|
| `GET /health` | **Liveness**: is the process up? |
| `GET /ready` | **Readiness**: are Postgres and Redis reachable? |
| `GET /visits` / `POST /visits` | Read / record a visit (count in Redis, row in Postgres) |

## Steps

### 0. Check Docker

```bash
docker version            # both Client and Server must show a version
docker context ls         # the * marks the active context
```

If `Server` shows an error about `.orbstack/run/docker.sock`, your CLI still points to OrbStack, which is no longer installed. Switch it to Docker Desktop:

```bash
docker context use desktop-linux
```

### 1. The naive image (to have something to compare)

Before reading the real Dockerfile, build the simplest possible one:

```bash
cd apps/hello-api
cat > /tmp/Dockerfile.naive <<'EOF'
FROM golang:1.26-alpine
WORKDIR /src
COPY . .
RUN go build -o /hello-api .
CMD ["/hello-api"]
EOF
docker build -t hello-api:naive -f /tmp/Dockerfile.naive .
docker images hello-api                # note the SIZE
docker run --rm hello-api:naive whoami  # who does it run as?
```

Write the size and the user down. What's inside that the app doesn't need?

### 2. The multi-stage image

Read [Dockerfile](../../apps/hello-api/Dockerfile) line by line, then build it:

```bash
make docker-build                      # = docker build --build-arg VERSION=... -t hello-api:<version> .
docker images hello-api                # compare with naive
docker history hello-api:<version>     # the layers and their sizes
docker image inspect hello-api:<version> --format '{{.Config.User}}'
```

**Feel the layer cache:** change a log message in `main.go` and build again. The `go mod download` step says `CACHED`. Then change `go.mod` (e.g. add a blank line) and build again to see what's no longer cached.

### 3. Run one container by hand

```bash
docker run -d --name hello -p 127.0.0.1:8000:8000 hello-api:<version>
docker ps                              # STATUS shows (health: starting) → (healthy)
curl localhost:8000/
curl localhost:8000/ready              # both "not configured": no DB yet
curl -X POST localhost:8000/visits     # 503: needs Postgres and Redis
docker logs -f hello                   # Ctrl+C to stop following
docker exec hello sh                   # fails: distroless has no shell. Why is that good?
docker stop hello && docker logs hello # "shutting down": graceful SIGTERM
docker rm hello
```

### 4. The full stack with Compose

```bash
cd stacks/hello-api
cp .env.example .env                   # then change POSTGRES_PASSWORD in .env
docker compose up -d --build
docker compose ps                      # all three healthy; app started after db and cache
curl localhost:8000/ready              # {"postgres":"ok","redis":"ok"}
curl -X POST localhost:8000/visits     # run a few times
curl localhost:8000/visits
```

Look inside the services:

```bash
docker compose logs -f app
docker compose exec db psql -U hello -d hello -c 'SELECT * FROM visits;'
docker compose exec cache redis-cli GET visits
docker compose exec app /hello-api healthcheck; echo $?   # 0 = healthy
```

Read [compose.yaml](../../stacks/hello-api/compose.yaml) and answer: how does the app find the database at the hostname `db`? Why does `db` have no `ports:`?

### 5. Persistence

```bash
docker compose down                    # containers and network removed…
docker compose up -d
curl localhost:8000/visits             # …but the counts survive (named volumes)

docker volume ls | grep hello-api
docker compose down -v                 # -v also removes volumes
docker compose up -d
curl localhost:8000/visits             # back to 0
```

### 6. Break it on purpose

```bash
docker compose stop db
curl -i localhost:8000/health          # 200: the process is alive
curl -i localhost:8000/ready           # 503: it can't serve real work
curl -i -X POST localhost:8000/visits  # 500
docker compose start db
curl localhost:8000/visits             # compare redis_count with db_total. Do they match?
```

The counts no longer match. Find the cause in [store.go](../../apps/hello-api/store.go) (`recordVisit`) and write it up in "What broke". Bonus: how would you fix it?

Also try:
- `docker compose restart app` and watch the logs for graceful shutdown.
- Change `POSTGRES_PASSWORD` in `.env` and run `docker compose up -d`. The app now fails to connect, because Postgres sets the password **only when the volume is first created** and keeps the old one. Watch `docker compose ps` and `logs app` to see the restart policy at work. Put the old password back afterwards (or `down -v` to start fresh).

### 7. Clean up

```bash
docker compose down -v
docker rmi hello-api:naive
```

## Results

Measured on 2026-10-08, Docker Desktop 29.7.2 on Apple Silicon (arm64).

### Image size and user

| Image | Disk usage | Content size (pulled) | Runs as |
|---|---|---|---|
| `hello-api:naive` (single stage, `golang:1.26-alpine`) | 763 MB | 145 MB | `root` |
| `hello-api:39bdd7c` (multi-stage, distroless) | **22.5 MB** | **4.93 MB** | `nonroot:nonroot` |

Final image layers (`docker history`): distroless base ≈ 5.5 MB (`tzdata` 4.24 MB, `base-files`, `cacerts`, `passwd`/`group`) + the app binary **12.1 MB**. No layers from the build stage.

### Build cache experiment

| Change | `go.mod`/`go.sum` copy | `go mod download` | `COPY . .` + `go build` | Final `COPY --from=build` | Time |
|---|---|---|---|---|---|
| First build with `VERSION=39bdd7c` (previous build used `dev`) | CACHED | CACHED | `COPY` cached, `go build` rebuilt | rebuilt | 8.1 s |
| Edited a log message in `main.go` | CACHED | CACHED | rebuilt | rebuilt | 4 s |
| Added a blank line to `go.mod` | rebuilt | rebuilt | rebuilt | **CACHED** (identical binary) | 1 s |

### Single container (`docker run`)

| Check | Result |
|---|---|
| Health status | `(health: starting)` → `(healthy)` within ~10 s |
| `GET /` | `host` = container ID `3ef53c18ffe9`, `client_ip` = `172.17.0.1` (default bridge gateway) |
| `GET /ready` | 200, Postgres and Redis `not configured` |
| `POST /visits` | 503 `visits need both DATABASE_URL and REDIS_URL` |
| `docker exec hello sh` | `exec: "sh": executable file not found in $PATH` |
| `docker stop hello` | Logged `shutting down`, exit code **0** |
| Logs | ~60 of ~70 lines were `/health` checks every 10 s |

### Compose stack

| Check | Result |
|---|---|
| Startup order | `db` + `cache` started → `Healthy` after ~5.7 s → `app` started |
| Published ports | app `127.0.0.1:8000->8000`; db `5432/tcp` and cache `6379/tcp` internal only |
| `GET /ready` | 200, `{"postgres":"ok","redis":"ok"}` |
| 3 × `POST /visits` | counts 1 → 2 → 3 in both stores |
| `SELECT * FROM visits` | 3 rows, `client_ip` = `172.21.0.1` (Compose network gateway) |
| `redis-cli GET visits` | `"3"` |
| `down` → `up` | `{"redis_count":3,"db_total":3}`: volumes kept |
| `down -v` → `up` | `{"redis_count":0,"db_total":0}`: volumes removed |

### DB stopped (`docker compose stop db`)

| Endpoint | Status | Body / log |
|---|---|---|
| `GET /health` | **200** | `{"status":"ok"}` |
| `GET /ready` | **503** | Postgres: `lookup db on 127.0.0.11:53: no such host`; Redis `ok` |
| `POST /visits` | **500** | `{"error":"internal error"}`; real error only in app logs; request took ~9.7 ms vs ~0.2 ms for `/health` |
| After `start db` | | `/ready` back to 200 without restarting the app; `/visits` = `{"redis_count":2,"db_total":0}` |

## Code

- [apps/hello-api/](../../apps/hello-api/): app, Dockerfile, `.dockerignore`
- [stacks/hello-api/](../../stacks/hello-api/): Compose stack

## What broke

### 1. `No such image: hello-api:39bdd7c`

- **Symptom:** `docker history hello-api:$(git describe …)` failed.
- **Cause:** I ran `docker history` before `make docker-build`, so only `hello-api:naive` existed.
- **Fix:** build first. `docker images hello-api` shows which tags actually exist. The tag also becomes `<sha>-dirty` while files are edited.

### 2. `no configuration file provided: not found`

- **Symptom:** `docker compose exec db psql …` failed.
- **Cause:** I was in `apps/hello-api`; Compose looks for `compose.yaml` in the current directory.
- **Fix:** `cd stacks/hello-api`, or `docker compose -f <path>/compose.yaml …`.

### 3. Visit counts drifted apart: `redis_count: 2`, `db_total: 0`

- **Symptom:** after the DB was stopped and started again, Redis and Postgres disagreed.
- **Cause:** `recordVisit` in [store.go](../../apps/hello-api/store.go) runs `INCR` in Redis first, then `INSERT` in Postgres. With the DB down, each `POST` returned 500, but the Redis increment had already happened and nothing undid it: a **partial write** across two systems.
- **Fix I would choose:** _TODO: your choice and why_

## Lessons learned

_TODO: write these in your own words. Prompts:_

- **Image size:** what made up the 763 MB → 22.5 MB difference, and why it matters for deploys.
- **Layer cache:** why the order of `COPY` lines matters; what invalidates the cache (including build args).
- **Distroless:** what you gain and what you lose (debugging without a shell).
- **Liveness vs readiness:** what `/health` and `/ready` did with the DB down, and which one should trigger a restart.
- **Networking errors:** `no such host` vs `connection refused` vs `timeout` vs authentication errors, and which layer each points to.
- **Volumes:** containers are disposable, data lives in volumes; what `down -v` would mean on a real server.
- **Published ports:** `127.0.0.1:8000` vs `0.0.0.0` (compare with the `docker-redis-1` container on this Mac).
- **Logging:** `/health` noise, and no status code in the request log.

## References

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
