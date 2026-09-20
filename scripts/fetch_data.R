# fetch_data.R --------------------------------------------------------------
# Downloads every raw source into data/raw/ and records what was downloaded,
# when, and its SHA-256 in data/raw/manifest.json.
#
# The Shiny app never calls this. It reads the tidy files written by
# prepare_data.R, so the dashboard makes no network requests at runtime.
#
# Usage: Rscript R/fetch_data.R

suppressPackageStartupMessages({
  library(jsonlite)
})

# Resolve the project root whether run via Rscript or sourced.
root <- tryCatch(
  normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..")),
  error = function(e) normalizePath(".")
)
if (is.na(root) || !dir.exists(file.path(root, "R"))) root <- normalizePath(".")

raw_dir <- file.path(root, "data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# PHAC Measles and Rubella Weekly Monitoring Report -------------------------
# These are the CSVs that drive PHAC's own published figures. The file list
# comes from the page's data-loader.js.
phac_base <- "https://health-infobase.canada.ca/src/data/measles-rubella/"
phac_files <- c(
  "global_variables.csv",          # headline counts, report year/week, outbreak totals
  "figure2A-EpiCurvePT.csv",       # weekly cases by province, current reporting year
  "figure3-epi-curve-yearly.csv",  # annual confirmed cases, 1998 onwards
  "geographic_distribution.csv",   # cases by province/territory, year to date
  "demographics.csv",              # age, sex, vaccination status, genotype, outcomes
  "outbreaks.csv",                 # outbreak-level detail incl. last rash onset
  "Figure3-ActiveMap.csv",         # active cases by health region
  "updateDate.csv"                 # PHAC's own "data as of" timestamp
)

# Statistics Canada 13-10-0870-01 -------------------------------------------
# PHAC childhood National Immunization Coverage Survey (cNICS) estimates,
# by province/territory, with 95% CIs and quality flags.
statcan_url <- "https://www150.statcan.gc.ca/n1/tbl/csv/13100870-eng.zip"

sha256 <- function(path) {
  # digest is not a hard dependency; fall back to shasum if absent.
  if (requireNamespace("digest", quietly = TRUE)) {
    digest::digest(file = path, algo = "sha256")
  } else {
    out <- suppressWarnings(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE, stderr = FALSE))
    if (length(out) == 1) sub(" .*$", "", out) else NA_character_
  }
}

download_one <- function(url, dest) {
  message("  downloading ", basename(dest))
  ok <- tryCatch({
    utils::download.file(url, dest, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) {
    message("    FAILED: ", conditionMessage(e))
    FALSE
  })
  if (!ok || !file.exists(dest) || file.size(dest) == 0) return(NULL)

  # PHAC serves a styled 404 page with HTTP 200 for missing files. Reject any
  # "CSV" that is actually HTML, so a silent soft-404 never reaches the app.
  if (grepl("\\.csv$", dest, ignore.case = TRUE)) {
    head_bytes <- readBin(dest, "raw", n = 200)
    if (grepl("<!DOCTYPE|<html", rawToChar(head_bytes), ignore.case = TRUE)) {
      message("    FAILED: server returned HTML, not CSV (soft 404)")
      unlink(dest)
      return(NULL)
    }
  }

  list(
    file          = basename(dest),
    url           = url,
    bytes         = as.integer(file.size(dest)),
    sha256        = sha256(dest),
    downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

message("Fetching PHAC measles and rubella surveillance files...")
records <- list()
for (f in phac_files) {
  rec <- download_one(paste0(phac_base, f), file.path(raw_dir, f))
  if (!is.null(rec)) {
    rec$source  <- "PHAC Measles and Rubella Weekly Monitoring Report"
    rec$licence <- "Open Government Licence - Canada"
    records[[length(records) + 1]] <- rec
  }
}

message("Fetching Statistics Canada cNICS coverage table...")
zip_path <- file.path(raw_dir, "13100870-eng.zip")
rec <- download_one(statcan_url, zip_path)
if (!is.null(rec)) {
  rec$source  <- "Statistics Canada table 13-10-0870-01 (PHAC cNICS)"
  rec$licence <- "Statistics Canada Open Licence"
  records[[length(records) + 1]] <- rec
  utils::unzip(zip_path, exdir = file.path(raw_dir, "cnics"))
  message("  unzipped to data/raw/cnics/")
}

manifest <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  note = paste(
    "Raw downloads for the Measles Elimination and Coverage Simulator.",
    "Independent student project; not a PHAC product."
  ),
  files = records
)
write_json(manifest, file.path(raw_dir, "manifest.json"), auto_unbox = TRUE, pretty = TRUE)

message("\nDone. ", length(records), " files in data/raw/. Manifest written.")
if (length(records) < length(phac_files) + 1) {
  message("WARNING: some downloads failed. Check the messages above before using the data.")
}
