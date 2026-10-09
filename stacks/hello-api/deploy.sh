#!/usr/bin/env bash
# Deploy a hello-api image tag on this server with zero downtime (labs 07–08).
# CI runs this over SSH; you can also run it by hand.
#
# Usage: ./deploy.sh <image-tag>        e.g. ./deploy.sh sha-1a2b3c4
#   PULL=0 ./deploy.sh <tag>             skip the pull (image already local, e.g. a rehearsal)
#
# Rolling deploy:
#   1. start a container with the new image NEXT TO the running one
#   2. wait until it is healthy; Traefik only routes to healthy containers
#   3. stop the old one gracefully (SIGTERM, in-flight requests finish)
# If the new container never becomes healthy, it is removed and the old one
# keeps serving: a failed deploy causes no outage.
#
# Needs: .env next to this file (DB credentials), the proxy network, and Traefik.
set -euo pipefail

TAG="${1:?usage: $0 <image-tag>}"
cd "$(dirname "$0")"
export APP_VERSION="$TAG"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
HISTORY=.deploy-history

compose() { docker compose -f compose.yaml -f compose.traefik.yaml -f compose.deploy.yaml "$@"; }
image_of() { docker inspect --format '{{.Config.Image}}' "$1"; }

wait_healthy() {
  local id=$1 status
  for ((i = 0; i < HEALTH_TIMEOUT; i++)); do
    status=$(docker inspect --format '{{.State.Health.Status}}' "$id")
    case "$status" in
      healthy) return 0 ;;
      unhealthy) return 1 ;;
    esac
    sleep 1
  done
  return 1
}

[[ -f .env ]] || { echo "missing .env (copy .env.example and set a password)" >&2; exit 1; }

echo "==> Deploying hello-api $TAG"
if [[ "${PULL:-1}" == "1" ]]; then
  compose pull app
fi

old=$(compose ps -q app)

if [[ -z "$old" ]]; then
  # First deploy: nothing to replace.
  compose up -d --no-build --wait --wait-timeout "$HEALTH_TIMEOUT"
else
  [[ $(wc -l <<<"$old") -eq 1 ]] || { echo "expected one running app container, found: $old" >&2; exit 1; }
  echo "==> Old: $(image_of "$old")"

  # Scale to 2 without touching the existing container: the new one gets the new image.
  compose up -d --no-build --no-recreate --scale app=2 app
  new=$(compose ps -q app | grep -v "$old")
  echo "==> New: $(image_of "$new"), waiting for it to be healthy..."

  if ! wait_healthy "$new"; then
    echo "!!> New container is not healthy; removing it. The old version keeps serving." >&2
    docker logs --tail 20 "$new" >&2 || true
    docker rm -f "$new" >/dev/null
    exit 1
  fi

  # Give Traefik a moment to add the new container, then retire the old one.
  sleep 3
  echo "==> Stopping old container (graceful, up to 30 s)"
  docker stop --time 30 "$old" >/dev/null
  docker rm "$old" >/dev/null
fi

echo "$TAG" >> "$HISTORY"
echo "==> Running: $(image_of "$(compose ps -q app)")"
echo "==> Deployed $TAG"
