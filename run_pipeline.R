# =============================================================================
# run_pipeline.R
#
# Master script — runs the full project pipeline in order:
#   1. simulate_aud_data.R  – simulate raw audiological data
#   2. render_report.R      – render the data quality report
#   3. clean_data.R         – clean and validate the raw data
#   4. figures.R            – generate output figures
#   5. render_summary.R     – render the summary report
#
# Run from the repo root:
#   Rscript run_pipeline.R
# =============================================================================

# ---------------------------------------------------------------------------
# Ensure the working directory is the repo root (where this script lives)
# ---------------------------------------------------------------------------
script_path <- normalizePath(
  sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)),
  mustWork = FALSE
)
repo_root <- if (length(script_path) && nzchar(script_path)) {
  dirname(script_path)
} else {
  getwd()
}
setwd(repo_root)
cat("Working directory set to:", repo_root, "\n\n")

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

# 1. Ensure output/ and data/ directories exist
for (d in c("data", "output")) {
  if (!dir.exists(d)) {
    dir.create(d)
    cat("Created missing directory:", d, "\n")
  }
}

# 2. Check required packages are installed
required_pkgs <- c("arsenal", "ggplot2", "tidyverse", "ggpubr", "svglite", "quarto")
missing_pkgs  <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(
    "The following required packages are not installed:\n  ",
    paste(missing_pkgs, collapse = ", "),
    "\nInstall them with: install.packages(c(",
    paste0('"', missing_pkgs, '"', collapse = ", "), "))",
    call. = FALSE
  )
}
cat("All required packages found.\n\n")

# ---------------------------------------------------------------------------
# Helper: run a script and stop the pipeline on failure
#
# Steps that use source() are run directly (simulate, clean, figures).
# Steps that invoke quarto::quarto_render() are run as Rscript subprocesses
# so that commandArgs() resolves the script path correctly for Quarto's CLI.
# ---------------------------------------------------------------------------
rscript_bin <- file.path(R.home("bin"), "Rscript")

run_step <- function(step_number, label, script_rel_path, subprocess = FALSE) {
  cat(rep("=", 60), "\n", sep = "")
  cat(sprintf("Step %d: %s\n", step_number, label))
  cat(rep("=", 60), "\n", sep = "")

  full_path <- file.path(repo_root, script_rel_path)

  if (subprocess) {
    # Run as a child Rscript process so --file= is set correctly for quarto
    exit_code <- system2(rscript_bin, args = full_path)
    if (exit_code != 0) {
      stop(sprintf("Pipeline aborted at step %d: Rscript exited with code %d.",
                   step_number, exit_code), call. = FALSE)
    }
  } else {
    tryCatch(
      source(full_path, local = new.env(parent = globalenv())),
      error = function(e) {
        cat(sprintf("\nERROR in step %d (%s):\n  %s\n", step_number, label, conditionMessage(e)))
        stop(sprintf("Pipeline aborted at step %d.", step_number), call. = FALSE)
      }
    )
  }

  cat(sprintf("\nStep %d complete.\n\n", step_number))
}

# ---------------------------------------------------------------------------
# Pipeline steps
# ---------------------------------------------------------------------------
run_step(1, "Simulate audiological data",  "scripts/simulate_aud_data.R")
run_step(2, "Render data quality report",  "scripts/render_report.R",  subprocess = TRUE)
run_step(3, "Clean data",                  "scripts/clean_data.R")
run_step(4, "Generate figures",            "scripts/figures.R")
run_step(5, "Render summary report",       "scripts/render_summary.R", subprocess = TRUE)

cat(rep("=", 60), "\n", sep = "")
cat("Pipeline complete. All steps finished successfully.\n")
cat(rep("=", 60), "\n", sep = "")
