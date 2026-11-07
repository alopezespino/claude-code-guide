# The one entry point projects use to read the shared baseline.
#
#   source(file.path(base_dir, "R", "baseline.R"))
#   b <- read_baseline(base_dir)
#
# base_dir is where the shared repository sits in the project (the submodule
# folder). The function checks the table against its fingerprint, so a stale
# or partial file stops loudly instead of feeding a project wrong rows.

read_baseline <- function(base_dir,
                          out_dir = Sys.getenv("BASE_DATA_OUT",
                                               file.path(base_dir, "output"))) {
  csv  <- file.path(out_dir, "baseline.csv")
  meta <- file.path(out_dir, "baseline_meta.txt")
  if (!file.exists(csv) || !file.exists(meta))
    stop("baseline not built: run build/build_baseline.R in ", base_dir)
  b <- read.csv(csv, stringsAsFactors = FALSE)
  m <- readLines(meta)
  rows <- as.integer(sub("^rows: ", "", grep("^rows: ", m, value = TRUE)))
  if (!identical(rows, nrow(b)))
    stop("baseline.csv has ", nrow(b), " rows, its fingerprint says ", rows)
  attr(b, "commit") <- sub("^commit: ", "", grep("^commit: ", m, value = TRUE))
  b
}
