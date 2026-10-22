---
description: Apply requested edits to a LaTeX document with minimal changes, then compile and verify
argument-hint: <file.tex> <what to change>
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Revise a LaTeX document (a paper, slides, an exam, notes): $ARGUMENTS

This command makes the edits; `/compile-tex` owns compilation. Do not restate the
compile loop here: two commands that each carry their own copy drift apart.

1. **Identify scope.** Find the .tex file or files to change. If the project has several
   candidates (`main.tex`, `paper_draft.tex`, a short variant), ask which one rather
   than guessing: a repo often holds near-identical drafts that share the same inputs.
2. **Apply the edits, minimally.** Change only what was asked. Do not reflow paragraphs,
   renumber labels, reorder the preamble, or tidy anything else. Never change notation,
   labels or citation keys unless asked. A diff that touches lines nobody asked about
   is a defect, not a bonus.
3. **Compile and verify** with `/compile-tex <file>`. It builds with the project's
   command, fixes errors and undefined references, and, for an exam or a problem set,
   checks that the points add up. If `/compile-tex` is not installed, build with the
   command in the project's CLAUDE.md and read the log for errors, undefined
   references and citations, and overfull boxes.
4. **Report** what changed (file:line) and what the compile found. Print the full
   absolute path of the PDF on its own line.

## Rules

- **Moving a slide to the appendix needs two links.** Ask which main slide should carry
  the `\hyperlink` button to the appendix slide, and always add a `back` button from the
  appendix slide to that main slide (`\hyperlink{main:...}{\beamerbutton{back}}`).
- **Unicode and emoji** in the source need lualatex or xelatex and a font that has the
  glyphs. Use the engine the project's build command names; do not switch it to
  pdflatex.
- **Point totals must balance** after any change to a rubric or a question.
- Never delete a file with `rm`. Move it to the Trash with `trash`.
