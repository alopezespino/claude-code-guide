#!/usr/bin/env bash
# Example from claude-code-guide: look up, reopen and stop named Claude Code
# sessions, for the manager workflow in prompts/manager-protocol.md.
#
#   peer-session.sh id     <name>           newest session id and cwd for that name
#   peer-session.sh open   <name> [message] reopen a stopped session in the background,
#                                           with [message] as its next prompt
#   peer-session.sh close  <name>           stop it (conversation kept, can reopen)
#   peer-session.sh ls                      running sessions: name, kind, state, cwd
#   peer-session.sh health                  one line per running session: minutes since
#                                           its last transcript entry, and STALLED if its
#                                           last turn ended on an API error (it will not
#                                           resume by itself and needs a message)
#
# Names are the ones given with `claude --bg -n <name>` or `/rename <name>`.
# `open` only reopens a name that has run before; start a new one with
#   claude --bg -n <name> "<prompt>"
# `open` refuses when a session with that name is still running: message it
# with SendMessage instead, because a second copy would act on the same files.
# Extra claude flags for `open` go in PEER_FLAGS, e.g. PEER_FLAGS="--model opus".
# Needs: claude, python3. Reads transcripts under ~/.claude/projects.
set -euo pipefail
PROJ="$HOME/.claude/projects"

lookup() { # prints "<session id> <cwd>" of the newest transcript with that name
    local name="$1" f cwd
    f=$({ grep -l -r --include='*.jsonl' \
            "\"customTitle\":\"$name\"" "$PROJ" || true; } |
        xargs ls -t 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "no session named $name" >&2; exit 1; }
    cwd=$({ grep -o -m1 '"cwd":"[^"]*"' "$f" || true; } | cut -d'"' -f4)
    echo "$(basename "$f" .jsonl) ${cwd:-UNKNOWN}"
}

running_id() { # short id of a running session with that name, if any
    claude agents --json | python3 -c '
import json, sys
for a in json.load(sys.stdin):
    if a.get("name") == sys.argv[1] and a.get("state") != "failed":
        print(a.get("id") or a["sessionId"][:8]); break' "$1"
}

case "${1:-}" in
id) lookup "$2" ;;
open)
    if [ -n "$(running_id "$2")" ]; then
        echo "$2 is still running: send it a message instead" >&2; exit 1
    fi
    read -r sid cwd < <(lookup "$2")
    [ -d "$cwd" ] || { echo "cwd missing: $cwd" >&2; exit 1; }
    cd "$cwd"
    # shellcheck disable=SC2086
    claude --bg --resume "$sid" -n "$2" ${PEER_FLAGS:-} ${3:+"$3"}
    ;;
close)
    rid=$(running_id "$2")
    [ -n "$rid" ] || { echo "$2 is not running" >&2; exit 1; }
    claude stop "$rid"
    ;;
ls)
    claude agents --json | python3 -c '
import json, sys
for a in json.load(sys.stdin):
    print(a.get("name", "?"), a.get("kind", "?"),
          a.get("state") or a.get("status", "?"), a.get("cwd", "?"), sep="\t")'
    ;;
health)
    claude agents --json | python3 -c '
import json, glob, os, sys, datetime as dt
now = dt.datetime.now(dt.timezone.utc)
for a in json.load(sys.stdin):
    sid = a.get("sessionId")
    if not sid or a.get("state") == "failed":
        continue
    fs = glob.glob(os.path.expanduser("~/.claude/projects/*/%s.jsonl" % sid))
    last_ts, last_text = None, ""
    for line in (open(fs[0]) if fs else []):
        try:
            d = json.loads(line)
        except Exception:
            continue
        last_ts = d.get("timestamp") or last_ts
        c = (d.get("message") or {}).get("content")
        if d.get("type") == "assistant" and isinstance(c, list):
            for x in c:
                if x.get("type") == "text":
                    last_text = x["text"]
    age = "?"
    if last_ts:
        t = dt.datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
        age = str(int((now - t).total_seconds() // 60))
    flag = "STALLED(api-error)" if last_text.startswith("API Error") else "ok"
    print("%-16s label=%-8s idle_min=%-5s %s" % (
        a.get("name", "?"), a.get("state") or a.get("status", "?"), age, flag))'
    ;;
*) sed -n '2,22p' "$0"; exit 2 ;;
esac
