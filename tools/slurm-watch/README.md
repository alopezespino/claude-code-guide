# slurm-watch

A watcher for Slurm jobs on a remote cluster. It runs on your laptop, polls
the cluster with one short ssh call per minute, prints nothing while the job
is healthy, and exits with ONE verdict line (and a distinct exit code) on the
first event that needs attention: the job ended, ran out of memory, sits idle,
stopped writing checkpoints, cannot start, or the cluster stopped answering.

## Why it saves tokens

When Claude waits for a cluster job by checking it every few minutes, every
check is a full model turn, and every turn re-sends the whole conversation.
A two-hour job checked every five minutes costs 24 turns that say "still
running".

slurm-watch moves the waiting out of the model. Claude starts it as a
background Bash command (`run_in_background: true`); the shell does the
polling and the filtering, and Claude is woken exactly once, when the watcher
exits. Its silence is the status. It also catches the failures that a
"has it finished?" check never sees: a job that hangs at 0% CPU, a job that
never starts, a run that is alive but has stopped making progress.

## Requirements

- Key-based ssh to the cluster login node under a Host alias in
  `~/.ssh/config` (no password or passphrase prompt; it runs with
  `BatchMode=yes`).
- On the cluster: Slurm (`squeue`, `sacct`, `scontrol`, `sstat`), bash, GNU
  coreutils. On the laptop: bash, perl (for the per-call time limit).
- Optional: ssh from the login node to the compute node your job runs on.
  Many sites allow this while you have a job there. It is used for memory,
  OOM and per-process CPU readings from the job's cgroup; without it, OOM and
  MEMORY never fire and IDLE relies on `sstat` alone.

## Install

```bash
mkdir -p ~/.claude/bin
cp tools/slurm-watch/slurm-watch ~/.claude/bin/
chmod +x ~/.claude/bin/slurm-watch
# optional: the default cluster, so --host can be omitted
echo 'export SLURM_WATCH_HOST=mycluster' >> ~/.bashrc
```

Check it locally, without a cluster:

```bash
tools/slurm-watch/tests/blocked.sh   # BLOCKED decision, 9 cases
tools/slurm-watch/tests/watch.sh     # every event, fake ssh and Slurm, ~1 min
tools/slurm-watch/tests/hook.sh      # the optional hook below
```

## Usage

```bash
slurm-watch --host mycluster --jobid 123456
slurm-watch --jobid 123456 --require 'RESULT-OK'   # exit 0 alone is not success
slurm-watch --dir '~/scratch/runs/exp1'            # job id from <dir>/jobid
slurm-watch --name mychain --allow-end TIMEOUT     # a chain of jobs with one name
slurm-watch --jobid 123456 --checkpoint '~/scratch/runs/exp1/ckpt_*.rds' \
  --first 30m --every 45m                          # alarm if checkpoints stop
```

After an alarm that does not end the job (IDLE, MEMORY, STALL, BLOCKED,
STARTED), decide what to do, then re-arm with the same arguments if the job
should continue (add `--no-idle`, `--mem-pct 98` or `--no-blocked` as
needed). A watcher killed from outside (a session restart, memory pressure on
the laptop) prints `STOPPED` or nothing: in both cases nothing is watching
any more, so re-arm.

One watcher per job: a second one on the same target exits at once with
`DUPLICATE`.

## Events and exit codes

| Exit | Line | Meaning |
|------|------|---------|
| 0 | `ENDED ... COMPLETED 0:0` | success: every job of the set completed, and `--require` matched if given |
| 1 | `ENDED ...` | any other end: FAILED, TIMEOUT, OUT_OF_MEMORY, CANCELLED, or `--require` missing |
| 2 | (usage message) | bad arguments, or no host given |
| 3 | `STARTED` | PENDING to RUNNING, only with `--notify-start` |
| 4 | `NOT FOUND` | no job for the target after `--not-found` (default 5m) |
| 5 | `DUPLICATE` | another live watcher holds this target |
| 10 | `OOM` | the job cgroup's `oom_kill` counter rose while the job still runs |
| 11 | `MEMORY` | cgroup RSS reached `--mem-pct` (default 90) of the job's memory limit |
| 12 | `IDLE` | RUNNING at fewer than `--idle-cores` (0.1) cores for `--idle` (20m) |
| 13 | `STALL` | the `--checkpoint` glob or `--progress` regex did not advance within `--first` / `--every` |
| 14 | `BLOCKED` | PENDING and cannot start: walltime crosses a maintenance reservation, or a reason that never clears (DependencyNeverSatisfied, ReqNodeNotAvail, a QOS or partition limit) |
| 20 | `UNREACHABLE` | the first 3 queries failed, or no successful query for `--unreachable` (30m) |
| 30 | `STOPPED` | the watcher got a signal before any verdict |

An `ENDED` line carries the Slurm accounting state, exit code, elapsed time,
peak RSS against the request, and up to 3 log lines matching `--result`
(default: SUMMARY, Error, Traceback, Execution halted, FAIL, DUE TO TIME
LIMIT, CANCELLED, oom, Killed, DONE), each cut at 200 characters. For example:

```
slurm-watch: ENDED job 123456 (exp1) COMPLETED 0:0 after 00:01:32, peak RSS 3.8M of 1G; --require found; log <run dir>/run.log
slurm-watch: MEMORY job 123457: RSS 1.8G of 2.0G limit (>= 90%) (watch stopped; ...)
slurm-watch: BLOCKED job 123458 pending with reason (ReqNodeNotAvail, Reserved for maintenance); cancel and resubmit, ...
```

## Options

| Option | Use |
|--------|-----|
| `--host <alias>` | ssh Host alias of the login node; default `$SLURM_WATCH_HOST` |
| `--jobid <id>[,<id>]` | job ids, array ids included |
| `--dir <remote dir>` | run dir: reads `<dir>/jobid`, else matches WorkDir in squeue, then in sacct (a job that already finished still gets its verdict); uses `<dir>/run.log` as the log if present |
| `--name <job name>` | every job with that name since 2 days before arming; for requeue or `--dependency` chains whose ids change per link (the queue must be empty on 2 consecutive polls) |
| `--log <remote file>` | log to read; default the job's StdOut |
| `--allow-end S1,S2` | states that do not count as failure for non-final jobs of a set |
| `--require '<regex>'` | a log line that must exist for COMPLETED to count as success |
| `--result '<regex>'` | which log lines to quote in the ENDED line |
| `--checkpoint '<glob>'` or `--progress '<regex>'`, with `--first <dur>` and/or `--every <dur>` | first-checkpoint-missing and checkpoint-gap alarms |
| `--idle <dur>`, `--no-idle`, `--idle-cores <x>` | CPU liveness alarm |
| `--mem-pct <n>` | memory pressure threshold; 0 disables |
| `--no-blocked` | do not alarm on a pending job that cannot start |
| `--notify-start` | exit when the job starts running |
| `--poll <dur>` | default 60s |
| `--unreachable <dur>` | default 30m |
| `--not-found <dur>` | default 5m |

Durations: `90`, `90s`, `20m`, `2h`. Environment: `SLURM_WATCH_HOST`
(default host), `SLURM_WATCH_STATE` (pid files, default
`~/.claude/state/slurm-watch`).

## How to tell Claude to use it

Add this to `~/.claude/CLAUDE.md` (or a project's `CLAUDE.md`):

```markdown
## Waiting for a Slurm job: slurm-watch, never polling

1. Submit the job and return. Never wait in an open ssh session.
2. Start `~/.claude/bin/slurm-watch --host <cluster> --jobid <id>` with Bash
   `run_in_background: true`. Add `--require '<regex>'` when exit 0 alone does
   not prove success, and `--checkpoint '<glob>' --first <dur>` for long runs
   that write checkpoints.
3. It prints nothing while the job is healthy. When it exits, read its one
   line and act on it. Exit codes: 0 success, 1 failed, 10 OOM, 11 memory,
   12 idle, 13 stall, 14 blocked, 20 unreachable, 30 stopped.
4. After a non-final alarm, re-arm with the same arguments if the job should
   continue. If the background task was killed, re-arm: nothing is watching.
5. One watcher per job. Never check a watched job by hand (`squeue`, `sacct`,
   `tail` of its log): the watcher's silence is the status. In the meantime,
   do unrelated work or stop.
```

## Optional hook: deny hand polls of a watched job

`hooks/no-redundant-poll.sh` is a PreToolUse hook that denies a Bash command
such as `ssh mycluster 'squeue -j 123456'` while a live slurm-watch watches
job 123456, and tells Claude why. Copy it to `~/.claude/hooks/` and register
it under `PreToolUse` with matcher `Bash` in `~/.claude/settings.json`, next
to any hooks you already have:

```json
{ "type": "command", "command": "$HOME/.claude/hooks/no-redundant-poll.sh" }
```

It needs `jq` and fails open (allows the command) on any problem.

## Design notes

Each one comes from a watcher that stayed silent when it should have spoken.

| Failure seen | Cause | What slurm-watch does |
|---|---|---|
| Watcher silent on jobs longer than 30 min | it ran under a tool with a time cap | runs as a background Bash command, which has none |
| Watcher silent on jobs of a few minutes | it looked only in `squeue`; a job already gone was never found | falls back to `sacct`, so a finished job still gets a verdict |
| Watcher hung forever | ssh with no keepalive waited on a dead connection | `ssh -n`, ServerAliveInterval 15, and every call killed after 90 s |
| Job pending all night, no event | its walltime crossed a maintenance window; an end-only watcher never fires for a job that never starts | BLOCKED event |
| False "done" on a summary line printed mid-run | completion keyed on a log pattern | the end is decided by Slurm; the log is read once afterwards |
| A hung job looked like "still running" | liveness keyed on log lines | IDLE from CPU use; STALL from checkpoints |
| False IDLE on a multi-node job | CPU read on the first node only, while the work ran as srun steps elsewhere | IDLE takes the larger of the first-node cgroup rate and the `sstat` rate summed over all steps and nodes |
| False UNREACHABLE after the laptop slept | timers used wall-clock time | a gap of more than 5 polls plus 3 min counts as sleep and restarts the timers |
| False BLOCKED from a long-lived reservation on a few nodes | every MAINT reservation counted | a reservation counts only if it holds the job: ALL_NODES, every node of the job's partition, or named in the pending reason |

## How it measures

- One ssh call per poll to the login node. It runs a probe script (sent
  base64-encoded) that returns only `key|value` lines, so almost nothing
  crosses the network and nothing reaches Claude until the verdict.
- Memory, OOM kills and per-process CPU come from the job's cgroup on its
  first node, through a nested ssh capped at 25 s: cgroup v1
  `memory/slurm/uid_<uid>/job_<id>/`, with cgroup v2
  `system.slice/slurmstepd.scope/job_<id>/` as a fallback. These are the
  standard Slurm layouts; a site with a different layout gets no OOM or
  MEMORY events.
- CPU over the whole job: `sstat -a` CPU seconds summed over every running
  step on every node. It misses processes that leave step accounting, so IDLE
  uses the larger of this rate and the cgroup rate; either one busy resets it.
- Maintenance reservations come from `scontrol show reservation` (flag MAINT).
- At most 4 running jobs are probed per poll; IDLE, MEMORY and OOM track the
  first running job of a set.
