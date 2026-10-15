---
description: Compile a LaTeX file, fix errors and warnings, repeat until clean
argument-hint: <file.tex>
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Compile `$ARGUMENTS`. If no file is given, use the main file named in the project's
CLAUDE.md.

1. Build with the command given in CLAUDE.md. If there is none, use
   `latexmk -pdf -interaction=nonstopmode -file-line-error <file>`.
   Never add `-shell-escape`.
2. Read the log narrowly; do not paste it. Look for: errors, undefined references and
   citations, overfull or underfull boxes over 10pt, missing characters or fonts, and
   duplicate labels.
3. Fix each issue with a minimal edit. Never change the meaning of the text, notation,
   labels or citation keys. If a fix would change content, ask me first.
4. Recompile. Repeat until there are no errors and no undefined references, for at most
   five rounds.
5. If the document is an exam or a problem set, also check that the points of the parts
   add up to each question's total and to the stated grand total.
6. Report: number of rounds, what was fixed (file:line), what remains and why, and the
   full path of the PDF.
