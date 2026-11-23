#!/usr/bin/env bash
# Tests of hooks/no-redundant-poll.sh with a fake watcher state file.
# Example test from claude-code-guide (https://github.com/alopezespino/claude-code-guide).
# Usage: tests/hook.sh   (exit 0 when every case passes; needs jq)
here=$(cd "$(dirname "$0")" && pwd); hook="$here/../hooks/no-redundant-poll.sh"; fail=0
T=$(mktemp -d "${TMPDIR:-/tmp}/slurm-watch-hook.XXXXXX")
# this shell's pid stands in for a live watcher of job 1234567
printf 'target=ids:1234567\nids=1234567\nkey=1234567\n' > "$T/$$"
case_() {  # name, expected (deny or allow), command
  local got
  got=$(jq -n --arg c "$3" '{tool_name: "Bash", tool_input: {command: $c}}' |
    SLURM_WATCH_STATE=$T bash "$hook" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  [ -n "$got" ] || got=allow
  if [ "$got" = "$2" ]; then echo "PASS $1"; else echo "FAIL $1: got $got"; fail=1; fi
}
case_ "poll of a watched job is denied" deny "ssh mycluster 'squeue -j 1234567'"
case_ "sacct of a watched job is denied" deny "ssh mycluster sacct -j 1234567"
case_ "poll of another job is allowed" allow "ssh mycluster 'squeue -j 1111111'"
case_ "non-poll command naming the job is allowed" allow "echo 1234567 >> notes.md"
: > "$T/$$"   # watcher exited: its pid file is emptied
case_ "finished watcher blocks nothing" allow "ssh mycluster 'squeue -j 1234567'"
exit $fail
