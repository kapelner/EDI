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
install.packages(c("medicaldata", "qte", "AER", "stevedata"))

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

## ICPSR access via `R/package_metadata/icpsr_download.R`

The CRAN package `icpsrdata` was evaluated and **dropped from the plan**:
it's confirmed broken, unfixable by credential/option changes. It POSTs to
a hardcoded `http://www.icpsr.umich.edu/cgi-bin/bob/zipcart2?...` URL —
plain HTTP, a legacy CGI-bin path. ICPSR has since moved to a
Keycloak-based OAuth/OIDC login (`login.*.icpsr.umich.edu/realms/icpsr/...`),
a structurally different flow the old package cannot perform at all. It
is not listed in "Required R packages" above and should not be installed
for this purpose.

**Use `R/package_metadata/icpsr_download.R` instead** — a self-contained
`httr2`-based script, no extra package dependency beyond `httr2`:

```r
source("R/package_metadata/icpsr_download.R")
icpsr_download_simple(project_id = 36138, download_dir = "some/local/dir")
```

Two functions it defines:
- `get_icpsr_credentials()` — reads `getOption("icpsr_email")` /
  `getOption("icpsr_password")` (falling back to the `ICPSR_EMAIL` /
  `ICPSR_PASS` environment variables), and stops with a clear message if
  neither is set.
- `icpsr_download_simple(project_id, download_dir)` — runs the full
  session-cookie → login-form → authenticate → locate-file →
  stream-download sequence and returns the path of the downloaded file.

**Where credentials go: your personal `~/.Rprofile` (home directory),
never this repo.** `.Rprofile` in `$HOME` is sourced automatically at the
start of every R session on the machine, is not part of any git working
tree, and is never at risk of being committed or pushed. Add one line:

```r
options("icpsr_email" = "your_email@example.com", "icpsr_password" = "your_password")
```

**Do not** put credentials in any file under this repository (not in a
`.Rprofile` at the repo root, not in `_dataset_load.R`, not in this
document, not in `icpsr_download.R` itself) — anything in the working
tree can end up in a commit even with good intentions, and ICPSR
credentials have no business in version control.

**Known limitation (found 2026-09-14): not yet proven reliable
end-to-end.** Diagnosed and fixed two real bugs versus the reference
implementation this was translated from (github.com/Xarthisius/openicpsr):
it targeted `test.openicpsr.org` / `login.uat.icpsr.umich.edu` (staging
hosts — a bare GET to those 403s with no login logic involved), corrected
here to `www.openicpsr.org`; and the site also 403s any request missing
realistic browser headers (User-Agent/Accept/Accept-Language), also
fixed. But the corrected script got past step 1 once (HTTP 200), then
403'd on an identical retry minutes later — indicative of bot-detection/
rate-limiting on ICPSR's side rather than a remaining URL/header bug, not
something a persistent-cookie-jar-free stateless script defeats
automatically. See the script's own header comment for the current,
up-to-date status. Until this is fully solved and verified, a manual
browser download from icpsr.umich.edu is the reliable fallback path for
any specific file actually needed.

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

Some J-PAL/openICPSR studies on Harvard Dataverse require a one-time
"Guestbook" response (name/position/intended-use) before a file can be
downloaded — this is a usage-tracking requirement from the depositor, not
a license restriction (the license itself, e.g. CC0, is unaffected).
**Confirmed working end-to-end 2026-09-14**, unlike the still-unreliable
ICPSR OAuth flow documented above:

1. `GET https://dataverse.harvard.edu/api/guestbooks/{guestbookId}` — read
   the required fields and any custom questions (multiple-choice options
   included) without submitting anything.
2. `POST https://dataverse.harvard.edu/api/access/datafile/{fileId}` with
   a JSON body `{"guestbookResponse": {"name":..., "email":...,
   "institution":..., "position":..., "answers":[{"id":Q_ID,"value":...}]}}`
   — returns `{"data":{"signedUrl": "..."}}`, not the file itself.
3. `GET` that signed URL **immediately** (in the same script run — it
   appears short-lived; a signed URL generated in one script invocation
   and used in a separate one 401'd, while using it inline in the same
   call worked) to get the actual file bytes.

This is unrelated to `icpsr_download.R`'s ICPSR-proper OAuth flow (a
different site, different auth mechanism entirely) — use this pattern
specifically for Harvard-Dataverse-hosted (including J-PAL/openICPSR)
files, and the other script for classic ICPSR archive files.

Three more CC0-licensed candidates found alongside the one above, not yet
pulled through this flow: "Getting to the Top of Mind: How Reminders
Increase Savings" (`doi:10.7910/DVN/UJD5OP`), "Increasing the Electoral
Participation of Immigrants" (`doi:10.7910/DVN/DDCNEW`), and "HIV
Prevention Among Youth" (`doi:10.7910/DVN/CVOPZL`) — same guestbook
mechanism should apply.

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

| Dataset | Source | Version | License | n | p (covariates) | Response Variable | Response Type | Design | Description |
|---|---|---|---|---|---|---|---|---|---|
| `veteran` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 137 | 5 | `time`/`status` | survival | Unknown; arms 69/68 ≈ equal → assumed BCRD | VA Lung Cancer trial |
| `ovarian` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 26 | 3 | `futime`/`fustat` | survival | Unknown; arms 13/13 exact → assumed BCRD | ovarian cancer trial |
| `colon` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 1,858 | 10 | `time`/`status` (`etype`) | survival + incidence | Unknown; 3 arms 315/310/304 ≈ equal → assumed BCRD | colon cancer adjuvant chemo trial; recurrence gives an incidence endpoint alongside death |
| `pbc` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 418 | 16 | `time`/`status` | survival | Unknown; arms 158/154 ≈ equal → assumed BCRD | Mayo Clinic D-penicillamine trial for primary biliary cirrhosis |
| `respdis` | CRAN: geepack | 1.3.13 | GPL (>= 3) | 111 | 0 | `y1`–`y4` | ordinal (3-level) | Unknown; arms 57/54 ≈ equal → assumed BCRD | randomized respiratory-disorder trial (poor/good/excellent), no baseline covariates recorded |
| `respiratory` | CRAN: geepack | 1.3.13 | GPL (>= 3) | 111 (444 obs) | ~4 | `outcome` | incidence | Unknown, possibly stratified by clinical center (data carries a `center` field); arms 27/29 ≈ equal → assumed BCRD | same respiratory trial family, binary good/poor version |
| `strep_tb` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 107 | 6 | `radiologic_6m`/`rad_num`/`improved` | ordinal (6-level) + incidence | **Documented: simple random allocation via sealed envelopes/random numbers** (Bradford Hill design, 1948) — one of the first formally randomized trials | 1948 Streptomycin-for-TB trial, one of the first modern RCTs |
| `licorice_gargle` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 235 | 8 | `extubation_cough` (+6 more timepoints) | ordinal (3-level, ×7 timepoints) | Unknown; arms 117/118 ≈ equal → assumed BCRD | licorice gargle before intubation, repeated cough/pain severity measures |
| `polyps` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 22 | 3 | `number3m`/`number12m` | count | Unknown; arms 11/11 exact → assumed BCRD | Sulindac-for-polyp-prevention trial |
| `indo_rct` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 602 | ~27 | `outcome` | incidence | Unknown; arms 307/295 ≈ equal → assumed BCRD | indomethacin trial for post-ERCP pancreatitis prevention |
| `laryngoscope` | CRAN: medicaldata | 0.2.0 | MIT + file LICENSE | 99 | 5 | `intubation_overall_S_F`; `total_intubation_time`; `attempts`/`failures` | incidence + continuous + count | Unknown; arms 49/50 ≈ equal → assumed BCRD | video vs. standard laryngoscope trial — one real RCT yielding all three response types at once |
| `lalonde.exp` | CRAN: qte | 2.0.0 | GPL-3 | 445 | 10 | `re78` | continuous | Unknown; arms 260/185 unequal → assumed Bernoulli | LaLonde (1986) NSW job-training experiment, real earnings outcome |
| `STAR` | CRAN: AER | 1.2.17 | GPL-2 \| GPL-3 | 11,598 | ~31 (panel, K–3) | `readk`/`read1`/…, `mathk`/`math1`/… | continuous | **Documented: randomized within-school** (blocked by school, not a pooled draw) — 3 arms 2194/1900/2231, unequal overall but explained by the blocking | Tennessee Project STAR class-size experiment, achievement test scores |
| `ResumeNames` | CRAN: AER | 1.2.17 | GPL-2 \| GPL-3 | 4,870 | ~20 | `call` | incidence | Unknown (resume-level name randomization, not checked this session for exact race/gender balance); tentatively assumed BCRD given the study's stated intent to balance names | Bertrand & Mullainathan (2004) hiring-discrimination field experiment — sociology/labor economics domain |
| `mm_randhie` | CRAN: stevedata | 1.8.0 | GPL-2 | 3,957 (baseline) | 10 | `ftf`/`totadm`; `out_inf`/`inpdol_inf`/`tot_inf` | count + continuous | **Documented: intentional unequal-probability assignment** across plans (759/881/1022/1295), stratified by income/family size to balance cost against power | RAND Health Insurance Experiment; visit/admission counts + expenditures |
| `diabetic` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 394 | 3 | `time`/`status` | survival | **Documented: within-subject paired randomization** — one eye per patient randomized to laser, the other control; not a between-subject BCRD/Bernoulli case at all | Diabetic Retinopathy Study |
| `bladder1` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 294 | ~6 | `number`/`recur` (`rtumor`) | count + survival | Unknown; 3 arms 48/32/38 unequal → assumed Bernoulli | Byar bladder-cancer recurrence trial (thiotepa/placebo), real recurrent-event counts |
| `rhDNase` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 767 | ~3 | `fev`; `ivstart`/`ivstop` | continuous (`fev`) + survival | Unknown; arms 325/322 ≈ equal → assumed BCRD | Pulmozyme cystic-fibrosis trial; lung function (continuous) + exacerbation timing |
| `cgd` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 203 | ~9 | `tstart`/`tstop`/`status` | survival | **Documented: stratified by clinical center, permuted-block randomization within center** (International CGD Cooperative Study); arms 65/63 | International CGD Cooperative Study (gamma interferon), recurrent infection timing |
| `udca` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 170 | ~3 | `death.dt`/`tx.dt`/`hprogress.dt`/`varices.dt`/`ascites.dt`/`enceph.dt`/`double.dt` | survival | Unknown; arms 84/86 ≈ equal → assumed BCRD | ursodeoxycholic acid trial for liver disease — multiple distinct real endpoints (death/transplant/histologic progression/varices/ascites/encephalopathy) |
| `solder` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 900 | 4 factors | `skips` | count (`skips`) | N/A — multi-factor factorial DOE, not a 2-arm design; doesn't fit the BCRD/Bernoulli framework | real industrial DOE for solder-skip defects — manufacturing/engineering domain |
| `charitable` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 50,083 | ~51 | `out_amountgive`/`out_gavedum` | continuous + incidence | **Documented: 1/3 control, 2/3 treatment** (16687/33396), intentionally unequal per Karlan & List (2007) | Karlan & List (2007) charitable-giving matching-grant field experiment |
| `mobilization` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 2,474,927 | ~20 | `vote02` | incidence | **Documented: budget-constrained, small treatment fraction by design** (large voter-file field experiment; treated arms 29990/29982 are tiny relative to the 1.8M+ control pool) | Arceneaux/Gerber/Green voter mobilization experiment |
| `social` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 180,002 | ~63 (census-tract merge) | `outcome_voted` | incidence | **Documented: originally 5 groups** (control + 4 treatment conditions — civic duty/Hawthorne/self/neighbors); the 99999/80003 split shown here is the pooled treatment-vs-control dummy, not the per-arm design | Gerber/Green/Larson (2008) social-pressure voter-turnout experiment |
| `secrecy` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 3,744 | ~19 | `turnoutindex_12` (+ `v_*` vote-history indicators) | count + incidence | Unknown; arms 1289/2455 unequal → assumed Bernoulli | ballot-secrecy mobilization experiment |
| `vouchers` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 25,330 | ~70 (many fixed-effect dummies) | `INSCHL`/`FINISH6`/`FINISH7`/`FINISH8`; `REPT`/`TOTSCYRS` | incidence + count | **Documented: oversubscribed lottery among program applicants** (PACES, Colombia) — voucher availability was budget-limited, not an equal-probability design (7149/18180) | Angrist et al. (2002) Colombia private-schooling voucher lottery |
| `welfare` | GitHub: itamarcaspi/experimentdatar | commit `f71a9d0` | CC0 | 36,501 | ~209 (GSS-derived) | `y` | incidence | **Documented: GSS split-ballot design** — standard survey-methodology simple random assignment (17048/19453) | Green & Kern (2012) GSS survey-wording experiment ("welfare" vs. "assistance to the poor") |
| `monitoring_works` | Dataverse: `doi:10.7910/DVN/LRDXHX` (openICPSR) | v3.3 | CC0 1.0 | 113 schools (57 treated/56 comparison, analyzed sample), 2,896 students, 49,381 school-days | school-level | `validday` (`ValidDay.tab`); `post_math_v`/`post_lang_v`/`post_total_v`/… (`Posttest.tab`) | **proportion** (derived: valid/open days ÷ total days per school) + continuous (post-test scores) | **Documented (verified against the study's own paper, Duflo & Hanna 2006 p.5): 60 of 120 eligible schools randomly selected as treatment, remainder as comparison — simple random allocation, not matched pairs.** 57/56 reflects the final analyzed sample after some attrition from the original 60/60 design. (Correction: an earlier version of this note incorrectly claimed baseline-matched-pair randomization — not supported by the paper.) | Duflo & Hanna (2006), later published as Duflo, Hanna & Ryan (2012) — camera-monitoring vs. control for teacher attendance, one-teacher schools, India. Fetched via the Dataverse guestbook API, not the ICPSR OAuth flow. |
| `savings` | Dataverse: `doi:10.7910/DVN/UJD5OP` (IPA); file `analysis_dataallcountries.tab` | v1.0 | CC0 1.0 | 13,560 | ~50 | `quant_saved`/`saved_formal` | continuous (`quant_saved`) + incidence (`saved_formal`) | N/A — multi-factor (incentive type × framing × reminder), not a simple 2-arm design | Karlan et al., "Getting to the Top of Mind" — reminder-message savings field experiment, multiple countries |
| `immig` | Dataverse: `doi:10.7910/DVN/DDCNEW`; file `analysis.dta` | v1.2 | CC0 1.0 | 23,836 | ~800 (wide, census-merged) | `registered`; `vote2010_1st`/`_2nd`, `vote2011_1st`/`_2nd` | incidence | **Documented: stratified and clustered** — data carries explicit `cluster`/`stratum` fields; not simple Bernoulli/BCRD | GOTV field experiment on immigrant electoral participation, France |
| `hiv` | Dataverse: `doi:10.7910/DVN/CVOPZL`; file `Phase2_sample_list.dta` | v2.0 | CC0 1.0 | 10,636 | ~10 | not confirmed this session — actual biomarker outcome lives in the larger, not-yet-loaded `bio_*.dta` files; `Phase2_sample_list.dta` only has sampling/eligibility flags (`sampledVCT`/`sampledCONDOMS`) | incidence (+ biomarker-derived measures in larger, not-yet-loaded files) | **Documented: stratified with sampling weights** — data carries explicit `strata_ITsampling`/`weight_sample` fields; unequal-probability by design | HIV prevention RCT (VCT + condom distribution), rural Kenya |
| `sanitation` | Dataverse: `doi:10.7910/DVN/GJDUTV` (IPA); file `BD-SAN-FINAL.dta` | v2.3 | CC0 1.0 | 18,254 households | ~40 | `r4_any_own`/`r4_any_access`; `r4_any_od_adults`/`r4_any_od_male`/`r4_any_od_female` | incidence (latrine ownership/access, open defecation) + derivable proportion (household-level OD rate) | **Documented: cluster-randomized at the village level** (`vid`/`cid` cluster fields), 5-category multi-arm design (`treat_cat_1`–`5`, likely crossing supply-/demand-side interventions) — not a simple 2-arm case | Guiteras, Levinsohn & Mobarak — sanitation-investment cluster-RCT, Bangladesh |

## Response-type coverage against EDI's 6 supported types

Recomputed 2026-09-14 directly from the table above (each dataset counted
once per type it covers; most cover more than one).

| Response Type | # Datasets | Datasets |
|---|---|---|
| incidence | 16 | `colon`, `respiratory`, `strep_tb`, `indo_rct`, `laryngoscope`, `ResumeNames`, `charitable`, `mobilization`, `social`, `secrecy`, `vouchers`, `welfare`, `savings`, `immig`, `hiv`, `sanitation` |
| survival | 9 | `veteran`, `ovarian`, `colon`, `pbc`, `diabetic`, `bladder1`, `rhDNase`, `cgd`, `udca` |
| continuous | 8 | `laryngoscope`, `lalonde.exp`, `STAR`, `mm_randhie`, `rhDNase`, `charitable`, `monitoring_works`, `savings` |
| count | 7 | `polyps`, `laryngoscope`, `mm_randhie`, `bladder1`, `solder`, `secrecy`, `vouchers` |
| ordinal | 3 | `respdis`, `strep_tb`, `licorice_gargle` |
| proportion | 2 | `monitoring_works`, `sanitation` |

`proportion` was a confirmed zero-source gap for most of this session —
`monitoring_works` (derived: valid/open days ÷ total days per school) and
`sanitation` (derived: household-level open-defecation rate) closed it,
both via aggregation from real day-/individual-level binary indicators
rather than a directly-reported proportion field.

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
