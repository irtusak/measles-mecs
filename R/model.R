# model.R -------------------------------------------------------------------
# Transmission model for the Measles Elimination and Coverage Simulator.
#
# Pure functions only: no Shiny, no file reads, no global state. Everything
# here is testable from the command line (see tests/test_model.R), which is
# the point -- the numbers on the dashboard should be reproducible by anyone
# who reads this file.
#
# Every parameter default is sourced from published literature and is NOT
# fitted to Canadian case counts. See docs/METHODS.md for the reasoning.

# Parameters ----------------------------------------------------------------

#' Default measles transmission and vaccine parameters.
#'
#' R0 range 12-18 is the range conventionally used for measles in an
#' unvaccinated, well-mixed population (Anderson & May 1991). Guerra et al.
#' (2017, Lancet Infect Dis 17:e420-e428) systematically reviewed measles R0
#' estimates and found a much wider spread across settings, and cautioned that
#' 12-18 is not universal. We keep 12-18 as the default slider range because it
#' is what WHO and PHAC documents use operationally, and we let the user move
#' R0 so the sensitivity of the threshold is visible rather than hidden.
#'
#' Vaccine effectiveness against measles: about 93% after one dose and about
#' 97% after two doses (Canadian Immunization Guide, measles vaccine chapter;
#' CDC Pink Book, measles chapter). These are effectiveness against disease.
MEASLES_PARAMS <- list(
  r0_default    = 15,    # midpoint of the conventional 12-18 range
  r0_low        = 12,
  r0_high       = 18,
  ve_one_dose   = 0.93,
  ve_two_dose   = 0.97,
  who_target    = 0.95   # WHO/PHAC operational coverage target, for reference
)

# Core threshold functions --------------------------------------------------

#' Herd immunity threshold.
#'
#' The classic result: with a basic reproduction number R0, sustained
#' transmission is prevented once the immune fraction of the population
#' exceeds 1 - 1/R0.
#'
#' @param r0 Basic reproduction number (> 1).
#' @return Proportion of the population that must be immune, 0-1.
herd_immunity_threshold <- function(r0) {
  stopifnot(is.numeric(r0), all(r0 > 1, na.rm = TRUE))
  1 - 1 / r0
}

#' Vaccination coverage required to reach the herd immunity threshold.
#'
#' Vaccination is not perfectly protective, so coverage has to exceed the
#' immunity threshold: required coverage = HIT / vaccine effectiveness.
#'
#' This is the function behind the "95%" figure. At R0 = 15 and two-dose
#' effectiveness of 97%, required coverage is 0.9333 / 0.97 = 96.2%. Across the
#' conventional R0 range of 12-18 it runs from about 94.5% to 97.3%. The widely
#' quoted 95% target sits inside that band -- the dashboard derives it rather
#' than hardcoding it, so a reviewer can see what it depends on.
#'
#' @param r0 Basic reproduction number.
#' @param ve Vaccine effectiveness, 0-1.
#' @return Required coverage as a proportion. May exceed 1, which means the
#'   threshold is unreachable by vaccination alone at that R0 and effectiveness.
required_coverage <- function(r0, ve = MEASLES_PARAMS$ve_two_dose) {
  stopifnot(is.numeric(ve), all(ve > 0 & ve <= 1, na.rm = TRUE))
  herd_immunity_threshold(r0) / ve
}

#' Population immunity produced by a given vaccination coverage.
#'
#' @param coverage Proportion vaccinated, 0-1.
#' @param ve Vaccine effectiveness, 0-1.
#' @param other_immune Additional immune proportion of the *whole* population
#'   from other sources, for example adults born before 1970 who are presumed
#'   immune through natural infection. Applied to the population left
#'   unprotected by vaccination, so immunity can never exceed 1.
#' @return Immune proportion of the population, 0-1.
population_immunity <- function(coverage, ve = MEASLES_PARAMS$ve_two_dose,
                                other_immune = 0) {
  stopifnot(all(coverage >= 0 & coverage <= 1, na.rm = TRUE))
  stopifnot(all(other_immune >= 0 & other_immune <= 1, na.rm = TRUE))
  vaccine_immune <- coverage * ve
  vaccine_immune + (1 - vaccine_immune) * other_immune
}

#' Effective reproduction number.
#'
#' R_eff = R0 * (1 - immune proportion). Below 1, each case replaces itself
#' with fewer than one further case and transmission dies out.
#'
#' @param r0 Basic reproduction number.
#' @param immunity Immune proportion of the population, 0-1.
r_effective <- function(r0, immunity) {
  stopifnot(all(immunity >= 0 & immunity <= 1, na.rm = TRUE))
  r0 * (1 - immunity)
}

#' Convenience wrapper: R_eff directly from coverage.
r_effective_from_coverage <- function(coverage, r0 = MEASLES_PARAMS$r0_default,
                                      ve = MEASLES_PARAMS$ve_two_dose,
                                      other_immune = 0) {
  r_effective(r0, population_immunity(coverage, ve, other_immune))
}

# Outbreak consequences -----------------------------------------------------

#' Expected total outbreak size following a single introduction.
#'
#' Treats onward transmission as a branching process. When R_eff < 1 the
#' process is subcritical and the expected total number of cases generated by
#' one introduction, including the introduction itself, is 1 / (1 - R_eff).
#' At or above 1 the expected size is unbounded, which is the formal statement
#' of "sustained community transmission is possible".
#'
#' Standard result; see Diekmann, Heesterbeek & Britton (2013), Mathematical
#' Tools for Understanding Infectious Disease Dynamics.
#'
#' @param r_eff Effective reproduction number.
#' @return Expected number of cases, or Inf when r_eff >= 1.
expected_outbreak_size <- function(r_eff) {
  ifelse(r_eff >= 1, Inf, 1 / (1 - r_eff))
}

#' Probability that a single introduction causes a large outbreak.
#'
#' With Poisson-distributed secondary cases of mean R_eff, the probability that
#' a chain starting from one case eventually dies out is the root q in (0, 1)
#' of q = exp(-R_eff * (1 - q)). The probability of a large outbreak is 1 - q,
#' and is zero when R_eff <= 1.
#'
#' @param r_eff Effective reproduction number.
#' @return Probability, 0-1.
prob_large_outbreak <- function(r_eff) {
  one <- function(r) {
    if (is.na(r)) return(NA_real_)
    if (r <= 1) return(0)
    q <- stats::uniroot(
      function(q) exp(-r * (1 - q)) - q,
      interval = c(1e-12, 1 - 1e-12), tol = 1e-12
    )$root
    1 - q
  }
  vapply(r_eff, one, numeric(1))
}

# Clustering / equity lens --------------------------------------------------

#' Split a population into a well-covered majority and an under-immunized
#' pocket that together average to an observed provincial coverage.
#'
#' The point of the equity module. A province can report a coverage average
#' above the threshold while containing communities well below it, and measles
#' spreads in the pocket regardless of the provincial mean. This function takes
#' the observed average as a constraint and solves for the coverage of the
#' remainder, so the two groups always reproduce the real reported figure.
#'
#' This is a **modelled illustration**, not observed data: Canada does not
#' publish sub-provincial measles coverage, so the size and coverage of the
#' pocket are user-chosen inputs, not measurements.
#'
#' @param mean_coverage Observed overall coverage, 0-1.
#' @param cluster_share Proportion of the population in the pocket, 0-1
#'   (exclusive of 0 and 1).
#' @param cluster_coverage Coverage inside the pocket, 0-1.
#' @param r0,ve Transmission parameters.
#' @return A data frame with one row per subpopulation plus the overall figure.
clustered_coverage <- function(mean_coverage, cluster_share, cluster_coverage,
                               r0 = MEASLES_PARAMS$r0_default,
                               ve = MEASLES_PARAMS$ve_two_dose) {
  stopifnot(cluster_share > 0, cluster_share < 1)

  # Coverage in the rest of the population, constrained so the weighted mean
  # equals the observed provincial average.
  rest_coverage <- (mean_coverage - cluster_share * cluster_coverage) / (1 - cluster_share)

  feasible <- rest_coverage >= 0 && rest_coverage <= 1

  out <- data.frame(
    group      = c("Under-immunized community", "Rest of the province", "Province overall"),
    share      = c(cluster_share, 1 - cluster_share, 1),
    coverage   = c(cluster_coverage, rest_coverage, mean_coverage),
    stringsAsFactors = FALSE
  )
  out$immunity <- population_immunity(pmin(pmax(out$coverage, 0), 1), ve)
  out$r_eff    <- r_effective(r0, out$immunity)
  out$feasible <- feasible
  out
}

# Elimination clock ---------------------------------------------------------

#' Convert an epidemiological week to the date its week ends.
#'
#' Uses the standard MMWR/ISO-style convention that epidemiological week 1 is
#' the week containing the first Saturday in January, and weeks end on
#' Saturday. This matches how PHAC labels weeks of rash onset.
#'
#' @param year Calendar year.
#' @param week Epidemiological week number.
#' @return A Date, the Saturday ending that week.
epi_week_end <- function(year, week) {
  jan1 <- as.Date(paste0(year, "-01-01"))
  # weekday of Jan 1, with Sunday = 0
  wd <- as.integer(format(jan1, "%w"))
  # The Saturday ending epi week 1.
  first_sat <- jan1 + (6 - wd)
  if (wd > 3) first_sat <- first_sat + 7  # week 1 must contain >= 4 days of the year
  first_sat + 7 * (week - 1)
}

#' Earliest date Canada could demonstrate 12 months without transmission of an
#' outbreak-linked strain.
#'
#' WHO/PAHO verification of measles elimination requires interruption of
#' endemic transmission of a given strain for at least 12 consecutive months,
#' confirmed by adequate surveillance. This function computes, from the most
#' recent rash onset linked to the outbreak, the earliest date at which a
#' 12-month interruption could be demonstrated.
#'
#' Caveats the app must display alongside it: this is a calculation from
#' published onset dates, not a determination by PHAC or by the regional
#' verification commission, and the public data do not confirm genotype-level
#' linkage of every chain.
#'
#' @param last_onset_year,last_onset_week Most recent outbreak-linked rash onset.
#' @param as_of Date to measure progress against; defaults to today.
#' @return A list with the last onset date, the earliest verification date, and
#'   days elapsed / remaining.
elimination_clock <- function(last_onset_year, last_onset_week, as_of = Sys.Date()) {
  last_onset <- epi_week_end(last_onset_year, last_onset_week)
  earliest   <- seq(last_onset, by = "12 months", length.out = 2)[2]
  list(
    last_onset      = last_onset,
    earliest_verify = earliest,
    days_elapsed    = as.integer(as_of - last_onset),
    days_remaining  = as.integer(earliest - as_of),
    months_elapsed  = as.numeric(difftime(as_of, last_onset, units = "days")) / 30.44
  )
}
