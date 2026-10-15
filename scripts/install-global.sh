#!/bin/bash
# Copies global/ into ~/.claude. Never overwrites an existing file: it lists
# what it skipped, so you can merge those with prompts/merge-existing-setup.md.
# Usage: scripts/install-global.sh

set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
src="$repo/global"
dest="$HOME/.claude"
skipped=0

mkdir -p "$dest/hooks" "$dest/commands"

install_file() {
  # install_file <path relative to global/>
  local rel=$1
  if [ -e "$dest/$rel" ]; then
    echo "  skipped  ~/.claude/$rel (already exists)"
    skipped=$((skipped + 1))
  else
    cp "$src/$rel" "$dest/$rel"
    case $rel in hooks/*.sh) chmod +x "$dest/$rel" ;; esac
    echo "  copied   ~/.claude/$rel"
  fi
}

install_file CLAUDE.md
install_file settings.json
for f in "$src"/hooks/*.sh; do
  install_file "hooks/$(basename "$f")"
done
for f in "$src"/commands/*.md; do
  install_file "commands/$(basename "$f")"
done

echo
if [ "$skipped" -gt 0 ]; then
  echo "$skipped file(s) skipped. To merge them, open Claude Code in this repo"
  echo "and paste prompts/merge-existing-setup.md."
fi
echo "Next: edit ~/.claude/CLAUDE.md to make the rules yours."
