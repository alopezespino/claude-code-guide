# tlog

> Example template from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide), kept in the
> coordination repo and copied into projects by the example `/press` command.

One logging function, `tlog`, with the same output in shell, R and Python, so the log
of a pipeline reads the same whichever language wrote each line:

```text

22/10/2026 - 03:14:07 PM  Cleaning started
```

The timestamp prints in green and the message in cyan, after one blank line. The format
stays fixed so a log can be searched or parsed into a table later.

| File | Use |
|------|-----|
| `tlog.sh` | `. tools/tlog/tlog.sh; tlog "message"`, or run `./tlog.sh "message"` |
| `tlog.py` | `from tlog import tlog` (with the folder on `sys.path`), or `python tlog.py "message"` |
| `tlog.R` | `source("tools/tlog/tlog.R"); tlog("message")` |

Each file defines `tlog` only if it is not defined yet, so sourcing it twice is harmless.

## Config keys read from `project.yaml`

The template holds no project path. Each copy reads one optional key from the
`project.yaml` at the root of the git repo it runs in:

```yaml
paths:
  logs: ~/data/paper-a/logs   # optional
```

| Key | Default when absent | Effect |
|-----|---------------------|--------|
| `paths.logs` | none: the terminal only | Each line is also appended, without colors, to `<paths.logs>/tlog.log`; the folder is created if needed |

The reader handles only a top-level `paths:` block of `key: value` lines, so the helper
needs no YAML package. A leading `~` is expanded. Outside a git repo, or with no
`project.yaml`, `tlog` prints to the terminal only.
