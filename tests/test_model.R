# test_model.R --------------------------------------------------------------
# Checks R/model.R against hand-computed values and against PHAC's own
# published figures. Run: Rscript tests/test_model.R
# Exits non-zero on the first failure.

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")
source(file.path(root, "R", "model.R"))

pass <- 0L; fail <- 0L
check <- function(label, actual, expected, tol = 1e-4) {
  ok <- isTRUE(all.equal(actual, expected, tolerance = tol))
  if (ok) {
    pass <<- pass + 1L
    cat(sprintf("  ok    %s\n", label))
  } else {
    fail <<- fail + 1L
    cat(sprintf("  FAIL  %s\n          expected: %s\n          actual:   %s\n",
                label, paste(format(expected), collapse = ", "),
                paste(format(actual), collapse = ", ")))
  }
}

cat("\nHerd immunity threshold (1 - 1/R0)\n")
check("R0 = 12", herd_immunity_threshold(12), 0.9166667)
check("R0 = 15", herd_immunity_threshold(15), 0.9333333)
check("R0 = 18", herd_immunity_threshold(18), 0.9444444)

cat("\nRequired coverage (HIT / vaccine effectiveness)\n")
# This is the derivation behind the 95% target: across the conventional R0
# range the required two-dose coverage brackets 95%.
check("R0 = 12, VE = 0.97", required_coverage(12, 0.97), 0.9450172)
check("R0 = 15, VE = 0.97", required_coverage(15, 0.97), 0.9621993)
check("R0 = 18, VE = 0.97", required_coverage(18, 0.97), 0.9736541)
check("95% target sits inside the R0 12-18 band",
      required_coverage(12, 0.97) < 0.95 && required_coverage(18, 0.97) > 0.95, TRUE)
check("one dose cannot reach the threshold at R0 = 15",
      required_coverage(15, 0.93) > 1, TRUE)

cat("\nPopulation immunity\n")
check("coverage 0 gives no immunity", population_immunity(0, 0.97), 0)
check("coverage 1 gives VE", population_immunity(1, 0.97), 0.97)
check("Canada 2021, 2-year-olds (91.6%)", population_immunity(0.916, 0.97), 0.88852)
check("other_immune never pushes immunity above 1",
      population_immunity(1, 0.97, other_immune = 1), 1)

cat("\nEffective reproduction number\n")
check("R_eff = R0 at zero immunity", r_effective(15, 0), 15)
check("R_eff = 1 exactly at the threshold",
      r_effective(15, herd_immunity_threshold(15)), 1)
check("R_eff from Canada's 2021 coverage, R0 = 15",
      r_effective_from_coverage(0.916, 15, 0.97), 1.6722)
check("R_eff falls below 1 at the required coverage",
      r_effective_from_coverage(required_coverage(15, 0.97), 15, 0.97), 1)

cat("\nOutbreak consequences\n")
check("expected size at R_eff = 0.5", expected_outbreak_size(0.5), 2)
check("expected size at R_eff = 0.9", expected_outbreak_size(0.9), 10)
check("expected size unbounded at R_eff = 1", expected_outbreak_size(1), Inf)
check("no large outbreak at or below R_eff = 1", prob_large_outbreak(1), 0)
# For Poisson offspring with mean 2, extinction probability is about 0.2032.
check("P(large outbreak) at R_eff = 2", prob_large_outbreak(2), 0.7968, tol = 1e-3)
check("P(large outbreak) rises with R_eff",
      prob_large_outbreak(3) > prob_large_outbreak(2), TRUE)

cat("\nClustering\n")
cl <- clustered_coverage(mean_coverage = 0.92, cluster_share = 0.10,
                         cluster_coverage = 0.60, r0 = 15, ve = 0.97)
check("rest-of-province coverage solves the weighted mean",
      cl$coverage[cl$group == "Rest of the province"], 0.9555556)
check("weighted mean reproduces the observed average",
      sum(cl$coverage[1:2] * cl$share[1:2]), 0.92)
# The equity point: a province can sit above the threshold on average and
# still contain a pocket where each case produces several more. 97% overall
# with a 5% community at 70% gives R_eff 0.89 province-wide but 4.8 in the
# pocket. (At 92% overall the province is already above 1 on its own, so it
# would not illustrate the point.)
safe_avg <- clustered_coverage(mean_coverage = 0.97, cluster_share = 0.05,
                               cluster_coverage = 0.70, r0 = 15, ve = 0.97)
check("a province above the threshold on average", safe_avg$r_eff[3] < 1, TRUE)
check("still has a pocket with sustained transmission", safe_avg$r_eff[1] > 1, TRUE)
check("pocket R_eff at 70% coverage", safe_avg$r_eff[1], 4.815)
check("an infeasible split is flagged",
      clustered_coverage(0.92, 0.5, 0.10)$feasible[1], FALSE)

cat("\nEpidemiological weeks\n")
# Validated against PHAC's own global_variables.csv, which reports week 35 of
# 2026 as ending 2026-09-05.
check("2026 week 35 ends on PHAC's published date",
      epi_week_end(2026, 35), as.Date("2026-09-05"))
check("2026 week 1 ends 2026-01-10", epi_week_end(2026, 1), as.Date("2026-01-10"))
check("weeks are 7 days apart",
      as.integer(epi_week_end(2026, 10) - epi_week_end(2026, 9)), 7L)
check("week ends fall on a Saturday",
      format(epi_week_end(2026, 20), "%w"), "6")

cat("\nElimination clock\n")
ec <- elimination_clock(2026, 31, as_of = as.Date("2026-09-19"))
check("last onset is the end of 2026 week 31", ec$last_onset, as.Date("2026-08-08"))
check("earliest verification is 12 months later", ec$earliest_verify, as.Date("2027-08-08"))
check("days elapsed", ec$days_elapsed, 42L)
check("days remaining", ec$days_remaining, 323L)

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) quit(status = 1)
