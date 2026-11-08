#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Remove the optional features this workspace did not choose, so their skills
# and scripts are not installed.
#
#   agent-tools/features.sh          # prune what workspace.yaml does not enable
#
# A feature is on when workspace.yaml has its top-level block, uncommented:
#   sheets:     the gsheets skill (agent-tools/skills/gsheets)
#   whatsapp:   the whatsapp skill, the send-gate agent and their registrations
# "Later" is a block left in place with a comment saying it is unused.
#
# Run by ONBOARDING.md after workspace.yaml is written, and by update.sh after
# every engine update (which would otherwise bring the files straight back).
# To turn a feature on later: add its block, then run agent-tools/update.sh --
# the files come back with the engine and are registered.
#
# Prunes agent-tools/ and the skill/agent registrations only; memory/ and the
# workspace's own files are never touched. skills/gsheets/assets (a local key)
# is kept. Refuses to run in the template: there both features ship.
# ---------------------------------------------------------------------------
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if in_template; then
  echo "features: no workspace.yaml — this is the template; both optional features ship here." >&2
  exit 0
fi

has_block() { grep -qE "^$1:" "$CONFIG"; }
removed=()
rm_path() { [ -e "$1" ] || [ -L "$1" ] || return 0; rm -rf "$1"; removed+=("${1#"$ROOT"/}"); }
rm_skill() {  # <name>: registrations, then the skill itself
  rm_path "$ROOT/.claude/skills/$1"; rm_path "$ROOT/.agents/skills/$1"
  if [ "$1" = gsheets ] && [ -d "$ROOT/agent-tools/skills/gsheets/assets" ]; then
    find "$ROOT/agent-tools/skills/gsheets" -mindepth 1 -maxdepth 1 ! -name assets -exec rm -rf {} + \
      && removed+=("agent-tools/skills/gsheets (except assets/)")
  else
    rm_path "$ROOT/agent-tools/skills/$1"
  fi
}

has_block sheets || rm_skill gsheets
if ! has_block whatsapp; then
  rm_skill whatsapp
  rm_path "$ROOT/.claude/agents/whatsapp-send-gate.md"
  rm_path "$ROOT/agent-tools/agents/whatsapp-send-gate.md"
fi

if [ "${#removed[@]}" -eq 0 ]; then
  echo "features: nothing to prune"
else
  echo "features: not enabled in workspace.yaml, removed: ${removed[*]}"
  echo "features: to enable one later, add its block (sheets: / whatsapp:) and run agent-tools/update.sh"
fi
