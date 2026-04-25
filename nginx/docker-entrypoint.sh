#!/bin/sh
# nginx entrypoint wrapper.
#
# Why this exists: on cold start the acme-certs volume is empty, so nginx
# cannot satisfy the ssl_certificate directives in nginx.conf and refuses
# to start. acme.sh (see scripts/issue-certs.sh) is what writes the real
# Let's Encrypt cert into this same volume -- but it runs in a separate
# container that needs nginx already up so the final `nginx -s reload`
# succeeds. Classic chicken-and-egg.
#
# This wrapper resolves the egg side: if the expected cert files are
# missing, write a short-lived self-signed cert at the paths nginx.conf
# expects, so nginx boots. Once scripts/issue-certs.sh runs, acme.sh
# overwrites those files with the real Let's Encrypt cert and nginx is
# reloaded to pick them up.
#
# Only runs when real certs are absent; do not use as a permanent cert
# source. Safe to run on every container start: if the real cert already
# exists, this wrapper does nothing and exec's nginx directly.

set -eu

CERT_DIR="/etc/nginx/certs"
FULLCHAIN="${CERT_DIR}/digitalbadges.scot.fullchain.pem"
KEY="${CERT_DIR}/digitalbadges.scot.key.pem"

if [ ! -s "${FULLCHAIN}" ] || [ ! -s "${KEY}" ]; then
    echo "nginx-entrypoint: real cert not found at ${FULLCHAIN}; generating self-signed bootstrap cert." >&2
    mkdir -p "${CERT_DIR}"
    openssl req -x509 -nodes -newkey rsa:2048 \
        -days 30 \
        -subj "/CN=digitalbadges.scot" \
        -addext "subjectAltName=DNS:digitalbadges.scot,DNS:*.digitalbadges.scot,DNS:api.digitalbadges.scot" \
        -keyout "${KEY}" \
        -out "${FULLCHAIN}"
    chmod 600 "${KEY}"
    echo "nginx-entrypoint: self-signed bootstrap cert installed. Run scripts/issue-certs.sh to replace with Let's Encrypt." >&2
else
    echo "nginx-entrypoint: cert present at ${FULLCHAIN}; skipping bootstrap." >&2
fi

exec /docker-entrypoint.sh "$@"
