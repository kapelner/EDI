# Negative-Binomial Dispersion-Parameter Convergence on Non-Overdispersed Data

> **Depends on:** none (touches the negative-binomial-family C++ kernels --
> `src/fast_zinb.cpp`, `src/fast_negbin_regression.cpp`,
> `src/fast_hurdle_negbin.cpp` -- and possibly the shared optimizer
> convergence check in `src/_helper_functions_core.h` if the chosen fix
> needs a core change rather than a per-kernel one; see options below).
> Not yet slated for a release line -- needs a Phase-0-style decision
> (which option, and whether it's worth the C++ risk/effort) before
> scheduling.

## Symptom (2026-08-27)

`InferenceCountZeroInflatedNegBin` ("Zero Infl Neg Bin") reported `nonest`
for **every** method (`wald`, `rand`, `rand boot (%ile)`, `jackknife`,
`score`, `lik_ratio`, `gradient`, `LR ≈Bartlett`, `param boot` ×2, `bayes
boot (%ile)`, `boot (%ile)`) against `run_inference_suite_demo.R`'s
synthetic `count` response (`rpois(n, exp(0.5 + 0.3*betaT*w + 0.1*x1))` --
a plain Poisson draw, no injected excess zeros or overdispersion).

Reproduced directly: `fast_zinb_cpp()` returns `converged = FALSE` on this
data, with the fitted dispersion parameter (`log_theta`, the last of the 15
parameters for this `n=100, p=5` fixture) at `13.7` (i.e. `theta ≈
e^13.7 ≈ 890,000` -- already far into "the negative binomial is
indistinguishable from Poisson" territory) while the other 14 coefficients
look like ordinary, plausible finite values. On data with genuinely injected
excess zeros, the identical class/design/n converges normally
(`est = 0.60`, `converged = TRUE`).

## Root cause

`fast_zinb_internal()` (`src/fast_zinb.cpp:166-204`) dispatches to
`optimize_fixed_likelihood()` with `optimization_alg = "lbfgs"` (the
default), `maxit = 1000`, `tol = 1e-8`. For the LBFGS path
(`optimize_likelihood_lbfgs()`, `src/_helper_functions_core.h:1234-1286`),
convergence is declared when *either* the gradient norm drops below `tol`
*or* LBFGSpp's own internal relative-function-decrease criterion fires
before `maxit` iterations (`lbfgs_params.delta = tol` -- also `1e-8`,
per `optimizer_diagnostics_report.md`'s TODO-4 fix that added this OR
specifically so ordinary well-behaved fits plateauing near tight tolerances
aren't misclassified as failures).

The negative-binomial dispersion parameter is parameterized as `log_theta`
(unconstrained real line, `theta = exp(log_theta)`, `src/fast_zinb.cpp:86`
and identically in `fast_negbin_regression.cpp`/`fast_hurdle_negbin.cpp`).
When the data has **no genuine overdispersion** relative to what the fitted
mean structure already explains, the negative-binomial likelihood's
**profile likelihood in `theta` has no interior maximum** -- it keeps
improving, at a logarithmically decaying rate, as `theta -> infinity`
(the NegBin -> Poisson limit). Two consequences, both satisfied
simultaneously in the reproduction above:

1. The gradient component with respect to `log_theta` never actually
   reaches `0` in finite time (it only decays, never vanishes) -- so the
   gradient-norm criterion can't fire.
2. The objective *value* also keeps improving at a rate that, empirically,
   stays above the tight `1e-8` relative-decrease threshold for far longer
   than 1000 iterations on this fixture -- so LBFGSpp's own OR'd fallback
   criterion doesn't fire either.

The **other 14 parameters** are, by the time this happens, most likely
already sitting very close to their own true optimum (their own gradient
components are probably small) -- the entire fit is being held hostage by
one parameter walking up an asymptotically flat, unbounded ridge. Since
`fit.converged` is a single joint boolean over the *whole* parameter
vector's gradient norm, there is no way for the current code to distinguish
"genuinely stuck, don't trust any of these numbers" from "everything of
interest has converged, only the nuisance dispersion parameter is still
drifting harmlessly toward its own well-known unbounded limit."

This is not a ZINB-only phenomenon: `log_theta` (or an equivalent
unconstrained dispersion parameterization) also appears in
`fast_negbin_regression.cpp` (plain `InferenceCountNegBin`) and
`fast_hurdle_negbin.cpp` (`InferenceCountHurdleNegBin`) -- both share the
same theoretical failure mode on non-overdispersed data, just not yet
reported/reproduced against those two classes specifically (see TODO-1
below).

## Remediation options

1. **Reparameterize the dispersion parameter as `phi = 1/theta` (or
   `log(phi)`) instead of `log(theta)`.** The Poisson limit (`theta ->
   infinity`) becomes `phi -> 0`, a well-defined, *attainable* boundary
   rather than an unbounded ridge -- a well-known, standard fix for exactly
   this problem in the negative-binomial-fitting literature (e.g. this is
   effectively what many robust NegBin implementations do to avoid the same
   optimizer pathology). Once `phi` is small, its own gradient component
   with respect to the likelihood shrinks toward a genuine, reachable zero
   (the boundary itself, not an asymptote at infinity), so ordinary
   gradient-norm convergence becomes achievable in finite iterations. This
   is the most *principled* fix -- it removes the pathology at its source
   rather than working around the optimizer's convergence check -- but
   requires re-deriving the score/Hessian entries for `log_theta` in terms
   of the new parameterization in all three kernels (`fast_zinb.cpp`,
   `fast_negbin_regression.cpp`, `fast_hurdle_negbin.cpp`), re-validating
   against `glmmTMB`/`glm.nb`-style references
   (`test-rcpp-fitting-equivalence.R` already has a `fast_zinb_cpp` vs
   `glmmTMB` golden -- extend it with a non-overdispersed fixture as the
   regression test for this exact bug), and updating every place that reads
   back `theta`/`log_theta` from the fitted parameter vector (sandwich SE
   construction, warm-start caching, `record_zero_augmented_fit_summary()`,
   etc. -- audit needed, not a drop-in swap).
2. **Partial/profile convergence acceptance, scoped to the dispersion
   parameter, inside each affected kernel (not the shared core helper).**
   After `optimize_fixed_likelihood()` returns `converged = FALSE`, check
   whether the *non-dispersion* sub-vector of the final gradient is already
   below `tol` on its own, and whether `log_theta` is large (past some
   threshold past which `theta` is practically indistinguishable from
   "no overdispersion" at any sane sample size, e.g. `theta > 1e4` or a
   data-driven multiple of the fitted means) and still monotonically
   improving (not oscillating/diverging). If so, accept the fit as
   converged for the purposes of every *other* parameter (the treatment
   coefficient in particular), while still flagging the dispersion estimate
   itself as unreliable/at-the-boundary in the returned diagnostics. Lower
   engineering risk than option 1 (touches only the post-fit classification
   logic inside the three affected `.cpp` files, not the score/Hessian
   derivation, and not `_helper_functions_core.h`'s shared convergence
   check used by every other likelihood path in the package) but more of a
   targeted patch than a real fix -- still needs care to avoid accepting a
   fit that's actually stuck for an unrelated reason (a genuinely singular
   Hessian elsewhere, a different parameter also drifting, etc.), so the
   "non-dispersion sub-gradient is small AND log_theta is both large and
   still monotonically improving in the right direction" check needs to be
   conservative, not just "log_theta is big."
3. **Cap `log_theta` at a large-but-finite bound during optimization**
   (e.g. clamp `theta` at some large multiple of the fitted means, or a
   fixed large constant), turning the unbounded ridge into a bounded one
   with a reachable interior-ish optimum at the cap. Simplest to implement,
   but picking a principled cap is itself hard (too small biases genuinely
   overdispersed-but-extreme fits; too large just delays the same problem)
   and a hard clamp can produce a visible kink/discontinuity in the
   likelihood surface right at the boundary, which is exactly the kind of
   thing that can make *other* diagnostics (Hessian-based SEs, Bartlett
   corrections) misbehave. Probably the weakest of the three options
   unless 1 and 2 both turn out to be too expensive for the value here.

## Implementation decision (2026-08-27)

Option 2 is implemented as the conservative near-term fix, shared only by
the three negative-binomial-family kernels through
`src/_negbin_boundary_convergence.h` (not through the generic optimizer).
A failed joint fit is reclassified only when all of the following hold:

1. dispersion is free and `log_theta >= log(1e4)`;
2. the norm of the free non-dispersion gradient is at most
   `max(10 * tol, 1e-6)`;
3. the dispersion gradient is negative (increasing theta improves the
   negative log likelihood); and
4. a probe at `log_theta + log(2)` does not worsen the objective, remains
   finite, and retains a non-positive dispersion gradient.

Accepted fits return `dispersion_at_poisson_boundary = TRUE`. Their
coefficient covariance is computed conditional on the Poisson boundary by
excluding the dispersion coordinate; the dispersion row/column of a full
covariance result is `NA`. This makes the unreliable boundary estimate
explicit while keeping treatment-coefficient inference available. Ordinary
interior NegBin fits and the generic optimizer convergence contract are
unchanged.

## Implementation TODOs

1. **Reproduce (or rule out) the same failure against plain `InferenceCountNegBin`
   and `InferenceCountHurdleNegBin`** on non-overdispersed synthetic data,
   confirming or narrowing the blast-radius claim above before scoping
   further work -- a single-part NegBin's likelihood surface may behave
   better in practice even though the theoretical pathology is shared (fewer
   interacting mixture components).
2. **Decision:** which remediation option (or combination -- e.g. option 2
   as a near-term mitigation, option 1 as the eventual real fix) to pursue,
   and whether this is worth prioritizing at all given it only produces an
   honest `nonest`, never a wrong number.
3. If option 1: derive the reparameterized score/Hessian entries for each
   of the three kernels, audit every downstream consumer of the raw
   `log_theta`/`theta` parameter slot (warm-start caching
   `get_backend_warm_start_args()`, `record_zero_augmented_fit_summary()`,
   sandwich SE construction, the R-level `smart_cold_start` initial value
   `par[n_par-1] = log(1.0)` at `fast_zinb.cpp:189` and its
   `cold_starts.md` documentation), and re-validate against
   `test-rcpp-fitting-equivalence.R`'s existing `glmmTMB` goldens plus a
   new non-overdispersed fixture.
4. If option 2: define the "non-dispersion sub-gradient small enough, and
   `log_theta` large *and* still monotonically improving" acceptance rule
   precisely (exact thresholds, what "still monotonically improving" means
   operationally given only the final iterate is available -- may need
   LBFGSpp to report the last few objective values, not just the final one,
   which could itself require a small `LikelihoodFitResult`/solver-wrapper
   change), then implement per-kernel (not in the shared helper) and add
   the `diagnostics` field that flags the dispersion estimate as
   boundary/unreliable even when the rest of the fit is accepted.
5. Whichever option: add the regression test this bug currently has none
   of -- fit each affected class to genuinely non-overdispersed count data
   and assert the treatment coefficient/its CI *are* estimable (not `NA`),
   the mirror image of `test-rcpp-fitting-equivalence.R`'s existing
   overdispersed-data goldens.
6. Cross-reference from `_master.md`/a release-line file once a decision
   and a target release are made.

## Testing/verification plan

- TODO-1's reproduction (or non-reproduction) against
  `InferenceCountNegBin`/`InferenceCountHurdleNegBin` is the first gate --
  it determines whether this is a three-kernel problem or genuinely
  ZINB-specific in practice.
- TODO-5's new non-overdispersed-data regression test is the load-bearing
  test for whichever fix ships -- it directly encodes "this specific
  convergence failure cannot silently reappear."
- Whichever option ships, re-run `test-rcpp-fitting-equivalence.R` in full
  (not just the new fixture) to confirm no regression on the existing
  genuinely-overdispersed/genuinely-inflated goldens -- especially
  important for option 1, which changes the optimization parameterization
  for every fit of the affected kernels, not just the pathological case.
- No change expected outside the three negative-binomial-family kernels
  (option 1/3) or their immediate R-level callers (option 2's diagnostics
  field) -- Poisson-family zero-augmented/hurdle classes
  (`InferenceCountZeroInflatedPoisson`, `InferenceCountHurdlePoisson`) have
  no dispersion parameter and are unaffected by any option here.
