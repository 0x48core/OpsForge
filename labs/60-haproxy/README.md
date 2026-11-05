# Lab 60 — HAProxy load balancing

- **Phase:** Extra — Load balancing
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker Compose on the Mac (optional last step on the VPS)
- **Builds on:** Labs 02, 05, 08, 13

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Set up HAProxy by hand in front of several servers: load balancing, health checks, TLS termination, routing, sticky sessions, rate limiting, TCP mode, zero-downtime maintenance, and monitoring.

## Done when

- [ ] HAProxy runs from a config you can explain line by line, and `haproxy -c` passes
- [ ] Requests are spread across three servers, and you can switch algorithms and weights
- [ ] A server failing its HTTP health check is removed and comes back on its own, with no client errors
- [ ] HTTPS is terminated at HAProxy, HTTP redirects to HTTPS, and the app sees `X-Forwarded-For`/`-Proto`
- [ ] `/api/*` is routed to a second pool with sticky sessions
- [ ] A client above 20 requests / 10 s gets `429`, and you can show why from the stick table
- [ ] A server is drained and returned with the runtime API, and the config is reloaded with no downtime
- [ ] Redis is load-balanced in TCP mode with a backup server that takes over
- [ ] The stats page and `/metrics` show server state (bonus: scraped by the lab 11 Prometheus)

## Verified while preparing this lab

On Docker Desktop 29.9 (macOS), `haproxy:3.2-alpine` (HAProxy 3.2.26):

| Experiment | Result |
|---|---|
| 6 requests to `/` | `web1 web2 web3 web1 web2 web3` |
| `http://localhost:8080/foo?x=1` | `301` → `https://localhost:8443/foo?x=1` |
| `POST 500` to web2's `/health` | `Server web/web2 is DOWN, reason: Layer7 wrong status, code: 500`; traffic only to web1/web3 |
| `docker compose stop web3` | Requests kept answering from web1/web2 |
| `set server web/web1 state drain` | Only web2/web3 answered |
| Cookie `SRV=a2` on `/api/` | `api2` four times in a row |
| 25 fast requests | `200` × 16 then `429` (the rate counts the requests from earlier steps too) |
| Stop `redis1` | `GET who` returned `redis2`; log: `Running on backup` |
| `kill -s HUP` | `Reloading HAProxy` → `Loading success` |
| Reload with a typo (`balance roundrobinn`) | `ALERT … balance only supports …`; old worker kept serving `200` |
| `haproxy -c` without `resolvers`/`init-addr`, backends not running | `could not resolve address 'web3'`, config rejected |

## Steps

All commands run from `stacks/haproxy/` on the Mac.

### 0. Start the stack

```bash
cd stacks/haproxy
./gen-cert.sh                 # self-signed cert → certs/site.pem (git-ignored)
docker compose up -d
docker compose ps             # haproxy, web1-3, api1-2, redis1-2
docker compose logs haproxy   # "Loading success."
```

Then read [`haproxy.cfg`](../../stacks/haproxy/haproxy.cfg) top to bottom. Every line has a comment. Draw the frontend → ACL → backend → servers picture from `knowledge.md` with the real names.

Helper for sending requests *inside* the Docker network (whoami has no shell):

```bash
dcurl() { docker run --rm --network haproxy_default curlimages/curl:8.11.1 -s "$@"; }
```

### 1. Check the config

```bash
docker compose run --rm --no-deps haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
docker compose exec haproxy haproxy -vv | head -20      # version, OpenSSL, built-in Prometheus
```

`--no-deps` starts HAProxy *without* its backends. You'll see `could not resolve address 'web1', disabling server` as a NOTICE, not an error. Now break it on purpose: comment out the `default-server init-addr … resolvers docker` line in `defaults` and run the check again. The config is rejected. Put the line back. That's why the `resolvers` section exists (see knowledge.md, "DNS resolution of servers").

Make it a habit: **check, then reload**, every time.

### 2. Load balancing

```bash
for i in $(seq 6); do curl -sk https://localhost:8443/ | grep Hostname; done
```

Round robin: web1, web2, web3, and again. Now experiment in `backend web`, reloading after each change (`docker compose kill -s HUP haproxy`):

- `balance source`: every request from your Mac goes to the same server. Why?
- `balance roundrobin` with `weight 3` on web1: count how often each server answers in 20 requests.
- Put it back to plain `roundrobin`.

### 3. TLS termination, redirect, and forwarded headers

```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' 'http://localhost:8080/foo?x=1'   # 301 → https://localhost:8443/foo?x=1
curl -skL http://localhost:8080/ | grep -E 'Hostname|X-Forwarded'
curl -kv https://localhost:8443/ 2>&1 | grep -E 'SSL connection|ALPN|subject'           # TLS 1.3, h2, CN=opsforge.localhost
```

whoami echoes the request it received: plain HTTP from HAProxy, with `X-Forwarded-For` (your client IP as Docker sees it) and `X-Forwarded-Proto: https`.

Read the redirect line in the config. On a real server listening on 80/443, the one-liner `redirect scheme https` would be enough. Here we also have to swap `8080` for `8443`.

### 4. Health checks: a broken server is removed

In a second terminal, keep a request loop running so you can see whether any client gets an error:

```bash
while true; do curl -sk -o /dev/null -w '%{http_code} ' https://localhost:8443/; sleep 0.3; done
```

Make web2's `/health` return 500. The process stays up, but the app is "broken":

```bash
dcurl -X POST -d 500 http://web2/health
docker compose logs -f haproxy | grep -i web2      # DOWN after 3 failed checks (~6 s)
```

Open <http://localhost:8404/stats>: web2 is red. The loop shows only `200`. Heal it:

```bash
dcurl -X POST -d 200 http://web2/health            # UP again after 2 good checks
```

Now a harder failure, a container that disappears:

```bash
docker compose stop web3          # watch the loop and the stats page
docker compose start web3
```

Did any request fail during the ~6 s before web3 was marked DOWN? `retries 2` + `option redispatch` in `defaults` retry a failed connection on another server. Comment them out, reload, and repeat to see the difference.

### 5. Path routing and sticky sessions

```bash
curl -sk https://localhost:8443/api/users | grep Hostname         # api1 or api2
curl -sk -D - -o /dev/null https://localhost:8443/api/ | grep -i set-cookie   # SRV=a1 or a2
for i in $(seq 4); do curl -sk -b 'SRV=a2' https://localhost:8443/api/ | grep Hostname; done   # always api2
```

Questions: what happens if you send `SRV=a2` and api2 is DOWN? Try it with `dcurl -X POST -d 500 http://api2/health`. Then heal api2.

### 6. The runtime API: maintenance without a reload

```bash
echo "show servers state web" | nc -w1 localhost 9999
echo "show stat" | nc -w1 localhost 9999 | cut -d, -f1,2,18 | column -t -s,

echo "set server web/web1 state drain" | nc -w1 localhost 9999
for i in $(seq 4); do curl -sk https://localhost:8443/ | grep Hostname; done   # no web1
echo "set server web/web1 state maint" | nc -w1 localhost 9999                # "do the maintenance"
echo "set server web/web1 state ready" | nc -w1 localhost 9999                 # back in rotation

echo "set server web/web1 weight 0" | nc -w1 localhost 9999
echo "get weight web/web1" | nc -w1 localhost 9999                              # 0 (initial 1)
echo "set server web/web1 weight 1" | nc -w1 localhost 9999
```

Runtime changes are **not saved**: a reload brings back what's in the file. That's by design. The file is the source of truth, and the API is for temporary operations like deploys.

Write a small script, `scripts/haproxy-rolling-restart.sh`: for each web server, drain → wait until its sessions are 0 (`show stat`, column 5 `scur`) → restart the container → wait until UP → ready. Run it with the request loop from step 4 open. It should show only `200`.

### 7. Rate limiting with a stick table

```bash
sleep 10
for i in $(seq 25); do curl -sk -o /dev/null -w '%{http_code} ' https://localhost:8443/; done; echo
echo "show table www" | nc -w1 localhost 9999      # key=<your IP> http_req_rate(10000)=25
```

After about 20 requests you get `429`. Wait 10 seconds and it's `200` again. Change the limit or the window, reload, and confirm.

### 8. Layer 4: Redis in TCP mode with a backup

```bash
docker compose exec redis1 redis-cli set who redis1
docker compose exec redis2 redis-cli set who redis2
rcli() { docker run --rm --network haproxy_default redis:7.4-alpine redis-cli -h haproxy -p 6379 "$@"; }
rcli get who                     # redis1: balance first + redis2 is "backup"
docker compose stop redis1; sleep 8
rcli get who                     # redis2
docker compose logs haproxy | grep redis     # "Running on backup", tcplog lines
docker compose start redis1
```

The check sends `PING` and expects `+PONG`: a protocol-level health check without HTTP. Note what HAProxy *can't* do here: the two Redis servers have different data. Failover in the proxy doesn't replicate data. That's the database's job (lab 54, Sentinel/replication).

### 9. Logs and metrics

```bash
docker compose logs --no-log-prefix haproxy | grep 'www~' | tail -3
curl -s localhost:8404/metrics | grep -E '^haproxy_(server_status|backend_active_servers)' | head
```

Read one `httplog` line field by field. The `0/0/0/0/0` block is the timings: request / queue / connect / response / total (ms). The `----` block is the termination state: when something goes wrong, the first two letters say who closed the connection and at what stage. Look these up in the manual's "Logging" section the first time you see an error.

**Bonus:** add HAProxy as a scrape target in the lab 11 Prometheus (`haproxy:8404/metrics`) and import Grafana dashboard 12693.

### 10. Hot reload

```bash
docker compose exec haproxy ps -o pid,args        # PID 1 = master, another PID = worker
docker compose kill -s HUP haproxy
docker compose logs haproxy | tail -3             # "Reloading HAProxy" / "Loading success."
docker compose exec haproxy ps -o pid,args        # new worker PID
```

Run it with the request loop from step 4 open: no errors. Then break the config (a typo), run `haproxy -c`, see the error, and see what a reload does with a broken file (the old worker keeps running). Fix it.

### 11. (Optional) On the VPS, without Docker

```bash
sudo apt install haproxy                     # Ubuntu's package; config in /etc/haproxy/haproxy.cfg
haproxy -v
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy                # same zero-downtime reload, through systemd
journalctl -u haproxy -f
```

Port the `web` part of this config, pointing at two hello-api instances on `127.0.0.1:8001` and `:8002` (lab 08). Remember lab 01: keep the stats page and runtime API bound to `127.0.0.1`, open only 80/443 in ufw, and use a Let's Encrypt certificate (cert + key concatenated into one `.pem`).

### Clean up

```bash
docker compose down
```

## Code

- [`stacks/haproxy/compose.yaml`](../../stacks/haproxy/compose.yaml): HAProxy, three web servers, two API servers, two Redis servers
- [`stacks/haproxy/haproxy.cfg`](../../stacks/haproxy/haproxy.cfg): the commented config
- [`stacks/haproxy/gen-cert.sh`](../../stacks/haproxy/gen-cert.sh): self-signed certificate for local TLS

## What broke

- **`haproxy -c` failed with `could not resolve address 'web3'`** when the backends weren't running. HAProxy resolves server names at startup and refuses unresolvable ones by default. Fixed with a `resolvers docker` section (Docker DNS at `127.0.0.11`) and `default-server init-addr last,libc,none resolvers docker`.
- **The HTTP→HTTPS redirect went to `https://localhost:8080`.** `redirect scheme https` keeps the original port. Fine on 80/443, wrong for local 8080/8443. Fixed with `redirect location` and `regsub(:8080,:8443)` on the Host header.
- **A reload failed with `Missing LF on last line, file might have been truncated`**, even though the file was fine. The config was bind-mounted as a *single file*, and `sed -i` (like many editors) writes a new file and renames it over the old one. The container kept the old, now-deleted inode. Fixed by mounting the whole `stacks/haproxy/` directory.
- **Warning `'option forwardfor' ignored for proxy 'redis'`.** Options in `defaults` apply to every proxy, including the TCP one. Moved `option forwardfor` into the HTTP frontend.

## Lessons learned

## References

- [knowledge.md → Further reading](knowledge.md#further-reading)
