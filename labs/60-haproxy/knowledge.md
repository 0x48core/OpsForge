# Lab 60 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

One server is one point of failure and one ceiling on capacity. As soon as you run two copies of something (lab 08's blue/green, lab 23's replicas, a Postgres primary + standby), something has to sit in front and decide **which copy gets each request**, notice when a copy is broken, and stop sending it traffic. That's a load balancer.

You've already used one without focusing on it: Nginx (lab 02) and Traefik (lab 05) both load-balance. **HAProxy** is the tool built *only* for this job. It's what many companies put in front of their web tier and databases, and what the cloud load balancers you'll meet in lab 29 do as a managed service. Learning it by hand shows you every knob those managed products hide.

## Core concepts

### Where HAProxy sits

```
                    ┌──────────── HAProxy ────────────┐
client ──TLS──▶ frontend www (:443)                   │
                │  ACLs: path_beg /api ?              │
                │     yes ──▶ backend api ──▶ api1, api2
                │     no  ──▶ backend web ──▶ web1, web2, web3
                └─────────────────────────────────────┘
                       ▲ health checks every 2 s to every server
```

- A **frontend** is what listens: an address/port, TLS settings, and rules about the incoming request.
- A **backend** is a pool of **servers**, plus how to choose between them and how to check them.
- A **`listen`** block is a frontend and a backend in one, handy for simple TCP services.
- **ACLs** are named conditions (`path_beg /api`, `hdr(host) -i api.example.com`, `src 10.0.0.0/8`) used to route, deny, or redirect.

### Layer 4 vs layer 7

| | `mode tcp` (layer 4) | `mode http` (layer 7) |
|---|---|---|
| What HAProxy sees | A stream of bytes between two IPs and ports | Parsed HTTP: method, path, headers, cookies |
| Can route by | IP, port, TLS SNI | Anything in the request |
| Can do | Forward connections, health-check the port or a simple protocol | Rewrite headers, redirect, add `X-Forwarded-For`, rate-limit per path, sticky cookies, return errors itself |
| Use it for | Databases, Redis, SMTP, anything not HTTP, TLS passthrough | Web apps and APIs |

### Load-balancing algorithms (`balance`)

| Algorithm | How it picks | Good for |
|---|---|---|
| `roundrobin` | Each server in turn, respecting `weight` | Short, similar requests (the default choice) |
| `leastconn` | The server with the fewest active connections | Long or uneven requests, WebSockets, databases |
| `source` | Hash of the client IP: same client → same server | Poor man's stickiness when you can't use cookies |
| `uri` | Hash of the path | Caches: the same URL always hits the same cache server |
| `first` | First server with free slots, in order | Primary + standby, or packing load onto few servers |

**Weights** (`server web1 … weight 3`) let a bigger server take more traffic. Weight 0 means "no new traffic".

### Health checks

HAProxy checks every server on a timer, independently of real traffic:

- `check` on a `server` line turns it on. Without `option httpchk` it's a **TCP connect** check: "is the port open?"
- `option httpchk GET /health` + `http-check expect status 200` is a **layer 7 check**: "does the app actually answer correctly?" A process that's up but broken (database lost, disk full) fails this and gets pulled out.
- `inter 2s fall 3 rise 2`: check every 2 s, mark **DOWN after 3 failures** and **UP after 2 successes**. The gap between `fall` and `rise` stops a flapping server from bouncing in and out.
- `backup` servers only get traffic when all normal servers are DOWN.

Health checks are about **removing broken servers**. They're not the same as retries: a request already sent to a server that dies mid-request fails unless `retries` + `option redispatch` let HAProxy try another server.

### Server states you'll see

| State | Meaning |
|---|---|
| `UP` | Passing checks, gets traffic |
| `DOWN` | Failing checks, gets nothing |
| `DRAIN` | Healthy, but gets **no new** connections; existing ones finish. Use this before maintenance |
| `MAINT` | Taken out by an operator (or name not resolvable), gets nothing, not even checks |

**Drain → wait → maintain → work → ready** is how you take a server out with zero errors. Lab 08 did the same thing with blue/green.

### TLS termination

HAProxy can terminate TLS (`bind :443 ssl crt site.pem`): the client's HTTPS ends at HAProxy, and HAProxy talks plain HTTP to the servers on the private network. That's one place to manage certificates, and HAProxy can read the HTTP inside to route on it. The alternatives:

- **Passthrough** (`mode tcp`): HAProxy forwards the encrypted bytes; the servers hold the certificates. It can only route on SNI.
- **Re-encryption** (`server … ssl verify required ca-file …`): terminate, inspect, then encrypt again to the server. Use it when the network between them isn't trusted.

Because the server only sees HAProxy's IP, HAProxy adds **`X-Forwarded-For`** (client IP) and you add **`X-Forwarded-Proto`** (original scheme). The app must trust these headers *only* from the proxy.

### Sticky sessions

If an app keeps session state in memory, a user must keep hitting the same server. `cookie SRV insert` makes HAProxy set a cookie naming the server, then route on it. It works, but it's a crutch: the better fix is a stateless app with sessions in Redis (lab 24), so any server can answer.

### Stick tables and rate limiting

A **stick table** is an in-memory key/value table inside HAProxy (key = client IP, for example) that counts things: request rate, connection count, errors. `http-request track-sc0 src` puts each request in the table; `http-request deny if { sc_http_req_rate(0) gt 20 }` rejects clients above a rate. It's how HAProxy does rate limiting and basic abuse protection with no extra service.

### Timeouts

Every connection has a client side and a server side, and each needs a limit or a stuck peer holds a slot forever:

| Timeout | Covers |
|---|---|
| `timeout connect` | HAProxy opening a TCP connection to a server |
| `timeout client` | Client inactivity |
| `timeout server` | Server inactivity (waiting for the response) |
| `timeout http-request` | Time for the client to send full request headers. Stops slowloris attacks |

HAProxy warns at startup if they're missing. Too short breaks slow endpoints; too long lets dead connections pile up to `maxconn`.

### Reloads and the runtime API

- **Reload** (`SIGUSR2` or `SIGHUP` to the master process, or `systemctl reload haproxy`): a new worker starts with the new config and takes the listening sockets; the old worker finishes its existing connections and exits. No dropped connections. Always run `haproxy -c -f haproxy.cfg` first: a broken config doesn't load and the old one keeps running, but you want to know before that.
- **Runtime API** (`stats socket`): a text protocol to change things *without* a reload: drain a server, change a weight, read a stick table, see stats. It's how automation (deploy scripts, service discovery) talks to HAProxy. It's full admin access, so it must never be exposed publicly.

### DNS resolution of servers

By default HAProxy resolves server hostnames **once, at startup**, and refuses to start if one doesn't resolve. In Docker or Kubernetes, containers come and go and change IPs. A `resolvers` section makes HAProxy re-resolve at runtime, and `init-addr last,libc,none` lets it start even if a server's name doesn't exist yet. The server then starts in `MAINT` and comes up when it appears.

### HAProxy vs the other proxies in this repo

| | HAProxy | Nginx (lab 02) | Traefik (lab 05) | Envoy (lab 44) |
|---|---|---|---|---|
| Main job | Load balancing, L4 + L7 | Web server that also proxies | Auto-configured edge proxy | Programmable data plane for meshes |
| Config | One static file + runtime API | Static files | Docker labels / K8s CRDs, discovered live | YAML or xDS from a control plane |
| Strengths | Health checks, algorithms, stick tables, stats, very fast and predictable | Serving files, caching, everywhere | No config to write for containers, Let's Encrypt built in | Dynamic config, retries/circuit breaking, observability |
| Choose it when | You want a dedicated, tunable LB, often for TCP too | You also serve static content | Many containers, things change often | You're building or running a mesh |

## Key terms

| Term | Meaning |
|---|---|
| Frontend | Listening side: bind address, TLS, request rules |
| Backend | Pool of servers + algorithm + checks |
| `listen` | Frontend and backend combined in one block |
| ACL | A named condition on the request or connection |
| `balance` | The algorithm that picks a server |
| Health check | Periodic probe that marks a server UP or DOWN |
| `fall` / `rise` | Failed / successful checks needed to change state |
| Backup server | Used only when all normal servers are DOWN |
| Drain | No new connections; existing ones finish |
| TLS termination | Decrypt at the proxy, plain HTTP behind it |
| `X-Forwarded-For` | Header carrying the original client IP |
| Stick table | In-memory table of counters per key (IP, cookie…) |
| Runtime API | Socket for changing HAProxy without reloading |
| `maxconn` | Cap on concurrent connections (global, frontend, or per server); extra ones queue |

## Commands to know

| Command | What it does |
|---|---|
| `haproxy -c -f haproxy.cfg` | Check the config without starting |
| `haproxy -vv` | Version and build options (OpenSSL, Lua, Prometheus…) |
| `docker compose kill -s HUP haproxy` | Hot reload in the official image (`systemctl reload haproxy` on a server) |
| `echo "show stat" \| nc localhost 9999` | Stats as CSV via the runtime API |
| `echo "show servers state" \| nc localhost 9999` | State of every server |
| `echo "set server web/web1 state drain" \| nc localhost 9999` | Drain a server (`ready`, `maint` too) |
| `echo "set server web/web1 weight 0" \| nc localhost 9999` | Change a weight live |
| `echo "show table www" \| nc localhost 9999` | Dump a stick table |
| `curl localhost:8404/metrics` | Prometheus metrics |

## Before you start, can you answer these?

1. What's the difference between a frontend and a backend?
2. When would you use `mode tcp` instead of `mode http`?
3. Why is an HTTP health check better than a TCP connect check for a web app?
4. What does `fall 3 rise 2` mean, and why are the numbers different?
5. If HAProxy terminates TLS, how does the app learn the client's real IP?
6. What's the difference between `DRAIN` and `MAINT`?

## After the lab, check yourself

1. A server's process is running, but its database is down. Which kind of check catches that, and what did HAProxy log when it happened in step 4?
2. You stopped `web3`. Did any client see an error? What settings decide that?
3. Why did `haproxy -c` fail before `resolvers` and `init-addr` were added, and why doesn't it now?
4. Explain how a reload avoids dropping connections.
5. When would you pick `leastconn` over `roundrobin`? `first`?
6. Your rate limit returns 429. Show from the stick table why that client was blocked.
7. HAProxy itself is now a single point of failure. How would you remove it? (Hint: two HAProxy nodes + keepalived and a floating IP, or a cloud LB in front, lab 29.)

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [HAProxy configuration manual (3.2)](https://docs.haproxy.org/3.2/configuration.html): the reference; search it rather than reading it
- [HAProxy management guide](https://docs.haproxy.org/3.2/management.html): runtime API, reloads, signals
- [The four essential sections of an HAProxy configuration](https://www.haproxy.com/blog/the-four-essential-sections-of-an-haproxy-configuration)
- [Introduction to HAProxy ACLs](https://www.haproxy.com/blog/introduction-to-haproxy-acls)
- [Introduction to HAProxy stick tables](https://www.haproxy.com/blog/introduction-to-haproxy-stick-tables)
- [Official Docker image](https://hub.docker.com/_/haproxy)
