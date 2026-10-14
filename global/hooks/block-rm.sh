#!/bin/bash
# PreToolUse hook (matcher: Bash). Refuses a recursive or forced rm and tells
# Claude to use `trash` instead, so every deletion can be recovered.
#
# Claude Code passes the tool call as JSON on stdin. Exit code 2 blocks the
# call and sends stderr back to Claude; exit code 0 lets it run.
#
# Matches rm at the start of a command (after a quote, ;, &, | or a
# parenthesis), so `git rm -r --cached` is not blocked.

input=$(cat)

if printf '%s' "$input" | grep -Eq '(["(;&|]) *rm +-[[:alpha:]]*[rRf]'; then
  echo "Blocked: use 'trash <path>' instead of rm -r / rm -f," \
       "so the deletion can be recovered from the Trash." >&2
  exit 2
fi

exit 0
