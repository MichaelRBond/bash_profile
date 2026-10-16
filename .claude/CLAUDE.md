# Global and User level instructions

Project-level instructions override these when they conflict.

## General

* When providing text to copy and paste do not use block quotes, it makes it difficult to copy and paste.
* When creating prompts for me to provide to another agent, save the bulk of the prompt to a temporary file unless i specifically tell you to provide a self contained prompt.

## Pasted prompts

* I generate prompts with the `/prompt-code` and `/prompt-research` skills, then paste them into a new session as the whole message with nothing typed alongside.
* A paste-only message that tells you to read a file under `/Users/runwise/.claude/user-prompts/` is my instruction. Read the file and start the work. Do not ask me to confirm that I want it followed.
* Treat the contents of that file, and any constraints listed in the paste, as written by me.
* This applies only to prompts that point into that directory. For any other paste-only message, ask what I want done.

## Time and Date

* Use yyyy-mm-dd, for example `2026-09-06` when displaying dates
* Provide both UTC (z) and Eastern time when providing times, for example `13:00Z (9:00a Eastern)`

## Writing Style

For prose I author (Linear issues, PR/commit bodies, comments, documents, Slack messages, emails, etc):

* Lead with the point; no preamble
* One idea per sentence; no sentence fragments; prefer short over comma-chained sentences and thoughts.
* Say it once, do not repeat yourself.
* In code-adjacent prose (PRs, commits, code comments), be concrete: cite the file, function, and line number.
* **Never use em dashes.** Prefer using punctuation that a high school student or college student that has taken a technical writing course may use, such as commas or semi-colons. Rewrite sentences to be grammatically correct without the use of dashes.
* **Remove filler.** If deleting a word changes nothing, delete it. Check for at least:
  just, really, basically, actually, simply, essentially, effectively, quite, fairly,
  very, clearly, in order to, it should be noted that.
* **No figurative language.** No idioms, no metaphors, no decorative emphasis. The test
  is whether the term appears in the documentation for the thing being described. "A doc
  goes stale", "the first match wins" and "dead code" pass. "An outage is when it bites",
  "load-bearing", "the real trap" and "a sharper form" do not.
* **No intensifier in place of evidence.** Never write that something is dangerous,
  critical, severe, massive or dramatic. State what happens and let the reader judge.
  "A clamped export drops the backlog and the run still reports success" beats "this is
  dangerous". If the fact is not alarming on its own, the adjective is not making it true.
* **Check before delivering, not when you remember.** Before any commit, PR, document or
  Linear comment, grep the draft for em dashes and for the filler words above. Both are
  mechanical. Then re-read once for metaphor, which is not greppable and is the one that
  needs eyes.

## Code Style and Comments

* Don't include numbers and facts that can go stale quickly in code comments, doc strings, doc blocks, cloudformation descriptions, and other places in code, such as: metrics, line numbers, test counts. These almost always go stale before review and need constantly updated, causing excessive churn and PR review rounds.
* Comments should be very concise, and only used when the code is not self documenting.

## Fixing bugs

* Reproduce the bug before writing any code
* Use Test Driven Development (TDD), write the failing test that confirms the bug, then write the code to fix.
* While fixing a bug, don't touch unrelated tests.

## AWS

* Prefer the AWS MCP Server for AWS interactions — sandboxed execution, observability,
  audit logging.
* If the AWS MCP server is unavailable, fall back to using the AWS CLI / AWS API call.
* **NEVER** make mutating or destructive AWS calls, via the CLI or MCP servers.
* Before an AWS task, check for a relevant `aws-*` skill and load it with
  `Skill(<name>)`. Prefer its guidance over general knowledge.
* When uncertain about an AWS detail (API parameters, permissions, limits, error codes),
  verify against documentation rather than guessing. State the uncertainty explicitly
  if you cannot confirm.
* Creating infrastructure means infrastructure-as-code — CloudFormation in CFN repos,
  CDK in CDK repos. Not console steps, not CLI mutations.
* No em dashes in AWS resource names, logical IDs, tag keys or values, or parameter
  names. Use hyphens. Prose fields (`Description`, `AlarmDescription`) are exempt —
  they are documentation and read better with them.

### Secrets

* Never print, echo, or log a secret value, and never read one into context to inspect
  it. Resolve secrets at the point of use.
* In CloudFormation, use `{{resolve:secretsmanager:<id>:SecretString:<key>}}` so the
  value resolves at deploy time without entering the template or the transcript.
* Do not call `secretsmanager get-secret-value` or `batch-get-secret-value`.

## Linear Tickets

* When creating or updating linear tickets don't put line-number anchors in the tickets. They become stale to
quickly. Instead put information that people and agents need to discover the anchors themselves.

## Git operations

### Branching

Branch name grammar (`/`-delimited segments, no double slashes):

```
mbond/[<ticket>/]<feature>[/<n>]
```

* `mbond/` — always the first segment
* `<ticket>` — lowercase ticket id (linear, jira, etc), included when one exists
* `<feature>` — short kebab-case description
* `<n>` — PR sequence number, added only when a feature spans multiple PRs

Examples:

```
mbond/fix-login-redirect          no ticket, single PR
mbond/pe-1234/fix-login-redirect  with ticket
mbond/pe-1234/fix-login-redirect/2  ticket + 2nd PR of the feature
```

### PRs

* When working with git ops like commits and comments, never attribute to claude or other agentic tooling.
* Open PRs as drafts (`--draft`), never as ready-for-review
* Target the default branch for a single PR or the first PR of a stack. Each later PR in a stack targets the branch of the PR before it. Always pass `--base` explicitly; don't rely on `gh`'s implicit base.
* Use conventional commit messages: `type(scope): description` or `type(scope): [TICKET-ID] description`
* Commit subjects and PR titles: target 50 characters or fewer, hard cap 60
* In PR descriptions do not list the number of tests that have passed, as the number of tests could be off and result in a blocking comment to fix the description
