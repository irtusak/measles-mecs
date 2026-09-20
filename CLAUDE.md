# MECS — Measles Elimination and Coverage Simulator: project brief for Claude Code

## What this is
An interactive R Shiny dashboard by Kasturi Rangarajan (Master of Public Health student, Simon Fraser
University) that visualises how vaccination coverage relates to measles outbreak risk, and tracks Canada's
path back to measles elimination status.

Audience: federal and provincial public health analysts, epidemiologists and immunization programme
managers — specifically PHAC staff working on restoring Canada's elimination status, lost in November 2025.
Purpose: supports a Federal Student Work Experience Program (FSWEP) application. Credibility in front of a
PHAC epidemiologist matters more than visual flash.

This is an independent student project. It is **not** a PHAC product and must say so on every page.

Kasturi is learning. When you make a methodological choice, explain it briefly in plain language in your
reply and record it in the Decision log below and in `docs/METHODS.md`.

## Non-negotiable data rules
1. Every observed number shown must come from a file in `data/raw/` (or be computed from those numbers by
   code in `R/`). Never invent, simulate, interpolate or "fill in" an observed value.
2. Modelled values are allowed *only* in the simulator and equity modules, and must be visually and
   textually labelled as modelled, never mixed into a surveillance chart.
3. Suppressed and unreliable estimates stay missing. Show gaps, never zeros.
   StatCan quality flags: `E` = use with caution (show, flagged), `F` = too unreliable to publish,
   `x` = suppressed for confidentiality, `..` = not available. `F`/`x`/`..` are gaps.
4. Blank cells in PHAC weekly files are **not zero**. Future epidemiological weeks are `NA`.
5. Keep PHAC's own caveats and wording. Confirmed and probable cases are counted separately, never silently
   summed without saying so.
6. Cite the source and download date for every dataset. Licences: Open Government Licence – Canada (PHAC)
   and the Statistics Canada Open Licence.
7. No API keys anywhere in this repo. No runtime network calls from the app — the app reads local files
   written by the fetch step.

## Model rules
- Transmission parameters come from published literature and are cited inline in `R/model.R`. They are not
  tuned to fit Canadian case counts.
- The 95% threshold is **derived, not hardcoded**: herd immunity threshold HIT = 1 − 1/R₀, and required
  coverage = HIT / vaccine effectiveness. The UI shows this derivation.
- Projections are scenarios ("if coverage were X…"), never predictions. No causal claims.
- No ad hoc p-values or "statistically significant" language.

## Tech stack
- R 4.6.1, Shiny. Packages: shiny, bslib, ggplot2, dplyr, tidyr, readr, jsonlite, markdown, scales.
- Charts: ggplot2 with the Okabe–Ito colour-blind-safe palette.
- No plotly/leaflet/sf in v1 — a health-region choropleth needs shapefiles and is deferred.

## Commands
- `Rscript scripts/fetch_data.R` downloads raw PHAC and StatCan files into `data/raw/` and writes `manifest.json`
- `Rscript scripts/prepare_data.R` parses raw files into tidy CSVs in `data/tidy/`
- `Rscript tests/test_model.R` checks the model functions against hand-computed values
- `Rscript -e 'shiny::runApp("app.R", port=7788)'` runs the dashboard

## Environment notes
- **`TAR=internal` is required for `install.packages()` on this machine.** CRAN macOS binaries are
  zstd-compressed and the sandboxed `/usr/bin/tar` cannot find a `zstd` binary (no zstd, no Homebrew).
  Without it every install fails with "Can't initialize filter; unable to run program zstd".
- **Shiny automatically sources every `.R` file in an app's `R/` directory at startup.** The data
  pipeline therefore lives in `scripts/`, not `R/`. When both were in `R/`, launching the app
  re-downloaded every file from PHAC and StatCan before serving a page. `R/` holds only pure
  app-support code (`model.R`, `theme.R`), which is safe and useful to auto-source.

## Project layout
```
scripts/fetch_data.R    downloads raw sources, writes data/raw/manifest.json
scripts/prepare_data.R  parses raw -> data/tidy/
R/model.R            transmission model functions (pure, testable, no Shiny)
R/theme.R            shared ggplot theme and Okabe-Ito palette
app.R                the Shiny application
data/raw/            untouched downloads + manifest.json
data/tidy/           parsed tables (generated)
data/SOURCES.md      every URL, what it contains, and its licence
docs/METHODS.md      methods and parameter justification
docs/policy_brief.md plain-language brief rendered in the app
tests/test_model.R   model unit checks
```

---

# Decision log

Decisions are recorded newest-last. Kasturi's decisions are marked **[K]**; methodological calls made
during the build are marked **[M]** and should be reviewed by Kasturi.

## 2026-09-19 — Project start

- **[K]** Build the Measles Elimination and Coverage Simulator (MECS) as an interactive dashboard for a
  FSWEP application. Audience: federal/provincial public health analysts, epidemiologists, immunization
  programme managers.
- **[K]** Technology stack is **R Shiny**, because R is heavily used in federal epidemiology. Iterative
  development: a simple working version showing surveillance data and basic charts first, then the
  interactive scenario sliders.
- **[K]** Three core modules: (1) Coverage Scenario Simulator with a coverage slider by province/age group
  against the 95% herd immunity threshold; (2) Real-Time Surveillance tab with PHAC epidemic curves;
  (3) Equity and Clustering Lens showing how under-immunised pockets sustain transmission despite a high
  provincial average.
- **[K]** Embed a plain-language evidence-informed policy brief covering the 12-consecutive-months
  interruption requirement for reclaiming elimination status, and recommending targeted community
  engagement to close immunisation gaps and rebuild trust.
- **[K]** Model must adhere to scientifically standard, well-established measles parameters so it is
  defensible if a PHAC epidemiologist reviews the code.
- **[K]** Build logic to handle suppressed regional data appropriately, to respect privacy.
- **[K]** Version the project with git, keep this CLAUDE.md, and record decisions throughout.
- **[K]** Use the advisor to evaluate the work regularly.

### Data source decisions

- **[M]** Surveillance data comes from PHAC's **Measles and Rubella Weekly Monitoring Report** machine-
  readable CSVs at `health-infobase.canada.ca/src/data/measles-rubella/`. These are the files that drive
  PHAC's own published figures, found by reading the page's `data-loader.js`. Eight files are pulled;
  see `data/SOURCES.md`.
- **[M]** Coverage data comes from **Statistics Canada table 13-10-0870-01** (PHAC's childhood National
  Immunization Coverage Survey, cNICS), which carries provincial/territorial estimates, 95% confidence
  intervals and quality flags. Biennial, 2011–2021; **2021 is the latest machine-readable cycle**.
- **[M]** The brief cites 2021 coverage for 2-year-olds as ranging "77% to 92%". The actual cNICS 2021
  measles figures for 2-year-olds range from **34.6% (Nunavut, flagged E — use with caution)** to
  **98.0% (Prince Edward Island)**, with Canada at **91.6%**. The dashboard uses the table values, not the
  figures in the brief. *Kasturi: worth checking where the 77–92% range came from — it may be a different
  age group or dose.*
- **[M]** "Real-time" is interpreted as **the most recent PHAC pull**, not a live connection. The app reads
  local files and displays PHAC's own `updateDate.csv` timestamp on every surveillance view, so a user
  always knows how current the data is. Re-running `scripts/fetch_data.R` refreshes it.

### Data limitation decisions

- **[M]** PHAC publishes a weekly epidemic curve for the **current reporting year only** (2026). There is no
  published weekly file for 2025. The multi-year picture therefore uses PHAC's **annual** confirmed-case
  series (1998–2026). A 2025 weekly curve is **not** reconstructed — that would mean inventing data.
- **[M]** Weeks after the current reporting week are blank in the PHAC weekly file. The "Canada" column
  reads `0` for those weeks; this is a placeholder, not an observation. Those weeks are treated as `NA` and
  the curve stops at the latest week of rash onset.

### Timeline note

- **[M]** The brief was written before **2026-09-19** (today): it targets shipping "by December or January"
  and describes the elimination loss as recent. As of the 2026-09-14 PHAC report, the 2024 multi-
  jurisdictional outbreak (CAN2024A) has been declared over in most provinces, Canada has 5 active cases in
  2 provinces, and 2026 year-to-date stands at 1,038 confirmed and 81 probable cases. The dashboard reflects
  the current situation, and treats the 12-month interruption clock as a **live computed indicator** rather
  than a static statement.
