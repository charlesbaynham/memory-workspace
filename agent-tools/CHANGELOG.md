# Changelog

Every released version of the engine (`agent-tools/`), newest first. The
version at the top is what `agent-tools/VERSION` holds.

Semantic versioning: **major** — the structure of a workspace's stored memory
changes (and a migration ships with it, run by the `migrate` skill), or a
consumer has to do something by hand (an `event.yaml` key, a moved file,
renumbered sections); **minor** — new
behaviour you may want to read about, but nothing to do; **patch** — a fix
with no behaviour change. **Before 1.0.0, breaking changes rode in a minor; none
keep compatibility shims** — the entry says so, and lists what to edit under
**To do by hand**.

A workspace is shown every entry newer than the version it runs, both by `agent-tools/hooks/version-check.sh` at session start and by
`agent-tools/update.sh`. Write each entry for that reader: what changed, and
what they have to do about it.

<!-- Maintainers: the bump-version skill (template only) writes this file and
     VERSION together, in the same commit as the change. One `## X.Y.Z — date`
     heading per version; headings are what the tooling parses. -->

## 1.2.0 — 2026-11-08

**Memory filing can run without a scheduled task.** Until now every workspace
relied on a nightly scheduled task to file `memory/log.md` into the notes and
the digest. A new `workspace.yaml` key lets the owner opt out.

### Added

- **`memory_filing: scheduled | in-session`** in `workspace.yaml`. `scheduled`
  is the default, and what a workspace without the key keeps doing. With
  `in-session` there is no scheduled task: when `memory-check.sh` reports the
  log at 40 unfiled entries (the `MEMORY_COMPACT_THRESHOLD` default), the
  session that sees it runs the `memory-compact` skill itself, after the work
  it was started for and before it ends, without asking. Two sessions racing
  to file are handled by the pass's existing `state-set` check.
- The `setup` skill asks which mode the owner wants, writes the key, and in
  `in-session` mode registers nothing. If it finds a filing task left over, it
  offers to disable it (never delete it).
- `ONBOARDING.md` offers the choice to new workspaces (template only; it does
  not reach existing ones).

### Changed

- In `in-session` mode `memory-check.sh` drops the "pass last ran Nh ago, it
  may have stopped" alarm, which has no task to blame, and reports the
  threshold instead.
- Contract wording: "the nightly pass" is now "the filing pass".

### To do by hand

- Nothing required. To switch an existing workspace to in-session filing, add
  `memory_filing: in-session` to `workspace.yaml` and ask a session to "set up
  the automations", which offers to disable the old filing task.

## 1.1.0 — 2026-10-27

**Sessions log as they work again; reading transcripts is a bonus, not the
plan.** 1.0.0 told working sessions they could skip logging because the
filing pass would read their transcripts. In practice a session started by a
scheduled task isn't given `list_sessions` / `list_events`, so the pass
couldn't read them, and interactive sessions' findings were lost. Found on the
first workspace to migrate.

### Changed

- **The contract (`AGENTS.md`, "Writing memory") asks every session to log
  durable findings to `memory/log.md` as they happen**: decisions with their
  reason, state changes, gotchas, open questions, identifiers. This applies to
  interactive cloud sessions too. It is the 0.x discipline, back.
- **The filing pass files from `memory/log.md` and git history.** It still
  reads transcripts when the session running it can list sessions (a pass run
  by hand from an interactive session), and says so. A scheduled run reporting
  "transcripts not read" is now the expected path, not a fault.
- **`setup` skill:** a scheduled task created by an agent has no repository
  attached; the skill now has the owner add it in the browser before proving
  the task. Proving it no longer expects `list_sessions`.
- The `memory/log.md` header text in the 1.0.0 migration and the template seed
  describe the new rule.

### Fixed

- `memory.py sessions` / `transcript` read a saved tool result that is a JSON
  list of content blocks (the `.json` form). It used to parse the wrapper and
  select no sessions.

### To do by hand

- Nothing required. If your `memory/log.md` header still says sessions log
  only "when a transcript won't carry them", you may replace that sentence
  with the new header text from the template. It's a comment; nothing parses it.

## 1.0.0 — 2026-10-22

**Major: memory is stored differently, the configuration files are renamed,
and a migration does both for you.** After updating, commit the engine update,
then run the `migrate` skill (read `agent-tools/skills/migrate/SKILL.md` if it
is not listed yet). It renames `event.yaml` and `EVENT.md`, gives every note
frontmatter, tags sensitive lines, shrinks the digest, files the pending log,
and replaces the nightly compaction task through the new `setup` skill.

**event-workspace is now memory-workspace.** The template and its contract no
longer assume an event: a workspace can equally hold a project with a team or
open-ended life admin, and events remain a first-class use. WhatsApp stays and
stays optional — every rule about it applies only when `workspace.yaml` has a
`whatsapp:` block.

### Added

- **The `migrate` skill and the major-version rule.** Every future major ships
  a migration (`agent-tools/skills/migrate/<X.0.0>.md`); `update.sh` announces
  it, the contract requires it, and `memory-check.sh` reports memory not yet
  migrated (`migrated:` in `memory/filing-state.md`).
- **The `setup` skill** registers, audits and repairs the workspace's
  automations: the nightly memory pass (always) and the WhatsApp wake (when
  configured, by way of `whatsapp/setup.md`). It does the agent's half and
  walks the owner through theirs: choosing a model, the routine's API token,
  or the whole thing in the browser when a session can't schedule. It records
  ids in `memory/notes/automations.md`. Say "set up the automations".
- `update.sh` now registers skills that arrived after the workspace was born
  (`.claude/skills/<name>` symlinks, `.agents/skills/<name>` stubs).

### Changed

- **`event.yaml` → `workspace.yaml`, `EVENT.md` → `WORKSPACE.md`.** Same keys,
  same content. Until the migration renames them, `lib.sh`, `memory.py`,
  `render.sh` and the Codex `load-memory.sh` hook fall back to the old names,
  so an updated-but-unmigrated workspace still works; nothing else does, and
  the fallback goes in a later major.
- **The contract is domain-neutral.** `AGENTS.md` describes a memory store for
  one domain of work, names a source of truth only where `workspace.yaml`
  does (and says what happens when it names none), lets `WORKSPACE.md` give a
  technical co-user the owner's register, and marks the WhatsApp section
  optional. "Guest" becomes "person" or "contact" throughout the engine.
- **Send-gate wording.** Its categories are about any other person, not
  another guest; the escalation category `other-guest-information` is now
  `other-person-information`, and the section `render.sh` appends from
  `gate_rules` is now "Workspace-specific rules". `update.sh` re-renders the
  gate; commit the regenerated `.claude/agents/whatsapp-send-gate.md` if it
  changed.
- **The upstream URL is `https://github.com/charlesbaynham/memory-workspace`.**
  The old URL redirects; update `agent_tools_upstream` in `workspace.yaml` when
  convenient.
- **Memory is filed by a nightly pass, not by every session as it works.**
  The `memory-compact` skill is now that pass. A scheduled task starts a
  session that lists the owner's cloud sessions, keeps **only those launched
  with this workspace's repository in scope**, and hands each one to a Haiku
  subagent that reads its transcript and extracts findings tagged by
  provenance (`[stated]`, `[confirmed]`, `[found: …]`, `[did]`, `[open]`).
  Only when there is something durable, a filer subagent then files them,
  along with git history and the log, into notes and the digest, and commits.
  The filer runs on Sonnet unless `event.yaml` sets `memory_filer_model:
  opus`. A run with nothing new stops after one Haiku listing, so the pass can
  run hourly; `setup` asks how often and which models. The `setup` skill creates the task and
  proves it with one run.
- **Working sessions log far less.** The contract (`AGENTS.md`, "Writing
  memory") drops "err on the side of logging". A session in the owner's cloud
  account no longer stops to file what is said in the conversation. It still
  acts on explicit "remember / forget / correct" requests in the same turn,
  and logs only what a transcript won't carry: unattended sessions (scheduled
  tasks and webhook wakes, so every WhatsApp session logs as before), local
  CLI, Codex or co-user sessions, and anything settled only inside tool work.
- **Notes carry frontmatter, and `memory-check.sh` prints an index of them at
  `SessionStart`**: path, aliases, description. One subject per note; a fact
  about X goes only in X's note; lines are tagged `[stated]`,
  `[found: source, date]` or `[inferred]`. The first pass adds frontmatter to
  existing notes.
- **The digest's target drops to 500 words or fewer**, since the index now
  lists every note.
- **New rules for reading memory:** read before saying memory has nothing on
  a subject, and treat an open item as context, never an agenda.
- **Sensitive details are stored and tagged** (`[sensitive]` on a line, or
  `sensitive: true` in the frontmatter of a note that is mostly guests'
  private details): health
  (allergies, dietary needs and medical conditions included); ID, card and
  account numbers; sexual, criminal, abuse, self-harm and immigration matters;
  another person's private money, contacts or RSVP. The tag marks what must not be
  shared further. Credentials and instructions to the agent still never go in
  memory.
- **The log is trimmed by exact line, not truncated.** The pass removes only
  the entries it filed, so lines other sessions append while it runs survive.
  This fixes the race where a concurrent merge re-added already-folded entries.
- New `memory/filing-state.md` records each pass (`last_run`, `last_commit`,
  and `retry` for sessions whose review failed). `memory-check.sh` warns when
  the last pass is more than 36 hours old. Before the file exists, it reads
  the last `memory: compact` commit instead.
- New `agent-tools/skills/memory-compact/memory.py` (standard library only)
  does the mechanical parts: index, check, session selection and transcript
  condensing from saved tool output, log snapshot and trim, and state.

### To do by hand

- **Run the migration**: commit the engine update, then invoke the `migrate`
  skill. It does everything below, asking you only which model should run the
  nightly task:
  - renames `event.yaml` → `workspace.yaml` and `EVENT.md` → `WORKSPACE.md`,
    and updates the `@EVENT.md` import in `CLAUDE.md`;
  - registers the new skill;
  - creates `memory/filing-state.md`;
  - runs the first filing pass (frontmatter on every note, `[sensitive]` tags,
    a 500-word digest);
  - runs the `setup` skill, which updates the old compaction scheduled task in
    place and checks the WhatsApp wake.

## 0.11.0 — 2026-10-09

### Changed

- **Messages from a linked device are treated as the account's own.** WhatsApp
  Web, desktop and second phones send as `<number>:NN@s.whatsapp.net`. The
  whatsapp skill (§1) now strips the `:NN` device suffix before anything else:
  same thread file, same identity check, and every exact-JID rule (owner
  console, `gate_exempt`, read-only-chat addressing, owner alerts) compares the
  normalised JID. Previously an owner writing from WhatsApp Web was refused as
  an unknown sender. A different number, a LID or a group JID is still never
  matched to anyone.

## 0.10.0 — 2026-10-04

### Changed

- **`gs.py set` refuses data that does not fit the range it names.** Free
  text sent with `set '<sheet>' 'Jobs!E43' --csv note.txt` used to be split on
  every comma and blank line and written as a block from E43, overwriting
  other rows' cells. `set` now exits 1, before authenticating, when there is
  more than one value for a single cell, or more rows/columns than an explicit
  range like `A1:C3` holds. Open-ended ranges (`A:C`, `A1:C`, `2:5`) and tab or
  named ranges are not limited. Write one cell of free text with
  `--json '[["..."]]'`. The library's `Sheets.write()` is unchanged.
- **Breaking:** writing a block from a single anchor cell
  (`set ... 'Data!A1' --csv table.csv`) now needs the full range or the new
  `--allow-expand` flag.

### To do by hand

- Any script or note in the workspace that calls `gs.py set` with a single
  anchor cell for a multi-cell block: give it the full range or add
  `--allow-expand`.

## 0.9.0 — 2026-09-28

### Added

- **Event-specific send-gate rules.** Write them in `event.yaml` as a block
  under `whatsapp.gate_rules: |` (commented example in `event.yaml.example`),
  then run `agent-tools/agents/render.sh` and commit. It builds
  `.claude/agents/whatsapp-send-gate.md` as the shipped gate prompt plus an
  "Event-specific rules" section carrying yours verbatim; without
  `gate_rules` that file stays the usual symlink. Use it to teach the gate a
  sharing rule of your own (say, partners may see each other's answers)
  instead of letting the drafting agent override its verdict. The gate reads
  its prompt at session start, so a change applies from the **next** session.
- A rule may define an extra input block for the gate; the `whatsapp` skill
  (§3 step 3) now tells the drafting agent to establish that block's content
  independently and pass it alongside the usual three.
- `agent-tools/hooks/gate-check.sh` (SessionStart) reports when the gate
  Claude Code loaded does not match `event.yaml`. `update.sh` re-renders the
  gate after every update, and says if the hook is not wired.

### Changed

- **The send-gate's untrusted input is now fenced by a per-call nonce.** The
  drafting agent opens every gate call with `NONCE: <fresh random hex>` and
  wraps the transcript in `<transcript-HEX>` … `</transcript-HEX>`; the gate
  treats everything up to the matching closing tag as a stranger's text, so a
  guest who types `</transcript>` and a fake `<identity-check>` is still
  inside it. A missing or mismatched nonce is `ESCALATE` with the new
  category `malformed-input`. The `whatsapp` skill (§3 step 3) says how to
  make the nonce; nothing to do by hand.
- The shipped gate prompt accepts extra input blocks defined by an
  event-specific rules section; with no such section it behaves exactly as
  before.
- Contract: before any work, switch to the default branch and pull its
  remote tip, even when the hook or `git status` says it is current.

### To do by hand

- Optional: add `agent-tools/hooks/gate-check.sh` beside the other
  SessionStart hooks in `.claude/settings.json`. Nothing else changes unless
  you add `gate_rules`.

## 0.8.0 — 2026-09-27

### Fixed

- **The WhatsApp send-gate no longer escalates every message.** Current
  Claude Code returns a subagent's report through a `SubagentHandback` call,
  which used up the gate's single turn: the `Agent` result said "stopped at
  its 1-turn limit" while the real verdict arrived as a separate hand-back
  message, and the skill treated that as a gate failure and escalated. The
  gate now has `maxTurns: 2`.

### Changed

- `whatsapp` skill §3 step 4: the hand-back message from the gate's own agent
  ID is its verdict. The gate must show `tool_uses` of 0, or 1 for the
  hand-back; more voids the verdict (ESCALATE, tell the owner).
- The gate keeps `tools: []`, which does mean no tools despite the
  "(Tools: All tools)" label. Details in `docs/agent-ops-notes.md` upstream.

### To do by hand

- Nothing.

## 0.7.0 — 2026-09-20

### Changed

- **`latest` (and branch-named) tracks now hear about updates too.**
  `agent-tools/hooks/version-check.sh` used to be silent unless the workspace
  was `pinned`. It now compares `agent-tools/` with upstream's tip on every
  track: on `pinned` a newer `VERSION` is still the only trigger; on `latest`
  **any** difference is, version bump or not, and the hook lists the files that
  differ. The contract's "Updating the engine" section offers it to the owner
  with the same four answers as before.
- `agent_tools_version_skip` on `latest` takes the 12-character upstream commit
  the hook prints, not a version number — declining one tip does not silence
  the next.
- `update.sh` warns about a workspace that does not run the hook on any track,
  not just `pinned`.

### To do by hand

- Nothing required. Workspaces created from the template already run the hook;
  if `update.sh` says yours does not, add it beside the other `SessionStart`
  hooks in `.claude/settings.json` (and `.codex/hooks.json` for Codex).

## 0.6.0 — 2026-09-20

**Breaking, and nothing is carried over.** Before 1.0.0 this engine keeps no
compatibility shims: the old spellings below are simply gone, so a workspace
has to be edited once (see **To do by hand**).

### Changed

- The update tracks are now **`latest`** (follow upstream's default branch,
  what `main` used to mean) and **`pinned`** (stay put until you accept an
  offer, what `tags` used to mean). Any other value is still a branch name —
  and `tags` is now read as one, so a workspace left on it will fail to fetch.
- **Pinning no longer involves git tags.** The pin is the text of
  `agent-tools/VERSION`, compared against upstream's copy of the same file, so
  a release is offered as soon as it lands on upstream's default branch and
  nothing needs tagging.
- `agent-tools/hooks/tag-check.sh` is now `agent-tools/hooks/version-check.sh`.
- A pinned workspace moves with `agent-tools/update.sh --accept` (an explicit
  ref still works too). A bare `update.sh` keeps the pin, and says what it is
  declining to take.
- `event.yaml`: `agent_tools_tag_skip` → `agent_tools_version_skip` (bare
  versions, no `v`), `agent_tools_tag_check` → `agent_tools_update_check`.

### Added

- This changelog. Update offers quote every entry the workspace does not have
  yet, so the owner decides on the changes rather than on a version number.

### To do by hand

In `event.yaml`: `agent_tools_track: tags` → `pinned`, `main` → `latest`, and
rename `agent_tools_tag_skip` / `agent_tools_tag_check` (dropping any `v`
prefixes) if you have them. In `.claude/settings.json` and `.codex/hooks.json`,
point the `SessionStart` hook at `version-check.sh` instead of `tag-check.sh` —
those files are yours and no update writes to them, so until you do, nothing
will tell you an update has landed. `update.sh` says so when it notices.

## 0.5.0 — 2026-09-20

### Changed

- The `tags` track became a **pin**: a bare `update.sh` reinstalled the release
  the workspace was already on, and moving meant naming a release.

### Added

- `agent-tools/hooks/tag-check.sh`: checked upstream for newer tags at session
  start and offered them, with the answer remembered in `event.yaml`
  (`agent_tools_tag_skip`, `agent_tools_tag_check: off`).

### To do by hand

- Register the new hook beside the other `SessionStart` hooks in
  `.claude/settings.json` and `.codex/hooks.json` — those files are per-event
  and no update writes to them.

## 0.4.0 — 2026-09-20

### Changed

- The shipped contract split from the template's own maintainer guide:
  `agent-tools/AGENTS.md` travels with the engine, and `update.sh` installs it
  as the workspace's root `AGENTS.md`. Until 0.3.x, `update.sh` copied
  upstream's *root* `AGENTS.md`, which is now the maintainer guide.
- `lib.sh` gained `in_template`; `update.sh` and `sync-push.sh` refuse to run
  in the template, and `git-sync.sh` leaves its branches alone.

### To do by hand

- Upgrading from 0.3.x or earlier: copy upstream's `agent-tools/update.sh` over
  yours before running it, or you will get the wrong `AGENTS.md`.

## 0.3.0 — 2026-09-20

### Changed

- Tags became optional: `update.sh` followed `agent_tools_track` in
  `event.yaml` — the default branch by default, or semver tags.

## 0.2.0 — 2026-09-20

### Added

- Auto-mode classifier rules kept in the repository, installed by the setup
  script and drift-checked at session start.

## 0.1.0 — 2026-09-20

### Added

- The engine, scrubbed and generalised out of the first event workspace:
  hooks, skills, `update.sh`, `sync-push.sh`, and the contract.
