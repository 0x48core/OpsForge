#!/usr/bin/env bash
# Self-signed certificate for local TLS termination (lab 60).
# HAProxy wants the certificate and the key concatenated in one .pem file.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=opsforge.localhost" \
  -addext "subjectAltName=DNS:opsforge.localhost,DNS:localhost,IP:127.0.0.1" \
  -keyout certs/site.key -out certs/site.crt 2>/dev/null
cat certs/site.crt certs/site.key > certs/site.pem
rm certs/site.key
chmod 644 certs/site.pem   # readable by the haproxy user inside the container
echo "wrote certs/site.pem"
