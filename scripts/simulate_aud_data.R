# =============================================================================
# simulate_aud_data.R
#
# Purpose: Simulate an audiological dataset of 150 subjects. The simulated
#          data includes:
#            - Tinnitus group (1 = none, 2 = mild, 3 = severe)
#            - Pure-tone hearing thresholds for left (L) and right (R) ears
#              at 9 frequencies: 125, 250, 500, 1000, 2000, 3000, 4000,
#              6000, 8000 Hz
#            - Uncomfortable Loudness Level (UCL) thresholds for 4
#              frequencies (500, 1000, 2000, 4000 Hz) per ear
#            - Age (20-65 years)
#            - Sex (approximately 43% male, 55% female, 2% other)
#              coded as integer: 1 = male, 2 = female, 3 = other
#
# Key design decisions (based on real-world audiology patterns):
#   1. Hearing thresholds increase (worsen) at frequencies >2000 Hz with
#      increasing tinnitus severity.
#   2. Hearing thresholds increase with age (age-related hearing loss /
#      presbycusis), predominantly at high frequencies.
#   3. Males show higher (worse) hearing thresholds than females and are
#      more likely to belong to higher tinnitus severity groups.
#   4. All relationships are statistically significant but noisy, as
#      expected in real clinical data.
#   5. Within-group variability is greater than in the original dataset to
#      reflect a larger, more heterogeneous sample.
#
# Output: data/aud_data_simulated.csv
#
# Dependencies: base R only (no external packages required)
#
# Author: [your name]
# Date:   2026-07-08
# =============================================================================

set.seed(42)   # for reproducibility

# =============================================================================
# 1. GLOBAL SETTINGS
# =============================================================================

N <- 150   # total number of subjects

# Frequencies (Hz) measured
freqs <- c(125, 250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

# Frequencies for UCL (subset)
ucl_freqs <- c(500, 1000, 2000, 4000)

# Age range
age_min <- 20
age_max <- 65

# =============================================================================
# 2. ASSIGN SEX
#    Target: ~55% female, ~43% male, ~2% other
#    Coded as integer: 1 = male, 2 = female, 3 = other
# =============================================================================

sex <- sample(
  x       = c(1L, 2L, 3L),   # 1 = male, 2 = female, 3 = other
  size    = N,
  replace = TRUE,
  prob    = c(0.43, 0.55, 0.02)
)

# =============================================================================
# 3. ASSIGN AGE (uniform between 20-65; not correlated with sex here)
# =============================================================================

age <- as.integer(round(runif(N, min = age_min, max = age_max)))

# =============================================================================
# 4. ASSIGN TINNITUS GROUP
#    Males are more likely to be in severe-tinnitus group.
#    We use group probabilities that differ by sex.
#
#    Female / Other: roughly 40% none, 38% mild, 22% severe
#    Male:           roughly 30% none, 35% mild, 35% severe
# =============================================================================

group <- integer(N)

for (i in seq_len(N)) {
  if (sex[i] == 1L) {   # male
    group[i] <- sample(1:3, 1, prob = c(0.30, 0.35, 0.35))
  } else {               # female or other
    group[i] <- sample(1:3, 1, prob = c(0.40, 0.38, 0.22))
  }
}

# =============================================================================
# 5. BASELINE HEARING THRESHOLDS BY GROUP AND FREQUENCY
#
#    Mean thresholds (dB HL) are modelled from the original data:
#      - Groups 1 & 2 have near-normal thresholds at low frequencies.
#      - From 3000 Hz upwards, group 2 is slightly elevated, group 3
#        markedly elevated (reflects the UCL/tinnitus simulation in the
#        original dataset).
#    Values are manually selected plausible values based on typical
#    audiological norms.
# =============================================================================

# baseline_means[group, frequency_index]
# Rows = groups 1,2,3   |   Columns = 125,250,500,1000,2000,3000,4000,6000,8000

baseline_means <- matrix(
  c(
    #  125   250  500  1000  2000  3000  4000  6000  8000
    6,    6,   5,    6,    9,    9,    8,   14,   18,   # group 1
    7,    8,   8,    8,    7,   18,   19,   27,   27,   # group 2
    8,    7,   8,    8,   10,   33,   33,   35,   31    # group 3
  ),
  nrow = 3, byrow = TRUE
)

# Within-group SD — increased vs original to reflect greater heterogeneity
baseline_sd <- 6   # dB; applies to all groups and frequencies

# =============================================================================
# 6. AGE EFFECT ON HEARING
#
#    Presbycusis predominantly affects high frequencies. We model the effect
#    as a linear slope: additional dB per year above 30, scaled by frequency.
#    Effect is small at low frequencies and larger at high frequencies.
#
#    Reference age for zero offset: 30 years
#    Frequency-specific slopes (dB / year above 30):
# =============================================================================

# Slopes in dB/year for each of the 9 frequencies
age_slopes <- c(
  0.05,   # 125 Hz  – minimal age effect
  0.07,   # 250 Hz
  0.10,   # 500 Hz
  0.12,   # 1000 Hz
  0.18,   # 2000 Hz
  0.22,   # 3000 Hz
  0.28,   # 4000 Hz – substantial presbycusis
  0.35,   # 6000 Hz
  0.40    # 8000 Hz – largest age effect
)

age_ref <- 30   # threshold values above are calibrated to this reference age

# =============================================================================
# 7. SEX EFFECT ON HEARING
#
#    Males tend to have higher (worse) thresholds, especially at high
#    frequencies (noise-exposure pattern). We add a fixed offset for males.
# =============================================================================

# Additional dB for males at each frequency (females / other = 0 offset)
sex_offsets_male <- c(
  0,    # 125 Hz
  0,    # 250 Hz
  1,    # 500 Hz
  1,    # 1000 Hz
  2,    # 2000 Hz
  3,    # 3000 Hz
  4,    # 4000 Hz
  5,    # 6000 Hz
  5     # 8000 Hz
)

# =============================================================================
# 8. SIMULATE HEARING THRESHOLDS
#
#    For each subject, for each ear, for each frequency:
#      threshold = baseline(group, freq)
#                + age_effect(age, freq)
#                + sex_effect(sex, freq)
#                + noise
#
#    Left and right ears share the same group/age/sex effects but have
#    independent noise terms (ears are correlated within person but not
#    identical).
# =============================================================================

# Helper: simulate thresholds for one set of ears (left or right).
# Returns an integer matrix (dB HL values are always whole numbers).
simulate_ear <- function(group_vec, age_vec, sex_vec, n_subj) {
  mat <- matrix(NA_integer_, nrow = n_subj, ncol = length(freqs))

  for (i in seq_len(n_subj)) {
    g <- group_vec[i]
    a <- age_vec[i]
    s <- sex_vec[i]

    # age contribution (relative to reference age)
    age_contrib <- pmax(0, (a - age_ref)) * age_slopes

    # sex contribution (1 = male gets the offset; female/other = 0)
    sex_contrib <- if (s == 1L) sex_offsets_male else rep(0, length(freqs))

    # baseline + effects + noise; rounded to nearest integer
    mu <- baseline_means[g, ] + age_contrib + sex_contrib
    mat[i, ] <- as.integer(round(rnorm(length(freqs), mean = mu, sd = baseline_sd)))
  }

  mat
}

L_thresholds <- simulate_ear(group, age, sex, N)
R_thresholds <- simulate_ear(group, age, sex, N)

# =============================================================================
# 9. SIMULATE UCL THRESHOLDS
#
#    UCL values in the original data range roughly 75-95 dB SPL.
#    UCLs tend to be inversely related to tinnitus severity (loudness
#    discomfort is lower / more sensitive in tinnitus patients).
#
#    Mean UCL by group:
#      Group 1: ~87 dB SPL
#      Group 2: ~85 dB SPL
#      Group 3: ~84 dB SPL
#
#    Age and sex have small effects on UCL; we keep it simple with noise only.
# =============================================================================

ucl_means_by_group <- c(87, 85, 84)   # mean UCL (dB SPL) for groups 1,2,3
ucl_sd <- 5                            # within-group SD for UCL

# Returns an integer matrix (UCL values are whole-number dB SPL).
simulate_ucl <- function(group_vec, n_subj, n_ucl_freqs = 4) {
  mat <- matrix(NA_integer_, nrow = n_subj, ncol = n_ucl_freqs)
  for (i in seq_len(n_subj)) {
    mu <- ucl_means_by_group[group_vec[i]]
    mat[i, ] <- as.integer(round(rnorm(n_ucl_freqs, mean = mu, sd = ucl_sd)))
  }
  mat
}

UCLL <- simulate_ucl(group, N)
UCLR <- simulate_ucl(group, N)

# =============================================================================
# 10. ASSEMBLE THE FINAL DATA FRAME
#
#     Column order: ID, Group, Age, Sex, L thresholds, R thresholds,
#     UCLL, UCLR. Sex is integer (1=male, 2=female, 3=other); Age and all
#     threshold/UCL values are integer.
# =============================================================================

# Column names for hearing thresholds
L_names <- paste0("L", freqs)
R_names <- paste0("R", freqs)

# Column names for UCL
UCLL_names <- paste0("UCLL", ucl_freqs)
UCLR_names <- paste0("UCLR", ucl_freqs)

sim_data <- data.frame(
  ID    = seq_len(N),
  Group = group,
  Age   = age,
  Sex   = sex,
  as.data.frame(L_thresholds),
  as.data.frame(R_thresholds),
  as.data.frame(UCLL),
  as.data.frame(UCLR)
)

# Apply proper column names
names(sim_data)[5:(5 + length(freqs) - 1)]                          <- L_names
names(sim_data)[(5 + length(freqs)):(5 + 2*length(freqs) - 1)]     <- R_names
names(sim_data)[(5 + 2*length(freqs)):(5 + 2*length(freqs) + 3)]   <- UCLL_names
names(sim_data)[(5 + 2*length(freqs) + 4):(5 + 2*length(freqs) + 7)] <- UCLR_names

# =============================================================================
# 11. QUICK VALIDATION — printed to console, not saved
#
#     Check that the key relationships are present in the simulated data.
# =============================================================================

cat("\n--- Simulated data: sample counts ---\n")
cat("Total subjects:", N, "\n")
cat("Group distribution:\n")
print(table(sim_data$Group))
cat("\nSex distribution:\n")
print(table(sim_data$Sex))
cat("\nAge summary:\n")
print(summary(sim_data$Age))

cat("\n--- Mean 4000 Hz threshold by group (should increase group 1 < 2 < 3) ---\n")
cat("Left ear (L4000):\n")
print(tapply(sim_data$L4000, sim_data$Group, mean))

cat("\n--- Correlation: Age vs. L8000 (should be positive) ---\n")
cat(round(cor(sim_data$Age, sim_data$L8000), 3), "\n")

cat("\n--- Mean L4000 by sex (1=male should be highest) ---\n")
print(tapply(sim_data$L4000, sim_data$Sex, mean))

cat("\n--- Linear model: L8000 ~ Age + Sex + Group ---\n")
lm_check <- lm(L8000 ~ Age + Sex + Group, data = sim_data)
print(summary(lm_check)$coefficients)

# =============================================================================
# 12. SAVE SIMULATED DATA
# =============================================================================

out_path <- file.path("..", "data", "aud_data_simulated.csv")

# Resolve path relative to the script location if run interactively from root
if (!dir.exists(dirname(out_path))) {
  out_path <- file.path("data", "aud_data_simulated.csv")
}

write.csv(sim_data, file = out_path, row.names = FALSE)
cat("\nSimulated data saved to:", out_path, "\n")

# =============================================================================
# 13. WRITE CODE KEY (data/code_key.xlsx)
#
#     Documents every variable in the dataset: name, type, labels/coding,
#     and unit. Uses the openxlsx package.
# =============================================================================

library(openxlsx)

# Build the code key as a data frame. One row per variable.
# Hearing threshold columns: L125 … R8000 (18 columns)
# UCL columns: UCLL500 … UCLR4000 (8 columns)

# Helper to build rows for a block of similarly-structured columns
hearing_rows <- function(side, freqs_hz) {
  data.frame(
    Variable_name = paste0(side, freqs_hz),
    Variable_type = "integer",
    Labels        = paste0(
      "Pure-tone hearing threshold at ", freqs_hz, " Hz, ",
      ifelse(side == "L", "left", "right"), " ear"
    ),
    Units         = "dB HL",
    stringsAsFactors = FALSE
  )
}

ucl_rows <- function(side, freqs_hz) {
  data.frame(
    Variable_name = paste0("UCL", side, freqs_hz),
    Variable_type = "integer",
    Labels        = paste0(
      "Uncomfortable loudness level at ", freqs_hz, " Hz, ",
      ifelse(side == "L", "left", "right"), " ear"
    ),
    Units         = "dB SPL",
    stringsAsFactors = FALSE
  )
}

code_key <- rbind(
  data.frame(
    Variable_name = "ID",
    Variable_type = "integer",
    Labels        = "Unique subject identifier",
    Units         = "—",
    stringsAsFactors = FALSE
  ),
  data.frame(
    Variable_name = "Group",
    Variable_type = "integer",
    Labels        = "Tinnitus severity group: 1 = no tinnitus, 2 = mild tinnitus, 3 = severe tinnitus",
    Units         = "—",
    stringsAsFactors = FALSE
  ),
  data.frame(
    Variable_name = "Age",
    Variable_type = "integer",
    Labels        = "Age of participant",
    Units         = "years",
    stringsAsFactors = FALSE
  ),
  data.frame(
    Variable_name = "Sex",
    Variable_type = "integer",
    Labels        = "Biological sex / gender identity: 1 = male, 2 = female, 3 = other",
    Units         = "—",
    stringsAsFactors = FALSE
  ),
  hearing_rows("L", freqs),
  hearing_rows("R", freqs),
  ucl_rows("L", ucl_freqs),
  ucl_rows("R", ucl_freqs)
)

# Resolve output path (same logic as for the CSV)
key_path <- file.path("..", "data", "code_key.xlsx")
if (!dir.exists(dirname(key_path))) {
  key_path <- file.path("data", "code_key.xlsx")
}

# Create workbook, style the header row, write data, auto-size columns
wb <- createWorkbook()
addWorksheet(wb, "Code Key")

# Header style: bold, light blue fill
header_style <- createStyle(
  fontName   = "Calibri",
  fontSize   = 11,
  textDecoration = "bold",
  fgFill     = "#D9E1F2",
  border     = "Bottom",
  halign     = "left"
)

writeData(wb, sheet = "Code Key", x = code_key, headerStyle = header_style)

# Apply a thin border to all data cells for readability
data_style <- createStyle(border = "TopBottomLeftRight", borderColour = "#BFBFBF")
addStyle(wb, sheet = "Code Key", style = data_style,
         rows = 2:(nrow(code_key) + 1), cols = 1:4, gridExpand = TRUE)

# Auto-size columns
setColWidths(wb, sheet = "Code Key", cols = 1:4, widths = "auto")

saveWorkbook(wb, file = key_path, overwrite = TRUE)
cat("Code key saved to:", key_path, "\n")
