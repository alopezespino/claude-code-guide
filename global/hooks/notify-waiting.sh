#!/bin/bash
# Example hook from claude-code-guide. Hooks are a Claude Code feature;
# this script is not.
# Stop and Notification hook. Shows a macOS notification when Claude finishes
# a turn or needs your input, so you can leave it working and come back.
#
# The hook input (JSON on stdin) is not needed; it is read and discarded.
# The message goes to osascript as an argument, so a folder name with quotes
# or backslashes cannot break the AppleScript.

cat > /dev/null

project=$(basename "$PWD")
message="Claude is waiting in $project"

osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"' \
  -e 'end run' \
  "$message" > /dev/null 2>&1

exit 0
