---
name: github-summarize-comments
description: "Summarize human PR comments — deduplicate similar feedback, condense long comments, and validate concerns against the codebase. Reads PR context from $DEVDASH_CONTEXT."
---

# Summarize PR Comments

Fetch all human comments on a PR, summarize them, deduplicate similar feedback, and validate any concerns or change requests against the actual code.

---

## Step 0: Load PR Context

Read the context file:

```bash
cat "$DEVDASH_CONTEXT"
```

Extract: `repo`, `pr_number`, `branch`.

If `$DEVDASH_CONTEXT` is not set, ask the user for the repo and PR number.

---

## Step 1: Verify Repo

Check the current directory matches the target repo:

```bash
git remote get-url origin 2>/dev/null
```

If not in the right repo, tell the user and stop.

---

## Step 2: Fetch PR Comments

Use `gh` to get all comments, filtering to humans only (skip bots):

```bash
gh pr view <pr_number> --json comments,reviews --repo <repo>
```

This returns:
- `comments` — general PR comments
- `reviews` — review comments (inline and top-level)

Filter out bot comments by checking the author login. Common bots to exclude:
- Any author with `[bot]` suffix
- `github-actions`
- `dependabot`
- `renovate`
- `codecov`

Also fetch inline review comments:

```bash
gh api repos/<repo>/pulls/<pr_number>/comments
```

---

## Step 3: Fetch the PR Diff

Get the actual changes for validating concerns:

```bash
git fetch origin <branch>
git diff origin/main...origin/<branch>
```

Or use:

```bash
gh pr diff <pr_number> --repo <repo>
```

---

## Step 4: Analyze and Summarize

Process all human comments and produce a structured summary:

### 4a. Group similar comments

If multiple people raised the same concern (e.g., two reviewers both mention error handling in the same function), group them:

```
**Error handling in parseConfig()** — raised by @alice and @bob
  Alice: "This should handle the nil case"
  Bob: "What happens when config is empty?"
  → Both are concerned about nil/empty input to parseConfig
```

### 4b. Condense long comments

For comments longer than 2-3 sentences, extract the key point:

- **Original** (15 lines about naming conventions and refactoring suggestions)
- **Summary**: "@carol suggests renaming `processData` to `transformRecords` for clarity, and extracting the validation logic into a separate function"

Always attribute to the original author.

### 4c. Validate concerns against the code

For every comment that requests a change or raises a concern:

1. Read the relevant code in the PR diff
2. Read surrounding context (callers, tests, related files)
3. Determine if the concern is:
   - **Valid** — the code has the issue described
   - **Already handled** — the concern is addressed elsewhere in the code
   - **Not applicable** — the reviewer misunderstood the code's intent
   - **Debatable** — reasonable people could disagree

---

## Step 5: Present the Summary

```
═══════════════ PR COMMENT SUMMARY ═══════════════

PR: <repo>#<pr_number> — <title>
Comments from: <list of human commenters>
Total comments: <N> (from <M> reviewers)

───────────────────────────────────────────────────

## Action Required

<Comments that need your attention — valid concerns, change requests>

1. **<file>:<line>** — @<author>: <concise summary>
   Status: ⚠️ Valid — <brief explanation of why>

2. **<file>:<line>** — @<author1>, @<author2>: <grouped concern>
   Status: ⚠️ Valid — <brief explanation>

## Already Handled

<Concerns that are addressed in the code but the reviewer may not have seen>

1. **<file>:<line>** — @<author>: <concern>
   Status: ✅ Handled — <where/how it's addressed>

## No Action Needed

<Comments that are observations, praise, or not applicable>

1. @<author>: <summary>
   Status: ℹ️ <reason — e.g., "style preference", "already follows convention">

## General Discussion

<Non-code comments — questions, context, decisions>

1. @<author>: <summary>

═══════════════════════════════════════════════════
```

### Rules:

- **Always attribute.** Every summary point names who said it.
- **Be honest.** If a concern is valid, say so even if it means more work.
- **Read the code.** Don't guess whether a concern is valid — verify it.
- **Skip bot noise.** Only summarize human comments.
- **Prioritize.** Action Required items come first.

---

## Important Behaviors

- **Don't fabricate.** Only summarize what was actually said.
- **Don't dismiss valid concerns.** If a reviewer found a real issue, flag it clearly.
- **Be concise.** The whole point is to save time reading comments.
- **Validate against code, not assumptions.** Read the actual diff and surrounding code before classifying a concern.
