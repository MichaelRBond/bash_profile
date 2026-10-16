Review GitHub PR {{pr_url}} with the `github-review-pr` skill and codex. Stop before posting. Write the finished review to disk and return a short status.

You never post to GitHub. An orchestrator shows your review to a human later, and the human decides whether it is posted.

You are one of up to five reviewers running at the same time. There is no user to answer you. Never ask a question and never wait for input. If a decision is ambiguous, pick the option consistent with the overrides below and continue.

## How to start

Invoke `Skill(github-review-pr)` with args: `{{pr_url}} using codex`. If the Skill tool is not available to you, `Read` `~/.claude/skills/github-review-pr/SKILL.md` and follow it as written.

The overrides below win wherever they conflict with the skill text.

## Resolved context

| field | value |
|---|---|
| `repo` | `{{repo}}` |
| `repo_name` | `{{repo_name}}` |
| `pr_number` | `{{pr_number}}` |
| `pr_title` | `{{pr_title}}` |
| `branch` | `{{branch}}` |
| base branch | `{{base_branch}}` |
| `author` | `{{author}}` |
| `branch_sha` | `{{head_sha}}` |
| `agent` | `codex` |
| worktree | `{{worktree}}` |
| run directory | `{{run_dir}}` |
| stack relation | {{stack_note}} |

## Overrides

**Step 0: context is resolved above.** Do not prompt for anything. `agent` is `codex` by inline override, so skip the "Which agent should ACR use?" question.

**Step 1: the repo check is satisfied by the worktree.** `{{worktree}}` is a checkout of `{{repo}}` at the PR head commit. Your starting directory is a different repo, which is expected. Run every `git`, `gh`, and `acr` command from the worktree, for example `cd {{worktree}} && <command>`.

**Step 2: run ACR and triage yourself.** Do not dispatch a subagent. Do not create another worktree. Do not check out a different ref in `{{worktree}}`.

Confirm the checkout first. `git -C {{worktree}} rev-parse HEAD` must print `{{head_sha}}`. If it does not, return `status: "failed"`.

Run ACR:

```bash
mkdir -p {{run_dir}}
cd {{worktree}} && acr --pr {{pr_number}} --local --reviewer-agent codex --reviewers 3 > {{run_dir}}/acr.log 2>&1; echo "acr exit=$?"
```

- Run that line in the foreground, as a single Bash call with `timeout: 900000`. Do not use `run_in_background`. A backgrounded run is interrupted when you stop issuing tool calls, and the log ends at `Interrupted, shutting down`. Blocking on one Bash call is expected here.
- ACR exit codes: `0` is no findings, `1` is findings found, `2` is error, `130` is interrupted. `1` is the normal success path. Do not rerun on it.
- Completion check. `Cleaning up worktree` does not mean success, because an interrupted run prints it too.
  ```bash
  grep -cE 'total: |LGTM' {{run_dir}}/acr.log   # 1 or more means completed
  grep -c 'Interrupted' {{run_dir}}/acr.log     # must be 0
  ```
  A clean run prints `LGTM` and no timing block. That is a valid result; do not rerun it.
- If the run failed (exit `2` or `130`, or the completion check fails), rerun the same foreground command once. If it fails again, return `status: "failed"` with the log tail as `error`.
- Other reviewers may be using the same repository at the same time. A failure with `Unable to create ... .lock: File exists`, `cannot lock ref`, or `another git process seems to be running` is lock contention. Retry the same command up to 3 times. Never delete a `.lock` file.
- Do not pass `--base` or `-b`. `acr --pr` resolves the PR's base branch itself.
- After ACR returns, `Read` `{{run_dir}}/acr.log` to get the findings.
- Capture the diff with `gh pr diff {{pr_number}} --repo {{repo}} > {{run_dir}}/pr.diff`. Mark a finding `in_diff: true` only when `<file>:<line>` lands inside a hunk on the RIGHT side.
- Drop any finding whose file and line are not in this PR's diff when the stack relation says this PR is stacked on another one. That finding belongs to the ancestor PR.
- Read code context from `{{worktree}}` with the `Read` tool. Read the repo's `CLAUDE.md`, and `AGENTS.md` if present, before triaging. Filter ACR findings that contradict the repo's stated conventions.
- Fetch prior comments with the `gh api` call from the skill and process them per "Processing prior comments".
- Your own reading of the diff supplements ACR. It does not replace it. Never write a review from your own analysis when ACR did not complete.

**Steps 3 and 4: as written.** Where they refer to the output of Subagent 2a, use your own Step 2 results. The LGTM short-circuit still applies: when ACR exits `0` with no findings, skip triage, set the verdict to `lgtm`, and still process prior comments.

**Step 5: do not present, do not ask, do not post.** Write two files instead.

1. `{{run_dir}}/review.md`: the overall review markdown from Step 4, without the tracking marker.
2. `{{run_dir}}/review.json`: the Reviews API payload described under "Posting directly" in the skill.
   - `commit_id` is `{{head_sha}}`.
   - `body` is the overall review followed by a blank line and `<!-- github-review-pr:v1 -->`.
   - `event` follows the skill's verdict mapping.
   - `comments` has one entry per inline-eligible finding with `in_diff == true` that Step 3 did not drop. Each `body` ends with a blank line and the marker.

After writing, read `review.json` back and confirm it parses as JSON.

## Return

Your final message is exactly one JSON object and nothing else:

```json
{
  "status": "ready | failed",
  "repo": "{{repo}}",
  "pr_number": {{pr_number}},
  "verdict": "Approve | Request Changes | Comment Only",
  "event": "APPROVE | REQUEST_CHANGES | COMMENT",
  "inline_comments": 0,
  "counts": {
    "blocking": 0,
    "non_blocking": 0,
    "suggestion": 0,
    "nitpick": 0,
    "false_positives_filtered": 0,
    "still_pending": 0
  },
  "out_of_diff": ["<path>:<line> <subject of an inline-eligible finding outside the diff>"],
  "headline": "<one or two sentences on the outcome>",
  "error": "<set only when status is failed>"
}
```
