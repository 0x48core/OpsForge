#!/usr/bin/env bash
# Roll back hello-api to the previously deployed tag, with the same
# zero-downtime rolling deploy (lab 08).
#
# Usage: ./rollback.sh
#   PULL=0 ./rollback.sh    skip the pull (image already local)
set -euo pipefail
cd "$(dirname "$0")"

HISTORY=.deploy-history
[[ -f "$HISTORY" ]] || { echo "no $HISTORY yet: nothing to roll back to" >&2; exit 1; }

current=$(tail -n 1 "$HISTORY")
# The most recent entry that differs from the current tag.
previous=$(grep -vxF "$current" "$HISTORY" | tail -n 1 || true)
[[ -n "$previous" ]] || { echo "no earlier tag than $current in $HISTORY" >&2; exit 1; }

echo "==> Rolling back: $current -> $previous"
exec ./deploy.sh "$previous"
