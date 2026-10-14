# Lessons

One entry per lesson, numbered in order. Before adding one, read the end of this file
and take the next free number. A lesson that holds for every project also goes, as one
line, into `~/.claude/CLAUDE.md`.

Format: `L<n>. <the rule> (YYYY-MM-DD)`, then symptom, cause, fix.

## L1. Build with latexmk, never a single engine pass (example entry)

- Symptom: citations printed as [?] after new entries were added to the .bib file.
- Cause: the build ran the engine once and never ran biber.
- Fix: build with `latexmk`, which runs biber and repeats passes as needed.
- Rule: every build command in CLAUDE.md uses latexmk.
