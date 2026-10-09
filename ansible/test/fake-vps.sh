#!/usr/bin/env bash
# Manage a disposable fake VPS (a privileged systemd container) for lab 09.
#
# Usage: ansible/test/fake-vps.sh up | down | recreate | ssh | status
#
# SSH is published on 127.0.0.1:2201 (port 22 inside, the "fresh server")
# and 127.0.0.1:2202 (the hardened port the playbook switches to).
set -euo pipefail

NAME=opsforge-fake-vps
IMAGE=opsforge-fake-vps:24.04
KEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"
DIR="$(cd "$(dirname "$0")" && pwd)"

up() {
  [[ -f "$KEY" ]] || { echo "no public key at $KEY (set SSH_PUBKEY)" >&2; exit 1; }
  docker build -q -t "$IMAGE" "$DIR" >/dev/null
  docker run -d --name "$NAME" --hostname fake-vps --privileged --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --tmpfs /run --tmpfs /run/lock \
    -v "$NAME-docker:/var/lib/docker" -v "$NAME-containerd:/var/lib/containerd" \
    -p 127.0.0.1:2201:22 -p 127.0.0.1:2202:2202 \
    -p 127.0.0.1:8080:80 -p 127.0.0.1:8443:443 \
    "$IMAGE" >/dev/null
  docker exec -i "$NAME" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY"
  for _ in $(seq 1 30); do
    docker exec "$NAME" systemctl is-active --quiet ssh && break
    sleep 1
  done
  # A fresh server has a new host key: forget the old one for these ports.
  ssh-keygen -R "[127.0.0.1]:2201" >/dev/null 2>&1 || true
  ssh-keygen -R "[127.0.0.1]:2202" >/dev/null 2>&1 || true
  # Trust the new host key on first use (fine for a local throwaway container;
  # on a real VPS, compare the fingerprint with the provider's console).
  ssh-keyscan -p 2201 -t ed25519 127.0.0.1 2>/dev/null >> "$HOME/.ssh/known_hosts"
  echo "fake VPS up: ssh -p 2201 root@127.0.0.1"
}

down() {
  docker rm -f "$NAME" >/dev/null 2>&1 && echo "fake VPS removed" || echo "not running"
  docker volume rm "$NAME-docker" "$NAME-containerd" >/dev/null 2>&1 || true
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  recreate) down; up ;;
  ssh) exec docker exec -it "$NAME" bash ;;
  status) docker ps --filter "name=$NAME" --format '{{.Names}}  {{.Status}}  {{.Ports}}' ;;
  *) echo "usage: $0 up | down | recreate | ssh | status" >&2; exit 1 ;;
esac
