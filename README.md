# Claude Code + VS Code: a setup that keeps Claude focused

A step-by-step guide, with ready-to-copy sample files, for researchers who want to move from Claude's chat app to Claude Code and are comfortable with git, VS Code and a terminal. It works with any programming language; examples use LaTeX where they help.

**Why this fixes "Claude goes off track."** In chat, the only context is the
conversation, and it drifts as the conversation grows. In Claude Code the context is files
on disk: the repo, written rules, and a notes file per task, all re-read every session.
Everything below makes that context explicit.

**If you do only five things:** one repo per project with Claude running in its terminal;
a `CLAUDE.md` in the repo; a global `CLAUDE.md` with your own rules; one task per session;
a notes file per task.

## Contents

- [What is in this repository](#what-is-in-this-repository)
  - [What each file does](#what-each-file-does)
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
│       ├── compile-tex.md       /compile-tex: build, fix, repeat until clean
│       ├── papersummarize.md    /papersummarize: a paper into LaTeX working notes
│       ├── zotero.md            /zotero: manage a Zotero library via its Web API
│       ├── press.md             /press: one canonical copy of each shared script
│       └── debrief.md           /debrief: meeting recording to summary and issues
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

### What each file does

Every file is optional: take the ones you want. "Recommended" marks the ones with the
largest payoff for the least effort.

**`scripts/`: run from this repository's folder**

| File | What it does | Needed? | What it gets you |
|------|--------------|---------|------------------|
| `preflight.sh` | Checks for each tool the guide uses (brew, git, gh, claude, code, latexmk, biber, trash, micromamba) and prints `ok`, `MISSING` (required) or `-` (optional). Then prints versions, whether `gh` is logged in to GitHub, and which of `CLAUDE.md`, `settings.json`, `hooks`, `commands`, `skills` and `agents` already exist in `~/.claude`. Changes nothing. | Optional | Missing tools found before a later step fails; you learn whether you need the merge prompt |
| `install-global.sh` | Creates `~/.claude/hooks` and `~/.claude/commands` if missing, copies each file from `global/` unless a file with that name already exists, makes the hooks executable, and lists each file as `copied` or `skipped`. | Optional (you can copy by hand) | The global files installed in one command, with nothing of yours overwritten |
| `new-project.sh` | Creates the project folder (stops if it exists and is not empty), copies `project-template/` into it, renames the workspace file after the folder, writes the folder name wherever the templates say `PROJECT_NAME`, and runs `git init`. Does not commit. | Optional (you can create the files by hand) | The same structure in every project, so you and Claude find things in the same place |

**`global/`: installed into `~/.claude/`, applies to every project**

| File | What it does | Needed? | What it gets you |
|------|--------------|---------|------------------|
| `CLAUDE.md` | Starter personal rules: short answers, minimal edits, `trash` instead of `rm`, a commit table before any push, no secrets in files, notes and lessons files, narrow reading, subagents, paste-safe commands, and a section for your own preferences. | Recommended; edit it freely | Claude follows your rules in every session without being told again |
| `settings.json` | Permissions and hooks. `allow`: `git status`, `git diff`, `git log`, `ls` and `latexmk` run without asking. `ask`: `git push` always asks. `deny`: `rm -rf`, any command with `-shell-escape` (lets LaTeX run arbitrary programs), reading `~/.ssh` and `~/.aws` (keys), and editing your shell startup files and `~/.gitconfig`. `hooks`: registers the two scripts below. | Recommended | Fewer prompts for safe commands; hard stops for dangerous ones |
| `hooks/notify-waiting.sh` | Runs when Claude finishes a turn (`Stop`) or needs your input (`Notification`), and shows a macOS notification with the project's name. macOS may ask once whether to allow notifications. | Optional; if it is too frequent, delete its `Stop` entry in `settings.json` | You can leave Claude working and come back when it waits |
| `hooks/block-rm.sh` | Runs before every shell command Claude starts. If the command begins with `rm` and a `-r` or `-f` flag, it blocks the command (exit code 2) and tells Claude to use `trash`. `git rm` is not affected. | Recommended; needs `trash` (preflight checks; `brew install trash` if missing) | Every deletion can be recovered from the Trash |
| `commands/start-task.md` | Defines `/start-task <description>`: creates `notes/<task>.md` from the template, fills in the objective, inputs and outputs, adds the task to `notes/README.md`, asks at most three questions, and stops before doing the work. | Optional | Every task starts with a written definition of "done" |
| `commands/wrap-up.md` | Defines `/wrap-up`: updates the task's notes (progress, decisions, surprises, follow-ups), adds lessons to `notes/lessons.md`, offers to commit, and prints how to resume. | Optional | Nothing is lost at `/clear` or the end of a session |
| `commands/compile-tex.md` | Defines `/compile-tex <file>`: builds with latexmk, reads the log for errors and warnings, fixes them with minimal edits, and repeats (at most five rounds). For an exam or problem set, also checks that points add up. | Optional (LaTeX) | A clean build without reading the log yourself |
| `commands/papersummarize.md` | Defines `/papersummarize <paper.pdf>`: converts the PDF to Markdown with marker (equations as LaTeX, cached by file contents), checks the citation key against the paper's first page, and writes LaTeX working notes in `litrev/<Key>/` with a fixed structure, quoting key definitions with page numbers. Never overwrites an existing summary. The bibliography file and literature folder come from CLAUDE.md. | Optional (research); needs MacTeX, poppler and marker (install lines at the top of the file) | Papers read as text instead of page images, and every summary in the same structure |
| `commands/zotero.md` | Defines `/zotero <subcommand>` (add, meta, papers, clean, dedup, attach, tags): works on a Zotero library through its Web API, with the API key in the macOS Keychain. Every write goes read, dry run, approval table, apply, re-read. Keeps old PDF versions, queues paywalled published versions for manual download, and lists the API's known traps. | Optional; needs pyzotero and a Zotero API key (install lines at the top of the file) | Bulk library edits that are shown to you before they are made |
| `commands/press.md` | Defines `/press` with four modes: consolidate (turn a project's script into a template), deploy (copy a template into a new project), sync (update every copy) and check (report copies that differ). A manifest in the coordination repo lists each template and where its copies live; scripts read per-project values from `project.yaml`. Shows a diff before overwriting a locally edited copy, never deletes, commits per project, never pushes without approval. | Optional; useful once a script lives in two or more projects | A fix made once reaches every project |
| `commands/debrief.md` | Defines `/debrief <audio file>`: runs [debriefr](https://github.com/alopezespino/debriefr) to transcribe and identify speakers (you name unknown voices from short clips), writes a summary with an action-items table, and, after a dry run and your approval, syncs the items to GitHub issues on a Project board. | Optional; needs debriefr, a Hugging Face token, and an Anthropic key or a summary written in the session (install lines at the top of the file) | A meeting's next steps assigned without retyping notes |

**`project-template/`: copied into each new project**

| File | What it does | Needed? | What it gets you |
|------|--------------|---------|------------------|
| `CLAUDE.md` | Sections Claude reads at the start of every session: what the project is, a folder map, the build command, the environment, conventions, where notes live. | Recommended | Claude knows the project from the first message |
| `README.md` | Five questions: what it is, how to set it up, what is in it, how to use it, who. | Recommended | People and Claude get oriented quickly |
| `project.code-workspace` | VS Code settings for this project only: a title-bar color, auto-save, a LaTeX recipe (latexmk with lualatex, SyncTeX on, errors reported as file:line, build files kept for faster rebuilds), a commented line for a code interpreter, and recommended extensions. | Recommended | Opening this file restores the project's setup; the color tells you which window you are in |
| `.gitignore` | Keeps out of git: LaTeX build files, `confidential/`, `.claude/settings.local.json` (your personal approvals), `.DS_Store`, `.vscode/`. | Recommended | Clean diffs; confidential material is never committed |
| `.claude/settings.json` | Project permissions. `allow`: `latexmk`, `biber`, `git add`, `git commit`. `deny`: reading or editing `confidential/`, any shell command that names `confidential/`, editing `refs.bib` (it is exported from your reference manager). Committed, so coauthors share it. | Recommended when the project has confidential material | Fewer prompts, and the confidential folder is off limits to Claude |
| `notes/README.md` | An index table of task files and their status. | Optional | Open tasks at a glance |
| `notes/_task-template.md` | Section skeleton for one task: objective, inputs, outputs, decisions, progress, surprises, follow-ups. | Recommended | A fresh session resumes from one file |
| `notes/lessons.md` | Format for numbered lessons, with one example entry. | Optional | A mistake is made once, not rediscovered |
| `style/writing-style.md` | Section skeleton for your writing rules: all documents, research notes, paper summaries, paper drafts, and the reference documents that show your style. | Optional | Claude writes in your voice |

**`prompts/`: text to paste into a Claude session**

| File | What it does | Needed? | What it gets you |
|------|--------------|---------|------------------|
| `build-style-guide.md` | Has Claude read documents you wrote yourself, describe the patterns with quoted examples, write them as rules into `style/writing-style.md`, and ask about what it is unsure of. | Optional | A first style guide in one session |
| `merge-existing-setup.md` | Has Claude back up your `~/.claude` files, classify each incoming rule as add, merge, conflict or skip, ask you about every conflict, write only after your approval, and verify in a fresh session. | Only if `~/.claude/CLAUDE.md` or `settings.json` already exist | The kit adopted without losing your existing rules |

---

## Part 1. Setup, step by step

Each command block is followed by what each line does, whether you need it, and what it
gets you. "Required" means a later step depends on it.

### Step 1. Install the tools (macOS)

**Homebrew.** Check whether you have it with `brew --version`. If not:

```bash
url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
/bin/bash -c "$(curl -fsSL "$url")"
```

| Line | What it does | Needed? |
|------|--------------|---------|
| `url=...` | Stores the address of Homebrew's official install script in a variable, so the next line stays short enough to paste safely. | Only without Homebrew |
| `/bin/bash -c "$(curl -fsSL "$url")"` | Downloads the script and runs it. `curl` flags: `-f` stop on a server error, `-s` no progress bar, `-S` still show errors, `-L` follow redirects. It asks for your Mac password and may install Apple's command-line developer tools. | Only without Homebrew |

What it gets you: Homebrew installs every other tool below with one command each, and
`brew upgrade` updates them all. When it finishes it prints "Next steps": lines that add
`brew` to your shell's PATH. Run them, or a new terminal will not find `brew`.

**The tools.**

```bash
brew install git gh claude-code
brew install --cask visual-studio-code
brew install --cask mactex-no-gui
gh auth login
```

| Line | What it does | Needed? |
|------|--------------|---------|
| `brew install git gh claude-code` | Installs three command-line tools: `git` (version control; newer than the one Apple ships), `gh` (GitHub from the terminal: log in, create repos, issues, pull requests) and `claude-code` (the `claude` command). | Required |
| `brew install --cask visual-studio-code` | Installs VS Code (`--cask` means a desktop app) and its `code` command for the terminal. | Required, unless VS Code is installed |
| `brew install --cask mactex-no-gui` | Installs TeX Live without its desktop apps: the TeX engines, `latexmk` and `biber`. Several GB. Open a new terminal afterwards so the TeX commands are found. | Only for LaTeX, and only if `latexmk --version` fails |
| `gh auth login` | Logs you in to GitHub through the browser (choose GitHub.com, HTTPS, and "Login with a web browser") and sets git to use that login. | Required to push to GitHub |

What it gets you: one editor, one version-control setup and one GitHub login, with no
passwords or tokens to manage by hand; Claude can then create repos, commits and issues
for you.

Claude Code needs a paid Claude plan; the first `claude` run opens the browser to log in.

### Step 2. Get this repository and check your machine

```bash
git clone https://github.com/OWNER/claude-code-guide.git ~/claude-code-guide
cd ~/claude-code-guide
scripts/preflight.sh
```

| Line | What it does | Needed? |
|------|--------------|---------|
| `git clone <url> ~/claude-code-guide` | Downloads this repository into a folder in your home directory. | Required to use the scripts and templates; reading the guide on GitHub needs nothing |
| `cd ~/claude-code-guide` | Moves the terminal into that folder. The scripts in Steps 2, 4 and 5 are run from here. | Required |
| `scripts/preflight.sh` | Read-only report: each tool as `ok`, `MISSING` (required) or `-` (optional), then versions, GitHub login status, and what already exists in `~/.claude`. | Optional, recommended |

What it gets you: you see what is missing before a later step fails, and whether Step 4
needs the merge prompt.

### Step 3. Set up VS Code

1. **Extensions.**

   ```bash
   code --install-extension james-yu.latex-workshop
   code --install-extension anthropic.claude-code
   ```

   | Line | What it does | Needed? |
   |------|--------------|---------|
   | `code --install-extension james-yu.latex-workshop` | Installs LaTeX Workshop: builds on save with the recipe in the workspace file, a PDF preview tab, a list of errors that link to the line, and SyncTeX (click in the PDF to jump to the source, and back). | Only for LaTeX |
   | `code --install-extension anthropic.claude-code` | Installs the Claude Code extension: Claude's proposed edits open as side-by-side diffs in the editor, and Claude can see the file and lines you have selected. If it does not connect, type `/ide` in Claude. | Optional; Claude runs in the terminal without it |

   If the terminal says `code: command not found`, open the Command Palette
   (Cmd+Shift+P) and run "Shell Command: Install 'code' command in PATH".
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

What it does: copies `global/` into `~/.claude/`, the folder Claude Code reads in every
session: your personal rules (`CLAUDE.md`), permissions and hooks (`settings.json`,
`hooks/`), and seven slash commands (`commands/`). It never overwrites a file you already
have; it lists each file as `copied` or `skipped`. Each file is described in
[What each file does](#what-each-file-does).

Needed? Optional, recommended. To drop one piece later, delete its file from
`~/.claude/`; for a hook, also delete its entry in `~/.claude/settings.json`.

What it gets you: the rules, safety settings and commands apply in every project without
being repeated. If you already have a `~/.claude/CLAUDE.md` or `settings.json`, paste
`prompts/merge-existing-setup.md` into a Claude session to merge the two safely.

Then open `~/.claude/CLAUDE.md` and edit it: it is yours. Every rule there applies in
every session of every project.

### Step 5. Create a project

One project (a paper, a course, a grant) is one folder, one git repo and one VS Code
window.

```bash
scripts/new-project.sh ~/Documents/my-paper
code ~/Documents/my-paper/my-paper.code-workspace
```

| Line | What it does | Needed? |
|------|--------------|---------|
| `scripts/new-project.sh ~/Documents/my-paper` | Creates the folder (it stops if the folder exists and is not empty), copies `project-template/` into it, renames the workspace file to `my-paper.code-workspace`, writes the project name into `CLAUDE.md`, `README.md` and the workspace file, and runs `git init`. It does not commit. | Optional: you can create the same files by hand |
| `code ~/Documents/my-paper/my-paper.code-workspace` | Opens the project in its own VS Code window with the workspace's settings. Open this file each time, not the folder: opening the folder skips the workspace settings. | Required to get the workspace settings |

What it gets you: every project starts with the same structure, so you and Claude find
things in the same place in each one. For an existing project, copy the pieces you want
into it instead (`CLAUDE.md`, `notes/`, `.claude/settings.json`, the workspace file).

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

What it does: starts Claude Code in the terminal's current folder. That folder and its
subfolders are what Claude can read and edit, so always start it from the project's root;
the VS Code terminal opens there. Required. Type `/exit` to leave.

What it gets you: Claude sees the whole project. It reads, edits, compiles and commits the
files itself, so nothing is pasted. In the first session type `/init`: Claude reads the
folder and fills in `CLAUDE.md`. Then correct what it wrote.

### Step 7. Know what each context document is for


| File                     | Read by               | Holds                                                                         |
| -------------------------- | ----------------------- | ------------------------------------------------------------------------------- |
| `CLAUDE.md` (repo root)  | Claude, every session | What the project is, folder map, how to build, conventions, what not to touch |
| `README.md`              | People and Claude     | What it is, setup, contents, usage, who. Ask Claude to keep it current        |
| `notes/<task>.md`        | One task              | The task's state, so a fresh session can resume from it alone                 |
| `style/writing-style.md` | Claude, when writing  | Your rules for notes, summaries and drafts                                    |
| `~/.claude/CLAUDE.md`    | Claude, every project | Your personal rules                                                           |

A task file is started at the beginning of the task, not written up at the end, and
Claude updates it as it works. The skeleton is in
`project-template/notes/_task-template.md`.

### Step 8. Run your first task end to end

`/start-task`, `/compile-tex` and `/wrap-up` are the sample commands installed in Step 4.
Without them, type the same request in plain words; the commands only save the typing
and make the steps the same every time.

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
   repeated workflow into `/name`, usable in every project. The seven in
   `global/commands/` are starting points: three for everyday work (`/start-task`,
   `/wrap-up`, `/compile-tex`) and four larger workflows from Part 4 (`/papersummarize`,
   `/zotero`, `/press`, `/debrief`). Write your own the third time you type the same
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
   - read permission removed at the operating-system level, so a command that slips past
     Claude's rules still fails (Claude's rules are policy; file permissions are enforced
     by the system):

     ```bash
     chmod -R go-rwx confidential/   # other accounts on this Mac: no access
     chmod -R u-r confidential/      # your own account, so Claude too: no reads
     chmod -R u+r confidential/      # undo the line above when you need the files
     ```

     `-R` applies the change to the folder and everything in it. The first line removes
     read, write and open rights for other accounts (`g` group, `o` others); it is
     optional on a Mac only you use. The second removes your own read right (`u` user),
     so every program running as you, Claude included, gets "Permission denied"; use it
     while Claude works in the project. The third restores your access. The project's
     `.claude/settings.json` also denies shell commands that name `confidential/`, so
     Claude cannot run the obvious `chmod` that would undo the lock;
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
   every repo. Generic version: `global/commands/press.md`.
2. **Meetings to assigned tasks.** A small package I wrote
   ([debriefr](https://github.com/alopezespino/debriefr)) and a `/debrief`
   command: the recording becomes a transcript with speakers identified, then a summary
   with an action-items table (owner, task, due date, priority), then GitHub issues
   assigned to each owner on the project board. After a coauthor meeting, the next steps
   are assigned before anyone retypes notes. Generic version:
   `global/commands/debrief.md`.
3. **A personal control center.** A plain-Markdown repo with inbox, tasks, projects,
   archive and journal folders. I drop a scan in the inbox and Claude files it; a planner
   command reads open tasks and deadlines and proposes the day, and scheduled runs do it
   each morning. Sensitive folders are protected as in Part 3, item 7: filenames visible,
   contents not.
4. **A literature pipeline.** PDFs become Markdown, then LaTeX working notes in one folder
   per paper, named by citation key and written to my summary style guide. Scripts keep
   the reference manager in sync with the project's `.bib` file and check for newer
   versions of working papers. Generic versions: `global/commands/papersummarize.md` and
   `global/commands/zotero.md`.
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
