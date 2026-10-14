#!/bin/bash
# Stop and Notification hook. Shows a macOS notification when Claude finishes
# a turn or needs your input, so you can leave it working and come back.
#
# The hook input (JSON on stdin) is not needed; it is read and discarded.

cat > /dev/null

project=$(basename "$PWD")
message="Claude is waiting in $project"
script="display notification \"$message\" with title \"Claude Code\""

osascript -e "$script sound name \"Glass\"" > /dev/null 2>&1

exit 0
