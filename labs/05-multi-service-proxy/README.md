# Lab 05 — Multi-service reverse proxy

- **Phase:** 2 — Containers
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker Desktop on the Mac; Let's Encrypt part on the VPS later

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Run several apps behind one entry point, each on its own subdomain with HTTPS, and add new apps without touching the proxy config.

## Done when

**Local (Mac)**
- [ ] Traefik running from [stacks/traefik](../../stacks/traefik/), the only container with published ports
- [ ] At least two services on separate subdomains (`api.` and `whoami.opsforge.localhost`)
- [ ] HTTP redirects to HTTPS
- [ ] Dashboard reachable only with basic auth
- [ ] Locally trusted HTTPS with mkcert (browser padlock, no warning)
- [ ] A new service added with labels only, no Traefik config change or restart
- [ ] [ADR 0003](../../docs/decisions/0003-traefik-as-reverse-proxy.md) read and agreed (or changed)

**On the VPS (later)**
- [ ] Let's Encrypt certificates issued and renewed automatically by Traefik

## Architecture

```
                      ┌─────────────── proxy network ───────────────┐
Browser ──HTTPS:443──▶│ Traefik ──▶ whoami      (whoami.opsforge.localhost)
        ──HTTP:80 ───▶│    │    ──▶ hello-api   (api.opsforge.localhost) ──┐
        (301 → 443)   │    └──────▶ dashboard   (traefik.opsforge.localhost)│
                      └───────────────────────────────────────────────┼─┘
                                     hello-api default network:  db, cache
```

- **One shared Docker network, `proxy`.** Traefik and every web-facing container join it. Databases don't.
- **Routing comes from Docker labels** on each container. Traefik watches Docker and updates itself live.
- **Domains:** `*.localhost` always resolves to `127.0.0.1` in Chrome, Firefox, and curl, so no `/etc/hosts` editing is needed. Safari may not resolve these names; use Chrome for this lab.

## Files

| File | What it is |
|---|---|
| [stacks/traefik/compose.yaml](../../stacks/traefik/compose.yaml) | Traefik container: ports, Docker socket, dashboard labels |
| [stacks/traefik/traefik.yml](../../stacks/traefik/traefik.yml) | **Static** config: entry points, providers, dashboard |
| [stacks/traefik/dynamic/middlewares.yml](../../stacks/traefik/dynamic/middlewares.yml) | **Dynamic** config: basic-auth middleware |
| [stacks/traefik/dynamic/tls.yml.example](../../stacks/traefik/dynamic/tls.yml.example) | Default certificate (mkcert), enabled in step 5 |
| [stacks/whoami/compose.yaml](../../stacks/whoami/compose.yaml) | Test service that echoes request headers |
| [stacks/hello-api/compose.traefik.yaml](../../stacks/hello-api/compose.traefik.yaml) | Override: hello-api behind Traefik instead of a published port |

Git-ignored, created by you: `stacks/traefik/secrets/dashboard-users`, `stacks/traefik/certs/*.pem`, `stacks/traefik/dynamic/tls.yml`.

## Steps

All commands run from the repo root unless a `cd` says otherwise.

### 0. Prerequisites

```bash
docker version                 # Server must show a version; if not, start Docker Desktop
lsof -nP -iTCP:80 -iTCP:443 -sTCP:LISTEN || echo "80/443 free"
```

Ports 80 and 443 must be free. Stop anything else using them first.

### 1. Create the shared network

```bash
docker network create proxy
docker network ls | grep proxy
```

Every stack declares `proxy` as `external: true`, so no single stack owns it, and `docker compose down` in one stack can't delete it from under the others.

### 2. Dashboard password

```bash
htpasswd -nB admin > stacks/traefik/secrets/dashboard-users   # asks for a password
cat stacks/traefik/secrets/dashboard-users                    # admin:$2y$05$...  (bcrypt hash, not the password)
```

### 3. Start Traefik

```bash
cd stacks/traefik
docker compose up -d
docker compose logs -f         # Ctrl+C when it settles; there should be no ERR lines
```

Then open:
- `http://traefik.opsforge.localhost/` → redirected to HTTPS
- Your browser warns about the certificate. That's expected: it's `TRAEFIK DEFAULT CERT`, self-signed. Continue anyway for now; step 5 fixes it.
- Log in with `admin` and your password, then look around the dashboard: **Routers**, **Services**, **Middlewares**.

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://traefik.opsforge.localhost/dashboard/            # 401
curl -sk -o /dev/null -w '%{http_code}\n' -u admin https://traefik.opsforge.localhost/dashboard/   # 200 (asks for password)
curl -sk -o /dev/null -w '%{http_code}\n' https://nope.opsforge.localhost/                         # 404: no router matches
```

### 4. Add services, with labels only

**whoami:**

```bash
cd ../whoami
docker compose up -d
curl -sk https://whoami.opsforge.localhost/
```

Read the output. Which headers did Traefik add? Compare `RemoteAddr` (who connected to whoami) with `X-Real-Ip` and `X-Forwarded-For` (who connected to Traefik).

**hello-api, through Traefik:**

```bash
cd ../hello-api
docker compose -f compose.yaml -f compose.traefik.yaml up -d --build
docker compose -f compose.yaml -f compose.traefik.yaml ps   # app shows 8000/tcp, no 127.0.0.1:8000
curl -sk https://api.opsforge.localhost/ready
curl -sk -X POST https://api.opsforge.localhost/visits
curl -s -m 2 http://127.0.0.1:8000/ || echo "not reachable directly, as intended"
```

Read [compose.traefik.yaml](../../stacks/hello-api/compose.traefik.yaml). It's an **override file**: Compose merges it on top of `compose.yaml`. `ports: !reset []` removes the published port, and the app joins both networks: `default` for db and cache, `proxy` for Traefik.

Check the dashboard: the new routers appeared **without restarting Traefik**.

### 5. Trusted local HTTPS with mkcert

```bash
brew install mkcert
mkcert -install                # adds a local CA to your Mac's keychain (asks for your password)
cd stacks/traefik
mkcert -cert-file certs/local.pem -key-file certs/local-key.pem \
  "opsforge.localhost" "*.opsforge.localhost"
cp dynamic/tls.yml.example dynamic/tls.yml
```

There's no restart needed: the file provider watches `dynamic/`. Then check:

```bash
echo | openssl s_client -connect 127.0.0.1:443 -servername api.opsforge.localhost 2>/dev/null \
  | openssl x509 -noout -subject -issuer   # issuer: mkcert development CA
curl -s https://api.opsforge.localhost/   # works WITHOUT -k now
```

Reload the browser tabs. They should now show a padlock with no warning.

> ⚠️ Why `tls.yml` is copied only now: if it points to certificate files that don't exist, Traefik fails to build the certificate store, and HTTPS stops working entirely instead of falling back.

### 6. Watch and break

```bash
docker logs -f traefik-traefik-1        # access log: client, status, router, backend, duration
```

Try, and note what you see:
- `docker compose -f compose.yaml -f compose.traefik.yaml stop app` in `stacks/hello-api`, then `curl -sk https://api.opsforge.localhost/`. What status do you get, and why isn't it a 502 like with Nginx in lab 02? (Hint: what happens to the router when its container disappears? Check the dashboard.)
- Change the `Host` rule label for whoami to `hi.opsforge.localhost` and run `docker compose up -d`. How fast does the new name work?
- Remove `traefik.enable=true` from whoami. What happens, and why? (`exposedByDefault: false`)

### 7. Let's Encrypt — do this on the VPS

On a VPS with a real domain whose DNS points at it, Traefik requests and renews certificates itself. Add to `traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: <you@example.com>
      storage: /etc/traefik/acme/acme.json   # mount a volume here; chmod 600
      httpChallenge:
        entryPoint: web
```

Then add one label per router, publish `80:80` and `443:443` on all interfaces, and don't use `tls.yml`:

```
traefik.http.routers.whoami.tls.certresolver=letsencrypt
```

Tip: test with the staging server first (`caServer: https://acme-staging-v02.api.letsencrypt.org/directory`) so failed attempts don't hit Let's Encrypt's rate limits.

### 8. Clean up

```bash
(cd stacks/hello-api && docker compose -f compose.yaml -f compose.traefik.yaml down)
(cd stacks/whoami && docker compose down)
(cd stacks/traefik && docker compose down)
docker network rm proxy
```

Keep `secrets/`, `certs/`, and `dynamic/tls.yml` for next time. They're git-ignored.

## Code

- [stacks/traefik/](../../stacks/traefik/), [stacks/whoami/](../../stacks/whoami/), [stacks/hello-api/compose.traefik.yaml](../../stacks/hello-api/compose.traefik.yaml)
- Decision: [ADR 0003 — Traefik as the reverse proxy](../../docs/decisions/0003-traefik-as-reverse-proxy.md)

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **`API returned a 400 (Bad Request)`** from Traefik's Docker provider: Traefik v3.5 asks Docker Engine 29 for an API version it no longer supports. Fixed by using `traefik:v3.6`.
- **HTTPS completely dead** (`curl` gets no response): `tls.yml` pointed at certificate files that didn't exist yet. Fixed by enabling `tls.yml` only after the certificates are created.

## Lessons learned

## References

- [Traefik docs: Docker provider](https://doc.traefik.io/traefik/providers/docker/)
- [Traefik docs: routers](https://doc.traefik.io/traefik/routing/routers/) and [middlewares](https://doc.traefik.io/traefik/middlewares/overview/)
- [Traefik docs: Let's Encrypt](https://doc.traefik.io/traefik/https/acme/)
- [Compose: merging files](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/)
- [mkcert](https://github.com/FiloSottile/mkcert)
