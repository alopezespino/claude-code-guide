#!/bin/bash
# Read-only check of the tools this guide uses. Changes nothing.
# Usage: scripts/preflight.sh

check() {
  # check <command> <what it is for> [required|optional]
  local cmd=$1 purpose=$2 level=${3:-required}
  if command -v "$cmd" > /dev/null 2>&1; then
    printf '  ok       %-12s %s\n' "$cmd" "$purpose"
  elif [ "$level" = required ]; then
    printf '  MISSING  %-12s %s\n' "$cmd" "$purpose"
  else
    printf '  -        %-12s %s (optional)\n' "$cmd" "$purpose"
  fi
}

echo "Tools:"
check brew       "installs everything else"
check git        "version control"
check gh         "GitHub from the terminal"
check claude     "Claude Code"
check code       "VS Code command line (Cmd+Shift+P: Shell Command)"
check latexmk    "LaTeX builds"
check biber      "bibliographies (biblatex)" optional
check trash      "recoverable deletes (brew install trash if missing)"
check micromamba "per-project environments" optional

echo
echo "Versions:"
command -v claude > /dev/null 2>&1 && echo "  $(claude --version 2>/dev/null)"
command -v git > /dev/null 2>&1 && echo "  $(git --version)"
echo "  macOS $(sw_vers -productVersion 2>/dev/null)"

echo
echo "GitHub login:"
if command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
  echo "  ok"
else
  echo "  not logged in: run gh auth login"
fi

echo
echo "Existing Claude Code configuration in ~/.claude:"
for f in CLAUDE.md settings.json hooks commands skills agents; do
  if [ -e "$HOME/.claude/$f" ]; then
    echo "  exists   ~/.claude/$f"
  else
    echo "  -        ~/.claude/$f"
  fi
done
echo
echo "If CLAUDE.md or settings.json exist, merge with" \
     "prompts/merge-existing-setup.md."
