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

## Required R packages

All of the following are free and installable without a data-use agreement
or application process.

```r
# CRAN packages
install.packages(c("medicaldata", "qte", "AER", "stevedata",
                    "whatifbandit", "cjoint", "WSCdata", "DigestiveDataSets",
                    "NeuroDataSets", "CardioDataSets", "rpsftm", "ForCausality",
                    "experiment", "GK2011", "endorse", "ecoteach", "epifitter",
                    "callback"))

# survival and geepack are common dependencies and may already be installed;
# install explicitly if not:
install.packages(c("survival", "geepack"))

# experimentdatar is GitHub-only, NOT on CRAN -- install.packages() will fail
install.packages("devtools")
devtools::install_github("itamarcaspi/experimentdatar")
```

Notes on packages that looked like they should be on CRAN but are not:
- **`lalonde`** as a standalone package name does not exist on CRAN (GitHub-
  only, `jjchern/lalonde`). The LaLonde NSW data used here comes from the
  CRAN `qte` package instead (`lalonde.exp`), which keeps the experimental
  and observational (PSID) comparison arms as separate, clearly labeled
  data frames.
- **`experimentdatar`** is GitHub-only; there is no CRAN fallback for it.

## Downloading everything: `R/package_metadata/icpsr_download.R`

**As of 2026-09-15 this one script downloads and normalizes every
Dataverse-sourced dataset in the table below** (everything not already
covered by an installed CRAN/GitHub R package — see "Required R packages"
above for those). Clone the repo, optionally set guestbook-identity
options (see below — sensible defaults exist, so this is optional), and
run:

```r
Rscript R/package_metadata/icpsr_download.R
```

or, sourced interactively, to fetch a subset:

```r
source("R/package_metadata/icpsr_download.R")
download_all_datasets(datasets = c("sanitation", "student_test_data"))
```

**Every downloaded file is normalized to plain CSV** (`.tab` retabbed,
`.dta` read via `haven` and stripped of value/variable labels via
`zap_labels()`, zip-bundled files unzipped and the target member located
recursively) **and the whole output directory is packed into one
`R/package_metadata/icpsr_data.tar.bz2`** — uniform format, and
compressed CSV text is small, so this keeps disk usage low compared to
the previous mix of `.zip`/`.tab`/`.dta`/`.csv` files sitting loose
(two of the source zips alone are 99MB and 221MB; only one small member
file is kept from each, the rest is discarded after conversion). By
default the loose CSVs are deleted after archiving; call
`icpsr_data_extract()` to unpack them again when you actually need to
read one.

The CRAN package `icpsrdata` was evaluated and **dropped from the plan**:
it's confirmed broken, unfixable by credential/option changes. It POSTs to
a hardcoded `http://www.icpsr.umich.edu/cgi-bin/bob/zipcart2?...` URL —
plain HTTP, a legacy CGI-bin path. ICPSR has since moved to a
Keycloak-based OAuth/OIDC login (`login.*.icpsr.umich.edu/realms/icpsr/...`),
a structurally different flow the old package cannot perform at all. It
is not listed in "Required R packages" above and should not be installed
for this purpose.

`icpsr_download.R` implements **two distinct mechanisms**, used per
dataset:

1. **Harvard Dataverse guestbook/direct download** — confirmed working
   end-to-end 2026-09-14/15, and what every dataset in the manifest
   actually uses. No ICPSR account or login of any kind: Dataverse's own
   "Guestbook" (a usage-tracking questionnaire some depositors require,
   unrelated to the file's license) is satisfied with plain identity
   fields, not credentials. Functions: `dataverse_dataset_files()`,
   `dataverse_download_file()`, `dataverse_download_by_filename()`,
   `download_zip_member_as_csv()`. See the script's own header comment
   for the exact request/response shape, including a real gotcha found
   2026-09-15: guestbook "options"-type answers must be submitted as the
   option's **string text**, not its numeric id — the numeric form looks
   plausible but 500s server-side with an opaque `ClassCastException`.
2. **Classic ICPSR archive proper** (`icpsr_download_simple()`, kept for
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
document, not in `icpsr_download.R` itself) — anything in the working
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
via `icpsr_download.R`, under the researcher's own account, and keep the
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
ICPSR OAuth flow documented above — this is now `icpsr_download.R`'s
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

This is unrelated to `icpsr_download.R`'s ICPSR-proper OAuth flow (a
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

## Two tiers: Core (GCP) vs. Expanded (AWS)

The 32 originally-sourced datasets (2026-09-14) are **Core**. Twenty-seven
more, added 2026-09-15 across four rounds, are **Expanded**:
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
   run after the user pointed out round 3's limitation: a metadata-keyword
   search misses packages that ship real experimental data without
   describing it that way. Round 4 instead pre-filtered to CRAN's ~9,700
   `LazyData`-true packages (i.e. packages that ship a `/data` directory at
   all), scored ~2,420 of those against a broad domain keyword set, and
   for the top 692 actually installed and inspected each package's real
   shipped datasets and help-page documentation — not just title text.
   **Coverage caveat, reported honestly, across the three parallel
   ~231-package batches this was split into:** batch A never got past a
   ~12-package title-triaged slice (bulk-install attempts across the full
   231 repeatedly stalled and were abandoned); batch B read all 231
   packages' descriptions in full (avoiding another bulk-install stall)
   and installed/deep-inspected the ~6 that survived that read; batch C
   completed all 229 packages via a background install-and-check scan
   (423 datasets inspected, 120 install failures, 12 with no datasets at
   all, 34 flagged for explicit "random" language in their help pages).
   One real, verified-but-unintegrated lead surfaced in batch C:
   `public.ctn0094data`/`ctn0094extra` (NIDA CTN-0027/CTN-0030 opioid-use-
   disorder trial, n=4,691, real 6-level randomized `treatment` column) —
   its outcome lives in a separate weekly urine-drug-screen "pattern"
   table that needs real decoding into a clean response variable before
   it's table-ready; flagged for a future pass, not silently included.
   **Net: genuinely more thorough than round 3's pure keyword search, but
   still a bounded, uneven pass** — not literally exhaustive over all
   25,038 CRAN packages or even the full 9,700 `LazyData` pool.

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

Recomputed 2026-09-15 directly from the table above (each dataset counted
once per type it covers; most cover more than one). Core counts are the
2026-09-14 baseline; Expanded adds all 27 2026-09-15 datasets on top.

| Response Type | # Core | # Expanded (Core+new) | Independent new sources this round (4) |
|---|---|---|---|
| incidence | 16 | 27 | `sulphinpyrazone_tbl_df`, `seguro`, `train1`, `opt` |
| survival | 9 | 15 | `immdef`, `Gbsg_df`, `supraclavicular` |
| continuous | 8 | 14 | `ajps`, `opt` |
| count | 7 | 9 | `epilepsy_RCT_tbl_df` |
| ordinal | 3 | 6 | `pakistan` (5-level), `berberis_treatment` (3-level) |
| proportion | 2 | 4 | `PowderyMildew` |

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
`geepack`/`medicaldata`). The Expanded rounds add **4 more independent
ordinal sources** (`laviiswa`, `pakistan`, `berberis_treatment` — none
sharing a package/collection with each other or with Core) and **2 more
independent proportion sources** (`zamstar`, `PowderyMildew`) — response
types that were previously each traceable to essentially one origin are
now covered from several unrelated studies/domains.

**Expanded-tier total: 32 Core + 27 new = 59 datasets, 45 + 30 = 75
dataset×response-type pairs.** Beyond closing the ordinal/proportion gaps,
the Expanded rounds introduce: a **stepped-wedge cluster-randomized
design** (`thrio`) and a **randomized-conjoint/factorial design**
(`immigrationconjoint`, `train1`) not otherwise represented in this
table's Design column; a real **time-varying-covariate** survival
structure (`liver_cirrhosis_prednisone_df`); a real **treatment-crossover**
survival structure (`immdef`, the Concorde AZT trial); and several new
domains (education psychology, environmental economics, public-benefits
policy, political science, ecology, plant pathology/agriculture,
anesthesiology, obstetrics) alongside the Core table's existing medicine/
economics/sociology coverage.

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
