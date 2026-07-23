# Global and User level instructions

Project-level instructions override these when they conflict.

## Writing Style

For prose I author (Linear issues, PR/commit bodies, comments, documents, Slack messages, emails, etc):

* Lead with the point; no preamble
* Remove filler ("just", "really", "basically", "in order to", etc ...)
* One idea per sentence; no sentence fragments; prefer short over comma-chained sentences and thoughts.
* Say it once, do not repeat yourself.
* In code-adjacent prose (PRs, commits, code comments), be concrete: cite the file, function, and line number.
* Don't use colorful phrases to add emphasis. Avoid phrases like "real trap", etc.

## Fixing bugs

* Reproduce the bug before writing any code
* Use Test Driven Development (TDD), write the failing test that confirms the bug, then write the code to fix.
* While fixing a bug, don't touch unrelated tests.

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
* Target the default branch, don't rely on `gh`'s implicit base
* Use conventional commit messages: `type(scope): description` or `type(scope): [TICKET-ID] description`
* Commit subjects and PR titles: target 50 characters or fewer, hard cap 60
