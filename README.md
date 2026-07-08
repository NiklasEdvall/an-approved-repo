# an-approved-repo
This is a good example of a well organized repo for the course [Open Science in Practice: Collaborative Research with Git](https://doctoralcourses.application.ki.se/fubasextern/info?kurs=K8F6106).

## Purpose

## Dependencies

## Scripts (in scripts/)

### `ssimulate_aud_data.R`
Generates a simulated audiological dataset of 150 subjects (`data/aud_data_simulated.csv`) with plausible real-world relationships between tinnitus severity, hearing thresholds, age, and sex.

Key features of the simulated data:
- Hearing thresholds worsen at high frequencies (>2000 Hz) with increasing tinnitus severity
- Age-related hearing loss and higher thresholds in males are included as noisy but significant effects
- Intentional data quality issues: birth year entered instead of age for two participants, and missing right-ear data for one participant

### `data_quality_report.qmd`

Quarto report that reads the raw simulated data and produces `data/data_quality_report.html`. Contains a descriptive table (stratified by tinnitus group) and a data quality section that automatically identifies and lists subjects with birth year entered instead of age, and subjects with missing ear data.

### `render_report.R`

Helper script to render `data_quality_report.qmd` and save the output to `data/`. Run from the repo root with `Rscript scripts/render_report.R`.

### `clean_data.R`
Reads the raw data and 
- Correct age entries and excluding subjects with extensive missing right-ear data. 
- Convert categorical variables to labelled factors
- Saves the result as `data/clean_data.rds`. Run from the repo root with `Rscript scripts/clean_data.R`.

## Flowchart
