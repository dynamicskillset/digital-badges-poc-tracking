# Plan process (implementation planning)

## Setup

Decide on a name for the plan. This should be a short, descriptive name that
captures the purpose of the plan. This will be refered to as `<plan-name>` in this
document.

Create a new plan directory at `docs/plans/<YYYY-MM-dd>-<plan-name>/`.

Use `date +%Y-%m-%d` to get the current date.

This directory will contain the plan files for the plan.

## Analysis

Analyze the current scope of work, and populate a `00-notes.md` file with the
following sections:

- The scope of work
- The current state of the codebase as it pertains to the scope of work
- Questions that need to be answered to complete the plan. Each question should
  include context and a suggested answer.

## Question Iteration

Go through the questions one at a time, asking me for clarification and answers.

- a summary of the current state
- your suggested course forward

I will answer or ask more questions.
You will record the answers in the `00-notes.md` file.
If my answers imply additional questions, add them to the file.
If my answers include other notes, add them to the file in a `# Notes` section.
If my answers affect other questions or the scope of work, update the file
accordingly before moving on.

Move on to the next question.

## Design Iteration

Once questions are answered, you will present me with a suggestion of an
architecture design with two main elements:

The file structure as a bare-bones ascii file tree of the relevant directories
and files.
Do NOT create a file to show the file tree, print it to the user in a code
block, like this:

```
module/
└── src/
    ├── file.ts                 # NEW: File with things in it
    └── updater.ts              # UPDATE: File with the updater function
```

A summary of the conceptual architecture. This could be ASCII art, a diagram,
or a class hierarchy. It should summarize the main components and how they
interact in an easy
to understand way.

If I want to make changes, I will tell you and you will show me relevant updates
to the file tree
and architecture summary.

## Design Completion

Once the design is agreed, you will create a new file called `00-design.md` with
the design overview.

The design file should include:

- Scope of work
- File structure (as shown above)
- Conceptual architecture summary
- Main components and how they interact

# Plan phases

Consider how best to break down the work into phases.

Present phase suggestions to me, like this example:

```
1. Extend ElfLoadInfo
2. Create Object Submodule Structure
3. Implement Object Layout Calculation
4. Implement Object Section Loading
5. Implement Object Symbol Map Building
6. Implement Symbol Map Merging
7. Cleanup, review, and validation
```

I will then make suggestions to change the phases, or add more phases.

Once I tell you that we're ready to start, save the phases to the plan
directory.

# Phase Files

The names of the phase files should be like: `01-phase-title.md`,
`02-phase-title.md`, etc.

Every phase file should include:

## Scope of phase

A short summary of the scope of work for the phase.

## Code Organization Reminders

Every phase should include some code quality reminders.

- Prefer a granular file structure, one concept per file.
- Place more abstract things, entry points, and tests **first**
- Place helper utility functions **at the bottom** of files.
- Keep related functionality grouped together
- Any temporary code should have a TODO comment so we can find it later.

## Implementation Details

Be specific and detailed. Write out code examples where appropriate.
Include tests to write to verify the work in the phase.

## Validate

Specify exactly which commands should be run to validate the phase. Generally,
this will
be `turbo check test` or similar.

We want to keep the code compiling and passing tests as we go.

Clean up any warnings that won't be fixed in later phases (like unused
functions)

DO NOT COMMIT between phases unless specifically requested. Keeping plans in one
commit makes
it easier to review changes and produces a better git log.

# Final Phase

The final phase of all plans should be a cleanup phase:

## Cleanup & validation

Grep the git diff for any temporary code, TODOs, debug prints, etc. Remove them.

Specify the exact validation command to run `turbo check test` or similar.

Fix all warnings, errors, and formatting issues.

## Plan cleanup

Add a summary of the completed work to `<plan-dir>/summary.md`.

Move the plan files to the `docs/plans-done/` directory.

## Commit

Once the plan is complete, and everything compiles and passes tests, it's time
to commit the changes.
commit the changes with a message following
the [Conventional Commits](https://www.conventionalcommits.org/) format

```
<type>(<scope>): <description>

<body>
```

Where:

- <type> is the type of commit (e.g. feat, fix, chore, docs, etc.)
- <scope> is the scope of the commit (e.g. ui, backend, docs, etc.)
- <description> is a short description of the commit

<body> should be included only if the changes are not obvious from the description.

It should be a bulleted list of the changes made. Each item should be a single
line.
Be clear, concise, and to the point.
