# plots.R -------------------------------------------------------------------
# Chart builders. Pure functions: each takes data and returns a ggplot object,
# with no Shiny inputs and no file access. app.R calls these, and
# tests/test_plots.R renders every one of them headlessly, so a broken chart
# is caught without needing a browser.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr)
})

fmt_pct_p <- function(x, d = 1) ifelse(is.na(x), "—", sprintf(paste0("%.", d, "f%%"), x))
fmt_num_p <- function(x) ifelse(is.na(x), "—", format(x, big.mark = ","))

#' Annual confirmed and probable cases, 1998 onward.
plot_yearly_cases <- function(yearly, meta, as_of) {
  d <- yearly |>
    pivot_longer(c(confirmed, probable), names_to = "type", values_to = "n") |>
    filter(!is.na(n)) |>
    mutate(type = factor(type, levels = c("probable", "confirmed"),
                         labels = c("Probable", "Confirmed")))
  ggplot(d, aes(year, n, fill = type)) +
    geom_col(width = 0.78) +
    scale_fill_manual(values = c(Confirmed = MECS_COLOURS$cases,
                                 Probable  = MECS_COLOURS$probable)) +
    scale_y_continuous(labels = scales::comma, expand = expansion(c(0, 0.08))) +
    scale_x_continuous(breaks = seq(1998, max(d$year), 4)) +
    labs(x = NULL, y = "Cases",
         title = "Canada lost measles elimination status in November 2025",
         subtitle = paste0("Confirmed cases 1998–", meta$report_year,
                           ". 2025 was the largest year since elimination was achieved in 1998."),
         caption = SOURCE_PHAC(as_of)) +
    theme_mecs()
}

#' Cases by vaccination status and age group.
plot_demographics <- function(demo, meta, as_of) {
  d <- demo |>
    filter(characteristic %in% c("Vaccination status", "Age group"),
           !is.na(count), category != "Unknown") |>
    mutate(characteristic = factor(characteristic,
             levels = c("Vaccination status", "Age group")))
  ggplot(d, aes(x = reorder(category, count), y = count)) +
    geom_col(fill = MECS_COLOURS$cases, width = 0.7) +
    geom_text(aes(label = paste0(fmt_num_p(count), "  (", percentage_label, "%)")),
              hjust = -0.08, size = 3.4, colour = "#43505F") +
    coord_flip(clip = "off") +
    facet_wrap(~characteristic, scales = "free_y") +
    scale_y_continuous(expand = expansion(c(0, 0.32))) +
    labs(x = NULL, y = "Cases",
         title = paste0("Measles cases in ", meta$report_year,
                        " by vaccination status and age"),
         subtitle = "The overwhelming majority of cases are in people who were never vaccinated.",
         caption = SOURCE_PHAC(as_of)) +
    theme_mecs() + theme(panel.grid.major.y = element_blank())
}

#' Weekly epidemic curve for the current reporting year.
#' @param mode "stack" or "facet".
plot_weekly_cases <- function(weekly, meta, as_of, pts, mode = "stack") {
  d <- weekly |> filter(pt %in% pts, !is.na(cases))
  if (nrow(d) == 0) return(NULL)

  p <- ggplot(d, aes(week, cases, fill = pt)) +
    scale_fill_manual(values = unname(OKABE_ITO[c(6, 2, 4, 3, 7, 8, 5, 1)])) +
    scale_x_continuous(breaks = scales::pretty_breaks(8)) +
    scale_y_continuous(expand = expansion(c(0, 0.06))) +
    labs(x = paste0("Epidemiological week of rash onset, ", meta$report_year),
         y = "Confirmed and probable cases",
         title = paste0("Weekly measles cases, ", meta$report_year),
         subtitle = paste0("Reported through week ", max(weekly$week),
                           ". Later weeks are not yet reported and are omitted."),
         caption = SOURCE_PHAC(as_of)) +
    theme_mecs()

  if (identical(mode, "facet")) {
    p + geom_col(width = 0.85, show.legend = FALSE) +
      facet_wrap(~pt, ncol = 2, scales = "free_y")
  } else {
    p + geom_col(width = 0.85)
  }
}

#' Year-to-date cases by jurisdiction.
plot_cases_by_pt <- function(by_pt, meta, as_of) {
  d <- by_pt |> filter(!is.na(cases_ytd))
  ggplot(d, aes(x = reorder(pt, cases_ytd), y = cases_ytd)) +
    geom_col(fill = MECS_COLOURS$cases, width = 0.72) +
    geom_text(aes(label = fmt_num_p(cases_ytd)), hjust = -0.15, size = 3.4,
              colour = "#43505F") +
    coord_flip(clip = "off") +
    scale_y_continuous(expand = expansion(c(0, 0.14))) +
    labs(x = NULL, y = "Cases year to date",
         title = paste0("Measles cases by jurisdiction, ", meta$report_year,
                        " year to date"),
         caption = SOURCE_PHAC(as_of)) +
    theme_mecs() + theme(panel.grid.major.y = element_blank())
}

#' Modelled effective reproduction number across coverage levels.
#'
#' @param observed Optional list with `coverage` and `year` for the observed
#'   marker; NULL to omit.
plot_reff_curve <- function(r0, ve, chosen_cov, observed = NULL) {
  grid <- tibble::tibble(cov = seq(0.5, 1, by = 0.002)) |>
    mutate(reff = r_effective_from_coverage(cov, r0, ve))
  chosen_reff <- r_effective_from_coverage(chosen_cov, r0, ve)

  p <- ggplot(grid, aes(cov * 100, reff)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = MECS_COLOURS$threshold) +
    annotate("text", x = 51, y = 1, label = "R_eff = 1", vjust = -0.6,
             hjust = 0, size = 3.4, colour = MECS_COLOURS$threshold) +
    geom_line(linewidth = 1, colour = MECS_COLOURS$modelled) +
    annotate("point", x = chosen_cov * 100, y = chosen_reff, size = 3.6,
             colour = MECS_COLOURS$modelled) +
    annotate("text", x = chosen_cov * 100, y = chosen_reff,
             label = sprintf(" %.1f%%, R_eff %.2f", chosen_cov * 100, chosen_reff),
             hjust = -0.05, vjust = -0.6, size = 3.5, colour = MECS_COLOURS$modelled)

  if (!is.null(observed) && !is.na(observed$coverage)) {
    p <- p +
      geom_vline(xintercept = observed$coverage, colour = MECS_COLOURS$neutral,
                 linetype = "dotted") +
      annotate("text", x = observed$coverage, y = max(grid$reff) * 0.95,
               label = paste0(" observed ", fmt_pct_p(observed$coverage),
                              " (", observed$year, ")"),
               hjust = 0, size = 3.3, colour = MECS_COLOURS$neutral)
  }

  p + scale_x_continuous(labels = function(x) paste0(x, "%")) +
    labs(x = "Vaccination coverage", y = "Effective reproduction number",
         title = "Modelled outbreak risk against coverage",
         subtitle = sprintf(
           "R0 = %.1f, vaccine effectiveness %.0f%%. Purple line is model output.",
           r0, ve * 100),
         caption = paste0("Modelled scenario.\n", SOURCE_CNICS)) +
    theme_mecs()
}

#' Effective reproduction number in each modelled subpopulation.
plot_equity <- function(d) {
  # An infeasible split would need coverage above 100% in the rest of the
  # population to average out to the observed figure. Refuse it rather than
  # drawing a clamped bar labelled with an impossible percentage.
  if (!isTRUE(d$feasible[1])) return(NULL)
  d$group <- factor(d$group, levels = rev(d$group))
  ggplot(d, aes(group, r_eff, fill = r_eff >= 1)) +
    geom_col(width = 0.65) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = MECS_COLOURS$threshold) +
    geom_text(aes(label = sprintf("R_eff %.2f  (coverage %s)", r_eff,
                                  fmt_pct_p(coverage * 100))),
              hjust = -0.04, size = 3.5, colour = "#43505F") +
    coord_flip(clip = "off") +
    scale_fill_manual(values = c(`TRUE` = MECS_COLOURS$warning,
                                 `FALSE` = MECS_COLOURS$safe), guide = "none") +
    scale_y_continuous(expand = expansion(c(0, 0.45))) +
    labs(x = NULL, y = "Effective reproduction number",
         title = "The provincial average hides the pocket",
         subtitle = "Bars above the dashed line can sustain transmission. Modelled.",
         caption = paste0("Modelled illustration; provincial average is observed.\n", SOURCE_CNICS)) +
    theme_mecs() + theme(panel.grid.major.y = element_blank())
}

#' Coverage over time for one jurisdiction and age group, with gaps preserved.
#'
#' Cycles with no publishable estimate are drawn as open markers on the axis
#' rather than being interpolated over, so a survey gap never reads as a value.
plot_coverage_trend <- function(coverage, geo_sel, age_sel, r0 = 15, ve = 0.97) {
  d <- coverage |> filter(geo == geo_sel, age_group == age_sel) |> arrange(year)
  if (nrow(d) == 0) return(NULL)
  req_cov <- required_coverage(r0, ve) * 100
  have <- d |> filter(!is.na(coverage))
  gaps <- d |> filter(is.na(coverage))

  p <- ggplot(d, aes(year, coverage)) +
    geom_hline(yintercept = req_cov, linetype = "dashed",
               colour = MECS_COLOURS$threshold) +
    annotate("text", x = min(d$year), y = req_cov,
             label = sprintf(" coverage needed at R0 = %.0f: %.1f%%", r0, req_cov),
             hjust = 0, vjust = -0.7, size = 3.3, colour = MECS_COLOURS$threshold)

  if (nrow(have) > 0) {
    p <- p +
      geom_errorbar(data = have, aes(ymin = ci_low, ymax = ci_high),
                    width = 0.35, colour = MECS_COLOURS$neutral, na.rm = TRUE)
    # Several territories have only one publishable cycle. A line needs two
    # points, and asking for one warns rather than failing, so skip it.
    if (nrow(have) > 1) {
      p <- p + geom_line(data = have, colour = MECS_COLOURS$cases, linewidth = 0.8)
    }
    p <- p +
      geom_point(data = have, aes(shape = quality), size = 3,
                 colour = MECS_COLOURS$cases) +
      scale_shape_manual(values = c(ok = 16, caution = 1),
                         labels = c(ok = "Estimate",
                                    caution = "Use with caution (flag E)"))
  }
  if (nrow(gaps) > 0) {
    p <- p + geom_point(data = gaps, aes(y = 0), shape = 4, size = 2.4,
                        colour = MECS_COLOURS$suppressed)
  }

  p + scale_y_continuous(limits = c(0, 100),
                         labels = function(x) paste0(x, "%")) +
    scale_x_continuous(breaks = unique(d$year)) +
    labs(x = NULL, y = "Coverage",
         title = paste0("Measles vaccination coverage, ", age_sel, ", ", geo_sel),
         subtitle = paste0(
           "95% confidence intervals shown. ",
           if (nrow(gaps) > 0)
             paste0(nrow(gaps), " cycle(s) with no publishable estimate marked \u00d7 on the axis.")
           else "All cycles carry a publishable estimate."),
         caption = SOURCE_CNICS) +
    theme_mecs()
}
