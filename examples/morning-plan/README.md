# Morning plan: a scheduled `/organize` run

> Example from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit these files to change what the job does.

On weekday mornings, macOS `launchd` runs the
[`/organize`](../../global/commands/organize.md) planner once with `claude -p`
and saves the day's plan as a dated Markdown file. The run is read-only: it
reads the task folder and writes only the report and a log.

| File | Purpose |
|---|---|
| `run-morning-plan.sh` | sets the environment, runs `claude -p`, writes the report, logs |
| `com.example.morning-plan.plist` | `launchd` schedule template (weekdays 08:50) |

Output:

- report: `<project>/reports/morning-plan/<YYYY-MM-DD>.md`
  (a failed or stopped run leaves `<YYYY-MM-DD>.failed.md` instead);
- log: `~/Library/Logs/morning-plan/morning-plan.log`.

## Before you install

1. Install the planner command: copy `global/commands/organize.md` to
   `~/.claude/commands/`, and check that `/organize` works interactively in your
   project.
2. Log in to Claude Code once in a terminal (`claude`, then `/login`).
3. Pick a folder for the two files below, for example `~/bin/morning-plan/`, and copy
   them there.

## Why the script sets USER, LOGNAME and PATH

`launchd` starts a job with almost no environment: a minimal `PATH`, no shell profile,
and no `USER` or `LOGNAME`. Two consequences:

- Claude Code keeps its login in the macOS Keychain. Without `USER` and `LOGNAME` the
  Keychain lookup fails, and the run stops within a second with "Not logged in".
- Tools installed by Homebrew or in `~/.local/bin` (`claude`, `gh`) are not found.

The script exports all three before anything else. Always start the job through the
script, never by calling `claude` from the plist directly.

## Test by hand first

Run the script from a terminal, then again with an empty environment, which is close
to what `launchd` provides:

```bash
export PROJECT_DIR=/absolute/path/to/project
export CLAUDE_BIN="$(command -v claude)"
~/bin/morning-plan/run-morning-plan.sh
env -i PROJECT_DIR="$PROJECT_DIR" CLAUDE_BIN="$CLAUDE_BIN" \
  /bin/bash ~/bin/morning-plan/run-morning-plan.sh
```

Each run prints START and END lines with the exit code. Read the report in
`$PROJECT_DIR/reports/morning-plan/`. If the run stops early, the log says why.

## Permissions

A scheduled run cannot answer a permission prompt. The script passes
`--allowedTools` with the read-only tools the planner needs (`Read`, `Glob`, `Grep`,
`date`, `grep`, `gh issue list`); anything else is refused. If the report says a
tool was denied, add it to `ALLOWED_TOOLS` in the script. Do not use
`--dangerously-skip-permissions` for a job that runs unattended every day.

The calendar step (`Planner calendar: yes`) needs Calendar access, which macOS grants
through a dialog. Run `/organize` interactively once and approve it, so a scheduled run
never meets that dialog.

## Install

Claude Code should not write to `~/Library/LaunchAgents/` or run `launchctl`; do these
steps yourself.

1. Fill in the placeholders in the plist (`__SCRIPT_DIR__`, `__PROJECT_DIR__`,
   `__CLAUDE_BIN__`, `__HOME__`) with absolute paths. `launchd` does not expand `~`.
   For example:

   ```bash
   sed -e "s#__SCRIPT_DIR__#$HOME/bin/morning-plan#" \
     -e "s#__PROJECT_DIR__#/absolute/path/to/project#g" \
     -e "s#__CLAUDE_BIN__#$(command -v claude)#" \
     -e "s#__HOME__#$HOME#g" \
     com.example.morning-plan.plist \
     > ~/Library/LaunchAgents/com.example.morning-plan.plist
   ```

2. Check it and load it:

   ```bash
   mkdir -p ~/Library/Logs/morning-plan
   plutil -lint ~/Library/LaunchAgents/com.example.morning-plan.plist
   launchctl load ~/Library/LaunchAgents/com.example.morning-plan.plist
   launchctl list | grep com.example.morning-plan
   ```

3. Start one run now, without waiting for the schedule:

   ```bash
   launchctl start com.example.morning-plan
   tail -f ~/Library/Logs/morning-plan/morning-plan.log
   ```

To change the time, edit `Hour` and `Minute` in the plist. After any edit to the
installed plist, `unload` it and `load` it again; `launchd` keeps the old definition
until then.

## When the Mac is asleep

`launchd` does not run a job while the Mac sleeps. A missed `StartCalendarInterval` run
starts at the next wake instead, which for a morning plan is usually when you want it.
If it must run at a fixed time, schedule a wake a few minutes earlier, for example
`sudo pmset repeat wakeorpoweron MTWRF 08:45:00` (macOS allows one repeating wake
event; `sudo pmset repeat cancel` removes it).

## Remove

```bash
launchctl unload ~/Library/LaunchAgents/com.example.morning-plan.plist
trash ~/Library/LaunchAgents/com.example.morning-plan.plist
```

The reports and the log stay where they are; move them to the Trash too if you no
longer want them.
