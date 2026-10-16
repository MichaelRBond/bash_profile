---
name: consider-feedback
description: "Use when you want feedback weighed against the code before acting on it — provided either as plain text (a colleague's notes, a self-review before any PR exists) or as a URL to a GitHub PR/issue thread, pasted in your message or after /consider-feedback. Triggers: 'consider this feedback', 'address this review', 'what do you think of these comments', or feedback text / a GitHub pull/issue/comment URL handed over for evaluation. For feedback you want verified, not blindly applied."
---

# Consider Feedback

Take feedback — pasted as plain text, or fetched from a GitHub PR/issue URL — evaluate each point **on its merits against the actual code**, then implement the points you verify as valid, commit and push them, draft replies, and ask before acting on anything disputed or uncertain.

The value here is verification, not compliance. Feedback is a set of claims to check — some right, some wrong, some partly right. Never implement a point you have not confirmed in the code.

## Prerequisites

- `gh` CLI authenticated for the target repo — needed only for the GitHub-URL input mode (below). Plain-text feedback needs no `gh`.
- **If `superpowers:receiving-code-review` is available, use it** for the evaluation discipline — this skill's job is to fetch the feedback and orchestrate; that skill sharpens how you weigh it. If it's not available, the evaluation prompt below is self-contained.

## Step 0: Get the feedback

Feedback arrives one of two ways. Determine which from the invoking message (both work conversationally or after `/consider-feedback`):

**Mode A — plain text.** The feedback is written directly in the message: a colleague's notes, a self-review, pre-PR review before any PR or thread exists. Use it as given — **skip Step 1**. Distill it into a numbered list of discrete points and go to Step 2. Evaluate against the code in the current working tree / branch. A pasted **non-GitHub URL** falls here: this skill doesn't fetch it — ask the user to paste the feedback text, then treat it as Mode A.

**Mode B — a GitHub URL or reference.** Fetch it in Step 1. Parse:

| Input | Meaning |
|---|---|
| `https://github.com/<owner>/<repo>/pull/<n>` | whole PR thread |
| `…/pull/<n>#discussion_r<id>` | one inline (diff) review comment |
| `…/pull/<n>#issuecomment-<id>` | one conversation comment |
| `…/pull/<n>#pullrequestreview-<id>` | one review (summary + its inline comments) |
| `https://github.com/<owner>/<repo>/issues/<n>` (± `#issuecomment-<id>`) | issue thread or one comment |
| `<owner>/<repo>#<n>` | short form |
| bare `<n>` | derive repo via `gh repo view --json nameWithOwner -q .nameWithOwner` |

If an anchor (`#…-<id>`) is present, **focus on that specific comment/thread** but still read enough surrounding context to judge it.

**If the message has neither feedback text nor a resolvable reference**, ask for the feedback (paste the text, or give a PR/issue URL). Don't guess. If it has both a URL and its own substantive feedback text, ask which to treat as the source.

## Step 1: Fetch the complete thread (Mode B only)

Under-fetching is the common failure — a PR carries feedback on **three** surfaces; get all of them (or the single comment if an anchor was given). Batch these:

```bash
# Conversation (issue-level) comments
gh api "repos/<owner>/<repo>/issues/<n>/comments?per_page=100" \
  --jq '[.[]|{id,user:.user.login,body,reactions:(.reactions|del(.url))}]'
# Inline review comments (anchored to diff lines)
gh api "repos/<owner>/<repo>/pulls/<n>/comments?per_page=100" \
  --jq '[.[]|{id,in_reply_to_id,user:.user.login,path,line,body}]'
# Review summaries + verdicts
gh api "repos/<owner>/<repo>/pulls/<n>/reviews?per_page=100" \
  --jq '[.[]|{id,user:.user.login,state,body}]'
```

For an **issue** URL, fetch `gh issue view <n> --repo <owner>/<repo> --comments` (only the issue-comments call applies). For a single-comment anchor, fetch that id directly, e.g. `gh api repos/<owner>/<repo>/pulls/comments/<id>`.

Also read the PR/issue itself for context: `gh pr view <n> --json title,body,headRefName,files` (or `gh issue view`). Distill the feedback into a numbered list of discrete points before evaluating.

## Step 2: Evaluate each point (the core)

Apply this to every point. It is the contract for the output — a verdict + evidence per point, not a general impression.

```
Evaluate the following feedback critically and on its merits. Do not assume it is
correct; do not assume it is wrong. Treat each point as a claim to verify.

For each point:
- Verify against the actual code — read the relevant files, cite file:line evidence.
- Give a verdict: valid / invalid / partially valid / needs clarification, with the
  facts that support it.
- Where you disagree, say so plainly and show the evidence. Don't agree to be
  agreeable; don't dismiss without proof.

Ground every conclusion in verified facts, not assumptions. Research first; then ask
me only what the code can't answer. Surface genuine concerns before acting on them.
```

Read the actual files (in parallel) before judging any point. A verdict without a `file:line` citation is an opinion, not a finding.

## Step 3: Act on the verdicts

| Verdict | Action |
|---|---|
| **valid** — verified in code, low risk, unambiguous | Implement it. |
| **partially valid** | Implement the part you verified; note what you did not. |
| **invalid** | Do not change code. Draft an evidence-backed reply in Step 5. |
| **needs clarification / you disagree / risky / ambiguous** | Do **not** implement. Present the verdict + evidence and **ask the user first**. |

**Hard rule:** never implement a point you have not verified against the code, and never implement a disputed or risky point without the user's go-ahead. When a fix touches a documented contract, a public API, or behavior on a path you can't fully trace, treat it as "ask first" regardless of how the reviewer framed it.

**Important:** do NOT worry about existing PR approvals or branch protections. Correctness of the code matters more than keeping an existing approval. If a new approval is needed, it will be requested.

### Decide whether to stop

Put every point in one of two buckets:
- **Act:** valid, partially valid (the verified part), or invalid (reply only).
- **Ask:** needs clarification, disputed, risky, or touches a contract or public API.

If the Ask bucket is empty, go through Steps 4 to 6 without stopping. Do not end the turn with an offer such as "Want me to push?" Invoking this skill authorizes you to commit and push to the PR branch.

If the Ask bucket is not empty, still do the Act points first (Steps 4 to 6). Then present the Ask points and wait for answers.

## Step 4: Commit and push

Run the relevant tests and build. If they fail, stop and report the failure; it counts as an Ask point.

Then commit and push without asking, with these limits:
- The current branch must match the PR's `headRefName`. If it doesn't, ask.
- Never push to the default branch. Never force push.
- Stage only files you changed for this feedback. Leave unrelated working-tree changes alone.
- Commit messages follow the repo's CLAUDE.md and the global Git conventions.
- Mode A with no PR or upstream branch: commit, do not push, and say so.

## Step 5: Draft replies

Draft a reply for every point, after pushing so fixed points can cite the commit SHA.
- Valid: what changed and the short SHA.
- Partially valid: what changed and what didn't, with the reason.
- Invalid: the evidence, stated plainly.
- Ask: skip until the user answers.

Write every draft to the **Writing Style** rules in `~/.claude/CLAUDE.md`. Before presenting, grep the drafts for em dashes and the listed filler words, then re-read once for figurative language.

Present each draft as plain text under a heading that names the comment (author and URL or id). Do not use block quotes. Do not post drafts to GitHub unless the user asks.

## Step 6: Report

Report in this order:
1. Pushed branch and commit SHA (or why nothing was pushed).
2. Test and build results.
3. Per point: the verdict, the `file:line` evidence, what you did, and the drafted reply.
4. Ask points last, together, so they are easy to answer.

Don't post comment replies to GitHub unless the user asks; pushing commits is expected.

## Rules

- **Verification before action.** Read the code for every point; cite `file:line`. No citation → it's an opinion, hold it.
- **Fetch all three comment surfaces** (issue comments, inline review comments, reviews), not just the one that's easy.
- **Implement valid, ask on disputed.** Never implement an unverified or contested point without approval.
- **Push when there are no Ask points; ask when there are.** Act points are committed and pushed either way.
- **Draft a reply for every point** in the user's Writing Style, as plain text.
- **Push back with evidence, not deference.** Wrong feedback gets a factual reply, not silent compliance or silent dismissal.
- **Two input modes.** Plain-text feedback is used directly (no fetch); only a GitHub PR/issue URL triggers Step 1. Non-GitHub URLs aren't fetched — ask for the text.
- **Defer to `receiving-code-review`** for evaluation rigor when it's installed.

## Common mistakes

| Mistake | Fix |
|---|---|
| Assuming feedback must be a URL | Accept plain-text feedback directly (Mode A) — no fetch, evaluate against the working tree |
| Fetching only inline comments (or only the conversation) | Pull issue comments, PR review comments, and reviews |
| Implementing every point to be agreeable | Verify each against code; some feedback is wrong |
| Verdict with no `file:line` evidence | Read the file and cite it, or mark it "needs clarification" |
| Silently dropping feedback you disagree with | Draft an evidence-backed reply so the disagreement is explicit |
| Applying a risky/contract-changing fix on the reviewer's say-so | Move it to "ask first" and present the evidence |
| Treating a pasted non-GitHub URL as fetchable | Out of scope — ask the user to paste the feedback text |
| Stopping to ask "should I push?" when the Ask bucket is empty | Invoking the skill is the authorization; push |
| Drafting replies only for invalid points | Draft one for every answered point |
