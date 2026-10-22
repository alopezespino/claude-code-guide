#!/usr/bin/env bash
# Example from claude-code-guide
# (https://github.com/alopezespino/claude-code-guide), not part of Claude Code.
#
# Runs the /organize planner once, unattended, and writes the plan to a dated
# report file. Meant to be started by launchd (see README.md), but it also runs
# by hand from a terminal, which is how to test it.
#
# Usage: run-morning-plan.sh
# Settings (edit below, or set them in the environment):
#   PROJECT_DIR   folder holding the task folder and CLAUDE.md
#   CLAUDE_BIN    path to the claude executable (`command -v claude`)
#   REPORT_DIR    where <YYYY-MM-DD>.md reports go
#   LOG_DIR       where morning-plan.log goes
#   MAX_SECONDS   stop the run after this many seconds
#
# launchd starts jobs with almost no environment: a bare PATH, no shell
# profile, and no USER or LOGNAME. Everything is set explicitly here, because
# a job that works in a terminal and fails on schedule nearly always fails on
# an environment difference.

set -uo pipefail

# USER and LOGNAME are required: Claude Code reads its login from the macOS
# Keychain, and without them the lookup fails and the run stops at once with
# "Not logged in". launchd does not set them.
USER="${USER:-$(id -un)}"
LOGNAME="${LOGNAME:-$USER}"
if [ -z "${HOME:-}" ]; then
  HOME="$(dscl . -read "/Users/$USER" NFSHomeDirectory | awk '{print $2}')"
fi
export USER LOGNAME HOME
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

PROJECT_DIR="${PROJECT_DIR:-<path to your planner project>}"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
REPORT_DIR="${REPORT_DIR:-$PROJECT_DIR/reports/morning-plan}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs/morning-plan}"
MAX_SECONDS="${MAX_SECONDS:-900}"

# Tools the run may use without asking. A scheduled run cannot answer a
# permission prompt; anything not listed here is refused. Do not replace this
# with --dangerously-skip-permissions on a job that runs unattended every day.
ALLOWED_TOOLS="Read Glob Grep Bash(date *) Bash(grep *) Bash(gh issue list *)"

PROMPT='Run /organize plan for today. This is an unattended scheduled run:
follow the "Unattended runs" rules in that command. Print the plan as
Markdown, starting with a one-line summary: the number of items planned, the
most time-critical item, and how many items need a decision.'

LOG="$LOG_DIR/morning-plan.log"
TODAY="$(date +%Y-%m-%d)"
REPORT="$REPORT_DIR/$TODAY.md"

mkdir -p "$LOG_DIR" "$REPORT_DIR" || exit 73

# Log format: green timestamp, cyan message, one blank line before each entry.
tlog() {
  printf '\n\033[32m%s\033[0m - \033[36m%s\033[0m\n' \
    "$(date '+%d/%m/%Y - %I:%M:%S %p')" "$1" | tee -a "$LOG"
}

tlog "START morning-plan report=$REPORT"

if [ ! -x "$CLAUDE_BIN" ]; then
  tlog "ABORT: claude not executable at $CLAUDE_BIN"
  exit 127
fi
if ! cd "$PROJECT_DIR" 2>/dev/null; then
  tlog "ABORT: PROJECT_DIR not found: $PROJECT_DIR"
  exit 66
fi

start=$(date +%s)
tmp="$REPORT.partial"

# Run in the background with a watchdog, so a stalled run is stopped after
# MAX_SECONDS instead of hanging until the next morning. (macOS has no
# `timeout` command by default.)
"$CLAUDE_BIN" -p "$PROMPT" --allowedTools "$ALLOWED_TOOLS" \
  >"$tmp" 2>>"$LOG" &
pid=$!
( sleep "$MAX_SECONDS" && kill "$pid" 2>/dev/null \
    && echo "watchdog: stopped after ${MAX_SECONDS}s" >>"$LOG" ) &
watchdog=$!

wait "$pid"
rc=$?
kill "$watchdog" 2>/dev/null
wait "$watchdog" 2>/dev/null

if [ "$rc" -eq 0 ] && [ -s "$tmp" ]; then
  mv "$tmp" "$REPORT"
else
  # Keep the partial output for diagnosis under a name that is not mistaken
  # for a finished report.
  mv "$tmp" "$REPORT_DIR/$TODAY.failed.md" 2>/dev/null
fi

elapsed=$(( $(date +%s) - start ))
tlog "END morning-plan rc=$rc elapsed=${elapsed}s"
exit "$rc"
