# `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` Optimizer Stability

> **Depends on:** nothing architectural. Two small, additive changes inside
> the existing Clayton-copula/loggamma-frailty C++ optimizer and its R
> fallback cascade; no public API change. **Release target: v1.1.0**
> (`release_v1_1_0.md → TODO-22`).

Written 2026-09-11, from a comprehensive-test-harness timing investigation
(not a user report). Owning plan for the bimodal-slowness finding
documented in `comprehensive_tests.R`'s BRT-sweep session history.

## Why

Production timing data (20 replicates, same design=KK21stepwise,
dataset=diamonds, `beta_T=0`, `design_formula=~1`) showed
`compute_lik_ratio_bartlett_approx_two_sided_pval()` on this class taking
0.5-1s for 18 of 20 replicates and 178.7s / 159.7s for exactly two (reps 1
and 13) — a ~200x outlier with everything about the scenario identical
except the specific data realization. A read-only investigation (this
session) traced the mechanism; it was not fixed.

## Root cause

`compute_lik_ratio_bartlett_approx_two_sided_pval` →
`InferenceExtBartlettApprox$get_bartlett_factor_approx`
(`inference_ext_bartlett_approx.R:53-94`) runs `B=99` Monte-Carlo null
replicates (`run_param_bootstrap_replicates`,
`inference_all_abstract_param_boot.R:582-696`), each calling
`simulate_under_lik_null` (`inference_survival_GLMM_weibull_frailty_
loggamma.R:840-920`), which does two `fast_clayton_weibull_aft_optim_cpp`
refits (full + null-constrained) per replicate.

Two compounding issues in that C++ optimizer
(`src/fast_survival_models_optim.cpp`):

1. **No bound on the dependence parameter.** The sibling normal-frailty
   optimizer (`fast_weibull_frailty_cpp`, `src/fast_weibull_frailty.cpp:
   319-323,426`) caps its analogous parameter at `max_abs_log_sigma=8.0`
   and uses a looser `eps_g=1e-6`/`maxit=300`. The Clayton/loggamma
   optimizer has no such cap — only `maxit=2000, reltol=1e-9`
   (`:743`) — and its objective merely *clips* `theta=exp(min(log_theta,
   10))` (`:69`) without constraining `log_theta` itself.
2. **Stale-gradient mismatch.** The gradient terms (`:111,121,135,148`)
   still multiply by the *unclipped* `theta` even where the objective used
   the clipped value. Once `log_theta > 10`, this leaves the optimizer
   seeing a persistent nonzero gradient on what is actually a flat
   objective surface, driving it toward the 2000-iteration cap instead of
   terminating.
3. **Cascading fallback only on this family's fit path.**
   `.fit_clayton_weibull_aft` (`helper_survival_fits.R:243-399`), when no
   warm start is cached (true for a fresh replicate object — the common
   case inside the B=99 loop), tries 3 C++ LBFGS starts, then 3 R
   `optim(BFGS)` starts, then 3 R `optim(Nelder-Mead, maxit=10000)` starts.
   The sibling normal-frailty fit (`.fit_weibull_frailty`, same file,
   line 503) is a thin direct pass-through with no cascade. When (1)+(2)
   above leave the C++ starts unconverged, this ladder's R-level
   Nelder-Mead tail is the expensive part.

Assessment (from the investigating agent): a real, data-dependent
numerical-cost bug, not an inherent fixed cost of the loggamma frailty
family — the two normal-frailty asymmetries (bound, gradient consistency)
are the most direct evidence this is fixable rather than structural.

## Proposal

- **TODO-1**: Add an explicit `log_theta` bound to
  `fast_clayton_weibull_aft_optim_cpp` (mirror `max_abs_log_sigma=8.0`'s
  role — same idea, different parameter name/scale; needs its own
  numerically-justified cap, not a blind copy of `8.0`).
- **TODO-2**: Fix the gradient/objective clipping mismatch (`:69` vs.
  `:111,121,135,148`) so both consistently use the clipped `theta` — this
  alone may resolve most of the thrashing even before TODO-1 lands.
- **TODO-3**: After TODO-1/2, re-run this session's production scenario
  (KK21stepwise/diamonds/`beta_T=0`/`~1`, ideally the exact reps 1 and 13
  seeds) to confirm the outlier is gone; if any residual slow tail remains,
  consider tightening `.fit_clayton_weibull_aft`'s fallback cascade (e.g.
  drop or shrink the Nelder-Mead tail's `maxit=10000`) as a second lever.
- **TODO-4**: Decide whether a bounded `log_theta` changes any existing
  golden-test point estimates for this class (expected: no, since a
  well-converged unclipped fit should already sit well inside any
  sane bound — but verify, not assume).

## Tests

- Golden-test parity for `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`
  before/after (point estimate, SE, Bartlett-approx p-value) on existing
  fixtures — must be bit-for-bit or within existing tolerance.
- Targeted timing regression: construct the reps-1/13-shaped scenario (or
  a synthetic data realization known to drive `log_theta` large) and
  assert `compute_lik_ratio_bartlett_approx_two_sided_pval()` completes
  well under the old 178.7s outlier, ideally in the same ~1s range as the
  other 18 reps.
- Sibling-class regression: `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik`
  untouched by this change (different `.cpp` file) — no new test needed,
  just confirm nothing in the shared R dispatch layer moved.

## TODOs

- [ ] TODO-1: Bound `log_theta` in `fast_clayton_weibull_aft_optim_cpp`
  (`src/fast_survival_models_optim.cpp`).
- [ ] TODO-2: Fix the clipped-vs-unclipped `theta` mismatch between the
  objective (`:69`) and gradient (`:111,121,135,148`).
- [ ] TODO-3: Re-verify the original outlier scenario is resolved; consider
  narrowing `.fit_clayton_weibull_aft`'s fallback cascade if a residual
  slow tail remains.
- [ ] TODO-4: Confirm no golden-test point-estimate drift from the new
  bound; update fixtures only if a deliberate, justified change is found.
