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

TODO-8 remains pending until the affected comprehensive-results rows are
regenerated with the user's separately managed rebuilt package. The
repository rule forbids building or installing the checkout during this
audit.

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

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
