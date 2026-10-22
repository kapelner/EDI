# optimize_likelihood_newton: false non-convergence (C++ patch plan)

Found 2026-10-22 while fixing ZIP `compute_estimate()` NA (v1.0.5 TODO-4 notes) and
surveyed across families (v1.0.5 TODO-123). Release target: v1.0.5 (fix-only; the
convergence flag is wrong, estimates are fine).

## Problem

`optimize_likelihood_newton` (`R/EDI/src/_helper_functions_core.h`) returns
`converged = FALSE` when it is already at the optimum to ~6 digits, because the
predicted decrease at gradient norm ~1e-7 is ~1e-17, below the rounding of a log-likelihood
of ~90, so `candidate < current` never holds. In an R port on Poisson data 68 of 79
non-converged exits were the line-search failure (`if (!accepted) break;`) and 11 were the
step-size exit. The LBFGS fallback does not beat it. R then discards the fit
(NA estimate, failed hardened fit, or silent downgrade).

## Survey (installed kernels, `optimization_alg = "newton_raphson"`, 30 seeds x 3 DGPs per n)

False non-convergence = `converged = FALSE`, gradient norm < 1e-4 and loglik gap to the
reference < 1e-3 (references: pscl, MASS::glm.nb, betareg, ordinal::clm, VGAM, survreg).
Counts out of 90 fits per cell:

| Family (tol) | n=40 | n=100 | n=200 |
|---|---|---|---|
| hurdle-Poisson (1e-8) | 7 | 10 | 10 |
| ZIP (1e-8) | 3 | 8 | 9 |
| Poisson via Newton (1e-8) | 17 | 16 | 13 |
| Weibull via Newton (1e-8) | 19 | 22 | 32 |
| beta (1e-6) | 0 | 0 | 5 |
| NB via Newton (1e-6) | 0 | 0 | 4 |
| ordinal logit (1e-6) | 0 | 0 | 3 |
| ordinal probit (1e-6) | 0 | 0 | 1 |
| stereotype (1e-8) | 0 | 0 | 1 |

Zero false failures: adjacent-category, continuation-ratio, ordinal cloglog/cauchit, ZOIB.
True failures (must stay failures): ZINB 6/90 at n=40, hurdle-NB 3/90 at n=40,
stereotype 12/8/8; all have gradient norm >= 4.96e-4. At tol 1e-6 (the KK21 Weibull helper)
the Weibull rate falls to 0/1/5.6%. Default-reachable large rates: hurdle-Poisson and ZIP
(both now have an R-side recovery). Others are reachable only with `newton_raphson` or via
KK21 Weibull weights. An R cold retry rescues most but not all (ZIP 15/20, hurdle 24/27,
Poisson 33/46, Weibull 63/73, beta 5/5, NB 4/4, ordinal 4/4); warm start from the stalled
parameters rescues about nothing. Not surveyed: GLMM/CLMM/LMM/Gauss-Hermite kernels, Cox
kernels, pure LBFGS paths.

## Proposed patch (not compiled; text from the survey agent, untested)

Add `newton_stalled_at_optimum(fun, params, gnorm, tol)`: true when
`gnorm < min(1e-4, 10 * tol * max(1, lambda_max(H)))`, H = `hessian_for_opt` at the final
params, `lambda_max` the spectral norm from a `SelfAdjointEigenSolver` on the symmetrized
H; false for non-finite values. Set `bool stalled = false;` before the loop and write the
line-search exit as `if (!accepted) { stalled = true; break; }`. Step-size exit:
`fit.converged = (last_grad_norm < tol) || newton_stalled_at_optimum(...)`. Final
fall-through: `fit.converged = (last_grad_norm < tol) || (stalled && newton_stalled_at_optimum(...))`.
Singular-Hessian and non-finite exits never loosen. The gradient is a sum over observations, so
`tol * lambda_max(H)` is the gradient size corresponding to a parameter error of about `tol`.

Offline evidence on the survey data (179 false cases, 39 true failures):
Hessian-scaled rule rescues 179/179 and accepts 0/39 true failures; absolute 1e-4 also
179/0 but only a 5x margin (smallest true failure 4.96e-4); absolute 1e-5 rescues 176/179.
The ratio `gnorm / (tol * lambda_max)` is <= 2.06 over false cases and >= 3.3e2 over true
failures. The absolute cap also blocks one degenerate hurdle-NB divergence (gradient 2e12,
lambda 3e24) that the ratio alone would accept. Weibull used a crude `lambda_max(X'X)` proxy.

## Raw patch text from the survey agent

```
// (1) new helper, placed just above optimize_likelihood_newton in _helper_functions_core.h
// Accept a Newton terminal state that stalled at (numerically) the optimum:
// the gradient is a SUM over observations, so the absolute tol is not
// scale-free; tol * lambda_max(H) is the gradient size that corresponds to a
// parameter error of ~tol (|theta-theta*| ~ H^-1 g). 10x slack + absolute cap.
template <typename LikelihoodFunctor>
inline bool newton_stalled_at_optimum(LikelihoodFunctor& fun, const Eigen::VectorXd& params,
                                      double gnorm, double tol) {
    if (!std::isfinite(gnorm)) return false;
    Eigen::MatrixXd H = hessian_for_opt(fun, params);
    if (!H.allFinite()) return false;
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> es(0.5 * (H + H.transpose()), Eigen::EigenvaluesOnly);
    if (es.info() != Eigen::Success) return false;
    const double lam_max = es.eigenvalues().cwiseAbs().maxCoeff();
    if (!std::isfinite(lam_max)) return false;
    return gnorm < std::min(1e-4, 10.0 * tol * std::max(1.0, lam_max));
}

// (2) in optimize_likelihood_newton: add `bool stalled = false;` before the loop.
// (3) line-search failure:   if (!accepted) { stalled = true; break; }
// (4) step-size exit: replace
//         fit.converged = (last_grad_norm < tol);
//     with
//         fit.converged = (last_grad_norm < tol) ||
//                         newton_stalled_at_optimum(fun, params, last_grad_norm, tol);
// (5) final fall-through return: replace
//         fit.converged = (last_grad_norm < tol);
//     with
//         fit.converged = (last_grad_norm < tol) ||
//                         (stalled && newton_stalled_at_optimum(fun, params, last_grad_norm, tol));
// Singular-Hessian / non-finite exits keep stalled=false (never loosened).
```

## Verification plan (needs the user's targeted compile, `EDI_UNITY=0`)

1. Apply the patch; compile only the touched file(s) per CLAUDE.md.
2. Re-run the survey (`sim2.R`-style): all 179 false cases converge; all 39 true failures
   still fail; no estimate changes for already-converged fits (bit-identical).
3. Add a regression test modelled on `test-zip-newton-stall-cold-retry.R` (seeds 6 and 19, n = 100).
4. After the C++ fix, the R-side cold retries (ZIP, hurdle) remain as safety nets.

## KK21 Weibull helper impact

Read-mostly impact analysis (installed EDI built 2026-10-22 02:36, i.e. after the TODO-67
shared-`WeibullAFTLikelihood` edits; no C++ touched, no build). Scratch scripts:
`$TMPDIR/tkk21w/{sim,d,e}.R`.

**What a `-1.0`/`false` does downstream (the premise "ranked as uninformative" is not quite right).**
- `univariate_weibull_tstat` (kk21_weights.cpp ~L742) -> `kk21_survival_weights_cpp`
  (called from `design_seq_one_by_one_KK21.R:386`): `tstat > 0` fails, so that covariate falls back to
  the univariate OLS-on-log(y) |t|. It is NOT dropped or ranked last. Weight is a different (usually
  smaller, noisier) statistic mixed with Weibull |z| of the other covariates.
- `weibull_reduced_fit_for_score_test` (kk21_stepwise_survival.cpp ~L14) -> `kk21_stepwise_survival_weights_cpp`
  (called from `design_seq_one_by_one_KK21_stepwise.R:281`): `fit_ok = FALSE` switches ALL remaining
  steps to the FWL OLS-on-log(y) path (it never reverts to Weibull, since the failing fit is not retried
  after the next covariate is added). Earlier-picked covariates keep Weibull score statistics, later ones
  get OLS |t|: a mixed-scale weight vector. Nothing is NA/0 unless OLS also breaks.
- The weights then feed the KK21 distance weighting (relative scale only), so the effect is a
  perturbed relative weighting, not a dropped covariate or a crash.

**Simulation** (installed kernels via `EDI:::`; 30 seeds per n; p = 5 standardized N(0,1) covariates,
true log-time effects 0.8 (X1), 0.4 (X2), 0 (X3-5), treatment 0.5, Weibull scale 0.5, ~15% censoring;
reference = survreg, tol 1e-12 rel, Weibull score test replicated in R; tolerance of the kernel is NOT an
R argument so the two-tolerance comparison was not possible, the kernel at its hard-wired 1e-6 is
compared with survreg instead).

| n | univariate fits where kernel != survreg \|z\| (and equals OLS t = fallback) | stepwise seeds where final weight vector changed (rel. tol 1e-3) | seeds where selection order changed | mean TV of normalized weights, changed seeds | weight share on true prognostic X1+X2, kernel vs survreg |
|---|---|---|---|---|---|
| 40  | 0/150 (0%)    | 0/30 (0%)     | 0/30  | -    | 0.759 vs 0.759 |
| 100 | 4/150 (2.7%)  | 4/30 (13%)    | 2/30  | 0.096 (max 0.11) | 0.854 vs 0.854 |
| 200 | 26/150 (17%)  | 6/30 (20%)    | 6/30  | 0.092 (max 0.12) | 0.897 vs 0.888 |

(A first run with a slightly different censoring stream gave 10% / 43% of stepwise seeds changed at
n = 100 / 200 and univariate order changes in 10% / 20% of seeds, so the rate at n = 200 is roughly
20-40%, with 100% of the discrepancies being the OLS fallback, none being a wrong Newton optimum.)
Every flagged univariate fit was a fallback to the OLS t (identical to 1e-6), and every one of those
fits converges under survreg, i.e. all are false non-convergence. The false rate grows with n, as in
the survey, and is higher than the survey's 5.6% at n = 200 here (small Weibull scale -> large
Hessian -> absolute gradient tolerance too strict; consistent with the Hessian-scaled-rule diagnosis).

**Materiality.** Small. When the weight vector changes, its total-variation distance to the survreg
version is ~0.09-0.12, the same order as the KK21 `*_use_speedup` loss (TV 0.02-0.16 against 0.1-0.43
own noise; v1.0.5 TODO-67 / project notes). The share of weight on the truly prognostic covariates is
unchanged on average (0.854 vs 0.854, 0.897 vs 0.888), so covariate balance/efficiency of the resulting
assignments should be unaffected to first order. I did not run the full design and measure assignment
imbalance (weights only rescale distances); that is an inference from the weight shares, not a measurement.

**Recommendation: (b).** No separate change. The failing exits are exactly the false non-convergence the
Newton patch (`newton_stalled_at_optimum`, Hessian-scaled rule) fixes, so applying it makes both helpers
stop falling back (expected: 0% change vs survreg up to ~1e-6 for the 150 + 150 fits above); re-run
`$TMPDIR/tkk21w/sim.R` after the targeted compile as the verification (expect `step_same` = 1, `n_uni_diff` = 0).
Optional small hardening, only if desired (cheap, not required): in the stepwise helper, when a fit fails
mid-way, retry once from a cold start (beta = 0 for the added column) before switching the remaining
steps to OLS, to avoid the mixed-scale weight vector; the failure is never silent-dropped, so explicit
failure propagation (option c) is not warranted.

## Survey 2: GLMM/CLMM/LMM, Cox and LBFGS kernels

Read-mostly survey, 2026-10-22 (installed EDI built 2026-10-22 02:36 via `EDI:::fast_*_cpp`; no C++ touched,
no build). Scratch: `$TMPDIR/tsurvey2` (= `/tmp/claude-1000/tsurvey2`; `gen.R`, `common.R`, `run_glmm.R`,
`run_cox.R`, `run_single.R`, `run_surv.R`, `run_hpg.R`, `all_results.csv`). 30 seeds x 2 DGPs per n (60 fits per
cell), n in {40, 100, 200}. DGP 1 = balanced/benign; DGP 2 = unbalanced/near-separated (10-15% treated, rare
outcomes or categories, strong effect, skewed covariate, heavy ties/censoring for Cox, sigma_b near 0 for the LMM).
GLMM designs are KK-shaped (30% matched pairs, rest singletons). Per-fit timeout 120 s (never hit; GLMM fits take
<0.2 s here). Definitions as in the first survey: false non-convergence (FALSE_NC) = `converged = FALSE`, gradient
norm < 1e-4 and loglik gap to the reference < 1e-3. References: `lme4::glmer(nAGQ = 20)` (Poisson: the kernel's
Gauss-Hermite objective evaluated at glmer's parameters, because glmer's Poisson `logLik` differs from the
kernel's by a data-dependent amount), `lmer(REML = FALSE)`, `ordinal::clmm(nAGQ = 20)`, `survival::coxph`
(Breslow, eps 1e-12), `survreg`, `MASS::glm.nb` (+ BFGS polish), `ordinal::clm`, `betareg`, `pscl`, `glm`; DepCens and
Clayton have no external reference, so the reference is the best of several tight multistart fits of the kernel
itself (including atanh(rho) pinned at +-3 for DepCens).

### Headline

1. **The pure-LBFGS path almost never reports `converged = FALSE`.** `optimize_likelihood_lbfgs` sets
   `converged = (gnorm < tol) || (niter < maxit)` (`_helper_functions_core.h` ~L1361), so a FALSE needs an
   iteration-cap hit or a thrown line search. Across ~2,600 non-Cox LBFGS fits (GLMM/LMM/CLMM and the other
   kernels below) there were 0 cap hits and 0 stalled-at-optimum FALSEs. The Newton-side stall pattern of the first
   survey does not exist on the LBFGS path, so **no LBFGS-side analogue of `newton_stalled_at_optimum` is needed**.
2. **The LBFGS problem is the opposite one: over-lenient `converged = TRUE`.** Median gnorm/tol at a "converged"
   LBFGS exit is 1e3-7e4 (e.g. LMM final gradient ~0.03 at tol 1e-6, Weibull ~1e-4..1e-3 at 1e-8). The loglik is
   usually fine (gap < 1e-3), but some fits are accepted with a real gap (table column D).
3. **The Newton-side stall DOES occur in the GLMM/LMM kernels when run with `newton_raphson`** (they share
   `optimize_fixed_likelihood` -> `optimize_likelihood_newton_then_lbfgs`), and the proposed Hessian-scaled rule
   rescues all of them. This is default-reachable for the Poisson KK GLMM (policy default `newton_raphson`).
4. **Cox NR false non-convergence is just `maxit = 20` being 1-3 iterations short** (6 cases, all n = 40, DGP 2);
   the stall rule is not the right fix there. Cox LBFGS (maxit = 20, tol = 1e-9 in the exported wrapper) hits the
   cap often, but that is budget, not a stall, and is not what the classes call.
5. **Real failures found (not "false non-convergence", but they are what the discard path actually sees):**
   DepCens default-start fits throw/NaN in 19% of bootstrap-like resamples; Cox NR can return `converged = TRUE` at a
   diverged point (1/720 NR fits); the hurdle-Poisson GLMM landscape is multimodal.

### Table: counts per cell "A/B/C/D (N)"

A = FALSE_NC; B = non-converged, gap < 1e-3 but gnorm >= 1e-4 (hit the cap with a good loglik); C = true failure
(non-converged with gap >= 1e-3, or NaN/throw); D = `converged = TRUE` but gap >= 1e-3 (false convergence).
N = fits compared (ordinal cells are smaller because draws missing a category were dropped; a few reference
failures dropped).

| kernel (algorithm) | n=40 | n=100 | n=200 |
|---|---|---|---|
| Poisson GLMM (lbfgs) | 0/0/0/0 (60) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| **Poisson GLMM (newton_raphson, class default)** | 0/0/0/1 (60) | **1**/0/0/0 (60) | **3**/0/0/0 (60) |
| Logistic GLMM (lbfgs) | 0/0/0/6 (60) | 0/0/0/9 (60) | 0/0/0/5 (60) |
| Logistic GLMM (newton_raphson) | 0/0/0/6 (60) | 0/0/0/9 (60) | 0/0/0/5 (60) |
| Gaussian LMM (lbfgs, class default) | 0/0/0/0 (60) | 0/0/0/0 (60) | 0/0/0/3 (60) |
| **Gaussian LMM (newton_raphson)** | 0/0/0/8 (60) | **1**/0/0/8 (60) | **10**/0/0/4 (60) |
| CLMM (lbfgs, eps_g 1e-6) | 0/0/0/0 (59) | 0/0/0/4 (60) | 0/0/0/1 (60) |
| CLMM (lbfgs, eps_g 1e-3, what the class passes) | 0/0/0/52 (59) | 0/0/0/60 (60) | 0/0/0/60 (60) |
| Hurdle-Poisson GLMM (lbfgs) | 0/0/10/10 (60) | 0/0/0/17 (60) | 0/0/0/19 (60) |
| Hurdle-Poisson GLMM (newton_raphson, class default) | 0/0/9/32 (60) | 0/0/0/33 (60) | 0/0/0/28 (60) |
| Cox NR, cold start (class default) | 1/0/0/1 (60) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| Cox NR, smart start | 2/0/0/0 (60) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| Stratified Cox NR, cold / smart | 0/0/0/0 ; 3/0/0/0 (60) | 0 (60) | 0 (60) |
| Cox LBFGS, smart start (wrapper default, maxit 20) | 1/8/3/0 (60) | 1/11/3/0 (60) | 1/13/4/0 (60) |
| Cox LBFGS, cold start | 0/3/4/0 (60) | 0/6/4/0 (60) | 0/4/4/0 (60) |
| Stratified Cox LBFGS, smart / cold | 1/5/1/0 ; 1/5/2/0 (60) | 2/8/1/0 ; 1/7/3/0 (60) | 2/9/2/0 ; 0/6/3/0 (60) |
| DepCens transform (lbfgs, default start, estimate-only) | 0/0/24/7 (60) | 0/0/17/4 (60) | 0/0/27/2 (60) |
| Clayton Weibull AFT (lbfgs) | 0/0/3/0 (60) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| Weibull, LBFGS (tol 1e-8) | 0/0/0/0 (60) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| NB, LBFGS | 0/0/0/0 (58) | 0/0/0/0 (60) | 0/0/0/0 (60) |
| Ordinal logit / cloglog, LBFGS | 0/0/0/0 (33/30) | 0/0/0/1 ; 0 (49/31) | 0 (57/39) |
| Beta, LBFGS | 0/0/0/1 (58) | 0/0/0/1 (60) | 0/0/0/0 (60) |
| ZIP / hurdle-Poisson / ZINB, LBFGS | 0 (60/59/58) | 0 (60) | 0 (60) |
| Logistic (glm), LBFGS | 0 (60) | 0 (60) | 0 (60) |

Notes on the cells.
- Poisson GLMM@NR FALSE_NC: 4/180, niter 5-10 (not the cap), gnorm 1.5-3.3e-6 at tol 1e-6, gap <= 1e-7 (or
  the kernel *better* than glmer by 1-3e-3), Hessian ratio gnorm/(tol*lambda_max) 0.009-0.013. This is exactly the
  first survey's line-search/step-size stall. LMM@NR FALSE_NC: 11/180 (n=200: 10/60, 7/30 in DGP 1), niter 7-14,
  gnorm 1.1-4.3e-6, gap ~1e-13 (the optimum to machine precision), ratio 0.005-0.019.
- Cox NR FALSE_NC (6): all DGP 2 (10% treated, lognormal covariate, heavy ties) at n = 40, `hit_iteration_cap`
  TRUE (niter = 20), gradient 1e-8..1.4e-7, gap 1e-9..3e-8, ratio 0.002-0.83. With `maxit = 100` all six converge
  at iteration 20-23. Cox LBFGS B/C cells: all are `hit_iteration_cap`; with `maxit = 100` **all 129 non-converged
  LBFGS fits converge** (max |gap| 4e-4), so these are iteration-budget failures.
- Column C for DepCens (68/360 = 19%, all `converged = FALSE`, value NaN, niter = maxit) is the TODO-111 flat-clamped
  coordinate throw: for all 68, the R cold-zero retry also fails but the atanh(rho)-pinned fit converges (68/68).
  Clayton C (3/60 at n = 40) is the same NaN/throw signature; 11 further Clayton fits had `converged = TRUE`
  (gnorm 1.5e-4..4.4e-3) but no external or multistart reference converged, so they are unclassified.
- Column D, Logistic GLMM: 17 of 20 are DGP 2 (near-separation, 2.5 log-odds effect, 15% treated); the fits stop
  with `converged = TRUE`, gnorm ~1e-3, and a loglik up to 6 below glmer's; treatment estimates 34 vs 58 (the
  likelihood is nearly monotone). Not default-reachable (below). LMM D: 3 fits, gap 1.4-2.1e-3.
- CLMM at the class's `eps_g = 1e-3`: `converged = TRUE` but treatment-effect error vs `clmm` has median 0.05-0.07 (max
  0.52) log-odds and loglik gap median 0.04-0.07 (max 2.2); at 1e-6 the error is median 2e-4 (max 5e-3).
  (Precision, not a false-FALSE issue, but it is the same lenient-criterion root cause.)
- Hurdle-Poisson GLMM: the objective has several local optima with small gradients (e.g. n=200 DGP 2 seed 3: four
  starts converge at nll 101.3, 65.8, 66.5 and 63.3 with very different parameters), so column D there mostly
  measures multimodality, not premature stopping; treat the 10-19 / 28-33 counts as an upper bound. The C cell
  (n = 40, 9-10 fits) is a NaN/throw. Flagged for follow-up, no FALSE_NC either way.

### R handling when `converged = FALSE` and default reachability

Policy defaults (`edi_optimization_dispatch_policy()`): `newton_raphson` for InferenceCountKKPoissonCombinedOneLik,
InferenceCountKKHurdlePoissonGLMM, InferenceSurvivalWeibull, InferenceSurvivalDepCensTransformRegr,
InferenceSurvivalCoxPH (kernel NR), ZIP, hurdle, beta; `lbfgs` for InferenceContinuousKKGLMM, InferenceCountNegBin,
InferenceOrdinalPropOddsRegr.

| kernel | R handling of `converged = FALSE` | default-reachable? |
|---|---|---|
| `fast_poisson_glmm_cpp` | `inference_count_KK_combined.R` ~L299, L370: fall back to glmmTMB (weighted path / `shared_glmm_tmb`); NA only if that also fails. Fit discarded (cost + Laplace vs GH-20 estimate shift). | yes, **at newton_raphson (the default)** |
| `fast_gaussian_lmm_cpp` | `inference_continuous_KK_glmm.R` ~L309: fall back to `shared_glmm_tmb`; likelihood-test helpers return NULL | yes, at lbfgs (0 FALSE there); NR only if the user sets it |
| `fast_ordinal_clmm_cpp` | **NA, no fallback**: `inference_ordinal_KK_clmm_abstract.R` L165 `return(NA_real_)`; full fit `cache_nonestimable_estimate("kk_clmm_rcpp_failed")`. Class passes no `optimization_alg` (lbfgs) and `eps_g = 1e-3` in the unweighted estimate | yes, but 0/358 non-converged here; the exposure is the NA design, not a measured rate |
| `fast_logistic_glmm_cpp` | no R caller (only RcppExports) | no |
| `fast_hurdle_poisson_glmm_cpp` | `inference_count_KK_cond_poisson.R` | yes, at newton_raphson |
| `fast_coxph_regression_cpp`, stratified | classes (`inference_survival_coxph.R`, `_strat_cox.R`, KK lwa) fall back to `survival::coxph` hardened fit (`.fit_survival_coxph_kernel`), no NA | yes (NR, `smart_cold_start` FALSE) |
| `fast_coxph_regression()` R wrapper (lbfgs, maxit 20) | `stop("Cox PH regression (Rcpp) failed to converge.")` | exported only; no internal caller |
| DepCens | `dep_cens_fit_retry()` ladder (cold zero start, then rho-pinned) and R `optim` fallback; non-estimate-only returns NULL after cold retry | yes |
| Clayton | tries 3 starts, keeps converged ones, else R `optim(BFGS)` | yes (GLMM Weibull loggamma, KK helper) |
| Weibull / NB / ordinal / beta / ZIP / ZINB / logistic LBFGS | `.fit` helpers retry cold (e.g. `inference_survival_weibull.R` ~L7-20) or NA | NB and ordinal PropOdds default to lbfgs, so reachable; 0 FALSE in 1,000+ fits |

### Does the Hessian-scaled rule rescue the false cases?

Computed offline from the wrappers' `gradient_norm` and `fisher_information` (largest absolute eigenvalue), rule =
`gnorm < min(1e-4, 10 * tol * max(1, lambda_max))`.
- Newton-side GLMM/LMM FALSE_NC: **15/15 accepted** (Poisson GLMM 4/4, ratio <= 0.013; LMM 11/11, ratio <= 0.019).
  Because these kernels reach the loop through `optimize_fixed_likelihood`, the single C++ patch in the plan above
  covers Poisson GLMM, Gaussian LMM, hurdle GLMM and the logistic/ordinal GLMM variants when run at
  `newton_raphson`; nothing GLMM-specific is needed.
- True failures it must not accept: Cox LBFGS true failures 0/34 accepted (ratio >= 2.7e4), the Cox NR
  `converged = TRUE`-at-divergence case has gnorm 2 and ratio 1e7; no GLMM/LMM true failure exists in this sample,
  so the 0/39 rejection evidence still comes from the first survey.
- Cox NR (own loop `cox_newton_raphson`, objective-based `|dll| < tol`, no stalled-state exit): the rule would accept
  6/6 (ratio <= 0.83) if applied at the `maxit` exit, but raising `maxit` (20 -> 50 or 100) fixes the same 6 with no
  new logic.
- Cox LBFGS cap hits with a good loglik (95): the rule accepts only 7 (ratios 3-5e5): these are budget cases,
  not stalls; the right fix is a larger `maxit` in the wrapper, not an acceptance rule.
- ZINB does not return `gradient_norm`; hurdle-NB returns no objective value; the CLMM kernel returns no
  information matrix, so for CLMM the ratio cannot be computed (not needed: 0 non-converged). Fix by exposing them
  only if those kernels get a stall rule.

### Recommendation

1. Apply the existing `newton_stalled_at_optimum` patch as planned; it covers the GLMM/LMM Newton stalls (default-
   reachable for the Poisson KK GLMM, 2-5% of fits at n >= 100). Add the LMM (n = 200, 17%) and Poisson GLMM
   stall cases to the verification list (simulation scripts above; `run_glmm.R pois|lmm 30 40,100,200 newton_raphson`).
2. No LBFGS-side acceptance rule is warranted; do not widen `optimize_likelihood_lbfgs`. If anything, its
   `niter < maxit` clause is too lenient (column D, CLMM eps 1e-3); consider reporting the gradient ratio
   instead of changing the flag.
3. Cox: raise the C++ default `maxit` from 20 (and the wrapper's) so the 6 NR and ~129 LBFGS cap exits go away; fix the
   `cox_newton_raphson` loop to reject non-decreasing candidates (it assigns `beta = beta_candidate` unconditionally,
   so one DGP-2 fit diverged to bT = 166 and still reported `converged = TRUE`).
4. DepCens/Clayton: the proper C++ fix already in TODO-111 (zero the clamped-coordinate gradient/Hessian) is
   what removes the 19% / 5% NaN; no stall rule helps because the value is NaN.
5. CLMM is the only NA-on-failure kernel; it showed no failures, so no action beyond optionally falling back like
   the Poisson/Gaussian GLMM classes do.
6. Not covered: weighted/prebuilt/clustered Cox entry points (same optimizer), `fast_clogit_plus_glmm_cpp`, the
   ordinal/Weibull-frailty GLMMs, stereotype, hurdle-NB (no objective value exposed), quantile/robust (no
   `optimize_likelihood` use: robust is its own IRLS loop, no quantile kernel in `src`).

### CLMM tolerance (2026-10-22, follow-up to Survey 2)

Where set: `R/EDI/R/inference_ordinal_KK_clmm_abstract.R`, both `fast_ordinal_clmm_cpp` call sites (`shared_rcpp`, the
observed/full fit; `compute_ri_estimate_rcpp`, the cold-start randomization refit) hard-coded `eps_g = 1e-3`. No
rationale exists in the repo: `git log -S` only reaches the initial commit, benchmark files have no CLMM tolerance
note; only `algorithm_choice_audit_catalog.md` (L1829, L1922, L2781) flags it as loose and records one fixture where it
costs accuracy (0.6175 at 1e-3 vs 0.5835 at 1e-6, `clmm` 0.5827 on the sigma-collapse fixture). Every other GLMM/LMM R
caller already uses 1e-6 (`inference_continuous_KK_glmm.R` L303/359/433/469/482 for the Gaussian LMM; kernel
defaults 1e-6 for the Poisson, logistic, hurdle and ordinal GLMMs; `fast_clogit_plus_glmm_cpp` 1e-5), so the CLMM is
the only loosened class site; the logistic GLMM has no R caller. Not changed for those families (report only).

Simulation (`$TMPDIR/tclmm/sim.R`, installed kernel, class warm start = fixed-effects ordinal fit + log sigma 0; KK-like
design: 30% pairs, rest singletons, 50% treated, true effect 0.5, sigma_b 0.8, K = 4, 20 seeds per n, reference
`ordinal::clmm(nAGQ = 20)`; the installed kernel returns no `params`, so the two-stage start was rebuilt from
`c(alpha, b, log_sigma)`). One n = 40 seed is a (quasi-)separated fit (clmm 26.5, SE 0.0016) and dominates the max
column; medians exclude its effect.

| n | median abs treatment err vs clmm: 1e-3 / 1e-6 / 1e-3 then polish 1e-6 | median abs SE err vs clmm SE: 1e-3 / 1e-6 | time vs 1e-6 alone: 1e-3 / two-stage |
|---|---|---|---|
| 40 | 4.5e-3 / 2.1e-4 / 1.2e-4 | 8.4e-3 / 5.7e-5 | 0.50x / 1.7x |
| 100 | 3.0e-2 / 8.5e-4 / 1.8e-4 | 3.4e-3 / 4.6e-5 | 0.53x / 1.8x |
| 200 | 2.8e-2 / 5.4e-4 / 1.4e-4 | 2.6e-3 / 2.5e-5 | 0.53x / 1.8x |

Max error (non-separated cells) at 1e-3: 0.078 (n = 100), 0.073 (n = 200); at 1e-6: 3.6e-3, 2.3e-3. `converged = TRUE` in all
fits at both tolerances. The tight tolerance costs ~2x kernel time (fits are ~10 ms), so a two-stage polish is no
cheaper than going straight to 1e-6 and was not adopted.

Change (R only, no C++): new private field `clmm_eps_g = 1e-6` on the CLMM abstract class, used at both call sites;
subclasses can override it. Observed fit and randomization refits therefore stay consistent. Bootstrap refits: the Bayesian-
bootstrap weighted refit (`compute_weighted_clmm_estimate` -> `weighted_ordinal_random_intercept_fit`, TODO-76) calls
`ordinal::clmm` with its own optimizer, no `eps_g`, so it is unaffected (parity tests unchanged); non-Bayesian bootstrap
resamples go through `shared_rcpp` and now use 1e-6. Estimates move: class results at the old default were off the
maximum by up to ~0.04 log-odds on the test fixtures (seed 303: 3.8e-2 -> 1.0e-4; seed 305: 3.2e-2 -> 5.2e-4; seed 302:
5.9e-3 -> 2.7e-4). New test `package_tests/testthat_bulk/test-ordinal-kk-clmm-gradient-tolerance-matches-clmm.R` (class
within 2e-3 of clmm; fails before, passes after). Open: the `converged` flag itself is still lenient for all LBFGS
kernels (Survey 2 item 2); GLMM logistic near-separation and LMM D-cells unchanged.
