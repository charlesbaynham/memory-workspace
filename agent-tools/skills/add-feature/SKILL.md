---
name: add-feature
description: Add an optional feature to a workspace that is already set up — one the owner declined or postponed at onboarding (Google Sheets, the WhatsApp bot, auto-mode rules) — or see what else the upstream template offers and has added since. Use when the owner says "add WhatsApp", "add Google Sheets", "turn on the bot", "I want the Sheets skill after all", "add more features from the original repository", "what features did I skip?" or "is there anything new upstream?".
---

# Adding a feature after the workspace exists

Onboarding lets the owner decline a feature, and `agent-tools/features.sh`
then removes its skill and scripts (`update.sh` re-runs it, so they stay
removed). This skill is the way back: it turns the feature on, fetches what was
removed, wires it into this workspace's own files, and hands over whatever only
the owner can do. The owner may name a feature ("add WhatsApp") or ask openly
("add more features from the original repository"); either way start at §1.

**Do it from a session in this workspace's repository, on the default
branch.** Commit as the contract says (§5).

## 1. What is on, what is off, what is new

Read `workspace.yaml`. A feature is **on** when its top-level block is present
and uncommented.

| Feature | On when | What turning it on installs | Owner's part |
|---|---|---|---|
| **Google Sheets** | `sheets:` block | the `gsheets` skill and scripts (`agent-tools/skills/gsheets/`) | one Google Cloud step, a key in the agent environment, sharing each Sheet |
| **WhatsApp bot** | `whatsapp:` block | the `whatsapp` skill, the `whatsapp-send-gate` agent, `memory/whatsapp/` | a spare number, a bridge, a connector, the routine (`agent-tools/skills/whatsapp/setup.md`) |
| **Auto-mode rules** | `automode.json` exists | classifier rules installed by `agent-tools/automode/install.sh` | pasting a setup-script block into the cloud environment (Claude Code on the web only) |

For the *open* question, also learn what upstream has added:

```bash
agent-tools/update.sh --check      # installed vs upstream VERSION, track, and — on a
                                   # pinned workspace behind upstream — the changelog entries between
```

Report in a few lines: which of the three are off, and any upstream versions
newer than the installed one with the changelog headline of each. Then ask what
they want (the question tool, a few options, features first) and do **only**
that. New upstream behaviour that is not one of the three optional features
(a new hook, a changed contract) arrives by updating the engine, not here —
offer `agent-tools/update.sh --accept`, and follow the contract's "Updating the
engine" if they take it.

If the feature is already on, say so and stop; offer the `setup` skill if the
trouble is that its automation is not firing.

## 2. Turn it on in `workspace.yaml`

Ask for what the block needs, then add it. Take the shape from
`workspace.yaml.example` (kept in every workspace; upstream's copy if yours was
deleted). Never put a token or key in it.

- **Sheets** — a `sheets:` block with the spreadsheet **ids**, not URLs (the
  part between `/d/` and `/edit`). Add the Sheet to `WORKSPACE.md` under the
  source of truth, and to `source_of_truth` in `workspace.yaml` if it is now
  where the facts live.
- **WhatsApp** — a `whatsapp:` block with `bot_name`, `mcp_prefix` (the bot's
  connector, written `mcp__<Name>__`), `personal_prefixes`, `identity_roster`,
  `shareable`, and empty `read_only_chats` / `gate_exempt`. If they do not have
  the prerequisites yet, add it anyway with a comment above it saying it is
  unused until the bot is set up — the skill must be installed for the setup
  walk-through. Add both spellings of the connector to
  `.claude/settings.json` `permissions.allow` (`mcp__<Name>__*` and
  `mcp__claude_ai_<Name>__*`), replacing any stale example entries. Add a
  bot register to `WORKSPACE.md` if there is none.
- **Auto-mode** — `cp automode.json.example automode.json`; keep the WhatsApp
  sentences only if the bot is on, delete them otherwise.

## 3. Fetch what was removed

The files come back with the engine:

```bash
agent-tools/update.sh --check      # note installed / upstream / track
```

- **Same version, or track `latest`** — run `agent-tools/update.sh`. It
  replaces `agent-tools/`, keeps the features whose block is now present,
  registers their skills for Claude Code and Codex, and re-renders the
  send-gate.
- **`pinned` and upstream is newer** — a bare update refuses and prints the
  changelog. Tell the owner the choice: take the newer engine
  (`agent-tools/update.sh --accept`, then follow the contract's "Updating the
  engine" including any migration), or stay on the installed version with
  `agent-tools/update.sh v<installed>` if upstream tagged that release (it may
  not have). Do not pick for them.
- **Auto-mode only** — nothing to fetch; `agent-tools/automode/` ships in every
  workspace.

Then check: `git status` shows the feature's directory back; `ls -l
.claude/skills` lists it; for WhatsApp `ls -l .claude/agents` shows
`whatsapp-send-gate.md`. A new skill or agent is read at session start, so say
that it is usable from the **next** session.

**WhatsApp also needs `memory/whatsapp/`** (onboarding deletes it when the bot
is off). Restore its two files from upstream, never overwriting what is there:

```bash
. agent-tools/lib.sh; T="$(mktemp -d)"
git -C "$T" init -q && git -C "$T" fetch -q --depth 1 "$(upstream_url)" HEAD \
  && git -C "$T" checkout -q FETCH_HEAD \
  && mkdir -p memory/whatsapp \
  && for f in AGENTS.md CLAUDE.md; do [ -e "memory/whatsapp/$f" ] || cp "$T/memory/whatsapp/$f" memory/whatsapp/; done
rm -rf "$T"
```

(`memory/whatsapp/CLAUDE.md` is the one deliberate `@` import in `memory/`.)

## 4. Hand over what is the owner's

Name only what remains, in the owner's register:

- **Sheets**: run `agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh` once in
  Google Cloud Shell, put the key it prints in the agent environment as
  `GOOGLE_SERVICE_ACCOUNT_KEY` (never the repository), and share each Sheet with
  the service-account address it prints. Verify with the skill's `whoami` and
  `info` once the key is in place (next session).
- **WhatsApp**: the prerequisites are in `agent-tools/skills/whatsapp/setup.md`.
  When they have them, say "set up the WhatsApp routine" in a new session; the
  `setup` skill walks it. Until then the bot does not answer anyone.
- **Auto-mode**: run `agent-tools/automode/install.sh --snippet` and have them
  paste what it prints into the cloud environment's setup script.

## 5. Record and commit

Log it (`memory/log.md`, one line each, `- [YYYY-MM-DD] TYPE: …`): a `DECISION`
for the feature turned on and why they changed their mind, `RESOURCE` for
spreadsheet ids, an `OPEN` for every prerequisite still outstanding. Update the
digest's Tools & resources only if the filing pass would not. Then commit and
push with `agent-tools/sync-push.sh "Add <feature>"` — the whole change in one
commit: `workspace.yaml`, `.claude/settings.json`, `WORKSPACE.md`, `memory/`,
and the restored engine files.
