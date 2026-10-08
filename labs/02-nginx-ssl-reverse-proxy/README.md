# Lab 02 — Nginx, SSL & reverse proxy

- **Phase:** 1 — Linux & server foundations
- **Status:** 🟨 in progress
- **Started / finished:** YYYY-MM-DD / —
- **Environment:** local Ubuntu 24.04 VM (Multipass) until a VPS is rented, see [ADR 0002](../../docs/decisions/0002-local-vm-before-vps.md)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Serve a static site over HTTPS, then run an app as a `systemd` service behind Nginx as a reverse proxy.

## Done when

**Local VM**
- [ ] Static site served by Nginx at `http://opsforge.test`
- [ ] [hello-api](../../apps/hello-api/) runs as a `systemd` service and restarts on failure (tested with `kill -9`)
- [ ] Nginx reverse-proxies `app.opsforge.test` to the app; the app sees the real client IP
- [ ] HTTPS with a locally trusted certificate (mkcert); HTTP redirects to HTTPS

**On the VPS (later, needs a public IP + domain)**
- [ ] Real Let's Encrypt certificate via Certbot at `https://<domain>`
- [ ] Auto-renewal tested (`certbot renew --dry-run`)

## Before you start

Names used below: VM `opsforge`, domains `opsforge.test` and `app.opsforge.test`. `.test` is a TLD reserved for testing, so it never clashes with a real site. `<VM_IP>` is the VM's IP address.

## Steps

### 0. Create the local "VPS"

```bash
# on your Mac
brew install --cask multipass
multipass launch 24.04 --name opsforge --cpus 2 --memory 4G --disk 20G
multipass info opsforge          # note the IPv4 address → <VM_IP>
multipass shell opsforge         # opens a shell in the VM as user "ubuntu"
```

Point the test domains at the VM. Edit `/etc/hosts` on your **Mac**:

```bash
sudo nano /etc/hosts
```

```
<VM_IP>  opsforge.test app.opsforge.test
```

> Optional but recommended: run lab 01's steps 2–5 and 7–8 inside this VM. The guide works the same way, and later labs build on a hardened server.

### 1. Install Nginx

```bash
# in the VM
sudo apt update && sudo apt install -y nginx
systemctl status nginx --no-pager
curl -I localhost            # HTTP/1.1 200 OK
```

If `ufw` is active (from lab 01): `sudo ufw allow 'Nginx Full'` (opens 80 and 443).

### 2. Serve a static site

```bash
sudo mkdir -p /var/www/opsforge.test
echo '<h1>OpsForge</h1><p>Served by Nginx.</p>' | sudo tee /var/www/opsforge.test/index.html
sudo nano /etc/nginx/sites-available/opsforge.test
```

```nginx
server {
    listen 80;
    server_name opsforge.test;

    root /var/www/opsforge.test;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Enable it and turn off the default site:

```bash
sudo ln -s /etc/nginx/sites-available/opsforge.test /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t                 # always test before reload
sudo systemctl reload nginx
```

On your Mac, open `http://opsforge.test`.

**Things to explore:** `/var/log/nginx/access.log` and `error.log`. What happens with a URL that doesn't exist? What does `nginx -t` say when you delete a `;`?

### 3. Run hello-api as a systemd service

Go compiles to a single static binary, so the server doesn't need Go installed. Build it on your Mac for Linux and copy it over:

```bash
# on your Mac, from the repo root
make -C apps/hello-api build-linux        # → apps/hello-api/bin/hello-api-linux-arm64
multipass transfer apps/hello-api/bin/hello-api-linux-arm64 apps/hello-api/hello-api.service opsforge:/tmp/
```

> The Multipass VM on an Apple Silicon Mac is **arm64**. On a typical VPS use `make -C apps/hello-api build-linux ARCH=amd64`. Check with `uname -m` on the server: `aarch64` = arm64, `x86_64` = amd64.

```bash
# in the VM
sudo useradd --system --no-create-home --shell /usr/sbin/nologin hello
sudo mkdir -p /opt/hello-api
sudo install -m 755 /tmp/hello-api-linux-arm64 /opt/hello-api/hello-api
sudo mv /tmp/hello-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hello-api
systemctl status hello-api --no-pager
curl localhost:8000/health    # {"status":"ok"}
```

Read [hello-api.service](../../apps/hello-api/hello-api.service) and work out what each line does. Pay special attention to `Restart=on-failure` and the sandboxing options.

**Test restart on failure:**

```bash
sudo systemctl kill -s SIGKILL hello-api
sleep 3
systemctl status hello-api --no-pager      # active again, with a new PID
journalctl -u hello-api -n 20 --no-pager   # see the crash and the restart
```

Compare with a clean stop: `sudo systemctl restart hello-api`, then check the journal. You'll see `shutting down`, because the app handles `SIGTERM` gracefully. `SIGKILL` can't be caught, so it gets no chance to clean up.

The app listens on `127.0.0.1` only, so it can't be reached from outside the VM. Nginx will be the only way in.

### 4. Reverse proxy

```bash
sudo nano /etc/nginx/sites-available/app.opsforge.test
```

```nginx
server {
    listen 80;
    server_name app.opsforge.test;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/app.opsforge.test /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

```bash
# on your Mac
curl http://app.opsforge.test/
```

`client_ip` should be your Mac's IP on the VM network, not `127.0.0.1`. That proves `X-Real-IP` works.

**Break it on purpose:** `sudo systemctl stop hello-api`, then curl again. You get a **502 Bad Gateway**. Check `/var/log/nginx/error.log` to see why, then start the app again. A 502 means "Nginx is fine, the app behind it isn't". You'll see this a lot in real life.

### 5. HTTPS with a locally trusted certificate

Let's Encrypt can't issue certificates for `.test` domains or private IPs. For local work, use [mkcert](https://github.com/FiloSottile/mkcert), which creates a local certificate authority that your Mac trusts.

```bash
# on your Mac
brew install mkcert
mkcert -install
mkcert opsforge.test app.opsforge.test      # creates opsforge.test+1.pem and opsforge.test+1-key.pem
multipass transfer opsforge.test+1.pem opsforge.test+1-key.pem opsforge:/tmp/
rm opsforge.test+1*.pem                     # don't leave keys lying around (*.pem is also git-ignored)
```

```bash
# in the VM
sudo mkdir -p /etc/nginx/ssl
sudo mv /tmp/opsforge.test+1.pem /etc/nginx/ssl/opsforge.test.crt
sudo mv /tmp/opsforge.test+1-key.pem /etc/nginx/ssl/opsforge.test.key
sudo chmod 600 /etc/nginx/ssl/opsforge.test.key
```

Update **both** site files: HTTP only redirects, and HTTPS serves. Example for the app (do the same for `opsforge.test`, keeping its `root`/`location` block):

```nginx
server {
    listen 80;
    server_name app.opsforge.test;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;   # Nginx 1.24 syntax; 1.25.1+ uses a separate `http2 on;`
    server_name app.opsforge.test;

    ssl_certificate     /etc/nginx/ssl/opsforge.test.crt;
    ssl_certificate_key /etc/nginx/ssl/opsforge.test.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

```bash
# on your Mac
curl -I http://app.opsforge.test       # 301 → https://
curl https://app.opsforge.test/        # works, no certificate warning
```

Then open both sites in the browser and check for the padlock.

### 6. Let's Encrypt — do this on the VPS

When you have a VPS and a domain with DNS A records pointing at it, the Certbot part of this lab replaces step 5:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d <domain> -d app.<domain>
sudo certbot renew --dry-run
systemctl list-timers | grep certbot    # renewal runs automatically
```

Certbot edits your Nginx config itself. Save a copy of the site file before running it, then `diff` the two to see what it changed.

### 7. Clean up or keep

Keep the VM: lab 03 backs up what you built here. Useful commands:

```bash
multipass stop opsforge     # pause
multipass start opsforge    # resume (the IP may change, so update /etc/hosts)
multipass delete --purge opsforge   # remove completely
```

## Code

- [apps/hello-api/](../../apps/hello-api/): the Go app, its Makefile, and its systemd unit
- Nginx configs are inline above and become part of the Ansible setup in [lab 09](../09-ansible/)

## What broke

_Write down errors and fixes here as you go._

## Lessons learned

## References

- [Nginx beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- [Nginx reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- `man systemd.service`, `man systemd.exec`
- [Go `net/http` package](https://pkg.go.dev/net/http)
- [mkcert](https://github.com/FiloSottile/mkcert)
- [Certbot instructions (Nginx on Ubuntu)](https://certbot.eff.org/instructions?ws=nginx&os=snap)
