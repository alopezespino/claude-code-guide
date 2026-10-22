# Manager and worker protocol for parallel sessions

Use this when one piece of work is split across several Claude Code sessions that run at
the same time (for example `data-clean`, `estimate` and `tables`). One extra session,
named `manager`, is the only one you talk to. Workers report to it, it relays to you, and
it wakes waiting workers when what they wait for lands.

The file has two halves. Point every worker prompt at the first half ("Worker side")
instead of copying it, so a later fix reaches every session. The second half is what the
manager itself follows. The plan template that goes with it is
`prompts/multi-session-plan.md`.

How sessions find each other: every message is addressed by session NAME. Name each
session when you create it (`claude --bg -n data-clean "<prompt>"`, or `/rename
data-clean` inside an interactive session). An unnamed session cannot be addressed
reliably, and two sessions with the same name make messages ambiguous.

---

## Worker side

Paste or point to this block from the prompt of every session that reports to the
manager. Replace `<session>` with the session's own name.

```text
You do not talk to the user directly. The session named "manager" relays. Send it
messages with the SendMessage tool (to: "manager"). Every report below is one line
unless stated.

1. Announce yourself once, at start, then start work without waiting for a reply:
   OPEN: <session> <one line: what the task is and where its inputs live>

2. Report these events, and only these:
   - Milestone, at roughly quarter points, never per item:
     MILESTONE: <session> <n>/<N> done, <summary numbers>
   - Long job started (cluster job, overnight run), one line per job:
     JOB: <session> <job id> <job name> <one-phrase purpose>
   - Blocked on a decision only the user can make:
     NEEDS YOU: <session> RULING, followed by the four-part body in item 3
   - Handoff to a session that waits on you: send it to that session by name
     (or to the manager if the plan says so), with the full handoff in the body
     (commit hashes, output paths, row counts, checksums, job ids: anything the
     next session's first measurement depends on). A pointer to your notes file
     is not enough; the receiver may not be able to read your worktree.
   - Finished: CLOSE OK: <session> <lessons file> <lesson numbers> <branch>
     Never send this before the close-out in item 6 is committed.
   - Failed or abandoned: FAILED: <session> <one sentence: what broke, what you tried>
   A verdict you can reach yourself is not an event. Decide it, record it in your
   notes file, move on.

3. Ruling requests. One message, about 150 words, exactly four parts, in order:
   1. The thing being decided, stated in full and split into parts (a, b, c): the
      definition, sample rule, filter, pipeline step or comparison that failed, with
      the numbers that matter, their units, and how much of the output they affect.
   2. The issue in one sentence.
   3. Your recommendation.
   4. What would make your recommendation wrong.
   Write it as a research assistant explains an issue to the PI in a meeting: plain
   words about what the step does. No script, function or variable names, no file
   paths, no commit hashes, no background section, no survey of options. The user
   asks follow-up questions if the short version is not enough.
   The answer comes back as one line starting "RULING (user, <date>, relayed by
   manager)". Only that line is the user's decision; anything else the manager adds
   is the manager's view.

4. Do not:
   - Poll the manager ("any news?", "are you done?"). Silence means the message was
     delivered and the user has not answered yet.
   - Send bulk output (data dumps, log tails, full tables). Findings go in your notes
     file; a message names the file and section.
   - Put several rulings in one message.
   - Ask the manager or another session to do something your own permissions
     refused. Send a FAILED line instead.

5. Files.
   - If you run in the background, Claude Code may refuse edits to the shared
     checkout. Before your first edit, create a git worktree for your records at the
     default location (the EnterWorktree tool, which puts it under
     .claude/worktrees/; a custom path raises a permission prompt nobody sees), commit
     there, and name the branch in CLOSE OK. Merging is the user's decision.
   - Right after entering the worktree, check its base:
       git merge-base --is-ancestor <plan commit> HEAD
     A new worktree can start from origin/<default branch> instead of your local
     branch, so it may lack unpushed commits. If the check fails, rebase onto the
     local branch before doing anything else.
   - You own one notes file for this task, named for the task. Write into it as you
     go: objective and what "done" means; inputs and outputs; each decision with its
     reason; progress with measured numbers; bugs and surprises; open follow-ups. A
     fresh session must be able to resume from it alone.

6. Close-out: record lessons BEFORE sending CLOSE OK. Lessons are the only part of a
   session's work that outlives it.
   - Where: the project's existing numbered lessons log (for example
     notes/lessons.md). If there is none, a "Lessons" heading in your notes file.
   - What counts: anything a future session would otherwise rediscover. Each entry:
     symptom, cause, fix, and the rule it implies. A wrong assumption that cost time
     is a lesson even when nothing broke. "It worked" is not a lesson.
   - Numbering: parallel sessions collide. Re-read the end of the log when you write,
     take the next free numbers, and put the range in CLOSE OK. If your numbers were
     taken meanwhile, renumber yours.
   - Commit the log before CLOSE OK, with a message naming the session and numbers.
   - A lesson that holds beyond this project goes to the manager as one extra line,
     LESSON: <session> <one sentence>, at most two per session.
```

---

## Manager side

1. **Relay, do not decide.** Forward a `NEEDS YOU` to the user as received. Add your own
   recommendation only if it differs, labelled as yours. Relay the answer back as
   `RULING (user, <date>, relayed by manager)`. Never relay your own recommendation as a
   ruling. Return a request that breaks the four-part format to its sender.

2. **A pending ruling holds the floor.** After you put a ruling request to the user,
   print nothing else until it is answered: no status updates, no relays, no new
   questions. Log incoming messages to the handoff file and report them after the answer.
   Exceptions: an event that changes the ruling itself (one line), or an emergency.
   Present a series of rulings one at a time.

3. **A report is a claim.** Before asking the user to approve something, check what is
   cheap to check: the commit exists on the branch, the job's exit state, the script the
   worker wants run (what it overwrites, whether it backs up). Say which parts you checked
   and which are the worker's statements.

4. **Live data.** Before approving a write to shared data or a shared checkout, check
   whether a running job reads it. If you cannot tell, ask the owning session and hold.

5. **Wake waiting sessions.** A dependent session does its allowed prep, ends its turn and
   may stop. When the message it waits for arrives at the manager, forward it verbatim to
   that session by name. If the session is no longer running, a message to it fails, so
   reopen it with the message as its prompt (see "Commands" below). Before reopening,
   check the session list: if the name is still listed, message it instead, because
   reopening a live session starts a duplicate that acts on the same files.

6. **Reroute before closing.** Before you close a session that waits on a message, tell
   every sender of that message to send it to the manager instead, and record the reroute.
   A message sent to a closed session is lost.

7. **Silence is not progress.** A session can stop without sending anything: its API call
   is cut when the computer sleeps, or it waits on a permission prompt nobody sees. When
   you open a session whose message gates others:
   - subscribe to its idle notice (SendMessage with `notify_when_idle: true`; omit the
     message for a pure subscription);
   - record the message you expect and a due time in the handoff file;
   - arm one background timer for the due time (Bash, `run_in_background: true`,
     command `sleep <seconds>; echo DUE <session>`).
   When the notice or timer fires without the expected message, look at the session's
   last turn (`claude logs <name>`). If it ended on an API error, message it its current
   step so it resumes. If it waits on a permission prompt, tell the user the session name
   so they can open it (`claude attach <name>`). Otherwise ask it for one status line.
   The busy/idle label in the session list is not task state; never report a session as
   finished, stuck or abandoned from the label alone.

8. **Same-name sessions.** If the session list shows two rows with one name, address the
   one you mean as `name [ref]`, with the ref copied from the listing. Read every
   SendMessage result; a result that says the target is offline means the message went
   to a different session than you intended.

9. **Open late, close early.** Close a session in the same turn as its `CLOSE OK`, after
   checking that the lessons commit it names exists. Close idle sessions early rather than
   let the computer run short of memory.

10. **Prompts are one code block.** Every prompt you write for another session is one
    fenced block opened with ```text, with only a short header above it (session name,
    model, effort). No triple backticks inside. Save it under the project's
    `prompts/` or `tasks/` folder, never only in a scratch directory.

11. **The handoff file is the state.** Record every ruling, job, open, close and reroute
    in your handoff file in the same turn. Keep two tables current:

    | Session | State | Waiting for (message) | Due |
    |---|---|---|---|

    | Job | Owner session | Purpose | State |
    |---|---|---|---|

    A job with no `JOB:` line is "owner unknown": ask, do not guess from its name.

12. **Daily reset.** The manager's transcript grows with every relay and is re-sent on
    every turn. At the end of each day, bring the handoff file up to date (live sessions
    and their gates, jobs, queued rulings), put a fresh-manager prompt at its bottom, and
    start a new manager session from it the next day. Tell every open session the new
    manager's name if it changes.

---

## Commands

Verified against Claude Code 2.1.x. Check `claude --help` on your version.

| Purpose | Command or tool |
|---|---|
| Start a named background session | `claude --bg -n data-clean "<prompt>"` (run from the repository directory) |
| Name an interactive session | `/rename data-clean` inside the session |
| List running sessions | `claude agents --json` (shell), or the ListAgents tool (inside a session) |
| Send a message | SendMessage tool, `to: "data-clean"` |
| Be told when a session goes idle | SendMessage with `notify_when_idle: true` |
| Watch or take over a session | `claude attach data-clean` |
| Read its recent output | `claude logs data-clean` |
| Stop it (conversation kept) | `claude stop <id>` |
| Reopen a stopped session in the background | `claude --bg --resume <session-id> -n data-clean "<message>"` |

`scripts/peer-session.sh` wraps the last three by name.
