# Plan process (implementation planning)

## Execution model

Plans are executed primarily by delegating phases to **Composer 2 sub-agents**.
The main agent (you) acts as planner, dispatcher, and reviewer; sub-agents do
the bulk of the implementation work.

This has consequences that shape the rest of this document:

- **Phases must be self-contained.** A sub-agent does not share your
  conversation context. Each phase file must stand on its own as a complete
  prompt: scope, files involved, implementation details, validation command,
  and definition of done.
- **Phases should be sized for one autonomous run.** Small enough to verify in
  a single review pass, large enough to be worth spinning up.
- **Parallelize when phases are independent.** When two or more phases touch
  disjoint files and have no ordering dependency, dispatch them as parallel
  sub-agents. If unsure, run sequentially — merge conflicts cost more than
  parallelism saves. In this repository the most common parallelism unit is
  "one Compose service vs. another" or "doc edits vs. independent script
  changes"; ingress and shared docs (`docs/architecture.md`,
  `nginx/*.conf` if present) tend to serialize.
- **The main agent reviews every phase.** Sub-agents cut corners (scope creep,
  drive-by refactors, suppressing rather than fixing warnings, weak validation,
  premature commits, leaked secrets). Review is mandatory — see the "Phase
  Execution & Review" section below.
- **Commits happen at the end of the plan, not between phases.** See "Commit"
  at the bottom. Sub-agents must be told explicitly not to commit.

Planning, design, and question iteration are _not_ sub-agent work — they need
direct user interaction and stay with the main agent.

This repository holds **deployment orchestration and documentation** for the
Scottish digital badges PoC. Application services (ORCA, the DCC stack) ship as
**published Docker images** that Compose / ingress configuration here references;
this repo is not the source of those services.

## Setup

Decide on a name for the plan. Referred to as `<plan-name>` in this document.

**From a roadmap milestone:** When the plan implements a roadmap milestone,
create the plan directory at:

`docs/plans/<YYYY-MM-DD>-<roadmap-name>-m<N>-<milestone-name>/`

- `<YYYY-MM-DD>` is the date you start the plan (use `date +%Y-%m-%d`).
- `<roadmap-name>` matches the slug from the roadmap folder
  `docs/roadmaps/<any-date>-<roadmap-name>/` (same name segment after the
  roadmap's date prefix; the plan may use a different date).
- `<N>` is the arabic milestone number (`1`, `2`, `3`, …) matching the
  milestone file `m<N>-<milestone-name>.md` in the roadmap.
- `<milestone-name>` is the milestone's slug, copied verbatim from the part
  of the milestone filename after `m<N>-` (without the `.md`).

Example: roadmap folder `docs/roadmaps/2026-04-20-issuer-trust-baseline/`
with milestone file `m1-compose-skeleton.md` → plan directory
`docs/plans/2026-04-20-issuer-trust-baseline-m1-compose-skeleton/`.

Confirm the suggested name with the user before creating the directory.

**Standalone:** For work not tied to a roadmap, use a short descriptive
`<plan-name>` and create `docs/plans/<YYYY-MM-DD>-<plan-name>/`.

This directory will contain the plan files for the plan.

**Note**: Most work runs from the **repository root**. If the plan touches a
specific subdirectory (e.g. a future `compose/`, `nginx/`, `scripts/`, or
environment template tree), commands for that slice should be run from inside
that directory. If unsure, check the plan or ask which directory contains the
relevant files.

## Analysis

Analyze the current scope of work, and populate a `00-notes.md` file with the
following sections:

- The scope of work
- The current state of the repository as it pertains to the scope of work
  (which docs, scripts, Compose fragments, ingress configs are involved; which
  external Docker images are touched)
- Questions that need to be answered to complete the plan. Each question should
  include context and a suggested answer.

## Question Iteration

First, **triage the questions** into two buckets:

- **Confirmation-style questions** — small "is this right?" / "use X here?"
  / "name this Y?" questions where you have a clear suggested answer and
  the user is mostly sanity-checking. These are fast to scan.
- **Discussion-style questions** — anything that needs real back-and-forth:
  open architectural choices, trade-offs, ambiguous scope, anything where
  you don't have a confident suggested answer.

If there are several confirmation-style questions (roughly 3+), batch them
into **one table at the top** that the user can scan and answer in a single
pass. Use the CHAT interface, not the question interface (the question
interface causes problems in cursor). Format:

| #   | Question                            | Context (1 line)                       | Suggested answer |
| --- | ----------------------------------- | -------------------------------------- | ---------------- |
| Q1  | Use `api.digitalbadges.scot` for X? | Matches PoC hostname table in arch doc | Yes              |
| Q2  | Pin image to digest, not `latest`?  | Standard for reproducible deploys      | Yes              |
| Q3  | Keep signing service internal-only? | Already the documented topology        | Yes              |

Tell the user they can answer with something like `Q1 yes, Q2 → tag v1.4,
Q3 yes` — or just "all yes" / "lgtm" if the suggestions all stand. Anything
they push back on graduates to a discussion-style question.

Then ask the discussion-style questions **ONE AT A TIME** in chat. Each
should include:

- the question
- the current state of the repository as it pertains to the question
- your suggested course forward

**Make each question visually obvious in the chat stream.** A short
"Q7. should we …" buried in a paragraph of analysis is easy to miss. Lead
with a prominent header and separator so the user can scan the chat and
immediately see that a new question has arrived. Use this shape:

```
---

## Q7: <one-line question>

<context — current state of the repository as it pertains to this question>

**Suggested answer:** <your recommended course forward, in 1–3 lines>
```

Use a top-level `##` header with the question number and a horizontal
rule (`---`) above it. Keep the question itself on the header line so it
shows up clearly when the user scrolls. Long context goes below the
header, not in it.

The user will answer the question or ask follow up questions.

We must ensure that we have clear acceptance criteria for the plan. There
should be a phase at the end for verifying the acceptance criteria and
debugging.

Once a question (batched or individual) is answered or otherwise resolved:

- Record the answers in the `00-notes.md` file.
- If the user's answers imply additional questions, add them to the file.
  New confirmation-style questions can be batched into another small table;
  new discussion-style questions are asked one at a time.
- If the user's answers include other notes, add them to the file in a
  `# Notes` section.
- If the user's answers affect other questions or the scope of work,
  update the file accordingly before moving on.
- Move on to the next question.

## Design Iteration

Once questions are answered, you will present me with a suggestion of an
architecture design with two main elements:

The file structure as a bare-bones ascii file tree of the relevant directories
and files.
Do NOT create a file to show the file tree, print it to the user in a code
block, like this:

```
compose/
└── services.yml                # NEW: internal signing service definition
nginx/
└── conf.d/
    └── api.conf                # UPDATE: route api.digitalbadges.scot to tx svc
docs/
└── architecture.md             # UPDATE: refresh routing diagram + hostname table
```

A summary of the conceptual architecture. This could be ASCII art, a diagram,
or a service list. It should summarize the main images, ingress paths, and
internal dependencies in an easy to understand way.

If I want to make changes, I will tell you and you will show me relevant updates
to the file tree and architecture summary.

## Design Completion

Once the design is agreed, you will create a new file called `00-design.md` with
the design overview.

The design file should include:

- Scope of work
- File structure (as shown above)
- Conceptual architecture summary
- Main components and how they interact

## Documentation and conventions review

Before drafting plan phases, read the in-repo docs that govern the PoC:

- [docs/architecture.md](../../docs/architecture.md) — service boundaries,
  Compose topology, hostnames, integration with ORCA and DCC images
- [docs/standards.md](../../docs/standards.md) — interoperability profile and
  normative references for credential flows
- [docs/security.md](../../docs/security.md) — security posture and the five
  Cyber Essentials controls

Identify which of these (plus any orchestration conventions in-repo, e.g.
image tag/digest policy, secrets handling, environment naming) are relevant to
the planned work. These will be called out in each phase file so sub-agents
implementing the phases follow the right conventions.

# Plan phases

Consider how best to break down the work into phases. Optimize for phases that
a sub-agent can execute autonomously: self-contained scope, clear file
boundaries, explicit validation.

Present phase suggestions to me, like this example. Tag each phase with:

- **parallel:** which other phases (if any) it can run in parallel with
  (touches disjoint files, no dependency on their output).
- **sub-agent:** `yes` (default), `supervised` (sub-agent works but main agent
  should pair closely), or `main` (must be done by main agent — usually
  because it requires user interaction or cross-cutting judgment).

Example:

```
1. Document new hostname + topology in architecture.md   [sub-agent: yes,  parallel: -]
2. Add Compose service for transaction service           [sub-agent: yes,  parallel: 3]
3. Add Compose service for signing service               [sub-agent: yes,  parallel: 2]
4. Add nginx route for api.digitalbadges.scot            [sub-agent: yes,  parallel: -]
5. Add example env files and document secrets handling   [sub-agent: yes,  parallel: -]
6. Cleanup, review, and validation                        [sub-agent: supervised]
```

I will then make suggestions to change the phases, or add more phases.

Once I tell you that we're ready to start, save the phases to the plan
directory.

# Phase Files

The names of the phase files should be like: `01-phase-title.md`,
`02-phase-title.md`, etc.

Every phase file must be **self-contained**: a sub-agent will read only this
file (plus any other files it explicitly references) and must have everything
it needs to do the work.

Every phase file should include:

## Scope of phase

A short summary of the scope of work for the phase. Be explicit about what is
**out of scope** — sub-agents are prone to scope creep.

## Repository organization reminders

Every phase should include some quality reminders suited to orchestration work.

- Prefer a clear layout: one concern per file (one Compose overlay, one nginx
  vhost, one env example per environment class).
- Keep **docs aligned with what Compose and scripts actually deploy** —
  diagrams, hostnames, and security claims should not drift from the configs.
- Pin external images to digests or specific tags; do not introduce `latest`.
- Any temporary scaffolding (debug services, throwaway env files) should have
  a TODO or be removed before the final phase.

## Relevant documentation and conventions

Each phase file must include a **Relevant documentation and conventions**
section listing the in-repo docs that apply to that phase. For each relevant
item:

- Reference the specific file path (e.g., `docs/architecture.md`)
- Briefly note how it applies to this phase's work

Example:

```markdown
### Relevant documentation and conventions

- **Architecture** (`docs/architecture.md`) — New hostname and traffic path
  must match the deployment diagram and the PoC hostnames section.
- **Standards** (`docs/standards.md`) — Any change to issuance/verification
  flow must stay within the VCALM–EdDSA profile selections.
- **Security** (`docs/security.md`) — Ingress and exposure changes must not
  contradict the documented Cyber Essentials controls.
- **Image policy** (in-repo, when adopted) — External images pinned by tag or
  digest; record the chosen reference in `docs/architecture.md` if it shifts.
```

Not every doc applies to every phase — only include the ones relevant to that
phase's work.

## Sub-agent reminders

Phases dispatched to a sub-agent should include explicit guardrails:

- Do **not** commit. The plan commits at the end as a single unit.
- Do **not** expand scope. Stay strictly within "Scope of phase".
- Do **not** commit secrets, production credentials, certificates, or
  short-lived tokens. Use placeholder values in env examples.
- Do **not** weaken validation (skip a check, comment out a Compose service,
  loosen nginx config, or weaken existing tests where they exist) to make a
  phase appear to pass. Fix or escalate.
- If something blocks completion (ambiguity, unexpected design issue), stop
  and report back rather than improvising.
- Report back: what changed, what was validated, and any deviations from the
  phase plan.

## Implementation Details

Be specific and detailed. Reference relevant existing files and external image
references by path / coordinate. Provide enough context that a fresh sub-agent
— with no memory of the design discussion — can execute the phase correctly.

Include **acceptance checks** for the phase (doc PDF builds, `docker compose
config` renders, nginx syntax check, link integrity), not only application
unit tests, which generally live in the repos that produce the images.

## Validate

Specify exactly which commands should be run to validate the phase. Examples
tied to this repository:

- After **Markdown** changes under `docs/`:
  `scripts/build-poc-architecture-pdf.sh` (requires pandoc and a PDF engine).
- When **Compose** files exist:
  `docker compose config` (or the project's equivalent) from the directory
  containing the compose file.
- For **nginx** config: `nginx -t` against the candidate config (e.g. inside a
  short-lived container) when nginx files are present.
- For **shell** changes: optional `shellcheck` on edited scripts if available.

If only plan notes under `docs/plans/` changed, validation may be "none beyond
review" — say so explicitly.

We want docs, configs, and scripts to stay consistent as we go. Clean up
warnings that won't be fixed in later phases.

# Phase Execution & Review

For each phase (or each parallel group of phases):

1. **Dispatch.** Launch a sub-agent with the phase file as its prompt, unless
   the phase is tagged `main`. For parallel groups, dispatch all sub-agents in
   the group concurrently.
2. **Wait for completion.** Collect each sub-agent's report.
3. **Review (main agent).** This step is mandatory. The main agent must:
   - Read the diff produced by the sub-agent.
   - Confirm the changes match the phase scope (no scope creep, no unrelated
     refactors).
   - Re-run the phase's validation command directly.
   - Look for shortcuts and risks: new TODOs, secrets or real credentials in
     diffs, vague image tags where digests/pinned tags were required, broken
     networking or volume mounts in Compose, ingress changes that contradict
     the architecture or security docs, leftover debug services or scratch
     files, weakened or skipped tests where tests exist.
   - For parallel groups, also verify the merged result still validates
     (parallel sub-agents validate in isolation; the join needs re-validation
     — at minimum re-run `docker compose config` and rebuild the docs PDF if
     `docs/` changed).
4. **Resolve.** Either accept the phase, fix small issues directly, or send
   the sub-agent back with specific feedback. Do not move on with known
   issues.

**Do not commit between phases.** Keeping the plan in one commit makes review
easier and produces a cleaner git log. Exceptions are rare and should be
explicit — for example:

- A self-contained refactor that would otherwise muddy review of a later
  substantive change.
- Reaching a known-good checkpoint before a risky or experimental phase.

When in doubt, don't commit early.

# Final Phase

The final phase of all plans should be a cleanup phase:

## Cleanup & validation

Grep the git diff for any temporary scaffolding, stray TODOs, debug logging,
commented-out blocks, scratch files, or accidentally committed secrets.
Remove them.

Specify the exact validation command(s) to run. Typically a combination of:

- `scripts/build-poc-architecture-pdf.sh` when `docs/*.md` changed.
- `docker compose config` (from the right directory) when Compose files
  changed.
- `nginx -t` when nginx config changed.
- `shellcheck scripts/*.sh` when adopted.

Fix all warnings, errors, and formatting issues called out by those checks.

## Plan cleanup

Add a summary of the completed work to `<plan-dir>/summary.md`. The summary
should have two sections:

### What was built

A short bulleted list of the concrete changes (services added, hostnames
introduced, docs updated, scripts added). One line each. This restates the
diff at a glance.

### Decisions for future reference

This section is for **future-you and future agents**. Its job is to be
retrievable later — short, scannable, and grep-friendly. Capture only
decisions that future readers might otherwise reintroduce or relitigate.
**Skip anything that is already obvious from the configs, docs, or
`00-design.md`.**

For each decision, use this shape (keep it terse — 3–8 lines per decision is
ideal, not paragraphs):

```
#### <short title — what was decided>

- **Decision:** <one line>
- **Why:** <one or two lines on the constraint or reasoning>
- **Rejected alternatives:** <X (because Y); Z (because W)>
- **Revisit when:** <what would have to change for this decision to be
  reopened — e.g. "we adopt a self-hosted OIDF registry", "we move ingress
  off nginx". Omit if the decision is permanent.>
```

Include 0–5 decisions per plan. If a plan genuinely has no decisions worth
recording (pure mechanical doc fix, trivial config tweak), write
`No notable decisions.` and move on — do not pad with restatements of the
design. Padding kills the signal.

Decisions worth recording are typically:

- A real fork in the road where another path would have worked (e.g. choosing
  between two DCC components, or between OIDF and community registry for
  trust).
- A constraint-driven choice that future-you might forget the constraint of.
- An approach that was tried and rejected mid-plan (so it doesn't get
  reintroduced).
- A deliberate non-goal or postponed feature (e.g. VerifierPlus deferred).

Decisions **not** worth recording:

- "We used a YAML anchor instead of repeating env." (obvious, low-stakes)
- Restating what `00-design.md` already says.
- Anything an agent could derive in 30 seconds from reading the configs.

Move the plan files to the `docs/plans-old/` directory (use `git mv` so
history is preserved).

## Commit

Once the plan is complete and the agreed validation commands succeed, commit
the changes with a message following
the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

<body>
```

Where:

- `<type>` is the type of commit (e.g. `feat`, `fix`, `chore`, `docs`,
  `refactor`, `perf`, `test`, etc.).
- `<scope>` is the affected area. Choose what fits this repository, for
  example: `docs`, `scripts`, `compose`, `nginx`, `ci`, `cursor`, or `chore`
  when no single area dominates.
- `<description>` is one short line in imperative mood.

`<body>` should be included only if the changes are not obvious from the
description. It should be a bulleted list of the changes made. Each item
should be a single line. Be clear, concise, and to the point. The body
**must also include the plan directory name** on its own line so the commit
and the archived plan can be correlated later. Use the form:

`Plan: docs/plans-old/<YYYY-MM-DD>-<plan-name>/`

When ready to push and open a PR, use your normal team process (review, CI if
configured, then push).
