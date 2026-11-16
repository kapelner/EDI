# Two New Optimizer Engines: Trust-Region Newton and Bounded L-BFGS

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> Release: v1.2.0 (`release_v1_2_0.md → TODO-203`; added 2026-11-16, owner
> request). **Provides engines for:** `nonconcave_optimizer_techniques.md`
> (TODO-202). Its T7 (trust-region Newton) and T4 (bounded variance and
> dispersion parameters) are built here as general engines, and TODO-202 only
> decides where to use them. **Composes with:**
> `../v1_1_0/multistart_nonconcave_likelihoods.md` (each start can run on
> any engine) and `algorithm_ab_testing_framework.md` (TODO-21), which must
> show a win before any class's default changes. **Native tests:**
> `native_cpp_tests_v1_2_0.md` (TODO-37). Each new header lands with its
> `cpp_tests/` target.

Date: 2026-11-16

**Goal:** Add two values to `optimization_alg`, next to `"irls"`,
`"newton_raphson"` and `"lbfgs"`:

- `"trust_region"`: Newton with a trust region. It handles an indefinite
  Hessian directly instead of failing or line-searching along an ascent
  direction.
- `"lbfgsb"`: L-BFGS with per-parameter box constraints. A parameter that
  belongs at a boundary stops there and is reported as at the bound,
  instead of running toward −∞ on the log scale and reporting a false
  `converged = TRUE`.

Both are opt-in. No class changes its default in this plan.

## Why

Our three engines share two blind spots, and both have caused documented
failures:

| Failure | Engines affected | Seen in |
|---|---|---|
| The Hessian is indefinite at the start or along the path, so the Newton step points uphill and L-BFGS curvature pairs cannot represent it | NR, NR-then-L-BFGS, L-BFGS | stereotype logit near β_T = 0; GLMM/CLMM σ from log σ = −3; the dependent-censoring model bimodal in ρ |
| The MLE sits on a parameter boundary that the log scale puts at −∞, so the fit stops on a step or function tolerance far out and reports convergence | L-BFGS, NR | GLMM/CLMM σ collapse; the audit fits from 2026-11-16 (ZINB inflation intercept ≈ −6, Clayton log θ ≈ −18.7, frailty log σ_u ≈ −5.8) |

The registry now records which classes are exposed: `likelihood_concave`
(FALSE means indefinite Hessians are possible), `boundary_parameters`
(which coordinate has a boundary), and `parameter_layout` (where that
coordinate sits in the vector, on which scale). `derivatives` records
whether an analytic Hessian exists, which trust-region Newton needs to be
cheap.

## Existing code this builds on

- `R/EDI/src/_helper_functions_core.h`:
  - `normalize_optimizer_algorithm()` (about line 1228) accepts `lbfgs`,
    `newton_raphson` and `irls`.
  - `optimize_likelihood_newton()` (about line 1436) and
    `optimize_likelihood_lbfgs()`.
  - `optimize_fixed_likelihood()` (about line 1606) dispatches on the
    engine. `FixedParameterFunctor` subsets to the free parameters and
    exposes `hessian()`.
  - `LikelihoodFitResult` already has `min_eigenvalue_information`,
    `dispersion_at_poisson_boundary` and `zero_inflation_at_boundary`.
- R side: `.normalize_optimizer_algorithm()` in
  `R/EDI/R/helper_glm_fit.R` validates the value; 35 R files thread
  `optimization_alg` through.
- `LBFGSpp::LBFGSBSolver` (`<optimization/LBFGSB.h>`) ships in
  RcppNumerical 0.7.0, which the package already links to (`LinkingTo:
  RcppNumerical`). The Python build pins LBFGSpp v0.4.0
  (`python/CMakeLists.txt`), which also has `LBFGSB.h`. **No new
  dependency.**

## Design

### D1. `src/optimization_trust_region.h` — trust-region Newton

A new leaf header. Its interface matches `optimize_likelihood_newton()`, so
it slots into the same dispatch: the functor's value, gradient and
`hessian()`, plus `maxit`, `tol` and an optional warm-start Hessian.

- **Subproblem:** Moré–Sorensen exact solve on the eigendecomposition of
  the Hessian (`Eigen::SelfAdjointEigenSolver`), which is cheap at our
  sizes (p plus at most a few nuisance coordinates, typically under 30).
  This handles the "hard case" (gradient orthogonal to the
  negative-curvature eigenvector) explicitly. Above a size threshold
  (default p > 200, never hit today), fall back to Steihaug truncated CG.
- **Radius update:** standard ρ = actual/predicted reduction rule (shrink
  by 1/4 below 0.25, expand ×2 at the boundary above 0.75), initial radius
  = ‖Newton step‖ when the Hessian is PD, else 1.
- **Convergence:** gradient norm < `tol` *and* the information matrix is
  positive definite (smallest eigenvalue > `1e-10 × largest`). A
  stationary point with negative curvature is not reported as converged.
  Instead the step leaves it along the negative-curvature direction. This
  means a saddle point cannot end the fit, which is what technique T3 of
  TODO-202 checks for after the fact with the other engines.
- **Reporting:** fills `min_eigenvalue_information`, `niter`,
  `hit_iteration_cap`. Adds `n_negative_curvature_steps` to
  `LikelihoodFitResult` (provenance for calibration).
- **Numerical Hessians:** classes whose `derivatives$information` is
  `"numerical"` can use the engine, but each iteration costs O(p) gradient
  evaluations. The engine accepts these classes; whether that cost is
  worth it is for the A/B harness to decide.

### D2. `src/optimization_bounded.h` — bounded L-BFGS

A new leaf header wrapping `LBFGSpp::LBFGSBSolver`.

- **Bounds:** two vectors `lb`, `ub` (±∞ for free coordinates) on the
  kernel's existing parameter scale. The first version does not
  reparametrize. A log-scale variance gets a finite floor (default
  log σ ≥ log(1e-6), configurable). This keeps every kernel's likelihood
  code unchanged. Natural-scale reparametrization (σ ≥ 0 directly) is a
  per-family follow-on in TODO-202 T4, and needs the parameter_layout
  `scale` field updated in the same change.
- **Bounds from the registry:** a helper
  `edi_default_parameter_bounds(layout, p, K)` in R builds `lb`/`ub` from
  `parameter_layout`. It reads blocks whose name starts with `log_sigma`,
  `log_theta` or `log_phi` and whose class declares the matching
  `boundary_parameters` entry. Kernels receive `lb`/`ub` as two new
  optional arguments, empty by default, so existing calls are unchanged.
- **Fixed parameters:** `FixedParameterFunctor` subsets `lb`/`ub` to
  `free_idx` the same way it subsets the start.
- **Convergence:** the projected gradient norm is below `tol`, which is
  the KKT condition at a bound. A coordinate at its bound is a legitimate
  optimum. Report it in a new `at_bound` logical vector (full length) and
  set the family flag (`dispersion_at_poisson_boundary`,
  `zero_inflation_at_boundary`) or a new `variance_component_at_boundary`.
- **Inference at the bound:** at a bound, the Wald SE for that coordinate
  is not defined, and the LR test of the boundary value has a χ̄² null.
  This plan only reports `at_bound`, and the Wald machinery excludes
  at-bound coordinates from the information inverse (the same rule
  the existing Poisson-boundary flag uses). The χ̄² LR mixture is out of
  scope; the class docs say so.

### D3. Dispatch and the R/Python API

- `normalize_optimizer_algorithm()` (C++) and
  `.normalize_optimizer_algorithm()` (R) accept `"trust_region"` (aliases
  `"tr"`, `"trust-region"`) and `"lbfgsb"` (aliases `"l-bfgs-b"`,
  `"L-BFGS-B"`).
- `optimize_likelihood()` / `optimize_fixed_likelihood()` dispatch to them.
  Every kernel that already calls these gets both engines without kernel
  edits except the `lb`/`ub` pass-through for `"lbfgsb"`.
- **Which classes accept which engine:** a new registry field
  `optimization_algs` (a character vector), filled at populate time from
  which kernel entry point each class calls. IRLS-only kernels list only
  their current values. Requesting an unsupported engine is an error at
  construction, not a silent fallback. A registry test checks that every
  class declaring `"lbfgsb"` has a `parameter_layout`, since bounds are
  derived from it.
- Python `edi_kernels`: the same string values and `lb`/`ub` arguments
  (parity tests in the existing binding suite).

### D4. Equivalence and defaults

- On a concave class with an interior optimum, `"trust_region"` and
  `"newton_raphson"` must agree to the D2 numerical-equivalence tolerance
  (owner rule, 2026-10-15). `"lbfgsb"` with all bounds infinite must agree
  with `"lbfgs"` to the same tolerance.
- No default changes here. Switching a class's default is a separate
  decision per class. It needs an A/B harness report (TODO-21) and a
  calibration comparison. Any accepted calibration row cites an open TODO.

## Implementation TODOs

- [ ] TODO-1: `optimization_trust_region.h` + `cpp_tests/` target.
  Unit tests:
  - Rosenbrock.
  - A quadratic with one negative eigenvalue started exactly at the
    saddle, which must leave it.
  - The hard case (gradient orthogonal to the negative eigenvector).
  - A PD quadratic, which must take exactly one step from any start.
- [ ] TODO-2: `optimization_bounded.h` + `cpp_tests/` target.
  Unit tests:
  - A box-constrained quadratic whose optimum is on a bound: `at_bound`
    is set, and the projected gradient is 0.
  - All bounds infinite equals `optimize_likelihood_lbfgs()` to 1e-10.
  - The `free_idx` subsetting.
- [ ] TODO-3: dispatch in `_helper_functions_core.h` (both normalizers,
  `optimize_likelihood`, `optimize_fixed_likelihood`), the
  `LikelihoodFitResult` fields (`n_negative_curvature_steps`, `at_bound`,
  `variance_component_at_boundary`), and the `lb`/`ub` kernel arguments.
  Targeted compiles only: list the touched `.cpp` files first, and stop
  and ask if the needed `.o` files are missing.
- [ ] TODO-4: R side. Add `.normalize_optimizer_algorithm()` values,
  `edi_default_parameter_bounds()`, the `optimization_algs` registry field
  plus its test, and Wald exclusion of at-bound coordinates. A live-fit
  test fits every class declaring each engine and checks the
  equivalence rule (D4) on the concave ones.
- [ ] TODO-5: failure-case tests, each written to fail on the current
  engines first:
  - stereotype logit started at β_T = 0: NR stalls or reports a saddle,
    while trust region reaches the better optimum;
  - Gaussian GLMM data simulated with σ = 0: `"lbfgs"` reports
    log σ ≈ −large with `converged = TRUE`, while `"lbfgsb"` reports
    σ at the floor, `at_bound` set, and the fixed effects equal to the
    plain GLM fit;
  - ZINB data with no inflation: `"lbfgsb"` sets `at_bound` on the
    inflation intercept.
- [ ] TODO-6: Python `edi_kernels` parity (values, `lb`/`ub`, result
  fields).
- [ ] TODO-7: documentation. Update the `optimization_alg` roxygen
  everywhere it is documented, explaining when to use each engine. Add a
  NEWS entry and an "Optimizer engines" section in the inference
  vignette. Add a cost row to the benchmark utility section.
- [ ] TODO-8: A/B report through TODO-21's harness. Compare trust region
  against NR-then-L-BFGS on the nonconcave classes, and `lbfgsb` against
  `lbfgs` on the boundary classes. The report recommends defaults per
  class; the owner decides.

## Standing constraints

- Targeted compiles only, never a full rebuild; agents use `EDI_UNITY=0`
  (repo `CLAUDE.md`).
- `cpp_tests/` builds stay per target, under `$TMPDIR`, at `-j2` or less.
- Concave classes on their current default engine stay numerically
  equivalent (D2 rule). Nothing in this plan changes a default.
