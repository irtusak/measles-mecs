# Methods and data

Measles Elimination and Coverage Simulator (MECS)
Kasturi Rangarajan, Master of Public Health candidate, Simon Fraser University

> Independent student project built with open federal data. Not produced or endorsed by the Public Health
> Agency of Canada, Statistics Canada, or any province or territory.

This page documents every parameter, assumption and limitation in the dashboard. It is written so that a
reviewer can check the arithmetic without reading the code, and find the code quickly if they want to.

---

## 1. What is observed and what is modelled

The dashboard keeps these strictly separate.

| Tab | Status |
|---|---|
| Overview, Surveillance | **Observed only.** Every number comes from a PHAC file. |
| Coverage simulator | **Modelled**, seeded from observed coverage. Marked with a banner. |
| Equity & clustering | **Modelled illustration.** The provincial average is observed; the split is not. |

No modelled value is ever plotted on a surveillance chart, and no observed value is interpolated,
smoothed or imputed.

## 2. Data sources

Full URLs, file-by-file contents and licences are in [`data/SOURCES.md`](../data/SOURCES.md). In summary:

- **Surveillance:** PHAC *Measles and Rubella Weekly Monitoring Report*, eight machine-readable CSVs.
  These are the files behind PHAC's own published figures.
- **Coverage:** Statistics Canada table 13-10-0870-01, the PHAC childhood National Immunization Coverage
  Survey (cNICS). Biennial 2011–2021, by province and territory, with 95% confidence intervals and quality
  flags.

`scripts/fetch_data.R` records the URL, byte size, SHA-256 and download time of every file in
`data/raw/manifest.json`. The app itself makes no network requests; it reads only the tidy files written by
`scripts/prepare_data.R`.

### "Real-time" surveillance

The dashboard is not connected live to PHAC. "Real-time" here means *the most recent PHAC publication*.
Every surveillance view displays PHAC's own `updateDate.csv` timestamp so the user always knows how current
the data is. Re-running the fetch and prepare scripts refreshes it.

## 3. Handling of missing, suppressed and unreliable data

This is the part most likely to be wrong in a student dashboard, so it is handled explicitly.

### Statistics Canada quality flags

| Flag | Meaning | Treatment |
|---|---|---|
| *(blank)* | Usable estimate | Shown normally with its confidence interval |
| `E` | Use with caution | Shown, marked "use with caution", confidence interval always displayed |
| `F` | Too unreliable to be published | Gap. Never shown as a number |
| `x` | Suppressed for confidentiality | Gap, labelled "suppressed" |
| `..` | Not available for this cycle | Gap, labelled "not surveyed" |

`F`, `x` and `..` values are set to `NA` in `scripts/prepare_data.R` before anything downstream can see them,
so a suppressed cell cannot leak into a chart or an average. Of the 252 jurisdiction × age-group × cycle
combinations for measles, **80 carry a usable estimate**; the remaining 172 are gaps, mostly because cNICS
does not sample every jurisdiction in every cycle.

In the coverage trend chart, cycles with no publishable estimate are drawn as crosses on the axis rather
than being joined across. A line that skips a gap implies a measurement that does not exist.

### Blank is not zero

PHAC's weekly file lists all 53 epidemiological weeks from the start of the year. Weeks after the current
reporting week are blank for every province — but PHAC's "Canada" summary column carries a literal `0` for
those weeks. Taking that at face value would draw a long false tail of zero-case weeks.

A week is therefore treated as reported only if at least one province or territory has a non-blank value.
Later weeks are dropped, and the chart says so.

### Small cells

PHAC reports percentages below one as `<1`. The original string is kept for display, so a `<1` is never
rendered as `1`. Counts that are blank for individual jurisdictions in `outbreaks.csv` stay blank.

## 4. Transmission model

All model code is in [`R/model.R`](../R/model.R) as pure functions with no Shiny dependency, checked by
[`tests/test_model.R`](../tests/test_model.R) (36 assertions against hand-computed values).

### Parameters

| Parameter | Value | Source |
|---|---|---|
| Basic reproduction number R₀ | 12–18, default 15 | Anderson & May (1991); range used operationally by WHO and PHAC |
| Vaccine effectiveness, two doses | 97% | Canadian Immunization Guide; CDC Pink Book |
| Vaccine effectiveness, one dose | 93% | as above |

These are **not fitted to Canadian case counts**. They are the standard published values, and R₀ is exposed
as a slider so its influence on the threshold is visible rather than buried.

A note of honesty about R₀: Guerra et al. (2017, *Lancet Infectious Diseases* 17:e420–e428) systematically
reviewed measles R₀ estimates and found a far wider spread across settings than 12–18, and cautioned against
treating that range as universal. It is retained here because it is the range used in operational guidance,
and because the slider lets a reviewer test the sensitivity directly.

### Derivations

**Herd immunity threshold.** The proportion of the population that must be immune to prevent sustained
transmission:

    HIT = 1 - 1 / R₀

At R₀ = 12, 15 and 18 this gives 91.7%, 93.3% and 94.4%.

**Required vaccination coverage.** Vaccination is not perfectly protective, so coverage must exceed the
immunity threshold:

    required coverage = HIT / vaccine effectiveness

At R₀ = 15 and 97% effectiveness: 0.9333 / 0.97 = **96.2%**. Across R₀ 12–18: **94.5% to 97.4%**.

This is why the dashboard does not hardcode 95%. The widely used 95% target sits inside the band the
arithmetic produces, and showing the derivation lets a reviewer see exactly what it depends on. Note that at
R₀ = 15, one-dose effectiveness of 93% gives a required coverage above 100% — one dose alone cannot reach
the threshold, which is the quantitative case for the two-dose schedule.

**Population immunity and R_eff.**

    immunity = coverage × effectiveness
    R_eff    = R₀ × (1 - immunity)

**Outbreak consequences.** Onward transmission from a single introduction is treated as a branching process.
When R_eff < 1 the expected total number of cases, including the introduction, is `1 / (1 - R_eff)`. At or
above 1 it is unbounded, which is the formal statement of "sustained community transmission is possible".
With Poisson-distributed secondary cases, the probability that a chain dies out is the root q in (0,1) of
`q = exp(-R_eff(1-q))`, so the probability of a large outbreak is `1 - q`. Standard results; see Diekmann,
Heesterbeek & Britton (2013).

### Assumptions, stated plainly

- **Homogeneous mixing** within a population. This is the assumption the Equity & clustering tab exists to
  challenge, and it is why a single national R_eff understates real risk.
- **Coverage is used as a proxy for population immunity in the relevant age group.** It does not account for
  waning immunity, immunity from prior infection, or adults born before 1970 who are presumed immune. The
  model accepts an `other_immune` term for this, set to zero in the dashboard because there is no
  jurisdiction-level estimate to put in it.
- **Static, not dynamic.** The model gives thresholds and expected sizes, not an epidemic trajectory over
  time. It does not simulate an outbreak week by week, and it should not be read as a forecast.
- **Vaccine effectiveness is treated as constant** across ages and jurisdictions.

## 5. The clustering module

`clustered_coverage()` splits a population into an under-immunised community and the rest, and solves for
the coverage of the rest so that the weighted mean always reproduces the **observed** provincial average:

    rest coverage = (observed mean - share × community coverage) / (1 - share)

If that solution exceeds 100%, the combination is impossible and the module refuses to draw it rather than
clamping to a plausible-looking bar. Each group's R_eff is then computed independently, which assumes each
group mixes mainly within itself — the assumption that makes clustering matter.

**This is a mechanism, not a measurement.** Canada does not publish measles coverage below the provincial
level, so the size and coverage of the community are user inputs. The module does not describe any real
community, and deliberately avoids naming ethnic or religious groups.

## 6. The elimination clock

Verification of measles elimination requires interruption of transmission of the outbreak strain for at
least twelve consecutive months, demonstrated by adequate surveillance.

The dashboard computes this from `outbreaks.csv`: it takes the most recent rash onset linked to the
multi-jurisdictional outbreak across all jurisdictions, converts the epidemiological week to a date, and
adds twelve months.

**Epidemiological weeks** follow the standard convention that week 1 is the first week containing at least
four days of the new year, and weeks end on Saturday. This implementation is validated against PHAC's own
published dates: `global_variables.csv` states that week 35 of 2026 runs to 5 September 2026, and
`epi_week_end(2026, 35)` returns that date. The test suite asserts it.

**Caveats displayed alongside the clock in the app:**

- It is a calculation from published onset dates, **not a determination by PHAC** or by the regional
  verification commission.
- Public data do not confirm genotype-level linkage of every chain of transmission.
- The clock resets if a new outbreak-linked case is reported.

## 7. Known limitations

1. **Coverage data ends at 2021.** cNICS is biennial and 2021 is the latest machine-readable cycle. Current
   coverage is unknown and may differ in either direction.
2. **No sub-provincial coverage exists nationally**, which is why Module 3 is modelled.
3. **No weekly data before the current reporting year.** PHAC publishes a weekly epidemic curve for the
   current year only. The multi-year picture uses the annual series; a 2025 weekly curve is not
   reconstructed, because that would mean inventing data.
4. **Provincial case counts and provincial coverage are not causally linked** by anything in this dashboard.
   Where both are shown, the text says so explicitly.
5. **Confirmed and probable cases are counted separately** and are never silently summed.
6. **No health-region map.** A choropleth needs boundary files and careful suppression handling at small
   geographies; it is deferred rather than done badly.

## 8. Reproducing this

```bash
Rscript scripts/fetch_data.R      # download raw sources, write manifest
Rscript scripts/prepare_data.R    # parse into data/tidy/
Rscript tests/test_model.R        # 36 model assertions
Rscript tests/test_plots.R        # render every chart headlessly
Rscript -e 'shiny::runApp("app.R", port = 7788)'
```

On macOS, `install.packages()` may need `TAR=internal` if the system `tar` cannot find a `zstd` binary.
