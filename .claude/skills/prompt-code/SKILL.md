---
name: prompt-code
description: Turn a description of coding work into a complete, self-contained prompt for a fresh autonomous coding agent that uses worktrees, stacked draft PRs, a severity-rubric self-review loop, the review-prs workflow, and /consider-feedback. Invoke as /prompt-code followed by the work to be done.
argument-hint: <description of the work to be done>
disable-model-invocation: true
---

# /prompt-code

Your job is to write a prompt for a **fresh agent**. You are not doing the work yourself.

## The work to be done

$ARGUMENTS

## Steps

1. **Check the input.** If the work description above is empty, ask the user what work they want done and stop. If the work is a URL or Ticket number open the URL or use MCP to get the information from the ticket.

2. **Gather just enough context.** The fresh agent starts with nothing: no memory of this conversation, no knowledge of which repos or files matter. Pull in whatever it would otherwise have to rediscover or guess: repo names and paths, relevant files or modules, linked issues/tickets, decisions or constraints already discussed in this conversation, and any prior attempts. Read-only lookups are fine. Do not start implementing, branching, or editing anything.

3. **Pull in the hard rules from global CLAUDE.md.** Read `~/.claude/CLAUDE.md` and copy, verbatim, every rule that applies to this kind of work: commits and commit messages, branch names, PRs, comments, ticket updates, and writing style. Put them in the "Hard rules from CLAUDE.md" section of the prompt. Copy them exactly; do not paraphrase or summarize.

4. **Resolve blocking ambiguity now.** If something in the work description is ambiguous in a way that would change the scope or approach (which repo, which behavior is intended, what counts as done), ask the user before writing the prompt. Ask all such questions in one batch. Do not assume. Smaller open questions that the fresh agent can reasonably raise later go in the prompt's "Open questions" section instead.

5. **Write the prompt** using the structure in "Prompt template" below. The Task section is written fresh for this work. The Operating instructions section is included as written; don't trim, reword, or soften it, since each line reflects a deliberate preference.

6. **Output the prompt** in a single fenced code block using four backticks (````) so any triple-backtick code inside it doesn't break the block. Put nothing inside the block except the prompt. After the block, add at most one or two lines noting any assumptions you'd like the user to double-check.

7. **Save the full prompt to a file.** Write the complete prompt (everything that would have gone inside the four-backtick block) to `~/.claude/user-prompts/code-<YYYY-MM-DD>-<short-slug>.md`, where the slug is 3 to 5 lowercase, hyphenated words describing the task. Create the directory if it doesn't exist. If a file with that name already exists, add `-2`, `-3`, and so on rather than overwriting it. This write is the one exception to the read-only rule in step 2. After writing, read the file back to confirm it saved completely.

   **Return a short launcher prompt instead of the full prompt.** In a single fenced code block, give the user a prompt of no more than about 8 lines that:
   - Tells the agent to read the full file at its absolute path before doing anything else, and to treat that file as its complete instructions.
   - Reminds the agent to adhere to rules in the global and local CLAUDE.md files
   - Lists only the crucial points, if any, that need particular attention for this specific task: the things most likely to go wrong or cause damage here (a risky repo, a production system in the path, a tricky rebase, a question that must be asked before a certain point). Don't restate standing rules just because they exist; repeat one only when this task makes it especially likely to be broken. If nothing stands out, include no list.

   Outside the block, give the file path on one line, and add at most one or two lines noting any assumptions the user should double-check. Do not print the full prompt in the chat.

## Prompt template

````
# Task

## Goal
<One or two sentences: what should be true when this is done.>

## Context
<Repos (with paths), relevant files/modules, linked issues, prior decisions and constraints, anything learned in the orchestrating conversation. Be specific; the agent has no other context.>

## Scope
<What is in scope. If useful, a suggested breakdown into small, independently reviewable PRs and how they stack.>

## Out of scope
<What the agent should not touch or change.>

## Acceptance criteria
<Concrete, checkable conditions for done, including tests that should pass or be added.>

## Open questions
<Known unknowns the agent must ask me about before proceeding past the point where they matter. Write "None known" if there are none.>

# Operating instructions

## Hard rules from CLAUDE.md
Read `~/.claude/CLAUDE.md` in full before starting. The rules below are copied from it and are the ones most likely to matter for this task. They override any default behavior of your tools, including defaults that add AI or Claude attribution.

<rules copied verbatim by the orchestrator>

Every subagent you spawn must receive these hard rules verbatim in its briefing. Subagents do not inherit your context, so a rule you leave out of a briefing will not be followed.

Before every push, and before posting any comment to GitHub or Linear, check your output against these rules.

## Autonomy and questions
Work independently unless there is a question that I need to answer. If there is, ask me the question before continuing. Never assume. Return to me only after you have done the final reviews on the draft PRs you open.

## Git ops, parallelism, and workflows
You are allowed to handle git ops. Create a workflow or use sub-agents, if warranted, to parallelize the task in the most efficient way possible. You may create workflows for tasks you think need one without asking me for permission first.

## Models
Use appropriate agent models: Sonnet for tasks like gathering data or wherever Sonnet is a good fit, Opus for other tasks. You must not use Fable without first asking me.

## Worktrees, branches, and PR stacks
Work from worktrees in the appropriate repos and create the needed branches. Branch names must conform to the specification in my global CLAUDE.md file. Create small PRs that are easily reviewable, and create PR stacks to make reviewing and merging easy. If there are any changes on a base branch, handle rebases so the stack stays clean.

## Self-review before pushing
Before pushing to GitHub, do a self-review of the diff using this rubric:
- Critical/High: bugs, security issues, data loss, or broken logic
- Medium: correctness edge cases, missing error handling, or maintainability risks that could cause a bug later
- Low: everything else, including all comment wording, docstring content, formatting, naming preferences, and documentation completeness

Comments and documentation are NEVER Medium or higher on their own. Only escalate a docs/comment issue if it actively misdescribes the code's behavior in a way that would mislead someone into introducing a bug (e.g. a docstring claims a function is idempotent when it isn't).

For an unbiased pass, spawn a fresh subagent to do the review (don't just re-read your own reasoning) and have it report findings with these severity labels. Fix every Medium-or-higher finding, then re-review. Repeat until a review pass finds zero Medium-or-higher issues.

## Opening PRs
All PRs must be opened as Drafts; I'll move them to Ready for Review manually. Never move a PR to Ready for Review. If a PR is in Ready for Review, assume that I changed the status.

Do not add any GitHub labels to the PR.

## Review rounds
After opening the draft PRs, run the `review-prs` workflow on each branch you opened. Then use the `/consider-feedback` skill on the PR feedback to address it. You and your sub-agents have permission to post review feedback to GitHub. You have my consent to post comments to GitHub, using the writing style and conventions from my global CLAUDE.md.

If a second review round is warranted, run the `review-prs` workflow again and follow the same guidance for considering feedback.

## Before returning to me
Update each PR description to reflect any changes made due to the review round(s). If the work is a stack of PRs, rebase it correctly after the corrections from review feedback.
````
