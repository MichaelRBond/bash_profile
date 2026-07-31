---
name: code-review-loop
description: "Use when the user invokes /acr-review or asks to run the ACR review loop, external code review cycle, or iterative review process. Orchestrates an automated code review feedback loop using ACR (Agentic Code Reviewer). Never runs automatically."
---

# Code Review Loop

Automated code review feedback loop: run ACR against the current branch diff, evaluate each finding (fixing real issues, flagging false positives and out-of-scope findings), and re-review — capped at 3 iterations.

This skill is **never triggered automatically**. It runs only when the user invokes the `/acr-review` slash command.

---

## Prerequisites

ACR (Agentic Code Reviewer) must be installed and available on the PATH. See https://github.com/richhaase/agentic-code-reviewer for installation.

If `acr` is not found, tell the user and stop. Do not attempt to install it without asking.

---

## How ACR Works

ACR is a **diff-based** reviewer. It compares the current branch against a base ref (default: `main`) and reviews the entire diff. Key facts:

- **No subcommand** — invoke as `acr [flags]`, NOT `acr review`
- **No file targeting** — ACR reviews the entire diff, not individual files
- **Output goes to stdout** — findings are printed directly with priority tags (P1/P2/P3)
- **`--local`** — skips posting to a PR; required for local-only reviews
- **`--base <ref>`** — sets the base branch to diff against (e.g., `master`, `main`)
- **`--reviewer-agent`** — agent for reviews: `codex`, `claude`, `gemini` (default: `codex`)
- **`--summarizer-agent`** — agent for summarization (default: `codex`)
- **`--reviewers N`** — number of parallel reviewers (default: 5)

Run `acr --help` for the full flag reference.

---

## Workflow

### Step 0: Determine scope

ACR reviews the entire diff against the base branch. When working on a feature branch, the diff may include unrelated changes (e.g., from a shared worktree or upstream merges). Before running ACR:

1. Identify the **in-scope files** — the files the user actually changed for this task. Use one of:
   - `git diff --name-only` (unstaged changes)
   - `git diff --cached --name-only` (staged changes)
   - Explicit file list from the user or conversation context
2. Confirm the file list and base branch with the user before proceeding.

This scope list is used later to **filter findings**, not to target ACR (which always reviews the full diff).

### Step 1: Verify ACR is available

```bash
command -v acr >/dev/null 2>&1 && echo "acr found" || echo "acr not found"
```

If not found, inform the user and stop.

### Step 2: Determine the base branch

Check what the typical base branch is:

```bash
git remote show origin | grep 'HEAD branch'
```

Or use the branch the user specifies. Common values: `master`, `main`.

### Step 3: Run the review loop (max 3 iterations)

For each iteration (1 through 3):

#### 3a. Run ACR directly

Run ACR in the main session. No sub-agent needed — it's a single CLI command.

```bash
acr --base <base-branch> --local --reviewer-agent claude --summarizer-agent claude 2>&1 | tee /tmp/acr_review_iteration_N.txt
```

Replace `N` with the current iteration number and `<base-branch>` with the base ref.

**Do NOT spawn a sub-agent to run ACR.** It's a CLI tool that returns output directly. A sub-agent adds minutes of overhead for zero benefit.

#### 3b. Filter and evaluate findings

ACR returns findings tagged with priority levels. For each finding:

1. **Check if in scope** — is the finding in one of the in-scope files from Step 0? If not, classify as **out of scope** and skip it. This is the most common source of noise.

2. **Classify priority:**

| Priority | Meaning | Action if genuine |
|----------|---------|-------------------|
| P1 | Critical — bugs, security holes, data loss risks | Fix immediately |
| P2 | Important — logic errors, bad patterns, maintainability risks | Fix immediately |
| P3 | Minor — style, naming, minor improvements | Fix if straightforward; skip if trivial |

3. **Evaluate genuine vs false positive** — for each in-scope finding, read the relevant code and determine if it's valid. A finding is a false positive if:
   - The reviewer misunderstood the code's intent or context
   - The flagged pattern is intentional and correct for this use case
   - The issue has already been handled elsewhere
   - The suggestion would break existing functionality
   - The reviewer flagged a language idiom or framework convention as a problem

Do not blindly fix everything. Think critically about each finding.

#### 3c. Present the summary

```
## Review iteration N — Summary

### In-scope findings:

#### Issues to fix:
- P1: X issues
- P2: X issues
- P3: X issues (fixing N, skipping M as trivial)

1. [P1] [file:line] Brief description — what will be changed
2. [P2] [file:line] Brief description — what will be changed

#### False positives:
1. [P2] [file:line] ACR flagged: "description"
   -> Why it's a false positive: explanation

### Out-of-scope findings: X (in files not part of this task)
```

If there are no false positives, omit that section. If there are no real issues, say so.

#### 3d. Fix genuine issues

Fix all genuine P1 and P2 issues directly. For P3 issues, fix if the change is localized, low-risk, and clearly beneficial; otherwise note them and move on.

After fixing, briefly describe each change made.

#### 3e. Check exit conditions

Stop the loop if ANY of these are true:
- No genuine P1 or P2 in-scope issues were found in this iteration
- This was iteration 3 (hard cap)
- The reviewer found no issues at all
- The same issues keep recurring across iterations (loop is not converging)

If stopping, move to Step 4. Otherwise, increment the iteration counter and go back to 3a.

### Step 4: Final report

```
## ACR Review Complete

Iterations: N/3
In-scope findings: X
Genuine issues fixed: Y
False positives identified: Z
Out-of-scope findings: W (not part of this task)
Items deferred: V (trivial P3s)

### Changes made:
- [file] Description of change (iteration N)

### False positives:
- [file:line] What ACR said -> Why it's not an issue

### Out-of-scope findings (may be worth flagging separately):
- [file:line] Brief description — belongs to other work

### Deferred items (not fixed):
- [P3] [file:line] Description — reason for deferral
```

---

## Important Behaviors

- **Never run automatically.** This skill only activates via `/acr-review`.
- **Run ACR directly.** No sub-agents. It's a CLI tool — just run it.
- **Cap at 3 iterations.** Even if issues remain after 3 rounds, stop and report.
- **Filter by scope first.** The most common noise source is findings in files not related to the current task. Filter these out before evaluating.
- **Evaluate every in-scope finding.** Don't blindly fix — determine whether each finding is genuine or a false positive before acting.
- **Explain false positives.** When a finding is a false positive, explain why so the user can override you if they disagree.
- **Be transparent.** Always show the user what was found and what you're planning to fix before making changes.
