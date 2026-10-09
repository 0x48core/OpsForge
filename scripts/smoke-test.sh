#!/usr/bin/env bash
# Smoke-test a running hello-api: health, readiness, and a real write.
# Used by CI after starting the stack, and after each deploy.
#
# Usage: scripts/smoke-test.sh <base-url> [expected-version]
#   scripts/smoke-test.sh http://localhost:8000
#   scripts/smoke-test.sh https://api.example.com sha-1a2b3c4
set -euo pipefail

BASE_URL="${1:?usage: $0 <base-url> [expected-version]}"
EXPECTED_VERSION="${2:-}"
CURL=(curl --silent --show-error --max-time 5 --retry 5 --retry-delay 2 --retry-all-errors)

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "Smoke-testing $BASE_URL"

"${CURL[@]}" --fail "$BASE_URL/health" >/dev/null || fail "/health"
echo "  ok  /health"

ready=$("${CURL[@]}" --fail "$BASE_URL/ready") || fail "/ready: $ready"
echo "  ok  /ready $ready"

if [[ -n "$EXPECTED_VERSION" ]]; then
  version=$("${CURL[@]}" --fail "$BASE_URL/" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
  [[ "$version" == "$EXPECTED_VERSION" ]] || fail "version is '$version', expected '$EXPECTED_VERSION'"
  echo "  ok  version $version"
fi

before=$("${CURL[@]}" --fail "$BASE_URL/visits" | sed -n 's/.*"db_total":\([0-9]*\).*/\1/p')
"${CURL[@]}" --fail -X POST "$BASE_URL/visits" >/dev/null || fail "POST /visits"
after=$("${CURL[@]}" --fail "$BASE_URL/visits" | sed -n 's/.*"db_total":\([0-9]*\).*/\1/p')
(( after == before + 1 )) || fail "db_total went from $before to $after, expected +1"
echo "  ok  POST /visits ($before -> $after)"

echo "All smoke tests passed."
