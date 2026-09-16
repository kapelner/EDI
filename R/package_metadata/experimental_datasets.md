# Real experimental datasets for EDI's comprehensive test/simulation database

Sourced 2026-09-14 for the planned expansion of `R/package_tests/comprehensive_tests.R`'s
dataset registry (`_dataset_load.R`) beyond its existing 14 public ML-benchmark
covariate sources (Pima, Breast Cancer Wisconsin, Sonar, Soybean, Diamonds,
Boston, Cars93, Ionosphere, Abalone, FuelEconomy, iris, airquality, glass,
pte_example). Those 14 supply realistic covariate structure with *synthetic*
treatment assignment and response (known ground truth, needed for coverage/
power validation). The datasets below are **real completed experiments** —
real observed assignment, real observed outcomes — added for capabilities the
synthetic-response approach cannot provide: replaying genuine documented
randomization mechanisms, and real case-study validation against a published
trial.

Three intended usage modes (not mutually exclusive):
1. **Covariate-source only** — real baseline covariates, synthetic response
   with known truth. Same pattern as the existing 14 datasets.
2. **Real assignment replay** — real covariates *and* real observed
   assignment, synthetic response with known truth. Validates inference
   against an actual realized randomization, not an idealized one.
3. **Full real replay** — real covariates, real assignment, real outcome, no
   synthetic component. No known ground truth (can't validate coverage), but
   produces genuine case-study evidence. Does not fit the same
   replicate-based simulation structure as modes 1–2 (one evaluation per
   trial, not a Monte Carlo loop).

`IVdataset` (Angrist & Krueger 1991) was evaluated and **excluded**: it is
observational census data analyzed via an instrumental-variable strategy
(quarter-of-birth as instrument for schooling), not a randomized experiment
— no real `W` exists to replay.

## Required R packages: none

**No dataset in this table -- Core or Expanded, all 262 rows -- requires
`install.packages()` of anything.** Every one is fetched by
`download_experimental_datasets.R` install-free: CRAN-sourced datasets
(Core and Expanded alike) via `cran_download_dataset_as_csv()`, which
downloads just the package's source tarball and reads the one needed
`data/*` object directly (`load()`/`fread()` don't care whether the
surrounding package is actually installed); the handful of GitHub-only
Core datasets via `github_download_dataset_as_csv()`, which downloads the
repo's tarball at a pinned commit the same way, no `devtools::
install_github()` needed. See "Downloading everything" below for the full
mechanism list.

Notes on packages that looked like they should be on CRAN but are not:
- **`lalonde`** as a standalone package name does not exist on CRAN (GitHub-
  only, `jjchern/lalonde`). The LaLonde NSW data used here comes from the
  CRAN `qte` package instead (`lalonde.exp`), which keeps the experimental
  and observational (PSID) comparison arms as separate, clearly labeled
  data frames.
- **`experimentdatar`** (charitable, mobilization, social, secrecy,
  vouchers, welfare) is GitHub-only, pinned at commit `f71a9d0`; there is
  no CRAN fallback for it. Its GitHub-tarball structure is close enough to
  the CRAN one (a `data/*.rda` directory) that the same install-free
  approach applies, just against `github.com/<repo>/archive/<sha>.tar.gz`
  instead of `cran.r-project.org/src/contrib/`.

## Downloading everything: `R/package_metadata/download_experimental_datasets.R`

**This one script downloads and normalizes every dataset in the table
below, Core and Expanded tier alike (262 datasets total), through four
mechanisms, all without vendoring any raw data into the repo and without
`install.packages()`-ing anything:** CRAN packages fetched by source
tarball only (`cran_download_dataset_as_csv()` — download the tarball,
extract just the one needed `data/*` object, convert to CSV, discard
everything else; the large majority of the table, Core and Expanded
alike), GitHub-only packages fetched the same tarball-only way at a
pinned commit (`github_download_dataset_as_csv()`, the 6 Core-tier
`experimentdatar` datasets), Harvard Dataverse (guestbook or direct
download, the 15 original Dataverse-sourced Expanded entries), and a
handful of legacy ICPSR-proper downloads. Clone the repo, optionally set
guestbook-identity options (see below — sensible defaults exist, so this
is optional), and run:

```r
Rscript R/package_metadata/download_experimental_datasets.R
```

or, sourced interactively, to fetch a subset:

```r
source("R/package_metadata/download_experimental_datasets.R")
download_all_datasets(datasets = c("sanitation", "student_test_data"))
```

**Every downloaded file is normalized to plain CSV** (`.tab` retabbed,
`.dta` read via `haven` and stripped of value/variable labels via
`zap_labels()`, zip-bundled/CRAN-tarball files extracted and the target
member located directly, `.rda`/`.RData` loaded and coerced to a plain
data frame) — uniform format, and compressed CSV text is small, so this
keeps disk usage low compared to a mix of `.zip`/`.tab`/`.dta`/`.rda`/
`.csv` files sitting loose (two of the Dataverse source zips alone are
99MB and 221MB; only one small member file is kept from each, the rest
is discarded after conversion). **Each dataset is packed into its own
`R/package_metadata/randomized_experiment_datasets/<name>.tar.bz2`** —
one archive per table row, not one combined archive for the whole
collection, so a consumer that wants a single dataset extracts only
that one file, and "already downloaded" is a plain existence check on
`<name>.tar.bz2` (no extraction needed to resume a partial run). By
default the loose CSV is deleted right after its archive is written;
call `extract_experimental_datasets("<name>")` to unpack it again when
you actually need to read it.

The CRAN package `icpsrdata` was evaluated and **dropped from the plan**:
it's confirmed broken, unfixable by credential/option changes. It POSTs to
a hardcoded `http://www.icpsr.umich.edu/cgi-bin/bob/zipcart2?...` URL —
plain HTTP, a legacy CGI-bin path. ICPSR has since moved to a
Keycloak-based OAuth/OIDC login (`login.*.icpsr.umich.edu/realms/icpsr/...`),
a structurally different flow the old package cannot perform at all. It
is not listed in "Required R packages" above and should not be installed
for this purpose.

`download_experimental_datasets.R` implements **four distinct mechanisms**, used per
dataset:

1. **CRAN source tarball, no install** (`cran_download_dataset_as_csv()`)
   — this script's primary mechanism, used by both tiers: 21 of the 32
   Core-tier entries (everything except the 6 GitHub-only ones and the
   Dataverse-sourced ones below), plus 218 of the 234 Expanded-tier
   manifest entries as of the round-5 exhaustive sweep. Downloads
   just the package's `.tar.gz` from CRAN (no `install.packages()`, no
   dependency resolution, no compilation), extracts only the one needed
   `data/*.rda`/`.txt` object, and `load()`s/`fread()`s it directly — R's
   data-loading doesn't care whether the surrounding package is actually
   installed. Two extra parameters handle packages that bundle several
   datasets together: `obj_name` picks one top-level object out of an
   `.rda` file that `load()`s several at once (e.g. `survival`'s
   `data/cancer.rda` holds 21 datasets including `veteran`/`ovarian`/
   `colon`/`bladder1`), and `list_element` picks one data frame out of a
   single loaded object that is itself a named list of tables (e.g.
   `stevedata::mm_randhie` loads as a list with a "RAND Outcomes" table).
   **Version fallback, confirmed necessary in practice:** the exact CRAN
   version recorded for a dataset (captured by whichever review pass
   checked it, across a multi-hour sweep) is often no longer CRAN's
   current release by the time this runs — CRAN keeps only the current
   version at the plain `src/contrib/` URL, moving anything superseded to
   `src/contrib/Archive/<pkg>/`. The function tries the pinned version's
   direct URL first, falls back to the `Archive/` copy of that exact
   version, and falls back to whatever is current on CRAN right now as a
   last resort (logged, not silent) — safe because a package that exists
   mainly to ship one classic dataset essentially never changes that
   dataset's content across version bumps.
2. **GitHub source tarball at a pinned commit, no install**
   (`github_download_dataset_as_csv()`) — the 6 Core-tier `experimentdatar`
   datasets (charitable/mobilization/social/secrecy/vouchers/welfare),
   which are GitHub-only with no CRAN release. Downloads
   `https://github.com/<repo>/archive/<commit_sha>.tar.gz` (note: GitHub's
   tarball extracts to `<repo>-<sha>/`, not `<repo>/`), then the same
   `data/*.rda` extraction as mechanism 1. No `devtools::
   install_github()` involved.
3. **Harvard Dataverse guestbook/direct download** — confirmed working
   end-to-end 2026-09-14/15, and what the original 15 Dataverse-sourced
   entries use. No ICPSR account or login of any kind: Dataverse's own
   "Guestbook" (a usage-tracking questionnaire some depositors require,
   unrelated to the file's license) is satisfied with plain identity
   fields, not credentials. Functions: `dataverse_dataset_files()`,
   `dataverse_download_file()`, `dataverse_download_by_filename()`,
   `download_zip_member_as_csv()`. See the script's own header comment
   for the exact request/response shape, including a real gotcha found
   2026-09-15: guestbook "options"-type answers must be submitted as the
   option's **string text**, not its numeric id — the numeric form looks
   plausible but 500s server-side with an opaque `ClassCastException`.
4. **Classic ICPSR archive proper** (`icpsr_download_simple()`, kept for
   any future dataset that's on ICPSR but has no Dataverse mirror — none
   currently in the manifest need it). **Known limitation, not yet proven
   reliable end-to-end:** diagnosed and fixed two real bugs versus the
   reference implementation this was translated from
   (github.com/Xarthisius/openicpsr) — it targeted `test.openicpsr.org` /
   `login.uat.icpsr.umich.edu` (staging hosts that 403 with no login logic
   involved), corrected here to `www.openicpsr.org`; and the site also
   403s any request missing realistic browser headers, also fixed. But
   the corrected script got past step 1 once (HTTP 200), then 403'd on an
   identical retry minutes later — indicative of bot-detection/
   rate-limiting rather than a remaining URL/header bug. Prefer a
   Dataverse mirror when one exists; a manual browser download from
   icpsr.umich.edu remains the fallback for any file that only lives on
   ICPSR proper.

**Where credentials go: your personal `~/.Rprofile` (home directory),
never this repo.** Only mechanism 2 (classic ICPSR) needs any secret —
mechanism 1 (Dataverse guestbook, everything actually in the manifest)
needs no account and no secret, just identity fields (see
`dataverse_guestbook_identity()` in the script; override via
`options("dataverse_guestbook_name"/"dataverse_guestbook_email"/
"dataverse_guestbook_institution")` if you're not Adam Kapelner). For
mechanism 2, `.Rprofile` in `$HOME` is sourced automatically at the start
of every R session, is not part of any git working tree, and is never at
risk of being committed or pushed. Add one line:

```r
options("icpsr_email" = "your_email@example.com", "icpsr_password" = "your_password")
```

**Do not** put credentials in any file under this repository (not in a
`.Rprofile` at the repo root, not in `_dataset_load.R`, not in this
document, not in `download_experimental_datasets.R` itself) — anything in the working
tree can end up in a commit even with good intentions, and ICPSR
credentials have no business in version control.

## Licensing note: ICPSR/openICPSR data must not be bundled/shipped

**Do not vendor raw ICPSR or openICPSR data files into this repo or the
shipped EDI package.** Checked 2026-09-14: classic ICPSR archive terms of
use prohibit redistribution without ICPSR's written agreement (and
possibly a fee) — explicitly covering inclusion "in a new data product,"
which is what shipping it as package data would be. openICPSR is
different but not uniformly safer: depositors choose a per-dataset license
(often CC-BY 4.0, which does permit redistribution with attribution, but
sometimes other terms), so nothing from there should be assumed
redistributable without checking that specific dataset's license page.

The safe pattern, matching how `_dataset_load.R` already works for the
non-experimental sources (pulled live from installed packages, never
vendored as a static copy): fetch ICPSR/openICPSR data **at test/run time**
via `download_experimental_datasets.R`, under the researcher's own account, and keep the
download directory `.gitignore`d so a fetched file never lands in a public
commit — that would itself be redistribution, independent of whether it
ends up in the CRAN-shipped tarball. All of the CRAN/GitHub-packaged
datasets in the table below (`survival`, `medicaldata`, `qte`, `AER`,
`stevedata`, `experimentdatar`) are unaffected by this note — they're
already published specifically as reusable R data packages under their
own stated licenses, not something being newly redistributed by EDI.

## Dataverse guestbook downloads — a separate, working mechanism

Some J-PAL/openICPSR/IPA studies on Harvard Dataverse require a one-time
"Guestbook" response (name/position/intended-use) before a file can be
downloaded — this is a usage-tracking requirement from the depositor, not
a license restriction (the license itself, e.g. CC0, is unaffected).
**Confirmed working end-to-end 2026-09-14/15**, unlike the still-unreliable
ICPSR OAuth flow documented above — this is now `download_experimental_datasets.R`'s
primary mechanism (see "Downloading everything" above), not a separate
manual procedure:

1. `GET https://dataverse.harvard.edu/api/guestbooks/{guestbookId}` — read
   the required fields and any custom questions (multiple-choice options
   included) without submitting anything.
2. `POST https://dataverse.harvard.edu/api/access/datafile/{fileId}` with
   a JSON body `{"guestbookResponse": {"name":..., "email":...,
   "institution":..., "position":..., "answers":[{"id":Q_ID,"value":...}]}}`
   — returns `{"data":{"signedUrl": "..."}}`, not the file itself.
   **Gotcha found 2026-09-15:** for an "options"-type custom question,
   `value` must be the option's **string text**, not its numeric id — the
   numeric form looks plausible (an `id` field elsewhere in the same
   payload does take a number) but 500s server-side with an opaque
   `ClassCastException`. Also, a dataset's guestbook can require more than
   one custom question (the IPA guestbook, id 80, requires five, plus a
   non-empty email and institution) — check
   `GET /api/guestbooks/{guestbookId}` for the *complete* required set
   before assuming a single-question payload will be accepted.
3. The resulting signed URL (or, for a file with no guestbook requirement,
   the plain `GET /api/access/datafile/{fileId}` URL directly) responds
   with an **HTTP 303 redirect** to a short-lived, pre-signed S3 URL —
   follow it promptly (`httr2::req_perform()` follows redirects by
   default; a bare `curl` needs `-L`) to get the actual file bytes.

This is unrelated to `download_experimental_datasets.R`'s ICPSR-proper OAuth flow (a
different site, different auth mechanism entirely) — this pattern is used
for every Harvard-Dataverse-hosted (including J-PAL/IPA/openICPSR) file in
the manifest, and the other mechanism is kept only for a hypothetical
future dataset that's on classic ICPSR with no Dataverse mirror.

## Dataset table

`p` = baseline covariates only (treatment, outcome, and ID columns
excluded). `~` marks a count that required judgment calls about column
purpose (e.g. multi-wave panel data, or datasets with many derived
indicator/fixed-effect columns) rather than an unambiguous count.

**Design column**: the actual documented randomization scheme where known
with reasonable confidence; otherwise labeled `Unknown; assumed BCRD` or
`Unknown; assumed Bernoulli`, per the rule: **roughly equal arm sizes →
assume balanced/fixed randomization (BCRD); unequal arm sizes → assume
independent Bernoulli draws**, checked against real computed arm counts
from the actual data wherever it was already loaded this session (not
guessed).

Pinning rule: **CRAN packages → installed package version; the GitHub-only
package (`experimentdatar`) → installed commit SHA, not its meaningless
static `0.0.0.9000` dev-version placeholder; Dataverse datasets → DOI +
Dataverse version number.** All checked against what's actually installed/
fetched this session (2026-09-14), not assumed.

| Tier | Dataset | Source | Version | License | n | p (covariates) | tx (treatment column) | Response Variable | Response Type | Design | Description |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Core | `veteran` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 137 | 5 | `trt` | `time`/`status` | survival | Unknown; arms 69/68 ≈ equal → assumed BCRD | VA Lung Cancer trial |
| Core | `ovarian` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 26 | 3 | `rx` | `futime`/`fustat` | survival | Unknown; arms 13/13 exact → assumed BCRD | ovarian cancer trial |
| Core | `colon` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 1,858 | 10 | `rx` | `time`/`status` (`etype`) | survival + incidence | Unknown; 3 arms 315/310/304 ≈ equal → assumed BCRD | colon cancer adjuvant chemo trial; recurrence gives an incidence endpoint alongside death |
| Core | `pbc` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 418 | 16 | `trt` | `time`/`status` | survival | Unknown; arms 158/154 ≈ equal → assumed BCRD | Mayo Clinic D-penicillamine trial for primary biliary cirrhosis |
| Core | `respdis` | CRAN: geepack | 1.3.13 | GPL (>= 3) | 111 | 0 | `trt` | `y1`–`y4` | ordinal (3-level) | Unknown; arms 57/54 ≈ equal → assumed BCRD | randomized respiratory-disorder trial (poor/good/excellent), no baseline covariates recorded |
| Core | `respiratory` | CRAN: geepack | 1.3.13 | GPL (>= 3) | 111 (444 obs) | ~4 | `treat` | `outcome` | incidence | Unknown, possibly stratified by clinical center (data carries a `center` field); arms 27/29 ≈ equal → assumed BCRD | same respiratory trial family, binary good/poor version |
| Core | `strep_tb` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 107 | 6 | `arm` | `radiologic_6m`/`rad_num`/`improved` | ordinal (6-level) + incidence | **Documented: simple random allocation via sealed envelopes/random numbers** (Bradford Hill design, 1948) — one of the first formally randomized trials | 1948 Streptomycin-for-TB trial, one of the first modern RCTs |
| Core | `licorice_gargle` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 235 | 8 | `treat` | `extubation_cough` (+6 more timepoints) | ordinal (3-level, ×7 timepoints) | Unknown; arms 117/118 ≈ equal → assumed BCRD | licorice gargle before intubation, repeated cough/pain severity measures |
| Core | `polyps` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 22 | 3 | `treatment` | `number3m`/`number12m` | count | Unknown; arms 11/11 exact → assumed BCRD | Sulindac-for-polyp-prevention trial |
| Core | `indo_rct` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 602 | ~27 | `rx` | `outcome` | incidence | Unknown; arms 307/295 ≈ equal → assumed BCRD | indomethacin trial for post-ERCP pancreatitis prevention |
| Core | `laryngoscope` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 99 | 5 | `Randomization` | `intubation_overall_S_F`; `total_intubation_time`; `attempts`/`failures` | incidence + continuous + count | Unknown; arms 49/50 ≈ equal → assumed BCRD | video vs. standard laryngoscope trial — one real RCT yielding all three response types at once |
| Core | `lalonde.exp` | CRAN: qte | 2.0.0 | GPL-3 | 445 | 10 | `treat` | `re78` | continuous | Unknown; arms 260/185 unequal → assumed Bernoulli | LaLonde (1986) NSW job-training experiment, real earnings outcome |
| Core | `STAR` | CRAN: AER | 1.2.17 | GPL-2 \| GPL-3 | 11,598 | ~31 (panel, K–3) | `stark` (kindergarten-entry class-type assignment) | `readk`/`read1`/…, `mathk`/`math1`/… | continuous | **Documented: randomized within-school** (blocked by school, not a pooled draw) — 3 arms 2194/1900/2231, unequal overall but explained by the blocking | Tennessee Project STAR class-size experiment, achievement test scores |
| Core | `ResumeNames` | CRAN: AER | 1.2.17 | GPL-2 \| GPL-3 | 4,870 | ~20 | `ethnicity` | `call` | incidence | Unknown (resume-level name randomization, not checked this session for exact race/gender balance); tentatively assumed BCRD given the study's stated intent to balance names | Bertrand & Mullainathan (2004) hiring-discrimination field experiment — sociology/labor economics domain |
| Core | `mm_randhie` | CRAN: stevedata | 1.8.0 | GPL-2 | 3,957 (baseline) | 10 | `plantype` | `ftf`/`totadm`; `out_inf`/`inpdol_inf`/`tot_inf` | count + continuous | **Documented: intentional unequal-probability assignment** across plans (759/881/1022/1295), stratified by income/family size to balance cost against power | RAND Health Insurance Experiment; visit/admission counts + expenditures |
| Core | `diabetic` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 394 | 3 | `trt` | `time`/`status` | survival | **Documented: within-subject paired randomization** — one eye per patient randomized to laser, the other control; not a between-subject BCRD/Bernoulli case at all | Diabetic Retinopathy Study |
| Core | `bladder1` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 294 | ~6 | `treatment` | `number`/`recur` (`rtumor`) | count + survival | Unknown; 3 arms 48/32/38 unequal → assumed Bernoulli | Byar bladder-cancer recurrence trial (thiotepa/placebo), real recurrent-event counts |
| Core | `rhDNase` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 767 | ~3 | `trt` | `fev`; `ivstart`/`ivstop` | continuous (`fev`) + survival | Unknown; arms 325/322 ≈ equal → assumed BCRD | Pulmozyme cystic-fibrosis trial; lung function (continuous) + exacerbation timing |
| Core | `cgd` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 203 | ~9 | `treat` | `tstart`/`tstop`/`status` | survival | **Documented: stratified by clinical center, permuted-block randomization within center** (International CGD Cooperative Study); arms 65/63 | International CGD Cooperative Study (gamma interferon), recurrent infection timing |
| Core | `udca` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 170 | ~3 | `trt` | `death.dt`/`tx.dt`/`hprogress.dt`/`varices.dt`/`ascites.dt`/`enceph.dt`/`double.dt` | survival | Unknown; arms 84/86 ≈ equal → assumed BCRD | ursodeoxycholic acid trial for liver disease — multiple distinct real endpoints (death/transplant/histologic progression/varices/ascites/encephalopathy) |
| Core | `solder` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 900 | 4 factors | N/A -- 4-factor DOE (Opening/Solder/Mask/PadType/Panel) | `skips` | count (`skips`) | N/A — multi-factor factorial DOE, not a 2-arm design; doesn't fit the BCRD/Bernoulli framework | real industrial DOE for solder-skip defects — manufacturing/engineering domain |
| Core | `charitable` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 50,083 | ~51 | `treatment` | `out_amountgive`/`out_gavedum` | continuous + incidence | **Documented: 1/3 control, 2/3 treatment** (16687/33396), intentionally unequal per Karlan & List (2007) | Karlan & List (2007) charitable-giving matching-grant field experiment |
| Core | `mobilization` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 2,474,927 | ~20 | `treatment` | `vote02` | incidence | **Documented: budget-constrained, small treatment fraction by design** (large voter-file field experiment; treated arms 29990/29982 are tiny relative to the 1.8M+ control pool) | Arceneaux/Gerber/Green voter mobilization experiment |
| Core | `social` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 180,002 | ~63 (census-tract merge) | `treatment_dum` | `outcome_voted` | incidence | **Documented: originally 5 groups** (control + 4 treatment conditions — civic duty/Hawthorne/self/neighbors); the 99999/80003 split shown here is the pooled treatment-vs-control dummy, not the per-arm design | Gerber/Green/Larson (2008) social-pressure voter-turnout experiment |
| Core | `secrecy` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 3,744 | ~19 | `anysecrecytreatment` | `turnoutindex_12` (+ `v_*` vote-history indicators) | count + incidence | Unknown; arms 1289/2455 unequal → assumed Bernoulli | ballot-secrecy mobilization experiment |
| Core | `vouchers` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 25,330 | ~70 (many fixed-effect dummies) | `VOUCH0` | `INSCHL`/`FINISH6`/`FINISH7`/`FINISH8`; `REPT`/`TOTSCYRS` | incidence + count | **Documented: oversubscribed lottery among program applicants** (PACES, Colombia) — voucher availability was budget-limited, not an equal-probability design (7149/18180) | Angrist et al. (2002) Colombia private-schooling voucher lottery |
| Core | `welfare` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 36,501 | ~209 (GSS-derived) | `w` | `y` | incidence | **Documented: GSS split-ballot design** — standard survey-methodology simple random assignment (17048/19453) | Green & Kern (2012) GSS survey-wording experiment ("welfare" vs. "assistance to the poor") |
| Core | `monitoring_works` | Dataverse: `doi:10.7910/DVN/LRDXHX` (openICPSR) | v3.3 | CC0 1.0 | 113 schools (57 treated/56 comparison, analyzed sample), 2,896 students, 49,381 school-days | school-level | derived (`schid` membership in `TreatmentSchools.tab`) -- no literal 0/1 column | `validday` (`ValidDay.tab`); `post_math_v`/`post_lang_v`/`post_total_v`/… (`Posttest.tab`) | **proportion** (derived: valid/open days ÷ total days per school) + continuous (post-test scores) | **Documented (verified against the study's own paper, Duflo & Hanna 2006 p.5): 60 of 120 eligible schools randomly selected as treatment, remainder as comparison — simple random allocation, not matched pairs.** 57/56 reflects the final analyzed sample after some attrition from the original 60/60 design. (Correction: an earlier version of this note incorrectly claimed baseline-matched-pair randomization — not supported by the paper.) | Duflo & Hanna (2006), later published as Duflo, Hanna & Ryan (2012) — camera-monitoring vs. control for teacher attendance, one-teacher schools, India. Fetched via the Dataverse guestbook API, not the ICPSR OAuth flow. |
| Core | `savings` | Dataverse: `doi:10.7910/DVN/UJD5OP` (IPA); file `analysis_dataallcountries.tab` | v1.0 | CC0 1.0 | 13,560 | ~50 | N/A -- multi-factor (incentive type x framing x reminder) | `quant_saved`/`saved_formal` | continuous (`quant_saved`) + incidence (`saved_formal`) | N/A — multi-factor (incentive type × framing × reminder), not a simple 2-arm design | Karlan et al., "Getting to the Top of Mind" — reminder-message savings field experiment, multiple countries |
| Core | `immig` | Dataverse: `doi:10.7910/DVN/DDCNEW`; file `analysis.dta` | v1.2 | CC0 1.0 | 23,836 | ~800 (wide, census-merged) | `treatment` (`actualtreatment` for compliance-adjusted analysis) | `registered`; `vote2010_1st`/`_2nd`, `vote2011_1st`/`_2nd` | incidence | **Documented: stratified and clustered** — data carries explicit `cluster`/`stratum` fields; not simple Bernoulli/BCRD | GOTV field experiment on immigrant electoral participation, France |
| Core | `hiv` | Dataverse: `doi:10.7910/DVN/CVOPZL`; file `Phase2_sample_list.dta` | v2.0 | CC0 1.0 | 10,636 | ~10 | `Utreat`/`HIVtreat` (2-factor: VCT arm x condom-distribution arm) | not confirmed this session — actual biomarker outcome lives in the larger, not-yet-loaded `bio_*.dta` files; `Phase2_sample_list.dta` only has sampling/eligibility flags (`sampledVCT`/`sampledCONDOMS`) | incidence (+ biomarker-derived measures in larger, not-yet-loaded files) | **Documented: stratified with sampling weights** — data carries explicit `strata_ITsampling`/`weight_sample` fields; unequal-probability by design | HIV prevention RCT (VCT + condom distribution), rural Kenya |
| Core | `sanitation` | Dataverse: `doi:10.7910/DVN/GJDUTV` (IPA); file `BD-SAN-FINAL.dta` | v2.3 | CC0 1.0 | 18,254 households | ~40 | `treat_cat_1`-`5` | `r4_any_own`/`r4_any_access`; `r4_any_od_adults`/`r4_any_od_male`/`r4_any_od_female` | incidence (latrine ownership/access, open defecation) + derivable proportion (household-level OD rate) | **Documented: cluster-randomized at the village level** (`vid`/`cid` cluster fields), 5-category multi-arm design (`treat_cat_1`–`5`, likely crossing supply-/demand-side interventions) — not a simple 2-arm case | Guiteras, Levinsohn & Mobarak — sanitation-investment cluster-RCT, Bangladesh |
| Expanded | `student_test_data` | Dataverse: `doi:10.7910/DVN/LWFH9U` (J-PAL) | v2.3 | CC0 1.0 | 7,022 (121 schools) | ~10 | `tracking` | `std_mark` | continuous | **Documented: school-level randomization to "tracking" (streaming by initial achievement) vs. no tracking** (Duflo, Dupas & Kremer 2011) — schools 3,409 non-tracked/3,613 tracked pupil-obs, close to balanced → consistent with BCRD at the school level; a second, independently randomized arm (`etpteacher`, contract-teacher assignment) is also balanced (3,537/3,485) | Duflo, Dupas & Kremer (2011) Kenya primary-school tracking and teacher-incentive experiment — standardized test scores, education domain |
| Expanded | `PES_analysis_science` | Dataverse: `doi:10.7910/DVN/MGMDYN` (J-PAL) | v4.0 | CC0 1.0 | 1,174 households (121 villages) | ~11 | `treat` | `change_fcover_act` | continuous | Unknown exact randomization unit from the fields pulled this session (no explicit cluster-ID beyond `village`); household-level `treat` is closely balanced (585/589) → assumed BCRD, consistent with the published village-clustered PES design (Jayachandran et al. 2017) | Jayachandran, de Laat, Jakob, Thomas & Wibbels (2017) *Science* — Payments-for-Ecosystem-Services (PES) conservation contracts vs. control, satellite-measured forest-cover change, Uganda; environmental-economics domain, no prior domain overlap in this table |
| Expanded | `ghana_bednet` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 26,342 (96 clusters) | ~3 | `bednet` | `outcome` (`follyr` for a survival cut) | incidence (+ survival via `follyr`) | **Documented: cluster-randomized, 96 clusters, 48/48 exactly balanced** | Ghana insecticide-treated-bednet trial — child mortality, malaria/public-health domain |
| Expanded | `laviiswa` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 680 | ~2 | `trialarm` | `lsizel` | **ordinal (3-level: 427/207/46)** | **Documented: cluster-randomized (village-level), close to balanced (344/336 individual obs)** | Lake Victoria schistosomiasis/praziquantel trial — liver-size grade; genuinely new ordinal source (our other 2 ordinal sources both come from `geepack`/`medicaldata`), parasitology domain |
| Expanded | `mkvtrial` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 4,100 (20 communities) | ~4 | `arm` | `know` | incidence | **Documented: community-randomized, stratified by 3 strata, balanced (2,024/2,076)** | Adolescent-health/HIV-knowledge community trial (Mwanza region) |
| Expanded | `mwanza_stdtrial` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 8,549 (12 communities) | ~3 | `arm` | `hiv` | incidence | **Documented: matched-pair community randomization, 6 pairs/12 communities, balanced (4,400/4,149)** | Mwanza STD-treatment HIV-prevention trial — seroconversion; the companion `mwanza_stdtrial_community.tab` (n=12, community-level baseline HIV prevalence only, no outcome field) was evaluated and excluded — pure baseline/matching covariates, not a usable response |
| Expanded | `pneumovac` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 449 (36 clusters) | 0 | `spnvac` | `bpepisodes` | **count (0–3)** | **Documented: cluster-randomized, 36 clusters, 18/18 exactly balanced** | Gambia pneumococcal-vaccine trial — bacterial pneumonia episode counts |
| Expanded | `share` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 5,854 (25 schools) | ~2 | `arm` | `debut` (+ `kscore`) | incidence (+ continuous via `kscore`, range −6 to 8) | **Documented: school-randomized, 25 schools, balanced (2,987/2,867)** | South African SHARE school sex-education trial — sexual-debut incidence + knowledge score; education/public-health domain |
| Expanded | `thrio` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 20,574 (29 units) | 0 | `interv` | `tb` | incidence | **Documented: stepped-wedge cluster-randomized, 29 units — a design family not otherwise represented in this table** | Botswana THRio TB/HIV isoniazid-preventive-therapy trial |
| Expanded | `zamstar` | Dataverse: `doi:10.7910/DVN/YXMQZM` (Hayes & Moulton *Cluster Randomised Trials*) | v3.0 | CC0 1.0 | 24 communities (cluster-level) | ~2 | `ecf`/`hh` (2x2 factorial) | `d`/`n` (TB cases / evaluable sample) | **proportion** | **Documented: 2×2 factorial cluster-randomized (24 communities), stratified** | Zambia/South Africa ZAMSTAR TB-transmission trial (enhanced case-finding × household intervention), cluster-level proportions |
| Expanded | `tanf` | CRAN: whatifbandit | 1.0.3 | GPL (>= 3) | 3,517 | ~2 | `condition` | `success` | incidence | **Documented: 3-arm, well-balanced** (`condition`: no_letter 1,170 / open_appt 1,176 / specific_appt 1,171) | DC TANF-recertification reminder-letter field experiment — public-benefits/social-policy domain, found via an exhaustive CRAN-wide sweep (2026-09-15) |
| Expanded | `gastric_cancer_trial_df` | CRAN: DigestiveDataSets | 0.2.0 | GPL-3 | 90 | 0 | `group` | `time`/`event` | survival | **Documented: 2-arm, exactly balanced (45/45)** | Stablein gastric-cancer chemotherapy+radiation-vs-chemotherapy trial — distinct trial/cohort from the table's existing `pbc`/`udca`/`veteran` survival sources |
| Expanded | `liver_cirrhosis_prednisone_df` | CRAN: DigestiveDataSets | 0.2.0 | GPL-3 | 488 patients (2,968 counting-process rows) | 0 fixed (`proth` is a real **time-varying** covariate) | `Trt` | `death`/`event` (`start`/`stop`) | survival | **Documented: 2-arm, balanced (237 placebo/251 prednisone)** | Andersen-Gill liver-cirrhosis prednisone trial -- the table's first *time-varying-covariate* start/stop survival structure |
| Expanded | `WSCdata` | CRAN: WSCdata | 0.1.2 | MIT + file LICENSE | 2,200 | ~25 | `mathGrp` | `mathPost` (+ `vocabPost`) | continuous | **Documented randomized arm** `mathGrp`, balanced (1,136/1,064), within a real 4-arm within-study-comparison design (also carries a non-randomized quasi-experimental arm, `mathSel`, for explicit experimental-vs-quasi-experimental comparison -- use `mathGrp` only) | Education-psychology within-study-comparison design |
| Expanded | `immigrationconjoint` | CRAN: cjoint | 2.1.3 | GPL (>= 2) | 13,960 profile evaluations (1,396 respondents x 10) | N/A -- 9 independently randomized profile attributes | N/A -- 9 independently randomized attributes | `Chosen_Immigrant` | incidence | **N/A -- fully randomized conjoint/factorial design** (Education/Gender/Country-of-Origin/Reason-for-Application/Job/Job-Experience/Job-Plans/Prior-Entry/Language-Skills all independently randomly assigned per profile), not a simple 2-arm case -- same treatment as `solder`'s factorial DOE; using this dataset requires picking one attribute as the focal treatment and the rest as already-realized randomized covariates, a modeling choice left to the analysis, not resolved here | Hainmueller, Hopkins & Yamamoto (2014) immigration-attitudes conjoint survey experiment -- new design family (randomized factorial/conjoint) and new domain (political science/public opinion) |
| Expanded | `epilepsy_RCT_tbl_df` | CRAN: NeuroDataSets | 0.3.1 | GPL (>= 2) | 59 | ~3 | `treat` | `y1`-`y4` (seizure counts, 4 visits) | count | Documented, balanced (28 Control/31 Prograbide) -- the classic Thall & Vail (1990) progabide epilepsy trial | Neurology domain, deep CRAN /data scan (2026-09-15) |
| Expanded | `sulphinpyrazone_tbl_df` | CRAN: CardioDataSets | 0.2.0 | GPL-3 | 1,475 | 0 | `group` | `outcome` (died/lived) | incidence | Documented, balanced (742 control/733 treatment) -- Anturane Reinfarction Trial | Cardiology domain; no covariates shipped |
| Expanded | `immdef` | CRAN: rpsftm | 1.2.9 | GPL-2 | 1,000 | ~2 | `imm` (immediate vs. deferred; also `def`) | `xo`/`xoyrs` (crossover) + `censyrs` for a survival cut | survival | **Documented, exactly balanced (500/500)** -- the Concorde AZT immediate-vs-deferred HIV trial, canonical in the treatment-switching/RPSFTM literature | HIV/infectious-disease domain; table's first dataset with explicit real treatment-crossover data |
| Expanded | `Gbsg_df` | CRAN: ForCausality | 0.1.0 | GPL-3 | 686 | ~6 | `hormon` | `rfstime`/`status` | survival | Documented (440/246, unequal but real) -- German Breast Cancer Study Group trial | Oncology domain; richer covariate set (age/meno/size/grade/nodes/pgr/er) than the table's other survival sources |
| Expanded | `seguro` | CRAN: experiment | 1.2.1 | GPL (>= 2) | 14,902 (matched-pair rows) | 0 shipped | `Ta`/`Tb` (paired treatment assignment) | `Ya`/`Yb` (satisfaction, binary; ~79% missing) | incidence | **Documented matched-pairs design** (Imai & Jiang 2018), marginally balanced (7,410/7,492); heavy missingness in the outcome is a real feature of the data, not a data-quality issue -- use with that in mind | Seguro Popular Mexican universal-health-insurance policy trial; health-policy domain |
| Expanded | `ajps` | CRAN: GK2011 | 0.1.3 | GPL (>= 2) | 483 | 1 | `tr` (4-level: treatment/control/chose-treatment/chose-control) | `therm.obama`/`therm.mccain` | continuous | **Documented hybrid self-selection experiment** (Gaines & Kuklinski 2011, *AJPS*) -- new design family (experimental + self-selected arms combined) | Political science, feeling-thermometer outcomes |
| Expanded | `pakistan` | CRAN: endorse | 1.6.2 | GPL (>= 2) | 5,212 | 5 | derived: exactly one of `Polio.a`-`e` non-missing per row (clean random 5-arm assignment, not a single factor column) | `Polio.a`-`e` (whichever is non-missing) | **ordinal (1-5)** | **Documented 5-arm endorsement experiment** (control + 4 militant-group endorsers), Bullock, Imai & Shapiro (2011) *Political Analysis* | Political science/conflict studies, Pakistan; independent ordinal source (not `geepack`/`medicaldata`/Hayes-Moulton) |
| Expanded | `berberis_treatment` | CRAN: ecoteach | 0.1.0 | MIT | 127 | 4 | `treatment` (4-level: manual digging/leaf-spray/stem-cut+glyphosate/stem-cut+salt) | `regrowth` | **ordinal (3-level: Dead<Limited<Vital)** | Documented real field experiment, Belgium dune sites | Ecology/invasive-species-management domain; another independent ordinal source |
| Expanded | `PowderyMildew` | CRAN: epifitter | 1.0.0 | MIT | 240 | 3 | `irrigation_type` | `sev` (disease severity) | **proportion** | Documented real trial (Lage et al. 2019, *Crop Protection*), organic tomato | Plant pathology/agriculture domain; second independent proportion source (alongside `zamstar`) |
| Expanded | `train1` | CRAN: callback | 0.1.3 | GPL-3 | 2,167 | ~10 | N/A -- candidate-identity attributes (same structural caveat as `ResumeNames`/`immigrationconjoint`, no single binary column) | `callback` | incidence | Documented correspondence/audit-study field experiment (Fremigacci et al. 2013, *Revue d'economie politique*) | Labor-economics/discrimination domain, France -- package ships 12 more similar sub-studies (train2, labour1/2, origin1/2, gender1-4, mobility1, address1, inter1), not individually added here |
| Expanded | `opt` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 823 | ~25 | `Group` | `Preg.ended...37.wk` (+ `Birthweight`) | incidence (+ continuous via `Birthweight`) | **Documented: "Randomized treatment assignment... T = Intervention; C = Control"** | Obstetrics/periodontal-therapy RCT -- new domain, found via deep CRAN /data scan (2026-09-15) |
| Expanded | `supraclavicular` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 103 | 3 | `group` | `onset_sensory`/`onset_first_sensory` (`nerve_block_censor`) | survival | **Documented: "Patients were randomly assigned to either...combined group...or...sequential group"** | Anesthesiology nerve-block-onset-time RCT -- new domain |
| Expanded | `clubSandwich::AchievementAwardsRCT` | CRAN: clubSandwich | 0.5.11 | GPL-3 | 16,526 | 15 | `treated` | `Bagrut_status / achv_math_gpa` | incidence | Documented: Angrist & Lavy (2009) AER randomized Israeli high-school achievement-award experiment | Angrist & Lavy (2009) achievement-award field experiment, Israel |
| Expanded | `asaur::pharmacoSmoking` | CRAN: asaur | 0.50 | MIT + file LICENSE | 125 | 10 | `grp` | `ttr / relapse` | survival | Documented: Steinberg et al. (2009) Ann Intern Med randomized smoking-cessation trial | Triple-therapy vs patch smoking-cessation RCT |
| Expanded | `afex::laptop_urry` | CRAN: afex | 1.5-1 | GPL (>= 2) | 142 | 1 | `condition` | `overall / factual / conceptual` | continuous | Documented: Urry et al. (2021) Psych Science replication RCT (laptop vs longhand note-taking) | Replication of Mueller & Oppenheimer (2014) note-taking RCT |
| Expanded | `cofad::testing_effect` | CRAN: cofad | 0.4.0 | LGPL (>= 3) | 60 | 0 | `condition` | `recalled` | count | Documented: randomly assigned to one of three learning conditions, U. Cologne study | Testing-effect memory experiment |
| Expanded | `causalweight::JC` | CRAN: causalweight | 1.1.5 | MIT + file LICENSE | 9,240 | 15 | `assignment` | `everwkdy1 / earnq4` | incidence | Documented: real randomized US Job Corps National Study | Job Corps job-training federal RCT |
| Expanded | `causalOT::pph` | CRAN: causalOT | 1.0.4 | GPL (==3.0) | 802 | 14 | `tx` | `cum_blood_20m` | continuous | Documented Blum et al. (2010) Lancet RCT; mixed RCT+external-control structure, use with that caveat | Misoprostol vs oxytocin postpartum-hemorrhage RCT |
| Expanded | `baggr::microcredit` | CRAN: baggr | 0.8.2 | GPL (>= 3) | 40,267 | 2 | `treatment` | `consumption / profit (6 outcome vars)` | continuous | Documented: Meager (2019) AEJ:Applied, pooled individual-level data from 7 real microcredit RCTs | Pooled microcredit-access RCTs, 7 countries |
| Expanded | `asbio::potash` | CRAN: asbio | 1.13-1 | GPL (>= 2) | 15 | 1 | `treatment` | `strength` | continuous | Documented: Cochran & Cox (1957) classic randomized complete block design | Potash-fertilizer RCBD field trial |
| Expanded | `collett::prostatic` | CRAN: collett | 0.1.2 | MIT + file LICENSE | 38 | 4 | `treatment` | `time / status` | survival | Documented: VA Cooperative Urological Research Group randomized trial | Prostatic cancer treatment RCT |
| Expanded | `collett::tamoxifen` | CRAN: collett | 0.1.2 | MIT + file LICENSE | 641 | 14 | `treat` | `time / status (endpoint-specific)` | survival | Documented: real randomized breast-cancer tamoxifen + radiotherapy trial | Breast-cancer tamoxifen RCT |
| Expanded | `collett::active_hepatitis` | CRAN: collett | 0.1.2 | MIT + file LICENSE | 44 | 0 | `treatment` | `time / status` | survival | Documented: real randomized hepatitis prednisolone-vs-control trial | Hepatitis prednisolone RCT |
| Expanded | `BGPhazard::gehan` | CRAN: BGPhazard | 2.1.1 | GPL (>= 2) | 42 | 0 | `treat` | `time / cens` | survival | Documented: Freireich et al. (1963) classic matched-pair leukemia 6-MP trial | Freireich (1963) leukemia matched-pair RCT (canonical form; also appears as SMPracticals::aml/boot::aml/IDPSurvival::aml -- same trial) |
| Expanded | `coxphw::biofeedback` | CRAN: coxphw | 4.0.3 | GPL-3 | 33 | 4 | `bfb` | `thdur / success` | survival | Documented: patients were randomized into two groups | Biofeedback therapy RCT |
| Expanded | `CrossCarry::Water` | CRAN: CrossCarry | 1.2.0 | GPL (>= 3) | 214 | 6 | `Treatment` | `LCI (cognitive score)` | continuous | Documented crossover RCT: control/treatment order randomized across two days | Water-intake cognitive-performance crossover RCT |
| Expanded | `dae::McIntyreTMV.dat` | CRAN: dae | 3.2.35 | GPL (>= 2) | 128 | 6 | `light treatment factor` | `SqrtCount` | count | Documented: McIntyre (1955), four light treatments randomized to tobacco leaves | Tobacco mosaic virus light-treatment RCBD |
| Expanded | `dae::Oats.dat` | CRAN: dae | 3.2.35 | GPL (>= 2) | 72 | 3 | `Nitrogen / Variety` | `Yield` | continuous | Documented: Yates (1937) classic randomized complete block design oats trial | Yates oats RCBD field trial (canonical; also appears as asremlPlus::Oats.dat/nlme::Oats/RobStatTM::oats/emmeans::MOats -- same classic dataset) |
| Expanded | `cvGEE::aids` | CRAN: cvGEE | 0.1.2 | GPL (>= 2) | 1,405 | 5 | `drug` | `Time / death` | survival | Documented: real randomized clinical trial comparing two antiretroviral drugs | Antiretroviral-drug RCT |
| Expanded | `DeepLearningCausal::exp_data` | CRAN: DeepLearningCausal | 0.0.107 | GPL-3 | 257 | 9 | `strong_leader` | `support_war` | incidence | Documented: respondents randomly assigned to control or one of two treatments | Political-messaging survey experiment |
| Expanded | `coursekata::TipExperiment` | CRAN: coursekata | 0.20.1 | GPL (>= 3) | 44 | 3 | `Condition` | `Tip` | continuous | Documented: tables randomly assigned to receive checks with different conditions | Restaurant-tipping field experiment |
| Expanded | `DoseFinding::migraine` | CRAN: DoseFinding | 1.4-1 | GPL-3 | 8 | 0 | `dose` | `painfree / ntrt` | proportion | Documented: clinicaltrials.gov NCT00712725, randomized placebo-controlled dose-response trial | Migraine dose-response RCT |
| Expanded | `ecotox::lamprey_tox` | CRAN: ecotox | 1.4.4 | GPL-3 \| file LICENSE | 64 | 3 | `dose / tank` | `response / total` | proportion | Documented: randomly assigned to a tank for exposure to varying doses | Lamprey toxicology dose-response experiment |
| Expanded | `emplik::smallcell` | CRAN: emplik | 1.3-3 | GPL (>= 2) | 121 | 2 | `arm` | `survival / indicator` | survival | Documented: North Central Cancer Treatment Group Randomized Clinical Trial | Small-cell lung cancer RCT |
| Expanded | `EngrExpt::uvcoatin` | CRAN: EngrExpt | 0.1-8 | GPL (>= 2) | 10 | 1 | `left/right random assignment` | `diff (haze)` | continuous | Documented: coatings applied to lens in a random fashion | UV coating engineering paired experiment |
| Expanded | `esci::data_rattanmotivation` | CRAN: esci | 1.0.4 | GPL (>= 3) | 54 | 1 | `Group` | `(motivation score)` | continuous | Documented Rattan et al. (2012) randomized feedback experiment | Growth-mindset feedback RCT |
| Expanded | `esci::data_selfexplain` | CRAN: esci | 1.0.4 | GPL (>= 3) | 52 | 1 | `Condition` | `(learning score)` | continuous | Documented McEldoon et al. (2013) randomized learning-strategy experiment | Self-explanation learning-strategy RCT |
| Expanded | `EstimationTools::head_neck_cancer` | CRAN: EstimationTools | 4.1.1 | GPL-3 | 96 | 1 | `Therapy` | `survival` | survival | Documented randomized radiation-therapy trial | Head/neck cancer radiation RCT |
| Expanded | `coin::rotarod` | CRAN: coin | 1.4-5 | GPL-2 | 24 | 0 | `group` | `time` | continuous | Documented: randomly assigned pharmacology rat experiment | Rat rotarod pharmacology RCT (canonical; also appears as exactRankTests::rotarod) |
| Expanded | `experimentr::mcgrath` | CRAN: experimentr | 0.1.0 | MIT + file LICENSE | 30 | 1 | `treatment` | `(outcome score)` | continuous | Documented McGrath et al. (2016) randomized experiment | Chocolate-scent consumer-behavior RCT |
| Expanded | `experimentr::sherman` | CRAN: experimentr | 0.1.0 | MIT + file LICENSE | 207 | 1 | `treatment` | `(recidivism count)` | count | Documented Sherman et al. (1995) randomized field experiment | Police domestic-violence-raid RCT |
| Expanded | `faraway::coagulation` | CRAN: faraway | 1.0.9 | GPL (>= 2) | 24 | 1 | `diet` | `(coagulation time)` | continuous | Documented Box/Hunter/Hunter randomized diet experiment | Diet-coagulation-time RCT |
| Expanded | `faraway::fruitfly` | CRAN: faraway | 1.0.9 | GPL (>= 2) | 124 | 1 | `activity` | `(longevity)` | continuous | Documented Partridge & Farquhar (1981) randomized experiment | Fruit-fly mating-activity longevity RCT |
| Expanded | `faraway::hips` | CRAN: faraway | 1.0.9 | GPL (>= 2) | 78 | 1 | `grp` | `(outcome score)` | continuous | Documented randomized physiotherapy trial | Ankylosing-spondylitis physiotherapy RCT |
| Expanded | `faraway::irrigation` | CRAN: faraway | 1.0.9 | GPL (>= 2) | 16 | 0 | `irrigation treatment` | `(yield)` | continuous | Documented split-plot randomized irrigation trial | Split-plot irrigation field trial |
| Expanded | `frailtyHL::bladder0` | CRAN: frailtyHL | 2.3 | GPL (>= 2) | 410 | 1 | `Chemo` | `survival` | survival | Documented EORTC randomized bladder-cancer trial | EORTC bladder-cancer chemo RCT |
| Expanded | `frailtyHL::ren` | CRAN: frailtyHL | 2.3 | GPL (>= 2) | 254 | 1 | `gp` | `survival` | survival | Documented Gail et al. (1980) randomized rat mammary-tumor experiment | Mammary-tumor rat RCT |
| Expanded | `frailtypack::bcos` | CRAN: frailtypack | 3.7.1 | GPL (>= 2) | 94 | 1 | `treatment` | `survival` | survival | Documented Finkelstein & Wolfe randomized breast-cosmesis trial | Breast cosmesis radiotherapy RCT |
| Expanded | `frailtypack::colorectal` | CRAN: frailtypack | 3.7.1 | GPL (>= 2) | 289 | 1 | `treatment` | `survival` | survival | Documented FFCD 2000-05 randomized colorectal-cancer trial | FFCD colorectal-cancer chemo RCT (canonical; also appears as SLCARE::colorectal, same trial ID) |
| Expanded | `frailtypack::dataOvarian` | CRAN: frailtypack | 3.7.1 | GPL (>= 2) | 1,192 | 1 | `trt` | `survival` | survival | Documented pooled patient-level data, 4 real randomized ovarian-cancer trials | Pooled advanced ovarian-cancer RCTs |
| Expanded | `frailtypack::gastadj` | CRAN: frailtypack | 3.7.1 | GPL (>= 2) | 3,288 | 1 | `trt` | `survival` | survival | Documented GASTRIC group pooled patient-level data, real randomized adjuvant-chemo trials | Pooled gastric-cancer adjuvant-chemo RCTs (canonical; also appears as surrosurv::gastadj) |
| Expanded | `frailtypack::reduce` | CRAN: frailtypack | 3.7.1 | GPL (>= 2) | 939 | 1 | `treatment` | `survival` | survival | Documented REDUCE randomized haloperidol-delirium trial | Haloperidol delirium-prevention RCT |
| Expanded | `geecure::smoking` | CRAN: geecure | 1.5 | GPL (>= 2) | 223 | 1 | `SI.UC` | `survival` | survival | Documented randomized smoking-cessation trial | Smoking-cessation RCT |
| Expanded | `geecure::tonsil` | CRAN: geecure | 1.5 | GPL (>= 2) | 195 | 1 | `Trt` | `survival` | survival | Documented randomized tonsil-carcinoma trial | Tonsil carcinoma treatment RCT |
| Expanded | `geer::cerebrovascular` | CRAN: geer | 0.1.0 | GPL (>= 2) | 134 | 1 | `treatment` | `(deficiency incidence)` | incidence | Documented randomized crossover trial | Cerebrovascular deficiency crossover RCT |
| Expanded | `geer::cholecystectomy` | CRAN: geer | 0.1.0 | GPL (>= 2) | 246 | 1 | `treatment` | `(shoulder-pain score)` | ordinal | Documented randomized post-laparoscopy shoulder-pain trial | Post-laparoscopy shoulder-pain RCT |
| Expanded | `geer::depression` | CRAN: geer | 0.1.0 | GPL (>= 2) | 366 | 1 | `treatment` | `(depression score)` | continuous | Documented randomized postnatal-depression oestrogen trial | Postnatal-depression oestrogen RCT |
| Expanded | `geer::leprosy` | CRAN: geer | 0.1.0 | GPL (>= 2) | 60 | 1 | `treatment` | `(bacterial count)` | count | Documented randomized leprosy antibiotic trial | Leprosy antibiotic RCT |
| Expanded | `geer::rinse` | CRAN: geer | 0.1.0 | GPL (>= 2) | 218 | 1 | `treatment` | `(plaque score)` | continuous | Documented randomized dental mouth-rinse trial | Dental plaque mouth-rinse RCT |
| Expanded | `GJRM.data::hie` | CRAN: GJRM.data | 0.2-6.1 | GPL (>= 2) | 7,734 | 1 | `bonus` | `(employment incidence)` | incidence | Documented Illinois Hiring Incentive randomized field experiment | Illinois re-employment bonus experiment |
| Expanded | `glmm::bacteria` | CRAN: glmm | 1.4.4 | GPL-2 | 220 | 1 | `trt` | `(infection incidence)` | incidence | Documented randomized otitis-media drug trial in children | Otitis-media antibiotic RCT |
| Expanded | `glmtoolbox::amenorrhea` | CRAN: glmtoolbox | 1.1.4 | GPL (>= 2) | 4,604 | 1 | `Dose` | `(amenorrhea incidence)` | incidence | Documented randomized DMPA-contraceptive dose trial | Contraceptive dose-response RCT |
| Expanded | `glmtoolbox::ossification` | CRAN: glmtoolbox | 1.1.4 | GPL (>= 2) | 81 | 2 | `pht / tcpo` | `(ossification proportion)` | proportion | Documented randomized 2x2 factorial teratology mouse trial | Teratology factorial mouse RCT |
| Expanded | `gosset::breadwheat` | CRAN: gosset | 1.5.5 | GPL-3 | 493 | 0 | `variety triplet` | `(ranking)` | ordinal | Documented tricot on-farm randomized wheat-variety trial, India | On-farm tricot wheat-variety RCT, India |
| Expanded | `gosset::nicabean` | CRAN: gosset | 1.5.5 | GPL-3 | 300 | 0 | `variety triplet` | `(ranking)` | ordinal | Documented tricot on-farm randomized bean-variety trial, Nicaragua | On-farm tricot bean-variety RCT, Nicaragua |
| Expanded | `gpk::cloudseed` | CRAN: gpk | 1.0 | GPL (>= 2) | 52 | 1 | `Seeded.Indicator` | `(rainfall)` | continuous | Documented classic randomized cloud-seeding experiment | Cloud-seeding weather-modification RCT |
| Expanded | `granova::arousal` | CRAN: granova | 2.0.0 | GPL (>= 2) | 40 | 0 | `treatment group (4-level)` | `(arousal score)` | continuous | Documented randomized rat pharmacology arousal experiment | Rat arousal pharmacology RCT |
| Expanded | `gss::bacteriuria` | CRAN: gss | 0.10-9 | GPL (>= 2) | 820 | 1 | `trt` | `(bacteriuria incidence)` | incidence | Documented randomized bacteriuria treatment trial | Bacteriuria treatment RCT |
| Expanded | `hamlet::orxwide` | CRAN: hamlet | 0.9.8 | GPL-3 | 109 | 1 | `Group` | `(tumor score)` | continuous | Documented preclinical randomized tumor study, matched random allocation | Preclinical tumor-treatment RCT |
| Expanded | `heplots::RatWeight` | CRAN: heplots | 1.7.4 | GPL (>= 2) | 27 | 1 | `trt` | `(weight gain)` | continuous | Documented Box (1950) classic randomized rat weight-gain experiment | Box (1950) rat weight-gain RCT (canonical; also appears as nlmm::rats) |
| Expanded | `heritable::lettuce_phenotypes` | CRAN: heritable | 0.1.0 | GPL-3 | 703 | 1 | `gen` | `(phenotype ordinal score)` | ordinal | Documented randomized complete block lettuce field trial | Lettuce RCBD phenotype field trial |
| Expanded | `hiddenf::Graybill.mtx` | CRAN: hiddenf | 1.2.2 | GPL (>= 2) | 52 | 0 | `treatment (implicit in matrix)` | `(yield)` | continuous | Documented Graybill (1954) classic randomized wheat RCBD | Graybill (1954) wheat RCBD field trial |
| Expanded | `HLMdiag::ahd` | CRAN: HLMdiag | 0.5.0 | GPL (>= 2) | 330 | 1 | `treatment` | `(outcome score)` | continuous | Documented randomized methylprednisolone hepatitis trial | Methylprednisolone hepatitis RCT |
| Expanded | `hnp::cbb` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 288 | 1 | `trap` | `(borer count)` | count | Documented completely randomized coffee-berry-borer field trial | Coffee berry borer CRD field trial |
| Expanded | `hnp::chryso` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 24 | 1 | `conc` | `(toxicity proportion)` | proportion | Documented completely randomized lime-sulphur toxicology trial | Lime-sulphur toxicology CRD |
| Expanded | `hnp::corn` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 40 | 1 | `extract` | `(mortality proportion)` | proportion | Documented completely randomized corn-weevil insecticide trial | Corn weevil insecticide CRD |
| Expanded | `hnp::fungi` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 30 | 2 | `species / conc` | `(inhibition proportion)` | proportion | Documented completely randomized fungi biocontrol trial | Fungi biocontrol CRD |
| Expanded | `hnp::oil` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 70 | 1 | `treat` | `(oviposition count)` | count | Documented completely randomized agricultural-oil oviposition trial | Agricultural-oil oviposition CRD |
| Expanded | `hnp::orange` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 150 | 1 | `sugar` | `(embryogenesis count)` | count | Documented randomized complete block orange embryogenesis trial | Orange embryogenesis RCBD |
| Expanded | `hnp::progeny` | CRAN: hnp | 1.2-8 | GPL (>= 2) | 40 | 1 | `extract` | `(progeny count)` | count | Documented completely randomized weevil-progeny trial | Weevil progeny CRD |
| Expanded | `HSAUR3::BtheB` | CRAN: HSAUR3 | 1.0-13 | GPL-2 | 100 | 1 | `treatment` | `(depression score)` | continuous | Documented randomized 'Beat the Blues' depression trial | Beat the Blues computerized-CBT RCT |
| Expanded | `HSAUR3::Lanza` | CRAN: HSAUR3 | 1.0-13 | GPL-2 | 198 | 1 | `treatment` | `(outcome ordinal)` | ordinal | Documented pooled patient-level data, 4 real randomized misoprostol trials | Pooled misoprostol RCTs |
| Expanded | `HSAUR3::students` | CRAN: HSAUR3 | 1.0-13 | GPL-2 | 35 | 1 | `treatment` | `(risk score)` | continuous | Documented Timm randomized risk-taking experiment | Risk-taking behavioral RCT |
| Expanded | `PASWR2::WEIGHTGAIN` | CRAN: PASWR2 | 1.7 | GPL (>= 2) | 40 | 2 | `source / type` | `weightgain` | continuous | Documented completely randomized design, ten rats per treatment (Hand et al., Handbook of Small Datasets) | Rat-diet weight-gain factorial RCT (canonical; also appears as HSAUR::weightgain) |
| Expanded | `mediation::jobs` | CRAN: mediation | 4.5.0 | GPL (>= 2) | 899 | 8 | `treat` | `job_dich / depress2` | incidence | Documented JOBS II randomized field experiment | JOBS II job-training/mental-health RCT |
| Expanded | `Matching::GerberGreenImai` | CRAN: Matching | 4.10-15 | GPL (>= 3) | 10,829 | 6 | `PHONEGRP` | `VOTED98` | incidence | Documented Gerber & Green (2000) GOTV randomized field experiment | GOTV phone-canvassing field experiment (canonical; also appears as factiv::newhaven) |
| Expanded | `lmPerm::Federer276` | CRAN: lmPerm | 2.1.0 | GPL (>= 2) | 96 | 3 | `Treatment` | `Plants` | count | Documented Federer (1955) randomized block design | Federer randomized block agricultural trial |
| Expanded | `lmPerm::Hald17.4` | CRAN: lmPerm | 2.1.0 | GPL (>= 2) | 35 | 1 | `T` | `Y` | continuous | Documented Hald (1952) randomized block experiment | Hald (1952) engineering RCBD |
| Expanded | `labstats::festing` | CRAN: labstats | 0.0.1 | GPL-3 | 16 | 2 | `treatment` | `value` | continuous | Documented randomized block mouse-liver-enzyme experiment | Mouse liver-enzyme RCBD |
| Expanded | `labstats::fluoxetine` | CRAN: labstats | 0.0.1 | GPL-3 | 20 | 0 | `dose` | `time.immob` | continuous | Documented: rats randomly assigned to control or three doses | Rat fluoxetine pharmacology RCT |
| Expanded | `labstats::glycogen` | CRAN: labstats | 0.0.1 | GPL-3 | 36 | 2 | `Treatment` | `Glycogen` | continuous | Documented: six rats randomised to three treatment conditions | Rat glycogen physiology RCT |
| Expanded | `labstats::hypertension` | CRAN: labstats | 0.0.1 | GPL-3 | 30 | 2 | `Diet` | `Y` | continuous | Documented Casella (2008) randomized diet/blood-pressure experiment | Diet/blood-pressure RCT |
| Expanded | `labstats::KH2004` | CRAN: labstats | 0.0.1 | GPL-3 | 210 | 2 | `cond` | `values` | continuous | Documented paired-randomization rat muscle-pharmacology experiment | Rat muscle-pharmacology paired RCT |
| Expanded | `labstats::locomotor` | CRAN: labstats | 0.0.1 | GPL-3 | 282 | 2 | `drug` | `dist` | continuous | Documented: forty-seven rats randomised, behavioral pharmacology | Rat locomotor-activity pharmacology RCT |
| Expanded | `labstats::VPA` | CRAN: labstats | 0.0.1 | GPL-3 | 24 | 2 | `group / drug` | `activity` | continuous | Documented two-level randomization mouse teratology experiment | Mouse VPA teratology RCT |
| Expanded | `KONPsurv::carcinoma` | CRAN: KONPsurv | 1.1.0 | GPL (>= 2) | 625 | 0 | `group` | `time / status` | survival | Documented real Phase 3 IMvigor211 randomized trial (Powles et al.) | IMvigor211 urothelial-carcinoma RCT |
| Expanded | `mice::toenail` | CRAN: mice | 3.18.0 | GPL (>= 2) | 1,908 | 0 | `treatment` | `outcome` | incidence | Documented multicenter randomized dermatology trial | Toenail-infection dermatology RCT (canonical; also appears as faraway::toenail) |
| Expanded | `ISwR::alkfos` | CRAN: ISwR | 1.5 | GPL (>= 2) | 43 | 1 | `grp` | `c3-c24 (repeated measures)` | continuous | Documented randomized Tamoxifen oncology trial | Tamoxifen breast-cancer RCT |
| Expanded | `invGauss::d.oropha.rec` | CRAN: invGauss | 1.6 | GPL (>= 2) | 192 | 7 | `treatm` | `time / status` | survival | Documented RTOG randomized oropharynx-carcinoma trial | RTOG oropharyngeal-carcinoma RCT |
| Expanded | `lava::bmd` | CRAN: lava | 1.8.1 | Apache License 2.0 | 112 | 1 | `group` | `bmd` | continuous | Documented: 112 girls randomized to receive calcium or placebo | Pediatric calcium/bone-density RCT |
| Expanded | `mhazard::anemia` | CRAN: mhazard | 0.1.1 | GPL (>= 2) | 64 | 2 | `Treatment` | `Time / Censored` | survival | Documented real randomized hematology trial (CSPMTX vs MTX) | Anemia chemotherapy RCT |
| Expanded | `isdals::cornyield` | CRAN: isdals | 2.0-9 | GPL-2 | 8 | 0 | `variety / fertilizer` | `yield` | continuous | Documented: randomly assigned to the 8 plots | Corn-yield agricultural RCT |
| Expanded | `lqmm::labor` | CRAN: lqmm | 1.5.8 | GPL (>= 2) | 358 | 0 | `trt` | `pain` | continuous | Documented Davis (1991) randomized labor-pain trial | Labor-pain medication RCT (canonical; also appears as Qtools::labor) |
| Expanded | `LongCART::ACTG175` | CRAN: LongCART | 3.2 | GPL (>= 2) | 6,417 | 14 | `treat` | `cd4 / cens / days` | continuous | Documented real randomized ACTG175 AIDS clinical trial | ACTG175 AIDS trial (canonical; also appears reduced/reformatted across JM/JMbayes/JMbayes2/JSM as 'aids') |
| Expanded | `mixor::schizophrenia` | CRAN: mixor | 1.2 | GPL (>= 2) | 437 | 0 | `TxDrug` | `imps79 / imps79b / imps79o` | ordinal | Documented NIMH Schizophrenia Collaborative Study, randomized to one of four medications | NIMH schizophrenia drug RCT (canonical; also appears as vcrpart::schizo, remiod::schizo) |
| Expanded | `mixor::SmokeOnset` | CRAN: mixor | 1.2 | GPL (>= 2) | 1,556 | 0 | `cc / tv (2x2 factorial)` | `smkonset / event` | survival | Documented: school randomized to social-resistance curriculum / media intervention | TV School & Family Smoking Prevention Project |
| Expanded | `mixor::SmokingPrevention` | CRAN: mixor | 1.2 | GPL (>= 2) | 1,600 | 0 | `cc / tv` | `thksord / thksbin` | ordinal | Documented same TV School & Family Smoking Prevention trial, companion outcome | TV School & Family Smoking Prevention Project (companion dataset) |
| Expanded | `MNM::beans` | CRAN: MNM | 1.0-4 | GPL (>= 2) | 24 | 0 | `Treatment (6-level) / Block` | `y1 / y2 / y3` | count | Documented randomized block experiment, six treatments | Bean randomized block field trial |
| Expanded | `moderate.mediation::newws` | CRAN: moderate.mediation | 0.0.12 | GPL-2 | 694 | 0 | `treat` | `depression` | continuous | Documented NEWWS Riverside randomized welfare-to-work trial | NEWWS Riverside welfare-to-work RCT (canonical; also appears as rmpw::Riverside) |
| Expanded | `mosaicData::HELPrct` | CRAN: mosaicData | 0.20.4 | GPL (>= 2) | 453 | 0 | `treat` | `mcs / pcs` | continuous | Documented HELP randomized clinical trial | HELP clinical trial, substance-abuse patients |
| Expanded | `mosaicData::Mites` | CRAN: mosaicData | 0.20.4 | GPL (>= 2) | 47 | 0 | `treatment` | `outcome` | incidence | Documented: randomly allocated to infestation or no-infestation groups | Spider-mite infestation RCT |
| Expanded | `multiDimBio::Nuclei` | CRAN: multiDimBio | 1.2.5 | GPL (>= 3) | 71 | 0 | `stress x vinclozolin (2x2)` | `(14 brain-region measures)` | continuous | Documented: dyads randomly chosen to receive chronic restraint stress | Rat brain-stress 2x2 factorial RCT |
| Expanded | `nlme::Alfalfa` | CRAN: nlme | 3.1-171 | GPL (>= 2) | 72 | 0 | `Variety / Date` | `Yield` | continuous | Documented Snedecor & Cochran randomized split-plot trial | Alfalfa split-plot field trial |
| Expanded | `nlme::Assay` | CRAN: nlme | 3.1-171 | GPL (>= 2) | 60 | 0 | `sample / dilut (split-block)` | `logDens` | continuous | Documented randomized split-block bioassay | Split-block bioassay experiment |
| Expanded | `nlmeU::armd0` | CRAN: nlmeU | 0.71.7 | GPL-2 | 1,107 | 0 | `treat.f` | `visual` | continuous | Documented randomized multi-center ARMD trial (interferon-alpha vs placebo) | ARMD macular-degeneration RCT |
| Expanded | `nlmeU::prt.subjects` | CRAN: nlmeU | 0.71.7 | GPL-2 | 63 | 0 | `prt.f` | `iso.fo / spec.fo` | continuous | Documented Progressive Resistance Randomized Trial | Progressive resistance-training RCT |
| Expanded | `PASWR::Aggression` | CRAN: PASWR | 1.1.1 | GPL (>= 2) | 16 | 0 | `(paired: violence/noviolence)` | `aggression score` | ordinal | Documented: one child randomly selected to view violent shows, matched-pair | TV-violence/aggression matched-pair RCT (Gibbons 1997) |
| Expanded | `PASWR::Ratbp` | CRAN: PASWR | 1.1.1 | GPL (>= 2) | 12 | 0 | `group` | `mmHg` | continuous | Documented: treatment group chosen at random | Rat blood-pressure drug RCT |
| Expanded | `PASWR::Swimtimes` | CRAN: PASWR | 1.1.1 | GPL (>= 2) | 28 | 0 | `diet` | `seconds` | continuous | Documented: swimmers randomly assigned to follow one of the diets | Swimmer diet-performance RCT |
| Expanded | `PASWR2::EPIDURALF` | CRAN: PASWR2 | 1.7 | GPL (>= 2) | 342 | 0 | `treatment` | `oc (obstructive contacts)` | count | Documented Fisher et al. (2009) Anesth Analg randomized trial | Epidural sitting-position vs hamstring-stretch RCT |
| Expanded | `R4HCR::Acupuncture` | CRAN: R4HCR | 0.1.0 | GPL-3 | 301 | 0 | `group` | `pk5 / change` | continuous | Documented Vickers et al. (2004) BMJ randomized trial | Acupuncture-for-headache RCT |
| Expanded | `R4HCR::Facemasks` | CRAN: R4HCR | 0.1.0 | GPL-3 | 216 | 0 | `mask comparison (crossover)` | `delta (O2 saturation)` | continuous | Documented MERIT crossover RCT (Jones et al. 2023 BMJ Open) | Face-mask exercise crossover RCT |
| Expanded | `powerSurvEpi::Oph` | CRAN: powerSurvEpi | 0.1.4 | GPL (>= 2) | 354 | 0 | `group` | `times / status` | survival | Documented Berson et al. (1993) Arch Ophthalmol randomized trial | Vitamin A/E retinitis-pigmentosa RCT |
| Expanded | `pscl::RockTheVote` | CRAN: pscl | 1.5.9 | GPL-2 | 85 | 0 | `treated` | `r / n (turnout)` | proportion | Documented Green & Vavreck (2008) cluster-randomized field experiment | Cable-TV voter-mobilization cluster RCT |
| Expanded | `QDComparison::Microfinance` | CRAN: QDComparison | 0.1.0 | GPL (>= 2) | 6,811 | 0 | `x` | `y (rupees borrowed)` | continuous | Documented Banerjee et al. (2015) AEJ:Applied randomized evaluation | Microfinance-access RCT, Hyderabad |
| Expanded | `quantreg::uis` | CRAN: quantreg | 6.1 | GPL (>= 2) | 575 | 0 | `TREAT` | `TIME / CENSOR` | survival | Documented: 'Treatment Randomization Assignment' field, UIS drug-treatment trial | UIS drug-treatment RCT |
| Expanded | `RCT2::india` | CRAN: RCT2 | 0.1.0 | GPL (>= 3) | 10,072 | 0 | `Z` | `Y (hospital expenditure)` | continuous | Documented real two-stage randomized village health-intervention field experiment | Village health-intervention RCT, India |
| Expanded | `RCT2::jd` | CRAN: RCT2 | 0.1.0 | GPL (>= 3) | 13,103 | 0 | `assigned` | `emploidur / cdi` | incidence | Documented real two-stage randomized labor-market field experiment, France | Labor-market job-placement RCT, France |
| Expanded | `RESIDE::IST` | CRAN: RESIDE | 0.1.0 | GPL (>= 2) | 19,435 | 0 | `RXASP / RXHEP` | `(death/dependency outcomes)` | incidence | Documented International Stroke Trial, large randomized aspirin/heparin trial | International Stroke Trial (IST) |
| Expanded | `Rfit::quail` | CRAN: Rfit | 0.25.1 | GPL (>= 2) | 39 | 0 | `treat (4-level)` | `ldl` | continuous | Documented: 39 quail randomized to one of four cholesterol-lowering treatments | Quail cholesterol-treatment RCT |
| Expanded | `Rlab::magnet` | CRAN: Rlab | 4.0 | GPL (>= 2) | 6 | 0 | `volt (2-level, blocked)` | `force` | continuous | Documented randomized complete block electromagnet physics experiment | Electromagnet physics RCBD |
| Expanded | `randomizationInference::reading` | CRAN: randomizationInference | 1.0.5 | GPL (>= 2) | 66 | 0 | `Group (3-level)` | `Post1 / Diff1` | continuous | Documented: 66 students randomly assigned to one of three reading-comprehension methods | Reading-comprehension teaching-method RCT |
| Expanded | `RPEXE.RPEXT::data2` | CRAN: RPEXE.RPEXT | 0.1.0 | GPL (>= 2) | 118 | 0 | `group` | `time / censor` | survival | Documented Randomized Phase II Trial (Adelson et al. 2016) | Phase II oncology RCT |
| Expanded | `rqlm::mch` | CRAN: rqlm | 0.1.0 | GPL (>= 2) | 500 | 0 | `x` | `Y / y` | count | Documented cluster-randomized trial (Mori et al. 2015 PLoS One) | Cluster-RCT, 18 clusters |
| Expanded | `s20x::teach.df` | CRAN: s20x | 3.7.9 | GPL (>= 2) | 30 | 0 | `method` | `lang` | continuous | Documented: randomly allocated into three groups | Teaching-method RCT |
| Expanded | `s20x::thyroid.df` | CRAN: s20x | 3.7.9 | GPL (>= 2) | 16 | 0 | `group` | `thyroid` | continuous | Documented: randomly assigned | Thyroid treatment RCT |
| Expanded | `sanon::cpain` | CRAN: sanon | 1.6 | GPL (>= 2) | 193 | 0 | `treat` | `response (5-level)` | ordinal | Documented multicenter randomized clinical trial | Chronic-pain multicenter RCT |
| Expanded | `sanon::sebor` | CRAN: sanon | 1.6 | GPL (>= 2) | 167 | 0 | `treat` | `score1-3 (6-level)` | ordinal | Documented randomized clinical trial | Seborrhea treatment RCT |
| Expanded | `sanon::skin` | CRAN: sanon | 1.6 | GPL (>= 2) | 172 | 0 | `treat` | `res1-3 (5-level)` | ordinal | Documented randomized clinical trial | Skin-condition treatment RCT |
| Expanded | `scidesignR::silkdat` | CRAN: scidesignR | 0.1.0 | GPL (>= 2) | 48 | 0 | N/A -- 4-factor DOE | `mass_change / removed_sericin_pct` | continuous | Documented: randomized run number (Bucciarelli et al. 2021) | Silk-processing factorial DOE |
| Expanded | `SingleCaseES::Kelley2015` | CRAN: SingleCaseES | 0.7.1 | GPL (>= 3) | 54 | 0 | `condition` | `pre / post` | continuous | Documented randomized control trial | Kelley (2015) intervention RCT |
| Expanded | `SixSigma::ss.data.doe1` | CRAN: SixSigma | 0.9-7 | GPL (>= 3) | 16 | 0 | N/A -- 3-factor DOE | `score` | continuous | Documented factorial DOE with randomized order | Six Sigma factorial DOE |
| Expanded | `Sleuth2::case0101` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 47 | 0 | `Treatment` | `Score` | continuous | Documented real randomized experiment (Statistical Sleuth textbook case) | Statistical Sleuth case0101 RCT |
| Expanded | `Sleuth2::case0301` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 52 | 0 | `Treatment` | `Rainfall` | continuous | Documented real randomized cloud-seeding experiment (Sleuth textbook) | Statistical Sleuth case0301 RCT |
| Expanded | `Sleuth2::case0402` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 28 | 0 | `Treatmt` | `Time (+ Censor)` | survival | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth case0402 RCT |
| Expanded | `Sleuth2::case0501` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 349 | 0 | `Diet (6-level)` | `Lifetime` | continuous | Documented real randomized diet-longevity experiment (Sleuth textbook) | Statistical Sleuth case0501 RCT |
| Expanded | `Sleuth2::case0601` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 70 | 0 | `Handicap (5-level)` | `Score` | continuous | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth case0601 RCT |
| Expanded | `Sleuth2::case1301` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 96 | 0 | `Treat (6-level) / Block` | `Cover` | proportion | Documented real randomized block field experiment (Sleuth textbook) | Statistical Sleuth case1301 RCT |
| Expanded | `Sleuth2::case1302` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 29 | 0 | `Treat / Company (block)` | `Score` | continuous | Documented real randomized block experiment (Sleuth textbook) | Statistical Sleuth case1302 RCT |
| Expanded | `Sleuth2::case1402` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 30 | 0 | N/A -- 3-factor | `Forrest / William` | continuous | Documented real randomized factorial experiment (Sleuth textbook) | Statistical Sleuth case1402 RCT |
| Expanded | `Sleuth2::case1602` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 20 | 0 | `Order (crossover)` | `Hifiber / Lofiber` | continuous | Documented real randomized crossover experiment (Sleuth textbook) | Statistical Sleuth case1602 RCT |
| Expanded | `Sleuth3::ex0112` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 14 | 0 | `Diet` | `BP` | continuous | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth ex0112 RCT |
| Expanded | `Sleuth3::ex0211` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 122 | 0 | `Group` | `Lifetime` | survival | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth ex0211 RCT |
| Expanded | `Sleuth3::ex0331` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 36 | 0 | `Supplement` | `Iron` | proportion | Documented real randomized supplement experiment (Sleuth textbook) | Statistical Sleuth ex0331 RCT |
| Expanded | `Sleuth2::ex0429` | CRAN: Sleuth2 | 2.0-9 | GPL-2 | 12 | 0 | `Exercise` | `Age` | continuous | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth ex0429 RCT |
| Expanded | `Sleuth3::ex0431` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 58 | 0 | `Group` | `Survival (+ Censor)` | survival | Documented real randomized experiment (Sleuth textbook) | Statistical Sleuth ex0431 RCT |
| Expanded | `Sleuth3::ex0432` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 15 | 0 | `crossover` | `Marijuana / Placebo` | count | Documented real randomized crossover experiment (Sleuth textbook) | Statistical Sleuth ex0432 RCT |
| Expanded | `Sleuth3::ex0518` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 30 | 0 | `Treatment (6) / Day` | `Protein` | continuous | Documented real randomized block experiment (Sleuth textbook) | Statistical Sleuth ex0518 RCT |
| Expanded | `Sleuth3::ex1014` | CRAN: Sleuth3 | 1.0-5 | GPL-2 | 25 | 0 | `Cu x Zn` | `Protein` | continuous | Documented real randomized factorial experiment (Sleuth textbook) | Statistical Sleuth ex1014 RCT |
| Expanded | `smbdata::beetles` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 40 | 0 | `Treatment (4)` | `Eggs` | count | Documented: completely randomized experiment | Beetle-egg-laying CRD experiment |
| Expanded | `smbdata::biomassc` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 48 | 0 | N/A -- 2x3x2 factorial | `C` | continuous | Documented randomized factorial biomass experiment | Biomass carbon factorial DOE |
| Expanded | `smbdata::calcium` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 20 | 0 | `Calcium (4)` | `Length` | continuous | Documented randomized calcium-dose experiment | Calcium-dose growth RCT |
| Expanded | `smbdata::calibrate` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 24 | 0 | `Prep x Conc` | `Absorbance` | continuous | Documented randomized calibration factorial experiment | Chemistry calibration factorial DOE |
| Expanded | `smbdata::cotton` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 25 | 0 | `Herbicide x Insecticide` | `Weight` | continuous | Documented randomized agricultural factorial experiment | Cotton herbicide/insecticide factorial DOE |
| Expanded | `smbdata::cuttings` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 25 | 0 | `Type (5) / Size (3), blocked` | `Yield` | continuous | Documented randomized block experiment | Plant-cutting-type RCBD |
| Expanded | `smbdata::demethylation` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 24 | 0 | `Dose (6)` | `Normal / Total` | proportion | Documented randomized dose-response experiment | Demethylation dose-response RCT |
| Expanded | `smbdata::forage` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 12 | 0 | `N (4), blocked` | `Yield` | continuous | Documented randomized block forage-nitrogen trial | Forage nitrogen RCBD |
| Expanded | `smbdata::heights` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 24 | 0 | `Dose (6)` | `Height` | continuous | Documented randomized dose-response growth trial | Plant-height dose-response RCT |
| Expanded | `smbdata::herbicide` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 135 | 0 | `Herbicide (3), blocked` | `Fwt` | continuous | Documented randomized block herbicide trial | Herbicide RCBD field trial |
| Expanded | `smbdata::ladybird` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 72 | 0 | `Host x Cadaver x Ladybird` | `Infected / Live` | proportion | Documented randomized factorial entomology experiment | Ladybird-infection factorial DOE |
| Expanded | `smbdata::lupintrial` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 42 | 0 | `Line (14), blocked` | `OilYield` | continuous | Documented randomized block lupin field trial | Lupin oil-yield RCBD |
| Expanded | `smbdata::potato` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 20 | 0 | `Fungicide (5), blocked` | `Yield` | continuous | Documented randomized block potato-fungicide trial | Potato fungicide RCBD |
| Expanded | `smbdata::prey` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 60 | 0 | `Sex x Prey, blocked` | `Eaten / Total` | proportion | Documented randomized block predation experiment | Predation-rate factorial RCBD |
| Expanded | `smbdata::tgw` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 24 | 0 | `Trt (2x2)` | `TGW` | continuous | Documented randomized factorial grain-weight trial | Thousand-grain-weight factorial DOE |
| Expanded | `smbdata::voltage` | CRAN: smbdata | 1.0.1 | GPL (>= 2) | 18 | 0 | `Voltage (9), blocked` | `Km` | continuous | Documented randomized block voltage experiment | Voltage-response RCBD |
| Expanded | `SMPracticals::arithmetic` | CRAN: SMPracticals | 1.4-3 | GPL (>= 2) | 45 | 0 | `group (5)` | `y` | continuous | Documented: divided at random into 5 groups | Arithmetic-teaching-method RCT |
| Expanded | `SMPracticals::cake` | CRAN: SMPracticals | 1.4-3 | GPL (>= 2) | 270 | 0 | `temp (cooking temperature)` | `y (breaking angle)` | continuous | Documented Cochran & Cox (1959): randomly allocated to be cooked at different temperatures | Cake-baking split-plot RCT (canonical; also appears as faraway::choccake) |
| Expanded | `SMPracticals::marking` | CRAN: SMPracticals | 1.4-3 | GPL (>= 2) | 32 | 0 | `Original (proxy random assignment)` | `mark (out of 80)` | continuous | Documented Lindley (1961): one script taken at random from each batch | Exam-marking randomization experiment |
| Expanded | `SMPracticals::shoe` | CRAN: SMPracticals | 1.4-3 | GPL (>= 2) | 20 | 0 | `material` | `wear` | continuous | Documented: materials allocated randomly to left/right feet, paired | Shoe-material wear paired RCT |
| Expanded | `SMPracticals::teak` | CRAN: SMPracticals | 1.4-3 | GPL (>= 2) | 24 | 0 | `Plant (2) x Root (3), blocked` | `height` | continuous | Documented randomised blocks | Teak-propagation RCBD |
| Expanded | `SpATS::wheatdata` | CRAN: SpATS | 1.0-19 | GPL (>= 3) | 330 | 0 | `geno (107 levels)` | `yield` | continuous | Documented Gilmour et al. (1997) randomized complete block wheat trial | South Australia wheat RCBD |
| Expanded | `splmm::cognitive` | CRAN: splmm | 1.2.0 | GPL (>= 2) | 1,562 | 0 | `treatment (cluster-randomized by school)` | `ravens / arithmetic / vmeaning / dstotal` | continuous | Documented: three schools randomized to each group, Kenya school-lunch intervention | Kenya school-lunch nutrition cluster-RCT |
| Expanded | `SRMData::Jumping` | CRAN: SRMData | 0.1.0 | GPL (>= 3) | 80 | 0 | `Shoes vs Barefoot` | `jumping distance` | continuous | Documented Randomized Cross-Over Study | Barefoot-vs-shoes jumping crossover RCT |
| Expanded | `SRMData::SixMWT` | CRAN: SRMData | 0.1.0 | GPL (>= 3) | 50 | 0 | `Dist20 vs Dist30 (crossover)` | `distance` | continuous | Documented randomized crossover study | Six-minute walk-test crossover RCT |
| Expanded | `Stat2Data::Alfalfa` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 15 | 0 | `Acid (3), blocked by Row` | `Ht4` | continuous | Documented: randomly chose five to get plain water (etc.) | Alfalfa-acid RCBD classroom experiment |
| Expanded | `Stat2Data::AutoPollution` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 36 | 0 | `Type (filter)` | `Noise` | continuous | Documented: cars randomly assigned to get new filter or standard filter | Auto-filter noise RCT |
| Expanded | `Stat2Data::CalciumBP` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 21 | 0 | `Treatment (Calcium/Placebo)` | `Decrease (BP)` | continuous | Documented: each randomly assigned to treatment or control group | Calcium/blood-pressure RCT |
| Expanded | `Stat2Data::Contraceptives` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 44 | 0 | `Treatment (crossover)` | `EE` | continuous | Documented: allocated randomly to one of two treatment sequences | Contraceptive-drug crossover RCT |
| Expanded | `Stat2Data::CrackerFiber` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 48 | 0 | `Fiber (4), crossover, randomized order` | `Calories` | continuous | Documented randomized-order crossover trial | Cracker-fiber caloric-intake crossover RCT |
| Expanded | `Stat2Data::FruitFlies2` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 201 | 0 | `Mated / Alone` | `Lifespan / Activity` | continuous | Documented: randomly assigned / randomly allocated | Fruit-fly mating-lifespan RCT |
| Expanded | `Stat2Data::FruitFlies` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 125 | 0 | `Treatment (5 groups)` | `Longevity` | continuous | Documented Hanley & Shapiro (1994) classic fruit-fly longevity study | Fruit-fly longevity RCT |
| Expanded | `Stat2Data::Meniscus` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 18 | 0 | `Method (3 repair methods)` | `FailureLoad / Displacement / Stiffness` | continuous | Documented: randomly assigned to one of three treatments | Meniscus-repair biomechanics RCT |
| Expanded | `Stat2Data::Milgram` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 37 | 0 | `Results (3 vignette groups)` | `Score (ethics rating)` | continuous | Documented: 'using chance,' each teacher assigned to one of three treatment groups | Milgram-vignette ethics-rating survey RCT |
| Expanded | `Stat2Data::MusicTime` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 60 | 0 | `Music (3 conditions), within-subject` | `TimeGuess / Accuracy` | continuous | Documented: order randomized for each participant | Music-condition time-perception RCT |
| Expanded | `Stat2Data::PigFeed` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 12 | 0 | `Antibiotic x B12 (2x2)` | `WgtGain` | continuous | Documented: scientist randomly assigned 12 pigs | Pig-feed factorial RCT |
| Expanded | `Stat2Data::Popcorn` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 12 | 0 | `Brand` | `Unpopped` | continuous | Documented: randomly chose which brand would go first | Popcorn-brand comparison RCT |
| Expanded | `Stat2Data::SandwichAnts` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 48 | 0 | `Bread x Filling x Butter` | `Ants` | count | Documented randomized factorial design | Sandwich-ant-attraction factorial DOE |
| Expanded | `Stat2Data::TipJoke` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 211 | 0 | `Card (Ad/Joke/None)` | `Tip` | incidence | Documented: waiter randomly assigned coffee-ordering customers | Restaurant tip-card RCT |
| Expanded | `Stat2Data::WeightLossIncentive` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 38 | 0 | `Group (Control/Incentive)` | `WeightLoss / Month7Loss` | continuous | Documented randomized trial, financial incentives (JAMA 2008) | Weight-loss financial-incentive RCT |
| Expanded | `Stat2Data::WordMemory` | CRAN: Stat2Data | 2.0.5 | GPL (>= 2) | 40 | 0 | `Abstract x Frequent (2x2, within-subject)` | `Percent recalled` | continuous | Documented: words presented in a randomized order | Word-memory-recall RCT |
| Expanded | `stepp::aspirin` | CRAN: stepp | 2.0-4 | GPL (>= 2) | 1,121 | 0 | `DOSE (0/81/325mg)` | `AD / AL (adenoma occurrence)` | incidence | Documented real Polyp Prevention Study aspirin RCT (Baron et al. 2003 NEJM) | Aspirin polyp-prevention RCT |
| Expanded | `stepp::bigCI` | CRAN: stepp | 2.0-4 | GPL (>= 2) | 2,685 | 0 | `trt (letrozole/tamoxifen)` | `event / time` | survival | Documented BIG 1-98 randomized breast-cancer trial | BIG 1-98 breast-cancer RCT |
| Expanded | `surrosurv::gastadv` | CRAN: surrosurv | 1.1.1 | GPL (>= 2) | 4,069 | 0 | `trt (control/chemo)` | `timeT / statusT` | survival | Documented pooled patient-level data, 20 real randomized advanced-gastric-cancer trials | Pooled advanced-gastric-cancer RCTs |
| Expanded | `survSAKK::esophagus` | CRAN: survSAKK | 1.0 | GPL (>= 2) | 297 | 0 | `arm` | `OS.time / OS.event` | survival | Documented SAKK 75/08 phase III randomized trial (Ruhstaller et al. 2018) | SAKK 75/08 esophageal-cancer RCT |
| Expanded | `texmex::liver` | CRAN: texmex | 2.4.8 | GPL (>= 3) | 606 | 0 | `dose (A/B/C/D)` | `ALT.M / AST.M / ALP.M / TBL.M` | continuous | Documented AstraZeneca randomized, blind, parallel-group 4-dose trial | Liver-function dose-response RCT |
| Expanded | `TukeyC::SPET` | CRAN: TukeyC | 1.1-6 | GPL (>= 2) | 24 | 0 | `treatments (8: 7 legume cover crops + maize)` | `yield` | continuous | Documented real agricultural-textbook randomized block design (Gomes 1990) | Legume cover-crop RCBD |
| Expanded | `vegan::pyrifos` | CRAN: vegan | 2.7-1 | GPL (>= 2) | 132 | 0 | `dose (0/0.1/0.9/6/44 ug/L insecticide)` | `invertebrate abundance (primary taxon)` | count | Documented: twelve mesocosms allocated at random to treatments | Insecticide mesocosm ecotoxicology RCT |
| Expanded | `VGAMdata::belcap` | CRAN: VGAMdata | 1.1-13 | GPL (>= 2) | 797 | 0 | `school (6 treatments, cluster-randomized)` | `dmfte` | count | Documented: six treatments randomized to six separate schools | BELCAP dental-caries cluster RCT |
| Expanded | `WA::hfaction_cpx12` | CRAN: WA | 0.1.0 | GPL (>= 2) | 741 | 0 | `trt` | `time / status` | survival | Documented HF-ACTION randomized trial (O'Connor et al. 2009 JAMA) | HF-ACTION heart-failure exercise RCT (canonical; also appears reformatted as WR::hfaction_cpx9/non_ischemic, rmt::hfaction) |
| Expanded | `wgaim::phenoCxR` | CRAN: wgaim | 2.0.3 | GPL (>= 2) | 200 | 0 | `Type` | `shoot / znconc` | continuous | Documented: randomly allocated to pots, randomised complete block design | Wheat glasshouse zinc RCBD |
| Expanded | `wgaim::phenoRxK` | CRAN: wgaim | 2.0.3 | GPL (>= 2) | 520 | 0 | `Genotype / Type` | `yld / tgw` | continuous | Documented: randomly allocated to 520 plots using a randomized complete block design | Wheat field RCBD |
| Expanded | `wgaim::phenoSxT` | CRAN: wgaim | 2.0.3 | GPL (>= 2) | 456 | 0 | `Type` | `myield` | continuous | Documented two-phase randomized wheat field/milling trial | Two-phase wheat field/milling RCT |
| Expanded | `wooldridge::apple` | CRAN: wooldridge | 1.4-2 | GPL (>= 2) | 660 | 0 | `regprc / ecoprc` | `reglbs / ecolbs` | continuous | Documented: prices facing a family randomly determined, real experimental survey data | Eco-labeled-apple randomized-price survey experiment |
| Expanded | `WRS2::electric` | CRAN: WRS2 | 1.1-6 | GPL (>= 2) | 192 | 0 | `Group` | `Posttest` | continuous | Documented classic Electric Company educational RCT (Gelman & Hill 2007) | Electric Company educational-TV RCT |
| Expanded | `WWGbook::ratpup` | CRAN: WWGbook | 1.0.4 | GPL (>= 2) | 322 | 0 | `treatment (High/Low/Control dose)` | `weight` | continuous | Documented: 30 female rats randomly assigned to receive one of three doses | Rat-pup dose-response RCT |

## Two tiers: Core (GCP) vs. Expanded (AWS)

The 32 originally-sourced datasets (2026-09-14) are **Core**. Two hundred
thirty more, added 2026-09-15/16 across five rounds, are **Expanded**:
1. `student_test_data`, `PES_analysis_science` (2 datasets).
2. `ghana_bednet`, `laviiswa`, `mkvtrial`, `mwanza_stdtrial`, `pneumovac`,
   `share`, `thrio`, `zamstar` (8 datasets) — the Hayes & Moulton
   *Cluster Randomised Trials* textbook dataverse, found via a repository
   search.
3. `tanf`, `gastric_cancer_trial_df`, `liver_cirrhosis_prednisone_df`,
   `WSCdata`, `immigrationconjoint` (5 datasets) — a CRAN package-metadata
   (Title/Description keyword) search.
4. `epilepsy_RCT_tbl_df`, `sulphinpyrazone_tbl_df`, `immdef`, `Gbsg_df`,
   `seguro`, `ajps`, `pakistan`, `berberis_treatment`, `PowderyMildew`,
   `train1`, `opt`, `supraclavicular` (12 datasets) — a **deep CRAN scan**
   pre-filtered to CRAN's ~9,700 `LazyData`-true packages, scored against
   a broad domain keyword set, with the top 692 actually inspected —
   genuinely more thorough than round 3's title/description-only search,
   but still bounded (only ~289 of those 692 were actually opened, per
   its own honestly-reported coverage tally).
5. **203 more datasets** (2026-09-16) — a **true exhaustive CRAN sweep**,
   run after the user pointed out round 4's remaining limitation: even
   the `LazyData` pre-filter and keyword scoring could still miss real
   candidates. Round 5 instead checked **all 25,043 scanned CRAN packages'
   actual source tarballs for a real `/data` directory** — no title,
   description, or `LazyData`-field filtering of any kind, just "does the
   tarball contain one." **11,173 of 25,043 packages (44.6%) had a real
   `/data` directory**; excluding the 630 already covered by earlier
   rounds left **10,543 genuinely new candidates**. Every dataset each of
   those packages ships was mechanically harvested (tarball download +
   extract + `load()`/`fread()` the data directly + parse the `.Rd` help
   page, all without `install.packages()`) into a evidence file, then
   every entry was reviewed by 5 parallel Haiku-model forks against the
   same rigor bar used throughout this table (explicit textual
   confirmation of random assignment to a real completed study; excludes
   synthetic/simulated data, random *sampling* language, aggregate/
   meta-analysis tables, and duplicates). **Coverage: all 10,543
   candidates' `/data` contents were harvested; of the resulting ~13,150
   dataset-level rows, every one flagged for a "random"-language match
   (2,607) was reviewed in full, plus a ~600-row random spot-check of the
   non-flagged rows (0 additional confirms found there, validating the
   flag as a reliable — not just convenient — prioritization signal).**
   236 candidates were confirmed before cross-batch/existing-table
   deduplication; **203 survived** as genuinely new, non-duplicate
   entries (many real studies turned up repackaged across 2-4 different
   CRAN packages — e.g. the Freireich 1963 leukemia trial, the NIMH
   schizophrenia trial, several Yates agricultural field trials, the
   HF-ACTION cardiology trial — only one canonical copy of each was kept,
   noted in that row's Description). One real, flagged-but-excluded lead
   from round 4 remains open for a future pass:
   `public.ctn0094data`/`ctn0094extra` (NIDA CTN-0027/CTN-0030 opioid-use-
   disorder trial, n=4,691, real randomized `treatment` column, but its
   outcome lives in a separate weekly-urine-screen "pattern" table needing
   real decoding before it's table-ready).
   **Version-number caveat:** each new CRAN dataset's recorded package
   version reflects whatever a review fork observed at the moment it
   checked (a multi-hour sweep run by many parallel workers) — CRAN
   packages get updated continuously, so several of these version strings
   no longer match the package's current release, and a few appear to
   have been mis-transcribed outright (values that never existed on CRAN
   at all). This does not affect actually fetching the data:
   `download_experimental_datasets.R`'s `cran_download_dataset_as_csv()`
   tries the pinned version first, falls back to CRAN's `Archive/` for
   that exact version if superseded, and falls back to the current
   release as a last resort — safe because a package that exists mainly
   to ship one classic dataset essentially never changes that dataset's
   content across version bumps, only its surrounding code/docs. Treat
   the **Version** column for round-5 entries as "approximately when
   verified," not a hard-pinned guarantee, unlike the exact-installed-
   version pinning used elsewhere in this table.

This split exists specifically so the two cloud-credit grant applications
can scope independently: **GCP's application is scoped to Core only** (its
cost estimate — capped at the program's $5,000 ceiling — was computed
against the 32-dataset/45-pair Core table and is unaffected by any later
Expanded additions); **AWS's application is scoped to Core + Expanded**
(uncapped, so it's the natural place to fold in new datasets as they're
added — see `AWS/application.md`'s cost estimate, recomputed against the
Expanded total). Adding a dataset in the future: default to Expanded-only
unless there's a specific reason GCP's capped, already-submitted-or-
near-final scope should grow too.

## Response-type coverage against EDI's 6 supported types

Recomputed 2026-09-16 directly from the table above (each dataset counted
once per type it covers; most cover more than one). Core counts are the
2026-09-14 baseline; Expanded adds all 230 2026-09-15/16 datasets on top
(rounds 1-4: 27 datasets; round 5, the exhaustive CRAN sweep: 203 more).

| Response Type | # Core | # Expanded (Core+new) | Notes |
|---|---|---|---|
| incidence | 16 | 43 | Round 5 alone added 16 more (e.g. `Matching::GerberGreenImai`, `mediation::jobs`, `mice::toenail`, `Stat2Data::TipJoke`) |
| survival | 9 | 47 | Round 5 alone added 32 more — the largest single-type gain, mostly classic oncology/cardiology RCTs (e.g. `LongCART::ACTG175`, `stepp::bigCI`, `BGPhazard::gehan`) |
| continuous | 8 | 129 | Round 5 alone added 115 more, dominated by textbook-companion packages (Sleuth2/Sleuth3, Stat2Data, smbdata, SMPracticals — dozens of small classic DOE/RCBD field and lab experiments) |
| count | 7 | 26 | Round 5 alone added 17 more (mostly agricultural/entomological CRD/RCBD trials, e.g. `hnp`'s 7 datasets) |
| ordinal | 3 | 17 | Round 5 alone added 11 more independent sources (e.g. `sanon`'s 3 datasets, `mixor::schizophrenia`) — Core's 3 ordinal sources traced to just 2 packages; this is now a genuinely well-populated type |
| proportion | 2 | 16 | Round 5 alone added 12 more independent sources (e.g. `DoseFinding::migraine`, `Sleuth2::case1301`, `hnp`'s proportion-type datasets) — was the thinnest Core gap, now the best-diversified relative to its Core baseline |

**Expanded-tier total: 262 datasets (32 Core + 230 new), 278
dataset×response-type pairs.**

Full Core datasets-by-type listing:

| Response Type | # Datasets | Datasets |
|---|---|---|
| incidence | 16 | `colon`, `respiratory`, `strep_tb`, `indo_rct`, `laryngoscope`, `ResumeNames`, `charitable`, `mobilization`, `social`, `secrecy`, `vouchers`, `welfare`, `savings`, `immig`, `hiv`, `sanitation` |
| survival | 9 | `veteran`, `ovarian`, `colon`, `pbc`, `diabetic`, `bladder1`, `rhDNase`, `cgd`, `udca` |
| continuous | 8 | `laryngoscope`, `lalonde.exp`, `STAR`, `mm_randhie`, `rhDNase`, `charitable`, `monitoring_works`, `savings` |
| count | 7 | `polyps`, `laryngoscope`, `mm_randhie`, `bladder1`, `solder`, `secrecy`, `vouchers` |
| ordinal | 3 | `respdis`, `strep_tb`, `licorice_gargle` |
| proportion | 2 | `monitoring_works`, `sanitation` |

`proportion` and `ordinal` were the thinnest Core gaps (2 and 3 datasets,
with all 3 Core ordinal sources tracing back to just two CRAN packages,
`geepack`/`medicaldata`). Rounds 1-4 alone had already added 4 more
independent ordinal sources and 2 more independent proportion sources;
round 5's exhaustive sweep added 11 and 12 more respectively — both
response types went from "traceable to essentially one origin" to
genuinely well-diversified across dozens of unrelated studies/domains.

Beyond closing the ordinal/proportion gaps, the Expanded rounds introduce:
a **stepped-wedge cluster-randomized design** (`thrio`) and a
**randomized-conjoint/factorial design** (`immigrationconjoint`, `train1`)
not otherwise represented in this table's Design column; a real
**time-varying-covariate** survival structure
(`liver_cirrhosis_prednisone_df`); a real **treatment-crossover** survival
structure (`immdef`, the Concorde AZT trial); and a large expansion of
domains beyond the Core table's medicine/economics/sociology coverage —
education psychology, environmental economics, public-benefits policy,
political science, ecology, plant pathology/agriculture, anesthesiology,
obstetrics, and (via round 5's textbook-companion veins) a wide swath of
classic agricultural DOE/RCBD experiments spanning entomology, plant
breeding, and food science.

## Notable extremes for grid-design purposes

- `respdis` has **zero baseline covariates** — usable for
  testing unadjusted designs/inference, not covariate-adjusted ones.
- `mobilization` (n ≈ 2.47M) is far larger than anything else in this set;
  `welfare` (p ≈ 209) is far wider.

**Sample-size cap: subsample every dataset here to `n = 500`** before use,
matching `_dataset_load.R`'s existing `max_n_dataset` convention (which
already varies by script purpose: 148 for fast correctness-only testing in
`comprehensive_tests.R`, 500 for actual design/power comparison in
`large_power_simulations.R` — 500 is the right precedent to reuse here,
since this is design-comparison work, not a crash test). This isn't just
a cost-saving measure: covariate imbalance under any reasonable
randomization scheme shrinks at roughly `1/sqrt(n)`, so the gap between a
sophisticated design (matching, rerandomization, biased-coin) and plain
Bernoulli randomization is largest at small-to-moderate n and becomes
scientifically uninteresting well before n reaches the thousands. Running
`mobilization` at its full ~2.47M would not demonstrate anything a design
comparison needs to show. Capping every dataset uniformly at 500 also
reduces the AWS/GCP compute estimates elsewhere in this project below
what was budgeted, since per-replicate cost scales with n.
