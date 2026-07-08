# =============================================================================
# 1. LOAD RAW DATA
#    Age is read as character to handle the mixed integer / birth-year column.
# =============================================================================

raw <- read.csv(
  file.path("data", "aud_data_simulated.csv"),
  colClasses = c(Age = "character")
)

# =============================================================================
# 2. FIX BIRTH-YEAR ENTRIES FOR SUBJECTS 7 AND 43
#    These subjects have a 4-digit birth year in the Age column instead of
#    their age in years. Correct by computing 2026 - birth year.
# =============================================================================

birthyear_ids <- c(7, 43)

for (id in birthyear_ids) {
  row       <- which(raw$ID == id)
  birthyear <- as.integer(raw$Age[row])
  raw$Age[row] <- as.character(2026L - birthyear)
}

# Now the Age column contains only valid ages; coerce to integer.
raw$Age <- as.integer(raw$Age)

# =============================================================================
# 3. EXCLUDE SUBJECT 22 (MISSING RIGHT-EAR DATA)
# =============================================================================

clean <- raw[raw$ID != 22, ]

# =============================================================================
# 4. CONVERT GROUP AND SEX TO LABELLED FACTORS
#    Coding follows the code key (data/code_key.xlsx):
#      Group: 1 = No tinnitus, 2 = Mild tinnitus, 3 = Severe tinnitus
#      Sex:   1 = Male, 2 = Female, 3 = Other
# =============================================================================

clean$Group <- factor(
  clean$Group,
  levels = 1:3,
  labels = c("No tinnitus", "Mild tinnitus", "Severe tinnitus")
)

clean$Sex <- factor(
  clean$Sex,
  levels = 1:3,
  labels = c("Male", "Female", "Other")
)

# =============================================================================
# 5. QUICK VALIDATION
# =============================================================================

cat("--- Cleaned dataset ---\n")
cat("Rows:", nrow(clean), "(expected 149)\n")
cat("Subject 22 present:", 22 %in% clean$ID, "(expected FALSE)\n")

cat("\nAge for subjects 7 and 43 (should be integers, not birth years):\n")
print(clean[clean$ID %in% birthyear_ids, c("ID", "Age")])

cat("\nGroup distribution:\n")
print(table(clean$Group))

cat("\nSex distribution:\n")
print(table(clean$Sex))

# =============================================================================
# 6. SAVE CLEANED DATA FRAME
# =============================================================================

saveRDS(clean, file = file.path("data", "clean_data.rds"))
cat("\nClean data saved to: data/clean_data.rds\n")
