# Lab 07 — CI/CD pipeline

- **Phase:** 3 — CI/CD
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** GitHub Actions; deploy target is a VPS (switched off until one exists)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Every change to hello-api is tested automatically; every merge to `main` produces a versioned image in a registry and, once a VPS exists, is deployed and verified without anyone touching the server.

## Done when

**Now (no VPS needed)**
- [ ] Pipeline runs unit tests and an integration test on every push and PR
- [ ] A PR with a failing test shows a red check (and is not merged)
- [ ] Merging to `main` pushes `ghcr.io/0x48core/hello-api:sha-<commit>` (amd64 + arm64)
- [ ] You can pull that image on your Mac and run it
- [ ] `deploy.sh` rehearsed locally with two tags

**With a VPS**
- [ ] Deploys to the VPS over SSH as a dedicated, limited `deploy` user
- [ ] Secrets stored only in GitHub secrets (and the server's `.env`)
- [ ] The deploy smoke-tests the live URL and checks the version
- [ ] Stretch: a self-hosted runner on the VPS

## The pipeline

```
push / PR ──▶ test ──────────▶ integration ─────────────▶ image ─────────────▶ deploy
              gofmt, vet,      docker compose up --wait,   main only:          main only, if
              go test -race    smoke-test.sh               multi-arch build,   DEPLOY_ENABLED=true:
                                                           push to GHCR        ssh → deploy.sh → smoke test
```

| File | Role |
|---|---|
| [.github/workflows/hello-api.yml](../../.github/workflows/hello-api.yml) | The pipeline |
| [apps/hello-api/main_test.go](../../apps/hello-api/main_test.go) | Unit tests (`make test`) |
| [scripts/smoke-test.sh](../../scripts/smoke-test.sh) | Checks a running instance: health, readiness, version, a real write |
| [stacks/hello-api/compose.deploy.yaml](../../stacks/hello-api/compose.deploy.yaml) | Override: use the GHCR image instead of building |
| [stacks/hello-api/deploy.sh](../../stacks/hello-api/deploy.sh) | Pull, `up --wait`, report the running image |
| [apps/hello-api/Dockerfile](../../apps/hello-api/Dockerfile) | Now cross-compiles for multi-arch builds (`$BUILDPLATFORM`) |

## Steps

### 1. Run the checks locally first

The pipeline should only run what you can also run yourself:

```bash
cd apps/hello-api
gofmt -l .          # no output = formatted
make test           # go vet + go test -race
cd ../..
```

Read [main_test.go](../../apps/hello-api/main_test.go). It tests the routes **without a server or network**, using `httptest`. That's why `main.go` now has a `newMux(st)` function.

Then the integration test, exactly as CI runs it:

```bash
cd stacks/hello-api
docker compose up -d --build --wait     # uses your .env
../../scripts/smoke-test.sh http://localhost:8000 dev
docker compose down -v
cd ../..
```

### 2. Read the workflow

Open [hello-api.yml](../../.github/workflows/hello-api.yml) and find:
- the **triggers** (`on:`) and their `paths:` filter. Why doesn't a change to `labs/` run the pipeline?
- `needs:` chaining the jobs
- `if:` limiting `image` to pushes on `main`, and `deploy` to when `DEPLOY_ENABLED` is set
- `permissions:`: read-only by default, `packages: write` only for the `image` job
- the two `concurrency:` blocks: one cancels outdated runs, the other never cancels a deploy

### 3. Watch it run on a PR

Push this branch and open the PR. On the PR page, the **Checks** section shows `Lint and unit tests` and `Integration test`. Open the **Actions** tab to see each step's logs.

`image` and `deploy` are **skipped** on a PR. That's on purpose: only reviewed, merged code becomes an image.

### 4. Break it on purpose

On a throwaway branch:

```bash
git checkout -b test/break-ci
sed -i '' 's/"status": "ok"/"status": "fine"/' apps/hello-api/main.go
git commit -am "test: break health response" && git push -u origin test/break-ci
```

Open a PR from it and watch `Lint and unit tests` fail. Find **which test** failed in the log. Then close the PR and delete the branch:

```bash
git checkout lab/07-cicd-pipeline
git push origin --delete test/break-ci && git branch -D test/break-ci
```

Optional: in GitHub **Settings → Branches**, add a rule for `main` that requires these checks to pass before merging. That makes a red pipeline actually block the merge.

### 5. Merge, and pull the image

After merging, the push to `main` runs all of `test → integration → image`. When it's green:
1. Go to your GitHub profile → **Packages** → `hello-api`, and see the tags `sha-<commit>` and `main`.
2. New packages are **private**. Either make it public (**Package settings → Change visibility**), or log in from your Mac with a personal access token that has `read:packages`:

   ```bash
   echo <TOKEN> | docker login ghcr.io -u 0x48core --password-stdin
   ```

3. Pull and run it:

   ```bash
   docker pull ghcr.io/0x48core/hello-api:sha-<commit>
   docker image inspect ghcr.io/0x48core/hello-api:sha-<commit> --format '{{.Architecture}}'   # arm64 on your Mac
   docker run --rm -p 127.0.0.1:8000:8000 ghcr.io/0x48core/hello-api:sha-<commit>
   curl localhost:8000/                   # "version": "sha-<commit>"
   ```

The same tag pulls **amd64** on a typical VPS. That's a multi-arch image: one tag, a manifest list pointing to one image per architecture.

### 6. Rehearse the deploy locally

`deploy.sh` is what CI runs on the server. Rehearse it on your Mac. You need the `proxy` network from lab 05 and a `.env` in `stacks/hello-api`.

```bash
docker pull ghcr.io/0x48core/hello-api:sha-<commit>       # or build: docker build --build-arg VERSION=sha-test -t ghcr.io/0x48core/hello-api:sha-test apps/hello-api
PULL=0 stacks/hello-api/deploy.sh sha-<commit>
docker ps --filter name=hello-api-app
```

Deploy a second tag and watch `docker ps` during the switch. The container is **recreated**: the old one stops before the new one is healthy. Note how long the gap is. Lab 08 removes it.

Clean up:

```bash
(cd stacks/hello-api && APP_VERSION=x docker compose -f compose.yaml -f compose.traefik.yaml -f compose.deploy.yaml down -v)
```

### 7. Turn on deploys (when you have a VPS)

On the VPS, after labs 01, 05 (Traefik with Let's Encrypt), and Docker installed:

```bash
# a dedicated deploy user that can run Docker, and nothing else special
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy           # ⚠️ docker group = root-equivalent; see knowledge.md
sudo -u deploy mkdir -p ~deploy/opsforge/stacks/hello-api
# create ~deploy/opsforge/stacks/hello-api/.env with a strong POSTGRES_PASSWORD
```

On your Mac, create a key used **only** for deploys:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/opsforge_deploy -C "github-actions-deploy" -N ""
ssh-copy-id -i ~/.ssh/opsforge_deploy.pub -p <SSH_PORT> deploy@<VPS_IP>
ssh-keyscan -p <SSH_PORT> <VPS_IP>        # copy the output for DEPLOY_KNOWN_HOSTS
```

In GitHub, **Settings → Environments → New environment → `production`**, add:

| Kind | Name | Value |
|---|---|---|
| Secret | `DEPLOY_SSH_KEY` | Contents of `~/.ssh/opsforge_deploy` (the **private** key) |
| Secret | `DEPLOY_KNOWN_HOSTS` | `ssh-keyscan` output |
| Secret | `DEPLOY_HOST` | `<VPS_IP>` |
| Secret | `DEPLOY_PORT` | `<SSH_PORT>` |
| Secret | `DEPLOY_USER` | `deploy` |
| Variable | `DEPLOY_URL` | `https://api.<domain>` |

Then **Settings → Variables → Actions → New repository variable**: `DEPLOY_ENABLED` = `true`.

If the GHCR package is private, log the server in once as `deploy`: `docker login ghcr.io` with a `read:packages` token.

Push any change under `apps/hello-api/`, and watch the `deploy` job run `deploy.sh` over SSH and smoke-test the live URL.

Optional: add yourself as a **required reviewer** on the `production` environment, so every deploy waits for your click.

## Code

- [.github/workflows/hello-api.yml](../../.github/workflows/hello-api.yml)
- [apps/hello-api/main_test.go](../../apps/hello-api/main_test.go), [scripts/smoke-test.sh](../../scripts/smoke-test.sh)
- [stacks/hello-api/compose.deploy.yaml](../../stacks/hello-api/compose.deploy.yaml), [stacks/hello-api/deploy.sh](../../stacks/hello-api/deploy.sh)

## What broke

_Write down errors and fixes here as you go._

Verified while preparing this lab:
- `actionlint` and `shellcheck` report no issues; unit tests pass with `-race`.
- Integration job rehearsed locally: stack healthy, smoke test passes, and a wrong expected version makes it fail.
- Multi-arch build works locally (amd64 + arm64); the amd64 variant runs and passes its healthcheck.
- `deploy.sh` rehearsed with two tags; the running version matched each time. The switch has a short outage (→ lab 08).

## Lessons learned

## References

- [GitHub Actions: workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Actions: security hardening](https://docs.github.com/en/actions/reference/security/secure-use)
- [Publishing Docker images to GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker: multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
- [Docker build cache in GitHub Actions](https://docs.docker.com/build/ci/github-actions/cache/)
