---
name: memory-compact
description: The memory filing pass — read memory/log.md and the git history since the last pass (plus the transcripts of sessions launched with this repository in scope, when the session running it can list them), and file what is durable into memory/notes/ and the digest. Run by a scheduled task, nightly or as often as hourly, or — when workspace.yaml says `memory_filing: in-session` — by whichever session finds the log past the threshold (a Haiku session selects and dispatches, Haiku subagents review one session each, and only when there is something durable a filer subagent — Sonnet by default — files and commits). Also use when the owner asks to compact, refresh or update memory. (Creating or repairing the nightly task is the setup skill's job.)
---

# The memory filing pass

Working sessions log what they learn as they go; this pass files it. It reads,
since the last pass:

- **`memory/log.md`** — what sessions logged. The main input.
- **Git history** — what sessions changed and committed.
- **Session transcripts, when it can** — every cloud session on the owner's
  account launched with **this repository in scope**. This needs
  `list_sessions` and `list_events`, which a session started by a scheduled
  task does not get; a pass run by hand from an interactive session has them.
  Without them the pass files from the log and git alone, which is the normal
  case and not a fault. Sessions without this repository in scope are never
  read, however related their title looks.

Three roles, and the split is the point: **you select and dispatch** (this
file), **reviewers** read one session each and extract findings
([reviewer.md](reviewer.md)), **one filer** decides what is durable, edits the
notes and the digest, trims the log and commits ([filing.md](filing.md)). Do
not review or file yourself when you can dispatch — the judgement belongs to
the filer's model.

**Cost scales with work, not with how often it runs.** A pass with nothing new
is one Haiku session reading a page of the session list. Reviewers start only
for sessions with activity in the window, and the filer only when they or the
log produced something.

`memory.py` (beside this file) does the mechanical parts. Run it from the
repository root as `python3 agent-tools/skills/memory-compact/memory.py <cmd>`.

## Running the pass

1. **Start clean.** Switch to the default branch in `workspace.yaml` and
   `git pull --ff-only`. Make a run directory and keep its path:
   `RUN=$(mktemp -d)`; `mkdir $RUN/candidates`.

2. **Fix the window.** `memory.py state > $RUN/state.txt`. It prints `since`
   (read sessions and log entries after this), `last_commit` (read commits
   after this), `head`, `started`, `repo` (`owner/repo` of this workspace),
   `retry` (sessions a failed review left for this pass) and `filer_model`
   (from `workspace.yaml`, Sonnet by default). Then
   `memory.py log-snapshot > $RUN/log-snapshot.md` — exactly the log entries
   this pass will file; lines appended after this moment wait for the next one.

3. **Select the sessions.** You need `mcp__claude-code-remote__list_sessions`
   and `list_events`; load them with ToolSearch
   (`select:mcp__claude-code-remote__list_sessions,mcp__claude-code-remote__list_events`)
   if they are deferred. If they do not exist in this session, skip to step 5
   and say in your report that transcripts were not read. In a scheduled run
   that is expected.

   Call `list_sessions` with `mine: true`, `limit: 20`. **A session is in only
   if one of its `session_context.sources[].git_repository.url` values ends in
   `/<repo>`** (case-insensitive, `.git` ignored) **and its `updated_at` is
   after `since`.** Add every id on the `retry:` line whatever its date. Never
   add your own session.
   - When the tool saves the result to a file instead of showing it, run
     `memory.py sessions <file> [<file>…] --since <since>`: it applies the same
     rule, leaves out the session running it, and says whether to page on.
   - Page with `after_id` = the page's `last_id` while `has_more` is true and
     the page's oldest `created_at` is within 14 days before `since` (a session
     can be resumed long after it was created; older than that is not worth
     the pages).

   Write the result to `$RUN/sessions.tsv`, one line per session: id, title.

   **Nothing new — stop here.** No sessions selected, nothing on `retry:`, and
   `log-snapshot.md` empty: report "nothing new since <since>" in one line and
   end. Commit nothing. The pass can run as often as hourly, and most runs end
   here, so this is the cheap path: no subagents, no commit.

4. **Review each session — Haiku subagents.** For each selected session, call
   the Agent tool with `subagent_type: "general-purpose"`, `model: "haiku"`,
   and this prompt, filled in:

   > Memory review of one session for the workspace at `<repo root>`.
   > Read `<repo root>/agent-tools/skills/memory-compact/reviewer.md`
   > completely and follow it. Session: `<id>` — "`<title>`". Window: events
   > after `<since>`. Write your findings to `<RUN>/candidates/<id>.md` and
   > reply with one line: `<id>: <n> findings`.

   Up to five at once, in one message. A review that fails or writes no file
   gets one more try; after that, add its id to `$RUN/failed.txt` and move on.
   **Every selected session you did not get reviewed, for any reason, goes in
   `failed.txt`**: the window moves on after this pass, so a session left out
   of both is never read. Failed ids are carried to the next pass.

5. **Only file when there is something to file.** Run `memory.py work $RUN`.

   - **`file: no`** — the reviewers found nothing durable and the log is
     empty. Don't start the filer. Advance the state, so the same windows aren't
     reviewed again next run:
     `memory.py state-set <started> <head> <sessions reviewed> <ids from failed.txt>`,
     then `agent-tools/sync-push.sh "memory: filing pass (nothing to file, <n> sessions)"`.
     `state-set` exiting 3 means a later pass already covered this; commit
     nothing. Then report and end.
   - **`file: yes`** — start one filer subagent. Call the Agent tool with
     `subagent_type: "general-purpose"`, `model:` the `filer_model` from
     `state.txt`, and:

   > Memory filing pass for the workspace at `<repo root>`. Read
   > `<repo root>/agent-tools/skills/memory-compact/filing.md` completely and
   > follow it. Run directory: `<RUN>` (state.txt, log-snapshot.md,
   > sessions.tsv, candidates/, failed.txt if present). End with the report
   > the procedure asks for.

   If it fails, call it once more with the same prompt. If that fails too,
   report the failure and stop. Nothing advances the state then, so the next
   pass simply covers this window as well.

6. **Report.** The filer's report verbatim (if it ran), then one line of your
   own: sessions selected, reviews failed, whether the filer ran, whether
   transcripts were read at all.

**Without the Agent tool** (Codex, or a session that lacks it), do the steps
yourself in the same order: reviewer.md once per session, then filing.md.
**Run by hand** — the owner asked to compact or refresh memory — it is the same
pass. Make sure anything durable from your own session is already in a note or
the log first, since your own transcript is not reviewed.

**Run in-session** (`memory_filing: in-session`, and `memory-check.sh` reported
the threshold reached): also the same pass, run by the working session itself.
Differences:

- Do it after the work you were started for, and say in a line that you are
  filing. Don't ask the owner.
- Commit and push your own work first. Step 1's switch-and-pull needs a clean
  tree, and the filer stops if anything outside `memory/` is uncommitted.
- Keep the dispatch: reviewers and the filer run as subagents so the pass costs
  your context almost nothing. You have `list_sessions`, so step 3 reads
  transcripts too, except your own.
- If `state-set` exits 3, another session filed this window first: discard
  your changes and stop. That is success, not failure.

## Setting up the nightly task

The scheduled task that runs this pass is created, audited and repaired by the
**`setup` skill** (`agent-tools/skills/setup/SKILL.md`), together with the
workspace's other automations. Use that; don't create a task from here. With
`memory_filing: in-session` there is no task to set up.

## When something is off

- `memory-check.sh` reports the last pass at SessionStart. With a scheduled
  task, older than about 36 hours means the task has stopped or is failing: say
  so to the owner once, then run the `setup` skill, which audits and repairs
  it. With `memory_filing: in-session` there is no such alarm; the hook says
  when the threshold is reached instead.
- Co-users on their own Claude accounts, local CLI sessions and Codex are
  invisible to the listing. The contract tells those sessions to keep logging.
