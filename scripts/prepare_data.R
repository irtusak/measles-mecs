# prepare_data.R ------------------------------------------------------------
# Parses the raw downloads into tidy CSVs in data/tidy/ that the app reads.
#
# Two rules drive everything here:
#   * blank is not zero. Future epidemiological weeks and suppressed estimates
#     stay NA, so charts show gaps rather than fabricated zeros.
#   * quality flags travel with the value they describe, so the app can render
#     a caution marker next to an unreliable estimate.
#
# Usage: Rscript R/prepare_data.R

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(jsonlite)
})

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")

raw  <- function(...) file.path(root, "data", "raw", ...)
tidy <- function(...) file.path(root, "data", "tidy", ...)
dir.create(tidy(), recursive = TRUE, showWarnings = FALSE)

message("Parsing raw sources...")

# 1. Report metadata --------------------------------------------------------
# global_variables.csv is a long key/value table driving PHAC's own headline
# numbers. We keep it as a named list so the app can quote PHAC's figures
# directly rather than recomputing them.
gv <- read_csv(raw("global_variables.csv"), show_col_types = FALSE)
gv_val <- function(name) {
  v <- gv$Value[gv$`Variable name` == name]
  if (length(v) == 0 || is.na(v[1])) NA_character_ else as.character(v[1])
}

update_stamp <- trimws(readLines(raw("updateDate.csv"), warn = FALSE)[1])

meta <- list(
  phac_data_as_of       = update_stamp,
  report_year           = as.integer(gv_val("report_year")),
  report_week           = as.integer(gv_val("report_week")),
  week_start            = gv_val("week_start"),
  week_end              = gv_val("week_end"),
  latest_week_onset     = as.integer(gv_val("measles_latest_week_onset")),
  annual_confirmed      = as.integer(gv_val("measles_annual_confirm")),
  annual_probable       = as.integer(gv_val("measles_annual_probable")),
  annual_pt_count       = as.integer(gv_val("measles_annual_pt_count")),
  new_confirmed         = as.integer(gv_val("measles_new_confirm")),
  new_probable          = as.integer(gv_val("measles_new_probable")),
  active_total          = as.integer(gv_val("measles_active_total")),
  active_pt             = gv_val("measles_active_pt"),
  active_phu_count      = as.integer(gv_val("measles_active_phu_count")),
  mj_outbreak_total     = as.integer(gv_val("measles_MJoutbreak_total")),
  mj_outbreak_confirmed = as.integer(gv_val("measles_MJoutbreak_confirmed")),
  mj_outbreak_probable  = as.integer(gv_val("measles_MJoutbreak_probable")),
  mj_outbreak_pt_count  = as.integer(gv_val("measles_MJoutbreak_pt_count")),
  rubella_annual        = as.integer(gv_val("rubella_annual_confirm")),
  crs_annual            = as.integer(gv_val("crs_annual_confirm")),
  retrieved_at          = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)
write_json(meta, tidy("report_meta.json"), auto_unbox = TRUE, pretty = TRUE)
message("  report_meta.json  (PHAC data as of ", update_stamp, ")")

# 2. Annual epidemic curve --------------------------------------------------
# 1998 onwards. Confirmed and probable are kept as separate columns: PHAC
# reports probable cases only for 2025 and 2026, and summing them silently
# would misrepresent the earlier years.
yearly_raw <- read_csv(raw("figure3-epi-curve-yearly.csv"), show_col_types = FALSE)

yearly <- yearly_raw |>
  filter(!is.na(suppressWarnings(as.integer(Year)))) |>
  mutate(year = as.integer(Year), value = as.numeric(Value)) |>
  select(year, Category, value) |>
  pivot_wider(names_from = Category, values_from = value) |>
  rename(confirmed = `Number of confirmed cases`)

# PHAC reports probable cases only for the most recent years. Keep the column
# separate from confirmed so earlier years read as "not reported", not zero.
if (!"Number of probable cases" %in% names(yearly)) yearly$`Number of probable cases` <- NA_real_

yearly <- yearly |>
  rename(probable = `Number of probable cases`) |>
  select(year, confirmed, probable) |>
  arrange(year)

write_csv(yearly, tidy("cases_yearly.csv"))
message("  cases_yearly.csv  (", min(yearly$year), "-", max(yearly$year), ", ",
        nrow(yearly), " years)")

# 3. Weekly epidemic curve by province, current reporting year --------------
# Column names are "48: Alberta" style. The TOTAL row is a summary and is
# dropped. Weeks with no reported value in any province are future weeks and
# are removed entirely rather than being plotted as zero -- note that PHAC's
# own "Canada" column carries a literal 0 for those future weeks.
wk_raw <- read_csv(raw("figure2A-EpiCurvePT.csv"), show_col_types = FALSE,
                   na = c("", "NA"))
week_col <- names(wk_raw)[1]

wk <- wk_raw |>
  filter(.data[[week_col]] != "TOTAL") |>
  mutate(week = as.integer(.data[[week_col]])) |>
  select(-all_of(week_col)) |>
  pivot_longer(-week, names_to = "pt_label", values_to = "cases") |>
  mutate(
    pruid = sub(":.*$", "", pt_label),
    pt    = trimws(sub("^[^:]*:", "", pt_label))
  ) |>
  select(week, pruid, pt, cases)

# A week counts as reported only if at least one province reported a value.
reported_weeks <- wk |>
  filter(pt != "Canada") |>
  group_by(week) |>
  summarise(any_reported = any(!is.na(cases)), .groups = "drop") |>
  filter(any_reported) |>
  pull(week)

wk <- wk |> filter(week %in% reported_weeks)
write_csv(wk, tidy("cases_weekly_pt.csv"))
message("  cases_weekly_pt.csv  (weeks ", min(wk$week), "-", max(wk$week),
        " of ", meta$report_year, "; weeks ", max(wk$week) + 1,
        "+ dropped as not yet reported)")

# 4. Cases by province, year to date ----------------------------------------
geo <- read_csv(raw("geographic_distribution.csv"), show_col_types = FALSE) |>
  select(pruid, pt = pt_name, cases_ytd = num_cases,
         new_cases = num_new_cases, last_onset_week = last_onset_epi_week) |>
  arrange(desc(cases_ytd))
write_csv(geo, tidy("cases_by_pt.csv"))
message("  cases_by_pt.csv  (", sum(geo$cases_ytd, na.rm = TRUE), " cases year to date)")

# 5. Case demographics ------------------------------------------------------
# percentage arrives as "<1" for small cells; keep the original string for
# display and a numeric column for charting, so a "<1" is never shown as 1.
demo <- read_csv(raw("demographics.csv"), show_col_types = FALSE) |>
  select(characteristic = case_characteristics, category, count, percentage) |>
  mutate(
    percentage_label = as.character(percentage),
    percentage_num   = suppressWarnings(as.numeric(percentage)),
    count            = suppressWarnings(as.integer(count))
  ) |>
  select(characteristic, category, count, percentage_num, percentage_label)
write_csv(demo, tidy("demographics.csv"))
message("  demographics.csv  (", nrow(demo), " rows)")

# 6. Outbreaks --------------------------------------------------------------
# Drives the elimination clock: last_rash_onset_year / _week give the most
# recent onset linked to each outbreak in each jurisdiction.
ob <- read_csv(raw("outbreaks.csv"), show_col_types = FALSE) |>
  select(outbreak_id, outbreak_type, outbreak_string, date_start, date_end,
         province, total_cases, confirmed_cases, probable_cases,
         last_rash_onset_year, last_rash_onset_week, description_en)
write_csv(ob, tidy("outbreaks.csv"))
message("  outbreaks.csv  (", nrow(ob), " outbreak-jurisdiction rows)")

# 7. Immunization coverage (cNICS) ------------------------------------------
# StatCan quality flags decide what the app may show:
#   ""  usable        E  use with caution (shown, flagged)
#   F   too unreliable to publish     x  suppressed for confidentiality
#   ..  not available
# F, x and .. are gaps. They are kept as rows with value NA so the app can say
# "suppressed" rather than silently dropping a province.
cn_path <- raw("cnics", "13100870.csv")
cn <- read_csv(cn_path, show_col_types = FALSE, na = character()) |>
  filter(`Antigen or vaccine` == "Measles", Sex == "Total - Gender")

# Match the space before the number: "7-year" on its own also matches
# "1|7-year", which would collapse 17-year-olds into the 7-year-old group.
age_of <- function(x) {
  dplyr::case_when(
    grepl("for 2-year-old",  x, fixed = TRUE) ~ "2-year-olds",
    grepl("for 7-year-old",  x, fixed = TRUE) ~ "7-year-olds",
    grepl("for 17-year-old", x, fixed = TRUE) ~ "17-year-olds",
    TRUE ~ NA_character_
  )
}
char_of <- function(x) {
  dplyr::case_when(
    x == "Percentage vaccinated" ~ "coverage",
    grepl("^Low",  x)            ~ "ci_low",
    grepl("^High", x)            ~ "ci_high",
    TRUE ~ NA_character_
  )
}

cov <- cn |>
  mutate(
    year      = as.integer(REF_DATE),
    geo       = GEO,
    age_group = age_of(`Target population`),
    metric    = char_of(Characteristics),
    value     = suppressWarnings(as.numeric(VALUE)),
    status    = STATUS
  ) |>
  filter(!is.na(age_group), !is.na(metric)) |>
  select(year, geo, age_group, metric, value, status)

# Suppressed or unpublishable estimates must not carry a number through.
cov <- cov |> mutate(value = ifelse(status %in% c("F", "x", ".."), NA_real_, value))

# Guard: a duplicated key here means the age-group or metric mapping has
# collapsed two different series together, which pivot_wider would quietly
# turn into list-columns and write_csv would render as blanks.
dupes <- cov |> count(year, geo, age_group, metric) |> filter(n > 1)
if (nrow(dupes) > 0) {
  stop("coverage keys are not unique -- check age_of()/char_of(). Example: ",
       paste(utils::head(dupes, 1), collapse = " "))
}

coverage <- cov |>
  select(-status) |>
  pivot_wider(names_from = metric, values_from = value) |>
  left_join(
    cov |> filter(metric == "coverage") |> select(year, geo, age_group, status),
    by = c("year", "geo", "age_group")
  ) |>
  mutate(
    quality = dplyr::case_when(
      status == ""   ~ "ok",
      status == "E"  ~ "caution",
      status == "F"  ~ "unreliable",
      status == "x"  ~ "suppressed",
      status == ".." ~ "not_available",
      TRUE ~ "unknown"
    )
  ) |>
  select(year, geo, age_group, coverage, ci_low, ci_high, quality) |>
  arrange(geo, age_group, year)

write_csv(coverage, tidy("coverage_measles.csv"))
usable <- sum(coverage$quality %in% c("ok", "caution") & !is.na(coverage$coverage))
message("  coverage_measles.csv  (", nrow(coverage), " rows, ", usable,
        " with a usable estimate; ", nrow(coverage) - usable, " suppressed or unavailable)")

message("\nDone. Tidy files written to data/tidy/.")
