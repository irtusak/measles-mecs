# gba.R ---------------------------------------------------------------------
# "Who is affected, and what these data cannot show": a GBA Plus reading of
# PHAC's published case demographics. Pure functions: gba_facts() reads the
# tidy demographics table and returns what PHAC published, gba_panel() turns
# that into HTML. No Shiny inputs, no file access, so tests/test_server.R can
# check both against the real data and against a table with rows missing.
#
# Everything here is descriptive. PHAC publishes sex and age as separate
# national totals; nothing is cross-tabulated, and no percentage is recomputed:
# the label PHAC publishes is the label shown (including "<1").

suppressPackageStartupMessages({ library(dplyr); library(shiny) })

# PHAC's sex categories, in the order they appear in demographics.csv.
GBA_SEX_LEVELS <- c("Male", "Female", "Other/unspecified", "Unknown")

#' What PHAC published about who the cases are.
#'
#' @param demo the tidy demographics table (characteristic, category, count,
#'   percentage_num, percentage_label).
#' @return a list: total (published case count or NA); sex, a data frame with
#'   one row per PHAC sex category, count NA and pct "not published" where the
#'   row is absent; sex_published, TRUE if at least one sex count is present;
#'   n_age_groups, the number of published age-group rows other than Unknown.
gba_facts <- function(demo) {
  stopifnot(all(c("characteristic", "category", "count", "percentage_label") %in% names(demo)))
  total <- demo$count[demo$characteristic == "Total number of cases"]
  total <- if (length(total) == 1 && !is.na(total)) total else NA_real_

  published <- demo |> filter(characteristic == "Sex")
  sex <- tibble(category = GBA_SEX_LEVELS) |>
    left_join(published |> select(category, count, percentage_label), by = "category") |>
    mutate(pct = ifelse(is.na(count), "not published", paste0(percentage_label, "%")))

  ages <- demo |> filter(characteristic == "Age group", category != "Unknown", !is.na(count))
  list(total = total, sex = sex,
       sex_published = any(!is.na(sex$count)),
       n_age_groups = nrow(ages))
}

fmt_count_g <- function(x) ifelse(is.na(x), "not published", format(x, big.mark = ","))

#' The panel shown beside the demographics chart on the Overview tab.
#' @param facts output of gba_facts(); @param report_year PHAC's reporting year.
gba_panel <- function(facts, report_year) {
  s <- facts$sex
  row <- function(cat) {
    r <- s[s$category == cat, ]
    # Built as one string: separate tag children are joined with a space,
    # which would print "Male : 609".
    tags$li(HTML(paste0("<strong>", htmltools::htmlEscape(cat), "</strong>: ",
                        fmt_count_g(r$count),
                        if (!is.na(r$count)) paste0(" (", htmltools::htmlEscape(r$pct), ")"))))
  }
  sex_lead <- if (facts$sex_published) {
    paste0("PHAC reports the ", fmt_count_g(facts$total), " cases in ", report_year,
           " by sex as follows.")
  } else {
    paste0("PHAC has not published the ", report_year, " cases by sex in this report.")
  }

  tagList(
    p(sex_lead),
    if (facts$sex_published) tags$ul(class = "gba-list", lapply(GBA_SEX_LEVELS, row)),
    p("Sex and age are published as separate national totals. Neither is broken down by the ",
      "other, by province or territory, by week, or by vaccination status, so the files ",
      "cannot say, for example, whether cases among unvaccinated children differ between ",
      "females and males, or between provinces. ",
      HTML("PHAC’s field is <strong>sex</strong>, with the four categories above; this "),
      "dashboard uses PHAC's word and does not describe gender. Statistics Canada publishes measles ",
      "coverage for all children together, not by gender, so coverage cannot be shown that ",
      "way either."),
    p(strong("Not in these data: "),
      "Gender-based Analysis Plus asks how sex and gender combine with age, disability, ",
      "education, ethnicity, economic status, geography including rurality, language, race, ",
      "religion and sexual orientation. Of these, PHAC's measles files carry sex, age group and ",
      "province or territory only. Health-region counts are withheld where small, so rurality ",
      "cannot be read from them. A factor that is missing here is not evidence that it makes no ",
      "difference."),
    p(class = "smallnote",
      "The Equity lens tab shows how uneven coverage sustains transmission. It is a modelled ",
      "illustration and does not describe any real community. ",
      tags$a(href = "https://www.canada.ca/en/women-gender-equality/gender-based-analysis-plus/what-gender-based-analysis-plus.html",
             target = "_blank", rel = "noopener", "What is GBA Plus? (Women and Gender Equality Canada)"))
  )
}
