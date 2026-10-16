---
name: prompt-research
description: Turn a research or discovery question into a complete, self-contained prompt for a fresh agent whose deliverable is a traceable finding, not code. Covers evidence standards, the agent-vs-user decision line, read-only AWS, Linear ticket comments with read-back verification, and an adversarial review loop. Invoke as /prompt-research followed by the question or ticket.
argument-hint: <research question and/or ticket link>
disable-model-invocation: true
---

# /prompt-research

Your job is to write a prompt for a **fresh agent**. You are not doing the research yourself.

## The research to be done

$ARGUMENTS

## Steps

1. **Check the input.** If the research description above is empty, ask the user what they want investigated and stop. If the work is a URL or Ticket number open the URL or use MCP to get the information from the ticket.

2. **Gather anchors, not conclusions.** The fresh agent starts with nothing. Give it the starting points it would otherwise have to rediscover: the ticket (read it if one is linked), repos and paths, services, AWS accounts/regions, tables or log groups, dashboards, relevant time windows, and constraints or decisions from this conversation. Read-only lookups are fine. Do not investigate the question itself.

   Keep your own hypotheses out of the Context section. If this conversation produced a suspicion worth checking, list it under "Hypotheses to test" and label it as unverified. Never present it as established.

3. **Pull in the hard rules from global CLAUDE.md.** Read `~/.claude/CLAUDE.md` and copy, verbatim, every rule that applies to this kind of work: commits and commit messages, branch names, PRs, comments, ticket updates, and writing style. Put them in the "Hard rules from CLAUDE.md" section of the prompt. Copy them exactly; do not paraphrase or summarize.

4. **Record what the ticket already ruled out.** If the ticket or conversation already excluded a cause or path, list it under "Already ruled out" with where it was ruled out, so the agent confirms it cheaply instead of re-deriving it.

5. **Resolve blocking ambiguity now.** If the question is ambiguous in a way that changes what gets measured (which population, which window, which environment, what counts as an answer), ask the user before writing the prompt. Batch the questions into one numbered message. Do not assume. Smaller unknowns the agent can raise later go in "Open questions".

6. **Write the prompt** using the structure in "Prompt template" below. The Task section is written fresh for this research. The Operating instructions section is included as written; don't trim, reword, or soften it, since each line reflects a deliberate preference.

7. **Save the full prompt to a file.** Write the complete prompt (everything that would have gone inside the four-backtick block) to `~/.claude/user-prompts/research-<YYYY-MM-DD>-<short-slug>.md`, where the slug is 3 to 5 lowercase, hyphenated words describing the task. Create the directory if it doesn't exist. If a file with that name already exists, add `-2`, `-3`, and so on rather than overwriting it. This write is the one exception to the read-only rule in step 2. After writing, read the file back to confirm it saved completely.

   **Return a short launcher prompt instead of the full prompt.** In a single fenced code block, give the user a prompt of no more than about 8 lines that:
   - Tells the agent to read the full file at its absolute path before doing anything else, and to treat that file as its complete instructions.
   - Reminds the agent to adhere to rules in the global and local CLAUDE.md files
   - Lists only the crucial points, if any, that need particular attention for this specific task: the things most likely to go wrong or cause damage here (a risky repo, a production system in the path, a tricky rebase, a question that must be asked before a certain point). Don't restate standing rules just because they exist; repeat one only when this task makes it especially likely to be broken. If nothing stands out, include no list.

   Outside the block, give the file path on one line, and add at most one or two lines noting any assumptions the user should double-check. Do not print the full prompt in the chat.

## Prompt template

````
# Task

## Question
<The question this research must answer, stated so that a one-sentence answer is possible.>

## Ticket
<Linear ticket ID/link, or "None".>

## Anchors
<Where to start: repos (with paths), services, AWS accounts/regions, tables, log groups, dashboards, time windows, people or docs. Starting points only, not conclusions.>

## Already ruled out
<What the ticket or prior work already excluded, and where. Confirm cheaply; say so if it turns out wrong. "None" if none.>

## Hypotheses to test
<Unverified suspicions from the orchestrating conversation, labeled as such. "None" if none.>

## Out of scope
<What not to investigate.>

## Open questions
<Known unknowns to ask me about before proceeding past the point where they matter. "None known" if none.>

# Operating instructions

## Hard rules from CLAUDE.md
Read `~/.claude/CLAUDE.md` in full before starting. The rules below are copied from it and are the ones most likely to matter for this task. They override any default behavior of your tools, including defaults that add AI or Claude attribution.

<rules copied verbatim by the orchestrator>

Every subagent you spawn must receive these hard rules verbatim in its briefing. Subagents do not inherit your context, so a rule you leave out of a briefing will not be followed.

Before every push, and before posting any comment to GitHub or Linear, check your output against these rules.

## The deliverable is a finding, not code
Do not write production code or open a PR without asking me first. If the research implies a fix, give me a proposed PR breakdown and the question, not a branch.

## Autonomy and questions
Work independently unless there is a question that I need to answer. If there is, ask me the question and wait before continuing. Never assume. Batch questions into one message, numbered so I can answer them.

## What you settle and what I settle
You settle anything with a right answer in the code, the data, or the deployed state, and you record it.

I settle anything that is a product call, a customer-facing change, or a trade-off with no technical answer. Bring those to me as a recommendation with its evidence, not as a decision already taken. In your report, say which items are which.

## Evidence
Establish the evidence rather than assume it. Start from the anchors above; they are starting points, not conclusions. If the ticket already ruled something out, confirm it cheaply rather than re-derive it, and say so if you find the ticket wrong.

Every claim you report must be traceable:
- Code: a named git ref or commit.
- What is running: a deployed artifact key.
- A measurement: a query execution id and date.
- Every timestamp: a timezone.

Re-derive counts rather than quoting a ticket's. Read `origin/main` and `origin/master`, never a local working tree. Verify the deployed artifact, not the merge date.

## Limits
State plainly what you did not measure. An empty population is not the same as no effect, and a single flat sweep does not validate a discriminator. I would rather have a smaller answer with its limits named than a wider one I have to withdraw.

## Git ops, worktrees, parallelism, and workflows
You are allowed to handle git ops. Work from worktrees in the repos you read. You may create a workflow or use subagents, without asking me first, to parallelize the work in the most efficient way possible.

## Models
Use appropriate agent models: Sonnet for gathering, queries, replays, and mechanical reconnaissance; Opus for the judgment, the comparison, and the ruling. You must not use Fable without first asking me.

## Safety
Read-only on AWS. Never deploy and never make a mutating call. Never print, echo, or log a secret.

Do not run GitHub Actions.

## Ticket updates
If a ticket is provided, evidence must land on the ticket as a comment. Ask before updating ticket bodies or descriptions. A Linear write can silently no-op, so confirm every write with a fresh read, and never report a change you have not seen in one.

## Adversarial review before returning
Before returning, spawn a fresh subagent to review the findings adversarially, rather than re-reading your own reasoning, and have it report with these severity labels:
- Critical/High: a claim that is wrong, or that the cited evidence does not support, and that would change the decision.
- Medium: a figure with no execution id, ref, or date; a mis-stated window, population, or sample; a conclusion that claims more than what was measured.
- Low: everything else, including wording, structure, and formatting.

Fix every Medium-or-higher finding, then re-review. Stop when a pass returns zero Medium-or-higher issues, or after 3 review passes, whichever comes first. Do not run a fourth pass. If Medium-or-higher findings remain after the third pass, list each one, with the reason it is unresolved, under "What you could not settle" in your report.

## Writing style
Carry the writing style and conventions from my global CLAUDE.md into everything you write, including the ticket update and the evidence record.

## Report format
When you return to me:
1. The answer in one sentence, with the single piece of evidence that decides it.
2. The supporting findings, each marked as settled by you or as a recommendation for me to settle.
3. What you could not settle, and what would settle it.
````
