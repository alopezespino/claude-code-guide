#!/usr/bin/env bash
# End-to-end tests of slurm-watch against fake ssh and fake Slurm commands
# (tests/fakes/). Nothing contacts a cluster. Runs in about a minute.
# Example test from claude-code-guide (https://github.com/alopezespino/claude-code-guide).
# Usage: tests/watch.sh   (exit 0 when every case passes)
here=$(cd "$(dirname "$0")" && pwd); sw="$here/../slurm-watch"; fail=0
uid=$(id -u)

new_fake() {  # fresh fixture dir (left in the temp dir, never deleted)
  F=$(mktemp -d "${TMPDIR:-/tmp}/slurm-watch-test.XXXXXX")
  mkdir -p "$F/state"
}
run() {  # run <args...>: sets out and rc; each run is killed after 60 s
  out=$(PATH="$here/fakes:$PATH" FAKE=$F SLURM_WATCH_STATE=$F/state \
    SLURM_WATCH_CGROUP_ROOT=$F/cg SLURM_WATCH_HOST=fakehost \
    perl -e 'alarm shift; exec @ARGV' 60 bash "$sw" --poll 1 "$@" 2>&1)
  rc=$?
}
check() {  # check <name> <expected rc> <regex>
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -qE -- "$3"; then echo "PASS $1"
  else echo "FAIL $1: rc $rc, output: $out"; fail=1; fi
}
cgroup() {  # cgroup <job> <rss> <limit> <oom kills>: cgroup v1 fixture
  local m="$F/cg/memory/slurm/uid_$uid/job_$1"; mkdir -p "$m"
  echo "total_rss $2" > "$m/memory.stat"; echo "$3" > "$m/memory.limit_in_bytes"
  echo "oom_kill $4" > "$m/memory.oom_control"
}
G=1073741824
running='101|101|RUNNING|node01|demo|1:00:00|4|cpu|None'

# --- usage
new_fake; out=$(env -u SLURM_WATCH_HOST bash "$sw" --jobid 1 2>&1); rc=$?
check "no host is a usage error" 2 "no cluster: pass --host"

# --- ENDED success: job already gone, accounting says COMPLETED 0:0
new_fake
echo "101|demo|COMPLETED|0:0|00:01:32|3.8M|1G|$F/job_%j.log" > "$F/sacct.out"
printf 'step 1\nRESULT-OK\n' > "$F/job_101.log"
run --jobid 101 --require RESULT-OK
check "ended success" 0 "ENDED job 101 \(demo\) COMPLETED 0:0 after 00:01:32.*--require found"

# --- ENDED success claimed by Slurm, but --require is missing
new_fake
echo "101|demo|COMPLETED|0:0|00:01:32|3.8M|1G|$F/job_%j.log" > "$F/sacct.out"
echo "nothing useful" > "$F/job_101.log"
run --jobid 101 --require RESULT-OK
check "require missing is failure" 1 "NOT in log"

# --- ENDED failure after running for two polls
new_fake
echo "$running" > "$F/squeue.out"; echo 2 > "$F/squeue.n"; : > "$F/squeue.after"
echo "101|demo|FAILED|1:0|00:00:40|1.2G|4G|$F/job_%j.log" > "$F/sacct.out"
printf 'Traceback (most recent call last)\nValueError: bad input\n' > "$F/job_101.log"
run --jobid 101
check "ended failure" 1 "log: Traceback"

# --- STARTED
new_fake
echo '101|101|PENDING||demo|1:00:00|4|cpu|Priority' > "$F/squeue.out"
echo 1 > "$F/squeue.n"; echo "$running" > "$F/squeue.after"
run --jobid 101 --notify-start
check "started" 3 "STARTED job 101: 101 on node01"

# --- BLOCKED on a reason that never clears
new_fake
echo '101|101|PENDING||demo|1:00:00|4|cpu|DependencyNeverSatisfied' > "$F/squeue.out"
run --jobid 101
check "blocked" 14 "BLOCKED job 101 pending with reason \(DependencyNeverSatisfied\)"

# --- MEMORY: cgroup RSS at 95% of the limit
new_fake; echo "$running" > "$F/squeue.out"; cgroup 101 $((95 * G / 100)) $G 0
run --jobid 101 --no-idle
check "memory" 11 "MEMORY job 101: RSS 972.8M of 1.0G limit"

# --- OOM: the oom_kill counter rises after arming
new_fake; echo "$running" > "$F/squeue.out"; cgroup 101 $((G / 2)) $G 0
( sleep 3; cgroup 101 $((G / 2)) $G 1 ) &
run --jobid 101 --no-idle
check "oom" 10 "OOM job 101: 1 process\(es\) OOM-killed"

# --- IDLE: sstat CPU seconds do not advance
new_fake; echo "$running" > "$F/squeue.out"
echo '101.batch|cpu=00:05:00,mem=1G' > "$F/sstat.out"
run --jobid 101 --idle 3 --mem-pct 0
check "idle" 12 "IDLE job 101 RUNNING but at 0.00 cores"

# --- STALL: no checkpoint file appears within --first
new_fake; echo "$running" > "$F/squeue.out"
run --jobid 101 --no-idle --checkpoint "$F/ckpt_*.rds" --first 3
check "stall first checkpoint" 13 "STALL job 101: no first checkpoint"

# --- STALL not raised while checkpoints keep arriving; then the job ends
new_fake; echo "$running" > "$F/squeue.out"; echo 6 > "$F/squeue.n"; : > "$F/squeue.after"
echo "101|demo|COMPLETED|0:0|00:00:09|1M|1G|$F/job_%j.log" > "$F/sacct.out"
( for i in 1 2 3 4; do sleep 1; touch "$F/ckpt_$i.rds"; done ) &
run --jobid 101 --no-idle --checkpoint "$F/ckpt_*.rds" --first 3
check "checkpoints advance, no stall" 0 "ENDED job 101"

# --- UNREACHABLE: ssh fails on the first queries
new_fake
out=$(FAKE_SSH_DOWN=1 PATH="$here/fakes:$PATH" FAKE=$F SLURM_WATCH_STATE=$F/state \
  perl -e 'alarm shift; exec @ARGV' 60 bash "$sw" --host fakehost --poll 1 --jobid 101 2>&1); rc=$?
check "unreachable" 20 "UNREACHABLE job 101: the first 3 queries to fakehost"

# --- NOT FOUND: a run dir with no jobid file and no matching job
new_fake; mkdir -p "$F/run"
run --dir "$F/run" --not-found 2
check "not found" 4 "NOT FOUND no Slurm job for dir"

# --- --dir resolves the job from <dir>/jobid
new_fake; mkdir -p "$F/run"; echo 101 > "$F/run/jobid"
echo "101|demo|COMPLETED|0:0|00:00:05|1M|1G|$F/run/run.log" > "$F/sacct.out"
echo DONE > "$F/run/run.log"
run --dir "$F/run"
check "dir mode" 0 "ENDED job 101 .*log $F/run/run.log"

# --- DUPLICATE, then STOPPED by a signal
new_fake; echo "$running" > "$F/squeue.out"
PATH="$here/fakes:$PATH" FAKE=$F SLURM_WATCH_STATE=$F/state SLURM_WATCH_HOST=fakehost \
  bash "$sw" --poll 1 --jobid 101 --no-idle > "$F/first.out" 2>&1 &
first=$!
sleep 3
run --jobid 101 --no-idle
check "duplicate" 5 "DUPLICATE job 101 is already watched by pid $first"
kill -TERM "$first"; wait "$first"; rc=$?; out=$(cat "$F/first.out")
check "stopped" 30 "STOPPED watcher on job 101 by a signal"

exit $fail
