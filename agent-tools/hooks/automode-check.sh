#!/usr/bin/env bash
# SessionStart hook — report whether the classifier rules in automode.json are
# what this environment actually loaded (~/.claude/settings.json), so drift is
# caught instead of silently assumed away. Reports only; the classifier reads
# its rules at startup, so nothing a hook writes now would apply.
#
# "In sync" means every rule in automode.json is present in the live list of
# the same name. install.sh merges, so the live block may carry more (the
# environment's own rules, another workspace's) and that is not drift.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
note() { printf 'automode hook: %s\n' "$1"; }
CANON="$ROOT/automode.json"
APPLIED="$HOME/.claude/settings.json"

[ -f "$CANON" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Prints OK, ABSENT (no autoMode installed), UNREADABLE, or MISSING <n> <total>.
state="$(python3 - "$CANON" "$APPLIED" <<'PY' 2>/dev/null
import json, sys
def block(path):
    try: return json.load(open(path)).get("autoMode")
    except Exception: return None
want = block(sys.argv[1])
if not isinstance(want, dict): print("UNREADABLE"); raise SystemExit
have = block(sys.argv[2])
if not isinstance(have, dict): print("ABSENT"); raise SystemExit
total = missing = 0
for key, items in want.items():
    if not isinstance(items, list): continue
    live = have.get(key) if isinstance(have.get(key), list) else []
    for r in items:
        total += 1
        missing += r not in live
print("OK" if not missing else f"MISSING {missing} {total}")
PY
)" || exit 0

case "$state" in
  OK) note "classifier rules ACTIVE: every rule in automode.json is installed." ;;
  UNREADABLE) note "automode.json has no readable autoMode block — fix the file." ;;
  ABSENT|"")
    note "classifier rules from automode.json are NOT installed in this environment."
    note "They only take effect at session start: on the web, add the block printed by"
    note "agent-tools/automode/install.sh --snippet to the environment setup script;"
    note "locally, run agent-tools/automode/install.sh once by hand." ;;
  MISSING*)
    set -- $state
    note "classifier rules PARTLY installed: $2 of $3 rules in automode.json are missing from"
    note "$APPLIED — a setup script that writes autoMode after the workspace block, or an"
    note "older install, would do this. Re-run agent-tools/automode/install.sh where it was"
    note "installed from; the live copy wins until then." ;;
esac
exit 0
