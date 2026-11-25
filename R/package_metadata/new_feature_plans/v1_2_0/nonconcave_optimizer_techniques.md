# Optimizer Techniques for the Nonconcave Likelihoods

> **Depends on:** the registry's likelihood properties in
> `R/EDI/R/inference_class_registry.R` (`likelihood_concave`,
> `boundary_parameters`, `parameter_layout`, `derivatives`,
> `nonregular_points`; added 2026-11-16), which tell each technique below
> which classes it applies to and where the nuisance coordinates sit in the
> parameter vector. **Composes with:**
> `../v1_1_0/multistart_nonconcave_likelihoods.md` (`release_v1_1_0.md →
> TODO-17s`, remainder `release_v1_2_0.md → TODO-20`): techniques 1 and 2
> here are extra *deterministic starts* for its
> `optimize_fixed_likelihood_multistart()`, and techniques 3 and 6 are
> checks that decide whether its random layer runs at all.
> `em_algorithm_zero_inflated_mixtures.md` (`release_v1_2_0.md → TODO-21`)
> is technique 5 and is not repeated here. Release: v1.2.0
> (`release_v1_2_0.md → TODO-202`).

Date: 2026-11-16

## Why

Multistart (the v1.1.0 plan) is random restarts. It finds a better optimum
only if a start happens to land in that optimum's basin, and it can't
certify the result. In EDI's nonconcave likelihoods, the nonconcavity sits
in one to three nuisance coordinates. These are σ (random effect), θ
(negative-binomial dispersion), φ (beta precision), π (inflation), ρ
(correlation) and the copula θ. The regression block β is concave once
those are fixed. The techniques below use that structure.

Evidence from 2026-11-16 (randomization warm-start work):

- Randomization replicates used to chain warm starts. For nonconcave
  classes they now restart from the full-data MLE
  (`compute_randomization_distr_via_reused_worker_states()` in
  `R/EDI/R/inference_all_abstract_rand.R`; test
  `test-rand-warm-start-anchoring-nonconcave.R`). In a ZIP example (n = 80,
  zero-part treatment coefficient 11.8 at the observed fit), chaining moved
  17 of 30 replicates into another optimum, and running the same
  permutations in reverse changed the estimates by up to 0.44.
- That ZIP example was not an optimizer failure. Fresh fits on the permuted
  data match `pscl::zeroinfl` exactly. The replicates were wrong because they
  warm-started from the full-data fit, which sits on a flat zero-inflation
  ridge (zero-part intercept -23.8, treatment +23.8). With warm starts off,
  every replicate is correct. This is a v1.0.6 bug fix
  (`release_v1_0_6.md → TODO-6`), not part of this plan. It shows why T2
  (start from the concave limit) is worth having as a fallback start.

## Techniques

### T1. Profile over the nuisance parameters on a grid

Fix the nuisance block on a 1-D or 2-D grid. At each grid point, fit β with
the class's existing concave (or log-concave-link) inner kernel, then polish
jointly from the best grid point. Integrating out a random effect with a
log-concave link keeps the inner problem concave (Prékopa). Under these
conditions the grid gives a global guarantee up to grid resolution, which
random restarts can't.

- Applies to classes whose `parameter_layout` has one to two nuisance
  blocks of size 1: NegBin, HurdleNegBin, Beta, Weibull frailty, GLMM
  (log σ), and the ordinal GLMM. ZINB is 2-D (log θ plus the inflation
  intercept). Stereotype φ is K−2-dimensional, so it is out of scope
  unless K ≤ 4.
- The grid runs on the natural scale and includes the boundary point
  (σ = 0, θ = ∞, φ = ∞), so a boundary MLE is found directly.
- Cost is grid size times one concave fit. Use a coarse grid (about 15
  points) then golden-section on the profile, since the profile is 1-D
  and Brent is already in v1.1.0.

### T2. Continuation from the concave limit

Start at the concave limit, where the model reduces to the concave
baseline: σ = 0 is the plain GLM, θ = ∞ is Poisson, π = 0 is no inflation,
and ρ = 0 is independence (copula and dependent-censoring models). Then
move the nuisance parameter into the interior in a few steps, warm-starting
each step.

- The `boundary_parameters` registry field lists exactly which limit each
  class has.
- It is cheap: the limit fit is usually already computed (the null model,
  or the class's GLM fallback).
- This becomes one more deterministic start in the multistart helper.

### T3. Check for a saddle point after convergence

At the reported optimum, factor the information matrix. If it is not
positive definite, the fit is at a saddle or on a ridge. Restart from
T1/T2 starts, or mark the fit `converged = FALSE` with reason
`"non_pd_information"`.

- `derivatives` says whether the information is analytic or numerical.
  For numerical information, use a relative eigenvalue tolerance, not a
  bare Cholesky.
- At a declared boundary (for example σ = 0), the information is legitimately
  singular along that coordinate. Check the PD condition on the
  non-boundary sub-block only, using `boundary_parameters` and
  `parameter_layout`.
- This is a pure check with no change on fits that pass.

### T4. Optimize boundary parameters on their natural scale with bounds

The engine is `"lbfgsb"` from
`trust_region_and_bounded_optimizer_engines.md` (TODO-203). This section
covers the per-family move to natural-scale bounds after that engine
ships.

Fit σ ≥ 0, θ⁻¹ ≥ 0 and φ⁻¹ ≥ 0 with box constraints (L-BFGS-B, or a
projected Newton step) instead of the unbounded log scale. On the log scale
the MLE σ = 0 sits at log σ = −∞. The optimizer then stops on the gradient
or step tolerance at some finite very negative value and reports
`converged = TRUE`. This is what happened in the GLMM/CLMM σ collapse, and
in the 2026-11-16 audit fits: ZINB inflation intercept ≈ −6, Clayton
log θ ≈ −18.7, frailty log σ_u ≈ −5.8.

- A change to the parameter scale changes reported nuisance values, and
  their SEs at the boundary. β is unchanged when the optimum is interior.
- `parameter_layout`'s `scale` field must be updated in the same change
  (`"log"` becomes `"constrained"`).
- The boundary case needs the χ̄² mixture for LR tests of σ = 0. That is
  out of scope here; record it in the class docs.

### T5. EM for the mixtures, then a Newton polish

This is `em_algorithm_zero_inflated_mixtures.md` (`release_v1_2_0.md →
TODO-21`). It is listed here only so the technique set is complete.

### T6. Use the null fit as a check on the full fit

The null model is nested in the full model. If the constrained null fit
reaches a lower negative log-likelihood than the full fit, the full fit
is at a local optimum. In that case, refit the full model from the null
solution (with the treatment coefficient at 0) and keep the better fit.

- The stereotype logit already does a version of this (see the stereotype
  learnings, 2026-09-21 and 2026-11-07). Generalize it to every class with
  `likelihood_concave = FALSE` that has a likelihood test spec.
- It is free whenever an LR test or the parametric bootstrap already
  computes both fits. Otherwise it costs one extra null fit, so make it
  opt-in for estimate-only calls.
- Record a provenance flag (`full_fit_rescued_by_null`) so calibration can
  count how often it triggers.

### T7. Trust-region Newton for small nuisance blocks

The engine is `"trust_region"` from
`trust_region_and_bounded_optimizer_engines.md` (TODO-203). This section
covers which classes use it.

For parameter vectors of moderate length (p plus at most 3 nuisance
coordinates), a trust-region Newton step (Moré–Sorensen, or dogleg with a
negative-curvature direction) handles indefinite Hessians directly.
L-BFGS's curvature pairs cannot represent negative curvature.

- Applies where `derivatives$information` is `"analytic"`. Numerical
  Hessians make each iteration cost O(p) gradient calls, so compare cost
  in the A/B harness first.
- This is the most invasive technique (a new optimizer next to
  `optimize_fixed_likelihood()`), so it comes last and is promoted only on
  an A/B harness win.

## Implementation phases

- [ ] Phase 1 (T3 + T6, checks only): add the post-convergence PD check and
  the null-versus-full check behind a policy table keyed on the registry.
  Measure the trigger rates on the calibration roster before any rescue
  path is switched on. Tests: one forced saddle (stereotype at
  β_T = 0) and one forced bad full fit (ZIP replicate from the evidence
  above).
- [ ] Phase 2 (T2 + T1 as multistart deterministic starts): add the
  concave-limit start and the 1-D profile start to
  `optimize_fixed_likelihood_multistart()`'s start list. Acceptance case:
  the four ZIP replicates above, warm-started from the ridge point, reach
  the independent global maximum to 1e-6 in log-likelihood (TODO-30 in
  v1.0.6 fixes them by not warm-starting; this case checks that the
  optimizer recovers anyway). Bit-for-bit whenever the primary start already
  wins (the multistart contract).
- [ ] Phase 3 (T4): move the variance and dispersion components to
  bounded natural-scale optimization, one kernel family per change (GLMM σ
  first, then NegBin θ, then frailty and copula). Update `parameter_layout`
  scales and their live-fit test in the same change.
- [ ] Phase 4 (T7): build a trust-region Newton prototype, A/B it against
  L-BFGS through `algorithm_ab_testing_framework.md`, and promote it only on
  a win.
- [ ] Phase 5: update docs and NEWS. Each class's Details gets a sentence on
  which techniques its fit uses. Add Python `edi_kernels` parity for any
  new kernel argument.

## Standing constraints

- Targeted compiles only (repo `CLAUDE.md`). Every new C++ helper is a leaf
  header with its `cpp_tests/` target.
- No default change without a calibration comparison
  (`calibration_study_accepted.csv` rows cite an open TODO).
- Concave classes (`likelihood_concave = TRUE`) must stay bit-for-bit.
