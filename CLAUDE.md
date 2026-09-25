# MECS — Measles Elimination and Coverage Simulator: project brief for Claude Code

## What this is
An interactive R Shiny dashboard by Kasturi Rangarajan (Master of Public Health student, Simon Fraser
University) that visualises how vaccination coverage relates to measles outbreak risk, and tracks Canada's
path back to measles elimination status.

Audience: federal and provincial public health analysts, epidemiologists and immunization program
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
7. No API keys anywhere in this repo. The app reads its figures from local files written by the fetch
   step and never downloads data at runtime. **One exception, added 2026-09-24:** on startup the app
   makes a single read-only request for PHAC's 19-byte `updateDate.csv`, purely to tell the reader whether
   a newer report exists. It downloads no data files, it is wrapped so any failure is silent, and the
   dashboard is fully usable whether or not it succeeds. Refreshing the data itself is CI's job, not the
   app's — see `.github/workflows/update-data.yml`.

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
  program managers.
- **[K]** Technology stack is **R Shiny**, because R is heavily used in federal epidemiology. Iterative
  development: a simple working version showing surveillance data and basic charts first, then the
  interactive scenario sliders.
- **[K]** Three core modules: (1) Coverage Scenario Simulator with a coverage slider by province/age group
  against the 95% herd immunity threshold; (2) Real-Time Surveillance tab with PHAC epidemic curves;
  (3) Equity and Clustering Lens showing how under-immunized pockets sustain transmission despite a high
  provincial average.
- **[K]** Embed a plain-language evidence-informed policy brief covering the 12-consecutive-months
  interruption requirement for reclaiming elimination status, and recommending targeted community
  engagement to close immunization gaps and rebuild trust.
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

### Build and verification decisions

- **[M]** The dashboard is one Shiny app (`app.R`) with six tabs: Overview, Surveillance, Coverage
  simulator, Equity & clustering, Policy brief, Methods & data. The brief asked for three modules; the
  Overview and Methods tabs were added because a PHAC reader needs the headline situation up front and the
  assumptions documented in the app itself, not only in the repository.
- **[M]** Charts live in `R/plots.R` as **pure functions returning ggplot objects**, not inline in the
  server. This is what makes `tests/test_plots.R` possible: every chart is rendered headlessly against the
  real data, so a broken chart is caught without a browser. The Chrome extension was not connected in this
  environment, so headless rendering was the only way to actually *look* at the output.
- **[M]** The **elimination clock** is computed from the most recent outbreak-linked rash onset in
  `outbreaks.csv` (Manitoba, week 31 of 2026 → 8 August 2026), giving an earliest verification date of
  8 August 2027. It is labelled in the app as our calculation, not a PHAC determination, and the app states
  that public data do not confirm genotype-level linkage of every chain.
- **[M]** Epidemiological weeks use the convention that week 1 contains at least four days of the new year
  and weeks end on Saturday. This is **validated against PHAC's own published dates** — `global_variables.csv`
  says week 35 of 2026 ends 2026-09-05, and `epi_week_end(2026, 35)` returns that date. The test suite
  asserts it, so a wrong week convention cannot pass silently.
- **[M]** Colour-blind-safe Okabe–Ito palette throughout, with semantic roles defined once in `R/theme.R`.
- **[M]** The equity module deliberately does not name any ethnic or religious community. It demonstrates a
  mechanism using user-chosen inputs, and says so.

### Bugs found during the build, and what they changed

Recorded because each one would have produced a plausible-looking but wrong dashboard.

1. **17-year-olds were being silently merged into the 7-year-old group.** `grepl("7-year", x)` also matches
   `"17-year"`. The duplicate keys turned the coverage table into list-columns and `write_csv` wrote them
   as blanks, so real estimates vanished and a cycle with data was labelled "ok" with no value. Fixed by
   matching `"for 7-year-old"` with the leading space, and a uniqueness guard now **stops the pipeline** if
   keys ever collide again.
2. **The app re-downloaded every source file on startup.** Shiny auto-sources all of `R/`, which included
   the fetch script. Pipeline moved to `scripts/`.
3. **`jsonlite::validate()` masks `shiny::validate()`** because jsonlite is attached after shiny. Every
   validation message in the app failed with `is.character(txt) is not TRUE` instead of explaining the
   problem — visible only on the error paths, which is exactly when a user needs the message. All calls are
   now `shiny::validate(shiny::need(...))`.
4. **The equity chart drew an impossible "100.2% coverage" bar.** Splits that cannot average to the observed
   provincial figure are now refused, with an explanation, rather than clamped.
5. **The subscript zero in "R₀" is missing from the default plotting font** and rendered as an empty box.
   Chart text uses ASCII; the HTML interface still uses the proper glyphs, which browsers render.
6. **A NULL input took down the whole session.** `cov_lookup()` passed a zero-length value into `filter()`,
   which threw and poisoned every other output. It now returns NULL defensively.

### Testing

- `tests/test_model.R` — 36 assertions on the epidemiology against hand-computed values.
- `tests/test_plots.R` — renders all 13 charts headlessly plus 3 edge cases; PNGs land in `tests/output/`.
- `tests/test_server.R` — drives the Shiny server with `shiny::testServer` across all 42 jurisdiction ×
  age-group combinations, 18 slider-edge combinations, and both feasible and infeasible equity splits.
  276 checks. This is what caught bugs 3 and 6.

### Still open

- **[M]** No health-region choropleth. `Figure3-ActiveMap.csv` is downloaded but not yet used; a map needs
  boundary files and careful suppression handling at small geographies. Deferred rather than done badly.
- **[M]** Coverage data stops at 2021. Worth checking whether a 2023 cNICS cycle has been published in a
  form that is not in the StatCan table, and transcribing it with a citation if so.
- **[M]** The brief's "ship by December or January" timeline predates today (2026-09-19). Kasturi should
  decide whether the FSWEP framing needs updating for the current application cycle.

## 2026-09-19 — Changes made after review

- **[M]** Removed `font_google("Inter")` from `bs_theme()`. It fetched the font from
  fonts.googleapis.com **when the app started**, which contradicted rule 7 and would fail on a restricted
  federal network. Verified by clearing the font cache and relaunching: no download, and no
  `fonts.googleapis` reference in the served HTML. bslib's default system font stack is used instead.
- **[M]** The simulator verdict now states its scope. "R_eff = 1.67" computed from 2-year-old coverage is
  not a whole-of-Canada figure — it excludes immunity in adults, including those born before 1970. The
  verdict box says so, because that box is the first thing a reviewer reads. This was documented in
  METHODS but not surfaced in the interface.
- **[M]** The claim that Canada lost elimination status in November 2025 comes from the project brief, not
  from any file in `data/raw/`. It is now flagged as such in `docs/METHODS.md` and in the brief's sources.
  *Kasturi: cite the primary PAHO Regional Verification Commission / PHAC announcement before submitting.*
- **[M]** Corrected the brief: the herd immunity threshold across R₀ 12–18 is 91.7–94.4%, so it now reads
  "roughly 92% to 94%", not "93% to 94%". Also reworded an ambiguous sentence that could be read as saying
  a province was below the herd immunity threshold when the point was that it was above it.
- **[M]** The demographics chart excludes cases recorded as "Unknown" status or age. It now says how many
  cases that removes, computed from the data rather than hardcoded.
- **[M]** Doc sync: `tests/test_server.R` added to the README and METHODS command lists; chart count
  corrected.

**Verification at this point:** 36 model assertions, 16 chart renders, 276 server checks — all passing,
no warnings. App serves HTTP 200 with no network calls at startup.

## 2026-09-24 — Interface redesign

- **[K]** The dashboard opens with a large title, then a short description of what it is, then Kasturi's
  contact details (name, "MPH Candidate, Simon Fraser University", kasturi_rangarajan@sfu.ca). These three
  sit above the tabs and are present on every tab. The interface was too dense: "an overwhelming amount of
  information and it's hard to concentrate/read".
- **[M]** Moved from `page_navbar` to `page_fluid` + a masthead + `navset_pill`, so content can sit above
  the tab strip. The masthead is static and the **tab strip is sticky**, so navigation stays reachable on
  scroll without a ~150px block permanently occupying the viewport — pinning the whole masthead on scroll
  is a two-line CSS change if Kasturi wants it.
- **[M]** Density reductions: the "not a PHAC product" disclaimer and the "data as of" date now appear
  **once**, in the masthead, instead of on every tab. Each tab gets a one-sentence lede saying what it
  answers. Card footers cut to a single line, with the detail already in `docs/METHODS.md`. Four
  text-heavy blocks moved into collapsed accordions: the elimination clock caveat, the coverage-over-time
  chart, the 95% derivation, and the equity evidence.
- **[M]** Dropped "Module 1 —" / "Module 3 —" from headings; that is specification jargon, not something a
  reader needs. Tabs renamed to *Simulator* and *Equity lens*.
- **[M]** Typography: base 17px, line-height 1.55, `.smallnote` raised to 0.88rem and darkened to #55606E,
  which was below the WCAG AA contrast minimum at the previous #6E7A8A on white.
- **[M]** The weekly-curve jurisdiction list now offers only the 8 jurisdictions with at least one case
  this year, naming the 5 with none underneath. This also removes a latent crash: the manual fill palette
  holds 8 colours, so selecting 9 or more of the 13 jurisdictions would have failed with "Insufficient
  values in manual scale". `tests/test_server.R` now selects all 8 at once to hold that line.
- **[M]** Fixed `page_fluid(padding = 0, gap = 0)` — `page_fluid` takes only `...`, `title`, `theme` and
  `lang`, so those two were silently rendered as invalid HTML attributes and did nothing. Container
  padding is now handled in CSS.

**Verification:** 36 model assertions, 16 chart renders, 278 server checks, all passing, no warnings.
Masthead → contact → tab strip confirmed in that order in the served HTML, with all six tabs present.

- **[M]** *Not visually verified.* Chrome cannot reach the local Shiny app in this environment — it can
  screenshot external sites but shows an error page for `127.0.0.1:7788`, so its localhost is not the same
  as the shell's. Layout was checked structurally, not by eye. Kasturi should open it and say what still
  reads as cluttered.

## 2026-09-24 — Resume claims audited against the app

- **[K]** The project is described on Kasturi's CV in six bullets, and a hiring manager may open the
  dashboard while reading them. Every claim must therefore be true of the running app.
- **[M]** Three claims did not hold and were fixed rather than reworded:
  1. *"a surveillance tab presenting historical and recent PHAC case data"* — the historical annual series
     (1998 onward) lived only on the Overview tab. It is now the first card on Surveillance, headed
     "Historical", with the weekly curve below it headed "Recent".
  2. *"with reporting-lag ... caveats stated explicitly"* — nothing on the tab used the words. There is now
     a labelled **Reporting lag** caveat explaining that cases are counted by rash onset but reported only
     after confirmation, so recent weeks are systematically incomplete.
  3. *"and data-suppression caveats stated explicitly"* — suppression was handled for coverage data on the
     Simulator tab but never mentioned on Surveillance. A labelled **Data suppression** caveat now names
     what is actually withheld in the data shown: `<1` percentages, unpublished confirmed/probable splits,
     and blank health-region counts (which is why there is no sub-provincial map).
- **[M]** `MEASLES_PARAMS$who_target` (0.95) was defined and never used. The CV says outbreak risk is shown
  "relative to the 95% herd immunity threshold", but the chart drew only the derived requirement (96.2% at
  R₀ 15). The risk chart now draws the 95% operational target as a labelled line, so the quoted figure is
  visible next to the derived one, and the accordion explains why they differ.
- **[M]** The elimination clock measured against `Sys.Date()` while the data is a fixed snapshot, so months
  would accrue beyond what the data supports. It is now measured against the PHAC report date and labelled
  "as of the latest PHAC report".
- **[M]** Spelling moved to Canadian federal usage (`-ize`, "program"), matching the source documents —
  *National Immunization Coverage Survey*, *Canadian Immunization Guide* — and the CV itself.
- **[M]** `tests/test_resume_claims.R` locks all six bullets to the application: 27 checks that fail if a
  claim stops being true.

**Open question for Kasturi: where will the link in the resume point?** The repository has no remote and
the app runs locally. Bullet 6 ("Git version control ... decision log") is only checkable by a manager if
the repository is public. Deciding between a public GitHub repository, a hosted app (shinyapps.io), or
both needs Kasturi's accounts, so nothing has been pushed or deployed.

### Publishing

- **[K]** The dashboard will be published both as a **public GitHub repository** (so the commit history and
  this decision log are checkable, which is what CV bullet 6 claims) and as a **live app on shinyapps.io**
  (so a manager can actually use the simulator).
- **[M]** Nothing has been pushed or deployed: both need Kasturi's own accounts, and publishing is theirs to
  trigger. `docs/DEPLOY.md` has the exact steps for both, plus what to check afterwards.
- **[M]** Deployment is pre-flighted rather than assumed: `rsconnect::listBundleFiles()` confirms 29 files,
  2.7 MB, and `rsconnect::appDependencies()` detects all nine packages the app uses. `markdown` and `scales`
  are only ever called as `markdown::` and `scales::`, which rsconnect does detect.
- **[M]** `.rscignore` excludes `tests/` and `scripts/`. It cannot exclude `data/raw/` — rsconnect matches
  only top-level entries — and that is left as is deliberately: the raw downloads travel with the deployed
  app so the tidy data can be checked against them.
- **[M]** Added an MIT `LICENSE` for the code, which restates that the data carry their own Government of
  Canada licences and that this is not a PHAC product.

## 2026-09-24 — Colour and contrast

- **[K]** "The grey font is hard to read on a blue background." The colour scheme needed to be easier to
  read.
- **[M]** The cause was measured, not guessed. The four headline boxes on the Overview tab used bslib's
  themed `value_box()`, which paints a saturated fill, and the caption inside each one used `.smallnote`
  (#55606E). That is grey on #0072B2 blue: **1.23:1**, against a WCAG AA minimum of 4.5:1 — effectively
  unreadable. The three "secondary" boxes were as bad at 1.36:1.
- **[M]** Fixed by inverting the surface rather than recolouring the text: the boxes now use
  `value_box_theme(bg = "#FFFFFF", fg = "#11212E")`, a light card with dark ink (**16.4:1** for the number,
  8.2:1 for the title, 6.4:1 for the note). The category colour moved to a 4px left border, where it
  signals meaning without sitting behind any text. `value_box()` itself is kept, so bslib's layout and
  fill behaviour are untouched.
- **[M]** Colour now carries meaning on the "new cases this week" box: green when none were reported,
  amber when some were.
- **[M]** Three chart colours failed the text minimum because reference lines and their labels share a
  colour. They were darkened in `MECS_COLOURS` so the line and its label stay one thing:
  threshold #D55E00 → **#A34500** (3.87 → 6.16), safe #009E73 → **#00674C** (3.42 → 6.90), modelled
  #CC79A7 → **#9B4779** (3.06 → 5.88), neutral #6E7A8A → **#5A6472** (4.36 → 6.00), caption #77808E →
  **#5C6673** (3.99 → 5.83). Bars and fills keep the pure Okabe-Ito hues: they are large shapes, they meet
  the 3:1 graphical threshold, and every one is labelled in text as well as colour.
- **[M]** The suppression markers were nearly invisible at #C9CDD4 (1.4:1) and are now #8892A0 (3.2:1),
  which matters because those crosses are the visible evidence that a survey cycle has no publishable
  estimate.
- **[M]** The sidebar surface is pinned to #F7F9FA rather than inheriting a bslib default, so the contrast
  of the help text on it is a known quantity rather than a guess.
- **[M]** `tests/test_contrast.R` computes WCAG relative luminance in R and asserts all 32 pairs, including
  a check against the rendered HTML that no stat card ever gets a saturated fill or a `.smallnote` caption
  again.

### Page footer

- **[K]** Every tab carries a credit line at the bottom: "Built by Kasturi Rangarajan, MPH Candidate,
  Simon Fraser University. Contact: kasturi_rangarajan@sfu.ca".
- **[M]** Placed as a sibling of the tab set rather than inside any panel, so it renders once and appears
  on all six tabs. The page is a flex column with `min-height: 100vh`, so on a short tab the footer sits at
  the bottom of the window rather than floating half way up it. The email is a `mailto:` link.
  `tests/test_contrast.R` asserts it renders exactly once, sits outside every tab panel, and carries the
  name, institution and contact.

## 2026-09-24 — Weekly data refresh

- **[K]** The dashboard should update weekly, or whenever PHAC publishes new information, rather than
  being frozen at whatever was last fetched by hand.
- **[M]** **CI refreshes the data, not the app.** A scheduled GitHub Action
  (`.github/workflows/update-data.yml`) runs each Tuesday — PHAC publishes Mondays — and downloads,
  reparses, runs all five test suites, then commits and redeploys only if every suite passes.
  The alternative, an app that fetches and reparses its own data at startup, was rejected: PHAC's files do
  change (`global_variables.csv` carries its own "Removed in May 2026" and "NEW VAR (created Jan 19, 2026)"
  annotations, and `scripts/prepare_data.R` deliberately calls `stop()` on a duplicate-key guard), and a
  self-fetching app would meet the next such change **in front of a reader**. In CI the same change fails
  on a Tuesday, in Kasturi's inbox, while the deployed dashboard carries on serving the last good data.
- **[M]** The app does make one runtime request, which amends rule 7 above: a single read of PHAC's 19-byte
  `updateDate.csv` so the masthead can say whether a newer report exists. No data files are downloaded,
  `phac_published_date()` is total (any failure returns `NULL`), and `freshness_status()` is a pure
  function so the wording is tested without a network.
- **[M]** `scripts/fetch_data.R` now **fails with a non-zero exit** on a partial download instead of
  printing a warning. Unattended, a partial fetch would otherwise be committed as though it were real.
- **[M]** The Action decides whether to commit by diffing `data/tidy/` alone. `data/raw/manifest.json`
  records a fresh download timestamp every run, so keying on it would produce an empty commit every week.
- **[M]** The refresh path was exercised end to end, not just written: PHAC had in fact published a newer
  report (2026-09-21) while this work was in progress. Fetch and prepare absorbed it cleanly — week 36 now
  reported, 1,120 cases year to date, up from 1,119 — and all five suites passed on the new data. The
  dashboard now shows 21 September 2026.
- **[M]** *Note for a future change:* the elimination clock takes the most recent rash onset across **all**
  outbreak rows. That is right for "any outbreak-linked case", but if PHAC ever adds an unrelated outbreak
  with its own `outbreak_id`, the clock would start tracking that instead. Worth revisiting if a second
  outbreak appears in `outbreaks.csv`.

**Only Kasturi can finish this:** push to GitHub, then add the three `SHINYAPPS_*` repository secrets so
the Action can redeploy as well as commit. Steps are in `docs/DEPLOY.md`.
