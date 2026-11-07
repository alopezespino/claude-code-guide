# paper-a's own sample, built on top of the shared baseline.
#
# The shared repository is a git submodule at paper-a/base-data, so this
# project always reads the baseline at the exact commit it recorded. What is
# specific to this paper (which sectors and years) lives here, not in the
# shared repository.
#
#   Rscript code/1_sample.R                  (from the paper-a folder)
#
# BASE_DATA_DIR points to the shared repository when it is not at
# <project>/base-data (in this example folder it is a sibling: ../base-data).

root <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(file.path(dirname(sub("^--file=", "", a)), ".."))
})
base_dir <- Sys.getenv("BASE_DATA_DIR", file.path(root, "base-data"))
if (!dir.exists(base_dir))
  stop("shared repository not found at ", base_dir,
       ": run `git submodule update --init`")
source(file.path(base_dir, "R", "baseline.R"))

b <- read_baseline(base_dir)

# ---- This project's filter --------------------------------------------------
s <- b[b$sector == "manufacturing" & b$year >= 2015, ]

dir.create(file.path(root, "output"), showWarnings = FALSE)
write.csv(s, file.path(root, "output", "sample.csv"), row.names = FALSE)
message(sprintf("sample: %d of %d baseline rows kept (baseline commit %s)",
                nrow(s), nrow(b), attr(b, "commit")))
