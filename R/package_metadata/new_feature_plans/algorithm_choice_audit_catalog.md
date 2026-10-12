# Appendix to `algorithm_choice_audit.md`: Per-Kernel Algorithm Catalog

> **Parent:** `algorithm_choice_audit.md` (rows A–M, plus the consolidated rows
> N–AC that this sweep added; read its "2026-10-09 full-catalog sweep"
> section first). This file is the evidence the parent summarizes. It has one row
> per computational kernel in `R/EDI/src/` and per R-side hot loop in
> `R/EDI/R/`, each giving the algorithm, complexity, family, and verdict, with an
> options-and-disadvantages table for every non-trivial verdict.
>
> **Date:** 2026-10-09. **Method:** 12 read-only subagents, each assigned a
> disjoint file set, all following one shared brief (summarized below). Nothing
> was compiled or built. The only code that ran was a pure-R port of one
> loop (the KK21 Weibull bug, see `../bug_fix_plans/kk21_weibull_irls_wrong_fixed_point.md`)
> and reads of existing `comprehensive_tests` CSVs. The coordinator
> verified each finding that the parent file promotes to a bug-fix plan. Everything else here
> is subagent output and is **unverified until someone acts on it**. Re-read the
> cited `file:line` before acting, because line numbers drift.
>
> **All speed multiples here are theoretical** (complexity or literature
> arguments). Like the parent's speedup table, none may be quoted as a
> measurement until `algorithm_ab_testing_framework.md` or a benchmark confirms it.

## How to read a row

- **family**: one of the parent's rows A–M, or a `NEW-<slug>` assigned by
  the subagent. The parent consolidates the ~80 slugs into rows N–AC (mapping
  below).
- **verdict**: one of the following.
  - **Keep**: already best-known at EDI's sizes, or every faster option is worse for EDI.
  - **Keep-tracked**: a known gap that another plan already owns.
  - **Adopt**: a deterministic drop-in that gives the same result within tolerance.
  - **Prototype**: needs the A/B harness.
  - **Investigate**: something could not be determined.
- **Options & disadvantages** tables list *every* serious option, including faster
  ones that are worse (accuracy, bias, exactness, divergence, RNG
  reproducibility, sizes EDI doesn't run). The current algorithm appears as one row.

## Slug → consolidated row mapping

| row | consolidated family | subagent slugs |
|---|---|---|
| N | Finite-difference derivatives where an analytic form exists | fd-derivatives, fd-hessian, glmm-obs-info, delta-method-gradient, delta-method, numerical-derivative |
| O | Special functions and floating-point accuracy | special-fn, special-functions, special-fn-series, streaming-moments |
| P | Separable / reducible / closed-form likelihoods fit by a generic optimizer | two-part-factorization, separable-likelihood, ordinal-binary-reduction, lmm-closed-form, gaussian-closed-form, closed-form, closed-form-stat, matched-pair-clogit |
| Q | Sort-and-sweep statistics; presorting inside resampling loops | survival-sort-sweep, resample-presort, perm-stat-kernel, kk-summary-stats, level-coding, mode-counting, step-function |
| R | Exact discrete null distributions and exhaustive enumeration | exact-discrete-null, exact-rank, exact-conditional-2x2, balanced-partition, pvalue-combination |
| S | Randomization / sequential-design draws, sampling primitives, RNG | seq-design-null-draws, restricted-randomization-draw, assignment-draw, random-variate-generation, sampling-primitives, prng-core |
| T | Forward-stepwise covariate selection (KK21) | forward-stepwise-selection, score-forward-selection |
| U | Distances and small dense linear algebra / design assembly | dense-distance-matrix, small-dense-linalg, rank-revealing, rank-revealing-factorization, linear-algebra-setup, collinearity, design-assembly, design-utils, group-layout, pairwise-distance-quantile, gh-rule |
| V | Refit economics in CI searches and replicate loops | ci-refit-warm-start, mc-bartlett, iterated-bootstrap, seq-mc-stopping, jackknife-influence, resample-size-selection, rand-refit-loop, r-replicate-loop, design-variance-MC, sim-mc |
| W | Quantile-regression LP and rank estimators | quantreg, quantile-LP, rank-selection, rank-hl, rank-AFT |
| X | Robust regression | robust-regression, robust-M |
| Y | Interval-censored NPMLE (Turnbull) | interval-censored, npmle-interval-censored |
| Z | Boundary / constrained MLE, cold starts, separation | constrained-binomial-mle, boundary-reduced-refit, vc-boundary, 1d-nuisance-profile, 1d-constrained-mle, cold-start, separation |
| AA | Nonconcave non-mixture likelihoods | nonconcave-cumulative-link, stereotype-bilinear, nonconcave-dependence-mle, nonconcave, nonconcave-multistart, copula-surv |
| AB | Variance estimators (sandwich, g-computation) | sandwich-vcov, sandwich-variance, gcomp-standardization |
| AC | Infrastructure-level algorithms (scheduling, tuning, imputation) | task-scheduling, autotuning, covariate-imputation |

## Coverage index

| § | group | rows (table lines) |
|---|---|---|
| 1 | C++ — GLMs, OLS, robust, beta regression, starts & linear-algebra helpers | 133 |
| 2 | C++ — ordinal / categorical regression | 64 |
| 3 | C++ — zero-inflated, hurdle, zero-one-inflated | 70 |
| 4 | C++ — GLMM, LMM, clogit+GLMM, GEE, KK combined designs | 107 |
| 5 | C++ — survival | 99 |
| 6 | C++ — rank tests, exact/score CIs, CI inversion, special functions | 106 |
| 7 | C++ — resampling loops, permutations, bootstrap indices, RNG | 105 |
| 8 | C++ — designs, matching, distances, rerandomization, shared helpers, infrastructure | 117 |
| 9 | R — shared inference machinery (inference_all_*, inference_ext_*) | 130 |
| 10 | R — inference classes: survival, ordinal, continuous, count | 127 |
| 11 | R — inference classes: incidence, proportion, mixins, misc | 89 |
| 12 | R — designs, helpers, tuning, simulation framework | 151 |

Every assigned file appears at least once in its group, either as a row or on a grouped `glue` line. Each subagent checked this for its own group.

---

## 1. C++ — GLMs, OLS, robust, beta regression, starts & linear-algebra helpers


All paths relative to `R/EDI/src/`. Line numbers are from the 2026-10-09 working tree (HEAD 36ba15e9). "Shared engine" rows are in `_helper_functions_core.h` (not assigned to this group). They are listed because every assigned Newton/L-BFGS fitter delegates its step to them, and the brief asked which solve each Newton step uses.

**Answers to the brief's specific questions, up front:**
- **Linear solve inside each Newton step:** hand-written IRLS loops (logistic, probit, Poisson-IRLS, log/identity-binomial, cpoisson-combined, robust IRLS, OLS) use `Eigen::LDLT` on the p×p information matrix. No explicit `.inverse()` is used inside any iteration. The shared generic Newton (`optimize_likelihood_newton`, used by Poisson non-IRLS, NB and beta when `optimization_alg="newton*"`) uses `Eigen::FullPivLU` on the observed Hessian. Post-fit variance code uses an LDLT solve against a unit vector (`compute_diagonal_inverse_entry`, with a ColPivQR fallback) or `FullPivLU` followed by a separate `.inverse()` (`invert_free_information`, which factorizes twice).
- **Line search / step halving:**
  - **None:** logistic IRLS, probit IRLS, and cpoisson-combined Newton.
  - **Halving on objective decrease:**
    - Poisson IRLS: up to 10 halvings.
    - Log/identity-binomial: halving down to 1e-8; a step that leaves the feasible region gets -inf log-lik and is rejected.
    - Generic Newton: halving down to 1e-4, then falls back to L-BFGS.
  - **L-BFGS paths:** LBFGSpp backtracking strong-Wolfe line search, max_linesearch=100.
- **COM-Poisson normalizing constant:** **no COM-Poisson kernel exists in the codebase.** A grep for conway/com_poisson/compoisson over `src/` finds nothing. `fast_cpoisson_combined.cpp` is the *conditional*-Poisson (matched-pair binomial) + reservoir-Poisson joint likelihood. Audit row A lists "COM-Poisson", which appears to be a misreading of this file; the row should say "conditional-Poisson".
- **NegBin dispersion:** joint ML over (β, log θ) by L-BFGS (default) or generic Newton→L-BFGS. It is not MASS-style alternation and not a moment estimator. The only moment estimate is the θ start (Cameron–Trivedi-style auxiliary α̂). A Poisson-limit certificate (`_negbin_boundary_convergence.h`) accepts log θ ≥ log 1e4 with a negative θ-gradient as "converged at boundary".
- **Robust regression:** a fixed-scale IRLS M-estimator.
  - Start: OLS (QR).
  - Scale: MAD of the OLS residuals, computed once and never updated.
  - Weights: Huber ("M") or Tukey bisquare ("MM", the default).
  - It does **not** run an S-estimator, FAST-S, FAST-LTS or any subsampling, so "MM" is a misnomer. The estimator is a bisquare M-estimator started from LS, and its breakdown point is effectively 0 against leverage outliers.
- **Matrix rank:** Eigen `ColPivHouseholderQR` (Businger–Golub column-pivoted QR), not SVD.
  - `matrix_rank_cpp` uses threshold 1e-7 relative to the largest pivot.
  - `qr_reduce_*` use Eigen's default threshold (≈ eps·min(n,p)), so the two can disagree about rank.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity (n, p, B, K, \|R\| as relevant) | family | verdict |
|---|---|---|---|---|---|
| fast_logistic_regression.cpp:177-287 `fast_logistic_regression_internal` (IRLS path, default) | logistic MLE | Newton = IRLS (canonical link, Fisher = observed). Fused score + XᵀWX column-pair dot products (`score_weighted_crossprod_colwise_assign`). **LDLT** solve. **Full step, no halving/line search.** Stops on ‖score‖<tol or ‖δ‖<tol. Optional warm/“smart” XᵀWX on iter 0 | O(K·n p²/2 + K p³/3), K≈5–8 | A | Keep algorithm; **Adopt** monotone step-halving (TODO-2) |
| fast_logistic_regression.cpp:103-174 (lbfgs branch) | same | L-BFGS (LBFGSpp, strong-Wolfe backtracking, ε=ε_rel=δ=tol, past=1) | O(K·n p) per iteration; K larger than Newton | A | Keep (non-default alternative) |
| fast_logistic_regression.cpp:292-365 `get_logistic_regression_{score,hessian,weighted_*}_cpp` | analytic score / Hessian at given β | closed form Xᵀ(y−μ), −XᵀWX | O(n p²) | A | Keep |
| fast_logistic_regression.cpp:445 `..._with_var_cpp` → `compute_diagonal_inverse_entry` (_helper_functions_core.h:222) | one diagonal entry of I⁻¹ | LDLT then solve(e_j); ColPivQR fallback | O(p³/3 + p²) | A | Keep (TODO-155 territory) |
| fast_probit_regression.cpp:155-243 (IRLS path, default) | probit MLE | **Fisher scoring** (expected info; non-canonical link) with generalized residual φ/Φ. **LDLT**. **Full step, no halving.** | O(K·n p²/2), K≈5–10 | A | Keep algorithm; **Adopt** halving (TODO-2); fix tail (Incidental 3) |
| fast_probit_regression.cpp:40-83,135-154 `ProbitLbfgsObjective` | same | L-BFGS on log-scale −ℓ (erfc identity for \|η\|<6, `fast_log_pnorm` beyond). Gradient uses *clamped* `pnorm_fast` | O(K n p) | A | Keep; f/grad inconsistent in the tail (Incidental 3) |
| fast_probit_regression.cpp:289-328, 518 (score/hessian/with_var) | evaluators + diag inverse | closed form; `compute_diagonal_inverse_entry` | O(n p²) | A | Keep |
| fast_poisson_regression.cpp:212-290 `fast_poisson_internal` (IRLS path) | Poisson MLE | Newton = IRLS. **LDLT**. **Step-halving ≤10×** on −ℓ, with Δη cached so each probe is O(n). η clamped at 700 | O(K n p² + K·s·n) | A | Keep (already the reference pattern for TODO-2) |
| fast_poisson_regression.cpp:113-149 (non-IRLS path) → `optimize_fixed_likelihood` | same | L-BFGS, or generic Newton (FullPivLU + halving) → L-BFGS fallback | as shared-engine rows | A | Keep |
| fast_poisson_regression.cpp:542 `fast_quasipoisson_regression_with_var_cpp` | quasi-Poisson SE | Pearson χ²/(n−p) × diag inverse | O(n + p³) | A | Keep |
| fast_poisson_regression.cpp:351-401 (score/hessian evaluators) | analytic derivs | closed form | O(n p²) | A | Keep |
| fast_log_binomial_regression.cpp:147-326 `fit_constrained_binomial_cpp_impl` (log & identity link) | **constrained** binomial MLE (μ<1, or 0<μ<1) | Fisher-scoring IRLS (working response z, w = μ/(1−μ) log / 1/(μ(1−μ)) identity). **LDLT**. Halving to 1e-8; infeasible η ⇒ ℓ=−∞ ⇒ rejected. Stop: relative ‖Δβ‖<tol(1e-6). Fails (`converged=FALSE`) when the MLE is on the boundary | O(K n p² + K·s·n) | NEW-constrained-binomial-mle | **Prototype** (TODO-3); start is infeasible (Incidental 1) |
| fast_log_binomial_regression.cpp:328-507 `..._weighted_cpp_impl` | same, weighted | same | same | NEW-constrained-binomial-mle | Prototype (with above) |
| fast_log_binomial_regression.cpp:509-576 `..._with_var_cpp_impl` | Var(β̂_j) | XᵀWX (working weights) → `compute_diagonal_inverse_entry` | O(n p² + p³) | NEW-constrained-binomial-mle | Keep |
| fast_log_binomial_regression.cpp:580-662 `constrained_binomial_{score,hessian}[_weighted]_cpp_impl` | score & **observed Hessian** used in production by `inference_incidence_log_binomial.R:339-348` / `..._binomial_identity.R:247-253` for score/gradient/Bartlett CI refits | **central finite differences**: score 2p ℓ-evals (h=1e-6); Hessian 4-point stencil, 4·p(p+1)/2 ℓ-evals (h=1e-4), each ℓ-eval O(n p) | Hessian **O(2 n p³)** + 2p² n transcendental calls | NEW-fd-derivatives | **Adopt** analytic (TODO-1) |
| fast_negbin_regression.cpp:255-323 `fast_neg_bin_internal` | NB2 MLE, (β, log θ) jointly | default **L-BFGS** (maxit 1000, eps_g 1e-6) on the joint vector; or generic Newton (FullPivLU on the observed Hessian, halving) → L-BFGS. Then the Poisson-boundary certificate | O(K n p) per iteration (L-BFGS); special functions on D distinct y only | A (dispersion GLM) | **Prototype** Fisher-scoring/alternation (TODO-5); boundary failures tracked in bug_fix_plans/negbin_dispersion_convergence.md |
| fast_negbin_regression.cpp:19 `smart_negbin_theta_start_from_beta` + :270-292 start | θ, β start | β: OLS of log1p(y) (QR). α̂ = Σ((y−μ)²−μ)/μ² / (n−p) (moment estimator), θ₀ = max(0.1, 1/α̂); legacy θ₀ = ȳ²/(s²−ȳ) | O(n p²) | NEW-cold-start | Keep |
| fast_negbin_regression.cpp:92-138 `NBLogLik::operator()` | −ℓ and gradient | lgamma/digamma tabulated per **distinct y** (hash map built once); one GEMV | O(n p + D) special-function calls, D = #distinct y | A | Keep (good trick) |
| fast_negbin_regression.cpp:140-189 `NBLogLik::hessian` | observed Hessian | analytic, upper-triangle accumulation; trigamma on distinct y | O(n p²/2) | A | Keep |
| fast_negbin_regression.cpp:191-250 `expected_hessian` / `expected_trigamma_y_plus_theta` | E[ψ₁(Y+θ)] under NB | **series over NB pmf**: recursive p_k, running ψ₁ via recurrence ψ₁(x+1)=ψ₁(x)−1/x², stops when k>μ+10·sd and p_k<1e-14 and tail<1e-12, cap 1e5 terms | O(n·(μ+10 sd)) per call | NEW-special-fn-series | Keep (only reachable via `get_negbin_regression_expected_hessian_cpp`, which has no R caller) |
| fast_negbin_regression.cpp:450 `fast_neg_bin_with_var_cpp` → `invert_free_information` (_helper_functions_core.h:650) | vcov of (β, log θ) | FullPivLU invertibility check, **then a separate `.inverse()`** (two LU factorizations) | O(2·p³) | A | Keep-tracked (performance_profiling_and_upgrades.md TODO-155) |
| log_lik_nb.cpp:7 `neg_loglik_nb_cpp` | NB −ℓ at (θ, β) | direct lgamma sum | O(n p + 3n lgamma) | A | Keep (dead export: only caller is commented out at helper_glm_fit.R:1836) |
| _negbin_boundary_convergence.h:38 `accept_negbin_poisson_boundary_convergence` | certify a Poisson-limit (θ→∞) optimum | if log θ ≥ log 1e4, ∂/∂logθ<0, ‖∇β‖≤max(10tol,1e-6), and a probe at θ·2 does not increase −ℓ, then mark converged + boundary | 2 extra objective evaluations | A | Keep |
| _negbin_boundary_convergence.h:10-35 `negbin_parameter_is_free`, `negbin_information_spec` | glue | drop θ from the information block at the boundary | O(p) | — | glue — no algorithmic content |
| fast_cpoisson_combined.cpp:262-480 `fast_cpoisson_combined_internal` (used by inference_count_KK_cond_poisson.R) | joint MLE: matched-pair conditional-Poisson (=binomial-logit) + reservoir Poisson | Newton with analytic Fisher info (= observed; both parts canonical). **LDLT (`.ldlt().solve`, info() not checked)**. **Full step, no halving**. Cold start β₀=log max(1,ȳ_R), rest 0 | O(K (n_d+n_R) p² ) | A | Keep algorithm; **Adopt** halving + LDLT/finiteness checks (TODO-2) |
| fast_cpoisson_combined.cpp:66-160 `cpoisson_combined_score_info_cpp_impl`, `..._neg_loglik_cpp_impl` | evaluators | closed form; lgamma(y+1) recomputed per call | O((n_d+n_R) p²) | A | Keep |
| fast_ols.cpp:13-69 `fast_ols_internal` | OLS | **normal equations**: `symmetric_crossprod` + **LDLT**; ColPivQR fallback if LDLT reports failure | O(n p²/2 + p³/3) | A | Keep (see Options) |
| fast_ols.cpp:93-201 `fast_ols_with_var_cpp` | OLS + σ̂² + Var(β̂_j) | same; **SSE = yᵀy − β̂ᵀXᵀy**; diagonal entries by LDLT solve(e_j) | O(n p² + p³) | A | Keep; SSE cancellation (Incidental 6) |
| qr_reduce_design_matrix.cpp:7 `qr_reduce_full_rank_cpp` | choose a maximal independent column subset | one ColPivHouseholderQR, keep first `rank` pivots (default Eigen threshold ≈ eps·min(n,p)) | O(2 n p²) | NEW-rank-revealing | Keep (threshold inconsistency, Incidental 8) |
| qr_reduce_design_matrix.cpp:42 `qr_reduce_preserve_cols_cpp` (callers: inference_all_abstract.R:1135,1159; coxph:570,706; KK quantile) | same, forcing required columns | greedy: **a fresh QR of the growing trial matrix for every required column and every candidate column**, plus one QR on the residualized remainder | O(Σ_k 2 n k²) ≈ **O(n p³)** | NEW-rank-revealing | **Prototype-lite** (TODO-6) |
| fast_matrix_rank.cpp:7 `matrix_rank_cpp` (helper_model_matrix.R:99) | numerical rank | ColPivHouseholderQR, threshold `tol` (1e-7) relative to the max pivot | O(2 n p²) | NEW-rank-revealing | Keep |
| fast_scale_cols.cpp:7 `scale_columns_cpp` | column standardization | two-pass mean/sd | O(n p) | NEW-design-utils | Keep (no R caller outside RcppExports) |
| which_cols_vary.cpp:4 `which_cols_vary_cpp` | constant-column detection | early-exit compare to row 0 | O(n p) worst case | NEW-design-utils | Keep (no R caller outside RcppExports) |
| get_column_types.cpp:5 `get_column_types_cpp` | glue | class attribute / SEXP type lookup | O(p) | — | glue — no algorithmic content |
| optimization_starts.h:18 `robust_ols_solve` | LS start | ColPivHouseholderQR basic solution (the comment wrongly says "Complete Orthogonal Decomposition") | O(2 n p²) | NEW-cold-start | Keep |
| optimization_starts.h:32 `logistic_smart_cold_start` | logistic start | OLS of logit((y+0.5)/2) (glm `mustart` analogue) | O(n p²) | NEW-cold-start | Keep |
| optimization_starts.h:48 `poisson_smart_cold_start` | Poisson start | OLS of log(y+0.1) | O(n p²) | NEW-cold-start | Keep |
| optimization_starts.h:60-75 `logistic_smart_hessian`, `poisson_smart_hessian` | iter-0 information | Xᵀ diag(w) X via dense expression | O(n p²) | NEW-cold-start | Keep (could reuse `weighted_crossprod`; trivial) |
| optimization_starts.h:78 `negbin_smart_hessian` | iter-0 NB observed Hessian | per-row `x xᵀ` outer product (heap temporaries per row) | O(n p²) + n allocs | NEW-cold-start | Keep (implementation note, Incidental 13) |
| optimization_starts.h:112,132 `zinb_smart_cold_start`, `zap_smart_cold_start` | mixture starts | component-wise Poisson + logistic(y==0) OLS starts; log θ=0 | O(n p²) | NEW-cold-start (feeds B) | Keep-tracked (multistart_nonconcave_likelihoods.md, em_algorithm_zero_inflated_mixtures.md) |
| optimization_starts.h:163 `weibull_smart_cold_start` | Weibull AFT start | OLS of log y on uncensored rows only (ignores censoring); log σ from the residual SD | O(n p²) | NEW-cold-start | Keep (it is only a start) |
| test_smart_starts.cpp:6-75 `test_*_cpp` | test exports for the starts | forwarders | — | — | glue — no algorithmic content |
| fast_robust_regression.cpp:60-236 `fast_robust_regression_internal` | robust linear regression | OLS (ColPivQR) start → σ̂ = MAD(OLS residuals)/0.6745, **fixed for good** → IRLS with Huber ("M") or bisquare ("MM", default, c=4.685) weights. **LDLT** WLS each iteration. Stop on relative ‖Δβ‖<1e-7, maxit 50. **No S/LTS/subsampling step** | O(K n p² ), K≤50 | NEW-robust-regression | **Investigate** (TODO-4) |
| fast_robust_regression.cpp:137-157 (MAD) | median of \|r\| | `std::sort` if n<512, else `nth_element` ×1 + `max_element` (introselect) | O(n log n) / O(n) | NEW-robust-regression | Keep |
| fast_robust_regression.cpp:356-402 (variance in `fast_robust_regression_cpp`) | Var(β̂_j) | Huber (1981) form (n/(n−p))·Σψ²/(n·mean ψ′)² · [(XᵀX)⁻¹]_jj, with (XᵀX)⁻¹_jj from the cached OLS R (RᵀR LDLT) or `compute_diagonal_inverse_entry` | O(n + p³) | NEW-robust-regression | Keep (formula is standard); no guard for mean ψ′→0 (Incidental 10) |
| fast_robust_regression.cpp:416 `compute_robust_rand_bootstrap_parallel_cpp` (inference_continuous_robust_regr.R) | B randomization/bootstrap refits | OpenMP over B, dynamic schedule. Each replicate builds X_b and does a full **cold** (OLS-QR) robust fit | O(B·K n p²) | J (resampling loop) / NEW-robust-regression | Prototype warm start (TODO-8) |
| robust_post_fit_speedups.cpp:71,174,201,276 HC2: `ols_hc2_post_fit_result`, `ols_hc2_setup_cpp`, `..._precomputed_cpp`, `ols_hc2_post_fit_cpp` | HC2 sandwich vcov | bread = LDLT.solve(I); h_ii = rowSums((X B)∘X); ω=r²/(1−h); meat = weighted_crossprod | O(n p² + p³) | NEW-sandwich-vcov | Keep (`..._precomputed` has no R caller) |
| robust_post_fit_speedups.cpp:297 `glm_sandwich_post_fit_cpp` | HC0 GLM sandwich | bread (XᵀWX)⁻¹ via LDLT.solve(I); meat Xᵀdiag((y−μ)²)X (valid for canonical links only) | O(n p² + p³) | NEW-sandwich-vcov | Keep (no R caller) |
| robust_post_fit_speedups.cpp:137,344 `cluster_meat_robust`, `glm_cluster_sandwich_post_fit_cpp` | cluster-robust GLM sandwich | hash-map cluster grouping of score sums; meat = Σ_g s_g s_gᵀ | O(n p + G p²) | NEW-sandwich-vcov | Keep (caller convention, Incidental 12) |
| robust_post_fit_speedups.cpp:34 `summarize_with_vcov_result` | glue | SE/z extraction | O(p) | — | glue — no algorithmic content |
| fast_beta_regression.cpp:217-272 `fast_beta_regression_internal` | beta regression MLE (logit mean, constant φ) | **L-BFGS** (default; maxit 1000, tol 1e-6 hard-coded) on (β, log φ). Start: OLS of logit(y) for β, **φ₀ = start_phi = 10 fixed** | O(K n p) + 2n lgamma + 2n digamma per eval | A (dispersion GLM) | **Prototype** (TODO-7) |
| fast_beta_regression.cpp:50-104 `BetaRegression::operator()` | −ℓ, gradient | analytic; μ clipped to [1e-8, 1−1e-8] | O(n p) + 4n special fns | A | Keep |
| fast_beta_regression.cpp:106-212 `hessian` (observed) / `expected_hessian` | information | analytic observed (Ferrari–Cribari-Neto) and expected | O(n p²) + 4n special fns | A | Keep |
| fast_beta_regression.cpp:613 `..._with_var_cpp` → `invert_free_information` | vcov | inverts the **observed** Hessian (FullPivLU, then `.inverse()`) | O(2 p³) | A | Keep-tracked (TODO-155); doc mismatch (Incidental 14) |
| beta_regression_helpers.cpp:12,44,76 `beta_loglik_internal`, `beta_dev_resids_internal`, `beta_aic_internal` (+ `_cpp` wrappers) | beta ℓ / deviance residuals / AIC | direct lgamma/lbeta sums | O(n) | A | Keep; **dead exports**, with an AIC bug (Incidental 11) |
| zero_one_logit_transform.h:15-37 `edi_transform::logit_cpp`, `inv_logit_cpp` | clamped logit / expit | branch-stable expit | O(1) | NEW-design-utils | Keep |
| *shared engine* _helper_functions_core.h:1389 `optimize_likelihood_newton` (used by Poisson non-IRLS, NB, beta when Newton is requested) | generic damped Newton | observed Hessian, **FullPivLU** solve, **no descent-direction check**, halving down to 1e-4; then L-BFGS fallback (`optimize_likelihood_newton_then_lbfgs`). `warm_start_hessian` is accepted but `(void)`-ignored | O(K (n p² + p³)) | A | **Prototype** modified Newton (TODO-9) |
| *shared engine* _helper_functions_core.h:1312 `optimize_likelihood_lbfgs` | generic quasi-Newton | LBFGSpp, backtracking strong Wolfe, m = LBFGSpp default | O(K n p) | A | Keep |
| *shared engine* _helper_functions_core.h:308,559 `weighted_crossprod`, `score_weighted_crossprod_colwise_assign` | XᵀWX (+ Xᵀr) | col-major: per column pair a dot product with w∘x_j (upper triangle only, halves the FLOPs of a full GEMM). Row-major: DSYR-style accumulation | O(n p²/2) | A | Keep-tracked (TODO-155: a BLAS-3 `dsyrk`/Eigen `rankUpdate` on √w∘X may win at p≳20) |

Count: 59 catalog rows (including the 3 shared-engine rows), covering all 21 assigned files.

### Options & disadvantages

**O1. Step control for the hand-rolled IRLS/Newton loops (logistic, probit, cpoisson-combined; Poisson and log-binomial already have it)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| globalizing Newton/IRLS on a concave ℓ | **current: full undamped step** | baseline | not globally convergent: can overshoot from a poor start or under quasi-separation and oscillate or run η to ±∞ until maxit. Logistic ℓ is concave but not strongly concave far from the optimum | Nocedal & Wright 2006 ch. 3 |
| | **step-halving on ℓ decrease (glm2-style)** | identical iteration count when the full step is accepted (the common case); +1 O(n) ℓ-evaluation per iteration, which can be fused with the next iteration's μ pass, so ≈0 net cost | none statistically; converged point identical to tolerance. Halving can stall at a tiny step on a separated design (as glm does), which is the correct failure signal | Marschner 2011, *R Journal* 3(2) (glm2) |
| | Armijo/Wolfe line search | same as halving at these sizes | more code; no gain over halving for concave GLM ℓ | Nocedal & Wright 2006 ch. 3 |
| | trust region (Moré–Sorensen) | 1–2× more p³ work per iteration (negligible at small p) | more code; only pays on non-concave surfaces (not these) | Moré & Sorensen 1983, *SIAM J Sci Stat Comput* 4(3) |
| | Firth penalized likelihood (separation) | ≈ same per iteration (+ hat diag O(n p²)) | **changes the estimator** (bias-reduced, finite under separation); not a drop-in | Firth 1993, *Biometrika* 80(1) |

**O2. Linear solve inside each Newton/IRLS step (all GLM rows)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| solve I δ = s, I SPD p×p | **current: Eigen LDLT** (Bunch–Kaufman-free diagonal pivoting) | p³/3 | does not report ill-conditioning. Eigen zeroes only exactly-zero pivots in `solve`, so near-singular I gives huge steps rather than failing (verify on a collinear fixture) | Golub & Van Loan 2013 §4.1–4.2 |
| | LLT (Cholesky) | ≈ same p³/3, slightly fewer branches | fails (info≠Success) on semidefinite I, which is actually desirable as a singularity detector | Golub & Van Loan 2013 §4.2 |
| | FullPivLU (generic Newton today) | ~2–3× slower than LDLT at the same p (theoretical) | wasteful for SPD; no definiteness information. Irrelevant in wall-clock while the O(n p²) Hessian build dominates (n≫p) | Golub & Van Loan 2013 §3.4 |
| | QR on √W X (IRLS as weighted least squares, as in R's glm.fit) | ~2× the flops (2n p² vs n p²/2 + p³/3) | slower; wins only in accuracy when κ(√W X) is ~1e6+ (squared condition number of the normal equations) | Higham 2002 ch. 20 |
| | rank-1 / fixed-size specializations | big win only at p≤2 | narrow scope | performance_profiling_and_upgrades.md TODO-155 (already tracked) |

**O3. Generic Newton on non-concave or indefinite surfaces (NB, beta when Newton is selected; shared engine)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| Newton step with a possibly indefinite observed Hessian | **current: FullPivLU solve + halving to 1e-4, else hand off to L-BFGS** | baseline | the step may be an ascent direction, so halving fails and costs ~14 wasted ℓ-evaluations before the L-BFGS restart | Nocedal & Wright 2006 §3.4 |
| | modified Newton: LDLT/LLT; if not PD add τI (Levenberg–Marquardt) or switch to the expected-information (Fisher-scoring) matrix, which `has_expected_hessian` already detects | fewer wasted evaluations on hard fits; same on easy ones | changes the iterate path on non-concave surfaces, so a different local optimum is possible; needs A/B | Nocedal & Wright 2006 §3.4; Levenberg 1944; Marquardt 1963 |
| | trust region (dogleg / Moré–Sorensen) | similar | more code; same A/B caveat | Moré & Sorensen 1983 |

**O4. Log-/identity-binomial constrained MLE (NEW-constrained-binomial-mle)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| maximize binomial ℓ subject to Xβ<0 (log) or 0<Xβ<1 (identity) | **current: Fisher-scoring IRLS + halving with infeasibility rejection** | baseline, O(K n p²) | **cannot converge when the MLE is on or near the boundary** (common for RR models with a strong covariate), and reports `converged=FALSE`. Also stalls from an infeasible start (Incidental 1) | Wacholder 1986, *Am J Epidemiol* 123(1) |
| | combinatorial EM / reparameterized EM (logbin) | slower (EM is linearly convergent, and the combinatorial variant fits up to 2^p submodels) | always converges to the constrained MLE (monotone); slow at p≳8 for the combinatorial variant | Marschner & Gillett 2012, *Biostatistics* 13(1) |
| | active-set / projected Newton (a QP subproblem per IRLS step with linear constraints Xβ≤−ε) | ≈ current per iteration + a small QP | more code; degenerate active sets at ties | Nocedal & Wright 2006 ch. 16 |
| | adaptive log-barrier (constrOptim-style) | 2–5× more iterations (theoretical) | barrier parameter tuning; returns an interior approximation | Lange 2010, *Numerical Analysis for Statisticians* (adaptive barrier) |
| | COPY method (duplicate data with tiny weight) | ≈ current | **biased** by the copy weight; a heuristic | Deddens, Petersen & Lei 2003, SUGI 28 |
| | modified Poisson + sandwich | fastest (unconstrained Poisson IRLS) | **different estimator** (not the MLE); fitted risks can exceed 1; consistent for the RR only | Zou 2004, *Am J Epidemiol* 159(7) |

**O5. Score/Hessian for log/identity-binomial (NEW-fd-derivatives)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| derivatives of ℓ at β | **current: central finite differences** (2p and 2p(p+1) ℓ-evaluations) | baseline: O(2 n p³) flops + ~2p²n exp/log1p calls for the Hessian | truncation error O(h²) plus cancellation ~ε·\|ℓ\|/h² ≈ 1e-8·\|ℓ\| in the Hessian. **Stencils at a near-boundary β cross η≥−1e-8, so ℓ=−∞ and the Hessian is NaN/Inf, exactly where log-binomial MLEs sit** | Nocedal & Wright 2006 §8.1 |
| | **analytic**: log link ∂ℓ/∂η=(y−μ)/(1−μ), ∂²ℓ/∂η²=−(1−y)μ/(1−μ)²; identity link ∂ℓ/∂η=y/μ−(1−y)/(1−μ), ∂²=−y/μ²−(1−y)/(1−μ)². Hessian = Xᵀ diag(∂²) X | **~p× fewer flops and ~2p² fewer transcendental calls per call** (theoretical: p=10 means ~10× fewer flops, ~200× fewer exp calls) | none; exact. Results change only by the FD error (≤1e-6 relative), and the boundary NaNs disappear | McCullagh & Nelder 1989 §2.5 |
| | automatic differentiation | similar to analytic | dependency/complexity for a 2-line formula | — |

**O6. NB2 dispersion estimation (fast_neg_bin_internal)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| joint MLE of (β, θ) | **current: joint L-BFGS on (β, log θ)**, gradient tol 1e-6, maxit 1000 | baseline; superlinear, typically tens of iterations | stops on a relative-f criterion (past=1) before ‖g‖ is small, a known `converged` ambiguity. Drifts toward θ→∞ on equidispersed data (boundary certificate added) | Liu & Nocedal 1989, *Math Prog* 45 |
| | **Fisher scoring on the joint vector** (the NB2 expected information is block-diagonal in β and θ, so this is IRLS for β plus 1-D scoring for θ, alternating exactly) | typically fewer iterations (quadratic-like for β); expected info needs E[ψ₁(Y+θ)] (series, O1 per obs at moderate μ) | linear convergence in θ when θ is poorly identified; the expected-ψ₁ series is costly at large μ | Lawless 1987, *Can J Stat* 15(3); Cameron & Trivedi 2013 §3.3 |
| | MASS glm.nb alternation (IRLS β ↔ Newton θ via theta.ml) | similar to above | outer-loop convergence can be slow (linear); same boundary drift | Venables & Ripley 2002 §7.4 |
| | profile likelihood in θ (1-D Brent over log θ, IRLS inside) | ~10–20 inner IRLS fits | robust and bracketable (θ→∞ boundary detected naturally) but slower | Brent 1973 |
| | moment / Pearson-χ² θ (quasi-likelihood) | fastest | **not the MLE**; less efficient; breaks LR/score inference built on ℓ | Cameron & Trivedi 2013 §3.2 |

**O7. E[ψ₁(Y+θ)] under NB (NEW-special-fn-series)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| expected trigamma | **current: direct pmf-weighted series with recurrences**, ~μ+10·sd terms | O(μ+10 sd) per obs | cost grows with μ (thousands of terms per obs for large counts); only reachable via an export with no R caller | — |
| | truncate by mass-based bounds with Kahan summation | same order | marginal gain | Higham 2002 ch. 4 |
| | asymptotic (large-θ or large-μ) expansion | O(1) | accuracy only in its regime; needs a switch-over | [cite needed] |
| | use observed information instead | O(1) per obs | different information (observed vs expected) | Efron & Hinkley 1978, *Biometrika* 65(3) |

**O8. Robust regression (NEW-robust-regression)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| robust β for continuous y with possible outliers/leverage | **current: LS start, fixed MAD(LS residuals) scale, IRLS Huber or bisquare** | baseline: O(K n p²), K≲20 | breakdown point **0** w.r.t. leverage points (LS start + LS-residual scale). The bisquare IRLS from the LS start can converge to the wrong root (redescending ψ). The scale is inflated by outliers because it is never re-estimated. Labelled "MM" but is **not** Yohai's MM. Deterministic and fast | Huber 1981; Maronna, Martin & Yohai 2006 ch. 4–5 |
| | Huber M with concomitant scale (re-estimate MAD each iteration, or Huber's Proposal 2) | ≈ current | still breakdown 0 for leverage; behaviour closer to MASS::rlm(psi.huber) | Huber 1981; Venables & Ripley 2002 §6.5 |
| | **true MM: S-estimator via FAST-S (≈500 random p-subsets, k I-steps each, best-t refinement), then bisquare M-step at fixed S-scale** | ~50–200× current per fit at n≈200, p≈5 (500 subsamples × (p³ + k·n p)) | **RNG-dependent** (subsample draws; needs a seed contract for reproducibility of randomization/bootstrap streams). Much slower inside B-replicate loops. 50% breakdown, 95% efficiency | Yohai 1987, *Ann Stat* 15(2); Salibian-Barrera & Yohai 2006, *JCGS* 15(2) |
| | FAST-LTS initial + M-step | similar to FAST-S | RNG-dependent; LTS has low efficiency on its own | Rousseeuw & Van Driessen 2006, *Data Min Knowl Disc* 12 |
| | deterministic S/MM start (DetS-type) | ~5–20× current (a handful of deterministic starts) | not every high-breakdown guarantee carries over exactly; less mature | Hubert, Rousseeuw & Verdonck 2012, *JCGS* 21(3) (location/scatter version); regression variant [cite needed] |
| | LAD (L1) start | ~2–5× current (LP/IRLS) | robust to y-outliers only, not leverage | Koenker & Bassett 1978, *Econometrica* 46(1) |
| | Newton instead of IRLS for the M-step | fewer iterations (quadratic vs linear) | ψ′ is non-smooth (Huber) or changes sign (bisquare), so Newton needs safeguards; IRLS is monotone for Huber | Maronna, Martin & Yohai 2006 §4.5 |
| robust SE | current Huber-1981 formula with (XᵀX)⁻¹ | — | known small-sample anti-conservatism | Koller & Stahel 2011, *CSDA* 55(8) |

**O9. Median / MAD selection**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| median of \|r\| | **current: sort (n<512) / nth_element (introselect)** | O(n log n)/O(n) | none at EDI sizes | Musser 1997, *Softw Pract Exper* 27(8) |
| | Floyd–Rivest select | ~1.2–1.5× fewer comparisons (theoretical) | not worth the code at n≤10⁴ | Floyd & Rivest 1975, *CACM* 18(3) |

**O10. OLS solve**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| least squares | **current: normal equations + LDLT** (QR fallback) | n p²/2 + p³/3 (fastest) | squares κ(X): ~κ(X)²·ε relative error. Unscaled covariates (e.g. 1e5-scale income plus an intercept) can lose ~10 digits. Weak singularity detection (O2) | Higham 2002 ch. 20 |
| | Householder QR (R's lm) | ~2× flops | slower; accurate to κ(X)·ε | Golub & Van Loan 2013 §5.3 |
| | column-pivoted QR / COD (rank-deficient safe) | ~2–2.5× | slower; needs a threshold policy | Golub & Van Loan 2013 §5.4 |
| | SVD | ~4–10× | slowest; gold-standard rank handling | Golub & Van Loan 2013 §5.5 |

**O11. Numerical rank and column selection (NEW-rank-revealing)**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| numerical rank | **current: column-pivoted Householder QR** | 2n p² | can underestimate the rank gap on adversarial (Kahan-type) matrices; essentially never matters for design matrices | Businger & Golub 1965, *Numer Math* 7; Golub & Van Loan 2013 §5.4 |
| | SVD | ~3–5× slower | none except speed; this is the gold standard | Golub & Van Loan 2013 §2.4 |
| | strong RRQR | ≈ QR + extra swaps | more code; guarantees bounds that ColPivQR lacks | Gu & Eisenstat 1996, *SIAM J Sci Comput* 17(4) |
| independent-subset selection forcing required columns (`qr_reduce_preserve_cols_cpp`) | **current: greedy, a new QR per trial column** | O(n p³) | wasteful; redundant re-verification after the residualized QR | — |
| | one QR of [required \| (I−P_req)·remaining]; or incremental QR column-append updates | O(n p²) (~p/3× faster, theoretical) | **discrete rank decisions can flip on near-collinear designs** (different rounding paths), so gate on keep-set equality over the test corpus | Golub & Van Loan 2013 §6.5 (QR updating) |

**O12. Beta regression optimizer and start**
| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| MLE of (β, log φ) | **current: L-BFGS from β=OLS(logit y), φ₀=10** | baseline | φ₀=10 can be orders of magnitude off (φ̂ ranges ~1–1000), costing extra iterations; relative-f stop with past=1 | Liu & Nocedal 1989 |
| | betareg recipe: φ₀ from the Ferrari–Cribari-Neto moment formula; quasi-Newton then a **Fisher-scoring polish** with the analytic expected information (already implemented here) | fewer iterations; a tight-gradient finish | changes the iterate path; the ℓ is non-concave in (β, φ) in general, so A/B is needed | Ferrari & Cribari-Neto 2004, *J Appl Stat* 31(7); Cribari-Neto & Zeileis 2010, *JSS* 34(2) |
| | Newton with the observed Hessian | quadratic locally | observed Hessian can be indefinite away from the optimum (see O3) | Nocedal & Wright 2006 |

**O13. Sandwich vcov (NEW-sandwich-vcov)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| HC/cluster sandwich | **current: explicit bread via LDLT.solve(I)**; leverages via rowSums((X B)∘X) | O(n p² + p³) | normal-equation conditioning (O10); fine at EDI sizes | MacKinnon & White 1985, *J Econometrics* 29(3) |
| | thin QR: h_ii = ‖Q_i‖², bread = R⁻¹R⁻ᵀ | ~2× flops | slower; better conditioned | Golub & Van Loan 2013 §5.3 |
| | HC3 instead of HC2 | same cost | different estimator (more conservative at small n) | Long & Ervin 2000, *Am Stat* 54(3) |

**O14. Cold-start heuristics (NEW-cold-start)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| GLM starting β | **current: one OLS on a transformed response** (logit((y+.5)/2), log(y+.1), log1p(y), logit(y)) | O(n p²) | fine for canonical links. **Wrong transform for log-binomial (log1p(y)≥0 gives an infeasible η)**. Ignores censoring for Weibull | McCullagh & Nelder 1989 §2.5 (glm mustart) |
| | glm-style mustart then one IRLS step | same | needs per-family μ-start code (log-binomial: μ₀=(y+0.5)/2 gives η₀=log μ₀<0, feasible) | McCullagh & Nelder 1989 |
| | multistart | k× | already scoped | multistart_nonconcave_likelihoods.md |

### New TODO candidates
1. **Analytic score/Hessian for log- and identity-binomial** (replace the FD stencils at `fast_log_binomial_regression.cpp:580-662`, closed forms in O5). These are production calls: `inference_incidence_log_binomial.R:339-348` and `inference_incidence_binomial_identity.R:247-253`, where every score/gradient/Bartlett-LR CI refit calls the Hessian up to 3×. Expected win (theoretical) ~p× fewer flops and ~2p²× fewer exp/log1p calls per call, plus removal of the NaN/Inf Hessians when a stencil crosses μ=1 at boundary MLEs. Risk: none statistical. Results change only within FD error, so existing CI tests must use tolerances ≥1e-5. **Deterministic drop-in (Adopt).**
2. **glm2-style monotone step-halving** in logistic IRLS (`fast_logistic_regression.cpp:226-248`), probit IRLS (`fast_probit_regression.cpp:191-215`) and cpoisson-combined Newton (`fast_cpoisson_combined.cpp:407-436`). Copy the Poisson pattern at `fast_poisson_regression.cpp:258-275` (cached Δη, O(n) probes). Also check `ldlt.info()` and `delta.allFinite()` in cpoisson-combined. Expected win: robustness, not speed. It converts overshoot/oscillation failures into converged fits, at ~0 cost when the full step is accepted (fuse the ℓ check into the next iteration's μ pass). Risk: none on well-behaved fits (identical iterates). **Deterministic drop-in (Adopt); the existing fixtures are the gate.**
3. **Log-binomial constrained-MLE solver plus a feasible start** (`fast_log_binomial_regression.cpp:147-507`).
   - (a) Immediately: replace the `ols_smart_cold_start_beta_on_log1p_or_legacy` start with a feasible start, e.g. OLS of log((y+0.5)/2), or the legacy intercept log ȳ, shifted so that max η<0. This is deterministic.
   - (b) Prototype a constrained solver (active-set/projected IRLS, or logbin-style EM fallback when IRLS stalls at the boundary). Expected win: converts boundary-MLE `converged=FALSE` fits to converged ones.
   - Risk: an EM fallback is slow at larger p; an active-set QP adds code. **Needs the A/B harness** (convergence-rate and CI-coverage metrics).
4. **Robust regression "MM"** (`fast_robust_regression.cpp:60-236`).
   - Minimum: rename the label or document it as "bisquare M from an LS start" (no breakdown guarantee).
   - Prototype: a true MM with an S-estimator start (FAST-S, Salibian-Barrera & Yohai 2006) behind an option, seeded from EDI's RNG stream for reproducibility.
   - Expected cost ~50–200× per fit (theoretical), which matters inside `compute_robust_rand_bootstrap_parallel_cpp` (B refits). That suggests MM for the point estimate only, warm-starting replicates from it.
   - Risk: RNG-stream reproducibility; wall-clock in randomization loops. **Needs A/B** (breakdown simulations with leverage contamination, efficiency at the normal).
5. **NB2 Fisher-scoring/alternation** instead of joint L-BFGS (`fast_negbin_regression.cpp:308`), using the already-implemented `expected_hessian` (block-diagonal). Expected win: fewer iterations and a tighter gradient at exit (theoretical). Risk: the expected-ψ₁ series cost at large μ; linear convergence in poorly-identified θ. Composes with bug_fix_plans/negbin_dispersion_convergence.md. **Needs A/B.**
6. **`qr_reduce_preserve_cols_cpp` single-factorization rewrite** (`qr_reduce_design_matrix.cpp:42-157`). Replace the per-candidate re-QR with one QR of the residualized block, or QR column-append updates: O(n p³) → O(n p²). Also unify the rank threshold with `matrix_rank_cpp`'s 1e-7. Risk: discrete keep-set changes on near-collinear designs. **Gate on keep-set equality across the test corpus (light A/B).**
7. **Beta regression start and polish** (`fast_beta_regression.cpp:231-260`). Use the Ferrari–Cribari-Neto moment φ₀ instead of the constant 10, and optionally a Fisher-scoring polish using the existing `expected_hessian`. Expected win: fewer L-BFGS iterations (theoretical). Risk: a different local optimum on rare non-concave surfaces. **Needs A/B.**
8. **Warm-start robust replicates** in `compute_robust_rand_bootstrap_parallel_cpp` (`fast_robust_regression.cpp:482`): pass the full-data β̂ (and scale) as the start instead of a per-replicate OLS-QR. Expected win: fewer IRLS iterations per replicate (theoretical 1.5–3×). Risk: for bisquare, a different start can reach a different root; this also interacts with TODO-4. **Needs A/B.**
9. **Modified-Newton safeguard in the shared `optimize_likelihood_newton`** (_helper_functions_core.h:1389). Use LDLT/LLT, and on a non-PD Hessian or non-descent direction substitute the expected information (when `has_expected_hessian`) or add τI. Also either honour or remove the ignored `warm_start_hessian`. Expected win: fewer wasted halving cascades and L-BFGS hand-offs on NB/beta Newton paths. Risk: changes the iterate path on non-concave ℓ. **Needs A/B.**

### Incidental findings (optional)
1. **Log-binomial smart start is infeasible** (`fast_log_binomial_regression.cpp:177,360`). It uses `ols_smart_cold_start_beta_on_log1p_or_legacy`, i.e. OLS of log1p(y) with y∈{0,1}, so mean fitted η = 0.693·ȳ > 0 and η≥0 is infeasible.
   - Then `ll_curr=−∞` (:195), and the acceptance test `ll_new ≥ ll_curr−1e-10` accepts any finite probe.
   - If the full Fisher step is itself infeasible, halving moves *toward the infeasible start* and never becomes feasible, so the loop breaks with `converged=FALSE`.
   - The identity link's OLS-on-y start can also leave (0,1).
   - The legacy start (`beta[0]=log ȳ`) is feasible and is only used when `smart_cold_start=FALSE`.
2. Log-binomial `converged` is relative-‖Δβ‖-based with tol 1e-6. It is not gradient-based, unlike the other GLMs. Documented, but inconsistent for downstream "converged" gating.
3. **Probit tail handling.**
   - `pnorm_fast` (fast_erfc.h:76) clamps Φ to 6e-16 for |η|≥8. For y=1, η=−10 the generalized residual φ/Φ ≈ 1e-7 instead of the true Mills ratio ≈ 10, so the score and weights vanish for badly misfit points.
   - `Phi_inv = 1−Phi` loses relative accuracy for η≳5.
   - The L-BFGS objective uses log-scale Φ while its gradient uses the clamped Φ (fast_probit_regression.cpp:70-77), so f and ∇f disagree in the tail, which can break the strong-Wolfe line search.
   - Fix: compute the Mills ratio in log space, and use `pnorm_fast(-η)` for the upper tail.
4. Stale quantities at loop exit:
   - Probit IRLS `neg_ll` (:237-242) is computed from `mu` of the pre-final-step iterate when the loop exits on ‖δ‖<tol or maxit.
   - Logistic IRLS `res.mu` and `XtWX` are stale on a maxit exit.
5. `fast_cpoisson_combined_internal`:
   - `H_free.ldlt()` info and `delta_free.allFinite()` are not checked (:413), so NaN parameters propagate.
   - `exp(eta_r)` is unclamped.
   - The cold start sets all of β_T, β_xs to 0, with β₀ = log max(1, ȳ_R), which is biased upward for ȳ<1.
6. `fast_ols_with_var_cpp` SSE = yᵀy − β̂ᵀXᵀy (fast_ols.cpp:117,160,190). This is catastrophic cancellation when R²≈1 or ȳ is large relative to the residual SD, and `max(0,·)` can return σ̂²=0. Use ‖y−Xβ̂‖² (an extra O(n p)).
7. Eigen `LDLT::info()` does not flag ill-conditioned or most rank-deficient PSD matrices. The ColPivQR fallback in `fast_ols_internal` and `fast_ols_with_var_cpp` therefore almost never fires, and near-collinear X gives huge coefficients rather than the QR basic solution. Verify on a collinear fixture.
8. Rank-threshold inconsistency:
   - `qr_reduce_full_rank_cpp` / `qr_reduce_preserve_cols_cpp` use Eigen's default threshold (≈eps·min(n,p)), while `matrix_rank_cpp` / `drop_linearly_dependent_cols` use 1e-7.
   - `drop_linearly_dependent_cols` (helper_model_matrix.R:87-111) factorizes twice, once with Eigen ColPivQR for the rank and once with R LINPACK `qr` (limited pivoting) for the pivot. The two can disagree on *which* columns to keep.
9. `invert_free_information` (_helper_functions_core.h:650) runs FullPivLU for the invertibility test and then `information.inverse()`, a second, partial-pivot LU. Use `lu.inverse()` or LDLT. Tracked under TODO-155.
10. Robust regression:
    - Scale is MAD of the *OLS* residuals and is never updated.
    - `mean ψ′` can be ≈0 or negative for bisquare with many large residuals, which blows up `ssq_b_j` (no guard, fast_robust_regression.cpp:378-380).
    - The variance uses unweighted (XᵀX)⁻¹ (the Huber-1981 form), which is anti-conservative at small n (Koller & Stahel 2011).
11. `beta_aic_internal` (beta_regression_helpers.cpp:108) uses penalty `2*(mu.size()+1)`, i.e. 2(n+1) instead of 2(p+1). The function is dead code: `beta_aic_cpp`, `beta_loglik_cpp`, `beta_dev_resids_cpp` and `neg_loglik_nb_cpp` are referenced only in commented-out R (helper_glm_fit.R:1690-1836). Also without R callers outside RcppExports: `scale_columns_cpp`, `which_cols_vary_cpp`, `ols_hc2_post_fit_precomputed_cpp`, `glm_sandwich_post_fit_cpp`, `get_negbin_regression_expected_hessian_cpp`.
12. Weighted cluster sandwich caller (inference_incidence_KK_marginal.R:61-71) passes X·√w. The cluster score becomes Σ√wᵢ xᵢ rᵢ, whereas the weighted-likelihood score is Σwᵢ xᵢ rᵢ. These match only for w∈{0,1}. The comment claims a "weighted-HC0 convention"; verify that it is intended for Bayesian-bootstrap or IPW weights.
13. `negbin_smart_hessian` (optimization_starts.h:93-96) allocates `X.row(i).transpose()` and a p×p `x xᵀ` temporary per row. Use `weighted_crossprod`-style accumulation. Also, `robust_ols_solve`'s comment claims COD but the code uses ColPivHouseholderQR.
14. Beta regression roxygen (fast_beta_regression.cpp:369-378) says `fisher_information` is the "XᵀWX-style working-weights / expected-information approximation". The code returns `fun.hessian(params)`, the **observed** Hessian (:265), and `_with_var` inverts that.
15. `optimize_likelihood_newton` silently ignores `warm_start_hessian` (`(void)warm_start_hessian;`, _helper_functions_core.h:1394). The `h_ptr` plumbing in Poisson, NB and beta does nothing on the Newton path.
16. NB −ℓ uses lgamma(y+θ)−lgamma(θ) (fast_negbin_regression.cpp:108,125). This loses absolute precision ~ε·lgamma(θ) near the Poisson boundary (θ≥1e4: ~1e-11 per obs, fine; θ~1e8: ~1e-7 per obs). Σ_{k<y} log(θ+k) would be exact for small y. Minor.
17. Audit row A's kernel list says "COM-Poisson". No COM-Poisson kernel exists; `fast_cpoisson_combined.cpp` is conditional-Poisson. Row A also lists "log-binomial" under Keep. That Keep is not justified, because the log-binomial problem is constrained and the current IRLS fails at boundary MLEs (TODO-3).

---

## 2. C++ — ordinal / categorical regression


Shared machinery referenced below (not in this group's files, read to classify): `optimize_fixed_likelihood` (`_helper_functions_core.h:1552`) dispatches `"lbfgs"` → LBFGSpp, strong-Wolfe backtracking, stops on gradient norm OR relative function decrease `delta = tol, past = 1` (`:1312-1345`); anything else → damped Newton on the **observed** Hessian (FullPivLU solve, step-halving to 1e-4, no LM/trust-region modification; `:1394-1478`), falling back to L-BFGS if Newton does not converge (`:1481-1508`). **`warm_start_hessian` is ignored by both paths** (`(void)warm_start_hessian;` at `:1399`; the L-BFGS path never receives it). d = number of free parameters below.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| ordinal_fixed_link_helpers.h:26 `init_levels` | distinct sorted levels | sort + unique | O(n log n) once | — | Keep |
| ordinal_fixed_link_helpers.h:36 `fast_atan` | arctan for cauchit CDF | Cephes range reduction + 5/5 rational minimax (1 ulp) | O(1) | NEW-special-fn | Keep |
| ordinal_fixed_link_helpers.h:67-161 `cdf`/`pdf`/`pdf_derivative`/`cdf_and_pdf`/`cdf_pdf_fpdf` | link CDF, density, density' | closed forms; probit via Cephes erfc (`fast_erfc.h`, full precision, ±8 clamp); cloglog fused (2 exp instead of 4–6) with hard clamps z>5→F=1, z<−37→F=0 | O(1) | NEW-special-fn | Keep |
| ordinal_fixed_link_helpers.h:245 / :264 `FixedOrdinalRegression::neg_log_likelihood` / `operator()` | cumulative-link NLL + analytic gradient (logit/probit/cloglog/cauchit share this) | direct CDF-difference likelihood, 1e-12 floor; **ordering of thresholds enforced by hard barrier** (`validate_params` → return 1e10, zero gradient) — no reparametrization, no clamping | O(n(K+p)) per eval (incl. O(K) `level_index` scan per obs) | A | Keep |
| ordinal_fixed_link_helpers.h:302 `FixedOrdinalRegression::hessian` | observed information | analytic second derivatives (rank-1 + two endpoint terms per obs), upper-triangle accumulate | O(n d²), d=K−1+p | A | Keep |
| ordinal_fixed_link_helpers.h:392 `expected_hessian` | expected (Fisher) information | analytic Σ_k (1/π_k)∇π_k∇π_kᵀ | O(n K d²) | A | Keep (never used by optimizer; inference only) |
| fast_ordinal_regression.cpp:138 `fast_ordinal_regression_internal` (logit / proportional odds; also `_cpp` :322, `_weighted_cpp` :381, `_with_var_cpp` :445) | PO-model MLE | **L-BFGS default**; cold start = thresholds evenly spaced on (−1,1) + β from no-intercept OLS of (y−1)/(K−1) (not the marginal-quantile start the other 3 links use); computes a full Hessian `H_start` (:193-196) that the optimizer then ignores | O(n(K+p)) × (~20–50 L-BFGS evals) + one wasted O(n d²) | A | Prototype (Newton default; see TODO-1) |
| fast_ordinal_regression.cpp:214-247 (post-fit) | vcov | observed Hessian + FullPivLU inverse of free block | O(n d² + d³) | A | Keep-tracked (`performance_profiling_and_upgrades.md` TODO-155: LU vs LDLT) |
| fast_ordinal_probit_regression.cpp:114 `fast_ordinal_probit_regression_internal` (+ `_cpp` :295, `_with_var_cpp` :357) | ordered-probit MLE | L-BFGS default; marginal-quantile threshold start (`ordinal_smart_cold_start`, `_helper_functions_core.h:1012`), β=0 | as logit | A | Prototype (TODO-1) |
| fast_ordinal_cloglog_regression.cpp:117 `fast_ordinal_cloglog_regression_internal` (+ `_cpp` :296, `_with_var_cpp` :358) | cumulative cloglog (grouped PH) MLE | L-BFGS default; marginal-quantile start; **sign convention F(α+xᵀβ)** (`eta_sign=+1`) unlike the other 3 links' F(α−xᵀβ) | as logit | A | Prototype (TODO-1); CR-reformulation option listed below |
| fast_ordinal_cauchit_regression.cpp:111 `fast_ordinal_cauchit_regression_internal` (+ `_cpp` :293, `_with_var_cpp` :355) | cumulative cauchit MLE | L-BFGS default, single marginal-quantile start; likelihood **not concave** (Cauchy density not log-concave → Pratt 1981 condition fails) | as logit | NEW-nonconcave-cumulative-link | Keep-tracked (`multistart_nonconcave_likelihoods.md` TODO-5, v1.2.0) + Investigate (multimodality frequency at EDI n unmeasured) |
| fast_ordinal_{cauchit,probit,cloglog}_regression.cpp :175-192 / :178-197 / ~:180 (post-fit) | vcov, ssq_b_j | Hessian built **twice** (`model.hessian` then `fixed_obj.hessian` rebuilds it), LDLT diag-entry solve + separate LDLT full inverse | 2·O(n d²) + 2·O(d³) | A | Keep (redundancy is implementation-level, see incidental) |
| fast_ordinal_regression.cpp:527 `ordinal_gcomp_post_fit_cpp` | standardized mean-score difference + delta-method SE | Hessian + FullPivLU inverse; **gradient of md by central finite differences** (h=1e-5) over all K−1+p params | O(n d² + d³ + n K d) | NEW-delta-method-gradient | Adopt (analytic gradient, low priority; TODO-5) |
| fast_ordinal_regression.cpp:760 `expand_continuation_ratio_data_cpp` | CR → stacked binary (strata × cut) | row emission, rows for cuts 1..min(y,K−1); exact sequential factorization of the CR likelihood | O(nK) | NEW-ordinal-binary-reduction | Keep |
| fast_ordinal_regression.cpp:869 `expand_adjacent_category_data_cpp` | adjacent-category → stacked binary (strata × cut) | row emission for the ≤2 cuts bordering y_i; product of the per-cut conditional binomials is a **composite (pairwise-conditional) likelihood**, not the multinomial likelihood | O(nK) | NEW-ordinal-binary-reduction | Investigate (downstream SE validity; see options + incidental) |
| fast_adjacent_category_logit.cpp:34 `AdjacentCategoryLogitNegLogLik::operator()` | AC-logit NLL + gradient | additive log-space recurrence + log-sum-exp (overflow-safe) | O(n(K+p)) | A | Keep |
| fast_adjacent_category_logit.cpp:93 `::hessian` | information | analytic; canonical exponential family so observed = expected; O(K²) αα block via cdf products | O(n(K²+Kp+p²)) | A | Keep |
| fast_adjacent_category_logit.cpp:198 `fast_adjacent_category_logit_internal` (+ `_cpp` :381, `_with_var_cpp` :468) | AC-logit MLE (strictly concave) | **L-BFGS default**; start α=0, β = **no-intercept** OLS of y∈{1..K} on X (β absorbs mean level, e.g. ≈(K+1)/2 for a 0/1 treatment column) | O(n(K+p)) × L-BFGS evals | A | Prototype (TODO-1, TODO-4 start) |
| fast_adjacent_category_logit.cpp:509-519 (post-fit) | vcov | `symmetric_pseudo_inverse` of free information (rank-aware) | O(d³) | A | Keep |
| fast_adjacent_category_logit.cpp:555 `compute_adj_cat_logit_distr_parallel_cpp` | randomization distribution of β̂_T | B independent **Newton** fits from all-zero start, OpenMP static schedule | O(B · iters · n(K²+Kp+p²)) | NEW-rand-refit-loop | Keep (concave → start-invariant; see incidental on optimizer mismatch vs observed fit) |
| fast_adjacent_category_logit.cpp:180/187 `get_levels`/`map_y_to_1K` | level coding | sort-unique + binary search | O(n log n) | — | Keep |
| fast_continuation_ratio_regression.cpp:74 `build_continuation_ratio_augmented_data` | CR → binary-GLM expansion | **yes, uses the known exact reduction**: dense X_aug with K−1 cut dummies + X, z = "continued past cut" | N_aug=Σmin(y_i+1,K−1) ≤ n(K−1) rows × d cols, O(N_aug d) memory | NEW-ordinal-binary-reduction | Keep (reduction) / Adopt structured version (TODO-3) |
| fast_continuation_ratio_regression.cpp:44 `ContinuationRatioObjective::operator()` | logistic NLL + gradient on expanded data | dense GEMV; μ clamped via η∈[−20,20] | O(N_aug d) | A | Keep |
| fast_continuation_ratio_regression.cpp:56 `::hessian` | information | `weighted_crossprod(X_aug, μ(1−μ))` on dense X_aug | O(N_aug d²) | A | Adopt (structured, TODO-3) |
| fast_continuation_ratio_regression.cpp:151 `fast_continuation_ratio_internal` (+ `_cpp` :323, `_weighted_cpp` :382, `_with_var_cpp` :478) | CR MLE (canonical logistic, strictly concave) | **L-BFGS default**; start = OLS (linear-probability) on z | O(N_aug d) × L-BFGS evals | A | Prototype (Newton/IRLS default; TODO-2) |
| fast_stereotype_logit.cpp:119 / :155 `compute_scores` / `compute_scores_with_second_derivatives` | ordered scores φ with 0=φ₁<…<φ_K=1 | **cumulative-softmax reparam** φ_j = Σ_{r≤j−2}e^{γ_r}/(1+Σe^{γ_r}) (exp-increment normalized; γ=0 ⇒ equally spaced) | O(K²) / O(K³) | NEW-stereotype-bilinear | Keep |
| fast_stereotype_logit.cpp:204 `loglik_grad` | stereotype LL + gradient | softmax with max-shift; analytic | O(n(p + K·(K−2))) | NEW-stereotype-bilinear | Keep |
| fast_stereotype_logit.cpp:275 `loglik_hessian` | observed Hessian | analytic: B_y − Σp_jB_j − (Σp_j z_j z_jᵀ − m mᵀ); dense d×d B_j per category per obs (sparse in truth) | O(n K d²), d=2K−3+p | NEW-stereotype-bilinear | Keep (sparsity = incidental) |
| fast_stereotype_logit.cpp:389 `expected_hessian` | Fisher information (PSD) | analytic Σp_j z_j z_jᵀ − m mᵀ | O(n K d²) | NEW-stereotype-bilinear | Keep (unused by optimizer — see options) |
| fast_stereotype_logit.cpp:688 `fast_stereotype_logit_internal` (+ `_full_internal` :731, `_cpp` :935, `_with_var_cpp` :1045) | stereotype MLE, **nonconcave (bilinear φ_kβ)** | **Newton-then-L-BFGS** default from one start (α = empirical log count ratios, β=0, γ=0); at β=0 the γγ block is 0 and (p=1, K≥4) the Hessian is singular → Newton breaks at iter 0 and L-BFGS does the work. R side (`inference_ordinal_stereotype_logit.R:1-150`) adds ≤8 deterministic restarts (4 joint γ offsets, 2 alternating, 2 data-hash-seeded) on the **full-data fit only** | O(n K d²) per Newton iter | NEW-stereotype-bilinear | Keep-tracked (`multistart_nonconcave_likelihoods.md` TODO-5) + Prototype (safeguarded Newton, TODO-6) + Investigate (p=1 saturation, TODO-7) |
| fast_stereotype_logit.cpp:593 `optimize_nuisance_given_beta` / :652 `profile_loglik_for_beta` / :1154 `fast_stereotype_profile_loglik_cpp` | profile LL at fixed β₁ | damped Newton on nuisance block, analytic Hessian (helper is misnamed `nuisance_numeric_hessian_from_gradient`; `h` unused), 50 iters, step-halving to 1e-8 | O(50 · n K d²) | NEW-stereotype-bilinear | Keep |
| fast_stereotype_logit.cpp:785-795 / :1091-1101 (variance fallback) | Var(β̂₁) when observed-info diagonal-inverse not finite | 3 profile refits + **second finite difference** of profile LL, h=max(1e-4,1e-3(|β̂|+1)) | 3 × profile cost | NEW-stereotype-bilinear | Keep (fallback only) |
| fast_stereotype_logit.cpp:1210 `compute_stereotype_logit_distr_parallel_cpp` | randomization distribution of β̂_T | B cold-start **L-BFGS** fits (maxit 200, tol 1e-10), OpenMP; no multistart (observed statistic does get R-side multistart) | O(B · ~100s evals · n K²) | NEW-rand-refit-loop | Investigate (TODO-7) |
| glue — fast_ordinal_regression.cpp:27 `plogis_stable_cpp`, :90 `get_ordinal_regression_score_cpp`, :123 `..._hessian_cpp`; fast_ordinal_cauchit_regression.cpp:56 `fast_atan_cauchit_cpp`, :65/:86 score/hessian; fast_ordinal_probit_regression.cpp:68/:89 score/hessian, :54 `pseudo_inverse_symmetric_probit` (**dead code**); fast_ordinal_cloglog_regression.cpp:56 `fast_cloglog_link_eval_cpp`, :73/:94 score/hessian; fast_adjacent_category_logit.cpp:247/:266 score/hessian; fast_continuation_ratio_regression.cpp:200/:220 score/hessian (rebuild X_aug each call); fast_stereotype_logit.cpp:824/:859 score/hessian, :469 `pseudo_inverse_symmetric` (**dead code**), :481/:514/:544 nuisance pack/unpack | — | forwarding / packing | — | — | glue — no algorithmic content |

### Options & disadvantages

**(1) Optimizer for the concave cumulative-link fits (logit/probit/cloglog; Pratt 1981 ⇒ concave LL), adjacent-category, continuation-ratio.**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| concave ordinal MLE, d≈3–15 | **current: L-BFGS (LBFGSpp, strong Wolfe), stop on ‖g‖<tol OR relative f-decrease (past=1)** | 1× | superlinear only; the f-decrease stop routinely ends with ‖g‖≫tol (the audit's own TODO-4 note), so the score at the "MLE" is not ~0. That matters for score/LR CIs (constrained refits) and for the randomization null distribution | Nocedal & Wright 2006 ch. 7 |
| (same) | damped Newton on analytic observed Hessian (already implemented: `optimization_alg="newton_raphson"`, L-BFGS fallback) | ~1–2× fewer gradient-equivalents (≈5–8 Newton iters × [grad + O(nd²) Hessian + ~1 line-search eval] vs ≈25–45 L-BFGS evals; the transcendental CDF/pdf calls dominate both); unmeasured | Hessian is O(nd²) per iteration, so it loses when d grows large (not EDI's regime); on a non-PD Hessian (far start, near-separation) the plain Newton step can fail → falls back to L-BFGS anyway | McCullagh 1980 JRSS-B; Nocedal & Wright 2006 ch. 3; ordinal::clm defaults to Newton (Christensen, *ordinal* R package) |
| (same) | Fisher scoring (expected info; = Newton for AC-logit and CR-logit because they are canonical) | same as Newton; Fisher info is always PSD | for non-canonical links (probit/cloglog/cauchit) only linear convergence near optimum; needs final observed-info Newton step for exact SE equivalence | McCullagh & Nelder 1989 |
| CR / AC logit specifically | Böhning–Lindsay fixed-curvature-bound MM (one Cholesky reused every iter) | O(N_aug d) per iter after one factorization | linear convergence (often 20–100 iters); a win only when d is large | Böhning & Lindsay 1988, *Ann. Inst. Stat. Math.*; Böhning 1992, *Ann. Inst. Stat. Math.* |
| any of the above | post-fit single Newton "polish" step using the Hessian already computed for vcov | ~free when `estimate_only=FALSE` | does nothing for `estimate_only=TRUE` replicate fits (the hot path) | — |

**(2) Threshold ordering constraint (cumulative links).**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| α₁<…<α_{K−1} | **current: unconstrained α, hard barrier (NLL=1e10, grad=0 if violated)** | 1× | barrier point carries no gradient info; harmless for log-concave links because LL → −∞ at a crossing and the MLE is interior whenever every category is observed (EDI codes K from observed levels) | Pratt 1981 |
| (same) | exp-increment reparam α_k = α₁ + Σ exp(δ_j) | same cost | **destroys concavity** in (δ,β) for logit/probit/cloglog, so Newton loses its global behavior; Jacobian chain rule on every Hessian; δ → −∞ when two thresholds nearly coincide (sparse categories) | MASS::polr (Venables & Ripley 2002) |
| cloglog only | Läärä–Matthews: refit as CR-cloglog binary GLM on the CR expansion with θ_j unconstrained (α_k = log Σ_{j≤k} e^{θ_j}) | IRLS on an O(n(K−1)) binary design, no barrier | different parametrization → Hessian/vcov needs a delta-method map back to α; zero-variance gain at EDI sizes; extra code path to maintain | Läärä & Matthews 1985, *Biometrika* |

**(3) Continuation-ratio fitting (the reduction question).**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| CR-logit MLE | **current: exact binary-logit reduction on dense X_aug + generic L-BFGS** | 1× | dense K−1 dummy columns: Hessian O(N_aug d²) with N_aug ≤ n(K−1); L-BFGS stop rule as in (1) | Fienberg 1980; Agresti 2010 |
| (same) | same reduction, Newton/IRLS, **structure-exploiting** (never materialize X_aug: per subject, accumulate s_i=Σ_cuts μ(1−μ), Hessian = [diag(cut sums) | Σ_i (per-cut sums) x_iᵀ ; Σ_i s_i x_i x_iᵀ]) | Hessian O(n p² + nKp) vs O(n K (K+p)²): ~5–8× at K=5,p=5 (theoretical); memory O(np) not O(nK(K+p)) | none statistically — identical likelihood; implementation cost; separate code path from `ContinuationRatioObjective` | — |
| (same) | direct (unexpanded) sequential likelihood | same as structured | identical to the structured reduction; no advantage over it | Agresti 2010 |
| (same) | reuse package IRLS logistic (`fast_logistic_regression_cpp`) on X_aug | Newton-rate, zero new code | keeps the dense X_aug cost | — |

**(4) Adjacent-category via stacked binary (`expand_adjacent_category_data_cpp` → clogit in `inference_ordinal_KK_cond_logit_abstract.R:27`).**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| AC-logit with pair-conditioned nuisance | **current: stacked binary conditional logit, naive model-based SE** | 1× | each subject appears in up to 2 cuts with the same y: product of per-cut conditionals is a composite likelihood; estimator consistent but **naive SE is not the Godambe/sandwich SE** | Begg & Gray 1984, *Biometrika*; Varin, Reid & Firth 2011, *Stat. Sinica* |
| (same) | same estimator + subject-clustered sandwich SE | +O(N_aug d²) | — | Varin, Reid & Firth 2011 |
| (same) | full conditional multinomial AC likelihood given pair (exact conditional) | more expensive (per-pair enumeration of category permutations) | implementation cost; small strata only | Agresti 2010 [exact conditional form: cite needed] |

**(5) Stereotype logit (bilinear, nonconcave).**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| stereotype MLE | **current: observed-Hessian Newton → L-BFGS fallback, 1 C++ start + ≤8 R-side restarts (full data only)** | 1× | at the cold start (β=0) γ is unidentified, Newton step singular/indefinite and is discarded (wasted O(nKd²)); no curvature modification; known ~3% non-global optimum at n=50 (memory note) | Anderson 1984, *JRSS-B* |
| (same) | Levenberg–Marquardt / trust-region Newton (modify observed H by λI or Moré–Sorensen) | same per-iter cost, fewer failed iterations | still local; λ schedule tuning; not bit-for-bit with current fits that already converge | Moré & Sorensen 1983, *SIAM J. Sci. Stat. Comput.*; Marquardt 1963 |
| (same) | Fisher scoring on the existing PSD `expected_hessian` (+LM damping at β≈0 where it is also singular in γ), then observed-Newton polish | same | linear rate until the switch; still local | McCullagh & Nelder 1989 |
| (same) | alternating (block-coordinate) ML: given φ, (α,β) is a concave multinomial-logit fit; given β, (α,φ) is a concave multinomial fit in η_i | each block Newton O(nKd_b²); many outer iterations | monotone ascent but linear (often slow) convergence; the monotone-φ constraint is nonlinear in γ, so the φ-block needs isotonic/constrained handling; still local → still needs multistart | Yee & Hastie 2003, *Statistical Modelling* (RR-VGLM alternating algorithm); Kuss 2006, *CSDA* |
| (same) | multistart (tracked) | ×(#starts) | cost; does not apply to replicate fits unless extended | `multistart_nonconcave_likelihoods.md` |
| p=1 (treatment only) | **closed form**: with p=1 the model has 2K−2 params = saturated 2-arm multinomial, so if the empirical scores φ̂_k=log(n₁ₖn₀₁/(n₀ₖn₁₁))/log(n₁K n₀₁/(n₀K n₁₁)) are strictly monotone in (0,1), the MLE is closed form (β̂ = top-vs-bottom log odds ratio); otherwise the constrained MLE is on the φ-tie boundary (an order-restricted problem) | O(n) vs O(iters·nK²) | boundary/zero-cell cases need an isotonic (pool-adjacent-violators-type) solver, not a closed form; must be A/B'd against current outputs, which on boundary cases depend on where L-BFGS stopped | Robertson, Wright & Dykstra 1988 (order-restricted inference) |

**(6) Delta-method gradient in `ordinal_gcomp_post_fit_cpp`.**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| ∇ md(α,β) | **current: central differences, h=1e-5, 2d evaluations** | 1× (O(nKd)) | ~1e-10 truncation/rounding error; returns NA if a ±h perturbation crosses two near-equal thresholds | — |
| (same) | analytic: ∂md/∂α_k = mean_i[f(η₀ᵢ−α_k) − f(η₁ᵢ−α_k)], ∂md/∂β_j = mean_i Σ_k[f(η₁ᵢ−α_k)X1_ij − f(η₀ᵢ−α_k)X0_ij] | ~d× fewer passes (absolute time negligible) | none; deterministic, equal to tolerance | — |

### New TODO candidates
1. **Newton (Newton-then-L-BFGS) as default for the concave ordinal fits** — `fast_ordinal_regression.cpp:198`, `fast_ordinal_probit_regression.cpp:161`, `fast_ordinal_cloglog_regression.cpp:164`, `fast_adjacent_category_logit.cpp:242` (change `"lbfgs"` defaults; R callers pass no `optimization_alg`). Expected (theoretical): ~1–2× fewer gradient-equivalents per fit and gradient-norm-certified convergence instead of the f-plateau stop. Risk: Newton step failures on far/near-separated starts (already guarded by the L-BFGS fallback); numbers change at the 1e-6 level. Needs the A/B harness for wall-clock only — correctness gate is "same unique MLE within tol" (strictly concave). Not for cauchit.
2. **Continuation-ratio: Newton/IRLS default** — `fast_continuation_ratio_regression.cpp:194` (and :160, :323, :392, :486 defaults). Canonical logistic, so Newton = Fisher scoring, quadratic. Win/risk as TODO-1; A/B for wall-clock only.
3. **Continuation-ratio: structure-exploiting objective/Hessian without dense X_aug** — replace `build_continuation_ratio_augmented_data` + `ContinuationRatioObjective` (`fast_continuation_ratio_regression.cpp:28-135`). Expected: Hessian O(n p² + nKp) instead of O(nK(K+p)²) (~5–8× at K=5,p=5, theoretical), memory O(np). Deterministic drop-in (identical likelihood); keep `X_aug`/`z` outputs only if R still reads them. Gate: existing CR tests.
4. **Fix the adjacent-category / PO cold starts** — `fast_adjacent_category_logit.cpp:226-231` regresses y∈{1..K} on X **without an intercept** (β start absorbs the mean level); `fast_ordinal_regression.cpp:169-184` uses evenly spaced (−1,1) thresholds instead of `ordinal_smart_cold_start`'s marginal link quantiles. Use α = empirical log ratios/marginal quantiles, β = 0 (or centered-y OLS). Concave, so only iteration count changes; deterministic, A/B for iteration count.
5. **Analytic md gradient in `ordinal_gcomp_post_fit_cpp`** (`fast_ordinal_regression.cpp:616-644`). Deterministic drop-in; removes the spurious-NA edge case. Low priority.
6. **Stereotype: curvature-safe Newton** — in the stereotype path, replace plain observed-Hessian Newton (which is discarded at the β=0 cold start) with LM-damped Fisher scoring on `expected_hessian` then observed-Newton polish; or start from a β obtained by a 1-D concave fit with φ fixed at equally spaced scores (= adjacent-category-type model). Where: `fast_stereotype_logit.cpp:724` (+ shared helper). Expected: fewer wasted Hessians and fewer non-converged replicate fits; not a guaranteed global optimum (multistart TODO-5 still needed). Needs A/B harness (nonconcave: results can change).
7. **Stereotype p=1 closed form / order-restricted MLE + investigate the null randomization distribution** — `compute_stereotype_logit_distr_parallel_cpp` (`fast_stereotype_logit.cpp:1210-1264`) and the p=1 full-data fit. Under H₀ β≈0 so φ is unidentified and the empirical φ̂ are frequently non-monotone ⇒ many replicate MLEs sit on the φ-tie boundary, where the reported β̂ depends on L-BFGS's stopping point; meanwhile the observed statistic gets R-side multistart and replicates do not. Expected: O(n) per replicate when interior; main value is a well-defined replicate statistic. Needs A/B (null-distribution comparison + Type-I error).

### Incidental findings (optional)
- `fast_ordinal_regression.cpp:188-196`: `H_start = model.hessian(params)` is computed on every smart cold start and passed down, but both optimizer paths ignore `warm_start_hessian` (`_helper_functions_core.h:1399`, L-BFGS path never receives it) — one wasted O(n d²) Hessian per PO fit, including every randomization/bootstrap replicate fit. Same dead plumbing for `warm_start_fisher_info` in all 8 files.
- `fast_ordinal_{cauchit,probit,cloglog}_regression.cpp` post-fit: full Hessian built twice (`model.hessian` and `FixedParameterFunctor::hessian`, which rebuilds the full matrix then subsets), plus two LDLT factorizations (diag entry + full inverse).
- Dead code: `pseudo_inverse_symmetric_probit` (`fast_ordinal_probit_regression.cpp:54`), `pseudo_inverse_symmetric` (`fast_stereotype_logit.cpp:469`).
- `ordinal_fixed_link_helpers.h:163` `level_index` is an O(K) linear scan with exact double equality, done per observation per evaluation; precompute integer codes once in the constructor.
- Cloglog sign convention F(α+xᵀβ) (positive β → lower categories) is opposite to the logit/probit/cauchit F(α−xᵀβ) and to CR/AC/stereotype "positive β → higher". Documented, but it is a sign trap relevant to the open ordinal param-bootstrap sign-mismatch bug (memory `project_ordinal_param_bootstrap_sign_bug_20260923`).
- `fast_continuation_ratio_regression.cpp:23-53`: μ is computed from η clamped to ±20, and the NLL from that clamped μ, so beyond |η|>20 the objective is flat while the gradient Xᵀ(μ−z) is not its derivative. Under (quasi-)separation this mismatch can break the strong-Wolfe line search (L-BFGS throws → `catch(...)` → NaN value, converged=FALSE).
- Cumulative links compute P(Y=k) = F(z_u) − F(z_l) directly; when both F≈1 (large η, upper categories) this cancels catastrophically. Symmetric links could use F̄(z_l) − F̄(z_u) when z_l>0; cloglog's z<−37 → F=0 clamp flattens the low tail (log P ≈ z is still informative there). Only matters from extreme starts.
- `fast_adjacent_category_logit.cpp`: the docstring says log(P(k+1)/P(k)) = α_k + βᵀx, but the code implements −α_k + βᵀx (log_unnorm recurrence at :61-63). Harmless for β, but the sign of the reported `alpha` is opposite to the doc.
- `compute_adj_cat_logit_distr_parallel_cpp` fits replicates with Newton (tol 1e-8, zero start) while the observed statistic uses L-BFGS (tol 1e-8, f-plateau stop, OLS start). The two have different optimizer error. Both `*_distr_parallel_cpp` functions also add `delta` to y for treated units: for a non-integer delta this creates new distinct levels, so K changes per replicate. That is a semantics question, not an algorithm one, but worth confirming it is intended. Both call `omp_set_num_threads`, which changes the process-wide thread count.
- Stereotype docs say "nominal or ordinal … not their order", but the cumulative-softmax φ forces monotone scores in sorted-level order. This is the *ordered* stereotype model. The multistart plan's TODO-5 extra start "(i) sign-flipped φ→−φ, β→−β" cannot be represented in this parametrization (φ₁=0, φ_K=1 fixed, φ∈[0,1]), and its start (ii), equally spaced scores, is already the cold start (γ=0). The plan's line ref `:815` is stale (now `:724`).
- `compute_diagonal_inverse_entry` (LDLT) on an indefinite stereotype observed information (e.g. at a non-optimum) can return a finite *negative* ssq_b_1, and the profile fallback only fires on non-finite values (`fast_stereotype_logit.cpp:785`, `:1091`). The adjacent-category path already switched to the pseudo-inverse for exactly this reason (`:515-519`).
- Downstream (outside this group, flagged because of `expand_adjacent_category_data_cpp`): `inference_ordinal_KK_cond_logit_abstract.R:27-91` reports the clogit model-based `ssq_b_j` for the stacked adjacent-category composite likelihood, with no subject-clustered sandwich. Coverage of Wald CIs for `InferenceOrdinalKKCondAdjCatLogit*` should be checked. The CR expansion does not have this issue (its factorization is exact).

---

## 3. C++ — zero-inflated, hurdle, zero-one-inflated


Files: `R/EDI/src/fast_zinb.cpp`, `fast_zero_augmented_poisson.cpp` (ZAP = ZIP + hurdle-Poisson), `fast_zero_one_inflated_beta.cpp` (ZOIB), `fast_hurdle_negbin.cpp`, `fast_hurdle_poisson_glmm.cpp`. Sizes: n tens to low thousands, p_c/p_z (count / zero-part columns) in the single digits to tens, k = total parameters, D = number of distinct positive y, n+ = number of positive y, G groups, m = group size, K = GH nodes.

### Audit row B: corrections (read first)

`algorithm_choice_audit.md` row B says these five kernels run "joint Newton/L-BFGS on the full parameter vector … from a multistart set of cold starts", and that EM is the fix. Reading the code shows something different for each file:

| kernel | is the latent class real? | what the audit says | what the code actually does |
|---|---|---|---|
| ZINB (`fast_zinb.cpp:710`) | **yes**: a zero can be structural or sampling | joint + multistart | joint **L-BFGS** (default; Newton only if `optimization_alg != "lbfgs"`), **one** start (`:689-697`: β₀=log ȳ, all else 0, i.e. **π=0.5, θ=1**), **no multistart** (multistart is planned in `multistart_nonconcave_likelihoods.md` TODO-4, not built). After the fit, four boundary rescues run: the exact Poisson-limit accept (`:619`), a reduced ZIP refit (`:564`), a reduced π≡0 NegBin refit (`:388`), and a near-stationary accept (`:552`). Audit's line ref `:412` is stale (it now points inside the π-boundary fallback). EM is relevant: **audit row correct in substance**. |
| ZIP (`fast_zero_augmented_poisson.cpp:303`, `is_hurdle=FALSE`) | **yes** | joint + multistart | joint L-BFGS, **one** start (`zap_smart_cold_start`, `optimization_starts.h:132`: an untruncated Poisson fit on y>0 plus a logistic fit on 1[y=0]), no multistart. EM is relevant: **correct in substance**. |
| hurdle-Poisson (same kernel, `is_hurdle=TRUE`) | **no**: zero vs positive is *observed* | listed under B in the summary table | the likelihood **factorizes** (Mullahy 1986): `−log p` for zeros depends only on γ, and `log(1−p) + truncPois` for positives has β in the truncated part only. Both blocks are **strictly concave** (logistic, plus zero-truncated Poisson whose IRLS weight `λ(1−e^{−λ}−λe^{−λ})/(1−e^{−λ})² ≥ 0`), and the analytic Hessian is block-diagonal (`:121-138`). It is still fit **jointly** with L-BFGS. Separate fits by fixed-block refits are only the **R-level fallback** `fit_hurdle_poisson_components_independently` (`inference_count_zero_augmented_poisson_abstract.R:690-740`), which runs when the joint L-BFGS reports non-convergence. **EM does not apply. This model belongs in family A, not B.** |
| ZOIB (`fast_zero_one_inflated_beta.cpp:479`) | **no**: y==0, y==1 and 0<y<1 are *observed* categories | joint + multistart; EM plan TODO-6 designs a 3-responsibility E-step | joint L-BFGS, one OLS start, hardcoded `maxit=1500, tol=1e-6`. The likelihood **factorizes** exactly into (i) a 3-category multinomial logit in (γ₀, γ₁) on the observed category and (ii) a beta regression in (β, log φ) on the interior rows only (`operator()` `:94-147`; the Hessian `:179` has zero cross-blocks). This is the Ospina & Ferrari (2012) "inflated beta" two-part structure, **not a latent mixture**. EM "responsibilities" would be exactly 0/1, so EM collapses to one iteration of "fit the two parts separately". **`em_algorithm_zero_inflated_mixtures.md` TODO-6 is moot and should be replaced by the factorized fit (TODO candidate 2 below).** |
| hurdle-NegBin (`fast_hurdle_negbin.cpp:538`) | no | listed under B ("hurdle") | **Already exploits the factorization**: `fast_logistic_regression_internal` on 1[y>0] (`:567`), then an independent zero-truncated NB fit on the positives (`:620-658`) with a 12-start sequential fallback chain. Not a mixture. EM n/a. |
| hurdle-Poisson-GLMM (`fast_hurdle_poisson_glmm.cpp:520`) | no (the only nonconcavity is the RE variance) | in row B's title | **Exploits the factorization**: it fits *only* the truncated-Poisson count GLMM on positives (independent random intercepts per part make it separable, header `:3-5`). The zero part is never fit in C++; the R caller needs only the count-part treatment coefficient, and the glmmTMB fallback fits both. Nonconcavity comes from σ, i.e. **family C, not B**. EM n/a. |

Net: row B's EM recommendation applies to **ZINB and ZIP only**. Hurdle-Poisson and ZOIB are factorizable concave or near-concave two-part models (fit them separately). Hurdle-NB and the hurdle-Poisson GLMM already fit the parts separately. Row B's description should also drop "multistart" (none of these kernels has it today).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| fast_zinb.cpp:87 `ZeroInflatedNegBin::operator()` | ZINB NLL + analytic gradient | Eigen-batched exp/log (`:97-103`), distinct-y tables for lgamma/digamma(y+θ) (`:111-115`), two GEMVs | O(n(p_c+p_z)) + O(D) special functions per eval | B | Keep (objective). The fit around it is the TODO, see row `fast_zinb_internal` |
| fast_zinb.cpp:162 `ZeroInflatedNegBin::hessian` | observed information (SEs; Newton steps if alg≠lbfgs) | **numerical**: central differences of the analytic gradient (`numerical_hessian`, `_helper_functions_core.h:1079`, h=1e-4·max(1,\|x\|)), symmetrized. The file header's "analytic Hessian" claim (`:10`) is stale | 2k gradient evals = O(n k²); ~1e-7 relative FD error | A (linear-algebra/derivative choice) | Keep. Analytic is a low-priority accuracy nicety (cost is similar at k≈10). Under `newton_raphson` each Newton iteration costs ≈2k+1 evals, so L-BFGS default is right |
| fast_zinb.cpp:171 `poisson_limit_value_gradient` | exact θ→∞ (ZIP) limit objective/score, avoiding lgamma overflow | closed-form ZIP log-lik with softplus / log-add-exp | O(n k) | B (boundary) | Keep |
| fast_zinb.cpp:230 `ZipLimitLikelihood` (+ FD `hessian` :251, step 1e-5) | reduced ZIP model at θ=∞ | wrapper over the above; FD Hessian of analytic gradient | O(n k) / O(n k²) | B (boundary) | Keep |
| fast_zinb.cpp:275 `NegBinNoZiLikelihood` | reduced NB (π≡0) | plain NB log-lik; recomputes lgamma/digamma per observation (no distinct-y cache) | O(n p) + O(n) special functions | A | Keep (fallback-only path) |
| fast_zinb.cpp:388 `fit_zinb_zi_boundary_fallback` | detect π→0 for all obs (logit intercept →−∞) and refit the reduced model | predicate max η_z<−10 plus non-zi gradient small relative to `fit.gradient_norm`, then L-BFGS refit of NB | one extra fit | NEW-boundary-reduced-refit | Keep. This is the standard way to handle an MLE at infinity in logit coordinates. Note its test is relative to `5·gradient_norm` (heuristic) |
| fast_zinb.cpp:552 `accept_zinb_near_stationary_gradient` | accept a non-converged fit with ‖g‖<max(100·tol,1e-5) | threshold | O(1) | NEW-boundary-reduced-refit | Keep (heuristic, documented) |
| fast_zinb.cpp:564 `fit_zip_reduced_fallback` | θ→∞ boundary: refit reduced ZIP | L-BFGS on `ZipLimitLikelihood`, anchors log θ=log 1e4 | one extra fit | NEW-boundary-reduced-refit | Keep, but see TODO 4 (α=1/θ reparametrization would make this machinery unnecessary) |
| fast_zinb.cpp:619 `accept_zinb_poisson_boundary_convergence` | certify a run-away log θ as converging to the Poisson limit | limit score check + anchor comparison at θ=1e4 | 3 evals | NEW-boundary-reduced-refit | Keep (same note) |
| fast_zinb.cpp:672 `fast_zinb_internal` | ZINB MLE | **single** crude cold start (β₀=log ȳ, γ=0 ⇒ π=0.5, log θ=0) or warm start; joint L-BFGS (`optimize_fixed_likelihood`, `:710`); then the 4 fallbacks above. In resampling the R caller fixes (γ, log θ) at cached values (`inference_count_zero_augmented_poisson_abstract.R:807-815`), leaving only β_c free | L-BFGS iters × O(n k) | B | **Prototype**: `em_algorithm_zero_inflated_mixtures.md` TODO-3 (EM start), plus new TODO 1 (conditional-likelihood consistent start) and TODO 4 (α-parametrization) |
| fast_zinb.cpp:770/841 `fast_zinb_with_var_internal`, `fast_zinb_cpp` | vcov | FD Hessian (or ZIP-limit FD Hessian, zero-padded), free-block subset, `invert_free_information` (FullPivLU) | O(n k²)+O(k³) | A | Keep |
| fast_zero_augmented_poisson.cpp:45 `ZeroAugmentedPoisson::operator()` (ZIP branch `:80-93`) | ZIP NLL + gradient | per-obs loop, one shared exp(−η_z), two GEMVs | O(n k) | B | Keep (objective) |
| fast_zero_augmented_poisson.cpp:45 `operator()` (hurdle branch `:67-79`) | hurdle-Poisson NLL + gradient | same loop. Truncation normalizer `log(1−e^{−λ})` uses `log1p(-e^{−λ})` for λ>ln2, else `log(−expm1(−λ))`, the Mächler (2012) log1mexp switch (correct) | O(n k) | A (factorized; see corrections) | Keep (objective) |
| fast_zero_augmented_poisson.cpp:103 `hessian` | analytic observed information, both branches (hurdle: block-diagonal) | hand-rolled upper-triangle rank-1 accumulation | O(n k²) | A | Keep |
| fast_zero_augmented_poisson.cpp:193 `expected_hessian` | expected information | closed form | O(n k²) | A | Keep. **Dead code**: no optimizer or caller uses `expected_hessian` for this functor (`hessian_for_opt` uses `hessian`) |
| fast_zero_augmented_poisson.cpp:270 `fast_zap_internal` (ZIP) | ZIP MLE | `zap_smart_cold_start` (untruncated Poisson on positives, which is biased up for small λ, plus logistic on 1[y=0], which over-counts sampling zeros), joint L-BFGS | iters × O(n k) | B | **Prototype**: EM plan TODO-2 and new TODO 1 (truncated-Poisson conditional start is consistent for β under ZIP) |
| fast_zero_augmented_poisson.cpp:270 `fast_zap_internal` (hurdle) | hurdle-Poisson MLE | joint L-BFGS on a block-separable strictly concave objective; separate fits exist only as the R fallback | iters × O(n k) | A | **Prototype (low)**: TODO 3 (block-separate Newton/IRLS, same unique MLE) |
| fast_zero_augmented_poisson.cpp:317/481 `fast_zap_with_var_internal`, `fast_zero_augmented_poisson_cpp`; :360/:379 score/Hessian getters | vcov / getters | analytic Hessian + FullPivLU-guarded inversion; exception → diagnostic list | O(n k²)+O(k³) | glue | Keep |
| fast_zero_one_inflated_beta.cpp:76 `ZeroOneInflatedBeta::operator()` | ZOIB NLL + gradient | stable 3-way softmax per obs (`:100-107`) for (γ₀, γ₁); beta-regression log-lik on interior rows with `LgammaFunctor`/`DigammaFunctor` over n_b. **Wastes** `eta = X·β`, `mu = logistic(eta)`, `clamp_probs(mu)` over **all n** (`:84-86`), never used | O(n p) wasted + O(n p_zo) + O(n_b p) + 4·n_b special functions | NEW-two-part-factorization | Keep the objective; drop the dead `mu` (incidental) |
| fast_zero_one_inflated_beta.cpp:179 `hessian` | analytic observed information (block-diagonal: beta block plus 2×2-block multinomial) | per-obs rank-1 updates; `fast_trigamma_vec` | O(n_b p² + n p_zo²) | NEW-two-part-factorization | Keep |
| fast_zero_one_inflated_beta.cpp:298 `expected_hessian` | expected information | closed form over all n weighted by π_b | O(n(p²+p_zo²)) | — | Keep. **Dead code** (no caller) |
| fast_zero_one_inflated_beta.cpp:412 `fast_zero_one_inflated_beta_internal` | ZOIB MLE | start: OLS of logit(y) on interior rows for β, log φ=2, and **OLS (linear-probability) coefficients of 1[y=0] / 1[y=1] used directly as multinomial-logit γ** (scale mismatch: a probability-scale intercept 0.1 gives π₀≈0.36). Joint L-BFGS, maxit 1500, tol 1e-6 (looser than the 1e-8 used elsewhere). In resampling the R caller fixes (log φ, γ₀, γ₁) (`inference_proportion_zero_one_inflated_beta.R:486-497`), but `operator()` still loops all n over the fixed γ block | iters × O(n(p+p_zo)) | NEW-two-part-factorization | **Adopt** for the fixed-γ path (TODO 2a: pure work removal, same β-gradient); **Prototype** for the free fit (TODO 2b: separate multinomial-logit Newton + beta-regression Newton, same MLE) |
| fast_zero_one_inflated_beta.cpp:484/502/585 getters, `fast_zero_one_inflated_beta_cpp` | vcov | FullPivLU invert of the free block; NA on failure | O(k³) | glue | Keep |
| fast_hurdle_negbin.cpp:102 `smart_truncated_negbin_theta_start_from_beta` | θ start | Pearson moment α̂=Σ((y−μ)²−μ)/μ²/(n−p), **ignoring truncation** (biased, but only a start) | O(np) | A (start) | Keep |
| fast_hurdle_negbin.cpp:150 `make_truncated_negbin_candidate_starts` | deterministic start set | ≤3 β candidates (legacy, OLS log1p, OLS log) × θ ∈ {Pearson, moment, 10, 25}, deduplicated | O(S·np), S≤12 | A (start) | Keep |
| fast_hurdle_negbin.cpp:199 `fit_truncated_negbin_with_fallback` | robust truncated-NB fit | L-BFGS, then Newton from the best iterate, then fallback start, then each extra start (Newton, then L-BFGS). **Returns on the first converged run** (not best-of-all) | 1 fit typically; ≤~26 on failure | A | Keep (truncated NB is near-concave; first-converged is fine) |
| fast_hurdle_negbin.cpp:337 `TruncatedNegBinCount::operator()` | zero-truncated NB NLL + gradient | distinct-y lgamma/digamma tables. Normalizer: `p0 = exp(θ(log θ − log(θ+μ)))` **clamped to [1e-12, 1−1e-12]**, then `log(1−p0)` (or −p0 if p0<1e-7) | O(n+ p) + O(D) special functions | A | Keep the algorithm. Numerics are incidental (see below) |
| fast_hurdle_negbin.cpp:399 `TruncatedNegBinCount::hessian` | analytic observed information | distinct-y digamma/trigamma; `weighted_crossprod` | O(n+ p²) | A | Keep |
| fast_hurdle_negbin.cpp:474 `TruncatedNegBinCount::expected_hessian` | expected information | brute-force series over y=1..max(10000, μ+12 sd) **per observation**, building a 1-row functor and calling `hessian` for each y (heap allocations every term) | O(n+ · Y · p²), Y≥10⁴ | — | Keep. **Dead code** (no caller); if ever wired in, it would be pathologically slow |
| fast_hurdle_negbin.cpp:538 `fast_hurdle_negbin_internal` | hurdle-NB MLE + targeted variances | **factorized**: logistic on 1[y>0] (`fast_logistic_regression_internal`, L-BFGS by default, maxit 100), then truncated NB on positives; `negbin_information_spec` drops log θ at the Poisson boundary; `compute_diagonal_inverse_entry` (LDLT single-RHS solve) for ssq | O(n p_h) + iters × O(n+ p) + O(p³) | NEW-two-part-factorization | **Keep**: the best-known approach (Mullahy 1986; same as `pscl::hurdle`) |
| fast_hurdle_negbin.cpp:735 `fast_truncated_negbin_count_internal` (+ getters :867/:889, wrappers :909/:1032/:1057) | count part only | same as above | same | A | Keep |
| fast_hurdle_poisson_glmm.cpp:42 `gauss_hermite_rule_hp` | GH nodes/weights | Golub–Welsch (1969): dense `SelfAdjointEigenSolver` on the K×K Jacobi matrix. **Duplicate** of `glmm::gauss_hermite_rule` (`_glmm_engine.h:32`) | O(K³), K=7, rebuilt per data construction | C | Keep (trivial at K=7); dedupe is incidental |
| fast_hurdle_poisson_glmm.cpp:57/63/69 `soft_barrier_hp*` | keep log σ off ±∞ | quadratic penalty outside \|log σ\|≤5, subtracted back out of the reported NLL/score/information | O(1) | C | Keep |
| fast_hurdle_poisson_glmm.cpp:75 `log_one_minus_exp_neg_hp` | truncation normalizer log(1−e^{−λ}) | λ<1e-10: log λ; e^{−λ}<1e-7: −e^{−λ}; else `log1p(−e^{−λ})`. **Not** the log1mexp switch: loses relative precision for 1e-10<λ≲0.7 (≈1e-16/λ relative) | O(1) | C | Keep (incidental fix: `log(−expm1(−λ))` for λ<ln2) |
| fast_hurdle_poisson_glmm.cpp:138 `HurdlePoissonGLMMData` | group layout | `stable_sort` by group id; per-group weight = **mean of row weights** | O(n log n) | glue | Keep (weights note is incidental) |
| fast_hurdle_poisson_glmm.cpp:226 `HurdlePoissonGLMMObjective::operator()` | marginal NLL + score of the zero-truncated Poisson GLMM (random intercept) | **non-adaptive K=7** GH (default `n_gh=7`, R caller never overrides it, `inference_count_KK_cond_poisson.R:349`); multiplicative exp sharing λ_ik=e^{η_i}·e^{b_k}; fused log-sum-exp; one GEMV per group | O(n+ K p) per eval | C | **Prototype (accuracy)**: TODO 5. NB: `performance_profiling_and_upgrades.md` TODO-153 (adaptive GH) is scoped to `_glmm_engine.h` "n_gh=20" and **does not cover this file** (own GH implementation, K=7) |
| fast_hurdle_poisson_glmm.cpp:319 `hessian` | observed information of the marginal likelihood | **Louis (1982) identity** per group: −E[H]−E[GGᵀ]+E[G]E[G]ᵀ under node posteriors; analytic per-node H incl. log σ chain rule | O(n+ K p² + G K p²) | C | Keep (exact for the quadrature-approximated likelihood) |
| fast_hurdle_poisson_glmm.cpp:435 `fast_hurdle_poisson_glmm_internal` (+ wrapper :806) | count-part GLMM MLE | filter positives; start = OLS of log y, log σ=−3; L-BFGS maxit 300, eps 1e-6; vcov via `covariance_from_information` | iters × O(n+ K p) | C | Keep (factorization exploited); quadrature → TODO 5 |
| fast_hurdle_poisson_glmm.cpp:607–803 six `get_hurdle_poisson_glmm_*_cpp` getters (weighted/unweighted score, Hessian, NLL) | per-call evaluation for an **R-level `stats::optim(BFGS)`** objective (`inference_count_KK_cond_poisson.R:931-1190`) | each call re-filters positives, re-sorts groups (O(n log n)) and re-runs Golub–Welsch | per R-iteration overhead O(n log n + K³) | glue | Keep (overhead is small at K=7; see incidental note) |

### Options & disadvantages

**P1. ZINB / ZIP latent-mixture MLE** (`fast_zinb.cpp:672`, `fast_zero_augmented_poisson.cpp:270` ZIP)

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| ZINB/ZIP MLE | **current**: one crude start + joint L-BFGS + boundary rescues | — | no monotone-ascent guarantee; π=0.5/θ=1 start is far from typical optima; ~400 lines of boundary-specific rescue logic (`fast_zinb.cpp:319-668`) grew one CI failure at a time | — |
| | joint Newton (analytic or FD Hessian) | fewer iterations, but ZINB's FD Hessian costs 2k+1 evals per iteration | indefinite Hessian away from the optimum; current Newton has no modified-Cholesky / trust region (`_helper_functions_core.h:1390`: FullPivLU solve + halving), so it breaks and falls back to L-BFGS | Nocedal & Wright 2006 |
| | **EM (Lambert 1992)** as start generator, Newton/L-BFGS polish | ~0.8–1.0× on easy fits (linear-rate warm-up); converts some failed fits to converged | still local; slow near boundary (π→0 or θ→∞ makes EM *crawl*, linear rate→1), so EM does **not** by itself remove the boundary rescues. Needs a weighted NB M-step (θ inside E- and M-step) | Lambert 1992 *Technometrics*; Dempster, Laird & Rubin 1977; Redner & Walker 1984 |
| | EM + acceleration (SQUAREM; quasi-Newton EM) | 2–10× fewer EM iterations than plain EM (literature-typical) | loses strict monotonicity unless safeguarded; more code | Varadhan & Roland 2008 *Scand. J. Stat.*; Jamshidian & Jennrich 1997 *JRSS-B* |
| | **conditional-likelihood consistent start** (TODO 1): fit zero-truncated count model on y>0 (Y\|Y>0 ~ ZT-NB(μ,θ) **does not depend on π**), then a γ intercept from the zero-excess | one concave or near-concave fit (kernels already exist: `fast_truncated_negbin_count_internal`, ZAP hurdle branch); from a √n-consistent start Newton reaches the MLE in ~1–3 steps (one-step-estimator argument) | fails or is noisy when n+ ≤ p_c or n+ is tiny (heavy zero mass), so fall back to the current start; requires X_c columns identified on positives alone; still a local method | Mullahy 1986 *J. Econometrics*; Lehmann & Casella 1998 *Theory of Point Estimation* (one-step estimators) |
| | multistart (planned) | ×S cost | cost scales with S; does not fix boundary runaway | `multistart_nonconcave_likelihoods.md` TODO-4 |
| | Bayesian / MCMC data augmentation | ≫ slower | not an MLE; RNG-dependent | [n/a for EDI] |

**P2. Hurdle-Poisson and ZOIB: factorized two-part likelihoods** (`fast_zero_augmented_poisson.cpp:270` hurdle, `fast_zero_one_inflated_beta.cpp:412`)

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| two-part MLE | **current**: joint L-BFGS on the concatenated vector | — | L-BFGS memory mixes curvature of independent blocks; condition number = worst block; hurdle needs an R-side block-refit fallback when the joint stopping rule misfires (`inference_count_zero_augmented_poisson_abstract.R:690`); ZOIB loops over all n for γ even when γ is fixed | — |
| | **block-separate fits** (logistic or multinomial-logit Newton/IRLS + truncated-Poisson IRLS / beta-regression Newton) | each block concave (or near-concave for beta (β, log φ)): Newton ~5–8 iterations vs typical L-BFGS 20–60 on the joint vector. ~1.5–3× fewer evaluations, unmeasured | same MLE (unique by strict concavity for hurdle-Poisson; for ZOIB the beta block is the only non-concave piece either way); results equal within tol but **not bit-identical** (different iterate path), so existing tests are the gate; the zero part becomes redundant work when only the count/β treatment effect is needed | Mullahy 1986; Ospina & Ferrari 2012 *CSDA*; Ferrari & Cribari-Neto 2004 *J. Appl. Stat.*; precedent `pscl::hurdle` (Zeileis, Kleiber & Jackman 2008 *JSS*) |
| | closed-form zero part when X_zo / X_z is intercept-only | O(n) instead of an iterative fit: γ₀=log(n₀/n_b), γ₁=log(n₁/n_b) (ZOIB); γ=logit(n₀/n) (hurdle) | only for intercept-only zero designs; must still match the fixed-idx semantics | exact MLE of a saturated multinomial |
| | EM | — | **not applicable**: no latent class (categories observed) | — |

**P3. NB dispersion parametrization** (ZINB `log θ`, truncated NB `log θ`)

| problem | option | speed vs current | disadvantages / risks | citation |
|---|---|---|---|---|
| θ→∞ (Poisson) boundary | **current**: unconstrained log θ + boundary detectors/rescues at log θ ≥ log 1e4 | — | the boundary sits at infinity, so the optimizer runs away and is reported as non-converged; NaN from lgamma cancellation; much bespoke code | `bug_fix_plans/negbin_dispersion_convergence.md` |
| | **α = 1/θ ≥ 0 with bound-constrained L-BFGS-B**, log-pmf via the finite sum lgamma(y+1/α)−lgamma(1/α)=Σ_{j<y}log(1/α+j) ⇒ Σ log(1+jα) − y log α, and (1/α)·log1p(αμ) | boundary becomes a finite KKT point (α=0 is exactly Poisson); 1 fit replaces fit + up to 3 rescue fits | changes the optimizer path (A/B needed); Wald SE at α=0 is a boundary case anyway (same as now); finite sum is O(max y) per distinct y, which must be cached; LBFGSpp's `LBFGSBSolver` must be wired into `optimize_fixed_likelihood` | Lawless 1987 *Can. J. Stat.*; Byrd, Lu, Nocedal & Zhu 1995 *SIAM J. Sci. Comput.*; Self & Liang 1987 *JASA* (boundary inference) |
| | profile θ (alternate β-IRLS / 1-D θ Newton, as in `MASS::glm.nb`) | similar | alternation is linearly convergent; same boundary-at-∞ issue unless done in α | Venables & Ripley 2002 *MASS* |

**P4. Random-intercept integral in the truncated-Poisson GLMM** (`fast_hurdle_poisson_glmm.cpp:226`)

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| ∫ Π_j ZTPois(y_j; e^{η_j+u}) φ(u;σ) du per pair | **current**: non-adaptive GH, K=7 | — | **inaccurate when the conditional posterior of u is much narrower than σ**: Poisson counts carry ~Σλ information, e.g. λ≈10 in a pair gives posterior sd ≈0.22 vs node spacing ≈0.58 at σ=0.5. Error grows with counts and σ, not only with small clusters | Liu & Pierce 1994 *Biometrika* |
| | non-adaptive GH, K=20 | ~3× slower | fixes moderate cases only; same failure at large counts | — |
| | **adaptive GH** (AGQ, K=3–7 centered and scaled at the per-group mode) | ~1–1.5× per eval (1-D Newton mode search ~3–5 its × m per group, offsets the node saving); large accuracy gain | gradient must account for mode dependence (or use fixed-mode trick per outer iteration); more code; changes results (A/B with an equivalence metric vs high-K reference) | Pinheiro & Bates 1995 *JCGS*; Liu & Pierce 1994 |
| | Laplace (AGQ K=1) | ~3–7× faster than K=7 | biased for small counts × tiny clusters (m≤2 after dropping zeros here); usually fine for moderate/large Poisson counts; glmmTMB (the R fallback) already uses Laplace, so it is a natural reference | Joe 2008 *CSDA*; Brooks et al. 2017 *R Journal* (glmmTMB) |
| | closed form | n/a | no conjugacy for truncated Poisson × normal | — |

### New TODO candidates

1. **Conditional-likelihood (truncated-count) consistent start for ZINB and ZIP.** Where: `fast_zinb.cpp:689-697` and `fast_zero_augmented_poisson.cpp:286-287` (ZIP only). What: fit ZT-NB (`fast_truncated_negbin_count_internal`) / ZT-Poisson (ZAP hurdle objective with γ fixed) on y>0 to get (β_c, θ) consistently. Then set the γ intercept to logit(max(0.01, (f₀ − mean p0(μ̂,θ̂))/(1 − mean p0))), where f₀ is the observed zero fraction. Pass this as the start (or as one more deterministic start in the planned multistart set; it improves on `multistart_nonconcave_likelihoods.md` line 298, which uses the cold-start β). Expected win (theoretical): fewer L-BFGS iterations, and fewer boundary-rescue invocations because the start is √n-consistent; current start π=0.5/θ=1 is far off. Risk: n+ ≤ p_c, or near-all-zero data, means the start is unavailable (fall back). Needs A/B harness (changes optimizer path). It composes with, and is cheaper than, `em_algorithm_zero_inflated_mixtures.md` TODO-2/3; compare them head-to-head in that plan's TODO-5.
2. **Exploit ZOIB factorization.** (a) **Adopt**: when the whole γ block is fixed (resampling path, `inference_proportion_zero_one_inflated_beta.R:486-497`), skip the softmax loop in `operator()` (`fast_zero_one_inflated_beta.cpp:95-131`); it contributes a constant to the NLL and zero to the β/φ gradient. Also delete the unused all-n `eta/mu/clamp_probs` (`:84-86`). Deterministic, β-gradient identical (NLL differs by a constant, so line-search comparisons are unchanged up to rounding). Win: removes O(n·p_zo)+3n exp/log plus O(np) per eval, theoretically ~30–50% of per-eval cost at typical n_b/n. Gate: existing ZOIB tests. (b) **Prototype**: for free fits, fit multinomial-logit (γ₀,γ₁) by Newton and beta regression (β, log φ) separately (closed form for intercept-only X_zo). Same MLE within tol. Win ~1.5–3× fewer evaluations (theoretical). Also fix the LPM-as-logit start scale (`:457-460`). **Replace `em_algorithm_zero_inflated_mixtures.md` TODO-6 (ZOIB EM) with this; EM is inapplicable.**
3. **Hurdle-Poisson: block-separate Newton (or joint Newton on the existing block-diagonal analytic Hessian) as the primary fit.** Where: `fast_zero_augmented_poisson.cpp:303` when `is_hurdle`. Strictly concave, so the MLE is unique and identical within tol. Expected: ~1.5–3× fewer evals (theoretical) and removal of the need for the R-level `fit_hurdle_poisson_components_independently` rescue. Risk: low; different iterate path, so not bit-identical. Gate: existing hurdle tests plus `pscl::hurdle` equivalence. Could be Adopt after a timing check; listed as Prototype only because the speed is unmeasured. Also **update audit row B** to move hurdle-Poisson (and ZOIB) out of the "mixture/EM" family.
4. **α = 1/θ bound-constrained parametrization for NB dispersion** (ZINB `fast_zinb.cpp:88-89`, truncated NB `fast_hurdle_negbin.cpp:339`). Finite-sum log-pmf plus L-BFGS-B (LBFGSpp ships `LBFGSBSolver`). Expected: the Poisson boundary becomes an ordinary converged KKT point at α=0, which could retire `accept_zinb_poisson_boundary_convergence`, `fit_zip_reduced_fallback` and `accept_negbin_poisson_boundary_convergence` for these kernels (robustness more than speed). Risk: large change, optimizer-path change, and reported θ at the boundary becomes ∞ (α=0) rather than 1e4. Needs A/B harness plus the `negbin_dispersion_convergence.md` fixture.
5. **Adaptive GH (or Laplace) for the truncated-Poisson GLMM.** Where: `fast_hurdle_poisson_glmm.cpp:226/319` (own GH, K=7, not covered by TODO-153). First **Investigate**: measure the K=7 non-adaptive quadrature error against K=50 non-adaptive / AGQ-20 on high-count pairs (λ≥10, σ∈{0.5,1,2}). If the error is material, Prototype AGQ (K=5) reusing whatever TODO-153 builds in `_glmm_engine.h`, preferably by porting this objective onto the engine and deleting the duplicate GH/barrier code. Win is accuracy, not speed (~1×). Needs A/B with an equivalence metric against a high-K reference.

### Incidental findings (optional)

- `fast_zinb.cpp:10` header says "analytic Hessian"; `hessian()` (`:162`) is finite-difference.
- `fast_zinb.cpp:102`, `fast_hurdle_negbin.cpp:366`: `θ·(log θ − log(θ+μ))` has cancellation for θ≫μ. Use `−θ·log1p(μ/θ)`. `fast_hurdle_negbin.cpp:368-371`: p0 clamped at 1−1e-12 and `log(1−p0)` both lose precision as μ→0. Use `log1mexp(log_p0)` (Mächler 2012). The 1e-12 clamp biases the truncated likelihood for tiny μ.
- `fast_zero_augmented_poisson.cpp:78,130`: gradient/Hessian use `1−e^{−λ}` (not `−expm1(−λ)`), so there is cancellation for small λ in the hurdle score and `h_cond` (the objective itself is fine). Same at `fast_hurdle_poisson_glmm.cpp:305,392-394` and in `log_one_minus_exp_neg_hp` (`:78`) for 1e-10<λ<ln2.
- Dead code: `ZeroAugmentedPoisson::expected_hessian` (`:193`), `ZeroOneInflatedBeta::expected_hessian` (`:298`), `TruncatedNegBinCount::expected_hessian` (`fast_hurdle_negbin.cpp:474`, O(n·10⁴·p²) with per-term allocations).
- `R/helper_zoib.R:88-128` `.fit_zero_one_inflated_beta`: no callers found, and it tests `length(fit$coefficients) == 0L`, but `fast_zero_one_inflated_beta_cpp` returns no `coefficients` element, so it would always return NULL if ever called.
- `fast_zero_one_inflated_beta.cpp:479`: maxit/tol hardcoded (1500, 1e-6), unlike siblings (1000, 1e-8).
- `fast_hurdle_negbin.cpp:567-571`: hurdle logistic part inherits the count part's `optimization_alg` (L-BFGS by default) with hardcoded maxit=100, whereas IRLS is the family-A optimum for logistic.
- `fast_hurdle_poisson_glmm.cpp:176-178`: row weights are collapsed to a per-group mean weight applied to the whole group log-likelihood. Within-pair unequal weights are not honored per observation.
- `R/inference_count_KK_cond_poisson.R:931-952`: the "combined" KK hurdle likelihood uses a **zero-truncated** Poisson GLMM on matched positives but an **untruncated** Poisson (zeros included) on the reservoir. Possible model inconsistency; verify intent. Same function (`:1167-1172`): the `method = if (...) "BFGS" else "BFGS"` ternary is a no-op, and each R-optim iteration re-sorts groups and recomputes GH nodes via the getters.
- `fast_hurdle_poisson_glmm.cpp:42-55,57-73` duplicate `glmm::gauss_hermite_rule` and the engine's σ-barrier, so engine-level improvements (TODO-153) will silently not reach this kernel.

---

## 4. C++ — GLMM, LMM, clogit+GLMM, GEE, KK combined designs


Files covered (all `R/EDI/src/`): `_glmm_engine.h`, `_glmm_links.h`, `fast_logistic_glmm.cpp`, `fast_poisson_glmm.cpp`, `fast_gaussian_lmm.cpp`, `fast_ordinal_glmm.cpp`, `fast_ordinal_clmm.cpp`, `fast_clogit_plus_glmm.cpp`, `fast_gee.cpp`, `build_kk_combined_clogit_design.cpp`, `build_kk_combined_ols_design.cpp`. Notation: n obs, G groups (KK: pairs of size 2 plus reservoir singletons, so m_g ∈ {1,2} everywhere except where noted), p fixed effects, K ordinal levels, n_gh quadrature nodes (default 20), d = number of free parameters.

### Row C per-file confirmation (fixed 20-node GH vs adaptive GH vs Laplace)

| file | how the random intercept is integrated out | n_gh | adaptive (mode-centred) nodes? | Laplace / PQL anywhere? |
|---|---|---|---|---|
| `_glmm_engine.h:158,192` (`GLMMObjective`, used by `fast_ordinal_clmm.cpp`) | non-adaptive Gauss–Hermite: nodes `b_k = √2·σ·z_k`, centred at 0, scaled only by σ; per-group log-sum-exp | caller arg, 20 by default | **No** | No |
| `fast_logistic_glmm.cpp:155,185` | own non-adaptive GH (own copy of the rule, `:39`) | `n_gh=20` default (`:468`) | **No** | No |
| `fast_poisson_glmm.cpp:189,248` | own non-adaptive GH (`:45`) | `n_gh=20` default (`:342`) | **No** | No |
| `fast_ordinal_glmm.cpp:111` | non-adaptive GH, rule taken from the engine, own objective loop | `n_gh=20` default (`:255`) | **No** | No |
| `fast_ordinal_clmm.cpp:92` | engine `GLMMObjective<OrdinalLikelihood<Link>>`, links logit/probit/cauchit/cloglog | `n_gh=20` default (`:162`) | **No** | No |
| `fast_clogit_plus_glmm.cpp:156,228` | own non-adaptive GH (`:40`) for the concordant/reservoir GLMM part; the discordant-pair part needs no integral (closed-form conditional likelihood) | 20 (the R export hard-codes `20` at `:694`; score/Hessian exports at `:455,:483` hard-code it too) | **No** | No |
| `fast_gaussian_lmm.cpp:121` | **no quadrature**: the closed-form Gaussian marginal likelihood, using the compound-symmetry Sherman–Morrison form per group | — | — | — |

So the audit's row C is right for every non-Gaussian file. All five use **fixed, non-adaptive 20-node GH**, and none uses Laplace or PQL. The Gaussian LMM was never a quadrature kernel.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| `_glmm_engine.h:32` `gauss_hermite_rule` | GH nodes and weights | Golub–Welsch: a dense `SelfAdjointEigenSolver` on the n_gh×n_gh Jacobi matrix; log-weights normalised to N(0,1). Rebuilt on every `GLMMData` construction, so once per fit and once per score/Hessian export call | O(n_gh³) per fit (20³) | NEW-gh-rule | **Adopt** (cache it; TODO-1) |
| `fast_logistic_glmm.cpp:39` `gauss_hermite_rule_log`; `fast_poisson_glmm.cpp:45` `gauss_hermite_rule_poisson`; `fast_clogit_plus_glmm.cpp:40` `gauss_hermite_rule` | same | three byte-for-byte duplicates of the Golub–Welsch code above | same | NEW-gh-rule | **Adopt** (TODO-1) |
| `_glmm_engine.h:47,56` `log_sum_exp`, `log_sum_exp_and_weights` | stable log ∑ exp over nodes, plus the posterior node weights | max-shift log-sum-exp, fused with the weight normalisation (copies also at `fast_logistic_glmm.cpp:54`, `fast_poisson_glmm.cpp:60`, `fast_clogit_plus_glmm.cpp:23`) | O(n_gh) per group | C (component) | Keep |
| `_glmm_engine.h:73` `GLMMData` ctor (likewise `LogisticGLMMData:98`, `PoissonGLMMData:98` (also precomputes `lgamma(y+1)`), `LMMData:52`, `OrdinalGLMMData:47`) | contiguous group layout | `std::stable_sort` of row indices by group id, then a run-length scan | O(n log n) | NEW-group-layout | Keep |
| `_glmm_engine.h:112-136` `sigma_penalty*`, `glmm_variance_boundary_hit` (copies at `fast_logistic_glmm.cpp:71-87`, `fast_poisson_glmm.cpp:66-82`) | keep log σ finite | soft quadratic barrier 10·(\|log σ\|−5)² beyond \|log σ\|>5, subtracted from the reported NLL afterwards; a hard 1e100 wall at `max_abs_log_sigma` only in `value()` | O(1) | NEW-vc-boundary | Prototype (low; options T4) |
| `_glmm_engine.h:158` `GLMMObjective::value` | GLMM marginal NLL | fixed non-adaptive GH (see the table above) | O(n·n_gh) link evaluations | C | Keep-tracked (`performance_profiling_and_upgrades.md` TODO-153; see the caveat in T1) |
| `_glmm_engine.h:192` `GLMMObjective::operator()` | NLL plus analytic gradient | per node: model `log_prob_derivs`; posterior node weights p_k; gradient = ∑_k p_k·(node score), including ∂b_k/∂log σ = b_k | O(n·n_gh·(1+n_model)) + O(G·n_gh·m_g·p) | C | Keep-tracked (TODO-153) |
| `_glmm_engine.h:248` `GLMMObjective::hessian` (used for vcov by `fast_ordinal_clmm.cpp:127`) | observed information | `numerical_hessian` (`_helper_functions_core.h:1079`): central differences of the analytic gradient, h = 1e-4·max(1,\|θ_i\|), then symmetrised | 2d gradient evaluations | NEW-glmm-obs-info | **Adopt** (Louis identity; TODO-2) |
| `_glmm_links.h:21,35,42,49` `LogitLink`/`ProbitLink`/`CauchitLink`/`CloglogLink` | link cdf, pdf, pdf′ | closed forms; `pdf_from_cdf` reuses F | O(1) | glue-level | Keep (precision notes under Incidental findings) |
| `fast_logistic_glmm.cpp:155` `LogisticGLMMObjective::value` | logistic GLMM NLL | fixed GH; uses the sufficient sums y′η and ∑y per group; vectorised softplus | O(n·n_gh) | C | Keep-tracked (TODO-153) |
| `fast_logistic_glmm.cpp:185` `operator()` | NLL plus gradient | same, plus posterior-weighted residuals | O(n·n_gh + n·p) | C | Keep-tracked |
| `fast_logistic_glmm.cpp:254` `hessian` | observed information | **analytic, via the Louis identity**: −(E_p[H_k] + E_p[g gᵀ] − E_p[g]E_p[g]ᵀ) per group, over the posterior node weights | O(n·n_gh·p²) | NEW-glmm-obs-info | Keep |
| `fast_logistic_glmm.cpp:460` `fast_logistic_glmm_internal` | outer MLE | L-BFGS by default (`"newton"` can be selected), **single start** (OLS β on y, log σ = −3); vcov = inverse of the observed information | iterations × O(n·n_gh) | A / C | Prototype (default optimizer only; TODO-6) |
| `fast_poisson_glmm.cpp:189` `PoissonGLMMObjective::operator()` | Poisson GLMM NLL plus gradient, optional row weights (weighted pseudo-likelihood) | fixed GH, vectorised exp over all n per node, lgamma precomputed (the class has no `value()`) | O(n·n_gh·p) | C | Keep-tracked (TODO-153) |
| `fast_poisson_glmm.cpp:248` `hessian` | observed information | analytic Louis identity (β-β block via `weighted_crossprod` over all n per node) | O(n·n_gh·p²) | NEW-glmm-obs-info | Keep |
| `fast_poisson_glmm.cpp:334` `fast_poisson_glmm_internal` | outer MLE | L-BFGS, single start (QR-OLS on log(y+0.5), log σ = −3); LDLT inverse | iterations × O(n·n_gh·p) | A / C | Prototype (TODO-6) |
| `fast_gaussian_lmm.cpp:121` `neg_ll_and_grad` | Gaussian random-intercept **ML** marginal NLL plus gradient | **closed form, no quadrature.** Per group: a_g = v_e + m_g·v_b, S_g = ∑r, Q_g = ∑r², W_g = Q_g − (v_b/a_g)·S_g² (Sherman–Morrison on the compound-symmetry V_g); analytic gradient | **O(n·p) per evaluation** | NEW-lmm-closed-form | Keep (this already is the O(n) Woodbury form the question asks about) |
| `fast_gaussian_lmm.cpp:207` `lmm_P_analytic` | V_g⁻¹ for m ∈ {1,2} | closed-form 2×2 inverse, stack-allocated | O(1) | NEW-lmm-closed-form | Keep |
| `fast_gaussian_lmm.cpp:221` `lmm_analytic_hessian` | observed information | analytic: β-β = ∑XᵀPX; β-θ and θ-θ via dP = −P·dV·P and the trace identities | O(n·p²) | NEW-lmm-closed-form | Keep |
| `fast_gaussian_lmm.cpp:360` `make_start` | start values | OLS via normal-equation LDLT; σ_e from the RSS; σ_b = σ_e/2 | O(n·p²) | A | Keep |
| `fast_gaussian_lmm.cpp:387` `fast_gaussian_lmm_internal` | outer ML fit | **joint L-BFGS over (β, log σ_e, log σ_b)**. Not profiled (β is not concentrated out; no 1-D search over σ_b²/σ_e²); ML, not REML; vcov from the analytic Hessian | iterations × O(n·p) | NEW-lmm-closed-form | **Prototype** (profiled 1-D Brent, optional REML; TODO-3) |
| `fast_gaussian_lmm.cpp:557` `fast_gaussian_lmm_gls_cpp` | GLS β at fixed variance components | normal equations ∑_g w_g[X_gᵀX_g − c_g·s_x s_xᵀ] with c_g = v_b/a_g, solved by LDLT | O(n·p² + p³) | NEW-lmm-closed-form | Keep (the building block for TODO-3) |
| `fast_ordinal_glmm.cpp:111` `OrdinalGLMMObjective::operator()` | cumulative-logit random-intercept NLL plus gradient | fixed GH; cutpoints reparameterised as (α₁, log-diffs); hard clamp on log σ plus a 1e4·Δ² penalty; the α-gradient loop is O(K) per observation | O(n·n_gh·(p+K)) | C | Keep-tracked (TODO-153) |
| `fast_ordinal_glmm.cpp:220` `hessian` | observed information | central differences of the analytic gradient, absolute h = 1e-4 | 2d gradient evaluations (d = K+p) | NEW-glmm-obs-info | **Adopt** (Louis identity; TODO-2) |
| `fast_ordinal_glmm.cpp:247` `fast_ordinal_glmm_internal` | outer MLE | **multistart**: up to 5 log σ starts {cold, −1, 0, 1, −max} × L-BFGS → L-BFGS polish (tol 1e-10) → a damped-Newton polish that uses the **finite-difference Hessian** (Armijo backtracking, ≤50 iterations), triggered only if the projected gradient is still above max(1e-5, eps_g); KKT projection at the lower σ boundary | ≈ (5 + polish)·L-BFGS runs + up to 50·2d gradients | A + multistart | Keep-tracked (`multistart_nonconcave_likelihoods.md`); the Newton polish gets cheaper with TODO-2 |
| `fast_ordinal_clmm.cpp:25` `OrdinalLikelihood<Link>::log_prob(_derivs)` | per-observation interval probability F(α_up−η) − F(α_lo−η), with derivatives | direct subtraction, floored at 1e-15; cutpoint gradient by suffix | O(K) per observation per node | C (component) | Keep (Probit: see T1 option "closed form") |
| `fast_ordinal_clmm.cpp:92` `run_fast_ordinal_clmm` | outer MLE, 4 links | engine objective; L-BFGS, **single start** (all-zero cutpoints and β, log σ = −3); vcov from the engine's numerical Hessian | iterations × O(n·n_gh·(p+K)) | A / C | Keep-tracked (TODO-153); Prototype for probit (TODO-4) |
| `fast_clogit_plus_glmm.cpp:148` `neg_clogit` (gradient `:211`, Hessian `:298`) | exact conditional likelihood of 1:1 matched discordant pairs | **closed form**: P(config \| pair sum = 1) = expit((x₁−x₂)ᵀβ), i.e. no-intercept logistic on within-pair differences; Fisher information XᵀWX, exact | O(n_d·p) per evaluation, O(n_d·p²) for the Hessian | NEW-matched-pair-clogit | Keep (Gail–Lubin–Rubinstein and enumeration both reduce to this 2-term sum when m=2) |
| `fast_clogit_plus_glmm.cpp:156,228` `neg_glmm` / `operator()` GLMM part | logistic random intercept on concordant pairs plus reservoir | fixed 20-node GH | O(n_c·n_gh) | C | Keep-tracked (TODO-153) |
| `fast_clogit_plus_glmm.cpp:293` `hessian` (GLMM part) | observed information | analytic Louis identity, plus the exact clogit block | O(n_c·n_gh·p²) | NEW-glmm-obs-info | Keep |
| `fast_clogit_plus_glmm.cpp:503` `fast_clogit_plus_glmm_internal` | outer joint MLE (shared β) | L-BFGS from an all-zero start (log σ = 0), single start | iterations × O((n_d + n_c·n_gh)·p) | A / C | Prototype (TODO-6) |
| `fast_gee.cpp:62` `gee_solve_system` | solve the scoring system | LDLT on the symmetrised matrix, falling back to `colPivHouseholderQr` | O(p³) | A | Keep |
| `fast_gee.cpp:76` `gee_estimate_exchangeable_alpha` | working correlation | Liang–Zeger moment estimator over pair Pearson products (√(w_i w_j)-weighted), clamped to ±0.95; **no φ̂ scaling, no −p df** | O(n) | K | Keep the algorithm; see the possible bug under Incidental findings |
| `fast_gee.cpp:103` `gee_fit_independence_glm` | starting β | IRLS logistic/Poisson (`fast_*_regression_internal`), with an intercept-only fallback | O(n·p²) per iteration | A | Keep |
| `fast_gee.cpp:118` `gee_pairs_singletons_cpp_impl` | solve the GEE U(β) = ∑DᵀV⁻¹(y−μ) = 0 | Fisher scoring (modified Gauss–Newton), with α re-estimated by moments every iteration (Liang–Zeger alternation); closed-form 2×2 V_g⁻¹; stop when ‖U‖ < 1e-8 (absolute); then sandwich vcov B⁻¹MB⁻¹ (model bread, empirical meat). Clusters ≤ 2 are enforced (`:130`) | O(n·p²) per iteration | K | Keep |
| `build_kk_combined_clogit_design.cpp:9` `find_discordant_pairs` | pair up strata and keep the discordant ones | single pass with an `unordered_map` (first member → index); difference rows; a 3rd or later member is silently skipped | O(n·p) | NEW-design-assembly | Keep |
| `build_kk_combined_clogit_design.cpp:93` `build_matching_combined_clogit_design_cpp` | stacked conditional-pairs plus marginal-reservoir logistic design | rows [0 \| ΔT \| ΔX] stacked with [1 \| w \| X] | O((n_d+n_R)·p) | NEW-design-assembly | Keep (statistical note under Incidental findings) |
| `build_kk_combined_ols_design.cpp:160` `build_matching_combined_ols_design_cpp` | stacked pair-difference plus reservoir OLS design | pair rows scaled by 1/√2 (assumes Var(pair diff) = 2σ² and Var(reservoir) = σ²) | O((m+n_R)·p) | NEW-design-assembly | Keep (no production caller; see Incidental findings) |
| glue — `_glmm_engine.h` none beyond the above; `fast_logistic_glmm.cpp:374,404,433,626`; `fast_poisson_glmm.cpp:471,515,545`; `fast_gaussian_lmm.cpp:511,627,674`; `fast_ordinal_glmm.cpp:235` (OLS start), `:571,606,624,642,757`; `fast_ordinal_clmm.cpp:154` (link dispatch), `:213`; `fast_clogit_plus_glmm.cpp:193` (`value`), `:435,463,659`; `fast_gee.cpp:34-58` (variance/link/quasi-loglik helpers), `:275,322` (grouping by `std::sort`); `build_kk_combined_clogit_design.cpp:52` | Rcpp wrappers, argument checks, data marshalling | — | — | glue — no algorithmic content | — |

### Options & disadvantages

**T1. Integrating out the random intercept (row C; logistic, Poisson, ordinal-logit, CLMM ×4 links, the GLMM part of clogit+GLMM; m_g ≤ 2)**

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| GLMM marginal likelihood | **current**: fixed non-adaptive 20-node GH, exact analytic gradient for fixed nodes | 1× (20·n link evaluations per call) | Nodes are not centred at the conditional mode. At large σ (log σ ≳ 1.5) a binary pair's integrand in z is close to a step function (width ≈ 1/(√2σ)), and a 20-point polynomial rule resolves it poorly. Accuracy at small/moderate σ is fine for m_g ≤ 2 (the existing `lme4::glmer(nAGQ=20)` equivalence tests agree) | Pinheiro & Bates 1995 (JCGS); Lesaffre & Spiessens 2001 (JRSS-C), on the sensitivity of non-adaptive GH to node count |
| | adaptive GH, 5–9 nodes (`nAGQ`) | ~1.2–1.6× per call for m_g ≤ 2 (my estimate; the 2–4× in TODO-153 ignores the mode-finding cost: each group needs a 1-D Newton for û_g, 3–5 iterations of O(m_g), re-solved on every line-search evaluation) | The exact gradient must differentiate through û_g(θ), which is not an envelope identity for nAGQ > 1 (lme4 sidesteps this with derivative-free BOBYQA). Results are not bitwise identical. **The real gain is accuracy at large σ, not speed** | Liu & Pierce 1994 (Biometrika); Pinheiro & Bates 1995; Bates et al. 2015 (JSS) |
| | fewer fixed nodes (e.g. 10) | ~2× | Error grows with σ, and that is exactly where the 20-node rule is already weakest. Needs the A/B harness | [same as current] |
| | Laplace (nAGQ = 1) | ~5–10× | Known bias for binary GLMMs with tiny clusters; m_g ≤ 2 is the worst case. An accuracy regression | Joe 2008 (CSDA); Breslow & Lin 1995 (Biometrika) |
| | PQL | ~10×+ | Severe downward bias of σ and attenuation of β for binary data with small clusters; no true likelihood, so no LR test | Breslow & Clayton 1993 (JASA); Rodríguez & Goldman 1995 (JRSS-A) |
| | **probit closed form** (CLMM `ProbitLink` only): singleton P = Φ((α_k−η)/√(1+σ²)) − Φ((α_{k−1}−η)/√(1+σ²)); pair = rectangle probability of a bivariate normal with ρ = σ²/(1+σ²) (4 Φ₂ evaluations) | singletons ~20× fewer cdf calls; pairs about equal cost (Genz Φ₂ ≈ 6–20 Gauss–Legendre points) | **Removes the quadrature error entirely.** Needs derivatives of Φ₂ (∂Φ₂/∂ρ = φ₂ (Plackett); bounds via φ·Φ). Moderate implementation cost; probit only; cloglog and cauchit have no analogue | Genz 2004 (Stat. Comput.); Drezner & Wesolowsky 1990 (JSCS); Plackett 1954 (Biometrika) |
| | eliminate u by conditioning (clogit for logistic, already used for discordant pairs; conditional Poisson y₁ \| y₁+y₂ ~ Bin for counts) | O(1) per pair, no quadrature | **Different estimator.** Drops singletons, concordant pairs and between-pair information; no σ estimate. A design choice, not a drop-in | Breslow & Day 1980 (IARC Vol. 1); Hausman, Hall & Griliches 1984 (Econometrica) |
| | Monte Carlo / QMC integration | slower | Noisy objective breaks L-BFGS; 1-D does not need it | — |
| | adaptive Gauss–Kronrod per group | slower (≥ 21 evaluations, adaptive) | Robust but costlier than GH at this smoothness | — |

**T2. GH rule generation (NEW-gh-rule)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| nodes and weights | **current**: Golub–Welsch dense eigensolve per fit (4 duplicate copies) | 1× | Recomputed per fit and per score/Hessian export call (those exports sit inside the CI-inversion loops) | Golub & Welsch 1969 (Math. Comp.) |
| | compute once and cache per n_gh (function-local static, or `thread_local` map) | removes O(n_gh³) per fit (theoretical, a few % at n ≈ 100) | none: same code, bitwise-identical values; trivial thread-safety work | — |
| | hard-coded tables | same as the cache | Values differ from the eigensolver output in the last ulp, so not bitwise | — |
| | asymptotic O(n) node computation | only matters for n_gh in the hundreds | irrelevant at 20 | Townsend, Trogdon & Olver 2016 (IMA J. Numer. Anal.) |

**T3. Group layout (NEW-group-layout)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| contiguous groups | **current** `stable_sort`, O(n log n) | 1× | negligible next to the O(n·n_gh) objective | — |
| | counting/bucket sort on integer ids | O(n + G) | Ids must be dense; the saving is a rounding error at EDI's n | — |

**T4. Variance-component boundary (NEW-vc-boundary)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| σ → 0 or ∞ | **current**: log σ parametrisation plus a soft quadratic barrier beyond \|log σ\| = 5 (ordinal: hard clamp plus 1e4 penalty) | 1× | ∂ℓ/∂log σ = 2σ²·∂ℓ/∂σ² → 0 as σ → 0, so L-BFGS creeps toward the barrier and stops on a flat gradient at an arbitrary small σ (harmless for β; makes `variance_boundary_hit` common). The 1e100 wall in `value()` is not seen by LBFGSpp, which calls only `operator()` | Nocedal & Wright 2006 |
| | box-constrained L-BFGS-B on log σ | ~1× | Same flat-gradient issue; only replaces the barrier | Byrd, Lu, Nocedal & Zhu 1995 (SISC) |
| | parametrise by σ ≥ 0 (lme4's θ) with a bound-constrained optimiser | ~1× | Boundary σ = 0 reachable exactly. Changes the reported parametrisation, so vcov on the log σ scale is undefined at the boundary; needs the A/B harness | Bates et al. 2015 (JSS); Powell 2009 (BOBYQA, Cambridge NA2009/06) |
| | (LMM only) profile to 1-D in λ = σ_b²/σ_e² ∈ [0, λ_max] with Brent | see T7 | see T7 | Brent 1973 |

**T5. Observed information for GLMMs (NEW-glmm-obs-info)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| −∇²ℓ at the MLE (vcov; also the Newton polish in the ordinal GLMM) | **current, ordinal GLMM and CLMM/engine**: central-difference Jacobian of the analytic gradient | 2d gradient evaluations | O(h²) truncation plus O(ε/h) round-off, ~1e-7 relative. Absolute h = 1e-4 in `fast_ordinal_glmm.cpp:223` is not scaled to \|θ\|. Paid on every Newton-polish iteration and also when `estimate_only` | — |
| | **current, logistic/Poisson/clogit**: analytic Louis identity (E_p[H] + Cov_p[g] per group) | ≈ 1–2 gradient-equivalents + O(G·n_gh·d²) | Needs per-observation second derivatives; for cumulative links these are F″, already present as `Link::deriv_pdf` in `_glmm_links.h` | Louis 1982 (JRSS-B) |
| | forward-mode AD of the gradient | ~d gradient-equivalents | Exact, but no cheaper than FD; Eigen AutoDiff adds a dependency | — |
| | L-BFGS curvature pairs | free | Not a valid Hessian (rank-limited); wrong SEs | Nocedal & Wright 2006 |
| | expected (Fisher) information | — | No closed form for GLMMs (needs the same quadrature) | — |

**T6. GLMM outer optimiser (default choice)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| maximise ℓ(β, log σ), d ≈ p+1 | **current**: L-BFGS, single start (ordinal GLMM: 5-start multistart plus polish) | 1×; typically tens to ~100 gradient calls | Superlinear only; stops on relative decrease (the reason the ordinal GLMM needed a Newton polish) | Nocedal & Wright 2006 |
| | damped Newton with the existing analytic Louis Hessian (already selectable via `optimization_alg`) | ~2–5× fewer objective passes when the Hessian costs ≈ 2–3 gradients (theoretical) | ℓ is nonconcave in log σ near 0, so the Hessian can be indefinite and needs the existing LBFGS fallback. Default change needs the A/B harness | McCullagh & Nelder 1989; Nocedal & Wright 2006 |
| | EM with a GH E-step | slower (linear rate) | Monotone, but no benefit for a 1-D random effect with analytic gradients | Dempster, Laird & Rubin 1977 |
| | derivative-free (BOBYQA, lme4 style) | slower | Throws away the analytic gradient | Powell 2009 |

**T7. Gaussian LMM (NEW-lmm-closed-form)**

| problem | option | speed (theoretical) | disadvantages | citation |
|---|---|---|---|---|
| evaluate ℓ(β, σ_e, σ_b) | **current**: closed form per group (Sherman–Morrison on v_e·I + v_b·J), O(n·p) | 1× | none; already the O(n) form. General sparse Cholesky (lme4 PLS) would only add overhead for blocks ≤ 2 | Harville 1977 (JASA); Bates et al. 2015 (JSS) |
| fit | **current**: joint L-BFGS over p+2 parameters, ML | 1× (~20–100 evaluations × O(n·p)) | Not profiled. log σ_b → −∞ at the boundary (flat gradient, see T4). ML σ² biased low → anti-conservative SE at small G | — |
| | **profiled ML**: β̂(λ) by GLS (the existing `fast_gaussian_lmm_gls_cpp` kernel), σ̂_e²(λ) closed form, Brent on 1-D λ ∈ [0, λ_max] | ~15–25 evaluations × O(n·p² + p³): roughly equal at p ≲ 10, slower at large p; **main win is robustness**: λ = 0 attained exactly, 1-D bracketed search cannot diverge | Not bitwise identical at the boundary (exact 0 vs log σ_b ≈ −5); the profile can in principle be multimodal (rare for 1 variance component); vcov must still come from the full analytic Hessian (undefined at λ = 0 on the log scale) | Bates et al. 2015 (JSS); Brent 1973 |
| | Newton with the existing analytic Hessian (`optimization_alg="newton"`) | ~5–8 iterations × O(n·p²) | Same boundary issue as L-BFGS | Nocedal & Wright 2006 |
| | **REML** (profiled; adds log\|XᵀV⁻¹X\|, O(p³)) | ≈ ML | **Different estimator**: unbiased-to-first-order σ², better SE calibration at small G; changes reported numbers. A statistical decision, so A/B | Patterson & Thompson 1971 (Biometrika); Harville 1977 |
| | EM for variance components | slower (linear rate, very slow near σ_b = 0) | none worth it | Laird & Ware 1982 (Biometrics) |
| | ANOVA/moment estimators | O(n) closed form | Not ML; inefficient with covariates and mixed pair/singleton groups | — |

**T8. Conditional logit for KK pairs (NEW-matched-pair-clogit)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| exact conditional likelihood per stratum | **current**: closed form for 1:1 pairs = no-intercept logistic on differences | O(p) per pair | none (exact); handles 1:1 only (3rd and later members are dropped upstream) | Breslow & Day 1980 (IARC Vol. 1) |
| | Gail–Lubin–Rubinstein recursion | O(m·k) per stratum, the same 2-term sum at m=2 | Only needed for 1:M or M:N strata, which KK designs never produce | Gail, Lubin & Rubinstein 1981 (Biometrika) |
| | brute-force enumeration of the C(m,k) subsets | 2 subsets at m=2 | Exponential for large strata | — |
| | `survival::clogit` (Cox exact-ties route) | far slower (R-level overhead) | — | — |

**T9. GEE (row K)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| solve U(β) = 0 with working correlation α | **current**: Fisher scoring plus a moment α̂ each iteration, closed-form 2×2 V⁻¹, sandwich | 1× | α̂ is not scaled by φ̂ (see Incidental findings). For clusters ≤ 2, exchangeable = AR(1) = unstructured (one off-diagonal), so row K's "missing families" gap is moot here | Liang & Zeger 1986 (Biometrika) |
| | same, with φ̂-scaled α̂ (the Liang–Zeger formula proper) | 1× | Changes α̂ (efficiency only; β is still consistent and the sandwich still valid) | Liang & Zeger 1986 |
| | GEE2 / joint estimating equations for α | slower | Misspecified 2nd moments can bias β; less robust | Prentice 1988; Prentice & Zhao 1991 (Biometrics) |
| | alternating logistic regression (odds-ratio association for binary pairs) | ~1× | Better-posed α range for binary data (Prentice's correlation bounds depend on μ); binary only | Carey, Zeger & Diggle 1993 (Biometrika) |
| | QIF | slower (GMM) | More efficient under misspecification; more complex, and a test-statistic change | Qu, Lindsay & Li 2000 (Biometrika) |
| | independence GEE | faster | Efficiency loss when within-pair correlation is real | Liang & Zeger 1986 |
| | bias-corrected sandwich (an add-on, not a solver) | ~1× | Changes SEs (a statistical choice) | Mancl & DeRouen 2001 (Biometrics) |

**T10. Design assembly (NEW-design-assembly)**

| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| pair rows from strata | **current**: hash-map single pass | O(n) | none at EDI sizes | — |
| | sort by stratum | O(n log n) | slower; no benefit | — |
| | index directly from the design's match vector | O(n) | equivalent | — |

### New TODO candidates
1. **Cache the GH rule and remove 3 duplicates.** In `_glmm_engine.h:32`, compute once per n_gh (function-local static or a `thread_local` map) and replace `fast_logistic_glmm.cpp:39`, `fast_poisson_glmm.cpp:45` and `fast_clogit_plus_glmm.cpp:40` with it. Expected win (theoretical): removes O(n_gh³) eigensolve work per fit and per score/Hessian export call, a few % per fit and more inside CI-inversion loops that call `get_*_glmm_score/hessian_cpp` repeatedly. Risk: none (bitwise identical). Deterministic drop-in (**Adopt**).
2. **Analytic Louis-identity observed information** for `fast_ordinal_glmm.cpp:220` and for the engine `_glmm_engine.h:248` (which serves `fast_ordinal_clmm.cpp:127`), mirroring `fast_logistic_glmm.cpp:254`. It needs F″ per link (`deriv_pdf` already exists). Expected win (theoretical): replaces 2d gradient passes (d = K+p, often 8–20) with ~2, on the vcov step and on **each** Newton-polish iteration of the ordinal GLMM; it also removes the ~1e-7 FD error. In the same change, skip the Hessian when `estimate_only` (`fast_ordinal_glmm.cpp:516`). Risk: algebra errors; gate on existing tests plus an FD cross-check test. Deterministic (**Adopt**; the results match FD to its own tolerance).
3. **Profiled 1-D Gaussian LMM** (`fast_gaussian_lmm.cpp:387`): Brent on λ = σ_b²/σ_e² ∈ [0, λ_max], with β̂(λ) from the existing GLS normal-equation code (`:589-612`) and closed-form σ̂_e²(λ); optional REML flag (+O(p³)). Expected win (theoretical): robustness at σ_b → 0 (exact boundary, no flat-gradient crawl, fewer `hit_iteration_cap`); speed roughly neutral at p ≲ 10. Risk: boundary results differ from the current output, and REML changes estimates. **Prototype**, needs the A/B harness.
4. **Closed-form probit CLMM** (`fast_ordinal_clmm.cpp` `ProbitLink` path): Φ(·/√(1+σ²)) for singletons, bivariate-normal rectangle probabilities (Genz/Drezner–Wesolowsky Φ₂) for pairs. Expected win (theoretical): ~20× fewer cdf evaluations for reservoir singletons, and zero quadrature error at any σ. Risk: Φ₂ derivative implementation; results move (toward exact) relative to GH-20. **Prototype**, A/B (accuracy-equivalence check).
5. **Amend TODO-153 (adaptive GH) rather than open a new item.** Record that for m_g ≤ 2 the per-group mode solve eats most of the node saving, so expect ~1.2–1.6× rather than 2–4× (theoretical). The stronger argument for AGQ is accuracy at large σ. An exact gradient needs dû/dθ. A/B harness.
6. **A/B damped Newton vs L-BFGS as the default** for `fast_logistic_glmm.cpp:460`, `fast_poisson_glmm.cpp:334`, `fast_clogit_plus_glmm.cpp:503` and `fast_gaussian_lmm.cpp:387`, all of which already have analytic Hessians and an `optimization_alg="newton"` path. Expected win (theoretical): ~2–5× fewer objective passes. Risk: indefinite Hessian near σ = 0 (the LBFGS fallback already exists). Harness.

### Incidental findings (optional)
- **Possible bug, `fast_gee.cpp:76-100`**: α̂ = ∑ r_i r_j / count uses Pearson residuals **without dividing by φ̂** (Liang–Zeger: α̂ = φ̂⁻¹ ∑ r_i r_j /(N_pairs − p)). Consequences by family:
  - Gaussian (`gee_variance` = 1): α̂ is a covariance, not a correlation. Unused in production; no R class uses `gaussian`.
  - Poisson with overdispersion: α̂ ≈ φρ and can clamp at 0.95, giving a near-singular V (detV ∝ 1 − α²).
  - `binomial` on proportions (φ < 1): α̂ is attenuated.

  β stays consistent and the sandwich stays valid, so this costs efficiency and stability only.
- **`fast_gee.cpp:130`**: clusters are ≤ 2, so audit row K's "only independence/exchangeable" scope gap is vacuous for this kernel (AR(1) and unstructured coincide with exchangeable at m = 2). Worth one line in the audit.
- `fast_gee.cpp:211`: convergence on the absolute ‖U‖ < 1e-8 is not scale-invariant (large Poisson counts may hit `maxit` with a converged β).
- `fast_ordinal_glmm.cpp:516`: the FD Hessian (2d gradient evaluations) is computed even when `estimate_only = TRUE`, i.e. inside resampling loops.
- `fast_ordinal_glmm.cpp` vs `fast_ordinal_clmm.cpp<LogitLink>`: two independent implementations of the same cumulative-logit random-intercept model. The CLMM path is a single start from all-zero cutpoints and lacks the multistart/Newton-polish robustness fix, so results can diverge on hard data.
- `_glmm_engine.h:214-217,231`: the per-group heap allocations (`log_terms`, `dL_dp_sum_nodes`, `dL_de_nodes`, `dp`, `pk_vec`) inside the hot gradient loop are G × 5 mallocs per objective call.
- `_glmm_engine.h:161` vs `:192`, and `fast_clogit_plus_glmm.cpp:160` vs `:228`: the `max_abs_log_sigma` wall exists only in `value()`/`neg_glmm`; LBFGSpp calls `operator()`, so the wall is inactive during optimisation (the soft barrier still applies in the engine; clogit+GLMM has no barrier at all in `operator()`).
- `fast_poisson_glmm.cpp:515,545` (score/Hessian exports): they include the soft-barrier gradient/Hessian (the logistic exports subtract them) and ignore `row_weights`. This only matters when |log σ| > 5 or the fit was weighted.
- `fast_gaussian_lmm.cpp:487`: `ssq_b_T = V(1,1)` hard-codes treatment at column 1 (other kernels take `j_T`). `:80` takes the group weight from the first member only. The score/fisher exports (`:627,:674`) ignore weights.
- `_glmm_links.h:53`: cloglog cdf `1 − exp(−exp(x))` returns 0 for x ≲ −37; `−expm1(−exp(x))` is exact. Also `fast_ordinal_clmm.cpp:51-53` computes F_up − F_lo by subtraction, which cancels in the upper tail (the standard fix uses survival functions when both are near 1). Floored at 1e-15, so this is bounded but loses information in the extreme categories.
- `build_kk_combined_ols_design.cpp:160` has **no production caller** (only `test-resampling-kernel-contracts.R` and `test-matching-ols-degenerate-geometry.R`). Its 1/√2 equal-variance stacking also ignores σ_b² in the reservoir rows under a random-pair-effect model. Feasible GLS (`fast_gaussian_lmm_gls_cpp`) is the efficient version.
- Statistical, Investigate, not algorithmic: `build_kk_combined_clogit_design.cpp:93` pools a conditional (subject-specific) pair likelihood with a *marginal* reservoir logistic under one β. When σ_b > 0, marginal logistic coefficients are attenuated relative to conditional ones (Neuhaus, Kalbfleisch & Hauck 1991, Int. Stat. Rev.), so the common-β assumption is misspecified. `fast_clogit_plus_glmm` avoids this for the reservoir, but it drops P(pair sum = 1) for discordant pairs while keeping the full marginal for concordant ones. That makes it a composite likelihood, so the χ² calibration of its LR test is not guaranteed.
- `build_kk_combined_clogit_design.cpp:41`: a 3rd or later stratum member is silently skipped (fine for KK; a silent failure for any other caller).
- `fast_clogit_plus_glmm.cpp:455,483`: the score/Hessian exports hard-code n_gh = 20 (consistent with the fit only because the fit wrapper also hard-codes 20 at `:694`).

---

## 5. C++ — survival


Files covered (all `R/EDI/src/`): `fast_coxph_regression.cpp`, `fast_survival_models_optim.cpp`, `fast_survival_stats.cpp`, `fast_weibull_regression.cpp`, `fast_weibull_frailty.cpp`, `fast_logrank.cpp`, `fast_gehan_wilcox.cpp`, `survival_rank_record.h`, `survival_strata_ids.cpp`, `kk21_stepwise_survival.cpp`. All read in full. Nothing compiled or run against EDI. One pure-numpy re-implementation of a formula was run as a check (finding I-1).

**Answers to the coordinator's focus questions (short):**
- **Cox risk sets:** fast already. There is **one sort per dataset** (`CoxData` ctor, `:42`). XPtr-cached data (`:757`, `:764`) reuse it across calls, and it sits outside the Newton loop. Each iteration then uses **reverse cumulative sums** (`:169-230`): O(n p²) for S2, plus O(K p²) for the per-event Hessian terms, plus O(np) for η. This is **not O(n²)**. Ties use **Breslow** (`dk·log S0`, `dk·e_z`, and `dk·(S2/S0 − e eᵀ)` over the full tied risk set; no Efron branch). Row L is the coordinator's to settle.
- **Log-rank / "Gehan":** both run **O(n log n)** (one sort, then a linear sweep over tie groups). No O(n²) pairwise form exists anywhere. `fast_gehan_wilcox.cpp` actually computes the **Peto–Prentice** weighted log-rank (weight = pooled KM Ŝ(t⁻), = `survdiff(rho=1)`). It does not use Gehan's original weight Y(t). Either weight fits the same O(n log n) sweep.
- **Interval censoring / Turnbull:** no NPMLE exists in this C++ group. The only interval-censored C++ code is **parametric**: Weibull AFT with `y_L`/`y_R` (`fast_weibull_regression.cpp:140`), fitted by L-BFGS. The NPMLE is delegated to R: `interval::icfit()` in `R/helper_inference_survival_turnbull.R:35` and `interval::ictest(..., scores="wmw")` in `R/inference_survival_gehan_wilcox.R:258`. The R-group sweep should catalog EM vs ICM vs EMICM there. An options table is included below for convenience.
- **Weibull frailty:** **fixed 20-node, non-adaptive Gauss–Hermite**. The rule comes from Golub–Welsch. The marginal is a log-sum-exp per cluster. The gradient is analytic and the Hessian uses central finite differences. This falls under row C (tracked by TODO-153). TODO-153's text scopes `_glmm_engine.h` only, while this kernel has its **own** GH rule and likelihood. It must be named explicitly, or it will be missed.
- **Kaplan–Meier:** sort, then one product-limit sweep, O(n log n). That is optimal for a single evaluation.
- **Per-replicate re-sorting in resampling loops:** present in the Cox BRT (×2), log-rank BRT, and KM/RMST BRT (×2) kernels. The Weibull BRT kernel doesn't sort. Only the Cox case is tracked (`small_kernel_hoists_batch.md` Item C), and that plan's shortcut is **incomplete for `delta ≠ 0`** (finding I-4). KM/RMST and log-rank are new TODO candidates (1, 2).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity (n, p, B, K, \|R\| as relevant) | family | verdict |
|---|---|---|---|---|---|
| fast_coxph_regression.cpp:37 `CoxData::CoxData` | order subjects by time, build unique event times and tie counts | `std::sort` of an index by (time asc, dead desc), then two linear sweeps; X copied row-major | O(n log n + np) once per dataset; cached via XPtr (`:757`, `:764`) for repeated fits | NEW-survival-sort-sweep | Keep |
| fast_coxph_regression.cpp:105 `compute_cox_neg_ll_only` | Cox partial log-lik (line-search objective) | forward pass: start from total Σexp(η) and **subtract** leaving subjects; Breslow ties; max-η shift | O(np) per eval | A | Keep (numerical note I-6) |
| fast_coxph_regression.cpp:143 `compute_cox_ll_grad_hess_fast` | Cox neg-log-lik, score and observed information | reverse cumulative sums S0/S1/S2 from the latest time backward (additive, stable). Breslow tie terms per unique event time. Hessian built with a scalar upper-triangular loop per subject | O(np²) per subject-sweep + O(Kp²) per event-time terms (K = # unique event times); **not** O(n²) | A (+L ties) | Keep (constant-factor TODO-5) |
| fast_coxph_regression.cpp:256 `cox_newton_raphson` | maximize Cox partial likelihood | damped Newton: LDLT solve, ≤10 step-halvings, convergence on \|Δℓ\|<tol; default maxit 20 | O(iter·(np² + p³)); iter ≈ 4–8 typical | A | Keep |
| fast_coxph_regression.cpp:405/:440 `StratifiedCoxObjective`, `cox_lbfgs` | same, L-BFGS option; strata = sum of per-stratum likelihoods | shared L-BFGS (`optimize_fixed_likelihood`), analytic gradient; Hessian only at the end | O(iter·np) + one O(np²) | A | Keep |
| fast_coxph_regression.cpp:523 `compute_robust_vcov` | Lin–Wei cluster-robust sandwich | per-subject score residuals via prefix sums `cum_A`/`cum_B` and binary search for each subject's last event time; per-cluster sums in a hash map; H⁻¹BH⁻¹ | O(n log K + (n+K)p + Cp²) | NEW-survival-sort-sweep | Keep (I-6 also applies: forward subtraction at `:559-563`) |
| fast_coxph_regression.cpp:692/:764/:890/:983/:996 stratified builders | group rows by stratum | `std::map<int, vector<int>>`, then per-stratum `CoxData` (each sorts its own stratum) | O(n log S + Σ nₛ log nₛ) | glue-ish | Keep |
| fast_coxph_regression.cpp:1114 `compute_coxph_rand_bootstrap_cpp` | B Cox refits for a BRT reference distribution (p=1, documented as having no in-package caller) | per draw: gather, re-sort inside `CoxData`, Newton (no smart start) | O(B·(n log n + iter·n)) | NEW-resample-presort | Keep-tracked (`small_kernel_hoists_batch.md` Item C1–C3; see I-4) |
| fast_coxph_regression.cpp:1157 `compute_coxph_rand_bootstrap_parallel_cpp` | B Cox refits with covariates, optional smoothing noise, OpenMP | per draw: gather, re-sort, Newton with `smart_cold_start=true` (OLS of log y on X **without intercept**), tol 1e-6 | O(B·(n log n + np² + iter·np²)) | NEW-resample-presort + A | Keep-tracked (Item C; see I-4, I-5) |
| fast_coxph_regression.cpp:639,:791,:841,:961-:1006 | glue — internal/prebuilt/R wrappers, score/Hessian getters | forwarding plus result packing | — | glue | — |
| fast_survival_models_optim.cpp:26 `log_sum_exp_clayton` | stable log(eᵃ+eᵇ−1) | max-shifted LSE with floor | O(1) | glue (numerics) | Keep |
| fast_survival_models_optim.cpp:77 `ClaytonWeibullLikelihood::operator()` | Clayton-copula Weibull AFT neg-log-lik and gradient for matched pairs plus singletons | closed-form 4-case (δ₁,δ₂) pair likelihood; derivatives via ratios r=exp(θh−logA) ∈ (0,1] (overflow-safe); log θ clamped ≤ 6 with zeroed gradient at the clamp | O(np) per eval | NEW-nonconcave-dependence-mle | Keep-tracked (`multistart_nonconcave_likelihoods.md` TODO-5) |
| fast_survival_models_optim.cpp:221 `ClaytonWeibullLikelihood::hessian` | observed information for vcov | **forward** finite difference of the analytic gradient, h=1e-6 absolute, then symmetrized | (P+1) gradient evals, P=p+2; once per fit | NEW-fd-hessian | Keep |
| fast_survival_models_optim.cpp:264 `DepCensTransformLikelihood::operator()` | bivariate-normal dependent-censoring log-normal model neg-log-lik and gradient | per-row closed form with log Φ via `fast_log_pnorm`, Mills ratio as exp(log φ − log Φ); atanh ρ clamped to ±3 | O(np) per eval | NEW-nonconcave-dependence-mle | Keep-tracked (multistart TODO-5) |
| fast_survival_models_optim.cpp:361 `DepCensTransformLikelihood::hessian` | observed information | forward finite difference of the gradient (the block at `:362-379` returns early). An **analytic Hessian at `:380-496` is unreachable dead code** | (P+1) gradient evals, P=2p+3 | NEW-fd-hessian | Keep (I-3) |
| fast_survival_models_optim.cpp:599 `fast_clayton_weibull_aft_optim_internal` | fit the Clayton model | L-BFGS from the caller's warm start; the upper bound is handled by clamp plus zero gradient (not a true bound-constrained method) | O(iter·np) | NEW-nonconcave-dependence-mle | Keep-tracked (options: L-BFGS-B) |
| fast_survival_models_optim.cpp:696 `fast_dep_cens_transform_optim_internal` | fit the dependent-censoring model | L-BFGS from an OLS-on-log-y start (same β for event and censoring, σ=1, ρ=0) | O(iter·np) | NEW-nonconcave-dependence-mle | Keep-tracked |
| fast_survival_models_optim.cpp:508-591,:786,:814 | glue — score/Hessian getters and R wrappers | forwarding | — | glue | — |
| fast_survival_stats.cpp:45/:58 `rmst_from_km`, `km_stat_inline` | KM median (survfit quantile semantics) or RMST to τ for one arm | comparison sort, then product-limit sweep over tie groups; RMST by summing step areas | O(n log n) sort + O(n) | NEW-survival-sort-sweep | Keep |
| fast_survival_stats.cpp:102/:226 `get_survival_stat_for_group_result_at_tau`, `get_survival_stat_for_group` | same, Eigen/SEXP entry points (the second is a near-duplicate body) | same | O(n log n) | NEW-survival-sort-sweep | Keep |
| fast_survival_stats.cpp:396 `get_restricted_mean_se_for_group_at_tau` | Greenwood-type delta-method variance of RMST | sort, KM event table, suffix sums A(t_j)=∫S, Σ A² d/(n(n−d)) | O(n log n) | NEW-survival-sort-sweep | Keep |
| fast_survival_stats.cpp:536 `compute_survival_stat_diff_rand_bootstrap_parallel_cpp` | B per-arm KM median/RMST differences (BRT), OpenMP | per draw: split arms, then **re-sort each arm** (`km_stat_inline`), then sweep | O(B·n log n) | NEW-resample-presort | **Adopt** (TODO-1) |
| fast_survival_stats.cpp:628 `compute_survival_stat_diff_rand_bootstrap_serial_cpp` | same, serial | per draw: copy into vectors, then re-sort each arm | O(B·n log n) | NEW-resample-presort | **Adopt** (TODO-1) |
| fast_survival_stats.cpp:181,:323,:480 | glue — arm split, shared τ, SE combination | linear passes | O(n) | glue | — |
| fast_weibull_regression.cpp:90/:112 `WeibullAFTLikelihood` | Weibull AFT neg-log-lik/grad (exact plus right-censored) and analytic Hessian, parametrized (β, log σ) | vectorized Eigen arrays; Hessian = weighted crossprod | O(np) per eval; O(np²) Hessian | A | Keep (I-7 on audit wording) |
| fast_weibull_regression.cpp:197/:239 `WeibullAFTLikelihoodGeneral` | same with left/interval/right censoring (parametric interval censoring) | exact rows vectorized; censored rows use a scalar log(S(a)−S(b)) with degenerate-bound special cases; analytic Hessian | O(np) per eval | A | Keep |
| fast_weibull_regression.cpp:316/:508 `fast_weibull_regression_internal`, `…_left_interval_censoring_internal` | fit the Weibull AFT | **L-BFGS default** (`"lbfgs"`) even though an exact analytic Hessian exists; `newton` (newton-then-L-BFGS) is available by argument; survreg-style moment start | O(iter·np); L-BFGS iter ≈ 15–40 vs Newton ≈ 4–8 | A | **Prototype** (TODO-3) |
| fast_weibull_regression.cpp:714 `compute_weibull_rand_bootstrap_parallel_cpp` | B Weibull AFT refits (BRT), OpenMP | per draw: L-BFGS from **all-zero params** (no smart or warm start), maxit 100, tol 1e-8 | O(B·iter·np) | A | **Prototype** (TODO-3) |
| fast_weibull_regression.cpp:286 `general_to_effective` + `weibull_aft_start` (helper) | start heuristic | survreg moment start: OLS on uncensored log y + 0.5722, var/1.645 | O(np²) | glue | Keep |
| fast_weibull_frailty.cpp:39 `gauss_hermite_rule_wf` | GH nodes and weights | Golub–Welsch: eigen-decomposition of the K×K Jacobi matrix | O(K³) per functor build (K=20) | C | Keep-tracked (`small_kernel_hoists_batch.md` Item D shared GH rule) |
| fast_weibull_frailty.cpp:86 `build_group_structure` | make clusters contiguous | `stable_sort` by group id, then contiguous layout | O(n log n) once | glue-ish | Keep |
| fast_weibull_frailty.cpp:152 `WeibullFrailtyNormalLikelihood::operator()` | marginal likelihood of a Weibull AFT with N(0,σᵤ²) random intercept on log-time | **fixed K=20 non-adaptive GH**; per-node conditional log-lik; per-cluster LSE fused with posterior weights; exp(w_ik)=exp(base_i)·exp(δ_k) factorization. Gradient loop updates the p-vector **inside** the k,g,i loops | O(nK) log-lik + **O(nKp)** gradient per eval | C | Keep-tracked (TODO-153, see note) + Prototype TODO-4 |
| fast_weibull_frailty.cpp:236 `hessian` | observed information | `numerical_hessian`: **central** finite difference of the analytic gradient, h=1e-4·max(1,\|θ\|) | 2P gradient evals, P=p+2; once per fit | NEW-fd-hessian | Keep |
| fast_weibull_frailty.cpp:309 `fast_weibull_frailty_internal` | fit the frailty model | L-BFGS (eps_g 1e-6, maxit 300) from an OLS start with log σᵤ = 0 | O(iter·nKp) | C | Keep-tracked (`multistart_nonconcave_likelihoods.md`, `:369` start row) |
| fast_logrank.cpp:27 `fast_logrank_internal` | log-rank score, hypergeometric variance, martingale-residual mean difference and Welch SE | sort with `record_less`; precomputed tie-group boundaries; one fused sweep (score, var, Nelson–Aalen, martingale moments) | O(n log n) + O(n) | NEW-survival-sort-sweep | Keep |
| fast_logrank.cpp:163 `compute_logrank_rand_bootstrap_parallel_cpp` | B log-rank estimates (BRT), OpenMP static | per draw: gather, **full re-sort** of pooled records, sweep | O(B·n log n) | NEW-resample-presort | **Adopt** (TODO-2) |
| fast_gehan_wilcox.cpp:34 `fast_gehan_wilcox_internal` | Peto–Prentice (survdiff ρ=1) weighted log-rank and weighted martingale-residual difference | same sort and sweep as log-rank, with weight = running pooled KM Ŝ(t⁻) | O(n log n) + O(n); **no O(n²) pairwise Gehan form** | NEW-survival-sort-sweep | Keep (naming note I-8) |
| fast_logrank.cpp:129/:137, fast_gehan_wilcox.cpp:141/:149 | glue — portable and R wrappers | forwarding | — | glue | — |
| survival_rank_record.h:25 `record_less` | strict weak order for rank sweeps | (time asc, dead desc, w asc) comparator | O(1) | glue (sort key) | Keep |
| survival_strata_ids.cpp:40 `compute_survival_strata_ids_cpp` | auto-strata from low-cardinality columns | per-column `std::map` level counts with early exit when >L levels; pick ≤4 columns by fewest levels; mixed-radix code, then `std::map` relabel | O(np log L + n·c·log L + n log S), L≤4 | NEW-level-coding | Keep |
| kk21_stepwise_survival.cpp:22 `weibull_reduced_fit_for_score_test` | Weibull AFT MLE on the reduced design [1, w, selected] | "alternating IRLS (β) + 1-D Newton (σ)" with warm start. **The working response and σ-score do not match the Weibull AFT score equations, so the fixed point is not the MLE** (I-1) | O(iter·nm²) per call | A | **Investigate** (correctness; TODO-6) |
| kk21_stepwise_survival.cpp:99 `kk21_stepwise_survival_weights_cpp` | KK21 covariate-importance weights by forward selection | one reduced fit per step, then a Rao score (LM) statistic for every unused candidate (`v_j = (WX_S)ᵀx_j` GEMV each). Fallback: FWL OLS on log y with an incrementally extended orthonormal basis | O(p·(fit + p·n·m)) ≈ O(p² n m), m ≤ p+2; fallback O(p²n·q) | NEW-score-forward-selection | Keep (algorithm); result quality depends on the I-1 fix |

Counts: 41 rows (8 of them glue/glue-ish lines). NEW families: 6 (NEW-survival-sort-sweep, NEW-resample-presort, NEW-fd-hessian, NEW-nonconcave-dependence-mle, NEW-level-coding, NEW-score-forward-selection).

### Options & disadvantages

**Cox partial likelihood: risk-set sums and Hessian (rows `:143`, `:256`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| risk-set sums | naive: recompute Σ_{j∈R(t_k)} per event time | O(n·K·p²) ≈ O(n²p²): far slower | none worth having | — |
| risk-set sums | **current**: one sort, reverse cumulative S0/S1/S2 | O(np² + Kp²) per iteration | the forward-subtraction variant used in the line-search objective and robust vcov can lose precision late in follow-up (I-6) | Therneau & Grambsch 2000, *Modeling Survival Data* (coxph's own algorithm) |
| Hessian assembly | SYRK identity: Σ_k d_k S2_k/S0_k = Xᵀ diag(eᶯⁱ·A_i) X with A_i = Σ_{t_k≤y_i} d_k/S0_k, plus Σ_k d_k e_k e_kᵀ as one SYRK on a K×p matrix | same O(np² + Kp²), but BLAS-3 instead of a scalar triple loop: ~1.5–3× on assembly at p ≥ 5 (theoretical) | tolerance-equal, not bit-identical (summation order); gains vanish at p=1–2 (the BRT kernels' typical p) | identity already used in-file at `compute_robust_vcov:576-607` |
| ties | **current**: Breslow | — | biased toward 0 under heavy ties; differs from coxph's Efron default | Breslow 1974, *Biometrics* |
| ties | Efron | +O(Dp²) (D = # deaths), same order | needs a per-tied-death loop; row L decides | Efron 1977, *JASA* |
| ties | exact discrete partial likelihood | recursive, O(Σ_k nₖdₖ)-type per k, much slower with many ties | rarely needed in trials | Gail, Lubin & Rubinstein 1981, *Biometrika* |
| optimizer | **current** damped Newton / L-BFGS option | — | — | row A |

**Weibull AFT optimizer choice (rows `:316`, `:508`, `:714`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| fit (β, log σ) | **current**: L-BFGS default; BRT draws start at all-zero | ~15–40 objective+gradient evals of O(np) | slower convergence; the all-zero start in BRT draws puts log σ = 0 and intercept = 0, far from typical data | Nocedal & Wright 2006 |
| fit | Newton (existing `newton_then_lbfgs`) with the analytic Hessian already in-file | ~4–8 iterations of O(np²); ~2–4× fewer passes at p ≤ 10 | (β, log σ) is not jointly concave in general, so damping/fallback is needed (already present). A different path may change *which* rare fits fail, so an A/B is required | survreg uses Newton–Raphson (Therneau & Grambsch 2000) |
| fit | Newton in Burridge/Pratt parametrization (β/σ, 1/σ): concave for log-concave errors under censoring | same iteration count as Newton, with global concavity (pure Newton safe) | reparametrize back for vcov (delta method); more code; the audit row A wording already claims this parametrization, but the code doesn't use it | Burridge 1981, *JRSS-B*; Pratt 1981, *JASA* |
| BRT start | warm start each draw at the observed MLE (treatment coef + δ) | typically ~2× fewer iterations | belongs to `cold_starts.md` territory; must not change converged values (deterministic MLE, so it shouldn't) | — |

**Weibull frailty integration (row `:152`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| ∫ over log-normal random intercept | **current**: fixed 20-node GH | O(nK) + O(nKp) gradient | over-provisioned for most clusters | Golub & Welsch 1969, *Math. Comp.* (rule) |
| same | adaptive GH, 5–9 nodes | ~2–4× fewer nodes | per-cluster mode/curvature solve; tracked as TODO-153, whose text names only `_glmm_engine.h` | Liu & Pierce 1994, *Biometrika*; Pinheiro & Bates 1995, *JCGS* |
| same | Laplace (1 node) | ~20× fewer node evals | biased for small clusters (KK pairs = size 2) and large σᵤ: an accuracy regression | Pinheiro & Chao 2006, *JCGS* |
| same | gamma frailty on the PH scale (closed-form marginal) | O(n) per eval, no quadrature | **different model** (PH vs AFT, gamma vs log-normal); EDI already has a log-gamma frailty class elsewhere | Clayton 1978, *Biometrika* [model-family cite] |
| same | MCEM / h-likelihood | slower (MCEM) or biased for small clusters (h-lik) | worse on both axes for EDI | Ha & Lee [cite needed for exact paper] |
| gradient accumulation | **current**: p-vector update inside the k,g,i triple loop, O(nKp) | — | — | — |
| gradient accumulation | per-observation s_i = Σ_k pw_{g(i)k}·(r_ik−δ_i)/σ, then one `Xᵀs` GEMV | O(nK + np): ~p× on that term | tolerance-equal; previous "math tightening" of this kernel was measured slower and reverted (`performance_profiling_and_upgrades.md` Phase 3), so benchmark before adopting | — |

**NEW-survival-sort-sweep (KM, RMST, RMST SE, log-rank, Peto–Prentice, Cox data build)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| single evaluation | **current**: comparison sort + one linear sweep over tie groups | O(n log n) | — (a sort is unavoidable for an unsorted input in the comparison model) | Kaplan & Meier 1958, *JASA*; Mantel 1966; Peto & Peto 1972, *JRSS-A*; Prentice 1978, *Biometrika* |
| Gehan statistic | pairwise U-statistic Σᵢ Σⱼ U_ij | O(n²) | strictly worse; not used anywhere | Gehan 1965, *Biometrika* |
| Gehan statistic | weighted log-rank sweep with weight Y(t) | O(n log n) | — (EDI's sweep already has this shape; it uses weight Ŝ(t⁻) instead) | Mantel 1967, *Biometrics* |
| sort itself | LSD radix sort on IEEE-754 keys | O(n) with ~8 passes | wins only at n in the thousands; NaN/-0 handling; not worth it for a single eval | — |

**NEW-resample-presort (per-replicate sort in BRT kernels)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| order draw b | **current**: gather, then comparison sort per draw | O(B·n log n) | sort dominates the cheap O(n) sweep kernels (KM, log-rank) | — |
| order draw b | `rank0` (parent order, computed once) + per-draw counting pass over `rank0[i_b]` | O(B·n) | valid only when the draw's order is a function of parent ranks: true per arm for **any** δ (×e^δ is monotone within an arm); false for the pooled sort when δ≠0, and false with `noise_mat` | `small_kernel_hoists_batch.md` Item C (Cox) |
| pooled order with δ≠0 | counting pass per arm, then a two-way O(n) merge | O(B·n) | merge tie rule must reproduce `record_less` (dead desc, then w) when a treated time equals a control time | — |
| draws with noise | keep the comparison sort (or radix) | — | the presort is invalid, so fall back | — |
| sort algorithm swap only (pdqsort, radix) | constant factor | small | does not remove the log n; less win than presort | — |

**NEW-fd-hessian (Clayton `:221`, dep-cens `:361`, frailty `:236`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| observed information once per fit | **current**: forward FD of the analytic gradient (Clayton, dep-cens: P+1 evals, O(h) error) / central FD (frailty: 2P evals, O(h²)) | — | FD noise ~1e-6 relative (forward); fine for SEs | Nocedal & Wright 2006 §8.1 |
| same | analytic Hessian | 1 pass instead of P+1 or 2P | high derivation/bug cost; the dep-cens analytic Hessian already exists but is dead code, and was presumably disabled for a reason (I-3) | — |
| same | complex-step derivative of the gradient | P evals, error ~machine precision | needs complex-templated functors; `fast_log_pnorm` and similar would need complex versions | Squire & Trapp 1998, *SIAM Review* |
| same | forward-over-reverse automatic differentiation | ~O(P) gradient cost, exact | new dependency or templating of every functor | Griewank & Walther 2008, *Evaluating Derivatives* |
Verdict: Keep. The Hessian runs once per fit, not per iteration, so it is never a bottleneck at EDI's P (≤ ~25).

**NEW-nonconcave-dependence-mle (Clayton copula AFT, dependent-censoring transform)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| fit with a dependence parameter | **current**: L-BFGS, single caller start; the bound is handled by clamp + zero gradient | — | local optima; flat region at the clamp | — |
| same | multistart over the dependence parameter | ×S starts | cost ×S; already planned | `multistart_nonconcave_likelihoods.md` TODO-5 |
| same | L-BFGS-B with a true upper bound on log θ | ~same | removes the clamp hack; needs a bounded optimizer in the shared helper | Byrd, Lu, Nocedal & Zhu 1995, *SIAM J. Sci. Comput.* |
| same | profile over θ (1-D Brent outer, concave-ish inner AFT) | outer 10–20 inner fits | slower, but more robust to the θ-boundary | Brent 1973 |
| same | two-stage IFM (margins first, then copula) | faster | not full MLE: efficiency loss; censoring complicates the margins | Joe 2005, *J. Multivariate Anal.* [cite needed: confirm title/venue] |
Verdict: Keep-tracked (multistart TODO-5).

**NEW-level-coding (`survival_strata_ids.cpp:40`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| count levels and combine | **current**: `std::map` per column with early exit at L+1 levels; mixed-radix id | O(np log L), L ≤ 4 | — | — |
| same | `unordered_map` / small linear array (L ≤ 4) | constant factor | none material; ids would need re-sorting to keep the deterministic level order | — |
Verdict: Keep (trivial cost).

**NEW-score-forward-selection (`kk21_stepwise_survival.cpp:99`)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| rank covariates by entry statistic | full refit per candidate (Wald/LR) | ~p× more fits per step | slow; the reference answer | — |
| same | **current**: one reduced fit per step + Rao score statistic per candidate | O(p² n m) total | asymptotically equivalent to Wald only if the reduced fit is the MLE (it isn't today: I-1) | Rao 1948, *Proc. Camb. Phil. Soc.* |
| same | same, with the p candidate cross-products batched as one GEMM `(WX_S)ᵀ X_unused` | constant factor (BLAS-3) | none | — |
| same | FWL OLS on log y (the existing fallback / "speedup") | cheapest | ignores censoring | — |

**Out-of-group pointer: interval-censored NPMLE (R side, `interval::icfit`)**
| problem | option | speed (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| Turnbull NPMLE | EM / self-consistency (believed to be `interval::icfit`'s method; R group to verify) | linear convergence; can need thousands of iterations with many Turnbull intervals | slow near the boundary; mass on few intervals | Turnbull 1976, *JRSS-B*; Fay & Shaw 2010, *J. Stat. Softw.* |
| same | ICM (iterative convex minorant) | faster per iteration on the cumulative scale | can be non-monotone without line search | Groeneboom & Wellner 1992, *Information Bounds and Nonparametric MLE* |
| same | EMICM hybrid | typically far fewer iterations than EM | more code | Wellner & Zhan 1997, *JASA* |
| same | support reduction | fast, handles sparse support | implementation cost | Groeneboom, Jongbloed & Wellner 2008, *Scand. J. Statist.* |

### New TODO candidates
1. **KM/RMST BRT presort** (`fast_survival_stats.cpp:536`, `:628`, via `km_stat_inline:63`). Compute `rank0` (each subject's position in the sorted `y0`) once. Per draw, do a counting pass per arm over `rank0[i_b]`, with a single flat array plus a cursor to keep it O(n). This is valid for **every δ**, because the shift is multiplicative on one whole arm and so preserves within-arm order. Fall back to the sort when `noise_mat` is non-null. KM uses only per-time event/at-risk counts, so the result is **bit-identical**. Win (theoretical): O(n log n) → O(n) per arm per draw, ~2–5× on this kernel at n=200–1000, because the post-sort sweep is cheap. Risk: low (tie groups still form by `==`). Deterministic drop-in; existing BRT tests plus an `identical()` check are the gate. No A/B needed.
2. **Log-rank BRT presort + merge** (`fast_logrank.cpp:163`). Use the same `rank0` counting pass per arm, then an O(n) merge that reproduces `record_less`'s tie order (dead desc, then w asc). With δ=0 and no noise, the per-arm streams interleave exactly by parent order. Win (theoretical): ~2–4× on the kernel (sort-dominated). Risk: martingale sums inside a tie group may sum in a different order, so the result is tolerance-equal (~1e-15), not bit-identical. Deterministic drop-in, gated by tolerance tests. If a Peto–Prentice BRT kernel is ever added (none exists; resampling currently goes through R calls to `fast_gehan_wilcox_stats_cpp`), it should be built this way from the start.
3. **Weibull AFT: Newton default with the analytic Hessian, plus warm-started BRT draws** (`fast_weibull_regression.cpp:356`, `:551`; BRT `:788-789`, which uses `params0.setZero()` and `"lbfgs"`). Switch the default to `newton` (newton-then-L-BFGS fallback already exists). In the BRT kernel, start each draw from the observed-data MLE instead of zero. Win (theoretical): ~2–4× fewer passes per fit, multiplied by B in BRT. Risk: (β, log σ) is not jointly concave, so the set of rare non-convergent draws may change. **Needs the A/B harness** (convergence-failure rate plus wall-clock); the converged estimates should agree to tol. Optional: Burridge reparametrization for global concavity.
4. **Weibull-frailty gradient O(nKp) → O(nK + np)** (`fast_weibull_frailty.cpp:210-231`). Accumulate per-observation scalar weights across nodes, then do one `Xᵀs` GEMV. The log σ_ε and log σ_u gradient parts are already scalar. Win (theoretical): ~p× on the gradient's dominant term, ~1.5–3× per objective eval at p≈5–10. Risk: tolerance-equal only, and a prior math rewrite of this kernel benchmarked slower. Needs a benchmark (perf A/B), not a statistical A/B. Also name this file explicitly in TODO-153's scope (adaptive GH) and in `small_kernel_hoists_batch.md` Item D (shared GH rule).
5. **Cox Hessian via a SYRK identity** (`fast_coxph_regression.cpp:184-192`, `:218-227`). Use H = Xᵀ diag(eᶯ·A) X − Σ_k d_k e_k e_kᵀ, the same prefix-sum identity `compute_robust_vcov` already uses. Win (theoretical): ~1.5–3× on Hessian assembly at p ≥ 5; ~nothing at p=1–2. Risk: tolerance-equal. Deterministic; needs a benchmark plus the existing coxph-equivalence tests. Low priority: most Cox fits in BRT have small p.
6. **KK21 survival reduced fit: replace with the real Weibull MLE** (`kk21_stepwise_survival.cpp:22-86`). Swap the hand-rolled IRLS for `WeibullAFTLikelihood` plus Newton from `fast_weibull_regression.cpp` (same model, exact analytic Hessian). The minimal alternative is fixing the formulas: working response Xβ + σ(w−δ)/w, and σ-score Σ[z eᶻ − δ(z+1)]/σ with observed information. This is a **correctness** swap (see I-1). It changes KK21 survival weights, so the KK21 matching-quality comparison in memory `project_kk21_speedup_vs_glm_weights_20261008` should be re-run for survival afterward. Not an A/B speed question; validate the reduced fit against `survival::survreg` on fixtures.

### Incidental findings (optional)
- **I-1 (likely bug, high confidence): `kk21_stepwise_survival.cpp:47,52-53,63-65`. The reduced Weibull fit does not converge to the MLE.**
  - **β-step:** with adj = z−1+w (events) or w (censored), the IRLS fixed point satisfies Σ xᵢ(wᵢ−δᵢ)(zᵢ−1)=0. The Weibull AFT score equation is Σ xᵢ(wᵢ−δᵢ)=0.
  - **σ-step:** `score_s` = Σ[δ(z−1) − z eᶻ]/σ, while the true dℓ/dσ = Σ[z eᶻ − δ(z+1)]/σ. The update `scale − score_s/info_s` overshoots the Newton step by +2σ.
  - **Numeric check** (pure numpy port of the loop, n=400, true β=(1, .5, −.3), σ=.7, ~10% censoring; script at `scratchpad/algo_catalog/chk/kk21_irls.py`):
    - code path → β=(−9.56, .34, −.15), σ pinned at the clamp 10;
    - gradient-ascent MLE → β=(1.06, .50, −.27), σ=.72;
    - with XS=[1,w] and no censoring, the code-path intercept diverged to ~1e11.
  - **Effect:** score statistics are computed from wrong residuals, which affects KK21 covariate weights. That is design efficiency, not randomization validity.
  - **Scope:** the R wrapper only routes here when censoring is present or `survival_use_speedup_for_no_censoring` is FALSE (`R/design_seq_one_by_one_KK21_stepwise.R:173-177`).
- **I-2: `fast_coxph_regression.cpp:1225` and `:272-284`.** `smart_cold_start` regresses log y on X **without an intercept** (Cox X has none), so the w-coefficient absorbs mean(log y). That gives a poor start, and the sign is flipped by `-`. The Cox log-likelihood is concave, so this costs iterations, not correctness. The standard start is β=0 (coxph). Also: if all 10 step-halvings fail, the loop accepts the 2⁻¹⁰ step anyway (`:362-367`).
- **I-3: `fast_survival_models_optim.cpp:380-496`.** The analytic dep-cens Hessian is unreachable dead code after the FD block returns at `:378`. Either delete it, or validate it against FD and enable it.
- **I-4: `small_kernel_hoists_batch.md` Item C** proposes a per-draw counting pass over `rank0[i_b]` for Cox BRT and plans a test "with δ≠0". With δ≠0, treated times are rescaled, so the **pooled** order is no longer a function of parent ranks. The δ≠0 case needs per-arm counting passes plus a merge (as in TODO-2), and `noise_mat` draws must fall back to sorting. As written, C1 would produce wrong orderings for δ≠0.
- **I-5: `fast_coxph_regression.cpp:519`.** `cox_fit` drops `warm_start_fisher_info` when dispatching to `cox_lbfgs` (the argument is accepted but never forwarded).
- **I-6: `fast_coxph_regression.cpp:112-119`, `:544-563`.** The line-search objective and the robust-vcov score residuals compute risk sets by **subtracting** from the grand total. The gradient/Hessian path accumulates in reverse, which is stable. When η spans ≳ 30 (exp range > 1e13), late risk sets suffer cancellation, and the objective and gradient can disagree slightly, causing spurious step-halving. Fix: reverse accumulation (O(n), same cost).
- **I-7: audit row A** (and `multistart_nonconcave_likelihoods.md:44`) says "Weibull AFT (Burridge parametrization)". The code optimizes (β, log σ), not Burridge's (β/σ, 1/σ). The one-start conclusion still holds, because the map is a diffeomorphism, so the unique stationary point is preserved. But the stated reason (concavity of the optimized surface) is not literally true of what the code optimizes.
- **I-8: `fast_gehan_wilcox.cpp:27-33`.** The kernel is named Gehan–Wilcoxon but uses Peto–Prentice weights Ŝ(t⁻) (= survdiff ρ=1). This is documented in the in-file comment, but the class and function names may mislead users who expect Gehan's Y(t) weight. Gehan vs Peto–Prentice can differ materially under unequal censoring.
- **I-9: `fast_weibull_frailty.cpp:154-157`.** log σ_ε and log σ_u are clamped to ±8 but keep a nonzero gradient beyond the clamp. This is the same stale-gradient pattern already fixed for Clayton (`fast_survival_models_optim.cpp:83-88`). It is only reachable on degenerate data.

---

## 6. C++ — rank tests, exact/score CIs, CI inversion, special functions


Scope: 20 files in `R/EDI/src/` (all read in full). "Dead" = no caller in `R/EDI/R/` or `R/EDI/tests/` (grep, 2026-10-09); may still be reachable from a Python/`EDI_CORE_ONLY` binding. Complexity symbols: `n` subjects, `n_T,n_C` arm sizes, `m` pairs, `K` ordinal levels, `S = 2·n_T·n_C` (JT stat support), `B` replicates, `L` value-space bisection passes (≤96, ~53 typical for doubles).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| fast_wilcox_hl.cpp:45 `median_in_place` | median of a materialized array | two `std::nth_element` calls (introselect) | O(N) | NEW-rank-selection | Keep (linear-time selection is optimal) |
| fast_wilcox_hl.cpp:71,87,108 `count_pairwise_diffs_leq` / `max_pairwise_diff_leq` / `select_pairwise_diff_sorted` | k-th order statistic of the n_T·n_C pairwise differences X−Y (two-sample Hodges–Lehmann) | value-space bisection on [min diff, max diff]; each step a two-pointer O(n_T+n_C) count of diffs ≤ x; stops at float exhaustion or 96 iters; snaps to largest realized diff ≤ hi | O(n log n) sort + O((n_T+n_C)·L) | NEW-rank-selection | Keep-tracked (`wilcox_hl_kernel_hoisting.md` TODO-3 early stop, TODO-4 warm bracket) — but TODO-3's stop rule needs a tie-safe variant (Incidental 6) |
| fast_wilcox_hl.cpp:135,149,166 `count_walsh_avgs_leq` / `max_walsh_avg_leq` / `select_walsh_avg_sorted` | k-th of the m(m+1)/2 Walsh averages (one-sample HL) | same value-space bisection + two-pointer count | O(m log m + m·L) | NEW-rank-selection | Keep (only caller is legacy IVWC bootstrap) |
| fast_wilcox_hl.cpp:192 `hl_from_groups` | two-sample HL point estimate | n_T·n_C ≤ 4096: materialize all diffs + introselect; else sort both arms + `select_pairwise_diff_sorted` (×2 if even) | ≤4096: O(n_T n_C); else O(n log n + n·L) | NEW-rank-selection | Keep-tracked (`wilcox_hl_kernel_hoisting.md` TODO-1 hoist sort, TODO-2 buffers). NOT the naive O(nm log nm) all-pairs sort |
| fast_wilcox_hl.cpp:220 `hl_signed_rank` | one-sample HL (Walsh median) | materialize ≤4096 else sort + Walsh selection | O(m²) / O(m log m + m·L) | NEW-rank-selection | Keep (legacy-only caller) |
| fast_wilcox_hl.cpp:250 `estimate_hl_ssq_rank_sum`, :268 `estimate_hl_ssq_signed_rank` | variance of all pairwise diffs / Walsh averages (IVWC weights) | explicit double loop over all pairs, one-pass sum/sum² | O(n_T n_C) / O(m²) | NEW-closed-form-stat | Adopt, low priority — exact O(n) closed forms exist (TODO 5); caller is legacy IVWC |
| fast_wilcox_hl.cpp:454 `compute_wilcox_hl_distr_parallel_cpp` | Monte-Carlo randomization distribution of HL (`InferenceAllSimpleWilcox`) | per replicate: partition y by w, `hl_from_groups` (re-sorts) | O(B·(n log n + n·L)) | NEW-perm-stat-kernel (+E for p-value) | Keep-tracked (`wilcox_hl_kernel_hoisting.md` TODO-1..6; exact alternative `exact_rank_tests_shift_algorithm.md` TODO-2/3) |
| fast_wilcox_hl.cpp:599 `compute_wilcox_hl_rand_bootstrap_parallel_cpp` | BRT distribution of HL | per replicate gather + optional noise + `hl_from_groups` | O(B·(n log n + n·L)) | J | Keep (noise breaks the presort hoist; balanced indices = audit J) |
| fast_wilcox_hl.cpp:509 `compute_wilcox_matching_ivwc_bootstrap_parallel_cpp` | IVWC (matched signed-rank HL + reservoir HL, inverse-variance weighted) bootstrap | per replicate `std::map` pair grouping + two HL selections + O(m²)/O(n²) variance loops | O(B·(n log n + m² + n_T n_C)) | J | Keep (legacy IVWC, never public per memory); its O(m²) variance helpers are TODO 5 |
| fast_wilcox_hl.cpp:387 `compute_wilcox_hl_bootstrap_parallel_cpp` | HL bootstrap | per replicate `hl_from_groups` | O(B·n log n) | J | Keep — dead (Incidental 8) |
| fast_wilcox_parallel.cpp:25 `compute_single_wilcox_stat`; :61 `compute_wilcox_distr_parallel_cpp`; :134 `..._from_list_...` | MC null distribution of mean-midrank difference | δ=0: midranks computed once, per replicate O(n) masked sum; δ≠0: full `std::sort` + midrank per replicate | δ=0 O(n log n + B·n); δ≠0 O(B·n log n) | NEW-perm-stat-kernel | Keep — dead, slated for deletion (`ols_randomization_distr_cpp_wiring.md` TODO-4 per `wilcox_hl_kernel_hoisting.md` header) |
| fast_kk_wilcox_parallel.cpp:107-215 `compute_matching_wilcox_distr_parallel_cpp` (fixed-matching path) | MC null of standardized signed-rank(pairs) + rank-sum(reservoir) | reservoir ranks hoisted at δ=0; pair |diff| re-sorted every replicate | O(B·(m log m + n_R)) at δ=0 | NEW-perm-stat-kernel | Keep-tracked (`kk_signed_rank_hoisting.md` TODO-1: at δ=0 |diff| ranks are w-invariant → O(B·m)) |
| fast_kk_wilcox_parallel.cpp:218-303 (same fn, non-fixed path) | same, matching varies per replicate | per replicate rebuild pairs + 2 sorts | O(B·n log n) | NEW-perm-stat-kernel | Keep (matching changes each draw; sort is required) |
| fast_jonckheere_terpstra.cpp:18,36 `build_log_factorials` / `build_log_choose_table` | log C(n_k, t) tables | cumulative log sums | O(n) | NEW-exact-discrete-null | Keep |
| fast_jonckheere_terpstra.cpp:64 `compute_jt_statistic2_from_counts` | 2U (Mann–Whitney with ordinal ties) from level counts | single pass over levels | O(K) | NEW-closed-form-stat | Keep |
| fast_jonckheere_terpstra.cpp:82 `recurse_jt_distribution` + :136 `exact_jonckheere_terpstra_pval_cpp` | exact permutation null PMF of 2U for 2 arms on K tied ordinal levels (multivariate hypergeometric) | depth-first **enumeration of every composition** (t_1..t_K), Σt_k=n_T, t_k≤n_k; no feasibility pruning, no size guard, no interrupt check | O(#compositions) — exponential in K: 1.2e5 (K=5,n=100), 4.5e9 (K=11,n=100), 2.8e12 (K=11,n=200) leaves (computed, balanced levels) | NEW-exact-discrete-null | **Adopt** (TODO 1): polynomial DP, identical PMF to rounding |
| fast_jonckheere_terpstra.cpp:231 `compute_jt_rand_bootstrap_parallel_cpp` | BRT distribution of superiority U/(n_T n_C) − ½ | per replicate sort controls + 2 binary searches per treated | O(B·n log n) | NEW-perm-stat-kernel | Keep (O(n+K) counting variant is a small optional win, TODO 9) — no O(n²) anywhere |
| fast_ridit_analysis.cpp:25 `fast_ridit_scores_from_ref_indices` | ridit scores vs a reference arm | sorted-vector insert for levels + binary search per subject | O(n·K) worst / O(n log K) | NEW-closed-form-stat | Keep (K small); see Incidental 2 (between-level rule) |
| fast_ridit_analysis.cpp:110 `fast_ridit_analysis_result` | mean-ridit contrast + SE | one pass | O(n) | NEW-closed-form-stat | Keep |
| ridit_distr_parallel.cpp:18,44,68 `get_ridit_map_cpp` / `compute_mean_ridit_with_map_cpp` / `compute_single_ridit_estimate_cpp` | per-replicate ridit estimate | copy + sort + unique reference arm per replicate, binary search per subject; string compare per element | O(n log n) per replicate | NEW-perm-stat-kernel | Keep-tracked (`ridit_kernel_level_slots.md` TODO-1/2: precomputed level slots → O(n+K)) |
| ridit_distr_parallel.cpp:106 `compute_ridit_distr_parallel_cpp` | MC randomization distribution | pooled: map hoisted; control/treatment: per-replicate rebuild | O(B·n log n) | NEW-perm-stat-kernel | Keep-tracked (same plan) |
| ridit_distr_parallel.cpp:171 `compute_ridit_bootstrap_parallel_cpp` | bootstrap distribution | per replicate gather + rebuild | O(B·n log n) | J | Keep-tracked (`ridit_kernel_level_slots.md` TODO-3) |
| ridit_distr_parallel.cpp:238 `compute_ridit_rand_bootstrap_parallel_cpp` | BRT distribution | per replicate gather + rebuild map | O(B·n log n) | J | Keep (level slots apply here too; add to the plan's TODO-3 scope) |
| fast_bai_parallel.cpp:26 `compute_bai_distr_parallel_cpp` | MC null of matched-pair mean diff with Bai–Romano–Shaikh pairs-of-pairs variance, convex combo with reservoir | per replicate O(n) bucket by match id + O(n_halves) λ² term | O(B·(n + n_halves)) | NEW-closed-form-stat | Keep (linear; reading the data is the lower bound) |
| cmh_speedups.cpp:170 `compute_cmh_block_se_cpp` | null SE of block-stratified risk difference (hypergeometric within equal blocks) | flat accumulator by block id, closed form Σ s(n_b−s)/(n_b−1) | O(n) | NEW-closed-form-stat | Keep |
| cmh_speedups.cpp:230 `compute_extended_robins_block_se_cpp` | block-stratified RD variance (extended Robins) | flat accumulator, closed form | O(n) | NEW-closed-form-stat | Keep |
| miettinen_nurminen_speedups.cpp:18 `mn_constrained_mle_pc_cpp` | constrained MLE of p_C s.t. p_T−p_C=δ | 60-iteration bisection on the score, 1e15 sentinels at boundaries, early exit |score|<1e-9 | O(60) per δ | NEW-1d-constrained-mle | Adopt, low priority (TODO 3): closed-form cubic |
| miettinen_nurminen_speedups.cpp:80,124 `mn_z_statistic_cpp` / `mn_pvalue_cpp` | MN score z and 2Φ(−|z|) | O(1) + `pnorm_fast` | O(60) | NEW-special-functions | Keep (p floors at 1.2e-15 for |z|>8 — Incidental 3) |
| miettinen_nurminen_speedups.cpp:139 `mn_ci_internal` | MN score-CI bounds | ≤50-step bisection on δ per bound, tolerance in p-space, each step a full inner 60-step bisection | ≤2·50·60 score evals | M | Adopt, low priority (TODO 3; extend `brent_ci_inversion.md` scope). Absolute cost is microseconds |
| newcombe_speedups.cpp:212 `wilson_score_interval_internal` | Wilson score CI | closed form, z via `fast_qnorm` (Acklam) | O(1) | NEW-special-functions | Keep algorithm; swap quantile to exact (TODO 7) |
| newcombe_speedups.cpp:244 `newcombe_independent_ci_internal` | Newcombe method 10 RD CI | closed form from two Wilson CIs | O(1) | NEW-closed-form-stat | Keep (R-side p-value inverts it over α with `uniroot` — appropriate) |
| newcombe_speedups.cpp:305 `newcombe_paired_ci_cpp` | Newcombe paired RD CI | closed form with Pearson φ of the 2×2 | O(1) | NEW-closed-form-stat | Investigate: verify φ definition against Newcombe (1998b) (whether a corrected φ is required when AD−BC > 0 or a margin is 0) |
| zhang_exact_speedups.cpp:22 `binom_two_sided_pval` | exact two-sided binomial p (prob-ordering / "minlike", rel tol 1e-7) | sum all dbinom ≤ dbinom(obs) | O(k) | NEW-exact-discrete-null | Keep |
| zhang_exact_speedups.cpp:41 `fisher_noncentral_two_sided_pval` | exact noncentral-hypergeometric (conditional OR) two-sided p | full support log-weights + log-sum-exp, minlike rule | O(min(row1,col1)) lgamma calls per δ | NEW-exact-discrete-null | Keep (δ-free log-weights could be cached across the R-side CI bisection; trivial at EDI sizes) |
| inference_helpers_zhang.R:44 `zhang_bisect_ci_boundary` (R; consumer of the two above) | CI by inverting a discontinuous exact p(δ) | 50-step bisection, stop on |p−α|<tol or width<1e-8 | ≤50 p evals per bound | D/M (exact-discrete variant) | Keep — p(δ) is a step function, so Brent degenerates to bisection; see Incidental 15 |
| zhang_exact_speedups.cpp:111 `compute_zhang_match_data_cpp`, :290 `compute_matching_wy_stats_cpp` | split matched pairs vs reservoir, discordant counts, X diffs | single pass | O(n·p) | NEW-closed-form-stat | Keep |
| spbr_speedups.cpp:12 `spbr_redraw_w_cpp` | stratified permuted-block assignment redraw | `std::map<string>` per stratum, shuffle per new block | O(n log S) | NEW-assignment-draw | Keep — dead (Incidental 17 for RNG portability) |
| spbr_speedups.cpp:47 `stratified_bootstrap_indices_cpp` | stratified bootstrap indices | `std::map` strata, uniform draws per stratum, final shuffle | O(n log S) | J | Keep (balanced-bootstrap prototype of audit J applies) |
| gcomp_speedups.cpp:96 `gcomp_fractional_logit_point_estimate_cpp` (+:150 alias) | G-computation standardized risk diff | two plogis passes | O(np) | NEW-closed-form-stat | Keep |
| gcomp_speedups.cpp:175 `compute_gcomp_logistic_post_fit` (+:345,:366 wrappers) | HC0 sandwich + delta-method SE of standardized RD / log RR | LDLT of XᵀWX, explicit inverse, solves | O(np² + p³) | A (post-fit linear algebra) | Keep (p tens; see Incidental 16 on estimand) |
| gcomp_speedups.cpp:384 `gcomp_logistic_cluster_post_fit_cpp` | same with cluster-robust meat | `unordered_map` of cluster scores | O(np² + p³) | A | Keep |
| gcomp_speedups.cpp:545 `gcomp_ordinal_proportional_odds_post_fit_cpp` | standardized expected-score diff under PO | K−1 plogis per subject per arm | O(n(p+K)) | NEW-closed-form-stat | Keep |
| lrt_ci_newton.cpp:20 `eval_lrt` + :99 `lrt_ci_nr_cpp` | LR CI bounds (each eval = constrained refit) | Wald-seed / exponential bracket, then Newton on p(δ)−α with envelope-theorem dp/dδ = 2 f_χ²(T)·score_j, bisection safeguard, stop |p−α|<1e-7 | ~4–8 refits per bound (unmeasured) | M | Prototype (TODO 4): Newton on the signed root r(δ) — deterministic, eval-count measurement only, no A/B equivalence question |
| lrt_ci_newton.cpp:214 `pval_invert_ci_cpp` | score / gradient / Bartlett-LR CI bounds | bracket search + pure bisection to 1e-6 in δ | ~20 refits per bound | M | Keep-tracked (`brent_ci_inversion.md` TODO-1..3 = audit row M) |
| bisection_ci.cpp:11 `edi::bisection_ci_search` (+:72 `bisection_ci_parallel_cpp`, :98 `bisection_ci_single_bound_cpp`, bisection_ci_loop.cpp:28 `bisection_ci_loop_cpp`, bisection_ci_search.h) | randomization-CI bound by inverting an MC p-value | bisection, stop on p-gap ≤ tol or float exhaustion (≤2048 iters) | ~52+ full-B evals per bound (Incidental 13) | D | Keep-tracked (`garthwaite_buckland_ci_search.md`); all four exports are dead — the live search is R-level |
| fast_erfc.h:99 `fast_erfc` | erfc(x) | Cephes rational approximations (|x|<1 via 1−erf; 1≤|x|≤5.6 P/Q·exp(−x²)); libm beyond 5.6 | O(1) | NEW-special-functions | Keep (~1e-15 abs; exp(−x²) without split-exponent trick costs ~1e-14 rel at x≈5.6, harmless) |
| fast_erfc.h:154 `pnorm_fast` | Φ(x) | ½·fast_erfc(−x/√2), **clamped to 6e-16 / 1−6e-16 for |x|≥8** | O(1) | NEW-special-functions | Adopt (TODO 2): real tail for x≤−8 (true Φ(−10)=7.6e-24); used in probit score/Mills ratio, GLMM probit link, ordinal probit, MN p |
| fast_erfc.h:166 `fast_log_pnorm` | log Φ(x) | log of the above, **clamped at −35.0496 for x≤−8** (true log Φ(−10) = −53.2, log Φ(−20) = −203.9) | O(1) | NEW-special-functions | **Adopt** (TODO 2): asymptotic Mills-ratio branch — accuracy regression vs the `R::pnorm(log.p=TRUE)` it replaced (perf TODO-101) |
| fast_erfc.h:188 `fast_qnorm` | Φ⁻¹(p) | Acklam rational approx, ~1.15e-9 rel error, no refinement | O(1) | NEW-special-functions | Keep for optimizer warm starts; Adopt exact quantile in Wilson CI (TODO 7) |
| fast_gamma_functions.h:28 `fast_digamma` (+:50 functor) | ψ(x) | recurrence shift to x≥8 + asymptotic series to x⁻¹⁰ | O(1)–O(8) | NEW-special-functions | Keep (~1e-12 rel, adequate for score equations) |
| fast_gamma_functions.h:59 `fast_trigamma`, :82 `fast_trigamma_vec` | ψ'(x) | same, vectorized with masked shifts | O(1)–O(8) | NEW-special-functions | Keep |
| fast_gamma_functions.h:105,120,137 `fast_lgamma_stirling` / `_lanczos` / `fast_lgamma` (+:145 `fast_lbeta`) | log Γ(x) | Lanczos (g=7, 9 coeffs) for x<8 (x<0.5 via +1 shift), Stirling to x⁻¹³ for x≥8 | O(1) | NEW-special-functions | Keep (~1e-15 abs; relative error unbounded only near the zeros x=1,2, harmless in differences) |
| fast_gamma_functions.h:155 `fast_dnbinom_mu` | NB log-pmf (mean param) | lgamma differences + size·(log size − log(size+mu)) | O(1) | NEW-special-functions | Adopt, low priority (TODO 8): cancellation ~1e-7–1e-6 abs at size≈1e8 (near-Poisson boundary) — R's `dnbinom_mu` uses log1p/dbinom_raw there |
| fast_gamma_functions.h:172,188,215,226 `fast_gammap_series` / `fast_gammaq_cf` / `fast_gammaq` / `fast_pchisq_upper` | upper χ² tail (LR p-values) | series for x<a+1 (1−P), modified-Lentz continued fraction otherwise, 1e-16 stop | O(iters ≤500) | NEW-special-functions | Keep (df=1 at χ²≈3.84 takes the CF branch, ~1e-14 rel; prefactor loses ~a·log(a)·ε rel at large df) |
| glue — fast_wilcox_hl.cpp `apply_shift_hl`, `wilcox_hl_point_estimate_result`, `wilcox_hl_point_estimate_cpp`, `wilcox_hl_signed_rank_point_estimate_cpp` (dead); fast_kk_wilcox_parallel.cpp `apply_shift_kk_wilcox`; fast_ridit_analysis.cpp `fast_ridit_scores_cpp` (dead), `fast_ridit_analysis_cpp`; zhang `zhang_exact_binom_pval_cpp`/`zhang_exact_fisher_pval_cpp`; newcombe/MN Rcpp wrappers; erfc.h `dnorm_fast`/`fast_log_dnorm`; fast_math_utils.cpp (all 8 `fast_*_vec_cpp` exports are elementwise loops over the header kernels above) | — | — | — | — | glue — no algorithmic content |

### Options & disadvantages

**HL two-sample selection (k-th of X−Y), `fast_wilcox_hl.cpp:108,192`**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| k-th pairwise diff | **current**: materialize+introselect ≤4096 pairs; else sort + value-space bisection, O((n_T+n_C)·L), L≈53–96 | 1× | 53–96 counting passes; hits the 96-iteration cap when the target diff is exactly 0 (common with integer/tied y) | — |
| | sort all n_T·n_C diffs | ≫ slower (O(nm log nm)) | O(nm) memory per replicate (8 MB at n_T=n_C=1000) | — |
| | materialize + introselect at every size | O(nm) vs O(n·L): slower once n_T n_C ≳ 50·(n_T+n_C), i.e. n ≳ 130 balanced | same memory problem | Hoare (1961) FIND |
| | bisection with early stop (plan TODO-3: stop when count(hi)−count(lo)=1) | ~2–2.5× (passes 53→~log₂(nm)≈18) | stop rule never fires on tied diffs; needs a tie-safe criterion (stop when the only realized value in (lo,hi] is unique: max_diff_leq(hi)==min_diff_gt(lo)) | `wilcox_hl_kernel_hoisting.md` |
| | warm bracket from previous replicate (plan TODO-4) | further ~1.3–2× | correctness depends on validation passes; must be tested bit-identical | same plan |
| | Monahan-style rank-space selection (per-row index bounds, pivot among remaining candidates, recount) | O(n log(nm)) expected ≈ early-stopped bisection; no float-exhaustion pathology, handles ties exactly | randomized pivot would consume RNG → must use a deterministic pivot (weighted median of row medians) to keep R streams untouched; more code | Monahan (1984), ACM TOMS 10(3), Algorithm 616 |
| | Johnson–Mizoguchi / Frederickson–Johnson deterministic selection in X+Y / sorted matrices | O(n log n) or O(n) after sort | large constants, intricate; at n ≤ few thousand no better than early-stopped bisection | Johnson & Mizoguchi (1978), SIAM J. Comput.; Frederickson & Johnson (1982), J. Comput. Syst. Sci. |

**Exact null of the two-arm JT/Mann–Whitney statistic on K ordinal levels, `fast_jonckheere_terpstra.cpp:82,136`**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| exact PMF of 2U | **current**: enumerate all compositions (t_1..t_K) | 1× | exponential in K: 1.2e5 leaves at K=5,n=100 (ms) but 4.5e9 at K=11,n=100 and 2.8e12 at K=11,n=200 (an 0–10 pain scale) → effectively hangs, uninterruptible, no guard | — |
| | same + prune branches whose remaining capacity cannot absorb `remaining_treated` | constant-factor only | still exponential | — |
| | dense DP over levels on state (T_k treated so far, s partial 2U) | O(Σ_k n_T·S·(n_k+1)) ≈ 4e8 ops at K=11,n=200 (sub-second); polynomial | **slower than enumeration at small K** (K=5,n=100: ~2.5e7 vs 1.2e5); memory O(n_T·S) doubles (2e6 cells = 16 MB at n=200) | Mehta, Patel & Tsiatis (1984), Biometrics (network algorithm for ordered categorical data) |
| | sparse "network" DP (merge identical (T,s) nodes, hash/active list per level) | never more nodes than enumeration; polynomial worst case | hashing overhead; summation order differs → tolerance-equal, not bit-identical | Mehta & Patel network-algorithm family (as above) |
| | Streitberg–Röhmel shift algorithm over subjects with scores 2×midrank (the `exact_rank_tests_shift_algorithm.md` TODO-1 kernel) | O(n·n_T·S) — same order as dense DP | same small-K slowdown; benefit is one shared kernel for Wilcoxon + JT | Streitberg & Röhmel (1986), Statistical Software Newsletter |
| | FFT / generating-function multiplication | O(K·S log S) | FFT round-off (~1e-16·max) swamps tail probabilities → bad small p-values | — |
| | normal approximation / saddlepoint / Monte Carlo | O(1) / O(B·n) | loses exactness, the method's whole point (class already has an asymptotic path) | Robinson (1982), Ann. Statist. (saddlepoint) |

**MN constrained MLE and MN CI, `miettinen_nurminen_speedups.cpp:18,139`**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| constrained p̃_C | **current** 60-step bisection on score | 1× | 1e15 sentinels; |score|<1e-9 absolute stop is n-scale dependent | — |
| | closed-form cubic root (trigonometric form) | ~30–60× fewer flops, O(1) | must clamp the acos argument and special-case x=0, x=n, δ→±1; needs a cross-check vs bisection over a grid | Miettinen & Nurminen (1985), Stat. Med.; Farrington & Manning (1990), Stat. Med. |
| | safeguarded Newton on score | ~5–10× | must stay inside (max(0,−δ), min(1,1−δ)); safeguard code ≈ bisection anyway | Nocedal & Wright (2006) |
| CI bound | **current** ≤50 bisection steps in δ, tolerance in p-space | 1× | p-space tolerance gives non-uniform δ accuracy | — |
| | Brent on p(δ)−α | ~5–8 evals (≈6–10×) | none material; deterministic, identical within tol | Brent (1973) |
| | secant/Brent on z(δ) − z_{1−α/2} | ~3–6 evals; z is nearly linear in δ so better conditioned than p | must handle the z sign change at the estimate (search each side separately, as now) | Brent (1973) |
| | (no closed form for MN score bounds) | — | — | — |

**LR CI root-finding, `lrt_ci_newton.cpp:99`**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| LR bound | **current** Newton on p(δ)−α + bisection safeguard | 1× (~4–8 refits/bound, unmeasured) | p is sigmoidal in δ → Newton overshoots far from root, falls back to bisection | — |
| | Newton on signed root r(δ)=sgn(δ−est)·√T(δ) − z_{1−α/2}, dr/dδ = −score_j/r (envelope theorem) | ~2–3 refits/bound (r is near-linear in δ) | needs T>0 (true off the estimate); same score-sign dependency as now (Incidental 12) | Venzon & Moolgavkar (1988), Applied Statistics |
| | Brent (derivative-free) | ~5–8 refits | throws away the free derivative | Brent (1973) |
| | Robbins–Monro / Garthwaite–Buckland | ~100–200 refits | wrong tool for a noiseless function (audit row M) | Garthwaite & Buckland (1992) |

**Special functions (NEW-special-functions), `fast_erfc.h`, `fast_gamma_functions.h`**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| Φ, log Φ | **current** Cephes erfc + clamp at |x|≥8 | 1× (benchmarked ~2.5× vs R's pnorm dispatch) | log Φ flat at −35.05 for x≤−8 and Φ floored at 6e-16 → probit/dep-censoring log-lik flat and Mills ratio φ/Φ→0 (true ≈|x|) on extreme points: wrong gradient | Cody (1969), Math. Comp. (R's pnorm basis) |
| | add an asymptotic tail for x<−8: log Φ(x) = −x²/2 − log(−x) − ½log 2π + log(1 − x⁻² + 3x⁻⁴ − 15x⁻⁶ + …) | same speed (one extra log) | ≤~1e-9 rel at x=−8 with 4 terms, better further out; small branch-boundary jump to test | Abramowitz & Stegun (1964), §7.1.23 / §26.2.12 |
| | call `R::pnorm5(..., log_p=1)` in the tail only | negligible (tail is rare) | R-dependent, so not `EDI_CORE_ONLY`-portable | — |
| Φ⁻¹ | **current** Acklam, ~1.15e-9 rel | ~2× vs R qnorm | Wilson/Newcombe bounds differ from R references at ~1e-9 rel | Acklam (unpublished web note) [cite needed] |
| | Wichura AS241 (= R's qnorm) | ~0.5× of Acklam | none for one call per CI | Wichura (1988), Applied Statistics |
| log Γ | **current** Lanczos g=7 + Stirling | ~2× vs R lgamma | ~1e-15 abs; rel error large only near x=1,2 | Lanczos (1964), SIAM J. Numer. Anal. B |
| ψ, ψ' | **current** recurrence + asymptotic | 7–19× vs R | ~1e-12 rel | Abramowitz & Stegun §6.3–6.4 |
| NB log-pmf | **current** lgamma differences | 1.35× vs R | cancellation at large size (near-Poisson): ~1e-7–1e-6 abs at size≈1e8, exactly where NB dispersion runs to the boundary | — |
| | log1p(−mu/(size+mu)) for the size term + R's Poisson-limit branch (x < 1e-10·size) | same | slightly more code | Loader (2000), "Fast and accurate computation of binomial probabilities" (technical note; R's dbinom_raw) |
| χ² upper tail | **current** series / Lentz CF | ~R | prefactor loses ~a·log a·ε rel at large df | Press et al., Numerical Recipes (§6.2) |

**Permutation-statistic kernels (NEW-perm-stat-kernel) — rank/ridit/JT/signed-rank recomputation per replicate**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| statistic per replicate | **current** re-sort per replicate (HL, ridit control/treatment, KK pair ranks, JT BRT) | 1× | O(n log n) per replicate | — |
| | hoist ranks at δ=0 (masked O(n) sum) | log n × | only at δ=0 / w-invariant parts | `kk_signed_rank_hoisting.md`, `ridit_kernel_level_slots.md` |
| | presort y once; stable partition per replicate (monotone shifts keep order: additive, ×e^δ, logit, round(y·e^δ)) | log n × at any δ | breaks with per-draw noise (BRT smoothed) | `wilcox_hl_kernel_hoisting.md` TODO-1 |
| | count-by-level for ordinal (K levels): U = Σ_k t_k(C_{<k} + ½c_k) | O(n+K) per replicate | requires precompressed level index | — |
| | exact null (shift algorithm / closed-form PMF) instead of MC | removes B entirely when size rule holds | exact only for fixed-n_T designs; tied scores need 2×midrank | `exact_rank_tests_shift_algorithm.md`, `exact_randomization_nulls_closed_form.md` |

**Exact-discrete CI inversion (Zhang combined, `inference_helpers_zhang.R:44` over `zhang_exact_speedups.cpp`)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| bound of discontinuous p(δ) | **current** bisection | 1× | needs a verified outside bracket (Incidental 15) | — |
| | Brent | no gain: step function → Brent falls back to bisection | none, but no benefit | Brent (1973) |
| | enumerate jump points (δ where two support-point probabilities swap order) and evaluate exactly | exact endpoints, finite evaluations | implementation effort; needed only if exact endpoints (not tol) are wanted | Fay (2010), R Journal ("Two-sided exact tests and matching confidence intervals for discrete data") |

**NEW-closed-form-stat / NEW-assignment-draw / NEW-1d-constrained-mle** — every Keep row in these families is a single O(n) or O(n·p) pass (CMH/Robins block SEs, Bai pairs-of-pairs, ridit scores, g-comp point estimates, Zhang data split, Newcombe/Wilson) whose cost is bounded below by reading the data; no faster algorithm exists. The only non-Keep members are the O(nm) HL variance helpers (exact O(n) closed form, TODO 5) and the MN constrained MLE (closed-form cubic, TODO 3).

### New TODO candidates
1. **JT exact null → polynomial DP** — `fast_jonckheere_terpstra.cpp:82-131,203`. Replace composition enumeration with a sparse level DP on (treated-so-far, partial 2U) (merge identical nodes), or with the `exact_rank_tests_shift_algorithm.md` TODO-1 kernel using 2×midrank scores; keep enumeration for small estimated leaf counts if it benchmarks faster; add `checkUserInterrupt` and a size rule with an asymptotic fallback. Expected (theoretical): 2.8e12 leaves → ~4e8 cell updates at K=11, n=200 (hang → sub-second); ~1× at K≤5. Risk: summation order → tolerance-equal PMF, not bit-identical. Deterministic drop-in; gate = brute-force enumeration at n≤12 plus the current kernel on small-K fixtures to 1e-12.
2. **Normal tail accuracy in `pnorm_fast` / `fast_log_pnorm`** — `fast_erfc.h:154-170`. Add an asymptotic Mills-ratio branch below −8 (upper tail by symmetry). Not a speed item: an accuracy fix for probit (`fast_probit_regression.cpp:16-25,75,…`), dependent-censoring survival (`fast_survival_models_optim.cpp:307-308,409-410`), GLMM probit link (`_glmm_links.h:36`), ordinal probit (`ordinal_fixed_link_helpers.h:78`). Deterministic; changes values only where |η|>8. Gate: grid vs `R::pnorm(log.p=TRUE)` on [−40, 40] to 1e-12 rel, then the existing probit/dep-cens tests.
3. **MN: closed-form constrained MLE + Brent/secant on z(δ)** — `miettinen_nurminen_speedups.cpp:18-62,139-169`. ~50× fewer score evaluations (theoretical; absolute cost already microseconds, so this is about precision and consistency with row M). Fold into `brent_ci_inversion.md`'s scope. Deterministic drop-in; gate = existing MN CI tests plus a grid cross-check against the bisection MLE.
4. **LR CI: Newton on the signed root** — `lrt_ci_newton.cpp:153-184`. Iterate on r(δ)=sgn·√T − z instead of p−α. Expected ~4–8 → ~2–3 constrained refits per bound (theoretical). Risk: none for the converged value within tol; also use an inside Wald seed as the new inner bracket point (Incidental 10). Deterministic; gate = existing LR CI tests plus an eval-count log.
5. **HL variance helpers to O(n)** — `fast_wilcox_hl.cpp:250-285`. Σ over all pairs of (d−d̄)² = n_C·SS_T + n_T·SS_C; Walsh: Σ_{i≤j}(d_i+d_j)² = (m+2)Σd² + (Σd)², Σ_{i≤j}(d_i+d_j) = (m+1)Σd (use centered sums). O(n_T n_C)/O(m²) → O(n). Tolerance-equal and more stable than the current one-pass formula. Low priority (legacy IVWC only). Deterministic.
6. **Tie-safe early stop for HL bisection** — amend `wilcox_hl_kernel_hoisting.md` TODO-3. count(hi)−count(lo)==1 never holds on tied diffs; stop when max_pairwise_diff_leq(hi) == min diff > lo, which is also bit-identical and fixes the 96-iteration cap on HL=0. Optionally prototype the Monahan-style rank-space selection with a deterministic pivot as the TODO-3 alternative.
7. **Exact z in Wilson/Newcombe** — `newcombe_speedups.cpp:215`. Use `R::qnorm5` (or AS241) instead of Acklam: one call per CI, removes the ~1e-9 discrepancy with R references. Trivial deterministic drop-in.
8. **Stable `fast_dnbinom_mu` at large size** — `fast_gamma_functions.h:155-167`. log1p form for the size term plus R's Poisson-limit branch. Accuracy only, near the NB dispersion boundary. Gate: vs `R::dnbinom_mu` for size ∈ [1e-3, 1e10].
9. (small) **O(n+K) per-replicate JT/ridit BRT statistic** — `fast_jonckheere_terpstra.cpp:255-273`, `ridit_distr_parallel.cpp:271-289`. Precompress y0 to level indices once, count per replicate. Integer arithmetic gives an identical result. Fold into `ridit_kernel_level_slots.md` TODO-3.

### Incidental findings (optional)
1. `fast_jonckheere_terpstra.cpp:82-131`: no `checkUserInterrupt`, no size guard, no infeasible-branch pruning, so a large-K ordinal outcome (for example 0–10 scales) hangs R uninterruptibly via `InferenceOrdinalJonckheereTerpstraTest$compute_exact_two_sided_pval_for_treatment_effect()` (`inference_ordinal_jonckheere_terpstra_test.R:193`).
2. Ridit between-level rule is wrong: `fast_ridit_analysis.cpp:76-81`, `ridit_distr_parallel.cpp:59-61`. A response level absent from the reference arm but between present levels gets ½(R_{k−1}+R_k) = c_k + ¼(p_k − p_{k−1}). The correct ridit P(X<y)+½P(X=y) is c_k, the cumulative mass below. This breaks the stated equivalence with the Mann–Whitney superiority estimate whenever the reference arm misses an interior level (common with sparse ordinal data). The below-all and above-all cases (0 and 1) are already correct.
3. `fast_erfc.h:166-170` docs and comments overstate accuracy. `fast_math_utils.cpp:262-266` says log Φ is "stable for large negative x", and `fast_probit_regression.cpp:16` says it "falls back to fast_log_pnorm's wider-range series", but both clamp at −35.05. This was introduced by perf TODO-101 (`performance_profiling_and_upgrades.md` ~L2018), which replaced `R::pnorm(w,0,1,1,1)` in the dependent-censoring likelihood. MN p-values floor at 1.2e-15 for |z|>8.
4. `fast_math_utils.cpp:187` docs say `fast_dnbinom_mu` returns "numerically identical values" to R. That is false at large size (see TODO 8).
5. `fast_erfc.h:178-187` comment says the only `fast_qnorm` call sites are probit warm starts. `newcombe_speedups.cpp:215` (a reported CI) also uses it.
6. `fast_wilcox_hl.cpp:120-129,177-186`: when the target order statistic is exactly 0.0 (frequent with integer y and ties), bisection cannot reach float adjacency near 0 and always runs the full 96 passes. The result is still correct.
7. `fast_wilcox_hl.cpp:263,272`: `int count` (overflow only above 2³¹ pairs) and the one-pass sum²/N variance formula, which is cancellation-prone.
8. `fast_wilcox_hl.cpp:425-427` treats bootstrap indices as 0-based, while the sibling at `:552` uses 1-based (`idx_col[i]-1`). The first is dead, but it is a trap if revived.
9. `ridit_distr_parallel.cpp:215-218`: invalid bootstrap indices become y=0, w=0 (a fake control at level 0) instead of being dropped.
10. `lrt_ci_newton.cpp:124-141` and `:257-274`: a Wald seed with p>α (inside the CI) is discarded. The exponential search then restarts from `est` instead of setting a=seed, which wastes refits on both inverters.
11. `lrt_ci_newton.cpp:186` vs `:289`: when not converged, LR returns the bracket midpoint, while score/Bartlett returns the outer endpoint `b`. The conservativeness conventions are inconsistent.
12. `lrt_ci_newton.cpp:61`: the dp/dδ sign assumes `score_fn` returns ∂ℓ/∂β (loglik, not negloglik). A caller with the opposite convention silently turns every Newton step into a bisection fallback (slower, no error). Verify per caller.
13. `bisection_ci.cpp:25-43`: on a step-function MC p(δ) with tol < 1/r, the p-gap stop never fires. It runs to floating-point exhaustion (~52 evaluations, ~1000 if the jump sits at δ=0). All 4 exports are dead (no R or test caller).
14. Exact-binomial CI (`inference_incidence_exact_binomial.R`, `binom.test` Clopper–Pearson) is not the inversion of the minlike two-sided p-value in `zhang_exact_speedups.cpp:22`, so CI and p can disagree at α (Fay 2010).
15. `inference_helpers_zhang.R:44-58`: `zhang_bisect_ci_boundary` never checks p(outside) < α. If the true bound lies beyond the MLE CI ± ½ width, it silently returns a truncated bound.
16. `gcomp_speedups.cpp:248-251,462-466`: the delta-method SE propagates only β uncertainty. It omits the covariate-sampling term (1/n)·Var(r1_i − r0_i), so it targets the conditional/sample ATE. Investigate whether that is the intended estimand (Ge et al. 2011, Drug Inf. J.; Ye, Shao, Yi & Zhao 2023, JASA include the term).
17. `spbr_speedups.cpp:35,59-60,76`: `std::shuffle` and `std::uniform_int_distribution` algorithms are implementation-defined. The same R seed gives different draws under libstdc++ vs libc++ (Linux vs macOS). Live via `stratified_bootstrap_indices_cpp`; the codebase has 23 such uses.
18. `fast_kk_wilcox_parallel.cpp:179,209,277,298`: both components are standardized without a tie correction. The permutation test stays valid, but tie-heavy components get mis-weighted in the sum.
19. `newcombe_speedups.cpp:313-314`: `newcombe_paired_ci_cpp` calls the allocating Rcpp `wilson_score_interval_cpp` instead of the `_internal` struct version (minor).

---

## 7. C++ — resampling loops, permutations, bootstrap indices, RNG


Files are in `R/EDI/src/`. "Dead" means the R package never calls the function (checked by grep of `R/EDI/R` with `RcppExports.R` excluded); "test-only" means only `tests/testthat` calls it. Sizes: n tens–low thousands, p tens, B (r) hundreds–low thousands; R's randomization default is `r = 501` (`inference_all_abstract_rand.R:28`).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| RNG.h:172 `RRng::mt_genrand` | uniform 32-bit PRNG word | Mersenne Twister MT19937. Verbatim port of R's `MT_genrand` (Matsumoto & Nishimura 1998), so it is bit-identical to R's stream | O(1) amortized per word (one 624-word twist every 624 draws); 2.5 KB state | NEW-prng-core | Keep (R-parity reproducibility is the binding constraint); throughput and parallel-stream question already tracked as Keep-tracked `performance_profiling_and_upgrades.md → TODO-149(c)` |
| RNG.h:92 `RRng::RRng(uint32)` | seed → MT state | R's `RNG_Init`: 50 + 625 LCG(69069) scramble steps | O(N=624) per construction (~1–2 µs) | NEW-prng-core | Keep (needed for R parity). See Incidental for the 32-bit seed birthday-collision issue |
| RNG.h:114 `RRng(mti, mt)` | continue R's live `.Random.seed` stream | state copy + mti clamp | O(624) | NEW-prng-core | Keep |
| RNG.h:120 `RRng::unif_rand` | U(0,1) double | word × 2^-32, R's `fixup` | O(1) | NEW-prng-core | Keep |
| RNG.h:128 `RRng::norm_rand` | N(0,1) deviate | R's "Inversion": 2 uniforms → 2^27-resolution U → AS241 qnorm | 2 words + 1 rational approx | NEW-prng-core | Keep (R parity; none of these files call it in a hot loop) |
| RNG.h:210 `qnorm_std` | standard normal quantile | AS 241 (Wichura 1988, *Appl. Stat.*), verbatim from R's `qnorm.c` | O(1) | NEW-prng-core | Keep (same accuracy as R, ~1e-16) |
| RNG.h:292 `seed_from_unif01`; r_seed_draw.h:355 `draw_seed_from_r` | derive a child-stream seed from R's stream | one `R::unif_rand()` → uint32 | O(1) | NEW-prng-core | Keep (but see Incidental #2) |
| RNG.h:310 `bounded_rand` | unbiased integer in [0,s) | Lemire's "nearly divisionless" multiply-shift with rejection (Lemire 2019, *ACM TOMACS*) | ~1 word per draw; division only on the rare rejection path | NEW-sampling-primitives | Keep (best-known method) |
| fast_sample_int.cpp:388 `sample_int_replace_internal` (+ :464 wrapper `sample_int_replace_cpp`) | i.i.d. bootstrap row indices for **one** replicate | `size` Lemire draws from a freshly seeded RRng | O(size) + O(624) seeding per call | J | Prototype (balanced bootstrap, TODO-1 below). **This, not `bootstrap_indices.cpp`, is the production bootstrap index path**: `design_abstract.R:979,995`, `design_matching_abstract.R:111`, `design_component_registry.R:462` call it once per replicate |
| fast_sample_int.cpp:398 `resample_group_rows_internal` (+ :471 wrapper) | cluster/block bootstrap: resample groups with replacement and expand to rows | bucket rows by group (counting pass), then Lemire draw per group, concatenate | O(n + G + output rows) | J | Keep (optimal). The balanced variant applies at group level |
| fast_shuffle.cpp:15 `shuffle_cpp` | random permutation of a vector | `std::shuffle` (Fisher–Yates/Durstenfeld) driven by RRng | O(n) | NEW-sampling-primitives | Keep algorithmically, but **dead** (no R caller). See Incidental #4 (in-place mutation) and TODO-3 (std::shuffle is not portable) |
| bootstrap_indices.cpp:28 `bootstrap_indices_internal` (+ :46 `bootstrap_indices_cpp`) | B×n i.i.d. bootstrap index matrix | Lemire draws, row by row | O(Bn) | J | Prototype (balanced). **Test-only**: no production caller, so audit row J's scoping ("change only `bootstrap_indices.cpp`") would change nothing in production; see TODO-1 |
| bootstrap_match_indices.cpp:77 `bootstrap_m_indices_internal` (+ :125 wrapper) | pair-preserving bootstrap: reservoir rows i.i.d. plus whole matched pairs i.i.d. | precomputed pair table, then Lemire draws | O(n + B(n_R + m)) | J | Keep, but **test-only**. The legacy R loop it could replace (`inference_all_KK_mean_diff_IVWC.R:123-146`) is O(B·m·n) (Incidental #6) |
| bootstrap_match_indices.cpp:142 `draw_matching_bootstrap_sample_cpp` | one pair-preserving bootstrap draw (production path for matching designs) | two `Rcpp::Function("sample")` callbacks into R's `sample()` (R's own rejection sampler) | O(n_R + m) + 2 R calls per replicate | J | Keep (cost is trivial next to the per-replicate refit). Mixes R's `sample()` and RRng streams across designs; harmless |
| bootstrap_match_indices.cpp:183 `compute_bootstrap_matching_stats_cpp` | gather a resampled reservoir + pair-difference summaries (d+, d−, n11..n00, X diffs) | single gather pass plus a column non-zero scan | O(np) | NEW-kk-summary-stats | Keep |
| bootstrap_match_indices.cpp:331 `match_stats_from_indices_cpp` | gather rows, then call `compute_zhang_match_data_cpp` (another file) | row gather | O(np) | NEW-kk-summary-stats | Keep, but **dead** (only the dead `kk_bootstrap_loop.cpp` calls it). Possible issue: resampled duplicate pairs keep their original match id (Incidental #7) |
| base_bootstrap_loop.cpp:12 `base_bootstrap_loop_cpp` | generic bootstrap driver | serial loop; per replicate a row gather plus an R callback (OpenMP commented out) | O(B(np + refit)) | J | Keep, but **dead** |
| randomization_loop.cpp:12 `randomization_loop_cpp` | generic randomization driver | serial R-callback loop with a fixed r | O(r·refit) | E | Keep, but **dead** |
| kk_bootstrap_loop.cpp:22 `matching_bootstrap_loop_cpp` | KK bootstrap driver | serial R-callback loop | O(B(np + refit)) | J | Keep, but **dead** |
| kk_bootstrap_reservoir_stats.cpp:108 `compute_matching_reservoir_stats_cpp` (+ :76 `sample_variance`, :93 `mean_or_na`) | KK compound (Kim–Kopf IVWC) summary stats | one-pass Σx/Σx² variance; reservoir split by `NumericVector::push_back` | O(n_R²) because each `push_back` copies (Incidental #8); arithmetic O(n) | NEW-streaming-moments | Keep, but **dead**. If revived, use the TODO-4 variance |
| KK_bootstrap_helper_fillin.cpp:178 `fill_i_b_with_matches_loop_cpp` | expand sampled pair ids to row indices | linear scan of `m_vec` for every sampled pair | O(m·n) | J | Keep, but **dead** (a pair table makes it O(n + m), as `bootstrap_m_indices_internal` already does) |
| exchangeable_resampling_draws.cpp:170 `proportional_allocation` | split a subsample size across strata in proportion to stratum size | Hamilton / largest-remainder rounding | O(G log G) | NEW-sampling-primitives | Keep (standard method, trivial cost) |
| exchangeable_resampling_draws.cpp:203 `sample_group_units` (replace = TRUE) | i.i.d. units within a stratum | Lemire draws | O(k) | J | Keep |
| exchangeable_resampling_draws.cpp:223 `sample_group_units` (replace = FALSE) | k-of-n units without replacement (m-out-of-n subsampling) | rejection: draw positions, reject duplicates through an `unordered_set` | expected n(H_n − H_{n−k}) draws (≈0.69n for k = n/2, ≈n ln n as k → n) plus a hash insert per draw | NEW-sampling-primitives | Prototype → partial Fisher–Yates (TODO-2) |
| exchangeable_resampling_draws.cpp:233 `renumber_positive_match_ids` | compact match ids to 1..M | sort + unique + hash map | O(N log N) | glue-ish | Keep |
| exchangeable_resampling_draws.cpp:257 `build_draw` | expand units to rows; optional row-order restoration | concatenate; `stable_sort` of an index permutation when `preserve_order` | O(N log N) | NEW-sampling-primitives | Keep (a counting sort keyed on row < n would be O(N + n); immaterial) |
| exchangeable_resampling_draws.cpp:375 `exchangeable_resampling_draws_cpp` | B stratified unit-level bootstrap/subsample draws | single RRng stream; per b, per stratum `sample_group_units` | O(B·size·(1 + hash)) | J | Keep (balanced variant possible for replace = TRUE; folded into TODO-1) |
| generate_permutations.cpp:135 `generate_permutations_matching_internal` | null draws for a KK matched design: within-pair coin flip, reservoir Bernoulli | 1 uniform per pair and per reservoir unit | O(n) per draw, O(nB) total | E | Keep. Exact enumeration option for small m: TODO-6 |
| generate_permutations.cpp:170 `generate_permutations_bernoulli_internal` | i.i.d. Bernoulli(prob_T) assignments | `unif_rand() < prob_T` per subject | O(nB) words | E | Keep (bit-packing 32 coins per word for prob_T = ½ breaks the stream for no material gain) |
| generate_permutations.cpp:181 `generate_permutations_ibcrd_internal` | complete randomization: n_T of n | full Fisher–Yates via `std::shuffle` of a 1^{n_T}0^{n−n_T} template; copies the template every b | O(n) per draw | NEW-sampling-primitives | Keep algorithmically (a partial shuffle saves ≤2× RNG words, and libstdc++ already draws two positions per word); **portability**: TODO-3 |
| generate_permutations.cpp:197 `generate_permutations_blocking_internal` | stratified complete randomization | `std::shuffle` per stratum | O(n) per draw | NEW-sampling-primitives | Keep; TODO-3 |
| generate_permutations.cpp:218 `generate_permutations_efron_internal` | Efron biased-coin null draws | sequential simulation of the design rule | O(n) per draw | NEW-seq-design-null-draws | Keep (optimal) |
| generate_permutations.cpp:240 `generate_permutations_atkinson_internal` + :80 `compute_atkinson_weight_internal` | Atkinson D_A-optimal biased-coin null draws | per draw, per t: rebuild the (t−1)×(p+2) design `[w,1,X]`, form XᵀX (O(tp²)), FullPivLU + full inverse (O(p³)), read 1 row. Column-selection QR hoisted out of the B loop (:251) | **O(B·(n²p²/2 + n p³))** | NEW-seq-design-null-draws | **Adopt** (TODO-5): block-inverse / Schur identity gives O(n²p² once + B·n·p²) |
| generate_permutations.cpp:27,46,57 `which_cols_vary_subset_int`, `extract_submatrix_int`, `find_independent_cols_int` | per-t column selection for Atkinson | scan + FullPivHouseholderQR rank | O(n·(tp + tp² )) once, not per draw | A-adjacent (linear algebra) | Keep (already hoisted; rank-revealing QR is correct here) |
| generate_permutations.cpp:297 `generate_permutations_pocock_simon_internal` | Pocock–Simon minimization null draws | sequential rule with per-level counts | O(B·n·num_covs) | NEW-seq-design-null-draws | Keep (optimal) |
| generate_permutations.cpp:357 `generate_permutations_cluster_internal` | cluster randomization | 1 uniform per cluster plus scatter | O(n) per draw | E | Keep |
| generate_permutations.cpp:392 `generate_permutations_spbr_internal` | stratified permuted blocks | `std::shuffle` of a block template on first use in each stratum, then `pop_back` | O(n) per draw | NEW-sampling-primitives | Keep; TODO-3 |
| generate_permutations.cpp:455–650 nine `generate_permutations_*_cpp` wrappers | — | glue: seed from R, wrap result | — | glue | — |
| rand_bootstrap_mean_diff_parallel.cpp:104 `compute_rand_bootstrap_mean_diff_parallel_cpp` | bootstrap-randomization-test (BRT) null distribution of the mean difference | per b: gather y0[i_b], optional noise, optional sharp-null shift per treated unit (log/logit transcendental), masked sums; OpenMP over b | O(Bn) (+ O(B·n_T) transcendentals when δ ≠ 0) | E | Keep (O(n) per replicate is the floor). Implementation note: Incidental #9 |
| rand_bootstrap_mean_diff_parallel.cpp:170 `compute_rand_bootstrap_mean_diff_se_parallel_cpp` | BRT null of mean difference plus Welch SE | one pass: Σy, Σy² per arm; var = (Σy² − Σy·ȳ)/(n−1) | O(Bn) | NEW-streaming-moments | **Adopt** shifted one-pass variance (TODO-4) |
| rand_bootstrap_ols_parallel.cpp:257 `compute_rand_bootstrap_ols_parallel_cpp` | BRT null of the OLS treatment coefficient (rows resampled **and** w redrawn each b) | build M = [1, w, X[i_b]], normal equations MᵀM, LDLT, residual-norm singularity guard; OpenMP over b | O(B(np² + p³)) | A (per-replicate LS) | Keep: FWL hoisting does **not** apply because X changes every replicate; see options |
| ols_distr_parallel.cpp:15 `compute_ols_distr_parallel_cpp` | randomization null of the OLS treatment coefficient (X fixed, w permuted) | hoists Xᵀ1, XᵀX; per b computes Xᵀw and Xᵀy_sim (O(np) each) and a ColPivQR of the (p+2)² bordered normal matrix | O(B(2np + p³)) | A / E | **Keep-tracked**: `ols_distr_kernel_fwl.md` (release v1.2.0 TODO-9; FWL gives O(B(n_T p + p²))). Currently **dead**, waiting on `ols_randomization_distr_cpp_wiring.md` |
| ols_distr_parallel.cpp:112 `compute_ols_bootstrap_parallel_cpp` | bootstrap of the OLS treatment coefficient | per b: copy X_b, form X_bᵀX_b, bordered normal matrix, ColPivQR | O(B(np² + p³)) | J / A | Keep, but **dead**. Cost is inherent to resampling rows; only checks `idx_col[0] < 0` for NA |
| simple_mean_diff_parallel.cpp:221 `compute_simple_mean_diff_parallel_cpp` | randomization null of the mean difference (y fixed, w permuted) | branch-free masked Σ_T, Σ_C, n_T with `omp simd`; OpenMP over b | O(Bn), memory-bound on the w column | E | Keep (Σ_C = S − Σ_T saves flops but not memory traffic). The real levers are B itself (TODO-156, row E saddlepoint) and exact enumeration (TODO-6) |
| kk_compound_distr_parallel.cpp:15 `compute_matching_compound_distr_parallel_cpp` | randomization null of the KK compound (IVWC) estimator | one scatter pass: pair slots plus reservoir Σ/Σ² per arm; pair pass d̄ and s²_D; inverse-variance combination | O(Bn) | NEW-kk-summary-stats + NEW-streaming-moments | Keep. TODO-4 for the variance formula; possible correctness issue in the caller (Incidental #5) |
| kk_compound_distr_parallel.cpp:119 `compute_matching_compound_bootstrap_parallel_cpp` | bootstrap of the same estimator over a pre-gathered y_mat | same pass structure | O(Bn) | J + NEW-streaming-moments | Keep; TODO-4 |
| sample_bootstrap_distr_weighted_distances.cpp:219 `compute_bootstrapped_weighted_sqd_distances_internal` (+ :259 wrapper) | KK21: Monte Carlo sample of weighted squared distances between random distinct subject pairs among the first t, used for the matching threshold λ | B random pairs (i2 by rejection until ≠ i1), O(d) distance each | O(Bd) | NEW-pairwise-distance-quantile | Prototype: exact all-pairs enumeration when t(t−1)/2 ≤ B (TODO-7) |
| sample_mode.cpp:32,86,136,203 `sample_mode_{integer,logical,numeric,character}` (+ :256 dispatcher) | statistical mode with first-occurrence tie-break | hash-map counting (CHARSXP pointer identity for strings) | O(n) expected | NEW-mode-counting | Keep (optimal; the logical case could be a 3-slot array, immaterial) |
| *cross-cutting* (every E-family consumer of `generate_permutations_*` + the kernels above) | Monte Carlo randomization p-value at fixed r | fixed r (default 501) draws generated up front as an n×r matrix; the CI search already has batch early stopping (`mc_enable`, `mc_batch_size`, `mc_conf_level`, `inference_all_abstract_rand_ci.R:398-401`) but the plain p-value does not | O(r·stat) | E | Keep-tracked: `performance_profiling_and_upgrades.md → TODO-156` (Besag–Clifford) and audit row E (saddlepoint). Exact enumeration: TODO-6 (NEW) |

### Options & disadvantages

**P1. PRNG core** (RNG.h; NEW-prng-core)
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| uniform words | **MT19937, R-parity port (current)** | 1× | 2.5 KB state per stream; fails a few linear-complexity tests in BigCrush (irrelevant to resampling); a serial single stream feeds OpenMP kernels (Amdahl bottleneck on the cheapest kernels); seeding costs ~1–2 µs | Matsumoto & Nishimura 1998, *ACM TOMACS* |
| | MT19937 with SIMD (SFMT / dSFMT) | ~2× on word generation | **different stream from R**, so it breaks `set.seed()` parity and the cross-language reproducibility RNG.h exists for | Saito & Matsumoto 2008, SFMT [cite needed for venue] |
| | xoshiro256++ / xoshiro256** | ~2–4× per random bit (64-bit word, 32 B state) | breaks R parity and every seed-pinned test; needs jump() for parallel streams; the win is only visible where RNG time is comparable to stat time (mean-difference permutation kernels at small n). dqrng ships it for R | Blackman & Vigna 2021, *ACM TOMS* |
| | PCG32/64 | ~2–3× | same parity break; streams by increment | O'Neill 2014, HMC tech report HMC-CS-2014-0905 |
| | counter-based Philox/Threefry | ~1–2× serial, but trivially parallel (draw b from key b) | parity break; replicate b becomes independent of thread schedule, which is a determinism **gain** for OpenMP generation | Salmon et al. 2011, *SC'11* |
| | MRG32k3a (R's `L'Ecuyer-CMRG`) | slower than MT (~0.5–1×) | R-native parallel streams (`parallel::nextRNGStream`), so parity is possible **only** if the user chose that RNGkind | L'Ecuyer et al. 2002, *Operations Research* |
| verdict | Keep MT for the R stream. If TODO-149(c) measures RNG as material, the least disruptive change is a counter-based or xoshiro **child** stream seeded once from R (as dqrng does), documented as a seed-behaviour change | | | |

**P2. Bounded integers, shuffles, without-replacement sampling** (NEW-sampling-primitives)
| problem | option | speed (theoretical) | disadvantages | citation |
|---|---|---|---|---|
| integer in [0,s) | **Lemire multiply-shift + rejection (current)** | 1× | none at these sizes | Lemire 2019, *ACM TOMACS* |
| | `floor(s·unif)` (R ≤ 3.5 style) | ~same | biased for large s (R changed `sample()` in 3.6.0 because of this) | — |
| | modulo/rejection (OpenBSD `arc4random_uniform`) | slower (a division per draw) | — | — |
| random permutation | **Fisher–Yates/Durstenfeld via `std::shuffle` (current)** | 1× | output is **implementation-defined**: libstdc++ and libc++ produce different permutations from the same URBG (the standard leaves the shuffle and distribution algorithms unspecified; libstdc++ also packs two swap indices into one word when the range allows). Seeds therefore don't reproduce across Linux vs macOS/clang, contradicting the "identical draws in R and Python" note at generate_permutations.cpp:124-133 | Durstenfeld 1964, *CACM* Alg. 235; Knuth TAOCP vol. 2 §3.4.2 |
| | explicit Fisher–Yates with `bounded_rand` | ~1× (≤2× more words than libstdc++'s paired draws, still O(n)) | changes the stream on at least one platform, so seed-pinned tests need refreshing | same |
| | partial Fisher–Yates, k = min(n_T, n−n_T) swaps | ≤2× fewer words | same stream change; marginal win | Knuth TAOCP vol. 2 |
| | random-key sort | O(n log n), slower | — | — |
| k of n w/o replacement | **rejection + `unordered_set` (current)** | 1× | expected draws grow like n ln n as k → n; hash inserts ~10–30× the cost of an array swap; extra memory allocation per stratum per replicate | — |
| | partial Fisher–Yates on a reusable scratch copy of ids | ~2–10× fewer ops at k ≥ n/4 | O(n) scratch (trivial); different realized draws (same distribution) | Knuth TAOCP vol. 2 |
| | Floyd's algorithm | exactly k draws, still a hash set | best when k ≪ n; output order not uniformly random (irrelevant if order is unused) | Bentley & Floyd 1987, *CACM* "A sample of brilliance" |
| | selection sampling (Algorithm S) / Vitter Algorithm D | O(n) / O(k) sequential, output sorted | sorted output is a plus when `preserve_order`; more code | Fan, Muller & Rezucha 1962, *JASA*; Vitter 1987, *ACM TOMS* |
| weighted repeated draws | alias (Walker 1977, *ACM TOMS*; Vose 1991, *IEEE TSE*); Efraimidis–Spirakis 2006, *IPL* | — | **N/A**: none of the assigned files does weighted sampling (all draws are uniform or Bernoulli(prob_T)) | — |

**P3. Bootstrap index generation (audit row J)**
| problem | option | effect at fixed B (theoretical) | disadvantages | citation |
|---|---|---|---|---|
| bootstrap replicate indices | **i.i.d. per replicate (current; one RRng seeded per call)** | 1× | first-order Monte Carlo imbalance noise | Efron 1979, *Ann. Statist.* |
| | balanced bootstrap (concatenate B copies of 1..n, one permutation, cut into B rows) | ~1.1–1.5× fewer effective replicates for smooth statistics (bias/mean estimates gain most; quantile-based CIs gain little) | **needs a B-batch API**: today draws are per replicate (`draw_bootstrap_indices()` → `sample_int_replace_cpp(n, n)`), so the balanced array has to be built once and served row by row through private state, which interacts with the CI-search's per-call draws and worker duplication. O(Bn) int memory. Replicates are no longer independent, so code that assumes i.i.d. replicates (e.g. MC-error formulas) is slightly off. Cluster/pair-preserving and stratified variants each need their own balanced form | Davison, Hinkley & Schechtman 1986, *Biometrika*; Gleason 1988, *Am. Stat.* |
| | antithetic resampling | small, statistic-dependent | needs a monotone pairing of observations, so it is per-statistic work | Hall 1989, *Biometrika* |
| | importance resampling for tail quantiles | large for extreme percentiles | needs tilting weights per statistic; reweighting complexity | Johns 1988, *JASA*; Davison & Hinkley 1997 §9.4 |
| | post-hoc linear-approximation centering | cheap, bias/variance only | no help for percentile CIs | Efron 1990, *JASA* |
| verdict | Prototype through the A/B harness (audit TODO-4), re-scoped to the per-replicate production API (TODO-1) | | | |

**P4. Monte Carlo randomization p-values / exactness (row E, TODO-156, small-n enumeration)**
| problem | option | speed (theoretical) | disadvantages | citation |
|---|---|---|---|---|
| p-value of T under the design's randomization distribution | **fixed-r Monte Carlo, (b+1)/(r+1) (current)** | 1× | MC error ~ √(p(1−p)/r); a whole n×r w-matrix is generated up front even when the answer is clear early | Dwass 1957, *Ann. Math. Stat.*; Phipson & Smyth 2010, *SAGMB* |
| | Besag–Clifford sequential (stop after h exceedances) | 5–10× fewer draws when the result is clearly significant or clearly null (estimate in TODO-156) | p-values are discretized; needs streaming generation (generate draws in batches instead of one n×r matrix); the stopping rule must be documented as opt-in | Besag & Clifford 1991, *Biometrika* |
| | Gandy's sequential test with bounded resampling risk | similar to Besag–Clifford, with a uniform error bound | decision-oriented (tied to α), so it doesn't give a p-value to report | Gandy 2009, *JASA* |
| | saddlepoint for linear statistics | O(1) in r | approximate, so the exactness guarantee is lost; only for linear-in-w statistics (mean difference, FWL-OLS, pair sign-flip); sequential designs have no closed-form cumulant generating function | Robinson 1982, *Ann. Statist.*; Booth & Butler 1990, *Biometrika* |
| | **exact full enumeration** of the assignment space when it is small (complete randomization: C(n, n_T) ≤ ~2·10⁵, i.e. n ≤ ~20; matched pairs: 2^m, m ≤ ~18; Bernoulli/cluster: 2^n weighted) | exact and deterministic; cheaper than r = 501 only when the support is ≤ r, otherwise slower but MC error goes away | size cap; sequential designs (Efron, Atkinson, Pocock–Simon, KK) need path-probability-weighted enumeration of up to 2^n paths; different design classes need different enumerators; p-value moves from MC to exact, so any test pinned to MC values shifts | Fisher 1935, *The Design of Experiments* |
| | exact distribution via DP/FFT for linear statistics with lattice-valued scores | polynomial | needs integer/lattice scores (ranks), so it doesn't apply to raw continuous y | Pagano & Tritchler 1983, *JASA* |

**P5. OLS coefficient under permutation / BRT**
| problem | option | per-replicate cost | disadvantages | citation |
|---|---|---|---|---|
| fixed X, permuted w (`ols_distr_parallel.cpp:15`) | **bordered normal equations + ColPivQR (current, dead)** | O(2np + p³) + 6 allocations | — | — |
| | FWL: β_b = w_bᵀ(My)/(n_T − ‖L⁻¹Z_cᵀw_b‖²) + δ | O(n_T p + p²) | rank-guard NA pattern must match; differs from current by roundoff, not bit-identical. Already planned | Frisch & Waugh 1933, *Econometrica*; Lovell 1963, *JASA*; `ols_distr_kernel_fwl.md` |
| resampled rows + fresh w (`rand_bootstrap_ols_parallel.cpp:257`) | **normal equations + LDLT + residual guard (current)** | O(np² + p³) | squares the condition number (fine for standardized p in the tens) | — |
| | thin QR of M | ~2× flops | more stable; slower | Golub & Van Loan |
| | FWL hoisting | — | **not applicable**: X[i_b] changes every replicate, so nothing w-independent survives | — |
| | count-weighted Gram Σ c_i x_i x_iᵀ | same O(np²) | no gain | — |

**P6. Atkinson null draws** (generate_permutations.cpp:240/:80; NEW-seq-design-null-draws)
| option | cost | disadvantages | citation |
|---|---|---|---|
| **rebuild [w,1,X_t]ᵀ[w,1,X_t], FullPivLU, full inverse at every t of every replicate (current)** | O(B(n²p²/2 + np³)), e.g. n = 200, p = 10, B = 501 ≈ 1.1·10⁹ flops | — | Atkinson 1982, *Biometrika* |
| block inverse with the w-independent C_t = Z_tᵀZ_t (Z_t = [1, X_prev(indep cols)]) precomputed **once** per t, plus a running v = Σ_{treated} [1, x_i] (O(p) update per arrival). Only u = C_t⁻¹v (O(p²)) is needed: M(0,0)/A = −1/(uᵀx_t), the Schur complement cancels, and invertibility ⇔ C_t SPD and s = n_T − vᵀu > 0 | O(n²p²/2 + np³) **once** + O(B·n·p²): ≈ 2·10⁷ flops in the example, **~50× theoretical** (grows with n) | singular branches (`!lu.isInvertible()` → 0.5, `A == 0` → 0.5) must be reproduced with explicit tolerances, and near-singular cases could flip; O(n p²) memory for the C_t⁻¹ factors; probabilities match to roundoff, so a coin flip differs only when a uniform falls inside a ~1e-12 window (same RNG consumption, streams stay aligned) | Sherman–Morrison / Schur complement, Golub & Van Loan, *Matrix Computations* |
| also make C_t incremental (rank-1 Cholesky update per t) | precompute drops to O(np²) | more code, and column-set changes (`indep_cols` varies with t) force downdates or refactorization | Gill, Golub, Murray & Saunders 1974, *Math. Comp.* |

**P7. Streaming variance** (NEW-streaming-moments: rand_bootstrap_mean_diff_parallel.cpp:227-228, kk_compound_distr_parallel.cpp:81,92-93,185,195-196, kk_bootstrap_reservoir_stats.cpp:89)
| option | cost | disadvantages | citation |
|---|---|---|---|
| **textbook one-pass Σx² − n x̄² (current)** | 1 pass | catastrophic cancellation: relative error ≈ ε·(x̄/s)², so precision is gone when |x̄|/s ≳ 10⁶ (raw timestamps, incomes, unscaled lab values). Can even return var < 0 (the SE kernel then reports se = 0) | Chan, Golub & LeVeque 1983, *Am. Stat.* |
| shifted one-pass (subtract a per-call constant K, e.g. mean(y0), computed once before the replicate loop) | same cost, one subtraction per element | not bit-identical to current; identical to tolerance on well-scaled data | Chan, Golub & LeVeque 1983 |
| Welford online update | ~2× flops (a division per element) | slower in the SIMD-friendly loops | Welford 1962, *Technometrics* |
| two-pass | 2× memory reads | — | — |

**P8. KK21 distance threshold** (sample_bootstrap_distr_weighted_distances.cpp:219)
| option | cost | disadvantages | citation |
|---|---|---|---|
| **B random distinct pairs, with replacement (current)** | O(Bd) | MC noise in λ; when t(t−1)/2 ≤ B it samples duplicates of a small finite population | — |
| exact enumeration of all t(t−1)/2 pairs when that is ≤ B (t ≤ ~32 for B = 500) | O(t²d) ≤ O(Bd) | λ becomes deterministic, so KK21 design draws change for a given seed; RNG consumption changes downstream (seed-pinned tests) | — |
| sampling pairs without replacement when the pair count is close to B | ~same | marginal | — |

### New TODO candidates
1. **Re-scope balanced bootstrap (audit row J / audit TODO-4) to the production API.** `bootstrap_indices.cpp` is test-only. Production bootstrap draws are per replicate (`sample_int_replace_cpp(n, n)` at `design_abstract.R:979,995`, `design_matching_abstract.R:111`, `design_component_registry.R:462`; `resample_group_rows_cpp`; `draw_matching_bootstrap_sample_cpp`; `exchangeable_resampling_draws_cpp`). A balanced version needs a B-batch generator (one permuted array of B copies of 1..n, served row by row) wired into `draw_bootstrap_indices()`. Expected win: ~1.1–1.5× effective-B (theoretical, smooth statistics). Main risk: plumbing and worker duplication; replicates stop being i.i.d. **Needs the A/B harness.**
2. **Partial Fisher–Yates for subsampling without replacement** (exchangeable_resampling_draws.cpp:223-230). Use a reusable scratch copy of `ids` and k swaps instead of rejection plus a hash set. Expected win: 2–10× on that function (theoretical; k ≥ n/4), negligible end to end unless m-out-of-n subsampling dominates. Risk: the realized draws change (same distribution), so seed-pinned tests need regenerating. **No statistical A/B needed**; it is a stream-changing drop-in.
3. **Replace `std::shuffle` with an explicit Fisher–Yates on `bounded_rand`** (generate_permutations.cpp:191,211,427; fast_shuffle.cpp:12). This is a portability and reproducibility fix, not a speedup: `std::shuffle` output differs between libstdc++ and libc++, so IBCRD/blocking/SPBR null draws are not seed-reproducible across Linux vs macOS, contrary to the file's header claim. Win: cross-platform and cross-language determinism; speed ~1×. Risk: one-time stream change on whichever platform's library is not matched. No A/B; deterministic drop-in plus refreshed fixtures.
4. **Shifted one-pass variance** in `compute_rand_bootstrap_mean_diff_se_parallel_cpp` (:227-228) and both `kk_compound_distr_parallel.cpp` kernels (:81,92-93,185,195-196). Subtract a per-call constant (mean of y0 / y) before accumulating. Win: accuracy (no cancellation at large |mean|/sd) at zero cost. Risk: last-bit differences only. **Adopt**: deterministic, identical to tolerance.
5. **Atkinson null-draw Schur/block-inverse rewrite** (generate_permutations.cpp:80-119, :279-293). Precompute C_t⁻¹ (or its Cholesky) per t once; per replicate keep v = Σ_treated [1, x] and compute u = C_t⁻¹v. Expected win: O(B n² p²) → O(n² p² + B n p²), ~50× at n = 200, p = 10, B = 501, more at larger n (theoretical). Risk: reproducing the two 0.5-fallback singular branches with explicit tolerances. **Adopt**: deterministic, probabilities identical to roundoff, same RNG consumption; gate on the existing Atkinson randomization tests plus a near-singular fixture. Check whether `DesignSeqOneByOneAtkinson$assign_wt()` (R side) has the same O(t p²)-per-arrival structure.
6. **Exact enumeration of the randomization distribution for small support** (NEW). Applies to complete randomization C(n, n_T) ≤ ~2·10⁵, matched pairs 2^m, cluster 2^G, and as an alternative to the MC path in `generate_permutations_*` when |support| ≤ r. Win: exact deterministic p-values and no MC error, at equal or lower cost when |support| ≤ r (theoretical). Risk: per-design enumerators (sequential designs need probability-weighted path enumeration); changes reported p-values from MC to exact. **Needs a design/policy decision, then a correctness check against the large-r MC.**
7. **Exact pairwise-distance enumeration for KK21's λ when t(t−1)/2 ≤ B** (sample_bootstrap_distr_weighted_distances.cpp:232-248). Win: removes MC noise in early-t thresholds at ≤ current cost. Risk: changes KK21 assignments for a given seed. **A/B on design imbalance metrics** (the KK21 speedup study pattern).

(Already tracked elsewhere, not re-proposed: FWL OLS kernel → `ols_distr_kernel_fwl.md`; Besag–Clifford → TODO-156; RNG throughput and parallel streams → TODO-149; saddlepoint → audit row E / audit TODO-5.)

### Incidental findings (optional)
1. **Dead kernels** (no R caller; tests at most): `base_bootstrap_loop_cpp`, `randomization_loop_cpp`, `matching_bootstrap_loop_cpp`, `match_stats_from_indices_cpp`, `compute_matching_reservoir_stats_cpp`, `fill_i_b_with_matches_loop_cpp`, `shuffle_cpp`, `compute_ols_distr_parallel_cpp`, `compute_ols_bootstrap_parallel_cpp`; test-only: `bootstrap_indices_cpp`, `bootstrap_m_indices_cpp`. Candidates for removal or wiring; they inflate the 100+ .cpp build.
2. RNG.h:292 / every `*_cpp` wrapper: each call derives a 32-bit child seed from one `R::unif_rand()`. Because bootstrap draws call `sample_int_replace_cpp` once per replicate, two of B replicates share a seed, and so are identical resamples, with probability ≈ B²/2³³ (~1% at B = 10⁴, ~70% at B = 10⁵). Statistically negligible, but non-zero. A B-batch API (TODO-1) removes it.
3. generate_permutations.cpp:124-133 and every "identical draws in R and in any future binding" note: false for the `std::shuffle`-based designs (TODO-3).
4. fast_shuffle.cpp:12-14: `NumericVector(w)` doesn't copy a REALSXP, so `std::shuffle` permutes the **caller's R vector in place** (dead code; dangerous if revived). The same in-place mutation by design happens in KK_bootstrap_helper_fillin.cpp:178.
5. **Possible correctness issue (legacy class)**: `inference_all_KK_mean_diff_IVWC.R:160-163` replaces a NULL `permutations$m_mat` with all-zero match ids. `m_mat` is always NULL (`inference_all_abstract_rand.R:758`; `generate_permutations_matching_cpp` returns NULL), so `compute_matching_compound_distr_parallel_cpp` sees no pairs and returns the plain reservoir mean difference r̄. That is a different statistic from the observed KK compound estimate. The slow path (`inference_all_abstract_rand.R:533`) treats NULL as "use the design's fixed m". The IVWC class is legacy/unpublished, so low priority, but worth a test.
6. `inference_all_KK_mean_diff_IVWC.R:123-146`: the R bootstrap loop does `which(m_vec == id)` per sampled pair and grows vectors with `c()`, which is O(B·m·n). The already-written `bootstrap_m_indices_cpp` (O(n + B(n_R + m))) is the replacement and is currently test-only.
7. bootstrap_match_indices.cpp:350: `match_stats_from_indices_cpp` copies the original match ids for resampled rows, so a pair drawn twice yields 4 rows with one id. `compute_zhang_match_data_cpp` may then mis-pair them (dead path; compare `draw_matching_bootstrap_sample_cpp`, which renumbers).
8. kk_bootstrap_reservoir_stats.cpp:121,124: `NumericVector::push_back` reallocates on every call, so the split is O(n_R²) (dead).
9. rand_bootstrap_mean_diff_parallel.cpp:149,208: with no noise, the sharp-null shift (exp/log/logit per treated unit) is recomputed in every replicate. Precomputing `y0_shift[i]` once per call gives bit-identical results and cuts B·n_T transcendentals to n.
10. kk_compound_distr_parallel.cpp:58-59,74: if a match id has no treated or no control member, or ids are non-contiguous, the slot stays −1 and `y[-1]` is read (UB). The `diffs` vector is written but never read.
11. sample_bootstrap_distr_weighted_distances.cpp:233: with t = 0, `bounded_rand(rng, 0)` returns 0, which then indexes an empty matrix. The caller presumably guarantees t ≥ 2; a guard is cheap.
12. `inference_all_abstract_rand.R:754` stores `w_mat` as double and kernels convert it back to integer (`inference_all_KK_mean_diff_IVWC.R:158`). That is an 8nB-byte copy per call; implementation-level only.

---

## 8. C++ — designs, matching, distances, rerandomization, shared helpers, infrastructure


All paths relative to `R/EDI/src/`. Line numbers are function start lines as of HEAD `36ba15e9`. Read-only sweep; nothing compiled.

Answers to the "pay special attention" questions, up front:
- **Mahalanobis distances.** There are three implementations and they differ. (a) KK14 nearest match (`compute_mahal_distances.cpp:10`): R inverts the covariance explicitly once per arrival (`solve()` at `design_seq_one_by_one_KK14.R:143`), then C++ evaluates all `|R|` quadratic forms in one batched `(D·S⁻¹)∘D` call, costing O(p³ + |R|p²). That is the same order as Cholesky whitening; the only cost of the explicit inverse is a little numerical stability. (b) Greedy and rerandomization (`design_fixed_greedy.cpp:49`, `rerandomization_helpers.cpp:179`) whiten once via `LLT` + triangular solve, `M = L⁻¹X'/n`, which is already the best form. (c) **Optimal blocks** (`optimal_blocks_distance.cpp:196`) inverts by hand-rolled Gauss–Jordan and then evaluates a **per-pair** `d'S⁻¹d`, costing O(n²p²). This is the one that should whiten instead, bringing it to O(np² + n²p).
- **Atkinson D_A.** Every arrival recomputes everything (`atkinson_assign.cpp:24`): X'X is rebuilt from the full t×(p+2) design in O(tp²), then `FullPivLU`, then a full `.inverse()` in O(p³). Only row 0 of the inverse is used. There is no Sherman–Morrison update.
- **Pocock–Simon.** Already incremental. Counts are maintained in place, and the per-subject score touches only that subject's J levels for 2 arms, so O(J) per arrival (`pocock_simon_assign.cpp:28,93`).
- **Greedy pairwise-swap engine.**
  - D-/A-optimal: O(1) delta per pair plus a sorted-scan pruning bound (`optimal_design_search.cpp:41,64`).
  - `DesignFixedGreedy` (Mahalanobis and L1 modes): **O(p)** per pair, so O(n_T·n_C·p) per round (`design_fixed_greedy.cpp:228`).
  - Simulated annealing: O(1) per move for the quadratic and ratio objectives, O(p) for L1, plus O(n) on accept.
  - No objective is ever recomputed from scratch inside a search, except the annealing drift-check at chain end.
- **KK21 weights.** A forward stepwise selection that adds the covariate with the largest |t| (or score z) given the already-selected set plus `w`.
  - Continuous: FWL with incremental Gram–Schmidt, O(np²) total.
  - Logistic: one warm-started reduced fit per step plus score statistics for all candidates.
  - Beta, negbin and ordinal: **a full refit for every (step, candidate) pair**, so O(p²) fits.
- **Optimal blocks distance.** A dense n×n matrix for the ompr MILP, built by brute force O(n²p) for Euclidean and L1, and O(n²p²) for Mahalanobis (see above).
- **Binary match search.** Not a search. It draws independent fair coin flips per pair for `r` columns, O(n·r), with per-column RNG streams, so it is invariant to thread count.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| compute_mahal_distances.cpp:10 `compute_proportional_mahal_distances_cpp` | KK14: Mahalanobis distance from the arrival to every reservoir subject | Builds the difference matrix D (|R|×p) column-major, then `rowsum((D·S⁻¹)∘D)` in one GEMM. S⁻¹ comes from R `solve()` per arrival | O(\|R\|p²) per arrival + O(p³) inverse in R; O(n\|R\|p²) summed | H | Keep-tracked (`kk14_incremental_covariance.md` TODO-3 swaps `solve()` for a Cholesky solve; its "out of scope" section correctly notes that whitening the reservoir costs the same) |
| compute_weighted_distances.cpp:5 `compute_weighted_sqd_distances_cpp` | KK21: weighted squared Euclidean distance to the reservoir | brute-force column-major SIMD scan | O(\|R\|d) per arrival | H | Keep |
| atkinson_assign.cpp:24 `atkinson_assign_weight_internal` (+:76 wrapper) | Atkinson (1982) D_A biased-coin probability | Rebuilds `[w,1,X]'[w,1,X]` from scratch, `FullPivLU` invertibility check, full `lu.inverse()`, uses only `M.row(0)` | O(tp² + p³) per arrival; O(n²p² + np³) summed. Dominated by the O(tp²) rebuild plus `compute_all_subject_data` QR, not by the inverse | H | Keep (low-priority micro in TODO 6; Sherman–Morrison rejected, see options) |
| pocock_simon_assign.cpp:28 `pocock_simon_assign_internal`; :299 `…_assign_and_update_cpp` | Pocock–Simon marginal-imbalance minimization, biased coin | For each arm k, G_k = Σ_j w_j·Var(counts with the subject added to k). Counts are R-side state, incremented in place | O(J·K) per arrival (K=2) | H | Keep (optimal: touches only the subject's levels) |
| pocock_simon_assign.cpp:93 `pocock_simon_redraw_w_internal` (:355 wrapper) | Replay a full PS sequence | Same rule, flat int counts array, continues R's live MT stream | O(nJ) | H | Keep |
| binary_match_search.cpp:33 `draw_binary_match_assignments_cpp` | Draw r pair-randomized allocations | Per pair, a coin from the MSB of an MT word; per-column RRng seeded by SplitMix64(master + j); OMP static | O(n·r) | NEW-random-variate-generation | Keep |
| random_block_size_speedups.cpp:12 `random_block_size_redraw_w_cpp` | Stratified permuted blocks with random block size | `std::map<string,…>` per stratum; on an empty block, draws a size, fills it and `std::shuffle`s | O(n log S·\|key\| + n) | NEW-random-variate-generation | Keep (see incidental 8 on `std::` distribution portability) |
| rerandomization_helpers.cpp:57 / :71 `complete_randomization_{forced_balanced,imbalanced}_cpp` | r uniform complete-randomization draws | Fisher–Yates per row | O(n·r) | NEW-random-variate-generation | Keep |
| rerandomization_helpers.cpp:84 `compute_objective_vals_cpp` | Score r allocations (L1-std or Mahalanobis) | Hand triple loop for Σ_T x (branch per (i,row)), then an unwhitened p² quadratic form per row | O(r·n·p + r·p²) | I | Keep-tracked (`rerandomization_objective_vals_gemm.md`: GEMM + whitened form) |
| rerandomization_helpers.cpp:179 `rerandomization_search_cpp` | Draw r allocations with objective ≤ cutoff | i.i.d. rejection sampling; each draw is a full Fisher–Yates plus `d = M(2w−1)` (M = L⁻¹X'/n via LLT, or diag-sd); OMP work-stealing | O((n + np)/p_acc) per accepted draw | I | Keep-tracked (audit row I / `quantum_upgrade.md §II.1`) |
| optimal_blocks_distance.cpp:12 `invert_matrix_cpp`; :75 `compute_mahal_inverse_covariance` | Sample covariance + 1e-8 ridge + inverse | Naive O(np²) covariance loops, Gauss–Jordan with partial pivoting | O(np² + p³) | NEW-small-dense-linalg | Adopt (subsumed by TODO 1: replace with LLT) |
| optimal_blocks_distance.cpp:196 `distance_matrix_mahal_cpp` | Full n×n Mahalanobis matrix for the ompr MILP | **Per-pair** S⁻¹·diff matvec | **O(n²p²)** | NEW-dense-distance-matrix | Adopt (TODO 1: whiten once, then Euclidean, O(np² + n²p)) |
| optimal_blocks_distance.cpp:152 / :177 `distance_matrix_{euclidean_sq,sum_abs_diff}_cpp` | Full n×n Euclidean² / L1 | Brute-force double loop; inner loop over k strides a column-major `X(i,k)` | O(n²p) | NEW-dense-distance-matrix | Keep (order optimal; stride is implementation-level, incidental 9) |
| optimal_blocks_distance.cpp:121 `distance_matrix_custom_cpp_impl` (:172, :228 dispatch) | User R distance per pair | one R callback per pair | O(n²) R calls | NEW-dense-distance-matrix | Keep (inherent to a black-box R fn) |
| pair_dist_helpers.cpp:9 `compute_pair_averages_cpp` | Per-pair covariate means | scatter-add | O(np) | glue-ish | Keep |
| pair_dist_helpers.cpp:56 `compute_pair_distance_matrix_cpp` | m×m weighted Euclidean² between pair means (Bai inference) | Row-major copy + SIMD brute force (upper triangle) | O(m²p) | NEW-dense-distance-matrix | Keep (output is m², brute force is order-optimal; GEMM form only a constant factor, see options) |
| pair_dist_helpers.cpp:93 `compute_lambda_squ_cpp` | Mean product over matched halves | single pass | O(m) | glue | Keep |
| greedy_pairwise_swap_engine.h:86 `exhaustive_best_improvement_search` | Best-improvement 1-swap local search to a strict local optimum | Full n_T×n_C scan per round, apply best swap | O(n_T n_C · cost(delta)) per round, ~O(n) rounds | F | Keep (the search rule *defines* the design's allocation distribution; see options) |
| greedy_pairwise_swap_engine.h:149 `exhaustive_best_improvement_search_pruned` | Same, with a provable lower-bound prune | Per round, sorts T by outer bound and C by inner bound, then breaks early | O(n log n + pruned scan) per round | F | Keep |
| design_fixed_greedy.cpp:49 `greedy_design_search_cpp` (exhaustive, non-pair, :228 `GreedyExhaustiveObjective`) | Greedy balance design, Mahalanobis or L1 | Δ = 2(M_j − M_i); f_new = f + 2d·Δ + ‖Δ‖² (O(p)); L1 recomputes ‖d+Δ‖₁ (O(p)) | **O(n_T n_C p) per round** | F | Keep-tracked (`small_kernel_hoists_batch.md` Item A: G = M'M gives O(1)/pair). New extension in TODO 2 (route through the D-opt *pruned* engine) |
| design_fixed_greedy.cpp:191 / :259 (pair mode exhaustive; stochastic modes) | Pair-constrained swaps; random-pair hill climbing | O(p) delta per candidate | O(n_pairs·p) per round; O(n_iter·p) | F | Keep |
| optimal_design_search.cpp:41/:132 `DOptimalPruneObjective`/`d_optimal_search_cpp` | Minimize w'Pw over balanced w | Pruned best-improvement; delta = A_i + B_j − 2P_ij in O(1); Pw updated O(n) on swap | O(n²) worst per round, pruned | F | Keep |
| optimal_design_search.cpp:64/:175 `AOptimalPruneObjective`/`a_optimal_search_cpp` | Minimize (w'Hw+1)/(n_T − w'Pw) | Same, O(1) ratio delta, fixed-per-round prune threshold | O(n²) worst per round | F | Keep |
| optimal_design_search.cpp:114 `random_balanced_init` | Random start | `std::shuffle` with RRng | O(n) | NEW-random-variate-generation | Keep |
| design_optimal_annealing_search.cpp:132 `annealing_design_search_cpp` (+:73 `state_objective`, :85 `exact_objective`, :100 `init_state`) | One near-global-optimal allocation (DesignFixedOptimal, n>20) | Single-exchange Metropolis SA, geometric cooling, n_chains independent chains (per-chain seeds), best visited state, exact recompute at end | O(1) per move (quadratic/ratio), O(p) (l1), user cost (custom); O(n) on accept; O(n_chains·max_iter) | F | Keep-tracked (`quantum_upgrade.md` TODO-5: SA vs PT/tabu) |
| kk21_weights.cpp:22 `kk21_continuous_weights_cpp` | Per-covariate univariate OLS \|t\| | Closed-form simple regression from **raw one-pass sums** (sumx2 − n·x̄², expanded SSE) | O(np) | NEW-forward-stepwise-selection | Keep (numerics in incidental 4) |
| kk21_weights.cpp:83 `kk21_logistic_weights_cpp` | Per-covariate univariate logistic Wald \|z\| | 2×2 closed-form IRLS, cold start 0 | O(p·iter·n) | A | Keep |
| kk21_weights.cpp:170 `kk21_stepwise_continuous_weights_cpp` | Forward stepwise OLS t, adjusting for [1, w, selected] | FWL: keeps residualized candidates E_x and e_y; per step O(np) scoring + one MGS projection of the remaining columns | O(np²) total | NEW-forward-stepwise-selection | Keep (equivalent to QR-update forward selection, which is the textbook algorithm) |
| kk21_weights.cpp:279/:328 `logistic_reduced_fit_for_score_test` / `kk21_stepwise_logistic_weights_cpp` | Forward stepwise logistic | One warm-started IRLS reduced fit per step; Rao score z_j = U_j/√(I_jj·S) for all candidates via LDLT solves | O(p) fits × O(iter·n·m²) + O(p²·n·m) scoring | NEW-forward-stepwise-selection | Keep (already the fast design) |
| kk21_weights.cpp:414 `univariate_beta_tstat`; :931 `multivariate_beta_tstat` | Beta-regression \|t\| for one coefficient | Mean: quasi-binomial logit IRLS (not beta MLE); φ: **19-point grid** over log φ ∈ [−2, 7] step 0.5 on the beta loglik at fixed μ; SE from (1+φ)μ(1−μ) weights | O(iter·n·m² + 19·n·lgamma) | NEW-1d-nuisance-profile | Prototype (TODO 4: Brent/Newton on log φ) |
| kk21_weights.cpp:500 `univariate_negbin_tstat`; :1014 `multivariate_negbin_tstat` | NB2 regression \|t\| | Alternating: IRLS for β given θ (≤25 it) + one Newton step on θ (method-of-moments start), clamped [0.01, 1000] | O(outer·inner·n·m²) | A | Keep (glm.nb-style alternation is standard) |
| kk21_weights.cpp:744 `univariate_weibull_tstat` (used by :852 `kk21_survival_weights_cpp`) | Univariate Weibull AFT \|t\| | Alternating WLS on a pseudo-response (weights e^z) + approximate scale Newton (info = d/σ²) | O(iter·n) | A | **Investigate**: the fixed point does not appear to solve the Weibull score equations (incidental 1) |
| kk21_weights.cpp:597/:670/:852 `kk21_{beta,negbin,survival}_weights_cpp` | Non-stepwise per-covariate weights + OLS-on-transform fallback | p independent univariate fits | O(p · fit) | A | Keep |
| kk21_weights.cpp:1108 / :1173 `kk21_stepwise_{beta,negbin}_weights_cpp` | Forward stepwise beta / NB | **Full refit of [1, x_j, selected, w] for every remaining j at every step** | O(p²/2) fits, each O(iter·n·p²), so ≈O(iter·n·p⁴) | NEW-forward-stepwise-selection | Prototype (TODO 3: score-test scheme as in logistic) |
| kk21_weights.cpp:1233/:1246/:1276 `multivariate_ordinal_tstat`, `kk21_{,stepwise_}ordinal_weights_cpp` | Univariate / stepwise ordinal \|t\| | **R callback** `Function("fast_ordinal_regression_with_var_cpp")` per fit; stepwise = O(p²/2) callbacks | O(p²) R-level fits | NEW-forward-stepwise-selection | Prototype (TODO 3), plus the known unprotected-`wrap` crash (MEMORY: KK21 speedup note) |
| kk_cluster_ids.cpp:6/:49 `compute_matching_grouping_cpp`, `compute_cluster_ids_cpp` | Map match ids to cluster ids | single pass | O(n) | glue | Keep |
| kk_lin_match_data.cpp:6/:109 `compute_matching_lin_match_data_cpp`, `compute_matching_lin_wy_stats_cpp` | Pair diffs/means + reservoir split | single scatter pass | O(np) | glue | Keep |
| match_data_compute_speedup.cpp:12 `match_diffs_cpp` | Forwarder to `compute_zhang_match_data_cpp` (other file) | glue (note: `wrap(X)` copies X) | O(np) | glue | Keep |
| compute_all_subject_data.cpp:106 `process_subset` (+:68 `find_independent_cols`, :88 `matrix_rank`, :46 `scale_columns`, :7 `which_cols_vary`) | Per-arrival varying/independent column detection + z-scaling for 4 row subsets | Per subset: varying-column scan, z-score, **ColPivHouseholderQR** for rank and pivots, **then a second QR** on the selected columns just for `rank` | 4×(O(tp²) + O(t·r²)) per arrival; O(n²p²) summed | NEW-rank-revealing-factorization | Keep-tracked (`kk14_incremental_covariance.md` TODO-1/2: QR only when the varying set changes) |
| compute_all_subject_data.cpp:231 `compute_all_subject_data_cpp` | Driver (4 subsets) | as above | as above | glue | Keep-tracked (same) |
| imputation_helpers.cpp:7 / :74 / :144 `columns_have_missingness_cpp`, `create_missingness_indicators_cpp`, `count_unique_values_cpp` | NA scans; distinct counts | Linear scans; `unordered_set` distinct count | O(n·cols) expected | glue | Keep |
| simulation_dgp.cpp:13 `apply_treatment_and_noise_cpp` | Simulate y \| linear predictor, w for 6 response types | R's own samplers (rnorm/runif vectorized; rbeta/rpois/rweibull per obs); ordinal via rounding | O(n) | NEW-random-variate-generation | Keep (incidental 2: Weibull shape/scale and censoring) |
| _helper_functions_core.h:222 `compute_diagonal_inverse_entry` | One diagonal entry of M⁻¹ | LDLT solve against e_j; ColPivQR fallback | O(p³/3 + p²) | NEW-small-dense-linalg | Keep |
| _helper_functions_core.h:308 / :359 `weighted_crossprod`; :387 / :416 `weighted_crossprod_rhs` | X'WX, X'Wz | Col-major: p(p+1)/2 dot products (unblocked); row-major: rank-1 accumulate upper triangle | O(np²/2) | NEW-small-dense-linalg | Keep-tracked (`performance_profiling_and_upgrades.md` TODO-155; √w·X + DSYRK option below) |
| _helper_functions_core.h:441 `symmetric_crossprod` | X'X | BLAS DSYRK | O(np²/2), BLAS-3 | NEW-small-dense-linalg | Keep |
| _helper_functions_core.h:559 `score_weighted_crossprod_colwise_assign` | Fused score + X'WX | colwise dot loops | O(np²/2) | NEW-small-dense-linalg | Keep-tracked (TODO-155) |
| _helper_functions_core.h:650 `invert_free_information` | Inverse of the information matrix with a singularity flag | `FullPivLU` for the decision, **then** `.inverse()` (a second factorization) | 2×O(p³) | NEW-small-dense-linalg | Keep-tracked (TODO-155; kept on purpose for bit-compat per its comment) |
| _helper_functions_core.h:672 `symmetric_pseudo_inverse`; :1242 `covariance_from_information` | Covariance from information (LDLT solve with I; eigen-pinv fallback) | LDLT, SelfAdjointEigenSolver | O(p³) | NEW-small-dense-linalg | Keep |
| _helper_functions_core.h:690–811 `plogis_*`, `log1pexp_safe`, `fast_log1p_arr`, `log1pexp_array_safe`, `fast_log1pexp`, `log1pexp_array_fast` | Logistic CDF, softplus | Branch-split stable forms; `fast_log1p_arr` uses Goldberg's log(u)·z/(u−1) correction; `fast_log1pexp` uses a truncated 10-term atanh series (claimed abs error <5e-12) | O(1)/elem | NEW-special-functions | Keep (see options: the series is approximate, not exact) |
| _helper_functions_core.h:813 `try_safe_ols_solve` (+:851–881 smart cold-start wrappers) | OLS start values | ColPivHouseholderQR | O(np²) | A | Keep |
| _helper_functions_core.h:902 `weibull_aft_start` | Weibull AFT start | OLS on log y of uncensored rows + 0.5722 shift; σ² = var/1.6449 | O(np²) | A | Keep (incidental 3: the constant) |
| _helper_functions_core.h:1013 `ordinal_smart_cold_start` | Cumulative-link thresholds start | Marginal cumulative proportions → link quantiles, β = 0 | O(nK) | A | Keep |
| _helper_functions_core.h:1066 / :1079 `numerical_gradient`, `numerical_hessian` | FD derivatives | Central differences (value) / central differences of the analytic gradient, symmetrized | 2p evals / 2p gradient evals | NEW-small-dense-linalg | Keep |
| _helper_functions_core.h:1312 `optimize_likelihood_lbfgs` | Generic unconstrained MLE | LBFGSpp, strong-Wolfe backtracking | superlinear | A | Keep |
| _helper_functions_core.h:1390 `optimize_likelihood_newton` (+:1480 `…_newton_then_lbfgs`, :1512–1584 fixed-param wrappers, `optimize_likelihood`) | Generic MLE driver | Damped Newton with **observed** Hessian solved by `FullPivLU`, step-halving on simple decrease; on failure, L-BFGS from Newton's endpoint | O(p³ + cost(H)) per iteration | A | Keep (FullPivLU → LDLT/LLT is TODO-155; see options for indefinite-H safeguarding) |
| _helper_functions_core.h:277 `build_contiguous_group_layout` | Run-length group boundaries | single pass | O(n) | glue | Keep |
| _helper_functions.h:108 / :124 / :174 `likelihood_ratio_test_from_negloglik`, `score_test_from_score_information`, `gradient_test_from_restricted_score` | LR / Rao score (efficient info via Schur complement) / Terrell gradient statistic | closed form; Schur complement uses a full `covariance_from_information(I_nn)` then a matvec | O(p³) | A | Keep (could be one LDLT solve instead of a full inverse; constant factor, TODO-155) |
| _helper_functions.cpp:11–82 `eigen_Xt_times_X_cpp`, `eigen_compute_single_entry_…`, `eigen_Xt_times_diag_w_times_X_cpp`, `*_test_*_cpp`, `mean_cpp`, `var_cpp` | R-facing forwarders + two-pass mean/var | glue | — | glue | Keep |
| _helper_functions_core.h:1–200, 466–645, 838–900, 983–1011, 1096–1235 (interrupt/time-budget checks, ModelResult, FixedParamSpec, subset/expand helpers, start (un)packers, LikelihoodFitResult, `normalize_optimizer_algorithm`, disabled `compute_min_eigenvalue_if_suspect`) | glue, no algorithmic content | — | — | glue | — |
| **Infrastructure (no algorithmic content):** `RcppExports.cpp` (generated forwarders); `build_info.cpp` / `edi_build_flags.h` (configure-stamped build metadata); `edi_locked_binding.cpp` (R_unLockBinding); `omp_control.cpp` (thread-count setters); `result_map.h` (vector-of-pairs map with linear `get_if`, O(k) and fine for k ≲ 100) / `result_map_rcpp.h` (variant→SEXP); `na_real_core.h` (NA_REAL = qNaN for core builds); `user_compiled_fns.h` / `user_compiled_fn_shims.cpp` (XPtr fn-pointer typedefs + forwarders); `internal_fn_decls.h` (prototypes). **`result_key_store.cpp`** has minimal algorithmic content: FNV-1a 64-bit hash of the result-key tuple into an `unordered_set<uint64_t>` that stores only hashes, so a false "already done" has probability ≈ k²/2⁶⁵ (≈3e-6 at k = 10⁷), which is negligible | — | — | — | infra | Keep |

Totals: 59 catalog rows plus 1 infrastructure row (60 table rows); several rows cover multiple functions.

### Options & disadvantages

**P1. Full n×n Mahalanobis distance matrix (`distance_matrix_mahal_cpp`, optimal_blocks_distance.cpp:196)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| dense Mahalanobis matrix | **current**: Gauss–Jordan S⁻¹, per-pair (x_i−x_j)'S⁻¹(x_i−x_j) | 1× (O(n²p²)) | explicit inverse slightly less stable; absolute 1e-8 ridge is scale-dependent | — |
| | Cholesky S = LL', Z = X L⁻ᵀ once, then Euclidean² on rows of Z | ~p× on the pair loop (O(np² + n²p)) | tolerance-equal, not bit-equal: MILP tie-breaking on near-equal distances could pick different blocks; Cholesky fails if the ridge is too small (keep the ridge, or fall back to LDLT) | Golub & Van Loan, *Matrix Computations* (Cholesky / whitening, standard) |
| | Whitening + Gram trick D = diag(G)1' + 1diag(G)' − 2G, G = ZZ' via DSYRK | another ~5–20× constant (BLAS-3) on top | catastrophic cancellation for near-duplicate points (exactly the near-ties the MILP cares about); needs clamping at 0 | standard (see `intel_hardware.md` TODO-13 "Gram screening") |
| | Leave it | — | the ompr MILP dominates end-to-end at the n it can solve (low hundreds), so the user-visible win is small | — |

**P2. Greedy Mahalanobis swap delta (`design_fixed_greedy.cpp:228`)**
| problem | option | speed vs current | disadvantages | citation |
|---|---|---|---|---|
| per-pair Δf | **current**: O(p) via d·Δ and ‖Δ‖² | 1× | — | — |
| | Gram G = M'M (n×n), g = Mᵀd: O(1) per pair (tracked: `small_kernel_hoists_batch.md` Item A) | ~p× per round | n² memory (200 MB at n = 5000, so it needs the plan's size guard); exact ties may resolve differently | — |
| | **Gram + the existing pruned engine** (`DOptimalPruneObjective` with P = 4G): with X centered, M·1 = 0, so f = ‖M(2w−1)‖² = 4w'Gw *exactly*. The D-optimal adaptive prune bound is already proven for that form | Item A's speedup × prune skip rate (typically large) | same as Item A; plus `abs_mode` fallback (LLT failure) must keep the unpruned path | derivation here; bound proof in `optimal_design_search.cpp:7-10` |
| | first-improvement / random-order search | cheaper per accepted move | **not a drop-in**: reaches different local optima, so it changes the design's allocation distribution, which randomization inference conditions on | — |
| | Kernighan–Lin / tabu / multi-swap | better optima | same: changes the design, does not just speed it up | Kernighan & Lin 1970 (*Bell Syst. Tech. J.*) |

**P3. Stepwise beta / NB / ordinal KK21 weights (kk21_weights.cpp:1108, :1173, :1276)**
| problem | option | speed vs current | disadvantages | citation |
|---|---|---|---|---|
| forward selection by \|t\| given the selected set | **current**: refit [1, x_j, S, w] for every candidate j at every step (Wald t) | 1× (O(p²/2) fits) | ordinal path pays one R callback per fit and has the known gctorture UAF | — |
| | Rao score test from one reduced fit per step (exactly what `kk21_stepwise_logistic_weights_cpp` already does) | ~(p−k)× fewer fits per step, ~p/2× overall (5× at p = 10, theoretical) | weight *values* change (score z, not Wald t), so KK21 distances and matches change; ordering can differ in small samples (Wald suffers Hauck–Donner, score does not); NB needs θ held at the reduced-fit value (β⊥θ orthogonal under the log link, so asymptotically fine); ordinal needs the thresholds block in the efficient information | Rao 1948 (*Proc. Camb. Phil. Soc.*); Hauck & Donner 1977 (*JASA*) |
| | one-step (Newton from the reduced fit) Wald approximation per candidate | similar | approximation quality degrades when the candidate effect is large | [cite needed] |
| | Leave (p is small in KK21) | — | O(p⁴·n) is real at p ≈ 20 with n in the hundreds, per arrival | — |

**P4. Beta-regression φ (kk21_weights.cpp:458-483, :972-996)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| φ̂ at fixed μ | **current**: 19-point grid in log φ, step 0.5 | 19 loglik evals | φ̂ off by up to e^{±0.25} (≈ ±28%), so SE off by up to ~13% and the weight magnitudes are distorted; [e^-2, e^7] range clipped | — |
| | Brent / safeguarded Newton on the 1-D profile in log φ (digamma/trigamma available in `fast_gamma_functions.h`) | ~2–3× fewer evals and exact to tol | changes weight values (not identical), so it needs A/B on KK21 outcomes | Brent 1973 (*Algorithms for Minimization Without Derivatives*) |
| | Full beta MLE (joint Fisher scoring on β, φ) as in `betareg` | slower (more iterations, trigamma in the weights) | the mean model also changes (quasi → true beta MLE) | Ferrari & Cribari-Neto 2004 (*J. Appl. Stat.*) |
| | Grid + one Newton polish step | ~1.05× cost | removes the grid bias cheaply; still not identical | — |

**P5. Atkinson per-arrival inverse (atkinson_assign.cpp:24)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| row 0 of (F'F)⁻¹ | **current**: rebuild F'F O(tp²) + FullPivLU + full inverse O(p³) | 1× | two O(p³) factorizations; FullPivLU is ~2–3× slower than LDLT | Atkinson 1982 (*Biometrika*) |
| | LDLT of F'F + one solve against e₀ | ~3–5× on the O(p³) part | tolerance-equal; the coin probability shifts at the ulp level, which almost never changes the uniform comparison but is not bit-identical | — |
| | incremental F'F (+ z z' per arrival, O(p²)) | removes the O(tp²) rebuild | needs R6-side state; must recompute when `compute_all_subject_data` drops or adds columns | — |
| | Sherman–Morrison on (F'F)⁻¹ | O(p²) per arrival | error accumulates over n updates (needs periodic refresh); invalid on column-set changes; at p ≲ 20 the saved O(p³) is ~8k flops, below the O(tp²) work that remains elsewhere. Same reasoning `kk14_incremental_covariance.md` uses to reject it | Sherman & Morrison 1950 (*Ann. Math. Stat.*) |

**P6. Rerandomization draw (`rerandomization_search_cpp`, rerandomization_helpers.cpp:179)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| sample uniformly from {w : f(w) ≤ a} | **current**: i.i.d. Fisher–Yates + O(np) M·s check | 1/p_acc draws per accept | — | Morgan & Rubin 2012 (*Ann. Statist.*) |
| | d = 2Σ_{i∈T} M_i (uses M·1 = 0) | ~2× on the check | tolerance-equal; accept/reject could flip exactly at the cutoff | — |
| | partial Fisher–Yates (n_T swaps only) | ~2× fewer RNG calls | changes the RNG stream, so not seed-identical to current output | Knuth TAOCP vol. 2 §3.4.2 |
| | MCMC (swap-chain) inside the acceptance region | far fewer rejections at tight a | **invalid**: draws are not i.i.d. uniform on the acceptable set, which breaks the randomization distribution | — |
| | amplitude amplification | √ speedup | fault-tolerant QPU only (audit row I) | — |

**P7. Dense / small linear algebra, NEW-small-dense-linalg (`weighted_crossprod`, `invert_free_information`, Newton's `FullPivLU`, score-test Schur complement)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| X'WX | **current**: p(p+1)/2 unblocked dot products (col-major) | 1× | — | — |
| | form √w∘X, then DSYRK | BLAS-3 blocking: ~2–4× at n ≳ 10³, p ≳ 20; ~1× at small p | needs w ≥ 0 (true for IRLS weights, false for some observed-Hessian weights); extra n·p temporary; BLAS call overhead at p ≤ 5 | Golub & Van Loan |
| Newton step H⁻¹g | **current**: FullPivLU solve | 1× | O(p³) with full pivoting is the slowest LU variant; gives a non-descent step when H is indefinite (then halving fails and L-BFGS takes over) | — |
| | LDLT/LLT with a Levenberg–Marquardt / modified-Cholesky shift when not PD | ~2–3× solve; fewer fallbacks | different iterate path (same optimum); changes `niter` diagnostics | Nocedal & Wright 2006 §3.4 |
| info inverse | **current**: FullPivLU check + `.inverse()` | 1× | double factorization | — |
| | single LDLT (or PartialPivLU) + rcond check | ~2× | bit-compat broken at the five call sites the comment protects | — |
(All tracked by `performance_profiling_and_upgrades.md` TODO-155.)

**P8. Rank-revealing column selection, NEW-rank-revealing-factorization (compute_all_subject_data.cpp:68/88)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| rank + independent columns of a t×p (scaled) matrix, per arrival | **current**: ColPivHouseholderQR ×4 subsets + a second QR for `rank` | O(tp²)×(4–8) per arrival | — | Businger & Golub 1965 (*Numer. Math.*) |
| | recompute only on varying-set change (tracked: kk14 plan TODO-2) | ~t× | must detect "rank could have changed" correctly | — |
| | pivoted Cholesky on a running Welford Gram (O(p²) update + O(p³)) | O(p³) per arrival | Gram-based rank detection squares the condition number (QR tol 1e-12 corresponds to 1e-24 on the Gram), so collinear-column decisions differ | Higham 1990 (pivoted Cholesky, in *Reliable Numerical Computation*) |
| | drop the redundant second QR (`matrix_rank` on already-selected columns): rank := indep_cols.size() | ~2× on that step | equal except in degenerate edge cases where the re-QR finds lower rank. Verify on fixtures | — |

**P9. NEW-forward-stepwise-selection (continuous / logistic paths, already efficient)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| forward selection OLS | **current**: FWL residual updates (MGS), O(np²) | optimal order | plain MGS without reorthogonalization loses orthogonality for near-collinear candidates; the 1e-10 absolute collinearity threshold on ‖e_j‖² is scale-dependent | Golub & Van Loan §5.2 |
| | Householder QR column append | same order, more stable | ~2× flops | same |
| | Gram-matrix (sweep operator) forward selection | O(p³) after O(np²) Gram | squares the condition number | Goodnight 1979 (*Amer. Statist.*) |

**P10. NEW-random-variate-generation**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| uniform permutation / coin flips / permuted blocks | **current**: Fisher–Yates via `std::uniform_int_distribution<int>(0,i)(RRng)`; MSB coin | optimal O(n) | `std::uniform_int_distribution` and `std::shuffle` are implementation-defined, so the same seed gives different designs on libstdc++ vs libc++ (incidental 8) | Knuth TAOCP vol. 2 |
| | Lemire nearly-divisionless bounded ints implemented inside RRng | ~1–2× | changes streams once (one-time break), then becomes portable | Lemire 2019 (*ACM TOMACS*) |
| DGP sampling | R's samplers (inversion / R's rbeta, rpois) | standard | — | — |

**P11. NEW-special-functions (`fast_log1pexp`, `log1pexp_array_fast`)**
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| softplus | **current fast**: truncated atanh series, ~1e-11 abs error | fastest (no log call) | not exact: summed over n terms in a log-likelihood, error is ~n·1e-11, harmless for optimization but enough to break bit-equality with R | — |
| | `log1pexp_array_safe` (exact via Goldberg log1p) | ~1.5–2× slower | — | Goldberg 1991 (*ACM Comput. Surv.*); Mächler 2012 (Rmpfr vignette "Accurately computing log(1−exp(−\|a\|))") |
| | minimax polynomial on [0,1] with more terms | same cost, near-ulp | implementation cost | [cite needed] |

**P12. NEW-dense-distance-matrix (pair-mean distances, Euclidean/L1 blocks)**: brute force is order-optimal because the output is O(m²). The only options are GEMM/Gram (constant factor, with cancellation risk, see P1) and transposing to row-major first (implementation-level). Keep.

**P13. NEW-1d-nuisance-profile**: see P4. The same pattern (a single 1-D nuisance at fixed mean) appears in NB θ (`univariate_negbin_tstat`), which already uses Newton, so that one is Keep.

### New TODO candidates
1. **Whitened Mahalanobis for optimal blocks.**
   - What: replace `compute_mahal_inverse_covariance` + `invert_matrix_cpp` + the per-pair matvec with LLT of (S + ridge), Z = X·L⁻ᵀ once, then Euclidean² on Z.
   - Where: `optimal_blocks_distance.cpp:75,12,196`.
   - Expected win: ~p× in the kernel, O(n²p²) → O(np² + n²p) (theoretical). End-to-end gain is small because the ompr MILP dominates.
   - Risk: tolerance-equal; MILP ties on near-equal distances. Also make the ridge relative (`× mean(diag S)`), as KK14 already does.
   - Gate: deterministic drop-in. Existing optimal-blocks tests plus an "identical block_ids on separated fixtures" test. **Adopt, low priority.**
2. **Greedy Mahalanobis through the pruned D-opt engine** (extends `small_kernel_hoists_batch.md` Item A).
   - What: after Item A's G = M'M, instantiate `DOptimalPruneObjective` with P = 4G and call `exhaustive_best_improvement_search_pruned`, instead of a bespoke O(1) objective. Valid because X is centered (`design_fixed_greedy.cpp:315`), so M·1 = 0 and f = 4w'Gw exactly.
   - Where: `design_fixed_greedy.cpp:423-457`.
   - Expected win: Item A's ~p× times the pruning skip rate (theoretical).
   - Risk: objective-tie resolution differs, so the final w can differ at exact ties. The L1 / LLT-failure fallback must stay unpruned.
   - Gate: deterministic (same local optimum from the same start, modulo ties). Assert identical w on separated fixtures. Fold into Item A's A1/A2.
3. **Score-test stepwise for beta / NB / ordinal KK21.**
   - What: port the `kk21_stepwise_logistic_weights_cpp` scheme: one warm-started reduced fit per step, then Rao z for all candidates.
   - Where: `kk21_weights.cpp:1108,1173,1276`.
   - Expected win: ~p/2× fewer fits (theoretical). For ordinal it also removes O(p²) R callbacks and the UAF-prone `Function` call.
   - Risk: weight values change (score vs Wald), which changes KK21 matches.
   - Gate: **A/B harness** (`algorithm_ab_testing_framework.md`): compare imbalance and match rate the way the 2026-10-08 KK21-speedup study did.
4. **Profile φ by 1-D Brent/Newton instead of a 19-point grid.**
   - Where: `kk21_weights.cpp:458-483, :972-996`.
   - Expected win: fewer evaluations *and* removes up to ~13% SE bias.
   - Risk: changes the weights.
   - Gate: A/B (can share TODO 3's run).
5. **Drop the redundant `matrix_rank` QR.**
   - Where: `compute_all_subject_data.cpp:186,209`, setting `rank = indep_cols.size()`.
   - Expected win: ~½ of that step's QR cost per subset per arrival.
   - Risk: degenerate cases where the re-QR is lower.
   - Gate: deterministic. Add an equality assertion over the test corpus before switching. Coordinate with `kk14_incremental_covariance.md` TODO-2.
6. **Atkinson micro.**
   - What: replace `FullPivLU` + `inverse()` with LDLT + `solve(e₀)` (only row 0 is used).
   - Where: `atkinson_assign.cpp:44-50`.
   - Expected win: ~3–5× on the O(p³) part, small end-to-end.
   - Risk: ulp-level probability changes.
   - Gate: deterministic. Lowest priority. Do not do Sherman–Morrison (P5).

### Incidental findings (optional)
1. **Possible bug: `univariate_weibull_tstat` (kk21_weights.cpp:780-837) does not converge to the Weibull AFT MLE.**
   - With z = (log y − xβ)/σ and w = eᶻ, the β-update's fixed point satisfies Σ x_i (w_i z_i − adj_i) = 0, i.e. Σ x_i (z_i − 1)(w_i − δ_i) = 0. The true score equation is Σ x_i (w_i − δ_i) = 0.
   - The scale "score" Σ[δ(z−1) − z eᶻ] has the δ term's sign flipped relative to ∂ℓ/∂σ ∝ Σ[z eᶻ − δ(1+z)].
   - Effect: KK21 survival weights would be a non-MLE \|t\|. The same `adj` pattern appears in `kk21_stepwise_survival.cpp:47` (not in this group).
   - `test-kk21-weighted-crossprod.R` reportedly re-implements the same IRLS in R, so it would not catch this.
   - Verify: compare β̂ against `survival::survreg(dist = "weibull")` on one fixture. **Investigate.**
2. `simulation_dgp.cpp:90`: `R::rweibull(mu_i, k_survival)` passes exp(η) as the **shape** and k as the **scale**. Treatment then changes the hazard shape, so the DGP is neither PH nor AFT. Censoring `t_i = U(0, t_i)` makes the censoring time depend on the event time. Both may be intentional; verify.
3. `_helper_functions_core.h:940`: `+ 0.5722` looks like a typo for Euler's γ = 0.5772. For a min-extreme-value error the intercept shift is +γ·σ, not +γ. It only affects the start value.
4. `kk21_weights.cpp:43-77` (and the fallbacks at :627-661, :704-736, :890-923): one-pass `Σx² − n x̄²` and the expanded SSE suffer cancellation when \|mean\|/sd is large. A centered two-pass form has the same O(np) cost.
5. `optimal_blocks_distance.cpp:432`: the ridge `cov(a,a) += 1e-8` is absolute, so it is scale-dependent (it dominates for covariates with var ≲ 1e-6). KK14 uses a relative ridge.
6. Thread-count dependence.
   - `greedy_design_search_cpp`, `d_optimal_search_cpp` and `a_optimal_search_cpp` seed **per thread** with `schedule(static)`, so output is reproducible at a fixed core count but differs across core counts. Annealing (per chain) and binary-match (per column) are invariant.
   - `design_class_registry.R:95-110` says optimal_design_search "has no OpenMP at all". That is stale: it is OpenMP-parallel now (`optimal_design_search.cpp:145,192`).
7. `binary_match_search.cpp:50`: `omp_set_num_threads(num_cores)` mutates global OpenMP state and is not restored.
8. Portability: `std::uniform_int_distribution` / `std::shuffle` / `std::uniform_real_distribution` / `std::bernoulli_distribution` over RRng (rerandomization_helpers.cpp:52,243,292; design_fixed_greedy.cpp:304,348-350,374; optimal_design_search.cpp:119; design_optimal_annealing_search.cpp:332,401-403; random_block_size_speedups.cpp:22,39) are implementation-defined. That contradicts the RNG.h comments promising cross-platform and cross-language identical draws: Linux and macOS designs will differ for the same seed.
9. `optimal_blocks_distance.cpp:152-210`: inner loops index `X(i,k)` with k innermost on a column-major `NumericMatrix`, which is a strided access. Copy X to row-major first, as `compute_pair_distance_matrix_cpp` already does.
10. `pocock_simon_assign.cpp:45`: allocates a `std::vector` per (arm, covariate) per call. Implementation-level only.
11. `_helper_functions_core.h:1390`: `warm_start_hessian` is accepted and threaded through four wrappers but ignored (`(void)warm_start_hessian`).
12. `kk21_weights.cpp:1238`: `Function("fast_ordinal_regression_with_var_cpp")` R callback per fit. This is the unprotected-`wrap` crash already recorded in MEMORY (KK21 speedup note, ~L1239). TODO 3 would remove the per-candidate callback count, but the fix there is still needed.

---

## 9. R — shared inference machinery (inference_all_*, inference_ext_*)


Scope: all 37 files `R/EDI/R/inference_all_*.R` + `inference_ext_*.R` (16,143 lines), read 2026-10-09. No `optim()`, `nlm()`, `nlminb()`, `optimize()` or `integrate()` call exists in any assigned file (grep-verified); the only R-level root-finder from `stats` is one `uniroot()` (row 12). All likelihood fitting is delegated to class-specific `generate_mod()`/`spec$fit_null()` (other files / C++); this group owns the *drivers*: CI inverters, resampling loops, caches, warm-start plumbing.

**Status corrections to `algorithm_choice_audit.md` (verified in code today):**
- Row M: `pval_invert_ci_cpp` (`src/lrt_ci_newton.cpp:214-282`) is **still pure bisection** (bracket ≤60 doublings, then bisection to |b−a| < 1e-6, ≤60 steps, returns outer end). `brent_ci_inversion.md` TODO-1..3 are all unchecked; no Brent code exists. LR via `lrt_ci_nr_cpp` (`:99-190`) is still Newton+bisection safeguard (tol_p 1e-7, ≤25 iter).
- Row M's claim "Bartlett factor is analytic, `B` vestigial" is now **wrong for `lik_ratio_bartlett_approx`**: it is a Monte-Carlo factor (B = 99 parametric-bootstrap LR pairs **per δ**, `inference_ext_bartlett_approx.R:202`) fed to the same bisection inverter. Only `lik_ratio_bartlett_exact` is analytic.
- Row M also misses that **count-likelihood LR CIs** (`inference_all_abstract_count_likelihood.R:211`, also `inference_count_composite_likelihood.R:105`) route through the bisection inverter, not the Newton LR inverter.
- Row D says `randomization_ci_affine_shift_reuse.md` "already shipped": **false**. No `supports_additive_delta_shift`, no write site for `cached_values$t0s_rand`; the read branch at `inference_all_abstract_rand.R:303` is still dead. Shipped pieces: sequential-MC early stopping and the high-precision confirm pass (`randomization_ci_search_precision.md`), and the BRT closed-form affine inversion (`inference_all_abstract_rand_bootstrap_ci.R:365`).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity (n, p, B, K, \|R\| as relevant) | family | verdict |
|---|---|---|---|---|---|
| 1. `inference_ext_ci_inversion.R:65` `invert_test_pval_confidence_interval` → `pval_invert_ci_cpp` (`src/lrt_ci_newton.cpp:214`) | score / Bartlett-exact / Bartlett-approx / count-LR CI by test inversion | Wald seed, then exponential bracket (step = SE·2^i), then **pure bisection** in δ to 1e-6; p(δ) memoized per δ (row 7); R closure called from C++ | ≈ 1 + k_bracket + ⌈log₂(width/1e-6)⌉ ≈ 20–25 constrained refits/bound, each O(iter·n·p²) | M | Keep-tracked (`brent_ci_inversion.md` TODO-1..3, **not implemented**) |
| 2. `inference_ext_ci_inversion.R:119` `invert_gradient_ci_uniroot` | gradient-test CI | same `pval_invert_ci_cpp` bisection (the name says uniroot; it is not uniroot) | same as row 1 | M | Keep-tracked (same plan) |
| 3. `inference_ext_ci_inversion.R:173` `invert_lik_ratio_ci_newton` → `lrt_ci_nr_cpp` (`src/lrt_ci_newton.cpp:99`) | LR CI | Newton–Raphson on p(δ) − α with envelope-theorem dp/dδ = 2·f_χ²(T)·score_j, bisection when a step leaves the bracket, tol_p 1e-7 | ~4–8 constrained refits/bound | M | Keep (Venzon–Moolgavkar is an option, see table M) |
| 4. `inference_ext_ci_inversion.R:34` `finalize_inverted_ci` | accept / Wald fallback / give up | sort, width floor 1e-3·Wald width | O(1) | glue | Keep |
| 5. `inference_all_abstract_asymp_lik_std_mod_cache.R:113` `make_warm_fit_null_wrapper` (override) | starting point for the constrained refits inside CI search | **warm start switched off** for every `*_ci` cache key (the code says this is to avoid path-dependent p(δ)), so each constrained refit starts from the spec default | full Newton/IRLS iteration count per refit × 20–25 refits/bound | NEW-ci-refit-warm-start | Prototype (TODO-5) |
| 6. `inference_ext_likelihood_test_memoization.R:242` `make_warm_fit_null_wrapper` (base) | same, non-std-mod-cache classes | chained: start from the previous δ's null solution, which depends on the order of δ visits | saves iterations; result depends on visit order to within solver tolerance | NEW-ci-refit-warm-start | Keep (note: inconsistent with row 5) |
| 7. `inference_ext_likelihood_test_memoization.R:276` `get_memoized_likelihood_test_eval` | per-δ cache of null fit, score, information, −loglik | list keyed by `sprintf("%.17g", δ)` | O(1) lookup | glue | Keep |
| 8. `inference_ext_likelihood_test_memoization.R:349` `get_memoized_likelihood_test_pval` | score / gradient / LR / Bartlett p from one null fit | closed forms in C++ (`src/_helper_functions.cpp:37,44,55`); Bartlett divides LR by c(δ) | O(p³) | A | Keep |
| 9. `inference_ext_bartlett_approx.R:202` `get_bartlett_factor_approx` (via `inference_ext_likelihood_test_memoization.R:411`) | Bartlett factor c(δ) = E[LR\|H₀] | Monte-Carlo mean of B = 99 null-simulated LR statistics (2 refits each), recomputed **at every δ** the inverter visits, worker reuse turned off | 2B ≈ 200 refits per δ → ≈ 4–5k refits per bound, ≈ 9k per CI | NEW-mc-bartlett | Prototype (TODO-3); MC-noise accuracy concern in Incidental I4 |
| 10. `inference_ext_information_matrix.R:107` `compute_variance_from_information_matrix` | Var(θ̂_j) from information | `qr()` rank check, then Eigen single diagonal entry of the inverse (`src/_helper_functions.cpp:18`), fallback `solve`/`qr.solve` | O(p³) (factorizes twice) | A | Keep (TODO-155 territory) |
| 11. `inference_ext_information_matrix.R:184` `score_test_with_ridge_fallback` | non-PD nuisance Schur complement in the score test | escalating ridge (8 multipliers) + `solve()` | ≤8·O(p³) | A | Keep (numerical patch; calibration unverified, as the code itself notes) |
| 12. `inference_all_abstract_asymp.R:239` `invert_ci_to_find_two_sided_pval_for_treatment_effect` | p-value from a CI family by root-finding in α (sole caller: `inference_survival_log_rank.R:136`) | `stats::uniroot` (Brent–Dekker zeroin), tol 1e-6 | ~10–15 CI evaluations | M | Keep (closed form 2Φ(−\|z\|) when the CI is Wald) |
| 13. `inference_all_abstract_asymp.R:169,213,227` Wald CI / p | z or t critical value | `qt`/`qnorm` | O(1) | glue | Keep |
| 14. `inference_all_abstract_param_boot.R:64` `compute_lik_ratio_bootstrap_two_sided_pval` + `:586` `run_param_bootstrap_replicates` | parametric-bootstrap-calibrated LR p-value | B = 199: simulate under the fitted null, then full + null refit; per-replicate seeds drawn from `set.seed(seed)` (common random numbers across δ when a seed is set); reusable worker warm-started from the base MLE; `par_lapply` | 2B refits per δ | J | Keep (Prototype SMC early stop, TODO-8) |
| 15. `inference_all_abstract_param_boot.R:206` `compute_lik_ratio_bootstrap_confidence_interval` | invert the parametric-bootstrap LR p | Wald seed, doubling (≤20), **bisection ≤ 8 iterations**, root_tol = 0.1·SE, early accept when \|p−α\| ≤ MC tolerance | ≈ 1 + 2·(1–3 + 8) ≈ 20–25 p-evals × 398 refits ≈ 8–10k refits | D | Keep-tracked (`garthwaite_buckland_ci_search.md`, its named 2nd consumer); Prototype fixed-critical-value (TODO-9) |
| 16. `inference_ext_param_bootstrap_estimate.R:221` `run_param_bootstrap_estimate_batch` / `:286` replicates (used by `inference_all_abstract_param_boot.R:375,445,521`) | parametric-bootstrap bias correction, basic CI, reflected p | one batch of B = 199 simulate-at-MLE + unrestricted refits, `par_lapply` | B refits **per method call, not cached**: 3B if estimate, CI and p are all requested | J | Keep algorithm; Adopt memoization (TODO-1) |
| 17. `inference_all_abstract_param_boot.R:701-756` `simulate_param_boot_*` | null-data simulation | vectorized `rbinom`/`rpois`/`rnorm`/`rweibull`; ordinal draws one `sample.int` per observation via `apply`, and rejects a draw with any empty category; Weibull censors only at observed censoring times | O(nK) | J | Keep (incidental I16) |
| 18. `inference_all_abstract_non_param_boot.R:426` `approximate_bootstrap_distribution_beta_hat_T` + `:1276` `compute_reusable_bootstrap_worker_distribution` | nonparametric bootstrap distribution | design-aware index draws (`Design$draw_bootstrap_indices` → `bootstrap_indices.cpp` / `bootstrap_match_indices.cpp`); B refits through a reusable worker (warm start = full-data MLE) or one R6 duplicate per replicate; fork/mirai `par_lapply`; timing-based parallel guard; cached by B | B·fit | J | Keep-tracked (audit J / TODO-4, balanced bootstrap) |
| 19. `inference_all_abstract_non_param_boot.R:666` `compute_bootstrap_two_sided_pval` | percentile / symmetric / studentized / BCa p | tail counts | O(B) | J | Keep |
| 20. `inference_all_abstract_non_param_boot.R:829` `compute_bootstrap_confidence_interval` (dispatch; quantiles in a helper file) | 10 CI types | type-8 quantiles | O(B log B) | J | Keep |
| 21. `inference_all_abstract_non_param_boot.R:1602` `approximate_bootstrap_statistics_beta_hat_T` | (θ*, se*) pairs for studentized / smoothed / calibrated CIs | **serial `for` loop**, full R6 `duplicate()` per replicate (no reusable worker), no `par_lapply`, **no seed**, ignores `bootstrap_type` | B fits including the SE | J | Keep algorithm (implementation issue, I7) |
| 22. `inference_all_abstract_non_param_boot.R:1758` `ci_calibrated_bootstrap` (`"prepivoted"`/`"double-bootstrap"`/`"calibrated"`) | double-bootstrap calibration of α | for **each** of 5 grid α values: n_outer ≤ 101 fresh outer resamples × inner bootstrap of 51; pick the grid α whose coverage is closest to 1−α; then one outer B | 5·101·(51+1) + B ≈ 26.8k refits at defaults | NEW-iterated-bootstrap | Prototype (TODO-2) |
| 23. `inference_all_abstract_non_param_boot.R:1803` `ci_smoothed_bootstrap` | smoothed percentile CI | add N(0, sd(y)/√n) noise to y in every replicate | B refits (row 21 loop) | J | Keep (ad hoc bandwidth is documented) |
| 24. `inference_all_abstract_non_param_boot.R:1641` `approximate_jackknife_distribution_beta_hat_T_private` + `:1387` `build_jackknife_deletion_draws` | delete-one-unit replicates (observation / cluster / block / pair / matched set) | n_units refits via reusable worker (warm start = full MLE) or `par_lapply`; cached | n_units·fit | NEW-jackknife-influence | Keep |
| 25. `inference_ext_bca_bootstrap_ci.R:36` `bca_ci_core`, `:68` `bca_pval_core` (callers `inference_all_abstract_non_param_boot.R:1741,1829`) | BCa CI and p-value | z₀ = Φ⁻¹(mean(θ* < θ̂)); â = Σd³ / (6(Σd²)^{3/2}) from jackknife (Efron 1987); adjusted type-8 quantiles; p by the closed-form inverse map | O(B log B) + n_units jackknife refits | NEW-jackknife-influence | Prototype (TODO-7, opt-in influence acceleration) |
| 26. `inference_all_abstract_jackknife.R:227` `compute_jackknife_summary` | Quenouille bias, Tukey variance | moments of the jackknife vector | O(n_units) after refits | NEW-jackknife-influence | Keep (I17) |
| 27. `inference_all_abstract_bayesian_bootstrap.R:82` `approximate_bayesian_bootstrap_distribution_beta_hat_T` + `:578` `bayesian_bootstrap_sample_weights` | Bayesian bootstrap distribution | Dirichlet(1,…,1) as normalized Gamma(1) per group; B weighted refits via reusable worker or duplicate; cached | B·fit + O(B·n) for weights (context rebuilt on every draw) | J | Keep-tracked (audit J antithetic note) |
| 28. `inference_all_abstract_bayesian_bootstrap.R:620` `approximate_bayesian_bootstrap_statistics_beta_hat_T` | (θ*, se*) for the studentized variant | serial loop on one duplicated worker | B weighted fits with SE | J | Keep (I13) |
| 29. `inference_all_abstract_bayesian_bootstrap.R:681` `approximate_bayesian_jackknife_distribution_beta_hat_T` (+ `:719,729` BCa) | weighted delete-one-unit for Bayesian BCa | weight 0 on the deleted unit, within-group rescale m_g/(m_g−1); **serial `vapply`** | n_units weighted refits | NEW-jackknife-influence | Keep / Prototype with TODO-7 |
| 30. `inference_all_abstract.R:513` `run_isolated_weighted_refit` | roll back the cache and warm start after a weighted refit | save/restore | O(1) | glue | Keep |
| 31. `inference_all_abstract_rand.R:28` `approximate_randomization_distribution_beta_hat_T` | randomization null distribution | assignments pre-drawn from the design (`:736` `generate_permutations` → `Design$draw_ws_according_to_design`, cached by design signature); dispatch order: C++ fast kernel (`simple_mean_diff_parallel.cpp:15`, `fast_wilcox_hl.cpp:454`, `kk_compound_distr_parallel.cpp:15`, `fast_kk_wilcox_parallel.cpp:75`) → reused worker → duplicate-per-iteration `par_lapply` | O(r·n) in C++, else r refits | E | Keep (E tracked) |
| 32. `inference_all_abstract_rand.R:383` `compute_randomization_distr_via_reused_worker_states` | r null refits | one cached worker per CI session; **sequential null anchoring**: each permutation is warm-started from the previous permutation's converged null fit (Fisher information dropped) | r·(reduced iteration count)·fit | J | Keep (already the warm-start answer for this loop) |
| 33. `inference_all_abstract_rand.R:523` `compute_fast_randomization_distr_via_reused_worker` | same, for classes that ask for it (e.g. KK quantile OneLik) | chunked reused worker, shifts applied in R | r·fit | J | Keep |
| 34. `inference_all_abstract_rand.R:262` `compute_rand_two_sided_pval` + `:633` `compute_two_sided_randomization_pval_from_t0s` | Monte-Carlo p-value | 2·min(tails), floor 2/n_valid; dead `t0s_rand` branch at `:303` | O(r) | E | Keep |
| 35. `inference_all_abstract_rand.R:695` `compute_two_sided_pval_with_sequential_mc` + `:643` band + `inference_ext_sequential_mc_pval.R:45` | early stopping of the MC p-value | batches of max(25, 2√r); stop once a per-look Clopper–Pearson 99% band excludes α/2 (after ≥ mc_min_draws); no multiplicity control across looks | expected draws ≪ r when p is far from the threshold | NEW-seq-mc-stopping | Keep-tracked (`performance_profiling_and_upgrades.md` TODO-156) |
| 36. `inference_all_abstract_rand.R:763` `build_randomization_distribution_cache_key` + `inference_all_abstract.R:958` `stable_signature` | cache key for the distribution | xxhash64 of the full serialized r×n `w_mat` on **every** p-value call | O(r·n) per call / bisection step | glue | Keep (I12) |
| 37. `inference_all_abstract_rand_ci.R:183` `compute_rand_confidence_interval` + `:493` `build_randomization_ci_search_bounds` + `:574` `expand_bound` | randomization CI: seeding and bracketing | Wald/asymptotic seed at **2α**, radius max(25·SE, 6·sd(y)), ≤7 doublings; δ-quantized p cache | each evaluation ≤ r refits (early-stopped) | D | Keep-tracked |
| 38. `inference_all_abstract_rand_ci.R:681` `compute_ci_by_inverting_the_randomization_test_iteratively` | root of p(δ) = **α/2** | NA repair (≤30), then bisection until \|u−l\| ≤ tol or \|p_u−p_l\| ≤ tol, with **tol = pval_epsilon = 0.005 in both δ units and p units** | ≈ 8–15 evaluations/bound (scale-dependent), each ≤ r refits | D | Keep-tracked (`garthwaite_buckland_ci_search.md`; `randomization_ci_affine_shift_reuse.md` TODO-1..8 **not shipped**) |
| 39. `inference_all_abstract_rand_ci.R:626` `high_precision_confirm_and_refine_ci_bound` | correct for SMC noise at the final bound | 2 full-r evaluations; ≤15 more bisection steps only if they disagree | +2..17 full-r evaluations/bound | D | Keep (`randomization_ci_search_precision.md`) |
| 40. `inference_ext_quantile_rand_ci.R:90` `ci_exact_zhang_combined` → `zhang_bisect_ci_boundary` (`inference_helpers_zhang.R:44`) | Zhang combined randomization CI for KK quantile regression | bisection (≤50 steps) until \|p−α\| < pval_epsilon; each p evaluation = 2 components × `nsim_rand` fresh `rq` refits; **no common random numbers across δ** | ≈ 2 bounds × 10–20 evaluations × 2r ≈ 20–40k `rq` fits | D | Prototype (TODO-6) |
| 41. `inference_all_KK_quantile_regr_ivwc_abstract.R:339` `compute_rand_pval_matched_pairs`, `:367` `compute_rand_pval_reservoir` (+ `:403,424` helpers) | sign-flip and permutation tests on a quantile-regression coefficient | r calls to `quantreg::rq` (Barrodale–Roberts simplex) through formula + `data.frame` each time; `sample()` from the global RNG | r·[model.frame + simplex O(n·p·iters)] | NEW-quantreg | Prototype (TODO-6) |
| 42. `inference_all_KK_quantile_regr_ivwc_abstract.R:238,284`; `inference_all_KK_quantile_regr_one_lik_abstract.R:177,272` | quantile-regression fit (pairs, reservoir, stacked, weighted) | `quantreg::rq(method="br")`; SE from `summary.rq(se="nid")` (Hendricks–Koenker sandwich), then `"iid"`, then IQR/√n fallback; `qr_reduce_*_cpp` for rank | simplex, fine at n ≤ low thousands | NEW-quantreg | Keep |
| 43. `inference_all_abstract_rand_bootstrap.R:219` `approximate_rand_bootstrap_distribution_beta_hat_T` | bootstrap-randomization-test (BRT) null distribution | per draw: design-aware resample + fresh assignment from the design; C++ batch kernels (`rand_bootstrap_mean_diff_parallel.cpp:54`, `fast_wilcox_hl.cpp:599`) → reusable worker → duplicate `par_lapply`; cached | B refits + B design re-runs | J | Keep |
| 44. `inference_all_abstract_rand_bootstrap.R:688` `generate_rand_bootstrap_draws` | materialize w_b for common random numbers | **serial** loop; per-draw `w_seed`; re-runs the design on the resampled covariates (for KK-type sequential designs that is O(n·\|R\|·p²) per draw) | B × design cost, single core | J | Adopt (TODO-4: parallelize, results identical) |
| 45. `inference_all_abstract_rand_bootstrap.R:896` `compute_two_sided_brt_pval_with_sequential_mc` + `:847` `get_brt_distribution_prefix` | BRT early stopping | same Clopper–Pearson band on the common-random-number prefix | ≪ B when p is far from α/2 | NEW-seq-mc-stopping | Keep-tracked (TODO-156) |
| 46. `inference_all_abstract_rand_bootstrap.R:1022` `compute_brt_null_statistics_with_se` (+ `:991`, `:938`, `:1051`) | studentized BRT | C++ (mean diff), reused worker, or duplicate loop; SE fixed at δ = 0 | B fits with SE | J | Keep |
| 47. `inference_all_abstract_rand_bootstrap_ci.R:365` `closed_form_ci_from_affine_null_draws` (coefficients from `inference_all_average_diff.R:212`) | exact BRT CI for statistics affine in δ | breakpoints (t − A_b)/c_b, sorted, one probe per interval | O(B²) probe counting (B ≤ low thousands) | D | Keep (exact; an O(B log B) sweep exists but is irrelevant at these B) |
| 48. `inference_all_abstract_rand_bootstrap_ci.R:99` `compute_rand_bootstrap_confidence_interval` + `:423` expand + `:445` `invert_rand_bootstrap_test_bisection` | BRT CI for non-affine statistics | pre-drawn common random numbers make p(δ) a deterministic step function; doubling bracket; bisection on threshold **α/2** with SMC; no high-precision confirm pass (unlike row 39) | ≈ 10–20 evaluations × ≤ B refits | D | Keep-tracked (Garthwaite–Buckland plan) |
| 49. `inference_all_average_diff.R:68,101,234` estimate / weighted estimate / Welch SE | mean difference and its SE | closed form (frequency-weight Welch) | O(n) | glue | Keep |
| 50. `inference_all_average_diff.R:158` `compute_fast_bootstrap_distr` | rejection-resampled mean-diff bootstrap | R loop | O(B·n) | J | Keep (effectively unreachable, I10) |
| 51. `inference_all_KK_mean_diff_IVWC.R:117` `compute_fast_bootstrap_distr` → `compute_matching_compound_bootstrap_parallel_cpp` (`kk_compound_distr_parallel.cpp:119`) | KK compound bootstrap | index matrices built in R with `which(m_vec == id)` inside the pair loop, plus growing vectors; then C++ | **O(B·m·n)** in R before the C++ call | J | Keep (implementation fix, I9) |
| 52. `inference_all_KK_mean_diff_IVWC.R:155,176` randomization (δ = 0 only) + IVWC shared | inverse-variance-weighted combination of pair and reservoir means | C++ distribution; closed form | O(r·n) | glue | Keep |
| 53. `inference_all_KK_wilcox_ivwc.R:370,388` `rank_for_matched_pairs` / `rank_for_reservoir` | Hodges–Lehmann sub-estimates + SEs | `stats::wilcox.test(conf.int=TRUE)`: exact for m < 50 with no ties (sorted Walsh averages), else normal approximation + `uniroot`; SE = var(Walsh averages)/m and var(pairwise differences)/(n_T+n_C) | O(m² log m), O(n_T·n_C) | NEW-rank-hl | Investigate (SE scale, I2) |
| 54. `inference_all_KK_wilcox_ivwc.R:231,281,405` randomization kernel / standardized rank statistic / fast bootstrap | KK Wilcoxon resampling | C++ (`fast_kk_wilcox_parallel.cpp:75`, `fast_wilcox_hl.cpp:509`); `rank()` O(n log n); index build same as row 51 | O(B·m·n) index build in R | J | Keep (I9) |
| 55. `inference_all_simple_wilcox.R:56,96,299` HL estimate and asymptotic CI | two-sample HL | `wilcox_hl_point_estimate_cpp` (`fast_wilcox_hl.cpp:360`); `wilcox.test(exact=FALSE, conf.int=TRUE)` (normal approximation + `uniroot`) | O(n_T·n_C) | NEW-rank-hl | Keep |
| 56. `inference_all_simple_wilcox.R:250` `hl_point_estimate` (weighted branch) | weighted HL for the Bayesian bootstrap | `outer` + `order` + cumulative-weight median | O(n_T·n_C·log) per replicate | NEW-rank-hl | Keep (selection algorithms only pay off at n ≫ 10³) |
| 57. `inference_all_simple_wilcox.R:358`, `inference_all_average_diff.R:270` `simulate_under_lik_null` | Gaussian null simulation | `rnorm`; HL refit | O(n log n) | J | Keep |
| 58. `inference_all_simple_mean_diff_pooled_var.R:116,120` | pooled-variance t | closed form | O(n) | glue | Keep |
| 59. `inference_all_abstract.R:1183` `fit_with_hardened_qr_column_dropping` | fit with a rank-deficient design | `qr()` (LINPACK dqrdc2, limited pivoting) for rank, then greedy removal of last-pivoted columns with a refit each time | O(n·p²) + k·fit | A | Keep |
| 60. `inference_all_abstract.R:1126,1145` `reduce_design_matrix_preserving_treatment*` | rank reduction that keeps the treatment column | `qr_reduce_preserve_cols_cpp` (`qr_reduce_design_matrix.cpp:42`), keep-set cached | O(n·p²) once | A | Keep |
| 61. `inference_all_abstract.R:652` `set_fit_warm_start` / `inference_all_abstract_asymp.R:295` `get_optimal_warm_start_config` | warm-start policy | resampling fits never overwrite the MLE warm start (except `rand`, which chains); light/medium/heavy tiers pass β, β + weights, or β + information | O(p²) copy | glue | Keep |
| 62. `inference_all_abstract.R:824` `par_lapply` | parallel map | 4·cores chunks; persistent fork cluster or mirai; `clusterSetRNGStream`; serial whenever a deadline is set | — | glue | Keep |
| 63. `inference_ext_minimum_volatility_selector.R:15` `select_optimal_resample_size` | choose m (m-out-of-n) or b (subsampling) | grid of K = 9 sizes (n^0.5…n^0.9), B = 251 each, rolling-sd window 3, argmin (Politis–Romano–Wolf minimum volatility) | K·B ≈ 2.3k refits of size m < n | NEW-resample-size-selection | Keep |
| 64. `inference_ext_m_out_of_n_bootstrap.R:51,143,209,311` | m-out-of-n bootstrap | draws from `exchangeable_resampling_draws_cpp` (`exchangeable_resampling_draws.cpp:233`); B refits; √m-scaled centered pivot; basic CI; refuses if <50% of replicates are finite | B·fit(m) | J | Keep |
| 65. `inference_ext_prw_subsampling.R:46,343` | Politis–Romano–Wolf subsampling | draws without replacement; FPC 1/√(1−b/n) | B·fit(b) | J | Keep |
| 66. `inference_ext_exchangeable_resampling_units.R:34,133,150,199,229,314,323` | units, stratified allocation, draws, distribution, pivot CI/p | largest-remainder (Hamilton) allocation by stratum; C++ draws with R fallback; quantile pivot | O(B·n) draws + B·fit | J | Keep |
| 67. `inference_all_abstract_count_likelihood.R:117,160,211` count plumbing | count fit cache, SE (information first), score/LR/gradient CIs | LR CI uses the **bisection** inverter (row 1), not Newton (row 3); bootstrap fallback CI when SE is missing | ≈ 20–25 refits/bound | M | Investigate (why the count families bypass Newton LR, I5) |
| 68. `inference_all_abstract_mle_or_KM_summary_table.R:90` `shared` | coefficient table from vcov | `vcov()`, z, `pnorm` | O(p²) | glue | Keep |
| 69. `inference_all_abstract_asymp_lik_std_mod_cache.R:177` `shared` | fit cache + warm start | `generate_mod()` (class-specific C++) | — | glue | Keep |
| 70. `inference_all_abstract_KK_passthrough_compound.R:26` `compute_estimate_with_bootstrap_weights` | weighted KK compound (fallback) | weighted pair and reservoir means with `w*` fixed from the observed fit | O(n) | glue | Keep |
| 71. glue — no algorithmic content: `inference_all_abstract_asymp_lik.R` (testing-type dispatch, Bartlett exact/approx selection), `inference_all_abstract_exact.R`, `inference_all_abstract_marginal_estimand.R`, `inference_all_abstract_quantile_rand_ci.R`, `inference_all_abstract_jackknife.R` (public wrappers), `inference_all_abstract.R` (initialize, accessors, capabilities, caches), `inference_ext_information_matrix.R:20` (information-source selection) | — | — | — | glue | — |

Totals: 70 algorithmic rows + 1 glue row; every one of the 37 files appears.

### Options & disadvantages

**M — deterministic test-inversion CI root (rows 1–3, 12, 67)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| score / gradient / Bartlett-exact / count-LR bound | bisection to 1e-6 (current) | 1× (~20–25 refits/bound) | none for correctness; spends ~15 refits only refining digits | — |
| same | Brent–Dekker (inverse-quadratic + secant with bisection guard) | ~3–5× fewer refits (5–8/bound) | converged bound matches within tol, not bit-identical; degrades to bisection if p(δ) is non-smooth (e.g. after the ridge fallback switches on mid-search) | Brent 1973, *Algorithms for Minimization Without Derivatives* |
| same | Illinois / regula falsi | similar to Brent | slightly less robust when the function is very flat on one side | [cite needed] |
| LR only | Newton with envelope derivative (current for row 3) | ~4–8 refits | needs the score at the null fit; count families do not use it | — |
| LR only | Venzon–Moolgavkar: solve (∂ℓ/∂θ_{−j} = 0, ℓ = ℓ̂ − χ²₁,α/2) jointly by Newton | one Newton system per bound (~3–6 iterations of O(n·p²+p³)) instead of nested root × refit | needs `neg_loglik_at`/`information_at` at arbitrary θ (only some specs have them); can diverge without a good start (Wald endpoint helps); LR only | Venzon & Moolgavkar 1988, *Appl. Statist.* 37:87–94 |
| Bartlett-approx bound (p(δ) is Monte-Carlo) | any of the above | — | p(δ) is stochastic unless a seed is set; with a seed it is a common-random-number function that is only piecewise smooth, so Brent can stall back to bisection | see NEW-mc-bartlett |

**NEW-ci-refit-warm-start (rows 5–6)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| start of each constrained refit in a CI search | cold / spec default (current, std-mod-cache classes) | 1× | full iteration count every time | — |
| same | chain the previous δ's solution (current, base memoization) | saves 1–3 Newton iterations | result depends on the order δ is visited, within optimizer tolerance (the reason row 5 turned it off); non-concave fits can jump basins | — |
| same | **deterministic tangent predictor**: θ⁰(δ) = θ̂ + (δ−θ̂_j)·[−I_nn⁻¹I_nj ; 1] from the full-fit information (already stored as `fit_warm_start_fisher` for "heavy" tiers) | saves ~1–3 iterations per refit (~30–50% of search cost for iterative fits), with no path dependence | needs an information matrix of the right dimension (fall back to cold start otherwise); first-order only, so poor far from θ̂ (bracket-expansion points) | Allgower & Georg 1990, *Numerical Continuation Methods* (predictor–corrector) |
| same | start from θ̂ with θ_j := δ | small saving, deterministic | worse than the tangent predictor whenever nuisance parameters are correlated with θ_j | — |

**NEW-mc-bartlett (row 9)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| Bartlett factor for the LR CI | MC mean of B = 99 null LRs re-simulated at every δ (current) | 1× (≈ 9k refits/CI) | **MC SE of c ≈ √(2/B) ≈ 0.14**, the same size as or larger than the O(1/n) correction it estimates (c − 1 is typically 0.01–0.1); independent noise at each δ (no seed) makes bisection run on a noisy function | Lawley 1956, *Biometrika* (Bartlett correction); Rocke 1989, *JASA* (bootstrap Bartlett adjustment) |
| same | one MC factor at δ = θ̂ (or at the two Wald endpoints) with large B (e.g. 999), held fixed through the search | ~10–20× fewer refits | drops the δ-dependence of c, which changes by O(n^{−3/2}) across a CI-width neighbourhood, so the corrected interval is accurate to O(n^{−3/2}) instead of O(n^{−2}); changes results, so A/B is needed | Lawley 1956 (order of the correction) |
| same | analytic factor (`_exact`, Cordeiro-type) | ~200× per δ (no simulation) | must be derived class by class; only some families have one | Lawley 1956 |
| same | use the parametric-bootstrap-calibrated LR (row 14) instead | a different estimator | same cost class as the current approach; full bootstrap calibration rather than a mean correction | Beran 1988, *JASA* 83:687–697 |

**D — Monte-Carlo CI search (rows 15, 37–40, 47–48)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| rand / BRT / Zhang / parametric-bootstrap-LR bound | bracket + bisection + SMC + confirm pass (current) | 1× | ~10–25 evaluations, each up to r (or 2B) refits | — |
| same, statistic affine in δ | closed-form breakpoint inversion (shipped for BRT, row 47; planned for rand as affine-reuse TODO-8) | ~20–30× (one distribution) | only for statistics exactly affine under the additive shift; tier-2 equivariance unproven | `randomization_ci_affine_shift_reuse.md` |
| same, general | Robbins–Monro (Garthwaite–Buckland) | ~3–20× (unmeasured) | only asymptotic (CLT) coverage of the bound; step-size tuning; the stream is no longer common-random-number deterministic | Garthwaite & Buckland 1992, *Appl. Statist.*; plan exists |
| same | anytime-valid confidence sequences | similar | redesign of the testing layer | `randomization_ci_search_precision.md` |
| same | Brent | — | rejected: p(δ) is a step function under common random numbers, so interpolation steps are always refused | `brent_ci_inversion.md` |
| parametric-bootstrap LR bound | **fixed bootstrap critical value**: simulate the LR null distribution once at θ̂, take q*_{1−α}, then use the Newton LR inverter (row 3) with χ² replaced by q* | ≈ 8–10k → ≈ 400 + ~10 refits (~20×) | assumes LR is (asymptotically) pivotal in δ near the bounds; error O(n^{−1}) in that dependence, so second-order behaviour differs from per-δ calibration; A/B needed | Beran 1987, *Biometrika* 74:457–468 (prepivoting); Hall 1992, *The Bootstrap and Edgeworth Expansion* |
| Zhang quantile CI (row 40) | common random numbers (one sign/permutation matrix per search) + bisection | same evaluation count, but p(δ) becomes monotone-deterministic, so fewer wasted or erroneous steps | changes MC realisation (results differ by MC noise only) | — |

**NEW-jackknife-influence (rows 24–26, 29): BCa acceleration â and jackknife SE**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| â for BCa | delete-1 jackknife over design units (current) | 1× (n_units extra refits, warm-started; at n = 1000 and B = 501 this **doubles** the BCa cost) | O(n) refits; poor for non-smooth statistics (HL and quantiles are already refused) | Efron 1987, *JASA* 82:171–185; Efron & Tibshirani 1993 §14.3 |
| same | analytic empirical influence U_i = e_j′Ĥ⁻¹s_i(θ̂) (infinitesimal jackknife), summed within units for cluster/pair designs | n refits → 0 (O(n·p²)) | needs per-observation score contributions, which most specs do not expose (they expose score and information); differs from jackknife â at O(n⁻¹) relative, so BCa endpoints move (not a drop-in); not defined for IVWC compounds, ranks or KM without bespoke influence functions | Efron 1982, *The Jackknife, the Bootstrap and Other Resampling Plans* (SIAM); Davison & Hinkley 1997 §2.7 |
| same | regression / IJ estimate of influence from the B replicates already drawn (cov(N*_i, θ*)) | 0 refits; O(B·n) memory and time | needs B ≫ n (EDI often has n ≈ B), so â is MC-noisy and biased upward by O(n/B); needs the stored resample count matrix | Efron 2014, *JASA* 109:991–1007; Davison & Hinkley 1997 §2.7.4 |
| same | ABC intervals (numerical second derivatives in resampling-weight space) | ~2n+ evaluations, no Monte-Carlo BCa | smooth statistics only; no fewer evaluations than the jackknife | DiCiccio & Efron 1992, *Biometrika* 79:231–245; DiCiccio & Efron 1996, *Stat. Sci.* |
| same | grouped (delete-d) jackknife with g ≪ n groups | n → g refits | noisier â; depends on the random grouping (an extra RNG stream) | [cite needed] |
| each jackknife replicate | one-step Newton deletion approximation (approximate leave-one-out) | ≈ iteration count (2–4×) cheaper per replicate | approximation, not exact jackknife; the gain is small once warm-started, and R6 overhead per replicate probably dominates | Pregibon 1981, *Ann. Statist.* 9:705–724; Rad & Maleki 2020, *JRSS-B* |

**NEW-iterated-bootstrap (row 22)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| calibrate the percentile CI level | 5-point α grid, fresh outer × inner bootstrap per grid point, nearest-coverage pick (current) | 1× (≈ 26.8k refits) | grid quantizes α to {α/4, α/2, α, 1.5α, 2α}; outer resamples are unseeded | — |
| same | **one** outer × inner set; u_b = inner-CDF position of θ̂ for each outer b; calibrated level = empirical quantiles of {u_b} (prepivoting / Hall–Martin calibration) | ~5× fewer refits (≈ 5.2k) and a continuous α | results change (finer calibration), so coverage needs A/B; the same nested cost structure remains | Beran 1987, *Biometrika*; Hall & Martin 1988, *Biometrika* 75:661–671 |
| same | Booth–Hall reduced inner B with MC-error-optimal allocation | a further ~2× on top of the line above | extra tuning; small B_inner gives a noisy u_b | Booth & Hall 1994, *Biometrika* 81:331–340 |
| same | use studentized or BCa (second-order accurate, no nesting) instead | ~50× cheaper | different interval (needs SEs or a jackknife); not "calibrated" in the double-bootstrap sense | Efron & Tibshirani 1993; Hall 1992 |

**NEW-seq-mc-stopping (rows 35, 45)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| stop drawing replicates once the decision is clear | Clopper–Pearson 99% band per look, batches of max(25, 2√r) (current) | 5–10× when p is far from the threshold | no control of resampling risk across repeated looks (each look 1% error; ~r/batch looks); handled only partially by the final confirm pass | — |
| same | Besag–Clifford (stop after h exceedances) | similar | gives a valid p-value but not a decision with bounded risk near the threshold | Besag & Clifford 1991, *Biometrika* 78:301–304 |
| same | Gandy's sequential test with uniformly bounded resampling risk | similar or better near the threshold | more bookkeeping; the boundary must be computed | Gandy 2009, *JASA* 104:1504–1511 |
| same | fixed r (no stopping) | 0.1–0.2× (slower) | — | — |

**NEW-quantreg (rows 41–42)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| one quantile-regression fit | `rq()` formula interface, `"br"` simplex (current) | 1× | model.frame/data.frame overhead dominates at n ≈ 50–200 | Barrodale & Roberts 1974, *CACM*; Koenker & d'Orey 1987, *Appl. Statist.* |
| same | `quantreg::rq.fit(X, y, tau, method="br")` on the matrix directly | identical result; skips model.frame (3–10×, unmeasured) | must replicate column naming / NA handling manually | same |
| same | Frisch–Newton interior point (`"fn"`) | faster only at n ≫ 10³ | can differ at degenerate (non-unique) solutions | Portnoy & Koenker 1997, *Stat. Sci.* 12:279–300 |
| randomization test of a quantile coefficient | r refits per δ, fresh `sample()` (current) | 1× | no common random numbers, so p(δ) is noisy inside bisection; no SMC | — |
| same | regression rank-score test (asymptotic) | ~r× (no resampling) | asymptotic, not a randomization test, so the exactness motivation is lost | Gutenbrunner, Jurečková, Koenker & Portnoy 1993, *J. Nonparam. Stat.* |
| same, intercept-only pairs (p = 0) | τ-quantile of sign-flipped differences by selection (O(m)) | ≫10× | none (exact equivalence for p = 0) | — |

**NEW-resample-size-selection (row 63)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| choose m or b | minimum volatility over a 9-point grid × B = 251 (current) | 1× (~2.3k smaller refits) | grid-coarse; noisy volatility | Politis, Romano & Wolf 1999, *Subsampling* |
| same | Bickel–Sakov adaptive rule (distance between consecutive m on a geometric grid) | similar cost | needs a distance on distributions; different tie behaviour | Bickel & Sakov 2008, *Ann. Statist.* |
| same | fixed m = n^0.7 (the existing default) | ~10× cheaper | not data-adaptive; brittle for unstable estimators | — |

**NEW-rank-hl (rows 53, 55–56)**
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| HL estimate (one- or two-sample) | all Walsh averages / pairwise differences, sort or select (current) | 1× (O(n²) memory) | O(n²) memory at n ≫ 10³ | Hodges & Lehmann 1963, *Ann. Math. Statist.* |
| same | Monahan (one-sample) / Johnson–Mizoguchi (X+Y selection) | O(n log n) | only pays off at n in the thousands; weighted versions need custom code | Monahan 1984, *ACM TOMS* 10:265–270; Johnson & Mizoguchi 1978, *SIAM J. Comput.* 7:147–153 |
| SE of HL | var(Walsh)/m, var(pairwise)/(n_T+n_C) (current, KK IVWC) | — | **wrong asymptotic scale** (see I2) | Hettmansperger & McKean 2011, *Robust Nonparametric Statistical Methods* |
| same | invert the rank test (distribution-free CI) or use the density-based 1/(12n(∫f²)²) with a kernel ∫f² estimate | O(n log n)–O(n²) | needs a bandwidth or an inversion | same |

**J — bootstrap loops (rows 14, 16, 18, 21, 27–28, 43–44, 51, 64–66)**: tracked under audit J (balanced bootstrap, TODO-4). The only new options here are implementation-level (memoization TODO-1, parallel draw materialization TODO-4, serial loops I7/I13).

### New TODO candidates
1. **Memoize the parametric-bootstrap estimate batch** — `inference_ext_param_bootstrap_estimate.R:221` (`run_param_bootstrap_estimate_batch`), keyed on (B, max_attempts, seed, data signature), shared by `compute_param_bootstrap_estimate` / `_confidence_interval` / `_pval` (`inference_all_abstract_param_boot.R:375,445,521`). Win: 3B → B refits when all three are run, as `InferenceSuite` does (theoretical 3×). Risk: none when a seed is set (identical); without a seed, results remain MC-equivalent. Deterministic drop-in, no A/B.
2. **Rewrite the double-bootstrap calibration** — `inference_all_abstract_non_param_boot.R:1758`: draw one outer × inner set once, compute u_b, and take calibrated levels from the quantiles of {u_b} (Beran prepivoting / Hall–Martin). Win: ≈ 26.8k → ≈ 5.2k refits (theoretical 5×), continuous α. Risk: coverage changes, so run it through the A/B harness. Seed the outer draws while doing this.
3. **Bartlett-approx: compute the MC factor once per CI** — `inference_ext_bartlett_approx.R:202` / `inference_ext_likelihood_test_memoization.R:411`: estimate c at θ̂ (or at the two Wald endpoints) with large B and hold it fixed during inversion. Win: ≈ 9k → ≈ 0.5–2k refits per CI (theoretical 5–20×), and less MC noise than B = 99. Risk: drops O(n^{−3/2}) δ-dependence. Needs A/B (coverage). Pair it with Brent from `brent_ci_inversion.md`.
4. **Parallelize BRT draw materialization** — `inference_all_abstract_rand_bootstrap.R:688-736`: run `materialize_chunk` over `par_lapply` chunks. Every draw already carries its own `w_seed` (`set.seed(draw$w_seed)` per draw), so results do not depend on execution order. Win: up to #cores on the serial pre-pass, which matters for sequential (KK) designs where each draw re-runs matching. Deterministic drop-in (verify bit-identity in a test).
5. **Deterministic tangent warm start for CI-search refits** — `inference_all_abstract_asymp_lik_std_mod_cache.R:113` (currently cold for every `*_ci` key), and optionally `inference_ext_likelihood_test_memoization.R:242`. Start = θ̂ + (δ−θ̂_j)·[−I_nn⁻¹I_nj; 1] from the stored full-fit information. This keeps the path-independence that motivated the cold start. Win: ~1–3 fewer Newton/IRLS iterations per constrained refit (theoretical 30–50% of score/gradient/LR CI cost for iterative fits). Risk: the bound moves within optimizer tolerance, and a bad predictor far from θ̂ could land in a worse basin for non-concave fits (fall back to cold start when the predicted point fails). Gate: existing CI tests, plus a light A/B on non-concave families.
6. **KK quantile-regression randomization CI** — `inference_all_KK_quantile_regr_ivwc_abstract.R:339,367,403,424`; `inference_ext_quantile_rand_ci.R:90`.
   - (a) Pre-draw one sign-flip / permutation matrix per CI search (common random numbers), so bisection runs on a deterministic, monotone-in-expectation p(δ). This is a Prototype: the MC realisation changes.
   - (b) Replace formula `rq()` with `quantreg::rq.fit(X, y, tau, method="br")`. Identical results; theoretical 3–10× on the ~20–40k fits per CI. Adopt.
   - (c) Optionally add SMC early stopping (row 35 machinery).
7. **Opt-in influence-function BCa acceleration** for likelihood classes whose spec can return per-observation scores — `inference_ext_bca_bootstrap_ci.R:36,68` callers. Removes n_units refits per BCa (theoretical up to 2× of total BCa cost at n ≈ B). Risk: â differs at O(n⁻¹), so endpoints move. Prototype through the A/B harness; keep the jackknife as the default.
8. **SMC early stopping for the parametric-bootstrap LR p-value inside its CI search** — `inference_all_abstract_param_boot.R:206` / `:586`, reusing `InferenceExtSequentialMCPval`. Theoretical 2–5× on the expansion steps far from α. Prototype; it composes with the Garthwaite–Buckland plan.
9. **Fixed-critical-value bootstrap-calibrated LR CI** (new method or opt-in) — `inference_all_abstract_param_boot.R:206`: bootstrap the LR once at θ̂, then use the Newton LR inverter (`lrt_ci_nr_cpp`) with threshold q*. Theoretical ≈ 20× (≈ 8–10k → ≈ 0.4k refits). Risk: assumes local pivotality of LR in δ. Needs A/B.
10. (Tracked, not new, but re-confirmed as still open) **Implement `brent_ci_inversion.md`** and extend its gate to the count-family LR CIs (`inference_all_abstract_count_likelihood.R:211`) and Bartlett-exact CIs, which also use `pval_invert_ci_cpp`.

### Incidental findings (optional)
- **I1 (possible coverage bug — verify by simulation).** The randomization CI and the BRT CI invert a **two-sided** p-value (2·min tail; `inference_all_abstract_rand.R:641`) at threshold **α/2** (`inference_all_abstract_rand_ci.R:210,322-325,535-536`; `inference_all_abstract_rand_bootstrap_ci.R:314-321,368`). That yields nominal 1−α/2 (97.5%) intervals. The docstring (`inference_all_abstract_rand_ci.R:94-97`: "p-value … at least alpha") and the other inverters (`pval_invert_ci_cpp`, Zhang `inference_ext_quantile_rand_ci.R:118`, parametric-bootstrap LR) all use α. Seeds are built at 2α (`:559,568`), consistent with the α/2 choice. If confirmed, rand and BRT CIs over-cover by design.
- **I2 (possible SE miscalibration).** `inference_all_KK_wilcox_ivwc.R:377-381,395-397` use var(Walsh averages)/m and var(pairwise differences)/(n_T+n_C) as HL variances. Under normality the true asymptotic HL variance (1/(12n(∫f²)²)) is ≈ πσ²/(3m), against ≈ σ²/(2m) from the formula, a ≈ 2.09× variance ratio. The same 2.09× holds for the two-sample case. The IVWC weights are scale-invariant, but the asymptotic CI (`:107`) would cover ≈ 82% at nominal 95%. Check against the comprehensive-tests coverage CSV for `InferenceAllKKWilcoxIVWC` before acting. The same formula is said to match C++ `estimate_hl_ssq_*`.
- I3. Audit row D's "affine-shift reuse shipped" is incorrect (see header). `cached_values$t0s_rand` is never written; `inference_all_abstract_rand.R:303` and its clone-copy at `inference_all_abstract.R:268` are dead.
- I4. Bartlett-approx factor B = 99: MC SE of c ≈ 0.14 under χ²₁ (sd(LR) ≈ √2) swamps the O(1/n) correction, so the "corrected" test can be noisier than the plain LR. Worker reuse is deliberately off (`:228`).
- I5. Count families' LR CI bypasses the Newton LR inverter (`inference_all_abstract_count_likelihood.R:211`); the reason is undocumented.
- I6. Tolerance unit mixing: `pval_epsilon` (0.005) is used both as a δ-width (scale-dependent: too coarse for small-scale responses, too many steps for large-scale ones) and as a p-span (`inference_all_abstract_rand_ci.R:721`, `inference_all_abstract_rand_bootstrap_ci.R:482`).
- I7. `inference_all_abstract_non_param_boot.R:1602` `approximate_bootstrap_statistics_beta_hat_T` is serial, does a full R6 duplicate per replicate, is **unseeded** (studentized / smoothed / calibrated CIs are irreproducible even after `set_seed`), and drops `bootstrap_type`.
- I8. `ci_calibrated_bootstrap` (`:1758`): `"prepivoted"` and `"calibrated"` produce identical intervals. Outer resamples are unseeded. Inner bootstraps inherit `private$seed` through `duplicate()`, so every inner bootstrap reuses the same index pattern.
- I9. `inference_all_KK_mean_diff_IVWC.R:117-145` and `inference_all_KK_wilcox_ivwc.R:405-433` build bootstrap indices with `which(m_vec == id)` inside an m-loop plus growing vectors (O(B·m·n)). Precompute `split(seq_along(m_vec), m_vec)` once.
- I10. `inference_all_average_diff.R:158` `compute_fast_bootstrap_distr` is only called from the KK passthrough mixin, where it returns NULL (`is_KK`), so it is effectively dead for this class.
- I11. Parallel warm-up guards discard 2 full replicate fits per call (`inference_all_abstract_non_param_boot.R:588-590`, `inference_all_abstract_rand.R:193-194`, `inference_all_abstract_bayesian_bootstrap.R:212-214`, `inference_all_abstract_rand_bootstrap.R:362-363`); the second result could be kept.
- I12. `stable_signature` re-serializes and hashes the r×n `w_mat` on every p-value call (`inference_all_abstract_rand.R:765`), O(r·n) per bisection step; cache the hash as an attribute on the permutations object.
- I13. Bayesian bootstrap rebuilds `build_bayesian_bootstrap_context()` (including `compute_cluster_ids_cpp`) for every draw and stores it per draw (O(B·n) memory; `inference_all_abstract_bayesian_bootstrap.R:579`). The Bayesian jackknife (`:699`) and studentized stats (`:656`) are serial.
- I14. BCa z₀ uses mean(θ* < θ̂) without tie splitting (`inference_ext_bca_bootstrap_ci.R:37,69`), which biases z₀ for discrete statistics; the usual fix is (#< + ½#=)/B.
- I15. Misnomers: `invert_gradient_ci_uniroot` uses bisection; the `inference_all_abstract_rand_bootstrap.R:425` doc says the "uniroot-based delta search" but the code bisects.
- I16. `simulate_param_boot_ordinal_y` (`inference_all_abstract_param_boot.R:718`) loops `sample.int` per observation via `apply` (vectorizable with one `runif(n)` against cumulative probabilities). It rejects draws missing a category, i.e. it simulates conditionally on full support (cf. the known ordinal parametric-bootstrap sign bug memory).
- I17. The jackknife variance uses the equal-unit Tukey formula even when KK deletion units mix pairs (size 2) and reservoir singletons (`inference_all_abstract_jackknife.R:272`).
- I18. Warm-start policy for CI-search refits is inconsistent between families: cold in std-mod-cache classes (row 5), path-dependent chained in the base (row 6).

---

## 10. R — inference classes: survival, ordinal, continuous, count


Scope: 57 files `R/EDI/R/inference_{survival,ordinal,continuous,count}_*.R` (28.5k lines), read-only.
Shared R drivers these classes call (the generic randomization/bootstrap loops in `inference_all_abstract_rand.R:523`
`compute_fast_randomization_distr_via_reused_worker`, parametric-bootstrap driver `inference_all_abstract_param_boot.R`,
CI inverters `inference_ext_ci_inversion.R`) belong to another group; they are named here only to give each class's per-replicate cost.
Notation: n obs, p covariates, K ordinal levels, m pairs, B/r replicates, D distinct event times, G clusters, n_gh GH nodes, C = # design-candidate rungs.
"RW-loop" = the R-level reused-worker loop that re-runs the class's full estimator once per permutation (parallelised by chunk over cores, but each
draw is an R call); its cost is r × (cost of one estimate).

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| **CONTINUOUS** ||||||
| continuous_ols.R:262 `shared` | OLS β̂_T + model SE | delegates to `fast_ols_cpp`/`fast_ols_with_var_cpp` (C++); hardened QR column-dropping on failure | O(np²) | A | Keep (C++ side cataloged elsewhere) |
| continuous_ols.R:201 `compute_fast_rand_bootstrap_distr` | randomization-bootstrap null draws | `compute_rand_bootstrap_ols_parallel_cpp` (C++, threaded) | O(B np²) | J/D | Keep (C++ elsewhere) |
| continuous_ols.R:222 & continuous_lin.R:216 `compute_rand_bootstrap_ci_affine_coefs` | affine coefficients (A_b, c_b) for the closed-form BRT CI | **pure-R loop over B draws**, each `qr()` of the n×(p+2) [Lin: n×(2p+2)] resampled design with a two-column RHS | O(B n p²) in R; ~B × 0.1–1 ms | D (affine-shift reuse) | Keep algorithm (one QR per draw is necessary: rows differ per draw); port loop to C++ is implementation-level — see Incidental |
| continuous_lin.R:285 `shared` | Lin (2013) interacted OLS + HC2 | `stats::lm.fit` (LINPACK Householder QR, limited pivoting) + `ols_hc2_post_fit_cpp` | O(n p²) | A | Keep |
| continuous_lin.R:206 `compute_fast_randomization_distr` | randomization null | RW-loop: `lm.fit` per draw (no C++ batch kernel, unlike OLS) | O(r n p²) + r R-call overheads | NEW-r-replicate-loop | Prototype (C++ batch kernel mirroring OLS's; deterministic) |
| continuous_lin.R:396, continuous_KK_ols_one_lik.R:290 `get_likelihood_test_spec` (+ `simulate_under_lik_null` lin.R:361, KK_ols_one_lik.R:245) | score / gradient / LR CIs and param-bootstrap LR for a Gaussian linear model | generic inverters (score: bisection; gradient: `uniroot`; LR: Newton) each doing a constrained `lm.fit`/`fast_ols_with_var_cpp` refit per δ; param-bootstrap LR re-simulates B datasets | ~6–20 refits per bound; param-boot O(B·refits) | NEW-gaussian-closed-form | **Adopt** (σ² is fixed at the full-fit value in the spec, so LR = score = gradient = (β̂−δ)²/(σ̂²[(X'X)⁻¹]_jj) exactly; bounds are closed-form; LR null law is exactly F(1,n−p) — the class already uses that in `get_bartlett_factor_exact` — so the param bootstrap estimates a known distribution) |
| continuous_KK_ols_one_lik.R:389 `fit_combined`, :459 `fit_weighted_combined` | stacked matched-diff + reservoir OLS | `lm.fit`/`lm.wfit` + HC2 C++ post-fit; `reduce_design_matrix_once` cached | O(n p²) | A | Keep |
| continuous_KK_ols_one_lik.R:185, KK_ols_ivwc.R:88 `compute_fast_randomization_distr` | randomization null | RW-loop (`lm.fit` per draw) | O(r n p²) | NEW-r-replicate-loop | Prototype (same as Lin) |
| continuous_KK_ols_ivwc.R:93 `shared`, :176 `ols_for_matched_pairs` | IVWC of pair-diff OLS and reservoir OLS, Satterthwaite df | 2× `lm.fit` + HC2 C++ | O(n p²) | A | Keep |
| continuous_KK_glmm.R:216 `shared_rcpp` | Gaussian random-intercept LMM (pairs + singletons) | `fast_gaussian_lmm_cpp` (exact Gaussian marginal likelihood, no quadrature; `optimization_alg`, maxit 300, eps_g 1e-6); estimate-only replicates use **GLS fast path** `fast_gaussian_lmm_gls_cpp` with variance components frozen at the observed fit; fallback `shared_glmm_tmb` (glmmTMB: Laplace — exact for Gaussian — + nlminb) | O(n p²) per GLS; O(iters·n p²) full | A/C | Keep (GLS-with-frozen-VC is the right replicate shortcut) |
| continuous_robust_regr.R:262 `fit_rlm_model`, :286 `shared`, :100 weighted | M / MM regression | `fast_robust_regression_cpp` (C++ IRLS; MM per C++ side); fallback `MASS::rlm` (IWLS; MM = `lqs` S-estimator start by random subsampling, then Tukey-bisquare IWLS) | O(iters·n p²); MM start O(nsamp·p³) | NEW-robust-M | Keep (IRLS is the standard M-estimation algorithm; Huber 1964, Yohai 1987) |
| continuous_robust_regr.R:374 `compute_fast_rand_bootstrap_distr`; :239 `compute_fast_randomization_distr` | BRT null / randomization null | BRT: `compute_robust_rand_bootstrap_parallel_cpp`; plain randomization: RW-loop (C++ fit per draw, warm start) | O(B·iters·n p²) | J / NEW-r-replicate-loop | Keep / Prototype (batch C++ like BRT path) |
| continuous_KK_robust_regr_one_lik.R:236 `fit_rlm`, :365 `fit_combined`, :427 weighted; continuous_KK_robust_regr_ivwc.R:206 | stacked / IVWC robust regression | C++ IRLS; `estimate_only` **forces Huber "M"** (no MM phase); `maxit` capped 10–25, `acc` 1e-3/1e-4; MASS::rlm fallback with MM→M retry ladder | O(maxit·n p²) | NEW-robust-M | Keep (see Incidental re M-vs-MM statistic) |
| continuous_quantile_regr.R:232 `fit_quantile_model`, :252 `shared`, :105 weighted | linear quantile regression | `quantreg::rq.fit(method="br")` (Barrodale–Roberts simplex) for estimate-only; `quantreg::rq` default = also **"br"** for full/weighted fits; SE `summary.rq(se="nid")` (Hendricks–Koenker sandwich) → fallback `"iid"` (helper_matching.R:172) | br: empirically ~O(n p²)–O(n² ) pivots, fast to n≈5k; nid SE O(n p²) + 2 extra fits | NEW-quantile-LP | **Keep "br"** at EDI sizes (see options) |
| continuous_quantile_regr.R:200 `compute_fast_randomization_distr` | randomization null for β̂_T,τ | RW-loop: one `rq.fit(br)` per draw; no affine shift identity (y−δw_obs is not in the column space of the permuted design) so the rand-CI bisection pays r refits per step | O(r · br) per p-value; × bisection steps for CI | NEW-r-replicate-loop / D | Keep algorithm; Prototype C++/batched driver only if profiling says so |
| continuous_KK_quantile_regr_ivwc.R, continuous_KK_quantile_regr_one_lik.R (leaves) | KK matched-diff + reservoir quantile regression | glue over `inference_all_KK_quantile_regr_*_abstract.R`: `quantreg::rq` default ("br"); RW-loop randomization | O(r · br) | NEW-quantile-LP | Keep (algorithm cataloged with the component) |
| continuous_KK_bai_abstract.R:302 `compute_halves` | pairs-of-pairs matching for Bai–Romano–Shaikh (2022) variance | `compute_pair_averages_cpp` + `compute_pair_distance_matrix_cpp` + `nbpMatching::nonbimatch` (Derigs blossom-type min-weight perfect matching) on m pair-averages; cached | O(m³) once | G | Keep |
| continuous_KK_bai_abstract.R:279 `compute_bai_variance_for_pairs` | BRS λ² / variance | `compute_lambda_squ_cpp`, closed form | O(m) | NEW-closed-form | Keep |
| continuous_KK_bai_abstract.R:203 `compute_fast_randomization_distr` | randomization null | `compute_bai_distr_parallel_cpp` (halves reused across draws) | O(r n) | E | Keep |
| continuous_KK14_bai.R, continuous_KK21_bai.R | — | glue — no algorithmic content (KK14 overrides a squared-Euclidean `distance`; unused by the C++ path) | — | — | — |
| **COUNT** ||||||
| count_poisson.R:706 `generate_mod`, :402 weighted, :569 rand-estimate | Poisson GLM | `fast_poisson_regression{,_with_var,_weighted}_cpp` (IRLS/Newton, C++) with hardened QR dropping | O(iters·n p²) | A | Keep |
| count_poisson.R:816 `compute_fast_randomization_distr` | randomization null | `compute_poisson_distr_parallel_cpp` | O(r·iters·n p²) | A/J | Keep |
| count_poisson.R:615/659, count_quasipoisson.R, count_robust_poisson.R, count_composite_likelihood.R:109 | likelihood-test spec / param-bootstrap LR | C++ score/Hessian getters; constrained refits via `fixed_idx`; param bootstrap = R-level B loop of C++ refits (driver elsewhere); quasi/robust use sandwich (`robust_sandwich_variance_from_xtwx`) | O(B·iters·n p²) | A/J | Keep |
| count_negbin.R:412 `generate_mod`, :121 weighted | NB2 GLM | `fast_neg_bin{,_weighted,_with_var}_cpp` (joint β, log θ); weighted fallback `stats::glm(poisson)` IRLS | O(iters·n p²) | A (θ boundary per negbin plan) | Keep |
| count_composite_likelihood.R | — | glue (abstract `shared` + param-bootstrap closure over `fast_poisson_regression_cpp`) | — | — | — |
| count_zero_augmented_poisson_abstract.R:1008 `generate_mod`, :791 rand-estimate | ZIP / ZINB / hurdle-Poisson MLE | `fast_zero_augmented_poisson_cpp` / `fast_zinb_cpp` joint Newton/L-BFGS; **hurdle-Poisson fitted as two independent blocks** (:688 — count block with zero-part fixed, then zero block with count fixed), exploiting exact separability of the hurdle likelihood | O(iters·n(p+q)²) | B | Keep-tracked (em_algorithm_zero_inflated_mixtures.md); hurdle separability already optimal |
| count_zero_augmented_poisson_abstract.R:126 `compute_estimate_with_bootstrap_weights` (+ :990 `fit_zero_augmented_model`) | Bayesian-bootstrap replicate of ZIP/ZINB/hurdle-P | **`glmmTMB::glmmTMB` per replicate** (TMB AD + `nlminb`; no RE so exact ML) with full `sdreport` unless estimate_only | B × (TMB build ~10–100 ms + nlminb) | B / NEW-r-replicate-loop | Prototype (weighted C++ kernels; see TODO-3) |
| count_hurdle.R:693 `generate_mod`, :580 `try_hurdle_negbin_fit`, :616 spec | hurdle-NB MLE + LR/score | `fast_hurdle_negbin{,_with_var}_cpp`, null refits `fast_truncated_negbin_count_cpp` (count block only — separability) ; score CI via `invert_test_pval_confidence_interval` (bisection) | O(iters·n p²) per refit | A/B, M | Keep; score CI → Keep-tracked (brent_ci_inversion.md TODO-1..3) |
| count_hurdle.R:400 `compute_estimate_with_bootstrap_weights` | Bayesian-bootstrap hurdle-NB | **`glmmTMB(truncated_nbinom2)` per replicate** | B × glmmTMB | NEW-r-replicate-loop | Prototype (TODO-3) |
| count_zero_inflated.R | ZIP / ZINB leaves | glue (family/description over the ZA abstract) | — | — | — |
| count_KK_combined.R:311 `shared_rcpp`, :242 weighted, :376 rand | Poisson random-intercept GLMM (pairs + singletons) | `fast_poisson_glmm_cpp` (20-node GH; IRLS/Newton/L-BFGS by `optimization_alg`, warm start); fallback glmmTMB (Laplace + nlminb) over a predictor-candidate ladder | O(iters·n·n_gh·p²) | C | Keep-tracked (performance_profiling_and_upgrades.md TODO-153 AGQ) |
| count_KK_gee.R | Poisson GEE | glue → `KKGEE` component (`fast_gee.cpp` / geepack) | — | K | Keep |
| count_KK_cond_poisson.R:263 `shared` (HurdlePoissonIVWC) | IVWC of matched hurdle-Poisson GLMM + reservoir Poisson GLM | `fast_hurdle_poisson_glmm_cpp` (GH) → fallback `glmmTMB(truncated_poisson, ziformula, (1\|pair))` (Laplace + nlminb, `parallel=num_cores`); reservoir `fast_poisson_regression_*_cpp` | O(iters·n·n_gh·p²) | C | Keep-tracked (TODO-153); Laplace fallback is the less accurate one at cluster size 2 (audit C) |
| count_KK_cond_poisson.R:149 / :373 weighted matched hurdle | Bayesian-bootstrap of matched hurdle GLMM | **always glmmTMB** (no weighted C++ GLMM; comment at :~327) | B × glmmTMB(+RE Laplace) | C / NEW-r-replicate-loop | Prototype (weighted hurdle-GLMM C++ exists for the OneLik class: `get_hurdle_poisson_glmm_weighted_*_cpp`) |
| count_KK_cond_poisson.R:1111 `fit_combined_hurdle` (HurdlePoissonOneLik) | joint hurdle-Poisson GLMM (pairs) + Poisson (reservoir) MLE | **R `stats::optim(method="BFGS")`**, maxit 300, reltol 1e-8, analytic gradient from C++ (`get_hurdle_poisson_glmm{,_weighted}_score_cpp` + reservoir score), objective C++ GH NLL + R Poisson NLL; analytic Hessian computed only afterwards for SE; `optimization_alg` ternary at :1173 yields "BFGS" on both branches | ~50–300 BFGS iters × O(n·n_gh·p) | C (+A for reservoir) | Prototype (damped Newton/trust-region with the analytic Hessian that is already available; see TODO-4) |
| count_KK_cond_poisson.R:1890 `fit_combined_cpoisson` (CondPoissonOneLik) | conditional-Poisson pairs (binomial-logit on y_T\|n_k) + reservoir Poisson | `fast_cpoisson_combined_with_var_cpp` (C++ Newton) | O(iters·n p²) | A | Keep |
| count_KK_cond_poisson.R:2029 `compute_weighted_combined_estimate` | Bayesian-bootstrap replicate of the same **concave** likelihood | **R `optim(BFGS)`** on R-coded NLL/score (`weighted_cpoisson_neg_loglik/score`), maxit 300 | ~20–100 iters × O(n p) in R per replicate | A | **Adopt** (add a weights arg to the C++ Newton kernel: same concave optimum, quadratic vs superlinear; TODO-2) |
| count_KK_cond_poisson.R:1806 `build_combined_cpoisson_data` | pair extraction | R loop over pairs with `which(m_vec == pid)` | O(n·m) per call (called per bootstrap replicate) | NEW-r-replicate-loop | see Incidental |
| **ORDINAL** ||||||
| ordinal_proportional_odds.R:220, ordinal_ordered_probit.R:196, ordinal_cauchit.R:190, ordinal_cloglog.R:229, ordinal_adj_cat_logit.R:149 `generate_mod` (+ weighted, rand, spec) | cumulative-link (logit/probit/cauchit/cloglog) and adjacent-category MLE | C++ Newton/Fisher kernels `fast_ordinal_*_cpp`, `fast_adjacent_category_logit_cpp`; score/Hessian getters | O(iters·n K (p+K)²) | A | Keep |
| ordinal_cloglog.R:113/172, ordinal_stereotype_logit.R:449/528 null refits (`fit_null`) | constrained null refit for LR / param-bootstrap LR | **2-start** (warm start + full-fit-with-δ, nudged +1e-3), keep lower NLL | 2× refits | A (cloglog) / NEW-nonconcave (stereotype) | Cloglog: Investigate (log-concave link ⇒ concave likelihood in (α,β) — Pratt 1981 — so a "local optimum" means solver/parametrization failure, not nonconcavity; see Options). Stereotype: Keep-tracked (multistart_nonconcave_likelihoods.md) |
| ordinal_stereotype_logit.R:~400 `.stereotype_full_data_multistart` (+ :1–95 helpers) | stereotype logit (bilinear φ_k·β, genuinely nonconcave) | primary C++ fit + up to 8 deterministic restarts (±γ shifts, alternating, 2 data-seeded via an in-R Lehmer LCG + Box–Muller that never touches `.Random.seed`); full data only | ≤ 9 × O(iters·n K p²) once | NEW-nonconcave | Keep-tracked (multistart_nonconcave_likelihoods.md) — RNG-free seeding is the right design |
| ordinal_stereotype_logit.R:852 (continuation-ratio class in same file) | continuation-ratio logit | `fast_continuation_ratio_regression*_cpp` | O(iters·nK p²) | A | Keep |
| ordinal_adj_cat_logit.R:245, ordinal_stereotype_logit.R:955, ordinal_KK_combined.R:737 `simulate_under_lik_null` | simulate ordinal y under null | **per-observation R loop** (`sample.int` / sequential `runif`) | O(nK) R ops per replicate | J | Keep algorithm (inverse-CDF is optimal); vectorise — Incidental |
| ordinal_partial_proportional_odds.R:292 `shared`, :525 `fit_vgam`, :578 `fit_clm`, :632 `fit_polr` (+ weighted variants) | partial proportional odds | no nonparallel terms → C++ PO; else ladder `VGAM::vglm(cumulative, parallel=…)` (IRLS/Fisher scoring) → `ordinal::clm(nominal=)` (Newton w/ step-halving) → `MASS::polr` (optim BFGS) → weighted surrogate | O(iters·n K²p²) per rung, ≤3 rungs | A | Keep (PPO likelihood can be improper—crossing cumulatives—so the ladder is a reasonable robustness device) |
| ordinal_partial_proportional_odds.R:260 rand-estimate | randomization null | RW-loop, VGAM per draw when nonparallel terms exist | r × vglm (~10–50 ms) | NEW-r-replicate-loop | Keep (no C++ PPO kernel; Prototype only if used heavily) |
| ordinal_gcomp.R:241 `shared`, :301 `compute_md_gradient`, :328 weighted | g-computation mean difference under PO + delta-method SE | C++ PO fit + `gcomp_ordinal_proportional_odds_post_fit_cpp`; delta-method gradient by **central finite differences** (2(p+K−1) post-fit calls); weighted path tries ≤3 starts | O((p+K)·nK) per SE | A / NEW-delta-method | Keep (analytic gradient exists but FD cost is negligible at EDI sizes; FD error ~1e-8 rel) |
| ordinal_ridit.R:224 `shared`, :258/:268/:208 | ridit analysis + randomization / bootstrap | `fast_ridit_analysis_cpp`, `compute_ridit_{distr,bootstrap,rand_bootstrap}_parallel_cpp`; bootstrap indices drawn in an R loop with arm-rejection | O(B n) | E/J | Keep |
| ordinal_jonckheere_terpstra_test.R:191 `compute_exact_jt_components` | exact JT/Mann–Whitney p-value (2 arms) | `exact_jonckheere_terpstra_pval_cpp` | (C++ elsewhere) | NEW-exact-rank | Keep (C++ elsewhere) |
| ordinal_jonckheere_terpstra_test.R:141 `weighted_superiority` | weighted P(Y_T>Y_C)+½P(=) per Bayesian-bootstrap replicate | **`outer()` of all n_T×n_C pairs** (3 dense matrices) | O(n_T n_C) time and memory per replicate, ×B | NEW-exact-rank | **Adopt** → weighted category tabulation + cumulative sums, O(n+K) (the unweighted path at :~170 already does exactly this); TODO-1 |
| ordinal_jonckheere_terpstra_test.R:128 `compute_fast_rand_bootstrap_distr` | BRT null | `compute_jt_rand_bootstrap_parallel_cpp` | O(B n) | E/J | Keep |
| ordinal_paired_sign_test.R:235 `shared`, :140 weighted | matched-pair sign test | counts of y-diff signs (closed form); weighted path loops pairs with `which(m_vec==pid)` | O(m) / O(n m) | NEW-closed-form | Keep (Incidental: O(nm) loop) |
| ordinal_KK_clmm_abstract.R:277 `shared_rcpp` (+ logit/probit/cauchit/cloglog leaves) | CLMM: cumulative-link random-intercept model | `fast_ordinal_clmm_cpp` (GH quadrature, **eps_g = 1e-3**) warm-started from fixed-effects C++ fit; `use_rcpp=FALSE` → `ordinal::clmm` (default nAGQ=1 = **Laplace**) → `ordinal::clm` (drops RE) | O(iters·n·n_gh·K p²) | C | Keep-tracked (TODO-153); see Incidental re eps_g and estimand-mismatched fallbacks |
| ordinal_KK_clmm_abstract.R:169 `compute_weighted_clmm_estimate` | Bayesian-bootstrap replicate of CLMM | **fixed-effects ordinal fit** (`fast_ordinal_regression_weighted_cpp` for logit, else `weighted_ordinal_bootstrap_surrogate_fit` = MASS::polr BFGS) — no random intercept | O(iters·nKp²) | C | Investigate (marginal-vs-conditional estimand mismatch; see Incidental) |
| ordinal_KK_combined.R:521 `shared_rcpp` (KKGLMM), :460 weighted | ordinal GLMM (cumulative logit, RE) | `fast_ordinal_glmm_cpp` (n_gh = 20, lbfgs default) ; weighted replicate = fixed-effects `fast_ordinal_regression_weighted_cpp` | as CLMM | C | Keep-tracked (TODO-153); weighted path: same Investigate as CLMM |
| ordinal_KK_combined.R:146 `fit_ordinal_gee_mod` (KKGEE) | ordinal GEE, local-odds-ratio working structure | `multgee::ordLORgee(LORstr="uniform")` (Touloumis–Agresti–Kateri 2013; Fisher scoring, vglm backend) over a predictor-candidate ladder; Bayesian bootstrap disabled (surrogate mismatch acknowledged in code) | O(iters·n K² p²) per rung | K | Keep |
| ordinal_KK_cond_logit_abstract.R:27 `ordinal_cond_clogit_shared_multi`; ordinal_KK_cond_adj_cat_logit.R:166 | conditional logit on expanded adjacent-category binary trials within pairs | C++ expansion (`expand_adjacent_category_data_cpp`) + R loop building X_stack + `clogit_helper` (helper_glm_fit.R:2004: discordant-pair differences → C++ logistic regression, exact CL for 1:1 strata) | O(n K p) build + O(iters·m p²) | A | Keep |
| **SURVIVAL** ||||||
| survival_coxph.R:545 `generate_mod` (right-censored) | Cox PH partial likelihood | `build_cox_data_cache_cpp` (sorted risk-set cache, reused across calls) + `fast_coxph_regression_prebuilt_cpp(newton_raphson)`; fallback `.fit_survival_coxph_kernel` = `survival::coxph.fit(method="breslow")`; `use_rcpp=FALSE` → `survival::coxph(ties="breslow")` | O(n log n + iters·n p²) | A / L | Keep (point-estimate tie-method consistency fixed in v1.0.5 TODO-69; audit row L) |
| survival_coxph.R:776 `compute_fast_rand_bootstrap_distr` | BRT null | `compute_coxph_rand_bootstrap_parallel_cpp` (right-censored only) | O(B·iters·n p²) | J | Keep |
| survival_coxph.R:~700–727 icen path (`icenReg::ic_sp`) | semiparametric PH for interval/left-censored data | `icenReg::ic_sp(model="ph", bs_samples=200)` — ICM for baseline masses + Newton for β (Anderson-Bergman 2017); **SE = 200 internal bootstrap refits** (0 when estimate_only); randomization/bootstrap via generic loop (fast path returns NULL) | point: O(iters·(n·#Turnbull-intervals)); SE: 200× that | NEW-interval-censored | Keep-tracked? — no plan exists; Prototype candidate (see Options: profile-likelihood / EM-sieve SEs) |
| survival_coxph.R:2–100 `.fit_survival_coxph_kernel`, `.fit_survival_coxph_fixed_kernel` | Cox fit / δ-constrained fit (offset trick) | `survival::coxph.fit(method="breslow")`, `init=NULL` | O(iters·n p²) | A / L | Keep |
| survival_coxph.R:109/136/153 `.cox_neg_loglik_breslow_r`, `.cox_score_breslow_fd_r`, `.cox_information_breslow_fd_r` | Breslow NLL, score, information | pure R: per event time rescans risk set (`y >= tt`) ⇒ O(nD)≈O(n²); score by central FD (2p NLL calls), information by FD (≈2p² NLL calls) | O(p² n²) in R | A / L | Investigate → apparently **dead code** (no callers outside contract list `contracts_mixins.R:999`); if ever used, replace with analytic O(n log n + n p²) reverse-cumsum score/info |
| survival_strat_cox.R:569 `generate_mod`, :308 `shared` | stratified Cox | `compute_survival_strata_ids_cpp` + `build_stratified_cox_data_cache_cpp` + `fast_stratified_coxph_regression_cpp` / `fast_coxph_regression_prebuilt_cpp`; fallbacks `coxph.fit(breslow)` and `survival::coxph(..., ties="breslow")` formula | O(n log n + iters·n p²) | A / L | Keep (point-estimate formula fallback fixed in v1.0.5 TODO-69) |
| survival_strat_cox.R:39 `cox_partial_likelihood_informative_rows` | drop non-informative strata | R loop over strata with `which(strata_id==s)` | O(n·S) | — | Keep (Incidental: `split()`/`tapply` gives O(n)) |
| survival_strat_cox.R:256, survival_coxph.R:421 `compute_estimate_with_bootstrap_weights` | weighted Cox replicate | `weighted_cox_bootstrap_surrogate_fit` (globals.R:281) = `survival::coxph(weights=, …)` (Efron default, NR with step-halving) per replicate | B × coxph | A / L | Keep (tie-method note in Incidental) |
| survival_KK_strat_cox.R:176 `shared` (IVWC), :~322 one-lik | pair-stratified Cox (conditional on pair) + reservoir Cox | `fast_stratified_coxph_regression_cpp` (each pair a stratum) + `fast_coxph_regression_cpp` over a C ≤13-rung correlation-threshold design ladder; `compute_zhang_match_data_cpp` | O(C·iters·n p²) worst | A | Keep |
| survival_KK_lwa_cox_ivwc_abstract.R:205 `fit_cox_model`, :162 `cox_design_candidates`; survival_KK_lwa_cox_one_lik_abstract.R (fast_coxph_regression_cpp(cluster=) on stacked data) | Lee–Wei–Amato marginal Cox with cluster-robust sandwich | `fast_coxph_regression_cpp(cluster=)` over ≤13-rung ladder (stop at first finite SE); candidates recomputed each call (12× `drop_highly_correlated_cols` + QR) | O(C·(np² + iters·n p²)) | A | Keep (Incidental: cache candidates) |
| survival_KK_lwa_cox.R, survival_KK_rank_regr.R | — | glue (leaf classes over components) | — | — | — |
| survival_KK_rank_regr_ivwc_abstract.R:262 `aftsrr_for_matched_pairs`, reservoir twin | rank-based (Gehan) AFT | `aftgee::aftsrr` defaults (Gehan weights, induced-smoothing estimating equation, Brown & Wang 2007 / Johnson & Strawderman 2009) with `se = "ISMB", B = 0`; ≤13-rung design ladder, stop when SE finite | O(n² p) per estimating-equation eval (Gehan pairs) × iters × C | NEW-rank-AFT | Investigate (`B = 0` with ISMB — see Incidental; if SE is NA the full 13-rung ladder runs every time) |
| survival_weibull.R:387 `generate_mod` | Weibull AFT MLE (right / general censoring) | `fast_weibull_regression_cpp` / `fast_weibull_regression_general_cpp` (interval/left-censored likelihood) + score/Hessian getters | O(iters·n p²) | A | Keep |
| survival_KK_weibull_marginal.R:185 `fit_weibull_marginal_cpp`, :240 survreg fallback | Weibull AFT + cluster-robust (pair) sandwich | C++ MLE + R sandwich (`rowsum` of scores by cluster, crossprod) ; fallback `survival::survreg(robust=TRUE, cluster=)` (Newton) | O(n p²) | A | Keep |
| survival_KK_weibull_marginal.R:395 BRT | BRT null | `compute_weibull_rand_bootstrap_parallel_cpp` | O(B·iters·n p²) | J | Keep |
| survival_GLMM_weibull_frailty_normal.R:260/348/… | Weibull AFT with normal frailty (pairs) | `fast_weibull_frailty_cpp` (GH quadrature) | O(iters·n·n_gh·p²) | C | Keep-tracked (TODO-153) |
| survival_GLMM_weibull_frailty_loggamma.R:333 `clayton_copula_for_matched_pairs`, :779 one-lik | Weibull AFT with gamma frailty = Clayton copula (pairs) | `fast_clayton_weibull_aft_optim_cpp` (closed-form marginal — no quadrature) over a ≤4-candidate design ladder; reservoir `fast_weibull_regression_cpp` | O(iters·n p²) | A | Keep |
| survival_GLMM_weibull_frailty_loggamma.R:866 `simulate_under_lik_null` | simulate Clayton-copula pairs | conditional-inversion sampler (closed form, verified algebra), per-pair R loop | O(n) R ops | J | Keep |
| survival_dep_cens_transform.R:481 `generate_mod` | bivariate log-normal event/censoring transformation model | `fast_dep_cens_transform_optim_cpp` + score/Hessian getters | O(iters·n p²) | NEW-copula-surv | Keep |
| survival_dep_cens_transform.R:335 `dep_cens_percentile_bootstrap_ci`, :363 `dep_cens_validate_bootstrap_ci` | percentile bootstrap CI (B=1000 default) + validation | B refits via `approximate_bootstrap_distribution_beta_hat_T`; `quantile(type=8)`; replace by Wald CI when bootstrap CI excludes 0 but Wald includes 0, NA if \|bound\|>2 | O(B·iters·n p²) | J | Keep algorithm; see Incidental (selection rule) |
| survival_log_rank.R:237 `compute_shared`/ `compute_shared_icen` | log-rank (right) / Sun-score log-rank (interval) | right: `fast_logrank_stats_cpp`; interval: `interval::ictest(scores="logrank1")` — pooled Turnbull NPMLE by self-consistency EM (`icfit`) then linear rank scores | right O(n log n); interval O(iters_EM · n · J) | NEW-interval-censored | Keep (right); interval: see next row |
| survival_log_rank.R:177 & gehan_wilcox.R (+ :251 `compute_shared_icen`, `scores="wmw"`) randomization under interval censoring | permutation null of an interval-censored score test | fast path returns NULL ⇒ generic loop calls `ictest()` per draw ⇒ **re-solves the identical pooled NPMLE r times** (pooled (L,R) are label-invariant at δ=0) | O(r · iters_EM · n J) | NEW-interval-censored | **Adopt** (compute scores c_i once from the pooled NPMLE; null stat = linear in w ⇒ one matrix product over the permutation matrix; TODO-5) |
| survival_log_rank.R:195 `weighted_logrank_mean_difference`; gehan_wilcox.R:205 `weighted_peto_prentice_mean_difference` | weighted log-rank / Peto–Prentice statistic per replicate | `survival::coxph(~1, weights, method="breslow")` martingale residuals (+ `survfit` for PP) | O(n log n) per replicate (+ formula overhead) | NEW-closed-form | Keep (could be one C++ sweep, cf. `fast_gehan_wilcox_stats_cpp`; implementation only) |
| survival_gehan_wilcox.R (right-censored path) | Gehan/Peto–Prentice Wilcoxon | `fast_gehan_wilcox_stats_cpp` (fused sweep); convenience `survdiff(rho=1)` | O(n log n) | NEW-closed-form | Keep |
| survival_km_diff.R:259 `shared` | difference in KM medians + SE | `get_survival_stat_diff` (helper) ; SE back-solved from `survfit` quantile CIs (Brookmeyer–Crowley style); interval-censored → `turnbull_npmle_stat_diff` | O(n log n) | NEW-closed-form | Keep |
| survival_km_diff.R:373 `weighted_km_median` | weighted KM median per Bayesian-bootstrap replicate | R while-loop; **`at_risk_weight = sum(row_weights[i:n])` recomputed at every distinct time** + growing vectors via `c()` | O(n·D) ≈ O(n²) per replicate | NEW-closed-form | **Adopt** (reverse cumulative sum after the sort: O(n log n); identical up to FP summation order; TODO-6) |
| survival_rmst.R:221 `weighted_survival_stat_for_group`, :279 `compute_s_beta_hat_T` | RMST difference (shared τ) + SE | `survival::survfit(weights=)` + O(D) area loop; SE from `get_restricted_mean_se_diff` (helper); interval-censored → Turnbull, SE = **nonparametric bootstrap fallback** | O(n log n); icen SE: B × 2 icfit | NEW-closed-form / NEW-interval-censored | Keep (right); icen → TODO-7 |
| helper_inference_survival_turnbull.R:29 `turnbull_npmle_group_stat` (called by km_diff.R, rmst.R) | per-arm Turnbull NPMLE | `interval::icfit(L,R)` defaults (self-consistency EM, Turnbull 1976; `icfitControl` epsilon 1e-6, maxit 10000), then O(J) step-function functional | O(iters_EM · n J), EM linear (often slow) convergence | NEW-interval-censored | Prototype (EMICM hybrid; TODO-7) |

Row count: 84 rows (incl. 6 glue lines). Every assigned file appears at least once (continuous 14, count 11, ordinal 15, survival 17).

### Options & disadvantages

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| Linear quantile regression fit (continuous_quantile_regr.R, KK quantile components) | **Barrodale–Roberts simplex `"br"` (current)** | baseline | exact vertex solution; slows down past n ≈ 5–10k; picks one vertex when the solution set is non-unique (ties, discrete y) | Koenker & d'Orey 1987, *Appl. Stat.* (AS 229); Koenker 2005 *Quantile Regression* §6 |
| | Frisch–Newton interior point `"fn"` | ~same at n ≤ 2k; 2–10× faster at n ≥ 10k | solution to a duality-gap tolerance, not an exact vertex ⇒ tiny numerical differences and a different choice among non-unique solutions — a randomization test whose observed statistic and null draws come from different solvers could disagree in tied data; no win at EDI sizes | Portnoy & Koenker 1997, *Stat. Sci.* |
| | `"pfn"` (preprocessing + FN) | big win only at n ≫ 10⁵ | extra tuning; pointless at EDI sizes | Portnoy & Koenker 1997 |
| | `"sfn"` sparse FN | wins only for sparse X | X is dense here | Koenker & Ng 2005 (SparseM) [cite needed for exact venue] |
| | Smoothed check loss / convolution-smoothed QR (Newton) | O(n p²) per iter, warm-startable | changes the estimator (bias O(h²)), needs bandwidth; not the classical β̂_τ | Fernandes, Guerre & Horta 2021, *JBES* [cite needed — verify] |
| | **Verdict** | Keep "br" for continuous (n tens–low thousands). Note proportion_quantile_regr.R (not this group) uses `"fn"` for estimate-only but default `"br"` for full/weighted fits — see Incidental | | |
| Gaussian-model score/gradient/LR CI and param-bootstrap LR (lin.R, KK_ols_one_lik.R) | generic root-finders on refits (current) | baseline: ~6–20 refits/bound; param boot B·(1+refits) | none statistically; pure waste | — |
| | **closed form**: with σ² fixed in the spec, LR = score = gradient = Wald_model² ⇒ CI = β̂ ± z·σ̂√[(X'X)⁻¹]_jj; exact LR null = F(1, n−p) | ~10–20× fewer fits per CI; param-boot LR eliminated (B× ) | must keep reporting exactly what the current code reports (model-based σ², not HC2); if σ² were ever re-estimated under the null the identity changes to a monotone transform of F (still closed form) | standard linear-model theory (e.g. Seber & Lee 2003, *Linear Regression Analysis*) |
| Concave likelihood fit in pure R (count_KK_cond_poisson.R:2029) | **R `optim(BFGS)` (current)** | baseline: superlinear, 20–100 iters, R-coded f/g | R interpreter overhead per eval; reltol stopping, not gradient-norm | Nocedal & Wright 2006 ch. 6 |
| | C++ Newton (existing `fast_cpoisson_combined_with_var_cpp` + weights arg) | ~10–50× per replicate (fewer iters, compiled) | small implementation; result identical to tolerance because the objective is strictly concave (binomial-logit + Poisson-log, canonical links) | McCullagh & Nelder 1989 ch. 2.5 |
| | Weighted IRLS in R (`glm.fit`) on stacked binomial+Poisson pseudo-data | ~3–5× | needs two families in one fit (not directly expressible); more code than adding weights to C++ | — |
| Nonconcave GH-GLMM in R optim (count_KK_cond_poisson.R:1111) | **R `optim(BFGS)` with analytic gradient (current)** | baseline | no use of the available analytic Hessian; reltol stop; BFGS can terminate early on flat σ direction | — |
| | Damped Newton / trust-region (`trust`-style) with the analytic Hessian (`combined_hurdle_hessian`) | 2–5× fewer iterations near optimum (quadratic) | Hessian can be indefinite away from optimum ⇒ needs Levenberg/trust-region safeguard; same local-optimum risk as now (no global guarantee) | Nocedal & Wright 2006 ch. 4 |
| | `nlminb` (PORT) with gradient + Hessian | 2–4× | bound handling for log σ easier; still R-level f/g calls | Gay 1990 (PORT) [cite needed] |
| | Laplace (glmmTMB) | 1 vs 20 node evals per cluster | biased at cluster size 2 (audit row C) — worse | Joe 2008 *CSDA*; Pinheiro & Chao 2006 *JCGS* |
| Weighted (Bayesian-bootstrap) replicates of ZIP/ZINB/hurdle-P/hurdle-NB/hurdle-GLMM via glmmTMB | **glmmTMB per replicate (current)** | baseline: TMB object construction dominates (tens of ms) + nlminb | different optimizer than the point estimate (C++ L-BFGS/Newton) ⇒ on a nonconcave mixture the replicate can land on a different local optimum than the estimator it is resampling; heavy; `parallel=num_cores` inside an already-parallel replicate loop risks oversubscription | Brooks et al. 2017, *R Journal* (glmmTMB) |
| | Weighted variants of the existing C++ kernels (ZIP/ZINB/hurdle-NB; the hurdle-Poisson-GLMM weighted score/Hessian/NLL already exist) | 10–100× per replicate (theoretical) | implementation cost (weights in 3–4 kernels); still nonconcave (B-row EM/multistart concerns unchanged) | — |
| | EM-then-Newton (row B) | robustness, not speed | tracked | Lambert 1992 *Technometrics* |
| Weighted Mann–Whitney/JT superiority (ordinal_jonckheere_terpstra_test.R:141) | **all-pairs `outer()` (current)** | baseline O(n_T n_C) time & 3×8·n_T n_C bytes | at n=2000, B=1000: ~10⁹ flops and ~24 MB transient per replicate | — |
| | category tabulation: weighted counts per level, cumulative control mass below each level | O(n + K) — ~10³× at n=2000 | none: exact same sum (floating-point order differs ~1e-15); K levels assumed (it is ordinal) | Lehmann 1975 *Nonparametrics* (tie-corrected U as category sums) |
| | sort-merge for continuous y | O(n log n) | unnecessary for ordinal | — |
| Interval-censored NPMLE (Turnbull) in km_diff/rmst/ictest | **self-consistency EM via `interval::icfit` defaults (current)** | baseline: linear convergence; can need 10³–10⁴ iterations when mass sits on few intervals | slow; maxit/eps stopping may leave it short of the KKT point | Turnbull 1976 *JRSS-B*; Fay & Shaw 2010 *JSS* |
| | ICM (iterative convex minorant) | superlinear-ish in practice | not monotone without line search; can stall | Groeneboom & Wellner 1992 (book); Jongbloed 1998 *JCGS* |
| | **EMICM hybrid** (alternate EM and ICM steps) | typically 10–100× fewer iterations than EM | needs Icens (Bioconductor) or own implementation; NPMLE masses not always unique ⇒ functionals (median midpoint) can differ when the likelihood is flat — Prototype, not Adopt | Wellner & Zhan 1997 *JASA* |
| | Warm start from the pooled NPMLE support/masses (per-arm or per-draw fits) | 2–10× fewer EM iterations | must reset support (Turnbull intervals differ per subset) | — |
| | Reuse pooled NPMLE for label-invariant score tests (log-rank1 / wmw at δ=0) | r× (one NPMLE instead of r) | only valid for statistics whose NPMLE is computed on pooled data and whose dependence on labels is linear (exactly ictest's scores); not for per-arm functionals (KM-median diff, RMST) | Fay & Shaw 2010 (ictest's own permutation methods do this) |
| Semiparametric PH under interval censoring SE (icenReg ic_sp, bs_samples=200) | **bootstrap SE inside ic_sp (current)** | baseline: 201 fits per SE | slow; adds its own RNG draws (reproducibility depends on seed state) | Anderson-Bergman 2017 *JSS* |
| | Profile-likelihood / numerical-Hessian of profile log-lik for β | ~10–50 fits instead of 200 | requires a profile maximiser (baseline re-fit per β); theory established for sieve/EM approaches | Zeng, Mao & Lin 2016 *Biometrika* (semiparametric transformation, interval-censored) |
| | Spline-sieve EM (Poisson augmentation) with Louis/profile SE | one fit + SE | different estimator (sieve), new implementation | Wang, McMahan, Hudgens & Qureshi 2016 *Biometrics* [cite needed — verify authors] |
| | parametric Weibull AFT (EDI already has `fast_weibull_regression_general_cpp`) | 10²–10³× | different model (parametric), not a drop-in | — |
| Cloglog cumulative-link null refits (ordinal_cloglog.R) | **2-start, keep lower NLL (current)** | 2× refits | papers over a solver failure | — |
| | Newton on the direct (α, β) parametrization with ordered-threshold safeguard | 1× refit | concavity (Pratt 1981) holds in (α,β) for log-concave F (logit, probit, cloglog; **not** cauchit) but not in the exp-increment threshold parametrization the kernels appear to use — if stalls persist, they are parametrization/line-search artefacts | Pratt 1981, *JASA* |
| Weighted KM median (km_diff.R:373) | **R loop with repeated tail sums (current)** | O(n·D) | — | — |
| | reverse cumsum of sorted weights, single pass; or `survfit(weights=)`+`quantile` (as rmst.R already does) | O(n log n) | survfit's median convention (midpoint rule on flat 0.5) must match the custom rule at :~400 to stay identical | Kaplan & Meier 1958 *JASA* |
| Randomization nulls for classes without C++ batch kernels (Lin, KK OLS, quantile, robust, PPO, KK hurdle, ZA, KK quantile) | **RW-loop: full R estimator per draw (current)** | baseline r × (R overhead ~0.1–1 ms + fit) | R overhead dominates for cheap fits (OLS/Lin: fit ≈ µs–tens of µs, overhead ≫ fit) | — |
| | C++ batch kernel per family (pattern already used by `compute_poisson_distr_parallel_cpp`, `compute_bai_distr_parallel_cpp`) | 10–100× for linear models; ~1–2× for expensive fits | per-class implementation cost; must replicate hardening/column-dropping exactly or results diverge | — |
| | Sequential MC stopping (Besag–Clifford) | data-dependent, large when p far from α | tracked elsewhere | Besag & Clifford 1991 *Biometrika*; performance_profiling_and_upgrades.md TODO-156 |

### New TODO candidates
1. **JT weighted superiority by category tabulation** — `inference_ordinal_jonckheere_terpstra_test.R:141 weighted_superiority`: replace `outer()` (O(n_T n_C), 3 dense matrices) with weighted per-level counts + cumulative control mass (mirrors the unweighted code at :~170). Win (theoretical): O(n_T n_C) → O(n+K), ~10³× at n=2000 per Bayesian-bootstrap replicate, and removes ~24 MB/replicate allocation. Risk: none beyond FP summation order. Deterministic drop-in (Adopt); gate = existing tests.
2. **Weights in the C++ conditional-Poisson combined Newton kernel** — `inference_count_KK_cond_poisson.R:2029 compute_weighted_combined_estimate`: drop R `optim(BFGS)` on R-coded NLL/score; call `fast_cpoisson_combined_with_var_cpp` with pair/reservoir weights. Win (theoretical): 10–50× per replicate. Risk: low — objective strictly concave so same optimum to tolerance. Deterministic drop-in (Adopt) after adding the weights argument.
3. **Weighted C++ kernels for ZIP/ZINB/hurdle-NB/KK-hurdle-GLMM Bayesian-bootstrap replicates** — `inference_count_zero_augmented_poisson_abstract.R:126/990`, `inference_count_hurdle.R:400`, `inference_count_KK_cond_poisson.R:149/373`: replace per-replicate glmmTMB with weighted versions of the C++ kernels already used for the point estimate. Win (theoretical): 10–100× per replicate; also makes replicate and point estimate share one optimizer (removes a local-optimum mismatch on nonconcave mixtures). Risk: nonconcavity unchanged; needs A/B harness (replicate distributions will change slightly). Prototype.
4. **Trust-region Newton for the KK hurdle-Poisson one-lik fit** — `inference_count_KK_cond_poisson.R:1111 fit_combined_hurdle`: use the analytic `combined_hurdle_hessian` (already computed post-hoc) in a damped Newton/trust-region instead of R BFGS (and fix the no-op `newton_raphson ? "BFGS" : "BFGS"` ternary at :1173). Win (theoretical): 2–5× fewer iterations; better σ-direction convergence. Risk: indefinite Hessian far from optimum (needs safeguard); A/B harness.
5. **Reuse the pooled NPMLE for interval-censored log-rank/Wilcoxon randomization tests** — `inference_survival_log_rank.R:237`, `inference_survival_gehan_wilcox.R:251` (fast path returns NULL at log_rank.R:185): compute `ictest` scores once on pooled (L,R) (label-invariant at δ=0; rand CI is unsupported for these classes anyway) and evaluate the linear statistic for every permutation as one `t(W) %*% c` (or a C++ kernel). Win (theoretical): r× fewer NPMLE solves (r=501 ⇒ ~500×). Risk: must reproduce exactly the statistic `ictest` returns as `estimate` (verify on fixtures). Deterministic for δ=0 ⇒ Adopt after an equivalence check.
6. **Linear-time weighted KM median** — `inference_survival_km_diff.R:373 weighted_km_median`: reverse-cumsum of sorted weights instead of `sum(row_weights[i:n])` per time; preallocate instead of `c()`. Win (theoretical): O(n²) → O(n log n) per Bayesian-bootstrap replicate. Risk: FP order only. Adopt.
7. **Faster Turnbull NPMLE** — `helper_inference_survival_turnbull.R:29` (used by km_diff.R/rmst.R, and implicitly by `interval::ictest`): pass an EMICM initial fit / warm start (interval's `icfit` exposes an `initfit` hook; exact option to verify) or own EMICM. Win (theoretical): 10–100× fewer iterations; matters most for RMST icen SE (B × 2 NPMLEs) and icen randomization loops. Risk: NPMLE mass non-uniqueness can move the median midpoint ⇒ A/B harness. Prototype.
8. **Closed-form score/gradient/LR CIs and exact LR test for the Gaussian linear classes** — `inference_continuous_lin.R:396`, `inference_continuous_KK_ols_one_lik.R:290` (and OLS `continuous_ols.R:352` likewise): with σ² fixed in the spec, every bound is β̂ ± z·σ̂√[(X'X)⁻¹]_jj and the param-bootstrap LR null is exactly F(1,n−p). Win: ~10–20 refits → 0 per CI; param bootstrap → 0. Risk: none if the reported quantities are kept identical. Adopt (existing CI tests gate it).
9. **C++ batch randomization kernel for Lin and KK OLS** — `continuous_lin.R:206`, `continuous_KK_ols_one_lik.R:185`, `continuous_KK_ols_ivwc.R:88` (and the B-loop in `compute_rand_bootstrap_ci_affine_coefs` ols.R:222 / lin.R:216): mirror `compute_rand_bootstrap_ols_parallel_cpp`. Win (theoretical): 10–100× (R overhead dominates µs-scale fits). Risk: must reproduce `reduce_design_matrix_*` column dropping exactly. Deterministic; Prototype-level effort, Adopt-level validation (identical results).
10. **Investigate aftsrr `se = "ISMB", B = 0`** — `inference_survival_KK_rank_regr_ivwc_abstract.R:286/300/330/344`: in aftgee, B is the number of multiplier resamples for ISMB; with B = 0 the SE may be absent ⇒ every rung of the 13-rung design ladder is fitted and rejected. Verify by reading `aftgee::aftsrr` source; if confirmed, set B (e.g. 100) or use the closed-form sandwich of the smoothed equations. Investigate.

### Incidental findings (optional)
- **Estimand mismatch in KK ordinal Bayesian bootstrap**: `inference_ordinal_KK_clmm_abstract.R:169` and `inference_ordinal_KK_combined.R:460` (KKGLMM) compute weighted replicates with a *fixed-effects* cumulative-link fit (no random intercept) while the point estimate is the conditional (RE) log-OR from `fast_ordinal_{clmm,glmm}_cpp`; conditional coefficients exceed marginal ones in magnitude (attenuation), so the Bayesian-bootstrap CI is centred on a different estimand. The KKGEE class already disables Bayesian bootstrap for the analogous reason (KK_combined.R:142).
- `inference_ordinal_KK_clmm_abstract.R:162,309`: `eps_g = 1e-3` gradient tolerance for the CLMM C++ fit — loose relative to other kernels (1e-6); affects estimate precision in randomization draws.
- `inference_ordinal_KK_clmm_abstract.R:391/419`: `use_rcpp = FALSE` fallbacks are `ordinal::clmm` (default Laplace, nAGQ = 1) and then `ordinal::clm` (drops the random effect) — two different estimands from the GH C++ fit.
- **KK hurdle-Poisson IVWC randomization statistic**: `inference_count_KK_cond_poisson.R:206` uses dummy SEs (1.0) when `se = FALSE`, so the per-draw statistic is the *equal-weight* average of matched and reservoir estimates, not the IVWC estimate reported by `compute_estimate()`. Valid as a test (observed and null use the same rule) but not the documented statistic and likely less powerful. Same dummy-SE pattern in `compute_estimate_with_bootstrap_weights` at :149 when `estimate_only = TRUE`.
- **KK robust regression randomization uses Huber "M" while the reported estimate is "MM"** (`inference_continuous_KK_robust_regr_one_lik.R:240`, `_ivwc.R:248`; documented): randomization p-value tests a different estimator than the point estimate; `maxit` 10–20 with `acc` 1e-4 means truncated IRLS in null draws.
- **Cox tie-handling audit (row L):** v1.0.5 TODO-69 resolved the two
  point-estimate fallbacks: `use_rcpp = FALSE` at `coxph.R:641` and the
  stratified formula helper at `strat_cox.R:52` now explicitly use Breslow.
  `weighted_cox_bootstrap_surrogate_fit` at `globals.R:281` still calls
  `survival::coxph` without `ties`, and therefore uses Efron; it is a separate
  bootstrap-surrogate route that was not one of TODO-69's two fallback calls
  and remains an existing **Investigate** item in this catalog's resampling-harness
  table rather than a completed TODO-69 subtask.
- `inference_survival_coxph.R:109/136/153`: pure-R Breslow NLL with O(n·D) risk-set rescans plus FD score (2p calls) and FD information (~2p² calls) — no callers found outside `contracts_mixins.R:999-1001`; dead code or a contract stub. Delete or replace with analytic reverse-cumsum versions.
- `inference_ordinal_jonckheere_terpstra_test.R:~180`: asymptotic SE uses the **no-ties** variance n_T n_C (N+1)/12; for ordinal data the tie-corrected variance is smaller by factor 1 − Σ(t³−t)/(N³−N) (≈0.89 for 3 equal categories, 0.75 for 2) ⇒ conservative Wald p-values/CIs.
- `inference_survival_dep_cens_transform.R:363`: if the percentile-bootstrap CI excludes 0 but the Wald CI includes 0, the Wald CI is substituted; plus a hard \|bound\| > 2 ⇒ NA rule. Data-dependent CI selection that always favours non-rejection — coverage/size properties of the composite procedure are not those of either CI.
- O(n·m) pair loops with `which(m_vec == pid)` inside a loop over pairs: `inference_count_KK_cond_poisson.R:1820` (`build_combined_cpoisson_data`, called per bootstrap replicate via :2029), `inference_ordinal_paired_sign_test.R:160`; `inference_survival_strat_cox.R:42` (per stratum). `.complete_pair_index_matrix` (helper_matching.R) / `split()` gives O(n).
- `inference_survival_KK_lwa_cox_ivwc_abstract.R:162 cox_design_candidates` is not cached (the rank-regression twin caches by key): 12× `drop_highly_correlated_cols` + QR per call, per replicate.
- Per-observation R sampling loops in `simulate_under_lik_null` (`ordinal_adj_cat_logit.R:260`, `ordinal_stereotype_logit.R:971`, `ordinal_KK_combined.R:766`): vectorisable inverse-CDF (`rowSums(cumP < runif(n)) + 1`) — note it changes the RNG stream (one runif per obs vs `sample.int`), so reproducibility of seeded param-bootstrap results would change.
- `glmmTMBControl(parallel = self$num_cores)` inside per-replicate fits (`count_KK_cond_poisson.R:~386`, `count_hurdle.R:~420`) when the replicate loop itself is parallel ⇒ potential thread oversubscription.
- Out-of-group but adjacent: `inference_proportion_quantile_regr.R:236` uses `rq.fit(method = "fn")` for estimate-only (randomization draws) but default `"br"` for the full and weighted fits (:129, :249) — observed statistic and null draws from different LP solvers; with non-unique solutions they can differ.

---

## 11. R — inference classes: incidence, proportion, mixins, misc


Scope: 44 files in `R/EDI/R/inference_*.R` (incidence_*, indicidence_*, incid_*, proportion_*, mixin_*, rand_*, suite, helpers_zhang, custom_extensions, class_registry). All paths below are relative to `R/EDI/R/` unless they name `src/`. Read-only sweep; nothing compiled or run.

Key negative finding up front: **no unconditional exact test (Barnard / Boschloo / Suissa–Shuster / Chan–Zhang) exists anywhere in EDI** (grepped R/ and src/). Every "exact" incidence path is *conditional* (Fisher noncentral hypergeometric, conditional binomial on discordant pairs, exact CMH convolution). So the nuisance-parameter-maximization question (grid vs Berger–Boos restriction) is moot today. It is recorded in the options table as a feature gap, not as a swap.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| inference_indicidence_exact_fisher.R:121 `get_exact_fisher_htest` (single stratum) | Exact conditional test, CI, and CMLE for the 2x2 odds ratio | `stats::fisher.test` 2x2 branch: direct enumeration of the noncentral-hypergeometric pmf over the support (`dnhyper`), "minlike" two-sided p-value (sum of pmf ≤ observed·(1+1e-7)). CMLE and conditional CI come from `uniroot` (Brent) on the pnhyper mean and tails. This is not the Mehta–Patel network algorithm: FEXACT is only used for r×c tables larger than 2x2. | O(S) per p-value, S = min margin ≤ n; CI ≈ 2×(10–30) Brent evals × O(S) | NEW-exact-conditional-2x2 | Keep |
| same :121 (K strata: blocks, or KK pairs plus the reservoir as one stratum) | Exact stratified conditional test of OR = 1, plus the exact conditional CI | `stats::mantelhaen.test(exact=TRUE)`: exact distribution of Σ_k n11k by convolving the K hypergeometric pmfs; CI via `uniroot` on the convolved noncentral distribution. Only δ0 = 0 is supported (stops otherwise). | O(K·S_tot) to O(K·S_tot²) convolution; KK pairs have per-stratum support ≤ 2, so in practice it costs about O(K²) | NEW-exact-conditional-2x2 | Keep |
| same :172/:190 `build_exact_fisher_tables_blocking/_kk` | Build the strata tables | Blocking: R `vapply` + `paste` key per row, then `split`. KK: `for (match_id) which(m_vec == match_id)` | Blocking O(n·\|strata_cols\|); KK O(n·m) = O(n²) | glue | Keep (implementation note below) |
| inference_incidence_exact_binomial.R:116 `pval_exact_binomial` → `zhang_exact_binom_pval_cpp` (src/zhang_exact_speedups.cpp:95) | Exact matched-pair (exact McNemar) test of the conditional log-OR δ0 | Conditional binomial on discordant pairs, d+ ~ Bin(d, expit δ0); minlike two-sided sum over 0..d | O(d) | NEW-exact-conditional-2x2 | Keep |
| same :127 `ci_exact_binomial` | Exact CI for the matched-pair conditional log-OR | `binom.test` Clopper–Pearson (closed-form `qbeta`), then `qlogis` | O(1) | NEW-exact-conditional-2x2 | Keep (the p-value and CI use different two-sided conventions; see incidental findings) |
| inference_helpers_zhang.R:173 `zhang_pval_exact_combined` + :16 `zhang_combine_exact_pvals` (+ src/zhang_exact_speedups.cpp `fisher_noncentral_two_sided_pval`) | Exact test for KK designs: matched pairs (binomial) combined with reservoir (noncentral-hypergeometric Fisher) | Two independent exact p-values combined by Fisher χ²₄ (default), Stouffer, or min-p (1−(1−p)²) | O(d + S) | NEW-pvalue-combination | Investigate. Fisher's χ²₄ reference assumes continuous U(0,1) p-values, so with discrete exact p's the combination is conservative. The exact joint distribution is cheap to enumerate (see options). |
| inference_helpers_zhang.R:44 `zhang_bisect_ci_boundary`, :205 `zhang_ci_exact_combined`, :180 `zhang_compute_ci_bounds_parallel` | CI by inverting the combined exact p(δ) | R-level bisection, at most 50 iterations, stopping when \|p−α\| < `pval_epsilon` (**default 0.005**) or the bracket is < 1e-8. Bracket = Wald CI at level **2α** ± 0.5·width; never checked to bracket the root. num_cores > 1 forks 2 workers via `duplicate()` | ~5–15 evals/bound × O(d+S); fork overhead ≫ the work | M (deterministic CI inverter) | Adopt-with-caveat (precision and correctness gain, not speed; see TODO-2) |
| inference_incidence_newcombe_univ.R:121 → `newcombe_independent_ci_cpp` (src/newcombe_speedups.cpp); :142 `compute_asymp_two_sided_pval` | Newcombe hybrid-score (Wilson) RD CI, and the p-value obtained by inverting it | CI closed form. p-value: `stats::uniroot` (Brent) over α ∈ (1e-10, 1−1e-10) of CI_bound(α) − δ | CI O(1); p ≈ 10–15 closed-form evals | M | Keep (already Brent) |
| inference_incidence_miettinen_nurminen_univ.R:139/:155 → `mn_ci_cpp`/`mn_pvalue_cpp` (src/miettinen_nurminen_speedups.cpp) | Miettinen–Nurminen score CI and p-value for RD | C++: score p-value with the constrained MLE; CI by **bisection** on p (comments at :14–:184 of the cpp) | ~20–40 closed-form evals/bound | M | Keep-tracked (brent_ci_inversion.md: extend its scope to `mn_ci_internal`; C++ side cataloged elsewhere) |
| inference_incid_wald.R:99 `compute_incidence_wald_components` | Unpooled Wald SE for RD | closed form | O(n) | — | Keep |
| inference_incidence_cmh.R:152 `get_standard_error` (non-blocking branch) | Design-based variance of τ̂ = (2/n)y'w | **Monte Carlo**: draw K = `se_est_num_vectors` = 5000 assignment vectors from the design (or a design-precomputed matrix), then SE = (2/n)·sqrt(mean((y'w)²)) | O(nK) flops plus K design draws; consumes the RNG stream | NEW-design-variance-MC | Prototype (closed form for CR/BCRD/Bernoulli/blocked; keep MC only for sequential designs; TODO-3) |
| inference_incidence_cmh.R:160, inference_incidence_extended_robins.R:106 → `compute_cmh_block_se_cpp`, `compute_extended_robins_block_se_cpp` (src/cmh_speedups.cpp) | Block-design variance for RD | closed-form within-block moments | O(n) | — | Keep |
| inference_incidence_KK_newcombe_ivwc_univ.R:123 `shared_combined` | KK RD: pairs plus reservoir | Wald paired variance (p10+p01−(p10−p01)²)/m and Wald unpooled reservoir variance, pooled by IVW. **Not Newcombe** despite the class name | O(n) | — | Keep (legacy IVWC; see incidental findings) |
| inference_incidence_KK_cond_logit.R:344 `shared_combined_likelihood` + :1 `conditional_logit_prepare_combined_design` (→ `build_matching_combined_clogit_design_cpp`, `collect_discordant_pairs_cpp`) | Conditional-logit MLE for 1:1 pairs plus unconditional logit for the reservoir, with a shared β_T | Uses the exact identity "1:1 conditional logit = no-intercept logistic on within-pair differences of discordant pairs", stacked with the reservoir rows, then `fast_logistic_regression[_with_var]_cpp` (Newton/IRLS or L-BFGS per `optimization_alg`) inside `fit_with_hardened_qr_column_dropping` | O(n p²) per Newton iteration | A | Keep |
| same :52 `conditional_logit_weighted_combined_estimate` (Bayesian bootstrap), :541 `simulate_under_lik_null` (parametric-bootstrap LR) | Per-replicate refits | BB: weighted logistic per replicate, warm-started. PB: `rbinom` y*, one full refit, then warm-started constrained null refits | B × O(n p² · iters) | J / A | Keep (J tracked in the audit; implementation note on :61) |
| same :817 `IncidKKCondLogitIVWC$shared` | Separate logistic fits on pairs and reservoir, then IVW pooling | 2× `fast_logistic_regression_with_var_cpp` | O(n p²) | A | Keep (legacy) |
| inference_incidence_KK_cond_logit_glmm_abstract.R:197 `shared` → `fast_clogit_plus_glmm_cpp` (src/fast_clogit_plus_glmm.cpp:659); inference_incidence_KK_cond_logit_glmm.R (the two concrete classes differ only by `combine_reservoir_into_glmm`) | Joint likelihood: clogit on discordant pairs plus a random-intercept logistic GLMM on concordant pairs (± reservoir) | 20-node Gauss–Hermite per group + L-BFGS | O(G·n_gh·p) per objective eval | C | Keep-tracked (performance_profiling_and_upgrades.md TODO-153, AGQ) |
| inference_incidence_KK_cond_logit_glmm_abstract.R:103 `compute_estimate_with_bootstrap_weights` | Bayesian-bootstrap replicate of β_T | **`glmmTMB::glmmTMB`** random-intercept logistic on *all* rows (Laplace approximation, TMB autodiff + `nlminb`). This is a different model (no conditional-logit block) and a different integration rule from the point estimate | B × (TMB tape build + Laplace inner Newton) ≫ C++ kernel cost | C | Investigate (estimator mismatch, TODO-4) |
| inference_incidence_KK_marginal.R:311 `InferenceAbstractKKModifiedPoisson$shared`, :23 BB path (classes `InferenceIncidKKModifiedPoisson`; abstract in inference_incidence_KK_marginal_abstract.R is glue) | KK marginal RR/RD via modified Poisson (Zou 2004) with a pair-cluster sandwich | `fast_poisson_regression[_weighted]_cpp` (IRLS) + `glm_cluster_sandwich_post_fit_cpp` | O(n p²)/iteration + O(n p²) sandwich | A + K-style sandwich | Keep |
| inference_incidence_gcomp_abstract.R:843 `shared`, :602 `fit_logistic_with_sandwich` (→ `gcomp_logistic_post_fit_cpp`), :690 `compute_standardized_effects_r`; inference_incidence_gcomp.R (`InferenceIncidGCompRiskDiff/RiskRatio`, glue); inference_incidence_KK_gcomp_abstract.R:772/:532 (→ `gcomp_logistic_cluster_post_fit_cpp`, classes `InferenceIncidKKGCompRiskDiff/RiskRatio` defined in inference_incidence_KK_marginal.R:404/:489) | Logistic g-computation (standardization) of RD/RR, with a delta-method sandwich SE | One logistic fit (C++ Newton; `glm.fit` IRLS on the non-hardened estimate-only path). Then a plug-in average over n rows of expit(X1β), expit(X0β), and an analytic gradient times the robust vcov. The `repeat` loop drops the largest-\|coef\| covariate and refits until coefficients are ≤ 25 in absolute value | O(n p²·iters) + O(n p) standardization + O(p²) delta method; worst case p refits | A (+ NEW-gcomp-standardization) | Keep |
| same :514 `weighted_gcomp_fit` (BB), :285–:490 RR resampling helpers | Per-replicate g-comp | Weighted logistic per replicate (warm-started, column-drop loop) then standardization; RR CIs on the log scale | B × fit | J | Keep (see the incidental BB-weighting finding) |
| inference_incidence_logit.R:265, inference_incidence_probit.R:242, inference_incidence_modified_poisson.R:320, inference_incidence_log_binomial.R:357, inference_incidence_binomial_identity.R:264, inference_incidence_risk_diff.R:289 `generate_mod` (+ `compute_estimate_with_bootstrap_weights`, `simulate_under_lik_null` in each) | GLM MLE for treatment effect on logit/probit/log/identity link; OLS LPM with HC0 | All delegate to C++: `fast_logistic/probit/poisson/log_binomial/identity_binomial_regression[_with_var/_weighted]_cpp` (Newton/IRLS/L-BFGS; log-binomial uses IRLS with backtracking and clamping), `fast_ols[_with_var]_cpp`. R adds the QR column-drop retry, `solve(fisher_information)` for the BB vcov, and a `rbinom` parametric bootstrap | O(n p²)/iteration; PB B × (1 + k) refits | A (log-binomial/identity: constrained, see options) | Keep (C++ cataloged elsewhere) |
| inference_incidence_log_binomial.R:252 `compute_gradient_confidence_interval_impl` → `invert_gradient_ci_uniroot` (inference_ext_ci_inversion.R:119), fallback `invert_lik_ratio_ci_newton` | Gradient-test CI for the log-RR | `uniroot` (Brent); falls back to LR Newton when one side is infeasible | ~5–10 constrained refits/bound | M | Keep (already Brent) |
| inference_proportion_beta.R:566 `generate_mod`, :237 BB, :468 PB; inference_proportion_fractional_logit.R:248, :168 | Beta regression MLE; fractional-logit QMLE (Papke–Wooldridge) | `fast_beta_regression[_with_var/_weighted]_cpp` (L-BFGS/IRLS); fractional logit via `fast_logistic_regression_cpp` on y ∈ [0,1] (`glm.fit(quasibinomial)` IRLS on one estimate-only path). PB draws `rbeta`. The BB fallback `lm.wfit` on logit(y) is a different estimator | O(n p²)/iteration | A | Keep |
| inference_proportion_gcomp.R:530 `fit_fractional_logit_with_sandwich`, :763/:808 effects, :700 `resolve_effect_variance`, :675 `finite_difference_md_gradient`, :640/:653 eigen-stabilized vcov/inverse | Fractional-logit g-comp mean difference with a delta-method SE and a fallback ladder | C++ logistic QMLE + `gcomp_fractional_logit_post_fit_cpp`. Variance ladder: analytic gradient × robust vcov, then eigen-floored vcov, then model-based vcov, then central-FD gradient (2p standardizations), then stronger clipping | O(n p²) fit; FD fallback O(n p²); eigen O(p³) | A + NEW-gcomp-standardization | Keep (FD only fires when the analytic path fails) |
| inference_proportion_gcomp.R:312 `approximate_bootstrap_distribution_beta_hat_T`, :821 `bootstrap_sample_is_usable`, :894 `bootstrap_fit_from_sample` | Nonparametric bootstrap of the g-comp MD | i.i.d. resample with **rejection** of "unusable" resamples (boundary mass ≥ 0.95, groups < 5, separation) up to `max_resample_attempts`, then a C++ refit per replicate, chunked `par_lapply` | B × attempts × O(n p²) | J | Keep-tracked (J); the rejection is a statistical choice (see incidental findings) |
| inference_proportion_quantile_regr.R:233 `fit_quantile_model`, :114 BB path, helper_matching.R:172 `.extract_se_from_rq_fit` | τ-quantile regression on logit(y) | `quantreg::rq.fit(method="fn")` (Frisch–Newton interior point) for the point fit. **The BB path uses `quantreg::rq()` with the default `method="br"`** (Barrodale–Roberts simplex). SE from `summary.rq(se="nid")` (Hendricks–Koenker sandwich), else `"iid"` | fn: O(n p²·√n-ish) iterations; br: fast at n ≲ several thousand | NEW-quantile-LP | Prototype (pick one LP method for both paths; TODO-6) |
| inference_proportion_KK_quantile_regr_ivwc.R, inference_proportion_KK_quantile_regr_one_lik.R | KK τ-quantile regression | Thin wrappers over the `KKQuantileRegrIVWC`/`KKQuantileRegrOneLik` components (`.init_kk_quantile_regr_ivwc`, defined outside this group) | — | NEW-quantile-LP | Keep here (algorithm cataloged with the component owner) |
| inference_proportion_zero_one_inflated_beta.R:657 `generate_mod` → `fast_zero_one_inflated_beta_cpp` (src/fast_zero_one_inflated_beta.cpp:76 objective) | ZOIB MLE | **Joint** L-BFGS/Newton over [β(p), log φ, γ0(q), γ1(q)] with multistart cold starts (audit row B treats it as a nonconcave mixture). But the C++ objective is `−Σ log softmax(0/1/mid; γ0, γ1)` (mid is the baseline) **plus** a beta log-likelihood on the mid rows in (β, φ): **fully separable, with a block-diagonal Hessian and no latent class**, because membership in {0}, {1}, (0,1) is observed | O(n(p+2q)) per eval × iterations over dimension p+1+2q | NEW-separable-likelihood (mis-filed under B) | Adopt (split into a multinomial logit plus a beta regression; identical MLE; TODO-1) |
| inference_proportion_zero_one_inflated_beta.R:242 BB path, :738 `simulate_under_lik_null` | ZOIB BB replicate / parametric bootstrap | BB: γ0, γ1 from two separate binary logits, β from `betareg::betareg` (BFGS via `optim` + Fisher scoring), fallback `lm.wfit`. PB: R `for (i in 1:n)` loop calling `rbeta(1)` per row, with mixing probabilities computed as **plogis-then-normalize** | BB: betareg per replicate; PB: O(n) interpreted loop | NEW-separable-likelihood | Investigate (the parameterization does not match the C++ softmax; see incidental findings) |
| inference_proportion_KK_combined.R:123 `InferencePropKKGLMM` (inherits the KK clogit+GLMM abstract), :208 PB | KK proportion "clogit+GLMM" | Same `fast_clogit_plus_glmm_cpp` (GH20 + L-BFGS); PB draws **Bernoulli** y* for disc/conc rows | as row C above | C | Investigate (a Bernoulli parametric bootstrap for a fractional response; see incidental findings) |
| inference_incidence_KK_combined.R:33 `InferenceIncidKKGEE`, inference_proportion_KK_combined.R:34 `InferencePropKKGEE` → inference_mixin_kk_gee_shared.R:541 `fit_gee_on_data` (→ `gee_pairs_singletons[_weighted]_cpp`, fallback `geepack::geeglm` exchangeable) | GEE with exchangeable correlation, pairs + singletons | C++ moment-based GEE (Liang–Zeger), with a fallback cascade over predictor candidates (:302, QR reduction + 12 correlation-drop thresholds) × {with, without reservoir} | Worst case ~26 GEE fits per call; candidate generation O(12·n p²) per call | K | Keep (cascade cost is an implementation note) |
| inference_mixin_kk_glmm_shared.R:207 `fit_glmm_on_data`, :24 BB | KK GLMM (continuous/count/ordinal users, not incidence) | `glmmTMB` Laplace (nAGQ = 1 equivalent) + `nlminb`; `glmmTMBControl(parallel = num_cores)` | per fit: TMB tape + inner Newton | C | Keep-tracked (C). Laplace is exact for the Gaussian LMM but biased for small-cluster count GLMMs, the exact concern audit row C raises. Users are outside this group; flagged for the count/ordinal catalog owner |
| inference_mixin_kk_passthrough.R:56 `approximate_bootstrap_distribution_beta_hat_T` (→ `compute_bootstrap_matching_stats_cpp`, src/bootstrap_match_indices.cpp:133) | KK pair-respecting bootstrap | Fast C++ distribution if available; else `replicate(B, draw_bootstrap_indices())` then per-replicate `duplicate()` + C++ match stats + `compute_estimate` | B × (object clone + fit) | J | Keep-tracked (J, balanced bootstrap) |
| inference_mixin_kk_passthrough_compound.R:99 `compute_reservoir_and_match_statistics` | KK compound mean-diff moments | `mean_cpp`/`var_cpp` closed form | O(n) | — | Keep |
| inference_mixin_off_optimum_likelihood_eval.R:92 `evaluate_penalized_neg_loglik_at` | Firth/Jeffreys-penalized objective evaluator (no caller yet) | NLL + 0.5·log\|I\| via `determinant` (LU) | O(p³) | A | Investigate (sign looks wrong; see incidental findings) |
| inference_mixin_cordeiro_ferrari_approx.R, inference_mixin_lemonte_gradient_approx.R | Stubs (flag only) | — | — | glue | n/a |
| inference_rand_custom.R:144 `compute_fast_randomization_distr` | Randomization distribution of a user statistic | R `vapply` over the r columns of `w_mat`, evaluating the user R or Rcpp function with an affine δ shift on treated units; workers recompile from source (`Rcpp::cppFunction`, cached per session) | r × cost(stat) | D/E | Keep (an arbitrary statistic cannot use the affine shortcut, as the comments note) |
| inference_mixin_kk_gee_shared.R:120 `compute_rand_two_sided_pval` | Randomization p-value for the GEE family | Cached-prefix / sequential-MC driver (`compute_two_sided_pval_with_sequential_mc`, defined outside this group); incidence reroutes to Zhang exact | r × GEE fit | E (+ TODO-156 seq-MC) | Keep-tracked |
| inference_suite.R:1429 task loop (`parallel::mcparallel` + `mccollect(wait=FALSE)` polling at 0.2 s, per-task timeout) | Run every (class, method, type) task on `num_cores` | Greedy list scheduling in **build order** (FIFO; sorting at :2126 is for display only) | makespan ≤ (2 − 1/m)·OPT (Graham bound) | NEW-task-scheduling | Prototype (LPT order from the existing CI runtime manifest; TODO-5) |
| inference_suite.R:4011 `cct_combine_pvalues_full` | Cauchy combination test (Liu & Xie 2020) | `sum(w·tan((0.5−p)π))`, then `0.5 − atan(T)/π` | O(k) | NEW-pvalue-combination | Adopt (tail-accurate form; TODO-7) |
| inference_class_registry.R (whole file), inference_custom_extensions.R (whole file), inference_suite.R (everything except the two rows above), inference_incidence_KK_marginal_abstract.R, inference_incidence_gcomp.R alias lists, inference_incidence_exact_zhang.R (dispatch to helpers_zhang) | R6 composition, metadata, capability manifests, report rendering | glue: no algorithmic content (ancestor walks, `sort`/`order` of class names, string formatting) | — | glue | n/a |

### Options & disadvantages

**Exact tests for 2x2 tables and matched pairs** (rows: exact Fisher, exact binomial, Zhang, plus the absent unconditional tests)
| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| 2x2 OR test/CI | **current**: conditional noncentral-hypergeometric enumeration (`fisher.test`), minlike p, conditional CI via `uniroot` | — | Conservative (discreteness); p-value and CI conventions differ (minlike p vs central CI), so they can disagree at the boundary | Fisher 1935; R `fisher.test` docs; Fay 2010, *R Journal* 2(1) |
| 2x2 OR | Mehta–Patel network (FEXACT) | slower for 2x2; only pays off for r×c | No gain for 2x2: the support is already 1-D | Mehta & Patel 1983, *JASA* |
| 2x2 OR | Matching CI (`exact2x2::exact2x2(tsmethod="minlike")`, Blaker CI) | ~same order (more pmf evals for CI inversion) | Adds an external dependency; minlike/Blaker CIs can be non-intervals in rare cases (handled in exact2x2) | Fay 2010; Blaker 2000, *Can. J. Stat.* |
| 2x2 RD/RR, unconditional | Barnard/Boschloo/Suissa–Shuster: sup over nuisance π of the tail probability on a **grid** (e.g. 100–1000 points) | O(G·n_T·n_C) per p; CI by inversion multiplies by ~20–40; **much slower** than conditional (≈10³–10⁵×, theoretical) | Not implemented in EDI. A grid can miss the supremum (anti-conservative), so it needs a fine grid or a refinement step | Barnard 1947, *Biometrika*; Boschloo 1970, *Stat. Neerl.*; Suissa & Shuster 1985, *JRSS-A* |
| same | **Berger–Boos**: restrict the nuisance sup to a (1−γ) CI for π and add γ (γ ≈ 1e-3 to 1e-6) | 2–10× fewer nuisance evals than the full-range grid; still a grid inside the restricted range | Adds γ to p (slightly conservative); still needs an inner grid plus local refinement | Berger & Boos 1994, *JASA* 89 |
| same | Chan–Zhang test-based exact CI for RD (score statistic ordering + nuisance sup) | expensive (sup per candidate δ) | Same grid issue; widely used in trials (StatXact default); CI can be wide at small n | Chan & Zhang 1999, *Biometrics* 55 |
| same | Exact unconditional with E+M ordering (Lloyd) | one sup per test, using an estimated-p ordering | Implementation cost; known to dominate plain Barnard in power | Lloyd 2008, *Biometrics* [cite needed for exact title] |
| matched pairs | **current**: conditional binomial on discordant pairs (exact McNemar) | — | Ignores concordant pairs (by design; conditional) | McNemar 1947; Breslow & Day 1980 |
| matched pairs | Unconditional exact McNemar (sup over nuisance discordance rate) | ≫ slower (grid over nuisance) | Same grid caveats; modest power gain | Suissa & Shuster 1991 [cite needed for venue] |
| KK combination | **current**: Fisher χ²₄ / Stouffer / min-p on two exact p's | — | All three treat discrete p's as continuous; Fisher's is conservative | Lancaster 1949, *Biometrika* 36 |
| KK combination | **Exact joint convolution**: the pairs and reservoir statistics are independent under H0 with known exact pmfs (binomial × noncentral hypergeometric), so P(combined stat ≥ obs) can be enumerated exactly over the (d+1)×(S+1) grid | O(d·S), still µs–ms at EDI sizes; an extra cost of O(d·S) vs O(d+S) | Changes the reported p (it is the exact size-α test the combination intends), so the CI tests' expected values move. Ordering for Fisher-combination ties needs a convention | standard (convolution of independent exact nulls); Lancaster mid-p as a cheaper alternative |

**Deterministic CI inversion of exact p(δ)** (row `zhang_bisect_ci_boundary`)
| problem | option | speed (theoretical) | disadvantages | citation |
|---|---|---|---|---|
| root of p(δ) = α | **current**: bisection, stop when \|p−α\| < 0.005 (p-space) or width < 1e-8; bracket = Wald(2α) ± 0.5w, never validated | ~5–15 evals | Bound error is uncontrolled in δ-space (0.005 in p at α = 0.05 is 10% relative). If the true bound lies beyond the bracket the CI is silently truncated at the bracket. Eval errors map to p = 0, which biases toward the inside | — |
| same | `uniroot` (Brent) in δ-space, tol 1e-8, with bracket expansion (`extendInt="yes"`) | ~8–15 evals to a 1e-8 δ-tolerance (vs bisection ~30 for the same tolerance), each eval O(d+S) | Exact minlike p(δ) can be non-monotone (Fay 2010). With several crossings Brent and bisection may land on different crossings, so this is "identical within tol" only when the root in the bracket is unique | Brent 1973 |
| same | Matching exact CI (invert the same minlike test via the exactci/exact2x2 algorithm, which handles non-monotonicity) | similar | Dependency, or porting the algorithm | Fay 2010, *R Journal* |
| same | Keep bisection, drop the 2-worker fork | removes fork/duplicate overhead (ms) for µs work | None | — |

**CMH design-based variance** (row `inference_incidence_cmh.R:152`)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| Var_w(y'w) under the design | **current**: MC over K = 5000 draws | O(nK) | MC noise ≈ 1/√(2K) ≈ 1% relative in the SE; consumes the RNG stream, so results depend on seed and call order | — |
| same | Closed form from the design's second moments. Complete randomization with fixed n_T = n/2 (±1 coding): Var = n/(n−1)·Σ(y−ȳ)². Bernoulli(½): Σy². Blocked/BCRD: sum of within-block versions | O(n), ~5000× fewer flops (theoretical); deterministic | Only for designs with known E[ww']. Sequential/KK/Efron designs still need MC (or an exact E[ww'] if available) | Imbens & Rubin 2015 (ch. 6, Neyman variance); standard permutation moments |
| same | MC with antithetic draws (w, −w) | 2× variance reduction at fixed K | For balanced ±1 designs y'(−w) = −y'w has the same square, so this gives no gain for this statistic | — |

**KK clogit+GLMM Bayesian-bootstrap replicate** (row `glmm_abstract.R:103`)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| β_T under BB weights | **current**: glmmTMB random-intercept logit on all rows (Laplace) | slowest (TMB tape per replicate) | Estimates a different model than the point estimate (no conditional-logit block for discordant pairs), so the BB distribution is centered on a different estimand. Laplace is biased for binary clusters of size 2 | Joe 2008, *CSDA*; Pinheiro & Chao 2006, *JCGS* |
| same | Weighted version of `fast_clogit_plus_glmm_cpp` (weights on the discordant-pair and group log-likelihood terms) | ~10–100× faster than glmmTMB (theoretical; C++ GH20 with warm start) | Needs a weighted objective in C++, an implementation cost | — |
| same | Nonparametric pair-bootstrap through the existing unweighted kernel (resample pairs) | same cost as the point fit × B | Changes BB to an ordinary bootstrap (different weighting scheme) | — |

**ZOIB likelihood structure** (row `fast_zero_one_inflated_beta_cpp`; NEW-separable-likelihood)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| ZOIB MLE | **current**: joint L-BFGS/Newton on all p+1+2q parameters + multistart | — | Treats a separable problem as joint: the joint Hessian is larger (O((p+2q)³) vs O(p³)+O((2q)³)), and joint line searches couple two independent blocks | — |
| same | Split: (i) multinomial logit (softmax, mid as baseline) on the observed category, 2q parameters, **globally concave**, Newton; (ii) beta regression on the mid rows, p+1 parameters, Newton/Fisher scoring | Fewer total evals (theoretical ~1.5–3×); the concave block needs no multistart; identical MLE to optimizer tolerance because the log-likelihood is an exact sum of disjoint-parameter blocks | Must reassemble the block-diagonal vcov (trivial). The LR/score tests for β_T then only need the beta block | Ospina & Ferrari 2012, *CSDA* (ZOIB, separable likelihood); Ferrari & Cribari-Neto 2004, *J. Appl. Stat.* (beta regression) |
| same | EM (audit row B, `em_algorithm_zero_inflated_mixtures.md`) | slower (linear rate) | **Not applicable**: there is no latent class in ZOIB, so EM has nothing to impute. Remove ZOIB from the EM plan's scope | Lambert 1992 applies to ZIP, not ZOIB |

**Quantile regression LP** (row `inference_proportion_quantile_regr.R:233`; NEW-quantile-LP)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| τ-QR | **current**: `fn` (Frisch–Newton interior point) for the point fit, `br` (simplex) in the BB path | — | Two algorithms. With non-unique solutions (common with a binary treatment and small n), br returns a vertex while fn returns an interior-ish solution, so the BB replicates are not the same estimator as the point fit | Koenker & d'Orey 1987, *Appl. Stat.*; Portnoy & Koenker 1997, *Stat. Sci.* |
| same | `br` everywhere | Koenker documents br as competitive or faster up to n of several thousand (EDI's regime) | Can be slow for n ≫ 10⁴ (not EDI) | Koenker 2005, *Quantile Regression* |
| same | `fn` everywhere | consistent | Slower at small n; interior-point tolerance yields a slightly non-vertex β | same |
| same | `pfn` (preprocessing) / `sfn` (sparse) / `conquer` (smoothed QR) | big win only at n ≥ 10⁵ (pfn), sparse X (sfn), or very large n (conquer) | Not EDI sizes; conquer changes the estimator (smoothing bias) | Portnoy & Koenker 1997; He, Pan, Tan & Zhou 2023, *JBES* [cite needed for exact venue] |

**Constrained-link binomial GLMs** (log-binomial, identity-binomial rows; for the C++ cataloger)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| log-binomial MLE with μ ≤ 1 | **current**: IRLS + backtracking + clamping (C++) | — | Non-convergence when the MLE is on the boundary | — |
| same | Combinatorial EM / adaptive barrier (`logbin`) | slower, but guaranteed convergence to the constrained MLE | Linear rate | Marschner & Gillett 2012, *Biostatistics* 13 |
| same | COPY method (augment the data with c copies) | ~same as IRLS | Approximate (bias from the copies) | Deddens, Petersen & Lei 2003 [cite needed for venue] |
| same | Modified Poisson (already offered as a separate class) | faster, always converges | Different estimator (QMLE; same estimand) | Zou 2004, *AJE* |

**Task scheduling in `run_all_inference`** (NEW-task-scheduling)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| makespan of ~10²–10³ heterogeneous tasks on m cores | **current**: FIFO greedy list scheduling in build order | ≤ (2 − 1/m)·OPT | One slow class (GLMM, exact, PB) started last dominates the tail | Graham 1966/1969 |
| same | LPT (longest-first by estimated runtime) | ≤ (4/3 − 1/(3m))·OPT; typically a large tail reduction when a few tasks are 10–100× the median (theoretical) | Needs runtime estimates (a CI runtime manifest exists: commit 29199e78); a wrong estimate degrades it gracefully to FIFO-like | Graham 1969, *SIAM J. Appl. Math.* |
| same | Work-stealing / dynamic chunking | n/a (already dynamic per task) | No gain beyond LPT ordering | — |

**Cauchy combination numerics** (row `cct_combine_pvalues_full`)
| problem | option | speed | disadvantages | citation |
|---|---|---|---|---|
| CCT stat and p | **current**: `tan((0.5−p)π)`, `0.5 − atan(T)/π` | — | For p ≲ 1e-16, (0.5−p)π rounds to π/2, so tan saturates at about 1.6e16 and tiny p's are lost. For large T, `0.5 − atan(T)/π` cancels catastrophically (relative error about 0.3 at p ≈ 3e-16) | Liu & Xie 2020, *JASA* 115 |
| same | Use 1/(pπ) when p < 1e-16 (as in Liu & Xie's ACAT code), and `pcauchy(T, lower.tail=FALSE)` for the p-value | same O(k) | None; identical for moderate p | Liu & Xie 2020; R `pcauchy` |

### New TODO candidates
1. **ZOIB: split the separable likelihood** (`src/fast_zero_one_inflated_beta.cpp:76`, called from `inference_proportion_zero_one_inflated_beta.R:657`). Fit the softmax 0/1/mid block (concave Newton) and the beta block on the mid rows independently, and assemble a block-diagonal vcov. Expected win: theoretical ~1.5–3× fewer objective evals, no multistart needed for the concave block, and no joint line-search coupling. Risk: low, because the MLE is identical by separability. Deterministic drop-in, gated by the existing tests. Also **edit the audit's family B and `em_algorithm_zero_inflated_mixtures.md` to drop ZOIB**: there is no latent class, so EM does not apply.
2. **Zhang exact CI inversion** (`inference_helpers_zhang.R:44,205,180`). Replace the p-space-tolerance bisection with `uniroot(..., extendInt="yes", tol=1e-8)` in δ-space, validate the bracket, map eval errors to NA rather than p = 0, and remove the 2-worker fork. Win: accuracy (the δ-bound error currently corresponds to ±0.005 in p) and less ms-scale fork overhead. Risk: CI expected values in tests shift (they currently encode the coarse tolerance), and non-monotone minlike p(δ) can have several crossings. Deterministic; not an A/B case.
3. **CMH closed-form design variance** (`inference_incidence_cmh.R:192-203`). Use n/(n−1)Σ(y−ȳ)² for complete randomization with exactly balanced draws, Σy² for Bernoulli(½), and per-block sums for blocked designs; keep MC for sequential/KK designs. Win: deterministic SE, no RNG consumption, theoretical ~10³× fewer flops. Risk: designs whose `draw_ws_according_to_design` differs subtly from the textbook moments (verify per design). Deterministic; prototype per design family against the MC value at K = 10⁵.
4. **KK clogit+GLMM BB path** (`inference_incidence_KK_cond_logit_glmm_abstract.R:103-151`). Replace glmmTMB-on-a-different-model with a weighted `fast_clogit_plus_glmm_cpp`. Win: estimator consistency (the main point) plus a theoretical 10–100× per-replicate speedup. Risk: needs a C++ weighted objective. Needs A/B because BB CIs will change.
5. **LPT scheduling in `run_all_inference`** (`inference_suite.R:1360-1440`, `pending = seq_len(n_total)`). Order `pending` by descending estimated runtime from the CI runtime manifest. Win: theoretical makespan bound 4/3 vs 2; the real tail win depends on the runtime spread. Risk: none for correctness (results are keyed by index). Deterministic.
6. **Quantile regression: one LP method for the point fit and the BB replicates** (`inference_proportion_quantile_regr.R:129` vs `:236/:249`). Prefer `br` at EDI sizes, or pass `method="fn"` in the BB path for consistency. Win: consistency, and possibly speed at small n. Risk: point estimates move when the solution is non-unique. Needs the A/B harness for the speed half; the consistency half is a decision.
7. **CCT tail numerics** (`inference_suite.R:4019-4020`). Use the small-p approximation and `pcauchy(stat, lower.tail=FALSE)`. Win: correct combined p below about 1e-15. Risk: none. Deterministic drop-in.
8. (Low priority) **Exact joint null for the Zhang combined test** (`inference_helpers_zhang.R:16`). Enumerate the binomial × noncentral-hypergeometric product support instead of the Fisher χ²₄ reference. Win: an exact-size test (less conservative); cost O(d·S), still trivial. Risk: changes reported p-values. Prototype with exactness checks at n ≤ 12.

### Incidental findings (optional)
- **ZOIB parameterization mismatch (likely bug).** The C++ likelihood uses softmax mixing p0 = e^{η0}/(1+e^{η0}+e^{η1}) (`src/fast_zero_one_inflated_beta.cpp:98-107`). The R side uses p0 = plogis(η0), p1 = plogis(η1), p_mid = max(1−p0−p1, 0), then renormalizes, in three places:
  - `simulate_under_lik_null` (`inference_proportion_zero_one_inflated_beta.R:750-760`): the parametric bootstrap simulates from a different model than the one fitted. At η0 = η1 = 0 the softmax gives ⅓ each, while the R simulator never draws a mid value.
  - `zoib_mean_from_coefs` (:375-384): the marginal-mean estimand and its numerical delta-SE are computed under the wrong mixing.
  - BB path (:251-260): γ0 and γ1 come from separate binary logits, which estimate neither parameterization.
- `inference_incidence_newcombe_univ.R:156-157`: when `uniroot` finds no sign change (δ far outside even the α = 1e-10 CI), the p-value returned is **1.0**; it should be < 1e-10.
- Incidence g-comp BB standardizes with an **unweighted** mean over rows (`helper_gcomp.R:64`, reached via `inference_incidence_gcomp_abstract.R:579 → :690`), while the KK g-comp BB uses `weighted.mean` (`inference_incidence_KK_gcomp_abstract.R:497`). A Bayesian-bootstrap standardization should weight the empirical covariate distribution, so the non-KK path likely under-disperses.
- `inference_mixin_off_optimum_likelihood_eval.R:105`: the Firth/Jeffreys penalized NLL should be `neg_loglik − 0.5·log|I|`. The code adds it, which yields an anti-Firth objective. Dormant today (no caller).
- `InferenceIncidExactBinomial` reports a minlike two-sided p (`src/zhang_exact_speedups.cpp:22`) but a central Clopper–Pearson CI (`inference_incidence_exact_binomial.R:136`), so the two can disagree. `fisher.test` has the same documented mismatch. See Fay 2010.
- `inference_helpers_zhang.R:47-48`: an error in p(δ) is coerced to p = 0 (treated as "outside"), which can silently shrink the CI. The bracket is never checked (:211-214).
- `InferenceIncidKKNewcombeRiskDiff` (`inference_incidence_KK_newcombe_ivwc_univ.R:137-157`) uses Wald variances, not Newcombe's paired hybrid-score interval; the name is misleading.
- O(n·m) R loops:
  - `inference_indicidence_exact_fisher.R:200-203` (`which(m_vec == id)` per pair);
  - `inference_incidence_KK_cond_logit.R:61` (same pattern, **per BB replicate**).
  Use `split(seq_len(n), m)` once.
- `inference_mixin_kk_gee_shared.R:302-362`: `gee_predictors_df_candidates()` eagerly builds 12 correlation-threshold candidates plus a QR pass on **every call, including every BB replicate** (`fit_weighted_gee_with_fallback` :643), even though the first candidate almost always succeeds. Make it lazy and cache it (the predictors do not depend on the weights).
- `inference_proportion_gcomp.R:338-351, 821`: the bootstrap rejects "unusable" resamples (boundary mass, separation, small groups). The result is the bootstrap distribution conditional on non-degeneracy, which is biased toward narrower CIs in exactly the hard cases. This is statistical, but worth a note in the docs.
- `inference_proportion_KK_combined.R:219-231`: the parametric bootstrap draws Bernoulli y for a **proportion** response. It also multiplies `d$X_disc` by `beta_null` of length `ncol(d$X_conc)`; verify that the column alignment between X_disc and X_conc holds.
- `inference_mixin_kk_glmm_shared.R:218`: `glmmTMBControl(parallel = self$num_cores)` inside forked bootstrap workers can oversubscribe cores (num_cores² threads).
- `inference_incidence_cmh.R:193`: the MC SE consumes the session RNG on its first call, so later randomization draws depend on whether the SE was requested first.
- `inference_proportion_zero_one_inflated_beta.R:761-770`: the per-row R `for` loop with `rbeta(1)` could be vectorized (`rbeta(n_mid, a, b)`).

---

## 12. R — designs, helpers, tuning, simulation framework


Scope: `R/EDI/R/` design_*.R (36), helper_*.R (21), local_machine_tuning*.R (6), simulation_framework_report.R, simulations_framework.R, contracts_*.R (2), comprehensive_slow_paths.R, EDI.R, globals.R, zzz.R. RcppExports.R = glue (generated Rcpp wrappers). No graft*.R file exists in R/EDI/R. Where an R routine only forwards to a C++ kernel, the row names the kernel (src file) and its algorithm, read from the source.

Notation: n subjects, p covariates, r design draws, B resamples, |R| = KK reservoir size, K = Turnbull intervals or event times, k = number of strata columns.

### Catalog rows
| kernel (file:line `function`) | problem | current algorithm | complexity | family | verdict |
|---|---|---|---|---|---|
| helper_optimal_milp_solvers.R:97 `prepare_optimal_objective_matrices` | Write the greedy-design imbalance criteria as forms in w | Center X; Cholesky of S (with an rcond guard); `forwardsolve` gives M = L^-1 X'/n, Q = 4M'M (rank p); l1 matrix A = (2/n)X_std' | O(np² + n²p) | F | Keep. Q is built as a dense n×n matrix even though it has rank p. TODO-1/2 use the rank-p structure |
| helper_optimal_milp_solvers.R:121 `milp_solve_l1` | Minimize sum_j abs((Aw)_j) subject to sum(w) = n_T, w binary (`abs_sum_diff`) | Standard absolute-value linearization (p continuous t_j, 2p+1 rows); GLPK branch and bound through ompr/ROI; always used, at any n | n binaries + p continuous variables; branch and bound is exponential in the worst case | F | Prototype. Add the valid symmetry cut w_1 = 1 at prob_T = 0.5 (A·1 = 0 because X is centered). Add orbit ordering for duplicate covariate rows. TODO-1 enumeration for n ≤ ~30 |
| helper_optimal_milp_solvers.R:144 `milp_solve_quadratic` | Minimize w'Qw subject to sum(w) = n_T, w binary (`mahal_dist`, D/D_s/D_B) | Fortet/McCormick product linearization: n(n-1)/2 continuous y_ij with **all three** rows per pair (y≤w_i, y≤w_j, y≥w_i+w_j-1). No RLT cuts, no symmetry breaking, no MIP start. GLPK | n(n-1)/2 variables, 3n(n-1)/2 rows. Benchmark in the file: n=15 0.4 s, n=20 3.5 s, n=25 311 s | F | **Prototype**. This is not the tightest known formulation. See options table (a), TODO-1, TODO-2 |
| helper_optimal_milp_solvers.R:175 `milp_solve_A_dinkelbach` | Minimize (w'Hw+1)/(n_T − w'Pw), a 0-1 fractional program (A/A_s/A_B) | Dinkelbach parametric iteration (Dinkelbach 1967). Each step solves a full product-linearized MILP **cold**, starting from w = the first n_T subjects (an arbitrary start) | iterations × MILP(n); max_dinkelbach_iter 30 | F | Keep the algorithm (superlinear outer convergence; Schaible 1976). Prototype: start t_0 from the annealing incumbent (usually 1–2 fewer outer MILPs). TODO-13 |
| helper_optimal_annealing.R:28 `estimate_annealing_initial_temp` | Calibrate the starting temperature for simulated annealing | T0 = 10 × mean absolute Δ over 16 random BCRD swaps, evaluated in R with `f_exact` | O(16·n²) | F | Keep |
| helper_optimal_annealing.R:42 `annealing_solve_kernel` → src/design_optimal_annealing_search.cpp:132 `annealing_design_search_cpp` | Heuristic minimization over allocations with fixed n_T (quadratic / l1 / ratio / custom) | Single treated↔control swap with Metropolis acceptance. **Geometric cooling 0.999 per move for a fixed 20,000 moves**, so T_final = T0·e^-20 ≈ 2e-9·T0 and roughly the second half is pure descent. 4 OpenMP chains (serial for custom), each keeping its best-so-far. Δ is O(1) from a cached gQ = Qw (O(n) update on accept); l1 is O(p). No reheating, no final local-search polish, and **max_iter does not scale with n** (the swap neighbourhood has n²/4 moves: 10k at n=200, 250k at n=1000) | O(chains·(max_iter + accepts·n)) | F | Keep-tracked (audit F → quantum_upgrade.md TODO-5, PT/tabu comparison). Additionally Prototype an n-scaled schedule plus a final 1-swap steepest-descent polish (TODO-4) |
| helper_optimal_annealing.R:117 `optimal_solve_auto` | Choose between exact and heuristic solvers | MILP if n ≤ 20 (GLPK cliff), otherwise annealing. l1 always uses MILP. A Dinkelbach run that fails to converge falls back to annealing and keeps the better answer | — | F | Keep the policy, but the cutoff should depend on the solver once TODO-1 exists: enumeration to n≈30, then MILP or annealing |
| helper_optimal_shared.R:99 `build_optimal_design_P_H` | Criterion matrices P = Z0(Z0'Z0)^-1Z0' and H / H_S / Bayesian variants | Householder QR of Z0; P = QQ' formed densely; `solve(R'R)` with a ginv fallback; ridge `solve` in the Bayesian case | O(np² + n²p) time, O(n²) memory | NEW-linear-algebra-setup | Keep at EDI sizes. P and H have rank p+1, so the n×n storage is avoidable (relevant to TODO-1) |
| design_fixed_optimal.R:494 `solve_optimal_w` (+:454 `build_solver_inputs`) | Dispatch the solve, then the mirror coin | Solver dispatch. The mirror is checked by re-evaluating the objective, O(n²), then a fair coin. BRT replicate mode uses annealing with 2000 moves × 1 chain | — | F | Keep (glue plus verification). See incidental #1 (the BRT replays a weaker mechanism) |
| design_fixed_greedy.R:131 `draw_ws_raw` → src/design_fixed_greedy.cpp `greedy_design_search_cpp` | Greedy pair-switching design (Krieger, Azriel & Kapelner 2019) | Random balanced start. Each round takes the best improving swap over all (treated, control) pairs, with incremental Δ (mahal: f+2d·Δ+‖Δ‖²); n_iter < ∞ gives a random-swap mode. OpenMP over r draws | O(n_T·n_C·p) per round × rounds × r | F | Keep. **The search is the design**: a different search changes the allocation distribution, not just the speed |
| design_fixed_greedy_d_optimal.R:250 → src/optimal_design_search.cpp `d_optimal_search_cpp` / `a_optimal_search_cpp` | Greedy D/A-optimal swap design | Shared sorted-scan **pruned** best-swap engine (greedy_pairwise_swap_engine.h). The D bound adapts; the A bound is fixed per round. OpenMP over r | ≤ O(n²) per round × rounds × r; pruning cuts the constant | F | Keep (same reason as the row above) |
| design_fixed_matching_greedy_pair_switching.R:170 → `greedy_design_search_cpp` (pair-constrained mode) | Greedy within-pair flips over a blossom pairing | Best-improvement flip search restricted to pairs | O((n/2)·p) per round | F | Keep |
| design_fixed_rerandomization.R:206 → src/rerandomization_helpers.cpp `rerandomization_search_cpp` | Draw r balanced allocations with imbalance ≤ cutoff | Plain acceptance–rejection, OpenMP, max_draws = max(1000r, 1e5), errors if fewer than r are accepted | O(draws·np) | I | Keep-tracked (audit I → quantum_upgrade.md §II.1) |
| design_fixed_rerandomization.R:179-180 (`prop_acceptable`) | Keep the best fraction of N = r/prop draws | Generate N in C++, `compute_objective_vals_cpp`, then a **full `order()`** | O(N·np + N log N) | I | Keep. A partial selection (`sort(partial=)`) would be O(N), a trivial gain |
| design_fixed_rerandomization.R:238 `generate_one_rerandomized_w` | Rejection sampling in R for prob_T ≠ 0.5 or odd n | `repeat` over sample() or **rbinom** candidates with an R `colMeans` objective; **no draw cap** | O(draws·np) in R | I | Keep the algorithm. See incidental #6 |
| helper_matching.R:7 `compute_binary_match_structure` | Minimum-weight perfect non-bipartite pair matching | p=1: sort and pair neighbours, O(n log n), optimal for any convex 1-D cost. p>1: Mahalanobis via chol(S^-1) whitening, `dist()²`, then `nbpMatching::nonbimatch` (Derigs' weighted matching code, Fortran; Lu et al. 2011), distances scaled to integers at precision 6 | O(n²p + n³) | G | Keep (audit G) |
| design_fixed_binary_match.R:177 → `draw_binary_match_assignments_cpp` | Draw w given pairs | Independent fair coin per pair, OpenMP | O(nr) | NEW-restricted-randomization-draw | Keep |
| helper_matching.R:63-170 `.compute_kk_*_match_data(_cached)` → `compute_zhang_match_data_cpp`, `compute_matching_lin_*_cpp` | KK matched-pair difference and reservoir statistics | Linear passes; the X-structural part is cached per m_vec at design level | O(np) | NEW-linear-algebra-setup | Keep |
| design_fixed_optimal_blocks.R:383 `solve_optimal_blocks` | Partition n subjects into B blocks of size ⌊n/B⌋..⌈n/B⌉ minimizing within-block pairwise distance | MILP: x_ik binary; **z_ijk binary** (n²B/2 of them) with all three McCormick rows; the only symmetry breaking is x_11 = 1 (B! label symmetry otherwise remains); GLPK | O(n²B) variables and rows; exponential | NEW-balanced-partition | **Prototype** (options table (c), TODO-5) |
| design_fixed_optimal_blocks.R:319 `solve_greedy_blocks` | The same problem, heuristically | `blockTools::block` default `algorithm="optGreedy"`, Mahalanobis distance (repeatedly takes the closest available pair or group). Leftovers go to the nearest block with room, via an R loop | O(n²p) plus R loop O(leftover·np) | NEW-balanced-partition | Keep |
| design_fixed_optimal_blocks.R:359 `solve_kway_blocks` (default `method="K-way"`) | The same problem, heuristically | `anticlust::balanced_clustering(method="centroid")`. When n mod B ≠ 0, `hclust(ward.D2)` picks the r farthest-from-centroid subjects to hold out; they are attached afterwards | O(n² ) memory for the hclust holdout | NEW-balanced-partition | Keep |
| design_fixed_optimal_blocks.R:298 `get_or_compute_distance_matrix` → `optimal_blocks_distance_matrix_cpp` | All pairwise distances | Direct O(n²p); a custom R `dist` function means O(n²) R callbacks | O(n²p) | NEW-balanced-partition | Keep |
| design_fixed_blocking.R:181 / design_fixed_optimal_blocks.R:255 / design_fixed_cluster.R:95 / design_fixed_blocked_cluster.R:124 `draw_ws_raw` | Complete randomization within blocks / clusters | `replicate(r, randomizr::block_ra / cluster_ra / block_and_cluster_ra(...))`, one R-level call per draw. The C++ `generate_permutations_blocking_cpp` exists but runs **only when randomizr is not installed** | O(rn) work, but R/randomizr overhead dominates per draw | NEW-restricted-randomization-draw | Prototype (TODO-11) |
| design_blocking_abstract.R:195 `get_strata_keys` | Build strata from covariates with a target block count | Adds columns greedily; for continuous columns, scans quantile bin counts with `cut` | O(k·bins·n log n) | NEW-balanced-partition | Keep |
| design_fixed_blocking.R:6 `largest_divisor_at_most` | Default B | Linear downward scan | O(√n) | — | Keep (trivial) |
| design_fixed_factorial.R:116, design_fixed_bernoulli.R:87 (→`generate_permutations_bernoulli_cpp`), design_fixed_ibcrd.R:85 (→`generate_permutations_ibcrd_cpp`) | Draw from a fixed simple design | R loop of `sample(base_alloc)` (factorial); C++ shuffles or Bernoulli draws | O(nr) | NEW-restricted-randomization-draw | Keep |
| design_component_registry.R:~300-410 (BlockingStructure/ClusterStructure `draw_bootstrap_indices`) → `stratified_bootstrap_indices_cpp`, `resample_group_rows_cpp`; design_matching_abstract.R:81 → `draw_matching_bootstrap_sample_cpp`; design_abstract.R:~465,481 → `sample_int_replace_cpp`; design_fixed_matching_greedy_pair_switching.R:~63 | Bootstrap index draws (iid, stratified, cluster, pair+reservoir) | i.i.d. multinomial resampling within units | O(n) per replicate | J | Keep-tracked (audit J, TODO-4 balanced bootstrap) |
| design_abstract.R:1018 `covariate_impute_if_necessary_and_then_create_model_matrix` | Impute missing covariates, then build the model matrix | Adds missing-indicator columns; **missRanger** (chained random forests, with y included), falling back to **missForest** (Stekhoven & Bühlmann 2012); then `model.matrix`; drops constant columns; `drop_linearly_dependent_cols` | O(iter·p·RF(t)) + O(tp²) | NEW-covariate-imputation | Keep for fixed designs (runs once). For sequential designs see the next row |
| design_seq_one_by_one_abstract.R:58 `add_one_subject` | Ingest one arrival | `rbindlist` copy, O(tp), then **once enough subjects have arrived, a full re-imputation and model-matrix rebuild over all t rows on every arrival** | O(n²p) summed; with missingness, **n complete random-forest imputations** | NEW-covariate-imputation / H | **Prototype** (TODO-9). Recompute from scratch |
| design_abstract.R:1100 `compute_all_subject_data` → `compute_all_subject_data_cpp` | Per-arrival design matrices (prev/all/scaled/with-y), rank-QR column selection | Full rebuild for each t, cached by t | O(tp²) per arrival, O(n²p²) summed; **cache memory O(n²p)** (about 4 matrices of t×p per t) | H | Keep-tracked (kk14_incremental_covariance.md) |
| design_seq_one_by_one_abstract.R:190 `draw_ws_raw` (generic) | Redraw a sequential design | R double loop over j ≤ r and t ≤ n calling `self$assign_wt()`. **private$t is not advanced** and per-design state is not reset | O(r·n·cost(assign_wt)) in R | NEW-restricted-randomization-draw | Prototype for urn (TODO-10). **Bug for RandomBlockSize** (incidental #2) |
| design_seq_one_by_one_efron.R:76 `assign_wt`, :95 → `generate_permutations_efron_cpp` | Efron (1971) biased coin | Per arrival: `sum(w==1)` and `sum(w==0)` recounted from scratch, O(t). Draws in C++ with running counts | O(t) per arrival; O(nr) per draw batch | NEW-restricted-randomization-draw | Keep. Incremental counts would be O(1); not a bottleneck |
| design_seq_one_by_one_urn.R:90 `assign_wt` | Wei's UD(α,β) urn | Recounts O(t) per arrival. **No C++ draw kernel**, so draws go through the generic R loop | O(t) per arrival; **O(r n²) R ops** per draw batch | NEW-restricted-randomization-draw | Prototype (TODO-10) |
| design_seq_one_by_one_ibcrd.R:102/123, design_seq_one_by_one_bernoulli.R:77/82 | iBCRD / Bernoulli sequential | Remaining-slot probability (O(t) recount) or a coin; C++ draws | O(t) and O(nr) | NEW-restricted-randomization-draw | Keep |
| design_seq_one_by_one_spbr.R:98/119 | Stratified permuted blocks | Per-stratum queue in an env; refills by `sample`; C++ draws (`generate_permutations_spbr_cpp`); keys built by an O(n) `vapply` | O(1) amortized per arrival | NEW-restricted-randomization-draw | Keep |
| design_seq_one_by_one_random_block_size.R:121 `assign_wt` | Permuted blocks with random block size | Per-stratum queue (`block[-1]` copy); no draw override, so it uses the generic loop | O(bs) per arrival | NEW-restricted-randomization-draw | Keep the algorithm. **Generic redraw is wrong** (incidental #2) |
| design_seq_one_by_one_pocock_simon.R:118 `assign_wt` → `pocock_simon_assign_and_update_cpp`; :161 `ensure_factor_metadata` | Pocock–Simon minimization | C++ keeps **incremental** marginal counts and updates them in place, O(Σ levels). But the R `ensure_factor_metadata` rescans all t rows of every strata column (`unique`, `setdiff`) and runs **twice per arrival** | O(tk) R work per arrival, O(n²k) summed | H | Keep the algorithm; the R metadata cost is an implementation issue (incidental #9) |
| design_seq_one_by_one_pocock_simon.R:137 `draw_ws_raw` → `generate_permutations_pocock_simon_cpp` | Redraw Pocock–Simon | C++ incremental counts per replicate. The R prep loops over n rows calling `get_subject_levels_idx` → `ensure_factor_metadata` | C++ O(rnK); **R prep O(n²k)** | H | Keep (incidental #9) |
| design_seq_one_by_one_atkinson.R:94 `assign_wt` → src/atkinson_assign.cpp `atkinson_assign_weight_cpp` | Atkinson (1982) D_A-optimal biased coin, one arrival | Rebuilds [w,1,X]'[w,1,X] and its FullPivLU inverse from scratch | O(tp² + p³) per arrival | H | Keep (once per arrival) |
| design_seq_one_by_one_atkinson.R:115 → src/generate_permutations.cpp:80-121, 279-292 `generate_permutations_atkinson_internal` | Redraw Atkinson for randomization inference | Per replicate b and per t: **form X_w'X_w (O(tp²)) and FullPivLU-invert it (O(p³))**. The w-independent column selection is precomputed per t, but each step stores a (t−1)×p copy, so memory is O(n²p) | **O(r·n²·p² + r·n·p³)** | H | **Adopt** (TODO-3). Schur complement: precompute (Z'Z)^-1 per t once (w-independent) and update Z'w incrementally, giving O(r·n·p²) and O(np²) memory |
| design_seq_one_by_one_KK14.R:130 `assign_wt` → `compute_proportional_mahal_distances_cpp` | KK14 sequential matching | `var(X_prev)` O(tp²), `solve` O(p³), brute-force scan of the reservoir O(\|R\|p²), Hotelling-T² / F threshold via `qf` | O(tp² + p³ + \|R\|p²) per arrival | H | Keep-tracked (kk14_incremental_covariance.md). The nearest-neighbour scan is Keep per audit H |
| design_seq_one_by_one_KK14.R:186 → `generate_permutations_matching_cpp` | Redraw KK designs given m | Pair flips plus a Bernoulli reservoir | O(nr) | NEW-restricted-randomization-draw | Keep |
| design_seq_one_by_one_KK21.R:247 `assign_wt`, :355 `compute_weights` → src/kk21_weights.cpp `kk21_{continuous,logistic,survival,negbin,beta,ordinal}_weights_cpp` | KK21: covariate-importance-weighted matching | Per arrival, **from scratch**: p univariate fits on all responses so far (closed-form OLS t; logistic Newton; etc.). Match threshold = λ-quantile of **500 Monte Carlo random-pair** weighted distances (`compute_bootstrapped_weighted_sqd_distances_cpp`). Brute-force reservoir scan | O(p·t·iters + 500p + \|R\|p) per arrival, plus the compute_all_subject_data rebuild | H / A | Keep. Warm-starting each covariate's fit from the previous arrival is a low-priority Prototype. An exact all-pairs threshold (O(t²p)) would change the design rule |
| design_seq_one_by_one_KK21_stepwise.R:148 `compute_weights` → kk21_weights.cpp:170 `kk21_stepwise_*_weights_cpp` | KK21 forward-stepwise weights | Continuous: **FWL incremental residualization** (one orthogonalization per step, then O(t) per candidate). Logistic: score test against a reduced fit with LDLT | O(p²t) per arrival | H / A | Keep (already the efficient forward-stepwise algorithm). The R fallback at :199 `compute_weights_KK21stepwise` refits every candidate, O(p⁴t), but is unreachable for current response types |
| helper_glm_fit.R:852/923 `fast_logistic_regression(_with_var)` → C++ | Logistic MLE plus SE | C++ default **L-BFGS** (IRLS / Newton–Raphson available; the tuning axis may switch). On separation (‖β‖ > threshold) it **drops the covariate with the largest coefficient and refits**, up to p times | O(np·iters) per fit, × up to p refits | A + NEW-separation | Keep (A). Investigate the separation strategy (options table (i)) |
| helper_glm_fit.R:1023 `fast_weibull_regression` → `fast_weibull_regression_cpp` | Weibull AFT MLE | C++ L-BFGS/Newton; with `use_rcpp=FALSE`, falls back to `survreg` (Newton–Raphson) | O(np²·iters) | A | Keep |
| helper_glm_fit.R:1143 `sanitize_beta_response` | Move y ∈ {0,1} inside (0,1) | Smithson & Verkuilen (2006) squeeze (y(n−1)+0.5)/n | O(n) | — | Keep |
| helper_glm_fit.R:1213/1294 `fast_beta_regression(_with_var)` | Beta regression MLE | C++ L-BFGS, then `betareg` (optim plus Fisher scoring), then OLS on logit(y) | O(np·iters) | A | Keep |
| helper_glm_fit.R:1407 `fast_coxph_regression` → `fast_coxph_regression_cpp` | Cox partial likelihood | C++ (documented as **Breslow** ties). The `use_rcpp=FALSE` fallback is `glmnet(lambda=0)` coordinate descent | O(n log n + np²) per iteration | A / L | Keep (row L verification still open). See incidental #4 |
| helper_glm_fit.R:1490/1585 `fast_negbin_regression(_with_var)` → `fast_neg_bin(_with_var)_cpp` | NB2 MLE, joint (β, θ) | C++ L-BFGS; rank-deficient columns pruned by QR; on failure, drops the last QR-pivot covariate and refits, up to p times | O(np·iters) × refits | A (fixed θ) / B-adjacent | Keep-tracked (bug_fix_plans/negbin_dispersion_convergence.md) |
| helper_glm_fit.R:2004 `clogit_helper` → `collect_discordant_pairs_cpp` | Conditional logistic regression for 1:1 pairs | Exact reduction: intercept-free logistic on within-pair differences over discordant pairs | O(np) + logistic fit | A | Keep (incidental #10) |
| helper_robust_regression.R:83 `robust_survreg_with_surv_object` | Robust parametric AFT fit | Drops correlated and dependent columns. Weibull: C++ fast fit used as `init` for `survreg` (so the fit runs twice). Otherwise up to 50 **random-walk restarts** (`init += rnorm`, unscaled) | O(restarts·np²·iters) | A / NEW-nonconcave-multistart | Keep-tracked (multistart_nonconcave_likelihoods.md). Prototype deterministic data-driven starts |
| helper_robust_regression.R:177 `robust_negbinreg` | NB fit with fallback | `MASS::glm.nb`: alternating IRLS for β and `theta.ml` Newton for θ (linear outer convergence); drops the last column on error | O(outer·np²) | A | Keep (used only on the KK21 fallback path) |
| helper_robust_regression.R:231 `summary_glm_lean` | GLM coefficient table | `chol2inv` of the pivoted QR R factor | O(p³) | — | Keep |
| helper_robust_sandwich.R:5/19/64 `robust_sandwich_*` | Heteroskedasticity-robust variance | **HC0**: meat = crossprod(X, X·r²), bread = `solve(XtWX)` (explicit inverse) | O(np² + p³) | NEW-sandwich-variance | Keep the algorithm. **Investigate HC2/HC3** for small n (options table (j)); this is a statistical choice, not a speed one |
| helper_inference_survival_turnbull.R:131 `turnbull_npmle_group_stat` | Turnbull NPMLE for interval-censored S(t); median / RMST | `interval::icfit(L, R)` with **no initfit**: pure self-consistency **EM** (Turnbull 1976) from a uniform-ish start, ε=1e-6, maxit 10,000, dense A (n×K) matrix products in R. Then an R loop for RMST | O(iter·nK); EM iteration counts are often in the hundreds to thousands | NEW-npmle-interval-censored | **Prototype** (TODO-6). EMICM or icenReg |
| helper_inference_survival_turnbull.R:172 `turnbull_npmle_stat_diff` | Arm difference of the Turnbull statistic | Two NPMLE fits per call, inside resampling loops | 2 × the row above, × B | NEW-npmle-interval-censored | Same as above |
| helper_gcomp.R:52 `gcomp_logistic_potential_outcomes`; :34 `gcomp_select_covariate_to_drop` | G-computation standardization; separation fallback | Closed-form plogis averages; drop the covariate with the largest coefficient | O(np) | NEW-separation | Keep / Investigate (same as the logistic separation strategy) |
| helper_marginal_estimand.R:20/64 `numerical_gradient_central` / `marginal_estimand_delta_se` (used by :142 Poisson marginal) | Delta-method SE of a marginal mean-difference or ratio | **Central differences with absolute eps 1e-5**: 2p evaluations of an O(np) functional | O(np²); truncation error O(eps²·f''') | NEW-numerical-derivative | **Adopt** the analytic gradient (TODO-8) |
| helper_model_matrix.R:87 `drop_linearly_dependent_cols` | Remove rank-deficient columns | `matrix_rank_cpp`, then R `qr` (LINPACK limited pivoting) with tol 1e-7: two factorizations | O(np²) × 2 | NEW-collinearity | Keep (one pivoted QR would do) |
| helper_model_matrix.R:113 `drop_highly_correlated_cols` | Remove near-collinear columns | Iterated full `cor` (O(np²)); removes **every** second index of every flagged pair at once | O(rounds·np²) | NEW-collinearity | Keep. Correctness note: can over-drop (incidental #8) |
| helper_survival_fits.R:21/86 `.extract_survreg_start`, `.extract_lognormal_start` | Starting values | Fast Weibull fit or `robust_survreg` | — | A | Keep |
| helper_survival_fits.R:107 `.fit_dep_cens_transform_model` | Bivariate-lognormal dependent-censoring MLE (ρ via atanh) | 3 starts on ρ ∈ {0, ±0.25}; C++ L-BFGS; fallback R `optim(BFGS)` **without an analytic gradient** (finite differences) and a numeric Hessian | O(starts·iters·np) | NEW-nonconcave-multistart | Keep-tracked (multistart_nonconcave_likelihoods.md). Note: ρ is identified only parametrically (Tsiatis 1975) |
| helper_survival_fits.R:243 `.fit_clayton_weibull_aft` | Clayton-copula Weibull AFT for pairs | 3 θ starts; C++ L-BFGS, then `optim` BFGS, then Nelder–Mead; C++ or numeric Hessian | O(starts·iters·np) | NEW-nonconcave-multistart | Keep-tracked (same plan) |
| helper_survival_fits.R:516 `.fit_weibull_frailty_rcpp` → src/fast_weibull_frailty.cpp | Normal-frailty Weibull marginal likelihood | Fixed 20-node Gauss–Hermite per pair | O(n·20·p) per evaluation | C | Keep-tracked (performance_profiling_and_upgrades.md TODO-153, adaptive GH) |
| helper_survival_fits.R:571 `.breslow_hazard` | Breslow cumulative baseline hazard | **For each event time, rescans the whole at-risk vector**: `sum(risk_o[y_o >= t_k])` | **O(nK)** ≈ O(n²) | NEW-step-function | **Adopt** a reverse cumulative sum, O(n log n) (TODO-7) |
| helper_survival_fits.R:592/617 `.cox_simulate_stratified` / `.cox_simulate_from_breslow` | Parametric-bootstrap simulation of Cox event times | Inversion by a linear `which(cumhaz >= tgt)` scan per subject | O(nK) per replicate | NEW-step-function | **Adopt** `findInterval`, O(n log K) (TODO-7). **Normalization bug** (incidental #3) |
| helper_zoib.R:88 `.fit_zero_one_inflated_beta` (+:25 start, :61 R likelihood) | ZOIB MLE | C++ `fast_zero_one_inflated_beta_cpp` joint L-BFGS over (β, φ, γ0, γ1). The fallback Hessian is `numDeriv` on an R likelihood with **intercept-only** inflation | O(np·iters) | B (audit) → actually separable | Investigate. See options table (o) and incidental #7. **This R wrapper appears to have no callers** |
| helper_bootstrap_ci.R:5-80 `bootstrap_ci_*` | Percentile, basic, studentized and symmetric-studentized intervals | `quantile(type=8)` plus pivot stabilization guards | O(B log B) | J / D | Keep |
| helper_matching.R:172 `.extract_se_from_rq_fit` | Quantile-regression SE | `quantreg` summary `se="nid"` (Hall–Sheather sparsity), falling back to `"iid"` | O(np²) | NEW-sandwich-variance | Keep |
| helper_math.R:26-77 `logit` / `inv_logit` / `sample_mode` (→`sample_mode_cpp`) | Clamped link functions; sample mode | Closed form; C++ mode | O(n) | — | Keep |
| globals.R:166 `weighted_ordinal_bootstrap_surrogate_fit` | Weighted proportional-odds fit per Bayesian-bootstrap draw | `MASS::polr`: `optim` BFGS on reparametrized cutpoints, warm start, reltol 1e-10; fallback `lm.wfit` | O(iters·np) per replicate, × B | A | Keep. Investigate whether an EDI C++ weighted ordinal Newton kernel could replace it (quasi-Newton BFGS against Newton, inside a B-loop) |
| globals.R:281 `weighted_cox_bootstrap_surrogate_fit` | Weighted Cox per Bayesian-bootstrap draw | `survival::coxph` Newton–Raphson with its **default `ties="efron"`** | O(iters·(n log n + np²)) | A / L | **Investigate**: the main estimator is documented as Breslow (incidental #4) |
| globals.R:338 `weighted_weibull_bootstrap_surrogate_fit` | Weighted Weibull per Bayesian-bootstrap draw | `survreg` Newton–Raphson, warm init, robust cluster sandwich | O(iters·np²) | A | Keep |
| globals.R:251 `kk_pair_and_reservoir_bootstrap_weights` | Aggregate row weights to pairs | `vapply` over pair ids with `which(m_vec == pid)` | O(n·#pairs) = O(n²) | — | Keep (`tapply` or `rowsum` would be O(n); trivial) |
| local_machine_tuning.R:296 `tune_EDI_for_this_machine` | Choose per-machine dispatch settings (cold/warm start, optimizer, parallel crossover) | **Axis by axis, independently (no interaction search)**. Exhaustive over family × n_grid × candidates with fixed reps (3/5/9 presets) | cells × reps × fit time | NEW-autotuning | Prototype (TODO-12) |
| local_machine_tuning_harness.R:136/206/269 `edi_tuning_interleaved_ab`, `_blocked_ab`, `_accept_candidate` | Timing comparison and acceptance | Interleaved ABAB timing (good against drift), **but analyzed unpaired**: accept if Δmedian ≥ 5% and > 2·IQR(candidate). No multiplicity control across hundreds of cells | O(reps) | NEW-autotuning | Prototype: paired-difference analysis (TODO-12) |
| local_machine_tuning_axes.R:61/441 `edi_tuning_tune_binary_axis` / `_categorical_axis` (+:171/393/596 cold/warm/optimizer wrappers) | One-axis candidate search | Each candidate A/B'd against the incumbent | O(cells·candidates·reps) | NEW-autotuning | Keep (racing would prune losers early; see TODO-12) |
| local_machine_tuning_axes.R:742 `edi_tuning_tune_parallel_crossover` | Smallest n at which parallel beats serial | Linear scan over ascending n_grid; stops at the first win (assumes monotone). Blocked A/B so setup_a/b can switch cores | O(\|n_grid\|·reps) | NEW-autotuning | Keep (grid has 3–5 points; bisection would gain nothing) |
| simulations_framework.R:1049-1930 (rep×cell loops; :955 result-key store via `init/add/check_in_result_key_store_cpp`; :1762 rep-major mirai work stream) | Monte Carlo simulation study | Fixed Nrep per cell; fork chunks or a windowed mirai unit stream; C++ hash set for dedupe and resume | O(Nrep·cells·fit) | NEW-sim-mc | Keep (scheduling). Prototype a precision-targeted Nrep (options table (n)) |
| simulations_framework.R:178 (ordinal quantization), :4139 `compute_true_ordinal_mean_diff`, :4128 survival truth | DGP coarsening and true estimands | Quantile `cut`; closed-form normal cell probabilities, O(nK); Weibull means via `gamma()` | O(nK) | NEW-sim-mc | Keep (verify the survival factor; incidental #11) |
| simulation_framework_report.R:85 `summarize` | MSE, coverage, power and size with MC error | Group means; **exact binomial (Clopper–Pearson) `binom.test`** for coverage and size | O(rows) | NEW-sim-mc | Keep |

**Glue, no algorithmic content (one line per file):**
- design_class_factory.R: R6 class composition.
- design_class_registry.R: class metadata registry and ancestor walks.
- design_component_registry.R: component wiring, apart from the bootstrap-index rows above.
- design_custom_extensions.R: user-extension stubs.
- design_fixed_abstract.R: argument checks and the response API.
- design_observational.R, design_observational_blocks.R, design_observational_matching.R: no draw mechanism; they only set m.
- design_matching_abstract.R: pair-row bookkeeping and cluster-id caching via `compute_cluster_ids_cpp`, apart from the bootstrap row above.
- design_blocking_abstract.R `summarize_blocks` (:124): R loop summary, O(n·p).
- design_abstract.R: everything apart from the imputation, compute_all_subject_data and bootstrap rows above.
- helper_additional_asserts.R, helper_package_checks.R, helper_rcpp_doc_stubs.R, helper_response_asserts.R, helper_reused_worker_private_cache.R: asserts, availability checks, roxygen stubs, cache reset.
- helper_user_compiled_fn.R: `cppXPtr` normalization.
- helper_glm_fit.R lines 180–850 and 1671–1990: roxygen stubs and commented-out code.
- local_machine_tuning_persistence.R: config input/output and policy merge.
- local_machine_tuning_correctness.R: agreement check at tolerance 1e-6.
- local_machine_tuning_synthetic_fixtures.R: fixture construction.
- contracts_mixins.R: mixin/component registry, dependency resolution, binding unlocks.
- contracts_resampling_draws.R: draw-contract tables and cache get/set.
- comprehensive_slow_paths.R: rule validation.
- EDI.R: package doc.
- zzz.R: `.onLoad` / `.onAttach`.
- globals.R, apart from the four surrogate and weights rows: dispatch-policy getters/setters, fork-cluster and mirai daemon lifecycle (`start_mirai_daemons_bounded`, bounded settle polling).
- RcppExports.R: generated wrappers.

### Options & disadvantages

**(a) Exact minimization of w'Qw (and l1, ratio) over sum(w) = n_T** (milp_solve_quadratic / _l1 / _A_dinkelbach)

| problem | option | speed vs current (theoretical) | disadvantages / risks | citation |
|---|---|---|---|---|
| exact BQP with a cardinality constraint | **Current**: Fortet/McCormick, 3 rows per pair, GLPK | baseline; a branch-and-bound cliff between n=20 and 25 (in-file benchmark) | weak LP relaxation (at w_i = n_T/n all y_ij ≈ 0, so the bound is near 0); n²/2 extra variables | Fortet 1960 [cite needed]; Glover & Woolsey 1974 [cite needed] |
| (same) | Sign-pruned McCormick: keep only y ≥ w_i+w_j−1 when Q_ij > 0, and only y ≤ w_i, y ≤ w_j when Q_ij < 0 | ~1.5–3× fewer LP rows; same bound, same optimum | none (exact); small win only | standard |
| (same) | **RLT-1 cardinality equalities** Σ_{j≠i} y_ij = (n_T−1)·w_i (∀i) added to the above | far tighter LP bound, so far fewer nodes; plausibly pushes the GLPK cliff beyond n≈20 (unmeasured) | n extra dense rows; still n²/2 variables; GLPK remains weak versus commercial solvers | Adams & Sherali 1986 (Management Science 32(10)); Sherali & Adams 1990 (SIAM J. Discrete Math.) |
| (same) | **Symmetry breaking** at prob_T = 0.5: fix w_1 = 1 (valid for mahal_dist since Q·1 = 0; for D since P·1 = 1 and n = 2n_T; for l1 since A·1 = 0; **not** for the A-ratio, where H·1 ≠ 0). Orbit ordering w_i ≥ w_j for identical covariate rows | ≤2× from the mirror; very large with discrete covariates (many duplicate rows) | the mirror coin already re-randomizes the label after the solve, so no bias. Invariance must be asserted numerically per kind | Margot 2010 (in *50 Years of Integer Programming*, Springer) |
| (same) | **Low-rank formulation**: Q = 4M'M (rank p), P = UU' (rank p+1). Minimize ‖z‖² subject to z = Mw: p continuous variables. Convex MIQP (Gurobi/CPLEX) or outer approximation (tangent cuts θ ≥ 2z_k'z − ‖z_k‖², iterative GLPK re-solves) | removes all n²/2 auxiliary variables; MIQP solvers handle this well | MIQP needs a commercial solver (not GLPK). Outer approximation with GLPK may need many re-solves; ratio and l1 need separate treatment | Duran & Grossmann 1986 (Math. Programming 36) for outer approximation; Bertsimas, Johnson & Kallus 2015 (Operations Research 63(4)) for MIP in this design context |
| (same) | Glover compact linearization (n auxiliary variables z_i = w_i·(Qw)_i, 4n rows) | far smaller model | LP bound no tighter than McCormick without extra cuts | Glover 1975 (Management Science 22(4)) |
| (same) | QCR convex reformulation plus MIQP | strong root bound | needs an SDP solve plus MIQP (commercial); implementation cost | Billionnet & Elloumi 2007 (Math. Programming 109); Billionnet, Elloumi & Plateau 2009 (Discrete Appl. Math. 157) |
| (same) | **Exhaustive enumeration** with a revolving-door (single swap) combination Gray code plus an **O(p) incremental objective** (maintain z = Mw ∈ R^p; ratio: z_P, z_H; l1: v = Aw). Halve by the mirror at prob_T = 0.5; OpenMP over prefixes | C(25,12) ≈ 5.2e6 × O(p) ≈ milliseconds, against **311 s** for GLPK at n=25. n=30: 1.55e8 × p ≈ ~1 s/thread. All theoretical | exponential wall ≈ n 32–34; exact and certified, with deterministic tie-breaking; the custom kind is still too slow (black-box O(np) per evaluation) | Nijenhuis & Wilf 1978 (*Combinatorial Algorithms*); Knuth, TAOCP 4A §7.2.1.3 |
| (same) | SDP-bound branch and bound (BiqMac-style) | best exact method for dense BQP at n ~ 100 | heavy dependency and implementation; overkill at EDI sizes | Rendl, Rinaldi & Wiegele 2010 (Math. Programming 121) |
| fractional 0-1 (A-ratio) | Current Dinkelbach plus a cold MILP at each step | baseline | each outer step is a full MILP from an arbitrary start | Dinkelbach 1967; Schaible 1976 (Management Science 22(8)) |
| (same) | Dinkelbach seeded with the annealing incumbent's ratio as t_0, plus a MIP start | typically 1–2 fewer MILPs (unmeasured) | ROI.plugin.glpk support for MIP starts is unverified | — |
| (same) | Enumeration (row above), where the ratio is exact per subset | removes Dinkelbach entirely for n ≤ ~30 | same exponential wall | — |

**(b) Heuristic allocation search beyond the exact range** (annealing kernel; audit F)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: single-swap SA, geometric 0.999, fixed 20k moves, 4 chains, best-so-far | baseline | budget does not grow with n (neighbourhood n²/4); the end state is not guaranteed to be 1-swap locally optimal; the BRT profile (2k moves, 1 chain) is weaker still | Kirkpatrick, Gelatt & Vecchi 1983 (Science 220) |
| SA plus a **final steepest-descent 1-swap polish** (reuse greedy_pairwise_swap_engine.h; O(n_T·n_C) per pass with O(1) Δ) | adds ≤ a few passes; ensures a 1-swap local optimum | small extra time; still not global | — |
| n-scaled schedule (moves ∝ n per temperature level) | more time at large n; better objective | longer runtimes for large n | Hajek 1988 (log schedule, provable but impractically slow) |
| Kernighan–Lin pair-swap passes (balanced bipartition) | strong for balanced partition problems; deterministic | local optimum only; reimplementation | Kernighan & Lin 1970 (Bell Syst. Tech. J. 49(2)) |
| Parallel tempering | better on rugged landscapes at equal time | more state; temperature-ladder tuning | Swendsen & Wang 1986; Earl & Deem 2005 — already tracked (quantum_upgrade.md TODO-5) |
| Tabu search | often the best QUBO heuristic at moderate n | tabu-tenure tuning; deterministic cycling risk | Glover 1989/1990 — already tracked |
| Exact enumeration (table (a)) | exact up to n≈30 | exponential | — |

**(c) Balanced partition into B blocks** (solve_optimal_blocks / greedy / K-way)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current** MILP: binary z_ijk, 3 rows each, x_11 = 1 | baseline (tiny n only) | B!/1 label symmetry remains; z binary is needless; LP bound weak | — |
| z continuous plus only z ≥ x_ik + x_jk − 1 (valid when D ≥ 0; minimization never pushes z up) | about ⅔ fewer rows and n²B/2 fewer binaries; same optimum | must check D ≥ 0 at runtime (a custom dist function can be negative) | standard |
| Symmetry breaking: x_ik = 0 for k > i (representative ordering) | removes ~B! equivalent subtrees | none (exact) | Margot 2010 |
| Label-free clique partitioning: y_ij same-block indicators, triangle inequalities (lazy), size rows Σ_j y_ij ∈ [L−1, U−1] | no label symmetry; O(n²) variables | O(n³) triangle rows (need lazy separation, which GLPK through ompr lacks) | Grötschel & Wakabayashi 1989 (Math. Programming 45) |
| Column generation / set partitioning over feasible blocks | strongest LP bound | complex pricing; heavy | Mehrotra & Trick 1998 (Oper. Res. Letters 22) |
| blockTools optGreedy (current `greedy`) | fast | heuristic; R loop for leftovers | Moore 2012 (Political Analysis 20(4)) |
| anticlust centroid balanced clustering (current default) | fast | heuristic | Papenberg & Klau 2021 (Psychological Methods 26(2)) |

**(d) Atkinson redraws** (generate_permutations_atkinson_internal)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: rebuild X_w'X_w and invert it with FullPivLU per (b, t) | O(r·n²·p² + r·n·p³), memory O(n²p) | — | Atkinson 1982 (Biometrika 69(1)) |
| **Schur complement**: precompute C_t^-1 = (Z_t'Z_t)^-1 once per t (w-independent); keep b = Z'w incrementally; s = 1/(n_T − b'C^-1b); the needed row is s·[1, −(C^-1b)'] | O(r·n·p²) and O(np²) memory: about **n×** fewer operations (e.g. ~200× at n=200, theoretical) | must reproduce the "singular → 0.5" fallback (FullPivLU's rank threshold against s → ∞); ULP-level differences in p could flip a draw when a uniform lands within 1e-15, so not bit-identical | standard block inversion |
| Sherman–Morrison update of the full inverse across t | O(r·n·p²) | numerical drift over many rank-1 updates; w enters the cross terms, so updates are needed per replicate anyway | Sherman & Morrison 1950 [cite needed] |

**(e) Per-arrival covariate preprocessing in sequential designs** (add_one_subject, covariate_impute…)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: full missRanger/missForest over all t rows (with y) plus a model.matrix rebuild on every arrival | O(n) random-forest imputations; O(n²p) rebuilds | past subjects' imputed covariates **change over time** (the reservoir distances move); consumes RNG on every arrival | Stekhoven & Bühlmann 2012 (Bioinformatics 28(1)) |
| Impute only the new row from a stored forest, refit every k arrivals | ~k× fewer forest fits | imputations differ from current behaviour; needs storing a model | — |
| Missing-indicator plus mean/mode imputation for baseline covariates (design-time only) | O(p) per arrival | less efficient balance on the imputed covariates; the design's matching changes | White & Thompson 2005 (Stat. Med. 24(7)) |
| Append to a model matrix incrementally (no rebuild) when no new factor levels or columns appear | O(p) per arrival instead of O(tp) | must detect new levels or columns and then rebuild | — |

**(f) Turnbull NPMLE** (turnbull_npmle_group_stat)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: `interval::icfit` self-consistency EM, R, dense A | baseline; EM converges sublinearly near the boundary (masses → 0) | slow inside resampling loops; no weights argument (which blocks the Bayesian bootstrap) | Turnbull 1976 (JRSS-B 38(3)) |
| `icfit(..., initfit = "initEMICM")` (interval exports `initEMICM`; Icens is already an interval dependency) | EMICM converges in far fewer iterations; EM then only polishes | Icens is pure R; still no weights | Wellner & Zhan 1997 (JASA 92(439)) |
| `icenReg::ic_np` (EMICM in C++, **has a `weights=` argument**; icenReg is already used by EDI) | likely the largest constant-factor gain | different convergence tolerance (1e-10); the NPMLE mass allocation can be non-unique, so median and RMST must be A/B'd | Anderson-Bergman 2017 (J. Stat. Software 81(12)); Gentleman & Geyer 1994 (Biometrika 81(3)) for non-uniqueness and KKT checks |
| ICM alone | fast early progress | can stall; usually paired with EM | Groeneboom & Wellner 1992 (*Information Bounds and Nonparametric MLE*, Birkhäuser) |
| Support reduction | fast, exact KKT | implementation cost | Groeneboom, Jongbloed & Wellner 2008 (Scand. J. Stat. 35(3)) |

**(g) Breslow hazard and inversion** — current O(nK) scans against a reverse `cumsum` of sorted risk with event grouping (O(n log n)) and `findInterval` (O(n log K)). Both are exact and give identical output; the only risk is tie-grouping parity with `y_o == t_k` (use `rle`/`match` on the sorted times). Breslow 1974 (Biometrics 30(1)).

**(h) Delta-method gradient** (marginal_estimand_delta_se)

| option | speed / accuracy | disadvantages | citation |
|---|---|---|---|
| **Current**: central differences, absolute eps = 1e-5 | 2p functional evaluations; error O(eps²) plus rounding O(ε_mach/eps); not scale-aware | inaccurate when coefficients are large or small | — |
| Analytic: d/dβ mean(exp(X_aβ)) = mean(μ_ai·x_ai); quotient rule for the log-ratio | one O(np) pass; exact | per-functional derivation (only two functionals here) | standard |
| Complex-step differentiation | machine-precision gradient | needs complex-safe functionals (exp is fine); unusual in R | Squire & Trapp 1998 (SIAM Review 40(1)) |

**(i) Logistic separation handling** (fast_logistic_regression_with_var, gcomp drop rule)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: detect ‖β‖ > threshold, drop the covariate with the largest coefficient, refit (≤ p fits) | up to p refits | ad hoc model selection; the treatment column can still separate; the detection threshold is heuristic | — |
| LP separation detection before fitting | one LP; certifies (quasi-)separation exactly | needs an LP solver; still requires a policy for what to do next | Konis 2007 (DPhil thesis, Oxford) |
| Firth / Jeffreys-penalized likelihood | one fit, always finite | **changes the estimator** (bias-reduced), so the estimand and CI differ; not a drop-in | Firth 1993 (Biometrika 80(1)); Kosmidis & Firth 2021 (Biometrika 108(1)) |
| Weakly informative prior (Cauchy) | one fit | changes the estimator | Gelman et al. 2008 (Ann. Appl. Stat. 2(4)) |
| Exact logistic regression | valid under separation | exponential cost; only small n | Mehta & Patel 1995 (Stat. Med. 14(19)) |

**(j) Robust sandwich**

| option | cost | disadvantages | citation |
|---|---|---|---|
| **Current**: HC0 | O(np²) | anti-conservative at n in the tens | White 1980 (Econometrica 48(4)) |
| HC2 / HC3 | +O(np²) for leverages | slightly wider CIs | MacKinnon & White 1985 (J. Econometrics 29(3)); Long & Ervin 2000 (Am. Stat. 54(3)) |
| `chol2inv(chol(XtWX))` instead of `solve` | ~2× fewer flops, more stable for SPD input | none; negligible at p in the tens | — |

**(k)/(l) Restricted-randomization draws in R** (randomizr `replicate`; generic sequential loop for the urn design)

| option | speed | disadvantages |
|---|---|---|
| **Current**: `replicate(r, randomizr::*_ra)` | R overhead per draw dominates (ms × r) | slow for r in the thousands |
| Existing C++ `generate_permutations_blocking_cpp` (and cluster variants) | ~O(rn) native | different RNG stream (draws not identical); **must match randomizr's odd-block-size rounding rule** or the design distribution changes |
| Urn: C++ kernel with running counts | O(rn) instead of O(rn²) R work | new kernel; RNG stream differs (the distribution is the same) |

**(m) Autotuning search** (tune_EDI_for_this_machine)

| option | speed vs current | disadvantages | citation |
|---|---|---|---|
| **Current**: per-axis exhaustive A/B against the incumbent; unpaired median±2·IQR rule; fixed reps | baseline | ignores the pairing that interleaving provides; no multiplicity control (false accepts across hundreds of cells); no interaction between axes | — |
| Paired analysis of interleaved differences (sign test or Hodges–Lehmann on a_i − b_i) | same timing runs; higher power or fewer reps | none material | — |
| Racing (F-Race / irace): drop candidates once statistically dominated | fewer reps on losers | more complex control flow | Birattari et al. 2002 (GECCO); López-Ibáñez et al. 2016 (Oper. Res. Perspectives 3) |
| Successive halving | budget-optimal for many candidates | wasteful with only 2–3 candidates per axis (EDI's case) | Jamieson & Talwalkar 2016 (AISTATS) |
| Bayesian optimization (SMAC) over joint axes | captures interactions | heavy; overkill for a few binary or categorical axes | Hutter, Hoos & Leyton-Brown 2011 (LION) |

**(n) Simulation Monte Carlo budget** — current fixed Nrep against a precision-targeted Nrep (stop a cell when the Monte Carlo SE of coverage or power falls below a target). The precision-targeted option saves reps in cells with p far from 0.5. Disadvantages: unequal Nrep across cells complicates comparison and resume keys; the stopping rule introduces small bias. Koehler, Brown & Haneuse 2009 (Am. Stat. 63(2)); Morris, White & Crowther 2019 (Stat. Med. 38(11)).

**(o) ZOIB fitting** — 0s and 1s are **observed**, not latent, so the log-likelihood factorizes into a multinomial logit on {0, 1, interior} (γ0, γ1, concave) plus a beta regression on interior observations (β, φ). The parameters are disjoint and the Hessian is block-diagonal (Ospina & Ferrari 2012, Comput. Stat. Data Anal. 56(6)). Options:
- Current joint L-BFGS: baseline.
- Two separate fits (Newton on the concave multinomial part; the existing beta-regression kernel): smaller, better-conditioned problems; exact MLE, so a deterministic drop-in to tolerance. It needs the C++ kernel and inference_proportion_zero_one_inflated_beta.R touched (outside this group).
- Audit row B's EM proposal does not apply to ZOIB, because there is no latent class. It does apply to ZIP and ZINB.

**NEW families introduced** (beyond A–M): NEW-restricted-randomization-draw, NEW-balanced-partition, NEW-covariate-imputation, NEW-npmle-interval-censored, NEW-separation, NEW-sandwich-variance, NEW-numerical-derivative, NEW-collinearity, NEW-step-function, NEW-nonconcave-multistart, NEW-linear-algebra-setup, NEW-autotuning, NEW-sim-mc (13).

### New TODO candidates
1. **Exact enumeration solver for DesignFixedOptimal** (quadratic / l1 / ratio kinds), replacing the GLPK path for n ≤ ~30.
   - Where: new C++ kernel; dispatch in helper_optimal_annealing.R:117 `optimal_solve_auto`; replaces helper_optimal_milp_solvers.R:144/175 within range.
   - Algorithm: revolving-door Gray code over n_T-subsets with O(p) incremental objective on the rank-p factor (z = Mw, or z_P, z_H, or v = Aw); mirror halving at prob_T = 0.5; OpenMP by prefix.
   - Expected win (theoretical): n=25 from 311 s (measured GLPK) to ~ms; exact certificate extended from n≈20 to n≈30–32.
   - Risk: exponential wall; ties need a deterministic tie-break.
   - Gate: deterministic exact, so the existing brute-force exactness tests suffice; no A/B needed.
2. **Tighten the quadratic MILP** for n beyond enumeration and for commercial backends (helper_optimal_milp_solvers.R:144).
   - Sign-pruned McCormick rows.
   - RLT-1 rows Σ_{j≠i} y_ij = (n_T−1)w_i.
   - Symmetry cut w_1 = 1 at prob_T = 0.5 for the quadratic and l1 kinds, also applicable to :121. Never for the ratio kind; assert invariance numerically.
   - Orbit ordering for duplicate covariate rows.
   - Optional low-rank outer-approximation / MIQP formulation for Gurobi/CPLEX.
   - Expected win (theoretical): large node-count reduction; the optimum is unchanged.
   - Risk: GLPK gains are unmeasured. Needs the benchmark harness (speed only); correctness is deterministic.
3. **Atkinson redraw kernel via Schur complement** (src/generate_permutations.cpp:80-121, 240-292; called from design_seq_one_by_one_atkinson.R:115).
   - Cost goes from O(r·n²·p²) to O(r·n·p²); memory from O(n²p) to O(np²). Theoretical ~n×.
   - Risk: reproduce the singular → 0.5 fallback threshold. Draws are identical except for ULP-boundary uniforms.
   - **Adopt**: golden test at tolerance on the distribution of w, not bit-identity.
4. **Annealing: final 1-swap steepest-descent polish plus an n-scaled move budget** (design_optimal_annealing_search.cpp:186-246; profiles in design_fixed_optimal.R:513-527).
   - Matters most for the BRT replicate profile (2k moves, 1 chain).
   - Expected win: better objective at equal time; guarantees a 1-swap local optimum.
   - Risk: longer runtimes at large n.
   - Needs the A/B harness (objective at fixed time). Composes with quantum_upgrade.md TODO-5.
5. **Reformulate the optimal-blocks MILP** (design_fixed_optimal_blocks.R:383): continuous z; drop the z ≤ x rows when min(D) ≥ 0; add x_ik = 0 for k > i (or a label-free clique-partition model). Expected: removes most of the B! symmetry and 2/3 of the rows (theoretical). Deterministic optimum; benchmark only.
6. **Turnbull NPMLE via EMICM** (helper_inference_survival_turnbull.R:137): first `icfit(initfit="initEMICM")` (no new dependency), then `icenReg::ic_np`. The `weights=` argument of `ic_np` also unblocks the Bayesian bootstrap under interval censoring, which inference_survival_km_diff.R and inference_survival_rmst.R currently reject. Expected: many-fold fewer iterations (theoretical). Risk: NPMLE non-uniqueness can move the median or RMST. Needs A/B on statistic values.
7. **Breslow cumulative hazard via reverse cumsum, inversion via `findInterval`** (helper_survival_fits.R:571, 592, 617). O(nK) → O(n log n) per parametric-bootstrap replicate. Deterministic drop-in (**Adopt**). Fix incidental #3 in the same change.
8. **Analytic delta-method gradient** for the Poisson-family marginal estimands (helper_marginal_estimand.R:64, 109). 2p evaluations → 1 pass, exact instead of O(eps²). Deterministic (**Adopt**); SE agrees with the current value to ~1e-8 relative.
9. **Stop the full per-arrival re-imputation and model-matrix rebuild** in sequential designs (design_seq_one_by_one_abstract.R:118-120 → design_abstract.R:1018). Rebuild only when a column or level changes or new missingness appears; otherwise append a row. Win: O(n²p) → O(np), and n random-forest imputations → a few. Risk: imputed values for past subjects stop drifting (arguably more correct). Changes design output, so it needs the A/B harness.
10. **C++ draw kernel for the urn design** (O(rn²) R → O(rn)), and either a C++ kernel or a corrected generic loop for RandomBlockSize (design_seq_one_by_one_abstract.R:190; see incidental #2). The RNG stream changes but the distribution is the same; needs a distributional check.
11. **Use the existing C++ block and cluster draw kernels instead of `replicate(randomizr::…)`** (design_fixed_blocking.R:192, design_fixed_optimal_blocks.R:261, design_fixed_cluster.R:108, design_fixed_blocked_cluster.R:135). Win: removes per-draw R overhead (theoretical 10–100× at large r). Risk: odd-block-size rounding must match randomizr. Needs a distributional check.
12. **Tuning harness: paired-difference acceptance plus racing** (local_machine_tuning_harness.R:269; axes :61/:441). Same or fewer reps with fewer false accepts. Needs a self-check against seeded synthetic timings; no change to package results.
13. **Seed Dinkelbach** with the annealing incumbent's ratio (helper_optimal_milp_solvers.R:188). Fewer outer MILPs; deterministic optimum. Low priority once TODO-1 exists.
14. **Investigate factorized ZOIB fitting** (multinomial logit plus beta regression; C++ kernel and inference_proportion_zero_one_inflated_beta.R). Deterministic MLE to tolerance. Also re-scope audit row B so its EM proposal covers ZIP and ZINB only.

### Incidental findings (optional)
1. design_fixed_optimal.R:512-527 — In BRT replicate mode the mechanism is re-solved by annealing with 2000 moves and 1 chain. The observed w* came from the exact MILP, or from annealing with 20000 moves × 4 chains. The reference distribution therefore replays a **weaker mechanism than the one that produced the observed allocation**. This is a validity concern for the bootstrap randomization test, not just speed.
2. design_seq_one_by_one_random_block_size.R:121 used by the generic design_seq_one_by_one_abstract.R:190:
   - `strata_states` is an environment, and `duplicate()` is a shallow `clone()` (design_abstract.R:903). Redraws therefore mutate the **original** design's queues.
   - Queues are never reset between replicates, so replicate j starts mid-block.
   - `assign_wt` reads `Xraw[private$t, ]`, but the generic loop never advances `private$t`, so every position uses the last subject's stratum.
   - Result: randomization draws for this design are not from its distribution. Likely a real bug; verify.
3. helper_survival_fits.R:592-611 — `.cox_simulate_stratified` normalizes the per-stratum Breslow hazard with exp(η − max_stratum η) (inside `.breslow_hazard`), but normalizes subject risk with exp(η − max_global η). Simulated hazards are scaled by exp(max_s − max_g) ≤ 1, so event times come out too long in strata that do not contain the global max η, whenever b_null ≠ 0.
4. globals.R:281 `weighted_cox_bootstrap_surrogate_fit` uses `survival::coxph`'s default **Efron** ties, while `fast_coxph_regression` is documented as **Breslow**. With tied times, the Bayesian-bootstrap distribution is centered on a different estimator. Feed this into audit row L. Also, helper_glm_fit.R:1428 uses `glmnet(lambda=0)` as an unpenalized-Cox fallback; a single lambda of 0 is discouraged by glmnet.
5. helper_robust_regression.R:132-136 — the comments say `#default`, but `maxiter = 100` is not survreg's default (30). The restarts are a cumulative random walk (`init += rnorm`) with no data scale.
6. design_fixed_rerandomization.R:238-251 has three problems:
   - For prob_T ≠ 0.5 it uses Bernoulli `rbinom`, so n_T is not fixed; the other paths use complete randomization.
   - There is no draw cap, so a tight cutoff can loop forever.
   - `abs(det(S)) < 1e-10` (:224, :167) is a scale-dependent singularity test; use `rcond`.
7. helper_zoib.R:88 `.fit_zero_one_inflated_beta` has no callers in R/. Its numDeriv fallback (:146-155) differentiates `.neg_loglik_zoib`, which has **intercept-only** inflation, while the C++ fit uses X_zero_one covariates; the lazy default `X_zero_one = X` is evaluated before the intercept is added. The fallback vcov and the parameter names would be wrong whenever ncol(X_zero_one) ≠ 1.
8. helper_model_matrix.R:121-128 `drop_highly_correlated_cols` kills `unique(pairs[,2])` in one shot. With chained correlations (a~b, b~c, not a~c) it drops both b and c. The fix is to drop one column at a time.
9. design_seq_one_by_one_pocock_simon.R:161-209 — `ensure_factor_metadata` rescans all of Xraw on each call and runs twice per arrival, plus once per row in `draw_ws_raw` (:139-141). That is O(n²k) total; it could track only the new row.
10. helper_glm_fit.R:2004 `clogit_helper` passes a no-intercept X (column 1 = treatment difference, column 2 = first covariate) to `fast_logistic_regression_with_var`. Its separation-drop rule protects columns 1–2 on the assumption that they are intercept and treatment. So in clogit the first covariate can never be dropped, and with p=1 the rule stops immediately.
11. simulations_framework.R:4128-4134 — the survival "true estimand" multiplies the Weibull mean difference by (1 − prob_censoring/2). The true mean difference of event times does not depend on censoring. Verify this is intended.
12. design_abstract.R:1100-1139 — the `all_subject_data_cache` keeps per-t copies of ~4 t×p matrices: O(n²p) memory (~160 MB at n=1000, p=10). generate_permutations.cpp:248-270 keeps an O(n²p) `step_data` for Atkinson.
13. design_abstract.R:1058-1063 — sequential designs include y in the covariate imputation and re-impute all past rows on every arrival. Earlier subjects' imputed covariates, and therefore KK distances, drift as responses arrive.
14. Minor:
    - helper_inference_survival_turnbull.R:163-166: the RMST R loop could be `sum(head(surv,-1)*diff(times))`.
    - design_fixed_rerandomization.R:180: a full `order()` where a partial selection would do.
    - globals.R:265: `vapply`/`which` per pair is O(n²); `rowsum` would be O(n).

---

## 13. Verification of the incidental findings (2026-10-09, `algorithm_choice_audit.md → TODO-B4`)

Five verifier subagents were each told to *refute* their findings. They
checked code and ran small scripts: pure-R ports, and EDI loaded only via
`pkgload::load_all(compile = FALSE)` against the existing `src/EDI.so`. Nothing
was compiled. The coordinator independently re-ran F8, F9, F15 and F22
(reproduced exactly) and re-read the code for F1/F1b. The per-finding verdict
table is in the parent's "Correctness findings surfaced by the sweep". The
check scripts lived in the session scratchpad and are not preserved; each
report below states enough of its setup to rebuild them.

### 13.1 Designs & RNG (F1–F5)


Execution environment: `pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE)` loaded fine and was used for F1 and F5. F2 and F4 are pure-R checks. F3 was checked by reading the code and the C++ standard, because nothing could be compiled. Nothing was compiled or built, and no repo file was edited.

---

#### F1: DesignSeqOneByOneRandomBlockSize redraws are wrong
- **Verdict:** CONFIRMED (every part), plus two related bugs found along the way (F1b, F1c).
- **Evidence:**
  - RandomBlockSize does **not** override `draw_ws_raw`. It inherits the generic one at `R/EDI/R/design_seq_one_by_one_abstract.R:190-204`. The loop there is `for (t in 1 : private$t){ private$w[t] = self$assign_wt() }`. That `t` is a local variable, and `private$t` stays at n. `assign_wt()` (`design_seq_one_by_one_random_block_size.R:121-141`) computes the stratum key from `private$Xraw[private$t, ]`, which is always the **last** subject's row. So every redrawn position pops from the last subject's stratum queue.
  - The C++ kernel `random_block_size_redraw_w_cpp` (`src/random_block_size_speedups.cpp:12`) takes per-row strata keys correctly, but it is **dead code**: nothing calls it except `RcppExports.R`. The same is true of `spbr_redraw_w_cpp` and `shuffle_cpp`. SPBR, by contrast, overrides `draw_ws_raw` with `generate_permutations_spbr_cpp` (`design_seq_one_by_one_spbr.R:119-130`), so SPBR is not affected.
  - Queue sharing: `private$strata_states = new.env(...)` (`random_block_size.R:105`). `Design$duplicate()` is `self$clone()`, which is shallow (`design_abstract.R:898-906`). Even a deep R6 clone does not copy plain environments. `prepare_for_resampling_replay()` is a no-op for this class (`design_abstract.R:740`). The result: redraws start from the real experiment's leftover partial block, each replicate continues from the previous replicate's leftover, and the original design's queue is mutated.
  - Execution check `scratchpad/verify/f1_rbs_redraw.R`. I used `block_sizes = c(4,4)` because of F1b.
    - A (unstratified, n=10): `duplicate()` shares the env (`TRUE`). The original's queue changed from `0,1` to `1,0` after redrawing on the duplicate. The fraction of 2000 redraws with block 1 (positions 1-4) exactly balanced was **0.757**, and 0.761 for block 2. The design rule, confirmed by fresh-design simulation, gives **1.000 / 1.000**. Replicates alternate phase because 10 mod 4 = 2, which is why about half are misaligned.
    - B (strata a/b sized 12/4, last subject in b): the real `w` is exactly balanced within each stratum. Redraws are exactly balanced within stratum a only **0.507** of the time, and within b 0.507 (rule: 1.000). Every redraw (**1.000**) is balanced in consecutive *overall* 4-blocks. That is the signature of one queue that ignores strata.
  - **F1c (extra):** the generic `draw_ws_raw` overwrites `private$w` on the object it runs on. Calling `des$draw_ws_according_to_design(5)` directly on the user's design changed `get_w()` (`identical(...) = FALSE` in check A). Inference callers go through `duplicate()`, which protects `w` but not the shared env.
  - **F1b (extra, real):** `current_block_size = sample(private$block_sizes, 1)` (`random_block_size.R:129`) hits R's `sample()` gotcha. With a single block size, e.g. `block_sizes = 4`, it samples from `1:4`. Sizes 1 and 3 then give `round(0.5)=0` and `round(1.5)=2` treated (R rounds half to even). The real design's own assignments therefore are not blocked. In `f1_debug.R`, blocks of length 1 and 3 appear, and fresh designs had positions 1-4 balanced only 70% of the time and positions 5-8 only 54%. This passes the constructor's `bs*prob_T` validation, which checks only the declared sizes.
- **Severity if real:** Randomization-inference p-values and CIs (and BRT redraws) for `DesignSeqOneByOneRandomBlockSize` use the wrong reference distribution. The effect is worst when `strata_cols` is supplied, which defeats the design's own stratification. This happens on the default redraw path for this design. F1c is a state-mutation hazard for a public method. F1b corrupts the actual assignment whenever `length(block_sizes) == 1`; the default `c(4,6,8)` is not affected.
- **Fix sketch:** Override `draw_ws_raw` in RandomBlockSize the way SPBR does: compute per-row strata keys and call `random_block_size_redraw_w_cpp` (it already exists), or a `generate_permutations_*` variant, `r` times, using fresh queues. Or save and restore `private$t`/`w` and use a fresh local queue env per replicate. Replace `sample(private$block_sizes, 1)` with `private$block_sizes[sample.int(length(private$block_sizes), 1L)]`.
- **Existing coverage:** none. `test-designs.R` "DesignSeqOneByOneRandomBlockSize works" only checks `0 <= sum(ws[1:4]) <= 4`, which is vacuous. The strata-bootstrap golden test covers bootstrap indices only, not redraws.

---

#### F2: `.cox_simulate_stratified` normalizes baseline by stratum max but risk by global max
- **Verdict:** CONFIRMED.
- **Evidence:** `R/EDI/R/helper_survival_fits.R:592-615`.
  - `risk_i = exp(eta - max(eta))` uses the global max M_g.
  - `.breslow_hazard(y[idx], ..., X[idx,], b_null)` (`:571-590`) internally uses `exp(eta - max(eta[idx]))`, so the returned cumhaz equals exp(M_s)·H0_s(t).
  - Inversion `cumhaz >= -log U / risk_i` is equivalent to H0_s(T)·exp(eta_i) ≥ E·exp(M_g − M_s). The effective hazard is therefore scaled down by exp(M_s − M_g) ≤ 1, which gives event times that are too long in every stratum without the global max. Many targets overshoot the last cumhaz and are set to `max_time = 2*max(y)`. For uncensored subjects (`C_i = Inf`) these become **events tied at max_time**.
  - The unstratified `.cox_simulate_from_breslow` is consistent, because both sides use the global max.
  - Pure-R check `scratchpad/verify/f2_cox_strat_sim.R` evaluates the verbatim source functions against a corrected per-stratum normalization. Setup: 2 strata, n=400, b_null=(0,1), max eta 1.23 vs 4.75.

    | Quantity | EDI | Corrected |
    |---|---|---|
    | Stratum-1 event rate (stratum 2) | 0.785 (0.865) | 0.870 (0.865) |
    | Stratum-1 median y_sim | 12.8 | 0.485 |
    | Stratum-1 fraction at max_time | **0.614** | 0.005 |
    | Mean stratified-Cox β_x refit on simulated data (truth 1) | **0.635** | 0.991 |
- **Severity if real:** The parametric-bootstrap LR null distribution (p-values and CIs from `simulate_under_lik_null`) is miscalibrated for:
  - `InferenceSurvivalStratCoxPHRegr` when stratified (`inference_survival_strat_cox.R:344`)
  - `InferenceSurvivalKKStratCox*` (`inference_survival_KK_strat_cox.R:590`). Here the strata are matched pairs plus the reservoir, so almost no stratum holds the global max.

  The bug is inert only when eta is constant: no covariates in `X_fit` and delta = 0. It is active with covariates, which are included whenever `X_cov` is non-empty, and at delta ≠ 0 during CI inversion. Because the scaling is constant within each stratum, the treatment-null structure is preserved. The damage is to the nuisance structure, censoring, and ties, so the effect on p-values was not quantified. It is a non-default option (LR parametric bootstrap).
- **Fix sketch:** Inside the stratum loop, use `r_s = exp(eta[idx] - max(eta[idx]))` for subject risk. Alternatively, have `.breslow_hazard` take a normalization constant and pass the global max.
- **Existing coverage:** none. `test-parametric-bootstrap-lr-smoke-families.R` is a smoke test with no calibration check.

---

#### F3: `std::shuffle` / `std::uniform_int_distribution` make draws stdlib-dependent
- **Verdict:** CONFIRMED (from the standard and the code; I could not run the same seed on two platforms without compiling).
- **Evidence:**
  - **What the standard says.** [rand.dist.general]/3: "The algorithms for producing each of the specified distributions are implementation-defined." This covers `uniform_int_distribution`, `uniform_real_distribution` and `bernoulli_distribution`. [alg.random.shuffle] specifies only that each permutation is equally likely, not the algorithm or how many URNG calls it makes. In practice libstdc++ and libc++ differ: for example, libstdc++'s `std::shuffle` draws two indices per URNG call when the URNG range is ≥ n², while libc++ uses plain Fisher-Yates through its own `uniform_int_distribution`. libstdc++'s `uniform_int_distribution` algorithm has also changed across GCC releases. So the same `RRng` word stream maps to different permutations under libc++ (macOS CRAN) and libstdc++ (Linux), and possibly across GCC versions.
  - **What `RNG.h` claims (`:16-26`).** It claims portability for the raw `RRng` stream only, which is true. The overclaims are elsewhere:
    - `rerandomization_helpers.cpp:34-40` explicitly rejects `std::default_random_engine` for being implementation-defined and promises "a real cross-platform guarantee". Then `shuffle_vec` (`:49-54`) uses `std::uniform_int_distribution` anyway.
    - `generate_permutations.cpp:126-133` and `:438-444` say "a given seed produces identical draws in R and in any future binding". The same claim appears in the roxygen in `RcppExports.R` and in `man/generate_permutations_matching_cpp.Rd`.
  - **Sites:**
    - `std::shuffle`: `generate_permutations.cpp:191` (iBCRD), `:211` (blocking), `:427` (SPBR); `fast_shuffle.cpp:12`; `optimal_design_search.cpp:119`; `spbr_speedups.cpp:35,76`; `random_block_size_speedups.cpp:39`.
    - `uniform_int_distribution`: `rerandomization_helpers.cpp:51,243,292`; `design_fixed_greedy.cpp:103,146-147,172` (+ `bernoulli_distribution:148`); `design_optimal_annealing_search.cpp:107,176-178` (+ `uniform_real_distribution`); `spbr_speedups.cpp:59,71`; `random_block_size_speedups.cpp:22`.
  - **Reachability from public APIs:**
    - `DesignFixediBCRD` and `DesignSeqOneByOneiBCRD` (`generate_permutations_ibcrd_cpp`), for both the initial assignment (`design_fixed_abstract.R:53`) and redraws. iBCRD is the documented "classical complete randomization reference design".
    - `DesignFixedBlocking` (`generate_permutations_blocking_cpp`) and `DesignSeqOneByOneSPBR`.
    - `stratified_bootstrap_indices_cpp`, which is the default bootstrap for BlockingStructure designs and for SPBR/RandomBlockSize with strata.
    - The greedy, rerandomization, and optimal/annealing design searches.
    - Dead code: `shuffle_cpp`, `spbr_redraw_w_cpp`, `random_block_size_redraw_w_cpp`.
- **Severity if real:** Reproducibility only. The distributions are still correct. The same `set.seed` gives different assignments, permutation/bootstrap draws, and therefore p-values/CIs across macOS/Linux, and possibly across compiler versions. This contradicts the in-code portability claims and the R↔Python parity goal. It affects default paths of the designs listed above.
- **Fix sketch:** Replace `std::shuffle` with a hand-written Fisher-Yates using `edi_rng::bounded_rand(rng, i+1)`, which already exists in `RNG.h`. Replace `uniform_int_distribution` with `bounded_rand`, and `uniform_real`/`bernoulli` with `rng.unif_rand()`. Add a golden-value test of a fixed seed's `generate_permutations_ibcrd_cpp` output so CI on macOS catches regressions.
- **Existing coverage:** none. Seed-reproducibility tests compare runs on the same machine only, and there is no cross-platform golden.

---

#### F4: Per-replicate bootstrap seeds can collide
- **Verdict:** PARTIAL. Collisions are real and give identical replicates in the parametric bootstrap. The finding's numbers are wrong (the true space is 31-bit, so collisions are about twice as likely as claimed), and the practical impact is negligible.
- **Evidence:**
  - Per-replicate seeds are drawn in R:
    - `replicate_seeds = sample.int(.Machine$integer.max, B, replace = TRUE)` at `inference_all_abstract_param_boot.R:598` and `inference_ext_param_bootstrap_estimate.R:171`.
    - `draw$w_seed = sample.int(.Machine$integer.max, 1L)` at `inference_all_abstract_rand_bootstrap.R:698`.
    - The C++ seeds (`seed_from_unif01`, `r_seed_draw.h`) are per thread or per chain, not per replicate.
  - The seed space is 2^31 − 1, not 2^32. P(any collision) ≈ 1 − exp(−B(B−1)/2N) = **0.0230** at B = 1e4; the finding's B²/2^33 gives 0.0116. Simulation in `scratchpad/verify/f4_seed_collision.R` gave 0.0257 over 3000 runs.
  - Param bootstrap: each replicate runs entirely under `with_param_bootstrap_seed` (`param_boot.R:785-796`, which calls `set.seed(seed)`), so a collision yields a bit-identical simulated dataset and LR statistic.
  - BRT: `i_b` comes from the main stream, so a `w_seed` collision only reuses the w-draw stream on a different resample. That is not an identical replicate.
  - The expected number of colliding pairs is about 0.023 at B = 1e4, so the effect on a p-value is at most 1/B.
- **Severity if real:** Negligible or cosmetic. Strictly, replicates are not exactly i.i.d., but the effect on p-values and CIs is far below Monte Carlo error. It affects the `*ParamBootstrap*` LR/estimate paths for all likelihood families.
- **Fix sketch:** Sample without replacement (`sample.int(.Machine$integer.max, B)`), or derive seeds as `base + b`. Alternatively, use L'Ecuyer substreams (`parallel::nextRNGStream`).
- **Existing coverage:** none, and none is needed.

---

#### F5: Studentized and smoothed BRT CI/p-value paths are unseeded
- **Verdict:** REFUTED (serial path, `num_cores = 1`).
- **Evidence:**
  - Every draw-generation site calls `set.seed(private$seed)` when a seed is set:
    - p-value studentized branch: `inference_all_abstract_rand_bootstrap.R:512-520`
    - p-value smoothed branch: `:543-551`
    - SMC branch: `:577-585`
    - default path in `approximate_rand_bootstrap_distribution_beta_hat_T`: `:252-260`
    - CI common-random-numbers draws, shared by all types: `inference_all_abstract_rand_bootstrap_ci.R:142-151`

    The smoothing noise `rnorm` (p-value `:557`, CI `:255`) is drawn afterwards from the same seeded stream.
  - Execution check `scratchpad/verify/f5_brt_seed.R` (`InferenceContinOLS` on `DesignFixediBCRD`, n=40, B=101). For percentile, studentized, and smoothed p-values, and for studentized and smoothed CIs, results were identical twice in each of these setups: same object with `set_seed(7)`; fresh object with `set_seed(7)`; no private seed but `set.seed(5)` before the call.
    - Example: studentized CI (0.0904982, 1.5666) both times; smoothed CI (0.044809, 1.71779) both times.
  - `f5b.R` confirms the results do change with the seed (seeds 1-3 give different p-values) and that the studentized path really ran (se_obs = 0.339; it differs from percentile under seed 1).
  - Remaining nit, not a reproducibility bug in public use: in the smoothed p-value branch, when the caller passes `rand_bootstrap_draws` without `smooth_noise`, the noise `rnorm` is drawn without re-seeding. That is internal or advanced use only. The parallel (`num_cores > 1`) path was not tested here; it uses `clusterSetRNGStream(seed)` (`inference_all_abstract.R:884`).
- **Severity if real:** n/a.
- **Fix sketch:** none needed.
- **Existing coverage:** n/a.

---

| id | verdict | severity | one-line summary |
|---|---|---|---|
| F1 | CONFIRMED (+F1b, F1c) | correctness of rand/BRT p-values and CIs for DesignSeqOneByOneRandomBlockSize (default redraw path); F1b corrupts real assignments when length(block_sizes)==1 | Generic `draw_ws_raw` uses last subject's stratum and a shared, never-reset queue env; redraws are balanced in only ~51-76% of cases vs 100% under the design; `sample(block_sizes,1)` gotcha; the C++ redraw kernel exists but is never called |
| F2 | CONFIRMED | correctness of param-bootstrap LR p-values/CIs for stratified Cox classes (non-default option; active with covariates or delta≠0) | Baseline normalized by stratum max, risk by global max; 61% of stratum-1 sims tied at max_time; refit β_x 0.635 vs 1 |
| F3 | CONFIRMED (standard + code) | reproducibility only (cross-platform/stdlib); default paths of iBCRD, Blocking, SPBR, blocking bootstrap, search designs | `std::shuffle`/`<random>` distributions are implementation-defined, contradicting in-code "cross-platform guarantee" comments |
| F4 | PARTIAL | negligible | Seeds are 31-bit (P(collision)≈2.3% at B=1e4, not 1%); a param-bootstrap collision gives an identical replicate, but the impact is ≤1/B |
| F5 | REFUTED | n/a | All studentized/smoothed BRT p-value and CI paths call `set.seed(private$seed)`; execution shows identical repeat results |

### 13.2 Rank & exact tests (F6–F10)


How I checked: by reading the code and running small scripts. I loaded EDI source with
`pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE)`, which loaded without errors because
`src/EDI.so` (2026-10-08 18:05) is newer than every .cpp file checked here. I compiled nothing.
All scripts are in `/tmp/claude-1000/-home-kapelner-workspace-EDI/0c756886-097f-421d-a114-706dc047fb66/scratchpad/verify/`.

---

#### F6: Exact Jonckheere–Terpstra p-value enumerates compositions, which grows exponentially with K, and it cannot be interrupted

- **Verdict:** CONFIRMED. The leaf counts are of the claimed order. The reach is narrower than the finding suggests: the code only runs when the user calls one non-default method or the exported cpp function.
- **Evidence:**
  - `src/fast_jonckheere_terpstra.cpp:82-131`: `recurse_jt_distribution` loops `for (int tk = 0; tk <= max_take; ++tk)` at every level and recurses into `idx + 1`. It has no memoization, so it visits every tuple (t_1..t_{K-1}) with t_k ≤ n_k and Σ ≤ n_T. Called at `:203`. The file has no `checkUserInterrupt`, and grep finds no size guard. A polynomial DP exists and would work: state (idx, treated_seen) → distribution over stat2, because `lower_controls` depends only on that state.
  - Analytic leaf/node counts (DP counter, `f6_jt_count.R`, n_T = n/2, levels split evenly):
    K=5,n=100: 1.56e5 leaves · K=7,n=100: 9.7e6 · K=11,n=100: 7.75e9 · **K=11,n=200: 4.78e12** · K=11,n=400: 3.8e15.
    A realistic skewed 0–10 pain scale with n=200 gives 3.54e12 leaves (3.9e12 nodes).
  - Measured rate on the real function: about 1e8 leaves/s (K=6..9, n=60; for example K=9 took 0.111 s for 9.1e6 leaves).
    Extrapolated: K=11,n=100 takes about 80 s, **K=11,n=200 about 13 hours**, and K=11,n=400 about 1 year. Ctrl-C has no effect during this.
  - **How it is reached:** only through `InferenceOrdinalJonckheereTerpstraTest$compute_exact_two_sided_pval_for_treatment_effect()`
    (`R/inference_ordinal_jonckheere_terpstra_test.R:96-99`, then `compute_exact_jt_components()` at `:191-204`), or the
    exported `exact_jonckheere_terpstra_pval_cpp` (NAMESPACE:150). Neither has an R-side guard on K or n.
    It is **not the default**. The class has components `c("BayesianBootstrap","Wald")` and no `exact_test` capability.
    Both `InferenceSuite` (`inference_suite.R:314`) and the simulation framework
    (`supports_exact_inference` → `supports_inference_capability(inf_obj,"exact_test","InferenceExact")`, simulations_framework.R:2847/3037)
    therefore never call it. A user who calls the documented exact method on a 0–10 scale with n≥200 hangs R with no way to interrupt.
  - **Asymptotic alternative:** it exists as a separate method, `compute_asymp_two_sided_pval()` (normal approximation, `:118-125`).
    The exact method does not fall back to it automatically.
- **Severity if real:** usability and hang (efficiency). Results are not wrong: the enumeration computes the exact hypergeometric distribution correctly.
  Affects `InferenceOrdinalJonckheereTerpstraTest` (explicit exact call only) and the exported cpp function.
- **Fix sketch:** replace the recursion with a DP over (level, treated_seen) carrying a stat2 probability vector, which takes O(K·n_T·max_stat2) time.
  At minimum, add `Rcpp::checkUserInterrupt()` every N leaves plus a guard on the leaf count that falls back to the normal approximation or Monte Carlo with a warning.
- **Existing coverage:** none. JT appears only in BRT/plumbing tests, none with large K.

---

#### F7: `InferenceAllKKWilcoxIVWC` Hodges–Lehmann variance is about 2.09× too small, giving about 82% coverage

- **Verdict:** CONFIRMED (analytically, by Monte Carlo, and end-to-end on the real class).
- **Evidence:**
  - Code: `src/fast_wilcox_hl.cpp:250-266` `estimate_hl_ssq_rank_sum` = var(all y_T−y_C pairwise differences)/(n_T+n_C).
    `:268-285` `estimate_hl_ssq_signed_rank` = var(Walsh averages)/m. R mirrors them in
    `R/inference_all_KK_wilcox_ivwc.R:381-383` (`var(walsh) / m_pairs`) and `:399-400`
    (`var(as.vector(outer(yT, yC, "-"))) / (length(yT)+length(yC))`). The C++ versions are used in the bootstrap IVWC weighting at fast_wilcox_hl.cpp:573-575.
    These are combined into `s_beta_hat_T` at `:355-364` and used by `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`.
  - Correct asymptotics, with τ² = 1/(12(∫f²)²):
    - Two-sample HL: Var = τ²(1/n_T + 1/n_C). Under N(0,σ²), ∫f² = 1/(2σ√π), so τ² = πσ²/3.
      The code gives Var(Y_T−Y_C)/(n_T+n_C) = 2σ²/n. With n_T = n_C = n/2 the truth is 4πσ²/(3n), so the **ratio is π/3 ÷ 1/2 = 2.094**.
      It gets worse when the reservoir is unbalanced, because the code uses 1/(n_T+n_C) instead of 1/n_T+1/n_C.
    - One-sample (Walsh) HL on d ~ N(0,σ_d²): Var = πσ_d²/(3m). The code gives var(Walsh) ≈ σ_d²/2, divided by m, so the **ratio is again 2.094**.
    - Implied coverage at nominal 95% = 2Φ(1.96/√2.094) − 1 = **0.824**.
  - Monte Carlo (`f7_hl_var.R`, 2000 reps, n_T=n_C=60, m=60):

    | Branch | Empirical Var / mean code SE² | Coverage |
    |---|---|---|
    | Rank-sum | 2.17 | 0.807 |
    | Signed-rank | 2.03 | 0.814 |

    Empirical variances match πσ²/3 theory (0.0358 and 0.0337 vs 0.0349).
  - End-to-end (`f7_class_cov.R`): `DesignSeqOneByOneKK14`, n=80, N(0,1) noise, β=1, 300 reps.
    The asymptotic 95% CI of `InferenceAllKKWilcoxIVWC` covered in **80.7%** of reps.
- **Severity if real:** correctness of the SE, CI and p-value (anti-conservative: Type-I error about 18% at nominal 5%). The point estimate is fine.
  Under normality, inverse-variance weights are unaffected because both components are scaled by the same factor. Under non-normal f the factor differs between components.
  Affects only `InferenceAllKKWilcoxIVWC` on the asymptotic path. Its `compute_bootstrap_confidence_interval` is aliased to the asymptotic CI (`:16-18`), so that is wrong too.
  This class is **legacy IVWC (not public-facing per project rules)**.
- **Fix sketch:** use a consistent τ estimate. Simplest: SE = (upper−lower)/(2·z) from `wilcox.test(..., conf.int=TRUE)`'s distribution-free Lehmann interval for each component.
  Alternatively, use a Koul–Sievers–McKean τ̂ with the correct factor (1/n_T+1/n_C) or 1/m.
- **Existing coverage:** none. `tests/testthat/test-wilcox-regr-bootstrap-fast-path.R` checks components against `wilcox.test` estimates, not SE or coverage, and IVWC has no comprehensive_tests coverage rows.

---

#### F8: Ridit score for a level that is interior and missing from the reference arm is ½(R_{k−1}+R_k) instead of P_ref(Y<level)

- **Verdict:** CONFIRMED. It breaks the documented equivalence with Mann–Whitney superiority. The default `reference = "control"` path is affected.
- **Evidence:**
  - `src/fast_ridit_analysis.cpp:75-81` uses `0.5 * (ridit_values[idx-1] + ridit_values[idx])`. `src/ridit_distr_parallel.cpp:59-61` uses `(ridit_scores[idx-1] + ridit_scores[idx]) / 2.0`, which is the same formula in the randomization-distribution kernel.
    The levels table is built from reference-arm levels only (`:30-45`). Below-min (0) and above-max (1) are handled correctly.
  - Algebra: with C = reference mass strictly below level k−1, the code gives C + ¾p_{k−1} + ¼p_k. The correct value is C + p_{k−1}. The **error is ¼(p_k − p_{k−1})**, nonzero unless the neighbouring masses are equal.
  - Hand example (`f8_ridit.R`): control = {1,1,3,3,3,4}, treated = {2,2,3,4,4,4}; level 2 is absent from control.
    - Correct ridit of level 2 = 2/6 = 0.3333. EDI gives 0.375.
    - Mean treated ridit: correct 0.6667, which equals MW P(T>C)+½P(T=C) = 0.6667. **EDI gives 0.6806.**
  - Through the class (`f8_ridit_class.R`): `InferenceOrdinalRidit` with the default control reference, n=40, treated using levels {2..5} and control {1,3,4,5}.
    - `compute_estimate()` = **0.1717**.
    - Mann–Whitney superiority − ½ = **0.2247**. The `InferenceOrdinalJonckheereTerpstraTest` estimate is also 0.2247.
    - A port of the class's own R weighted path (`compute_estimate_with_bootstrap_weights`, `R/inference_ordinal_ridit.R:~118-130`) with unit weights gives 0.2247.
      That path builds ridits over all observed levels with zero mass, which is correct.
    - So the C++ point estimate disagrees with the class's own Bayesian-bootstrap path, and with the doc claim (`R/inference_ordinal_ridit.R:16-22`) that it equals the Mann–Whitney contrast.
  - `reference = "pooled"` cannot hit this, because every level is in the reference. `reference = "treatment"` can, when control has levels missing from the treated arm.
- **Severity if real:** correctness of the estimate, SE and p-value. The randomization distribution is affected too, since `compute_ridit_distr_parallel_cpp` uses the same rule, so the test statistic is not the documented one.
  Affects `InferenceOrdinalRidit` on its default path whenever a non-reference arm has a level that is interior and absent from the reference arm. This is common with many-level scales (for example 0–10) and small arms.
- **Fix sketch:** for a missing interior level, score = cumulative reference mass below it, i.e. `cumulative_p` through `idx-1` = R_{idx−1} + ½p_{idx−1}. This is simplest if the cumulative masses are kept in a vector. Apply the fix in both .cpp files.
- **Existing coverage:** `package_tests/testthat_bulk/test-ordinal-ridit-unweighted-scores-wald-and-fast-kernels-reference.R` has a correct reference (`ref_ridit` uses all levels). Its fixture (4 levels, about 30 controls, probabilities .4/.3/.2/.1) essentially never leaves a level out of control, so the bug is never exercised.

---

#### F9: Newcombe p-value returns 1.0 when it should be < 1e-10

- **Verdict:** CONFIRMED. A second, previously unreported precision problem is also present.
- **Evidence:**
  - `R/inference_incidence_newcombe_univ.R:151-158`: `uniroot(p_fn, interval = c(1e-10, 1 - 1e-10))` is wrapped in `tryCatch(..., error = NA)` and followed by `if (!is.finite(res)) return(1.0)`.
    When δ lies outside even the α=1e-10 Newcombe CI, p_fn has the same sign at both ends, uniroot errors, and the method **returns 1**.
    The roxygen (`:138-140`) wrongly says this means δ is "far inside the interval".
  - Trigger (`f9_newcombe.R`, `InferenceIncidNewcombeRiskDiff` on `DesignFixediBCRD`, δ=0):

    | Data | EDI p | prop.test p | Newcombe CI at α=1e-10 |
    |---|---|---|---|
    | 90/100 vs 10/100 | **1** | 1.1e-29 | [0.349, 0.918] |
    | 180/200 vs 20/200 | **1** | 1.3e-57 | |
    | 250/500 vs 100/500 | **1** | 2.7e-23 | |

    Moderate cases are fine (30/60 vs 20/60 gives 0.0635 vs 0.0641).
  - Additional precision problem (`f9b_newcombe_tol.R`): uniroot uses its default `tol = .Machine$double.eps^0.25 ≈ 1.2e-4`, which is absolute on α.
    p-values below about 1e-3 are therefore inaccurate. Compared with a precise log-scale inversion:
    - 75/100 vs 40/100: EDI p=7.0e-05, precise 4.3e-07 (**162× too large**).
    - 70/100 vs 40/100: EDI 8.5e-05, precise 1.7e-05 (4.9×).
- **Severity if real:** correctness of the p-value. Strong effects are reported as p=1, the opposite of the truth, which is silent and catastrophic for testing/power.
  Affects `InferenceIncidNewcombeRiskDiff$compute_asymp_two_sided_pval`. This is the class's "wald" p-value, so it **is a default path** in `InferenceSuite`.
  The CI method (`newcombe_independent_ci_cpp`) is unaffected. I found no `uniroot` in the KK Newcombe class.
- **Fix sketch:** run the root search on log(α) over [log(1e-300), log(1−ε)] with a tight tol.
  If δ is outside the CI at the smallest α, return that floor (or 0), not 1. If it is inside at α≈1, return 1. Decide the sign at the end points explicitly instead of catching errors.
- **Existing coverage:** `package_tests/testthat_bulk/test-incid-newcombe-hybrid-wilson-score-reference.R:84-88` **pins the bug**:
  `far_delta = beta_hat_T + 0.9; expect_equal(inf$compute_asymp_two_sided_pval(delta = far_delta), 1.0)`. It must be inverted when fixed.

---

#### F10: Zhang exact CI: bracket never checked, errors counted as p=0, stop at |p−α|<0.005

- **Verdict:** PARTIAL. Silent truncation is CONFIRMED and reachable on realistic tables, including every table with a zero cell, where the true bound is infinite.
  "Errors count as p=0" is true in the code but practically harmless. The tolerance stop is CONFIRMED but small in effect.
- **Evidence:**
  - `R/inference_helpers_zhang.R:44-59` `zhang_bisect_ci_boundary`:
    - It never evaluates `p_fn(outside)`. If p(outside) > α, every step sets `inside = mid`, and it returns the bracket end without a warning.
    - `tryCatch(p_fn(mid), error = NA)` plus `if (is.na(p_mid)) p_mid = 0` treats errors and NA as "outside".
    - `abs(p_mid - pval_th) < tol` stops early. `tol = pval_epsilon` defaults to 0.005 (`R/inference_incidence_exact_zhang.R:31`, `inference_all_abstract_exact.R:26`).
    - The bracket (`:211-214`) is the Haldane Wald CI at **2α** (a 90% interval for α=.05) widened by 50% of its width on each side, i.e. est ± 3.29·se.
  - Pure code path, using the package's own `zhang_incid_mle_ci`, `zhang_bisect_ci_boundary` and `zhang_exact_fisher_pval_cpp` (`f10_zhang.R`), on reservoir-only (Bernoulli) tables n11/n10/n01/n00 with α=.05:

    | Table | p at bracket | EDI bound | True bound | Note |
    |---|---|---|---|---|
    | 1/19/6/14 | p(lo bracket)=0.068 | lower −4.953 (the bracket end) | about −5.27 | `f10d.R`: p(−4.95)=0.068, p(−5.26)=0.050, p(−5.27)=0.0498 |
    | 0/20/5/15 | p(lo)=1 | lower −7.661 | **−∞** | |
    | 5/5/0/10 | p(hi)=1 | upper 8.203 | **+∞** | |
    | 9/1/3/7 | p(hi)=0.052 | upper 6.170 | about 6.24 | |

    End-to-end, `InferenceIncidExactZhang$compute_exact_confidence_interval()` on `DesignFixedBernoulli` (`f10b_zhang_class.R`) reproduces exactly [−4.953, 0.032], [−7.661, −0.186] and [0.465, 8.203].
    Truncation always narrows the CI (anti-conservative), and for zero-cell tables it reports a finite number where the bound should be infinite.
  - Errors as p=0: inside the bracket `mid` is always finite. The only practical NA comes from `zhang_combine_exact_pvals` returning NA when both components are 0 or NA (underflow), where p≈0 is true anyway. So this is benign.
    A related quirk: a component that underflows to exactly 0 is dropped (`has_M`/`has_R` require p>0), so the combined p becomes the other component alone. This only matters at extreme δ.
    `incidence-exact-and-score-interval-contracts` and `zhang-exact-incidence-stats...-reference.R:92-93` pin the error-as-0 behavior on purpose.
  - Tolerance: with Wald-like slope, |Δp| ≤ 0.005 maps to |Δδ| ≲ 0.043·se, about 2% of the half-width. Observed shifts were 0.02–0.04 on the log-OR scale (10/40/20/30: −0.030 vs about −0.050; 2/48/9/41: −0.042 vs about −0.001).
    In my examples CI-vs-p(0) consistency held. The two-sided-by-probability Fisher p is discontinuous at δ=0 in balanced arms (`f10c_scan.R`), so "true" bounds there sit exactly at 0.
  - Reach: `InferenceIncidExactZhang$compute_exact_confidence_interval` (the class's "exact" CI, so a default path for that class in `InferenceSuite`).
    The same bisection is used by `inference_ext_quantile_rand_ci.R:40-70`, which uses an asymptotic-CI ±50% bracket and has the same unchecked-bracket issue.
    The incidence randomization-CI dispatch to Zhang is currently disabled (`inference_all_abstract_rand_ci.R:~228`).
- **Severity if real:** correctness of the CI. Too-narrow and finite-instead-of-infinite bounds occur on small or zero-cell tables, which is exactly where exact methods get used.
  The tolerance issue is a minor precision problem. Error-as-0 is benign.
- **Fix sketch:** before bisecting, evaluate p(outside) and expand the bracket geometrically while p(outside) > α, up to a cap.
  Return ±Inf when the cap is hit (with zero cells this is a monotone limit). Tighten the stop rule to interval width only, or use tol around 1e-6.
- **Existing coverage:** `test-zhang-exact-incidence-stats-pvalues-and-ci-search-reference.R` and `test-zhang-exact-ci-parallel-bounds-search-reference.R` use fixtures where the bracket is not binding. No test covers a zero-cell table or a bracket that is too narrow.

---

| id | verdict | severity | one-line summary |
|---|---|---|---|
| F6 | CONFIRMED | efficiency/hang (results correct) | JT exact enumerates about 4.8e12 leaves at K=11,n=200 (about 13 h, cannot be interrupted, no guard); only via the explicit `compute_exact_two_sided_pval_for_treatment_effect()` or the exported cpp, not the suite default; the asymptotic method exists separately |
| F7 | CONFIRMED | SE/CI/p wrong (anti-conservative) | HL SE formulas are π/3÷½ = 2.09× too small in both branches; MC 81%, class end-to-end 80.7% coverage at nominal 95%; legacy IVWC only |
| F8 | CONFIRMED | estimate/SE/p wrong | Interior level missing from the reference gets ½(R_{k−1}+R_k); error ¼(p_k−p_{k−1}); class estimate 0.172 vs MW 0.225 (and vs its own weighted path); default control reference |
| F9 | CONFIRMED (+ extra) | p-value wrong (default path) | uniroot without a bracket returns p=1 for 90/100 vs 10/100 (true about 1e-29); default uniroot tol also inflates small p (162×); an existing test pins p=1 |
| F10 | PARTIAL | CI too narrow / infinite bound reported finite | Unchecked bracket truncates realistic small and zero-cell CIs (−4.953 vs −5.27; −7.661 vs −∞); error-as-0 is benign; the 0.005 tolerance gives about 0.04·se error |

### 13.3 Estimate vs. resampling-path mismatches (F11–F16)


How this was run: EDI source loaded with `pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE)` (the existing `src/EDI.so` loaded fine). Nothing was compiled. Each check took a few seconds to about 2 minutes, with num_cores = 1. All scripts are in `scratchpad/verify/` (`f11_hurdle.R`, `f12_robust.R`, `f12b_robust_nulldraw.R`, `f13_ordinal.R`, `f13b_clmm_stuck.R`, `f14_clogit_glmm.R`, `f15_meandiff_ivwc.R`, `f16_gcomp.R`, `f16b_gcomp_hetero.R`).

The common technique: put the observed assignment `w` in column 1 of a permutation matrix, or use near-unit bootstrap weights (`1 + 1e-3*runif`). The "null draw at the observed assignment" (or the near-unit-weight replicate) should then reproduce the reported estimate exactly. When it does not, the resampling path computes a different statistic.

---

#### F11: KK hurdle-Poisson IVWC uses dummy SEs of 1.0, so the resampled statistic is an equal-weight average

- **Verdict:** CONFIRMED. The problem is wider than reported: it also hits the Bayesian bootstrap (BB) and `compute_estimate(estimate_only = TRUE)`.
- **Evidence:** `R/EDI/R/inference_count_KK_cond_poisson.R`
  - Randomization statistic `compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)` (:206). It calls `fit_hurdle_for_matched_pairs(..., se = FALSE)` (:215). That returns `se = 1.0` from the Rcpp path (:364 `if (!se) return(list(beta_hat = beta_hat, se = 1.0))`) and from the glmmTMB path (:419 `# Return dummy SE > 0`). The reservoir fit returns `ssq_hat = 1` when estimate_only (:449, :470). So `w_star = 1/(1+1) = 0.5`.
  - `compute_estimate_with_bootstrap_weights(..., estimate_only = TRUE)` (:165 `ssq_m = if (!estimate_only) res_m$se^2 else 1.0`, :177 the same for `ssq_r`). The BB driver calls it with `estimate_only = TRUE` in every main-distribution path (`inference_all_abstract_bayesian_bootstrap.R:116,133,205,234,611`). The only exception is the studentized-stat loop at :661. So the **BB distribution is also equal-weight**.
  - `shared(estimate_only = TRUE)` (:274, :284) stores 1.0 for both variances and **caches** the equal-weight `beta_hat_T`. As a result, `compute_estimate(estimate_only = TRUE)` on a fresh object returns a different number from `compute_estimate()`.
  - Execution (`f11_hurdle.R`, n = 60): beta_m = 0.7225 (ssq 0.1069), beta_r = 0.9326 (ssq 0.1237).
    - Reported IVWC estimate: **0.8199**
    - Randomization observed statistic: **0.8275**, which equals the equal-weight average 0.8275
    - Fresh `compute_estimate(estimate_only = TRUE)`: 0.8275
    - BB replicate at unit weights with estimate_only = TRUE: 0.8280, versus 0.8205 with estimate_only = FALSE. Part of that 0.0006 gap is a second, smaller mismatch: weighted matched-pair fits always go through glmmTMB, while the point estimate uses Rcpp. This is documented in the roxygen.
  - It is not intentional. The roxygen for `compute_estimate_with_bootstrap_weights` says it combines "the same inverse-variance way as `$compute_estimate()`". The test `test-kk-hurdle-poisson-ivwc-weighted-and-randomization-combination-branches-reference.R` asserts the IVWC formula in the randomization path, but its mocks return real variances regardless of the `se` flag, so it cannot see the dummy-SE substitution.
- **Severity if real:**
  - Randomization p-value: the observed statistic and the null draws use the same equal-weight rule, so the test is still valid; only power is lost. The randomization CI is valid under the shift model.
  - BB CI and p-value: these are **miscalibrated**, because the BB distribution is of the equal-weight statistic but is centred and compared against the IVWC estimate (percentile, BCa and Wald-from-BB-sd all affected).
  - `compute_estimate(estimate_only = TRUE)` returns the wrong point estimate.
  - Class affected: `InferenceCountKKHurdlePoissonIVWC`. It is exported, but it is a legacy IVWC class. The default Wald CI is unaffected.
- **Fix sketch:** In the estimate-only paths, compute the real variances (pass `se = TRUE` / `estimate_only = FALSE` to the two component fits) whenever both components are usable. If speed matters, fix `w_star` from the observed-data variances and reuse it for every draw.
- **Existing coverage:** none effective. The test above mocks the fits and so misses it.

#### F12: KK robust regression: resampling fits the Huber "M" estimator while the reported estimate is "MM"

- **Verdict:** CONFIRMED for the KK classes, and worse than reported. The C++ `compute_robust_rand_bootstrap_parallel_cpp` part is REFUTED: the non-KK class passes the same `rlm_method` everywhere.
- **What "M" and "MM" mean here** (`src/fast_robust_regression.cpp:60-236`): both start from an OLS fit (ColPivQR) with σ̂ = MAD(OLS residuals)/0.6745 held fixed, then run IRLS. "M" uses Huber weights (c = 1.345). "MM" uses Tukey bisquare (c = 4.685, redescending). So in the default `use_rcpp = TRUE` path, the two are different estimators: a monotone ψ versus a redescending ψ from the same start. In the `MASS::rlm` path, "MM" adds a `lqs` S-estimator start and scale.
- **Evidence:**
  - `inference_continuous_KK_robust_regr_one_lik.R:240` and :305, and `_ivwc.R:248` and :313: `method_to_try = if (estimate_only || ...) "M" else private$rlm_method`. The randomization worker always calls `compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)` (`inference_all_abstract_rand.R:607`), which resolves to `compute_estimate(estimate_only = TRUE)` (:1062). The OneLik BB weighted fit hard-codes `method = "M"` (:485 rcpp, :507 MASS).
  - "Documented" only covers part of it. The `compute_estimate` roxygen says estimate_only "use[s] the faster "M" robust estimator regardless of the method argument". Nothing says the randomization or bootstrap tests a different estimator.
  - **OneLik, call-order-dependent observed statistic** (`f12b_robust_nulldraw.R`, n = 80, t₂ errors):
    - Reported MM estimate: 0.5394
    - Null draw at the OBSERVED assignment: **0.6248**, the Huber estimate
    - The observed statistic in `compute_rand_two_sided_pval` is the cached **MM 0.5394** if `compute_estimate()` ran first (cache hit at `fit_combined` :366), otherwise **M 0.6248**.
    - So in the common order (estimate, then p-value), the test compares an MM observed statistic against an M null distribution. That is a mismatch inside the test itself, not just a mismatch with the reported estimate.
  - **IVWC, randomization p-value is always NA** under the default `use_rcpp = TRUE`:
    - `fit_rlm_with_treatment` returns `ssq = NA_real_` when estimate_only (`_ivwc.R:274`).
    - `shared()` requires a finite `ssq` for both `m_ok` and `r_ok`, so `beta_hat_T = NA`.
    - Execution: every null draw is NA, so `compute_rand_two_sided_pval(r = 199)` returns **NA**, and a fresh `compute_estimate(estimate_only = TRUE)` returns **NA**.
  - The non-KK `InferenceContinRobustRegr` (`inference_continuous_robust_regr.R:189-221, 386-389`) uses `private$rlm_method` in the reported fit, in randomization, and in the C++ randomization/bootstrap kernel. That class is consistent.
- **Severity if real:**
  - `InferenceContinKKRobustRegrOneLik` (public): the randomization p-value and CI compare different statistics, so exactness is not guaranteed and the result depends on call order. The BB is of the Huber estimator around the MM estimate.
  - `InferenceContinKKRobustRegrIVWC` (legacy IVWC): randomization inference is completely broken (NA) on the default path.
  - The default is `method = "MM"`, so both problems are on the default path.
- **Fix sketch:** In estimate_only mode, keep `rlm_method` and only skip the SE. If speed is needed, warm-start the bisquare fit from the cached full-data fit. In the IVWC estimate_only path, still compute the component variances. In OneLik `fit_weighted_combined`, use `private$rlm_method`.
- **Existing coverage:** none. No test runs `compute_rand_two_sided_pval` on either KK robust class with an assertion on the result.

#### F13: Ordinal KK random-effects classes: Bayesian-bootstrap replicates use a fixed-effects fit

- **Verdict:** CONFIRMED.
  - For `InferenceOrdinalKKGLMM` the choice is intentional and documented, but the documentation describes it wrongly.
  - For the CLMM family it is undocumented.
  - Today the CLMM mismatch is masked by an already-tracked bug that makes the CLMM point estimate collapse to the fixed-effects estimate.
- **Evidence:**
  - `inference_ordinal_KK_clmm_abstract.R:169-218` `compute_weighted_clmm_estimate`: for logit it uses `fast_ordinal_regression_weighted_cpp`; for the other links it uses `weighted_ordinal_bootstrap_surrogate_fit` (`MASS::polr`). Neither has a random intercept. The roxygen (:59-62) says only "Recomputes the KK ordinal CLMM treatment estimate under Bayesian-bootstrap weights".
  - `inference_ordinal_KK_combined.R:437-507` (KKGLMM): the roxygen says it uses "an ordinary (non-mixed-effects) weighted cumulative-logit fit, not a reweighted GLMM refit — as a fast approximation to the weighted marginal likelihood". So it is deliberate. But a fixed-effects fit estimates the attenuated marginal log-OR, which is a different parameter from the conditional log-OR the class reports, not an approximation of it. The sibling KKGEE disables BB for the analogous surrogate reason (`inference_ordinal_KK_combined.R:138-142`), so the issue is known in principle.
  - Execution (`f13_ordinal.R`, n = 200, 85 pairs, pair random effect sd 2):
    - `InferenceOrdinalKKGLMM` reports **0.5827**. That agrees with `ordinal::clmm(nAGQ = 20)` at 0.5827 (σ̂ = 1.30).
    - Its near-unit-weight BB replicate is **0.4140**, which matches `ordinal::clm` (fixed effects) at 0.4142.
    - BB median 0.390, 95% interval (−0.10, 0.78).
    - So the BB distribution is centred about 0.19 below the reported estimate.
  - **Side finding, already tracked:**
    - `InferenceOrdinalKKCLMM` reports **0.4143**, which is the fixed-effects value. The cause is the warm start `c(alpha, beta_FE, log_sigma = -3)` (`clmm_warm_start` :267): the fit stops after 1 iteration with log σ = −2.9996 and `converged = TRUE` (`f13b_clmm_stuck.R`).
    - Starting from log σ = 0 with eps_g = 1e-6 gives 0.5835 (log σ = 0.262), which matches `ordinal::clmm`. With eps_g = 1e-3 it gives 0.6175, so `eps_g = 1e-3` also costs accuracy.
    - This is `bug_fix_plans/glmm_variance_component_sigma_collapse.md` (release_v1_0_5 TODO-31). Because of it, the CLMM BB is accidentally consistent with the reported estimate today. Once TODO-31 is fixed, F13 will show up in the CLMM classes exactly as it does for KKGLMM.
    - Also, the CLMM randomization statistic `compute_ri_estimate_rcpp` (:144) cold-starts without the warm start and gives **0.5547** on the same data, not the reported 0.4143. Observed and null are computed the same way, so the test is valid, but it does not test the statistic that is reported.
- **Severity if real:**
  - BB CI and p-value are centred on the marginal estimand, so a conditional-scale CI is shifted toward zero. The size of the shift depends on σ.
  - Classes affected: `InferenceOrdinalKKGLMM` and `InferenceOrdinalKKCLMM`, `...Probit`, `...Cauchit`, `...Cloglog` (public). BB is not the default CI; Wald is.
- **Fix sketch:** Either add weighted random-intercept kernels (weights entering per-group log-likelihood contributions) for the BB, or disable BB for these classes the way KKGEE does. At a minimum, correct the KKGLMM roxygen to say the bootstrap targets the marginal coefficient.
- **Existing coverage:** none for the mismatch. The sigma-collapse is pinned by the tests named in the TODO-31 plan.

#### F14: KK clogit + GLMM: Bayesian-bootstrap replicates fit glmmTMB (Laplace) on all rows

- **Verdict:** CONFIRMED (undocumented).
- **Evidence:**
  - `inference_incidence_KK_cond_logit_glmm_abstract.R:103-151`: the replicate fits `glmmTMB::glmmTMB(y ~ w + covariates + (1|group_id), binomial, weights = .bootstrap_weight__)` on every row (pairs and reservoir), using a Laplace approximation and no conditional-logit block.
  - The point estimate (`shared` → `fast_clogit_plus_glmm_cpp`, :212) combines a conditional logit on discordant pairs with a 20-node GH GLMM on concordant pairs, plus the reservoir only when `combine_reservoir_into_glmm()` is TRUE.
  - So `InferenceIncidKKCondLogitGLMMIVWC` (reservoir excluded from its likelihood) gets **exactly the same BB distribution** as the OneLik sibling. Its replicates use reservoir data its estimator never uses.
  - Execution (`f14_clogit_glmm.R`, n = 200):

    | seed | class | reported | near-unit-weight replicate | BB median | glmer AGQ20 (all rows) |
    |---|---|---|---|---|---|
    | 14 | OneLik | 1.2555 | 0.9102 | 1.206 | 1.044 |
    | 14 | IVWC | 1.2860 | 0.9102 | 1.206 | 1.044 |
    | 141 | OneLik | 0.0018 | 0.3388 | 0.367 | 0.358 |
    | 141 | IVWC | −0.0630 | 0.3388 | 0.367 | 0.358 |

    The BB clearly tracks the all-rows GLMM, not the reported clogit + GLMM estimator.
  - Under correct random-effects normality, both target the conditional log-OR, so this is an estimator mismatch (different efficiency and robustness) rather than a strict estimand mismatch. The clogit block's freedom from distributional assumptions is lost in the BB.
  - The 0.91 vs 1.21 gap between the near-unit replicate and the BB median in seed 14 suggests glmmTMB handles non-integer binomial weights oddly. Not investigated further.
- **Severity if real:**
  - BB CI and p-value are miscalibrated for the reported estimator; the shift can be about 0.35 on the log-OR scale.
  - Classes affected: `InferenceIncidKKCondLogitGLMMOneLik`, `InferenceIncidKKCondLogitGLMMIVWC` (legacy) and `InferencePropKKGLMM`. BB is not the default CI.
  - It also needs glmmTMB, and a TMB tape is built per replicate, which is slow.
- **Fix sketch:** Add a weights argument to `fast_clogit_plus_glmm_cpp` (per-pair weight on the clogit term, per-row weight in the GLMM term) and use it for replicates. Otherwise disable BB for these classes.
- **Existing coverage:** `test-prop-kk-glmm-weighted-refit-reference.R` **pins** the glmmTMB surrogate as the reference. It asserts the current behavior and would not catch the mismatch.

#### F15: Legacy `InferenceAllKKMeanDiffIVWC`: the always-NULL `m_mat` is replaced with zeros, so the null distribution is the plain mean difference

- **Verdict:** CONFIRMED.
- **Evidence:**
  - `inference_all_KK_mean_diff_IVWC.R:155-173`: `if (is.null(m_mat)) m_mat = matrix(0L, nrow = n, ncol = ncol(w_mat))`.
  - `generate_permutations` always returns `m_mat = NULL` (`inference_all_abstract_rand.R:756-759`), and this class does not override it.
  - In `compute_matching_compound_distr_parallel_cpp` (`src/kk_compound_distr_parallel.cpp:50-65`), all-zero match ids mean m = 0 and every row is treated as reservoir, so each draw is the plain treated-minus-control mean.
  - The generic reused-worker path does the right thing: it uses `base_m` when `m_vec` is NULL (`inference_all_abstract_rand.R:565`).
  - Execution (`f15_meandiff_ivwc.R`, n = 100, strong prognostic x1):
    - Reported KK compound estimate: 0.4329
    - Fast-path null draw at the observed w: **0.3487**, which equals the plain mean difference 0.3487
    - Null sd: 0.288 (fast path) vs 0.147 (correct compound null from the reused-worker path, whose observed-w draw is 0.4329)
    - **Shipped `compute_rand_two_sided_pval(r = 400)` = 0.19**
    - The same draws with the compound null give **p = 0.005**
- **Severity if real:**
  - The randomization p-value is wrong: it compares the compound observed statistic with the null of a different, higher-variance statistic. That gives a large power loss (usually conservative, but not exact).
  - Only the delta = 0 fast path is affected; for delta ≠ 0 it returns NULL and falls back to the generic path.
  - Class affected: legacy `InferenceAllKKMeanDiffIVWC`. It is not public-facing, but it is exported and the same component is used by the KK Newcombe IVWC class.
- **Fix sketch:** When `permutations$m_mat` is NULL, fill it with `rep(base m, ncol(w_mat))` (NA → 0) instead of zeros. KK matches depend only on covariates, so they are fixed across re-randomizations.
- **Existing coverage:** `test-kk-mean-diff-ivwc-fast-randomization-distr-and-bootstrap-type-bug-reference.R` ("a NULL m_mat ... reduces to the plain treated-minus-control mean difference") **pins the buggy branch as a documented contract**. It does not notice that this is the branch every real call takes.

#### F16: Non-KK incidence g-computation Bayesian bootstrap averages predictions without the bootstrap weights

- **Verdict:** PARTIAL. The inconsistency is real, but the practical impact is small and the choice is defensible.
- **Evidence:**
  - `inference_incidence_gcomp_abstract.R:77-92` → `weighted_gcomp_effects_from_row_weights` (:580) → `weighted_gcomp_fit` (:514). The logistic fit is weighted, but `compute_standardized_effects_r` (:690) → `gcomp_logistic_potential_outcomes` (`helper_gcomp.R:52-66`) uses `mean(risk1_i)` and `mean(risk0_i)`, which are unweighted.
  - The KK version uses `stats::weighted.mean(..., w_fit)` (`inference_incidence_KK_gcomp_abstract.R:497-498`).
  - No comment or doc explains the difference.
  - The non-KK proportion and ordinal g-comp BB paths also standardize without weights: their C++ point-estimate and post-fit kernels take no weights. So unweighted is the non-KK convention, and KK incidence is the odd one out.
  - Statistically, the unweighted version propagates only β uncertainty and conditions on the observed covariate sample (sample/conditional ATE). That matches the non-KK delta-method SE, which also omits the covariate-sampling term (catalog incidental #16). A standard BB of the functional would weight both steps.
  - Execution (`f16_gcomp.R`, `f16b_gcomp_hetero.R`): the shipped replicate equals the unweighted standardization exactly. BB sd was 0.05671 unweighted vs 0.05671 weighted (n = 200), and 0.0786 vs 0.0795 (n = 100, strong heterogeneity), so the shipped BB is about 1% narrower.
- **Severity if real:** Small. The BB CI is slightly narrow when the target is the population ATE. KK and non-KK siblings target different estimands. Classes affected: `InferenceIncidGCompRiskDiff` and `InferenceIncidGCompRiskRatio`, BB only (not default).
- **Fix sketch:** Pick one estimand convention and apply it everywhere. Either pass weights into `gcomp_logistic_potential_outcomes` (and the proportion/ordinal kernels), or switch the KK version to unweighted. Document the choice next to catalog incidental #16.
- **Existing coverage:** none comparing the two conventions.

---

| id | verdict | severity | one-line summary |
|---|---|---|---|
| F11 | CONFIRMED (wider than reported) | BB CI/pval miscalibrated; randomization only loses power; wrong `compute_estimate(estimate_only=TRUE)` | Dummy SE 1.0 makes the randomization stat, the BB replicates and the estimate-only estimate an equal-weight average (0.8275 vs IVWC 0.8199) |
| F12 | CONFIRMED (KK); REFUTED for the non-KK C++ kernel | Randomization p-value/CI wrong on the default path | OneLik: null = Huber M, observed = MM or M depending on call order; IVWC: randomization p-value always NA (ssq dropped when estimate_only); OneLik BB hard-codes M |
| F13 | CONFIRMED (KKGLMM deliberate, documented but described wrongly; CLMM undocumented) | BB CI centred on the marginal estimand | KKGLMM reports 0.583, BB centred at 0.39 (fixed-effects fit); CLMM masked today by the known sigma-collapse (TODO-31) |
| F14 | CONFIRMED | BB CI miscalibrated (shift ~0.35 log-OR) | BB is glmmTMB Laplace GLMM on all rows; IVWC sibling gets an identical BB even though it excludes the reservoir; a test pins the surrogate |
| F15 | CONFIRMED | Randomization p-value wrong (0.19 vs 0.005), legacy class | NULL `m_mat` turned into zeros makes the null the plain mean difference; a test pins this branch as a contract |
| F16 | PARTIAL | Small (~1% narrower BB); convention inconsistency | Non-KK unweighted standardization vs KK weighted.mean; defensible sample-ATE choice that matches the Wald SE but is undocumented and inconsistent |

### 13.4 Models & likelihoods (F17–F22)


Loading: `pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE)` worked (existing .so). Nothing was compiled or built. Scratch scripts are in `.../scratchpad/verify/` (`f17_zoib.R`, `f17_edi.R`, `f18_cloglog.R`, `f20_gee.R`, `f22_aftsrr.R`, `f22_edi2.R`).

---

#### F17: ZOIB R-side category probabilities use plogis-then-normalize; the C++ likelihood uses softmax
- **Verdict:** CONFIRMED, with one nuance: the Bayesian/weighted-bootstrap replicate path is a different model, explained below.
- **Evidence:**
  - C++ `src/fast_zero_one_inflated_beta.cpp:98-106`: `e0 = exp(eta0 - max)`, `e1 = exp(eta1 - max)`, `eb = exp(-max)`, `pi0 = e0/denom` … This is a 3-category multinomial logit with "mid" as the reference. `params = [beta(p), log_phi, gamma0(q), gamma1(q)]`, and `fast_zero_one_inflated_beta_cpp` returns that vector unchanged as `$params` (`:614/:647`). The R helpers `.softmax_three_from_logits` and `.neg_loglik_zoib` (`R/helper_zoib.R:16,59`) agree with softmax.
  - R `R/inference_proportion_zero_one_inflated_beta.R`:
    - `zoib_mean_from_coefs` (:375-384) does `p0 = plogis(Xz %*% b_zero); p1 = plogis(Xz %*% b_one); p_mid = pmax(1-p0-p1,0)`, then normalizes. Its comment ("raw p0/p1 aren't guaranteed to sum to <= 1") shows the author assumed two independent logits.
    - It is fed the C++ softmax params by `compute_marginal_mean_diff_estimate` (:419-447; point estimate plus delta-method SE) and by the reused-worker bootstrap `compute_bootstrap_worker_estimate` (:587-600).
    - `simulate_under_lik_null` (:753-758) uses the same plogis-normalize map on `null_fit$params`.
  - Nuance: `compute_estimate_with_bootstrap_weights` (:242-340, the Bayesian/weighted-bootstrap path) fits **separate** weighted logistic regressions for `1{y==0}` and `1{y==1}`. For those fits, plogis is the right inverse link, so that path is internally consistent (approximately). The problem there is different: its replicates target a different functional than the softmax-based point estimate and delta SE.
  - Pure-R map comparison (`f17_zoib.R`), with softmax coefficients that imply (0.1, 0.1, 0.8):
    - plogis-normalize gives (0.111, 0.111, 0.778).
    - With true softmax (0.3, 0.3, 0.4) it gives (0.43, 0.43, 0.14).
    - Simulator P(0) is 0.182 vs the model's 0.140.
  - End-to-end EDI (`f17_edi.R`, n = 2000, data from the softmax ZOIB): the C++ fit recovers the softmax gammas (γ0 = (−1.03, 0.89), truth (−1, 0.8)).
    - `marginal_mean_diff` from EDI: **−0.0876**
    - Softmax-consistent g-computation from the same fit: **−0.0816**
    - Oracle: −0.0782
    - The bias is about 7% in this mild-inflation case and grows with the amount of inflation.
- **Severity if real:** Correctness, `InferencePropZeroOneInflatedBetaRegr`.
  - (a) `estimand = "marginal_mean_diff"` (non-default): the point estimate and delta-method SE are both of the wrong functional, and the reused-worker nonparametric bootstrap replicates are also wrong.
  - (b) Default conditional estimand: the parametric-bootstrap / LR-bootstrap simulator draws 0/1/interior with the wrong probabilities. The tested coefficient sits in the beta submodel, and the likelihood factorizes, so the main effect is a wrong distribution of the interior-sample size. This is a mild calibration distortion, not a sign or location error.
- **Fix sketch:** In `zoib_mean_from_coefs` and `simulate_under_lik_null`, compute `d = 1 + exp(a0) + exp(a1)` and set `p0 = exp(a0)/d`, `p1 = exp(a1)/d`, `p_mid = 1/d` (or call `.softmax_three_from_logits`). Either make the weighted-bootstrap path fit the joint softmax model with weights, or keep its separate logits but document the different functional.
- **Existing coverage:** None. No test touches the ZOIB `marginal_mean_diff` (only the Hurdle/ZIP marginal test exists). `test-zero-one-inflated-beta-fast-math.R` checks only the C++ kernel.

---

#### F18: Cloglog ordinal uses the opposite β sign convention from logit/probit/cauchit
- **Verdict:** CONFIRMED. It **is** the root cause of the open "Bug 2" (ordinal parametric-bootstrap sign mismatch) **for Cloglog only**. The memory note's suspicion that it "likely affects other links" is **REFUTED** for the shared helper.
- **Evidence:**
  - `src/ordinal_fixed_link_helpers.h:256-257`: `cdf(link, alpha[k] + m_eta_sign * eta[i])`.
  - `eta_sign` is −1 for Logit (`fast_ordinal_regression.cpp:42`), Probit (`fast_ordinal_probit_regression.cpp:31`) and Cauchit (`fast_ordinal_cauchit_regression.cpp:31`), giving P(Y≤k) = F(α_k − xβ). It is **+1** for Cloglog (`fast_ordinal_cloglog_regression.cpp:31`), giving F(α_k + xβ); the Rd at :231 documents this.
  - `R/inference_ordinal_cloglog.R` compensates everywhere else:
    - the public estimate is `-attempt$fit$b[1]` (:291) and `-res$b[1]` (:99)
    - constrained fits use `fixed_values = -d` / `-delta` (:152, :198)
    - `R/inference_ordinal_KK_clmm_abstract.R:256` flips the sign for cloglog as well.
  - The shared simulator `simulate_param_boot_ordinal_y()` (`R/inference_all_abstract_param_boot.R:718-737`) implements `cdf_fn(a - e)`, i.e. the α − xβ convention. At **HEAD** (committed), Cloglog's `simulate_under_lik_null` passed native params straight in, so data were generated under −β_native for **all** slopes: the treatment slope and the covariate slopes are both reversed.
  - The other three callers (proportional_odds :136, cauchit :114, ordered_probit :112) pass native α − xβ params with no negation (`list(b = c(0, attempt$fit$b[1]))`, `fixed_values = d`). They are consistent with the simulator and are **not** affected.
  - AdjCat / KKCondAdjCat / CR / stereotype classes do not call `simulate_param_boot_ordinal_y` at all. Any bad Type-I error in those classes needs a separate cause.
  - Pure-R check (`f18_cloglog.R`, n = 4000, `ordinal::clm` as the α − xβ reference), with public truth (0.5, 0.3):
    - HEAD simulator, clm estimate (−0.503, −0.275): **sign-flipped**
    - Slope-negated simulator, clm estimate (0.517, 0.298): correct
  - Status: the working tree has a **staged, uncommitted fix**: `git diff HEAD -- R/EDI/R/inference_ordinal_cloglog.R` adds 9 lines that negate the slope block before calling the simulator. The new test `R/EDI/tests/testthat/test-cloglog-parametric-bootstrap-native-sign.R` is also staged. The fix is correct by the check above.
- **Severity if real:** Correctness of the p-value, CI and estimate for every parametric-bootstrap and LR-bootstrap method (including Bartlett-approx) of `InferenceOrdinalCloglogRegr`, on the default path for those methods. This is the 60% Type-I error. The estimate, Wald and analytic LR methods are unaffected.
- **Fix sketch:** Already staged: negate `params_null[(n_alpha+1):end]` in Cloglog's `simulate_under_lik_null`. Optionally, give the shared helper an explicit `eta_sign` argument so the convention can't drift silently again.
- **Existing coverage:** At HEAD, none. The staged `test-cloglog-parametric-bootstrap-native-sign.R` covers it.

---

#### F19: Firth penalty has the wrong sign in `evaluate_penalized_neg_loglik_at`
- **Verdict:** CONFIRMED (sign wrong), but it is latent dead code.
- **Evidence:** `R/EDI/R/inference_mixin_off_optimum_likelihood_eval.R:92-106` returns `neg_loglik + 0.5 * log_det`. Firth/Jeffreys maximizes ℓ*(θ) = ℓ(θ) + ½ log|I(θ)|, so the penalized **negative** log-likelihood is −ℓ − ½ log|I| = `neg_loglik - 0.5*log_det`. Minimizing the current expression pushes toward a small |I|, i.e. toward separation, which is the opposite of Firth. The comment above the function explicitly calls it "Firth/Jeffreys-penalized".
  - Callers: none in `R/EDI/R`. `inference_all_abstract_asymp_lik.R:400` only mentions it in a comment.
  - The only use is `R/package_tests/testthat_bulk/test-off-optimum-likelihood-eval-mixin-reference.R:105-114`, which **enshrines** the wrong sign: it checks against a hand-computed `neg_loglik + 0.5*log|I|`.
- **Severity if real:** Currently none, since nothing calls it. It becomes a correctness bug as soon as any Firth/Jeffreys optimizer is wired to it.
- **Fix sketch:** Change `+` to `-` in the return and in the doc comment, and update the reference test's expected value.
- **Existing coverage:** One test exists, and it asserts the wrong sign.

---

#### F20: GEE exchangeable α̂ is not divided by the dispersion φ̂
- **Verdict:** CONFIRMED.
- **Evidence:**
  - `src/fast_gee.cpp:76-100` (`gee_estimate_exchangeable_alpha`): `ri = resid[i]/sqrt(gee_variance(mu))`, with `num += w*ri*rj`, `den += w`, and returns `clamp(num/den, ±0.95)`.
  - No φ appears anywhere in the file (grep finds no "phi", "dispersion" or "scale"), and residuals are not scaled by √φ̂ anywhere upstream. The variance function is μ for Poisson and μ(1−μ) for binomial, with no dispersion factor. So α̂ estimates φρ, not ρ. The denominator is the number of pairs rather than N_pairs − p, which is a minor difference.
  - The sandwich vcov is `BI * Meat * BI` (:270), so β̂ stays consistent and the SEs stay asymptotically valid.
  - Pure-R port vs geepack (`f20_gee.R`), overdispersed paired Poisson:
    - φ̂ = 4.75
    - EDI-formula α = **1.54** (clamped to 0.95 in the kernel)
    - L-Z α = 0.327; geepack α = 0.325
  - Proportions with binomial variance:
    - φ̂ = 0.083
    - EDI-formula α = **0.063**
    - L-Z α = 0.763; geepack α = 0.761
  - Callers: `R/inference_mixin_kk_gee_shared.R` (`gee_pairs_singletons_cpp` :497/546, weighted :597).
  - Families in use:
    - poisson: `InferenceCountKKGEE` (`inference_count_KK_gee.R:56`)
    - binomial: incidence (φ=1, so correct), proportion (`inference_proportion_KK_combined.R:62`, φ<1, α attenuated) and ordinal (`inference_ordinal_KK_combined.R:144`)
    - gaussian is not used by any class. It would be worse there: α would be the raw covariance σ²ρ.
  - The `use_rcpp = FALSE` geepack fallback estimates α correctly, so the two paths disagree on α. They also disagree slightly on β and SE, because the working correlation feeds into β.
- **Severity if real:** Mainly efficiency, for the count KK GEE and the proportion (and possibly ordinal) KK GEE wrappers on the default `use_rcpp` path. With a large φ, α pinned at 0.95 makes the working correlation badly wrong, so finite-sample behaviour of the sandwich SE and power degrade. It also creates a parity gap between the Rcpp and geepack paths.
- **Fix sketch:** Compute `phi = sum(w*r^2)/(N - p)` from the Pearson residuals, set `alpha = num/((den - p)*phi)` (or `num/(den*phi)`), and fix φ = 1 only for the Bernoulli incidence case if desired.
- **Existing coverage:** `R/package_tests/testthat_bulk/test-kk-gee-parity.R:61-102` compares α with geepack. It uses Bernoulli data (φ=1) and mildly overdispersed Poisson data with a loose `alpha_tol = 6e-2` for Poisson only, which masks the bug. No proportion-response α check exists.

---

#### F21: Dependent-censoring bootstrap CI swaps in the Wald CI whenever the bootstrap CI rejects and Wald does not
- **Verdict:** CONFIRMED. It is deliberate and only vaguely documented. A sibling rule that is worse was also found.
- **Evidence:**
  - `R/EDI/R/inference_survival_dep_cens_transform.R:363-399` (`dep_cens_validate_bootstrap_ci`): if the Wald fallback is usable and `fb[1] <= 0 && fb[2] >= 0` and the bootstrap CI excludes 0, then `use_fallback = TRUE` and the Wald CI is returned. The reverse case (bootstrap covers 0, Wald excludes it) never triggers a swap. The comparison point is hard-coded to 0.
  - Applied to the percentile/default (:156), basic (:192) and BCa (:214) bootstrap CIs.
  - **Sibling, worse:** `compute_bootstrap_confidence_interval_studentized` (:236) returns **NA and marks the result nonestimable whenever the CI excludes 0** (`dep_cens_ci_excludes_zero(ci) || too_wide`). That is, any significant studentized result is suppressed.
  - Further: `dep_cens_bootstrap_ci_max_abs = 2` declares any CI with an endpoint beyond |2| "unstable", which truncates on effect size.
  - Documentation: the class Rd (around :685-688) says "excessively wide or zero-excluding-by-construction intervals are treated as unstable and replaced with NA". That describes intent vaguely and is inaccurate: the percentile/basic/BCa paths substitute Wald rather than NA. The behaviour dates from the initial commit (ff079d54).
  - Reference tests enshrine it: `test-dep-cens-transform-bootstrap-ci-validation-zero-exclusion-width-guard-and-wald-fallback-reference.R:45` ("a bootstrap interval excluding zero while the Wald interval covers zero is replaced by the Wald interval") and `test-dep-cens-transform-studentized-bootstrap-ci-unstable-guard-reference.R:61`.
- **Severity if real:** Correctness of CIs and inference for `InferenceSurvivalDepCensTransformRegr` on the default bootstrap-CI path. The procedure depends on the outcome and is biased toward non-rejection. Coverage audits will look fine, but power and the CI's validity as a procedure are compromised, and the studentized CI can never reject. This looks like tuning to pass coverage tests.
- **Fix sketch:** Remove the zero-based swap and the zero-based NA. Keep only data-independent sanity checks (non-finite results, too few usable replicates). If instability is the real concern, base the check on the bootstrap-distribution diagnostics, not on whether the CI covers 0.
- **Existing coverage:** Tests exist, but they assert the biased behaviour as correct.

---

#### F22: `aftgee::aftsrr(se = "ISMB", B = 0)` returns no SE
- **Verdict:** CONFIRMED. It is worse than reported: `InferenceSurvivalKKRankRegrIVWC` **always** returns an NA estimate.
- **Evidence:**
  - Installed aftgee 1.2.1 source (`aftsrr_src.txt`): `if (sum(se %in% "ISMB") > 0) { if (B > 0) { vISMB <- isFun(...) } }` (lines 138-145). With B = 0, `vISMB` stays `NaN`.
  - `summary.aftsrr` sets `se.srr <- NA` unless `z$B != 0`. It also rounds StdErr to 3 decimals: a side issue, because EDI reads the SE from `summary(mod)$coefficients`.
  - Execution (`f22_aftsrr.R`): B = 0 gives `covmat$ISMB = NaN` and StdErr NA; B = 10 gives StdErr 0.215 / 0.107.
  - EDI `R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R`:
    - `aftsrr_for_matched_pairs` (:286-288) / `_reservoir` (:330-332) call it with B = 0. In the covariate ladder, every rung needs `is.finite(se_try)`, so every rung is fitted and rejected and `mod` stays NULL. Neither beta nor ssq is cached.
    - The no-covariate branch (:300/:344) does set beta, but ssq is NA.
    - Second, independent defect: in `estimate_only = TRUE`, ssq is forced to NA (:307/:351, `!estimate_only && ...`), yet `shared()` (:209-235) requires a finite ssq for both `m_ok` and `r_ok`. So the estimate-only path (used by bootstrap and randomization) is also always nonestimable, even after the B fix.
  - EDI execution (`f22_edi2.R`, KK14, n = 100, 2 covariates; m = 40, nRT = 8, nRC = 12; the dedup'd ladder has 2 rungs here, up to 13 in general):
    - full path: matched and reservoir both unset (all rungs rejected)
    - estimate-only path: beta_m = 0.427, beta_r = 0.298, ssq = NA
    - `compute_estimate()` and the p-value are NA, with reason `kk_rank_regr_ivwc_no_usable_component`
    - With `model_formula = ~1`, also NA.
- **Severity if real:** The whole class `InferenceSurvivalKKRankRegrIVWC` is non-functional: estimate, SE, p-value and CI are all NA on every path. It is a legacy IVWC class (per project memory, not promoted publicly; InferenceSuite hides it), but it is still exported and registered (`inference_class_registry.R:748, :993, :1140`). Besides the failure itself, it wastes up to 13 aftsrr fits per call.
- **Fix sketch:** Pass `B = <e.g. 200>` for ISMB (or use `se = "ISCF"` with B > 0), and read the SE from `sqrt(diag(mod$covmat$ISMB))` rather than the rounded `summary()`. In `shared()`, let `estimate_only` combine with cached or plug-in weights (or use an unweighted fallback) instead of requiring a finite ssq.
- **Existing coverage:** Effectively none. `test-survival-kk-rank-regr-ivwc-migration-golden.R` compares legacy and migrated outputs, which are both NA, so it passes. Other `kk-rank-regr-ivwc-*` reference tests cover guard branches only.

---

#### Summary

| id | verdict | severity | one-line summary |
|---|---|---|---|
| F17 | CONFIRMED (BB path nuance) | correctness, non-default `marginal_mean_diff` point+SE; mild calibration of default param-boot | ZOIB R code applies plogis-normalize to C++ softmax coefs; EDI marginal −0.0876 vs consistent −0.0816 (truth −0.078) |
| F18 | CONFIRMED; is the Bug-2 root cause for Cloglog only | correctness of all param/LR-bootstrap p/CI for `InferenceOrdinalCloglogRegr` (at HEAD) | cloglog kernel uses α+xβ (eta_sign=+1) vs α−xβ for logit/probit/cauchit; HEAD simulator flips all slopes; logit/probit/cauchit callers are fine; staged uncommitted fix is correct |
| F19 | CONFIRMED (latent) | none today (no callers); correctness if wired | `evaluate_penalized_neg_loglik_at` returns NLL + ½log\|I\| (should be −); reference test enshrines it |
| F20 | CONFIRMED | efficiency + Rcpp/geepack parity (β, sandwich SE still consistent) | exchangeable α̂ not divided by φ̂: Poisson φ=4.7 gives α 1.54 (clamped 0.95) vs 0.33; proportions give 0.06 vs 0.76 |
| F21 | CONFIRMED (deliberate, vaguely/inaccurately documented) | correctness: outcome-dependent CI biased to non-rejection | bootstrap CI excluding 0 is swapped for a 0-covering Wald CI; studentized CI that excludes 0 becomes NA; \|endpoint\|>2 cap |
| F22 | CONFIRMED (worse than reported) | class non-functional: always NA estimate/SE/p/CI | aftsrr ISMB with B=0 gives NaN SE, so every ladder rung is rejected; the estimate_only path also needs a finite ssq it never has |

### 13.5 Variance estimators & validity (F23–F26)


How I checked: by reading the code, plus small scripts using `pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE)`. The existing `src/EDI.so` loaded fine. Nothing was compiled and no repo file was edited. All scripts are in
`/tmp/claude-1000/-home-kapelner-workspace-EDI/0c756886-097f-421d-a114-706dc047fb66/scratchpad/verify/`.

---

#### F23: The DesignFixedOptimal bootstrap randomization test (BRT) replays a weaker solver than the one that produced the observed w

- **Verdict:** CONFIRMED.
  - The solver profiles are as the finding describes.
  - The replicate allocations are much less optimal, so the reference distribution comes from a different mechanism.
  - The effect on the test is **conservative**, not anti-conservative. It is small for covariate-adjusted or low-R² analyses and material for unadjusted mean differences when R² is high.
  - The docs do not acknowledge any validity cost.

- **Evidence: profiles**
  - `R/EDI/R/design_fixed_optimal.R:512-529` is the BRT replicate path. When `brt_mode && brt_solver != "ompr"`, it always runs annealing with `n_chains = arg_or("brt_n_chains", 1L), max_iter = arg_or("brt_max_iter", 2000L)` and cooling 0.999. This applies to every objective kind, including `l1`.
  - `:530-542` is the main path, `optimal_solve_auto(..., n_chains = 4L, max_iter = 20000L)`. In `helper_optimal_annealing.R:117-176` that means:
    - `l1` (`abs_sum_diff`) is always solved by exact MILP, at any n.
    - Quadratic (`mahal_dist`, `D`) and Dinkelbach ratio (`A`) use exact GLPK MILP when n ≤ `linearization_max_n` (default 20), and annealing with 4 chains × 20000 moves above that.
  - Kernel `src/design_optimal_annealing_search.cpp:174-260`: one swap proposal per iteration, T_{k+1} = 0.999·T_k, and each chain keeps its best-seen allocation.
  - The initial temperature is 10 × the mean |Δf| of random swaps (`helper_optimal_annealing.R:28-39`). After 2000 iterations T is still 0.999^2000 ≈ 0.135·T0 ≈ 1.35× a typical |Δf|. So the BRT chain is still hot when it stops: it is close to "the best of a near-random walk of 2000 swaps", not a converged anneal. The main profile ends at 0.999^20000 ≈ 2e-9·T0.
  - The observed w is drawn in main mode; each replicate is drawn after `prepare_for_resampling_replay()`. The call sites are `inference_all_abstract_rand_bootstrap.R:721,727,776,947,1077`.

- **Evidence: how much worse the optimum is** (`f23_brt_profile.R`, mahal_dist, p=3, 200 datasets per n; the main profile is approximated by 4×20000 annealing even at n=20, where MILP would do at least as well, so the gap shown there is a lower bound)

  | n | median f_BRT / f_main | IQR |
  |---|---|---|
  | 20 | 6.6× | 3.5–13 |
  | 40 | 16× | 6.6–34 |
  | 100 | 45× | 25–98 |

  The objective gap grows with n because the fixed 2000-move budget covers less and less of the space.

- **Evidence: validity and direction**
  - Under the sharp null with y = Xβ + ε, the null variance of the difference in means rises with covariate imbalance. Less-optimal replicate allocations therefore give a **wider** reference distribution than the true mechanism would. That inflates p-values and widens CIs, so the test is conservative and loses power. Type-I error is not inflated.
  - With moderate R² (`f23_brt_profile.R`, ε~N(0,1), β=(1,1,1)), the variance ratio brt/main was 1.20 at n=20, 1.02 at n=40 and 1.00 at n=100: negligible beyond n=20.
  - With R²≈0.99 (`f23b_highR2.R`), the ratio was 1.29, 1.20 and 1.41 at n=20/40/100. For a nominal 5% test that implies an actual size of about 0.026, 0.032 and 0.020.
  - For regression-adjusted statistics, imbalance enters only through the treatment-vs-X VIF, so the effect is second-order there.

- **Docs:**
  - The `prepare_for_resampling_replay` roxygen (`design_fixed_optimal.R:366-376`) says "replicate assignments need to be faithful applications of the mechanism, not individually re-verified to the observed solve's convergence standard". The finished plan (`finished_features/design_fixed_optimal.md` TODO-8b) frames it the same way.
  - Neither acknowledges that a reduced budget **changes** the mechanism. `brt_solver = "ompr"` is described only as buying exactness "at the user's expense".

- **Severity if real:** Affects reported p-values and CIs from the BRT on `DesignFixedOptimal`, on the default path (`brt_solver = "annealing"`, 2000×1). Results are conservative, with power loss. It is noticeable for unadjusted estimators with strongly prognostic covariates and negligible for low-R² or adjusted analyses. Point estimates and the design itself are unaffected.

- **Fix sketch:** Make the BRT replicate profile match the profile that produced the observed w (same chains, iterations and MILP cutoff). An alternative is to re-solve the observed w with the replicate profile, so both come from the same mechanism. At minimum, document the conservativeness and have the cheap profile end cold, with the cooling rate scaled so T_final ≪ |Δf|.

- **Existing coverage:** `package_tests/testthat_bulk/test-design-fixed-optimal-brt.R` checks only that the profile switches (the `solver_profile` diagnostic). No test compares the imbalance of replicate and observed allocations, and none checks the BRT's size.

---

#### F24: The weighted cluster sandwich scales scores by √w instead of w

- **Verdict:** REFUTED.
  - The √w scaling is what the code does, but the weights that reach it are constant within each cluster.
  - With such weights the √w form is exactly the frequency-weight convention Σ_g w_g S_g S_gᵀ. That is the right within-replicate SE for the Bayesian-bootstrap bootstrap-t that consumes it.
  - The "correct" w form the finding proposes, Σ_g w_g² S_g S_gᵀ, would overstate the replicate SE by about √E[w²] = √2.

- **Evidence: the code**
  - The only weighted caller is `R/EDI/R/inference_incidence_KK_marginal.R:57-77` (`compute_estimate_with_bootstrap_weights`). It passes `X_weighted = X_fit * sqrt(w_fit)` into `glm_cluster_sandwich_post_fit_cpp` with `working_weights = mu_hat`. The other call, at `:180`, is unweighted.
  - `src/robust_post_fit_speedups.cpp:344-382`:
    - Bread = (X̃ᵀ diag(μ) X̃)⁻¹ = (Xᵀ diag(wμ) X)⁻¹. This is the correct weighted bread.
    - Meat (`cluster_meat_robust`, `:137-168`) = Σ_g (Σ_{i∈g} √w_i x_i r_i)(…)ᵀ.

- **Evidence: what weights arrive**
  - These are Bayesian-bootstrap Dirichlet weights only. `inference_all_abstract_bayesian_bootstrap.R:578-588` draws rgamma(1) and scales each unit group to mean 1.
  - For match structures, `build_bayesian_bootstrap_context` (`:515-526`) defines units as `compute_cluster_ids_cpp(m_vec)`, i.e. pairs plus reservoir singletons. The sandwich clusters come from `get_cluster_ids()` (`inference_incidence_KK_marginal_abstract.R:80-110` → `des_priv$compute_matching_cluster_ids`, which is the same `compute_cluster_ids_cpp`). The two partitions are identical, so w is constant within each cluster.
  - Hence (Σ_{i∈g} √w_g x_i r_i)(…)ᵀ = w_g S_g S_gᵀ, and the meat is Σ_g w_g S_g S_gᵀ.

- **Evidence: derivation**
  - With integer bootstrap counts, the standard bootstrap-t replicate SE treats each copy of a cluster as its own cluster, which gives Σ_g c_g S_g S_gᵀ. The √w form is the smooth Dirichlet analogue of that.
  - It is unbiased for the full-data meat, since E[w_g] = 1. The w-form has E[w_g²] ≈ 2.
  - The w² form is the right one only for fixed sampling (IPW) weights, which never reach this code.
  - The two forms agree only for w ∈ {0,1}, as the finding says, but that is not the case that matters here.

- **Execution check** (`f24_weighted_cluster_meat.R`, pure R, 40 pairs + 40 reservoir, B=2000 Dirichlet draws)

  | Quantity | Value | Ratio to BB SD |
  |---|---|---|
  | BB SD of θ* | 0.1890 | — |
  | Full-data cluster SE | 0.1883 | — |
  | Mean replicate SE, √w form (EDI) | 0.1916 | 1.014 |
  | Mean replicate SE, w form (proposed) | 0.2558 | 1.353 |

- **Severity if real:** None. The convention is correct for its only consumer, the studentized / bootstrap-t Bayesian bootstrap. It matches the `weighted-HC0` convention in `inference_count_robust_poisson.R:104-120` and `inference_incidence_modified_poisson.R:95`: meat Σ w_i e_i² x_i x_iᵀ, the frequency-weight form, not sandwich::'s prior-weight w² form.
  - Caveat: if the helper is ever reused with weights that vary within a cluster, or with IPW / sampling weights, it would produce a hybrid with no clean interpretation.

- **Fix sketch:** No fix needed. Optionally expand the comment at `:58-61` to say that it assumes frequency-type, cluster-constant weights, and add an assert to that effect.

- **Existing coverage:** None specific (no test of the weighted cluster SE). Not needed for a non-bug.

---

#### F25: The g-computation SE omits the covariate-sampling variance term

- **Verdict:** CONFIRMED as an undocumented (implicit) estimand choice rather than a computational bug.
  - The delta-method SE propagates only the uncertainty in β̂, so it targets the conditional-on-sample-covariates standardized risk difference / log RR, not the population (PATE) one.
  - The resulting understatement of the PATE SE is small: about 0–6% of SE in my simulations.
  - Separately, a public doc says no closed-form asymptotic SE is used, which is false.

- **Evidence: the code**
  - `src/gcomp_speedups.cpp:244-266` (non-KK) and `:453-470` (KK): `var_rd = ∇ᵀ B M B ∇` with ∇ = ∂ mean(risk1_i − risk0_i)/∂β only. There is no `(1/n)·Var_i(r1_i − r0_i)` term.
  - The same β-only pattern appears in the R fallback (`inference_incidence_KK_gcomp_abstract.R:651-656`), in `inference_ordinal_gcomp.R:293` and in `inference_proportion_gcomp.R:695-697,755`.
  - Under a correctly specified model, the cross term between the β-score and (r1_i − r0_i − RD) is zero because E[y − μ | x] = 0. So the full PATE variance is exactly the current value plus (1/n)·Var(r1_i − r0_i) ≥ 0. The omission can only make the SE smaller (anti-conservative for PATE).

- **Evidence: the docs**
  - `inference_incidence_gcomp_abstract.R:1-7` and the C++ roxygen (`gcomp_speedups.cpp:~295-310`) say "standardized over the empirical covariate distribution … delta method for the marginal estimand". No doc says whether the estimand is the sample-covariate-conditional or the population quantity.
  - The public `InferenceIncidGCompRiskDiff` roxygen (`inference_incidence_gcomp.R:~205-207`) states "no closed-form asymptotic standard error is used". In fact the class exposes `get_standard_error` / `compute_asymp_*` / `compute_wald_*` (testing type "wald"), which use `se_rd` (`inference_incidence_gcomp_abstract.R:64-76`). That is a separate doc inaccuracy.

- **Execution check** (`f25_gcomp_se.R`, `f25b_gcomp_se_extreme.R`, calls `gcomp_logistic_post_fit_cpp`, 1000 reps)

  | Scenario | EDI SE (mean) | SE + covariate term | Monte Carlo SD | EDI coverage of PATE | EDI coverage of conditional target | Full-SE coverage of PATE |
  |---|---|---|---|---|---|---|
  | logit(p) = −0.5 + w + 2x, n=100 | 0.0758 | 0.0763 | 0.0790 | 0.932 | 0.933 | 0.933 |
  | same, n=400 | 0.0384 | 0.0386 | 0.0385 | 0.941 | 0.946 | 0.943 |
  | strong heterogeneity, logit(p) = −1 + 2.5w + 3x, n=400 | 0.0326 | 0.0341 | 0.0347 | 0.936 | 0.944 | 0.945 |

  - In the first two rows the missing term is under 1% of the variance.
  - In the strong-heterogeneity row the SE understates the PATE SE by about 4–6%.
  - A theoretical bound: Var(r1 − r0) ≤ ~0.06 against a β-term of order 1/n·4·p(1−p). So the omitted part is at most a few percent of the variance on the RD scale.
  - The comprehensive-tests audit (`bug_fix_plans/investigate_incidence_riskdiff_gcomp_coverage.md`, Cluster 1) records mild **over**-coverage for the GComp RD/RR classes. That is consistent with this term being second-order next to other effects.

- **Severity if real:**
  - SE / CI / p-value only, and only if the user's target is the population ATE.
  - Default path for the Wald / asymptotic methods of `InferenceIncidGCompRiskDiff` / `RiskRatio`, the KK GComp RD/RR classes, ordinal GComp and proportion GComp.
  - Magnitude is small: a ≤ ~1 percentage-point coverage shortfall in the scenarios tested.
  - Defensible as the conditional / sample estimand, which matters for a design-based package. But the estimand is not stated.

- **Fix sketch:** Either document that the target is "conditional on the observed covariates" (Ye, Shao, Yi & Zhao 2023 call this the conditional/sample variance), or add `+ var(r1_i − r0_i)/n` for RD (and the analogous delta-method term for log RR) behind an option or as the default. Also fix the false "no closed-form asymptotic SE" sentence.

- **Existing coverage:** None tests the estimand. `test-gcomp-helper-parity.R` and `test-gcomp-fractional-post-fit-native-result.R` check only that the R and C++ versions agree.

---

#### F26: Exact binomial uses a Clopper–Pearson CI but a "minlike" two-sided p-value

Clopper–Pearson (CP) is the central exact CI. "Minlike" is the two-sided p-value that sums all outcomes no more probable than the observed one.

- **Verdict:** CONFIRMED.
  - The CI and the p-value come from different two-sided rules, so they can disagree at α for null values δ0 ≠ 0. There are concrete examples below.
  - EDI is faithfully mirroring base R's `binom.test`, which has the same incoherence (Fay 2010). It is not a computational error.

- **Evidence: the code**
  - `R/EDI/R/inference_incidence_exact_binomial.R:116-126`: the p-value is `zhang_exact_binom_pval_cpp(d_plus, d_minus, delta_0)`.
  - `src/zhang_exact_speedups.cpp:22-38`: `binom_two_sided_pval` sums P(x) over every x with log P(x) ≤ log P(x_obs) + log1p(1e-7). That is the minlike rule, identical to `binom.test`'s p-value.
  - `:127-139`: the CI is `qlogis(stats::binom.test(d_plus, d_total, conf.level = 1-alpha)$conf.int)`, which is Clopper–Pearson (central, doubling of one-sided tails).
  - The class roxygen (`:180-195`) describes both pieces but not the mismatch.

- **Execution check** (`f26_exact_binom.R`, k = d+ + d− ∈ 5..40, all d+, δ0 ∈ [−4, 4] step 0.01)
  - 13,110 grid points disagree:
    - In 13,002, δ0 is **inside** the CP CI yet p < 0.05.
    - In 108, δ0 is just outside the CI yet p ≥ 0.05. These sit at the CI boundary.
  - There is no disagreement at δ0 = 0, because at p0 = ½ the distribution is symmetric and minlike equals central.
  - Clean example: d+ = 0, d− = 5, δ0 = 0.01.
    - The CP 95% CI on the log-OR is (−∞, 0.0874), which contains 0.01.
    - The EDI p-value is 0.0305 < 0.05, the same as `binom.test(0, 5, p = plogis(0.01))$p.value`.
    - The central (doubling) p-value would be 2·P(X ≤ 0) ≈ 0.06, which agrees with the CI.
  - Larger-k example: k = 15, d+ = 1, δ0 = −0.83. The CI upper bound is −0.756, so δ0 is inside, but p = 0.0497.

- **Severity if real:**
  - Affects the p-value vs CI consistency of `InferenceIncidExactBinomial` (KK / `DesignFixedBinaryMatch` matched pairs) when testing a non-zero null log-OR.
  - The default δ0 = 0 test is unaffected, and each piece is individually valid (both are exact level-α).
  - The incoherence is the standard minlike-vs-central one: the p-value is less conservative than the CI implies.
  - Cosmetic to moderate, mostly for users who invert the p-value or compare it against the CI.

- **Fix sketch:** Use one rule for both. Either:
  - compute the p-value as central, 2·min(P(X ≤ x), P(X ≥ x)) capped at 1, to match CP; or
  - make the CI the inversion of the minlike p-value (the Blaker / Sterne-type CI, e.g. `exactci::binom.exact(tsmethod = "minlike")`).

  Or document the choice.

- **Existing coverage:** `R/EDI/tests/testthat/test-incidence-exact-binomial.R:36` asserts the CI equals `qlogis(binom.test(...)$conf.int)`. That locks in the CP choice. No test checks CI/p-value coherence at δ0 ≠ 0.

---

#### Summary

| id | verdict | severity | one-line summary |
|---|---|---|---|
| F23 | CONFIRMED | p-value / CI (BRT on DesignFixedOptimal, default path); conservative | BRT replicates use 1×2000 annealing that is still hot at the end (T_final ≈ 0.135·T0); objective 6–45× worse than the observed MILP / 4×20000 solve; null variance up to 1.2–1.4× at high R² (size about 0.02–0.03 at nominal 0.05), negligible at low R²; docs don't flag it |
| F24 | REFUTED | none | √w row scaling with cluster-constant Dirichlet weights gives Σ_g w_g S_g S_gᵀ, the correct frequency / bootstrap-t convention (replicate SE / BB SD = 1.01); the proposed w-form overstates the SE by about √2 (1.35) |
| F25 | CONFIRMED (undocumented estimand choice, not a code bug) | SE / CI / p (Wald) of the incidence, KK, ordinal and proportion GComp classes; small anti-conservatism for PATE | Delta-method SE is β-only, so it targets the conditional-on-sample-X standardized effect; omitted (1/n)·Var(r1 − r0) costs 0–6% of SE and ≤ ~1 pp coverage; also a public doc wrongly says no asymptotic SE is used |
| F26 | CONFIRMED | p vs CI coherence (`InferenceIncidExactBinomial`, δ0 ≠ 0 only); cosmetic to moderate | p-value uses minlike (as `binom.test` does), CI is Clopper–Pearson; e.g. d+=0, d−=5, δ0=0.01 is inside the CI but p = 0.0305; never at δ0 = 0 |
