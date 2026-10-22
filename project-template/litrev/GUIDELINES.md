# Guidelines for writing a paper summary

> Example file from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide): the standard
> I use for paper summaries, made generic. Edit any section to set your own standard.
> The example `/papersummarize` command reads this file when it exists.

The standard every summary in this folder follows, whether written by hand, by
`/papersummarize`, or by a subagent. Where this file and the command or any other note
disagree, this file wins.

## 1. Purpose

A summary is a set of working notes. After reading it, a reader should be able to
(a) state the paper's question and contribution, (b) reproduce the model's key
equations and formal results in the paper's own notation, (c) describe the data and
identification, and (d) say how the paper relates to this project. It is not a
referee report and not a paraphrase of the abstract.

## 2. Files and naming

- One folder per paper, named by the paper's citation key in the project's
  bibliography (for example Better BibTeX keys: `Author2024`, `AuthorAuthor2024`,
  `Author-etal2024`; no diacritics). Take the key from the bibliography, never from the
  PDF's file name.
- Inside: `<Key>.pdf`, `<Key>_summary.tex`, optional `images/`.
- A folder without a PDF holds a `NEEDS_PDF.md` note saying where to get it. Move the
  note to the Trash once the PDF is in place and the summary compiles.

## 3. Reading the source

- Convert the PDF to Markdown (for example with marker, as `/papersummarize` does) and
  read the Markdown: it is the cheapest faithful source for text and math.
- Treat the Markdown as a draft. Check every equation that looks mangled, and every
  equation you reproduce in a `definition`, `prop` or `theo`, against the PDF page.
- Cite the paper's own numbering with the page: "(eq. 12, p. 9)", "Proposition 3",
  "Fig. 2", so a claim can be checked in one step.

## 4. Preamble and bibliography

- Use one preamble for every summary, so they all look the same: copy it from an
  existing summary, or keep it as `summary_template.tex` in this folder.
- Bibliography: biblatex with biber, `\usepackage[style=numeric]{biblatex}` and
  `\addbibresource{../../refs.bib}` (the relative path from the paper's folder to the
  project's bibliography, exported from the reference manager), ending with
  `\printbibliography`. Cite with the key exactly as it appears in the bibliography.
- Header: full title (subtitle after a colon on its own line), authors, venue and year
  with `\autocite{<Key>}`, and "Summary by <your name>".

## 5. Structure

Keep the arc: big picture, then technical core, then data and estimation, then
results. Section names may change and sections may split as the paper requires
(for example Environment / Market Structure / Equilibrium), but the arc does not.

1. **Big Picture.** 3 to 5 bullets: the question, why it matters, the core
   contribution, and where it sits in the literature. Broad to specific. At least one
   `commnt` on relevance to this project.
2. **Model.** Every key equation in `equation` or `align`. Every formal object in its
   environment: `ass` for assumptions, `definition`, `prop`, `theo`, `coro`. Give
   proof intuition in 1 to 3 bullets; never reproduce a full proof. Mark the role of
   each object with the highlight commands (section 6).
3. **Data** (empirical papers). Its own section: sources, unit of observation, panel
   or cross section, coverage, frequency, sample or population. Observables in
   `\obs{}`.
4. **Estimation** (empirical papers). Subsections for Identification and, if any,
   Counterfactuals. Estimated objects in `\estim{}`, calibrated ones in `\param{}`.
5. **Results and Conclusions.** 3 to 5 bullets with the headline numbers, plus a
   `commnt` on implications for this project.

**Papers with an important regression design** must also cover, woven into the
sections above: the main specification written out; the identifying assumptions; why
this strategy improves on plain OLS and which bias it removes (`commnt`); the main
estimates and their interpretation; each threat to identification (one `doubt` each);
the robustness checks; and possible extensions (`commnt` in Results).

**Reference works** (books, monographs, a single chapter cited for a theorem): write a
targeted summary of the results this project uses, not of the whole work. Find them by
searching the project for the key. Keep the same arc: Big Picture (what the work is
and why the project cites it), Setting (the spaces, definitions and notation the
results need), Main Results (each cited theorem stated verbatim with its number and
page, plus hypotheses and a proof idea), and Use in This Project (where each result
enters the argument and whether its hypotheses hold there, with `doubt` where they may
not). Read only the chapters needed.

## 6. Annotations and highlighting

| Device | Use for |
|---|---|
| `commnt` (navy) | Connections to this project, comparisons with other papers, explanations |
| `doubt` (magenta) | Concerns, open questions, steps to verify |
| `mymodel` (green) | Extensions of, or mappings to, the project's own model |
| `\gray{}` | A named concept at first use |
| `\obs{}`, `\param{}`, `\estim{}` | Observed, calibrated and estimated objects |

- At least 3 `commnt` blocks per summary. Each must say something specific (which of
  the project's objects corresponds to theirs, which assumption the project relaxes),
  not "this is relevant to our project".
- Keep the paper's notation in the body. Translate to the project's notation only
  inside `commnt` or `mymodel`, stating the mapping explicitly (the project's notation
  conventions are in its CLAUDE.md).
- Highlight macros built on `\tcbhighmath` (tcolorbox) go inside math mode.
- The color names used here (NavyBlue, PineGreen, RedViolet, Goldenrod) need the
  `dvipsnames` option (`\documentclass[dvipsnames]{article}` or
  `\usepackage[dvipsnames]{xcolor}`); without it they are undefined.

## 7. Figures

Clip only figures that carry information the text does not (a mechanism diagram, a
key empirical pattern), usually 0 to 4. Render the page with `pdftoppm -r 300`, crop
to the figure, save it to `images/`, and move the full-page renders to the Trash.
Caption with the paper's figure number. If a clean crop is not possible, leave the
`figure` block commented out with its caption.

## 8. Register

- Plain, precise, economics-first prose; no metaphor, no slang, no vague
  intensifiers. Give the number instead of the adjective.
- Follow the punctuation and spelling rules in `style/writing-style.md`, if the project
  has one.
- Bullets over paragraphs; equations over prose descriptions of equations.

## 9. Length

200 to 500 lines of LaTeX: about 200 for a short empirical paper, 400 or more for a
dense theory paper; 100 to 200 for a targeted reference-work summary. Formal structure
takes priority over prose.

## 10. Done checklist

- [ ] Compiles cleanly from the paper's folder
      (the project's build command from CLAUDE.md, e.g.
      `latexmk -lualatex -interaction=nonstopmode <Key>_summary.tex`): no errors, no `??`,
      no undefined citations. An undefined key means the paper is missing from the
      bibliography: add it in the reference manager and export again.
- [ ] Every reproduced equation and theorem checked against the PDF page.
- [ ] Big Picture, Model and Results present; Data and Estimation for empirical papers;
      the regression-design items where they apply.
- [ ] At least 3 specific `commnt` blocks; `doubt` blocks for real concerns.
- [ ] Rendered PDF inspected for overflowing equations and figure placement.
- [ ] `NEEDS_PDF.md` moved to the Trash, if there was one.
