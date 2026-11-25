# Release Scope: v1.0.7

> **Status: APPROVED 2026-11-25 (owner).** Follow-up release for the unfinished implementation and
> investigations moved out of v1.0.6. Entries whose implementation is complete and only await CI,
> a build, regenerated results or release verification remain in [v1.0.6](release_v1_0_6.md).
>
> **Counts at the split:** 180 unchecked TODOs, numbered 1–180.
> **Depends on:** v1.0.6. Existing owner-approved exceptions to the fixes-only rule remain in scope.

Both releases were split and renumbered on 2026-11-25 at the owner's request.
The [migration table](todo_migration_2026_11_25.csv) maps every original entry to its current release and number.
Fully qualified TODO citations use the new numbers. Unqualified TODO references in carried-over historical
notes retain their original meaning (including references inherited from v1.0.5/v1.1.0); use the migration table
for old v1.0.6 numbers. `DECISION-*` identifiers are stable historical keys and were not renamed.
Each entry has a `todo-N` link anchor and a comment recording its pre-split number.

An unresolved investigation moves even when its initial calibration screen still needs statistical
confirmation: that is not CI confirmation of an implemented fix. Partially completed entries move when
substantive work remains (for example the harness, subset-copy ZIP failure and duplication backlog);
their completed steps and evidence are preserved and must not be implemented again.

## Entry rule

A TODO belongs in v1.0.7 only if all three hold:

1. It fixes one of these:
   - wrong output;
   - a crash or a hang;
   - a false `converged = TRUE`;
   - an NA where a value is defined;
   - output that depends on call history or draw order;
   - a performance regression introduced by v1.0.5.
2. It adds no user-facing API and changes no default beyond the D2 numerical-equivalence rule. A fix that corrects
   wrong output may move results; it says so in NEWS.
3. Its fix is known, or its investigation is bounded (a named experiment with a stop condition).

Everything else stays in v1.1.0: new methods, options, capabilities, small-sample corrections (Bartlett, Firth,
bootstrap-calibrated tests), performance work that is not a v1.0.5 regression, and refactors. Calibration rows that
were accepted with a TODO ("oversized at n = 50") enter v1.0.7 only if triage finds a bug behind them.

## Gates (lighter than v1.0.5)

Run only the gates that the merged changes require.

| Gate | When | What |
|---|---|---|
| G1 build | any C++ change | User-run build. Agents compile touched files only (`EDI_UNITY=0`, see `CLAUDE.md`). |
| G2 timing | only if a kernel or a resampling loop changes, or for the GLMM warm-start regression fix (v1.0.7-TODO-5) | Quiet host (1-min load < 1.0), the affected benchmark sections only, compared with `R/benchmark/compare_benchmark_runs.R` against the v1.0.6 reports. |
| G3 parity | always | Untouched classes reproduce v1.0.6 under D2 on the parity fixtures. Touched classes: every change is listed and explained. |
| G4 results | touched classes only | Regenerate the comprehensive-test slices and the calibration fast tier for the touched classes; no full regeneration. |
| G5 CI | always | All required checks green at the release SHA; sanitizer/valgrind jobs too if C++ changed. |
| G6 docs | always | Roxygen and Rd regenerated with 0 warnings; NEWS lists every fix and every moved result. |
| G7 CRAN | always | `release.md` checklist (win-builder, mac-builder, reverse dependencies, `cran-comments.md`). |


The original [triage tables](release_v1_0_6.md#historical-triage-of-v110-todos-that-came-from-v105-approved-2026-11-10) remain in v1.0.6 as historical context.

## Implementation TODOs

Descriptions and dated progress notes are carried over from the original checklist. Historical bare TODO
numbers retain their pre-split meaning; the migration table and each entry's provenance comment identify the old number.

<a id="todo-1"></a>
<!-- pre-split-id: 1.0.6/1; 2026-11-25 -->

- [ ] TODO-1 (moved 2026-11-10 from `release_v1_1_0.md → TODO-74`, owner approval of the v1.0.6 triage; originally added 2026-10-23, user decision; moved here first because
  v1.0.5 is closed; split out of `release_v1_0_5.md → TODO-128`):
  **The Bayesian jackknife depends on call history.** *(reproducibility
  fix; small numeric change)*
  - Problem: `approximate_bayesian_jackknife_distribution_beta_hat_T()`
    (`R/EDI/R/inference_all_abstract_bayesian_bootstrap.R`, the BCa
    acceleration for the Bayesian bootstrap) refits on
    `self$duplicate(make_fork_cluster = FALSE)`, so the leave-one-out refits
    inherit whatever warm-start state earlier calls left on the object.
    v1.0.5 TODO-128 fixed this for the ordinary jackknife (reused-worker
    cache keyed by operation; log-binomial workers seeded from the full-data
    fit), but that fix does not reach this path. A user's Bayesian BCa
    interval or p-value can therefore change with what ran before it.
  - Evidence (2026-10-23, installed EDI built 2026-10-22 19:33 UTC, before
    patch 14): simulated n = 100, three covariates, 100 folds; fresh object
    vs. the same object after a Bayesian bootstrap CI, a BCa bootstrap CI, a
    jackknife estimate and an LR CI, with `bayes_jack_distr_cache` cleared
    before recomputing. `InferenceCountHurdleNegBin` identical for `~1` and
    `~.`; `InferenceIncidLogBinomial` `~1` max |diff| 1.7e-13, `~.`
    **3.4e-7**. On `pte_example` the six-class harness mix with the cache
    reused was 2,166 / 2,166 identical to cold, so those data do not
    trigger it.
  - Work:
    1. Recheck with patch 14 built (it was compiling at 2026-10-23 12:20
       IDT). If converged log-binomial fits make the folds start-independent,
       the difference may vanish without an R change; record the result.
    2. If it remains: make the refits independent of prior state, mirroring
       TODO-128, e.g. seed `inf_work` from the full-data fit (`cached_mod`)
       or clear its inherited warm-start state before the loop. Check other
       classes whose Bayesian-bootstrap dispatch policy is warm.
    3. Test: the Bayesian jackknife (and the Bayesian BCa CI built from it)
       on a fresh object equals the one computed after the calls above, for
       log-binomial `~1` and `~.` (≤ 1e-8, ideally identical). Extend
       `test-log-binomial-jackknife-history-independence.R` or add a sibling.
    4. Add `bayes_jack_distr_cache` to `REUSED_RESAMPLING_CACHES` in
       `R/package_tests/comprehensive_tests.R` and repeat the harness
       identity check (cold vs. reuse, `fork=FALSE`).
  - Default change: only where results currently depend on history (the
    fresh-object result should stay bit-identical); note in NEWS if any
    fresh-object output moves.
  - Pointers: `release_v1_0_5.md → TODO-128` (2026-10-23 note);
    `../audits/further_optimizations.md` (draw reuse).

<a id="todo-2"></a>
<!-- pre-split-id: 1.0.6/2; 2026-11-25 -->

- [ ] TODO-2 (moved 2026-11-10 from `release_v1_1_0.md → TODO-157`, owner approval of the v1.0.6 triage; originally added 2026-10-25, owner decision at G4-C R4A of v1.0.5):
  **RMST randomization-bootstrap: per-draw tau, and a possible
  uncensored-only CI.** v1.0.5 refuses every
  `compute_rand_bootstrap_confidence_interval*` type for
  `InferenceSurvivalRestrictedMeanDiff` (the survival shift is a log-time
  ratio, not the RMST difference). Two follow-ups:
  - Per-draw tau: with the default horizon, each null draw recomputes tau as
    the smaller arm's maximum follow-up (~10 in R4 vs ~4 observed), so the
    studentized pivot's SE is ~1.85x too large. Hold tau at the observed
    value in every draw (fast kernel `fast_survival_stats.cpp` `rmst_tau` arg
    plus the R slow path). This also affects the rand-bootstrap p-value at
    delta = 0; measure its null rejection (5% CP rule) before and after.
    Needs a rebuild.
  - Uncensored-only CI (optional): with no censoring, the RMST difference at
    a fixed tau is the mean difference of z = min(y, tau), so the sharp null
    "z shifted by delta" is invertible. It needs its own statistic (the mean
    difference of the pre-truncated z, with no re-truncation and no tau
    recompute) and an additive transform, not the log path. Validate the
    coverage with an R4-style study before enabling. The censored case stays
    refused.
  - Pointer: `release_v1_0_5.md → G4-C batch failures, R4A`.
  - **Scope in v1.0.7:** the per-draw tau fix only. The uncensored-only CI stays in `release_v1_1_0.md → TODO-157`.

<a id="todo-3"></a>
<!-- pre-split-id: 1.0.6/3; 2026-11-25 -->

- [ ] TODO-3 (moved 2026-11-10 from `release_v1_1_0.md → TODO-160`, owner approval of the v1.0.6 triage; originally added 2026-10-26, owner decision at G4-C R2 of v1.0.5: defer
  from 1.0.5): **Stereotype logit: scale-driven usability gate and silent
  covariate dropping.** Found by the v1.0.5 R2 null study
  (`todo8_stereotype_null_study.R`, 400 seeds per cell). Neither fix changes
  the n = 100, K = 5 Type-I excess (12.9%; 11.5% with 41 starts, ungated),
  which is documented as a small-sample limitation in the class roxygen.
  - (a) `stereotype_fit_is_usable()` (`inference_ordinal_stereotype_logit.R`,
    ~L290) rejects a fit when the unscaled `rcond(information_free)` <=
    sqrt(eps). That measures covariate scale, not ill-conditioning (scaled
    rcond of rejected vs kept fits 0.021 vs 0.025); 30-38% of fits come out
    non-estimable, and at n = 50 the gate flatters the result (rejected seeds
    13.3%, kept 4.6%, ungated 5.8%). Fix: scale the information matrix (e.g.
    to a correlation-scale D^-1/2 I D^-1/2) before the rcond test.
  - (b) The QR column-dropping fallback silently drops covariate x1 in 33/248
    (n = 100) and 27/280 (n = 50) results, leaving a treatment-only model
    whose LR is non-regular at the null. Fix: warn, or refuse the fit,
    instead of dropping silently.
  - Acceptance: rerun R2 (both cells); report the non-estimable rate and the
    Type-I error with and without the gate; no silent column drops.
  - Pointer: `release_v1_0_5.md → G4-C R2`.

<a id="todo-4"></a>
<!-- pre-split-id: 1.0.6/5; 2026-11-25 -->

- [ ] TODO-4 (moved 2026-11-10 from `release_v1_1_0.md → TODO-165`, owner approval of the v1.0.6 triage; originally added 2026-11-08, owner; follow-up of v1.0.5 TODO-190): **`InferenceIncidLogBinomial`: tighten the full-data fit when a subject sits at fitted probability exp(X b) = 1.**
  - Found by: the v1.0.5 TODO-190 agent (2026-11-08). In 4 of 1600 calibration fits (all n = 50, `~.`), the C++ fit (`src/fast_log_binomial_regression.cpp`, TODO-128 active-set / KKT gate) stops with the nuisance score off zero: rep 31 at prob_T 0.5 has x2 score 0.037, and Nelder-Mead reaches the same log-likelihood at x2 = 0.46476 vs the kernel's 0.46442. The KKT check in `edi_log_binomial_kkt_terms()` then rejects the null fit near the estimate, the gradient p-value there is `NA`, gradient CI inversion cannot start, and v1.0.5 substitutes the LR interval (with the `edi_lik_ci_lik_ratio_fallback` warning).
  - Related: the same KKT gate also passed a non-optimal warm-started null fit where the binding set changes (v1.0.5 TODO-181 leftover, worked around by a cold refit in `fit_null`).
  - Fix: tighter boundary convergence in the kernel (for example a KKT-residual stopping rule in the free directions), verified per-file (no full build). Then drop or keep the v1.0.5 LR substitution in `compute_gradient_confidence_interval_impl()`.
  - Done when: on the TODO-190 study grid (200 reps x n 50 / 200 x prob_T 0.5 / 0.2 x `~1` / `~.`), no LR substitution fires and the full fit's nuisance score is 0 to 1e-6 at boundary MLEs.

<a id="todo-5"></a>
<!-- pre-split-id: 1.0.6/6; 2026-11-25 -->

- [ ] TODO-5 (moved 2026-11-10 from `release_v1_1_0.md → TODO-167`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found by the v1.0.5 TODO-62 benchmark regression check): **GLMM / CLMM kernels run the full log-sigma multistart even when given `warm_start_params`.**
  - Why: v1.0.5 TODO-31 (e706c6f6) made `fast_logistic_glmm_cpp` (`src/fast_logistic_glmm.cpp` ~L521-565) and `fast_ordinal_clmm_cpp` (`src/fast_ordinal_clmm.cpp` ~L107-144) screen 5 log-sigma starts, and `fast_poisson_glmm_cpp` (`src/fast_poisson_glmm.cpp` ~L414-472) 5 sigma starts x 2 beta starts, keeping the best objective. The screening also runs when the caller passes a warm start, so warm starts save nothing: on the benchmark pairs fixture, warm-started at the optimum, logistic 46 ms vs 47 ms cold, CLMM 88 ms vs 79 ms cold (2026-11-09 probe, installed EDI). Bootstrap, randomization and CI-search refits that warm-start therefore pay about 5x per refit.
  - Fix: when `warm_start_params` is supplied (and finite, length-checked), start from it alone, optionally plus one cold start, and keep the better objective; keep the full screen for cold fits. Verify per file (no full build).
  - Done when: warm-started refits at the optimum cost about one single-start fit; cold-fit results unchanged bit for bit; resampling results unchanged or with the change explained (a warm start can land in a different mode than the screen, so check on the TODO-31 sigma-collapse datasets).

<a id="todo-6"></a>
<!-- pre-split-id: 1.0.6/7; 2026-11-25 -->

- [ ] TODO-6 (moved 2026-11-10 from `release_v1_1_0.md → TODO-169`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found computing the v1.2.0 TODO-36 calibration-study truths): **`InferenceIncidModifiedPoisson` with `~1` returns NA at large n.**
  - Why: on the study's incidence generator (5 covariates, beta_T at the n = 200 power50 effect, `DesignFixedBernoulli`, prob_T 0.5, seed 4242) `compute_estimate()` gives 0.249 / 0.257 / 0.256 at n = 200 / 2000 / 5000, then NA at n = 10000 and 20000 with non-estimable reason `model_fit_unavailable`: no error, no warning. `~.` on the same data is fine at n = 20000 (0.206). In `calibrate_study_truths.R` (8 fits of n = 20000 per cell) `~1` failed in 9 of 12 cells, so those power cells have no true value and their non-null coverage goes untested.
  - Investigate first: which fit step reports `model_fit_unavailable` above ~10^4 rows for the treatment-only model (an iteration cap, a convergence tolerance that does not scale with n, or a sandwich-variance step); whether `InferenceIncidKKModifiedPoisson` shares it.
  - Done when: `~1` returns a finite estimate at n = 10000 / 20000 / 50000 on that generator, agreeing with `glm(..., family = poisson)` plus sandwich SEs to 1e-6; a regression test at n = 20000; the truths re-run with the ModifiedPoisson `~1` cells usable.

<a id="todo-7"></a>
<!-- pre-split-id: 1.0.6/9; 2026-11-25 -->

- [ ] TODO-7 (moved 2026-11-10 from `release_v1_1_0.md → TODO-189`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; follow-up of v1.0.5 TODO-179): **Boundary MLEs of the constrained binomial classes: what is left after Wald became NA for `InferenceIncidLogBinomial`.**
  - Done in v1.0.5 TODO-179 (2026-11-09, the "make Wald NA at the boundary (with LR suggested)" idea): `InferenceIncidLogBinomial` returns NA for the Wald p-value and CI when the full-data MLE has a linear predictor within 1e-8 + 1e-6 of 0, with warning class `edi_wald_mle_boundary_unavailable` and `procedure_failure_reason[["wald"]]`; `fit_null` got a strictly feasible last-resort start, so the LR interval at those fits no longer falls back to Wald (526 -> 75 of 1000 at n = 50). Study cell (Bernoulli, `~.`, p = 5, 1000 null reps): Wald NA in 68% (n = 50) / 66% (n = 200) of reps; Wald size over the rest 0.041 / 0.047, coverage 0.959 / 0.953.
  - (a) LR is still oversized at boundary MLEs: size 0.085 (n = 50) / 0.078 (n = 200) in boundary reps vs 0.048 / 0.044 interior; LR coverage 0.924 / 0.934. Candidates: parametric-bootstrap-calibrated LR (`compute_lik_ratio_bootstrap_*`, already supported) as the recommended boundary procedure, or a chi-bar-squared reference.
  - (b) 75 of 1000 LR CIs at n = 50 (7 at n = 200) still fall back to Wald: one null refit at a single delta fails (non-converged) while neighbouring deltas succeed. Overlaps TODO-165 (kernel boundary convergence). Either fix the kernel or let the root search step past one failed refit; and decide whether a Wald fallback under the LR label should itself be NA at a boundary MLE.
  - (c) `InferenceIncidBinomialIdentityRiskDiff` (identity link, bounds at mu = 0 and 1, same TODO-128 warning and `edi_binomial_bound_kkt_core()`) was NOT changed: its Wald path is the generic `StandardModelCache` one, and the identity-link boundary needs its own decision (two-sided bounds; `~1` boundary is a 0% or 100% arm, where the SE is already 0). Measure its boundary share and Wald size in the study cell first. `InferenceIncidRiskDiff` (unpooled Wald, v1.1 TODO-179) does not have this boundary.
  - Accepted rows (2026-11-12): the 2 `InferenceIncidLogBinomial` score `~.` n = 50 prob_T 0.5 rows (size 0.09, coverage 0.915; boundary MLEs) that cited a bare `TODO-179` now cite this TODO.
  - Done when: (a)-(c) are each fixed or ruled honest by the owner, and the LogBinomial / BinomialIdentity accepted calibration rows say which.
  - **Scope in v1.0.7:** parts (b) and (c) only. Part (a) is triaged in TODO-13; its fix, if any, stays in `release_v1_1_0.md → TODO-189`.

<a id="todo-8"></a>
<!-- pre-split-id: 1.0.6/10; 2026-11-25 -->

- [ ] TODO-8 (moved 2026-11-10 from `release_v1_1_0.md → TODO-190`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found by bulk CI run 42638595069): **`fast_clogit_plus_glmm_cpp()` stops short of a zero random-intercept variance and still reports `converged = TRUE`.**
  - Found by: `R/package_tests/testthat_bulk/test-prop-kk-glmm-weighted-refit-reference.R`, failing since the v1.0.5 pair-grouping fix (`b1e96231`, TODO-173), which made the kernel fit one random intercept per matched pair instead of one per row. On that test's `InferencePropKKGLMM` fixture (n = 80, KK14, proportion response, `~ x1 + x2`) with block bootstrap weights, the weighted optimum is at sigma = 0: a weighted `glm()` gives beta_T 0.07979 (negative log-likelihood 93.2709), and `glmmTMB` (Laplace) and `lme4::glmer(nAGQ = 20)` agree, both flagging a singular fit. EDI's L-BFGS (`optimize_fixed_likelihood()`, `optimization_alg = "lbfgs"`, `max_abs_log_sigma = 8`) stops after 11 iterations at log sigma = -3.81 with negative log-likelihood 93.2794 and gradient norm 0.22, yet reports `converged = TRUE`, giving 0.08168 (2.4% off). The unweighted fit on the same data agrees with `glmer` to 0.2% (0.11855 vs 0.11878).
  - Interim: the test's tolerance was loosened from 1e-3 to 0.03 (2026-11-09), with a comment pointing here.
  - Investigate first: why `converged` is TRUE at gradient norm 0.22 (a function-change stop that fires on the flat log-sigma direction?); whether other kernels that share `optimize_fixed_likelihood()` with a log-variance parameter (continuous/count KK GLMM, the GLMM Weibull frailty classes) stop short the same way near sigma = 0.
  - Fix (candidates): gate `converged` on the gradient norm; when log sigma runs toward `-max_abs_log_sigma`, refit with sigma fixed at 0 (the plain GLM) and keep the better likelihood; or profile sigma out at the boundary.
  - Done when: on that fixture the weighted estimate matches the weighted `glm()` / `glmer(nAGQ = 20)` value to 1e-4 relative, `converged` is FALSE whenever the gradient norm is above tolerance, and the test's tolerance is back at 1e-3.
  - Note (coordinator 2026-11-21): the rand warm-start chaining study found `InferencePropKKGLMM` fits depend on the
    start by up to 1e-2 (base-start worker 0.39643 vs observed 0.39727 on the original data); same symptom. The
    v1.0.6-TODO-117 / v1.0.6-TODO-118 shared convergence rule (`_helper_functions_core.h`, owner build pending) may already gate
    `converged` here; re-check this fixture after the build.

<a id="todo-9"></a>
<!-- pre-split-id: 1.0.6/11; 2026-11-25 -->

- [ ] TODO-9 (moved 2026-11-10 from `release_v1_1_0.md → TODO-192`, owner approval of the v1.0.6 triage; originally added 2026-11-10, owner; from v1.0.5 TODO-1's closing, `finished_features/v1_0_5/reusable_bootstrap.md` TODO-6): **Realistic proportion data for `tune_EDI_for_this_machine()`.**
  - Problem: the tuner's proportion fixture is noiseless. `inference_migration_complete_design()` (`local_machine_tuning_synthetic_fixtures.R`) sets `y = pmin(0.95, pmax(0.05, plogis(linpred)))` with no noise and no exact 0s or 1s (`edi_tuning_synthetic_experiment()` adds zero mass only for zero-inflated/hurdle count classes). Every proportion fit recovers the true coefficient 0.55 exactly, the precision parameter diverges, and jackknife summaries are degenerate (ZOIB: every warm-started fold returns 0.55, SE ~4e-9; NA at n = 50 and 1000). ZOIB's zero/one submodel is never exercised.
  - Effect on the tuner: warm vs cold timings are distorted. The 2026-11-10 ZOIB jackknife A/B (`scratch/v1_0_5_g2_outputs/zoib_jackknife_ab_2026-11-10/`) gave warm start ON 0.76 s vs OFF 10.6 s at n = 200 and 13.0 vs 248 s at n = 1000 (14-19x), likely inflated because cold fits chase a diverging precision. The correctness gate also cannot verify cells whose summary is NA. Applies to every proportion class the tuner times.
  - Fix: add real noise to the proportion response (e.g. a beta draw around `plogis(linpred)` with a fixed precision, seeded as now) and, for classes with a zero/one part (ZOIB), a small share of exact 0s and 1s, the way count classes get structural zeros. Keep the fixtures deterministic per seed. Check every other caller of `inference_migration_complete_design()` (migration goldens) before changing it, or add a separate tuning-only generator.
  - Done when: proportion fits on the tuning fixture give finite, non-degenerate jackknife summaries at n = 50, 200 and 1000; ZOIB's zero/one part is fitted; the ZOIB jackknife A/B is re-measured and recorded; affected golden tests pass or are deliberately updated.

<a id="todo-10"></a>
<!-- pre-split-id: 1.0.6/13; 2026-11-25 -->

- [ ] TODO-10 (added 2026-11-10, owner approval of the v1.0.6 triage): **Triage the v1.0.5-born calibration and
  test-size TODOs that stay in `release_v1_1_0.md`.** For each, run the check in the historical "Triage first" table in `release_v1_0_6.md` and record
  the result in both files. A bug found moves its fix here as a new TODO; honest small-sample or misspecification
  behaviour stays in v1.1.0 (corrections work, TODO-5 there) with a dated note.
  - `release_v1_1_0.md` TODO-159 (cloglog param bootstrap conservative), TODO-178 (log-binomial score at prob_T 0.2;
    run with TODO-5 here), TODO-189 (a) (LR oversized at boundary MLEs), TODO-174 (hurdle Poisson `~1`).
  - `release_v1_1_0.md` TODO-170 (added 2026-11-11, owner; Stereotype gradient / LR at n = 50, size about 0.085): take
    the reps that reject in the 2026-11-09 local n = 50 run (`run_calibration_fast_tier.R`, both prob_T; saved at
    `~/edi_regen/stereotype_fast_tier_20261111/n50_n200_run20261109/n50/rows.csv`), refit the null
    model from many starts (e.g. 20 random plus the current cold starts) and recompute the LR and gradient statistics.
    Stop condition: if a fair share of the rejections (say >= 20%) go away, the null refit misses the global mode and
    the fix (a better multistart in `fit_null`) comes here as a new TODO; if not, record that the excess is a
    small-sample property and TODO-170 stays in v1.1.0. The same check covers the score test (TODO-168).
  - Calibration rows oversized at n = 50 or prob_T = 0.2: TODO-168, 171, 172, 173, 175, 176, 177, 179, 180, 181, 182, 183,
    184, 185, 186, 187, 188. Per class: SE vs sd(estimate), share of boundary or non-converged fits, a variance
    collapsing to 0.
  - Done when: every listed TODO has a dated triage result and a placement.

<a id="todo-11"></a>
<!-- pre-split-id: 1.0.6/14; 2026-11-25 -->

- [ ] TODO-11 (added 2026-11-10, owner; **exception to the entry rule above**: a repository-layout refactor with no
  package code, API or result change): **Repository layout cleanup.**
  - Plan: `../new_feature_plans/v1_0_7/repository_layout_cleanup.md`.
  - What changes:
    - Project-wide material in `R/package_metadata/` (plans, releases, audits, contracts, dataset catalogs) moves to
      a root `metadata/`.
    - R-only notes (~10 files) move to `R/metadata/`.
    - `R/package_tests/` stays under `R/`, renamed (name to be decided).
    - The coverage-floor gate moves to `scripts/`, and `benchmark_model_fits_python.py` moves to `python/benchmark/`.
    - No root `tests/`, and no C++ moves (that is the v4.0.0 `core/` step).
  - Order: its own commit, after the 2026-11-10 per-release subfolder reorganization of the plan folders is
    committed.
  - Gates: G5 (every touched workflow green, scheduled ones via `workflow_dispatch`) and G6 (roxygen paths changed,
    so regenerate Rd). G1 only if C++ header comments are updated, since that recompiles their includers.
  - Includes the two C++ header comments left stale on 2026-11-10 (owner, 2026-11-11):
    - `R/EDI/src/na_real_core.h` L19 gives `package_metadata/finished_features/unity_build_collision_audit.md`.
    - `R/EDI/src/RNG.h` L17-18 gives `package_metadata/new_feature_plans/sexp_removal_rcppeigen_conversion_spec.md`,
      which was already wrong before 2026-11-10 (the plan is in `finished_features/`).
    - Point both at their final location after this TODO's move: `metadata/finished_features/v1_0_0/…`.
    - Make the edit with the other header-comment updates, in a change that goes with a user-run build (G1), since a
      header edit recompiles every file that includes it.
  - Done when: the plan's Verification section passes and its TODO-1..6 are ticked.

<a id="todo-12"></a>
<!-- pre-split-id: 1.0.6/15; 2026-11-25 -->

- [ ] TODO-12 (added 2026-11-10, owner; **exception to the entry rule above**: new test infrastructure with no package
  code, API or result change): **Native C++ test suite for the R-free core.**
  - Plan: `../new_feature_plans/v1_0_7/native_cpp_test_suite.md`.
  - Phase 1 (this release):
    - A CMake/CTest suite in a root `cpp_tests/` (moves to `core/tests/` at v4.0.0) that builds the `EDI_CORE_ONLY`
      sources from `R/EDI/src`, sharing the Python build's source list.
    - Optimizer edge cases in `_helper_functions_core.h`, and the Cox descent guard and backward sum.
    - ASan/UBSan builds and time-boxed libFuzzer harnesses.
    - One new CI job, not required until it has a green streak.
  - Not here: thread-count determinism of design draws. The design kernels have no R-free path yet, so that waits for
    a v1.1.0 refactor (next to `release_v1_1_0.md` TODO-48).
  - Agent builds are whitelisted in `CLAUDE.md` (owner, 2026-11-10) for each test target's minimal file subset only; location decided: `cpp_tests/`.
  - Gates: G5 (the new job green). G1 does not apply: the R package build is unchanged.

<a id="todo-13"></a>
<!-- pre-split-id: 1.0.6/16; 2026-11-25 -->

- [ ] TODO-13 (added 2026-11-11, owner; opened with the accepted calibration rows it covers; bounded investigation
  under entry rule 3 — if it finds no bug, move it to v1.1.0 as a small-sample item): **`InferenceCountZeroInflatedNegBin`
  / `InferenceCountZeroInflatedPoisson`: likelihood and Wald tests oversized at n = 50.**
  - Why: nightly calibration fast tier 2026-11-09 (run 42583252947, commit `749977ab`, 1000 reps, synthetic count DGP,
    `DesignFixedBernoulli`) failed 20 cells with no accepted rows:
    - ZINB, both prob_T: all four tests with `~.` (size 0.100-0.144; score worst, 0.131 / 0.144; Wald 0.121 / 0.137),
      score `~1` (0.117 / 0.113), and Wald `~1` at prob_T 0.2 (0.094).
    - ZIP: every test at prob_T 0.2, both formulas (0.084-0.118; Wald worst), and Wald `~.` at prob_T 0.5 (0.093).
    - At n = 200 both classes pass, but are still somewhat high (worst size 0.074 / 0.072).
    - Accepted rows (reason starting `v1.0.7 TODO-13`) are in
      `R/package_tests/calibration/calibration_fast_tier_accepted.csv`.
  - Suspicious, so possibly a bug, not only small n: ZINB Wald `~.` at prob_T 0.5 is 0.137, while most other count
    classes are near nominal in the same cell. v1.0.5 TODO-169 / TODO-185 found saturated zero-inflation fits (a flat
    zero-inflation ridge with a near-singular nuisance information) behind the CI-inversion failures.
  - Investigate (bounded): on the installed build, re-run the fast tier for both classes at n = 50 / 100 / 200 (1000 reps).
    - For the rejecting reps, record the share of fits with the zero-inflation probability at 0 or 1, theta at its
      bound (ZINB), and a near-singular information.
    - Compare the SE with sd(estimate).
    - Stop when the excess is attributed either to boundary or ridge fits (a bug: fix the fit or the information, as in
      TODO-169/185) or to a smooth small-sample effect (move to v1.1.0: bootstrap-calibrated or Bartlett-type
      correction).
  - Done when: the cells pass the fast-tier gate at nominal and the `v1.0.7 TODO-13` rows are pruned; or the owner
    rules the excess inherent, and the rows stay with a reason saying why. A "Small samples" roxygen note is added to
    both classes if any rows remain at release.

<a id="todo-14"></a>
<!-- pre-split-id: 1.0.6/17; 2026-11-25 -->

- [ ] TODO-14 (added 2026-11-11, owner; **exception to the entry rule above**: calibration-study infrastructure with no
  package change, like TODO-14/15): **Stop clearly passing null cells early in calibration campaigns.**
  - Why: TODO-21 (was v1.0.5 TODO-203) made campaigns class-major and Amendment E sized shards from measured costs, but the remaining
    time is the fits themselves. Campaign `2026-11-11-9d2edc5c` predicted about 14,700 core-hours of screening, so
    about 11 days of screening plus 1-2 days of confirmation on 16 free runners. Most null cells sit far inside their bound
    long before 1000 replicates.
  - Idea: two looks per null unit (one class with all its procedures, one design, one n), for example at 500 and 1000
    replicates. At the first look, a unit stops if every test in it (size for each procedure and formula, plus
    coverage from the same replicates) is clearly inside its bound; borderline units run to 1000 as today. Rough saving:
    30-50% of null work, several days per campaign.
  - Owner decision pending: [DECISION-v1.0.6-TODO-17](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-17) (the five design questions to settle before any code: first-look margin, p-value of a stopped unit, weighting, post-stop bias, confirmation replicates).
  - Where: `R/package_tests/calibration/plan_calibration_study.R` and `calibration_study_plan_common.R` (units, looks),
    `analyze_calibration_study.R` / `convergence_calibration_study.R` (p-values, weighting), `calibration_gates.md`.
  - Done when: the rule is written into `calibration_gates.md` with its power check, the planner stops units at the first
    look, a synthetic-campaign test shows no change in false-flag rate and the agreed power, and one campaign completes
    with it.

<a id="todo-15"></a>
<!-- pre-split-id: 1.0.6/18; 2026-11-25 -->

- [ ] TODO-15 (added 2026-11-12, owner; **exception to the entry rule above**: the owner placed it in v1.0.6 although a
  studentized or reduced-model bootstrap is a small-sample correction that the rule sends to v1.1.0; found by v1.0.5
  TODO-18's true-null study, runbook R3): **Percentile and smoothed randomization-bootstrap p-values are
  anti-conservative when the model has many covariates per observation.**
  - Evidence (R3, `~/edi_regen/batch_20261023T144230Z/r3_todo18_smoothed_brt/`, diamonds n = 148, Bernoulli, B = 101,
    500 cases): `InferenceContinOLS` `~.` (24 columns) percentile 14.2%, smoothed 13.4%; `InferenceCountPoisson` `~.`
    7.6% / 7.6% (rerun 2026-10-25). Same data with `~1`: nominal; OLS Wald 4.15%. Mechanism: a resample holds about 94
    distinct rows of 148, so each refit overfits and the null SD is about 0.71 of the true SD (replica), predicting
    about 16.5% rejection. Smoothing is not involved (paired discordance <= 2.4%). A milder small-n version: the
    TODO-18 permanent test's fixture (`InferenceAllSimpleAverageDiff`, count, n = 60, B = 51) rejects about 11% for
    both variants.
  - Candidate fixes, to compare on the two R3 cells and the small-n fixture: (a) default or fall back to
    `type = "studentized"` when the class exposes an SE and p / n is large; (b) refit the null draws with a reduced model;
    (c) warn above a p / n threshold and point to studentized / model-based tests. (a) and (b) move default output, so
    they need an owner decision and a NEWS entry.
  - Done when: the chosen fix brings both R3 cells to the R3 rule (Holm, >= 500 finite) or the warning is in place
    with its threshold justified by the same study; the "many covariates" paragraph of the
    `compute_rand_bootstrap_two_sided_pval()` docs (`inference_all_abstract_rand_bootstrap.R`) is updated to match.

<a id="todo-16"></a>
<!-- pre-split-id: 1.0.6/19; 2026-11-25 -->

- [ ] TODO-16 (moved 2026-11-12 from `release_v1_0_5.md → TODO-196`, owner decision; originally added 2026-11-10, owner;
  **exception to the entry rule above**: it ships new data to users rather than fixing a bug; the owner moved it here so
  v1.0.5 does not wait for a complete calibration campaign): **Ship the measured size / coverage / bias per design x
  class x procedure x n from the latest complete campaign inside the package (with campaign id and EDI commit), and
  surface it next to the expected rate.** GATED on the first complete calibration campaign (`2026-11-09-8c32d060` or
  its successor under TODO-21's class-major order). Plan:
  `new_feature_plans/v1_0_5/inference_validity_user_visibility.md`, section 3. The consumer hook already exists:
  `edi_procedure_validity_measured()` in `R/EDI/R/inference_validity_lookup.R` returns `NULL` until this lands
  (v1.0.5 TODO-197).

<a id="todo-17"></a>
<!-- pre-split-id: 1.0.6/20; 2026-11-25 -->

- [ ] TODO-17 (moved 2026-11-12 from `release_v1_0_5.md → TODO-202`, owner decision, so v1.0.5 does not wait on the
  calibration campaign; originally added 2026-11-10, from the calibration study; enters under the entry rule as a
  bounded investigation of possible wrong output, confirmed or closed by the campaign's confirmation stage):
  **`InferenceContinKKGLMM`'s randomization test is oversized on the KK and matching designs.** A randomization test
  should hold its level at every n (finite-sample regime, gate level 0.05), but in campaign `2026-11-09-8c32d060`
  (simulated at `8c32d060`, screen stage, n = 50, null, 1,000 replicates per cell) `rand` rejects at 0.072 on
  `DesignSeqOneByOneKK21` (`~ .`; `~ 1` 0.060), 0.069 on `DesignSeqOneByOneKK14` (`~ .`), 0.058 / 0.059 on
  `DesignFixedBinaryMatch` and 0.060 / 0.067 on `DesignSeqOneByOneKK21stepwise`: pooled 0.062 over its 8 cells (about
  3.5 SE above 0.05 once the shared replicates of the two formulas are allowed for). The count, proportion and ordinal
  `KKGLMM` siblings pool to 0.047 / 0.052 / 0.053 on the same designs, so it is specific to the continuous class. Weaker
  signal to check at the same time: every other continuous class's `rand` on the KK / matching designs pools to 0.054
  (110 cells; the classes share replicates, so the SE of 0.0007 understates the noise), against 0.051 on the other
  designs. Investigate: (1) whether the randomization reference distribution re-runs the sequential KK matching (and the
  fixed matching) for each draw, rather than permuting within the observed pairs/reservoir; (2) whether the KKGLMM
  continuous statistic used by `compute_bootstrap_worker_estimate` / the randomization worker matches the observed
  statistic (the KK Wilcox class had exactly this mismatch, fixed 2026-10-12); (3) the p-value convention ((1 + #) / (1
  + r)) and r. Confirm first: the cell is provisional until the campaign's confirmation stage, and n = 200 / 1000 will
  show whether it is a finite-n effect (it should not be for an exact test). Reproduce with `run_calibration_study.R
  --response-type continuous --design DesignSeqOneByOneKK21 --n 50 --effect null --only InferenceContinKKGLMM`. Any
  calibration-row acceptance for these cells cites this TODO.

<a id="todo-18"></a>
<!-- pre-split-id: 1.0.6/23; 2026-11-25 -->

- [ ] TODO-18 (added 2026-11-15, owner; found by the first scheduled-mode run of the nightly argument-combination job,
  `.github/workflows/nightly.yml` `argument-combinations`): **finish the public argument-combination harness for every
  registry target, then make the ALL sweep gating.**
  - Why it went unseen: the pre-push hook's drift check (`R/package_tests/drift_artifacts.sh`) generates and executes
    only the curated smoke targets (`default_smoke_target_filter`, two targets; the committed results CSV has two
    rows). The harness's own unit tests (`R/package_tests/smoke_test_*public_argument*.R`) are run by nothing (no
    hook, workflow or bulk shard) and have rotted: `smoke_test_run_public_argument_combinations.R` fails on HEAD with
    "Runner did not preserve skipped_slow cases". Nothing had ever executed the other ~1,190 registry targets.
  - Fixed 2026-11-15 (smoke tests green and wired into pre-push via `R/package_tests/run_harness_smoke_tests.sh`, ~20 s,
    beside the comprehensive smoke tier; the two ~200 s comprehensive-suite smoke tests stay out):
    - Lazy-component stubs (`function(...)`, `install_lazy_inference_component`) hid the real methods from
      `public_api_inventory.R` and `extract_checkmate_argument_contracts.R`, so most inference methods had no
      argument contracts (about 3,900 contract rows restored; the curated smoke target had silently vanished).
    - `capture_call()` assigned the method's result with `<<-` inside `tryCatch`, so every case returned NULL and
      every output invariant checked NULL.
    - `assertBootstrapArgs()` (EDI's wrapper) was not recognized, so `B` and `min_number_usable_samples` had no domain;
      an assertion on an expression (`assertCount(as.integer(max_expansions))`) produced a bogus argument name.
    - The slow-path rule skipped every case of any resampling target below nightly, even `B = 5`; it is now per case.
    - Bare `<fixture>` placeholders were passed as literal strings; a string argument with a default got the
      fixture id; an all-NA result with EDI's explaining warning was an invariant failure.
    - `run_public_workflow_coverage.R`: likelihood families now use `InferenceContinOLS` (the simple mean difference
      lost them in the hierarchy split); `ObservationalDesign*` classes are covered.
  - Still open (one-class sweep of `InferenceAllSimpleAverageDiff`, 444 cases after the fixes: 64 errors, 164
    invariant failures): randomization and randomization-bootstrap CIs on incidence, unsupported by design, counted as
    errors instead of constraints (60); `pval_in_0_1` and `ci_ordered` failures on bootstrap p-values and CIs (about
    65; check whether NA without a warning, or a real EDI bug); `distribution_length_valid` on the
    `approximate_*_distribution` methods (30); `initialize` called without `des_obj` (4).
  - Found so far (one class, `InferenceAllSimpleAverageDiff`: 35 errors, 106 invariant failures, nearly all harness
    defects): invariants attached to methods they do not fit (`pval_in_0_1` on a jackknife p-value,
    `distribution_length_valid` on randomization p-values and distributions, `ci_length_2` on rand CIs that errored);
    string arguments filled with the fixture id (`testing_type = "fixed_bernoulli_continuous_smoke"`); `initialize`
    called without `des_obj`; randomization CIs on incidence, deliberately disabled since 2026-08-27, counted as
    unexpected errors instead of a constraint. Design classes with no fixture of their own (e.g.
    `DesignFixedFactorial`) used to abort the whole run; since 2026-11-15 they are recorded as `unsupported`.
  - Until done: the nightly gates on the curated targets and runs ALL report-only (warning plus step summary, failure
    CSVs in the artifact). Triage that artifact: fix harness defects in the generator, fixtures and invariants; file
    real EDI bugs as their own TODOs.
  - Done when: a scheduled ALL sweep has zero unexpected errors and invariant failures, design classes have fixtures
    (no `unsupported` from missing receivers), and the ALL step's `continue-on-error` is removed.

<a id="todo-19"></a>
<!-- pre-split-id: 1.0.6/24; 2026-11-25 -->

- [ ] TODO-19 (added 2026-11-15, agent, owner request to allowlist the remaining path-audit gaps with TODO citations;
  found by `R/package_tests/compare_path_audits.R` after the 2026-11-12 path-audit gap regeneration batch): **trace why 29
  nonestimability-defaults rows that HEAD's `path_audits_nonestimability_defaults.csv` still lists are gone from every
  canonical results CSV.** None of these (class, function_run) pairs is in any `comprehensive_tests_results_nc_1_*.csv`,
  nor in the pre-merge backups from 2026-11-03 on, and fresh runs of the current runner do not emit them (the 2026-11-12
  KKGEE / KKGLMM slices have no nonparametric-bootstrap rows), so the batch did not remove them. They are allowlisted as
  `row_removed` under this TODO (`todo24_v106_*` rows in `path_audits_regression_allowlist.csv`):
  - Bartlett LR p-value: `InferenceCountHurdlePoisson`, `InferenceOrdinalPropOddsRegr`, `InferenceOrdinalStereotypeLogitRegr`.
  - `InferenceOrdinalKKGEE` (bootstrap basic / BCa CIs and p-values, symmetric p-value, m-out-of-n, subsampling) and
    `InferenceOrdinalKKGLMM` (bootstrap CIs, m-out-of-n CI, `compute_rand_two_sided_pval` with and without delta = 0.5;
    the current runner emits only the `(custom)` rand p-value for it).
  - `InferenceOrdinalAdjCatLogitRegr` studentized bootstrap CI.
  - `compute_rand_confidence_interval` (and `(custom)`): `InferencePropKKQuantileRegrOneLik` (the release_v1_1_0.md TODO-25
    stopgap makes it fail loudly), `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr`,
    `InferenceSurvivalKKLWACoxPHOneLik`, `InferenceSurvivalKKStratCoxPHOneLik`.
  - For each, find the change that stopped the runner emitting it (registry exclusion, support gate, a NEWS 1.0.5 refusal)
    and either cite that change in the allowlist row or restore the method. A pair the package still advertises but the
    runner skips is a harness gap, not an accepted change.
  - Done when: every `todo24_v106_*` allowlist row cites its real cause (or is removed because the rows came back), and the
    defaults CSV is regenerated without those rows.

<a id="todo-20"></a>
<!-- pre-split-id: 1.0.6/25; 2026-11-25 -->

- [ ] TODO-20 (added 2026-11-15, agent; owner accepted these into `comprehensive_results_audit_baseline.csv` the same day):
  **investigate the 90 results-audit findings accepted after the 2026-11-12 path-audit gap regeneration batch.** Most are
  rows the batch made visible for the first time: `InferencePropGCompMeanDiff` (26 low_coverage, 17 pval_miscalibration;
  its proportion rows were regenerated on all seven designs), the AllSimple proportion rows moved out of
  `..._filtered_class-Inference_AllSimpleAverageDiff_..._AllSimpleWilcox.csv` into the main CSV (AverageDiff 6 + 4,
  Wilcox 5, MeanDiffPooledVar 2), and ordinal `InferenceOrdinalKKGLMM` (3 + 12) / `InferenceOrdinalKKGEE` (3). The rest
  (CountKKGLMM 2, IncidKKGCompRiskDiff 4, ContinKKRobustRegrOneLik 2, and one each for CountKKHurdlePoissonOneLik,
  IncidKKCondLogitOneLik, IncidKKGEE, OrdinalContRatioRegr) sit in files the batch did not touch; check whether they are
  borderline FDR calls moved by the larger number of tests corrected together. The same baseline rewrite dropped 31
  findings that no longer occur. Also look at KKGLMM on KK21stepwise: the 2026-11-12 rerun turned 169 diamonds results
  into NA (`numeric_instability`) with none going the other way.
  - Already tracked elsewhere: `InferenceContinKKRobustRegrOneLik` (`release_v1_1_0.md` TODO-172, Wald oversized at
    n = 50) and `InferenceIncidKKCondLogitOneLik` (`release_v1_1_0.md` TODO-177, gradient test oversized); fold their
    findings into those TODOs rather than re-investigating them here.
  - Done when: each class above has a cause (real miscalibration with its own TODO, or an accepted limitation in NEWS /
    roxygen), and the baseline rows are re-justified or removed.

<a id="todo-21"></a>
<!-- pre-split-id: 1.0.6/27; 2026-11-25 -->

- [ ] TODO-21 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
  pending): **`InferenceIncidKKCondLogitGLMMOneLik`: likelihood-ratio and score tests oversized at n = 50 on matched
  designs, and the LR test disagrees with its own CI.** Null, `~.`, n = 50: LR size 0.188 (BinaryMatch), 0.198 (KK21),
  0.180 (KK21stepwise), against a 0.10 cap, while LR CI coverage is 0.99-1.00; score size 0.286 (BinaryMatch).
  - Why it looks like a bug, not small-sample noise: a test that rejects 19% of the time paired with an interval that
    covers the null 99-100% of the time means the CI is not the inversion of the test (compare TODO-26). Check whether
    the LR p-value and the LR CI use the same null fit (`fit_null`) and the same reference distribution; the model was
    rewritten in v1.0.4 (conditional logit on discordant pairs plus a reservoir logit, TODO-187).
  - Done when: the cause is found; either fixed (the cells pass the calibration gate) or accepted with a reason and rows
    in `R/package_tests/calibration/calibration_study_accepted.csv` citing this TODO.

<a id="todo-22"></a>
<!-- pre-split-id: 1.0.6/28; 2026-11-25 -->

- [ ] TODO-22 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
  pending): **`InferenceIncidKKNewcombeRiskDiff`: Wald size 0.159, coverage 0.841 at n = 50 on
  `DesignSeqOneByOneKK21stepwise`** (`~.` and `~1` identical; cap 0.10 / 0.90). Not seen on the other KK designs at
  n = 50 so far.
  - Investigate first: the KK21stepwise match/reservoir split at n = 50 (few pairs or a tiny reservoir) and how the
    Newcombe hybrid interval combines the two parts; whether n = 200 passes.
  - Done when: fixed, or accepted as small-sample with a reason and calibration_study_accepted.csv rows citing this TODO.

<a id="todo-23"></a>
<!-- pre-split-id: 1.0.6/29; 2026-11-25 -->

- [ ] TODO-23 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
  pending): **`InferenceIncidLogBinomial`: score test oversized at n = 1000**, not only at n = 50 (`release_v1_1_0.md`
  TODO-178 and this file's TODO-9 cover n = 50). Null, `~.`, n = 1000: size 0.086-0.091 and coverage 0.911-0.916 on
  `DesignFixedBlocking` (prob_T 0.2), `DesignFixedRerandomization` (0.2), `DesignSeqOneByOneBernoulli` (0.5) and
  `DesignSeqOneByOneiBCRD` (0.2); level 0.0525 (rate rule, order unknown).
  - Why it matters: an excess that does not shrink by n = 1000 is not small-sample anti-conservatism. Suspects: the
    boundary-MLE active-set handling of the null fit (the 2026-11-07 cold-refit fix in `get_likelihood_test_spec()`
    `fit_null`; the profile score p-value is discontinuous where the binding set changes), or a score variance that
    ignores the boundary.
  - Done when: the cause is found and the n = 1000 cells pass, or the owner accepts them with a reason and rows citing
    this TODO.
  - Accepted rows completed 2026-11-21 (coordinator, owner request): 2 confirmed score size cells had no row after wave 24 of campaign 2026-11-15-e36c7710; added citing this TODO, level = the worse of the screening and confirmation values + 3 SE.

<a id="todo-24"></a>
<!-- pre-split-id: 1.0.6/31; 2026-11-25 -->

- [ ] TODO-24 (added 2026-11-16, agent, owner request; found by the algorithm-audit re-review of drift issue #8, row L,
  unverified): **Cluster-robust Cox SE: `compute_robust_vcov` still builds risk-set sums by forward subtraction.**
  - Where: `src/fast_coxph_regression.cpp` `compute_robust_vcov` (from ~L544). `r_exp` and `r_x_exp` start at the
    stratum's grand total and subtract each subject that leaves the risk set (~L575-585); `safe_r` clamps the remainder
    at 1e-100.
  - Why it is suspect: commit 96b34122 (2026-10-23) removed this exact pattern from the sibling
    `compute_cox_neg_ll_only` (now ~L105-140), because when one subject dominates `exp(eta - max)` the remainder after
    it leaves is rounding noise. There the line-search objective came out as -509 instead of +363.7 and Newton accepted
    a diverging step. `compute_cox_ll_grad_hess_fast` (~L151) already sums backwards. The same cancellation here would
    corrupt `dk/R_k` and `e_k`, so the Lin-Wei score residuals and the cluster-robust SE. Reached only when `cluster`
    is given (~L897). This is the open half of algorithm-audit catalog note I-6.
  - Investigate first (bounded): build a stratum where one subject dominates (a large-|eta| outlier that leaves the
    risk set early) and compare the cluster-robust SE with `survival::coxph(..., ties = "breslow", cluster = )` with
    and without the outlier. Stop condition: they agree to 1e-6 (the suspicion is wrong; close this with the evidence)
    or they disagree (the bug is real).
  - Fix if confirmed: accumulate `r_exp` / `r_x_exp` in reverse, as `compute_cox_ll_grad_hess_fast` does, and make the
    repro a regression test against `survival::coxph`.
  - Done when: the repro's cluster-robust SE matches `survival::coxph` to 1e-6 with a regression test, or the
    investigation shows no error; NEWS notes any change to cluster-robust Cox SEs.

<a id="todo-25"></a>
<!-- pre-split-id: 1.0.6/32; 2026-11-25 -->

- [ ] TODO-25 (added 2026-11-16, agent, owner request; found by the algorithm-audit re-review of drift issue #8, row E,
  unverified): **Randomization tie tolerance scales with the largest replicate, so one blown-up refit can inflate
  p-values.**
  - Where: `R/inference_all_abstract_rand.R` `rand_tie_tolerance` (~L34): `tol = EDI_TIE_REL_TOL * max(|t|,
    max|t0s|)` over the finite draws, used by `rand_tail_counts`, so by the stored-distribution p-value, the affine
    reuse branch and the sequential-MC band.
  - Why it is suspect: one finite but blown-up replicate (a near-separated or near-zero-denominator refit returning
    about 1e7 when typical |t| is about 1) sets the scale for every draw. With `EDI_TIE_REL_TOL = sqrt(eps)` that is a
    tie window of about 0.15, so draws near t count in both tails and p moves toward 1. The error is conservative, not
    anti-conservative, and has not been seen in practice.
  - Investigate first (bounded): count how often a class's randomization draws contain a replicate more than 1e3
    times the median |t0s|, across the calibration-study and comprehensive_tests result runs, and on any hit compare p
    with the current scale against p with a robust scale. Stop condition: no class produces such outliers (close with
    the evidence), or one does (fix).
  - Fix candidate: scale by a high quantile of |t0s| (e.g. the 0.99 quantile) together with |t| instead of the max.
    This keeps the unit invariance and the both-tails tie rule that the TODO-112 reproducibility fix and the
    InferenceOrdinalRidit n = 12 enumeration case need. Re-run those tests.
  - Done when: an outlier-replicate regression test shows p unchanged by a single 1e7 draw, and the TODO-112 and ridit
    tie tests still pass; or the investigation shows no class produces such draws and this is closed with the evidence.

<a id="todo-26"></a>
<!-- pre-split-id: 1.0.6/33; 2026-11-25 -->

- [ ] TODO-26 (added 2026-11-16, agent, owner request; carries out `new_feature_plans/v1_1_0/cross_platform_reproducibility.md`
  TODO-6): **Optimizer design draws change when the columns of X are reordered, because near-ties are broken by
  rounding and an unstable sort.**
  - Measured 2026-11-15 (1,000 seeded draws each, X vs `X[, perm]`, no code change). Continuous X: 0 draws changed
    in every design. Discrete X:
    - Greedy: 570-767 of 1,000 changed;
    - PairSwitching: 556;
    - GreedyDOptimal: 766;
    - Rerandomization: 0.
    The cause is best-vs-runner-up ties decided by rounding, plus a `std::sort` of bound keys that is not stable. Its
    order differs between libstdc++ and libc++, so the draws also differ across platforms.
  - Fix (C++): a `constexpr` copy of `EDI_TIE_REL_TOL` (`sqrt(eps)`, the R-side tie rule of cross-platform TODO-3).
    Candidates within `tol * max(1, |best|)` count as tied, and the lowest index wins. Use `std::stable_sort`, and
    accept a rerandomization criterion within `tol` of its threshold. Files:
    - `greedy_pairwise_swap_engine.h`
    - `design_fixed_greedy.cpp`
    - `optimal_design_search.cpp`
    - `design_optimal_annealing_search.cpp`
    - `rerandomization_helpers.cpp`
  - Needs a build (owner); agents compile only the touched files (CLAUDE.md).
  - This changes seed-pinned draws once. NEWS records it as a documented default change; bundle it with any other
    draw change in the same release.
  - Done when all of these pass:
    - a discrete-X digest case in `test-cross-platform-reproducibility-digests.R`;
    - an X-vs-`X[, perm]` invariance test (both fail today);
    - the plan's two constructed fixtures: two exactly tied swaps, and a rerandomization criterion 1 ulp from its
      threshold;
    - the same-binary and cross-platform digests, after the fixture is regenerated once.

<a id="todo-27"></a>
<!-- pre-split-id: 1.0.6/34; 2026-11-25 -->

- [ ] TODO-27 (added 2026-11-16, agent, owner request; found by `test-same-binary-determinism-registry.R`,
  cross-platform TODO-2): **`InferenceBaiAdjustedTKK14` / `KK21` give last-bit different results on the same binary,
  depending on memory alignment.**
  - Cause, verified: the estimate is `d_bar = mean_cpp(y_matched_diffs)`, and `mean_cpp` (`_helper_functions.cpp:65`)
    is `Eigen::Map<VectorXd>::mean()`. Eigen's vectorized reduction adds scalars one at a time until the pointer is
    packet-aligned, so the order of the sum depends on where R allocated the vector. The same 17 numbers gave two
    different means (in the last bit) across 300 fresh copies.
  - Affects every non-resampling output (estimate, summary, asymptotic CI and p-value): seen in 3 of 3 runs, on both
    the rerun and the 1-vs-4-core comparisons. Any `Eigen::Map` reduction (`sum`, `mean`, `dot`, `squaredNorm`) on
    memory R allocated has the same property; Bai is where the sweep saw it.
  - Fix: a fixed-order reduction (a plain scalar loop, or a pairwise sum with a fixed block size) for `mean_cpp`,
    `sum_cpp` and similar helpers. Then grep `src/` for `Map<...>` reductions that feed reported results.
    `scripts/check_thread_determinism.py` could flag them.
  - Needs a build (owner). NEWS: Bai results may move in the last bit.
  - Done when: the Bai entries are removed from `SAME_BINARY_KNOWN_FAILURES` and the same-binary test passes 3 runs
    in a row.

<a id="todo-28"></a>
<!-- pre-split-id: 1.0.6/36; 2026-11-25 -->

- [ ] TODO-28 (added 2026-11-16, agent, owner request; found by nightly run 43877847174): **Make KK21 and KK21stepwise
  assignments robust to last-bit floating-point differences across platforms.**
  - What was seen: with the digest test's old response (`y = x1`, an exact covariate), KK21 `w_md5` differed on every
    platform: `7f556fdd…` locally, `170b0370…` (Ubuntu), `621678d5…` (Ubuntu native), `67159e0a…` (both macOS legs),
    `065fd247…` (Windows). Within each leg it did not change with the thread count.
  - Cause of that case: the test input, not EDI. With y equal to a covariate the weight regressions fit perfectly, so
    the weights were ratios of rounding noise (learning l-66ee65e3, 2026-11-16). The test now uses a response with
    real residual variance, and the four fixture rows were rewritten.
  - What remains for this TODO: on real data KK21 still makes two floating-point decisions per step in `assign_wt()`
    (`R/EDI/R/design_seq_one_by_one_KK21.R`): the nearest reservoir subject under the weighted distance
    (`compute_weighted_sqd_distances_cpp()`), and whether it is below the λ-quantile of the bootstrapped distances
    (`compute_bootstrapped_weighted_sqd_distances_cpp()` plus `stats::quantile`). A near-tie still flips on last-bit
    differences (libm, BLAS, FMA contraction on native and Apple arm64 builds), so cross-platform identity is likely
    but not guaranteed.
  - 2026-11-16: nightly run 43896129262 (commit `c9f0a7d6`, new response) passed on all five legs and in the
    cross-leg comparison, so KK21 and KK21stepwise now match the fixture everywhere and need no exemption.
  - Investigate first (bounded): measure how often real
    decisions are near-ties (per-step margins between the smallest and second-smallest distance, and between the
    smallest distance and the cutoff) on the calibration datasets. Close this TODO as "not needed" if the chance of a
    flip per draw is negligible, and document that KK21 is reproducible across platforms except at exact near-ties.
  - Fix, if needed:
    1. Round the normalized weights to a fixed relative grid.
    2. Round each weighted distance and the cutoff to a grid, and compare the rounded values.
    3. Break exact ties by subject index (`which(... == min(...))[1]` already does this once values are equal).

    Rounding makes a split rare, not impossible: the chance per decision is about the cross-platform error divided by
    the grid step, so pick a step 1e4-1e6 times the measured error. The fix changes KK21 draws everywhere, so it needs
    a NEWS entry, regenerated fixture rows and the KK21 comprehensive and calibration slices (gate G4).
  - Done when: either closed after the investigation, or the fix lands and all five nightly legs agree with the
    fixture on both designs.

<a id="todo-29"></a>
<!-- pre-split-id: 1.0.6/37; 2026-11-25 -->

- [ ] TODO-29 (added 2026-11-17, agent, owner request; noticed by the 2026-11-17 algorithm-research triage of run
  43925959437 while reviewing the ridit findings, unverified): **Ridit DeLong SE returns 0, not NA, when an arm
  has a single subject.**
  - Where: `src/fast_ridit_analysis.cpp` `ridit_delong_se_from_scores` (~L117: `if (n_t < 2 || n_c < 2) return 0.0;`)
    and its R twin `R/inference_ordinal_ridit.R` `ridit_delong_se` (~L12: `return(0)`), which
    `InferenceOrdinalRidit` uses for `s_beta_hat_T` (~L284).
  - Why it is wrong: the DeLong structural-components variance is var(V10)/n_T + var(V01)/n_C; with one subject in an arm
    that arm's sample variance (denominator n - 1) is undefined, not zero. Returning 0 makes the Wald z infinite, so the
    asymptotic p-value is 0 and the CI has zero width whatever the data: wrong output, where `NA` (as already returned for
    an empty arm) is the defined answer.
  - Investigate first (bounded): confirm with a 1-vs-k ordinal dataset that `InferenceOrdinalRidit`'s asymptotic
    p-value and CI come out as 0 / a point. Stop condition: they do (fix), or a downstream guard already turns SE = 0
    into NA (close with the evidence).
  - Fix: return `NA_real_` in both functions for n_T < 2 or n_C < 2, so the existing NA path (as for an empty arm)
    applies; keep the two in step. Add a regression test for n_T = 1 and n_C = 1; NEWS: ridit asymptotic results become
    NA instead of p = 0 when an arm has one subject.
  - Done when: both functions return NA for a single-subject arm, the regression test passes, and the ridit
    randomization / bootstrap paths (which do not use this SE) are unchanged.

<a id="todo-30"></a>
<!-- pre-split-id: 1.0.6/38; 2026-11-25 -->

- [ ] TODO-30 (added 2026-11-17, agent, owner request; found by the 2026-11-17 algorithm-research triage of run
  43925959437 and checked against the code): **Remove the unreachable `robust_negbinreg` fallback in KK21stepwise count
  weights.**
  - Dead path: `DesignSeqOneByOneKK21stepwise` count weights never reach `compute_weights_KK21stepwise_count`
    (`R/design_seq_one_by_one_KK21_stepwise.R` ~L349): the dispatcher returns `kk21_stepwise_negbin_weights_cpp` when
    `!count_use_speedup` (~L283) and the continuous-weights path when `count_use_speedup` (~L268) first, and nothing
    else calls the method. Its body is the only caller of `robust_negbinreg` (`R/helper_robust_regression.R` ~L233,
    `MASS::glm.nb` with a column-drop retry).
  - Entry rule: this is a cleanup, not a wrong-output fix, so keep it to what changes nothing users see. Remove
    `compute_weights_KK21stepwise_count` and any test that calls it directly
    (`R/package_tests/testthat_bulk/test-kk21-stepwise-design-count-and-ordinal-weight-selection-reference.R`,
    `...-compute-weights-dispatcher-speedup-branches-reference.R`: keep their dispatcher assertions). Do **not** delete
    `robust_negbinreg` itself in v1.0.6: it is exported (`NAMESPACE`, `man/robust_negbinreg.Rd`), so deleting it is a
    user-facing API change. Instead mark it deprecated (`.Deprecated()` pointing at `fast_negbin_regression_with_var`,
    roxygen `@keywords internal` / deprecation note) and schedule its removal for v1.1.0.
  - Registries: regenerate the `R/package_tests` CSVs that list the removed method or the deprecation
    (`comprehensive_suite_*`, `public_api_inventory.csv`, `public_argument_*`, `coverage_gap_registry.csv`) and keep
    `test-robust-negbinreg-column-drop-retry-reference.R` passing (it tests the still-exported function).
  - Inventory: drop the `robust_negbinreg` row's dead-code verdict once removed (or mark it deprecated), per
    `R/package_metadata/audits/algorithm_inventory.csv` (check 4 flags a row whose symbol disappears).
  - Done when: `compute_weights_KK21stepwise_count` is gone, KK21stepwise count weights are unchanged (same seeds give
    bit-identical designs), `robust_negbinreg` still works with a deprecation warning, the registries and inventory are
    current, and NEWS records the deprecation.

<a id="todo-31"></a>
<!-- pre-split-id: 1.0.6/39; 2026-11-25 -->

- [ ] TODO-31 (added 2026-11-17, agent, owner request; found by the 2026-11-17 algorithm-research triage of run
  43925959437 and checked against the code): **Rename `invert_gradient_ci_uniroot`: it never calls `uniroot`.**
  - The private `InferenceExtCIInversion` method (`R/inference_ext_ci_inversion.R` ~L150) builds the gradient-test
    p-value function and inverts it with `pval_invert_ci_cpp` (C++ Wald-seeded exponential bracketing, then bisection,
    with the TODO-174 jump guard). The name says Brent / `uniroot`, which misled the algorithm inventory (its
    log-binomial row said Brent until 2026-11-17).
  - Rename to `invert_gradient_ci_bisection` (or another name the owner prefers). It is a private R6 method, so no
    user-facing change. Touches: the definition and its roxygen mention (`inference_ext_ci_inversion.R` ~L9, ~L150);
    callers `inference_continuous_KK_ols_one_lik.R` ~L139, `inference_incidence_log_binomial.R` ~L392,
    `inference_all_abstract_asymp_lik.R` ~L317; tests `R/EDI/tests/testthat/test-ext-ci-inversion.R` and
    `R/package_tests/testthat_bulk/test-asymp-lik-gradient-ci-inversion-guards-reference.R` (+ the comment in
    `...-compute-likelihood-test-two-sided-pval-unavailable-reason-reference.R`); regenerate
    `R/package_tests/testthat_bulk/fixtures/inference_component_registry_baseline.csv`, which lists method names.
    `grep -rn invert_gradient_ci_uniroot R/ python/` must come back empty except history.
  - Done when: the method is renamed everywhere, the registry baseline is regenerated, and all affected tests pass with
    results unchanged (a pure rename).

<a id="todo-32"></a>
<!-- pre-split-id: 1.0.6/40; 2026-11-25 -->

- [ ] TODO-32 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `clmm-ordinal-mixed-fit#43925959437.1`, see `audits/research_triage_drafts.md`): **KK CLMM/GLMM Bayesian-bootstrap
  replicates: check clmm's per-observation weight semantics**
  - Step 1 (bounded): for one KK ordinal dataset and one Bayesian-bootstrap weight draw, evaluate clmm's weighted
    -logLik and a direct sum_g w_g log integral (same theta, 20-node GH) and compare; also compare replicate
    beta_hat_T between the two objectives over 200 draws at n in {50, 200}.
  - Done when: either the objectives agree (close as not a bug) or they differ and the owner rules on the intended
    weighting; if a fix is ordered, add w_g to GLMMObjective/OrdinalGLMMObjective, switch the callers, and report
    replicate CI coverage plus per-replicate time vs clmm.

<a id="todo-33"></a>
<!-- pre-split-id: 1.0.6/41; 2026-11-25 -->

- [ ] TODO-33 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `monte-carlo-test-inversion-ci#43925959437.1`, see `audits/research_triage_drafts.md`): **Quantile IVWC Zhang CI:
  reservoir randomization p-value does not vanish as |delta| grows**
  - Check whether compute_rand_pval_reservoir tests H0: effect = delta. Unit test on a Bernoulli design (m = 0, all
    subjects in the reservoir) and on a KK fixture: evaluate p_R(delta) on a grid out to +/-20 SE and record whether
    it falls below alpha on both sides; then run 200 reps of the IVWC quantile rand CI at n = 100 and record coverage
    and the share of bounds hitting the bracket edge. Stop condition: if p_R stays above alpha on one side, fix by
    subtracting delta*w_obs before permuting (standard form) and re-run the coverage check; if not, close with the
    numbers. Only if the current form is kept, the one-shot affine breakpoint inversion
    (closed_form_ci_from_affine_null_draws, c_b = 1) becomes a v1.1.0 speed item.
  - Done when: the reservoir p-value is shown valid or fixed, with coverage within MC error of 95%.

<a id="todo-34"></a>
<!-- pre-split-id: 1.0.6/43; 2026-11-25 -->

- [ ] TODO-34 (added 2026-11-17, agent, owner request; from the dead code behind three rejected findings of the
  algorithm-research triage of run 43925959437, see the Rejected section of `audits/research_triage_drafts.md`; each
  "no caller" claim was checked against the code on 2026-11-17): **Remove three dead C++ code paths.**
  - `compute_coxph_rand_bootstrap_cpp` (`src/fast_coxph_regression.cpp` ~L1135; finding
    `resampling-refit-loop#43925959437.2`): no caller in R or C++, and only a reference test calls it
    (`R/package_tests/testthat_bulk/test-rand-bootstrap-statistic-kernels-coxph-jt-and-km-diff-reference.R` ~L28). It
    is exported (`NAMESPACE` L147) but documented `@keywords internal` (`man/compute_coxph_rand_bootstrap_cpp.Rd`).
    Delete it, its export, Rd page and test case, and add a NEWS line (an exported internal kernel is removed).
    - Owner decision pending: [DECISION-v1.0.6-TODO-43](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-43) (delete `compute_coxph_rand_bootstrap_cpp` outright, or deprecate it first?).
  - `newcombe_paired_ci_cpp` (`src/newcombe_speedups.cpp` ~L113; finding `risk-difference-ci#43925959437.2`): not
    exported, `@keywords internal`, no R caller (`InferenceIncidKKNewcombeRiskDiff` computes its matched part with its
    own Wald variance, `inference_incidence_KK_newcombe_ivwc_univ.R` ~L140-148). Only
    `test-proportion-interval-and-distance-matrix-kernels-reference.R` ~L45-47 calls it. Delete it, its Rd page, the
    `@seealso` link at ~L99 and those test lines. Its paired phi (~L127-128) is also the uncorrected definition the
    finding flags, so it must not be wired in as it stands.
  - `TruncatedNegBinCount::expected_hessian` (`src/fast_hurdle_negbin.cpp` ~L474; finding
    `zero-inflated-count-mle#43925959437.3`): nothing calls `.expected_hessian(` on a truncated-NB object (the Newton
    path uses `hessian_for_opt` → `hessian`, `_helper_functions_core.h` ~L1397). Delete the method and its
    `one_row` helper loop. Also check whether `has_expected_hessian` (`_helper_functions_core.h` ~L1390-1395) has any
    user left; it had none on 2026-11-17, so delete it too if that still holds.
  - Regenerate `RcppExports` (compileAttributes, at the end of the batch, not mid-way) and the `R/package_tests`
    registries that list the two kernels (`comprehensive_suite_*`, `coverage_gap_registry.csv`,
    `public_api_inventory.csv`, `public_argument_*`). Mark or drop the two rows in
    `R/package_metadata/audits/algorithm_inventory.csv` (~L621, ~L949) so the inventory check stays clean. Compile only
    the touched `.cpp` files (CLAUDE.md targeted-compile rule).
  - Done when: `grep -rn` finds none of the three symbols outside history, the hurdle-NB, Cox and Newcombe tests pass
    with unchanged results, and the registries, inventory and NEWS are current.

<a id="todo-35"></a>
<!-- pre-split-id: 1.0.6/52; 2026-11-25 -->

- [ ] TODO-35 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Ratio annealing can return an infeasible allocation.** The A-optimal "ratio" annealing
  kernel (`R/EDI/src/design_optimal_annealing_search.cpp:77`) scores a chain's random start as (w'Hw+1)/(n_T-w'Pw)
  without checking the denominator is positive, so an infeasible start with a negative objective beats every feasible
  allocation and `annealing_solve_A_ratio` returns it (its own `f_exact` scores it Inf). Score non-positive
  denominators as Inf and redraw infeasible starts. The failing test is
  `R/package_tests/testthat_bulk/test-annealing-ratio-infeasible-start-not-returned.R` (skipped, citing this TODO);
  done when the fix lands and the skip is removed.

<a id="todo-36"></a>
<!-- pre-split-id: 1.0.6/68; 2026-11-25 -->

- [ ] TODO-36 (added 2026-11-17, agent, owner request; from GitHub issue #25, the NEWS and version audit):
  **Version numbers disagree across files.** `CITATION.cff` and `codemeta.json` say 1.0.2; `python/CITATION.cff`,
  `python/README.md` and `python/README_PYPI.md` say 1.0.5; `R/EDI/DESCRIPTION` says 1.0.4. Bring the R-side
  files to the R version. Decide whether the Python package versions independently (it has its own `py-v*` tags
  and `.postN` rule); if so, make `.github/scripts/audits/news_version.py` compare the Python files with the
  latest `py-v*` tag instead of DESCRIPTION, with a unit test. The audit's other finding (no NEWS section newer
  than 1.0.4) is fixed: `NEWS.md` now has `# EDI (development version)`.

<a id="todo-37"></a>
<!-- pre-split-id: 1.0.6/74; 2026-11-25 -->

- [ ] TODO-37 (added 2026-11-17, agent, owner request; found by the cluster-and-factorial article agent): **The
  jackknife silently returns `c(NA, NA)` on `DesignFixedBlockedCluster`.**
  `compute_jackknife_wald_confidence_interval()` gives `NA, NA` with no warning for `unit = "auto"`,
  `"cluster"` and `"observation"`; only `unit = "block"` works. The cause is
  `jackknife_block_size_gt_one_unsupported()` (`R/inference_all_abstract_jackknife.R`, see its ~L164 comment).
  Meanwhile `edi_cluster_independence_warning` tells users to call `unit = "cluster"`, which on this design gives
  `NA` without a word. Repro: build the `blocked-cluster` design from
  `vignettes/articles/cluster-and-factorial-experiments.Rmd`, then
  `InferenceContinOLS$new(des_b)$compute_jackknife_wald_confidence_interval(unit = "cluster")`.
  Fix: make `unit = "cluster"` (and `"auto"`, which should resolve to it) work on blocked cluster designs by
  deleting one cluster at a time, or, if that is not valid here, error or warn with the unit that works
  instead of returning `NA` silently, and make the cluster-independence warning name a unit that works on the
  design at hand. Add a test for each unit on this design. Update the article's stated limitation when fixed.
  Update 2026-11-18 (v1.0.6-TODO-62 agent): not fixed (cluster-unit jackknife on blocked designs still unimplemented),
  but `mark_jackknife_nonestimable_if_block_unsupported()` now warns and names `unit = "block"`, and the BCa CI that
  hits the same refusal now warns too. `cluster-and-factorial-experiments.Rmd` text updated to "with a warning".
  - Also reported by the docs-scenario audit: ds-clusters-blocking-44358267779-f3 (2026-11-18, on
    `DesignFixedBlockedCluster` the advice runs in a circle: the cluster-independence warning recommends the
    jackknife with `unit = "cluster"`, which is NA and says to use `unit = "block"`, which is NA with 4 units
    and says to use "the model-based standard error", the SE the first warning called too narrow; the reason
    "blocks hold more than one subject" does not explain refusing leave-one-cluster-out). Filed here rather than as
    a new entry because this entry's fix (make the warning name a unit that works on the design) covers it; the
    "model-based SE" advice of the too-few-units message must also not be given on a cluster design.
  Investigated 2026-11-21 (agent): not changed. On a blocking
  design `jackknife_block_size_gt_one_unsupported()` (`inference_all_abstract_non_param_boot.R` ~L1332) refuses
  every unit except block / permuted_block / observation_within_block / pair / matched_set, so `unit = "cluster"`
  (and `"auto"`) on `DesignFixedBlockedCluster` is refused before any layout is built.
  - Owner decision pending: [DECISION-v1.0.6-TODO-74](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-74) (implement a stratified delete-one-cluster jackknife, change the advice, or both?).

<a id="todo-38"></a>
<!-- pre-split-id: 1.0.6/80; 2026-11-25 -->

- [ ] TODO-38 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
  **`InferenceRandCustom` with a nonzero `delta` tests an incoherent hypothesis for count and survival responses
  (probably proportion too).** The null template removes `delta` on the log scale (multiplicatively; rounded for
  counts), then the custom fast path (`R/inference_rand_custom.R` ~L186, `y + delta * wj`) adds it back
  additively, so the hypothesis at `delta != 0` is a hybrid. Count and proportion CIs are refused, but survival
  runs and returns an interval, e.g. (-1.71, 1.04) on this fixture:
  ```r
  set.seed(3); n=40; ds=DesignFixedBernoulli$new(n=n,response_type="survival",verbose=FALSE)
  ds$add_all_subjects_to_experiment(data.frame(x1=rnorm(n))); ds$assign_w_to_all_subjects()
  t=rexp(n); c=runif(n)<.25; ds$add_all_subject_responses(ys=ifelse(c,NA,t), y_Ls=ifelse(c,t,NA), y_Rs=ifelse(c,Inf,NA))
  seen=list(); f=function(y,w,dead){seen[[length(seen)+1]]<<-y; mean(y[w==1])-mean(y[w==0])}
  o=InferenceRandCustom$new(ds, custom_randomization_statistic_function=f); o$set_seed(1)
  o$compute_rand_two_sided_pval(r=20, delta=1, show_progress=FALSE)
  cbind(t, w=ds$get_w(), y=seen[[2]])[c(3,6),]  # 4.255 -> 4.255/e+1 = 2.565 ; 0.763 -> 0.763/e = 0.281
  o$compute_rand_confidence_interval(r=200, show_progress=FALSE)  # returns numbers
  ```
  For count, `response_type = "count"` with Poisson responses: a treated y = 5 becomes 3 (round(5/e) + 1) and a
  control 6 becomes 7. Fix: apply the shift on one scale consistently (the template's), or refuse nonzero `delta`
  for these types in `InferenceRandCustom`; add a test that the imputed null responses are on one scale.

<a id="todo-39"></a>
<!-- pre-split-id: 1.0.6/88; 2026-11-25 -->

- [ ] TODO-39 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent):
  **`min_eigenvalue_information` is always NaN in Cox regression, in R and Python.** In
  `R/EDI/src/fast_coxph_regression.cpp` the field is NaN-initialized (`CoxFitResult`, ~L261), copied (~L512) and
  returned (~L691-895), but nothing ever computes it. Its comment says it is "computed only when !converged"
  (optimizer_diagnostics_report.md TODO-1), so the non-converged fallback path was meant to fill it and doesn't.
  Fix: compute the minimum eigenvalue of the observed information at the returned beta on that path (or remove
  the field everywhere); add a test with a non-converging fit that checks it is finite. C++ change: needs a
  targeted compile to verify and an owner rebuild.

<a id="todo-40"></a>
<!-- pre-split-id: 1.0.6/89; 2026-11-25 -->

- [ ] TODO-40 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent): **The Python
  API's conventions are inconsistent.** Index arguments are mixed: `j_T` and the Clayton `pair_idx` are 0-based,
  while `fixed_idx`, `j` and `j_treat` are 1-based. Return-value keys differ between kernels: the GLM kernels
  return `b`/`XtWX`, Cox returns `coefficients`/`vcov`. `vignettes/articles/edi-from-python.Rmd` documents both
  as they are. Fix: decide one convention for the Python layer (0-based indices and one key set are the natural
  Python choice), translate at the binding layer so the C++ and R stay unchanged, deprecate the old forms with a
  warning for a release, and update the stub, README, CHANGELOG and the article. Breaking for Python users, so
  schedule with a minor version bump.

### Test dimensions the v1.0.6 vignettes exposed
The agents writing the new pkgdown articles found 22 bugs (v1.0.6-TODO-36 / v1.0.7-TODO-37 / v1.0.6-TODO-37 / v1.0.6-TODO-38 / v1.0.6-TODO-39 / v1.0.6-TODO-40 / v1.0.6-TODO-41 / v1.0.7-TODO-38 / v1.0.6-TODO-42 / v1.0.6-TODO-43 / v1.0.6-TODO-44 / v1.0.6-TODO-45 / v1.0.6-TODO-46 / v1.0.6-TODO-47 / v1.0.6-TODO-48 / v1.0.7-TODO-39 / v1.0.7-TODO-40 / v1.0.6-TODO-49 / v1.0.6-TODO-50 / v1.0.6-TODO-51 / v1.0.6-TODO-52 / v1.0.6-TODO-53) that the testthat suite, the
comprehensive suite, the argument-combination harness and the audit jobs had all missed. They were not wrong numbers
on canonical inputs. They were silent `NA`s, messages and docs that say something false, documented options that crash
(`n = NULL`, unequal blocks, interval censoring), and code outside the registry (`InferenceRandCustom`, the Python
kernels). checkmate did not catch them because the inputs are legal; the downstream code is what fails. These five
TODOs add the missing dimensions.

<a id="todo-41"></a>
<!-- pre-split-id: 1.0.6/97; 2026-11-25 -->

- [ ] TODO-41 (added 2026-11-18, agent, owner request): **Option-matrix (data-shape) tests.** Pairwise coverage, per
  design and inference family, over the non-default but documented settings the canonical fixtures never use:
  `n = NULL` (sequential designs, analyzed mid-stream and at the end), unequal block / cluster sizes, censoring type
  (none / right / interval), a missing response or covariate, and effect size (null vs. strong enough that 0 is
  outside the bootstrap distribution). Each cell must either succeed with finite output or fail with a clear,
  correct error; a silent `NA` is a failure (shares the rule with v1.0.6-TODO-54). Build on the existing
  argument-combination harness (`R/package_tests/generate_public_argument_combinations.R`,
  `public_argument_combination_fixtures.R`): its axes come from checkmate contracts, which only see argument types,
  so add data-shape axes to the fixtures rather than a new harness. Would have caught v1.0.6-TODO-36 / v1.0.7-TODO-37 / v1.0.6-TODO-38 / v1.0.6-TODO-39 / v1.0.6-TODO-40 / v1.0.6-TODO-49 / v1.0.6-TODO-50. Also cover `InferenceRandCustom` with R and C++ statistics returning one value, several values and `NA`
  (v1.0.6-TODO-42 / v1.0.6-TODO-43 / v1.0.6-TODO-44).
  Status 2026-11-18 (agent, uncommitted): implemented in the argument-combination harness. New entry point
  `R/package_tests/run_public_argument_data_shape_matrix.R` (`EDI_DATA_SHAPE_LOAD_ALL=1` runs against source);
  fixtures, generator (greedy pairwise covering array: 1,812 legal cells -> 177, 0 pairs uncovered), constraints,
  invariants and runner edited; results gain `output_outcome` (finite / warned_na / recorded_na / silent_na /
  clear_error / unclear_error / ...), `na_reason` and `known_todo`. Full run: 1,346 cases, ~5 min on 2 workers;
  491 fail, 431 map to open TODOs (-73: 42, -74: 13, -76: 98, -77: 238, -81: 4, -82: 4, -83: 25, -90: 5, -91: 2).
  ~60 new failures, not yet filed (repros in the agent report): KK14/KK21 crash when `design_formula` names a covariate
  still constant among enrolled subjects; BCa bootstrap and jackknife silent NA on `DesignFixedBlocking` with the
  strata column in `design_formula`; no separation warning in `InferenceIncidLogRegr`; C++ custom statistic refused
  on incidence even at `delta = 0`; all-NA custom statistic gives NA with no warning; KMDiff silent NA on right-censored
  data; several smaller NA-without-warning paths. Open: wire into `run_public_argument_combination_nightly.R`, commit a
  baseline `public_argument_combination_data_shape_*.csv`. TODO-78 is not exercised (responses added in order).
  Fix 2026-11-18 (coordinator): `run_public_argument_combinations.R` read an empty `receiver_args` back as logical NA,
  which `%||%` doesn't replace, so any filtered run with no `InferenceRandCustom` rows failed every case with
  "non-character argument". Now coerced to "" before `args_from_signature()`; one-cell matrix rerun clean (20 finite, 1
  warned_na) and the runner smoke test passes.

### Silent fallbacks and out-of-bounds reads in the C++ kernels
Found 2026-11-18 by the v1.0.6-TODO-59 agent while writing the Python input checks. The Python wrappers now block
all three, but direct callers of the R `_cpp` functions and of `edi_kernels._core` are still exposed. A fourth
report (`fast_robust_regression` silently running MM for any `method` other than `"M"`) was checked by the
coordinator and is not a bug: `fast_robust_regression.cpp` ~L78 throws on anything but `"M"`/`"MM"`, and the
2026-11-17 `_core` build raises for `method = "bogus"`.

<a id="todo-42"></a>
<!-- pre-split-id: 1.0.6/102; 2026-11-25 -->

- [ ] TODO-42 (added 2026-11-18, agent, owner request; minor): **An unknown `requested_stat` makes the survival
  stat kernels return `NA` silently.** `get_survival_stat_for_group_result_at_tau()` (`R/EDI/src/fast_survival_stats.cpp`
  ~L157-176) handles `"median"` and `"restricted_mean"` and otherwise falls through to `return NA_REAL;`, so
  `get_survival_stat_diff(..., requested_stat = "mean")` (Python) or a typo from R returns `NA` with no error. Fix:
  throw `std::invalid_argument` naming the accepted values on any other string; test from R (`_cpp`) and Python
  (`_core`). Needs a targeted compile and a wheel rebuild.

<a id="todo-43"></a>
<!-- pre-split-id: 1.0.6/103; 2026-11-25 -->

- [ ] TODO-43 (added 2026-11-18, agent, owner request; minor): **An unknown `family` in `gee_pairs_singletons`
  silently becomes gaussian.** Both `R/EDI/src/fast_gee.cpp` ~L322-324 (`gee_pairs_singletons_weighted_cpp`) and
  `python/cpp/bindings_incidence.cpp` ~L63-65 default to `GEEFamily::GAUSSIAN` and only switch on `"binomial"` /
  `"poisson"`, so `"Binomial"`, `"logit"` or a typo fits a linear model with no warning. Fix: accept exactly
  `"gaussian"`, `"binomial"`, `"poisson"` and throw otherwise, in both places (better: one shared parse helper in the
  core so the two can't drift); test both. Check the R callers pass one of the three. Needs a targeted compile and a
  wheel rebuild.

<a id="todo-44"></a>
<!-- pre-split-id: 1.0.6/104; 2026-11-25 -->

- [ ] TODO-44 (added 2026-11-18, agent, owner request): **`fast_lbeta` and the vector `fast_pchisq_upper` read past
  the end of a shorter second array.** In `python/cpp/bindings_fast_math.cpp` (~L41 `fast_pchisq_upper`, ~L96
  `fast_lbeta`) the loop runs over the first argument's size and indexes the second (`df[i]`, `b[i]`) without
  checking its length, so a shorter `df`/`b` is undefined behavior (garbage or a crash), not an error. Python-only
  bindings; the v1.0.6-TODO-59 wrappers now reject mismatched lengths, but `_core` is still exposed. Fix: check
  `a.size() == b.size()` (or broadcast a length-1 second argument, numpy-style) and throw otherwise; sweep the rest of
  `bindings_fast_math.cpp` for the same pattern; add a `_core` test. Needs a wheel rebuild.

### Argument-check gaps beyond assertNumeric

<a id="todo-45"></a>
<!-- pre-split-id: 1.0.6/105; 2026-11-25 -->

- [ ] TODO-45 (added 2026-11-18, agent, owner request; follow-up to v1.0.6-TODO-58): **472 (class, method) pairs in
  91 Inference classes have no argument check and return `NA` for an `NA` argument instead of erroring.**
  v1.0.6-TODO-58 could only tighten existing `assertNumeric` calls; these methods have none. A sweep calling every
  exported class's `compute_*confidence_interval` / `compute_*pval` with `alpha`, `delta` or `pval_epsilon = NA`
  (2,061 calls: 1,589 error, 472 return) is saved as `R/package_tests/sweep_na_argument_guards.R`. Worst offenders,
  all class-level overrides: `compute_wald_two_sided_pval` (86), `compute_asymp_confidence_interval` (43),
  `compute_asymp_two_sided_pval` (39), score / gradient / lik-ratio p-values incl. the Bartlett variants (35-42
  each), jackknife Wald (10 + 10), e.g. `inference_continuous_ols.R` ~L246. Also the G-computation risk-ratio
  subsampling / m-out-of-n paths (private `compute_rr_*`) and the dependent-censoring randomization stubs, which are
  the 10 pairs in the `na_arg_unguarded` allowlist of `R/EDI/tests/testthat/test-inference-args-reject-na.R` (now
  citing this TODO). Output is `NA`, not a wrong number, so this is a clarity fix. Fix: prefer one shared argument
  check at the dispatch layer the overrides go through (or a helper each override calls first) over 400+ per-method
  asserts; then empty `na_arg_unguarded` and extend that test to the override methods. Re-run the sweep to confirm 0
  returns.

### Follow-ups and other findings filed 2026-11-18
Bugs and leads found while fixing the TODOs above (each entry says which fix found it), plus v1.0.6-TODO-99 from the
docs-claims audit.

<a id="todo-46"></a>
<!-- pre-split-id: 1.0.6/139; 2026-11-25 -->

- [ ] TODO-46 (added 2026-11-18, agent; found by the v1.0.6-TODO-87 agent): **The C++ stratified Cox fit with zero
  events reports `converged = TRUE` at a nonzero coefficient.** Repro: KK14 survival design, seed 2, n = 40, every
  matched subject censored (`y_L = 5 + i/100, y_R = Inf`): `fast_stratified_coxph_regression_cpp(..., estimate_only =
  TRUE)` returns coef (-1.64, -0.10) with `converged = TRUE` (looks like a leftover start value), so
  `InferenceSurvivalKKStratCoxPHIVWC$compute_estimate(estimate_only = TRUE)` returns -1.642 while the SE path returns
  NA. Fix: in `R/EDI/src` (zero events -> not converged; needs the owner's targeted compile) and/or an R-side
  zero-events guard on the matched half.

<a id="todo-47"></a>
<!-- pre-split-id: 1.0.6/142; 2026-11-25 -->

- [ ] TODO-47 (added 2026-11-18, agent; found by the v1.0.6-TODO-85 agent): **Bootstrap subset copies made outside an
  active resampling operation inherit the parent's warm start**, so results depend on the fit path. E.g. the outer
  loop of `ci_calibrated_bootstrap()` runs after the inner bootstrap's `on.exit` cleared the operation, and the copy
  keeps `fit_warm_start`/`fit_warm_start_fisher`. Warm vs cold: BinomialIdentityRiskDiff on Blocking 0.0034 vs 0.128
  (warm matches `optim`, loglik -35.10; the cold start drops a covariate column and lands elsewhere), LogBinomial on
  Cluster 0.0037 vs -0.081, ZIP on Blocking -0.19 vs 0.16. Two parts: (1) a policy for warm starts in subset copies
  (and set the resampling operation in the calibrated outer loop); (2) the cold-start/column-reduction failure in
  the identity-binomial (and LogBinomial, ZIP) fits. The public bootstrap path is unaffected.
  Status 2026-11-18 (agent, uncommitted): (1) policy, R only, verified: `bootstrap_subset_inference()` copies made
  outside an operation now follow `edi_warm_start_dispatch_policy(class, "non_param_boot", n)` like `duplicate()`
  does inside one, and `ci_calibrated_bootstrap()`'s outer loop sets the operation (restoring the caller's). Subset
  copies never chain, so the likelihood_concave gate (2026-11-16 learning) has nothing to add. (2) Cold-start
  failures, identity and log binomial: the OLS smart start is infeasible (mu outside [0,1] / eta > 0), its loglik is
  -Inf, and the kernel returns converged = FALSE after 1 iteration, so the class silently drops covariates. Fix in
  `R/EDI/src/fast_log_binomial_regression.cpp` (`pull_infeasible_start_into_support()`, both weighted and unweighted
  impls): move the start 90% of the way to the first boundary toward the intercept-only point; feasible starts
  untouched. NEEDS THE OWNER'S TARGETED COMPILE (EDI_UNITY=0). Emulated: IdentityRiskDiff 0.003385 (optim agrees),
  LogBinomial 0.003662 (glm log-link same loglik); 400-dataset sweeps: 66 identity and 6 log old failures now
  converge. After the compile, update 6 bulk tests that encoded the old failure (listed in the agent report:
  binomial-identity null-fit golden CI 0.4780708 -> 0.4585320, four guard tests whose fixtures relied on the kernel
  failing, log-binomial KKT golden p-values drift <= 2.4e-6). Test
  `test-bootstrap-subset-warm-start-policy-and-binomial-infeasible-start.R` (2 tests skip until compiled). (3) ZIP not
  fixed: owner decision (zero-part separation; LBFGS candidate from pscl's start, separation detection, or leave to
  v1.1.0's multistart work). Optional: raise the binomial kernels' default maxit (100); ~12 of 400 log cases need ~125.

<a id="todo-48"></a>
<!-- pre-split-id: 1.0.6/148; 2026-11-25 -->

- [ ] TODO-48 (added 2026-11-18, agent; found by the v1.0.6-TODO-98 agent): **`InferenceSurvivalWeibullRegr` smoothed
  bootstrap randomization test on plain right-censored data returns NA** (30 of 31 null draws NA at delta = 0 and
  0.3): the smoothing noise is additive on raw time, so `y + noise` goes negative (min -0.40). Repro: n = 40 Bernoulli,
  `t = rexp(n)`, `dead = rbinom(n, 1, .7)`, `ys = ifelse(dead == 1, t, NA)`, `y_Ls = ifelse(dead == 1, NA, t)`,
  `y_Rs = ifelse(dead == 1, NA, Inf)`; `set.seed(9); InferenceSurvivalWeibullRegr$new(des)$compute_rand_bootstrap_two_sided_pval(B = 31, transform_responses = "log", type = "smoothed")`.
  Likely fix: log-scale noise for survival (also in the C++ kernels' noise_mat handling, so a targeted compile); check
  the other survival classes' smoothed BRT on right-censored data too.

### Divergent near-clones from the code-duplication audit
Found 2026-11-18 by the first local run of the code-duplication audit (`.github/scripts/audits/code_duplication.py`),
which ranks near-identical code whose copies differ in a few lines. Suspects only: none confirmed with a repro yet.

<a id="todo-49"></a>
<!-- pre-split-id: 1.0.6/155; 2026-11-25 -->

- [ ] TODO-49 (added 2026-11-18, owner request): **The Python bindings default `smart_cold_start` differently for
  logistic and probit**: `python/cpp/bindings_binary.cpp` ~L255-284 `fast_logistic_regression` defaults
  `smart_cold_start = false`, ~L335-364 `fast_probit_regression` defaults `true`. Check both against the R `_cpp`
  defaults and the R classes' usage, make them consistent (an rpy-parity question), and update `_core.pyi`, the
  v1.0.6-TODO-59 rules table if it mentions defaults, and `python/CHANGELOG.md`. Needs a wheel rebuild.

### Perfect predictors among the covariates
A covariate (or set of covariates) that predicts the response exactly, given treatment, is almost always leakage in
a randomized experiment (the outcome or a post-treatment variable in `X`). Decided (owner, 2026-11-18): "perfect
predictor" means zero residual variance (to a relative tolerance) in the fit of `y` on `w` plus the covariates, not
`y` on the covariates alone: with `y = x + tau w` exactly and `tau != 0`, `x` alone does not fit perfectly but
`w + x` does.

<a id="todo-50"></a>
<!-- pre-split-id: 1.0.6/159; 2026-11-25 -->

- [ ] TODO-50 (added 2026-11-18, owner request): **KK21 / KK21stepwise covariate weights for perfect predictors.**
  Today a covariate that predicts the responses so far exactly has residual variance 0, so the stepwise kernel
  (`kk21_weights.cpp`) skips it and gives it weight 0, and the non-stepwise kernel gives it eps: matching ignores the
  most useful covariate (seen with `y = x1` in the cross-platform digest test). Rule (owner, 2026-11-18): if only
  perfect predictors remain, split the weight uniformly across them; if there are other covariates, give the perfect
  ones 90% uniformly and spread the other 10% over the rest by their usual weights (make 90% a named, documented
  constant). Guard: call a covariate perfect only when its fit has enough residual degrees of freedom (e.g. >= 5);
  early responses fit `[1, w, x_j]` exactly by saturation, so below the guard use the equal-weights fallback
  (v1.0.6-TODO-74). Implementation (owner, 2026-11-18): in C++, where the stepwise kernel skips a zero-residual
  candidate today (`kk21_weights.cpp`, the `sigma2 <= 0` `continue`, ~L168-290): detect perfect predictors there and
  apply the uniform / 90-10 rule in the kernel (and the same handling in the non-stepwise kernel, which gives eps),
  rather than in R's `assign_wt`. Needs the owner's targeted compile (`EDI_UNITY=0`); the Python bindings compile the
  same kernel, so note it in `python/CHANGELOG.md`. Check seeded allocations are unchanged on data with no perfect
  predictor.

<a id="todo-51"></a>
<!-- pre-split-id: 1.0.6/164; 2026-11-25 -->

- [ ] TODO-51 (added 2026-11-18, agent; from v1.0.6-TODO-110): **The Weibull C++ kernel (`fast_weibull_regression_cpp`)
  fails to converge on unscaled covariates** (lbfgs and newton both hit `maxit = 100` on `survival::colon`; survreg
  needs 5 iterations). v1.0.6-TODO-110 added an R-side standardized retry after a failure. Cleaner: standardize
  columns inside the kernel (and/or raise maxit), mapping results back. Needs the owner's targeted compile and would
  change results for fits that converge today (within optimizer tolerance); check other C++ GLM kernels for the same
  conditioning problem. Also untested: the retry on interval-censored unscaled data.

<a id="todo-52"></a>
<!-- pre-split-id: 1.0.6/171; 2026-11-25 -->

- [ ] TODO-52 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-112): **The shared design-matrix rank check silently drops an innocent column at large covariate offsets.**
  `drop_linearly_dependent_cols` (`R/EDI/R/helper_model_matrix.R` ~L89-110, called from `create_design_matrix`,
  `R/EDI/R/inference_all_abstract.R` ~L1260) takes `min()` of `matrix_rank_cpp(M, tol = 1e-7)`
  (`R/EDI/src/fast_matrix_rank.cpp`, Eigen ColPivHouseholderQR threshold) and R's `qr()` rank. Once the smallest
  singular value ratio drops below about 1e-8 (age + 3e4 or more on the colon data), the Eigen rank is 10 against R's 11
  and the last pivot column (`surg`) is dropped with no warning: `InferenceContinOLS` gives 167.94 against `lm`'s 163.77
  (`fast_ols_cpp` itself is correct). Affects every class built on `create_design_matrix` (OLS, Lin, robust and
  quantile regression, proportion quantile, g-computation, ...). Center/scale before the rank test or use a
  scale-invariant tolerance, and warn whenever a column is dropped. Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.

<a id="todo-53"></a>
<!-- pre-split-id: 1.0.6/174; 2026-11-25 -->

- [ ] TODO-53 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-112): **The ordinal GLMM and CLMM classes return NA on ordinary data.** `InferenceOrdinalKKGLMM` returns NA on the
  raw colon data (y = quartiles of `time`) while the scaled fit gives -0.026; `InferenceOrdinalKKCLMM` returns NA at
  age x 1000 (its kernel `fast_ordinal_clmm_cpp` stops with treatment 0 and gradient norm 325). Kernels:
  `fast_ordinal_glmm_cpp` (K/C variants `converged = FALSE`, objective 793/786 vs 778.47 scaled) and
  `fast_ordinal_clmm_cpp`, both L-BFGS (see the L-BFGS stopping-rule TODO above). Find why the classes return NA
  rather than a fit or an informative non-estimable reason, fix the scaling, and compare with `ordinal::clmm`. Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.
  The probe ran these through KK designs with `private$X` overridden to keep the matching fixed across variants,
  because KK14 matching is itself scale-dependent.

### Code-duplication audit backlog

<a id="todo-54"></a>
<!-- pre-split-id: 1.0.6/193; 2026-11-25 -->

- [ ] TODO-54 (added 2026-11-19, owner request): **Merge the code-duplication audit's "refactor" clones into shared
  helpers.** The weekly code-duplication audit (`.github/workflows/audit-code-duplication.yml`; verdicts in
  `code-duplication/verdicts.json` on the `audit-notes` branch) judges near-clones as `intentional`, `refactor` or
  `divergence_bug`. Merge each `refactor` clone set into one shared helper. Rule: results must stay bit-identical,
  proved by before/after output (same seed, `identical()`) on every class or kernel that calls the merged code; any
  difference is a divergence bug, not a refactor, and gets its own TODO. Later weekly runs add their `refactor`
  verdicts to this list (append the decision id, family id and files). Citing a decision id here keeps the audit from
  re-listing it while this TODO is open; once a clone is merged its family disappears from the scan. Then tick the
  item. Items marked [C++] need a C++ change: agents write the patch and verify it with targeted compiles only where
  per-file objects exist (never a full build); otherwise the owner builds. First CI run 2026-11-18 (run 44358232233,
  `4ce2b712`): 32 judged (20 refactor, 3 divergence_bug, 9 intentional), 365 not yet judged.
  - `code-duplication-da35f9c8f` (`dup-1adb37d8ab20`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:534-614` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:622-701` (coordinate with v1.0.6-TODO-138, same function) -- DONE (agent, uncommitted; bit-identical): `fit_logistic_with_sandwich()` in both classes is now a thin wrapper over `gcomp_fit_logistic_with_sandwich()` (`helper_gcomp.R`); each class passes its clamp and post-fit (HC0 vs KK cluster) as arguments
  - `code-duplication-d6b10061f` (`dup-440466dd6dc0`): `R/EDI/R/design_abstract.R:405-498` vs `R/EDI/R/design_fixed_abstract.R:89-187` -- DONE (2026-11-25): fixed designs now inherit the shared `add_all_subject_responses()` body; the fixed-sample assertion still runs at the same point. Before/after `identical()` on 120 cases across four fixed/sequential designs and six response types, including ordinal levels, censoring, and errors.
  - `code-duplication-d4e38d855` (`dup-47b3c5848e6a`): `R/EDI/R/inference_survival_gehan_wilcox.R:220-329` vs `R/EDI/R/inference_survival_log_rank.R:199-317` -- DONE (agent, uncommitted)
  - `code-duplication-d23a10708` (`dup-4ca7ca9c9237`): `R/EDI/R/inference_ordinal_ordered_probit.R:100-186` vs `R/EDI/R/inference_ordinal_proportional_odds.R:134-217` -- DONE (agent, uncommitted)
  - `code-duplication-dcdb7e599` (`dup-51b70d0e54ad`): `R/EDI/R/inference_incidence_KK_cond_logit_glmm_abstract.R:367-427` vs `R/EDI/R/inference_proportion_KK_combined.R:164-224` -- DONE (agent, uncommitted)
  - `code-duplication-dfe6e2293` (`dup-53e9eeb69c5d`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:863-970` vs `R/EDI/R/inference_incidence_gcomp.R:16-151` -- DONE (agent, uncommitted; bit-identical): `incidence_kk_gcomp_generic_alias_overrides` is now `modifyList(incidence_gcomp_generic_alias_overrides, ...)` with only `compute_rand_two_sided_pval` re-pinned to `InferenceRandCI`
  - `code-duplication-de10bd6b1` (`dup-6af874290f8f`): `R/EDI/R/simulations_framework.R:3393-3441` vs `R/EDI/R/simulations_framework.R:3446-3494` -- DONE (agent, uncommitted)
  - `code-duplication-db001874c` (`dup-847f2d57f083`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:259-462` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:296-515` (coordinate with v1.0.6-TODO-138) -- DONE (agent, uncommitted; bit-identical): `default_null_value()` and the eleven `compute_rr_*()` privates live once in `gcomp_incid_rr_private_methods` (`helper_gcomp.R`), added to both classes' `private` lists
  - `code-duplication-d7e6ac7c3` (`dup-86f70c0a1fbe`): `R/EDI/R/inference_ordinal_cauchit.R:8-80` vs `R/EDI/R/inference_ordinal_ordered_probit.R:2-76` -- DONE (agent, uncommitted)
  - `code-duplication-d24d11c40` (`dup-8fdf724fbd87`): `R/EDI/R/simulations_framework.R:2110-2146` vs `R/EDI/R/simulations_framework.R:2157-2194` -- DONE (agent, uncommitted)
  - `code-duplication-d1b25b18a` (`dup-a82df7b209aa`): `R/EDI/R/inference_continuous_quantile_regr.R:50-261` vs `R/EDI/R/inference_proportion_quantile_regr.R:54-262` -- DONE (agent, uncommitted)
  - `code-duplication-d593b90a9` (`dup-e88368769f0c`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:400-427` vs `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:439-462` (coordinate with v1.0.6-TODO-138) -- DONE (agent, uncommitted; bit-identical): the four subsampling / m-out-of-n RR privates delegate to `gcomp_rr_resampling_two_sided_pval()` / `gcomp_rr_resampling_confidence_interval()` (`helper_gcomp.R`), parameterized by family
  - `code-duplication-dc93f6357` (`dup-fb4cd2ec3279`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:183-232` vs `R/EDI/R/inference_incidence_risk_diff.R:217-273` -- DONE (agent, uncommitted)
  - `code-duplication-dc1588975` (`dup-01e154dfbad0`) [C++]: `R/EDI/src/gcomp_speedups.cpp:175-276` vs `R/EDI/src/gcomp_speedups.cpp:384-490` -- DONE (agent, uncommitted; verified by kernel swap): `compute_gcomp_logistic_post_fit()` is now a template taking the meat as a functor; HC0 and cluster exports both call it
  - `code-duplication-d1a5a5abe` (`dup-5997356561a2`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:100-387` vs `R/EDI/src/fast_ordinal_cloglog_regression.cpp:108-386` -- DONE (agent, uncommitted; verified by kernel swap): one template `edi_ordinal::fixed_link_ordinal_internal<Model>()` (+ shared score/Hessian templates) in new header `R/EDI/src/ordinal_fixed_link_internal.h`, shared with probit; the cloglog validation-order drift is kept as an explicit policy flag (bit-identical), not fixed
  - `code-duplication-da540c45e` (`dup-7640a4a65caa`) [C++]: `R/EDI/src/fast_hurdle_poisson_glmm.cpp:32-72` vs `R/EDI/src/fast_poisson_glmm.cpp:36-82` -- PATCHED, needs owner build: soft_barrier trio moved into `_glmm_engine.h` (namespace glmm), both files use `glmm::gauss_hermite_rule`; hurdle half verified by kernel swap, `fast_poisson_glmm.cpp` cannot be sourceCpp'd standalone (needs `fast_poisson_regression_internal` from another TU)
  - `code-duplication-d4d992420` (`dup-b4945bb7ace9`) [C++]: `R/EDI/src/fast_gaussian_lmm.cpp:636-663` vs `R/EDI/src/fast_gaussian_lmm.cpp:683-710` -- DONE (agent, uncommitted; verified by kernel swap): static `build_lmm_data()` in the same file
  - `code-duplication-dd690bfdc` (`dup-b82ef667e0cb`) [C++]: `R/EDI/src/kk_compound_distr_parallel.cpp:25-112` vs `R/EDI/src/kk_compound_distr_parallel.cpp:126-211` -- DONE (agent, uncommitted; verified by kernel swap): static inline `compound_beta_hat()` in the same file
  - `code-duplication-d730a0bdd` (`dup-b84f50f38a71`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:177-387` vs `R/EDI/src/fast_ordinal_probit_regression.cpp:179-381` -- DONE (agent, uncommitted; verified by kernel swap): same shared template as the cauchit/cloglog item; probit's NaN guard on ssq_b_j and its missing K<2 early return are kept as explicit policy flags (bit-identical), not unified
  - `code-duplication-dee72312b` (`dup-be7f39dede8f`) [C++]: `R/EDI/src/fast_cpoisson_combined.cpp:87-124` vs `R/EDI/src/fast_cpoisson_combined.cpp:346-395` -- DONE (agent, uncommitted; verified by kernel swap): the Newton loop now calls `cpoisson_combined_score_info_cpp_impl()` (new `want_info` flag skips the info on the warm-start iteration)
  Added 2026-11-20 from run 44511244843 (`0231668c`, 2026-11-19): the run's 67 refactor verdicts not yet cited here
  (issue #61). Eight are flagged as possible divergence bugs and should be checked before merging.
  - `code-duplication-d0008dd06` (`dup-cf2587a46833`): `R/EDI/R/inference_count_hurdle.R:80-236` vs `R/EDI/R/inference_count_zero_inflated.R:97-268` -- DONE (2026-11-25): share the estimand-aware estimate, CI and p-value bodies for hurdle Poisson and ZIP, retaining both public APIs. Before/after `identical()` on 48 seeded cases covering estimates, every supported test type, marginal-to-conditional switching and warnings.
  - `code-duplication-d045a2ebb` (`dup-4b61e21df5c8`): `R/EDI/R/inference_ordinal_adj_cat_logit.R:44-64` vs `R/EDI/R/inference_ordinal_ordered_probit.R:251-271` -- DONE (2026-11-25): adjacent-category logit now uses the existing weighted ordinal surrogate helper with its own retained-column cache field. Before/after `identical()` on 54 cases across adjacent-category logit, ordered probit and cauchit, including weighted-fit cache fields and warnings.
  - `code-duplication-d0bee2d47` (`dup-40a8fc9297a9`) [C++]: `R/EDI/src/fast_gehan_wilcox.cpp:1-110` vs `R/EDI/src/fast_logrank.cpp:1-98` -- PATCHED (2026-11-25), verification pending: extracted a shared rank kernel in `survival_rank_test.h` with compile-time Peto–Prentice weighting. The installed-binary baseline is reproducible with `/tmp/edi-t54-survival-rank.R baseline`. Needs explicit permission for targeted log-rank and Gehan–Wilcoxon compilation and bit-identical checks.
  - `code-duplication-d0bf7a47c` (`dup-73dca8787a4c`): `R/EDI/R/inference_incidence_binomial_identity.R:628-668` vs `R/EDI/R/inference_proportion_beta.R:368-407` -- DONE: shared the degrees-of-freedom and marginal mean contrast code. Kept the distinct SE rules already required by v1.0.6-TODO-161. Verified with the joint 108-case matrix/estimand comparison.
  - `code-duplication-d0f32f7c4` (`dup-ae89fd0f2d50`): `R/EDI/R/inference_count_hurdle.R:581-605` vs `R/EDI/R/inference_proportion_zero_one_inflated_beta.R:470-494` -- DONE: one component matrix builder preserves formula handling and retained-column order. Joint 108-case before/after comparison with d0bf7a47c was identical.
  - `code-duplication-d114b8d9b` (`dup-89aa9d2539e0`) [C++]: `R/EDI/src/sample_mode.cpp:40-93` vs `R/EDI/src/sample_mode.cpp:94-143` -- PATCHED: integer and logical mode use one typed helper. Factor attributes, NA sentinels and the first-occurrence tie break are preserved in source. Native verification pending.
  - `code-duplication-d1564c4c6` (`dup-abd094cd763e`): `R/EDI/R/inference_ordinal_adj_cat_logit.R:5-66` vs `R/EDI/R/inference_ordinal_cloglog.R:52-109` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): cloglog `initialize` has no `harden` argument; adjacent-category logit has one -- DONE for the weighted-fit clone: shared the surrogate helper and kept each constructor’s documented hardening interface. Before/after identical on 36 weighted-fit cases.
  - `code-duplication-d1d0200db` (`dup-7df0544df4d2`): `R/EDI/R/inference_all_abstract_rand_ci.R:559-594` vs `R/EDI/R/inference_incidence_exact_zhang.R:73-106` -- DONE: shared the Zhang dispatch after the entry points’ distinct validations. 20 seeded before/after cases identical, including nonzero-delta refusals.
  - `code-duplication-d1f2bef91` (`dup-b02d9fd25b94`) [C++]: `R/EDI/src/fast_wilcox_hl.cpp:340-356` vs `R/EDI/src/fast_wilcox_hl.cpp:381-397` -- PATCHED: R Wilcoxon HL estimate delegates to the existing portable grouping and estimate implementation. Native verification pending.
  - `code-duplication-d2067ea8e` (`dup-4387d08426f4`): `R/EDI/R/inference_count_KK_cond_poisson.R:831-877` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1795-1841` -- DONE: one cache-preserving conservative p-value helper. The supported OneLik entry points were identical on 18 seeded cases including cache fields. The IVWC bodies use the same helper but those tests are not exposed by its contract.
  - `code-duplication-d22d0b43d` (`dup-bf70b2e02e63`): `R/EDI/R/inference_all_abstract_rand_bootstrap.R:1024-1072` vs `R/EDI/R/inference_all_abstract_rand_bootstrap.R:1159-1212` -- DONE: shared fresh-subset bootstrap preparation and kept scalar and studentized statistics separate. 12 before/after draws identical in both modes, including survival, smoothing and malformed draws.
  - `code-duplication-d27b99ba5` (`dup-9319feaf81b4`): `R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R:163-172` vs `R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R:175-184` -- DONE: shared the result handling after the two QR paths. Both focused matrix-helper test files passed with existing native kernels.
  - `code-duplication-d2c14e342` (`dup-117b65d30af8`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:1024-1064` vs `R/EDI/R/inference_incidence_KK_marginal_abstract.R:66-110` -- DONE: share covariate naming and design-versus-inference cluster cache logic. Both focused cache and covariate-name test files passed.
  - `code-duplication-d2c94a819` (`dup-018bf5078750`): `R/EDI/R/inference_ext_likelihood_test_memoization.R:192-206` vs `R/EDI/R/inference_ext_likelihood_test_memoization.R:207-221` -- DONE: shared exact and approximate Bartlett adjustment around their selected factor. Memoization regression file passed against the installed kernels.
  - `code-duplication-d2cb1831f` (`dup-32b5d56ba802`) [C++]: `R/EDI/src/fast_logistic_glmm.cpp:380-405` vs `R/EDI/src/fast_logistic_glmm.cpp:439-461` -- PATCHED: three logistic GLMM testing entry points use one checked data builder. Native verification pending.
  - `code-duplication-d32feefe2` (`dup-ee0fda8e5b7b`) [C++]: `R/EDI/src/kk21_weights.cpp:493-599` vs `R/EDI/src/kk21_weights.cpp:972-1076` -- do with v1.0.7-TODO-66, which must edit both Newton loops anyway -- PATCHED: shared the existing theta update. The sign correction stays in v1.0.7-TODO-66 and now has one update site. Native verification pending.
  - `code-duplication-d37d994cc` (`dup-0cae3844f40b`): `R/EDI/R/inference_ext_m_out_of_n_bootstrap.R:64-114` vs `R/EDI/R/inference_ext_prw_subsampling.R:59-109` -- v1.0.6-TODO-139 merged only the p-value and CI setups -- DONE: common draw/refit/debug path, preserving replacement, RNG restoration and deadlines. Eight seeded before/after comparisons per method identical. Timeout contract tests passed.
  - `code-duplication-d3f8794a9` (`dup-e19765984523`): `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:654-701` vs `R/EDI/R/inference_survival_KK_lwa_cox_one_lik_abstract.R:99-142` -- DONE: one CI and p-value dispatch, preserving each model’s Wald fit. Shared dispatch comparisons and the KK LWA Cox migration golden passed.
  - `code-duplication-d4062d188` (`dup-82f8a493e070`): `R/EDI/R/inference_continuous_KK_ols_one_lik.R:112-168` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:654-696` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): OLS one-lik `compute_asymp_confidence_interval` `testing_type` switch has no default, returns NULL -- DONE for the common p-value dispatch. The old missing CI default is already fixed by v1.0.6-TODO-208. OLS uses its own CI inversion routines, which remain separate.
  - `code-duplication-d41dc9935` (`dup-a34c2117a793`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:1-47` vs `R/EDI/src/fast_ordinal_probit_regression.cpp:1-47` -- PATCHED: shared the unweighted fixed-link adapter for ordinal cauchit and probit. Native verification pending.
  - `code-duplication-d48f0b621` (`dup-5b31a3214560`): `R/EDI/R/inference_all_abstract_rand.R:770-785` vs `R/EDI/R/inference_all_abstract_rand.R:790-805` -- DONE in 6166f9b5: the duplicate branches already call the central shift path. No additional source edit.
  - `code-duplication-d4c0c7f7a` (`dup-c48486186648`) [C++]: `R/EDI/src/fast_gaussian_lmm.cpp:565-583` vs `R/EDI/src/fast_gaussian_lmm.cpp:636-652` -- PATCHED: Gaussian LMM GLS, score and Fisher share checked input, group remapping and optional weights. Native verification pending.
  - `code-duplication-d4ceca027` (`dup-d1a3e796a967`): `R/EDI/R/inference_incidence_exact_binomial.R:30-93` vs `R/EDI/R/inference_indicidence_exact_fisher.R:21-77` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): exact-binomial design check runs always, exact-Fisher only under `should_run_asserts()` -- DONE for argument validation: shared argument normalization, response and censoring checks. The Fisher constructor already rejects unsupported designs unconditionally, so the differing internal gate does not expose a public bypass. Four exact-binomial/Fisher guard test files passed.
  - `code-duplication-d54d5e887` (`dup-c59fc462a58f`) [C++]: `R/EDI/src/fast_gehan_wilcox.cpp:85-168` vs `R/EDI/src/fast_logrank.cpp:76-156` -- PATCHED: same shared survival rank kernel as d0bee2d47. Native verification pending.
  - `code-duplication-d56b63aab` (`dup-d3f4295c00b8`): `R/EDI/R/inference_incidence_log_binomial.R:262-291` vs `R/EDI/R/inference_incidence_modified_poisson.R:188-199` -- DONE: shared the coefficient/convergence screening, preserving the model-specific probability and predictor checks. Modified Poisson predicate test passed.
  - `code-duplication-d5e5b1877` (`dup-5e66d7d6a084`): `R/EDI/R/inference_continuous_quantile_regr.R:230-352` vs `R/EDI/R/inference_proportion_quantile_regr.R:54-172` -- partly done: `code-duplication-d1b25b18a` merged the privates; the public skeleton is still copied -- DONE: shared the point-estimate and Wald method bodies after the previously merged private fits. Both quantile refit reference files passed.
  - `code-duplication-d63139ea4` (`dup-ccaf9d863fdd`): `R/EDI/R/design_fixed_greedy.R:159-178` vs `R/EDI/R/design_fixed_greedy_d_optimal.R:296-313` -- DONE: shared the treated-count validation and covariate-free draws. 24 seeded before/after draw matrices were identical across both designs and allocation settings.
  - `code-duplication-d6a11e876` (`dup-27d58e66d0f8`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:410-437` vs `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:449-472` -- re-detection of `code-duplication-d593b90a9` (DONE); should drop off the next scan -- DONE: alias of the already merged d593b90a9 family.
  - `code-duplication-d6c8eb597` (`dup-80086ada1649`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:901-1012` vs `R/EDI/R/inference_incidence_gcomp.R:16-155` -- re-detection of `code-duplication-dfe6e2293` (DONE); should drop off the next scan -- DONE: alias of the already merged dfe6e2293 family.
  - `code-duplication-d6e5fae59` (`dup-1d2fe9089c45`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:23-69` vs `R/EDI/R/inference_survival_strat_cox.R:239-271` -- DONE: reused the common likelihood switches, preserving the early Wald path, per-class input checks and original fallbacks. Dispatch/Bartlett routing reference passed.
  - `code-duplication-d708f1f8e` (`dup-b60c9f7798cf`): `R/EDI/R/inference_ordinal_ordered_probit.R:176-225` vs `R/EDI/R/inference_ordinal_stereotype_logit.R:1337-1386` -- DONE: share the ordinal leaf override declaration and preserve each class’s specific methods. Both generators loaded under the original registry contracts.
  - `code-duplication-d79480795` (`dup-bd767b3b1e90`): `R/EDI/R/inference_count_KK_cond_poisson.R:1007-1031` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1070-1093` -- DONE: share the weighted/unweighted matched contribution across likelihood, score and Hessian, keeping each reservoir formula and result type. Focused derivative reference passed.
  - `code-duplication-d7bfd0139` (`dup-8500784fdfc4`) [C++]: `R/EDI/src/fast_adjacent_category_logit.cpp:393-415` vs `R/EDI/src/fast_adjacent_category_logit.cpp:479-508` -- PATCHED: adjacent-category estimate and variance wrappers share outcome mapping and fitting. Native verification pending.
  - `code-duplication-d7d618301` (`dup-e8c35417c731`) [C++]: `R/EDI/src/fast_gee.cpp:307-351` vs `R/EDI/src/fast_gee.cpp:354-392` -- family parse overlaps v1.0.7-TODO-43; the group sort is not covered there -- PATCHED: R GEE wrappers share group sorting, grouped fit and output conversion. The existing family parsing behavior is unchanged pending v1.0.7-TODO-43. Native verification pending.
  - `code-duplication-d8450dc93` (`dup-38ee54497f68`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:386-512` vs `R/EDI/src/fast_probit_regression.cpp:438-612`
  - `code-duplication-d872ec3dd` (`dup-03478b9e1cf3`): `R/EDI/R/inference_count_hurdle.R:110-153` vs `R/EDI/R/inference_count_zero_inflated.R:358-393` -- DONE for the common count estimate: ZINB shares the conditional cache update with Hurdle/ZIP. Its conditional-only estimand contract stays in place. ZINB fit and reason reference passed.
  - `code-duplication-d89e34e9e` (`dup-348cb26a7183`) [C++]: `R/EDI/src/fast_continuation_ratio_regression.cpp:330-364` vs `R/EDI/src/fast_continuation_ratio_regression.cpp:391-433` -- PATCHED: continuation-ratio weighted and unweighted wrappers share result assembly while preserving the weighted-only field and field order. Native verification pending.
  - `code-duplication-d8aa199fe` (`dup-37d956f7bdfa`): `R/EDI/R/inference_count_KK_cond_poisson.R:760-812` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1750-1799` -- DONE: shared interval assembly and cache restoration. Six seeded before/after OneLik comparisons were identical.
  - `code-duplication-d8f5eab74` (`dup-b026b3ce7998`) [C++]: `R/EDI/src/fast_hurdle_poisson_glmm.cpp:595-663` vs `R/EDI/src/fast_hurdle_poisson_glmm.cpp:664-730` -- PATCHED: weighted and unweighted hurdle GLMM likelihood/score/Hessian wrappers share checked positive-count data construction. Native verification pending.
  - `code-duplication-d912e6d2b` (`dup-6eab11b3bbec`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:562-629` vs `R/EDI/src/fast_log_binomial_regression.cpp:804-868` -- PATCHED: weighted and unweighted constrained-binomial fits share result finalization and retain their separate working and effective weights. Native verification pending.
  - `code-duplication-d913fbe2c` (`dup-405743f65354`): `R/EDI/R/inference_ordinal_cauchit.R:137-206` vs `R/EDI/R/inference_ordinal_cloglog.R:287-358` -- DONE: shared full-fit orchestration, design matrix, and cache handling while preserving cloglog’s multistart and treatment sign. 54 seeded before/after comparisons across the cumulative-link classes passed.
  - `code-duplication-d9607a7c1` (`dup-9e2c0a9f8178`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:116-272` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:123-301` -- partly done: the RR methods are merged; the RD bootstrap, Bayesian-bootstrap and jackknife wrappers and `compute_treatment_estimate_during_randomization_inference` are still copied
  - `code-duplication-daf376ace` (`dup-1f433f508026`): `R/EDI/R/inference_incidence_modified_poisson.R:441-486` vs `R/EDI/R/inference_incidence_probit.R:376-421`
  - `code-duplication-db5595975` (`dup-3fa266e6a729`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:376-441` vs `R/EDI/src/fast_log_binomial_regression.cpp:618-689` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): unweighted log-binomial IRLS takes `warm_start_weights` but never reads it
  - `code-duplication-db621c738` (`dup-a61a70528060`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:460-581` vs `R/EDI/src/fast_log_binomial_regression.cpp:709-819`
  - `code-duplication-db68b8e31` (`dup-eb77e907ec3a`): `R/EDI/R/inference_count_zero_inflated.R:120-174` vs `R/EDI/R/inference_count_zero_inflated.R:341-387`
  - `code-duplication-dba30f68d` (`dup-21b487f963fb`): `R/EDI/R/inference_all_KK_quantile_regr_one_lik_abstract.R:85-134` vs `R/EDI/R/inference_continuous_KK_ols_one_lik.R:62-137`
  - `code-duplication-dbc57fae3` (`dup-0bea0bb60720`): `R/EDI/R/contracts_mixins.R:3318-3364` vs `R/EDI/R/design_component_registry.R:183-224`
  - `code-duplication-dbec652e7` (`dup-395b2ca21302`): `R/EDI/R/contracts_mixins.R:3206-3245` vs `R/EDI/R/design_component_registry.R:241-279`
  - `code-duplication-dc61886c3` (`dup-7bf412e7eaca`) [C++]: `R/EDI/src/fast_gee.cpp:322-336` vs `python/cpp/bindings_incidence.cpp:63-87` -- overlaps v1.0.7-TODO-43 (one shared GEE family parse)
  - `code-duplication-dc78d3281` (`dup-c8291bff0887`): `R/EDI/R/design_abstract.R:410-493` vs `R/EDI/R/design_fixed_abstract.R:89-174` -- DONE: same family and verification as `code-duplication-d6b10061f` above
  - `code-duplication-dc91e2221` (`dup-27fab88a45dc`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:12-69` vs `R/EDI/R/inference_incidence_log_binomial.R:101-157`
  - `code-duplication-dd45c2fa8` (`dup-11b5cd15f2d7`): `R/EDI/R/inference_ordinal_cauchit.R:134-206` vs `R/EDI/R/inference_ordinal_ordered_probit.R:57-129` -- DONE: same shared cumulative-link full-fit helpers and 54-case verification as d913fbe2c.
  - `code-duplication-dd9c46373` (`dup-18a4061ca2d7`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:434-511` vs `R/EDI/src/fast_poisson_regression.cpp:465-540` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): logistic `*_with_var_cpp` hard-codes maxit/tol and omits `mu`; the Poisson one exposes them
  - `code-duplication-ddad98657` (`dup-bf285fb350be`): `R/EDI/R/inference_all_abstract_rand.R:447-475` vs `R/EDI/R/inference_mixin_kk_gee_shared.R:173-200` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): GEE mixin rand p-value tail takes no `alternative` and skips the cached shift path
  - `code-duplication-dde2683cb` (`dup-d14222627cd9`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:145-183` vs `R/EDI/R/inference_continuous_KK_ols_one_lik.R:355-375` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): OLS one-lik likelihood-test p-value copy lacks the base guard and the TODO-116 failure recording
  - `code-duplication-ddf23fa3c` (`dup-1ba380677ef3`) [C++]: `R/EDI/src/fast_hurdle_negbin.cpp:125-138` vs `R/EDI/src/fast_hurdle_negbin.cpp:146-163`
  - `code-duplication-de22418b2` (`dup-a7f3006dc4c4`): `R/EDI/R/inference_incidence_binomial_identity.R:649-698` vs `R/EDI/R/inference_proportion_beta.R:391-438`
  - `code-duplication-de5860b48` (`dup-fd52b678b440`): `R/EDI/R/inference_incidence_binomial_identity.R:530-611` vs `R/EDI/R/inference_proportion_beta.R:153-237`
  - `code-duplication-de67677f3` (`dup-0803feaefbb3`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:392-466` vs `R/EDI/src/fast_poisson_regression.cpp:425-497`
  - `code-duplication-de783d17e` (`dup-1ece871a8c89`): `R/EDI/R/helper_matching.R:90-133` vs `R/EDI/R/helper_matching.R:146-169`
  - `code-duplication-de7e2b41e` (`dup-8f3ba82e1352`) [C++]: `R/EDI/src/robust_post_fit_speedups.cpp:296-339` vs `R/EDI/src/robust_post_fit_speedups.cpp:343-385`
  - `code-duplication-de9e00e72` (`dup-f24385724a76`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:271-472` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:300-517` -- re-detection of `code-duplication-db001874c` (DONE); should drop off the next scan
  - `code-duplication-ded18c68a` (`dup-6ca3192b49a2`) [C++]: `R/EDI/src/kk21_weights.cpp:1136-1181` vs `R/EDI/src/kk21_weights.cpp:1241-1287` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): KK21 stepwise: ordinal skips a throwing candidate, negbin sets its stat to 0
  - `code-duplication-df3056dcc` (`dup-3e3efd5c256a`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:415-485` vs `R/EDI/src/fast_log_binomial_regression.cpp:659-734`
  - `code-duplication-df815ccee` (`dup-953983a5b28c`): `R/EDI/R/inference_proportion_gcomp.R:724-732` vs `R/EDI/R/inference_proportion_gcomp.R:737-745`
  - `code-duplication-df90f4d8c` (`dup-281eb5818608`) [C++]: `R/EDI/src/fast_hurdle_poisson_glmm.cpp:595-651` vs `R/EDI/src/fast_hurdle_poisson_glmm.cpp:731-783`
  Added 2026-11-23 from run 45037204796 (`9186e6a5`, 2026-11-22): the run's 51 refactor verdicts (issue #61); its two
  divergence_bug verdicts are v1.0.7-TODO-170 and v1.0.7-TODO-171. Fourteen of the 51 are flagged as possible divergence
  bugs and should be checked before merging.
  - `code-duplication-d03e1cc0f` (`dup-62427e559c21`): `R/EDI/R/inference_continuous_lin.R:442-491` vs `R/EDI/R/inference_continuous_ols.R:476-522`
  - `code-duplication-d07d94f12` (`dup-781c3eba4ee9`): `R/EDI/R/inference_mixin_kk_passthrough.R:118-142` vs `R/EDI/R/inference_mixin_kk_passthrough.R:164-182` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): only the debug copy of the KK bootstrap replicate calls `compute_reservoir_and_match_statistics()`; the parallel and serial copies do not
  - `code-duplication-d1421e1c6` (`dup-ad22cc9e05e1`) [C++]: `R/EDI/src/rerandomization_helpers.cpp:57-69` vs `R/EDI/src/rerandomization_helpers.cpp:71-82`
  - `code-duplication-d14868fe3` (`dup-7dda27e13bf2`): `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:242-256` vs `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:272-286` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the ZAP CI wrappers do not expose `min_fraction_usable_samples`, the p-value wrappers do
  - `code-duplication-d15664876` (`dup-9428ea78e32b`): `R/EDI/R/inference_ordinal_cauchit.R:93-137` vs `R/EDI/R/inference_ordinal_ordered_probit.R:471-514` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): cauchit keeps its own `get_likelihood_test_spec`, using `get_fit_warm_start_for_length`/`_fisher` instead of `get_backend_warm_start_args`
  - `code-duplication-d20db4083` (`dup-ee84d31f8808`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:518-582` vs `R/EDI/src/fast_log_binomial_regression.cpp:801-872`
  - `code-duplication-d2164341b` (`dup-7ba91e25902b`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:604-812` vs `R/EDI/src/fast_log_binomial_regression.cpp:894-1082`
  - `code-duplication-d286f6d5e` (`dup-74fed185bef1`) [C++]: `R/EDI/src/fast_gaussian_lmm.cpp:403-420` vs `R/EDI/src/fast_gaussian_lmm.cpp:572-590`
  - `code-duplication-d2c92521f` (`dup-753e9d723d07`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:634-712` vs `R/EDI/src/fast_poisson_regression.cpp:496-571` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the logistic `with_var` wrapper hard-codes maxit/tol and omits `mu`; the Poisson one exposes them
  - `code-duplication-d2e855eb9` (`dup-cca84c6e9584`): `R/EDI/R/inference_count_KK_combined.R:310-339` vs `R/EDI/R/inference_ordinal_KK_combined.R:562-588` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the count KK combined class inflates the SE with `.inflate_kk_onelik_standard_error_with_jackknife()`, the ordinal one does not (owner to confirm)
  - `code-duplication-d33781699` (`dup-fd8056940861`): `R/EDI/R/inference_ordinal_cloglog.R:67-107` vs `R/EDI/R/inference_ordinal_ordered_probit.R:268-301`
  - `code-duplication-d3a37242b` (`dup-1bc99d4593d2`) [C++]: `R/EDI/src/kk21_weights.cpp:678-727` vs `R/EDI/src/kk21_weights.cpp:826-879`
  - `code-duplication-d3c08cd80` (`dup-16edf232d0b4`): `R/EDI/R/inference_continuous_lin.R:141-202` vs `R/EDI/R/inference_continuous_ols.R:154-216`
  - `code-duplication-d517ba962` (`dup-be0576598be3`): `R/EDI/R/inference_continuous_KK_robust_regr_ivwc.R:210-247` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:324-374` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the live loggamma copy keeps a redundant early return after v1.0.6-TODO-86 (harmless today)
  - `code-duplication-d5284f092` (`dup-30a5f25e14cd`): `R/EDI/R/inference_survival_strat_cox.R:676-689` vs `R/EDI/R/inference_survival_strat_cox.R:690-702`
  - `code-duplication-d5867314f` (`dup-78103d4c1c9b`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:360-541` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:411-598`
  - `code-duplication-d586bfb11` (`dup-21f4a388433b`): `R/EDI/R/inference_continuous_KK_ols_one_lik.R:112-147` vs `R/EDI/R/inference_survival_KK_lwa_cox_one_lik_abstract.R:99-121`
  - `code-duplication-d58a41a25` (`dup-c894cf6d2f0f`): `R/EDI/R/inference_all_average_diff.R:258-289` vs `R/EDI/R/inference_all_simple_wilcox.R:428-459`
  - `code-duplication-d590bf12e` (`dup-1bde054f4a23`): `R/EDI/R/inference_incidence_KK_cond_logit.R:867-899` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:344-373`
  - `code-duplication-d5df38ede` (`dup-23b0189638cd`): `R/EDI/R/inference_ordinal_cauchit.R:278-344` vs `R/EDI/R/inference_ordinal_proportional_odds.R:250-317` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): PropOdds overrides `get_complexity_tier` to "heavy"; Cauchit (and Cloglog) get the "light" default, so warm starts are beta-only
  - `code-duplication-d5e145b6f` (`dup-74e315bcd22f`) [C++]: `R/EDI/src/fast_coxph_regression.cpp:1174-1244` vs `R/EDI/src/fast_weibull_regression.cpp:835-915`
  - `code-duplication-d61b1e65d` (`dup-7a3c5e76926c`) [C++]: `R/EDI/src/fast_zero_augmented_poisson.cpp:156-168` vs `R/EDI/src/fast_zero_augmented_poisson.cpp:173-188`
  - `code-duplication-d6bd896f0` (`dup-5be91e2d8c8c`): `R/EDI/R/inference_ordinal_cauchit.R:139-208` vs `R/EDI/R/inference_ordinal_cloglog.R:290-361`
  - `code-duplication-d6dd4bb22` (`dup-4a855c5b3ea6`) [C++]: `R/EDI/src/fast_ordinal_clmm.cpp:120-153` vs `R/EDI/src/fast_poisson_glmm.cpp:415-444`
  - `code-duplication-d7d373540` (`dup-8cf00df7147b`): `R/EDI/R/inference_ordinal_cauchit.R:136-208` vs `R/EDI/R/inference_ordinal_ordered_probit.R:57-129` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): cauchit `generate_mod` uses a different warm-start accessor than probit (see d15664876)
  - `code-duplication-d7f65f74b` (`dup-34bf68e1fb0d`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:116-280` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:123-309`
  - `code-duplication-d84d305f3` (`dup-0ce60a39bcff`): `R/EDI/R/inference_continuous_KK_ols_one_lik.R:47-137` vs `R/EDI/R/inference_continuous_KK_robust_regr_one_lik.R:48-130`
  - `code-duplication-d853f318a` (`dup-2b57c27e00a4`): `R/EDI/R/inference_survival_strat_cox.R:649-691` vs `R/EDI/R/inference_survival_strat_cox.R:749-790` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the second prebuilt block labels the fit `stratified = FALSE, strata = NULL` while `strat_cox_data_cache` is still the stratified cache
  - `code-duplication-d9383b909` (`dup-2d175b52b684`): `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:336-374` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R:359-395` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the normal Weibull-frailty class guards `is.null(KKstats)`, the loggamma class does not
  - `code-duplication-d971fa2d0` (`dup-d8550248d5a0`) [C++]: `R/EDI/src/fast_survival_models_optim.cpp:650-659` vs `R/EDI/src/fast_survival_models_optim.cpp:661-670`
  - `code-duplication-d97d93309` (`dup-738f7c904be2`) [C++]: `R/EDI/src/fast_logistic_glmm.cpp:380-406` vs `R/EDI/src/fast_logistic_glmm.cpp:410-435`
  - `code-duplication-d9966a006` (`dup-faf67873824e`) [C++]: `R/EDI/src/_helper_functions_core.h:1859-1890` vs `R/EDI/src/_helper_functions_core.h:1891-1921`
  - `code-duplication-da55699c9` (`dup-a8d3d55a6f41`): `R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R:345-367` vs `R/EDI/R/inference_survival_KK_strat_cox.R:267-289` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the Weibull-frailty normal `shared()` keeps the early return on a cached `beta_hat_T` (L349) that v1.0.6-TODO-86 meant to remove
  - `code-duplication-dab3ec8ba` (`dup-568f77559618`): `R/EDI/R/inference_ext_m_out_of_n_bootstrap.R:62-112` vs `R/EDI/R/inference_ext_prw_subsampling.R:57-107`
  - `code-duplication-dac68e91d` (`dup-e4bb88b1e488`): `R/EDI/R/inference_class_registry.R:3149-3163` vs `R/EDI/R/inference_class_registry.R:3169-3186`
  - `code-duplication-db1a1593e` (`dup-4be9360a3eb0`): `R/EDI/R/inference_all_abstract_non_param_boot.R:2440-2456` vs `R/EDI/R/inference_all_abstract_non_param_boot.R:2567-2582`
  - `code-duplication-dc2e938b7` (`dup-c430dcafd64e`): `R/EDI/R/inference_ordinal_adj_cat_logit.R:8-72` vs `R/EDI/R/inference_ordinal_stereotype_logit.R:334-394` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the stereotype copy has the `stereotype_treatment_estimate_is_usable` guard and nonestimable-state handling, adjacent-category does not
  - `code-duplication-dc38e164b` (`dup-46f330704001`): `R/EDI/R/inference_ordinal_ordered_probit.R:30-84` vs `R/EDI/R/inference_ordinal_proportional_odds.R:80-139` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): PropOdds `generate_mod` catches errors but its `estimate_only` branch has no `is.null(res)` guard; probit has the guard but no `tryCatch`
  - `code-duplication-dc67f77bd` (`dup-795fe533cf12`): `R/EDI/R/inference_all_abstract_rand.R:482-516` vs `R/EDI/R/inference_mixin_kk_gee_shared.R:176-207` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the GEE mixin copy of the rand p-value tail omits the additive-delta-shift cache and affine-reuse branch (not reachable today)
  - `code-duplication-dc6d70509` (`dup-b5ece4323f44`): `R/EDI/R/design_abstract.R:417-518` vs `R/EDI/R/design_fixed_abstract.R:90-191`
  - `code-duplication-dd01a78e4` (`dup-1afcc07d3228`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:647-713` vs `R/EDI/src/fast_probit_regression.cpp:605-670`
  - `code-duplication-ddc856d68` (`dup-a646215cf3fb`) [C++]: `R/EDI/src/_helper_functions_core.h:283-317` vs `R/EDI/src/_helper_functions_core.h:334-360`
  - `code-duplication-ddddf4f3d` (`dup-d9617a3cac16`) [C++]: `R/EDI/src/fast_poisson_regression.cpp:459-528` vs `R/EDI/src/fast_probit_regression.cpp:514-623`
  - `code-duplication-de147f919` (`dup-02d020585d2c`): `R/EDI/R/inference_survival_coxph.R:358-378` vs `R/EDI/R/inference_survival_coxph.R:388-408`
  - `code-duplication-deb78240f` (`dup-5241962b7a38`): `R/EDI/R/inference_continuous_KK_ols_one_lik.R:397-479` vs `R/EDI/R/inference_continuous_KK_robust_regr_one_lik.R:366-429`
  - `code-duplication-deea3181d` (`dup-26172419b01d`): `R/EDI/R/inference_count_poisson.R:950-962` vs `R/EDI/R/inference_incidence_risk_diff.R:321-332`
  - `code-duplication-df6297951` (`dup-b204ea6df4fc`): `R/EDI/R/inference_incidence_KK_combined.R:82-117` vs `R/EDI/R/inference_proportion_KK_combined.R:66-106`
  - `code-duplication-df6be3096` (`dup-15964dd92780`): `R/EDI/R/inference_count_KK_cond_poisson.R:846-882` vs `R/EDI/R/inference_count_KK_cond_poisson.R:927-956`
  - `code-duplication-dfa2f5560` (`dup-6e848545caae`): `R/EDI/R/inference_count_poisson.R:309-344` vs `R/EDI/R/inference_count_poisson.R:436-470`
  - `code-duplication-dfe3bfba7` (`dup-f1e6c6e01c40`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:558-629` vs `R/EDI/src/fast_log_binomial_regression.cpp:843-919`
  - `code-duplication-dfee4a016` (`dup-4f9b19023d97`) [C++]: `R/EDI/src/fast_weibull_regression.cpp:447-535` vs `R/EDI/src/fast_weibull_regression.cpp:640-736`

<a id="todo-55"></a>
<!-- pre-split-id: 1.0.6/197; 2026-11-25 -->

- [ ] TODO-55 (added 2026-11-19, agent, owner request; found by the Phase 0 algorithm-research bench run 44048167550,
  finding `beta-regression-mle#43925959437.1`): **Every `betareg` call in EDI fails, so the beta fits silently fall
  back to OLS on logit(y).** All three call sites pass `betareg::betareg.control(start = list(phi = ...))`. In betareg
  3.2.6 `start` must be the full parameter vector (mean coefficients and precision), so a bare `phi` makes `optim`
  stop with "initial value in 'vmmin' is not finite" on any data; reproduced on a plain n = 200 dataset, where the
  same call without `start` fits normally. Affected:
  (1) `InferencePropZeroOneInflatedBeta$compute_estimate_with_bootstrap_weights()`
  (`inference_proportion_zero_one_inflated_beta.R` ~L286-296): the error is swallowed by `tryCatch`, so every
  Bayesian-bootstrap replicate of the ZOIB conditional estimate is the `lm.wfit` fallback on `logit(y_mid)`, a
  different estimator from the point estimate, with no warning;
  (2) and (3) the `betareg` fallbacks of the beta-regression wrappers in `helper_glm_fit.R` (~L1193 and ~L1284),
  reached when `fast_beta_regression_cpp` fails; they warn "betareg fallback failed" and use OLS on logit(y).
  Fix: drop `start`, or pass a complete start (mean coefficients from the logit-OLS fit, then `phi`); check the
  betareg version range EDI supports. Test: a small fixture with exact 0s/1s where the bootstrap replicate's
  estimate matches a direct weighted `betareg` fit, and a forced-fallback test for each `helper_glm_fit.R` path.
  Then rerun the Phase 0 bench spec for `beta-regression-mle#43925959437.1`, whose current side is this code (see
  v1.1.0-TODO-197).
  - Owner decision pending: [DECISION-v1.0.6-TODO-197](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-197) (related: delete or fix the unused ZOIB wrapper `.fit_zero_one_inflated_beta` in `helper_zoib.R`?).

<a id="todo-56"></a>
<!-- pre-split-id: 1.0.6/198; 2026-11-25 -->

- [ ] TODO-56 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65): **The published reference page
  of `InferenceIncidKKCondLogitGLMMOneLik` shows `Warning: number of rows of result is not a multiple of vector length
  (arg 1)`.** That is R's recycling warning from `cbind`/`rbind` or a matrix fill whose pieces have different lengths,
  raised somewhere in the example's fit (KK14, n = 10, two covariates, Bernoulli(0.5) responses; the clogit plus
  reservoir-logit path since v1.0.5-TODO-187). A silent recycling usually means a vector built with the wrong length
  (for example per-pair versus per-subject, or the reservoir rows dropped from one piece), so the estimate may be
  wrong, not just noisy. Find the call (`options(warn = 2)` on the example, then `traceback()`), fix the lengths, and
  add a test that the example's data fit without warnings and match a direct `survival::clogit` + `glm` fit. Check
  the IVWC sibling, which shares the abstract class.

<a id="todo-57"></a>
<!-- pre-split-id: 1.0.6/199; 2026-11-25 -->

- [ ] TODO-57 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65): **The `InferenceSuite`
  example's `\donttest` block takes about 138 s.** `R CMD check --as-cran` runs `\donttest` examples, and CRAN asks for
  examples that finish in seconds (the audit flags anything over 60 s). Shrink the example (fewer classes, smaller n,
  a subset of procedures, or no resampling), or move the full run to a vignette and keep a short call that shows the
  API. Done when the Rd audit reports the block under 60 s and the page still shows a meaningful result.

<a id="todo-58"></a>
<!-- pre-split-id: 1.0.6/200; 2026-11-25 -->

- [ ] TODO-58 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65, which runs each complete
  example block under up to 5 seeds): **Examples that warn under some seeds.** EDI's warnings are correct in each case;
  the examples use data too small or settings too coarse for what they show:
  (1) `InferenceIncidBinomialIdentityRiskDiff` (seeds 2, 5) and `InferenceIncidLogBinomial` (seed 2): boundary MLE
  warning; `InferenceIncidLogBinomial` (seeds 4, 5): covariate dropped and refit;
  (2) `InferenceIncidKKGEE` (seed 4): fitted probabilities 0 or 1, separation, sandwich SE degenerate;
  (3) `InferenceSurvivalKMDiff` (seeds 1, 5): control arm has no usable response or its median is not reached;
  (4) `SimulationFramework` (all 5 seeds, `InferenceContinOLS` BCa at B = 50) and `SimulationFrameworkReport`
  (seeds 2, 4, BCa at B = 201): BCa adjustment on the boundary, p-value NA;
  (5) `tune_EDI_for_this_machine` (all 5 seeds): `InferenceIncidLogRegr` drops covariate `z` and reports separation.
  Fix the example data, not the warnings: larger n or a less extreme design for (1)-(3); `type = "percentile"` or
  B >= 501 for (4) where the run time allows; for (5), less separable synthetic incidence data in the tuner's fixture
  (coordinate with the proportion-fixture item in this file, which edits the same generator family). Done when every
  example runs warning-free under the audit's 5 seeds, or a warning that is the point of the example is wrapped in
  `suppressWarnings(..., classes = ...)` with a comment saying why.

### Code bugs found by the source-comment-rot fixes, 2026-11-19
The source-comment-rot decisions fixed in 21e0679a rewrote these comments to describe the current code. The code
itself still needs a look.

<a id="todo-59"></a>
<!-- pre-split-id: 1.0.6/223; 2026-11-25 -->

- [ ] TODO-59 (added 2026-11-19, owner; audit decision `source-comment-rot-d06973fef`): **`fast_beta_regression`
  reports the observed Hessian as `fisher_information`.** `R/EDI/src/fast_beta_regression.cpp` sets `fit.XtWX =
  fun.hessian(params)`, the exact observed Hessian of the negative log-likelihood, and `vcov` inverts it, while
  `BetaRegression::expected_hessian()` is never called. The old docs said expected (working-weights) information.
  - Decide which is intended. If expected information: call `expected_hessian()` for `fisher_information` and keep
    the observed one under `observed_information`, as the other likelihood kernels do. If observed: delete the dead
    `expected_hessian()`.
  - Done when: the label matches the matrix, the unused code is gone, and a test compares both matrices with a
    numerical Hessian on a small fixture. Changing the matrix behind `vcov` changes SEs, so it needs a NEWS bullet.

<a id="todo-60"></a>
<!-- pre-split-id: 1.0.6/224; 2026-11-25 -->

- [ ] TODO-60 (added 2026-11-19, owner; `source-comment-rot-d77150edf`): **`fast_log_pnorm` is a constant for every
  x <= -8.** It returns -35.0496 there (and -6.661e-16 for x >= 8), with no asymptotic lower tail; log Phi(-10) is
  about -53.2. Censored-normal likelihoods that call it (`fast_survival_models_optim.cpp`) get no gradient far into
  the lower tail.
  - Replace the clamp with the standard asymptotic tail (log Phi(x) = log(phi(x)/|x|) + log of the Mills-ratio
    series, or `R::pnorm(x, 0, 1, 1, 1)` where R is available); this overlaps v1.1.0-TODO-50's erfcx item
    (`normal-cdf-quantile#43925959437.1`), so take whichever lands first.
  - Done when: |fast_log_pnorm(x) - pnorm(x, log.p = TRUE)| < 1e-12 relative on x in [-40, 8], with a test.

<a id="todo-61"></a>
<!-- pre-split-id: 1.0.6/225; 2026-11-25 -->

- [ ] TODO-61 (added 2026-11-19, owner; `source-comment-rot-d4adc9b4d`): **`prob_clip_eps` assert accepts 0.5.**
  `R/EDI/R/inference_incidence_gcomp_abstract.R` checks `assertNumber(prob_clip_eps, lower = 0, upper = 0.5)`
  (inclusive), while a separate `stop()` rejects `>= 0.5`. Behavior is correct; tighten the assert (e.g.
  `upper = 0.5 - .Machine$double.eps`) and drop the redundant `stop()`, keeping the error message.
  - Done when: one check, and a test that 0.5 errors.

<a id="todo-62"></a>
<!-- pre-split-id: 1.0.6/226; 2026-11-25 -->

- [ ] TODO-62 (added 2026-11-19, owner; `source-comment-rot-d6554d59d`): **`edi_tuning_verify_parallel_deviation`
  cannot detect a serial-vs-parallel difference.** `R/EDI/R/local_machine_tuning_correctness.R` fits the same class
  on two identical seeded experiments without setting or varying the core count, so both fits run under the same
  core setting.
  - Run one fit with one core and the other with `num_cores`, restoring the setting afterward, and compare.
  - Done when: a test plants a core-count-dependent estimator and the check flags it.

<a id="todo-63"></a>
<!-- pre-split-id: 1.0.6/227; 2026-11-25 -->

- [ ] TODO-63 (added 2026-11-19, owner; `source-comment-rot-de20927dd`): **`bootstrap_match_indices.cpp` cannot be
  compiled under `EDI_CORE_ONLY`.** It includes `<RcppEigen.h>` unconditionally and has no `#ifdef EDI_CORE_ONLY`
  guard, although `bootstrap_m_indices_internal` has no R dependency. Apply the guard pattern of
  `bootstrap_indices.cpp` (core function outside, Rcpp wrapper inside `#ifndef EDI_CORE_ONLY`).
  - Done when: the file compiles in a `cpp_tests/` target (per the CLAUDE.md whitelist) and the R build is unchanged.

<a id="todo-64"></a>
<!-- pre-split-id: 1.0.6/228; 2026-11-25 -->

- [ ] TODO-64 (added 2026-11-19, owner; `source-comment-rot-df6e615ac`): **The KK "Newcombe" risk-difference class
  uses Wald variances.** `shared_combined()` in `R/EDI/R/inference_incidence_KK_newcombe_ivwc_univ.R` computes
  Wald variances (var_m = (p10 + p01 - (p10 - p01)^2)/n, var_r = pRT(1-pRT)/nRT + pRC(1-pRC)/nRC) and no Wilson-score
  interval. The docs now say so, but the class name promises Newcombe.
  - Decide: implement the paired (Newcombe Method 10) and independent Newcombe intervals for the components, or
    rename the class (with a deprecated alias) to describe the Wald combination.
  - Done when: the name and the method agree; if the method changes, calibration coverage is rechecked and NEWS says
    so.

<a id="todo-65"></a>
<!-- pre-split-id: 1.0.6/229; 2026-11-25 -->

- [ ] TODO-65 (added 2026-11-19, owner; `source-comment-rot-d8959b19b`): **`InferencePropQuantileRegr`'s
  Bayesian-bootstrap refits use a different solver from its main fit.** The point and variance fits use
  `method = "fn"`, but the weighted `quantreg::rq()` in the shared `compute_quantile_estimate_with_bootstrap_weights`
  (`R/EDI/R/inference_continuous_quantile_regr.R`) uses the default `"br"`, so replicates and the original estimate
  come from different solvers.
  - Pass `private$quantile_full_method` (when not `NA`) to the weighted `rq()` call, so each class uses one solver.
  - Done when: the proportion class's weighted fit uses "fn", the continuous class is unchanged, and a test checks
    that unit weights reproduce the point estimate.

<a id="todo-66"></a>
<!-- pre-split-id: 1.0.6/236; 2026-11-25 -->

- [ ] TODO-66 (added 2026-11-19, owner; from the algorithm-research triage of run 44358397244, finding
  `kk21-covariate-weights#44358397244.1`, checked against the code; CHANGES RESULTS): **KK21 negative-binomial theta
  Newton step has the wrong sign.**
  - `univariate_negbin_tstat` (`R/EDI/src/kk21_weights.cpp:570`) and `multivariate_negbin_tstat` (`:1045`) update
    `theta_new = theta - score / info`, but `info` there is the negative second derivative of the log-likelihood (the
    same expression as `MASS::theta.ml`'s `i`), so the Newton step is `theta + score / info`. As written each step
    moves away from the MLE and theta walks to the [0.01, 1000] clamp. The R reference in
    `R/EDI/tests/testthat/test-kk21-negbin-fast-digamma.R:37` copies the wrong sign, so the test cannot catch it.
  - Fix: flip the sign at both sites and in the test reference; optionally step on log(theta) or add step-halving
    (as `fastglm_nb` does) so theta stays positive without the clamp.
  - Test: on a fixture, theta-hat matches `MASS::theta.ml(y, fitted(MASS::glm.nb(...)))` to tolerance and is not at a
    clamp, for both the univariate and multivariate paths.
  - Changes KK21 count-design weights (the `count_use_speedup = FALSE` negbin path): add a NEWS bullet and rerun the
    KK21 count weight comparisons and the affected package_tests CSVs.
  - Done when: both sites fixed, the theta.ml test passes, NEWS notes the changed weights.

### Bugs found by the algorithm-audit re-review of drift issue #55, 2026-11-20
The 2026-11-20 re-review of the 26 drifted algorithm-audit rows (`new_feature_plans/v1_0_5/algorithm_choice_audit.md`,
"Re-review log", entry "2026-11-20: drift issue #55") kept every row's decision but found these. Only TODO-271 and
TODO-273 were confirmed by reading the code; the rest are suspected and need a reproducer first.

<a id="todo-67"></a>
<!-- pre-split-id: 1.0.6/323; 2026-11-25 -->

- [ ] TODO-67 (added 2026-11-21, owner; found by the v1.0.6-TODO-173 agent): **`InferenceOrdinalKKGEE` separation
  rule can blank the SE of a fit that is not separated.** The same false alarm v1.0.6-TODO-173 fixed for the binary
  and proportion KK GEE: `R/EDI/R/inference_ordinal_KK_combined.R` (~L284-295) makes the sandwich SE, the asymptotic
  p-value and the CI NA whenever one subject's largest |cumulative logit| reaches qlogis(1 - 1e-8)
  (`edi_logistic_n_fitted_extreme`). One high-leverage point can get there without any separation.
  `edi_binary_data_separated()` (`helper_robust_sandwich.R`) does not carry over as is: for a cumulative-logit model
  existence of the MLE depends on all cumulative splits jointly (they share the slope), so the exact check needs a
  different formulation; find and cite the right condition before coding it.
  - First reproduce: a non-separated ordinal KK GEE fixture with one extreme covariate value whose SE comes back NA,
    confirmed non-separated independently (e.g. `MASS::polr` / `ordinal::clm` converging with bounded coefficients,
    or an LP check on each cumulative split).
  - Fix: keep the |eta| test as the cheap first screen and blank the SE only when an exact check for the
    cumulative-logit model confirms separation (as v1.0.6-TODO-173 did), or, if no practical exact check exists,
    document the rule as a heuristic and when it misfires.
  - Done when: the rule fires only on separated fits (or the docs say it is a heuristic), with a test on a separated
    and a non-separated high-leverage fixture; NEWS bullet if results change.

<a id="todo-68"></a>
<!-- pre-split-id: 1.0.6/324; 2026-11-25 -->

- [ ] TODO-68 (added 2026-11-21, owner; found by the v1.0.6-TODO-175 agent): **Rerandomization `mahal_dist` with a
  constant covariate column ranks draws differently on the two paths.** With `objective = "mahal_dist"` and a
  constant column kept by the design formula (e.g. `~ x1 + I(x2^0)`), the `prop_acceptable` path stays finite
  because `ensure_S_inv_current()` (`R/EDI/R/design_fixed_rerandomization.R` ~L277) adds a 1e-6 ridge to a singular
  covariance and ranks by that ridged Mahalanobis distance, while the cutoff path `rerandomization_search_cpp`
  (`R/EDI/src/rerandomization_helpers.cpp` ~L203-210) falls back to the abs objective when its Cholesky fails. So the
  same design and data are filtered by different criteria depending on whether `prop_acceptable` or
  `obj_val_cutoff` is set. (The abs_sum_diff paths were made consistent by v1.0.6-TODO-175.)
  - Decide the rule: drop zero-variance columns before forming the covariance (the Mahalanobis distance of the rest
    is then well defined and the constant column contributes nothing, matching the abs fix), or use the same ridge,
    or the same abs fallback, on both paths. Dropping the column is the cleanest; the `abs(det(S)) < 1e-10` test is
    also scale dependent and should go with it.
  - Done when: both paths score a draw identically on a fixture with a constant column (and on one with collinear
    columns), with a test; NEWS bullet under "Changes that alter results" if allocations change.

<a id="todo-69"></a>
<!-- pre-split-id: 1.0.6/424; 2026-11-25 -->

- [ ] TODO-69 (added 2026-11-23, owner; the optional item left open by v1.0.6-TODO-171): **Logistic IRLS runs the
  plain pass even when it is bound to fail.** `fast_logistic_regression_impl` (`R/EDI/src/fast_logistic_regression.cpp`
  ~L430-434) always runs `run_irls(false)` first and, when that pass does not converge, reruns the whole fit from the
  same start with step halving (`run_irls(true)`). The plain pass comes first so that every fit that converged before
  stays bit-identical (the comment at ~L216-225). But a fit that will not converge (separation, or a far warm start)
  pays for two full IRLS runs, up to 2 x maxit iterations, and that cost lands on every resampling draw of such data.
  Callers include the logistic classes, `fast_gee.cpp` and `fast_hurdle_negbin.cpp`.
  - Measure first: how often the plain pass fails in practice (separated KK / bootstrap / randomization draws, far warm
    starts) and what the second pass costs there; if it is rare or cheap, close this with the numbers.
  - Options: (a) stop the plain pass early as soon as a step raises the negative log-likelihood (the case the
    safeguarded pass exists for) and switch to the safeguarded pass from that point, or from the start, keeping
    converged fits that never saw a rise bit-identical; (b) skip the plain pass when a cheap screen predicts failure
    (e.g. the fitted |eta| separation screen on the warm start); (c) reuse the plain pass's best iterate as the
    safeguarded pass's start instead of restarting.
  - Done when: non-converging fits take about one pass of work, every fit that converges today returns bit-identical
    coefficients (sweep as in v1.0.6-TODO-171: far warm starts, separation, maxit 1..100), with a test and a timing
    note; NEWS bullet only if any result changes.

### custom-statistic docs-scenario findings, run 44358267779, 2026-11-20
The docs-scenario audit (`.github/workflows/audit-docs-scenarios.yml`, run 44358267779, 2026-11-18) followed the
custom-statistic article and help pages against installed 1.0.4. Findings and repros:
`git show origin/audit-notes:docs-scenarios/runs/2026-11-18-run44358267779/custom-statistic/findings.md`. The docs half of
f2 and f11 was fixed in f6d20e4d; f1, f5 and f6 (the null shift re-added on the wrong scale) are handled in a separate
entry.

<a id="todo-70"></a>
<!-- pre-split-id: 1.0.6/277; 2026-11-25 -->

- [ ] TODO-70 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f2): **`transform_responses`
  accepts any string.** `"bogus"`, `"sqrt"` and `"identity"` silently act as `"none"` (additive shift); `"logit"` is
  accepted on a continuous response with negative values. Fix: `match.arg(transform_responses, c("none", "log",
  "logit"))` in every public entry point that takes it (`compute_rand_two_sided_pval`, `compute_rand_confidence_interval`,
  `approximate_randomization_distribution_beta_hat_T`, in `inference_all_abstract_rand.R` /
  `inference_all_abstract_rand_ci.R`), and refuse `"log"`/`"logit"` when the response is outside the transform's domain
  (y <= 0 for log; y outside [0, 1] for logit) with a message naming the offending values. Test: each bad value errors;
  the three valid values still give today's results.

<a id="todo-71"></a>
<!-- pre-split-id: 1.0.6/278; 2026-11-25 -->

- [ ] TODO-71 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f3): **`r` from 1 to 9 gives a
  silent NA p-value.** The argument check is `r >= 1`, but at least `max(10, floor(r/10))` finite reference statistics
  are required, so r < 10 always returns NA (and `compute_rand_confidence_interval(r = 9)` returns `NA NA`) with no
  warning. The same silent NA happens whenever too many draws are non-finite. Fix: require `r >= 10` in the argument
  check, and warn (naming the number of finite draws and the minimum) whenever the NA comes from too few finite draws.
  Test: r = 9 errors; r = 200 with a statistic that is non-finite on most draws warns.

<a id="todo-72"></a>
<!-- pre-split-id: 1.0.6/279; 2026-11-25 -->

- [ ] TODO-72 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f4): **The RandCustom CI
  refusal for count and proportion responses names a CI the class does not have.** The message says "the randomization
  p-value and the randomization-bootstrap CI remain available", but `InferenceRandCustom` has no bootstrap CI (its help and
  `capabilities()` list only the randomization test and CI), and it ends with a pointer to an internal TODO that is not
  shipped. Fix: name only what this class can call (the randomization p-value) and point to the built-in classes for the
  response type; drop the internal pointer. Re-check this message after the null-shift scale fix (the separate f1/f5/f6
  entry), which may make the count and proportion randomization CI valid and the refusal unnecessary.

<a id="todo-73"></a>
<!-- pre-split-id: 1.0.6/280; 2026-11-25 -->

- [ ] TODO-73 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f8): **Multi-line C++ source
  gets "not a character".** `custom_randomization_statistic_cpp = c("double f(...,", "...) { return 1; }")` errors with
  "... not a character", although it is one. Fix: accept a character vector by `paste(x, collapse = "\n")`; keep the error
  for non-character input, and say what it actually got (`class(x)`, `length(x)`). Also document the two other accepted
  input kinds the message lists (a compiled Rcpp function from `Rcpp::cppFunction()`, an `RcppXPtrUtils::cppXPtr()`
  pointer), which the help does not mention. Test: the two-line source compiles and gives the same p-value as the
  one-string form.

<a id="todo-74"></a>
<!-- pre-split-id: 1.0.6/281; 2026-11-25 -->

- [ ] TODO-74 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f10): **An
  `InferenceCustomRand` subclass whose `fit()` calls a user helper returns NA p-values and CIs with 2 cores, silently.**
  With `set_num_cores(1)` (or the helper inlined into `fit()`) the same class gives 0.274, matching `InferenceRandCustom`.
  The helper is a global-environment function not exported to the worker processes, so every worker fit errors, the
  errors are swallowed and every draw is NA. Two fixes, both needed: (1) export the subclass's free variables (or the
  enclosing environment of `fit`) to the workers, or run user-defined `fit()` in the main session as `InferenceRandCustom`
  does for its R statistic; (2) never turn all-failed worker draws into a silent NA: warn with the first worker error
  message. Test: the repro from the finding gives the 1-core p-value with 2 cores; a `fit()` that always errors in workers
  warns with its message.

<a id="todo-75"></a>
<!-- pre-split-id: 1.0.6/282; 2026-11-25 -->

- [ ] TODO-75 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f11): **Malformed
  `permutations` input is accepted or fails with an unrelated error.** A bare n x r matrix gives "$ operator is invalid
  for atomic vectors"; `list(w_mat = P)` with fewer than r columns gives "subscript out of bounds"; draws of the wrong
  length (40 rows for n = 50) are recycled and return a p-value; 1/2-coded draws return NA. The format is now documented
  (f6d20e4d: a list with `w_mat`, an n x r 0/1 matrix, optional `m_mat`). Fix: validate in one helper used by every
  entry point that takes `permutations`: accept a bare matrix as `list(w_mat = .)`; require n rows, at least r columns,
  values in {0, 1}, no NA; and say which rule failed. Test: each malformed case errors with its rule; the valid list still
  gives 0.304 on the finding's repro.

### Docs-scenario findings, run 44358267779, 2026-11-20
The docs-scenario audit (`.github/workflows/audit-docs-scenarios.yml`, run 44358267779, 2026-11-18) also followed the
sequential-designs, fixed-designs, clusters-blocking, factorial, survival-censoring and missing-data articles and help
pages against installed 1.0.4. Findings and repros: `git show
origin/audit-notes:docs-scenarios/runs/2026-11-18-run44358267779/<area>/findings.md`; "Repro: <area> F<k>" below
names the block in that file. Findings an existing entry already covers are cited there instead: sequential-designs
f1/f2/f6 (v1.0.6-TODO-39 / v1.0.6-TODO-38 / v1.0.6-TODO-40), clusters-blocking f1 and factorial f6 (v1.0.6-TODO-36), clusters-blocking f3
(v1.0.7-TODO-37), survival-censoring f1 (v1.0.6-TODO-112, verified fixed on HEAD 2026-11-20) and fixed-designs f2
(cited at v1.0.6-TODO-168, which did not fix it, and filed as v1.0.6-TODO-181). Code locations marked "suspected"
were found by reading, not by running a fix.

<a id="todo-76"></a>
<!-- pre-split-id: 1.0.6/303; 2026-11-25 -->

- [ ] TODO-76 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f1,
  ds-factorial-44358267779-f2): **Randomization tests refuse every incidence analysis on `DesignFixedFactorial` and
  `DesignFixedBlocking` although `supports("randomization_test")` is TRUE, and the "Use Zhang method" advice then
  fails.** Every incidence class tried (RiskDiff, AverageDiff, LogRegr, GCompRiskDiff, CMH, NewcombeRiskDiff) stops with
  "Randomization tests are not supported for incidence. Use Zhang method." (`R/EDI/R/inference_all_abstract_rand.R`
  ~L427, guarded by `supports_rand_pval_for_incidence()` ~L326; same text in `inference_mixin_kk_gee_shared.R` ~L153),
  while `supports("randomization_test")` is TRUE. Following the advice, `type = "Zhang"` errors "Randomization type
  dispatch is only supported for incidence outcomes." on an incidence outcome
  (`assert_no_incidence_only_randomization_args()`, `R/EDI/R/inference_all_abstract_rand_ci.R` ~L463-466, which
  fires whenever `type` is non-NULL on this path), and GCompRiskDiff / NewcombeRiskDiff give "unused argument (type =
  "Zhang")"; `InferenceIncidExactZhang` is not applicable to these designs. The factorial article says these designs
  work with every inference class and uses `compute_rand_two_sided_pval()` on the blocked main-effect design. Fix: (1)
  make `supports("randomization_test")` return what `supports_rand_pval_for_incidence()` returns, so capabilities and
  the suite agree; (2) say in the refusal why the plain permutation test is not offered for incidence on this design
  and name what works here (e.g. `InferenceIncidExactFisher` / CMH), mentioning Zhang only when the design is
  Zhang-eligible; (3) fix the `type` guard message so it names the real reason (Zhang/Fisher dispatch needs a
  Zhang-eligible design) and list the valid `type` values in the roxygen; (4) state the incidence restriction in the
  factorial article and `?DesignFixedFactorial`. Test: on both
  designs `supports()` and the method agree; the refusal names a class that runs; `type = "Zhang"` on a non-eligible
  design gives the new message. Repro: factorial F1, F2.
  Investigated 2026-11-21 (agent): not changed; the ruling decides the shape of every part.
  - Owner decision pending: [DECISION-v1.0.6-TODO-303](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-303) (allow the plain randomization test at delta = 0 for incidence on these designs?).
  - Also reported by the docs-scenario audit: ds-incidence-44883784401-f7 (2026-11-21, the same refusal and failing
    `type = "Zhang"` advice on `DesignFixediBCRD`). Extends the scope: run the test on iBCRD too, and correct the
    "does not refuse outright" sentence in the @description of `InferenceIncidWald` (`inference_incid_wald.R:51-56`),
    `InferenceIncidRiskDiff` (`inference_incidence_risk_diff.R:55-60`), `inference_all_average_diff.R:445-447`,
    `inference_incidence_extended_robins.R:56-58` and `inference_incidence_cmh.R:67`. The guard lines above have
    drifted: `inference_all_abstract_rand.R:326-347,427`, `inference_all_abstract_rand_ci.R:476-479`.

<a id="todo-77"></a>
<!-- pre-split-id: 1.0.6/304; 2026-11-25 -->

- [ ] TODO-77 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f3): **On the 2 x 2 main-effect
  design (`DesignFixedBlocking` with 2 blocks) the default BCa bootstrap CI and p-value and every jackknife unit return
  NA, and the warnings recommend a randomization test that errors for incidence.** BCa gives NA with
  "bootstrap_bca_jackknife_too_few_deletion_units" (only 2 blocks); its message also says "the bootstrap itself
  resamples only those units", which contradicts the help (the default bootstrap resamples subjects within blocks; the
  percentile CI is a sensible 0.151 to 0.370). The jackknife gives NA for `"auto"`/`"block"` (2 units) and for
  `"observation"` ("not supported on this blocking design because its blocks hold more than one subject; use unit =
  "block""), so it sends the user to the unit that just failed. Both messages say to use a randomization test, which
  errors for incidence (v1.0.7-TODO-76). Fix: (1) on a design that resamples within blocks, compute the BCa
  acceleration from a leave-one-subject-out (within-block) jackknife instead of leave-one-block-out, or fall back to
  the percentile/BC interval with a warning that says so; (2) correct the "resamples only those units" sentence; (3)
  make the jackknife and BCa advice name a procedure that runs for the response type at hand (shared with
  v1.0.7-TODO-37's message fix); (4) the help's "the jackknife (resample within blocks)" must match what happens.
  Test: the finding's repro gives a finite default bootstrap CI or a warning whose advice runs; no jackknife message
  points to a unit that also fails. Repro: factorial F3.
  Investigated 2026-11-21 (agent): not changed. Part (2) is in `edi_warn_bca_jackknife_unavailable()` (`inference_all_abstract_non_param_boot.R`
  ~L2664: "the bootstrap itself resamples only those units"), and parts (2)-(3) depend on the advice chosen for
  v1.0.7-TODO-37 / v1.0.7-TODO-76 (which procedures run for incidence on these designs), so they are best done together after
  those rulings.
  - Owner decision pending: [DECISION-v1.0.6-TODO-304](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-304) (part (1): within-block jackknife BCa acceleration, or percentile / BC fallback?).

<a id="todo-78"></a>
<!-- pre-split-id: 1.0.6/308; 2026-11-25 -->

- [ ] TODO-78 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f3): **An exact event
  time of 0 is accepted, and `InferenceSurvivalWeibullRegr` then returns NA estimate, CI and p-value with no
  warning.** `add_all_subject_responses(ys = y)` with `y[1] = 0` passes `assert_y()` (`R/EDI/R/design_abstract.R`
  ~L1148-1151, `assertNumeric(y, lower = 0, ...)` for survival); Weibull then gives NA, only `is_nonestimable()` /
  reason `"model_fit_unavailable"` hint at it, and the reason does not mention the zero time. Cox, log-rank and RMST give
  finite results. Fix: as the owner decides (decision below). Test: the
  finding's repro errors at entry with the left-censoring advice (or warns with the new reason); positive times unchanged. Repro:
  survival-censoring F3.
  Investigated 2026-11-21 (agent): not changed.
  - Owner decision pending: [DECISION-v1.0.6-TODO-308](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-308) (refuse an exact time of 0 at data entry, or only in the parametric classes?).

<a id="todo-79"></a>
<!-- pre-split-id: 1.0.6/310; 2026-11-25 -->

- [ ] TODO-79 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f5): **On
  interval-censored data `InferenceSurvivalCoxPHRegr` lists score / gradient / lik_ratio as supported but gives NA, a
  relabelled Wald interval, or an error.** `get_supported_testing_types()` returns all four types;
  `compute_lik_ratio_two_sided_pval()` returns NA with a warning naming an internal ("get_likelihood_test_spec()
  returned NULL") and advising `testing_type = "wald"`, which the constructor does not take (the setter is
  `set_testing_type()`); `compute_score_confidence_interval()` returns the Wald interval with a warning;
  `set_testing_type("score")` is accepted and only the next `compute_asymp_two_sided_pval()` errors. The help says
  score/gradient/LR/Bartlett "raise an informative error for such data". Fix (`R/EDI/R/inference_survival_coxph.R`,
  `get_supported_testing_types_impl` and the `icenReg` dispatch ~L360-395): on left-/interval-censored data return
  only `"wald"`, make `set_testing_type()` refuse the others at once, and make the score/gradient/LR methods raise the
  documented error naming `set_testing_type()` (no relabelled Wald interval). Test: on the finding's data each of these
  calls gives the documented error; right-censored data keeps all four types. Repro: survival-censoring F5.

<a id="todo-80"></a>
<!-- pre-split-id: 1.0.6/311; 2026-11-25 -->

- [ ] TODO-80 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f6): **User-facing
  messages point to repo-internal documents that are not shipped.** Audit: `InferenceSurvivalStratCoxPHRegr$new()` and
  `InferenceSurvivalDepCensTransformRegr$new()` on interval-censored data say "see interval_censored_survival_response.md";
  `InferenceSurvivalCoxPHRegr$compute_rand_confidence_interval()` points to
  `R/package_metadata/new_feature_plans/v1_0_5/randomization_ci_construction_audit.md`; neither file is installed.
  `grep -nE '"[^"]*(package_metadata|[A-Za-z_]+\.md|TODO-[0-9]+)[^"]*"'` over `R/EDI/R/*.R` and `R/EDI/src/*` (comment
  lines excluded) finds, 2026-11-20:
  - `R/EDI/R/inference_all_abstract.R:116`: "see interval_censored_survival_response.md" (StratCox, DepCensTransformRegr).
  - `R/EDI/R/inference_all_abstract_rand_ci.R:279`: "R/package_metadata/new_feature_plans/v1_0_5/randomization_ci_construction_audit.md, section A."
  - `R/EDI/R/inference_all_abstract_rand_ci.R:337`: "See R/package_metadata/new_feature_plans/v1_1_0/incidence_randomization_cis.md."
  - `R/EDI/R/inference_all_abstract_rand_ci.R:357-358`: "See TODO-119 in R/package_metadata/future_release_plans/release_v1_0_5.md." (the
    RandCustom refusal of v1.0.7-TODO-72).
  - `R/EDI/R/inference_class_registry.R:325`: the same "See TODO-119 in ... release_v1_0_5.md." (registry refusal text).
  - `R/EDI/R/inference_class_registry.R:1184`: "(multimodal_log_liks.md)" (stereotype non-regularity note).
  - `R/EDI/R/helper_optimal_shared.R:39`: "DesignFixedGreedyDOptimal plan (see fix_design_hierarchy.md)" (an error).
  - `R/EDI/R/inference_procedure_regime.R:134`: "(TODO-192 regime note)" in a regime description string.
  Fix: replace each pointer with an installed help topic or article section (e.g. "Which classes accept interval
  censoring" in the censored-survival article, `?InferenceRand`), or drop it; keep internal references in comments.
  Add a source test that fails on any string literal in `R/` naming `package_metadata`, a `.md` file other than
  `REFERENCES.md`, or a `TODO-<n>`, so new ones cannot land. Repro: survival-censoring F6.

<a id="todo-81"></a>
<!-- pre-split-id: 1.0.6/314; 2026-11-25 -->

- [ ] TODO-81 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f1): **A `model_formula`
  naming a covariate that `"impute"` silently removed (an all-NA column) gives NA estimates with an unrelated `cbind`
  warning.** `x3 = NA_real_` for every subject is dropped from `get_X()` with no message (even `verbose = TRUE`); then
  `InferenceContinOLS$new(des, model_formula = ~ x1 + x3)` gives estimate NA, CI `NA NA`, `is_nonestimable()` FALSE, and
  only "number of rows of result is not a multiple of vector length" from `cbind(...)`; `InferenceContinLin` gives NA
  with reason `linear_model_design_unusable`. For an unknown name or a `drop_column`-removed column the constructor
  already stops with "model_formula contains variables not present in the available covariates"
  (`R/EDI/R/helper_additional_asserts.R` ~L38). Suspected: the formula check runs against the raw column names, while
  the all-NA column is dropped later inside the imputation step (`R/EDI/R/design_abstract.R`, `"impute"` branch
  ~L1180-1215). Fix: run the formula check against the columns that survive imputation and say why a column is gone
  ("x3 is NA for every subject and was removed before imputation"); with `verbose = TRUE`, or always, warn when
  imputation drops an all-NA column. Test: the finding's repro errors at `$new()` naming x3 for both classes. Repro:
  missing-data F1.

<a id="todo-82"></a>
<!-- pre-split-id: 1.0.6/315; 2026-11-25 -->

- [ ] TODO-82 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f2): **With
  `missingness_method = "error"`, covariate-adaptive sequential designs enroll subjects with NA covariates and fail later
  on a subject whose data are complete.** `DesignSeqOneByOneAtkinson` (p = 2) assigns subjects 1 to 4 although subject 1
  has `x2 = NA`; subject 5 fails with "Missing values detected in covariate(s): x2"; KK14/Atkinson with 3 covariates fail
  at t = 6. The message does not name the subject, and after it the trial cannot enroll anyone. The check lives in the
  lazy model-matrix build (`R/EDI/R/design_abstract.R` ~L1170-1177), which a sequential design first runs only when it
  needs covariates (after its burn-in). Fix: under `"error"`, check `anyNA(x_new)` in `add_one_subject()`
  (`R/EDI/R/design_seq_one_by_one_abstract.R` ~L79) before the subject is stored, and name the subject index and
  columns; also for `add_all_subjects_to_experiment()`. Test: the finding's repro errors at t = 1 naming subject 1 and
  x2; the design is unchanged after the error (see v1.0.6-TODO-196). Repro: missing-data F2.

<a id="todo-83"></a>
<!-- pre-split-id: 1.0.6/317; 2026-11-25 -->

- [ ] TODO-83 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f4): **An `Inf` covariate is
  accepted at enrollment, and inference later fails with `qr.default` "NA/NaN/Inf in foreign function call".**
  `add_all_subjects_to_experiment()` with `X$x2[3] = Inf` is accepted silently and `get_X()[3, ]` shows `Inf`;
  `InferenceContinOLS$compute_estimate()` then errors in `qr.default(X_mat)`. Responses are checked for finiteness
  (`assert_y()`), covariates are not; NaN is treated as missing and imputed. Fix: in `add_one_subject()` and
  `add_all_subjects_to_experiment()` refuse `Inf`/`-Inf` in numeric covariates with a message naming column and rows.
  Test: Inf in a fixed and a sequential design errors at entry naming x2 and row 3. Repro: missing-data F4.
  - Owner decision pending: [DECISION-v1.0.6-TODO-317](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-317) (refuse `Inf` covariates at entry, or treat them as missing under `"impute"`?).

<a id="todo-84"></a>
<!-- pre-split-id: 1.0.6/318; 2026-11-25 -->

- [ ] TODO-84 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f5): **When `"drop_column"`
  removes every covariate, covariate-balancing designs run silently without covariates.** `dim(get_X())` is `40 0`
  and `DesignFixedRerandomization(prop_acceptable = 0.01)` and KK14 assign with no warning, even with `verbose = TRUE`;
  in a 60-farm trial the rerandomized Mahalanobis imbalance on the true covariates was 0.092 under `drop_column`
  against 0.019 under `impute`. `draw_ws_raw()` simply falls back to unrestricted draws when `ncol(private$X) == 0`
  (`R/EDI/R/design_fixed_rerandomization.R` ~L206-207; KK, Greedy, Atkinson and Optimal have similar paths). Fix: when a
  design that uses covariates for assignment ends up with zero columns after the missingness step, warn once (classed
  `edi_no_covariates_left_warning`) naming the dropped columns and suggesting `"impute"`. Test: the finding's repro
  warns for Rerandomization and KK14; a design with covariates left does not. Repro: missing-data F5.

<a id="todo-85"></a>
<!-- pre-split-id: 1.0.6/319; 2026-11-25 -->

- [ ] TODO-85 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f7): **In sequential designs
  `get_X_raw()` and `get_X()` reorder the covariate columns when the first subject has missing values.** Input `a b c`
  with the first subject missing `a` and `c` gives `names(get_X_raw())` = `b a c` and `colnames(get_X())` starting `b a
  c`; values stay aligned by name, but positional indexing (`get_X()[, 1]`, `get_covariates()` in an extension class)
  gets the wrong covariate. Fixed designs keep the input order. Suspected: `add_one_subject()`
  (`R/EDI/R/design_seq_one_by_one_abstract.R` ~L79) builds the first row's schema from its non-missing columns first
  and appends the all-NA ones (logical-typed) afterwards. Fix: fix the column order from `names(x_new)` of the first
  subject (and keep it as later subjects arrive), whatever their missingness. Test: the finding's repro gives `a b c`
  for both getters; allocations unchanged. Repro: missing-data F7.

<a id="todo-86"></a>
<!-- pre-split-id: 1.0.6/320; 2026-11-25 -->

- [ ] TODO-86 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f8): **`get_summary()` on
  `InferenceContinOLS` prints only the treatment row, though the docs promise the full coefficient table for
  model-based classes.** On complete data the output is a single `treatment` row (estimate -0.0535, SE 0.265); no
  intercept or covariate rows, so a user cannot see what imputed covariates or `*_is_missing` indicators contribute.
  `get_summary()` (`R/EDI/R/inference_all_abstract.R` ~L320) builds the table via `edi_build_summary_table()`; suspected:
  the OLS fast path caches only the treatment coefficient and SE, not the full coefficient vector and covariance with
  names, so the one-row fallback is used. Fix: have the OLS fit cache the named coefficient vector and its covariance
  (it already computes them), and check the other model-based classes for the same gap. Test: the finding's repro
  shows rows for the intercept, treatment, x1 and x2 matching `summary(lm())` to 1e-8. Repro: missing-data F8.

### Audit-written bug tests that were skipped without a TODO, 2026-11-22
The numerical-robustness audit (PRs #51, #64, #71) added these tests with `skip("open a release TODO for this")`, and no TODO was ever opened for them. Each one was re-run on HEAD `ac08e642` (2026-11-22) with the skip removed, under `load_all(compile = FALSE)`. Every test that still fails now skips with a message citing its TODO.

<a id="todo-87"></a>
<!-- pre-split-id: 1.0.6/385; 2026-11-25 -->

- [ ] TODO-87 (added 2026-11-22, coordinator, owner request; numerical-robustness-609a1f12ec78): **`InferencePropBetaRegr` marginal-mean-diff SE is NA when a covariate is on a large scale.**
  On HEAD, `se_big` is NA while the unit-scale SE is 0.0328. `generate_mod()` (`R/EDI/R/inference_proportion_beta.R` ~L741) discards the vcov when the raw `rcond(fi) < sqrt(eps)`, and that test depends on scale.
  Fix: test conditioning on `D^{-1/2} fi D^{-1/2}` with `D = diag(fi)`, or use the kernel's own invertibility flag.
  Test: `R/package_tests/testthat_bulk/test-beta-regr-marginal-se-covariate-rescaling-invariance.R` ("beta regression marginal_mean_diff SE is invariant to rescaling a covariate"), currently skipped; remove the skip when fixed.

<a id="todo-88"></a>
<!-- pre-split-id: 1.0.6/386; 2026-11-25 -->

- [ ] TODO-88 (added 2026-11-22, coordinator, owner request; numerical-robustness-23a66300445a): **Combined evidence returns NaN, or one p-value labelled as combined, when fewer than two rows have a positive custom weight.**
  On HEAD, `res0$pval` is NaN with all-zero weights, and with one positive weight the result is that row's p-value instead of NA. `run_all_inference_combine_pvalues()` (`R/EDI/R/inference_suite.R` ~L4273) counts a row as usable whenever its weight is finite, zero included.
  Fix: require `weights > 0` in `usable`, so the existing `n_used < 2 -> NA` branch fires.
  Test: `R/package_tests/testthat_bulk/test-combined-evidence-zero-custom-weights-not-nan.R` ("combined evidence returns NA, not NaN or a single p-value, when fewer than two rows carry positive weight"), currently skipped; remove the skip when fixed.

<a id="todo-89"></a>
<!-- pre-split-id: 1.0.6/387; 2026-11-25 -->

- [ ] TODO-89 (added 2026-11-22, coordinator, owner request; numerical-robustness-3165df9ca614): **The Cox R fallback kernel always reports `converged = TRUE`.**
  On HEAD, on a monotone-likelihood fit where `coxph.fit` runs out of iterations and warns, `fit_converged` differs from the reference flag. `.fit_survival_coxph_kernel()` (`R/EDI/R/inference_survival_coxph.R` L44/L69/L105) hard-codes `converged = TRUE` inside `suppressWarnings()`.
  Fix: derive `converged` from `coxph.fit` (`iter < iter.max`, no "Ran out of iterations") and pass it through the fixed-kernel wrapper.
  Test: `R/package_tests/testthat_bulk/test-coxph-r-fallback-kernel-convergence-flag.R` ("Cox R fallback kernel reports convergence only when survival::coxph.fit converged"), currently skipped; remove the skip when fixed.

<a id="todo-90"></a>
<!-- pre-split-id: 1.0.6/388; 2026-11-25 -->

- [ ] TODO-90 (added 2026-11-22, coordinator, owner request; numerical-robustness-6fbae0626f0b): **The combined conditional-Poisson restricted fit reports `converged = FALSE` at the exact restricted optimum.**
  On HEAD, `fit$converged` is FALSE even though the free-parameter estimates match the restricted MLE. `fast_cpoisson_combined_internal` (`R/EDI/src/fast_cpoisson_combined.cpp` ~L340) tests `grad.norm()` over all parameters, including the ones held fixed by `fixed_idx`.
  Fix: take the norm over `fixed_spec.free_idx` only, as the Newton step already does.
  Test: `R/package_tests/testthat_bulk/test-cpoisson-combined-fixed-parameter-convergence-flag.R` ("combined cond-Poisson restricted fit reports convergence at the restricted optimum"), currently skipped; remove the skip when fixed.

<a id="todo-91"></a>
<!-- pre-split-id: 1.0.6/390; 2026-11-25 -->

- [ ] TODO-91 (added 2026-11-22, coordinator, owner request; numerical-robustness-a98e2d9a3577): **`InferenceCountKKCondPoissonOneLik`'s pairs-only fallback always sets the SE to NA.**
  On HEAD, the SE is NA where the reference conditional-logit model SE is 0.173. `try_pairs_only()` (`R/EDI/R/inference_count_KK_cond_poisson.R` ~L2210) sets `s_beta_hat_T = NA_real_`, so studentized bootstrap replicates on that path have no SE.
  Fix: when `!estimate_only`, use the `[1,1]` entry of `solve(crossprod(X, X * n_k * p * (1 - p)))`, as `try_reservoir_only` does.
  Test: `R/package_tests/testthat_bulk/test-kk-cond-poisson-pairs-only-fallback-standard-error.R` ("KK cond-Poisson pairs-only fallback reports the finite conditional-logit model SE"), currently skipped; remove the skip when fixed.

<a id="todo-92"></a>
<!-- pre-split-id: 1.0.6/391; 2026-11-25 -->

- [ ] TODO-92 (added 2026-11-22, coordinator, owner request; numerical-robustness-5402ae828a70): **The off-optimum penalized neg-loglik is finite at an indefinite information matrix.**
  On HEAD, with `diag(2, -3)` the function returns -0.396 instead of Inf. `evaluate_penalized_neg_loglik_at()` (`R/EDI/R/inference_mixin_off_optimum_likelihood_eval.R` ~L99) uses `determinant()$modulus` and drops the sign, so the Jeffreys/Firth penalty is evaluated where it is undefined.
  Fix: return Inf unless `chol()` succeeds (or `$sign == 1`), and use `2 * sum(log(diag(R)))` as the log-determinant.
  Test: `R/package_tests/testthat_bulk/test-off-optimum-penalized-loglik-indefinite-information.R` ("penalized neg-loglik is infeasible (Inf) when the information matrix is indefinite"), currently skipped; remove the skip when fixed.

<a id="todo-93"></a>
<!-- pre-split-id: 1.0.6/392; 2026-11-25 -->

- [ ] TODO-93 (added 2026-11-22, coordinator, owner request; numerical-robustness-96505e151f00): **The cloglog full-data multistart does nothing on the estimate-only path.**
  On HEAD, a stalled primary fit is returned unchanged: `b[1]` is 1.64 against the MLE's -0.357. `.cloglog_full_data_multistart()` (`R/EDI/R/inference_ordinal_cloglog.R` L1) needs `neg_loglik`, which the estimate-only kernel never returns, so no candidate can be compared.
  Fix: have the estimate-only kernel return `neg_loglik`, or evaluate it in the helper. Related: v1.1.0-TODO-203 (gate the multistart on a certificate).
  Test: `R/package_tests/testthat_bulk/test-ordinal-cloglog-estimate-only-multistart-repairs-stalled-fit.R` ("cloglog full-data multistart repairs a stalled primary fit on the estimate-only path"), currently skipped; remove the skip when fixed.

<a id="todo-94"></a>
<!-- pre-split-id: 1.0.6/397; 2026-11-25 -->

- [ ] TODO-94 (added 2026-11-22, coordinator, owner request; numerical-robustness-f0b0281da215): **The stereotype logit parametric-bootstrap simulator breaks for a binary (K = 2) response.**
  On HEAD, `simulate_under_lik_null()` returns NULL and the parametric-bootstrap LR p-value is NA (with a warning). `gammas = params_null[(n_alpha + p + 1L):n_params]` (`R/EDI/R/inference_ordinal_stereotype_logit.R` ~L716) counts downward when there are no loadings, which gives `c(NA, beta)`.
  Fix: `gammas = if (n_gamma > 0L) params_null[n_alpha + p + seq_len(n_gamma)] else numeric(0)`. Check the same idiom at ~L44.
  Test: `R/package_tests/testthat_bulk/test-stereotype-logit-binary-response-param-bootstrap-simulation.R` ("stereotype logit parametric LR bootstrap simulates a binary (K = 2) response"), currently skipped; remove the skip when fixed.

<a id="todo-95"></a>
<!-- pre-split-id: 1.0.6/398; 2026-11-25 -->

- [ ] TODO-95 (added 2026-11-22, coordinator, owner request; numerical-robustness-5a9caf5f5780): **The estimate-only stratified-Cox helper reports `converged = TRUE` after hitting `iter.max`.**
  On HEAD, `res$converged` is TRUE for an unconverged coefficient. `cox_partial_likelihood_fit_estimate_only_fast()` (`R/EDI/R/inference_survival_strat_cox.R` ~L59-92) hard-codes the flag. This is the sibling of TODO-387.
  Fix: take the flag from `coxph.fit` (iterations below the cap and no "Ran out of iterations"), or return NULL when the cap is hit.
  Test: `R/package_tests/testthat_bulk/test-strat-cox-estimate-only-fit-convergence-flag.R` ("estimate-only coxph.fit helper does not report convergence when the iteration cap is hit"), currently skipped; remove the skip when fixed.

<a id="todo-96"></a>
<!-- pre-split-id: 1.0.6/399; 2026-11-25 -->

- [ ] TODO-96 (added 2026-11-22, coordinator, owner request; numerical-robustness-7110d0cf73ab): **The ZIP degeneracy check flags well-identified fits whose count intercept is below -15 (an uncentred covariate).**
  On HEAD, the marginal CI is `c(NA, NA)` on the raw covariate and `(-0.102, 0.957)` once it is centred. `zero_augmented_fit_is_degenerate()` (`R/EDI/R/inference_count_zero_augmented_poisson_abstract.R` ~L1699) uses `params[1] < -15`, which depends on where the covariates sit.
  Fix: drop the intercept rule, or check the fitted rates instead (e.g. `max(lambda)` near 0).
  Test: `R/package_tests/testthat_bulk/test-zero-augmented-degeneracy-uncentered-covariate-intercept.R` ("ZIP marginal CI is finite and invariant to shifting an uncentered covariate"), currently skipped; remove the skip when fixed.

<a id="todo-97"></a>
<!-- pre-split-id: 1.0.6/400; 2026-11-25 -->

- [ ] TODO-97 (added 2026-11-22, coordinator, owner request; numerical-robustness-dfcfe3aea2a6): **The Zhang combined p-value treats an underflowed matched-pairs p (p_M = 0) as missing, so the exact CI upper bound becomes +Inf.**
  On HEAD, `p_fn(8.5)` is 1.00 where it should be at most 0.05, and the upper endpoint is Inf where the expected value is below 0.5. In `zhang_combine_exact_pvals()` (`R/EDI/R/inference_helpers_zhang.R` L20-21), `has_M` requires `p_M > 0`.
  Fix: treat `p_M == 0` (or `p_R == 0`) as decisive (combined p = 0), or compute the components in log space. Related: v1.1.0-TODO-211 (tail-accurate combination).
  Test: `R/package_tests/testthat_bulk/test-zhang-combined-pval-underflowed-matched-component.R` ("Zhang combined p-value does not drop an underflowed matched-pairs p-value and the exact CI stays finite"), currently skipped; remove the skip when fixed.

<a id="todo-98"></a>
<!-- pre-split-id: 1.0.6/401; 2026-11-25 -->

- [ ] TODO-98 (added 2026-11-22, coordinator, owner request; numerical-robustness-c12c91fd6454): **The ZOIB marginal mean difference under bootstrap weights is wrong even with unit weights.**
  On HEAD, the unit-weight estimate differs from the unweighted ML estimate by 0.029, against a tolerance of 0.005. `compute_estimate_with_bootstrap_weights()` (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R` ~L272) fits two independent binary logits for P(0) and P(1), then feeds them to `zoib_marginal_mean_diff_from_coefs()`, which expects softmax logits.
  Fix: fit the zero/one parts as one weighted multinomial logit with the interior as reference (or as a weighted `fast_zero_one_inflated_beta` fit). Related: v1.1.0-TODO-197.
  Test: `R/package_tests/testthat_bulk/test-zoib-marginal-weighted-unit-weights-match-ml-estimate.R` ("ZOIB marginal mean diff under unit bootstrap weights matches the unweighted ML estimate"), currently skipped; remove the skip when fixed.

### Process and save-format questions from the audit free-text sweep, 2026-11-22
Found by the 2026-11-22 sweep of every audit report for items written outside the structured findings.

<a id="todo-99"></a>
<!-- pre-split-id: 1.0.6/402; 2026-11-25 -->

- [ ] TODO-99 (added 2026-11-22, coordinator, owner request; audit free-text sweep, test-suite-health run 44358374710
  `mechanical.json` and numerical-robustness PRs #51/#64/#71): **Audit-written bug tests that are skipped without a
  TODO never reach any issue.** The numerical-robustness audit merges a failing test for each bug it finds behind
  `skip("open a release TODO for this")`, and audit-notes marks the finding `fixed`/`proposed`; test-suite-health
  reports these skips only as `unconditional-skip` in its own `mechanical.json`, which `audit_decisions.py` does not
  read. 17 such tests sat untracked until v1.0.7-TODO-87 / v1.0.7-TODO-88 / v1.0.7-TODO-89 / v1.0.7-TODO-90 / v1.0.6-TODO-197 / v1.0.7-TODO-91 / v1.0.7-TODO-92 / v1.0.7-TODO-93 / v1.0.6-TODO-198 / v1.0.6-TODO-199 / v1.0.6-TODO-200 / v1.0.6-TODO-201 / v1.0.7-TODO-94 / v1.0.7-TODO-95 / v1.0.7-TODO-96 / v1.0.7-TODO-97 / v1.0.7-TODO-98 (2026-11-22).
  - Owner decision pending: [DECISION-v1.0.6-TODO-402](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-402) (how should
    skipped audit tests without a TODO be surfaced?).

<a id="todo-100"></a>
<!-- pre-split-id: 1.0.6/403; 2026-11-25 -->

- [ ] TODO-100 (added 2026-11-22, coordinator, owner request; audit free-text sweep, docs-scenarios run 44883784401,
  save-load "could not do"): **A saved design or inference object carries its own method code.** R6 objects
  serialize their method closures, so `readRDS()` of a design saved under an older EDI keeps running the old code
  under a newer installed EDI, silently. `?Design` and the reproducibility vignette say nothing about it.
  - Owner decision pending: [DECISION-v1.0.6-TODO-403](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-403) (what should
    happen when an object saved under another EDI version is loaded?).

<a id="todo-101"></a>
<!-- pre-split-id: 1.0.6/406; 2026-11-25 -->

- [ ] TODO-101 (added 2026-11-22, coordinator, owner request; found by the v1.0.6-TODO-224 doc agent, from reading the
  code, not yet reproduced): **`DesignFixedBlockedCluster$set_m()` can store block ids that differ from the strata
  used to randomize.** Randomization draws always use `strata_cols`, while `set_m()` (inherited from
  `design_blocking_abstract.R` ~L76) only replaces what `get_block_ids()` reports; inference that reads
  `get_block_ids()` (blocked jackknife, block bootstrap, stratified tests) would then analyse different strata from
  the ones the allocation was drawn in. Fix: reproduce first; then either refuse `set_m()` on this class (or when the
  ids disagree with the strata) or make it re-derive the strata. Test: `set_m()` with ids that disagree with
  `strata_cols` errors (or the analysis strata equal the randomization strata).

<a id="todo-102"></a>
<!-- pre-split-id: 1.0.6/431; 2026-11-25 -->

- [ ] TODO-102 (added 2026-11-25, agent, owner request: "we can run this on the post push"): **Real-data crash corpus: a push-triggered CI job that runs every applicable inference class on every catalog trial and counts errors, non-convergence and NAs.**
  - Why. `comprehensive_tests.R` runs on a handful of real covariate matrices capped at `max_n_dataset = 148` rows, with simulated responses. Real trials hit failures those don't: separation, constant or near-constant columns, real missingness patterns, ties, tiny arms, unequal allocation, heavy censoring, cluster columns with singletons. The experimental catalog (`R/package_metadata/experimental_datasets.csv`, 271 trials, median n = 135) supplies them with their real outcomes. This finds crashes and silent NAs; it says nothing about calibration (that is v1.1.0-TODO-271).
  - What it runs. One case per (catalog row, outcome, inference class applicable to that outcome's response type), on the CRAN-hosted rows with Redistribution `yes` (223 rows; data installed from CRAN at the catalog's pinned versions, never committed or uploaded). Each case builds the matching design from the catalog's treatment column (the documented design where the catalog has one, e.g. `cgd` blocked on `center`, else DesignFixedBernoulli with `w_precomputed` = the trial's real assignment, a cluster design where a cluster column exists), adds the covariates and the real outcome, and calls `compute_estimate()`, `compute_asymp_two_sided_pval()`, `compute_asymp_confidence_interval()` and, with a small seeded r / B, one randomization p-value and one bootstrap CI. Trials with more than two arms use the catalog's treatment-vs-control coding; multi-factor DOE rows (`solder`, `savings`) are skipped with a reason.
  - What it records. Per case and call: ok / error (message) / warning (message) / NA or non-finite / non-estimable (EDI's own refusal, which is expected and counted separately from a crash) / wall time. Output: a CSV artifact plus a step summary table by class and by dataset.
  - Gate. A committed baseline `R/package_tests/ci/real_data_crash_corpus_baseline.csv` lists each case's expected status. The job fails on a new error, a new NA where the baseline had a value, or a case that times out (per-case limit, e.g. 60 s, so one hanging fit cannot stall the job); a case that improves is reported, and the baseline is refreshed by a script, the same pattern as the drift artifacts. Each baseline error or NA row cites an open TODO (release-prefixed), like an accepted calibration row; triaging the first run's errors into TODOs is part of this TODO.
  - Placement. A new push-triggered workflow (`real-data-crash-corpus.yml`), like `rpy-parity-push.yml` / `code-duplication-push.yml`: `on: push` to main with a path filter on `R/EDI/R/**`, `R/EDI/src/**`, the catalog CSV and the job's own scripts, plus `workflow_dispatch`. Not a required check. It installs EDI once (cached like the other push workflows) and the catalog's CRAN packages from a cached library (about 124 packages, so the cache matters), then runs the cases sharded by response type in a few jobs, keeping within the 20-concurrent-job budget it shares with push CI and the calibration waves (4 slots kept free).
  - Step 1. Write the case runner as a script usable locally (`Rscript R/package_tests/real_data_crash_corpus.R [--datasets ...] [--classes ...]`), run it once in full, and record here: case count, total and per-response-type wall time, and the error / NA / non-estimable counts by class. If the full run is too slow for every push, report to the owner the options (a smaller per-push subset with the full corpus at release time, or path-filtered shards) before wiring the workflow.
  - Done when: the workflow runs on push and on dispatch, the baseline is committed with every error / NA row citing a TODO, `R/package_tests/ci/README.md` documents the job and how to refresh the baseline, and a deliberately broken class (local check) makes the job fail.

<a id="todo-103"></a>
<!-- pre-split-id: 1.0.6/432; 2026-11-25 -->

- [ ] TODO-103 (added 2026-11-25, agent, owner request: "make this a weekly run that only runs if any Design code changes"): **Design balance on real covariates: a weekly job that replays real trials' patients through every design and reports how well each balances their covariates.**
  - What it is. A benchmark, not validation: there is no right answer to check, and nothing fails on a worse number. For each catalog trial, keep its covariate matrix in row order (or enrollment order where the data carry one, e.g. `cgd$random`), discard its outcome and its assignment, and assign the subjects with each design: the fixed designs on the whole matrix, the sequential designs one subject at a time in that order, as in the README's "Sequential experimental data example → Real data" (Pocock-Simon on `medicaldata::strep_tb`). Repeat over seeded draws per design. It complements the calibration study's balance statistics (`R/package_tests/calibration/calibration_study_balance.R`, `balance_calibration_study.R`), which measure balance on the campaign's simulated covariates; this measures it on real covariate distributions (skew, ties, factors with rare levels, missingness, correlated columns).
  - Metrics. Reuse `calibration_study_balance.R`'s statistics where they apply, so the two reports are comparable: standardized mean difference per covariate (max and mean over covariates), Mahalanobis imbalance, margin imbalance of each factor level, treated-share deviation from the design's target, plus each design's wall time. Report per design the median and spread over trials and draws, and the trial's own allocation as a reference row where the catalog has its assignment.
  - Data. The CRAN-hosted catalog rows with Redistribution `yes` (as in v1.0.7-TODO-102; data installed from CRAN at the pinned versions, never committed or uploaded). Rows far larger than a shard's budget are subsampled to n = 50, 200 and 1000, matching the calibration grid, with the subsample redrawn per draw. Designs that need settings (strata columns, block sizes, matching parameters) use the catalog's documented strata or cluster column where there is one and the design's defaults otherwise; record which.
  - Schedule. New workflow `design-balance-real-data.yml`: `on: schedule` weekly plus `workflow_dispatch` (with a `force` input). A first job decides whether to run: it runs only if a significant change (`scripts/significant_changes.py`, so comment- and whitespace-only edits do not count) touched Design code since the last successful run of this workflow (`R/EDI/R/design_*.R`, the design kernels in `R/EDI/src/` they call, e.g. `atkinson_assign.cpp`, `binary_match_search.cpp`, and the job's own scripts). Fails open like nightly.yml's `change-gate` (no earlier run, a force-pushed base or an API error means run). List the design kernels explicitly in the workflow, with a check that every `.cpp` reached from a `design_*.R` file is in the list (the `rpy-parity-push.yml` path list has a test of this kind).
  - Output. A report published like the nightly benchmark (a page under the GitHub Pages site, e.g. `benchmarks/design-balance/`, via the same pkgdown-artifact swap as `bench-pages`) plus the CSV of every (trial, design, draw) result as an artifact; the README's benchmark line links it once it has published.
  - Step 1. Write the runner as a script usable locally (`Rscript R/benchmark/design_balance_real_data.R [--datasets ...] [--designs ...] [--draws N]`), run it on a few trials (`cgd`, `lalonde.exp`, `STAR`, `indo_rct`) and record here the runtime per design and the full corpus estimate, so the workflow's sharding and draw count can be set.
  - Done when: the workflow skips a week with no Design change, runs on one with a change (or on `force`), publishes the report and CSV, and the benchmark section of `CONTRIBUTING.md` documents it.

## Drafted from calibration campaign 2026-11-15-e36c7710 (review)

Drafted by `R/package_tests/calibration/triage_calibration_study.R` from the campaign's `summary/triage.csv`: one TODO per failing class x procedure x metric. Review each: edit, merge or delete it, and move kept ones into the implementation list.

<a id="todo-104"></a>
<!-- pre-split-id: 1.0.6/250; 2026-11-25 -->

- [ ] TODO-104 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedPoisson`'s `rand` fails its null size gate; small n only: passes at the largest n.** 25 failing cell(s) (0 confirmed, 25 awaiting confirmation (campaign still running when drafted)) on 13 design(s): SeqOneByOne:KK14, Fixed:Bernoulli@0.2, Fixed:Blocking@0.2, Fixed:Greedy@0.2, Fixed:GreedyDOptimal@0.2, Fixed:iBCRD@0.2, Fixed:OptimalBlocks@0.2, Fixed:Rerandomization@0.2, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:iBCRD@0.2, SeqOneByOne:RandomBlockSize@0.2, SeqOneByOne:SPBR@0.2, Fixed:OptimalBlocks; formulas ~., ~1; failing at n = 50, 200 (tested at n = 50, 200, 1000); effects null. Worst cell: Fixed:Greedy@0.2, ~1, n = 50, null: size 0.185 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignFixedGreedy@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedPoisson/rand/size -->

<a id="todo-105"></a>
<!-- pre-split-id: 1.0.6/251; 2026-11-25 -->

- [ ] TODO-105 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedNegBin`'s `rand` fails its null size gate; persistent: fails at the largest n.** 95 failing cell(s) (8 confirmed, 87 awaiting confirmation (campaign still running when drafted)) on 31 design(s): Fixed:Bernoulli@0.2, Fixed:Bernoulli, Fixed:BinaryMatch, Fixed:Blocking, Fixed:Blocking@0.2, Fixed:Greedy, Fixed:Greedy@0.2, Fixed:GreedyDOptimal, Fixed:GreedyDOptimal@0.2, Fixed:iBCRD, Fixed:iBCRD@0.2, Fixed:OptimalBlocks, Fixed:OptimalBlocks@0.2, Fixed:Rerandomization, Fixed:Rerandomization@0.2, SeqOneByOne:Atkinson, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:Bernoulli, SeqOneByOne:Efron, SeqOneByOne:iBCRD, SeqOneByOne:KK21, SeqOneByOne:KK21stepwise, SeqOneByOne:RandomBlockSize@0.2, SeqOneByOne:RandomBlockSize, SeqOneByOne:SPBR, SeqOneByOne:SPBR@0.2, SeqOneByOne:Urn, Fixed:MatchingGreedyPairSwitching, SeqOneByOne:iBCRD@0.2, SeqOneByOne:PocockSimon, SeqOneByOne:KK14; formulas ~., ~1; failing at n = 50, 200, 1000 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:RandomBlockSize@0.2, ~., n = 50, null: size 0.109 vs level 0.05 (964 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneRandomBlockSize@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedNegBin --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedNegBin/rand/size -->
  - **Status 2026-11-26 (agent; partial, not done):** the persistent n = 1000 `~1` flags are fixed on the current
    tree. Run with `pkgload::load_all(compile = FALSE)` (uncommitted tree of 2026-11-25), the campaign's own data
    (`cal_study_run_rep()`, confirmation seeds, reps 10001-10400), rand only, r = 501. Size with Clopper-Pearson 95%:

    | design | n | formula | reps | size now | campaign (5000 reps) |
    |---|---|---|---|---|---|
    | FixedBernoulli | 1000 | `~1` | 400 | 0.0275 [0.014, 0.049] | 0.0854 |
    | SeqOneByOneEfron | 1000 | `~1` | 400 | 0.0425 [0.025, 0.067] | 0.0902 |
    | FixedBinaryMatch | 1000 | `~1` | 400 | 0.0375 [0.021, 0.061] | 0.0826 |

    Why: at n = 1000 `~1` (FixedBernoulli, 12 datasets, 6,012 draw fits), 0% of the draw fits are off the MLE now
    (best of three cold kernel fits plus `pscl::zeroinfl`, tolerance 1e-4 in nll). An emulation of the campaign's
    code (chained warm start, no guard) on the same datasets gives 72% off the MLE: median treatment-estimate error
    0.045, nll gap up to 9.3. The `~1` flags therefore come from the chaining (removed in c28bbb34) plus the missing
    guard. Each draw is warm-started from the full-data fit (anchored), and the guard refits about 33% of draw fits.
    Not yet measured: FixedBlocking@0.2 n = 1000 (the run died), the n = 200 `~1` cells and the n = 50 `~.` cells.
    **Still open at n = 50 `~.`:** 12% of draw fits (FixedBernoulli, 30 datasets, 15,060 fits) stop at an interior
    local maximum. These fits are converged, with gradient about 1e-7 and zero-part coefficients about 1, so the
    guard does not flag them. The supremum is on a zero-part separation ridge, up to 13.6 nll units lower. Adding a
    plain cold-start candidate fixes about half (64 to 30 of 502 draws on one dataset). The likelihood has several
    ridges, so "always the MLE" is not reachable. A randomization test stays exact if every draw and the observed
    fit use the same deterministic fitting procedure, without a warm start taken from the observed fit. The size
    effect of these fits is not measured yet (0 of 30 rejections in the probe; the 2026-11-19 run gave 0.053 on
    other seeds). Scripts and outputs: `/tmp/claude-1000/zinb105/` (`run_cells.R`, `mle_check.R`,
    `mle_check_old.R`, `debug2.R`, `patched_guard.R`, `res_*.rds`, `mle_*.rds`).
    Next: measure the n = 200 `~1` and n = 50 `~.` cells (`run_cells.R`, 400 reps). If n = 50 `~.` is oversized, make
    the draw fit independent of the observed fit and add a cold-start candidate. Done when, as before, the next
    campaign confirms these cells.

<a id="todo-106"></a>
<!-- pre-split-id: 1.0.6/252; 2026-11-25 -->

- [ ] TODO-106 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountRobustPoisson`'s `rand` fails its null size gate; persistent: fails at the largest n.** 2 failing cell(s) (0 confirmed, 2 awaiting confirmation (campaign still running when drafted)) on 2 design(s): SeqOneByOne:Atkinson, SeqOneByOne:Bernoulli@0.2; formulas ~1; failing at n = 200, 1000 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Bernoulli@0.2, ~1, n = 1000, null: size 0.076 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneBernoulli@prob_T=0.2' --n 1000 --effect null --only InferenceCountRobustPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountRobustPoisson/rand/size -->

<a id="todo-107"></a>
<!-- pre-split-id: 1.0.6/253; 2026-11-25 -->

- [ ] TODO-107 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountQuasiPoisson`'s `rand` fails its null size gate; small n only: passes at the largest n.** 1 failing cell(s) (0 confirmed, 1 awaiting confirmation (campaign still running when drafted)) on 1 design(s): SeqOneByOne:Atkinson; formulas ~1; failing at n = 200 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Atkinson, ~1, n = 200, null: size 0.075 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneAtkinson' --n 200 --effect null --only InferenceCountQuasiPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountQuasiPoisson/rand/size -->

<a id="todo-108"></a>
<!-- pre-split-id: 1.0.6/254; 2026-11-25 -->

- [ ] TODO-108 (added 2026-11-19, owner; from docs-claims audit finding `docs-claims-d1f53ee72`; CHANGES RESULTS):
  **`InferenceIncidNewcombeRiskDiff` p-value is the 1e-300 floor instead of 1 when delta sits on the interval boundary
  at every alpha.** With p_T = 1, p_C = 0 and delta = 1 the null is inside every Newcombe interval (the upper bound is
  capped at 1), but `compute_asymp_two_sided_pval(delta = 1)` returns 1e-300. The upper-boundary branch measures
  `ci[2] - delta`, which is exactly 0 at the floor, and `outside_at_floor = ... at_floor <= 0`
  (`R/EDI/R/inference_incidence_newcombe_univ.R` ~L197) counts that zero gap as outside. The doc (~L170) says the
  p-value is 1 in this case.
  - Fix: treat a zero gap as inside (`at_floor < 0` on the upper side, `at_floor > 0` on the lower side), and check the
    `inside_at_ceiling` test the same way. Remove the `skip()` in
    `R/package_tests/testthat_bulk/test-newcombe-pval-boundary-estimate-equals-delta.R` and cite this TODO there.
  - Changes the p-value on boundary data: add a NEWS bullet under "Changes that alter results".
  - Done when: the un-skipped boundary test passes (p-value 1 at delta = 1 with p_T = 1, p_C = 0), the other Newcombe
    tests still pass, and NEWS notes the change.

<a id="todo-109"></a>
<!-- pre-split-id: 1.0.6/255; 2026-11-25 -->

- [ ] TODO-109 (added 2026-11-19, owner; from docs-claims audit finding `docs-claims-dfa95cecb`): **KK g-computation
  failed fits are never marked non-estimable.** The docs (e.g. `InferenceIncidKKGCompRiskRatio`,
  `R/EDI/R/inference_incidence_KK_marginal.R` ~L315 and ~L419) say a working model that fails to converge, has no
  treatment-arm variation, or gives a zero all-control standardized risk is marked non-estimable via
  `is_nonestimable()`. In all three cases `shared()` (`R/EDI/R/inference_incidence_KK_gcomp_abstract.R` ~L550) calls
  `set_failed_fit_cache()`, which calls `gcomp_cache_failed_standardized_effects()` (`R/EDI/R/helper_gcomp.R`
  ~L114). That only writes NA effects and never calls `cache_nonestimable_estimate()`, so `cached_values$nonestimable`
  stays unset and `is_nonestimable()` returns FALSE. This affects every KK g-comp class (risk difference and risk
  ratio).
  - Fix: have the failed-fit path call `private$cache_nonestimable_estimate()` with a reason per failure mode (e.g.
    `gcomp_working_model_failed`, `gcomp_no_treatment_variation`, `gcomp_zero_control_risk`), keeping the NA estimate.
    Check that resampling replicates still count the failures as before.
  - Test: for each of the three failure modes, on each KK g-comp class, `compute_estimate()` is NA and
    `is_nonestimable()` is TRUE with the expected reason.
  - Done when: the new tests pass and the existing KK g-comp tests are unchanged.
  - **Merged 2026-11-20 (owner):** one item for every class that returns NA without flagging it non-estimable.
    Fix all of these together, with one shared helper or reason-naming convention, and remove each skip():
    - v1.0.7-TODO-114 (KK g-comp RD/RR): also an all-treated `DesignFixedBinaryMatch` design gives a finite
      estimate instead of non-estimable (`shared()` must check `w` variation / a missing treatment column); skip at
      `R/package_tests/testthat_bulk/test-rand-bootstrap-and-kk-gcomp-fallback-branches-reference.R:179`.
    - v1.0.7-TODO-113 (`InferenceIncidWald` empty arm, `compute_incidence_wald_components()`); skip at
      `test-incid-wald-welch-ttest-dispatch-reference.R:118`.
    - v1.0.7-TODO-116 (`InferenceCountPoisson` weighted refit with non-finite beta_T); skip at
      `test-count-poisson-deferred-fit-weighted-refit-and-estimand-switch.R:100`.
    - v1.0.7-TODO-118 (`InferencePropBetaRegr` failed weighted refit, `inference_proportion_beta.R` ~L328); skip at
      `test-prop-beta-regr-deferred-fit-boundary-responses-and-weighted-refit.R:77`.
    - v1.0.7-TODO-119 (`InferencePropFractionalLogit` failed weighted refit, ~L216); skip at
      `test-fractional-logit-weighted-coefficient-reference.R:92`.
    The details of each stay in its own entry below. Done when all six are fixed and every skip() is gone.

<a id="todo-110"></a>
<!-- pre-split-id: 1.0.6/256; 2026-11-25 -->

- [ ] TODO-110 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d38c37c85`): **`InferenceOrdinalPartialProportionalOddsRegr` docs misdescribe the last-resort bootstrap surrogate.**
  The roxygen of `compute_estimate_with_bootstrap_weights` (`R/EDI/R/inference_ordinal_partial_proportional_odds.R:97-101`) says that when every weighted backend fails the fallback is "a plain weighted binary-logistic surrogate fit ... that does not model the ordinal structure at all". `weighted_ordinal_bootstrap_surrogate_fit(method = "logistic")` (`R/EDI/R/globals.R:177-251`) actually fits a weighted `MASS::polr` proportional-odds model (`fit_type` "polr_logistic") and falls back to `lm.wfit`. The value returned is right; only the description is wrong.
  - Failing expectation: `expect_false(startsWith(sur$fit_type, "polr"))`, skipped at `R/package_tests/testthat_bulk/test-partial-odds-backend-fallback-reference.R:145`.
  - Candidate fix (doc): say "weighted proportional-odds (polr) surrogate, falling back to weighted least squares", and change the test expectation to match.
  - Done when: fix it and remove the skip().

<a id="todo-111"></a>
<!-- pre-split-id: 1.0.6/257; 2026-11-25 -->

- [ ] TODO-111 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d7b766030`): **`InferenceOrdinalStereotypeLogitRegr` gives the wrong non-estimable reason when every covariate is dropped.**
  The docs (`R/EDI/R/inference_ordinal_stereotype_logit.R:872-874`) say a treatment-only fit (`~1` or all covariates dropped) is non-estimable with reason `stereotype_treatment_only_fit_not_identified`. `~1` does give it. With `~ xdup` (an exact copy of treatment, n = 120, 4 categories), 6 of 8 seeds give `stereotype_treatment_only_fit_at_loading_boundary`. In `generate_mod()` (about lines 584-624) the `length(attempt$fit$b) <= 1L` check only runs when the hardened refit returns a usable fit. When the treatment-only refit is rejected at a loading boundary, `attempt$fit` is NULL and the boundary reason wins.
  - Failing expectation: `expect_identical(...$cached_values$nonestimable_reason, "stereotype_treatment_only_fit_not_identified")`, skipped at `R/package_tests/testthat_bulk/test-stereotype-logit-null-refit-history-independence.R:97`.
  - Candidate fix (code): when K >= 3 and the column-dropping ladder ends at treatment only, report `stereotype_treatment_only_fit_not_identified` whatever the boundary rejection says. Alternative (doc): name both reasons.
  - Done when: fix it and remove the skip().

<a id="todo-112"></a>
<!-- pre-split-id: 1.0.6/258; 2026-11-25 -->

- [ ] TODO-112 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-da2b1f69e`): **`InferenceOrdinalRidit`'s public bootstrap ignores `max_resample_attempts`.**
  The constructor docs (`R/EDI/R/inference_ordinal_ridit.R:106-109`) say a draw that loses an arm is redrawn up to `max_resample_attempts` times and is NA only after all attempts fail. Only the private `compute_fast_bootstrap_distr(B, n, y, dead, w)` (lines 299-330) uses the setting, and nothing on the public non-KK path calls it. The only caller is `inference_mixin_kk_passthrough.R:101`, with a different signature. With n = 10, 1 treated subject, B = 40 and seed 1, `approximate_bootstrap_distribution_beta_hat_T()` returns the identical vector with 14/40 NA for both `max_resample_attempts = 1L` and `50L`. That is about the no-redraw rate 0.9^10 ≈ 0.35.
  - Failing expectation: `expect_identical(sum(is.na(b50)), 0L)`, skipped at `R/package_tests/testthat_bulk/test-ordinal-ridit-unweighted-scores-wald-and-fast-kernels-reference.R:179`.
  - Candidate fix (code): wire the redraw loop into the public non-KK bootstrap path, or delete the dead kernel and the parameter. Alternative (doc): say failed draws are NA and the parameter is unused.
  - Done when: fix it and remove the skip().

<a id="todo-113"></a>
<!-- pre-split-id: 1.0.6/259; 2026-11-25 -->

- [ ] TODO-113 (merged into v1.0.7-TODO-109 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d7661f482`): **`InferenceIncidWald` returns NA for an empty arm but never flags it non-estimable.**
  The docs (`R/EDI/R/inference_incid_wald.R:15`) say the class is non-estimable if either arm has zero subjects. With every subject treated, or every subject control, `compute_estimate()`, the CI and the p-value are NA as expected. But `is_nonestimable("estimate")` is FALSE and `get_nonestimable_reason()` is NULL. The cause is that `compute_incidence_wald_components()` (about lines 127-130) only sets `incidence_wald_se = NA` and never calls `cache_nonestimable_estimate()`.
  - Failing expectation: `expect_true(inf$is_nonestimable("estimate"))`, skipped at `R/package_tests/testthat_bulk/test-incid-wald-welch-ttest-dispatch-reference.R:118`.
  - Candidate fix (code): in the empty-arm branch, call `private$cache_nonestimable_estimate("incidence_wald_empty_arm")`. Alternative (doc): say "returns NA" rather than "non-estimable".
  - Done when: fix it and remove the skip().

<a id="todo-114"></a>
<!-- pre-split-id: 1.0.6/260; 2026-11-25 -->

- [ ] TODO-114 (merged into v1.0.7-TODO-109 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-dcb561000`): **KK g-computation incidence classes do not flag a failed fit or a missing treatment arm as non-estimable.**
  The docs of `InferenceIncidKKGCompRiskDiff` (`R/EDI/R/inference_incidence_KK_marginal.R:313-316`) say a working model that fails to converge, or a design with no treatment-arm variation, marks the estimate non-estimable via `is_nonestimable()`. `InferenceIncidKKGCompRiskRatio` makes the same promise at `:417`. Two things go wrong for both classes:
  - Failed fit: with `fit_logistic_with_sandwich` injected to return NULL, the estimate is NA but `is_nonestimable("estimate")` is FALSE and the reason is NULL. `set_failed_fit_cache()` (`R/EDI/R/inference_incidence_KK_gcomp_abstract.R:338`, called at :551) writes NA effects and never calls `cache_nonestimable_estimate()`.
  - All subjects treated (`DesignFixedBinaryMatch`, n = 20, seed 3): the estimate is finite (RD -0.163, RR 0.658) and not flagged. The design matrix has no treatment column, but the class still standardizes over the remaining columns.
  - Failing expectations: `expect_true(inf$is_nonestimable("estimate"))`, `expect_false(is.null(inf$get_nonestimable_reason()))`, and `expect_true(is.na(est))` for the all-treated design. One skip at `R/package_tests/testthat_bulk/test-rand-bootstrap-and-kk-gcomp-fallback-branches-reference.R:179` covers the whole block.
  - Candidate fix (code): `set_failed_fit_cache()` calls `private$cache_nonestimable_estimate(<reason>)`, and `shared()` marks the estimate non-estimable when `w` has no variation or the treatment column is missing from the fit.
  - Done when: fix it and remove the skip().

<a id="todo-115"></a>
<!-- pre-split-id: 1.0.6/261; 2026-11-25 -->

- [ ] TODO-115 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d3906c9d4`): **`InferenceSuite` fills `ci_method` even when `compute_conf_intervals = FALSE`.**
  The `compute_conf_intervals` param doc (`R/EDI/R/inference_suite.R:4956`) says ci_a, ci_b and ci_method "stay present but always NA in results_table". ci_a and ci_b are NA, but ci_method is "wald" or "rand" on every row. `run_all_inference_one_class()` back-fills it (`R/EDI/R/inference_suite.R:1843`, `if (is.na(row$ci_method)) row$ci_method = method`).
  - Failing expectation: `expect_true(all(is.na(tbl$ci_method)))`, skipped at `R/package_tests/testthat_bulk/test-run-all-inference-build-display-table-sorting-column-selection-and-ci-method-column-dropping-reference.R:89`.
  - Candidate fix: code (skip the back-fill when `compute_conf_intervals = FALSE`), or doc (say ci_method keeps the method label while ci_a and ci_b are NA).
  - Done when: fix it and remove the skip().

<a id="todo-116"></a>
<!-- pre-split-id: 1.0.6/262; 2026-11-25 -->

- [ ] TODO-116 (merged into v1.0.7-TODO-109 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-dccc6a08a`): **`InferenceCountPoisson` weighted refit with a non-finite treatment coefficient is not cached as non-estimable.**
  The method docs of `compute_estimate_with_bootstrap_weights` (`R/EDI/R/inference_count_poisson.R:456`) say a hardened weighted fit with a non-finite treatment coefficient "is cached as nonestimable and returns NA". With `fast_poisson_regression_weighted_cpp` mocked to return `b[2] = NA`, the estimate and `last_weighted_refit$s_beta_hat_T` are NA, but `last_weighted_refit$nonestimable` is FALSE and no reason is recorded. The code (about lines 461-512) sets the values to NA and never calls `cache_nonestimable_estimate()`.
  - Failing expectation: `expect_true(f$p$last_weighted_refit$nonestimable)`, skipped at `R/package_tests/testthat_bulk/test-count-poisson-deferred-fit-weighted-refit-and-estimand-switch.R:100`.
  - Candidate fix (code): call `private$cache_nonestimable_estimate(<reason>)` on that path. Alternative (doc): say it returns NA with an NA SE.
  - Done when: fix it and remove the skip().

<a id="todo-117"></a>
<!-- pre-split-id: 1.0.6/263; 2026-11-25 -->

- [ ] TODO-117 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d78c189b0`): **`InferenceOrdinalKKGLMM(use_rcpp = FALSE)` never fits: `glmmTMB::cumulative` does not exist.**
  The docs (`R/EDI/R/inference_ordinal_KK_combined.R:349`) say `use_rcpp = FALSE` fits via glmmTMB Laplace. `private$glmm_family()` (`:550`) calls `glmmTMB::cumulative(link = "logit")`, which the installed glmmTMB 1.1.14 does not export. Every fit prints "GLMM FIT ERROR: 'cumulative' is not an exported object from 'namespace:glmmTMB'", and the estimate is always NA. The documented `supports_likelihood_tests()` = FALSE part does hold.
  - Failing expectation: `expect_true(is.finite(est))`, skipped at `R/package_tests/testthat_bulk/test-ordinal-kk-glmm-deferred-fit-wald-likelihood-tests-and-polish.R:106`.
  - Candidate fix (code): fit the `use_rcpp = FALSE` path with `ordinal::clmm`, as the weighted helper already does. Alternative (doc): say the path is unavailable, and refuse `use_rcpp = FALSE` at construction.
  - Done when: fix it and remove the skip().

<a id="todo-118"></a>
<!-- pre-split-id: 1.0.6/264; 2026-11-25 -->

- [ ] TODO-118 (merged into v1.0.7-TODO-109 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d3a8c4d21`): **`InferencePropBetaRegr` weighted refit that fails is not cached as non-estimable.**
  The docs (`R/EDI/R/inference_proportion_beta.R:246-252`) say a hardened but still unreasonable weighted fit "is cached as nonestimable". With `fast_beta_regression_weighted_cpp` returning NaN coefficients and `stats::lm.wfit` failing, the refit returns NA, but `weighted_refit_is_nonestimable()` is FALSE and `last_weighted_refit$nonestimable_reason` is NULL. The failure branch (`:328-333`) only writes NA to `cached_values`, and `fit_ok` checks only finiteness, so there is no unreasonable-fit check at all.
  - Failing expectation: `expect_true(p$weighted_refit_is_nonestimable())`, skipped at `R/package_tests/testthat_bulk/test-prop-beta-regr-deferred-fit-boundary-responses-and-weighted-refit.R:77`.
  - Candidate fix (code): call `private$cache_nonestimable_estimate("weighted_refit_failed")` in that branch. Alternative (doc): say NA is returned and nothing is marked.
  - Done when: fix it and remove the skip().

<a id="todo-119"></a>
<!-- pre-split-id: 1.0.6/265; 2026-11-25 -->

- [ ] TODO-119 (merged into v1.0.7-TODO-109 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d412caeef`): **`InferencePropFractionalLogit` weighted refit that fails is not cached as non-estimable.**
  The docs (`R/EDI/R/inference_proportion_fractional_logit.R:180`) make the same promise as v1.0.7-TODO-118. With `fast_logistic_regression_weighted_cpp` mocked to return a NaN treatment coefficient, the refit returns NA for both `harden = FALSE` and `harden = TRUE`, but `weighted_refit_is_nonestimable()` is FALSE and the reason is NULL. The branch at `:216-220` never caches non-estimable.
  - Failing expectation: `expect_true(all(flagged))`, skipped at `R/package_tests/testthat_bulk/test-fractional-logit-weighted-coefficient-reference.R:92`.
  - Candidate fix (code): the same one-line fix as v1.0.7-TODO-118. Alternative (doc).
  - Done when: fix it and remove the skip().

<a id="todo-120"></a>
<!-- pre-split-id: 1.0.6/266; 2026-11-25 -->

- [ ] TODO-120 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d55fb24f7`): **`InferencePropGCompMeanDiff` public bootstrap ignores its screening arguments.**
  The docs (`R/EDI/R/inference_proportion_gcomp.R:261`, wrappers at `:268` and `:300`) say the screening arguments of `compute_bootstrap_two_sided_pval()` and `compute_bootstrap_confidence_interval()` reach the bootstrap-sample screen and are restored afterwards. The wrappers set `private$bootstrap_screening_control`, but the generic (`inference_all_abstract_non_param_boot.R:769` for the p-value, `:978` for the CI) calls `approximate_bootstrap_distribution_beta_hat_T(B, show_progress)`. That method overwrites the control with its own defaults (`inference_proportion_gcomp.R:353-359`). With n = 40 (20 per arm) and `min_group_n = n`, no resample can pass, yet the CI is finite, (0.111, 0.174), and the p-value is 0.105. Calling `approximate_bootstrap_distribution_beta_hat_T(min_group_n = n)` directly gives all-NA replicates, as expected. The restore part works.
  - Failing expectations: `expect_true(all(is.na(ci)))` and `expect_true(is.na(pval))`, skipped at `R/package_tests/testthat_bulk/test-proportion-gcomp-bootstrap-sample-screening-contract.R:109`.
  - Candidate fix (code): give `approximate_bootstrap_distribution_beta_hat_T`'s screening args a NULL default and override the control only when they are supplied, or have the wrappers pass them through.
  - Done when: fix it and remove the skip().

<a id="todo-121"></a>
<!-- pre-split-id: 1.0.6/268; 2026-11-25 -->

- [ ] TODO-121 (added 2026-11-20, agent; found fixing the bulk CI run 44616748908): **`InferenceContinRobustRegr`
  with `use_rcpp = FALSE` and the default `method = "MM"` returns a silent NA on an exact fit.** On a noise-free
  y = 3 + 2w (n = 40, one covariate x1 unrelated to y) `MASS::rlm(method = "MM")` errors ("incompatible dimensions",
  from its S-estimate start), `fit_rlm_model()` returns NULL, and `set_failed_fit_cache()`
  (`inference_continuous_robust_regr.R` ~L265) caches NA for the estimate with no nonestimable reason and no warning.
  `method = "M"` and the Rcpp backend both give 2 and `model_standard_error_unavailable` (the SE floor). Fix: record a
  nonestimable reason (and the usual warning) when every fit attempt fails, or fall back to an M start. The bulk test
  `test-continuous-robust-regr-se-floor-nonestimable-guard-reference.R` uses `method = "M"` for the rlm backend until
  then.

<a id="todo-122"></a>
<!-- pre-split-id: 1.0.6/270; 2026-11-25 -->

- [ ] TODO-122 (added 2026-11-20, coordinator; from the v1.1.0-TODO-218 verification): **Permuted-block jackknife with
  few units per stratum is oversized.** Since 72ea20ba (v1.0.6-TODO-165 (3)) `DesignSeqOneByOneRandomBlockSize`
  resolves the automatic jackknife unit to "permuted_block", like SPBR. With few permuted blocks per stratum the
  jackknife-Wald test is too liberal: InferenceCountPoisson, RandomBlockSize, prob_T 0.2, n = 200, `~1` has size
  0.082 [0.066, 0.101] (16-20 deletion units, 3-4 in the smallest stratum), against 0.055 with the
  "observation_within_block" unit; SPBR is about 0.061 pooled over 3000 reps.
  - Decided 2026-11-20 (owner): option (a), switch to "observation_within_block" below ~5 blocks per stratum; see [DECISION-v1.0.6-TODO-270a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-270a).
  Fix: in `resolve_jackknife_unit("auto")` (`inference_all_abstract_non_param_boot.R`), when any stratum has fewer than
  about 5 permuted-block units, use "observation_within_block" (delete one subject within its stratum, Wolter 2007
  Sec. 4.5) instead. Shared code, so it affects every
  class that uses the automatic unit. Done when: the threshold is a named constant, documented in the jackknife docs
  and NEWS ("Changes that alter results"), tested, and the RBS / SPBR cells above are nominal within MC error.
  Status 2026-11-20 (agent, uncommitted; R only, no build). Implemented: `resolve_jackknife_unit("auto")`
  (`inference_all_abstract_non_param_boot.R`) on SPBR and RandomBlockSize builds the permuted-block layout and returns
  "observation_within_block" when any stratum has fewer than `EDI_JACKKNIFE_MIN_PERMUTED_BLOCKS_PER_STRATUM` (5L, next
  to `EDI_JACKKNIFE_MIN_DELETION_UNITS` in `inference_all_abstract_jackknife.R`) units; explicit units unchanged. Also:
  RandomBlockSize without `strata_cols` can now reach that unit, and its `get_block_ids()` errors ("'length.out' must
  be of length 1"), so `jackknife_stratified_layout()` puts all subjects in one stratum there (was a silent fall-back
  to the plain "observation" unit with the normal reference). Cache keys are the resolved unit already
  (`jackknife_cache_key()`); InferenceCountPoisson's `use_within_block_jackknife_fallback()` needs "block", so it does
  not fire on these designs (tested). Docs: InferenceJackknife, SPBR, RandomBlockSize, InferenceCountPoisson roxygen
  + hand-edited Rd (checkRd clean apart from old non-ASCII notes), REFERENCES.md, NEWS. Tests: new
  testthat_bulk/test-jackknife-auto-unit-few-permuted-blocks-per-stratum-deletes-subjects.R (52 pass; 4 vs 5 blocks
  on SPBR and RBS, partial-block stratum, random sizes, no strata, Poisson); two SPBR layout tests in
  test-jackknife-stratified-units-spbr-and-fixed-blocking.R now ask for unit = "permuted_block" explicitly (their
  fixture has 2-3 blocks per stratum). Related jackknife tests and the call-graph acceptance test pass.
  Size (null, n = 200, prob_T 0.2, ~1, calibration DGP/seeds; 95% Clopper-Pearson):
  Poisson RBS reps 1-1500: class 0.050 [0.040, 0.062]; jackknife-Wald auto 0.051 [0.040, 0.063], explicit
  permuted_block 0.060 [0.049, 0.073]; switch fired in 95% of reps (smallest stratum 2-6 blocks); CI coverage 0.949.
  Poisson SPBR reps 1001-2000: 0.062 [0.048, 0.079], unchanged (smallest stratum 6-10 blocks, switch never fires;
  with reps 1-1000 at 0.063 the 2000-rep pool is ~0.062 [0.052, 0.074]); obs_within_block there 0.055 [0.042, 0.071].
  OLS (InferenceContinOLS) RBS reps 1-1000: jackknife-Wald auto 0.034 [0.024, 0.047] (permuted_block 0.044
  [0.032, 0.059]); CI coverage 0.966, so slightly conservative, not broken. Note: with the v1.0.6-TODO-165 (6) t
  reference already in, the permuted-block size on the RBS cell is 0.060, not the 0.082 measured before it.
  NOT ticked: the RBS cell is nominal, but the SPBR cell stays at ~0.062 (this change does not reach it, since SPBR has
  8-9 blocks per stratum).
  - Owner decision pending: [DECISION-v1.0.6-TODO-270](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-270) (SPBR at 0.062: accept, raise the threshold, or investigate SPBR separately?).

<a id="todo-123"></a>
<!-- pre-split-id: 1.0.6/283; 2026-11-25 -->

- [ ] TODO-123 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-134 agent; needs a wheel rebuild): **Python
  `fast_beta_regression` returns `neg_loglik = nan`.** Same pattern as v1.0.6-TODO-134: the binding reads
  `ModelResult.neg_ll`, which `R/EDI/src/fast_beta_regression.cpp` never sets (R computes `$neg_loglik` separately).
  `python/tests/test_fast_beta_regression.py` documents it as "not a binding bug"; fix the binding (or set `neg_ll` in
  the kernel), pin the value against R, and drop that note.

<a id="todo-124"></a>
<!-- pre-split-id: 1.0.6/321; 2026-11-25 -->

- [ ] TODO-124 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-156 agent): **Cumulative-link ordinal warm start
  is overwritten.** In the four cumulative-link classes (PropOdds, OrderedProbit, Cauchit, Cloglog),
  `standard_model_cache_shared()` replaces the full warm start that `generate_mod()` just stored with
  `b = c(0, beta_T)` and no information matrix, so later refits (bootstrap, randomization, CI inversion) never get a
  full-length warm start. Check whether this costs iterations or changes any refit's optimum, and keep the full start.

<a id="todo-125"></a>
<!-- pre-split-id: 1.0.6/322; 2026-11-25 -->

- [ ] TODO-125 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-117 / v1.0.6-TODO-118 agent): **ZINB with a large-scale
  zero-inflation covariate, and the unprobed users of the new convergence rule.** (1) ZINB with a covariate at x 1000 in
  the zero-inflation design gives -0.042 vs pscl -0.2125 (0 at + 1e5) on `colon`: the zero part saturates, its Hessian
  block is 0, so the new Newton-decrement rule cannot finish the fit and the old verdict stands. (2) ZIP / hurdle, ZOIB,
  the GLMMs, Weibull frailty and CLMM share the patched wrapper in `_helper_functions_core.h` but were not re-probed
  (hurdle NegBin cannot be kernel-swapped alone); probe them on raw / x 1000 / + 1e5 designs after the owner build.
  (3) Poisson and probit L-BFGS on raw `colon` still report not converged at the default 100-iteration cap.
  (4) (coordinator 2026-11-21, from the beta/ZINB reference-check agent) ZINB on raw `colon` (Xzi = intercept,
  treatment, age) reports converged under the patched kernels but stops at negLL 1252.196; pscl and the same kernel on
  `scale()`d X reach 1250.054. Its treatment coefficient (-0.2111 vs pscl -0.2126) is close only by luck. The reference
  check in `test-count-probit-kernels-scale-aware-convergence-colon.R` uses tolerance 3e-3; tighten it once this is fixed.

<a id="todo-126"></a>
<!-- pre-split-id: 1.0.6/325; 2026-11-25 -->

- [ ] TODO-126 (added 2026-11-21, agent, owner request; found by the issue #66 review): **`R CMD check` hangs in
  "checking examples" on Windows.** Both Windows legs hit the 240-min job timeout on f49c200b (run 44636521403), and
  Windows devel again on 8d8c5f78 (run 44749244495). In the job logs (135956486361, 136332700594) `EDI-Ex.Rout` stays
  at 0 bytes after `* checking examples ...` starts, and the Rterm processes use about 1 min of CPU in 3+ hours: blocked
  (a deadlock or wait), not slow. Windows still finished in 56-90 min on e16dd7ae, so the cause is in the 18 commits of
  e16dd7ae..f49c200b. Candidate, not bisected: 91b4d62f changed the `InferenceSuite` `\donttest` example to
  `run_all_inference(methods = c("wald", "rand"), r = 99)` (compare the earlier Windows `\donttest{}` hang,
  release_v1_0_0.md:541); other R changes in the window are 72ea20ba, 5bdb9dfb and f4f0c7aa. (1) Make the next hang name
  its example: the Windows `EDI-Ex.Rout` is locked and empty, so have the check leg write each example's name to stderr
  (or run the examples with unbuffered output) and add a step timeout well under 240 min. (2) Bisect the window on a
  Windows leg and fix the example or the code it reaches (look first at parallel / fork / daemon paths, which differ on
  Windows). Done when both Windows legs finish `R CMD check` in under ~90 min again. Costs ~3 h of runner time per
  Windows leg per push until fixed.

<a id="todo-127"></a>
<!-- pre-split-id: 1.0.6/329; 2026-11-25 -->

- [ ] TODO-127 (added 2026-11-21, agent, owner request; audit decision `code-duplication-db5595975`; low priority):
  **The unweighted log- and identity-binomial kernels ignore `warm_start_weights`.** `fit_constrained_binomial_cpp_impl`
  (`R/EDI/src/fast_log_binomial_regression.cpp:520-810`) never reads the argument and doesn't check its length; the
  weighted implementation uses it (L857-873) and the roxygen promises "initial working weights". Fitted values don't
  change and no R class passes it. Fix: port the weighted path's iteration-0 block and length check, or document the
  argument as unused and add the length check. Test: a wrong-length vector errors. [C++]

<a id="todo-128"></a>
<!-- pre-split-id: 1.0.6/330; 2026-11-25 -->

- [ ] TODO-128 (added 2026-11-21, agent, owner request; mechanical findings `rd-m2fa7c1c1`, `rd-m362b49ad`,
  `rd-m3ca40610`, `rd-m6949d76a`, `rd-m77d445ee`, `rd-m7f2798f2`, `rd-m8e01cb35`, `rd-m8e01cb35-2`, `rd-m9706d359`,
  `rd-ma957805a`, `rd-maa4ffcbb`, `rd-maa4ffcbb-2`, `rd-mafc40b7d`, `rd-meda604bf`, `rd-mff4a0118`): **The
  `InferenceCountZeroInflatedPoisson`, `...ZeroInflatedNegBin`, `...HurdlePoisson`, `...HurdleNegBin` and
  `InferenceIncidGCompRiskRatio` examples emit separation or boundary warnings**, also on the published reference
  pages. Choose n, data or a seed so the zero / hurdle part isn't separated on any of the rd audit's 5 seeds, keeping
  each example under 4 s. Done when the rd audit's example check is clean for these classes.

<a id="todo-129"></a>
<!-- pre-split-id: 1.0.6/334; 2026-11-25 -->

- [ ] TODO-129 (added 2026-11-21, agent, owner request; audit decision `docs-claims-d70b0515c`, claim 2): **Test
  `InferenceRandCustom`'s parallel-path contract.** The docs (`R/EDI/R/inference_rand_custom.R:84-86`) say a C++
  source string works on parallel paths while an external pointer or pre-compiled Rcpp function is valid in the main
  process only. No test checks either half, and both worker-count invariance helpers skip this class. Test: with a
  source-string statistic, `compute_rand_two_sided_pval()` under `set.seed()` is identical for `num_cores = 1` and
  `2`; with an external pointer or pre-compiled function, pin whatever the parallel path does (clear error or
  main-process fallback), and fix the docs if it differs. Test only.

### Docs-scenario findings, run 44883784401, 2026-11-21
The docs-scenario audit (run 44883784401, merged as PR #78) followed the inference-suite, save-load,
simulation-framework, observational, incidence, count, ordinal and proportion articles and help pages against installed
1.0.4. Findings and repros: `R/package_metadata/audits/docs_scenario_findings/2026-11-21-run44883784401.md`; "Repro:
<area> F<k>" below names the block in that file. Each was re-checked on HEAD (779dc92c..6ed95ff3) on 2026-11-21 by
reading the code, most also by a small repro under `load_all(compile = FALSE)`. Findings an existing entry covers are
cited there: observational f1 (v1.0.6-TODO-185), incidence f7 (v1.0.7-TODO-76). Fixed or invalid ones are in
`R/package_metadata/audits/DISMISSED_DECISIONS.md` (observational f5-f8, fixed in ba1c3988; incidence f4, fixed in
ca01dd4b under v1.0.6-TODO-191; proportion f8, by design).

<a id="todo-130"></a>
<!-- pre-split-id: 1.0.6/338; 2026-11-25 -->

- [ ] TODO-130 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`max_secs_per_class` at
  1 core and the inherited `set_num_cores()` cluster in forked suite workers.**
  Ids: ds-inference-suite-44883784401-f3, ds-inference-suite-44883784401-f11, ds-observational-44883784401-f3.
  (1) At 1 core the suite uses `setTimeLimit(elapsed =, transient = TRUE)` (`R/EDI/R/inference_suite.R:1692-1693`):
  a limit that fires inside a per-draw `tryCatch` is swallowed, so a 69 s ZINB is reported `ok` at a 2 s limit, and
  one that fires in native code halts Rscript past every handler. b9a3519e (v1.0.6-TODO-179) fixed only the fork
  path; its "found, not changed" note recorded this. (2) After `set_num_cores(2)`, forked children inherit the
  socket cluster; `configured_worker_fn` in `run_all_inference_fork_dispatch()` (`inference_suite.R:~1535`) resets
  only the thread env vars, so a child's randomization p-value fails with "ignoring SIGPIPE signal" while the row
  stays `ok`, and later direct calls in the parent fail too. Fix: when `max_secs_per_class` is set, run every task
  through the fork dispatcher with kill-by-PID, also at 1 core; in a child, drop the inherited cluster handle without
  closing the parent's sockets and run inner work serially; a failed p-value never leaves status `ok`. Done when:
  the inference-suite F3 repro returns timeout rows and never reaches an outer `tryCatch`, and the F11 and
  observational F3 repros give the same p-values as at 1 core with a working direct call afterwards.

<a id="todo-131"></a>
<!-- pre-split-id: 1.0.6/339; 2026-11-25 -->

- [ ] TODO-131 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Suite rows for skipped,
  refused or misspelled procedure types look like successes.**
  Ids: ds-inference-suite-44883784401-f1, ds-inference-suite-44883784401-f4, ds-inference-suite-44883784401-f7.
  With `compute_conf_intervals = FALSE`, CI-only bootstrap types (`basic`, `calibrated`, ...) still get rows with
  `pval = NA`, method columns filled, `status = "ok"`, no message: `inference_suite.R:1022` (and the CI twin ~L925)
  returns `method = entry$label` instead of NA, and `:1846-1847` back-fills both method columns (v1.0.7-TODO-115 is
  the `ci_method` half of this; fix both together and remove that TODO's skip). A misspelled type
  (`bootstrap = "percentil"`) passes `intersect()` at `:542` as zero types, builds a `type = NA` task (`:1255-1258`)
  and runs the default flavour, `ok`. A refused rand CI (QuasiPoisson/RobustPoisson lose `randomization_ci` on count,
  registry `:208-225`) returns `method = NA` at `:900`, back-filled to "rand", no message. Fix: don't build tasks for
  a side that is turned off; error in `run_all_inference()` on a type outside the known vocabularies, listing them
  (as for sentinels, ~L5116); put the refusal reason in `message` for a capability the class refuses here. Done
  when: the three repros give no row or an NA-method row with a message, and a typo errors naming the valid types.

<a id="todo-132"></a>
<!-- pre-split-id: 1.0.6/340; 2026-11-25 -->

- [ ] TODO-132 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Count estimand tags and the
  QuasiPoisson/RobustPoisson randomization-CI scale.**
  Ids: ds-inference-suite-44883784401-f2, ds-inference-suite-44883784401-f8.
  `EDI_INFERENCE_ESTIMAND_TAGS` (`R/EDI/R/inference_class_registry.R:1621-1634`) tags Poisson, Quasi, Robust, NegBin,
  ZIP and HurdlePoisson `log_rate_ratio_marginal` but HurdleNegBin and ZINB `log_rate_ratio_conditional`, while every
  object reports `get_estimand() == "conditional"`; Combined Evidence groups by these tags.
  `inference_model_scale_randomization_transform_for()` (`R/EDI/R/inference_all_abstract_rand_ci.R:21-31`) does not
  count Quasi/RobustPoisson as model-scale, so their rand-CI refusal says the estimate "is on the raw response scale"
  (false: it is the same log rate ratio as Poisson, whose rand CI works), and the message appends an internal TODO
  path (`inference_all_abstract_rand_ci.R:360-361`, `inference_class_registry.R:325`). Fix (the tags: owner
  decision below): treat Quasi/Robust as model-scale; drop the path from the message (see also
  v1.0.5-TODO-119's note). Done when: a test asserts every count class's tag agrees with `get_estimand()`, the Quasi
  rand CI is finite, and no user-facing message contains "package_metadata".
  - Owner decision pending: [DECISION-v1.0.6-TODO-340](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-340) (retag the GLM / count-part coefficients `log_rate_ratio_conditional`, or keep the current tags?).

<a id="todo-133"></a>
<!-- pre-split-id: 1.0.6/341; 2026-11-25 -->

- [ ] TODO-133 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Suite print and Combined
  Evidence: row-vs-class counts, single-inference groups, the 1e-4 Cauchy floor, mangled numbers.**
  Ids: ds-inference-suite-44883784401-f5, ds-inference-suite-44883784401-f6, ds-inference-suite-44883784401-f9,
  ds-ordinal-44883784401-f10.
  (1) The print header uses `nrow(results_table)` as "class(es)" (`inference_suite.R:5529`), `summary()` mixes
  class and row counts (~L5577), and `n_used` counts zero-weight rows (`:4286`, footer `:4315`). (2) A group of one
  prints `p = NA` because `run_all_inference_combine_pvalues()` returns NA for n < 2 (`:4287`), though that p enters
  the overall combination. (3) The Cauchy combination clips every p to [1e-4, 1 - 1e-4] (`pval_eps`, `:4273`,
  `:4290`), so the combined p (1.05e-4) exceeds 19 of the 21 inputs; the floor is not in `?InferenceSuite`. (4) Long
  numbers are hard-wrapped with a hyphen (`:2051-2066`): `-4.22e-06` prints as `-4.22e--` / `06`. Fix: print
  "k rows / m classes" and label row counts; `n_used` counts weight > 0; a one-row group shows its own p; clip only
  the upper end (or eps ~1e-300; CCT is stable for small p) or document the floor; never wrap numeric cells. Done
  when: the F5 repro shows the right counts, a one-row group prints its p, `combined_evidence$pval` matches the
  Liu-Xie formula on the ordinal F10 table to 1e-8, and a wrap test on "-4.22e-06" gives one intact cell.

<a id="todo-134"></a>
<!-- pre-split-id: 1.0.6/342; 2026-11-25 -->

- [ ] TODO-134 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **The suite drops a valid
  exact p-value and CI when only the estimate is non-estimable, and keeps separated fits at full weight.**
  Ids: ds-incidence-44883784401-f9.
  `inference_suite.R:1759-1771` sets the row to "nonest" on any `is_nonestimable("any")`, discarding
  `InferenceIncidExactFisher`'s exact p (6.26e-05) and CI on zero-cell data (its `nonestimable_stage` is
  "estimate"), while GComp RR (p = 0, CI 2.7e-10 to 7.6e-10) with its own separation warning stays `ok` at full
  weight. Fix: keep the p/CI cells a class still returns when only the estimate stage is non-estimable; treat rows
  that raised a separation/boundary warning as the owner decides (below). Done when: on the incidence F9
  repro the Fisher row carries its p and CI and the separated rows do not enter the combination at full weight.
  - Owner decision pending: [DECISION-v1.0.6-TODO-342](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-342) (down-weight or exclude suite rows that raised a separation / boundary warning?).

<a id="todo-135"></a>
<!-- pre-split-id: 1.0.6/343; 2026-11-25 -->

- [ ] TODO-135 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **User-facing help names
  unexported objects and internal developer files.**
  Ids: ds-inference-suite-44883784401-f10, ds-observational-44883784401-f4.
  `?InferenceSuite` sends users to the unexported `EDI_INFERENCE_SUITE_METHOD_SENTINELS`,
  `is_inference_class_compatible_with_design_metadata()`, `infer_inference_requires_blocking_design()` and
  `inference_class_registry.R` (`inference_suite.R:4432,4451,4790`). Roxygen on the observational path cites
  `fix_design_hierarchy.md`, internal TODOs and `draw_ws_raw()`: `design_observational.R:84-88`,
  `design_abstract.R:660-662,768,796`, `design_fixed_binary_match.R:54`, `design_fixed_greedy.R:79`,
  `design_fixed_greedy_d_optimal.R:159`, `design_class_registry.R:4`, `design_component_registry.R:3`,
  `design_class_factory.R:4`. Fix: list the sentinels inline (or export a getter), rewrite the `#'` lines to stand
  alone and keep internal pointers in `#` comments. This extends v1.0.7-TODO-80 (which covers message strings) to
  roxygen. Done when: a source test fails on any `#'` line naming `package_metadata`, an internal `.md` or
  `TODO-<n>`, and `man/InferenceSuite.Rd` names no unexported identifier.
  2026-11-22 (coordinator): the vignette part is done in commit 2bc1e336 (v1.0.6-TODO-224): a grep of
  `vignettes/` and `vignettes/articles/` for `ROADMAP.md`, `R/package_metadata/` and `release_v` found two links to
  unshipped repo files, `cookbook-count.Rmd` (`ROADMAP.md`) and `extending-edi.Rmd`
  (`R/package_metadata/contracts/new_model_creation.md`); both now link to the GitHub copies. The roxygen part
  stays open.

<a id="todo-136"></a>
<!-- pre-split-id: 1.0.6/344; 2026-11-25 -->

- [ ] TODO-136 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`InferenceCountRobustPoisson`
  returns a named estimate and p-value (`"treatment"`).**
  Ids: ds-inference-suite-44883784401-f12.
  `R/EDI/R/inference_all_abstract_count_likelihood.R:138` keeps the name of RobustPoisson's named `b_full`
  (`inference_count_robust_poisson.R:249`); every other count class returns unnamed numbers. Fix: `as.numeric(...)[1L]`
  as in `inference_all_abstract_asymp_lik_std_mod_cache.R:264`, same on the p-value path. Done when: a test over
  all count classes asserts `is.null(names())` on the estimate, CI and p-value.

<a id="todo-137"></a>
<!-- pre-split-id: 1.0.6/346; 2026-11-25 -->

- [ ] TODO-137 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`get_summary()` SEs disagree
  with the Wald SE for ZIP, HurdlePoisson and KK GLMM, and are all NA for HurdleNegBin.**
  Ids: ds-count-44883784401-f2, ds-count-44883784401-f3, ds-count-44883784401-f5.
  ZIP/HurdlePoisson build the summary from the model-based `fit$vcov`
  (`R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:349-366`) while `compute_asymp_*` use a sandwich (SE
  0.3407 vs 0.5518, p 0.093 vs 0.299). `InferenceCountHurdleNegBin` (`inference_count_hurdle.R:375+`) caches no
  `full_vcov`/`summary_table`, so every SE is NA, the hurdle part is missing and the labels differ. KK GLMM: the Wald
  docs were fixed in 83e092b7 (rd-dc6614af5: the larger of model and jackknife SE), but `get_summary()` still shows a
  different SE from the one its Wald CI uses, depending on `use_rcpp`. Fix: fill the summary SE from the vcov the
  Wald path uses (or label the column) and cache HurdleNegBin's count/hurdle coefficients with `conditional:` /
  `hurdle:` names; relates to v1.1.0-TODO-56 items 2-3. Done when: for these four classes the summary's treatment SE
  equals the SE implied by the asymptotic CI and HurdleNegBin's labels match HurdlePoisson's.

<a id="todo-138"></a>
<!-- pre-split-id: 1.0.6/348; 2026-11-25 -->

- [ ] TODO-138 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Testing types are listed as
  supported, then refused or answered with "no error message was recorded".**
  Ids: ds-count-44883784401-f6, ds-incidence-44883784401-f5.
  `InferenceCountKKGLMM$get_supported_testing_types()` lists `lik_ratio_bartlett_approx`
  (`R/EDI/R/inference_all_abstract_asymp_lik.R:552-565`) but its `compute_asymp_*` switch
  (`inference_count_KK_combined.R:~208-236`) has no case: "Unsupported testing_type". On `InferenceIncidLogRegr` the
  public `compute_lik_ratio_bartlett_exact_*()` run although `supports_bartlett_likelihood_ratio_exact()` is FALSE
  (`inference_all_abstract_asymp_lik.R:288-303`) and return NA with the fallback text "no error message was recorded"
  (`helper_robust_sandwich.R:366-369`); the bad-value error of `set_testing_type()` lists all six types
  (`normalize_testing_type()`, `:601`) though `:98-108` then refuses bartlett_exact. The ordinal PO/cloglog classes
  show the same exact-Bartlett NA. Fix: add the bartlett_approx cases to KK GLMM; make the exact methods return NA
  with a specific reason (or error) when unsupported; list only `get_supported_testing_types_with_bartlett()` in the
  error. Done when: every class's listed testing types all run through `compute_asymp_*`, and the LogRegr exact
  warning names the real reason.

<a id="todo-139"></a>
<!-- pre-split-id: 1.0.6/349; 2026-11-25 -->

- [ ] TODO-139 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`capabilities()` /
  applicability promise procedures the design refuses (randomization on `ObservationalDesign`, CMH's SE, the
  bootstrap on KK sequential designs).**
  Ids: ds-observational-44883784401-f2, ds-observational-44883784401-f12, ds-save-load-44883784401-f1.
  `get_design_excluded_inference_capabilities()` (`R/EDI/R/inference_class_registry.R:2800-2808`) excludes by the
  `DesignSeqOneByOne` class name only and never asks `supports_randomization_draw()`, so on `ObservationalDesign`
  `supports()` says TRUE for randomization test/CI/bootstrap, which then refuse. `InferenceIncidCMH`'s non-blocking SE
  path draws `w` (`inference_incidence_cmh.R:~197-211`) and hits the observational `draw_ws_raw()` stop
  (`design_observational.R:110-112`), though CMH is listed as applicable. On KK14/KK21 the bootstrap stops with "This
  method is not supported for DesignSeqOneByOne designs" (`inference_class_registry.R:2850-2858,2878`; intended, 1b2f1c74),
  but the KK help's method table lists it and the message names neither the method nor the class. Fix: exclude the
  randomization capabilities when `!supports_randomization_draw()`; mark CMH incompatible there (or cache a
  non-estimable SE with a classed warning); name the method, the class and the Bernoulli exception in the refusal and
  note the restriction in the KK table. Sibling of v1.0.7-TODO-76. Done when: on `ObservationalDesign*` `supports()`
  is FALSE for these and TRUE on Bernoulli, CMH is absent or NA-with-warning, and the KK14 error names the method
  and "DesignSeqOneByOneKK14".

<a id="todo-140"></a>
<!-- pre-split-id: 1.0.6/353; 2026-11-25 -->

- [ ] TODO-140 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`SimulationFramework` docs:
  `w` coding, a missing `get_errors()`, and what `$run()` returns.**
  Ids: ds-simulation-framework-44883784401-f1, ds-simulation-framework-44883784401-f2,
  ds-simulation-framework-44883784401-f3.
  `R/EDI/vignettes/notation-glossary.Rmd:41` says hooks get `w` in {-1,+1} and suggests `(w+1)/2`; they get {0,1}
  (`?SimulationFramework`, `simulations_framework.R:495,509`; the internal comment at `:3178-3180` is also wrong). The
  `stop_on_error` doc (`:598-603`) says to call `$get_errors()`, which only `SimulationFrameworkReport` has. The
  `$run()` description (`:848-853`) says it returns a `SimulationFrameworkReport`, while `@return` and the code
  (`invisible(self)`, `:1236,1972`) return the framework. Fix the three texts (or add a thin `get_errors()`). Done
  when: a test asserts the hook sees `w` in {0,1}, the documented error call works, and the `$run()` Rd agrees with
  itself.

<a id="todo-141"></a>
<!-- pre-split-id: 1.0.6/355; 2026-11-25 -->

- [ ] TODO-141 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`SimulationFramework`
  constructor accepts bad `alpha` / `sd_noise` and hides a design constructor's own error.**
  Ids: ds-simulation-framework-44883784401-f6, ds-simulation-framework-44883784401-f7,
  ds-simulation-framework-44883784401-f8.
  `alpha` is stored unchecked (`R/EDI/R/simulations_framework.R:755`; a later base-R check complains about `'p'`) and
  0 gives infinite CIs with coverage NA; a negative `sd_noise` (`:759`) fails later with a missing-outcomes message
  (note `:3904` treats `sd_noise <= 0` as zero noise for ordinal). A design parameter the constructor rejects is
  swallowed by `tryCatch(private$.build_design(...), error = function(e) NULL)` (`:2802-2806`) and reported as a
  design/inference compatibility warning (`:2840-2850`), even with `stop_on_error = TRUE`. Fix: validate
  `alpha` in (0, 1) and `sd_noise >= 0` at `$new()` naming the argument; keep the caught condition and show it (stop
  under `stop_on_error = TRUE`). Done when: alpha 0 / 1.5 / NA and `sd_noise = -1` error at `$new()`, and
  `list(DesignFixediBCRD = list(foo = 1))` with `stop_on_error = TRUE` errors with "unused argument (foo = 1)".

<a id="todo-142"></a>
<!-- pre-split-id: 1.0.6/358; 2026-11-25 -->

- [ ] TODO-142 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`DesignFixedBinaryMatch`
  accepts a `w_precomputed` that does not treat exactly one member of each pair.**
  Ids: ds-observational-44883784401-f9.
  The override (`R/EDI/R/design_fixed_binary_match.R:176-179`) builds the pairs and delegates; ba1c3988's
  `validate_w_precomputed()` checks clusters but not pairs, so a within-pair randomization test runs on a pair with
  two treated and one with none. Fix: after the pairs exist, error naming the first offending pairs (the
  v1.0.6-TODO-188 cluster-check pattern); consider `ObservationalDesignMatching` too. Done when: the observational F9
  repro errors and a valid one-per-pair `w` is stored unchanged.

<a id="todo-143"></a>
<!-- pre-split-id: 1.0.6/359; 2026-11-25 -->

- [x] TODO-143 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Blocking/BCa text in the *(ticked by the TODO audit 2026-11-25 as v1.0.6-TODO-359: R/EDI/R/design_fixed_blocking.R:222; R/EDI/R/design_fixed_blocking.R:91; R/EDI/vignettes/articles/analyzing-an-existing-experiment.Rmd:351; R/EDI/vignettes/articles/analyzing-an-existing-experiment.Rmd:146)*
  existing-experiment article and `?DesignFixedBlocking` doesn't match the code.**
  Ids: ds-observational-44883784401-f10, ds-observational-44883784401-f11.
  With unequal strata and `equal_block_sizes = TRUE` the error comes at the first bootstrap/randomization call
  (blocks form lazily, `R/EDI/R/design_blocking_abstract.R:~290-325`), not "when subjects are added" (`@param`,
  `design_fixed_blocking.R:210-218`), "at `assign_w_to_all_subjects()`" (Details, L88-93) or "an inference fit"
  (`vignettes/articles/analyzing-an-existing-experiment.Rmd:350-353`). The same article (`:145-148`) says BCa is NA
  with 4 sites; since v1.0.6-TODO-1 / v1.0.6-TODO-165 the jackknife unit is `observation_within_block` and BCa is finite. Fix:
  preferably check equal sizes eagerly at the end of `add_all_subjects_to_experiment()` when the blocks are fixed by
  then; otherwise make the three texts name the real step; rewrite the BCa sentence. Done when: the F10 repro errors
  at the documented step, and help, article and chunk output agree.

<a id="todo-144"></a>
<!-- pre-split-id: 1.0.6/360; 2026-11-25 -->

- [ ] TODO-144 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Rd pages: constructor
  arguments that `$new()` rejects, and a stale risk-ratio scale note.**
  Ids: ds-incidence-44883784401-f1, ds-incidence-44883784401-f10, ds-ordinal-44883784401-f4.
  Members pinned as `name = OtherClass$public_methods$name` spill their `@param` tags into the next method's Arguments:
  `?InferenceIncidWald` documents `alpha`, `delta` (`inference_incid_wald.R:78-85` -> `man/InferenceIncidWald.Rd:183-185`)
  and `?InferenceIncidRiskDiff` `r`, `delta`, `type`, `permutations`, ... (`inference_incidence_risk_diff.R:65-75`),
  which `$new()` rejects; the pattern is in ~75 files. PO, cloglog, probit and cauchit document their constructors in
  `#` not `#'` comments (`inference_ordinal_proportional_odds.R:10-18`, `inference_ordinal_cauchit.R:~10-17`,
  `inference_ordinal_cloglog.R:~57-64`, `inference_ordinal_ordered_probit.R:~8-14`), so users see `Inference$new()`'s
  `harden`/`seed`, which they reject. The risk-ratio scale note was fixed in roxygen by f6d20e4d but
  `man/InferenceIncidLogRegr.Rd:35` was not regenerated, and LogBinomial (`:699`) / ModifiedPoisson (`:385`) don't
  point to GCompRiskRatio's ratio scale. Fix the roxygen, regenerate the Rd. Done when: a package-wide check that
  every `$new()` Arguments entry appears in its Usage passes, and all four risk-ratio pages name both scales.

<a id="todo-145"></a>
<!-- pre-split-id: 1.0.6/361; 2026-11-25 -->

- [ ] TODO-145 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Flagged non-estimable fits
  return NA (or a 0 estimate) with no warning.**
  Ids: ds-incidence-44883784401-f2, ds-incidence-44883784401-f6, ds-ordinal-44883784401-f8.
  `InferenceIncidLogBinomial` with a zero-event arm returns all NA with reason `model_fit_unavailable`
  (`inference_all_abstract_asymp_lik_std_mod_cache.R:260`), no warning; the KK conditional-logit OneLik
  (`inference_incidence_KK_cond_logit.R:298`, `extreme_treatment_coefficient`) and GLMM
  (`inference_incidence_KK_cond_logit_glmm_abstract.R:335,616`) classes do the same on matched pairs with no treated
  events. With every patient in one category, `InferenceOrdinalRidit` returns 0 / NA / NA with `is_nonestimable()`
  FALSE (`inference_ordinal_ridit.R:259-290`, in v1.0.7-TODO-109's scope), and `InferenceOrdinalPropOddsRegr` is
  flagged but reports an estimate of 0. Fix: the v1.0.6-TODO-191 convention package-wide: one classed
  `edi_procedure_na_warning` per object (outside resampling) naming the reason, raised from the shared non-estimable
  path (`cache_nonestimable_estimate()`, `inference_all_abstract.R:~1003`), with advice (exact Fisher / risk
  difference for a zero arm); Ridit flags `ordinal_single_category`; cumulative-link classes return NA when y has
  < 2 levels. Done when: each repro warns once and returns NA with `is_nonestimable()` TRUE.

<a id="todo-146"></a>
<!-- pre-split-id: 1.0.6/362; 2026-11-25 -->

- [ ] TODO-146 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Separation not detected:
  ModifiedPoisson, KK IVWC / KKModifiedPoisson, cumulative-link ordinal, and LogRegr parametric-bootstrap replicates.**
  Ids: ds-incidence-44883784401-f3, ds-incidence-44883784401-f8, ds-ordinal-44883784401-f9.
  `InferenceIncidModifiedPoisson` on zero-cell data gives log RR -22.3, CI (-22.85, -21.80), p = 0 with no boundary
  warning (`inference_incidence_modified_poisson.R:320`; KKModifiedPoisson similar, and KK cond-logit IVWC in
  incidence F6 gives a CI of about +/-21 500, unflagged). `InferenceOrdinalPropOddsRegr` under quasi-complete
  separation gives -14.81, CI +/-400, no flag, and its LR CI is NA with no warning (the ticked
  v1.0.6-TODO-63 / v1.0.6-TODO-72 / v1.0.6-TODO-73 / v1.0.6-TODO-76 covered logit, probit and KK GEE only). `InferenceIncidLogRegr`'s parametric bootstrap
  keeps near-separated replicates (log OR ~ -25): the bias-corrected estimate flips -2.23 to +1.03, CI upper bound
  +21, `n_extreme = 0` (`inference_ext_param_bootstrap_estimate.R:52-62,120-133`, threshold 50). Fix: detect an arm
  with all-zero fitted means / fitted probabilities 0 or 1 (helpers `helper_robust_sandwich.R:~751`), raise the
  separation warning and `cache_nonestimable_se()`; count separated bootstrap refits in `n_extreme` via a per-class
  hook; make an NA LR CI warn or return a one-sided interval. Done when: the incidence F3/F6 and ordinal F9 repros
  warn with NA Wald p and CI, and the incidence F8 repro has `n_extreme > 0` with those replicates excluded.

<a id="todo-147"></a>
<!-- pre-split-id: 1.0.6/363; 2026-11-25 -->

- [ ] TODO-147 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferenceOrdinalPartialProportionalOddsRegr`: a t(n-1) reference for an ML fit, and unknown `nonparallel` names
  silently ignored.**
  Ids: ds-ordinal-44883784401-f1, ds-ordinal-44883784401-f2.
  `df = n - 1` (`R/EDI/R/inference_ordinal_partial_proportional_odds.R:280,343,347,357`) makes the CI and p differ
  from `InferenceOrdinalPropOddsRegr` on the same fit (p 3.67e-05 vs 1.38e-05) with no non-parallel covariates;
  `nonparallel` is validated only against "treatment" (`:96-102`) and `intersect()` (`:426,456`) drops a typo. Fix:
  normal reference (label `Pr(>|z|)`); error on names not among the covariates, listing them. Done when: with
  `nonparallel = character(0)` PPO's CI and p equal PO's to 1e-8, and `nonparallel = "base_pian"` errors.

<a id="todo-148"></a>
<!-- pre-split-id: 1.0.6/364; 2026-11-25 -->

- [ ] TODO-148 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Cumulative-link R6 classes
  stop short of the MLE, and the PPO breakdown benchmark refits and overwrites the cache.**
  Ids: ds-ordinal-44883784401-f3, ds-ordinal-44883784401-f5.
  PO, cloglog, probit and cauchit call the kernels with the lbfgs defaults (maxit 100, tol 1e-6) and don't forward
  `optimization_alg` (`R/EDI/R/inference_ordinal_proportional_odds.R:111-145`, `inference_ordinal_cauchit.R:65-158`;
  stop rule `src/fast_ordinal_regression.cpp:147-205`): estimates differ from `ordinal::clm` in the 3rd significant
  digit (cauchit -0.5246 vs -0.5283), so Wald CIs and p are off and `set_optimization_alg("newton_raphson")` does
  nothing. `benchmark_asymp_two_sided_pval_breakdown()` on PPO refits warm-started (`inference_ordinal_partial_proportional_odds.R:255-290,488-517`),
  returns a different estimate and leaves it in the cache. Related: v1.0.7-TODO-124. Fix: Newton-polish the lbfgs
  result (or tighten tol) and forward `optimization_alg`; make the breakdown time the cached path or refit cold
  without writing the cache. Done when: on the F5 trials all four links match clm to 1e-5, and the breakdown's
  estimate and p equal the public methods' with the cache unchanged. [C++]

<a id="todo-149"></a>
<!-- pre-split-id: 1.0.6/365; 2026-11-25 -->

- [ ] TODO-149 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Open-interval checks: a
  false "Element 1 is not <= 1" message, and two CI overrides with no alpha check.**
  Ids: ds-ordinal-44883784401-f6, ds-ordinal-44883784401-f7, ds-proportion-44883784401-f3.
  `checkmate::assertNumeric(x, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps)` prints the bound as
  "1", so alpha = 1 or `tau = 1` fails with "Element 1 is not <= 1" (e.g. `inference_all_abstract_asymp.R:22`,
  `inference_proportion_quantile_regr.R:81`, `inference_continuous_quantile_regr.R:257`; ~100 sites in ~66 files).
  `compute_asymp_confidence_interval()` on PO Wald (`inference_all_abstract_asymp_lik_std_mod_cache.R:20`) and
  `InferenceOrdinalRidit` (`inference_ordinal_ridit.R:225`) skip the check: alpha = 1.5 gives a reversed interval,
  alpha < 0 NaN. Fix: one helper `assert_open_unit_interval(x, name)` ("`alpha` must be strictly between 0 and 1
  (got 1)") used at every alpha/tau/prob site, including the two overrides (or inside
  `compute_z_or_t_ci_from_s_and_df()`). Done when: alpha 0, 1, 1.5 and tau 1 give that message on every class tried,
  and a source test bans the old pattern.

<a id="todo-150"></a>
<!-- pre-split-id: 1.0.6/366; 2026-11-25 -->

- [ ] TODO-150 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`?InferenceOrdinalJonckheereTerpstraTest` misstates the exact-enumeration cap.**
  Ids: ds-ordinal-44883784401-f12.
  The help (`R/EDI/R/inference_ordinal_jonckheere_terpstra_test.R:15-17,104-107`) says exact enumeration stops at one
  million allocations with a warning; `kMaxJTExactLeaves = 1e6` (`src/fast_jonckheere_terpstra.cpp:19-38,211`) counts
  treated-count tables given the category margins, so 2.5e25 allocations give an exact p with no warning. Fix the
  text, and state the two-sided convention (2 x min one-sided, which differs from coin on ties). Done when: the Rd
  matches the C++ and a test pins the 2 x min convention.

<a id="todo-151"></a>
<!-- pre-split-id: 1.0.6/367; 2026-11-25 -->

- [ ] TODO-151 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Exact 0s and 1s in
  proportion outcomes: Beta's silent squeeze, QuantileRegr's eps clamp, and the cookbook's open-interval claim.**
  Ids: ds-proportion-44883784401-f1, ds-proportion-44883784401-f2, ds-proportion-44883784401-f10.
  `sanitize_beta_response()` (`R/EDI/R/helper_glm_fit.R:1110-1124`) applies the Smithson-Verkuilen squeeze to every
  y when any is 0 or 1, silently; `?InferencePropBetaRegr` (`inference_proportion_beta.R:21-23`) points to that
  undocumented function. `InferencePropQuantileRegr` clamps to `.Machine$double.eps` before the logit
  (`inference_continuous_quantile_regr.R:139`, `helper_math.R:26`), giving a "log-odds shift" of about +/-34 with
  p ~ 1e-117 at low/high tau, no warning. The proportion cookbook (`vignettes/cookbook-proportion.Rmd:52-53,64`) says
  fractional logit needs open-interval data and clips y; the class takes [0, 1]. Fix: document the squeeze (formula,
  Smithson & Verkuilen 2006) and warn once naming the counts and pointing to ZOIB / FractionalLogit; for QuantileRegr
  (and the rand kernel's `zero_one_logit_clamp`) as the owner decides (below; results change, NEWS); fix the cookbook
  text and drop the clipping from the fractional-logit chunk. Done when: the F1 and F2 repros warn (no silent +/-34),
  and cookbook and help agree.
  - Owner decision pending: [DECISION-v1.0.6-TODO-367](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-367) (`InferencePropQuantileRegr` on exact 0/1: Smithson-Verkuilen squeeze, or warn / error?).

<a id="todo-152"></a>
<!-- pre-split-id: 1.0.6/368; 2026-11-25 -->

- [ ] TODO-152 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropZeroOneInflatedBetaRegr` returns NA with no warning for exact 1s without 0s and an uncentred
  covariate.**
  Ids: ds-proportion-44883784401-f4.
  Reproduced on HEAD (seed 1): raw age gives CI `NA NA`, `is_nonestimable()` TRUE, no warning; centred age gives
  (0.342, 0.745). Not root-caused (likely an ill-conditioned one-class inflation submodel in
  `R/EDI/R/inference_proportion_zero_one_inflated_beta.R`); seed 3 also gives a finite CI with `is_nonestimable()`
  TRUE (stale flag). Fix: standardize covariates inside the joint fit and back-transform, drop an empty boundary
  submodel, warn when the SE is still unavailable, and keep the flag consistent. Done when: raw and centred
  covariates give the same CI on the repro's seeds 1-6 and `is_nonestimable()` agrees with the CI.

<a id="todo-153"></a>
<!-- pre-split-id: 1.0.6/369; 2026-11-25 -->

- [ ] TODO-153 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropGCompMeanDiff(variance_fallback_methods = character(0))` loses the point estimate.**
  Ids: ds-proportion-44883784401-f5.
  `shared()` (`R/EDI/R/inference_proportion_gcomp.R:1093-1101`) calls `effects_are_usable(..., estimate_only = FALSE)`
  (`:613-616`), which needs a finite `se_md`; with an empty cascade `set_failed_fit_cache()` wipes `md` (0.1218 with
  `estimate_only = TRUE`, NA otherwise), no warning. The docs (`:30-36`) promise an NA variance only. Fix: keep `md`
  and cache a non-estimable SE with a reason (e.g. `variance_cascade_exhausted`) and a warning. Done when: the repro
  returns 0.1218369 with NA SE/CI and a reason.

<a id="todo-154"></a>
<!-- pre-split-id: 1.0.6/370; 2026-11-25 -->

- [ ] TODO-154 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropZeroOneInflatedBetaRegr` doesn't check the variables in `model_formula_zero_one`.**
  Ids: ds-proportion-44883784401-f6.
  `initialize()` (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R:130-142`) only runs `assertFormula()` on it;
  `~ bogus` returns NA silently, while the same typo in `model_formula` errors. Fix: also call
  `assertFormulaContext(model_formula_zero_one, ...)` (`helper_additional_asserts.R:28-44`). Done when: the repro errors
  naming `bogus`.

<a id="todo-155"></a>
<!-- pre-split-id: 1.0.6/371; 2026-11-25 -->

- [ ] TODO-155 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`InferencePropGCompMeanDiff`'s
  `"model_based"` variance fallback uses the unscaled Bernoulli information for a fractional response.**
  Ids: ds-proportion-44883784401-f7.
  `resolve_effect_variance()` / `model_based_covariance_matrix()` (`R/EDI/R/inference_proportion_gcomp.R:~786-840`,
  docs `:92-110`) use the binomial Fisher information, which `?InferencePropFractionalLogit` (`:12-20`) calls wrong for
  a fractional y; on the repro it is 2.5 x the sandwich SE. Fix (results change, NEWS): scale by the Pearson
  dispersion and document it. Done when: the `model_based` SE on the repro is about 0.0507 (quasi-binomial delta
  method).
  - Owner decision pending: [DECISION-v1.0.6-TODO-371](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-371) (OK to scale the model-based variance by the Pearson dispersion (results change)?).

<a id="todo-156"></a>
<!-- pre-split-id: 1.0.6/372; 2026-11-25 -->

- [ ] TODO-156 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **The quantile classes offer a
  jackknife that is NA on clean data, and the warning blames separation.**
  Ids: ds-proportion-44883784401-f9.
  `InferencePropQuantileRegr`'s jackknife is NA on interior data with the generic "separation" reason
  (`R/EDI/R/inference_all_abstract_jackknife.R:590-591`, trigger `:678`); the delete-1 jackknife is not consistent for
  sample quantiles anyway. Fix: drop the jackknife capability for the Contin/Prop/KK quantile classes and update the
  small-sample table, or keep it with a quantile-specific reason; reword the generic text so separation is one
  possible cause. Done when: the repro either doesn't offer the jackknife or warns without mentioning separation.

<a id="todo-157"></a>
<!-- pre-split-id: 1.0.6/373; 2026-11-25 -->

- [ ] TODO-157 (added 2026-11-21, agent; found by the v1.0.6-TODO-209 fix): **`InferenceIncidKKGEE` can never return a
  randomization p-value.** The KK GEE mixin's `compute_rand_two_sided_pval` override
  (`R/EDI/R/inference_mixin_kk_gee_shared.R` ~L125) stops with "not supported for incidence. Use Zhang method." unless
  the design is a rerandomization design, but the class accepts only KK designs, so the call always errors. The base
  method has allowed draw-based incidence p-values since 2026-10-20, so the refusal looks stale. Test either way.
  - Owner decision pending: [DECISION-v1.0.6-TODO-373](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-373) (drop the stale incidence refusal, or remove `rand` from `InferenceIncidKKGEE`'s supported procedures?).

<a id="todo-158"></a>
<!-- pre-split-id: 1.0.6/374; 2026-11-25 -->

- [ ] TODO-158 (added 2026-11-21, agent, owner request; found by the R-CMD-check triage of run 44749244495, follow-up to
  v1.0.6-TODO-117 and v1.0.7-TODO-125): **The Newton-decrement L-BFGS finish exposed two optimizer bugs.** (1)
  `fast_stereotype_logit_internal`'s cold start (beta = 0, where the loadings carry no information) sent a loading to
  +-Inf and stopped at a non-optimal boundary point that the old verdict called converged (n = 800, K = 3: neg-loglik
  755.7 vs the MLE 732.7; K = 5: 392.9 vs 269.8). Fix applied in `R/EDI/src/fast_stereotype_logit.cpp` (~L727): with no
  `warm_start_params`, K >= 3 and no caller-fixed gamma, fit with gamma held at 0 first, then release it (the in-kernel
  form of the R layer's `adjcat_two_stage` start, TODO-176). (2) `lbfgs_finish_with_newton_decrement`
  (`R/EDI/src/_helper_functions_core.h` ~L1507) kept the old verdict only when the Hessian was unusable at the first
  check, so a boundary fit (Gaussian LMM with the random-effect SD -> 0) whose damped steps improved the objective and
  then lost positive definiteness was reported as not converged. Fix applied: keep the old verdict whenever the
  Hessian is unusable. Five tests that still assumed the old behaviour were updated (information reuse, ordinal GLMM
  polish flags x2, stereotype multistart, stereotype hessian-allocs fixture). Verified 2026-11-21 by kernel swap
  (stereotype and Gaussian LMM kernels via `sourceCpp`, swapped into the namespace and `package:EDI`):
  `test-rcpp-fitting-equivalence.R` 81/81, `test-stereotype-logit-hessian-allocs.R` 18/18,
  `test-gaussian-lmm-hessian-prealloc.R` 19/19, and all 22 stereotype and 3 Gaussian LMM test files 386 pass / 0 fail.
  Done when, after the owner's rebuild with both patches, R-CMD-check is green on every leg and the v1.0.7-TODO-125 (2)
  probes of the other kernels sharing the finish (ZIP / hurdle, ZOIB, the GLMMs, Weibull frailty, CLMM) pass; the
  header change reaches every L-BFGS kernel, and only these two were swapped.
  - **Verified 2026-11-23 (agent) on the owner's 09:28 build with both patches:** `test-rcpp-fitting-equivalence.R` 81/81,
    `test-stereotype-logit-hessian-allocs.R` 18/18, `test-gaussian-lmm-hessian-prealloc.R` 19/19, and the three other
    files from the run 44749244495 failures pass. Still to confirm on CI after a push: R-CMD-check green on every leg, and
    the v1.0.7-TODO-125 (2) probes of the other kernels that share the finish.

<a id="todo-159"></a>
<!-- pre-split-id: 1.0.6/375; 2026-11-25 -->

- [ ] TODO-159 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalWeibullRegr`: Wald / LR / gradient oversized at n = 1000 with `~1`, and score oversized at every n.**
  - Wald / LR / gradient, size and coverage: 4-5 cells each, all `~1`, n = 1000 (FixedBernoulli, FixediBCRD,
    FixedRerandomization at prob_T 0.5 and 0.2, SeqOneByOneRandomBlockSize); worst FixedRerandomization `~1` n = 1000:
    size 0.082 (level 0.05), coverage 0.918.
  - Score, size and coverage: 9 cells at n = 50, 200 and 1000, `~.` and `~1` (FixedBlocking@0.2, FixedOptimal@0.2,
    FixedRerandomization, FixedRerandomization@0.2, FixedBernoulli, FixediBCRD, SeqOneByOneiBCRD,
    SeqOneByOneRandomBlockSize); worst FixedOptimal@0.2 `~.` n = 50: size 0.147 (level 0.1), coverage 0.853.
  - v1.1.0-TODO-188 covers the score test at n = 50 only; these cells fail at large n too, so they are not small-sample.
    Since all four tests fail together at n = 1000 with `~1`, check first whether omitting the DGP covariates misspecifies
    the Weibull model (shape absorbs covariate heterogeneity), as v1.1.0-TODO-174 / -216 found for count models.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedRerandomization' --n 1000 --effect null --only InferenceSurvivalWeibullRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cells; confirmed ones are fixed, or ruled inherent and documented, with
    calibration_study_accepted.csv rows citing this TODO.
  - Status 2026-11-23 (coordinator): every flagged cell is now decided (wave 29 of campaign 2026-11-15-e36c7710): 32 confirmed failing (2 at n = 200, 30 at n = 1000; Wald 8, score 11, LR 6, gradient 7) and 18 cleared (all 4 at n = 50, 2 at n = 200, 12 at n = 1000). The large-n excess is real, not screening noise: investigate (start with the `~1` misspecification check above).

<a id="todo-160"></a>
<!-- pre-split-id: 1.0.6/376; 2026-11-25 -->

- [ ] TODO-160 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`: Wald / LR / gradient oversized at n = 1000 on KK14 (`~1`).**
  - One cell per test: SeqOneByOneKK14 `~1` n = 1000, size 0.080-0.081 (level 0.0525), coverage 0.919-0.920.
  - v1.1.0-TODO-184 covers Wald at n = 50 and v1.1.0-TODO-256 / -257 the score test; neither covers large n.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignSeqOneByOneKK14' --n 1000 --effect null --only InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell (a single flag may clear); if confirmed, fixed or accepted with rows citing
    this TODO.

<a id="todo-161"></a>
<!-- pre-split-id: 1.0.6/377; 2026-11-25 -->

- [ ] TODO-161 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalDepCensTransformRegr`: score test oversized at n = 1000.**
  - Size: FixedGreedyDOptimal `~.` n = 1000, size 0.075 (level 0.05). Coverage: FixedOptimal@0.2 `~.` n = 50, 0.867
    (level 0.9), and FixedGreedyDOptimal `~.` n = 1000.
  - v1.1.0-TODO-183 covers score / LR at n = 50 only (small-sample); the n = 1000 cell is outside it.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedGreedyDOptimal' --n 1000 --effect null --only InferenceSurvivalDepCensTransformRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cells; the n = 50 coverage cell can join v1.1.0-TODO-183 if it confirms.

<a id="todo-162"></a>
<!-- pre-split-id: 1.0.6/378; 2026-11-25 -->

- [ ] TODO-162 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalCoxPHRegr` and `InferenceSurvivalStratCoxPHRegr`: randomization test oversized at n = 200.**
  - CoxPHRegr: FixedGreedy and FixedGreedyDOptimal `~.` n = 200, size up to 0.075 (level 0.05).
    StratCoxPHRegr: SeqOneByOneEfron `~.` n = 200, size 0.076. Neither class has a calibration TODO.
  - A randomization test is exact under the design, so a confirmed excess is a bug (check the redraw uses the design's
    own randomization, and the Monte Carlo p-value's resolution), not small-sample behaviour.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedGreedy' --n 200 --effect null --only InferenceSurvivalCoxPHRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"` (and `--design 'DesignSeqOneByOneEfron' --only InferenceSurvivalStratCoxPHRegr`). Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the three cells; confirmed ones are fixed.

<a id="todo-163"></a>
<!-- pre-split-id: 1.0.6/379; 2026-11-25 -->

- [ ] TODO-163 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferencePropQuantileRegr`: Wald oversized at n = 1000, FixedBernoulli prob_T 0.2.**
  - One cell: FixedBernoulli@0.2 `~.` n = 1000, size 0.076 (level 0.05), coverage 0.924. No calibration TODO covers it.
  - Investigate first if it confirms: the quantile-regression sandwich / kernel density bandwidth with about 200
    treated, and the 0/1 boundary of the proportion response.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type proportion --design 'DesignFixedBernoulli@prob_T=0.2' --n 1000 --effect null --only InferencePropQuantileRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell; if confirmed, fixed or accepted with rows citing this TODO.

<a id="todo-164"></a>
<!-- pre-split-id: 1.0.6/381; 2026-11-25 -->

- [ ] TODO-164 (added 2026-11-21, owner request; from the `pkg-size` budget report, issue #66): **The R CMD check
  test phase got 36-60% slower on five of the six CRAN legs.** At commit `626f9964`, `tests_s` against the 8-week
  median: macos-latest-release 11.0 min vs 416 s (+59%), ubuntu-latest-devel 561 vs 351 s (+60%),
  ubuntu-latest-oldrel-1 507 vs 329 s (+54%), ubuntu-latest-release 463 vs 324 s (+43%), windows-latest-release
  15.0 vs 11.0 min (+36%); the run before (`8d8c5f78`) had macos at 13.0 min. Install, examples and total check time
  are within budget, so the growth is in `tests/testthat`. Find which test files grew (per-file timings from the
  check logs of a run before and after the jump), and either speed them up, move them to the bulk suite, or accept
  the new baseline with a reason here. Done when: the next budget run shows no `tests_s` flag, or the accepted new
  baseline is recorded.
  - Update 2026-11-23 (coordinator, owner request; budget run 45131875338 at `38d1b90a`, issue #66): macos-latest-release
    `tests_s` 15.0 min vs 446 s (+102%) and, new, total `check_s` 55.6 vs 41.7 min (+33%, the first `check_s` flag; it
    follows from the test phase, since install and examples are within budget); ubuntu-latest-oldrel-1 `tests_s` 560 vs
    405 s (+38%); the other legs' `tests_s` are back within budget. The source tarball grew to 3.07 MB (3.09 MB on
    Windows) from 2.80 MB at `01ee435d` (8-week median 2.75 MB): under the 4 MB warning, but find what added ~0.3 MB
    when looking at this TODO.

<a id="todo-165"></a>
<!-- pre-split-id: 1.0.6/382; 2026-11-25 -->

- [ ] TODO-165 (added 2026-11-21, owner request; from the `ci-self-check` audit, issue #20): **Eight workflows now take
  1.6-3.4x their 8-week median.** calibration-study 384 vs 114 min (ci-self-check-m17a2fb9e), audit-results-freshness
  113 vs 56 (ci-self-check-m4736ea4b), audit-python-vulns 103 vs 54 (ci-self-check-med42e85a), audit-generated-drift
  91 vs 47 (ci-self-check-md410b94c), audit-dead-code 134 vs 82 (ci-self-check-m03e51a70), audit-dependency-license 77
  vs 41 (ci-self-check-m6bcbb195), audit-ci-self-check 59 vs 35 (ci-self-check-m45af0b31), audit-allowlist-hygiene 50
  vs 29 (ci-self-check-m7f0b680b). Most medians rest on only 3 earlier runs, and several audits that rarely build EDI
  (python-vulns, dependency-license) roughly doubled together, which points at a shared step (package install or
  cache miss) rather than each audit's own work. Compare step timings of one slow and one normal run per workflow;
  fix the shared cause, or accept the new baseline here per workflow. Done when: the next ci-self-check run reports
  none of these ids, or each is accepted with a reason.

<a id="todo-166"></a>
<!-- pre-split-id: 1.0.6/383; 2026-11-25 -->

- [ ] TODO-166 (added 2026-11-21, owner request; from the algorithm-audit drift report, issue #55): **Re-look at
  algorithm-audit row R (exact discrete nulls and enumeration), reviewed 2026-10-22.** Commit `8d8c5f78` (2026-11-20)
  changed its kernels (`R/EDI/R/inference_helpers_zhang.R`, `R/EDI/src/zhang_exact_speedups.cpp`). Follow
  `R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md` for the row: check the change keeps the
  row's chosen algorithm and its comparator agreement, then update the row's `reviewed` date. Done when: the drift
  report lists no commits for row R.

<a id="todo-167"></a>
<!-- pre-split-id: 1.0.6/384; 2026-11-25 -->

- [ ] TODO-167 (added 2026-11-21, coordinator; found by the rand warm-start chaining study, see
  `R/package_metadata/audits/research_findings/2026-11-21-rand-warm-start-chaining-timing.md`):
  **`InferenceIncidKKCondLogitGLMMOneLik` randomization replicates disagree with a fresh fit and go NA silently.**
  On n = 150 `DesignFixedBinaryMatch` (75 pairs), r = 400, `num_cores = 1`: (1) the reused-worker statistic matches the
  observed estimate on the original assignment, but on permuted assignments 58 of 60 replicates differ from a fresh
  `compute_estimate()` on the permuted design (same y, X, pairs) by more than 1e-3, up to 0.44 (correlation 0.90);
  the same check on `InferenceCountKKGLMM` matches to 3e-9. First suspect: a per-draw cache (clogit / reservoir split,
  pair data) that the worker does not refresh. (2) With the full-data base warm start (v1.0.6-TODO-25) 43 of 400
  replicates are NA with no warning (7 with the old chaining, 0 of 60 with warm starts off); `na.rm` drops them and
  the p-value moves (0.112 vs 0.102). Example: on the mirrored assignment `1 - w` the worker returns NA while a fresh
  fit gives -0.6247. Fix (1) first, then check whether (2) remains; the randomization p-value of this class is
  unreliable until then. Test: worker replicate equals a fresh fit on several permuted draws, and no silent NA.

<a id="todo-168"></a>
<!-- pre-split-id: 1.0.6/408; 2026-11-25 -->

- [ ] TODO-168 (added 2026-11-22, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 27): **Ordinal randomization tests oversized in one shared cell, SeqOneByOneiBCRD prob_T 0.2, n = 50.**
  - `rand` size in SeqOneByOneiBCRD@0.2 `~.` n = 50: `InferenceOrdinalAdjCatLogitRegr` 0.074, `InferenceOrdinalCloglogRegr`
    0.074, `InferenceOrdinalContRatioRegr` 0.074, `InferenceOrdinalGCompMeanDiff` 0.079 (level 0.05); GCompMeanDiff also
    FixedBinaryMatch `~1` n = 50. No calibration TODO covers these.
  - Four classes share the same data in this cell and fail together, so suspect the design's redraws (iBCRD at prob_T
    0.2 and n = 50, sequential) or the Monte Carlo p-value rather than the classes. A randomization test is exact under
    the design, so a confirmed excess is a bug.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type ordinal --design 'DesignSeqOneByOneiBCRD@prob_T=0.2' --n 50 --effect null --only InferenceOrdinalGCompMeanDiff --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cells; confirmed ones are fixed.
  - Status 2026-11-23 (coordinator): wave 29 of campaign 2026-11-15-e36c7710: `InferenceOrdinalAdjCatLogitRegr` cleared by confirmation; `InferenceOrdinalCloglogRegr` (1 cell), `InferenceOrdinalContRatioRegr` (1) and `InferenceOrdinalGCompMeanDiff` (2) still pending confirmation.
  - Status 2026-11-23 (coordinator), wave 30 of campaign 2026-11-15-e36c7710: `InferenceOrdinalCloglogRegr` and `InferenceOrdinalContRatioRegr` cleared by confirmation (after `InferenceOrdinalAdjCatLogitRegr` in wave 29), and so did `InferenceOrdinalGCompMeanDiff` on FixedBinaryMatch `~1`. One cell left, pending: `InferenceOrdinalGCompMeanDiff` on SeqOneByOneiBCRD@0.2 `~.` n = 50, size 0.079 (level 0.05). Close this TODO if it clears too.

<a id="todo-169"></a>
<!-- pre-split-id: 1.0.6/412; 2026-11-25 -->

- [ ] TODO-169 (added 2026-11-23, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), wave 29): **`InferenceOrdinalCauchitRegr`: score / LR / gradient oversized, confirmed at n = 50, 200 and 1000.**
  - Wave 29: 28 cells confirmed failing (18 at n = 50, 10 at n = 1000), 10 cleared, 87 pending, across many designs
    and both allocations.
  - Worst confirmed: score at n = 50, size 0.170 / 0.167 / 0.166 (level 0.1) on FixedGreedy@0.2, FixedRerandomization@0.2,
    FixedOptimal@0.2, and 0.13-0.14 at prob_T 0.5 (SeqOneByOneBernoulli, SPBR, Efron, KK14, FixedOptimalBlocks,
    FixedBinaryMatch); LR and gradient at n = 1000, FixediBCRD@0.2 `~.`, size about 0.070 (level 0.05). Wald fails at
    n = 1000 too (SeqOneByOneRandomBlockSize@0.2, 0.082, pending).
  - v1.1.0-TODO-181 covers the likelihood tests at n = 50 as small-sample; the n = 1000 failures are outside it, so
    either the cauchit fit or its information is off, not only small-n asymptotics. Investigate first: observed vs
    expected information for the cauchit link (heavy tails make the expected information a poor fit to the curvature);
    convergence and boundary handling of the null fit used by score / LR / gradient; compare against `ordinal::clm(link =
    "cauchit")` on the failing cells. Also check the shared ordinal parametric-bootstrap simulator's sign mismatch
    (owner memory 2026-09-23, root-caused, not fixed; Cauchit among the affected), in case it shares code with these tests.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type ordinal --design 'DesignFixediBCRD@prob_T=0.2' --n 1000 --effect null --only InferenceOrdinalCauchitRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"` (and `--design 'DesignFixedGreedy@prob_T=0.2' --n 50`). Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: the cause is found and the n = 1000 cells pass, or the owner accepts them with a reason and
    calibration_study_accepted.csv rows citing this TODO; the n = 50 cells can stay under v1.1.0-TODO-181 if that is the cause.
  - Status 2026-11-23 (coordinator), wave 30 of campaign 2026-11-15-e36c7710: 82 cells confirmed failing (score 59, gradient 14, LR 9; size and coverage) across n = 50, 200 and 1000. Every Wald cell was cleared by confirmation, so Wald is out of scope (title updated). 6 cells still pending: score / LR / gradient, size and coverage, SeqOneByOneRandomBlockSize prob_T 0.5, n = 1000.

### Audit triage sweep, 2026-11-23
Found by the 2026-11-23 sweep of the audit reports and CI runs since 2026-11-21 22:30 UTC.

<a id="todo-170"></a>
<!-- pre-split-id: 1.0.6/414; 2026-11-25 -->

- [ ] TODO-170 (added 2026-11-23, coordinator, owner request; audit decision `code-duplication-d78867741`
  (`dup-de630ca1589f`), code-duplication run 45037204796, issue #61): **KK21's univariate beta t-statistic does not
  clamp y, so an exact 0 or 1 response freezes phi at its default.** `multivariate_beta_tstat`
  (`R/EDI/src/kk21_weights.cpp` ~L894-972) clamps y inside the beta log-likelihood (`std::max(yi, 1e-12)`,
  `std::min(yi, 1 - 1e-12)`, ~L952-953) and its caller clamps y to [1e-10, 1 - 1e-10] (~L1086-1089).
  `univariate_beta_tstat` (~L412-493) runs the same phi grid without the clamp (~L474-475), and its caller
  `kk21_beta_weights_cpp` (~L595-612) passes y unclamped (the clamp at ~L620 is only in the logit fallback). The design
  accepts proportion responses in [0, 1] inclusive (`design_abstract.R:1152`), so with one y exactly 0 or 1,
  `log(yi)` or `log1p(-yi)` is -inf, the log-likelihood is -inf for every phi, `ll > best_ll` never fires and
  `best_phi` stays at 10.0 instead of the profile-likelihood phi. The t-statistic stays finite, so the logit fallback
  does not run and the KK21 weights change silently. Reached by `DesignSeqOneByOneKK21` / `KK21stepwise` with
  `response_type = "proportion"` and `proportion_use_speedup = FALSE` (`design_seq_one_by_one_KK21.R` ~L436).
  Confirmed by reading HEAD (38d1b90a); not yet run. Fix: clamp y in `kk21_beta_weights_cpp` as the multivariate
  caller does, or share one phi-profile helper between the two functions (see v1.0.7-TODO-54). Test: y with an exact
  0 and 1 gives the same weights as y clamped to [1e-10, 1 - 1e-10], and the profile picks a phi other than 10.
  Changes KK21 weights (and so allocations) on such data; NEWS entry. [C++]

<a id="todo-171"></a>
<!-- pre-split-id: 1.0.6/415; 2026-11-25 -->

- [ ] TODO-171 (added 2026-11-23, coordinator, owner request; audit decision `code-duplication-dc86f7ad2`
  (`dup-55ec9b7a429d`), code-duplication run 45037204796, issue #61): **`InferenceIncidModifiedPoisson`'s
  randomization-inference refit swallows timeouts and interrupts.** In
  `compute_treatment_estimate_during_randomization_inference` (`R/EDI/R/inference_incidence_modified_poisson.R`
  ~L142-176) the `tryCatch` around `fast_poisson_regression_cpp` uses `error = function(e) NULL` (~L164), so a time
  or CPU limit raised inside the fit becomes `NA_real_` and the randomization loop continues instead of aborting. The
  count sibling (`inference_count_robust_poisson.R` ~L192-204) rethrows control conditions with
  `if (is_edi_control_condition(e)) stop(e)` (`globals.R` ~L86-92). The incidence copy also omits
  `estimate_only = TRUE` in that refit (a speed difference; check that the warm-start Fisher it stores from
  `res$XtWX` is still valid if it is added). The other `error = function(e) NULL` handlers in the same file (~L229,
  ~L252, ~L266) need the same check. Confirmed by reading HEAD (38d1b90a). Fix: rethrow control conditions as the
  count class does (or use `private$resampling_error_to_na`), pass `estimate_only = TRUE`. Test: with
  `options(EDI.ci_timeout_deadline)` in the past, the randomization p-value / CI aborts with the timeout condition
  instead of returning a value; the randomization distribution is otherwise unchanged on a fixed seed.

<a id="todo-172"></a>
<!-- pre-split-id: 1.0.6/416; 2026-11-25 -->

- [ ] TODO-172 (added 2026-11-23, coordinator, owner request; test-bulk-non-cran runs 44958883285 (91ec8e5c) and
  45131875335 (38d1b90a) failed, 45082880097 (29d59ae4) passed): **`test-simulation-worker-result-dispatch-contracts.R`
  fails intermittently in the bulk shard.** `R/package_tests/testthat_bulk/test-simulation-worker-result-dispatch-contracts.R:181-182`
  ("observational DGP estimands override standard class-based estimands"): `out$errors` has length 1 and
  `out$results_dt$true_estimand` is NULL, for both the stateless and the stateful `custom_dgp`. The test file has not
  changed since be70fd55 (2026-09-18), and between the passing and the latest failing run `simulations_framework.R`
  changed only in roxygen, so the failure looks order-dependent (process state left by an earlier file in the same
  shard; see the `feedback_shard_process_state_poisoning` memory) or random. The other six files that failed in
  44958883285 were fixed on 2026-11-22; this one was not. Plan: (1) print `out$errors` (add it to the expectation's
  `info`) so the next failure names the error; (2) run the file alone and then directly after its shard neighbours (the
  shard-1 file list in the run log), with NOT_CRAN=true, to see whether the order triggers it; (3) fix the leaking
  state or the test. Done when the file passes in the shard on three consecutive bulk runs.

<a id="todo-173"></a>
<!-- pre-split-id: 1.0.6/418; 2026-11-25 -->

- [ ] TODO-173 (added 2026-11-23, agent, owner request; code-duplication run 45037204796, issue #56): **Keep a
  code-duplication family's id, verdict and TODO citation when its code is edited.** A family id (`dup-<12 hex>`,
  `.github/scripts/audits/code_duplication.py` ~L341) hashes the two file paths and the normalized text of both
  regions, and each region runs from the jscpd match out to `EXTEND_LINES` (20) past each end. So it survives a pure
  move, but any edit inside or near either copy makes a new id. The family then comes back on issue #56 as a new
  decision, is judged again by Claude (`verdicts.json` is keyed by the id), and needs a new citation in
  v1.0.7-TODO-54. Evidence: the 2026-11-22 run listed 53 new decisions; 19 of them are on a file pair that
  v1.0.7-TODO-54 already cited under an older id, e.g. `design_abstract.R` vs `design_fixed_abstract.R` was
  `code-duplication-d6b10061f` (L405-498 / L90-191) and is now `code-duplication-dc6d70509` (L417-518 / L90-191).
  Fix: when a new family overlaps an earlier one (same file pair and, say, at least half of each region's lines in
  common), carry over the old family's verdict and decision id instead of minting new ones. Record the old-to-new id
  mapping in `verdicts.json` so citations and dismissals keep working. Re-judge only when the overlap is small or
  the structural differences changed. Alternatively, key families by file pair and the enclosing function or R6
  method names. Test: in a fixture, edit one line inside a judged region; the next detect() gives the same decision id
  and no new Claude batch.

### Follow-ups from the v1.0.6-TODO-228 measurement, 2026-11-23

<a id="todo-174"></a>
<!-- pre-split-id: 1.0.6/419; 2026-11-25 -->

- [ ] TODO-174 (added 2026-11-23, agent, from the v1.0.6-TODO-228 measurement): **Several L-BFGS kernels still report
  `converged = TRUE` at a wrong optimum on the colon age x 1000 / age + 1e5 designs.** With the v1.0.6-TODO-117 finish
  on, the Hessian at LBFGSpp's stop is not positive definite, so `lbfgs_finish_with_newton_decrement()` keeps the old
  "stopped before the cap" verdict. Measured (colon, etype 2, Obs vs Lev+5FU, pairs of consecutive rows in time order;
  negLL above the best fit of the same model on the `scale()`d design): `fast_ordinal_clmm_cpp` x1000 treatment 0 (+68),
  +1e5 0 (+65), truth -0.170; `fast_logistic_glmm_cpp` x1000 / +1e5 about -0.23 (+9), truth -0.263;
  `fast_clogit_plus_glmm_cpp` x1000 / +1e5 0 (+40); `fast_weibull_frailty_cpp` x1000 / +1e5 0.080 (+46 / +37), truth 0.347;
  ZINB already known (v1.0.6-TODO-117). `fast_ordinal_glmm_cpp` is also wrong there but reports `converged = FALSE`.
  Fix candidates: report not converged when the rule cannot judge a point that is far from stationary (e.g. a large
  relative gradient), retry from an internally column-scaled problem (the v1.0.6-TODO-112 Weibull approach), or use
  the expected information when the observed one is not PD. Repro scripts: the v1.0.6-TODO-228 session scratch
  (`colon.R`, not committed); the TODO-410 measurement note has the response and grouping construction.

<a id="todo-175"></a>
<!-- pre-split-id: 1.0.6/420; 2026-11-25 -->

- [ ] TODO-175 (added 2026-11-23, agent, from the v1.0.6-TODO-228 measurement): **The ZINB NaN rescue spends 12 Newton
  steps on a fit that is thrown away.** On the benchmark `InferenceCountZeroInflatedNegBin` fixture (Poisson data, so
  theta goes to its boundary) the full ZINB L-BFGS run ends non-finite, `optimize_likelihood_lbfgs` retries the
  damped-Newton finish from the start (gradient norm 669, 13 numerical Hessians, 12 steps), the rescue fails the rule,
  and the kernel falls back to the reduced model anyway: fit time 12.2 -> 24.2 ms for no change in the result. Skip the
  rescue when the start is far from stationary, or cap its steps, and check that the TODO-169 NegBin rescue cases
  (smart cold start, age x 1000 / + 1e5) still succeed.

<a id="todo-176"></a>
<!-- pre-split-id: 1.0.6/421; 2026-11-25 -->

- [ ] TODO-176 (added 2026-11-23, agent, from the v1.0.6-TODO-228 measurement): **The benchmark ordinal generators leave
  the middle category empty.** `generate_kk_ordinal_pairs_data()` and the `"ordinal"` branch of `generate_data()` in
  `R/benchmark/benchmark_model_fits.R` set p1 = 1 / (1 + exp(eta - 1)) and p2 = 1 / (1 + exp(eta + 1)) - p1, which is
  always negative, so it is clamped to 1e-6 and y takes only 1 and 3 (199 / 201 on the CLMM pairs fixture). The
  ordinal kernels then fit a boundary model (log spacing of the cutpoints about -13), and `fast_ordinal_glmm_cpp`
  differs from `ordinal::clmm` by 0.38 / 0.18 on those fixtures while matching it to 1e-5 on colon. Fix the
  probabilities (cumulative P(Y <= k) = plogis(alpha_k - eta) with increasing alpha), note that it changes every ordinal
  benchmark dataset and timing, and check the ordinal GLMM vs clmm gap on boundary data separately.

<a id="todo-177"></a>
<!-- pre-split-id: 1.0.6/422; 2026-11-25 -->

- [ ] TODO-177 (added 2026-11-23, agent, from the v1.0.6-TODO-228 measurement; unverified): **Check whether the GLMM
  kernels compute the right likelihood for groups larger than two rows.** In a first colon attempt with groups of 6
  rows, `fast_logistic_glmm_cpp` reported a negLL of 190.7 where `lme4::glmer(nAGQ = 20)` on the same data and model
  gave 200.8 (a better likelihood than the reference, which should not happen for the same model), while
  `fast_gaussian_lmm_cpp` refuses groups larger than 2. KK designs only produce pairs and singletons, but the kernels
  accept any `group_id`. Compare each GLMM kernel (logistic, Poisson, ordinal CLMM / GLMM, hurdle Poisson, frailty)
  with glmer / clmm on groups of 3-6 rows, and either fix the likelihood or reject such groups as the LMM does.

<a id="todo-178"></a>
<!-- pre-split-id: 1.0.6/423; 2026-11-25 -->

- [ ] TODO-178 (added 2026-11-23, agent; found by the v1.0.6-TODO-230 agent): **`InferenceAsympLik`'s
  `compute_asymp_*()` switch has no `stop()` default**, so a testing type with no branch returns `NULL` (the bug class
  v1.0.6-TODO-208 fixed in the subclasses). Add `stop("Unsupported testing_type: ", ...)` to both switches in
  `R/EDI/R/inference_all_abstract_asymp_lik.R` and sweep the remaining `switch(private$testing_type` sites that lack one
  (v1.0.6-TODO-208's sweep listed abstract_asymp_lik, std_mod_cache, logit, binomial_identity, log_binomial, beta, zoib,
  coxph, strat_cox). `set_testing_type()` validates names today, so this guards against a supported-type list and a
  switch drifting apart. Test: a class whose supported list names a type its switch lacks errors instead of returning
  `NULL` (inject via a test subclass).

<a id="todo-179"></a>
<!-- pre-split-id: 1.0.6/429; 2026-11-25 -->

- [ ] TODO-179 (added 2026-11-25, agent; found by nightly run 45494402590 on cf2beb67): **`InferenceOrdinalStereotypeLogitRegr`
  `asymp_ci` and `asymp_pval` were "equal but not identical" at 2 and 4 cores vs 1, on both fork and mirai, in the
  exhaustive worker-count sweep** (`reproducibility (ubuntu-latest-release)`, `test-aa-fork-...` and
  `test-zz-mirai-worker-count-invariance-registry.R`, 8 failures). The point estimate was identical. The same leg passed
  on a65304eb (run 45467685988) with the same runner image (ubuntu-26.04 20261116) and serial OpenBLAS, and no ordinal
  code changed in between (only e57fb3c5's randomization-CI speedup, which made the earlier classes finish sooner: the
  1-core pass reached the class at +1.0 min instead of +1.5 min). Not reproduced locally (MKL, load_all(compile =
  FALSE)): all three values bit-identical at 1, 2 and 4 cores. Ruled out so far: the C++ fit and
  `loglik_hessian` (serial, no OpenMP region, matrix-vector products only) and the R multistart loop (serial). The
  sweep now prints `all.equal(tolerance = 0)` with a value failure, so a recurrence names the component and size.
  Next: re-run the leg to see whether it recurs; if it does, find what the asymptotic path reads that depends on
  the thread budget or on earlier cases in the same process.
  - Recurred 2026-11-25 on 28e38d3a (nightly run 45561016892): mean relative difference 1.766e-16 (asymp_ci) and
    1.878e-16 (asymp_pval), identical at 2 and 4 cores, fork and mirai. OpenBLAS ruled out: Cholesky and inverse of the
    sweep's exact 8 x 8 information matrix (traced from `chol()`) are bit-identical at 1, 2 and 4 OpenBLAS threads, so
    the last bit moves earlier (the fit's other parameters, or `get_stereotype_logit_hessian_cpp`). Next: on the Ubuntu
    leg, dump the selected fit's full `params` and the information matrix at each core count and compare.
  - Decided 2026-11-25 (owner): both keys become known failures of the sweep (reported, not asserted) for the v1.0.5
    freeze; see [DECISION-v1.0.6-TODO-429](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-429).
  - Done when: the cause is found and fixed and both keys are removed from `worker_invariance_known_failures`.

<a id="todo-180"></a>
<!-- pre-split-id: 1.0.6/430; 2026-11-25 -->

- [ ] TODO-180 (added 2026-11-25, agent, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 35, confirmation pending): **`InferenceContinQuantileRegr`: Wald CI undercovers the true estimand at power20, n = 200, prob_T 0.2.**
  - Four screen flags (BH q < 0.05, rule rate_check, level 0.95), each over 500 replicates with formula `~.`:
    coverage 0.902 on FixediBCRD@0.2, and 0.912 on FixedGreedy@0.2, FixedGreedyDOptimal@0.2 and SeqOneByOneiBCRD@0.2.
    At prob_T 0.2 and n = 200 only 40 subjects are treated. Confirmation runs on fresh replicates are still pending;
    no QuantileRegr Wald cell at the null has failed.
  - Related: the campaign also reports estimate bias for this class at the null and at power20 (worst -0.171 at
    FixedGreedyDOptimal@0.2, `~1`, n = 200; reported, not gated), and v1.1.0 lists ContinQuantileRegr among the
    null-bias flags just over 0.1 SD. Undercoverage at a non-zero effect plus bias suggests checking the estimand
    (the true quantile treatment effect the campaign computes for the DGP) before the SE.
  - Investigate first: whether `coverage_truth` for this class matches what the fit estimates at a non-zero effect
    (owner memory 2026-09-22: a one-shot MC truth for the quantile classes once cached an implausible value); then the
    Wald SE (the sparsity / density estimate the quantreg-style SE uses) when the treated arm is small (40 subjects).
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type continuous --design 'DesignFixediBCRD@prob_T=0.2' --n 200 --effect power20 --only InferenceContinQuantileRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation clears the four cells (close this TODO), or the cause is found and fixed, or the owner
    accepts the cells with a reason and calibration_study_accepted.csv rows citing this TODO.
