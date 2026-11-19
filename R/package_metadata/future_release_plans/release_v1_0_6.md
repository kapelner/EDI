# Release Scope: v1.0.6

> **Status: APPROVED 2026-11-10 (owner).** A bug-fix release after v1.0.5 that fixes bugs found during v1.0.5
> work, which were parked in `release_v1_1_0.md`. The owner approved the triage table below on 2026-11-10; the
> "Proposed for v1.0.6" items moved here as TODO-1..12 (their v1.1.0 entries are now strike-through pointers), and
> TODO-13 runs the "Triage first" checks.

> **Depends on:** v1.0.5 shipped to CRAN. v1.0.6 starts from what is left after v1.0.5's own gates close; open v1.0.5
> items do not slide into v1.0.6. CRAN prefers updates no more often than every one to two months, so plan the
> submission for at least a month after v1.0.5.

## Entry rule

A TODO belongs in v1.0.6 only if all three hold:

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
were accepted with a TODO ("oversized at n = 50") enter v1.0.6 only if triage finds a bug behind them.

## Gates (lighter than v1.0.5)

Run only the gates that the merged changes require.

| Gate | When | What |
|---|---|---|
| G1 build | any C++ change | User-run build. Agents compile touched files only (`EDI_UNITY=0`, see `CLAUDE.md`). |
| G2 timing | only if a kernel or a resampling loop changes, or for the v1.0.5 regression fix (TODO-167) | Quiet host (1-min load < 1.0), the affected benchmark sections only, compared with `R/benchmark/compare_benchmark_runs.R` against the v1.0.5 reports. |
| G3 parity | always | Untouched classes reproduce v1.0.5 under D2 on the parity fixtures. Touched classes: every change is listed and explained. |
| G4 results | touched classes only | Regenerate the comprehensive-test slices and the calibration fast tier for the touched classes; no full regeneration. |
| G5 CI | always | All required checks green at the release SHA; sanitizer/valgrind jobs too if C++ changed. |
| G6 docs | always | Roxygen and Rd regenerated with 0 warnings; NEWS lists every fix and every moved result. |
| G7 CRAN | always | `release.md` checklist (win-builder, mac-builder, reverse dependencies, `cran-comments.md`). |

## Triage of v1.1.0 TODOs that came from v1.0.5 (approved 2026-11-10)

Placement: **1.0.6** = proposed for this release; **1.1.0** = stays; **triage** = run the named check first, then
decide. Numbers are `release_v1_1_0.md` TODO numbers.

### Proposed for v1.0.6

| TODO | What | Why it qualifies |
|---|---|---|
| 74 | Bayesian jackknife (Bayesian BCa) depends on call history (log-binomial `~.` 3.4e-7) | Output depends on call history; bounded fix mirroring v1.0.5 TODO-128 |
| 157 (per-draw tau half only) | RMST rand-bootstrap recomputes tau per null draw, so the pivot's SE is ~1.85x too large; it also affects the p-value at delta = 0 | Wrong output; known fix (hold tau at the observed value). The uncensored-only CI half is a new capability and stays in 1.1.0. Needs a rebuild. |
| 160 | Stereotype logit: (a) the usability gate tests unscaled rcond, so 30-38% of fits are wrongly non-estimable; (b) QR fallback drops a covariate silently | Wrong NA and silent model change; known fixes (scale the information matrix; warn or refuse). |
| 162 | Block jackknife on SPBR / FixedBlocking deletes whole strata (G = 2-4), coverage 0.84-0.86 | Wrong output; owner already chose fix (b) (permuted block as the unit on SPBR). |
| 165 | Log-binomial full-data fit stops with the nuisance score off zero at exp(Xb) = 1 (4/1600 fits) | Unconverged fit treated as converged; gradient p-value NA. Bounded. |
| 167 | GLMM / CLMM kernels rerun the full multistart even when warm-started | Performance regression introduced by v1.0.5 TODO-31. Needs a rebuild and G2. |
| 169 | `InferenceIncidModifiedPoisson` `~1` returns NA (`model_fit_unavailable`) at n >= 10000, no warning | NA where a value is defined. |
| 170 | Stereotype accepted calibration rows predate the TODO-175/176/178 fixes; n = 1000 not re-run | Bounded re-run; closes or reopens stale accepted rows. **Done 2026-11-11 (as v1.0.6 TODO-8): no bug; moved back to v1.1.0 TODO-170.** |
| 189 (b), (c) | (b) 75/1000 LR CIs at n = 50 fall back to Wald because one null refit fails; (c) `InferenceIncidBinomialIdentityRiskDiff` lacks the TODO-179 Wald-at-boundary treatment | Wrong output on known paths; (c) copies an existing fix. Part (a), LR oversized at boundary MLEs, goes to triage. |
| 190 | `fast_clogit_plus_glmm_cpp()` stops at gradient norm 0.22 and reports `converged = TRUE` | False convergence. Needs a rebuild. |
| 192 | The tuner's proportion data is noiseless, so `tune_EDI_for_this_machine()` policies for proportion classes rest on degenerate fits | Users' tuning profiles are wrong for those classes; internal fixture only, no API. |
| 71 | Bootstrap p-value with `na.rm = TRUE` can come from a small surviving fraction of replicates | Wrong output without a guard; needs one owner decision (threshold, user-settable or not). Default unchanged for `na.rm = FALSE`. |

### Triage first

| TODO | What | Check that decides it |
|---|---|---|
| 159 | Cloglog: param-bootstrap p-value too conservative (2.8% / 0.6%); LR at `~.` 8-12% | Find why the param bootstrap is conservative (centring, scale of delta). A bug goes to 1.0.6; a small-sample property stays in 1.1.0. |
| 178 | Log-binomial score size 0.255 at prob_T 0.2, n = 50 | Re-run on the build with the v1.0.5 KKT score (TODO-181), together with TODO-165. If it is the exp(Xb) = 1 fits, it goes to 1.0.6 with 165. |
| 189 (a) | LR oversized at boundary MLEs (0.085 / 0.078 vs 0.048 interior) | Boundary-aware reference distribution is a method change (1.1.0) unless a bug is found. |
| 168, 171, 172, 173, 175, 176, 177, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188 | Accepted calibration rows: one test oversized at n = 50 or prob_T = 0.2, nominal at n = 200 | One check per class: SE vs sd(estimate), share of boundary or non-converged fits, variance collapsing to 0. A fitting or SE bug goes to 1.0.6; honest small-sample behaviour stays with v1.1.0's corrections work (TODO-5, Bartlett/Firth/Brent). |
| 170 | Stereotype gradient / LR size about 0.085 at n = 50 (nominal at n = 200 and 1000; moved back 2026-11-11) | Refit the null model from many starts on the n = 50 rejecting reps. If a fair share of rejections vanish, the null refit misses the global mode: a bug, fix goes to 1.0.6. Otherwise it stays in 1.1.0. |
| 174 | Hurdle Poisson likelihood tests anti-conservative at `~1` (misspecification, n = 1000) | Confirm `~.` is nominal. If so, this is documentation (stays 1.1.0, or a NEWS / roxygen note only). |

### Stays in v1.1.0

| TODO | What | Why it stays |
|---|---|---|
| 57 | Native randomization kernel for `InferenceContinLin` | Performance feature |
| 60 | Remove the post-clone rebind helper | Cleanup, no behaviour change |
| 61 | Cox `ties`: Efron becomes the default | Default change |
| 62 | Direct order-statistic inversion for randomization CIs | Exactness feature |
| 63 | Bayesian-bootstrap performance remainder | Performance work, not a v1.0.5 regression |
| 64 | `add_block_fixed_effects` opt-in | New API |
| 65 | Randomization CI on the estimand's own scale | Restores a refused capability with new sharp-null families |
| 66 | Monte Carlo SE of randomization CI endpoints | New output |
| 67 | NegBin jackknife; tighter NB `eps_g` in hurdle/ZAP | New capability; tolerance change (owner withdrew the C++ default change, 2026-11-04) |
| 68 | Speed acceptance for bootstrap / Zhang targets | Performance |
| 69 | Firth for KK-matched Cox | New method |
| 70 | Native Clayton optimizer limit at large n | Performance; changes estimates at tolerance level |
| 73 | Retire the legacy ladder parents | Refactor |
| 156 | DepCens kernel stalls at the atanh(rho) clamp | R retries rescue every case, so not user-visible; performance only, and the deferred patch has a known caveat |
| 157 (uncensored-only CI half) | RMST randomization CI without censoring | New capability |
| 161 | Design-aware RMST variance | New method (documented as conservative in 1.0.x) |
| 163 | KKStratCoxPH `~.` small-sample attenuation | Tied to Firth (TODO-69) |
| 166 | Bootstrap-calibrated score p-value for the log-gamma frailty class | New method |
| 191 | Column-dropping cache with a three-mode setting | New API and performance |

Not from v1.0.5, so not triaged here: every other v1.1.0 TODO (for example 158, the observational-design split).

## Implementation TODOs

Moved text is verbatim from `release_v1_1_0.md`. Inside it, bare TODO numbers keep their original meaning (mostly
v1.0.5 or v1.1.0 numbers, as the text says); new references here name the file.

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
  - **Scope in v1.0.6:** the per-draw tau fix only. The uncensored-only CI stays in `release_v1_1_0.md → TODO-157`.

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

- [ ] TODO-4 (moved 2026-11-10 from `release_v1_1_0.md → TODO-162`, owner approval of the v1.0.6 triage; originally added 2026-10-27, owner decision at v1.0.5 TODO-162: defer, fix
  (b)): **Block jackknife on SPBR / FixedBlocking leaves out whole strata.**
  `resolve_jackknife_unit()` / `build_jackknife_deletion_draws()`
  (`inference_all_abstract_non_param_boot.R`) use unit "block", and
  `get_block_ids()` (`design_blocking_abstract.R`) returns STRATUM ids, so the
  jackknife has G = 2-4 groups. The delete-a-group variance then has G - 1 df but
  the CI and p-value use z. 1.0.5 canonical CSVs at beta 0: jackknife-Wald coverage
  SPBR 0.838, FixedBlocking 0.860, other designs 0.953; 36/43 classes undercover
  on SPBR by > 0.05. The bias correction `(G-1)*(jack_bar - theta)` also shifts the
  centre when strata are very unequal (fuel 110/36/2: +0.08).
  - Fix (b), owner-chosen: on `DesignSeqOneByOneSPBR`, make the jackknife unit the
    permuted block (`block_size` = 4 subjects; ~37 units at n = 148), which is the
    design's actual randomization unit. Partial trailing blocks: decide (own unit
    or merge into the previous block). FixedBlocking has no permuted blocks: use
    delete-one within strata or the t(G - 1) / minimum-group rule from rejected
    fix (a); decide when implementing.
  - Risk: `get_block_ids()` has other callers (design registry, blocking/optimal-
    blocks designs, CMH and extended-Robins incidence classes, exchangeable
    resampling units, nonparametric and Bayesian bootstrap, jackknife). Do not
    change its meaning; add a separate accessor (e.g. `get_permuted_block_ids()`,
    recorded at assignment time) and use it only in the jackknife unit resolver.
    Run `trail callers` on both before editing.
  - Acceptance: jackknife-Wald coverage at beta 0 on SPBR within 0.93-0.97 across
    the suite; non-blocking designs bit-identical; regenerate SPBR / FixedBlocking
    jackknife rows and retire the 1.0.5 baseline acceptances that cite TODO-162.
  - Pointer: `release_v1_0_5.md → TODO-162` (repro, scratch `todo162/`).

- [ ] TODO-5 (moved 2026-11-10 from `release_v1_1_0.md → TODO-165`, owner approval of the v1.0.6 triage; originally added 2026-11-08, owner; follow-up of v1.0.5 TODO-190): **`InferenceIncidLogBinomial`: tighten the full-data fit when a subject sits at fitted probability exp(X b) = 1.**
  - Found by: the v1.0.5 TODO-190 agent (2026-11-08). In 4 of 1600 calibration fits (all n = 50, `~.`), the C++ fit (`src/fast_log_binomial_regression.cpp`, TODO-128 active-set / KKT gate) stops with the nuisance score off zero: rep 31 at prob_T 0.5 has x2 score 0.037, and Nelder-Mead reaches the same log-likelihood at x2 = 0.46476 vs the kernel's 0.46442. The KKT check in `edi_log_binomial_kkt_terms()` then rejects the null fit near the estimate, the gradient p-value there is `NA`, gradient CI inversion cannot start, and v1.0.5 substitutes the LR interval (with the `edi_lik_ci_lik_ratio_fallback` warning).
  - Related: the same KKT gate also passed a non-optimal warm-started null fit where the binding set changes (v1.0.5 TODO-181 leftover, worked around by a cold refit in `fit_null`).
  - Fix: tighter boundary convergence in the kernel (for example a KKT-residual stopping rule in the free directions), verified per-file (no full build). Then drop or keep the v1.0.5 LR substitution in `compute_gradient_confidence_interval_impl()`.
  - Done when: on the TODO-190 study grid (200 reps x n 50 / 200 x prob_T 0.5 / 0.2 x `~1` / `~.`), no LR substitution fires and the full fit's nuisance score is 0 to 1e-6 at boundary MLEs.

- [ ] TODO-6 (moved 2026-11-10 from `release_v1_1_0.md → TODO-167`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found by the v1.0.5 TODO-62 benchmark regression check): **GLMM / CLMM kernels run the full log-sigma multistart even when given `warm_start_params`.**
  - Why: v1.0.5 TODO-31 (e706c6f6) made `fast_logistic_glmm_cpp` (`src/fast_logistic_glmm.cpp` ~L521-565) and `fast_ordinal_clmm_cpp` (`src/fast_ordinal_clmm.cpp` ~L107-144) screen 5 log-sigma starts, and `fast_poisson_glmm_cpp` (`src/fast_poisson_glmm.cpp` ~L414-472) 5 sigma starts x 2 beta starts, keeping the best objective. The screening also runs when the caller passes a warm start, so warm starts save nothing: on the benchmark pairs fixture, warm-started at the optimum, logistic 46 ms vs 47 ms cold, CLMM 88 ms vs 79 ms cold (2026-11-09 probe, installed EDI). Bootstrap, randomization and CI-search refits that warm-start therefore pay about 5x per refit.
  - Fix: when `warm_start_params` is supplied (and finite, length-checked), start from it alone, optionally plus one cold start, and keep the better objective; keep the full screen for cold fits. Verify per file (no full build).
  - Done when: warm-started refits at the optimum cost about one single-start fit; cold-fit results unchanged bit for bit; resampling results unchanged or with the change explained (a warm start can land in a different mode than the screen, so check on the TODO-31 sigma-collapse datasets).

- [ ] TODO-7 (moved 2026-11-10 from `release_v1_1_0.md → TODO-169`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found computing the v1.2.0 TODO-36 calibration-study truths): **`InferenceIncidModifiedPoisson` with `~1` returns NA at large n.**
  - Why: on the study's incidence generator (5 covariates, beta_T at the n = 200 power50 effect, `DesignFixedBernoulli`, prob_T 0.5, seed 4242) `compute_estimate()` gives 0.249 / 0.257 / 0.256 at n = 200 / 2000 / 5000, then NA at n = 10000 and 20000 with non-estimable reason `model_fit_unavailable`: no error, no warning. `~.` on the same data is fine at n = 20000 (0.206). In `calibrate_study_truths.R` (8 fits of n = 20000 per cell) `~1` failed in 9 of 12 cells, so those power cells have no true value and their non-null coverage goes untested.
  - Investigate first: which fit step reports `model_fit_unavailable` above ~10^4 rows for the treatment-only model (an iteration cap, a convergence tolerance that does not scale with n, or a sandwich-variance step); whether `InferenceIncidKKModifiedPoisson` shares it.
  - Done when: `~1` returns a finite estimate at n = 10000 / 20000 / 50000 on that generator, agreeing with `glm(..., family = poisson)` plus sandwich SEs to 1e-6; a regression test at n = 20000; the truths re-run with the ModifiedPoisson `~1` cells usable.

- [ ] ~~TODO-8~~ **→ moved back 2026-11-11 to `release_v1_1_0.md → TODO-170`** (owner): the 2026-11-11 re-run found no bug; n = 1000 is nominal and the 8 n = 1000 rows were pruned. What is left is a small-sample excess at n = 50, which the entry rule keeps in v1.1.0.

- [ ] TODO-9 (moved 2026-11-10 from `release_v1_1_0.md → TODO-189`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; follow-up of v1.0.5 TODO-179): **Boundary MLEs of the constrained binomial classes: what is left after Wald became NA for `InferenceIncidLogBinomial`.**
  - Done in v1.0.5 TODO-179 (2026-11-09, the "make Wald NA at the boundary (with LR suggested)" idea): `InferenceIncidLogBinomial` returns NA for the Wald p-value and CI when the full-data MLE has a linear predictor within 1e-8 + 1e-6 of 0, with warning class `edi_wald_mle_boundary_unavailable` and `procedure_failure_reason[["wald"]]`; `fit_null` got a strictly feasible last-resort start, so the LR interval at those fits no longer falls back to Wald (526 -> 75 of 1000 at n = 50). Study cell (Bernoulli, `~.`, p = 5, 1000 null reps): Wald NA in 68% (n = 50) / 66% (n = 200) of reps; Wald size over the rest 0.041 / 0.047, coverage 0.959 / 0.953.
  - (a) LR is still oversized at boundary MLEs: size 0.085 (n = 50) / 0.078 (n = 200) in boundary reps vs 0.048 / 0.044 interior; LR coverage 0.924 / 0.934. Candidates: parametric-bootstrap-calibrated LR (`compute_lik_ratio_bootstrap_*`, already supported) as the recommended boundary procedure, or a chi-bar-squared reference.
  - (b) 75 of 1000 LR CIs at n = 50 (7 at n = 200) still fall back to Wald: one null refit at a single delta fails (non-converged) while neighbouring deltas succeed. Overlaps TODO-165 (kernel boundary convergence). Either fix the kernel or let the root search step past one failed refit; and decide whether a Wald fallback under the LR label should itself be NA at a boundary MLE.
  - (c) `InferenceIncidBinomialIdentityRiskDiff` (identity link, bounds at mu = 0 and 1, same TODO-128 warning and `edi_binomial_bound_kkt_core()`) was NOT changed: its Wald path is the generic `StandardModelCache` one, and the identity-link boundary needs its own decision (two-sided bounds; `~1` boundary is a 0% or 100% arm, where the SE is already 0). Measure its boundary share and Wald size in the study cell first. `InferenceIncidRiskDiff` (unpooled Wald, v1.1 TODO-179) does not have this boundary.
  - Accepted rows (2026-11-12): the 2 `InferenceIncidLogBinomial` score `~.` n = 50 prob_T 0.5 rows (size 0.09, coverage 0.915; boundary MLEs) that cited a bare `TODO-179` now cite this TODO.
  - Done when: (a)-(c) are each fixed or ruled honest by the owner, and the LogBinomial / BinomialIdentity accepted calibration rows say which.
  - **Scope in v1.0.6:** parts (b) and (c) only. Part (a) is triaged in TODO-13; its fix, if any, stays in `release_v1_1_0.md → TODO-189`.

- [ ] TODO-10 (moved 2026-11-10 from `release_v1_1_0.md → TODO-190`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; found by bulk CI run 42638595069): **`fast_clogit_plus_glmm_cpp()` stops short of a zero random-intercept variance and still reports `converged = TRUE`.**
  - Found by: `R/package_tests/testthat_bulk/test-prop-kk-glmm-weighted-refit-reference.R`, failing since the v1.0.5 pair-grouping fix (`b1e96231`, TODO-173), which made the kernel fit one random intercept per matched pair instead of one per row. On that test's `InferencePropKKGLMM` fixture (n = 80, KK14, proportion response, `~ x1 + x2`) with block bootstrap weights, the weighted optimum is at sigma = 0: a weighted `glm()` gives beta_T 0.07979 (negative log-likelihood 93.2709), and `glmmTMB` (Laplace) and `lme4::glmer(nAGQ = 20)` agree, both flagging a singular fit. EDI's L-BFGS (`optimize_fixed_likelihood()`, `optimization_alg = "lbfgs"`, `max_abs_log_sigma = 8`) stops after 11 iterations at log sigma = -3.81 with negative log-likelihood 93.2794 and gradient norm 0.22, yet reports `converged = TRUE`, giving 0.08168 (2.4% off). The unweighted fit on the same data agrees with `glmer` to 0.2% (0.11855 vs 0.11878).
  - Interim: the test's tolerance was loosened from 1e-3 to 0.03 (2026-11-09), with a comment pointing here.
  - Investigate first: why `converged` is TRUE at gradient norm 0.22 (a function-change stop that fires on the flat log-sigma direction?); whether other kernels that share `optimize_fixed_likelihood()` with a log-variance parameter (continuous/count KK GLMM, the GLMM Weibull frailty classes) stop short the same way near sigma = 0.
  - Fix (candidates): gate `converged` on the gradient norm; when log sigma runs toward `-max_abs_log_sigma`, refit with sigma fixed at 0 (the plain GLM) and keep the better likelihood; or profile sigma out at the boundary.
  - Done when: on that fixture the weighted estimate matches the weighted `glm()` / `glmer(nAGQ = 20)` value to 1e-4 relative, `converged` is FALSE whenever the gradient norm is above tolerance, and the test's tolerance is back at 1e-3.

- [ ] TODO-11 (moved 2026-11-10 from `release_v1_1_0.md → TODO-192`, owner approval of the v1.0.6 triage; originally added 2026-11-10, owner; from v1.0.5 TODO-1's closing, `finished_features/v1_0_5/reusable_bootstrap.md` TODO-6): **Realistic proportion data for `tune_EDI_for_this_machine()`.**
  - Problem: the tuner's proportion fixture is noiseless. `inference_migration_complete_design()` (`local_machine_tuning_synthetic_fixtures.R`) sets `y = pmin(0.95, pmax(0.05, plogis(linpred)))` with no noise and no exact 0s or 1s (`edi_tuning_synthetic_experiment()` adds zero mass only for zero-inflated/hurdle count classes). Every proportion fit recovers the true coefficient 0.55 exactly, the precision parameter diverges, and jackknife summaries are degenerate (ZOIB: every warm-started fold returns 0.55, SE ~4e-9; NA at n = 50 and 1000). ZOIB's zero/one submodel is never exercised.
  - Effect on the tuner: warm vs cold timings are distorted. The 2026-11-10 ZOIB jackknife A/B (`scratch/v1_0_5_g2_outputs/zoib_jackknife_ab_2026-11-10/`) gave warm start ON 0.76 s vs OFF 10.6 s at n = 200 and 13.0 vs 248 s at n = 1000 (14-19x), likely inflated because cold fits chase a diverging precision. The correctness gate also cannot verify cells whose summary is NA. Applies to every proportion class the tuner times.
  - Fix: add real noise to the proportion response (e.g. a beta draw around `plogis(linpred)` with a fixed precision, seeded as now) and, for classes with a zero/one part (ZOIB), a small share of exact 0s and 1s, the way count classes get structural zeros. Keep the fixtures deterministic per seed. Check every other caller of `inference_migration_complete_design()` (migration goldens) before changing it, or add a separate tuning-only generator.
  - Done when: proportion fits on the tuning fixture give finite, non-degenerate jackknife summaries at n = 50, 200 and 1000; ZOIB's zero/one part is fitted; the ZOIB jackknife A/B is re-measured and recorded; affected golden tests pass or are deliberately updated.

- [ ] TODO-12 (moved 2026-11-10 from `release_v1_1_0.md → TODO-71`, owner approval of the v1.0.6 triage; originally added 2026-10-22, owner decision `release_v1_0_5.md → G6 #14`):
  **Fractional-validity guard for bootstrap p-values with `na.rm`.**
  - Background: v1.0.5 keeps the bootstrap p-value `na.rm = FALSE` default
    and adds a classed warning (G6 #14). With `na.rm = TRUE`, a p-value can
    be formed from a small surviving fraction of replicates without any
    guard.
  - Scope: add a minimum valid-replicate fraction for `na.rm = TRUE`. Below
    it the p-value is nonestimable with a classed reason, mirroring the 5%
    invalid-interval cap used for CIs. Decide the threshold and whether it
    is user-settable. Test boundary fractions. This is a default change only
    for `na.rm = TRUE` calls below the threshold, so document it.
  - Pointer: `release_v1_0_5.md → G6 #14` (maintainer-brief item; no v1.0.5
    TODO entry carries it).

- [ ] TODO-13 (added 2026-11-10, owner approval of the v1.0.6 triage): **Triage the v1.0.5-born calibration and
  test-size TODOs that stay in `release_v1_1_0.md`.** For each, run the check in the "Triage first" table above and record
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

- [ ] TODO-14 (added 2026-11-10, owner; **exception to the entry rule above**: a repository-layout refactor with no
  package code, API or result change): **Repository layout cleanup.**
  - Plan: `../new_feature_plans/v1_0_6/repository_layout_cleanup.md`.
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

- [ ] TODO-15 (added 2026-11-10, owner; **exception to the entry rule above**: new test infrastructure with no package
  code, API or result change): **Native C++ test suite for the R-free core.**
  - Plan: `../new_feature_plans/v1_0_6/native_cpp_test_suite.md`.
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
- [ ] TODO-16 (added 2026-11-11, owner; opened with the accepted calibration rows it covers; bounded investigation
  under entry rule 3 — if it finds no bug, move it to v1.1.0 as a small-sample item): **`InferenceCountZeroInflatedNegBin`
  / `InferenceCountZeroInflatedPoisson`: likelihood and Wald tests oversized at n = 50.**
  - Why: nightly calibration fast tier 2026-11-09 (run 42583252947, commit `749977ab`, 1000 reps, synthetic count DGP,
    `DesignFixedBernoulli`) failed 20 cells with no accepted rows:
    - ZINB, both prob_T: all four tests with `~.` (size 0.100-0.144; score worst, 0.131 / 0.144; Wald 0.121 / 0.137),
      score `~1` (0.117 / 0.113), and Wald `~1` at prob_T 0.2 (0.094).
    - ZIP: every test at prob_T 0.2, both formulas (0.084-0.118; Wald worst), and Wald `~.` at prob_T 0.5 (0.093).
    - At n = 200 both classes pass, but are still somewhat high (worst size 0.074 / 0.072).
    - Accepted rows (reason starting `v1.0.6 TODO-16`) are in
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
  - Done when: the cells pass the fast-tier gate at nominal and the `v1.0.6 TODO-16` rows are pruned; or the owner
    rules the excess inherent, and the rows stay with a reason saying why. A "Small samples" roxygen note is added to
    both classes if any rows remain at release.

- [ ] TODO-17 (added 2026-11-11, owner; **exception to the entry rule above**: calibration-study infrastructure with no
  package change, like TODO-14/15): **Stop clearly passing null cells early in calibration campaigns.**
  - Why: TODO-21 (was v1.0.5 TODO-203) made campaigns class-major and Amendment E sized shards from measured costs, but the remaining
    time is the fits themselves. Campaign `2026-11-11-9d2edc5c` predicted about 14,700 core-hours of screening, so
    about 11 days of screening plus 1-2 days of confirmation on 16 free runners. Most null cells sit far inside their bound
    long before 1000 replicates.
  - Idea: two looks per null unit (one class with all its procedures, one design, one n), for example at 500 and 1000
    replicates. At the first look, a unit stops if every test in it (size for each procedure and formula, plus
    coverage from the same replicates) is clearly inside its bound; borderline units run to 1000 as today. Rough saving:
    30-50% of null work, several days per campaign.
  - Design questions to settle before any code (owner decision):
    - Stopping only for "clearly passing" is non-binding futility stopping: it cannot add false flags, but it lowers the
      power to flag a mildly miscalibrated cell (for example a true size of 0.06). Choose the first-look margin from the
      power that must be kept, and check it by simulation of the planner with known true sizes.
    - Multiple testing: the campaign runs Benjamini-Hochberg over every test in the plan with unrun tests as p = 1, so
      interim flags are never withdrawn. Define the p-value of a stopped unit (its first-look p-value is valid under
      non-binding futility) and show that this keeps `m_total` and the monotonicity argument intact.
    - Precision and the convergence analysis: stopped units have wider intervals; the |error| vs n_eff slopes and
      the per-class pages must weight by replicates actually run, and the README must say which units stopped.
    - Estimates after a sequential stop are slightly biased; say whether the published size/coverage use them as they are.
    - Confirmation replicates (5,000 at 0.01 / m_total) are unchanged.
  - Where: `R/package_tests/calibration/plan_calibration_study.R` and `calibration_study_plan_common.R` (units, looks),
    `analyze_calibration_study.R` / `convergence_calibration_study.R` (p-values, weighting), `calibration_gates.md`.
  - Done when: the rule is written into `calibration_gates.md` with its power check, the planner stops units at the first
    look, a synthetic-campaign test shows no change in false-flag rate and the agreed power, and one campaign completes
    with it.
- [ ] TODO-18 (added 2026-11-12, owner; **exception to the entry rule above**: the owner placed it in v1.0.6 although a
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

- [ ] TODO-19 (moved 2026-11-12 from `release_v1_0_5.md → TODO-196`, owner decision; originally added 2026-11-10, owner;
  **exception to the entry rule above**: it ships new data to users rather than fixing a bug; the owner moved it here so
  v1.0.5 does not wait for a complete calibration campaign): **Ship the measured size / coverage / bias per design x
  class x procedure x n from the latest complete campaign inside the package (with campaign id and EDI commit), and
  surface it next to the expected rate.** GATED on the first complete calibration campaign (`2026-11-09-8c32d060` or
  its successor under TODO-21's class-major order). Plan:
  `new_feature_plans/v1_0_5/inference_validity_user_visibility.md`, section 3. The consumer hook already exists:
  `edi_procedure_validity_measured()` in `R/EDI/R/inference_validity_lookup.R` returns `NULL` until this lands
  (v1.0.5 TODO-197).

- [ ] TODO-20 (moved 2026-11-12 from `release_v1_0_5.md → TODO-202`, owner decision, so v1.0.5 does not wait on the
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

- [ ] TODO-21 (moved 2026-11-12 from `release_v1_0_5.md → TODO-203`, owner decision; originally added 2026-11-10, owner;
  builds on v1.0.5 TODO-199/200/201; **exception to the entry rule above**: calibration-study infrastructure with no
  package behavior change, like TODO-17): **Run calibration campaigns in class-major order and publish one convergence
  page per class.** Order: null before non-null; within an effect, response type, then inference class, then design,
  then n = 50 / 200 / 1000, then the class's confirmation replicates, so verdicts become final class by class instead of
  only at campaign end (today the planner sorts by n first, so campaign 2026-11-09-8c32d060 showed only n = 50 after 13
  waves). The unit of work is one class with all its procedures (they share a fit). Multiple-testing control over the
  whole campaign: Benjamini-Hochberg over every test in the plan with unrun tests as p = 1 (interim flags are then never
  withdrawn), confirmation at 0.01 / total tests. The convergence analysis is final per class once it has all n. One
  page per class with one figure (procedure rows x metric columns, |error| vs n_eff log-log, expected slope, verdict,
  effects as colours); summary figures stay separate. Measure the cost of re-running each design per class first; cache
  assignments if it exceeds about 10%. After it is pushed the owner cancels the running campaign and starts a new one.
  Plan: `new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md`. Current state: IMPLEMENTED 2026-11-10 (not
  committed): class-major planner with a committed class roster, campaign-wide BH with `m_total` and a fixed
  confirmation level, per-class status, convergence `provisional` per class, per-class pages and figures, Classes index;
  Step 0: repeated design cost 7.5% unpacked / 2.7% packed, no assignment cache. Shards pack neighbouring cheap classes
  (deviation, see the plan's Done). Owner: review, push, cancel campaign `2026-11-09-8c32d060`, dispatch a new one.
  Amendment A (owner, 2026-11-10): the class roster is generated per campaign by a new `roster` job from the EDI built
  at the pinned sha (first wave) and stored in the campaign folder, replacing the hand-built committed
  `calibration_study_roster.csv`; see the plan's Amendment A. **Amendment A IMPLEMENTED 2026-11-10 (uncommitted):** the
  class roster is no longer committed; a new workflow job `roster` (plan -> build -> roster -> shards -> analyze ->
  publish) enumerates it from the EDI built at the pinned sha in a campaign's first wave and publishes it as
  `<campaign>/roster.csv`; later waves reuse it; costs from the previous published campaign, else 2 s default; see the
  plan's "Amendment A: Done". Amendment B (owner, 2026-11-10): the design list is discovered from the installed EDI's
  exported designs minus a documented exclusion list (cluster, blocked cluster, factorial), replacing the hand-kept
  CAL_STUDY_DESIGNS / CAL_PLAN_DESIGNS; see the plan's Amendment B. Amendment C (owner, 2026-11-10): every design
  capable of unequal allocation also runs at prob_T = 0.2 (discovered from the registry, not hand-listed). **Amendment B
  and C IMPLEMENTED 2026-11-10 (uncommitted):** designs are discovered from the installed EDI (`cal_study_designs()`,
  exclusion list with reasons, smoke check that fails the roster job naming a design that cannot be built), the roster
  carries `design_rank`, no hand-kept design list in the planner/runner; 33 labels (11 added `@prob_T=0.2`), +687 roster
  rows, about +3,560 core-hours (+35%); RandomBlockSize / SPBR get 5-multiple blocks at 0.2; package R files touched (no
  compile): `inference_procedure_regime.R` (generic `@prob_T` registry key), `inference_validity_n_eff.R`,
  `inference_small_sample_doc.R` (Rd to regenerate); see the plan's Amendment B/C: Done. Amendment D DONE 2026-11-11:
  the matched-design list comes from the package (`is_a_kk_matching_capable()`, recorded in the roster), not a hand
  list. Amendment E DONE 2026-11-11 (uncommitted): the wave planner takes each class cost from the campaign own finished
  shards (stats/tests.csv.gz per class, ledger for the per-pack overhead) with a fallback chain to the roster, and tops
  up shards predicted under a third of the target with further classes of the same cell; see the plan Amendment E.
  **Status at the move (2026-11-12):** the implementation, including Amendments A-E, is committed (`fe267250` and later;
  working tree clean at `57df40d4`), so the "(uncommitted)" / "(not committed)" notes above are history. Left: owner
  review, push, cancel campaign `2026-11-09-8c32d060`, dispatch a new one.

- [ ] TODO-22 (added 2026-11-14, owner; found by the new worker-count invariance tests of `release_v1_1_0.md` TODO-48 (2)):
  **`InferencePropGCompMeanDiff` bootstrap results depend on the worker count.**
  - Symptom: same seed, `compute_bootstrap_confidence_interval` (proportion, n = 40, B = 39, seed 99) gives serial
    [-0.0104, 0.1352], fork 2 workers [0.0093, 0.1184], fork 4 [0.0031, 0.1459], mirai 2 [0.0006, 0.1494], mirai 4
    [-0.0003, 0.1256]. Each worker count reproduces itself, so it is not chance. `compute_bootstrap_two_sided_pval` is
    affected too (0.0769 serial vs 0.0513 at fork 2 and 4 and mirai 4; mirai 2 matched serial, likely a serial
    fallback; first nightly sweep, 2026-11-14). The Bayesian bootstrap is invariant.
  - Unverified guess: the class's bootstrap worker draws random numbers inside the workers (per-worker or per-chunk
    streams) instead of using only the resample indices drawn up front. Compare with the 2026-09-22 stale worker-cache
    resampling fix, which touched this class's resampling path.
  - Test: `R/EDI/tests/testthat/helper-worker-count-invariance.R` lists `bootstrap_ci` and `bootstrap_pval` in
    `worker_invariance_known_failures`. Known failures are reported (`known_failure` column), not asserted either way,
    because a run that falls back to serial matches; remove the entries once fixed.
  - Also: the full sweep (`EDI_EXHAUSTIVE_WORKER_TESTS=true`, nightly on the Ubuntu reproducibility leg since
    2026-11-14) stopped at this class in its first local run, so other classes may fail too; triage what the first
    nightly sweep reports here.
    Triaged 2026-11-18: the nightly sweep (run 44287229233, leg `ubuntu-latest-release`, commit `39721ef9`) ran every
    concrete exported non-KK, non-IVWC registry class with every procedure at 1, 2 and 4 cores on fork (~13.5 min) and
    mirai (~19.5 min) and found no other difference: this class's two known-failure entries are the only open cases.
  - Fixed 2026-11-18 (the 2026-11-17 thread audit's diagnosis held): `approximate_bootstrap_distribution_beta_hat_T()`
    in `R/EDI/R/inference_proportion_gcomp.R` drew each resample inside the worker chunk, from the chunk's own RNG
    stream (fork: L'Ecuyer per worker; mirai: seed + chunk). Now every replicate's first resample and a per-replicate
    redraw seed (for resamples the screening rejects) are drawn serially before the split. The known-failure list is
    empty, the class is an asserted representative for `bootstrap_ci` and `bootstrap_pval`, and
    `testthat_bulk/test-prop-gcomp-bootstrap-core-count-invariance.R` is unskipped (1, 2, 4 cores `identical()`).
    Fork and mirai registry sweeps pass locally (source tree, `load_all(compile = FALSE)`). Tick after the next
    nightly exhaustive sweep passes on the fix.
  - Done when: results are `identical()` at 1, 2 and 4 workers on both backends, the known-failure entry is removed, and
    the nightly sweep passes.
- [ ] TODO-23 (added 2026-11-15, owner; found by the first scheduled-mode run of the nightly argument-combination job,
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
- [ ] TODO-24 (added 2026-11-15, agent, owner request to allowlist the remaining path-audit gaps with TODO citations;
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
- [ ] TODO-25 (added 2026-11-15, agent; owner accepted these into `comprehensive_results_audit_baseline.csv` the same day):
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
- [ ] TODO-26 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710):
  **`InferenceIncidExactZhang`: the exact CI did not invert its own combined test on matched designs.** At the null, the
  test's size was 0.02-0.05 everywhere, but CI coverage was 1.00 on `DesignFixedBinaryMatch` at every n and 0.85-0.88 on
  `DesignSeqOneByOneKK21` / `KK21stepwise` at n = 1000 (should be about 1 - size).
  - Cause: `zhang_ci_exact_combined()` (`R/EDI/R/inference_helpers_zhang.R`) started both endpoint bisections from the
    reservoir-only log odds ratio. With no reservoir it is always 0, so the interval always held 0; with a small reservoir
    it is noise the matched pairs outweigh, and a start the test rejects sends the bisection to a wrong endpoint.
  - Fixed 2026-11-16 (uncommitted): new `zhang_ci_inside_point()` starts the search from a point the combined test
    accepts (reservoir estimate, matched-pairs conditional MLE, their inverse-variance blend, else the maximiser of the
    combined p-value). Also fixes the `type = "Zhang"` randomization CI for incidence, which calls the same helper.
    Regression test `R/EDI/tests/testthat/test-zhang-exact-ci-inverts-combined-test.R`; the migration goldens in
    `test-exact-incidence-migration-baseline.R` are unchanged. Simulated (installed EDI with the patched helper, 300 null
    reps, BinaryMatch): n = 50 coverage 1.00 -> 0.973, n = 200 1.00 -> 0.97, size 0.027; KK21 n = 1000 (150 reps, same seeds): coverage 0.90 -> 0.947, size 0.053, test and CI agree on every rep; the test and the CI now disagree
    only where the two-sided exact binomial p-value jumps at delta = 0 itself (1 of 300 reps).
  - Watch out: the exact two-sided binomial p-value is discontinuous at delta = 0 (p0 = 1/2), so an endpoint can land
    within 1e-7 of 0 while the test accepts at exactly 0. That is a property of the test, not of the search.
  - Done when: the next calibration campaign (run at a commit with the fix) passes the Zhang coverage cells on KK21 and
    KK21stepwise at n = 1000 and BinaryMatch coverage is about 1 - size.
- [ ] TODO-27 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
  pending): **`InferenceIncidKKCondLogitGLMMOneLik`: likelihood-ratio and score tests oversized at n = 50 on matched
  designs, and the LR test disagrees with its own CI.** Null, `~.`, n = 50: LR size 0.188 (BinaryMatch), 0.198 (KK21),
  0.180 (KK21stepwise), against a 0.10 cap, while LR CI coverage is 0.99-1.00; score size 0.286 (BinaryMatch).
  - Why it looks like a bug, not small-sample noise: a test that rejects 19% of the time paired with an interval that
    covers the null 99-100% of the time means the CI is not the inversion of the test (compare TODO-26). Check whether
    the LR p-value and the LR CI use the same null fit (`fit_null`) and the same reference distribution; the model was
    rewritten in v1.0.4 (conditional logit on discordant pairs plus a reservoir logit, TODO-187).
  - Done when: the cause is found; either fixed (the cells pass the calibration gate) or accepted with a reason and rows
    in `R/package_tests/calibration/calibration_study_accepted.csv` citing this TODO.
- [ ] TODO-28 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
  pending): **`InferenceIncidKKNewcombeRiskDiff`: Wald size 0.159, coverage 0.841 at n = 50 on
  `DesignSeqOneByOneKK21stepwise`** (`~.` and `~1` identical; cap 0.10 / 0.90). Not seen on the other KK designs at
  n = 50 so far.
  - Investigate first: the KK21stepwise match/reservoir split at n = 50 (few pairs or a tiny reservoir) and how the
    Newcombe hybrid interval combines the two parts; whether n = 200 passes.
  - Done when: fixed, or accepted as small-sample with a reason and calibration_study_accepted.csv rows citing this TODO.
- [ ] TODO-29 (added 2026-11-16, agent, owner request; found by calibration campaign 2026-11-15-e36c7710, confirmation
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
- [ ] TODO-30 (added 2026-11-16, agent, owner request; found while gating randomization warm-start chaining on
  `likelihood_concave`): **`InferenceCountZeroInflatedPoisson`: randomization replicates are stuck at the full-data
  fit's zero-inflation ridge, so the randomization distribution is wrong.**
  - Repro: `set.seed(3)`, n = 80, `DesignFixedBernoulli`, `~ x1 + x2`, y zero-inflated Poisson
    (inflation `plogis(-0.8 + 0.3 w - 0.3 x1)`, mean `exp(0.3 + 0.2 w + 0.2 x1 - 0.1 x2)`), `set_seed(11)`, 30
    permutations. The full-data fit has zero-part intercept -23.8 and zero-part treatment coefficient +23.8 (a flat
    ridge where the two cancel). Its count-part treatment estimate is 0.806, which matches `pscl::zeroinfl`.
  - Wrong output: all 30 warm-started replicates differ from a fresh fit on the same permuted data, by up to 0.84. The
    fresh fits match `pscl::zeroinfl` exactly, and on four replicates an independent multistart fit confirms they are
    the maximum. The warm-started replicates sit 0.05-1.3 log-likelihood units lower. With warm starts disabled
    (`fit_warm_start_enabled = FALSE`, `null_fit_warm_start_enabled = FALSE`), every replicate equals the fresh fit.
  - So the fitter is fine; the warm start is the cause. Neither anchoring every replicate to the full-data fit (now the
    behaviour for nonconcave classes) nor the old chaining fixes it: chaining was also wrong, and order-dependent.
  - Same family as the 2026-11-03 ZINB/ZIP score-CI finding (flat zero-inflation ridge) and the CI-search guard in
    `inference_count_zero_augmented_poisson_abstract.R` (TODO-169, "refit from the full fit, keep the lower nll").
    That guard does not help here, because its alternative start is the same ridge point.
  - Fix candidates, cheapest first:
    1. Do not use a warm start whose zero-part coefficients are on a ridge or boundary. That means
       `zero_inflation_at_boundary`, or zero-part coefficients that are large and cancel. Cold-start those replicates
       instead (the TODO-128 log-binomial pattern of dropping boundary warm starts).
    2. Fit from the warm start and a cold start, and keep the lower nll. This doubles the cost of each replicate, so
       use it only when 1 flags the warm start.
  - Scope to check: the other resampling paths that warm-start from the full-data fit (nonparametric bootstrap,
    jackknife, parametric bootstrap, rand CI search); ZINB and the hurdle classes; and ZOIB, which has the same
    inflation structure.
  - Done when: on the repro, every randomization replicate (and every bootstrap and jackknife replicate in scope)
    equals the fresh fit to 1e-6, and that check is a regression test; NEWS records that ZIP randomization and
    bootstrap results change.
- [ ] TODO-31 (added 2026-11-16, agent, owner request; found by the algorithm-audit re-review of drift issue #8, row L,
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
- [ ] TODO-32 (added 2026-11-16, agent, owner request; found by the algorithm-audit re-review of drift issue #8, row E,
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
- [ ] TODO-33 (added 2026-11-16, agent, owner request; carries out `new_feature_plans/v1_1_0/cross_platform_reproducibility.md`
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
- [ ] TODO-34 (added 2026-11-16, agent, owner request; found by `test-same-binary-determinism-registry.R`,
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
- [x] TODO-35 (added 2026-11-16, agent, owner request; found by `test-same-binary-determinism-registry.R`,
  cross-platform TODO-2; cause unconfirmed): **Randomization p-values of `InferenceIncidBinomialIdentityRiskDiff`,
  `InferenceIncidKKCondLogitGLMMOneLik` and `InferenceOrdinalGCompMeanDiff` depend on the worker count.**
  - Symptom, stable in 3 of 3 runs: the permutation draws match, but per-replicate estimates differ by 1e-11 to 1e-3
    at 4 cores. KKCondLogitGLMMOneLik even has a different number of NA (non-converged) replicates: 22 serial vs 6.
  - Guess: the solver warm start is carried from one replicate to the next (`set_fit_warm_start` /
    `fit_warm_start`). The chain of starting values, and so where an iterative fit stops, then depends on how the
    replicates are split among workers.
  - Check first: TODO-30's work now anchors every replicate to the full-data fit for non-concave classes. Re-run the
    same-binary test on the current tree; this may already be fixed for some of the three.
  - Investigate (bounded): for each class, compare serial and 4-core replicates with warm starts disabled
    (`fit_warm_start_enabled = FALSE`). Stop condition: if they are identical, the warm start is the cause, and the
    fix is to anchor to the full-data fit (or cold-start). If not, find the worker-dependent state. Also explain why
    the NA count changes, because a converged/non-converged split that depends on the start is a correctness issue,
    not just reproducibility.
  - Done when: the three entries are removed from `SAME_BINARY_KNOWN_FAILURES` and the same-binary test passes. NEWS
    notes any p-value change.
  - Fixed 2026-11-19 by TODO-61 (agent; owner accepted TODO-61 the same day). The "check first" step above was wrong
    when written: the 2026-11-16 rule anchored only non-concave classes, and all three of these still chained (two are
    listed as concave; `OrdinalGCompMeanDiff` is on neither list, so NA). TODO-61 removed chaining between replicates
    for every class. On the current tree, `test-same-binary-determinism-registry.R` (`load_all(compile = FALSE)`)
    passes for all three in 3 local runs; only the Bai entries (TODO-34) still fail. Their three entries were removed
    from `SAME_BINARY_KNOWN_FAILURES`. NEWS: covered by TODO-61's entry.
- [ ] TODO-36 (added 2026-11-16, agent, owner request; found by nightly run 43877847174): **Make KK21 and KK21stepwise
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
- [ ] TODO-37 (added 2026-11-17, agent, owner request; noticed by the 2026-11-17 algorithm-research triage of run
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
- [ ] TODO-38 (added 2026-11-17, agent, owner request; found by the 2026-11-17 algorithm-research triage of run
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
- [ ] TODO-39 (added 2026-11-17, agent, owner request; found by the 2026-11-17 algorithm-research triage of run
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
- [ ] TODO-40 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `clmm-ordinal-mixed-fit#43925959437.1`, see `audits/research_triage_drafts.md`): **KK CLMM/GLMM Bayesian-bootstrap
  replicates: check clmm's per-observation weight semantics**
  - Step 1 (bounded): for one KK ordinal dataset and one Bayesian-bootstrap weight draw, evaluate clmm's weighted
    -logLik and a direct sum_g w_g log integral (same theta, 20-node GH) and compare; also compare replicate
    beta_hat_T between the two objectives over 200 draws at n in {50, 200}.
  - Done when: either the objectives agree (close as not a bug) or they differ and the owner rules on the intended
    weighting; if a fix is ordered, add w_g to GLMMObjective/OrdinalGLMMObjective, switch the callers, and report
    replicate CI coverage plus per-replicate time vs clmm.
- [ ] TODO-41 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
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
- [x] TODO-42 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `sequential-biased-coin-designs#43925959437.1`, see `audits/research_triage_drafts.md`): **Sequential designs:
  draw_ws_raw overwrites the live design's w (CMH SE path)**
  - Related: v1.2.0-TODO-22.
  - Reproduce: build an urn (or other generic-draw_ws_raw sequential) design, run InferenceIncidCMH's SE path
    (inference_incidence_cmh.R:196), then compare des$get_w() and a second Inference's estimate before and after. If w
    changes, fix by saving/restoring private$w (and t-dependent state) in draw_ws_raw or by drawing on a duplicate.
  - Done when: a regression test shows get_w() and downstream estimates unchanged after the CMH SE call, or the check
    closes with evidence that no reachable path mutates a live design.
  Done 2026-11-19 (agent, uncommitted): the generic `draw_ws_raw()` replay (used only by Urn and
  `DesignCustomSequential`) now saves `private$w` and restores it via `on.exit()`. All 11 sequential designs checked:
  no private field changes after redraws (seeded/unseeded, completed and mid-trial); CMH SE path leaves state
  unchanged. New `test-sequential-design-redraw-leaves-design-state-unchanged.R`; 49 related files (2,633
  expectations) pass; negative control fails as expected. Follow-ups found: v1.0.6-TODO-183.
- [ ] TODO-43 (added 2026-11-17, agent, owner request; from the dead code behind three rejected findings of the
  algorithm-research triage of run 43925959437, see the Rejected section of `audits/research_triage_drafts.md`; each
  "no caller" claim was checked against the code on 2026-11-17): **Remove three dead C++ code paths.**
  - `compute_coxph_rand_bootstrap_cpp` (`src/fast_coxph_regression.cpp` ~L1135; finding
    `resampling-refit-loop#43925959437.2`): no caller in R or C++, and only a reference test calls it
    (`R/package_tests/testthat_bulk/test-rand-bootstrap-statistic-kernels-coxph-jt-and-km-diff-reference.R` ~L28). It
    is exported (`NAMESPACE` L147) but documented `@keywords internal` (`man/compute_coxph_rand_bootstrap_cpp.Rd`).
    Delete it, its export, Rd page and test case, and add a NEWS line (an exported internal kernel is removed). If the
    owner prefers, deprecate it instead, as v1.0.6-TODO-38 does for `robust_negbinreg`.
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
- [x] TODO-44 (added 2026-11-17, agent, owner request; found by the case-study article agent): **Covariate *(ticked by the TODO audit 2026-11-17: R/EDI/R/design_abstract.R:1142; R/EDI/R/design_abstract.R:1151; R/EDI/man/Design.Rd:318; R/EDI/R/design_abstract.R:186; R/EDI/REFERENCES.md:212; R/package_tests/testthat_bulk/test-covariate-imputation-ignores-outcome.R:34; R/package_tests/testthat_bulk/test-design-missingness-impute-missranger-fa...)*
  imputation must not use the outcome.** `missingness_method = "impute"` (`R/EDI/R/design_abstract.R`,
  `covariate_impute_if_necessary_and_then_create_model_matrix()`) gave missRanger/missForest the response
  (`get_effective_time()`) as an extra predictor but not the assignment. Treated subjects have shifted responses, so
  the imputed covariate carried part of the treatment effect, and adjusting for it biased the estimate toward 0
  (`InferenceContinOLS`, n = 200, true effect 1, 30% of x missing, 150 reps: mean 0.900 (MC SE 0.014), 95% CI
  coverage 0.91; complete data 0.988 and 0.97). The imputation was also unseeded, so the same data gave slightly
  different estimates, and it advanced the caller's RNG.
  - Done 2026-11-17: impute from the covariates only; seed with the design's `seed`, else 1, inside a
    `.Random.seed` save/restore. After the fix the same simulation gives 0.996 (MC SE 0.018) and coverage 0.93.
    Roxygen and `man/Design.Rd` updated by hand (no interim roxygenize). Test:
    `R/package_tests/testthat_bulk/test-covariate-imputation-ignores-outcome.R` (fails on 1.0.4, passes now);
    the missForest-fallback test's wording updated. The randomization test under the sharp null was never affected
    (imputation ran once with y fixed and w unused).
  - The two articles that described the old default (`vignettes/articles/case-study.Rmd`,
    `vignettes/articles/analyzing-an-existing-experiment.Rmd`) are updated; the case study re-rendered on the new
    code (adjusted HR 0.68 (0.54, 0.86), unchanged to two decimals; its blocked and unblocked designs now give the
    identical estimate).
  - Single imputation does not understate the variance here (owner question 2026-11-17): the imputed covariate is
    outcome- and assignment-free, so it is just an adjustment covariate (Freedman 2008; Lin 2013). Checked: 600
    trials, fresh imputation seed each, MAR missingness: coverage 0.958 (linear) and 0.945 (nonlinear outcome),
    MC SE 0.009; on one dataset the estimate's SD across 30 imputation seeds was 0.001 vs SE 0.186. The argument
    and numbers are in the `missingness_method` roxygen (`Design.Rd`); Freedman2008 added to `REFERENCES.md`.
  - Still to do: a NEWS line under the next release's heading (imputed values and covariate-adjusted estimates change
    for data with missing covariates, and are now reproducible).
- [ ] TODO-45 (added 2026-11-17, agent, owner request; found by the matching-on-the-fly article agent): **KK14's
  match test was twice as strict as published.** `DesignSeqOneByOneKK14$assign_wt()` compared the full
  d'S^-1 d (`compute_proportional_mahal_distances_cpp`, stored as `sqd_distances_times_two`) with the Hotelling
  cutoff p(n-1)/(n-p) F_{p,t-p}(lambda). The statistic is half of that (the difference of two exchangeable
  subjects has covariance 2 Sigma); SeqExpMatch 0.1.0 (`R/design.R` ~L396, CRAN archive) used `1 / 2 * t(d) %*%
  S_inv %*% d`. The halving was lost in the C++ port.
  - Done 2026-11-17 (R only, no recompile): `T_sq = ... / 2`; roxygen and `DesignSeqOneByOneKK14.Rd` give the
    formula. Effect (4 covariates, 2 prognostic, 400-600 null trials): mean pairs at n = 40 went 8.5 -> 14.0 of 20,
    at n = 100 31.5 -> 42.0 of 50 (KK21: 14.8 and 43.1). `InferenceContinKKOLSOneLik` Wald size: n = 40 7.2% ->
    6.3%, n = 100 5.0% -> 5.0% (MC SE about 1 point; KK21 5.8% and 4.7%).
  - Re-pinned 2026-11-17 (agent; R/EDI/tests/testthat). A useful rule: with p covariates the F(p, .) cutoff near
    0 scales like lambda^(p/2), so lambda = 0.1 * 2^(-p/2) (0.07 for p = 1, 0.05 for p = 2) brings back roughly the
    old allocation; most re-pinned fixtures use it (checked: allocation identical to the pre-fix one unless noted).
    `test-cross-platform-reproducibility-digests.R`: fixture regenerated with EDI_REPRO_WRITE_FIXTURE and
    EDI_REPRO_OVERWRITE_FIXTURE; only the two DesignSeqOneByOneKK14 rows changed (KK21 unchanged: that case reveals
    responses, so KK21 is past its KK14 fallback). `test-incid-kk-newcombe-migration-golden.R`: the legacy
    score/gradient/LR CIs were still the Wald fallback but 1.4e-6 (relative) off the closed-form Wald CI, past the
    test's 1e-10; that is `pval_invert_ci_cpp`'s root tolerance, and about half of seeds show it with or without the
    fix, so the design seed moved to 20260820 (exact). `test-weibull-frailty-loggamma-null-boundary.R`: KK14 fixture
    now `lambda = 0.07` (same 16 pairs, same goldens). `test-kk-ivwc-compound-focused-regression.R`: single-pair
    fixture `lambda = 0.05` (same one pair).
  - Bulk sweep 2026-11-17: all 264 files under `R/package_tests/testthat_bulk/` that name KK14/KK21 run against the
    source (EDI_PREPUSH_NO_PARALLEL=true), and failures rerun on a copy with the `/ 2` reverted. 17 fail only with the
    fix, none fail in both. Fixed (fixture lambda, comment cites this TODO): the three
    `*-ivwc-shared-matched-reservoir-combination-branches-reference.R` files (quantile, Weibull-frailty-normal,
    hurdle-Poisson; `lambda = 0.07`), `test-kk-ols-ivwc-weighted-passthrough-reference.R` and
    `test-kk-rank-regr-ivwc-weighted-passthrough-reference.R` (0.05), `test-randomization-fast-path-wiring-reference.R`
    (KKOLSIVWC case 0.05; 3 pairs again, not the same 3), `test-kk-weibull-marginal-jackknife-arm-event-guard-reference.R`
    (0.05), `test-kk-clogit-onelik-pairs-and-reservoir-only-branches-reference.R` (0.07; the new seed-2 reservoir was
    perfectly separated, so the glm reference diverged).
  - Still to do: 9 fix-dependent bulk files, not re-pinned because several look like real discrepancies the old
    fixture hid rather than stale pins. Reference parity: `test-kk-gee-parity.R` (EDI GEE vs geepack, incidence
    estimate 3.2e-3 relative apart vs 1e-3 tolerance; 2-4e-3 is typical across families and seeds),
    `test-kk-gee-weighted-refit-reference.R` (weighted refit -0.616 vs geepack -0.581),
    `test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` (cloglog 0.815 vs ordinal::clmm 0.776 and 0.259 vs
    0.280), `test-ordinal-kk-clmm-boundaries-coverage.R` (Cauchit weighted refit 3.8e-5 off),
    `test-ordinal-kk-clmm-migration-golden.R` (Probit/Cloglog legacy vs migrated jackknife/randomization 1-3e-6 apart
    vs 1e-7), `test-incid-kk-modified-poisson-weighted-refit-reference.R` (SE 1.2e-6 off). Premise is data
    dependent: `test-contin-kk-quantreg-onelik-stacked-weighted-reference.R` (weights no longer move the estimate by
    1e-4), `test-proportion-kk-classes-match-logit-stacked-quantile-and-quasibinomial-references.R` (expects GEE/GLMM
    more than 0.1 from the Gaussian-logit fit; now 0.05). These two re-pinned 2026-11-17 (agent): the quantreg
    divergence test moved to design seed 8 / weight seed 9 and also checks the independent rq() rebuild (median
    regression is piecewise constant in the weights, so seed 4 moved only 1.1e-6); the GEE/GLMM test keeps seed and
    0.1 but draws Beta responses with phi = 4 instead of 8 (the logit(E[y]) vs E[logit(y)] gap is a method property,
    about 0.11 in population at phi = 8 and 0.22 at phi = 4; the old pass was seed luck). Possible bug: `test-design-inference-introspection-audit.R`
    "no silently masked capability for KK/incidence" finds a status 'ok' row with a non-finite estimate (an exact
    Fisher log-odds of Inf is reported as ok). Not yet run: the KK rows of the comprehensive/calibration
    baselines, which change: `comprehensive_tests_{size,power,coverage,mse}.csv` (KK21stepwise rows, where KK21
    falls back to KK14 before 2(p+2) responses), `calibration/calibration_study_accepted.csv` (18 KK14 and 36 KK21
    accepted rows to re-review), and the timing files `calibration/calibration_study_costs.csv` and
    `cloud/comprehensive_study_costs.csv`. NEWS line (KK14 forms more matches; seeded KK14 allocations change; the
    digest fixture's header asks for one). `test-designs.R`'s "DesignSeqOneByOneiBCRD works" failure is unrelated
    (fails with or without the fix).
- [ ] TODO-46 (added 2026-11-17, agent, owner request): **KK21 / KK14 doc and API fixes from the matching-on-the-fly
  article.**
  - Done 2026-11-17: `morrison = TRUE` was documented on KK21/KK21stepwise as switching to Morrison's
    calibration but nothing reads it; it now warns ("not implemented yet") and the docs say it is reserved.
    The KK21 docs cited "Morrison and Owen (2025)"; now Morrison, T. (2025), arXiv:2505.17247, as in
    REFERENCES.md. Full KK21 citation added (Kapelner and Krieger 2023, Biometrics 79(1) 216-229, online 2021,
    doi:10.1111/biom.13561, verified on Crossref) to both classes and REFERENCES.md. `response_type` docs list
    "ordinal" (checked: both classes run with ordinal responses). `get_block_ids()` errored "improperly sized"
    mid-trial on sequential designs (y pre-allocated to n, ids sized to t); fixed in `design_blocking_abstract.R`.
    `test-permutations.R`'s morrison test now expects the warning.
  - Not reproduced: an R segfault under `Rprof` in a KK21 loop (5 profiled n = 100 runs at 2 ms were clean).
  - Still to do: implementing Morrison's calibration itself, if wanted (the v1.2.0 KK14 incremental-covariance
    note already mentions the argument); the power-simulation scripts in `R/package_tests/*bai_et_al.R` pass
    `morrison = TRUE` and have been running the standard schedule all along.
- [ ] TODO-47 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **KK GEE
  weighted refit disagrees with its reference by 6%.** On the data the corrected KK14 threshold produces,
  `R/package_tests/testthat_bulk/test-kk-gee-weighted-refit-reference.R` gets -0.616 from EDI vs -0.581 from the
  reference. Also `test-kk-gee-parity.R`: EDI's GEE vs geepack differ by 3.2e-3 relative against a 1e-3
  tolerance, and 2-4e-3 is typical on other data, so that tolerance looks fitted to its old fixture. The old KK14
  fixture hid both. Find which side is wrong (working correlation, weights, convergence tolerance, or the
  reference call) before re-pinning either test; do not restore the old fixture with a smaller `lambda` to make
  them pass. Done when the two agree to a justified tolerance on several seeds.
- [ ] TODO-48 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **KK
  ordinal CLMM cloglog link disagrees with `ordinal::clmm`.** On the new KK14 data,
  `R/package_tests/testthat_bulk/test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` gets 0.815 vs clmm's
  0.776 (and 0.259 vs 0.280) for the cloglog link; the other links agree. Related small gaps on the same data:
  `test-ordinal-kk-clmm-boundaries-coverage.R` (Cauchit weighted refit 3.8e-5 off) and
  `test-ordinal-kk-clmm-migration-golden.R` (Probit and Cloglog legacy vs migrated 1-3e-6 off in jackknife and
  randomization outputs, against 1e-7). Check the cloglog likelihood, gradient and the quadrature, and compare
  log-likelihoods at both optima to see which fit is better. Done when cloglog matches clmm on several seeds or
  the difference is explained (e.g. clmm stops at a worse optimum) and documented.
- [ ] TODO-49 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **An
  inference reported as status 'ok' with a non-finite estimate.**
  `R/package_tests/testthat_bulk/test-design-inference-introspection-audit.R` ("no silently masked capability for
  KK/incidence") finds a KK/incidence row with status 'ok' and a non-finite estimate, most likely the exact Fisher
  log odds ratio = Inf on a separated 2x2 table. Find the row, then either report it with a non-ok status (and a
  reason) or define the estimate on separated tables; an 'ok' row must never carry Inf/NaN. Done when the audit
  test passes on the new data without changing the fixture.
- [x] TODO-50 (added 2026-11-17, agent; surfaced by the v1.0.6-TODO-45 pre-push run): **KK robust regression's *(ticked by the TODO audit 2026-11-17: R/package_metadata/future_release_plans/release_v1_0_6.md:1007; R/EDI/src/fast_robust_regression.cpp:192; R/EDI/src/fast_robust_regression.cpp:244; R/EDI/src/fast_robust_regression.cpp:195; R/EDI/src/fast_robust_regression.cpp:428; R/EDI/R/inference_continuous_KK_robust_regr_ivwc.R:196; R/EDI/R/i...)*
  C++ path disagrees with `MASS::rlm`.** `R/EDI/tests/testthat/test-kk-robust-regr-use-rcpp.R` ("InferenceContinKKRobustRegrIVWC:
  use_rcpp matches MASS::rlm fallback") now fails: -0.864 (use_rcpp = TRUE) vs -0.854 (rlm), tolerance 1e-3. It is
  not the fixture: over 21 seeds (`method = "M"`, 40 forced pairs + 20 reservoir, t(4) noise, 3 outliers) the
  |gap| is 1e-4 to 6e-2, typically about 1e-2, both with the test's forced match vector and with every pair made
  opposite-arm; two seeds give NA. The test's old seed passed by luck. Compare the two paths' psi, scale
  estimate (rlm re-estimates the MAD scale each iteration), convergence criterion and iteration cap; find why some
  seeds return NA. Do not re-pin the seed to make the test pass. Done when the paths agree to a justified
  tolerance across seeds, or the documented difference is explained.
  - **Root cause (2026-11-17, agent): the C++ kernel ran a different estimator, not a looser one.** Three
    differences, found in order:
    1. *Scale.* `fast_robust_regression_internal()` (`R/EDI/src/fast_robust_regression.cpp`) fixed the MAD scale
       at the OLS residuals; `MASS:::rlm.default` (`scale.est = "MAD"`) re-estimates `median(|r|)/0.6745` at the
       top of every IRLS iteration. Psi (Huber, k = 1.345), start (OLS) and weights were already the same.
       Evidence: with both paths run to acc = 1e-10, maxit = 1000 the gap stayed (21 seeds, opposite-arm pairs:
       IVWC median 1.1e-2, max 6.2e-2; OneLik median 4.6e-3, max 3.2e-2), so rlm's loose acc = 1e-4 is not the
       cause. Re-estimating the scale each iteration in the kernel cut the tight-convergence gap to 1e-11 (IVWC
       median 1.4e-11, OneLik 1.7e-11). rlm's side is right: it is the estimator the classes document and the
       standard Huber M-estimator with concomitant MAD scale; the old kernel's scale came from the outlier-pulled
       OLS fit.
    2. *Stopping rule.* The kernel stopped on relative coefficient change, rlm on relative residual change
       (`test.vec = "resid"`). At the classes' acc = 1e-4 that left gaps of ~1e-5 (max 1.4e-4). With rlm's rule
       the two paths stop on the same iteration and agree to roundoff.
    3. *SE.* For IVWC the component SEs set the inverse-variance weights. The kernel's `ssq_b_j` lacked the
       Huber small-sample factor kappa = 1 + p Var(psi')/(n mean(psi')^2) that `MASS:::summary.rlm` applies, so
       with identical component estimates the combined IVWC estimate still differed (median 1.9e-3, max 6.3e-2).
  - **NA cause.** The classes' default `maxit` (10 / 15 / 20 by p with the OLS start) is below rlm's own default of
    20. With the scale re-estimated each iteration, rlm needed up to 26 iterations on the 20-subject reservoir
    (50 seeds; the matched-pair fit needed 4-9), so on 2 seeds it warned "failed to converge", the reservoir fit
    returned NULL and, because the forced match vector leaves same-arm pairs with NA differences, the IVWC estimate
    was NA. The C++ path returned its unconverged iterate on those seeds instead.
  - **Fix.** C++ (`fast_robust_regression.cpp`): `method = "M"` re-estimates the MAD scale each iteration and stops on
    rlm's relative-residual-change test (a zero MAD stops as converged, as rlm does); `ssq_b_j` gains kappa^2 for M
    and MM; roxygen updated. `"MM"` keeps its fixed scale and coefficient test (it is not rlm's MM: it starts from
    OLS, not an S-estimate). No Rcpp signature change. R (`inference_continuous_KK_robust_regr_ivwc.R`,
    `inference_continuous_KK_robust_regr_one_lik.R`): default `maxit` is 100 for every p (a safety cap; fits stop
    at `acc`), and the Rcpp branch returns NULL for an unconverged fit, as the rlm branch already did.
  - **Evidence after the fix** (sourceCpp of the edited kernel assigned into the namespace under
    `load_all(compile = FALSE)`; 51 seeds, `method = "M"`): IVWC |gap| max 4.4e-16 with opposite-arm pairs and
    6.7e-16 with the test's forced match vector, no NA (was median 6.4e-3, max 9.8e-2, 2 NA); OneLik max 4.4e-16
    (was median 4.4e-3, max 5.0e-2). The test's seed and 1e-3 tolerance are kept.
  - **Tests.** `test-kk-robust-regr-use-rcpp.R`: the fixture now puts each forced pair's members in opposite arms
    (same-arm pairs gave NA differences, so the OneLik comparison was NA vs NA and passed vacuously) and the
    OneLik test checks finiteness. New seed sweep
    `R/package_tests/testthat_bulk/test-kk-robust-regr-rcpp-matches-mass-rlm-across-seeds.R` (20 seeds, both
    classes, estimates and SEs at 1e-6). Updated for the new behavior: `test-robust-regression-xtx-cache.R`
    (reference SE gets kappa), `test-kk-robust-fallbacks.R` (an unconverged Rcpp fit is now NULL),
    `test-robust-rand-bootstrap-kernel-mass-rlm-reference-...R` (kernel M now equals rlm; rlm tolerance 0.15 ->
    1e-3; the investigation test asserts the new scale rule and same-iteration stopping) and
    `test-kk-robust-regr-one-lik-rlm-control-resolution-...R` (maxit default 100).
  - **Rebuild pending:** the installed EDI.so still has the old kernel; the owner must rebuild before the installed
    package (and any CSV regeneration) picks the fix up.
  - **NEWS entry needed:** user-visible estimates change for every `use_rcpp = TRUE` robust fit with `method = "M"`
    (KK IVWC/OneLik, `InferenceContinRobustRegr`, the robust rand/bootstrap kernel) and all kernel robust SEs grow by
    kappa (M and MM); KK robust classes may now return NA for an unconverged Rcpp fit instead of the unconverged value.
- [x] TODO-51 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Breslow hazard floors tiny risk-set sums at an absolute 1e-10.** `.breslow_hazard()`
  (`R/EDI/R/helper_survival_fits.R:596`) floors each rescaled risk-set sum at 1e-10, so when a late risk set holds
  only subjects whose linear predictor is more than about 23 below the maximum the hazard increment is wrong by orders
  of magnitude (1e10 vs 5.3e12), and Cox simulations that invert it draw wrong times. Use a relative floor, or keep
  the sums on the log scale. The failing test is
  `R/package_tests/testthat_bulk/test-breslow-hazard-low-relative-risk-risk-set.R` (skipped, citing this TODO); done
  when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): `.breslow_hazard()` drops the `max(R_k, 1e-10)` floor; plain `d_k / R_k`
  unless `R_k` underflows, then a log-scale rescale by the risk set's own max (Inf beyond double range). Repro cumhaz
  `1, 1e10, 2e10` -> exact `1, 5.34e12, 1.60e13`. Instrumented check on 3000 datasets: 146 changed, all where the floor
  bound, 0 otherwise. New `test-breslow-hazard-no-absolute-floor-on-risk-set-sum.R` (58); bulk test un-skipped; 1686
  survival expectations pass. Left alone: `.cox_simulate_*` `exp(eta - max(eta))` underflows only beyond ~745.
- [ ] TODO-52 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Ratio annealing can return an infeasible allocation.** The A-optimal "ratio" annealing
  kernel (`R/EDI/src/design_optimal_annealing_search.cpp:77`) scores a chain's random start as (w'Hw+1)/(n_T-w'Pw)
  without checking the denominator is positive, so an infeasible start with a negative objective beats every feasible
  allocation and `annealing_solve_A_ratio` returns it (its own `f_exact` scores it Inf). Score non-positive
  denominators as Inf and redraw infeasible starts. The failing test is
  `R/package_tests/testthat_bulk/test-annealing-ratio-infeasible-start-not-returned.R` (skipped, citing this TODO);
  done when the fix lands and the skip is removed.
- [x] TODO-53 (added 2026-11-17, agent, owner request; found by the thread-rng review audit, merged as a skipped
  failing test): **Smoothed bootstrap-randomization p-value depends on the core count.**
  `compute_rand_bootstrap_two_sided_pval(type = "smoothed")` (`R/EDI/R/inference_all_abstract_rand_bootstrap.R:579`)
  draws each draw's assignment lazily inside the worker from that process's RNG stream, so with an unseeded design the
  draws and the seeded p-value change with `set_num_cores()`. The default percentile path does the same for classes
  with no fast kernel and no reusable worker (line 279). Record a per-draw w seed (materialize) as the other paths do;
  see v1.1.0-TODO-48. The failing test is
  `R/package_tests/testthat_bulk/test-rand-bootstrap-smoothed-lazy-assignment-core-count-invariance.R` (skipped,
  citing this TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): lazy draws now carry a `w_seed` and the RNG kind; new
  `rand_bootstrap_lazy_draw_w()` replays them and restores the caller's RNG state (fork workers run L'Ecuyer, so
  `set.seed` alone wasn't enough). Repro smoothed p 0.1106 / 0.1407 -> 0.0804 / 0.0804. Materialized paths unchanged
  at 1 core; lazy paths change by Monte Carlo noise. 1-core vs 2-core (fork) now bit-identical; new `test-aa-fork-warm-start-lazy-assignment-and-tmb-thread-core-count-invariance.R` (22); bulk test un-skipped (callr-based bulk tests need a reinstall).
- [x] TODO-54 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Mahalanobis objective silently dropped for badly scaled covariates.**
  `prepare_optimal_objective_matrices()` (`R/EDI/R/helper_optimal_milp_solvers.R:106`) declares Sigma singular when
  `rcond(Sigma) < 1e-12`, which is not scale-invariant, so full-rank covariates on very different scales fall back to
  the l1 objective (`mahal_fell_back = TRUE`). Test singularity on the correlation matrix (or standardized columns).
  The failing test is `R/package_tests/testthat_bulk/test-optimal-mahal-objective-badly-scaled-covariates.R` (skipped,
  citing this TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): `prepare_optimal_objective_matrices()` judges singularity by non-finite or
  relatively constant column SDs and `rcond(cov2cor(Sigma)) < 1e-12` (scale-invariant); Q still from `chol` of the raw
  Sigma. Objective matrices bit-identical on 40 well-scaled / collinear random X. New
  `test-optimal-mahal-objective-scale-invariant-singularity.R`; bulk test un-skipped; 946 optimal-design expectations
  pass.
- [x] TODO-55 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Sequential-MC randomization p-value is NA when `mc_batch_size` < 10.**
  `compute_two_sided_pval_with_sequential_mc` (`R/EDI/R/inference_all_abstract_rand.R:938`) returns the NA from the
  first batch's prefix (fewer than the 10 finite draws required) instead of drawing the next batch. Continue drawing
  until 10 finite draws exist, or reject `mc_batch_size < 10` in `normalize_randomization_ci_search_control`. The
  failing test is `R/package_tests/testthat_bulk/test-rand-pval-sequential-mc-small-batch.R` (skipped, citing this
  TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 with v1.0.6-TODO-166 (same cause): the `skip()` in
  `testthat_bulk/test-rand-pval-sequential-mc-small-batch.R` is removed and the test passes.
- [ ] TODO-56 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **KK GLMM null simulation swaps the two variance components.** `simulate_under_lik_null()`
  (`R/EDI/R/inference_continuous_KK_glmm.R:503`) reads the null fit as c(beta, log_sigma_b, log_sigma_e), but
  `fast_gaussian_lmm_cpp` returns c(beta, log_sigma_e, log_sigma_b) (`fast_gaussian_lmm.cpp:539-545`), so
  parametric-bootstrap LR null replicates use swapped SDs. Fix the indexing (by name if possible) and re-check the
  affected calibration rows. The failing test is
  `R/package_tests/testthat_bulk/test-contin-kk-glmm-null-simulation-variance-component-order.R` (skipped, citing this
  TODO); done when the fix lands and the skip is removed.
- [x] TODO-57 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **D/A-optimal projection is wrong when a covariate is collinear with the intercept.**
  `R/EDI/R/helper_optimal_shared.R:107` builds P = QQ' from `qr.Q(qr(cbind(1, X)))` without truncating to the QR rank,
  so for X = [x1, x1 + 1] P projects onto an extra arbitrary direction (trace 3, not 2) and the search optimizes the
  wrong criterion. Keep only the first `qr$rank` columns (pivoted). The failing test is
  `R/package_tests/testthat_bulk/test-greedy-d-optimal-projection-rank-deficient-intercept-collinear.R` (skipped,
  citing this TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): `build_optimal_design_P_H()` (non-Bayesian branch) keeps only
  `Q[, seq_len(qr$rank)]`, un-pivots R before building M (a second defect: pivoted QR misaligned the subset-interest
  H), and goes straight to `MASS::ginv` when rank deficient. Full-rank `[1, X]`: bit-identical P/H and same-seed
  allocations (18 comparisons, GreedyDOptimal and Optimal). New `test-optimal-projection-rank-deficient-design-matrix.R`
  (14); bulk test un-skipped; a bulk reference test that copied the bug fixed; 52 optimal/greedy files pass. The
  Bayesian (ridge) branch has the same pivot-free code but doesn't take this QR path when tau > 0.
- [x] TODO-58 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **CR2 cluster-robust variance is NULL for small-unit responses.**
  `cluster_robust_cr2_variance()` (`R/EDI/R/helper_robust_sandwich.R:155`) returns NULL when the variance is below the
  absolute `.Machine$double.eps`, so y * 1e-8 is called not estimable and OLS/Lin silently fall back to the
  homoskedastic SE on a cluster design. Use a floor relative to the scale of y (or the residuals). The failing test is
  `R/package_tests/testthat_bulk/test-cr2-cluster-robust-variance-small-scale-response.R` (skipped, citing this TODO);
  done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): `cluster_robust_cr2_variance()` replaced the absolute `ssq < eps` floor with a
  noise floor relative to the scale of y and the fit (`n * (100 eps max|y|)^2 * (X'X)^-1_jj`). Matches clubSandwich CR2
  variance and Satterthwaite df to ~1e-15 at scales 1e-12..1e8; 1,200 perfect-fit cases still NULL. New
  `test-cr2-cluster-robust-variance-scale-equivariant.R` (26); bulk test un-skipped; sandwich / cluster files pass.
- [x] TODO-59 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **Wilcoxon Hodges-Lehmann estimate is NA when each arm is constant.** `shared()`
  (`R/EDI/R/inference_all_simple_wilcox.R:337`) turns `wilcox.test(conf.int = TRUE)`'s all-ties error into a
  non-estimable NA estimate, although the HL estimate is defined (the estimate_only path returns it). Compute the
  estimate without `conf.int` when the CI fails, and report the CI as unavailable. The failing test is
  `R/package_tests/testthat_bulk/test-simple-wilcox-constant-arms-hl-estimate.R` (skipped, citing this TODO); done
  when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): when both arms are constant, the estimate is `yT - yC` on both paths (matches
  `stats::wilcox.test(exact = TRUE)`), the ties-corrected p-value is computed (equals stats; 1 at the shift), and the
  CI is NA with `edi_wilcox_ci_unavailable_warning` (reason `wilcox_ci_each_arm_constant`, recorded as a Wald
  procedure failure, not nonestimable): rank-test inversion only gives the point [d, d]. Helpers are file-level to keep
  the migration-baseline private counts. New `test-simple-wilcox-constant-arms-estimate-pval-and-ci.R` (30); bulk test
  un-skipped; Wilcox golden and routing tests pass. Class docs could mention the constant-arms CI (not roxygenized).
- [x] TODO-60 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **KK21 proportion speedup loses all weights when a response is 0 or 1.** `compute_weights`
  (`R/EDI/R/design_seq_one_by_one_KK21.R:380`) takes `log(ys / (1 - ys))` unclamped, so one response of exactly 0 or 1
  makes every t-statistic non-finite and matching silently becomes unweighted. Clamp as `KK21_stepwise.R:272-274`
  does. The failing test is `R/package_tests/testthat_bulk/test-kk21-proportion-speedup-boundary-response-logit.R`
  (skipped, citing this TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): KK21's proportion speedup now uses the package `logit()` (clamped to
  [eps, 1 - eps], as KK21stepwise does) instead of a raw `log(y / (1 - y))`. Repro weights 2.2e-16, 2.2e-16 -> 0.202,
  0.635; interior-response designs identical on 20 seeds. New
  `test-kk21-proportion-speedup-boundary-response-clamped.R`; bulk test un-skipped; 30 KK21 files (1262) pass.
  Open design question (both KK21 classes): the eps clamp makes a 0/1 response a +/-36 logit outlier for the OLS
  t-statistics; a milder clamp such as (y(n-1)+0.5)/n would keep more signal.
- [x] TODO-61 (added 2026-11-17, agent, owner request; found by the thread-rng review audit, merged as a skipped
  failing test): **Randomization distribution of warm-started fits depends on the core count.** The reused-worker
  randomization path (`R/EDI/R/inference_all_abstract_rand.R:672`) chains warm starts within each of `num_cores`
  chunks, so each null fit's start, and so its converged iterate, depends on the core count; for loose-tolerance fits
  (L-BFGS Weibull, ordinal) the drift exceeds ulps. Start every permutation's fit from a point that does not depend on
  the chunking (e.g. the full-data MLE, or chunk boundaries fixed independently of cores); see v1.1.0-TODO-48. The
  failing test is `R/package_tests/testthat_bulk/test-rand-distribution-warm-start-chain-core-count-invariance.R`
  (skipped, citing this TODO); done when the fix lands and the skip is removed.
  Fixed 2026-11-19 (agent, uncommitted; owner accepted 2026-11-19): removed warm-start chaining between permutations in
  `compute_randomization_distr_via_reused_worker_states`; every permutation starts from the full-data fit. This
  reverses the 2026-11-16 ruling that concave classes chain (the option this TODO's own text suggests). No measurable
  slowdown (Poisson, NegBin, PropOdds). 1-core values change at tolerance level (Poisson 1e-10, HurdlePoisson 2e-5).
  `rand_likelihood_is_nonconcave()` is now unused by this loop (still referenced by a test and the call-graph
  baseline). 1-core vs 2-core (fork) now bit-identical; new `test-aa-fork-warm-start-lazy-assignment-and-tmb-thread-core-count-invariance.R` (22); bulk test un-skipped (callr-based bulk tests need a reinstall).
  Owner ruling 2026-11-19: accepted. Randomization replicates never chain warm starts, for any class (supersedes the
  2026-11-16 ruling that concave classes chain): every permutation starts from the full-data fit.
- [x] TODO-62 (added 2026-11-17, agent, owner request; found by the thread-rng review audit, merged as a skipped
  failing test): **Hurdle negbin bootstrap-weighted fits depend on the core count.**
  `InferenceCountHurdleNegBin$compute_estimate_with_bootstrap_weights()` (`R/EDI/R/inference_count_hurdle.R:442`)
  passes `glmmTMBControl(parallel = self$num_cores)`, so TMB's thread-split likelihood sums differ by thread count and
  every Bayesian/nonparametric bootstrap replicate depends on `set_num_cores()`. Pass `parallel = 1` inside EDI's own
  parallel loops; see v1.1.0-TODO-48 and the next TODO. The failing test is
  `R/package_tests/testthat_bulk/test-hurdle-negbin-weighted-glmmtmb-core-count-invariance.R` (skipped, citing this
  TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 (agent, uncommitted): glmmTMB `parallel = 1L` (TMB sums per-thread likelihoods in a
  thread-count-dependent order; 3e-11 differences). Same fix applied to `inference_count_KK_cond_poisson.R` and
  `inference_mixin_kk_glmm_shared.R` (two sites). 1-core output unchanged to 17 digits. 1-core vs 2-core (fork) now bit-identical; new `test-aa-fork-warm-start-lazy-assignment-and-tmb-thread-core-count-invariance.R` (22); bulk test un-skipped (callr-based bulk tests need a reinstall).
- [ ] TODO-63 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **KK21 stepwise errors when every response so far is identical.** With constant responses so
  far (e.g. all count responses 0) `kk21_stepwise_continuous_weights_cpp` returns all NA, `na0()` makes them 0, and
  `assign_wt` (`R/EDI/R/design_seq_one_by_one_KK21.R:270`) normalizes 0/0 = NaN, so the next assignment errors in
  `stats::quantile`. Fall back to equal weights when the raw weights sum to 0. The failing test is
  `R/package_tests/testthat_bulk/test-kk21-stepwise-constant-response-zero-weight-normalisation.R` (skipped, citing
  this TODO); done when the fix lands and the skip is removed.
  Status 2026-11-18 (agent, uncommitted): v1.0.6-TODO-120 and -63 fixed together (same cause), R only. The stepwise
  kernel skips a candidate whose residual variance is 0 (exact fit, or constant y), so with one covariate all weights
  are NA -> 0 and `assign_wt` normalized 0/0. `assign_wt` (`design_seq_one_by_one_KK21.R`) now falls back to equal
  weights when the sum is non-finite or <= 0 (what non-stepwise KK21 already gives). 20 single-covariate scenarios:
  continuous, count, proportion, survival and ordinal cases that crashed now run. Allocations unchanged on non-crashing
  paths (72/72 configs identical vs HEAD). Test `test-kk21-stepwise-degenerate-weights-fall-back-to-equal.R` (51); the
  TODO-63 bulk test's skip removed (3/3); 59 KK21/KK golden files pass. Not changed: with several covariates, one that
  predicts y exactly gets weight ~0 in the stepwise kernel (eps in non-stepwise); a C++ change if wanted. NEWS line
  pending.
- [x] TODO-64 (added 2026-11-17, agent, owner request; found by the thread-rng review audit, merged as a skipped
  failing test): **Zero-augmented Poisson fits depend on the core count.** `fit_zero_augmented_model()`
  (`R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:1094`) passes `glmmTMBControl(parallel =
  self$num_cores)`, so the coefficients of InferenceCountHurdlePoisson and the other zero-augmented subclasses (and
  their `use_rcpp = FALSE` fits) change in the low bits with `set_num_cores()`. Same fix as the previous TODO. The
  failing test is `R/package_tests/testthat_bulk/test-zero-augmented-poisson-weighted-glmmtmb-core-count-invariance.R`
  (skipped, citing this TODO); done when the fix lands and the skip is removed.
  Done 2026-11-19 with v1.0.6-TODO-62 (same cause; glmmTMB `parallel = 1L` in
  `inference_count_zero_augmented_poisson_abstract.R`).
- [ ] TODO-65 (added 2026-11-17, agent, owner request; from GitHub issue #20, the CI self-check audit): **Bump
  outdated GitHub Actions and fix the self-check's zero-median false positives.**
  - Bump to the latest major: `actions/cache` v5 -> v6 (calibration-study, comprehensive-study, nightly,
    test-coverage-R-advanced), `actions/checkout` v6 -> v7 (algorithm-research-bench, audit-compiled-code,
    audit-status), `actions/download-artifact` v7 -> v8 (algorithm-audit-drift), `actions/setup-python` v6 -> v7
    (audit, copilot-setup-steps, nightly, test-coverage-python), `codecov/codecov-action` v6 -> v7
    (test-coverage-R-pr, test-coverage-python). Read each action's release notes for breaking inputs first.
  - Done 2026-11-17 (uncommitted; tick the box once the owner has seen these workflows run green): every
    older-major pin in `.github/workflows/` bumped, 24 `uses:` lines and no input changes. `actions/cache`,
    `cache/restore` and `cache/save` @v5 -> @v6: calibration-study (152, 165, 264, 377, 389, 544),
    comprehensive-study (104, 200, 321), nightly (191, 269, 499, 545, 816, 1029, 1052), test-coverage-R-advanced
    (97). `actions/checkout` @v6 -> @v7: algorithm-research-bench (31, 46, 78, 115); audit-compiled-code and
    audit-status were already on v7. `actions/download-artifact` @v7 -> @v8: algorithm-audit-drift (402).
    `actions/setup-python` @v6 -> @v7: audit (122), copilot-setup-steps (49), nightly (688),
    test-coverage-python (33). `codecov/codecov-action` @v6 -> @v7: test-coverage-R-pr (124),
    test-coverage-python (58). Nothing was held back. No input these steps pass changed: cache v6 is an ESM
    rebuild with the same inputs and the same cache-version salt, so existing caches still hit. checkout v7
    refuses fork-PR code under `pull_request_target`/`workflow_run`, and algorithm-research-bench is dispatch-only.
    download-artifact v8 fails on a digest mismatch by default and skips unzipping non-zip downloads, which
    does not affect the zipped `research-*` artifacts from upload-artifact@v7. setup-python v7 removed
    `pip-install`, which no step uses. codecov v7 only moves the uploader's PGP key to `codecovsecops`.
    `upload-artifact` stays on v7, the latest major. YAML parse, actionlint, the 391 tests in
    `.github/scripts/test_*.py` and the self-check's `check_actions` against live releases (no action behind)
    all pass.
  - Done 2026-11-17: `.github/scripts/audits/ci_self_check.py` flagged `test-coverage-R.yaml` (336x) and
    `loc-badge.yml` (13x) against an 8-week median of 0 min made of gate-only runs. Commit a32ab62c (after the
    run that opened issue #20) excludes earlier runs under `BASELINE_MIN_S` = 120 s from the median; replaying
    #20's numbers flags neither now, while calibration-study (real 96-min baseline) is still flagged.
    Regression test `test_zero_minute_median_is_never_the_baseline` added.
  - `calibration-study.yml` at 3.6x its median is expected while campaign waves run long; decide whether to
    exempt campaign workflows from the slow-run check.
- [ ] TODO-66 (added 2026-11-17, agent, owner request; from GitHub issue #21, the generated-file drift audit):
  **The audit runner's roxygen2 rewrites 152 of 369 Rd files.** `audit.yml` pins roxygen2 to the version in
  `Config/roxygen2/version` (8.0.0.9000), and the local build reports the same string, yet the runner's
  regeneration differs, so the pin does not reproduce the local build (a dev version string covers many
  commits). Pin the runner to the exact roxygen2 commit the committed Rd files come from (install by SHA), check
  that a fresh runner regeneration matches the committed `man/`, and record the SHA next to the version pin.
  - Found (2026-11-17, agent): the runner already installed by SHA, but the wrong one. `ROXYGEN2_REF` was
    upstream `r-lib/roxygen2@9a82bf42` (run 44048276794 ran at 4fc58cd0, which has that pin). The owner's
    roxygen2 is `kapelner/roxygen2@c9203b7f`, the branch of r-lib/roxygen2 PR #1914 (open): one commit on top
    of 9a82bf42 adding the `r6_inherited_documentation_display` option, default "grouped" (one
    "+ inherited public methods from <Class>" block per ancestor instead of one flat "Inherited methods"
    list). Both report 8.0.0.9000. The local install has no RemoteSha (installed from a working tree on
    2026-08-02, 28 min before that commit); identified by matching its NEWS.md blob against r-lib history
    (pins it to e4c23d06..9a82bf42) and by deparsing all 734 namespace objects: they differ from a scratch
    install of 9a82bf42 in exactly the 5 functions that commit changes, and match a scratch install of
    c9203b7f exactly. The 152 files are exactly the 152 Rd files with "+ inherited public methods from".
    Scratch regeneration (copy of R/EDI, `R/fast_roxygenize.R`, scratch library): 9a82bf42 changes 152 Rd
    files; c9203b7f changes none except `DesignFixedFactorial.Rd`, whose roxygen source has an uncommitted edit
    (v1.0.6-TODO-70) in the working tree.
  - Changed: `ROXYGEN2_REF` in `audit.yml` is now `kapelner/roxygen2@c9203b7f504b8d01cf29411f6166efa584e377d8`
    and is the one record of the pin (header comment rewritten); the finish job's pin check also compares the
    installed RemoteSha with it. `audits/generated_drift.py` names the pinned ref in its mass-change message.
    Tests in `test_audit_generated_drift.py`: the pin is a full SHA, every workflow roxygen2 install uses it,
    the check step reads RemoteSha. Not stored in DESCRIPTION (it would ship in the CRAN tarball, and
    `Config/roxygen2/*` is roxygen2's own namespace).
  - Risk: the committed docs depend on an unmerged fork commit. If PR #1914 is closed or the branch deleted,
    the SHA may stop being fetchable; if it merges with a different default, set
    `Config/roxygen2/r6_inherited_documentation_display: grouped` in DESCRIPTION and move the pin to upstream.
  - Tick when the next dispatch of `audit-generated-drift.yml` logs "roxygen2 commit c9203b7f... matches
    ROXYGEN2_REF" and reports no Rd mass change (issue #21 then closes itself).
- [ ] TODO-67 (added 2026-11-17, agent, owner request; from GitHub issue #23, the results-freshness audit):
  **Regenerate the stale result rows.** All four `R/package_tests/comprehensive_tests_{size,power,coverage,mse}.csv`,
  `comprehensive_coverage_attempt_summary.csv` and the current calibration campaign's summary have row groups
  generated before their class or family code last changed (49 groups at 2026-11-17). Today's v1.0.6-TODO-44
  (imputation), -45 (KK14 threshold) and -50 (robust kernel) change more of them. Run the next comprehensive
  campaign after those land (and the owner's rebuild for TODO-50), then confirm the freshness issue closes itself.
- [ ] TODO-68 (added 2026-11-17, agent, owner request; from GitHub issue #25, the NEWS and version audit):
  **Version numbers disagree across files.** `CITATION.cff` and `codemeta.json` say 1.0.2; `python/CITATION.cff`,
  `python/README.md` and `python/README_PYPI.md` say 1.0.5; `R/EDI/DESCRIPTION` says 1.0.4. Bring the R-side
  files to the R version. Decide whether the Python package versions independently (it has its own `py-v*` tags
  and `.postN` rule); if so, make `.github/scripts/audits/news_version.py` compare the Python files with the
  latest `py-v*` tag instead of DESCRIPTION, with a unit test. The audit's other finding (no NEWS section newer
  than 1.0.4) is fixed: `NEWS.md` now has `# EDI (development version)`.
- [x] TODO-69 (added 2026-11-17, agent, owner request; from GitHub issue #27, the README and vignette drift
  audit): **Three cookbooks warn about BCa at B = 200.** `cookbook-continuous.Rmd` (chunk `ols-boot`),
  `cookbook-incidence.Rmd` and `cookbook-ordinal.Rmd` (chunk `fixed-resampling`) print EDI's own warning that
  BCa at B = 200 has only about 5 order statistics in each tail. Use `type = "percentile"` there (keeps the
  vignettes fast) or B >= 501 if the build time allows, so the rendered pages show no warning.
  - DONE 2026-11-17 (agent, uncommitted). The warning also meant the printed interval was `NA, NA`. Chose BCa at
    B = 501 (EDI's default type and B) in all three, since it costs under half a second more than percentile at
    B = 200 (installed EDI, one chunk, seed 1): continuous 0.11 s vs 0.06 s, incidence 0.47 s vs 0.16 s, ordinal
    0.72 s vs 0.33 s. Prose next to each chunk now says why B = 501 (continuous: BCa needs about 501 draws, else
    `NA` with a warning; use `type = "percentile"` for a small B; incidence and ordinal: one line pointing to it).
    Rendered with the installed EDI into `$TMPDIR`: continuous 3.6 s, incidence 3.2 s, ordinal 3.8 s; no warning
    or error in any page; intervals [1.37, 4.74], [0.294, 2.48], [0.974, 2.56]. The other B = 200 bootstrap
    chunks (`cookbook-count`, `-proportion`, `-survival`, `EDI.Rmd`, `articles/analyzing-an-existing-experiment`)
    rendered without the warning, so they were left as they are (they still use BCa at B = 200, which can go `NA`
    if their data change).
  - Follow-up 2026-11-17 (owner request): those five chunks now use B = 501 too, so no page runs BCa at B = 200.
    Rendered with the installed EDI into `$TMPDIR`: proportion 5.0 s, count 2.4 s, existing-experiment article
    2.4 s, Getting started 2.0 s, survival 1.9 s; no warnings and no `NA` interval.
- [x] TODO-70 (added 2026-11-17, agent, owner request; from GitHub issue #28, the docs-claims audit): **Design
  docs that the code or tests contradict.** Fix the docs or the code for each (decide which side is right):
  - `DesignFixedBinaryMatch` (`design_fixed_binary_match.R:44`): says it falls back to complete randomization
    with no covariates; the code and a test error instead.
  - `DesignFixedBlockedCluster` (`:21`): describes one `randomizr::block_and_cluster_ra` call per replicate; the
    code uses `block_ra_batch`.
  - `DesignFixedFactorial` (`:14`): documents a {-1,+1} public convention; the code and tests return {0,1}.
  - `DesignFixedGreedyDOptimal` (`:111`): says `DesignFixedGreedy` refuses unequal allocation and odd n; it
    accepts both now. `get_interest()` (`:289`) is documented as returning "treatment" or "all" but also
    returns formulas and column names.
  - `DesignFixedRerandomization` (`:34`): says `abs_sum_diff` is unstandardized, but the C++ fast path divides
    each covariate by its SD (`rerandomization_helpers.cpp` ~L205-211), so which allocations are accepted
    differs from the documented objective. Decide the intended objective; this one can change results.
    Also (`:36`): other objective names are documented to error at draw time but reach the C++ search unchecked
    on the fast path.
  - `DesignSeqOneByOneEfron` (`:14`): documents `weighted_coin_prob > 0.5` and never deterministic, but the
    constructor does not validate it and a test uses 1. Add validation (or document 1 as allowed).
  - Already fixed today: the KK14 regularization wording and the two `morrison` claims (v1.0.6-TODO-45, -46).
  - The same issue lists 33 untested and 45 partly tested claims, each with a test idea; adding those tests is
    lower priority and can be batched later.
  - **Resolved 2026-11-17 (agent).** No C++ changed, so no rebuild is needed; R and Rd changes only.
    - BinaryMatch: doc fixed. The code is right: with no covariates and no `m` it errors ("no covariates
      provided ..."), as `test-design-fixed-binary-match-no-covariates-guard-reference.R` pins. The BCRD branch
      in `draw_ws_raw()` is kept as a defensive fallback but cannot be reached through the public API.
    - BlockedCluster: already fixed in 25100e2f (docs now describe `block_ra_batch()`); covered by
      `test-cluster-batched-draws.R`.
    - Factorial: doc fixed to say `w` is {0,1} internally and publicly (`test-fixed-designs-greedy.R` checks it).
    - GreedyDOptimal: the "different draws when prob_T != 0.5 / odd n" bullet removed and the identity stated
      for any `prob_T` (`test-greedy-unequal-arms.R` shows identical draws at 0.3 and 0.7). `get_interest()`
      `@return` now lists formulas and column-name vectors; new test
      `test-greedy-d-optimal-get-interest-returns-validated-interest.R`.
    - Rerandomization `abs_sum_diff` (**changes results, NEWS line needed**): the paths disagreed. Both C++
      kernels (`rerandomization_search_cpp`, balanced fast path; `compute_objective_vals_cpp`, prop_acceptable
      path) divide by each covariate's SD, and have done so since the initial commit (inherited from
      GreedyExperimentalDesign). `DesignFixedGreedy`'s `abs_sum_diff` also standardizes, and the class's own
      fast-path paragraph said "GED-standardized". Only the pure-R path (odd n, or prob_T != 0.5, with
      obj_val_cutoff) and the private `compute_obj()` used raw differences. Those two paths now standardize
      too (`abs_sum_diff_scaled_X()`), the docs say M(w) = sum_j |diff_j| / sd_j and that it is
      scale-invariant. Draws change only for `objective = "abs_sum_diff"` with `obj_val_cutoff` at odd n or
      prob_T != 0.5. New test `test-rerandomization-abs-sum-diff-standardized-and-objective-validation.R`
      (every path meets the standardized cutoff; the C++ search keeps exactly the candidates the R objective
      accepts; scale invariance); updated the raw-difference reference in
      `test-rerandomization-batched-fallback.R`, `test-rerandomization-objective-and-draw-paths-reference.R`
      and `test-sequential-design-branches.R`.
    - Rerandomization objective validation (**NEWS line**): the constructor now errors on anything but
      "mahal_dist"/"abs_sum_diff", and `draw_ws_raw()` re-checks before any C++ call. Same new test file.
    - Efron (**NEWS line**): the constructor now requires 0.5 < `weighted_coin_prob` <= 1 (Efron's p > 1/2;
      p = 1 is the deterministic limit, which existing tests use; no caller passes 0.5 or less). Docs say
      p = 1 is deterministic when the counts differ. New test `test-efron-weighted-coin-prob-range-validation.R`.
    - Found, not fixed: when the Cholesky factorization fails, the fast path's `mahal_dist` falls back to the
      standardized abs criterion against cutoff/4 (accepting M_abs <= a/2), while the other paths
      ridge-regularize S. Now documented; aligning it needs a C++ change and a rebuild (follow-up).
    - Also fixed in passing: `test-rerandomization-batched-fallback.R` built the design with no acceptance rule,
      which the constructor has rejected since earlier today; it now uses `obj_val_cutoff = Inf`.
- [x] TODO-71 (added 2026-11-17, agent, owner request; from GitHub issue #30, the reference-check audit): **Four
  citations disagree with Crossref.**
  - `design_seq_one_by_one_urn.R`: the DOI 10.1080/01621459.1977.10481006 given for Wei (1977), "A class of
    designs for sequential clinical trials", JASA 72(358), 382-386, resolves to a different paper ("Robust
    Univariate Test of Symmetry ..."). Find the correct DOI.
  - `inference_incidence_KK_marginal.R` (two entries, DOI 10.1016/0270-0255(86)90088-6): the Robins (1986) title
    differs from Crossref's; use Crossref's exact title.
  - `inference_ordinal_ordered_probit.R`: McCullagh (1980), JRSS B 42(2), pages are 109-127, not 109-142.
  - Mirror each fix in `R/EDI/REFERENCES.md`.
  - DONE 2026-11-17 (agent), each checked against the Crossref REST API: Wei (1977) is
    10.1080/01621459.1977.10481005 ("A Class of Designs for Sequential Clinical Trials", Lee-Jen Wei, JASA 72(358),
    382-386, June 1977); the Robins (1986) title now carries Crossref's subtitle ("...exposure period—application
    to control of the healthy worker survivor effect"); McCullagh (1980) pages are 109-127 in all four ordinal
    files that cite it (ordered probit, proportional odds, partial proportional odds, cloglog), not only the one
    the issue names. REFERENCES.md and the 7 affected Rd files regenerated; `tools::checkRd()` clean.
- [x] TODO-72 (added 2026-11-17, agent, owner request; from GitHub issue #33, the R/Python parity audit): **The
  Python Cox bindings default to `maxit = 20`; R uses 100.** `fast_coxph_regression` and
  `fast_stratified_coxph_regression` in `python/cpp/bindings_survival.cpp` (~L135, ~L207) default to 20, their
  R twins in `R/EDI/src/fast_coxph_regression.cpp` to 100, so Python can stop early on fits R finishes. Align
  the Python defaults to 100 (and the stub/docstrings), with a parity test. The audit's AI batches did not run
  on that issue's run (being fixed separately), so more parity findings may follow.
  - DONE 2026-11-17 (agent). The 20 was not deliberate: both Cox kernels were 20 on both sides when the bindings
    were written (2026-08), and R raised them to 100 in v1.0.5 (commit 96b34122, "Survey 2: was 20 (cap exits
    1-3 iterations short)") without the Python bindings following. R users get 100: `RcppExports.R` says
    `maxit = 100L` for both exports, and no R wrapper or Cox inference class passes its own `maxit`. Changed:
    `python/cpp/bindings_survival.cpp` (both `py::arg("maxit") = 100` and both docstrings' "default 100"),
    `python/src/edi_kernels/_core.pyi` (both signatures and both docstrings), `python/CHANGELOG.md` (a line under
    1.0.4 Unreleased, Changed). New pure-text test `python/tests/test_binding_defaults_match_r.py` checks every
    binding's `py::arg` defaults against its `<name>_cpp` twin in `RcppExports.R` (no compiled module needed);
    it fails on the old binding and passes now. The rpy-parity mechanical check now reports 0 findings (was these
    2). No other default mismatch with a same-name twin. **Takes effect only when the wheel is rebuilt.**
- [ ] TODO-73 (added 2026-11-17, agent, owner request; found by the cluster-and-factorial article agent):
  **`DesignFixedBlockedCluster` refuses blocks with different numbers of subjects, and its error points to an
  argument it does not take.** The blocking base (`design_blocking_abstract.R`, `equal_block_sizes = TRUE` by
  default, checked ~L263/L286) rejects strata of unequal size and says "Set equal_block_sizes = FALSE", but
  `DesignFixedBlockedCluster$new()` has no such argument, so following the message fails with `unused argument`.
  Real clusters almost never have equal sizes, so most real blocked cluster trials hit this. The tests miss it
  because they build equal subject counts per block (`test-cluster-batched-draws.R`).
  Repro (installed 1.0.4):
  ```r
  library(EDI); set.seed(1)
  cl = factor(rep(1:8, times = c(3,4,5,6,3,4,5,7))); blk = factor(rep(c("a","b"), times = c(18, 19)))
  X = data.frame(cl = cl, blk = blk, x = rnorm(37))
  d = DesignFixedBlockedCluster$new(n = 37, response_type = "continuous", strata_cols = "blk", cluster_col = "cl")
  d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()   # error: unequal block sizes
  DesignFixedBlockedCluster$new(n = 37, response_type = "continuous", strata_cols = "blk", cluster_col = "cl",
    equal_block_sizes = FALSE)                                         # error: unused argument
  ```
  Fix: expose `equal_block_sizes` on the constructor (or default it to FALSE for cluster designs, where the
  balance unit is the cluster, not the subject), and add a test with unequal cluster and block sizes. Check
  that the batched `block_ra_batch()` path then balances clusters within each block. The
  `cluster-and-factorial-experiments.Rmd` article works around this (every school has 20 students) and states
  the restriction; update it when fixed.
  Status 2026-11-18 (agent, uncommitted): fixed. Unequal blocks supported (the within-block cluster randomization
  never assumed equal sizes; the private default `equal_block_sizes` is now FALSE, and only `DesignFixedBlocking`
  exposes and sets it, default TRUE); the error names `equal_block_sizes`/`B_target` only when the class takes them
  (message_args audit: 0 findings at that site); `optional_public_methods = "initialize"` added to the BlockingStructure
  registration. Equal-size allocations identical (same w and digest). Test
  `test-blocked-cluster-unequal-block-sizes.R` (112); cluster article paragraph updated; known_todo row removed;
  `test-design-inference.R` CMH pattern updated by the coordinator. NEWS added.
- [ ] TODO-74 (added 2026-11-17, agent, owner request; found by the cluster-and-factorial article agent): **The
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
  Update 2026-11-18 (v1.0.6-TODO-108 agent): not fixed (cluster-unit jackknife on blocked designs still unimplemented),
  but `mark_jackknife_nonestimable_if_block_unsupported()` now warns and names `unit = "block"`, and the BCa CI that
  hits the same refusal now warns too. `cluster-and-factorial-experiments.Rmd` text updated to "with a warning".
- [ ] TODO-75 (added 2026-11-17, agent, owner request; found by the reporting-an-analysis article agent): **The
  BCa bootstrap p-value returns `NA`, with no warning, exactly when the evidence is strongest**: when the null
  value lies outside the whole bootstrap distribution. BCa is the default p-value type, so the default call
  fails this way. The percentile, symmetric and studentized types return the 2/B floor in the same situation,
  and the BCa CI on the same object works.
  - Cause: in `bca_pval_core()` (`R/EDI/R/inference_ext_bca_bootstrap_ci.R`), `bca_midrank_cdf(boot, 0)` is
    clamped to machine epsilon; its normal quantile is about -8.1, so the `|adj_z| > 8` check reports
    `adjustment_on_boundary` and returns `NA`. In `run_all_inference()` it shows as an `NA` p-value on the
    `boot (bca)` row.
  - Repro (installed 1.0.4; bootstrap range about [0.36, 4.68], so 0 is outside it):
    ```r
    library(EDI); set.seed(20261117); n = 60
    X = data.frame(age = round(rnorm(n,45,12)), bmi = round(rnorm(n,27,4),1), male = rbinom(n,1,.5))
    des = DesignFixedRerandomization$new(n = n, response_type = "continuous", prop_acceptable = 0.05, seed = 7)
    des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
    des$add_all_subject_responses(10 + 2.5*w + 0.1*X$age - 0.3*X$bmi + rnorm(n, sd = 3))
    inf = InferenceContinOLS$new(des, verbose = FALSE); inf$num_cores = 1L; inf$set_seed(1)
    inf$compute_bootstrap_two_sided_pval(B = 501, show_progress = FALSE)                          # NA, no warning
    inf$compute_bootstrap_two_sided_pval(B = 501, type = "percentile", show_progress = FALSE)     # 0.00399 = 2/501
    inf$compute_bootstrap_two_sided_pval(B = 501, type = "bca", delta = 1, show_progress = FALSE) # 0.054, works
    ```
  - Fix: when the null value is outside the bootstrap support, return the 2/B floor like the other types (or
    at least warn); keep `NA` only for a genuinely degenerate adjustment. Add a test with this repro, and check
    the same clamp in any other BCa p-value path. `vignettes/articles/reporting-an-analysis.Rmd` works around it
    by pairing the BCa CI with a percentile p-value; it can use the default once this is fixed.
  Status 2026-11-18 (agent, uncommitted): v1.0.6-TODO-75, -92 and -114 fixed together. `bca_pval_core()`
  (`inference_ext_bca_bootstrap_ci.R`) returns the 2/B floor when delta is outside the bootstrap support (was NA via the
  epsilon clamp and |adj_z| > 8); a boundary BCa p-value is still NA but now warns `edi_bootstrap_bca_boundary_warning`
  (`what = "p-value"`), like the CI; at B >= 501 the warning no longer says to increase B (`helper_robust_sandwich.R`
  `edi_warn_bca_boundary_once()`). Changes results (NA -> 2/B); NEWS line pending under "Changes that alter results".
  New test `test-bootstrap-bca-pval-outside-support-and-boundary-warning.R`; one bulk test updated (NA -> 2/B). On
  closing: remove the v1.0.6-TODO-75 rows of `R/package_tests/na_audit_allowlist.csv` and widen its BCa-boundary
  intentional row to the bootstrap p-value methods. Still silent: the "unstable bias or acceleration" BCa NA (CI and
  p-value). The LogRank boundary case is really a sign bug in LogRank bootstrap draws on interval data (not yet filed).
- [ ] TODO-76 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
  **KK14, KK21 and KK21stepwise crash on the first assignment when `n = NULL`**, although the docs say
  `n = NULL` means the sample size is not fixed. `too_early_to_match()` (`R/design_seq_one_by_one_KK14.R`
  ~L213) computes `private$t <= private$t_0_pct * private$n`, which is `logical(0)` when `n` is NULL, and `||`
  then errors "missing value where TRUE/FALSE needed" (or "invalid 'x' type"). Repro:
  `DesignSeqOneByOneKK21$new(response_type = "continuous")$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1))`.
  Fix: decide what burn-in means without `n` (e.g. an absolute `t_0` or require `n` for KK and error clearly at
  construction), document it, and test KK14/KK21/KK21stepwise with `n = NULL`. See also v1.0.6-TODO-77 and -78:
  together they mean `n = NULL` does not work for sequential designs at all.

  Status 2026-11-18 (agent, resumed, uncommitted): v1.0.6-TODO-76/-77/-78 fixed together. 76: `too_early_to_match()`
  compared t with `t_0_pct * NULL`; with n = NULL the burn-in now lasts until the model matrix exists (owner decision
  open: this, or require n for KK designs at construction). 77: completion checks guarded with `isTRUE(fixed_sample)`;
  `draw_bootstrap_indices()` used `private$n` (now `get_n()`), also in `compute_matching_cluster_ids()`. 78: responses
  stored by index, any order; a response for a subject not yet arrived is refused (also with asserts off). Fixed-n
  results identical by construction. Test `test-sequential-design-without-fixed-n.R` (50); 8 related files pass;
  data-shape matrix n = NULL cells 0 failing (354 cases), fixed-n sequential 0 failing (357); known_todo rows -76/-77
  removed; n = NULL fixtures now add responses in reverse order (so TODO-78 is exercised). KK roxygen for `t_0_pct`
  should mention n = NULL (suggested text in the agent report). NEWS added.
  Decided (owner, 2026-11-18): KK designs with `n = NULL` start matching once the covariate model matrix exists (no
  requirement for `n`). `t_0_pct` roxygen in KK14 / KK21 / KK21stepwise now says so (coordinator; not yet
  roxygenized).
- [ ] TODO-77 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
  **No sequential design with `n = NULL` can be analyzed.** `check_experiment_completed()` and
  `assert_all_subjects_arrived()` (`R/design_abstract.R` ~L482 and ~L500) evaluate
  `if (private$fixed_sample & private$t < private$n)`, which is `if (logical(0))` when `n` is NULL ("argument is of
  length zero"), so every `Inference*$new()` errors. Repro:
  `d = DesignSeqOneByOneEfron$new(response_type = "continuous"); for (t in 1:10) { d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1))); d$add_one_subject_response(t, rnorm(1)) }; d$check_experiment_completed()`.
  Fix: use `&&` with the `fixed_sample` test first (`isTRUE(private$fixed_sample) && private$t < private$n`); add a
  test that an `n = NULL` sequential design can be analyzed once every enrolled subject has a response.

  Status 2026-11-18 (agent, resumed, uncommitted): v1.0.6-TODO-76/-77/-78 fixed together. 76: `too_early_to_match()`
  compared t with `t_0_pct * NULL`; with n = NULL the burn-in now lasts until the model matrix exists (owner decision
  open: this, or require n for KK designs at construction). 77: completion checks guarded with `isTRUE(fixed_sample)`;
  `draw_bootstrap_indices()` used `private$n` (now `get_n()`), also in `compute_matching_cluster_ids()`. 78: responses
  stored by index, any order; a response for a subject not yet arrived is refused (also with asserts off). Fixed-n
  results identical by construction. Test `test-sequential-design-without-fixed-n.R` (50); 8 related files pass;
  data-shape matrix n = NULL cells 0 failing (354 cases), fixed-n sequential 0 failing (357); known_todo rows -76/-77
  removed; n = NULL fixtures now add responses in reverse order (so TODO-78 is exercised). KK roxygen for `t_0_pct`
  should mention n = NULL (suggested text in the agent report). NEWS added.
- [ ] TODO-78 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
  **With `n = NULL`, responses must be added in enrollment order, and the error message is wrong.**
  `add_one_subject_response()` (`R/design_abstract.R` ~L370-382) only appends to `y` when the sample size is not
  fixed. After enrolling 5 subjects, `d$add_one_subject_response(3, 1)` stops with "You cannot add a response for a
  subject that has not yet arrived when the sample size is not fixed in advance", but subject 3 has arrived. With
  `n` fixed, any order works. Fix: grow `y` (and the censoring vectors) to `t` with `NA` so any arrived subject can
  get a response in any order; keep the error only for `i > t`. Test out-of-order responses with `n = NULL`.

  Status 2026-11-18 (agent, resumed, uncommitted): v1.0.6-TODO-76/-77/-78 fixed together. 76: `too_early_to_match()`
  compared t with `t_0_pct * NULL`; with n = NULL the burn-in now lasts until the model matrix exists (owner decision
  open: this, or require n for KK designs at construction). 77: completion checks guarded with `isTRUE(fixed_sample)`;
  `draw_bootstrap_indices()` used `private$n` (now `get_n()`), also in `compute_matching_cluster_ids()`. 78: responses
  stored by index, any order; a response for a subject not yet arrived is refused (also with asserts off). Fixed-n
  results identical by construction. Test `test-sequential-design-without-fixed-n.R` (50); 8 related files pass;
  data-shape matrix n = NULL cells 0 failing (354 cases), fixed-n sequential 0 failing (357); known_todo rows -76/-77
  removed; n = NULL fixtures now add responses in reverse order (so TODO-78 is exercised). KK roxygen for `t_0_pct`
  should mention n = NULL (suggested text in the agent report). NEWS added.
- [ ] TODO-79 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
  **`vignettes/reproducibility.Rmd` overstates re-seeding for sequential designs.** Around L23-37 it says
  `maybe_set_seed()` runs "immediately before each call that consumes randomness" and that calling a draw method
  twice re-seeds. For the `DesignSeqOneByOne*` family the seed is applied once, at construction (as the `Design`
  roxygen correctly says), so a design reloaded from disk draws from whatever state the session's generator is in.
  Fix the vignette (say this for sequential designs and show saving `.Random.seed` with the design, as
  `articles/running-a-sequential-trial.Rmd` does), or decide that sequential designs should carry their own RNG
  state (a larger change; would make save/restore exact without user code).
  Status 2026-11-18 (agent, uncommitted): fixed. Verified: fixed designs re-seed on every draw; sequential designs
  seed only in the constructor (same seed reproduces only with no RNG use in between; continuing after readRDS needs
  the saved `.Random.seed`); inference `set_seed()` reproduces rand p-values and bootstrap CIs and leaves the caller's
  stream untouched. `reproducibility.Rmd` rewritten with runnable chunks (strict render PASS) and `Design` roxygen
  corrected. Open (owner): make sequential designs keep their own RNG state so save/restore works without user code.
- [ ] TODO-80 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
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
- [ ] TODO-81 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
  **Incidence responses with an R-function custom statistic get past the documented ban on nonzero `delta`.**
  The roxygen says "A nonzero delta is not supported for incidence responses", but the guards in
  `R/inference_all_abstract_rand.R` (~L308, ~L347, ~L537) only fire when
  `is.null(private$custom_randomization_statistic_function)`, so `InferenceRandCustom` with an R function runs
  `compute_rand_two_sided_pval(delta = 0.1)` on binary y (returned 0.01), while a `_cpp` statistic stops. Fix:
  apply the incidence `delta` guard regardless of how the statistic is supplied; test both forms.
  Status 2026-11-18 (agent, uncommitted): fixed with v1.0.6-TODO-81/-110 together. Cause: "custom statistic?" checked
  only the R-function field, not `compiled_cpp_stat_fn`. Now on incidence `delta = 0` runs for every form and nonzero
  `delta` errors for every form (`inference_all_abstract_rand.R`, `inference_all_abstract_rand_ci.R`). Test
  `test-rand-custom-incidence-delta-guard.R`; the incidence rand-attempt manifest and its bulk test updated. Stale,
  left for the owner (changes the grid): `comprehensive_tests.R` ~L2199 `skip_custom_rand_pval` on incidence, and
  `path_audits_source.R` `cell_rand_custom_p` (~L1577-1586). NEWS line pending.
- [ ] TODO-82 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
  **`na.rm` in `compute_rand_two_sided_pval()` does nothing, and the finite-draw minimum is misdocumented.**
  `R/inference_all_abstract_rand.R` ~L343-352 asserts `na.rm` but never uses it; non-finite draws are always
  dropped with no warning (`na.rm = FALSE` gave the same p-value, 0.7251, with about half the draws `NA`). The
  roxygen says "at least 10 finite reference statistics"; the code requires `max(10, 10% of r)`. Fix: honour
  `na.rm = FALSE` (return `NA` if any draw is non-finite) or remove the argument; warn when draws are dropped,
  with the count; make the roxygen state the real minimum. Test both.
  Note 2026-11-18 (v1.0.6-TODO-111 agent): the cause is in the shared p-value code (`inference_all_abstract_rand.R`
  ~L343, ~L837), not the custom class. Owner decision needed: honouring `na.rm = FALSE` literally would break every
  rand CI, because the CI search (`inference_all_abstract_rand_ci.R` ~L454) passes `na.rm = FALSE` and some draws
  fail; so either remove the argument or keep it as "drop non-finite draws" and fix the docs. A warning on dropped
  draws would need deduplication. The "at least 10" doc vs `max(10, 10% of r)` code mismatch is a roxygen fix.
  Decided (owner, 2026-11-18): keep `na.rm`, documented as "drop non-finite draws". Done (agent, uncommitted, docs
  only): roxygen in `inference_all_abstract_rand.R`, `_rand_ci.R`, paired sign test, Weibull, KK cond logit, risk diff
  (tags were mid-line and unread), dep-cens (unused there), `InferenceRandCustom` class text; minimum now documented as
  `max(10, floor(r/10))`, matching the code. Close after roxygenize. The cached affine-reuse fast path does not enforce
  that minimum: v1.0.6-TODO-124.
  Roxygenized 2026-11-18 (coordinator, `R/fast_roxygenize.R`, 0 warnings; 21 Rd files changed, uncommitted).
- [ ] TODO-83 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
  **A custom statistic that returns more than one value is silently truncated.** `evaluate_stat` keeps
  `as.numeric(...)[1L]` (see also `R/inference_all_abstract_rand.R` ~L196/L214), so
  `function(y, w, dead) c(1, 2)` gives an estimate of 1 with no error, though the docs say it must return one
  scalar. Fix: error (naming the length) when the return value is not length 1, at least for the observed
  statistic; test it.
  HALTED 2026-11-18 (agent stopped by the weekly usage limit, resets 2026-11-20 05:00 Asia/Jerusalem; partial
  edits are in the working tree; resume that agent rather than starting over).
  Status 2026-11-18 (agent, resumed, uncommitted): fixed. `evaluate_stat()` (`inference_rand_custom.R`) errors when the R
  or C++ statistic returns other than one value (was `as.numeric(...)[1L]`); surfaces at the first estimate/p-value.
  known_todo row removed; the 26 vector-statistic matrix cells now give the clear error. Test
  `test-rand-custom-statistic-length-and-ci-refusal.R` (27). NEWS added; roxygen line updated (not roxygenized).
- [ ] TODO-84 (added 2026-11-17, agent, owner request; found by the custom-randomization-statistic article agent):
  **Wrong refusal message and capabilities for `InferenceRandCustom` CIs on count and proportion responses.** The
  refusal (`R/inference_all_abstract_rand_ci.R`) says "the randomization-bootstrap CI remain available", but
  `InferenceRandCustom` has no bootstrap, and `capabilities()` still lists `"randomization_ci"` for those response
  types. Fix: make the message say what this class can do (the p-value at `delta = 0`), and drop
  `"randomization_ci"` from its capabilities for the types where it is refused (check the capability-registry
  tests that pin this). Related: v1.0.6-TODO-80.
  HALTED 2026-11-18 (agent stopped by the weekly usage limit, resets 2026-11-20 05:00 Asia/Jerusalem; partial
  edits are in the working tree; resume that agent rather than starting over).
  Status 2026-11-18 (agent, resumed, uncommitted): message fixed in `inference_all_abstract_rand_ci.R` (mentions the
  randomization-bootstrap CI only when the class has it); capabilities already correct (randomization_ci dropped for
  count/proportion/incidence), now pinned by the same test. The matrix's 4 remaining InferenceRandCustom failures
  carry the v1.0.6-TODO-82 known row (na.rm, owner-decided docs-only); retire that row when -82 closes. Related, not
  fixed: on survival the custom rand CI inverts a log-time shift although the class doc says "additive on the
  response scale" (v1.0.6-TODO-80).
- [x] TODO-85 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent): **The
  `fast_gaussian_lmm` docstring says X has "no intercept column", but it needs one.**
  `python/src/edi_kernels/_core.pyi` (~L324, and the binding docstring it mirrors) says so, but the R class
  `InferenceContinKKGLMM` passes (intercept, w, covariates), and the PyPI README example includes an intercept.
  On the article's KK21 data an intercept column gives treatment 1.03748533 (R: 1.037485); without one the first
  coefficient is 1.7279, a different model. Fix the stub and binding docstrings (and check the other "no
  intercept column" claims in the stub, ~L178 and ~L206, against what each R caller passes); add a test that
  the documented X layout reproduces the R class's estimate.
  Done 2026-11-19 (agent, uncommitted): the "no intercept column" claim was wrong for four GLMMs
  (`fast_gaussian_lmm`, `fast_poisson_glmm`, `fast_logistic_glmm`, `fast_hurdle_poisson_glmm`); fixed in `_core.pyi`
  and the binding docstrings (`cpp/bindings_glmm.cpp`, text only; reaches `help()` with the next wheel). The ordinal and
  Cox "no intercept" claims are correct. New `tests/test_glmm_x_includes_intercept.py` (matches the R class's
  estimate).
- [ ] TODO-86 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent): **Python
  kernels don't check that `w` is 0/1.** With `y = [1, 2, 3.5, 4, 2.2, 3.1]`, `dead` all 1 and
  `w = [1, 2, 1, 2, 1, 2]` (and likewise with -1/1 coding), `wilcox_hl_point_estimate`, `get_survival_stat_diff`
  and `fast_ridit_analysis` silently return `nan`, and `fast_logrank_stats(...)["beta_hat"]` silently flips sign
  (+0.511 instead of -0.511), the worst case. No error in any of them. The R classes validate `w` before calling
  these kernels, so this only affects direct (Python, or R `_cpp`) callers. The fix (input validation) moved to
  v1.0.6-TODO-101 on 2026-11-18 (owner request); this entry keeps the repro and closes when TODO-101 lands with a
  test of all treatment-vector kernels under 1/2 and -1/1 coding.
  Status 2026-11-18: that test is in `python/tests/test_input_checks.py` and passes (6 kernels x 2 codings x checks
  on/off); close with TODO-101.
- [x] TODO-87 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent): **Variance
  outputs are missing from the Python kernels.** `fast_ols(estimate_only=False)` returns only `b` and `XtWX`
  (R's `fast_ols_with_var_cpp` also returns `ssq_b_j` and `sigma2_hat`); `fast_logistic_regression` always
  returns `ssq_b_j`/`ssq_b_2`/`sigma2_hat` as `nan` (the fields exist but are never filled, which invites
  misuse); and Python has none of R's `_with_var` variants (OLS, logistic, probit, Poisson, negative binomial,
  ordinal links). Fix: either bind the `_with_var` kernels or fill the variance fields, and never return
  always-`nan` fields (drop them or document them); update the stub, README and `python/CHANGELOG.md`, and
  extend the rpy-parity audit's list so this gap is tracked. Python package; needs a wheel rebuild.
  Done 2026-11-19 (agent, uncommitted; pure Python, no new pybind outputs): new `python/src/edi_kernels/_variance.py`,
  run by `wrap_kernel()` when `estimate_only=False`, adds `vcov` / `ssq_b_2` (and `sigma2_hat` for OLS) to OLS,
  logistic, probit, Poisson and NegBin (log theta row dropped at the Poisson boundary); always-NaN keys the C++ never
  set are removed (logged under Changed in `python/CHANGELOG.md`: may break code that checks they exist). Matches R's
  `*_with_var_cpp` to ~1e-14. New `tests/test_glm_variance_outputs.py`; 821 Python tests pass against the Nov 9 built
  extension. Docstrings and READMEs updated. Follow-up: v1.0.6-TODO-188.
- [ ] TODO-88 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent):
  **`min_eigenvalue_information` is always NaN in Cox regression, in R and Python.** In
  `R/EDI/src/fast_coxph_regression.cpp` the field is NaN-initialized (`CoxFitResult`, ~L261), copied (~L512) and
  returned (~L691-895), but nothing ever computes it. Its comment says it is "computed only when !converged"
  (optimizer_diagnostics_report.md TODO-1), so the non-converged fallback path was meant to fill it and doesn't.
  Fix: compute the minimum eigenvalue of the observed information at the returned beta on that path (or remove
  the field everywhere); add a test with a non-converging fit that checks it is finite. C++ change: needs a
  targeted compile to verify and an owner rebuild.
- [ ] TODO-89 (added 2026-11-17, agent, owner request; found by the edi-from-python article agent): **The Python
  API's conventions are inconsistent.** Index arguments are mixed: `j_T` and the Clayton `pair_idx` are 0-based,
  while `fixed_idx`, `j` and `j_treat` are 1-based. Return-value keys differ between kernels: the GLM kernels
  return `b`/`XtWX`, Cox returns `coefficients`/`vcov`. `vignettes/articles/edi-from-python.Rmd` documents both
  as they are. Fix: decide one convention for the Python layer (0-based indices and one key set are the natural
  Python choice), translate at the binding layer so the C++ and R stay unchanged, deprecate the old forms with a
  warning for a release, and update the stub, README, CHANGELOG and the article. Breaking for Python users, so
  schedule with a minor version bump.
- [ ] TODO-90 (added 2026-11-17, agent, owner request; found by the missing-data and censoring
  article agent): **`InferenceSurvivalKMDiff` returns `NA` on interval-censored data with no warning, despite its
  documented bootstrap fallback.** `compute_asymp_confidence_interval()`, `compute_asymp_two_sided_pval()` and
  `compute_bootstrap_confidence_interval(B = 501)` all return `NA`; the bootstrap call takes 0.07 s, so it is not
  actually resampling. The roxygen (`R/EDI/R/inference_survival_km_diff.R`) says these "silently fall back to a
  nonparametric bootstrap instead of returning NA" and that the interval-censored path "relies entirely on the
  bootstrap fallback". Same on installed 1.0.4. Repro (shared with TODO-91):
  ```r
  set.seed(7); n = 120
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects(); w = des$get_w()
  t_event = rweibull(n, 1.5, 12 * exp(0.4 * w)); L = floor(t_event / 3) * 3
  des$add_all_subject_responses(y_Ls = L, y_Rs = L + 3)
  inf = InferenceSurvivalKMDiff$new(des); inf$compute_asymp_confidence_interval()   # NA, no warning
  ```
  Fix: find why the bootstrap returns at once (likely every replicate's estimate is non-finite on the
  interval-censored Turnbull path, or an early return), make the fallback work or warn and say why; test on
  this fixture. `articles/censored-survival-outcomes.Rmd` lists KMDiff as accepting interval
  censoring but does not demonstrate it; add a demo once fixed.
  Note 2026-11-18 (v1.0.6-TODO-112 agent): cause found, not fixed. `bootstrap_confidence_interval_extreme()`
  (`inference_all_abstract_non_param_boot.R` ~L1134) flags the CI because `bootstrap_outcome_scale()` uses `private$y`,
  which is all NA under interval censoring, so it falls back to scale 1 and caps the width at 5; a visit-grid interval
  of width 6 counts as extreme. Fix: compute the scale from finite `y_L`/`y_R` (midpoints). Likely also v1.0.6-TODO-91.
  Update 2026-11-18: the same `bootstrap_outcome_scale()` fix makes the KMDiff percentile CI on the repro finite
  ([0, 9]); check whether the rest of this TODO (the "bootstrap fallback does not resample") still holds before closing.
  Re-check 2026-11-18 (agent, uncommitted): can close once committed. On the repro every method is finite, a warned
  NA (BCa boundary, studentized: no SE on the Turnbull path, jackknife of a median) or a clear error (randomization
  CI). The fallback does resample now (1004 `icfit` calls for B = 501; ~1.5-3 s, not 0.07 s); asymp CI equals the
  bootstrap CI. Fixed here: the Bayesian-bootstrap p-value (icfit takes no weights) was a silent NA; it now stops up
  front under general censoring. Test `test-km-diff-interval-censored-bootstrap-fallback.R` (27); known_todo row and
  allowlist row removed; NA-gate smoke test passes. NEWS added. Still open from the TODO text: a KMDiff
  interval-censoring demo in `articles/censored-survival-outcomes.Rmd`. Found: v1.0.6-TODO-140, -141.
  Article demo done 2026-11-18 (agent, uncommitted): `censored-survival-outcomes.Rmd` gains "Median and restricted mean
  survival differences" (KMDiff 6.00 [-3, 9], RMST tau = 24: 3.65 [1.135, 6.531], rand p 0.02 both); strict render
  PASS. Found: v1.0.6-TODO-144.
- [ ] TODO-91 (added 2026-11-17, agent, owner request; found by the missing-data and censoring
  article agent): **`InferenceSurvivalRestrictedMeanDiff`'s bootstrap interval is `NA` on interval-censored data**,
  with no warning, even with `type = "percentile"` and B = 501, although
  `approximate_bootstrap_distribution_beta_hat_T(B = 101)` is all finite (range 0.29 to 6.65). Seen on the
  article's visit-schedule data set (same construction as the TODO-90 repro, seed 7; `R/EDI/R/inference_survival_rmst.R`).
  A percentile interval from a finite distribution should never be `NA`, so the interval step is discarding the
  draws (check the CI path's finiteness/minimum-draw filter and any interval-censoring-specific branch). Test on
  that fixture; add the article demo once fixed.
  Status 2026-11-18 (v1.0.6-TODO-115 agent, uncommitted): fixed by the `bootstrap_outcome_scale()` change (see
  TODO-115): repro percentile CI [1.17, 7.16], asymp CI [2.06, 7.45]; known-issue row removed from
  `run_public_argument_data_shape_matrix.R`. Close when committed; NEWS line pending. Its allowlist row in
  `R/package_tests/na_audit_allowlist.csv` should then be removed.
- [ ] TODO-92 (added 2026-11-17, agent, owner request; found by the missing-data and censoring
  article agent): **The BCa boundary warning recommends the B that was just used.** On interval-censored data,
  `InferenceSurvivalLogRank`'s BCa interval at B = 501 returns `NA` with "BCa adjustment on the boundary at B = 501
  ... increase B (>= 501 recommended) or use type = \"percentile\"". The message comes from
  `R/EDI/R/helper_robust_sandwich.R` (~L477-480) for every class. Fix: when B is already >= 501, drop the
  "increase B" advice (say the adjustment is on the boundary for this data and suggest `type = "percentile"`),
  and check whether this is the same epsilon-clamp cause as v1.0.6-TODO-75 (the boundary test on |adj_z| > 8).
  Test the message at B = 200 and B = 501.
  Status 2026-11-18 (agent, uncommitted): v1.0.6-TODO-75, -92 and -114 fixed together. `bca_pval_core()`
  (`inference_ext_bca_bootstrap_ci.R`) returns the 2/B floor when delta is outside the bootstrap support (was NA via the
  epsilon clamp and |adj_z| > 8); a boundary BCa p-value is still NA but now warns `edi_bootstrap_bca_boundary_warning`
  (`what = "p-value"`), like the CI; at B >= 501 the warning no longer says to increase B (`helper_robust_sandwich.R`
  `edi_warn_bca_boundary_once()`). Changes results (NA -> 2/B); NEWS line pending under "Changes that alter results".
  New test `test-bootstrap-bca-pval-outside-support-and-boundary-warning.R`; one bulk test updated (NA -> 2/B). On
  closing: remove the v1.0.6-TODO-75 rows of `R/package_tests/na_audit_allowlist.csv` and widen its BCa-boundary
  intentional row to the bootstrap p-value methods. Still silent: the "unstable bias or acceleration" BCa NA (CI and
  p-value). The LogRank boundary case is really a sign bug in LogRank bootstrap draws on interval data (not yet filed).
- [ ] TODO-93 (added 2026-11-17, agent, owner request; found by the missing-data and censoring
  article agent): **A missing non-survival response gives an error about survival-only arguments.**
  `add_all_subject_responses()` with an `NA` in `ys` for a continuous or incidence response stops with "Each
  subject needs either ys or both y_Ls and y_Rs." (`R/EDI/R/design_abstract.R` ~L434 and
  `design_fixed_abstract.R` ~L139). Fix: for non-survival response types say that responses may not be `NA`
  (name the first offending subject) and point to the missing-outcomes section of
  `articles/missing-covariates.Rmd`; keep the y_L/y_R wording for survival only. Test both.
  Status 2026-11-18: fixed with v1.0.6-TODO-100 (`missing_response_error_message()` in `design_abstract.R`; test in
  `test-design-responses-reject-na.R`); uncommitted.
- [ ] TODO-94 (added 2026-11-17, agent, owner request; found by the missing-data and censoring
  article agent; minor): **`add_one_subject_response(1, y = NA_real_)` is accepted silently on a continuous
  design.** `assert_y()` (`R/EDI/R/design_abstract.R` ~L1083) has no NA check for continuous responses. The result
  is not wrong (inference later stops with "This experiment is incomplete..."), but the error comes far from the
  cause. Fix: reject `NA` at `add_one_subject_response()` for non-survival types with the same message as
  v1.0.6-TODO-93; test it.
  Status 2026-11-18: fixed with v1.0.6-TODO-100 (`missing_response_error_message()` in `design_abstract.R`; test in
  `test-design-responses-reject-na.R`); uncommitted.

### Test dimensions the v1.0.6 vignettes exposed (TODO-95..99)

The agents writing the new pkgdown articles found 22 bugs (v1.0.6-TODO-73..94) that the testthat suite, the
comprehensive suite, the argument-combination harness and the audit jobs had all missed. They were not wrong numbers
on canonical inputs. They were silent `NA`s, messages and docs that say something false, documented options that crash
(`n = NULL`, unequal blocks, interval censoring), and code outside the registry (`InferenceRandCustom`, the Python
kernels). checkmate did not catch them because the inputs are legal; the downstream code is what fails. These five
TODOs add the missing dimensions.

- [ ] TODO-95 (added 2026-11-18, agent, owner request): **`NA` audit in the comprehensive suite.** A case whose
  inputs are finite and whose estimate, CI bound or p-value comes back `NA` without a warning or error is a failure,
  not "unsupported". Allowlist a row only against an open release-prefixed TODO, as calibration rows are (see the
  calibration-acceptance rule). Would have caught v1.0.6-TODO-74, -75, -90 and -91. Location: the quality gates in
  `R/package_tests/` (`comprehensive_suite_quality_gate_summary.csv` and its checker); extend the same gate to
  `public_argument_combination_quality_gates.csv`. Also add an allowlisted list of intentional `NA` returns (e.g. a
  documented "not estimable" path that warns) so the gate stays honest.
  Status 2026-11-18 (agent, uncommitted): gate implemented in both checkers. New `R/package_tests/na_audit_gate.R`
  (rule, allowlist validation against open `- [ ] TODO-n` lines, `digest` of the gitignored per-response results),
  `na_audit_allowlist.csv` (kind todo|intentional; intentional rows must have a recorded warning),
  `smoke_test_na_audit_gate.R`; `comprehensive_tests.R` `safe_call` now records warning classes
  (`...; warnings=none|<classes>`). Hard gates `silent_na_output`, `silent_na_output_missing_input`,
  `na_allowlist_invalid`; argument-combination gate reads TODO-97's `output_outcome` (`recorded_na` counts as
  silent). Caveat: today's comprehensive results predate warning capture, so all 591,100 NA rows are "warning status
  unknown" (hard_later): 82,683 allowlisted (68,895 under v1.0.6-TODO-75), 508,417 not, in 1,371 groups across 81
  classes. Open (owner): commit the digest `comprehensive_suite_na_audit.csv` (2 MB) or make it part of a results
  refresh; regenerate the comprehensive results so unknown rows resolve to silent/warned (the comprehensive smoke test
  will then fail until they are fixed or allowlisted, by design); regenerate drift artifacts; policy: should declared
  non-estimable NAs without a warning stay report-only? Silent NAs seen with no TODO yet: studentized and
  Bayesian-bootstrap CIs/p-values (CoxPH ~1, LogBinomial, PropGCompMeanDiff), m-out-of-n/subsampling on
  KKCondLogitGLMMOneLik, ZIP ~1 parametric bootstrap, ExactFisher estimate/CI on FixedBlocking (pima).

- [ ] TODO-96 (added 2026-11-18, agent, owner request): **Mechanical message audit.** Every argument name quoted in a
  `stop()`, `warning()` or `message()` string in `R/EDI/R/` (e.g. `` `equal_block_sizes = FALSE` ``, `\code{B}`)
  must be a formal of that function, of the class's `initialize`, or of a listed public method. Fits the audit-jobs
  framework: new `.github/scripts/audits/message_args.py` + `test_audit_message_args.py` + workflow, following
  `docs_claims.py`. Would have caught v1.0.6-TODO-73. Stretch: flag numeric advice in a message that equals the value
  just used (v1.0.6-TODO-92's "use B >= 501" after B = 501) by a targeted testthat check rather than the static audit.
  Status 2026-11-18 (agent, uncommitted): implemented as `.github/scripts/audits/message_args.py`,
  `test_audit_message_args.py` (13 tests) and `audit-message-args.yml` (weekly, Wed 07:07 UTC; one line added to
  `audit-status.yml`). Real tree: 3 findings, all real: `design_blocking_abstract.R:289` "Set equal_block_sizes = FALSE"
  reached by 13 classes that lack it (v1.0.6-TODO-73, id `message-args-d46d9b383`); `inference_all_abstract.R:1092`
  advises `num_cores = 1`, which no Inference class takes (use `set_num_cores(1)`; id `message-args-dcfba122d`);
  `inference_suite.R:4996` prints `weighting =` for `combined_evidence_weighting` (id `message-args-d7bd0d2e5`).
  Not covered: messages built in a variable first (~40 of ~870), and the numeric-advice stretch goal.

- [ ] TODO-97 (added 2026-11-18, agent, owner request): **Option-matrix (data-shape) tests.** Pairwise coverage, per
  design and inference family, over the non-default but documented settings the canonical fixtures never use:
  `n = NULL` (sequential designs, analyzed mid-stream and at the end), unequal block / cluster sizes, censoring type
  (none / right / interval), a missing response or covariate, and effect size (null vs. strong enough that 0 is
  outside the bootstrap distribution). Each cell must either succeed with finite output or fail with a clear,
  correct error; a silent `NA` is a failure (shares the rule with v1.0.6-TODO-95). Build on the existing
  argument-combination harness (`R/package_tests/generate_public_argument_combinations.R`,
  `public_argument_combination_fixtures.R`): its axes come from checkmate contracts, which only see argument types,
  so add data-shape axes to the fixtures rather than a new harness. Would have caught v1.0.6-TODO-73, -74, -76..78,
  -90, -91. Also cover `InferenceRandCustom` with R and C++ statistics returning one value, several values and `NA`
  (v1.0.6-TODO-81..83).
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
- [ ] TODO-98 (added 2026-11-18, agent, owner request): **Scenario tests written from the docs alone, per feature
  area.** The six article agents were in effect six runs of the agent harness (the owner's gitignored harness-audit notes)
  on new territory, and found 22 bugs. Make this routine: when a feature area lands or changes (a new design, an
  inference family, the Python kernels, the custom-statistic API), run one docs-only agent that must complete a
  realistic task end to end using the installed help and vignettes, and file what it trips over. Decide (owner) the
  trigger: a release-gate checklist item, or a step in the new-feature plan template. Record each run's findings
  with release-prefixed TODOs, as here.
  Decided (owner, 2026-11-18): run every feature area as a weekly CI job (the `ANTHROPIC_API_KEY` secret is set, as
  for the other Claude CI jobs). An area is skipped when nothing relevant to it changed since its last run, and the
  job keeps a durable store of what earlier runs learned (findings, workarounds, already-filed TODOs) that each run
  reads first and updates. Being built 2026-11-18.
  Status 2026-11-18 (agent, uncommitted, never run on GitHub): built. `.github/workflows/audit-docs-scenarios.yml`
  (Saturdays 01:07 UTC + dispatch), driver `.github/scripts/docs_scenarios.py` (plan/render/collect/report; 19 tests),
  areas `.github/prompts/docs_scenario_areas.json` (17), prompt `.github/prompts/docs_scenario.md`; one line in
  `audit-status.yml`; runbook section 7. Skip: an area runs only if `scripts/significant_changes.py` reports a change in
  its paths since its last successful commit (docs/Rd changes count; comment-only code edits don't); at most 8 areas
  per run; no due area -> no EDI build. State on the `audit-notes` branch under `docs-scenarios/` (state.json,
  learnings/<area>.md read first and appended each run, findings.jsonl with filed/closed/dismissed status re-derived
  from the release file and dismissed_decisions.md). Agent runs `claude -p` with no source checkout (installed EDI with
  help + vignettes, articles as text, wheel venv for Python). Output: one PR per run with new findings
  (`audit/docs-scenarios/<date>-run<id>`). Agent's estimate: $5-12 per area, ~4 h for an 8-area run. Open: first
  dispatch with `areas: factorial` to test CLI flags, timeouts and build time; owner decisions on the 8-area/$15 caps,
  effort level, and a periodic re-run of unchanged areas.
  Decided (owner, 2026-11-18): weekly; Claude Opus 5.5 at effort `high`; $30 per-area cap
  (`.github/prompts/docs_scenario_areas.json` `defaults`); unchanged areas re-run every 42 days
  (`rerun_unchanged_after_days`; `due_reason()` in `.github/scripts/docs_scenarios.py`). Run order within the 8-area
  cap: never-run areas, then areas with relevant changes, then the periodic re-runs (oldest first in each group), so
  changes are never pushed out by re-runs. Two tests added (21 pass).
- [ ] TODO-99 (added 2026-11-18, agent, owner request): **Articles as a CI gate.** Render every vignette and
  `vignettes/articles/*.Rmd` with warnings as errors (`options(warn = 2)` or a knitr hook failing on any
  `warning`/`error` chunk output) so the workflows the articles document keep working. Today
  `.github/workflows/pkgdown.yaml` builds the site only on push to main and does not fail on a chunk warning.
  Add a job (PR + push, path-filtered on `R/EDI/R/**` and `R/EDI/vignettes/**`) or a step before
  `build_site_github_pages`. Mind the runtime: the articles take seconds to ~20 s each now; keep the gate under
  ~10 min and note which articles compile code at render time (`custom-randomization-statistic.Rmd` uses
  `Rcpp::cppFunction`). Not in pre-push (keeps the hook lean, per the pre-push rule).
  Status 2026-11-18 (agent, uncommitted): `scripts/render_articles_strict.R` (fresh process per file, fails on chunk
  or inline warnings/errors, `--load-all`, `--workers<=2`, `--timeout`) and `.github/workflows/articles-strict.yml`
  (push + PR, path-filtered; actionlint clean). Verified on injected warnings. Full run from source: 28 files,
  12 m 20 s wall on 2 workers. Decided (owner, 2026-11-18): the ~12 min runtime is acceptable; no CI-size switch.
  Open (owner): (1, settled above) runtime is over the ~10 min target because three articles take
  4-7 min each (`matching-on-the-fly` 398 s, `planning-a-study` 305 s, `learn-statistics-through-edi` 240 s); a
  CI-size switch for their simulations, or run them on push to main only; (2) `cluster-and-factorial-experiments.Rmd`
  chunk `cluster-warning` fails because it shows EDI's cluster-SE warning on purpose; either `warning = FALSE` and
  show the text another way, or a per-chunk opt-out in the gate.
  Decided (owner, 2026-11-18): per-chunk opt-out. Done: chunk option `strict_expect_warning = TRUE` exempts that
  chunk's warnings (never errors) and fails the file if the chunk shows no warning, so stale prose is caught;
  `cluster-warning` uses it and the article passes (7.4 s from source). Remaining: commit, then watch the first CI run.

- [x] TODO-100 (added 2026-11-18, agent, owner request): **Audit `assertNumeric` calls that let `NA` through.** *(ticked by the TODO audit 2026-11-18: R/EDI/R/design_abstract.R:323; R/EDI/R/inference_ordinal_partial_proportional_odds.R:145; R/EDI/R/design_abstract.R:433; R/EDI/R/design_fixed_abstract.R:118; R/EDI/R/design_abstract.R:971; R/EDI/R/design_abstract.R:310; R/EDI/R/design_abstract.R:227; R/EDI/R/design_abstract.R:382; R/EDI/tests/tes...)*
  checkmate's `assertNumeric()` defaults to `any.missing = TRUE`, so `NA` passes unless the call says otherwise. That
  is how `add_one_subject_response(1, y = NA)` is accepted (`R/EDI/R/design_abstract.R` ~L310,
  `assertNumeric(y, len = 1, null.ok = TRUE)`; v1.0.6-TODO-94). On 2026-11-18 `R/EDI/R/` had ~207 single-line
  `assertNumeric(` calls, ~195 of them without `any.missing = FALSE` (multi-line calls not counted). For each, decide
  whether `NA` is legitimate; if not, add `any.missing = FALSE`, and if so, leave a short comment saying why.
  `assertNumber()` needs no audit: its `na.ok` already defaults to `FALSE`. Watch out: 559 assertion sites are inside
  `should_run_asserts()`, so they are skipped when asserts are off (e.g. `SimulationFramework`'s
  `turn_off_asserts_for_speed`); an NA check that guards correctness, not just a clear message, belongs outside that
  gate, as the censoring checks in `add_one_subject_response()` already are. Add a test per tightened public entry
  point. This is the narrow validation fix; most of the 22 vignette bugs need v1.0.6-TODO-95 and -97 instead.
  Status 2026-11-18 (agent, uncommitted): done. 209 `assertNumeric` calls (getParseData): 190 got
  `any.missing = FALSE`, 7 left with a why-comment (`ys`/`y_Ls`/`y_Rs` in `add_all_subject_responses`, `y_temp` in
  `transform_y`), 0 unsure; 12 already had it. Always-on (outside `should_run_asserts()`) NA checks added for
  `add_one_subject_response` `y`/`y_R`, `prob_T`, Pocock-Simon `p_best`/`weights`. New `delta` check in
  `compute_rand_two_sided_pval` (cached null path skipped the old one). Tests:
  `test-design-responses-reject-na.R` (61) and `test-inference-args-reject-na.R` (844 passed on the coordinator's
  re-run); 52 related test files, 0 failures. Follow-up: 472 (class, method) pairs in 91 classes have no argument
  check and return NA for an NA argument (own Wald/asymp overrides, score/gradient/LR incl. Bartlett, jackknife Wald,
  GComp RR paths); the test's `na_arg_unguarded` allowlist cites this TODO until a follow-up TODO is filed.

- [ ] TODO-101 (added 2026-11-18, agent, owner request): **Input-validation gate for the Python kernels.** The
  Python package does almost no input checking: `python/src/edi_kernels/__init__.py` re-exports the pybind11
  functions from `_core` directly, and the 64 bindings in `python/cpp/bindings_*.cpp` have one explicit check (the
  category count in `bindings_ordinal.cpp`). pybind11 converts types but checks nothing else, so a non-0/1 `w`, a
  NaN in `y` or mismatched lengths go straight into the C++ solvers, which R never lets happen because checkmate
  runs first. v1.0.6-TODO-86 (silent `nan`, logrank sign flip on 1/2-coded `w`) is the known result.
  Decided (owner, 2026-11-18): no new dependency. Python has no checkmate equivalent for numpy values (`beartype`,
  `typeguard` and `jaxtyping` check types and shapes, not finite or 0/1 values; `pydantic` is heavy and awkward with
  arrays; `icontract`/`deal` still need every check written by hand). Plan:
  1. A private `edi_kernels/_checks.py` (numpy only, ~100 lines) with checkmate-named helpers:
     `assert_numeric(x, n=None, finite=True)`, `assert_binary(w)`, `assert_count(k)`, `assert_choice(s, choices)`,
     `assert_same_length(...)`, each raising `ValueError` naming the argument.
  2. `__init__.py` wraps each `_core` function in a thin Python function that checks its inputs, then calls the
     kernel. Update `_core.pyi`/stubs as needed.
  3. A switch mirroring R's `should_run_asserts()` (e.g. `edi_kernels.set_checks(False)`) for speed; checks that
     guard correctness (0/1 `w`, matching lengths) stay on regardless, the rule v1.0.6-TODO-100 sets for R.
  4. Declare each kernel's argument rules in one table in `_checks.py`, and add a test comparing it with the R
     checkmate rules for the same kernels (`R/package_tests/checkmate_argument_contracts.csv`) so they don't drift;
     consider wiring it into the rpy-parity audit.
  5. Tests: a parametrized pytest per rule (NaN, wrong length, non-0/1 `w` with 1/2 and -1/1 coding), covering
     v1.0.6-TODO-86's repro. Update the README and `python/CHANGELOG.md`. Python package; takes effect when the
     wheel is rebuilt.
  Status 2026-11-18 (agent, uncommitted): implemented. `python/src/edi_kernels/_checks.py` (helpers, the `KERNELS`
  rules table for all 63 exports, `set_checks()`/`get_checks()`, `wrap_kernel()`), wrappers in `__init__.py`,
  `python/tests/test_input_checks.py` (593 new tests; suite 791 passed, re-run by the coordinator), READMEs and
  CHANGELOG. With checks off, 0/1 (`w`, `w_r`, `dead`) and matching-length checks still run. No R checkmate rows
  exist for `_cpp` functions, so the R comparison covers only 7 class-argument pairs; the rest are pinned as
  "no R rule". Overhead on `fast_ols`: 11 to 30 us at n = 100, 124 to 174 us at n = 10,000. Not done: rpy-parity
  wiring, benchmarks with `set_checks(False)`, a mypy/pyright check of the stubs. Close when committed and the
  wheel is rebuilt.

### Silent fallbacks and out-of-bounds reads in the C++ kernels (TODO-102..104)

Found 2026-11-18 by the v1.0.6-TODO-101 agent while writing the Python input checks. The Python wrappers now block
all three, but direct callers of the R `_cpp` functions and of `edi_kernels._core` are still exposed. A fourth
report (`fast_robust_regression` silently running MM for any `method` other than `"M"`) was checked by the
coordinator and is not a bug: `fast_robust_regression.cpp` ~L78 throws on anything but `"M"`/`"MM"`, and the
2026-11-17 `_core` build raises for `method = "bogus"`.

- [ ] TODO-102 (added 2026-11-18, agent, owner request; minor): **An unknown `requested_stat` makes the survival
  stat kernels return `NA` silently.** `get_survival_stat_for_group_result_at_tau()` (`R/EDI/src/fast_survival_stats.cpp`
  ~L157-176) handles `"median"` and `"restricted_mean"` and otherwise falls through to `return NA_REAL;`, so
  `get_survival_stat_diff(..., requested_stat = "mean")` (Python) or a typo from R returns `NA` with no error. Fix:
  throw `std::invalid_argument` naming the accepted values on any other string; test from R (`_cpp`) and Python
  (`_core`). Needs a targeted compile and a wheel rebuild.

- [ ] TODO-103 (added 2026-11-18, agent, owner request; minor): **An unknown `family` in `gee_pairs_singletons`
  silently becomes gaussian.** Both `R/EDI/src/fast_gee.cpp` ~L322-324 (`gee_pairs_singletons_weighted_cpp`) and
  `python/cpp/bindings_incidence.cpp` ~L63-65 default to `GEEFamily::GAUSSIAN` and only switch on `"binomial"` /
  `"poisson"`, so `"Binomial"`, `"logit"` or a typo fits a linear model with no warning. Fix: accept exactly
  `"gaussian"`, `"binomial"`, `"poisson"` and throw otherwise, in both places (better: one shared parse helper in the
  core so the two can't drift); test both. Check the R callers pass one of the three. Needs a targeted compile and a
  wheel rebuild.

- [ ] TODO-104 (added 2026-11-18, agent, owner request): **`fast_lbeta` and the vector `fast_pchisq_upper` read past
  the end of a shorter second array.** In `python/cpp/bindings_fast_math.cpp` (~L41 `fast_pchisq_upper`, ~L96
  `fast_lbeta`) the loop runs over the first argument's size and indexes the second (`df[i]`, `b[i]`) without
  checking its length, so a shorter `df`/`b` is undefined behavior (garbage or a crash), not an error. Python-only
  bindings; the v1.0.6-TODO-101 wrappers now reject mismatched lengths, but `_core` is still exposed. Fix: check
  `a.size() == b.size()` (or broadcast a length-1 second argument, numpy-style) and throw otherwise; sweep the rest of
  `bindings_fast_math.cpp` for the same pattern; add a `_core` test. Needs a wheel rebuild.

### Argument-check gaps beyond assertNumeric (TODO-105..106)

- [ ] TODO-105 (added 2026-11-18, agent, owner request; follow-up to v1.0.6-TODO-100): **472 (class, method) pairs in
  91 Inference classes have no argument check and return `NA` for an `NA` argument instead of erroring.**
  v1.0.6-TODO-100 could only tighten existing `assertNumeric` calls; these methods have none. A sweep calling every
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

- [x] TODO-106 (added 2026-11-18, agent, owner request): **Audit every other checkmate assertion in `R/EDI/R/`.** *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_rand.R:375; R/EDI/R/inference_ordinal_partial_proportional_odds.R:144; R/EDI/R/design_abstract.R:327; R/EDI/R/design_abstract.R:496; R/EDI/R/inference_rand_custom.R:77; R/EDI/tests/testthat/test-inference-args-reject-nonscalar-nonfinite.R; R/EDI/tests/testthat/test-...)*
  v1.0.6-TODO-100 covered only `assertNumeric`'s `any.missing` default. The other ~310 calls (2026-11-18:
  `assertCount` 84, `assertFlag` 59, `assertChoice` 48, `assertList` 22, `assertFunction` 19, `assertCharacter` 19,
  `assertNumber` 17, `assertIntegerish` 17, `assertLogical` 8, `assertSubset`/`assertString`/`assertFactor`/
  `assertClass` 4 each, `assertDataFrame` 2) and the 207 `assertNumeric` calls again for defaults other than NA have
  checkmate's permissive defaults to check:
  - `finite = FALSE` in `assertNumeric`/`assertNumber`/`assertIntegerish`: `Inf` passes (e.g. `alpha = Inf`).
  - Missing `lower`/`upper` (an `alpha` outside (0, 1), a negative `B`, a `prob_T` outside (0, 1)).
  - Missing `len = 1` where a scalar is meant (a vector silently uses its first element or recycles).
  - `any.missing = TRUE` in `assertCharacter`, `assertIntegerish`, `assertList`, `assertLogical`.
  - `assertCount` allows 0 unless `positive = TRUE` (e.g. `B = 0`, `r = 0`, `num_cores = 0`).
  - `null.ok = TRUE` where `NULL` is not actually handled downstream.
  - `assertFunction` without `nargs`/`args` where the callback's signature matters (e.g. custom statistics).
  - Asserts inside `should_run_asserts()` that guard correctness (the v1.0.6-TODO-100 rule: move those out).
  - Arguments with no assert at all on public entry points (overlaps v1.0.6-TODO-105 for the inference methods).
  Classify each call as fine / tighten / intentionally loose (comment why), parse with `getParseData` to catch
  multi-line calls, add tests per tightened public entry point, and run the related test files. Also consider a
  small static check (like v1.0.6-TODO-96's audit) that flags new `assertNumeric`/`assertNumber` calls without an
  explicit `finite`/`any.missing` choice, so the gap doesn't come back.
  Status 2026-11-18 (agent, uncommitted): done. 555 checkmate calls (all assert*): 232 tightened, 10 intentionally loose
  (commented), 313 fine, 0 unsure; ~80 `R/EDI/R` files. Tightened: `len = 1` on alpha (91), delta (64) and other
  scalars; `finite = TRUE` on all delta/delta_0 (`delta = Inf` gave p = 0), root_tolerance, urn/Pocock weights,
  `assert_y()` continuous; alpha upper bound `1 - .Machine$double.xmin` (== 1, so `alpha = 1` passed) -> `1 -
  .Machine$double.eps` (93 sites); any.missing on strata/cluster cols, suite classes, tuning grids; 8 assertLogical ->
  assertFlag; `Design$new(n = 0)` rejected; `assertCount(as.integer(x))` truncation removed (5); RandCustom statistic
  must take (y, w, dead); `overwrite_all_subject_assignments()` gets an always-on 0/1/NA/length check. Bug fixed:
  `transform_y()` errored on any censored or not-yet-responded row. Tests: `test-inference-args-reject-nonscalar-nonfinite.R`
  (1377), `test-design-args-reject-nonfinite-and-nonscalar.R` (27), `test-transform-y-with-censored-rows.R` (5); 104
  related files, 0 failures. Static check saved as `R/package_tests/check_checkmate_explicit_defaults.R` (flags 16
  sites today, all loose/fine; needs `# checkmate-loose: <why>` opt-outs before joining pre-push; owner decision).
  Not fixed: `inference_survival_GLMM_weibull_frailty_loggamma.R:998` clamps `U2` to `1 - .Machine$double.xmin` (== 1,
  a no-op), so `U2 = 1` can give a survival time of 0 (rare).
### Bugs found by the data-shape matrix (TODO-107..115)

Found 2026-11-18 by the v1.0.6-TODO-97 matrix (`R/package_tests/run_public_argument_data_shape_matrix.R`; fixture
ids below are its cell ids, rebuilt with `build_data_shape_fixture(id)` from
`R/package_tests/public_argument_combination_fixtures.R`). When one closes, drop its `known_todo` mapping there.

- [x] TODO-107 (added 2026-11-18, agent, owner request): **KK14/KK21 crash when `design_formula` names a covariate *(ticked by the TODO audit 2026-11-18: R/EDI/R/helper_model_matrix.R:145; R/EDI/R/design_abstract.R:1221; R/EDI/R/design_seq_one_by_one_KK14.R:149; R/EDI/tests/testthat/test-kk-design-formula-covariate-constant-among-enrolled.R; R/EDI/NEWS.md:204)*
  that is still constant among the subjects enrolled so far.** "object 'g' not found" at subject 5.
  `covariate_impute_if_necessary_and_then_create_model_matrix()` (`R/EDI/R/design_abstract.R` ~L1196) drops constant
  columns before applying the formula. Repro:
  `X = data.frame(x1 = rnorm(20), g = factor(rep(c("a","b"), each = 10)));
  d = DesignSeqOneByOneKK21$new(response_type = "continuous", n = 20, design_formula = ~ x1 + g, seed = 1);
  for (i in 1:20) d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])`. Fix: apply the formula first
  (or keep formula-named columns and handle the constant column in the model matrix); test KK14, KK21, KK21stepwise.
  Status 2026-11-18 (agent, uncommitted): fixed. `helper_model_matrix.R` gains `constant_formula_named_columns()` and
  `create_model_matrix_with_constant_formula_columns()` (used in `design_abstract.R` only when a formula-named column is
  constant); KK14 `assign_wt` sends a subject to the reservoir when no covariate varies yet (`rank_prev == 0`, was a
  `solve()` on 0 x 0); same latent fix in `design_fixed_optimal_blocks.R`. Only formerly-crashing paths change: an A/B
  over 72 KK cases gave identical `w`; ~30 KK golden/migration test files pass. Test
  `test-kk-design-formula-covariate-constant-among-enrolled.R` (38). NEWS line pending. A separate KK21stepwise crash
  found along the way is v1.0.6-TODO-120.
- [x] TODO-108 (added 2026-11-18, agent, owner request): **BCa bootstrap and jackknife return NA with no warning on *(ticked by the TODO audit 2026-11-18: R/EDI/R/design_abstract.R:1217; R/EDI/R/inference_continuous_lin.R:309; R/EDI/tests/testthat/test-blocking-strata-in-design-formula-bca-jackknife.R; R/EDI/R/inference_all_abstract_non_param_boot.R:2306; a BCa interval or p-value that is NA for lack of jackknife replicates warns; R/EDI/NEWS.md:84)*
  `DesignFixedBlocking` when `design_formula` names the strata column.** Reasons recorded only on the object:
  `bootstrap_bca_jackknife_unavailable`, `jackknife_estimate_unavailable`. `~ .` or `~ x` work. Seen for OLS, Lin,
  RobustRegr, RiskDiff, FractionalLogit, CoxPH, Poisson. Different cause from v1.0.6-TODO-74. Repro:
  `set.seed(1); n = 40; Xb = data.frame(x = rnorm(n), s = factor(rep(c("a","b"), each = 20)));
  db = DesignFixedBlocking$new(strata_cols = "s", response_type = "continuous", n = n, seed = 1, design_formula = ~ x + s);
  db$add_all_subjects_to_experiment(Xb); db$assign_w_to_all_subjects(); db$add_all_subject_responses(rnorm(n) + db$get_w());
  InferenceContinOLS$new(db)$compute_bootstrap_confidence_interval(B = 501, show_progress = FALSE)` gives `NA NA`.
  Likely a leave-one-out / resample that leaves a stratum level constant. Fix the cause; any remaining NA must warn.
  Status 2026-11-18 (agent, uncommitted): same root cause as v1.0.6-TODO-107 (leave-one-block-out leaves the strata
  column constant; the worker's model-matrix rebuild dropped it before the formula), so it is fixed by TODO-107's
  `design_abstract.R` change and must be committed with it. Second, Lin-only bug fixed: `get_centered_covariates()` read
  `private$X` (NULL on rank-deficient worker draws); now `get_X()`. BCa CI/p-value (incl. Bayesian) now warn when fewer
  than 2 jackknife replicates exist. Repro: BCa CI [0.628, 1.607], jackknife [-0.442, 2.601]. Test
  `test-blocking-strata-in-design-formula-bca-jackknife.R` (39); two existing tests now `expect_warning(...,
  class = "edi_procedure_na_warning")`. Unverified lead: ~12 other classes call `as.matrix(private$X)` directly (KK
  OLS/RobustRegr, StratCox, ZeroAugmented Poisson, Weibull frailty) and may hit the same NULL-X worker problem.
  NEWS line pending.
- [x] TODO-109 (added 2026-11-18, agent, owner request): **`InferenceIncidLogRegr` gives no warning under *(ticked by the TODO audit 2026-11-18: R/EDI/R/helper_robust_sandwich.R:665; R/EDI/R/inference_incidence_logit.R:562; InferenceIncidLogRegr warns once under quasi-complete separation, estimate unchanged; R/EDI/NEWS.md:215; R/EDI/R/inference_incidence_KK_gcomp_abstract.R:814; R/EDI/R/inference_mixin_kk_gee_shared.R:496; R/EDI/R/inferen...)*
  quasi-complete separation.** Estimate 30.7, asymptotic p = 0.998, CI +/- 26,000, while `glm()` warns "fitted
  probabilities numerically 0 or 1". Fixture `data_shape__fixed_blocking__incidence__fixed__equal__none__no__strong`.
  Fix: detect separation (fitted probabilities at 0/1, or diverging coefficients / huge SE) and warn, as `glm()` does;
  check the other logistic-family classes (KK, GEE, GLMM) for the same gap.
  Status 2026-11-18 (agent, uncommitted): fixed for `InferenceIncidLogRegr` and the four logistic g-computation
  classes: classed warning `edi_logistic_separation_warning` (helpers `edi_logistic_n_fitted_extreme`,
  `edi_warn_logistic_separation_once` in `helper_robust_sandwich.R`), once per object, never inside resampling;
  estimates unchanged. Test `test-logistic-separation-warning.R`; 33 related test files pass. Not covered (see the
  agent's report): `InferenceIncidKKGEE` gives estimate 44.6 with p = 0.0000 under separation (sandwich SE collapses;
  worse than this TODO; needs a family-aware check in `inference_mixin_kk_gee_shared.R`); KKCondLogitOneLik and
  KKCondLogitGLMMOneLik give NA with no warning (v1.0.6-TODO-113 pattern); `InferenceIncidProbitRegr` has the same
  gap (estimate 6.85, p = 0.999). NEWS line pending.
- [x] TODO-110 (added 2026-11-18, agent, owner request): **`InferenceRandCustom` with a C++ statistic refuses *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_rand.R:309; R/EDI/R/inference_all_abstract_rand.R:363; R/EDI/R/inference_all_abstract_rand_ci.R:59; C++ custom statistic on incidence: delta = 0 runs (same p as the R form), nonzero delta errors; R-function custom statistic on incidence: delta = 0 runs, nonzero delt...)*
  `compute_rand_two_sided_pval()` on incidence even at `delta = 0`** ("Randomization tests are not supported for
  incidence. Use Zhang method."); the R-function form runs (p = 0.475). Mirror image of v1.0.6-TODO-81 (R form
  bypasses the delta guard). Fix: one guard for both forms, refusing only nonzero `delta` on incidence; test both.
  Status 2026-11-18 (agent, uncommitted): fixed with v1.0.6-TODO-81/-110 together. Cause: "custom statistic?" checked
  only the R-function field, not `compiled_cpp_stat_fn`. Now on incidence `delta = 0` runs for every form and nonzero
  `delta` errors for every form (`inference_all_abstract_rand.R`, `inference_all_abstract_rand_ci.R`). Test
  `test-rand-custom-incidence-delta-guard.R`; the incidence rand-attempt manifest and its bulk test updated. Stale,
  left for the owner (changes the grid): `comprehensive_tests.R` ~L2199 `skip_custom_rand_pval` on incidence, and
  `path_audits_source.R` `cell_rand_custom_p` (~L1577-1586). NEWS line pending.
  Harness widened 2026-11-18 (agent, uncommitted): `comprehensive_tests.R` runs the custom p-value on incidence at
  delta = 0 and adds a delta = 0.5 call expected to error; `path_audits_source.R` `cell_rand_custom_p` no longer
  hard-codes incidence as unsupported (35 path-audit cells NTS -> attempted, compare PASS); the incidence rand-attempt
  manifest, its bulk test and `analyze_comprehensive_tests.R` updated. Also fixed: custom-statistic refusals were
  recorded as "ok ... non-estimable" when the outer class was non-estimable. +2 rows per incidence key (822 on one
  pima shard). Owner: reinstall EDI before regenerating (the installed 1.0.4 lacks this fix), then a rand_custom-only
  incidence shard, then re-render path audits.
- [x] TODO-111 (added 2026-11-18, agent, owner request): **An all-NA custom statistic (R or C++) gives NA estimate and *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_rand_custom.R:101; R/EDI/NEWS.md:224; an all-NA R custom statistic warns (naming the function argument) and returns NA; an all-NA C++ source-string statistic warns naming custom_randomization_statistic_cpp)*
  p-value with no warning** (only `custom_estimate_unavailable` is recorded). Fix: warn (or error) when the observed
  statistic is NA, naming the statistic; related to v1.0.6-TODO-82 (`na.rm`, finite-draw minimum); test both forms.
  Status 2026-11-18 (agent, uncommitted): fixed in `InferenceRandCustom$fit()` (`inference_rand_custom.R` ~L83-99):
  warns once per user-facing call, naming the statistic argument, when the observed statistic is not finite; values
  unchanged (NA). Test `test-rand-custom-nonfinite-statistic-warns.R` (4/4). NEWS line pending. v1.0.6-TODO-82 is a
  different path (shared `inference_all_abstract_rand.R`), not fixed here.
- [x] TODO-112 (added 2026-11-18, agent, owner request): **`InferenceSurvivalKMDiff` returns NA with no warning on *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_survival_km_diff.R:535; KMDiff warns, naming the treated arm, when its median is not reached; R/EDI/R/inference_survival_km_diff.R:323; KMDiff jackknife-Wald NA on uncensored data warns with the bias-guard reason; R/EDI/NEWS.md:229)*
  right-censored data, and its jackknife is NA with no warning on uncensored data.** `compute_estimate()` is a silent
  NA when the treated arm's KM curve never reaches 0.5 (median not reached); the other methods record NA without
  warning. Fixture `fixed_blocking__survival__fixed__unequal__right__yes__strong`; jackknife on plain Bernoulli
  survival. Fix: warn with the reason (median not reached in arm ...; suggest RMST); find why the jackknife is NA.
  Related to v1.0.6-TODO-90 (interval censoring).
  Status 2026-11-18 (agent, uncommitted): fixed in `inference_survival_km_diff.R`. Median not reached: classed warning
  `edi_km_median_not_reached_warning` naming the arm(s) and lowest survival, suggesting RMST; silent inside resampling.
  Jackknife NA (uncensored): not a bug; the leave-one-out median moves among 3 values, so the jackknife bias trips the
  shared `abs(bias) > 2 SE` guard (the jackknife is inconsistent for medians); new public jackknife overrides warn
  `edi_km_jackknife_na_warning` with that reason. Test `test-km-diff-na-warns-with-reason.R` (33). Owner: roxygenize
  (two new public methods); amend the class roxygen sentence about the asymp methods "silently" falling back to the
  bootstrap (NA when the median isn't reached). NEWS line pending.
  Roxygenized 2026-11-18 (coordinator, `R/fast_roxygenize.R`, 0 warnings; 21 Rd files changed, uncommitted).
- [x] TODO-113 (added 2026-11-18, agent, owner request): **Smaller NA-without-warning paths.** Each records a reason on *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_count_likelihood.R:226; Poisson asymptotic inference on a blocked-cluster design warns edi_unsupported_procedure instead of a silent NA; R/EDI/R/inference_all_abstract_non_param_boot.R:1146; a bootstrap CI rejected as extreme warns with its recorded reason; R/EDI/R/...)*
  the object but does not warn: `InferenceCountPoisson` asymptotic CI and p-value on `DesignFixedBlockedCluster`
  (`count_likelihood_asymp_block_size_gt_one_not_supported`); `InferenceOrdinalPropOddsRegr` bootstrap CI on
  `DesignFixedCluster` (`bootstrap_extreme_confidence_interval`); `InferenceOrdinalKKGEE` jackknife on KK21. Fix:
  warn (or refuse with a clear error if unsupported) for each; consider one shared helper so a recorded NA reason
  always warns (the v1.0.6-TODO-95 rule).
  Status 2026-11-18 (agent, uncommitted): done; none was a computation bug. New helper `edi_warn_procedure_na()`
  (`helper_robust_sandwich.R`; class `edi_procedure_na_warning`, fields `procedure`/`reason`, silent inside resampling,
  warns on every user-level call). Poisson/count-likelihood asymp on blocked-cluster now warns `edi_unsupported_procedure`
  (points to bootstrap and randomization, both finite there); `missing_bootstrap_ci()` warns on an extreme CI; the five
  public jackknife methods warn with the specific reason (`jackknife_extreme_summary` was being overwritten by
  `jackknife_estimate_unavailable`). Test `test-recorded-na-reason-warns.R` (19); 41 related files pass. Owner decision:
  `bootstrap_extreme_ci_width_threshold = 5` is in outcome-SD units but applied to log-odds coefficients too (a 5.6-wide
  log-OR CI from 10 clusters is plausibly real); not changed. Related, not fixed: `InferenceOrdinalKKGEE` asymp CI under
  separation is finite but meaningless (21.33, 25.80), no warning (see v1.0.6-TODO-118). NEWS line pending.
- [x] TODO-114 (added 2026-11-18, agent, owner request): **At the BCa boundary the bootstrap p-value is NA with no *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_non_param_boot.R:2271; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:884; BCa p-value NA on the adjustment boundary warns once, like the CI, and the CI still warns; R/EDI/R/inference_ext_bca_bootstrap_ci.R:73; boundary warning advises a larger B only when B <...)*
  warning, while the CI warns.** OLS on `DesignSeqOneByOneBernoulli` with a strong effect, and LogRank on
  interval-censored data, at B = 501. Likely the same root cause as v1.0.6-TODO-75 (`bca_pval_core`, |adj_z| > 8)
  and related to v1.0.6-TODO-92 (boundary message); coordinate with them. Fix: the p-value must warn like the CI
  (or fall back to percentile with a warning).
  Status 2026-11-18 (agent, uncommitted): v1.0.6-TODO-75, -92 and -114 fixed together. `bca_pval_core()`
  (`inference_ext_bca_bootstrap_ci.R`) returns the 2/B floor when delta is outside the bootstrap support (was NA via the
  epsilon clamp and |adj_z| > 8); a boundary BCa p-value is still NA but now warns `edi_bootstrap_bca_boundary_warning`
  (`what = "p-value"`), like the CI; at B >= 501 the warning no longer says to increase B (`helper_robust_sandwich.R`
  `edi_warn_bca_boundary_once()`). Changes results (NA -> 2/B); NEWS line pending under "Changes that alter results".
  New test `test-bootstrap-bca-pval-outside-support-and-boundary-warning.R`; one bulk test updated (NA -> 2/B). On
  closing: remove the v1.0.6-TODO-75 rows of `R/package_tests/na_audit_allowlist.csv` and widen its BCa-boundary
  intentional row to the bootstrap p-value methods. Still silent: the "unstable bias or acceleration" BCa NA (CI and
  p-value). The LogRank boundary case is really a sign bug in LogRank bootstrap draws on interval data (not yet filed).
- [x] TODO-115 (added 2026-11-18, agent, owner request; investigate): **RMST on interval-censored *(ticked by the TODO audit 2026-11-18: R/package_metadata/future_release_plans/release_v1_0_6.md:2016; R/EDI/R/inference_all_abstract_non_param_boot.R:1184; interval-censored outcome scale is on the time scale, not the fallback 1; R/EDI/R/inference_survival_rmst.R:150; R/EDI/R/inference_survival_rmst.R:330; randomization draws use the...)*
  `DesignFixedBlockedCluster` data with a strong effect: randomization p-value >= 0.05 and asymptotic CI NA.** The NA
  CI is probably v1.0.6-TODO-91's cause; the p-value may be a power issue (small n = 40, clusters) rather than a bug.
  Decide which with a small simulation (power at this effect and n), and fix or close with the evidence.
  Status 2026-11-18 (agent): two causes. (1) CI: same as v1.0.6-TODO-91, fixed (uncommitted) in
  `bootstrap_outcome_scale()` (`inference_all_abstract_non_param_boot.R`): under general censoring the scale uses
  exact time / interval midpoint / right-censoring time instead of all-NA `y` (was scale 1, width cap 5). Fixture now:
  asymp CI [8.49, 27.93]. Test `test-rmst-interval-censored-bootstrap-ci.R`. (2) p-value: not a coding bug. The default
  tau (min of the arms' max follow-up) is recomputed in every randomization draw: observed tau 39, null draws 162-180,
  so the observed 24 sits mid-null (p 0.475; tau held at 39: p 0.003). Power sim (n = 40, 10 clusters, 150 sets,
  r = 199): strong effect rejection 0.027 with default tau vs 0.927 with prespecified tau = 30; null 0.047 both. The
  test is valid but has power below alpha at large effects. OWNER DECISION: fix the horizon across draws (pooled or
  observed tau held fixed) or document that `tau` must be prespecified for randomization tests. Also noted: the
  bootstrap percentile CI rejects 12.7% under the null with 10 clusters (anti-conservative, few clusters), and the
  "extreme interval" warning suggests `compute_rand_confidence_interval()`, which RMST refuses.
  Decided (owner, 2026-11-18): fix the horizon across draws. Done (agent, uncommitted): with no user `tau`,
  `initialize()` stores the observed-data horizon (`rmst_observed_tau`); every use goes through `rmst_horizon()`, and
  workers inherit it, so randomization, rand-bootstrap, bootstrap and jackknife draws all use it (bootstrap too: the
  estimand is RMST at a given tau). Observed estimate/SE `identical()` before vs after on 30 seeds. Fixture p 0.475 ->
  0.004. Power sim (K = 300): strong 0.027 -> 0.993, null 0.040. Roxygen text updated. Test
  `test-rmst-horizon-fixed-across-resampling-draws.R` (14); `test-rmst-tau-fast-kernel.R` updated; RMST and related
  tests pass. NEWS added. Leftovers in v1.0.6-TODO-125.
  Roxygenized 2026-11-18 (coordinator, `R/fast_roxygenize.R`, 0 warnings; 21 Rd files changed, uncommitted).

### Found while fixing TODO-109 and TODO-114 (TODO-116..119)

- [x] TODO-116 (added 2026-11-18, agent, owner request): **The BCa "unstable bias or acceleration" NA is silent, for *(ticked by the TODO audit 2026-11-18: R/EDI/R/helper_robust_sandwich.R:483; R/EDI/R/helper_robust_sandwich.R:541; R/EDI/R/helper_robust_sandwich.R:529; R/EDI/R/helper_robust_sandwich.R:537; R/package_tests/na_audit_allowlist.csv:8; R/EDI/tests/testthat/test-bootstrap-bca-unstable-bias-or-acceleration-warning.R:40; R/EDI/tests/testtha...)*
  both the interval and the p-value.** v1.0.6-TODO-75/-114 made the boundary NA warn; the separate instability check in
  `bca_pval_core()` / the BCa CI path (`R/EDI/R/inference_ext_bca_bootstrap_ci.R`) still returns NA with no warning.
  Fix: warn with a classed warning (or reuse `edi_bootstrap_bca_boundary_warning` with a distinct reason field) once per
  object, never inside resampling; suggest `type = "percentile"`; add the warning class to
  `R/package_tests/na_audit_allowlist.csv` as an intentional row; test both CI and p-value.
  Status 2026-11-18 (agent, uncommitted): fixed in `helper_robust_sandwich.R`: `edi_warn_bca_boundary_once()` routes
  `unstable_bias_or_acceleration` reasons to new `edi_warn_bca_unstable_once()`, classed
  `edi_bootstrap_bca_unstable_warning` (fields B, type, reason, what), once per object/type/what, silent in resampling.
  In practice fires when |z0| > 2.5 or z0/a non-finite (|a| <= 1/6 for a real jackknife). Test
  `test-bootstrap-bca-unstable-bias-or-acceleration-warning.R` (24, stubbed draws; no real-data repro found);
  allowlist row added; 15 bootstrap test files pass. Open: the Bayesian BCa CI also gets the generic
  `edi_procedure_na_warning` from `missing_bootstrap_ci()` (double warning, also for the boundary case); roxygen of
  the public BCa methods names only the boundary warning. NEWS line pending.
  Update 2026-11-18 (agent, uncommitted): the Bayesian BCa CI double warning is fixed (`missing_bootstrap_ci(warn =
  FALSE)` after a specific BCa warning; every case warns exactly once; test `test-bootstrap-bca-na-warns-exactly-once.R`,
  47) and the BCa roxygen now names both warnings and the 2/B floor. Close after roxygenize.
  Roxygenized 2026-11-18 (coordinator, `R/fast_roxygenize.R`, 0 warnings; 21 Rd files changed, uncommitted).
- [x] TODO-117 (added 2026-11-18, agent, owner request): **`InferenceSurvivalLogRank` bootstrap draws on *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_survival_log_rank.R:338; R/EDI/R/inference_survival_log_rank.R:283; R/EDI/R/inference_survival_log_rank.R:348; R/EDI/R/inference_survival_gehan_wilcox.R:291; R/EDI/tests/testthat/test-logrank-interval-censored-sign-convention.R:55; R/EDI/NEWS.md:65)*
  interval-censored data have an essentially random sign.** On fixture
  `data_shape__fixed_bernoulli__survival__fixed__equal__interval__no__strong` the estimate is -1.11; the draws' |value|
  centres near 1.08 but 57% are positive (median +0.90). On right-censored data they centre correctly (estimate -1.08,
  draw median -1.05). Gives a percentile p-value of 0.69 under a strong effect, and is what puts LogRank's BCa on the
  boundary. Repro: `fx = build_data_shape_fixture(id)` (from `R/package_tests/public_argument_combination_fixtures.R`),
  `inf = InferenceSurvivalLogRank$new(fx$design)`, `bd = inf$approximate_bootstrap_distribution_beta_hat_T(B = 501)`,
  `mean(bd > 0)`. Likely the resampled interval bounds or the arm labels are not carried with each subject in the
  bootstrap path for interval data. Check the other survival classes' interval-censored bootstrap too.
  Status 2026-11-18 (agent, uncommitted): fixed. Cause: not resampling but `interval::ictest()`'s sign convention: it
  orders arms by first appearance (`unique(group)`), so its estimate and Z are "row-1 arm minus the other". Under
  left/interval censoring the point estimate had the wrong sign whenever subject 1 was a control, and every resample
  that changed row 1 flipped sign. `compute_shared_icen()` (`inference_survival_log_rank.R`) now multiplies by
  `ictest_treatment_minus_control_sign(fit)` (reads `names(fit$U)`). Repro draws now all negative (median -1.07, was
  +0.83). Test `test-logrank-interval-censored-sign-convention.R` (13); the existing ictest comparison test was enforcing
  the bug and now compares against treatment-minus-control mean scores. Changes results for interval-censored LogRank
  where subject 1 is a control (estimate sign, Wald CI, all resampling); regenerate affected matrix/comprehensive rows.
  NEWS line pending. Same bug in Gehan-Wilcoxon is v1.0.6-TODO-121.
- [x] TODO-118 (added 2026-11-18, agent, owner request): **`InferenceIncidKKGEE` under (quasi-)complete separation gives *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_mixin_kk_gee_shared.R:492; R/EDI/R/inference_mixin_kk_gee_shared.R:502; R/EDI/tests/testthat/test-kk-gee-logistic-separation-na-wald.R:23; R/EDI/tests/testthat/test-kk-gee-logistic-separation-na-wald.R:64; R/EDI/R/inference_ordinal_KK_combined.R:296; R/EDI/NEWS.md:72)*
  a confident wrong answer: estimate 44.6 with asymptotic p ~ 0, no warning.** Found by the v1.0.6-TODO-109 agent on a
  `DesignSeqOneByOneKK14` incidence design where all treated subjects have y = 1. The sandwich SE collapses. The fit runs
  through the GEE mixin (`R/EDI/R/inference_mixin_kk_gee_shared.R`), shared with non-logit families. Fix: a
  family-aware separation check (reuse `edi_logistic_n_fitted_extreme()` / `edi_warn_logistic_separation_once()` from
  `helper_robust_sandwich.R`) that warns, and make the asymptotic p-value / CI NA-with-warning (or refuse) rather than
  p ~ 0 when the SE is degenerate; check the other KK GEE logit-link classes.
  Status 2026-11-18 (agent, uncommitted): fixed for `InferenceIncidKKGEE` and `InferencePropKKGEE` (binomial/logit GEE)
  in `inference_mixin_kk_gee_shared.R` `shared_gee_default()`: after the SE is accepted, fitted probabilities at 0/1 ->
  one `edi_logistic_separation_warning` (advice: randomization, exact incidence method, fewer covariates; no LR, GEE has
  none) and `cache_nonestimable_se("kk_gee_logistic_separation")`, so asymp p and CI are NA; estimate unchanged. Repro:
  was estimate 50.48, SE 0.675, p = 0; now p NA. `edi_warn_logistic_separation_once()` gained optional `advice`. Test
  `test-kk-gee-logistic-separation-na-wald.R` (22); 10 related files pass. Not covered: `InferenceOrdinalKKGEE` (own
  ordLORgee dispatch; asymp CI (21.33, 25.80) under separation, no warning) and the jackknife-Wald p (0.376, no warning,
  leave-one-out fits also separated). Poisson KK GEE excluded on purpose (all-zero arm already NA with warnings).
  NEWS line pending.
- [x] TODO-119 (added 2026-11-18, agent, owner request; minor): **`InferenceIncidProbitRegr` gives no warning under *(ticked by the TODO audit 2026-11-18: R/EDI/R/helper_robust_sandwich.R:633; R/EDI/R/helper_robust_sandwich.R:665; R/EDI/R/inference_incidence_probit.R:292; R/EDI/tests/testthat/test-probit-separation-warning.R:41; R/EDI/NEWS.md:212)*
  separation** (estimate 6.85, p = 0.999, on the v1.0.6-TODO-109 fixture
  `data_shape__fixed_blocking__incidence__fixed__equal__none__no__strong`). Fix: extend the v1.0.6-TODO-109 helper to
  the probit link (fitted Phi(Xb) within eps of 0/1) and call it the same way; test.
  Status 2026-11-18 (agent, uncommitted): fixed. Helpers in `helper_robust_sandwich.R` take `link = c("logit",
  "probit")` (default logit; same warning class, new `link` field); `inference_incidence_probit.R` `generate_mod` calls
  it after the full fit. The named fixture no longer reproduces (estimate 3.39, p 1.5e-4: the full probit fit diverges,
  the hardened QR step drops the separated `stratumhigh` covariate silently and refits; existing behaviour, owner's
  call whether to say so); verified on the TODO-109 test fixture (6.79, p 0.999 -> warns once). Test
  `test-probit-separation-warning.R` (21); 9 related files pass. The coordinator also fixed the TODO-109 test, which
  called nonexistent `compute_jackknife_confidence_interval()` inside `tryCatch` (so its jackknife check never ran); now
  `compute_jackknife_wald_confidence_interval()`, 14/14 pass. NEWS line pending.
- [x] TODO-120 (added 2026-11-18, agent; found by the v1.0.6-TODO-107 agent): **KK21stepwise crashes ("missing values *(ticked by the TODO audit 2026-11-18: R/EDI/R/design_seq_one_by_one_KK21.R:270; R/EDI/R/design_seq_one_by_one_KK21.R:276; R/EDI/NEWS.md:207; R/EDI/tests/testthat/test-kk21-stepwise-degenerate-weights-fall-back-to-equal.R:19)*
  and NaN's not allowed" in `quantile()`) with a single varying covariate once responses come in.** Repro (default
  formula): `set.seed(1); X = data.frame(x1 = rnorm(20)); d = DesignSeqOneByOneKK21stepwise$new(response_type =
  "continuous", n = 20, seed = 1L); set.seed(1L); y = rnorm(20); for (i in 1:20) { d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); d$add_one_subject_response(i, y[i]) }`
  fails at i = 8. `kk21_stepwise_continuous_weights_cpp` returns NaN, `na0()` makes it 0, and `assign_wt` in
  `design_seq_one_by_one_KK21.R` normalizes `raw_weights / sum(raw_weights)` = 0/0. Fix: find why the C++ weight is NaN
  with one covariate (needs a targeted compile if C++), and guard the all-zero case in R (fall back to equal weights,
  as KK21 does before enough responses). Seeded allocations may change only on paths that crashed before; verify.
  Status 2026-11-18 (agent, uncommitted): v1.0.6-TODO-120 and -63 fixed together (same cause), R only. The stepwise
  kernel skips a candidate whose residual variance is 0 (exact fit, or constant y), so with one covariate all weights
  are NA -> 0 and `assign_wt` normalized 0/0. `assign_wt` (`design_seq_one_by_one_KK21.R`) now falls back to equal
  weights when the sum is non-finite or <= 0 (what non-stepwise KK21 already gives). 20 single-covariate scenarios:
  continuous, count, proportion, survival and ordinal cases that crashed now run. Allocations unchanged on non-crashing
  paths (72/72 configs identical vs HEAD). Test `test-kk21-stepwise-degenerate-weights-fall-back-to-equal.R` (51); the
  TODO-63 bulk test's skip removed (3/3); 59 KK21/KK golden files pass. Not changed: with several covariates, one that
  predicts y exactly gets weight ~0 in the stepwise kernel (eps in non-stepwise); a C++ change if wanted. NEWS line
  pending.
- [x] TODO-121 (added 2026-11-18, coordinator; found by the v1.0.6-TODO-117 agent): **`InferenceSurvivalGehanWilcox` *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_survival_gehan_wilcox.R:291; R/EDI/tests/testthat/test-logrank-gehan-wilcox-general-censoring.R:94; R/EDI/NEWS.md:65)*
  has the same `interval::ictest()` arm-order sign bug as v1.0.6-TODO-117** (`compute_shared_icen()`,
  `inference_survival_gehan_wilcox.R` ~L252-285, `scores = "wmw"`): on the TODO-117 fixture 50% of bootstrap draws were
  positive (median +0.35) against an estimate of -0.703. Status 2026-11-18 (coordinator, uncommitted): fixed with the
  same two lines (multiply `fit$estimate` and `fit$statistic` by `ictest_treatment_minus_control_sign(fit)`); draws now
  all negative (median -0.683, B = 101); the Gehan `ictest()` comparison test in
  `test-logrank-gehan-wilcox-general-censoring.R` updated to treatment-minus-control (19/19 pass). Changes results like
  TODO-117; NEWS line pending.

### Follow-ups from the TODO-108/-113/-118 fixes (TODO-122..123)

- [x] TODO-122 (added 2026-11-18, owner request): **Separation gaps left by v1.0.6-TODO-118.** (1) *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_ordinal_KK_combined.R:287; R/EDI/tests/testthat/test-kk-gee-separation-ordinal-and-jackknife.R:33; R/EDI/R/inference_all_abstract_jackknife.R:218; R/EDI/R/inference_mixin_kk_gee_shared.R:514; R/EDI/tests/testthat/test-kk-gee-separation-ordinal-and-jackknife.R:63; R/EDI/NEWS.md:76)*
  `InferenceOrdinalKKGEE` uses its own ordLORgee dispatch, so the TODO-118 check never runs: on
  `data_shape__seq_kk21__ordinal__fixed__equal__none__no__strong` (all treated in the top category) its asymptotic
  CI is (21.33, 25.80) with no warning. Add the analogous check (cumulative-logit fitted category probabilities
  numerically 0/1) after its SE is accepted, then `cache_nonestimable_se()` and the separation warning. (2) On a
  separated design, `InferenceIncidKKGEE$compute_jackknife_wald_two_sided_pval()` returns 0.376 with no warning (the
  leave-one-out fits are separated and the warning is silent inside resampling): warn from the jackknife driver when
  the full-data fit is separated, or make it NA-with-warning.
  Status 2026-11-18 (agent, uncommitted): both fixed. (1) `InferenceOrdinalKKGEE` `shared_gee_dispatch()` checks the
  largest |cumulative logit| per subject; separated -> one warning + `cache_nonestimable_se("ordinal_kk_gee_separation")`
  (was CI (21.33, 25.80), p 4e-95). (2) New jackknife-driver hook `jackknife_full_fit_is_separated()` (default FALSE;
  KK GEE override reads a full-fit flag) -> NA with reason `jackknife_full_data_separation` (was p 0.376 with a
  jackknife estimate of -384 vs +50.5). Also fixed: the ordinal GEE refit from a warm start at a diverged solution
  failed silently (`ordinal_kk_gee_fit_unavailable`); now retries cold. Test
  `test-kk-gee-separation-ordinal-and-jackknife.R` (32); ~25 related and bulk files pass. NEWS and ordinal class
  roxygen added by the coordinator.
- [x] TODO-123 (added 2026-11-18, owner request): **Classes that read `private$X` directly may fail on rank-deficient *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract.R:1228; R/EDI/R/inference_continuous_lin.R:309; R/EDI/tests/testthat/test-reused-worker-rank-deficient-draw-rebuilds-covariates.R:118; R/EDI/NEWS.md:106)*
  worker draws.** The v1.0.6-TODO-108 agent found `InferenceContinLin$get_centered_covariates()` read `private$X`,
  which the reusable bootstrap worker sets to NULL on a rank-deficient draw so the matrix is rebuilt; fixed there by
  using `private$get_X()`. About a dozen other classes call `as.matrix(private$X)` (KK OLS / RobustRegr, StratCox,
  ZeroAugmented Poisson, Weibull frailty, ...). Audit every direct `private$X` read in `R/EDI/R/`, reproduce on a
  rank-deficient resample (e.g. `DesignFixedBlocking` with the strata column in `design_formula`, the
  v1.0.6-TODO-108 fixture), switch to `get_X()` where needed, and test.
  Status 2026-11-18 (agent, uncommitted): fixed. Two failure modes: `as.matrix(NULL)` errors (KK OLS/RobustRegr,
  CountKKGLMM, KK Hurdle, KKCondLogitOneLik, OrdinalKKGLMM, SurvivalKKRankRegrIVWC, StratCox: replicate NA) and, worse,
  `if (is.null(private$X))` fallbacks that silently fitted the treatment-only model (LogRegr, Probit, ModifiedPoisson,
  RiskDiff, QuasiPoisson, Beta, the ordinal regressions, OrdinalGComp, Weibull, DepCens, KKCondPoissonOneLik; e.g.
  LogRegr worker 0.619 vs refit 0.647). 57 lines in 30 files now use `private$get_X()`. Full-data and non-deficient
  results byte-identical vs a reverted copy (120 classes); BCa on the strata fixture changes because its jackknife is
  now right. Test `test-reused-worker-rank-deficient-draw-rebuilds-covariates.R` (153; 19 failures + 11 errors on
  the reverted copy); 23 related files pass. NEWS added. New bugs found: v1.0.6-TODO-126..129.
- [x] TODO-124 (added 2026-11-18, agent; found by the v1.0.6-TODO-82 docs agent; minor): **The cached affine-reuse fast *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_rand.R:431; R/EDI/R/inference_all_abstract_rand.R:856; affine-reuse path returns NA below max(10, floor(r/10)) finite draws)*
  path of `compute_rand_two_sided_pval()` (`R/EDI/R/inference_all_abstract_rand.R` ~L420) returns NA only when there are
  zero finite draws**, not below the documented `max(10, floor(r/10))` minimum the other path enforces (~L852). Fix:
  apply the same minimum on both paths; test with a stubbed draw set that has a few finite draws.
  Status 2026-11-18 (agent, uncommitted): fixed; the fast path (~L420) now calls the same helper
  `compute_two_sided_randomization_pval_from_t0s()`, so both enforce the minimum; p-values with enough finite draws
  identical. Test `test-rand-pval-affine-reuse-finite-draw-minimum.R` (48). NEWS added. Neither path warns on this NA
  (it only records `randomization_too_few_finite_estimates`): v1.0.6-TODO-136.
- [x] TODO-125 (added 2026-11-18, agent; found by the v1.0.6-TODO-115 agents; minor): **RMST leftovers.** (1) The *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_survival_rmst.R:135; user tau validation counts exact-event y under general censoring; R/EDI/R/inference_all_abstract_non_param_boot.R:1153; R/EDI/R/helper_robust_sandwich.R:210; R/EDI/vignettes/articles/cluster-and-factorial-experiments.Rmd:119)*
  user-`tau` validation in `InferenceSurvivalRestrictedMeanDiff$initialize()` uses `rmst_arm_max_time()`, which under
  general censoring ignores exact-event `y` values that `turnbull_npmle_stat_diff()` folds in, so it can reject a valid
  `tau` when an arm's largest time is an exact event; use the new default-horizon helper's rule. (2) The bootstrap
  "extreme interval" warning suggests `compute_rand_confidence_interval()`, which RMST refuses; make the suggestion
  class-aware. (3) Note only: with 10 clusters the bootstrap percentile CI rejects ~11% under the null (few-cluster
  anti-conservatism); consider documenting a minimum number of clusters for bootstrap CIs on cluster designs.
  Status 2026-11-18 (agent, uncommitted): all three done. (1) user-tau check uses `rmst_default_horizon()` (repro:
  `tau = 30` was refused against a limit of 9.02; default horizon 34.7). (2) `missing_bootstrap_ci()` suggests the
  randomization CI only if `self$supports("randomization_ci")`; `edi_warn_cluster_independence_once()` lists only
  supported alternatives. (3) cluster article: cluster bootstrap needs about 30+ clusters (Cameron, Gelbach and Miller
  2008 rule of thumb; 11-13% null rejection at 10 clusters here); coordinator also fixed the article's "cluster-aware on
  any inference class" claim. Test `test-rmst-user-tau-validation-and-class-aware-advice.R` (20). NEWS added. Note:
  the article's own example uses 24 schools with a bootstrap interval, just under that threshold.

### Found by the v1.0.6-TODO-123 agent (TODO-126..129)

Fixture for all: `DesignFixedBlocking`, 3 strata, `design_formula = ~ x + s`, leave-one-block-out jackknife. Repro
scripts were in the agent's scratch (`/tmp/claude-1000/t123/pg.R`, `zi.R`), which may be cleared.

- [x] TODO-126 (added 2026-11-18, agent): **Zero-inflated and hurdle count classes give an all-NA leave-one-block-out *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:1126; R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:1146; R/EDI/R/inference_all_abstract_non_param_boot.R:1938; R/EDI/R/inference_all_abstract_non_param_boot.R:1939; R/EDI/tests/testthat/test-zero-augmented-count-rank-deficient...)*
  jackknife with no warning** (`InferenceCountZeroInflatedPoisson`, `ZeroInflatedNegBin`, `HurdlePoisson`). Error
  "NAs are not allowed in subscripted assignments" in `record_zero_augmented_fit_summary`
  (`inference_count_zero_augmented_poisson_abstract.R` ~L293): the cached `best_X_colnames` keeps a collinear stratum
  dummy that the hardened `X_full` dropped. Pre-existing.
  Status 2026-11-18 (agent, uncommitted): two bugs fixed. (1) Worker: `generate_mod()`
  (`inference_count_zero_augmented_poisson_abstract.R` ~L1119/1145) now drops a cached column set not contained in the
  hardened `X_full`/`Xzi_full` and reduces again. (2) Slow path, every draw when `model_formula` isn't `~ .`:
  `bootstrap_subset_inference()` kept the parent's n-row `za_X_cov_all`/`za_Xzi_cov_all` caches, which `cbind()`
  recycled against the subset `w`; now cleared (`inference_all_abstract_non_param_boot.R` ~L1805). Worker = refit on
  every draw (ZIP, ZINB, HurdlePoisson; HurdleNegBin and KK hurdle unaffected). 14 class/fixture combos identical vs a
  reverted copy on normal paths. Test `test-zero-augmented-count-rank-deficient-draw-refits.R` (92). NEWS added.
  Follow-up: v1.0.6-TODO-131.
  Fix 2026-11-18 (coordinator): the za_* reset assigned the fields unconditionally, which fails ("cannot add bindings
  to a locked environment") on a plain R6 subclass; it broke `test-incidence-logit-bootstrap-fast-path.R` and
  `test-incidence-modified-poisson-bootstrap-fast-path.R`. Now assigned only where the field exists; both tests pass.
- [x] TODO-127 (added 2026-11-18, agent): **`InferencePropGCompMeanDiff` leave-one-block-out jackknife is all NA, *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_proportion_gcomp.R:496; leave-one-block-out and leave-one-pair-out jackknives are finite; R/EDI/NEWS.md:286)*
  silently.** Its `load_bootstrap_sample_into_worker` (`inference_proportion_gcomp.R` ~L462) calls
  `as.integer(indices)` on the `list(i_b, m_vec_b)` draw. (This class also tops the v1.0.6-TODO-95 NA list.)
  Status 2026-11-18 (agent, uncommitted): fixed (one line in `inference_proportion_gcomp.R` ~L460: take `indices$i_b`
  for a list draw, as ZOIB does). List draws come from blocked/KK jackknife deletions and every exchangeable-unit
  draw (subsampling, m-out-of-n on every design). Probe of 16 methods x 6 fixtures: only NA -> finite changes. Test
  `test-prop-gcomp-list-shaped-resampling-draws.R` (28). Covers ~90k of the class's 176k comprehensive NA rows. NEWS
  added. Remaining causes: v1.0.6-TODO-134 (studentized SEs); also noted: a 2-unit leave-one-block-out jackknife gives
  a finite but meaningless SE with no warning (generic; v1.0.6-TODO-135).
- [x] TODO-128 (added 2026-11-18, agent): **`InferenceSurvivalKKStratCoxPHIVWC`: the slow-path subset refit returns NA *(ticked by the TODO audit 2026-11-18: R/package_metadata/future_release_plans/release_v1_0_6.md:2207; R/EDI/R/inference_survival_KK_strat_cox.R:19; R/EDI/R/inference_survival_KK_strat_cox.R:241; R/EDI/R/inference_survival_KK_strat_cox.R:336; KK StratCox IVWC: slow-path refit equals the reusable worker on a draw that drops a rare cova...)*
  where the reusable worker returns a finite value** on the same draw. Find which is right and make them agree.
  Status 2026-11-18 (agent, uncommitted): fixed; the slow path was wrong. A covariate constant within every pair is
  unidentified in the per-pair stratified Cox; the C++ fit returned the right coefficient but NaN variance, so the
  SE-requiring slow path dropped the matched half (worker, which uses `estimate_only = TRUE`, kept it). New helper
  `kk_strat_cox_drop_within_strata_aliased_cols()` (`inference_survival_KK_strat_cox.R`) drops such columns as
  `coxph(strata=)` does; both-halves-failed now warns `edi_kk_strat_cox_ivwc_nonestimable_warning`. Matches
  `coxph` (-0.6221271). Full-rank designs identical vs old. Full-data estimate changes on designs where a covariate is
  constant within all pairs (example -1.3917 reservoir-only -> -0.7574). OneLik unaffected. Test
  `test-kk-strat-cox-ivwc-covariate-constant-within-pairs.R` (19). NEWS added. Found: v1.0.6-TODO-132, -133.
- [x] TODO-129 (added 2026-11-18, agent; unverified lead): **Design randomization methods that read the design's own *(ticked by the TODO audit 2026-11-18: R/package_metadata/future_release_plans/release_v1_0_6.md:2229; R/EDI/R/design_seq_one_by_one_atkinson.R:119; R/EDI/R/design_seq_one_by_one_KK21_stepwise.R:217; Atkinson redraw rebuilds a model matrix cleared by the bootstrap worker)*
  `private$X` may ignore covariates on rank-deficient worker draws**, since the worker sets it to NULL and these skip
  covariates when it is NULL (e.g. `design_fixed_greedy.R` ~L173, `design_fixed_rerandomization.R` ~L202,
  `design_seq_one_by_one_KK14.R` ~L222). A randomization-bootstrap re-randomization on such a draw could then be
  covariate-blind. Verify, and use the design's X accessor if so.
  Status 2026-11-18 (agent, uncommitted): real for two designs, fixed. The fixed designs named in the lead are safe
  (`ensure_model_matrix_current()` runs before their reads) and KK14/KK21 redraws permute `m` only. Real:
  `DesignSeqOneByOneAtkinson$draw_ws_raw` passed a NULL X to C++ (28/28 deficient rand-bootstrap draws gave
  `w_b = NULL`), and KK21stepwise's exact-replay path (`condition_on_ws_for_rand_tests = FALSE`) treated every subject
  as too early, giving Bernoulli redraws (imbalance 0.2285 vs 0.1131). Both now call
  `ensure_model_matrix_current()` first; seeded draws identical on normal paths. Test
  `test-design-replay-rebuilds-cleared-model-matrix.R`. NEWS added. Lead for a follow-up (v1.0.6-TODO-130).

### Follow-ups and other findings filed 2026-11-18 (TODO-130..152, TODO-157)

Bugs and leads found while fixing the TODOs above (each entry says which fix found it), plus v1.0.6-TODO-147 from the
docs-claims audit.

- [x] TODO-130 (added 2026-11-18, agent; found by the v1.0.6-TODO-129 agent; investigate): **On full-rank bootstrap *(ticked by the TODO audit 2026-11-18: R/EDI/R/inference_all_abstract_non_param_boot.R:1316; R/EDI/R/inference_all_abstract_non_param_boot.R:1331; R/EDI/R/inference_all_abstract_non_param_boot.R:1465; rank-deficient draw keeps the inference's model-formula columns; R/EDI/R/inference_all_abstract_non_param_boot.R:1939)*
  draws the worker design's `X` is a subset of the inference's `base_X`, which may be the inference's own model
  matrix rather than the design's formula matrix** (see the comment in `design_fixed_optimal_blocks.R` ~L304). So
  covariate-aware redraws on full-rank draws may balance on the inference's columns, while deficient draws (since
  v1.0.6-TODO-129) rebuild from the design formula. Same when the inference uses the design's X (the usual case).
  Check `load_bootstrap_sample_into_design_backed_worker()` (`inference_all_abstract_non_param_boot.R`) and make the
  worker design always use the design's formula matrix for redraws.
  Status 2026-11-18 (agent, uncommitted): real, fixed, plus a second side. `base_X` (the inference's matrix) served
  both the worker design (redraws balanced on `model_formula` columns: greedy imbalance 0.409 vs 0.031 on the slow
  path) and, on deficient draws, the inference fell back to the design's columns (estimate 0.03677 vs 0.03299). Worker
  now also stores `base_des_X` (the design's matrix) only when it differs from `base_X`; when the formulas coincide
  the old path runs unchanged. Fast = slow for all four designs. Test
  `test-bootstrap-worker-design-redraws-on-design-formula.R` (54). NEWS added. The agent saw
  `test-incidence-logit-bootstrap-fast-path.R` (2) and `test-incidence-modified-poisson-bootstrap-fast-path.R` (1)
  failing for an unrelated reason (slow reference returns all-NA draws); recheck after the parallel agents finish.
- [ ] TODO-131 (added 2026-11-18, agent; found by the v1.0.6-TODO-126 agent): **Other n-row private caches may survive
  into `bootstrap_subset_inference()` copies.** The subset refit duplicates the inference object and resets a listed
  set of caches; ZA's `za_X_cov_all` was missing from that list, so R silently recycled the parent's rows against the
  subset (v1.0.6-TODO-126). Audit every private/`cached_values` field holding per-subject data across the Inference
  classes, compare with the reset block in `bootstrap_subset_inference()` (`inference_all_abstract_non_param_boot.R`
  ~L1805), and add a generic guard (e.g. clear or assert-length every cached object whose NROW equals the parent's n).
  Test with a non-`~ .` `model_formula` on the slow path for each family.
  Status 2026-11-18 (agent, uncommitted): fixed. The real recycling was design-side: the subset design copy kept the
  parent's n-row `y_L`/`y_R`/`y_original` (wrong censoring times; "experiment is incomplete" on `duplicate()`; on
  interval data rand-bootstrap slow-path draws all NA for Weibull and LogRank, wrong for KMDiff). Now subset.
  Inference side: a generic guard `clear_parent_row_private_caches()` (`helper_reused_worker_private_cache.R`, keep
  list `EDI_SUBSET_COPY_ROW_FIELDS`) clears every other parent-row private field; the surviving caches were all keyed
  on full data (never reused) except `fit_warm_start_weights` (unkeyed; no numeric effect seen). Slow-path bootstrap,
  rand bootstrap and jackknife bit-identical on 290 class/design combos before vs after. Test
  `test-bootstrap-subset-copy-drops-parent-row-caches.R` (780). NEWS added. Leads: v1.0.6-TODO-142, -143.
- [ ] TODO-132 (added 2026-11-18, agent; found by the v1.0.6-TODO-128 agent; owner decision, changes results):
  **`InferenceSurvivalKKStratCoxPHIVWC`'s `estimate_only = TRUE` is a different estimator.** It weights the matched
  and reservoir halves by sample size, while the full call uses inverse-variance weights. The reusable worker, the
  jackknife and the slow bootstrap path all use `estimate_only = TRUE`, so their replicates are of a different
  estimator than the reported point estimate; the result also depends on call order (after a full fit, `estimate_only`
  returns the cached IVW value). Repro on the TODO-128 rare-covariate KK14 fixture: `compute_estimate()` -0.757 vs a
  fresh `compute_estimate(estimate_only = TRUE)` -4.653. Same class of bug as the 2026-11-07 Stereotype finding
  (estimate_only and full fits were different estimators). Fix: make `estimate_only` compute the same IVW combination
  (needs the halves' variances, so it is not "estimate only" in cost) or document and bootstrap the IVW estimator
  explicitly; check the other KK IVWC classes for the same split.
  Deferred (owner, 2026-11-18): leave for later. Options:
  1. **`estimate_only = TRUE` computes the same inverse-variance-weighted (IVW) combination as the full call**
     (coordinator's recommendation). Bootstrap, jackknife and reusable-worker replicates then estimate the reported
     quantity, and the call-order dependence goes away. Cost: each replicate also computes both halves' variances,
     so resampling is slower for this class. Point estimates unchanged; bootstrap/jackknife results change.
  2. **Report the sample-size-weighted estimator everywhere** (make the full call match `estimate_only`). Keeps
     resampling fast, but changes the reported point estimate and uses a less efficient combination.
  3. **Keep both and document the mismatch.** No code change; the resampling intervals stay for a different
     estimator than the one reported, so this only labels the problem.
  Options 1 and 2 are "Changes that alter results" NEWS entries. Whichever is chosen, check the other KK IVWC
  classes for the same `estimate_only` vs full-call split (the 2026-11-07 Stereotype bug was the same kind).
- [x] TODO-133 (added 2026-11-18, agent; found by the v1.0.6-TODO-128 agent): **`InferenceSurvivalKKStratCoxPHIVWC`'s *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_survival_KK_strat_cox.R:284; R/EDI/R/inference_survival_KK_strat_cox.R:255; R/EDI/R/inference_survival_KK_strat_cox.R:311; R/EDI/tests/testthat/test-kk-strat-cox-ivwc-reservoir-fallback-usability.R; R/EDI/NEWS.md:441)*
  reservoir treatment-only fallback is never checked.** When no candidate reservoir fit is usable, the
  `if (is.null(res))` fallback is accepted without `rcpp_cox_fit_is_usable`, letting unconverged/infinite-coefficient
  fits through (with 1 treated reservoir subject, old slow path gave -21.65; `coxph` warns "coefficient may be
  infinite"). It also uses `y_r`/`dead_r`, undefined when `nRT` or `nRC` is 0 (a `tryCatch` hides the error). Fix:
  apply the usability check and guard the empty-arm case (warn and drop the reservoir half).
  Status 2026-11-18 (agent, uncommitted): fixed. The fallback runs only with both reservoir arms present and is kept
  only if `rcpp_cox_fit_is_usable()`; a dropped two-arm reservoir warns
  `edi_kk_strat_cox_ivwc_reservoir_dropped_warning` on direct calls. An empty arm drops the reservoir silently
  (routine for small KK reservoirs, same as the sibling IVWC classes; to warn, change `nRT > 0L && nRC > 0L` to
  `nRT + nRC > 0L` ~L310). 1,548 fits vs old code: identical wherever the fallback was usable; 297 SE-path fits moved
  by <= 5e-8 (they had mixed in an unusable fallback). Test `test-kk-strat-cox-ivwc-reservoir-fallback-usability.R`
  (20). LWA Cox IVWC never checks `res$converged` (minor). NEWS added. Found: v1.0.6-TODO-139; and on the
  `estimate_only` path `rcpp_cox_fit_is_usable` bounds |beta| only at 1e4 (a beta of -60.9 with vcov 6e14 passes),
  to fold into v1.0.6-TODO-132.
  Decided (owner, 2026-11-18): an empty reservoir arm warns too. Done (coordinator, uncommitted): the warning fires
  whenever a non-empty reservoir is dropped on a direct call (`nRT + nRC > 0`), naming the empty arm or the unusable
  fit; never inside resampling. Two tests updated (empty-arm test now expects the warning; the TODO-128 test muffles
  it where it isn't the subject); both pass with 0 warnings. NEWS line updated.
- [x] TODO-134 (added 2026-11-18, agent; found by the v1.0.6-TODO-127 agent): **`InferencePropGCompMeanDiff` *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_proportion_gcomp.R:1116; R/EDI/R/inference_incidence_gcomp_abstract.R:939; R/EDI/R/helper_gcomp.R:149; R/EDI/R/inference_proportion_gcomp.R:986; R/EDI/R/inference_incidence_gcomp_abstract.R:98; R/package_metadata/future_release_plans/release_v1_0_6.md:2677; R/EDI/tests/testthat/...)*
  studentized bootstrap and Bayesian-bootstrap CIs/p-values are NA on every design** (warned:
  `bootstrap_too_few_finite_standard_errors`, `bayesian_bootstrap_too_few_finite_standard_errors`; ~65k comprehensive
  NA rows). (1) Nonparametric: `bootstrap_replication_stats()` (`inference_all_abstract_non_param_boot.R` ~L1823) reads
  `cached_values$s_beta_hat_T`, but this class stores its SE only in `cached_values$se_md`; mirror it at the end of
  `shared()` as `inference_ordinal_gcomp.R` ~L321 does (check other readers of the key). (2) Bayesian:
  `compute_estimate_with_bootstrap_weights()` computes a point estimate only and never sets `last_weighted_refit`, so
  it needs a weighted sandwich SE. Check the other G-computation classes for the same two gaps.
  Status 2026-11-18 (agent, uncommitted): fixed for PropGCompMeanDiff and IncidGCompRiskDiff/RiskRatio (same two gaps):
  `shared()` full fits set `s_beta_hat_T` (and `beta_hat_T` for prop); weighted refits get a weighted HC0 sandwich
  delta-method SE (`gcomp_weighted_logistic_sandwich_vcov()` in `helper_gcomp.R`; equals the unweighted SE at unit
  weights). Non-studentized results bit-identical across 470 method/type/design probes. Studentized BRT p-values
  change (they silently fell back to percentile before). Coverage check: prop 0.940 (np studentized), 0.933
  (Bayesian), RD 0.950/0.950. Test `test-gcomp-studentized-bootstrap-standard-errors.R` (90). NEWS added. Not fixed
  (different causes): OrdinalGCompMeanDiff Bayesian studentized (needs a weighted proportional-odds sandwich) and its
  `get_standard_error()` erroring; KK g-comp RD/RR Bayesian studentized (needs a weighted KK-pair sandwich):
  v1.0.6-TODO-149. Leads: v1.0.6-TODO-150, -151.
- [x] TODO-135 (added 2026-11-18, agent; found by the v1.0.6-TODO-127 agent): **A jackknife with very few deletion *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_jackknife.R:287; R/EDI/R/inference_all_abstract_jackknife.R:235; R/EDI/R/inference_all_abstract_non_param_boot.R:2390; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:868; R/EDI/vignettes/articles/analyzing-an-existing-experiment.Rmd:152; R/EDI/tests/testthat/te...)*
  units returns a finite but meaningless SE with no warning.** With 2 strata, leave-one-block-out gives SE 0.0176
  against a Wald SE of 0.0316 (p ~ 4.6e-16). Add a minimum-units guard to the generic jackknife driver
  (`inference_all_abstract_jackknife.R`): NA with an `edi_procedure_na_warning` (or a warning and the value) below a
  threshold, with the threshold justified (e.g. fewer than ~5 units).
  Status 2026-11-18 (agent, uncommitted): fixed. `EDI_JACKKNIFE_MIN_DELETION_UNITS = 5L` in
  `inference_all_abstract_jackknife.R`; below it the summary is NA with reason `jackknife_too_few_deletion_units`
  (replicates kept). NA rather than value+warning because the driver uses a normal reference (coverage 70/81/86% at
  G = 2/3/4 even in the ideal case). Identical results for G >= 5. BCa deliberately not gated (uses replicates
  directly; with 2 the acceleration is 0, so bias-corrected percentile) — owner to confirm. Side effect: KK OneLik
  count no longer jackknife-inflates its SE with < 5 units. Test `test-jackknife-too-few-deletion-units-na-warns.R`;
  3 tests and 3 bulk tests updated deliberately. Cluster article prose updated by the coordinator. NEWS added.
  Pre-existing failures seen: `test-bayesian-bootstrap-jackknife-bca-and-weight-helpers-reference.R` (textbook BCa
  references) and `test-inference-class-registry.R` (method-owner baseline, likely the new private methods from this
  session's fixes). Sibling gap: v1.0.6-TODO-137.
  Decided (owner, 2026-11-18): BCa is also blocked below 5 units. Done (agent, uncommitted): new
  `edi_bca_jackknife_gate_reason()` gates plain and Bayesian BCa CI/p-value (reason
  `..._jackknife_too_few_deletion_units`, one warning per NA); 5+ units byte-identical (snapshot over blocking G = 2..8
  and cluster designs). Two tests updated deliberately (TODO-108 fix still tested with the minimum lowered). Article
  `analyzing-an-existing-experiment.Rmd` (4 sites) switched to `type = "percentile"` with a sentence on why. Side
  effects: a 4-cluster `DesignFixedCluster` BCa was a silent `NA NA` before (now warned; whether 5+ clusters can still
  give a silent NA is untested); small KK designs with < 5 matched sets now get NA BCa. Found while rendering:
  v1.0.6-TODO-161. NEWS added. Roxygen updated (comment lines).
- [x] TODO-136 (added 2026-11-18, coordinator; found by the v1.0.6-TODO-124 agent): **A randomization p-value that is NA *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_rand.R:848; R/EDI/R/inference_all_abstract_rand.R:49; R/EDI/tests/testthat/test-rand-and-bootstrap-pval-silent-na-warns.R; R/EDI/NEWS.md:520)*
  because too few draws are finite does not warn**; `compute_two_sided_randomization_pval_from_t0s()`
  (`inference_all_abstract_rand.R` ~L846) only records `randomization_too_few_finite_estimates`. Warn via
  `edi_warn_procedure_na()` from that one shared helper, but make sure it does not fire repeatedly inside the
  randomization CI search (which calls the p-value many times; check whether `active_resampling_operation` is set
  there) — warn once per user-facing call.

  Status 2026-11-18 (agent, resumed, uncommitted): v1.0.6-TODO-136 and -145 fixed together. Every listed silent-NA
  p-value return warns once (`edi_warn_procedure_na()`, silent in resampling); values and reasons unchanged. The rand
  CI search does not set `active_resampling_operation`, so new `edi_muffle_rand_pval_na_warnings()` drops only the
  per-delta rand / rand-bootstrap p-value NA warnings inside the CI searches (13 warnings -> 1), and the rand CI warns
  once itself when it ends NA (search-bounds / bisection failure). Test `test-rand-and-bootstrap-pval-silent-na-warns.R`
  (43); 47 rand/bootstrap/Bayesian files pass; NA-gate smoke passes. NEWS added. Left: v1.0.6-TODO-165, -166.
- [x] TODO-137 (added 2026-11-18, agent; found by the v1.0.6-TODO-135 agent): **The g-computation risk-ratio jackknife *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_jackknife.R:352; R/EDI/R/inference_incidence_gcomp_abstract.R:383; R/EDI/R/inference_incidence_KK_gcomp_abstract.R:345; R/EDI/tests/testthat/test-gcomp-risk-ratio-jackknife-shared-guards-warn.R; R/EDI/NEWS.md:222)*
  path bypasses the jackknife guards.** `inference_incidence_gcomp_abstract.R` and
  `inference_incidence_KK_gcomp_abstract.R` build their own log-scale SE from the replicates, rejecting only
  `n_units <= 1`, so they skip the v1.0.6-TODO-135 minimum-units guard and return NA without a warning on several
  paths. Route them through the shared summary/guards (or apply the same checks) and warn via
  `edi_warn_jackknife_na()`.

  Status 2026-11-18 (agent, resumed, uncommitted): fixed. Shared helpers `edi_rr_jackknife_log_summary()`,
  `edi_rr_jackknife_wald_two_sided_pval()`, `edi_rr_jackknife_wald_confidence_interval()`
  (`inference_all_abstract_jackknife.R`) apply the `compute_jackknife_summary()` guards in the same order (block size,
  original RR, separation, >= 2 replicates, >= 5 units, finite, > 0 [new reason
  `jackknife_nonpositive_risk_ratio_replicates`], extreme, zero spread, extreme summary); every NA warns. Both g-comp
  classes' three private methods now delegate (removes most of duplication pair #1 for these methods). Changes: RR with
  < 5 units, non-finite/zero replicates (were silently dropped), and three KK 6-pair cases with 1e-13..1e14 CIs now NA
  with a reason; 57 of 60 snapshot cases with 5+ units byte-identical. Test
  `test-gcomp-risk-ratio-jackknife-shared-guards-warn.R` (92); 51 files pass; two bulk tests updated deliberately. NEWS
  under "Changes that alter results".
- [x] TODO-138 (added 2026-11-18, owner request; found by the v1.0.6-TODO-119 agent): **When separation forces a *(ticked by the TODO audit 2026-11-19: R/EDI/R/helper_robust_sandwich.R:726; R/EDI/R/inference_all_abstract.R:1394; R/EDI/R/inference_proportion_gcomp.R:1101; R/EDI/R/helper_robust_sandwich.R:774; R/EDI/R/helper_robust_sandwich.R:728; R/EDI/tests/testthat/test-covariate-dropped-warning.R; R/EDI/R/inference_incidence_probit.R:343; R/ED...)*
  hardened refit, `InferenceIncidProbitRegr` silently drops the separated covariate; it must warn.** On
  `data_shape__fixed_blocking__incidence__fixed__equal__none__no__strong` the full probit fit diverges (`glm` probit:
  w = 11.9, stratumhigh = -8.3), coefficients above `max_abs_reasonable_coef = 10` make the hardened QR step drop
  `stratumhigh` and refit, and the reduced fit is reported (estimate 3.39, p 1.5e-4) with no message. Decided (owner,
  2026-11-18): warn, naming the dropped column(s) and why. Check every class sharing that harden-and-refit step (logit,
  g-computation, other GLM families) and warn there too; once per object, never inside resampling.
  Status 2026-11-18 (agent, uncommitted): done. All drops go through `fit_with_hardened_qr_column_dropping()` (37
  class files) plus the incidence/proportion g-comp loops; a drop beyond the QR rank set (fit unusable or a
  coefficient diverged) now raises `edi_covariate_dropped_warning` once per object, silent in resampling; pure
  collinearity drops stay silent. 0 of 130 class x fixture estimates/p-values changed. Test
  `test-covariate-dropped-warning.R` (34); 133 related files pass (one bulk test updated to expect the warning).
  Roxygen "Dropped covariates" paragraph added to probit, log-binomial, binomial-identity. NEWS added.

- [ ] TODO-139 (added 2026-11-18, agent; found by the v1.0.6-TODO-133 agent): **The C++ stratified Cox fit with zero
  events reports `converged = TRUE` at a nonzero coefficient.** Repro: KK14 survival design, seed 2, n = 40, every
  matched subject censored (`y_L = 5 + i/100, y_R = Inf`): `fast_stratified_coxph_regression_cpp(..., estimate_only =
  TRUE)` returns coef (-1.64, -0.10) with `converged = TRUE` (looks like a leftover start value), so
  `InferenceSurvivalKKStratCoxPHIVWC$compute_estimate(estimate_only = TRUE)` returns -1.642 while the SE path returns
  NA. Fix: in `R/EDI/src` (zero events -> not converged; needs the owner's targeted compile) and/or an R-side
  zero-events guard on the matched half.
- [x] TODO-140 (added 2026-11-18, agent; found by the v1.0.6-TODO-90 agent): **The studentized bootstrap p-value is a *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_non_param_boot.R:773; R/EDI/R/inference_all_abstract_non_param_boot.R:819; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:361; studentized bootstrap p-value warns when SEs are missing (KMDiff, RestrictedMeanDiff); R/EDI/NEWS.md:473)*
  silent NA when standard errors are missing.** In `compute_bootstrap_two_sided_pval()`
  (`inference_all_abstract_non_param_boot.R` ~L752-756) the too-few-usable-draws branch only records
  `bootstrap_too_few_finite_standard_errors`; the CI path warns. Seen on KMDiff and RestrictedMeanDiff with interval
  censoring (`type = "studentized"`). Warn via `edi_warn_procedure_na()` like the CI.
  Status 2026-11-18 (agent, uncommitted): fixed; the actual silent return was the "original SE unavailable" branch.
  Warns at every studentized NA return (and the Bayesian-bootstrap studentized p-value), values unchanged. Test
  `test-bootstrap-studentized-pval-missing-se-warns.R` (20). NEWS added. Still silent (out of scope): non-studentized
  `bootstrap_too_few_finite_estimates` (na.rm = TRUE), `bootstrap_extreme_finite_estimates`,
  `bootstrap_pvalue_unavailable`, and the Bayesian `..._extreme_finite_estimates` / `..._too_few_finite_estimates`
  p-value returns: v1.0.6-TODO-145.

- [x] TODO-141 (added 2026-11-18, agent; found by the v1.0.6-TODO-90 agent): **Bayesian bootstrap under general *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:13; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:108; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:3; R/EDI/R/inference_survival_rmst.R:57; R/EDI/R/inference_survival_log_rank.R:14; R/EDI/R/inference_survival_gehan_wilcox.R:21; R/E...)*
  censoring fails inside every draw for RestrictedMeanDiff, GehanWilcox, LogRank and Weibull** (their interval-
  censored fits take no weights), returning NA with `edi_bootstrap_nonfinite_na_warning`: warned but misleading.
  Refuse up front with a clear "not supported under left/interval censoring" error, as KMDiff now does
  (v1.0.6-TODO-90), and fix KMDiff's inherited Bayesian-bootstrap CI reason
  (`bayesian_bootstrap_too_few_finite_estimates`) the same way. Add the restriction to the roxygen of these classes.
  Status 2026-11-18 (agent, uncommitted): done. One plain function
  `edi_stop_if_bayesian_bootstrap_under_general_censoring()` (`inference_all_abstract_bayesian_bootstrap.R`) called
  after the existing `supports_bayesian_bootstrap()` check in the three public entry points (not a private method or
  override, which breaks lazy component loading); blanket guard because exactly these five classes accept general
  censoring and none has weighted interval-censored fits. Right-censored results identical. Roxygen comment lines
  updated (not yet roxygenized). Test `test-survival-bayesian-bootstrap-general-censoring-refused.R`; KMDiff fallback
  test updated. NEWS added. Coordinator also fixed two stale bulk references this session's fixes had left behind:
  `test-survival-logrank-gehan-interval-censored-compute-shared-icen-vs-ictest-reference.R` (now treatment minus
  control, v1.0.6-TODO-117/-121; 25 pass) and `test-bayesian-bootstrap-jackknife-bca-and-weight-helpers-reference.R`
  (now the 2/B floor, v1.0.6-TODO-75; 24 pass).
- [ ] TODO-142 (added 2026-11-18, agent; found by the v1.0.6-TODO-131 agent): **Bootstrap subset copies made outside an
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
- [x] TODO-143 (added 2026-11-18, agent; unverified lead from the v1.0.6-TODO-131 agent): **In the slow *(ticked by the TODO audit 2026-11-19: R/package_metadata/future_release_plans/release_v1_0_6.md:2596; R/EDI/R/inference_all_abstract_rand_bootstrap.R:1224; R/EDI/R/inference_all_abstract_rand_bootstrap.R:885; R/EDI/R/contracts_mixins.R:452; R/EDI/R/inference_all_abstract_rand.R:1114; R/EDI/tests/testthat/test-rand-bootstrap-shifts-ce...)*
  randomization-bootstrap path with general censoring and `delta != 0`, `y_L`/`y_R` may not be shifted along with
  `y_sim`.** Verify, and shift the bounds consistently if so.
  Status 2026-11-18 (agent, uncommitted): real, in both the worker and the slow path (and the studentized path). The
  plain rand test/CI refuse nonzero delta under general censoring, but the bootstrap randomization test did not, and
  its three loaders skipped the y_L/y_R rebuild, so the bounds stayed at their observed values (all-interval Weibull:
  null mean -0.0469 at delta = -1, 0, 1). New private `rand_bootstrap_null_censoring_bounds()`
  (`inference_all_abstract_rand_bootstrap.R`, registered in `contracts_mixins.R`) applies the same shift as `y`
  (multiplicative for survival under the "log" mapping; 0 and Inf bounds unchanged). delta = 0 and exact/right-censored
  paths unchanged; worker = slow at delta = 0.7 for 6 survival classes. Test
  `test-rand-bootstrap-shifts-censoring-bounds-under-null.R` (17). NEWS added. Owner decision open: allow the plain
  rand test/CI at nonzero delta under general censoring with the same bounds shift. Unchecked: under smoothed BRT the
  noise is added to y but not to y_L/y_R.
  Follow-up 2026-11-18 (owner decision, agent, uncommitted): the plain randomization test and CI now accept nonzero
  delta under general censoring. New private `randomization_null_censoring_bounds()` (`inference_all_abstract_rand.R`;
  the TODO-143 bootstrap helper now delegates to it); refusals removed in `setup_randomization_template_and_shifts()`,
  `inference_all_abstract_rand_ci.R` and Weibull's own `compute_rand_two_sided_pval`; the worker resets bounds on every
  draw so a worker reused across a CI search holds no stale bounds. delta = 0 and exact/right-censored results
  identical (36 p-values + a Weibull CI). Simulation (n = 40, ~85% interval-censored, true log ratio 0.5): rejection
  at 0.05 of 0.054 for Weibull and LogRank (exact-data baseline 0.054 / 0.046); Weibull rand CI (alpha 0.10) covered
  85.5% vs 90% (about 1.3 SE low; one NA bound in 70 not chased). Rand CI newly available for Weibull only (the
  other five refuse it for unrelated reasons). Test `test-rand-test-and-ci-shift-censoring-bounds-under-null.R` (34);
  one testthat and two bulk tests updated deliberately; article paragraph in `censored-survival-outcomes.Rmd`. NEWS
  under "New features".
- [x] TODO-144 (added 2026-11-18, agent; found by the KMDiff article agent): **On interval-censored data, *(ticked by the TODO audit 2026-11-19: R/EDI/R/helper_inference_survival_turnbull.R:115; R/EDI/R/inference_survival_km_diff.R:550; R/EDI/R/inference_survival_km_diff.R:376; interval-censored KMDiff jackknife NA gives the median-specific warning; interval-censored KMDiff warns from the Turnbull NPMLE when a median is not reached; R/EDI...)*
  `InferenceSurvivalKMDiff` returns an NA estimate with no warning when a Turnbull median is not reached.**
  `shared()`'s general-censoring branch (`inference_survival_km_diff.R` ~L421-435) returns before
  `warn_km_median_not_reached_once()` (~L445), and that helper reads `private$y` (all NA under interval censoring), so
  it needs a Turnbull-based version. Repro: the censoring article's interval data cut at month 9 (`y_Ls =
  ifelse(y_R > 9, 9, y_L), y_Rs = ifelse(y_R > 9, Inf, y_R)`), `InferenceSurvivalKMDiff$new(des_9)$compute_estimate()`.
  Also: on interval data the KMDiff jackknife-Wald NA gives the generic `edi_procedure_na_warning` rather than the
  median-specific `edi_km_jackknife_na_warning`.
  Status 2026-11-18 (agent, uncommitted): fixed. New `turnbull_npmle_group_lowest_survival()`
  (`helper_inference_survival_turnbull.R`); the general-censoring branch warns when a Turnbull median is not reached
  (arm, lowest survival, RMST suggestion), once per object, silent in resampling; median-specific jackknife reasons.
  Values unchanged. Test `test-km-diff-interval-censored-median-not-reached-warns.R` (28). NEWS added. Roxygen
  sentence on the jackknife methods needs updating.
- [x] TODO-145 (added 2026-11-18, agent; found by the v1.0.6-TODO-140 agent): **Remaining silent-NA returns in the *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_non_param_boot.R:774; R/EDI/R/inference_all_abstract_non_param_boot.R:781; R/EDI/R/inference_all_abstract_non_param_boot.R:794; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:412; R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:419; the p-value helper is si...)*
  bootstrap p-values:** non-studentized `bootstrap_too_few_finite_estimates` (with `na.rm = TRUE`),
  `bootstrap_extreme_finite_estimates`, `bootstrap_pvalue_unavailable`, and the Bayesian p-value's
  `bayesian_bootstrap_extreme_finite_estimates` / `bayesian_bootstrap_too_few_finite_estimates`. Warn via
  `edi_warn_procedure_na()` as v1.0.6-TODO-140 did, once per call, silent in resampling.

  Status 2026-11-18 (agent, resumed, uncommitted): v1.0.6-TODO-136 and -145 fixed together. Every listed silent-NA
  p-value return warns once (`edi_warn_procedure_na()`, silent in resampling); values and reasons unchanged. The rand
  CI search does not set `active_resampling_operation`, so new `edi_muffle_rand_pval_na_warnings()` drops only the
  per-delta rand / rand-bootstrap p-value NA warnings inside the CI searches (13 warnings -> 1), and the rand CI warns
  once itself when it ends NA (search-bounds / bisection failure). Test `test-rand-and-bootstrap-pval-silent-na-warns.R`
  (43); 47 rand/bootstrap/Bayesian files pass; NA-gate smoke passes. NEWS added. Left: v1.0.6-TODO-165, -166.
- [x] TODO-146 (added 2026-11-18, owner request; unverified lead from the v1.0.6-TODO-143 agent): **Smoothed bootstrap *(ticked by the TODO audit 2026-11-19: R/package_metadata/future_release_plans/release_v1_0_6.md:2645; R/EDI/R/inference_all_abstract_rand_bootstrap.R:12; R/EDI/R/inference_all_abstract_rand_bootstrap.R:23; smoothed BRT p-value and CI are refused under left/interval censoring; R/EDI/NEWS.md:188)*
  randomization test under left/interval censoring: the smoothing noise is added to `y` but not to `y_L`/`y_R`.**
  First check whether smoothing can run under general censoring at all; if it can, decide how bounds should move
  (consistently with `y`, or refuse smoothing under general censoring) and fix; if it can't, record the evidence.
  Status 2026-11-18 (agent, uncommitted): real (nothing gated smoothing on censoring; Weibull, LogRank, KMDiff, RMST,
  CoxPH all ran it; noise vanished on censored rows, bandwidth from exact times only, 1.0 raw units with none).
  Decided to refuse rather than jitter bounds: no published smoothed bootstrap for interval-censored data (the
  Turnbull NPMLE is not unique within innermost intervals), additive jitter breaks the 0 lower bound, multiplicative
  jitter would be an invented estimator. `rand_bootstrap_smoothing_supported()` now returns FALSE under general
  censoring (covers p-value, CI, type listings, pre-noised draws). Right-censored and continuous results identical.
  Test `test-rand-bootstrap-smoothing-refused-under-general-censoring.R` (60). Roxygen sentence and NEWS added by the
  coordinator. Found: v1.0.6-TODO-148.

- [ ] TODO-147 (added 2026-11-18, agent, owner decision; from the docs-claims audit): **`InferenceIncidExactZhang`'s
  point estimate ignores the matched pairs on KK designs.** `compute_estimate()`
  (`R/EDI/R/inference_incidence_exact_zhang.R` ~L24) is `zhang_incid_treatment_estimate()`
  (`R/EDI/R/inference_helpers_zhang.R` ~L96): the Haldane-Anscombe log odds ratio of `n11`, `n10`, `n01`, `n00`.
  With a match structure, `zhang_get_exact_stats()` fills those from `compute_zhang_match_data_cpp()`, which counts
  the reservoir only, so the estimate is always 0 when every subject is matched. The docs
  (`inference_incidence_exact_zhang.R` ~L120, `man-roxygen/exact-zhang-compute-estimate.R`) say it uses the pooled
  2x2 table across all subjects. Owner decision (2026-11-18): the estimate must use all subjects, as documented.
  Build the pooled table (each matched subject's own treatment and outcome, plus the reservoir) and use it in
  `compute_estimate()`; check whether `zhang_incid_mle_ci()` (the CI search bracket) and
  `zhang_ci_inside_point()` (`est_R`) should use the pooled or the reservoir table, since the exact p-value still
  combines the matched and reservoir parts separately. Test: on a KK design with every subject matched the estimate is
  not identically 0 and equals the pooled-table formula; with no matching it is unchanged. Add a NEWS entry under
  "Changes that alter results". (audit decision `docs-claims-d42892ef3`)

- [ ] TODO-148 (added 2026-11-18, agent; found by the v1.0.6-TODO-146 agent): **`InferenceSurvivalWeibullRegr` smoothed
  bootstrap randomization test on plain right-censored data returns NA** (30 of 31 null draws NA at delta = 0 and
  0.3): the smoothing noise is additive on raw time, so `y + noise` goes negative (min -0.40). Repro: n = 40 Bernoulli,
  `t = rexp(n)`, `dead = rbinom(n, 1, .7)`, `ys = ifelse(dead == 1, t, NA)`, `y_Ls = ifelse(dead == 1, NA, t)`,
  `y_Rs = ifelse(dead == 1, NA, Inf)`; `set.seed(9); InferenceSurvivalWeibullRegr$new(des)$compute_rand_bootstrap_two_sided_pval(B = 31, transform_responses = "log", type = "smoothed")`.
  Likely fix: log-scale noise for survival (also in the C++ kernels' noise_mat handling, so a targeted compile); check
  the other survival classes' smoothed BRT on right-censored data too.

- [x] TODO-149 (added 2026-11-18, agent; found by the v1.0.6-TODO-134 agent): **Remaining G-computation studentized *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_ordinal_gcomp.R:444; R/EDI/R/inference_ordinal_gcomp.R:124; R/package_metadata/future_release_plans/release_v1_0_6.md:2694; R/EDI/R/helper_gcomp.R:194; R/EDI/R/inference_incidence_KK_gcomp_abstract.R:528; R/EDI/R/inference_incidence_KK_gcomp_abstract.R:858; R/EDI/tests/testthat/...)*
  gaps.** (1) `InferenceOrdinalGCompMeanDiff`: the Bayesian studentized bootstrap is NA because
  `compute_estimate_with_bootstrap_weights()` has no weighted SE (needs a weighted proportional-odds sandwich); also its
  `get_standard_error()` errors with "attempt to apply non-function". (2) `InferenceIncidKKGCompRiskDiff`/`RiskRatio`:
  the Bayesian studentized path is NA (`compute_weighted_gcomp_estimate` sets `s_beta_hat_T = NA`, a full fit never
  sets it); needs a weighted KK-pair cluster sandwich.

  Status 2026-11-18 (agent, resumed, uncommitted): both parts fixed. Ordinal: weighted refit had no SE, and its own
  `on.exit` restored the unweighted cache before the isolation wrapper's snapshot; now a weighted delta-method SE
  (weighted inverse observed information) set on top of the restored cache. KK RD/RR: new
  `gcomp_weighted_logistic_cluster_sandwich_vcov()` (`helper_gcomp.R`; sqrt(w) in the cluster scores so a pair drawn k
  times counts k times); `shared()` full fits now set `s_beta_hat_T` (also un-NAs the nonparametric studentized
  bootstrap). Unit-weight SEs equal the unweighted SEs; 90 non-studentized probes identical. Coverage (Bayesian
  studentized, 100 reps): KK RD 0.95, KK RR 0.90 (about 2 MC SEs low, not investigated), ordinal 0.95. Test
  `test-gcomp-ordinal-and-kk-weighted-refit-standard-errors.R` (37). NEWS added. The ordinal class's
  `get_standard_error()` "error" is not a bug: it is private there (the class composes `Wald`); owner decision to keep
  it private (agent's recommendation) or drop `Wald` to match the sibling classes.
  Decided (owner, 2026-11-18): keep `InferenceOrdinalGCompMeanDiff`'s `get_standard_error()` private (it composes
  `Wald`); no change.
- [x] TODO-150 (added 2026-11-18, agent; lead from the v1.0.6-TODO-134 agent): **`InferencePropGCompMeanDiff` *(ticked by the TODO audit 2026-11-19: R/package_metadata/future_release_plans/release_v1_0_6.md:2700; R/EDI/R/inference_proportion_gcomp.R:527; R/EDI/tests/testthat/test-prop-gcomp-rand-bootstrap-null-uses-fresh-assignment.R:22; R/EDI/NEWS.md:224)*
  bootstrap randomization (BRT) percentile p-values look wrong:** 0.78-0.90 at z ~ 3.2 where the randomization test
  gives p = 0.02 (incidence RD in the same setting gives 0.039). Predates TODO-134. Investigate.

  Status 2026-11-18 (agent, resumed, uncommitted): fixed; a real bug, not scale or centring. The reused worker's
  `compute_bootstrap_worker_estimate` fit a snapshot of the observed `w[i_b]`/`y[i_b]`, ignoring the fresh assignment
  and sharp-null `y` the BRT loader installs, so the "null" draws were bootstrap replicates centred at the estimate
  (p 0.945 vs rand 0.010). Now fits the worker's live `w`/`y` (`inference_proportion_gcomp.R`); worker = slow path
  draw for draw at delta 0 and 0.3; null size 5.7% at 0.05 (300 sets); strong effect rejected 100%. Plain bootstrap
  and jackknife unchanged. Test `test-prop-gcomp-rand-bootstrap-null-uses-fresh-assignment.R`. NEWS under "Changes that
  alter results". Comprehensive rows for this class's BRT p-values/CIs are stale. Same bug in ZOIB: v1.0.6-TODO-167.
- [x] TODO-151 (added 2026-11-18, agent; lead from the v1.0.6-TODO-134 agent; minor): **The risk-ratio classes' *(ticked by the TODO audit 2026-11-19: R/package_metadata/future_release_plans/release_v1_0_6.md:2712; R/EDI/R/inference_all_abstract_rand_bootstrap.R:595; R/EDI/R/inference_all_abstract_rand_bootstrap.R:527; R/EDI/tests/testthat/test-risk-ratio-rand-bootstrap-null-centering.R:39; R/EDI/R/inference_all_abstract_rand_bootstrap.R:419; R...)*
  `compute_rand_bootstrap_two_sided_pval()` defaults to `delta = 0`, which means "RR = exp(0)?" only if delta is on the
  log scale.** Check the scale the RR classes shift on and make the default null correspond to RR = 1 (document it).
  HALTED 2026-11-18 (agent stopped by the weekly usage limit, resets 2026-11-20 05:00 Asia/Jerusalem; partial
  edits are in the working tree; resume that agent rather than starting over).
  Status 2026-11-19 (agent + coordinator, uncommitted): only the studentized / symmetric-percentile-t BRT was wrong
  (pivot centered at 0 for the raw-RR classes). Every other path already defaulted to 1 (via
  `default_null_value()`) or works on log RR / a response shift where 0 is the sharp null (docs clarified). Fixed in
  `compute_rand_bootstrap_two_sided_pval()`: center at `default_null_value()` when `delta == 0`; nonzero `delta` on
  incidence now errors. Null simulation (GCompRR, n = 80, 400 datasets): rejection at 0.05 went 0.000 -> 0.055.
  Coordinator also fixed a regression from v1.0.6-TODO-149's edit: KK g-comp `shared()` cached `s_beta_hat_T` but not
  `beta_hat_T`, so the KK studentized BRT returned NA; now finite for KK RR and RD. Test
  `test-risk-ratio-rand-bootstrap-null-centering.R` (16 pass, KK finiteness now asserted); g-comp studentized, KK
  migration golden, warm-start and KK reference tests pass. Roxygen edited, not roxygenized. Lead not investigated:
  `mann_whitney_effect` estimands (no-effect value 0.5) may have the same mis-centering.
- [ ] TODO-152 (added 2026-11-18, owner decision: keep for v1.0.6; split out of v1.0.6-TODO-142): **ZIP fits under
  separation in the zero-inflation part.** On the v1.0.6-TODO-142 bootstrap draw the zero-part coefficients diverge
  (the likelihood's supremum is at infinity; count_w tends to -0.147, pscl agrees, nll 77.069), the warm start stops
  at count_w -0.188 (nll 78.40) and the cold start at a genuine interior local maximum, count_w 0.163 (nll 82.56,
  gradient 7.7e-9); in 150 random full-data fits only such separation cases were off. Options: (a) an LBFGS candidate
  from pscl's start, keeping the lower nll (cheap; the multi-candidate pattern used elsewhere); (b) detect separation
  in the zero part and warn / mark the zero-part estimate nonestimable; (c) both. Respect the 2026-11-16 rule that
  replicates chain warm starts only when `likelihood_concave` is TRUE, and the ZIP ridge note in that learning. Repro
  scripts were in the TODO-142 agent's scratch (`zipstarts2.R`, `zipsweep.R`), which may be cleared.

- [x] TODO-157 (added 2026-11-18, owner decision; from v1.0.6-TODO-113): **Measure the bootstrap "extreme interval" *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_non_param_boot.R:1264; R/EDI/R/inference_all_abstract_non_param_boot.R:1319; R/EDI/R/inference_all_abstract_non_param_boot.R:1270; PropOddsRegr on the 10-cluster fixture: the wide log-OR percentile interval is no longer rejected; R/EDI/tests/testthat/test-bootstrap-...)*
  cutoff on each estimand's own scale.** `bootstrap_confidence_interval_extreme()` in
  `R/EDI/R/inference_all_abstract_non_param_boot.R` rejects an interval wider than
  `bootstrap_extreme_ci_width_threshold = 5` times `bootstrap_outcome_scale()`, i.e. in outcome-SD units, but the check
  is also applied to coefficients on other scales (log-odds, log rate ratios, log hazard ratios). Example: a 5.6-wide
  log-odds-ratio interval from 10 clusters (`InferenceOrdinalPropOddsRegr` on `DesignFixedCluster`, fixture
  `data_shape__fixed_cluster__ordinal__fixed__equal__none__no__null`) is rejected as extreme though plausibly real.
  Proposed: scale the cap by the estimator's own spread (bootstrap replicate SD, or the asymptotic SE when available)
  instead of the outcome SD, so "extreme" means implausibly wide relative to the sampling variability, which is
  scale-free; keep the outcome scale only where still needed. Show before and after on: the 10-cluster log-OR case; a
  logistic and a Poisson class; the interval-censored RMST/KMDiff cases (v1.0.6-TODO-90/-91; must stay finite); and a
  genuinely degenerate case the check exists to catch (find its origin and the tests that pin it; it must still be
  rejected). Results that were not rejected must be identical. An agent started on this 2026-11-18.
  Status 2026-11-18 (agent, uncommitted): done. Neither spread alone works (the asymptotic SE explodes under
  separation; the replicate SD is inflated by a mixture; the MAD fails when most replicates are separated), so for
  link-scale estimands (by `EDI_INFERENCE_ESTIMAND_TAGS`) an interval over the old cap is kept only if width <= 10 x
  the replicates' MAD and both bounds are within +/-10. Runs only when the old rule already rejected, so previously
  accepted intervals are identical by construction. PropOdds 10-cluster fixture: NA -> [-3.10, 2.58]; logit/Poisson
  regular, RMST and KMDiff interval-censored identical; all separation variants still rejected. New private members
  registered in `contracts_mixins.R`. Test `test-bootstrap-extreme-ci-cap-on-estimand-scale.R` (24); one test
  deliberately updated; 54 bootstrap files pass. NEWS added (under "Changes that alter results"). Gaps: v1.0.6-TODO-160.

### Divergent near-clones from the code-duplication audit (TODO-153..156)

Found 2026-11-18 by the first local run of the code-duplication audit (`.github/scripts/audits/code_duplication.py`),
which ranks near-identical code whose copies differ in a few lines. Suspects only: none confirmed with a repro yet.

- [x] TODO-153 (added 2026-11-18, owner request): **`InferenceCountZeroInflatedPoisson` does not accept *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_count_zero_inflated.R:136; R/EDI/R/inference_count_zero_inflated.R:358; R/EDI/tests/testthat/test-zero-inflated-smart-cold-start-and-risk-diff-nonestimable-reason.R:28; R/EDI/NEWS.md:490; R/package_tests/public_api_inventory.csv:3986; R/package_tests/public_api_inventory.csv:3893)*
  `smart_cold_start_default`.** Its hurdle sibling (`inference_count_hurdle.R` ~L80-236) takes it in `initialize()`
  and forwards it, and their shared abstract accepts it, but `inference_count_zero_inflated.R` (~L85-255) does not, so
  ZIP users cannot set it. Confirm with a call, add the argument and forwarding (match the hurdle class), test. Check
  `InferenceCountZeroInflatedNegBin` too.
  Status 2026-11-18 (agent, uncommitted): confirmed and fixed for ZIP and ZINB (`smart_cold_start_default = NULL`,
  forwarded; defaults identical). Test `test-zero-inflated-smart-cold-start-and-risk-diff-nonestimable-reason.R`.
  Owner: regenerate `public_api_inventory.csv` and `comprehensive_suite_registry.csv` (initialize formals drift).
- [x] TODO-154 (added 2026-11-18, owner request): **`overwrite_all_subject_assignments()` differs between *(ticked by the TODO audit 2026-11-19: R/package_metadata/future_release_plans/release_v1_0_6.md:2773; R/EDI/R/design_abstract.R:497; R/EDI/R/design_fixed_abstract.R:175; R/EDI/tests/testthat/test-overwrite-assignments-shared-fixed-and-sequential.R:23; R/EDI/NEWS.md:654)*
  `design_abstract.R` (~L405-498) and `design_fixed_abstract.R` (~L89-187).** Only the fixed copy calls
  `assert_fixed_sample()`; the fixed copy also checks that `w` is 0/1, though v1.0.6-TODO-106 added an always-on
  0/1/NA/length check (`assert_overwritten_w_always()`) that may already cover the abstract copy. Decide whether the
  abstract (sequential) path should assert anything the fixed one does, or whether the two should share one body;
  test both.
  Status 2026-11-18 (agent, uncommitted): the premise was stale (neither copy called `assert_fixed_sample()`; the only
  difference was a 0/1 check already covered by v1.0.6-TODO-106). `DesignFixed`'s override removed, one body in
  `Design` with two always-on checks: no subjects yet (`t == 0`), and a sequential design with `n` while `t < n`
  (open-ended designs allowed). No repo caller overwrites early, so results are unchanged. Test
  `test-overwrite-assignments-shared-fixed-and-sequential.R` (100). NEWS under "Breaking changes". Rd needs
  regenerating (the `DesignFixed` method's block is gone).
- [ ] TODO-155 (added 2026-11-18, owner request): **The Python bindings default `smart_cold_start` differently for
  logistic and probit**: `python/cpp/bindings_binary.cpp` ~L255-284 `fast_logistic_regression` defaults
  `smart_cold_start = false`, ~L335-364 `fast_probit_regression` defaults `true`. Check both against the R `_cpp`
  defaults and the R classes' usage, make them consistent (an rpy-parity question), and update `_core.pyi`, the
  v1.0.6-TODO-101 rules table if it mentions defaults, and `python/CHANGELOG.md`. Needs a wheel rebuild.

- [x] TODO-156 (added 2026-11-18, owner request; minor): **`inference_incidence_risk_diff.R` (~L217-273) hard-codes
  the nonestimable reason `"model_fit_unavailable"`** where its near-copy in
  `inference_all_abstract_asymp_lik_std_mod_cache.R` (~L183-232) uses the class-specific
  `generate_mod_nonestimable_reason %||% ...`. Use the same expression so the recorded (and warned) reason is specific;
  test the reason on a failing fit.
  Status 2026-11-18 (agent, uncommitted): fixed (uses `generate_mod_nonestimable_reason %||% ...`), but no output
  changes today because risk-diff's `generate_mod()` never sets a reason; owner call whether it should.
  Closed 2026-11-18 (owner): the fix stands (a reason set by `generate_mod()` is used); no class-specific reason is
  added, because OLS risk difference fails in essentially one way (treatment not identified), which
  `model_fit_unavailable` already covers. Fix uncommitted.

### Perfect predictors among the covariates (TODO-158..159)

A covariate (or set of covariates) that predicts the response exactly, given treatment, is almost always leakage in
a randomized experiment (the outcome or a post-treatment variable in `X`). Decided (owner, 2026-11-18): "perfect
predictor" means zero residual variance (to a relative tolerance) in the fit of `y` on `w` plus the covariates, not
`y` on the covariates alone: with `y = x + tau w` exactly and `tau != 0`, `x` alone does not fit perfectly but
`w + x` does.

- [x] TODO-158 (added 2026-11-18, owner request): **Detect perfect predictors in the inference covariates, drop them *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract.R:205; R/EDI/R/inference_all_abstract.R:1643; R/EDI/R/inference_all_abstract.R:1596; R/EDI/R/inference_all_abstract.R:1677; R/EDI/R/inference_all_abstract.R:1775; a combination leak (y = x1 + x2 + tau w) drops both columns, never w; R/EDI/R/inference_count_hurdle.R:...)*
  and warn.** Decided (owner, 2026-11-18): in the top `Inference` class's constructor, check whether `y ~ w + X` fits
  with zero residual variance; if so, find the smallest set of columns whose removal restores a nonzero residual (it can be a
  combination, e.g. `y = x1 + x2`) and raise one classed warning (e.g. `edi_perfect_predictor_warning`) naming them and
  suggesting leakage. With an exact fit the estimate of tau is exact but the SE is 0, so p-values and intervals
  degenerate. The detection is a cheap least-squares residual check, not a model fit. Decided: the constructor drops
  those columns from the covariates the class will use, with the warning, and every later fit (estimate, CIs,
  resampling) uses the reduced set, so the model is fitted once, without them; randomization keeps the reduced model
  unbiased. (Considered and not chosen: fit as specified and mark the SE nonestimable.) Watch out: the check needs
  responses, which a sequential design may not have when the Inference object is built; then run it lazily at the
  first fit, still before fitting. A design that changes after construction (more responses) must re-run it. Once per object, never inside resampling.
  Per-response-type definition (owner, 2026-11-18). Two different things look like "perfect prediction"; only the
  first drops columns:
  1. An exact linear relation (leakage: `X` holds the response or a linear function of it on the model's scale).
     Detect with one cheap least-squares check of a type-appropriate transform of `y` on `w + X`, flagged when the
     residual sum of squares is ~0 relative to the total sum of squares:
     - continuous: `y`;
     - survival: `log y` over exact event times, and every censored row's interval contains the fitted time;
     - proportion: `logit(y)` over interior values;
     - count: `y` and `log1p(y)`;
     - incidence: the 0/1 `y` (catches only a copy of the outcome in `X`);
     - ordinal: the category codes.
     Drop the smallest set of `X` columns whose removal breaks the exact fit, with the warning.
  2. Separation (some combination of `w` and `X` splits the outcomes; the likelihood's maximum is at infinite
     coefficients): binary and ordinal separation, exact 0/1 proportions, `X` perfectly predicting count zeros, and a
     covariate that perfectly orders event times (monotone Cox likelihood). It happens by chance in small or
     rare-outcome samples, so it is not evidence of leakage: warn only, never drop (the warnings from
     v1.0.6-TODO-109/-118/-119/-122 cover most of it).
  Rules for both: never drop `w` (an exact fit or separation driven by `w` alone is a real treatment effect; only `X`
  columns are candidates). Only linear relations on the chosen scale are caught (e.g. `X` holding `y^2` is missed);
  no nonlinear dependence test, since those false-alarm on ordinary covariates. Skip the check below a
  residual-degrees-of-freedom guard (few responses relative to `ncol(X) + 2` fit exactly by saturation), as in
  v1.0.6-TODO-159. Once per object, never inside resampling.

  Status 2026-11-18 (agent, resumed, uncommitted): implemented as decided; the coordinator's temporary guards are
  removed. Check at the end of `Inference$initialize()` (pending -> lazily in `get_X()` when too few responses); never
  inside resampling. Exact = RSS <= 1e-10 x TSS by QR, skipped when n - rank([1, w, X]) < 5; never drops `w`;
  candidates from the minimum-norm exact solution, smallest breaking sets (<= 2000 subset fits), ties drop the union.
  Reduced X reaches every path (duplicate, bootstrap slow path, parametric workers, TODO-130 worker path, KK); the
  hurdle / zero-inflated / ZOIB component builders also filter it (`edi_drop_perfect_predictor_cols()`). Clean-data
  sweep: 0 differences over 128 class/data cases plus KK designs; leak sweep: every covariate-using class warns once
  and equals the fit without the leak. Test `test-perfect-predictor-covariates-dropped.R` (71). Roxygen section added
  (not roxygenized). NEWS added. Owner decisions: (1) ties drop the union (e.g. `y = 3z + 0.4 x1 + 1.5 w` drops z and
  x1) vs a deterministic single pick; (2) the lazy re-run tracks the object's own `y`, not the design; (3)
  covariate-ignoring classes skip the check (no warning there); (4) factor-dummy leaks in the component-formula
  filter are untested.
- [ ] TODO-159 (added 2026-11-18, owner request): **KK21 / KK21stepwise covariate weights for perfect predictors.**
  Today a covariate that predicts the responses so far exactly has residual variance 0, so the stepwise kernel
  (`kk21_weights.cpp`) skips it and gives it weight 0, and the non-stepwise kernel gives it eps: matching ignores the
  most useful covariate (seen with `y = x1` in the cross-platform digest test). Rule (owner, 2026-11-18): if only
  perfect predictors remain, split the weight uniformly across them; if there are other covariates, give the perfect
  ones 90% uniformly and spread the other 10% over the rest by their usual weights (make 90% a named, documented
  constant). Guard: call a covariate perfect only when its fit has enough residual degrees of freedom (e.g. >= 5);
  early responses fit `[1, w, x_j]` exactly by saturation, so below the guard use the equal-weights fallback
  (v1.0.6-TODO-120). Implementation (owner, 2026-11-18): in C++, where the stepwise kernel skips a zero-residual
  candidate today (`kk21_weights.cpp`, the `sigma2 <= 0` `continue`, ~L168-290): detect perfect predictors there and
  apply the uniform / 90-10 rule in the kernel (and the same handling in the non-stepwise kernel, which gives eps),
  rather than in R's `assign_wt`. Needs the owner's targeted compile (`EDI_UNITY=0`); the Python bindings compile the
  same kernel, so note it in `python/CHANGELOG.md`. Check seeded allocations are unchanged on data with no perfect
  predictor.

- [x] TODO-160 (added 2026-11-18, agent; found by the v1.0.6-TODO-157 agent): **Gaps left in the bootstrap *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract_non_param_boot.R:1245; degenerate Poisson and NegBin percentile intervals on large-SD counts are rejected with the warning; R/EDI/R/inference_all_abstract_non_param_boot.R:1225; the g-computation risk ratio is judged on log(RR): a skewed interval is kept, a degenera...)*
  extreme-interval check.** (1) For log-scale estimands with a large outcome SD (e.g. counts with SD 20) the old
  outcome-SD cap is ~100 log units and never binds, so degenerate Poisson/NegBin intervals there are not caught;
  tightening it would change intervals accepted today (owner decision). (2) The raw risk ratio from
  `InferenceIncidGCompRiskRatio` / `InferenceIncidKKGCompRiskRatio` keeps the outcome-SD cap; decide whether a ratio
  scale gets its own rule (e.g. apply the check to log RR). Both classes appear among the check's 372 comprehensive
  hits.
  Decided (owner, 2026-11-18): do both. (1) For link-scale estimands always apply the +/-10 link-scale bound, whatever
  the outcome SD (newly rejects only intervals with a bound beyond a ratio of e^10). (2) Run the check for the
  g-computation risk-ratio classes on log(RR) with the link-scale rule. Agent started 2026-11-18.
  Status 2026-11-18 (agent, uncommitted): both parts done in `bootstrap_confidence_interval_extreme()` (no new private
  method). 165-call before/after comparison: 155 identical, 10 intended changes (degenerate large-SD count intervals
  now NA with the warning; GCompRR degenerate [4.9e-10, 0.97] now NA; skewed RR intervals [0.76, 6.51], [2.2, 60.1],
  KK [1.56, 38.7] now kept). Paths without replicates (subsampling, m-out-of-n) unchanged. 4 tests added to
  `test-bootstrap-extreme-ci-cap-on-estimand-scale.R` (55 pass); bootstrap test files pass. NEWS under "Changes that
  alter results". Follow-ups: v1.0.6-TODO-175; unrelated bulk failures seen: v1.0.6-TODO-176.
- [x] TODO-161 (added 2026-11-18, coordinator; found while strict-rendering articles): **`articles/case-study.Rmd` fails *(ticked by the TODO audit 2026-11-19: 2557834b; R/EDI/R/inference_survival_weibull.R:45; R/EDI/R/inference_survival_weibull.R:431; Weibull fit on unscaled colon covariates keeps every covariate and matches survreg; R/EDI/NEWS.md:213)*
  the strict article gate: `InferenceSurvivalWeibullRegr` drops covariates (differ, extent, surg, ...) and refits in
  chunk `others`,** raising the new `edi_covariate_dropped_warning` (v1.0.6-TODO-138). The warning is working as
  intended, but dropping that many covariates on the article's real data may be a Weibull fit problem (cold start,
  scaling, convergence) rather than genuine separation. Investigate why the full Weibull fit is unusable there; fix
  the fit if it is a bug, otherwise show the warning on purpose (`strict_expect_warning = TRUE`) and explain it in the
  prose. Until then the article fails `scripts/render_articles_strict.R`.

  Status 2026-11-18 (agent, resumed, uncommitted): fixed; the drop was not legitimate. On `survival::colon`'s unscaled
  covariates the lbfgs Weibull fit hit maxit = 100 unconverged (newton too), so the hardened refit dropped five
  columns. New `weibull_fit_standardized_retry()` (`inference_survival_weibull.R`) runs only after a failed fit:
  refit on centered/scaled columns, map back, polish on the original columns; hooked into
  `weibull_fit_with_cold_retry()` and the LR `fit_null`. Colon now matches survreg (0.38209 vs 0.38208, SE 0.11179).
  83 of 84 survival fixtures byte-identical; the one change was a previously wrong reduced-model fit, now matching
  survreg. Strict render of `case-study.Rmd` PASS (71 s). Test `test-weibull-unscaled-covariates-fit-converges.R`.
  NEWS under "Changes that alter results". Root cause in C++: v1.0.6-TODO-164.
- [x] TODO-162 (added 2026-11-18, agent; lead from the v1.0.6-TODO-135 follow-up): **`InferenceAllSimpleAverageDiff` *(ticked by the TODO audit 2026-11-19: R/EDI/NEWS.md:512; R/EDI/R/inference_all_abstract_non_param_boot.R:2242; BCa CI on the boundary with some non-finite bootstrap draws is NA with a warning)*
  BCa on `DesignFixedCluster` returned `NA NA` with no warning at 4 clusters** (B = 201); now warned by the new
  minimum, but the cause was never found. Check whether 5+ clusters can still give a silent BCa NA, and fix the cause.

  Status 2026-11-18 (agent, resumed, uncommitted): fixed. Every silent NA was a genuine
  `bootstrap_bca_adjustment_on_boundary` with some non-finite draws (cluster resamples with no treated or no control
  cluster): `ci_bca()`'s failure handler warned only when all draws were finite, and the recorded reason made
  `missing_bootstrap_ci()` skip its own warning. It also happened at 5+ clusters (not covered by the 5-unit minimum).
  Now warns `edi_procedure_na_warning` with "Only N of B bootstrap draws were finite"; NA counts identical before vs
  after, 0 silent. Test `test-bca-ci-boundary-with-nonfinite-draws-warns.R`; 8 BCa test files pass. NEWS added. Note:
  at B = 201, BCa on cluster designs is NA (warned) in roughly 20-80% of datasets for OLS/logistic; B >= 501 is the
  documented recommendation.
- [x] TODO-163 (added 2026-11-18, agent, owner request; found by the articles-strict workflow): **The Weibull AFT
  fitter does not converge on unscaled covariates and silently reports a reduced model.** On the case-study article's
  colon data (`R/EDI/vignettes/articles/case-study.Rmd`, chunk `others`; 619 subjects, 11 covariates such as age in
  years and `nodes` up to 33, condition number about 400), `fast_weibull_regression_cpp` hits its 100-iteration cap
  with both `lbfgs` (gradient norm 38) and `newton_raphson` (49), so `InferenceSurvivalWeibullRegr` refuses the full
  fit, drops five covariates and warns (`edi_covariate_dropped_warning`). `survival::survreg` fits the full model in 5
  iterations (log-likelihood -2624.171), and EDI's own fitter converges in 13 iterations to the same optimum once the
  covariates are standardized. Fix in the fitter (`R/EDI/src/fast_weibull_regression.cpp`): standardize the
  non-intercept, non-treatment columns internally, optimize, and transform the coefficients, `vcov`, information,
  gradient and any returned `params` back to the original scale, so every caller is unchanged. The treatment
  coefficient and its variance are invariant to this, but warm starts (`warm_start_params`,
  `warm_start_fisher_info`), fixed parameters (`fixed_idx`/`fixed_values`) and the likelihood tests consume the
  information matrix and parameter vector, so they must be transformed in and out consistently. Test on this exact
  data: the full model converges, no covariate is dropped, the estimate and SE match `survreg`, and existing Weibull
  results on well-scaled data are unchanged. C++ change: compile only that file (kernel-swap check), never a full
  build. Then make the article render without the warning (`articles-strict`).
  - Done 2026-11-18: `R/EDI/src/fast_weibull_regression.cpp` standardizes badly scaled columns internally (`make_weibull_column_scaling()`, `fit_weibull_aft_with_column_scaling()`, shared by the right- and left/interval-censoring kernels and the randomization-bootstrap kernel) and maps params, vcov, information, score and gradient back; a guarded Newton polish (at most 5 steps) finishes the fit when the transform is active. On the colon data both algorithms converge and match `survreg` (treatment 0.3809608, SE 0.1117923). Test: `test-weibull-aft-unscaled-covariates-converges.R`. Verified by a single-file kernel swap into the installed EDI (139 Weibull test files: identical results except the new file, which fails on the old kernel). Python wheel not built.

- [ ] TODO-164 (added 2026-11-18, agent; from v1.0.6-TODO-161): **The Weibull C++ kernel (`fast_weibull_regression_cpp`)
  fails to converge on unscaled covariates** (lbfgs and newton both hit `maxit = 100` on `survival::colon`; survreg
  needs 5 iterations). v1.0.6-TODO-161 added an R-side standardized retry after a failure. Cleaner: standardize
  columns inside the kernel (and/or raise maxit), mapping results back. Needs the owner's targeted compile and would
  change results for fits that converge today (within optimizer tolerance); check other C++ GLM kernels for the same
  conditioning problem. Also untested: the retry on interval-censored unscaled data.

- [x] TODO-165 (added 2026-11-18, agent; left by the v1.0.6-TODO-136/-145 agent): **Remaining silent NAs in the
  randomization-bootstrap CI and the Bayesian BCa p-value.** The randomization-bootstrap CI's own NA returns
  (`missing_ci()` reasons, `rand_bootstrap_ci_bisection_failed`) don't warn (its per-delta warnings are now muffled,
  so the CI must warn once itself, like the plain rand CI); and `bayesian_bootstrap_bca_pvalue_unavailable` is silent.
  Done 2026-11-19 (agent, uncommitted): `missing_ci()` in `inference_all_abstract_rand_bootstrap_ci.R` records the
  reason and warns once (also covers the bisection and closed-form failures); the Bayesian BCa branch warns
  `bayesian_bootstrap_bca_pvalue_unavailable` (now also when `harden = FALSE`), skipping NAs `pval_bayesian_bca()`
  already warned about. Values and reasons unchanged; silent while resampling. Test
  `test-rand-bootstrap-ci-and-bayesian-bca-silent-na-warns.R` (55); 83 rand/boot/Bayesian files pass; NA-gate smoke
  passes. No allowlist change needed now; after the digest is regenerated these NAs move to the report-only
  "warned" gate. Follow-ups: v1.0.6-TODO-185.
- [x] TODO-166 (added 2026-11-18, agent; unverified lead from the v1.0.6-TODO-136/-145 agent): **Sequential Monte Carlo
  p-values stop at the first NA batch prefix.** `compute_two_sided_pval_with_sequential_mc()` (used by the rand CI
  search when r >= 200) returns as soon as one batch prefix gives NA, so a first 25-draw batch with fewer than 10
  finite draws ends the p-value NA even when all r draws would have enough; the randomization-bootstrap sequential-MC
  loop does the same. Reproduce on real data, then continue to the next batch instead of stopping.
  Done 2026-11-19 (agent, together with v1.0.6-TODO-55; R source committed by the owner in `3dabce47`, tests
  uncommitted): real. Both sequential-MC loops now draw the next batch when a prefix has too few finite draws instead
  of returning NA; once all r/B draws are in, the p-value is computed as before. New `keep_nonfinite_cache` argument
  of `get_randomization_distribution_prefix()` stops a fixed all-NA first batch being re-drawn forever. Real data
  (MASS::birthwt `ptl`, n = 16, HurdlePoisson): seq-MC p NA -> 0.683; no-NA cases byte-identical (OLS, Poisson,
  NegBin rand / rand-bootstrap CIs). New `test-sequential-mc-pval-continues-past-nonfinite-prefix.R` (11); 33
  rand files pass. Follow-up: v1.0.6-TODO-186. Minor, unchanged: the rand-bootstrap seq-MC path ignores `na.rm`.
- [x] TODO-167 (added 2026-11-18, agent; found by the v1.0.6-TODO-150 agent): **`InferencePropZeroOneInflatedBetaRegr`'s
  bootstrap randomization null is built from the observed assignment** (same bug as v1.0.6-TODO-150):
  `compute_bootstrap_worker_estimate` (`inference_proportion_zero_one_inflated_beta.R` ~L583-635) takes X from the
  `runtime$X` snapshot (treatment column from `w[i_b]`) while `y` is the live sharp-null `worker_priv$y`. On data with
  0/1 values: rand p 0.020, BRT p 0.869, null mean 0.614 vs estimate 0.598. Fix: overwrite treatment column 2 of
  `runtime$X` and `runtime$X_zero_one` with `worker_priv$w` (as TODO-150 did); check worker = slow path and null size.
  These two are the only classes with a `runtime` snapshot env.
  Done 2026-11-19 (agent; source fix committed by the owner in `3dabce47`, test uncommitted): the worker writes the live
  `worker_priv$w` into the treatment column of local copies of `runtime$X` / `runtime$X_zero_one` (rank rechecked;
  full-fit fallback). Repro: BRT p 0.85 -> 0.020 (rand 0.010). Null size (200 datasets): BRT 6.0% / 11.0% at
  0.05 / 0.10, rand 5.5% / 9.0%. Worker equals its own full fit exactly; vs the slow path within ~5e-4 (older warm-start
  and fixed-variance-component differences). No other class has the bug (14 overrides checked; only PropGComp, fixed
  in v1.0.6-TODO-150, and ZOIB snapshot runtime X). New test
  `test-zoib-rand-bootstrap-null-uses-fresh-assignment.R`. Comprehensive / argument-combination ZOIB BRT rows are now
  stale. Follow-up: v1.0.6-TODO-184.
- [x] TODO-168 (added 2026-11-18, owner request; from v1.0.6-TODO-149): **Investigate the low coverage of the
  `InferenceIncidKKGCompRiskRatio` studentized Bayesian-bootstrap interval.** The v1.0.6-TODO-149 coverage check
  (B = 101, n = 60, 100 reps, 2 cores; Monte Carlo SE ~0.022) gave 0.90 for KK RR against 0.95 nominal (KK RD 0.95,
  ordinal 0.95), about 2 MC SEs low, and 1 of 100 intervals non-finite. The agent suspected small-sample skew of a
  ratio studentized on the raw scale, or a population truth compared with a sample-standardized estimand, but did
  not check. Rerun with more reps (>= 500) and larger B; compare coverage when the bootstrap-t is studentized on the
  log-RR scale (as the jackknife and asymptotic RR paths already do) and back-transformed, and with the truth
  computed for the same standardization; check the plain (non-KK) `InferenceIncidGCompRiskRatio` too. If the log scale
  fixes it, studentize RR on the log scale.
  Investigated 2026-11-19 (agent; no package change; scratch in
  /tmp/claude-1000/-home-kapelner-workspace-EDI/354c53b6-c792-4138-93ba-8154526e6c02/scratchpad/t168/): KK n = 60,
  1000 reps, B = 999: raw studentized 0.889 (MCSE 0.010), log-RR studentized 0.899, symmetric log-RR studentized
  0.930, percentile 0.940, log Wald 0.943; plain (non-KK) class 0.886; KK n = 200 0.928. Not the truth (population vs
  sample-standardized differ by <= 0.004) and not KK-specific: a small-sample property of the Bayesian bootstrap-t (the
  pivot's upper quantile is compressed because large estimates come with large replicate SEs; misses are one-sided,
  5.5-7% below the lower bound). The 2 non-finite intervals come from a real bug, filed as v1.0.6-TODO-192.
  OWNER DECISION: (a) switch to a symmetric studentized interval on log RR (0.93 KK, 0.91 plain) and/or (b) document
  the small-sample undercoverage and point to log Wald / percentile / log basic. Agent recommends (b), plus (a) if a
  log-scale studentized RR path is wanted for consistency.
  Decided (owner, 2026-11-19): both. (a) Add a symmetric studentized Bayesian-bootstrap interval on log RR for the two
  g-computation risk-ratio classes; (b) document the small-sample undercoverage of the raw-scale studentized interval
  (about 0.89 at n = 60, 0.93 at n = 200) and point to log Wald / percentile / log basic. Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted; roxygenize pending): new `type = "symmetric-percentile-t"` in
  `compute_bayesian_bootstrap_confidence_interval()` for `InferenceIncidGCompRiskRatio` and
  `InferenceIncidKKGCompRiskRatio` (shared free function `edi_rr_bayesian_bootstrap_symmetric_studentized_ci()` in
  `inference_incidence_gcomp_abstract.R`; RD classes reject it), plus a "Bayesian-bootstrap intervals" roxygen paragraph
  on both classes. Existing six types `identical()` before/after. Coverage at n = 60, 500 reps, B = 999: KK 0.936
  (studentized 0.892, percentile 0.945), plain 0.918 (studentized 0.900, percentile 0.920); misses balanced. 67/500 KK
  datasets still hit the v1.0.6-TODO-192 RR = 1 replicates (0.940 on the clean 433). Test:
  `test-gcomp-risk-ratio-bayesian-bootstrap-symmetric-log-studentized-ci.R` (35 expectations).
- [ ] TODO-169 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **The L-BFGS wrapper declares convergence too early.** `optimize_likelihood_lbfgs`
  (`R/EDI/src/_helper_functions_core.h` ~L1361-1394) sets `past = 1`, `delta = tol` and then
  `converged = gradient_norm < tol || niter < maxit`, so any stop before the cap, including LBFGSpp's one-step
  relative-decrease rule on an ill-conditioned problem, is reported as converged with a large gradient left. Verified:
  `fast_neg_bin_cpp` on the raw colon design (y = max(nodes - 1, 0), nodes dropped from X) returns `converged = TRUE`,
  gradient norm 4.95, treatment -0.2478, where `MASS::glm.nb` and the same kernel on scaled X give -0.211; with age
  x 1000 it stops after 3 iterations at gradient 63 with treatment 0. The probe found the same pattern in every L-BFGS
  kernel (ZINB, ZIP/hurdle Poisson, hurdle NegBin, beta, ZOIB, dependent-censoring transform, logistic/Poisson/
  hurdle-Poisson/ordinal GLMMs, Weibull frailty, ordinal CLMM), several wrong on the raw data with no warning
  (e.g. `InferenceCountZeroInflatedNegBin` estimate NA; `InferenceCountHurdleNegBin` and
  `InferencePropZeroOneInflatedBetaRegr` estimates ~1e-10 at age x 1000). Fix the stopping rule (converged only when
  a scale-aware gradient criterion holds; a relative-decrease stop below the cap is not convergence), and consider a
  shared internal column scaling for all kernels, reusing the approach of v1.0.6-TODO-163 (Weibull). Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.
  Test each affected kernel against its reference fitter (glm.nb, pscl, betareg, glmer, ...) on raw and rescaled
  data. Probe scripts: the session scratchpad `scaling_probe/` (not committed).

- [ ] TODO-170 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **IRLS and Newton use an absolute gradient tolerance, so a correct fit on large-scale covariates is reported
  as not converged and the class drops covariates.** With age + 1e5, `fast_logistic_regression_cpp` and
  `fast_poisson_regression_cpp` (IRLS) reach the optimum but return `converged = FALSE`, and `fast_neg_bin_cpp` with
  Newton does the same at age x 1000; the classes then drop covariates and report a different model
  (`InferenceIncidLogRegr` drops 4, `InferenceIncidProbitRegr` 7, `InferenceIncidModifiedPoisson` 7,
  `InferenceIncidRiskDiff` all; LogRegr -0.541 vs glm -0.503). Make the convergence test scale-aware (relative
  gradient, or gradient on standardized columns, or relative change in coefficients and deviance as glm does). Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.

- [ ] TODO-171 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **The shared design-matrix rank check silently drops an innocent column at large covariate offsets.**
  `drop_linearly_dependent_cols` (`R/EDI/R/helper_model_matrix.R` ~L89-110, called from `create_design_matrix`,
  `R/EDI/R/inference_all_abstract.R` ~L1260) takes `min()` of `matrix_rank_cpp(M, tol = 1e-7)`
  (`R/EDI/src/fast_matrix_rank.cpp`, Eigen ColPivHouseholderQR threshold) and R's `qr()` rank. Once the smallest
  singular value ratio drops below about 1e-8 (age + 3e4 or more on the colon data), the Eigen rank is 10 against R's 11
  and the last pivot column (`surg`) is dropped with no warning: `InferenceContinOLS` gives 167.94 against `lm`'s 163.77
  (`fast_ols_cpp` itself is correct). Affects every class built on `create_design_matrix` (OLS, Lin, robust and
  quantile regression, proportion quantile, g-computation, ...). Center/scale before the rank test or use a
  scale-invariant tolerance, and warn whenever a column is dropped. Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.

- [x] TODO-172 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **`InferenceOrdinalGCompMeanDiff` and `InferenceOrdinalStereotypeLogitRegr` bypass the ordinal column-scaling
  wrapper.** The six PO/probit/cloglog/cauchit/adjacent-category/continuation-ratio classes fit through
  `ordinal_fit_scaled()` / `ordinal_center_scale_plan()` (`R/EDI/R/inference_ordinal_proportional_odds.R`
  ~L426-520) and are scale-invariant, but the g-computation class calls the raw kernel
  (`R/EDI/R/inference_ordinal_gcomp.R` ~L240, 288, 296) and the stereotype class calls `fast_stereotype_logit_cpp`
  directly (`R/EDI/R/inference_ordinal_stereotype_logit.R` ~L493, 538, 621, 708, 735). With y = quartiles of `time`:
  G-comp gives 0.2586 on the raw data against 0.1930 on scaled data (an `ordinal::clm` g-computation reference gives
  0.1929); stereotype gives 0.443 raw against 0.475 scaled, and at age x 1000 drops every covariate and returns NA
  (note its likelihood is multimodal, see the stereotype learning). Route both through the wrapper, transforming
  warm starts and fixed parameters as the wrapper does. Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.
  Done 2026-11-19 (agent, uncommitted): g-comp routes all five kernel calls through `ordinal_fit_scaled()` (as
  PropOddsRegr does); stereotype gets `.stereotype_center_scale_design()` (same `ordinal_center_scale_plan()` rule,
  applied once to the design: the wrapper's linear map doesn't fit the loading-dependent intercept shift; exact because
  all fits use data-only starts). Colon data: estimate and SE identical raw / scaled / x1000 / +1e5 (g-comp 0.1930,
  matches an `ordinal::clm` g-computation; stereotype 0.4752, matches a 12-start optim). The stereotype bootstrap
  worker spec now uses the full multistart (only a bulk test calls it). New
  `test-ordinal-gcomp-and-stereotype-covariate-scale-invariance.R` (23); 51 unit + 162 bulk ordinal/gcomp/migration
  files pass (except v1.0.6-TODO-190's ZOIB golden). Comprehensive rows for both classes on poorly scaled datasets
  are now stale.
- [ ] TODO-173 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **`fast_probit_regression_cpp` reports `converged = FALSE` even on a well-conditioned, fully converged fit.**
  On the scaled colon design (y = status) it returns `converged = FALSE` with gradient norm 1.5e-8 and the correct
  coefficients (matching `glm(binomial(link = "probit"))`). Find why the flag is never set (Newton path, probably the
  criterion or its reset) and add a test that a clean probit fit reports converged; check whether callers drop
  covariates or retry because of it.

- [ ] TODO-174 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **The ordinal GLMM and CLMM classes return NA on ordinary data.** `InferenceOrdinalKKGLMM` returns NA on the
  raw colon data (y = quartiles of `time`) while the scaled fit gives -0.026; `InferenceOrdinalKKCLMM` returns NA at
  age x 1000 (its kernel `fast_ordinal_clmm_cpp` stops with treatment 0 and gradient norm 325). Kernels:
  `fast_ordinal_glmm_cpp` (K/C variants `converged = FALSE`, objective 793/786 vs 778.47 scaled) and
  `fast_ordinal_clmm_cpp`, both L-BFGS (see the L-BFGS stopping-rule TODO above). Find why the classes return NA
  rather than a fit or an informative non-estimable reason, fix the scaling, and compare with `ordinal::clmm`. Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.
  The probe ran these through KK designs with `private$X` overridden to keep the matching fixed across variants,
  because KK14 matching is itself scale-dependent.

- [x] TODO-175 (added 2026-11-18, agent; from v1.0.6-TODO-160): **Remaining raw-ratio-scale guards for the
  g-computation risk ratio.** (1) The non-parametric percentile/BCa paths for `InferenceIncidGCompRiskRatio` often
  return NA earlier via `bootstrap_extreme_finite_estimates`: one replicate with near-zero control risk gives an RR
  above 1e6 and rejects the whole bootstrap (n = 30, rare-control fixtures), while the Bayesian path on the same data
  now gives [0.76, 6.5]; apply that estimates guard on log(RR) too. (2) The RR m-out-of-n interval on a regular
  fixture is [3e-5, 2.83] and is accepted because theta-free callers skip the log(RR) rule; pass log-scale information
  there. (3) `compute_rr_bootstrap_basic_confidence_interval` and `compute_rr_bayesian_bootstrap_log_confidence_interval`
  never call the extreme check; decide whether they should.
  Done 2026-11-19 (agent; R source committed by the owner in `3dabce47`, two test files uncommitted): (1) the CI
  replicate guard runs on log(RR) (p-value paths keep the raw-scale guard on purpose: their statistics use the raw
  replicate mean); (2) theta-free RR callers (subsampling / m-out-of-n) get the log(RR) rule (+/-10 bound and the
  log-scale width cap of 5); passing subsample replicates as theta was tried and reverted (they are ~sqrt(n/b) wider);
  (3) the basic bootstrap RR interval and the Bayesian basic/Wald RR paths now run the guard and the check. 165-call
  comparison: only 7 RR rows changed (e.g. small-n GCompRR percentile now [0.668, 8.13] instead of NA; m-out-of-n
  [3e-5, 2.83] now NA); 3 degenerate basic intervals now NA. 87 expectations in the extreme-cap test; 51/52 boot files
  (the 1 is a sandbox socket error); 135 bulk files pass after the pivot-reference test set `harden = FALSE`.
  Open owner choice: theta-free RR intervals are also held to the log-scale width cap of 5 (bounds more than ~148x
  apart are rejected, as for log-OR subsampling); the alternative is the +/-10 bound only.
- [x] TODO-176 (added 2026-11-18, coordinator; seen by the v1.0.6-TODO-160 agent): **Two bulk tests fail after this
  round's changes, unrelated to TODO-160.** (1) `R/package_tests/testthat_bulk/test-simple-estimator-migration-baseline.R`:
  private-owner counts are +4 (e.g. 340 vs 336), the four `perfect_predictor_*` fields added by v1.0.6-TODO-158;
  re-pin the baseline (the file's own comment predicts this). (2)
  `test-dep-cens-transform-compute-bootstrap-ci-basic-and-bca-wrapper-wiring-reference.R`: "names for current but not
  for target" in `dep_cens_validate_bootstrap_ci`; find which change caused it and fix the test or the code.
  Done 2026-11-19 (agent, uncommitted; tests only, no R source). (1) Manifest diff vs a HEAD copy: only additions are
  the four `perfect_predictor_*` fields (v1.0.6-TODO-158) plus two private methods from the in-flight
  v1.0.6-TODO-175 edit (`bootstrap_estimand_is_raw_ratio`, `bootstrap_ci_estimates_extreme`); re-pinned to
  342/345/353/326/339. Re-pin again if TODO-175 changes before commit. (2) Cause: v1.0.6-TODO-160's +/-10 link-scale
  bound rejects the test's artificial est = 5 interval [9.41, 10.53] (intended), so the class falls back to its named
  percentile CI; fixture changed to est = 3 (interval [5.4, 6.5], still checks the same wiring). 24 nearby bulk files
  pass.
- [ ] TODO-177 (added 2026-11-18, owner decision; from v1.0.6-TODO-79): **Sequential designs get their own randomness,
  seeded per subject.** Today a `DesignSeqOneByOne*` design calls `set.seed(seed)` once at construction and then draws
  from R's global stream, so (a) any RNG use between construction and the assignments changes the allocation, (b) a
  saved trial does not continue exactly after `readRDS()` without the user saving `.Random.seed`, and (c) it resets the
  session's stream. Decided: when `seed` is given, derive each assignment's draw from `(seed, subject index t)` (the
  seed-per-draw-index rule EDI already uses so results don't depend on the thread count), run it with the session's
  RNG state saved and restored, so allocations depend only on the seed and the subjects' data, a saved trial continues
  exactly, and the session's stream is untouched. `seed = NULL` keeps using the session's stream. Changes seeded
  sequential allocations for every sequential design (Efron, Atkinson, Pocock-Simon, KK14/KK21/KK21stepwise, ...):
  re-pin their migration goldens deliberately, NEWS under "Changes that alter results", and update the
  reproducibility article and the `Design` roxygen written for v1.0.6-TODO-79.
  Status 2026-11-19 (agent, uncommitted): done. One wrapper in
  `DesignSeqOneByOne$add_one_subject_to_experiment_and_assign()` (not in `assign_wt()`, which the redraw replays call:
  seeding there would make every redraw reproduce the realized allocation); constructor no longer seeds; internal
  `seq_design_draw_seed(seed, key)` (same polynomial hash as `comprehensive_tests.R`'s `coverage_truth_seed()`);
  `draw_ws_according_to_design()` on a seeded design runs under derived(seed, "redraw"). Inference/bootstrap draws
  use `duplicate()` (seed NULL) and are unchanged. All 11 sequential designs verified (unrelated RNG use, save/reload
  mid-trial, session stream untouched); new `test-seeded-sequential-design-per-subject-rng.R` (62 pass); 191 affected
  test files pass, one deliberate re-pin (`test-pocock-simon-level-rows-and-binary-match-structure-reference.R`, seed
  601). Goldens and the cross-platform digests did not move (their designs are unseeded). `reproducibility.Rmd` and
  `running-a-sequential-trial.Rmd` rewritten, both strict-render PASS. NEWS under "Changes that alter results".
  Pending: roxygenize (`Design`, `DesignSeqOneByOne` Rd); regenerate the public-argument-combination / workflow-coverage
  CSVs (their sequential fixtures use `seed =`). Confirmed v1.0.6-TODO-42 (Urn redraw overwrites realized `w`) still
  reproduces, with or without a seed.
- [ ] TODO-178 (added 2026-11-19, owner request 2026-11-18; built by agent, uncommitted): **Weekly untested-code
  audit** (`audit_jobs_framework.md` TODO-21). `.github/workflows/audit-untested-code.yml` (Tuesdays 09:07 UTC) ranks
  uncovered regions from CI coverage by risk, has Opus agents write tests (or judge a region unreachable / intended /
  a bug), verifies each test in an instrumented `EDI_UNITY=0` CI build (must pass, assert a value, cover >= half the
  region) and opens one PR with the kept tests. Skips weeks with no code/test change. New:
  `.github/scripts/audits/untested_code.py`, `untested_code_export.R`, `.github/prompts/audit_untested_code.*`,
  `R/package_metadata/audits/untested_code_allowlist.csv` (rows must cite an open release TODO); edits to `audit.yml`
  (`finish_coverage_build`), `audit-status.yml`, `test-coverage-R.yaml` (`coverage-lines` artifact),
  `test-coverage-python.yml` (`coverage-python` artifact), dead-code and allowlist-hygiene audits. 392 audit unit
  tests pass; actionlint clean. Not yet run on GitHub. To close: commit, push once (first `coverage-lines` artifact),
  first manual run with `scope: all`, decide allowlist rows for the mirai/daemon paths (they need an open TODO).
  First-ranked real gap: `design_seq_one_by_one_abstract.R:190-201` (Pocock-Simon preallocated path when a later
  subject's columns/levels differ) never runs in the suite. Estimated cost ~$6-12/week.

- [x] TODO-179 (added 2026-11-19, owner request; lead from the v1.0.6-TODO-151 agent): **Do estimands with a no-effect
  value other than 0 have mis-centered tests?** TODO-151 found the studentized BRT centered the raw risk ratio at 0
  instead of 1. Estimands whose no-effect value is 0.5 (`mann_whitney_effect`), or any other non-zero no-effect value,
  may have the same problem in the studentized / symmetric-percentile-t BRT, Wald / asymptotic p-values with
  `delta = 0`, or bootstrap p-values. List every estimand type and its no-effect value, check each test path's
  default center, and fix any that center at 0 by mistake (`default_null_value()`).
  Done 2026-11-19 (agent, uncommitted; no source change): only the `RR` tag has a nonzero no-effect value, and every RR
  p-value path already defaults to RR = 1 (the studentized BRT was the one exception, fixed in v1.0.6-TODO-151).
  Stochastic-superiority estimands (Ridit, JT, sign test) are reported as theta - 0.5, so 0 is correct; MarginalEstimand
  `"marginal_ratio"` is a log ratio. Null size simulated (200 datasets) on every path for GCompRR, KKGCompRR, Ridit, JT,
  SignTest: consistent with correct centering. Guard test `test-estimand-no-effect-value-centering.R` (51): a new
  estimand tag must be classified. Follow-up: v1.0.6-TODO-191.
- [ ] TODO-180 (added 2026-11-19, agent, owner request; found by the weekly R-CMD-check on 4ce2b712, run 44358518303):
  **The slow path and the reusable-worker path disagree for general-censoring survival classes.**
  `R/EDI/tests/testthat/test-rand-test-and-ci-shift-censoring-bounds-under-null.R:73` fails on every platform. The
  sanitizer legs (valgrind, ASAN/UBSAN), which run more tests, also fail
  `test-rand-bootstrap-shifts-censoring-bounds-under-null.R:64,67` and
  `test-bootstrap-subset-copy-drops-parent-row-caches.R:68` on interval-censored data. The class named in the failure
  is `InferenceSurvivalWeibullRegr`, and the two paths differ by about 1e-5. The likely cause is the Weibull optimizer
  stopping early from different warm starts, which v1.0.6-TODO-163 (column scaling and a Newton polish in
  `fast_weibull_regression.cpp`) should fix. Re-run these three files on a build with TODO-163. If they still fail,
  find which class and path differ, and either make the worker path start from the same point as the slow path or
  loosen the tolerance only where the difference is optimizer precision. Valgrind and ASAN/UBSAN reported no memory
  errors.
- [ ] TODO-181 (added 2026-11-19, agent, owner request; found by the weekly R-CMD-check on 4ce2b712, sanitizer legs):
  **Two argument-validation tests don't skip classes whose optional packages aren't installed.**
  `R/EDI/tests/testthat/test-inference-args-reject-na.R:113,163` and
  `test-inference-args-reject-nonscalar-nonfinite.R:116` fail 8 times each on the valgrind and ASAN/UBSAN legs with
  "has no fixture", because the fixtures (`na_arg_fixtures`, line 18) can't build these classes:
  `InferenceContinKKQuantileRegrIVWC`, `InferenceContinKKQuantileRegrOneLik`, `InferenceContinQuantileRegr`,
  `InferencePropKKQuantileRegrIVWC`, `InferencePropKKQuantileRegrOneLik`, `InferencePropQuantileRegr`,
  `InferenceOrdinalKKGEE` and `InferenceSurvivalKKRankRegrIVWC`. Those images likely lack the Suggests packages the
  classes need (quantreg, geepack, ...). Confirm which package is missing, then skip a class whose required package
  is not installed (`skip_if_not_installed()` or a per-class `requireNamespace()` check) instead of failing. This is a
  test bug, not a package bug.
- [ ] TODO-182 (added 2026-11-19, agent, owner request; found by the nightly run 44358510753 on 4ce2b712):
  **The nightly silent-NA gate fails for `InferenceAllSimpleAverageDiff$compute_bootstrap_confidence_interval`.**
  On the smoke fixtures the same BCa-boundary NA comes with a warning in some calls and silently in others (5
  continuous cases, 1 incidence), so the `silent_na_output` hard gate fails. Reproduced by re-running the gate on
  4ce2b712 with the run's artifact CSVs. Suspected cause: a warn-once flag or a cache hit that returns the cached NA
  without re-raising the warning (not confirmed). Make every NA that this method returns come with its warning (or a
  `procedure_failure_reason`), and add a test that calls it twice on the same object and expects the warning both
  times.

- [x] TODO-183 (added 2026-11-19, agent; found by the v1.0.6-TODO-42 agent): **Mid-trial redraws on sequential designs
  are inconsistent.** (1) `DesignSeqOneByOnePocockSimon$draw_ws_raw()` loops over all `n` preallocated rows, so
  before every subject is enrolled it errors ("Unknown strata level encountered for Pocock-Simon column s: NA"; repro:
  `strata_cols = "s"`, `n = 30`, enroll 20, `draw_ws_according_to_design(2)`). (2) After 20 of 30 subjects, Efron and
  iBCRD redraws return `n` = 30 rows while Bernoulli, Urn, Atkinson, SPBR, RandomBlockSize and the KK designs return
  `t` = 20; pick one (likely `t`, the enrolled subjects) and make all designs agree. (3) The generic replay calls
  `assign_wt()` with `private$t` fixed at the final `t`, so a custom sequential `assignment_rule()` that reads `t` or
  the current subject's row sees the wrong subject during a redraw; advance `t` during the replay and restore it.
  Done 2026-11-19 (agent, uncommitted): (1) Pocock-Simon `draw_ws_raw()` builds strata over the `t` enrolled
  subjects; (2) Efron calls its kernel with `t`; iBCRD still draws full-`n` sequences (it balances toward the planned
  n) and keeps the first `t` rows, so all 11 designs return `t` rows, as the roxygen already says; (3) the generic
  replay advances `private$t` and restores it via `on.exit`. Completed-trial redraws identical (8 comparisons). Redraw
  test extended (Pocock-Simon mid-trial, row counts for all 11, custom rule reading `t`); one Efron bulk reference
  test updated to enroll first; 76 files / 3,496 expectations pass. Follow-up: v1.0.6-TODO-187.
- [x] TODO-184 (added 2026-11-19, agent; found by the v1.0.6-TODO-167 agent): **ZOIB randomization statistic ignores
  `estimand = "marginal_mean_diff"`.** `InferencePropZeroOneInflatedBetaRegr`'s
  `compute_treatment_estimate_during_randomization_inference` (`inference_proportion_zero_one_inflated_beta.R`
  ~L497-524) always returns the conditional coefficient `res$b[2]`, so under the marginal estimand the BRT slow path
  draws on the conditional scale (0.2-0.4 off the worker on the repro). The plain randomization test and CI for the
  marginal estimand probably use the same function and would also run on the conditional scale; check. Repro:
  `make(0.8)` in the TODO-167 agent's scratch `t167/eq.R`, `inf$set_estimand("marginal_mean_diff")`, compare
  `run_rand_bootstrap_iteration` with worker draws.
  Done 2026-11-19 (agent, uncommitted): under `marginal_mean_diff` the ZOIB randomization statistic refits all
  parameters and returns the marginal functional (conditional path byte-identical); `set_estimand()` drops resampling
  caches and reusable workers when the estimand changes (was reusing the old estimand's: rand p 0.63 vs fresh 0.26);
  rand and rand-bootstrap CIs are refused under any non-conditional estimand
  (`inference_stop_rand_ci_non_conditional_estimand()`, `edi_rand_ci_estimand_scale_mismatch_refused`). Repro worker
  vs slow path 0.22 -> 6e-4; null size under marginal (200 datasets): BRT 6.0% / 10.5%, rand 5.5% / 10.5%. New
  `test-zoib-marginal-estimand-randomization-statistic.R` (10). Left: roxygen for the CI refusal;
  `get_effective_capabilities()` still advertises the two CIs after switching to a marginal estimand. Follow-ups:
  v1.0.6-TODO-189, -190.
- [ ] TODO-185 (added 2026-11-19, agent; found by the v1.0.6-TODO-165 agent): **Two leftovers from the silent-NA work.**
  (1) The Bayesian-bootstrap p-value's normal-approximation branch still returns a silent NA for
  `bayesian_bootstrap_standard_error_unavailable`; same one-line `edi_warn_procedure_na()` fix. (2) Computing the
  null draws resets `private$active_resampling_operation` to NULL instead of restoring the previous value, so a flag set
  by an outer resampling call is lost after an inner one; check whether any outer operation then warns where it
  should be silent, and restore the previous value if so.

- [x] TODO-186 (added 2026-11-19, agent; found by the v1.0.6-TODO-166 agent): **`InferenceCountHurdlePoisson`'s
  randomization null distribution collapses to a constant.** On MASS::birthwt (`ptl`, n = 16, covariates
  age/lwt/smoke/ht/ui) every randomization replicate is nearly the same value instead of responding to the permuted
  assignment: after the observed estimate is computed, replicates equal it (t = 0.00508, replicate 5-95% range
  0.00507-0.00508); a fresh one-shot run gives a different constant (~0.25) and a different number of finite draws,
  so seq-MC and one-shot p-values disagree with no NA (0.18 vs 0.033). Likely stale warm-start / cached state reused
  across replicates (cf. the zero-inflation-ridge warm-start learning). Repro: the TODO-166 agent's scratch
  `probe5.R`, `probe6.R` in /tmp/claude-1000/-home-kapelner-workspace-EDI/354c53b6-c792-4138-93ba-8154526e6c02/scratchpad/.
  Check HurdleNegBin and the other zero-augmented classes too. Coordinate with v1.0.6-TODO-62 (hurdle core-count).
  Done 2026-11-19 (agent, uncommitted): not a stale cache. Every repro dataset has exactly one positive count against a
  7-column count submodel, so the count-part treatment coefficient (learned from positive rows only) is not
  identified and the optimizer returns its warm start. New `zero_augmented_count_treatment_identified()` (rank of the
  positive-row count design with vs without treatment); where it fails, the full fit, randomization refit and weighted
  bootstrap are NA (`zero_augmented_count_treatment_unidentified`, `hurdle_negbin_count_treatment_unidentified`;
  HurdleNegBin's treatment-only fallback still runs when dropping covariates restores identification). Null
  simulation (300 datasets, n = 24): size 3.0-5.3% at 0.05, KS p 0.48-0.78. New
  `test-zero-augmented-count-treatment-unidentified-from-positive-rows.R` (20); ~4,085 hurdle / zero-inflated / rand
  expectations pass. Results change: such datasets are now NA instead of arbitrary; committed rows on sparse small-n
  count data may go stale. Follow-ups: v1.0.6-TODO-195.
- [ ] TODO-187 (added 2026-11-19, agent; found by the v1.0.6-TODO-183 agent; owner decision, changes results):
  **`DesignSeqOneByOneiBCRD` with `n = NULL` has the wrong randomization distribution.** With no planned `n`,
  `assign_wt()` falls back to a Bernoulli coin, but the redraw still calls `generate_permutations_ibcrd_cpp(t)`, which
  forces exact balance at `t`: enroll 21 subjects, `colSums(draw_ws_according_to_design(500))` is always 11. Likely fix:
  when `private$n` is NULL, redraw with `generate_permutations_bernoulli_cpp(t, r, prob_T)`. Repro: the TODO-183
  agent's `$TMPDIR/t183/ibcrd_nulln.R`. Related: v1.0.6-TODO-76 (`n = NULL` behaviour of sequential designs).

- [ ] TODO-188 (added 2026-11-19, agent; found by the v1.0.6-TODO-87 agent; needs a wheel rebuild): **Python
  `fast_neg_bin` returns `neg_loglik = nan` and an empty `mu`.** The NB internal stores the log-likelihood in
  `res.sigma2_hat` (R's `fast_neg_bin_with_var_cpp` returns `logLik = res.sigma2_hat`), but
  `python/cpp/bindings_count.cpp` returns `res.neg_ll`, which is never set; `mu` comes back with shape (0,). Fix in the
  binding (e.g. `out["neg_loglik"] = std::isfinite(res.neg_ll) ? res.neg_ll : -res.sigma2_hat;`, and fill `mu`), add
  a test against R, rebuild the wheel.

- [ ] TODO-189 (added 2026-11-19, agent; found by the v1.0.6-TODO-184 agent): **Randomization statistic stays
  conditional under `marginal_mean_diff` in other classes.** Marginal estimate vs randomization statistic:
  `InferencePropBetaRegr` 0.170 vs 0.718, `InferenceCountPoisson` / `QuasiPoisson` 0.773 vs 0.309,
  `InferenceCountHurdlePoisson` 0.751 vs 0.204, `InferenceCountZeroInflatedPoisson` 0.755 vs 0.229,
  `InferenceIncidLogRegr` 0.160 vs 0.667 (`InferenceIncidBinomialIdentityRiskDiff` is fine). Their rand p-values are
  valid sharp-null tests but don't match the estimate, and their BRT may compare a conditional observed statistic with
  marginal null draws (as ZOIB did). Apply the TODO-184 pattern per class (marginal functional in
  `compute_treatment_estimate_during_randomization_inference`, worker and slow path agree), and make
  `get_effective_capabilities()` estimand-aware. Repro: the TODO-184 agent's `t184/others.R` in
  /tmp/claude-1000/-home-kapelner-workspace-EDI/354c53b6-c792-4138-93ba-8154526e6c02/scratchpad/.

- [ ] TODO-190 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-184 agent): **`test-zoib-jackknife-reusable-worker-migration-golden.R`
  fails 6 expectations** (`beta_x` missing from the worker's columns, L126; the jackknife extreme-summary NA no longer
  produced, L262-267). The test sets no estimand and uses no randomization path; suspected cause is another uncommitted
  change (v1.0.6-TODO-158 perfect-predictor column handling, or -167 / -175). Bisect against `git show HEAD:` copies
  (no `git stash`: shared checkout), then fix the test if the new behaviour is intended or the code if it is a
  regression.

- [ ] TODO-191 (added 2026-11-19, agent; found by the v1.0.6-TODO-179 agent; owner decision on the fix): **Risk-ratio
  subsampling and m-out-of-n p-values almost never reject.** Null size at n = 80 (200 datasets):
  `InferenceIncidGCompRiskRatio` subsampling 0.005, m-out-of-n 0.000 (`InferenceIncidKKGCompRiskRatio` 0.015 / 0.000;
  the RD sibling 0.065 / 0.070). With the default b = 21 of 80, subsamples with a zero-event arm or near separation
  give log RR ~ +/-20, so the pivot sqrt(b)(log RR* - log RR_hat) in `compute_rr_resampling_pivot()`
  (`inference_incidence_gcomp_abstract.R` ~L403) spans ~+/-98 and nearly every p-value is large; the matching CIs are
  very wide. Options: larger default b / m for ratio estimands, drop degenerate subsamples, or a studentized pivot.
  Repro: `/tmp/claude-1000/t179/dbg.R` (seed 1005).

- [ ] TODO-192 (added 2026-11-19, agent; found by the v1.0.6-TODO-168 agent): **The KK g-computation weighted refit
  poisons its own warm-start chain.** `compute_weighted_gcomp_estimate` (`inference_incidence_KK_gcomp_abstract.R`
  ~L452-487) stores every replicate's coefficients in `private$gcomp_boot_beta` as the next warm start without checking
  `mod$converged` or `coefficients_are_usable()`. One diverged fit (repro: rep 102, `set.seed(100102)`, warm start
  (-0.70, 2.24, 3.18, -1.38) -> `converged = FALSE`, b ~ 1e9 after 100 IRLS iterations; cold start converges to glm's
  answer) makes every later replicate garbage (RR exactly 1, NA SE). In a 1000-rep study 104 datasets were hit; they
  covered 0.82 vs 0.90 and caused the non-finite intervals. Affects every Bayesian-bootstrap type for KK RR and RD.
  Fix: accept a fit only if converged and usable; otherwise retry from `get_fit_warm_start_for_length("beta", p)`,
  then cold; never cache a failed fit (set NULL, return NA). Same `converged` check plus a cold retry before the
  covariate-drop loop in the plain class (`inference_incidence_gcomp_abstract.R` ~L537-575). Working version: the
  agent's `t168/patch.R` (all 999 replicates kept, ~3x faster). Regression test with the rep-102 data. C++ follow-up
  (weighted logistic IRLS runs to |b| ~ 1e9 with no step-halving) belongs with v1.0.6-TODO-169/170.

### Code-duplication audit backlog (TODO-193..194)

- [ ] TODO-193 (added 2026-11-19, owner request): **Merge the code-duplication audit's "refactor" clones into shared
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
  - `code-duplication-da35f9c8f` (`dup-1adb37d8ab20`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:534-614` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:622-701` (coordinate with v1.0.6-TODO-192, same function)
  - `code-duplication-d6b10061f` (`dup-440466dd6dc0`): `R/EDI/R/design_abstract.R:405-498` vs `R/EDI/R/design_fixed_abstract.R:89-187` -- DONE by v1.0.6-TODO-154 (uncommitted): `DesignFixed`'s override removed, one body in `Design`
  - `code-duplication-d4e38d855` (`dup-47b3c5848e6a`): `R/EDI/R/inference_survival_gehan_wilcox.R:220-329` vs `R/EDI/R/inference_survival_log_rank.R:199-317` -- DONE (agent, uncommitted)
  - `code-duplication-d23a10708` (`dup-4ca7ca9c9237`): `R/EDI/R/inference_ordinal_ordered_probit.R:100-186` vs `R/EDI/R/inference_ordinal_proportional_odds.R:134-217` -- DONE (agent, uncommitted)
  - `code-duplication-dcdb7e599` (`dup-51b70d0e54ad`): `R/EDI/R/inference_incidence_KK_cond_logit_glmm_abstract.R:367-427` vs `R/EDI/R/inference_proportion_KK_combined.R:164-224` -- DONE (agent, uncommitted)
  - `code-duplication-dfe6e2293` (`dup-53e9eeb69c5d`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:863-970` vs `R/EDI/R/inference_incidence_gcomp.R:16-151`
  - `code-duplication-de10bd6b1` (`dup-6af874290f8f`): `R/EDI/R/simulations_framework.R:3393-3441` vs `R/EDI/R/simulations_framework.R:3446-3494` -- DONE (agent, uncommitted)
  - `code-duplication-db001874c` (`dup-847f2d57f083`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:259-462` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:296-515` (coordinate with v1.0.6-TODO-192)
  - `code-duplication-d7e6ac7c3` (`dup-86f70c0a1fbe`): `R/EDI/R/inference_ordinal_cauchit.R:8-80` vs `R/EDI/R/inference_ordinal_ordered_probit.R:2-76` -- DONE (agent, uncommitted)
  - `code-duplication-d24d11c40` (`dup-8fdf724fbd87`): `R/EDI/R/simulations_framework.R:2110-2146` vs `R/EDI/R/simulations_framework.R:2157-2194` -- DONE (agent, uncommitted)
  - `code-duplication-d1b25b18a` (`dup-a82df7b209aa`): `R/EDI/R/inference_continuous_quantile_regr.R:50-261` vs `R/EDI/R/inference_proportion_quantile_regr.R:54-262` -- DONE (agent, uncommitted)
  - `code-duplication-d593b90a9` (`dup-e88368769f0c`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:400-427` vs `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:439-462` (coordinate with v1.0.6-TODO-192)
  - `code-duplication-dc93f6357` (`dup-fb4cd2ec3279`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:183-232` vs `R/EDI/R/inference_incidence_risk_diff.R:217-273` -- DONE (agent, uncommitted)
  - `code-duplication-dc1588975` (`dup-01e154dfbad0`) [C++]: `R/EDI/src/gcomp_speedups.cpp:175-276` vs `R/EDI/src/gcomp_speedups.cpp:384-490` -- DONE (agent, uncommitted; verified by kernel swap): `compute_gcomp_logistic_post_fit()` is now a template taking the meat as a functor; HC0 and cluster exports both call it
  - `code-duplication-d1a5a5abe` (`dup-5997356561a2`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:100-387` vs `R/EDI/src/fast_ordinal_cloglog_regression.cpp:108-386` -- DONE (agent, uncommitted; verified by kernel swap): one template `edi_ordinal::fixed_link_ordinal_internal<Model>()` (+ shared score/Hessian templates) in new header `R/EDI/src/ordinal_fixed_link_internal.h`, shared with probit; the cloglog validation-order drift is kept as an explicit policy flag (bit-identical), not fixed
  - `code-duplication-da540c45e` (`dup-7640a4a65caa`) [C++]: `R/EDI/src/fast_hurdle_poisson_glmm.cpp:32-72` vs `R/EDI/src/fast_poisson_glmm.cpp:36-82` -- PATCHED, needs owner build: soft_barrier trio moved into `_glmm_engine.h` (namespace glmm), both files use `glmm::gauss_hermite_rule`; hurdle half verified by kernel swap, `fast_poisson_glmm.cpp` cannot be sourceCpp'd standalone (needs `fast_poisson_regression_internal` from another TU)
  - `code-duplication-d4d992420` (`dup-b4945bb7ace9`) [C++]: `R/EDI/src/fast_gaussian_lmm.cpp:636-663` vs `R/EDI/src/fast_gaussian_lmm.cpp:683-710` -- DONE (agent, uncommitted; verified by kernel swap): static `build_lmm_data()` in the same file
  - `code-duplication-dd690bfdc` (`dup-b82ef667e0cb`) [C++]: `R/EDI/src/kk_compound_distr_parallel.cpp:25-112` vs `R/EDI/src/kk_compound_distr_parallel.cpp:126-211` -- DONE (agent, uncommitted; verified by kernel swap): static inline `compound_beta_hat()` in the same file
  - `code-duplication-d730a0bdd` (`dup-b84f50f38a71`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:177-387` vs `R/EDI/src/fast_ordinal_probit_regression.cpp:179-381` -- DONE (agent, uncommitted; verified by kernel swap): same shared template as the cauchit/cloglog item; probit's NaN guard on ssq_b_j and its missing K<2 early return are kept as explicit policy flags (bit-identical), not unified
  - `code-duplication-dee72312b` (`dup-be7f39dede8f`) [C++]: `R/EDI/src/fast_cpoisson_combined.cpp:87-124` vs `R/EDI/src/fast_cpoisson_combined.cpp:346-395` -- DONE (agent, uncommitted; verified by kernel swap): the Newton loop now calls `cpoisson_combined_score_info_cpp_impl()` (new `want_info` flag skips the info on the warm-start iteration)

- [x] TODO-194 (added 2026-11-19, owner request; from the code-duplication audit, decisions `code-duplication-d3fc63ea7`
  (`dup-eb9320e6bb57`, p-value path) and `code-duplication-d61e30e3a` (`dup-7bbada5cb607`, CI path); one drift on two
  paths, so one TODO): **PRW subsampling swallows timeouts that m-out-of-n honours.** The m-out-of-n CI, p-value and
  pivot paths (`inference_ext_m_out_of_n_bootstrap.R` ~L144-172, ~L212-239) call
  `private$check_bootstrap_replicate_deadline()` at setup, and the pivot reads the original estimate with
  `error = private$resampling_error_to_na` (re-throws control conditions). The PRW subsampling copies
  (`inference_ext_prw_subsampling.R` ~L136-163, ~L204-230) have no deadline check, and `subsampling_centered_pivot()`
  uses `error = function(e) NA_real_`, so a timeout / control condition raised while computing the original estimate
  is reported as `subsampling_original_estimate_unavailable` instead of aborting. Impact is limited (the shared
  `compute_resampling_draw_distribution()` still checks the deadline per replicate). Repro: set
  `options(EDI.ci_timeout_deadline)` in the past and compare the two CI calls. Fix: same deadline check and error
  handler as m-out-of-n; ideally merge the two setups into one helper. Test both paths.
  Done 2026-11-19 (agent, uncommitted): new shared private helper `resampling_centered_pivot_for_inference(family,
  target, ...)` (`inference_ext_exchangeable_resampling_units.R`, registered in `contracts_mixins.R`) replaces the four
  duplicated m-out-of-n / subsampling p-value and CI setups; subsampling's pivot, distribution and size evaluator now
  check the deadline and use `resampling_error_to_na`. Repro: a timeout inside `compute_estimate` was swallowed by
  subsampling (NA, `subsampling_original_estimate_unavailable`), now re-thrown. Bit-identical on 14 runs (7 classes,
  harden on/off). New `test-subsampling-honours-timeouts-like-m-out-of-n.R` (35); 19 resampling bulk files pass;
  migration baseline re-pinned to 343/346/354/327/340 (only this helper). Resolves code-duplication decisions
  `code-duplication-d3fc63ea7` and `code-duplication-d61e30e3a`. Follow-ups: v1.0.6-TODO-196.
- [ ] TODO-195 (added 2026-11-19, agent; found by the v1.0.6-TODO-186 agent): **Leftovers from the zero-augmented
  identification fix.** (1) The KK hurdle classes (`InferenceCountKKHurdlePoissonOneLik`, `...IVWC`,
  `inference_count_KK_cond_poisson.R`) use a separate path and were not checked for the same unidentified count-part
  treatment coefficient; add the guard if needed. (2) Owner decision (changes results): drop aliased count-part
  covariates on the positive rows (as `glm` would) so more small-n datasets stay estimable instead of NA. (3) When every
  positive count equals 1 the hurdle count MLE goes to -infinity; today only the SE is dropped
  (`zero_augmented_data_has_no_mle`) and the point estimate is still returned. (4) `fast_zero_augmented_poisson_cpp`
  with `y = NULL` segfaults instead of erroring (C++ input check).

- [x] TODO-196 (added 2026-11-19, agent; found by the v1.0.6-TODO-194 agent): **More resampling paths swallow
  timeouts, and the RR classes reject a list `b`/`m`.** (1) `compute_rr_resampling_pivot()`
  (`inference_incidence_gcomp_abstract.R` ~L404, `inference_incidence_KK_gcomp_abstract.R` ~L358) reads the original
  estimate with `error = function(e) NA_real_`, so a timeout inside `compute_estimate` is swallowed on both
  subsampling and m-out-of-n for the RR classes; use `resampling_error_to_na`. (2)
  `InferenceIncidGCompRiskRatio$compute_subsampling_confidence_interval(b = list(...))` fails with "b selection must
  be resolved before drawing." because the RR pivot passes the list straight to `resolve_resampling_size`; route it
  through `resampling_centered_pivot_for_inference()` or resolve the size first. (3) `select_optimal_resample_size()`
  (`inference_ext_minimum_volatility_selector.R` ~L39) turns any evaluator error, timeouts included, into a
  non-estimable candidate; re-throw control conditions. Coordinate with v1.0.6-TODO-191 / -192 (same RR files).
  Done 2026-11-19 (agent, uncommitted): (1) `compute_rr_resampling_pivot()` (both g-comp files) reads the estimate with
  `resampling_error_to_na`; (2) list `b`/`m` resolved via new private helper `select_resampling_size_from_spec()`
  (`inference_ext_exchangeable_resampling_units.R`, registered in `contracts_mixins.R`, also used by the generic setup);
  (3) `select_optimal_resample_size()` re-throws control conditions. 72-entry before/after check identical except the 8
  RR list-size calls (error -> finite). New `test-risk-ratio-resampling-honours-timeouts-and-list-sizes.R` (87); 46
  related files pass; migration baseline re-pinned to 344/347/355/328/341 (this helper only).
- [ ] TODO-197 (added 2026-11-19, agent, owner request; found by the Phase 0 algorithm-research bench run 44048167550,
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
  v1.1.0-TODO-197). Related: the open owner decision from the 2026-11-17 re-review to delete or fix the ZOIB wrapper.

- [ ] TODO-198 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65): **The published reference page
  of `InferenceIncidKKCondLogitGLMMOneLik` shows `Warning: number of rows of result is not a multiple of vector length
  (arg 1)`.** That is R's recycling warning from `cbind`/`rbind` or a matrix fill whose pieces have different lengths,
  raised somewhere in the example's fit (KK14, n = 10, two covariates, Bernoulli(0.5) responses; the clogit plus
  reservoir-logit path since v1.0.5-TODO-187). A silent recycling usually means a vector built with the wrong length
  (for example per-pair versus per-subject, or the reservoir rows dropped from one piece), so the estimate may be
  wrong, not just noisy. Find the call (`options(warn = 2)` on the example, then `traceback()`), fix the lengths, and
  add a test that the example's data fit without warnings and match a direct `survival::clogit` + `glm` fit. Check
  the IVWC sibling, which shares the abstract class.

- [ ] TODO-199 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65): **The `InferenceSuite`
  example's `\donttest` block takes about 138 s.** `R CMD check --as-cran` runs `\donttest` examples, and CRAN asks for
  examples that finish in seconds (the audit flags anything over 60 s). Shrink the example (fewer classes, smaller n,
  a subset of procedures, or no resampling), or move the full run to a vignette and keep a short call that shows the
  API. Done when the Rd audit reports the block under 60 s and the page still shows a meaningful result.

- [ ] TODO-200 (added 2026-11-19, agent, owner request; found by the Rd audit, PR #65, which runs each complete
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

- [ ] TODO-201 (added 2026-11-19, agent; found by the v1.0.6-TODO-193 R-refactor agent; owner decision, changes
  results): **`InferenceOrdinalPropOddsRegr` lacks `supports_fisher_information()`, unlike its probit sibling.** The
  code-duplication audit (`dup-4ca7ca9c9237`) flagged it as a drift. Adding it changes the testing types offered and the
  information source PropOdds uses, so it was left out of the bit-identical refactor. Decide whether PropOdds should
  support it (and check cauchit / cloglog for the same gap), then add it with a test and a NEWS line.

- [ ] TODO-202 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-193 R-refactor agent):
  **`test-inference-migration-harness.R` fails at its custom-randomization block (~L168).** `expect_silent` now catches
  `edi_perfect_predictor_warning` (v1.0.6-TODO-158) and an `edi_procedure_na_warning` (v1.0.6-TODO-136/-145/-165) from
  `InferenceRandCustom`. Check whether the fixture really has a perfect predictor and a silent-NA path (then the
  warnings are correct: muffle by class or change the fixture) or whether a warning fires where it should not (then fix
  the code).
- [ ] TODO-203 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-193 C++-refactor agent):
  **The three fixed-link ordinal kernels (cauchit, cloglog, probit) disagree on edge cases.** The v1.0.6-TODO-193 merge
  into `R/EDI/src/ordinal_fixed_link_internal.h` kept each difference as an explicit `FixedLinkFitSpec` policy flag so
  the refactor stayed bit-identical; this TODO is to decide one behavior and test it:
  - cloglog validates `warm_start_fisher_info` before the K < 2 early return; cauchit returns first.
  - probit has no K < 2 early return at all.
  - probit maps a non-finite or non-positive `ssq_b_j` to NaN; cauchit and cloglog pass it through.
  - cauchit's `_with_var` returns a list of NAs where probit returns an empty list.
  Needs the owner's build to verify (C++).
