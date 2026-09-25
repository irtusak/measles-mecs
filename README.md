# MECS — Measles Elimination and Coverage Simulator

An interactive R Shiny dashboard showing how measles vaccination coverage relates to outbreak risk, and
tracking Canada's path back to measles elimination status after it was lost in November 2025.

Built for federal and provincial public health analysts, epidemiologists and immunization programme
managers.

An independent student project by Kasturi Rangarajan, Master of Public Health candidate, Simon Fraser
University. It uses open data from the Public Health Agency of Canada and Statistics Canada. **It is not
produced or endorsed by PHAC, Statistics Canada, or any province or territory.**

---

## What it does

A masthead carries the title, a short description of the tool and Kasturi's contact details above the
tabs, so they are on screen whichever tab is open. Detail that is not needed at a glance sits in collapsed
panels rather than on the page.

| Tab | What it shows |
|---|---|
| **Overview** | Current situation, the annual epidemic curve since 1998, who is being infected, and a live count of progress through the 12-month interruption requirement |
| **Surveillance** | Weekly epidemic curves by province for the current reporting year, and year-to-date cases by jurisdiction |
| **Simulator** | Move coverage, R₀ and vaccine effectiveness and watch the effective reproduction number, expected outbreak size and the derivation of the 95% target respond |
| **Equity lens** | Why a province can report coverage above target and still sustain transmission in an under-immunised community |
| **Policy brief** | A plain-language evidence-informed brief with recommendations |
| **Methods & data** | Every parameter, assumption and limitation |

## Running it

Requires R 4.x.

```bash
Rscript -e 'install.packages(c("shiny","bslib","ggplot2","dplyr","tidyr","readr","jsonlite","markdown","scales"))'

Rscript scripts/fetch_data.R      # download raw PHAC + StatCan sources
Rscript scripts/prepare_data.R    # parse into data/tidy/
Rscript -e 'shiny::runApp("app.R", port = 7788)'
```

Then open http://127.0.0.1:7788.

The tidy data is committed, so the app runs without the fetch step. Re-run fetch and prepare to update to
the latest PHAC report.

> On macOS, if `install.packages()` fails with *"Can't initialize filter; unable to run program zstd"*,
> prefix it with `TAR=internal`.

## Tests

```bash
Rscript tests/test_model.R    # 36 assertions on the transmission model
Rscript tests/test_plots.R    # renders every chart headlessly to tests/output/
Rscript tests/test_server.R   # 276 checks driving the Shiny server end to end
```

The model tests check the epidemiology against hand-computed values, including validating the
epidemiological-week function against PHAC's own published week dates. The plot tests render every chart
against the real data, so a broken chart is caught without opening a browser. The server tests drive the
reactive logic with `shiny::testServer` across every jurisdiction, age group and slider edge.

## How it is organised

```
app.R                    the Shiny application
R/model.R                transmission model — pure, testable, no Shiny
R/plots.R                chart builders — pure functions returning ggplot objects
R/theme.R                shared theme and the Okabe–Ito colour-blind-safe palette
scripts/fetch_data.R     downloads raw sources, writes data/raw/manifest.json
scripts/prepare_data.R   parses raw sources into data/tidy/
data/SOURCES.md          every URL, what it contains, and its licence
docs/METHODS.md          methods, parameters, assumptions and limitations
docs/policy_brief.md     the plain-language brief
tests/                   model assertions and headless chart rendering
CLAUDE.md                project rules and the running decision log
```

The pipeline lives in `scripts/`, not `R/`, because Shiny automatically sources every `.R` file in an app's
`R/` directory at startup — which would re-download from PHAC every time the app launched.

## Data and licences

- Public Health Agency of Canada, *Measles and Rubella Weekly Monitoring Report* — Open Government
  Licence – Canada
- Statistics Canada table 13-10-0870-01, *Vaccine coverage estimates for recommended vaccines in children
  and pregnant women* (PHAC childhood National Immunization Coverage Survey) — Statistics Canada Open
  Licence

See [`data/SOURCES.md`](data/SOURCES.md) for the full list, including known limitations of each source.

## Two things worth knowing before you read the numbers

**Suppressed data stays suppressed.** Statistics Canada quality flags are carried through to the interface:
`E` estimates are shown with a caution marker and their confidence interval, while `F`, `x` and `..` are
shown as gaps and never as numbers. Survey cycles with no publishable estimate appear as crosses on the
axis rather than being joined across.

**Modelled is labelled.** The simulator and the clustering lens produce modelled values, and say so on
every view. No modelled number is ever drawn on a surveillance chart.
