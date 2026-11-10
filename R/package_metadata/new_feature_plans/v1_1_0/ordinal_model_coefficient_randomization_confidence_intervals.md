# Native randomization confidence intervals for ordinal model coefficients

## Status and release guard

Not implemented. Generic randomization and randomization-bootstrap confidence
intervals are disabled for ordinal model-coefficient estimands. The registry
removes the `randomization_ci` and `randomization_bootstrap_ci` capabilities,
and direct calls fail immediately with an explicit not-implemented error. An
unsupported CI must not mark the otherwise-valid primary estimate
nonestimable through the shared fit cache.

The ordinary `randomization_test` and `randomization_bootstrap` p-value
capabilities are not removed by this guard. This is intentionally a CI-only
change. In particular, the default `delta = 0` tests do not require inversion
over artificial nonzero category shifts.

The authoritative affected-class list is
`EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_CLASSES` in
`R/EDI/R/inference_class_registry.R`. It covers the adjacent-category,
continuation-ratio, cumulative-link, partial-proportional-odds, stereotype,
ordinal GEE, ordinal GLMM, and ordinal CLMM coefficient estimators. Rank, sign,
ridit/Mann-Whitney, and g-computation mean-difference estimands are deliberately
not included.

## Why the generic implementation is invalid

The current generic CI obtains a null distribution at each candidate `delta`
by shifting observed responses. For an ordinal outcome this means adding a
continuous coefficient-scale value to integer category codes. The operation:

- creates response values outside the observed category support;
- does not impose a null value on an adjacent-category, continuation-ratio,
  cumulative-link, stereotype, GEE, GLMM, or CLMM coefficient;
- does not define the missing potential outcomes required by a Fisher sharp
  null; and
- can produce a nonmonotone or disconnected acceptance set that the current
  two-bound bisection cannot represent.

Randomization-bootstrap CI inversion inherits the same defect and additionally
mixes resampling with the invalid response shift.

The 2026-08-24 `InferenceSuite` report exposed the practical symptom: the
generic randomization and randomization-bootstrap intervals for several
ordinal regressions excluded zero while their associated p-values exceeded
0.05. This was not ordinary Monte Carlo boundary noise; the CI and test were
not operating on the same valid null model.

There is also an independent generic inversion defect to correct before any
re-enablement: a two-sided p-value must be inverted at `alpha`, not at
`alpha / 2`.

## Required statistical contract

A future implementation must be estimator-specific. Each supported class must
provide a native null-imposition contract containing at least:

1. the coefficient parameterization and treatment-coefficient index;
2. a constrained fit at the candidate coefficient `delta`;
3. nuisance-parameter estimation rules under that constraint;
4. the observed and randomized test statistic on the same scale;
5. the assignment mechanism and the valid resampling unit; and
6. fit diagnostics that turn failed or weakly identified refits into typed
   nonestimable draws.

Merely transforming ordinal category labels is never an acceptable
implementation of this contract.

## Candidate implementation

### 1. Introduce a native class hook

Add a component contract along these lines:

```r
private$ordinal_randomization_ci_spec()
private$fit_under_randomization_null(delta, assignment, warm_start = NULL)
private$randomization_score_at_null(fit, assignment)
```

The spec should declare the estimand scale, null-fit method, nuisance handling,
coefficient mapping, supported design families, and whether a finite-sample
sharp-null interpretation exists. A class must not regain either CI capability
until it supplies and validates the hook.

### 2. Prefer constrained-score inversion

For model coefficients, a constrained score or efficient-score statistic is
the most coherent first implementation:

- constrain the treatment coefficient to `delta`;
- estimate thresholds and nuisance slopes under that constraint;
- compute the treatment score, adjusted by the nuisance information;
- replay valid treatment assignments while preserving ordinal responses and
  category support; and
- form a two-sided randomization p-value from the same statistic.

This is model-assisted randomization inference, not automatically an exact
Fisher interval. Documentation must state its assumptions. A truly exact
Fisher interval would instead need an explicit sharp causal model capable of
generating every subject's ordinal potential outcome at each `delta`; a link
coefficient alone does not provide that model.

### 3. Invert the test robustly

Evaluate the two-sided p-value against `alpha`. Use common random assignments
across candidate values to reduce Monte Carlo noise. Start with an adaptive
grid, identify every accepted component, and refine crossings locally. Do not
assume monotonicity or silently replace a disconnected confidence set with its
convex hull. If the public API cannot yet represent a confidence set, return a
typed nonestimable result with diagnostics rather than a misleading interval.

### 4. Implement randomization-bootstrap CIs on the same contract

Only after ordinary randomization inversion is validated should the bootstrap
variant be restored. It must preserve the design's resampling unit (subject,
pair, or block), replay assignment within each resample, use the same
constrained estimator and coefficient mapping, and reject numerically invalid
refits. No `t0 + delta` shortcut is permitted unless the class proves an affine
statistic contract; ordinal likelihood coefficients are generally not affine.

### 5. Re-enable deliberately

Re-enable one class at a time by removing its two exclusions from the registry
only after its native hook, diagnostics, tests, and documentation land. Keep
the central class list until every listed estimator has a valid implementation;
then retire the list and the direct-call guard together.

## Acceptance criteria

- Candidate null values never change the number or labels of ordinal categories.
- At every checked `delta`, `delta` is accepted by the reported 95% confidence
  set exactly when its two-sided p-value is at least 0.05, up to a declared
  Monte Carlo tolerance.
- Refined finite endpoints have p-values near `alpha`, not `alpha / 2`.
- The acceptance-set algorithm detects and reports disconnected sets.
- Treatment-coefficient extraction is identical to the class's ordinary fit.
- Constrained and randomized refits apply the class's standard convergence,
  conditioning, variance, and separation diagnostics.
- Fixed, blocked, and matched designs preserve their proper assignment and
  resampling units.
- Regression fixtures cover every mismatch found in
  `inference_suite_results_20260824_185009.html`.
- Simulation studies report coverage, type-I error, Monte Carlo error, and
  nonestimable rates under null, weak-signal, sparse-category, and separated
  regimes.
- Capability and path-audit tests prove that unsupported classes remain NI and
  supported classes expose both the method and the estimator-specific hook.

## Out of scope for the temporary guard

This change does not claim that every retained ordinal randomization p-value is
valid for arbitrary nonzero `delta`. The future native contract must either
support such null values estimator-specifically or reject them explicitly.
The present guard prevents the package from constructing and reporting the
known-invalid confidence intervals while preserving existing default-null test
paths.
