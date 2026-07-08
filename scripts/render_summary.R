# render_summary.R
#
# Renders summary_report.qmd and moves the output to data/.
#
# Run from the repo root:
#   Rscript scripts/render_summary.R

script_path <- normalizePath(
  sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)),
  mustWork = FALSE
)
script_dir <- if (length(script_path) && nzchar(script_path)) {
  dirname(script_path)
} else {
  file.path(getwd(), "scripts")
}

qmd_file  <- file.path(script_dir, "summary_report.qmd")
html_src  <- file.path(script_dir, "summary_report.html")
html_dest <- file.path(script_dir, "..", "output", "summary_report.html")

quarto::quarto_render(input = qmd_file)

if (file.exists(html_src)) {
  file.rename(html_src, html_dest)
  cat("Report saved to:", normalizePath(html_dest), "\n")
} else {
  cat("Rendered HTML not found at expected path:", html_src, "\n")
}
