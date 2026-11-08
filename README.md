# memory-workspace

A template for a git repository that gives AI agents **memory across
sessions** for one domain of work: running an event (a wedding, a conference, a
festival), managing a project with a team, or open-ended life admin.
Optionally, it runs a **WhatsApp bot** that answers the people involved without
leaking anyone's private details. Extracted from a workspace that ran a real
wedding with ~90 guests, then scrubbed of everything about them; events remain
a first-class use, but nothing in the engine assumes one.

It is not an app. It is a git repository shaped so that an ephemeral agent
session (Claude Code on the web, Codex, or anything that reads `AGENTS.md`)
starts with the right context, writes down what it learns, and leaves the next
session no worse off than itself.

## Set it up with your coding agent

Paste this into Claude Code, Codex or any coding agent, from your home directory
with nothing cloned. There is nothing to fill in — it asks you.

```text
Set up a new memory workspace for me from the template at
https://github.com/charlesbaynham/memory-workspace.

Clone it into a new folder in my home directory, then read ONBOARDING.md in
that folder and follow it as your prompt. It will interview me about what the
workspace is for and configure it from my answers — ask me its questions rather than
guessing.
```

[`ONBOARDING.md`](ONBOARDING.md) is the whole setup procedure, written to be
executed by an agent rather than read by you: three rounds of questions (what
it is for and who is involved, which features you want, where the repository
lives) and a
recap you confirm, then it writes `workspace.yaml` and `WORKSPACE.md`, installs the
shipped contract as your root `AGENTS.md`, reseeds `memory/`,
replaces this README with one about your workspace, checks the hooks all run, creates
the private repo, pushes, and tells you the one or two things only you can do.
Answer in prose, skip what you do not care about, say "all the defaults" — it
takes what you give it. The document deletes itself in the first commit, so your
repository never carries it.

## What is in it

| Piece | What it does |
|---|---|
| **Memory** (`memory/`, `memory-compact` skill, hooks) | A small digest injected into every session, one note per subject indexed at session start, user corrections, and an append-only log each session writes to as it works. A filing pass files what is durable from the log and the git history into the notes and the digest (and reads session transcripts too, when the session running it can list them). By default a scheduled task runs it, nightly; set `memory_filing: in-session` in `workspace.yaml` for no task at all, and whichever session finds the log past 40 entries files it before it ends. |
| **Session hygiene** (`agent-tools/hooks/git-sync.sh`, `agent-tools/sync-push.sh`) | Repairs the shallow-snapshot divergence cloud containers show, keeps sessions on the default branch, and pushes with rebase-and-retry so two concurrent sessions don't lose each other's work. |
| **WhatsApp**, optional (`whatsapp` skill, `whatsapp-send-gate` agent) | A dedicated bot number answers the people involved — an event's guests, a project's team. Every reply is drafted, recorded, then judged by an isolated subagent that sees only the transcript, the draft, and an identity check. Anything about another person, anyone's money, or anything embarrassing waits for the owner. One thread file per contact is the durable record. Webhook-driven: each message wakes a fresh session. Off unless `workspace.yaml` has a `whatsapp:` block. |
| **`setup` and `migrate` skills** | `setup` creates and audits the scheduled tasks the workspace runs on (the filing pass unless it is in-session, the WhatsApp routine). `migrate` reshapes stored memory when an engine update crosses a major version. |
| **gsheets** skill | Read and write a Google Sheet in place via a service account. Ships no key. |
| **Two registers** | A technical owner and co-users (a partner, teammates, family) get different voices, the same facts. |
| **Classifier rules** (`automode.json`, `agent-tools/automode/`) | Auto-mode rules kept in the repo, installed into the environment by a script the setup script calls, with a session-start drift check. A repo cannot ship these directly; see the ops notes. |
| **The contract** (`agent-tools/AGENTS.md`, installed as your root `AGENTS.md`) | The rules above, written for an agent to follow. Generic; updated from upstream. This repository's own root `AGENTS.md` is the maintainer guide for the template, not the contract. |

## Getting started by hand

`ONBOARDING.md` walks an agent through all of this. If you would rather do it
yourself:

1. Clone this repository, `rm -rf .git && git init -b main`, and push it to a
   new private repo of your own (nothing is ever merged back from upstream;
   `update.sh` vendors the engine instead).
2. Copy `workspace.yaml.example` → `workspace.yaml` and `WORKSPACE.md.example` → `WORKSPACE.md`;
   fill them in. Everything about *your* workspace goes in those two files and in
   `memory/`; never in `agent-tools/`. Then `cp agent-tools/AGENTS.md AGENTS.md`
   — the contract replaces the template's maintainer guide. Reset
   `memory/log.md`, `digest.md`, `user-edits.md` and `filing-state.md` to their
   empty forms (what is there is the template's own history; `ONBOARDING.md`
   step 5 says exactly what to keep), trim the maintainer note out of
   `CLAUDE.md` (keep its three `@` imports), and fix or remove the example
   WhatsApp allow rules in `.claude/settings.json`. Delete `ONBOARDING.md`,
   `docs/spin-out-plan.md`, the template-only `bump-version` skill
   (`.claude/skills/` and `.agents/skills/`) and the release workflow
   (`.github/workflows/release.yml`).
3. If the source of truth is a Google Sheet: run
   `agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh` once in Cloud Shell,
   put the key it prints in the agent environment as
   `GOOGLE_SERVICE_ACCOUNT_KEY`, and share the Sheet with the service account.
4. For WhatsApp (optional): stand up a bridge (see `agent-tools/skills/whatsapp/setup.md`
   for the prerequisites — a second phone number, the bridge, a connector), then
   open a session and say "set up the WhatsApp routine". The skill walks both of
   you through it.
5. Optional: copy `automode.json.example` → `automode.json` and call
   `agent-tools/automode/install.sh` from the cloud environment's setup script
   (see `docs/agent-ops-notes.md` for why it has to be there).
6. Open a session and say "set up the automations": the `setup` skill creates
   the memory filing pass (the scheduled task that files what sessions learn;
   skipped if you chose `memory_filing: in-session`)
   and, once WhatsApp is configured, checks its webhook routine. From then on the hooks put each session on the default branch and
   print the memory index; `CLAUDE.md` imports the contract, `WORKSPACE.md` and the
   digest.

Codex users: `.codex/hooks.json` and `.agents/skills/` wire the same engine.

## Updating

The engine lives in `agent-tools/`, versioned by `agent-tools/VERSION` and
described release by release in `agent-tools/CHANGELOG.md`. It includes the
contract, `agent-tools/AGENTS.md`, which `update.sh` reinstalls as your root
`AGENTS.md`.

```bash
agent-tools/update.sh --check    # installed vs upstream, changes nothing
agent-tools/update.sh            # pull upstream over agent-tools/, reinstall AGENTS.md
git diff && git commit -am "agent-tools: X.Y.Z"
```

What "upstream" means is your choice, recorded as `agent_tools_track` in
`workspace.yaml`:

- **`latest`** — the tip of this repo's default branch: what the author runs
  day to day, including work in progress. Every `update.sh` takes it.
- **`pinned`** (the default) — your workspace stays on the version in
  `agent-tools/VERSION` and nothing arrives unasked. Instead,
  `agent-tools/hooks/version-check.sh` compares that file with upstream's copy
  at session start, and when upstream is ahead the agent offers the update
  **with the changelog entries you do not have yet**: update now, not now, not
  this version, or stop offering. The last two are remembered in `workspace.yaml`
  (`agent_tools_version_skip`, `agent_tools_update_check: off`) so you are
  asked once. Taking it is `update.sh --accept`.

  Versions follow semantic versioning: a patch is a fix, a minor adds a feature
  or changes behaviour you may want to read about, a major changes the shape
  of your stored memory or something else you have to act on (`workspace.yaml`
  keys, file layout). Every major ships a migration, which the `migrate` skill
  runs after `update.sh`; anything it can't do is listed under **To do by
  hand** in the changelog. Pick this track if you would rather not be
  surprised.

Nothing reads git tags: a version is the text in `agent-tools/VERSION`, on
whichever branch you follow. `update.sh <tag|branch|full sha>` still overrides
the track for one run.

**Upgrading from 0.x to 1.0.0:** `event.yaml` and `EVENT.md` became
`workspace.yaml` and `WORKSPACE.md`. Commit the engine update, then run the
`migrate` skill; it renames them, fixes the `CLAUDE.md` import, and restructures
memory. Until then the engine still reads the old names.

**Before 1.0.0 there were no compatibility shims** — a breaking change is
described under **To do by hand** in the changelog entry, and you make it
yourself. **Upgrading from 0.5.0 or 0.4.x:** rename your `agent_tools_track`
(`tags` → `pinned`, `main` → `latest`) and the `agent_tools_tag_*` keys, and
point the `SessionStart` hook in `.claude/settings.json` and
`.codex/hooks.json` at `agent-tools/hooks/version-check.sh` — those files are
yours and no update writes to them, so until you do, nothing will tell you an
update has landed. `update.sh` says so when it notices. **Upgrading from 0.3.x
or earlier: copy the current `agent-tools/update.sh` from upstream over yours
before running it.** Older versions only knew about tags (0.2.0 and before) or copied the
template's *root* `AGENTS.md` over yours (0.3.x) — and since 0.4.0 that file is
the template's maintainer guide, not the contract.

Local edits to `agent-tools/` and `AGENTS.md` are overwritten on update — that
is the point. Per-workspace behaviour belongs in `workspace.yaml`, `WORKSPACE.md` and
`memory/`.

## Design notes

- [docs/spin-out-plan.md](docs/spin-out-plan.md) — what was extracted, from
  where, and why this shape rather than a plugin or a submodule. Historical:
  written when this was `event-workspace`.
- [docs/agent-ops-notes.md](docs/agent-ops-notes.md) — things learned running
  agents in ephemeral cloud containers: monitors, auto-mode, shallow clones.

## Licence

MIT — see [LICENSE](LICENSE).
