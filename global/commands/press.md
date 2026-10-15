---
description: Keep one canonical copy of each shared script and sync it to its projects
argument-hint: [consolidate | deploy | sync | check] [template] [paths...]
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Manage the shared scripts kept as templates in the coordination repo: $ARGUMENTS

Prerequisites: a git repo that holds the canonical copies, with a `templates/` folder in
it; and git in every project that receives a copy. The repo's path is the one my
`~/.claude/CLAUDE.md` names on a line "Coordination repo for the example `/press`
command: <path>"; if there is no such line, it is `~/coordination`. Below,
`~/coordination` stands for that path.

First run: if the repo, `templates/` or `templates/press.yaml` does not exist, say so
and offer to create them (`git init`, a manifest holding `templates: {}`, and a first
commit). Create nothing without my approval.

## Layout

Each template is a folder `~/coordination/templates/<name>/` holding its files and a
`README.md` that lists the config keys it reads. The manifest
`~/coordination/templates/press.yaml` records every copy:

```yaml
templates:
  my-tools:
    description: Shell helpers to run jobs and check the environment
    files: [run-job, check-env, README.md]   # what gets copied
    instances:
      - project: ~/projects/paper-a           # the project's repo root
        dir: tools                            # destination inside the project
        ignore: [README.md]                   # listed files never copied here
        synced: 3f2a9c1                       # coordination commit last copied
        deployed: 2026-01-15
```

Templates never hardcode a project value. Each project keeps a small `project.yaml` at
its repo root, and a template reads what it needs from there:

```yaml
# ~/projects/paper-a/project.yaml
environments:
  laptop:  {env: paper-a}
  cluster: {env: paper-a, python: ~/envs/paper-a/bin/python3}
paths:
  data: ~/data/paper-a
```

A script finds the repo root with `git rev-parse --show-toplevel`, picks the entry for
the machine it runs on by a rule its README states (for example, the hostname prefix),
and, if a key is absent, uses a default its README documents or stops with a message
naming the key. It never guesses. The same copy then runs unchanged in every project.

With no arguments, list the four modes and one line per template: name, description,
number of copies.

## Modes

### consolidate <name> <path1> [path2 ...]

Turn variants of one script, scattered across projects, into a single template.

1. Read every file in each path and diff the variants against each other.
2. Separate the shared logic from project-specific values (paths, environment names,
   repo names). Show me the differences in a short table.
3. Propose the canonical version: all shared logic kept, each project-specific value read
   from `project.yaml` and documented in the README. Ask me before writing.
4. Write `templates/<name>/`, add one manifest instance per source path, and list the
   `project.yaml` lines each source project needs.
5. Commit in the coordination repo, then offer to `sync` the source projects.

### deploy <name> <project> [dir]

Install a template in a project that does not use it yet.

1. Stop if `templates/<name>/` does not exist or `<project>` is not a git repo.
2. Copy the files to `<project>/<dir>` (default `<name>/`). If a file there already
   exists and differs, show the diff and ask.
3. Show the `project.yaml` lines the README requires and add them after I approve.
4. Record the instance in the manifest, commit as in `sync`, and remind me of any
   post-install step the README names.

### sync [name]

Copy the canonical version to every copy of every template, or of `<name>` only.

1. Stop if `templates/` has uncommitted changes, so that `synced` always names real
   content. Ask me to commit first.
2. Run `check`. For each copy that is behind, summarize what changes. For each copy that
   was edited locally, show the full diff and ask me: merge the edit into the canonical
   (then sync again), overwrite it, or skip this copy.
3. After my approval, copy the files, keeping permissions (executable bits). Skip files
   in `ignore`. If the project's `project.yaml` lacks a key the README requires, show
   the lines and add them.
4. Never delete a file in a project. If a file left the template, report the old copy
   and leave it in place.
5. Commit in each project separately, staging only the files written, by path, with the
   message `<name>: sync from coordination <commit>`. Never push without my approval.
6. Update `synced` and `deployed` in the manifest and commit it in the coordination repo.

### check [name]

Report drift without changing anything. Compare each file of each copy and classify:

- **clean**: identical to the current canonical;
- **behind**: identical to the canonical at its `synced` commit
  (`git -C ~/coordination show <synced>:templates/<name>/<file>`), so only the
  canonical changed; safe to sync;
- **edited locally**: differs from both; show the diff and say whether the edit looks
  like a fix worth merging into the canonical;
- **missing**: the project, the destination folder or a listed file does not exist.

Skip the files listed in a copy's `ignore`. End with one line per template giving the
count in each class.

## Rules

- Re-read the manifest at the start of every run; write it back after any mode that
  changes it, with templates in alphabetical order.
- Fix the canonical copy, never a deployed one. If I ask for a fix in a project's copy,
  make it in `templates/<name>/`, commit it, then `sync`.
- Use the project paths in the manifest exactly as written. If one does not exist,
  report it as missing; never search the disk for a similar folder.
- Show a diff and ask before writing any file outside the coordination repo.
- Never delete files anywhere. Report what should go and let me remove it.
- Before committing in a project, run `git status` on the paths to commit; uncommitted
  edits there count as edited locally, so ask first.
- Use absolute paths in every diff and copy.
