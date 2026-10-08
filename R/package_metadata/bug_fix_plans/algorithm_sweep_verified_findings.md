# Fix: Verified Correctness Findings from the 2026-10-09 Algorithm-Catalog Sweep

> **Depends on:** none (each TODO is independent unless noted). Release
> index: `../future_release_plans/release_v1_0_5.md → TODO-70..94`, one release
> TODO per plan TODO below, in the same order (plan TODO-k = release TODO-(69+k)).
> Origin: `../new_feature_plans/algorithm_choice_audit.md → TODO-B4`. Each
> finding was surfaced by the per-kernel catalog sweep, then checked on
> 2026-10-09 by an adversarial verifier subagent (code reading plus small
> execution checks: pure-R ports, or `pkgload::load_all(compile = FALSE)`
> against the existing `src/EDI.so`; nothing compiled). The coordinator
> re-ran F8, F9, F15 and F22 (reproduced exactly) and re-read F1/F1b.
> **Full evidence for each finding** is in
> `../new_feature_plans/algorithm_choice_audit_catalog.md §13`
> (13.1 = F1–F5, 13.2 = F6–F10, 13.3 = F11–F16, 13.4 = F17–F22, 13.5 = F23–F26).
> Line numbers are as of 2026-10-09; locate by symbol.
>
> **Not included:** F5 (refuted: the BRT studentized/smoothed paths are
> seeded), F24 (refuted: √w cluster-sandwich scaling is correct for
> cluster-constant Dirichlet weights), and F18 (cloglog sign convention;
> already tracked and implemented under `release_v1_0_5.md → TODO-16`).
>
> **Build rule:** per top-level `CLAUDE.md`, any `.cpp` change is verified by a
> targeted compile of the touched file(s) plus relink only. Never a full rebuild.

"IVWC" marks a legacy class (exported, never used in public examples). Those
are fixed here because they are still exported and registered.

## Group A — wrong results on default paths of public classes

- [ ] TODO-1 (F1 + F1c): **`DesignSeqOneByOneRandomBlockSize` redraws are wrong.**
  The class does not override `draw_ws_raw`, so it uses the generic loop at
  `design_seq_one_by_one_abstract.R:190-204`. That loop iterates a *local* `t`,
  but `assign_wt()` reads `private$Xraw[private$t, ]`
  (`design_seq_one_by_one_random_block_size.R:121-140`), so every redrawn
  position uses the last subject's stratum. The block queue `strata_states` is an
  environment shared by the shallow `duplicate()` clone and never reset, so
  redraws start from the real experiment's leftover block and mutate the
  original design (F1c: calling `draw_ws_according_to_design()` directly
  also overwrites the user's `w`). Measured: redraws are block-balanced 51–76% of the time
  (100% required). `random_block_size_redraw_w_cpp` already handles strata
  correctly and is never called (neither are `spbr_redraw_w_cpp` and
  `shuffle_cpp`). **Fix:** override `draw_ws_raw` like SPBR does: per-row
  strata keys plus `random_block_size_redraw_w_cpp` with fresh queues, and no
  mutation of `private$w`, `private$t` or `strata_states`. **Test:** a
  redraw-balance test (every completed block in every stratum balanced; the
  original design's queue and `w` unchanged after `r` redraws). Replace the
  vacuous `0 <= sum(ws[1:4]) <= 4` check in `test-designs.R`.
  **Default change:** randomization and bootstrap p-values and CIs for this design.

- [ ] TODO-2 (F1b): **`sample(private$block_sizes, 1)` R gotcha corrupts real
  assignments** (`design_seq_one_by_one_random_block_size.R:129`).
  `assertIntegerish(block_sizes, min.len = 1)` accepts one value, and
  `sample(4L, 1)` then draws from `1:4`. With `block_sizes = 4` the first four
  subjects were balanced only 70% of the time. The default `c(4,6,8)` is
  unaffected. **Fix:** `private$block_sizes[sample.int(length(private$block_sizes), 1L)]`.
  Grep the package for other `sample(x, 1)` on possibly length-1 vectors.
  **Test:** `block_sizes = 4` gives perfectly balanced consecutive blocks.

- [ ] TODO-3 (F8): **Ridit misscores an interior level that is absent from the
  reference arm** (`src/fast_ridit_analysis.cpp:76-81`,
  `src/ridit_distr_parallel.cpp:59-61`). It scores ½(R_{k−1}+R_k) instead of the
  reference mass below the level, R_{k−1} + ½p_{k−1}, which breaks the documented
  equivalence with Mann–Whitney. Example: class estimate 0.1717 vs
  Mann–Whitney 0.2247. The class's own weighted R path and the JT class both
  give 0.2247. Default `reference = "control"` path. **Fix:** keep the cumulative
  masses in a vector and score the missing level by mass-below, in both files.
  **Test:** a fixture whose control arm omits an interior level, asserting
  equality with Mann–Whitney. The existing reference test's fixture never omits
  a level.

- [ ] TODO-4 (F9): **Newcombe p-value returns 1 for strong effects, and small p
  are inflated** (`inference_incidence_newcombe_univ.R:~157`). The inversion's
  `uniroot` fails to bracket, and the error branch returns 1: 90/100 vs 10/100
  gives p = 1 where `prop.test` gives 1.1e-29 (likewise 180/200 vs 20/200 and
  250/500 vs 100/500). Also, the default `uniroot` tolerance (~1.2e-4 on α)
  inflates small p up to ~160× (75/100 vs 40/100: 7.0e-5 vs 4.3e-7).
  **Fix:** root-search on log α over [log 1e-300, log(1−ε)] with a tight tol.
  Decide the end-point signs explicitly: outside the CI at the floor α means
  return the floor; inside at α ≈ 1 means return 1. **Tests:**
  `test-incid-newcombe-hybrid-wilson-score-reference.R:84-88` currently pins
  p = 1 and must change. Add a strong-effect and a precision regression.

- [ ] TODO-5 (F12, OneLik): **`InferenceContinKKRobustRegrOneLik` randomization
  null uses a different estimator than the observed statistic.** In
  estimate-only mode the null draws fit Huber "M". The observed statistic is
  bisquare "MM" (0.5394) if `compute_estimate()` ran first, otherwise M (0.6248),
  so it depends on call order. `fit_weighted_combined` (Bayesian bootstrap)
  hard-codes "M". **Fix:** keep `private$rlm_method` in every path and only skip
  the SE in estimate-only mode (warm-start bisquare from the cached full fit if
  speed matters). **Test:** randomization statistic at the observed `w` equals
  the reported estimate, regardless of call order.

- [ ] TODO-6 (F21): **Dependent-censoring bootstrap CI is outcome-dependent and
  biased toward non-rejection** (`inference_survival_dep_cens_transform.R:~363`,
  `dep_cens_validate_bootstrap_ci`). The percentile, basic and BCa CIs are replaced
  by the Wald CI whenever the bootstrap CI excludes 0 and Wald does not (never
  the reverse). The studentized CI goes NA (nonestimable) whenever it excludes
  0, so it can never reject. Any endpoint beyond ±2 is declared unstable. The
  roxygen says NA, but the code substitutes Wald. Present since the initial
  commit. **Fix:** remove every zero-based swap or NA. Keep only data-independent
  sanity checks (non-finite values, too few usable replicates, bootstrap-distribution
  diagnostics). Fix the docs. **Tests:** two reference tests assert the biased
  behavior and must be rewritten. Add a test that a CI excluding 0 is returned unchanged.

## Group B — resampling calibrated against the wrong target

- [ ] TODO-7 (F13): **Ordinal KK random-effects Bayesian bootstraps use a
  fixed-effects fit** (`inference_ordinal_KK_clmm_abstract.R:~169`,
  `inference_ordinal_KK_combined.R:~460`). `InferenceOrdinalKKGLMM` reports
  0.583 (matches `ordinal::clmm`), but BB replicates are about 0.414 and the BB
  median is about 0.39. The BB targets the marginal coefficient, not the
  reported conditional one. The KKGLMM roxygen calls it a "fast approximation",
  and the CLMM classes don't document it. CLMM is currently masked by the σ-collapse
  bug (`→ TODO-31`, `glmm_variance_component_sigma_collapse.md`). Once that is
  fixed, CLMM shows the same mismatch, so **land this with or after TODO-31**.
  **Fix:** weighted random-intercept kernels for the BB, or disable BB for these
  classes (as KKGEE does). At a minimum, document that it targets the marginal coefficient.

- [ ] TODO-8 (F14): **KK clogit+GLMM Bayesian bootstraps fit glmmTMB (Laplace)
  on all rows**, while the point estimate uses clogit + 20-node GH
  (`inference_incidence_KK_cond_logit_glmm_abstract.R:~103-151`). Reported
  1.256 / 0.002 vs near-unit-weight replicates 0.910 / 0.339 (two seeds), a ~0.35
  log-OR shift. The IVWC sibling gets the identical BB distribution.
  **Fix:** add weights to `fast_clogit_plus_glmm_cpp` (per-pair on the clogit
  term, per-row in the GLMM) and use it for replicates, or disable BB.
  **Tests:** `test-prop-kk-glmm-weighted-refit-reference.R` pins the glmmTMB
  surrogate and must change.

- [ ] TODO-9 (F2): **`.cox_simulate_stratified` hazard mis-scaling**
  (`helper_survival_fits.R:592-615`). The baseline is normalized by the stratum's
  max risk, but subject risk by the global max, so the hazard shrinks by
  exp(M_s − M_g) in strata without the global max. Result: 61% of simulated
  times tied at `max_time` in such a stratum (corrected: 0.5%), and the refit
  β_x is 0.635 vs a true 1 (corrected: 0.991). This affects
  `InferenceSurvivalStratCoxPHRegr` (stratified) and the `KKStratCox*`
  parametric-bootstrap LR p-values and CIs (non-default; bites with covariates or δ ≠ 0).
  **Fix:** per-stratum `r_s = exp(eta[idx] − max(eta[idx]))`. **Test:** a
  simulate-then-refit recovery test across strata.

- [ ] TODO-10 (F17): **ZOIB R side uses plogis-then-normalize on softmax
  coefficients.** The C++ likelihood is a softmax with mid as the reference
  (`params` = [β, log φ, γ0, γ1]). `zoib_mean_from_coefs` (marginal estimate and
  delta-method SE), the reused-worker bootstrap, and `simulate_under_lik_null`
  apply plogis-normalize instead. `marginal_mean_diff`: EDI −0.0876 vs
  softmax-consistent −0.0816 (truth −0.0782). The default-estimand parametric
  bootstrap is mildly distorted. The weighted-BB path fits separate logits (a
  different functional, so document or align it). **Fix:**
  `d = 1 + e^{a0} + e^{a1}`, `p0 = e^{a0}/d`, `p1 = e^{a1}/d`, `p_mid = 1/d`.
  **Test:** a `marginal_mean_diff` test against a softmax-consistent reference
  (none exists today).

- [ ] TODO-11 (F10): **Zhang exact CI bracket is never validated**
  (`inference_helpers_zhang.R:~44,180,205`). The search bracket is the 2α Wald CI
  widened 50%, and its ends are never checked to lie outside the CI, so bounds are
  silently truncated (CI too narrow). Examples via `InferenceIncidExactZhang`:
  1/19/6/14 gives lower −4.953 (p there 0.068) vs about −5.27; zero-cell tables
  report finite bounds where the truth is ±∞. Also: bisection stops at
  |p − α| < 0.005 (about 0.04·se). Error-as-p = 0 is harmless (pinned
  deliberately). The same bisection is used in `inference_ext_quantile_rand_ci.R`.
  **Fix:** expand the bracket geometrically while p(outside) > α, return ±Inf at
  the cap, and stop on interval width (or tol around 1e-6). **Test:** zero-cell and
  too-narrow-bracket fixtures.

- [ ] TODO-12 (F23): **`DesignFixedOptimal` BRT replays a weaker solver than
  produced the observed allocation.** Replicates always use annealing with
  1 chain × 2000 moves (`design_fixed_optimal.R:512-529`), which stops hot
  (T_final ≈ 0.135 T_0). The observed `w` comes from exact MILP (n ≤ 20) or
  4 × 20000 annealing. Replicate objectives are 6–45× worse (p = 3, n = 20–100), so the
  null is wider. This is **conservative**: size ≈ 0.02–0.03 at nominal 0.05 when R² is
  high, negligible at moderate R² for n ≥ 40. It is undocumented, and the plan
  calls the reduced budget harmless. **Fix:** a replicate profile that
  matches the observed one, or re-solve the observed `w` with the replicate
  profile. At minimum, end the cheap profile cold and document the
  conservativeness. Interacts with `algorithm_choice_audit.md → TODO-20`
  (exact enumeration would make the replicate solver exact at n ≤ ~30).

## Group C — legacy IVWC classes (still exported)

- [ ] TODO-13 (F22): **`InferenceSurvivalKKRankRegrIVWC` always returns NA**
  (estimate, SE, p, CI; reason `kk_rank_regr_ivwc_no_usable_component`, with or
  without covariates; coordinator re-ran). `aftgee::aftsrr(se = "ISMB", B = 0)`
  computes no variance when B = 0, so every rung of the 13-rung ladder is fitted and rejected
  (`inference_survival_KK_rank_regr_ivwc_abstract.R:~286/300/330/344`). Separately,
  the estimate-only path forces the variance to NA while `shared()` needs it finite.
  **Fix:** B ≥ 100 for ISMB (or ISCF), read the SE from
  `sqrt(diag(mod$covmat$ISMB))` rather than the rounded `summary()`, and let the
  estimate-only path combine with cached weights. **Tests:** the migration golden
  passes only because both sides are NA. Add a finite-output test.

- [ ] TODO-14 (F15): **`InferenceAllKKMeanDiffIVWC` randomization null is the
  plain mean difference** (`inference_all_KK_mean_diff_IVWC.R:~160-163`).
  `generate_permutations` never returns `m_mat`, the class substitutes zeros,
  and the C++ kernel sees no pairs. Shipped p = 0.19 vs 0.005 with the correct compound
  null (coordinator re-ran). **Fix:** fill `m_mat` with the design's match ids
  (fixed across re-randomizations), not zeros. **Tests:**
  `test-kk-mean-diff-ivwc-fast-randomization-distr-and-bootstrap-type-bug-reference.R`
  pins the zeros branch as a contract and must change.

- [ ] TODO-15 (F7): **`InferenceAllKKWilcoxIVWC` HL variance is 2.09× too small**
  (`src/fast_wilcox_hl.cpp:~250-285` and its R mirror). Both component formulas
  (all pairwise differences / (n_T+n_C), Walsh averages / m) are wrong by the
  same factor under normality. Class coverage is 80.7% at nominal 95% (KK14,
  n = 80, 300 reps). The bootstrap CI aliases the asymptotic one. **Fix:** a
  consistent τ̂, e.g. the SE from the distribution-free Lehmann interval
  (`wilcox.test(conf.int = TRUE)`) per component, or a Koul–Sievers–McKean τ̂ with
  the correct factor. **Test:** a coverage smoke test.

- [ ] TODO-16 (F11): **KK hurdle-Poisson IVWC placeholder SEs of 1.0**
  (`inference_count_KK_cond_poisson.R:~364,419,449/470,165/177,274/284`). With
  `estimate_only = TRUE` the IVWC combination becomes an equal-weight average.
  Effects: randomization stays valid but loses power (observed and null both
  equal-weight); BB replicates are equal-weight while the CI is centred on the IVWC estimate
  (miscalibrated); `compute_estimate(estimate_only = TRUE)` caches the wrong
  estimate (0.8275 vs reported 0.8199). **Fix:** compute real component variances
  in estimate-only paths, or fix `w*` from the observed variances and reuse it.
  **Tests:** the existing reference test mocks real variances and must exercise
  the estimate-only path.

- [ ] TODO-17 (F12, IVWC): **`InferenceContinKKRobustRegrIVWC` randomization
  p-value is always NA** on the default `use_rcpp` path. With
  `estimate_only = TRUE` the component variance returns NA (`_ivwc.R:~274`), so
  the combined estimate is NA. A fresh `compute_estimate(estimate_only = TRUE)`
  is also NA. **Fix:** the same approach as TODO-5 (keep the method, compute or
  cache component variances).

## Group D — efficiency, documentation, coherence, robustness

- [ ] TODO-18 (F20): **GEE exchangeable α̂ is not divided by φ̂**
  (`src/fast_gee.cpp`, `gee_estimate_exchangeable_alpha`). Overdispersed Poisson
  (φ̂ 4.75): EDI 1.54, clamped to 0.95, vs correct 0.327 (geepack 0.325).
  Proportions (φ̂ 0.083): 0.063 vs 0.763. Affects `InferenceCountKKGEE` and the
  KK GEE fits for proportion (probably ordinal) responses. Incidence is
  unaffected (φ = 1). β and sandwich SEs stay valid, so this is efficiency and
  Rcpp/geepack parity. **Fix:** Pearson φ̂ = Σ w r²/(N − p), then α̂ = num/((den − p) φ̂).
  **Test:** tighten `test-kk-gee-parity.R` (Poisson α tolerance 6e-2 masks it;
  add strongly overdispersed Poisson and a proportion case).

- [ ] TODO-19 (F25): **g-computation SE estimand is undocumented.** The
  delta method propagates β uncertainty only (`src/gcomp_speedups.cpp:244-266,
  453-470`, the KK R fallback, and the ordinal/proportion g-comp classes), so it
  targets the effect conditional on the sample covariates. The population SE is
  larger by 0–6% (coverage 0.932–0.941 vs 0.933–0.945 with the term). **Fix:**
  document the conditional target, or add the `var(r1 − r0)/n` term as an option.
  Also fix `InferenceIncidGCompRiskDiff`'s false roxygen sentence "no closed-form
  asymptotic standard error is used" (its Wald methods use `se_rd`).

- [ ] TODO-20 (F26): **Exact-binomial CI and p-value use different two-sided
  rules.** The CI is Clopper–Pearson (central) but `zhang_exact_binom_pval_cpp` is
  minlike. They disagree only when δ0 ≠ 0: d+ = 0, d− = 5, δ0 = 0.01 is inside the
  CI (−∞, 0.087) yet p = 0.0305 (13,110 disagreeing grid points for k = 5–40).
  **Fix:** one rule for both (central p to match CP, or a minlike/Blaker CI).
  `test-incidence-exact-binomial.R:36` pins CP. Add a coherence test.

- [ ] TODO-21 (F6): **Jonckheere–Terpstra exact p-value can hang
  uninterruptibly** (`src/fast_jonckheere_terpstra.cpp:82-131`). The recursion
  enumerates compositions with no memoization, no size guard and no
  `checkUserInterrupt`: 4.78e12 leaves at K = 11, n = 200, about 13 h at 1e8 leaves/s.
  Only reached by an explicit
  `compute_exact_two_sided_pval_for_treatment_effect()` or the exported cpp
  function (results are correct). **Fix:** polynomial DP over (level, treated
  seen). At minimum add an interrupt check plus a leaf-count guard falling back to
  the normal approximation with a warning. See
  `algorithm_choice_audit.md → TODO-15`.

- [ ] TODO-22 (F3): **`std::shuffle` / `<random>` distributions make draws
  stdlib-dependent.** Algorithms are implementation-defined (libstdc++ vs libc++),
  so the same seed gives different draws on Linux and macOS (distributions
  correct). Default paths: iBCRD initial assignment and redraws,
  `DesignFixedBlocking`, SPBR, stratified blocking bootstrap, greedy,
  rerandomization and optimal/annealing searches. The in-code "cross-platform
  guarantee" comments (`rerandomization_helpers.cpp:34-40`,
  `generate_permutations.cpp:126-133, 438-444`) are wrong; `RNG.h` itself only
  claims raw-stream portability, which is true. **Fix:** hand-written
  Fisher–Yates on `edi_rng::bounded_rand`, and `bounded_rand` / `unif_rand`
  in place of the distributions. **Test:** a fixed-seed golden for
  `generate_permutations_ibcrd_cpp` so macOS CI catches drift.
  **Default change:** seed-pinned draws change once on whichever platform's
  library is not matched. See `algorithm_choice_audit.md → TODO-23`.

- [ ] TODO-23 (F19): **Firth penalty has the wrong sign** in
  `evaluate_penalized_neg_loglik_at`
  (`inference_mixin_off_optimum_likelihood_eval.R:92-106`): it returns
  `neg_loglik + 0.5*log_det` and should be `−`. There are no callers today, and
  `test-off-optimum-likelihood-eval-mixin-reference.R` asserts the wrong sign.
  **Fix:** flip the sign in code, comment and test before anything calls it.

- [ ] TODO-24 (F4, partial; low priority): **Per-replicate seeds drawn with
  replacement from 31 bits** (`sample.int(.Machine$integer.max, B, replace = TRUE)`
  at `param_boot.R:598`, `param_bootstrap_estimate.R:171`,
  `rand_bootstrap.R:698`). Collision probability is about 2.3% at B = 1e4, giving an
  identical parametric-bootstrap replicate. Impact ≤ 1/B. **Fix:** draw without
  replacement, or use L'Ecuyer substreams.

- [ ] TODO-25 (F16, partial; low priority): **g-computation BB weighting
  convention is inconsistent.** Non-KK incidence, proportion and ordinal
  g-comp average predictions unweighted (the sample estimand, consistent with
  their Wald SE); the KK version uses `weighted.mean`. About 1% effect. **Fix:**
  choose one convention, apply it everywhere, and document it (pair with TODO-19).
