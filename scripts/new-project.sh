#!/bin/bash
# Creates a new project from project-template/ and runs git init.
# Usage: scripts/new-project.sh <path/to/new-project>
# Example: scripts/new-project.sh ~/Documents/my-paper

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path/to/new-project>" >&2
  exit 1
fi

repo=$(cd "$(dirname "$0")/.." && pwd)
target=$1
name=$(basename "$target")

if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
  echo "Stopped: $target exists and is not empty." >&2
  echo "Copy the pieces you want from project-template/ instead." >&2
  exit 1
fi

mkdir -p "$target"
cp -R "$repo/project-template/." "$target/"
mv "$target/project.code-workspace" "$target/$name.code-workspace"

# Fill in the project name in the templates (BSD sed on macOS).
for f in CLAUDE.md README.md "$name.code-workspace"; do
  sed -i '' "s/PROJECT_NAME/$name/g" "$target/$f"
done

git -C "$target" init --quiet

target_abs=$(cd "$target" && pwd)
echo "Created $target_abs"
echo "Next:"
echo "  code $target_abs/$name.code-workspace"
echo "  then, in the VS Code terminal: claude, and /init"
