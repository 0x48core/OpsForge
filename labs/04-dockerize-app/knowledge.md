# Lab 04 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

"It works on my machine" happens because machines differ: OS, library versions, config. A **container image** packs the app *and* everything it needs into one artifact that runs the same on your Mac, a VPS, CI, or Kubernetes. Almost every later lab (CI/CD, zero-downtime deploys, K3s) moves images around, so this is the foundation.

## Core concepts

### Containers vs virtual machines

```
Virtual machines                      Containers
┌──────┐ ┌──────┐                     ┌──────┐ ┌──────┐
│ App  │ │ App  │                     │ App  │ │ App  │
│ Libs │ │ Libs │                     │ Libs │ │ Libs │
│ OS   │ │ OS   │  ← full OS each     └──────┘ └──────┘
└──────┘ └──────┘                     ── one shared Linux kernel ──
── hypervisor ──                      ─────── host OS ────────
```

- A container is **just a Linux process**, isolated with kernel features:
  - **namespaces** control what it can *see*: its own process list, network, filesystem, hostname.
  - **cgroups** control how much it can *use*: CPU and memory limits.
- That's why containers start in milliseconds and are small. It's also why they share the host kernel, so isolation is weaker than a VM's.
- On a Mac, Docker Desktop runs a small Linux VM in the background, because containers need a Linux kernel.

### Image, container, registry

| Thing | Analogy | Example |
|---|---|---|
| **Image** | A class or template (read-only) | `hello-api:1.0.0` |
| **Container** | An object or running instance | `hello` started from that image |
| **Registry** | An app store for images | Docker Hub, GHCR (lab 07) |

- **Tags** (`:1.0.0`, `:latest`) are movable labels. `latest` is just a name, not "newest", so avoid it in production.
- A **digest** (`@sha256:…`) is the immutable ID of an exact image.

### Layers and the build cache

- Each Dockerfile instruction (`FROM`, `COPY`, `RUN`…) creates a **layer**. An image is a stack of read-only layers, and a running container adds a thin writable layer on top.
- Docker **caches** each layer. If an instruction and its inputs haven't changed, the cached layer is reused.
- **Once one layer changes, every layer after it is rebuilt.** So order matters: put rarely changing things first.

```dockerfile
COPY go.mod go.sum ./     # changes rarely  → cached
RUN go mod download       # slow, but cached while go.mod is unchanged
COPY . .                  # changes often   → only from here on rebuilds
RUN go build ...
```

- `RUN --mount=type=cache` keeps Go's download and build caches between builds without putting them in the image.
- **`.dockerignore`** keeps files out of the **build context** (what gets sent to the builder): faster builds, and no `.env` accidentally baked in.

### Multi-stage builds

- **Stage 1 (build):** a big image with the full toolchain (~300 MB+ for Go) compiles the binary.
- **Stage 2 (run):** a minimal base image that gets only the binary (`COPY --from=build`).
- The final image contains nothing used for building: no compiler, no source code. It's smaller, faster to pull, and has less to attack.

### Choosing a base image

| Base | Size | Shell? | Use when |
|---|---|---|---|
| `ubuntu`, `debian` | 30–80 MB | ✅ | You need system packages |
| `alpine` | ~8 MB | ✅ | Small, but uses musl libc (rarely matters for Go) |
| `distroless/static` | ~2 MB | ❌ | Static binaries such as Go with `CGO_ENABLED=0` |
| `scratch` | 0 | ❌ | Absolutely nothing: no CA certs, no users, no timezone data |

**Distroless** has no shell or package manager. An attacker who gets in can't easily run tools, and there's less for vulnerability scanners to flag. The trade-off is that you can't `docker exec … sh` to debug, and healthchecks can't use `curl`. That's why hello-api has a built-in `healthcheck` subcommand.

### Running as non-root

- By default, processes in a container run as **root (UID 0)**. If an attacker escapes the container, root inside can mean root on the host.
- `USER nonroot` (UID 65532 in distroless) limits the damage. Ports below 1024 need root, so the app listens on 8000.

### PID 1 and signals

- The `ENTRYPOINT` process is **PID 1** inside the container.
- `docker stop` sends **SIGTERM** to PID 1, waits 10 seconds, then sends **SIGKILL**.
- **Exec form** `ENTRYPOINT ["/hello-api"]` runs the app directly as PID 1, so it receives SIGTERM.
- **Shell form** `ENTRYPOINT /hello-api` runs `/bin/sh -c …`. The shell becomes PID 1 and often *doesn't pass the signal on*, so the app gets killed after 10 seconds with no graceful shutdown.

### Docker Compose

Compose describes a multi-container app in one YAML file:

- **services**: each becomes one or more containers.
- **networks**: Compose creates a private network per project. Services reach each other **by service name** (`db`, `cache`) through Docker's built-in DNS.
- **volumes**: persistent storage.
- **`depends_on` + `condition: service_healthy`**: start the app only after the DB passes its healthcheck. Without the condition, Compose only waits for the DB container to *start*, not to be *ready*.
- **`.env`**: Compose reads it automatically and substitutes `${VAR}`. `$$` escapes a `$` so the container's shell expands it instead.

### Ports: publish vs expose

- Inside the Compose network, every service can reach every other service's ports. **Nothing needs to be published for that.**
- **`ports: "127.0.0.1:8000:8000"`** publishes to the **host**, here only on localhost.
- **`ports: "8000:8000"`** publishes on **all interfaces**. On a VPS that means public, and **Docker bypasses ufw** (lab 01).
- Rule: publish only what must be reachable from outside, and bind to `127.0.0.1` when a reverse proxy sits in front (lab 05).

### Volumes and persistence

- A container's writable layer is **thrown away** when the container is removed.
- **Named volumes** (`db-data:`) are managed by Docker and survive `down`/`up`. `down -v` deletes them.
- **Bind mounts** (`./data:/data`) map a host folder: handy for development and config files.
- Databases **must** use a volume, or every redeploy loses your data.

### Healthchecks: liveness vs readiness

| Check | Question | hello-api | If it fails |
|---|---|---|---|
| **Liveness** | Is the process alive and not stuck? | `/health` | Restart it |
| **Readiness** | Can it serve real traffic right now? | `/ready` | Don't send it traffic, but don't restart |

If the DB is down, restarting the app won't fix anything. That's why the Docker `HEALTHCHECK` uses liveness only. Kubernetes (lab 12) has separate liveness and readiness probes built on exactly this idea.

### Restart policies

`no` (default) · `on-failure` · `always` · `unless-stopped` (like `always`, but respects a manual stop). It's the container equivalent of systemd's `Restart=` from lab 02.

### Twelve-factor config

Config comes from **environment variables** (`DATABASE_URL`, `REDIS_URL`), not from files baked into the image. One image then runs in dev, staging, and prod with different settings. Secrets stay out of the image and out of git (`.env` is git-ignored; commit `.env.example`).

## Key terms

| Term | Meaning |
|---|---|
| Build context | The files sent to the builder (filtered by `.dockerignore`) |
| Layer | The filesystem change made by one Dockerfile instruction |
| Multi-stage | Several `FROM`s; copy only the artifacts into the final stage |
| Distroless | Minimal images with no shell or package manager |
| Named volume | Docker-managed persistent storage |
| Service discovery | Finding other containers by name through Docker DNS |
| Liveness / readiness | "Is it alive?" vs "Can it do work?" |
| Exec vs shell form | `["cmd"]` runs directly as PID 1; `cmd` runs through `/bin/sh -c` |

## Commands to know

| Command | What it does |
|---|---|
| `docker build -t name:tag .` | Build an image |
| `docker images` / `docker history <img>` | List images / show layers and sizes |
| `docker run -d --name x -p 127.0.0.1:8000:8000 <img>` | Run detached, publish on localhost |
| `docker ps` / `docker ps -a` | Running / all containers |
| `docker logs -f <c>` | Follow logs |
| `docker exec -it <c> <cmd>` | Run a command inside a container |
| `docker inspect <c>` | Full JSON details (network, mounts, health) |
| `docker compose up -d --build` | Build and start the stack |
| `docker compose ps` / `logs -f <svc>` | Status / logs of the stack |
| `docker compose down [-v]` | Stop and remove (and volumes, with `-v`) |
| `docker system df` / `docker system prune` | Disk usage / clean unused data |

## Before you start, can you answer these?

1. What's the difference between an image and a container?
2. Why do we `COPY go.mod go.sum` and download modules *before* `COPY . .`?
3. Why is the final image so much smaller than the build stage?
4. How does the app container find Postgres at `db:5432`?
5. What happens to a database's data if it has no volume and you run `docker compose down`?

## After the lab, check yourself

1. What were the naive and final image sizes, and what made up the difference?
2. Why can't you `docker exec` into the app with `sh`? Is that a problem?
3. Why does `/health` stay 200 while `/ready` returns 503 when the DB is down? Which one should trigger a restart?
4. What would change if `ENTRYPOINT` used shell form?
5. Why are the DB and Redis not published to the host, and why is the app bound to `127.0.0.1`?
6. Why did `redis_count` and `db_total` drift apart, and how would you fix it?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Docker overview](https://docs.docker.com/get-started/docker-overview/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Build cache](https://docs.docker.com/build/cache/)
- [Compose: networking](https://docs.docker.com/compose/how-tos/networking/) and [startup order](https://docs.docker.com/compose/how-tos/startup-order/)
- [The Twelve-Factor App](https://12factor.net/)
- [What even is a container? (Julia Evans)](https://jvns.ca/blog/2016/10/10/what-even-is-a-container/)
