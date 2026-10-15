---
description: Open a notes file for a new task and agree on what "done" means
argument-hint: <short task description>
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Start a new task: $ARGUMENTS

1. Choose a short lowercase-hyphen slug for the task. If `notes/<slug>.md` already
   exists, stop and offer to resume it instead.
2. Create `notes/<slug>.md` from `notes/_task-template.md` (create `notes/` if the repo
   has none, using the same section headings).
3. Fill in Objective (including how "done" will be checked), Inputs and Outputs from my
   description and from the repo. Read only what you need to do this.
4. Add one line for the task to `notes/README.md`.
5. Ask me at most three questions about whatever is ambiguous, and record my answers as
   numbered decisions (D1, D2, ...) in the Decisions section.
6. Do not start the work itself yet. End by printing the full path of the notes file.
