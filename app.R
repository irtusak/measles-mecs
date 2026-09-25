# app.R ---------------------------------------------------------------------
# Measles Elimination and Coverage Simulator (MECS)
#
# An independent student project by Kasturi Rangarajan, Simon Fraser
# University. Not a PHAC product.
#
# Run: Rscript -e 'shiny::runApp("app.R", port = 7788)'
#
# The app reads only local files in data/tidy/, written by scripts/prepare_data.R.
# It makes no network requests at runtime.

suppressPackageStartupMessages({
  library(shiny); library(bslib); library(ggplot2)
  library(dplyr); library(tidyr); library(readr); library(jsonlite)
})

# jsonlite also exports validate(), and being attached after shiny it wins.
# shiny::validate is therefore always called by its full name below; without
# that, every validation message in the app fails with
# "is.character(txt) is not TRUE" instead of explaining the problem.

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
  # Inputs can be NULL while a session is initialising. Without this guard the
  # filter below is handed a zero-length value, throws, and the error takes
  # down every other output in the session.
  if (length(geo_sel) != 1 || length(age_sel) != 1 ||
      is.na(geo_sel) || is.na(age_sel)) return(NULL)
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

# Measured against the PHAC report date, not today: the data is a snapshot, and
# counting months past it would claim progress the data cannot support.
CLOCK <- elimination_clock(last_onset_row$last_rash_onset_year,
                           last_onset_row$last_rash_onset_week,
                           as_of = as.Date(AS_OF))
CLOCK_PROVINCE <- last_onset_row$province

fmt_pct  <- function(x, d = 1) ifelse(is.na(x), "—", sprintf(paste0("%.", d, "f%%"), x))
fmt_num  <- function(x) ifelse(is.na(x), "—", format(x, big.mark = ","))

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
# Layout: a masthead that stays above the tabs on every view (title, what the
# dashboard is, contact), then a sticky tab strip, then one tab of content.
# Detail that is not needed at a glance lives in collapsed accordions rather
# than on the page, so each tab shows one idea at a time.
css <- "
html { font-size: 17px; }
body { line-height: 1.55; background: #FAFBFC; }
/* The masthead and each tab set their own gutters, so the Bootstrap
   container padding would only double them up. */
body > .container-fluid { padding: 0; }

/* --- masthead ---------------------------------------------------------- */
.mecs-header { background: #FFFFFF; border-bottom: 1px solid #DFE4EA; padding: 26px 0 20px; }
.mecs-inner { max-width: 1500px; margin: 0 auto; padding: 0 28px; }
.mecs-title { font-size: 2.5rem; font-weight: 700; letter-spacing: -0.02em;
  color: #11212E; margin: 0; line-height: 1.08; }
.mecs-title .mecs-abbr { color: #0072B2; }
.mecs-blurb { max-width: 60rem; margin: 14px 0 0; color: #36424F; font-size: 1.02rem; }
.mecs-contact { margin-top: 16px; padding-top: 14px; border-top: 1px solid #EDF0F3;
  font-size: 0.94rem; color: #43505F; line-height: 1.45; }
.mecs-contact .mecs-name { font-weight: 600; color: #11212E; }
.mecs-contact a { color: #0072B2; }
.mecs-foot { margin-top: 10px; font-size: 0.84rem; color: #6B7684; }

/* --- sticky tab strip --------------------------------------------------- */
.mecs-body > div > .nav { position: sticky; top: 0; z-index: 1020;
  background: #FFFFFF; border-bottom: 1px solid #DFE4EA;
  padding: 10px 28px; margin: 0 0 26px; gap: 4px; }
.mecs-body .nav-pills .nav-link { font-weight: 500; color: #43505F; border-radius: 6px; }
.mecs-body .nav-pills .nav-link:hover { background: #EDF2F7; }
.mecs-body .nav-pills .nav-link.active { background: #0072B2; color: #FFFFFF; }

/* --- tab content -------------------------------------------------------- */
.tabwrap { max-width: 1500px; margin: 0 auto; padding: 0 28px 48px; }
.tab-h { font-size: 1.6rem; font-weight: 650; color: #11212E; margin: 0 0 4px; }
.lede { font-size: 1.04rem; color: #4A5666; max-width: 58rem; margin: 0 0 22px; }
.card { margin-bottom: 22px; }

/* --- annotations -------------------------------------------------------- */
.flag { display: inline-block; font-size: 0.8rem; padding: 2px 8px;
  border-radius: 10px; margin-left: 6px; }
.flag-caution { background: #FDF0D5; color: #7A4F00; border: 1px solid #E69F00; }
.flag-gap { background: #EFF1F3; color: #4C5764; border: 1px solid #C9CDD4; }
.caveat { background: #FFFFFF; border: 1px solid #DFE4EA; border-left: 3px solid #E69F00;
  padding: 14px 18px 4px; margin-bottom: 24px; border-radius: 4px; max-width: 62rem;
  font-size: 0.93rem; color: #3D4854; }
.caveat p { margin-bottom: 10px; }
.caveat code { background: #F1F3F5; color: #8A5A00; padding: 1px 5px; border-radius: 3px; }
.modelled-banner { background: #F8F1F7; border-left: 3px solid #CC79A7;
  padding: 10px 14px; font-size: 0.92rem; color: #5F4257; margin-bottom: 22px;
  border-radius: 4px; max-width: 60rem; }
.verdict { font-size: 1.08rem; font-weight: 600; padding: 12px 16px;
  border-radius: 5px; margin-top: 4px; }
.verdict-bad  { background: #FBEAE3; color: #7D2F0E; border: 1px solid #D55E00; }
.verdict-good { background: #E4F4EE; color: #04543F; border: 1px solid #009E73; }
.smallnote { font-size: 0.88rem; color: #55606E; }
.brief { max-width: 54rem; }
.brief h1 { font-size: 1.75rem; }
.brief h2 { font-size: 1.32rem; margin-top: 1.9rem; }
.brief h3 { font-size: 1.08rem; margin-top: 1.3rem; color: #36424F; }
.brief li { margin-bottom: 0.4rem; }
.brief table { font-size: 0.95rem; }
"

masthead <- tags$header(
  class = "mecs-header",
  div(
    class = "mecs-inner",
    h1(class = "mecs-title",
       span(class = "mecs-abbr", "MECS"), " \u2014 Measles Elimination and Coverage Simulator"),
    p(class = "mecs-blurb",
      "An interactive tool for exploring how measles vaccination coverage relates to outbreak ",
      "risk in Canada, and for tracking progress back towards measles elimination status, which ",
      "Canada lost in November 2025. It is built for public health analysts, epidemiologists and ",
      "immunization program managers, using open surveillance data from the Public Health ",
      "Agency of Canada and coverage estimates from Statistics Canada."),
    div(
      class = "mecs-contact",
      div(class = "mecs-name", "Kasturi Rangarajan"),
      div("MPH Candidate, Simon Fraser University"),
      div(tags$a(href = "mailto:kasturi_rangarajan@sfu.ca", "kasturi_rangarajan@sfu.ca"))
    ),
    p(class = "mecs-foot",
      "Independent student project \u2014 not produced or endorsed by PHAC, Statistics Canada, or ",
      "any province or territory. \u00b7 PHAC surveillance data as of ", AS_OF,
      " \u00b7 Coverage estimates: Statistics Canada table 13-10-0870-01.")
  )
)

# Only jurisdictions that have reported a case this year are offered as weekly
# curve choices. The rest would draw an empty series, and the manual fill
# palette holds eight colours.
REPORTING_PTS <- by_pt$pt[!is.na(by_pt$cases_ytd) & by_pt$cases_ytd > 0]
SILENT_PTS    <- by_pt$pt[!is.na(by_pt$cases_ytd) & by_pt$cases_ytd == 0]

ui <- page_fluid(
  title = "MECS \u2014 Measles Elimination and Coverage Simulator",
  # No font_google() here: it fetches from fonts.googleapis.com when the app
  # starts, which would break the no-runtime-network guarantee and can fail
  # behind a restricted network. bslib's default system font stack is fine.
  theme = bs_theme(version = 5, primary = "#0072B2"),
  tags$head(tags$style(HTML(css))),
  masthead,

  div(
    class = "mecs-body",
    navset_pill(

      # --- Overview -------------------------------------------------------
      nav_panel(
        "Overview",
        div(class = "tabwrap",
          h2(class = "tab-h", "Where Canada stands today"),
          p(class = "lede",
            "The headline numbers from the latest weekly PHAC report, the long view since ",
            "elimination was achieved in 1998, and how far Canada has come through the ",
            "12-month clock needed to regain that status."),
          layout_column_wrap(
            width = 1/4, fill = FALSE,
            value_box(title = paste0("Confirmed cases in ", meta$report_year),
                      value = fmt_num(meta$annual_confirmed), theme = "primary",
                      p(class = "smallnote", paste0("plus ", meta$annual_probable,
                        " probable, in ", meta$annual_pt_count, " jurisdictions"))),
            value_box(title = "Active cases now",
                      value = fmt_num(meta$active_total), theme = "secondary",
                      p(class = "smallnote", meta$active_pt)),
            value_box(title = "Outbreak total since Oct 2024",
                      value = fmt_num(meta$mj_outbreak_total), theme = "secondary",
                      p(class = "smallnote", paste0("across ",
                        meta$mj_outbreak_pt_count, " jurisdictions"))),
            value_box(title = "New cases this week",
                      value = fmt_num(meta$new_confirmed), theme = "secondary",
                      p(class = "smallnote", paste0("week ", meta$report_week,
                        ", ending ", meta$week_end)))
          ),
          layout_columns(
            col_widths = c(7, 5),
            card(card_header("Confirmed cases, 1998 to present"),
                 plotOutput("plot_yearly", height = "340px"),
                 card_footer(class = "smallnote",
                   "A gap in the early years means not reported, not zero.")),
            card(card_header("The 12-month elimination clock"),
                 uiOutput("clock_ui"))
          ),
          card(card_header("Who is being infected"),
               plotOutput("plot_demo", height = "300px"),
               card_footer(class = "smallnote",
                 paste0("Confirmed and probable cases in ", meta$report_year, "."))),
          accordion(
            open = FALSE,
            accordion_panel("How the elimination clock is calculated",
                            uiOutput("clock_caveat"))
          )
        )
      ),

      # --- Surveillance ---------------------------------------------------
      nav_panel(
        "Surveillance",
        div(class = "tabwrap",
          h2(class = "tab-h", "Epidemic curves"),
          p(class = "lede",
            "Historical and recent measles case data from PHAC: the annual series back to 1998, ",
            "the current year week by week, and the year-to-date total for each jurisdiction. ",
            "Cases are plotted by when the rash began, the closest available marker of when ",
            "infection happened."),

          div(class = "caveat",
            p(strong("Reporting lag."),
              " Cases are counted by the week the rash began, but a case is only reported once it ",
              "has been seen, tested and confirmed. The most recent weeks are therefore ",
              strong("systematically incomplete"), " and will rise as late reports arrive. ",
              paste0("This report covers week ", meta$report_week, " of ", meta$report_year,
                     ", while the latest week with any rash onset reported is week ",
                     meta$latest_week_onset, "."),
              " Weeks with nothing reported yet are left out of the curve rather than drawn as ",
              "zero, so an empty week is never mistaken for a week without cases."),
            p(strong("Data suppression."),
              " PHAC withholds or rounds small counts to protect privacy, and this dashboard keeps ",
              "those gaps rather than filling them. Percentages below one are published as ",
              tags$code("<1"), " and are shown that way. Some jurisdictions' confirmed and probable ",
              "splits are not published and stay blank. Health-region case counts are blank where ",
              "numbers are small, which is why no sub-provincial map is shown here \u2014 mapping ",
              "suppressed small cells would imply precision the data does not have. Suppression ",
              "flags on the immunization coverage estimates are handled on the Simulator tab.")),

          card(
            card_header("Historical \u2014 annual confirmed cases, 1998 to present"),
            plotOutput("plot_yearly_surv", height = "340px"),
            card_footer(class = "smallnote",
              paste0("Probable cases are published separately by PHAC for 2025 and ",
                     meta$report_year, " only. For earlier years a gap means not reported, ",
                     "not zero."))),

          card(
            card_header(paste0("Recent \u2014 weekly cases by week of rash onset, ", meta$report_year)),
            layout_sidebar(
              sidebar = sidebar(
                width = 290,
                checkboxGroupInput("surv_pts", "Show these jurisdictions",
                  choices = REPORTING_PTS,
                  selected = utils::head(REPORTING_PTS, 4)),
                p(class = "smallnote",
                  paste0("Only jurisdictions with at least one case in ", meta$report_year,
                         " are listed. ", paste(SILENT_PTS, collapse = ", "),
                         " have reported none.")),
                hr(),
                radioButtons("surv_stack", "Display",
                  choices = c("Stacked together" = "stack", "Separate panels" = "facet"),
                  selected = "stack")
              ),
              plotOutput("plot_weekly", height = "420px")
            ),
            card_footer(class = "smallnote",
              paste0("PHAC publishes a weekly curve for the current reporting year only, so 2025 ",
                     "cannot be shown week by week \u2014 the annual series above carries the ",
                     "multi-year picture."))),

          card(card_header("Cases by jurisdiction, year to date"),
               plotOutput("plot_bypt", height = "340px"),
               card_footer(class = "smallnote",
                 "Zero here is an observed count, not a missing value."))
        )
      ),

      # --- Simulator ------------------------------------------------------
      nav_panel(
        "Simulator",
        div(class = "tabwrap",
          h2(class = "tab-h", "Coverage simulator"),
          p(class = "lede",
            "Move the coverage slider and watch the risk of sustained transmission change. ",
            "The sliders start at the coverage actually observed for the jurisdiction you pick."),
          div(class = "modelled-banner",
            strong("This tab is modelled. "),
            "The coverage you choose is hypothetical, and everything calculated from it is model ",
            "output. Observed coverage is shown alongside for comparison and is labelled as such."),
          layout_sidebar(
            sidebar = sidebar(
              width = 340,
              selectInput("sim_geo", "Jurisdiction", choices = GEOS, selected = "Canada"),
              selectInput("sim_age", "Age group", choices = AGES, selected = "2-year-olds"),
              uiOutput("sim_observed"),
              hr(),
              sliderInput("sim_cov", "If coverage were\u2026 (%)",
                          min = 50, max = 100, value = 92, step = 0.5),
              actionButton("sim_reset", "Reset to observed",
                           class = "btn-sm btn-outline-secondary"),
              hr(),
              sliderInput("sim_r0", "How contagious, R\u2080",
                          min = 12, max = 18, value = 15, step = 0.5),
              radioButtons("sim_ve", "Vaccine effectiveness",
                choices = c("Two doses (97%)" = "0.97", "One dose (93%)" = "0.93"),
                selected = "0.97")
            ),
            layout_columns(
              col_widths = c(6, 6),
              card(card_header("What this coverage level means"),
                   uiOutput("sim_verdict"), br(), uiOutput("sim_numbers")),
              card(card_header("Risk across every coverage level"),
                   plotOutput("plot_sim", height = "340px"))
            )
          ),
          accordion(
            open = FALSE,
            accordion_panel(
              "Observed coverage over time, and where the survey has gaps",
              plotOutput("plot_cov_trend", height = "320px"),
              p(class = "smallnote",
                "Observed data, not modelled. The survey runs every two years and does not ",
                "publish an estimate for every jurisdiction in every cycle. Cycles with no ",
                "publishable estimate are marked with a cross on the axis rather than joined ",
                "up, so a gap is never read as a value.")),
            accordion_panel("Why the target is 95%", uiOutput("sim_derivation"))
          )
        )
      ),

      # --- Equity lens ----------------------------------------------------
      nav_panel(
        "Equity lens",
        div(class = "tabwrap",
          h2(class = "tab-h", "Why a healthy average can still sustain an outbreak"),
          p(class = "lede",
            "A province can report coverage above the target and still contain communities ",
            "where measles spreads freely. This tab shows how that happens."),
          div(class = "modelled-banner",
            strong("This tab is an illustration. "),
            "Canada does not publish coverage below the provincial level, so the size and ",
            "coverage of the under-immunized community are values you choose. The provincial ",
            "average they must average out to is real. This shows a mechanism; it does not ",
            "describe any specific community."),
          layout_sidebar(
            sidebar = sidebar(
              width = 340,
              selectInput("eq_geo", "Jurisdiction", choices = GEOS, selected = "Canada"),
              selectInput("eq_age", "Age group", choices = AGES, selected = "2-year-olds"),
              uiOutput("eq_observed"),
              hr(),
              sliderInput("eq_share", "Size of that community (% of population)",
                          min = 1, max = 30, value = 8, step = 1),
              sliderInput("eq_cov", "Coverage inside it (%)",
                          min = 20, max = 95, value = 60, step = 1),
              p(class = "smallnote",
                "Coverage in the rest of the population is worked out for you, so the two ",
                "groups always average to the real provincial figure.")
            ),
            layout_columns(
              col_widths = c(6, 6),
              card(card_header("Transmission in each group"),
                   plotOutput("plot_equity", height = "330px")),
              card(card_header("What this means"), uiOutput("eq_text"))
            )
          ),
          accordion(
            open = FALSE,
            accordion_panel("What the real surveillance data shows",
                            uiOutput("eq_evidence"))
          )
        )
      ),

      # --- Policy brief ---------------------------------------------------
      nav_panel(
        "Policy brief",
        div(class = "tabwrap",
          h2(class = "tab-h", "Evidence-informed policy brief"),
          p(class = "lede",
            "A plain-language summary for decision-makers: what happened, why it happened, ",
            "and six recommendations."),
          div(class = "brief", uiOutput("brief")))
      ),

      # --- Methods --------------------------------------------------------
      nav_panel(
        "Methods & data",
        div(class = "tabwrap",
          h2(class = "tab-h", "Methods, data and limitations"),
          p(class = "lede",
            "Every parameter, assumption and limitation, written so the arithmetic can be ",
            "checked without reading the code."),
          div(class = "brief", uiOutput("methods")))
      )
    )
  )
)

# Server --------------------------------------------------------------------
server <- function(input, output, session) {

  # -- Overview -------------------------------------------------------------
  output$plot_yearly <- renderPlot(plot_yearly_cases(yearly, meta, AS_OF))
  # Same chart on the Surveillance tab, which is where "historical" belongs.
  # A Shiny output id can only be bound to one placeholder, hence the alias.
  output$plot_yearly_surv <- renderPlot(plot_yearly_cases(yearly, meta, AS_OF))

  output$clock_ui <- renderUI({
    months_done <- floor(CLOCK$months_elapsed)
    pct <- max(0, min(100, 100 * CLOCK$days_elapsed / (CLOCK$days_elapsed + CLOCK$days_remaining)))
    tagList(
      p("To regain elimination status, Canada must show that transmission of the ",
        "outbreak strain has been interrupted for ", strong("12 consecutive months"),
        ", verified by adequate surveillance."),
      div(class = "verdict verdict-bad",
          sprintf("%d of 12 months since the last outbreak-linked case", months_done),
          tags$div(style = "font-weight:400;font-size:0.86rem;margin-top:4px;",
                   paste0("as of the latest PHAC report, ",
                          format(as.Date(AS_OF), "%d %B %Y")))),
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
        strong("Our calculation, not a PHAC determination."),
        " See the panel below for how it is worked out.")
    )
  })

  output$clock_caveat <- renderUI({
    tagList(
      p("Verification of measles elimination requires interrupting transmission of the ",
        "outbreak strain for at least twelve consecutive months, demonstrated through ",
        "surveillance of sufficient quality."),
      p("This dashboard takes the most recent rash onset that PHAC links to the ",
        "multi-jurisdictional outbreak across all jurisdictions \u2014 ",
        strong(sprintf("week %d of %d in %s", last_onset_row$last_rash_onset_week,
                       last_onset_row$last_rash_onset_year, CLOCK_PROVINCE)),
        ", which ends ", strong(format(CLOCK$last_onset, "%d %B %Y")),
        " \u2014 and adds twelve months."),
      tags$ul(
        tags$li(strong("It is our calculation, not a PHAC determination"),
                " and not a decision of the regional verification commission."),
        tags$li("The published data do not confirm genotype-level linkage of every chain ",
                "of transmission."),
        tags$li("The clock resets if a new outbreak-linked case is reported."),
        tags$li("Epidemiological weeks follow the convention that week 1 contains at least ",
                "four days of the new year and weeks end on Saturday. This is validated ",
                "against PHAC's own published week dates.")
      )
    )
  })

  output$plot_demo <- renderPlot(plot_demographics(demo, meta, AS_OF))

  # -- Surveillance ---------------------------------------------------------
  output$plot_weekly <- renderPlot({
    req(length(input$surv_pts) > 0)
    p <- plot_weekly_cases(weekly, meta, AS_OF, input$surv_pts, input$surv_stack)
    shiny::validate(shiny::need(!is.null(p), "No reported cases for the selected jurisdictions."))
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
    # The figure describes a population whose immunity comes only from the
    # coverage chosen here. It is not a whole-of-Canada R_eff: it excludes
    # immunity in adults, including those born before 1970.
    scope <- tags$div(
      class = "smallnote", style = "margin-top:6px;font-weight:400;",
      "Applies to a population whose only immunity is the coverage selected ",
      "above \u2014 typically a childhood cohort. It is not a whole-population ",
      "figure: it excludes immunity from past infection and in adults born ",
      "before 1970.")
    if (s$reff >= 1) {
      div(class = "verdict verdict-bad",
        sprintf("Sustained transmission possible — Rₑff = %.2f", s$reff),
        tags$div(style = "font-weight:400;font-size:0.88rem;margin-top:4px;",
          "Each case leads to more than one further case on average, so an ",
          "introduction can grow into an outbreak rather than dying out."),
        scope)
    } else {
      div(class = "verdict verdict-good",
        sprintf("Below the threshold — Rₑff = %.2f", s$reff),
        tags$div(style = "font-weight:400;font-size:0.88rem;margin-top:4px;",
          "Introductions still cause cases, but chains of transmission die out."),
        scope)
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
    shiny::validate(shiny::need(!is.null(p), "No coverage series for this selection."))
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
    shiny::validate(shiny::need(!is.null(p), paste(
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
          "At these settings even the under-immunized community is below the threshold."),
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
