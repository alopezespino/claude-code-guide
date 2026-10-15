---
description: Summarize an academic paper into LaTeX working notes, one folder per paper
argument-hint: <paper.pdf> | <folder> | revise [<Key>]
---

Summarize into LaTeX working notes: $ARGUMENTS

Prerequisites (macOS, once). marker turns PDFs into Markdown with equations in LaTeX;
its first run downloads its models (a few GB).

```bash
brew install --cask mactex-no-gui   # latexmk, biber
brew install poppler micromamba     # pdftoppm; Python environments
micromamba create -y -c conda-forge -p ~/micromamba/envs/marker python=3.11
~/micromamba/envs/marker/bin/pip install marker-pdf
```

Settings come from the project's CLAUDE.md (default in brackets): the bibliography file
[`refs.bib`], exported from the reference manager and never edited by you; the
literature folder, `<lit>` below [`litrev/`]; the converter command
[`~/micromamba/envs/marker/bin/marker_single`]; an optional summary template. The "Paper
summaries" section of `style/writing-style.md` wins where it differs from this command.

Arguments: a PDF; a folder, which must be `<lit>` (every PDF directly in it; confirm the
list with me first); nothing (same as `<lit>`); or `revise` (see the end).

## 1. Cite key and folder

1. Read only the PDF's first page for title, authors and year, never the file name.
2. Find the paper in the bibliography by title and authors and use that exact key. If it
   is missing, tell me to add it in the reference manager and re-export; meanwhile use a
   provisional key in the style of the existing keys and flag it. Never add a local bib.
3. If `<lit>/<Key>/<Key>_summary.tex` exists, do not overwrite it: skip, offer `revise`.
4. Create `<lit>/<Key>/images/` and move the PDF to `<lit>/<Key>/<Key>.pdf`.
5. For context, read the Big Picture of two or three existing summaries, the project's
   README and CLAUDE.md (model, notation), and search the project for `<Key>` to see
   where and why it cites the paper. The annotations must speak to those uses.

## 2. Read the paper as Markdown, not as page images

A page read as an image costs about 1,750 tokens, and its math is read from a bitmap.
Convert once; the cache is keyed on the PDF's contents, so a rerun is instant:

```bash
conv="$HOME/micromamba/envs/marker/bin/marker_single"  # or CLAUDE.md's
pdf="<lit>/<Key>/<Key>.pdf"
out="$HOME/.cache/papersummarize/$(shasum -a 256 "$pdf" | cut -c1-16)"
ls "$out"/*/*.md 2>/dev/null ||
  $conv "$pdf" --output_dir "$out" --output_format markdown
```

Read the `.md` under `$out` as a draft. Check against the PDF page (that page only)
every equation that looks mangled and every one you reproduce in a formal environment.
If the conversion fails, read the PDF in short page ranges. For a book, convert only the
chapters the project uses: add `--page_range 40-72` (0-indexed) and append it to `$out`.

## 3. Write the summary

Write `<lit>/<Key>/<Key>_summary.tex`. Copy the preamble from an existing summary in
`<lit>`, or from the template in CLAUDE.md, so all summaries match. If there is neither,
write one with: biblatex (numeric, biber) and `\addbibresource` with the relative path
from the paper's folder to the bibliography; amsthm environments `ass`, `definition`,
`prop`, `theo`, `coro`; colored annotation environments `commnt` (navy: links to the
project, explanations), `doubt` (magenta: concerns, steps to verify) and `mymodel`
(green: mappings to the project's model); `\gray{}` (a soul highlight) for a named
concept at first use; math shading by role, `\obs{}` observed, `\param{}` calibrated,
`\estim{}` estimated; `\printbibliography` at the end. Header: the title in bold
(subtitle on its own line), `\today`, "by Authors -- Journal Year", `\autocite{<Key>}`.

Purpose: a reader can state the question and contribution, reproduce the key equations
and results in the paper's notation, describe the data and identification, and say how
the paper relates to the project. Not a referee report; not the abstract again. Use
these sections in this order (rename or split them as needed; keep the order):
1. **Big Picture**: 3 to 5 bullets: question, why it matters, contribution, place in
   the literature; at least one `commnt` on relevance to the project.
2. **Model**: each key equation in `equation` or `align`; each formal object in its
   environment; proof intuition in 1 to 3 bullets, never a full proof.
3. **Data** and **Estimation** (empirical papers): sources, unit of observation,
   coverage, frequency; then Identification, and Counterfactuals if any.
4. **Results and Conclusions**: 3 to 5 bullets with the headline numbers; a `commnt` on
   implications for the project.

A regression design also needs: the specification written out; the identifying
assumptions; the bias it removes relative to plain OLS (`commnt`); the main estimates
and their meaning; one `doubt` per threat to identification; robustness; extensions.
A reference work cited for a theorem gets instead: Big Picture; Setting; Main Results
(each cited theorem verbatim, with number, page, hypotheses, proof idea); Use in This
Project (where each result enters, whether its hypotheses hold; `doubt` where not).

Rules:
- Quote key definitions and cited theorems verbatim, with the page. Cite the paper's own
  numbering with the page ("eq. 12, p. 9"), so each claim can be checked in one step.
- At least three `commnt` blocks, each specific (which project object maps to which of
  theirs, which assumption the project relaxes); never "relevant to our project".
- Keep the paper's notation; translate to the project's only inside `commnt` or
  `mymodel`, stating the mapping. Bullets over paragraphs; numbers over adjectives.
- Length: about 200 lines of LaTeX for a short empirical paper, 400 or more for a dense
  theory paper, 100 to 200 for a reference work.

## 4. Figures

Clip only figures the text cannot replace, usually 0 to 4: preview page P, then crop at
300 dpi (coordinates 3 times the preview's). Include each in a `figure[H]` captioned
"(Fig.~X in the paper)"; comment out one that cannot be cropped cleanly.

```bash
tmp=$(mktemp -d); pdftoppm -png -r 100 -f P -l P "$pdf" "$tmp/page"
pdftoppm -png -r 300 -f P -l P -x X -y Y -W W -H H -singlefile \
  "$pdf" "<lit>/<Key>/images/fig_name"
```

## 5. Build, verify, report

In `<lit>/<Key>/`, run `latexmk -pdf -interaction=nonstopmode <Key>_summary.tex`. Fix
and rebuild until there are no errors, no `??` and no undefined citations (an undefined
`<Key>` means the paper is missing from the bibliography: report it). Render one or two
pages (`pdftoppm -png -r 80`) and look for overflowing equations. Report: full paths of
the `.tex` and `.pdf`, one per line; the key, and whether it is provisional; figures
clipped; remaining warnings.

## Revise mode

`revise` audits each `*_summary.tex` in `<lit>` (or only `<Key>`) against steps 3 and 5
and the style file, shows a table `Summary | OK or Needs update | Gaps`, and asks which
to update. For each one approved: re-read the paper from the cached Markdown, keep all
existing content, fill only the gaps, build and verify as in step 5. Report the counts.
