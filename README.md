# digital-badges-poc
🏴󠁧󠁢󠁳󠁣󠁴󠁿 Project tracker for a Scottish digital badges proof of concept

This repository holds **documentation and deployment orchestration** for the PoC.
Application services (for example ORCA and the DCC stack) ship as **published
Docker images**; compose, ingress, and env configuration here reference those
images rather than embedding primary application source code.

## CI / GitHub Actions deployment

The workflow [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) renders env files and rsyncs them to the PoC server. Configure **repository variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Purpose |
| -------- | ------- |
| `SSH_HOST` | Deploy target hostname or IP |
| `SSH_USER` | SSH user for rsync and remote `docker compose` |
| `ACME_MYTHICBEASTS_USERNAME` | Mythic Beasts DNS API key id (non-sensitive identifier; pairs with the API secret below) |
| `ACME_LE_EMAIL` | Let's Encrypt account email (non-sensitive; used for expiry notifications) |

Configure **repository secrets** (Settings → Secrets and variables → Actions → Repository secrets). Existing signing/transaction secrets are documented in the workflow file; additionally set:

| Secret | Purpose |
| ------ | ------- |
| `POSTGRES_PASSWORD` | Postgres superuser password for `orcaadmin`. **Use a URL-safe value** (e.g. `openssl rand -hex 24`) — it is embedded in ORCA’s `DATABASE_URL`. |
| `ORCA_ORG_CONFIG_ENCRYPTION_KEY` | 32 random bytes, base64. `openssl rand -base64 32` — encrypts per-org API keys at rest in ORCA. |
| `ACME_MYTHICBEASTS_PASSWORD` | Mythic Beasts DNS API secret |
| `MAIL_SMTP_USERNAME` | Inbound SMTP AUTH username on the in-compose `mail` service (Postfix). Used by both `.env.mail` (`SMTP_USERNAME`) and `.env.orca` (`SMTP_USER`). Any opaque string. |
| `MAIL_SMTP_PASSWORD` | Inbound SMTP AUTH password for the above username. Generate with e.g. `openssl rand -hex 24`. |

After a successful run, verify on the host:

1. `ls /opt/digital-badges/current/.env.*` lists `.env.signing`, `.env.transaction`, `.env.orca`, `.env.mail`, `.env.postgres`, and `.env.acme`.
2. `cd /opt/digital-badges/current && docker compose ps` — `orca` and `postgres` **healthy**, other app services (including `mail`) **Up**.
3. Optional: run `./scripts/issue-certs.sh` from that directory for TLS (`.env.acme` is deployed by CI).

## Hostname routing

| Host | Routes to |
| ---- | --------- |
| `api.digitalbadges.scot` | `transaction-service` (via nginx → `transaction-service:4004`) |
| `digitalbadges.scot` (apex) | `orca` (via nginx → `orca:3000`) |
| `*.digitalbadges.scot` (any non-apex subdomain) | `orca` (via nginx → `orca:3000`) |

`api.digitalbadges.scot` is matched by an exact `server_name` in nginx, so it is **not** covered by the wildcard that sends other subdomains to ORCA. The apex `digitalbadges.scot` is listed explicitly in the same `server_name` block as the wildcard (nginx wildcards do not match the bare apex), so apex traffic reaches ORCA on the same TLS vhost as tenant subdomains. Unknown hosts still hit the `default_server` catch-all and return `404`.

### Local testing

Before DNS points at the PoC host, you can add entries to `/etc/hosts` so your machine resolves the same names to the host that runs Docker (e.g. `127.0.0.1` on your laptop while testing compose locally):

```
# /etc/hosts entries for local PoC testing
127.0.0.1   api.digitalbadges.scot
127.0.0.1   pilot.digitalbadges.scot
```

Use any tenant-style subdomain in place of `pilot` to exercise the ORCA path. After TLS is configured (see **TLS** below), `https://` URLs are the primary test targets; plain `http://` requests are redirected to `https://`.

## TLS

TLS is terminated at **nginx** using **Let's Encrypt** certificates. A single **wildcard** cert for `digitalbadges.scot` and `*.digitalbadges.scot` is obtained and renewed by **[acme.sh](https://github.com/acmesh-official/acme.sh)** in the `acme` compose service, using the **Mythic Beasts DNS API** for **DNS-01** challenges. That one certificate covers the API host, all tenant subdomains, and the apex for the default HTTPS catch-all (see below).

**Operator prerequisites**

- DNS **A** (or AAAA) records for the hostnames you use, pointing at the PoC server.
- **Ports 80 and 443** reachable from the public internet (80 is used for HTTP→HTTPS redirect and optional `/.well-known/acme-challenge/`; 443 serves the apps).
- A Mythic Beasts **account-level API key** (control panel → **Account → API keys**), scoped to write **only** `_acme-challenge` **TXT** records on the `digitalbadges.scot` zone. The control panel emits a key id and secret — these map to the env vars `MB_AK` and `MB_AS` that acme.sh's `dns_mythic_beasts` hook reads. *Do not* use the older per-domain "DNS API key"; the current acme.sh hook uses Mythic Beasts' Primary API v2 with OAuth2, not the legacy DNS API.
- A real **Let's Encrypt** contact email in `LE_EMAIL` (expiry and account notices).

**Initial issuance**

1. Copy the template and fill in credentials and email:  
   `cp .env.acme.example .env.acme`
2. Ensure **`.env.orca`** sets `PUBLIC_HTTP_PROTOCOL` / `USE_SECURE_COOKIES` for HTTPS (match `.env.orca.example`).
3. From the PoC repo root, run:  
   `./scripts/issue-certs.sh`  
   (This invokes the `acme` compose service — which uses the upstream `neilpang/acme.sh` image's default `/entry.sh` entrypoint, so flags are passed to acme.sh directly — to register a Let's Encrypt account, issue the wildcard, write PEMs into the shared `acme-certs` volume, and reload nginx.)

**Verification**

- Inspect the certificate handshakes, for example:  
  `openssl s_client -connect api.digitalbadges.scot:443 -servername api.digitalbadges.scot </dev/null`
- Hit the API health over HTTPS, for example:  
  `curl -fsS https://api.digitalbadges.scot/health`  
  (expect plain `healthy` with HTTP 200.)
- ORCA’s `/healthz` on a tenant host, for example:  
  `curl -fsS https://<pilot-org>.digitalbadges.scot/healthz`  
  (expect JSON with `"healthy":true` if ORCA is up.)

**Renewal**

- **Cron (recommended):** on the host, install a weekly job that runs acme.sh’s renew check then reloads nginx, for example:

  ```
  # /etc/cron.d/digital-badges-acme-renew
  # Run weekly. acme.sh's --cron mode internally checks whether each
  # cert is within its renewal window and skips otherwise, so weekly is
  # fine and won't hit Let's Encrypt rate limits.
  0 4 * * 1 root cd /opt/digital-badges-poc && \
      docker compose run --rm -T acme --cron --home /acme.sh && \
      docker compose exec -T nginx nginx -t && \
      docker compose exec -T nginx nginx -s reload >> /var/log/digital-badges-acme.log 2>&1
  ```

  Adjust the `cd` path and user to match your deployment; `root` is common when only root may run `docker`.

- **Manual:**  
  `docker compose run --rm -T acme --cron --home /acme.sh`  
  then run nginx -t and nginx -s reload as above if a cert was renewed.

**Where certificates live**

- **`acme-state`** volume: acme.sh’s own account and state (mounted at `/acme.sh` in the `acme` container).
- **`acme-certs`** volume: installed PEMs — `digitalbadges.scot.fullchain.pem` and `digitalbadges.scot.key.pem` under `/certs` in `acme`, mounted into nginx at `/etc/nginx/certs` (read/write so the entrypoint can write a short-lived self-signed cert before the first `issue-certs.sh` run, then the real cert from acme overwrites the same files).

**HSTS note**

**`Strict-Transport-Security` is intentionally not** sent in this rollout, so clients are not locked into HTTPS-only for a long `max-age` before the deployment is proven stable. You can add HSTS in nginx later once you are confident you will not need to fall back to plain HTTP for any hostname. (See the plan doc for rationale.)

## First run

Each service has a `.env.<role>.example` template at the repo root
(`.env.transaction.example`, `.env.signing.example`, `.env.postgres.example`, `.env.orca.example`, `.env.acme.example` for TLS).
For each one, copy to `.env.<role>` and fill in real values before starting
the stack. Rendered `.env.<role>` files are gitignored.

Bring the stack up with:

```bash
docker compose up -d
```

### Postgres lifecycle

The `postgres` service stores its data in a named volume (`postgres-data`),
so:

- `docker compose down` preserves the database; the next `up` reuses the
  existing data and **does not** re-run the schema init script.
- `docker compose down -v` deletes the named volume, which **wipes the
  database**. The next `up` will run the init script against an empty data
  directory.

For an ad-hoc `psql` session against the running container (no host port is
published):

```bash
docker compose exec postgres psql -U orcaadmin orca
```

## Troubleshooting

- **Logs:** follow a service with `docker compose logs -f <service>` where `<service>` is one of `nginx`, `orca`, `postgres`, `mail`, `transaction-service`, `signing-service`, or `redis`. (The `acme` service is usually invoked with `docker compose run` rather than left running.)
- **ORCA uploads:** filesystem-backed media lives in the **`orca-uploads`** named volume (mounted at `/app/dev-uploads` in the `orca` container). It survives `docker compose restart` and is removed only if you delete the volume (e.g. `docker compose down -v` together with other volumes).
- **Installed certificates:** list what acme.sh has stored with  
  `docker compose run --rm -T acme --list --home /acme.sh`
