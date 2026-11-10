# Design: Quantile Regression Inference for Survival Responses

Status: approved design, not yet implemented.
Date: 2026-08-26

## Motivation

EDI currently has quantile-regression inference classes for continuous
(`InferenceContinQuantileRegr`) and proportion responses
(`InferenceProportionKKQuantileRegrIVWC`/`OneLik`), all built on
`quantreg::rq()`, but none for survival responses. Survival responses in
EDI can carry general interval censoring (exact, right-, left-, and
interval-censored observations all representable via `y_L`/`y_R`, per
`Design$add_one_subject_response()` in `design_abstract.R:255-338`), and
existing survival inference classes (`InferenceSurvivalCoxPHRegr`,
Turnbull-based helpers) already handle that generality for other model
families. This design adds an analogous quantile-regression class family
for survival responses under the same general censoring model.

`quantreg::crq()` (Portnoy/Peng-Huang censored quantile regression) is not
referenced anywhere in the codebase today and only handles right-censoring
well; it does not solve general interval censoring, so no existing
dependency directly covers this. A custom estimator is required for the
interval-censored case.

## Scope decisions

- **Censoring:** general interval censoring supported from v1 (not just
  right-censoring), matching the rest of EDI's survival inference classes.
- **Estimator:** a custom self-consistent EM built on `quantreg::rq()`
  (Peng-Huang-style estimating equations extended to redistribute mass
  *within* a known interval, not just to the right tail). This single
  algorithm is used uniformly for all censoring patterns — there is no
  fast-path dispatch to `quantreg::crq()` for the pure right-censoring
  case. Exact/right-censored data is expected to reduce to the classic
  Peng-Huang solution as a special case of the general algorithm; this
  reduction is unverified analytically and must be validated numerically
  against `crq()` in tests (see Testing plan), even though `crq()` is
  never called at runtime.
- **Inference:** both a bootstrap path (primary, via the existing
  `BayesianBootstrap` component) and an asymptotic sandwich-variance Wald
  path (secondary, faster, but a heuristic extension of Peng-Huang's
  right-censoring asymptotics with no rigorous proof for the
  interval-censored case — must be documented as such).
- **Designs:** both plain (non-KK) designs and KK matched-pair designs
  (IVWC and one-stacked-likelihood variants) are in scope for v1.
- **Randomization inference:** the KK variants also get randomization
  p-value/CI support (`InferenceAbstractQuantileRandCI`'s contract), at
  full parity with the continuous/proportion KK quantile-regression
  classes.
- **tau:** single scalar `tau` per object (default 0.5), matching the
  existing quantile-regression family's API — not a vector of quantile
  levels in one object.
- **Explicitly out of scope:** quantile regression for `incidence`
  (binary) responses — conditional quantiles of a Bernoulli variable are
  degenerate, existing methods (Manski/Horowitz maximum score) are niche
  and not used in experimental/RCT inference in practice. (Quantile
  regression for `count` responses via jittering is a separate,
  independently-scoped design — see `count_quantile_regression.md`.)

## 1. Class hierarchy & naming

- `InferenceSurvivalQuantileRegr`
  (`R/EDI/R/inference_survival_quantile_regr.R`) — base class, plain
  (non-KK) designs, any censoring pattern, single `tau`.
- `InferenceSurvivalKKQuantileRegrIVWC`
  (`R/EDI/R/inference_survival_KK_quantile_regr_ivwc.R`) — KK
  matched-pair variant, combining matched-pair and reservoir estimates by
  inverse-variance weighting, paralleling
  `inference_continuous_KK_quantile_regr_ivwc.R`.
- `InferenceSurvivalKKQuantileRegrOneLik`
  (`R/EDI/R/inference_survival_KK_quantile_regr_one_lik.R`) — KK variant
  fitting a single stacked EM/`rq()` model over pooled matched+reservoir
  rows, paralleling `inference_continuous_KK_quantile_regr_one_lik.R`.

Naming uses `InferenceSurvival...` (not `InferenceSurv...`) so that
`infer_inference_response_types()`'s `^InferenceSurvival` regex
(`inference_class_registry.R:540-551`) picks these classes up
automatically as `response_type = "survival"`.

All three inherit `Inference` and mix in
`components = c("BayesianBootstrap", "Wald")`; the KK variants
additionally follow `InferenceAbstractQuantileRandCI`'s pattern to add
`compute_rand_confidence_interval()`/`compute_rand_two_sided_pval()`,
exactly as the continuous/proportion KK quantile classes do.

`initialize(des_obj, model_formula = NULL, tau = 0.5, em_max_iter = ...,
em_tol = ..., verbose = FALSE)` asserts `response_type == "survival"`
(no `assertNoCensoring` — all censoring patterns are accepted) and
requires the `quantreg` package installed, same guard as
`InferenceContinQuantileRegr`.

## 2. Core algorithm — self-consistent EM on interval-censored data

Given design matrix `X` and per-subject bounds `(y_L_i, y_R_i)` — exact
observations have `y_L_i = y_R_i`, right-censored have `y_R_i = Inf`,
left-censored have `y_L_i = 0` (consistent with
`Design$add_one_subject_response()`'s representation):

1. **Initialize** `beta^(0)` from a naive fit: treat interval-censored
   observations at their midpoint (or `y_L` when `y_R = Inf`) and run
   ordinary `quantreg::rq()`.
2. **E-step (redistribute):** for each interval-censored subject
   (`y_L_i < y_R_i`), given `beta^(k)`, compute the conditional
   distribution of the "true" `y_i` within `(y_L_i, y_R_i)` implied by the
   current fit's residual distribution — Peng-Huang's redistribute idea,
   adapted to redistribute mass *within the known interval* rather than
   only to the right tail. Produces weighted pseudo-observations (mass
   split across a few support points, e.g. interval endpoints and
   empirical residual quantile points within the interval).
3. **M-step (refit):** stack pseudo-observations (weighted) with exact
   observations, refit via `quantreg::rq(..., weights = ...)` to get
   `beta^(k+1)`.
4. **Iterate** until `max(abs(beta^(k+1) - beta^(k))) < em_tol` or
   `em_max_iter` reached. Non-convergence is a failed fit (`NA`
   estimate/SE/df), same pattern as `set_failed_fit_cache()` in
   `InferenceContinQuantileRegr`.
5. Exact and right-censored observations are expected to fall out as
   special cases of the same loop; validating this reduction is a testing
   task, not assumed correct by construction.

## 3. Inference — bootstrap + asymptotic sandwich variance

- **Bootstrap (primary):** reuse the existing `BayesianBootstrap`
  component exactly as `InferenceContinQuantileRegr` does —
  `compute_estimate_with_bootstrap_weights()` reruns the full EM loop
  under resampled subject/block weights (warm-started from the unweighted
  `beta_hat` to reduce iteration count). This is the primary source of
  truth since it makes no asymptotic-approximation assumptions.
- **Asymptotic sandwich (secondary):** `V = A^{-1} B A^{-T}`, where `A` is
  a numerically-estimated Jacobian of the estimating-equation gradient at
  convergence (finite-difference perturbation of `beta_hat`) and `B` is
  the empirical outer-product-of-scores from the final E-step's
  pseudo-observation weights/residuals. Documented explicitly as a
  heuristic extension of Peng-Huang's asymptotics without a rigorous proof
  for the interval-censored case (parallel to how
  `InferenceSurvivalCoxPHRegr` documents its `icenReg`-based Wald path).
- Both paths surface through the existing `InferenceAsymp`/bootstrap
  contracts (`compute_asymp_confidence_interval`,
  `compute_asymp_two_sided_pval` for the sandwich; standard bootstrap
  CI/p-value machinery for `BayesianBootstrap`) — no new inference
  contract surface.
- Degrees of freedom for the sandwich Wald CI: `n - p`, approximate given
  the EM's fractional-mass pseudo-observations (note this in code
  comments).

## 4. KK design variants + randomization inference

- **`InferenceSurvivalKKQuantileRegrIVWC`:** fits the EM estimator
  separately on matched-pair rows and reservoir rows, combines the two
  `beta_hat_T` via inverse-variance weighting using each arm's sandwich
  variance (section 3).
- **`InferenceSurvivalKKQuantileRegrOneLik`:** pools matched-pair +
  reservoir rows into one stacked design, single EM/`rq()` fit over the
  combined data.
- **Randomization inference:** both KK variants inherit
  `InferenceAbstractQuantileRandCI`'s contract
  (`compute_rand_two_sided_pval`, `compute_rand_confidence_interval` via
  Zhang's test-inversion), requiring `compute_fast_randomization_distr()`
  to rerun the EM fit under permuted treatment assignments (same shape as
  `compute_fast_randomization_distr_via_reused_worker()` in the continuous
  class, but each "fast" refit is now a full EM loop rather than one
  `rq()` call).
- **Open performance risk:** randomization tests need O(thousands) of
  refits, each of which is now an iterated EM loop rather than a single
  `rq()` call — likely the dominant runtime cost of the whole feature.
  Mitigations to design during implementation: warm-starting each
  permutation's EM from the unpermuted `beta_hat`, reusing
  `fit_warm_keep`-style rank-reduction caching across permutations,
  and/or a tighter `em_max_iter` specifically for the randomization path.
  Not resolved in this design — flagged for the implementation plan.

## 5. Testing plan

- **Estimator correctness / reduction checks:**
  - No censoring at all → matches plain `quantreg::rq()` exactly.
  - Pure right-censoring → matches `quantreg::crq()` (Portnoy/Peng-Huang)
    closely. This is the unverified reduction claim from section 2/scope
    decisions, made concrete as a numerical test (comparing against
    `crq()` as ground truth, even though `crq()` is never used at
    runtime).
  - Simulated interval-censored data from a known AFT/location-shift
    model recovers the true `beta_T` at increasing `n` (consistency
    check).
- **Convergence/failure handling:** degenerate designs (rank-deficient
  `X`, too few residual degrees of freedom, all-censored subsets) return
  `NA` via `set_failed_fit_cache()`-style handling; EM non-convergence
  within `em_max_iter` is a failed fit, never a silent partial answer.
- **Inference agreement:** bootstrap CI and sandwich-Wald CI should
  roughly agree (coverage/width) on simulated data with known ground
  truth. Large disagreement is a signal the sandwich formula's heuristic
  extension (section 3) is unreliable and should be documented as such,
  not silently trusted.
- **KK variants:** extend the registry-driven fixture pattern already
  used for `inference_continuous_KK_quantile_regr_ivwc/one_lik` (via
  `constraint_survival_censoring_supported` and friends in
  `public_argument_combination_constraints.R`) with
  `response_type = "survival"` fixtures across the censoring-pattern
  matrix; spot-check randomization p-value/CI against brute-force full
  permutation on small `n` where feasible.
- **Registry wiring:** new classes need entries in
  `inference_class_registry.R`; naming as `InferenceSurvivalQuantileRegr`
  / `InferenceSurvivalKKQuantileRegrIVWC` /
  `InferenceSurvivalKKQuantileRegrOneLik` keeps
  `infer_inference_response_types()`'s existing `^InferenceSurvival`
  regex working with no changes to that function.

## Open risks (carried into implementation planning)

1. The EM-to-Peng-Huang reduction (section 2, point 5) is asserted but
   unverified until the numerical test in the testing plan is written and
   passes.
2. The sandwich variance (section 3) is a heuristic extension without a
   rigorous proof for interval-censored data; if bootstrap and sandwich
   CIs disagree substantially in testing, the sandwich path may need to
   be dropped or re-derived.
3. Randomization-inference performance (section 4) is unresolved; the
   implementation plan needs a concrete mitigation (warm-starting,
   rank-reduction caching, tighter iteration caps) or an explicit decision
   to accept slower randomization tests for this class family.
