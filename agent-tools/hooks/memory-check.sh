#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — put the memory index in front of the session and report
# whether the filing pass (nightly by default) is keeping up.
#
# The index (one line per note in memory/notes/, from each note's frontmatter)
# is how a session knows what memory holds without loading it: the digest is
# imported, the notes are read on demand. The pass itself is the memory-compact
# skill, run nightly by a scheduled task (or, when workspace.yaml says
# `memory_filing: in-session`, by whichever session finds the log past the
# threshold); this hook only reports on it. It never edits anything.
#
# Never fails a session — always exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'memory hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0

LOG=memory/log.md
DIGEST=memory/digest.md
STATE=memory/filing-state.md
MEMPY=agent-tools/skills/memory-compact/memory.py
# Unfiled log entries that make the pass worth running: the environment variable,
# else workspace.yaml `memory_filing_threshold`, else 50. Anything that is not a
# positive integer is ignored.
THRESHOLD="${MEMORY_COMPACT_THRESHOLD:-$(ws_cfg memory_filing_threshold 50)}"
case "$THRESHOLD" in ''|*[!0-9]*|0) THRESHOLD=50 ;; esac
STALE_HOURS=36

[ -f "$LOG" ] || { note "no $LOG — memory system not installed here."; exit 0; }

# A major engine version changes how memory is stored, and ships a migration.
# Memory not yet migrated to the engine's major is the first thing to fix.
if ! in_template; then
  ENGINE_MAJOR="$(sed -nE 's/^v?([0-9]+)\..*/\1/p' agent-tools/VERSION 2>/dev/null | head -1)"
  MIGRATED="$(sed -nE 's/^migrated:[[:space:]]*//p' "$STATE" 2>/dev/null | head -1)"
  DONE_MAJOR="$(printf '%s\n' "$MIGRATED" | tr ', ' '\n\n' | sed -nE 's/^v?([0-9]+)\..*/\1/p' | sort -n | tail -1)"
  if [ -n "$ENGINE_MAJOR" ] && [ "$ENGINE_MAJOR" -ge 1 ] && [ "${DONE_MAJOR:-0}" -lt "$ENGINE_MAJOR" ]; then
    note "the engine is ${ENGINE_MAJOR}.x but memory has not been migrated to it (migrated: ${MIGRATED:-none})."
    note "Tell the owner, and run the migrate skill before other memory work"
    note "(read agent-tools/skills/migrate/SKILL.md and follow it if the skill is not listed)."
  fi
fi

if command -v python3 >/dev/null 2>&1 && [ -f "$MEMPY" ]; then
  python3 "$MEMPY" index 2>/dev/null || note "could not build the memory index; list memory/notes/ by hand."
else
  note "no python3 — no memory index this session; list memory/notes/ by hand."
fi

# Entries since the baseline marker are the ones the next pass will file.
ENTRY_RE='^- \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]'
BASELINE="$(grep -n '^<!-- compaction-baseline' "$LOG" 2>/dev/null | tail -1 | cut -d: -f1)"
if [ -n "$BASELINE" ]; then
  ENTRIES="$(tail -n +$((BASELINE + 1)) "$LOG" | grep -cE "$ENTRY_RE" || true)"
else
  ENTRIES="$(grep -cE "$ENTRY_RE" "$LOG" || true)"
fi

LAST_RUN="$(sed -nE 's/^last_run:[[:space:]]*([^[:space:]]+).*/\1/p' "$STATE" 2>/dev/null | head -1)"
if [ -z "$LAST_RUN" ] || [ "$LAST_RUN" = never ]; then
  # Before the first pass writes the state file: the last compaction commit, if any.
  LAST_RUN="$(git log -1 --format=%cI -E --grep='^memory: (compact|nightly filing|filing pass)' 2>/dev/null || true)"
fi
AGE_H=""
if [ -n "$LAST_RUN" ] && [ "$LAST_RUN" != never ]; then
  then_s="$(date -d "$LAST_RUN" +%s 2>/dev/null || true)"
  [ -n "$then_s" ] && AGE_H=$(( ($(date +%s) - then_s) / 3600 ))
fi

# workspace.yaml `memory_filing`: `scheduled` (default) = a scheduled task runs
# the pass; `in-session` = no task, and whichever session finds the log past the
# threshold files it.
FILING="$(ws_cfg memory_filing scheduled)"

if in_template; then
  # No scheduled task here: the template's own sessions log, and compaction is by hand.
  note "log.md: $ENTRIES entries since the last compaction (template: compact by hand at about $THRESHOLD)."
elif [ "$FILING" = in-session ]; then
  # No scheduled task, so no staleness alarm: the only trigger is the log's length.
  if [ -n "$AGE_H" ]; then
    note "memory filing is in-session (no scheduled task); last pass ${AGE_H}h ago, $ENTRIES log entries unfiled."
  else
    note "memory filing is in-session (no scheduled task); no pass has run yet, $ENTRIES log entries unfiled."
  fi
  if [ "$ENTRIES" -ge "$THRESHOLD" ]; then
    note "$ENTRIES unfiled entries reaches the threshold of $THRESHOLD: filing is THIS session's job."
    note "Once you have dealt with what you were started for, and before the session ends,"
    note "run the memory-compact skill (no need to ask the owner)."
  fi
elif [ -n "$AGE_H" ]; then
  if [ "$AGE_H" -gt "$STALE_HOURS" ]; then
    note "the nightly memory pass last ran ${AGE_H}h ago ($LAST_RUN) — it may have stopped."
    note "Tell the owner once; the setup skill audits and repairs it."
  else
    note "nightly memory pass last ran ${AGE_H}h ago; $ENTRIES log entries wait for the next."
  fi
else
  note "no nightly memory pass has run here yet; $ENTRIES log entries are waiting."
  note "If the owner has not set one up, offer once: the setup skill creates it."
fi

if ! in_template && [ "$FILING" != in-session ] && [ "$ENTRIES" -ge "$THRESHOLD" ] && { [ -z "$AGE_H" ] || [ "$AGE_H" -gt "$STALE_HOURS" ]; }; then
  note "$ENTRIES unfiled log entries and no recent pass — run the memory-compact skill now if the owner agrees."
fi

# Content = anything left once HTML comments, headings, blank lines and the
# "*(empty)*" placeholders are stripped. A digest of nothing but scaffolding
# has never been compacted, which is worth saying out loud.
digest_is_empty() {
  [ -f "$DIGEST" ] || return 0
  awk '
    /<!--/ { in_comment = 1 }
    !in_comment && !/^#/ && !/^[[:space:]]*$/ && !/^\*\(empty/ { found = 1 }
    /-->/  { in_comment = 0 }
    END    { exit found ? 1 : 0 }
  ' "$DIGEST"
}

if digest_is_empty; then
  note "digest.md is still empty — no pass has filed anything yet, so continuity"
  note "for this session comes from the tail of log.md instead."
fi

exit 0
