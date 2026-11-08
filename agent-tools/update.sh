#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Pull the engine (agent-tools/) from the upstream memory-workspace over this
# vendored copy, and reinstall the contract it ships (agent-tools/AGENTS.md)
# as this repository's root AGENTS.md.
#
#   agent-tools/update.sh            # what workspace.yaml's agent_tools_track says:
#                                    #   latest (default) — upstream's current tip
#                                    #   pinned           — the version in agent-tools/VERSION:
#                                    #                      refreshes it, but refuses to move to
#                                    #                      a different one without --accept
#   agent-tools/update.sh --accept   # take the version upstream has now — how a pinned
#                                    #   workspace moves, after being offered a release
#   agent-tools/update.sh v0.2.0     # an explicit tag, branch or full sha, whatever the track
#   agent-tools/update.sh --check    # installed vs upstream VERSION, change nothing
#
# Versions are the text of agent-tools/VERSION, not git tags: on the `pinned`
# track agent-tools/hooks/version-check.sh compares the two at SessionStart,
# quotes agent-tools/CHANGELOG.md for everything in between, and offers it.
# AGENTS.md ("Updating the engine") says what to do about that offer.
#
# Everything under agent-tools/ is replaced except the paths in KEEP, which are
# per-workspace and never shipped upstream; the root AGENTS.md is replaced too.
# Local edits to either are overwritten — per-workspace behaviour belongs in
# workspace.yaml and WORKSPACE.md, not here. Review `git diff` and commit afterwards;
# nothing is committed for you.
#
# Refuses to run in the template itself (no workspace.yaml): there the engine is
# edited in place, and the root AGENTS.md is the maintainer guide, not the
# contract.
# ---------------------------------------------------------------------------
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if in_template; then
  echo "update: no workspace.yaml — this is the template, not a workspace; nothing to update here." >&2
  exit 1
fi
UPSTREAM="$(upstream_url)"
TRACK="$(update_track)"
KEEP=(skills/gsheets/assets)
DEST="$ROOT/agent-tools"
INSTALLED="$(tr -d '[:space:]' < "$DEST/VERSION")"

# A bare run follows the track. An explicit ref, or --accept, is the consent
# that lets a pinned workspace land on a different version.
MODE=install; REF=""; ACCEPT=0
case "${1:-}" in
  "")       ;;
  --check)  MODE=check ;;
  --accept) ACCEPT=1 ;;
  -*)       echo "update: unknown option '$1' — try --check, --accept, or a ref." >&2; exit 1 ;;
  *)        REF="$1"; ACCEPT=1 ;;
esac
[ -n "$REF" ] || REF="$(track_ref)"
[ -n "$REF" ] || { echo "update: nothing to fetch — track '$TRACK' resolved to no ref at $UPSTREAM" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init --quiet
# A branch, tag, sha or HEAD alike.
if ! git -C "$TMP" fetch --quiet --depth 1 "$UPSTREAM" "$REF"; then
  echo "update: could not fetch '$REF' from $UPSTREAM." >&2
  echo "update: agent_tools_track is '$TRACK' — the tracks are 'latest', 'pinned', or a branch name." >&2
  exit 1
fi
git -C "$TMP" checkout --quiet FETCH_HEAD
UP_VERSION="$(tr -d '[:space:]' < "$TMP/agent-tools/VERSION")"

if [ "$MODE" = check ]; then
  echo "installed: $INSTALLED   upstream ($REF): $UP_VERSION   track: $TRACK   $UPSTREAM"
  if [ "$TRACK" = pinned ] && [ "$INSTALLED" != "$UP_VERSION" ]; then
    echo "track 'pinned' stays on $INSTALLED; take $UP_VERSION with 'agent-tools/update.sh --accept'."
    changelog_since "$TMP/agent-tools/CHANGELOG.md" "$INSTALLED"
  fi
  exit 0
fi

if [ "$TRACK" = pinned ] && [ "$ACCEPT" = 0 ] && [ "$INSTALLED" != "$UP_VERSION" ]; then
  echo "update: this workspace is pinned to $INSTALLED; upstream is now $UP_VERSION." >&2
  echo "update: a bare update keeps the pin. Take it with 'agent-tools/update.sh --accept'," >&2
  echo "update: or name a ref explicitly. What changed:" >&2
  changelog_since "$TMP/agent-tools/CHANGELOG.md" "$INSTALLED" >&2
  exit 1
fi

# No rsync in the cloud containers this runs in, so: set the kept paths aside,
# replace the directory wholesale, put them back.
for k in "${KEEP[@]}"; do
  [ -e "$DEST/$k" ] || continue
  mkdir -p "$TMP/keep/$(dirname "$k")" && cp -a "$DEST/$k" "$TMP/keep/$k"
done
rm -rf "$DEST" && cp -a "$TMP/agent-tools" "$DEST"
for k in "${KEEP[@]}"; do
  [ -e "$TMP/keep/$k" ] || continue
  mkdir -p "$DEST/$(dirname "$k")" && cp -a "$TMP/keep/$k" "$DEST/$k"
done
cp "$DEST/AGENTS.md" "$ROOT/AGENTS.md"

# The replace above brought back features this workspace did not choose
# (workspace.yaml has no sheets: / whatsapp: block); drop them again before
# skills are registered below.
"$DEST/features.sh"

# Skills are registered by .claude/skills/<name> symlinks and .agents/skills
# stubs, which are only written at birth. Register any skill that arrived later.
for dir in "$DEST"/skills/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue
  if [ -d "$ROOT/.claude/skills" ] && [ ! -e "$ROOT/.claude/skills/$name" ]; then
    ln -s "../../agent-tools/skills/$name" "$ROOT/.claude/skills/$name"
    echo "update: registered skill '$name' for Claude Code (.claude/skills/$name)"
  fi
  if [ -d "$ROOT/.agents/skills" ] && [ ! -e "$ROOT/.agents/skills/$name/SKILL.md" ]; then
    mkdir -p "$ROOT/.agents/skills/$name"
    desc="$(sed -nE 's/^description:[[:space:]]*//p' "$dir/SKILL.md" | head -1)"
    printf -- '---\nname: %s\ndescription: %s\n---\n\nRead `agent-tools/skills/%s/SKILL.md` completely and follow it.\nResolve all relative resource paths from `agent-tools/skills/%s/`.\n' \
      "$name" "$desc" "$name" "$name" > "$ROOT/.agents/skills/$name/SKILL.md"
    echo "update: registered skill '$name' for Codex (.agents/skills/$name)"
  fi
done

echo "update: agent-tools is now $UP_VERSION ($REF) from $UPSTREAM"
if version_gt "$UP_VERSION" "$INSTALLED"; then
  changelog_since "$DEST/CHANGELOG.md" "$INSTALLED"
fi
echo "update: review with 'git status' and 'git diff', then commit."

# A new major changes how memory is stored; the upgrade is not finished until
# its migration has run (AGENTS.md, "Updating the engine").
if [ "${UP_VERSION%%.*}" -gt "${INSTALLED%%.*}" ] 2>/dev/null; then
  echo "update: MIGRATION REQUIRED — $INSTALLED → $UP_VERSION crosses a major version."
  echo "update: Commit this engine update on its own, then invoke the 'migrate' skill"
  echo "update: (agent-tools/skills/migrate/SKILL.md) to bring memory/ and the workspace files up to it."
fi

# The send-gate agent is built from the shipped prompt plus this workspace's
# gate_rules; an update may have changed the shipped half.
"$DEST/agents/render.sh" || echo "update: could not re-render the send-gate — run agent-tools/agents/render.sh by hand."

# The hook lives in agent-tools/ and so arrives with every update, but the
# files that RUN it are per-workspace and were only ever written at birth — a
# workspace that does not name it has to be told once.
if ! grep -qs 'version-check\.sh' "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json"; then
  echo "update: this workspace does not run"
  echo "update: agent-tools/hooks/version-check.sh at SessionStart, so nothing will tell you"
  echo "update: when upstream has something new. Add it beside the other SessionStart hooks in"
  echo "update: .claude/settings.json (and .codex/hooks.json if you use Codex)."
fi
if ! grep -qs 'gate-check\.sh' "$ROOT/.claude/settings.json"; then
  echo "update: this workspace does not run agent-tools/hooks/gate-check.sh at SessionStart,"
  echo "update: so nothing reports a send-gate out of step with workspace.yaml's gate_rules."
  echo "update: Add it beside the other SessionStart hooks in .claude/settings.json."
fi
