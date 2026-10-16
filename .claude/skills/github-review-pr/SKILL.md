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

## Tracking marker

Every comment this skill posts ends with the HTML marker `<!-- github-review-pr:v1 -->` (invisible in rendered markdown). Future runs use it to identify prior comments so we can dedupe, honor 👎 / author-rejection signals, and resurface unaddressed findings. Required on both inline comment bodies and the overall review body in Step 5. If you change the `v1` suffix, also update the match logic in Step 2's prior-comments processing.

---

## Step 0: Load PR Context

Resolve PR context from the first source that succeeds, then extract all six fields: `repo` (e.g., `octocat/hello-world`), `repo_name` (just the repo segment), `pr_number`, `pr_title`, `branch`, `author`. Then resolve the reviewer `agent` (see "Reviewer Agent" below).

### Source priority

1. **`$DEVDASH_CONTEXT`** — if the env var is set, use the `Read` tool on that path and parse as JSON. Devdash provides all six fields directly.

2. **User-named PR in the invoking message** — if the user identified a PR (URL, short form, or bare number), parse it and fill the remaining fields via `gh`:
   - **URL** `https://github.com/<owner>/<repo>/pull/<n>` → `repo = "<owner>/<repo>"`, `pr_number = <n>`.
   - **Short forms** `<owner>/<repo>#<n>` or `<owner>/<repo>/pull/<n>` → same mapping.
   - **Bare `<n>`** → derive `repo` from the current working directory:
     ```
     gh repo view --json nameWithOwner -q .nameWithOwner
     ```
   Then fetch the remaining fields in one call:
   ```
   gh pr view <pr_number> --repo <repo> --json number,title,headRefName,author
   ```
   Map: `pr_title = .title`, `branch = .headRefName`, `author = .author.login`. Set `repo_name` to the segment after `/` in `repo`.

3. **Nothing provided** — ask the user for a PR URL or `<owner>/<repo>` + PR number. Don't proceed until all six fields are populated.

If `gh` returns an error (PR not found, repo inaccessible, not authenticated for that org), surface the error and stop. Do not fall through to a different source.

### Reviewer Agent

Resolve `agent` (passed to ACR's `--reviewer-agent`). Supported values: `claude`, `codex` (case-insensitive).

1. **Inline override**: if the invoking message names an agent (e.g., "with codex", "using claude", `--reviewer-agent codex`), use it. Anything other than `claude`/`codex` → ask the user to clarify, don't guess.
2. **Otherwise, you MUST prompt the user before dispatching subagents.** Do **not** silently choose a default. This is required even in autonomous/auto-mode operation — the choice has real cost implications and the user has explicitly asked to be prompted every run. Send this question verbatim and wait for a response:

   > Which agent should ACR use? `claude` or `codex`?

   Treat an empty response as `claude`. Any other non-{`claude`,`codex`} response → re-ask, do not guess.

Do not proceed to Step 1 until `agent` is resolved from an inline override or an explicit user response.

---

## Step 1: Verify We're in the Right Repo

Check `git remote get-url origin` contains the target repo name. If not, stop and tell the user:

> "This skill needs to run from within the <repo_name> repository so ACR can check out the PR branch in an isolated worktree. Either `cd` into that repo and re-run, or — if you launched from devdash — set $GITHOME to the parent directory of your repos and retry."

---

## Step 2: Dispatch ACR Triage and Fetch Prior Comments in Parallel

Issue these in a **single message** (parallel tool use):

- An `Agent` call dispatching **Subagent 2a** (ACR + triage) — described below.
- A `Bash` call **fetching prior comments** directly in the main context (no subagent — the work is mechanical, and subagent dispatch overhead would dwarf it). Described below.

When both return, process the Bash output per "Processing prior comments" below, then proceed to Step 3.

### Subagent 2a — ACR + Triage

Dispatch with `subagent_type: "general-purpose"`, `isolation: "worktree"`, and `model: "sonnet"`. `general-purpose` is the right fit for multi-step task execution (run a long shell command, read targeted file ranges, emit structured JSON); `Explore` is read-only search and the wrong shape for this work. The worktree auto-cleans on subagent exit.

Brief the subagent with `repo`, `pr_number`, `branch`, and `agent`, and instruct it to:

1. In the worktree, fetch and check out the PR branch, then capture the SHA so we can anchor inline comments to this commit at posting time (protects against new commits landing on the PR mid-review):
   ```
   git fetch origin <branch>
   git checkout origin/<branch>
   BRANCH_SHA=$(git rev-parse HEAD)
   ```
   Carry `BRANCH_SHA` through to the JSON return as `branch_sha`.
2. Run ACR locally. **Pass `timeout: 600000` (10 min) to the Bash tool** — the default 2-min Bash timeout kills ACR mid-run and causes retry loops that burn tokens. Do **not** use `--verbose`; the streaming reviewer chatter floods the subagent's context without adding signal.
   ```
   acr --pr <pr_number> --local --reviewer-agent <agent> --reviewers 3
   ```
3. **LGTM short-circuit:** if ACR exits 0 with no findings, return `{"branch_sha": "<SHA>", "verdict": "lgtm"}` and stop. Do not perform an independent review.
4. Capture the PR diff for inline-anchor validation:
   ```
   gh pr diff <pr_number> > /tmp/pr-<pr_number>.diff
   ```
   For each finding, set `in_diff = true` iff `<file>:<line>` falls inside a hunk on the `RIGHT` side (post-change line numbers). Lines outside any hunk get 422 from GitHub.
5. Read each flagged file plus ~20 lines of surrounding context — **issue all reads in parallel in a single message**, not sequentially. Then triage.
6. Return a JSON object with the captured `branch_sha` and a `findings` array:
   ```json
   {
     "branch_sha": "<SHA captured in step 1>",
     "findings": [
       {
         "file": "path/to/file.ts",
         "line": 42,
         "in_diff": true,
         "acr_quote": "<verbatim ACR finding>",
         "classification": "genuine | false_positive | out_of_scope | nitpick | praise",
         "severity": "blocking | important | suggestion | n/a",
         "description": "<concise issue description>",
         "reasoning": "<why this classification/severity, or for false positives, why it's not an issue>",
         "comment_body": "<inline comment markdown — only for inline-posted classifications, see table>"
       }
     ]
   }
   ```

**`comment_body` format** — Conventional Comments (https://conventionalcomments.org/), self-contained since the reader sees it on a single line:
```
<label> (<decoration>): <one-line subject, ~80 chars max>

<1–3 sentence discussion: why it's a problem and what to change. Include a fix or snippet when useful.>
```

Do **not** include the tracking marker — the main context appends it during posting.

**Classification + severity + mapping:**

| classification | severity | label / decoration | inline? | meaning |
|---|---|---|---|---|
| genuine | blocking | `issue (blocking)` | yes | real bug, security, data loss — must fix |
| genuine | important | `issue (non-blocking)` | yes | logic error, missing error handling — should fix |
| genuine | suggestion | `suggestion (non-blocking)` | yes | nice-to-have improvement |
| nitpick | n/a | `nitpick (non-blocking)` | yes | style/naming, no correctness impact |
| praise | n/a | `praise: <subject>` | yes | something genuinely well-done — don't fabricate |
| out_of_scope | n/a | `note (non-blocking)` | summary only | not in this PR's diff |
| false_positive | n/a | — | filtered | ACR misread intent or it's handled elsewhere |

Example `comment_body` for `issue (blocking)`:
```
issue (blocking): empty config file crashes startup with a nil map write

If `config.yaml` is empty, `yaml.Unmarshal` leaves `cfg.Limits` nil, and `cfg.Limits["default"] = 10` panics. Initialize the map before the assignment.
```

### Fetching prior comments (Bash)

Single `gh api` call with server-side jq trim — runs in the main context, paired with the 2a `Agent` call:
```
gh api "repos/<owner>/<repo>/pulls/<pr_number>/comments?per_page=100" \
  --jq '[.[] | {id, in_reply_to_id, body, user: .user.login, path, line, reactions: (.reactions | del(.url))}]'
```

Hard cap of 100 — markers from this skill's recent runs cluster together, so 100 suffices in practice. The trim drops `diff_hunk`, URLs, and full user objects (~75% size reduction on typical PRs).

### Processing prior comments

After the Bash returns, build the prior-comments list in the main context. Schema (consumed by Step 3):

```json
[
  {
    "comment_id": 123456,
    "file": "path/to/file.ts",
    "line": 42,
    "subject": "<first line of the original comment body, marker stripped>",
    "original_body": "<full original comment body, marker stripped>",
    "status": "rejected | acknowledged | unaddressed",
    "rejection_signal": "<thumbs-down: N | author reply: \"...\"> — only when status=rejected, otherwise null"
  }
]
```

1. If the Bash response is `[]`, the prior-comments list is `[]`. Done.
2. Identify "marker comments" — entries whose `body` contains the literal string `<!-- github-review-pr:v1 -->`. Replies do not contain the marker.
3. For each marker comment:
   - **Replies**: entries from the full list whose `in_reply_to_id` matches this comment's `id`.
   - **Status** (use natural-language judgment, not substring matching — natural rejection phrasing is too varied for a fixed keyword list):
     - `rejected` — `reactions["-1"] > 0`, OR any reply from the PR author signals declining-to-fix or asserts the finding is wrong. Concrete rejection signals (non-exhaustive): "won't fix", "wontfix", "by design", "intentional", "leaving as-is", "I'm gonna leave this", "leave it", "out of scope", "false positive", "disagree", "not an issue", "not a bug", "working as intended", "best-effort and that's fine", "X is the priority over Y", "should be handled elsewhere". Match on intent, not literal phrasing. Set `rejection_signal` to `thumbs-down: N` or `author reply: "<≤120-char snippet from the most rejection-bearing reply>"`.
     - `acknowledged` — not rejected, but the thread has any reply OR any reaction other than 👎. The author is engaging with the issue but hasn't declined to fix it.
     - `unaddressed` — no replies, no reactions.
   - When ambiguous between `rejected` and `acknowledged`, prefer `acknowledged` — `rejected` is for clear declines, not engaged discussion.
   - Replies from anyone other than the PR author (including bots like CodeRabbit) do not trigger rejection — they count as `acknowledged` engagement only.
4. Emit the prior-comments list per the schema above.

---

## Step 3: Reconcile Findings Against Prior Comments

This step runs in the **main context** after Step 2 completes. It merges the ACR triage list (from Subagent 2a) with the prior-comments list (built in Step 2 from the Bash output) and produces the final list of findings to post and summarize.

If 2a's `verdict` is `lgtm` (no `findings` array), skip ACR-side reconciliation: there are no new findings to merge. Still consult the prior-comments list — any `unaddressed` priors get a "Still Pending from Prior Review" section in Step 4.

Otherwise, for each finding in 2a's `findings` array, look for a matching prior comment in the prior-comments list. A match requires **all** of:
- Same `file`, AND
- `line` within ±3 of the prior comment's `line`, AND
- The two findings are clearly about the same issue (judge by comparing the ACR `description` to the prior `subject`/`original_body` — same topic, not just the same neighborhood).

For each match, apply this rule:

| prior status | action on the new ACR finding |
|---|---|
| `rejected` | Override `classification` to `false_positive`. Set `reasoning` to: `Previously raised; PR author signaled rejection (<rejection_signal>). Treating as false positive and not re-posting.` Move to the "False Positives Filtered" section in Step 4. |
| `acknowledged` | Drop entirely — do not re-post inline, do not list in any section. The thread already exists and was discussed. |
| `unaddressed` | Drop the new finding from inline posting and from the regular sections, but record it for the "Still Pending from Prior Review" section in Step 4. |

ACR findings with **no prior match** flow through unchanged.

After the match pass, also retain any `unaddressed` priors that did NOT match a current ACR finding — surface those too in "Still Pending from Prior Review" so the author sees them again. (`acknowledged` and `rejected` priors without a current ACR match are silently dropped — the thread already speaks for itself.)

After this step you have:
- A reconciled triage list to drive the review template (Step 4).
- A list of `unaddressed` priors (matched + unmatched) to populate "Still Pending from Prior Review".
- A list of `rejected`-prior overrides to populate "False Positives Filtered".

---

## Step 4: Compose the Review

If 2a's `verdict` is `lgtm` AND there are no `unaddressed` priors to surface, write a short LGTM review using the template below (Findings and Still Pending sections omitted, Verdict = Approve) and skip to Step 5.

Otherwise, compose the review from the reconciled findings, grouped by Conventional Comments label so the overall review uses the same vocabulary as inline comments. Use this template (omit any section with no entries — no "None" placeholders):

```markdown
## Code Review: <PR title>

### Summary

<2-3 sentence summary of what the PR does and overall assessment>

### Findings

#### issue (blocking)

- **<file>:<line>** — issue (blocking): <subject>
  <1–3 sentences on the problem and the fix>

#### issue (non-blocking)

- **<file>:<line>** — issue (non-blocking): <subject>
  <discussion>

#### suggestion (non-blocking)

- **<file>:<line>** — suggestion (non-blocking): <subject>
  <discussion>

#### nitpick (non-blocking)

- **<file>:<line>** — nitpick (non-blocking): <subject>
  <discussion>

#### note (non-blocking)

<For out-of-scope observations or heads-ups not anchored to a specific line.>

- **<file>:<line>** — note (non-blocking): <subject>
  <discussion>

#### praise

<Only include if something is genuinely worth highlighting — don't fabricate.>

- **<file>:<line>** — praise: <subject>
  <one sentence on what's good>

### Still Pending from Prior Review

<Prior findings the author hasn't replied or reacted to. One-line nudges only — don't restate the discussion.>

- **<file>:<line>** — <subject> (still pending; raised previously, no response yet)

### False Positives Filtered

<ACR findings filtered as false positives, plus Step 3 overrides where the author previously rejected the issue.>

- **<file>:<line>** — ACR flagged: "<what ACR said>"
  Filtered because: <why, or "PR author previously rejected this (<rejection_signal>)">

### Verdict

<One of: **Approve**, **Request Changes**, **Comment Only**>
```

### Rules

- Use Conventional Comments labels in both inline and overall review; one decoration per comment.
- Be specific: reference exact files, lines, and code snippets; pair `issue` with a fix.
- When uncertain, use `question (non-blocking): ...` inline instead of asserting.
- Omit empty sections; if the PR is clean, just say LGTM.
- **Don't re-raise reconciled findings.** Step 3 `acknowledged` drops are silent. `rejected` overrides go to "False Positives Filtered" only. `unaddressed` priors go to "Still Pending from Prior Review" only.

### Verdict mapping

- Any `issue (blocking)` → **Request Changes**
- No blockers but `issue (non-blocking)` present → **Comment Only** (or **Request Changes** if you want them addressed before merge — your judgement)
- Only `suggestion` / `nitpick` / `note` / `praise` / "Still Pending" → **Approve**

A finding overridden to `false_positive` in Step 3 cannot be a blocker, so a PR whose only original blocker was previously rejected by the author lands on Approve / Comment Only naturally.

---

## Step 5: Present the Review

Display the overall review so the user can copy it if they want:

```
The overall review below is ready to paste into GitHub. Copy everything between the markers:

════════════════ REVIEW START ════════════════

<the review markdown>

════════════════ REVIEW END ══════════════════
```

Then list the inline comments that will be attached to specific lines if they choose to post directly. Include any reconciled finding where `in_diff == true` AND its classification maps to an inline-posted label per the table in Step 2 (`genuine`, `nitpick`, `praise`) AND was not dropped by Step 3. Show each as `path:line — <first line of comment_body>` so the CC label is visible in the preview.

If any inline-eligible findings have `in_diff == false`, mention them separately: "These findings reference lines outside the PR diff and will only appear in the overall review, not as inline comments: …"

Then ask the user:
1. Would you like to post this review directly via `gh` (overall comment + inline comments in one GitHub review)?
2. Would you like to modify anything first?
3. Or just copy the overall review manually? (Inline comments will be lost — they require API posting.)

### Posting directly

Use the GitHub Reviews API (not `gh pr review`, which lacks inline-comment support). One API call posts the overall body + every inline comment as a single review.

**Marker:** append `<!-- github-review-pr:v1 -->` (preceded by a blank line) to every inline `comments[].body` and to the overall `body`. Without this, future runs can't dedupe or honor rejection signals.

**SHA staleness check** — before building the payload, verify whether the PR has received new commits since ACR ran:
```bash
CURRENT_SHA=$(gh pr view <pr_number> --repo <owner>/<repo> --json headRefOid -q .headRefOid)
```
Compare to `branch_sha` from 2a:
- **Same SHA** → comments will land on current code. Proceed normally.
- **Different SHA** → PR HEAD has moved. Comments will still post correctly because we anchor them to `branch_sha` via `commit_id` (see below), but they'll appear marked as "outdated" on the GitHub UI. Surface this to the user before they confirm:
  > Note: the PR has received new commits since ACR ran (was at `<branch_sha[:7]>`, now at `<current_sha[:7]>`). Posting will anchor comments to the older commit so they reference the lines ACR analyzed; they'll appear as "outdated" on GitHub. Re-run the skill if you want comments against the latest HEAD instead.

1. Build the JSON payload. Use the `Write` tool to create `/tmp/pr-<pr_number>-review.json`:

   ```json
   {
     "commit_id": "<branch_sha from 2a>",
     "body": "<the overall review markdown from Step 4>\n\n<!-- github-review-pr:v1 -->",
     "event": "APPROVE | REQUEST_CHANGES | COMMENT",
     "comments": [
       {
         "path": "path/to/file.ts",
         "line": 42,
         "side": "RIGHT",
         "body": "<comment_body from triaged finding>\n\n<!-- github-review-pr:v1 -->"
       }
     ]
   }
   ```

   The `commit_id` is critical — without it, GitHub anchors comments to whatever the current HEAD is at posting time, which may have shifted line numbers since ACR analyzed the code. With `commit_id` set, GitHub interprets `line` values relative to that specific commit, so comments correctly reference the code ACR saw.

   Map the verdict from Step 4 to `event`: Approve → `APPROVE`, Request Changes → `REQUEST_CHANGES`, Comment Only → `COMMENT`.

   Include one `comments[]` entry for every finding that is inline-eligible per the Step 2 mapping (`genuine`, `nitpick`, `praise`) AND has `in_diff == true` AND was not dropped by Step 3 reconciliation. `side` is `RIGHT` for additions/modifications (the normal case); use `LEFT` only when commenting on a line removed by the PR. Skip findings with `in_diff == false` and any classification mapped to "summary only" / "filtered".

2. POST the review:

   ```bash
   gh api "repos/<owner>/<repo>/pulls/<pr_number>/reviews" \
     --method POST \
     --input /tmp/pr-<pr_number>-review.json
   ```

   `<owner>/<repo>` comes from the `repo` field in the devdash context.

3. If the API returns 422 with a message about an invalid `line` or position, one of the inline comments points outside the diff hunk. Re-check `in_diff` for each comment, drop the offending entry, note it in the response to the user, and retry.

4. On success, report the review URL from the API response so the user can verify it on GitHub.
