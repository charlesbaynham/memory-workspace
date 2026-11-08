# Running agents in ephemeral cloud containers — things learned

Short, generic, and each one cost an afternoon somewhere.

## A bare background process is not a monitor

The container sleeps the moment the session goes idle. Every unmanaged process
in it freezes — a `run_in_background` polling loop, its `sleep` backstop, a
`tailscaled`. It resumes only when something else wakes the session, and then
reports as if nothing happened. The harness's `Monitor` tool is the exception:
it keeps the session alive across the wait. Use `Monitor` for anything that
must survive an idle turn. When ending the turn is preferable, use a wake from
*outside* the container — a scheduled routine, `send_later`, a PR subscription,
a webhook.

**Every monitor needs a backstop that fires even if the thing it's watching for
never happens.** A typo in the condition otherwise hangs the task silently.
Before starting one, know exactly what "done" looks like; pair the condition
with a maximum wait; and treat hitting the timeout as the prompt to work out
*why* (slow, wrong, or genuinely stuck), never as an answer in itself.

## `autoMode` classifier rules: where they are read from, and when

Claude Code's auto-mode classifier reads `autoMode` from user settings
(`~/.claude/settings.json`), managed settings and the `--settings` flag only.
A block in a repository's `.claude/settings.json` or `.claude/settings.local.json`
is skipped with a logged warning (the local file was dropped in v2.1.207) — a
repo must not be able to grant itself allow rules. `permissions.allow/ask/deny`
and hooks in the repo *are* read. Plugins cannot carry `autoMode` either.

Measured in a cloud session on 2026-09-20 (Claude Code 2.1.278):

- **The container's own `~/.claude/settings.json` is read.** Rules an
  environment setup script had written there appeared in
  `claude auto-mode config` alongside the defaults. The settings doc's "user
  settings are not read in cloud sessions" means your laptop's file is not
  shipped; the file inside the container is ordinary user settings.
- **A change made after session start is not honoured.** A `hard_deny` naming
  an exact command, written mid-session (in manual mode, since in auto mode
  the classifier denies the write itself as self-modification), showed up in
  `claude auto-mode config` and was ignored by the classifier across two
  mode switches. So a `SessionStart` hook that wrote rules would be too late,
  quite apart from being the self-granting route the exclusion exists to
  close.

What this engine does about it: the consumer keeps its rules in
`automode.json` at the repo root (start from `automode.json.example`);
`agent-tools/automode/install.sh` merges them into `~/.claude/settings.json`
and is meant to run from the cloud environment's setup script, before the
session starts (on a local machine, run it once by hand).
`agent-tools/hooks/automode-check.sh` reports at every session start whether
every rule in `automode.json` is installed, so drift is visible rather than
assumed away.

### One setup script for every session: install only what is in scope

A user's default environment serves every repository they launch, so the
setup script cannot assume a workspace is there, nor where. What a session
gets is a directory of checkouts (Claude does not start inside any one of
them when several are attached), and the setup script runs in it after the
clones. Measured 2026-11-08: the default environment's script ran about 30 s
after the checkout was written, and `~/.claude/settings.json` was written by
it, so the clone is there to be found. Three rules follow, and `install.sh`
keeps all three:

- **Find the workspace by what it is, not where it is.** A memory workspace is
  a checkout with `workspace.yaml`; the template has only
  `workspace.yaml.example`. `install.sh --snippet` prints the loop to paste
  into the environment's setup script: it looks in `$PWD`, `$PWD/*` and
  `/home/user/*`, runs each workspace's *own* `install.sh`, and does nothing
  if there are none. It carries no rules and no version, so it is pasted once;
  the rules and the logic come from the repository at the time it runs.
  `install.sh` itself takes the workspace from its own path, never `$PWD`,
  and refuses quietly if that directory is not a workspace with an
  `automode.json` (template, other repos, a workspace without the feature).
- **Merge; never replace.** `autoMode` is one key in one file shared by
  everything the environment does. The script adds each rule to the list of the
  same name (`"$defaults"` only into a list that did not exist) and keeps the
  rest, so the environment's own rules and several workspaces' rules coexist
  and a second run changes nothing. Order matters the other way too: a block
  that sets `autoMode` wholesale (`cur.update(...)`, `cur["autoMode"] = ...`)
  must come *before* the snippet, or it discards what the snippet merged.
  `automode-check.sh` reports that case as "partly installed".
- **Exit 0 whatever happens.** A failing setup script stops the session from
  starting, and the rules are an optional extra.

`install.sh --inline` still prints a self-contained block that carries the
rules, for a setup script that runs before the clone. It cannot be
conditional, since the rules go in whether or not the workspace is attached,
so it is the fallback and not the recommendation. Known limit: a merge cannot
remove a rule a workspace has dropped; an environment that rebuilds
`~/.claude/settings.json` in its setup script each time (the default does)
never carries one over.

Other things the environment has to hold are inert without a workspace and
need no condition: an environment variable such as `GOOGLE_SERVICE_ACCOUNT_KEY`
is read only by the `gsheets` skill, and allowed network hosts only matter to
a session that tries to reach them.
Anything the classifier must hear *in-session* — "the send-gate
is the authorisation control for message content" — goes in the routine
prompt, which it does read; the `permissions.allow` entries for the bot's
tools go in `.claude/settings.json` in both spellings (`mcp__X__*` and
`mcp__claude_ai_X__*`), which is also read from the repo.

## The checkout is a restored snapshot, not a fresh clone

A cloud session's `.git` can be a snapshot days old, refreshed by a shallow
`--depth 50` fetch. Once the repo has moved more than 50 commits, git reports
the local default branch as having *no common ancestor* with the remote
(`ahead 17, behind 51`). That divergence is an illusion. `git-sync.sh` deepens
the clone before comparing; never `reset --hard` to "fix" it.

## Concurrent sessions race on the default branch

Webhook-fired sessions run in parallel. Two of them appending to
`memory/log.md` and pushing within seconds conflict, and the one that gives up
on "non-fast-forward" has recorded nothing. `sync-push.sh` commits, rebases,
merges log appends by keeping both sides, and retries.

## Plugins and submodules, as of September 2026

A Claude Code plugin can ship skills, agents, hooks and MCP config, and its
hooks run in cloud sessions — but its `CLAUDE.md` is not loaded, whether an
`enabledPlugins` entry auto-installs in a fresh container is undocumented, and
git submodule initialisation in cloud sessions is undocumented. That is why
this engine is a vendored directory with an update script rather than either.

## The send-gate's tools, and where its verdict arrives (Claude Code 2.1.28x)

Tested with headless `claude -p` against probe agents, 27 Sep 2026:

- `tools: []` gives a subagent **no tools**, although the agent listing
  labels it "(Tools: All tools)". A `tools: []` probe could not read a canary
  file in auto or default mode. Omitting `tools` is what inherits everything.
- `disallowedTools: "*"` removes nothing; only `mcp__*` patterns wildcard.
- Subagents return their final report through `SubagentHandback`, which
  `tools`/`disallowedTools` can neither remove nor name: `tools:
  SubagentHandback` resolves to nothing and the agent refuses to launch. It
  carries the report out and nothing in, so it does not breach the gate's
  isolation.
- That hand-back is a tool call and costs a turn. With `maxTurns: 1` the
  `Agent` result says "stopped at its 1-turn limit… no report" while the
  verdict arrives intact in the hand-back message, which sessions read as a
  gate outage and failed closed on every message. `maxTurns: 2` clears it; any
  other tool call would still exhaust the turns before a verdict.
