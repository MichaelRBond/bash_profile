---
name: github-review-multi-pr
description: Use when the user invokes /github-review-multi-pr with several GitHub PR URLs and wants every PR reviewed in parallel, then wants to post, edit, or skip each review one at a time. Nothing is posted without the user's decision on that PR. For autonomous comment-only batch posting, the review-prs workflow applies instead.
argument-hint: <PR URLs separated by spaces, commas, or bullets>
disable-model-invocation: true
---

# /github-review-multi-pr

Review several GitHub PRs in parallel with the `github-review-pr` skill and codex. Hold every result until all reviews are finished. Then walk the user through the reviews one at a time.

You are the orchestrator. Reviewer subagents do the reviewing. Only you post to GitHub, and only after the user decides on that PR.

## Input

$ARGUMENTS

---

## Step 1: Parse the PR list

- Extract every match of `github.com/<owner>/<repo>/pull/<n>` from the input. Bullets, commas, markdown link syntax, and trailing segments such as `/files` or `#discussion_r123` are noise.
- Drop duplicates. Keep first-seen order.
- If the input has no PR URL, ask the user for the PR URLs and stop.
- List any other URL in the input as ignored when you print the pre-flight summary.

The PRs may be unrelated, in different repos, or stacked on each other. Treat each one independently unless Step 2 finds a stack relation.

---

## Step 2: Pre-flight

Run this step yourself, one PR at a time. Parallel git commands against the same clone collide on `.git` locks.

1. Confirm `acr`, `gh`, and `codex` are on PATH, and that `$GITHOME` is set. `$GITHOME` is the parent directory of the local repos. If any of these is missing, tell the user and stop.
2. Create the run directory and note the path it prints. Each PR gets `<run_dir>/<repo_name>-<n>/`.
   ```bash
   mktemp -d "${TMPDIR:-/tmp}/review-multi-pr.XXXXXX"
   ```
   Shell variables do not persist between Bash calls. Use the literal paths for the run directory, clones, and worktrees in every later command.
3. For each PR, fetch its metadata:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json number,title,headRefName,headRefOid,baseRefName,author,state,isDraft
   ```
4. Resolve the local clone at `$GITHOME/<repo_name>/<repo_name>`. Confirm that `git -C <clone> remote get-url origin` names `<owner>/<repo>`.
5. Create a worktree in that repo, checked out at the PR head commit:
   ```bash
   WT="$GITHOME/<repo_name>/.worktrees/review-pr-<n>-ro"
   git -C <clone> fetch origin pull/<n>/head
   git -C <clone> worktree add --detach "$WT" <headRefOid>
   ```
   The checkout is detached because the PR branch is often checked out in another worktree already, and `pull/<n>/head` also resolves fork PRs. If `$WT` already exists from an earlier run, reuse it with `git -C "$WT" checkout --detach <headRefOid>`.
6. Record stack relations. PR B is stacked on PR A when both are in the same repo and B's `baseRefName` equals A's `headRefName`.
7. Keep a record per PR: clone path, worktree path, run directory, the metadata from item 3, and its stack relation. Steps 3, 5, and 6 use it.

A PR that fails item 3, 4, or 5 is marked `failed` with the error text. It gets no reviewer in Step 3. Continue with the other PRs.

Print one line per PR: `<owner>/<repo>#<n>`, title, state, worktree path or failure reason.

---

## Step 3: Dispatch reviewers, at most 5 running

1. Read `reviewer-brief.md` in this skill's directory. It is the prompt template for one reviewer.
2. For each PR that passed pre-flight, fill every `{{placeholder}}` from the table below and dispatch one `Agent` call with `subagent_type: "general-purpose"`.
3. Dispatch the first 5, or fewer, in a single message.
4. Each time a reviewer finishes and undispatched PRs remain, dispatch the next one. The count of running reviewers never exceeds 5.

| placeholder | source |
|---|---|
| `{{pr_url}}` | `https://github.com/<owner>/<repo>/pull/<n>` |
| `{{repo}}` | `<owner>/<repo>` |
| `{{repo_name}}` | `<repo>` |
| `{{pr_number}}` | `number` |
| `{{pr_title}}` | `title` |
| `{{branch}}` | `headRefName` |
| `{{base_branch}}` | `baseRefName` |
| `{{author}}` | `author.login` |
| `{{head_sha}}` | `headRefOid` |
| `{{worktree}}` | the worktree path from Step 2 |
| `{{run_dir}}` | `<run_dir>/<repo_name>-<n>` |
| `{{stack_note}}` | `stacked on #<a> (base branch <baseRefName>)`, or `none` |

Each reviewer writes its review to the PR's run directory and returns one JSON status object. Record that object for Step 5. Take the JSON object from the reply even when a code fence or other text surrounds it. Mark the PR `failed` when the reply has no such object or the object says `"status": "failed"`. Do not re-run a failed reviewer on your own. The user chooses in Step 5.

---

## Step 4: Hold every result until all reviewers have finished

While any reviewer is running or undispatched, your only output is a one-line progress count, for example `3 of 7 reviews done`. The total is the number of PRs that passed pre-flight.

During this step:

- Do not read any `review.md` or `review.json`.
- Do not print a verdict, a headline, a finding, or a failure reason.
- Do not ask the user anything about a finished review.

The user steps through reviews only after the last reviewer has returned.

---

## Step 5: Walk through the reviews one at a time

Present the PRs in input order, with one exception: a stacked PR comes after the PR it is stacked on. `<N>` counts every PR from Step 1, including failed ones.

For each PR, in turn:

1. Read `<run_dir>/<repo_name>-<n>/review.md` and `review.json`.
2. Print a header: `Review <i> of <N>`, `<owner>/<repo>#<n>`, title, PR URL, verdict, finding counts, and the stack relation if there is one.
3. Present the review the way Step 5 of `github-review-pr` does:
   - the overall review between the `REVIEW START` and `REVIEW END` markers
   - the inline comments that would be attached, one `path:line` and first body line each
   - the findings outside the diff that appear only in the overall review
4. Ask the user to choose **Post**, **Modify**, or **Skip**. Then stop and wait for the answer.
5. Act on the answer:
   - **Post**: run the posting steps below, then report the review URL.
   - **Modify**: apply the user's edits to both `review.md` and `review.json` in place, present the PR again, and ask again.
   - **Skip**: post nothing for this PR.
6. Move to the next PR only after this PR is posted or skipped.

For a `failed` PR, show the error in its turn and ask **Retry** or **Skip**. On Retry:

1. Run Step 2 items 3 to 5 for that PR again. This creates the worktree when pre-flight failed, and moves an existing worktree to the current PR head.
2. If that fails again, show the error and ask again.
3. Otherwise dispatch one reviewer for that PR and wait for it.
4. Present its result before moving to the next PR.

### Posting

`review.json` is the complete payload for the GitHub Reviews API. It already carries `commit_id`, `event`, the inline comments, and the `<!-- github-review-pr:v1 -->` marker on every body.

1. Check whether the PR head moved since the review ran:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json headRefOid -q .headRefOid
   ```
   If it differs from `commit_id`, tell the user that the comments will be anchored to the older commit and will show as outdated on GitHub. Ask whether to post anyway.
2. Post the review:
   ```bash
   gh api "repos/<owner>/<repo>/pulls/<n>/reviews" --method POST --input <run_dir>/<repo_name>-<n>/review.json
   ```
3. On a 422 about an invalid `line` or `position`, remove the offending entry from `comments` in `review.json`, tell the user which one, and retry.
4. Report `html_url` from the response.

---

## Step 6: Wrap up

1. Print a table with one row per PR: PR, verdict, and outcome (`posted` with the review URL, `skipped`, or `failed`).
2. Remove every review worktree from the per-PR records, including ones reused from an earlier run and ones whose PR was skipped or failed:
   ```bash
   git -C <clone> worktree remove "$WT"
   ```
   Do not pass `--force`. If git refuses, leave the worktree in place and report its path.
