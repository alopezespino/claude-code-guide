#!/usr/bin/env bash
# BLOCKED decision of slurm-watch on synthetic probe lines (no ssh, no Slurm).
# Example test from claude-code-guide (https://github.com/alopezespino/claude-code-guide).
# Usage: tests/blocked.sh   (exit 0 when every case passes)
# Probe lines: Q|id|rawid|state|nodes|name|limit s|cpus|reason|partition
#              R|reservation|start|end|scope (ALL, covered partitions, or empty)
here=$(cd "$(dirname "$0")" && pwd); sw="$here/../slurm-watch"; fail=0
now=1792000000            # any fixed epoch
h=3600; d=86400
case_() {  # name, expected regex ("" = no verdict), probe lines
    local name=$1 want=$2 got; shift 2
    got=$(printf '%s\n' "$@" | SLURM_WATCH_BLOCKED_TEST=$now bash "$sw")
    if { [ -z "$want" ] && [ -z "$got" ]; } || { [ -n "$want" ] && printf '%s' "$got" | grep -qE "$want"; }; then
        echo "PASS $name"
    else
        echo "FAIL $name: got '$got'"; fail=1
    fi
}
# A long-lived MAINT reservation on a few nodes must not block a job pending
# on Priority.
case_ "partial MAINT reservation does not block" "" \
    "Q|101|101|PENDING||t|$((4*h))|1|Priority|cpu" \
    "R|few_nodes_maint|$((now - 16*d))|$((now + 349*d))|"
# An ALL_NODES downtime: a job whose walltime crosses its start is held.
case_ "ALL_NODES reservation crossed blocks" "102: walltime 8.0h crosses maintenance reservation DOWNTIME" \
    "Q|102|102|PENDING||t|$((8*h))|1|Priority|cpu" \
    "R|few_nodes_maint|$((now - 16*d))|$((now + 349*d))|" \
    "R|DOWNTIME|$((now + 2*h))|$((now + 7*d))|ALL"
case_ "ALL_NODES reservation not crossed" "" \
    "Q|103|103|PENDING||t|$((1*h))|1|Priority|cpu" \
    "R|DOWNTIME|$((now + 2*h))|$((now + 7*d))|ALL"
# A reservation holding every node of the job's partition (no ALL_NODES flag).
case_ "reservation covering the job's partition blocks" "104: walltime" \
    "Q|104|104|PENDING||t|$((4*h))|1|Resources|cpu" \
    "R|cpu_maint|$((now + 1*h))|$((now + 1*d))|cpu"
case_ "reservation covering another partition does not" "" \
    "Q|105|105|PENDING||t|$((4*h))|1|Resources|highmem" \
    "R|cpu_maint|$((now + 1*h))|$((now + 1*d))|cpu"
case_ "multi-partition job needs every partition covered" "" \
    "Q|106|106|PENDING||t|$((4*h))|1|Resources|cpu,highmem" \
    "R|cpu_maint|$((now + 1*h))|$((now + 1*d))|cpu"
# A partial reservation named in the job's pending reason.
case_ "partial reservation named in the reason blocks" "107: walltime" \
    "Q|107|107|PENDING||t|$((4*h))|1|Reservation_fix_a01_is_on|cpu" \
    "R|fix_a01|$((now + 1*h))|$((now + 1*d))|"
# Reasons that never clear.
case_ "ReqNodeNotAvail reason blocks" "108 pending with reason \(ReqNodeNotAvail" \
    "Q|108|108|PENDING||t|$((4*h))|1|ReqNodeNotAvail, Reserved for maintenance|cpu"
# A running job is never BLOCKED.
case_ "running job ignored" "" \
    "Q|109|109|RUNNING|a001|t|$((8*h))|1|None|cpu" \
    "R|DOWNTIME|$((now + 2*h))|$((now + 7*d))|ALL"
exit $fail
