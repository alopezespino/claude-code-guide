# Prompt: build a writing-style guide from your own writing

Paste the text below into a Claude Code session in the project, after replacing the file
list. Use documents you wrote yourself, ideally before you used AI tools, two or three
per document type.

```text
Build a writing-style guide for me from my own writing.

Documents, grouped by type:
- Research notes: path/to/notes1.md, path/to/notes2.md
- Paper summaries: path/to/summary1.tex, path/to/summary2.tex
- Paper drafts: path/to/draft1.tex, path/to/draft2.tex

Steps:
1. Read the documents of one type at a time. If they are long, use one
   subagent per document and keep only its findings.
2. For each type, describe the patterns you observe: structure and section
   order, sentence length, voice, tense, punctuation habits, how notation and
   numbers are written, what is never done. Quote one short example of each
   pattern with its file and line.
3. Separate rules shared by all types from rules specific to one type.
4. Write the result into style/writing-style.md, using its existing sections.
   Each rule is one line, stated as an instruction.
5. List the patterns you were unsure about as questions for me. Do not guess.
```

Then read the guide, correct it, and keep correcting it whenever Claude's writing misses:
each correction is a new rule.
