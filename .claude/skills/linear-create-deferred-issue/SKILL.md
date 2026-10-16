---
name: linear-create-deferred-issue
description: "Capture deferred tech-debt as a Linear issue an agent can pick up cold. Use immediately after a conversation in which the user defers work — phrases like 'let's defer', 'leave for later', 'follow-up ticket', 'punt on this', 'separate PR', 'out of scope', 'tech debt', 'create a ticket', or any decision to not address something now. Drafts a human-reviewable Linear issue with an executive summary for leadership that covers the whole scope across sibling tickets, concise rationale, suggested PR breakdown with task checklists, and codebase anchors — then drops a TODO(LINEAR-XXX) into the code."
---

# Linear: Create Deferred Tech-Debt Issue

The output has two readers: a human triaging in Linear and an agent loading the ticket as its starting prompt. Optimized for Opus 4.7 — batch tool calls in parallel, only spawn an `Explore` subagent when the relevant files aren't already known.

## Prerequisites

- `mcp__claude_ai_Linear__*` tools available (otherwise tell the user to connect Linear in Settings → Connectors and stop).
- Working dir is a git repo. If not, ask the user where the TODO should go.

## Step 0: Confirm there's something concrete to capture

You need four things from the conversation. If any is missing, ask one focused question — don't fabricate:

- **What** is being deferred
- **Why it's needed** (the cost of not doing it)
- **Why it's being deferred now** (out of scope / blocked / needs design)
- **Where** in the code (at least one file path)

## Step 1: Gather context (parallel) and decide placement

Issue these in **a single batched message**:

- `mcp__claude_ai_Linear__list_teams`
- `mcp__claude_ai_Linear__list_issue_labels`
- `git remote get-url origin` and `git rev-parse --show-toplevel`
- `Read` on any file the user already named

**Never guess — always ask** for the three placement decisions:

- **Team** — auto-pick only if there's exactly one. Otherwise ask.
- **Project** — once team is chosen, call `mcp__claude_ai_Linear__list_projects` and ask which project (or none). Don't infer from topic.
- **Assignee** — default unassigned. Ask whether to assign and to whom. Don't auto-assign to the user, conversation participants, or git blame.

For labels, pick an existing fit (e.g. `tech-debt`, `follow-up`). Only create a new label after explicit confirmation, and ask which scope.

## Step 2: Find codebase anchors

Build a short list of `path:line` anchors the implementing agent should read first: the affected code, the surrounding contract/pattern, and relevant tests.

If the relevant files are already named (1–3), just `Read` them in parallel. Otherwise spawn one `Explore` subagent (thoroughness `medium`) to return `path:line` anchors with one-sentence relevance notes. Do **not** ask it to design a solution.

## Step 3: Draft the issue body

Use this structure exactly. A human should triage it in under a minute; an agent should be able to start without reading anything else first.

```markdown
**<One sentence stating what this ticket delivers and who benefits.>**

## Executive summary

* <What changes, and what happens today without it.>
* <What the work delivers, one outcome per bullet.>
* <Why it was deferred, in one plain sentence.>
* <Where this ticket fits: what it covers, which sibling tickets cover the
  rest, and the order they ship in. Omit when this is the only ticket.>

## Why this matters

<2–4 sentences. Concrete cost of not doing this: bug class left open,
perf hit, maintainability tax, future feature blocked. Lead with impact.>

## Why this was deferred

<1–3 sentences. The actual reason from the conversation — "out of scope
of PR #123", "needs design discussion with @person", "depends on Y
migration". This is what stops the next reviewer from asking why we
didn't just do it.>

## Codebase anchors

- `path/to/file.ext:LINE` — <one-sentence note: what's here, why it matters>
- `path/to/contract.ext` — <interface/pattern to conform to>

## Constraints and context the agent needs

<Bullets of non-obvious things the agent must know: invariants to
preserve, patterns to match, edge cases the user flagged, decisions
already made. If nothing is non-obvious, write "None — straightforward
change matching patterns at <anchor>." Do not pad.>

## Suggested PR breakdown

### PR 1: <what this PR accomplishes>

- [ ] <deliverable — the *what*, not the *how*>
- [ ] <deliverable>
- [ ] <tests covering the new behavior>

### PR 2: <what this PR accomplishes> (depends on PR 1)

- [ ] <deliverable>

## Out of scope

<Bullets of related things this ticket does *not* cover. Skip the
section if there's nothing worth calling out.>
```

### Executive summary

The summary is for leadership, managers and other humans who will not read past it. Someone reading only the opening sentence and the summary should know what is changing, why it is deferred, and how this ticket relates to the rest of the work.

- Four to seven bullets. One idea per bullet, one or two short sentences each.
- The first bullet states the change and what is wrong today.
- Describe behavior and impact, not code. Use a code identifier only when a non-engineer on the team would recognize it.
- No anchors, no PR breakdown, no implementation.
- Do not repeat the opening sentence or the "Why this matters" section word for word.

### When the work spans several tickets

If the deferred work splits into more than one ticket, write the whole story first and then cut it into tickets.

- Each ticket's executive summary describes the whole scope of work as well as its own part. A reader who opens any one ticket should learn the full plan.
- The last bullet names this ticket's part, names each sibling ticket and its part, and gives the release order or dependency.
- Show all drafts together in Step 4 so the user can check that the summaries agree.

**Hard rules:**

- No code, pseudocode, or implementation plan. Anchors + constraints only.
- Title reads as a deliverable, not a complaint. "Extract retry logic into shared policy" beats "Retry logic is duplicated". Under ~80 chars.
- Every anchor must be a real file/line you actually read in Step 2.
- PR breakdown reflects **review boundaries**, not implementation order. Group by what a reviewer can evaluate as a coherent unit. Single PR is fine if the work is small — say so.
- If the work is small enough for one PR, use one section.

## Step 4: Show the draft, get confirmation

```
────────────── ISSUE DRAFT ──────────────
Team:     <team>
Project:  <project, or "(none)">
Title:    <title>
Labels:   <labels>
Assignee: <name, or "unassigned">

<full markdown body>
─────────────────────────────────────────

TODO(LINEAR-XXX) will be added at:
  - <file:line>

Confirm to create, or tell me what to change.
```

If team / project / assignee weren't decided in Step 1, ask now. Revise and re-show on requested changes. **Do not call `save_issue` until the user confirms.**

## Step 5: Create the issue

Call `mcp__claude_ai_Linear__save_issue` with `team`, `title`, `description` (real newlines, not `\n`), and `labels`. Include `project` only if chosen. Include `assignee` only if the user explicitly named one. Capture the returned identifier (e.g. `ENG-1234`). On error, surface it and stop — don't write TODOs against a non-existent issue.

When several tickets were created, sibling IDs do not exist until every ticket is saved. After the last `save_issue`, update each ticket's executive summary so the final bullet links its siblings by identifier. Call `save_issue` with the ticket's `id` and the revised `description`.

## Step 6: Drop the TODO

Add `TODO(<ISSUE-ID>): <≤80-char description>` using the file's native comment syntax, on its own line directly above the relevant statement, matching surrounding indentation.

- Place at the single best anchor. If two locations are equally relevant, leave one at each — but don't sprinkle.
- Skip if the file already has a TODO referencing the same issue.

## Step 7: Final report

One short paragraph: issue ID + URL, files where TODOs landed, and anything the user should do (e.g. "left unassigned — set in Linear if you want it owned"). Don't offer to start the work — that's the point of deferring.
