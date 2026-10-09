#!/usr/bin/env bash
# Deploy a hello-api image tag on this server (lab 07).
# CI runs this over SSH; you can also run it by hand.
#
# Usage: ./deploy.sh <image-tag>        e.g. ./deploy.sh sha-1a2b3c4
#   PULL=0 ./deploy.sh <tag>             skip the pull (image already local, e.g. a rehearsal)
#
# Needs: .env next to this file (DB credentials), the proxy network, and Traefik.
set -euo pipefail

TAG="${1:?usage: $0 <image-tag>}"
cd "$(dirname "$0")"
export APP_VERSION="$TAG"

compose() { docker compose -f compose.yaml -f compose.traefik.yaml -f compose.deploy.yaml "$@"; }

[[ -f .env ]] || { echo "missing .env (copy .env.example and set a password)" >&2; exit 1; }

echo "==> Deploying hello-api $TAG"
if [[ "${PULL:-1}" == "1" ]]; then
  compose pull app
fi

# --wait blocks until the containers are healthy, and fails if they never are.
compose up -d --no-build --wait --wait-timeout 60

echo "==> Running: $(docker inspect --format '{{.Config.Image}}' "$(compose ps -q app)")"
echo "==> Deployed $TAG"
