# tlog: one log line per pipeline milestone, the same style in shell, R and Python.
#   Terminal: a blank line, then the timestamp in green and the message in cyan.
#   Format:   DD/MM/YYYY - HH:MM:SS AM/PM  message
# If the project's project.yaml sets paths.logs, each line is also appended,
# without colors, to <paths.logs>/tlog.log. See README.md.
#
# Use it from a script:  source("tools/tlog/tlog.R"); tlog("Cleaning started")

# Define the functions once, even if this file is sourced twice.
if (!exists("tlog")) {

  # Return paths.logs from <repo root>/project.yaml, or NULL if it is not set.
  # Reads only a top-level "paths:" block with lines such as "  logs: ~/logs/x",
  # so the helper needs no YAML package.
  tlog_logdir <- function() {
    root <- tryCatch(
      suppressWarnings(system2("git", c("rev-parse", "--show-toplevel"),
                               stdout = TRUE, stderr = FALSE)),
      error = function(e) character(0)
    )
    if (length(root) != 1 || !is.null(attr(root, "status"))) return(NULL)
    yaml <- file.path(root, "project.yaml")
    if (!file.exists(yaml)) return(NULL)
    in_paths <- FALSE
    for (line in readLines(yaml, warn = FALSE)) {
      if (grepl("^[^[:space:]#]", line)) {
        in_paths <- grepl("^paths:[[:space:]]*$", line)
        next
      }
      if (in_paths && grepl("^[[:space:]]+logs:", line)) {
        val <- sub("^[[:space:]]+logs:[[:space:]]*", "", line)
        val <- sub("[[:space:]]+#.*$", "", val)
        val <- gsub("^[\"']|[\"']$", "", val)
        if (nzchar(val)) return(path.expand(val))
      }
    }
    NULL
  }

  tlog <- function(msg) {
    ts <- format(Sys.time(), "%d/%m/%Y - %I:%M:%S %p")
    cat("\n\033[32m", ts, "\033[0m  \033[36m", msg, "\033[0m\n", sep = "")
    logdir <- tlog_logdir()
    if (!is.null(logdir)) {
      dir.create(logdir, recursive = TRUE, showWarnings = FALSE)
      cat("\n", ts, "  ", msg, "\n", sep = "",
          file = file.path(logdir, "tlog.log"), append = TRUE)
    }
    invisible(NULL)
  }
}
