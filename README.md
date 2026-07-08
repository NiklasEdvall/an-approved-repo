# an-approved-repo
This is a good example of a well organized repo for the course [Open Science in Practice: Collaborative Research with Git](https://doctoralcourses.application.ki.se/fubasextern/info?kurs=K8F6106).

## Purpose

## Dependencies

## Scripts

### `scripts/simulate_aud_data.R`

This script generates a simulated audiological dataset of 150 subjects, saved as `data/aud_data_simulated.csv`. It produces pure-tone hearing thresholds for left and right ears across nine frequencies (125–8000 Hz), uncomfortable loudness levels (UCL) at four frequencies per ear, tinnitus severity group (1 = none, 2 = mild, 3 = severe), age (20–65 years), and sex (integer-coded: 1 = male, 2 = female, 3 = other). Baseline threshold means and effect sizes are manually selected plausible values based on typical audiological norms. Key relationships embedded in the simulation include: worsening high-frequency thresholds with increasing tinnitus severity, age-related hearing loss (presbycusis) that grows with frequency, and higher thresholds and greater tinnitus burden in males compared to females. All effects are statistically significant but intentionally noisy to reflect plausible real-world variability. The script requires base R only (no external packages) and uses `set.seed(42)` for reproducibility; a brief validation summary is printed to the console on each run.

## Flowchart
