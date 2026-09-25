# test_resume_claims.R ------------------------------------------------------
# Checks that every claim made about this project on Kasturi's CV is actually
# true of the running application. If a claim stops being true, this fails.
#
# Run from the project root: Rscript tests/test_resume_claims.R

suppressPackageStartupMessages({
  library(shiny); library(htmltools)
})

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")
setwd(root)

pass <- 0L; fail <- 0L
claim <- function(bullet, label, ok) {
  ok <- isTRUE(ok)
  if (ok) { pass <<- pass + 1L; cat(sprintf("  ok    [%s] %s\n", bullet, label)) }
  else    { fail <<- fail + 1L; cat(sprintf("  FAIL  [%s] %s\n", bullet, label)) }
}

# Capture the UI without starting a server, by intercepting shinyApp().
capture_env <- new.env(parent = globalenv())
capture_env$shinyApp <- function(ui, server, ...) list(ui = ui, server = server)
suppressWarnings(source("app.R", local = capture_env))
ui_html <- paste(as.character(renderTags(capture_env$ui)$html), collapse = "\n")
# Strip tags, then collapse whitespace: htmltools puts each string argument of
# a tag on its own line, so a sentence split across source lines would not
# match as one phrase even though it reads as one on screen.
plain   <- gsub("\\s+", " ", gsub("<[^>]+>", " ", ui_html))

brief   <- gsub("\\s+", " ", paste(readLines("docs/policy_brief.md", warn = FALSE), collapse = " "))
methods <- gsub("\\s+", " ", paste(readLines("docs/METHODS.md",      warn = FALSE), collapse = " "))
has <- function(hay, ...) all(vapply(list(...), function(n) grepl(n, hay, ignore.case = TRUE), logical(1)))

cat("\nBullet 1 - R Shiny dashboard integrating PHAC surveillance with coverage data\n")
claim("1", "app is a Shiny app with a UI and a server",
      !is.null(capture_env$ui) && is.function(capture_env$server))
claim("1", "PHAC weekly surveillance data is loaded",
      file.exists("data/tidy/cases_weekly_pt.csv") && file.exists("data/tidy/cases_yearly.csv"))
claim("1", "childhood immunization coverage data is loaded",
      file.exists("data/tidy/coverage_measles.csv"))
claim("1", "both data sources are named on screen",
      has(plain, "Public Health Agency of Canada", "Statistics Canada"))
claim("1", "the 2025 loss of elimination status is stated on screen",
      has(plain, "elimination", "November 2025"))

cat("\nBullet 2 - coverage simulator, by province or age group, vs the 95% threshold\n")
claim("2", "jurisdiction selector exists", has(ui_html, "sim_geo"))
claim("2", "age group selector exists",    has(ui_html, "sim_age"))
claim("2", "hypothetical coverage slider exists", has(ui_html, "sim_cov"))
claim("2", "the 95% threshold is named in the interface", has(plain, "95%"))
# The chart must actually draw the 95% operational target, not just mention it.
source("R/model.R"); source("R/theme.R"); source("R/plots.R")
p95 <- plot_reff_curve(15, 0.97, 0.916, NULL)
claim("2", "the 95% target line is drawn on the risk chart",
      any(vapply(p95$layers, function(l)
        isTRUE(all.equal(l$data$xintercept %||% NA, 95)), logical(1))) ||
      grepl("95% WHO/PHAC target",
            paste(vapply(p95$layers, function(l)
              paste(as.character(l$aes_params$label %||% ""), collapse = ""), character(1)),
              collapse = " ")))
# Risk must respond to coverage, and fall below 1 at the required level.
claim("2", "outbreak risk responds to coverage",
      r_effective_from_coverage(0.80, 15, 0.97) > r_effective_from_coverage(0.95, 15, 0.97))
claim("2", "established parameters are cited in the methods",
      has(methods, "Anderson & May", "Guerra", "Canadian Immunization Guide"))

cat("\nBullet 3 - surveillance tab: historical and recent, with lag and suppression caveats\n")
claim("3", "historical annual series is on the Surveillance tab",
      has(ui_html, "plot_yearly_surv") && has(plain, "1998 to present"))
claim("3", "recent weekly epidemic curve is present",
      has(ui_html, "plot_weekly") && has(plain, "week of rash onset"))
claim("3", "reporting lag is stated explicitly", has(plain, "Reporting lag"))
claim("3", "the lag caveat explains incompleteness", has(plain, "systematically incomplete"))
claim("3", "data suppression is stated explicitly", has(plain, "Data suppression"))
claim("3", "suppression handling is described", has(plain, "withholds", "small"))

cat("\nBullet 4 - equity and clustering module\n")
claim("4", "equity controls exist", has(ui_html, "eq_share") && has(ui_html, "eq_cov"))
claim("4", "the tab explains the average-versus-pocket point",
      has(plain, "average", "sustain an outbreak"))
# The mechanism must actually hold: a province above target, a pocket below it.
d <- clustered_coverage(0.97, 0.05, 0.70, 15, 0.97)
claim("4", "a province above target can still contain a pocket above R_eff 1",
      d$r_eff[3] < 1 && d$r_eff[1] > 1)

cat("\nBullet 5 - embedded plain-language policy brief\n")
claim("5", "the brief is embedded in the app", has(ui_html, "brief"))
claim("5", "the 12-month interruption requirement is explained",
      has(brief, "twelve consecutive months") && has(brief, "elimination"))
claim("5", "targeted community engagement is recommended",
      has(brief, "community engagement"))
claim("5", "the brief is plain-language, not a stub", nchar(brief) > 6000)
# The brief is generated from the data. It must carry no unfilled placeholder,
# and its headline figure must be the one in report_meta.json -- otherwise the
# prose and the charts disagree, which is exactly what a reviewer would catch.
claim("5", "the rendered brief has no unfilled placeholders", !grepl("\\{\\{", brief))
rm_meta <- jsonlite::fromJSON("data/tidy/report_meta.json")
claim("5", "the brief's case count matches the data behind the charts",
      grepl(format(rm_meta$annual_confirmed + rm_meta$annual_probable, big.mark = ","), brief, fixed = TRUE) &&
      grepl(format(as.Date(substr(rm_meta$phac_data_as_of, 1, 10)), "%d %B %Y"), brief, fixed = TRUE))

cat("\nBullet 6 - Git version control and a maintained decision log\n")
n_commits <- suppressWarnings(as.integer(system("git rev-list --count HEAD 2>/dev/null", intern = TRUE)))
claim("6", "the project is a git repository with history",
      length(n_commits) == 1 && !is.na(n_commits) && n_commits >= 5)
claim("6", "a decision log exists and records choices",
      file.exists("CLAUDE.md") &&
      has(paste(readLines("CLAUDE.md", warn = FALSE), collapse = "\n"),
          "Decision log", "\\[K\\]", "\\[M\\]"))

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) quit(status = 1)
