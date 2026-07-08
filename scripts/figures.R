
library(tidyverse)
library(ggplot2)
library(ggpubr)
library(svglite)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

dat <- readRDS("data/clean_data.rds")

# =============================================================================
# 2. HELPER FUNCTION for STANDARD ERROR
# =============================================================================

std_error <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))

# =============================================================================
# 3. RESHAPE TO LONG FORMAT
#    Separate PTT and UCL into their own long data frames, each with columns:
#    ID, Group, ear (Left / Right), freq (numeric kHz), freqLabels (factor)
# =============================================================================

ptt_cols <- c("L125","L250","L500","L1000","L2000","L3000","L4000","L6000","L8000",
              "R125","R250","R500","R1000","R2000","R3000","R4000","R6000","R8000")

ucl_cols <- c("UCLL500","UCLL1000","UCLL2000","UCLL4000",
              "UCLR500","UCLR1000","UCLR2000","UCLR4000")

ptt_long <- dat[, c("ID", "Group", ptt_cols)] |>
  pivot_longer(cols = all_of(ptt_cols), names_to = "ear_freq", values_to = "dB") |>
  separate(ear_freq, into = c("ear", "freq"), sep = 1) |>
  mutate(
    freq       = as.numeric(freq) / 1000,
    freqLabels = factor(freq),
    ear        = recode(ear, "L" = "Left", "R" = "Right"),
    ear        = factor(ear, levels = c("Left", "Right"))
  )

ucl_long <- dat[, c("ID", "Group", ucl_cols)] |>
  pivot_longer(cols = all_of(ucl_cols), names_to = "ear_freq", values_to = "dB") |>
  separate(ear_freq, into = c("ear", "freq"), sep = 4) |>
  mutate(
    freq       = as.numeric(freq) / 1000,
    freqLabels = factor(freq),
    ear        = recode(ear, "UCLL" = "Left", "UCLR" = "Right"),
    ear        = factor(ear, levels = c("Left", "Right"))
  )

# =============================================================================
# 4. SHARED PLOT SETTINGS
# =============================================================================

titlesz   <- 16   # title text size
axlabsz   <- 14   # axis tick label size
axtitlesz <- 16   # axis title size
linew     <- 0.5  # line width
pointsz   <- 1    # point size
pointa    <- 0.75 # point opacity
ymax      <- 110  # y-scale maximum (UCL values reach ~100 dB)
ymin      <- -10  # y-scale minimum
pointscat <- 0.3  # dodge width to avoid overplotting

# =============================================================================
# 5. BUILD ONE PANEL PER EAR (PTT + UCL combined)
#
#    PTT:  mean ± SEM as connected pointrange, reversed y-axis (audiogram
#          convention: higher thresholds plotted lower).
#    UCL:  mean ± SEM overlaid on the same axis; UCL frequencies are a
#          subset of PTT frequencies so they share the x-axis scale.
#
#    A dashed line at 25 dB HL marks the clinical normal-hearing boundary.
# =============================================================================

make_panel <- function(ear_label) {
  ggplot(
    data = ptt_long[ptt_long$ear == ear_label, ],
    aes(y = dB, x = freqLabels, group = Group, color = Group, shape = Group)
  ) +
    # PTT: mean ± SEM pointrange + connecting line
    stat_summary(
      fun     = mean,
      fun.min = function(x) mean(x, na.rm = TRUE) - std_error(x),
      fun.max = function(x) mean(x, na.rm = TRUE) + std_error(x),
      geom    = "pointrange", size = pointsz, alpha = pointa,
      position = position_dodge(width = pointscat)
    ) +
    stat_summary(fun = mean, geom = "line", linewidth = linew) +

    # UCL: overlaid mean ± SEM pointrange + connecting line
    stat_summary(
      data    = ucl_long[ucl_long$ear == ear_label, ],
      fun     = mean,
      fun.min = function(x) mean(x, na.rm = TRUE) - std_error(x),
      fun.max = function(x) mean(x, na.rm = TRUE) + std_error(x),
      geom    = "pointrange", size = pointsz, alpha = pointa,
      position = position_dodge(width = pointscat)
    ) +
    stat_summary(
      data = ucl_long[ucl_long$ear == ear_label, ],
      fun  = mean, geom = "line", linewidth = linew
    ) +

    # Audiogram y-axis: reversed, 10 dB steps
    scale_y_reverse(
      limits = c(ymax, ymin),
      breaks = seq(ymin, ymax, by = 10)
    ) +

    # Reference line at 25 dB HL (normal hearing boundary)
    geom_hline(yintercept = 25, linetype = "dashed", color = "black", linewidth = 0.5) +

    labs(
      x     = "Frequency (kHz)",
      y     = "Threshold (dB HL)",
      title = paste("Audiogram with UCL —", ear_label, "ear")
    ) +
    theme_bw() +
    theme(
      plot.title  = element_text(size = titlesz),
      axis.text   = element_text(size = axlabsz),
      axis.title  = element_text(size = axtitlesz)
    )
}

panel_L <- make_panel("Left")
panel_R <- make_panel("Right")

# =============================================================================
# 6. ARRANGE AND SAVE
# =============================================================================

final_plot <- ggarrange(
  panel_L, panel_R,
  ncol   = 2, nrow = 1,
  common.legend = TRUE, legend = "bottom"
)

# Create output directory if it does not exist
if (!dir.exists("output")) dir.create("output")

# PNG
png(file = "output/audiogram.png", width = 1040, height = 500)
print(final_plot)
dev.off()

# SVG
ggsave(file = "output/audiogram.svg", plot = final_plot,
       units = "cm", width = 25, height = 14)

cat("Figures saved to output/audiogram.png and output/audiogram.svg\n")

# Sex within tinnitus group
dat_filtered <- droplevels(dat[dat$Sex != "Other", ])

box <- ggplot(dat_filtered, aes(x = Group, y = Age, fill = Sex)) +
  geom_boxplot() +
  labs(title = "Age Distribution by Group and Sex",
       x = "Tinnitus Group", y = "Age (years)") +
  theme_bw()

# Save sex within tinnitus group plot as png and svg
ggsave(file = "output/age_by_group_sex.png", plot = box,
       units = "cm", width = 20, height = 14)
ggsave(file = "output/age_by_group_sex.svg", plot = box,
       units = "cm", width = 20, height = 14)

cat("Figures saved to output/audiogram.png, output/audiogram.svg, output/age_by_group_sex.png, and output/age_by_group_sex.svg\n")
