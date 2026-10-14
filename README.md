# Claude Code + VS Code: a setup that keeps Claude focused

A step-by-step guide, with ready-to-copy sample files, for researchers who use Claude in
chat and are comfortable with git, VS Code and a terminal. It does not depend on a
programming language; examples use LaTeX where they help.

**Why this fixes "Claude goes off track."** In chat, the only context is the
conversation, and it drifts as the conversation grows. In Claude Code the context is files
on disk: the repo, written rules, and a notes file per task, all re-read every session.
Everything below makes that context explicit.

**If you do only five things:** one repo per project with Claude running in its terminal;
a `CLAUDE.md` in the repo; a global `CLAUDE.md` with your own rules; one task per session;
a notes file per task.

## Contents

- [What is in this repository](#what-is-in-this-repository)
- [Part 1. Setup, step by step](#part-1-setup-step-by-step)
- [Part 2. Best practices: fewer tokens, a smarter Claude](#part-2-best-practices-fewer-tokens-a-smarter-claude)
- [Part 3. Easy extras with a large payoff](#part-3-easy-extras-with-a-large-payoff)
- [Part 4. Advanced use cases](#part-4-advanced-use-cases)

## What is in this repository

```
claude-code-guide/
├── README.md                    this guide
├── scripts/
│   ├── preflight.sh             reports which tools are installed (read-only)
│   ├── install-global.sh        copies global/ into ~/.claude, never overwrites
│   └── new-project.sh           creates a new project from project-template/
├── global/                      files for ~/.claude: apply to every project
│   ├── CLAUDE.md                starter personal rules
│   ├── settings.json            permissions and hooks
│   ├── hooks/
│   │   ├── notify-waiting.sh    macOS notification when Claude waits for you
│   │   └── block-rm.sh          blocks rm -r / rm -f, points Claude to trash
│   └── commands/
│       ├── start-task.md        /start-task: open a notes file for a task
│       ├── wrap-up.md           /wrap-up: update notes and lessons before /clear
│       └── compile-tex.md       /compile-tex: build, fix, repeat until clean
├── project-template/            copied into each new project
│   ├── CLAUDE.md                instructions Claude reads every session
│   ├── README.md                five-question README
│   ├── project.code-workspace   VS Code workspace: LaTeX recipe, title-bar color
│   ├── .gitignore               LaTeX build files, OS and editor files
│   ├── .claude/settings.json    project permissions (confidential folder blocked)
│   ├── notes/
│   │   ├── README.md            index of task files
│   │   ├── _task-template.md    skeleton for one task's notes
│   │   └── lessons.md           numbered lessons log
│   └── style/writing-style.md   writing-style guide skeleton
└── prompts/
    ├── build-style-guide.md     derive your style guide from your own writing
    └── merge-existing-setup.md  merge these files into an existing ~/.claude
```

---

## Part 1. Setup, step by step

### Step 1. Install the tools (macOS)

Install Homebrew if you do not have it:

```bash
url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
/bin/bash -c "$(curl -fsSL "$url")"
```

Then the tools. Skip MacTeX if TeX is already installed.

```bash
brew install git gh claude-code
brew install --cask visual-studio-code
brew install --cask mactex-no-gui
gh auth login
```

Claude Code needs a paid Claude plan; the first `claude` run asks you to log in.

### Step 2. Get this repository and check your machine

```bash
git clone https://github.com/OWNER/claude-code-guide.git ~/claude-code-guide
cd ~/claude-code-guide
scripts/preflight.sh
```

`preflight.sh` only reads: it lists what is installed, what is missing, and what is
already in `~/.claude`.

### Step 3. Set up VS Code

1. **Extensions.** Install LaTeX Workshop (builds and previews LaTeX) and Claude Code
   (shows Claude's proposed edits as diffs in the editor):

   ```bash
   code --install-extension james-yu.latex-workshop
   code --install-extension anthropic.claude-code
   ```

2. **Auto-save.** Claude edits files on disk. If the editor holds unsaved changes to the
   same file, the two versions conflict. Turn on auto-save: Settings (Cmd+,), search
   "auto save", choose `afterDelay`.
3. **GitHub sign-in.** Click the Accounts icon (bottom left), "Sign in with GitHub". The
   Source Control panel then shows every change Claude makes as a diff.
4. **The three panels you will use:** Explorer (files), Source Control (diffs and
   commits), and the integrated terminal (Ctrl+`), where Claude runs.

### Step 4. Install the global files

```bash
scripts/install-global.sh
```

This copies `global/` into `~/.claude/`: your personal rules (`CLAUDE.md`), permissions
and hooks (`settings.json`, `hooks/`), and three slash commands (`commands/`). It never
overwrites a file you already have; it lists what it skipped. If you already have a
`~/.claude/CLAUDE.md` or `settings.json`, paste `prompts/merge-existing-setup.md` into a
Claude session to merge the two safely.

Then open `~/.claude/CLAUDE.md` and edit it: it is yours. Every rule there applies in
every session of every project.

### Step 5. Create a project

One project (a paper, a course, a grant) is one folder, one git repo and one VS Code
window.

```bash
scripts/new-project.sh ~/Documents/my-paper
code ~/Documents/my-paper/my-paper.code-workspace
```

The script copies `project-template/`, names the workspace file after the folder, and
runs `git init`. For an existing project, copy the pieces you want into it instead
(`CLAUDE.md`, `notes/`, `.claude/settings.json`, the workspace file).

The workspace file holds the project's settings: the LaTeX build recipe, a title-bar
color (so with several windows open you know which project you are typing in), and, if
the project has code, the interpreter of its environment. One environment per project
(a mamba/conda env or a venv), named in `CLAUDE.md`, means Claude runs code with the
right tools instead of guessing.

### Step 6. Start Claude in the terminal

Open the integrated terminal (Ctrl+`) and run:

```bash
claude
```

Claude now sees the whole folder. It reads, edits, compiles and commits the files itself,
so nothing is pasted. In the first session type `/init`: Claude reads the folder and
fills in `CLAUDE.md`. Then correct what it wrote.

### Step 7. Know what each context document is for

| File | Read by | Holds |
|------|---------|-------|
| `CLAUDE.md` (repo root) | Claude, every session | What the project is, folder map, how to build, conventions, what not to touch |
| `README.md` | People and Claude | What it is, setup, contents, usage, who. Ask Claude to keep it current |
| `notes/<task>.md` | One task | The task's state, so a fresh session can resume from it alone |
| `style/writing-style.md` | Claude, when writing | Your rules for notes, summaries and drafts |
| `~/.claude/CLAUDE.md` | Claude, every project | Your personal rules |

A task file is started at the beginning of the task, not written up at the end, and
Claude updates it as it works. The skeleton is in
`project-template/notes/_task-template.md`.

### Step 8. Run your first task end to end

1. `/start-task tighten the introduction`. Claude creates
   `notes/tighten-introduction.md`, writes the objective and how "done" will be checked,
   and asks at most three questions.
2. Press Shift+Tab until the mode reads Plan, and ask: "Plan the changes to the
   introduction." Read the plan; ask for changes until it is right; accept it.
3. Claude edits. Review the diffs in Source Control. Then `/compile-tex main.tex`.
4. "Commit this with a short message."
5. `/wrap-up`. Claude brings the notes file up to date and records any lessons.
6. `/clear`. Next time: "Read notes/tighten-introduction.md and continue."

### Step 9. Stay in control while you learn

- **Default mode asks before every command and edit.** At that permission prompt,
  **Ctrl+E** gives a plain-language explanation of the command before you accept it (the
  prompt's footer shows the key). This is the best way to learn the terminal while in
  control.
- **Shift+Tab** cycles the modes. Plan mode reads and proposes without editing: use it
  before any large change.
- **Esc Esc** rewinds to an earlier point; **Ctrl+C** stops Claude mid-step; **Ctrl+O**
  opens the full transcript of what it ran and saw; **Ctrl+G** opens your editor for a
  long prompt.
- **`@path/to/file`** in a prompt points Claude at a file.
- **Read diffs before accepting.** Commit before and after each change, so any change can
  be undone with git.

To check that your rules loaded, start a new session and ask "Which of my CLAUDE.md
rules apply to this task?"

---

## Part 2. Best practices: fewer tokens, a smarter Claude

Every turn re-sends the whole conversation. A long conversation costs more per turn and
drifts more. The rules below keep the conversation short and the files rich.

1. **One task per session.** `/clear` at each task boundary; `/compact` at a natural break
   before a long session fills its context. `/rename <name>` names the session for its
   task, and `/resume` reopens it later.
2. **State lives in files, not in the transcript.** Ask Claude to write findings into the
   task's notes file as it finds them, and run `/wrap-up` before `/clear`. The transcript
   is lost at `/clear`; the file is not.
3. **Point, do not paste.** Name the file and section (`@chapter3.tex`, "the proof of
   Lemma 2"). For a question about a long file, ask Claude to send a subagent to read it
   and report the answer, so the bulk text stays out of the main session.
4. **Subagents for reading in parallel, on cheaper models.** "Send three agents to read
   X, Y and Z and report back." A small model is enough for finding and quoting; keep the
   main model for synthesis and edits.
   *Use case: this guide was assembled by four agents reading in parallel: a student
   guide, an onboarding kit, research repos and a global configuration.*
5. **Match the model to the turn.** `/model` picks the model; `/effort` lowers the effort
   for routine turns, which saves usage.
6. **`/btw` for side questions.** `/btw what does this flag do?` gets an answer without
   pulling the main task off track.
7. **Say what "done" means.** "Done when it compiles with no warnings and every citation
   resolves" lets Claude check its own work. Use Plan mode for anything large: a rejected
   plan costs far less than a rejected implementation.
8. **Convert PDFs to Markdown before Claude reads them.** A converter such as marker turns
   math-heavy PDFs into text with the equations in LaTeX: cheaper and more accurate than
   page images.
9. **Never let Claude poll a long job.** Each check is a full turn. Ask for a background
   command that exits when the job ends, so Claude is woken once.
10. **Memory for durable facts.** Claude Code keeps memory per project; say "remember
    that..." for preferences and facts that outlive the task (who is who, a journal's
    house style). Notes hold the task detail; memory holds the facts.
11. **Writing-style guides, one per document type.** Research notes, paper summaries and
    paper drafts each get their own rules (structure, notation, tone, punctuation). Build
    them from your own pre-AI writing with `prompts/build-style-guide.md`: Claude reads a
    few documents you wrote by hand, drafts the rules, and you correct them.
    *Use case: a paper summary comes out with the same structure and voice as the ones I
    wrote by hand years earlier.*
12. **Global rules that carry an origin.** `~/.claude/CLAUDE.md` is loaded in every
    session of every project, so keep it to rules that apply everywhere and move project
    detail into the repo's `CLAUDE.md`. Give each rule a reason, and an "Origin" line
    (date, what went wrong) when it comes from a real mistake. Add a rule the second time
    the same mistake happens. A rule without a reason gets ignored or argued away.
13. **A lessons log and numbered decisions.** `notes/lessons.md` holds numbered entries
    with symptom, cause, fix and the rule it implies; lessons that hold everywhere move to
    the global `CLAUDE.md`. Decisions D1, D2, ... in a task file stop the same choice from
    being re-argued every session.
14. **Precise language in notes.** Numbers instead of adjectives ("compiles in 40 s, 3
    warnings left", not "almost there"). Later sessions read notes as fact.

---

## Part 3. Easy extras with a large payoff

1. **Permissions files.** `global/settings.json` and
   `project-template/.claude/settings.json` hold an allow list for routine safe commands
   (latexmk, git status, git diff), so Claude stops asking; an ask list (`git push`
   always asks); and deny rules for what Claude must never do (`-shell-escape`, reading
   `~/.ssh`, reading the project's `confidential/` folder).
2. **Hooks.** Scripts that Claude Code runs at fixed points, set in
   `global/settings.json`:
   - `notify-waiting.sh`: a macOS notification when Claude finishes or needs you, so you
     can walk away while it works;
   - `block-rm.sh`: refuses `rm -r` and `rm -f`, so Claude uses `trash` and every
     deletion can be recovered from the Trash.
3. **Your own slash commands.** One Markdown file in `~/.claude/commands/` turns a
   repeated workflow into `/name`, usable in every project. The three in
   `global/commands/` are starting points; write your own the third time you type the same
   instructions.
   *Use cases: compile a .tex file and fix warnings until clean, checking that an exam's
   point totals add up; revise a .tex file with minimal edits, then recompile; summarize a
   paper into LaTeX working notes.*
4. **Named, colored sessions.** `/rename` per task and `/color` per session, so several
   sessions running side by side are easy to tell apart and to find again with `/resume`.
5. **`/remote-control`.** Continue the same session from your phone or claude.ai/code, for
   example to approve a step while away from the desk.
6. **GitHub issues as the task list.** One issue per task; `closes #N` in the commit that
   finishes it closes the issue. A GitHub Projects board gives the overview.
7. **Guardrails for confidential data.** Three layers, each easy:
   - deny rules in Claude's permissions for confidential folders, so Claude does not read
     them (see `project-template/.claude/settings.json`);
   - read permission removed at the operating-system level (`chmod -R go-rwx` for other
     users, `chmod -R u-r` to lock even your own account while Claude works), so a command
     that slips past Claude's rules still fails: Claude's rules are policy, file
     permissions are enforced by the system;
   - develop on fake data: write and test code locally against synthetic data with the
     real structure (same columns, types, keys, realistic sizes), then push through git
     to the server that holds the real data and run it there. Claude never sees a real
     record.

---

## Part 4. Advanced use cases

What I do with this setup once the basics are habit.

1. **One copy of every shared script.** A script reused in several projects lives once,
   in a templates folder of a coordination repo. A slash command copies it into each
   project and reports copies that have drifted, so a fix made once reaches every
   project. The scripts read project-specific values (environment name, paths) from a
   small per-project config file instead of hardcoding them, so the same copy runs in
   every repo.
2. **Meetings to assigned tasks.** A small package I wrote (debriefr) and a `/debrief`
   command: the recording becomes a transcript with speakers identified, then a summary
   with an action-items table (owner, task, due date, priority), then GitHub issues
   assigned to each owner on the project board. After a coauthor meeting, the next steps
   are assigned before anyone retypes notes.
3. **A personal control center.** A plain-Markdown repo with inbox, tasks, projects,
   archive and journal folders. I drop a scan in the inbox and Claude files it; a planner
   command reads open tasks and deadlines and proposes the day, and scheduled runs do it
   each morning. Sensitive folders are protected as in Part 3, item 7: filenames visible,
   contents not.
4. **A literature pipeline.** PDFs become Markdown, then LaTeX working notes in one folder
   per paper, named by citation key and written to my summary style guide. Scripts keep
   the reference manager in sync with the project's `.bib` file and check for newer
   versions of working papers.
5. **Several sessions working in parallel.** Independent tasks run in separate sessions,
   each on its own git branch (a worktree), and the sessions message each other: a
   dependent task starts when its predecessor sends its handoff (commit hashes, counts).
   One manager session relays to me only what needs my decision, and every session
   records its lessons before it closes.
6. **Laptop to cluster.** Code developed on fake data locally runs on a computing
   cluster. Long jobs save checkpoints so a kill loses one step, not the run, and a
   watcher wakes Claude only when the job finishes or fails, so waiting costs no tokens.
7. **Fresh-eyes reviews.** A new agent that has not seen my reasoning reads a draft, a
   proof or a set of results and reports what is wrong. It does not anchor on my
   conclusions the way the working session does.
8. **Onboarding someone else.** A starter rules file plus a prompt that merges it into the
   other person's existing setup: back up first, classify each rule as add, merge,
   conflict or skip, ask about every conflict, write only after approval, then verify in a
   fresh session with test questions. This repository is that kit:
   `global/CLAUDE.md` and `prompts/merge-existing-setup.md`.
