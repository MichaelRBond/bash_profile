# /acr-review

Run an automated code review feedback loop using ACR (Agentic Code Reviewer).

## Usage

```
/acr-review [base-branch]
```

If no base branch is specified, defaults to `master` or `main` (auto-detected from remote).

## Instructions

You are an orchestrator running an iterative code review loop. Follow the code-review-loop skill instructions exactly.

1. Determine in-scope files for this task: $ARGUMENTS
   - If arguments specify a base branch, use it; otherwise auto-detect
   - Identify which files are in scope by checking unstaged/staged changes or conversation context
   - Confirm the file list and base branch with the user before starting

2. Verify `acr` is on the PATH. If not found, inform the user and stop.

3. Run the review loop (max 3 iterations):
   a. Run `acr --base <base-branch> --local --reviewer-agent claude --summarizer-agent claude` directly (no sub-agent)
   b. Read the output. Findings are tagged P1, P2, or P3.
   c. Filter out findings in files that are NOT in scope for this task (out-of-scope noise).
   d. For every in-scope finding, evaluate whether it is genuine or a false positive by reading the actual code.
   e. Present a summary to the user with three sections:
      - Issues to fix: grouped by priority with planned changes
      - False positives: each with an explanation of why it's not a real issue
      - Out-of-scope: count of findings in unrelated files
   f. Fix genuine P1 and P2 issues. Fix P3 issues only if straightforward and clearly beneficial.
   g. Re-run ACR to verify fixes.
   h. Stop early if no genuine P1/P2 in-scope issues remain, if the loop is not converging, or after iteration 3.

4. Present a final summary: iterations used, in-scope findings, issues fixed, false positives identified, out-of-scope findings, deferred items.

Important:
- Maximum 3 review iterations, then stop regardless
- Run ACR directly in this session — do NOT spawn a sub-agent to run a CLI command
- Filter findings by scope before evaluating — most noise comes from unrelated files in the diff
- Evaluate every in-scope finding critically — do not blindly fix false positives
- Always explain WHY a finding is a false positive so the user can override if they disagree
- Always show the user what you're fixing before making changes
