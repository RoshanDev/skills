#!/usr/bin/env bash
# md2docx skill installer — macOS / Linux / WSL
# Installs SKILL.md and converter-template.md into all detected AI CLI skill directories.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILL="$REPO_DIR/SKILL.md"
SRC_TEMPLATE="$REPO_DIR/converter-template.md"

if [[ ! -f "$SRC_SKILL" || ! -f "$SRC_TEMPLATE" ]]; then
  echo "ERROR: SKILL.md or converter-template.md missing in $REPO_DIR" >&2
  exit 1
fi

# All known target directories. Add more here as new CLIs adopt the skill convention.
TARGETS=(
  "$HOME/.qoderwork/skills/md2docx:QoderWork"
  "$HOME/.qoder/skills/md2docx:Qoder CLI"
  "$HOME/.claude/skills/md2docx:Claude Code"
  "$HOME/.codex/skills/md2docx:Codex"
)

installed=0
skipped=0
for entry in "${TARGETS[@]}"; do
  dir="${entry%%:*}"
  name="${entry##*:}"
  parent="$(dirname "$dir")"

  if [[ ! -d "$parent" ]]; then
    echo "  [skip] $name — parent directory '$parent' does not exist (CLI not installed?)"
    skipped=$((skipped+1))
    continue
  fi

  mkdir -p "$dir"
  cp "$SRC_SKILL" "$dir/SKILL.md"
  cp "$SRC_TEMPLATE" "$dir/converter-template.md"
  echo "  [ok]   $name → $dir"
  installed=$((installed+1))
done

echo
echo "Done. Installed: $installed, Skipped: $skipped"
echo "Restart your CLI to pick up the skill."
