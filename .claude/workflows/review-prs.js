export const meta = {
  name: 'review-prs',
  description: 'Review each PR with the github-review-pr skill (ACR + codex) and post a comment-only review',
  whenToUse: 'Batch-review a list of GitHub PRs autonomously. Posts COMMENT-only reviews — never approves, never requests changes. Pass PR URLs via args to override the default list.',
  phases: [{ title: 'Review', detail: 'one agent per PR, one at a time' }],
}

const SKILL_PATH =
  '/Users/runwise/Documents/GIT/claude-plugin-labs/claude-plugin-labs/mbond/skills/github-review-pr/SKILL.md'

// Stable scratch dir, not a session scratchpad — this workflow is reused across sessions.
const SCRATCH = '/private/tmp/claude-501/review-prs'

const REPO_DIRS = {
  'v2-backend': '/Users/runwise/Documents/GIT/v2-backend/v2-backend',
  'data-pipeline-streaming':
    '/Users/runwise/Documents/GIT/data-pipeline-streaming/data-pipeline-streaming',
  'dev-env': '/Users/runwise/Documents/GIT/dev-env/dev-env',
}

// No baked-in default list, deliberately. A stale hardcoded list is a live weapon here:
// this workflow POSTS to GitHub, so a bare no-args run would fire reviews at whatever
// batch was last edited in. That happened — a PE-7430 list survived into a PE-4646 run
// and only the safety classifier stopped it. Always pass the PRs explicitly.
const DEFAULT_PRS = []

const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['repo', 'pr_number', 'status'],
  properties: {
    repo: { type: 'string' },
    pr_number: { type: 'integer' },
    pr_title: { type: 'string' },
    status: { enum: ['posted', 'failed'] },
    review_url: { type: 'string', description: 'html_url from the reviews API response' },
    event_posted: { type: 'string', description: 'must be COMMENT' },
    inline_comments: { type: 'integer' },
    counts: {
      type: 'object',
      additionalProperties: false,
      properties: {
        blocking: { type: 'integer' },
        important: { type: 'integer' },
        suggestion: { type: 'integer' },
        nitpick: { type: 'integer' },
        false_positives_filtered: { type: 'integer' },
        still_pending: { type: 'integer' },
      },
    },
    headline: { type: 'string', description: '1-2 sentence summary of the review outcome' },
    error: { type: 'string', description: 'set only when status=failed' },
  },
}

function parsePr(entry) {
  if (entry && typeof entry === 'object') {
    if (entry.url) return { ...parsePr(entry.url), repost: !!entry.repost }
    const repo = entry.repo
    const number = Number(entry.number ?? entry.pr_number)
    return { repo, number, repost: !!entry.repost }
  }
  const m = String(entry).match(/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)/)
  if (m) return { repo: `${m[1]}/${m[2]}`, number: Number(m[3]) }
  const s = String(entry).match(/^([^/]+)\/([^/#]+)(?:#|\/pull\/)(\d+)$/)
  if (s) return { repo: `${s[1]}/${s[2]}`, number: Number(s[3]) }
  throw new Error(`cannot parse PR reference: ${entry}`)
}

// args can arrive as a real array, a JSON-encoded string, a bare string (one PR ref),
// or {prs: [...], concurrency: N} to control how many PRs review at once.
function normalizeArgs(a) {
  if (Array.isArray(a)) return a.length ? a : null
  if (typeof a === 'string' && a.trim()) {
    const t = a.trim()
    if (t.startsWith('[') || t.startsWith('{')) return normalizeArgs(JSON.parse(t))
    return t.split(/[\s,]+/).filter(Boolean)
  }
  if (a && typeof a === 'object') {
    if (Array.isArray(a.prs)) return a.prs.length ? a.prs : null
    if (a.number || a.pr_number || a.url) return [a]
  }
  return null
}

function requestedConcurrency(a) {
  const raw = typeof a === 'string' && a.trim().startsWith('{') ? JSON.parse(a) : a
  const n = raw && !Array.isArray(raw) && typeof raw === 'object' ? Number(raw.concurrency) : NaN
  return Number.isFinite(n) && n >= 1 ? Math.floor(n) : null
}

const input = normalizeArgs(args) || DEFAULT_PRS
if (!input.length) {
  throw new Error(
    'no PRs given. Pass args as ["<pr-url>", ...] or {prs: [...], concurrency: N}. ' +
      'This workflow posts reviews to GitHub, so it will not fall back to a default list.',
  )
}
const prs = input.map(parsePr).map((pr) => {
  const repoName = pr.repo.split('/')[1]
  const dir = REPO_DIRS[repoName]
  if (!dir) throw new Error(`no local clone configured for ${pr.repo} (add it to REPO_DIRS)`)
  return { ...pr, repoName, dir, url: `https://github.com/${pr.repo}/pull/${pr.number}` }
})

function prompt(pr) {
  const slug = `${pr.repoName}-${pr.number}`
  return `Review GitHub PR ${pr.url} end to end using the \`github-review-pr\` skill, then POST the review yourself.

You are running fully autonomously. Never ask a question, never pause for confirmation, never wait for input. There is no user to answer you. If a decision is ambiguous, pick the option consistent with the overrides below and continue.

## How to start

Invoke \`Skill(github-review-pr)\` with args: \`${pr.url} using codex\`. If the Skill tool is not available to you, \`Read\` ${SKILL_PATH} and follow it as written.

## Overrides — these win over the skill text wherever they conflict

**Step 0 — context is already resolved. Do not prompt for anything.**
- \`repo\` = \`${pr.repo}\`, \`repo_name\` = \`${pr.repoName}\`, \`pr_number\` = \`${pr.number}\`.
- \`agent\` = \`codex\`. This is an inline override per Step 0 case 1 — SKIP the "Which agent should ACR use?" prompt entirely. Do not ask it, do not print it, do not treat its absence as blocking.
- Fill \`pr_title\`, \`branch\`, \`author\` with:
  \`gh pr view ${pr.number} --repo ${pr.repo} --json number,title,headRefName,author\`

**Step 1 — repo check is satisfied by the local clone at \`${pr.dir}\`.** Your cwd is a different repo; that is expected. Work out of \`${pr.dir}\` and do not stop on the Step 1 check.

**Step 2 — run ACR and triage yourself. Do NOT dispatch a subagent, do NOT create a git worktree.**
Other agents are using \`${pr.dir}\` concurrently, so treat it as read-only apart from \`git fetch\`. Never run \`git checkout\`, \`git switch\`, \`git reset\`, or \`git worktree add\` there. (\`acr --pr\` makes its own temp worktree; that is fine and does not touch the clone's working tree.)

\`\`\`bash
mkdir -p ${SCRATCH}
cd ${pr.dir}
git fetch origin <branch>
BRANCH_SHA=$(git rev-parse origin/<branch>)
acr --pr ${pr.number} --local --reviewer-agent codex --reviewers 3 > ${SCRATCH}/acr-${slug}.log 2>&1; echo "acr exit=$?"
\`\`\`
- These PRs are stacked (one PR's base is another PR's head). \`acr --pr N --local\` resolves the PR's real base branch itself — do NOT pass \`--base\`/\`-b\` or any target-branch flag, do NOT diff against \`main\`/\`master\`, and do NOT report findings that belong to an ancestor PR in the stack. If a finding's file+line is not in \`gh pr diff\` output for THIS PR, it belongs to an ancestor — drop it.
- **You are very likely running concurrently with other review agents against this same clone.** Several PRs in a stack share one local repo, and both your \`git fetch\` and \`acr\`'s internal \`git worktree add\` take short locks on \`${pr.dir}/.git\`. If any git or acr step fails with \`Unable to create ... .lock: File exists\`, \`cannot lock ref\`, or \`another git process seems to be running\`, that is transient contention, NOT a real failure: retry the same command up to 3 times before concluding anything. Never delete a \`.lock\` file — another agent is mid-write.
- **Run that \`acr\` line in the FOREGROUND, as a single Bash call with \`timeout: 900000\` (15 min).** Do NOT use \`run_in_background\`. Backgrounding it is what destroyed the ACR pass on 5 of 8 PRs across two prior runs: the harness SIGINTs the background shell whenever the agent stops issuing tool calls, and the log dies at \`[W] Interrupted, shutting down...\` with \`Reviewer #N failed (exit -1)\`. A completed run takes 6–8 min, well inside the 15-min timeout. Blocking on one Bash call is expected and correct here — do not try to keep busy in parallel.
- After it returns, \`Read\` the log file to get the findings.

- **Completion check — \`Cleaning up worktree\` does NOT mean success.** An interrupted run prints that line too. The discriminating marker is the timing summary:
  \`\`\`bash
  grep -cE 'total: |LGTM' ${SCRATCH}/acr-${slug}.log  # >=1 = completed
  grep -c 'Interrupted' ${SCRATCH}/acr-${slug}.log    # must be 0
  \`\`\`
  A real ACR pass has \`Interrupted\` absent AND ends one of two ways: a findings run prints a \`Timing:\` block with \`total: Xm Ys\`, or a clean run prints \`✓ LGTM (3/3 reviewers)\` and **no** timing block. Do not treat a bare LGTM as incomplete — it is a valid result (ACR exits 0), and rerunning it just burns a second pass. If the check fails, rerun the same foreground command once; if it fails again, return \`status: "failed"\` with the log tail as the error — do NOT post a review built from your own analysis alone.
- Your own reading of the diff **supplements** ACR, it does not replace it. Never post a review that says "ACR did not finish, so these findings are my own". Get a real ACR pass first, then add your own findings on top.
- **ACR exit codes: \`0\` = no findings, \`1\` = findings found, \`2\` = error, \`130\` = interrupted.** \`1\` is the normal success path — do NOT treat it as a failure and do NOT rerun on it. Only \`2\`/\`130\`, or a log with no parseable findings section, count as a failure: relaunch once the same way, and if it fails again return \`status: "failed"\` with the error and stop.
- If you need cross-repo context, the only local clones are \`${REPO_DIRS['data-pipeline-streaming']}\`, \`${REPO_DIRS['v2-backend']}\`, and \`${REPO_DIRS['dev-env']}\` (note the doubled path segment). Don't probe for other paths.
- Carry \`BRANCH_SHA\` through as \`branch_sha\`.
- \`in_diff\` validation: \`gh pr diff ${pr.number} --repo ${pr.repo} > ${SCRATCH}/pr-${slug}.diff\`, then mark a finding \`in_diff: true\` only when \`<file>:<line>\` lands inside a hunk on the RIGHT side.
- To read code context, use \`git show $BRANCH_SHA:<path>\` from \`${pr.dir}\` — NOT the \`Read\` tool. The clone's working tree is on some other branch, so \`Read\` would show the wrong revision.
- Read \`git show $BRANCH_SHA:CLAUDE.md\` (and \`AGENTS.md\` if present) before triaging, and use the repo's stated conventions to filter ACR findings that contradict them.
- Fetch prior comments with the \`gh api .../pulls/${pr.number}/comments\` call from the skill and process them per "Processing prior comments".

**Steps 3 and 4 — as written** (reconcile against prior comments, compose the review with Conventional Comments labels).

**Step 5 — do not present, do not ask. Post directly, comment-only.**
- Ignore the skill's "Verdict mapping" for the posted event: \`"event"\` is **always** \`"COMMENT"\`. Never \`APPROVE\`, never \`REQUEST_CHANGES\`, regardless of blocking findings.
- Write the review's \`### Verdict\` line as \`**Comment Only**\`.
- Keep blocking findings in the review body and inline — forcing COMMENT changes the review event only, not the content or severity labels.
- Append \`<!-- github-review-pr:v1 -->\` (after a blank line) to the overall \`body\` and to every inline \`comments[].body\`.
- Set \`commit_id\` to \`$BRANCH_SHA\`. Do the SHA staleness check, but instead of surfacing it to a user, note it in your returned \`headline\`.
${pr.repost ? `- **REPOST MODE — the idempotency guard below is DISABLED for this run.** A prior review from this skill already exists on this PR at this same commit, but it was built without a real ACR pass and is being deliberately superseded. Post a new review regardless of what the guard finds. Open the review body with this line, verbatim, before the \`## Code Review:\` heading:
  \`> Supersedes the earlier review on this commit, which was posted without a completed ACR pass.\`
  Still reconcile against that prior review's inline comments per Step 3 — do not re-raise findings it already made unless ACR contradicts them.
  Read the prior review first so you can reconcile against it:
  \`gh api "repos/${pr.repo}/pulls/${pr.number}/reviews" --jq '.[] | select(.body != null and (.body | contains("github-review-pr:v1"))) | "\\(.id) \\(.commit_id) \\(.html_url)"'\`` : `- **Idempotency guard (this may be a retry of a killed attempt).** Immediately before POSTing, check for a review this skill already posted against the same commit:
  \`gh api "repos/${pr.repo}/pulls/${pr.number}/reviews" --jq '.[] | select(.body != null and (.body | contains("github-review-pr:v1"))) | "\\(.id) \\(.commit_id) \\(.html_url)"'\`
  If a match has \`commit_id == $BRANCH_SHA\`, a prior attempt already posted this review — do NOT post again. Return \`status: "posted"\` with that \`html_url\` and say so in \`headline\`.`}
- Write the payload with the \`Write\` tool to \`${SCRATCH}/pr-${slug}-review.json\`, then:
  \`gh api "repos/${pr.repo}/pulls/${pr.number}/reviews" --method POST --input ${SCRATCH}/pr-${slug}-review.json\`
- On a 422 about an invalid \`line\`/\`position\`, drop the offending inline comment and retry — up to 3 POST attempts. If all 3 fail, retry once with \`comments: []\` so the overall review still lands, and say so in \`headline\`.

Return the structured result. \`review_url\` is \`html_url\` from the POST response.`
}

// Wall clock is set by the SLOWEST single PR once they run concurrently, not by the sum.
// Measured at 3-way: ~13.8 min/PR (acr 5-7 min foreground + agent triage/post). So 8-way
// lands ~15-18 min if nothing contends. Override with {prs: [...], concurrency: N}.
// The runtime caps real parallelism at min(16, cores-2) = 12 on this machine regardless.
// An earlier note here blamed concurrency for a 7.2 h run; that run was actually slow
// because acr ran in the background and kept getting SIGINT'd — see the ACR block above.
const BATCH = requestedConcurrency(args) || 1
const results = []
log(`${prs.length} PR(s), ${BATCH} at a time${BATCH >= prs.length ? ' (all concurrent)' : ''}`)
for (let i = 0; i < prs.length; i += BATCH) {
  const batch = prs.slice(i, i + BATCH)
  log(
    `batch ${Math.floor(i / BATCH) + 1}/${Math.ceil(prs.length / BATCH)}: ${batch
      .map((p) => `${p.repoName}#${p.number}`)
      .join(', ')}`,
  )
  const batchResults = await parallel(
    batch.map(
      (pr) => () =>
        agent(prompt(pr), {
          label: `review:${pr.repoName}#${pr.number}`,
          phase: 'Review',
          schema: RESULT_SCHEMA,
        }),
    ),
  )
  batchResults.forEach((r, idx) => {
    const pr = batch[idx]
    results.push(
      r || {
        repo: pr.repo,
        pr_number: pr.number,
        status: 'failed',
        error: 'agent returned no result (died or was skipped)',
      },
    )
  })
}

const posted = results.filter((r) => r.status === 'posted')
const failed = results.filter((r) => r.status !== 'posted')
log(`done: ${posted.length} posted, ${failed.length} failed`)
return { posted, failed, results }
