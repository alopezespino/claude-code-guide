# Coordination repo (example)

> Example folder from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide): the layout
> the example `/press` command (`global/commands/press.md`) expects.

A coordination repo is a git repo that holds the canonical copy of each script you
share across projects. Projects receive copies; fixes are made here and synced out, so
the copies never drift apart unnoticed.

```text
coordination/
└── templates/
    ├── press.yaml        manifest: each template and every project that holds a copy
    └── tlog/             one template: a logging helper in shell, R and Python
        ├── README.md     what it does and the project.yaml keys it reads
        ├── tlog.sh
        ├── tlog.py
        └── tlog.R
```

## Set it up

1. Copy this folder to `~/coordination` (or another path; then name that path in
   `~/.claude/CLAUDE.md` on the line "Coordination repo for the example `/press`
   command: <path>").
2. Replace the fictional instances in `templates/press.yaml` with your own projects, or
   set it to `templates: {}` and let `/press deploy` add them.
3. `git init`, then commit, so every `synced` value names a real commit.

## How it is used

- `/press deploy tlog ~/projects/paper-a tools/tlog` copies the template into a project
  and records the copy in the manifest.
- `/press check` reports each copy as clean, behind, edited locally or missing.
- `/press sync tlog` brings every copy up to the canonical version, asking before it
  overwrites a local edit.
- `/press consolidate <name> <path1> <path2>` turns variants of one script into a new
  template.

## No hardcoded project values

A template never names a project's paths or environments. Each project keeps a
`project.yaml` at its repo root, and the template reads the keys its README lists, with
a documented default when a key is absent. The `tlog` template shows this with one
optional key, `paths.logs`: the same file runs unchanged in every project, and only
`project.yaml` differs.
