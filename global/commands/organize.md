---
description: Daily planner over a folder of Markdown tasks, with modes for a weekly plan, sorting loose items into tasks, breaking down large tasks, and end-of-day wrap-up
argument-hint: [plan | week | check | done | wrap | inbox | breakdown | switch | estimate | away | help] [task or date]
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Help me plan and run my day from my task files: $ARGUMENTS

## Settings

Read these from the project's `CLAUDE.md`, one line each. Use the default when a line is
missing, and never ask for a setting that has a default.

| Line in CLAUDE.md | Default | Used for |
|---|---|---|
| `Planner tasks folder: <path>` | `tasks/` | task files (below) |
| `Planner journal folder: <path>` | `journal/` | daily log `<YYYY-MM-DD>.md` |
| `Planner workday: HH:MM-HH:MM` | `09:00-17:00` | the hours a plan fills |
| `Planner hard stop: HH:MM` | none | a time no block may cross |
| `Planner repos: owner/repo, owner/repo` | none | GitHub issues assigned to me |
| `Planner calendar: yes` | `no` | read events from macOS Calendar |

Paths are relative to the project root. Below, `tasks/` and `journal/` stand for the
configured folders.

### Task file format

One Markdown file per task in `tasks/`, with YAML frontmatter:

```yaml
---
title: Renew library card
status: pending        # pending | in-progress | done | cancelled
priority: normal       # low | normal | high | urgent
due: 2026-05-15        # YYYY-MM-DD, or empty
category: admin        # free text
created: 2026-05-01
---
```

The body is free text (notes, links, steps). When this command creates a task, it uses
exactly these fields and a lowercase-hyphen file name (`renew-library-card.md`).

## Modes

`$ARGUMENTS` picks the mode:

- empty or `plan`: build today's plan;
- `plan <day>` (a date `YYYY-MM-DD`, a weekday name, or `tomorrow`): draft a plan for that day;
- `week`: spread tasks across the days of this week;
- `check`: mid-day check-in, update the plan;
- `done [task]`: mark a task complete;
- `wrap`: end-of-day review, carry forward what is unfinished;
- `inbox`: sort a list of loose items into tasks;
- `breakdown <task>`: split a large or vague task into concrete steps;
- `switch`: close one task and open the next with a parking note;
- `estimate <task> <estimate>`: check an estimate for missing sub-tasks;
- `away <start> <end> [note]`: record a period away from work;
- `help`: print the mode list and nothing else.

## Working rules (all modes)

- Get the date and time from `date '+%A %Y-%m-%d %H:%M'` before planning. Never guess it.
- Read task frontmatter only, unless a mode needs the body.
- Ask before creating, editing or closing any task file. Change only the fields the
  mode names; leave the body alone.
- Never move a due date silently. Propose the new date and wait for my answer.
- Keep output short: the plan table, the questions, nothing else.
- Today's journal file is `journal/<YYYY-MM-DD>.md`. If it does not exist, create it
  with a `# <YYYY-MM-DD>` heading. Append to it; never rewrite earlier entries. Log
  lines have the form `- [HH:MM] <one line>`.

## Mode: plan (default)

### 1. Loose items

Ask once: "Anything not yet written down?" If I list items, run `inbox` on them first.

### 2. Gather

- **Task files**: every file in `tasks/` whose `status` is `pending` or `in-progress`.
  ```bash
  grep -lE '^status: (pending|in-progress)' tasks/*.md
  ```
- **Week plan**: if `tasks/week-plan.md` exists, take today's section.
- **GitHub issues** (only if `Planner repos` is set), for each repo:
  ```bash
  gh issue list -R <owner/repo> --state open --assignee @me \
    --limit 30 --json number,title,labels,milestone
  ```
  Tag each item `[<repo> #N]`. If `gh` fails, say so in one line and continue.
- **Calendar** (only if `Planner calendar: yes`): today's events from macOS Calendar.
  The first run asks for Calendar access in a system dialog; approve it once.
  ```bash
  osascript -e '
  set d0 to (current date)
  set time of d0 to 0
  set d1 to d0 + 1 * days
  set out to ""
  tell application "Calendar"
    repeat with c in calendars
      repeat with e in (every event of c whose start date >= d0 and start date < d1)
        set out to out & summary of e & " | " & start date of e & " | " & end date of e & linefeed
      end repeat
    end repeat
  end tell
  return out'
  ```
  Calendar events are fixed blocks. Ask whether anything is missing from the calendar.
- **Away periods**: if `tasks/away.md` lists a period that covers today, say so and ask
  whether to plan a short session or skip work items.

### 3. Prioritize

List overdue items first and ask, for each: do today, or which new date?

Classify the rest, and show the result as a short list:

| Class | Meaning | Placement |
|---|---|---|
| Main goal | advances a major project or a hard deadline | first deep block |
| Necessary | must be done, does not advance a major goal (admin, forms) | one grouped admin block |
| Upkeep | keeps things running (bills, errands, appointments) | short slots |

Ask one anchoring question: "If only one thing gets done today, which one?" That task
gets the first deep block. If the day's plan contains only necessary and upkeep work
while a main-goal task is due soon, point that out in one sentence.

Sort: overdue (decided), due today, due this week with high or urgent priority,
in-progress, the rest. Estimate effort as quick (under 15 min), medium (25 to 45 min)
or deep (several blocks); ask when unsure. For each deep task, list the 3 to 5
sub-tasks it implies (setup, reading, decisions, cleanup, messages to others), mark the
ones that need a DECISION, and revise the estimate.

### 4. Build the schedule

A table with columns `Time | Block | Task | Project | Est`, filling the configured
workday:

- work blocks of 25 to 45 minutes, numbered `Block 1`, `Block 2`, ...;
- a 5 to 10 minute break after each block, 15 minutes after a deep block;
- lunch as a fixed block;
- one short task first, then the anchor task;
- one admin block for email, issue comments and small replies;
- 5 minutes between tasks from different projects;
- about 20 percent of the day left unscheduled;
- a 15-minute review at the end;
- nothing crosses the hard stop, if one is set.

If it is past the middle of the workday, ask how many blocks are left before building it.

### 5. Adjust and save

Ask: start and end time today, anything to drop, swap or add. Revise. Then append the
final table to today's journal under `## Plan`.

### Planning another day

For `plan <day>`, resolve the day, gather tasks due by then and that day's calendar
events, and append the result to today's journal under `## Draft plan for <date>`.
Mark it as a draft to revise that morning.

## Mode: week

1. Gather as in `plan`, with calendar events for Monday to Friday (or to Sunday if I
   ask) and any away periods this week.
2. Ask: "What one or two things would make this a good week?" Those are the anchors.
3. Propose one line per day. At most two deep tasks per day, calendar events fixed,
   one lighter day for overflow. If the week is full after the anchors and hard
   deadlines, stop; the rest goes under "If there is time".
4. Revise until I approve, then overwrite `tasks/week-plan.md`:

```markdown
---
title: Week plan
week: 2026-06-08 to 2026-06-12
created: 2026-06-07
---

## Anchors
- Draft section 3 of the report

## Monday
- [ ] Draft section 3 (2 blocks)
- [ ] Submit expense form

## Tuesday
...

## If there is time
- Clean up the reference list
```

`plan` reads this file; `done` ticks the matching checkbox in it.

## Mode: check

Read today's `## Plan`. Ask which blocks are done and what is blocking anything.
Mark done blocks, log each under `## Done` in the journal, reorder the rest to fit the
time left, and for each skipped block ask: later today, another day (which date), or
drop. If a task is too vague to start, offer `breakdown`. Write the updated table back.

## Mode: done

1. Match the argument (or ask "What did you finish?") against task titles and file
   names in `tasks/`, and against today's plan blocks.
2. Confirm the match, then set `status: done` in that file.
3. Tick the block in today's plan and the line in `tasks/week-plan.md`, if present.
4. Append `- [HH:MM] <task>` under `## Done` in today's journal.
5. Reply in one line. If nothing matched, log it as a one-off completion.

## Mode: wrap

1. Count today's `## Done` lines and list them.
2. For each unfinished plan block: carry to tomorrow, new due date, or drop. Update the
   `due` field of the task files I approve. For a GitHub item, list the issue and the
   proposed date; edit it only if I ask.
3. Propose tomorrow's top three tasks.
4. Append a three-sentence summary under `## Summary` in today's journal.

## Mode: inbox

1. Ask for the list of loose items (notes, requests, ideas, emails to answer). Wait
   until I finish.
2. Put each item in one bucket and show a table `Item | Bucket | Next step`:

| Bucket | Meaning | Next step |
|---|---|---|
| Now | actionable today | one-sentence first action |
| Later | real, not today | a task file with a due date |
| Waiting | blocked on someone | who, and a follow-up date |
| Drop | not mine, or not needed | none |

3. Create task files for the Later and Waiting items I approve.
4. When run from `plan`, add the Now items to the day's task list and continue.

## Mode: breakdown

For a task that is too large or too vague to schedule. If the argument is a file in
`tasks/`, read it.

1. Split the task into 3 to 8 steps, each a concrete action with a visible end ("draft
   the data section of `report.tex`", not "work on the report"). Put any decision in its
   own step, phrased as a choice between named options.
2. Give each step an estimate and mark the one to do first.
3. Offer to write the steps into the task file as a checklist.

## Mode: switch

1. Ask: what I am leaving, what I am starting, and what open question from the first
   task is still unresolved.
2. Append that question as one line under `## Parking lot` in today's journal, tagged
   with the task.
3. Give a concrete entry point for the next task: the file to open and where to start.

## Mode: estimate

Take the task and my estimate. List the 3 to 5 sub-tasks the estimate may leave out
(setup, reading, decisions, cleanup, messages, waiting on others), mark decisions as
DECISION, give a revised estimate and the step most likely to take longest. If a
decision depends on someone else, suggest asking them first so the answer arrives in time.

## Mode: away

Append the period to `tasks/away.md` (create it with a `## Periods` heading):

```markdown
- 2026-05-15 to 2026-05-26: away (conference travel)
```

`plan` and `week` read this file and skip work items in those periods unless I ask.
Past periods are ignored.

## Unattended runs

When the prompt says the run is unattended (for example the scheduled morning job in
`examples/morning-plan/`), nobody can answer questions:

- ask nothing; where a mode would ask, state the assumption made;
- edit no files; print the plan to standard output only;
- list overdue items under a heading "Needs a decision" and leave their dates alone;
- skip the loose-items question and the calendar dialog if Calendar access was never granted.
