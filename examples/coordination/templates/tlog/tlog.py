"""tlog: one log line per pipeline milestone, the same style in shell, R and Python.

Terminal: a blank line, then the timestamp in green and the message in cyan.
Format:   DD/MM/YYYY - HH:MM:SS AM/PM  message
If the project's project.yaml sets paths.logs, each line is also appended,
without colors, to <paths.logs>/tlog.log. See README.md.

Use it from a script:  from tlog import tlog; tlog("Cleaning started")
Run it directly:       python tlog.py "message"
"""
import datetime
import os
import re
import subprocess
import sys

GREEN, CYAN, RESET = "\033[32m", "\033[36m", "\033[0m"


def tlog_logdir():
    """Return paths.logs from <repo root>/project.yaml, or None if it is not set.

    Reads only a top-level "paths:" block with lines such as "  logs: ~/logs/x",
    so the helper needs no YAML package.
    """
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    yaml = os.path.join(root, "project.yaml")
    if not os.path.isfile(yaml):
        return None
    in_paths = False
    with open(yaml, encoding="utf-8") as f:
        for line in f:
            if re.match(r"[^\s#]", line):
                in_paths = re.match(r"paths:\s*$", line) is not None
                continue
            m = re.match(r"\s+logs:\s*(.*?)\s*(#.*)?$", line)
            if in_paths and m and m.group(1):
                return os.path.expanduser(m.group(1).strip("\"'"))
    return None


def tlog(msg):
    ts = datetime.datetime.now().strftime("%d/%m/%Y - %I:%M:%S %p")
    print(f"\n{GREEN}{ts}{RESET}  {CYAN}{msg}{RESET}", flush=True)
    logdir = tlog_logdir()
    if logdir:
        os.makedirs(logdir, exist_ok=True)
        with open(os.path.join(logdir, "tlog.log"), "a", encoding="utf-8") as f:
            f.write(f"\n{ts}  {msg}\n")


if __name__ == "__main__":
    tlog(" ".join(sys.argv[1:]) or "tlog test line")
