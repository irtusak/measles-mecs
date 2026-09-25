# Publishing MECS

Two links, doing two different jobs:

| Link | What a hiring manager gets | Which CV bullets it evidences |
|---|---|---|
| **shinyapps.io** | Clicks through the live dashboard, moves the sliders | 1–5, by demonstration |
| **GitHub** | Reads the code, the 9+ commits and the decision log | 6, plus the methods behind 1–5 |

Everything below needs your accounts, so none of it has been run for you.

---

## 1. GitHub

The repository is ready: `.gitignore` is in place, the tidy data is committed so the app runs from a fresh
clone without the fetch step, and there is a LICENCE. It is about 1 MB.

**Create the repository** at <https://github.com/new>. Name it `measles-mecs`, set it to **Public**, and do
**not** let GitHub add a README, .gitignore or licence — this repository already has them.

Then, from the project directory:

```bash
git remote add origin https://github.com/<your-username>/measles-mecs.git
git branch -M main
git push -u origin main
```

If GitHub asks for a password, it wants a personal access token, not your account password: create one at
**Settings → Developer settings → Personal access tokens → Tokens (classic)** with the `repo` scope. Or
install the GitHub CLI (`brew install gh`), run `gh auth login`, and the push will just work.

**Check afterwards** that the repository front page shows the README, and that `CLAUDE.md` is visible —
that file is what makes the "maintained a decision log" claim checkable.

---

## 2. shinyapps.io

Free tier: one account, five applications, 25 active hours a month. That is comfortably enough for people
reading a CV, but the app sleeps when idle and takes a few seconds to wake.

**Set up once:**

1. Sign up at <https://www.shinyapps.io> with your SFU or GitHub account.
2. In the dashboard, go to **Account → Tokens → Show → Copy to clipboard**. It gives you a complete
   `rsconnect::setAccountInfo(...)` call with your name, token and secret.
3. Paste that call into R. It writes the credentials to your machine, once.

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(name = "<your-account>", token = "<token>", secret = "<secret>")
```

**Deploy**, from the project directory:

```r
rsconnect::deployApp(
  appName  = "measles-mecs",
  appTitle = "MECS - Measles Elimination and Coverage Simulator",
  forceUpdate = TRUE
)
```

`.rscignore` keeps `tests/` and `scripts/` out of the bundle. The app needs `app.R`, `R/`, `data/tidy/`
and `docs/` — `docs/` matters, because the Policy brief and Methods tabs read the markdown files from
there at runtime.

The raw downloads in `data/raw/` ship too. rsconnect's `.rscignore` only matches top-level entries, so a
nested path cannot be excluded — and it is worth keeping anyway: it adds about 3 MB and means the
deployed app carries the untouched source files a reviewer might want to check the tidy data against.

You can confirm what will be sent before sending it:

```r
f <- rsconnect::listBundleFiles(".")$contents
sort(f)
```

The first deploy takes several minutes while shinyapps.io builds the packages. Your URL will be
`https://<your-account>.shinyapps.io/measles-mecs/`.

**Check afterwards**, in the live app:

- the masthead shows your name and email
- the Surveillance tab renders both the historical and the weekly curve
- the Simulator sliders move and the numbers respond
- the Policy brief and Methods tabs show text, not "Document not found" (that would mean `docs/` did not
  ship)

---

## 3. Putting it on the CV

One line under the project heading:

```
Measles Elimination and Coverage Simulator (MECS)
Live demo: <your-account>.shinyapps.io/measles-mecs  |  Source: github.com/<your-username>/measles-mecs
```

---

## 4. Keeping it current, automatically

PHAC publishes the monitoring report weekly, on Mondays. Once the repository is on GitHub, the workflow in
`.github/workflows/update-data.yml` handles refreshes for you: every Tuesday it downloads the latest files,
reparses them, runs all five test suites, and commits and redeploys **only if everything passes**.

To make it redeploy as well as commit, add three repository secrets under
**Settings → Secrets and variables → Actions → New repository secret**, taking the values from the same
shinyapps.io token page as above:

| Secret | Value |
|---|---|
| `SHINYAPPS_NAME` | your shinyapps.io account name |
| `SHINYAPPS_TOKEN` | the token |
| `SHINYAPPS_SECRET` | the secret |

Without them the workflow still refreshes the repository; it just does not redeploy.

You can run it by hand at any time from the **Actions** tab → *Refresh PHAC data* → **Run workflow**. Do
that once after the first push, to confirm it works while you are watching.

**If it fails**, GitHub emails you. The usual cause is PHAC changing a file, and the failure is the point:
the deployed dashboard keeps serving the last known-good data until the pipeline is fixed.

### Refreshing by hand

```bash
Rscript scripts/fetch_data.R
Rscript scripts/prepare_data.R
Rscript tests/test_model.R && Rscript tests/test_plots.R && \
  Rscript tests/test_contrast.R && Rscript tests/test_server.R && \
  Rscript tests/test_resume_claims.R
git add -A && git commit -m "Update PHAC surveillance data to <date>" && git push
```

Then redeploy with `rsconnect::deployApp(appName = "measles-mecs", forceUpdate = TRUE)`.

Either way the masthead states the report date the figures come from, and flags it when PHAC has published
something newer, so a reader is never left guessing how current the dashboard is.
