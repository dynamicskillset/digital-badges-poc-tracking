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

# Extract LE_EMAIL from .env.acme. We do this in the host shell rather
# than letting acme.sh source the env file so we can fail fast with a
# clear message if the operator leaves it blank. cut -f2- preserves any
# '=' that might appear later in the value; the two tr calls strip both
# "double" and 'single' quotes.
LE_EMAIL="$(grep '^LE_EMAIL=' .env.acme | head -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")"

if [ -z "${LE_EMAIL}" ]; then
    echo "LE_EMAIL is not set in .env.acme. Let's Encrypt requires an account email for expiry notifications." >&2
    echo "Edit .env.acme and set LE_EMAIL=<address>, then re-run." >&2
    exit 1
fi

# We invoke acme.sh through the image's default ENTRYPOINT (/entry.sh),
# which execs `acme.sh "$@"`, so callers pass acme.sh flags directly - we
# do NOT prefix with `acme.sh` on the CLI (that would make /entry.sh run
# `acme.sh acme.sh ...`, silently broken).
#
# -T disables pseudo-TTY allocation on `docker compose run`; without it,
# acme.sh's stdout/stderr gets eaten by Compose's attach layer when the
# outer shell is piping or logging this script.
#
# --server letsencrypt is passed explicitly on every CA-touching call.
# acme.sh v3.x defaults to ZeroSSL, and the default is only persisted
# into account.conf once `--set-default-ca` runs. Passing the flag
# inline means we don't depend on volume state and we can't silently
# register against the wrong CA if the acme-state volume is wiped.

# Register the LE account on first run (idempotent).
docker compose run --rm -T acme \
    --register-account \
    --server letsencrypt \
    -m "${LE_EMAIL}"

# Issue the wildcard via Mythic Beasts DNS-01. --keylength ec-256 makes
# this an ECC cert so it lands in the same path that --install-cert --ecc
# reads from below. The DNS hook file is `dnsapi/dns_mythic_beasts.sh`
# (with underscores); it reads MB_AK / MB_AS from env and does OAuth2
# against Mythic Beasts' Primary API v2.
docker compose run --rm -T acme \
    --issue \
    --server letsencrypt \
    --dns dns_mythic_beasts \
    --keylength ec-256 \
    -d digitalbadges.scot \
    -d "*.digitalbadges.scot"

# Install the cert into a stable path inside the acme-certs volume.
# Nginx reads from /etc/nginx/certs/ (the same volume mounted ro).
docker compose run --rm -T acme \
    --install-cert -d digitalbadges.scot --ecc \
    --fullchain-file /certs/digitalbadges.scot.fullchain.pem \
    --key-file       /certs/digitalbadges.scot.key.pem

# Validate the rendered nginx config before reloading. `nginx -s reload`
# returns 0 on some builds even with a broken config, so a plain reload
# can leave the server in a degraded state. `nginx -t` (under `set -e`)
# makes broken configs fail the script before we try to reload.
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload

echo "Cert issued and installed. nginx reloaded."
