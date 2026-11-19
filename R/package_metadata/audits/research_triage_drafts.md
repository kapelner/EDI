# Release TODOs, defers and rejects from algorithm-research triage (run 43925959437)

The 27 drafts below were approved by the owner on 2026-11-17 and added to the release files
(each heading names its TODO). Proposed by a first-pass triage of run 43925959437's 120 findings (2026-11-17). Each entry is a
draft for the owner: approve it (then it is added to the named release file, and the finding's row
in `research_triage.csv` gets `status: approved` and `todo: TODO-<n>-v<version>`), edit it, or
reject it. The finding id links to its full text in `research_findings/2026-11-16-run43925959437.md`.

## v1.0.6 (3 drafts)

### KK CLMM/GLMM Bayesian-bootstrap replicates: check clmm's per-observation weight semantics  `clmm-ordinal-mixed-fit#43925959437.1`  → **v1.0.6-TODO-40** (approved 2026-11-17)
Step 1 (bounded): for one KK ordinal dataset and one Bayesian-bootstrap weight draw, evaluate clmm's weighted -logLik and a direct sum_g w_g log integral (same theta, 20-node GH) and compare; also compare replicate beta_hat_T between the two objectives over 200 draws at n in {50, 200}. Done when: either the objectives agree (close as not a bug) or they differ and the owner rules on the intended weighting; if a fix is ordered, add w_g to GLMMObjective/OrdinalGLMMObjective, switch the callers, and report replicate CI coverage plus per-replicate time vs clmm.

### Quantile IVWC Zhang CI: reservoir randomization p-value does not vanish as |delta| grows  `monte-carlo-test-inversion-ci#43925959437.1`  → **v1.0.6-TODO-41** (approved 2026-11-17)
Check whether compute_rand_pval_reservoir tests H0: effect = delta. Unit test on a Bernoulli design (m = 0, all subjects in the reservoir) and on a KK fixture: evaluate p_R(delta) on a grid out to +/-20 SE and record whether it falls below alpha on both sides; then run 200 reps of the IVWC quantile rand CI at n = 100 and record coverage and the share of bounds hitting the bracket edge. Stop condition: if p_R stays above alpha on one side, fix by subtracting delta * w_obs before permuting (standard form) and re-run the coverage check; if not, close with the numbers. Only if the current form is kept, the one-shot affine breakpoint inversion (closed_form_ci_from_affine_null_draws, c_b = 1) becomes a v1.1.0 speed item. Done when: the reservoir p-value is shown valid or fixed, with coverage within MC error of 95%.

### Sequential designs: draw_ws_raw overwrites the live design's w (CMH SE path)  `sequential-biased-coin-designs#43925959437.1`  → **v1.0.6-TODO-42** (approved 2026-11-17)
_Also related to existing v1.2.0-TODO-22._
Reproduce: build an urn (or other generic-draw_ws_raw sequential) design, run InferenceIncidCMH's SE path (inference_incidence_cmh.R:196), then compare des$get_w() and a second Inference's estimate before and after. If w changes, fix by saving/restoring private$w (and t-dependent state) in draw_ws_raw or by drawing on a duplicate. Done when: a regression test shows get_w() and downstream estimates unchanged after the CMH SE call, or the check closes with evidence that no reachable path mutates a live design.

## v1.1.0 (19 drafts)

### Pattern-compressed (count-weighted) likelihood for adjacent-category and continuation-ratio fits  `adjacent-cat-cr-logit-mle#43925959437.1`  → **v1.1.0-TODO-196** (approved 2026-11-17)
Add a grouped path to AdjacentCategoryLogitNegLogLik/hessian (fast_adjacent_category_logit.cpp) and route CR through fast_continuation_ratio_regression_weighted_cpp with pattern counts when distinct (x, y) rows G < n/2. Benchmark against the current path on treatment-only and one-binary-covariate designs, n in {50, 200, 1000, 2000}, K in {3, 5, 7}, timing one randomization CI and one parametric-bootstrap run. Done when: >= 1.5x on the treatment-only rows with b, ssq_b_1 and neg_loglik equal within 1e-10 and no fallback change for continuous X; or closed with the numbers.

### ZOIB Bayesian-bootstrap replicates: fast_beta_regression_weighted_cpp instead of formula betareg()  `beta-regression-mle#43925959437.1`  → **v1.1.0-TODO-197** (approved 2026-11-17)
In inference_proportion_zero_one_inflated_beta.R compute_estimate_with_bootstrap_weights, replace betareg::betareg (keep it and lm.wfit as fallbacks) with fast_beta_regression_weighted_cpp on the interior rows. Benchmark one Bayesian-bootstrap CI (B = 1000) at n in {100, 500, 2000}, p in {1, 5}, old vs new. Done when: >= 1.5x on the CI with every replicate beta_hat_T within 1e-6 of betareg's on the same weights (and fallback rate not higher); or closed with the numbers.

### fast_logistic_regression/fast_logistic_regression_with_var wrappers: decide lbfgs vs irls default  `binary-glm-mle#43925959437.1`  → **v1.1.0-TODO-198** (approved 2026-11-17)
First confirm whether the "lbfgs" default at helper_glm_fit.R:852/923 is intentional. If not, A/B irls vs lbfgs on the wrapper callers (KK21 and KK21-stepwise designs, helper_glm_fit.R:2015) at n in {50, 200, 1000}, p = 2, including separated fixtures: wall clock per design run and KK21 match/weight equality. Done when: switched with identical KK21 assignments (or explained differences) and >= 1.5x on the wrapper calls, or closed with the numbers and the inventory wording fixed either way.

### DesignFixedOptimalBlocks: nonbimatch fast path when n == 2B  `blocking-partition#43925959437.2`  → **v1.1.0-TODO-199** (approved 2026-11-17)
In design_fixed_optimal_blocks.R solve_optimal_blocks, dispatch n == 2B to nbpMatching::nonbimatch on D (offset negatives) and convert pairs to block ids. Compare with the MILP at n in {8, 12, 16} (B = n/2) on euclidean, mahal and a custom dist. Done when: objective equal to the MILP's within the nonbimatch integer-scaling tolerance on every fixture and >= 1.5x per solve; or closed with the numbers.

### Clogit reservoir logit: fast_logistic_regression_weighted_cpp with fixed_idx instead of glm.fit  `conditional-logit-matched-fit#43925959437.1`  → **v1.1.0-TODO-200** (approved 2026-11-17)
Replace both glm.fit calls in fit_clogit_reservoir_logit (full fit, Bayesian-bootstrap replicate and fixed-delta null refit) with fast_logistic_regression_weighted_cpp, fixing the treatment coordinate via fixed_idx/fixed_values, keeping glm.fit as a fallback and preserving the aliased-column drop. Benchmark one bootstrap CI and one LR CI inversion at KK sizes n in {50, 200, 1000}. Done when: >= 1.5x with params and neg_loglik within 1e-6 of glm.fit on fixtures (incl. separated/aliased ones); or closed with the numbers.

### KK strat-Cox: build the design-ladder rungs lazily  `cox-ph-fit#43925959437.2`  → **v1.1.0-TODO-201** (approved 2026-11-17)
Profile shared() in InferenceSurvivalKKStratCox over one randomization CI at n in {100, 500}, p in {2, 10}: share of time spent building rungs (inference_survival_KK_strat_cox.R:155-177) vs fitting. If material, generate each rung only after the previous fit is rejected. Done when: >= 1.5x on shared() with bit-identical estimates on the KK strat-Cox fixtures; or closed with the profile numbers if ladder building is < 10% of shared().

### Weighted native kernels for the ordinal bootstrap surrogate (replace per-draw MASS::polr)  `cumulative-link-ordinal-mle#43925959437.1`  → **v1.1.0-TODO-202** (approved 2026-11-17)
Add a weights argument to fast_ordinal_probit_regression_cpp/fast_ordinal_cloglog_regression_cpp (FixedOrdinalRegression already supports it) and route weighted_ordinal_bootstrap_surrogate_fit (globals.R:177) through the weighted C++ kernels for logistic, probit and cloglog, warm-started from the full-data fit; keep polr for cauchit (nonconcave) and as the failure fallback. Mind the cloglog sign convention (catalog F18, linpred_sign = 1). Benchmark per-draw time and treatment coefficient against the current polr path on the ordinal Bayesian-bootstrap fixtures at n in {50, 200, 1000}, K in {3, 5}, p in {1, 5}. Done when: >= 1.5x per-draw speedup with coefficients equal to polr within 1e-6 relative (polr reltol), or closed with the numbers.

### Cloglog ordinal: run the full-data multistart only when the primary fit fails a convergence certificate  `cumulative-link-ordinal-mle#43925959437.5`  → **v1.1.0-TODO-203** (approved 2026-11-17)
Gate .cloglog_full_data_multistart (inference_ordinal_cloglog.R:1) on a certificate of the primary fit (gradient norm plus PD Hessian, or the Newton decrement already used by ordinal_scale_guard.h), or replace it with a damped-Newton polish. A/B against the current always-on multistart on the cases that motivated it (test-cloglog-parametric-bootstrap-native-sign.R, test-ordinal-cloglog-lik-test-null-refit-multistart-reference.R, and the null-truth comprehensive rows) and time a randomization/bootstrap run at n in {50, 200, 1000}. Done when: identical selected fits (NLL within 1e-8) on all those cases and >= 1.5x faster per fit, or closed with the numbers (keep the multistart if any case regresses).

### Correlation-threshold design ladder: one cor() per call and candidates cached per dataset  `design-matrix-preprocessing#43925959437.1`  → **v1.1.0-TODO-204** (approved 2026-11-17)
Add a ladder helper that drops constant columns once, computes cor() once and returns the keep-set for every threshold; use it at the five ladder call sites, and cache the candidate list (cox_design_candidates, gee_predictors_df_candidates) by covariate key so BB replicates reuse it. Test that per-rung keep-sets equal the current drop_highly_correlated_cols output across the test corpus. Benchmark a Bayesian-bootstrap run of the KK GEE and KK LWA Cox classes at n in {100, 500, 2000}, p in {5, 20}. Done when: identical keep-sets and estimates and >= 1.5x end-to-end on the BB run, or closed with the numbers.

### Poisson GLMM: cluster-total (sufficient-statistic) form of the GH objective and Louis Hessian  `glmm-marginal-likelihood#43925959437.1`  → **v1.1.0-TODO-205** (approved 2026-11-17)
Rewrite PoissonGLMMObjective::operator(), hessian and the score/Hessian exports in fast_poisson_glmm.cpp to use per-group S_g, log Lambda_g (log-sum-exp) and A_g, so per-node work is O(G) and the beta blocks are one GEMV/crossprod with posterior-weighted e^eta; carry row weights into the group totals and reproduce the eta+b clamp at 700 or document its removal. A/B against the current kernel on the R8 accuracy grid (all.equal tol 1e-10 on estimates and SEs) and time fits plus a BB run at n in {100, 500, 1000}, p in {2, 5, 10}, cluster sizes 2 and 5, n_gh = 60. Done when: >= 1.5x per fit with results equal within 1e-10, or closed with the numbers.

### KK pair weights: grouped aggregation instead of a per-pair which() scan in every replicate  `grouping-and-level-coding#43925959437.1`  → **v1.1.0-TODO-206** (approved 2026-11-17)
Replace the vapply/which loop in kk_pair_and_reservoir_bootstrap_weights (globals.R:276) with a rowsum-based mean (NA weights excluded from both sum and count) or a pair-row index cached per design, and cache the pair extraction in build_combined_cpoisson_data across replicates. Test pair weights equal the old ones to 1e-12. Benchmark the helper alone and a Bayesian-bootstrap run of InferenceContinKKOLSOneLik and the KK cond-Poisson class at n in {100, 1000, 5000}. Done when: identical results and >= 1.5x on the helper with a measurable end-to-end share, or closed with the numbers.

### Closed-form exact jackknife for least-squares classes (mean difference, OLS, Lin, WLS)  `jackknife-replicates#43925959437.1`  → **v1.1.0-TODO-207** (approved 2026-11-17)
Add a per-class fast-path hook that computes delete-one-unit/cluster replicates by cross-product downdating (MacKinnon, Nielsen & Webb 2023, eq. 15), weighted for the Bayesian jackknife, falling back to the refit path (or non-estimable) when X'X - X_g'X_g is near-singular. Compare against the current refit jackknife and BCa on the continuous fixtures for unit, pair and cluster deletion at n in {50, 500, 2000}, p in {1, 5, 20}. Done when: replicates equal the refit jackknife within 1e-10 relative and the jackknife/BCa call is >= 1.5x faster, or closed with the numbers. Coordinate with the v1.0.6 block-jackknife unit fix (SPBR) so both use the same unit resolver.

### Cloglog null refit: second start only when the first fails a convergence certificate  `likelihood-tests-null-refits#43925959437.1`  → **v1.1.0-TODO-208** (approved 2026-11-17)
In both fit_null closures of inference_ordinal_cloglog.R (:194, :240), run fit_from(full_start) only when the first refit is NULL, non-converged, has max|score| > tol, or a non-PD observed information. Benchmark LR/score/gradient CI and param-bootstrap LR p-value wall time on the existing cloglog fixtures (n = 50, 200, 1000; prob_T 0.5 and 0.2), and count how often the second start changes neg_loglik by > 1e-8 on the current code (the fixtures that motivated the multistart, ordinal_cumulative_link_null_refit_multistart.md). Coordinate with v1.1.0-TODO-159. Done when: the second start never wins by > 1e-8 on certificate-passing fits and the change gives >= 1.5x on the null-refit-heavy paths with p-values/CIs identical within tolerance; or closed with the counts if the second start does win.

### Linear-statistic fast path for right-censored log-rank / Gehan-Wilcoxon randomization nulls  `logrank-family-tests#43925959437.1`  → **v1.1.0-TODO-209** (approved 2026-11-17)
Add compute_fast_randomization_distr to InferenceSurvivalLogRank and InferenceSurvivalGehanWilcox for right-censored data at delta = 0: compute pooled null scores once (Nelson-Aalen martingale residuals; Peto-Prentice weighted for Gehan) and evaluate all draws as one t(W) % * % m product, falling back to the current path for delta != 0 or general censoring. Benchmark compute_rand_two_sided_pval at n = 100, 500, 2000, r = 501 and 5001 against the per-draw path. Gate: estimates tolerance-equal (1e-12) to fast_logrank_stats_cpp / fast_gehan_wilcox_stats_cpp per draw on fixtures with ties, deaths tied with censorings, and a Bernoulli design with variable n_T. Implement together with the interval-censored version (v1.2.0-TODO-22, audit TODO-11) if that lands first. Done when: >= 1.5x with identical p-values within tolerance, or closed with the numbers.

### Tuning harness: paired-difference acceptance with adaptive stopping (catalog §12 TODO-12)  `performance-autotuning#43925959437.1`  → **v1.1.0-TODO-210** (approved 2026-11-17)
In local_machine_tuning_harness.R (edi_tuning_interleaved_ab / edi_tuning_interleaved_blocked_ab / edi_tuning_interleaved_accept_candidate), analyze per-round paired differences with a seeded percentile-bootstrap CI (or Wilcoxon signed-rank), accept only when the CI clears the 5% band, and add pairs adaptively between a minimum and maximum. Self-check on seeded synthetic timings (true effects 0%, 3%, 10%, 30%; noise CV 5-20%): false-accept rate, power, and mean reps per cell vs the current median + 2 * IQR rule; then one real tune_EDI_for_this_machine() run. Done when: false accepts at a 0% effect fall at equal or fewer reps, or closed with the numbers.

### Tail-accurate p-value combination: Stouffer, min-p and CCT (catalog §11 TODO-7)  `pvalue-combination#43925959437.2`  → **v1.1.0-TODO-211** (approved 2026-11-17)
Rewrite zhang_combine_exact_pvals's Stouffer branch as qnorm(p/2, lower.tail=FALSE) and 2 * pnorm(abs(z), lower.tail=FALSE), its min-p branch as -expm1(2 * log1p(-p)), and cct_combine_pvalues_full with the ACAT small-p branch (1/(p * pi) for p < 1e-15) and pcauchy(T, lower.tail=FALSE). Unit tests at p in {0.5, 1e-8, 1e-16, 1e-20, 1e-300}: equal to the old code within 1e-12 relative for p >= 1e-6, and finite, nonzero and correct against Rmpfr references below. No speed benchmark needed (same cost). Done when: the tests pass and the moved values are listed in NEWS.

### Per-draw RNG setup cost in index-seeded kernels; widen seed_for_index past 32 bits  `random-number-generation#43925959437.1`  → **v1.1.0-TODO-212** (approved 2026-11-17)
Micro-benchmark RRng(seed_for_index(master, d)) construction plus first draw against the full per-candidate work in rerandomization_search_cpp (and the greedy/optimal/binary-match search loops) at n in {50, 200, 1000}, p in {2, 10}. If setup is >= 30% of a candidate, prototype a counter-based child stream (Philox4x32-10 from Random123, BSD-3, or xoshiro256++ via SplitMix64) keyed by the 64-bit (master, index), keeping draw-index determinism and thread-count invariance (v1.1.0-TODO-48 (2) tests). Done when: a >= 1.5x win on rerandomization_search_cpp end-to-end with thread-count invariance tests green and the draw change documented, or closed with the setup-share numbers. The 32-bit truncation is fixed either way (owner: confirm the one-time seed-pinned draw change).

### robust_survreg: deterministic data-driven starts before random jitter  `weibull-aft-mle#43925959437.1`  → **v1.1.0-TODO-213** (approved 2026-11-17)
On the survival fixtures (lognormal, loglogistic, and Weibull when the C++ warm start fails), count survreg attempts per fit and wall-clock for the current rule vs (1) init omitted (survreg's own start), (2) intercept = mean log time and log-scale from residual SD, then (3) jitter scaled by |start| only as a last resort, at n = 50, 200, 1000, p = 1-10. Done when: >= 1.5x fewer attempts or time with estimates identical within 1e-6 where both converge, or closed with the numbers.

### Skip sdreport on estimate-only weighted glmmTMB replicates (ZIP/ZINB/hurdle)  `zero-inflated-count-mle#43925959437.1`  → **v1.1.0-TODO-214** (approved 2026-11-17)
Add se = !estimate_only at the two weighted glmmTMB call sites and time one Bayesian-bootstrap run (B = 200) per class at n = 100, 500, 2000, before and after; check parallel = 1 inside already-parallel replicate loops in the same run. Done when: a >= 1.5x win with identical replicate estimates (tolerance 1e-10), or closed with the numbers.

## v1.2.0 (5 drafts)

### Interval-censored Cox (ic_sp): profile-likelihood SE prototype in place of bs_samples = 200 (owner decision: SE estimator change)  `interval-censored-npmle#43925959437.1`  → **v1.2.0-TODO-204** (approved 2026-11-17)
Port icsp2's vcov/profile_fit logic (warm-started baseline refits at beta +/- h, OIM curvature) around icenReg's fitter, attributing the LGPL source; do not depend on icsp2 (not on CRAN). A/B against bs_samples = 200 on the interval-censored fixtures at n in {50, 200, 1000}: SE ratio, Wald CI coverage in a 1000-rep simulation, wall-clock, and convergence failures for the chosen h. Done when: >= 1.5x faster SE with coverage within MC error of the bootstrap SE, and the owner approves the estimator change, or closed with the numbers (bootstrap stays the default either way until approved).

### Quantile Zhang CI: common random numbers across the delta search (catalog §9 TODO-6a)  `monte-carlo-test-inversion-ci#43925959437.4`  → **v1.2.0-TODO-205** (approved 2026-11-17)
After the v1.0.6 reservoir-validity check (finding monte-carlo-test-inversion-ci .1) lands, pre-draw one sign-flip and one permutation matrix per CI search in ci_exact_zhang_combined / compute_rand_pval_matched_pairs / compute_rand_pval_reservoir and use p = (1+#)/(1+N). A/B against the current fresh-draw bisection at n = 50, 200, 1000 (nsim_rand default) on the KK quantile IVWC fixtures: wall time, number of p evaluations per bound, and coverage over 500 reps. Needs the A/B harness (v1.2.0-TODO-21); a changed MC realisation is a documented default change for the owner. Done when: >= 1.5x fewer evaluations with coverage >= nominal within MC error, or closed with the numbers.

### Zhang combined p-value: exact joint convolution vs Fisher chi^2_4 on discrete exact p-values (owner decision: test change)  `pvalue-combination#43925959437.3`  → **v1.2.0-TODO-206** (approved 2026-11-17)
Compare zhang_combine_exact_pvals (Fisher, Stouffer, min-p; inference_helpers_zhang.R) against (a) the exact joint convolution of the two discrete null supports (two-pointer sweep over log pM + log pR) and (b) DPComb 1.0.1 (MIT) as an oracle for the Wasserstein-adjusted rule, on the incidence KK Zhang classes at n = 50, 200, 1000 with 2,000 null and alternative reps. Report size, power and CI width; runtime only to confirm the exact option stays under 1 ms. Done when: the owner picks one rule given the size/power table, or closes it with the numbers (no default change without that decision).

### Randomization p-value rule: (b+1)/(r+1) vs b/r with floor (owner policy decision)  `randomization-null-distribution#43925959437.2`  → **v1.2.0-TODO-207** (approved 2026-11-17)
Simulate the null rejection rate of the current rule (rand_pval_from_tail_counts) and the Phipson-Smyth rule at r in {101, 201, 501} and alpha in {0.01, 0.05}, using a cheap statistic (mean difference) on 20,000 null datasets, and report the exact size of each. Also fix catalog section 7 P4's description of the current rule. Done when: the owner decides to switch (documented default change, bundled with v1.2.0-TODO-11 / perf TODO-156) or to keep b/r with the floor and document why, with the size table attached.

### Ridit: Brunner-Konietschke unbiased variance as an option beside DeLong (owner decision: estimator change)  `ridit-mann-whitney#43925959437.1`  → **v1.2.0-TODO-208** (approved 2026-11-17)
Implement the BK estimator from the placements already computed in ridit_delong_se_from_scores, and compare it with DeLong on Wald size and CI coverage for the ridit class at n_T, n_C in {5, 10, 25, 100} with 3-7 ordered categories and heavy ties (2,000 reps per cell); include the n_i = 1 case. Done when: the owner chooses default/option/none from the size-coverage table, or the item closes with the numbers.

## Deferred (37 findings)

Proposed defers: plausible but low value now (cold path, small share of runtime, new dependency or
estimator change not wanted yet). No TODO is drafted; each comes back for triage on its revisit date
(the inventory check flags a defer once its date is due).

### BLDM + complete Karmarkar-Karp for p = 1 optimal allocation  `balanced-allocation-optimization#43925959437.1`  → **v1.2.0-TODO-209** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-23._
Plausible but narrow: only p = 1 and the |sum difference| kinds, with an exponential certification tail near n = 50-60. The exact enumeration solver for n <= ~30 (algorithm_choice_audit.md TODO-20, in v1.2.0-TODO-23) covers the MILP range first; revisit for n > 30, p = 1 after it lands.

### Low-rank convex MIQCP via the CRAN scip package for DesignFixedOptimal  `balanced-allocation-optimization#43925959437.2`  → **v1.2.0-TODO-210** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-23._
New optional dependency, no benchmark, applies_at_edi_sizes unknown. The MILP is used only up to n = 20 (EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N, helper_optimal_milp_solvers.R:25), which the planned exact enumerator (audit TODO-20, v1.2.0-TODO-23) supersedes up to ~30; the MIQP formulation is already noted in catalog §12 TODO-2.

### HiGHS instead of GLPK as the MILP backend for optimal designs  `balanced-allocation-optimization#43925959437.3`  → **v1.2.0-TODO-211** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-23._
Unquantified, new dependency, and the source itself says results depend on the formulation; GLPK runs only at n <= 20 (helper_optimal_milp_solvers.R:25), where audit TODO-20's enumerator (v1.2.0-TODO-23) is the planned replacement. Revisit as one arm of that benchmark if MILPs are still used beyond the enumeration cap.

### Vectorize the per-row rbeta loop in the ZOIB parametric-bootstrap simulator  `beta-regression-mle#43925959437.2`  → **v1.2.0-TODO-212** (approved 2026-11-19)
_Revisit 2027-05-01._
Real but small: the loop at inference_proportion_zero_one_inflated_beta.R:791-801 draws u as a vector first and interleaves no other RNG, so a vectorized rbeta should be identical(); but it saves only O(n) interpreted iterations next to a C++ ZOIB refit per replicate. Fold into the ZOIB BB TODO (finding beta-regression-mle#43925959437.1) if that is approved, gated on identical() under a fixed seed.

### Route fractional-logit estimate_only glm.fit branch to C++ IRLS  `binary-glm-mle#43925959437.2`  → **v1.2.0-TODO-213** (approved 2026-11-19)
_Revisit 2027-05-01._
The glm.fit(quasibinomial) branch (inference_proportion_fractional_logit.R:165) runs only when harden = FALSE, and harden defaults to TRUE (:140) with no internal caller setting it FALSE, so this is a cold opt-in path; the default path already uses fast_logistic_regression_cpp (:257).

### HiGHS as an open-source MILP backend for optimal blocks  `blocking-partition#43925959437.3`  → **v1.2.0-TODO-214** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-23._
Unquantified for this model; ROI.plugin.highs MILP support is unconfirmed by the finding itself, and it adds a dependency. roi_solver is a closed set (helper_optimal_milp_solvers.R:30). Relevant only beyond the small-n range that the reformulation/DP work in v1.2.0-TODO-23 targets.

### Dense bitset instead of unordered_set in sample_group_units  `bootstrap-index-generation#43925959437.1`  → **v1.2.0-TODO-215** (approved 2026-11-19)
_Revisit 2027-05-01._
Bit-identical but negligible end to end (the finding says so); rejection + unordered_set is at exchangeable_resampling_draws.cpp:81. The partial Fisher-Yates half (catalog §7 TODO-2) is unscheduled and changes the stream. Revisit only if profiling shows subsampling draws matter.

### Batched bounded random integers (Brackett-Rozinsky & Lemire) for bootstrap indices  `bootstrap-index-generation#43925959437.2`  → **v1.2.0-TODO-216** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-11._
Unquantified at EDI sizes, needs 64-bit words while RRng is 32-bit MT19937, changes seed-pinned streams, and index generation is small next to per-replicate refits. Belongs with the RNG-throughput measurement (performance_profiling_and_upgrades.md TODO-149, in v1.2.0-TODO-11).

### C++ partial Fisher-Yates kernel for block_ra_batch  `complete-randomization-draws#43925959437.1`  → **v1.2.0-TODO-217** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-22._
block_ra_batch is already vectorized R (design_fixed_blocking.R:16, used by blocking/cluster/optimal-blocks designs), so the old replicate(randomizr) cost that audit TODO-21 (v1.2.0-TODO-22) targeted is mostly gone; the remaining constant-factor gain is unmeasured and changes seed-pinned draws. Profile first under that item.

### Batched bounded random integers for Fisher-Yates shuffles  `complete-randomization-draws#43925959437.2`  → **v1.2.0-TODO-218** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-11._
Same as the bootstrap-index finding: measured only with 64-bit generators, changes the seed-pinned R/Python stream, and the shuffle is rarely dominant (rerandomization spends O(np) per draw on balance). Revisit with the RNG-throughput item (performance TODO-149 in v1.2.0-TODO-11).

### Exponential-cone interior-point (ECOS/Clarabel) solver for log/identity-binomial MLE  `constrained-binomial-mle#43925959437.1`  → **v1.2.0-TODO-219** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-23._
A robustness idea with a new solver dependency and no measured gain over EDI's own active-set projection and KKT gate; probably slower per fit than IRLS. It is a candidate arm for the log-binomial constrained solver in algorithm_choice_audit.md TODO-32 (v1.2.0-TODO-23), not its own item.

### Factor the information matrix once (reuse FullPivLU or LDLT) for vcov  `covariance-from-information#43925959437.1`  → **v1.2.0-TODO-220** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-11._
Microseconds per fit at p <= 20, and the FullPivLU check plus inverse() pair is deliberate for bit-compatibility (comment at helper_functions_core.h:724-748). Tracked under performance_profiling_and_upgrades.md TODO-155 (v1.2.0-TODO-11); try lu.inverse() there with a vcov-fixture A/B.

### Tail-accurate cell-probability differences per link (rms celldiff) instead of F(u)-F(l) floored at 1e-12  `cumulative-link-ordinal-mle#43925959437.3`  → **v1.2.0-TODO-221** (approved 2026-11-19)
_Revisit 2027-05-01._
Robustness only, no speed gain; the cancellation and the 1e-12 floor (ordinal_fixed_link_helpers.h:258,285,343) are already recorded as a catalog section 2 incidental that 'only matters from extreme starts', and no fit failure has been traced to it. Revisit if a near-separated ordinal replicate failure is traced to the floor (it would then be a v1.0.6 false-convergence item).

### fastglm::fastglm_ordinal(nonparallel=) instead of VGAM::vglm for partial proportional odds  `cumulative-link-ordinal-mle#43925959437.4`  → **v1.2.0-TODO-222** (approved 2026-11-19)
_Revisit 2027-05-01._
Low confidence: no timings, fractional-weight behaviour undocumented (weights are frequency counts), estimator equivalence unknown, and fastglm_ordinal is a brand-new release (CRAN 0.1.4, 2026-11-11). It would add a dependency, so it would belong in v1.2.0+ with an owner decision; vglm is called at inference_ordinal_partial_proportional_odds.R:574,607. Revisit once the package has matured.

### Cancellation-free centred form of the LMM per-group quadratic form W_g  `dense-linear-algebra#43925959437.2`  → **v1.2.0-TODO-223** (approved 2026-11-19)
_Revisit 2027-05-01._
Robustness only, low confidence, and it matters only at v_b/v_e of about 1e6 or more; W_g = Q_g - (v_b/a_g) S_g^2 is at fast_gaussian_lmm.cpp:109-118 / :158. The natural time to change it is the profiled-LMM rewrite (audit TODO-32, v1.2.0-TODO-23), which reworks neg_ll_and_grad anyway.

### Single forced-front pivoted QR or column-append QR updates in qr_reduce_preserve_cols_cpp  `design-matrix-preprocessing#43925959437.2`  → **v1.2.0-TODO-224** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-22._
Already listed in audit TODO-29 ('qr_reduce_preserve_cols single factorization', v1.2.0-TODO-22, low-priority linear algebra). The keep-set is cached, so the path is cold, and a different pivot could change the keep-set on near-collinear designs; no new reason to raise its priority.

### p-value-only Fisher exact path (zhang_exact_fisher_pval_cpp or conf.int=FALSE)  `exact-conditional-tests#43925959437.1`  → **v1.2.0-TODO-225** (approved 2026-11-19)
_Revisit 2027-05-01._
pval_exact_fisher (inference_indicidence_exact_fisher.R:109) is only reached from the user-level p-value at a given delta (:78); the CI comes from one fisher.test call, not from inversion, so there is no repeated-call hot path. Low value; the conf.int = FALSE change is trivial when the file is next touched.

### Exact finite sums for integer/half-integer df upper chi-square tail  `gamma-family-functions#43925959437.1`  → **v1.2.0-TODO-226** (approved 2026-11-19)
_Revisit 2027-05-01._
Catalog verdict for fast_gamma_functions.h fast_pchisq_upper is Keep (catalog line 1024), and the finding expects negligible end-to-end gain since each p-value follows a refit; the accuracy benefit is unquantified. Could ride with the accuracy batch (audit TODO-22, v1.1.0-TODO-50) if that is reopened.

### Cache the multgee uniform local-odds-ratio structure across ladder rungs and draws  `gee-fit#43925959437.1`  → **v1.2.0-TODO-227** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-2._
Low confidence: the LOR estimation's share of an ordLORgee call is unmeasured, and the cache couples EDI to multgee's LORterm layout. The native ordinal GEE kernel that replaces multgee::ordLORgee is already scheduled (v1.2.0-TODO-2), which supersedes an interim cache.

### O(n) closed-form Hodges-Lehmann variance from centred group sums  `hodges-lehmann-estimation#43925959437.1`  → **v1.2.0-TODO-228** (approved 2026-11-19)
_Revisit 2027-05-01._
Exact and more stable, but the only caller is compute_wilcox_matching_ivwc_bootstrap_parallel_cpp (fast_wilcox_hl.cpp:574-576), used by the legacy InferenceAllKKWilcoxIVWC (inference_all_KK_wilcox_ivwc.R:467). Low value; do it when that file is next touched for the HL SE scale fix.

### Linearized (CV3L) jackknife from per-unit scores/information as an opt-in  `jackknife-replicates#43925959437.2`  → **v1.2.0-TODO-229** (approved 2026-11-19)
_Revisit 2027-05-01._
Estimator change (first-order approximation; BCa a-hat and jackknife SE move), low confidence, and it needs per-unit score and information contributions that most EDI specs do not expose (the same obstacle the catalog records for the infinitesimal jackknife, line ~1676). The 'v1.0.6-TODO-7' the finding cites is unrelated (ModifiedPoisson ~1 at large n). Revisit after the exact LS jackknife lands and if per-unit hooks are added.

### Distinct-y frequency table for the NB theta score/information sums in KK21 tstats  `kk21-covariate-weights#43925959437.1`  → **v1.2.0-TODO-230** (approved 2026-11-19)
_Revisit 2027-05-01._
Exact regrouping, but the theta step is one Newton step per outer iteration (kk21_weights.cpp:553-564, digamma/trigamma per obs) while the IRLS beta loop (<=25 its) dominates; only reached when count_use_speedup=FALSE. Unquantified, low confidence; revisit with a profile.

### Minimax (fdlibm-style) polynomial in s^2 for fast_log1pexp instead of 10-term Taylor  `link-function-evaluation#43925959437.1`  → **v1.2.0-TODO-231** (approved 2026-11-19)
_Revisit 2027-05-01._
Marginal speed (about 3 FMAs per element while exp dominates) and the current series already meets its claimed <5e-12 abs error (inventory row fast_log1pexp, 'Keep'). Worth doing only as an accuracy item; the citation fix for catalog P11 (algorithm_choice_audit_catalog.md:1474) can be done anytime.

### Factor X_pos once for both hurdle-NB OLS start columns  `mle-starting-values#43925959437.2`  → **v1.2.0-TODO-233** (approved 2026-11-19)
_Revisit 2027-05-01._
Real but tiny: fast_hurdle_negbin.cpp:167 and :170 each run a ColPivQR on X_pos, saving one O(np^2) factorization in a start grid of a whole iterative fit. Bit-identical; bundle with the next edit to the start code (e.g. v1.2.0-TODO-11's performance TODO-155 work) rather than ship alone.

### Exact quadratic jump-point inversion for studentized BRT pivots (Zhu & Liu 2024)  `monte-carlo-test-inversion-ci#43925959437.2`  → **v1.2.0-TODO-234** (approved 2026-11-19)
_Revisit 2027-05-01._
Applies only to OLS / mean-diff / Lin studentized BRT pivots, which fall back to bisection in invert_rand_bootstrap_test_bisection (inventory 'Keep-tracked'); low confidence, no EDI-size benchmark, and the reference code is unlicensed (implement from the paper). Revisit after v1.2.0-TODO-21's harness exists.

### ITP (n0=0) instead of bisection in zhang_bisect_ci_boundary  `monte-carlo-test-inversion-ci#43925959437.5`  → **v1.2.0-TODO-235** (approved 2026-11-19)
_Revisit 2027-05-01._
Each p(delta) evaluation is O(d+S) arithmetic, so even 20 -> 8-10 evaluations saves microseconds; the inventory already lists three conflicting verdicts for zhang_bisect_ci_boundary ('Keep', 'Adopt-with-caveat', 'Prototype') that should be reconciled first (the 'step function' rationale is the part to correct).

### Opt-in cheap bootstrap (B about 5-10) and studentized cheap bootstrap CI types  `nonparametric-bootstrap-distribution#43925959437.1`  → **v1.4.0-TODO-20** (approved 2026-11-19)
_Revisit 2027-05-01._
A new, different interval (wider at small B), not a faster way to compute the current one; it needs an owner decision on a new CI type and a coverage A/B, and the studentized variant is an unreviewed 2026 preprint. Revisit after v1.2.0-TODO-21's harness lands.

### XPtr compiled custom distance and hoisted buffers for the R-callback distance matrix  `pairwise-distance-matrix#43925959437.1`  → **v1.2.0-TODO-236** (approved 2026-11-19)
_Revisit 2027-05-01._
Adds API surface; the matrix is computed once per design and the ompr MILP dominates (finding tradeoffs; inventory distance_matrix_custom_cpp_impl 'Keep (inherent to a black-box R fn)'). Low value now.

### Portnoy-Koenker/CFM preprocessing for bootstrap quantile-regression refits  `quantile-rank-regression#43925959437.2`  → **v1.2.0-TODO-237** (approved 2026-11-19)
_Revisit 2027-05-01._
Exact (same estimates), but the cited gains are against Stata simplex at k = 20 and the paper reports no gain for a single fit at n = 500, k = 8; EDI's quantile classes have small p, and the inventory verdict for inference_continuous_quantile_regr.R is 'Keep br at EDI sizes'. Revisit after the rq.fit/C++ quantile work (v1.2.0-TODO-1, v1.2.0-TODO-22 / audit TODO-19) if profiling shows replicate QR fits dominate at n >= 1,000.

### Batched bounded integers (Brackett-Rozinsky & Lemire) for Fisher-Yates shuffles  `random-number-generation#43925959437.2`  → **v1.2.0-TODO-238** (approved 2026-11-19)
_Revisit 2027-05-01._
bounded_rand (RNG.h:324-336) is already Lemire's method (inventory verdict 'Keep (best-known method)'); the batched variant changes every seed-pinned shuffle for a gain bounded by the RNG share, which is unmeasured and, per the finding above, likely smaller than the per-draw MT seeding cost. Revisit together with the RNG-stream TODO if that benchmark shows word generation matters.

### Early-abandon partial sums in rerandomization acceptance check  `rerandomization-sampling#43925959437.1`  → **v1.2.0-TODO-239** (approved 2026-11-19)
_Revisit 2027-05-01._
The gain is bounded by the O(np) GEMV share of a candidate (rerandomization_helpers.cpp:236-238), and the per-draw MT seeding (finding random-number-generation .1) is likely the larger cost at EDI sizes. Accumulating f in a different order can also flip decisions exactly at the cutoff, which changes seed-pinned draws. Revisit after the RNG setup benchmark.

### nth_element sample quantile for intercept-only sign-flip refits instead of rq(yd ~ 1)  `resampling-refit-loop#43925959437.1`  → **v1.2.0-TODO-240** (approved 2026-11-19)
_Revisit 2027-05-01; related to v1.2.0-TODO-22._
The rq.fit replacement is already scheduled as audit TODO-19 (catalog section 9 TODO-6b) under v1.2.0-TODO-22, but the code path (qr_intercept_pairs, inference_all_KK_quantile_regr_ivwc_abstract.R:402-407) is hosted only by the legacy KK quantile IVWC classes (inference_continuous_KK_quantile_regr_ivwc.R:69, inference_proportion_KK_quantile_regr_ivwc.R:64), which are never published. Fold the p == 0 nth_element special case into v1.2.0-TODO-22 if that work touches this file.

### Closed-form MN constrained MLE (cubic) plus Brent on z(delta) for the risk-difference CI  `risk-difference-ci#43925959437.1`  → **v1.2.0-TODO-241** (approved 2026-11-19)
_Revisit 2027-05-01._
Catalog section 6 candidate 3 rates it 'Adopt, low priority': mn_ci_cpp/mn_pvalue_cpp are called once per CI/p-value (inference_incidence_miettinen_nurminen_univ.R:155,172), not inside resampling, and absolute cost is microseconds. No release TODO schedules it; brent_ci_inversion.md (v1.1.0-TODO-17w) does not yet name mn_ci_internal. Fold into that plan when it lands, using lrstat remlRiskDiff as the reference.

### Finite-termination active-set Newton for the Huber M-estimator  `robust-m-regression#43925959437.1`  → **v1.2.0-TODO-242** (approved 2026-11-19)
_Revisit 2027-05-01._
Same estimator and same O(np^2) per step; the finding's own source says Huber IRLS converges in 4-5 iterations, so the saving at n <= 1000, p <= 10 is likely small. Robust-regression performance work is already a v1.2.0 lane (v1.2.0-TODO-3, robust_regression_perf_optimization_spec.md); revisit there if profiling shows IRLS iterations dominate KK randomization draws.

### pxp Bell-McCaffrey df and kxk meat reduction for CR2 (estimatr 2.0)  `sandwich-variance#43925959437.1`  → **v1.2.0-TODO-243** (approved 2026-11-19)
_Revisit 2027-05-01._
Same CR2 estimator, but cluster_robust_cr2_variance (helper_robust_sandwich.R:116-157) runs once per fit, only on cluster-randomized designs (callers inference_continuous_ols.R:399, inference_continuous_lin.R:392), and its O(nG^2) crossprod is milliseconds at n <= 1000. Revisit if the CR2 SE is put inside studentized bootstrap or randomization loops.

### Boos-Zhang 1/B extrapolation of coverage/power in the simulation engine  `simulation-study-engine#43925959437.1`  → **v1.2.0-TODO-244** (approved 2026-11-19)
_Revisit 2027-05-01._
This changes what the simulation report states (an extrapolated B = infinity summary) rather than speeding any EDI algorithm, and it needs nested sub-B bookkeeping in every bootstrap/randomization cell; the inventory verdict for result_key_store is Keep. Plausibly useful for the monthly calibration study (v1.2.0-TODO-36), so revisit when that study's compute budget is set.

### missForestPredict warm-started periodic refits and per-arrival predict  `missing-covariate-imputation#43925959437.2`  → **v1.2.0-TODO-232** (approved 2026-11-19)
_Revisit 2027-07-01._
New dependency, a different imputer (estimator change), unquantified gain, and only needed if the missRanger predict path in v1.2.0-TODO-23 (audit TODO-30) proves insufficient. Revisit after that prototype reports.

## Rejected (18 findings)

Proposed rejects: dead code, paths only legacy IVWC classes use, estimator or design changes not
wanted, gains negligible at EDI's sizes, or already benchmarked and dropped. Next month's agents are
told not to re-report these without new evidence.

### Exact cardinality-constrained MSSC (SDP branch-and-cut) for blocking  `blocking-partition#43925959437.4`  → **rejected** (approved 2026-11-19)
Needs MATLAB/Gurobi-class tooling with no linked code, and only helps at n much larger than 20, which EDI's exact blocking does not target; the finding itself recommends not pursuing it.

### fastcluster::hclust drop-in for the K-way hold-out step  `blocking-partition#43925959437.5`  → **rejected** (approved 2026-11-19)
The step costs ~6-21 ms per replay draw (finding's own numbers), and fastcluster may resolve ward.D2 ties differently, which can change the held-out subjects and so the blocks (design_fixed_optimal_blocks.R:468); a new dependency for no measured win.

### Eigen selfadjointView rankUpdate (SYRK) for the per-replicate Gram in OLS rand bootstrap  `dense-linear-algebra#43925959437.1`  → **rejected** (approved 2026-11-19)
The same swap was benchmarked and dropped: performance_profiling_and_upgrades.md TODO-29 (fast_ols.cpp) found Eigen rankUpdate 4-6% slower than the full product at p=6, and performance_profiling_and_upgrades.md TODO-118 found DSYRK wins only at p>=15. EDI's OLS kernels run at small p, and the Gram at rand_bootstrap_ols_parallel.cpp:76 is the same shape, so the prior measurement still holds.

### O(log n) boundary search for the minlike exact binomial p-value  `exact-conditional-tests#43925959437.2`  → **v1.2.0-TODO-245** (approved 2026-11-19)
At EDI's discordant-pair counts the O(n) dbinom loop in zhang_exact_speedups.cpp::binom_two_sided_pval costs microseconds even inside the Zhang CI bisection (as the finding itself notes), so the win does not apply at EDI's sizes.

### Batched bounded-integer RNG (Lemire) for Fisher-Yates in random_balanced_init  `greedy-swap-allocation-search#43925959437.1`  → **rejected** (approved 2026-11-19)
The shuffle is a negligible share of each greedy/D/A search draw (the O(n_T n_C) swap rounds dominate), so the end-to-end gain is about 1x, while it would change every seed-pinned design stream and its fixtures.

### Null-model score statistics (Rfast::score.glms) instead of per-covariate univariate GLM fits  `kk21-covariate-weights#43925959437.3`  → **rejected** (approved 2026-11-19)
Estimator change that departs from KK21's Wald-|t| importance measure and would change the design rule; the per-covariate fits are tiny 2-parameter fits (inventory: kk21_logistic/negbin_weights_cpp 'Keep'), so the gain at EDI sizes is small.

### Replace MASS::glm.nb in robust_negbinreg with fast_neg_bin_cpp or fastglm_nb  `negbin-glm-mle#43925959437.1`  → **rejected** (approved 2026-11-19)
The only caller (design_seq_one_by_one_KK21_stepwise.R:352, compute_weights_KK21stepwise_count) is unreachable: compute_weights returns kk21_stepwise_negbin_weights_cpp for count with count_use_speedup=FALSE at :283-284 before the fallback at :295. Speeding up dead code has no value.

### k-step Newton bootstrap replicates from theta-hat instead of full refits  `nonparametric-bootstrap-distribution#43925959437.2`  → **rejected** (approved 2026-11-19)
Changes the bootstrap distribution at finite n (asymptotic equivalence only) and is risky for nonconcave likelihoods, while replicates are already warm-started at the full-data MLE (finding's own 'current'), so the remaining gain is the few iterations past k (est. 1-3x, unmeasured).

### k-step parametric bootstrap refits instead of full convergence  `parametric-bootstrap-simulation#43925959437.1`  → **rejected** (approved 2026-11-19)
Estimator change at finite n, and replicates are already warm-started from the base MLE (inventory run_param_bootstrap_replicates), so few iterations remain to save; same reasoning as the nonparametric k-step finding.

### Cache delta-free central log-choose weights across Zhang exact-CI bisection steps  `pvalue-combination#43925959437.1`  → **rejected** (approved 2026-11-19)
Already assessed: inventory fisher_noncentral_two_sided_pval 'Keep (delta-free log-weights could be cached ...; trivial at EDI sizes)'; microseconds per call at EDI reservoir sizes, and that reason still holds.

### aftsrr se='ISCF' closed-form sandwich instead of ISMB B=100 multiplier bootstrap  `quantile-rank-regression#43925959437.1`  → **rejected** (approved 2026-11-19)
The only host is the legacy InferenceSurvivalKKRankRegrIVWC chain (aftsrr_for_matched_pairs/aftsrr_for_reservoir, inference_survival_KK_rank_regr_ivwc_abstract.R:266-282, se_method 'ISMB', B = 100), and IVWC classes are never published. Switching to ISCF also changes the SE and hence the IVWC weights (keeps_estimator = no).

### MCMC/gradient rerandomization samplers (PSRSRR, Langevin-Gradient)  `rerandomization-sampling#43925959437.2`  → **rejected** (approved 2026-11-19)
These samplers do not draw uniformly from {w : f(w) <= a} (LGR is explicitly non-uniform), so they change the design law that rerandomization_search_cpp's exact i.i.d. rejection sampler defines and that the randomization tests condition on. Any such sampler would be a separate opt-in design, not a speedup.

### Per-event-time collapsed Newton for p=1 Cox in rand bootstrap kernel  `resampling-refit-loop#43925959437.2`  → **rejected** (approved 2026-11-19)
compute_coxph_rand_bootstrap_cpp (fast_coxph_regression.cpp:1135) has no caller outside RcppExports, so the faster path would speed up dead code. Keep FastSurvival as a test-oracle note in small_kernel_hoists_batch.md Item C if the kernel is ever wired.

### Fast robust bootstrap (one weighted LS per replicate) for robust rand bootstrap  `resampling-refit-loop#43925959437.3`  → **rejected** (approved 2026-11-19)
FRB is a linearized approximation of the replicate estimate, so it changes the bootstrap distribution that compute_robust_rand_bootstrap_parallel_cpp (called from inference_continuous_robust_regr.R:413) produces; keeps_estimator = no. Only relevant if a true MM estimator (audit TODO-31, v1.2.0-TODO-23) is adopted.

### Corrected Newcombe phi (AD-BC-N/2) in the paired Newcombe interval  `risk-difference-ci#43925959437.2`  → **rejected** (approved 2026-11-19)
newcombe_paired_ci_cpp (newcombe_speedups.cpp:113, phi at :127-128) has no R caller (only RcppExports.R:4784) and is not exported; InferenceIncidKKNewcombeRiskDiff computes its matched part with its own Wald variance (inference_incidence_KK_newcombe_ivwc_univ.R:140-148). Fix the phi definition only if the function is ever wired in.

### Monotone pointer instead of binary search in Cox robust vcov  `sandwich-variance#43925959437.2`  → **rejected** (approved 2026-11-19)
The finding itself says it does not apply at EDI sizes: it removes a log K factor from a non-dominant term of compute_robust_vcov (inventory verdict Keep). Do it only alongside the I-6 reverse-accumulation fix if that edit touches the function.

### Lam's cheap bootstrap (few-resample t interval) for subsampling CIs  `subsampling-m-out-of-n#43925959437.1`  → **v1.4.0-TODO-20** (approved 2026-11-19)
It is a different CI procedure (a t-type interval from a handful of resamples), not a faster way to compute the current B = 501 subsampling/m-out-of-n pivot CI (inventory verdict Keep), so it changes the estimator's interval. If wanted, it belongs in a new-methods proposal, not this triage.

### Fast tail-series or trigamma-free expected Hessian for truncated NB  `zero-inflated-count-mle#43925959437.3`  → **rejected** (approved 2026-11-19)
fast_hurdle_negbin.cpp TruncatedNegBinCount::expected_hessian is dead code with no caller (inventory verdict 'Keep. Dead code'), so speeding it up gains nothing. Delete it in a cleanup pass or rewrite it only if it is ever wired in.
