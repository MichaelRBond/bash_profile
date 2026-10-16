---
name: handoff-prompt
description: "Use when your context is filling up (around 50%+) mid-task and you want a fresh session to continue exactly where you are — especially on a ticket delivered as a stack of multiple PRs, or when review feedback may land on earlier PRs in that stack. Also use when the user says 'write a handoff', 'handoff prompt', 'hand this off', 'continue in a new session', or is running multiple agents across worktrees on one repo."
---

# Handoff Prompt

Generate a handoff so a **fresh Claude session** (Opus or Fable) continues the current ticket without re-deriving **settled decisions**. It carries decisions and context forward — it does not replace verifying against the actual code. The fresh session should still research, read code, and check its assumptions; if reality contradicts a carried-over decision, it verifies and confirms with the user before deviating. The reader is an agent, not a human — optimize for unambiguous dereferencing and verifiability, not readability.

**Carry decisions, not blindness.** The handoff transfers what was decided so the fresh session doesn't relitigate it for no reason. It is not a command to skip research or accept the plan uncritically. Default: proceed on the decisions. On finding a concrete problem in the code: verify it, then confirm the course change with the user — never silently override, never blindly follow past a real problem.

**Orient, then wait — never auto-start.** The consuming session's first turn is orientation only: read the handoff, run the read-only "Verify bearings" block, then reply with a bearings result and a **proposed** next action, and stop. It does not begin the task, edit code, commit, or push until the user gives the go-ahead. Both templates below must enforce this.

## Core principle: two artifacts, one source of truth

You produce **two** things:

1. **A memory file** — the full, authoritative handoff, written to your memory directory. Fixed schema (below). One living file per ticket, updated in place.
2. **A paste-prompt** — a short, **fully self-contained** block the user copies into the fresh session. It carries the memory file's **absolute path** + handoff ID, plus enough to orient immediately. It must work even if the fresh session has no skills installed.

Why both: the memory file holds depth; the paste-prompt grounds the model instantly and points it at the file. The paste-prompt never depends on this skill being installed on the other side.

## Why memory + absolute path

Your memory directory is keyed to the current working directory. A fresh session in a **different worktree of the same repo gets a different memory directory** and will not auto-discover this handoff. The paste-prompt therefore always carries the **absolute path** to the memory file — that is the bridge across worktrees. The MEMORY.md pointer only helps a same-worktree resume.

## Step 1 — Gather state (one batched message)

Run in parallel. Never rely on conversation memory for facts you can query:

```bash
git rev-parse --show-toplevel                 # repo root
git rev-parse --abbrev-ref HEAD               # branch
git rev-parse HEAD                             # head_sha (drift anchor)
git status --porcelain                         # dirty?
git log --oneline -8
gh repo view --json nameWithOwner -q .nameWithOwner
```

For the **PR stack**, list every PR tied to the ticket so the fresh session can act on any of them:

```bash
gh pr list --repo <owner>/<name> --search "<TICKET-ID>" --state all \
  --json number,title,headRefName,baseRefName,state,reviewDecision,isDraft
```

If `gh` is unavailable or unauthenticated, degrade to git-only and note it in the handoff. From the conversation, capture: the immediate next task, decisions made, gotchas, `path:line` anchors, and how to verify done.

## Step 2 — Key the handoff

- `handoff_id` = `handoff-<ticket-lowercased>` (e.g. `handoff-eng-1234`). No ticket → `handoff-<branch-slug>`.
- Memory file path = `<your-memory-dir>/<handoff_id>.md`, where `<your-memory-dir>` is the absolute path given in your memory instructions.
- If the file already exists (same ticket, earlier PR), **read it, update in place, and append a Progress log line** — do not create a second file.

## Step 3 — Write the memory file

Use this schema exactly. Every field is required unless marked optional; fill real values, never leave a placeholder.

````markdown
---
name: handoff-<ticket>
description: "Handoff for <TICKET> — <one-line current task>. Read when resuming this ticket in a fresh session."
metadata:
  type: project
---

# Handoff: <TICKET> — <title>

```yaml
handoff_id: handoff-<ticket>
ticket: <TICKET or none>
repo: <owner>/<name>
default_branch: main
worktree: <abs worktree path>
branch: <current branch>
base: <base branch>
head_sha: <sha at handoff>      # drift anchor — fresh session compares to reality
dirty: <true|false>            # uncommitted changes present?
stack:
  - pr: <number|null>          # null = not opened yet
    branch: <branch>
    state: <merged|open|draft|local>
    review: <approved|changes-requested|none>
    role: <current|done|blocking>
generated_from_cwd: <cwd>
```

## On resume (orient, then wait)
This file is orientation, not a run-list. On resume: read it, run "Verify bearings" (read-only), then present the proposed next action below to the user and WAIT for their go-ahead. Do not edit, run the task, commit, or push until they confirm.

Proposed next action (present it, do not auto-execute):
1. <immediate next task, one imperative line>
Then, after that (context — not a queue to auto-run):
2. <next…>

## Verify bearings (run first, compare to the yaml above)
```bash
cd <worktree>
git rev-parse --abbrev-ref HEAD    # expect <branch>
git rev-parse HEAD                  # expect <head_sha>; if different, commits landed — re-read git log
git status --porcelain             # expect dirty=<true|false>
gh pr view <current-or-relevant-pr> --repo <owner>/<name> --json state,reviewDecision
```
If any expectation is wrong, STOP and re-orient — the world moved since handoff.

## Current task
<what + where, with path:line anchors; why any test fails; the decision that governs it>

## PR stack — status & history
| PR | branch | state | did / does | outstanding |
|----|--------|-------|-----------|-------------|
| #218 | … | merged | … | — |

## Handling review feedback on earlier PRs
Do NOT trust this file for feedback — pull the LATEST threads first, they may have changed:
```bash
gh pr view <n> --repo <owner>/<name> --comments
gh api "repos/<owner>/<name>/pulls/<n>/comments?per_page=100" --jq '[.[]|{path,line,body,user:.user.login}]'
```
Switch to that PR's branch/worktree before changing it. Never apply another PR's fix from the current worktree.
Known-open at handoff:
- #<n>: <one-line ask> — <addressed?>

## Key files & anchors
- `path:line` — <why it matters>

## Constraints & decisions
These are settled defaults — carry them forward, don't relitigate them for no reason. They are not gospel: if the code shows one is wrong or unworkable, verify it, then confirm the change with the user before deviating. Don't silently override; don't blindly follow past a real problem.
- <decision — with a one-line reason if non-obvious>

## Verify done
```bash
<exact test/build commands>
```
- <per-task acceptance check>

## Guardrails — do NOT
- <e.g. touch merged PR #218 code>
- <e.g. rebase/force-push without asking>

## Progress log
- <YYYY-MM-DD>: <what happened, why handed off>
````

Then add a one-line pointer to `MEMORY.md`: `- [Handoff <TICKET>](<handoff_id>.md) — resume point for <ticket>`.

## Step 4 — Emit the paste-prompt

Print this for the user to copy. Self-contained; carries the absolute path.

```
You are resuming <TICKET> "<title>" in a fresh session. A prior session saved a full handoff to memory.

FIRST, read the authoritative handoff (do not act before reading it):
  Read: <ABSOLUTE PATH to memory file>
  Handoff ID: <handoff_id>
If that path is unreadable (different machine, or the file is gone), tell me and I'll paste it.

Orientation (full detail in that file):
- Repo <owner>/<name>, worktree <worktree>, branch <branch> (base <base>), dirty=<true|false>.
- Stack: <one-line-per-PR summary incl. which have open feedback>.
- Immediate task: <one line — the what, the where, the governing decision>.

On this first turn, ORIENT ONLY — do not start the work:
1. Read the handoff file above.
2. Run its "Verify bearings" block (read-only) and reconcile against the file.
3. STOP and reply with: a one-line bearings result (matches, or what drifted) and a proposed next action. Then WAIT for my instructions. Do not edit code, run the task, commit, or push until I tell you to.

Once I confirm, and only then:
- Work the task I approve. The handoff's decisions are settled defaults — carry them forward, but keep verifying against the code; if one is wrong or blocked, verify it and confirm with me before changing course. The handoff is context, not a substitute for checking reality.
- For feedback on earlier PRs, follow "Handling review feedback on earlier PRs" in the file — pull the latest gh threads first; never fix another PR from this worktree.

Follow the repo's CLAUDE.md conventions (branch grammar, draft PRs, conventional commits, no agent attribution).
```

## Rules

- **Prefer this skill's manual trigger** (`/handoff-prompt`) — a skill can't detect context %, so the user invokes it.
- **Query, don't recall.** Every fact in the yaml block comes from Step 1 commands, not from conversation memory.
- **Resolve every reference.** `path:line`, real PR numbers, absolute paths. No "the file we changed."
- **One living file per ticket.** Update in place; append to Progress log; never spawn a second file for the same ticket.
- **Paste-prompt stays self-contained.** It must not assume this skill exists on the other side.
- **Orient, then wait.** The paste-prompt and "On resume" section must tell the fresh session to read, verify bearings, propose a next action, and stop — never auto-start the task.
- **Show the user both** the paste-prompt (to copy) and the memory file path (so they know where it lives).

## Common mistakes

| Mistake | Fix |
|---|---|
| All-prose handoff | Fill the yaml state block; agents parse it deterministically |
| Omitting `head_sha` | Include it — it's how the fresh session detects drift |
| Fat prompt, nothing in memory | Split: depth in the memory file, pointer + orientation in the paste-prompt |
| Relative paths / "the current file" | Absolute paths and `path:line` only |
| Trusting the file for PR feedback | Prompt mandates a fresh `gh` pull before acting on any PR |
| New file every handoff | Update the existing `handoff-<ticket>.md` in place |
| Fresh session auto-starts the task | Prompt says orient, propose a next action, then wait for the user's go-ahead |
