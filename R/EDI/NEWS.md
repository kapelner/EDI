# EDI 1.0.5

Correctness release. Wrong results found by the algorithm audit and the
comprehensive-test sweeps are fixed, and seeded draws are now identical on
Linux, macOS and Windows at every thread count (checked in CI). No new
methods.

## Breaking changes

* GitHub source installs build the portable CRAN configuration by default;
  `EDI_PORTABLE=0` restores the machine-tuned build.
* Seed-pinned draws change once: a portable Fisher-Yates shuffle replaces
  `std::shuffle`, and the greedy, D-optimal, pair-switching and
  rerandomization designs no longer depend on the thread count.
* Seed-pinned draws also change once for `DesignFixedBlocking`,
  `DesignFixedOptimalBlocks`, `DesignFixedCluster` and
  `DesignFixedBlockedCluster`: null assignment draws are now generated in one
  vectorized pass (same distribution as `randomizr::block_ra` /
  `cluster_ra`, including random rounding; about 15x faster at `r = 2000`),
  no longer need `randomizr`, and a singleton block is now treated as
  Bernoulli(`prob_T`). The draws depend only on the seed, not on
  `set_num_cores()`. `DesignFixedRerandomization` with `prob_T != 0.5` or odd
  `n` still draws one at a time in R.
* The nonparametric bootstrap's studentized statistics (`studentized`,
  `bootstrap-t`, `symmetric-percentile-t`, `smoothed`) are now cached per
  object by `B` and `smooth`, and use `set_seed()` (global RNG state saved and
  restored). A studentized CI followed by a studentized p-value now share one
  set of resamples, and seeded objects give reproducible results; callers who
  ran several of these types on one object, or set a seed, see different
  (previously unseeded, recomputed) values.
* Seeded randomization p-values and intervals now use the seed. Draws come
  from `set_seed()` on the inference object, else the design seed (global RNG
  state is saved and restored); the permutation cache key includes that seed,
  so changing the seed changes the draws. Seeded designs and `set_seed()`
  users therefore get different (now reproducible) randomization p-values and
  CIs than before; unseeded behaviour is unchanged. New
  `clear_randomization_cache()` on `Inference` drops the cached draws (the
  unseeded cache is still shared by all inference objects on a design).
* More resampling paths now use `set_seed()` (global RNG state saved and
  restored): the KK matched-pair bootstrap (every KK class on a matching
  design), `InferencePropGCompMeanDiff`'s bootstrap, the `"calibrated"`,
  `"double-bootstrap"` and `"prepivoted"` bootstrap CIs, and the randomization
  CI of `InferenceContinKKQuantileRegrIVWC` / `InferencePropKKQuantileRegrIVWC`
  (inference seed, else design seed). Before, these drew from, and advanced,
  the caller's RNG stream even on a seeded object. Seeded results change once
  and are now reproducible; unseeded behaviour is unchanged.
* `compute_rand_confidence_interval()` now errors, instead of returning bounds
  on the wrong scale, for classes whose estimate is a raw-scale mean difference
  or rank effect on proportion, count and ordinal responses
  (`InferenceAllSimpleAverageDiff` on proportions/counts,
  `InferencePropGCompMeanDiff`, `InferenceOrdinalRidit`,
  `InferenceOrdinalJonckheereTerpstraTest`, `InferenceOrdinalGCompMeanDiff`,
  `InferenceOrdinalPairedSignTest`). The randomization p-value and
  randomization-bootstrap CI are unchanged.
* `capabilities()` / `supports()` no longer advertise `randomization_ci` for a
  (class, response type) pair whose randomization CI is refused (for example
  `InferenceAllSimpleAverageDiff` on proportions, counts or survival, and
  incidence responses), so `InferenceSuite`, `SimulationFramework` and other
  capability-driven callers no longer attempt it. The survival-only classes
  `InferenceSurvivalLogRank`, `InferenceSurvivalGehanWilcox`,
  `InferenceSurvivalRestrictedMeanDiff`, `InferenceSurvivalKMDiff` and
  `InferenceSurvivalDepCensTransformRegr`, whose randomization CI always
  refuses, no longer advertise it at all.
* On cluster designs `InferenceContinOLS` and `InferenceContinLin` Wald
  inference uses a CR2 cluster-robust SE with Bell-McCaffrey (Satterthwaite)
  degrees of freedom instead of G - 1 (matches
  `clubSandwich::coef_test(vcov = "CR2", test = "Satterthwaite")`), so p-values
  and CIs change; a `model_formula` that uses the cluster column now warns
  (`edi_cluster_col_in_model_formula_warning`). The design's `cluster_col` no
  longer enters the default `~ .` covariates (it used to add school dummies
  collinear with treatment). With fewer than 3 clusters the old SE is kept.
  Other regression classes are not yet cluster-robust: on cluster designs
  their Wald and likelihood-based (score, LR, gradient, Bartlett, parametric
  bootstrap) inference warns once per object
  (`edi_cluster_independence_warning`); this also covers OLS/Lin likelihood
  tests. Classes with custom Wald or likelihood paths may not warn. Use
  randomization, `compute_bootstrap_*` or `compute_jackknife_wald_*(unit =
  "cluster")` for cluster-aware inference.
* Randomization intervals invert at `alpha`, not `alpha / 2` (they were too
  wide); the default `pval_epsilon` drops from 0.005 to 1e-6.
* Binary matching minimizes plain distance, as `nbpMatching` does;
  `match_objective = "squared_distance"` restores the old pairs. This is the
  new default (`match_objective = "distance"`) and changes about 22% of
  matched pairs versus 1.0.x (measured at n = 1000, p = 4).
* KK21 survival weights come from a correct Weibull AFT fit.
* `InferenceSurvivalRestrictedMeanDiff` truncates both arms at one horizon.
  On the interval-censored (Turnbull) path exact events are now used (they
  were dropped, so RMST and KM-median differences ignored their times),
  excluded rows warn, and an all-censored arm's RMST is the horizon, not `NA`.
* Bootstrap confidence intervals are no longer set to `NA` just because they
  are wider than 5 outcome units: the width guard is now `5 * max(1, sd(y))`.
  Outcomes with `sd(y) <= 1` behave as before; intervals on larger-scale
  outcomes that used to come back `NA` (non-estimable) are now returned.
* `get_summary()` moved to the `Inference` base class. It now works for every
  class, always returns its table invisibly (Estimate / Std. Error / z or t /
  p), and falls back to a one-row `treatment` summary when no coefficient
  table is available. Previously 57 of 65 classes printed "No model
  available" or a raw internal list, and it returned `NULL`.
* `Design$any_censoring()` is `FALSE` before responses are recorded (it
  counted unrecorded `NA` responses as censored), so
  `applicable_inference_class_names()` no longer drops classes (e.g. pooled
  variance, Wilcoxon) before `add_all_subject_responses()`.
* `DesignFixedOptimal` bootstrap replays reuse the observed solver
  (`brt_solver` overrides).
* Jackknife inference is centred on the jackknife estimate.
* `compute_rand_two_sided_pval()` always uses randomization draws of `w`. For
  incidence responses on matched-pair and Bernoulli designs it used to return
  the Zhang exact combined test, which ignored the draws and was much more
  conservative (200 simulated nulls: 1% vs 3% rejections at 0.05). The Zhang
  test remains available through `type = "Zhang"`; a nonzero `delta` is
  refused for incidence.
* Methods that cannot give a valid answer now error: KK modified Poisson is
  Wald-only, smoothed randomization bootstrap is refused for categorical and
  bounded refits, exact tests refuse bootstrap weights, and
  `InferenceOrdinalKKCondAdjCatLogitRegr` drops the Bayesian bootstrap.
* `InferenceSurvivalDepCensTransformRegr`'s bootstrap intervals default to
  `B = 501`, like every other bootstrap method (they used 1000), so with
  defaults its interval and p-value now share one bootstrap distribution.
  Pass `B = 1000` for the old intervals.
* `DesignFixedBlocking`: naming `strata_cols` without `B_target` now uses all
  named strata (as `B_target = NULL`); the default sqrt/divisor cap used to
  drop them silently (e.g. at prime `n`). With `equal_block_sizes = TRUE` this
  errors when the cells are unequal; set `equal_block_sizes = FALSE`.
  `strata_cols = NULL` keeps the capped default.
* Blocking designs treat an integer-valued numeric strata column with at most
  10 distinct values (e.g. a site code 1..4) as categorical, one block per
  value; it used to be quantile-binned (4 sites became 2 blocks), so block
  assignments for such columns change. Other numeric columns are still binned.

## New features

* `DesignSeqOneByOneKK21stepwise`: `condition_on_ws_for_rand_tests = FALSE`
  replays the full allocation in randomization tests.
* KK quantile-regression randomization intervals are re-enabled.
* Studentized Bayesian-bootstrap intervals for the Weibull and
  modified-Poisson classes.
* `na.rm` for the KMDiff Bayesian-bootstrap p-value.
* `InferenceSurvivalRestrictedMeanDiff$new(..., tau = NULL)`: a user-settable
  RMST horizon (single positive number, at most the smaller arm's maximum
  follow-up); `NULL` keeps the default. With a user `tau`, the native
  randomization kernel is skipped in favour of the slower generic loop.
* `alternative = c("two.sided", "greater", "less")` (last argument) on
  `compute_rand_two_sided_pval()`, for non-negative custom statistics where
  doubling the smaller tail is wrong. The default is unchanged; single tails
  are `max(1/B, P)`. Confidence-interval inversion still uses the two-sided
  p-value, and classes that override the method with their own signature do
  not take `alternative`.
* `clear_randomization_cache()` on `Inference` (see Breaking changes).

## Bug fixes

* Randomization-bootstrap tests and intervals redrew each resample's assignment
  from the original sample's cached design structure instead of the resample's.
  On `DesignFixedBinaryMatch` and `DesignFixedMatchingGreedyPairSwitching` the
  resampled pairs could get 0 or 2 treated subjects (for
  `InferenceContinKKRobustRegrOneLik` the null distribution was identically 0
  and the p-value always 2/(B+1); `InferenceContinKKOLSOneLik` returned `NA`).
  On `DesignFixedOptimalBlocks` assignments were balanced within blocks of the
  original rows; the replay now re-solves the optimal blocking on each
  resample's covariates (same `method`, `B`, `dist` and `roi_solver`) and
  draws the assignment within the new blocks, so every replay draw pays one
  block solve (a draw whose solve fails is recorded as `NA`). That adds
  roughly 6-35 ms per draw for `method = "K-way"` or `"greedy"`, but seconds
  to minutes per draw for the exact `method = "ompr"` (about 1.7 s at
  `n = 12`, about 79 s at `n = 16`), so randomization-bootstrap replays with
  `ompr` are very slow; use a heuristic method or a small number of bootstrap
  replicates there (see `?DesignFixedOptimalBlocks`).
  `DesignFixedGreedyDOptimal` and
  `DesignFixedRerandomization` (`prop_acceptable`, or `prob_T != 0.5` / odd
  `n`) reused the original sample's criterion matrix / covariance on the
  resample. Randomization-bootstrap results on these designs change.
* `DesignFixedOptimalBlocks(method = "greedy")` could stop with "replacement
  has length zero" when `blockTools` listed its incomplete block before a
  complete one (seen on bootstrap resamples with duplicated rows). Complete
  blocks are now numbered consecutively; blockings that previously succeeded
  are unchanged.
* `InferenceSurvivalRestrictedMeanDiff`'s Bayesian-bootstrap studentized and
  bootstrap-t intervals and p-values were always `NA` (no weighted SE); they
  now use a frequency-weighted Greenwood-type SE, which equals the Wald SE at
  unit weights.
* `InferenceContinRobustRegr`, `InferenceContinKKRobustRegrOneLik` and
  `InferenceContinKKRobustRegrIVWC` returned a treatment estimate of 0 when a
  fit (including a resampled or randomization-bootstrap fit) received a
  non-finite response or covariate; such fits are now non-estimable (`NA`).
* `robust_survreg()` / `robust_survreg_with_surv_object()` restart jitter (used
  when `survreg` fails from its first start, e.g. inside the GLMM Weibull
  frailty classes and the KK21 survival designs) now draws from its own seeded
  stream and restores the caller's RNG state. The stream is seeded from the
  calling object's seed (`set_seed()`, else the design seed) plus a fixed
  offset, so the same seed gives the same fit, or from a fixed internal seed
  when no seed is set; new argument `jitter_seed` of
  `robust_survreg_with_surv_object()`. Before, it drew from and advanced the
  caller's RNG stream, so such fits depended on the caller's seed. Fits that
  need no restart are unchanged.
* `InferenceSurvivalKKRankRegrIVWC` (legacy IVWC) results did not duplicate:
  its IVWC weights come from `aftgee::aftsrr(se = "ISMB")`, a multiplier
  bootstrap that drew from and advanced the caller's RNG, so the estimate, SE,
  randomization and bootstrap results changed from call to call. Each `aftsrr`
  fit now runs under a deterministic seed derived from the object's seed
  (`set_seed()`, else the design seed, else a fixed constant) and the fitted
  data, with the caller's RNG state restored; results now duplicate across
  calls and fresh objects and do not depend on the core count. Seeded and
  unseeded results of this class change once.
* `InferenceAllKKMeanDiffIVWC`'s bootstrap errored "Wrong R type for mapped
  matrix" on `DesignFixedBinaryMatch` (double-stored assignments); fixed.
* Ridit `reference = "treatment"` always returned 0; interior levels misscored.
* `InferenceOrdinalRidit` SE is now the DeLong variance (pooled reference:
  (n_C/N) times it); the old SE treated the reference arm as known and gave
  about 19% rejections at a 5% level in a null simulation (now about 6%), and
  p-values now agree with `wilcox.test(correct = FALSE)`. The C++
  `fast_ridit_analysis_result()` `$se` field (and the Python kernel) still
  use the old SE.
* `compute_rand_confidence_interval()` now refuses proportion responses that
  contain an exact 0 or 1 for classes whose sharp null is a logit shift (for
  example `InferencePropZeroOneInflatedBetaRegr`, `InferencePropBetaRegr`).
  Exact 0/1 cannot be shifted on the logit scale, so the p-value was flat and
  the CI hit its search boundary or excluded the estimate. The error names the
  likelihood-based, asymptotic and bootstrap CIs; interior data is unaffected.
  The Zhang-combined quantile CI (`InferencePropKKQuantileRegrIVWC`) refuses
  the same way.
* `compute_rand_confidence_interval()` now refuses survival responses for
  classes whose estimate is a raw-scale mean difference or Hodges-Lehmann
  shift (e.g. `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleWilcox`).
  The search inverts a log-time shift, so these intervals were on a different
  scale from the estimate (in one test, asymptotic CI [-3.3, 2.7] vs
  randomization CI [-0.38, 0.93]). Model-scale survival classes (log time
  ratio) are unaffected; the randomization p-value is unchanged.
* The jackknife block-size guard no longer swallows interrupts and timeouts
  raised while reading block ids: a duplicate copy that caught every error
  was removed, leaving one implementation that re-raises EDI control
  conditions and treats only other errors as "no block ids".
* `InferenceRandCustom` randomization CIs are searched on the effect scale
  (delta), not on the statistic's scale, so a Welch-t or rescaled statistic
  gives the same CI as the mean difference and covers 0 when the p-value does.
  The search checks that its seed is accepted and errors if no delta is.
* `InferenceOrdinalPartialProportionalOddsRegr` (VGAM backend) reported the
  treatment coefficient with the wrong sign, and `nonparallel = ` gave a
  degenerate fit (NaN log-likelihood, near-zero SE) when `nonparallel` was
  set; both fixed (`nonparallel = "treatment"` now warns and is dropped).
* Ordinal fast solvers were inaccurate when covariates were far from zero
  (in a test, a covariate shift of 1e4 moved the Cloglog treatment estimate
  from 0.805 to 0.000, now 0.806): `InferenceOrdinalPropOddsRegr`, `Cauchit`,
  `Cloglog`, `OrderedProbit`, `AdjCatLogit` and `ContRatio` now centre and scale the
  covariates internally and map results back exactly; well-scaled data are
  unchanged. The C++ solvers still report `converged = TRUE` on such data.
* `InferenceContinLin` reused the first model formula's centred covariates for
  later Lin objects on the same design (the cache ignored `model_formula`),
  returning the wrong estimate.
* `InferenceSurvivalKKStratCoxPHOneLik`: the Bayesian-bootstrap refit now
  uses the same single reservoir stratum as the point estimate.
  `InferenceSurvivalStratCoxPHRegr` warns on matched designs (it stratifies on
  covariates, not pairs; use `InferenceSurvivalKKStratCoxPHOneLik`).
* The KK and frailty survival classes (`InferenceSurvivalKKStratCoxPHOneLik`,
  `KKLWACoxPHOneLik`, `GLMMWeibullFrailtyNormalOneLik`,
  `GLMMWeibullFrailtyLoggammaOneLik`) no longer fail with "X row count must
  match w size." when the covariate frame has zero columns; `get_X()` is
  `n x 0`. `InferenceSurvivalDepCensTransformRegr` gives finite estimates and
  Wald, score and LR tests there; its bootstrap no longer loses replicates
  whose dependence-parameter MLE sits on the boundary (it retries those fits).
* Score / LR / gradient tests of the KK OneLik and GLMM classes
  (`InferenceIncidKKCondLogitOneLik`, `InferenceContinKKOLSOneLik`,
  `InferenceSurvivalKKStratCoxPHOneLik`, `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceCountKKCondPoissonOneLik`) returned `NA` or the Wald value when
  `beta_T` was the only parameter (e.g. `~1` on an all-matched design); they
  now give real values that match `survival::clogit`/`coxph`. Several classes
  (`InferenceSurvivalKKLWACoxPHOneLik`, `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`,
  `InferenceContinKKGLMM`, `InferenceIncidKKCondLogitGLMMOneLik`,
  `InferencePropKKGLMM`, `InferenceCountKKGLMM`) ignored the requested
  testing type and returned Wald p-values and CIs; they now dispatch to the
  score / LR / gradient methods. `InferenceCountKKGLMM`'s score test used the
  Hessian with the wrong sign (garbage p-values) and is fixed; the
  loggamma-frailty null fit has a floor on log-theta, so its LR test is no
  longer `NA` when the null MLE is the no-frailty boundary. The KK
  Hurdle/Poisson/CountKKGLMM classes still return the larger of the model and
  Wald p-value by design, so score/LR can equal Wald.
* New classed warnings instead of silent substitution:
  `edi_lik_test_unavailable_warning` (score/LR/Bartlett p-value `NA` while
  Wald is finite), `edi_lik_ci_wald_fallback` and `edi_lik_test_wald_fallback`
  (a likelihood CI or p-value was replaced by the Wald one), and
  `edi_unsupported_procedure` (documented unsupported procedures, e.g. the
  `InferenceCountNegBin` jackknife, return `NA` with a warning and no longer
  clear the valid cached estimate and SE). Returned values are unchanged.
* A failed resampling or likelihood-test procedure (bootstrap, Bayesian or
  parametric bootstrap, jackknife, m-out-of-n, subsampling, randomization CI,
  score/LR/gradient p-values and intervals) still returns `NA`, but no longer
  marks the whole object non-estimable: the failure is recorded for that
  procedure only, and the Wald estimate, SE and `is_nonestimable()` are kept
  (unless the Wald fit itself is unusable).
* `InferenceIncidLogBinomial` and `InferenceIncidBinomialIdentityRiskDiff`
  warn once per object (`edi_binomial_mle_boundary_warning`) when the
  full-data MLE is on the parameter-space boundary (a fitted probability at
  1, or at 0 or 1 for the identity link), where Wald and score SEs and
  intervals may be unreliable; bootstrap or likelihood-ratio intervals are
  suggested. Returned values are unchanged.
* `InferenceCountNegBin` fit stopped short of the MLE (-0.2129 vs `MASS::glm.nb`
  -0.2111); the tolerance is tightened and now matches to about 1e-6.
  Hurdle/ZAP NB fits are not tightened.
* Modified Poisson Wald SE is the robust sandwich.
* Randomization intervals reused a shifted null that is exact only for
  mean-difference and OLS estimators, and refined the wrong endpoint.
* `InferenceAllKKWilcoxIVWC` SEs, bootstrap interval and bootstrap scale;
  other legacy `*IVWC` classes had placeholder variances or dropped pairs.
* Mixed models: logistic GLMM Hessian, multi-start fits, KK GEE correlation,
  bootstrap-weighted refits that fit the wrong model.
* Ordinal: cloglog parametric-bootstrap sign (left open in 1.0.2),
  stereotype and continuation-ratio multi-start; ZOIB softmax means.
* Designs: `RandomBlockSize` redraw stratum and single block size,
  `PocockSimon` `NA` level, `OptimalBlocks` block-size spread.
* Incidence: Newcombe root search, equal-tailed exact-binomial p-value,
  Zhang interval bracket.
* Survival: stratified-Cox bootstrap scaling, DepCens intervals, Clayton
  overflow, KK Weibull no-event `NA`, Breslow ties in Cox fallbacks.
* Stale caches keyed on `w` only (GLM, Cox, log-rank, Gehan);
  `get_X_imp()` aliased the raw covariates.
* `InferenceAllSimpleAverageDiff` bootstrap weights are frequency weights.
* Singular fits return `NA` SEs; Jonckheere-Terpstra exact enumeration is
  capped at 1e6 cells.
* Crashes: GC faults in the KK21 ordinal and match kernels;
  `InferenceRandCustom` compile cache.
* `InferenceOrdinalKKCLMMCloglog`: the weighted Bayesian-bootstrap refits and
  `use_rcpp = FALSE` fitted the log-log model, because `ordinal::clmm()`
  swaps the `"cloglog"` and `"loglog"` link names (seen in ordinal
  2026.7.26; `clm()` is correct). EDI now probes the mapping once per session
  and asks `clmm()` for the name that fits the cloglog model, so these paths
  match the native estimate (example: 0.208 before, 0.087 now, native 0.087).
  If the probe cannot decide, the `clmm()` fit is skipped with warning class
  `edi_clmm_link_unverified`. The native cloglog fit was already correct; when
  it reports a random-intercept SD near 0, that is the maximum-likelihood
  estimate.
* KK CLMM classes (all four links) reported `converged = TRUE` for fits that
  had not reached a stationary point (gradient norm around 1e-2), because the
  optimizer's relative-change stop counted as convergence. The optimizer
  tolerance is now 1e-12 (was 1e-6). A fit is accepted only if its gradient
  norm is at most 1e-4; otherwise it is retried once with Newton-Raphson, and
  if that fails too, the result is `NA` with the new nonestimable reason
  `kk_clmm_rcpp_not_stationary`. Estimates move by up to about 6e-3 (median
  about 2e-4).

## Performance

* The tighter KK CLMM tolerance makes these fits slower. A full fit takes
  about 1.5x as long (n = 200: about 44 ms before, 64 ms now). Randomization
  refits take about 2.8x as long (n = 200, r = 200: 3.7 s before, 10.1 s now,
  measured on a loaded machine). The first cloglog `ordinal::clmm()` refit in
  a session also runs a one-time probe of about 2 s.

* Cached per-permutation slopes, a C++ OLS randomization kernel, batched
  Bayesian-bootstrap weights, lazy model matrices; OpenMP kernels respect the
  package thread maximum.
* The unused internal C++ kernel `generate_permutations_blocking_cpp()` was
  removed; blocked designs draw assignments with the batched R helper.
* Seven unused internal C++ kernels were removed (the rank-mean Wilcoxon,
  legacy bootstrap-loop, match-index fill-in and single-bound bisection
  wrappers); no inference path called them.

## Internal

* Inference components now declare only the components they call. Shared
  resampling helpers (the resampling-distribution cache, jackknife-unit
  checks, the extreme-estimate guard) moved unchanged into a new internal
  `ResamplingCore` component, which removes a dependency cycle between the
  jackknife and bootstrap components. Every class keeps the same public
  methods and results.

# EDI 1.0.2

This is the first version submitted to CRAN. Versions 1.0.0 and 1.0.1 were
GitHub-only releases; their entries below record what changed in each. Most of
1.0.2 is correctness work found by the extended comprehensive test suite and
by writing unit tests: resampling and randomization results that were silently
wrong in specific classes, a few kernel defects (including one memory-safety
bug), and standard-error and confidence-interval fixes.

## Breaking changes

* `toggle_asserts()`, `set_num_cores()`, and the internal thread-count
  bookkeeping it drives no longer set global `options()` as a side effect
  (CRAN policy: a package must not modify and leave changed the user's
  session options). `toggle_asserts()` now stores its flag in the package's
  own internal state; calling it no longer changes what
  `getOption("edi.run_asserts")` returns (a user's own
  `options(edi.run_asserts = ...)` is still read and honored). Likewise,
  `set_num_cores()`/`set_package_threads()` no longer set
  `options(mc.cores = ...)` (nothing in EDI read it back; downstream code
  relying on this package to set it for `parallel`/`pbmcapply` needs to set
  it itself now) and no longer call `fixest::setFixest_nthreads()` (which
  sets `options(fixest_nthreads)`, the user's own option, not EDI's to
  change). No change to which thread counts are actually used internally —
  only to these previously-observable `options()` side effects.

## New features

* `InferenceCountQuasiPoisson` now composes the marginal-estimand component
  (`MarginalEstimand`), like `InferenceCountPoisson`, so marginal (standardized)
  effect estimands are available for the quasi-Poisson class as well.

## Bug fixes

* Reused-worker resampling reused a stale cached fit across draws for
  classes whose fit is cached under a custom guard key (first found in
  `InferenceOrdinalGCompMeanDiff`, whose `cached_values$md` guard survived
  the loader's narrow reset list). Every draw then returned the same
  number, the resampling distribution collapsed to a point mass, and
  `compute_rand_two_sided_pval()` sat at its floor regardless of the true
  effect (reject rate 1.0 at a true null). The worker loaders for
  randomization, non-parametric bootstrap, m-out-of-n bootstrap and
  randomization-bootstrap draws now reset the cached fit state between
  draws, and a structural regression test asserts that every class exposing
  a reusable-worker method returns a non-degenerate distribution.
* `InferencePropGCompMeanDiff` and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` returned `NA` (or a
  stale value) in randomization inference: the first from a
  sample-usability gate applied to the wrong resampling context, the second
  from its estimate-only `w_star` pooling. Both are fixed and no longer
  listed as known-broken.
* The KK survival compound classes `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` fed real `NA`s into the
  fitter for every censored subject during randomization inference:
  `compute_treatment_estimate_during_randomization_inference()` re-read `y`
  from the design and derived `dead = as.numeric(!is.na(y))`, but since the
  `y`/`y_L`/`y_R` migration the design's `y` uses `NA` to mark a censored
  observation. On simulated data with a strong effect the randomization
  `p`-value was 0.02 with no censoring and 0.97 with about 20% censoring.
  `y`/`dead` are now derived as `Design$get_effective_time()` /
  `$get_effective_dead()` do. A sweep of the other 16 survival classes found
  no further instance.
* `InferenceOrdinalCloglogRegr`'s parametric-bootstrap `p`-value was
  badly over-rejecting (60% at a true null). One cause is fixed: the
  delta-constrained null refit started from a single cold start and could
  stall; it is now multi-start (the same fix `InferenceOrdinalStereotypeLogitRegr`
  received earlier). *A second cause, a sign mismatch in the shared
  bootstrap-data simulator, is root-caused but not fixed here.*
* The Efron biased-coin randomization null draws (`generate_permutations`)
  compared weighted arm counts (`n_T * prob_T` vs `n_C * (1 - prob_T)`)
  instead of the raw arm counts `DesignSeqOneByOneEfron` actually compares,
  so for any `prob_T != 0.5` the randomization null did not follow the
  design's own assignment rule. It now uses the raw counts.
* `fast_probit_regression`'s L-BFGS objective held a dangling
  `Eigen::Ref` to a temporary, giving non-deterministic fits and `NaN`
  negative log-likelihoods. The objective now owns its design matrix.
* `fast_log_binomial_regression`'s weighted log-likelihood let zero-weight
  rows constrain the `[0, 1]` mean support although they are absent from
  the likelihood; zero-weight rows are now skipped, so the identity- and
  log-link binomial fits no longer reject valid data because of them.
* The robust-regression bootstrap kernel accepted any `method` string and
  would throw inside an OpenMP region, terminating R; `method` is now
  validated (`"M"` or `"MM"`) before the parallel region.
* `stable_signature()` (used to key cached randomization state) hashed a
  strided sample of the serialized object, which collided on 0/1 integer
  permutation matrices; it now hashes the full serialization.
* `InferenceCountPoisson`'s covariance falls back to the Fisher information
  when the kernel returns no `X'WX`; `InferenceIncidLogRegr` gained an
  estimand-aware standard error and degrees of freedom.
* Weibull and Cox fits with fixed (held) coefficients now compute the
  covariance from the free-parameter information block only and expand it
  back, so the free coefficients' variances are finite and the fixed
  parameters' rows and columns are `NaN` by convention; the Cox cluster-robust
  sandwich does the same.
* OpenMP's primary thread no longer polls R's interrupt machinery while
  worker threads are active in the Wilcoxon-Hodges-Lehmann kernels.
* `fast_gaussian_lmm_gls_cpp()` (the fixed-variance-component GLS solve used by
  the randomization and non-studentised bootstrap fast paths of
  `InferenceContinKKGLMM`) mixed `X'X` with a cross-term scaled by an extra
  `1/sigma_e^2`, so it returned the wrong coefficient whenever the residual
  standard deviation was not exactly 1 (on a paired-plus-singleton fixture
  with `sigma_e = 0.4` the slope was -0.53 instead of the correct 0.63; at
  `sigma_e = 1` the two agreed). It now matches an explicit GLS to machine
  precision at every `sigma_e`.
* The KK21 stepwise weight selection for ordinal responses read a
  nonexistent field (`ssq_b_2`) from `fast_ordinal_regression_with_var_cpp()`;
  it now reads the returned `ssq_b_j`.
* Native fitting kernels now validate the dimensions of consumed caller-supplied
  warm-start parameter, weight, and Fisher-information inputs, and validate
  fixed-parameter indices before use. Malformed inputs that could previously
  trigger unsafe Eigen indexing or silently discard a supplied start now fail
  at the native boundary with an error.
* `fast_zero_one_inflated_beta_cpp()` did not check the length of a supplied
  `warm_start_params` (or `warm_start_fisher_info`, or the row counts of `X`,
  `X_zero_one` and `y`), so a mis-sized start let the optimizer read and write
  past its parameter buffer (heap corruption, found under valgrind; it aborted
  R with `free(): invalid next size`). It now raises an ordinary error.
  `InferencePropZeroOneInflatedBetaRegr` always passed a correctly sized start
  and was not affected.
* `fast_ordinal_clmm` now errors on mismatched `X`/`y`/`group_id` lengths
  instead of reading out of bounds.
* `InferenceIncidRiskDiff`, `InferenceCountRobustPoisson`, and the
  zero-inflated/hurdle Poisson classes reported a confident (often
  zero-width) confidence interval and `p`-value on a perfectly or
  near-perfectly fit response (e.g. `y` fully separated by `w`, or
  constant), because the Huber-White/model-based standard error collapses
  to a numerically-zero-but-positive value there. Found via a raw
  `comprehensive_tests` results audit's new adversarial-data/fault-injection
  sweep. `robust_sandwich_variance()` and the affected classes' standard-error
  paths now treat a variance below `.Machine$double.eps` as non-estimable
  (`NA`), not as precision.
* `InferenceCountHurdlePoisson`/`InferenceCountZeroInflatedPoisson` reported
  a confident estimate and `p`-value on a hurdle fit that has no MLE by
  construction (every positive count equal to 1, so the zero-truncated
  Poisson likelihood only improves as `lambda -> 0`). Non-estimability is
  now decided from the data alone (not from what the optimizer/glmmTMB
  happens to return), so the result is `NA` on every platform.
* `InferenceRandCustom$compute_rand_confidence_interval()`'s fast path
  ignored the trial `delta` shift during the randomization search, so the
  returned interval was in the custom statistic's own scale (e.g. centred
  on a Welch-t value of ~2-4) rather than the response's scale. The
  `comprehensive_tests` harness's own custom-statistic randomization-CI
  check also fed it a non-translation-equivariant statistic (Welch t),
  which cannot give a meaningful CI under this or any correct
  implementation; it now uses a difference-in-means statistic for that
  check.
* `InferenceAllSimpleWilcox$compute_asymp_confidence_interval(alpha)`
  cached and returned the 95% Wilcoxon interval for every `alpha`, so a
  90% or 99% interval silently came back at the wrong nominal level.
* `InferenceOrdinalAdjCatLogitRegr`'s parametric-bootstrap confidence
  interval could be wildly wrong (e.g. `[-30, -11]` around an estimate of
  `-0.09`) because each simulated replicate's treatment coefficient was
  read from the wrong field of the refit object (`fit$b`, slopes only)
  when the anchor fit's index into its own coefficient vector (`fit$params`,
  thresholds + slopes) pointed somewhere else entirely on `fit$b`. Every
  parametric-bootstrap replicate now reads the same field the anchor fit
  used.
* `InferenceOrdinalContRatioRegr` (and, via the same hardened
  QR-column-dropping helper, 8 other ordinal threshold-model classes)
  could silently fit from a garbage cold start and "converge" after one
  iteration when the design matrix contained columns collinear with the
  model's *implicit* per-stage intercept (e.g. a stratified design's two
  complementary factor dummies) — `qr()` alone, with no intercept column
  to check against, reported the matrix as full rank. The column-dropping
  helper now optionally includes that implicit intercept in its rank
  check.
* A likelihood-ratio confidence interval whose Newton/bisection inversion
  converges to within a small tolerance of the point estimate — without
  landing on it exactly — was reported as a zero-width interval instead of
  falling back to the Wald interval (or `NA`), because the "failed
  inversion" sentinel check required bit-identical bounds.
  `InferenceOrdinalStereotypeLogitRegr`'s `compute_lik_ratio_confidence_interval()`
  hit this on ~6% of one audited sample. Its
  `compute_lik_ratio_bootstrap_confidence_interval()` had a related bug: a
  bootstrap `p`-value below `alpha` *at the point estimate itself* (which
  should be ~1, since the LR statistic there is 0) was silently treated as
  a legitimate zero-width interval rather than a failed constrained-fit
  refit; it now reports `NA`.

* `compute_rand_bootstrap_confidence_interval(type = "smoothed")` and
  `compute_rand_bootstrap_two_sided_pval(type = "smoothed")` added
  raw-scale Gaussian kernel noise to count responses, so a resampled zero
  could become a slightly negative non-integer. Under the CI inversion's
  multiplicative count shift that became a large negative integer, the
  Rcpp Poisson-GLMM fit gave up, and the glmmTMB fallback rejected every
  such draw (`GLMM FIT ERROR: negative values not allowed for the 'Poisson'
  family`), corrupting the null distribution and yielding a degenerate
  conservative bound (e.g. `InferenceCountKKGLMM`). With `use_rcpp = FALSE`
  every draw failed and the p-value was `NA`. Kernel noise on count
  responses is now rounded and floored at zero so the resampled draw stays
  on the non-negative integer support (the same convention the count shift
  already uses); other response types are unchanged.
* `InferenceCountHurdlePoisson`/`InferenceCountHurdleNegBin`/
  `InferenceCountZeroInflatedPoisson`/`InferenceCountZeroInflatedNegBin`'s
  standard error could fall through to the generic information-matrix-inverse
  fallback on a hurdle fit with no MLE by construction (every positive count
  equal to 1), and whether that generic inversion happened to return a
  spurious finite value or correctly fail depended on the LAPACK/BLAS
  backend (confirmed via CI to differ between this environment, where it
  correctly returned non-estimable, and Windows). The data-driven
  non-estimability check that already gated the estimate and `p`-value now
  also runs before this generic fallback, so the standard error is `NA` on
  every platform.
* `SimulationFramework`'s internal design/inference-combination builder
  unconditionally disabled package assertions and never restored them; a
  caller running with `turn_off_asserts_for_speed = FALSE` (assertions
  intentionally kept on) had assertions silently disabled for the rest of
  the R session after this method ran once, which could mask unrelated
  argument-validation bugs in later, unrelated code in the same session. It
  now restores whatever assert state was in effect on entry.

# EDI 1.0.1

## Breaking changes

* `set_custom_randomization_statistic_function()` and
  `set_custom_randomization_statistic_cpp()` are removed from every concrete
  estimator class. They let a bare R closure read `private$des_obj_priv_int`
  through a hand-built environment proxy — an undocumented, fragile
  mechanism that also forced every concrete estimator's own fast/vectorized
  randomization-test paths to carry a guard for a feature that had nothing
  to do with that estimator. Use the new `InferenceRandCustom` class
  instead: `InferenceRandCustom$new(des_obj, custom_randomization_statistic_function
  = function(y, w, dead) ...)` (or `custom_randomization_statistic_cpp =`
  for the same C++ source/compiled-function/`RcppXPtrUtils::cppXPtr()`
  options as before), then call `compute_rand_two_sided_pval()` or
  `compute_rand_confidence_interval()` on it. The statistic function's
  calling convention is now explicit arguments — `function(y, w, dead)` —
  not implicit access to private state; existing custom statistic functions
  need this small rewrite. `InferenceRandCustom` has its own dedicated fast
  kernel, so performance is unchanged or better than before, uniformly
  across every dataset and design (previously, speed depended on which
  concrete class the statistic happened to be attached to).

## New features

* `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio` gain
  subsampling and m-out-of-n bootstrap confidence intervals and two-sided
  p-values (previously only available for the risk-difference gcomp
  classes). The risk-ratio pivot is computed on the log scale (null at
  `log(delta)`, centered on `log(estimate)`), matching the convention
  already used by their percentile/BCa bootstrap CIs, since the raw-scale
  pivot correct for a difference is not correct for a ratio whose null is
  1 and which is right-skewed at reduced effective sample size.
* `get_local_EDI_optimization()`'s hardware fingerprint now detects
  CPU/RAM on Windows and macOS as well as Linux.

## Bug fixes

* The randomization confidence interval's bisection search picked the
  wrong "conservative" fallback endpoint when it had no reliable sign
  change to bracket: it always fell back to the lower endpoint `l`
  whenever the lower p-value was non-significant, which is correct when
  searching for a *lower* bound (`l` is the outer/conservative end there)
  but wrong when searching for an *upper* bound, where `l` is the point
  estimate itself and is essentially always non-significant. Every such
  "conservative" upper bound silently collapsed to the point estimate,
  producing badly-too-narrow intervals — confirmed by simulation at
  roughly 51-61% empirical coverage instead of the nominal 95% for
  `InferenceContinLin`, `InferenceContinOLS`, `InferenceContinQuantileRegr`,
  and the KK one-likelihood classes. The fallback now keys on which bound
  is being computed rather than which p-value was non-significant.
* `SurvivalDepCensTransformSource` (the dependent-censoring AFT residual
  transform) protected only the treatment column from the hardened QR
  column-dropping fallback, not the intercept — dropping the intercept
  left a severe bias under the null (mean `beta_hat` around 0.71 instead
  of about 0.005, coverage around 13% instead of 95%). Both columns are
  now protected, the same pattern already used for the Weibull-frailty
  design matrix below.
* `InferenceSurvivalStratCoxPHRegr`'s score-test information closures
  returned the raw Cox partial-likelihood Hessian unnegated. Since that
  Hessian is negative semi-definite (a concave log-likelihood), the
  "information" matrix fed to the score test was itself negative-definite,
  so the shared score-test helper's positivity check always failed —
  `compute_score_two_sided_pval()`/`compute_score_confidence_interval()`
  returned `NA` on every call, regardless of formula. Fixed to negate, as
  the sibling `InferenceSurvivalCoxPHRegr` already did.
* `get_clogit_plus_glmm_hessian_cpp()`'s exported wrapper negated an
  objective that already returns the positive information matrix (not the
  raw log-likelihood Hessian), so `InferencePropKKGLMM` and
  `InferenceIncidKKCondLogitGLMMIVWC`/`OneLik` fed the score test a
  negative-definite matrix — the same failure mode as the StratCoxPH bug
  above, reproducing an approximately 100% `NA` rate for their score test
  regardless of formula. The extra negation is removed.
* Six ordinal-response inference classes — `InferenceOrdinalAdjCatLogitRegr`,
  `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`,
  `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalContRatioRegr`, and
  `InferenceOrdinalPropOddsRegr` — extracted `b[length(b)]` (the last
  covariate's slope) as the treatment coefficient instead of `b[1]`
  (treatment is always the design matrix's first column). The two coincide
  only when the model has no covariates beyond treatment; with covariates
  present, the randomization test and the Bayesian-bootstrap machinery
  silently estimated and tested a different covariate's effect instead of
  treatment's (confirmed via near-total null rejection on
  `design_formula = ~.` paths).
* The log-normal-frailty Weibull AFT model
  (`InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`/`OneLik`) fit its design
  matrix with no intercept column. Without one, the control arm's baseline
  log-time was pinned at 0 and the mean-zero Gaussian frailty could only
  partly absorb it; the leftover bias (plus the Gumbel error's nonzero
  mean) leaked into the treatment estimate, inflating Wald/score/LR/
  bootstrap rejection to roughly 50-70% under the null (nominal 5%).
* The zero-inflated negative binomial kernel (`fast_zinb.cpp`) had two bugs
  in its ZIP-limit reduced fit: a fixed-parameter index was off by one, so
  the reduced fit pinned the parameter *before* the one requested (e.g.
  the intercept instead of the treatment coefficient); and the ZIP-limit
  score vector was one entry shorter than the full parameter vector and
  was not zero-padded, so score-test consumers compared it against a
  differently-sized information matrix.
* `InferenceOrdinalKKGEE` fit its GEE model on the raw, unreduced design
  matrix; rank-deficient fixtures (e.g. `~0+.` model matrices) made the
  `multgee::ordLORgee()` backend refuse the fit outright, silently
  swallowed to `NULL` (74-89% `NA` rates observed on affected data shapes).
  It now retries through the same QR-hardened rank-reduction machinery
  used elsewhere before giving up.
* Five classes' Bayesian-bootstrap machinery discarded an already-computed
  per-replicate SE for the treatment coefficient and always reported `NA`
  instead, starving their studentized/BCa variants of any SE:
  `InferenceOrdinalPropOddsRegr`, `InferenceCountQuasipoisson`,
  `InferenceCountRobustPoisson`, the glmmTMB-based weighted refit path
  shared by the zero-augmented Poisson classes, and
  `InferenceAbstractKKOrdinalCLMM` (the shared base of the KK ordinal
  CLMM classes).
* `InferenceProportionFractionalLogit` was missing quasi-binomial
  dispersion scaling, systematically overstating standard errors — 0
  rejections out of several hundred simulated replicates under the true
  null (near-zero power rather than nominal-level power).
* `InferenceIncidLogBinomial`'s Bayesian bootstrap discarded
  boundary-hitting refit replicates instead of retaining them, shrinking
  the empirical spread of the bootstrap distribution — observed test size
  25-36% instead of nominal 5%, and CI coverage 56-70% instead of 95%.
* `InferenceExtPRWSubsampling` was missing the finite-population
  correction for without-replacement subsampling, observed at roughly
  9.75% Type-I error instead of nominal 5% at a subsample fraction of
  about 0.4.
* `InferenceExtPRWSubsampling` and `InferenceExtMOutOfNBootstrap`'s
  failure gate checked only the absolute count of finite replicates
  (default minimum 5), not the fraction of the requested `B`/`m`. With
  `B` in the hundreds, a high (24%+) convergence-failure rate could still
  pass the gate, producing a falsely-precise, degenerate p-value. The gate
  now also requires a majority of replicates to succeed.
* The zero-augmented Poisson classes' shared information-matrix code now
  neutralizes the zero-inflation coefficient block when the ZI submodel's
  fitted probability collapses to its boundary, preventing inflated
  likelihood-ratio-test Type-I error in that regime.
* The KK-GEE shared mixin's QR-hardened column-dropping fallback read a
  nonexistent `attempt$X_fit` field (the correct field is `attempt$fit`),
  so the fallback candidate was never actually generated for any class
  composing that mixin (continuous/count/incidence/proportion/ordinal-KK
  GEE classes).
* The generic score test (`InferenceExtInformationMatrix`) returned `NA`
  for the large majority of calls from `InferenceContinKKGLMM` and
  `InferenceCountKKGLMM` — their null-constrained refit's
  nuisance-parameter information is positive definite only about 32% of
  the time near a variance-component boundary, which is expected behavior
  of the likelihood surface there, not a sign of a bad fit. This made the
  score test degenerate (0% Type-I error and 0% power together, rather
  than merely miscalibrated). A ridge-regularized fallback now activates
  only when the unregularized path already returned a non-finite p-value.
* `DesignFixedBlocking` silently ignored user-supplied block IDs: the
  randomization draw always re-derived blocks from the raw covariates
  instead of using the `m` a caller passed at construction.
* `InferenceSurvivalGehanWilcox` and `InferenceSurvivalLogRank` fit their
  null Cox model with the default (Efron) tie-handling, inconsistent with
  the Breslow/Nelson-Aalen convention their fast C++ kernels assume — a
  genuinely different martingale residual under tied event times. Both
  now fit with `method = "breslow"` explicitly.
* `InferenceSurvivalRestrictedMeanDiff` (RMST) never populated the
  treatment coefficient's SE on a full (non-`estimate_only`) fit, unlike
  every peer class, so bootstrap callers expecting it for a studentized
  pivot got `NA`.
* `InferenceOrdinalPairedSignTest`: an estimate is no longer `NaN`
  whenever any single pair-difference is `NA` — valid pairs are now used.
  Its bootstrap and jackknife distribution methods, previously disabled
  with an error asserting they violate the matched-pair design
  constraint, are available again.
* Bootstrap-family methods (nonparametric, m-out-of-n, subsampling, BCa)
  now refuse with an explicit error for `DesignSeqOneByOne` and its
  subclasses, except `DesignSeqOneByOneBernoulli` (whose assignments do
  not depend on prior subjects, so row resampling is valid there). These
  methods previously ran without error for sequential designs in general
  and were documented as merely "conservative"; that claim did not hold
  and has been removed along with the methods for the other sequential
  designs.
* An OpenMP worker thread (not the master) calling into R's interrupt or
  time-budget checks could raise an exception across the OpenMP thread
  boundary, crashing the whole R process (`SIGABRT`) instead of cleanly
  interrupting, under `num_cores > 1`. Both checks now no-op on any
  thread but the master.
* `InferenceSurvivalCoxPHRegr`'s internal `coxph.fit` wrapper crashed
  assigning column names to a 0-column design matrix (`length of
  'dimnames' [2] not equal to array extent`) on null-model refits — e.g.
  `compute_lik_ratio_two_sided_pval()`/`compute_score_two_sided_pval()`
  under `model_formula = ~1` — because `paste0("x", seq_len(0))` returns
  `"x"` rather than `character(0)`. The column-naming step is now skipped
  for a 0-column matrix.
* `SimulationFramework`'s `mirai`-based parallelization
  (`set_num_cores(force_mirai = TRUE)`) could hang indefinitely if a
  daemon died before connecting. Daemon launch and every
  daemon-collection call are now bounded by a deadline, with one relaunch
  attempt and a clear error in place of an unbounded wait.
* Randomization confidence intervals are no longer offered for the six
  log-hazard-ratio (Cox-family) survival classes — `InferenceSurvivalCoxPHRegr`,
  `InferenceSurvivalKKLWACoxPHIVWC`/`OneLik`, `InferenceSurvivalKKStratCoxPHIVWC`/`OneLik`,
  and `InferenceSurvivalStratCoxPHRegr` (which already refused). The generic
  randomization CI inverts an accelerated-failure-time sharp null, so its
  `delta` axis is a log *time* ratio; these classes' estimates are log
  *hazard* ratios, and the Cox model has no shape parameter linking the two.
  The search was being seeded on the wrong axis and returned bounds that
  were not a confidence interval for anything (on a Weibull test case:
  estimate −1.70, "CI" `[−1.70, −1.26]`). A direct
  `compute_rand_confidence_interval()` call now stops with an explanation,
  and `InferenceSuite` no longer lists the method for them, as for
  incidence responses. The randomization p-value and the randomization-
  bootstrap CI (a percentile interval on the estimate's own scale) are
  unchanged. AFT-scale survival classes (Weibull, marginal Weibull, Weibull
  frailty, rank regression) are unaffected.

## Documentation

* `compute_rand_confidence_interval()` documents the impute-then-permute
  construction (Rosenbaum 2002; Imbens & Rubin 2015) and, for survival
  responses, the AFT residual construction and its censoring assumptions
  (Tsiatis 1990; Wei, Ying & Lin 1990; Jin, Lin, Wei & Ying 2003).
* `InferenceOrdinalStereotypeLogitRegr`'s likelihood-ratio test
  (`compute_lik_ratio_two_sided_pval()`) now documents that it has
  inflated Type-I error (roughly 18-23% vs. a nominal 5%) for this class
  specifically (a non-regular case in the sense of Davies 1977), and
  recommends the bootstrap (~6-7%) or Bartlett-corrected (~4%) variants
  instead. The flagged method's own behavior is unchanged.
* `InferenceSuite`'s combined-evidence documentation adds a "same-Y does
  not mean same estimand" caveat: rows testing the same outcome under
  different link functions/estimands do not share one coherent null
  hypothesis under the weak (asymptotic) null, only under the
  randomization sharp null — relevant to interpreting
  `combined_evidence$pval`.

# EDI 1.0.0

Initial release of EDI (Experimental Design and Inference): a framework that
pairs randomized experimental designs — fixed-sample and sequential — with
inference procedures matched to each design and response type, so that
estimation and testing always reflect how the data were generated.

## Experimental designs

* Fixed-sample designs (all n subjects assigned at once via
  `assign_w_to_all_subjects()`): `DesignFixedBernoulli`, `DesignFixediBCRD`,
  `DesignFixedFactorial`, `DesignFixedBlocking`, `DesignFixedCluster`,
  `DesignFixedBlockedCluster`, `DesignFixedBinaryMatch`,
  `DesignFixedMatchingGreedyPairSwitching`, `DesignFixedGreedy`,
  `DesignFixedGreedyDOptimal`, `DesignFixedOptimal` and
  `DesignFixedOptimalBlocks` (mixed-integer-programming optimal designs via
  `ompr`/GLPK, with simulated-annealing and greedy alternatives), and
  `DesignFixedRerandomization`.
* Sequential one-by-one designs (each subject assigned on arrival via
  `add_one_subject_to_experiment_and_assign()`, maintaining covariate
  balance): `DesignSeqOneByOneBernoulli`, `DesignSeqOneByOneiBCRD`,
  `DesignSeqOneByOneUrn`, `DesignSeqOneByOneEfron` (biased coin),
  `DesignSeqOneByOneAtkinson`, `DesignSeqOneByOnePocockSimon`
  (minimization), `DesignSeqOneByOneRandomBlockSize`, `DesignSeqOneByOneSPBR`
  (stratified permuted block), and the Kapelner-Krieger matching-on-the-fly
  family that builds matched pairs from the accruing subject stream:
  `DesignSeqOneByOneKK14`, `DesignSeqOneByOneKK21`,
  `DesignSeqOneByOneKK21stepwise`.
* Observational designs (containers for already-observed, non-randomized
  assignments with blocking/matching structure): `ObservationalDesign`,
  `ObservationalDesignBlocks`, `ObservationalDesignMatching`.
* Custom-design extension bases for user-defined assignment rules:
  `DesignFixedCustom`, `DesignCustomSequential`.
* Unequal allocation supported; missing covariate data imputed
  automatically (`missRanger`/`missForest`).

## Response types

Six response types, each with its own matched inference classes: continuous,
incidence (binary), count, proportion (values in [0, 1]), ordinal, and
survival — the survival response supporting exact, left-censored,
right-censored, and interval-censored observations through one `y`/`y_L`/`y_R`
interface.

## Inference

* Continuous: OLS (`InferenceContinOLS`), Lin's covariate-interacted OLS,
  quantile regression, robust (Huber) regression, and for matched (KK)
  designs GLMM (`InferenceContinKKGLMM`), OLS/quantile/robust variants in
  both IVWC (inverse-variance-weighted combination) and combined-likelihood
  pooling, plus the Bai adjusted-t estimators (`InferenceBaiAdjustedTKK14`,
  `InferenceBaiAdjustedTKK21`).
* Incidence: logistic, probit, log-binomial, and identity-link binomial
  regression, Wald and exact binomial tests, Fisher's exact test, CMH,
  Newcombe and Miettinen-Nurminen risk-difference intervals, extended-Robins
  and Zhang (2026) exact test-inversion randomization CIs, g-computation
  marginal effects, modified Poisson, and conditional-logit / GLMM classes
  for matched designs.
* Count: Poisson, quasi-Poisson, robust Poisson, negative binomial,
  zero-inflated and hurdle models, composite likelihood, conditional
  Poisson, and GEE classes for matched designs.
* Proportion: beta regression, fractional logit, zero-one-inflated beta,
  quantile regression, g-computation, and matched-design GEE/quantile
  variants.
* Ordinal: proportional odds, partial proportional odds, adjacent-category
  logit, continuation-ratio, stereotype logit, ordered probit, cauchit and
  complementary-log-log links, g-computation, ridit scoring,
  Jonckheere-Terpstra, paired sign test, and CLMM-based matched-design
  classes; randomization confidence intervals for ordinal GLM effects are
  obtained by inverting the exact permutation test (following the
  Wang-Rosenberger approach).
* Survival: Cox proportional hazards (plain and stratified), Weibull AFT
  (with full censoring support), restricted mean survival time, log-rank and
  Gehan-Wilcoxon tests, Kaplan-Meier survival differences, Weibull frailty
  GLMMs (log-gamma and normal frailties), Clayton-copula and
  dependent-censoring-transform estimators, and LWA/rank-regression classes
  for matched designs.
* Cross-cutting estimators usable across response types:
  `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`,
  `InferenceAllSimpleWilcox`, `InferenceAllKKMeanDiffIVWC`,
  `InferenceAllKKWilcoxIVWC`.
* Every applicable procedure at once: `InferenceSuite` runs all inference
  classes valid for a given design/response combination and reports a single
  Cauchy-combined p-value alongside the individual results.
* Custom-inference extension bases: `InferenceCustomAsymp`,
  `InferenceCustomBoot`, `InferenceCustomRand`.
* Where a specialized engine is best-in-class, estimation delegates to it —
  `glmmTMB` (GLMMs), `fixest` (fast GLMs), `aftgee` (rank-based AFT),
  `Rfit` (R-estimation), `survival` — with EDI's own C++ kernels used
  everywhere else.

## Resampling and randomization machinery

* Non-parametric, parametric, and Bayesian bootstrap; BCa intervals;
  jackknife; m-out-of-n bootstrap and Politis-Romano-Wolf subsampling;
  exchangeable-resampling-unit handling for blocked/matched/cluster
  structures; minimum-volatility CI selection.
* Randomization tests with sequential Monte Carlo p-values, custom
  randomization statistics, quantile randomization CIs, and
  randomization/bootstrap confidence intervals via parallel bisection
  test-inversion.

## Simulation framework

* `SimulationFramework` runs Monte Carlo power, size, and
  operating-characteristic studies across designs, response types, and
  inference procedures, with `coverage_pval`/`size_pval` calibration
  diagnostics; `SimulationFrameworkReport` renders results.
* Helpers `generate_covariate_dataset()` and
  `transform_cont_y_based_on_response_type()`; optional parallelization via
  `mirai` (`set_num_cores()`/`unset_num_cores()`).

## Performance

* All model-fitting and variance kernels implemented in C++ (Rcpp,
  RcppEigen/Eigen, RcppNumerical, LBFGS++, IRLS, OpenMP), exposed as
  documented `fast_*` functions — typically one to three orders of magnitude
  faster than the corresponding pure-R fits (see the shipped benchmark
  comparisons against each canonical R baseline).
* Machine-specific tuning: `tune_EDI_for_this_machine()` benchmarks the
  local machine across four axes and persists tuned performance-policy
  defaults (`get_local_EDI_optimization()`,
  `clear_local_EDI_optimization()`).
* Runtime-tunable dispatch policies for optimizer choice, cold/warm-start
  heuristics, and parallel/serial execution:
  `get_optimization_dispatch_policy()`/`set_optimization_dispatch_policy()`
  and the corresponding `*_cold_start_`, `*_warm_start_`, and
  `*_parallel_dispatch_policy()` pairs, plus
  `get_bootstrap_dispatch_policy()`.
* Install-time build configuration via environment variables
  (`EDI_PORTABLE`, `EDI_NATIVE_SPEED`, `EDI_NATIVE_LTO`, `EDI_UNITY`,
  `EDI_DISABLE_VECTORIZATION`, `EDI_DEBUG_SYMBOLS`): a tuned
  `-march=native` unity build by default locally, and a fully portable,
  warning-free build for CRAN/CI (auto-selected on r-universe builders).
* Runtime argument-checking can be disabled for production speed with
  `toggle_asserts()`.

## Documentation and extensibility

* Five concept vignettes: notation glossary; reproducibility (RNG and seed
  conventions); backend contracts (`fast_*`/C++ kernel conventions);
  validation evidence; and extending EDI with your own design and inference
  classes (backed by the design/inference class registries and the
  `DesignFixedCustom`/`DesignCustomSequential`/`InferenceCustom*` bases).
* Utilities including `create_model_matrix_from_features()`,
  `robust_negbinreg()`, `robust_survreg()`, and
  `robust_survreg_with_surv_object()`.

## Companion Python package

* The same C++ kernels are published separately for Python as
  `edi_kernels` (PyPI; pybind11, no R dependency).
