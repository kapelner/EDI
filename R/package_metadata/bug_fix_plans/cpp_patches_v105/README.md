# v1.0.5 C++ remainders (G1): reviewable patch bundle

**STATUS: ALL PATCHES ARE UNCOMPILED AND UNTESTED.** Written 2026-10-22 by an agent that
may not run a compiler (project `CLAUDE.md`). Syntax was checked by reading only.
Each patch was generated with `diff -u` against the working-tree file and verified with
`git apply --check --directory=. <patch>` (applicability only; nothing compiled).
`R/EDI/src` was byte-identical before and after (`git status --porcelain R/EDI/src` empty,
md5 of every touched file unchanged). Source plan: the section "C++ remainders gated on a
user build (G1)" at the end of `../../future_release_plans/release_v1_0_5.md`, plus
`../optimize_likelihood_newton_false_nonconvergence.md`.

Apply from the repo root, e.g. `git apply --directory=. R/package_metadata/bug_fix_plans/cpp_patches_v105/01-newton-stall.patch`
(or `git apply --check ...` first). Patches 05 and 10 both touch `fast_survival_stats.cpp`,
and 08 and 10 both touch `fast_coxph_regression.cpp`, in distant hunks; applying them in
sequence was checked with `patch` on scratch copies and works.

## Compile / relink pattern (user's own tooling decides)

Per `CLAUDE.md` and memory `feedback_targeted_compile_only`: never a full build. For each
touched `.cpp` only: `EDI_UNITY=0`, reuse the flags from `R/EDI/src/Makevars` (`R CMD SHLIB`-style
single-object compile of that file, `-fopenmp` etc. as in Makevars), relink `EDI.so` from the
touched `.o` + the already-existing `.o` files, then `pkgload::load_all(".", compile = FALSE)`.
Header-only change (patch 01 touches `_helper_functions_core.h`, included by ~100 `.cpp`):
every `.cpp` that instantiates `optimize_likelihood_newton` must be recompiled, so this is
the one patch for which a targeted compile is not small (users: your build tooling decides;
the smallest verifying set is the files that call `optimize_fixed_likelihood` / `optimize_likelihood_newton_then_lbfgs`:
`fast_zero_augmented_poisson.cpp`, `fast_poisson_glmm.cpp`, `fast_weibull_regression.cpp`,
`fast_negbin_regression.cpp`, `fast_beta_regression.cpp`, `fast_gaussian_lmm.cpp`, ordinal kernels).
NOTE: stale per-file `.o` objects sit next to `unity_NN.o` from the user's unity builds, and a unity
install leaves no per-file objects; if the needed `.o` files are missing, STOP and ask (do not build
them). Patches 04 (and 05) change an exported signature: after the `.cpp` edit run
`Rcpp::compileAttributes()` (user's tooling) so `src/RcppExports.cpp` and `R/RcppExports.R` regenerate.
Rd for those functions needs `roxygenize` afterwards (not hand-edited here).

## Index

| # | File | TODO | Files touched |
|---|---|---|---|
| 01 | `01-newton-stall.patch` | 123 | `_helper_functions_core.h` |
| 02 | `02-dep-cens-clamped-gradient.patch` | 111 (4th pass) | `fast_survival_models_optim.cpp` |
| 03 | `03-clayton-stable-logA.patch` | 121 (3rd batch) | `fast_survival_models_optim.cpp` |
| 04 | `04-negbin-eps-g.patch` (+ `04b-...REFERENCE-ONLY.patch`) | 116 | `fast_negbin_regression.cpp` (+ generated `R/RcppExports.R`) |
| 05 | `05-rmst-tau.patch` | 108 | `fast_survival_stats.cpp` |
| 06 | `06-ridit-delong-se.patch` | 106 | `fast_ridit_analysis.cpp`, `python/cpp/bindings_ordinal.cpp`, `python/src/edi_kernels/_core.pyi` |
| 07 | `07-zinb-pseudo-inverse.patch` | 4 (ZINB note) | `fast_zinb.cpp` |
| 08 | `08-cox-newton-descent-guard.patch` (+ `08b-...REFERENCE-ONLY.patch`) | 123 Survey 2 | `fast_coxph_regression.cpp` (+ generated `R/RcppExports.R`) |
| 09 | `09-poisson-glmm-hessian-comment.patch` | 121 | `fast_poisson_glmm.cpp` (comment only) |
| 10 | `10-noise-mat-empty-survival-kernels.patch` | coordinator add-on | `fast_survival_stats.cpp`, `fast_logrank.cpp`, `fast_coxph_regression.cpp`, `fast_weibull_regression.cpp` |
| 11 | `11-noise-mat-empty-other-kernels.patch` | coordinator add-on (optional) | `rand_bootstrap_ols_parallel.cpp`, `rand_bootstrap_mean_diff_parallel.cpp`, `fast_wilcox_hl.cpp`, `fast_robust_regression.cpp` |
| 12 | `12-ordinal-scale-aware-convergence.patch` | 107 | NEW `ordinal_scale_guard.h`; `fast_ordinal_regression.cpp`, `fast_ordinal_cauchit_regression.cpp`, `fast_ordinal_cloglog_regression.cpp`, `fast_ordinal_probit_regression.cpp`, `fast_adjacent_category_logit.cpp`, `fast_continuation_ratio_regression.cpp` |
| 13 | WITHDRAWN (patch file deleted) | 118 | the kernel `generate_permutations_blocking_cpp` was deleted instead (owner decision 2026-10-22) |
| 14 | `14-log-binomial-active-set-step.patch` | 128 | `fast_log_binomial_regression.cpp` |
| 15 | `15-robust-regression-nonfinite-input.patch` (written 2026-10-23) | 131 | `fast_robust_regression.cpp` |
| 08c | `08c-cox-neg-ll-backward-sum.patch` (G1 post-build follow-up, 2026-10-23; apply after 08) | 123 Survey 2 | `fast_coxph_regression.cpp` (`compute_cox_neg_ll_only()` sums the risk set backwards; without it patch 08's descent guard never fires) |
| 12b | `12b-ordinal-scale-guard-skip-binary.patch` (G1 post-build fix, 2026-10-23; apply after 12) | 107 | `ordinal_scale_guard.h` (skip 0/1 columns), `fast_continuation_ratio_regression.cpp` (check subject-level `X`); recompile all 6 ordinal `.cpp` (R's `make` does not track header dependencies: `touch` the 5 ordinal `.cpp` files that only include the header, or they keep the old guard; this happened on the first 12b rebuild, 2026-10-23). Fixes a release-blocking patch-12 regression: >50% treated made ordinary fits report not converged |
| 02b | `deferred_v110/02b-depcens-clamp-boundary-refit.patch` | 111 | NOT for v1.0.5 (owner 2026-10-23): `release_v1_1_0.md → TODO-156` |

`*.REFERENCE-ONLY.patch` show what `compileAttributes()` should produce for `R/RcppExports.R`;
do NOT apply them; regenerate instead (they exist so the regeneration can be diffed).
`src/RcppExports.cpp` carries no default arguments, so patch 04 changes nothing there.
TODO-57/3 are NOT in this bundle (not requested; TODO-107 is patch 12; patch 13 for TODO-118 was withdrawn, see below); the CLMM
`eps_g` change was R-only (`clmm_eps_g`), so no C++ patch is needed.

## Owner-approved for G1 (decided 2026-10-22; "accept all" on `release_v1_0_5.md → G6`)

**Approval status:**

| Patch | Decision | Condition |
|---|---|---|
| 04 | G6 #40 (c) | apply with its listed tests (see note 04). Only the default in `fast_neg_bin_cpp`/`_with_var_cpp` changes; #40 (a)(b) are deferred to `release_v1_1_0.md → TODO-67` |
| 07 | G6 #26 | ONLY together with companions B07 and B07b, and only after the TODO-4 guard-test review in step 1 below. If that review finds a test the pseudo-inverse legitimately breaks beyond what B07b updates, stop and skip 07 + B07b (B07 alone is harmless: it is inert without the tag) |
| 08 | G6 #16 | apply. The BRT Cox kernel's literal `20` (~L1220) is NOT changed |
| 10 + 11 | G6 #27 | apply 11 together with 10 |
| 14 | G6 #46 (owner, 2026-10-22) | apply, with the KKT convergence gate folded in (note 14). Expected: some hard boundary log-binomial fits now report non-convergence |

Not owner-gated (each is already in its TODO's scope, G1 only): 01 (TODO-123), 02 (TODO-111), 03 (TODO-121), 05 (TODO-108,
with A05), 06 (TODO-106, with C06; the Python `.postN` release is approved by G6 #28, but push/tag need their own go-ahead),
09 (TODO-121, comment only), 12 (TODO-107), 15 (TODO-131; added 2026-10-23). 13 is withdrawn. Never apply `04b`/`08b` (REFERENCE-ONLY).

**Exact apply order** (from the repo root; run `git apply --check --directory=. <file>` immediately before each apply,
because the R tree changes under other agents):

1. Review the TODO-4 guard tests (G6 #26 precondition) before anything else. Do this by reading, plus running them on the
   unpatched build: `test-information-inverse-guard.R`, `test-information-inverse-inference-typed-guards.R`,
   `test-information-inverse-edge-cases.R`, `test-zinb-zero-inflation-boundary.R`, `test-zinb-zi-block-unidentified-count-se.R`.
   Record which assertions patch 07 changes. Only `test-information-inverse-guard.R` L125-129 is expected (B07b).
2. `companions/B07-zinb-safe-vcov-subblock.patch` (R only; safe before the kernel).
3. C++ patches, in this order: `01`, `02`, `03`, `04`, `05`, `06`, `07`, `08`, `09`, `10`, `11`, `12`, `14`, `15`.
   - 02/03 share `fast_survival_models_optim.cpp`. 05/10 share `fast_survival_stats.cpp`. 08/10 share
     `fast_coxph_regression.cpp`. 11/15 share `fast_robust_regression.cpp` (distant hunks; either order composes, see
     note 15).
   - Verified 2026-10-22 (check only, nothing applied): one `git apply --check --directory=.` with all thirteen files in
     this order passed against the working tree.
   - Re-verified 2026-10-23 with 15 appended (check only, nothing applied): one `git apply --check --directory=.` with
     all fourteen files (01-12, 14, 15) in this order passed, and so did the same call with
     `companions/B07-zinb-safe-vcov-subblock.patch` prepended (step 2 then step 3).
4. Targeted compile (`EDI_UNITY=0`) of every touched `.cpp`, then relink, as in "Compile / relink pattern". Patch 01 is a
   header change: recompile every file that instantiates `optimize_likelihood_newton`. Patch 12 adds `ordinal_scale_guard.h`
   plus 6 `.cpp`. If the per-file `.o` files are missing, STOP and ask.
5. `Rcpp::compileAttributes()`. Patches 04, 05 and 08 change exported formals/defaults. Diff the regenerated
   `R/RcppExports.R` against `04b`/`08b`; do not apply those two.
6. R/Python companions: `companions/A05-rmst-tau-R-callsite.patch`, `companions/B07b-zinb-guard-test-update.patch`,
   `companions/C06-ridit-delong-se-test-constants.patch`.
7. Copy the six companion tests into `R/EDI/tests/testthat/`:
   - `test-newton-stall-false-nonconvergence.R`
   - `test-depcens-clayton-kernel-numerics.R`
   - `test-rmst-tau-fast-kernel.R`
   - `test-ridit-kernel-se-equals-delong.R`
   - `test-zinb-pseudo-inverse-identified-coordinates.R`
   - `test-cox-newton-descent-guard.R`
8. Run them with `EDI_REQUIRE_CPP_PATCHES=true`, plus each patch's "Verify" list below. That includes patch 04's NegBin
   tests, 10/11's per-kernel BRT tests plus a new `matrix(0, 0, 0)` noise test, 14's
   `test-log-binomial-jackknife-history-independence.R`, and 15's robust-regression list (note 15).
9. Because 04/05/08 change exported signatures, re-run G8 (roxygen) and G9 (drift CSVs) afterwards, as
   `release_v1_0_5.md`'s dependency diagram requires.

## Per-patch notes

### 01 newton-stall (TODO-123)
- Purpose: add `newton_stalled_at_optimum()` (Hessian-scaled rule `gnorm < min(1e-4, 10*tol*max(1, lambda_max(H)))`),
  set `stalled = true` on the line-search-failure exit, and accept both exits per the plan
  (step-size exit: `|| newton_stalled_at_optimum`; fall-through: `|| (stalled && ...)`). Singular-Hessian and non-finite exits unchanged.
- Risk: touches every Newton-based kernel (ZIP, hurdle, Poisson, Weibull, beta, NB, ordinal, GLMM/LMM at `newton_raphson`).
  Fits already converged are untouched (rule only runs on previously unconverged exits), so `converged = TRUE`
  results should be bit-identical; previously-`FALSE` false failures flip to `TRUE`. The extra Hessian evaluation costs
  one `hessian()` call per unconverged fit. The eigen-solver needs `<Eigen/Eigenvalues>`, which `<Eigen/Dense>` already includes.
  The gradient is recomputed at the post-step point in the step-size exit (already in the code); for the fall-through
  `last_grad_norm` and `params` refer to the same point when `stalled` (params not updated on that exit).
- Verify: expected 179/179 false cases converge and 39/39 true failures stay failures; re-run
  `/tmp/claude-1000/tnewton_before/sim2.R` (and `sim.R`, `wb2.R`, `zoib.R`, `rule.R` for the rule check; patch text in
  `/tmp/claude-1000/tnewton_before/newton_patch.txt`), and `/tmp/claude-1000/tsurvey2/run_glmm.R pois|lmm 30 40,100,200 newton_raphson`
  (Poisson GLMM / LMM stall cases). KK21 helper: `/tmp/claude-1000/tkk21w/sim.R` (expect `step_same = 1`, `n_uni_diff = 0`).
  Tests to run: `test-zip-newton-stall-cold-retry.R`, `test-zinb-zero-inflation-boundary.R`, `test-negbin-weighted.R`,
  `test-kernel-warm-start-length-contracts.R`, `test-rcpp-fitting-equivalence.R`, `test-rcpp-fitting-real-data.R`,
  `test-hurdle-poisson-glmm-buffer-reuse.R`, `test-poisson-glmm-buffer-reuse.R`. Add the regression test described in the plan
  (modelled on `test-zip-newton-stall-cold-retry.R`, seeds 6 and 19, n = 100).

### 02 dep-cens-clamped-gradient (TODO-111 fourth pass)
- Purpose: `if (|params[2p+2]| >= 3) grad[2p+2] = 0` after the gradient is assembled in `DepCensTransformLikelihood::operator()`.
  `hessian()` is a finite difference of the gradient (its second, analytic block is unreachable dead code), so the
  matching row/column zero out automatically; no Hessian edit needed.
- Risk: the zeroed row/column makes the Hessian singular when the iterate sits on the boundary; this only matters if
  DepCens is run with Newton (policy default is Newton per Survey 2 table, `optimization_alg`): the Newton step then breaks on the
  singular Hessian and falls to LBFGS. Interior fits (the common case) are bit-identical. At exactly `|x| == 3` the one-sided
  derivative is discarded (flat from the clamp side).
- Verify: `test-dep-cens-transform-rho-boundary-retry.R` (R retry stays a safety net), `test-dep-cens-transform-fast-pnorm.R`,
  `test-dep-cens-bootstrap-default-B.R`; `/tmp/claude-1000/tsurvey2/run_surv.R` (expect the 68/360 NaN/throw fits, 19%, to converge
  without the R retry; look at `dc_ref.R`).

### 03 clayton-stable-logA (TODO-121 third batch)
- Purpose: in `log_sum_exp_clayton` (called by `ClaytonWeibullLikelihood`) use `log1p(expm1(a) + expm1(b))`.
  Gated to `max(a, b, 0) <= 1` (guard `s > -1`) so that all fits with larger `theta*h` keep the original formula exactly;
  the cancellation error only matters for small `theta*h`. This differs slightly from "always use log1p" to preserve bit-identity.
- Risk: fits with theta*h <= 1 change at the ulp level (not bit-identical) and in the theta->0 limit become exact. The gradient
  terms `logA / theta^2 - dA_d_theta_over_A / theta` still cancel as theta -> 0 (not addressed; a bound on log-theta below, as
  the plan allows, would be the follow-up). The R floor `.CLAYTON_LOG_THETA_NULL_FLOOR` should stay until verified.
- Verify: `test-clayton-logtheta-optimizer-bound.R`, `test-weibull-frailty-loggamma-null-boundary.R`; the failing fixture
  (all-matched `~x1`, n = 40, seed 2: null profile should now be finite beyond log-theta -12) and the gsd = 0 seed-2 full fit
  at log-theta -14.9; `/tmp/claude-1000/tsurvey2/run_surv.R` Clayton cell (3/60 NaN at n = 40).

### 04 negbin-eps-g (TODO-116)
- Purpose: default `eps_g` 1e-6 -> 1e-10 in `fast_neg_bin_cpp` and `fast_neg_bin_with_var_cpp` (the R class already passes 1e-10).
  `fast_neg_bin_weighted_cpp` and `fast_neg_bin_internal`'s defaults are deliberately NOT changed (not requested).
- Regeneration: after applying, run `Rcpp::compileAttributes()`; `R/RcppExports.R` defaults then change to `eps_g = 1e-10`
  (see `04b-...REFERENCE-ONLY.patch`), `src/RcppExports.cpp` is unchanged. Rd `\usage` regenerates via roxygen.
- Risk: only direct callers that relied on the default see tighter (slower) fits; the R class is unaffected.
- Verify: `test-unsupported-procedure-stubs-and-negbin-mle.R`, `test-negbin-weighted.R`, `test-negbin-std-lgamma-likelihoods.R`,
  `test-negbin-distinct-y-hessian.R`, `test-negbin-gemv-gradient.R`, `test-kernel-warm-start-length-contracts.R`.

### 05 rmst-tau (TODO-108)
- Purpose: `compute_survival_stat_diff_rand_bootstrap_parallel_cpp(..., int num_cores, double rmst_tau = NA_REAL)`; the shared
  horizon becomes `min(min arm max, rmst_tau)`; `km_stat_inline` already takes `rmst_tau`. A non-positive finite tau stops.
  New parameter is LAST with an NA default, so existing 8-argument R call sites keep working.
- Regeneration: `compileAttributes()` regenerates `RcppExports.cpp`/`.R` (the `NA_REAL` default should render as `NA_real_`; if
  your Rcpp version does not translate it, use `Rcpp::Nullable<double>`/`R_NaReal` instead). Rd regeneration needed.
- Required R follow-up (not done here, R is being edited by others): in `R/EDI/R/inference_survival_rmst.R` ~L244 remove
  `if (!is.null(private$rmst_tau)) return(NULL)` and pass `if (is.null(private$rmst_tau)) NA_real_ else private$rmst_tau` as the last argument.
- Risk: equivalence relies on right-truncation at tau being equal to RMST-to-tau on the shared KM curve (true for KM area before tau).
- Verify: `test-rmst-user-settable-tau.R` (compare fast kernel vs the generic loop for a user tau), `test-brt-smoothed-survival-stat-diff-kernel.R`.

### 06 ridit-delong-se (TODO-106)
- Purpose: `fast_ridit_analysis_result()` `se` becomes the DeLong SE, a port of `ridit_delong_se()` in
  `R/EDI/R/inference_ordinal_ridit.R` (scores under the opposite reference are the CDF midranks; sample variances n-1;
  pooled scaled by n_C/N; NA if an arm is empty, 0 if an arm has one subject). The reference's own scores are reused,
  the other arm's reference scores are computed with `fast_ridit_scores_from_ref_indices`. Python binding struct is unchanged
  (the field `se` simply changes value); the patch updates the binding docstring and `_core.pyi`.
- Python follow-ups NOT in the patch: `python/tests/test_fast_ridit_analysis.py` pins the old SE (`R_SE = 0.0487...` and
  `expected_se` in `test_estimate_orientation_...`), they must be recomputed (e.g. from `ridit_delong_se`); a
  `python/CHANGELOG.md` entry and the `.postN` rule apply (memory `feedback_python_package_release_workflow`).
- Risk: every consumer of `$se` from this kernel moves (R class already overrides it, so R results are unchanged).
- Verify: `test-ordinal-ridit-delong-se.R` plus a new assertion `fast_ridit_analysis_cpp(w, y, ref)$se` equals `ridit_delong_se(y, w, ref)`
  for control/treatment/pooled; Python `test_fast_ridit_analysis.py` after updating constants.

### 07 zinb-pseudo-inverse (TODO-4 ZINB note)
- Purpose: when `invert_free_information()` reports the free ZINB information block singular, return a covariance from the
  symmetric pseudo-inverse (eigenvalues <= 1e-10 * max dropped) in `fast_zinb_with_var_internal` (:801) and `fast_zinb_cpp` (:916).
  Coordinates that load on the null eigenvectors (squared loading > 1e-6) get NaN rows/columns, so a duplicated/aliased column stays
  non-estimable, while the identified count block gets pscl's SE (0.4818, 0.2881 on the TODO-111 fixture). `information_invertible`
  stays FALSE; the R path also sets `covariance_type = "pseudo_inverse_identified_coordinates"`.
- Required R follow-up: `safe_zero_augmented_vcov_se()` (`inference_count_zero_augmented_poisson_abstract.R` ~L366-395) rescues only if
  `all(is.finite(vc))` and `zero_augmented_fit_is_degenerate()` rejects any non-finite vcov; it must test finiteness/conditioning of the
  count (+theta) sub-block `vc[idx, idx]` instead of the full matrix, otherwise the new NaN rows in the zi block keep the SE at NA.
- Risk (highest design risk in the bundle): the threshold 1e-6 on null loading is a judgment call; it changes `vcov` from all-NaN to partly
  finite for singular fits, which the TODO-4 guard tests may assert against. Specify exactly as in the TODO note only for the zero-inflated
  Hessian block; ZIP/hurdle sites (`fast_zero_augmented_poisson.cpp`) are not covered.
- Verify: `test-zinb-zi-block-unidentified-count-se.R`, `test-information-inverse-guard.R`, `test-information-inverse-edge-cases.R`,
  `test-information-inverse-inference-typed-guards.R`, `test-zinb-zero-inflation-boundary.R`; check a duplicated count column still gives NA SE
  and the zi-collinear fixture gives the pscl SE.

### 08 cox-newton-descent-guard (Survey 2)
- Purpose: (a) in `cox_newton_raphson`, after step halving, `if (!(ll_candidate < ll + tol)) break;` instead of the unconditional
  `beta = beta_candidate` (a candidate within `tol` is still accepted, so fits at the optimum follow their previous path; a clearly
  worse or non-finite candidate stops at the current beta with `converged = FALSE`, `neg_ll` still belonging to that beta);
  (b) `maxit` default 20 -> 100 in the five defaults (`fast_coxph_regression_internal`, `fast_stratified_coxph_regression_internal`,
  `fast_coxph_regression_prebuilt_cpp`, `fast_coxph_regression_cpp`, `fast_stratified_coxph_regression_cpp`). The literal `20` in the
  BRT Cox kernel (~L1220, tol 1e-6) is left as is; changing it alters bootstrap NA rates (separate decision). The exported R wrapper
  `fast_coxph_regression()` (`helper_glm_fit.R`) states `maxit = 20` in its roxygen; update docs. `RcppExports.R` defaults regenerate (`08b` reference).
- Risk: raising `maxit` changes only fits that previously hit the cap (survey: 6 NR and 129 LBFGS cap exits all converge at 100);
  LBFGS fits take more iterations before giving up. The guard should only trigger on the diverged case (1/720 NR fits, bT = 166).
- Verify: `test-coxph-robust-vcov.R`, `test-coxph-hessian-symmetric-writes.R`, `test-cox-risk-set-cache-invalidation.R`,
  `test-strat-cox-matched-design-todo110.R`, `test-brt-smoothed-coxph-kernel.R`; `/tmp/claude-1000/tsurvey2/run_cox.R`, `cox_nr_maxit.R`, `cox_maxit.R`, `coxdata.R`
  (expect Cox NR FALSE_NC 6 -> 0 at default maxit and no converged-at-divergence fit).

### 09 poisson-glmm-hessian-comment (TODO-121)
- Comment only above `get_poisson_glmm_hessian_cpp`; the returned value `-obj.hessian(par)` (Hessian of the log-likelihood) is untouched
  because `inference_count_KK_combined.R` ~L484/488 negates it. No compile risk beyond the build. Verify: none needed beyond compiling.

### 10 / 11 noise_mat empty-matrix hardening (coordinator add-on)
- Bug: `Rcpp::Nullable<NumericMatrix>::isNotNull()` is TRUE for an empty `matrix(0, 0, 0)`, so `noise_ptr[b*n+i]` read out of bounds.
  Patch: build the matrix, then `has_noise = noise_m.size() > 0`, `noise_ptr = has_noise ? noise_m.begin() : nullptr`.
- grep of `isNotNull` over `R/EDI/src/*.cpp` found this identical `noise_mat` pattern in 8 kernels. Patch 10 (same survival family as the
  reported kernel): `fast_survival_stats.cpp` (the reported one), `fast_logrank.cpp`, `fast_coxph_regression.cpp`, `fast_weibull_regression.cpp`.
  Patch 11 (optional, same pattern, other families): `rand_bootstrap_ols_parallel.cpp`, `rand_bootstrap_mean_diff_parallel.cpp`,
  `fast_wilcox_hl.cpp`, `fast_robust_regression.cpp`.
- Other `isNotNull()` uses are not the same pattern (not patched): `design_fixed_greedy.cpp:56` (`indicies_pairs`, a mode switch),
  `fast_gaussian_lmm.cpp:587` (`weights`), `fast_coxph_regression.cpp:879` (`cluster`). They could misbehave on a zero-length argument
  from R but were not analysed.
- Risk: none for NULL/non-empty input (identical behaviour). Verify: `test-brt-smoothed-noise-mat-plumbing.R` and the per-kernel
  `test-brt-smoothed-{survival-stat-diff,logrank,coxph,weibull,ols,mean-diff,wilcox,robust-regr}-kernel.R`; add a test passing `matrix(0, 0, 0)`.

### 15 robust-regression-nonfinite-input (TODO-131), written 2026-10-23, UNCOMPILED
- Not owner-gated beyond G1 (in TODO-131's scope). The user applies and builds it; agents do not compile.
- Purpose: `fast_robust_regression_internal()` ran its IRLS on non-finite `X`/`y` and returned a 0 coefficient, which
  callers could not tell from a real estimate (TODO-18 cell C1: `NA` KK pair differences from the stale `FixedBinaryMatch`
  replay pairing gave an identically 0 BRT null). The R callers now pre-check (R-side guards, 2026-10-23); this patch makes
  the kernel itself refuse such input.
- Change: (1) `fast_robust_regression_internal()` throws `std::invalid_argument` when `X` or `y` has a non-finite entry
  (exported `fast_robust_regression_cpp()` turns it into an R error, which every R caller already catches with `tryCatch`
  -> `NULL` -> nonestimable; the Python binding in `python/cpp/bindings_continuous.cpp` gets a `ValueError`). (2)
  `compute_robust_rand_bootstrap_parallel_cpp()` checks each draw's assembled `X_b`/`y_b` before calling the core and skips
  a non-finite draw (result stays `NA`), because an exception must not escape the OpenMP region.
- Finite input is bit-identical (the check only reads). No exported signature change, so no `compileAttributes()`; only
  `fast_robust_regression.cpp` recompiles. Composes with patch 11 (same file, distant hunks) in either order: checked with
  `patch` on scratch copies.
- Verify (after user compile, `EDI_UNITY=0`): `R/package_tests/testthat_bulk/test-robust-regression-nonfinite-input-nonestimable.R`
  (R-side guards; must still pass), `test-brt-matched-pair-replay-uses-resampled-pairs.R`, the robust kernel tests
  (`R/EDI/tests/testthat/test-kk-robust-regr-use-rcpp.R`, `test-robust-regression-mad.R`, `test-robust-regression-xtx-cache.R`,
  `test-brt-smoothed-robust-regr-kernel.R`), and by hand `fast_robust_regression_cpp(cbind(1, c(0, 1, 0, 1)), c(1, NA, 2, 3))`
  must error instead of returning a coefficient.

## Not written
None of the nine requested patches was skipped. Not in scope / not written: TODO-107 (six-kernel scale-aware convergence), TODO-118, TODO-57, TODO-3,
and an R-side companion for 05 and 07 (described above, R files are being edited concurrently).

## Companion changes (written 2026-10-22; in `companions/`)

Everything here is NOT applied and NOT in the live test directory. The diffs were generated against the
working-tree contents of 2026-10-22 while other agents were editing R files: **re-run `git apply --check`
immediately before applying each one** (from the repo root, e.g.
`git apply --check R/package_metadata/bug_fix_plans/cpp_patches_v105/companions/A05-rmst-tau-R-callsite.patch`).
All five diffs passed `git apply --check` when written; every `.R` test parses; every probe-gated test was run
against the CURRENT (unpatched) installed EDI with `NOT_CRAN=true` and skips (or, for true-failure assertions, passes) as designed.
Nothing was run against a patched build, so every "post-patch" expectation is unverified.

Probe-gated tests skip pre-patch with a message naming the missing patch. Set `EDI_REQUIRE_CPP_PATCHES=true`
once the patches are built: the skips then become failures, so a regression cannot hide behind the probe.
To run a companion test by hand: `NOT_CRAN=true Rscript -e 'testthat::test_file("<path>")'` (tests use `skip_on_cran()`).

| Patch | Companion files (apply order) | What it proves |
|---|---|---|
| 01 newton-stall | `test-newton-stall-false-nonconvergence.R` (after building 01) | (a) ZIP seeds 6/19 n=100 via `fast_zero_augmented_poisson_cpp(..., "newton_raphson", smart_cold_start=TRUE)` converge and equal pscl (count and zero coefs, 1e-3); (b) Poisson n=40 bal seeds 15/16/17 (all false failures pre-patch: gradient 1e-8..1e-7) converge at the `glm` optimum (1e-6) and an already-converged fit equals the IRLS path; (c) Weibull n=40 unbal seeds 2/6 and bal seed 15 (false failures pre-patch) converge with `neg_ll` equal to the LBFGS fit; (d) six ZINB n=40 survey seeds (unbal 14/17/26, nearsep 11/26/30) STILL report `converged = FALSE` (this block passes before and after the patch). Blocks (a)-(c) key on a probe (Poisson n=40 bal seed 17 must report converged) and `skip('Newton stall patch not applied')`. Generators are copied from `/tmp/claude-1000/tnewton_before/sim2.R`. |
| 02 DepCens clamp | `test-depcens-clayton-kernel-numerics.R` (after building 02) | Zero-covariate DepCens, design seed 111, 101 iid resamples fitted through `fast_dep_cens_transform_optim_cpp` directly (estimate_only, cold zero start, no R retry): pre-patch 38/101 fail (measured), post-patch expect <= 2. Probe: >10 failures means skip. **Measured after the build (2026-10-23): 15/101**; the test was relaxed to probe <= 25 / expect <= 20 (owner decision; R retry rescues the rest, 02b deferred to v1.1.0). |
| 03 Clayton stable logA | same file as 02 | Clayton Weibull AFT profile objective (log-theta fixed via `fixed_idx = 3`, `clayton_bound_fixture` seed 918): pre-patch finite to log-theta -18 and NaN at -20 (measured, probe); post-patch finite at -16/-18/-20 with `|v(-20)-v(-18)| < 1e-6`, and the log-theta -6 value unchanged (101.840010784, gated formula leaves large theta*h alone). The `.CLAYTON_LOG_THETA_NULL_FLOOR` R floor stays. |
| 05 rmst-tau | 1) build 05 and run `compileAttributes()`; 2) `git apply companions/A05-rmst-tau-R-callsite.patch`; 3) copy `test-rmst-tau-fast-kernel.R` | A05 changes `compute_fast_rand_bootstrap_distr` in `inference_survival_rmst.R` (there is no `compute_fast_randomization_distr` in that file; RMST rand CIs are refused): it passes `rmst_tau` as the last argument when the formal exists (`"rmst_tau" %in% names(formals(kernel))`, evaluated per call) and returns `NULL` (generic loop) for a user tau only when the installed kernel lacks the formal, so an OLD binary keeps today's behavior exactly; unset tau passes `NA_real_` on a new binary. The test (skips if the formal is absent) checks per-replicate kernel output against an independent `survfit` RMST truncated at `min(arm maxima, tau)` for tau 2/5/12, NA tau == the 8-argument call, tau 1e9 == default, non-positive tau errors, and that the class hook returns the kernel result for `tau = 4` (skips if A05 is not applied). The existing generic-loop path is the reference for the class-level comparison only through the kernel, not a full end-to-end BRT run. |
| 06 ridit DeLong SE | 1) build 06; 2) `git apply companions/C06-ridit-delong-se-test-constants.patch`; 3) copy `test-ridit-kernel-se-equals-delong.R` | C06 rewrites the tests that pin the old SE: `python/tests/test_fast_ridit_analysis.py` (`R_SE` 0.0487241695783548 -> 0.086836566958365; the treatment-reference `expected_se` (sd/sqrt(n) of control scores) -> constant 0.086836566958365; new pooled constant 0.0424534327352006 = R_SE * 22/45 plus a new test) and three `r$se` lines in `R/package_tests/testthat_bulk/test-ridit-analysis-and-bootstrap-kernels-reference-groups-and-treatment-reference-degeneracy-reference.R` (fixture `fx()`: control and treatment 0.0597673440656908, pooled 0.0298836720328454). All constants were computed 2026-10-22 with `EDI:::ridit_delong_se()` (comments in the patch say how). Apply C06 only together with the built patch (it would fail the suite before). The new test file asserts kernel `se == ridit_delong_se()` for control/treatment/pooled on `fx()`, the missing-interior-level fixture (0.237992909558247), a one-subject-arm case and 20 random fixtures; it self-skips pre-patch via a numeric probe (pre-patch kernel se is 0.04305201 vs DeLong 0.0597673 on `fx()` control). The R class keeps `ridit_delong_se()`. A `python/CHANGELOG.md` entry and `.postN` bump are still needed (not written). No other test under `R/EDI/tests` or `R/package_tests` pins `fast_ridit_analysis_cpp()$se` (grepped). |
| 07 zinb pseudo-inverse | 1) `git apply companions/B07-zinb-safe-vcov-subblock.patch` (safe to apply BEFORE the kernel: it changes nothing unless `fit$covariance_type` is the tag); 2) build 07; 3) `git apply companions/B07b-zinb-guard-test-update.patch`; 4) copy `test-zinb-pseudo-inverse-identified-coordinates.R` | B07 edits `safe_zero_augmented_vcov_se()`: the rescue branch accepts a vcov that is not all-finite only when `fit$covariance_type` is `"pseudo_inverse_identified_coordinates"` (the tag patch 07 actually emits, and the only place it does so is `fast_zinb_cpp`; `fast_zinb_with_var_internal` emits NO tag, see risks) or `"pseudo_inverse_zero_inflation_unidentified"` (the name suggested in the task, harmless alias); the existing sub-block test `zero_augmented_fit_is_degenerate(vc[idx, idx])` (count coefs + theta for ZINB) then decides, and it already rejects non-finite input, so a duplicated COUNT column still yields NA SE (the aliased pair is inside `idx`). Untagged kernels: condition is the old `all(is.finite(vc))`, bit-identical. B07b updates the only TODO-4 guard test that asserts an all-NaN ZINB vcov: `test-information-inverse-guard.R` L125-129 (`fast_zinb_cpp` with duplicated `x`/`x_duplicate`): untagged keeps `all(is.nan(vcov))`; tagged expects NaN rows/cols 3,4 and a finite remaining block. Other tests checked and left alone: `test-information-inverse-inference-typed-guards.R` L79 (ZINB duplicated count column: the class SE stays NA because the duplicated columns sit in the count sub-block, so this test should still pass; unverified), `test-information-inverse-edge-cases.R` (NB only), `test-zinb-zero-inflation-boundary.R` (boundary path neutering the zi block; information is invertible there, so untouched; re-run), `test-zinb-zi-block-unidentified-count-se.R` (pscl SE equality; re-run). The new test file checks a zero-inflation block with an exactly duplicated column (count/theta SEs equal pscl within 5%, duplicated zi rows NaN), a duplicated count column (NaN rows 3,4), and the untagged/tagged `safe_zero_augmented_vcov_se()` behavior at unit level (skips until B07 is applied). |
| 08 Cox guard | `test-cox-newton-descent-guard.R` (after building 08) | Cold Newton Cox on survey fixture n=40 DGP 2 seed 15 (`cox_data` copied from `/tmp/claude-1000/tsurvey2/run_cox.R`): pre-patch reports `converged = TRUE` with bT = 166.03 (reproduced); post-patch must not report converged with bT off 3.385873 (coxph/LBFGS value) by >1e-3; a DGP-1 fixture keeps its previous path (bT 0.682037781). A second test asserts the `maxit` formal is 100 for both Cox kernels (08b). Probe: skip while the divergent TRUE is reproduced. |
| 14 log-binomial active set + KKT gate | `R/package_tests/testthat_bulk/test-log-binomial-constrained-mle-nloptr-reference-todo128.R` (already in the tree; after building 14) | `InferenceIncidLogBinomial` full-data fits (`~ .`) against an nloptr SLSQP constrained MLE (`X b <= -1e-8`, three starts): interior seed 11 n=200 (runs now: log-lik within 1e-6, coefficients 1e-4) and boundary seeds 20261022/120, 7/200, 20/120 (log-lik within 1e-4, coefficients 1e-3, kernel `converged` and `kkt_converged` TRUE, `n_active_bounds >= 1`). Probe: the `kkt_converged` field; skips pre-patch, fails under `EDI_REQUIRE_CPP_PATCHES=true`. |

Suggested order overall: B07 (R only) -> build the patches you want -> `compileAttributes()` -> the R/Python companion diffs (A05, B07b, C06) ->
copy the five new test files -> run them with `EDI_REQUIRE_CPP_PATCHES=true`. Not covered: patches 04, 09, 10, 11 have no
companion here (10/11 already suggest a `matrix(0, 0, 0)` noise test in their notes).

Known limits / risks of the companions
- Post-patch behavior of every probe-gated test is unverified (no patched build exists). The Clayton `|v(-20)-v(-18)| < 1e-6` threshold and the DepCens `<= 2/101` threshold are estimates; the Clayton gradient cancellation as theta -> 0 is explicitly not fixed by patch 03, so the -20 NaN could survive for another reason.
- Probe-gating hides a regression if a patched build regresses to the pre-patch symptom, hence `EDI_REQUIRE_CPP_PATCHES`.
- Patch 07 as written tags only the `fast_zinb_cpp` path; `fast_zinb_with_var_internal` (the portable sibling) returns the pseudo-inverse with no tag, so B07 will not rescue SEs built from that path (the R class uses `fast_zinb_cpp`). Consider setting `covariance_type` there too.
- Patch 07 changes `fast_zinb_cpp` vcov from all-NaN to partly finite on singular fits; anything in the R layer that tests `all(is.nan(vcov))` or `any(!is.finite(vcov))` on the raw ZINB fit (e.g. likelihood-test information code paths, `zero_augmented_sandwich_se`) was not audited beyond `safe_zero_augmented_vcov_se()`.
- A05 uses `do.call()` with a list of positional arguments plus a named `rmst_tau`; if `compileAttributes()` ever reorders the formals, adapt the call.

### 12 ordinal-scale-aware-convergence (TODO-107), written 2026-10-22, UNCOMPILED
- Purpose: the six ordinal kernels (logit, cauchit, cloglog, probit, adjacent-category, continuation-ratio) can report
  `converged = TRUE` on uncentred covariates while the treatment coefficient is off by many SEs. New header
  `ordinal_scale_guard.h` adds `ordinal_covariates_badly_scaled()` (same rule as R `ordinal_center_scale_plan()`: some
  |mean| > sd or sd outside [0.25, 4]) and `ordinal_newton_decrement_ok()` (affine-invariant g'H^-1 g <= max(1e-6, tol)
  over the free parameters). Each kernel's single fit site downgrades `fit.converged` to FALSE when the covariates are
  badly scaled AND the decrement fails. Params are never modified; well-scaled fits skip the check (bit-identical, no cost).
  Design choice: a post-hoc certificate rather than rescaling inside C++, because it is sign/link-agnostic and 6 small hunks.
  The R wrapper `ordinal_fit_scaled()` stays as the actual fixer; this makes the raw kernels honest (the wrapper then
  becomes a no-op safety net for converged results, and unconverged raw fits trigger its existing cold refit paths).
- Risk: header-only new file plus 6 .cpp; every site must see `FixedParamSpec`, `subset_vector`, `subset_matrix` (from
  `_helper_functions_core.h`, included first in all six). Functors are called as `fun(VectorXd, VectorXd&)` and
  `fun.hessian(VectorXd)`; the contratio functor is non-const (fine, passed by reference). Not checked: that the Ref-based
  logit/cloglog functors accept a plain VectorXd grad (they take `Ref<VectorXd>`, which binds an lvalue VectorXd).
- Verify (after user compile of the 6 `.cpp`): `R/EDI/tests/testthat/test-ordinal-fast-solver-uncentred-covariates-reference.R`,
  `test-ordinal-adjcat-contratio-uncentred-covariates-reference.R`; and for a raw kernel call at covariate mean 1e3, expect
  `converged == FALSE` or treatment within 1e-4 of the clm value; well-scaled fixtures unchanged.

### 13 WITHDRAWN (TODO-118), 2026-10-22
- Patch 13 (random rounding in `generate_permutations_blocking_internal`) was withdrawn and its file deleted: the owner decided
  on 2026-10-22 to delete the kernel `generate_permutations_blocking_cpp` (and `generate_permutations_blocking_internal`) instead,
  since R no longer uses it (`block_ra_batch()` replaced both R paths). The deletion was hand-edited in `generate_permutations.cpp`,
  `RcppExports.cpp`, `RcppExports.R`, the Rd, tests and profiler entries. UNCOMPILED: the user's next rebuild is what removes it
  from the installed build (see release_v1_0_5.md TODO-118, G1).
- Not written: a C++ rejection sampler for `DesignFixedRerandomization` (prob_T != 0.5 or odd n). The serial R loop was replaced by a
  vectorized R batch sampler (`generate_rerandomized_w_batch`), so a native version is only an optional OpenMP speedup.

### 14 log-binomial-active-set-step (TODO-128), written 2026-10-22, KKT gate added 2026-10-22, UNCOMPILED
- **Owner decision 2026-10-22: APPLY at G1** (the G6 question is closed). The user applies and builds it; agents do not compile.
- Purpose: the constrained-binomial Fisher-scoring loops (`fit_constrained_binomial_cpp_impl` and `_weighted_cpp_impl`; log
  and identity links) have no boundary handling beyond step halving. When a row sits on the mean-support boundary
  (log link: `eta >= -1e-8`) and the Newton step pushes it outward, halving shrinks the step to ~1e-8, the tiny accepted step
  passes the relative-change test and the fit reports `converged = TRUE` where it started. Seen on a 120-row synthetic set
  with 4 covariates (TODO-128's `make_todo128_design()`): every warm-started leave-one-out refit returned the full-data
  estimate (jackknife SE 0.025 vs 0.225 from cold starts), a third of Bayesian-bootstrap draws equalled the full-data estimate,
  and the cold full-data fit itself stopped early (log-lik -79.77821 vs -79.77803; on a 200-row seed: -120.404 vs -119.958,
  treatment coefficient 0.249 vs 0.283).
- Change: (1) `project_increment_off_active_bounds()` replaces the increment by its XtWX-metric projection onto
  `{d : X_A d = 0}` for rows within 1e-6 of the boundary that the step would push outward (zero-weight rows excluded in the
  weighted loop); (2) convergence is tested on the full (projected) increment when the line search had to damp the step, and
  on the actual step otherwise (bit-identical to the old test when `step == 1`); (3) **KKT convergence gate**
  (`collect_near_bound_rows()`, `kkt_verdict_at_bounds()`): at a point where some row is within 1e-6 of a bound (log: eta -> 0;
  identity: mu -> 0 or 1, signed), a fit is converged only if (i) the Newton-metric projected increment
  `H^{-1}(g - C' lambda)` onto `{d : C d = 0}` (C = the signed near-bound rows, `H d0 = g` reuses the iteration's own
  information and Fisher-scoring increment, no extra evaluation) is `<= 10 * tol` relative to `|beta_free|` (the scale of the
  loop's relative-change test) and (ii) every multiplier `lambda >= -1e-3 * max(1, max|lambda|)` (each held bound genuinely
  binding: the score points outward there). The gate runs at the top of every iteration after the first whose current point
  has a near-bound row (a pass stops the fit as converged: this also ends the Fisher-scoring 2-cycle seen next to the bound,
  where alternate full and half steps never pass the 1e-6 increment test), and when the increment test passes at a near-bound
  point the loop runs one more iteration whose gate decides (`kkt_confirm_pending`; a fail is a stall and returns
  `converged = FALSE`, honest NA downstream). The log-likelihood is concave and the bounds are linear in beta, so a KKT point
  is the constrained MLE. (4) New result fields: `kkt_converged` (same value as `converged`; its presence is the capability
  marker that tells R a built DLL has the gate; also `FALSE` on the early-return failure paths) and `n_active_bounds` (rows
  within 1e-6 of a bound at the returned beta), on the plain, weighted, `estimate_only` and `_with_var` results.
  Points with no row near a bound never reach the gate or the projection, so interior fits are bit-identical (b, converged,
  num_iter).
- Validated only as an R prototype that mirrors the C++ loop line by line (`/tmp/claude-1000/todo128b/proto_kkt.R`;
  unpatched mode reproduces the installed kernel to 1e-11; harnesses `r1.R`, `r2.R`, `r4.R`, `r6.R`, outputs `r4_final.txt`,
  `r6_final.txt`; reference = nloptr SLSQP with `X b <= -1e-8`, three starts):
  - 28 synthetic boundary datasets (`make_todo128_design()`, seeds with a full-data row on the bound, n = 120/200): the
    UNPATCHED kernel reports `converged = TRUE` on all 28 but is short of the constrained MLE on 23 (log-lik gaps up to 0.50,
    treatment coefficient off by up to 0.065); the KKT check, evaluated at the unpatched kernel's answer, rejects all 23 and
    also the 3 whose log-lik is within 2e-6 but whose coefficients have not converged (projected increment 1.4e-5..1.7e-4
    relative), and accepts the 2 that are genuinely at the MLE. Patch 14 without the gate converged on 26/28; with the gate
    28/28, all at the reference (log-lik within 1.4e-5, coefficients within 2.4e-4, median ~1.5e-5), in fewer iterations.
  - Leave-one-out (60 folds, four boundary seeds): warm-from-full and cold fits agree to 1.7e-6..1.3e-4 in the treatment
    coefficient; the unpatched warm refits are KKT-valid on 0/60, 1/60, 39/50, 0/60 folds. On seed 25 (n = 200) 6/60 warm and
    13/60 cold folds still hit `maxit = 100` without reaching the bound (interior Fisher-scoring oscillation, not a boundary
    stall; several converge by `maxit = 1000`): those become NA where the unpatched kernel reported a (mostly false) convergence.
  - Crafted non-optimal boundary point (interior MLE shifted so one y = 1 row sits 5e-7 inside the bound): rejected by both
    conditions (projected increment 0.30, lambda -17.7).
  - Interior fits: 69/69 log-link (unweighted + exponential weights) and 30/30 identity-link fits bit-identical to the
    unpatched loop (b, converged, iterations).
  - Weighted log boundary refits (20 Dirichlet-style draws with 10 zero weights): unpatched converged 13, KKT-valid 5;
    patched 13 converged, log-lik up to 1.4 higher.
- `InferenceIncidBinomialIdentityRiskDiff` (same two loops, `kIdentity`, bounds at `kMinMu = 1e-8` and `kMaxMu = 1 - 1e-8`):
  covered by the same code; `collect_near_bound_rows()` signs lower-bound rows -1 and upper-bound rows +1, and the projection
  and gate treat both. Prototype on three identity sets whose MLE puts a covariate stratum at mu = 0: the unpatched kernel
  falsely converges (log-lik gaps 0.56..2.25, gate rejects); patch 14 alone converges on all three but on two of them with a
  wrong active set (a held row with multiplier -744 / -3.99, log-lik short by 4.7e-4 / 4.0e-5); the gate turns those two into
  `converged = FALSE` and accepts the third (at the reference to 8e-6). In practice the class rarely reaches such fits (its OLS
  smart cold start is often infeasible, and QR column dropping then removes the offending column). Possible follow-up (not in
  this patch): drop rows with negative multipliers from the projection's active set (a full active-set step), which would let
  those fits converge instead of returning NA.
- Known limitation (unchanged): Fisher scoring converges linearly and can oscillate near the bound; the gate's 10 * tol stop
  removes the boundary 2-cycle, but interior oscillation still exhausts `maxit` on some resampled fits (above). A larger `maxit`
  for the log link or observed-information Newton steps would address it.
- Risk: changes boundary fits of `InferenceIncidLogBinomial` and `InferenceIncidBinomialIdentityRiskDiff` (full-data estimates
  too, toward the MLE; some boundary refits become NA). Needs `<vector>` (added) and Eigen's `completeOrthogonalDecomposition`
  (in `<Eigen/Dense>`, already included via RcppEigen / the core header). `std::max` comes through the existing includes (the
  file already uses it). No exported signature changes, so no `compileAttributes()`; only `fast_log_binomial_regression.cpp`
  recompiles. The Python binding uses the same `*_impl` functions and simply gains the two result fields.
- Verify (after user compile of `fast_log_binomial_regression.cpp`, `EDI_UNITY=0`): with `EDI_REQUIRE_CPP_PATCHES=true`,
  `R/package_tests/testthat_bulk/test-log-binomial-constrained-mle-nloptr-reference-todo128.R` (interior block runs today; the
  boundary block keys on the `kkt_converged` field and skips with a message naming this patch until it is built; dry-run
  against the R prototype in place of the kernel: 33/33 pass; against the unpatched numbers with the field faked: 8 failures),
  `test-log-binomial-boundary-mle-warning-todo128.R` (R-only warning, must still pass), `test-log-binomial-jackknife-history-
  independence.R` (must still pass), the kernel tests `test-log-and-identity-binomial-kernels-glm-fixed-coefficients-working-
  weights-and-iteration-cap-reference.R` and `test-binomial-link-score-hessian-and-identity-fit-kernels-reference.R`, and the
  R-side boundary rule (`logbin_feasible_warm_start_args()`, could then be relaxed).

