# Random-Effect Variance Collapse: GLMM/CLMM Fits Slide to the `log sigma` Boundary, Report `converged = TRUE`, and Return a Biased Estimate

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-31`. Added 2026-09-24 from
> an audit of the test-file comments (four existing tests pin these as
> `SUSPECTED SOURCE BUG (pinned, not fixed)`). The tests pass today, so the
> behavior is reproduced by the pinned fixtures; the extent across real data
> and the right fix are **not** established. Related, not duplicate:
> `multimodal_log_liks.md` and `../new_feature_plans/multistart_nonconcave_likelihoods.md`
> (v1.2.0 TODO-20) plan a general multistart for nonconcave kernels; this
> plan is the targeted, observed-wrong-answer subset and may be resolved by
> a narrow change well before that infrastructure lands.

## The finding

Four random-intercept kernels, from the same family of failure, in which
the optimizer slides `log sigma` to the lower boundary (about `-3`), stops
with `converged = TRUE`, and lands at a strictly worse likelihood and a
biased treatment coefficient:

| kernel / class | pinned by (test file) | observed |
|---|---|---|
| `fast_ordinal_clmm_cpp` started at `log sigma = -3` (the KK CLMM classes' `clmm_warm_start()`, `c(alpha_par, beta_nore, -3.0)` in `inference_ordinal_KK_clmm_abstract.R`) and its own cold start | `...ordinal-clmm-kernel-ordinal-package-agreement-and-sigma-collapse-from-minus-three-start...` | 6 of 12 simulated datasets (true sigma 0.9); worse nll and biased `b` |
| `InferenceOrdinalKKCLMM` (class level, same kernel) | `...ordinal-kk-glmm-class-matches-clmm-and-kk-clmm-class-collapses-to-fixed-effects...` | seed-302 fixture: estimate 0.4101 = fixed-effects `polr` 0.4100, vs `ordinal::clmm` / `InferenceOrdinalKKGLMM` 0.4228; the random effect is lost |
| `fast_logistic_glmm_cpp` default cold-start L-BFGS | `...logistic-glmm-fit-glmer-agreement-and-cold-start-variance-collapse...` | 12 of 30 datasets; up to ~2.4 nats worse; non-positive/non-finite variance in the pinned case |
| `InferenceCountKKGLMM` (`fast_poisson_glmm_cpp`, `optimization_alg = "newton_raphson"`) | `...count-kk-classes-match-joint-optimum-geeglm-and-glmer-and-newton-sigma-collapse...` | seed-6 fixture: log sigma about -3.5, `converged = TRUE`, gradient norm about 0.3, estimate 0.5475 vs L-BFGS / `glmer` 0.5359; on most datasets the optimizers agree |

A separate, related kernel-consistency defect, pinned in
`...logistic-glmm-neg-loglik-score-hessian-kernels...`:
`get_logistic_glmm_hessian_cpp`'s log-sigma row/column disagrees with the
Jacobian of the package's own (correct) score, and its diagonal has the wrong
sign (`h[3,3] > 0`, `|h - jac| > 1`). Anything that uses that Hessian for
standard errors at the sigma coordinate is suspect.

## Why it matters

Silently wrong estimates with a "converged" flag, in the KK classes that are
the package's default for matched designs. It also interacts with the
diagnostics work: `converged` here is gradient-norm based with a boundary
fallback that is not being treated as a failure (see
`../new_feature_plans/optimizer_diagnostics_report.md`, "valid lower-variance
boundary" handling). Careful: some sigma-at-boundary fits are legitimate
(true sigma near 0); the failure is a *non-stationary* boundary stop at a
worse likelihood.

## Items

- [ ] **TODO-1: Characterize.** For each of the four kernels, measure the
  rate of boundary stops with a strictly worse likelihood (vs. a high-quality
  reference: `ordinal::clmm(nAGQ=25)`, `glmer`) across a small grid of true
  sigma and `n`. Separate legitimate boundary solutions from non-stationary
  stops using the gradient norm at the stop.
- [ ] **TODO-2: Decide the fix per kernel.** Candidates: a non-boundary
  default start (`log sigma = 0`, which the ordinal test shows recovers the
  ML solution); a short multistart over `{-1, 0, 1}` for the sigma
  coordinate (the multistart plan proposes a `scalar_nuisance_starts()` helper;
  it does not exist yet); refusing to report `converged = TRUE` on a
  non-stationary boundary stop. Align with the multistart plan so this is
  its first, narrow use rather than a competing mechanism.
- [ ] **TODO-3: Hessian log-sigma block.** Determine whether
  `get_logistic_glmm_hessian_cpp`'s sigma row/column is wrong or the test's
  expectation is; if wrong, fix, and audit every caller that reads standard
  errors from it.
- [ ] **TODO-4: Fix and flip the tests.** The four pinned tests are written
  to assert the *buggy* behavior; convert each to a regression test that
  asserts agreement with `clmm`/`glmer`, and remove the "pinned" wording.
- [ ] **TODO-5: Reach.** Sweep the other random-intercept kernels
  (`fast_ordinal_glmm_cpp`, Poisson/negative-binomial GLMM, Gaussian LMM)
  for the same warm-start value, and record the answer here.
- [ ] **TODO-6: Comprehensive-test regeneration** for the affected KK
  classes after the fix, per the standing pruning workflow.

## Cross-links (kept in sync 2026-09-24)

Each of these carries a matching "Fed by"/"Related" note pointing back here:
`../new_feature_plans/multistart_nonconcave_likelihoods.md` (v1.2.0),
`../new_feature_plans/optimizer_diagnostics_report.md` and
`../new_feature_plans/public_diagnostics_api_spec.md` (v1.1.0, boundary vs.
failure classification), `../new_feature_plans/cold_starts.md`, and
`multimodal_log_liks.md` (same v1.0.5 wave, stereotype logit).

## Explicitly out of scope

- The general multistart infrastructure (`multistart_nonconcave_likelihoods.md`).
- The SolverDiagnostics taxonomy (v1.1.0).
