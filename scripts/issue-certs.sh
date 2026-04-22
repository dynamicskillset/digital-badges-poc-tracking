#!/bin/sh
# Issue (or re-issue) the wildcard cert for digitalbadges.scot using
# acme.sh + Mythic Beasts DNS-01, then install it into the acme-certs
# volume in a stable layout that nginx mounts read-only.
#
# Run from the PoC repo root after `.env.acme` is filled in:
#     ./scripts/issue-certs.sh
#
# Renewal is handled by host cron - see the README "TLS runbook"
# section. This script is for the initial issuance only.

set -e

if [ ! -f .env.acme ]; then
    echo "Missing .env.acme - copy from .env.acme.example and fill in." >&2
    exit 1
fi

# Register the LE account on first run (idempotent).
docker compose run --rm acme acme.sh \
    --register-account \
    -m "$(grep '^LE_EMAIL=' .env.acme | cut -d= -f2 | tr -d '\"')"

# Issue the wildcard via Mythic Beasts DNS-01.
docker compose run --rm acme acme.sh \
    --issue \
    --dns dns_mythicbeasts \
    -d digitalbadges.scot \
    -d "*.digitalbadges.scot"

# Install the cert into a stable path inside the acme-certs volume.
# Nginx reads from /etc/nginx/certs/ (the same volume mounted ro).
docker compose run --rm acme acme.sh \
    --install-cert -d digitalbadges.scot --ecc \
    --fullchain-file /certs/digitalbadges.scot.fullchain.pem \
    --key-file       /certs/digitalbadges.scot.key.pem

# Reload nginx to pick up the new cert.
docker compose exec nginx nginx -s reload

echo "Cert issued and installed. nginx reloaded."
