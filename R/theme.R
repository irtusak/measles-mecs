# theme.R -------------------------------------------------------------------
# Shared plotting style. The Okabe-Ito palette is colour-blind safe, which
# matters for a public health audience and is cheap to adopt.
# Okabe & Ito (2008), "Color Universal Design".

suppressPackageStartupMessages(library(ggplot2))

OKABE_ITO <- c(
  black      = "#000000",
  orange     = "#E69F00",
  sky_blue   = "#56B4E9",
  green      = "#009E73",
  yellow     = "#F0E442",
  blue       = "#0072B2",
  vermillion = "#D55E00",
  purple     = "#CC79A7"
)

# Semantic roles, so the meaning of a colour is set in one place.
#
# Reference lines and their labels are drawn in the SAME colour, so each pair
# reads as one thing. That colour therefore has to satisfy the 4.5:1 text
# contrast minimum on white, not just the 3:1 minimum for graphical objects,
# which is why the line colours below are darkened relatives of the Okabe-Ito
# hues rather than the hues themselves. Bars and filled areas keep the pure
# Okabe-Ito values: they are large shapes, and every one is labelled in text.
# Ratios against white are asserted in tests/test_contrast.R.
MECS_COLOURS <- list(
  cases        = unname(OKABE_ITO["blue"]),      # 5.19:1
  probable     = unname(OKABE_ITO["sky_blue"]),  # fill only
  warning      = unname(OKABE_ITO["orange"]),    # fill only
  threshold    = "#A34500",                      # 6.16:1  darkened vermillion
  safe         = "#00674C",                      # 6.90:1  darkened green
  modelled     = "#9B4779",                      # 5.88:1  darkened purple
  neutral      = "#5A6472",                      # 6.00:1  was #6E7A8A at 4.36:1
  label        = "#43505F",                      # 8.23:1  in-chart data labels
  caption      = "#5C6673",                      # 5.83:1  was #77808E at 3.99:1
  suppressed   = "#8892A0"                       # 3.24:1  gap markers, graphical
)

theme_mecs <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", size = base_size * 1.15,
                                      margin = margin(b = 4)),
      plot.subtitle    = element_text(colour = MECS_COLOURS$neutral, size = base_size * 0.92,
                                      margin = margin(b = 10)),
      plot.caption     = element_text(colour = MECS_COLOURS$caption, size = base_size * 0.78,
                                      hjust = 0, margin = margin(t = 10)),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      axis.title       = element_text(colour = MECS_COLOURS$label, size = base_size * 0.9),
      axis.text        = element_text(colour = MECS_COLOURS$neutral),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E8EBEF", linewidth = 0.4),
      legend.position  = "top",
      legend.title     = element_blank(),
      legend.key.height = unit(0.8, "lines"),
      plot.margin      = margin(10, 14, 8, 10)
    )
}

# Every chart carries its provenance.
SOURCE_PHAC <- function(as_of) {
  paste0("Source: Public Health Agency of Canada, Measles and Rubella Weekly ",
         "Monitoring Report. Data as of ", as_of,
         ".\nIndependent student project; not a PHAC product.")
}
SOURCE_CNICS <- paste0(
  "Source: Statistics Canada table 13-10-0870-01 (PHAC childhood National ",
  "Immunization Coverage Survey).\nIndependent student project; not a PHAC product."
)
