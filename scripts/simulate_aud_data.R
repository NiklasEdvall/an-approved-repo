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
#    UCL values in the original data range roughly 75-95 dB HL.
#    UCLs tend to be inversely related to tinnitus severity (loudness
#    discomfort is lower / more sensitive in tinnitus patients).
#
#    Mean UCL by group:
#      Group 1: ~87 dB HL
#      Group 2: ~85 dB HL
#      Group 3: ~84 dB HL
#
#    Age and sex have small effects on UCL; we keep it simple with noise only.
# =============================================================================

ucl_means_by_group <- c(87, 85, 84)   # mean UCL (dB HL) for groups 1,2,3
ucl_sd <- 5                            # within-group SD for UCL

# Returns an integer matrix (UCL values are whole-number dB HL).
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
# 11. INTRODUCE REALISTIC DATA QUALITY ISSUES
#
#     To simulate real-world data entry errors and missing data:
#
#     a) BIRTHYEAR INSTEAD OF AGE: Two participants have their birth year
#        recorded in the Age column instead of their age in years. This
#        mimics a common data-entry mistake when age is collected on paper
#        forms. The Age column is converted to character to allow mixed
#        values (integers and 4-digit years).
#
#     b) MISSING EAR DATA: All right-ear hearing threshold columns are set
#        to NA for one participant, simulating a case where one ear could
#        not be tested (e.g., due to equipment failure or non-compliance).
#        UCL values for that ear are also set to NA for consistency.
# =============================================================================

# a) Replace Age with birth year for participants 7 and 43.
#    A plausible birth year is derived from the current year minus their age,
#    giving a realistic 4-digit year rather than a random number.
#    The column must be character to hold both integers and year strings.

sim_data$Age <- as.character(sim_data$Age)
sim_data$Age[7]  <- as.character(2026L - age[7])   # e.g. age 34 -> "1992"
sim_data$Age[43] <- as.character(2026L - age[43])  # e.g. age 51 -> "1975"

# b) Set all right-ear thresholds and right-ear UCL to NA for participant 22.
#    This represents a complete failure to obtain right-ear measurements.
sim_data[22, R_names]   <- NA
sim_data[22, UCLR_names] <- NA

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
