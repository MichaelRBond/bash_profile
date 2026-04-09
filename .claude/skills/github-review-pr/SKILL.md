---
name: github-review-pr
description: "Review a GitHub PR using ACR (Agentic Code Reviewer), filter false positives, and produce a ready-to-post review. Reads PR context from $DEVDASH_CONTEXT when launched from devdash, or can be invoked manually."
---

# GitHub PR Review

Run ACR against a PR, critically evaluate every finding, and produce a polished review ready to paste into GitHub.

---

## Prerequisites

- `acr` must be installed and on PATH. See https://github.com/richhaase/agentic-code-reviewer
- `gh` CLI must be authenticated for the target repo.

If either is missing, tell the user and stop.

---

## Step 0: Load PR Context

Check if `$DEVDASH_CONTEXT` is set and points to a valid JSON file. If so, read it:

```bash
cat "$DEVDASH_CONTEXT"
```

Extract these fields:
- `repo` — full repo name (e.g., `HeatWatch/v2-backend`)
- `repo_name` — short repo name (e.g., `v2-backend`)
- `pr_number` — PR number
- `pr_title` — PR title
- `branch` — head branch name
- `author` — PR author

If `$DEVDASH_CONTEXT` is not set, ask the user for the repo and PR number.

---

## Step 1: Verify We're in the Right Repo

Check that the current directory is a git repo matching the target:

```bash
git remote get-url origin 2>/dev/null
```

If the remote URL contains the repo name (e.g., `v2-backend`), you're in the right place.

If NOT in the right repo, stop and tell the user:
> "This skill needs to run from within the <repo_name> repository. Devdash should have launched claude in the correct directory. If not, set $GITHOME to the parent directory of your repos and try again."

---

## Step 2: Create a Worktree for the PR

Create an isolated worktree so the review doesn't affect the main working tree:

```bash
# Fetch the PR branch
git fetch origin <branch>

# Create worktree in a temp location
WORKTREE_DIR="/tmp/devdash-review-pr-<pr_number>"
git worktree add "$WORKTREE_DIR" origin/<branch> --detach

# Enter the worktree
cd "$WORKTREE_DIR"
```

If the worktree already exists (from a previous review), remove and recreate it:

```bash
git worktree remove "$WORKTREE_DIR" --force 2>/dev/null
git worktree add "$WORKTREE_DIR" origin/<branch> --detach
cd "$WORKTREE_DIR"
```

Confirm you're in the worktree:

```bash
pwd
git log --oneline -1
```

---

## Step 3: Run ACR

Run ACR locally against the PR:

```bash
acr --pr <pr_number> --local --reviewer-agent claude --reviewers 5 --verbose 2>&1 | tee /tmp/acr-pr-<pr_number>.txt
```

If ACR exits with code 0 (no findings), skip to Step 6 with an "LGTM" review.

---

## Step 4: Evaluate Findings

For EVERY finding ACR reports, do a thorough evaluation:

### 4a. Read the source code

For each finding, read:
- The flagged file and line range
- Surrounding context (at least 20 lines above and below)
- Any related code paths (callers, callees, interfaces, tests)

Do NOT skip this step. You must understand the code before judging a finding.

### 4b. Classify each finding

| Classification | Criteria |
|---|---|
| **Genuine issue** | Real bug, security hole, logic error, or significant code quality problem |
| **False positive** | ACR misunderstood the code's intent, flagged an intentional pattern, or issue is handled elsewhere |
| **Out of scope** | Finding is about code not changed in this PR |
| **Nitpick** | Style/naming suggestions that don't affect correctness |

### 4c. For genuine issues, assess severity

| Severity | Meaning |
|---|---|
| **Blocking** | Must be fixed before merge — bugs, security issues, data loss risks |
| **Important** | Should be fixed — logic errors, bad patterns, missing error handling |
| **Suggestion** | Nice to have — minor improvements, refactoring opportunities |

---

## Step 5: Compose the Review

Write a GitHub PR review in markdown. Structure it as follows:

```markdown
## Code Review: <PR title>

### Summary

<2-3 sentence summary of what the PR does and overall assessment>

### Findings

#### Blocking
<If none, omit this section entirely>

- **<file>:<line>** — <description of the issue>
  <brief explanation of why this is a problem and what should change>

#### Important
<If none, omit this section entirely>

- **<file>:<line>** — <description>
  <explanation>

#### Suggestions
<If none, omit this section entirely>

- **<file>:<line>** — <description>
  <explanation>

### False Positives Filtered

<List ACR findings you determined were false positives and why>

- **<file>:<line>** — ACR flagged: "<what ACR said>"
  Filtered because: <why it's not actually an issue>

### Verdict

<One of: **Approve**, **Request Changes**, **Comment Only**>
```

### Rules for the review:

- **Be specific.** Reference exact files, lines, and code snippets.
- **Be constructive.** Suggest what to do, not just what's wrong.
- **Be honest about uncertainty.** If unsure about a finding, say so.
- **Don't pad the review.** If the PR is clean, say LGTM and move on.
- **Omit empty sections.** Don't include "Blocking: None" — just skip it.

---

## Step 6: Present the Review

Display the complete review so the user can copy it:

```
The review below is ready to paste into GitHub. Copy everything between the markers:

════════════════ REVIEW START ════════════════

<the review markdown>

════════════════ REVIEW END ══════════════════
```

Then ask the user:
1. Would you like to post this review directly via `gh`?
2. Would you like to modify anything first?
3. Or just copy it manually?

If posting directly:

```bash
gh pr review <pr_number> --<approve|request-changes|comment> --body '<review body>'
```

---

## Step 7: Clean Up Worktree

After the review is complete (posted or copied), clean up:

```bash
# Return to original directory
cd -

# Remove the worktree
git worktree remove "/tmp/devdash-review-pr-<pr_number>" --force
```

Always clean up, even if the review was cancelled.

---

## Important Behaviors

- **Read the code.** Don't just parrot ACR findings. Verify each one by reading the actual source.
- **Think about code paths.** Follow the data flow — a function might look fine in isolation but be called unsafely.
- **Filter aggressively.** ACR produces false positives. Your job is to catch them.
- **One review, not a conversation.** Produce a single complete review, not a back-and-forth.
- **Respect the author.** The review will be read by a human. Be professional and helpful.
- **Always clean up the worktree.** Don't leave temp worktrees around.
