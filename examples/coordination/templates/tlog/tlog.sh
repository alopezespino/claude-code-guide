#!/usr/bin/env bash
# tlog: one log line per pipeline milestone, the same style in shell, R and Python.
#   Terminal: a blank line, then the timestamp in green and the message in cyan.
#   Format:   DD/MM/YYYY - HH:MM:SS AM/PM  message
# If the project's project.yaml sets paths.logs, each line is also appended,
# without colors, to <paths.logs>/tlog.log. See README.md.
#
# Use it from a script:  . "$(dirname "$0")/tlog.sh"; tlog "Cleaning started"
# Run it directly:       ./tlog.sh "message"

# Define the functions once, even if this file is sourced twice.
if ! declare -F tlog >/dev/null 2>&1; then

  # Print the value of paths.logs from <repo root>/project.yaml, or nothing.
  # Reads only a top-level "paths:" block with lines such as "  logs: ~/logs/x".
  tlog_logdir() {
    local root yaml
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    yaml="$root/project.yaml"
    [ -f "$yaml" ] || return 0
    awk '
      /^[^[:space:]#]/ { inpaths = ($0 ~ /^paths:[[:space:]]*$/); next }
      inpaths && /^[[:space:]]+logs:/ {
        sub(/^[[:space:]]+logs:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, "")
        gsub(/^["\047]|["\047]$/, ""); print; exit
      }' "$yaml" | sed "s|^~|$HOME|"
  }

  tlog() {
    local ts dir
    ts=$(date '+%d/%m/%Y - %I:%M:%S %p')
    printf '\n\033[32m%s\033[0m  \033[36m%s\033[0m\n' "$ts" "$*"
    dir=$(tlog_logdir)
    if [ -n "$dir" ]; then
      mkdir -p "$dir" && printf '\n%s  %s\n' "$ts" "$*" >> "$dir/tlog.log"
    fi
  }
fi

# Executed (not sourced): log the arguments.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  tlog "${*:-tlog test line}"
fi
