# test_plots.R --------------------------------------------------------------
# Renders every chart headlessly against the real tidy data. Catches broken
# aesthetics, missing columns and scale errors without needing a browser.
# Writes the PNGs to tests/output/ so they can be eyeballed.
#
# Run: Rscript tests/test_plots.R

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(jsonlite); library(ggplot2)
})

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")

source(file.path(root, "R", "model.R"))
source(file.path(root, "R", "theme.R"))
source(file.path(root, "R", "plots.R"))

tp <- function(...) file.path(root, "data", "tidy", ...)
meta     <- fromJSON(tp("report_meta.json"))
yearly   <- read_csv(tp("cases_yearly.csv"),     show_col_types = FALSE)
weekly   <- read_csv(tp("cases_weekly_pt.csv"),  show_col_types = FALSE)
by_pt    <- read_csv(tp("cases_by_pt.csv"),      show_col_types = FALSE)
demo     <- read_csv(tp("demographics.csv"),     show_col_types = FALSE)
coverage <- read_csv(tp("coverage_measles.csv"), show_col_types = FALSE)
AS_OF <- substr(meta$phac_data_as_of, 1, 10)

out_dir <- file.path(root, "tests", "output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

pass <- 0L; fail <- 0L
render <- function(name, plot_expr, width = 9, height = 5) {
  path <- file.path(out_dir, paste0(name, ".png"))
  res <- tryCatch({
    p <- force(plot_expr)
    if (is.null(p)) stop("plot builder returned NULL")
    # Warnings during rendering usually mean dropped rows, so surface them.
    withCallingHandlers(
      ggsave(path, p, width = width, height = height, dpi = 110, bg = "white"),
      warning = function(w) {
        message("    warning: ", conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    TRUE
  }, error = function(e) { message("    error: ", conditionMessage(e)); FALSE })

  ok <- isTRUE(res) && file.exists(path) && file.size(path) > 5000
  if (ok) { pass <<- pass + 1L; cat(sprintf("  ok    %-22s %6.0f KB\n", name, file.size(path) / 1024)) }
  else    { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", name)) }
}

cat("\nRendering charts against real data\n")
render("yearly_cases",  plot_yearly_cases(yearly, meta, AS_OF), 9, 4.5)
render("demographics",  plot_demographics(demo, meta, AS_OF), 10, 4.5)
render("weekly_stack",  plot_weekly_cases(weekly, meta, AS_OF,
                          c("Manitoba", "Alberta", "Ontario", "British Columbia"), "stack"), 10, 5)
render("weekly_facet",  plot_weekly_cases(weekly, meta, AS_OF,
                          c("Manitoba", "Alberta"), "facet"), 9, 5)
render("cases_by_pt",   plot_cases_by_pt(by_pt, meta, AS_OF), 9, 4.5)

can <- coverage |> filter(geo == "Canada", age_group == "2-year-olds", !is.na(coverage)) |>
  slice_max(year, n = 1)
render("reff_curve",    plot_reff_curve(15, 0.97, 0.916,
                          list(coverage = can$coverage, year = can$year)), 8, 4.8)
render("reff_curve_bare", plot_reff_curve(18, 0.93, 0.80, NULL), 8, 4.8)
render("equity",        plot_equity(clustered_coverage(0.97, 0.05, 0.70, 15, 0.97)), 9, 4)

# Jurisdictions with different suppression patterns.
render("coverage_canada",  plot_coverage_trend(coverage, "Canada", "2-year-olds"), 8, 4.5)
render("coverage_alberta", plot_coverage_trend(coverage, "Alberta", "2-year-olds"), 8, 4.5)
render("coverage_nunavut", plot_coverage_trend(coverage, "Nunavut", "2-year-olds"), 8, 4.5)

cat("\nEdge cases\n")
empty <- plot_weekly_cases(weekly, meta, AS_OF, character(0), "stack")
if (is.null(empty)) { pass <- pass + 1L; cat("  ok    empty selection returns NULL\n") } else {
  fail <- fail + 1L; cat("  FAIL  empty selection should return NULL\n") }

# 8% of the population at 60% coverage cannot average to 97% without the rest
# exceeding 100%, so the chart must refuse to draw it.
infeasible <- plot_equity(clustered_coverage(0.97, 0.08, 0.60, 15, 0.97))
if (is.null(infeasible)) { pass <- pass + 1L; cat("  ok    infeasible split returns NULL\n") } else {
  fail <- fail + 1L; cat("  FAIL  infeasible split should return NULL\n") }

nocov <- plot_coverage_trend(coverage, "Nowhere", "2-year-olds")
if (is.null(nocov)) { pass <- pass + 1L; cat("  ok    unknown jurisdiction returns NULL\n") } else {
  fail <- fail + 1L; cat("  FAIL  unknown jurisdiction should return NULL\n") }

cat(sprintf("\n%d passed, %d failed. PNGs in tests/output/\n", pass, fail))
if (fail > 0) quit(status = 1)
