---
name: spec-writer
description: "Create spec and implementation plan documents optimized for both human reviewers and AI coding agents. Use this skill whenever someone asks to write a spec, PRD, implementation plan, technical design document, project plan, or any planning document that will guide development work — especially work done by Claude Code or other AI coding agents. Also use when someone wants to restructure, reorganize, or improve an existing spec or planning document. Trigger on phrases like 'write a spec', 'create a plan', 'implementation document', 'break this into tasks', 'project planning', 'technical design', or when someone mentions their spec is too long, hard to review, or not working well with AI agents."
---

# Spec Writer

Create spec and implementation documents that serve two audiences equally: human reviewers who need to understand and approve the plan, and AI coding agents who need to implement it.

## Why this skill exists

Large specs (thousands of lines, many files) create two problems:
1. **Human reviewers** can't quickly grasp scope, intent, and progress
2. **AI coding agents** waste context budget parsing irrelevant sections, or miss critical details buried in prose

This skill produces specs with a clear separation of concerns: a human-readable summary for reviewers, a machine-friendly task manifest for tracking, and self-contained task specs that an agent can load individually without needing to cross-reference other files.

## Output structure

The skill produces this file structure at a path specified by the user:

```
{spec-path}/
├── SUMMARY.md                  # Executive summary for human reviewers
├── TASKS.md                    # Task manifest with status checkboxes
├── DECISIONS.md                # Design decisions, rationale, and change log
├── DATABASE.md                 # Database usage map (if applicable)
└── tasks/
    ├── 001-{task-slug}.md      # Self-contained task spec
    ├── 002-{task-slug}.md
    ├── 003-{task-slug}.md
    └── ...
```

DATABASE.md is only created when the project involves a database or persistent data store. See Step 6 for details.

DECISIONS.md is created for any project with non-trivial design decisions. See Step 6b for details.

## Step 1: Gather context

Before writing anything, understand the project. Ask the user (or extract from conversation history):

1. **What are we building?** — the product/feature in plain language
2. **Who is this spec for?** — who will review it, who (or what agent) will implement it
3. **Where should specs live?** — the output path (they may have a dedicated specs repo)
4. **What exists already?** — existing codebase, prior specs, architectural decisions
5. **What are the constraints?** — timeline, tech stack, dependencies, non-negotiables

If the user has already provided this context in the conversation, don't re-ask. Extract and confirm.

## Step 2: Write SUMMARY.md

This is the human-readable executive summary. Its job is to let a reviewer understand the entire project in under 5 minutes. It should read like a well-written brief — not a technical dump.

**Token budget:** Scale to project size. Small projects (<15 tasks): ~5,000 tokens. Medium projects (15-30 tasks): ~6,000 tokens. Large projects (30+ tasks): ~8,000 tokens. These are guidelines — the goal is a document a reviewer can read in under 10 minutes, not a hard cap.

Use this structure:

```markdown
# {Project Name}

## Overview
Two to three sentences: what is being built, why it matters, and who it serves.

## Goals
What success looks like. Be specific and measurable where possible. Use prose, 
not bullet lists — this is a document for humans to read.

## Non-Goals
What is explicitly out of scope. This prevents scope creep and gives reviewers
confidence that boundaries are clear.

## Architecture

How the system is structured at a high level. State key technical decisions
and reference DECISIONS.md for the full rationale behind each one. If there
are architectural constraints (e.g., "must use hexagonal architecture", "must
integrate with existing auth service"), state them here.

Always include an architecture diagram in Mermaid format showing the major 
components and how they relate. Choose the Mermaid diagram type that best 
fits the architecture — typically a flowchart or C4-style diagram.

Example:

~~~mermaid
flowchart TB
    Client[Client Layer<br/>WebSocket + REST]
    Client --> Gateway[API Gateway]
    Gateway --> Auth[Auth Service]
    Gateway --> GameEngine[Game Engine]
    GameEngine --> Domain[Domain Layer<br/>Entities + Commands]
    GameEngine --> EventBus[Event Bus<br/>NATS]
    Domain --> Repo[(Repository<br/>PostgreSQL)]
    EventBus --> Notifications[Notification Service]
~~~

## Key Sequences

Include Mermaid sequence diagrams for the most important flows in the system 
— the ones reviewers need to understand to evaluate the design. Focus on 
flows that cross service or layer boundaries, involve multiple actors, or 
have non-obvious ordering. Typically 2-4 diagrams are sufficient.

Each sequence diagram should have a brief prose introduction (one or two 
sentences) explaining what the flow accomplishes and when it is triggered.

Example:

When a player sends a command, it flows through authentication, parsing, 
execution, and event broadcasting:

~~~mermaid
sequenceDiagram
    participant P as Player Client
    participant G as Gateway
    participant A as Auth Service
    participant E as Game Engine
    participant D as Database
    participant N as NATS

    P->>G: Send command
    G->>A: Validate session
    A-->>G: Session valid
    G->>E: Execute command
    E->>D: Read/write game state
    D-->>E: Result
    E->>N: Publish state change event
    E-->>G: Command result
    G-->>P: Response
~~~

## Key Decisions
One-paragraph summary of each significant design decision. State what was
decided and why, then reference the full entry in DECISIONS.md for rejected
alternatives, tradeoff analysis, and edge cases. These are the things a
reviewer most needs to understand and potentially challenge.

Example: "The pipeline uses an SQS FIFO queue between the sensor worker and
Kinesis, not direct publishing. This exists for failure isolation — the sensor
worker is on the V1 critical path and cannot absorb Kinesis retry latency
during the parallel-run period. See DECISIONS.md #D5 for the full tradeoff
analysis."

## Risks and Open Questions
What could go wrong, what is still uncertain, and what needs input from others.

## Implementation Phases
A brief narrative overview of how the work is sequenced. Not the detailed 
task list — just enough for a reviewer to understand the order of operations 
and why it's sequenced that way. Reference TASKS.md for the detailed breakdown.

## Glossary (if needed)
Define project-specific terms so reviewers and agents share a common vocabulary.
```

**Writing guidance for SUMMARY.md:**
- Write in prose paragraphs, not bullet lists. This is a narrative document.
- Lead with outcomes, not process. "Users will be able to..." not "We will implement..."
- Be opinionated. State decisions, don't present options. If decisions aren't made yet, say so in Risks.
- Keep it honest about complexity. Don't minimize hard parts — reviewers need to know where risk lives.
- **Mermaid diagrams are mandatory**, not optional. The architecture diagram and at least one key sequence diagram must be present. Reviewers consistently cite diagrams as the most valuable part of a spec for quickly grasping the system design.
- Keep diagrams focused — 5-10 nodes for architecture, 4-8 participants for sequences. If a diagram needs more, it's covering too much; split it.
- **SUMMARY.md states decisions; DECISIONS.md explains them.** A reviewer who agrees with a decision reads the one-paragraph summary and moves on. A reviewer who wants to challenge it follows the cross-reference to the full analysis in DECISIONS.md. This keeps SUMMARY.md scannable without losing the reasoning.

## Step 3: Decompose into tasks

Break the implementation into discrete, self-contained tasks. Each task should be a unit of work that one agent session (or one developer) can complete independently.

**Task sizing guidelines:**
- A task should produce a working, testable increment
- A task spec should target under 5,000 tokens (~2,500 words). If it exceeds that, first try to split the task. If the task genuinely can't be split (e.g., an XL processor with tightly coupled requirements), allow up to 8,000 tokens rather than losing implementation detail
- A task should not require reading other task specs to understand what to do
- A task spec may cross-reference DECISIONS.md entries for design rationale (e.g., "See DECISIONS.md #D3 for why FIFO queue over direct publish"), but must be self-contained for *implementation* — the agent should never need to read DECISIONS.md to write the code
- Dependencies between tasks should be explicit (what must be done first), not implicit (buried context)

**Task naming convention:**
- Files are numbered with zero-padded prefixes: `001-`, `002-`, etc.
- Slugs are lowercase kebab-case describing the deliverable: `setup-project`, `implement-auth-flow`, `add-room-entity`
- Numbers indicate suggested order, not strict sequence

## Step 4: Write TASKS.md

This is the central manifest — the single source of truth for what needs to be done and what's been completed. It bridges human and agent needs.

**Token budget:** Scale to project size. Under 4,000 tokens for up to ~30 tasks. For larger projects (30-60 tasks), allow up to 6,000 tokens. The manifest must stay scannable — if it's getting long, the phases are doing the organizational work.

Use this structure:

```markdown
# Task Manifest: {Project Name}

> Last updated: {date}
> Total tasks: {n} | Completed: {n} | In progress: {n} | Remaining: {n}

## Phase 1: {Phase Name}

- [ ] **001 · {Task Title}** — One-sentence description of the deliverable
      `tasks/001-{slug}.md` · Est: {size} · Depends on: none
- [ ] **002 · {Task Title}** — One-sentence description of the deliverable
      `tasks/002-{slug}.md` · Est: {size} · Depends on: 001
- [x] **003 · {Task Title}** — One-sentence description of the deliverable
      `tasks/003-{slug}.md` · Est: {size} · Depends on: none · ✅ Done

## Phase 2: {Phase Name}

- [ ] **004 · {Task Title}** — One-sentence description
      `tasks/004-{slug}.md` · Est: {size} · Depends on: 001, 003
...
```

**Fields explained:**
- **Checkbox** `- [ ]` / `- [x]`: status. Update these as tasks are completed.
- **Number · Title**: quick identification
- **One-sentence description**: what the task produces, not how
- **File path**: where the full task spec lives
- **Est (size)**: relative estimate — use S / M / L / XL. Don't use hours; they're misleading for agents.
- **Depends on**: task numbers that must be completed first. "none" if independent.

**When updating TASKS.md:**
- Check the box when a task is complete: `- [x]`
- Add `· ✅ Done` at the end for visual scanning
- Update the counts in the header
- If a task is in progress, mark it: `- [ ] 🔄 **004 · ...**`
- If a task is blocked, mark it: `- [ ] 🚫 **005 · ...** — Blocked: waiting on API credentials`

## Step 5: Write individual task specs

Each file in `tasks/` is a self-contained spec for one unit of work. An agent should be able to load this single file and implement the task without reading anything else.

**Token budget:** Target under 5,000 tokens per task. XL tasks that can't be split may go up to 8,000 tokens. If a task spec exceeds 8,000 tokens, the task is too big — split it.

Use this structure:

```markdown
# {Task Number}: {Task Title}

> Status: Not started | In progress | Done
> Size: S | M | L | XL
> Depends on: {task numbers or "none"}
> Phase: {phase number and name}

## Objective
What this task produces, stated in one or two sentences. Lead with the 
outcome: "After this task, the system will be able to..."

## Context
What the implementer needs to know to do this work. Include:
- Relevant architectural decisions (don't make them look these up elsewhere)
- Key interfaces or contracts this task must conform to
- Any prior work this builds on (reference file paths in the codebase, not 
  other spec files)

If there are code snippets the implementer needs (e.g., an interface to 
implement, a schema to conform to), include them directly. Don't say 
"see file X" — paste the relevant fragment here.

## Requirements
Specific, testable requirements. Each requirement should be something that 
can be verified. Write them as clear statements, not vague goals.

Use numbered items here so they can be referenced in testing:

1. The Room entity stores id, name, description, and a map of exits
2. Exits map a direction string to a target room ID
3. NewRoom() constructor validates that name is non-empty
4. Room serializes to/from JSON matching the schema in Context above

## Acceptance Criteria
How to verify the task is done. This is what the implementer runs after 
finishing. Be specific about commands, expected outputs, and edge cases.

- All tests pass: `go test ./internal/domain/room/... -v`
- Room can round-trip through JSON serialization
- Constructor rejects empty name with descriptive error

## Files to Create or Modify
Explicit list of file paths. Agents work best with unambiguous targets.

- Create: `internal/domain/room/room.go`
- Create: `internal/domain/room/room_test.go`
- Modify: `internal/domain/room/doc.go` (add package documentation)

## Notes (optional)
Anything else: design considerations, alternative approaches rejected, 
gotchas the implementer should watch for, links to relevant external docs.
```

**Writing guidance for task specs:**
- Paste relevant code fragments directly into Context — don't reference other spec files. Duplication across task specs is acceptable and intentional; self-containment matters more than DRY for spec documents.
- Requirements should be testable statements, not vague aspirations. "Handles errors gracefully" is not a requirement. "Returns a wrapped error with context when the database connection fails" is.
- Acceptance criteria should be runnable. Include actual commands, not "verify it works."
- Keep the files-to-create list tight. If a task touches more than 5-6 files, it's probably too big.

## Step 6: Write DATABASE.md (if applicable)

If the project involves a database or any persistent data store, create DATABASE.md. This document gives reviewers and implementers a complete picture of how the system reads from and writes to the database — something that's notoriously hard to piece together from scattered task specs.

Skip this step entirely if the project has no database or persistent storage.

**Token budget: under 4,000 tokens**

Use this structure:

```markdown
# Database Usage Map: {Project Name}

## Overview
Brief description of the database technology (e.g., PostgreSQL 15, Redis, 
DynamoDB) and the general data access pattern (e.g., repository pattern, 
direct queries, ORM).

## Schema Summary

List each table/collection and its purpose in one sentence. Include the 
key columns/fields but not exhaustive schemas — link to migration files 
or schema definitions in the codebase for the full picture.

| Table | Purpose | Key Fields |
|-------|---------|------------|
| users | Player accounts and authentication | id, username, email, password_hash, created_at |
| rooms | Game world locations | id, name, description, zone_id |
| room_exits | Directional connections between rooms | room_id, direction, target_room_id |
| player_inventory | Items held by players | player_id, item_id, quantity, slot |

## Read/Write Map

This is the core of the document. Map every database operation to the 
component that performs it, the type of operation, and when it happens.

| Component | Table | Operation | Trigger / When | Notes |
|-----------|-------|-----------|----------------|-------|
| AuthService.Login | users | READ | Player login | Lookup by username |
| AuthService.Register | users | WRITE | New account creation | Inserts new row |
| RoomRepository.GetByID | rooms, room_exits | READ | Any room load | Joins rooms + exits |
| RoomRepository.Save | rooms | WRITE | Admin room editing | Updates name, description |
| InventoryService.PickUp | player_inventory | WRITE | Player picks up item | Upserts (increment qty) |
| InventoryService.Drop | player_inventory | DELETE | Player drops item | Removes row if qty = 0 |
| GameEngine.MovePlayer | rooms, room_exits | READ | Player movement | Validates exit exists |
| SessionStore.Create | sessions | WRITE | Login success | TTL-based expiry |
| SessionStore.Validate | sessions | READ | Every authenticated request | High frequency |

## Access Patterns and Performance Considerations

Call out any operations that are high-frequency, involve complex queries, 
or have scaling implications. For example:

- SessionStore.Validate is called on every authenticated request — must 
  be fast. Redis is used for this instead of PostgreSQL.
- RoomRepository.GetByID joins two tables but rooms are loaded once and 
  cached in memory per zone.
- No full table scans are expected in normal gameplay. Admin operations 
  (room search, player lookup) may scan but are infrequent.

## Migrations

If the project uses database migrations, note the migration strategy 
and where migration files live in the codebase.
```

**Writing guidance for DATABASE.md:**
- The Read/Write Map table is the most important part. Every database call in the system should appear here. If a reviewer asks "who writes to the users table?" this table should answer it immediately.
- Use consistent operation names: READ, WRITE (insert/update), DELETE. Add specifics in the Notes column (e.g., "upserts", "bulk insert", "soft delete").
- Include the trigger — when does this operation happen? This helps reviewers trace data flow without reading code.
- Keep the Schema Summary concise. Its job is orientation, not to replace proper schema documentation.
- Update this document when tasks that add new database operations are completed.

## Step 6b: Write DECISIONS.md

This document captures the *why* behind the spec — design decisions, rejected alternatives, resolved questions, deviations from prior work, operator runbooks, and cost analysis. SUMMARY.md states what was decided; DECISIONS.md explains the reasoning so reviewers can evaluate it and future engineers can understand it.

Skip this step only for trivially simple projects where every decision is obvious from the code.

**Token budget:** No hard cap. This document grows with the project's complexity. Each entry should be concise (typically 200-500 words), but the total can be large for complex projects. An agent never needs to load the entire file — it reads individual entries by number when cross-referenced from task specs or SUMMARY.md.

Use this structure:

```markdown
# Design Decisions: {Project Name}

> Last updated: {date}
> Total entries: {n}

## D1: {Decision title}

**Status:** Decided | Deferred | Reversed
**Decided:** {date}
**Context:** {task or component this applies to}

{One paragraph stating what was decided and why — the essential reasoning
that a reviewer needs to evaluate whether this is the right call.}

**Alternatives considered:**
- *{Alternative A}* — rejected because {reason}
- *{Alternative B}* — rejected because {reason}

**Consequences:** {What this decision enables or constrains downstream.
Include operator responsibilities or deployment sequencing requirements
if applicable.}

---

## D2: {Decision title}
...
```

**What goes in DECISIONS.md:**

Entries should cover one of these categories. Not every project will have all of them, but any content that falls into these categories belongs here rather than being condensed into SUMMARY.md or scattered across task specs:

1. **Architectural decisions** — Why component X uses pattern Y. Why the system has N services instead of one. Why this queue exists between these two components.

2. **Rejected alternatives** — What else was considered and why it was ruled out. This is especially important when the rejected option looks simpler on the surface — a future engineer will wonder why you didn't just do the simple thing.

3. **Resolved findings** — Issues surfaced during spec review that required investigation and a decision. Include the investigation trail: what was found, what it means, what was decided. These are the equivalent of "resolved comments" on a PR, but for the spec itself.

4. **Deviations from prior work** — If this project builds on a POC, prototype, or prior spec, document what changed and why. Prior participants will look for these; new participants need to know the current plan is intentional, not accidental divergence.

5. **Cost and capacity analysis** — Throughput estimates, infrastructure cost breakdowns, scaling assumptions. These inform sizing decisions and help reviewers assess whether the architecture is over- or under-provisioned.

6. **Operator runbooks** — Procedures that humans must follow for edge cases the system doesn't handle automatically. Deprecation cleanup, deployment ordering, rollback procedures, manual data fixes.

7. **Deferred decisions** — Things that are explicitly *not* decided yet, why, and what needs to happen before they can be decided. This prevents future engineers from assuming something was overlooked when it was intentionally deferred. Include the candidate approaches being considered so the eventual decision-maker has context.

8. **Convention and style decisions** — Project-specific conventions that an implementing agent needs (error handling patterns, test patterns, naming conventions). These are the rules that don't live in a linter but affect every task.

**Writing guidance for DECISIONS.md:**
- Number entries sequentially (D1, D2, ...) so task specs and SUMMARY.md can cross-reference them by number.
- Lead each entry with the decision, not the analysis. A reader scanning for a specific decision should find it in the first sentence.
- Include the "Alternatives considered" section even when the choice seems obvious to you. What's obvious today may not be obvious in 6 months. If there truly was no alternative, say so and explain why.
- Deferred decisions are just as important as made decisions. An explicit "we haven't decided X yet because Y" prevents someone from making a bad ad-hoc decision during implementation.
- Keep entries independent. Each entry should make sense without reading other entries. Cross-reference other entries by number if needed (e.g., "this reverses D3").
- Update the status when decisions are reversed or deferred decisions are resolved.

**When reorganizing existing specs:** This is where the bulk of "homeless" content lands. Design analysis sections, findings, deviation logs, and rationale prose from existing specs should be reorganized into numbered DECISIONS.md entries, not dropped or condensed into task specs. If the total source material for decisions exceeds what can be covered, prioritize: (1) decisions that are non-obvious or surprising, (2) deviations from prior work, (3) deferred decisions with open contracts, (4) operator runbooks.

## Step 7: Consistency review

After all documents are written, perform a final review across the entire spec to catch inconsistencies. This step is mandatory — do not skip it.

Inconsistencies between spec documents are one of the most common sources of implementation bugs. A task spec that references an interface differently than SUMMARY.md describes it, or a database operation in a task that doesn't appear in DATABASE.md, will cause the implementing agent to make wrong assumptions.

**Review checklist — verify each of these:**

1. **Terminology consistency**: Every entity, service, and concept should use the same name across all documents. If SUMMARY.md calls it "AuthService" but a task spec calls it "AuthenticationService" or "auth module," fix it. Check the Glossary if one exists and make sure all documents conform to it.

2. **Architecture alignment**: The architecture and sequence diagrams in SUMMARY.md should match the components and interactions described in task specs. If a task introduces a component not shown in the architecture diagram, either add it to the diagram or question whether the task is correct.

3. **Task coverage**: Walk through the architecture diagram and sequence diagrams. Every component and every interaction shown should be covered by at least one task. If a component appears in a diagram but no task creates it, there's a gap.

4. **Dependency accuracy**: Check that the "Depends on" fields in TASKS.md and individual task specs are correct. If Task 005 references an interface that Task 003 creates, 005 must list 003 as a dependency. Look for hidden dependencies — tasks that reference code or schemas created by other tasks without declaring the dependency.

5. **Database consistency** (if DATABASE.md exists): Every database operation mentioned in any task spec should appear in the DATABASE.md Read/Write Map. Every entry in the Read/Write Map should be traceable to at least one task. If a task says "save the player's position to the database" but DATABASE.md has no corresponding WRITE entry, add it.

6. **Decision cross-references** (if DECISIONS.md exists): Every cross-reference in SUMMARY.md and task specs (e.g., "See DECISIONS.md #D3") must point to an entry that actually exists in DECISIONS.md. Every key decision mentioned in SUMMARY.md's "Key Decisions" section should have a corresponding DECISIONS.md entry. Deferred decisions referenced in task specs should have a DECISIONS.md entry with status "Deferred."

7. **File path consistency**: File paths referenced in task specs' "Files to Create or Modify" sections should be consistent with the project structure described in SUMMARY.md. If two tasks both create the same file, they should either be merged or their scopes clarified.

8. **Acceptance criteria feasibility**: Each task's acceptance criteria should be achievable using only what exists after its dependencies are complete — not things introduced by later tasks.

9. **Information preservation** (when reorganizing existing specs): If the spec was produced by reorganizing existing documents, verify that no information was dropped. Compare the total content of the original documents against the output. Design rationale, findings, deviations, cost analysis, and operator runbooks should all be traceable to DECISIONS.md entries. Implementation detail should be traceable to task specs. If the output is significantly smaller than the input (more than ~10% reduction), audit what was lost.

**How to report the review:**

After completing the review, add a brief section at the bottom of SUMMARY.md:

```markdown
## Spec Consistency Review
Last reviewed: {date}

Review passed with {n} items corrected:
- Renamed "AuthModule" to "AuthService" in tasks 003, 007 for consistency
- Added missing database READ entry for SessionStore.Validate in DATABASE.md
- Added dependency on task 002 to task 006 (uses UserRepository interface)
```

This gives reviewers confidence the spec has been cross-checked and documents what was fixed. If the review finds no issues, note that too — it's a positive signal.

## Updating specs during implementation

As work progresses, specs need to stay current. Here's the update protocol:

**When a task is completed:**
1. Update the checkbox in TASKS.md: `- [ ]` → `- [x]` and add `· ✅ Done`
2. Update the header counts in TASKS.md
3. Update the task spec's Status to `Done`

**When a task is in progress:**
1. Mark it in TASKS.md with 🔄
2. Update the task spec's Status to `In progress`

**When scope changes mid-project:**
1. Update SUMMARY.md if goals/non-goals/approach changed — update architecture and sequence diagrams if the component structure or key flows changed
2. Add new task specs with the next available number
3. Add new entries to TASKS.md
4. If new tasks introduce database operations, add them to DATABASE.md's Read/Write Map
5. If the scope change involves a design decision, add a DECISIONS.md entry explaining the change and why. If it reverses a prior decision, update the original entry's status to "Reversed" and cross-reference the new entry
6. Do NOT renumber existing tasks — downstream references would break

**When a task turns out to be wrong or unnecessary:**
1. Mark it in TASKS.md: `- [ ] ~~**005 · {Title}**~~ — Removed: {reason}`
2. Don't delete the task spec file — add a note at the top explaining why it was removed

## Token budgets at a glance

| Document | Small project (<15 tasks) | Medium (15-30) | Large (30+) | Rationale |
|----------|--------------------------|-----------------|-------------|-----------|
| SUMMARY.md | ~5,000 | ~6,000 | ~8,000 | Scales with architectural complexity; must stay readable in under 10 minutes |
| TASKS.md | ~3,000 | ~4,000 | ~6,000 | Scales linearly with task count; phases keep it scannable |
| DECISIONS.md | No hard cap | No hard cap | No hard cap | Entries are read individually, not loaded as a whole |
| DATABASE.md | ~3,000 | ~4,000 | ~5,000 | Scales with table count and access pattern complexity |
| Individual task spec | ~5,000 | ~5,000 | ~5,000 (8K for XL) | Stays constant — one task, one agent session |
| All task specs combined | No limit | No limit | No limit | Agent never loads all of them at once |

The key insight: an agent working on a task loads TASKS.md (~4-6K tokens) + one task spec (~5K tokens) = ~9-11K tokens of spec overhead. For a data layer task, add DATABASE.md (~4K) for ~13-15K total. That's still very manageable alongside a codebase. Compare this to 10,000 lines of monolithic spec consuming the entire context window.

DECISIONS.md is the one document without a budget because it's never loaded whole. An agent reads a specific entry only when a task spec cross-references it (e.g., "See DECISIONS.md #D3"). A reviewer reads it front-to-back during design review, but at that point they're focused on decisions, not implementing code — different context budget.

## Common mistakes to avoid

- **Don't put design rationale in task specs.** Task specs tell the agent *what* to build and *how*. The *why* goes in DECISIONS.md. A task spec that spends 2,000 tokens explaining why the team chose pattern X is wasting the agent's context budget — the agent needs the pattern, not the debate that led to it. Cross-reference DECISIONS.md instead.
- **Don't drop rationale entirely either.** The opposite mistake: condensing a 500-line spec into task specs and losing all the reasoning. If the original spec explains why alternative A was rejected, that belongs in DECISIONS.md — not nowhere. Reviewers and future engineers need the "why" even though the implementing agent doesn't.
- **Don't embed acceptance criteria only in SUMMARY.md.** Each task needs its own. The summary is for humans; tasks are for implementers.
- **Don't create tasks that are just "research" or "investigate."** Every task should produce a concrete artifact — code, configuration, tests, data.
- **Don't skip the Context section in task specs.** This is where most specs fail for agents. Without context pasted directly into the task, the agent has to hunt through the codebase or guess. Paste the relevant interface, schema, or contract right there.
- **Don't make TASKS.md a prose document.** It's a manifest — scannable, structured, and updatable. Save the narrative for SUMMARY.md.
- **Don't treat token budgets as hard caps.** They're sizing guidelines, not rules. A 5,200-token task spec for a genuinely complex task is fine. A 12,000-token task spec means the task should be split. The goal is "fits comfortably in an agent's context alongside the codebase," not a specific number.

## Reorganizing existing specs

When reorganizing an existing spec (rather than writing from scratch), the primary challenge is content that is analytical rather than prescriptive. Existing specs often contain deep design analysis, findings from review, deviation logs, and rejected-alternative writeups that don't map to any individual task.

**Triage existing content into four buckets:**

1. **Implementation instructions** → task specs. Code snippets, file paths, step-by-step procedures, test patterns. This is the core of what an agent needs.

2. **Design rationale** → DECISIONS.md. Why this architecture, why not the alternatives, what changed from prior plans, findings from review, cost analysis, operator runbooks, deferred decisions. Reorganize into numbered entries.

3. **System overview** → SUMMARY.md. Architecture diagrams, key sequences, goals, non-goals, risk summary, phase narrative. Condense from the originals but don't lose the structure.

4. **Data layer reference** → DATABASE.md. Table schemas, access patterns, read/write maps, performance considerations.

**The information preservation check is mandatory when reorganizing.** After writing all documents, compare the total byte count of the output against the input. A significant reduction (>10%) signals information loss. Audit what's missing — it's almost always design rationale that didn't make it into DECISIONS.md. See Step 7, check #9.
