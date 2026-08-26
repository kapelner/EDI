# Design: Quantile Regression Inference for Count Responses

Status: approved design, not yet implemented.
Date: 2026-08-26

> Related: `survival_quantile_regression.md` (brainstormed alongside this
> plan, same session) adds quantile regression for survival responses via
> a different mechanism (interval-censoring EM, not jittering). The two
> are independently scoped and can be implemented in either order.

## Motivation

EDI has quantile-regression inference classes for continuous
(`InferenceContinQuantileRegr`) and proportion responses
(`InferenceProportionKKQuantileRegrIVWC`/`OneLik`), all built on
`quantreg::rq()`, but none for count responses
(`inference_all_abstract_count_likelihood.R`,
`inference_count_composite_likelihood.R`,
`inference_count_KK_gee.R` cover mean-regression-style count models
today). Quantile regression for count data is well-founded in the
econometrics literature via Machado & Santos Silva (2005)'s jittering
method — add continuous uniform noise to make the (otherwise degenerate)
count response continuous, then apply ordinary `rq()` — and count
outcomes with heavy skew/zero-inflation (hospital visits, seizure counts,
adverse-event counts) are exactly where median/tail regression can beat
mean regression. This is distinct from quantile regression for
`incidence` (binary) responses, which was explicitly considered and
rejected as out of scope (see `survival_quantile_regression.md`'s scope
decisions — conditional quantiles of a Bernoulli variable are degenerate
and no standard method is used in RCT/experimental inference practice).

## Scope decisions

- **Jitter averaging:** `compute_estimate()` draws `B` (default 100)
  independent jittered datasets (`y + Uniform(0,1)` per subject), fits
  `rq()` on each, and reports the mean `beta_hat_T` across draws (and the
  mean Powell-sandwich SE, not the cross-draw SE of `beta_hat_T`, which
  would conflate jitter noise with sampling noise). A single jitter draw
  is statistically valid but adds irreducible extra variance to the point
  estimate; averaging over many draws is standard practice for this
  method.
- **Nested-loop cost:** bootstrap-weighted refits
  (`compute_estimate_with_bootstrap_weights()`) and randomization-inference
  refits (`compute_fast_randomization_distr()`) each use a **single**
  jitter draw per replicate, not the full `B`-average — avoiding a
  `B × (bootstrap/permutation count)` cost explosion. The point estimate
  is `B`-averaged; every downstream refit inside an already-existing
  resampling/permutation loop is not.
- **KK designs:** full parity with the continuous/proportion/survival
  quantile-regression family — both `InferenceCountKKQuantileRegrIVWC`
  and `InferenceCountKKQuantileRegrOneLik` are in scope for v1, including
  randomization p-value/CI support via `InferenceAbstractQuantileRandCI`.
- **RNG:** at v1 (pure R, matching the rest of the quantile-regression
  family today), jitter draws use plain R-level `stats::runif()` —
  reproducible via the caller's `set.seed()`, same as every other
  stochastic step in this package; no per-class seed parameter. If any
  part of this ever moves into a C++ kernel (`quantile_regression_cpp_kernel_spec.md`
  already targets this class family for a `use_rcpp` fast path) or is
  parallelized (e.g. across bootstrap/randomization replicates under
  OpenMP), jitter draws in that C++ code MUST use `edi_rng::RRng`
  (`R/EDI/src/RNG.h`) — seeded once via a single `R::unif_rand()` call at
  the single-threaded R/C++ boundary, then an independent `RRng(seed)`
  stream per thread/replicate — never `R::unif_rand()`/`R::runif()`
  directly inside parallel C++ code (thread-unsafe, and not what `RNG.h`
  exists to prevent).
- **tau:** single scalar `tau` per object (default 0.5), matching the
  rest of the quantile-regression family.

## 1. Class hierarchy & naming

- `InferenceCountQuantileRegr`
  (`R/EDI/R/inference_count_quantile_regr.R`) — base class, plain
  (non-KK) designs, jittered `rq()`, single `tau`.
- `InferenceCountKKQuantileRegrIVWC`
  (`R/EDI/R/inference_count_KK_quantile_regr_ivwc.R`) — KK matched-pair
  variant, IVWC combination of matched-pair and reservoir estimates,
  mirroring `inference_continuous_KK_quantile_regr_ivwc.R`.
- `InferenceCountKKQuantileRegrOneLik`
  (`R/EDI/R/inference_count_KK_quantile_regr_one_lik.R`) — KK variant
  fitting one stacked jittered `rq()` model over pooled matched+reservoir
  rows, mirroring `inference_continuous_KK_quantile_regr_one_lik.R`.

Naming uses `InferenceCount...` so `infer_inference_response_types()`'s
existing `^InferenceCount` regex (`inference_class_registry.R:540-551`)
picks these up automatically as `response_type = "count"`, with no
changes to that function.

All three inherit `Inference`, mix in
`components = c("BayesianBootstrap", "Wald")`; the KK variants
additionally follow `InferenceAbstractQuantileRandCI`'s pattern for
`compute_rand_confidence_interval()`/`compute_rand_two_sided_pval()`.

`initialize(des_obj, model_formula = NULL, tau = 0.5, n_jitter_draws = 100,
verbose = FALSE)` asserts `response_type == "count"` and requires the
`quantreg` package installed (same guard as `InferenceContinQuantileRegr`).

## 2. Jittering algorithm & averaging

Given count response `y` (non-negative integers) and design matrix `X`:

1. **Jitter draw:** for `b = 1..B` (default `B = 100`), form
   `y_jitter^(b) = y + u^(b)`, `u_i^(b) ~ Uniform(0, 1)` i.i.d. per
   subject (Machado & Santos Silva 2005). At v1, draws use plain R-level
   `stats::runif(n)`.
2. **Fit:** run `quantreg::rq()` (via `private$fit_quantile_model`,
   reusing the existing rank-reduction/`reduce_design_matrix_for_quantile`
   machinery from `InferenceContinQuantileRegr`) on `y_jitter^(b)`,
   extract `beta_hat_T^(b)`.
3. **Average:** `beta_hat_T = mean(beta_hat_T^(1), ..., beta_hat_T^(B))`
   is the reported point estimate.
4. **Standard error (Wald path):** average `quantreg`'s Powell-sandwich
   SE across the `B` draws the same way — not the cross-draw SE of
   `beta_hat_T^(b)`, which would conflate jitter noise with sampling
   noise.
5. **Bootstrap/randomization refits** each use a single jitter draw per
   replicate (see Scope decisions). This is the loop where a future C++
   path must use `edi_rng::RRng` rather than `R::unif_rand()` if
   parallelized.

## 3. KK design variants + randomization inference

- **`InferenceCountKKQuantileRegrIVWC`:** fits the jittered-`rq()`
  estimator (section 2, `B`-averaged point estimate + averaged sandwich
  SE) separately on matched-pair rows and reservoir rows, combines via
  inverse-variance weighting — same shape as the continuous/proportion/
  survival IVWC classes.
- **`InferenceCountKKQuantileRegrOneLik`:** pools matched-pair +
  reservoir rows into one stacked design, single `B`-averaged jittered
  fit over the combined data.
- **Randomization inference:** both KK variants inherit
  `InferenceAbstractQuantileRandCI`'s contract
  (`compute_rand_two_sided_pval`, `compute_rand_confidence_interval`),
  with `compute_fast_randomization_distr()` refitting under permuted
  treatment assignment using a single jitter draw per permutation — each
  permutation redraws its own jitter (never reusing one fixed jitter draw
  across all permutations, which would bake one arbitrary noise
  realization into the entire randomization distribution).
- **Performance:** cheaper than the survival design's per-replicate EM
  loop — each jitter+refit here is one `rq()` call, not an iterated EM.
  No new performance-risk flag beyond the existing quantile-regression
  family's already-measured cost profile (`path_audits_source.R:29`,
  motivating `quantile_regression_cpp_kernel_spec.md`).

## 4. Testing plan

- **Jitter-averaging correctness:** as `B` grows, `beta_hat_T` should
  stabilize (decreasing variance across repeated `B`-draw evaluations
  with different `set.seed()`s); a regression test checks `B = 100` vs
  `B = 1000` point estimates agree within a documented tolerance on a
  fixed seed/dataset, so a future change to the averaging logic can't
  silently drift.
- **Statistical validity:** simulated count data (e.g. Poisson/negative-
  binomial with a known covariate/treatment effect) at increasing `n`
  recovers the known conditional quantile treatment effect.
- **Degenerate/failure handling:** rank-deficient `X`, too few residual
  degrees of freedom, or an `rq()` failure on an individual jitter draw
  is a failed draw; if too many of the `B` draws fail (a threshold, e.g.
  majority), `compute_estimate()` returns `NA` via the same
  `set_failed_fit_cache()` pattern as `InferenceContinQuantileRegr`,
  rather than silently averaging a partial subset.
- **KK variants:** extend the registry-driven fixture pattern
  (`public_argument_combination_constraints.R`) with
  `response_type = "count"` fixtures across the KK/IVWC/one_lik matrix;
  spot-check randomization p-value/CI against brute-force full
  permutation on small `n`.
- **Registry wiring:** new classes need entries in
  `inference_class_registry.R`; naming as `InferenceCountQuantileRegr` /
  `InferenceCountKKQuantileRegrIVWC` / `InferenceCountKKQuantileRegrOneLik`
  keeps `infer_inference_response_types()`'s existing `^InferenceCount`
  regex working with no changes to that function.

## Explicitly out of scope

- Quantile regression for `incidence` (binary) responses — see
  `survival_quantile_regression.md`'s scope decisions for the rejection
  rationale (degenerate Bernoulli conditional quantiles, no standard
  method used in RCT practice).
