# Fix: `InferenceSurvivalKKWeibullMarginal` Jackknife Estimate Has Catastrophic Single-Fold Outliers

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-26`. Found 2026-09-24, independently
> surfaced TWICE — by a survival-class cluster investigation (into CI
> coverage/bias broadly) and separately by a dedicated `biased_estimate`
> audit sweep — converging on the same class and the same raw outlier
> values, which is strong corroboration this is real, not an artifact of
> either investigation's method.

## The finding

`compute_jackknife_estimate()` for `InferenceSurvivalKKWeibullMarginal`
shows severe apparent "bias" when tested via a one-sample t-test/Wilcoxon
signed-rank test on (estimate − truth): mean bias −0.080. But RMSE is
**2.154** — roughly **27× the bias magnitude**. For an estimand whose
typical scale is ~0.2-0.3, this ratio means the "bias" finding is not a
systematic mean shift; it's a small number of individual jackknife
replicates with catastrophic errors dominating the RMSE while barely
moving the mean.

Direct inspection of the raw jackknife errors confirms this: the top
absolute errors include values of **−38.0 and +17.5** — two orders of
magnitude outside the estimand's normal range, not "large but plausible"
outliers.

## Root cause (confirmed 2026-10-08)

A deterministic seed-1, 24-subject KK14 fixture reproduced the failure. The
leave-matched-set-out fold for rows 2 and 17 removes the treatment arm's only
observed event: the retained control arm has five events and the retained
treatment arm has zero. The old fit nevertheless reported convergence and
returned 17.1343525, while the other folds were 0.91--1.66. Thus the failure
is an estimator-specific identifiability bug: a resampled marginal-Weibull
fit with no observed event in one treatment arm silently produced a wild
finite coefficient.

## Corroboration: caught by both the coverage/bias investigations AND validates the Wilcoxon-test design choice

This class's jackknife estimate was independently flagged by two separate
investigations approaching it from different checks (survival-class
cluster sweep; dedicated `biased_estimate` sweep), both landing on the
same raw outlier values — this is not a single investigation's artifact.
It's also a clean, concrete real-data demonstration of exactly the
"t-test alone can be blind to outlier-driven anomalies" risk this
session's `biased_estimate` check redesign (t-test + Wilcoxon
signed-rank, ACAT-combined) was built to catch — worth keeping as a
reference example if this check's design is ever questioned or revisited.

## Implemented fix

`InferenceSurvivalKKWeibullMarginal` now checks that both treatment arms have
at least one positive-weight observed event before fitting. The check covers
ordinary subset refits (including jackknife, nonparametric bootstrap, and
subsampling) and weighted Bayesian-bootstrap refits. A failed check returns
`NA_real_` with typed reason
`kk_weibull_marginal_treatment_arm_no_events`; the shared jackknife summary
then reports `jackknife_nonfinite_replicate_estimates`. The invalid fold is
not dropped, because the delete-one jackknife formula requires every deletion.
This is preferable to an arbitrary coefficient cutoff and leaves all
well-identified folds unchanged.

## TODOs

- [x] TODO-1: Locate the jackknife loop for this class (likely in
  `R/EDI/R/inference_survival_KK_weibull_marginal.R` or a shared
  jackknife-family helper — confirm exact location) and trace exactly
  which fold(s) produce the −38.0/+17.5-class outliers. Reproduce directly
  via `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
- [x] TODO-2: Confirm the degenerate-configuration hypothesis (e.g. a
  cluster/covariate-pattern check on which specific held-out observation
  produces the outlier) or find the actual mechanism if different.
- [x] TODO-3: Design and implement the guard — following the same
  "detect near-singular/degenerate, return NA or exclude rather than a
  wild finite value" philosophy as TODO-4's fix, adapted for a
  per-fold jackknife context rather than a single information-matrix
  inverse.
- [x] TODO-4: Verify the fix doesn't change jackknife estimates for
  well-behaved folds (bit-for-bit or floating-point tolerance) — only the
  degenerate folds' handling should change.
- [x] TODO-5: Re-run the bias check (t-test + Wilcoxon on estimate −
  truth) and confirm both the mean bias and RMSE return to reasonable
  values, and that RMSE is no longer wildly disproportionate to the bias
  magnitude. **Done 2026-10-14:** reran the installed comprehensive harness
  on the exact historical dataset/design (`diamonds` / `KK21stepwise`),
  beta=0, for 25 replications under each formula (`~1`, `~.`), filtering to
  `compute_jackknife_estimate`. All 50 estimates were finite. For `~1`,
  mean bias=0.0324, RMSE=0.0848, max absolute error=0.1926 (t-test p=0.0539,
  Wilcoxon p=0.0596); for `~.`, mean bias=-0.0087, RMSE=0.0522, max absolute
  error=0.1337 (t-test p=0.4179, Wilcoxon p=0.5360). Neither formula shows
  the prior catastrophic −38/+17.5-scale outliers or an RMSE remotely
  disproportionate to mean bias. This is a focused 25-rep recheck, not the
  full comprehensive-results regeneration requested by TODO-8.
- **Artifact provenance audit 2026-10-16:** the ignored filtered output
  `R/package_tests/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalKKWeibullMarginal_dataset-diamonds_beta-0_family-jackknife.csv`
  contains 150 rows (25 replications × 2 formulas × 3 jackknife methods),
  stamped 2026-10-14 with `github_commit_id=2942b68f6d7ddfe846de0762a2fa628396f72fc3`.
  The event-per-arm guard is present in that commit's source, so these are
  post-fix focused-recheck rows. The artifact corroborates TODO-5 only; it
  is filtered, gitignored, and does not satisfy TODO-8's full
  comprehensive-results regeneration.
- [x] TODO-6: Add a permanent regression test constructing a fixture
  likely to produce a degenerate jackknife fold (small clusters, as
  identified by TODO-2) and asserting no fold's estimate exceeds a
  sanity-scale bound relative to the full-sample fit.
- [x] TODO-7: Check whether other jackknife-based methods across the
  package (not just this one class) share the same unguarded-fold
  vulnerability — this session's TODO-4 already found the same
  "unguarded numerical operation → wild finite value" shape recurring
  across several unrelated C++ kernels, so a package-wide jackknife-loop
  sweep may be warranted rather than treating this as isolated to one
  class.
- [ ] TODO-8: Regenerate affected `comprehensive_tests` CSV rows once
  fixed and installed (only after install, not before).

  **Regeneration matrix/provenance (2026-10-16):** the canonical
  `comprehensive_tests_results_nc_1_survival.csv` currently contains 300
  matching pre-fix rows: reps 1–50 × formulas `~1` and `~.` × the three
  jackknife operations (`compute_jackknife_estimate`,
  `compute_jackknife_wald_two_sided_pval`, and
  `compute_jackknife_wald_confidence_interval`). All match response
  `survival`, design `KK21stepwise`, class
  `InferenceSurvivalKKWeibullMarginal`, dataset `diamonds`, and
  `beta_T=0`. Their timestamps span 2026-08-26 through 2026-08-30 and their
  provenance is limited to commits `ec003b7eeefab2e40b64b6412f4fc127dee4efac`,
  `d41880c19a6c8a32a9515b1c19331d73e74f0b3e`, and
  `842da415c7e17697a118fb2e3dd50908c17ae8ba`; none is post-fix.

  The harness selector for this matrix is
  `Rscript package_tests/comprehensive_tests.R 50 1 survival KK21stepwise InferenceSurvivalKKWeibullMarginal diamonds 0 NA jackknife`
  (arguments: repetitions, cores, response, design, class, dataset, beta,
  rep selector, family). This produces a filtered CSV, not an update to the
  canonical survival CSV. The existing filtered file already holds the 150
  post-fix TODO-5 rows (25 reps × 2 formulas × 3 methods), and the harness
  appends rows; rerunning into that path would duplicate overlapping reps.
  Therefore the 50-rep run must target an isolated fresh output and any
  canonical reconciliation must be a separately approved, controlled merge.
  TODO-8 remains open pending the user's separately managed rebuilt/installed
  package, isolated full-matrix regeneration, and authorized canonical merge.

  **Read-only artifact recheck 2026-10-18:** the filtered focused-recheck CSV
  remains ignored by `.gitignore:85`, has 150 data rows (151 lines including
  the header), mtime 2026-10-14, and SHA-256
  `20fd07e48f6cadd5e2912174c9f6727e43239e1345e4c753cb658bffd9edccc6`.
  The canonical survival-results file's mtime remains 2026-09-27. This confirms
  the earlier post-fix focused artifact is intact and that no broader
  reconciliation has occurred; it does not satisfy TODO-8. No result file was
  changed during this recheck.

**Current-source focused recheck 2026-10-20:** at checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded `R/EDI` with
`pkgload::load_all(..., compile = FALSE)` and reran the two registered
correctness tests: `test-kk-weibull-marginal-jackknife-arm-event-guard-reference.R`
(16 assertions) and `test-kk-weibull-marginal-no-events-and-fit-failed-guards-reference.R`
(4 assertions). All 20 passed with no failures, warnings, or skips. These
current-checkout R-source tests used the installed EDI 1.0.3 native artifact;
no local compile/install was run. `gh run list --commit` for this HEAD returned
no run; the latest successful full correctness run is at an older SHA. This
refreshes focused regression evidence but does not satisfy TODO-8's required
50-rep, two-formula-by-three-operation post-fix output regeneration or
canonical reconciliation.

**Installed-package focused recheck 2026-10-20:** ran the two same registered
tests directly with `testthat::test_file()` (without `pkgload`) against
`EDI 1.0.3` from
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The jackknife
arm-event guard test passed 16 assertions; the no-events/fit-failed guard
test passed 4 (20 total; 0 failures, warnings, or skips). The installed
package DLL was `libs/EDI.so`, MD5
`dfd5bf4384b5a0cc0d430fd70dab2a59`. This confirms the focused guard behavior
with the currently installed native artifact; it does not prove the required
50-rep matrix or provenance-stamped canonical reconciliation. No build,
install, or result-file operation was performed.

**Isolated full-matrix installed-package recheck 2026-10-20:** ran
`EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo26-matrix-9NDMSE Rscript R/package_tests/comprehensive_tests.R 50 1 survival KK21stepwise InferenceSurvivalKKWeibullMarginal diamonds 0 NA jackknife`
into a fresh `/tmp` directory. The 300-row CSV has 300 unique `id`s and all
300 statuses are `ok`: 50 reps for each of `~1`/`~.` and each of the three
jackknife operations; all estimates and CI endpoints are finite, p-values
range from 0.009 to 0.992, and error messages are missing/empty. Estimate
errors (`result_1 - coverage_truth`) were descriptive as follows: `~1` bias
−0.0437, RMSE 0.0892, max absolute error 0.2265; `~.` bias 0.0090, RMSE
0.0537, max absolute error 0.1504. No catastrophic −38/+17-scale outlier
reappeared; no acceptance threshold was inferred from these summaries.
Artifact SHA-256:
`b017896390779fd24afed7f3126d8633c65de0bd7b11fbe5b607dcef694fe4ed`.
The available library was EDI 1.0.3 at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, native build stamp
`2026-10-19 23:31:50 IDT`, DLL MD5
`dfd5bf4384b5a0cc0d430fd70dab2a59`, R-devel r90668. CSV
`github_commit_id=4f7a6e4ca82829e880c15a76699701a95e5e83b9` identifies the
checkout harness, not the installed package/DLL source revision. This
advances only the isolated installed-package matrix; do not claim
current-checkout native validation or merge these rows into canonical data.

**Read-only reconciliation preflight, 2026-10-20:** compared the isolated
matrix against the 300 matching pre-fix canonical rows using the full row key
(`rep`, `beta_T`, dataset, response, design, inference class/formula,
`function_run`). Both sides have exactly 300 unique keys with no missing or
extra combinations and all statuses are `ok`; the isolated artifact also has
300 unique row `id`s. `case_id` alone is not a unique row key (only three
distinct values, one per operation). However, the `coverage_truth` values do
not match the old canonical rows: the isolated output has distinct values for
the `~1` and `~.` formulas, while the canonical rows carry the same old value
for both. The harness's TODO-32 formula-aware truth handling is a plausible
reason for the difference, but this preflight did not independently
recompute/validate those truth values. Thus status/key coverage is complete;
an independent truth oracle and explicit review of the truth-value change are
still needed before any canonical merge. This audit was read-only and does
not change TODO-8's separate installed-package/native-provenance gate.

**Formula-specific truth audit 2026-10-20:** the isolated artifact records
`coverage_truth = 0.036465267` for
`InferenceSurvivalKKWeibullMarginal [design_formula=~1]` and
`-0.007431527` for `[design_formula=~.]`, with `beta_T = 0` in both cases.
TODO-32 defines this split: explicit `~1` passes `real_X = NULL` (the
one-synthetic-covariate/no-adjustment MC path), while `~.` passes the real
dataset covariate matrix; a bare label also means the latter. Re-ran
`test-comprehensive-coverage-mc-registry-gaps-reference.R` against the current
checkout harness: 53 assertions passed (0 failures, warnings, or skips),
including the `~.`/bare-label real-covariate dispatch contract. Under the
zero-effect DGP, both formula-specific targets are zero; the recorded finite
MC fits are close to zero and show no sign/scale contradiction. This supports
the formula-aware truth routing and gives no indication that either recorded
truth is wrong, but it is not an exact numerical oracle for the two
single-fit MC values. No truth was regenerated and no canonical data changed.
The historical/native reconciliation gate remains open; these 300 rows must
not be merged on this evidence alone.

**TODO-26 class-specific dispatch regression, 2026-10-21:** broadened the
existing `test-comprehensive-coverage-mc-registry-gaps-reference.R` fixture
with `InferenceSurvivalKKWeibullMarginal` and its `DesignFixedBinaryMatch`
generator. The new case pins that the actual `design_formula=~1` label routes
to `real_X=NULL`, `design_formula=~.` routes to the toy dataset's full `X`,
and a bare class label reuses the adjusted cache entry. A stubbed simulator
also checks the class/design/response/`mc_n=3000` registry fields; it does
not fit models or assert either historical MC truth value. The focused test
passed 76 expectations with the `library(EDI)` attachment suppressed, so it
loaded neither the package nor native code. This closes only the
class-specific formula-routing regression; exact numerical truth review,
authenticated matrix-era R/DLL provenance, and TODO-8 exact-key/canonical
reconciliation remain open. No matrix or canonical artifact was read or
changed.

TODO-8 remains pending until the affected comprehensive-results rows are
regenerated with the user's separately managed rebuilt package. The
repository rule forbids building or installing the checkout during this
audit.

**Matrix-era provenance search, 2026-10-20:** the documented matrix output
directory `/tmp/edi-todo26-matrix-9NDMSE/` contains only the 300-row CSV; no
run-provenance sidecar, install log, or package-source manifest is retained
there. The prepared `/tmp/edi-todo26-ready-BouNHE/` tree contains only its
runbook and no output. The current installed EDI 1.0.3 build (2026-10-20
07:40:04 UTC; DLL SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`)
is later than the matrix artifact and differs from its recorded matrix-era
DLL MD5 `dfd5bf4384b5a0cc0d430fd70dab2a59`. Thus the matrix's `github_commit_id`
cannot retrospectively attest its installed R-layer source, and current
artifacts do not recover that identity. Safe rerun gate: first pin the
post-fix installed package source identity (R-layer file hashes or source
commit), package/library and DLL hashes, and runner/helper hashes in a fresh
run manifest/sidecar; then regenerate into a new isolated directory only
after TODO-56 is terminal. Keep canonical reconciliation separately
authorized. This search did not inspect the CSV payload, rerun the matrix, or
write canonical results.

**Bounded artifact recheck, 2026-10-21:** the declared matrix directory still
contains only the 220,422-byte 300-row CSV (mtime 2026-10-20 03:47:25 +0300;
SHA-256 `b017896390779fd24afed7f3126d8633c65de0bd7b11fbe5b607dcef694fe4ed`),
with no sidecar, install log, or source manifest. The prepared directory still
contains only `RUNBOOK.md`, not a generated result. Thus no retained artifact
adds authenticated installed R-layer identity, an independent oracle for the
two formula-specific Monte Carlo truths, or new exact-key reconciliation
beyond the already documented 300/300-key match to pre-fix rows. A focused
test rerun would not resolve those matrix-artifact gaps, so none was repeated.
The remaining gates are: establish the matrix's post-fix R-source provenance
or regenerate into fresh isolated output with a provenance sidecar; review
the `~1` versus `~.` truth difference against an independent numerical oracle;
then perform the separately authorized exact-key canonical reconciliation.
No CSV rows were parsed, and no simulation, build/install, or canonical write
occurred.

**Read-only exact-key audit, 2026-10-21:** subsequently parsed only the
isolated CSV above (no inference or simulation). Its 300 rows cover the full
declared Cartesian grid: reps 1–50, `beta_T=0`, dataset `diamonds`, response
`survival`, design `KK21stepwise`, both `design_formula=~1` and `~.` class
labels, and all three jackknife operations. Comparing the observed seven-field
key (`rep`, `beta_T`, `dataset`, `response_type`, `design`, `inference_class`,
`function_run`) to that in-memory expected grid produced 300/300 unique keys,
zero missing keys, zero extras, and zero duplicate full keys; `id` is also
unique for all 300 rows. Every replicate has six rows (two formulas × three
operations), every status is `ok`, and there are no nonempty error messages.
For estimate and p-value operations `result_1` is finite in all 50 rows per
formula/operation; for the CI operation both `result_1` and `result_2` are
finite in all 50 rows per formula. The two formula labels each have one
constant but different `coverage_truth`: `0.036465266547781` (`~1`) and
`-0.00743152669119731` (`~.`). This confirms key/status/field completeness,
not correctness of either Monte Carlo truth. The checked-in MC test verifies
formula-aware covariate dispatch, but neither it nor the matrix supplies an
independent exact numerical oracle for those finite-MC values; the matrix also
lacks authenticated installed R-source provenance. Keep the truth review and
separately authorized canonical reconciliation open; no row was changed.

**Zero-effect truth clarification, 2026-10-21:** source review establishes an
analytic target for this matrix's `beta_T=0` stratum: the survival DGP applies
`bt=0` in both arms and the same noise/censoring mechanism, so treatment
assignment is exchangeable under the null. The population null treatment
coefficient is therefore zero for both `~1` and covariate-adjusted `~.` fits;
the adjustment set changes the fit, not the null target. The recorded
`coverage_truth` values (`0.036465266547781` and `-0.00743152669119731`) are
not exact truth values: `COVERAGE_MC_SPEC` uses `mc_n=3000`, while
`compute_mc_coverage_truth_simframe()` runs one W/Y simulation replicate and
returns its single fitted estimate. They are finite-run MC draws around the
known zero target. Here `diamonds` survival starts from the transformed
`log(price)` response in `R/package_tests/_dataset_load.R`; the MC generator in
`R/package_tests/comprehensive_tests.R` applies a treatment shift on the
log-time scale and treatment-independent noise/censoring. The `~1` path uses
synthetic `X`, while `~.` uses the real covariates, but neither changes the
zero treatment-effect target. Accordingly, the extant matrix CSV
(`/tmp/edi-todo26-matrix-9NDMSE/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalKKWeibullMarginal_dataset-diamonds_beta-0_family-jackknife.csv`, SHA-256
`b017896390779fd24afed7f3126d8633c65de0bd7b11fbe5b607dcef694fe4ed`) is
diagnostic only with respect to truth: its serialized `coverage_truth` fields
are one-replicate fitted estimates, not the exact null truth. No coverage
impact is inferred and no canonical value is rewritten. For nonzero
`beta_T`, the source defines the generic target as the fitted least-false/KL-
projection coefficient under this dataset-derived survival and censoring
process; no closed-form truth is documented. This clarifies the null truth
only; it sets no acceptance threshold and does not authorize changing or
reconciling canonical rows. The matrix provenance and canonical reconciliation
gates remain open.

**Independent retained-artifact audit, 2026-10-21:** a shell-only recheck
found the declared matrix CSV at
`/tmp/edi-todo26-matrix-9NDMSE/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalKKWeibullMarginal_dataset-diamonds_beta-0_family-jackknife.csv`
(220,422 bytes; SHA-256
`b017896390779fd24afed7f3126d8633c65de0bd7b11fbe5b607dcef694fe4ed`). The
matrix directory contained only that CSV: no provenance sidecar, install log,
or source manifest. Its full seven-field key has 300/300 unique rows for reps
1–50 × two formulas × three jackknife operations; all 300 rows have
`status=ok`, unique `id`s, and the serialized missing-value marker `NA` in
`error_message`. The recorded `github_commit_id` identifies the harness
checkout, not the installed R-layer source. The prepared path
`/tmp/edi-todo26-ready-BouNHE/` was absent at this recheck (the earlier
runbook-only inventory is historical). The earlier 300/300 comparison is
against the pre-fix canonical cohort and proves key coverage only. Neither
that comparison nor this artifact audit authenticates installed-package
identity or validates the finite-MC `coverage_truth` fields against the exact
zero target; no current canonical merge is authorized. Preserve the separate
source-provenance, truth-review, and explicit canonical-reconciliation gates.

For TODO-7, every ordinary jackknife method reaches the same shared summary in
`inference_all_abstract_jackknife.R`. That summary already treats any nonfinite
fold as nonestimable and retains the raw distribution for diagnosis. No shared
jackknife-loop correction is needed. The finite outlier here arose before that
summary, inside this class's unidentified fit, so the narrow per-estimator
identifiability check is the appropriate fix. Other likelihood families have
different identification conditions and should not inherit this Weibull-arm
event rule mechanically.

## Scope widened 2026-09-24: broad CI undercoverage, not just the jackknife estimate

A fresh full-package audit run cross-validated the `biased_estimate`
finding above (exact match) and ALSO surfaced 8 `low_coverage` findings
for this class not previously tracked here: `compute_asymp_confidence_interval`,
`compute_bayesian_bootstrap_confidence_interval` (plain/`_basic`/`_bca`/`_wald`),
`compute_bootstrap_confidence_interval_studentized`,
`compute_subsampling_confidence_interval`, `compute_wald_confidence_interval`
— all UNDER-coverage, 0.87-0.91, over 237-390 rows each (all firmly
FDR-significant, not borderline). This spans asymptotic AND every
resampling family at once, which argues for a shared cause upstream of
any one estimation method — plausibly the same root mechanism as the
jackknife outliers (a degenerate/near-singular configuration in the
underlying marginal-Weibull fit that inflates variance broadly, not just
in leave-one-out folds), but NOT CONFIRMED to be the same bug — could
also be independent. TODO-1/TODO-2's root-cause trace should check
whether the degenerate-configuration mechanism it finds for the jackknife
loop also explains the general SE/CI machinery's undercoverage, or
whether this needs separate root-causing.

The confirmed mechanism explains resampling draws that omit all events from
one arm, including jackknife, nonparametric-bootstrap/subsampling, and weighted
Bayesian-bootstrap refits. It cannot explain the full-sample asymptotic CI row,
where no deletion or zero-weight draw occurs. That row therefore remains a
separate calibration question rather than evidence for widening this fix.

## Focused validation (2026-10-08)

Using `pkgload::load_all("R/EDI", compile = FALSE)`, 171 focused expectations
passed with no failures, errors, or warnings: the new deterministic regression
(16); existing no-event/backend guards (4); weighted refits (28); shared
jackknife guards (36); CRAN marginal-Weibull tests (9); migration golden tests
(32); cluster-ID cache tests (15); C++/`survreg` agreement and guard tests (19);
and randomization-refit tests (12). No compilation, build, or installation was
performed.

## Post-reinstall installed-package recheck (2026-10-20)

The two focused guard regressions passed against installed EDI 1.0.3:
`test-kk-weibull-marginal-jackknife-arm-event-guard-reference.R` passed 16
assertions and `test-kk-weibull-marginal-no-events-and-fit-failed-guards-reference.R`
passed 4, with no failures, warnings, or skips. The independent estimator
reference `test-kk-weibull-marginal-cpp-and-survreg-fits-cluster-robust-se-agreement-and-guards-reference.R`
also passed all 19 assertions. These bounded tests use installed-package
execution; no build, install, comprehensive regeneration, or canonical write
occurred.

Runtime identity: R `R Under development (unstable) (2026-10-13 r90668)`;
installed package `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`,
version 1.0.3, `Built: R 4.7.0; x86_64-pc-linux-gnu; 2026-10-20 07:40:04 UTC`;
loaded DLL MD5 `8b3ca30492d7b1c790deeebe94b201ad`, SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. That
DLL is byte-identical to ignored checkout `R/EDI/src/EDI.so` (same SHA-256),
at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the tracked implementation
and test files are clean at that HEAD. This establishes the loaded native
binary identity, but the package contains no Git SHA/build manifest to
authenticate its installed R-layer source. It adds focused installed-package
validation only. For the isolated matrix's `beta_T=0` stratum, the analytical
treatment-coefficient truth is zero under both `~1` and `~.`; the serialized
formula-specific `coverage_truth` values are one-replicate MC fitted estimates
and are diagnostic only. No coverage impact is inferred and no canonical
value is rewritten. The matrix still lacks authenticated installed R-source
provenance, and exact-key canonical reconciliation remains separately
authorized and open.

## Additional installed-package reference recheck (2026-10-20)

`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-kk-weibull-marginal-cpp-and-survreg-fits-cluster-robust-se-agreement-and-guards-reference.R", reporter="summary")'`
passed 19 assertions (0 failures, warnings, or skips) against installed EDI
1.0.3. This deterministic `set.seed(8)`, `n=80` fixture compares the C++
marginal-Weibull treatment estimate and cluster-robust SE to an independent
`survival::survreg` reference, including no-cluster and missing-treatment
guards. Runtime provenance: R `R Under development (unstable) (2026-10-13
r90668)`, library `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, DLL
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, MD5
`a75519a9256c0b3121398032314291d4`, SHA-256
`dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`, and
checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. The DLL differs from
the artifact used for the isolated 300-row matrix (MD5
`dfd5bf4384b5a0cc0d430fd70dab2a59`), so this is a separate installed-package
oracle check, not historical-result parity or current-checkout native
validation. No simulation sweep, canonical output write, build, or install
was performed. This advances the TODO-26 Weibull estimator-reference evidence
only; it does not satisfy linked-plan TODO-8's separate canonical
regeneration/reconciliation gate, which remains open.

## Checkout-R source-overlay reference recheck (2026-10-20)

The same focused `test-kk-weibull-marginal-cpp-and-survreg-fits-cluster-robust-se-agreement-and-guards-reference.R`
passed all 19 assertions with `pkgload::load_all("R/EDI", compile = FALSE,
quiet = TRUE)` followed by `testthat::test_file(...)` (0 failures, warnings,
or skips). This reruns the deterministic `set.seed(8)`, `n=80` independent
`survival::survreg` comparison and no-cluster/missing-treatment guards with
checkout R sources. The namespace was `/home/kapelner/workspace/EDI/R/EDI`,
package version 1.0.3, and the loaded temporary DLL MD5 was
`8b3ca30492d7b1c790deeebe94b201ad`; it matches the installed and ignored
checkout DLL, SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
No build, install, matrix run, or canonical write occurred. This strengthens
the focused current-checkout R-layer estimator-reference evidence only; the
isolated 300-row matrix's authenticated installed R-layer provenance and
formula-specific truth review, plus separately authorized exact-key
canonical reconciliation, remain open.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
