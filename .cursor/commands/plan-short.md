# Plan-small process (lightweight implementation planning)

For small, well-scoped work (1–3 phases, hours-to-a-day in size). For larger
multi-day efforts use the full `plan` command instead.

## Execution model

Same model as the full `plan` command, just lighter ceremony:

- Phases are typically dispatched to **Composer 2 sub-agents**; the main
  agent plans, dispatches, and reviews.
- Each phase must be **self-contained** — a sub-agent reads only the phase
  subsection (plus any files it explicitly references) and must have what it
  needs.
- **Parallelism is usually not worth it at this size.** Most small plans
  have 1–3 sequential phases. Only parallelize if phases touch genuinely
  disjoint files and there's real wall-clock to save.
- **Mandatory review after each phase**: read the diff, re-run validation,
  watch for shortcuts (secrets committed, weakened checks, doc drift, scope creep).
- **One commit at the end.** Sub-agents must be told not to commit.

Question iteration and design stay with the main agent — no sub-agent
delegation for those.

## Setup

Decide on a name for the plan. This should be a short, descriptive name.
Referred to as `<plan-name>` below.

Create a single plan file at `docs/plans/<YYYY-MM-DD>-<plan-name>.md`.

Use `date +%Y-%m-%d` to get the current date.

**Note**: This repository holds **deployment orchestration and documentation**;
application logic ships in **published Docker images** consumed by compose (or
similar), not as a monolithic app tree here. Most work runs from the **repository
root**. If the plan names a subdirectory (e.g. future `compose/`, `nginx/`, or
env templates), run commands from that path when validating that slice. If
unsure, check the plan or ask.

## Analysis

Populate the plan file with a `# Notes` section containing:

- The scope of work
- The current state of the codebase as it pertains to the scope of work
- Questions that need to be answered to complete the plan. Each question should
  include context and a suggested answer.

## Question Iteration

Ask the user each question, ONE AT A TIME:

Include in the question:

- the question
- the current state of the codebase as it pertains to the question
- your suggested course forward

The user will answer the question or ask follow up questions.

We must ensure that we have clear acceptance criteria. Include a final phase
for verifying the acceptance criteria and debugging.

Once the question is answered or otherwise resolved:

- Record the answers in the `# Notes` section.
- If the user's answers imply additional questions, add them.
- If the user's answers include other notes, add them.
- If the user's answers affect other questions or the scope of work, update
  accordingly before moving on.
- Move on to the next question.

## Design Iteration

Once questions are answered, present a suggested architecture design with two
main elements:

The file structure as a bare-bones ascii file tree of the relevant directories
and files.
Do NOT create a file to show the file tree, print it to the user in a code
block, like this:

```
compose/
└── services.yml              # UPDATE: add signing service dependency
docs/
└── architecture.md           # UPDATE: routing diagram for new hostname
```

A summary of the conceptual architecture. This could be ASCII art, a diagram,
or a component list. It should summarize the main services, images, and how they
interact in an easy to understand way.

If I want to make changes, I will tell you and you will show me relevant updates
to the file tree and architecture summary.

## Design Completion

Once the design is agreed, replace the `# Notes` section content with a
`# Design` section at the top of the plan file containing:

- Scope of work
- File structure (as shown above)
- Conceptual architecture summary
- Main components and how they interact

## Documentation and conventions review

Before drafting phases, skim the docs that apply to this plan’s work:

- [docs/architecture.md](../../docs/architecture.md) — service boundaries, Compose
  topology, hostnames, integration with ORCA and DCC images
- [docs/standards.md](../../docs/standards.md) — interoperability profile and
  normative references for credential flows
- [docs/security.md](../../docs/security.md) — security posture and controls for
  the PoC

Call out in each phase subsection which of these (plus any orchestration
conventions in-repo, e.g. image tags, secrets handling) the sub-agent must
respect.

## Phases

Below the design, add a `# Phases` section. Break the work into phases,
each as a subsection (`## Phase N: Title`).

Present phase suggestions to me first. Tag each phase with `[sub-agent: yes |
supervised | main]`; default is `yes`. For small plans, parallel groups are
rare — only call out parallelism when it's genuinely useful.

```
1. Document new service in architecture.md     [sub-agent: yes]
2. Add Compose service + nginx route             [sub-agent: yes]
3. Cleanup, review, and validation             [sub-agent: supervised]
```

I will then make suggestions to change the phases, or add more phases.

Once I tell you that we're ready to start, write the phase details into the
plan file.

Every phase subsection must be **self-contained** — a sub-agent reads only
this subsection plus any files it explicitly references, with no memory of
the design discussion.

Every phase subsection should include:

### Scope of phase

Short summary of the scope. Be explicit about what is **out of scope** —
sub-agents are prone to scope creep.

### Repository organization reminders

- Prefer a clear layout: one concern per file (e.g. one compose overlay, one
  env example per environment class).
- Keep **docs** aligned with what deploy scripts and Compose actually do.
- Any temporary scaffolding should have a TODO or be removed before the final phase.

### Relevant documentation and conventions

List the docs and conventions that apply to this phase, with one-line notes.
Only include what is actually relevant.

Example:

```markdown
- **Architecture** (`docs/architecture.md`) — New hostname and traffic path must
  match the deployment diagram and PoC hostnames section.
- **Security** (`docs/security.md`) — Ingress and exposure changes should not
  contradict the documented controls.
```

### Sub-agent reminders

- Do **not** commit. The plan commits at the end as a single unit.
- Do **not** expand scope. Stay strictly within "Scope of phase".
- Do **not** commit secrets, production credentials, or short-lived tokens.
- Do **not** disable, skip, or weaken validation (tests, `docker compose config`,
  doc builds) to greenwash a phase—fix or escalate.
- If something blocks completion, stop and report rather than improvising.
- Report back: what changed, what was validated, any deviations.

### Implementation Details

Be specific and detailed. Reference existing files by path so a fresh sub-agent
can find them. Include **acceptance checks** for the phase (e.g. compose renders,
doc PDF builds, nginx syntax)—not only unit tests, which may not exist in this
repo.

### Validate

Specify exactly which commands to run for this phase. Examples tied to this
repository:

- After **Markdown** changes under `docs/`:  
  `scripts/build-poc-architecture-pdf.sh` (requires pandoc and a PDF engine).
- When **Compose** files exist:  
  `docker compose config` (or the project’s equivalent) from the directory that
  contains the compose file.
- For **shell** changes: optional `shellcheck` on edited scripts if available.

If only plan notes under `docs/plans/` changed, validation may be “none beyond
review”—say so explicitly.

Keep docs, configs, and automation consistent as you go. Clean up warnings that
will not be fixed in later phases (e.g. shellcheck where agreed).

## Phase Execution & Review

For each phase:

1. **Dispatch** to a sub-agent with the phase subsection as its prompt
   (unless tagged `main`).
2. **Wait** for completion and collect the report.
3. **Review (main agent, mandatory)**: read the diff, confirm scope match,
   re-run the validation command, scan for shortcuts (credentials in repo,
   vague image tags where digests are required, broken networking or volume
   mounts, docs contradicting Compose, leftover debug or scratch files).
4. **Resolve**: accept, fix small issues directly, or send the sub-agent
   back with specific feedback. Do not move on with known issues.

**Do not commit between phases.** One commit at the end. Rare exceptions
(self-contained refactor that would muddy review of a later substantive
change; checkpoint before a risky phase) should be explicit. When in doubt,
don't.

## Final Phase

The final phase of all plans should be a cleanup phase:

### Cleanup & validation

Grep the git diff for temporary scaffolding, stray TODOs, debug logging,
commented-out blocks, and scratch files. Remove them.

Specify the exact validation command(s) to run. Typically:

- `scripts/build-poc-architecture-pdf.sh` when `docs/*.md` changed, and/or
- `docker compose config` when Compose files changed (from the correct directory).

Fix all warnings, errors, and formatting issues called out by those checks.

### Plan cleanup

Move the remaining notes to the bottom of the plan file under `# Notes`.

Append a `# Decisions for future reference` section to the plan file. This
section is for future-you and future agents — short, scannable, grep-friendly.
Capture only decisions future readers might otherwise reintroduce or
relitigate. **Skip anything obvious from the code or from `# Design`.**

For each decision use this shape (3–8 lines, not paragraphs):

```
## <short title — what was decided>

- **Decision:** <one line>
- **Why:** <one or two lines on the constraint or reasoning>
- **Rejected alternatives:** <X (because Y); Z (because W)>
- **Revisit when:** <what would have to change for this to be reopened.
  Omit if permanent.>
```

Small plans frequently have **0 notable decisions** — that is the expected
case for mechanical refactors and doc fixes. Write `No notable decisions.`
and move on. Do not pad with restatements of the design; padding kills the
signal across all the plans.

Decisions worth recording (when they exist): a real fork in the road; a
constraint-driven choice whose constraint future-you might forget; an
approach tried and rejected mid-plan; a deliberate non-goal.

Move the plan file to `docs/plans-old/` (use `git mv` to preserve history).

### Commit

Once the plan is complete and validation for the touched areas succeeds, commit
the changes with a message following
the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

<body>
```

Where:

- `<type>` is the type of commit (e.g., `feat`, `fix`, `chore`, `docs`,
  `refactor`, `perf`, `test`, etc.).
- `<scope>` is the affected area. Choose what fits this repository, for example:
  `docs`, `scripts`, `compose`, `nginx`, `ci`, `cursor`, or `chore` when no
  single area dominates.
- `<description>` is one short line in imperative mood.

`<body>` should be included only if the changes are not obvious from the
description. It should be a bulleted list of the changes made. Each item
should be a single line. Be clear, concise, and to the point. The body
**must also include the plan file path** on its own line so the commit and
the archived plan can be correlated later. Use the form:

`Plan: docs/plans-old/<YYYY-MM-DD>-<plan-name>.md`

When ready to push and open a PR, use your normal team process (review, CI if
configured, then push).
