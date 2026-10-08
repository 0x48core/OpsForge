# Lab 02 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Almost every web service in production looks like this:

```
Browser ──HTTPS──▶ Nginx (port 443) ──HTTP──▶ App (127.0.0.1:8000)
                   TLS, routing, logs          business logic only
```

Nginx sits in front and handles the work every app needs: encryption, routing by domain, static files, timeouts, and logs. The app is kept private and only does its own job. A process manager (systemd) keeps the app running. Learn this pattern once and Docker, Traefik, and Kubernetes Ingress later all feel familiar.

## Core concepts

### HTTP basics

HTTP is plain-text request and response.

```
GET /health HTTP/1.1          ← method, path, version
Host: app.opsforge.test       ← which site (one IP can host many)
User-Agent: curl/8.7.1

HTTP/1.1 200 OK               ← status
Content-Type: application/json

{"status":"ok"}               ← body
```

- **Methods:** `GET` reads, `POST` creates, `PUT`/`PATCH` updates, `DELETE` removes.
- **Status codes:** `2xx` success, `3xx` redirect (`301` permanent), `4xx` client error (`404` not found), `5xx` server error.
- **Codes you'll debug most behind a proxy:**
  - `502 Bad Gateway`: Nginx couldn't talk to the app (it's down or on the wrong port).
  - `504 Gateway Timeout`: the app took too long to answer.
- **The `Host` header** is how one server with one IP serves many domains.
- `curl -v` shows the full request and response. Use it all the time.

### DNS and `/etc/hosts`

- **DNS** turns a name into an IP: an `A` record maps to IPv4, `AAAA` to IPv6, and `CNAME` points to another name.
- Your computer checks **`/etc/hosts` first**, before asking DNS. That's how this lab fakes `opsforge.test` locally.
- On the VPS you'll create real `A` records at your domain registrar or DNS provider. Changes can take minutes (the TTL) to spread.
- `.test` is reserved by RFC 2606 and will never be a real public domain.

### Nginx

- An event-driven web server. One **master** process reads the config and manages several **worker** processes, which handle thousands of connections each.
- Config lives in `/etc/nginx/`. On Ubuntu, sites go in `sites-available/` and are switched on with a **symlink** in `sites-enabled/`.
- A **`server` block** is one virtual host. Nginx picks it by `listen` port plus **`server_name`** matched against the `Host` header. If nothing matches, it uses the default server.
- A **`location` block** matches the URL path inside a server.
- **`root` + `try_files $uri $uri/ =404`**: look for the file, then a directory, then return 404.
- **`nginx -t` before every reload.** A reload is graceful: new workers start with the new config, and old workers finish their requests. If the config is invalid, Nginx keeps running the old one.

### Reverse proxy

- A **forward proxy** acts on behalf of *clients* (e.g. a corporate proxy). A **reverse proxy** acts on behalf of *servers*: clients only ever see the proxy.
- **Why use one:** TLS in one place, many apps behind one IP, the app port isn't exposed, plus caching, rate limiting, load balancing, and zero-downtime deploys (lab 08).
- **`proxy_pass http://127.0.0.1:8000;`** forwards the request.
- **The app only sees Nginx as its client**, so you pass the original details along in headers:

| Header | Carries |
|---|---|
| `Host` | The domain the client asked for |
| `X-Real-IP` | The client's IP address |
| `X-Forwarded-For` | The chain of IPs, if there are several proxies |
| `X-Forwarded-Proto` | `http` or `https`, so the app can build correct URLs |

⚠️ An app should only trust these headers when they come from *its* proxy. Anyone can send a fake `X-Real-IP` directly. That's one more reason the app listens only on `127.0.0.1`.

### TLS / HTTPS

HTTPS is HTTP inside **TLS**, which provides:

1. **Encryption**: nobody in between can read the traffic.
2. **Integrity**: nobody can change it unnoticed.
3. **Authentication**: you're really talking to `app.opsforge.test`.

Authentication works through **certificates** and a **chain of trust**:

```
Root CA (pre-installed in your OS / browser)
  └── signs → Intermediate CA
                └── signs → your certificate (for app.opsforge.test) + your private key on the server
```

- The browser trusts your certificate because it can follow the signatures up to a root it already trusts.
- The **certificate** is public. The **private key** is secret and stays on the server (`chmod 600`).
- In the **handshake**, the server sends its certificate, the client checks the name, expiry, and chain, and the two agree on session keys.
- **Let's Encrypt** is a free, automated CA. It uses the **ACME** protocol: to prove you control a domain, Certbot answers a challenge. With **HTTP-01**, Let's Encrypt fetches a file from `http://<domain>/.well-known/acme-challenge/...`, so the domain must be public and port 80 reachable. Certificates last **90 days**, which is why auto-renewal matters.
- **mkcert** creates your own local root CA and installs it on your Mac. Your Mac trusts it, nobody else does, and that's fine for local labs. Let's Encrypt can't work here because `.test` isn't public.
- **Redirect HTTP to HTTPS** (`301`) so nobody uses the unencrypted version.

### systemd services

- **systemd** is PID 1 on Ubuntu. It starts, stops, supervises, and logs services.
- A **unit file** (`/etc/systemd/system/hello-api.service`) describes:
  - `[Unit]`: description and ordering (`After=network.target`)
  - `[Service]`: user, environment, `ExecStart`, restart policy, sandboxing
  - `[Install]`: `WantedBy=multi-user.target`, i.e. start at boot once `enable`d
- **`daemon-reload`** after editing a unit file. **`enable`** means start at boot. **`--now`** also starts it immediately.
- **`Restart=on-failure`**: restart when the process crashes or is killed by a signal, but not after a clean `systemctl stop`.
- **Logs** go to the **journal**: whatever the app writes to stdout or stderr shows up in `journalctl -u hello-api`.
- **Sandboxing:** `ProtectSystem=strict` makes the filesystem read-only for the app, `NoNewPrivileges` blocks privilege escalation, and a dedicated system user (`hello`) without a shell means a compromised app gets very little.

### Signals: SIGTERM vs SIGKILL

| Signal | Sent by | Can the app react? |
|---|---|---|
| `SIGTERM` (15) | `systemctl stop`, `docker stop`, `kill` | ✅ Yes: finish requests, then exit (**graceful shutdown**) |
| `SIGKILL` (9) | `kill -9`, the out-of-memory killer, timeouts | ❌ No: instant death |

hello-api catches `SIGTERM` and calls `srv.Shutdown()`. That's the foundation for zero-downtime deploys in lab 08.

### Go binaries (why deploying is easy)

- `go build` produces a **single static binary** with no runtime to install on the server.
- **Cross-compiling:** `GOOS=linux GOARCH=arm64 go build` builds a Linux binary on your Mac. `CGO_ENABLED=0` keeps it fully static.
- **The architecture must match the server:** `uname -m` prints `aarch64` (arm64) or `x86_64` (amd64). Running the wrong one gives `exec format error`.

## Key terms

| Term | Meaning |
|---|---|
| Virtual host | One server serving several domains, chosen by the `Host` header |
| Upstream | The backend a proxy forwards to |
| TLS termination | Decrypting HTTPS at the proxy, then forwarding plain HTTP internally |
| CA | Certificate Authority, which signs certificates |
| ACME / HTTP-01 | Let's Encrypt's protocol / its domain-ownership challenge |
| Unit | A systemd-managed thing (service, socket, timer…) |
| Journal | systemd's log store, read with `journalctl` |
| Graceful shutdown | Stop accepting new requests and finish the current ones before exiting |

## Commands to know

| Command | What it does |
|---|---|
| `curl -v` / `curl -I` | Full request and response / headers only |
| `curl --resolve app.opsforge.test:443:<IP> https://app.opsforge.test` | Test a domain without editing `/etc/hosts` |
| `nginx -t` / `systemctl reload nginx` | Test config / apply it gracefully |
| `nginx -T` | Print the full effective config |
| `tail -f /var/log/nginx/{access,error}.log` | Watch requests and errors live |
| `ss -tlnp` | Who's listening on which port |
| `systemctl status/start/stop/restart/enable <unit>` | Manage a service |
| `journalctl -u <unit> -f` | Follow a service's logs |
| `openssl s_client -connect <host>:443 -servername <host>` | Inspect a TLS certificate |
| `dig +short <domain>` | Check what a DNS name resolves to |

## Before you start, can you answer these?

1. How does one Nginx on one IP know whether to serve `opsforge.test` or `app.opsforge.test`?
2. Why should the app listen on `127.0.0.1` rather than `0.0.0.0`?
3. What does a `502` tell you, and where would you look first?
4. Why can't Let's Encrypt issue a certificate for `opsforge.test`?
5. What's the difference between `systemctl stop` and `kill -9` from the app's point of view?

## After the lab, check yourself

1. Draw the request path from browser to app, marking where TLS ends.
2. Without `proxy_set_header X-Real-IP`, what IP does the app see, and why?
3. What does `Restart=on-failure` do after `systemctl stop`? After `kill -9`?
4. Which file is secret: the `.crt` or the `.key`? What permissions should it have?
5. You change an Nginx config and reload, but nothing changes. List three things to check.

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [MDN: An overview of HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview)
- [Nginx beginner's guide](https://nginx.org/en/docs/beginners_guide.html) and [How Nginx processes a request](https://nginx.org/en/docs/http/request_processing.html)
- [How HTTPS works (comic)](https://howhttps.works/)
- [Let's Encrypt: How it works](https://letsencrypt.org/how-it-works/)
- [systemd for administrators](https://www.freedesktop.org/wiki/Software/systemd/) and `man systemd.service`
- [Go: net/http](https://pkg.go.dev/net/http)
