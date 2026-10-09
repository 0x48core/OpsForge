# Lab 07 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Until now, every build and deploy was you typing commands. That's slow, easy to get wrong, and impossible to audit. **CI/CD** turns the path from "commit" to "running in production" into code that runs the same way every time, and that stops bad changes early.

| Term | Meaning |
|---|---|
| **CI** (Continuous Integration) | Every change is built and tested automatically, so problems show up in minutes, not at release time |
| **CD** (Continuous Delivery) | Every change that passes is *ready* to deploy, as a versioned artifact |
| **CD** (Continuous Deployment) | Every change that passes *is* deployed, with no human step |

This lab builds CI plus continuous delivery (the GHCR image). The `deploy` job is continuous deployment, which you can gate with a required reviewer.

## Core concepts

### GitHub Actions vocabulary

```
Workflow (.github/workflows/hello-api.yml)
 └── triggered by events (push, pull_request, workflow_dispatch)
     └── Jobs (test, integration, image, deploy): each on a fresh VM ("runner")
         └── Steps: a shell command (run:) or a reusable action (uses:)
```

- **Jobs run in parallel** by default. `needs:` makes them a chain, and a failed job skips everything that needs it.
- **Each job gets a clean VM.** Nothing is shared unless you pass it on (`outputs:`, artifacts, or a registry).
- **`if:`** conditions skip jobs (`github.ref == 'refs/heads/main'`).
- **`paths:`** filters skip the whole workflow when unrelated files change.
- **Contexts** like `${{ github.sha }}`, `${{ secrets.X }}`, and `${{ vars.X }}` are filled in before the step runs.

### The test pyramid

```
        ▲  few, slow, realistic
       ╱ ╲   smoke test on the live site (after deploy)
      ╱───╲  integration: real Postgres + Redis via Compose
     ╱─────╲ unit tests: handlers with httptest, no network
    ▔▔▔▔▔▔▔▔▔ many, fast, isolated
```

Unit tests catch logic errors in milliseconds. Integration tests catch "works alone, breaks together" problems: wrong env vars, SQL errors, startup order. The smoke test answers "is the thing we just deployed actually working, and is it the right version?" **Fail fast:** cheap checks run first, so expensive ones don't waste time.

### Build once, deploy the same artifact

- The image is built **once**, in CI, tagged with the **commit SHA** (`sha-1a2b3c4`), and that exact image goes to every environment.
- **Never rebuild on the server.** A rebuild could pull different base images or dependencies, so what you tested isn't what you run.
- SHA tags are **immutable and traceable**: from a running container you can find the exact commit. `main` is a convenience tag that **moves**, like `latest`. Deploy by SHA, not by `main`.
- The version is baked in (`-X main.version=sha-…`), so `/` reports it, and the smoke test checks the deploy really switched.

### Container registries and GHCR

- A registry stores images. GHCR is `ghcr.io/<owner>/<name>:<tag>`.
- **`GITHUB_TOKEN`** is a short-lived token GitHub creates for each run. With `permissions: packages: write`, it can push to GHCR, so no long-lived password is needed.
- New packages are private. The server needs a `read:packages` token, or the package must be public.

### Multi-architecture images

- Your Mac is **arm64**, and most VPSs are **amd64**. One tag can serve both: a **manifest list** points to one image per platform, and `docker pull` picks the right one automatically.
- Building arm64 on an amd64 runner the slow way means **QEMU emulation**. For Go there's a fast way:

  ```dockerfile
  FROM --platform=$BUILDPLATFORM golang:… AS build   # compiler runs natively
  ARG TARGETOS TARGETARCH
  RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build …   # Go cross-compiles
  ```

  The final stage (distroless) is pulled for the *target* platform. No emulation is needed.

### Build cache in CI

Each runner is fresh, so Docker's layer cache is empty every time. `cache-from/cache-to: type=gha` stores layers in GitHub's cache between runs, so the `go mod download` layer from lab 04 stays cached in CI too.

### Secrets and least privilege

| Rule | In this workflow |
|---|---|
| Secrets live in the CI system, never in git | `DEPLOY_SSH_KEY` and others in the `production` environment |
| Least privilege by default | `permissions: contents: read` at the top; `packages: write` only for `image` |
| A key per purpose | A deploy-only SSH key, a dedicated `deploy` user |
| Pin what you trust | `DEPLOY_KNOWN_HOSTS` pins the server's host key. **Never** `StrictHostKeyChecking=no`, which lets anyone pretend to be your server |
| Don't paste untrusted input into scripts | Values go through `env:` instead of `${{ … }}` inside `run:`, which avoids script injection |
| Forked PRs get no secrets | GitHub's default, so a stranger's PR can't read your deploy key |

**Environments** (`production`) add their own secrets, optional **required reviewers**, and a deploy history.

### The `docker` group is root

Adding `deploy` to the `docker` group lets it run `docker run -v /:/host …`, which is root on the server (as with Portainer in lab 06). It's the common, pragmatic setup, but know the trade-off. Stricter options are rootless Docker, or a `sudo` rule that allows only `deploy.sh`.

### Supply-chain safety for actions

`uses: actions/checkout@v5` runs someone else's code with access to your workflow. Tags like `v5` can be moved. Hardening options:
- Use few third-party actions; this workflow uses only `actions/*` and `docker/*`.
- Pin actions to a **full commit SHA** (`uses: actions/checkout@<sha> # v5`), and let **Dependabot** propose updates.

### Concurrency

- `cancel-in-progress: true` per branch: if you push twice quickly, the first run is cancelled, so you don't waste minutes.
- The deploy uses its own group with `cancel-in-progress: false`: **never kill a deploy halfway**, and never run two at once.

### Self-hosted runners (stretch)

A runner is an agent that runs jobs. GitHub-hosted runners are fresh VMs. A **self-hosted** runner runs on your own machine (e.g. the VPS), so a deploy needs no SSH from outside. ⚠️ **Never use self-hosted runners on a public repo**: anyone's PR could run code on your server.

## Key terms

| Term | Meaning |
|---|---|
| Workflow / job / step | Pipeline file / a unit that runs on one runner / one command or action |
| Runner | The machine executing a job |
| Artifact | The build output you deploy (here: the image) |
| Immutable tag | A tag that never points to anything else (`sha-…`) |
| Manifest list | One tag → several images, one per platform |
| `GITHUB_TOKEN` | Per-run token with permissions set in the workflow |
| Environment (GitHub) | A deploy target with its own secrets and protection rules |
| Smoke test | A quick check that a deployed system basically works |

## Commands to know

| Command | What it does |
|---|---|
| `make test` | `go vet` + `go test -race` for hello-api |
| `scripts/smoke-test.sh <url> [version]` | Check a running instance |
| `stacks/hello-api/deploy.sh <tag>` | Deploy a tag on a server |
| `docker buildx build --platform linux/amd64,linux/arm64 …` | Multi-arch build |
| `docker buildx imagetools inspect <image>` | Show a tag's platforms |
| `docker compose up -d --wait` | Start and wait until healthy (fails otherwise) |
| `ssh-keyscan -p <port> <host>` | Fetch a server's host key for `known_hosts` |
| `actionlint` | Lint GitHub Actions workflows |

## Before you start, can you answer these?

1. Why does the `image` job run only on pushes to `main`, not on PRs?
2. Why tag images with the commit SHA instead of only `latest` or `main`?
3. What would go wrong if the server ran `docker compose build` instead of pulling the CI image?
4. Why is `StrictHostKeyChecking=no` dangerous in a deploy job?
5. What's the difference between the unit tests and the integration test here?

## After the lab, check yourself

1. Draw the pipeline, and say what each job proves.
2. Which permissions does each job have, and why?
3. A deploy succeeded but users still see the old version. Which part of this pipeline would catch that?
4. How does one image tag serve both your Mac and an amd64 VPS?
5. What's the risk of the `deploy` user being in the `docker` group, and what alternatives exist?
6. What happened to the running app during `deploy.sh` switching tags, and why is that a problem?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [GitHub Actions: understanding workflows](https://docs.github.com/en/actions/get-started/understand-github-actions)
- [GitHub Actions: secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [Martin Fowler: Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html)
- [Docker: multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
- [The test pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
