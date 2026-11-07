# Build the shared baseline table once, for every project that uses it.
#
# In a real shared repository this script reads the raw files (from a path
# documented in the README, never committed) and applies the cleaning every
# project agrees on. Here it makes up a small raw table so the example runs
# anywhere.
#
#   Rscript build/build_baseline.R            (from the base-data folder)
#
# Writes output/baseline.csv and output/baseline_meta.txt (row count and the
# commit the table was built from). Set BASE_DATA_OUT to write elsewhere.

here <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(file.path(dirname(sub("^--file=", "", a)), ".."))
})
out_dir <- Sys.getenv("BASE_DATA_OUT", file.path(here, "output"))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Raw input (made up) ----------------------------------------------------
set.seed(1)
n <- 600
raw <- data.frame(
  unit_id = sprintf("U%03d", sample(1:200, n, replace = TRUE)),
  year    = sample(2012:2020, n, replace = TRUE),
  sector  = sample(c("Manufacturing", "manufacturing ", "Services",
                     "Retail", NA), n, replace = TRUE),
  sales   = round(rlnorm(n, 10, 1)),
  stringsAsFactors = FALSE
)

# ---- Shared cleaning: the rules every project relies on ---------------------
raw$sector <- tolower(trimws(raw$sector))          # one spelling per sector
raw <- raw[!is.na(raw$sector), ]                   # sector is required
raw <- raw[!duplicated(raw[c("unit_id", "year")]), ] # one row per unit-year
raw <- raw[order(raw$unit_id, raw$year), ]

# ---- Write the baseline and its fingerprint ---------------------------------
commit <- tryCatch(
  system2("git", c("-C", here, "rev-parse", "--short", "HEAD"),
          stdout = TRUE, stderr = FALSE),
  error = function(e) "unknown", warning = function(w) "unknown")
write.csv(raw, file.path(out_dir, "baseline.csv"), row.names = FALSE)
writeLines(c(paste("rows:", nrow(raw)), paste("commit:", commit[1])),
           file.path(out_dir, "baseline_meta.txt"))
message(sprintf("baseline: %d rows written (commit %s)", nrow(raw), commit[1]))
