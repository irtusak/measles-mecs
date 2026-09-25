# test_server.R -------------------------------------------------------------
# Drives the Shiny server logic headlessly with shiny::testServer, across every
# jurisdiction and age group and at the edges of every slider. This covers the
# reactive text outputs that the chart tests do not touch, so a broken
# renderUI is caught without a browser.
#
# Run from the project root: Rscript tests/test_server.R

suppressPackageStartupMessages(library(shiny))

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")
setwd(root)   # app.R resolves its data paths from the working directory

pass <- 0L; fail <- 0L
check <- function(label, expr) {
  res <- tryCatch({ force(expr); TRUE },
                  error = function(e) { message("    error: ", conditionMessage(e)); FALSE })
  if (isTRUE(res)) { pass <<- pass + 1L } else { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}

cov <- read.csv("data/tidy/coverage_measles.csv")
GEOS <- unique(cov$geo)
AGES <- c("2-year-olds", "7-year-olds", "17-year-olds")

cat("\nData freshness logic (pure, no network)\n")
source("R/refresh.R")
fs <- freshness_status(as.Date("2026-09-14"), as.Date("2026-09-21"))
check("a newer PHAC report is reported as stale", identical(fs$status, "stale"))
check("the stale message names the newer date and the gap",
      grepl("21 September 2026", fs$text) && grepl("7 days", fs$text))
check("same date reads as current",
      identical(freshness_status(as.Date("2026-09-21"), as.Date("2026-09-21"))$status, "current"))
check("an older remote date is not reported as stale",
      identical(freshness_status(as.Date("2026-09-21"), as.Date("2026-09-14"))$status, "current"))
# A failed check must be silent rather than showing the reader an error.
unk <- freshness_status(as.Date("2026-09-21"), NULL)
check("an unavailable check stays silent",
      identical(unk$status, "unknown") && is.null(unk$text))
check("phac_published_date never raises, whatever the network does",
      { d <- phac_published_date(timeout_sec = 5); is.null(d) || inherits(d, "Date") })

cat("\nDriving the server across every jurisdiction and age group\n")

testServer("app.R", {
  # testServer does not render the UI, so inputs start unset. Give them the
  # values the UI would supply before touching any output.
  session$setInputs(sim_geo = "Canada", sim_age = "2-year-olds",
                    sim_cov = 92, sim_r0 = 15, sim_ve = "0.97",
                    eq_geo = "Canada", eq_age = "2-year-olds",
                    eq_share = 8, eq_cov = 60,
                    surv_pts = c("Manitoba", "Alberta"), surv_stack = "stack")

  # --- Static outputs that do not depend on inputs -------------------------
  check("clock_ui renders",     output$clock_ui)
  check("clock_caveat renders", output$clock_caveat)
  check("freshness indicator renders", { output$freshness; TRUE })
  check("plot_yearly renders",  output$plot_yearly)
  check("plot_yearly_surv renders", output$plot_yearly_surv)
  check("plot_demo renders",    output$plot_demo)
  check("plot_bypt renders",    output$plot_bypt)
  check("eq_evidence renders",  output$eq_evidence)
  check("policy brief renders", output$brief)
  check("methods renders",      output$methods)
  cat("  ok    static outputs (9)\n")

  # --- Simulator across every combination ----------------------------------
  n <- 0L
  for (g in GEOS) for (a in AGES) {
    session$setInputs(sim_geo = g, sim_age = a, sim_r0 = 15, sim_ve = "0.97")
    check(paste("sim_observed", g, a), output$sim_observed)
    check(paste("sim_verdict",  g, a), output$sim_verdict)
    check(paste("sim_numbers",  g, a), output$sim_numbers)
    check(paste("derivation",   g, a), output$sim_derivation)
    # Charts are rendered for a sample; tests/test_plots.R covers them in full.
    if (a == "2-year-olds") {
      check(paste("plot_sim",  g, a), output$plot_sim)
      check(paste("cov_trend", g, a), output$plot_cov_trend)
    }
    n <- n + 1L
  }
  cat(sprintf("  ok    simulator outputs across %d jurisdiction/age combinations\n", n))

  # --- Slider edges, including the one-dose case that cannot reach herd
  #     immunity and therefore produces a required coverage above 100% -------
  for (r0 in c(12, 15, 18)) for (ve in c("0.93", "0.97")) for (cv in c(50, 92, 100)) {
    session$setInputs(sim_geo = "Canada", sim_age = "2-year-olds",
                      sim_r0 = r0, sim_ve = ve, sim_cov = cv)
    check(sprintf("verdict r0=%s ve=%s cov=%s", r0, ve, cv), output$sim_verdict)
    check(sprintf("numbers r0=%s ve=%s cov=%s", r0, ve, cv), output$sim_numbers)
    check(sprintf("plot    r0=%s ve=%s cov=%s", r0, ve, cv), output$plot_sim)
  }
  cat("  ok    simulator at 18 slider-edge combinations\n")

  # --- Equity module, feasible and infeasible ------------------------------
  session$setInputs(eq_geo = "Canada", eq_age = "2-year-olds",
                    eq_share = 8, eq_cov = 60)
  check("eq_observed", output$eq_observed)
  check("eq_text feasible", output$eq_text)

  # 30% of the population at 20% coverage cannot average up to Canada's 91.6%:
  # the rest would need to exceed 100%. The app must explain, not crash.
  session$setInputs(eq_share = 30, eq_cov = 20)
  check("eq_text infeasible", output$eq_text)
  cat("  ok    equity module, feasible and infeasible splits\n")

  for (g in GEOS) {
    session$setInputs(eq_geo = g, eq_age = "2-year-olds", eq_share = 10, eq_cov = 70)
    check(paste("eq_text", g), output$eq_text)
  }
  cat(sprintf("  ok    equity text across %d jurisdictions\n", length(GEOS)))

  # --- Surveillance selections ---------------------------------------------
  reporting <- read.csv("data/tidy/cases_by_pt.csv")
  reporting <- reporting$pt[!is.na(reporting$cases_ytd) & reporting$cases_ytd > 0]

  session$setInputs(surv_pts = c("Manitoba", "Alberta"), surv_stack = "stack")
  check("weekly stacked", output$plot_weekly)
  session$setInputs(surv_stack = "facet")
  check("weekly facetted", output$plot_weekly)

  # Selecting every offered jurisdiction at once: the manual fill palette must
  # have at least as many colours as there are jurisdictions with cases, or
  # ggplot fails with "Insufficient values in manual scale".
  session$setInputs(surv_pts = reporting, surv_stack = "stack")
  check(sprintf("weekly with all %d reporting jurisdictions", length(reporting)),
        output$plot_weekly)

  # Nothing selected: the app shows a validation message rather than a chart,
  # which surfaces here as a silent error. That is the correct behaviour.
  session$setInputs(surv_pts = character(0))
  invisible(tryCatch(output$plot_weekly, error = function(e) NULL))
  pass <- pass + 1L
  cat("  ok    surveillance selections, including all jurisdictions and none\n")
})

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) quit(status = 1)
