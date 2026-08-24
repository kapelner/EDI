# Ordinal Adjacent-Category-Logit Bayesian Bootstrap Implementation Plan

Written 2026-08-24.

## Status and release guard

Bayesian-bootstrap inference for `InferenceOrdinalAdjCatLogitRegr` is disabled
until this plan is complete. The primary estimator uses EDI's native
adjacent-category likelihood. Its current non-uniform weighted hook instead
fits a cumulative-logit surrogate, so weighted draws do not target the
estimator returned by `compute_estimate()`.

The release guard consists of both:

- `private$supports_bayesian_bootstrap() == FALSE`, which stops every public
  Bayesian-bootstrap entry point before weights are drawn; and
- registry exclusion of the `bayesian_bootstrap` capability, so discovery and
  orchestration APIs do not advertise it.

Nonparametric subset bootstrap behavior is outside this plan and remains
unchanged.

## Goal

Implement subject-weighted refits of the same adjacent-category likelihood as
the ordinary estimator, preserving category ordering, treatment coding,
coefficient extraction, warm starts, and diagnostics.

## Implementation phases

### 1. Fix the estimator contract

- Record the native parameter ordering and the exact treatment coefficient
  extraction used by the ordinary adjacent-category fit.
- Record response-level ordering and the intercept/threshold convention.
- Add deterministic fixtures for positive and negative treatment effects,
  with and without covariates.

### 2. Add a native weighted C++ backend

- Extend `AdjacentCategoryLogitNegLogLik` in
  `R/EDI/src/fast_adjacent_category_logit.cpp` to accept one nonnegative finite
  weight per subject.
- Multiply each subject's complete adjacent-category likelihood contribution
  by that subject's weight.
- Apply the same weights consistently to the gradient and observed/Fisher
  information. Do not replace the adjacent-category likelihood with a
  cumulative-logit or other ordinal surrogate.
- Add a separate exported entry point, preferably
  `fast_adjacent_category_logit_weighted_cpp(X, y, weights,
  warm_start_beta = NULL, ...)`, rather than changing the existing exported
  signature.
- Return the same coefficient, convergence, objective, information, and
  treatment-variance fields as the ordinary backend.

### 3. Integrate the weighted estimator

- Replace `weighted_ordinal_bootstrap_surrogate_fit(..., method = "logistic")`
  in `compute_estimate_with_bootstrap_weights()` with the native weighted
  adjacent-category entry point.
- Continue to expand block, cluster, or subject weights with the existing
  resampling-unit machinery before calling C++.
- Extract the treatment coefficient exactly as the ordinary fit does:
  `as.numeric(res$b[1L])`.
- Use the ordinary fit's convergence, information-conditioning, coefficient,
  and standard-error acceptance predicate for weighted fits as well.
- Retain the cumulative-logit helper only as an explicitly named diagnostic
  comparator, never as a production Bayesian-bootstrap path.

### 4. Validate the backend

- All-one weights reproduce the ordinary coefficient, objective, gradient,
  information, and standard error within numerical tolerance.
- Multiplying all weights by a positive constant leaves coefficients
  unchanged and scales objective derivatives as expected.
- Integer weights agree with an explicitly row-replicated native fit.
- Analytic weighted gradients and Hessians agree with finite differences.
- Positive and negative simulated effects preserve their sign under weighted
  fits.
- Zero weights remove the subject's full likelihood contribution without
  disturbing response-level indexing.
- Serial and parallel Bayesian-bootstrap distributions agree for a fixed
  seed.
- Percentile, basic, Wald, BCa, and p-value paths remain on the ordinary
  estimator's scale. Enable studentized variants only after weighted standard
  errors pass their own validation.

### 5. Re-enable deliberately

- Remove `InferenceOrdinalAdjCatLogitRegr` from
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES`.
- Remove the class-local `supports_bayesian_bootstrap = function() FALSE`
  override and its component-contract declaration.
- Replace the disabled-behavior test with backend parity, capability, and
  end-to-end Bayesian-bootstrap tests.
- Update `path_audits_source.R` and `weighted_fitting.md` to mark the native
  path implemented.
- Run the comprehensive ordinal matrix and review estimate signs, interval
  scale, finite-replicate rates, convergence diagnostics, and runtime before
  release.

## Acceptance criteria

Bayesian bootstrap may be re-enabled only when all-one weights reproduce the
ordinary adjacent-category fit, non-uniform weights use the native likelihood,
unusable fits are rejected consistently, and every advertised
Bayesian-bootstrap variant passes deterministic serial and parallel tests.
