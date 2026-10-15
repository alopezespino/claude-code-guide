#!/bin/bash
# Example hook from claude-code-guide. Hooks are a Claude Code feature;
# this script is not.
# PreToolUse hook (matcher: Bash). Refuses a recursive or forced rm and tells
# Claude to use `trash` instead, so every deletion can be recovered.
#
# Claude Code passes the tool call as JSON on stdin. Exit code 2 blocks the
# call and sends stderr back to Claude; exit code 0 lets it run.
#
# Matches rm where a command starts: after a quote, ;, &, |, a parenthesis, a
# backtick or a line break (\n in the JSON), optionally after sudo or xargs,
# as rm, /bin/rm or /usr/bin/rm, with a short flag group holding r, R or f,
# or with --recursive or --force. `git rm -r --cached` is not blocked. It is a
# safety net, not a guarantee: a command can reach rm in ways it does not see.

input=$(cat)

start='(^|["(;&|`]|\\n)'
prefix=' *((sudo|xargs)( +-[[:alpha:]]+)* +)*((/usr)?/bin/)?'
flags='rm +((-[[:alpha:]]+|--[[:alpha:]-]+) +)*(-[[:alpha:]]*[rRf]|--recursive|--force)'

if printf '%s' "$input" | grep -Eq "$start$prefix$flags"; then
  echo "Blocked: use 'trash <path>' instead of rm -r / rm -f," \
       "so the deletion can be recovered from the Trash." >&2
  exit 2
fi

exit 0
