---
name: obsidian-planner
description: >
  Store planning documents, specs, architecture docs, meeting notes, task
  breakdowns, and other markdown artifacts in Obsidian via the Obsidian CLI --
  so they sync across devices automatically. Use this skill whenever you would
  create a planning document, design doc, spec, specification, design spec,
  test spec, refactor spec, roadmap, ADR, sprint plan, meeting note, or any
  project-related markdown artifact. Also use when the user says "plan",
  "write a spec", "spec this out", "specification", "document this",
  "write up", "note this", "track this", "decision record", "save to
  obsidian", "sync to obsidian", or asks you to create any markdown file that
  is not source code. This includes ANY file that would otherwise go in a
  docs/, specs/, or design/ folder in the repo -- those files belong in
  Obsidian, not in the repo. Do NOT use this skill for README.md or other
  files that belong in the repo itself.
---

# Obsidian Planner

Store project planning artifacts in Obsidian via the CLI so they sync to all
devices through Obsidian Sync. This skill is used from **project repos** --
you do NOT need to be inside the vault directory.

**CRITICAL: Never create docs/, specs/, design/, or planning/ directories in
the project repo.** All planning artifacts, specs, design docs, and similar
markdown documents go to Obsidian via the CLI. The only markdown files that
belong in the repo are README.md and code-level documentation like inline
comments or API docs generated from code.

## Prerequisites

- Obsidian desktop must be running (the CLI communicates with the running app)
- Obsidian CLI installed and on PATH (`obsidian help` to verify)
- Obsidian Sync configured (handles cross-device availability)

If `obsidian help` fails, tell the user:
> The Obsidian CLI isn't available. Make sure Obsidian is running and the CLI
> is installed. See https://help.obsidian.md/cli for setup instructions.

## Determining the vault and folder

All planning documents live under the `AI-Planning/` root folder in the
vault. This is hardcoded and must not be changed. Within `AI-Planning/`,
the user specifies a **subfolder** for the current project or area of work.

At the start of a session (or when first asked to create a planning
artifact), you need two things:

1. **Which vault?** -- If they have multiple vaults, they need to specify.
   Use `vault=<n>` as the first parameter on every command. If they only
   have one vault, skip this.
2. **What subfolder?** -- e.g. `kitchen-tracker`, `client-x`, `home-reno`.
   This becomes the folder under `AI-Planning/`.

The full path for any document is always:

```
AI-Planning/<subfolder>/<Document Name>.md
```

Once established, remember both values for the rest of the session. Example:

```
Vault:      Work
Subfolder:  kitchen-tracker
Full path:  AI-Planning/kitchen-tracker/
```

A note created with name "Architecture" would land at:
`AI-Planning/kitchen-tracker/Architecture.md`

If the user provides these in a `CLAUDE.md` or project config, use those
values without asking.

### CLAUDE.md convention

Users can put this in their project's `CLAUDE.md` to skip the question:

```markdown
## Obsidian
- vault: Work
- folder: kitchen-tracker
```

The skill will automatically prepend `AI-Planning/` -- the user only
specifies the subfolder name.

## CLI command reference

All commands use the format `obsidian <command> [params...]`.
Parameters use `=` syntax. Quote values containing spaces.
Use `\n` for newlines in content strings.

### Core commands you will use

| Action | Command |
|---|---|
| Create a note | `obsidian create name="Note Title" content="..." path="AI-Planning/folder/note.md" silent` |
| Read a note | `obsidian read path="AI-Planning/folder/note.md"` |
| Append to a note | `obsidian append path="AI-Planning/folder/note.md" content="..."` |
| Search the vault | `obsidian search query="term" limit=10` |
| Set a property | `obsidian property:set name="key" value="val" path="AI-Planning/folder/note.md"` |
| Append to daily note | `obsidian daily:append content="..."` |
| List tasks | `obsidian tasks` |
| Check backlinks | `obsidian backlinks path="AI-Planning/folder/note.md"` |

**Key flags:**
- `silent` -- prevents the note from opening in the Obsidian GUI
- `vault=<n>` -- targets a specific vault (always first parameter)
- `--copy` -- copies output to clipboard

### Targeting a specific vault

Always pass `vault=<n>` as the **first** parameter when the user has
specified a vault:

```bash
obsidian vault="Work" create name="Sprint Plan" path="AI-Planning/kitchen-tracker/Sprint-Plan.md" content="..." silent
```

### Creating notes with long content

For documents longer than a few lines, write the content to a temp file
and use shell redirection or build the content string with `\n` newlines.

**Preferred approach for long documents:**

```bash
# Build content in a shell variable, then pass it
CONTENT=$(cat <<'ENDOFCONTENT'
---
tags:
  - project/my-app
  - type/plan
status: draft
created: 2026-03-30
---

# Project Plan

## Overview
...
ENDOFCONTENT
)

obsidian vault="Work" create name="Project Plan" path="AI-Planning/my-app/Project-Plan.md" content="$CONTENT" silent
```

**Alternative: create then append in sections** for very long documents:

```bash
obsidian vault="Work" create name="Design Doc" path="AI-Planning/my-app/Design-Doc.md" content="---\ntags:\n  - type/design\nstatus: draft\n---\n\n# Design Doc\n\n## Overview" silent

obsidian vault="Work" append path="AI-Planning/my-app/Design-Doc.md" content="\n\n## Architecture\n\n..."
```

### Reading notes for context

Before updating a document, always read it first:

```bash
obsidian vault="Work" read path="AI-Planning/my-app/Sprint-Plan.md"
```

This lets you see what the user may have edited on mobile.

## Obsidian-flavored Markdown conventions

All documents MUST use Obsidian-flavored Markdown:

### Frontmatter (required on every note)

```yaml
---
tags:
  - project/<project-name>
  - type/<document-type>
status: draft | active | complete | archived
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Valid `type/` tags: `plan`, `design`, `spec`, `adr`, `sprint`, `meeting`,
`tasks`, `roadmap`, `retrospective`, `notes`

### Wikilinks (not regular markdown links)

```markdown
See [[Project Plan]] for context.
Related: [[Architecture]], [[Sprint 3 Tasks]]
```

Use wikilinks to connect related planning documents. This builds the
knowledge graph in Obsidian.

### Callouts

```markdown
> [!info] Context
> This decision was driven by the constraint that...

> [!warning] Risk
> If the API changes, this approach will break.

> [!todo] Action Item
> Assign someone to benchmark the alternatives.

> [!question] Open Question
> Should we support both v1 and v2 simultaneously?

> [!success] Decision
> We will proceed with Option B.
```

### Tasks

```markdown
- [ ] Implement auth middleware
- [ ] Write integration tests
- [x] Set up CI pipeline
- [ ] Review PR #42 📅 2026-04-05
```

Tasks with dates use the `📅 YYYY-MM-DD` convention for due dates, which
is compatible with the Obsidian Tasks plugin.

### Embeds

To embed another note's content inline:

```markdown
![[Sprint 3 Tasks]]
```

## Document templates

When creating each document type, follow these structures.

### Project Plan

```markdown
---
tags:
  - project/<n>
  - type/plan
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Project Name> -- Plan

## Objective
What we're building and why.

## Scope
What's in and out of scope.

## Milestones
- [ ] Milestone 1 -- <description> 📅 YYYY-MM-DD
- [ ] Milestone 2 -- <description> 📅 YYYY-MM-DD

## Key Decisions
- [[ADR-001 -- Decision Title]]

## Risks & Open Questions
> [!question] <Question>
> <Context>

## Resources
- Repo: `<repo-url>`
- [[Related Note]]
```

### Spec / Specification

```markdown
---
tags:
  - project/<n>
  - type/spec
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Component/Feature Name> -- Spec

## Summary
Brief description of what this spec covers and why it exists.

## Current State
How things work today. What's wrong or needs to change.

## Proposed Changes

### <Change Area 1>
What will change and how.

### <Change Area 2>
What will change and how.

## Affected Components
- `path/to/file.ts` -- description of changes
- `path/to/other.ts` -- description of changes

## Testing Strategy
How the changes will be verified.

- [ ] Unit tests for <area>
- [ ] Integration tests for <area>
- [ ] Manual verification of <area>

## Rollout / Migration
Any migration steps, feature flags, or phased rollout notes.

## Open Questions
> [!question] <Question>
> <Context>
```

### Architecture / Design Doc

```markdown
---
tags:
  - project/<n>
  - type/design
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Title> -- Design Doc

## Context & Problem
What problem does this solve? What constraints exist?

## Decision
What approach are we taking?

## Alternatives Considered

### Option A -- <n>
**Pros:** ...
**Cons:** ...

### Option B -- <n>
**Pros:** ...
**Cons:** ...

## Architecture

> [!info] Diagram
> Describe the system architecture. Use Mermaid fenced blocks if helpful.

## Implementation Plan
- [ ] Step 1
- [ ] Step 2

## Consequences
What trade-offs does this decision create?
```

### Meeting Notes

```markdown
---
tags:
  - project/<n>
  - type/meeting
status: complete
created: YYYY-MM-DD
attendees:
  - <n>
---

# Meeting -- <Topic> -- YYYY-MM-DD

## Agenda
1. Item one
2. Item two

## Notes
Key discussion points.

## Decisions
> [!success] Decision
> We agreed to...

## Action Items
- [ ] @<person> -- <task> 📅 YYYY-MM-DD
```

### Sprint / Task Breakdown

```markdown
---
tags:
  - project/<n>
  - type/sprint
status: active
created: YYYY-MM-DD
sprint: <number>
---

# Sprint <N> -- <Theme>

## Goal
What we aim to deliver this sprint.

## Tasks

### Must Have
- [ ] <Task> -- [[Design Doc]] context
- [ ] <Task>

### Should Have
- [ ] <Task>

### Nice to Have
- [ ] <Task>

## Carry-over from [[Sprint <N-1>]]
- [ ] <Incomplete task>

## Retrospective
> [!todo] Fill in at sprint end
```

### ADR (Architecture Decision Record)

```markdown
---
tags:
  - project/<n>
  - type/adr
status: accepted | proposed | superseded
created: YYYY-MM-DD
updated: YYYY-MM-DD
adr: <number>
---

# ADR-<NNN> -- <Decision Title>

## Status
Proposed / Accepted / Superseded by [[ADR-<NNN>]]

## Context
What is the issue that we're seeing that motivates this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or harder because of this change?
```

## Workflow patterns

### Starting a new project

When the user begins work on a new project and asks you to plan:

1. Confirm vault and subfolder (or read from CLAUDE.md)
2. Create a Project Plan note as the hub document at
   `AI-Planning/<subfolder>/Project-Plan.md`
3. Create supporting documents (design docs, specs, task breakdowns) as needed
4. Wikilink everything together

### Updating from the repo

When you've made progress on code and want to update the plan:

1. `obsidian read` the relevant planning doc
2. Check off completed tasks
3. Add notes about what changed
4. Update the `updated` frontmatter date
5. Use `obsidian append` or recreate with updated content

### Checking what the user changed on mobile

Before modifying any document, always read it first -- the user may have
edited it on their phone or another device via Obsidian Sync.

### Cross-referencing with daily notes

When logging progress or decisions, also append a summary to the daily note:

```bash
obsidian vault="Work" daily:append content="\n\n## <Project Name>\n- Completed auth middleware\n- Decision: using JWT over sessions ([[ADR-001]])"
```

## Important rules

1. **Always use `silent`** on create/append to avoid disrupting the user's
   Obsidian window while they work.
2. **Always read before writing** to avoid clobbering mobile edits.
3. **Always include frontmatter** with tags, status, and dates.
4. **Use wikilinks** to connect related documents, never regular markdown links
   for internal vault references.
5. **Never store source code** in Obsidian -- only planning artifacts.
6. **All paths start with `AI-Planning/`** -- never write outside this folder.
7. **Ask for vault/subfolder once**, then remember for the session.
8. **Run `obsidian help`** if you're unsure about a command -- it's always
   up to date.
9. **NEVER create docs/, specs/, design/, or planning/ directories in the
   project repo.** All specs, design docs, plans, and similar artifacts
   must be saved to Obsidian via the CLI. If you find yourself about to
   `mkdir` a docs or specs folder in the repo, stop -- use the Obsidian
   CLI instead.
10. **All markdown artifacts that are not source-code documentation (like
    README.md or API docs) go to Obsidian.** This includes specs, design
    docs, test plans, refactor plans, meeting notes, and any other
    planning or specification document.
