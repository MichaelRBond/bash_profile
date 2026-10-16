---
name: linear-create-user-story
description: "Create a Linear user story an agent can pick up cold. Use when the user wants to capture a new feature, product need, or piece of work as a proper user story — phrases like 'create a user story', 'make a story for', 'new Linear issue for this feature', 'write a story', 'log this feature', 'ticket for this capability'. Frames the issue as 'As a X, I want to do Y', follows it with an executive summary for leadership that covers the whole scope across sibling tickets, adds a concise why-this-matters and enough context for a fresh agent to start — without prescribing the solution. Distinct from linear-create-deferred-issue, which captures deferred tech-debt with a PR breakdown."
---

# Linear: Create User Story

Turns a request into a Linear user story. The output has two readers: a human triaging in Linear and an agent loading the ticket as its starting prompt. Give the agent enough to orient and start — **not** a solution. Let it do its own thinking. Optimized for Opus — batch tool calls in parallel; only spawn an `Explore` subagent when relevant files aren't already known.

**This is not the deferred-tech-debt skill.** If the user is deferring work they'd otherwise do now (out of scope, punt, follow-up PR, tech debt), use `linear-create-deferred-issue` instead — it produces a PR breakdown. This skill produces a user story for net-new work.

## Prerequisites

- `mcp__claude_ai_Linear__*` tools available (otherwise tell the user to connect Linear in Settings → Connectors and stop).

## Step 0: Nail down the story — "As a X, I want to do Y"

Every story opens with `As a <X>, I want to <Y>`.

- **X is the type of user** the work serves — `user`, `consumer`, `customer`, `engineer`, `product owner`, `admin`, `operator`, etc. It is a *role*, not a named person.
  - **If you cannot determine X from the conversation, ask. Never guess.** A wrong role reframes the whole story.

    > Who is this for — which type of user? (e.g. end user, customer, engineer, product owner…)

- **Y is the outcome** the user wants to accomplish, phrased as a capability, not an implementation. "filter reports by date range", not "add a `<select>` with an onChange handler".

If Y is vague, ask one focused question to sharpen it before drafting. Optionally close the line with `so that <benefit>` when the benefit isn't already obvious from Y.

## Step 1: Gather context (parallel) and decide placement

Issue these in **a single batched message**:

- `mcp__claude_ai_Linear__list_teams`
- `mcp__claude_ai_Linear__list_issue_labels`
- `Read` on any file or doc the user already named

**Never guess — ask for these placement decisions:**

- **Team** — auto-pick only if there's exactly one. Otherwise ask.
- **Project** — if it isn't obvious which project this belongs in, **ask, don't assume**. Once the team is chosen, call `mcp__claude_ai_Linear__list_projects` and ask which project (or none). Don't infer from topic alone.
- **Assignee** — **always ask** whether it should have an assignee and, if so, whom. Default to unassigned. Don't auto-assign to the user, conversation participants, or git blame.

For labels, pick an existing fit (e.g. `feature`, `enhancement`). Only create a new label after explicit confirmation, and ask which scope.

## Step 2: Gather just enough context for a fresh agent

The goal is orientation, not a plan. A fresh agent should understand *what* to build and *where the relevant terrain is* — then design the solution itself.

- If the work touches known code, collect a short list of `path:line` anchors (the relevant area, the contract/pattern to conform to, related tests). Read named files in parallel, or spawn one `Explore` subagent (thoroughness `medium`) for anchors with one-sentence relevance notes. Do **not** ask it to design a solution.
- If the story is product-level with no obvious code yet, that's fine — capture the constraints and prior decisions instead. Anchors are optional.

## Step 3: Draft the issue body

Use this structure. A human should grasp it in under a minute; an agent should be able to start without reading anything else first.

```markdown
**As a <X>, I want to <Y>** [so that <benefit>].

## Executive summary

* <What changes for the user, and what happens today without it.>
* <What the work delivers, one outcome per bullet.>
* <A decision or limit a manager needs to know, in plain language.>
* <Where this ticket fits: what it covers, which sibling tickets cover the
  rest, and the order they ship in. Omit when this is the only ticket.>

## Why this matters

<2–4 sentences, plain language, human-readable. The value to the user or
the business — what becomes possible, what pain goes away. Concise. Do not
pad, do not restate the story line.>

## Context

<Enough for a fresh agent to orient: the relevant area of the product/
codebase, constraints and invariants to respect, decisions already made,
and anything non-obvious the user flagged. Include `path:line` anchors here
when they exist. This is background, NOT a solution — do not prescribe an
approach, sequence steps, or dictate the design. Let the agent think.>

## Acceptance criteria

- [ ] <observable outcome — the *what*, phrased so anyone can verify it>
- [ ] <another outcome, including edge cases the user cares about>
```

### Executive summary

The summary is for leadership, managers and other humans who will not read past it. Someone reading only the story line and the summary should know what is changing, why, and how this ticket relates to the rest of the work.

- Four to seven bullets. One idea per bullet, one or two short sentences each.
- The first bullet states the change in user terms and what is wrong today.
- Describe behavior, not code. Use a code identifier only when a non-engineer on the team would recognize it, such as a route or feature name.
- No acceptance-criteria detail, no anchors, no implementation.
- Do not repeat the story line or the "Why this matters" section word for word.

### When the work spans several tickets

If the scope splits into more than one ticket (for example, backend and frontend), write the whole story first and then cut it into tickets.

- Each ticket's executive summary describes the whole scope of work as well as its own part. A reader who opens any one ticket should learn the full plan.
- The last bullet names this ticket's part, names each sibling ticket and its part, and gives the release order or dependency, such as "This ticket is backend only and ships first. The frontend ticket <ID> builds on it."
- Show all drafts together in Step 4 so the user can check that the summaries agree.

**Hard rules:**

- The first line is the story: `As a <X>, I want to <Y>`. X is a concrete user role you determined or asked for — never a guess.
- **Not prescriptive.** No implementation steps, no dictated design, no pseudocode, no PR breakdown. Describe outcomes and context; leave the *how* to the implementing agent. If you catch yourself writing "first do X, then Y", move it to acceptance criteria as an outcome or cut it.
- **Why-this-matters is a few sentences, tops.** If it runs past ~4 sentences, trim it.
- Acceptance criteria are observable outcomes, not tasks. "Reports can be filtered to a custom date range" — not "add a date picker component".
- Title reads as the capability, under ~80 chars. "Filter reports by custom date range" beats "Date filtering".
- Every anchor must be a real file/line you actually read in Step 2.

## Step 4: Show the draft, get confirmation

```
────────────── STORY DRAFT ──────────────
Team:     <team>
Project:  <project, or "(none)">
State:    Backlog
Title:    <title>
Labels:   <labels>
Assignee: <name, or "unassigned">

<full markdown body>
──────────────────────────────────────────

Confirm to create, or tell me what to change.
```

If team / project / assignee weren't settled in Step 1, ask now. Revise and re-show on requested changes. **Do not call `save_issue` until the user confirms.**

## Step 5: Create the issue

Call `mcp__claude_ai_Linear__save_issue` with:

- `team`, `title`, and `description` (real newlines — never literal `\n`).
- `state: "backlog"` — **unless the user asked for a different state.** Backlog is the default for a new story.
- `project` only if one was chosen.
- `assignee` only if the user explicitly named one.
- `labels` if any were chosen.

Capture the returned identifier (e.g. `ENG-1234`). On error, surface it and stop.

When several tickets were created, sibling IDs do not exist until every ticket is saved. After the last `save_issue`, update each ticket's executive summary so the final bullet links its siblings by identifier. Call `save_issue` with the ticket's `id` and the revised `description`.

## Step 6: Final report

One short paragraph: issue ID + URL, its state (Backlog unless changed), and anything the user should follow up on (e.g. "left unassigned — set an owner in Linear when it's picked up"). Don't offer to start implementing — the story is the deliverable.
