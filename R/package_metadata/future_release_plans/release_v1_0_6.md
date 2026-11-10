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
| 170 | Stereotype accepted calibration rows predate the TODO-175/176/178 fixes; n = 1000 not re-run | Bounded re-run; closes or reopens stale accepted rows. |
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

- [ ] TODO-8 (moved 2026-11-10 from `release_v1_1_0.md → TODO-170`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceOrdinalStereotypeLogitRegr`: Stereotype LR / gradient / Wald accepted rows predate TODO-175/176/178: re-verify, especially n = 1000.**
  - Why: 16 accepted rows cite v1.0.5 TODO-175/176/178, which are now applied: n = 50 gradient / LR (size up to 0.135) and n = 1000 all four methods (size 0.165-0.21, yield 33-36%, 2026-10-31 run). The 2026-11-09 local re-run at n = 50 / 200 gives yield >= 99% and n = 50 sizes about 0.085, so these rows are stale; n = 1000 was not re-run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: re-run the fast tier at n = 50 / 200 / 1000 on the installed build (n = 1000 started 2026-11-10). Also covers wald ~. n = 50 prob_T 0.5: 2026-11-09 local run size 0.077, coverage 0.923, p = 1.5e-4; it fails the local K = 32 cutoff but not the nightly's, so it has no accepted row; if the nightly flags it, add one citing this TODO; if n = 1000 is still above nominal it is not a small-sample effect (look at the null refit's mode choice and the loading-boundary information).
  - Fix (candidates): depends on the re-run: prune rows that pass; for any large-n excess, fix the refit or information; score is v1.1 TODO-168.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.0.6 TODO-8`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.

- [ ] TODO-9 (moved 2026-11-10 from `release_v1_1_0.md → TODO-189`, owner approval of the v1.0.6 triage; originally added 2026-11-09, owner; follow-up of v1.0.5 TODO-179): **Boundary MLEs of the constrained binomial classes: what is left after Wald became NA for `InferenceIncidLogBinomial`.**
  - Done in v1.0.5 TODO-179 (2026-11-09, the "make Wald NA at the boundary (with LR suggested)" idea): `InferenceIncidLogBinomial` returns NA for the Wald p-value and CI when the full-data MLE has a linear predictor within 1e-8 + 1e-6 of 0, with warning class `edi_wald_mle_boundary_unavailable` and `procedure_failure_reason[["wald"]]`; `fit_null` got a strictly feasible last-resort start, so the LR interval at those fits no longer falls back to Wald (526 -> 75 of 1000 at n = 50). Study cell (Bernoulli, `~.`, p = 5, 1000 null reps): Wald NA in 68% (n = 50) / 66% (n = 200) of reps; Wald size over the rest 0.041 / 0.047, coverage 0.959 / 0.953.
  - (a) LR is still oversized at boundary MLEs: size 0.085 (n = 50) / 0.078 (n = 200) in boundary reps vs 0.048 / 0.044 interior; LR coverage 0.924 / 0.934. Candidates: parametric-bootstrap-calibrated LR (`compute_lik_ratio_bootstrap_*`, already supported) as the recommended boundary procedure, or a chi-bar-squared reference.
  - (b) 75 of 1000 LR CIs at n = 50 (7 at n = 200) still fall back to Wald: one null refit at a single delta fails (non-converged) while neighbouring deltas succeed. Overlaps TODO-165 (kernel boundary convergence). Either fix the kernel or let the root search step past one failed refit; and decide whether a Wald fallback under the LR label should itself be NA at a boundary MLE.
  - (c) `InferenceIncidBinomialIdentityRiskDiff` (identity link, bounds at mu = 0 and 1, same TODO-128 warning and `edi_binomial_bound_kkt_core()`) was NOT changed: its Wald path is the generic `StandardModelCache` one, and the identity-link boundary needs its own decision (two-sided bounds; `~1` boundary is a 0% or 100% arm, where the SE is already 0). Measure its boundary share and Wald size in the study cell first. `InferenceIncidRiskDiff` (unpooled Wald, v1.1 TODO-179) does not have this boundary.
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
