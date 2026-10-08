# Lab 04 — Dockerize an app

- **Phase:** 2 — Containers
- **Status:** 🟨 in progress
- **Started / finished:** YYYY-MM-DD / —
- **Environment:** Docker Desktop on the Mac (no server needed)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Package [hello-api](../../apps/hello-api/) as a small, production-ready image and run it with PostgreSQL and Redis using Docker Compose.

## Done when

- [ ] Multi-stage Dockerfile; image size noted before and after (naive vs final)
- [ ] Container runs as a non-root user
- [ ] `compose.yaml` runs app + PostgreSQL + Redis
- [ ] Data persists in named volumes across `down`/`up`; `down -v` wipes it
- [ ] Healthchecks defined; the app waits for healthy dependencies
- [ ] Only the app is published, and only on `127.0.0.1`
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

## Code

- [apps/hello-api/](../../apps/hello-api/): app, Dockerfile, `.dockerignore`
- [stacks/hello-api/](../../stacks/hello-api/): Compose stack

## What broke

_Write down errors and fixes here as you go._

## Lessons learned

## References

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
