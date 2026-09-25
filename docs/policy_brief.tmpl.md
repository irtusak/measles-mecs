<!-- TEMPLATE. Do not edit docs/policy_brief.md directly: it is generated from
     this file by scripts/render_brief.R, which fills every double-brace placeholder
     from data/tidy/. Percentages are computed from PHAC's published counts
     and rounded once. Edit the wording here, then re-run the script. -->

# Getting Canada's measles elimination status back

**A plain-language brief for public health decision-makers**

Kasturi Rangarajan, Master of Public Health candidate, Simon Fraser University
Prepared 19 September 2026 · Figures as of the PHAC report of {{as_of_long}}

> This is an independent student project built with open federal data. It is not produced or endorsed by
> the Public Health Agency of Canada, Statistics Canada, or any province or territory.

---

## The short version

Canada lost its measles elimination status in November 2025, after an outbreak that began in New Brunswick
in October 2024 spread across {{mj_pt_count}} jurisdictions and caused more than six thousand cases.
Getting that status back requires one thing above all: showing that the outbreak strain has stopped
spreading in Canada for **twelve consecutive months**, backed by surveillance good enough to prove it.

As of the most recent report, the last rash onset PHAC links to the outbreak was on {{clock_last_onset}},
in {{clock_province}} — about {{clock_months}} of the twelve months. The earliest date on which a full
twelve months could be demonstrated is {{clock_verify}}, and the clock is fragile: a single new case linked
to the same chain of transmission resets it.

The deeper problem is that the conditions that allowed the outbreak have not gone away. National measles
vaccination coverage for two-year-olds was **{{cov_canada}}** in the most recent survey cycle ({{cov_year}}).
The level needed to stop measles spreading is roughly **95%**. Averages also hide the real risk: measles
finds communities where coverage is low, and it spreads there even when the province as a whole looks well
protected.

---

## What happened

Measles was declared eliminated in Canada in 1998. Elimination does not mean no cases — travellers bring
measles in most years. It means that when a case arrives, it does not establish a chain of transmission that
keeps going.

Between 1998 and 2024, Canada averaged about 90 confirmed cases a year. Then:

| Year | Confirmed cases |
|---|---|
{{year_table_rows}}

The multi-jurisdictional outbreak that began in October 2024 has accounted for **{{mj_total_fmt}} cases
across {{mj_pt_count}} jurisdictions**. Because transmission of that strain continued for more than twelve
months, Canada no longer met the definition of elimination, and the status was lost in November 2025.

The outbreak has since been declared over in most provinces. {{active_sentence}} {{new_sentence}}
PHAC's published outbreak table does not link these to the outbreak strain; if it does, the twelve-month
clock resets.

## Who is getting sick

Of the {{total_fmt}} confirmed and probable cases reported in {{report_year}}:

- **{{pct_unvax}} were unvaccinated.** Only {{pct_two_dose}} had received two or more doses.
- **{{pct_in_canada}} were infected inside Canada**, linked to known chains of transmission, rather than
  being imported.
- **{{pct_school}} were school-aged children** (5 to 17 years), and a further {{pct_under5}} were under
  five.
- **{{hosp_fmt}} people were hospitalized.** {{congen_sentence}} {{deaths_sentence}}

The pattern is not random. Measles is concentrating in people with no protection at all.

## Why 95%

Measles is among the most contagious diseases known. In a population with no immunity, one case infects
roughly twelve to eighteen others. To stop it spreading, roughly **92% to 94% of people must be immune**.

Because two doses of vaccine protect about 97% of people rather than 100%, vaccination coverage has to be
higher than the immunity target to reach it. Working it through: at the middle of that contagiousness range,
you need about **{{req_cov_mid}} coverage**; across the whole range, between roughly {{req_cov_low}} and
{{req_cov_high}}. That is where the familiar 95% target comes from. It is not a round number chosen for
convenience — it is what the arithmetic of this particular virus demands.

Canada is not there. National coverage for two-year-olds was {{cov_canada}} in the most recent cycle of the
childhood National Immunization Coverage Survey, and it has moved very little in a decade.

## Averages hide the risk

This is the part most easily missed by a national dashboard, and it is the reason the outbreak grew as it
did.

Suppose a province reports 97% coverage — comfortably above target. If 5% of that population lives in a
community where coverage is 70%, then inside that community each case leads to nearly **five** more — even
though the province as a whole sits above the level needed to stop transmission. The provincial average is
genuinely 97%. The virus does not experience the average; it experiences the community it lands in.

This is why coverage targets need to be met **locally**, not just nationally, and why the absence of
published sub-provincial coverage data is itself a surveillance gap.

## What it will take to regain elimination status

Verification requires interrupting transmission of the outbreak strain for **at least twelve consecutive
months**, demonstrated through surveillance of sufficient quality — including enough laboratory testing and
genotyping to show that new cases are unrelated importations rather than continuing chains.

Three things follow from that.

1. **The clock is the easy part to measure and the hard part to protect.** It only runs while no new
   outbreak-linked case appears. Each new case linked to the same chain restarts it.
2. **Surveillance quality is part of the test.** Regaining status is not only about case counts; it is about
   being able to demonstrate absence convincingly.
3. **Nothing about reaching twelve months fixes the underlying coverage gap.** Canada could regain
   elimination status in 2027 with coverage unchanged, and be equally vulnerable to the next importation.

---

## Recommendations

**1. Target under-immunized communities, not national averages.**
Identify where coverage is lowest at sub-provincial level and direct catch-up programs there. This means
investing in the local immunization registries needed to see those pockets in the first place. A national
average above 90% is compatible with communities well below 70%.

**2. Targeted community engagement: work with communities, not at them.**
The communities most affected by this outbreak were reached late. Engagement that involves trusted local
messengers — community leaders, family physicians, midwives, faith leaders where relevant — is slower to set
up and considerably more effective than broadcast campaigns. Fund it before the next outbreak, not during it.

**3. Close the routine-immunization gap left by the pandemic.**
Coverage for two-year-olds has not recovered. Systematic catch-up for children who missed doses in 2020–2022
addresses a known, countable deficit.

**4. Make school-entry and childcare-entry checks work.**
{{pct_school}} of {{report_year}} cases were school-aged. Existing points of contact with the health system
are the cheapest place to find and fix missed doses.

**5. Publish sub-provincial coverage.**
Public health cannot act on clustering it cannot see. Coverage should be published at health-region level
wherever cell sizes permit it, with suppression where they do not — the same standard already applied to
case data.

**6. Rebuild trust deliberately, and measure it.**
Vaccine confidence is not restored by information alone. Treat confidence as an outcome to be monitored
alongside coverage, so that falling intent is visible before it shows up as falling coverage, and falling
coverage before it shows up as an outbreak.

---

## What this brief cannot tell you

- **Coverage data is not current.** The latest machine-readable national coverage survey is from
  **{{cov_year}}**. Coverage today may be higher or lower.
- **Coverage below the provincial level is not published nationally**, so the clustering analysis in this
  dashboard is a modelled illustration of a mechanism, not a measurement of any real community.
- **Comparing provincial case counts with provincial coverage is suggestive, not causal.** Provinces differ
  in many things besides coverage.
- **The elimination clock shown here is a calculation**, derived from the last rash onset dates PHAC
  publishes. It is not a determination by PHAC or by the regional verification commission, and public data
  do not confirm genotype-level linkage of every chain.

---

## Sources

- Public Health Agency of Canada, *Measles and Rubella Weekly Monitoring Report*, data as of
  {{as_of_long}}. Contains information licensed under the Open Government Licence – Canada.
- Adapted from Statistics Canada, table 13-10-0870-01 *Vaccine coverage estimates for recommended vaccines
  in children and pregnant women* (childhood National Immunization Coverage Survey), {{cov_year}} cycle.
  This does not constitute an endorsement by Statistics Canada of this product.
- Transmission parameters: Anderson & May (1991); Guerra et al. (2017), *Lancet Infectious Diseases*.
  Vaccine effectiveness: Canadian Immunization Guide; CDC Pink Book.
- The loss of elimination status in November 2025 is not recorded in the open data files used here. It
  comes from the announcement by the Pan American Health Organization's Regional Verification Commission
  and PHAC's response to it. **Verify and cite the primary announcement before submitting this brief.**

Full methods, assumptions and limitations are in the **Methods & data** tab.
