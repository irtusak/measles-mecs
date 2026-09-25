# refresh.R -----------------------------------------------------------------
# Tells a reader whether the figures in front of them are the latest PHAC has
# published.
#
# The dashboard's data is refreshed by CI, not by the app: a scheduled workflow
# runs the fetch and prepare scripts, runs every test suite, and redeploys only
# if they all pass (see .github/workflows/update-data.yml). That way a change to
# PHAC's file format fails in CI, where Kasturi sees it, instead of failing in
# front of whoever is looking at the dashboard.
#
# The one thing the app does at runtime is read PHAC's 19-byte updateDate.csv to
# see whether a newer report exists. It never downloads the data files, it is
# wrapped so that any failure is silent, and the dashboard renders normally with
# its bundled data whether or not the check succeeds.

PHAC_UPDATE_URL <- "https://health-infobase.canada.ca/src/data/measles-rubella/updateDate.csv"

#' The date of the most recent PHAC report, or NULL if it cannot be determined.
#'
#' Deliberately total: any failure -- no network, a timeout, a redirect to
#' PHAC's styled 404 page, an unparseable value -- returns NULL rather than
#' raising, because a reader should never see an error caused by this check.
#'
#' @param timeout_sec Seconds to wait before giving up.
#' @return A Date, or NULL.
phac_published_date <- function(timeout_sec = 5) {
  old <- getOption("timeout")
  on.exit(options(timeout = old), add = TRUE)
  options(timeout = timeout_sec)

  tryCatch({
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    suppressWarnings(utils::download.file(PHAC_UPDATE_URL, tmp, mode = "wb", quiet = TRUE))
    if (!file.exists(tmp) || file.size(tmp) == 0 || file.size(tmp) > 4096) return(NULL)

    txt <- trimws(readLines(tmp, warn = FALSE)[1])
    # health-infobase answers a missing file with a styled 404 page and HTTP
    # 200, so anything that looks like markup is treated as a failure.
    if (is.na(txt) || grepl("[<>]", txt)) return(NULL)

    d <- suppressWarnings(as.Date(substr(txt, 1, 10)))
    if (is.na(d)) NULL else d
  }, error = function(e) NULL, warning = function(w) NULL)
}

#' How the freshness of the bundled data should be described.
#'
#' Pure: takes two dates and returns a status. Kept separate from the network
#' call so the wording can be tested without touching the internet.
#'
#' @param local_date Date of the bundled PHAC report.
#' @param remote_date Date PHAC currently advertises, or NULL if unknown.
#' @return A list with `status` ("current", "stale" or "unknown") and `text`.
#'   `text` is NULL when the status is unknown, because a reader is better
#'   served by silence than by a message about a failed background check.
freshness_status <- function(local_date, remote_date) {
  if (is.null(remote_date) || is.na(remote_date)) {
    return(list(status = "unknown", text = NULL))
  }
  local_date  <- as.Date(local_date)
  remote_date <- as.Date(remote_date)

  if (remote_date > local_date) {
    days <- as.integer(remote_date - local_date)
    list(
      status = "stale",
      text = sprintf(
        paste("PHAC published a newer report on %s, %d day%s after the figures shown here.",
              "This dashboard refreshes weekly."),
        format(remote_date, "%d %B %Y"), days, if (days == 1) "" else "s")
    )
  } else {
    list(status = "current",
         text = "These are the figures from the most recent PHAC report.")
  }
}
