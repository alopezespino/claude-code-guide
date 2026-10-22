# Claude Code + VS Code: a setup that keeps Claude focused

## Unsure about AI in your work?
If you are not sure whether to bring AI into your
workflow, how to use it and still keep control, integrity and authorship of your work,
or whether it will get in the way of your own learning, read [codingCS](https://github.com/alopezespino/codingCS)'s section
[Using AI as a Coding Companion](https://github.com/alopezespino/codingCS/blob/main/AI-TOOLS.md)
first.

### What this guide assumes.
You use Claude in the chat app and want to move to Claude
Code. You can work in a terminal (move between folders, run a command, read its
output), use git and GitHub (commit, push, pull), and open and edit files in VS Code.
Writing R, Python or LaTeX helps with some examples but is not required. If you need a
refresher on VS Code, the terminal, R or Python, or want a more basic setup of Claude
Code first, start with [codingCS](https://github.com/alopezespino/codingCS) and come
back here.

> **Made and tested for macOS.** The install commands (Homebrew), the hooks (macOS
> notifications, `trash`) and the key storage (the macOS Keychain) assume a Mac. The
> working method in Parts 2 to 4 applies on any system, but on Linux or Windows the
> commands and example files need changes.

A step-by-step guide for researchers who want to move from Claude's chat app to Claude Code. It works with any programming language; examples use LaTeX where they help. The setup needs only the tools and files of Part 1, made by hand; the subsequent parts and the files in this repository are optional examples of my own preferences.

### Why this fixes "Claude goes off track."
In chat, the only context is the
conversation, and it drifts as the conversation grows. In Claude Code the context is files
on disk: the repo, written rules, and a notes file per task, all re-read every session.
Everything below makes that context explicit.

### If you do only five things:
one repo per project with Claude running in its terminal;
a `CLAUDE.md` in the repo; a global `CLAUDE.md` with your own rules; one task per session;
a notes file per task.

### Built into Claude Code, or mine.
Claude Code comes with its own slash commands
(`/init`, `/clear`, `/compact` and others), keys (Shift+Tab, Esc Esc) and features
(permissions, hooks, custom slash commands, memory, subagents). Everything in this
repository is mine: slash commands, hooks, scripts and templates I wrote for my own work,
shared as optional examples. The guide calls the first kind *built-in* and the second
*my example*; each example links to its file. Other tools (git, gh, latexmk, marker,
Zotero) are named as such.

## Contents

- [What is in this repository](#what-is-in-this-repository)
- [Part 1. Setup, step by step](#part-1-setup-step-by-step)
  - [Optional: start from my example files](#optional-start-from-my-example-files)
- [Part 2. Best practices: fewer tokens, a smarter Claude](#part-2-best-practices-fewer-tokens-a-smarter-claude)
  - [Leverage Claude's capabilities with slash commands](#leverage-claudes-capabilities-with-slash-commands)
- [Part 3. Easy extras with a large payoff](#part-3-easy-extras-with-a-large-payoff)
- [Part 4. Advanced use cases](#part-4-advanced-use-cases)
- [License](#license)

## What is in this repository

```
claude-code-guide/
├── README.md                    this guide
├── LICENSE                      MIT
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
│   └── commands/                my slash commands, not built into Claude Code
│       ├── start-task.md        /start-task: open a notes file for a task
│       ├── wrap-up.md           /wrap-up: update notes and lessons before /clear
│       ├── compile-tex.md       /compile-tex: build, fix, repeat until clean
│       ├── papersummarize.md    /papersummarize: a paper into LaTeX working notes
│       ├── zotero.md            /zotero: manage a Zotero library via its Web API
│       ├── press.md             /press: one canonical copy of each shared script
│       ├── debrief.md           /debrief: meeting recording to summary and issues
│       └── ra-check.md          /ra-check: progress on issues you assigned
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
│   ├── litrev/GUIDELINES.md     standard for paper summaries
│   └── style/writing-style.md   writing-style guide skeleton
└── prompts/
    ├── build-style-guide.md     derive your style guide from your own writing
    └── merge-existing-setup.md  merge these files into an existing ~/.claude
```

None of these files is needed to follow the guide. They are my own setup, made generic:
a starting point you can install in one step and then change. How to install, revise and
customize them, and what each one does, is in
[Optional: start from my example files](#optional-start-from-my-example-files).

---

## Part 1. Setup, step by step

**What is required.** Steps 1 to 4: the tools, VS Code, a project folder under git, and
Claude Code running in it. They use nothing from this repository. Steps 5 and 6 are the
way of working that keeps Claude on track: recommended, and also done by hand. Everything
else in this guide, including every file in this repository, is optional. Every slash
command in Steps 1 to 6 (`/init`, `/permissions`, `/clear`, `/ide`, `/exit`) is built
in; the only commands of mine in Part 1 are named in the optional section at its end.

Each command block is followed by what each line does, whether you need it, and what it
gets you. "Required" means a later step depends on it.

### Step 1. Install the tools (macOS)

**Homebrew.** Homebrew is a package manager for macOS: one command-line tool that
downloads, installs and updates other software, both command-line tools and desktop apps.
This guide uses it so that every tool below installs with one `brew install` line and
updates with `brew upgrade`, instead of a separate installer and update routine for each
tool. Check whether you have it with `brew --version`. If not:

```bash
url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
/bin/bash -c "$(curl -fsSL "$url")"
```


| Line                                  | What it does                                                                                                                                                                                                                          | Needed?               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `url=...`                             | Stores the address of Homebrew's official install script in a variable, so the next line stays short enough to paste safely.                                                                                                          | Only without Homebrew |
| `/bin/bash -c "$(curl -fsSL "$url")"` | Downloads the script and runs it. `curl` flags: `-f` stop on a server error, `-s` no progress bar, `-S` still show errors, `-L` follow redirects. It asks for your Mac password and may install Apple's command-line developer tools. | Only without Homebrew |

When it finishes, it prints "Next steps": lines that add `brew` to your shell's PATH. Run
them, or a new terminal will not find `brew`.

**The tools.**

```bash
brew install git gh claude-code
brew install --cask visual-studio-code
brew install --cask mactex-no-gui
gh auth login
```


| Line                                     | What it does                                                                                                                                                                                                       | Needed?                                               |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `brew install git gh claude-code`        | Installs three command-line tools: `git` (version control; newer than the one Apple ships), `gh` (GitHub from the terminal: log in, create repos, issues, pull requests) and `claude-code` (the `claude` command). | Required                                              |
| `brew install --cask visual-studio-code` | Installs VS Code (`--cask` means a desktop app) and its `code` command for the terminal.                                                                                                                           | Required, unless VS Code is installed                 |
| `brew install --cask mactex-no-gui`      | Installs TeX Live without its desktop apps: the TeX engines, `latexmk` and `biber`. Several GB. Open a new terminal afterwards so the TeX commands are found.                                                      | Only for LaTeX, and only if `latexmk --version` fails |
| `gh auth login`                          | Logs you in to GitHub through the browser (choose GitHub.com, HTTPS, and "Login with a web browser") and sets git to use that login.                                                                               | Required to push to GitHub                            |

What it gets you: one editor, one version-control setup and one GitHub login, with no
passwords or tokens to manage by hand; Claude can then create repos, commits and issues
for you.

Claude Code needs a paid Claude plan; the first `claude` run opens the browser to log in.

### Step 2. Set up VS Code

1. **Extensions.**

   ```bash
   code --install-extension james-yu.latex-workshop
   code --install-extension anthropic.claude-code
   ```


   | Line                                               | What it does                                                                                                                                                                                                  | Needed?                                          |
   | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
   | `code --install-extension james-yu.latex-workshop` | Installs LaTeX Workshop: builds on save (with latexmk by default), a PDF preview tab, a list of errors that link to the line, and SyncTeX (click in the PDF to jump to the source, and back).                 | Only for LaTeX                                   |
   | `code --install-extension anthropic.claude-code`   | Installs the Claude Code extension: Claude's proposed edits open as side-by-side diffs in the editor, and Claude can see the file and lines you have selected. If it does not connect, type `/ide` in Claude. | Optional; Claude runs in the terminal without it |

   If the terminal says `code: command not found`, open the Command Palette
   (Cmd+Shift+P) and run "Shell Command: Install 'code' command in PATH".
2. **Auto-save.** Claude edits files on disk. If the editor holds unsaved changes to the
   same file, the two versions conflict. Turn on auto-save: Settings (Cmd+,), search
   "auto save", choose `afterDelay`.
3. **GitHub sign-in.** Click the Accounts icon (bottom left), "Sign in with GitHub". The
   Source Control panel then shows every change Claude makes as a diff.
4. **The three panels you will use:** Explorer (files), Source Control (diffs and
   commits), and the integrated terminal (Ctrl+`), where Claude runs.

### Step 3. Create a project

One project (a paper, a course, a grant) is one folder, one git repo and one VS Code
window.

```bash
mkdir -p ~/Documents/my-paper
cd ~/Documents/my-paper
git init
code .
```


| Line                            | What it does                                                                                                                               | Needed?                |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `mkdir -p ~/Documents/my-paper` | Creates the project folder (`-p`: no error if it already exists). Any name and location work.                                              | Only for a new project |
| `cd ~/Documents/my-paper`       | Moves the terminal into the folder.                                                                                                        | Required               |
| `git init`                      | Makes the folder a git repository, so every change Claude makes can be reviewed and undone. Skip it if the folder is already a repository. | Required               |
| `code .`                        | Opens the folder in a new VS Code window.                                                                                                  | Required               |

Then, in VS Code, choose File > Save Workspace As... and save `my-paper.code-workspace`
inside the project folder. From then on, open the project with:

```bash
code ~/Documents/my-paper/my-paper.code-workspace
```

This opens the project in its own window with the workspace's settings. Open this file
each time, not the folder: opening the folder skips the workspace settings.

**What the workspace file does.** It holds VS Code settings for this project only. Open
it from the Explorer and add settings inside `"settings"`, for example:

```jsonc
{
  "folders": [{ "path": "." }],
  "settings": {
    "workbench.colorCustomizations": {
      "titleBar.activeBackground": "#2E5E4E"
    },
    "files.autoSave": "afterDelay"
  }
}
```


| Setting                                                                         | What it does                                                                                                                                                                                   | Needed?                           |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `workbench.colorCustomizations`                                                 | Colors this window's title bar. Pick a different color per project, so with several windows open you know which project you are typing in.                                                     | Optional                          |
| `files.autoSave`                                                                | Auto-save for this project, if you did not turn it on for all of VS Code in Step 2.                                                                                                            | Optional                          |
| An interpreter path, e.g. `"python.defaultInterpreterPath": "<env>/bin/python"` | Points the editor at the project's environment (a mamba/conda env or a venv). Name the same environment in `CLAUDE.md` (Step 4), so Claude runs code with the right tools instead of guessing. | Only for a project that runs code |

A LaTeX project needs no build setting: LaTeX Workshop runs latexmk by default. To build
with lualatex or xelatex, add a recipe (the example workspace file in
[the optional section](#optional-start-from-my-example-files) has one).

**What `.gitignore` does.** It lists what git does not track: build output (for LaTeX,
`*.aux`, `*.log`, `*.synctex.gz` and similar), system files such as `.DS_Store`, your
personal Claude settings (`.claude/settings.local.json`, Step 4), and any folder that
must never be committed, such as `confidential/`. Diffs stay readable and confidential
files stay out of the history. Claude writes it for you in Step 4.

What it gets you: each project is its own folder, history and window, so Claude's
context is that project and nothing else.

### Step 4. Start Claude in the terminal

Open the integrated terminal (Ctrl+`) and run:

```bash
claude
```

What it does: starts Claude Code in the terminal's current folder. That folder and its
subfolders are what Claude can read and edit, so always start it from the project's root;
the VS Code terminal opens there. Required. Type `/exit` to leave.

What it gets you: Claude sees the whole project. It reads, edits, compiles and commits the
files itself, so nothing is pasted.

**First requests in a new project.**

1. `/init`. Claude reads the folder and writes `CLAUDE.md` at the project root. Claude
   reads this file at the start of every session in the project, so it should say what
   the project is, where things are (a folder map), how to build or run it, which
   environment to use, the project's conventions, and what not to touch. Read what Claude
   wrote and correct it: whatever it gets wrong here, it gets wrong in every session.
   Recommended.
2. "Write a .gitignore for this project." Check that it covers what Step 3 lists.
   Recommended.
3. "Write a README.md: what this is, how to set it up, what is in it, how to use it, who
   is involved." For people and Claude alike. Optional.

**Your personal rules: `~/.claude/CLAUDE.md`.** Claude reads this file in every session
of every project. Create it:

```bash
mkdir -p ~/.claude
code ~/.claude/CLAUDE.md
```


| Line                       | What it does                                                                            | Needed?                    |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------- |
| `mkdir -p ~/.claude`       | Creates Claude Code's settings folder in your home directory, if it does not exist yet. | Required for the next line |
| `code ~/.claude/CLAUDE.md` | Opens the file in VS Code; saving it creates it.                                        | Recommended                |

Write a few rules that should hold everywhere, one short line each with its reason, for
example:

```markdown
- Keep answers short; I will ask for detail.
- Make minimal edits; do not touch files I did not mention.
- Ask before deleting a file or pushing to GitHub.
```

Add a rule the second time the same mistake happens
([Part 2](#part-2-best-practices-fewer-tokens-a-smarter-claude), item 13).

**Permissions.** By default Claude asks before each command and edit. At a prompt, the
"don't ask again" option saves that rule in the project's `.claude/settings.local.json`:
personal, and kept out of git by `.gitignore`. `/permissions` lists and edits the rules.
Rules everyone in a project should share go in `.claude/settings.json`, which is
committed; rules for every project go in `~/.claude/settings.json`. Each file can
`allow` a command without asking, always `ask`, or `deny` it.

What it gets you: rules stated once and followed everywhere; fewer prompts for safe
commands and hard stops for dangerous ones.

### Step 5. Know what each context document is for


| File                     | Read by               | Holds                                                                         |
| -------------------------- | ----------------------- | ------------------------------------------------------------------------------- |
| `CLAUDE.md` (repo root)  | Claude, every session | What the project is, folder map, how to build, conventions, what not to touch |
| `README.md`              | People and Claude     | What it is, setup, contents, usage, who. Ask Claude to keep it current        |
| `notes/<task>.md`        | One task              | The task's state, so a fresh session can resume from it alone                 |
| `style/writing-style.md` | Claude, when writing  | Your rules for notes, summaries and drafts                                    |
| `~/.claude/CLAUDE.md`    | Claude, every project | Your personal rules                                                           |

A task file is started at the beginning of the task, not written up at the end, and
Claude updates it as it works. Keep task files in a `notes/` folder (`mkdir notes`), each
with the same sections: Objective (what "done" means and how it will be checked),
Inputs, Outputs, Decisions, Progress, Surprises, Follow-ups. The style guide is optional;
Claude can draft one from your own writing
([Part 2](#part-2-best-practices-fewer-tokens-a-smarter-claude), item 12).

### Step 6. Run your first task end to end

Every step is a request in plain words.

1. "Start a notes file for this task: tighten the introduction. Write the objective and
   how we will know it is done, ask me at most three questions, and do not edit anything
   yet." Claude creates `notes/tighten-introduction.md`.
2. Press Shift+Tab until the mode reads Plan, and ask: "Plan the changes to the
   introduction." Read the plan; ask for changes until it is right; accept it.
3. Claude edits. Review the diffs in Source Control. Then: "Compile main.tex and fix the
   errors and warnings."
4. "Commit this with a short message."
5. "Update the notes file with progress, decisions, follow-ups and any lessons."
6. `/clear`. Next time: "Read notes/tighten-introduction.md and continue."

My example commands [`/start-task`](global/commands/start-task.md),
[`/compile-tex`](global/commands/compile-tex.md) and
[`/wrap-up`](global/commands/wrap-up.md) do steps 1, 3 and 5 in one word each, the same
way every time. They are not built into Claude Code; installing them is covered
[below](#optional-start-from-my-example-files).

### Optional: start from my example files

Steps 1 to 6 need nothing from this repository. The repository holds my own setup, made
generic: personal rules, permissions, two hooks, eight slash commands and a project
template, all written for how I work. I developed all of them with Claude Code itself,
so each one is also an example of using Claude to customize Claude and to make your own
work more productive. Installing them gives you a populated setup to revise instead of a
blank one. There are two ways to use them: install them as they are
and then edit the installed copies, or first make your own version of the kit, so every
project you create starts from your preferences rather than mine.

**Install the examples, then revise them.**

```bash
git clone https://github.com/alopezespino/claude-code-guide.git \
  ~/claude-code-guide
cd ~/claude-code-guide
scripts/preflight.sh
scripts/install-global.sh
scripts/new-project.sh ~/Documents/my-paper
```


| Line                                          | What it does                                                                                                                                                                                                                                                                                                                                                  | Needed?                                                               |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `git clone <url> ~/claude-code-guide`         | Downloads this repository into a folder in your home directory.                                                                                                                                                                                                                                                                                               | Required for the scripts below                                        |
| `cd ~/claude-code-guide`                      | Moves the terminal into that folder; the scripts are run from here.                                                                                                                                                                                                                                                                                           | Required for the scripts below                                        |
| `scripts/preflight.sh`                        | Checks for each tool the guide uses (brew, git, gh, claude, code, latexmk, biber, trash, micromamba) and prints `ok`, `MISSING` (required) or `-` (optional). Then prints versions, whether `gh` is logged in to GitHub, and which of `CLAUDE.md`, `settings.json`, `hooks`, `commands`, `skills` and `agents` already exist in `~/.claude`. Changes nothing. | Optional                                                              |
| `scripts/install-global.sh`                   | Creates `~/.claude/hooks` and `~/.claude/commands` if missing, copies each file from `global/` unless a file with that name already exists, makes the hooks executable, and lists each file as `copied` or `skipped`.                                                                                                                                         | Only to install the global examples                                   |
| `scripts/new-project.sh ~/Documents/my-paper` | Does Step 3 with the starter files: creates the folder (stops if it exists and is not empty), copies `project-template/` into it, renames the workspace file to `my-paper.code-workspace`, writes the project name wherever the templates say `PROJECT_NAME`, and runs `git init`. Does not commit. Then open it as in Step 3.                                | Only for a new project; for an existing one, copy the pieces you want |

If you already have a `~/.claude/CLAUDE.md` or `settings.json`, `install-global.sh` skips
them; paste `prompts/merge-existing-setup.md` into a Claude session to merge the two
safely.

The example rules, the `block-rm.sh` hook and `/zotero` delete files with `trash`, which
moves them to the Trash. Recent macOS versions include it; check with `command -v trash`,
and if nothing prints, run `brew install trash`.

Then revise what was installed. Every file is plain text; change it in place:

- `~/.claude/CLAUDE.md`: read every rule. Delete the ones you do not want, reword the
  rest, and add your own under "My preferences (edit these)".
- `~/.claude/settings.json`: add or remove commands in `allow`, `ask` and `deny`. To drop
  a hook, delete its entry under `hooks` and its script in `~/.claude/hooks/`.
- `~/.claude/commands/`: one Markdown file per slash command, written as instructions to
  Claude; the file name is the command's name. Delete the ones you will not use and edit
  the steps of the others.
- In each project: fill in the sections of `CLAUDE.md` (including the settings the
  example commands read, such as the bibliography file and literature folder), adjust
  `.claude/settings.json`, and pick a title-bar color in the workspace file.

To check what Claude loaded, use the last bullet of
[Part 2](#part-2-best-practices-fewer-tokens-a-smarter-claude), item 1.

**Make the kit yours first.** For every new project to start from your own preferences,
keep your own copy of this repository and edit it before running the scripts. Clone it
as above, or fork it on GitHub to keep your version under version control
(`gh repo fork alopezespino/claude-code-guide --clone`). Then:

1. Edit `global/`: your rules in `CLAUDE.md`, your permissions and hooks in
   `settings.json`, the commands you want in `commands/`. Delete what you do not want:
   the scripts copy whatever the folders hold.
2. Edit `project-template/`: the sections of `CLAUDE.md`, the `.gitignore`, the workspace
   settings, the notes skeleton. Leave `PROJECT_NAME` where a project's name belongs;
   `new-project.sh` replaces it.
3. Commit, then run `scripts/install-global.sh` and `scripts/new-project.sh <path>` from
   your copy.
4. Later changes: edit the template and commit. New projects get the change; `~/.claude`
   and existing projects do not, because the scripts never overwrite a file. Copy a
   changed file over by hand, or move the old one to the Trash and rerun the script.

#### What each example file does

"Recommended" marks the files with the largest payoff for the least effort.

**`global/`: installed into `~/.claude/`, applies to every project**


| File                         | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Needed?                                                                                                                                         | What it gets you                                                                    |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `CLAUDE.md`                  | Starter personal rules: short answers, minimal edits, `trash` instead of `rm`, a commit table before any push, no secrets in files, notes and lessons files, narrow reading, subagents, paste-safe commands, and a section for your own preferences.                                                                                                                                                                                                                                                     | Recommended; edit it freely                                                                                                                     | Claude follows your rules in every session without being told again                 |
| `settings.json`              | Permissions and hooks. `allow`: `git status`, `git diff`, `git log`, `ls` and `latexmk` run without asking. `ask`: `git push` always asks. `deny`: `rm -rf`, any command with `-shell-escape` (lets LaTeX run arbitrary programs), reading `~/.ssh` and `~/.aws` (keys), and editing your shell startup files and `~/.gitconfig`. `hooks`: registers the two scripts below.                                                                                                                              | Recommended                                                                                                                                     | Fewer prompts for safe commands; hard stops for dangerous ones                      |
| `hooks/notify-waiting.sh`    | Runs when Claude finishes a turn (`Stop`) or needs your input (`Notification`), and shows a macOS notification with the project's name. macOS may ask once whether to allow notifications.                                                                                                                                                                                                                                                                                                               | Optional; if it is too frequent, delete its `Stop` entry in `settings.json`                                                                     | You can leave Claude working and come back when it waits                            |
| `hooks/block-rm.sh`          | Runs before every shell command Claude starts. If the command runs `rm` with `-r`, `-f`, `--recursive` or `--force` (also after `sudo` or `xargs`, as `/bin/rm`, or on a later line), it blocks the command (exit code 2) and tells Claude to use `trash`. `git rm` is not affected. A safety net for the common forms, not a guarantee.                                                                                                                                                                                                                                                                                                   | Recommended; needs `trash` (preflight checks; `brew install trash` if missing)                                                                  | Every deletion can be recovered from the Trash                                      |
| `commands/start-task.md`     | Defines `/start-task <description>`: creates `notes/<task>.md` from the template, fills in the objective, inputs and outputs, adds the task to `notes/README.md`, asks at most three questions, and stops before doing the work.                                                                                                                                                                                                                                                                         | Optional                                                                                                                                        | Every task starts with a written definition of "done"                               |
| `commands/wrap-up.md`        | Defines `/wrap-up`: updates the task's notes (progress, decisions, surprises, follow-ups), adds lessons to `notes/lessons.md`, offers to commit, and prints how to resume.                                                                                                                                                                                                                                                                                                                               | Optional                                                                                                                                        | Nothing is lost at `/clear` or the end of a session                                 |
| `commands/compile-tex.md`    | Defines `/compile-tex <file>`: builds with latexmk, reads the log for errors and warnings, fixes them with minimal edits, and repeats (at most five rounds). For an exam or problem set, also checks that points add up.                                                                                                                                                                                                                                                                                 | Optional (LaTeX)                                                                                                                                | A clean build without reading the log yourself                                      |
| `commands/papersummarize.md` | Defines `/papersummarize <paper.pdf>`: converts the PDF to Markdown with marker (equations as LaTeX, cached by file contents), checks the citation key against the paper's first page, and writes LaTeX working notes in `litrev/<Key>/` with a fixed structure, quoting key definitions with page numbers. Never overwrites an existing summary. The bibliography file and literature folder come from CLAUDE.md; follows `litrev/GUIDELINES.md` when the project has it.                                                                                       | Optional (research); needs MacTeX, poppler and marker (install lines at the top of the file)                                                    | Papers read as text instead of page images, and every summary in the same structure |
| `commands/zotero.md`         | Defines `/zotero <subcommand>` (add, meta, papers, clean, dedup, attach, tags): works on a Zotero library through its Web API, with the API key in the macOS Keychain. Every write goes read, dry run, approval table, apply, re-read. Keeps old PDF versions, queues paywalled published versions for manual download, and lists the API's known traps.                                                                                                                                                 | Optional; needs pyzotero and a Zotero API key (install lines at the top of the file)                                                            | Bulk library edits that are shown to you before they are made                       |
| `commands/press.md`          | Defines `/press` with four modes: consolidate (turn a project's script into a template), deploy (copy a template into a new project), sync (update every copy) and check (report copies that differ). A manifest in the coordination repo (path set in `~/.claude/CLAUDE.md`, default `~/coordination`; created on first run after your approval) lists each template and where its copies live; scripts read per-project values from `project.yaml`. Shows a diff before overwriting a locally edited copy, never deletes, commits per project, never pushes without approval.                                  | Optional; useful once a script lives in two or more projects                                                                                    | A fix made once reaches every project                                               |
| `commands/debrief.md`        | Defines `/debrief <audio file>`: runs [debriefr](https://github.com/alopezespino/debriefr) to transcribe and identify speakers (you name unknown voices from short clips), writes a summary with an action-items table, and, after a dry run and your approval, syncs the items to GitHub issues on a Project board (the board needs `gh auth refresh -s project` once).                                                                                                                                                                                     | Optional; needs debriefr, a Hugging Face token, and an Anthropic key or a summary written in the session (install lines at the top of the file) | A meeting's next steps assigned without retyping notes                              |
| `commands/ra-check.md`       | Defines `/ra-check`, with optional arguments N (days), `all` and `owner/repo`: reads the open issues of a repository where you coordinate others' work, and for those overdue or due within N days (default 7) counts checked boxes, comments and commits to the task's folder. Prints each issue as on track, watch or nudge, a nudge list, and the comments that tag you and have no reply yet (added to the session's task list). Read-only. The due-date and checklist conventions it reads are listed at the top of the file, to edit. | Optional; needs `gh` logged in                                                                                                                  | Who needs a nudge, in a ten-second read, and no unanswered question left behind     |

**`project-template/`: copied into each new project**


| File                      | What it does                                                                                                                                                                                                                                                            | Needed?                                                | What it gets you                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `CLAUDE.md`               | Sections Claude reads at the start of every session: what the project is, a folder map, the build command, the environment, conventions, where notes live, and the settings the example commands read (main file, bibliography, literature folder, PDF converter, download queue).                                                                                                              | Recommended                                            | Claude knows the project from the first message                                             |
| `README.md`               | Five questions: what it is, how to set it up, what is in it, how to use it, who.                                                                                                                                                                                        | Recommended                                            | People and Claude get oriented quickly                                                      |
| `project.code-workspace`  | VS Code settings for this project only: a title-bar color, auto-save, a LaTeX recipe (latexmk with lualatex, SyncTeX on, errors reported as file:line, build files kept for faster rebuilds), a commented line for a code interpreter, and recommended extensions.      | Recommended                                            | Opening this file restores the project's setup; the color tells you which window you are in |
| `.gitignore`              | Keeps out of git: LaTeX build files, `confidential/`, `.claude/settings.local.json` (your personal approvals), `.DS_Store`, `.vscode/`.                                                                                                                                 | Recommended                                            | Clean diffs; confidential material is never committed                                       |
| `.claude/settings.json`   | Project permissions. `allow`: `latexmk`, `biber`, `git add`, `git commit`. `deny`: reading or editing `confidential/`, any shell command that names `confidential/`, editing `refs.bib` (it is exported from your reference manager). Committed, so coauthors share it. | Recommended when the project has confidential material | Fewer prompts, and the confidential folder is off limits to Claude                          |
| `notes/README.md`         | An index table of task files and their status.                                                                                                                                                                                                                          | Optional                                               | Open tasks at a glance                                                                      |
| `notes/_task-template.md` | Section skeleton for one task: objective, inputs, outputs, decisions, progress, surprises, follow-ups.                                                                                                                                                                  | Recommended                                            | A fresh session resumes from one file                                                       |
| `notes/lessons.md`        | Format for numbered lessons, with one example entry.                                                                                                                                                                                                                    | Optional                                               | A mistake is made once, not rediscovered                                                    |
| `litrev/GUIDELINES.md` | The standard for every paper summary: purpose, file naming, reading the PDF as Markdown, preamble and bibliography, section structure (with extra items for regression designs and reference works), annotation devices, figures, register, length and a done checklist. `/papersummarize` follows it when it exists. | Optional (research) | Every summary, by hand or by Claude, meets the same standard |
| `style/writing-style.md`  | Section skeleton for your writing rules: all documents, research notes, paper summaries, paper drafts, and the reference documents that show your style.                                                                                                                | Optional                                               | Claude writes in your voice                                                                 |

**`prompts/`: text to paste into a Claude session**


| File                      | What it does                                                                                                                                                                                         | Needed?                                                        | What it gets you                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- | ---------------------------------------------------- |
| `build-style-guide.md`    | Has Claude read documents you wrote yourself, describe the patterns with quoted examples, write them as rules into `style/writing-style.md`, and ask about what it is unsure of.                     | Optional                                                       | A first style guide in one session                 |
| `merge-existing-setup.md` | Has Claude back up your `~/.claude` files, classify each incoming rule as add, merge, conflict or skip, ask you about every conflict, write only after your approval, and verify in a fresh session. | Only if `~/.claude/CLAUDE.md` or `settings.json` already exist | The kit adopted without losing your existing rules |

---

## Part 2. Best practices: fewer tokens, a smarter Claude

Every turn re-sends the whole conversation. A long conversation costs more per turn and
drifts more. The rules below keep the conversation short and the files rich. They use
built-in keys, commands and features; where an item names a file of mine, it says so.

1. **Stay in control while you learn.**
   - **Default mode asks before every command and edit.** At that permission prompt,
     **Ctrl+E** gives a plain-language explanation of the command before you accept it
     (the prompt's footer shows the key). This is the best way to learn the terminal
     while in control.
   - **Shift+Tab** cycles the modes. Plan mode reads and proposes without editing: use
     it before any large change.
   - **Esc Esc** rewinds to an earlier point; **Ctrl+C** stops Claude mid-step;
     **Ctrl+O** opens the full transcript of what it ran and saw; **Ctrl+G** opens your
     editor for a long prompt.
   - **`@path/to/file`** in a prompt points Claude at a file.
   - **Read diffs before accepting.** Commit before and after each change, so any change
     can be undone with git.
   - To check that your rules loaded, start a new session and ask "Which of my CLAUDE.md
     rules apply to this task?"
2. **One task per session.** `/clear` at each task boundary; `/compact` at a natural break
   before a long session fills its context. `/rename <name>` names the session for its
   task, and `/resume` reopens it later.
3. **State lives in files, not in the transcript.** Ask Claude to write findings into the
   task's notes file as it finds them, and update the notes before `/clear`. The
   transcript is lost at `/clear`; the file is not.
4. **Point, do not paste.** Name the file and section (`@chapter3.tex`, "the proof of
   Lemma 2"). For a question about a long file, ask Claude to send a subagent to read it
   and report the answer, so the bulk text stays out of the main session.
5. **Subagents for reading in parallel, on cheaper models.** "Send three agents to read
   X, Y and Z and report back." A small model is enough for finding and quoting; keep the
   main model for synthesis and edits.
   *Use case: this guide was assembled by four agents reading in parallel: a student
   guide, an onboarding kit, research repos and a global configuration.*
6. **Match the model to the turn.** `/model` picks the model; `/effort` lowers the effort
   for routine turns, which saves usage.
7. **`/btw` for side questions.** `/btw what does this flag do?` gets an answer without
   pulling the main task off track.
8. **Say what "done" means.** "Done when it compiles with no warnings and every citation
   resolves" lets Claude check its own work. Use Plan mode for anything large: a rejected
   plan costs far less than a rejected implementation.
9. **Convert PDFs to Markdown before Claude reads them.** A converter such as
   [marker](https://github.com/datalab-to/marker) (an open-source tool, separate from
   Claude Code) turns math-heavy PDFs into text with the equations in LaTeX: cheaper and
   more accurate than page images. My example
   [`/papersummarize`](global/commands/papersummarize.md) runs it.
10. **Never let Claude poll a long job.** Each check is a full turn. Ask for a background
    command that exits when the job ends, so Claude is woken once.
11. **Memory for durable facts.** Claude Code keeps memory per project; say "remember
    that..." for preferences and facts that outlive the task (who is who, a journal's
    house style). Notes hold the task detail; memory holds the facts.
12. **Writing-style guides, one per document type.** Research notes, paper summaries and
    paper drafts each get their own rules (structure, notation, tone, punctuation). Build
    them from your own pre-AI writing with my example prompt
    [`prompts/build-style-guide.md`](prompts/build-style-guide.md): Claude reads a
    few documents you wrote by hand, drafts the rules, and you correct them.
    *Use case: a paper summary comes out with the same structure and voice as the ones I
    wrote by hand years earlier.*
13. **Global rules that carry an origin.** `~/.claude/CLAUDE.md` is loaded in every
    session of every project, so keep it to rules that apply everywhere and move project
    detail into the repo's `CLAUDE.md`. Give each rule a reason, and an "Origin" line
    (date, what went wrong) when it comes from a real mistake. Add a rule the second time
    the same mistake happens. A rule without a reason gets ignored or argued away.
14. **A lessons log and numbered decisions.** `notes/lessons.md` holds numbered entries
    with symptom, cause, fix and the rule it implies; lessons that hold everywhere move to
    the global `CLAUDE.md`. Decisions D1, D2, ... in a task file stop the same choice from
    being re-argued every session.
15. **Precise language in notes.** Numbers instead of adjectives ("compiles in 40 s, 3
    warnings left", not "almost there"). Later sessions read notes as fact.

### Leverage Claude's capabilities with slash commands

A word typed after `/` at the start of a prompt runs a slash command. Type `/` alone to
see them all with a one-line description. Every command in the table below is built into
Claude Code; none comes from this repository. Commands you add yourself, such as my
examples (Part 3, item 3), appear in the same list. These are the built-in ones I use
most, in the order a session meets them.


| Command                   | What it does                                                                                                                                                                | When I use it                                                                                    |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `/rename <name>`          | Names the session.                                                                                                                                                          | First thing in every session, after its task, so `/resume` finds it later                        |
| `/color <color>`          | Sets the color of the session's prompt bar.                                                                                                                                 | With several sessions open side by side                                                          |
| `/model`                  | Picks the model for the session.                                                                                                                                            | The top model for synthesis and edits; a smaller one for routine work                            |
| `/effort`                 | Sets how much the model reasons before answering.                                                                                                                           | Lower for routine turns (it saves usage), higher for a hard proof or a subtle bug                |
| `/btw <question>`         | Answers a side question without adding it to the main task.                                                                                                                 | "What does this flag do?" in the middle of a task                                                |
| `/context`                | Shows how full the context is, as a colored grid.                                                                                                                           | To decide between `/compact` and `/clear`                                                        |
| `/compact [what to keep]` | Replaces the conversation so far with a summary, which frees context. The optional text says what the summary must keep, e.g. `/compact keep the decisions and file paths`. | At a natural break in a long task, before automatic compaction happens at a worse moment         |
| `/clear`                  | Starts a new session with an empty context. The old session stays on disk and `/resume` reopens it.                                                                         | At every task boundary, after the notes file is up to date                                       |
| `/resume`                 | Lists past sessions and reopens one with its conversation. From the terminal, `claude --continue` reopens the most recent one.                                              | To continue a task the next day                                                                  |
| `/remote-control`         | Lets you continue this session from your phone or claude.ai/code.                                                                                                           | To approve a step or answer a question while away from the desk                                  |
| `/usage`                  | Shows the session's cost, how much of your plan's limits is used, and activity.                                                                                             | Before starting a long task                                                                      |
| `/insights`               | Writes a report that analyzes your past Claude Code sessions.                                                                                                               | Every few weeks, to find habits worth changing and repeated mistakes worth a rule in `CLAUDE.md` |
| `/tasks`                  | Lists what is running in the background (commands, agents) and lets you stop it.                                                                                            | Before starting a watcher, to check that one is not already running                              |
| `/init`                   | Reads the project and writes `CLAUDE.md` (Step 4).                                                                                                                          | Once per project, then I correct what it wrote                                                   |
| `/memory`                 | Opens the `CLAUDE.md` files and memory settings for editing.                                                                                                                | To fix a rule Claude keeps misreading                                                            |
| `/permissions`            | Lists and edits the `allow`, `ask` and `deny` rules (Step 4).                                                                                                               | When Claude asks about the same safe command over and over                                       |
| `/ide`                    | Connects Claude to VS Code, so edits open as diffs in the editor.                                                                                                           | When the extension does not connect by itself                                                    |
| `/exit`                   | Leaves Claude Code.                                                                                                                                                         | At the end of the day                                                                            |

---

## Part 3. Easy extras with a large payoff

Each item is a built-in feature (or, in items 6 and 7, a GitHub or macOS one). The files
named are my examples of using it.

1. **Permissions files.** Permissions are built in (Step 4). My example files
   [`global/settings.json`](global/settings.json) and
   [`project-template/.claude/settings.json`](project-template/.claude/settings.json)
   hold an allow list for routine safe commands (latexmk, git status, git diff), so
   Claude stops asking; an ask list (`git push` always asks); and deny rules for what
   Claude must never do (`-shell-escape`, reading `~/.ssh`, reading the project's
   `confidential/` folder).
2. **Hooks.** Claude Code runs a script of your choice at fixed points, such as before
   each shell command or when it waits for you (a built-in feature; the scripts are
   yours). My two example hooks, registered in
   [`global/settings.json`](global/settings.json):
   - [`notify-waiting.sh`](global/hooks/notify-waiting.sh): a macOS notification when
     Claude finishes or needs you, so you can walk away while it works;
   - [`block-rm.sh`](global/hooks/block-rm.sh): refuses `rm -r` and `rm -f`, so Claude
     uses `trash` and every deletion can be recovered from the Trash.
3. **Your own slash commands.** Claude Code turns any Markdown file in
   `~/.claude/commands/` into the command `/name`, usable in every project (built in).
   The eight in [`global/commands/`](global/commands/) are mine, as starting points:
   three for everyday work ([`/start-task`](global/commands/start-task.md),
   [`/wrap-up`](global/commands/wrap-up.md),
   [`/compile-tex`](global/commands/compile-tex.md)) and five larger workflows from
   Part 4 (`/papersummarize`, `/zotero`, `/press`, `/debrief`, `/ra-check`). Write your
   own the third time you type the same instructions.
   *Use cases: compile a .tex file and fix warnings until clean, checking that an exam's
   point totals add up; revise a .tex file with minimal edits, then recompile; summarize a
   paper into LaTeX working notes.*
4. **Named, colored sessions.** `/rename` per task and `/color` per session, so several
   sessions running side by side are easy to tell apart and to find again with `/resume`.
5. **`/remote-control`.** Continue the same session from your phone or claude.ai/code, for
   example to approve a step while away from the desk.
6. **GitHub issues as the task list** (GitHub features). One issue per task; `closes #N` in the commit that
   finishes it closes the issue. A GitHub Projects board gives the overview.
7. **Guardrails for confidential data.** Three layers, each easy:
   - deny rules in Claude's permissions for confidential folders, so Claude does not read
     them (my example:
     [`project-template/.claude/settings.json`](project-template/.claude/settings.json));
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

What I do with this setup once the basics are habit. The commands and files named below
are my own, written to work on my machines and in my projects: read them as examples
and change them as you need. None of them is needed for the setup. The requirements are
[Part 1, Steps 1 to 4](#part-1-setup-step-by-step); everything else is optional. Each
item says which parts are built into Claude Code, which are my examples in this
repository (linked), and which are tools of mine that this repository does not include.

1. **One copy of every shared script.** A script reused in several projects lives once,
   in a templates folder of a coordination repo. A slash command of mine
   ([`/press`](global/commands/press.md)) copies it into each project and reports copies
   that have drifted, so a fix made once reaches every project. The scripts read
   project-specific values (environment name, paths) from a small per-project config
   file instead of hardcoding them, so the same copy runs in every repo. Generic version:
   [`global/commands/press.md`](global/commands/press.md).
2. **Meetings to assigned tasks.** A small package I wrote
   ([debriefr](https://github.com/alopezespino/debriefr)) and a slash command of mine
   ([`/debrief`](global/commands/debrief.md)): the recording becomes a transcript
   with speakers identified, then a summary with an action-items table (owner, task, due
   date, priority), then GitHub issues assigned to each owner on the project board. After
   a coauthor meeting, the next steps are assigned before anyone retypes notes. Generic
   version: [`global/commands/debrief.md`](global/commands/debrief.md).
3. **Checking on research assistants.** I coordinate research assistants through
   GitHub issues: one issue per task, with a due date and a checklist of steps, and a
   folder in the repository where the assistant pushes the work. That repository is a
   separate one for the assistants, parallel to the main project repository: it holds
   only their task folders, the inputs each task needs and the work they hand back. The
   assistants never change the main repository, each one sees only what the task needs,
   and every change they make sits in one small place that I review before bringing it
   into the project. A slash command of mine
   ([`/ra-check`](global/commands/ra-check.md)) reads the open issues, their comments and
   the commits to each task's folder, and prints each issue as on track, watch or nudge,
   with a nudge list and the comments that tag me and still have no reply. It changes
   nothing. My morning planning run (item 4) folds its output into the day's plan.
   Generic version: [`global/commands/ra-check.md`](global/commands/ra-check.md).
4. **A personal control center.** A plain-Markdown repo with inbox, tasks, projects,
   archive and journal folders. I drop a scan in the inbox and Claude files it; a planner
   command of mine reads open tasks and deadlines and proposes the day, and a scheduled
   job on my Mac runs it each morning (neither is in this repository). Sensitive folders are protected as in
   [Part 3](#part-3-easy-extras-with-a-large-payoff), item 7: filenames visible, contents
   not.
5. **A literature pipeline.** PDFs become Markdown, then LaTeX working notes in one folder
   per paper, named by citation key and written to my summary guidelines (generic
   version:
   [`project-template/litrev/GUIDELINES.md`](project-template/litrev/GUIDELINES.md)).
   Scripts of mine keep the reference manager (Zotero) in sync with the project's `.bib`
   file and check for newer versions of working papers. Generic versions:
   [`global/commands/papersummarize.md`](global/commands/papersummarize.md) and
   [`global/commands/zotero.md`](global/commands/zotero.md).
6. **Several sessions working in parallel.** Independent tasks run in separate sessions,
   each on its own git branch (a worktree), and the sessions message each other: a
   dependent task starts when its predecessor sends its handoff (commit hashes, counts).
   Background sessions (`claude --bg`), worktrees (`claude --worktree`) and messages
   between sessions are built in. The protocol on top is mine and not in this
   repository: one manager session relays to me only what needs my decision, and every
   session records its lessons before it closes.
7. **Laptop to cluster.** Code developed on fake data locally runs on a computing
   cluster. Long jobs save checkpoints so a kill loses one step, not the run. A watcher
   script of mine (not in this repository) runs as a built-in background command and
   wakes Claude only when the job finishes or fails, so waiting costs no tokens.
8. **Fresh-eyes reviews.** A new subagent (built in) that has not seen my reasoning reads
   a draft, a proof or a set of results and reports what is wrong. It does not anchor on my
   conclusions the way the working session does.
9. **Onboarding someone else.** A starter rules file plus a prompt that merges it into the
   other person's existing setup: back up first, classify each rule as add, merge,
   conflict or skip, ask about every conflict, write only after approval, then verify in a
   fresh session with test questions. This repository is that kit:
   [`global/CLAUDE.md`](global/CLAUDE.md) and
   [`prompts/merge-existing-setup.md`](prompts/merge-existing-setup.md).

---

## License

[MIT](LICENSE): use, copy and change any of it, keeping the copyright notice.
