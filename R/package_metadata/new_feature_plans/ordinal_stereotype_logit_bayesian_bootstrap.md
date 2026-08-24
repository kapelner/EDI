# Ordinal Stereotype-Logit Bayesian Bootstrap Implementation Plan

Written 2026-08-24.

## Status and release guard

Bayesian-bootstrap inference for `InferenceOrdinalStereotypeLogitRegr` is
disabled until this plan is complete. The primary estimator uses EDI's native
stereotype-logit likelihood, including estimated category scores. Its current
non-uniform weighted hook instead fits a cumulative-logit surrogate and
therefore does not generate draws from the primary estimator's weighted
sampling distribution.

The release guard consists of both:

- `private$supports_bayesian_bootstrap() == FALSE`, which stops every public
  Bayesian-bootstrap entry point before weights are drawn; and
- registry exclusion of the `bayesian_bootstrap` capability, so discovery and
  orchestration APIs do not advertise it.

Nonparametric subset bootstrap behavior is outside this plan and remains
unchanged.

## Goal

Implement subject-weighted refits of exactly the same stereotype-logit
likelihood used by the ordinary estimator, preserving category ordering,
category-score estimation, treatment coding, coefficient extraction, and fit
diagnostics.

## Implementation phases

### 1. Fix the estimator contract

- Record the parameter ordering for intercepts, regression coefficients, and
  free category-score parameters in `fast_stereotype_logit_cpp`.
- Record the constraints and transformation that identify the category
  scores, and ensure weighted fits estimate them rather than holding them
  fixed or substituting a proportional-odds model.
- Add deterministic fixtures for positive and negative treatment effects,
  with and without covariates.

### 2. Add a native weighted C++ backend

- Extend the objective in `R/EDI/src/fast_stereotype_logit.cpp` to accept one
  nonnegative finite weight per subject.
- Multiply each subject's complete multinomial-softmax log-likelihood
  contribution by that subject's weight. Apply the same weight to every
  derivative block involving intercepts, regression coefficients, and
  category-score parameters.
- Weight the full gradient and observed/Fisher information consistently; do
  not expand the response into an unrelated binary likelihood.
- Add a separate exported entry point, preferably
  `fast_stereotype_logit_weighted_cpp(X, y, weights,
  warm_start_params = NULL, ...)`, rather than changing the existing exported
  signature.
- Return the same parameter fields, convergence flag, objective value,
  information matrix, and treatment variance fields as the ordinary backend.

### 3. Integrate the weighted estimator

- Replace `weighted_ordinal_bootstrap_surrogate_fit(..., method = "logistic")`
  in `compute_estimate_with_bootstrap_weights()` with the native weighted
  stereotype-logit entry point.
- Continue to expand block, cluster, or subject weights with the existing
  resampling-unit machinery before calling C++.
- Extract the treatment coefficient exactly as the ordinary fit does:
  `as.numeric(res$b[1L])`.
- Apply the class's current convergence, information-conditioning, standard
  error, and separation checks to every weighted fit.
- Retain the cumulative-logit helper only as an explicitly named diagnostic
  comparator, never as a production Bayesian-bootstrap path.

### 4. Validate the backend

- All-one weights reproduce the ordinary coefficient, category scores,
  objective, and standard error within numerical tolerance.
- Multiplying all weights by a positive constant leaves parameter estimates
  unchanged and scales the objective, gradient, and information as expected.
- Integer weights agree with an explicitly row-replicated native fit.
- Analytic weighted gradients and Hessians agree with finite differences.
- Positive and negative simulated effects preserve their sign under weighted
  fits.
- Zero weights remove a subject's full likelihood contribution without
  changing category indexing.
- Serial and parallel Bayesian-bootstrap distributions agree for a fixed
  seed.
- Percentile, basic, Wald, BCa, and p-value paths remain on the ordinary
  estimator's scale. Enable studentized variants only when weighted replicate
  standard errors pass the same validation.

### 5. Re-enable deliberately

- Remove `InferenceOrdinalStereotypeLogitRegr` from
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
ordinary stereotype-logit fit, non-uniform weights reestimate the native
likelihood and category scores, diagnostics reject unusable fits, and every
advertised Bayesian-bootstrap variant passes deterministic serial and parallel
tests.
