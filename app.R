# app.R ---------------------------------------------------------------------
# Measles Elimination and Coverage Simulator (MECS)
#
# An independent student project by Kasturi Rangarajan, Simon Fraser
# University. Not a PHAC product.
#
# Run: Rscript -e 'shiny::runApp("app.R", port = 7788)'
#
# The app reads only local files in data/tidy/, written by R/prepare_data.R.
# It makes no network requests at runtime.

suppressPackageStartupMessages({
  library(shiny); library(bslib); library(ggplot2)
  library(dplyr); library(tidyr); library(readr); library(jsonlite)
})

app_dir <- getwd()
source(file.path(app_dir, "R", "model.R"))
source(file.path(app_dir, "R", "theme.R"))
source(file.path(app_dir, "R", "plots.R"))

tidy_path <- function(...) file.path(app_dir, "data", "tidy", ...)

# Data ----------------------------------------------------------------------
meta     <- fromJSON(tidy_path("report_meta.json"))
yearly   <- read_csv(tidy_path("cases_yearly.csv"),      show_col_types = FALSE)
weekly   <- read_csv(tidy_path("cases_weekly_pt.csv"),   show_col_types = FALSE)
by_pt    <- read_csv(tidy_path("cases_by_pt.csv"),       show_col_types = FALSE)
demo     <- read_csv(tidy_path("demographics.csv"),      show_col_types = FALSE)
outbreak <- read_csv(tidy_path("outbreaks.csv"),         show_col_types = FALSE)
coverage <- read_csv(tidy_path("coverage_measles.csv"),  show_col_types = FALSE)

AS_OF <- substr(meta$phac_data_as_of, 1, 10)

# Latest coverage cycle available per jurisdiction ---------------------------
latest_coverage <- coverage |>
  filter(!is.na(coverage)) |>
  group_by(geo, age_group) |>
  slice_max(year, n = 1, with_ties = FALSE) |>
  ungroup()

cov_lookup <- function(geo_sel, age_sel) {
  row <- latest_coverage |> filter(geo == geo_sel, age_group == age_sel)
  if (nrow(row) == 0) return(NULL)
  as.list(row[1, ])
}

GEOS <- sort(unique(coverage$geo))
GEOS <- c("Canada", setdiff(GEOS, "Canada"))
AGES <- c("2-year-olds", "7-year-olds", "17-year-olds")

# Elimination clock ---------------------------------------------------------
# Based on the most recent rash onset linked to the multi-jurisdictional
# outbreak across all reporting jurisdictions.
last_onset_row <- outbreak |>
  filter(!is.na(last_rash_onset_year), !is.na(last_rash_onset_week)) |>
  arrange(desc(last_rash_onset_year), desc(last_rash_onset_week)) |>
  slice(1)

CLOCK <- elimination_clock(last_onset_row$last_rash_onset_year,
                           last_onset_row$last_rash_onset_week)
CLOCK_PROVINCE <- last_onset_row$province

fmt_pct  <- function(x, d = 1) ifelse(is.na(x), "—", sprintf(paste0("%.", d, "f%%"), x))
fmt_num  <- function(x) ifelse(is.na(x), "—", format(x, big.mark = ","))

disclaimer <- div(
  class = "disclaimer",
  strong("Independent student project."), " Built by Kasturi Rangarajan (MPH, Simon Fraser University) ",
  "using open data from the Public Health Agency of Canada and Statistics Canada. ",
  "It is not produced or endorsed by PHAC, Statistics Canada, or any province or territory."
)

quality_note <- function(q) {
  switch(q,
    ok            = NULL,
    caution       = span(class = "flag flag-caution", "Use with caution (Statistics Canada quality flag E)"),
    unreliable    = span(class = "flag flag-gap", "Too unreliable to publish (flag F)"),
    suppressed    = span(class = "flag flag-gap", "Suppressed for confidentiality (flag x)"),
    not_available = span(class = "flag flag-gap", "Not surveyed in this cycle"),
    NULL)
}

# UI ------------------------------------------------------------------------
css <- "
.disclaimer { font-size: 0.82rem; color: #5A6472; background: #F4F6F8;
  border-left: 3px solid #0072B2; padding: 8px 12px; margin: 4px 0 16px 0; border-radius: 3px; }
.flag { display: inline-block; font-size: 0.76rem; padding: 2px 7px;
  border-radius: 10px; margin-left: 6px; }
.flag-caution { background: #FDF0D5; color: #8A5A00; border: 1px solid #E69F00; }
.flag-gap { background: #EFF1F3; color: #55606E; border: 1px solid #C9CDD4; }
.modelled-banner { background: #F7F0F6; border-left: 3px solid #CC79A7;
  padding: 8px 12px; font-size: 0.85rem; color: #6B4A62; margin-bottom: 14px;
  border-radius: 3px; }
.verdict { font-size: 1.05rem; font-weight: 600; padding: 10px 14px;
  border-radius: 4px; margin-top: 6px; }
.verdict-bad  { background: #FBEAE3; color: #8A3410; border: 1px solid #D55E00; }
.verdict-good { background: #E4F4EE; color: #05604A; border: 1px solid #009E73; }
.smallnote { font-size: 0.8rem; color: #6E7A8A; }
.brief { max-width: 62rem; }
.brief h2 { font-size: 1.28rem; margin-top: 1.6rem; }
.brief h3 { font-size: 1.05rem; margin-top: 1.1rem; color: #43505F; }
.brief li { margin-bottom: 0.35rem; }
"

ui <- page_navbar(
  title = "MECS — Measles Elimination and Coverage Simulator",
  theme = bs_theme(version = 5, primary = "#0072B2", base_font = font_google("Inter")),
  header = tags$head(tags$style(HTML(css))),

  # --- Overview -------------------------------------------------------------
  nav_panel(
    "Overview",
    div(class = "container-fluid",
      h3("Canada's measles situation and the road back to elimination"),
      disclaimer,
      layout_column_wrap(
        width = 1/4, fill = FALSE,
        value_box(title = paste0("Confirmed cases, ", meta$report_year),
                  value = fmt_num(meta$annual_confirmed),
                  showcase = NULL, theme = "primary",
                  p(class = "smallnote", paste0("plus ", meta$annual_probable,
                    " probable, across ", meta$annual_pt_count, " jurisdictions"))),
        value_box(title = "Active cases",
                  value = fmt_num(meta$active_total),
                  theme = "secondary",
                  p(class = "smallnote", paste0(meta$active_pt, " — ",
                    meta$active_phu_count, " health units"))),
        value_box(title = "Multi-jurisdictional outbreak, total",
                  value = fmt_num(meta$mj_outbreak_total),
                  theme = "secondary",
                  p(class = "smallnote", paste0("since October 2024, across ",
                    meta$mj_outbreak_pt_count, " jurisdictions"))),
        value_box(title = "New cases this reporting week",
                  value = fmt_num(meta$new_confirmed),
                  theme = "secondary",
                  p(class = "smallnote", paste0("week ", meta$report_week,
                    " (", meta$week_start, " to ", meta$week_end, ")")))
      ),
      br(),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("Confirmed measles cases in Canada, 1998 to present"),
             plotOutput("plot_yearly", height = "340px"),
             card_footer(class = "smallnote",
               "Probable cases are reported separately by PHAC for 2025 and 2026 only, and are shown",
               " as a separate band. Earlier years show confirmed cases only — a gap here means",
               " 'not reported', not zero.")),
        card(card_header("The 12-month elimination clock"),
             uiOutput("clock_ui"))
      ),
      card(card_header("Who is being infected"),
           plotOutput("plot_demo", height = "300px"),
           card_footer(class = "smallnote",
             "Vaccination status and age group of confirmed and probable cases in ",
             meta$report_year, ". Percentages shown by PHAC as '<1' are plotted at their",
             " count value and labelled accordingly."))
    )
  ),

  # --- Surveillance ---------------------------------------------------------
  nav_panel(
    "Surveillance",
    div(class = "container-fluid",
      h3("Epidemic curves"),
      p(class = "smallnote", paste0("PHAC data as of ", AS_OF,
        ". Reporting week ", meta$report_week, " of ", meta$report_year, ".")),
      disclaimer,
      card(card_header(paste0("Weekly cases by week of rash onset, ", meta$report_year)),
           layout_sidebar(
             sidebar = sidebar(
               width = 280,
               checkboxGroupInput("surv_pts", "Provinces and territories",
                 choices = setdiff(sort(unique(weekly$pt)), "Canada"),
                 selected = c("Manitoba", "Alberta", "Ontario", "British Columbia")),
               radioButtons("surv_stack", "Display",
                 choices = c("Stacked" = "stack", "Separate panels" = "facet"),
                 selected = "stack")
             ),
             plotOutput("plot_weekly", height = "400px")
           ),
           card_footer(class = "smallnote",
             paste0("Weeks 1 to ", max(weekly$week), " are reported. Later weeks of ",
               meta$report_year, " are not yet reported and are omitted rather than",
               " drawn as zero. PHAC publishes a weekly curve for the current",
               " reporting year only, so 2025 is not shown here — see the annual",
               " series on the Overview tab for the multi-year picture."))),
      card(card_header("Cases by province and territory, year to date"),
           plotOutput("plot_bypt", height = "320px"),
           card_footer(class = "smallnote",
             "Jurisdictions with no reported cases this year are shown at zero,",
             " which here is an observed count rather than a missing value."))
    )
  ),

  # --- Coverage simulator ---------------------------------------------------
  nav_panel(
    "Coverage simulator",
    div(class = "container-fluid",
      h3("Module 1 — What does a change in coverage do to outbreak risk?"),
      div(class = "modelled-banner",
        strong("Modelled scenario. "),
        "The coverage figure you choose is hypothetical. Everything downstream of it ",
        "— population immunity, the effective reproduction number, outbreak size ",
        "— is model output, not observed data. Observed coverage is shown for ",
        "comparison and is labelled as such."),
      layout_sidebar(
        sidebar = sidebar(
          width = 330,
          selectInput("sim_geo", "Jurisdiction", choices = GEOS, selected = "Canada"),
          selectInput("sim_age", "Age group", choices = AGES, selected = "2-year-olds"),
          uiOutput("sim_observed"),
          hr(),
          sliderInput("sim_cov", "Hypothetical vaccination coverage (%)",
                      min = 50, max = 100, value = 92, step = 0.5),
          actionButton("sim_reset", "Reset to observed", class = "btn-sm btn-outline-secondary"),
          hr(),
          sliderInput("sim_r0", "Basic reproduction number, R₀",
                      min = 12, max = 18, value = 15, step = 0.5),
          p(class = "smallnote",
            "12–18 is the range conventionally used for measles. Move it to see how",
            " sensitive the threshold is."),
          radioButtons("sim_ve", "Vaccine effectiveness",
            choices = c("Two doses (97%)" = "0.97", "One dose (93%)" = "0.93"),
            selected = "0.97")
        ),
        layout_columns(
          col_widths = c(6, 6),
          card(card_header("Where this coverage level sits"),
               uiOutput("sim_verdict"),
               br(),
               uiOutput("sim_numbers")),
          card(card_header("Effective reproduction number across coverage levels"),
               plotOutput("plot_sim", height = "330px"))
        )
      ),
      card(card_header("Observed coverage over time, with survey gaps shown"),
           plotOutput("plot_cov_trend", height = "300px"),
           card_footer(class = "smallnote",
             "Observed data, not modelled. The childhood National Immunization Coverage Survey",
             " runs every two years and does not publish an estimate for every jurisdiction in",
             " every cycle. Cycles with no publishable estimate are marked with a cross on the",
             " axis rather than joined up, so a gap is never read as a value.")),
      card(card_header("Why the target is 95%"),
           uiOutput("sim_derivation"))
    )
  ),

  # --- Equity lens ----------------------------------------------------------
  nav_panel(
    "Equity & clustering",
    div(class = "container-fluid",
      h3("Module 3 — Why a healthy provincial average can still sustain an outbreak"),
      div(class = "modelled-banner",
        strong("Modelled illustration. "),
        "Canada does not publish measles coverage below the provincial level, so the ",
        "size and coverage of the under-immunised community here are inputs you choose, ",
        "not measurements. The provincial average they are constrained to reproduce is ",
        "real. This module shows a mechanism; it does not describe any specific community."),
      layout_sidebar(
        sidebar = sidebar(
          width = 330,
          selectInput("eq_geo", "Jurisdiction", choices = GEOS, selected = "Canada"),
          selectInput("eq_age", "Age group", choices = AGES, selected = "2-year-olds"),
          uiOutput("eq_observed"),
          hr(),
          sliderInput("eq_share", "Share of the population in the under-immunised community (%)",
                      min = 1, max = 30, value = 8, step = 1),
          sliderInput("eq_cov", "Coverage inside that community (%)",
                      min = 20, max = 95, value = 60, step = 1),
          p(class = "smallnote",
            "Coverage in the rest of the population is solved for, so the two groups",
            " always average to the observed provincial figure.")
        ),
        layout_columns(
          col_widths = c(6, 6),
          card(card_header("Transmission in each group"),
               plotOutput("plot_equity", height = "320px")),
          card(card_header("What this means"),
               uiOutput("eq_text"))
        )
      ),
      card(card_header("What the surveillance data shows"),
           uiOutput("eq_evidence"))
    )
  ),

  # --- Policy brief ---------------------------------------------------------
  nav_panel("Policy brief", div(class = "container-fluid brief", uiOutput("brief"))),

  # --- Methods --------------------------------------------------------------
  nav_panel("Methods & data", div(class = "container-fluid brief", uiOutput("methods"))),

  nav_spacer(),
  nav_item(tags$span(class = "smallnote", paste0("PHAC data as of ", AS_OF)))
)

# Server --------------------------------------------------------------------
server <- function(input, output, session) {

  # -- Overview -------------------------------------------------------------
  output$plot_yearly <- renderPlot(plot_yearly_cases(yearly, meta, AS_OF))

  output$clock_ui <- renderUI({
    months_done <- floor(CLOCK$months_elapsed)
    pct <- max(0, min(100, 100 * CLOCK$days_elapsed / (CLOCK$days_elapsed + CLOCK$days_remaining)))
    tagList(
      p("To regain elimination status, Canada must show that transmission of the ",
        "outbreak strain has been interrupted for ", strong("12 consecutive months"),
        ", verified by adequate surveillance."),
      div(class = "verdict verdict-bad",
          sprintf("%d of 12 months since the last outbreak-linked case", months_done)),
      br(),
      tags$div(style = "background:#E8EBEF;border-radius:6px;height:14px;overflow:hidden;",
        tags$div(style = sprintf("background:%s;height:14px;width:%.1f%%;",
                                 MECS_COLOURS$safe, pct))),
      br(),
      tags$table(class = "table table-sm",
        tags$tr(tags$td("Most recent outbreak-linked rash onset"),
                tags$td(strong(format(CLOCK$last_onset, "%d %B %Y")))),
        tags$tr(tags$td("Reported in"), tags$td(CLOCK_PROVINCE,
                sprintf(" (week %d of %d)", last_onset_row$last_rash_onset_week,
                        last_onset_row$last_rash_onset_year))),
        tags$tr(tags$td("Earliest possible verification"),
                tags$td(strong(format(CLOCK$earliest_verify, "%d %B %Y")))),
        tags$tr(tags$td("Days remaining"), tags$td(strong(fmt_num(CLOCK$days_remaining))))),
      p(class = "smallnote",
        strong("This is our calculation, not a PHAC determination. "),
        "It is derived from the last rash onset dates PHAC publishes for the ",
        "multi-jurisdictional outbreak. The published data do not confirm ",
        "genotype-level linkage of every chain, and the clock resets if a new ",
        "outbreak-linked case is reported.")
    )
  })

  output$plot_demo <- renderPlot(plot_demographics(demo, meta, AS_OF))

  # -- Surveillance ---------------------------------------------------------
  output$plot_weekly <- renderPlot({
    req(length(input$surv_pts) > 0)
    p <- plot_weekly_cases(weekly, meta, AS_OF, input$surv_pts, input$surv_stack)
    validate(need(!is.null(p), "No reported cases for the selected jurisdictions."))
    p
  })

  output$plot_bypt <- renderPlot(plot_cases_by_pt(by_pt, meta, AS_OF))

  # -- Simulator ------------------------------------------------------------
  sim_obs <- reactive(cov_lookup(input$sim_geo, input$sim_age))

  output$sim_observed <- renderUI({
    o <- sim_obs()
    if (is.null(o)) {
      return(div(class = "flag flag-gap",
        "No published estimate for this jurisdiction and age group."))
    }
    tagList(
      p(class = "smallnote", style = "margin-bottom:2px;", "Observed coverage (cNICS ", o$year, ")"),
      div(style = "font-size:1.35rem;font-weight:600;", fmt_pct(o$coverage),
          if (o$quality == "caution") quality_note("caution")),
      p(class = "smallnote",
        sprintf("95%% CI %s to %s", fmt_pct(o$ci_low), fmt_pct(o$ci_high)))
    )
  })

  observeEvent(list(input$sim_geo, input$sim_age), {
    o <- sim_obs()
    if (!is.null(o) && !is.na(o$coverage)) {
      updateSliderInput(session, "sim_cov", value = round(o$coverage, 1))
    }
  })
  observeEvent(input$sim_reset, {
    o <- sim_obs()
    if (!is.null(o) && !is.na(o$coverage)) {
      updateSliderInput(session, "sim_cov", value = round(o$coverage, 1))
    }
  })

  sim_calc <- reactive({
    ve  <- as.numeric(input$sim_ve)
    r0  <- input$sim_r0
    cov <- input$sim_cov / 100
    imm <- population_immunity(cov, ve)
    reff <- r_effective(r0, imm)
    list(ve = ve, r0 = r0, cov = cov, imm = imm, reff = reff,
         req_cov = required_coverage(r0, ve),
         hit = herd_immunity_threshold(r0),
         size = expected_outbreak_size(reff),
         plarge = prob_large_outbreak(reff))
  })

  output$sim_verdict <- renderUI({
    s <- sim_calc()
    if (s$reff >= 1) {
      div(class = "verdict verdict-bad",
        sprintf("Sustained transmission possible — Rₑff = %.2f", s$reff),
        tags$div(style = "font-weight:400;font-size:0.88rem;margin-top:4px;",
          "Each case leads to more than one further case on average, so an ",
          "introduction can grow into an outbreak rather than dying out."))
    } else {
      div(class = "verdict verdict-good",
        sprintf("Below the threshold — Rₑff = %.2f", s$reff),
        tags$div(style = "font-weight:400;font-size:0.88rem;margin-top:4px;",
          "Introductions still cause cases, but chains of transmission die out."))
    }
  })

  output$sim_numbers <- renderUI({
    s <- sim_calc()
    gap <- (s$req_cov - s$cov) * 100
    tags$table(class = "table table-sm",
      tags$tr(tags$td("Chosen coverage"), tags$td(strong(fmt_pct(s$cov * 100)))),
      tags$tr(tags$td("Population immunity (coverage × effectiveness)"),
              tags$td(fmt_pct(s$imm * 100))),
      tags$tr(tags$td(sprintf("Herd immunity threshold at R₀ = %.1f", s$r0)),
              tags$td(fmt_pct(s$hit * 100))),
      tags$tr(tags$td("Coverage required to reach it"),
              tags$td(strong(if (s$req_cov > 1) "not reachable with this vaccine effectiveness"
                             else fmt_pct(s$req_cov * 100)))),
      tags$tr(tags$td("Gap to that coverage"),
              tags$td(if (gap > 0) span(style = "color:#8A3410;", sprintf("%.1f points short", gap))
                      else span(style = "color:#05604A;", sprintf("%.1f points above", -gap)))),
      tags$tr(tags$td("Expected cases per introduction"),
              tags$td(if (is.infinite(s$size)) "unbounded" else sprintf("%.1f", s$size))),
      tags$tr(tags$td("Chance one introduction becomes a large outbreak"),
              tags$td(fmt_pct(s$plarge * 100, 0)))
    )
  })

  output$plot_sim <- renderPlot({
    s <- sim_calc()
    plot_reff_curve(s$r0, s$ve, s$cov, sim_obs())
  })

  output$plot_cov_trend <- renderPlot({
    p <- plot_coverage_trend(coverage, input$sim_geo, input$sim_age,
                             input$sim_r0, as.numeric(input$sim_ve))
    validate(need(!is.null(p), "No coverage series for this selection."))
    p
  })

  output$sim_derivation <- renderUI({
    s <- sim_calc()
    tagList(
      p("The 95% figure is not a constant in this app — it is calculated, so you can see what it rests on."),
      tags$ol(
        tags$li(sprintf("Herd immunity threshold = 1 − 1/R₀ = 1 − 1/%.1f = %s of the population must be immune.",
                        s$r0, fmt_pct(s$hit * 100))),
        tags$li(sprintf("Vaccination is %.0f%% effective, so coverage must exceed immunity: %s ÷ %.2f = %s.",
                        s$ve * 100, fmt_pct(s$hit * 100), s$ve,
                        if (s$req_cov > 1) "above 100% — unreachable" else fmt_pct(s$req_cov * 100))),
        tags$li(sprintf("Across the conventional R₀ range of 12 to 18 at two-dose effectiveness, required coverage runs from %s to %s. The 95%% operational target sits inside that band.",
                        fmt_pct(required_coverage(12, 0.97) * 100),
                        fmt_pct(required_coverage(18, 0.97) * 100)))
      ),
      p(class = "smallnote",
        "Assumes a well-mixed population. Real populations are not well mixed, which is what the ",
        "Equity & clustering tab is about. R₀ range: Anderson & May (1991); see also Guerra et al. ",
        "(2017), Lancet Infectious Diseases, for the wider spread across settings. Vaccine ",
        "effectiveness: Canadian Immunization Guide; CDC Pink Book.")
    )
  })

  # -- Equity ---------------------------------------------------------------
  eq_obs <- reactive(cov_lookup(input$eq_geo, input$eq_age))

  output$eq_observed <- renderUI({
    o <- eq_obs()
    if (is.null(o)) return(div(class = "flag flag-gap", "No published estimate."))
    tagList(
      p(class = "smallnote", style = "margin-bottom:2px;",
        paste0("Observed provincial average (cNICS ", o$year, ")")),
      div(style = "font-size:1.3rem;font-weight:600;", fmt_pct(o$coverage),
          if (o$quality == "caution") quality_note("caution"))
    )
  })

  eq_calc <- reactive({
    o <- eq_obs()
    req(!is.null(o), !is.na(o$coverage))
    clustered_coverage(mean_coverage = o$coverage / 100,
                       cluster_share = input$eq_share / 100,
                       cluster_coverage = input$eq_cov / 100,
                       r0 = 15, ve = 0.97)
  })

  output$plot_equity <- renderPlot({
    p <- plot_equity(eq_calc())
    validate(need(!is.null(p), paste(
      "This combination is impossible: to average out to the observed provincial",
      "figure, coverage in the rest of the population would have to exceed 100%.",
      "Reduce the size of the community or raise its coverage.")))
    p
  })

  output$eq_text <- renderUI({
    d <- eq_calc(); o <- eq_obs()
    pocket <- d[1, ]; rest <- d[2, ]; overall <- d[3, ]
    if (!pocket$feasible) {
      return(div(class = "flag flag-gap",
        "This combination is impossible: to average out to the observed provincial figure, ",
        "coverage in the rest of the population would have to exceed 100%. Reduce the size ",
        "of the community or raise its coverage."))
    }
    tagList(
      p(sprintf("%s reports %s coverage for %s — %s the level needed to stop sustained transmission.",
                input$eq_geo, fmt_pct(o$coverage), input$eq_age,
                if (overall$r_eff < 1) "at or above" else "below")),
      p(sprintf("If %s%% of that population lives in a community with %s%% coverage, then to keep the provincial average where it is, the rest of the population must sit at %s.",
                input$eq_share, input$eq_cov, fmt_pct(rest$coverage * 100))),
      tags$ul(
        tags$li(sprintf("Inside that community, each case leads to %.1f further cases on average.",
                        pocket$r_eff)),
        tags$li(sprintf("In the rest of the population, %.2f.", rest$r_eff)),
        tags$li(sprintf("Province-wide the average is %.2f.", overall$r_eff))
      ),
      p(if (pocket$r_eff >= 1 && overall$r_eff < 1)
          strong("This is the elimination problem in one line: the province looks protected on average, and the virus still spreads.")
        else if (pocket$r_eff >= 1)
          strong("Both the community and the province are above the threshold — the gap is not only a clustering problem.")
        else
          "At these settings even the under-immunised community is below the threshold."),
      p(class = "smallnote",
        "R₀ fixed at 15 and two-dose effectiveness at 97% for this module. Assumes each ",
        "group mixes mainly within itself, which is the assumption that makes clustering matter.")
    )
  })

  output$eq_evidence <- renderUI({
    unvax <- demo |> filter(characteristic == "Vaccination status", category == "Unvaccinated")
    linked <- demo |> filter(characteristic == "Exposure source",
                             grepl("^Exposed in Canada", category))
    mb <- by_pt |> filter(pt == "Manitoba")
    on <- by_pt |> filter(pt == "Ontario")
    mb_cov <- cov_lookup("Manitoba", "2-year-olds")
    on_cov <- cov_lookup("Ontario", "2-year-olds")
    tagList(
      p("The clustering model above is an illustration. These are the observed figures that make it relevant:"),
      tags$ul(
        tags$li(strong(paste0(unvax$count, " of ", meta$annual_confirmed + meta$annual_probable,
                              " cases (", unvax$percentage_label, "%) were unvaccinated")),
                " — transmission is concentrated in people with no protection, not spread evenly."),
        tags$li(strong(paste0(linked$percentage_label, "% of cases were acquired in Canada")),
                " and linked epidemiologically or virologically to known chains, rather than imported."),
        tags$li(sprintf("Manitoba reported %s cases this year with %s coverage among 2-year-olds; Ontario reported %s with %s.",
                        fmt_num(mb$cases_ytd), fmt_pct(mb_cov$coverage),
                        fmt_num(on$cases_ytd), fmt_pct(on_cov$coverage)),
                span(class = "smallnote",
                  " This is a comparison of two numbers, not a causal claim — provincial averages",
                  " do not explain where within a province transmission happened."))
      ),
      p(class = "smallnote",
        "Sub-provincial coverage is not published nationally. Closing that gap is itself a ",
        "recommendation in the policy brief.")
    )
  })

  # -- Static documents -----------------------------------------------------
  render_md <- function(file) {
    path <- file.path(app_dir, "docs", file)
    if (!file.exists(path)) return(p("Document not found."))
    HTML(markdown::markdownToHTML(path, fragment.only = TRUE))
  }
  output$brief   <- renderUI(render_md("policy_brief.md"))
  output$methods <- renderUI(render_md("METHODS.md"))
}

shinyApp(ui, server)
