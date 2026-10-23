# KK CLMM: the cloglog "sigma collapse" is the correct MLE (the `ordinal::clmm` reference fits a different model), but every native CLMM fit reports `converged = TRUE` while visibly non-stationary

> **Status:** written 2026-10-22 as a plan. **TODO-1..4 and TODO-6 (items 1-3, 5; item 4 drafted) implemented
> 2026-10-22** (R only, owner decisions G6 #45 (i), (ii)(a), (iii)(a)); see "Implementation record" at the end.
> TODO-5 (C++) is not in 1.0.5 scope: v1.1.0, or G1 if that build happens anyway.
> Slated for `../future_release_plans/release_v1_0_5.md → TODO-31` (the "Golden re-pinned 2026-10-22" cloglog
> residual). Owner decisions are G6 #45. Related: `glmm_variance_component_sigma_collapse.md` (the 2026-10-09
> multistart fix), `optimize_likelihood_newton_false_nonconvergence.md` (Survey 2 headline 2, "CLMM tolerance"),
> `cpp_patches_v105/` patches 01, 12, 14, and `../future_release_plans/release_v1_0_5.md → TODO-76` (Bayesian bootstrap
> weighted CLMM refit).

## Summary

1. **The cloglog golden fit is not a failure.** On the golden design, EDI's cloglog CLMM likelihood falls
   monotonically as sigma goes to 0. The boundary is the MLE: the one-sided score in `tau = sigma^2` at 0 is +0.913.
   The fit equals `ordinal::clm(link = "cloglog")` (neg loglik 80.89729, treatment 0.08686).
2. **`ordinal::clmm(link = "cloglog")` fits the log-log model, and `link = "loglog"` fits cloglog.** This is in the
   installed ordinal 2026.7.26. clmm's "better" logLik -79.85048 is exactly the log-log integrated likelihood at its
   parameters. It is not a better cloglog fit; under the true cloglog model those parameters score 91.64. So the
   TODO-31 note's "0.0869 vs 0.2076" compares two different models. The swap also leaks into EDI. The cloglog
   Bayesian-bootstrap weighted refit and the `use_rcpp = FALSE` path both call `ordinal::clmm(link = "cloglog")`, so
   they fit log-log while the native point estimate is cloglog: 0.2076 and 0.1940 vs native 0.0869 on the golden design.
3. **The false-convergence report is real, and it is generic to every native CLMM fit.** The reported gradient norm
   of 1.55e-3 does not come from the log-sigma bound. It sits in the free fixed-effect coordinates. The stop came from
   LBFGSpp's relative function-decrease test (`past = 1`, `delta = eps_g`), which EDI maps to `converged = TRUE`
   through the `niter < maxit` clause. In the sweep below, all 360/360 class fits report `converged = TRUE` with
   gradient norm > `eps_g = 1e-6` (median 1.1e-2, max 0.20). Their treatment estimates sit a median 2e-4 (max 6.4e-3)
   from the stationary point.
4. **The multistart already exists in C++** (2026-10-09) and works. The sweep found 0 spurious collapses in 360 fits.
   Every boundary fit has a positive tau-score (42/42 certified), and every boundary fit's correctly specified
   reference also has sigma < 0.04.
5. **An R-only change fixes the estimates in 1.0.5.** Set `clmm_eps_g = 1e-12`: estimates land within 2.4e-6 of a
   Newton-polished optimum, at ~3x kernel time. Add an R-side stationarity acceptance with one Newton retry, and fix
   the R-side `ordinal::clmm` link name. An honest kernel-level `converged` flag (projected gradient/KKT) needs C++
   (G1). The sibling `fast_ordinal_glmm.cpp` already has that code, ready to port.

## Background and evidence

Provenance for every number below: HEAD `06f82d660bac5edf5c0f22a0b48dc990a49a21d0`, dirty tree (see git status in
the release file). R-devel r90668. Installed EDI 1.0.3 (`Built: R 4.7.0; 2026-10-22 19:33:28 UTC`), loaded via
`library(EDI)` + `pkgload::load_all("R/EDI", compile = FALSE)`. Loaded/installed `EDI.so` SHA-256
`3fc56f5a049a44b6112d16cefd8fd87e90c2ab49cca851d50c7f57075d17a768`, byte-identical to checkout `R/EDI/src/EDI.so`. As
for every DLL-equality claim in TODO-31, this does not attest the source/build chain. ordinal 2026.7.26. No build,
install or compile was run. Scripts and outputs: `/tmp/claude-1000/todo31_plan/` (`setup.R`, `diag1.R`..`diag6.R`,
`sweep.R` + `sweep.out` + `sweep.rds`, `sweep2.R`/`.rds`, `sweep3.R`/`.rds`). The golden design comes from
`test-ordinal-kk-clmm-migration-golden.R` (`ordinal_kk_clmm_golden_design()`): n = 60, K = 4, 42 groups, 18 pairs,
`~ x1 + x2`.

### E1. The golden cloglog fit (production path, `InferenceOrdinalKKCLMMCloglog$compute_estimate()`)

`cached_mod`: `log_sigma = -5`, `converged = TRUE`, `num_iter = 3`, `hit_iteration_cap = FALSE`,
`gradient_norm = 1.55e-3`, `neg_loglik = 80.9`. Estimate 0.08688.

| link | `ordinal::clmm(nAGQ=20)` w / sigma / -logLik | `clm` w / -logLik | EDI kernel w / log sigma / nll |
|---|---|---|---|
| logit | 0.3043 / 1.112 / 80.3934 | 0.2445 / 80.7658 | 0.3065 / 0.107 / 80.3934 |
| probit | 0.1573 / 0.730 / 80.3935 | 0.1073 / 80.9646 | 0.1573 / -0.315 / 80.3935 |
| cauchit | 0.5596 / 0.000 / 79.0266 | 0.5596 / 79.0266 | 0.5587 / -4.805 / 79.0262 |
| cloglog | 0.2076 / 0.906 / 79.8505 | 0.0869 / 80.8973 | 0.0868 / -4.880 / 80.8973 |
| (clmm `link = "loglog"`) | 0.08686 / 8.7e-5 / **80.89729** | | |

Cloglog profile of EDI's objective, with log sigma fixed and the other parameters refit (`diag1.R`): nll is 80.89733
at -5, 80.89955 at -3, 80.98643 at -1, 81.26321 at 0 and 84.34358 at 1. It is monotone, so sigma -> 0 is the optimum.
Started free at clmm's own parameters, the kernel goes back to the boundary (nll 80.8973). With log sigma pinned at
clmm's value (-0.099), the best EDI-objective value is 81.1989, which is worse than the boundary.

### E2. `ordinal::clmm` cloglog/loglog are swapped (`diag2.R`, `diag3.R`, `diag4.R`)

- Independent oracle: `integrate()` per group of `prod_r [F(theta_y - eta - b) - F(theta_{y-1} - eta - b)] phi(b/sigma)/sigma`,
  rel.tol 1e-10. At clmm-cloglog's parameters the true-cloglog oracle gives 91.64345, and a log-log `F` gives
  **79.85048, which equals clmm's -logLik exactly**. For logit, oracle = clmm = EDI = 80.39339.
- At sigma -> 0, `clmm(link = "loglog")` -logLik is 80.89729 = `clm(link = "cloglog")` = EDI.
- Simulated true-cloglog CLMM: 400 pairs, sigma 1.2, beta 0.6, seed 1. `clmm(link = "loglog", nAGQ = 10)` gives
  w 0.594, sigma 1.222, logLik -1029.482. EDI cloglog gives w 0.594, sigma 1.222, nll 1029.485.
  `clmm(link = "cloglog", nAGQ = 10)` gives w 0.653, sigma 1.313, logLik -1031.907. Laplace (`nAGQ = 1`) looks
  swapped as well.
- `clm` is correct. `ordinal:::setLinks` (the R-level `pfun` used by clmm) maps the names in the documented way, so the
  swap sits in the compiled clmm likelihood path. One more symptom: `ordinal:::getFittedC(c(0.5,1,-0.3), c(-Inf,0,-2),
  "cloglog")[1]` returns -0.192 (= F(0.5) - 1), not 0.808. The C source was not inspected; file an upstream report (G6 #45 (i)).
- Sweep (below): over 90 cloglog fits, median |EDI - clmm(loglog)| = 2.3e-4 and median |EDI - clmm(cloglog)| = 0.058.
  In 17% of fits clmm(cloglog)'s "better" logLik beats EDI by > 1e-3, which is the golden pattern.

### E3. EDI's own `ordinal::clmm` calls inherit the swap (`diag6.R`)

Golden design, cloglog. Native estimate 0.08688. `compute_weighted_clmm_estimate(rep(1, n))`, the
`weighted_ordinal_random_intercept_fit` helper that nonconstant-weight Bayesian-bootstrap draws use (TODO-76), gives
**0.20758**. The `use_rcpp = FALSE` path (`fit_clmm`, Laplace) gives **0.19395**. Logit, probit and cauchit agree
between the helper and native to <= 2e-4. Every cloglog BB draw is therefore a draw of a different model, centred
away from the reported point estimate.

### E4. Why "converged" at gradient 1.55e-3 (`diag5.R`)

- `optimize_likelihood_lbfgs` (`R/EDI/src/_helper_functions_core.h` L1337-1387) sets `epsilon = epsilon_rel = delta =
  tol`, `past = 1`, and then `converged = (gnorm < tol) || (niter < maxit)` (L1373-1374). LBFGSpp
  (`RcppNumerical/include/optimization/LBFGS.h`, `minimize`) stops when `|f_{k-1} - f_k| <= delta * max(|f_k|, 1)`.
  That threshold is 8.1e-5 at f = 80.9, and the test fired at iteration 3. So `niter < maxit`, and the fit reports
  `converged = TRUE`. The reported `gradient_norm` is LBFGSpp's `m_gnorm` at that point.
- An R replica of the 20-node GH objective reproduces the kernel's nll to 1e-8. Its numeric gradient at a cold
  kernel fit (gn 5.87e-3) is a1 1.25e-3, a2 1.44e-3, a3 -1.40e-3, **w -1.0e-3, x1 -7.7e-4, x2 -5.2e-3, log sigma 1.1e-4**.
  The residual is in the free fixed effects, not at the bound.
- BFGS polish of the replica: nll 80.89733, w 0.0868724, log sigma -5.000004, gnorm 1.1e-6. The kernel with
  `optimization_alg = "newton_raphson"` from the returned point converges in 1 iteration to gn 5.3e-10. Logit golden:
  returned w 0.30647 vs polished 0.30428 (2.2e-3 off, nll gap 1.9e-5). On the logit link, stopping short costs more
  than on cloglog.
- **Boundary/KKT certificate.** The one-sided slope `[nll(tau) - nll(0+)]/tau` at the polished fixed effects is
  0.9129 / 0.9126 / 0.9097 at tau = 1e-4 / 1e-3 / 1e-2. A positive slope means the boundary is a KKT point. With the
  soft penalty (`_glmm_engine.h` L109-128: `kSigmaPenaltyCenter = 5`, scale 10), the penalized objective has a true
  stationary point at `log sigma ≈ -5 - e^{-10} * s / 10` (s = tau-score). That is why fits sit at -5.000004 with a
  near-zero log-sigma gradient. A negative s would leave no stationary point near -5.
- Tighter L-BFGS tolerances (kernel default start): `eps_g = 1e-8` gives gn 6.35e-3 (33 iterations) and `1e-10` gives
  gn 1.15e-4.

### E5. Scope sweep (`sweep.R`, `sweep.out`)

Data: `DesignSeqOneByOneKK14`, ordinal K = 4 generated from each link's own cumulative model, eta = 0.5 w + 0.4 x + u.
Pair random intercept `u ~ N(0, sigma_b^2)`. 4 links × n ∈ {60, 200} × sigma_b ∈ {0, 0.6, 1.2} × 15 seeds = 360
class fits. Reference: `ordinal::clmm(nAGQ = 20)` with the correctly specified link name (cloglog -> "loglog").

- Boundary fits (log sigma <= -4): 71/360 (53 at sigma_b = 0, 17 at 0.6, 1 at 1.2). **Spurious collapses**
  (EDI at the boundary while the reference has sigma > 0.1 and a better likelihood by > 1e-3): **0/360**. The maximum
  reference sigma among EDI boundary fits is 0.039.
- `converged = TRUE` with gradient norm > 1e-6: **360/360**, for all four links. Gradient-norm quantiles (10/50/90/100%):
  logit 1.6e-3 / 9.6e-3 / 2.9e-2 / 7.1e-2; probit 3.6e-3 / 1.3e-2 / 5.4e-2 / 0.17; cauchit 1.8e-3 / 1.2e-2 / 4.0e-2 / 6.6e-2;
  cloglog 2.1e-3 / 1.1e-2 / 5.7e-2 / 0.20.
- Max |EDI - reference| treatment error: logit 2.5e-3, probit 2.4e-3, cloglog 1.7e-2. Cauchit reaches 0.95 because
  clmm itself fails or wanders on cauchit: 10/120 errors, and EDI is better by up to 0.99 nll.
- Interior fits at sigma_b = 1.2 can sit up to 0.06 (cloglog) / 0.14 (cauchit) nll above clmm while the parameters
  agree to ~3e-3. This is attributed to EDI's fixed 20-node non-adaptive GH vs clmm's adaptive quadrature, which is
  TODO-153 territory. It is **not verified** by exact integration here and is out of this plan's scope.

### E6. What a stationary point costs and what it moves (`sweep2.R`, `sweep3.R`)

240 fits (10 seeds per cell) were polished with the kernel (`optimization_alg = "newton_raphson"`, warm start =
returned params):
- 235/240 converged. gn <= 1e-6 in 231/240. The other 5 stall at gn 1.1e-6..4.5e-6, a numerical-Hessian floor;
  patch 01's rule would accept them. nll improved in 235/240 and got worse in 0/240.
- |delta treatment| median 1.8e-4, 90% 1.4e-3, 99% 2.5e-3, max 6.4e-3. Per-link median/max: logit 2.6e-4/2.4e-3,
  probit 1.2e-4/1.9e-3, cauchit 4.9e-4/6.4e-3, cloglog 1.4e-4/1.8e-3.
- Polishing with log sigma held fixed (cheap: 4 ms) is not enough. It leaves the treatment up to 5.6e-3 (99% 1.1e-3)
  from the free polish, and log sigma moves up to 0.088.
- Boundary certificate on all 42 boundary fits in this subset: the fixed-log-sigma Newton profile slope in tau between
  the boundary and sigma = 0.1 is > 0 in **42/42** (min 0.297).
- Cost (median per fit). Production class fit: 8 ms (n = 60) / 24-31 ms (n = 200). Kernel Newton via the multistart:
  54 / 155 ms, because every start runs Newton. **L-BFGS at `eps_g = 1e-12`: 24.5 / 81.5 ms (~3x)**, with gn median
  7.1e-6 (max 4.8e-5) and |delta treatment| vs Newton median 1.2e-7 (max **2.4e-6**). See `sweep3.R` (120 fits, same warm
  start as the class).

## Root cause

1. **(Question 1: why log sigma = -5.)** On this dataset the true cloglog CLMM likelihood is maximized at sigma = 0.
   The ending is not a bad start, a clamp with zero gradient, line-search shrinkage or a local optimum. The `-5` is the
   equilibrium of the soft variance penalty (`sigma_penalty`, centre 5) against a positive tau-score. Every start
   (warm `log sigma = 0`, -1, 1, -8) reaches it, and a start at clmm's parameters does too. The "better" reference is
   `ordinal::clmm`'s mislabelled log-log fit (E1, E2).
2. **(Question 2: which test fired.)** LBFGSpp's relative function-decrease test (`past = 1`, `delta = eps_g`),
   reported as converged by `optimize_likelihood_lbfgs`'s `|| lbfgs_own_converged` (`niter < maxit`) clause. The
   gradient test never fires: `eps_g = 1e-6` acts as a 1e-6 *relative-f* tolerance, not a gradient tolerance. This was
   a deliberate shared-optimizer choice (`optimizer_diagnostics_report.md` TODO-4, revised 2026-08-17; Survey 2
   recommendation 2: do not change the shared flag). Its CLMM consequence is estimates that are 1e-4..6e-3 from the
   stationary point, reported as converged.
3. **(Question 3: R-side fallback.)** `shared_rcpp` (`inference_ordinal_KK_clmm_abstract.R` L251-309) and
   `compute_ri_estimate_rcpp` (L158-179) have no retry. A non-converged fit becomes NA (`kk_clmm_rcpp_failed`) and the
   `clm` fallback exists only on the `use_rcpp = FALSE` path. The only multistart is the native one
   (`fast_ordinal_clmm.cpp` L111-136: supplied start + log sigma {-1, 0, 1, -8}, keep the lowest finite value). It ran,
   and it "doesn't rescue" because there is nothing to rescue (1). It cannot fix (2) because every candidate stops by
   the same lenient rule.
4. **(Question 4: scope.)** Spurious collapse: none observed (0/360, all four links, n 60/200, sigma_b 0/0.6/1.2).
   Lenient convergence: all four `InferenceOrdinalKKCLMM*` classes, every native CLMM fit (observed fit, randomization
   refits, non-Bayesian bootstrap and jackknife through `shared_rcpp`), and direct `fast_ordinal_clmm_cpp` callers.
   Link-name swap: `InferenceOrdinalKKCLMMCloglog` only, on the BB nonconstant-weight path (`helper_ordinal_mixed_fit.R`
   L27-44) and the `use_rcpp = FALSE` path (`fit_clmm`, L365-384), plus every test that uses
   `ordinal::clmm(link = "cloglog")` as an oracle. `fit_clm_fallback` (clm) is correct. `InferenceOrdinalKKGLMM`
   (`fast_ordinal_glmm_cpp`, logit) already polishes and judges convergence by the projected gradient, so it is not
   affected.
5. **(Question 5: patches 01 and 14.)** Patch 01 changes only `optimize_likelihood_newton` exits. The CLMM default is
   L-BFGS, so the production path is unaffected. It becomes relevant only if a Newton polish is added (TODO-4/5 below):
   it then accepts the gn 1-5e-6 numerical-Hessian stalls seen in E6, which strict `gnorm < tol` reports as
   non-converged. Patch 14 is log-binomial only, and its step-halving/active-set pathology does not occur here (the CLMM
   bound is a smooth penalty). Patch 12 does not touch `fast_ordinal_clmm.cpp`, but its `ordinal_newton_decrement_ok()`
   (affine-invariant `g'H^-1g`) is a reusable certificate for TODO-5.

## Fix steps

R-only steps (TODO-1..4) can land in 1.0.5 without G1. TODO-5 is C++ (G1). TODO-6 is documentation and release bookkeeping.

- [x] **TODO-1 (done 2026-10-22; tests and reference only; no package change): use the right `ordinal::clmm` link name for EDI's cloglog.**
  Add an internal R helper `ordinal_clmm_link_name(link)` in `R/EDI/R/helper_ordinal_mixed_fit.R`. It returns `link`
  for logit/probit/cauchit. For cloglog it returns `"loglog"` when a **session-cached probe** confirms the swap, and
  `"cloglog"` otherwise. Probe: a fixed deterministic 40-group dataset with a large random effect, built in-function
  with no RNG side effects (`withr`-style seed save/restore or a hard-coded vector). Fit `ordinal::clmm(link = "loglog",
  nAGQ = 10)` and `"cloglog"`. Evaluate the true-cloglog integrated NLL at each fit's parameters with a small pure-R
  `stats::integrate()` oracle (E2's, ~40 groups). Do not use the kernel with `maxit = 0`: LBFGSpp reads
  `max_iterations = 0` as "no cap", so it is not evaluate-only. Pick the name whose `-logLik` matches the oracle within
  1e-3. Cache the result in a package-level environment. Cost ~0.2 s
  once per session, only when a cloglog CLMM reference/refit is requested. If neither matches, return NA and let
  callers refuse. Point all test oracles at this helper (TODO-3 lists the files). The probe protects against upstream
  fixing the bug, where a hard-coded mapping would silently flip to wrong.
- [x] **TODO-2 (done 2026-10-22; R, package): fix EDI's own `ordinal::clmm` cloglog calls.**
  `helper_ordinal_mixed_fit.R` L33 (`link = link` inside `fit_clmm`): use `ordinal_clmm_link_name(link)`. Leave L51
  (`ordinal::clm`, correct) unchanged. The clm coefficients stay valid starts because clmm-"loglog" uses the same
  parameter convention as EDI/clm cloglog (E2, w 0.594 = 0.594). In `inference_ordinal_KK_clmm_abstract.R` `fit_clmm`
  (L365-384, `link = private$clmm_link()` at L379), make the same substitution. `fit_clm_fallback` (L385-402) is
  unchanged. If the probe returns NA, cloglog `fit_clmm`/BB refits return NULL/NA with a classed warning
  (`edi_clmm_link_unverified`) instead of fitting a mislabelled model. Pseudo-diff:
  ```
  -				link = link,
  +				link = ordinal_clmm_link_name(link),
  ```
- [x] **TODO-3 (done 2026-10-22; R, package; 1.0.5): make the native CLMM fit actually reach a stationary point.**
  In `inference_ordinal_KK_clmm_abstract.R` L124-128 set `clmm_eps_g = 1e-12` (was 1e-6) and update the comment with
  E6's numbers. Both call sites already use the field, so the observed fit and the randomization refits stay
  consistent, as the 2026-10-22 decision required. Expected effect: treatment within ~2.4e-6 of the Newton-polished
  optimum, gn median 7e-6 (max 4.8e-5), ~3x kernel time (n = 200: ~30 -> ~82 ms per fit, so an r = 1000
  randomization test goes ~30 s -> ~82 s). Update the pins: `test-ordinal-kk-clmm-gradient-tolerance-matches-clmm.R`
  L33 (`expect_equal(clmm_eps_g, 1e-6)`), and the `eps_g` literals in **both** legacy fixtures,
  `R/package_tests/testthat_bulk/fixtures/legacy_ordinal_kk_clmm.R` L152 and L291 and
  `R/EDI/tests/testthat/fixtures/legacy_ordinal_kk_clmm.R`. The two copies already differ, so diff them first. Today's
  39-failure golden episode shows that the live-vs-legacy golden fails whenever these drift. Re-point the cloglog
  oracles at TODO-1's helper: `test-ordinal-kk-glmm-class-matches-clmm-and-kk-clmm-class-collapses-to-fixed-effects-reference.R`
  (cloglog leg of the nonlogit test; tighten its 0.15 / 0.2 tolerances once the reference is the right model),
  `/tmp/claude-1000/goldens/vs_clmm.R`-style comparisons, and any cloglog leg in
  `test-ordinal-clmm-kernel-ordinal-package-agreement-and-sigma-collapse-from-minus-three-start-reference.R`.
- [x] **TODO-4 (done 2026-10-22; R, package; 1.0.5): R-side stationarity acceptance with one Newton retry.**
  Add a private helper `clmm_accept_fit(fit, call_args)` used at L177 (`compute_ri_estimate_rcpp`) and L286
  (`shared_rcpp`). Rule: accept if `isTRUE(fit$converged) && is.finite(fit$gradient_norm) && fit$gradient_norm <=
  private$clmm_gradient_accept`, with new field `clmm_gradient_accept = 1e-4` (patch 01's absolute cap). Otherwise call
  `fast_ordinal_clmm_cpp` once more with `warm_start_params = c(fit$alpha, fit$b, fit$log_sigma)`, `optimization_alg =
  "newton_raphson"` and the same `eps_g`. Take the retry if its `neg_loglik <= fit$neg_loglik + 1e-10` and its gradient
  passes. Otherwise cache nonestimable with the new reason `kk_clmm_rcpp_not_stationary`. With TODO-3 the retry should
  almost never run: 0/120 fits in `sweep3.rds` exceed 1e-4, so the 54-155 ms Newton cost is off the common path. No
  explicit KKT branch is needed in R. Because of the soft penalty, a stationary point of the penalized objective near
  log sigma = -5 exists only when the tau-score is positive (E4), so the gradient test already certifies the boundary.
  Add one diagnostic: `private$cached_values$clmm_variance_boundary = fit$log_sigma <= -4.5`. Do **not** read
  `fit$params` or `fit$fisher_information`: the kernel returns neither today (side finding: `shared_rcpp` L296 passes
  `fit$params = NULL` to `set_fit_warm_start`, so the CLMM warm-start cache never holds the fit). TODO-5 adds `params`.
- [ ] **TODO-5 (C++, G1; NOT in 1.0.5 scope per G6 #45 (iii)(a) unless G1 runs anyway, otherwise v1.1.0): port the sibling's polish + projected-gradient
  convergence into `run_fast_ordinal_clmm`.** File `R/EDI/src/fast_ordinal_clmm.cpp` L106-180, modelled on
  `R/EDI/src/fast_ordinal_glmm.cpp` L384-402 (tight L-BFGS polish, `polish_tol = min(eps_g, 1e-10)`) and L417-501
  (projected damped Newton on the active set, then `converged = projected_gnorm <= max(1e-5, eps_g)`). Changes:
  1. After the multistart (L127-136), run the tight L-BFGS polish of `best_fit.params` and accept it only if
     `value <= best + 1e-10`.
  2. Compute the full gradient `g = obj(par, grad)`. Compute the likelihood-only log-sigma derivative
     `g_ls_lik = g[ls] - sigma_penalty_grad(par[ls])` and the tau-score `s = g_ls_lik / (2 * exp(2 * par[ls]))`.
  3. The **lower-variance active set** holds when `par[ls] <= -kSigmaPenaltyCenter + 1e-4 && s > 0`. Then drop
     log sigma from the Newton system and from the convergence norm. This is the KKT condition: the free-direction
     gradient is ~0 and the bound coordinate's gradient points outward. If `par[ls] <= -kSigmaPenaltyCenter + 1e-4 &&
     s <= 0`, the coordinate is **not** active. Keep it free: the Newton polish then pushes it inward, and if that
     fails, `converged = false`.
  4. If the projected gradient norm is > `max(1e-5, eps_g)`, run the projected Newton polish (sibling L446-495,
     `polish_maxit = min(maxit, 50)`, Armijo backtracking, LDLT positive check), accepting only if value
     `<= neg_ll + 1e-10`.
  5. `converged = isfinite(neg_ll) && par.allFinite() && projected_gnorm <= max(1e-5, eps_g)`. **Never** use
     `best_fit.converged`, which is the lenient flag. `gradient_norm` = projected norm.
  6. **Upper variance bound** (`par[ls] >= kSigmaPenaltyCenter - 1e-4`, the variance diverging): never active, so it
     reports `converged = FALSE` unless stationary. Set `variance_boundary_hit` via
     `glmm::glmm_variance_boundary_hit` (`_glmm_engine.h` L134).
  7. New result fields: `params` (full vector, which also fixes the warm-start side finding in TODO-4),
     `variance_boundary_hit`, `variance_boundary_tau_score` (= s), `lbfgs_gradient_norm` (pre-polish),
     `newton_polish_attempted/accepted/iterations`. The R wrapper signature is unchanged, so no `compileAttributes()`
     is needed for arguments. The returned list grows; check
     `test-ordinal-kk-clmm-rcpp-shared-failure-reasons-caching-and-ri-estimate-reference.R` and
     `test-kernel-warm-start-length-contracts.R` for exact-names assertions.
  Pseudo-diff, skeleton:
  ```
  -        par = best_fit.params; neg_ll = best_fit.value;
  -        converged = std::isfinite(neg_ll) && best_fit.converged;
  +        // tight L-BFGS polish (fast_ordinal_glmm.cpp L384-402)
  +        // full gradient; tau-score s from the likelihood-only ls derivative
  +        // lower-bound active iff ls <= -kSigmaPenaltyCenter + 1e-4 && s > 0
  +        // projected damped-Newton polish if ||g_free|| > max(1e-5, eps_g)  (L436-495)
  +        converged = isfinite(neg_ll) && par.allFinite() && g_free.norm() <= std::max(1e-5, eps_g);
  ```
  Once TODO-5 is in, TODO-4's retry becomes a no-op safety net and TODO-3 could return to 1e-6 (the polish does the
  work). Keep 1e-12 unless G2 timing says otherwise.
- [ ] **TODO-6 (docs/release; items 1-3 and 5 done 2026-10-22, item 4 drafted but the owner sends it):**
  1. Correct the TODO-31 golden note: the cloglog residual is the reference's link swap, not an EDI collapse.
  2. Add a NEWS entry. Cloglog BB/`use_rcpp = FALSE` now fit the cloglog model. KK CLMM estimates move by up to ~6e-3
     (median ~2e-4) because the fits now reach the stationary point. A new nonestimable reason.
  3. Add roxygen `@details` on `InferenceAbstractKKOrdinalCLMM`: the variance can sit at the lower boundary (sigma
     -> 0, legitimate), and how `converged` is judged.
  4. File the upstream ordinal report with the `diag2.R`/`diag4.R` reproducer (owner, G6 #45 (i)).
  5. Re-check TODO-76's statement that "CLMM is masked today by TODO-31's sigma collapse". It is not masked by a
     collapse. The cloglog BB mismatch is E3, fixed by TODO-2.

## Equivalence contract

| Change | Must stay bit-identical | Allowed to move (expected size) |
|---|---|---|
| TODO-1 (tests only) | all package outputs | nothing in the package |
| TODO-2 (link name) | logit/probit/cauchit everywhere (identity mapping); cloglog native path; `fit_clm_fallback`; `InferenceOrdinalKKGLMM` | cloglog BB nonconstant-weight draws and the cloglog `use_rcpp = FALSE` estimate/SE, moving to the cloglog model (golden: 0.2076 -> ~0.0869; 0.1940 -> ~0.087) |
| TODO-3 (`eps_g` 1e-12) | fixed-effects ordinal kernels; `fast_ordinal_glmm_cpp`/`InferenceOrdinalKKGLMM`; all other GLMM/LMM kernels; direct `fast_ordinal_clmm_cpp` calls that pass their own `eps_g`; logit/probit/cauchit BB (R helper) | every KK CLMM native fit, all four links (observed, rand refits, non-BB bootstrap, jackknife): treatment median ~2e-4, 90% ~1.5e-3, max ~6.4e-3; nll never increases (0/240 worse); log sigma up to ~0.09; boundary fits stay at the boundary (42/42 certified) |
| TODO-4 (acceptance + retry) | every fit with `gradient_norm <= 1e-4` after TODO-3 (all 120 in `sweep3`) | fits that fail the gradient test: retried (move toward the optimum) or NA with `kk_clmm_rcpp_not_stationary` (expected ~0) |
| TODO-5 (C++) | interior-converged results to within the polish (treatment |delta| <= ~2.4e-6 after TODO-3); non-CLMM kernels (single-file change); boundary fits' estimates (certified KKT) | `converged` flips TRUE -> FALSE only for genuinely non-stationary fits (expected ~0 in the sweep cells); `gradient_norm` becomes the projected norm (orders of magnitude smaller); new result fields; direct default-`eps_g` kernel callers move by TODO-3's sizes |

Nothing in this plan changes `optimize_likelihood_lbfgs`'s shared flag. That is Survey 2 recommendation 2 and the
v1.1.0 diagnostics chain (`release_v1_1_0.md → TODO-3`, failure mode 2).

## Tests to add (all under `R/package_tests/testthat_bulk/`; `skip_if_not_installed("ordinal")` where used)

1. `test-ordinal-clmm-cloglog-reference-link-name.R` (TODO-1): on E2's simulated 400-pair true-cloglog fixture,
   `ordinal_clmm_link_name("cloglog")` agrees with the probe. EDI cloglog vs `clmm(link = ordinal_clmm_link_name("cloglog"),
   nAGQ = 10)`: |delta w| <= 2e-3, |delta log sigma| <= 2e-2, |nll + logLik| <= 1e-2. The independent `integrate()`
   true-cloglog NLL at the EDI fit is <= the NLL at the clmm-"cloglog" parameters (pins that the mislabelled fit is
   worse under cloglog). Reuse the oracle pattern of `test-ordinal-clmm-integrated-likelihood.R`.
2. `test-ordinal-kk-clmm-cloglog-golden-boundary-is-kkt.R` (root-cause pin): on the golden design, `log_sigma <= -4.5`.
   The treatment is within 1e-4 of `ordinal::clm(link = "cloglog")` (0.08686). The tau-score from a fixed-log-sigma
   Newton profile (`fixed_idx` = last, values `log(0.1)` vs the boundary) / 0.01 is > 0.5 (observed 0.91).
3. `test-ordinal-kk-clmm-stationary-fit-kkt.R` (TODO-3/4, the convergence assertion): over 4 links × {n = 60, 200} ×
   sigma_b {0, 0.6} × 3 seeds (fixed list from `sweep.R`'s `gen()`), the class `cached_mod$gradient_norm` is <= 1e-4.
   The treatment is within 1e-5 of a kernel Newton polish (`optimization_alg = "newton_raphson"`, warm start = returned
   params, `eps_g = 1e-10`). Boundary fits: `log_sigma <= -4.5` implies tau-score > 0. After TODO-5, add
   `gradient_norm <= max(1e-5, eps_g)` and `variance_boundary_tau_score > 0` whenever `variance_boundary_hit`. This
   test fails today (gn median 1e-2).
4. `test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` (reference test with tolerances): same fixtures with
   sigma_b ∈ {0.6, 1.2}. Reference is `clmm(nAGQ = 20, link = ordinal_clmm_link_name(link))`. Tolerances on |delta w|:
   logit/probit 3e-3, cloglog 3e-3 (sweep max at sigma_b <= 0.6 is 2.5e-3), cauchit 2e-2 with `skip` when clmm errors.
   This absorbs the quadrature difference recorded in E5 (adaptive vs 20-node). Log sigma 0.1. A class-level
   assertion `isTRUE(cached_mod$converged)` and the gradient bound of test 3.
5. `test-ordinal-kk-clmm-weighted-helper-matches-native-all-links.R` (TODO-2): `compute_weighted_clmm_estimate(rep(1, n))`
   equals the native estimate within 2e-3 for all four links on the golden design and on seed-302. The cloglog leg
   fails today (0.2076 vs 0.0869). The `use_rcpp = FALSE` cloglog estimate is within 1e-2 of native (Laplace vs
   20-node GH).
6. Pin updates (TODO-3): `test-ordinal-kk-clmm-gradient-tolerance-matches-clmm.R`, both legacy fixtures, and the
   golden must pass 141/141 afterwards.

Verification for TODO-1..4 needs no compile: `pkgload::load_all("R/EDI", compile = FALSE)` + `testthat::test_file(...)`
against the installed DLL, recording its SHA-256. TODO-5 needs G1.

## Gates

- **G1** (TODO-5 only): targeted `EDI_UNITY=0` compile of `fast_ordinal_clmm.cpp`, relinked only if the per-file
  `.o` set exists; otherwise stop and ask, per `CLAUDE.md`. Header-free change: `fast_ordinal_glmm.cpp`'s lambdas
  are copied, not shared, so no header edit is needed. If patch 01 is applied in the same build, the CLMM's own
  projected Newton loop does not call `optimize_likelihood_newton`, so the two are independent. Run tests 1-6 plus
  `test-ordinal-clmm-integrated-likelihood.R`, `test-ordinal-kk-clmm-migration-golden.R`,
  `test-ordinal-kk-clmm-rcpp-shared-failure-reasons-caching-and-ri-estimate-reference.R`,
  `test-kernel-warm-start-length-contracts.R` and `test-gcomp-rmst-ordinal-clmm-contracts.R`.
- **G4** (rows that move): all `InferenceOrdinalKKCLMM`, `InferenceOrdinalKKCLMMProbit`, `InferenceOrdinalKKCLMMCauchit`
  and `InferenceOrdinalKKCLMMCloglog` rows: asymptotic, rand p/CI, rand-bootstrap, non-Bayesian bootstrap and
  jackknife (TODO-3/4). For `InferenceOrdinalKKCLMMCloglog`, also the ten Bayesian-bootstrap procedures (TODO-2).
  These belong in the existing "31, 50, 76" G4 slice. Regenerate them once, after TODO-2..4 (and TODO-5 if it lands),
  not per step. The drifted `package_tests` CSVs (pre-push auto-regeneration) also move for these classes.
- **G2** (optional): quiet-host timing of the ~3x per-fit cost on a randomization test (r = 1000, n = 200).
- **G6 #45**: decisions below.

## Risks

- **The probe is wrong or ordinal changes the behaviour.** The probe compares against EDI's own objective, so a future
  upstream fix flips the mapping back automatically. The NA branch refuses rather than guesses.
- **The ~3x CLMM cost** affects randomization and bootstrap loops. It is measured at n <= 200 only. Mitigation:
  TODO-5's polish makes 1e-6 sufficient again.
- **Golden drift.** The legacy-vs-live golden hard-codes the tolerance. Forgetting either fixture copy reproduces
  today's 39 failures.
- **New NA reason** (TODO-4): expected ~0, but it is a behaviour change for pathological data. The retry is in place
  so that NA is the last resort.
- **The upper variance boundary** (TODO-5 item 6) can turn some currently "converged" quasi-separated fits into
  NA/non-converged. That is correct, but visible. The sweep had no upper-bound fits; check G4 counts.
- **Quadrature gaps at large sigma_b** (E5) remain and can look like optimizer failures in reference tests. That is
  why test 4's tolerances are sized for sigma_b <= 0.6 / 1.2 as stated, and the real fix stays TODO-153.

## Owner decisions needed (G6 #45)

(i) **Accept the diagnosis.** The golden cloglog log sigma = -5 is the correct MLE, and `ordinal::clmm`'s
cloglog/loglog names are swapped, so TODO-31's cloglog residual is closed as a reference error. File an upstream
report? **Recommend yes to both.**

(ii) **EDI's own `ordinal::clmm` cloglog calls** (BB nonconstant-weight refit, `use_rcpp = FALSE`):
(a) runtime-probed name mapping (TODO-1/2, R-only, 1.0.5);
(b) hard-coded `"loglog"`;
(c) refuse cloglog on those paths until a native weighted kernel exists (v1.1.0).
**Recommend (a).**

(iii) **1.0.5 scope for the false convergence:**
(a) R-only TODO-3 + TODO-4 (`clmm_eps_g = 1e-12`, gradient acceptance <= 1e-4 with one Newton retry; ~3x CLMM fit
cost; estimates move up to ~6e-3, median ~2e-4);
(b) (a) plus C++ TODO-5 in G1;
(c) defer everything to v1.1.0 and document the lenient flag.
**Recommend (a) for 1.0.5, with TODO-5 in G1 only if that build happens anyway (else v1.1.0).** An R-side retry
alone, without the tolerance change, does **not** fix the common case cheaply: 100% of fits would fail a gradient
test and pay the 54-155 ms Newton cost. Tolerance plus acceptance is the R-only fix.

## Implementation record (2026-10-22, R only; no build/install/compile, no roxygenize)

Owner decisions G6 #45: (i) accept the diagnosis and report upstream; (ii)(a) runtime-probed name mapping;
(iii)(a) R-only TODO-3 + TODO-4. TODO-5 (C++) is not in scope (v1.1.0, or G1 if that build happens anyway).
Verified with `library(EDI)` + `pkgload::load_all("R/EDI", compile = FALSE)` (installed EDI 1.0.3 DLL, ordinal 2026.7.26).
Scratch: `/tmp/claude-1000/todo31_impl/` (`measure.R`, `measure_{before,final}.rds`, `equiv.R`, `rand_timing.R`,
`upstream_repro.R`, `run_tests.R`).

- **TODO-1:** `ordinal_clmm_cloglog_link_probe()` and `ordinal_clmm_link_name(link)` live in
  `R/EDI/R/helper_ordinal_mixed_fit.R` (package-internal, so package code and tests share them). The probe uses a
  fixed RNG-free 40-group × 5 dataset (sigma 1.5), fits clmm `"cloglog"`/`"loglog"` at `nAGQ = 10`, and evaluates
  the true-cloglog NLL with `stats::integrate()`. Result: `"loglog"` matches (|diff| 1.6e-4); `"cloglog"` is off
  by 7.7. The result is cached per session and ordinal version in `EDI_ORDINAL_CLMM_LINK_NAME_CACHE`. Measured cost
  is **~1.9 s** once per session, not ~0.2 s: the two clmm fits dominate, and `nAGQ` 3/5 lose the 1e-3 match. If
  the probe is undecided it returns NA. Test oracles now use the helper:
  `test-ordinal-kk-glmm-class-matches-clmm-and-kk-clmm-class-collapses-to-fixed-effects-reference.R` (nonlogit
  leg, tolerances tightened 0.15/0.2 -> 3e-3/2e-2; measured <= 4e-5/1.3e-4) and
  `test-ordinal-kk-clmm-boundaries-coverage.R` (weighted cloglog reference).
- **TODO-2:** the weighted BB helper and `fit_clmm` pass `ordinal_clmm_link_name(link)`. On NA they emit a
  classed warning `edi_clmm_link_unverified` and return NA/NULL. `clm` calls are unchanged. Golden design:
  BB unit-weight cloglog 0.20758 -> 0.08686 (native 0.08687). `use_rcpp = FALSE` cloglog 0.19395 -> **0.14608**,
  not ~0.087 as predicted: that is clmm's default Laplace (`nAGQ = 1`) approximation of the correct model on
  n = 60 (Laplace optimum sigma 0.57, -logLik 80.94, worse than the boundary's 80.897). On the n = 200 seed-302
  design it is within 1e-2 of native. Logit/probit/cauchit BB and `use_rcpp = FALSE` estimates are bit-identical.
- **TODO-3:** `clmm_eps_g = 1e-12`, with both legacy fixtures (bulk and `R/EDI/tests/testthat/` copies) and the pin
  in `test-ordinal-kk-clmm-gradient-tolerance-matches-clmm.R` updated. Golden: 141/141 pass after one change. The
  Cauchit golden needs tolerance 1e-5 instead of 1e-6, because legacy and migrated differ by 2.0e-6 abs on the first
  rand draw and the jackknife at the flat lower-variance boundary. The TODO-4 retry is not involved (same diffs with
  it disabled), and the root cause of the path difference was not traced.
- **TODO-4:** private `clmm_accept_fit(fit, call_args)` and field `clmm_gradient_accept = 1e-4`, used by
  `shared_rcpp` and `compute_ri_estimate_rcpp`. Deviations from the plan text, both forced by measurement:
  1. **Retry acceptance.** The Newton retry is accepted on gradient + no-worse alone. At `eps_g` 1e-12, Newton's own
     `converged` is FALSE in most fits even at gn ~1e-10 (the strict `gnorm < tol`). The accepted retry is marked
     `converged = TRUE` (`kernel_converged` keeps the kernel flag, `clmm_newton_retry = TRUE`).
  2. **Retry tolerance.** The retry `eps_g` is `min(eps_g, 1e-6)`.
  3. **SE for a full fit.** If the accepted retry has no SE, one more Newton evaluation runs at
     `eps_g = clmm_gradient_accept`.

  Reasons: `kk_clmm_rcpp_not_stationary` applies to a converged but non-stationary fit; `kk_clmm_rcpp_failed` is
  unchanged for a missing or non-converged fit. Diagnostic `cached_values$clmm_variance_boundary`. Call-graph delta
  recorded in `inference_component_expect_reviewed_registry_baseline()`.
- **Equivalence** (120 class fits: 4 links × n {60, 200} × sigma_b {0, 0.6, 1.2} × 5 seeds, before vs after):

  | Link | Treatment movement (median / 90% / max) | Randomization refit max | log sigma max |
  |---|---|---|---|
  | logit | 3.7e-4 / 1.5e-3 / 2.4e-3 | 1.9e-3 | 4.5e-3 |
  | probit | 1.1e-4 / 6.9e-4 / 1.9e-3 | 1.1e-3 | 0.088 |
  | cauchit | 3.6e-4 / 2.3e-3 / 6.4e-3 | 4.2e-3 | 0.072 |
  | cloglog | 1.4e-4 / 1.1e-3 / 1.8e-3 | 7.4e-4 | 2.6e-3 |

  The SE moves by at most 2.2e-3. nll is never worse (0/120). No fit became NA. Boundary fits: 16 before, 16
  after. Gradient norm after: median 7.1e-6, max 4.8e-5 (was median 1.1e-2, max 0.20). All of this is within the
  contract (max ~6.4e-3).
- **Timing** (loaded host, load average 5-8, indicative only):

  | Measurement | Before | After | Ratio |
  |---|---|---|---|
  | Class `compute_estimate`, n = 60 (median) | 17 ms | 23 ms | ~1.4x |
  | Class `compute_estimate`, n = 200 (median) | 44 ms | 64 ms | ~1.45x |
  | Randomization refit, n = 200 (median) | 70 ms | 92 ms | |
  | `approximate_randomization_distribution_beta_hat_T(r = 200)`, n = 200, logit (A/B in-process) | 3.7 s | 10.1 s | 2.7x |
  | Same, cloglog | 4.3 s | 12.6 s | 2.9x |

  The probe adds ~1.9 s once per session. The retry costs 50-220 ms median when it runs (max 2.7 s).
- **Tests added** (all pass): `test-ordinal-clmm-cloglog-reference-link-name.R` (18),
  `test-ordinal-kk-clmm-cloglog-golden-boundary-is-kkt.R` (7), `test-ordinal-kk-clmm-stationary-fit-kkt.R` (258;
  includes forced-retry and forced-NA cases), `test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` (180).
  The last uses per-sigma_b tolerances (cloglog 2e-2 at sigma_b 1.2, measured 1.7e-2 quadrature gap) and skips a
  cauchit cell where clmm is 0.18 nll worse. `test-ordinal-kk-clmm-weighted-helper-matches-native-all-links.R` (19).
- **TODO-6:** roxygen `@details` on `InferenceAbstractKKOrdinalCLMM` (Rd pending G8). NEWS: bug fixes ×2 and
  performance. Release doc: TODO-31 note and TODO-76 re-check. Upstream draft:
  `upstream_ordinal_clmm_link_swap_report.md` (not posted).
- **Left:** TODO-5 (C++, v1.1.0/G1). G4: regenerate all four KKCLMM classes' rows (asymptotic, rand p/CI,
  rand-bootstrap, non-BB bootstrap, jackknife) and the ten cloglog BB procedures. G8: Rd. The owner sends the
  upstream report.
