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
MECS_COLOURS <- list(
  cases        = unname(OKABE_ITO["blue"]),
  probable     = unname(OKABE_ITO["sky_blue"]),
  threshold    = unname(OKABE_ITO["vermillion"]),
  safe         = unname(OKABE_ITO["green"]),
  warning      = unname(OKABE_ITO["orange"]),
  modelled     = unname(OKABE_ITO["purple"]),
  neutral      = "#6E7A8A",
  suppressed   = "#C9CDD4"
)

theme_mecs <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", size = base_size * 1.15,
                                      margin = margin(b = 4)),
      plot.subtitle    = element_text(colour = "#5A6472", size = base_size * 0.92,
                                      margin = margin(b = 10)),
      plot.caption     = element_text(colour = "#77808E", size = base_size * 0.78,
                                      hjust = 0, margin = margin(t = 10)),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      axis.title       = element_text(colour = "#43505F", size = base_size * 0.9),
      axis.text        = element_text(colour = "#5A6472"),
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
