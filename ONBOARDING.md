# ONBOARDING — read this as your prompt, not as documentation

You are an agent turning a fresh clone of the
[`memory-workspace`](https://github.com/charlesbaynham/memory-workspace) template
into one person's own workspace — for an event, a project, life admin, or
whatever else they want an agent to remember across sessions. This file is the whole procedure. Follow
it top to bottom; it ends with a repository pushed to GitHub and a short list
of things only the human can do.

It is a **one-shot** document. You delete it in step 8, so the new repository
never carries it. If it is ever needed again, it is in upstream.

## What you are converting, and into what

The clone you are standing in is the **template**: the engine, the example
configuration, and this procedure. A **workspace** is what it becomes — the
memory store for one domain of work (an event, a project with a team, open-ended
life admin), with real configuration and no template scaffolding. The
two are told apart by one file: **a workspace has `workspace.yaml`; the template has
only `workspace.yaml.example`.** `agent-tools/lib.sh` makes exactly that test as
`in_template`, and three things key off it:

- `agent-tools/update.sh` and `agent-tools/sync-push.sh` **refuse to run** until
  `workspace.yaml` exists. That is correct, not a fault — do not work around it, and
  do not reach for `sync-push.sh` for the birth commit in step 8.
- `agent-tools/hooks/git-sync.sh` leaves the current branch alone while there is
  no `workspace.yaml`, and starts moving sessions onto the default branch once there
  is one.

So `workspace.yaml` is the moment of birth. Everything before step 4 is a template
checkout; everything after it is a workspace.

**Two `AGENTS.md` files, and you install the right one.** The root `AGENTS.md`
you can see now is the *template's maintainer guide* — how to develop the
engine. The contract a workspace session runs under is `agent-tools/AGENTS.md`,
shipped inside the engine. Step 4 copies it over the root file, and
`update.sh` reinstalls it on every update. The maintainer guide must not
survive into the new repository.

**Before anything else, check you are in the right place.** If `git remote -v`
still points at `charlesbaynham/memory-workspace` and nobody asked you to set up
a new workspace, you are standing in the template's own repository rather than a
clone of it — say so and stop, changing nothing. Ask if you cannot tell: a
fresh clone and the template itself look identical on disk.

## How to run the interview

The point of this document is that nobody hand-edits a prompt. **You ask, they
answer however they like.**

- **Ask with your harness's structured question tool** (in Claude Code,
  `AskUserQuestion`) wherever the answer is a choice from a short list — most
  of rounds 2 and 3, and questions 2, 3 and 5 of round 1. A menu with the
  options in front of them gets answered; a wall of prose gets skimmed and
  half-answered. If your harness has no such tool, ask in prose and carry on.
- **Put the default first and mark it** — `(Recommended)` in the label, and one
  line in the option's description saying what it commits them to. Set
  `multiSelect` where several answers can be true at once: co-users, which
  features are on, which agents will open the repository.
- **Free text is never closed off.** The tool carries an "Other" escape, and a
  prose answer to a menu question is a valid answer. Say so once, at the start.
- **Batch by round, inside the tool's limits.** Claude Code takes up to four
  questions per call with two to four options each, so a round may need two
  calls back to back — still one round's worth of thinking, not one question at
  a time, and never all fifteen at once. The genuinely open questions (the
  one-line description, anyone else worth knowing about, the repository name) go as plain
  text in the message that carries the call.
- Prose answers, partial answers, "you decide", and answers to questions you
  did not ask are all valid. Take what they give you and carry on.
- Every question has a default. Offer it. If they skip a question, use the
  default and tell them so in the recap.
- The person running setup is an **owner** in this workspace's terms:
  technical, terse, no emoji. Say the number, name the file.
- Do not touch the network or write a single file until they have confirmed the
  recap at the end of step 2. Reading the repository is fine and expected.

## 1. Orient yourself

Read, in this order: `agent-tools/AGENTS.md`, `workspace.yaml.example`,
`WORKSPACE.md.example`, `README.md`, `docs/agent-ops-notes.md`. The contract comes
first because it is what every later session in the new repository is bound by —
you cannot configure a workspace sensibly without it. The README describes the
template to a newcomer; step 6 replaces it with one about this workspace.

The shape to keep in mind: `agent-tools/` is the **engine** — vendored,
overwritten wholesale by `update.sh`, contract included. Everything about *this
workspace* lives in `workspace.yaml` (facts the tooling reads), `WORKSPACE.md` (standing
rules, who is who, stock answers) and `memory/`. You fill in the second set and
leave the first alone.

## 2. The interview

### Round 1 — what it is for, and the people

1. **What is this workspace for?** A choice first — **an event** (a wedding, a
   conference, a festival), **a project with a team**, **open-ended life
   admin**, or something else — then one line, the way they would say it:
   *"Ada & Ben's wedding, 12 June 2027"*, *"the lab's new cryostat build"*,
   *"household admin: bills, car, house, health"*. The line goes in
   `workspace.yaml: name` and the digest; the kind shapes `WORKSPACE.md` (step 4)
   and which defaults you suggest below. An event has an end date; a project
   may; life admin does not — say in the recap whether this one is expected to
   wind down.
2. **Owners** — whose word is authoritative. Technical register. Default: the
   person you are talking to, alone.
3. **Co-users** — anyone else who will use the workspace: a partner planning
   the event, a project's teammates, a family member sharing the admin. They
   get the warm register by default (plain language, no paths or git talk,
   emoji welcome); ask whether any of them is technical, and note it in
   `WORKSPACE.md` if so. Default: none.
4. **Anyone else worth knowing about now?** A planner or venue contact, a
   collaborator or supplier, the accountant or landlord. Optional; it seeds
   `WORKSPACE.md`.
5. **Where do the facts live — the source of truth?** For an event a Google
   Sheet is the common answer; for a project its tracker, repository or shared
   drive; for life admin a task manager, a Drive folder, or nothing. Several is
   fine. A workspace *indexes* the source of truth and never replaces it, so if
   they say "here" or "nowhere", say plainly that there will be no live data to
   read and that memory becomes the only record.

### Round 2 — features

This round is the clearest case for the question tool: every row below is a
small choice with a default. Memory itself is not optional, but who files it is
a question, so all seven split into two calls — memory filing, Sheets, WhatsApp,
auto-mode, then agents, track and default branch. Mark the defaults, and say
that "all the defaults" is a complete answer.

| Feature | Question | Default |
|---|---|---|
| **Memory filing** | Memory itself is not optional; it is the reason the repository exists. Who files what sessions learned? `scheduled`: a scheduled task, nightly by default, set up by the `setup` skill after birth (§9). `in-session`: no task; whichever session finds the log past a threshold (50 entries, `memory_filing_threshold`; ask only if they care) files it before it ends. Choose `in-session` for a repository where a scheduled task is unwelcome (cost, no way to attach the repo, a team that wants nothing running unattended) | `scheduled`; recommend it |
| **Google Sheets** | Is the source of truth a Sheet you want the agent to read and write in place? Needs a one-off Google Cloud step from you. | on if they named a Sheet in round 1 |
| **WhatsApp bot** | A dedicated number people text — an event's guests, a project's team — answered by the workspace, with an isolated send-gate on every reply. Needs a spare phone number and a bridge you host. Optional for every kind of workspace. | later for an event; off otherwise |
| **Auto-mode rules** | Classifier rules kept in the repo and installed into a cloud environment, so routine work runs unattended. Only meaningful for Claude Code on the web. | on; recommend it, whichever way they open the repository |
| **Agents** | Which coding agents will open this repository? Claude Code, Codex, both, something else that reads `AGENTS.md`. | both wired; costs nothing |
| **Upstream track** | How `update.sh` follows upstream: `latest` = the author's current tip, work in progress included; `pinned` = stays on the version it has, with a session-start check that offers newer ones (changelog and all) and remembers a no. | `pinned`; recommend it |
| **Default branch** | `main` unless they have a reason. | `main` |

Three things to be straight about when they ask:

- **WhatsApp is the one feature with real prerequisites**: a second phone
  number and handset, a bridge with an MCP surface and outbound webhooks
  (`agent-tools/skills/whatsapp/setup.md` names the one this was built
  against), and that bridge reachable from claude.ai as a connector. "Later"
  is the right answer for most people on day one, and nothing else depends on
  it.
- **A feature they turn off is not installed.** Google Sheets and WhatsApp are
  on exactly when `workspace.yaml` has a `sheets:` / `whatsapp:` block, and
  step 4 runs `agent-tools/features.sh`, which removes the skills, scripts and
  registrations of whichever is absent. `update.sh` runs it too, so they stay
  gone. Turning one on later is the `configure-features` skill ("add WhatsApp").
  "Later" for WhatsApp keeps the block (commented as unused), so its skill
  stays available for the setup walk-through.
- **The engine is not theirs to edit.** `agent-tools/` and the root `AGENTS.md`
  are overwritten on every update; per-workspace behaviour goes in `workspace.yaml`,
  `WORKSPACE.md` and `memory/`. Say this once now — it is the mistake that costs a
  consumer real work later.

### Round 3 — where it lives

1. **GitHub repository** — owner/name, which is free text, and visibility,
   which is a choice: private (default — the memory is deliberately readable by
   every session and is not written to be public) or public.
2. **How will you open it?** A choice: Claude Code on the web (a cloud
   environment, so the auto-mode installer's discovery block needs to go in the
   environment's setup script), locally, or both.

### Recap, then stop

Write back everything you have as a filled-in summary — what it is for and its
one-line description, owners
and co-users, source of truth, each feature on/later/off, repository name and
visibility, track, default branch, and any defaults you applied because they
skipped a question. Ask one question: **is this right?**

Ask it with the question tool as well — "go ahead" against "something needs
changing", so a yes is one click and a correction arrives as their own words.
Wait for the answer. Change what they correct, and re-ask if the correction
touches enough to be worth confirming again. Only then write files.

## 3. Make it their repository, not a fork

```bash
rm -rf .git && git init -b main        # or their chosen default branch
```

This is the first thing you write. It stops a later `git push` going somewhere
surprising, and it is the honest signal that upstream is a template rather than
a parent — nothing is merged from it again; `update.sh` vendors the engine
instead. The clone directory should be named for the workspace; rename it if they
asked for a name and it does not match.

## 4. Write the configuration

```bash
cp workspace.yaml.example workspace.yaml
cp WORKSPACE.md.example WORKSPACE.md
cp automode.json.example automode.json     # only if auto-mode rules are on
cp agent-tools/AGENTS.md AGENTS.md         # the contract, over the template's maintainer guide
```

Keep the `.example` files. They are the reference for which keys `lib.sh` and
the skills actually read, and `update.sh` never touches them.

**`workspace.yaml`** — `name`, `default_branch` (match what you passed to
`git init`), `agent_tools_track`, `owners`, `co_users`, `source_of_truth`,
`memory_filing` and `memory_filing_threshold` (the example ships them set to the defaults; change them only to what they chose), `sheets` (ids, not URLs; **delete the block if Sheets is off** — the gsheets skill is then removed below). The `whatsapp`
block: fill it in if the bot is on; if it is "later", leave the example values
and add a comment on the block saying it is unused until the bot is set up, so
no session mistakes an example prefix for a real connector; if it is off,
**delete the block** — without one, the workspace has no bot and the WhatsApp
skill, send-gate and `memory/whatsapp/` are removed.

**Prune the features they did not choose** — once `workspace.yaml` is final:

```bash
agent-tools/features.sh      # lists what it removed; "nothing to prune" if both are on
```

With WhatsApp off, also `rm -rf memory/whatsapp` (step 5 otherwise keeps it), and
drop the WhatsApp entries from `automode.json` (its `environment`, `allow` and
`hard_deny` sentences about the bot) rather than installing rules for a bot that
does not exist.

**`AGENTS.md`** — the copy above, unedited. It is the workspace's contract and
`update.sh` replaces it wholesale; an edit here is silently lost on the next
update. If something in it is wrong for this workspace, that belongs in `WORKSPACE.md`.

**`WORKSPACE.md`** — rewrite it for this workspace rather than editing the
example's names in place. Open with what it is for (round 1 question 1) and its
scope — for life admin especially, what is in and what is out. Who is who, with
each person's register. The source of truth and its tabs or folders. Anything
from round 1 question 4. The example is written for an event; its comments say
what to swap in for a project or life admin. Drop the sections that do not
apply (there is no bot register if there is no bot) and keep the headings that are
empty but will fill up — stock answers, things that always go to the owner. Do
not invent facts: an empty section with a heading beats a plausible guess.

**`CLAUDE.md`** — it ships with a parenthetical and a release note about the template's maintainer
guide, which is now irrelevant here. Trim it to a line or two saying the
contract, the workspace's rules and the digest are imported so they are present from
the first turn. Leave the three `@` imports exactly as they are, and note what
they oblige: `AGENTS.md`, `WORKSPACE.md` and `memory/digest.md` must all exist
before the first session, or the import fails.

**`.claude/settings.json`** — the `permissions.allow` list ships with the
example's WhatsApp prefix. If the bot is on, replace it with the real connector
name **in both spellings** (`mcp__<Name>__*` and `mcp__claude_ai_<Name>__*`):
cloud and local sessions see different prefixes, and granting only one is why
sends get denied. If the bot is not on, remove both entries — a stale allow rule
for a connector that does not exist is noise in every session. Leave the
`SessionStart` hooks alone.

**Agent wiring** — `.claude/` (settings, the skill symlinks, the send-gate
agent) serves Claude Code; `.codex/hooks.json` and `.agents/skills/` serve
Codex. Leave both unless they asked for one gone. If they named a third agent,
tell them what it must read at session start (`AGENTS.md`, `WORKSPACE.md`,
`memory/digest.md`) rather than guessing at its hook format.

**Nothing secret goes in the repository.** Not now, not later. `sa.json` is
already gitignored; keys live in the agent environment.

## 5. Reset and seed the memory

`memory/` currently holds the **template's** own working memory. None of it is
about this workspace, and it must not be inherited.

- **Reset the four files to their empty forms**, keeping every heading and
  header comment exactly as shipped — the filing pass relies on them:
  `memory/log.md` down to its header comment plus the
  `<!-- compaction-baseline: fresh workspace -->` line; `memory/digest.md` to
  its five headings with `*(empty)*` under each; `memory/user-edits.md` to its
  header plus `1. *(none yet)*`; `memory/filing-state.md` as shipped
  (`last_run: never`). Leave `memory/notes/.gitkeep` and
  (when WhatsApp is on or "later") `memory/whatsapp/AGENTS.md` and `CLAUDE.md` in place; delete any note or
  thread file that is not one of those.
- **Then log this session**, one line each,
  `- [YYYY-MM-DD] TYPE: observation`: the feature choices as `DECISION` lines
  with their reasons, the repository URL and any spreadsheet ids as `RESOURCE`
  lines, every prerequisite still outstanding as an `OPEN` line. Provenance
  matters: their choice is a decision, your recommendation is a suggestion
  until they took it.
- **Fill in the digest's Purpose & context and Tools & resources** from the
  interview — a few lines each, no more. Leave the other three sections for the
  first filing pass.
- Never use `@` inside `memory/`. Imports recurse, and one `@` line would load
  the whole tree into every session — Markdown links from the repo root
  instead.

## 6. Rewrite the README for this workspace

The README you inherited sells the template to a newcomer and tells them to
clone it. Replace it with a short one for this repository: what this workspace
is and what it serves (the event, the project, the admin), where the source of
truth lives, which features are on, how a session starts (the hooks, the imports), and how to update the
engine (`agent-tools/update.sh --check`, then `update.sh`, then commit the
diff). Link `docs/agent-ops-notes.md`, which the contract also cites.

`docs/spin-out-plan.md` is the template's own design history and nothing in a
workspace refers to it — delete it unless they want to keep it. Delete the
`bump-version` skill too (`.claude/skills/bump-version/`,
`.agents/skills/bump-version/`), and the release workflow
(`.github/workflows/release.yml`; remove `.github/` if that leaves it empty):
releasing engine versions is the template's job, and a workspace only ever
receives them.

## 7. Check it actually looks like a workspace

Before the first commit, prove the conversion took. Every one of these has been
run through a real conversion, so the expected output is known:

```bash
test -f workspace.yaml && head -1 AGENTS.md  # "…a memory store and agent workspace for one
                                             #  domain" — the contract. If it says "the template,
                                             #  and how to maintain it", step 4's copy did not happen.
agent-tools/update.sh --check                # prints installed/upstream VERSION and the track;
                                             #  it refused before workspace.yaml existed
agent-tools/hooks/git-sync.sh                # "could not fetch origin/main" until step 8 adds
                                             #  origin — expected, and it exits 0
agent-tools/hooks/memory-check.sh            # no notes yet, a nearly empty log, "no nightly memory
                                             #  pass has run here yet", digest empty: the fresh seed
agent-tools/hooks/automode-check.sh          # silent if auto-mode is off; a drift report is
                                             #  expected until install.sh runs from this repo
agent-tools/hooks/version-check.sh           # on the pinned track: "pinned to X.Y.Z; nothing
                                             #  newer upstream" (you have just cloned it).
                                             #  Silent on any other track.
grep -rn '^@' memory/*.md memory/notes/      # nothing. (memory/whatsapp/CLAUDE.md is the one
                                             #  deliberate import and is not in that set)
ls -l .claude/skills .claude/agents          # symlinks, relative, resolving into agent-tools/;
                                             #  no bump-version/ left (step 6); no gsheets or
                                             #  whatsapp entry (nor whatsapp-send-gate.md) for a
                                             #  feature that is off (step 4)
test ! -e .github/workflows/release.yml      # gone (step 6), or the workspace cuts releases
```

Fix anything that complains beyond those expected messages. A hook that fails
here fails in every session.

## 8. Delete this file, commit, push

Create the GitHub repository from their round 3 answer with whatever you have —
the `gh` CLI, a GitHub MCP tool, or asking them to create it in the browser and
paste the URL. Add it as `origin`. Then:

```bash
rm ONBOARDING.md
git add -A
git commit -m "New workspace from memory-workspace <contents of agent-tools/VERSION>"
git push -u origin main
```

One commit is right: this is the repository's birth, not a change to it. Plain
`git push` is right too — `sync-push.sh` is for later sessions, once there is an
upstream branch to rebase onto.

## 9. Hand over

Tell them what is left, listing only what their answers actually require:

- **Google Sheets**: run `agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh`
  once in Google Cloud Shell, put the key it prints into the agent environment
  as `GOOGLE_SERVICE_ACCOUNT_KEY` (not into the repository), and share the Sheet
  with the service-account address it prints.
- **Claude Code on the web** (only if auto-mode rules are on): run
  `agent-tools/automode/install.sh --snippet` and have them paste what it prints
  into the setup script of the cloud environment they launch from — their
  default one is fine and is the usual choice. It has to run before the session
  starts (`docs/agent-ops-notes.md` explains why a repository cannot ship
  classifier rules itself), and it is safe to share: it finds memory workspaces
  among the checked-out repositories, installs the rules of each, and does
  nothing when a session has none, so it is never needed per repository and
  never needs re-pasting. If they already have a block that writes `autoMode`,
  the new one goes after it; it adds to the rules and never replaces them.
- **The automations** — when `memory_filing` is `scheduled` (the default), or
  WhatsApp is configured: open a session in the new repository and say "set up
  the automations". The `setup` skill creates the nightly memory pass (the
  scheduled task that files what sessions learn), proves it with one run, and
  handles the WhatsApp wake too once WhatsApp is configured. Until it has run,
  nothing files what sessions log. With `in-session` there is no task to
  create: say instead that sessions file memory themselves once the log passes
  `memory_filing_threshold` (50) entries.
- **WhatsApp, now or later**: the prerequisites are in
  `agent-tools/skills/whatsapp/setup.md`. When they have them, open a session in
  the new repository and say "set up the WhatsApp routine"; the skill walks both
  parties through it.
- **Features they skipped**: say that "add WhatsApp", "add Google Sheets" or
  "add more features from the original repository" in a session starts the
  `configure-features` skill, which turns them on later (and removes one
  on request).
- **Nothing, if none of the above** — say that too, and say what the first
  useful session looks like instead: open the repository and start telling it
  about the event, the project or the admin.

Say in one line where the work went (the repository URL and the commit) and that
from here on sessions commit straight to the default branch, as the contract
requires. Then stop. Offer to carry on with actual work, but do not start
it unasked.
