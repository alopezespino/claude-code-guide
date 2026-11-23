#!/bin/bash
# no-redundant-poll.sh: Claude Code PreToolUse hook (matcher "Bash").
# Example hook from claude-code-guide (https://github.com/alopezespino/claude-code-guide).
#
# Denies a poll-shaped Bash command (squeue, sacct, scontrol show job, tail of
# a .log) that names a job id, job name or run dir a live slurm-watch is
# already watching. The watcher costs no tokens until it exits; every manual
# poll is a full turn that re-sends the whole conversation.
#
# Liveness is the watcher's pid, so a finished or killed watcher never blocks
# anything. Fails open on any problem (no jq, unreadable state): a guard must
# never wedge a session.
set -u
command -v jq >/dev/null 2>&1 || exit 0
payload=$(cat 2>/dev/null) || exit 0
[ "$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)" = Bash ] || exit 0
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

# Only the shapes that are unambiguously status polling. Quotes count as
# separators so `ssh <cluster> 'squeue ...'` is recognized.
printf '%s' "$cmd" |
  grep -qE "(^|[;&|( '\"])(squeue|sacct)([ ;&|)'\"]|\$)|scontrol[[:space:]]+show[[:space:]]+job|tail[^|;]*\\.log" ||
  exit 0

state="${SLURM_WATCH_STATE:-$HOME/.claude/state/slurm-watch}"
for f in "$state"/*; do
  [ -s "$f" ] || continue
  p=${f##*/}
  kill -0 "$p" 2>/dev/null || continue
  for tok in $(sed -n 's/^ids=//p; s/^key=//p' "$f" 2>/dev/null | tr ',' ' '); do
    [ ${#tok} -ge 5 ] || continue     # too short to match safely
    case "$cmd" in
      *"$tok"*)
        jq -n --arg r "slurm-watch (pid $p) is already watching $tok. It exits with one verdict line on completion, failure, OOM, memory pressure, idle CPU, a stalled checkpoint or a blocked pending job, so its silence is the status. Do unrelated work or stop and wait. If this check is really needed, stop that watcher first (TaskStop, or kill $p)." \
          '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
        exit 0 ;;
    esac
  done
done
exit 0
