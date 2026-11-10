# Ordinal KK GEE Bayesian Bootstrap — v1.1.0 Implementation Plan

Written 2026-08-24.

## Status and release guard

`InferenceOrdinalKKGEE` Bayesian-bootstrap inference is disabled until this
plan is complete. The primary estimator is `multgee::ordLORgee`, a
proportional-odds local-odds-ratio GEE over matched-pair and reservoir
clusters. Its current non-uniform weighted-refit path instead calls
`fast_ordinal_regression_weighted_cpp`, which fits a plain weighted ordinal
logistic model without the GEE estimating equations, working association, or
matched-pair clustering. Bootstrap draws therefore do not currently refit the
estimator whose sampling distribution they purport to approximate.

The release guard consists of both:

- `private$supports_bayesian_bootstrap() == FALSE`, which makes all public
  Bayesian-bootstrap entry points fail before drawing weights; and
- registry exclusion of the `bayesian_bootstrap` capability, so discovery and
  orchestration APIs do not advertise the operation.

Nonparametric bootstrap behavior is outside this plan and remains unchanged.

## Goal

Provide weighted refits that solve the same ordinal local-odds-ratio GEE as
the unweighted `ordLORgee` fit, using the design's exchangeable bootstrap unit
(matched pair or reservoir singleton), while preserving the package's
treatment-effect sign and estimand conventions.

## Implementation phases

### 1. Establish the estimand and sign contract

- Record the exact `ordLORgee` treatment coefficient convention with a small,
  deterministic ordinal matched-design fixture.
- Verify coefficient extraction by name, category ordering, and treatment
  coding for both `model_formula = ~1` and covariate-adjusted fits.
- Add a unit-weight invariant: a weighted refit with all weights equal must
  reproduce `compute_estimate(estimate_only = TRUE)` within optimizer
  tolerance and with the same sign.

### 2. Choose and implement a genuine weighted GEE path

- First determine whether `multgee` exposes a supported case-weight or
  frequency-weight route that preserves `ordLORgee`'s estimating equations
  and local-odds-ratio association model.
- If it does, wrap that route and expand design-level weights to matched-pair
  and reservoir rows using the existing Bayesian-bootstrap context.
- If it does not, implement the weighted proportional-odds local-odds-ratio
  estimating equations in EDI. Apply each exchangeable-unit weight to that
  unit's full estimating-equation contribution; do not weight augmented rows
  as if they were independent observations.
- Preserve the original cluster IDs, category levels, working association,
  coefficient ordering, convergence diagnostics, and treatment coefficient
  extraction.
- Keep the existing plain weighted ordinal regression only as an explicitly
  named diagnostic comparator, never as the production Bayesian-bootstrap
  refit.

### 3. Weighted uncertainty for studentized methods

- Return a replicate sandwich standard error when
  `estimate_only = FALSE`.
- Confirm that the bread and meat both use the same unit weights and cluster
  structure as the point-estimate equations.
- Leave studentized/bootstrap-t types disabled independently if stable
  replicate standard errors cannot be supplied in the first implementation.

### 4. Validation

- Unit weights equal the primary `ordLORgee` estimate and sandwich SE.
- Multiplying every weight by a positive constant leaves the coefficient
  unchanged.
- Integer pair/singleton weights agree with an explicitly replicated-cluster
  reference fit where that comparison is well-defined.
- Permuting row order without changing cluster membership leaves results
  unchanged.
- Simulated positive and negative treatment effects retain their sign under
  weighted refits.
- Serial and parallel Bayesian-bootstrap distributions agree for a fixed
  seed.
- Percentile, basic, Wald, and BCa outputs are finite on stable fixtures and
  use distributions centered on the original estimator's scale. Do not use
  point-estimate inclusion as a universal percentile-interval invariant.
- Exercise `KK21`, `KK21stepwise`, `KK14`, and `FixedBinaryMatch`, with and
  without covariate adjustment, including reservoir singletons.

### 5. Re-enable deliberately

- Remove `InferenceOrdinalKKGEE` from
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES`.
- Remove the class-specific `supports_bayesian_bootstrap = function() FALSE`
  override.
- Replace the disabled-behavior test with capability, numerical parity, and
  end-to-end Bayesian-bootstrap tests.
- Run the comprehensive ordinal matrix and review estimate/CI alignment,
  finite-replicate rates, warnings, and runtime before releasing v1.1.0.

## Acceptance criteria

Bayesian bootstrap may be re-enabled only when the weighted refit targets the
same ordinal GEE estimand as `compute_estimate()`, unit weights reproduce the
ordinary fit, sign alignment holds on deterministic and simulated fixtures,
and the supported interval/p-value variants pass serial and parallel tests.
