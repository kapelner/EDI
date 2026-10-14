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

## Resolution audit (2026-10-09)

The three distinct affected native fitters now use the same deterministic
log-sigma multistart pattern already used by `fast_ordinal_glmm_cpp`: retain
the supplied/cold start, add `{-1, 0, 1}` and the lower variance boundary,
respect a fixed log-sigma coordinate, and select the finite fit with the
smallest objective. `InferenceOrdinalKKCLMM` also now supplies a neutral
`log_sigma = 0` warm start. This fixes both the CLMM kernel/class fixtures and
the logistic/Poisson GLMM cold-start fixtures without changing the public
optimizer-policy contract (in particular, `InferenceCountKKGLMM` still uses
`newton_raphson`; the kernel makes that choice robust to its starting basin).

The logistic Hessian discrepancy was a chain-rule error. In
`LogisticGLMMObjective::hessian`, `node_factor` is already
`sqrt(2) * sigma * z`; its beta/log-sigma and log-sigma/log-sigma terms
multiplied by `sigma` one extra time. Those factors are removed, and the
regression now requires the full matrix to agree with both the score Jacobian
and the independently differentiated marginal likelihood.

The pre-fix characterization is preserved by the former pinned fixtures:
CLMM collapsed in 6/12 simulations at `n = 200`, true sigma 0.9; logistic
GLMM collapsed in 12/30 simulations at the same size/sigma; and Poisson
Newton had the deterministic seed-6 failure while agreeing on the four
seed-701--704 controls. A broader sigma-by-n grid and post-fix rates require
executing the rebuilt native library and remain part of TODO-1 below.

Reach sweep: `fast_ordinal_glmm_cpp` already has deterministic multistart;
Gaussian LMM starts its random-effect SD at half the residual SD rather than
at `-3`; the combined conditional-logistic/GLMM kernel initializes log sigma
at zero. There is no negative-binomial random-intercept kernel in this
checkout. `fast_hurdle_poisson_glmm_cpp` still has a single `-3` cold start,
but no pinned collapse or evidence of a wrong basin; it is recorded here for
the general v1.2 multistart plan rather than expanding this observed-defect
fix without a reproducer.

Static validation completed without compiling: all five edited R regression
files and the edited R class file parse, and `git diff --check` passes. Native
behavior cannot be validated until the package is rebuilt. After that, run
the five focused bulk regressions, the sigma-by-n characterization grid, and
the affected KK comprehensive rows; regenerate installed comprehensive CSVs
only after those checks pass.

**Installed-package validation 2026-10-14:** the user-reinstalled package
(reports EDI 1.0.3) passed the five focused native regression files: ordinal
CLMM kernel (23 assertions), ordinal KK class (8), logistic GLMM (13), KK
count GLMM (11), and logistic score/Hessian (7), for 62 passing assertions
with no failures or warnings. Codex did not compile, build, or install. The
bounded sigma-by-n characterization grid (TODO-1) has since been run against
the installed package; its partial evidence and residual Poisson local-optimum
cases are recorded below. Affected KK comprehensive-row regeneration
(TODO-6) remains outstanding.

## Items

- [ ] **TODO-1: Characterize.** For each of the four kernels, measure the
  rate of boundary stops with a strictly worse likelihood (vs. a high-quality
  reference: `ordinal::clmm(nAGQ=25)`, `glmer`) across a small grid of true
  sigma and `n`. Separate legitimate boundary solutions from non-stationary
  stops using the gradient norm at the stop.
  **Bounded installed-package grid 2026-10-14 (partial evidence; EDI 1.0.3):**
  because this plan specifies only a “small grid,” the convention used here
  was `n={120,200}`, true `sigma={0.6,0.9}`, and seeds `41001:41010` in each
  cell (40 fits per kernel, 160 total). The kernels were `fast_ordinal_clmm_cpp`
  and `fast_ordinal_glmm_cpp` (both compared with `ordinal::clmm(nAGQ=25)`),
  `fast_logistic_glmm_cpp`, and `fast_poisson_glmm_cpp` (the latter two compared
  with `glmer`; native objective evaluations used 40-node quadrature). A
  material worse-fit threshold of `1e-3` NLL units was used to avoid treating
  floating-point noise as a failure. Ordinal CLMM had 5/40 boundary fits and
  ordinal GLMM 5/40; none was worse than its reference by more than the
  threshold. Logistic GLMM had 3/40 boundary fits, each paired with a
  singular/zero-sigma `glmer` reference (so its zero-sigma likelihood gap is
  not finite); the fit gradient norms were 0.00062–0.00121. Poisson GLMM had
  no boundary fits, but two converged, non-boundary cold-start fits at
  `n=200, sigma=0.9` were materially worse than a glmer-informed native start:
  seed 41003, gap 0.12833 NLL (fit sigma 0.92225 vs reference sigma 0.84160),
  and seed 41008, gap 1.01325 (fit sigma 1.04495 vs 0.80532). Both cold fits
  reported `converged=TRUE`, no iteration-cap hit, and gradient norms below
  `8e-7`; the lower-NLL reference-informed fits also reported convergence but
  larger gradient norms (0.0475 and 0.0313), so the gradient diagnostic needs
  cautious interpretation. Repeating both cases with LBFGS cold starts
  reproduced the worse local optima. Source inspection shows the Poisson
  kernel's deterministic multistart varies `log_sigma` while retaining its
  single smart-cold beta initialization; this points to a remaining
  coefficient-start/local-optimum robustness gap, not a nonstationary
  boundary stop. The bounded grid therefore does not close TODO-1: the two
  Poisson cases need a validated start/reference policy, and the plan's
  boundary/gradient classification must be reconciled with this non-boundary
  finding. Temporary results are under `/tmp/edi_todo31_sigma_n_grid.csv`,
  `/tmp/edi_todo31_ordinal_glmm_grid.csv`, and
  `/tmp/edi_todo31_poisson_outlier_diagnostics.csv`; no repository baseline was
  changed and no build/install was run.
- [x] **TODO-2: Decide the fix per kernel.** Candidates: a non-boundary
  default start (`log sigma = 0`, which the ordinal test shows recovers the
  ML solution); a short multistart over `{-1, 0, 1}` for the sigma
  coordinate (the multistart plan proposes a `scalar_nuisance_starts()` helper;
  it does not exist yet); refusing to report `converged = TRUE` on a
  non-stationary boundary stop. Align with the multistart plan so this is
  its first, narrow use rather than a competing mechanism.
- [x] **TODO-3: Hessian log-sigma block.** Determine whether
  `get_logistic_glmm_hessian_cpp`'s sigma row/column is wrong or the test's
  expectation is; if wrong, fix, and audit every caller that reads standard
  errors from it.
- [x] **TODO-4: Fix and flip the tests.** The four pinned tests are written
  to assert the *buggy* behavior; convert each to a regression test that
  asserts agreement with `clmm`/`glmer`, and remove the "pinned" wording.
- [x] **TODO-5: Reach.** Sweep the other random-intercept kernels
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
