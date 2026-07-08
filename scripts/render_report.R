# render_report.R
#
# Renders data_quality_report.qmd and moves the output to data/.
#
# Run from the repo root:
#   Rscript scripts/render_report.R
# Or from the scripts/ directory:
#   Rscript render_report.R

# Locate this script's directory robustly whether called via
# 'Rscript scripts/render_report.R' (from repo root) or
# 'Rscript render_report.R' (from scripts/).
# commandArgs() always contains the --file= argument when run via Rscript.
script_path <- normalizePath(
  sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)),
  mustWork = FALSE
)
script_dir <- if (length(script_path) && nzchar(script_path)) {
  dirname(script_path)
} else {
  # Fallback for interactive use: assume working directory is repo root
  file.path(getwd(), "scripts")
}

qmd_file  <- file.path(script_dir, "data_quality_report.qmd")
html_src  <- file.path(script_dir, "data_quality_report.html")
html_dest <- file.path(script_dir, "..", "data", "data_quality_report.html")

quarto::quarto_render(input = qmd_file)

if (file.exists(html_src)) {
  file.rename(html_src, html_dest)
  cat("Report saved to:", normalizePath(html_dest), "\n")
} else {
  cat("Rendered HTML not found at expected path:", html_src, "\n")
}
