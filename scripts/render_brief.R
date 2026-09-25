# render_brief.R ------------------------------------------------------------
# Fills docs/policy_brief.tmpl.md with figures from data/tidy/ and writes
# docs/policy_brief.md, the document the app displays and GitHub renders.
#
# Why the brief is generated: rule 1 says every number shown must come from
# data/raw/ or be computed from it. A brief with figures typed in by hand broke
# that the first week PHAC published a new report -- it said 1,038 confirmed
# cases while the data said 1,039. Rendering it from the same tidy tables the
# charts use keeps the prose and the charts in agreement, and each weekly
# refresh produces a diff showing exactly which sentences changed.
#
# Percentages are computed from PHAC's counts and rounded once here, rather
# than taken from PHAC's pre-rounded percentage column, so that a figure such
# as "under five" (two categories combined) is rounded once, not twice.
#
# Usage: Rscript scripts/render_brief.R

suppressPackageStartupMessages({ library(readr); library(dplyr); library(jsonlite) })

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")
tidy <- function(...) file.path(root, "data", "tidy", ...)
source(file.path(root, "R", "model.R"))

meta   <- fromJSON(tidy("report_meta.json"))
demo   <- read_csv(tidy("demographics.csv"),     show_col_types = FALSE)
yearly <- read_csv(tidy("cases_yearly.csv"),     show_col_types = FALSE)
outbk  <- read_csv(tidy("outbreaks.csv"),        show_col_types = FALSE)
cover  <- read_csv(tidy("coverage_measles.csv"), show_col_types = FALSE)

# Helpers --------------------------------------------------------------------
num   <- function(x) format(as.integer(x), big.mark = ",")
pct   <- function(n, d) sprintf("%d%%", as.integer(round(100 * n / d)))
longd <- function(d) format(as.Date(d), "%d %B %Y")
plural <- function(n, one, many = paste0(one, "s")) if (as.integer(n) == 1) one else many
# PHAC lists jurisdictions comma-separated; prose wants "A and B" / "A, B and C".
prose_list <- function(x) {
  x <- trimws(strsplit(as.character(x), ",")[[1]]); x <- x[nzchar(x)]
  if (length(x) <= 1) return(paste(x, collapse = ""))
  paste0(paste(head(x, -1), collapse = ", "), " and ", tail(x, 1))
}
count_of <- function(ch, cat) {
  v <- demo$count[demo$characteristic == ch & demo$category == cat]
  if (length(v) == 0 || is.na(v[1])) 0L else as.integer(v[1])
}

total     <- meta$annual_confirmed + meta$annual_probable
unvax     <- count_of("Vaccination status", "Unvaccinated")
two_dose  <- count_of("Vaccination status", "2 or more doses")
in_canada <- count_of("Exposure source", "Exposed in Canada, epidemiologically and/or virologically linked")
school    <- count_of("Age group", "5 to 17 years")
under5    <- count_of("Age group", "<1 years") + count_of("Age group", "1 to 4 years")
hosp      <- count_of("Hospitalizations", "All")
congen    <- count_of("Congenital measles cases", "Laboratory-confirmed")
deaths    <- count_of("Deaths", "All")

# Most recent published national coverage for 2-year-olds.
cov_row <- cover |> filter(geo == "Canada", age_group == "2-year-olds", !is.na(coverage)) |>
  slice_max(year, n = 1)

# Elimination clock, measured against the report date (not today).
last_onset <- outbk |> filter(!is.na(last_rash_onset_year)) |>
  arrange(desc(last_rash_onset_year), desc(last_rash_onset_week)) |> slice(1)
clock <- elimination_clock(last_onset$last_rash_onset_year, last_onset$last_rash_onset_week,
                           as_of = as.Date(substr(meta$phac_data_as_of, 1, 10)))

# Year table: the last four rows of the annual series, generated so a new
# year appears by itself each January.
yt <- yearly |> arrange(year) |> tail(4)
year_rows <- vapply(seq_len(nrow(yt)), function(i) {
  y <- yt$year[i]
  label <- if (y == meta$report_year) paste0(y, " to date") else as.character(y)
  cases <- num(yt$confirmed[i])
  if (!is.na(yt$probable[i])) cases <- paste0(cases, " (plus ", num(yt$probable[i]), " probable)")
  sprintf("| %s | %s |", label, cases)
}, character(1))

# Sentences that change shape with the number, written here so the template
# never has to say "Five cases" when the count is zero or one.
active_sentence <- if (meta$active_total == 0) {
  "No cases are currently listed as active."
} else {
  sprintf("%s case%s remain%s active, in %s, across %d health unit%s.",
          num(meta$active_total), plural(meta$active_total, ""),
          plural(meta$active_total, "s", ""), prose_list(meta$active_pt),
          meta$active_phu_count, plural(meta$active_phu_count, ""))
}
new_sentence <- if (meta$new_confirmed == 0) {
  "No new confirmed cases were reported in the latest week."
} else {
  sprintf("%d new confirmed case%s %s reported in the latest week.",
          meta$new_confirmed, plural(meta$new_confirmed, ""),
          plural(meta$new_confirmed, "was", "were"))
}
deaths_sentence <- if (deaths == 0) "No deaths were reported." else
  sprintf("%d death%s %s reported.", deaths, plural(deaths, ""), plural(deaths, "was", "were"))
congen_sentence <- if (congen == 0) "No cases of congenital measles were reported." else
  sprintf("%d %s born with congenital measles.", congen, plural(congen, "baby was", "babies were"))

vals <- list(
  as_of_long        = longd(substr(meta$phac_data_as_of, 1, 10)),
  report_year       = meta$report_year,
  total_fmt         = num(total),
  confirmed_fmt     = num(meta$annual_confirmed),
  probable_fmt      = num(meta$annual_probable),
  pt_count          = meta$annual_pt_count,
  mj_total_fmt      = num(meta$mj_outbreak_total),
  mj_pt_count       = meta$mj_outbreak_pt_count,
  active_sentence   = active_sentence,
  new_sentence      = new_sentence,
  pct_unvax         = pct(unvax, total),
  pct_two_dose      = pct(two_dose, total),
  pct_in_canada     = pct(in_canada, total),
  pct_school        = pct(school, total),
  pct_under5        = pct(under5, total),
  hosp_fmt          = num(hosp),
  deaths_sentence   = deaths_sentence,
  congen_sentence   = congen_sentence,
  cov_canada        = sprintf("%.1f%%", cov_row$coverage),
  cov_year          = cov_row$year,
  req_cov_mid       = sprintf("%.0f%%", 100 * required_coverage(15, 0.97)),
  req_cov_low       = sprintf("%.1f%%", 100 * required_coverage(12, 0.97)),
  req_cov_high      = sprintf("%.1f%%", 100 * required_coverage(18, 0.97)),
  clock_last_onset  = longd(clock$last_onset),
  clock_province    = last_onset$province,
  clock_verify      = longd(clock$earliest_verify),
  clock_months      = floor(clock$months_elapsed),
  year_table_rows   = paste(year_rows, collapse = "\n")
)

tmpl <- readLines(file.path(root, "docs", "policy_brief.tmpl.md"), warn = FALSE)
out  <- paste(tmpl, collapse = "\n")
for (k in names(vals)) out <- gsub(paste0("{{", k, "}}"), as.character(vals[[k]]), out, fixed = TRUE)

left <- regmatches(out, gregexpr("\\{\\{[a-z_0-9]+\\}\\}", out))[[1]]
if (length(left) > 0) stop("unfilled placeholders in the brief: ", paste(unique(left), collapse = ", "))

writeLines(out, file.path(root, "docs", "policy_brief.md"))
message("docs/policy_brief.md rendered: ", num(total), " cases, figures as of ", vals$as_of_long)
