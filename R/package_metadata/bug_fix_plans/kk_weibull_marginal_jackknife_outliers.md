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

## Root cause hypothesis (not yet traced to a specific line)

Not a mean-shift/formula bug. Most plausibly a leave-one-out jackknife
fold occasionally landing on a degenerate/non-identifiable configuration
— small matched-cluster counts plus one held-out observation can produce
this for marginal Weibull models (e.g. a fold that removes the only
non-censored observation from a small cluster, or a fold that leaves a
covariate pattern with no remaining variation). This is a **numerical
robustness** bug in the jackknife resampling loop specifically, analogous
in shape (though a different location) to `release_v1_0_5.md → TODO-4`'s
already-tracked unguarded near-singular information-matrix inverse — a
single unstable fit silently producing a wild-but-finite number rather
than failing loudly or being excluded.

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

## Proposed fix — not yet applied, not yet fully scoped

Add a sanity/guard check on jackknife-fold estimates: reject, flag, or
exclude a fold whose estimate is many orders of magnitude outside the
observed (full-sample) fit's own scale, rather than silently including it
in the jackknife SE/estimate computation. Exact mechanism (a hard
magnitude cutoff, a robust-scale-based outlier test, or fixing whatever
specific degenerate configuration causes the fold to blow up in the first
place) not yet decided — needs the root-cause trace below first.

## TODOs

- [ ] TODO-1: Locate the jackknife loop for this class (likely in
  `R/EDI/R/inference_survival_KK_weibull_marginal.R` or a shared
  jackknife-family helper — confirm exact location) and trace exactly
  which fold(s) produce the −38.0/+17.5-class outliers. Reproduce directly
  via `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
- [ ] TODO-2: Confirm the degenerate-configuration hypothesis (e.g. a
  cluster/covariate-pattern check on which specific held-out observation
  produces the outlier) or find the actual mechanism if different.
- [ ] TODO-3: Design and implement the guard — likely following the same
  "detect near-singular/degenerate, return NA or exclude rather than a
  wild finite value" philosophy as TODO-4's fix, adapted for a
  per-fold jackknife context rather than a single information-matrix
  inverse.
- [ ] TODO-4: Verify the fix doesn't change jackknife estimates for
  well-behaved folds (bit-for-bit or floating-point tolerance) — only the
  degenerate folds' handling should change.
- [ ] TODO-5: Re-run the bias check (t-test + Wilcoxon on estimate −
  truth) and confirm both the mean bias and RMSE return to reasonable
  values, and that RMSE is no longer wildly disproportionate to the bias
  magnitude.
- [ ] TODO-6: Add a permanent regression test constructing a fixture
  likely to produce a degenerate jackknife fold (small clusters, as
  identified by TODO-2) and asserting no fold's estimate exceeds a
  sanity-scale bound relative to the full-sample fit.
- [ ] TODO-7: Check whether other jackknife-based methods across the
  package (not just this one class) share the same unguarded-fold
  vulnerability — this session's TODO-4 already found the same
  "unguarded numerical operation → wild finite value" shape recurring
  across several unrelated C++ kernels, so a package-wide jackknife-loop
  sweep may be warranted rather than treating this as isolated to one
  class.
- [ ] TODO-8: Regenerate affected `comprehensive_tests` CSV rows once
  fixed and installed (only after install, not before).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
