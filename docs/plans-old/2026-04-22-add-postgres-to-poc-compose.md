# Add Postgres to PoC compose (for the forthcoming ORCA container)

# Design

## Scope of work

Add a `postgres` service to `scotland-digital-badges-poc/docker-compose.yml`
so the soon-to-land `orca` container has a database to talk to inside the PoC
network. Cover:

- Compose service definition (image, env, volume, healthcheck, network).
- Schema/role bootstrap on first start (matching what ORCA's Prisma
  configuration expects).
- `.env.postgres.example` consistent with the existing
  `.env.transaction.example` / `.env.signing.example` pattern.
- `.gitignore` entry for the rendered env file.
- `docs/architecture.md` updates: a Postgres entry under "Planned software"
  plus the `Postgres` node and `ORCA --> Postgres` edge in the deployment
  mermaid diagram.
- `README.md` updates: first-run note for `.env.postgres`, lifecycle hint
  (`down -v` wipes the volume), and the `docker compose exec postgres
  psql ...` recipe.

**Out of scope** (handled by the larger
`orca/docs/plans/2026-04-22-orca-docker-and-poc-deploy/` plan):

- The ORCA container itself (image, compose service, env, depends_on).
- nginx routing for ORCA (`*.digitalbadges.scot`).
- LocalStack / S3 media plumbing.
- Prisma migrations execution (ORCA's entrypoint owns that — we just need
  a reachable DB with the right roles/schemas).

## File structure

```
docker-compose.yml                 # UPDATE: add postgres service + named volume
.env.postgres.example              # NEW: POSTGRES_USER/PASSWORD/DB template
.gitignore                         # UPDATE: ignore rendered .env.postgres
postgres/
└── init/
    └── 01-orca-db-and-schemas.sql # NEW: CREATE DATABASE orca + orca_public schema
README.md                          # UPDATE: first-run note + lifecycle / psql tips
docs/
└── architecture.md                # UPDATE: prose paragraph + mermaid Postgres node + edge
```

## Conceptual architecture

The PoC Compose boundary (with Postgres added):

```
                 ┌────────────────────────────────────────────────────────┐
                 │ digital-badges-network (Docker bridge)                 │
                 │                                                        │
host ── 80/443 ──┤ nginx ──► transaction-service ──► signing-service      │
                 │                       │                                │
                 │                       └────► redis                     │
                 │                                                        │
                 │           (future) ORCA ──► postgres   ◄── NEW         │
                 │                                                        │
                 └────────────────────────────────────────────────────────┘
```

## Main components and how they interact

- **`postgres` service** — `postgres:16-alpine`, container name
  `digital-badges-postgres`. Service DNS name is `postgres`, which is what
  ORCA's eventual `DATABASE_URL` will use as host. Joins
  `digital-badges-network` alongside the existing services. No host port
  mapping (internal only); operators reach it via
  `docker compose exec postgres psql -U orcaadmin orca`.
- **`postgres-data` named volume** — mounted at
  `/var/lib/postgresql/data`. Survives `docker compose down`; dropped only
  with `down -v`, which causes the init script to run again on the next
  `up`.
- **Init script `postgres/init/01-orca-db-and-schemas.sql`** —
  bind-mounted into `/docker-entrypoint-initdb.d/` so it executes once on
  a fresh data volume. Creates database `orca` and schema `orca_public
  AUTHORIZATION orcaadmin`. Header comment reminds future maintainers that
  the `AUTHORIZATION` identifier must match `POSTGRES_USER` in
  `.env.postgres`.
- **`.env.postgres` (and example)** — supplies `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `POSTGRES_DB`. Rendered file is gitignored; example
  is checked in. Header comment notes that ORCA's eventual `DATABASE_URL`
  must use the same user/password/db.
- **Healthcheck** — `pg_isready -U <user> -d <db>` on a 5s interval with
  `start_period: 10s` so the future ORCA service can use
  `depends_on: { postgres: { condition: service_healthy } }` and have a
  reliable signal that migrations can run.
- **`docs/architecture.md`** — adds a "Postgres" entry under "Planned
  software (selected for first deployment)" and extends the mermaid
  deployment diagram with a `Postgres["Postgres (internal only)"]` node
  plus an `ORCA --> Postgres` edge, mirroring the existing internal-only
  `TxService --> Signing` pattern.
- **`README.md`** — short "first run" note pointing operators at
  `.env.postgres.example`, the `down -v` lifecycle warning, and the
  `docker compose exec` psql recipe.

# Phases

## Phase 1: Compose service + init script + env example  [sub-agent: yes]

### Scope of phase

Land all the actual deployment changes for the new Postgres service in
`scotland-digital-badges-poc/` as one cohesive unit:

1. Add a `postgres` service block to `docker-compose.yml`.
2. Declare a top-level named volume `postgres-data`.
3. Create `postgres/init/01-orca-db-and-schemas.sql`.
4. Create `.env.postgres.example`.
5. Add `.env.postgres` to `.gitignore`.

**Out of scope for this phase** — do not edit `docs/architecture.md`, do
not edit `README.md`, do not add or modify any other Compose service
(no ORCA, no nginx routes, no LocalStack), do not add a top-level `.env`
or `${VAR}` interpolation, do not publish port `5432` to the host, do
not introduce a multi-stage Dockerfile or any image building.

### Repository organization reminders

- One concern per file. The init SQL goes in its own file under
  `postgres/init/`, not inlined into compose or merged with anything else.
- The `.env.postgres.example` follows the existing `.env.<role>.example`
  pattern (compare `.env.transaction.example`, `.env.signing.example`).
- Service / container names follow the existing pattern: service name is
  the role (`postgres`); container name is `digital-badges-<role>`
  (`digital-badges-postgres`).
- Indentation in `docker-compose.yml` is two spaces, matching the
  existing file.
- Named volumes use kebab-case (`postgres-data`), matching
  `digital-badges-network`.

### Relevant documentation and conventions

- **Existing compose file** (`docker-compose.yml`) — copy the visual
  shape of the existing service blocks (`# <role> - <one-line summary>`
  comment header, `image:`, `container_name:`, `env_file:`,
  `networks:`, `restart: unless-stopped`). The new service must not
  break any existing service.
- **Env file convention** — `.env.transaction.example` and
  `.env.signing.example` show the existing template style (header
  comment line explaining the file's purpose, then KEY="value" lines
  with short comments). `.gitignore` already lists `.env.transaction`
  and `.env.signing`; add `.env.postgres` to that group.
- **Architecture** (`docs/architecture.md`) — already says the Signing
  Service is reachable only on the Docker network. The new Postgres
  service must follow the same internal-only pattern (no `ports:`
  mapping). Do not edit the architecture doc in this phase; that is
  Phase 2.
- **Security** (`docs/security.md`) — reinforces "Unnecessary ports
  closed". Confirms the no-host-publish decision; nothing to edit.
- **ORCA's init script reference** — `orca/docker-support/postgres/`
  `docker-entrypoint-initdb.d/init-db-and-schemas.sql` in the sibling
  ORCA repo is the source of truth for the schema names ORCA's Prisma
  config expects. The PoC copy intentionally drops `orca_test`.

### Sub-agent reminders

- Do **not** commit. The plan commits at the end as a single unit.
- Do **not** expand scope. Stay strictly within "Scope of phase". In
  particular, do not edit `README.md` or `docs/architecture.md` — those
  are Phase 2.
- Do **not** commit secrets, production credentials, or short-lived
  tokens. The example file uses placeholder values only.
- Do **not** disable, skip, or weaken validation
  (`docker compose config`, `psql` checks) to greenwash the phase — fix
  or escalate.
- Do **not** publish port `5432` to the host.
- If something blocks completion, stop and report rather than improvising.
- Report back: what changed, what was validated, any deviations.

### Implementation Details

**1. `docker-compose.yml` — add the `postgres` service**

Insert a new service block on `digital-badges-network`. Place it
between `signing-service` and `redis` (groups stateful services
together visually). Use the existing `# <role> - <comment>` style.

Service block to add (substitute the agreed values verbatim):

```yaml
  # Postgres - Persistence layer for ORCA (internal only, not exposed externally)
  postgres:
    image: postgres:16-alpine
    container_name: digital-badges-postgres
    env_file:
      - .env.postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U orcaadmin -d orca"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    networks:
      - digital-badges-network
    restart: unless-stopped
```

Then add a top-level `volumes:` section at the bottom of the file (the
existing file has only `networks:` today — add `volumes:` as a sibling
of `networks:`):

```yaml
volumes:
  postgres-data:
```

The `pg_isready` user/db are hard-coded in the healthcheck because
Compose evaluates `healthcheck.test` strings before `env_file` values
are available to interpolation in older Compose versions. We keep the
init script and the healthcheck in lockstep with the documented values
in `.env.postgres.example`. The init SQL file's header comment (below)
will repeat this constraint so future maintainers don't drift them.

**2. `postgres/init/01-orca-db-and-schemas.sql`**

Create the directory `postgres/init/` and add a single file
`01-orca-db-and-schemas.sql` containing:

```sql
-- Bootstrap ORCA's database and schema on first start.
--
-- Runs once when the Postgres data volume is empty (Postgres image
-- behaviour for /docker-entrypoint-initdb.d/*.sql files).
--
-- IMPORTANT: The AUTHORIZATION identifier below ("orcaadmin") must
-- match POSTGRES_USER in .env.postgres, and the database name "orca"
-- must match POSTGRES_DB. The healthcheck in docker-compose.yml also
-- references both. Keep all three in sync if you ever rename them.
--
-- ORCA's Prisma config expects database "orca" and schema
-- "orca_public". The "orca_test" schema used by ORCA's local unit
-- tests is intentionally NOT created here (the deployed PoC does not
-- run those tests).

CREATE DATABASE orca;
\connect orca;
CREATE SCHEMA orca_public AUTHORIZATION orcaadmin;
```

**3. `.env.postgres.example`**

Place at the repo root alongside the other `.env.<role>.example` files.
Use the same header-comment style as `.env.transaction.example`:

```
# Postgres Environment Template
# Copy to .env.postgres and fill in a real password before first start.
#
# IMPORTANT: ORCA's DATABASE_URL (set in the ORCA service's env file,
# defined by a separate plan) must use the SAME user, password, and db
# name as the values below. The healthcheck in docker-compose.yml and
# the init script in postgres/init/ also reference "orcaadmin" and
# "orca" — if you change either of those names here, update those two
# locations as well.

POSTGRES_USER=orcaadmin
POSTGRES_PASSWORD=changeme
POSTGRES_DB=orca
```

**4. `.gitignore`**

Append `.env.postgres` to the "Environment files" group, matching the
existing entries for `.env.signing` and `.env.transaction`:

```
.env.signing
.env.transaction
.env.postgres
```

(Keep the existing comment header above the group; just add the new
line.)

### Acceptance checks for Phase 1

- `docker compose config` from the repo root renders without errors and
  shows the `postgres` service with the healthcheck, env_file, and
  volume mounts (named volume + init bind-mount) defined, attached to
  `digital-badges-network`.
- A rendered `.env.postgres` (copied locally from the example, NOT
  committed) and `docker compose up -d postgres` reaches the `healthy`
  state within ~30 seconds (visible via `docker compose ps`).
- `docker compose exec postgres psql -U orcaadmin -d orca -c '\dn'`
  lists the `orca_public` schema (proves the init script ran with the
  right `AUTHORIZATION`).
- `docker compose down && docker compose up -d postgres` re-uses the
  persisted volume; the second `up` does not re-run the init script
  (no init log lines on the second start).
- `lsof -nP -iTCP:5432 -sTCP:LISTEN` (or `ss -ltn | grep 5432`) on the
  Docker host returns no listener related to this stack — port `5432`
  must not be published.
- `git status` shows `.env.postgres` is **not** staged or untracked
  visible (because of the `.gitignore` entry).

### Validate

- `docker compose config` (from repo root).
- `docker compose up -d postgres` followed by `docker compose ps`,
  the `psql ... \dn` check, and the `down && up` persistence check
  described above. Use a temporary local `.env.postgres` for these
  checks; do not commit it.
- After validation, `docker compose down -v` to leave a clean slate
  for the next phase / reviewer.

No tests exist in this repo and none are added by this phase, so the
checks above are the validation surface.

## Phase 2: Architecture & README documentation updates  [sub-agent: yes]

### Scope of phase

Update the documentation in `scotland-digital-badges-poc/` so it
reflects the new Postgres service that landed in Phase 1:

1. `docs/architecture.md` — add a "Postgres" entry under "Planned
   software (selected for first deployment)" and extend the deployment
   mermaid diagram with a `Postgres["Postgres (internal only)"]` node
   and an `ORCA --> Postgres` edge.
2. `README.md` — add a short "first run" / lifecycle / `psql` recipe
   note covering `.env.postgres` setup, `docker compose down -v` data
   loss warning, and the `docker compose exec postgres psql ...`
   recipe.

**Out of scope for this phase** — do not edit `docker-compose.yml`,
`.gitignore`, `.env.postgres.example`, or anything under `postgres/`
(those landed in Phase 1). Do not edit `docs/security.md` or
`docs/standards.md` (no relevant updates needed). Do not add new pages
under `docs/`. Do not change other parts of `docs/architecture.md`
beyond the two specified additions.

### Repository organization reminders

- Keep documentation aligned with what the Compose file actually does.
  Do not introduce documentation that contradicts Phase 1 (e.g. do not
  imply Postgres is reachable from the host).
- The "Planned software (selected for first deployment)" section uses
  `### <Service>` subheadings followed by a single short paragraph.
  Match that shape for the new Postgres entry.
- The mermaid diagram fences are `\`\`\`{.mermaid format=png}` (not
  plain `\`\`\`mermaid`); preserve the existing fence syntax exactly so
  the PDF build keeps rendering it.
- README "first run" content stays terse — this repo's README is short
  and pointer-style today, not a tutorial.

### Relevant documentation and conventions

- **Architecture** (`docs/architecture.md`) — the existing "Planned
  software" subsections (DCC Transaction Service, DCC Signing Service,
  ORCA, nginx) set the tone for the new Postgres entry: one paragraph,
  framed by what the service *does* in the deployment, with explicit
  mention of internal-only exposure where applicable (Signing Service
  is the precedent).
- **Architecture mermaid diagram** — already contains a `Services`
  subgraph with `ORCA`, `TxService`, `Future`, and a separate
  `Signing` node. The internal-only pattern to mirror is
  `TxService --> Signing`. Add `Postgres["Postgres (internal only)"]`
  inside the `Services` subgraph and an `ORCA --> Postgres` edge below
  the existing edges.
- **PDF build script** (`scripts/build-poc-architecture-pdf.sh`) —
  consumes `docs/architecture.md`. Both edits must keep the build
  green; that's verified in the cleanup phase, but locally Phase 2
  should run it once as a smoke check.
- **README** (`README.md`) — currently 7 lines describing the repo's
  purpose and mentioning that compose references published images.
  Match its terse style.

### Sub-agent reminders

- Do **not** commit. The plan commits at the end as a single unit.
- Do **not** expand scope. Stay strictly within "Scope of phase". Do
  not "improve" other sections of `architecture.md` or `README.md`
  while you're in the file.
- Do **not** rewrite the entire mermaid diagram. Add exactly one node
  and exactly one edge.
- Do **not** add a TODO marker for the future `Nginx --> ORCA` edge
  (the bigger ORCA plan owns that edge — leaving a TODO would cause
  doc drift).
- If the PDF build fails because pandoc / a PDF engine isn't
  installed, stop and report — do not weaken the doc to dodge the
  build. The cleanup phase has the option of a supervised path.
- Report back: what changed in each file, whether the local PDF build
  passed, any deviations.

### Implementation Details

**1. `docs/architecture.md` — prose addition**

Add a new `### Postgres` subsection under "Planned software (selected
for first deployment)", immediately after the existing `### nginx`
subsection (so internal infrastructure is grouped at the end of the
list). Suggested content (one paragraph, similar length to the Signing
Service paragraph):

```markdown
### Postgres

ORCA's persistence layer: tenant configuration, achievement
definitions, and credential / claim metadata. Runs as a container on
the same Docker Compose network as the application services so ORCA
can reach it by service DNS name (`postgres`). Reachable only on the
Docker network — not exposed via nginx and not published to the host.
Schema bootstrap (`orca` database, `orca_public` schema) runs once on
first start from a checked-in init script; data persists across
restarts via a named Docker volume.
```

**2. `docs/architecture.md` — mermaid diagram edits**

Inside the `Services` subgraph, add the Postgres node next to the
other services. Inside the body of the diagram (alongside the
existing `TxService --> Signing` edge), add the ORCA → Postgres edge.

The existing diagram is:

```
flowchart TB
  subgraph Clients
    Browsers["Browsers / staff / learners"]
    LCW["LCW on devices"]
  end

  Browsers --> Nginx
  LCW -->|"HTTPS to api.*"| Nginx
  Nginx["TLS at nginx"]

  Nginx --> ORCA
  Nginx --> TxService
  Nginx --> Future

  subgraph Services
    ORCA["ORCA (apex host)"]
    TxService["Transaction Service (api subdomain)"]
    Future["future: VerifierPlus, OIDF registry on reserved subdomains"]
  end

  TxService --> Signing
  ORCA -.->|"coordinates / uses for exchange flows"| TxService

  Signing["Signing Service (internal only)"]
```

Two edits required (do not change anything else):

- Add `Postgres["Postgres (internal only)"]` inside the `Services`
  subgraph, on a new line after `Future`.
- Add `ORCA --> Postgres` after the existing `TxService --> Signing`
  line.

The mermaid fence (`\`\`\`{.mermaid format=png}`) and the closing
fence stay untouched.

**3. `README.md` — first-run / lifecycle / psql recipe**

Append a new section to `README.md` (the file is currently 7 lines).
Suggested heading: `## First run`. Suggested content (terse, matches
the existing pointer-style):

```markdown
## First run

Each service has a `.env.<role>.example` template at the repo root
(`.env.transaction.example`, `.env.signing.example`,
`.env.postgres.example`). For each one, copy to `.env.<role>` and fill
in real values before starting the stack. Rendered `.env.<role>`
files are gitignored.

Bring the stack up with:

\`\`\`bash
docker compose up -d
\`\`\`

### Postgres lifecycle

The `postgres` service stores its data in a named volume
(`postgres-data`), so:

- `docker compose down` preserves the database; the next `up` reuses
  the existing data and **does not** re-run the schema init script.
- `docker compose down -v` deletes the named volume, which **wipes the
  database**. The next `up` will run the init script against an empty
  data directory.

For an ad-hoc `psql` session against the running container (no host
port is published):

\`\`\`bash
docker compose exec postgres psql -U orcaadmin orca
\`\`\`
```

(Replace the literal backslash-backticks above with real triple
backticks in the README — they are escaped here so this plan file
itself renders cleanly.)

### Acceptance checks for Phase 2

- `docs/architecture.md` contains the new `### Postgres` subsection
  in the "Planned software" section.
- `docs/architecture.md` mermaid diagram contains `Postgres["Postgres
  (internal only)"]` inside the `Services` subgraph and an
  `ORCA --> Postgres` edge in the diagram body.
- `README.md` contains a `## First run` section that mentions
  `.env.postgres.example`, the `down -v` data-loss warning, and the
  `docker compose exec postgres psql ...` recipe.
- `docker-compose.yml`, `.gitignore`, `.env.postgres.example`, and
  `postgres/init/01-orca-db-and-schemas.sql` from Phase 1 are
  unchanged.
- `scripts/build-poc-architecture-pdf.sh` runs without errors and
  produces an updated PDF (assuming pandoc + a PDF engine are
  available on the runner — if not, escalate).

### Validate

- `scripts/build-poc-architecture-pdf.sh` (from repo root). Confirm
  the new Postgres node and edge appear in the rendered PDF.
- Visual inspection of the diff for `docs/architecture.md` to confirm
  no other content changed.
- Visual inspection of the diff for `README.md` to confirm only the
  appended section is new.

If pandoc / a PDF engine is missing on the runner and cannot be
installed, stop and report — the cleanup phase will rebuild the PDF
under supervision.

## Phase 3: Cleanup, review, and validation  [sub-agent: supervised]

### Scope of phase

Final pass over everything Phase 1 and Phase 2 produced, then archive
the plan and prepare a single commit. No new functionality.

1. Grep the staged + unstaged diff for stray TODOs, scratch files,
   commented-out blocks, debug logging, or any temporary scaffolding;
   remove what shouldn't ship.
2. Re-run the full validation suite end-to-end (compose config, full
   `up`, healthy state, schema check, persistence check, port check,
   PDF build). Confirm all 7 acceptance criteria from the
   `# Design` / Q9 list are met.
3. Move the plan file from `docs/plans/` to `docs/plans-old/`.
4. Move the unanswered-questions section from the plan body to the
   bottom under `# Notes` (already done — confirm it's still in
   place after the move).
5. Append a `# Decisions for future reference` section to the plan
   file. Most decisions in this plan are mechanical or already
   captured in code/compose; only record the few that future readers
   might re-litigate.
6. Create a single conventional commit covering all changes from
   Phases 1 + 2 + 3.

**Out of scope for this phase** — do not push to a remote, do not
open a pull request (the user will do that via their normal team
process), do not amend any earlier commit (there shouldn't be any
intermediate commits to amend), do not rewrite the design or change
the behaviour shipped by Phases 1/2.

### Repository organization reminders

- The plan ends up in `docs/plans-old/<YYYY-MM-DD>-<plan-name>.md`
  via `git mv` (history preservation, even though `docs/plans` is
  gitignored — `git mv` will still record the rename in the new
  location).
- The commit message body must include the line
  `Plan: docs/plans-old/2026-04-22-add-postgres-to-poc-compose.md`.

### Relevant documentation and conventions

- **plan-short template** (the `/scotland-digital-badges-poc/plan-short`
  Cursor command) — defines the cleanup-and-validation, plan-archive,
  and decisions-section conventions. Follow it.
- **Conventional Commits** — `<type>(<scope>): <description>` then
  optional bulleted body. Scope candidate: `compose` (the dominant
  change is to `docker-compose.yml`); fall back to `chore` only if
  unsure.

### Sub-agent reminders

- Marked **supervised**: the main agent will review your plan before
  you commit. Do **not** push, force-push, or amend.
- Do **not** introduce new behaviour. This is a cleanup / packaging
  phase only.
- Do **not** weaken or skip any validation step to make it pass; if
  something fails, stop and report.
- Do **not** commit `.env.postgres` (the rendered file, if you used
  one for testing). Re-run `docker compose down -v` to drop the test
  volume before committing.

### Implementation Details

**1. Cleanup grep.** Run from repo root:

```bash
git status
git diff
git diff --staged
```

Inspect for: TODO/FIXME markers added by Phase 1/2, commented-out
SQL or compose blocks, scratch directories (e.g. an accidentally
committed `postgres/data/`), accidental `.env.postgres` (rendered),
trailing whitespace, leftover testing edits to other services.
Remove anything that shouldn't ship.

**2. Full validation pass (the 7 acceptance criteria).**

```bash
docker compose config                                                    # AC #1
cp .env.postgres.example .env.postgres                                   # local, do not commit
docker compose up -d postgres                                            # AC #2
docker compose ps                                                        # confirm healthy
docker compose exec postgres psql -U orcaadmin -d orca -c '\dn'          # AC #3
docker compose down
docker compose up -d postgres                                            # AC #4
docker compose logs postgres | grep -i 'CREATE DATABASE' || echo "no init log on second up — good"
lsof -nP -iTCP:5432 -sTCP:LISTEN || echo "no host listener — good"       # AC #5
scripts/build-poc-architecture-pdf.sh                                    # AC #6
git check-ignore -v .env.postgres                                        # AC #7 (path is ignored)
docker compose down -v                                                   # cleanup
rm -f .env.postgres                                                      # cleanup
```

Fix any failures. Do not lower the bar.

**3. Plan archive.**

```bash
mkdir -p docs/plans-old
git mv docs/plans/2026-04-22-add-postgres-to-poc-compose.md \
       docs/plans-old/2026-04-22-add-postgres-to-poc-compose.md
```

(`git mv` will still record the move even with the source path
gitignored, because the destination is tracked.)

**4. Decisions section.**

Append to the moved plan file. Most of this plan is mechanical, so
expect 0–2 entries. Candidates worth recording:

- "Don't publish 5432 to the host" — the constraint (security
  posture) might be forgotten in a future debugging push.
- "Per-service `.env.postgres` instead of top-level `.env`" — there
  was a real fork in the road (option A vs B in Q2) that future
  readers might want to reopen.

If neither feels worth recording in retrospect, write
`No notable decisions.` and move on.

**5. Commit.**

Pre-commit, sanity check:

```bash
git status
git diff --staged --stat
```

Then commit (single commit, conventional commits format, plan path in
the body):

```bash
git add docker-compose.yml \
        .env.postgres.example \
        .gitignore \
        postgres/init/01-orca-db-and-schemas.sql \
        docs/architecture.md \
        README.md \
        docs/plans-old/2026-04-22-add-postgres-to-poc-compose.md

git commit -m "$(cat <<'EOF'
feat(compose): add internal Postgres service for ORCA

- Add postgres:16-alpine service to docker-compose.yml on
  digital-badges-network with named volume, healthcheck, and
  init script bind-mount; not published to the host.
- Add postgres/init/01-orca-db-and-schemas.sql to bootstrap the
  orca database and orca_public schema on first start.
- Add .env.postgres.example template; gitignore .env.postgres.
- Document Postgres in docs/architecture.md (prose entry under
  Planned software, plus mermaid node and ORCA --> Postgres edge).
- Add a "First run" section to README.md covering env files,
  Postgres lifecycle, and the docker compose exec psql recipe.

Plan: docs/plans-old/2026-04-22-add-postgres-to-poc-compose.md
EOF
)"

git status
```

### Acceptance checks for Phase 3

- All 7 acceptance criteria from `# Design` / Q9 pass without
  weakening any check.
- No `TODO`, `FIXME`, scratch file, or rendered `.env.postgres` in the
  staged diff.
- `docs/plans/2026-04-22-add-postgres-to-poc-compose.md` is gone;
  `docs/plans-old/2026-04-22-add-postgres-to-poc-compose.md` exists
  and contains the moved plan plus the appended `# Decisions for
  future reference` section.
- Exactly one commit, conventional-commits format, with the plan path
  in the body.

### Validate

- The 7-criterion validation block above (already executed as part
  of step 2). Re-run `docker compose config` and
  `scripts/build-poc-architecture-pdf.sh` one final time after the
  plan move to confirm nothing regressed.
- `git log -1 --stat` to confirm the commit shape and message
  formatting.

# Notes

(Original Q&A retained below for reference — answers above represent the
agreed design.)

## Q1 — Postgres image and version

**Answer.** `postgres:16-alpine`. Pinned major avoids surprise jumps from
`latest`; alpine variant matches `redis:7-alpine` / `nginx:alpine`;
Postgres 16 is in the active support window through Nov 2028.

## Q2 — Credentials and env file shape

**Answer.** Per-service `.env.postgres` / `.env.postgres.example` defining
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, matching the existing
`.env.<name>` convention. Header comment in the example file flags that
ORCA's `DATABASE_URL` (set in the bigger ORCA plan's `.env.orca`) must use
the same values.

## Q3 — Schema bootstrap (init script)

**Answer.** Copy a trimmed `postgres/init/01-orca-db-and-schemas.sql` into
the PoC repo containing `CREATE DATABASE orca;` + `CREATE SCHEMA
orca_public AUTHORIZATION orcaadmin;` only (`orca_test` dropped — only
ORCA's local unit tests use it). Header comment notes that the
`AUTHORIZATION` identifier must match `POSTGRES_USER` in `.env.postgres`.

## Q4 — Port exposure to the host

**Answer.** `5432` is **not** published. README documents the
`docker compose exec postgres psql -U orcaadmin orca` recipe for ad-hoc
sessions. Matches the principle of least exposure in `docs/security.md`
and the existing internal-only pattern (`signing-service`, `redis`).

## Q5 — Persistence and volume naming

**Answer.** Named volume `postgres-data` mounted at
`/var/lib/postgresql/data`. README documents lifecycle:
`docker compose down` preserves data; `docker compose down -v` drops the
volume so the init script re-runs on next `up`.

## Q6 — Healthcheck

**Answer.** `pg_isready` healthcheck:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U orcaadmin -d orca"]
  interval: 5s
  timeout: 5s
  retries: 10
  start_period: 10s
```

Values for `-U` / `-d` track `POSTGRES_USER` / `POSTGRES_DB` from
`.env.postgres`.

## Q7 — Service name and container name

**Answer.** Service name `postgres` (so ORCA's `DATABASE_URL` host is
`postgres`). Container name `digital-badges-postgres`. Matches the repo's
`<role>` / `digital-badges-<role>` naming convention.

## Q8 — Documentation updates

**Answer.** Both edits land in this plan: a "Postgres" prose entry under
"Planned software" in `docs/architecture.md`, and a `Postgres` node plus
`ORCA --> Postgres` edge added to the mermaid deployment diagram. PDF
rebuild via `scripts/build-poc-architecture-pdf.sh` is part of the
cleanup phase's validation.

## Q9 — Acceptance criteria

**Answer.** Confirmed:

1. `docker compose config` from the repo root renders without errors and
   shows the new `postgres` service on `digital-badges-network` with the
   healthcheck and volume defined.
2. `docker compose up -d postgres` brings the service to `healthy`
   (`docker compose ps`).
3. `docker compose exec postgres psql -U orcaadmin -d orca -c '\dn'`
   lists `orca_public` (proves the init script ran with the right
   `AUTHORIZATION`).
4. `docker compose down && docker compose up -d postgres` re-uses the
   persisted volume and does **not** re-run the init script (verifiable
   by absence of init log lines on the second `up`).
5. `5432` is **not** open on the host (`lsof -nP -iTCP:5432 -sTCP:LISTEN`
   returns nothing related to this stack).
6. `docs/architecture.md` mentions Postgres in the prose, the mermaid
   diagram includes the `Postgres` node and `ORCA --> Postgres` edge, and
   `scripts/build-poc-architecture-pdf.sh` builds clean.
7. `.env.postgres.example` is checked in and referenced from the README's
   "first run" section; rendered `.env.postgres` is in `.gitignore`.

# Decisions for future reference

## Init script creates the schema only, not the database

- **Decision:** `postgres/init/01-orca-db-and-schemas.sql` runs only
  `CREATE SCHEMA IF NOT EXISTS orca_public AUTHORIZATION orcaadmin;`. It
  does **not** issue `CREATE DATABASE orca;`. The database is created
  by the official `postgres` image from `POSTGRES_DB=orca` in
  `.env.postgres`, before init scripts run.
- **Why:** The image's docker-entrypoint creates `POSTGRES_DB` first,
  then runs `/docker-entrypoint-initdb.d/*.sql` files inside that
  database with `psql -v ON_ERROR_STOP=1`. A `CREATE DATABASE orca;` in
  the init script collides with the already-existing database, raises
  an error, and aborts the rest of the script — so `orca_public` never
  gets created. (Discovered the hard way during validation in this
  plan.) The sibling ORCA repo's local-dev init script gets away with
  `CREATE DATABASE orca;` only because it does NOT set `POSTGRES_DB`,
  so the image creates a default `orcaadmin` database and the script's
  `CREATE DATABASE orca` is the first time `orca` exists.
- **Rejected alternatives:** Drop `POSTGRES_DB` from `.env.postgres`
  and let the init script own database creation (mirrors ORCA's local
  setup, but means the healthcheck `pg_isready -d orca` could race the
  init script on first boot, and we lose the image's automatic
  ownership wiring).
- **Revisit when:** Switching to a non-`postgres`-image runtime, or if
  ORCA grows a need for additional databases that can't be expressed as
  schemas inside `orca`.

## Port 5432 is not published to the host

- **Decision:** The `postgres` service has no `ports:` mapping in
  `docker-compose.yml`. Operators reach it via
  `docker compose exec postgres psql ...`, which is documented in the
  README's "First run" section.
- **Why:** Postgres is only consumed inside the Compose network (by
  the future ORCA service). Publishing 5432 would broaden the attack
  surface unnecessarily and contradict `docs/security.md`'s "unnecessary
  ports closed" control. Matches the pattern set by `signing-service`
  and `redis` (also internal-only, no host port).
- **Rejected alternatives:** Publish `5432:5432` for ad-hoc `psql`
  convenience (rejected — `docker compose exec` is the documented
  recipe and doesn't widen exposure).
- **Revisit when:** A non-containerised debugging workflow becomes
  routine enough to justify the exposure (e.g. a desktop SQL client is
  in regular use), at which point exposing on `127.0.0.1:5432` only
  (not `0.0.0.0`) would be the right scope.
