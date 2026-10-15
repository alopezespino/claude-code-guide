# CLAUDE.md

<!--
Instructions Claude reads at the start of every session in this repo.
Keep it short; point to longer files instead of pasting them here.
Run the built-in /init in the first session to have Claude fill in the sections from the
repo, then correct what it wrote.
-->

## What this project is

PROJECT_NAME: one paragraph. The question, the output (paper, slides, course
materials), and who works on it.

## Layout

Example entries for a LaTeX paper: replace them with this project's real files.

| Path | Holds |
|------|-------|
| `main.tex` | Main document |
| `sections/` | One .tex file per section |
| `figures/` | Generated figures; do not edit by hand |
| `refs.bib` | Bibliography, exported from the reference manager; do not edit (blocked in `.claude/settings.json`; delete that rule if you edit it by hand) |
| `notes/` | Task files (`notes/<task>.md`) and the lessons log |
| `style/writing-style.md` | Writing rules; follow them for any prose |
| `confidential/` | Never read. Blocked in `.claude/settings.json` |

## Build

```bash
latexmk -lualatex main.tex
```

## Environment

If the project runs code: the environment's name and how to run a script in it, for
example `micromamba run -n PROJECT_NAME python scripts/clean.py`. Never install packages
into another project's environment.

## Conventions

- Notation: (for example, vectors in bold, sets in calligraphic letters).
- Writing: follow `style/writing-style.md`.
- Commits: short imperative messages; `closes #N` when a commit finishes issue N.

## Settings for the example commands

Read by the example slash commands from claude-code-guide. Delete the lines for commands
you do not use.

- Main document (`/compile-tex`): `main.tex`
- Bibliography (`/papersummarize`, `/zotero`): `refs.bib`
- Literature folder (`/papersummarize`): `litrev/`
- PDF converter (`/papersummarize`): `~/micromamba/envs/marker/bin/marker_single`
- Download queue (`/zotero`): `notes/zotero-downloads.md`

## Working state

- Each task has a notes file `notes/<task>.md`, listed in `notes/README.md`.
- Lessons go in `notes/lessons.md`, numbered.
