# Delegating to sub-agents (Claude Code) — cheatsheet

A reference for handing work to sub-agents without permission stalls. Written 2026-06-26.

## Quickstart

**Default move: don't write the launch prompt — just ask Claude to do it.** Describe
the task; Claude reads `settings.json`, predicts the needed permissions, launches the
agent, and relays the result. (Only write your own prompt when you need it for a fresh
session where this Claude isn't present — use the templates at the bottom.)

Three rules that keep it stall-free and safe:

1. **Recon → read-only.** "Use a read-only agent…" *cannot* stall (nothing it does
   needs approval). This covers most delegation.
2. **Mutating work → preview first.** Ask Claude to show the agent prompt **and** the
   exact `permissions.allow` lines it would add *before* launching. Glance, approve,
   go. (Dry-run before bulk action.)
3. **Predict narrowly — never blanket.** Pre-authorize *specific* command patterns,
   not `Bash(*)`. A blanket grant guarantees no stall by dismantling the safety net.
   If an agent hits one unforeseen command, it reports back, add that one line, move on.
   Reactive-and-narrow beats blanket-and-broad.

Everything below is detail for when you want it.

## Why delegate

Fan-out work — "where is X used?", "is everything in sync?", "which files cite Y?",
tracing how a value flows across notebooks, diffing two decks, auditing references —
is what sub-agents are built for. The agent does the multi-file legwork in the
background and returns only the *conclusion*; your own session stays clean. You can
run several at once.

## How to launch one

**Just ask in plain language.** The recipe has three parts:

1. **the verb** — "use an agent / spawn a sub-agent / have an agent…"
2. **the tools it needs** — "with Read, Grep, and Bash access" (so it doesn't stall)
3. **report back** — "…and report X back to me" (so you get a conclusion, not a mess)

Example:

> "Use an agent with Read, Grep, and Bash access to trace how `W_star` is computed
> across the notes and report the call path back."

There is also an Agent picker in the UI for spawning one directly and choosing its
*type* (e.g. `Explore` = read-only search).

## The permission model (why agents stall)

It is NOT a fixed blocklist of commands. It's a permission system:

- When a tool call needs approval, an **interactive** session prompts *you* and you
  approve it.
- A **background sub-agent has no one to ask** → the call is blocked → the agent
  stalls or works around it.

So: **"what stalls an agent" = "what would have popped a permission prompt if you ran
it yourself."**

Two levers:

- **Lever 1 — the agent's toolset** (set by agent *type*). `Explore` is read-only by
  construction (Read/Grep/Glob/Bash, but no Edit/Write). `general-purpose` has
  everything.
- **Lever 2 — the allow/deny rules** in `settings.json` — decide whether a specific
  invocation sails through or needs approval.

## Stall-trigger table

### Safe — never prompts (the recon verbs)

| Tool / command                                                                      | Use                         |
| ----------------------------------------------------------------------------------- | --------------------------- |
| `Read`, `Grep`, `Glob`, `LS` tools                                          | reading, searching, listing |
| read-only Bash:`cat`, `ls`, `find`, `head`, `wc`, `git status/diff/log` | inspecting without changing |

### Needs approval → stalls a background agent unless pre-allowed

| Category                         | Commands                                                                                                                                                                                |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **File mutation**          | `Edit`, `Write` tools; Bash `mv`, `cp`, `rm`, `mkdir`, `touch`, `chmod`, `sed -i`, `tee`, any `>` / `>>` redirect                                               |
| **Deletion**               | `rm`, `trash` (`trash *` is pre-allowed in the ALE project)                                                                                                                       |
| **Network / external**     | `curl`, `wget`, `pip install`, `npm install`, `brew`, `gh` (api/issue/pr), `git push`, `git pull`                                                                       |
| **Version-control writes** | `git add`, `git commit`, `git push`                                                                                                                                               |
| **System / process**       | `launchctl`, `crontab`, `kill`, `osascript` (unless allowed)                                                                                                                    |
| **Hard `deny` list**     | `**/restricted/**`, `~/.ssh`, `~/.gitconfig`, shell rc files, `/etc/hosts`, `~/.aws`, `~/.npmrc` — denied outright; require editing settings, can't be approved on the fly |

## Two ways to avoid stalls

### 1. Recon (most delegation): keep it read-only and say so

Phrasing that *cannot* stall — nothing it does needs approval:

> "Use a read-only agent. Use the Read, Grep, and Glob tools (not shell mutations).
> Do not modify any files. Report X back."

### 2. Agent that must change things (build, move files, sync GitHub)

Pre-authorize the specific commands in `settings.json → permissions.allow` *before*
launching, so the prompt never arises. An agent inherits those rules, so anything on
the allow-list runs silently.

**Catch:** in an interactive session *you* are the fallback — an un-allowed command
just prompts you. A **background** agent has no fallback, so for mutating background
work either pre-allow the commands, or run that agent in the foreground where you can
approve.

## Copy-paste templates

Read-only recon:

```
Use a read-only agent (Read, Grep, Glob — no shell mutations, do not modify files).
[Describe the search/audit]. Report back: [the specific conclusion you want].
```

Trace / call-path:

```
Use an agent with Read, Grep, and Bash access to trace how [X] is computed across
[files/dirs] and report the call path back. Read-only — do not modify anything.
```

Mutating work (foreground, or pre-allow first):

```
Use an agent with Read, Grep, Bash, and Edit access to [task]. Before it runs, these
commands must be in permissions.allow: [list]. Report what changed.
```

LaTeX content editing (edit + compile-verify):

```
Use an agent with Read, Grep, Bash, and Edit access to [task — e.g. "revise the prose
in section 3 of draft/main.tex and move the long derivation to the appendix"].
Edit the .tex source, then compile with the project's real engine and verify 0 errors
before reporting done. Read-only on everything outside the target .tex files.
Report what changed and the final compile status.

Before it runs, these must be in permissions.allow:
  Bash(lualatex -interaction=nonstopmode *)
  Bash(xelatex -interaction=nonstopmode *)
  Bash(latexmk *)
  Bash(bibtex *)
  Bash(biber *)
  Bash(trash *)            # aux/log cleanup (already allowed in ALE)
  Bash(grep *)             # log scanning (already allowed in ALE)
```

Notes:

- Compile with **lua/xelatex**, not pdflatex — engine-specific bugs (soul letterspacing,
  float-loss, package clashes) only surface under the real engine. State the engine
  explicitly so the agent validates against your true build.
- Tell it not to remove preamble macros (e.g. `\R`) or add packages the document class
  already loads (e.g. `placeins` in tufte-handout) — past compile breaks came from both.
- Add `Edit`/`Write` are tools, not allow-list entries — granted via the agent's tool
  access, not `permissions.allow`. The allow-list is only for the Bash compile/cleanup
  commands.
