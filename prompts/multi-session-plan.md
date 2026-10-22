# Multi-session plan template

Use this when a task splits into parts that can run as separate Claude Code sessions,
some of which depend on others. The method:

1. Write the plan as one Markdown file, with the DEPENDENCIES block at the top.
2. Create ALL sessions at once, each with its own name and prompt. Do not wait for a
   predecessor to finish before starting the session that depends on it.
3. A dependent session does the prep its prompt allows (read, measure on current inputs,
   write code and local tests), then ends its turn and idles.
4. Close the waiting sessions if you want to free the screen or memory. Keep only the
   `manager` session open.
5. Senders send their handoff message to the manager (or straight to the receiver while
   it is still running). The manager wakes each waiting session by forwarding the message,
   reopening the session if it was closed.
6. Every session records its lessons and commits them before its `CLOSE OK`.

Names matter: messages are addressed by session name, so every session is created with
a name (`claude --bg -n <name>`, or `/rename <name>` inside an interactive session), and
no two live sessions share one. The worker and manager rules are in
`prompts/manager-protocol.md`.

---

## Template

Copy from here into `notes/<task>-plan.md` and fill in.

````markdown
# <Task> plan

Objective: <what "done" means, in one paragraph, and the check that will prove it>.
Plan commit: <hash of the commit that adds this file; workers check their base against it>.

## DEPENDENCIES

Messages (exact opening text):
- M1: `<sender> done <hash>` sent by <sender> to manager, opens <receiver>.
- M2: ...

Diagram:

    <session A> --M1--> <session B> --M2--> <session C>
    <session D> -------------------------------^

| Session | Model, effort | DEPENDS ON (message) | BLOCKS |
|---|---|---|---|
| <name> | <model>, <effort> | none | <names> |
| <name> | <model>, <effort> | M1 | <names> |

## Sessions

### <name>
Model, effort: <...>. Depends on: <...>. Blocks: <...>.
Prompt:

```text
<prompt, starting with: You are session "<name>". Follow the worker side of
prompts/manager-protocol.md. ...>
```

## Manager

```text
<manager opening prompt>
```

## Progress
<filled by the manager: opens, messages received, closes, with hashes and numbers>
````

---

## Worked example

A study with three stages: clean raw survey files, estimate a model on the clean panel,
and build the paper's tables. A fourth session writes a figure script that needs only the
raw files. All names, numbers and paths below are invented.

### DEPENDENCIES

Messages:
- M1: `data-clean done <hash>`, sent by `data-clean` to `manager`. Opens `estimate`.
- M2: `estimate done <hash>`, sent by `estimate` to `manager`. Opens `tables`.
- M3: `figures done <hash>`, sent by `figures` to `manager`. Opens `tables`.

```
data-clean --M1--> estimate --M2--> tables
figures   ------------------M3-----^
```

| Session | Model, effort | DEPENDS ON (message) | BLOCKS |
|---|---|---|---|
| data-clean | sonnet, medium | none | estimate |
| figures | sonnet, low | none | tables |
| estimate | opus, high | M1 | tables |
| tables | sonnet, medium | M2 and M3 | none |
| manager | opus, low | none (start first) | none |

Start `manager` first, then the four workers in one go, for example:

```bash
cd ~/projects/survey-study
claude --bg -n manager --model opus "$(cat notes/prompts/manager.txt)"
claude --bg -n data-clean --model sonnet \
  "$(cat notes/prompts/data-clean.txt)"
claude --bg -n figures --model sonnet "$(cat notes/prompts/figures.txt)"
claude --bg -n estimate --model opus "$(cat notes/prompts/estimate.txt)"
claude --bg -n tables --model sonnet "$(cat notes/prompts/tables.txt)"
```

(Or open five terminal tabs, start `claude` in each, `/rename` it, and paste its prompt.
An interactive session ends when its window closes, so background sessions suit chains
that run for hours.)

### Prompt for a session with no dependency: data-clean

```text
You are session "data-clean". Follow the worker side of
prompts/manager-protocol.md; send OPEN to "manager" now.

Task: build data/clean/panel.parquet from the raw files in data/raw/.
Rules: drop respondents with no wave-1 interview; harmonise the income
question across waves as described in notes/codebook.md.
Done means: the panel exists, a test checks one row per person-wave, and the
row count matches the count printed by the build.

Work on a worktree branch (EnterWorktree), and check its base against the
plan commit first. When done, send to "manager" exactly:
  data-clean done <commit hash>
with the full handoff in the same message body: output path, row count,
person count, column list, sha256 of panel.parquet. Then record lessons,
commit them, and send CLOSE OK.
```

### Prompt for a dependent session: estimate (with the WAITING block)

```text
You are session "estimate". Follow the worker side of
prompts/manager-protocol.md; send OPEN to "manager" now.

Task: estimate the model in notes/model.md on data/clean/panel.parquet and
write results/estimates.csv.

WAITING
- Your work opens with this message, forwarded by the manager:
    data-clean done <hash>
  Check it before you start: the commit exists in git log, and the row count
  and sha256 in the message match the file.
- Allowed before it arrives: read notes/model.md and the code; write the
  estimation script and unit tests on a small synthetic panel; measure run
  time on the synthetic panel.
- Not allowed before it arrives: run on the real panel, merge or rebase onto
  data-clean's branch, start any long or cluster job.
- After the prep, write what you did to your notes file, end your turn and
  wait. Do not poll the manager or ListAgents. If you are closed and reopened,
  the opening message will be your new prompt; resume from your notes file.

When done, send to "manager" exactly:
  estimate done <commit hash>
with the handoff in the body: output path, number of estimates, sample size,
the three headline coefficients with standard errors. Then lessons, CLOSE OK.
```

`tables` gets the same WAITING block with two opening messages (M2 and M3) and starts
only when both have arrived. `figures` looks like `data-clean`.

### Manager opening prompt

```text
You are session "manager" for the plan in notes/survey-study-plan.md.
Follow the manager side of prompts/manager-protocol.md.

Sessions: data-clean, figures, estimate, tables (see the DEPENDENCIES table).
Your jobs:
1. Acknowledge each OPEN only if something has changed.
2. When a "<session> done <hash>" message arrives, check that the commit
   exists and the handoff fields are present, record it in the Progress
   section of the plan, then forward it verbatim to every session it opens.
   tables needs both M2 and M3; forward both when the second one lands.
3. Before forwarding, check the session list (ListAgents). If the receiver is
   listed, use SendMessage. If it is not listed, reopen it with
   scripts/peer-session.sh open <name> "<the message>".
4. When you forward a gate message, subscribe to the receiver's idle notice
   and arm one due timer, as in item 7 of the manager side.
5. Relay NEEDS YOU requests to me unchanged and hold the floor until I answer.
6. On CLOSE OK, check the lessons commit, record it, and stop the session.
Keep the session and job tables in the plan's Progress section current.
```

---

## Checklist before you start the sessions

- Every session in the table has a unique name, a model and effort, and a prompt.
- Every message in DEPENDENCIES has an exact opening text, one sender and its receivers.
- Every sender's prompt says what to send, to whom, and which handoff fields go in it.
- Every dependent prompt has a WAITING block (opening message, allowed prep, forbidden
  steps, end the turn).
- The plan file is committed, and its hash is in the plan for the worktree base check.
- The manager is started first.
