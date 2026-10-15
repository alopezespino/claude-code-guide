# Personal rules for Claude Code

<!--
This file is loaded in every session of every project. Keep it to rules that
apply everywhere; project detail goes in each repo's CLAUDE.md.

Each rule says why it exists. When a rule comes from a real mistake, add an
Origin line: "Origin: YYYY-MM-DD, what went wrong." Add a rule the second time
the same mistake happens. Delete rules that no longer earn their place.
-->

## Responses

- Keep answers short, minimal and precise. No headers for simple answers, no restating
  the question, no survey of options: give a recommendation. If I want more, I will ask.
  Why: long answers bury the one line that matters.
- For a conceptual question, explain the foundations before recommending a method.
- When a task creates or changes files, end by printing each file's full absolute path,
  one per line, so I can open it with a click.

## Edits

- Make minimal, surgical edits: change only what was asked. Do not reformat, rename or
  "improve" anything else, and ask before touching files outside the request.
- In LaTeX, never change notation, labels or citation keys unless asked. Compile after
  editing and report the warnings that remain.
- I keep auto-save on in the editor. If a file changed on disk in a way you did not
  expect, stop and ask before editing it.

## Safety

- Never use `rm`. Move files to the Trash with `trash <path>` so they can be recovered.
  Before deleting anything, show a table (file, size, reason) and wait for my approval.
  Origin: (invented example) an `rm -rf` on the wrong folder deleted a draft that had no
  other copy.
- Before any `git push`, show a table of the commits being pushed and wait for approval.
- Never read, print or copy secrets (passwords, API tokens, keys). Store them in the
  macOS Keychain, never in files in a repo.
- Never read folders that a project's CLAUDE.md or settings mark as confidential, even
  when a task seems to need them: ask me instead.

## Working state

- For any task longer than a couple of turns, keep its state in `notes/<task>.md`
  (skeleton in `notes/_task-template.md`). Write findings there as they are found, not
  at the end.
- Before I clear or end a session, bring the task's notes file up to date.
- Record lessons in `notes/lessons.md`: symptom, cause, fix, and the rule it implies.
- In notes, commit messages and comments, use precise language: the measurement or the
  condition, not an adjective. Later sessions read these as fact.

## Efficiency

- Read files narrowly: the section needed, not the whole file. For a question about a
  long file, use a subagent and keep only its conclusion.
- Use subagents for independent reading in parallel: a small model for finding and
  quoting, the main model for synthesis and edits.
- Never poll a long-running command by checking it repeatedly. Run it so that it
  notifies on completion.
- Do not re-read a file to confirm an edit that succeeded.

## Commands for me to paste

- Keep every line of a command I will paste under 80 characters, broken with the
  language's own continuation (a trailing `\` in the shell). Why: the terminal turns soft
  wraps into hard line breaks when pasting, which breaks long one-liners.

## My preferences (edit these)

- Writing style: follow `style/writing-style.md` in the project, if there is one.
- Punctuation and spelling: (for example, American spelling; no em dashes).
- Dates: YYYY-MM-DD in file names and notes.
- Coordination repo for the example `/press` command: `~/coordination`.
