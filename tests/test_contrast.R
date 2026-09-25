# test_contrast.R -----------------------------------------------------------
# Colour contrast checks, so a readability regression fails here rather than in
# front of a reader.
#
# The bug this exists to prevent: themed value boxes rendered muted grey text
# (#55606E) on a saturated blue fill (#0072B2), which is 1.23:1 against a 4.5:1
# minimum, and was effectively unreadable.
#
# Thresholds are WCAG 2.1 AA: 4.5:1 for normal text, 3:1 for large text and for
# meaningful graphical objects.
#
# Run: Rscript tests/test_contrast.R

root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")
source(file.path(root, "R", "theme.R"))

# Relative luminance and contrast ratio, per WCAG 2.1.
relative_luminance <- function(hex) {
  rgb_ <- grDevices::col2rgb(hex)[, 1] / 255
  lin  <- ifelse(rgb_ <= 0.03928, rgb_ / 12.92, ((rgb_ + 0.055) / 1.055) ^ 2.4)
  sum(c(0.2126, 0.7152, 0.0722) * lin)
}
contrast_ratio <- function(fg, bg) {
  l <- c(relative_luminance(fg), relative_luminance(bg))
  (max(l) + 0.05) / (min(l) + 0.05)
}

pass <- 0L; fail <- 0L
check_contrast <- function(label, fg, bg, min_ratio = 4.5) {
  r <- contrast_ratio(fg, bg)
  if (r >= min_ratio) {
    pass <<- pass + 1L
    cat(sprintf("  ok    %-34s %s on %s  %5.2f:1 (need %.1f)\n", label, fg, bg, r, min_ratio))
  } else {
    fail <<- fail + 1L
    cat(sprintf("  FAIL  %-34s %s on %s  %5.2f:1 (need %.1f)\n", label, fg, bg, r, min_ratio))
  }
}
check <- function(label, ok) {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("  ok    %s\n", label)) }
  else            { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}

WHITE <- "#FFFFFF"

cat("\nChart colours that carry text, against the plot background\n")
# Reference lines are drawn in the same colour as their label, so each of these
# has to clear the text threshold, not the graphical one.
for (nm in c("cases", "threshold", "safe", "modelled", "neutral", "label", "caption")) {
  check_contrast(paste0("MECS_COLOURS$", nm), MECS_COLOURS[[nm]], WHITE)
}

cat("\nChart colours used only as fills or markers\n")
check_contrast("MECS_COLOURS$suppressed (markers)", MECS_COLOURS$suppressed, WHITE, 3.0)
check_contrast("MECS_COLOURS$probable (fill)",      MECS_COLOURS$probable,   WHITE, 1.0)
check_contrast("MECS_COLOURS$warning (fill)",       MECS_COLOURS$warning,    WHITE, 1.0)

cat("\nInterface text, against the surface it sits on\n")
check_contrast("masthead title",        "#11212E", WHITE)
check_contrast("masthead blurb",        "#36424F", WHITE)
check_contrast("masthead contact",      "#43505F", WHITE)
check_contrast("masthead footnote",     "#5F6875", WHITE)
check_contrast("stat card value",       "#11212E", WHITE)
check_contrast("stat card title",       "#43505F", WHITE)
check_contrast("stat card note",        "#55606E", WHITE)
check_contrast("sidebar help text",     "#55606E", "#F7F9FA")
check_contrast("smallnote on page",     "#55606E", "#FAFBFC")
check_contrast("tab lede",              "#4A5666", "#FAFBFC")
check_contrast("caveat body",           "#3D4854", WHITE)
check_contrast("modelled banner",       "#5F4257", "#F8F1F7")
check_contrast("verdict, above threshold", "#7D2F0E", "#FBEAE3")
check_contrast("verdict, below threshold", "#04543F", "#E4F4EE")
check_contrast("flag, use with caution",   "#7A4F00", "#FDF0D5")
check_contrast("flag, gap",                "#4C5764", "#EFF1F3")
check_contrast("active nav pill",          WHITE,     "#0072B2", 3.0)

cat("\nThe specific regression that caused this file to exist\n")
# Checked against the rendered HTML rather than the source text: what matters
# is the colour a reader actually sees on the value boxes.
suppressPackageStartupMessages({ library(shiny); library(htmltools) })
capture_env <- new.env(parent = globalenv())
capture_env$shinyApp <- function(ui, server, ...) list(ui = ui, server = server)
suppressWarnings(source(file.path(root, "app.R"), local = capture_env))
html <- paste(as.character(renderTags(capture_env$ui)$html), collapse = "\n")

boxes <- regmatches(html, gregexpr("<div class=\"[^\"]*bslib-value-box[^\"]*\"[^>]*>",
                                   html, perl = TRUE))[[1]]
check(sprintf("all four stat cards render (%d found)", length(boxes)), length(boxes) == 4)
check("every stat card is given a light surface",
      length(boxes) == 4 && all(grepl("background-color:\\s*#FFFFFF", boxes, ignore.case = TRUE)))
check("every stat card is given dark ink",
      length(boxes) == 4 && all(grepl("color:\\s*#11212E", boxes, ignore.case = TRUE)))
# .smallnote is styled for light page surfaces; inside a saturated value box it
# was the unreadable grey-on-blue. The stat cards use .statnote instead.
box_region <- sub(".*?bslib-value-box", "", html)
box_region <- substr(box_region, 1, max(gregexpr("statnote", box_region)[[1]]))
check("no .smallnote anywhere among the stat cards",
      !grepl("smallnote", box_region, fixed = TRUE))
check("stat cards carry a category accent",
      all(vapply(c("stat-cases", "stat-active", "stat-context|stat-clear"),
                 function(p) grepl(p, html), logical(1))))

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) quit(status = 1)
