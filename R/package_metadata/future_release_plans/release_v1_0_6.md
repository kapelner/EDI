# Release Scope: v1.0.6

> **Scope (owner ruling 2026-11-23):** TODOs ticked before the 1.0.5 release commit (<to be filled at tag time>)
> shipped in 1.0.5; 1.0.6 is the open TODOs. The ticked TODOs keep their v1.0.6 numbers (about 1,400 references
> cite them). See `release_v1_0_5.md`, "Release cut (owner ruling 2026-11-23)".

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

- [x] TODO-4 (moved 2026-11-10 from `release_v1_1_0.md → TODO-162`, owner approval of the v1.0.6 triage; originally added 2026-10-27, owner decision at v1.0.5 TODO-162: defer, fix
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

  - Decided 2026-11-19 (owner): trailing partial permuted block merged into the previous block; see [DECISION-v1.0.6-TODO-4a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-4a).
  - Decided 2026-11-19 (owner): FixedBlocking: stratified JKn delete-one within strata (Wolter); see [DECISION-v1.0.6-TODO-4b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-4b).
  Agent started 2026-11-19.
  -- DONE (agent, 2026-11-19, uncommitted): `resolve_jackknife_unit("auto")` now returns `"permuted_block"` on
  `DesignSeqOneByOneSPBR` and `"observation_within_block"` on `DesignFixedBlocking` (both also accepted as explicit
  units; `"block"` still means leave-one-stratum-out). `get_block_ids()` is unchanged; the new private
  `jackknife_stratified_layout()` rebuilds the SPBR permuted blocks from the assignment record (stratum key as in
  `assign_wt()`, enrolment order, `block_size`; trailing partial block merged into the previous block of its
  stratum; a stratum with only a partial block is one unit), `jackknife_replicate_strata()` feeds the stratum of
  each replicate to `edi_jackknife_bias_variance()` (`inference_all_abstract_jackknife.R`), used by
  `compute_jackknife_summary()` and the risk-ratio `edi_rr_jackknife_log_summary()`. Formula: Wolter (2007) Sec. 4.5
  JKn, v = sum_h (n_h-1)/n_h sum_i (theta*_(h,i) - theta*_bar_h)^2, bias = sum_h (n_h-1)(theta*_bar_h - theta_hat),
  applied to theta* = theta_hat + r_h (theta_(h,i) - theta_hat), r_h = n_h (N-1)/(N (n_h-1)). DEVIATION FROM THE
  LITERAL DECISION, owner to confirm: Wolter's replicates reweight the rest of stratum h by n_h/(n_h-1); EDI's are
  unweighted subset refits, and (n_h-1)/n_h on those understates v by ~((n_h-1)/n_h)^2 (SPBR coverage 0.89-0.92);
  r_h is the first-order reweighted equivalent (v = ((N-1)/N)^2 sum_h n_h/(n_h-1) SS_h; bias = ordinary
  (N-1)(theta_bar - theta_hat) without singleton strata; one stratum = old formula). Singleton strata contribute 0.
  Min-units gate uses sum_h (n_h-1)+1. Unblocked designs bit-identical (14 design x class checks `identical()`).
  Coverage at beta 0 (250 reps, n = 148, 4 strata, own DGP; old = 1.0.5 leave-one-stratum-out): SPBR 0.82-0.86 ->
  0.92-0.96, FixedBlocking 0.80-0.90 -> 0.92-0.99. Tests: new `test-jackknife-stratified-units-spbr-and-fixed-blocking.R`;
  updated `test-count-poisson-stratified-jackknife-guard-few-strata.R` (fallback now tested on RandomBlockSize),
  `test-jackknife-unit-resolution-block-guard-and-cluster-ids-reference.R`, migration baseline (+2 owners), call-graph
  delta. Open: regenerate SPBR/FixedBlocking jackknife CSV rows and retire the TODO-162 baseline acceptances;
  DesignSeqOneByOneRandomBlockSize has the same stratum-unit problem (needs block ids recorded at assignment);
  BCa acceleration still uses the unstratified replicate spread.
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
  - Note (coordinator 2026-11-21): the rand warm-start chaining study found `InferencePropKKGLMM` fits depend on the
    start by up to 1e-2 (base-start worker 0.39643 vs observed 0.39727 on the original data); same symptom. The
    v1.0.6-TODO-169/170 shared convergence rule (`_helper_functions_core.h`, owner build pending) may already gate
    `converged` here; re-check this fixture after the build.

- [ ] TODO-11 (moved 2026-11-10 from `release_v1_1_0.md → TODO-192`, owner approval of the v1.0.6 triage; originally added 2026-11-10, owner; from v1.0.5 TODO-1's closing, `finished_features/v1_0_5/reusable_bootstrap.md` TODO-6): **Realistic proportion data for `tune_EDI_for_this_machine()`.**
  - Problem: the tuner's proportion fixture is noiseless. `inference_migration_complete_design()` (`local_machine_tuning_synthetic_fixtures.R`) sets `y = pmin(0.95, pmax(0.05, plogis(linpred)))` with no noise and no exact 0s or 1s (`edi_tuning_synthetic_experiment()` adds zero mass only for zero-inflated/hurdle count classes). Every proportion fit recovers the true coefficient 0.55 exactly, the precision parameter diverges, and jackknife summaries are degenerate (ZOIB: every warm-started fold returns 0.55, SE ~4e-9; NA at n = 50 and 1000). ZOIB's zero/one submodel is never exercised.
  - Effect on the tuner: warm vs cold timings are distorted. The 2026-11-10 ZOIB jackknife A/B (`scratch/v1_0_5_g2_outputs/zoib_jackknife_ab_2026-11-10/`) gave warm start ON 0.76 s vs OFF 10.6 s at n = 200 and 13.0 vs 248 s at n = 1000 (14-19x), likely inflated because cold fits chase a diverging precision. The correctness gate also cannot verify cells whose summary is NA. Applies to every proportion class the tuner times.
  - Fix: add real noise to the proportion response (e.g. a beta draw around `plogis(linpred)` with a fixed precision, seeded as now) and, for classes with a zero/one part (ZOIB), a small share of exact 0s and 1s, the way count classes get structural zeros. Keep the fixtures deterministic per seed. Check every other caller of `inference_migration_complete_design()` (migration goldens) before changing it, or add a separate tuning-only generator.
  - Done when: proportion fits on the tuning fixture give finite, non-degenerate jackknife summaries at n = 50, 200 and 1000; ZOIB's zero/one part is fitted; the ZOIB jackknife A/B is re-measured and recorded; affected golden tests pass or are deliberately updated.

- [x] TODO-12 (moved 2026-11-10 from `release_v1_1_0.md → TODO-71`, owner approval of the v1.0.6 triage; originally added 2026-10-22, owner decision `release_v1_0_5.md → G6 #14`):
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

  - Decided 2026-11-19 (owner): minimum 95% valid replicates, user-settable; see [DECISION-v1.0.6-TODO-12](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-12).
  Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted): new argument `min_fraction_usable_samples = 0.95` (checkmate number in [0, 1];
  0 turns it off) on `compute_bootstrap_two_sided_pval()`, `compute_bayesian_bootstrap_two_sided_pval()` and
  `compute_rand_bootstrap_two_sided_pval()`, mirroring `min_number_usable_samples` (the 5% CI cap is a calibration
  constant, not a runtime argument, so the argument follows the existing per-call minimum instead). Forwarded by the
  gcomp (incidence, KK incidence, proportion), Weibull and KM-diff overrides. With `na.rm = TRUE` and fewer than
  `ceiling(f * B)` valid replicates (studentized: finite estimate and SE) the p-value is NA with reason
  `bootstrap_` / `bayesian_bootstrap_` / `rand_bootstrap_too_few_valid_replicates_fraction` and one
  `edi_procedure_na_warning` (silent inside resampling). Checked after `min_number_usable_samples` (and, for the
  randomization bootstrap, after its max(10, 10%) floor), so those reasons are unchanged. The randomization-bootstrap
  CI search passes 0, so its intervals are unchanged. Not covered: m-out-of-n, subsampling and parametric/LR bootstrap
  p-values (no `na.rm`; they always drop non-finite draws subject to `min_number_usable_samples`), the BRT sequential
  Monte Carlo early-stopping path, and the zero-augmented count overrides (other agent's files; the 0.95 default
  applies there through the pinned base method, but the argument is not forwarded). Test:
  `tests/testthat/test-bootstrap-pval-min-valid-fraction.R`. Rd regeneration and the public-argument drift artifacts
  are pending.
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
  - Owner decision pending: [DECISION-v1.0.6-TODO-17](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-17) (the five design questions to settle before any code: first-look margin, p-value of a stopped unit, weighting, post-stop bias, confirmation replicates).
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
  - Accepted rows completed 2026-11-21 (coordinator, owner request): 2 confirmed score size cells had no row after wave 24 of campaign 2026-11-15-e36c7710; added citing this TODO, level = the worse of the screening and confirmation values + 3 SE.
- [x] TODO-30 (added 2026-11-16, agent, owner request; found while gating randomization warm-start chaining on
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
  - Scope added (owner, 2026-11-19, from v1.0.6-TODO-208 (3)): the bootstrap-randomization reusable worker. On plain
    Poisson data (no real excess zeros) the full-data zero part is saturated (zero intercept -234.6, treatment +121); the
    worker warm-starts every draw there, the zero-part gradient is ~0, so only the count part moves and beta stays near
    the plain-Poisson value, while the slow path (cold start) reaches a lower nll by 0.7-15.7. Worker vs slow path BRT
    differ by ~0.1 (conditional) / ~0.2 (marginal). Decided: fix candidate 1, cold-start when the zero part is
    saturated, applied to the reusable worker too. The full-data estimate itself depends on the start here (0.585 /
    0.546 / 0.508; separated zero part, v1.0.6-TODO-152). Repro: `/tmp/claude-1000/t208/probe.R`, `trace.R`, `full.R`.
  Done together with v1.0.6-TODO-152 (owner, 2026-11-19): one agent, one fix for the flat zero-inflation region.
  Done 2026-11-19 (agent, uncommitted; with v1.0.6-TODO-152, R only): fix candidate 1. New free helpers in
  `inference_count_zero_augmented_poisson_abstract.R` (no private methods, no registry change):
  `zero_augmented_warm_start_on_ridge()` drops a warm start when any subject's zero-part logit `|Xzi gamma| >= 10`
  (`ZERO_AUGMENTED_RIDGE_ETA_EDGE`; fitted zero probability < 4.5e-5 or > 1 - 4.5e-5), it cannot be evaluated, or it is
  a ZINB zero-inflation-off boundary fit; the fit is then cold-started exactly as a fresh fit. Applied in
  `fast_zero_augmented_poisson_cpp_guarded()` (new; ZIP and HurdlePoisson: full fit, randomization refit (so rand CI
  search), reusable bootstrap / BRT worker via the full fit, parametric-bootstrap full and null refits) and at the top of
  `fast_zinb_cpp_guarded()` (ZINB, same paths). The ZIP randomization refit also got the full fit's plain cold retry
  on non-convergence, so a replicate is the same computation as a fresh fit. Candidate 2 was not needed. Evidence: TODO-30
  repro, 30 permutations: ZIP max |rand - fresh| 0.84 -> 0 (with only the TODO-152 candidate and no gate: 0.034); ZINB
  0.64 (15/30 off despite the v1.1.0-TODO-217 guard) -> 0; HurdlePoisson already <= 2e-8. Bootstrap (B = 30) ZIP / ZINB /
  HurdlePoisson replicates equal fresh fits (0, already so before). TODO-208 repro: BRT worker vs slow path 0.038
  (conditional) / 0.060 (marginal) with the candidate only -> 0 for both. Non-ridge data (6 seeds x n = 80 / 200 x ZIP /
  ZINB / HurdlePoisson): estimate, SE, asymptotic CI, summary table, 20 rand and 20 bootstrap replicates `identical()`
  to the pre-change code. Rand timing unchanged (r = 300 ZIP 0.8-1.1 s either way). Jackknife is unsupported in all
  four classes (nothing to do). Out of scope, reported: `InferenceCountHurdleNegBin` and ZOIB conditional rand refits
  differ from fresh fits (up to 6e-3 / 9e-4) because they hold theta / the zero-one part and phi at the full-data
  values by design, not because of a ridge; the likelihood-test (LR / score / gradient CI) null refits still warm-start
  on the same data (TODO-169 keep-the-lower-nll guard; learning 2026-11-03). Test
  `test-zero-augmented-ridge-warm-start-and-zero-part-separation.R`. NEWS not edited (lines proposed to the owner).
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
- [x] TODO-45 (added 2026-11-17, agent, owner request; done 2026-11-23; found by the matching-on-the-fly article agent): **KK14's
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
  - Done 2026-11-23 (agent; nothing left to change). The fix is on HEAD (a32ab62c, `T_sq = ... / 2` in
    `design_seq_one_by_one_KK14.R`; the only caller of `compute_proportional_mahal_distances_cpp`). The 9 bulk files
    were already re-pinned in 271a7ea1 (2026-11-17): GEE parity est tolerance 1e-3 -> 5e-3, GEE weighted refit 2e-2
    -> 5e-2 (20-seed sweep), CLMM all-links cloglog at sigma_b = 1.2 2e-2 -> 5e-2, CLMM boundaries Cauchit 1e-6 ->
    1e-4, CLMM migration 5e-5 for every link, modified-Poisson SE 1e-6 -> 1e-5, plus the two seed/phi re-pins above;
    the introspection audit passes unchanged because the separated exact-Fisher row is now `nonest`
    (`exact_fisher_conditional_mle_infinite`, also 271a7ea1). Those loosened tolerances are where v1.0.6-TODO-47 and
    v1.0.6-TODO-48 start; they stay open for the which-side-is-wrong question. Run 2026-11-23 against the source
    (`load_all(compile = FALSE)`, NOT_CRAN, EDI_PREPUSH_NO_PARALLEL): all 9 pass (1554 expectations, 0 failures;
    the one skip is the introspection audit's source-tree check, path-dependent), as do the 11 bulk files re-pinned
    on 2026-11-17 and the 4 `tests/testthat` files above. The roxygen, `DesignSeqOneByOneKK14.Rd`, the
    matching-on-the-fly article and the NEWS bullet ("Changes that alter results" > Designs) all give
    T^2 = 1/2 d'S^-1 d against p(n-1)/(n-p) F_{p,t-p}(lambda), as the code does. The KK14 and KK21/KK21stepwise rows
    of the comprehensive and calibration baselines (and their cost files) regenerate in the 1.0.5 full run
    (v1.0.6-TODO-67); the 18 KK14 and 36 KK21 accepted calibration rows get re-reviewed there.
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
- [x] TODO-47 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **KK GEE
  weighted refit disagrees with its reference by 6%.** On the data the corrected KK14 threshold produces,
  `R/package_tests/testthat_bulk/test-kk-gee-weighted-refit-reference.R` gets -0.616 from EDI vs -0.581 from the
  reference. Also `test-kk-gee-parity.R`: EDI's GEE vs geepack differ by 3.2e-3 relative against a 1e-3
  tolerance, and 2-4e-3 is typical on other data, so that tolerance looks fitted to its old fixture. The old KK14
  fixture hid both. Find which side is wrong (working correlation, weights, convergence tolerance, or the
  reference call) before re-pinning either test; do not restore the old fixture with a smaller `lambda` to make
  them pass. Done when the two agree to a justified tolerance on several seeds.
  Done 2026-11-24 (owner request): neither side is wrong; the two solve the same estimating equation with different exchangeable-alpha moment estimators. Weighted fixture (`test-kk-gee-weighted-refit-reference.R`, seed 20260918): EDI beta_w -0.61639, alpha 0.02655, converged, |U(beta_EDI; alpha_EDI)| = 1.2e-9 with U = sum D' V^-1 W^1/2 r; geepack -0.58137, alpha 0.12252, |U(beta_geepack; alpha_geepack)| = 4.3e-5 (its tolerance) under the same U, |U(beta_geepack; alpha_EDI)| = 0.53. `geeglm(corstr = "fixed", zcor = alpha_EDI)` reproduces EDI's beta to 3.3e-8. The alphas: EDI is Liang-Zeger (sum w_ij r_i r_j / ((n_pairs - p) phi), phi = sum w r^2 / (N - p)); geepack applies no p correction (unweighted: num / (n_pairs sum r^2 / N) gives -0.058312 = geepack's -0.0583124; EDI -0.06087) and its weighted alpha is noisier (30 weight draws: mean -0.065 / -0.069, SD 0.027 / 0.058). Unweighted the same: EDI beta_w -0.64141, geepack -0.64052, geepack at alpha_EDI -0.64141. Tests: both files now also check geepack with alpha fixed at EDI's value at 1e-6 (5 weighted draws; 4 seeds x binomial/Poisson for the direct solver); the exchangeable-alpha comparisons keep 5e-2 (weighted) and 5e-3 (incidence wrapper), documented as the alpha convention. No code change, no NEWS.
- [x] TODO-48 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **KK
  ordinal CLMM cloglog link disagrees with `ordinal::clmm`.** On the new KK14 data,
  `R/package_tests/testthat_bulk/test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` gets 0.815 vs clmm's
  0.776 (and 0.259 vs 0.280) for the cloglog link; the other links agree. Related small gaps on the same data:
  `test-ordinal-kk-clmm-boundaries-coverage.R` (Cauchit weighted refit 3.8e-5 off) and
  `test-ordinal-kk-clmm-migration-golden.R` (Probit and Cloglog legacy vs migrated 1-3e-6 off in jackknife and
  randomization outputs, against 1e-7). Check the cloglog likelihood, gradient and the quadrature, and compare
  log-likelihoods at both optima to see which fit is better. Done when cloglog matches clmm on several seeds or
  the difference is explained (e.g. clmm stops at a worse optimum) and documented.
  - Decided 2026-11-24 (owner): (a) n_gh = 60 for KK CLMM; see [DECISION-v1.0.6-TODO-48](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-48).
  - Investigated 2026-11-24 (agent, owner request): EDI is the side that is off. On cloglog n = 60, sigma_b = 1.2, seeds 2 and 3 both fits are stationary for their own objective, but under the exact marginal likelihood (`integrate()`) clmm's parameters win (nll 72.0694 vs 72.1193; 61.7877 vs 61.8786): EDI's fixed 20-node non-adaptive Gauss-Hermite rule is inaccurate at sigma 2.1-2.6. With `n_gh = 60L` EDI lands on clmm's optimum (0.8146 -> 0.7752 vs 0.7755; 0.2590 -> 0.2799 vs 0.2797). The fix is R-side (the kernel takes `n_gh`) but changes every KK CLMM result, so it waits for the decision; the test comment that said neither fit had the better likelihood is corrected. The Cauchit weighted-refit (3.8e-5) and Probit/Cloglog migration-golden (1-3e-6) gaps were not re-examined.
  Done 2026-11-24 (DECISION (a)): `KK_CLMM_N_GH = 60L` (`inference_ordinal_KK_clmm_abstract.R`) is passed by every KK CLMM kernel call (observed fit, rand/bootstrap refits, Newton retry and SE refit, score-test null fit) and used by `clmm_score_residuals()`; the weighted refit already uses `ordinal::clmm` (adaptive) and is unchanged; `fast_ordinal_clmm.cpp` and `RcppExports.R` untouched (the R calls now pass `n_gh` explicitly). Cloglog n = 60, sigma_b = 1.2: treatment 0.8146 -> 0.7752 (clmm 0.7755) and 0.2590 -> 0.2799 (clmm 0.2797); exact-likelihood nll 72.1193 -> 72.0694 (clmm 72.0694) and 61.8786 -> 61.7879 (clmm 61.7877). Max |EDI - clmm| over the all-links grid (20 -> 60 nodes): logit 1.6e-3 -> 1.5e-5, probit 1.3e-3 -> 8.9e-6, cloglog 3.9e-2 -> 2.6e-4, cauchit 3.8e-3 -> 4.1e-3 (that cell is clmm's error: its exact nll 263.3381 is worse than EDI's 263.3136). Fit time over the 44 grid fits 6.2 s -> 16.2 s (2.6x). Tests: all-links tolerances 3e-3/5e-2 (cloglog) / 2e-2 (cauchit) -> 1e-3 / 1e-3 / 5e-3, and the cauchit "EDI better by > 1e-2" skip removed (no longer fires; skips stay only where clmm errors or is not stationary); migration golden 5e-5 -> 1e-5 (fixture mirrors n_gh = 60; it failed with the fixture at 20 nodes); `test-ordinal-kk-clmm-stationary-fit-kkt.R`'s Newton polish now uses the class's 60-node objective (at 20 nodes it reported the moved optimum as non-stationary, up to 6.6e-3). `test-ordinal-kk-clmm-boundaries-coverage.R`'s cauchit 1e-4 compares the clmm-based weighted refit, which n_gh does not touch, so it stays. 24 CLMM test files pass.
  - Status 2026-11-24 (agent, owner approved; cross-reference v1.1.0-TODO-265): the 60-node rule's cost (2.3-3x per fit) is cut by a coarse-to-fine kernel change in `fast_ordinal_clmm.cpp`: with `n_gh > 20` the L-BFGS multistart runs on 20 nodes and only the winner (chosen under the 60-node likelihood) is refit on 60 nodes, so the reported fit is still the 60-node optimum; a fit now costs 1.1-1.5x the 20-node fit. Same results as the 60-node HEAD code under D2 (estimate <= 1.2e-6 over 48 calibration data sets; randomization p identical); `test-ordinal-kk-clmm-matches-clmm-all-links-reference.R` (this TODO's cloglog cases) passes with the new kernel. Needs the owner's rebuild to be live.
- [x] TODO-49 (added 2026-11-17, agent, owner approved; surfaced by the v1.0.6-TODO-45 fixture sweep): **An
  inference reported as status 'ok' with a non-finite estimate.**
  `R/package_tests/testthat_bulk/test-design-inference-introspection-audit.R` ("no silently masked capability for
  KK/incidence") finds a KK/incidence row with status 'ok' and a non-finite estimate, most likely the exact Fisher
  log odds ratio = Inf on a separated 2x2 table. Find the row, then either report it with a non-ok status (and a
  reason) or define the estimate on separated tables; an 'ok' row must never carry Inf/NaN. Done when the audit
  test passes on the new data without changing the fixture.
  - Done 2026-11-24 (owner request; fixed in 271a7ea1, 2026-11-17): the row was `InferenceIncidExactFisher` on a
    separated table. `inference_indicidence_exact_fisher.R` now flags that fit non-estimable (reason
    `exact_fisher_conditional_mle_infinite`), so the suite reports it as status `nonest`, not 'ok' with an Inf
    estimate. `test-design-inference-introspection-audit.R` passes unchanged (checked 2026-11-23 by the
    v1.0.6-TODO-45 agent, `load_all(compile = FALSE)`, NOT_CRAN=true). The missing warning on that path is
    v1.0.6-TODO-306.
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
- [x] TODO-56 (added 2026-11-17, agent, owner request; found by the numerical-robustness review audit, merged as a
  skipped failing test): **KK GLMM null simulation swaps the two variance components.** `simulate_under_lik_null()`
  (`R/EDI/R/inference_continuous_KK_glmm.R:503`) reads the null fit as c(beta, log_sigma_b, log_sigma_e), but
  `fast_gaussian_lmm_cpp` returns c(beta, log_sigma_e, log_sigma_b) (`fast_gaussian_lmm.cpp:539-545`), so
  parametric-bootstrap LR null replicates use swapped SDs. Fix the indexing (by name if possible) and re-check the
  affected calibration rows. The failing test is
  `R/package_tests/testthat_bulk/test-contin-kk-glmm-null-simulation-variance-component-order.R` (skipped, citing this
  TODO); done when the fix lands and the skip is removed.
  Done 2026-11-21 with v1.0.6-TODO-291 (same bug): the indices are fixed and the skip is removed; the test passes.
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
  - Decided 2026-11-19 (owner): (b) milder clamp (y(n-1)+0.5)/n in both KK21 proportion speedups; see [DECISION-v1.0.6-TODO-60](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-60).
  Agent started 2026-11-19.
  Done 2026-11-19 (agent, uncommitted): new internal `kk21_speedup_proportion_logit()` (end of
  `design_seq_one_by_one_KK21.R`), used by both classes' speedup paths and their (unreachable) per-covariate
  fallbacks. When any response in the fit is 0 or 1, every response is compressed to (y(n - 1) + 0.5)/n, n = the
  number of responses in that regression (= rows of `X_all_with_y_scaled`, so S&V's sample size), then logit; logits
  now lie within +/-log(2n - 1) (n = 30: +/-4.08) instead of +/-36. All-interior fits keep the plain logit, so
  interior-response designs stay bit-identical (paired sims: 100/100 KK21 and 60/60 KK21stepwise allocations
  identical). Applying to all responses (not only the 0/1s) follows the "if y also assumes the extremes 0 and 1"
  convention and keeps the responses' order (a boundary-only shift would put a 0 above a 0.001). Paired sims (n = 100,
  4 covariates, beta = 1.5/1/0.5/0.25), share of the true linear predictor's variance left inside matched pairs, eps
  clamp -> compression: KK21 5% 0/1s 0.124 -> 0.099 (paired SE 0.003), ceiling ~20% 0.099 -> 0.097 (0.002), 30%
  inflated 0.206 -> 0.131 (0.009); KK21stepwise 0.124 -> 0.104, 0.106 -> 0.111, 0.215 -> 0.143. Roxygen (KK21
  Details + both `proportion_use_speedup` params + references) and REFERENCES.md [SmithsonVerkuilen2006] updated; Rd
  not regenerated. S&V's own text is closed access (not read); the formula was verified from Cribari-Neto & Zeileis
  (2010, JSS 34(2), p. 3) and the DOI on Crossref. Test `test-kk21-proportion-speedup-boundary-response-clamped.R`
  extended. NEWS line pending.
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
  - Decided 2026-11-19 (owner): randomization replicates never chain warm starts, for any class; see [DECISION-v1.0.6-TODO-61](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-61).
  - 2026-11-21 (agent, owner request): timing study on the slow / non-concave classes (KK GLMMs, CLMM family,
    Weibull frailty OneLik, stereotype logit, partial PO, ZOIB, KK cond Poisson; n = 150, r = 400, 1 core), see
    `R/package_metadata/audits/research_findings/2026-11-21-rand-warm-start-chaining-timing.md`. Chaining is at
    most 1.10x to 1.12x faster (PropKKGLMM, CondLogitGLMM; noise floor about ±15%) and bit-identical for seven
    classes. Nothing is material, so no decision is raised and the ruling stands. Side findings, not yet TODOs:
    `InferenceIncidKKCondLogitGLMMOneLik` loses 43 of 400 replicates to NA under the base start (7 chained, 0 cold;
    the open v1.0.6-TODO-35 question), and its rand-worker statistic differs from a fresh fit on the permuted data
    (max 0.44). PropKKGLMM start dependence is about 1e-2 (v1.0.6-TODO-10).
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
  - 2026-11-23 (coordinator, owner request): the 2026-11-22 run (45033002717, `9186e6a5`) lists 606 stale row groups,
    none cited by an id, because a citation must name each `results-freshness-m<hex>` id and those ids change
    whenever the class changes again.
  - Decided 2026-11-23 (owner): (c) leave the findings listed; the full 1.0.5 regeneration clears them; see [DECISION-v1.0.6-TODO-67](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-67).
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
- [x] TODO-73 (added 2026-11-17, agent, owner request; found by the cluster-and-factorial article agent):
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
  - Also reported by the docs-scenario audit: ds-clusters-blocking-44358267779-f1 (2026-11-18, unequal blocks error
    and the message names `equal_block_sizes`/`B_target`, which the class does not take).
  - Also reported by the docs-scenario audit: ds-factorial-44358267779-f6 (2026-11-18, on `DesignFixedBlocking`
    with `B_target = 2` given, the unequal-block error still says "strata_cols was named without B_target" and
    advises passing `B_target`; the help says the check fires when subjects are added, but it fires at
    assignment).
  - Checked 2026-11-20 on HEAD (`load_all(compile = FALSE)` and the installed build of 15:04): the blocked-cluster
    part is fixed. The clusters-blocking F1 repro (24 schools, districts of 106/131/184/216 pupils) and this
    entry's own repro assign without error, w is constant within every school, and each district gets half its
    schools treated (North 4/4, South 3/3, East 3/3, West 2/2). Left open: the factorial F6 repro still fails on
    HEAD. `DesignFixedBlocking(strata_cols = "B", B_target = 2)` with blocks of 100/98 errors at
    `assign_w_to_all_subjects()` with "Because strata_cols was named without B_target ... (or pass an explicit
    B_target)" (`R/EDI/R/design_blocking_abstract.R` ~L293-300 picks the advice from the constructor's formals,
    not from whether `B_target` was passed). Fix: choose the clause by whether `B_target` was given, drop the
    `B_target` advice when the strata are categorical (it cannot equalise 100/98), and make the help say the
    check fires at assignment (or move it to `add_all_subjects_to_experiment()`). Tick this entry when that is
    done.
  Done 2026-11-21 (agent), remaining part: the unequal-block error in `design_blocking_abstract.R` now picks its
  advice from whether `B_target` was given and whether every stratum is categorical (factor/character or a
  few-level integer): with `B_target = 2` and the factorial F6 blocks of 100/98 it says "B_target = 2 was given, but
  the strata are categorical, so their categories fix the block sizes and B_target cannot make them equal. Set
  equal_block_sizes = FALSE ..."; the "pass an explicit B_target" advice appears only for binned continuous strata.
  `DesignFixedBlocking`'s roxygen now says the check fires at `assign_w_to_all_subjects()` and that `B_target` cannot
  equalise categorical strata (Rd not regenerated). Test: new block in `test-blocked-cluster-unequal-block-sizes.R`
  (118 pass); the 17 `*blocking*` bulk files pass.
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
- [x] TODO-76 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
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
  - Decided 2026-11-18 (owner): KK with `n = NULL` matches once the model matrix exists; `n` not required; see [DECISION-v1.0.6-TODO-76](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-76).
  `t_0_pct` roxygen in KK14 / KK21 / KK21stepwise now says so (coordinator; not yet roxygenized).
  - Also reported by the docs-scenario audit: ds-sequential-designs-44358267779-f2 (2026-11-18, KK14/KK21 with
    `n = NULL` fail at the 5th assignment and leave t advanced with no w stored; the half-added subject is the
    missing rollback of v1.0.6-TODO-316).
  Verified 2026-11-21 (agent): the n = NULL fix is on HEAD (`test-sequential-design-without-fixed-n.R`, 50 pass);
  `DesignSeqOneByOneKK21$new(response_type = "continuous")` now assigns 12 subjects in a row, and the half-added
  subject on a failed assignment is rolled back by v1.0.6-TODO-316.
- [x] TODO-77 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
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
  - Also reported by the docs-scenario audit: ds-sequential-designs-44358267779-f1 (2026-11-18, with `n = NULL`
    every completeness check and every Inference constructor fails with "argument is of length zero").
  Verified already fixed on HEAD 2026-11-21 (agent): the repro above (Efron, n = NULL, 10 subjects) gives
  `check_experiment_completed()` TRUE and an OLS p-value 0.827; `test-sequential-design-without-fixed-n.R` 50 pass.
- [x] TODO-78 (added 2026-11-17, agent, owner request; found by the running-a-sequential-trial article agent):
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
  - Also reported by the docs-scenario audit: ds-sequential-designs-44358267779-f6 (2026-11-18, with `n = NULL` an
    out-of-order outcome for an enrolled subject is refused as "not yet arrived").
  Verified already fixed on HEAD 2026-11-21 (agent): with n = NULL, responses for subjects 10..1 in reverse order are
  accepted, and a response for subject 11 (not enrolled) is refused naming subject 10 as the latest;
  `test-sequential-design-without-fixed-n.R` 50 pass.
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
  ~L343, ~L837), not the custom class. A warning on dropped draws would need deduplication. The "at least 10" doc vs
  `max(10, 10% of r)` code mismatch is a roxygen fix.
  - Decided 2026-11-18 (owner): keep `na.rm`, documented as "drop non-finite draws"; see [DECISION-v1.0.6-TODO-82](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-82).
  Done (agent, uncommitted, docs
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
  - Decided 2026-11-19 (owner): (a) keep the removal of the always-NaN keys; no further change; see [DECISION-v1.0.6-TODO-87](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-87).
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
  realistic task end to end using the installed help and vignettes, and file what it trips over.
  Record each run's findings
  with release-prefixed TODOs, as here.
  - Decided 2026-11-18 (owner): a weekly CI job over every feature area, skipping unchanged areas, with a durable learnings store; see [DECISION-v1.0.6-TODO-98a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-98a).
  Being built 2026-11-18.
  Status 2026-11-18 (agent, uncommitted, never run on GitHub): built. `.github/workflows/audit-docs-scenarios.yml`
  (Saturdays 01:07 UTC + dispatch), driver `.github/scripts/docs_scenarios.py` (plan/render/collect/report; 19 tests),
  areas `.github/prompts/docs_scenario_areas.json` (17), prompt `.github/prompts/docs_scenario.md`; one line in
  `audit-status.yml`; runbook section 7. Skip: an area runs only if `scripts/significant_changes.py` reports a change in
  its paths since its last successful commit (docs/Rd changes count; comment-only code edits don't); at most 8 areas
  per run; no due area -> no EDI build. State on the `audit-notes` branch under `docs-scenarios/` (state.json,
  learnings/<area>.md read first and appended each run, findings.jsonl with filed/closed/dismissed status re-derived
  from the release file and DISMISSED_DECISIONS.md). Agent runs `claude -p` with no source checkout (installed EDI with
  help + vignettes, articles as text, wheel venv for Python). Output: one PR per run with new findings
  (`audit/docs-scenarios/<date>-run<id>`). Agent's estimate: $5-12 per area, ~4 h for an 8-area run. Open: first
  dispatch with `areas: factorial` to test CLI flags, timeouts and build time.
  - Decided 2026-11-18 (owner): weekly; Opus 5.5 at effort `high`; $30 per-area cap; unchanged areas re-run every 42 days; see [DECISION-v1.0.6-TODO-98b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-98b).
  Config: `.github/prompts/docs_scenario_areas.json` `defaults`; `rerun_unchanged_after_days`; `due_reason()` in
  `.github/scripts/docs_scenarios.py`. Run order within the 8-area cap: never-run areas, then areas with relevant
  changes, then the periodic re-runs (oldest first in each group), so changes are never pushed out by re-runs. Two
  tests added (21 pass).
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
  12 m 20 s wall on 2 workers.
  - Decided 2026-11-18 (owner): the ~12 min runtime is acceptable; no CI-size switch; see [DECISION-v1.0.6-TODO-99a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-99a).
  - Decided 2026-11-18 (owner): per-chunk opt-out for the deliberate `cluster-warning` chunk; see [DECISION-v1.0.6-TODO-99b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-99b).
  Done: chunk option `strict_expect_warning = TRUE` exempts that
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
  - Decided 2026-11-18 (owner): no new dependency; a private numpy-only `_checks.py`; see [DECISION-v1.0.6-TODO-101](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-101).
  Plan:
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
  sites today, all loose/fine; needs `# checkmate-loose: <why>` opt-outs before joining pre-push).
  Not fixed: `inference_survival_GLMM_weibull_frailty_loggamma.R:998` clamps `U2` to `1 - .Machine$double.xmin` (== 1,
  a no-op), so `U2 = 1` can give a survival time of 0 (rare).
  - Owner decision pending: [DECISION-v1.0.6-TODO-106](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-106) (add `# checkmate-loose` opt-outs and put the explicit-defaults check in the pre-push hook?).
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
  - Decided 2026-11-18 (owner): fix the RMST horizon across draws; see [DECISION-v1.0.6-TODO-115](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-115).
  Done (agent, uncommitted): with no user `tau`,
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
- [x] TODO-132 (added 2026-11-18, agent; found by the v1.0.6-TODO-128 agent; owner decision, changes results):
  **`InferenceSurvivalKKStratCoxPHIVWC`'s `estimate_only = TRUE` is a different estimator.** It weights the matched
  and reservoir halves by sample size, while the full call uses inverse-variance weights. The reusable worker, the
  jackknife and the slow bootstrap path all use `estimate_only = TRUE`, so their replicates are of a different
  estimator than the reported point estimate; the result also depends on call order (after a full fit, `estimate_only`
  returns the cached IVW value). Repro on the TODO-128 rare-covariate KK14 fixture: `compute_estimate()` -0.757 vs a
  fresh `compute_estimate(estimate_only = TRUE)` -4.653. Same class of bug as the 2026-11-07 Stereotype finding
  (estimate_only and full fits were different estimators). Fix: make `estimate_only` compute the same IVW combination
  (needs the halves' variances, so it is not "estimate only" in cost) or document and bootstrap the IVW estimator
  explicitly; check the other KK IVWC classes for the same split.
  - Decided 2026-11-19 (owner): option 1, `estimate_only = TRUE` computes the same IVW combination (deferred 2026-11-18 first); see [DECISION-v1.0.6-TODO-132](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-132).
  Check the other KK IVWC classes for the same split. Agent started 2026-11-19.
  Status 2026-11-19 (agent, uncommitted): DONE. Fixed three classes; StratCox and both Weibull frailty IVWC classes
  now run the full fit (both halves' variances) under `estimate_only`, which only picks the cache check. Repro:
  fresh `estimate_only` -4.653 -> -0.757 = `compute_estimate()`, both call orders. Weibull frailty Normal/Loggamma
  pooled 50/50 under `estimate_only` (max gap 1.84 on 12/12 fixtures) and left no SE, so a full call after it
  returned the 50/50 value with NA CI; fixed. `InferenceIncidKKCondLogitIVWC` agreed on the estimate but returned
  before caching the SE (NA CI after `estimate_only`, 11/12 fixtures); fixed. Full-call estimate, SE, CIs, p-values
  `identical()` to HEAD (40 fixtures). Worker = slow full fit on every checked draw (StratCox was off by up to 3.99).
  StratCox jackknife mean -4.40 -> -0.749. Slowdown: StratCox none measurable (B = 200 worker 1.25 s vs 1.17 s),
  frailty ~20% (B = 100 1.16 -> 1.41 s). Already agreed: MeanDiff, Wilcox, OLS, QuantileRegr (Contin/Prop),
  RobustRegr, HurdlePoisson, CondLogitGLMM, Newcombe, LWA Cox, RankRegr. Test
  `test-kk-ivwc-estimate-only-matches-full-estimate.R` (83); 5 bulk tests updated (3 skips removed, 2 pinned the
  50/50 fallback). Rd for StratCox `compute_estimate` pending roxygenize. NEWS line proposed, not added.
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
  - Decided 2026-11-18 (owner): an empty reservoir arm warns too; see [DECISION-v1.0.6-TODO-133](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-133).
  Done (coordinator, uncommitted): the warning fires
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
  - Decided 2026-11-18 (owner): BCa is also blocked below 5 deletion units; see [DECISION-v1.0.6-TODO-135](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-135).
  Done (agent, uncommitted): new
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
  `stratumhigh` and refit, and the reduced fit is reported (estimate 3.39, p 1.5e-4) with no message.
  - Decided 2026-11-18 (owner): warn, naming the dropped column(s) and why, in every harden-and-refit class; see [DECISION-v1.0.6-TODO-138](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-138).
  Once per object, never inside resampling.
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
  `test-rand-bootstrap-shifts-censoring-bounds-under-null.R` (17). NEWS added. Unchecked: under smoothed BRT the
  noise is added to y but not to y_L/y_R.
  - Decided 2026-11-18 (owner): allow the plain rand test/CI at nonzero delta under general censoring, bounds shifted; see [DECISION-v1.0.6-TODO-143](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-143).
  Follow-up 2026-11-18 (agent, uncommitted): the plain randomization test and CI now accept nonzero
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

- [x] TODO-147 (added 2026-11-18, agent, owner decision; from the docs-claims audit): **`InferenceIncidExactZhang`'s
  point estimate ignores the matched pairs on KK designs.** `compute_estimate()`
  (`R/EDI/R/inference_incidence_exact_zhang.R` ~L24) is `zhang_incid_treatment_estimate()`
  (`R/EDI/R/inference_helpers_zhang.R` ~L96): the Haldane-Anscombe log odds ratio of `n11`, `n10`, `n01`, `n00`.
  With a match structure, `zhang_get_exact_stats()` fills those from `compute_zhang_match_data_cpp()`, which counts
  the reservoir only, so the estimate is always 0 when every subject is matched. The docs
  (`inference_incidence_exact_zhang.R` ~L120, `man-roxygen/exact-zhang-compute-estimate.R`) say it uses the pooled
  2x2 table across all subjects.
  - Decided 2026-11-18 (owner): the estimate must use all subjects, as documented; see [DECISION-v1.0.6-TODO-147](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-147).
  Build the pooled table (each matched subject's own treatment and outcome, plus the reservoir) and use it in
  `compute_estimate()`; check whether `zhang_incid_mle_ci()` (the CI search bracket) and
  `zhang_ci_inside_point()` (`est_R`) should use the pooled or the reservoir table, since the exact p-value still
  combines the matched and reservoir parts separately. Test: on a KK design with every subject matched the estimate is
  not identically 0 and equals the pooled-table formula; with no matching it is unchanged. Add a NEWS entry under
  "Changes that alter results". (audit decision `docs-claims-d42892ef3`)

  DONE 2026-11-19 (agent, uncommitted): `compute_estimate()` now uses new `zhang_get_pooled_table()`
  (`inference_helpers_zhang.R`; all subjects, not cached). The CI search (`zhang_incid_mle_ci()` bracket,
  `zhang_ci_inside_point()`'s `est_R`) deliberately stays on the reservoir table: the inside point combines the
  reservoir and matched-pair estimates by inverse variance, so a pooled table would count the pairs twice, and the
  bracket is only a starting scale the bisection expands. Exact p-values and CIs are unchanged. Tests: new
  `test-zhang-exact-estimate-uses-pooled-table.R` (18); re-pinned the `matching` fixture estimate (0 -> 1.6946) in
  `test-exact-incidence-migration-baseline.R` and the pooled-table check in
  `test-zhang-exact-incidence-stats-pvalues-and-ci-search-reference.R`. NEWS line proposed to the owner, not added.

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
  `test-gcomp-ordinal-and-kk-weighted-refit-standard-errors.R` (37). NEWS added.
  The ordinal class's `get_standard_error()` "error" is not a bug: it is private there (the class composes `Wald`).
  - Decided 2026-11-18 (owner): keep `InferenceOrdinalGCompMeanDiff`'s `get_standard_error()` private; no change; see [DECISION-v1.0.6-TODO-149](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-149).
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
- [x] TODO-152 (added 2026-11-18, owner decision: keep for v1.0.6; split out of v1.0.6-TODO-142): **ZIP fits under
  separation in the zero-inflation part.** On the v1.0.6-TODO-142 bootstrap draw the zero-part coefficients diverge
  (the likelihood's supremum is at infinity; count_w tends to -0.147, pscl agrees, nll 77.069), the warm start stops
  at count_w -0.188 (nll 78.40) and the cold start at a genuine interior local maximum, count_w 0.163 (nll 82.56,
  gradient 7.7e-9); in 150 random full-data fits only such separation cases were off. Options: (a) an LBFGS candidate
  from pscl's start, keeping the lower nll (cheap; the multi-candidate pattern used elsewhere); (b) detect separation
  in the zero part and warn / mark the zero-part estimate nonestimable; (c) both. Respect the 2026-11-16 rule that
  replicates chain warm starts only when `likelihood_concave` is TRUE, and the ZIP ridge note in that learning. Repro
  scripts were in the TODO-142 agent's scratch (`zipstarts2.R`, `zipsweep.R`), which may be cleared.

  - Decided 2026-11-19 (owner): (c) both: LBFGS candidate from pscl's start and zero-part separation detection; see [DECISION-v1.0.6-TODO-152](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-152).
  Done together with v1.0.6-TODO-30 (same flat zero-inflation region).
  Done 2026-11-19 (agent, uncommitted; with v1.0.6-TODO-30, R only). (a) `fast_zero_augmented_poisson_cpp_guarded()`
  refits every ZIP fit (full, randomization, bootstrap, parametric bootstrap; not hurdle, whose likelihood factorizes into
  two concave parts) with L-BFGS from pscl::zeroinfl()'s default start, reimplemented with EDI's IRLS kernels
  (`zero_augmented_pscl_start()`: Poisson GLM of y on X, logistic GLM of 1(y == 0) on Xzi, unestimable coefficients 0;
  pscl not needed), and keeps it only when converged and its nll is lower by more than 1e-6, so a fit already at the
  maximum is returned bit for bit; it runs only when the primary fit converged (unconverged fits keep their existing
  recovery paths). (b) `zero_augmented_zero_part_separation()` + `edi_zero_augmented_flag_zero_part_separation()` after
  every accepted full-data fit (ZIP, ZINB, HurdlePoisson; never inside resampling): separated when a fitted zero
  probability is numerically 0 or 1 (`|Xzi gamma| >= qlogis(1 - 1e-8)`, ~18.4, the `edi_logistic_n_fitted_extreme()`
  rule), or some `|Xzi gamma| >= 10` and the zero-part block of the observed information is not PD or has min/max
  eigenvalue < 1e-5 (early stop on the ridge; interior maxima with one covariate-extreme subject stay >= ~3e-4), or a ZINB
  zero-inflation-off boundary fit (never for zero-free data, whose zero part is fixed at pi ~ 0 by design via
  `zero_inflation_fixed_args()`). Then the zero / hurdle rows of the summary table and `zero_coefficients` are NA,
  `cached_values$zero_part_nonestimable_reason = "zero_part_separated"`, and one warning of new class
  `edi_zero_part_separation_warning` (subclass of the existing `edi_logistic_separation_warning`; fields `n_extreme`,
  `n`, `max_abs_eta`, `component`, `link`); the count-part treatment estimate and its SE are kept (TODO-30 repro: 0.80592
  vs pscl 0.80589, SE 0.24738 vs pscl 0.24739). Evidence: 600-dataset sweep (n = 24-150; ZIP, plain Poisson, heavy
  inflation): estimate vs pscl agree to 1e-3 or flagged in 596 / 597; the one unflagged disagreement has a lower nll than
  pscl (130.4 vs 132.0; pscl stopped early). Before: 3 unflagged local-maximum cases, e.g. `set.seed(98)` n = 30 default
  start 1.138 (nll 32.147) vs pscl -0.4661 (nll 31.991), now -0.46608. Roxygen "Separated zero-inflation part" /
  "Separated hurdle part" paragraphs in ZIP, ZINB and HurdlePoisson (not roxygenized). Two existing tests now suppress
  the new warning on separated fixtures (`test-mixture-submodel-formulas.R`, `test-information-inverse-inference-typed-guards.R`).
  Open: `InferenceCountHurdleNegBin`'s hurdle part (own C++ path) has no separation warning; ZOIB's zero / one parts are
  observed indicators (factorized likelihood), not flagged.
  Owner note: the warning now fires on typical no-excess-zero data (ZIP's zero part saturates; ZINB's zero-inflation-off
  boundary fit), e.g. once in each of ~12 existing zero-augmented test files (all still pass) and on calibration DGPs
  without inflation; say if ZINB boundary fits should stay silent.
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
  - Decided 2026-11-18 (owner): the fix stands; no class-specific reason added; see [DECISION-v1.0.6-TODO-156](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-156).
  Fix uncommitted.

### Perfect predictors among the covariates (TODO-158..159)

A covariate (or set of covariates) that predicts the response exactly, given treatment, is almost always leakage in
a randomized experiment (the outcome or a post-treatment variable in `X`). Decided (owner, 2026-11-18): "perfect
predictor" means zero residual variance (to a relative tolerance) in the fit of `y` on `w` plus the covariates, not
`y` on the covariates alone: with `y = x + tau w` exactly and `tau != 0`, `x` alone does not fit perfectly but
`w + x` does.

- [x] TODO-158 (added 2026-11-18, owner request): **Detect perfect predictors in the inference covariates, drop them *(ticked by the TODO audit 2026-11-19: R/EDI/R/inference_all_abstract.R:205; R/EDI/R/inference_all_abstract.R:1643; R/EDI/R/inference_all_abstract.R:1596; R/EDI/R/inference_all_abstract.R:1677; R/EDI/R/inference_all_abstract.R:1775; a combination leak (y = x1 + x2 + tau w) drops both columns, never w; R/EDI/R/inference_count_hurdle.R:...)*
  and warn.**
  - Decided 2026-11-18 (owner): detect in the constructor and drop the columns with a warning (not: fit as specified with SE nonestimable); see [DECISION-v1.0.6-TODO-158a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-158a).
  Watch out: the check needs
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
  (not roxygenized). NEWS added. Untested: factor-dummy leaks in the component-formula filter.
  - Owner decision pending: [DECISION-v1.0.6-TODO-158](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-158) (confirm the three judgment calls: ties drop the union, the lazy re-run tracks the object's own `y`, covariate-ignoring classes skip the check).
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
  - Decided 2026-11-18 (owner): do both: +/-10 link-scale bound always; check RR on log(RR); see [DECISION-v1.0.6-TODO-160](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-160).
  Agent started 2026-11-18.
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
  - Also reported by the docs-scenario audit: ds-survival-censoring-44358267779-f1 (2026-11-18, on installed 1.0.4
    the default L-BFGS fit stopped short of the MLE: 0.4776586 vs survreg 0.4771847, n = 80 right-censored).
    Verified fixed on HEAD 2026-11-20 (`load_all(compile = FALSE)`): the finding's repro gives 0.47718467 for both,
    and the exported `fast_weibull_regression(optimization_alg = "lbfgs")` matches survreg to 8 digits on the
    same kind of data. Not yet pinned by a test on this repro or on the interval-censored article data
    (`ic-weibull`, 0.4430507).
  - Regression test added 2026-11-21 (agent): `test-weibull-unscaled-covariates-fit-converges.R` now runs the
    survival-censoring F1 repro and checks the default (L-BFGS) and Newton estimates against `survreg` to 1e-6.
    The interval-censored article data is still not pinned.

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
  - Decided 2026-11-19 (owner): both: (a) symmetric studentized interval on log RR and (b) document the undercoverage; see [DECISION-v1.0.6-TODO-168](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-168).
  Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted; roxygenize pending): new `type = "symmetric-percentile-t"` in
  `compute_bayesian_bootstrap_confidence_interval()` for `InferenceIncidGCompRiskRatio` and
  `InferenceIncidKKGCompRiskRatio` (shared free function `edi_rr_bayesian_bootstrap_symmetric_studentized_ci()` in
  `inference_incidence_gcomp_abstract.R`; RD classes reject it), plus a "Bayesian-bootstrap intervals" roxygen paragraph
  on both classes. Existing six types `identical()` before/after. Coverage at n = 60, 500 reps, B = 999: KK 0.936
  (studentized 0.892, percentile 0.945), plain 0.918 (studentized 0.900, percentile 0.920); misses balanced. 67/500 KK
  datasets still hit the v1.0.6-TODO-192 RR = 1 replicates (0.940 on the clean 433). Test:
  `test-gcomp-risk-ratio-bayesian-bootstrap-symmetric-log-studentized-ci.R` (35 expectations).
  Re-run after TODO-192 (2026-11-19, agent; no package change; scratch `t168c/` next to `t168/`): same design and
  seeds (n = 60, 500 reps, B = 999, sample-standardized truth; non-finite intervals counted as misses; "lo" = truth
  below the interval, "hi" = truth above; MCSE ~0.011). KK RR, new (old): symmetric-percentile-t 0.936 (0.932),
  lo 0.028 / hi 0.036; studentized 0.892 (0.888), lo 0.068 / hi 0.040; percentile 0.930 (0.936, or 0.945 among finite),
  lo 0.038 / hi 0.032; log wald 0.942, lo 0.024 / hi 0.034; log basic 0.964, lo 0.004 / hi 0.032. Plain RR is
  unchanged at the rate level: symmetric 0.918, studentized 0.900, percentile 0.920, log wald 0.946, log basic 0.958.
  KK RD: studentized 0.932, percentile 0.928, wald 0.920, basic 0.914. Every class and dataset now keeps all 999
  replicates: none at RR = 1, no NA SEs, no non-finite intervals (KK RR before: 67/500 datasets with RR = 1
  replicates, 2 non-finite symmetric/studentized and 5 non-finite percentile intervals). The old RR = 1 count
  understated the damage: it checked only the separate statistics draw, and the percentile draw was also poisoned on
  40 more datasets, with intervals up to (0.14, 58). On the 67 formerly poisoned datasets, symmetric coverage rose
  from 0.881 to 0.910 and studentized from 0.806 to 0.836. The 433 clean datasets give bit-identical intervals (0.940
  symmetric). Across all 107 affected datasets, symmetric covers 0.888 vs 0.949 on the other 393. So they are now valid
  but still cover a little less, probably because a fit diverges on the harder datasets (n = 67 MCSE ~0.035; not a
  remaining bug). The conclusions above stand: the raw studentized interval undercovers about 0.89-0.90 with
  one-sided misses, and symmetric log / percentile / log wald / log basic are near nominal for KK.
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
  -- Shared L-BFGS rule PATCHED, needs owner build (agent, 2026-11-20, uncommitted, with v1.0.6-TODO-170):
  `_helper_functions_core.h` now has one scale-aware rule, `newton_decrement()` / `newton_decrement_within_tol()`:
  converged iff lambda^2 = g' H^-1 g <= tol * (2 |negLL| + 0.1) (glm's relative deviance tolerance, same as the
  logistic and log-binomial fixes), computed on the column-equilibrated Hessian. `optimize_likelihood_lbfgs` no longer
  treats "stopped before the cap" as converged: a run the gradient test rejects is finished by
  `lbfgs_finish_with_newton_decrement()` (damped Newton on the functor's Hessian, expected information if the observed
  one is not PD, numeric Hessian for functors without one; never past maxit), and a run that ends non-finite retries the
  same finish from the start. The old verdict stands only where no Hessian is PD (boundary fits). Fits that already pass
  are bit-identical. `ProbitLbfgsObjective` got an analytic `hessian()` (Fisher information). Kernel-swap evidence
  (colon, treatment coefficient): `fast_neg_bin_cpp` lbfgs raw -0.2478 -> -0.21105 (glm.nb -0.21106), age x 1000 / + 1e5
  0 -> -0.21107, smart-cold-start x 1000 / + 1e5 NaN -> -0.21125; Poisson lbfgs x 1000 / + 1e5 0 -> -0.159529 (= glm);
  probit lbfgs x 1000 / + 1e5 -0.149 -> -0.311169 (glm -0.311180); `fast_beta_regression_cpp` raw -0.0539 and x 1000
  -0.0949 -> -0.0632 (betareg -0.06319); ZINB raw -0.2189 -> -0.2111 (pscl -0.2126). Ordinary fits (60 random designs per
  kernel/optimizer; 40 for beta and ZINB): unchanged except 3 NegBin-lbfgs, 3 beta and 9 ZINB fits that moved by
  <= 1.4e-3 toward the MLE (negLL never worse); no fit flipped to converged = FALSE. Cost: one Hessian (plus a few Newton
  steps) on L-BFGS exits whose gradient exceeds tol. Behavior change: an L-BFGS fit that hits maxit is now judged by the
  rule without extra steps (`fast_poisson_regression_cpp(optimization_alg = "lbfgs")` and probit lbfgs on raw colon still
  report converged = FALSE at the 100-iteration cap, as before). Still open: ZINB with a large-scale covariate in the
  zero-inflation design (x 1000: -0.042 vs pscl -0.2125; + 1e5: 0) -- eta_zi reaches -1e4, so the zi block of the
  Hessian is 0, no PD Hessian, and the old verdict stands; the other kernels in the list (ZIP/hurdle, ZOIB,
  dependent-censoring, GLMMs, Weibull frailty, CLMM) share the new wrapper but were not re-probed (hurdle NegBin cannot
  be kernel-swapped alone: it links the logistic internal). Python: `python/cpp` includes the same header, so the wheel
  picks this up on its next build. Test (72 expectations pass under the swap; 25 fail on the installed build):
  `R/package_tests/testthat_bulk/test-count-probit-kernels-scale-aware-convergence-colon.R`.
  -- Beta and ZINB reference checks added to that test (agent, 2026-11-21, test only): beta regression vs `betareg`
  on raw / x 1000 / + 1e5 (y = (pmin(nodes, 30) + 0.5) / 31, nodes dropped from X; absolute tolerance 5e-4, new gaps
  <= 8.4e-5, old 9.3e-3 / 3.2e-2) and ZINB vs `pscl::zeroinfl` on raw (Xzi = intercept, w, age; tolerance 3e-3, new
  gap 1.5e-3, old 6.3e-3). Kernel swap of `fast_beta_regression.cpp` + `fast_zinb.cpp`: 8/8 new expectations pass;
  4 fail on the installed build. Not covered: beta on `scale()`d X stops at -0.062202 (gap 9.9e-4) with or without the
  rule; ZINB raw still reports converged at negLL 1252.196, 2.14 above the MLE (1250.054, reached by pscl and by this
  kernel on scaled X), so its estimate is close to pscl by luck more than by convergence (belongs with v1.0.6-TODO-322).

- [ ] TODO-170 (added 2026-11-18, agent, owner request; found by the fitter-scaling probe that followed v1.0.6-TODO-163): **IRLS and Newton use an absolute gradient tolerance, so a correct fit on large-scale covariates is reported
  as not converged and the class drops covariates.** With age + 1e5, `fast_logistic_regression_cpp` and
  `fast_poisson_regression_cpp` (IRLS) reach the optimum but return `converged = FALSE`, and `fast_neg_bin_cpp` with
  Newton does the same at age x 1000; the classes then drop covariates and report a different model
  (`InferenceIncidLogRegr` drops 4, `InferenceIncidProbitRegr` 7, `InferenceIncidModifiedPoisson` 7,
  `InferenceIncidRiskDiff` all; LogRegr -0.541 vs glm -0.503). Make the convergence test scale-aware (relative
  gradient, or gradient on standardized columns, or relative change in coefficients and deviance as glm does). Repro data for all of these: `survival::colon`, `etype == 2`, `rx` in Obs/Lev+5FU, complete cases (n = 594), X = cbind(1, w, age, sex, obstruct, perfor, adhere, nodes, differ, extent, surg); variants: raw, `scale()`d, age x 1000, age + 1e5.
  -- Logistic IRLS part PATCHED, needs owner build (agent, 2026-11-19, uncommitted, with the v1.0.6-TODO-192 C++
  follow-up): when the gradient rule fails, `fast_logistic_regression.cpp` also declares convergence if the Newton
  decrement score' (X'WX)^-1 score <= tol * (deviance + 0.1) (glm's relative deviance tolerance; invariant to column
  scaling/shifts), except on saturated (separated) fits where some mu (1 - mu) < 1e-10. Coefficients are unchanged.
  Colon age + 1e5: `fast_logistic_regression_cpp` / `_weighted_cpp` converged FALSE -> TRUE, treatment -0.5030643 = glm.
  Still open: Poisson IRLS (`fast_poisson_regression_cpp`), NegBin Newton (`fast_neg_bin_cpp`), probit/modified-Poisson/
  risk-difference kernels, and the class-level covariate drops (re-run the four class repros after the build).
  -- Poisson IRLS, NegBin Newton and probit IRLS PATCHED, needs owner build (agent, 2026-11-20, uncommitted): the
  shared rule above (`newton_decrement_converged()`) is the fallback when the gradient test fails in
  `fast_poisson_regression.cpp` IRLS (not when some mu < 1e-10) and `fast_probit_regression.cpp` IRLS (not when some
  |eta| >= 8, the pnorm clamp), and on the step-size / stalled / capped exits of the shared `optimize_likelihood_newton`
  (`likelihood_newton_decrement_converged()`; NegBin Newton, Poisson Newton, every Newton user). Declaration only;
  coefficients unchanged. Kernel swap, colon: Poisson IRLS + 1e5 converged FALSE -> TRUE; Poisson Newton raw / x 1000
  FALSE -> TRUE and + 1e5 0 -> -0.159529; NegBin Newton x 1000 FALSE -> TRUE, + 1e5 0 -> -0.21107; probit IRLS FALSE ->
  TRUE on raw, scaled, x 1000 and + 1e5 (it missed the absolute 1e-8 at gradient 3e-7 even on raw data: 20 of 60 random
  ordinary probit fits were reported converged = FALSE, all TRUE now, coefficients identical). Modified Poisson uses the
  Poisson kernel; risk difference uses OLS, so nothing to change there. Class repros under the swap
  (`compute_estimate()`): InferenceCountNegBin x 1000 kept 0/8 covariates -> 8/8 (-0.21106); InferenceIncidProbitRegr,
  InferenceIncidModifiedPoisson and InferenceCountPoisson keep all covariates at x 1000. At age + 1e5 Probit (2/9 kept),
  ModifiedPoisson (5/9) and NegBin (0/8) still drop covariates although the kernels converge: that is the R-side
  `qr()` rank check in `fit_with_hardened_qr_column_dropping` / `fast_negbin_regression`, i.e. v1.0.6-TODO-171, not
  this item. Re-run the four class repros after the owner build.

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
  - Decided 2026-11-19 (owner): (a) keep the log-scale width cap of 5 for theta-free RR intervals; no code change; see [DECISION-v1.0.6-TODO-175](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-175).
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
  session's stream.
  - Decided 2026-11-18 (owner): seed each sequential assignment from (seed, subject index t), session RNG untouched; see [DECISION-v1.0.6-TODO-177](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-177).
  Changes seeded
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
- [x] TODO-180 (added 2026-11-19, agent, owner request; found by the weekly R-CMD-check on 4ce2b712, run 44358518303):
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
  - **Done 2026-11-24 (agent, tests only, no package change):** two causes. (1) The OS-leg failure at 4ce2b712 (`:73`,
    Weibull, ~1e-5) was warm-start chaining on the worker path vs a cold slow path; b508634e turned warm starts off in
    the test and v1.0.6-TODO-61 stopped chaining for every class. At 8d8c5f78 (run 44903905332) all 10 OS legs that ran
    the tests pass the three files (68/68 expectations of the rand file) and fail only on other tests (ordinal GLMM,
    stereotype logit, Gaussian LMM Hessian). (2) The valgrind and ASAN/UBSAN legs still fail them because those images install only hard
    dependencies: under interval censoring KMDiff, RestrictedMeanDiff, LogRank and GehanWilcox need `interval` and
    CoxPHRegr needs `icenReg`, so the slow path gave all-NA draws (`is.finite` / "differs from delta = 0" failures) and
    two single-class checks errored (same leg-specific cause, also in
    `test-rand-bootstrap-smoothing-refused-under-general-censoring.R:83`). Fix: new
    `R/EDI/tests/testthat/helper-survival-general-censoring-missing-packages.R` reads the missing package from the
    class's own "Package 'X' is required" error; the three loops skip those classes and report them as a named skip,
    and the two single-class checks use `skip_if_not_installed("interval")`. Evidence (`load_all(compile = FALSE)`,
    NOT_CRAN): with `interval` mocked absent, before 16 failures/errors across the four files, the CI valgrind/ASAN set
    minus the two CoxPH ones (CI: 18); with `interval` and `icenReg` mocked absent, after 0 failed, 5 tests skipped by
    name, Weibull still compared; with both installed 915 expectations, 0 failed, 0 skipped, before and after.
- [x] TODO-181 (added 2026-11-19, agent, owner request; found by the weekly R-CMD-check on 4ce2b712, sanitizer legs):
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
  - **Done 2026-11-21 (agent):** the valgrind and ASAN/UBSAN legs install only hard dependencies, so quantreg,
    multgee / geepack and aftgee are missing (run 44358518303). Four loops failed (na.R:113,163; nonscalar-nonfinite.R:116,148).
    New `R/EDI/tests/testthat/helper-inference-fixture-missing-packages.R` reads the missing package from the class's own
    "Package 'X' is required" error; those classes are reported as a named skip, and a class with no fixture while its
    packages are installed still fails. Verified normally (0 failed, 0 skipped) and with the packages mocked absent (0
    failed, CI's 8 classes skipped). The helper moves to the registry under v1.0.6-TODO-335.
- [x] TODO-182 (added 2026-11-19, agent, owner request; found by the nightly run 44358510753 on 4ce2b712):
  **The nightly silent-NA gate fails for `InferenceAllSimpleAverageDiff$compute_bootstrap_confidence_interval`.**
  On the smoke fixtures the same BCa-boundary NA comes with a warning in some calls and silently in others (5
  continuous cases, 1 incidence), so the `silent_na_output` hard gate fails. Reproduced by re-running the gate on
  4ce2b712 with the run's artifact CSVs. Suspected cause: a warn-once flag or a cache hit that returns the cached NA
  without re-raising the warning (not confirmed). Make every NA that this method returns come with its warning (or a
  `procedure_failure_reason`), and add a test that calls it twice on the same object and expects the warning both
  times.
  - **Done 2026-11-21 (agent):** already fixed by v1.0.6-TODO-162 (3dabce47). At 4ce2b712 `ci_bca()` warned only when
    every draw was finite; with n = 8 a resample often has no treated or no control subject, so the NA was silent. Not
    warn-once or a cache hit (the gate builds a fresh object per case). Re-running the failing cases with the old
    `ci_bca` gave 6 silent NAs, current code 0. Added
    `R/package_tests/testthat_bulk/test-bootstrap-bca-ci-na-explained-on-every-repeat-call.R`: the non-finite-draw NA
    warns on both calls; the all-finite boundary NA warns once per object and then keeps its recorded reason (the
    documented warn-once policy, unchanged).

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
- [x] TODO-185 (added 2026-11-19, agent; found by the v1.0.6-TODO-165 agent): **Two leftovers from the silent-NA work.**
  (1) The Bayesian-bootstrap p-value's normal-approximation branch still returns a silent NA for
  `bayesian_bootstrap_standard_error_unavailable`; same one-line `edi_warn_procedure_na()` fix. (2) Computing the
  null draws resets `private$active_resampling_operation` to NULL instead of restoring the previous value, so a flag set
  by an outer resampling call is lost after an inner one; check whether any outer operation then warns where it
  should be silent, and restore the previous value if so.
  Done 2026-11-19 (agent, uncommitted): (1) the `type = "wald"` branch now warns `bayesian_bootstrap_standard_error_unavailable`
  (`edi_procedure_na_warning`, silent while resampling); value unchanged. (2) Real but latent: all 16 entry points that
  set the flag (rand / rand-bootstrap null draws, nonparametric / Bayesian bootstrap and statistics, jackknives,
  m-out-of-n, subsampling, the 5 parametric-bootstrap methods, Bartlett MC factor) now restore the caller's value on
  exit, as `ci_calibrated_bootstrap()` already did (v1.0.6-TODO-142). No shipped caller warned wrongly (nested calls
  return right after, or warn nothing after the inner call); the flag is copied to duplicates, so a nested call on one
  now stays silent. Test `test-bayesian-wald-pval-se-na-warns-and-nested-resampling-restores-operation.R`.

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
- [x] TODO-187 (added 2026-11-19, agent; found by the v1.0.6-TODO-183 agent; owner decision, changes results):
  **`DesignSeqOneByOneiBCRD` with `n = NULL` has the wrong randomization distribution.** With no planned `n`,
  `assign_wt()` falls back to a Bernoulli coin, but the redraw still calls `generate_permutations_ibcrd_cpp(t)`, which
  forces exact balance at `t`: enroll 21 subjects, `colSums(draw_ws_according_to_design(500))` is always 11. Likely fix:
  when `private$n` is NULL, redraw with `generate_permutations_bernoulli_cpp(t, r, prob_T)`. Repro: the TODO-183
  agent's `$TMPDIR/t183/ibcrd_nulln.R`. Related: v1.0.6-TODO-76 (`n = NULL` behaviour of sequential designs).

  - Decided 2026-11-19 (owner): disallow `n = NULL` for `DesignSeqOneByOneiBCRD` (breaking); see [DECISION-v1.0.6-TODO-187](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-187).
  Agent started 2026-11-19.
  Done 2026-11-19 (agent, uncommitted): the constructor stops on `n = NULL` ("DesignSeqOneByOneiBCRD needs n: ...
  use DesignSeqOneByOneBernoulli when n is unknown"), checked even with `edi.run_asserts` off, then
  `checkmate::assertCount(n, positive = TRUE)`; the Bernoulli branch in `assign_wt()` is gone (the redraw had no
  n-NULL branch). Roxygen: "No target n" paragraph replaced by "n is required", `@param n` / method docs updated (not
  roxygenized). With n, assignments and redraws are bit-identical to before (3 seeds, `identical()` on w and draws).
  No caller built iBCRD with n = NULL (simulations framework, calibration, comprehensive tests, data-shape matrix,
  benchmarks, vignettes and all tests pass n); no capability table advertised n = NULL. running-a-sequential-trial.Rmd
  table row now says `round(n * prob_T)` and "requires n". New `test-seq-ibcrd-requires-n.R` (17); 14 related
  design/sequential test files pass. Found, not fixed: when `n * prob_T` ends in .5, `assign_wt()` uses R's
  `round()` (half to even) but `generate_permutations_ibcrd_cpp()` uses `std::round` (half away), so e.g. n = 21,
  prob_T = 0.5 realizes 10 treated while every redraw has 11 (wrong randomization distribution for half of the odd n
  at the default prob_T); needs its own TODO and an owner decision on which rounding wins.
- [x] TODO-188 (added 2026-11-19, agent; found by the v1.0.6-TODO-87 agent; needs a wheel rebuild): **Python
  `fast_neg_bin` returns `neg_loglik = nan` and an empty `mu`.** The NB internal stores the log-likelihood in
  `res.sigma2_hat` (R's `fast_neg_bin_with_var_cpp` returns `logLik = res.sigma2_hat`), but
  `python/cpp/bindings_count.cpp` returns `res.neg_ll`, which is never set; `mu` comes back with shape (0,). Fix in the
  binding (e.g. `out["neg_loglik"] = std::isfinite(res.neg_ll) ? res.neg_ll : -res.sigma2_hat;`, and fill `mu`), add
  a test against R, rebuild the wheel.
  Done 2026-11-20 (agent, uncommitted; PATCHED, needs owner wheel rebuild): `python/cpp/bindings_count.cpp`'s
  `fast_neg_bin` now returns `neg_loglik = res.neg_ll` if finite, else `-res.sigma2_hat` (= -R's `$logLik`, the full
  weighted NB log-likelihood, constants included), and `mu = exp(X b)` when the kernel leaves it empty (R returns no
  fitted means); both are filled under `estimate_only = TRUE` too. No `R/EDI/src` change. The other count bindings
  do not have the pattern: ZINB / ZAP go through `likelihood_fit_result_to_dict` (`fit.value`); hurdle NB, truncated
  NB and cpoisson return the shared `ResultMap`; Poisson sets `neg_ll` / `mu` itself and leaves them NaN / empty
  only under `estimate_only`, exactly as R's `fast_poisson_regression_cpp` does. Three R-pinned tests added to
  `python/tests/test_fast_neg_bin.py` (default, smart start, estimate_only, weighted); they fail on the current
  wheel (NaN) and the expected values equal the NB2 NLL recomputed in Python from the current wheel's `b` and
  `theta` to all 15 digits. Not fixed here: `fast_beta_regression` (another binding file) has the same NaN
  `neg_loglik` note in `python/tests/test_fast_beta_regression.py`.

- [x] TODO-189 (added 2026-11-19, agent; found by the v1.0.6-TODO-184 agent): **Randomization statistic stays
  conditional under `marginal_mean_diff` in other classes.** Marginal estimate vs randomization statistic:
  `InferencePropBetaRegr` 0.170 vs 0.718, `InferenceCountPoisson` / `QuasiPoisson` 0.773 vs 0.309,
  `InferenceCountHurdlePoisson` 0.751 vs 0.204, `InferenceCountZeroInflatedPoisson` 0.755 vs 0.229,
  `InferenceIncidLogRegr` 0.160 vs 0.667 (`InferenceIncidBinomialIdentityRiskDiff` is fine). Their rand p-values are
  valid sharp-null tests but don't match the estimate, and their BRT may compare a conditional observed statistic with
  marginal null draws (as ZOIB did). Apply the TODO-184 pattern per class (marginal functional in
  `compute_treatment_estimate_during_randomization_inference`, worker and slow path agree), and make
  `get_effective_capabilities()` estimand-aware. Repro: the TODO-184 agent's `t184/others.R` in
  /tmp/claude-1000/-home-kapelner-workspace-EDI/354c53b6-c792-4138-93ba-8154526e6c02/scratchpad/.
  Done 2026-11-19 (agent, uncommitted): under a marginal estimand (`marginal_mean_diff`, and `marginal_ratio` where
  supported) the six classes' randomization statistic returns the g-computed functional at the refit coefficients
  (new helper `edi_rand_statistic_marginal_point()`); Beta refits phi under marginal so it matches the worker; the
  ZIP/hurdle glmmTMB path (`use_rcpp = FALSE`) returns NA there. It was worse than reported: the reused worker
  already returned the marginal value, so the plain rand test mixed a conditional observed statistic with marginal
  draws (LogRegr rand p 0.02 on the worker path vs 0.525 on the slow path; Poisson 0.14 vs 0.02). Now statistic =
  estimate, BRT worker vs slow path <= 2e-4 (was 0.13-1.1), rand p identical on both paths. `$capabilities()` /
  `get_effective_capabilities(live_obj)` drop `randomization_ci` / `randomization_bootstrap_ci` under a non-conditional
  estimand. Default estimand bit-identical (`identical()` on estimate, statistic, BRT draws both paths, rand / BRT
  p-values, rand CI, capabilities; 6 classes x 2 seeds). Null size under marginal (200 datasets, n = 80, rand / BRT at
  0.05): Beta 5.5 / 5.5%, Poisson and QuasiPoisson 7.0 / 6.5%, Hurdle 6.5 / 7.0%, ZIP 5.0 / 7.5%, LogRegr 4.5 / 6.0%.
  New `test-marginal-estimand-randomization-statistic-glm-classes.R` (45). Left: ZIP worker vs slow path differ by
  ~0.1 even under the conditional estimand on plain Poisson data (weakly identified inflation part; agree to 1e-4 with
  real excess zeros), and `InferenceIncidBinomialIdentityRiskDiff` rand p differs between worker and slow path under
  the conditional estimand (1.000 vs 0.586 on the repro); neither is caused by this change.

- [x] TODO-190 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-184 agent): **`test-zoib-jackknife-reusable-worker-migration-golden.R`
  fails 6 expectations** (`beta_x` missing from the worker's columns, L126; the jackknife extreme-summary NA no longer
  produced, L262-267). The test sets no estimand and uses no randomization path; suspected cause is another uncommitted
  change (v1.0.6-TODO-158 perfect-predictor column handling, or -167 / -175). Bisect against `git show HEAD:` copies
  (no `git stash`: shared checkout), then fix the test if the new behaviour is intended or the code if it is a
  regression.
  DONE 2026-11-19 (agent, uncommitted): cause is v1.0.6-TODO-158 (intended): both fixtures had noise-free responses,
  so `beta_x` and the tuning fixture's `x, z` are exact predictors of logit(y) and are dropped in the constructor
  (stubbing `edi_find_perfect_predictors` restores all 6 passes). Test fixed, no code change: noise added to the
  rank-fallback fixture's `y`; the tuning-seed test now expects the `x, z` drop and finite, route-identical summaries
  (the NA guard stays covered by the synthetic test); the futile-refit test stubs the detector to keep its 8 failed
  fits, plus a non-vacuity check (`legacy$calls > 51`).

- [x] TODO-191 (added 2026-11-19, agent; found by the v1.0.6-TODO-179 agent; owner decision on the fix): **Risk-ratio
  subsampling and m-out-of-n p-values almost never reject.** Null size at n = 80 (200 datasets):
  `InferenceIncidGCompRiskRatio` subsampling 0.005, m-out-of-n 0.000 (`InferenceIncidKKGCompRiskRatio` 0.015 / 0.000;
  the RD sibling 0.065 / 0.070). With the default b = 21 of 80, subsamples with a zero-event arm or near separation
  give log RR ~ +/-20, so the pivot sqrt(b)(log RR* - log RR_hat) in `compute_rr_resampling_pivot()`
  (`inference_incidence_gcomp_abstract.R` ~L403) spans ~+/-98 and nearly every p-value is large; the matching CIs are
  very wide. Options: larger default b / m for ratio estimands, drop degenerate subsamples, or a studentized pivot.
  Repro: `/tmp/claude-1000/t179/dbg.R` (seed 1005).
  Investigated 2026-11-19 (agent; no code changed; write-up with literature and bibliography:
  `R/package_metadata/audits/research_findings/2026-11-19-v1_0_6-TODO-191-rr-subsampling.md`, scripts and results in
  `/tmp/claude-1000/t191_rr/`). Cause: the degenerate subsamples (an arm with no events, or a separated fit) are
  finite (log RR* ~ +/-20 after the IRLS cap), so `compute_rr_resampling_pivot()` (now in `helper_gcomp.R`) keeps
  them, and they land on the same side as `t_obs` (79 % of them), because a dataset with an extreme log RR_hat has
  few events in one arm. If a fraction `a` of the draws are such atoms, `p >= 2a`; in the null datasets where Wald
  rejects, `2a` had a median of ~0.09, so the p-value never drops below 0.05. Away from the tails the p-values match
  Wald (correlation 0.975). Literature: no assumption of PRW's theorem (Politis, Romano and Wolf 2001, Thm 2.1:
  weak convergence to a continuous limit, b -> inf, b/n -> 0, tau_b/tau_n -> 0) is violated. Subsampling estimates
  J_b, the law at sample size b, and at b = 21 that law still puts 1-3 % of its mass at +/-inf. That is the "b too
  small" explanation, not the missing moments, the rate or the centering. Each arm needs about 6 expected events per
  subsample (b >~ (2/p) log(2/eps)), which b = n^0.7 ignores and the b <= n/2 cap cannot reach for p <= 0.2 at
  n = 80. m-out-of-n (BGvZ 1997, Bickel-Sakov 2008) is a remedy for bootstrap failure; for this smooth estimator the
  n-bootstrap works and their rule picks m/n -> 1. Null size, 200 datasets: at n = 80, dropping degenerate draws
  gives subsampling 0.040 and m-out-of-n 0.035 (threshold-insensitive); Firth fits in subsamples give 0.050 / 0.015;
  b = n/2 gives 0.090 (plain, anti-conservative through the (1 - b/n) factor) or 0.020 (with sqrt(b/(1 - b/n)));
  studentized gives 0.08-0.12 (anti-conservative, Hauck-Donner). At n = 200 (b = 40, ~6.5 events per arm) the atoms
  vanish and the current subsampling test is 0.025 (Wald 0.040), but m-out-of-n is still 0.010. Recommended fix
  (owner decision): treat a degenerate subsample (an arm with zero or all events, or a non-converged/separated fit)
  as unusable in `compute_rr_resampling_pivot()`, count it, and return NA with a recorded reason when the dropped
  fraction exceeds a cap (0.05 or 0.10). Firth subsample fits are a later option. Do not use a studentized pivot or
  just raise the default b. Document that the ordinary bootstrap is the better choice for RR. Check the same
  mechanism in the OR, KK RR, rate-ratio and hazard-ratio subsampling paths (not verified).
  Closed 2026-11-20 (coordinator): every item listed as still open moved to v1.0.6-TODO-230 and was done there (cap 0.8, other ratio paths, KK RR size via the symmetric p-value, debug path).

  - Decided 2026-11-19 (owner): drop degenerate subsamples; NA above 5% (cap later 0.8, v1.0.6-TODO-230); Firth deferred; see [DECISION-v1.0.6-TODO-191](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-191).
  Agent started 2026-11-19.
  -- DONE (agent, 2026-11-19, uncommitted): a draw is *degenerate* when (i) an arm has no events or only events
  (or no subjects), (ii) the accepted logistic fit reports `converged = FALSE`, or (iii) some fitted probability is
  numerically 0 or 1 (`edi_logistic_n_fitted_extreme() > 0`, the v1.0.6-TODO-109 separation criterion; not a log RR
  magnitude threshold). New `gcomp_bootstrap_worker_estimate()` (`helper_gcomp.R`, the `compute_bootstrap_worker_estimate`
  of both `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio`) returns `NaN` for such a draw only while
  `active_resampling_operation` is `"subsampling"` or `"m_out_of_n_boot"` and the estimand is RR; the flags come from
  `gcomp_record_fit_diagnostics()` in both `shared()`s (`gcomp_fit_logistic_with_sandwich()` now returns `converged`).
  `compute_rr_resampling_pivot()` counts NaN (degenerate) and NA (failed) draws as unusable; below
  `min_fraction_usable_samples` (same name/semantics as v1.0.6-TODO-12: minimum usable fraction, default 0.95,
  user-settable on the four public subsampling / m-out-of-n methods, RR only, RD ignores it) the p-value / CI is NA with
  reason `subsampling_too_few_usable_draws_fraction` / `m_out_of_n_too_few_usable_draws_fraction` and one
  `edi_procedure_na_warning`. Roxygen: class-level "Subsampling and m-out-of-n" paragraph in both RR classes, `@param` in
  the four `gcomp-*` templates (Rd not regenerated). Verification (n = 80, 200 null datasets, B = 199, 2 cores; scripts
  `$TMPDIR/t191/size.R`, `anal.R`): RD and KK RD bit-identical (identical() on all outputs), RR outputs bit-identical on
  every dataset with no degenerate draw, and non-degenerate draws identical everywhere. Null size, non-KK RR:
  subsampling 0.005 -> 0.040 and m-out-of-n 0.000 -> 0.030 with degenerate draws dropped and no cap (matches the
  findings), **but with the 0.95 cap** 9 % (subsampling) / 29 % (m-out-of-n) of datasets are NA, including 7/11 and
  9/11 of the Wald-rejecting ones (degenerate draws concentrate where log RR_hat is extreme), so size among non-NA is
  0.016 / 0.000. Cap 0.90: NA 2 % / 5 %, size 0.031 / 0.011; 0.80: no NA, 0.040 / 0.030. KK RR (degenerate fraction
  only 0.3 % / 0.9 %): 0.010 -> 0.015 and 0.000 -> 0.010, NA 0.5 % / 2.5 %; its low size is mostly not atoms (open).
  **Owner call needed on the default cap** (0.95 kept as decided). Other ratio paths share the mechanism (generic
  pivot keeps finite atoms; `|est* - est| > 5` on the log scale, 15 null datasets, n = 80): `InferenceIncidLogRegr`
  log OR 2.8 % / 4.7 % of draws, `InferenceIncidModifiedPoisson` 2.0 % / 3.0 %, `InferenceCountPoisson` 0.5 % / 1.6 %,
  `InferenceIncidKKGEE` 0.5 % / 1.4 %; `InferenceIncidLogBinomial` returns NA instead (2-3 %), `InferenceSurvivalCoxPHRegr`
  ~0 at 60 % events; not fixed. Test: `tests/testthat/test-gcomp-risk-ratio-subsampling-degenerate-draws.R`.
  REOPENED (owner, 2026-11-19): keep this TODO open. For now the code stays as shipped: degenerate draws are dropped
  and the result is `NA` (with the recorded reason and one warning) below the 0.95 default. Documented as provisional
  in the RR classes' "Subsampling and m-out-of-n" paragraph, the four `gcomp-*` `@param` templates and NEWS (Rd not
  regenerated). Still open: the default cap (0.95 vs 0.90 / 0.80, numbers above), the KK RR low size, and the other
  ratio paths listed above. Small-n tests hit the NA: the pre-push run on 2026-11-19 failed
  `test-bootstrap-extreme-ci-cap-on-estimand-scale.R` and `test-estimand-no-effect-value-centering.R` (n = 60, 10-15 %
  degenerate draws); they now expect the NA reason or pass `min_fraction_usable_samples = 0` where the test is about
  something else.
- [x] TODO-192 (added 2026-11-19, agent; found by the v1.0.6-TODO-168 agent): **The KK g-computation weighted refit
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
  -- DONE (agent, 2026-11-19, uncommitted): new `gcomp_weighted_logistic_fit_with_retries()` (`helper_gcomp.R`) tries
  the chained warm start, then the full-data warm start, then cold, and accepts a fit only if `converged` is not FALSE and
  `coefficients_are_usable()`; both the KK `compute_weighted_gcomp_estimate()` and the non-KK `weighted_gcomp_fit()` use
  it (the non-KK drop loop now runs only after all three attempts fail). A failed fit is never cached. Rep 102, B = 999:
  finite SEs 165 -> 999 (RR and RD), no replicate at RR = 1. The first attempt keeps the old arguments (chain beta +
  full-data Fisher), so converged replicates are unchanged. Test:
  `tests/testthat/test-gcomp-weighted-refit-rejects-diverged-warm-start.R` (fails 11/20 before, passes after). The C++
  step-halving follow-up stays open under v1.0.6-TODO-169/170.
  -- C++ follow-up PATCHED, needs owner build (agent, 2026-11-19, uncommitted): `fast_logistic_regression.cpp` IRLS
  (shared by `fast_logistic_regression_cpp`, `_weighted_cpp`, `_with_var_cpp` and the C++ callers in `fast_gee.cpp`,
  `fast_hurdle_negbin.cpp`) now runs the old plain IRLS pass first and, only if that pass does not converge, reruns
  from the same start with step halving (negative log-likelihood may not rise beyond a 1e-10 relative round-off
  allowance; up to 30 halvings; stops at the previous iterate if none helps). Plus the v1.0.6-TODO-170 Newton-decrement
  convergence fallback (below). `_weighted_cpp` also returns `num_step_halvings`. Verified by kernel swap (sourceCpp
  of old and new file, same flags, fresh processes): rep-102 bad warm start now converges (1-2 halvings, b equal to the
  cold-start fit, glm within 6e-9); 3000 random fits x 4 entry points (far/random warm starts, supplied Fisher, large
  column scales, 1e4 offsets, separation): every fit that converged before is `identical()` (whole result list);
  newly converged non-separated fits match glm (median |eta diff| ~1e-10). Inside the g-comp / LogRegr / PropGComp /
  FractionalLogit Bayesian and ordinary bootstraps (360 class x design x seed runs): 160,742 converged kernel calls
  identical; 718 weighted chain fits that diverged before (|b| 1e8-8e9) now converge (|b| <= 3.6, 1-4 halvings), so
  draws differ only from those replicates on (chained warm starts). A single-pass halving variant was rejected: it
  moved ~4% of converged far-warm-start fits by up to ~1e-9 relative. `-DEDI_CORE_ONLY` syntax check passes. Tests:
  `tests/testthat/test-logistic-irls-step-halving-and-scale-aware-convergence.R` (skips until the kernel has
  `num_step_halvings`); `test-gcomp-weighted-refit-rejects-diverged-warm-start.R` updated to pass on old and new
  kernels.

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
  - `code-duplication-da35f9c8f` (`dup-1adb37d8ab20`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:534-614` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:622-701` (coordinate with v1.0.6-TODO-192, same function) -- DONE (agent, uncommitted; bit-identical): `fit_logistic_with_sandwich()` in both classes is now a thin wrapper over `gcomp_fit_logistic_with_sandwich()` (`helper_gcomp.R`); each class passes its clamp and post-fit (HC0 vs KK cluster) as arguments
  - `code-duplication-d6b10061f` (`dup-440466dd6dc0`): `R/EDI/R/design_abstract.R:405-498` vs `R/EDI/R/design_fixed_abstract.R:89-187` -- NOT DONE (corrected 2026-11-20): v1.0.6-TODO-154 merged only `overwrite_all_subject_assignments()`; `DesignFixed` still overrides `add_all_subject_responses` (`R/EDI/R/design_fixed_abstract.R:109` vs `R/EDI/R/design_abstract.R:430`), and the 2026-11-19 run re-flagged the pair as `code-duplication-dc78d3281`
  - `code-duplication-d4e38d855` (`dup-47b3c5848e6a`): `R/EDI/R/inference_survival_gehan_wilcox.R:220-329` vs `R/EDI/R/inference_survival_log_rank.R:199-317` -- DONE (agent, uncommitted)
  - `code-duplication-d23a10708` (`dup-4ca7ca9c9237`): `R/EDI/R/inference_ordinal_ordered_probit.R:100-186` vs `R/EDI/R/inference_ordinal_proportional_odds.R:134-217` -- DONE (agent, uncommitted)
  - `code-duplication-dcdb7e599` (`dup-51b70d0e54ad`): `R/EDI/R/inference_incidence_KK_cond_logit_glmm_abstract.R:367-427` vs `R/EDI/R/inference_proportion_KK_combined.R:164-224` -- DONE (agent, uncommitted)
  - `code-duplication-dfe6e2293` (`dup-53e9eeb69c5d`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:863-970` vs `R/EDI/R/inference_incidence_gcomp.R:16-151` -- DONE (agent, uncommitted; bit-identical): `incidence_kk_gcomp_generic_alias_overrides` is now `modifyList(incidence_gcomp_generic_alias_overrides, ...)` with only `compute_rand_two_sided_pval` re-pinned to `InferenceRandCI`
  - `code-duplication-de10bd6b1` (`dup-6af874290f8f`): `R/EDI/R/simulations_framework.R:3393-3441` vs `R/EDI/R/simulations_framework.R:3446-3494` -- DONE (agent, uncommitted)
  - `code-duplication-db001874c` (`dup-847f2d57f083`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:259-462` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:296-515` (coordinate with v1.0.6-TODO-192) -- DONE (agent, uncommitted; bit-identical): `default_null_value()` and the eleven `compute_rr_*()` privates live once in `gcomp_incid_rr_private_methods` (`helper_gcomp.R`), added to both classes' `private` lists
  - `code-duplication-d7e6ac7c3` (`dup-86f70c0a1fbe`): `R/EDI/R/inference_ordinal_cauchit.R:8-80` vs `R/EDI/R/inference_ordinal_ordered_probit.R:2-76` -- DONE (agent, uncommitted)
  - `code-duplication-d24d11c40` (`dup-8fdf724fbd87`): `R/EDI/R/simulations_framework.R:2110-2146` vs `R/EDI/R/simulations_framework.R:2157-2194` -- DONE (agent, uncommitted)
  - `code-duplication-d1b25b18a` (`dup-a82df7b209aa`): `R/EDI/R/inference_continuous_quantile_regr.R:50-261` vs `R/EDI/R/inference_proportion_quantile_regr.R:54-262` -- DONE (agent, uncommitted)
  - `code-duplication-d593b90a9` (`dup-e88368769f0c`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:400-427` vs `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:439-462` (coordinate with v1.0.6-TODO-192) -- DONE (agent, uncommitted; bit-identical): the four subsampling / m-out-of-n RR privates delegate to `gcomp_rr_resampling_two_sided_pval()` / `gcomp_rr_resampling_confidence_interval()` (`helper_gcomp.R`), parameterized by family
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
  - `code-duplication-d0008dd06` (`dup-cf2587a46833`): `R/EDI/R/inference_count_hurdle.R:80-236` vs `R/EDI/R/inference_count_zero_inflated.R:97-268`
  - `code-duplication-d045a2ebb` (`dup-4b61e21df5c8`): `R/EDI/R/inference_ordinal_adj_cat_logit.R:44-64` vs `R/EDI/R/inference_ordinal_ordered_probit.R:251-271`
  - `code-duplication-d0bee2d47` (`dup-40a8fc9297a9`) [C++]: `R/EDI/src/fast_gehan_wilcox.cpp:1-110` vs `R/EDI/src/fast_logrank.cpp:1-98`
  - `code-duplication-d0bf7a47c` (`dup-73dca8787a4c`): `R/EDI/R/inference_incidence_binomial_identity.R:628-668` vs `R/EDI/R/inference_proportion_beta.R:368-407`
  - `code-duplication-d0f32f7c4` (`dup-ae89fd0f2d50`): `R/EDI/R/inference_count_hurdle.R:581-605` vs `R/EDI/R/inference_proportion_zero_one_inflated_beta.R:470-494`
  - `code-duplication-d114b8d9b` (`dup-89aa9d2539e0`) [C++]: `R/EDI/src/sample_mode.cpp:40-93` vs `R/EDI/src/sample_mode.cpp:94-143`
  - `code-duplication-d1564c4c6` (`dup-abd094cd763e`): `R/EDI/R/inference_ordinal_adj_cat_logit.R:5-66` vs `R/EDI/R/inference_ordinal_cloglog.R:52-109` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): cloglog `initialize` has no `harden` argument; adjacent-category logit has one
  - `code-duplication-d1d0200db` (`dup-7df0544df4d2`): `R/EDI/R/inference_all_abstract_rand_ci.R:559-594` vs `R/EDI/R/inference_incidence_exact_zhang.R:73-106`
  - `code-duplication-d1f2bef91` (`dup-b02d9fd25b94`) [C++]: `R/EDI/src/fast_wilcox_hl.cpp:340-356` vs `R/EDI/src/fast_wilcox_hl.cpp:381-397`
  - `code-duplication-d2067ea8e` (`dup-4387d08426f4`): `R/EDI/R/inference_count_KK_cond_poisson.R:831-877` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1795-1841`
  - `code-duplication-d22d0b43d` (`dup-bf70b2e02e63`): `R/EDI/R/inference_all_abstract_rand_bootstrap.R:1024-1072` vs `R/EDI/R/inference_all_abstract_rand_bootstrap.R:1159-1212`
  - `code-duplication-d27b99ba5` (`dup-9319feaf81b4`): `R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R:163-172` vs `R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R:175-184`
  - `code-duplication-d2c14e342` (`dup-117b65d30af8`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:1024-1064` vs `R/EDI/R/inference_incidence_KK_marginal_abstract.R:66-110`
  - `code-duplication-d2c94a819` (`dup-018bf5078750`): `R/EDI/R/inference_ext_likelihood_test_memoization.R:192-206` vs `R/EDI/R/inference_ext_likelihood_test_memoization.R:207-221`
  - `code-duplication-d2cb1831f` (`dup-32b5d56ba802`) [C++]: `R/EDI/src/fast_logistic_glmm.cpp:380-405` vs `R/EDI/src/fast_logistic_glmm.cpp:439-461`
  - `code-duplication-d32feefe2` (`dup-ee0fda8e5b7b`) [C++]: `R/EDI/src/kk21_weights.cpp:493-599` vs `R/EDI/src/kk21_weights.cpp:972-1076` -- do with v1.0.6-TODO-236, which must edit both Newton loops anyway
  - `code-duplication-d37d994cc` (`dup-0cae3844f40b`): `R/EDI/R/inference_ext_m_out_of_n_bootstrap.R:64-114` vs `R/EDI/R/inference_ext_prw_subsampling.R:59-109` -- v1.0.6-TODO-194 merged only the p-value and CI setups
  - `code-duplication-d3f8794a9` (`dup-e19765984523`): `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:654-701` vs `R/EDI/R/inference_survival_KK_lwa_cox_one_lik_abstract.R:99-142`
  - `code-duplication-d4062d188` (`dup-82f8a493e070`): `R/EDI/R/inference_continuous_KK_ols_one_lik.R:112-168` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:654-696` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): OLS one-lik `compute_asymp_confidence_interval` `testing_type` switch has no default, returns NULL
  - `code-duplication-d41dc9935` (`dup-a34c2117a793`) [C++]: `R/EDI/src/fast_ordinal_cauchit_regression.cpp:1-47` vs `R/EDI/src/fast_ordinal_probit_regression.cpp:1-47`
  - `code-duplication-d48f0b621` (`dup-5b31a3214560`): `R/EDI/R/inference_all_abstract_rand.R:770-785` vs `R/EDI/R/inference_all_abstract_rand.R:790-805`
  - `code-duplication-d4c0c7f7a` (`dup-c48486186648`) [C++]: `R/EDI/src/fast_gaussian_lmm.cpp:565-583` vs `R/EDI/src/fast_gaussian_lmm.cpp:636-652`
  - `code-duplication-d4ceca027` (`dup-d1a3e796a967`): `R/EDI/R/inference_incidence_exact_binomial.R:30-93` vs `R/EDI/R/inference_indicidence_exact_fisher.R:21-77` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): exact-binomial design check runs always, exact-Fisher only under `should_run_asserts()`
  - `code-duplication-d54d5e887` (`dup-c59fc462a58f`) [C++]: `R/EDI/src/fast_gehan_wilcox.cpp:85-168` vs `R/EDI/src/fast_logrank.cpp:76-156`
  - `code-duplication-d56b63aab` (`dup-d3f4295c00b8`): `R/EDI/R/inference_incidence_log_binomial.R:262-291` vs `R/EDI/R/inference_incidence_modified_poisson.R:188-199`
  - `code-duplication-d5e5b1877` (`dup-5e66d7d6a084`): `R/EDI/R/inference_continuous_quantile_regr.R:230-352` vs `R/EDI/R/inference_proportion_quantile_regr.R:54-172` -- partly done: `code-duplication-d1b25b18a` merged the privates; the public skeleton is still copied
  - `code-duplication-d63139ea4` (`dup-ccaf9d863fdd`): `R/EDI/R/design_fixed_greedy.R:159-178` vs `R/EDI/R/design_fixed_greedy_d_optimal.R:296-313`
  - `code-duplication-d6a11e876` (`dup-27d58e66d0f8`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:410-437` vs `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:449-472` -- re-detection of `code-duplication-d593b90a9` (DONE); should drop off the next scan
  - `code-duplication-d6c8eb597` (`dup-80086ada1649`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:901-1012` vs `R/EDI/R/inference_incidence_gcomp.R:16-155` -- re-detection of `code-duplication-dfe6e2293` (DONE); should drop off the next scan
  - `code-duplication-d6e5fae59` (`dup-1d2fe9089c45`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:23-69` vs `R/EDI/R/inference_survival_strat_cox.R:239-271`
  - `code-duplication-d708f1f8e` (`dup-b60c9f7798cf`): `R/EDI/R/inference_ordinal_ordered_probit.R:176-225` vs `R/EDI/R/inference_ordinal_stereotype_logit.R:1337-1386`
  - `code-duplication-d79480795` (`dup-bd767b3b1e90`): `R/EDI/R/inference_count_KK_cond_poisson.R:1007-1031` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1070-1093`
  - `code-duplication-d7bfd0139` (`dup-8500784fdfc4`) [C++]: `R/EDI/src/fast_adjacent_category_logit.cpp:393-415` vs `R/EDI/src/fast_adjacent_category_logit.cpp:479-508`
  - `code-duplication-d7d618301` (`dup-e8c35417c731`) [C++]: `R/EDI/src/fast_gee.cpp:307-351` vs `R/EDI/src/fast_gee.cpp:354-392` -- family parse overlaps v1.0.6-TODO-103; the group sort is not covered there
  - `code-duplication-d8450dc93` (`dup-38ee54497f68`) [C++]: `R/EDI/src/fast_logistic_regression.cpp:386-512` vs `R/EDI/src/fast_probit_regression.cpp:438-612`
  - `code-duplication-d872ec3dd` (`dup-03478b9e1cf3`): `R/EDI/R/inference_count_hurdle.R:110-153` vs `R/EDI/R/inference_count_zero_inflated.R:358-393`
  - `code-duplication-d89e34e9e` (`dup-348cb26a7183`) [C++]: `R/EDI/src/fast_continuation_ratio_regression.cpp:330-364` vs `R/EDI/src/fast_continuation_ratio_regression.cpp:391-433`
  - `code-duplication-d8aa199fe` (`dup-37d956f7bdfa`): `R/EDI/R/inference_count_KK_cond_poisson.R:760-812` vs `R/EDI/R/inference_count_KK_cond_poisson.R:1750-1799`
  - `code-duplication-d8f5eab74` (`dup-b026b3ce7998`) [C++]: `R/EDI/src/fast_hurdle_poisson_glmm.cpp:595-663` vs `R/EDI/src/fast_hurdle_poisson_glmm.cpp:664-730`
  - `code-duplication-d912e6d2b` (`dup-6eab11b3bbec`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:562-629` vs `R/EDI/src/fast_log_binomial_regression.cpp:804-868`
  - `code-duplication-d913fbe2c` (`dup-405743f65354`): `R/EDI/R/inference_ordinal_cauchit.R:137-206` vs `R/EDI/R/inference_ordinal_cloglog.R:287-358`
  - `code-duplication-d9607a7c1` (`dup-9e2c0a9f8178`): `R/EDI/R/inference_incidence_KK_gcomp_abstract.R:116-272` vs `R/EDI/R/inference_incidence_gcomp_abstract.R:123-301` -- partly done: the RR methods are merged; the RD bootstrap, Bayesian-bootstrap and jackknife wrappers and `compute_treatment_estimate_during_randomization_inference` are still copied
  - `code-duplication-daf376ace` (`dup-1f433f508026`): `R/EDI/R/inference_incidence_modified_poisson.R:441-486` vs `R/EDI/R/inference_incidence_probit.R:376-421`
  - `code-duplication-db5595975` (`dup-3fa266e6a729`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:376-441` vs `R/EDI/src/fast_log_binomial_regression.cpp:618-689` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): unweighted log-binomial IRLS takes `warm_start_weights` but never reads it
  - `code-duplication-db621c738` (`dup-a61a70528060`) [C++]: `R/EDI/src/fast_log_binomial_regression.cpp:460-581` vs `R/EDI/src/fast_log_binomial_regression.cpp:709-819`
  - `code-duplication-db68b8e31` (`dup-eb77e907ec3a`): `R/EDI/R/inference_count_zero_inflated.R:120-174` vs `R/EDI/R/inference_count_zero_inflated.R:341-387`
  - `code-duplication-dba30f68d` (`dup-21b487f963fb`): `R/EDI/R/inference_all_KK_quantile_regr_one_lik_abstract.R:85-134` vs `R/EDI/R/inference_continuous_KK_ols_one_lik.R:62-137`
  - `code-duplication-dbc57fae3` (`dup-0bea0bb60720`): `R/EDI/R/contracts_mixins.R:3318-3364` vs `R/EDI/R/design_component_registry.R:183-224`
  - `code-duplication-dbec652e7` (`dup-395b2ca21302`): `R/EDI/R/contracts_mixins.R:3206-3245` vs `R/EDI/R/design_component_registry.R:241-279`
  - `code-duplication-dc61886c3` (`dup-7bf412e7eaca`) [C++]: `R/EDI/src/fast_gee.cpp:322-336` vs `python/cpp/bindings_incidence.cpp:63-87` -- overlaps v1.0.6-TODO-103 (one shared GEE family parse)
  - `code-duplication-dc78d3281` (`dup-c8291bff0887`): `R/EDI/R/design_abstract.R:410-493` vs `R/EDI/R/design_fixed_abstract.R:89-174` -- same pair as `code-duplication-d6b10061f` above, which is NOT done: `add_all_subject_responses` is still overridden in `DesignFixed`
  - `code-duplication-dc91e2221` (`dup-27fab88a45dc`): `R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R:12-69` vs `R/EDI/R/inference_incidence_log_binomial.R:101-157`
  - `code-duplication-dd45c2fa8` (`dup-11b5cd15f2d7`): `R/EDI/R/inference_ordinal_cauchit.R:134-206` vs `R/EDI/R/inference_ordinal_ordered_probit.R:57-129`
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
  divergence_bug verdicts are v1.0.6-TODO-414 and v1.0.6-TODO-415. Fourteen of the 51 are flagged as possible divergence
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
  - `code-duplication-d517ba962` (`dup-be0576598be3`): `R/EDI/R/inference_continuous_KK_robust_regr_ivwc.R:210-247` vs `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:324-374` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the live loggamma copy keeps a redundant early return after v1.0.6-TODO-132 (harmless today)
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
  - `code-duplication-da55699c9` (`dup-a8d3d55a6f41`): `R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R:345-367` vs `R/EDI/R/inference_survival_KK_strat_cox.R:267-289` -- POSSIBLE DIVERGENCE BUG, check before merging (own TODO if confirmed): the Weibull-frailty normal `shared()` keeps the early return on a cached `beta_hat_T` (L349) that v1.0.6-TODO-132 meant to remove
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
- [x] TODO-195 (added 2026-11-19, agent; found by the v1.0.6-TODO-186 agent): **Leftovers from the zero-augmented
  identification fix.** (1) The KK hurdle classes (`InferenceCountKKHurdlePoissonOneLik`, `...IVWC`,
  `inference_count_KK_cond_poisson.R`) use a separate path and were not checked for the same unidentified count-part
  treatment coefficient; add the guard if needed. (2) Owner decision (changes results): drop aliased count-part
  covariates on the positive rows (as `glm` would) so more small-n datasets stay estimable instead of NA. (3) When every
  positive count equals 1 the hurdle count MLE goes to -infinity; today only the SE is dropped
  (`zero_augmented_data_has_no_mle`) and the point estimate is still returned. (4) `fast_zero_augmented_poisson_cpp`
  with `y = NULL` segfaults instead of erroring (C++ input check).

  - Decided 2026-11-19 (owner): item (2): (a) drop aliased count-part covariates on the positive rows, as `glm` does; see [DECISION-v1.0.6-TODO-195](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-195).
  Agent started 2026-11-19.
  Item (2) done 2026-11-19 (agent, uncommitted; items 1, 3, 4 open): new `zero_augmented_drop_aliased_count_cols()`
  (`inference_count_zero_augmented_poisson_abstract.R`; glm's sequential pivoted QR on the positive rows, intercept,
  treatment, covariates in design order, via `kk_strat_cox_drop_within_strata_aliased_cols()` with one stratum; the
  treatment is never dropped, so an aliased treatment still hits the TODO-186 guard) and the class-side wrapper
  `edi_zero_augmented_drop_aliased_count_cols()` (free functions, no registry change; only with `harden`). Wired before
  every TODO-186 guard: full fit, randomization refit and weighted bootstrap of HurdlePoisson / ZIP / ZINB (shared
  abstract) and of HurdleNegBin (own path, same rule); the reusable bootstrap worker and slow path refit through the
  full fit; jackknife is unsupported in all four. One `edi_covariate_dropped_warning` per object, new reason
  `"aliased_on_positive_rows"` (`helper_robust_sandwich.R`), silent in resampling; dropped coefficients are NA in
  `full_coefficients`. Roxygen "Aliased count-part covariates" paragraph in all four classes ("the same as what
  \code{\link[stats]{glm}} does", `singular.ok`), not roxygenized. Full-rank data bit-identical (`identical()` vs the
  no-drop path, 2 seeds x 4 classes, estimate/CI/rand/boot/Bayesian boot). Aliased example (n = 30, x2 = 2 x1 + 1 on
  the positive rows): before, HurdlePoisson/ZIP had NA CIs and ZIP/ZINB arbitrary estimates (0.343 vs 0.458); now
  every path equals the fit without x2 and pscl to 1e-3. New
  `test-zero-augmented-count-aliased-covariates-dropped-on-positive-rows.R` (88). Results change: datasets with an
  aliased count covariate (and some TODO-186 NA datasets with few positive rows) now give estimates.
  Items (1), (3), (4) done 2026-11-19 (agent, uncommitted; C++ PATCHED, needs owner build). (1) The KK hurdle classes
  had none of the guards: on `DesignFixedBinaryMatch` n = 40, every positive matched row treated gave -0.43 (SE 0.31),
  every treated positive count 1 gave -14 (SE 335), and randomization replicates stuck at the warm start. New free
  `kk_hurdle_count_guard()` (`inference_count_KK_cond_poisson.R`) applies the (2) aliased drop, the TODO-186
  identification check and the (3) rule to the rows that enter the count likelihood (IVWC: positive matched rows of the
  matched component; OneLik: those rows when more than the coefficients, plus all reservoir rows, where an arm is at
  infinity when its truncated rows are all 1 and its reservoir counts all 0). Wired into the full fit, weighted bootstrap
  and (via the full fit) randomization of both classes, and the OneLik parametric-bootstrap simulation. IVWC: a matched
  component failing the guard is dropped (reservoir only, as for any failed component), NA only with no reservoir.
  Reasons `kk_hurdle_count_treatment_unidentified` / `kk_hurdle_count_mle_not_finite`. `inference_count_KK_cond_poisson.R`'s
  conditional-Poisson class has no positive-row-only count part, so nothing to do there. (3) New
  `zero_augmented_count_mle_infinite_arms()`: the MLE is infinite whenever ONE arm's positive counts are all 1 (not only
  all of them; the direction that lowers only that arm's rate raises every term, whatever the covariates). pscl::hurdle
  confirms (count_w -12.2 / +11.7, SE ~100+; Poisson and negbin). HurdlePoisson and HurdleNegBin full fit: NA, reason
  `hurdle_count_mle_not_finite` / `hurdle_negbin_count_mle_not_finite`, one warning of class
  `edi_hurdle_count_mle_not_finite_warning` (subclass of `edi_procedure_na_warning`, procedure "estimate", once per object,
  silent in resampling); randomization refits, weighted bootstraps and the reusable worker return NA on draws that keep
  the pattern (so bootstrap draws of an arm-all-ones dataset are all NA; permutations mix the arms and stay finite); the
  parametric-bootstrap simulations mark params[j] / b[j] NA on such draws (estimate replicate = failed refit), while the
  LR replicate, which uses only the two nlls (finite supremum), is unchanged. `zero_augmented_data_has_no_mle()` stays as
  an SE-side backstop. ZIP / ZINB are unaffected (their count part also models zeros). (4) On the installed build the
  NULL-y case errors ("Not compatible"), but `y = numeric(0)` segfaults and a short y, an Xzi / X_hurdle / group_id with
  fewer rows, a wrong-length params or j_T = 7 returned "converged" garbage (34-case probe, one process per case). C++:
  `zap_check_kernel_inputs()` / `hnb_check_kernel_inputs()` / `hpg_check_kernel_inputs()` (file-unique names for unity
  builds) in `fast_zero_augmented_poisson_cpp` + score + hessian, `fast_hurdle_negbin_cpp`, `_with_var_cpp` (also j),
  `fast_truncated_negbin_count_cpp`, `fast_hurdle_poisson_glmm_cpp` (also group_id length, j_T range); the GLMM
  derivative exports already checked. R: `edi_check_count_kernel_inputs()` at the call sites (guarded ZAP wrapper, the
  hurdle component recovery, the ZAP LR null refit, the HurdleNegBin fit and rand refit, the KK matched GLMM fit).
  Kernel-swap verified (sourceCpp linked read-only against EDI.so): all 34 probe cases now error with a message;
  related kernel tests pass on the swapped kernels. Tests: `test-kk-hurdle-poisson-count-row-guards.R` (33),
  `test-hurdle-count-mle-not-finite-when-an-arm-has-only-ones.R` (45), `test-zero-augmented-kernel-input-checks.R` (39
  swapped; the C++ blocks skip on an unpatched build, detected from the NULL-y message). Roxygen paragraphs in
  HurdlePoisson, HurdleNegBin, KK IVWC, KK OneLik (not roxygenized). Results change: arm-all-ones hurdle data and KK
  hurdle data with unidentified / aliased count rows now give NA / a reduced model instead of arbitrary estimates.
  Follow-up found (not fixed): v1.0.6-TODO-218 (3) sweep, 3 small-n ZIP fits (n = 24-40, 2-7 positives) end at an
  unflagged point with a higher nll than pscl (by 0.17, 1.3, 6.6; e.g. sweep seed 100888: EDI 0.003 vs pscl -23.6).
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
  v1.1.0-TODO-197).
  - Owner decision pending: [DECISION-v1.0.6-TODO-197](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-197) (related: delete or fix the unused ZOIB wrapper `.fit_zero_one_inflated_beta` in `helper_zoib.R`?).

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

- [x] TODO-201 (added 2026-11-19, agent; found by the v1.0.6-TODO-193 R-refactor agent; owner decision, changes
  results): **`InferenceOrdinalPropOddsRegr` lacks `supports_fisher_information()`, unlike its probit sibling.** The
  code-duplication audit (`dup-4ca7ca9c9237`) flagged it as a drift. Adding it changes the testing types offered and the
  information source PropOdds uses, so it was left out of the bit-identical refactor. Decide whether PropOdds should
  support it (and check cauchit / cloglog for the same gap), then add it with a test and a NEWS line.

  - Decided 2026-11-19 (owner): (a) add it to PropOdds, check cauchit / cloglog, verify the information per link; see [DECISION-v1.0.6-TODO-201](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-201).
  Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted): cauchit / cloglog already had the flag (no gap), but in all three
  siblings "fisher" was the OBSERVED Hessian under a "fisher" label: every C++ ordinal fit returns
  `fisher_information = -Hessian` (`information_type = "observed"`), and the R spec closures passed it through.
  Added `ordinal_cumlink_expected_information()` (pure R, `inference_ordinal_ordered_probit.R`). It is the real
  expected information sum_i sum_k (d pi_ik)(d pi_ik)' / pi_ik for the logit / probit / cauchit / cloglog links,
  in the solvers' native parameterization (cloglog eta_sign = +1). It matches the exact expectation of the C++
  score outer product and negative Hessian to 1e-15, numDeriv to 1e-11, and the unexported C++
  `expected_hessian()` to 1e-15. For K = 2 logit it equals X'WX. All four specs' `fisher_information` now use it,
  and PropOdds gains `supports_fisher_information()` (registered in `contracts_mixins.R`; the registry baseline
  needed no delta). Changes results: the default score tests / score CIs (and `get_standard_error()`) of all four
  classes now use the expected information. Public Wald and LR are unchanged. Null size at n = 40, R = 1000: the
  cauchit score test goes from 0.092 to 0.053 and cloglog from 0.069 to 0.054; the other cells are at nominal.
  Test `test-ordinal-cumulative-link-expected-information.R`. Derivation, verification tables and open items
  (the public Wald test ignores the information preference; the misleading C++ field name; partial PO) are in
  `R/package_metadata/audits/research_findings/2026-11-19-ordinal-cumulative-link-expected-information.md`.
- [x] TODO-202 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-193 R-refactor agent):
  **`test-inference-migration-harness.R` fails at its custom-randomization block (~L168).** `expect_silent` now catches
  `edi_perfect_predictor_warning` (v1.0.6-TODO-158) and an `edi_procedure_na_warning` (v1.0.6-TODO-136/-145/-165) from
  `InferenceRandCustom`. Check whether the fixture really has a perfect predictor and a silent-NA path (then the
  warnings are correct: muffle by class or change the fixture) or whether a warning fires where it should not (then fix
  the code).
  DONE 2026-11-19 (agent, uncommitted): both warnings are correct. The shared continuous fixture's noise
  `seq(-0.3, 0.3, n)` is collinear with `x = seq(-1.1, 1.1, n)`, so y is exactly linear in w, x, z (real perfect
  predictor); the test now muffles `edi_perfect_predictor_warning` by class with a comment (fixture left as is, it is
  shared). The NA came from r = 9 < the 10-finite-draw floor (all 9 draws finite), so the block compared NA to NA; it
  now uses r = 12. Code fix: when r itself is below the floor, the `randomization_too_few_finite_estimates` warning
  now says "Increase r" instead of blaming the estimator (`inference_all_abstract_rand.R`); regression test in
  `test-rand-and-bootstrap-pval-silent-na-warns.R`.
- [x] TODO-203 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-193 C++-refactor agent):
  **The three fixed-link ordinal kernels (cauchit, cloglog, probit) disagree on edge cases.** The v1.0.6-TODO-193 merge
  into `R/EDI/src/ordinal_fixed_link_internal.h` kept each difference as an explicit `FixedLinkFitSpec` policy flag so
  the refactor stayed bit-identical; this TODO is to decide one behavior and test it:
  - cloglog validates `warm_start_fisher_info` before the K < 2 early return; cauchit returns first.
  - probit has no K < 2 early return at all.
  - probit maps a non-finite or non-positive `ssq_b_j` to NaN; cauchit and cloglog pass it through.
  - cauchit's `_with_var` returns a list of NAs where probit returns an empty list.
  Needs the owner's build to verify (C++).
  DONE 2026-11-20 (agent, uncommitted; PATCHED, needs owner build): the `DegenerateLevelsPolicy` and
  `nan_nonpositive_ssq` flags are gone; all three links now (1) validate `warm_start_fisher_info`, `fixed_idx` /
  `fixed_values` and the `warm_start_params` length before (2) the K < 2 early return (empty list), (3) report a
  non-finite or non-positive `ssq_b_j` as NaN, and (4) return `list(b = NA, ssq_b_2 = NA)` from `_with_var` for
  K < 2 (shared `fixed_link_ordinal_with_var_list()`). The probit "empty list" was not what happened: probit had no
  early return and fitted a threshold-free model, returning `b = 0`, `converged = TRUE`. USER-VISIBLE (probit only):
  `InferenceOrdinalOrderedProbitRegr` on a one-level response gave estimate 0 and now gives NA (as cauchit / cloglog
  already did), and bootstrap draws with one level used to enter the distribution as exact zeros (72 of 200 draws on
  a 12-subject fixture with one subject in the second level) and are now dropped (128 usable, as for the other two
  links), which moves probit bootstrap CIs / p-values on such data. Cauchit / cloglog: only the direct C++ calls
  change (`ssq_b_j` 0 -> NaN on a singular information; K < 2 with malformed inputs now errors); the R classes
  already treated a non-positive variance as missing. Ordinary fits unchanged (same b and ssq). Kernel swap of the
  three .cpp files. Test `test-ordinal-fixed-link-kernels-edge-cases-agree.R` (12 pass swapped; 13 failures + 1
  error on the old kernels). Rd not regenerated.
  - Decided 2026-11-20 (owner): probit on a one-level response returns NA; see [DECISION-v1.0.6-TODO-203](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-203).
  Documented in the `InferenceOrdinalOrderedProbitRegr` roxygen (one-level response gives NA; single-level resampling draws are
  dropped, as for cauchit / cloglog; Rd not regenerated). The Python `fast_ordinal_probit_regression` docstring
  already says it returns an empty dict for fewer than 2 observed categories, which is now true.
- [x] TODO-204 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-202 agent): **Unmuffled procedure-NA warnings
  in two tests, and a fixture that is an exact perfect predictor.** (1) `test-rand-pval-affine-reuse-finite-draw-minimum.R`
  (4 warnings) and `R/package_tests/testthat_bulk/test-randomization-pval-from-t0s-too-few-finite-guard-reference.R`
  (1 warning) expect the NA but don't muffle `edi_procedure_na_warning` (v1.0.6-TODO-136); add
  `suppressWarnings(classes = "edi_procedure_na_warning")`. (2) OWNER DECISION: `inference_migration_complete_design()`
  (`R/EDI/R/local_machine_tuning_synthetic_fixtures.R`) adds noise `seq(-0.3, 0.3)` collinear with
  `x = seq(-1.1, 1.1)`, so y is exactly linear in w, x, z and every caller with covariates hits
  `edi_perfect_predictor_warning`. Making the noise non-collinear fixes it at the source but may move goldens and the
  benchmark tuner's inputs. The v1.0.6-TODO-190 agent found the same in `edi_tuning_synthetic_experiment()` (same file
  ~L101-103): proportion (logit scale) and continuous responses have no noise, so x and z are dropped as perfect
  predictors and the tuning harness may benchmark ZOIB etc. without covariates. (3) Audit tests built on these
  noise-free fixtures for silent passes (the ZOIB futile-refit golden test passed vacuously after the drop until
  TODO-190 stubbed the detector and added a call-count check).
  - Decided 2026-11-19 (owner): (a) add a little noise to both fixtures; see [DECISION-v1.0.6-TODO-204](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-204).
  Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted): both fixtures are one function (`edi_tuning_synthetic_experiment()` wraps
  `inference_migration_complete_design()`), so the fix is there: the continuous, proportion (logit scale) and survival
  (log time; also exactly linear, not in the original report) responses get a seeded `rnorm()` term (sd 0.1 / 0.2 /
  0.1) drawn after the assignment inside the existing local seed scope, so `w` and the caller's RNG are unchanged.
  `edi_find_perfect_predictors()` now drops nothing for all six response types (n 10-200, 11 seeds; before: x, z for
  continuous and proportion, x for survival). Re-pinned only the continuous goldens in
  `test-simple-mean-difference-migration-golden.R` and `test-simple-wilcox-migration-golden.R` (both passed unchanged
  against the old fixture). Removed TODO-202's perfect-predictor muffle in `test-inference-migration-harness.R`
  (`expect_silent()` now fails on the old fixture); ZOIB golden test 4 now asserts no covariate is dropped; test 5
  rebuilds the old noise-free design locally (identical y and w) and keeps its detector stub and call-count check.
  The KK/blocked mirror recipe in `test-reused-worker-resampling-nondegenerate.R` got the same noise (52 warnings to 0).
  Item (1): both NA tests assert `edi_procedure_na_warning` with `expect_warning(class =)`. Saved
  `tune_EDI_for_this_machine()` policies and `scripts/reused_worker_bitforbit_sweep.R` baselines predate the change.
- [x] TODO-205 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-147 agent): **Rand-sweep reproducibility failure.**
  `R/package_tests/testthat_bulk/test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R`
  fails 1 of 36: two seeded calls to `InferenceIncidBinomialIdentityRiskDiff$compute_rand_two_sided_pval()` give 1 vs
  0.555. That class does not use the Zhang code. Suspects: concurrent uncommitted edits in
  `inference_all_abstract_rand*.R` / `..._bootstrap*.R` (v1.0.6-TODO-185's `active_resampling_operation` restore,
  v1.0.6-TODO-202's warning-text change) or committed seeding changes (v1.0.6-TODO-53/61/177). Re-run once TODO-185 lands,
  bisect, and fix the code or the test.
  Re-run 2026-11-19 after TODO-185 landed: still fails (1 vs 0.555), so TODO-185 is not the cause. The v1.0.6-TODO-189
  agent found that `InferenceIncidBinomialIdentityRiskDiff`'s rand p differs between the reusable-worker and slow
  paths under the conditional estimand (1.000 vs 0.586): likely the same bug (worker statistic != slow-path statistic).
  DONE 2026-11-19 (agent, uncommitted): a code bug in `inference_incidence_binomial_identity.R`, not the seeding changes.
  The warm start carried into a draw holds the Fisher information of a fit on another assignment, so the identity-link
  kernel's line search rejected every step and returned the start unchanged (`converged = FALSE`). The worker's
  estimate-only fit dropped `converged`, so ~30% of draws (143 of 501) equalled the observed estimate exactly. The
  observed statistic was its own warm-started refit, drifting ~1e-7 between calls, which moved those ties between tails
  (1 vs 0.555). Fix: stalled warm fits are refit cold (`fit_identity_binomial_warm_then_cold`), the estimate-only fit
  keeps `converged`, and the rand statistic is `compute_estimate(estimate_only = TRUE)`, as in the worker. Worker and
  slow path now agree (bern seeds 1/3, KK14 seeds 2/5, both estimands). A sibling sweep of every `InferenceIncid*`
  class found no other failure. Test: `test-binomial-identity-rand-pval-worker-slow-path-agree.R`. The 2026-11-17 skipped
  audit test `test-binomial-identity-randomization-refit-nonconverged-start.R` is now unskipped.
- [x] TODO-206 (added 2026-11-19, coordinator; from v1.0.6-TODO-147; OWNER DECISION): **The pooled Zhang estimate can lie
  outside the exact CI.** After v1.0.6-TODO-147 the point estimate uses the pooled table, while the exact CI inverts the
  combined matched + reservoir test, so the two are different quantities (in every case checked the estimate was
  inside, e.g. 2.34 in [0.66, 5.53]). Either document that the estimate is not guaranteed to lie in the CI, or change
  one of them. Also regenerate comprehensive CSV rows holding `InferenceIncidExactZhang` estimates on matching designs.
  - Decided 2026-11-19 (owner): (a) document it and regenerate the matching-design Zhang rows; see [DECISION-v1.0.6-TODO-206](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-206).
  Agent started 2026-11-19.
  DONE 2026-11-19 (agent, uncommitted): docs in the class roxygen (`inference_incidence_exact_zhang.R`) and the
  `exact-zhang-compute-estimate` / `exact-zhang-compute-exact-confidence-interval` templates say that on a matching
  design the estimate (pooled table) and the exact CI (discordant pairs + reservoir) are different quantities, so the
  estimate is not guaranteed to lie in the CI (Rd not regenerated). Regenerated all 323 matching-design keys (x 3
  functions = 969 rows; KK21stepwise ~1/~., FixedBinaryMatch ~.; pima reps 1-50 both betas, cancer, fuel; the only
  matching-capable designs with Zhang rows) with filtered `comprehensive_tests.R` runs and merged them with
  `merge_comprehensive_slice_results.R --apply` into the gitignored `comprehensive_tests_results_nc_1_incidence.csv`
  (backup `.pre_slice_merge_20261119T160923Z.bak`). The old rows predate per-case seeding, so the data draws (and
  therefore p-values/CIs) differ; the p-value/CI code was checked unchanged instead (old vs new helpers on 24 KK21stepwise
  / FixedBinaryMatch fits: identical p-values and CIs). Then updated only those classes' rows in the tracked
  `comprehensive_tests_{mse,coverage,size,power}.csv` from `analyze_comprehensive_tests.R` run on a copy (a full rewrite
  would change unrelated rows: the tracked files no longer match the local results). MSE: FixedBinaryMatch 0 -> 0.060,
  KK21stepwise ~. 0.844 -> 0.095, ~1 0.090 -> 0.147. In the new rows 320 of 323 estimates lie in the exact CI; of the 3
  outside, 1 is a genuine case (0.756 vs [0.767, 5.61]) and 2 are near-zero-width CIs (KK21stepwise ~., pima, beta_T 0.5, reps 6 and 14: [0.1933261, 0.1933269] with p = 0.002 at 0,
  and [-0.2623787, -0.2623780]; reported to the coordinator for a new TODO, not investigated). The
  baseline `low_power|incidence|InferenceIncidExactZhang` finding no longer fires; prune it with `--write-baseline`
  when the 29 new survival findings are triaged (not done here).
- [x] TODO-207 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-185 agent): **Resampling methods that set
  `active_resampling_operation` at their own top level silence any procedure-NA warning inside them, even when the user
  calls them directly.** The parametric-bootstrap, Bartlett, m-out-of-n and subsampling methods do this; nothing in them
  warns today, but a warning added later would never fire. Set the flag only around the inner replicate loop (as the
  rand / bootstrap paths do), and add restore tests for the parametric-bootstrap and Bartlett sites, which
  v1.0.6-TODO-185 changed without a test.
  Done 2026-11-19 (agent, uncommitted): the flag (saved and restored) now covers only `run_param_bootstrap_replicates()`,
  `run_param_bootstrap_estimate_replicates()` and, for m-out-of-n / subsampling, `compute_resampling_draw_distribution()`;
  the 5 parametric-bootstrap methods and `get_bartlett_factor_approx()` no longer set it. Values identical before/after
  (20 calls, `identical()`) once the estimate is fitted; on a fresh object the logit parametric-bootstrap results move by
  ~4e-10, because the top-level full fit now stores its warm start, so they now equal the already-fitted results (an
  order dependence removed). Silent NAs now warn (`edi_procedure_na_warning`, silent while resampling): the
  parametric-bootstrap LR p-value (6 reasons), estimate / CI / p-value (incl. the batch preflight reasons), the LR
  bootstrap CI (new reasons `lik_ratio_bootstrap_ci_*`, e.g. B = 29 can never reach alpha = 0.05; its search muffles the
  p-value's warning), and the m-out-of-n / subsampling p-value (as their CIs already did). `InferenceCountPoisson` holds
  the model warning and re-signals it only when its design-based fallback is NA too. Test
  `test-param-boot-and-subsampling-resampling-flag-scoped-to-replicate-loop.R`.
- [x] TODO-208 (added 2026-11-19, coordinator; seen by the v1.0.6-TODO-189 agent): **Two failing tests and two
  leftovers.** (1) `test-custom-extension-contract.R:62`: `x` missing from `get_analysis_data()`; the fixture's
  x = 1..20 perfectly separates the assignment, so v1.0.6-TODO-158 drops it; change the fixture or the expectation.
  (2) `test-inference-class-registry.R:118`: the reviewed registry baseline shows 101 `private_methods` mismatches from
  today's private-method additions; re-pin after review. (3) `InferenceCountZeroInflatedPoisson` BRT worker vs slow
  path differ by ~0.1 (conditional) / ~0.2 (marginal) on plain Poisson data where the inflation part is barely
  identified (agree to ~1e-4 with real excess zeros); decide whether to document or guard. (4) `InferenceCountHurdleNegBin`
  has no `set_estimand` (errors "attempt to apply non-function"): the known NegBin marginal gap.
  Status 2026-11-19 (agent, uncommitted): (1) fixed in the test. Not separation: y = c(1:10, 12:21) is exactly x + w
  with x = 1:20, so v1.0.6-TODO-158 rightly drops x as leakage. The three fixtures with that x now use an ordinary
  covariate (`rep(c(4, 1, 7, 2, 9, 3, 8, 5, 10, 6), 2)`, commented); the file passes with 0 failures and no more
  perfect-predictor warnings. (2) Nothing left to re-pin: HEAD dd255899 already added the reviewed delta
  (`abd7e49d_added_private` in `inference_component_call_graph_helpers.R`). Against the helper before that commit, the
  101 mismatched classes are all additions, no removals, and only 7 names: `bootstrap_ci_estimates_extreme`,
  `bootstrap_estimand_is_raw_ratio` (v1.0.6-TODO-175), `resampling_centered_pivot_for_inference`,
  `select_resampling_size_from_spec` (v1.0.6-TODO-194 / -196), `compute_quantile_estimate_with_bootstrap_weights`,
  `quantile_fit_response` (Contin/PropQuantileRegr) and `design_stratified_jackknife` (CountPoisson, v1.0.6-TODO-135
  follow-up). The registry test file passes. (3) A real path difference, the same bug as v1.0.6-TODO-30, made possible
  by v1.0.6-TODO-152. The reused BRT worker warm-starts every draw from the full-data fit, whose zero part is
  saturated (zero intercept -234.6), so the zero-part gradient is ~0 and Newton moves only the count part: the zero
  coefficients come back unchanged and beta is about the plain-Poisson coefficient. The slow path's fresh subset copy
  has no warm start and reaches a lower nll on every differing draw checked (0.7-15.7 units). The likelihood itself
  has no finite maximum here (separated zero part: even the full-data beta is 0.585 / 0.546 / 0.508 depending on
  start and optimizer). Recommendation: guard, not document. Fix it under v1.0.6-TODO-30 candidate 1 (no warm start
  from a saturated or ridge zero part) and add the BRT reusable worker to that TODO's scope; v1.0.6-TODO-152 covers the
  separation itself. No code change here. (4) Already tracked, not in v1.0.6 or v1.1.0: v1.4.0-TODO-17 (moved from
  v1.1.0-TODO-17f; `marginal_estimand_report.md` TODO-10) extends `set_estimand` to ZeroInflatedNegBin and
  HurdleNegBin. `InferenceCountNegBin` has no `set_estimand` either, and that TODO does not name it. Owner: decide
  whether the "attempt to apply non-function" error should become a clear "estimand not supported" error sooner.
  - Decided 2026-11-19 (owner): item (3) folded into v1.0.6-TODO-30 (cold start from a saturated zero part); see [DECISION-v1.0.6-TODO-208a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-208a).
  - Decided 2026-11-19 (owner): item (4) clear "estimand not supported" error now, NegBin added to v1.4.0-TODO-17; see [DECISION-v1.0.6-TODO-208b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-208b).
  Item (4) DONE 2026-11-19 (agent, uncommitted): the `Inference` root now
  has `set_estimand()` and `get_supported_estimands()`, which stop with a classed `edi_estimand_not_supported` error
  naming the class, and `get_estimand()`, which returns `"conditional"` (the existing `is.function(get_estimand)`
  probes in the zero-augmented and registry code already treat a missing method as `"conditional"`). Classes composing
  `MarginalEstimand` replace all three, so the 8 supporting classes are unchanged; the other 98 concrete classes (the
  three NegBin ones among them) get the new error. `InferenceCountNegBin` added to v1.4.0-TODO-17. Test:
  `test-estimand-not-supported-classed-error.R`; registry delta and migration baselines re-pinned.
- [ ] TODO-209 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-205 agent): **Leftovers from the identity-binomial
  randomization fix.** (1) `InferenceIncidLogBinomial`'s `compute_treatment_estimate_during_randomization_inference`
  still refits from a drifting warm start (it checks convergence and passed the sweep); consider returning
  `self$compute_estimate()` as TODO-205 did. (2) C++: `fast_identity_binomial_regression_cpp` uses the warm Fisher
  matrix from another assignment on its first Newton step, so the line search stalls (~30% of draws); callers now
  refit cold, but the kernel should recompute the information at the start (needs owner build). (3) The identity-binomial
  MLE near the mu = 0 bound is accurate to ~1e-6 at the default tol, so exact-tie draws depend slightly on warm-start
  order; tightening tol moves stored estimates by ~1e-6 (owner decision). (4) Regenerate rand-p / bootstrap /
  comprehensive CSV rows for `InferenceIncidBinomialIdentityRiskDiff`.
  - Decided 2026-11-19 (owner): (b) leave the default tolerance; see [DECISION-v1.0.6-TODO-209](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-209).
  Items (1) and (2) DONE 2026-11-19 (agent, uncommitted; item (2) PATCHED, needs owner build); item (4) still open.
  (1) `InferenceIncidLogBinomial`'s `compute_treatment_estimate_during_randomization_inference` now returns
  `self$compute_estimate(estimate_only = estimate_only)`, as TODO-205 did (it no longer refits or overwrites the warm
  start). Observed estimates and rand p-values unchanged on the fixtures checked (Bernoulli n = 40, seeds 1-4: two seeded
  calls identical, worker == slow path). Test `test-log-binomial-rand-pval-worker-slow-path-agree.R`; the reference test
  `test-log-binomial-randomization-estimate-refit-...-reference.R` now clears the fit caches as a draw loader does.
  (2) `fast_log_binomial_regression.cpp`: in both `fit_constrained_binomial_cpp_impl` and the weighted impl, when the
  first step built from a supplied warm Fisher (or warm working weights) is rejected by the line search, the fit is
  redone from the cold start, so it returns exactly a cold call's result (all four identity/log, plain/weighted kernels).
  Recomputing the information at the warm start, as first proposed, was tried and dropped: these warm starts often sit
  next to a mean bound, where the huge working weights make the Newton increments tiny, so the fit reported
  converged = TRUE short of the MLE (draw 18 of the TODO-205 fixture: 0.1439 vs 0.1503, log-lik 2e-3 lower). Kernel
  swap (sourceCpp, old vs new, 6 fixtures x 150 draws per kernel): every fit the old kernel converged is bit-identical;
  of the old stalls, 130/138 (identity), 135/150 (identity weighted), 183/220 (log), 73/108 (log weighted) are now
  identical to the cold call; the rest are not first-step rejections (mostly iteration-cap fits) and are unchanged.
  R-level identity-class results are unchanged (TODO-205's cold retry, which stays, already gave the cold answer).
  Separate pre-existing issue, not fixed: from a start near a mean bound the relative-change and KKT tests can pass short
  of the MLE (same mechanism as above, also with a warm beta and no Fisher); deserves its own TODO.
  Test `test-constrained-binomial-kernel-stale-warm-fisher-restarts-cold.R` (passes with the swapped kernel, fails on the
  installed one until the owner rebuilds).
  Item (4), not run: regenerate in the gitignored `comprehensive_tests_results_nc_1_incidence.csv` the resampling rows
  (rand, rand-bootstrap, bootstrap, Bayesian bootstrap, m-out-of-n, subsampling, jackknife, parametric and LR bootstrap)
  of `InferenceIncidBinomialIdentityRiskDiff` (TODO-205) and `InferenceIncidLogBinomial` (item (1) rand rows; item (2)
  draws that used to stall to NA), then those classes' rows in the tracked `comprehensive_tests_{mse,coverage,size,
  power}.csv` and in `calibration/calibration_study_accepted.csv`, `calibration_fast_tier_accepted.csv`
  and `comprehensive_results_audit_baseline.csv`. Point-estimate and asymptotic rows do not change.
- [x] TODO-210 (added 2026-11-19, coordinator; from the v1.0.6-TODO-207 agent; OWNER DECISION): **LR-bootstrap CI
  leftovers.** (1) The three new LR-bootstrap CI NA reasons (`lik_ratio_bootstrap_ci_pval_at_estimate_unavailable`,
  `..._rejects_at_estimate`, `..._bound_not_found`) warn but are not recorded in `procedure_failure_reason`; record
  them? (2) The LR-bootstrap CI and p-value don't check `B` up front: with B < 2/alpha - 1 the CI can never be found and
  this is only reported after the search; add an up-front warning or error?
  - Decided 2026-11-19 (owner): (a) record the three LR-bootstrap CI reasons; see [DECISION-v1.0.6-TODO-210a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-210a).
  - Decided 2026-11-19 (owner): (b) error up front when B < 2/alpha - 1; see [DECISION-v1.0.6-TODO-210b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-210b).
  Done 2026-11-19 (agent, uncommitted): (1) the three reasons are recorded via `edi_param_boot_record_and_warn_na()`
  under their own key `procedure_failure_reason[["lik_ratio_bootstrap_ci"]]` (as `rand_bootstrap_ci`), one warning
  each, Wald state kept; `edi_resampling_procedure_for_reason()` maps `^lik_ratio_bootstrap_ci_` ahead of the
  primary-fit `*estimate_unavailable` rule (else `..._pval_at_estimate_unavailable` wiped the Wald SE); the CI clears a
  stale reason when it re-runs. (2) The p-value is `max(2 / (n + 1), (1 + n_exceed) / (n + 1))`, so its floor is
  2 / (B + 1) and the CI needs B >= 2 / alpha - 1 (39 at 0.05, 199 at 0.01); `edi_assert_lik_ratio_bootstrap_ci_B()`
  errors ("B must be at least 39 for alpha = 0.05 ...") in the base CI and, ahead of their nonestimable short-circuit,
  in the Poisson and count-likelihood wrappers. The p-value takes no alpha, so it gets no check. Defaults (B = 199,
  alpha = 0.05) pass; `run_all_inference()` with alpha < 0.01 now reports this error in the row message.
  Orphan benchmark scripts `R/benchmark/heavy_paths.R` (PB = 10) and `heavy_only.R` (PB_H = 5) now error / time an
  error (not changed). Test `test-lik-ratio-bootstrap-ci-minimum-B-and-recorded-na-reasons.R`.
  Follow-up (owner, 2026-11-19; agent, uncommitted): `run_all_inference()` now errors before any fitting when CIs are
  on, a `"param_boot"` task is built and the effective B (the new `B` argument, else the method default 199) is below
  2 / alpha - 1, telling the user to pass a larger `B`: `run_all_inference_check_param_boot_ci_B()`, test
  `test-inference-suite-param-boot-ci-minimum-B-errors-before-fitting.R`. New `run_all_inference(r = NULL, B = NULL)`
  (owner, 2026-11-19): `r` reaches `"rand"` (its `r`) and `"rand_bootstrap"` (its `B`), `B` reaches `"bootstrap"`,
  `"bayes_boot"`, `"param_boot"` and `"param_boot_direct"` (their `B`), p-values and CIs, sequential and fork paths;
  recorded as `out$resample_counts`; NULL adds no argument, so every call is unchanged (a results_table identical()
  check against HEAD's suite is not possible: two seeded HEAD runs already differ in the bootstrap-t / BCa p-values). The Bartlett-approx Monte-Carlo `B` is not wired. Test
  `test-inference-suite-r-and-B-reach-resampling-procedures.R`. No such check for the other CI sentinels:
  bootstrap / Bayesian-bootstrap / param-boot-direct are quantile CIs with no p-value floor, the Bartlett-approx CI is
  asymptotic after a Monte-Carlo factor, and the rand (r = 501, floor 2/r on finite draws) and rand-bootstrap
  (B = 501) inversions have floors that depend on their search controls, so the bound is not certain.
- [x] TODO-211 (added 2026-11-19, coordinator; from the v1.0.6-TODO-210 agent): **Leftovers of the LR-bootstrap minimum-B
  check.** (1) OWNER DECISION: the orphan benchmark scripts `R/benchmark/heavy_paths.R` (PB = 10, now hard-errors) and
  `R/benchmark/heavy_only.R` (PB_H = 5, times the error inside tryCatch) — raise to B >= 39, pass alpha = 0.2, or delete
  (nothing references them). (2) `compute_param_bootstrap_confidence_interval()` (bias-correction family) has no
  alpha-vs-B check; decide whether one applies and add it.
  Item (2) DONE 2026-11-19 (agent, uncommitted): no check is needed, so none was added. The method has a single
  CI type, the "basic" reflected interval `2 * theta_hat - quantile(finite_reps, c(1 - alpha / 2, alpha / 2))`, from
  one batch of replicates at the unrestricted fit; it inverts no p-value, so the 2 / (B + 1) floor behind
  `edi_assert_lik_ratio_bootstrap_ci_B()` does not apply. `stats::quantile()` (type 7) is defined for every
  probability in [0, 1] and any number of draws (it interpolates between the two smallest or largest draws when
  alpha / 2 < 1 / (n - 1), and returns the single value when n = 1), so with the existing
  `min_number_usable_samples` gate (default 5, and B >= it is already asserted) the CI is never NA because B is small
  for alpha. Small B only leaves the tail unresolved (the bound is about the most extreme draw, so the interval
  undercovers), which is a soft property, not a certain bound, and the number of finite draws is only known after
  the run. Its p-value companion `compute_param_bootstrap_pval()` has the 2 / (B + 1) floor but takes no alpha.
  - Decided 2026-11-19 (owner): delete the orphan `heavy_paths.R` / `heavy_only.R` scripts (done); see [DECISION-v1.0.6-TODO-211](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-211).
  Closed 2026-11-20 (coordinator): items (1) and (2) are both done.
- [x] TODO-212 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-204 agent): **Vacuous NA-equals-NA goldens and
  fixture follow-ups.** (1) Several migration goldens compare NA with NA because r or B = 9 is below the 10-finite-draw
  minimum, so they can't catch a regression: simple mean difference (rand p-value, bootstrap CI, bootstrap p-value),
  simple Wilcoxon (rand p-value, rand-bootstrap p-value), `test-incid-risk-diff-migration-golden.R` (rand and
  rand-bootstrap p-values, legacy and migrated). Raise r / B to >= 10 finite draws (as v1.0.6-TODO-202 did) and re-pin.
  (2) ZOIB golden test 3 lets two `edi_procedure_na_warning`s through; muffle or expect them by class. (3) OWNER
  DECISION: bump `EDI_TUNING_SCHEMA_VERSION` so saved `tune_EDI_for_this_machine()` policies (timed on covariate-dropped
  continuous / proportion / survival fits before TODO-204) are invalidated, or leave them valid. Also regenerate the
  `scripts/reused_worker_bitforbit_sweep.R` before/after baseline (its arm data changed).
  Items (1) and (2) DONE 2026-11-19 (agent, uncommitted); item (3) still open (owner decision). (1) Simple mean
  difference: rand p-value r = 12 (0.1667); the bootstrap CI and p-value were NA not from the 10-draw floor but from
  the default BCa type's order-statistic boundary (`edi_bootstrap_bca_boundary_warning`): the CI first comes back
  finite at B = 29 and the p-value only at B = 99, so both now use B = 99 (CI 0.0176 to 0.9008, p 0.1487). Simple
  Wilcoxon: rand p-value r = 12 (0.6667), rand-bootstrap p-value B = 12 (0.1667); the KK Wilcoxon rand p-value in the
  same file had the same r = 9 NA and now uses r = 12 (0.1667). `test-incid-risk-diff-migration-golden.R` now runs
  its rand calls at r = 12 and its rand-bootstrap calls at B = 12 (file-local `risk_diff_method_calls`, the shared
  harness is unchanged) and pins both p-values (0.1667) on the legacy and the migrated side, with a check that both
  pinned labels were reached; the two sides agree. Every new pinned value is finite. (2) ZOIB golden test 3 now
  expects exactly one `edi_procedure_na_warning` per route (reason `jackknife_extreme_summary`) and muffles them.
  Not done: the simple-Wilcoxon jackknife goldens still let four `wilcox_hl_jackknife_not_supported` warnings
  through (not in this TODO's list).
  - Decided 2026-11-19 (owner): item (3) bump `EDI_TUNING_SCHEMA_VERSION` 1 -> 2 (done); see [DECISION-v1.0.6-TODO-212](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-212).
  Done by the coordinator (uncommitted at the time): bumped in `R/EDI/R/local_machine_tuning_persistence.R`.
  Wilcoxon jackknife goldens DONE 2026-11-20 (agent, uncommitted): in `test-simple-wilcox-migration-golden.R` the four
  simple-Wilcoxon jackknife NA goldens (which leaked four `wilcox_hl_jackknife_not_supported` warnings) and the four KK
  Wilcoxon ones (NA vs NA under `suppressWarnings`) are replaced by `expect_wilcox_jackknife_unsupported()`, which
  asserts the unsupported-procedure contract for all five jackknife methods (bias estimate added): exactly one classed
  `edi_unsupported_procedure` warning with the documented reason (`wilcox_hl_jackknife_not_supported` /
  `kk_wilcox_hl_jackknife_not_supported`), the cached reason, an NA result of the right length, and
  `is_nonestimable("any")` still FALSE. File passes with NOT_CRAN=true: 93 expectations, 0 failures, 0 warnings.
- [x] TODO-213 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-187 agent; OWNER DECISION, changes results):
  **`DesignSeqOneByOneiBCRD`'s realized assignment and its randomization redraws round the treated count differently.**
  When `n * prob_T` ends in .5, `assign_wt()` uses R's `round()` (half to even) but `generate_permutations_ibcrd_cpp()`
  (`R/EDI/src/generate_permutations.cpp` ~L185) uses `std::round` (half away from zero): n = 21, prob_T = 0.5 gives 10
  treated in the realized sequence but 11 in every redraw, so the randomization distribution is wrong for about half
  of odd n at the default prob_T. Options: (a) R side uses `floor(x + 0.5)` (changes some realized allocations);
  (b) `draw_ws_raw` passes `round(n * prob_T) / n` to the kernel (keeps realized allocations, changes only redraws).
  Check `DesignFixediBCRD` and any other design that computes a target count in both R and C++ for the same mismatch.
  - Decided 2026-11-19 (owner): (b) pass the realized treated count to the kernel; see [DECISION-v1.0.6-TODO-213](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-213).
  Agent started.
  Done 2026-11-19 (agent, uncommitted; R only, no rebuild): `DesignSeqOneByOneiBCRD`'s `draw_ws_raw` now passes
  `round(n * prob_T) / n` as the kernel's prob_T, so its `std::round` lands exactly on the realized count. Realized
  allocations identical to HEAD (9 (n, prob_T) configs x 3 seeds, incl. the TODO-187 goldens); redraws now match the
  realized count at every tie (n = 21/0.5: 11 -> 10, n = 10/0.25: 3 -> 2, n = 14/0.75: 11 -> 10, n = 22/0.75: 17 -> 16);
  non-tie redraws unchanged. Roxygen "Rounding of the treated count" paragraph in both iBCRD classes (not
  roxygenized). Other designs: `DesignFixediBCRD` draws realized and redraws from the same kernel, so they always agree
  (ties round up there, documented; it now differs from the sequential design by one treated subject at a tie: left for
  the owner, changing it would change realized fixed allocations). SPBR / random block size assert `bs * prob_T` is an
  integer (no tie possible); greedy, greedy D/A-optimal, optimal and rerandomization's batch/R paths pass R's `n_T` to
  C++; blocking is R only; Bernoulli, Efron, Atkinson, Pocock-Simon and cluster have no target count. Found, not fixed:
  `DesignFixedRerandomization` with `prop_acceptable` and prob_T = 0.5 draws from `complete_randomization_forced_balanced_cpp`
  (`n / 2`, floor) while its other paths use `round(n * prob_T)`: n = 23 gives 11 treated with `prop_acceptable` and 12
  with `obj_val_cutoff` (realized and redraws agree within each path, so the null is right; the documented count is
  not). One-line fix: use the forced-balanced kernel only when `n %% 2 == 0`; changes realized allocations for
  n = 3 mod 4, so owner call. New test `R/EDI/tests/testthat/test-ibcrd-tie-rounding-redraw-count.R` (170; 19 fail on
  HEAD's code).
- [x] TODO-214 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-12 agent): **Follow-ups of the bootstrap
  valid-fraction guard.** (1) `R/package_tests/testthat_bulk/test-brt-sequential-mc-pval-cache-shortcircuit-and-stopping-reference.R:63`
  fails (`tg()` returns length 4, expected 300); it calls the private sequential-MC helper directly. Find which of
  today's changes caused it (v1.0.6-TODO-12, -166, -185, -207 touched nearby code) and fix the code or the test.
  (2) The studentized rand-bootstrap path and the sequential-MC path drop non-finite draws even with `na.rm = FALSE`;
  make them honour `na.rm` or document why not. (3) Regenerate the public-argument drift artifacts in
  `R/package_tests/` (`public_api_inventory.csv`, argument-contract registry, checkmate contracts) for
  `min_fraction_usable_samples` and the other new arguments of this round (`InferenceSuite` `r` / `B`).
  Done 2026-11-19 (agent, uncommitted): (1) the failure is at line 108 (the last test), not 63: bisected by swapping
  `compute_two_sided_brt_pval_with_sequential_mc()` from older revisions over `load_all`; passes at `3dabce47^`, fails
  from `3dabce47` (v1.0.6-TODO-166: a prefix with too few finite draws draws the next batch instead of returning NA).
  Intended, so the test was updated (an all-NA pool now draws 300/600/900/1000, then NA). (2) `na.rm = FALSE` on
  `compute_rand_bootstrap_two_sided_pval()` now returns NA on any invalid null draw on every path, with one
  `edi_bootstrap_nonfinite_na_warning` per object (own flag and wording; silent inside resampling): studentized /
  symmetric-percentile-t (a draw also needs a finite positive SE; it used to drop them), sequential MC (new
  `na.rm` argument of the private helper, default TRUE; the first evaluated prefix or cached full distribution with a
  non-finite draw ends the loop; documented that an early stop on an all-finite prefix never sees the later draws, so it
  can be finite where the one-shot path is NA), and percentile / smoothed (were a silent NA). `na.rm = TRUE` unchanged;
  the CI search passes `na.rm = TRUE`. The SMC path still does not apply `min_fraction_usable_samples`. Tests: new
  `R/EDI/tests/testthat/test-rand-bootstrap-pval-na-rm-false-every-path.R` (36), the BRT seq-MC reference test (27).
  (3) Regenerated `public_api_inventory.csv`, `public_argument_baseline_gap_report.csv`,
  `checkmate_argument_contracts.csv` and `public_argument_contract_registry.csv` with their generators
  (`run_drift_generators.R`, first three steps of `drift_artifacts.sh`). `min_fraction_usable_samples` had no contract
  rows because it is checked through the wrapper `assert_min_fraction_usable_samples()`; the extractor now records it as
  `assertNumeric(len = 1, lower = 0, upper = 1)` (as it does for `assertBootstrapArgs()`): 303 contract rows, incl. the
  g-comp RR subsampling / m-out-of-n arguments added today. `run_all_inference` `r` / `B` are in (assertCount). Most of
  the diff is source line numbers moved by today's uncommitted edits; the downstream argument-combination CSVs were not
  rerun (full `drift_artifacts.sh regenerate` does that at push).
- [x] TODO-215 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-201 agent): **Information-source follow-ups.**
  (1) OWNER DECISION: for every `StandardModelCache` class the public Wald p-value and CI use the C++ `ssq_b_j`
  (observed information) whenever it is finite, while `get_standard_error()` follows the information preference; under
  "fisher" the two disagree (invisible for canonical-link GLMs, visible for the ordinal links after TODO-201). Decide
  which wins. (2) C++ (needs owner build; with v1.0.6-TODO-203): the `fisher_information` field of the four ordinal
  kernels holds the observed Hessian; rename it or fill it from `expected_hessian()`; guard `expected_hessian()`'s
  `p[0]` read when K = 1. (3) `InferenceOrdinalPartialProportionalOddsRegr` has no Fisher information; it needs its own
  derivation. Derivation and tables: `R/package_metadata/audits/research_findings/2026-11-19-ordinal-cumulative-link-expected-information.md`.
  - Decided 2026-11-19 (owner): item (1) (b) Wald always uses observed information; "fisher" stays the score default; see [DECISION-v1.0.6-TODO-215a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-215a).
  Agent started 2026-11-19.
  Item (1) DONE 2026-11-19 (agent, uncommitted; box stays open for items 2-3): the one place a Wald SE was
  formed from the preference was `compute_standard_error_from_information_matrix()`
  (`inference_ext_information_matrix.R`), behind every `get_standard_error()` that consults the information matrix
  (StandardModelCache, logit, Poisson, binomial identity, count likelihood, beta, KK GLMM, zero-augmented). It now
  asks for the observed information first, falls back to the configured source only when a class exposes no observed
  information, and no longer changes `get_information_source_used()` (which now reports the score test's source).
  `get_information_matrix()` gained a `preference` argument; no new private methods. So `get_standard_error()` (the
  Wald fallback when `ssq_b_j` is not finite, the CI-inversion seeds and step sizes, the parametric-bootstrap LR CI
  seed, and `InferenceSuite`'s `se` column) is observed for every class. Seeds follow observed, as they did before
  v1.0.6-TODO-201. Checked on 87 class x response x preference cells: estimates and public Wald p-values / CIs are
  identical() to before everywhere, and so are score p-values. Under "fisher"/"auto", the four cumulative-link ordinal
  classes now give the observed `get_standard_error()`, and their score CIs move within the root finder's tolerance
  (endpoint p-values within 5e-4 of alpha before and after; the largest endpoint shift was 2e-3, cauchit). Their LR CIs
  move by about 1e-7. `get_summary()` was already observed. Docs: `InferenceAsympLik` details plus
  `set_information_preference()`, `get_supported_information_preferences()`, the getters, and the Wald/score
  methods (also StandardModelCache and Poisson); `[EfronHinkley1978]` added to `REFERENCES.md`. Test
  `test-wald-se-uses-observed-information.R`; the TODO-201 test and `test-ext-information-matrix.R` were updated. Found,
  not changed (owner decision): the public Wald SE is the EXPECTED information (IRLS X'WX, as `glm()` reports for
  non-canonical links) for `InferenceIncidProbitRegr` (whose `observed_information` closure is X'WX too, so it has no
  observed information), `InferenceIncidBinomialIdentityRiskDiff` and `InferenceIncidLogBinomial` (observed SE is
  0.5% / 7.7% higher on the test fixture). In those two, and in `InferenceContinKKGLMM` / `InferenceCountKKGLMM`,
  `get_standard_error()` (observed information matrix) differs from the public Wald SE, so the Wald fallback, seeds and
  `InferenceSuite`'s `se` column disagree with the reported Wald CI. That was already true before this change.
  Item (2) DONE 2026-11-20 (agent, uncommitted; PATCHED, needs owner build): the four cumulative-link kernels
  (`fast_ordinal_regression.cpp`, `ordinal_fixed_link_internal.h`) no longer return `fisher_information`; the observed
  information stays as `observed_information` / `information` (`information_type = "observed"`). Renamed rather than
  filled from `expected_hessian()`: every R caller fed the field to the next fit's warm start, so filling it would have
  moved warm-start trajectories, and it would add an expected-information pass to every resampling fit. The R
  readers (four cumulative-link classes and their likelihood-test spec, PropOdds weighted refit, PartialPO fast path,
  ordinal G-computation, ordinal KK combined weighted refit) now read `observed_information`, the same matrix on the
  old build. `expected_hessian()` (`ordinal_fixed_link_helpers.h`) no longer reads `p[0]` when K = 1 (returns zeros;
  the old code fails `_GLIBCXX_ASSERTIONS`), and is `identical()` to before for K = 2..5 x 4 links. Kernel swap of the
  four .cpp files: kernel outputs identical apart from the dropped field; an 18-cell class battery (6 classes x 3 data
  sets: estimate, Wald / score / gradient / LR p and CI, bootstrap, randomization) is `identical()` between swapped
  HEAD kernels and swapped patched kernels (sourceCpp's -O3 -march=native build differs from the portable .so in a
  few last-digit CI endpoints and one randomization draw, for HEAD and patched code alike). Python's
  `fast_ordinal_*` dicts lose the `fisher_information` key too (no Python test or stub used it). Roxygen in the four
  .cpp files and RcppExports.R edited; Rd not regenerated. Test
  `test-ordinal-cumulative-link-kernels-return-observed-information-only.R` (48; 9 field assertions fail on the old
  build, all pass swapped); five kernel reference tests switched to `observed_information`.
  Item (3) derivation DONE 2026-11-20 (agent, uncommitted). Observed and
  expected information of the partial-PO cumulative logit in clm's `nominal` parameterization:
  `ordinal_partial_po_information()` (`inference_ordinal_partial_proportional_odds.R`, not wired in). Observed equals
  -numDeriv Hessian and gives `ordinal::clm`'s treatment SE; expected gives `VGAM::vglm(cumulative())`'s (VGAM's vcov
  is Fisher scoring's expected information); with no nonparallel columns they reduce to the PropOdds kernel Hessian and
  `ordinal_cumlink_expected_information()`. Test `test-ordinal-partial-po-information-observed-matches-clm-expected-matches-vgam.R`
  (12). The class has no likelihood tests (`likelihood_tier = "none"`), so a Fisher information has no consumer; the
  real issue is that its published Wald SE is EXPECTED on the VGAM path (any nonparallel column), against the item-1
  rule, while the fast-solver and clm fallback paths are observed. Moving the VGAM path to observed changes the
  treatment SE by a median 0.4-0.8% (max 1.0%) at n = 60-100, 0.2% (max 0.5%) at n = 300, 0.05% (max 0.2%) at
  n = 1000; estimates do not change. Tables in the
  research note (section 7). Also found, not changed: in the four cumulative-link classes `standard_model_cache_shared()`
  overwrites the params + information warm start that `generate_mod()` just set with `type = "beta"`, `b = c(0, beta_T)`
  and no information, so later refits cannot use a full-length warm start (pre-existing; proposed as a new TODO).
  - Decided 2026-11-20 (owner): item (3) option (a), observed SE at the VGAM MLE; see [DECISION-v1.0.6-TODO-215b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-215b).
  Item (3) DONE 2026-11-21 (agent; R only): when the class fits through
  `VGAM::vglm`, its Wald SE is now the observed information at VGAM's estimate (new top-level helper
  `ordinal_partial_po_vgam_observed_se()`, which maps VGAM's coefficients into `ordinal_partial_po_information()`'s
  parameterization), so VGAM, the fast solver and the clm fallback all publish observed-information SEs. The estimate
  is still VGAM's. `get_standard_error()`, the Wald / asymp CI and p-value, and `benchmark_asymp_two_sided_pval_breakdown()`
  all read the same cached SE; the class has no CI inversion, so there are no seeds to align. If the observed
  information is non-finite or not positive definite (Cholesky fails: VGAM did not stop at a maximum), the VGAM fit
  gets SE = NA and the cascade moves on to `ordinal::clm` for the estimate and SE; the expected information is never
  substituted. Bootstrap-weighted VGAM refits still report no SE. A/B on 160 simulated data sets (n = 40, 60, 100,
  300; one nonparallel covariate, K = 4) against the old expected-information SE: every estimate `identical()` (full
  and estimate-only paths), so the PD fallback never fired where the old code used VGAM, SE change median 0.1% / 0.8% / 0.3% / 0.2% and max
  5.0% / 5.7% / 1.6% / 0.9%. Roxygen `@details` (information source, sizes, fallback) and `[EfronHinkley1978]`
  reference added to the class; Rd not regenerated. No new private methods, so no registry / baseline change. Tests:
  `test-ordinal-partial-po-information-observed-matches-clm-expected-matches-vgam.R` (21; the pinning test now checks
  observed = helper at VGAM's estimate = clm, the Wald CI / p-value use that SE, and a mocked non-PD information falls
  back to clm), `test-partial-odds-vgam-primary-backend-reference.R` (its SE reference is now clm's observed SE).
- [ ] TODO-216 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-206 agent): **Near-zero-width Zhang exact CIs
  on KK21stepwise.** Two fresh comprehensive rows (`InferenceIncidExactZhang`, KK21stepwise `~.`, pima, beta 0.5): rep 6
  [0.1933261, 0.1933269] with p = 0.002, rep 14 [-0.2623787, -0.2623780]. Unverified guess: the combined (matched +
  reservoir) p-value never reaches alpha, so the bisection in `zhang_bisect_ci_boundary()` collapses to a point.
  Reproduce from the comprehensive seeds, find the cause, and return NA with a recorded reason (or the right interval)
  instead of a degenerate one. Also prune the stale `low_power|incidence|InferenceIncidExactZhang` results-audit
  baseline entry when the 29 new survival audit findings are triaged.
  DONE 2026-11-19 (agent, uncommitted), the CI part; the baseline prune stays open (it waits on the survival triage).
  Cause: the confidence set is empty. In both cases the discordant pairs and the reservoir point to incompatible
  effects (rep 6: pairs 13:7, reservoir n11..n00 = 0/6/9/1; rep 14: pairs 9:13, reservoir 6/2/0/6), and the largest
  combined Fisher p-value over a 1e-4 grid on [-8, 8] is 0.00223 and 0.0428, below alpha = 0.05 (Stouffer/min_p max
  0.0074/0.0154 and 0.049/0.076). `zhang_ci_inside_point()` then returned the rejected maximiser and both bisections
  collapsed onto it. Fix (`inference_helpers_zhang.R`): when the candidates and `optimize()` are all rejected, new
  `zhang_ci_inside_point_grid()` scans a 2001-point grid one unit beyond the search range and refines the 5 best points;
  if nothing is accepted, `zhang_ci_exact_combined()` returns `c(NA, NA)`, records `exact_ci_empty_acceptance_set`
  (procedure `compute_exact_confidence_interval`) and emits an `edi_procedure_na_warning`; a later accepted call
  clears the reason. CIs whose search started from an accepted point are byte-identical: 198/200 pima KK21stepwise
  comprehensive fits (both betas, both formulas, reps 1-50; the 2 others are the repros, now NA), 23/23 on the other
  stored matching slices (KK21stepwise cancer beta 0 reps 1-7, cancer 0.5 rep 2, fuel 0 rep 35; FixedBinaryMatch
  cancer 0 reps 1-7), and 5717/5717 such
  CIs out of 6000 synthetic KK fits x alpha x combination method; the other 283 had a rejected start (268 now NA, 9
  formerly degenerate now a real interval, 6 formerly with one endpoint at a rejected point now corrected). Roxygen
  `@return` in `man-roxygen/exact-zhang-compute-exact-confidence-interval.R` (Rd not regenerated). Test:
  `testthat_bulk/test-zhang-exact-ci-empty-acceptance-set.R` (32). Stored rows that would change: only the two
  KK21stepwise `~.` pima beta 0.5 rep 6 / rep 14 `compute_exact_confidence_interval` rows (to NA). Open: the
  minlike exact p-values make the acceptance set non-convex in about 2.5% of ordinary CIs (8 of 323 checked), and
  the bisection returns only the piece around the start point; not changed here (proposed as a new TODO).
- [x] TODO-217 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-132 agent): **KK IVWC leftovers.**
  (1) BUG: `InferenceSurvivalKKStratCoxPHIVWC`'s Bayesian bootstrap is all zeros (CI [0, 0]): the KKCompound
  `compute_estimate_with_bootstrap_weights` fallback reads `KKstats$y_matched_diffs`, which this class never creates
  (`sum(NULL)/...` = 0). Fix it, and check every IVWC class without `compute_weighted_estimate_ivwc` for the same
  fallback. (2) `InferenceSurvivalKKRankRegrIVWC`: on one draw (seed 3, rare covariate) worker and slow path give the
  same matched beta but different ISMB variances (0.144 vs 0.097), estimate off by 0.28; suspect the data-hash seed in
  `.kk_rank_regr_aftsrr_seed` seeing different pair-id labels. (3) `InferenceAllKKWilcoxIVWC`'s worker returns the W
  statistic by design (2026-10-12 fix); confirm no nonparametric-bootstrap path reaches it on a non-sequential matched
  design. (4) The Weibull frailty IVWC classes' `compute_treatment_estimate_during_randomization_inference` still uses
  the observed-data IVW weights with a 0.5 fallback; check it against the TODO-132 rule.
  Status 2026-11-19 (agent, uncommitted): DONE, all four items. (1) The generic fallback was wrong for 13 of the 14
  classes that used it (MeanDiff matched at uniform weights but kept the observed w_star; Newcombe got the matched
  mean difference alone, its KKstats has no w_star): StratCox 0 (BB CI [0, 0]); LWA Cox
  +2.64 and RankRegr +2.28 (raw survival-time differences; estimates -0.61 / 0.94); CondLogit 0.30 (risk difference
  for a log OR of 2.66); Prop quantile 0.14 (a mean difference, estimate 0.79); OLS / Contin quantile / Robust / Bai unadjusted mean
  differences; Weibull frailty Normal IVWC and Loggamma OneLik raw time differences. Fallback removed from both KK
  compound dispatchers (now a clear error); `w_info` carries the draw's row weights. Weighted refits of the class's
  own estimator (both halves refit under the weights, each half's variance from its weighted fit, IVW pooling as in
  `shared()`) via `compute_weighted_estimate_ivwc()` for StratCox (weighted stratified / plain `coxph`, model-based
  variance), LWA Cox (pair-clustered robust variance), OLS (WLS + HC2), CondLogit (weighted logit), MeanDiff
  (weighted means / variances; w_star no longer fixed at the observed value), Newcombe, RankRegr (`aftsrr(weights =)`,
  ISMB). Near-uniform weights reproduce `compute_estimate()` (1e-5; RankRegr within ISMB noise), BB sd ~ asymptotic
  SE on 3 fixtures each. Refused (`supports_bayesian_bootstrap()` FALSE + `EDI_INFERENCE_EXCLUDED_CAPABILITIES`,
  roxygen says so): Bai KK14/KK21, Contin/Prop QuantileRegr IVWC, RobustRegr IVWC, Weibull frailty Normal IVWC,
  Loggamma OneLik. Wilcox IVWC never had the BB component. (2) Cause: not pair-id labels but data-frame row names.
  `.kk_rank_regr_aftsrr_seed` hashed `dat` with its row names; `cbind()` with the covariate matrix carries them, and
  on draws whose model matrix is rebuilt the slow path has character row names, the worker automatic ones, so they
  drew different ISMB multipliers from identical data. The hash now ignores row names (observed-data fits have
  automatic row names, so reported results are unchanged; resampled replicates whose row names were non-automatic get
  new ISMB seeds). Worker = slow path on all 5 draws of the repro. (3) It does: on `DesignFixedBinaryMatch`, the
  m-out-of-n bootstrap, subsampling and the jackknife distribution reached the W-statistic worker (replicate means
  1.47 / 1.52 / 2.44 for an HL estimate of 0.63). The worker now returns W only for "rand" / "rand_bootstrap" (and
  a NULL operation, as before) and the estimate otherwise (0.56 / 0.59 / 0.62). (4) Three bugs, both classes: the
  fixed-sigma reservoir refit passed `fixed_idx = p_r` (one-based) instead of `p_r + 1`, pinning the last
  coefficient (the treatment coefficient without covariates) to log sigma (reservoir beta -0.03 vs 1.03); the halves
  were pooled with the observed variances from `cached_values`, or 50/50 when that cache was empty (duplicates,
  reused workers), so observed and permuted statistics were different functions (0.43 vs 0.25 vs estimate 0.63);
  Loggamma's `best_X_colnames_reservoir` was `c("w", "", ...)` (unnamed `KKstats$X_reservoir`), so the reservoir
  refit dropped every covariate. Now the statistic pools with the draw's own variances (fixed-nuisance fits,
  TODO-132 rule): it equals the estimate to <= 0.003 and is the same on a cache-cleared duplicate. Tests:
  `test-kk-ivwc-bayesian-bootstrap-replicates-match-estimator.R` (94),
  `test-kk-rank-regr-ivwc-worker-matches-slow-path-row-names.R` (13),
  `test-kk-wilcox-ivwc-worker-estimate-scale-by-operation.R` (12),
  `test-weibull-frailty-ivwc-randomization-statistic-matches-estimator.R` (10). Five bulk reference tests that
  pinned the old fallback rewritten (host, OLS, RankRegr: weighted-refit checks; Contin/Prop quantile: refusal);
  LWA component private list updated in `test-partial-likelihood-migration-baseline.R`. Registry delta
  (`compute_weighted_estimate_ivwc`, addition only) recorded in `inference_component_call_graph_helpers.R`. Rd pending roxygenize. NEWS line proposed, not added. Open:
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`'s own BB hook is a marginal-Weibull surrogate, not the IVW
  estimator (BB mean 0.55 vs 0.63; same TODO-132 question); weighted refits for the refused quantile classes (rq
  takes weights) could restore their BB.
- [x] TODO-218 (added 2026-11-19, coordinator; from the v1.0.6-TODO-30/-152 agent): **Zero-part separation warning
  follow-ups.** (1) OWNER DECISION: on ordinary count data with no excess zeros, ZIP's zero part saturates and ZINB
  falls back to its zero-inflation-off boundary fit, so the new `edi_zero_part_separation_warning` fires (about 12
  existing test files, and calibration runs without inflation). Options: keep it (it is true: the zero part is not
  identified), silence it for ZINB boundary fits only, or replace it with a softer message such as "no evidence of
  zero inflation". (2) `InferenceCountHurdleNegBin` (own C++ path) has no separation flag. (3) The 1e-5 eigenvalue
  threshold of the ridge rule comes from one sweep (ridge fits reached ratios up to ~1e-4, interior fits >= ~3e-4);
  revisit with a wider sweep.
  - Decided 2026-11-19 (owner): item (1) (c) a softer "no evidence of zero inflation" message; see [DECISION-v1.0.6-TODO-218a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-218a).
  Item (1) done 2026-11-19 (agent, uncommitted): `zero_augmented_zero_part_separation()` now also
  returns `no_inflation`: a separated zero-INFLATION part (never a hurdle part) whose ridge points only toward "no
  inflation", i.e. every zero logit <= qlogis(0.05) ~ -2.94 (`ZERO_AUGMENTED_NO_INFLATION_MAX_LOGIT`: no subject pushed
  toward a structural zero, no fitted inflation above 5%), or the ZINB zero-inflation-off boundary fit. Then
  `edi_zero_augmented_flag_zero_part_separation()` emits, once per object and never inside resampling, a `message()`
  of new class `edi_no_zero_inflation_message` (fields `n_to_zero`, `n`, `max_pi`, `max_abs_eta`, `component`)
  instead of the warning; zero rows are still NA, reason `"no_zero_inflation"`. Text when max pi <= 1%: "<Class>: no
  evidence of zero inflation: the fitted zero-inflation probability is essentially 0 for every subject, so the
  zero-inflation coefficients are not identified and are reported as NA; the count-part estimate is unaffected (a
  plain Poisson [negative binomial] model fits these data)."; otherwise "... driven to 0 for K of n subjects (at most
  P% for the rest) ..." without the plain-model clause. The 5% bound, not "every logit <= -10": on plain Poisson / NB
  data the MLE usually sends one arm to pi -> 0 and leaves the other at 0.5-4% (e.g. ZINB n = 500: 247 of 500 to 0,
  3.7% for the rest). `edi_zero_part_separation_warning` stays for any subject pushed to pi ~ 1 or sizeable inflation
  next to subjects driven to 0; note that on plain Poisson data with covariates in the zero formula the ZIP MLE often
  does push the few zeros at extreme covariate values to pi ~ 1 (4 of 6 seeds of a plain-Poisson sweep), and those
  keep the warning. Hurdle: no analogue (its zero probabilities model the observed zeros, so a saturated hurdle part
  is ordinary logistic separation), always the warning. Roxygen paragraphs in ZIP / ZINB / HurdlePoisson updated (not
  roxygenized). Tests: two new blocks in `test-zero-augmented-ridge-warm-start-and-zero-part-separation.R` (61 pass);
  `test-information-inverse-inference-typed-guards.R` switched to `suppressMessages(classes =
  "edi_no_zero_inflation_message")` (its fixture is the no-inflation case); `test-mixture-submodel-formulas.R` keeps
  the warning suppression (its fixture is real separation). In the other zero-augmented test files the remaining
  warnings are all real separation (subjects pushed to ~1), so those files were left as they are; all pass.
  Items (2), (3) done 2026-11-19 (agent, uncommitted). (2) `InferenceCountHurdleNegBin$generate_mod()` now calls
  `edi_zero_augmented_flag_zero_part_separation()` with the hurdle logistic part's information
  X_h' diag(p (1 - p)) X_h (new `zero_info` argument of that function and of `zero_augmented_zero_part_separation()`),
  `is_hurdle = TRUE`: always the warning, never the no-inflation message; reason recorded, count estimate kept; the
  internal `hurdle_coefficients` are kept (the parametric bootstrap simulates from them). 120-dataset check: HurdleNegBin
  and HurdlePoisson flags agree on 117; the 3 others are HurdleNegBin fit failures / treatment-only fallbacks (different
  hurdle design), not the rule. Test block added to `test-zero-augmented-ridge-warm-start-and-zero-part-separation.R`.
  (3) Sweep of 1200 datasets (n 24-400; no / -2.5 / -1 / 0 / 1 inflation logits; zero-part covariate effect 0 / 1 / 3;
  1-2 covariates; ZIP and HurdlePoisson; 2 cores; scratch `sweep/sweep.R`). The 1e-5 rule decides only fits with no
  numerically 0/1 zero probability and max |zero logit| >= 10: ZIP 118 of 1197 fits (591 had an extreme logit, 488 max
  |logit| < 10), hurdle 6 of 1169. ZIP min/max eigenvalue ratio there: 4 fits <= 1.35e-6 (one non-PD, 2.6e-8, 7.4e-8,
  1.35e-6), then a gap to 1.66e-4, 2.0e-3, ...; quartiles 0.021 / 0.036 / 0.054. Truth by moving 50 units along the
  flat eigenvector with the zero part fixed and the rest refit: the three low-ratio fits change the nll by -5e-7,
  -6e-7 (lower: a ridge) and +4.4e-5 (flat); the 1.66e-4 fit by +0.040 and the 2e-3 fits by +1.7..10.7 (interior).
  Hurdle middle-zone ratios 5.9e-3..5.3e-2, all interior by glm continuation. No misclassification: threshold
  unchanged. ZIP estimate vs pscl::zeroinfl: 1086 / 1197 agree to 1e-3; all but 3 disagreements are flagged (see the
  v1.0.6-TODO-195 follow-up for the 3).
  - Decided 2026-11-19 (owner): the 5% cutoff is confirmed; see [DECISION-v1.0.6-TODO-218b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-218b).
- [x] TODO-219 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-210 agent): **`InferenceSuite` is not
  reproducible under a fixed seed.** Two runs of the unchanged HEAD suite from the same `set.seed()` give different
  bootstrap-t and BCa p-values (e.g. 0.0299 vs 0.0279). Find which draws escape the seed (fork workers, lazy draw order,
  per-class RNG state) and make seeded suite runs reproducible; then verify that `r = NULL, B = NULL` results are
  identical to the pre-TODO-210 suite. Also: a user `B` below `min_number_usable_samples` (5) still fails per row in
  the parametric-bootstrap methods instead of up front.
  Done 2026-11-19 (agent, uncommitted): two seed escapes. (a) Fork path: each `mcparallel()` child (default
  `mc.set.seed = TRUE`, Mersenne-Twister) reseeds from the clock and PID, so every bootstrap / Bayesian-bootstrap /
  randomization draw changed run to run and differed from `num_cores = 1`. (b) Sequential path: tasks drew in turn
  from one global stream, and unseeded randomization permutations are cached on the design ("unseeded" key) and
  shared by every inference object on it, so the first rand task (or an earlier suite run or direct call on the same
  design) fixed the permutations every later task used, whatever the seed; reusing a design across seeded runs gave
  different results. Fix (`inference_suite.R`): one integer is drawn from the caller's stream; each task runs from
  `master + hash(result_name)` (`run_all_inference_task_seeds()`) inside `run_all_inference_with_task_seed()`, which
  restores `.Random.seed` and gives the task an empty design permutation cache, putting the design's own cache back
  afterwards; same wrapper on the sequential, fork and stand-in paths. Seeded runs now repeat exactly, `num_cores = 2`
  equals `num_cores = 1`, a task's result does not depend on which other tasks run, and the caller's stream advances
  by one draw. Direct method calls are unchanged; suite results under a given seed differ from before (breaking for
  pinned suite output). r = NULL, B = NULL check: with the TODO-219 seeding switched off, the TODO-210 suite equals
  `git show HEAD:R/EDI/R/inference_suite.R` loaded over load_all (identical() results_table without fit_secs:
  OLS + simple average diff, all default methods, 54 rows, CIs off, four alternating runs; logistic regression with
  wald / bootstrap / bayes_boot / param_boot_direct, CIs on). The TODO-210 agent's differing HEAD runs came from (b)
  (design reused across runs). Item 2: `run_all_inference_check_min_usable_B()` errors before fitting when the user's
  `B` < 5 and a "bootstrap" / "bayes_boot" / "param_boot" / "param_boot_direct" task runs. Tests
  `test-inference-suite-seeded-runs-reproducible.R`, `test-aa-fork-inference-suite-seeded-runs-reproducible.R`
  (real forks); the audit test `testthat_bulk/test-run-all-inference-fork-workers-seed-core-count-invariance.R` is
  unskipped and passes. Not covered: a small user `r` (rand / rand_bootstrap) is not checked up front.
  Also (coordinator, 2026-11-19, from the v1.0.6-TODO-214 agent): the rand-bootstrap sequential-MC path does not apply
  `min_fraction_usable_samples` (v1.0.6-TODO-12) with `na.rm = TRUE`; treat a short prefix as "draw more" and apply
  the check at the full B draws.
  DONE 2026-11-20 (agent, uncommitted; R only): `compute_two_sided_brt_pval_with_sequential_mc()`
  (`inference_all_abstract_rand_bootstrap.R`) takes `min_fraction_usable_samples` from the public p-value. With
  `na.rm = TRUE` a batch prefix whose valid fraction is below it is not a stopping point (next batch); at the full B
  draws, and on the cached-full-distribution shortcut, the one-shot check applies (same max(10, 10%) floor first) and
  the loop returns NA marked `too_few_valid_fraction`, which the caller records / warns through the existing
  `brt_valid_fraction_short()` (reason `rand_bootstrap_too_few_valid_replicates_fraction`, one
  `edi_procedure_na_warning`). A prefix that clears the check can still stop early (roxygen of `na.rm` /
  `min_fraction_usable_samples` updated; Rd not regenerated). Results change only where the old path stopped early
  on a prefix below the cap or returned a p-value from B draws below it. Test
  `test-rand-bootstrap-sequential-mc-applies-min-fraction-usable-samples.R` (15 pass); the v1.0.6-TODO-166 test
  `test-sequential-mc-pval-continues-past-nonfinite-prefix.R` now passes `min_fraction_usable_samples = 0` to the
  private loop (its fixture is 75% valid; it tests the finite-draw floor), 11 pass.
- [x] TODO-220 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-215 agent): **Wald SEs that are not observed
  information, and SE paths that disagree.** (1) OWNER DECISION: `InferenceIncidProbitRegr` exposes only expected
  information (its C++ `ssq` and all three spec closures, including `observed_information`, are X'WX), and
  `InferenceIncidBinomialIdentityRiskDiff` / `InferenceIncidLogBinomial` take their public Wald SE from the IRLS
  expected X'WX (as `glm()` does for non-canonical links; observed SE 0.5% / 7.7% higher on one fixture). Switch them to
  observed to follow the TODO-215 rule (probit needs a real observed-Hessian closure), or keep glm's convention and
  leave the documented exception. (2) In BinomialIdentityRiskDiff, LogBinomial, `InferenceContinKKGLMM` and
  `InferenceCountKKGLMM`, `get_standard_error()` (information matrix) differs from the public Wald SE (KK GLMM 0.2535 vs
  0.2948), so the Wald fallback, CI-inversion seeds and `InferenceSuite`'s `se` column disagree with the Wald CI the
  user sees; make them use the same SE.
  - Decided 2026-11-19 (owner): item (1) keep glm's expected-information convention; see [DECISION-v1.0.6-TODO-220](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-220).
  Item (2) done 2026-11-20 (see below).
  Item (2) DONE 2026-11-20 (agent, uncommitted; R only). Measured on 3 fixtures per class: `get_standard_error()`
  (also behind `compute_wald_*()`, which therefore disagreed with `compute_asymp_*()`) vs the Wald SE: identity
  0.0935 vs 0.0825, log-binomial 0.339 vs 0.305, Contin KK GLMM 0.2077 vs 0.2170 (sigma_b near 0: the spec's
  block-diagonal TODO-167 information vs the full observed Hessian), Count KK GLMM 0.187 vs 0.236 (model SE vs the
  jackknife-raised Wald SE of `.inflate_kk_onelik_standard_error_with_jackknife()`). Fix: `get_standard_error()` returns
  the cached Wald SE in all four (identity class body; new private override in `IncidenceLogBinomialLikelihoodSource`,
  registered in `contracts_mixins.R`; the shared KK GLMM mixin, so `InferenceOrdinalKKGLMM` too, which already agreed).
  The Wald SE was kept in each case (expected X'WX for the binomials per item (1); full observed Hessian for the LMM per
  the TODO-215 rule; max(model, jackknife) for the Poisson GLMM), so `compute_asymp_*()` is unchanged; what moves is
  `compute_wald_*()`, the Wald fallback, CI-inversion seeds and `InferenceSuite`'s `se` column. Roxygen: a
  "Wald standard error" paragraph in each class (Rd not regenerated). Test
  `test-binomial-and-kk-glmm-standard-error-paths-match-wald-interval.R` (81 pass). The new CI-inversion seed moved one
  pinned LogBinomial score-CI end by 1.4e-7 (root-finding tolerance), so
  `test-log-binomial-null-mle-boundary-kkt-score-reference.R` now uses 1e-6 there, with a comment.
- [x] TODO-221 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-209 agent): **Constrained binomial kernels can
  declare convergence short of the MLE near a mean bound.** From a start within ~1e-6 of a mean bound (mu = 0 or 1 for
  identity, mu = 1 for log), the huge working weights make Newton increments tiny, so the relative-change test and the
  KKT gate in `fit_constrained_binomial_cpp_impl` / `..._weighted_cpp_impl` (`R/EDI/src/fast_log_binomial_regression.cpp`)
  pass short of the MLE: TODO-205 fixture draw 18 reports converged at 0.1439 vs MLE 0.1503 (log-lik 2e-3 lower). It
  happens from a warm beta with or without a Fisher matrix; TODO-209's cold restart avoids it on first-step rejection
  only. Use a convergence test that is not fooled by tiny steps (log-likelihood change, scaled gradient / Newton
  decrement as in the logistic fix for v1.0.6-TODO-170). C++, needs owner build.
  DONE 2026-11-20 (agent; committed in 72ea20ba; PATCHED, needs owner build). Cause: the loop scores with the expected
  information (w = 1/(mu(1-mu)) identity, mu/(1-mu) log), which is ~1/distance next to a bound, while the observed
  curvature of a row the MLE does not hold there (y = 0 at mu -> 0 or y = 1 at mu -> 1, identity; y = 1 at mu -> 1,
  log) stays O(1); each Fisher step moved such a row ~7% of its distance, so the relative-change test passed.
  Draw 18 itself no longer reproduces (its warm start came from the dropped TODO-209 variant); the same mechanism
  reproduces on draw 17 of the same fixture warm-started from the previous draw: 0.0906 vs MLE 0.0912, ll 3e-4 lower,
  one y = 0 row stuck at mu = 1.2e-6 (MLE 0.009). Fix (both impls, all four kernels): before declaring convergence
  (relative-change test or KKT gate) the fitter takes the observed-information Newton step, projected off held bound
  rows; the point is accepted if its decrement, scaled to the part of the step that stays in the support, is
  <= tol * (2 |ll| + 0.1), or its relative increment <= 10 tol; otherwise the loop continues with observed-
  information Newton steps (singular observed information: check skipped). Draw 17 now converges to the MLE in 11
  iterations (gradient 1e-15). Kernel swap sweep (4 kernels x 20 fixtures x 40 draws x 6 start variants: cold,
  warm beta, warm beta + Fisher, chained, null fit, warm null fit; 19,200 calls): 18,775 `identical()` to the old
  kernel; 424 changed, all still converged and none worse (> 1e-8); 275 gain > 1e-5 in log-likelihood (max 0.02
  identity, 0.40 log); 1 old "converged" fit (weighted log, ll 2.5e-5 short) now hits maxit = 100 and reports
  converged = FALSE; no fit newly fails otherwise. Test `test-constrained-binomial-kernel-near-bound-start-reaches-mle.R`
  (5 pass swapped; 3 failures on the old kernel); 18 related kernel / class test files pass swapped. Rd not
  regenerated. Downstream: stored resampling rows of `InferenceIncidBinomialIdentityRiskDiff` / `InferenceIncidLogBinomial`
  can move slightly; fold into v1.0.6-TODO-209 item (4)'s regeneration.
- [ ] TODO-222 (added 2026-11-19, owner; from v1.1.0-TODO-217 part (b)): **`InferenceCountZeroInflatedNegBin`: the
  randomization test is oversized because `fast_zinb_cpp()` accepts non-MLE fits on permuted draws.** Newton-Raphson
  (the class default), warm-started from the full-data fit, often stops at a fit that is not the maximum likelihood.
  Two acceptance shortcuts in `R/EDI/src/fast_zinb.cpp` let it: `fit_zinb_zi_boundary_fallback()` accepts the
  zero-inflation-off NegBin fit ("NegBinNoZI") without checking that an interior fit has a lower negative
  log-likelihood (it can be 0.6-4 higher), and `accept_zinb_near_stationary_gradient()` reports converged on a
  separation ridge (zero-inflation coefficients ~1e5, gradient norm ~1e-2) above the MLE's negative log-likelihood.
  - Evidence (agent, 2026-11-19; calibration DGP, session scratchpad `todo217/`): 13-14% of randomization draws are
    wrong on the current tree (anchored warm start), 36% under the chained loop that campaign 2026-11-15-e36c7710 ran
    (removed in c28bbb34, v1.0.6-TODO-30). Class-level randomization size at n = 50 `~.`, same 400 datasets: 0.082
    before the guard below, 0.045 after (NegBin 0.045). At n = 200 `~1` the current tree is already about 0.058, so
    the campaign's `~1` randomization flags fit the old chaining; the n = 50 excess is on the current tree.
  - Decided 2026-11-19 (owner): the R guard `fast_zinb_cpp_guarded()` is the fix; see [DECISION-v1.0.6-TODO-222](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-222).
  - The R guard (NEWS "Changes that alter results"; class roxygen and Rd "Fitting" paragraph), `fast_zinb_cpp_guarded()` and `zinb_neg_loglik_r()` in
    `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`, routes all five ZINB fits through a check. It refits
    a suspect fit (not converged, at the zero-inflation boundary, a zero-inflation coefficient beyond 10 in absolute
    value, or gradient norm above 1e-5) with L-BFGS from a cold start and from the warm start, and keeps the lowest
    negative log-likelihood. New test `test-zinb-spurious-zero-inflation-boundary-refit.R`; the expectation in
    `test-count-classes-estimates-match-glm-nb-and-pscl-and-zinb-kernel-reference.R` changes to pscl's MLE (nll
    367.4735, not glm.nb's 367.5391). Cost: about half of n = 50 fits trigger 2-3 extra fits.
  - Root fix (C++, needs a rebuild): make both acceptance paths compare the negative log-likelihood with the interior
    fit's and keep the lower; then the R guard can go.
  - Done when: the confirmation stage shows the ZINB randomization cells nominal on the R guard. The C++ root fix is
    optional after that; if it is done, remove the R guard and its "Fitting" caveat about extra refits. The campaign's 78 ZINB randomization flags (size 0.075-0.109)
    are not accepted; they wait for that re-run.
  - **Verified locally 2026-11-19 (agent): the R guard holds; every cell is nominal within MC error.** Committed
    `fast_zinb_cpp_guarded()` (tree 6ae5d609; the later commit 72ea20ba changes only the ZIP path in that file),
    `pkgload::load_all(compile = FALSE)`, `compute_rand_two_sided_pval()` with the class defaults and `num_cores = 1`.
    Data: the count_zinb-like DGP and seeds of the v1.1.0-TODO-217 agent's `sim_rand.R` (seed 9e6 + 1000 n + rep),
    sharp null, 400 replicates per cell. DesignFixedBlocking is stratified on x4 x x5 (`equal_block_sizes = FALSE`).
    Size at alpha 0.05 with a Clopper-Pearson 95% interval; NegBin rand on the same data as a reference.

    | design | n | formula | reps (ZINB p finite) | ZINB rand | NegBin rand |
    |---|---|---|---|---|---|
    | FixedBernoulli | 50 | `~ .` | 400 (399) | 0.053 [0.033, 0.079] | 0.045 [0.027, 0.070] |
    | FixedBlocking | 50 | `~ .` | 400 (400) | 0.052 [0.033, 0.079] | 0.060 [0.039, 0.088] |
    | FixedBernoulli | 200 | `~ 1` | 400 (400) | 0.060 [0.039, 0.088] | 0.040 [0.023, 0.064] |
    | FixedBlocking | 200 | `~ 1` | 400 (400) | 0.045 [0.027, 0.070] | 0.060 [0.039, 0.088] |

    The pre-guard n = 50 `~ .` FixedBernoulli value on the same datasets was 0.082. The 0.053 here differs from the
    TODO-217 agent's post-guard 0.045 by 3 of 399 rejections. That run used an earlier tree (before 5bdb9dfb and
    6ae5d609) and did not set `num_cores`, so the randomization draws may differ; both are within MC error. Scripts and outputs: session scratchpad
    `verify218_222/` (`v222.R`, `v222_*.rds`, `tables.md`).

### Code bugs found by the source-comment-rot fixes, 2026-11-19 (TODO-223..229)

The source-comment-rot decisions fixed in 21e0679a rewrote these comments to describe the current code. The code
itself still needs a look.

- [ ] TODO-223 (added 2026-11-19, owner; audit decision `source-comment-rot-d06973fef`): **`fast_beta_regression`
  reports the observed Hessian as `fisher_information`.** `R/EDI/src/fast_beta_regression.cpp` sets `fit.XtWX =
  fun.hessian(params)`, the exact observed Hessian of the negative log-likelihood, and `vcov` inverts it, while
  `BetaRegression::expected_hessian()` is never called. The old docs said expected (working-weights) information.
  - Decide which is intended. If expected information: call `expected_hessian()` for `fisher_information` and keep
    the observed one under `observed_information`, as the other likelihood kernels do. If observed: delete the dead
    `expected_hessian()`.
  - Done when: the label matches the matrix, the unused code is gone, and a test compares both matrices with a
    numerical Hessian on a small fixture. Changing the matrix behind `vcov` changes SEs, so it needs a NEWS bullet.
- [ ] TODO-224 (added 2026-11-19, owner; `source-comment-rot-d77150edf`): **`fast_log_pnorm` is a constant for every
  x <= -8.** It returns -35.0496 there (and -6.661e-16 for x >= 8), with no asymptotic lower tail; log Phi(-10) is
  about -53.2. Censored-normal likelihoods that call it (`fast_survival_models_optim.cpp`) get no gradient far into
  the lower tail.
  - Replace the clamp with the standard asymptotic tail (log Phi(x) = log(phi(x)/|x|) + log of the Mills-ratio
    series, or `R::pnorm(x, 0, 1, 1, 1)` where R is available); this overlaps v1.1.0-TODO-50's erfcx item
    (`normal-cdf-quantile#43925959437.1`), so take whichever lands first.
  - Done when: |fast_log_pnorm(x) - pnorm(x, log.p = TRUE)| < 1e-12 relative on x in [-40, 8], with a test.
- [ ] TODO-225 (added 2026-11-19, owner; `source-comment-rot-d4adc9b4d`): **`prob_clip_eps` assert accepts 0.5.**
  `R/EDI/R/inference_incidence_gcomp_abstract.R` checks `assertNumber(prob_clip_eps, lower = 0, upper = 0.5)`
  (inclusive), while a separate `stop()` rejects `>= 0.5`. Behavior is correct; tighten the assert (e.g.
  `upper = 0.5 - .Machine$double.eps`) and drop the redundant `stop()`, keeping the error message.
  - Done when: one check, and a test that 0.5 errors.
- [ ] TODO-226 (added 2026-11-19, owner; `source-comment-rot-d6554d59d`): **`edi_tuning_verify_parallel_deviation`
  cannot detect a serial-vs-parallel difference.** `R/EDI/R/local_machine_tuning_correctness.R` fits the same class
  on two identical seeded experiments without setting or varying the core count, so both fits run under the same
  core setting.
  - Run one fit with one core and the other with `num_cores`, restoring the setting afterward, and compare.
  - Done when: a test plants a core-count-dependent estimator and the check flags it.
- [ ] TODO-227 (added 2026-11-19, owner; `source-comment-rot-de20927dd`): **`bootstrap_match_indices.cpp` cannot be
  compiled under `EDI_CORE_ONLY`.** It includes `<RcppEigen.h>` unconditionally and has no `#ifdef EDI_CORE_ONLY`
  guard, although `bootstrap_m_indices_internal` has no R dependency. Apply the guard pattern of
  `bootstrap_indices.cpp` (core function outside, Rcpp wrapper inside `#ifndef EDI_CORE_ONLY`).
  - Done when: the file compiles in a `cpp_tests/` target (per the CLAUDE.md whitelist) and the R build is unchanged.
- [ ] TODO-228 (added 2026-11-19, owner; `source-comment-rot-df6e615ac`): **The KK "Newcombe" risk-difference class
  uses Wald variances.** `shared_combined()` in `R/EDI/R/inference_incidence_KK_newcombe_ivwc_univ.R` computes
  Wald variances (var_m = (p10 + p01 - (p10 - p01)^2)/n, var_r = pRT(1-pRT)/nRT + pRC(1-pRC)/nRC) and no Wilson-score
  interval. The docs now say so, but the class name promises Newcombe.
  - Decide: implement the paired (Newcombe Method 10) and independent Newcombe intervals for the components, or
    rename the class (with a deprecated alias) to describe the Wald combination.
  - Done when: the name and the method agree; if the method changes, calibration coverage is rechecked and NEWS says
    so.
- [ ] TODO-229 (added 2026-11-19, owner; `source-comment-rot-d8959b19b`): **`InferencePropQuantileRegr`'s
  Bayesian-bootstrap refits use a different solver from its main fit.** The point and variance fits use
  `method = "fn"`, but the weighted `quantreg::rq()` in the shared `compute_quantile_estimate_with_bootstrap_weights`
  (`R/EDI/R/inference_continuous_quantile_regr.R`) uses the default `"br"`, so replicates and the original estimate
  come from different solvers.
  - Pass `private$quantile_full_method` (when not `NA`) to the weighted `rq()` call, so each class uses one solver.
  - Done when: the proportion class's weighted fit uses "fn", the continuous class is unchanged, and a test checks
    that unit weights reproduce the point estimate.
- [x] TODO-230 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-191 agent): **Ratio subsampling follow-ups.**
  (1) The default `min_fraction_usable_samples` cap for the g-comp RR subsampling / m-out-of-n paths.
  At 0.95, 9% (subsampling) / 29% (m-out-of-n) of null datasets return NA, the size among the rest is 0.016 / 0.000, and
  7 / 9 of the 11 datasets where Wald rejects become NA, because degenerate draws pile up where log RR-hat is extreme.
  At 0.80: 0% NA, size 0.040 / 0.030. (2) The same +/-20 degenerate-draw mechanism in other ratio subsampling /
  m-out-of-n paths (share of draws with |est* - est| > 5, subsampling / m-out-of-n): `InferenceIncidLogRegr` 2.8% /
  4.7%, `InferenceIncidModifiedPoisson` 2.0% / 3.0%, `InferenceCountPoisson` 0.5% / 1.6%, `InferenceIncidKKGEE` 0.5% /
  1.4%; `InferenceIncidLogBinomial` has 2-3% failed (NA) draws instead. (3) `InferenceIncidKKGCompRiskRatio`'s
  subsampling / m-out-of-n size stays low (0.015 / 0.010) for reasons other than degenerate draws. (4) The
  `debug = TRUE` distribution path does not apply the NaN marking. Scripts: /tmp/claude-1000/t191/.
  -- DONE (1), (2), (4); (3) investigated, cause found (fix below) (agent, 2026-11-20, uncommitted; scripts and results
  in `/tmp/claude-1000/t230/`). (1) Applied: the g-comp RR subsampling / m-out-of-n
  `min_fraction_usable_samples` default is 0.8 (was 0.95) on the public methods (`inference_incidence_gcomp.R`, also used
  by the KK classes) and the private RR pivot (`helper_gcomp.R`); still user-settable; the bootstrap / Bayesian-bootstrap
  `na.rm` 0.95 is unchanged. Class docs ("Subsampling and m-out-of-n") and the four `gcomp-*` `@param` templates state
  the value and why (Rd not regenerated); 16 `default` rows of `public_argument_contract_registry.csv` 0.95 -> 0.8.
  (2)+(4) One rule for every path: `edi_ratio_resampling_degenerate_rule()` (`inference_ext_exchangeable_resampling_units.R`)
  gives per class an arm rule (logit scale `InferenceIncidLogRegr` / `InferenceIncidKKGEE`: an arm with no or only
  events; log link `InferenceIncidModifiedPoisson` / `InferenceIncidLogBinomial`: no events; `InferenceCountPoisson`:
  zero total count) plus a fit rule (logistic separation, `edi_logistic_n_fitted_extreme() > 0`, for `InferenceIncidLogRegr`;
  the TODO-191 rule for the g-comp RR classes); `NULL` (no change) for `marginal_mean_diff`, RD and every other class.
  Applied in `compute_bootstrap_worker_estimate()` (component bodies in `inference_all_abstract_asymp.R` and
  `..._lik_std_mod_cache.R`, and the g-comp overrides; `gcomp_bootstrap_worker_estimate()` removed) via
  `edi_mark_degenerate_resampling_worker_draw()`, and in `compute_resampling_draw_distribution()` on the fresh-object and
  `debug = TRUE` paths (and the draw's arm rule after the reused-worker path); the debug list gains `num_degenerate`.
  The generic subsampling / m-out-of-n pivots of a class with a rule return NA with reason
  `<family>_too_few_usable_draws_fraction` and one `edi_procedure_na_warning` (even unhardened) below 80% usable draws
  (NaN and failed NA both count, so LogBinomial's failed fits are treated like the RR's); fixed constant
  `ratio_resampling_min_fraction_usable = 0.8`, NOT user-settable (needs a new argument on the generic public methods
  in `inference_all_abstract_non_param_boot.R`; owner call). No new private methods (standalone helpers only), so the
  registry / migration baselines are unchanged. Null size, n = 80, 200 data sets, B = 199, old = rule disabled, same
  seeds (subsampling / m-out-of-n): LogRegr (Wald 0.060) 0.000 / 0.000 -> 0.000 / 0.000, CI NA 25.5% / 54.0% -> 0 / 0;
  ModifiedPoisson (Wald 0.060) 0.005 / 0.000 -> 0.020 / 0.015, CI NA 16.5% / 36.5% -> 0 / 0; CountPoisson (Wald 0.020)
  0.010 / 0.000 -> 0.010 / 0.010, NA 0.5%; KKGEE (Wald 0.055) 0.000 / 0.000 -> 0.000 / 0.000, CI NA 2.0% / 10.0% -> 0 /
  0.5%; LogBinomial (Wald 0.043): unchanged 0.025 / 0.015, because its zero-event draws already come back NA (failed fit;
  1.6% / 2.8% of draws, 0 NaN) and now count against the same 80% cap (no data set reached it). The tests stay conservative for a second reason the degenerate rule cannot
  touch: at b = m = 21 the pivot is wider than the Wald scale (median SD ratio pivot / (sqrt(n) SE_Wald): LogRegr 1.48 /
  1.57, ModifiedPoisson 1.29 / 1.33, CountPoisson 1.13 / 1.15; the generic subsampling pivot also has the 1/sqrt(1 - b/n)
  = 1.165 factor the RR pivot lacks), i.e. J_b is far from J_n for these small-sample MLEs. (3) KK g-comp RR cause: not
  atoms and not the spread (pivot SD / Wald SE 0.93, 97.5% tail ratio vs normal 1.00; a normal with the pivot's SD gives
  size 0.055) but skew toward the observed effect: in the near-rejecting data sets the subsample law of log RR* has a
  heavy tail on the side of t_obs (3.5-7% of draws beyond |t|) and almost none on the other side (skew in the direction of
  the estimate 0.55 vs 0.22 for non-KK), so the equal-tailed p = 2 min(.) doubles the heavy tail. A symmetric p-value
  (mean(|pivot| >= |t|)) gives 0.045 (subsampling; non-KK 0.055) but m-out-of-n stays 0.015 (its pivot SD is 1.14-1.19x
  the Wald SE, both classes). Changing the p-value type is a methodology change (decided, see below). Tests: new `tests/testthat/test-ratio-subsampling-degenerate-draws.R` (36
  pass); updated `test-gcomp-risk-ratio-subsampling-degenerate-draws.R` (37), `test-bootstrap-extreme-ci-cap-on-estimand-scale.R`
  (94), comments in `test-estimand-no-effect-value-centering.R` and `test-risk-ratio-resampling-honours-timeouts-and-list-sizes.R`;
  17 related files incl. the call-graph acceptance and migration baseline pass.
  -- (3) DONE (agent, 2026-11-20, uncommitted). `resampling_centered_pval()` gains `symmetric = FALSE`;
  `TRUE` gives p = mean(|pivot| >= |t_obs|), floored at 1/B. Used by the g-comp RR pivot (`helper_gcomp.R`, both
  classes) and by the generic subsampling / m-out-of-n p-values of every class with a degenerate-draw rule (LogRegr,
  KKGEE, ModifiedPoisson, LogBinomial, CountPoisson); additive estimands and every other class keep the equal-tailed
  2 min(.). Intervals unchanged (basic, equal-tailed), and the size-selection evaluators' diagnostic p-values are
  unchanged. Null size (n = 80, 200 data sets, B = 199, 80% cap; computed from the stored NaN-marked draws, whose
  equal-tailed sizes reproduce the package's live values exactly), equal-tailed -> symmetric, subsampling / m-out-of-n:
  g-comp RR 0.040 -> 0.055 / 0.030 -> 0.035 (Wald 0.055); KK g-comp RR 0.015 -> 0.045 / 0.010 -> 0.015 (Wald 0.050);
  LogRegr 0 -> 0 / 0 -> 0; ModifiedPoisson 0.020 -> 0.020 / 0.015 -> 0.015; CountPoisson 0.010 -> 0.005 / 0.010 ->
  0.010; KKGEE 0 -> 0.005 / 0 -> 0; LogBinomial 0.025 -> 0.020 / 0.015 -> 0.020. No class became anti-conservative,
  so it applies to all ratio pivots. Docs: the two `gcomp-*-two-sided-pval` templates and both g-comp class paragraphs
  (definition, why, size); a new "Subsampling and m-out-of-n" `@section` in the five generic classes (degenerate rule,
  80% cap, symmetric p-value, measured size); Rd not regenerated. The generic public method docs live in
  `inference_all_abstract_non_param_boot.R` (jackknife agent's file) and were not touched. Tests: the symmetric formula
  in `test-ratio-subsampling-degenerate-draws.R` (41 pass) and `test-gcomp-risk-ratio-subsampling-degenerate-draws.R`
  (37), and in three bulk references (`test-gcomp-risk-ratio-subsampling-m-out-of-n-pivot-reference.R`,
  `test-gcomp-incidence-rr-jackknife-and-m-out-of-n-reference.R`,
  `test-incidence-gcomp-risk-ratio-jackknife-wald-and-subsampling-log-pivot-formulas-reference.R`). Open: the 0.8 cap on
  the generic paths is not user-settable (later, v1.0.6-TODO-269); KK m-out-of-n and LogRegr / KKGEE stay
  conservative because their small-b pivot is wider than the Wald scale.
  - Decided 2026-11-20 (owner): item (1) cap default 0.8; see [DECISION-v1.0.6-TODO-230a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-230a).
  - Decided 2026-11-20 (owner): item (3) symmetric centered p-value for ratio pivots; see [DECISION-v1.0.6-TODO-230b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-230b).
  - Decided 2026-11-20 (owner): generic-path cap user-settable, later (v1.0.6-TODO-269); see [DECISION-v1.0.6-TODO-230c](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-230c).
- [x] TODO-231 (added 2026-11-19, coordinator; from the v1.0.6-TODO-4 agent; DONE 2026-11-20 except item (2), the canonical-CSV regeneration, which needs an owner build of EDI first): **Stratified jackknife follow-ups.**
  (1) TODO-4 applies Wolter's JKn formulas to reweighting-equivalent replicates
  theta* = theta-hat + r_h (theta_(h,i) - theta-hat), r_h = n_h(N-1)/(N(n_h-1)), because EDI's replicates are unweighted
  subset refits and the literal (n_h-1)/n_h weight undercovers on SPBR (0.89-0.93 vs 0.92-0.96). The bias form rests on recollection of Wolter
  (paywalled); verify against the book. (2) Regenerate the SPBR / FixedBlocking jackknife rows in the canonical CSVs and
  retire the 1.0.5 baseline acceptances that cite TODO-162. (3) `DesignSeqOneByOneRandomBlockSize` has the same problem
  (unit = stratum, G = 2, so NA); record permuted-block ids at assignment and apply the same fix. (4) BCa acceleration
  still uses the unstratified spread of the replicates. (5) `DesignObservationalBlocks` still resolves to "block"; check
  it. (6) SPBR incidence AverageDiff coverage 0.924-0.928, just under the 0.93-0.97 band.
  Status 2026-11-20 (agent E, uncommitted; R only, no build). (1) Variance: rescaled form kept per the owner decision.
  Bias VERIFIED AND QUALIFIED: sum_h (n_h-1)(theta_bar_h - theta_hat) is the stratified jackknife bias of Jones (1974) /
  Krewski & Rao (1981), as Wolter 4.5 uses it, on REWEIGHTED replicates (confirmed: replicate construction, (n_h-1)/n_h
  variance and pseudovalues n_h theta_hat - (n_h-1) theta_(h,i) from Kolenikov's notes restating Krewski & Rao; the bias
  form from a second-order Taylor expansion; book and Jones paper not accessible). The r_h rescaling is first order
  only, so on EDI's refits the formula equals the ordinary unstratified bias (N-1)(theta_bar - theta_hat), which also
  counts the between-stratum spread of the outcome. Sim (g(mean), 40000 reps): true bias 0.0815 / 0.0067 / -0.0004;
  Jones on reweighted 0.0854 / 0.0061 / -0.0005; EDI 0.108 / 0.036 / -0.0028 (overcorrects by up to ~0.4 SE when
  strata differ strongly; 0 for a difference in means); literal raw-refit form -0.10 / -0.088 (worse). Code unchanged;
  documented in roxygen + comment (bias rule decided, see below). (2) NOT RUN: comprehensive_tests.R uses the installed EDI, so it needs an owner
  build first; then a filtered run (designs SPBR, FixedBlocking, RandomBlockSize; jackknife and bootstrap-bca families)
  merged with merge_comprehensive_slice_results.R. No baseline/accepted CSV row cites TODO-162 (grep of
  R/package_tests), so the retirement is of the class-keyed jackknife low_coverage rows the regenerated CSVs no longer
  flag. (3) DONE: RandomBlockSize assign_wt() records each subject's block (and each block's stratum key and drawn
  size; plain vectors, so duplicate() copies them); auto unit "permuted_block" from that record (trailing unfilled
  block merged as on SPBR; no strata_cols = one stratum); an object without the record keeps "block";
  "permuted_block" accepted explicitly on RandomBlockSize. (4) DONE: new edi_jackknife_acceleration(): stratified
  influence-skewness a = sum_h c_h^3 sum d^3 / (6 (sum_h c_h^2 sum d^2)^(3/2)), d = r_h (theta_bar_h - theta_(h,i)),
  c_h = (n_h-1)/n_h (one stratum = Efron; NULL strata bit-identical); used by ci_bca / pval_bca (Bayesian path
  unchanged). Only FixedBlocking is affected (sequential designs refuse the bootstrap). (5) CHECKED, not changed:
  ObservationalDesignBlocks (not "DesignObservationalBlocks") resolves to "block"; its blocks are
  user-defined "matched sets / strata / clusters", so leave-one-block-out is right for matched sets and clusters but
  NA with < 5 strata-like blocks (explicit unit = "observation_within_block" works). Its bootstrap resamples within
  blocks (strata reading).
  (6) INVESTIGATED: 400 reps (n = 148, 2 prognostic binary strata, incidence, beta 0; scripts $TMPDIR/simE6.R):
  jackknife-Wald z 0.930, with t(sum_h (n_h-1) ~ 31 df) 0.943; mean SE 0.078 = SD 0.078; bias negligible
  (4e-4); literal (n_h-1)/n_h 0.915. So no SE bias: the shortfall is the z reference at ~31 df plus SE noise (MC SE
  0.012).
  Owner decisions 2026-11-20 applied (agent E, uncommitted; R only). (1) KEEP the bias formula; the caveat (equals the
  ordinary (N-1)(theta_bar - theta_hat), can over-correct nonlinear estimators when strata differ) is now in the
  roxygen of the public methods compute_jackknife_bias_estimate() / compute_jackknife_estimate() / the jackknife-Wald
  p-value and CI, as well as the class Formulas section. (5) DONE: ObservationalDesignBlocks with fewer than
  EDI_JACKKNIFE_MIN_DELETION_UNITS (5) blocks resolves "auto" to "observation_within_block" (blocks as strata), else
  "block"; explicit units unchanged; documented in the design's roxygen (new Jackknife paragraph) and the class
  Deletion units list. (6) DONE: stratified units ("permuted_block", "observation_within_block") use t with
  df = sum_h (n_h - 1) for the jackknife-Wald p-value and CI (compute_jackknife_summary() now carries df; Inf for every
  other unit, which keeps pnorm/qnorm bit for bit); also the risk-ratio log-scale jackknife-Wald
  (edi_rr_jackknife_wald_*() in inference_all_abstract_jackknife.R, used by the g-comp classes; no g-comp file edited).
  Documented in the jackknife methods and in the SPBR, RandomBlockSize, FixedBlocking and ObservationalDesignBlocks
  docs. Re-measured (fresh seeds, 400 reps, 2 cores, same DGP): EDI's own jackknife-Wald CI coverage 0.955 / 0.960
  (two 200-rep halves; pooled with the earlier 400 reps the t interval covers 0.950, z 0.940). Remaining: item (2).
  - Decided 2026-11-20 (owner): item (1) variance: keep the rescaled replicates; see [DECISION-v1.0.6-TODO-231a](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-231a).
  - Decided 2026-11-20 (owner): item (1) bias, keep the current formula, documented; see [DECISION-v1.0.6-TODO-231b](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-231b).
  - Decided 2026-11-20 (owner): item (5) ObservationalDesignBlocks with < 5 blocks deletes one observation within a block; see [DECISION-v1.0.6-TODO-231c](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-231c).
  - Decided 2026-11-20 (owner): item (6) t reference with df = sum_h(n_h - 1) for stratified units; see [DECISION-v1.0.6-TODO-231d](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-231d).
  (5) and (6) were assigned to the TODO-231 agent.
- [x] TODO-232 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-218 agent's 1200-dataset sweep): **Small ZIP
  fits that stop unflagged below the maximum.** 3 of 1197 fits (n 24-40, 2-7 positive counts) end at a worse
  log-likelihood than `pscl::zeroinfl` by 0.17, 1.3 and 6.6 without any flag (e.g. sweep seed 100888: 0.003 vs pscl
  -23.6); the v1.0.6-TODO-152 pscl-start L-BFGS candidate does not catch them. Find why (start, optimizer stop, or a
  third local maximum) and add the missing candidate or flag. Sweep scripts are in the TODO-218 agent's $TMPDIR.
  Partly done 2026-11-19 (agent, uncommitted; R only). Cause: two of the three are not optimizer misses. Seeds 100532
  and 100888 drop a count covariate aliased on the positive rows (x2, x1; `edi_covariate_dropped_warning` fires, the
  sweep suppressed it), and pscl fit the full model, whose likelihood runs off to infinity in that count coefficient
  (pscl count x1 108.7); on EDI's reduced design pscl matches EDI to 1e-6 (nll 18.07638, 9.562061). Seed 101057 (n 24,
  7 positives) is a third local maximum and more: the default start and the pscl start both stop at an interior
  maximum (nll 21.073, gradient 3e-10, information eigenvalues 20.5..0.021), pscl at another (20.903), and the
  supremum is on a ridge (20.159, zero part separating zeros from every positive). The comparison with pscl hid how
  common this is: a 13-start reference on the same 1197 datasets puts 96 of 602 unflagged ZIP fits (all n, 24 to 400)
  below a higher-likelihood point, and 40 of the 41 examined in detail are separated zero parts. Fix:
  `fast_zero_augmented_poisson_cpp_guarded()` adds a second L-BFGS candidate from pscl's start with the zero part
  multiplied by 10 (`ZERO_AUGMENTED_SHARPENED_START_SCALE`; candidate name `pscl_start_sharpened_lbfgs`), keeping the
  lowest nll by the existing 1e-6 rule. On the 96 it improves 55 (all of them now flagged `zero_part_separated` by
  v1.0.6-TODO-152's rule), reaches the reference in 41; x5 / x20 gave 28 / 58 improved but x20 fails to converge more
  often at n = 400. Seed 101057 now: nll 20.1593, estimate -0.164, separation warning. Cost: a ZIP kernel fit
  (primary + candidates) about 1.8x slower at n <= 100 (80 datasets: 1.31 s -> 2.44 s for 5 passes), in every fit
  including resampling replicates. Roxygen "Separated zero-inflation part" in ZIP updated (not roxygenized). Test:
  `test-zip-sharpened-start-reaches-ridge.R`. Remaining: 41 of the 96 still stop unflagged at an interior maximum
  below a ridge; with continuous covariates in the zero formula the ZIP MLE often does not exist at small n (more
  candidates: all of x5 / x10 / x20 still leave 35 of 96, at ~3x cost).
  - Decided 2026-11-19 (owner): document now, no more starts; ridge detector filed as v1.1.0-TODO-258; see [DECISION-v1.0.6-TODO-232](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-232).
  Done 2026-11-19 (agent, uncommitted): `InferenceCountZeroInflatedPoisson` roxygen gets a "Small samples with
  covariates in the zero-inflation formula" paragraph (MLE often does not exist; several starts and a warning on the
  ridge, but about 41 of 602 unflagged sweep fits still stop at a lower interior maximum without a warning; pscl
  agreement does not rule it out; count estimate only weakly defined on a ridge; recommend `model_formula_zero = ~ 1`,
  which keeps the treatment), and the `model_formula_zero` @param points to it. Not roxygenized (parse() only). Sweep: `/tmp/claude-1000/sweep/` (TODO-218) and the TODO-232 agent's `$TMPDIR/t232/`.
- [x] TODO-233 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-216 agent; OWNER DECISION, changes results):
  **Zhang exact CIs can have gaps.** The combined two-sided exact p-value is not monotone in delta and can jump, so in
  about 2.5% of ordinary `InferenceIncidExactZhang` CIs on matching designs (8 of 323 checked) the accepted set has
  gaps, and the bisection returns only the piece around its starting point. Options: report the convex hull of the
  accepted set (conservative, standard for exact CIs), or keep the connected piece and document it. Also: ties at
  p0 = 0.5 within the binomial's 1e-7 tolerance give a narrow accepted window at exactly delta = 0, so some endpoints
  land at about -1e-7. Scripts: /tmp/claude-1000/z216/.
  - Decided 2026-11-20 (owner): report the convex hull; see [DECISION-v1.0.6-TODO-233](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-233).
  DONE 2026-11-20 (agent B, R only, no build). Cause: both components are
  two-sided minimum-likelihood p-values (as in `binom.test`/`fisher.test`) that jump where an outcome ties the observed
  one, at the known breakpoints delta = (c(x) - c(j)) / (j - x); beyond the outermost breakpoint each is a one-sided tail
  and falls monotonically. Fix (`inference_helpers_zhang.R`): new `zhang_exact_pval_breakpoints()`,
  `zhang_ci_hull_endpoint()` (the unchanged bisection from the start point, then a scan of the breakpoints plus a
  200-point grid out to just past the outermost breakpoint; the farthest accepted scan point is refined by bisection),
  `zhang_pval_exact_combined_vec()` (vectorised scan p-value; equals the scalar kernels to 6e-15) and
  `zhang_snap_endpoint()` (an endpoint within 1e-6 of a breakpoint the test accepts, with rejection just past it, is
  reported at the breakpoint: the p0 = 0.5 endpoints at -1.08e-7/-1.27e-7 are now exactly 0, consistent with the test
  accepting delta = 0). Serial and parallel paths share it. Docs: class roxygen, the CI template, `@references`
  Blaker (2000) and Fay (2010) (DOIs checked on Crossref), `REFERENCES.md` [Blaker2000]/[Fay2010], WORDLIST (Rd not
  regenerated). Evidence: 1200 synthetic KK CIs (seeds 1-200 x alpha 0.05/0.1 x 3 methods): 15 gapped CIs widened, all
  now containing every grid-accepted point (2e-3 grid), endpoints at p = alpha or a closed jump; all others within
  1e-6 of before (the snap; 693 bit-identical). 600 Bernoulli-only CIs: no gaps, all within 1e-6. Cost 1.7x (KK) to 2.8x
  (Bernoulli) the old CI time, max 2 s. Stored rows: replayed 576 dumped comprehensive fits (KK21stepwise pima 200,
  other KK/BinaryMatch 23, FixedBinaryMatch 353): only 2 change at the stored 3 decimals, KK21stepwise `~.` pima rep 47
  beta 0 ([-0.384, 1.474] -> [-0.536, 1.474]) and rep 11 beta 0.5 ([-0.430, 1.263] -> [-0.526, 1.263]); regenerated
  with receipt runs and merged (`--apply`, backups `.pre_slice_merge_20261120T054751Z.bak` / `T055028Z.bak`). No Bernoulli endpoint in the CSV lies within 2e-6 of a 3-decimal rounding boundary, and
  no Bernoulli gap was seen, so Bernoulli rows were not rerun. Coverage flags of the 2 rows unchanged (TRUE / NA).
  Test: `testthat_bulk/test-zhang-exact-ci-convex-hull-of-accepted-set.R` (84); existing Zhang tests pass.
- [x] TODO-234 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-213 agent; OWNER DECISION, changes realized
  allocations): **Treated-count rounding differs between designs.** (1) `DesignFixediBCRD` rounds a .5 tie up (n = 21,
  prob_T = 0.5 gives 11 treated; realized and redraws agree, from one kernel), while `DesignSeqOneByOneiBCRD` uses R's
  `round()` (10). Align them (one-line R change in `design_fixed_ibcrd.R`, changes realized fixed allocations at ties) or
  document the difference (done in roxygen). (2) `DesignFixedRerandomization` with `prop_acceptable` at prob_T = 0.5 uses
  `complete_randomization_forced_balanced_cpp` = floor(n/2) (n = 23: 11 treated) while the other paths use
  `round(n * prob_T)` (12); realized and redraws agree within each path, so the null is right, but the documented count
  is wrong. Fix: use the forced-balanced kernel only when n is even (changes realized allocations for n = 3 mod 4).
  - Decided 2026-11-19 (owner): "align both"; see [DECISION-v1.0.6-TODO-234](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-234).
  DONE 2026-11-19 (agent, uncommitted): (1) `DesignFixediBCRD$draw_ws_raw()` passes
  `round(n * prob_T) / n` to `generate_permutations_ibcrd_cpp()` (the `DesignSeqOneByOneiBCRD` v1.0.6-TODO-213 trick),
  so realized and redraws both use R's `round()`; no C++ change. Only tie cases move (n = 1 mod 4 at 0.5, e.g. n = 21:
  11 -> 10); non-tie draws are byte-identical. (2) `DesignFixedRerandomization`'s `prop_acceptable` path uses the
  forced-balanced kernel only when n is even, else `complete_randomization_imbalanced_cpp(n, round(n * prob_T), ...)`;
  only n = 3 mod 4 at 0.5 moves (the two kernels shuffle identically when the counts agree). Roxygen updated (Rd
  regen pending), tests: `test-ibcrd-tie-rounding-redraw-count.R` (updated + grid test),
  `test-rerandomization-prop-acceptable-odd-n-treated-count.R` (new). Open: comprehensive results rows for these two
  designs on odd-n datasets drift and need the next regeneration.
  - Also reported by the docs-scenario audit: ds-fixed-designs-44358267779-f2 (2026-11-18, with `prop_acceptable`
    the realized allocation is the best of 1 / prop_acceptable draws while the reference keeps the best r of
    r / prop_acceptable, so the randomization test over-rejects, 7.25% at 5%). Not fixed by this entry, which
    changed only treated-count rounding: re-run 2026-11-20 on HEAD, 31.7% of realized allocations vs 0% of
    reference draws lie above the base 1% quantile (KS D = 0.317), as in the audit. Filed as v1.0.6-TODO-294.
- [x] TODO-235 (added 2026-11-19, coordinator; found by the v1.0.6-TODO-217 agent): **KK IVWC leftovers after the
  Bayesian-bootstrap fix.** (1) OWNER DECISION: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`'s own Bayesian-bootstrap
  hook is a marginal-Weibull surrogate, not the IVW estimator (bootstrap mean 0.55 vs estimate 0.63): refuse it like
  the Normal IVWC class, or build a weighted fit. (2) The quantile IVWC classes could get their Bayesian bootstrap back
  with weighted `rq` refits. (3) `test-reused-worker-rank-deficient-draw-rebuilds-covariates.R:122` fails:
  `InferenceSurvivalStratCoxPHRegr` jackknife with explicit `unit = "block"` returns 60 replicates where 3 (strata) are
  expected; likely from v1.0.6-TODO-4 (explicit "block" should still delete whole strata) — check and fix.
  - Decided 2026-11-19 (owner): item (1) refuse the surrogate Bayesian bootstrap; see [DECISION-v1.0.6-TODO-235](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-235).
  Status of item (1) 2026-11-19 (agent, uncommitted): DONE, refused, same mechanism as the
  Normal IVWC class in v1.0.6-TODO-217. `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` now has private
  `supports_bayesian_bootstrap()` = FALSE and is listed in `EDI_INFERENCE_EXCLUDED_CAPABILITIES` (`bayesian_bootstrap`);
  the BB entry points stop with "... does not support Bayesian bootstrap (supports_bayesian_bootstrap() = FALSE)."
  The surrogate `compute_estimate_with_bootstrap_weights` was deleted from `SurvivalGLMMWeibullFrailtyLoggammaIVWCSource`
  (and from the component's `provides_public_methods` in `contracts_mixins.R`), so a direct call reaches the KK
  compound dispatcher's "has no weighted refit of its estimator" error. Roxygen gains the "No Bayesian bootstrap"
  paragraph (Rd pending roxygenize). Class method surface unchanged (the public method still binds, now from
  KKCompound; `supports_bayesian_bootstrap` was already on the host), so no registry-baseline delta. Tests: class added
  to the refused list in `test-kk-ivwc-bayesian-bootstrap-replicates-match-estimator.R` (now 29 expectations in that
  block, all pass); bulk `test-glmm-weibull-frailty-loggamma-ivwc-weighted-bootstrap-cluster.R` (pinned the surrogate)
  deleted with its two `ci/test_runtimes.csv` rows. Drift CSVs (`capability_matrix.*` etc.) left to the pre-push
  regeneration. Items (2) and (3) open.
  Item (3) 2026-11-20 (agent E): NOT A CODE BUG, already resolved. The failing line was the test at 5bdb9dfb, which
  called approximate_jackknife_distribution_beta_hat_T() with the default unit; v1.0.6-TODO-4 made that
  "observation_within_block" on DesignFixedBlocking (60 replicates, intended). 98d90465 changed the test to
  unit = "block", which returns 3 (checked directly: "block" 3, default 60). The file passes (load_all, 0 failures).
  Item (2) 2026-11-20 (agent D, uncommitted): DONE. `InferenceContinKKQuantileRegrIVWC` and
  `InferencePropKKQuantileRegrIVWC` support the Bayesian bootstrap again. The `KKQuantileRegrIVWC` component gains
  private `compute_weighted_estimate_ivwc()` (registered in `contracts_mixins.R`): both halves are refit by
  `quantreg::rq(weights = )` (pair weight = mean of its row weights; reservoir rows keep theirs; logit scale for the
  proportion class), each half's SE comes from its weighted fit ("nid", then "iid", then a weighted-IQR fallback that
  equals `stats::IQR()` at uniform weights), pooled by `kk_ivwc_pool_halves()`. Zero weights, and weights below 1e-10
  times the mean, drop the row (rq would otherwise keep near-empty rows in its "nid" bandwidth); kept weights are
  rescaled to mean 1. Both classes lose their `supports_bayesian_bootstrap() = FALSE` override and their
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES` entries; roxygen "No Bayesian bootstrap" paragraph replaced by a method
  description (Rd pending roxygenize). No registry-baseline delta (`compute_weighted_estimate_ivwc` is already an
  allowed addition; methods stay bound on the class host). Evidence: near-uniform replicate equals the estimate;
  replicate matches an independent weighted-rq reference to 1e-8; serial 100-rep simulation (n = 60, normal errors,
  B = 100) gave BB percentile coverage 0.98 (asymptotic 0.93), BB CIs about 22% wider. Tests: new
  `test-kk-quantile-ivwc-weighted-rq-bayesian-bootstrap.R`; Contin class added to the fixed cases of
  `test-kk-ivwc-bayesian-bootstrap-replicates-match-estimator.R`; the two bulk `*-weighted-passthrough-reference.R`
  files now check the weighted-rq reference instead of the refusal. Drift CSVs (`capability_matrix.*` etc.) left to
  the pre-push regeneration.
- [ ] TODO-236 (added 2026-11-19, owner; from the algorithm-research triage of run 44358397244, finding
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

### Bugs found by the algorithm-audit re-review of drift issue #55, 2026-11-20 (TODO-271..276, TODO-323..324, TODO-326, TODO-424)

The 2026-11-20 re-review of the 26 drifted algorithm-audit rows (`new_feature_plans/v1_0_5/algorithm_choice_audit.md`,
"Re-review log", entry "2026-11-20: drift issue #55") kept every row's decision but found these. Only TODO-271 and
TODO-273 were confirmed by reading the code; the rest are suspected and need a reproducer first.

- [x] TODO-271 (added 2026-11-20, coordinator; algorithm-audit row L, confirmed by reading): **KK Cox IVWC Bayesian
  bootstraps fit Efron ties while the estimate uses Breslow.** `kk_ivwc_weighted_cox_half()` (`R/EDI/R/globals.R:316`)
  fits each weighted half with `survival::coxph(weights = )`, which defaults to Efron, and the comment above it
  (`globals.R:313-315`) says this is "the same Efron-ties likelihood as the unweighted C++ fitter". The C++ fitter is
  Breslow. On tied event times the Bayesian-bootstrap replicates of `InferenceSurvivalKKStratCoxIVWC` and the KK LWA
  Cox IVWC class therefore fit a different partial likelihood from the reported estimate (uniform weights
  short-circuit to `compute_estimate()`, so only the replicates are affected). The non-KK Cox Bayesian bootstraps have
  the same mismatch; v1.1.0-TODO-61 covers the package-wide ties choice, so this TODO is the interim fix only.
  - Fix: pass `ties = "breslow"` in `kk_ivwc_weighted_cox_half()` (and any other weighted `coxph` call feeding a
    Breslow estimate), and correct the comment.
  - Test: on a tied-time fixture, a weighted replicate with all weights 1 matches `compute_estimate()`, and with
    non-uniform weights it matches `survival::coxph(..., ties = "breslow", weights = w)`.
  - Changes Bayesian-bootstrap draws on tied data for these classes: NEWS bullet ("Changes that alter results").
  - Done when: every weighted Cox replicate path uses the estimate's ties rule, the comment is true, the test passes.
  - Status 2026-11-20 (agent, uncommitted; the code and test landed in 8d8c5f78): confirmed the C++ fitter is Breslow
    (`fast_coxph_regression.cpp`: each tied set adds `d_k * log(S0)`, one shared risk-set denominator). Every weighted
    Cox replicate goes through one helper, `weighted_cox_bootstrap_surrogate_fit()` (`globals.R`), which hard-coded
    Efron on both its `coxph.fit()` fast path and its `coxph()` formula path. It now takes `ties = "breslow"` and
    passes it to both, so the fix covers the KK IVWC halves (`kk_ivwc_weighted_cox_half()`) and the non-KK and KK
    one-likelihood Cox replicates alike: `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr`,
    `InferenceSurvivalKKStratCoxPHIVWC`, `InferenceSurvivalKKStratCoxPHOneLik`, `InferenceSurvivalKKLWACoxPHIVWC`
    and `InferenceSurvivalKKLWACoxPHOneLik`. Comments corrected. `InferenceSurvivalDepCensTransformRegr` also uses
    this helper as a surrogate for a non-Cox estimate; it passes `ties = "efron"` explicitly so its results do not
    change (owner may prefer Breslow there; v1.1.0-TODO-61 owns the package-wide choice). The log-rank weighted null
    fit was already Breslow. Test:
    `R/package_tests/testthat_bulk/test-cox-bayesian-bootstrap-weighted-refit-uses-breslow-ties.R` (tied fixture:
    helper fast/stratified/clustered paths vs `coxph(ties = "breslow", weights = w)`, unit weights vs the C++ fit,
    `kk_ivwc_weighted_cox_half()` beta and naive variance, and all six classes' unit-weight replicates vs
    `compute_estimate()` with the constant-weight shortcut mocked off): 21 passed, 0 failed under
    `load_all(compile = FALSE)`; with the helper mocked back to Efron the same file has 10+ failures. NEWS bullet added
    under "Changes that alter results".
- [x] TODO-272 (added 2026-11-20, coordinator; algorithm-audit row A, suspected): **Logistic IRLS never checks the
  step taken at the last iteration.** In `R/EDI/src/fast_logistic_regression.cpp` `run_irls` (~L240-330) the
  safeguarded pass runs its descent check at the top of the next iteration, so the step taken at `iter = maxit - 1`
  is accepted unchecked. A fit that stops at the cap (not converged, e.g. under separation) can return a worse
  iterate than the best one it visited. Also, non-converging fits now run IRLS twice (plain, then safeguarded).
  - First reproduce: a fixture that hits `maxit` and returns a log-likelihood below one it reached earlier.
  - Fix: check the last step before returning (step-halve or keep the best iterate); consider skipping the plain pass
    when its failure is already predictable.
  - Done when: a capped fit never returns a worse log-likelihood than its best iterate, with a test, or the
    reproducer shows it cannot happen and the item is closed with that note.
  - Status 2026-11-20 (agent, uncommitted; no build): **real.** Far warm starts (n = 30, slope start +-5..40) at
    maxit 1..6: the old kernel returned a neg_ll above the start in 745 of 2700 fits (seed 1, start (0.3, -25):
    408.4 -> 36767.6 at maxit = 1, 66070.6 at maxit = 2); 0 with the fix. Fix in `run_irls`: after the loop the
    safeguarded pass checks a pending last step with the same halving rule (reverting to the previous iterate,
    `stalled`, if no halving helps), then rebuilds mu / XtWX / score / gradient norm at the returned coefficients
    (at the cap they described the iterate one step earlier, even on fits the Newton-decrement rule declared
    converged: Fisher error 0.035 -> 1e-15). Coefficients of all 1234 converged fits in the sweep and of the
    separation fixture are unchanged. Test `R/package_tests/testthat_bulk/test-logistic-irls-capped-fit-never-worse-than-start.R`
    (218 expectations) passes with the kernel swapped in via sourceCpp, as does
    `test-logistic-irls-step-halving-and-scale-aware-convergence.R`; it fails on the installed EDI.so until the
    owner rebuilds. Not done: skipping the plain pass when its failure is predictable (optional).
- [x] TODO-273 (added 2026-11-20, coordinator; algorithm-audit row X, confirmed by reading, minor): **Robust M fit
  takes an extra step on an exact fit.** `R/EDI/src/fast_robust_regression.cpp:177` clamps the initial scale to
  1e-10, so the exact-fit stop (`res.scale <= 0.0`, :195) cannot fire at iteration 1. When the OLS start has MAD 0,
  `MASS::rlm` returns the start and reports convergence, while EDI takes one more WLS step. The comment above
  `hit_iteration_cap` (~:268) still describes a coefficient-change stop. Not covered by v1.0.6-TODO-50.
  - Fix: test the unclamped scale for the exact-fit stop (or clamp after it) and update the comment.
  - Done when: on an exact-fit fixture the coefficients and `converged` match `MASS::rlm`, with a test.
  - Status 2026-11-20 (agent, uncommitted; no build): the kernel change landed in 8d8c5f78. For `"M"` the start
    scale is no longer floored (`"MM"` keeps the 1e-10 floor), so the MAD-0 stop fires at iteration 1; that exit
    builds `fisher_information` from the unit weights, since no WLS step has run. The comment above
    `hit_iteration_cap` now lists the real stopping rules. New test
    `R/package_tests/testthat_bulk/test-robust-regression-m-exact-fit-start-stops-like-mass-rlm.R` uses two fixtures
    whose OLS residuals are exactly 0 under both Eigen and LINPACK QR, on points that do not identify the slope.
    Under a sourceCpp kernel swap: coefficients 0/0, `converged` TRUE, 1 iteration, matching `rlm`. The old kernel
    gave slopes 1.67 and -1.0. The 5 existing robust-kernel test files also pass under the swap. The test fails
    against the installed EDI.so until the owner rebuilds. Not fixed (outside this TODO): when one QR's start is
    exact and the other's is off by rounding (MAD about 1e-17 rather than 0), the two fits still diverge. Fitting at
    a near-zero scale is ill-posed anyway.
- [x] TODO-274 (added 2026-11-20, coordinator; algorithm-audit row K, suspected): **KK GEE separation rule can blank
  the SE of a fit that is not separated.** The logit-link check in `R/EDI/R/inference_mixin_kk_gee_shared.R:493`
  (added for v1.0.6-TODO-118) reports SE, p and CI as NA when any single fitted |eta| reaches qlogis(1 - 1e-8). One
  high-leverage point can reach that without separation. It is the same heuristic as plain logistic
  (v1.0.6-TODO-109), but no TODO covers the GEE use.
  - First reproduce: a non-separated KK GEE fixture with one extreme fitted probability; compare with a separation
    test (e.g. `detectseparation`, or the LP check the logistic path uses, if any).
  - Done when: the rule fires only on a separated fit (or the docs state it is a heuristic and when it misfires),
    with a test on both kinds of fixture.
  Status 2026-11-20 (agent, uncommitted): reproduced and fixed. `DesignSeqOneByOneKK14` incidence, n = 40, one
  subject with x1 = 25 (y = 1): not separated (Konis LP via lpSolve and the new check agree; glm converges, all
  |coef| < 5), but max fitted |eta| 22-34, so 5 of 6 seeds gave p NA + separation warning (seed 2: est 0.67; now
  p 0.45). Fix: new exact check `edi_binary_data_separated()` (`helper_robust_sandwich.R`; Stiemke alternative
  solved as Lawson-Hanson NNLS, no new dependency, handles fractional y and rank deficiency; 0 mismatches vs the LP
  on 3,200 random fixtures). `shared_gee_default()` keeps the |eta| screen but blanks the SE only when the check
  confirms separation (or cannot run: NA falls back to the screen); the Rcpp result now also stores `y_fit`. The
  plain logistic path only warns (no NA), so it was not changed; `InferenceOrdinalKKGEE` (cumulative-logit screen,
  `inference_ordinal_KK_combined.R:288`) still uses the screen alone. Test
  `R/package_tests/testthat_bulk/test-kk-gee-separation-check-ignores-high-leverage-point.R` (38 pass, both
  fixtures, Rcpp and geepack paths); 10 related KK GEE test files pass. NEWS bullet added.
- [x] TODO-275 (added 2026-11-20, coordinator; algorithm-audit row Z, suspected, low): **Log-binomial IRLS loop can
  in principle run past `maxit`.** Both loops in `R/EDI/src/fast_log_binomial_regression.cpp` (:535, :818) run while
  `iter < maxit || kkt_confirm_pending`. A later small step near a bound can set `kkt_confirm_pending` again (:690),
  so if the observed-information check kept failing the loop would not stop at `maxit`. The relative-step criterion
  should nearly always pass, and this has not been shown. Belongs with v1.0.6-TODO-221's KKT gate.
  - Fix: cap the extra confirmation iterations (e.g. `iter < maxit + k`) and report non-convergence past that.
  - Done when: the loop has a hard bound, with a test that forces the pending flag and checks it stops.
  Status 2026-11-21 (agent, uncommitted; no build): could not overrun by more than one iteration in practice. For
  tol < 0.9 it is impossible: the pending iteration either stops or takes the observed-information Newton step that
  the check just found > 10 tol (relative), and |d| < tol |beta + d| then needs tol > 0.9, so the flag cannot be
  set twice in a row and num_iter <= maxit + 1. Sweeps (14,400 calls per tol, tol 1e-6 to 1e3, maxit 1-25, cold and
  warm starts, all four kernels) never exceeded maxit + 1. Fix anyway: both loops now run past maxit only while
  `iter - maxit < kKktConfirmMaxExtraIter` (= 3); a fit still pending then has converged = FALSE and
  hit_iteration_cap = TRUE. (A compile-time test seam that forced the flag was removed 2026-11-21 at the owner's
  request; the cap itself is therefore not exercised by a test.) Kernel swap (sourceCpp, HEAD vs patched): 34,560 calls over the
  6 entry points (plain, weighted, with_var; maxit 1-100, warm starts, fixed_idx) are all `identical()`.
  Test `test-constrained-binomial-kernel-kkt-confirmation-iterations-are-bounded.R`: (1) num_iter <= maxit + 1 on
  the installed kernel (passes on old and new); the seam-based second test was removed with the seam. No NEWS (results unchanged). Needs the
  owner's build for the bound to ship.
- [x] TODO-276 (added 2026-11-20, coordinator; algorithm-audit row I, suspected, probably unreachable): **Rerandomization
  objective divides by a zero SD.** `compute_objective_vals_cpp` (`R/EDI/src/rerandomization_helpers.cpp:110-114`,
  division at :153) divides by `sd_all[j]` in abs mode without the zero-variance guard the search kernel has (:209).
  A constant covariate column would give Inf/NaN objective values. Overlaps v1.4.0-TODO-11h; take whichever lands
  first.
  - Fix: skip (or treat as zero contribution) columns with `sd_all[j] == 0`, as the search kernel does.
  - Done when: a constant column gives finite objective values matching the search kernel, with a test.
  - Status 2026-11-20 (agent, uncommitted; no build): **reachable, not hypothetical.** The default `~ .` formula
    drops constant columns upstream, but a `design_formula` term such as `I(x2^0)` keeps one in the model matrix;
    with `prop_acceptable` + `objective = "abs_sum_diff"` every objective value was NaN, so `order()` kept the first
    `r` candidates unfiltered (silent complete randomization). Fixed in `compute_objective_vals_cpp`: SD from centered
    sums, `var < 1e-24` → unscaled (inv_sd = 1), the search kernel's rule; dropped the uncentered `sumsq` form.
    Non-constant values move by ≤ 1e-15 relative. Test:
    `R/package_tests/testthat_bulk/test-rerandomization-objective-constant-covariate-column.R` (10 pass with the
    kernel swapped in via sourceCpp, 9 fail on the installed kernel; existing rerandomization tests unchanged).
    NEWS bullet under "Changes that alter results". Needs the owner's rebuild before the bulk test passes.
    Not touched: the `mahal_dist` + constant column case stays finite (ridge in `ensure_S_inv_current`, while the
    search kernel falls back to abs mode on a failed LLT), so the two kernels rank by different criteria there.

- [ ] TODO-323 (added 2026-11-21, owner; found by the v1.0.6-TODO-274 agent): **`InferenceOrdinalKKGEE` separation
  rule can blank the SE of a fit that is not separated.** The same false alarm v1.0.6-TODO-274 fixed for the binary
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
    cumulative-logit model confirms separation (as v1.0.6-TODO-274 did), or, if no practical exact check exists,
    document the rule as a heuristic and when it misfires.
  - Done when: the rule fires only on separated fits (or the docs say it is a heuristic), with a test on a separated
    and a non-separated high-leverage fixture; NEWS bullet if results change.
- [ ] TODO-324 (added 2026-11-21, owner; found by the v1.0.6-TODO-276 agent): **Rerandomization `mahal_dist` with a
  constant covariate column ranks draws differently on the two paths.** With `objective = "mahal_dist"` and a
  constant column kept by the design formula (e.g. `~ x1 + I(x2^0)`), the `prop_acceptable` path stays finite
  because `ensure_S_inv_current()` (`R/EDI/R/design_fixed_rerandomization.R` ~L277) adds a 1e-6 ridge to a singular
  covariance and ranks by that ridged Mahalanobis distance, while the cutoff path `rerandomization_search_cpp`
  (`R/EDI/src/rerandomization_helpers.cpp` ~L203-210) falls back to the abs objective when its Cholesky fails. So the
  same design and data are filtered by different criteria depending on whether `prop_acceptable` or
  `obj_val_cutoff` is set. (The abs_sum_diff paths were made consistent by v1.0.6-TODO-276.)
  - Decide the rule: drop zero-variance columns before forming the covariance (the Mahalanobis distance of the rest
    is then well defined and the constant column contributes nothing, matching the abs fix), or use the same ridge,
    or the same abs fallback, on both paths. Dropping the column is the cleanest; the `abs(det(S)) < 1e-10` test is
    also scale dependent and should go with it.
  - Done when: both paths score a draw identically on a fixture with a constant column (and on one with collinear
    columns), with a test; NEWS bullet under "Changes that alter results" if allocations change.

- [x] TODO-326 (added 2026-11-21, owner; found while answering the v1.0.6-TODO-271 ties question): **The
  `InferenceSurvivalDepCensTransformRegr` Bayesian bootstrap resamples a Cox log hazard ratio, not the class's log
  time ratio.** `compute_estimate_with_bootstrap_weights()` (`R/EDI/R/inference_survival_dep_cens_transform.R`
  ~L49-68) replaces every weighted draw with `weighted_cox_bootstrap_surrogate_fit()` (`R/EDI/R/globals.R`), a
  weighted `survival::coxph` fit, and stores its treatment coefficient as `beta_hat_T`. The class's estimate is the
  treatment coefficient of the bivariate-normal dependent-censoring log-normal model (a log time ratio, from
  `fast_dep_cens_transform_optim_cpp`). Under a log-normal AFT the log hazard ratio has roughly the opposite sign and
  a different scale (about -beta / sigma), and it ignores the dependent censoring the class exists for. Only the
  constant-weights shortcut (~L51) returns the real estimate, which hides the mismatch on a quick check. The warm
  start passed to the Cox fit is the dependent-censoring fit's "params" / "beta" vector, also the wrong model. Found
  by reading the code, not yet reproduced; the Breslow-vs-Efron question (v1.0.6-TODO-271) is moot here.
  - First reproduce: on the fixture of `test-dep-cens-transform-recovers-log-time-ratio-under-dependent-censoring.R`
    (true log time ratio 0.5), compare `compute_estimate()` with the mean of Bayesian-bootstrap draws; expect a draw
    centre near the Cox log HR (negative), not 0.5. Check which public outputs use these draws (Bayesian-bootstrap
    CI / p-value, and any path that routes through `compute_estimate_with_bootstrap_weights`).
  - Fix (pick one): (a) add observation weights to the dependent-censoring likelihood (`fast_survival_models_optim.cpp`
    `DepCensTransformLikelihood` and `fast_dep_cens_transform_optim_cpp`, weights multiplying each row's
    log-likelihood and gradient) and refit it per draw, warm-started from the full-data params; or (b) if that is too
    slow or too unstable on small samples, remove `"BayesianBootstrap"` from the class's components so the method
    errors or is unsupported (as the jackknife and randomization methods already are), with the reason in the docs.
  - Update the roxygen that calls the surrogate an approximation (~L41-44 and ~L787-789) and its hand-edited Rd.
  - Done when: the Bayesian-bootstrap draws centre on the class's estimate (test against the known 0.5 fixture and,
    for (a), a weighted refit with all weights 1 equal to `compute_estimate()` without the shortcut), or the method
    is unsupported with a test; NEWS bullet under "Changes that alter results".
  - Decided 2026-11-21 (owner): option (b), the Bayesian bootstrap is unsupported; see [DECISION-v1.0.6-TODO-326](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-326).
  Status 2026-11-21 (coordinator, uncommitted; R only, no build). The class now overrides
  `compute_bayesian_bootstrap_two_sided_pval()`, `compute_bayesian_bootstrap_confidence_interval()` and
  `compute_estimate_with_bootstrap_weights()` to warn `edi_unsupported_procedure` (reason
  "dep_cens_transform_bayesian_bootstrap_not_supported") and return NA / an all-NA named CI, like its jackknife and
  randomization stubs; the component's `provides_public_methods` (contracts_mixins.R) and the class overrides list
  name them. Roxygen and the hand-edited Rd say so; NEWS bullet under "Breaking changes". Test
  testthat_bulk/test-dep-cens-transform-bayesian-bootstrap-methods-not-supported.R (14 pass); the obsolete
  test-survival-dep-cens-transform-weighted-bootstrap-reference.R (it tested the Cox-surrogate wiring) is deleted and
  ci/test_runtimes.csv refreshed. Under load_all(compile = FALSE) the other DepCens, mixin-contract, registry and
  Bayesian-bootstrap test files pass (test-mixin-contracts.R 1678 pass). Not reproduced numerically first.

- [ ] TODO-424 (added 2026-11-23, owner; the optional item left open by v1.0.6-TODO-272): **Logistic IRLS runs the
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
    coefficients (sweep as in v1.0.6-TODO-272: far warm starts, separation, maxit 1..100), with a test and a timing
    note; NEWS bullet only if any result changes.

### custom-statistic docs-scenario findings, run 44358267779, 2026-11-20 (TODO-277..282)

The docs-scenario audit (`.github/workflows/audit-docs-scenarios.yml`, run 44358267779, 2026-11-18) followed the
custom-statistic article and help pages against installed 1.0.4. Findings and repros:
`git show origin/audit-notes:docs-scenarios/runs/2026-11-18-run44358267779/custom-statistic/findings.md`. The docs half of
f2 and f11 was fixed in f6d20e4d; f1, f5 and f6 (the null shift re-added on the wrong scale) are handled in a separate
entry.

- [ ] TODO-277 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f2): **`transform_responses`
  accepts any string.** `"bogus"`, `"sqrt"` and `"identity"` silently act as `"none"` (additive shift); `"logit"` is
  accepted on a continuous response with negative values. Fix: `match.arg(transform_responses, c("none", "log",
  "logit"))` in every public entry point that takes it (`compute_rand_two_sided_pval`, `compute_rand_confidence_interval`,
  `approximate_randomization_distribution_beta_hat_T`, in `inference_all_abstract_rand.R` /
  `inference_all_abstract_rand_ci.R`), and refuse `"log"`/`"logit"` when the response is outside the transform's domain
  (y <= 0 for log; y outside [0, 1] for logit) with a message naming the offending values. Test: each bad value errors;
  the three valid values still give today's results.

- [ ] TODO-278 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f3): **`r` from 1 to 9 gives a
  silent NA p-value.** The argument check is `r >= 1`, but at least `max(10, floor(r/10))` finite reference statistics
  are required, so r < 10 always returns NA (and `compute_rand_confidence_interval(r = 9)` returns `NA NA`) with no
  warning. The same silent NA happens whenever too many draws are non-finite. Fix: require `r >= 10` in the argument
  check, and warn (naming the number of finite draws and the minimum) whenever the NA comes from too few finite draws.
  Test: r = 9 errors; r = 200 with a statistic that is non-finite on most draws warns.

- [ ] TODO-279 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f4): **The RandCustom CI
  refusal for count and proportion responses names a CI the class does not have.** The message says "the randomization
  p-value and the randomization-bootstrap CI remain available", but `InferenceRandCustom` has no bootstrap CI (its help and
  `capabilities()` list only the randomization test and CI), and it ends with a pointer to an internal TODO that is not
  shipped. Fix: name only what this class can call (the randomization p-value) and point to the built-in classes for the
  response type; drop the internal pointer. Re-check this message after the null-shift scale fix (the separate f1/f5/f6
  entry), which may make the count and proportion randomization CI valid and the refusal unnecessary.

- [ ] TODO-280 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f8): **Multi-line C++ source
  gets "not a character".** `custom_randomization_statistic_cpp = c("double f(...,", "...) { return 1; }")` errors with
  "... not a character", although it is one. Fix: accept a character vector by `paste(x, collapse = "\n")`; keep the error
  for non-character input, and say what it actually got (`class(x)`, `length(x)`). Also document the two other accepted
  input kinds the message lists (a compiled Rcpp function from `Rcpp::cppFunction()`, an `RcppXPtrUtils::cppXPtr()`
  pointer), which the help does not mention. Test: the two-line source compiles and gives the same p-value as the
  one-string form.

- [ ] TODO-281 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f10): **An
  `InferenceCustomRand` subclass whose `fit()` calls a user helper returns NA p-values and CIs with 2 cores, silently.**
  With `set_num_cores(1)` (or the helper inlined into `fit()`) the same class gives 0.274, matching `InferenceRandCustom`.
  The helper is a global-environment function not exported to the worker processes, so every worker fit errors, the
  errors are swallowed and every draw is NA. Two fixes, both needed: (1) export the subclass's free variables (or the
  enclosing environment of `fit`) to the workers, or run user-defined `fit()` in the main session as `InferenceRandCustom`
  does for its R statistic; (2) never turn all-failed worker draws into a silent NA: warn with the first worker error
  message. Test: the repro from the finding gives the 1-core p-value with 2 cores; a `fit()` that always errors in workers
  warns with its message.

- [ ] TODO-282 (added 2026-11-20, coordinator, owner request; ds-custom-statistic-44358267779-f11): **Malformed
  `permutations` input is accepted or fails with an unrelated error.** A bare n x r matrix gives "$ operator is invalid
  for atomic vectors"; `list(w_mat = P)` with fewer than r columns gives "subscript out of bounds"; draws of the wrong
  length (40 rows for n = 50) are recycled and return a p-value; 1/2-coded draws return NA. The format is now documented
  (f6d20e4d: a list with `w_mat`, an n x r 0/1 matrix, optional `m_mat`). Fix: validate in one helper used by every
  entry point that takes `permutations`: accept a bare matrix as `list(w_mat = .)`; require n rows, at least r columns,
  values in {0, 1}, no NA; and say which rule failed. Test: each malformed case errors with its rule; the valid list still
  gives 0.304 on the finding's repro.

### Docs-scenario findings, run 44358267779, 2026-11-20 (TODO-290..320)

The docs-scenario audit (`.github/workflows/audit-docs-scenarios.yml`, run 44358267779, 2026-11-18) also followed the
sequential-designs, fixed-designs, clusters-blocking, factorial, survival-censoring and missing-data articles and help
pages against installed 1.0.4. Findings and repros: `git show
origin/audit-notes:docs-scenarios/runs/2026-11-18-run44358267779/<area>/findings.md`; "Repro: <area> F<k>" below
names the block in that file. Findings an existing entry already covers are cited there instead: sequential-designs
f1/f2/f6 (v1.0.6-TODO-77/-76/-78), clusters-blocking f1 and factorial f6 (v1.0.6-TODO-73), clusters-blocking f3
(v1.0.6-TODO-74), survival-censoring f1 (v1.0.6-TODO-163, verified fixed on HEAD 2026-11-20) and fixed-designs f2
(cited at v1.0.6-TODO-234, which did not fix it, and filed as v1.0.6-TODO-294). Code locations marked "suspected"
were found by reading, not by running a fix.

- [x] TODO-290 (added 2026-11-20, coordinator, owner request; ds-sequential-designs-44358267779-f3): **KK14/KK21
  constructors accept `lambda` and `t_0_pct` outside [0, 1].** `lambda = -1`, `1.5`, `2` or `NA` constructs silently;
  KK14 then fails at the first post-burn-in assignment (a third of the way into the trial) with "NaNs produced" and
  "missing value where TRUE/FALSE needed" (`qf()` in `DesignSeqOneByOneKK14`, `R/EDI/R/design_seq_one_by_one_KK14.R`
  ~L188), and KK21 with "'probs' outside [0,1]". `t_0_pct = -0.2` and `1.5` are accepted; 1.5 gives a design that
  never matches (0 pairs of 30) with no warning. The constructor stores both unchecked (`private$lambda = ...`,
  `private$t_0_pct = ...`, ~L129-130; KK21 passes them to `super$initialize()`). Fix: in the KK14 constructor (shared
  by KK21/KK21stepwise) `assertNumber(lambda, lower = 0, upper = 1)` with 0 < lambda < 1 and `assertNumber(t_0_pct,
  lower = 0, upper = 1)`, with messages naming the argument, like Efron's `weighted_coin_prob` check. Test: each bad
  value errors at `$new()` on all three KK classes; the defaults still give today's allocations. Repro:
  sequential-designs F3.
  Done 2026-11-21 (agent): the KK14 constructor (shared by KK21 / KK21stepwise) stops at `$new()` with "lambda must be
  a single number with 0 <= lambda <= 1." / "t_0_pct must be a single number with 0 <= t_0_pct <= 1." for a
  non-numeric, NA, length != 1 or out-of-range value. The endpoints stay legal, unlike the entry's "0 < lambda < 1":
  `lambda = 0` (never match) is used by `test-kk14-design-matching-threshold-early-phase-and-pair-invariants-reference.R`,
  and `lambda = 1` runs (matches whenever the reservoir is non-empty, 15 pairs of 30). Test: new
  `test-kk-design-lambda-and-t0-pct-argument-validation.R` (bad values error on all three classes; explicit defaults
  give the default allocation; the endpoints run).
  - Owner decision pending: [DECISION-v1.0.6-TODO-290](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-290) (confirm the closed [0, 1] for `lambda` and `t_0_pct`, or tighten to (0, 1) and change the test).

- [x] TODO-291 (added 2026-11-20, coordinator, owner request; ds-sequential-designs-44358267779-f4): **High priority:
  `InferenceContinKKGLMM`'s parametric bootstrap swaps the two variance components, so its CI is ~70x narrower than
  Wald and its p-value sits at the 2/(B+1) floor.** Audit (KK14, n = 60, 26 pairs): Wald CI [-0.238, 0.679], p = 0.347;
  parametric-bootstrap CI [0.214, 0.227] (B = 199) and p = 0.01; replicate SD ~0.003 against a model SE of 0.23;
  `InferenceSuite` reports the `param_boot_direct` row as "ok". Re-run on HEAD 2026-11-20 with `load_all(compile =
  FALSE)`: Wald [0.585, 1.056], bootstrap [0.810, 0.830], still collapsed. Cause (confirmed by reading):
  `simulate_under_lik_null()` (`R/EDI/R/inference_continuous_KK_glmm.R` ~L499) reads `sigma_u = exp(b[p + 1])` and
  `sigma_e = exp(b[p + 2])`, but `fast_gaussian_lmm_cpp` returns `b = c(beta, log_sigma_e, log_sigma_b)`
  (`R/EDI/src/fast_gaussian_lmm.cpp` ~L538-544): the residual SD is used for the pair effect and the (often near-zero)
  pair SD for the residual, so within-pair noise vanishes from the simulated data. The comment above the code has the
  same wrong order. The likelihood-ratio bootstrap (0.345) uses the same simulator but its statistic is less
  sensitive to the noise scale. Fix: swap the two indices (and the comment); check the other KK GLMM simulators
  (count, proportion, ordinal) and any other reader of `fast_gaussian_lmm_cpp()$b` for the same layout mistake. Test:
  on the finding's repro, the replicate SD is within 25% of the Wald SE and the bootstrap CI covers the Wald CI's
  midpoint; a small null simulation of the bootstrap p-value holds its size. NEWS: changes results. Repro:
  sequential-designs F4.
  Done 2026-11-21 (agent): the two indices in `simulate_under_lik_null()` are swapped back (`sigma_e = exp(b[p + 1])`,
  `sigma_u = exp(b[p + 2])`) and the comment gives the kernel's order; the code change itself went in with commit
  8d8c5f78. No other reader of `fast_gaussian_lmm_cpp()$b` exists, and the count, proportion and ordinal KK GLMM
  classes have no `simulate_under_lik_null()` of their own. The legacy fixture
  `testthat_bulk/fixtures/legacy_contin_kk_glmm.R` had the same lines and got the same fix, so
  `test-contin-kk-glmm-migration-golden.R` still compares like with like (its `param_boot_pval` row moved 0.9 -> 1).
  Test: `test-contin-kk-glmm-null-simulation-variance-component-order.R` (the v1.0.6-TODO-56 skip removed, plus the
  F4 repro: replicate SD within 0.75-1.33x the OLS SE, CI contains the estimate). Evidence on the F4 repro (B = 199):
  bootstrap CI [0.810, 0.830] -> [0.332, 1.208], replicate SD 0.0052 -> 0.237 (lmer REML = FALSE SE 0.233, OLS SE
  0.241). Null size (KK14, n = 50, y = x1 + N(0, 1), 60 datasets, B = 99): parametric-bootstrap p-value rejects at
  5% in 75% of datasets before, 10% after (MC SE ~4%); LR bootstrap 6.7% before, 8.3% after. Found, not changed:
  on this repro the Wald CI is [0.585, 1.056] (SE 0.120) against lmer's 0.233; the kernel's
  `vcov` (inverse full observed information) at log_sigma_b = -4.0 has a negative diagonal for log_sigma_b and a w SE
  of 0.120, so the Wald SE looks wrong when sigma_b is near 0. The finding's run (older build) had Wald SE 0.230. The
  TODO's "within 25% of the Wald SE" test was therefore written against the OLS SE instead.
  - Owner decision pending: [DECISION-v1.0.6-TODO-291](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-291) (fix the KK GLMM Wald SE near sigma_b = 0, or accept it?).

- [x] TODO-292 (added 2026-11-20, coordinator, owner request; ds-sequential-designs-44358267779-f5):
  **`InferenceSuite$run_all_inference()` with `max_secs_per_class` and `num_cores = 2` prints the report and then
  fails with "arguments imply differing number of rows: 1, 0", losing every result.** The same call with `num_cores =
  1L`, or without `max_secs_per_class`, returns 3 rows; in a 13-class run 2 min 13 s of results were lost, and a forked
  worker printed "write error, closing pipe to the master". The error comes from the `results_table` build
  (`R/EDI/R/inference_suite.R` ~L5348, `data.frame(inference_class = r$inference_class, ...)`), so one row has a
  length-0 field. Suspected: a row produced on the fork-timeout path lacks a field, e.g.
  `run_all_inference_fork_timeout_row()` (~L1431) sets no `tau`, so `r$tau` is NULL. Fix: build every row from one
  constructor that fills every column (NA for missing), and make the table builder use `%||% NA` for each field so a
  bad row cannot drop the whole report. Test: the finding's repro (`classes = "InferenceContinRobustRegr"`, 2 cores,
  `max_secs_per_class = 20`) returns `results_table` with the same rows as 1 core; a forced timeout row has every
  column. Repro: sequential-designs F5.
  Done 2026-11-21 (agent): `run_all_inference_fork_timeout_row()` now sets `tau = NA_real_`, and the `results_table`
  builder in `run_all_inference()` maps any NULL or length-0 field to a typed NA, so one bad row cannot drop the
  report. (The suggested single row constructor for every path was not done; the builder guard covers it.) Test:
  `test-run-all-inference-fork-timeout-row-and-unavailable-packages-footer-reference.R` (the field set now includes
  tau; a new end-to-end block runs the F5 repro with `max_secs_per_class = 3` and checks 3 rows with the rand row
  "timeout"). Evidence on the F5 repro (2 cores, `max_secs_per_class = 20`): before, "arguments imply differing
  number of rows: 1, 0"; after, 3 rows (wald ok, rand timeout, jackknife ok), as at 1 core apart from the rand row.
  Found, not changed: at 1 core the rand row took 60.7 s and reported "ok", so `max_secs_per_class` is only enforced
  on the fork path; and at 2 cores the jackknife row, which ran next to the killed worker, reported "CI (jackknife)
  failed: ignoring SIGPIPE signal" (its p-value is fine).

- [x] TODO-293 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f1): **High priority:
  after `compute_rand_two_sided_pval()`, `InferenceAllSimpleMeanDiffPooledVar`'s asymptotic p-value and CI are
  silently `NA`.** On a fresh object the p-value is 0.9359437 (matches `t.test(var.equal = TRUE)`); after one
  `compute_rand_two_sided_pval(r = 101)` it is `NA` and the CI `NA NA`, with no warning, while `is_nonestimable()` is
  FALSE and `compute_estimate()` still returns the number. In a 200-replicate loop all 200 asymptotic p-values were
  NA. Same on iBCRD and Rerandomization; `InferenceAllSimpleAverageDiff` and `InferenceContinOLS` are not affected.
  Suspected cause: `compute_direct_pooled_t_components()` (`R/EDI/R/inference_all_simple_mean_diff_pooled_var.R`
  ~L157) only calls `compute_estimate()` when `cached_values$beta_hat_T` is NULL and then reads
  `cached_values$yTs`/`yCs`; the parent's fast estimate path (`R/EDI/R/inference_all_average_diff.R` ~L142-145, used
  by the randomization machinery) caches `beta_hat_T` without `yTs`/`yCs`, so `n_t = n_c = 0` and the NA branch is
  cached. Fix: compute the pooled components from `private$y`/`private$w` directly (or recompute `yTs`/`yCs` when
  missing, as `inference_all_average_diff.R` ~L242 does), and never cache NA components when the inputs are valid.
  Test: every procedure order (rand p, rand CI, bootstrap, then asymptotic, and the reverse) gives the fresh-object
  asymptotic p and CI. Repro: fixed-designs F1.
  Done 2026-11-21 (agent): `compute_direct_pooled_t_components()` now rebuilds `yTs`/`yCs` from `private$y` and
  `private$w` when the randomization path cached `beta_hat_T` without them (the same guard
  `InferenceAllSimpleAverageDiff` has); the code and test went in with commit 297cae6d. Test: a new block in
  `test-pooled-var-mean-diff-pooled-ttest-reference.R` runs rand p, rand CI and bootstrap CI before and after the
  asymptotic calls and checks p and CI against `t.test(var.equal = TRUE)`. Evidence on the F1 repro: after
  `compute_rand_two_sided_pval(r = 101)` the asymptotic p was NA and the CI `NA NA`; now 0.9359437 and
  [-1.393, 1.289], the same as a fresh object and `t.test`.

- [x] TODO-294 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f2): **The realized
  `DesignFixedRerandomization` allocation with `prop_acceptable` comes from a different law than its randomization
  reference, and the randomization test over-rejects (7.25% at nominal 5%).** `assign_w_to_all_subjects()` takes r = 1,
  i.e. the best of `round(1 / prop_acceptable)` = 100 draws, while `draw_ws_according_to_design(501)` keeps the best
  501 of 50,100 (`draw_ws_raw()`, `R/EDI/R/design_fixed_rerandomization.R` ~L212-230). Audit (n = 40, two covariates,
  `prop_acceptable = 0.01`): 31.7% of realized allocations have M(w) above the base distribution's 1% quantile, 0% of
  the reference draws do (KS D = 0.317); randomization test size 7.25% over 800 null trials (MCSE 0.77%), 5.88% with
  `obj_val_cutoff` at the same quantile. v1.0.6-TODO-234 only changed treated-count rounding; re-run on HEAD
  2026-11-20 (`load_all(compile = FALSE)`): realized outside 0.3167, reference outside 0, KS D 0.3167, unchanged.
  Fix: as the owner decides (decision below). Either
  way update the roxygen paragraph that calls the two "equivalent in the large-draw limit". Test: on the finding's
  repro, the realized and reference M(w) distributions agree (KS p > 0.01 over 300 seeds), and a 400-trial null
  simulation of the randomization test is within 2 MCSE of 0.05. NEWS: changes results. Repro: fixed-designs F2.
  Investigated 2026-11-21 (agent): not changed.
  - Decided 2026-11-23 (owner): (b) best-of-k reference draws; see [DECISION-v1.0.6-TODO-294](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-294).
  - DONE 2026-11-23 (agent): R-only, no rebuild needed. `draw_ws_raw()`'s `prop_acceptable` branch now draws
    r * k candidates, k = round(1 / prop_acceptable), and returns the best of each consecutive group of k (first
    minimum on ties, as `order()` picked). Every redraw (rand p-values and CIs, rand bootstrap, which already used
    r = 1) goes through it, so all use the realized rule. At r = 1 the draws and the pick are the old ones: the
    300 realized allocations of the repro and three seeded cases (even n, odd n, prob_T = 0.3 with abs_sum_diff)
    are bit-identical before and after. Same cost (r * k = the old round(r / prop_acceptable) draws). The draws are
    one sequential stream from the design seed, so they do not depend on the core count. Numbers on the F2 repro
    (n = 40, prop_acceptable = 0.01): before, realized outside the base 1% quantile 0.317, reference 0, KS D 0.317,
    rand test size 7.25% (800 trials); after, realized 0.317, reference 0.363 (theory (0.99)^100 = 0.366), KS D
    0.058 (p = 0.53), size 6.88% on the same 800 trials and 6.07% over 2,800 (MCSE 0.45%). That is the size EDI's
    b / r p-value rule gives for any valid reference at r = 201: P(min(n_ge, n_le) <= 5) = 12 / 202 = 5.94%
    (v1.2.0-TODO-207 covers that rule). On the same draws a (#{|T_b| >= |T_obs|}) / r p-value with the reference
    including the realized draw has size 5.05% (4,000 trials). So the entry's "400-trial null simulation within
    2 MCSE of 0.05" is not a test assertion: the residual is the p-value rule, not this design. Tests:
    `R/package_tests/testthat_bulk/test-rerandomization-prop-acceptable-reference-draws-follow-realized-law.R`
    (realized allocations pinned to the pre-fix values; best-of-group pool reference; KS D < 0.1 between 400
    realized and 1,000 reference draws, 0.0395 now and 0.37 with the old code; same reference and rand p at 1 and
    2 cores). Updated two tests that asserted the old best-r-of-pool rule
    (`test-rerandomization-objective-and-draw-paths-reference.R`, `test-rerandomization-objective-constant-covariate-column.R`).
    Docs: roxygen (class description, prop_acceptable path, @param; not roxygenized, Rd pending), NEWS, and the
    methods text in the reporting-an-analysis and custom-randomization-statistic articles. Changes 1.0.5 results:
    rand p-values and CIs of `DesignFixedRerandomization` with `prop_acceptable` (comprehensive rows for this design
    need regenerating).

- [x] TODO-295 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f3): **`DesignFixedGreedy`
  and `DesignFixedGreedyDOptimal` at their defaults return different allocations for the same seed when covariates
  have ties.** The help ("Same draws as DesignFixedGreedyDOptimal at the defaults") promises identical allocations;
  with weight rounded to 0.1 and age in whole weeks only 10 of 20 draws agree (none are mirrors), the realized
  allocation differs too, and the Mahalanobis imbalances differ by up to 3.9e-5, so the searches end at different
  local optima. With untied continuous covariates all 20 agree. Suspected: the two swap searches
  (`R/EDI/R/design_fixed_greedy.R` and `R/EDI/R/design_fixed_greedy_d_optimal.R`, and their C++ kernels) break ties
  between equal-improvement swaps differently, or compute the objective with different rounding so "equal" swaps
  compare differently. Fix: give both the same deterministic tie-break (lowest index pair) on the same objective
  computation, or, if that is not worth it, document that the identity holds only without ties. Test: the finding's
  tied-covariate repro gives 20 of 20 identical draws (or the doc change). Repro: fixed-designs F3.
  Done 2026-11-21 (agent), doc option: the two searches are separate C++ kernels (`greedy_design_search_cpp()` vs
  `d_optimal_search_cpp()`), so a shared tie-break needs a C++ change and a rebuild; instead the "same draws"
  paragraphs in `design_fixed_greedy.R` and `design_fixed_greedy_d_optimal.R` now say the identity can fail with tied
  covariates (roxygen only, Rd not regenerated). Still reproduces on HEAD: 10 of 20 tied draws agree. Test: new
  `test-greedy-and-greedy-d-optimal-same-draws-without-ties.R` (untied: 20 of 20 identical; tied: same treated count
  and Mahalanobis imbalances within 1e-3). If exact identity with ties is wanted, that is a C++ follow-up.

- [x] TODO-296 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f4):
  **`DesignFixedOptimal(objective = "abs_sum_diff")` with the default `solver = "auto"` hangs at n = 40 with no
  message.** n = 16 solves in 0.35 s, n = 24 in 3.7 s, n = 40 (`prob_T = 0.3`) had not returned after 400 s;
  `solver = "annealing"` takes 0.01 s. `solver = "auto"` always sends `abs_sum_diff` to the exact MILP
  (`optimal_solve_auto()`, `R/EDI/R/helper_optimal_annealing.R` / `milp_solve_l1()` in
  `R/EDI/R/helper_optimal_milp_solvers.R`, called from `R/EDI/R/design_fixed_optimal.R` ~L530) with no time limit, unlike
  the quadratic criteria, which switch to annealing above `linearization_max_n = 20` with a message. Fix: give the
  MILP a time limit (`solver_args$time_limit`, default e.g. 30 s, passed to GLPK's `tm_limit`) and on timeout fall back
  to annealing with a message that says the result is not certified optimal (and set the certificate accordingly);
  document the limit in "Solvers and certificates". Test: n = 40 with the default solver returns within the limit with
  the fallback message; n = 16 still returns the certified MILP optimum. Repro: fixed-designs F4.
  Done 2026-11-21 (agent): new `solver_args$milp_time_limit` (seconds, default 30 =
  `EDI_OPTIMAL_DEFAULT_MILP_TIME_LIMIT`, `Inf` for none; validated at `$new()`). `optimal_solve_auto()` passes it to
  `milp_solve_l1()`, which hands GLPK `tm_limit`; on the limit GLPK returns its feasible incumbent (status
  GLP_FEAS), and the auto path keeps the better of that and an annealing run, with a message, certificate
  `"annealing_converged"` and `milp_timed_out = TRUE` in the diagnostics. Only GLPK gets the limit (gurobi/cplex
  ignore it), and only `solver = "auto"` (a forced `solver = "ompr"` still has none). Roxygen ("Solvers and
  certificates", `solver_args`) updated, Rd not regenerated. Evidence: F4 repro (n = 40, prob_T = 0.3) with
  `milp_time_limit = 3` returns in 4.4 s with M(w) 0.00631, the same as `solver = "annealing"`; before, no return in
  400 s (finding). Test: new block in `test-optimal-solve-auto-dinkelbach-exhausted-annealing-fallback-reference.R`
  (n = 40 with a 2 s limit: message, annealing certificate; n = 16 at the default: "global"; bad limits error).

- [x] TODO-297 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f5):
  **`DesignFixedOptimal$get_optimization_diagnostics()$objective_value` is M/4 for "mahal_dist" and M/2 for
  "abs_sum_diff", not the documented M(w).** Hand-computed M(w) = 0.0005879 vs `objective_value` 0.000147; sum of
  |standardized mean differences| 0.02651 vs 0.0133. The C++ scaling is documented as internal in
  `?DesignFixedRerandomization` (and `design_fixed_rerandomization.R` ~L236-239 converts the user cutoff with the same
  factors 4 and 2), but `design_fixed_optimal.R` ~L614 reports `res$objective_value` unconverted. Fix: report
  `objective_value` on the user M(w) scale (multiply by 4 / 2 for those two objectives, check the other objectives),
  and say in the roxygen which scale it is. Test: on the finding's repro, `objective_value` equals the hand-computed
  M(w) for both objectives to 1e-10. NEWS: changes reported diagnostics. Repro: fixed-designs F5.
  Done 2026-11-21 (agent): the factor is not a constant 4 / 2: the solvers minimize f = 4 (Xc'w)' S^-1 (Xc'w) / n^2 and
  (2/n) sum_j |Xstd_j'w|, so M(w) = f n^4 / (4 n_T^2 n_C^2) and f n^2 / (2 n_T n_C) (4 and 2 only at n_T = n/2; at
  prob_T = 0.3, n = 40 the ratios were 5.67 and 2.38). New helper `optimal_objective_value_user_scale()` in
  `design_fixed_optimal.R` converts `objective_value` (a `"mahal_dist"` solve that fell back to l1 reports the
  abs_sum_diff M(w)); other objectives are unchanged; the solver value stays as `objective_value_internal`
  (`chain_values` etc. remain internal); roxygen of `get_optimization_diagnostics()` says which scale (Rd not
  regenerated). Evidence: hand M(w) / `objective_value` = 1 for both objectives at prob_T 0.5 and 0.3, n = 16 and 40,
  annealing and the exact MILP (was 4, 2, 5.67, 2.38, 5.42, 2.33). Tests: a new block in
  `test-fixed-optimal-solver-inputs-and-exact-allocation-reference.R`; three existing assertions that compared
  `objective_value` with internal solver values now read `objective_value_internal` (`test-design-fixed-optimal.R`,
  `test-fixed-optimal-solver-inputs-and-exact-allocation-reference.R`,
  `test-fixed-optimal-design-solve-diagnostics-mirror-coin-and-treated-count-guards-reference.R`). Related, not changed:
  `DesignFixedRerandomization`'s fixed 4 / 2 cutoff conversion (~L236) is only used for prob_T = 0.5 with even n,
  where it is right.

- [x] TODO-298 (added 2026-11-20, coordinator, owner request; ds-fixed-designs-44358267779-f6,
  ds-clusters-blocking-44358267779-f5): **Every fixed design accepts the default `n = NULL`, then
  `add_all_subjects_to_experiment()` errors although `X_all` gives n.** Bernoulli, iBCRD, Rerandomization, Greedy,
  GreedyDOptimal, BinaryMatch, Optimal, Blocking, Cluster and BlockedCluster all construct with `n = NULL` and then stop
  with "This type of design currently only works with fixed sample, i.e., you must specify n upon initialization"
  (`assert_fixed_sample()`, `R/EDI/R/design_abstract.R` ~L569, called from `add_all_subjects_to_experiment()` in
  `R/EDI/R/design_fixed_abstract.R` ~L65). On `DesignFixedCluster` a later `assign_w_to_all_subjects()` then errors
  "argument is of length zero". The help shows `n = NULL` as the default and calls `n` only "The sample size". Fix:
  as the owner decides (decision below). Either way `assign_w_to_all_subjects()` before subjects are
  added must give a clear error. Test: for every fixed design, `$new()` without `n` then `add_all_subjects_to_experiment(X)`
  works (or `$new()` errors), and the realized allocation equals the one with `n = nrow(X)` for the same seed. Repro:
  fixed-designs F6, clusters-blocking F5.
  Investigated 2026-11-21 (agent): still reproduces on HEAD. `$new()` without
  `n` then `add_all_subjects_to_experiment(X)` stops in `assert_fixed_sample()` for Bernoulli, iBCRD, BinaryMatch and
  Optimal; Rerandomization already stops earlier on its acceptance-rule check. Not changed.
  - Decided 2026-11-23 (owner): (a) infer `n = nrow(X_all)`, keep the mismatch error, error on assigning before subjects with `n` unknown; see [DECISION-v1.0.6-TODO-298](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-298).
  - Also reported by the docs-scenario audit: ds-observational-44883784401-f1 (2026-11-21, `ObservationalDesign`
    with the default `n = NULL` fails as soon as the data are added; reproduces on HEAD). Fix it here.
  Done 2026-11-24 (DECISION (a)): `DesignFixed$add_all_subjects_to_experiment()` sets `n` from `nrow(X_all)` via `set_n_from_subjects()` when the design has no `n` and no subjects; the mismatch error is always on and reads "X_all must have exactly n = <n> rows, but has <rows>."; `assert_n_known_for_assignment()` (DesignFixed and the BinaryMatch override) errors "<class>: n is not known yet; pass n to $new() or add the subjects first (add_all_subjects_to_experiment())." The `n` roxygen of the fixed-design and ObservationalDesign constructors describes the rule. Before: all 11 designs (Bernoulli, iBCRD, Rerandomization, Greedy, GreedyDOptimal, BinaryMatch, Optimal, Blocking, Cluster, BlockedCluster, ObservationalDesign) stopped with "you must specify n upon initialization", and assigning first gave "replacement has length zero", a Rerandomization prob_T/n = 0 error, a BinaryMatch "no covariates" error, or was accepted (Optimal, Blocking, Cluster, BlockedCluster). After: each takes n = 24 from X_all with `get_w()` identical to `n = 24` for the same seed; ds-observational-44883784401-f1 covered. Test: `R/package_tests/testthat_bulk/test-fixed-design-n-inferred-from-subjects.R`; `test-fixed-design-add-all-subjects-wrong-row-count-guard-reference.R` updated to the owner's wording.

- [x] TODO-299 (added 2026-11-20, coordinator, owner request; ds-clusters-blocking-44358267779-f2): **High priority:
  `approximate_bootstrap_distribution_beta_hat_T(bootstrap_type = ...)` returns cached draws of another
  `bootstrap_type`, and the cache leaks into `compute_bootstrap_confidence_interval()`.** On one object, a
  `"resample_blocks"` call after a `"within_blocks"` call (same seed) returns an object `identical()` to the first (SD
  0.531); a fresh object gives SD 0.430. In a 24-school trial NULL / `"within_blocks"` / `"resample_blocks"` all gave SD
  1.4726 on one object, while a fresh `"resample_blocks"` gave 2.22 (hand-coded block bootstrap 2.09). The percentile CI
  (B = 601, seed 1) was (-2.598, 3.575) on a fresh object and (-2.252, 5.679) after a `"resample_blocks"` diagnostic call,
  so the reported interval depends on an earlier call. Cause (confirmed by reading): the cache key is `as.character(B)`
  only (`R/EDI/R/inference_all_abstract_non_param_boot.R` ~L522, `get_cached_resampling_distribution("non_param_boot",
  cache_key)`), ignoring `bootstrap_type` and the seed. Fix: key the cache on B and the resolved bootstrap type (and
  check whether the seed belongs in the key too); make `compute_bootstrap_confidence_interval()` / p-value read only
  draws of the default type, never a diagnostic call's draws. Check the other resampling caches keyed by B alone.
  Test: the finding's repro gives `identical(a, b) == FALSE` and `identical(b, c) == TRUE`; the CI is the same with or
  without a prior `approximate_bootstrap_distribution_beta_hat_T()` call. NEWS: changes results. Repro:
  clusters-blocking F2.
  Done 2026-11-21 (agent): `approximate_bootstrap_distribution_beta_hat_T()` keys its cache on B and the
  bootstrap type (`"<B>::default"` for NULL, else `"<B>::within_blocks"` / `"<B>::resample_blocks"`), so the
  `compute_bootstrap_*()` callers (which pass NULL) only read default-type draws. Checked the sibling caches: the
  randomization-bootstrap cache (`inference_all_abstract_rand_bootstrap.R`) had the same gap for freshly drawn
  resamples and now keys them as `fresh:<type>` (supplied draws keep their `draws_id`, which already fixes the scheme);
  the Bayesian bootstrap, m-out-of-n and subsampling keys already include the type. The seed is not in the key:
  `set_seed()` clears no cache anywhere in the package, so keying one cache by seed would make this cache behave
  unlike the others; left as is. Test: a new block in
  `test-resampling-centered-pivots-cache-keys-and-size-evaluation-reference.R`. Evidence on the F2 repro (B = 200):
  `identical(a, b)` TRUE -> FALSE, `identical(b, c)` FALSE -> TRUE, SDs 0.531 0.531 0.430 -> 0.531 0.430 0.430;
  percentile CI after a `"resample_blocks"` diagnostic call [1.527, 2.722] -> [1.176, 3.111], the same as a fresh
  object.

- [x] TODO-300 (added 2026-11-20, coordinator, owner request; ds-clusters-blocking-44358267779-f4):
  **`assign_w_to_all_subjects(w_precomputed = )` accepts a 1/2-coded vector, keeps it, and inference then returns NA
  with no warning.** On `DesignFixedCluster`, `w_precomputed = wcl + 1` is accepted silently, `table(get_w())` shows 1
  and 2, and `InferenceAllSimpleAverageDiff` gives an NA estimate and NA randomization p-value (OLS happens to give the
  right slope, 2.946, so it is easy to miss). `DesignFixed$assign_w_to_all_subjects()`
  (`R/EDI/R/design_fixed_abstract.R` ~L49-51) assigns `as.numeric(w_precomputed)` with no check. Fix: validate
  `w_precomputed` there (shared by every fixed design): numeric or logical, length n, no NA, values in {0, 1}, both arms
  present, with a message naming the rule that failed. Test: 1/2 coding, wrong length, NA, a single arm, and a factor
  each error; a valid 0/1 vector still gives today's results. Repro: clusters-blocking F4.
  Done 2026-11-21 (agent): new private `validate_w_precomputed()` in `DesignFixed` (`design_fixed_abstract.R`), called
  by `assign_w_to_all_subjects()` for every fixed design: numeric or logical (factor/character refused), length n,
  no NA, only 0/1, both arms present, each with its own message; logical TRUE/FALSE is stored as 1/0. Test: new
  `test-fixed-design-w-precomputed-validation.R` (1/2 coding, wrong length, NA, one arm, factor, character error;
  logical and valid 0/1 vectors are stored unchanged). The bulk files that pass `w_precomputed` (14 checked, e.g.
  `test-fixed-observational-design-contracts.R`, `test-design-inference-introspection-audit.R`) still pass.

- [x] TODO-301 (added 2026-11-20, coordinator, owner request; ds-clusters-blocking-44358267779-f6):
  **`DesignFixedCluster$assign_w_to_all_subjects(w_precomputed = )` accepts an assignment that varies within
  clusters.** `w_precomputed = rbinom(n, 1, 0.5)` is accepted with no warning; both arms appear inside every school;
  `InferenceContinOLS` then reports a CR2 interval and a randomization p-value whose reference draws (whole schools)
  cannot produce the observed assignment. The help says every subject in a cluster gets the same assignment. Fix: in
  the cluster designs' `assign_w_to_all_subjects()` (`DesignFixedCluster`, `DesignFixedBlockedCluster`), after the
  0/1 check of v1.0.6-TODO-300, error when `w_precomputed` is not constant within `cluster_col`, naming the first
  offending clusters. Test: a within-cluster-varying vector errors on both classes; a cluster-constant one is
  accepted. Repro: clusters-blocking F6.
  Done 2026-11-21 (agent), with v1.0.6-TODO-300: `validate_w_precomputed()` also errors when the design has a
  `cluster_col` and `w_precomputed` is not constant within it, naming how many clusters vary and up to 5 of them
  (covers `DesignFixedCluster` and `DesignFixedBlockedCluster`). Test: same file, both classes (two flipped subjects
  -> "varies within 2 cluster(s)"; a cluster-constant vector is stored as given).

- [x] TODO-302 (added 2026-11-20, coordinator, owner request; ds-clusters-blocking-44358267779-f7): **On a
  blocked-cluster trial, `compute_bootstrap_confidence_interval(type = "prepivoted" | "double-bootstrap" |
  "calibrated")` returns `c(NA, NA)` with only "bootstrap_ci_unavailable", although `get_supported_bootstrap_ci_types()`
  lists them and the percentile CI is finite (-0.712, 2.654).** On another blocked-cluster data set the same types are
  finite, so it depends on the data in a way the user cannot see; on `DesignFixedCluster` (672 pupils) prepivoted and
  double-bootstrap took ~1.9 min each at B = 41 with 2 cores, which the help does not warn about. The bare reason comes
  from `missing_bootstrap_ci()` (`R/EDI/R/inference_all_abstract_non_param_boot.R` ~L1091-1106). Fix: find which inner
  step fails for these three types on the finding's data (inner bootstrap with too few blocks, or non-finite inner
  replicates) and give each a specific reason and advice, as the BCa reasons do; document the reasons and the cost
  (B x B_inner fits) in the help. Test: the finding's repro gives a classed warning with a specific reason for each
  type (or a finite CI, if the cause is a bug). Repro: clusters-blocking F7.
  Verified already fixed on HEAD 2026-11-21 (agent; `load_all(compile = FALSE)` with the EDI.so built 2026-11-21
  18:55): the F7 repro (B = 21, seed 1) gives prepivoted [-0.654, 2.635], double-bootstrap [-0.014, 3.274],
  calibrated [-0.654, 2.635] and percentile [-0.712, 2.654], all finite, no warning. Not traced which commit fixed
  it. Not done: the cost note for the help (prepivoted took ~20 s here at B = 21). Test: new
  `test-blocked-cluster-bootstrap-prepivoted-ci-finite.R` (prepivoted only, ~20 s).

- [ ] TODO-303 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f1,
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

- [ ] TODO-304 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f3): **On the 2 x 2 main-effect
  design (`DesignFixedBlocking` with 2 blocks) the default BCa bootstrap CI and p-value and every jackknife unit return
  NA, and the warnings recommend a randomization test that errors for incidence.** BCa gives NA with
  "bootstrap_bca_jackknife_too_few_deletion_units" (only 2 blocks); its message also says "the bootstrap itself
  resamples only those units", which contradicts the help (the default bootstrap resamples subjects within blocks; the
  percentile CI is a sensible 0.151 to 0.370). The jackknife gives NA for `"auto"`/`"block"` (2 units) and for
  `"observation"` ("not supported on this blocking design because its blocks hold more than one subject; use unit =
  "block""), so it sends the user to the unit that just failed. Both messages say to use a randomization test, which
  errors for incidence (v1.0.6-TODO-303). Fix: (1) on a design that resamples within blocks, compute the BCa
  acceleration from a leave-one-subject-out (within-block) jackknife instead of leave-one-block-out, or fall back to
  the percentile/BC interval with a warning that says so; (2) correct the "resamples only those units" sentence; (3)
  make the jackknife and BCa advice name a procedure that runs for the response type at hand (shared with
  v1.0.6-TODO-74's message fix); (4) the help's "the jackknife (resample within blocks)" must match what happens.
  Test: the finding's repro gives a finite default bootstrap CI or a warning whose advice runs; no jackknife message
  points to a unit that also fails. Repro: factorial F3.
  Investigated 2026-11-21 (agent): not changed. Part (2) is in `edi_warn_bca_jackknife_unavailable()` (`inference_all_abstract_non_param_boot.R`
  ~L2664: "the bootstrap itself resamples only those units"), and parts (2)-(3) depend on the advice chosen for
  v1.0.6-TODO-74 / -303 (which procedures run for incidence on these designs), so they are best done together after
  those rulings.
  - Owner decision pending: [DECISION-v1.0.6-TODO-304](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-304) (part (1): within-block jackknife BCa acceleration, or percentile / BC fallback?).

- [x] TODO-305 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f4): **`DesignFixedFactorial`
  accepts a non-integer number of levels (`list(subject = 2.5)`) and runs it as a two-level factor.** No error or
  warning; `get_w_factorial()` returns levels 1/2. An unnamed `list(2)` is also accepted and the column is named `Var1`,
  though the help says the names are the factor names. The constructor only checks `assertList(factors, types =
  "numeric", min.len = 1)` (`R/EDI/R/design_fixed_factorial.R` ~L72) and builds `expand.grid(lapply(factors,
  function(l) 1:l))`, so 2.5 becomes 1:2. Fix: require every entry to be an integer >= 2 (`assertIntegerish(l, lower
  = 2, len = 1)`), require a fully named list with unique non-empty names, and check the product rule on the validated
  integers. Test: 2.5, 1, 0, NA and an unnamed list each error with a message naming the factor; `list(subject_line =
  2)` still works. Repro: factorial F4.
  Done 2026-11-21 (agent): the `DesignFixedFactorial` constructor (always, not only with asserts on) requires a fully
  named list with unique non-empty names and every entry a whole number >= 2, with messages naming the factor
  ("factors$subject must be a whole number of levels >= 2 (got 2.5)."); entries are stored as integers before the
  product rule. `@param factors` updated (Rd not regenerated). Behaviour change beyond the finding: a single-level
  factor next to a two-level one (`list(dose = 1, arm = 2)`) was accepted and pinned by
  `test-factorial-design-two-arm-mapping-balance-and-factor-validation-reference.R`; it now errors, per this entry's
  "1 errors", and that assertion was changed to expect the error. Two unnamed lists in
  `test-fixed-design-constructor-two-arm-and-blocking-validation-guards-reference.R` were named. Test: new block in the
  factorial reference file (2.5, 1, 0, NA, -2, Inf, unnamed and empty-name lists error; `list(subject_line = 2)` runs and
  `get_w_factorial()` is named `subject_line`).
  - Owner decision pending: [DECISION-v1.0.6-TODO-305](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-305) (confirm that a one-level factor next to a two-level one now errors, or allow it again).

- [x] TODO-306 (added 2026-11-20, coordinator, owner request; ds-factorial-44358267779-f7):
  **`InferenceIncidExactFisher$compute_estimate()` returns a bare NA when an arm has no events.** Audit (n = 40, the
  A = 0 arm 0 of 20 events): estimate NA with no warning, while the exact CI is (0.551, Inf) and the p-value 0.009125,
  both matching `mantelhaen.test(exact = TRUE)`, whose OR is Inf. Checked on HEAD 2026-11-20 (`load_all(compile =
  FALSE)`): `get_exact_fisher_log_or_estimate()` (`R/EDI/R/inference_indicidence_exact_fisher.R` ~L118-127, added in
  271a7ea1, 2026-11-17) already marks the fit non-estimable (`is_nonestimable()` TRUE, reason
  `exact_fisher_conditional_mle_infinite`), but still emits no warning. Fix: route it through the shared
  non-estimable convention of v1.0.6-TODO-255 (classed `edi_procedure_na_warning` once per object, naming the empty
  arm, and saying the exact CI and p-value remain valid); document the reason in `?InferenceIncidExactFisher`. Test:
  the finding's repro warns once with that reason, on `DesignFixedBlocking` and `DesignFixediBCRD`; CI and p-value
  unchanged. Repro: factorial F7.
  - Also reported by the docs-scenario audit: ds-incidence-44883784401-f4 (2026-11-21, iBCRD zero cell: NA estimate,
    reason `exact_fisher_conditional_mle_infinite`, no warning; `inference_indicidence_exact_fisher.R:118-127`). Add
    its repro to this TODO's test.
  Done 2026-11-21 (agent): `get_exact_fisher_log_or_estimate()` now also calls `edi_warn_procedure_na()` (class
  `edi_procedure_na_warning`, reason `exact_fisher_conditional_mle_infinite`) once per fit (flag in
  `cached_values`), naming the cause ("the control arm has no events", "every treated subject has an event", ... or
  "the stratified table is separated") and saying the exact CI and p-value remain valid; the reason is documented in
  the class roxygen (Rd not regenerated). Test: new `test-exact-fisher-infinite-conditional-mle-warns.R` (the F7 repro
  on `DesignFixedBlocking` and `DesignFixediBCRD`, which is also the ds-incidence f4 shape: one warning, none on a
  repeat call, p = 0.009 and CI (finite, Inf) unchanged); the 13 fisher-named test files pass.

- [x] TODO-307 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f2):
  **`fast_weibull_regression(use_rcpp = FALSE)` reports "failed to converge" when the real problem is an empty column
  name.** With `X = cbind(w, d$age)` (column names `"w"`, `""`) the Rcpp path fits, but the survreg path stops with
  "Weibull regression failed to converge: attempt to use zero-length variable name". The wrapper turns every survreg
  error into "failed to converge" (`R/EDI/R/helper_glm_fit.R` ~L1061 and ~L1074). Fix: before calling survreg, give
  empty or duplicated column names safe names (`make.names(..., unique = TRUE)`, mapping the coefficient names back),
  and only say "failed to converge" for a real non-convergence; pass other errors through with their own message.
  Test: the finding's matrix fits on both paths with the same coefficients (1e-6). Repro: survival-censoring F2.
  Done 2026-11-21 (agent): the survreg path of `fast_weibull_regression()` (`helper_glm_fit.R`) fits under safe
  names (empty -> `X<j>`, duplicates made unique, names `y` / `dead` that collided with the response columns of its
  data frame renamed) and returns the coefficients under the original names; a survreg error is reported as "failed to
  converge" only when its message mentions convergence, otherwise as "Weibull regression (survreg) failed: <msg>".
  Evidence: the F2 matrix gives (1.27211, 0.18656, 0.02046) on both paths (was an error on survreg). Also fixed on
  the way: covariate columns named `y` or `dead` used to be overwritten by the response in that data frame. Test: new
  block in `test-fast-weibull-regression-r-fallback-reference.R`.

- [ ] TODO-308 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f3): **An exact event
  time of 0 is accepted, and `InferenceSurvivalWeibullRegr` then returns NA estimate, CI and p-value with no
  warning.** `add_all_subject_responses(ys = y)` with `y[1] = 0` passes `assert_y()` (`R/EDI/R/design_abstract.R`
  ~L1148-1151, `assertNumeric(y, lower = 0, ...)` for survival); Weibull then gives NA, only `is_nonestimable()` /
  reason `"model_fit_unavailable"` hint at it, and the reason does not mention the zero time. Cox, log-rank and RMST give
  finite results. Fix: as the owner decides (decision below). Test: the
  finding's repro errors at entry with the left-censoring advice (or warns with the new reason); positive times unchanged. Repro:
  survival-censoring F3.
  Investigated 2026-11-21 (agent): not changed.
  - Owner decision pending: [DECISION-v1.0.6-TODO-308](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-308) (refuse an exact time of 0 at data entry, or only in the parametric classes?).

- [x] TODO-309 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f4):
  **`InferenceSurvivalKMDiff$compute_asymp_two_sided_pval()` returns NA while `compute_asymp_confidence_interval()` is
  finite, and the warning's `na.rm = TRUE` cannot be passed.** Audit: CI (2.246, 8.740); p-value NA because 2 of 501
  bootstrap replicates were non-finite; `compute_asymp_two_sided_pval(na.rm = TRUE)` gives "unused argument"; only
  `compute_bootstrap_two_sided_pval(na.rm = TRUE)` gives 0.004008. The help says both asymptotic methods fall back to
  the bootstrap. `compute_asymp_two_sided_pval()` (`R/EDI/R/inference_survival_km_diff.R` ~L259-265) calls
  `compute_bootstrap_two_sided_pval(delta)` with the default `na.rm = FALSE`, while the CI fallback drops non-finite
  replicates. Fix: make the two fallbacks treat non-finite replicates the same way (drop them, subject to the
  valid-fraction guard of v1.0.6-TODO-12), and when NA is still returned, word the
  warning for the method the user called (no advice to pass an argument it does not take). Test: the finding's repro
  gives a finite asymptotic p-value consistent with the CI; on interval-censored data too. Repro: survival-censoring F4.
  Done 2026-11-21 (agent): `compute_asymp_two_sided_pval()`'s bootstrap fallback now passes `na.rm = TRUE`, like the
  CI fallback, so non-finite replicates are dropped subject to the bootstrap's `min_fraction_usable_samples = 0.95`
  guard; the NA warning it could give therefore no longer arises in this case (its wording, which names
  `compute_bootstrap_two_sided_pval()` and `na.rm`, was not changed). Evidence on the F4 repro: p NA -> 0.004008
  (CI 2.246 to 8.740 excludes 0), equal to `compute_bootstrap_two_sided_pval(na.rm = TRUE)`. Test: new block in
  `test-km-diff-interval-censored-median-not-reached-warns.R`; the interval-censored variant was not added.

- [ ] TODO-310 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f5): **On
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

- [ ] TODO-311 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f6): **User-facing
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
    RandCustom refusal of v1.0.6-TODO-279).
  - `R/EDI/R/inference_class_registry.R:325`: the same "See TODO-119 in ... release_v1_0_5.md." (registry refusal text).
  - `R/EDI/R/inference_class_registry.R:1184`: "(multimodal_log_liks.md)" (stereotype non-regularity note).
  - `R/EDI/R/helper_optimal_shared.R:39`: "DesignFixedGreedyDOptimal plan (see fix_design_hierarchy.md)" (an error).
  - `R/EDI/R/inference_procedure_regime.R:134`: "(TODO-192 regime note)" in a regime description string.
  Fix: replace each pointer with an installed help topic or article section (e.g. "Which classes accept interval
  censoring" in the censored-survival article, `?InferenceRand`), or drop it; keep internal references in comments.
  Add a source test that fails on any string literal in `R/` naming `package_metadata`, a `.md` file other than
  `REFERENCES.md`, or a `TODO-<n>`, so new ones cannot land. Repro: survival-censoring F6.

- [x] TODO-312 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f8):
  **`run_all_inference()` prints `p = NA` for every estimand that has only one inference class.** Right-censored n =
  100: every "(1 inferences)" line (Gehan-Wilcoxon, log-rank martingale, mean, RMST) shows `p = NA` while the class's
  own p-value is finite in the table (Gehan 0.561); every "(2 inferences)" line is finite; no warning. On an
  interval-censored trial all five lines were NA while the overall combined p (0.0173) was finite. The lines come from
  the per-estimand block in `R/EDI/R/inference_suite.R` (~L4340-4377), which calls
  `run_all_inference_combine_pvalues(groups[[g]])`; suspected: that combiner returns NA for a single p-value. Fix: a
  one-element group reports its own p-value (and the printed line says it is a single class). Also in the same run a
  Kaplan-Meier row showed `se NA, pval NA` with status "ok": a row whose p-value is NA should not be "ok" without a
  reason. Test: the finding's repro shows each single-class estimand's own p-value; a NA-p row carries a non-"ok" status
  or a message. Repro: survival-censoring F8.
  Done 2026-11-21 (agent), main part: the combiner returns NA for fewer than 2 usable p-values (pinned by
  `test-inference-suite-grouped-evidence-reference.R`, and right for the overall combined evidence), so the fix is in
  `run_all_inference_per_estimand_breakdown_lines()`: a group with exactly one finite p-value prints that p-value.
  The line still reads "(1 inferences)". Test: the breakdown test in
  `test-run-all-inference-combined-evidence-weights-summary-line-and-per-estimand-breakdown-reference.R` pinned NA for
  the one-row group; it now expects that row's p (0.0500). Not done: the "ok" status on a KM row with NA se and p
  (second part of the entry); not re-run on the finding's full suite repro.

- [x] TODO-313 (added 2026-11-20, coordinator, owner request; ds-survival-censoring-44358267779-f9): **On
  interval-censored data `InferenceSurvivalCoxPHRegr`'s Wald CI and p-value depend on the global RNG state even after
  `set_seed()`.** Same object seed 123: global seed 1 gives (-1.0867, -0.3260), p 0.000272; global seed 2 gives
  (-1.0931, -0.3196), p 0.000344; seed 1 again reproduces the first. On the audit's trial this moved the Wald p across
  0.05 (0.0437, 0.0571, 0.0689 in the suite). The result is cached, so a later `set_seed()` has no effect. The SEs come
  from `icenReg::ic_sp(model = "ph")`'s internal bootstrap (`icen_bs_samples = 200L`,
  `R/EDI/R/inference_survival_coxph.R` ~L466-475), which draws from the global stream. Fix: run the `ic_sp()` call
  under the object's seed (derive a seed from `private$seed`, save and restore the session RNG, as
  `with_derived_seed()` does for designs), and document in the help that this path's SE is bootstrap-based. Test: the
  finding's repro gives identical results for global seeds 1 and 2 under the same object seed, and different results
  for different object seeds. Repro: survival-censoring F9.
  Done 2026-11-21 (agent): when the object has a seed and `ic_sp()` is asked for bootstrap samples, the call runs
  under `seq_design_draw_seed(private$seed, "coxph_icenreg_ic_sp_bootstrap")` with the session `.Random.seed` saved
  and restored (`inference_survival_coxph.R`, icenReg dispatch); with no object seed it still draws from the session
  stream. Not done: the help sentence that this path's SE is bootstrap-based. Test: new
  `test-coxph-interval-censored-wald-se-uses-object-seed.R` (F9 repro: global seeds 1 and 2 give identical CI and p
  under object seed 123, object seed 456 differs, and the session stream after the call is unchanged). Unrelated,
  seen while running the 24 cox/interval test files: `test-weighted-cox-surrogate-coxph-fit-fast-path.R` fails 3
  expectations both with and without this change.

- [ ] TODO-314 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f1): **A `model_formula`
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

- [ ] TODO-315 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f2): **With
  `missingness_method = "error"`, covariate-adaptive sequential designs enroll subjects with NA covariates and fail later
  on a subject whose data are complete.** `DesignSeqOneByOneAtkinson` (p = 2) assigns subjects 1 to 4 although subject 1
  has `x2 = NA`; subject 5 fails with "Missing values detected in covariate(s): x2"; KK14/Atkinson with 3 covariates fail
  at t = 6. The message does not name the subject, and after it the trial cannot enroll anyone. The check lives in the
  lazy model-matrix build (`R/EDI/R/design_abstract.R` ~L1170-1177), which a sequential design first runs only when it
  needs covariates (after its burn-in). Fix: under `"error"`, check `anyNA(x_new)` in `add_one_subject()`
  (`R/EDI/R/design_seq_one_by_one_abstract.R` ~L79) before the subject is stored, and name the subject index and
  columns; also for `add_all_subjects_to_experiment()`. Test: the finding's repro errors at t = 1 naming subject 1 and
  x2; the design is unchanged after the error (see v1.0.6-TODO-316). Repro: missing-data F2.

- [x] TODO-316 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f3): **High priority: a
  refused `add_one_subject_to_experiment_and_assign()` still enrolls the subject: `get_t()` goes up and `w` is left
  NA.** After two refused calls `get_t()` is 6 and `get_w()[1:6]` is `0 1 0 0 NA NA`; each retry adds another
  unassigned subject, so the design is corrupted and cannot be repaired by retrying. Cause (confirmed by reading):
  `add_one_subject_to_experiment_and_assign()` (`R/EDI/R/design_seq_one_by_one_abstract.R` ~L239-258) calls
  `self$add_one_subject(x_new)` (which stores the row and increments `t`) before `assign_wt()`, and nothing rolls back
  when `assign_wt()` errors. The KK `n = NULL` corruption of ds-sequential-designs-44358267779-f2 (v1.0.6-TODO-76: t =
  5, w length 4, then `get_block_ids()` fails) is the same missing rollback. Fix: snapshot the mutable state (t, Xraw
  row, w, block/match state, model-matrix cache flags) before `add_one_subject()` and restore it in an `on.exit()` /
  `tryCatch()` when assignment fails, or validate everything that can fail before mutating. Test: inject a failing
  `assign_wt()` (and the finding's "error" repro); after the error `get_t()`, `get_w()`, `get_X_raw()` and the KK
  match state equal their values before the call, and a corrected retry gives the allocation an uninterrupted run
  gives. Repro: missing-data F3.
  Done 2026-11-21 (agent): `add_one_subject_to_experiment_and_assign()` (`design_seq_one_by_one_abstract.R`) takes a
  snapshot of the private fields before `add_one_subject()` and restores it in `on.exit()` unless the assignment was
  stored. The snapshot keeps references (copy-on-modify), not copies; the field-name list is computed once per object
  (`private$subject_state_field_names`); `Xraw` is deep-copied only when `x_new`'s columns differ, the one case where
  the add path changes it by reference (`:=` adding a column). Cost: 3,000 Bernoulli adds 3.8 s -> 4.1 s; 300 KK21
  adds 1.7 s -> 2.0 s (one run each, noisy). Test: new `test-sequential-add-subject-rollback-on-failed-assignment.R`
  (the F3 repro; an injected failing `assign_wt()` on KK21 / KK14 / Efron with fixed and NULL `n`: t, w, X and `m`
  are unchanged and a retry gives the uninterrupted run's allocation); fails on the old file, passes now. Evidence:
  F3 repro `get_t()` 6 -> 4. Not covered: state a subclass keeps in environments or other by-reference objects is not
  rolled back (none found on the add path).

- [ ] TODO-317 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f4): **An `Inf` covariate is
  accepted at enrollment, and inference later fails with `qr.default` "NA/NaN/Inf in foreign function call".**
  `add_all_subjects_to_experiment()` with `X$x2[3] = Inf` is accepted silently and `get_X()[3, ]` shows `Inf`;
  `InferenceContinOLS$compute_estimate()` then errors in `qr.default(X_mat)`. Responses are checked for finiteness
  (`assert_y()`), covariates are not; NaN is treated as missing and imputed. Fix: in `add_one_subject()` and
  `add_all_subjects_to_experiment()` refuse `Inf`/`-Inf` in numeric covariates with a message naming column and rows.
  Test: Inf in a fixed and a sequential design errors at entry naming x2 and row 3. Repro: missing-data F4.
  - Owner decision pending: [DECISION-v1.0.6-TODO-317](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-317) (refuse `Inf` covariates at entry, or treat them as missing under `"impute"`?).

- [ ] TODO-318 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f5): **When `"drop_column"`
  removes every covariate, covariate-balancing designs run silently without covariates.** `dim(get_X())` is `40 0`
  and `DesignFixedRerandomization(prop_acceptable = 0.01)` and KK14 assign with no warning, even with `verbose = TRUE`;
  in a 60-farm trial the rerandomized Mahalanobis imbalance on the true covariates was 0.092 under `drop_column`
  against 0.019 under `impute`. `draw_ws_raw()` simply falls back to unrestricted draws when `ncol(private$X) == 0`
  (`R/EDI/R/design_fixed_rerandomization.R` ~L206-207; KK, Greedy, Atkinson and Optimal have similar paths). Fix: when a
  design that uses covariates for assignment ends up with zero columns after the missingness step, warn once (classed
  `edi_no_covariates_left_warning`) naming the dropped columns and suggesting `"impute"`. Test: the finding's repro
  warns for Rerandomization and KK14; a design with covariates left does not. Repro: missing-data F5.

- [ ] TODO-319 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f7): **In sequential designs
  `get_X_raw()` and `get_X()` reorder the covariate columns when the first subject has missing values.** Input `a b c`
  with the first subject missing `a` and `c` gives `names(get_X_raw())` = `b a c` and `colnames(get_X())` starting `b a
  c`; values stay aligned by name, but positional indexing (`get_X()[, 1]`, `get_covariates()` in an extension class)
  gets the wrong covariate. Fixed designs keep the input order. Suspected: `add_one_subject()`
  (`R/EDI/R/design_seq_one_by_one_abstract.R` ~L79) builds the first row's schema from its non-missing columns first
  and appends the all-NA ones (logical-typed) afterwards. Fix: fix the column order from `names(x_new)` of the first
  subject (and keep it as later subjects arrive), whatever their missingness. Test: the finding's repro gives `a b c`
  for both getters; allocations unchanged. Repro: missing-data F7.

- [ ] TODO-320 (added 2026-11-20, coordinator, owner request; ds-missing-data-44358267779-f8): **`get_summary()` on
  `InferenceContinOLS` prints only the treatment row, though the docs promise the full coefficient table for
  model-based classes.** On complete data the output is a single `treatment` row (estimate -0.0535, SE 0.265); no
  intercept or covariate rows, so a user cannot see what imputed covariates or `*_is_missing` indicators contribute.
  `get_summary()` (`R/EDI/R/inference_all_abstract.R` ~L320) builds the table via `edi_build_summary_table()`; suspected:
  the OLS fast path caches only the treatment coefficient and SE, not the full coefficient vector and covariance with
  names, so the one-row fallback is used. Fix: have the OLS fit cache the named coefficient vector and its covariance
  (it already computes them), and check the other model-based classes for the same gap. Test: the finding's repro
  shows rows for the intercept, treatment, x1 and x2 matching `summary(lm())` to 1e-8. Repro: missing-data F8.

### Audit-written bug tests that were skipped without a TODO, 2026-11-22 (TODO-385..401)

The numerical-robustness audit (PRs #51, #64, #71) added these tests with `skip("open a release TODO for this")`, and no TODO was ever opened for them. Each one was re-run on HEAD `ac08e642` (2026-11-22) with the skip removed, under `load_all(compile = FALSE)`. Every test that still fails now skips with a message citing its TODO.

- [ ] TODO-385 (added 2026-11-22, coordinator, owner request; numerical-robustness-609a1f12ec78): **`InferencePropBetaRegr` marginal-mean-diff SE is NA when a covariate is on a large scale.**
  On HEAD, `se_big` is NA while the unit-scale SE is 0.0328. `generate_mod()` (`R/EDI/R/inference_proportion_beta.R` ~L741) discards the vcov when the raw `rcond(fi) < sqrt(eps)`, and that test depends on scale.
  Fix: test conditioning on `D^{-1/2} fi D^{-1/2}` with `D = diag(fi)`, or use the kernel's own invertibility flag.
  Test: `R/package_tests/testthat_bulk/test-beta-regr-marginal-se-covariate-rescaling-invariance.R` ("beta regression marginal_mean_diff SE is invariant to rescaling a covariate"), currently skipped; remove the skip when fixed.
- [ ] TODO-386 (added 2026-11-22, coordinator, owner request; numerical-robustness-23a66300445a): **Combined evidence returns NaN, or one p-value labelled as combined, when fewer than two rows have a positive custom weight.**
  On HEAD, `res0$pval` is NaN with all-zero weights, and with one positive weight the result is that row's p-value instead of NA. `run_all_inference_combine_pvalues()` (`R/EDI/R/inference_suite.R` ~L4273) counts a row as usable whenever its weight is finite, zero included.
  Fix: require `weights > 0` in `usable`, so the existing `n_used < 2 -> NA` branch fires.
  Test: `R/package_tests/testthat_bulk/test-combined-evidence-zero-custom-weights-not-nan.R` ("combined evidence returns NA, not NaN or a single p-value, when fewer than two rows carry positive weight"), currently skipped; remove the skip when fixed.
- [ ] TODO-387 (added 2026-11-22, coordinator, owner request; numerical-robustness-3165df9ca614): **The Cox R fallback kernel always reports `converged = TRUE`.**
  On HEAD, on a monotone-likelihood fit where `coxph.fit` runs out of iterations and warns, `fit_converged` differs from the reference flag. `.fit_survival_coxph_kernel()` (`R/EDI/R/inference_survival_coxph.R` L44/L69/L105) hard-codes `converged = TRUE` inside `suppressWarnings()`.
  Fix: derive `converged` from `coxph.fit` (`iter < iter.max`, no "Ran out of iterations") and pass it through the fixed-kernel wrapper.
  Test: `R/package_tests/testthat_bulk/test-coxph-r-fallback-kernel-convergence-flag.R` ("Cox R fallback kernel reports convergence only when survival::coxph.fit converged"), currently skipped; remove the skip when fixed.
- [ ] TODO-388 (added 2026-11-22, coordinator, owner request; numerical-robustness-6fbae0626f0b): **The combined conditional-Poisson restricted fit reports `converged = FALSE` at the exact restricted optimum.**
  On HEAD, `fit$converged` is FALSE even though the free-parameter estimates match the restricted MLE. `fast_cpoisson_combined_internal` (`R/EDI/src/fast_cpoisson_combined.cpp` ~L340) tests `grad.norm()` over all parameters, including the ones held fixed by `fixed_idx`.
  Fix: take the norm over `fixed_spec.free_idx` only, as the Newton step already does.
  Test: `R/package_tests/testthat_bulk/test-cpoisson-combined-fixed-parameter-convergence-flag.R` ("combined cond-Poisson restricted fit reports convergence at the restricted optimum"), currently skipped; remove the skip when fixed.
- [x] TODO-389 (added 2026-11-22, coordinator, owner request; numerical-robustness-c8ab3465e2aa): **`InferenceIncidRiskDiff` returns an NA estimate on a perfect fit (y = w; the true RD is 1).**
  On HEAD, `compute_estimate()` returns NA where 1 is expected. `generate_mod()`'s `fit_ok` (`R/EDI/R/inference_incidence_risk_diff.R` ~L290-320) requires a positive HC0 variance, so the zero-variance fit is rejected and the finite point estimate is lost.
  Fix: accept a finite treatment coefficient, and mark only the SE as non-estimable.
  Test: `R/package_tests/testthat_bulk/test-incidence-risk-diff-perfect-fit-estimate-not-na.R` ("risk-difference estimate is returned for a perfect fit even though the HC0 SE is not estimable"), currently skipped; remove the skip when fixed.
  Done 2026-11-24 (code and unskipped test in cf4b5a29, which picked up this session's staged edit): `generate_mod()`'s `fit_ok` keeps the first fit with a finite treatment coefficient as a fallback; when no attempt has a positive HC0 variance that fit is used with `ssq_b_j = NA`, so only the SE is non-estimable. Before / after on the test case (n = 40, y = w): estimate NA -> 1, asymptotic CI NA (unchanged). `test-zero-inflated-smart-cold-start-and-risk-diff-nonestimable-reason.R` asserted the old behaviour on an all-zero response (reason `model_fit_unavailable`); it now expects estimate 0 and reason `model_standard_error_unavailable`. 88 risk-difference / rand test files pass.
- [ ] TODO-390 (added 2026-11-22, coordinator, owner request; numerical-robustness-a98e2d9a3577): **`InferenceCountKKCondPoissonOneLik`'s pairs-only fallback always sets the SE to NA.**
  On HEAD, the SE is NA where the reference conditional-logit model SE is 0.173. `try_pairs_only()` (`R/EDI/R/inference_count_KK_cond_poisson.R` ~L2210) sets `s_beta_hat_T = NA_real_`, so studentized bootstrap replicates on that path have no SE.
  Fix: when `!estimate_only`, use the `[1,1]` entry of `solve(crossprod(X, X * n_k * p * (1 - p)))`, as `try_reservoir_only` does.
  Test: `R/package_tests/testthat_bulk/test-kk-cond-poisson-pairs-only-fallback-standard-error.R` ("KK cond-Poisson pairs-only fallback reports the finite conditional-logit model SE"), currently skipped; remove the skip when fixed.
- [ ] TODO-391 (added 2026-11-22, coordinator, owner request; numerical-robustness-5402ae828a70): **The off-optimum penalized neg-loglik is finite at an indefinite information matrix.**
  On HEAD, with `diag(2, -3)` the function returns -0.396 instead of Inf. `evaluate_penalized_neg_loglik_at()` (`R/EDI/R/inference_mixin_off_optimum_likelihood_eval.R` ~L99) uses `determinant()$modulus` and drops the sign, so the Jeffreys/Firth penalty is evaluated where it is undefined.
  Fix: return Inf unless `chol()` succeeds (or `$sign == 1`), and use `2 * sum(log(diag(R)))` as the log-determinant.
  Test: `R/package_tests/testthat_bulk/test-off-optimum-penalized-loglik-indefinite-information.R` ("penalized neg-loglik is infeasible (Inf) when the information matrix is indefinite"), currently skipped; remove the skip when fixed.
- [ ] TODO-392 (added 2026-11-22, coordinator, owner request; numerical-robustness-96505e151f00): **The cloglog full-data multistart does nothing on the estimate-only path.**
  On HEAD, a stalled primary fit is returned unchanged: `b[1]` is 1.64 against the MLE's -0.357. `.cloglog_full_data_multistart()` (`R/EDI/R/inference_ordinal_cloglog.R` L1) needs `neg_loglik`, which the estimate-only kernel never returns, so no candidate can be compared.
  Fix: have the estimate-only kernel return `neg_loglik`, or evaluate it in the helper. Related: v1.1.0-TODO-203 (gate the multistart on a certificate).
  Test: `R/package_tests/testthat_bulk/test-ordinal-cloglog-estimate-only-multistart-repairs-stalled-fit.R` ("cloglog full-data multistart repairs a stalled primary fit on the estimate-only path"), currently skipped; remove the skip when fixed.
- [x] TODO-393 (added 2026-11-22, coordinator, owner request; numerical-robustness-5b7fd96029e3): **`InferenceOrdinalGCompMeanDiff` changed with a covariate's location (uncentred covariate, unchecked `converged`).**
  Verified fixed on HEAD 2026-11-22 (test passes; skip removed). At `ac08e642` all 3 expectations pass with the skip removed. The fixing commit was not identified.
  Test: `R/package_tests/testthat_bulk/test-ordinal-gcomp-mean-diff-uncentred-covariate-shift-invariance.R` ("ordinal G-comp mean difference is invariant to shifting a covariate's location"), now unskipped.
- [x] TODO-394 (added 2026-11-22, coordinator, owner request; numerical-robustness-dfcefb11b502): **`InferenceCountPoisson` returns 0 for large counts (cell means ~2e4) under the default zero cold start.**
  On HEAD, `fast_poisson_regression_cpp` returns `b = c(0, 0)` against glm's `c(9.938, 0.651)`, and the estimate is 0 instead of 0.694. Ten step-halvings cannot rescue the first IRLS step from `beta = 0` (`R/EDI/src/fast_poisson_regression.cpp`, `fast_poisson_internal`), and `fit_ok` (`R/EDI/R/inference_count_poisson.R` ~L563/L953) never checks `converged`.
  Fix: retry from the smart `log(y + 0.1)` start when halving fails, and reject non-converged fits in `fit_ok`. This is the same kernel as TODO-395 and TODO-396.
  Test: `R/package_tests/testthat_bulk/test-poisson-large-counts-zero-start-step-halving.R` ("Poisson estimate matches glm for large counts under the default zero cold start"), currently skipped; remove the skip when fixed.
  Implemented 2026-11-24, needs a rebuild to verify: `fast_poisson_internal()` (`R/EDI/src/fast_poisson_regression.cpp`) refits once from the smart `log(y + 0.1)` start when the zero cold start does not converge, and the class rejects an unconverged fit (`isFALSE(mod$converged)`). Kernel-swap check (sourceCpp of the edited file under `load_all(compile = FALSE)`): kernel `b` `c(0, 0)` -> `c(9.938, 0.651)` (glm), class estimate 0 -> 0.694; skip removed, test passes with the swapped kernel and fails on the installed `.so` until the rebuild. Verified 2026-11-24 on the EDI.so rebuilt at 00:20 (after 4392d9dc): `fast_poisson_regression_cpp` returns `c(9.9376, 0.6505)`, converged, and all three classes give 0.6942 = glm; the three tests pass. 87 Poisson-family bulk files pass with the swap (only the pre-existing zero-augmented failures in `test-count-likelihood-families-focused.R`). python/tests fixtures unaffected (their zero-start fits converge, so the retry never runs).
- [x] TODO-395 (added 2026-11-22, coordinator, owner request; numerical-robustness-0cdb0c814d69): **`InferenceCountQuasiPoisson` returns 0 for large counts under the zero cold start.**
  On HEAD, the estimate is 0 instead of 0.694. This is the same kernel failure as TODO-394, and `fit_ok` (`R/EDI/R/inference_count_quasipoisson.R` ~L321) accepts it because the Pearson dispersion stays finite.
  Fix: the same as TODO-394, applied to this class's `fit_ok`.
  Test: `R/package_tests/testthat_bulk/test-quasipoisson-large-counts-zero-start-step-halving.R` ("quasi-Poisson estimate matches glm for large counts under the default zero cold start"), currently skipped; remove the skip when fixed.
  Implemented 2026-11-24, needs a rebuild to verify: `fast_poisson_internal()` (`R/EDI/src/fast_poisson_regression.cpp`) refits once from the smart `log(y + 0.1)` start when the zero cold start does not converge, and the class rejects an unconverged fit (`isFALSE(mod$converged)`). Kernel-swap check (sourceCpp of the edited file under `load_all(compile = FALSE)`): kernel `b` `c(0, 0)` -> `c(9.938, 0.651)` (glm), class estimate 0 -> 0.694; skip removed, test passes with the swapped kernel and fails on the installed `.so` until the rebuild. Verified 2026-11-24 on the EDI.so rebuilt at 00:20 (after 4392d9dc): `fast_poisson_regression_cpp` returns `c(9.9376, 0.6505)`, converged, and all three classes give 0.6942 = glm; the three tests pass. 87 Poisson-family bulk files pass with the swap (only the pre-existing zero-augmented failures in `test-count-likelihood-families-focused.R`). python/tests fixtures unaffected (their zero-start fits converge, so the retry never runs).
- [x] TODO-396 (added 2026-11-22, coordinator, owner request; numerical-robustness-747496232200): **`InferenceCountRobustPoisson` returns 0 for large counts under the zero cold start.**
  On HEAD, the estimate is 0 instead of 0.694, with a sandwich SE evaluated at `b = 0`. `fit_count_model_with_var()` (`R/EDI/R/inference_count_robust_poisson.R` ~L218) checks only that the coefficients are finite.
  Fix: check `mod$converged` and refit from the smart start (or take the kernel fix from TODO-394).
  Test: `R/package_tests/testthat_bulk/test-robust-poisson-large-counts-zero-start-step-halving.R` ("robust Poisson estimate matches glm for large counts under the default zero cold start"), currently skipped; remove the skip when fixed.
  Implemented 2026-11-24, needs a rebuild to verify: `fast_poisson_internal()` (`R/EDI/src/fast_poisson_regression.cpp`) refits once from the smart `log(y + 0.1)` start when the zero cold start does not converge, and the class rejects an unconverged fit (`isFALSE(mod$converged)`). Kernel-swap check (sourceCpp of the edited file under `load_all(compile = FALSE)`): kernel `b` `c(0, 0)` -> `c(9.938, 0.651)` (glm), class estimate 0 -> 0.694; skip removed, test passes with the swapped kernel and fails on the installed `.so` until the rebuild. Verified 2026-11-24 on the EDI.so rebuilt at 00:20 (after 4392d9dc): `fast_poisson_regression_cpp` returns `c(9.9376, 0.6505)`, converged, and all three classes give 0.6942 = glm; the three tests pass. 87 Poisson-family bulk files pass with the swap (only the pre-existing zero-augmented failures in `test-count-likelihood-families-focused.R`). python/tests fixtures unaffected (their zero-start fits converge, so the retry never runs).
- [ ] TODO-397 (added 2026-11-22, coordinator, owner request; numerical-robustness-f0b0281da215): **The stereotype logit parametric-bootstrap simulator breaks for a binary (K = 2) response.**
  On HEAD, `simulate_under_lik_null()` returns NULL and the parametric-bootstrap LR p-value is NA (with a warning). `gammas = params_null[(n_alpha + p + 1L):n_params]` (`R/EDI/R/inference_ordinal_stereotype_logit.R` ~L716) counts downward when there are no loadings, which gives `c(NA, beta)`.
  Fix: `gammas = if (n_gamma > 0L) params_null[n_alpha + p + seq_len(n_gamma)] else numeric(0)`. Check the same idiom at ~L44.
  Test: `R/package_tests/testthat_bulk/test-stereotype-logit-binary-response-param-bootstrap-simulation.R` ("stereotype logit parametric LR bootstrap simulates a binary (K = 2) response"), currently skipped; remove the skip when fixed.
- [ ] TODO-398 (added 2026-11-22, coordinator, owner request; numerical-robustness-5a9caf5f5780): **The estimate-only stratified-Cox helper reports `converged = TRUE` after hitting `iter.max`.**
  On HEAD, `res$converged` is TRUE for an unconverged coefficient. `cox_partial_likelihood_fit_estimate_only_fast()` (`R/EDI/R/inference_survival_strat_cox.R` ~L59-92) hard-codes the flag. This is the sibling of TODO-387.
  Fix: take the flag from `coxph.fit` (iterations below the cap and no "Ran out of iterations"), or return NULL when the cap is hit.
  Test: `R/package_tests/testthat_bulk/test-strat-cox-estimate-only-fit-convergence-flag.R` ("estimate-only coxph.fit helper does not report convergence when the iteration cap is hit"), currently skipped; remove the skip when fixed.
- [ ] TODO-399 (added 2026-11-22, coordinator, owner request; numerical-robustness-7110d0cf73ab): **The ZIP degeneracy check flags well-identified fits whose count intercept is below -15 (an uncentred covariate).**
  On HEAD, the marginal CI is `c(NA, NA)` on the raw covariate and `(-0.102, 0.957)` once it is centred. `zero_augmented_fit_is_degenerate()` (`R/EDI/R/inference_count_zero_augmented_poisson_abstract.R` ~L1699) uses `params[1] < -15`, which depends on where the covariates sit.
  Fix: drop the intercept rule, or check the fitted rates instead (e.g. `max(lambda)` near 0).
  Test: `R/package_tests/testthat_bulk/test-zero-augmented-degeneracy-uncentered-covariate-intercept.R` ("ZIP marginal CI is finite and invariant to shifting an uncentered covariate"), currently skipped; remove the skip when fixed.
- [ ] TODO-400 (added 2026-11-22, coordinator, owner request; numerical-robustness-dfcfe3aea2a6): **The Zhang combined p-value treats an underflowed matched-pairs p (p_M = 0) as missing, so the exact CI upper bound becomes +Inf.**
  On HEAD, `p_fn(8.5)` is 1.00 where it should be at most 0.05, and the upper endpoint is Inf where the expected value is below 0.5. In `zhang_combine_exact_pvals()` (`R/EDI/R/inference_helpers_zhang.R` L20-21), `has_M` requires `p_M > 0`.
  Fix: treat `p_M == 0` (or `p_R == 0`) as decisive (combined p = 0), or compute the components in log space. Related: v1.1.0-TODO-211 (tail-accurate combination).
  Test: `R/package_tests/testthat_bulk/test-zhang-combined-pval-underflowed-matched-component.R` ("Zhang combined p-value does not drop an underflowed matched-pairs p-value and the exact CI stays finite"), currently skipped; remove the skip when fixed.
- [ ] TODO-401 (added 2026-11-22, coordinator, owner request; numerical-robustness-c12c91fd6454): **The ZOIB marginal mean difference under bootstrap weights is wrong even with unit weights.**
  On HEAD, the unit-weight estimate differs from the unweighted ML estimate by 0.029, against a tolerance of 0.005. `compute_estimate_with_bootstrap_weights()` (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R` ~L272) fits two independent binary logits for P(0) and P(1), then feeds them to `zoib_marginal_mean_diff_from_coefs()`, which expects softmax logits.
  Fix: fit the zero/one parts as one weighted multinomial logit with the interior as reference (or as a weighted `fast_zero_one_inflated_beta` fit). Related: v1.1.0-TODO-197.
  Test: `R/package_tests/testthat_bulk/test-zoib-marginal-weighted-unit-weights-match-ml-estimate.R` ("ZOIB marginal mean diff under unit bootstrap weights matches the unweighted ML estimate"), currently skipped; remove the skip when fixed.

### Process and save-format questions from the audit free-text sweep, 2026-11-22 (TODO-402..403)

Found by the 2026-11-22 sweep of every audit report for items written outside the structured findings.

- [ ] TODO-402 (added 2026-11-22, coordinator, owner request; audit free-text sweep, test-suite-health run 44358374710
  `mechanical.json` and numerical-robustness PRs #51/#64/#71): **Audit-written bug tests that are skipped without a
  TODO never reach any issue.** The numerical-robustness audit merges a failing test for each bug it finds behind
  `skip("open a release TODO for this")`, and audit-notes marks the finding `fixed`/`proposed`; test-suite-health
  reports these skips only as `unconditional-skip` in its own `mechanical.json`, which `audit_decisions.py` does not
  read. 17 such tests sat untracked until v1.0.6-TODO-385..401 (2026-11-22).
  - Owner decision pending: [DECISION-v1.0.6-TODO-402](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-402) (how should
    skipped audit tests without a TODO be surfaced?).

- [ ] TODO-403 (added 2026-11-22, coordinator, owner request; audit free-text sweep, docs-scenarios run 44883784401,
  save-load "could not do"): **A saved design or inference object carries its own method code.** R6 objects
  serialize their method closures, so `readRDS()` of a design saved under an older EDI keeps running the old code
  under a newer installed EDI, silently. `?Design` and the reproducibility vignette say nothing about it.
  - Owner decision pending: [DECISION-v1.0.6-TODO-403](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-403) (what should
    happen when an object saved under another EDI version is loaded?).

- [x] TODO-405 (added 2026-11-22, coordinator, owner request; found by the v1.0.6-TODO-404 doc agent, confirmed by
  reading): **`compute_rand_two_sided_pval(type = "Zhang")` silently ignores `type` when assertions are off.** In
  `InferenceRandCI$compute_rand_two_sided_pval()` (`R/EDI/R/inference_all_abstract_rand_ci.R` ~L104-116) the `type`
  dispatch to `compute_exact_two_sided_pval_rand()` sits inside an `if (should_run_asserts())` block, together with the
  `transform_responses` guard. With assertions off (e.g. `SimulationFramework`'s `turn_off_asserts_for_speed`, or
  `set_asserts(FALSE)`), the call falls through and returns the randomization-draw p-value instead of the requested
  Zhang exact p-value, with no message. Fix: move the dispatch (and the guard's `stop()`, which is behaviour, not an
  assertion) out of the `should_run_asserts()` block; grep the other rand/CI entry points for the same pattern. Test:
  with assertions off, `type = "Zhang"` returns the same p-value as with assertions on, on an incidence Bernoulli
  design.
  Done 2026-11-24 (code in cf4b5a29, which picked up this session's staged edit): in `InferenceRandCI$compute_rand_two_sided_pval()` the transform refusal, the `type` dispatch and `assert_no_incidence_only_randomization_args()` (whose own `should_run_asserts()` gate is removed, so the randomization-CI call at ~L371 is always enforced too) run whatever the assertion setting; the same in `inference_mixin_kk_gee_shared.R` (plus its "Use Zhang method" refusal). Other entry points grepped: `inference_all_abstract_rand.R` ~L1321 has a gated incidence-delta stop that the always-on entry guard already covers; no other `type` dispatch is gated. Before / after on the incidence Bernoulli case (n = 40, `InferenceIncidLogRegr`): Zhang p asserts on 0.527254, off 0.42 (the draw p) -> 0.527254; a continuous class with `type = "Zhang"` and assertions off: ignored -> "only supported for incidence". The (1 + b)/(1 + B) draw p-value from 160a0dcc is untouched (the Zhang path never uses draws). Test: `R/package_tests/testthat_bulk/test-rand-pval-type-dispatch-independent-of-assertions.R`; 88 Zhang / risk-difference / KK GEE / rand-CI / rand-p test files pass.

- [ ] TODO-406 (added 2026-11-22, coordinator, owner request; found by the v1.0.6-TODO-404 doc agent, from reading the
  code, not yet reproduced): **`DesignFixedBlockedCluster$set_m()` can store block ids that differ from the strata
  used to randomize.** Randomization draws always use `strata_cols`, while `set_m()` (inherited from
  `design_blocking_abstract.R` ~L76) only replaces what `get_block_ids()` reports; inference that reads
  `get_block_ids()` (blocked jackknife, block bootstrap, stratified tests) would then analyse different strata from
  the ones the allocation was drawn in. Fix: reproduce first; then either refuse `set_m()` on this class (or when the
  ids disagree with the strata) or make it re-derive the strata. Test: `set_m()` with ids that disagree with
  `strata_cols` errors (or the analysis strata equal the randomization strata).

- [ ] TODO-431 (added 2026-11-25, agent, owner request: "we can run this on the post push"): **Real-data crash corpus: a push-triggered CI job that runs every applicable inference class on every catalog trial and counts errors, non-convergence and NAs.**
  - Why. `comprehensive_tests.R` runs on a handful of real covariate matrices capped at `max_n_dataset = 148` rows, with simulated responses. Real trials hit failures those don't: separation, constant or near-constant columns, real missingness patterns, ties, tiny arms, unequal allocation, heavy censoring, cluster columns with singletons. The experimental catalog (`R/package_metadata/experimental_datasets.csv`, 271 trials, median n = 135) supplies them with their real outcomes. This finds crashes and silent NAs; it says nothing about calibration (that is v1.1.0-TODO-271).
  - What it runs. One case per (catalog row, outcome, inference class applicable to that outcome's response type), on the CRAN-hosted rows with Redistribution `yes` (223 rows; data installed from CRAN at the catalog's pinned versions, never committed or uploaded). Each case builds the matching design from the catalog's treatment column (the documented design where the catalog has one, e.g. `cgd` blocked on `center`, else DesignFixedBernoulli with `w_precomputed` = the trial's real assignment, a cluster design where a cluster column exists), adds the covariates and the real outcome, and calls `compute_estimate()`, `compute_asymp_two_sided_pval()`, `compute_asymp_confidence_interval()` and, with a small seeded r / B, one randomization p-value and one bootstrap CI. Trials with more than two arms use the catalog's treatment-vs-control coding; multi-factor DOE rows (`solder`, `savings`) are skipped with a reason.
  - What it records. Per case and call: ok / error (message) / warning (message) / NA or non-finite / non-estimable (EDI's own refusal, which is expected and counted separately from a crash) / wall time. Output: a CSV artifact plus a step summary table by class and by dataset.
  - Gate. A committed baseline `R/package_tests/ci/real_data_crash_corpus_baseline.csv` lists each case's expected status. The job fails on a new error, a new NA where the baseline had a value, or a case that times out (per-case limit, e.g. 60 s, so one hanging fit cannot stall the job); a case that improves is reported, and the baseline is refreshed by a script, the same pattern as the drift artifacts. Each baseline error or NA row cites an open TODO (release-prefixed), like an accepted calibration row; triaging the first run's errors into TODOs is part of this TODO.
  - Placement. A new push-triggered workflow (`real-data-crash-corpus.yml`), like `rpy-parity-push.yml` / `code-duplication-push.yml`: `on: push` to main with a path filter on `R/EDI/R/**`, `R/EDI/src/**`, the catalog CSV and the job's own scripts, plus `workflow_dispatch`. Not a required check. It installs EDI once (cached like the other push workflows) and the catalog's CRAN packages from a cached library (about 124 packages, so the cache matters), then runs the cases sharded by response type in a few jobs, keeping within the 20-concurrent-job budget it shares with push CI and the calibration waves (4 slots kept free).
  - Step 1. Write the case runner as a script usable locally (`Rscript R/package_tests/real_data_crash_corpus.R [--datasets ...] [--classes ...]`), run it once in full, and record here: case count, total and per-response-type wall time, and the error / NA / non-estimable counts by class. If the full run is too slow for every push, report to the owner the options (a smaller per-push subset with the full corpus at release time, or path-filtered shards) before wiring the workflow.
  - Done when: the workflow runs on push and on dispatch, the baseline is committed with every error / NA row citing a TODO, `R/package_tests/ci/README.md` documents the job and how to refresh the baseline, and a deliberately broken class (local check) makes the job fail.

- [ ] TODO-432 (added 2026-11-25, agent, owner request: "make this a weekly run that only runs if any Design code changes"): **Design balance on real covariates: a weekly job that replays real trials' patients through every design and reports how well each balances their covariates.**
  - What it is. A benchmark, not validation: there is no right answer to check, and nothing fails on a worse number. For each catalog trial, keep its covariate matrix in row order (or enrollment order where the data carry one, e.g. `cgd$random`), discard its outcome and its assignment, and assign the subjects with each design: the fixed designs on the whole matrix, the sequential designs one subject at a time in that order, as in the README's "Sequential experimental data example → Real data" (Pocock-Simon on `medicaldata::strep_tb`). Repeat over seeded draws per design. It complements the calibration study's balance statistics (`R/package_tests/calibration/calibration_study_balance.R`, `balance_calibration_study.R`), which measure balance on the campaign's simulated covariates; this measures it on real covariate distributions (skew, ties, factors with rare levels, missingness, correlated columns).
  - Metrics. Reuse `calibration_study_balance.R`'s statistics where they apply, so the two reports are comparable: standardized mean difference per covariate (max and mean over covariates), Mahalanobis imbalance, margin imbalance of each factor level, treated-share deviation from the design's target, plus each design's wall time. Report per design the median and spread over trials and draws, and the trial's own allocation as a reference row where the catalog has its assignment.
  - Data. The CRAN-hosted catalog rows with Redistribution `yes` (as in v1.0.6-TODO-431; data installed from CRAN at the pinned versions, never committed or uploaded). Rows far larger than a shard's budget are subsampled to n = 50, 200 and 1000, matching the calibration grid, with the subsample redrawn per draw. Designs that need settings (strata columns, block sizes, matching parameters) use the catalog's documented strata or cluster column where there is one and the design's defaults otherwise; record which.
  - Schedule. New workflow `design-balance-real-data.yml`: `on: schedule` weekly plus `workflow_dispatch` (with a `force` input). A first job decides whether to run: it runs only if a significant change (`scripts/significant_changes.py`, so comment- and whitespace-only edits do not count) touched Design code since the last successful run of this workflow (`R/EDI/R/design_*.R`, the design kernels in `R/EDI/src/` they call, e.g. `atkinson_assign.cpp`, `binary_match_search.cpp`, and the job's own scripts). Fails open like nightly.yml's `change-gate` (no earlier run, a force-pushed base or an API error means run). List the design kernels explicitly in the workflow, with a check that every `.cpp` reached from a `design_*.R` file is in the list (the `rpy-parity-push.yml` path list has a test of this kind).
  - Output. A report published like the nightly benchmark (a page under the GitHub Pages site, e.g. `benchmarks/design-balance/`, via the same pkgdown-artifact swap as `bench-pages`) plus the CSV of every (trial, design, draw) result as an artifact; the README's benchmark line links it once it has published.
  - Step 1. Write the runner as a script usable locally (`Rscript R/benchmark/design_balance_real_data.R [--datasets ...] [--designs ...] [--draws N]`), run it on a few trials (`cgd`, `lalonde.exp`, `STAR`, `indo_rct`) and record here the runtime per design and the full corpus estimate, so the workflow's sharding and draw count can be set.
  - Done when: the workflow skips a week with no Design change, runs on one with a change (or on `force`), publishes the report and CSV, and the benchmark section of `CONTRIBUTING.md` documents it.

## Drafted from calibration campaign 2026-11-15-e36c7710 (review)

Drafted by `R/package_tests/calibration/triage_calibration_study.R` from the campaign's `summary/triage.csv`: one TODO per failing class x procedure x metric. Review each: edit, merge or delete it, and move kept ones into the implementation list.

- [ ] TODO-250 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedPoisson`'s `rand` fails its null size gate; small n only: passes at the largest n.** 25 failing cell(s) (0 confirmed, 25 awaiting confirmation (campaign still running when drafted)) on 13 design(s): SeqOneByOne:KK14, Fixed:Bernoulli@0.2, Fixed:Blocking@0.2, Fixed:Greedy@0.2, Fixed:GreedyDOptimal@0.2, Fixed:iBCRD@0.2, Fixed:OptimalBlocks@0.2, Fixed:Rerandomization@0.2, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:iBCRD@0.2, SeqOneByOne:RandomBlockSize@0.2, SeqOneByOne:SPBR@0.2, Fixed:OptimalBlocks; formulas ~., ~1; failing at n = 50, 200 (tested at n = 50, 200, 1000); effects null. Worst cell: Fixed:Greedy@0.2, ~1, n = 50, null: size 0.185 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignFixedGreedy@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedPoisson/rand/size -->
- [ ] TODO-251 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedNegBin`'s `rand` fails its null size gate; persistent: fails at the largest n.** 95 failing cell(s) (8 confirmed, 87 awaiting confirmation (campaign still running when drafted)) on 31 design(s): Fixed:Bernoulli@0.2, Fixed:Bernoulli, Fixed:BinaryMatch, Fixed:Blocking, Fixed:Blocking@0.2, Fixed:Greedy, Fixed:Greedy@0.2, Fixed:GreedyDOptimal, Fixed:GreedyDOptimal@0.2, Fixed:iBCRD, Fixed:iBCRD@0.2, Fixed:OptimalBlocks, Fixed:OptimalBlocks@0.2, Fixed:Rerandomization, Fixed:Rerandomization@0.2, SeqOneByOne:Atkinson, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:Bernoulli, SeqOneByOne:Efron, SeqOneByOne:iBCRD, SeqOneByOne:KK21, SeqOneByOne:KK21stepwise, SeqOneByOne:RandomBlockSize@0.2, SeqOneByOne:RandomBlockSize, SeqOneByOne:SPBR, SeqOneByOne:SPBR@0.2, SeqOneByOne:Urn, Fixed:MatchingGreedyPairSwitching, SeqOneByOne:iBCRD@0.2, SeqOneByOne:PocockSimon, SeqOneByOne:KK14; formulas ~., ~1; failing at n = 50, 200, 1000 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:RandomBlockSize@0.2, ~., n = 50, null: size 0.109 vs level 0.05 (964 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneRandomBlockSize@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedNegBin --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedNegBin/rand/size -->
- [ ] TODO-252 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountRobustPoisson`'s `rand` fails its null size gate; persistent: fails at the largest n.** 2 failing cell(s) (0 confirmed, 2 awaiting confirmation (campaign still running when drafted)) on 2 design(s): SeqOneByOne:Atkinson, SeqOneByOne:Bernoulli@0.2; formulas ~1; failing at n = 200, 1000 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Bernoulli@0.2, ~1, n = 1000, null: size 0.076 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneBernoulli@prob_T=0.2' --n 1000 --effect null --only InferenceCountRobustPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountRobustPoisson/rand/size -->
- [ ] TODO-253 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountQuasiPoisson`'s `rand` fails its null size gate; small n only: passes at the largest n.** 1 failing cell(s) (0 confirmed, 1 awaiting confirmation (campaign still running when drafted)) on 1 design(s): SeqOneByOne:Atkinson; formulas ~1; failing at n = 200 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Atkinson, ~1, n = 200, null: size 0.075 vs level 0.05 (1000 replicates). A finite-sample procedure should hold its level at every n, so this is most likely a bug. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneAtkinson' --n 200 --effect null --only InferenceCountQuasiPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountQuasiPoisson/rand/size -->
- [ ] TODO-254 (added 2026-11-19, owner; from docs-claims audit finding `docs-claims-d1f53ee72`; CHANGES RESULTS):
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
- [ ] TODO-255 (added 2026-11-19, owner; from docs-claims audit finding `docs-claims-dfa95cecb`): **KK g-computation
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
    - v1.0.6-TODO-260 (KK g-comp RD/RR): also an all-treated `DesignFixedBinaryMatch` design gives a finite
      estimate instead of non-estimable (`shared()` must check `w` variation / a missing treatment column); skip at
      `R/package_tests/testthat_bulk/test-rand-bootstrap-and-kk-gcomp-fallback-branches-reference.R:179`.
    - v1.0.6-TODO-259 (`InferenceIncidWald` empty arm, `compute_incidence_wald_components()`); skip at
      `test-incid-wald-welch-ttest-dispatch-reference.R:118`.
    - v1.0.6-TODO-262 (`InferenceCountPoisson` weighted refit with non-finite beta_T); skip at
      `test-count-poisson-deferred-fit-weighted-refit-and-estimand-switch.R:100`.
    - v1.0.6-TODO-264 (`InferencePropBetaRegr` failed weighted refit, `inference_proportion_beta.R` ~L328); skip at
      `test-prop-beta-regr-deferred-fit-boundary-responses-and-weighted-refit.R:77`.
    - v1.0.6-TODO-265 (`InferencePropFractionalLogit` failed weighted refit, ~L216); skip at
      `test-fractional-logit-weighted-coefficient-reference.R:92`.
    The details of each stay in its own entry below. Done when all six are fixed and every skip() is gone.
- [ ] TODO-256 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d38c37c85`): **`InferenceOrdinalPartialProportionalOddsRegr` docs misdescribe the last-resort bootstrap surrogate.**
  The roxygen of `compute_estimate_with_bootstrap_weights` (`R/EDI/R/inference_ordinal_partial_proportional_odds.R:97-101`) says that when every weighted backend fails the fallback is "a plain weighted binary-logistic surrogate fit ... that does not model the ordinal structure at all". `weighted_ordinal_bootstrap_surrogate_fit(method = "logistic")` (`R/EDI/R/globals.R:177-251`) actually fits a weighted `MASS::polr` proportional-odds model (`fit_type` "polr_logistic") and falls back to `lm.wfit`. The value returned is right; only the description is wrong.
  - Failing expectation: `expect_false(startsWith(sur$fit_type, "polr"))`, skipped at `R/package_tests/testthat_bulk/test-partial-odds-backend-fallback-reference.R:145`.
  - Candidate fix (doc): say "weighted proportional-odds (polr) surrogate, falling back to weighted least squares", and change the test expectation to match.
  - Done when: fix it and remove the skip().
- [ ] TODO-257 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d7b766030`): **`InferenceOrdinalStereotypeLogitRegr` gives the wrong non-estimable reason when every covariate is dropped.**
  The docs (`R/EDI/R/inference_ordinal_stereotype_logit.R:872-874`) say a treatment-only fit (`~1` or all covariates dropped) is non-estimable with reason `stereotype_treatment_only_fit_not_identified`. `~1` does give it. With `~ xdup` (an exact copy of treatment, n = 120, 4 categories), 6 of 8 seeds give `stereotype_treatment_only_fit_at_loading_boundary`. In `generate_mod()` (about lines 584-624) the `length(attempt$fit$b) <= 1L` check only runs when the hardened refit returns a usable fit. When the treatment-only refit is rejected at a loading boundary, `attempt$fit` is NULL and the boundary reason wins.
  - Failing expectation: `expect_identical(...$cached_values$nonestimable_reason, "stereotype_treatment_only_fit_not_identified")`, skipped at `R/package_tests/testthat_bulk/test-stereotype-logit-null-refit-history-independence.R:97`.
  - Candidate fix (code): when K >= 3 and the column-dropping ladder ends at treatment only, report `stereotype_treatment_only_fit_not_identified` whatever the boundary rejection says. Alternative (doc): name both reasons.
  - Done when: fix it and remove the skip().
- [ ] TODO-258 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-da2b1f69e`): **`InferenceOrdinalRidit`'s public bootstrap ignores `max_resample_attempts`.**
  The constructor docs (`R/EDI/R/inference_ordinal_ridit.R:106-109`) say a draw that loses an arm is redrawn up to `max_resample_attempts` times and is NA only after all attempts fail. Only the private `compute_fast_bootstrap_distr(B, n, y, dead, w)` (lines 299-330) uses the setting, and nothing on the public non-KK path calls it. The only caller is `inference_mixin_kk_passthrough.R:101`, with a different signature. With n = 10, 1 treated subject, B = 40 and seed 1, `approximate_bootstrap_distribution_beta_hat_T()` returns the identical vector with 14/40 NA for both `max_resample_attempts = 1L` and `50L`. That is about the no-redraw rate 0.9^10 ≈ 0.35.
  - Failing expectation: `expect_identical(sum(is.na(b50)), 0L)`, skipped at `R/package_tests/testthat_bulk/test-ordinal-ridit-unweighted-scores-wald-and-fast-kernels-reference.R:179`.
  - Candidate fix (code): wire the redraw loop into the public non-KK bootstrap path, or delete the dead kernel and the parameter. Alternative (doc): say failed draws are NA and the parameter is unused.
  - Done when: fix it and remove the skip().
- [ ] TODO-259 (merged into v1.0.6-TODO-255 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d7661f482`): **`InferenceIncidWald` returns NA for an empty arm but never flags it non-estimable.**
  The docs (`R/EDI/R/inference_incid_wald.R:15`) say the class is non-estimable if either arm has zero subjects. With every subject treated, or every subject control, `compute_estimate()`, the CI and the p-value are NA as expected. But `is_nonestimable("estimate")` is FALSE and `get_nonestimable_reason()` is NULL. The cause is that `compute_incidence_wald_components()` (about lines 127-130) only sets `incidence_wald_se = NA` and never calls `cache_nonestimable_estimate()`.
  - Failing expectation: `expect_true(inf$is_nonestimable("estimate"))`, skipped at `R/package_tests/testthat_bulk/test-incid-wald-welch-ttest-dispatch-reference.R:118`.
  - Candidate fix (code): in the empty-arm branch, call `private$cache_nonestimable_estimate("incidence_wald_empty_arm")`. Alternative (doc): say "returns NA" rather than "non-estimable".
  - Done when: fix it and remove the skip().
- [ ] TODO-260 (merged into v1.0.6-TODO-255 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-dcb561000`): **KK g-computation incidence classes do not flag a failed fit or a missing treatment arm as non-estimable.**
  The docs of `InferenceIncidKKGCompRiskDiff` (`R/EDI/R/inference_incidence_KK_marginal.R:313-316`) say a working model that fails to converge, or a design with no treatment-arm variation, marks the estimate non-estimable via `is_nonestimable()`. `InferenceIncidKKGCompRiskRatio` makes the same promise at `:417`. Two things go wrong for both classes:
  - Failed fit: with `fit_logistic_with_sandwich` injected to return NULL, the estimate is NA but `is_nonestimable("estimate")` is FALSE and the reason is NULL. `set_failed_fit_cache()` (`R/EDI/R/inference_incidence_KK_gcomp_abstract.R:338`, called at :551) writes NA effects and never calls `cache_nonestimable_estimate()`.
  - All subjects treated (`DesignFixedBinaryMatch`, n = 20, seed 3): the estimate is finite (RD -0.163, RR 0.658) and not flagged. The design matrix has no treatment column, but the class still standardizes over the remaining columns.
  - Failing expectations: `expect_true(inf$is_nonestimable("estimate"))`, `expect_false(is.null(inf$get_nonestimable_reason()))`, and `expect_true(is.na(est))` for the all-treated design. One skip at `R/package_tests/testthat_bulk/test-rand-bootstrap-and-kk-gcomp-fallback-branches-reference.R:179` covers the whole block.
  - Candidate fix (code): `set_failed_fit_cache()` calls `private$cache_nonestimable_estimate(<reason>)`, and `shared()` marks the estimate non-estimable when `w` has no variation or the treatment column is missing from the fit.
  - Done when: fix it and remove the skip().
- [ ] TODO-261 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d3906c9d4`): **`InferenceSuite` fills `ci_method` even when `compute_conf_intervals = FALSE`.**
  The `compute_conf_intervals` param doc (`R/EDI/R/inference_suite.R:4956`) says ci_a, ci_b and ci_method "stay present but always NA in results_table". ci_a and ci_b are NA, but ci_method is "wald" or "rand" on every row. `run_all_inference_one_class()` back-fills it (`R/EDI/R/inference_suite.R:1843`, `if (is.na(row$ci_method)) row$ci_method = method`).
  - Failing expectation: `expect_true(all(is.na(tbl$ci_method)))`, skipped at `R/package_tests/testthat_bulk/test-run-all-inference-build-display-table-sorting-column-selection-and-ci-method-column-dropping-reference.R:89`.
  - Candidate fix: code (skip the back-fill when `compute_conf_intervals = FALSE`), or doc (say ci_method keeps the method label while ci_a and ci_b are NA).
  - Done when: fix it and remove the skip().
- [ ] TODO-262 (merged into v1.0.6-TODO-255 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-dccc6a08a`): **`InferenceCountPoisson` weighted refit with a non-finite treatment coefficient is not cached as non-estimable.**
  The method docs of `compute_estimate_with_bootstrap_weights` (`R/EDI/R/inference_count_poisson.R:456`) say a hardened weighted fit with a non-finite treatment coefficient "is cached as nonestimable and returns NA". With `fast_poisson_regression_weighted_cpp` mocked to return `b[2] = NA`, the estimate and `last_weighted_refit$s_beta_hat_T` are NA, but `last_weighted_refit$nonestimable` is FALSE and no reason is recorded. The code (about lines 461-512) sets the values to NA and never calls `cache_nonestimable_estimate()`.
  - Failing expectation: `expect_true(f$p$last_weighted_refit$nonestimable)`, skipped at `R/package_tests/testthat_bulk/test-count-poisson-deferred-fit-weighted-refit-and-estimand-switch.R:100`.
  - Candidate fix (code): call `private$cache_nonestimable_estimate(<reason>)` on that path. Alternative (doc): say it returns NA with an NA SE.
  - Done when: fix it and remove the skip().
- [ ] TODO-263 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d78c189b0`): **`InferenceOrdinalKKGLMM(use_rcpp = FALSE)` never fits: `glmmTMB::cumulative` does not exist.**
  The docs (`R/EDI/R/inference_ordinal_KK_combined.R:349`) say `use_rcpp = FALSE` fits via glmmTMB Laplace. `private$glmm_family()` (`:550`) calls `glmmTMB::cumulative(link = "logit")`, which the installed glmmTMB 1.1.14 does not export. Every fit prints "GLMM FIT ERROR: 'cumulative' is not an exported object from 'namespace:glmmTMB'", and the estimate is always NA. The documented `supports_likelihood_tests()` = FALSE part does hold.
  - Failing expectation: `expect_true(is.finite(est))`, skipped at `R/package_tests/testthat_bulk/test-ordinal-kk-glmm-deferred-fit-wald-likelihood-tests-and-polish.R:106`.
  - Candidate fix (code): fit the `use_rcpp = FALSE` path with `ordinal::clmm`, as the weighted helper already does. Alternative (doc): say the path is unavailable, and refuse `use_rcpp = FALSE` at construction.
  - Done when: fix it and remove the skip().
- [ ] TODO-264 (merged into v1.0.6-TODO-255 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d3a8c4d21`): **`InferencePropBetaRegr` weighted refit that fails is not cached as non-estimable.**
  The docs (`R/EDI/R/inference_proportion_beta.R:246-252`) say a hardened but still unreasonable weighted fit "is cached as nonestimable". With `fast_beta_regression_weighted_cpp` returning NaN coefficients and `stats::lm.wfit` failing, the refit returns NA, but `weighted_refit_is_nonestimable()` is FALSE and `last_weighted_refit$nonestimable_reason` is NULL. The failure branch (`:328-333`) only writes NA to `cached_values`, and `fit_ok` checks only finiteness, so there is no unreasonable-fit check at all.
  - Failing expectation: `expect_true(p$weighted_refit_is_nonestimable())`, skipped at `R/package_tests/testthat_bulk/test-prop-beta-regr-deferred-fit-boundary-responses-and-weighted-refit.R:77`.
  - Candidate fix (code): call `private$cache_nonestimable_estimate("weighted_refit_failed")` in that branch. Alternative (doc): say NA is returned and nothing is marked.
  - Done when: fix it and remove the skip().
- [ ] TODO-265 (merged into v1.0.6-TODO-255 on 2026-11-20; fix it there. Added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d412caeef`): **`InferencePropFractionalLogit` weighted refit that fails is not cached as non-estimable.**
  The docs (`R/EDI/R/inference_proportion_fractional_logit.R:180`) make the same promise as v1.0.6-TODO-264. With `fast_logistic_regression_weighted_cpp` mocked to return a NaN treatment coefficient, the refit returns NA for both `harden = FALSE` and `harden = TRUE`, but `weighted_refit_is_nonestimable()` is FALSE and the reason is NULL. The branch at `:216-220` never caches non-estimable.
  - Failing expectation: `expect_true(all(flagged))`, skipped at `R/package_tests/testthat_bulk/test-fractional-logit-weighted-coefficient-reference.R:92`.
  - Candidate fix (code): the same one-line fix as v1.0.6-TODO-264. Alternative (doc).
  - Done when: fix it and remove the skip().
- [ ] TODO-266 (added 2026-11-19, found by the docs-claims test agent; finding `docs-claims-d55fb24f7`): **`InferencePropGCompMeanDiff` public bootstrap ignores its screening arguments.**
  The docs (`R/EDI/R/inference_proportion_gcomp.R:261`, wrappers at `:268` and `:300`) say the screening arguments of `compute_bootstrap_two_sided_pval()` and `compute_bootstrap_confidence_interval()` reach the bootstrap-sample screen and are restored afterwards. The wrappers set `private$bootstrap_screening_control`, but the generic (`inference_all_abstract_non_param_boot.R:769` for the p-value, `:978` for the CI) calls `approximate_bootstrap_distribution_beta_hat_T(B, show_progress)`. That method overwrites the control with its own defaults (`inference_proportion_gcomp.R:353-359`). With n = 40 (20 per arm) and `min_group_n = n`, no resample can pass, yet the CI is finite, (0.111, 0.174), and the p-value is 0.105. Calling `approximate_bootstrap_distribution_beta_hat_T(min_group_n = n)` directly gives all-NA replicates, as expected. The restore part works.
  - Failing expectations: `expect_true(all(is.na(ci)))` and `expect_true(is.na(pval))`, skipped at `R/package_tests/testthat_bulk/test-proportion-gcomp-bootstrap-sample-screening-contract.R:109`.
  - Candidate fix (code): give `approximate_bootstrap_distribution_beta_hat_T`'s screening args a NULL default and override the control only when they are supplied, or have the wrappers pass them through.
  - Done when: fix it and remove the skip().
- [x] TODO-267 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-221 agent): **`InferenceIncidBinomialIdentityRiskDiff`
  returns half the MLE on one fixture draw.** On draw 27 of the v1.0.6-TODO-205 fixture the class gives 0.0833 while
  the MLE is 0.1666, after the kernel reports converged = FALSE. Check whether a covariate drop or a fallback path
  produces this value, and whether a non-converged fit should return NA with a recorded reason instead.
  DONE 2026-11-20 (agent, uncommitted; PATCHED, needs owner build). Cause: not a wrong face or a start; Fisher
  scoring crawls toward an interior MLE with a y = 1 row at mu = 0.99956 (working weight ~2300 vs observed curvature
  ~1), so the cold fit needs 2817 iterations at tol 1e-12 and hit maxit = 100 (converged = FALSE); the class's
  hardened refit then dropped x1 (`edi_covariate_dropped_warning`) and returned the unadjusted 0.0833. The covariate
  drop is the documented fallback, so non-converged fits keep it (no NA). Fix (`fast_log_binomial_regression.cpp`,
  both impls, all four kernels): from iteration `kObservedNewtonStartIter` = 20, a fit with no row held on a bound
  steps with the observed-information Newton increment when its full step stays strictly inside the mean support,
  else keeps the Fisher step; convergence checks unchanged. Draw 27: converged in 23 iterations at the MLE 0.1666128.
  Rejected on the sweep: always taking the Newton step (181 fits ended lower, up to 0.06 in log-likelihood) and taking
  it while rows were held (wrong face, 3 converged fits turned converged = FALSE). Kernel-swap sweep (4 kernels x 20
  fixtures x 40 draws x 3 starts: cold, warm beta, warm beta + Fisher; 9,600 calls): 8,063 `identical()`; 1,377
  changed but converged both ways, all within 1e-8 or better in log-likelihood (max gain 4e-3); 109 newly converged;
  0 newly failed, 0 worse; no fit converging within 20 iterations changed. Test
  `test-identity-binomial-slow-fisher-scoring-interior-mle-reaches-mle.R` (12 pass swapped; 9 failures on the installed
  kernel); 33 related kernel / class test files pass swapped (806 expectations). Downstream: stored resampling rows of
  `InferenceIncidBinomialIdentityRiskDiff` / `InferenceIncidLogBinomial` can move; fold into v1.0.6-TODO-209 item (4)'s
  regeneration.
- [ ] TODO-268 (added 2026-11-20, agent; found fixing the bulk CI run 44616748908): **`InferenceContinRobustRegr`
  with `use_rcpp = FALSE` and the default `method = "MM"` returns a silent NA on an exact fit.** On a noise-free
  y = 3 + 2w (n = 40, one covariate x1 unrelated to y) `MASS::rlm(method = "MM")` errors ("incompatible dimensions",
  from its S-estimate start), `fit_rlm_model()` returns NULL, and `set_failed_fit_cache()`
  (`inference_continuous_robust_regr.R` ~L265) caches NA for the estimate with no nonestimable reason and no warning.
  `method = "M"` and the Rcpp backend both give 2 and `model_standard_error_unavailable` (the SE floor). Fix: record a
  nonestimable reason (and the usual warning) when every fit attempt fails, or fall back to an M start. The bulk test
  `test-continuous-robust-regr-se-floor-nonestimable-guard-reference.R` uses `method = "M"` for the rlm backend until
  then.
- [x] TODO-269 (added 2026-11-20, coordinator; owner decision on v1.0.6-TODO-230, "yes, later"): **User-settable usable-draw
  cap on the generic ratio subsampling / m-out-of-n paths.** v1.0.6-TODO-230 fixed the 0.8 cap for
  `InferenceIncidLogRegr`, `InferenceIncidKKGEE`, `InferenceIncidModifiedPoisson`, `InferenceIncidLogBinomial` and
  `InferenceCountPoisson` as the constant `ratio_resampling_min_fraction_usable`. Expose it as
  `min_fraction_usable_samples` on the generic subsampling / m-out-of-n public methods (in
  `inference_all_abstract_non_param_boot.R`), as the g-comp RR methods already do, and document it there.
  DONE 2026-11-20 (agent, uncommitted; R only): the four public methods (`compute_subsampling_two_sided_pval`,
  `compute_subsampling_confidence_interval`, `compute_m_out_of_n_bootstrap_two_sided_pval`,
  `compute_m_out_of_n_bootstrap_confidence_interval`) take `min_fraction_usable_samples = 0.8`, validated with
  `assert_min_fraction_usable_samples()` and threaded through the `_impl`s and
  `resampling_centered_pivot_for_inference()` to the centered pivots. The cap check moved after the pivot cache (the
  pivot stores `n_draws` / `n_degenerate`), so a pivot built under one cap is judged under the cap of each call
  (before, a failing pivot was not cached, so the fixed cap needed no care). For a class with a degenerate-draw rule
  the cap replaces the fixed 50% "high_replicate_failure_rate" gate (redundant at 0.8; a cap below 0.5 now works);
  classes without a rule ignore the argument and keep the 50% gate. Default results unchanged. Docs: `@param` on the
  four methods, the four unused `nonparamboot-subsampling-*` / `nonparamboot-m-out-of-n-*` templates, and the
  "Subsampling and m-out-of-n" sections of LogRegr, ModifiedPoisson, LogBinomial, CountPoisson and the KK combined
  (KKGEE) class (Rd not regenerated). Contracts: 380 rows in `checkmate_argument_contracts.csv` and 1520 in
  `public_argument_contract_registry.csv` (95 classes x 4 methods; the g-comp classes already had theirs), taken from
  a scratch regeneration, only the new rows merged in. No new private methods. Test
  `test-ratio-subsampling-m-out-of-n-min-fraction-usable-samples-argument.R` (114 pass: formals, validation, default
  = explicit 0.8, NA below / value above the cap, cap < 0.5, cached pivot re-judged, OLS ignores it).
- [ ] TODO-270 (added 2026-11-20, coordinator; from the v1.1.0-TODO-218 verification): **Permuted-block jackknife with
  few units per stratum is oversized.** Since 72ea20ba (v1.0.6-TODO-231 (3)) `DesignSeqOneByOneRandomBlockSize`
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
  [0.032, 0.059]); CI coverage 0.966, so slightly conservative, not broken. Note: with the v1.0.6-TODO-231 (6) t
  reference already in, the permuted-block size on the RBS cell is 0.060, not the 0.082 measured before it.
  NOT ticked: the RBS cell is nominal, but the SPBR cell stays at ~0.062 (this change does not reach it, since SPBR has
  8-9 blocks per stratum).
  - Owner decision pending: [DECISION-v1.0.6-TODO-270](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-270) (SPBR at 0.062: accept, raise the threshold, or investigate SPBR separately?).

- [ ] TODO-283 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-188 agent; needs a wheel rebuild): **Python
  `fast_beta_regression` returns `neg_loglik = nan`.** Same pattern as v1.0.6-TODO-188: the binding reads
  `ModelResult.neg_ll`, which `R/EDI/src/fast_beta_regression.cpp` never sets (R computes `$neg_loglik` separately).
  `python/tests/test_fast_beta_regression.py` documents it as "not a binding bug"; fix the binding (or set `neg_ll` in
  the kernel), pin the value against R, and drop that note.

- [x] TODO-284 (added 2026-11-20, done 2026-11-20; ds-python-kernels-44358267779-f1): **`import edi_kernels` died with
  SIGILL on an AVX2-only CPU.** Cause: `python/CMakeLists.txt` defaulted `EDI_PY_PORTABLE` to OFF (`-march=native
  -mtune=native`) and `python/pyproject.toml` pinned OFF for every non-cibuildwheel build, so a plain `pip wheel
  ./python`, `pip install .` and every sdist install (piwheels too) targeted the build host. The docs-scenarios
  `build-wheel` job built that way on one ubuntu-latest runner and the `scenario` job imported the wheel on another (AMD
  EPYC 7763, no AVX-512). Even `PyInit__core` is vectorized under `-march=native` (45 ymm instructions in a local native
  build), so the crash comes at import, not at a kernel call. The PyPI wheels (cibuildwheel, `EDI_PY_PORTABLE=ON`) were
  never affected: the 1.0.2 cp312 manylinux `_core` has 0 zmm and 0 ymm instructions, so no `.postN` re-release is
  needed. Fix: portable is the default (no `-march`, the compiler's x86-64/SSE2 baseline), mirroring
  `R/EDI/configure`'s `EDI_PORTABLE=1`; native is opt-in with `-DEDI_PY_PORTABLE=OFF` or `EDI_PORTABLE=0`, and
  cibuildwheel still pins ON. Guard: `.github/scripts/check_wheel_isa.py` disassembles the extension with `objdump` and
  fails on any AVX/AVX2/FMA/BMI or AVX-512 instruction (`--allow-avx2` rejects only AVX-512); unit tests in
  `.github/scripts/test_check_wheel_isa.py`. Wired into `build-wheels.yml` (Linux x86-64 wheels, after cibuildwheel) and
  the docs-scenarios `build-wheel` job. CPU baseline stated in `python/README.md` and `README_PYPI.md`; changelog in
  `python/CHANGELOG.md`. Local `build/<wheel tag>/` dirs cache the old OFF value: delete them before rebuilding.
- [x] TODO-285 (added 2026-11-20; nightly run 44715037976, benchmark (procedures) canary): **The Zhang exact CI's
  convex-hull scan costs about 2x the v1.0.4 CI.** The v1.0.6-TODO-233 hull (scan of the p-value breakpoints plus a
  200-point grid past the bisection endpoint) made the n = 1000 Bernoulli benchmark row 8.6x slower (1.71 -> 14.87 ms
  on CI). Partly fixed 2026-11-20, same endpoints (720 random Bernoulli/KK CIs x 3 combination methods x 2 alphas
  bit-identical; 917 Zhang test expectations pass): `zhang_pval_exact_combined_vec()` no longer uses
  `apply`/`sweep`, and the scan stops at `zhang_hull_scan_cut()`, where a monotone upper bound on the combined p-value
  (`zhang_pval_exact_tail_bound()`: log-concave components, so past the mode p <= tail x (1 + K - x)) is already below
  alpha; the points kept are the old scan's own points. Locally 40 -> 16 ms vs 7.9 ms before the hull. Still over the
  canary's 1.25x, so the row is in `R/benchmark/benchmark_regression_allowlist.csv` citing this TODO. Left: the scan's
  `exp` over a K x (breakpoints + grid) matrix (K = 326 outcomes, ~93 points) and 62 -> ~24 bound evaluations; a C++
  vectorised minimum-likelihood kernel (needs a targeted compile) or scanning only the breakpoints when one component
  is present (the p-value is quasi-convex between breakpoints then) would bring it near 1x. Remove the allowlist row
  when fixed, and in any case at the v1.0.6 release, when the canary's baseline includes the hull.
  C++ kernels added 2026-11-21 (agent, uncommitted; no build: tested by `sourceCpp` of `zhang_exact_speedups.cpp`
  into `$TMPDIR` plus a namespace assign, `RcppExports.*` regenerated with `compileAttributes`; **the installed EDI
  needs a rebuild to pick up the new exports**, and the parallel CI path's workers use the installed package).
  `zhang_minlike_pval_vec_cpp()` (one component's minimum-likelihood p-value at a vector of deltas, O(K) per delta,
  long double sums as in `colSums()`, so bit-identical to the R matrix; past the mode it stops once the remaining
  terms cannot change either long double sum, which is exact by log-concavity) replaces the matrix in
  `zhang_pval_exact_combined_vec()`, whose combination is now `zhang_combine_exact_pvals_vec()`;
  `zhang_pval_exact_tail_bound_cpp()` / `zhang_hull_scan_cut_cpp()` do the tail bound and the whole cut bisection
  in one call each (same arithmetic as the R versions, R's `pchisq`/`qnorm`/`pnorm`). A product R rounds on its own
  goes through a volatile on FMA targets (`__FP_FAST_FMA`, e.g. -march=native), else the compiler fuses it and the
  bits differ (seen: 1714 of 3000 vectors off by ~1e-15 before that). R side: the components are built once per
  CI; `t_far` skips its scalar evaluation when the bound there already rejects; the scan finds the farthest
  accepted point and the next one out without `order()`; `zhang_exact_pval_breakpoints()` uses a quicksort (values
  distinct) and the grid uses `seq.default()`'s own formula (`zhang_seq_length_out()`, identical on 50,000 random
  cases); and the endpoint snap (`zhang_snap_endpoint()`) takes its accept/reject decisions from the vector p-value
  through `zhang_accepts_certified()`, calling the scalar kernels only where |p_vec - alpha| is within a rigorous
  bound on the vector-vs-scalar difference (`zhang_pval_exact_vec_rel_err()`, floor 1e-6 relative; observed
  differences below 2e-10). At n = 1000 Bernoulli both endpoints sit on a breakpoint, so that saves 4 of 63 scalar
  evaluations (59 now, as before the hull). Endpoints: `cmp.R` (720 random Bernoulli/KK CIs x 3 methods x 2 alphas
  vs the 72ea20ba hull) 0 diffs, all 720 bit-identical; kernels vs the replaced R code bit-identical on 3000 vectors,
  60,000 single bounds, 52,488 combined bounds and 8748 cuts, with and without FMA (`-mno-fma`). Tests: all 22
  Zhang test files pass under `load_all(compile = FALSE)` + the sourced kernels (0 failures; the 2 skips are the
  files' own `skip()`); new `testthat_bulk/test-zhang-minlike-pval-vector-kernel-and-tail-bound-kernels.R`
  (bit-identity vs the replaced R code, agreement with the scalar kernels, the rel_err bound, certified decisions,
  bound validity/monotonicity, the vector combination); the TODO-233 test still compares the vector p-value with the
  scalar kernels (now `as.vector()`, as the result carries `rel_err`). Timing, n = 1000 Bernoulli Fisher CI, all
  versions byte-compiled, 100 interleaved rounds on a loaded machine (load ~9): pre-hull a54a263f 7.95 ms median,
  hull before this (R matrix + R cut) 15.4 ms (1.94x), now 9.6 ms (1.21x by medians, 1.26x median per-round ratio;
  earlier runs 1.19-1.29x). So at about the canary's 1.25x but not clearly under it: left open and the allowlist row
  kept. What is left is mostly the hull's own work (two scan kernel calls over 93 points x 326 outcomes, ~7% of the
  CI; R glue ~10%). Further options: skip outcomes far below the mode with a certified error bound and an exact
  fallback near alpha (not bit-identical, ~2%), or a scan restricted to breakpoints when one component is present.

  - Decided 2026-11-21 (owner): 1.2-1.3x is close enough, no further speedups; see [DECISION-v1.0.6-TODO-285](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-285).
  DONE 2026-11-21. The benchmark allowlist row stays, since the row sits at about the canary's 1.25x and would fail
  intermittently; remove it at the v1.0.6 release, when the canary baseline includes the hull.
- [x] TODO-286 (added 2026-11-20, done 2026-11-20; ds-custom-statistic-44358267779-f1, ds-custom-statistic-44358267779-f5, ds-custom-statistic-44358267779-f6):
  **`InferenceRandCustom` nonzero-delta nulls mixed scales.** Its fast path `compute_fast_randomization_distr()`
  re-added the null shift to every draw as `y + delta * w`, but `y` arrives with delta removed on the
  `transform_responses` scale (`setup_randomization_template_and_shifts()`; `compute_rand_two_sided_pval()` maps
  `"none"` to logit for proportion and log for count and survival). So on survival, count and proportion responses,
  and with `"log"`/`"logit"` on continuous ones, each draw combined a log/logit removal with an additive re-add and
  the reference distribution matched no sharp null (proportion draws left [0, 1]). Separately, the survival
  randomization CI passed log times to the user's statistic under an additive shift (`is_glm` is FALSE for this
  class), so it was not the inversion of the class's own p-value and a raw-time statistic such as `survreg` failed.
  Fix: the fast path re-applies delta with `shift_randomization_responses()` (the base-class helper; the two
  duplicated inline copies in `compute_fast_randomization_distr_via_reused_worker()` now call it too, pure
  refactor); a private hook `randomization_ci_shifts_raw_survival_times()` makes the survival CI use the `"log"`
  shift of raw times, and the delta-scale search seed is the mean log-time difference there. Before/after with a
  custom statistic equal to a built-in's (n = 60, r = 20 shared draws, delta = 0.3): max |draw difference| vs
  `InferenceSurvivalWeibullRegr` 0.142 -> 3e-5 (survreg tolerance), vs `InferenceCountPoisson` 0.206 -> 4e-11, vs
  `InferencePropFractionalLogit` error -> 1e-11; count p-value 0.020 vs built-in 0.040 -> equal; survival CI error
  (survreg on log times) -> [-0.5422, 0.4387] vs built-in [-0.5419, 0.4389]. Continuous `"none"` unchanged.
  Tests: `R/package_tests/testthat_bulk/test-rand-custom-null-shift-scale-by-response-type.R` (commit 6166f9b5). Docs: the
  `InferenceRandCustom` roxygen (Rd not regenerated) and the custom-statistic article now state the shift scale per
  response type instead of the f6d20e4d "not valid" warning. Not fixed, same additive pattern in C++-kernel fast
  paths: `InferenceAllSimpleMeanDiff` (`compute_simple_mean_diff_parallel_cpp`, ignores `transform_responses`) and
  `InferenceAllSimpleWilcox` (`transform_code = 0L` hard-coded) on survival/count/proportion at nonzero delta.

- [ ] TODO-321 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-215 agent): **Cumulative-link ordinal warm start
  is overwritten.** In the four cumulative-link classes (PropOdds, OrderedProbit, Cauchit, Cloglog),
  `standard_model_cache_shared()` replaces the full warm start that `generate_mod()` just stored with
  `b = c(0, beta_T)` and no information matrix, so later refits (bootstrap, randomization, CI inversion) never get a
  full-length warm start. Check whether this costs iterations or changes any refit's optimum, and keep the full start.

- [ ] TODO-322 (added 2026-11-20, coordinator; found by the v1.0.6-TODO-169/170 agent): **ZINB with a large-scale
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

- [ ] TODO-325 (added 2026-11-21, agent, owner request; found by the issue #66 review): **`R CMD check` hangs in
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

- [x] TODO-327 (added 2026-11-21, agent, owner request; audit decision `code-duplication-d4062d188`, issue #61 triage):
  **`set_testing_type("lik_ratio_bartlett_*")` makes `compute_asymp_*()` return NULL on `InferenceContinKKOLSOneLik`
  and `InferenceCountPoisson`.** Both switch on `testing_type` with no Bartlett branches and no `stop()` default
  (`R/EDI/R/inference_continuous_KK_ols_one_lik.R:132-141,160-169`, `R/EDI/R/inference_count_poisson.R:267-273,286-292`),
  although `get_supported_testing_types()` lists the Bartlett types; the CI and p-value are silently `NULL` (verified
  at runtime). Fix: add the Bartlett branches dispatching to the `*_impl` (as `..._loggamma.R:664-665` does) and a
  `stop("Unsupported testing_type")` default. Test: for every exported class and every supported testing type, the
  asymptotic CI is a length-2 numeric and the p-value a length-1 numeric.
  - **Done 2026-11-21 (agent):** Bartlett branches plus a `stop()` default added to the asymp CI and p-value switches in
    `inference_continuous_KK_ols_one_lik.R` and `inference_count_poisson.R`. The sweep found the same gap in
    `InferenceCountKKCondPoissonOneLik` and `InferenceCountKKHurdlePoissonOneLik` (NULL) and `InferenceCountKKGLMM`
    ("Unsupported testing_type"), now fixed too. The new loop test also found that `InferenceIncidExtendedRobins`'s asymp
    CI and p-value returned NA with no reason on a fresh object (never computed `beta_hat_T`); fixed. Test:
    `R/package_tests/testthat_bulk/test-asymp-ci-and-pval-defined-for-every-supported-testing-type.R` (every class x
    supported type, Bartlett factor stubbed, ~32 s, 1232 passed).
    - **Owner decision 2026-11-21: (a).** `lik_ratio_bartlett_approx` stays the model-only Bartlett-corrected LR test;
      documented in the class roxygen (`R/EDI/R/inference_count_KK_cond_poisson.R`, the OneLik doc and the shared
      design-conservative paragraph). A separate, opt-in design-conservative Bartlett option is v1.0.6-TODO-380.
- [x] TODO-328 (added 2026-11-21, agent, owner request; audit decision `code-duplication-ddad98657`, issue #61 triage):
  **`compute_rand_two_sided_pval(alternative = ...)` errors ("unused argument") on 7 classes whose override lacks the
  argument.** The base method gained `alternative` in 3dabce47 and NEWS announces it, but the overrides in
  `R/EDI/R/inference_mixin_kk_gee_shared.R:125` (the 4 KK GEE classes), `inference_survival_dep_cens_transform.R:121`,
  `inference_incidence_KK_cond_logit.R:715` and `inference_survival_weibull.R:241` don't take it (verified at runtime).
  Fix: add `alternative = "two.sided"` with `match.arg` and pass it through to the sequential Monte Carlo and t0s
  helpers, or have the override delegate its tail to the base method (see v1.0.6-TODO-193). Test: every exported
  class's `compute_rand_two_sided_pval` has an `alternative` formal, plus one `alternative = "greater"` call per
  override.
  - **Done 2026-11-21 (agent):** `alternative = "two.sided"` with `match.arg` added to the overrides in the KK GEE mixin
    (passed to the sequential Monte Carlo and t0s helpers; not delegated to the base, whose seeding and incidence rules
    differ), KK cond-logit OneLik and Weibull (passed to the base method they already call) and the DepCens stub (still
    NA). A runtime formals check on every exported class found no other override missing it. Two-sided p-values match
    HEAD to 17 digits on fixed seeds. Test: `R/EDI/tests/testthat/test-rand-pval-alternative-accepted-by-every-override.R`
    (243 passed). Follow-up filed as v1.0.6-TODO-373.
- [ ] TODO-329 (added 2026-11-21, agent, owner request; audit decision `code-duplication-db5595975`; low priority):
  **The unweighted log- and identity-binomial kernels ignore `warm_start_weights`.** `fit_constrained_binomial_cpp_impl`
  (`R/EDI/src/fast_log_binomial_regression.cpp:520-810`) never reads the argument and doesn't check its length; the
  weighted implementation uses it (L857-873) and the roxygen promises "initial working weights". Fitted values don't
  change and no R class passes it. Fix: port the weighted path's iteration-0 block and length check, or document the
  argument as unused and add the length check. Test: a wrong-length vector errors. [C++]
- [ ] TODO-330 (added 2026-11-21, agent, owner request; mechanical findings `rd-m2fa7c1c1`, `rd-m362b49ad`,
  `rd-m3ca40610`, `rd-m6949d76a`, `rd-m77d445ee`, `rd-m7f2798f2`, `rd-m8e01cb35`, `rd-m8e01cb35-2`, `rd-m9706d359`,
  `rd-ma957805a`, `rd-maa4ffcbb`, `rd-maa4ffcbb-2`, `rd-mafc40b7d`, `rd-meda604bf`, `rd-mff4a0118`): **The
  `InferenceCountZeroInflatedPoisson`, `...ZeroInflatedNegBin`, `...HurdlePoisson`, `...HurdleNegBin` and
  `InferenceIncidGCompRiskRatio` examples emit separation or boundary warnings**, also on the published reference
  pages. Choose n, data or a seed so the zero / hurdle part isn't separated on any of the rd audit's 5 seeds, keeping
  each example under 4 s. Done when the rd audit's example check is clean for these classes.
- [x] TODO-331 (added 2026-11-21, agent, owner request; audit decision `rd-d3554783c`): **Test that
  `fast_beta_regression_with_var()` passes `warm_start_fisher_info` to the C++ fitter.** The fix itself is 0e29876e
  (2026-11-19), which had no test. Added `R/EDI/tests/testthat/test-beta-regression-warm-start-fisher-info-reaches-backend.R`:
  the matrix reaches the backend unchanged (mocked), a wrong-size matrix is rejected by the C++ size check, and a warm
  start matches the cold fit. Shown to fail on the pre-fix wrapper. A parse scan of all 92 R functions with a
  `warm_start_*` argument found none that ignores it.
- [x] TODO-332 (added 2026-11-21, agent, owner request; audit decision `rd-d4d634228`): **The
  `InferenceIncidBinomialIdentityRiskDiff` example warned** (`edi_binomial_mle_boundary_warning` on 3 of 30 seeds). It
  now uses `set.seed(1)`, n = 100, a binary covariate and true risks in [0.3, 0.6], and also shows the asymptotic CI
  (roxygen in 8d8c5f78; the Rd example block hand-synced, `checkRd` clean). 0 of 50 seeds warn; about 0.1 s per run.
- [x] TODO-333 (added 2026-11-21, agent, owner request; audit decisions `rpy-parity-d1f65c8c0`, `rpy-parity-d62675f61`,
  `rpy-parity-dd699435e`): **Python bindings return less than their R exports.** Code done, not yet verified:
  (1) `fast_zero_one_inflated_beta` takes `estimate_only` (default `False`) and returns R's fields (`b`, `log_phi`,
  `zero_one_b0`, `zero_one_b1`, `vcov`, the information matrices, `hessian`, `min_eigenvalue_information`); (2)
  `fast_robust_regression` returns `min_eigenvalue_information` and, unless `estimate_only`, `ssq_b_j` and
  `fisher_information`; (3) `fast_clogit_plus_glmm`'s `weights_disc` / `weights_conc` (already in the binding since
  21e0679a) are now in `_core.pyi` and `_checks.py`. Both sides call new shared helpers in `R/EDI/src`
  (`fast_zero_one_inflated_beta_result_internal`, `fast_robust_regression_ssq_b_j_internal`; C++ in 8d8c5f78); R
  output should be unchanged. Done when, after the owner's rebuild, the 5 new pytest cases pass and the R ZOIB and
  robust-regression tests still pass.
  - **Verified 2026-11-23 (agent) on the owner's builds:** with today's Python extension
    (`python/build/cp314-cp314-linux_x86_64/`, loaded from a `$TMPDIR` copy because the venv's editable install still
    points at the 2026-11-20 one) the 6 binding test files pass, 650 passed, including the 5 new cases. On today's R build
    the 40 ZOIB / zero-one-inflated / robust-regression test files in both trees pass (830, 0 failed). The venv needs
    reinstalling to pick up the new extension.
- [ ] TODO-334 (added 2026-11-21, agent, owner request; audit decision `docs-claims-d70b0515c`, claim 2): **Test
  `InferenceRandCustom`'s parallel-path contract.** The docs (`R/EDI/R/inference_rand_custom.R:84-86`) say a C++
  source string works on parallel paths while an external pointer or pre-compiled Rcpp function is valid in the main
  process only. No test checks either half, and both worker-count invariance helpers skip this class. Test: with a
  source-string statistic, `compute_rand_two_sided_pval()` under `set.seed()` is identical for `num_cores = 1` and
  `2`; with an external pointer or pre-compiled function, pin whatever the parallel path does (clear error or
  main-process fallback), and fix the docs if it differs. Test only.
- [x] TODO-335 (added 2026-11-21, agent, owner request; found by the v1.0.6-TODO-181 agent): **The inference registry's
  `required_packages` is empty for every class** (`R/EDI/R/inference_class_registry.R:3958`), so
  `missing_required_packages_for_inference_class()` returns nothing and `InferenceSuite` never excludes a class whose
  Suggests package is missing (`R/EDI/R/inference_suite.R:94`). Fill it from the classes' own package guards (as
  `likelihood_concave` is filled from a constant), add a drift test against the guards, and make the v1.0.6-TODO-181
  test helper read it.
  - **Done 2026-11-21 (agent; source in 83e092b7):** `EDI_INFERENCE_REQUIRED_PACKAGES` in `inference_class_registry.R`
    fills the field for 10 classes (quantreg: the 6 quantile classes; multgee + geepack: `InferenceOrdinalKKGEE`;
    aftgee: `InferenceSurvivalKKRankRegrIVWC`; nbpMatching: `InferenceBaiAdjustedTKK14` / `KK21`), confirmed by running
    every exported class with all Suggests stats packages removed. Packages needed only on non-default paths are in
    `EDI_INFERENCE_OPTIONAL_PATH_PACKAGES`. `missing_required_packages_for_inference_class()` now uses
    `check_package_installed()`, so `InferenceSuite` excludes these classes and lists them under
    `unavailable_due_to_missing_packages`. Drift test: `tests/testthat/test-inference-required-packages-registry.R`
    (guard-text scan plus a mocked-absent construct-and-fit check); the v1.0.6-TODO-181 helper now reads the registry.
    Side effect: `classes =` / `exclude_classes =` naming such a class now errors "unknown/inapplicable class(es)".
    Open follow-up: `InferenceOrdinalKKGEE` fits with multgee only and needs geepack just because of the shared guard.
- [x] TODO-336 (added 2026-11-21, agent, owner request; found by the v1.0.6-TODO-181 agent): **`InferenceOrdinalKKGEE`'s
  missing-geepack error mentions `use_rcpp=FALSE`**, but the class hard-codes it (`R/EDI/R/inference_ordinal_KK_combined.R:87`)
  and has no such argument; the message comes from the shared mixin guard (`R/EDI/R/inference_mixin_kk_gee_shared.R:287`).
  Mention `use_rcpp` only for classes that expose it.
  - **Done 2026-11-21 (agent; source in 83e092b7):** the guard adds " when use_rcpp=FALSE" only when the constructor has
    `use_rcpp`; the error class is unchanged. Both message forms are tested in
    `R/package_tests/testthat_bulk/test-kk-gee-geepack-package-required-guard-reference.R`.
- [x] TODO-337 (added 2026-11-21, agent, owner request): **The docs-scenarios audit stayed green when the API refused
  its agents.** `docs_scenarios.py collect` now reads the refusal reason from each transcript with the shared
  `.github/scripts/agent_failure.py` (copied into each area kit); `report` puts "N of M scenario agent(s) did not run"
  with the API reason at the top of the report, PR body and findings file; and the publish job of
  `audit-docs-scenarios.yml` fails in its last step, after the partial results are saved. Areas that didn't run stay
  due. Tests: `DocsScenarios` in `.github/scripts/test_agent_failure.py` (560 `.github/scripts` tests pass; actionlint clean).

### Docs-scenario findings, run 44883784401, 2026-11-21 (TODO-338..372)

The docs-scenario audit (run 44883784401, merged as PR #78) followed the inference-suite, save-load,
simulation-framework, observational, incidence, count, ordinal and proportion articles and help pages against installed
1.0.4. Findings and repros: `R/package_metadata/audits/docs_scenario_findings/2026-11-21-run44883784401.md`; "Repro:
<area> F<k>" below names the block in that file. Each was re-checked on HEAD (779dc92c..6ed95ff3) on 2026-11-21 by
reading the code, most also by a small repro under `load_all(compile = FALSE)`. Findings an existing entry covers are
cited there: observational f1 (v1.0.6-TODO-298), incidence f7 (v1.0.6-TODO-303). Fixed or invalid ones are in
`R/package_metadata/audits/DISMISSED_DECISIONS.md` (observational f5-f8, fixed in ba1c3988; incidence f4, fixed in
ca01dd4b under v1.0.6-TODO-306; proportion f8, by design).

- [ ] TODO-338 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`max_secs_per_class` at
  1 core and the inherited `set_num_cores()` cluster in forked suite workers.**
  Ids: ds-inference-suite-44883784401-f3, ds-inference-suite-44883784401-f11, ds-observational-44883784401-f3.
  (1) At 1 core the suite uses `setTimeLimit(elapsed =, transient = TRUE)` (`R/EDI/R/inference_suite.R:1692-1693`):
  a limit that fires inside a per-draw `tryCatch` is swallowed, so a 69 s ZINB is reported `ok` at a 2 s limit, and
  one that fires in native code halts Rscript past every handler. b9a3519e (v1.0.6-TODO-292) fixed only the fork
  path; its "found, not changed" note recorded this. (2) After `set_num_cores(2)`, forked children inherit the
  socket cluster; `configured_worker_fn` in `run_all_inference_fork_dispatch()` (`inference_suite.R:~1535`) resets
  only the thread env vars, so a child's randomization p-value fails with "ignoring SIGPIPE signal" while the row
  stays `ok`, and later direct calls in the parent fail too. Fix: when `max_secs_per_class` is set, run every task
  through the fork dispatcher with kill-by-PID, also at 1 core; in a child, drop the inherited cluster handle without
  closing the parent's sockets and run inner work serially; a failed p-value never leaves status `ok`. Done when:
  the inference-suite F3 repro returns timeout rows and never reaches an outer `tryCatch`, and the F11 and
  observational F3 repros give the same p-values as at 1 core with a working direct call afterwards.

- [ ] TODO-339 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Suite rows for skipped,
  refused or misspelled procedure types look like successes.**
  Ids: ds-inference-suite-44883784401-f1, ds-inference-suite-44883784401-f4, ds-inference-suite-44883784401-f7.
  With `compute_conf_intervals = FALSE`, CI-only bootstrap types (`basic`, `calibrated`, ...) still get rows with
  `pval = NA`, method columns filled, `status = "ok"`, no message: `inference_suite.R:1022` (and the CI twin ~L925)
  returns `method = entry$label` instead of NA, and `:1846-1847` back-fills both method columns (v1.0.6-TODO-261 is
  the `ci_method` half of this; fix both together and remove that TODO's skip). A misspelled type
  (`bootstrap = "percentil"`) passes `intersect()` at `:542` as zero types, builds a `type = NA` task (`:1255-1258`)
  and runs the default flavour, `ok`. A refused rand CI (QuasiPoisson/RobustPoisson lose `randomization_ci` on count,
  registry `:208-225`) returns `method = NA` at `:900`, back-filled to "rand", no message. Fix: don't build tasks for
  a side that is turned off; error in `run_all_inference()` on a type outside the known vocabularies, listing them
  (as for sentinels, ~L5116); put the refusal reason in `message` for a capability the class refuses here. Done
  when: the three repros give no row or an NA-method row with a message, and a typo errors naming the valid types.

- [ ] TODO-340 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Count estimand tags and the
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

- [ ] TODO-341 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Suite print and Combined
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

- [ ] TODO-342 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **The suite drops a valid
  exact p-value and CI when only the estimate is non-estimable, and keeps separated fits at full weight.**
  Ids: ds-incidence-44883784401-f9.
  `inference_suite.R:1759-1771` sets the row to "nonest" on any `is_nonestimable("any")`, discarding
  `InferenceIncidExactFisher`'s exact p (6.26e-05) and CI on zero-cell data (its `nonestimable_stage` is
  "estimate"), while GComp RR (p = 0, CI 2.7e-10 to 7.6e-10) with its own separation warning stays `ok` at full
  weight. Fix: keep the p/CI cells a class still returns when only the estimate stage is non-estimable; treat rows
  that raised a separation/boundary warning as the owner decides (below). Done when: on the incidence F9
  repro the Fisher row carries its p and CI and the separated rows do not enter the combination at full weight.
  - Owner decision pending: [DECISION-v1.0.6-TODO-342](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-342) (down-weight or exclude suite rows that raised a separation / boundary warning?).

- [ ] TODO-343 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **User-facing help names
  unexported objects and internal developer files.**
  Ids: ds-inference-suite-44883784401-f10, ds-observational-44883784401-f4.
  `?InferenceSuite` sends users to the unexported `EDI_INFERENCE_SUITE_METHOD_SENTINELS`,
  `is_inference_class_compatible_with_design_metadata()`, `infer_inference_requires_blocking_design()` and
  `inference_class_registry.R` (`inference_suite.R:4432,4451,4790`). Roxygen on the observational path cites
  `fix_design_hierarchy.md`, internal TODOs and `draw_ws_raw()`: `design_observational.R:84-88`,
  `design_abstract.R:660-662,768,796`, `design_fixed_binary_match.R:54`, `design_fixed_greedy.R:79`,
  `design_fixed_greedy_d_optimal.R:159`, `design_class_registry.R:4`, `design_component_registry.R:3`,
  `design_class_factory.R:4`. Fix: list the sentinels inline (or export a getter), rewrite the `#'` lines to stand
  alone and keep internal pointers in `#` comments. This extends v1.0.6-TODO-311 (which covers message strings) to
  roxygen. Done when: a source test fails on any `#'` line naming `package_metadata`, an internal `.md` or
  `TODO-<n>`, and `man/InferenceSuite.Rd` names no unexported identifier.
  2026-11-22 (coordinator): the vignette part is done in commit 2bc1e336 (v1.0.6-TODO-404): a grep of
  `vignettes/` and `vignettes/articles/` for `ROADMAP.md`, `R/package_metadata/` and `release_v` found two links to
  unshipped repo files, `cookbook-count.Rmd` (`ROADMAP.md`) and `extending-edi.Rmd`
  (`R/package_metadata/contracts/new_model_creation.md`); both now link to the GitHub copies. The roxygen part
  stays open.

- [ ] TODO-344 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`InferenceCountRobustPoisson`
  returns a named estimate and p-value (`"treatment"`).**
  Ids: ds-inference-suite-44883784401-f12.
  `R/EDI/R/inference_all_abstract_count_likelihood.R:138` keeps the name of RobustPoisson's named `b_full`
  (`inference_count_robust_poisson.R:249`); every other count class returns unnamed numbers. Fix: `as.numeric(...)[1L]`
  as in `inference_all_abstract_asymp_lik_std_mod_cache.R:264`, same on the p-value path. Done when: a test over
  all count classes asserts `is.null(names())` on the estimate, CI and p-value.

- [x] TODO-345 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **A shared warm start makes
  results depend on call order (NegBin score p) or freezes randomization refits at a separated fit (Poisson family).**
  Ids: ds-inference-suite-44883784401-f13, ds-count-44883784401-f7.
  (1) `InferenceCountNegBin`'s score-test null fit starts from the mutable backend warm start
  (`R/EDI/R/inference_count_negbin.R:384-390`), which the score-CI search updates (`:297`): score p 0.1027268 on a
  fresh object, 0.1025635 after the CI. (2) When every control count is 0, Poisson, QuasiPoisson and RobustPoisson
  rand refits warm-start from the separated full fit (`inference_count_poisson.R:748-757`) and stay there: all 49
  draws equal the observed 22.79, p = 1 for every alternative, no warning. Fix: start the NegBin null fit from a fixed
  point; drop a warm start on a separation boundary and cold-start (the v1.0.6-TODO-30 pattern for ZIP), and return
  NA with a warning when all draws are degenerate. Done when: the score p is `identical()` with and without a prior
  CI, and the count F7 repro gives p near 2/(r+1) (or NA with a warning) for all three classes.
  Done 2026-11-24: (1) `InferenceCountNegBin`'s likelihood-test `fit_null()` has no `start` formal and always starts from the full-data MLE (`cached_mod` params and Fisher information), so the memoized wrapper cannot chain starts across deltas; score p fresh 0.8837140183 vs after a score CI 0.8837135948 (before) -> 0.8837140183 both, `identical()` (after). (2) A hook `warm_start_on_separation_boundary()` in `Inference$set_fit_warm_start()` (default FALSE) lets Poisson / QuasiPoisson / RobustPoisson refuse to store a start with any coefficient beyond +-15 (`edi_poisson_warm_start_on_boundary()`, `inference_count_poisson.R`); the all-control-zero repro (n = 30, observed estimate 23.12, full fit b = -22.0 / +23.1) gives rand p = 0.04 = 2/(r + 1) at r = 49 for all three classes (RobustPoisson was NA with "0 of 49 finite draws" on HEAD once unconverged fits were rejected; the warm-started draws stopped after 1 iteration at the observed fit). Test: `R/package_tests/testthat_bulk/test-count-warm-start-call-order-and-separated-fit-independence.R`; 168 Poisson / NegBin / warm-start test files pass (only the pre-existing zero-augmented failures in `test-count-likelihood-families-focused.R`).

- [ ] TODO-346 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`get_summary()` SEs disagree
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

- [x] TODO-347 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Count model formulas:
  `offset()` is silently dropped, and `~ 1` for the zero/hurdle part is under-documented.**
  Ids: ds-count-44883784401-f1, ds-count-44883784401-f4.
  `offset(log_fu)` in `model_formula` is accepted, echoed by `get_model_formula()`, and dropped: Poisson, NegBin and
  ZIP fits equal the no-offset fits (`assertFormulaContext()`, `R/EDI/R/helper_additional_asserts.R:28-45`; the
  feature itself is v1.1.0-TODO-17a). `model_formula_zero = ~ 1` fits `~ w`: by design and now said for ZIP
  (add3f6cb, `inference_count_zero_inflated.R:200-206`), not yet for ZINB (`:496-497`) or HurdlePoisson/HurdleNegBin
  `model_formula_hurdle` (`inference_count_hurdle.R:148-149,427-428`). Fix: error when `attr(terms(f), "offset")` is
  non-NULL ("offsets are not supported yet"), outside the `should_run_asserts()` gate; copy the "treatment is always
  included" sentence to the other three pages. Done when: `~ offset(x) + ...` errors for every count class and all
  four Rd pages say what `~ 1` fits.
  Done 2026-11-24: `edi_refuse_formula_offset()` (`R/EDI/R/helper_additional_asserts.R`) errors on `attr(terms(f), "offset")`, outside the `should_run_asserts()` gate, from `Inference$initialize()` (`model_formula`, so every class), the zero-augmented abstract (`model_formula_zero`) and `InferenceCountHurdleNegBin` (`model_formula_hurdle`). Before: `InferenceCountPoisson` with `~ x1 + offset(log_fu)` gave 0.3535 = the no-offset fit (glm with the offset: 0.2548); after: "model_formula contains an offset() term; offsets are not supported yet". The "treatment is always included, so `~ 1` ..." sentence is in the ZINB `model_formula_zero` and both hurdle `model_formula_hurdle` roxygen (ZIP already had it); the Rd pages pick it up at the next roxygenize. Test: `R/package_tests/testthat_bulk/test-count-model-formula-offset-term-refused.R` (8 count classes, asserts off, zero/hurdle formulas); 17 formula bulk files pass.

- [ ] TODO-348 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Testing types are listed as
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

- [ ] TODO-349 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`capabilities()` /
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
  note the restriction in the KK table. Sibling of v1.0.6-TODO-303. Done when: on `ObservationalDesign*` `supports()`
  is FALSE for these and TRUE on Bernoulli, CMH is absent or NA-with-warning, and the KK14 error names the method
  and "DesignSeqOneByOneKK14".

- [x] TODO-350 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`clone(deep = TRUE)` of
  SPBR, RandomBlockSize and PocockSimon shares per-stratum state with the original.**
  Ids: ds-save-load-44883784401-f2.
  `private$strata_states = new.env()` (`design_seq_one_by_one_spbr.R:103,120-129`,
  `design_seq_one_by_one_random_block_size.R:125,147-165`) is not copied by R6 deep clone, and
  `pocock_simon_assign_and_update_cpp(private$counts, ...)` (`design_seq_one_by_one_pocock_simon.R:131-142`) updates a
  shared matrix in place; no design defines `deep_clone`. Reproduced on HEAD: after the clone the original differs
  from an uninterrupted run in 5/12/11 of 20 assignments. Fix: a private `deep_clone()` (once on `DesignSeqOneByOne`)
  that copies environments and `counts`, or have the C++ return the updated counts. Check the v1.0.6-TODO-316
  rollback snapshot, which keeps the same references. Done when: a test over every sequential class shows the copy
  and the original each match an uninterrupted run.
  Done 2026-11-24: SPBR / RandomBlockSize `strata_states` is a list (keys `"s:<stratum>"`, since a list element named `""` cannot be looked up), PocockSimon copies `counts` (`+ 0`) before `pocock_simon_assign_and_update_cpp()` updates it in place, and `Design` gained a private `deep_clone()` that `data.table::copy()`s data.table fields (PocockSimon preallocates `Xraw` and fills it with `data.table::set()`, so a clone fed different subjects had its covariate rows overwritten by the original: found while writing the test). Other designs hold no environments (only `design_class_registry.R` / `design_component_registry.R` package-level registries). The v1.0.6-TODO-316 rollback snapshot is fixed by the same change (list and fresh counts are copy-on-modify). Before (seeded, n = 24, clone at 12): copy differed from an uninterrupted run in 4 (PocockSimon), 4 (RandomBlockSize), 6 (SPBR) assignments; after: 0 for all 11 sequential classes, copy-first and original-first. Test: `R/package_tests/testthat_bulk/test-seq-design-deep-clone-does-not-share-assignment-state.R`; 48 sequential/clone/PocockSimon/SPBR/RBS test files pass (two tests updated for the list: `test-random-block-size-design-block-decomposition-balance-and-argument-validation-reference.R`, `test-sequential-design-branches.R`; `test-randomization-sequential-mc-pval-stopping-rule-reference.R` fails 3 expectations, pre-existing from the merged (1 + b)/(1 + B) p-value rule).

- [x] TODO-351 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Sequential designs accept
  subject n + 1, and a covariate arriving as text retypes the column for every earlier subject.**
  Ids: ds-save-load-44883784401-f3, ds-save-load-44883784401-f5.
  `add_one_subject_to_experiment_and_assign()` has no `t < n` guard when `fixed_sample` is set
  (`R/EDI/R/design_seq_one_by_one_abstract.R:79-89`; `private$w[private$t] = w_t` grows `w`, `:239-262`), and
  `check_experiment_completed()` tests only `t < n` (`design_abstract.R:545-553`): 31 adds on n = 30 give t = 31,
  `get_n()` 30, inference on 31. A text value for a numeric covariate warns once (`:153`) and retypes the stored
  column (`:142-161`); later assignments change and the final analysis is NA with no warning. Fix: error at the
  (n + 1)th add; on a type change either error or coerce back to the stored type and error if that gives NA (the
  v1.0.6-TODO-316 rollback then restores state); update the "Fix the covariate list" sentence in the sequential-trial
  article. Done when: the 31st add errors with t still 30 (Bernoulli, KK14, KK21), and the F3 repro errors at subject
  26 naming the column, with `get_t()` and `get_X_raw()` unchanged.
  Done 2026-11-24: `DesignSeqOneByOne$add_one_subject()` refuses a subject when `fixed_sample` and `t >= n` (always on), and a column whose type changed is coerced back to the stored type by `coerce_new_value_to_stored_type()` or refused, naming the column, when a non-missing value would become NA (always on; replaces the old warning). Before (Bernoulli / KK14 / KK21, n = 30): the 31st add was accepted (`t = 31`); after: "all n = 30 subjects have already been added; subject 31 cannot be enrolled", `t` stays 30. Text `"1.7a"` for numeric `x1` at subject 26: before, a warning and the column retyped to character; after, "covariate 'x1' of subject 26 is character (1.7a) but was entered as numeric ...", `get_t()` 25 and `get_X_raw()` identical; `"1.7"` is stored as 1.7 (numeric). The sequential-trial article's "Fix the covariate list" bullet (and "Set `n`") updated. Test: `R/package_tests/testthat_bulk/test-seq-design-refuses-extra-subject-and-covariate-type-change.R`; 106 sequential-design test files pass. Two tests that asserted the old warn-and-retype behaviour updated: `test-design-seq-one-by-one-covariate-data-type-change-warning-reference.R`, `test-sequential-evolving-schema-contracts.R`.

- [x] TODO-352 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Development builds still
  report version 1.0.4, so saved designs are stamped with a release whose seeding rule differs (owner decision).**
  Ids: ds-save-load-44883784401-f4.
  `R/EDI/DESCRIPTION:4` says 1.0.4 while NEWS.md has a development section, and the docs date the sequential seeding
  rule to v1.0.6 (`R/EDI/R/design_abstract.R:78`, `R/EDI/vignettes/reproducibility.Rmd:70`), so a trial file stamped
  "1.0.4" points to the wrong allocation rule. Related: v1.0.6-TODO-68. Fix (owner): give development builds a version
  above the last release (e.g. 1.0.5.9000), changed only in DESCRIPTION and then `python3 scripts/sync_version.py`.
  Done when: `get_edi_version_created()` on a development build never equals a released version, and
  `sync_version.py --check` passes.
  - **Owner decision 2026-11-21:** set the version to 1.0.5 (the next release to ship; release_v1_0_5.md is closed and
    soon to be released). Done: `R/EDI/DESCRIPTION` says 1.0.5 and `python3 scripts/sync_version.py` rewrote
    CITATION.cff, python/CITATION.cff, codemeta.json, python/pyproject.toml, python/README.md and
    python/README_PYPI.md; `--check` passes. Saved designs from this tree are stamped 1.0.5, not the released 1.0.4.

- [ ] TODO-353 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`SimulationFramework` docs:
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

- [x] TODO-354 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Serial `SimulationFramework`
  runs don't seed replication i with `seed + i`, so results depend on `num_cores` and a resumed run replays old data.**
  Ids: ds-simulation-framework-44883784401-f4, ds-simulation-framework-44883784401-f5.
  The serial loop (`R/EDI/R/simulations_framework.R:1881-1970`) seeds once (`:866`); the fork (`:1629,1674`) and
  mirai (`:1793-1795`) paths seed each replication. With `continue_from_last_result_row = TRUE` the skipped reps never
  advance the stream, so the "new" reps duplicate the first ones. This is the serial-path item of
  `optimal_design_finder.md TODO-4` (tracked by v3.0.0-TODO-15); pulled into v1.0.6 because the vignettes promise
  reproducibility across `num_cores`. Fix: `set.seed(seed + rep)` before each serial rep, as the parallel paths do.
  Done when: the F4 repro gives identical `get_results()` at 1 and 2 cores, and a serial 3-rep run resumed to 6
  equals a fresh 6-rep run row for row.
  Done 2026-11-24: the serial loop calls `set.seed(seed + rep)` at the start of each replication, as `fork_rep_worker_fn` does. Repro (continuous, iBCRD + Bernoulli, OLS, n = 20, 4 reps, seed 42): 1 vs 2 cores identical FALSE -> TRUE; 2 reps resumed to 4 vs fresh 4 FALSE -> TRUE; rep 3 a replay of rep 1 TRUE -> FALSE. Note: the mirai path seeds per (rep, cell), so on a grid with several cells mirai results still differ from fork / serial (pre-existing, not in this entry; the test uses one cell so it holds on every backend). Test: `R/package_tests/testthat_bulk/test-simulation-framework-serial-seeding-report-alpha-and-risk-diff-estimand.R`.

- [ ] TODO-355 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`SimulationFramework`
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

- [x] TODO-356 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`SimulationFrameworkReport$new(sim, alpha = a)` tests coverage of CIs built at the framework's alpha against
  `1 - a`.**
  Ids: ds-simulation-framework-44883784401-f9.
  `R/EDI/R/simulation_framework_report.R:249` (`alpha_override`) feeds `binom.test(..., p = 1 - alpha)` (`:140-145`),
  so `coverage_pval` flags correctly calibrated intervals. Fix: test coverage against the alpha the CIs were built at
  and use the override for power/size only (or warn when they differ), and say so in the `alpha` doc. Done when: a
  report with alpha = 0.2 on a 0.05 run gives the same `coverage_pval` as the default report.
  Done 2026-11-24: the report keeps `ci_alpha` (the framework's alpha; from a file, the given alpha) and uses it for `coverage_pval`; an `alpha` override changes power / size only, and the `alpha` roxygen says so. Repro (incidence, n = 200, 40 reps): `coverage_pval` with `alpha = 0.2` identical to the default report (TRUE). Test: `R/package_tests/testthat_bulk/test-simulation-framework-serial-seeding-report-alpha-and-risk-diff-estimand.R`.

- [x] TODO-357 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`SimulationFramework` scores
  `InferenceIncidGCompRiskDiff` against the logit-scale `betaT`.**
  Ids: ds-simulation-framework-44883784401-f10.
  The hand-kept `is_mean_diff` list (`R/EDI/R/simulations_framework.R:3231-3240`) has InferenceIncidKKGCompRiskDiff but
  not InferenceIncidGCompRiskDiff, so coverage is 0 and MSE is wrong. Fix: add it, check the other marginal-difference
  classes (e.g. BinomialIdentityRiskDiff), or replace the list by a registry flag. Done when: the F10 repro gives a
  G-comp true estimand equal to Newcombe's (~0.198) and coverage near 0.95, and a test checks every incidence
  risk-difference class.
  Done 2026-11-24: the hand-kept list is now `EDI_SIM_MEAN_DIFF_INFERENCE_CLASSES` + `edi_sim_inference_scores_mean_diff()` (`simulations_framework.R`), with `InferenceIncidGCompRiskDiff` and `InferenceIncidBinomialIdentityRiskDiff` added (the only `InferenceIncid*RiskDiff` classes missing). Repro (incidence, n = 200, 40 reps, betaT = 1): G-comp, Newcombe and BinomialIdentity true estimand all 0.1965 (G-comp was scored against 1); G-comp asymp CI coverage 1.0 (40/40). Test: `R/package_tests/testthat_bulk/test-simulation-framework-serial-seeding-report-alpha-and-risk-diff-estimand.R` (asserts every `InferenceIncid*RiskDiff` class is in the list).

- [ ] TODO-358 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`DesignFixedBinaryMatch`
  accepts a `w_precomputed` that does not treat exactly one member of each pair.**
  Ids: ds-observational-44883784401-f9.
  The override (`R/EDI/R/design_fixed_binary_match.R:176-179`) builds the pairs and delegates; ba1c3988's
  `validate_w_precomputed()` checks clusters but not pairs, so a within-pair randomization test runs on a pair with
  two treated and one with none. Fix: after the pairs exist, error naming the first offending pairs (the
  v1.0.6-TODO-301 cluster-check pattern); consider `ObservationalDesignMatching` too. Done when: the observational F9
  repro errors and a valid one-per-pair `w` is stored unchanged.

- [ ] TODO-359 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Blocking/BCa text in the
  existing-experiment article and `?DesignFixedBlocking` doesn't match the code.**
  Ids: ds-observational-44883784401-f10, ds-observational-44883784401-f11.
  With unequal strata and `equal_block_sizes = TRUE` the error comes at the first bootstrap/randomization call
  (blocks form lazily, `R/EDI/R/design_blocking_abstract.R:~290-325`), not "when subjects are added" (`@param`,
  `design_fixed_blocking.R:210-218`), "at `assign_w_to_all_subjects()`" (Details, L88-93) or "an inference fit"
  (`vignettes/articles/analyzing-an-existing-experiment.Rmd:350-353`). The same article (`:145-148`) says BCa is NA
  with 4 sites; since v1.0.6-TODO-4/-231 the jackknife unit is `observation_within_block` and BCa is finite. Fix:
  preferably check equal sizes eagerly at the end of `add_all_subjects_to_experiment()` when the blocks are fixed by
  then; otherwise make the three texts name the real step; rewrite the BCa sentence. Done when: the F10 repro errors
  at the documented step, and help, article and chunk output agree.

- [ ] TODO-360 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Rd pages: constructor
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

- [ ] TODO-361 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Flagged non-estimable fits
  return NA (or a 0 estimate) with no warning.**
  Ids: ds-incidence-44883784401-f2, ds-incidence-44883784401-f6, ds-ordinal-44883784401-f8.
  `InferenceIncidLogBinomial` with a zero-event arm returns all NA with reason `model_fit_unavailable`
  (`inference_all_abstract_asymp_lik_std_mod_cache.R:260`), no warning; the KK conditional-logit OneLik
  (`inference_incidence_KK_cond_logit.R:298`, `extreme_treatment_coefficient`) and GLMM
  (`inference_incidence_KK_cond_logit_glmm_abstract.R:335,616`) classes do the same on matched pairs with no treated
  events. With every patient in one category, `InferenceOrdinalRidit` returns 0 / NA / NA with `is_nonestimable()`
  FALSE (`inference_ordinal_ridit.R:259-290`, in v1.0.6-TODO-255's scope), and `InferenceOrdinalPropOddsRegr` is
  flagged but reports an estimate of 0. Fix: the v1.0.6-TODO-306 convention package-wide: one classed
  `edi_procedure_na_warning` per object (outside resampling) naming the reason, raised from the shared non-estimable
  path (`cache_nonestimable_estimate()`, `inference_all_abstract.R:~1003`), with advice (exact Fisher / risk
  difference for a zero arm); Ridit flags `ordinal_single_category`; cumulative-link classes return NA when y has
  < 2 levels. Done when: each repro warns once and returns NA with `is_nonestimable()` TRUE.

- [ ] TODO-362 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Separation not detected:
  ModifiedPoisson, KK IVWC / KKModifiedPoisson, cumulative-link ordinal, and LogRegr parametric-bootstrap replicates.**
  Ids: ds-incidence-44883784401-f3, ds-incidence-44883784401-f8, ds-ordinal-44883784401-f9.
  `InferenceIncidModifiedPoisson` on zero-cell data gives log RR -22.3, CI (-22.85, -21.80), p = 0 with no boundary
  warning (`inference_incidence_modified_poisson.R:320`; KKModifiedPoisson similar, and KK cond-logit IVWC in
  incidence F6 gives a CI of about +/-21 500, unflagged). `InferenceOrdinalPropOddsRegr` under quasi-complete
  separation gives -14.81, CI +/-400, no flag, and its LR CI is NA with no warning (the ticked
  v1.0.6-TODO-109/118/119/122 covered logit, probit and KK GEE only). `InferenceIncidLogRegr`'s parametric bootstrap
  keeps near-separated replicates (log OR ~ -25): the bias-corrected estimate flips -2.23 to +1.03, CI upper bound
  +21, `n_extreme = 0` (`inference_ext_param_bootstrap_estimate.R:52-62,120-133`, threshold 50). Fix: detect an arm
  with all-zero fitted means / fitted probabilities 0 or 1 (helpers `helper_robust_sandwich.R:~751`), raise the
  separation warning and `cache_nonestimable_se()`; count separated bootstrap refits in `n_extreme` via a per-class
  hook; make an NA LR CI warn or return a one-sided interval. Done when: the incidence F3/F6 and ordinal F9 repros
  warn with NA Wald p and CI, and the incidence F8 repro has `n_extreme > 0` with those replicates excluded.

- [ ] TODO-363 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferenceOrdinalPartialProportionalOddsRegr`: a t(n-1) reference for an ML fit, and unknown `nonparallel` names
  silently ignored.**
  Ids: ds-ordinal-44883784401-f1, ds-ordinal-44883784401-f2.
  `df = n - 1` (`R/EDI/R/inference_ordinal_partial_proportional_odds.R:280,343,347,357`) makes the CI and p differ
  from `InferenceOrdinalPropOddsRegr` on the same fit (p 3.67e-05 vs 1.38e-05) with no non-parallel covariates;
  `nonparallel` is validated only against "treatment" (`:96-102`) and `intersect()` (`:426,456`) drops a typo. Fix:
  normal reference (label `Pr(>|z|)`); error on names not among the covariates, listing them. Done when: with
  `nonparallel = character(0)` PPO's CI and p equal PO's to 1e-8, and `nonparallel = "base_pian"` errors.

- [ ] TODO-364 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Cumulative-link R6 classes
  stop short of the MLE, and the PPO breakdown benchmark refits and overwrites the cache.**
  Ids: ds-ordinal-44883784401-f3, ds-ordinal-44883784401-f5.
  PO, cloglog, probit and cauchit call the kernels with the lbfgs defaults (maxit 100, tol 1e-6) and don't forward
  `optimization_alg` (`R/EDI/R/inference_ordinal_proportional_odds.R:111-145`, `inference_ordinal_cauchit.R:65-158`;
  stop rule `src/fast_ordinal_regression.cpp:147-205`): estimates differ from `ordinal::clm` in the 3rd significant
  digit (cauchit -0.5246 vs -0.5283), so Wald CIs and p are off and `set_optimization_alg("newton_raphson")` does
  nothing. `benchmark_asymp_two_sided_pval_breakdown()` on PPO refits warm-started (`inference_ordinal_partial_proportional_odds.R:255-290,488-517`),
  returns a different estimate and leaves it in the cache. Related: v1.0.6-TODO-321. Fix: Newton-polish the lbfgs
  result (or tighten tol) and forward `optimization_alg`; make the breakdown time the cached path or refit cold
  without writing the cache. Done when: on the F5 trials all four links match clm to 1e-5, and the breakdown's
  estimate and p equal the public methods' with the cache unchanged. [C++]

- [ ] TODO-365 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Open-interval checks: a
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

- [ ] TODO-366 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`?InferenceOrdinalJonckheereTerpstraTest` misstates the exact-enumeration cap.**
  Ids: ds-ordinal-44883784401-f12.
  The help (`R/EDI/R/inference_ordinal_jonckheere_terpstra_test.R:15-17,104-107`) says exact enumeration stops at one
  million allocations with a warning; `kMaxJTExactLeaves = 1e6` (`src/fast_jonckheere_terpstra.cpp:19-38,211`) counts
  treated-count tables given the category margins, so 2.5e25 allocations give an exact p with no warning. Fix the
  text, and state the two-sided convention (2 x min one-sided, which differs from coin on ties). Done when: the Rd
  matches the C++ and a test pins the 2 x min convention.

- [ ] TODO-367 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **Exact 0s and 1s in
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

- [ ] TODO-368 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropZeroOneInflatedBetaRegr` returns NA with no warning for exact 1s without 0s and an uncentred
  covariate.**
  Ids: ds-proportion-44883784401-f4.
  Reproduced on HEAD (seed 1): raw age gives CI `NA NA`, `is_nonestimable()` TRUE, no warning; centred age gives
  (0.342, 0.745). Not root-caused (likely an ill-conditioned one-class inflation submodel in
  `R/EDI/R/inference_proportion_zero_one_inflated_beta.R`); seed 3 also gives a finite CI with `is_nonestimable()`
  TRUE (stale flag). Fix: standardize covariates inside the joint fit and back-transform, drop an empty boundary
  submodel, warn when the SE is still unavailable, and keep the flag consistent. Done when: raw and centred
  covariates give the same CI on the repro's seeds 1-6 and `is_nonestimable()` agrees with the CI.

- [ ] TODO-369 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropGCompMeanDiff(variance_fallback_methods = character(0))` loses the point estimate.**
  Ids: ds-proportion-44883784401-f5.
  `shared()` (`R/EDI/R/inference_proportion_gcomp.R:1093-1101`) calls `effects_are_usable(..., estimate_only = FALSE)`
  (`:613-616`), which needs a finite `se_md`; with an empty cascade `set_failed_fit_cache()` wipes `md` (0.1218 with
  `estimate_only = TRUE`, NA otherwise), no warning. The docs (`:30-36`) promise an NA variance only. Fix: keep `md`
  and cache a non-estimable SE with a reason (e.g. `variance_cascade_exhausted`) and a warning. Done when: the repro
  returns 0.1218369 with NA SE/CI and a reason.

- [ ] TODO-370 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401):
  **`InferencePropZeroOneInflatedBetaRegr` doesn't check the variables in `model_formula_zero_one`.**
  Ids: ds-proportion-44883784401-f6.
  `initialize()` (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R:130-142`) only runs `assertFormula()` on it;
  `~ bogus` returns NA silently, while the same typo in `model_formula` errors. Fix: also call
  `assertFormulaContext(model_formula_zero_one, ...)` (`helper_additional_asserts.R:28-44`). Done when: the repro errors
  naming `bogus`.

- [ ] TODO-371 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **`InferencePropGCompMeanDiff`'s
  `"model_based"` variance fallback uses the unscaled Bernoulli information for a fractional response.**
  Ids: ds-proportion-44883784401-f7.
  `resolve_effect_variance()` / `model_based_covariance_matrix()` (`R/EDI/R/inference_proportion_gcomp.R:~786-840`,
  docs `:92-110`) use the binomial Fisher information, which `?InferencePropFractionalLogit` (`:12-20`) calls wrong for
  a fractional y; on the repro it is 2.5 x the sandwich SE. Fix (results change, NEWS): scale by the Pearson
  dispersion and document it. Done when: the `model_based` SE on the repro is about 0.0507 (quasi-binomial delta
  method).
  - Owner decision pending: [DECISION-v1.0.6-TODO-371](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-371) (OK to scale the model-based variance by the Pearson dispersion (results change)?).

- [ ] TODO-372 (added 2026-11-21, agent, owner request; docs-scenarios run 44883784401): **The quantile classes offer a
  jackknife that is NA on clean data, and the warning blames separation.**
  Ids: ds-proportion-44883784401-f9.
  `InferencePropQuantileRegr`'s jackknife is NA on interior data with the generic "separation" reason
  (`R/EDI/R/inference_all_abstract_jackknife.R:590-591`, trigger `:678`); the delete-1 jackknife is not consistent for
  sample quantiles anyway. Fix: drop the jackknife capability for the Contin/Prop/KK quantile classes and update the
  small-sample table, or keep it with a quantile-specific reason; reword the generic text so separation is one
  possible cause. Done when: the repro either doesn't offer the jackknife or warns without mentioning separation.

- [x] TODO-404 (added 2026-11-22, done 2026-11-22, coordinator, owner request; docs-scenario free-text gaps): **Doc gaps
  the docs-scenario agents noted outside their findings.** Sources: the "Not done / guesses", "Could not do" and
  "Where I had to guess" parts of the area summaries of run 44883784401 (2026-11-21, this file's section) and run
  44358267779 (2026-11-18, `audit-notes` branch). Docs-only, commit 2bc1e336 (roxygen edited, Rd not regenerated):
  - simulation-framework: `simulations_framework.R`: `X_mat` makes `cov_draw_method` ignored (the code drops it; the
    help said "must be NULL"); `keep_all_intermediate_data` refused with `num_cores > 1` or `Nrep_Y_w > 1`;
    `y_linear_model` (and `betaT`) on the logit scale for incidence, and for proportion, whose `betaT` text said
    additive. `simulation_framework_report.R`: `simulation_mode` values (`standard`, `custom_dgp`,
    `crdg`/`catn`/`cte` joined by `+`), and that `summarize()` groups by it and classifies null cells by mean
    `true_estimand` outside `standard`.
  - count: `vignettes/cookbook-count.Rmd` (`ROADMAP.md`) and `vignettes/extending-edi.Rmd`
    (`R/package_metadata/contracts/...`) link to GitHub (see v1.0.6-TODO-343). `get_matching_cluster_ids()`
    `@R6method` blocks on `DesignSeqOneByOneKK14` (KK21 inherits), `DesignFixedBinaryMatch`,
    `DesignFixedMatchingGreedyPairSwitching` and `ObservationalDesignMatching`.
  - incidence / factorial: `inference_all_abstract_rand_ci.R` and the `randci-compute-rand-two-sided-pval-params`
    template: `type` is `NULL` or `"Zhang"` (incidence on Bernoulli/matching designs) with
    `args_for_type = list(Zhang = list(combination_method = ...))`; the randomization-CI `type` has no usable value.
    `compute_exact_*()` `@R6method` blocks for ExactFisher (`"Fisher"`; CI from `fisher.test`/`mantelhaen.test`,
    `pval_epsilon` ignored, premise held), ExactBinomial (`"Binomial"`; Clopper-Pearson, `pval_epsilon` ignored) and
    ExactZhang's p-value.
  - fixed-designs / clusters-blocking: `design_fixed_rerandomization.R`: choosing `obj_val_cutoff` for a target
    rate (`a = qchisq(p_a, k) * n / (n_T n_C)` for `mahal_dist`, empirical quantile otherwise; `prop_acceptable` as
    the direct route). `design_fixed_blocked_cluster.R`: `set_m()` does not change the randomization (draws use
    `strata_cols`) and only changes what `get_block_ids()` reports.
  - survival-censoring: `inference_all_abstract.R` `set_optimization_alg()`: `"newton_raphson"`, `"lbfgs"`, plus
    `"irls"` when allowed, `match.arg` abbreviations, default from the optimization dispatch policy;
    `inference_survival_weibull.R` constructor: `"lbfgs"` default, no IRLS.
  Code issues seen, not fixed: in `InferenceRandCI$compute_rand_two_sided_pval()` the `type = "Zhang"` dispatch sits
  inside `if (should_run_asserts())`, so with assertions off (e.g. `SimulationFramework`'s
  `turn_off_asserts_for_speed`) `type` is silently ignored and the randomization-draw p-value is returned;
  `DesignFixedBlockedCluster$set_m()` can record block ids that differ from the randomization strata.

- [ ] TODO-373 (added 2026-11-21, agent; found by the v1.0.6-TODO-328 fix): **`InferenceIncidKKGEE` can never return a
  randomization p-value.** The KK GEE mixin's `compute_rand_two_sided_pval` override
  (`R/EDI/R/inference_mixin_kk_gee_shared.R` ~L125) stops with "not supported for incidence. Use Zhang method." unless
  the design is a rerandomization design, but the class accepts only KK designs, so the call always errors. The base
  method has allowed draw-based incidence p-values since 2026-10-20, so the refusal looks stale. Test either way.
  - Owner decision pending: [DECISION-v1.0.6-TODO-373](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-373) (drop the stale incidence refusal, or remove `rand` from `InferenceIncidKKGEE`'s supported procedures?).

- [ ] TODO-374 (added 2026-11-21, agent, owner request; found by the R-CMD-check triage of run 44749244495, follow-up to
  v1.0.6-TODO-169 and v1.0.6-TODO-322): **The Newton-decrement L-BFGS finish exposed two optimizer bugs.** (1)
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
  Done when, after the owner's rebuild with both patches, R-CMD-check is green on every leg and the v1.0.6-TODO-322 (2)
  probes of the other kernels sharing the finish (ZIP / hurdle, ZOIB, the GLMMs, Weibull frailty, CLMM) pass; the
  header change reaches every L-BFGS kernel, and only these two were swapped.
  - **Verified 2026-11-23 (agent) on the owner's 09:28 build with both patches:** `test-rcpp-fitting-equivalence.R` 81/81,
    `test-stereotype-logit-hessian-allocs.R` 18/18, `test-gaussian-lmm-hessian-prealloc.R` 19/19, and the three other
    files from the run 44749244495 failures pass. Still to confirm on CI after a push: R-CMD-check green on every leg, and
    the v1.0.6-TODO-322 (2) probes of the other kernels that share the finish.
- [ ] TODO-375 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalWeibullRegr`: Wald / LR / gradient oversized at n = 1000 with `~1`, and score oversized at every n.**
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
- [ ] TODO-376 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`: Wald / LR / gradient oversized at n = 1000 on KK14 (`~1`).**
  - One cell per test: SeqOneByOneKK14 `~1` n = 1000, size 0.080-0.081 (level 0.0525), coverage 0.919-0.920.
  - v1.1.0-TODO-184 covers Wald at n = 50 and v1.1.0-TODO-256 / -257 the score test; neither covers large n.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignSeqOneByOneKK14' --n 1000 --effect null --only InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell (a single flag may clear); if confirmed, fixed or accepted with rows citing
    this TODO.
- [ ] TODO-377 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalDepCensTransformRegr`: score test oversized at n = 1000.**
  - Size: FixedGreedyDOptimal `~.` n = 1000, size 0.075 (level 0.05). Coverage: FixedOptimal@0.2 `~.` n = 50, 0.867
    (level 0.9), and FixedGreedyDOptimal `~.` n = 1000.
  - v1.1.0-TODO-183 covers score / LR at n = 50 only (small-sample); the n = 1000 cell is outside it.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedGreedyDOptimal' --n 1000 --effect null --only InferenceSurvivalDepCensTransformRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cells; the n = 50 coverage cell can join v1.1.0-TODO-183 if it confirms.
- [ ] TODO-378 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalCoxPHRegr` and `InferenceSurvivalStratCoxPHRegr`: randomization test oversized at n = 200.**
  - CoxPHRegr: FixedGreedy and FixedGreedyDOptimal `~.` n = 200, size up to 0.075 (level 0.05).
    StratCoxPHRegr: SeqOneByOneEfron `~.` n = 200, size 0.076. Neither class has a calibration TODO.
  - A randomization test is exact under the design, so a confirmed excess is a bug (check the redraw uses the design's
    own randomization, and the Monte Carlo p-value's resolution), not small-sample behaviour.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedGreedy' --n 200 --effect null --only InferenceSurvivalCoxPHRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"` (and `--design 'DesignSeqOneByOneEfron' --only InferenceSurvivalStratCoxPHRegr`). Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the three cells; confirmed ones are fixed.
- [ ] TODO-379 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferencePropQuantileRegr`: Wald oversized at n = 1000, FixedBernoulli prob_T 0.2.**
  - One cell: FixedBernoulli@0.2 `~.` n = 1000, size 0.076 (level 0.05), coverage 0.924. No calibration TODO covers it.
  - Investigate first if it confirms: the quantile-regression sandwich / kernel density bandwidth with about 200
    treated, and the 0/1 boundary of the proportion response.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type proportion --design 'DesignFixedBernoulli@prob_T=0.2' --n 1000 --effect null --only InferencePropQuantileRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell; if confirmed, fixed or accepted with rows citing this TODO.

- [x] TODO-380 (added 2026-11-21, owner request; from the v1.0.6-TODO-327 decision): **A separate opt-in
  design-conservative Bartlett option, and "the testing type you ask for is the test you get".** (1) Owner 2026-11-21:
  `lik_ratio_bartlett_approx` stays the model-only Bartlett-corrected LR test on `InferenceCountKKCondPoissonOneLik`
  and `InferenceCountKKHurdlePoissonOneLik`. Add a separate option for the design-conservative version (the larger of
  the Bartlett p-value and the design Wald p-value, the union of the CIs, as `.conservative_kk_onelik_pval` / `_ci`
  already do for `lik_ratio`), with its CI and p-value branches, a `get_supported_testing_types()` entry, docs, and a
  test that its interval contains both the model-only Bartlett and the design Wald intervals. (2) **Owner principle:
  "If the user wants wald, we should always give wald."** A testing type must return that test, never another
  procedure. Audit and fix the Wald paths that silently return something else: the KK count OneLik classes fall back
  to the nonparametric-bootstrap interval when the model-based SE is unavailable (`inference_count_KK_cond_poisson.R`
  ~L856-866, documented ~L1697-1703); the same `compute_bootstrap_confidence_interval(alpha = alpha)` fallback also
  appears in `inference_all_abstract_count_likelihood.R`, `inference_survival_log_rank.R`,
  `inference_survival_km_diff.R`, `inference_survival_gehan_wilcox.R` and `inference_survival_rmst.R` (check each is a
  Wald path). Return the Wald result, or NA with a recorded `procedure_failure_reason` and a classed warning
  (v1.0.6-TODO-255 convention); offer the bootstrap as its own option if it is still wanted there. This changes results
  where a fallback fired, so it needs a NEWS entry. Test: with the SE forced unavailable, `testing_type = "wald"` never
  returns a bootstrap interval.
  - **Owner decision 2026-11-21:** the new testing type is named `"lik_ratio_bartlett_approx_design_conservative"`.
  - **Owner decision 2026-11-21:** `InferenceCountPoisson` gets the same split: its `lik_ratio_bartlett_approx`
    becomes the model-only Bartlett test (today it is wrapped in the design-conservative rule,
    `R/EDI/R/inference_count_poisson.R:404`), and its current result moves to
    `"lik_ratio_bartlett_approx_design_conservative"`. This changes `InferenceCountPoisson`'s default Bartlett result;
    NEWS entry required.
  - **Done 2026-11-23 (agent):** (1) New testing type `"lik_ratio_bartlett_approx_design_conservative"` on
    `InferenceCountPoisson`, `InferenceCountKKCondPoissonOneLik` and `InferenceCountKKHurdlePoissonOneLik` (the larger of
    the model-only Bartlett and design Wald p-values, the union of the CIs), reached through `set_testing_type()` and
    `compute_asymp_*()`. No new public methods: those would have to join the `likelihood_tests` method list on every
    likelihood class, plus suite sentinels and the argument registry. (2) `InferenceCountPoisson`'s
    `lik_ratio_bartlett_approx`, and also its best-available `compute_lik_ratio_bartlett_*` pair, so the two can't
    disagree, are now model-only; the new type reproduces the old result exactly (`identical()` on a fixture). (3) New
    `edi_wald_unavailable_na()` (`helper_robust_sandwich.R`): NA, `procedure_failure_reason$wald`, and a once-per-fit
    `edi_wald_unavailable_warning`. It replaces the bootstrap fallback in the Wald paths of KK hurdle Poisson OneLik,
    hurdle Poisson, ZIP, the zero-augmented base (ZINB), ordinal g-comp, the LogRank and Gehan-Wilcoxon CIs, and
    right-censored KMDiff / RMST. The unused `count_bootstrap_fallback_*` helpers were deleted. Tests:
    `R/package_tests/testthat_bulk/test-lik-ratio-bartlett-approx-design-conservative-testing-type.R` (36),
    `test-wald-se-unavailable-returns-na-never-bootstrap.R` (46); 90 related bulk files pass. Kept by design:
    interval-censored KMDiff / RMST (no analytic SE; bootstrap is the documented strategy), the KK GEE jackknife-Wald,
    and `InferenceCountPoisson`'s Wald / jackknife-Wald union. Follow-up: v1.0.6-TODO-413 (ZA count classes ignore the
    testing type).
  - Decided 2026-11-23 (owner): rank tests drop the bootstrap fallback, Poisson best-available Bartlett pair stays model-only; see [DECISION-v1.0.6-TODO-380d](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-380d). Implementation: v1.0.6-TODO-417.

- [ ] TODO-381 (added 2026-11-21, owner request; from the `pkg-size` budget report, issue #66): **The R CMD check
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
- [ ] TODO-382 (added 2026-11-21, owner request; from the `ci-self-check` audit, issue #20): **Eight workflows now take
  1.6-3.4x their 8-week median.** calibration-study 384 vs 114 min (ci-self-check-m17a2fb9e), audit-results-freshness
  113 vs 56 (ci-self-check-m4736ea4b), audit-python-vulns 103 vs 54 (ci-self-check-med42e85a), audit-generated-drift
  91 vs 47 (ci-self-check-md410b94c), audit-dead-code 134 vs 82 (ci-self-check-m03e51a70), audit-dependency-license 77
  vs 41 (ci-self-check-m6bcbb195), audit-ci-self-check 59 vs 35 (ci-self-check-m45af0b31), audit-allowlist-hygiene 50
  vs 29 (ci-self-check-m7f0b680b). Most medians rest on only 3 earlier runs, and several audits that rarely build EDI
  (python-vulns, dependency-license) roughly doubled together, which points at a shared step (package install or
  cache miss) rather than each audit's own work. Compare step timings of one slow and one normal run per workflow;
  fix the shared cause, or accept the new baseline here per workflow. Done when: the next ci-self-check run reports
  none of these ids, or each is accepted with a reason.
- [ ] TODO-383 (added 2026-11-21, owner request; from the algorithm-audit drift report, issue #55): **Re-look at
  algorithm-audit row R (exact discrete nulls and enumeration), reviewed 2026-10-22.** Commit `8d8c5f78` (2026-11-20)
  changed its kernels (`R/EDI/R/inference_helpers_zhang.R`, `R/EDI/src/zhang_exact_speedups.cpp`). Follow
  `R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md` for the row: check the change keeps the
  row's chosen algorithm and its comparator agreement, then update the row's `reviewed` date. Done when: the drift
  report lists no commits for row R.

- [ ] TODO-384 (added 2026-11-21, coordinator; found by the rand warm-start chaining study, see
  `R/package_metadata/audits/research_findings/2026-11-21-rand-warm-start-chaining-timing.md`):
  **`InferenceIncidKKCondLogitGLMMOneLik` randomization replicates disagree with a fresh fit and go NA silently.**
  On n = 150 `DesignFixedBinaryMatch` (75 pairs), r = 400, `num_cores = 1`: (1) the reused-worker statistic matches the
  observed estimate on the original assignment, but on permuted assignments 58 of 60 replicates differ from a fresh
  `compute_estimate()` on the permuted design (same y, X, pairs) by more than 1e-3, up to 0.44 (correlation 0.90);
  the same check on `InferenceCountKKGLMM` matches to 3e-9. First suspect: a per-draw cache (clogit / reservoir split,
  pair data) that the worker does not refresh. (2) With the full-data base warm start (v1.0.6-TODO-61) 43 of 400
  replicates are NA with no warning (7 with the old chaining, 0 of 60 with warm starts off); `na.rm` drops them and
  the p-value moves (0.112 vs 0.102). Example: on the mirrored assignment `1 - w` the worker returns NA while a fresh
  fit gives -0.6247. Fix (1) first, then check whether (2) remains; the randomization p-value of this class is
  unreliable until then. Test: worker replicate equals a fresh fit on several permuted draws, and no silent NA.
- [x] TODO-407 (added 2026-11-22, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 27): **`InferenceOrdinalCloglogRegr`: every model-based test oversized in one cell, FixedBlocking prob_T 0.2, n = 1000.**
  - Wald / score / LR / gradient, size and coverage, all in FixedBlocking@0.2 `~.` n = 1000: size 0.075-0.078 (level
    0.05), coverage 0.922-0.925. No other Cloglog cell is flagged, and no calibration TODO covers the class.
  - All four tests moving together in one cell points at the fit or the data in that cell (for example a sparse
    outcome category in the treated arm at prob_T 0.2 within blocks), not at one test's reference distribution.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type ordinal --design 'DesignFixedBlocking@prob_T=0.2' --n 1000 --effect null --only InferenceOrdinalCloglogRegr --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell; if confirmed, fixed or accepted with rows citing this TODO.
  - Status 2026-11-23 (coordinator): DONE. All 8 flagged cells (Wald / score / LR / gradient, size and coverage, FixedBlocking@0.2 n = 1000) were cleared by confirmation on fresh replicates in wave 29 of campaign 2026-11-15-e36c7710: screening noise, not a defect. No code change and no accepted rows needed.
- [ ] TODO-408 (added 2026-11-22, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 27): **Ordinal randomization tests oversized in one shared cell, SeqOneByOneiBCRD prob_T 0.2, n = 50.**
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
- [ ] TODO-409 (added 2026-11-23, coordinator, owner decision 2026-11-22; found by calibration campaign 2026-11-15-e36c7710): **The calibration planner abandoned slow units after shard timeouts instead of shrinking their shards.**
  - Problem: `InferenceOrdinalKKCLMM` null at n = 1000 costs ~870 s per replicate in `rand` (Wald 2.7 s), so its shards
    (4-7 replicates) ran ~58 min and some hit the shard job's `timeout-minutes: 75` (4 per wave in runs 44902301848,
    44970301607, 45002060522). `plan_calibration_study.R` counted every planned shard without a ledger row as dead,
    abandoned the unit at `--max-dead 3`, and re-planned a unit that had lost a shard at the same size, so it died again.
    Before this change the plan at wave 28 had all three units (FixedBinaryMatch, SeqOneByOneKK14, SeqOneByOneKK21)
    abandoned.
  - Owner decision 2026-11-22: options 1 and 2 below. Option 3, making `InferenceOrdinalKKCLMM`'s randomization test
    cheaper, is not taken now.
  - Changed: (1) planner: after each death the unit's next shards carry at most half the replicates of its smallest dead
    shard (down to 1), and only a dead 1-replicate shard counts toward `--max-dead`; recomputed from `planned.csv` every
    wave, so the three units came back without any edit to the `calibration-results` branch. `planned.csv` gains a
    `reps` column (the workflow adds it, empty, to an older file); for older rows the dead shard's size comes from its
    wave's finished siblings in the ledger (`n_done + n_failed + n_skipped`), else from the gap between shard ids.
    (2) backstop: the planner writes `timeout_minutes` into each matrix entry (`--timeout-minutes 75`,
    `--dead-timeout-minutes 180` for a unit that has lost a shard; at most 360) and the shards job uses
    `timeout-minutes: ${{ matrix.timeout_minutes || 75 }}`. Test:
    `R/package_tests/testthat_bulk/test-calibration-dead-shards-halve-replicates-and-extend-timeout.R`.
  - Dry run on the campaign files at wave 28: 0 abandoned units (was 3); the three units now plan 74 shards of 3
    replicates (FixedBinaryMatch, 7-replicate shards died), 176 and 12 shards of 2 (KK14, KK21; 4-replicate shards
    died), all with the 180-minute timeout; every other shard is the same as before, at 75 minutes.
  - Watch: a shard runs its replicates in parallel on 4 cores and the first round is never cut by the deadline, so a
    shard of 4 or fewer replicates takes about as long as its slowest replicate. Halving below 4 lowers the chance of
    a slow outlier, but the 180-minute timeout is what lets a single slow replicate finish.
  - Owner decision pending: [DECISION-v1.0.6-TODO-409a](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-409a) (keep halving shards below 4 replicates, or rely on the 180-minute timeout?).
  - Owner decision pending: [DECISION-v1.0.6-TODO-409b](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-409b) (after three dead 1-replicate shards, abandon the whole unit or only those replicates?).
  - Decided 2026-11-23 (owner): calibration campaigns gate x.y.0 releases only; this unfinished campaign does not gate 1.0.5; see [DECISION-v1.0.6-TODO-409c](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-409c).
  - Done when: after a push, the next wave(s) complete the `InferenceOrdinalKKCLMM` n = 1000 units.
- [x] TODO-410 (added 2026-11-23, agent, owner request; nightly runs 44890775329 and 45008760951, benchmark canary):
  **Likelihood fits through the shared L-BFGS wrapper got 1.3x-3x slower with v1.0.6-TODO-169.** Every flagged row
  first appeared together in the 11-21 nightly, the first on 8d8c5f78. The 11-18 nightly (4ce2b712) ran every section
  and passed, with the current CLMM wald row at 24.6 ms. In 4ce2b712..9186e6a5 the GLMM/CLMM kernels changed only by
  refactors (shared `glmm::gauss_hermite_rule`/`soft_barrier`, v1.0.6-TODO-193), and the ordinal CLMM/GLMM kernels,
  build flags, `nightly.yml` and the benchmark harness did not change. What did change is `_helper_functions_core.h`
  (8d8c5f78, v1.0.6-TODO-169). `optimize_likelihood_lbfgs` now passes every run that fails the gradient test to
  `lbfgs_finish_with_newton_decrement()`. That evaluates a Hessian at the stop (`numerical_hessian()` when the
  functor has no `hessian()` method, e.g. `fast_ordinal_clmm.cpp`), and it can take up to 50 damped Newton steps.
  GLMM-type fits usually stop on LBFGSpp's relative-decrease rule, so they now pay for that on most fits.
  Rows (release v1.0.4 -> current, ms; 11-21 / 11-22 runners):
  - wald-ordinal `InferenceOrdinalCLMM` (pairs) 24.4 -> 71.3 / 18.0 -> 51.8; `InferenceOrdinalGLMM` (pairs) 25.5 -> 61.5 / 14.6 -> 34.8;
    models-ordinal CLMM 79 -> 160, GLMM 124 -> 208.
  - `InferenceCountGLMM` (pairs) wald 10.2 -> 14.9, models 32-45 -> 42-58; `fast_logistic_glmm_cpp` (pairs, kernel only)
    27.8 -> 40.0 (a direct `.Call`, so no R-layer cause).
  - Not covered by v1.0.6-TODO-6: `InferenceCountZeroInflatedPoisson` wald 0.27 -> 0.65, models 1.9 -> 2.8;
    `InferenceCountZeroInflatedNegBin` 0.87 -> 1.15 / 15.6-20.7 -> 23.8-30.4; `InferenceCountHurdleNegBin` 0.20 -> 0.27,
    0.97 -> 1.25; `InferenceIncidKKCondLogitGLMMOneLik` 2.9 -> 3.7 / 3.0-4.4 -> 9.7-15.6;
    `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik` 0.75-0.99 -> 1.07-1.42 / 0.94-1.33 -> 2.5-3.5;
    `InferenceContinGLMM` (pairs) 0.05-0.09 -> 0.13-0.26.
  - Separate, 11-22 only: procedures "Randomization test p-value: OLS covariate-adjusted (r = 1000)" 30.9 -> 44.3
    (OLS does not use L-BFGS; check the next nightly before treating it as real).
  Benefit check (owner request 2026-11-23): v1.0.6-TODO-169 verified the finish on NegBin/Poisson/probit/beta/ZINB but did
  not re-probe the GLMM, CLMM, ZIP/hurdle, Weibull frailty or conditional-logit GLMM kernels, which are the slowed rows.
  With the finish on vs off, record for each of those kernels whether the estimate, SE, negLL and converged flag
  change (a) on the benchmark data (`R/benchmark/benchmark_model_fits.R` fixtures) and (b) on the colon scaling
  variants of v1.0.6-TODO-169 (raw, `scale()`d, age x 1000, age + 1e5) against a reference fitter (glmer, ordinal::clmm,
  pscl, ...). If (a) shows no change, the cheap fixes below keep (b) and recover the speed.
  Cause not yet confirmed by measurement (no build was run). Confirm first: kernel-swap one kernel (sourceCpp copy, as
  in the `feedback_kernel_swap_test_no_relink` memory) with and without the finish, and count how often the finish runs
  and how many Hessians and Newton steps it takes per fit on the benchmark data. Fix candidates (results must stay as
  v1.0.6-TODO-169 made them, or any change explained): an analytic `hessian()` for the CLMM functor; cache the
  Hessian across the rule check and the first Newton step; skip the finish when LBFGSpp stopped with a gradient
  already within a looser scale-aware bound. Overlaps v1.0.6-TODO-6 (the GLMM/CLMM warm-start screen); the
  v1.0.6-TODO-411 Ubuntu reproducibility timeout probably has the same cause. Done when the rows above are back within
  the canary's 1.25x, or the owner accepts the cost and the rows go into `R/benchmark/benchmark_regression_allowlist.csv`
  citing this TODO.
  -- Measurement (agent, 2026-11-23): cause CONFIRMED, but the finish also helps, so its cost is not free to drop.
  Method: kernel swap of all ten kernels (scratch `sourceCpp` copies built against a copy of `_helper_functions_core.h`
  with a runtime switch; OFF = the pre-TODO-169 verdict `gradient_norm < tol || niter < maxit`, no finish, no NaN
  rescue; `R/EDI/src` and `EDI.so` untouched; the Poisson GLMM and hurdle NegBin copies also compiled
  `fast_poisson_regression.cpp` / `fast_logistic_regression.cpp` into the same scratch unit, both used there only for
  IRLS start values). Local timings, single thread, 15 interleaved repeats; the ratios match the nightly.
  Benchmark fixtures, median ms OFF -> ON (models / wald): CLMM 92 -> 198 / 33 -> 87; ordinal GLMM 168 -> 293 / 38 -> 87;
  Poisson GLMM 60 -> 77 / 16 -> 21; logistic GLMM 38 -> 58 / 15 -> 21; ZIP 3.5 -> 4.4 / 0.36 -> 0.96; ZINB 12.2 -> 24.2 /
  0.98 -> 1.38; hurdle NegBin 1.28 -> 1.60 / 0.25 -> 0.38; clogit+GLMM 6.8 -> 20.5 / 5.1 -> 6.9; Weibull frailty 1.8 ->
  5.0 / 1.4 -> 2.0; Gaussian LMM 0.13 -> 0.30 / 0.12 -> 0.17. The finish runs after every L-BFGS run, including each
  multistart start (CLMM 5, ordinal GLMM 6, Poisson GLMM 10, logistic GLMM 5; 1-2 elsewhere): the gradient is never
  below 1e-6 at LBFGSpp's stop. Hessians / Newton steps per fit (models; wald): CLMM 10 / 5; 19 / 14, all
  `numerical_hessian()` (GLMM engine); ordinal GLMM 22 / 16; 22 / 16 (its own `hessian()` is also a central difference
  of the gradient); Poisson GLMM 10 / 0; 11 / 1; logistic GLMM 7 / 2; 5 / 0; ZIP 1 / 0; 17 / 16 (plus expected
  information when the observed one is not PD); ZINB 14 / 12; 2 / 1, numerical (on models 13 of the 14 are the NaN
  rescue from the start of a ZINB fit that fails either way and falls back to the reduced model); hurdle NegBin 2 / 0
  both; clogit+GLMM 2 / 1; 1 / 0; frailty 1 / 0 both, numerical; LMM 1 / 0 both. One Hessian costs about as much as the
  whole L-BFGS fit in these kernels, so even the finishes that pass at once (most of them) double the time. The
  converged flag never flipped.
  (a) Benchmark data, ON vs OFF (abs diff of treatment estimate; SE; negLL decrease): <= 2e-8 for ordinal GLMM, hurdle
  NegBin, frailty, LMM, CLMM models, Poisson GLMM models, logistic GLMM wald, ZIP models, ZINB models, clogit+GLMM wald.
  Changed, always toward the reference: ZIP wald 6.7e-3 (pscl gap 6.5e-3 -> 1.6e-4; negLL -4.42: OFF stopped at
  lambda^2 = 0.078 vs bound 6.7e-5); clogit+GLMM models 0.015, negLL -0.016 (no reference); logistic GLMM models 1.4e-3
  (glmer nAGQ = 20 gap 1.3e-3 -> 7e-5); CLMM wald 2.5e-4 (clmm gap 2.5e-4 -> 4e-7); Poisson GLMM wald 2.3e-4 (glmer gap
  2.4e-4 -> 6e-6); ZINB wald 7e-5. SE changes <= 1.7e-5.
  (b) colon variants. Responses: binary `status`; count pmax(nodes - 1, 0) and ordinal cut(nodes, c(-Inf, 1, 4, Inf))
  with nodes dropped from X; LMM log(time); frailty time / status; zero part of ZI/hurdle (1, w, age). Groups: pairs of
  consecutive rows in time order (in nodes order for LMM and frailty); clogit+GLMM: consecutive opposite-arm pairs in
  time order, discordant ones -> conditional part, concordant pairs and leftover rows -> GLMM part. Reference: glmer /
  lmer / ordinal::clmm / pscl on the `scale()`d design; the treatment coefficient and the maximum likelihood do not
  change across the four variants, so negLL above the best fit measures the error. OFF -> ON, gap in estimate (negLL
  excess):
  - Fixed by the finish: Poisson GLMM raw 1.6e-3 -> 9e-5, x1000 / +1e5 0.104 (+14.5 / +9.1) -> 9e-5; ZIP raw 1.2e-3 ->
    1e-7, x1000 / +1e5 0.043 (+6.3 / +2.6) -> 1e-6; hurdle NegBin raw 7.6e-3 -> 2e-5, x1000 / +1e5 0.245 (estimate 0) ->
    5e-6; LMM raw 2.8e-3 (+0.48) -> 5e-5, x1000 / +1e5 (+2.6 / +8.3) -> 9e-5; the raw design of logistic GLMM (+0.54 ->
    0), CLMM (1.3e-2 -> 8e-5), clogit+GLMM (0.18, +5.0 -> 0) and frailty (0.074, +4.5 -> 0); ZINB raw 6.4e-3 -> 1.5e-3
    (negLL +2.1 either way, known).
  - Not fixed, and reported converged = TRUE both ways (Hessian not PD at the stop, so the old verdict stands): CLMM
    x1000 estimate 0 -> -0.218 vs -0.170 (+68 -> +47), +1e5 estimate 0 (+65) both; logistic GLMM x1000 / +1e5 -0.110 ->
    -0.23 vs -0.263 (+27 -> +9); clogit+GLMM x1000 / +1e5 estimate 0 (+40) both; frailty x1000 / +1e5 0.080 vs 0.347
    (+46 / +37) both; ZINB x1000 / +1e5 (+8.7 / +18, known from v1.0.6-TODO-169). The ordinal GLMM is wrong on x1000 /
    +1e5 both ways but reports converged = FALSE.
  Prototypes (copies only, nothing in `R/EDI/src` changed): (1) skip the finish when LBFGSpp's own inverse-Hessian
  approximation gives g'Hg <= the bound: REJECTED, it underestimates lambda^2 by up to 1e5x on the raw colon designs
  (logistic GLMM 5.2 vs 6.3e-5) and keeps the OFF errors (logistic GLMM raw -0.271, LMM raw +0.48). A relative-gradient
  screen fails too: on the benchmark data the finishes that needed Newton steps and those that passed at once overlap
  (max |g_j| max(1, |theta_j|) / max(1, |f|) 2e-5 to 2.6e-3). (2) Reusing the Hessian between the rule check and the
  first Newton step: the code already does this (the step uses the check's Hessian). (3) Forward instead of central
  differences in `numerical_hessian()` during the finish: CLMM 227 -> 200 / 111 -> 79, frailty 6.2 -> 4.2 / 2.3 -> 2.1,
  ZINB 27.8 -> 25.5 / 1.62 -> 1.44; benchmark results move <= 6e-5, but CLMM colon x1000 falls back to estimate 0.
  (4) Finish only the multistart winner (each start's L-BFGS without the finish, then an L-BFGS restart with the finish
  from the best start): ms ON -> (4) (OFF): CLMM 223 -> 128 (113) / 106 -> 52 (39); ordinal GLMM 332 -> 272 (218) / 103
  -> 76 (37) (its tight-tolerance polish still runs the finish); Poisson GLMM 85 -> 70 (64) / 21.5 -> 16.8 (17);
  logistic GLMM 62 -> 50 (43) / 20.5 -> 17 (15). Against current ON on benchmark data: estimate <= 7.9e-4, SE <= 8.9e-5,
  negLL within 3e-5, converged unchanged. Colon (b) results kept, except that CLMM x1000 loses ON's partial improvement
  (back to estimate 0) and logistic GLMM +1e5 gets better (+9 -> +1.0). The rule itself accepts points about 0.02 SE
  from the optimum, so changes of 1e-4 to 1e-3 are inside its tolerance.
  Recommendation (agent): keep the finish; adopt (4) in the four multistart kernels (CLMM, ordinal GLMM, Poisson GLMM,
  logistic GLMM); accept the remaining cost of the single-start kernels (one Hessian is the floor there) and allowlist
  those rows citing this TODO. Still open, for separate TODOs: the colon cases above that stay wrong with
  converged = TRUE, and the ZINB NaN rescue that spends 12 Newton steps on a fit that is discarded. Side findings: the
  benchmark ordinal-pairs generator makes p2 negative, so the middle category is empty (y in {1, 3}) and both ordinal
  kernels fit a boundary model; `fast_ordinal_glmm_cpp` then differs from ordinal::clmm by 0.38 / 0.18 (it matches to
  1e-5 on colon). Unverified: with groups of 6 rows (a first colon attempt) the logistic GLMM kernel reported a negLL
  10 below glmer's (190.7 vs 200.8), and `fast_gaussian_lmm_cpp` refuses groups larger than 2; check whether the
  other GLMM kernels accept such groups but compute a different likelihood. Scripts: session scratch `$TMPDIR/t410/`
  (not committed).
  - Decided 2026-11-23 (owner): keep the finish and accept the cost; slowed rows allowlisted; see [DECISION-v1.0.6-TODO-410](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-410).
  - DONE 2026-11-23: ten rows added to `R/benchmark/benchmark_regression_allowlist.csv` citing this TODO (remove at the v1.0.6 release). Still open in separate TODOs if filed: the colon cases that stay wrong with converged = TRUE, and the ZINB NaN rescue.
  - Briefly revised 2026-11-23 to "finish only the multistart winner" (implemented by kernel swap: CLMM 256 -> 131 /
    150 -> 66 ms, estimates moved <= 7.9e-4), then withdrawn the same day: the owner confirmed the ruling above (keep the
    finish everywhere). The code, roxygen and NEWS edits were reverted to HEAD; the prototype is in /tmp/claude-1000/t410/.
  - Follow-ups filed from the measurement: v1.0.6-TODO-419 (colon cases wrong but converged = TRUE), v1.0.6-TODO-420
    (wasted ZINB NaN rescue), v1.0.6-TODO-421 (ordinal benchmark generators leave the middle category empty),
    v1.0.6-TODO-422 (unverified: GLMM likelihood for groups larger than two).
- [ ] TODO-411 (added 2026-11-23, agent, owner request; nightly runs 44890775329 and 45008760951): **The nightly Ubuntu
  reproducibility leg times out, so the cross-leg comparison fails.** `reproducibility (ubuntu-latest-release)` was
  cancelled at the 150-minute job limit on 11-21 (8d8c5f78) and 11-22 (9186e6a5); it took 47-69 min on 11-18..11-20.
  "reproducibility comparison across legs" then fails with "1 leg(s) produced no results"; the other four legs agree on
  every digest. The leg runs with `EDI_EXHAUSTIVE_WORKER_TESTS=true`, and the log stops at the first file,
  `test-aa-fork-worker-count-invariance-registry.R`, printing nothing for 2 h 15 min. That file runs the whole
  registry sweep (`worker_invariance_sweep("fork")`, every concrete exported non-IVWC non-KK class at 1/2/4 fork
  workers) inside one `test_that()` with its expectations at the end, so a hang and a slow sweep look the same in the
  log. Most likely cause: the v1.0.6-TODO-410 fit slowdown, multiplied over the sweep (it started with the same
  commit). A fork-worker hang is not ruled out: the old nanonext hang was mirai, but this file deliberately runs
  before mirai. Investigate: run the sweep locally with `EDI_EXHAUSTIVE_WORKER_TESTS=true` and
  `EDI_WORKER_INVARIANCE_VERBOSE=true` (over 10 minutes, real fork workers) and time each class, or add a per-class
  progress line with elapsed time to `worker_invariance_sweep()` (`helper-worker-count-invariance.R`) so the CI log
  shows where it stops. Done when the leg finishes within its limit (a fix, a per-class time cap, or a raised
  `timeout-minutes` with the reason) and the comparison step passes with five legs.
  -- Progress (agent, 2026-11-23): `worker_invariance_sweep()` now writes a `[worker-sweep HH:MM:SS +Nm] start|done`
  line to stderr around every (class, response, procedure, cores) run on the exhaustive leg (or with
  `EDI_WORKER_INVARIANCE_VERBOSE=true`). The other four legs did not slow (8-14 min on 11-23 vs 11-15 on 11-20), and
  the ~10 TODO-410 classes cannot turn 58 min into 150+, so a fork-worker hang or one very slow run is more likely
  than the fit slowdown. Next: read where the next nightly's Ubuntu leg log stops.
  -- Root cause and fix (agent, 2026-11-24; nightly run 45393057600 on 82ef6889): the progress lines stop at
  `start fork cores=1 InferenceCountHurdleNegBin|count|rand_ci_parallel` (13:02:09; cancelled 15:15); every other
  `rand_ci_parallel` took <= 0.3 s. Reproduced locally (> 5 min, all inside `fast_hurdle_negbin_cpp`, from
  `expand_bound` in the rand-CI bound search). Two causes. (1) The v1.0.6-TODO-169 Newton-decrement finish
  (8d8c5f78, 2026-11-20, the commit the timeouts started with) falls back to `TruncatedNegBinCount::expected_hessian()`
  whenever the observed Hessian is not positive definite, which it never is at the Poisson limit (v1.0.6-TODO-425), and
  that series built a one-row model plus a full Hessian for every term, up to 10000 terms per row (rounding stalled its
  `1 - cum < 1e-10` stop at a huge theta) or `mu + 12 sd` terms at the large `mu` of an extreme shift (5.9e6 one-row
  Hessians at mu ~ e^10). Fixed in `R/EDI/src/fast_hurdle_negbin.cpp`: the series is now four scalar sums per row
  (sum p, p*y, p*digamma(y + r), p*trigamma(y + r)), the same quantity (old vs new 1e-15 at ordinary theta, <= 3e-5 at
  theta 1e8-1e11 where the old per-term sum cancelled), with the bound computed in double (the int cast overflowed at
  eta ~ 700) and a negligible-term stop. (2) A warm start carried over at theta ~ 1e8 made a refit take 25 s even with
  the cheap series; `try_hurdle_negbin_fit()` now drops a warm start whose log theta is past
  `HURDLE_NEGBIN_POISSON_BOUNDARY_LOG_THETA` (the cold start reaches the same estimate at once). The sweep case: hours ->
  26 s with both (212 s with the kernel fix alone; still hung with the R fix alone), same CI (-9.7662, 10.658). 30
  ordinary hurdle NB fits: 29 bit-identical, one Poisson-limit fit moves (log theta 22.65 -> 23.26, b 5e-5). Verified by
  kernel swap (`sourceCpp` of the file into the scratchpad, no relink); 10 hurdle test files pass; new test
  `R/EDI/tests/testthat/test-hurdle-negbin-poisson-limit-warm-start-dropped.R`. Still open: the leg needs the user's
  rebuild (C++ change) and a nightly that finishes in its limit with five legs.
- [ ] TODO-412 (added 2026-11-23, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), wave 29): **`InferenceOrdinalCauchitRegr`: score / LR / gradient oversized, confirmed at n = 50, 200 and 1000.**
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

- [x] TODO-413 (added 2026-11-23, agent; found by the v1.0.6-TODO-380 agent): **`InferenceCountZeroInflatedPoisson`,
  `InferenceCountHurdlePoisson`, `InferenceCountZeroInflatedNegBin` and `InferenceCountHurdleNegBin` ignore
  `set_testing_type()`.** `compute_asymp_confidence_interval()` / `compute_asymp_two_sided_pval()` always return the
  Wald result: score, gradient, LR and Bartlett all gave the Wald p-value (0.2970551 for every type on a ZIP fixture),
  although `get_supported_testing_types()` lists them. Breaks the owner principle "the testing type you ask for is the
  test you get" (v1.0.6-TODO-380). Fix: dispatch on the testing type as the other likelihood classes do
  (`inference_count_zero_inflated.R`, `inference_count_hurdle.R`, `inference_count_zero_augmented_poisson_abstract.R`),
  or drop unsupported types from the list. Test: for each class and each listed type, the asymp p-value equals the
  direct `compute_<type>_two_sided_pval()`. Results change for anyone who set a non-Wald type; NEWS entry.
  - **Done 2026-11-23 (agent):** new `za_count_asymp_by_testing_type()`
    (`R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`) routes each non-Wald type to the same public method a
    direct call reaches, with a `stop()` default; used by the ZINB base, ZIP, hurdle Poisson and hurdle NegBin
    `compute_asymp_*()`. Wald is unchanged (including the v1.0.6-TODO-380 NA path). All listed types work, so none was
    dropped; the real Bartlett factor gives values close to LR (ZIP 0.675 vs 0.654). Also fixed:
    `InferenceCountHurdleNegBin$compute_gradient_confidence_interval()` inverted the configured type and so returned the
    Wald CI by default (fixture: [-0.596, 0.341] -> [-0.674, 0.424]). Test:
    `R/package_tests/testthat_bulk/test-zero-augmented-count-asymp-honors-testing-type.R` (141); 81 zero-augmented /
    hurdle files in both trees pass (3023, 0 failed). NEWS bullet added. Rd to regenerate:
    `InferenceCountZeroInflatedPoisson.Rd`, `InferenceCountHurdlePoisson.Rd`, `InferenceCountHurdleNegBin.Rd`.
    Follow-up: v1.0.6-TODO-423.

### Audit triage sweep, 2026-11-23 (TODO-414..416)

Found by the 2026-11-23 sweep of the audit reports and CI runs since 2026-11-21 22:30 UTC.

- [ ] TODO-414 (added 2026-11-23, coordinator, owner request; audit decision `code-duplication-d78867741`
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
  caller does, or share one phi-profile helper between the two functions (see v1.0.6-TODO-193). Test: y with an exact
  0 and 1 gives the same weights as y clamped to [1e-10, 1 - 1e-10], and the profile picks a phi other than 10.
  Changes KK21 weights (and so allocations) on such data; NEWS entry. [C++]
- [ ] TODO-415 (added 2026-11-23, coordinator, owner request; audit decision `code-duplication-dc86f7ad2`
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
- [ ] TODO-416 (added 2026-11-23, coordinator, owner request; test-bulk-non-cran runs 44958883285 (91ec8e5c) and
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
- [ ] TODO-418 (added 2026-11-23, agent, owner request; code-duplication run 45037204796, issue #56): **Keep a
  code-duplication family's id, verdict and TODO citation when its code is edited.** A family id (`dup-<12 hex>`,
  `.github/scripts/audits/code_duplication.py` ~L341) hashes the two file paths and the normalized text of both
  regions, and each region runs from the jscpd match out to `EXTEND_LINES` (20) past each end. So it survives a pure
  move, but any edit inside or near either copy makes a new id. The family then comes back on issue #56 as a new
  decision, is judged again by Claude (`verdicts.json` is keyed by the id), and needs a new citation in
  v1.0.6-TODO-193. Evidence: the 2026-11-22 run listed 53 new decisions; 19 of them are on a file pair that
  v1.0.6-TODO-193 already cited under an older id, e.g. `design_abstract.R` vs `design_fixed_abstract.R` was
  `code-duplication-d6b10061f` (L405-498 / L90-191) and is now `code-duplication-dc6d70509` (L417-518 / L90-191).
  Fix: when a new family overlaps an earlier one (same file pair and, say, at least half of each region's lines in
  common), carry over the old family's verdict and decision id instead of minting new ones. Record the old-to-new id
  mapping in `verdicts.json` so citations and dismissals keep working. Re-judge only when the overlap is small or
  the structural differences changed. Alternatively, key families by file pair and the enclosing function or R6
  method names. Test: in a fixture, edit one line inside a judged region; the next detect() gives the same decision id
  and no new Claude batch.

- [x] TODO-417 (added 2026-11-23, owner request; from DECISION-v1.0.6-TODO-380d): **Rank-test asymptotic p-values must
  not fall back to the bootstrap.** `InferenceSurvivalLogRank`'s p-value falls back to the bootstrap when its variance
  or the interval-censored p-value is missing (`R/EDI/R/inference_survival_log_rank.R` ~L181-187), and
  `InferenceSurvivalGehanWilcox`'s asymptotic p-value does the same for interval-censored data (~L196). Return NA with a
  recorded `procedure_failure_reason` and a classed warning (the v1.0.6-TODO-380 `edi_wald_unavailable_na()` pattern,
  with a rank-test reason); the bootstrap stays reachable through its own method. Update the docs; NEWS entry (results
  change where a fallback fired). Test: with the asymptotic quantity forced unavailable, the asymptotic p-value is NA
  with the reason and warning, and the bootstrap stub is never called.
  - **Done 2026-11-23 (agent):** new `edi_rank_test_unavailable_na()` (`R/EDI/R/helper_robust_sandwich.R`) records
    `procedure_failure_reason$rank_test = "rank_test_asymptotic_pvalue_unavailable"` and warns once per fit with
    `edi_rank_test_unavailable_warning` (also an `edi_procedure_na_warning`). `InferenceSurvivalLogRank` (right-censored
    variance or interval-censored `ictest()` p-value missing) and `InferenceSurvivalGehanWilcox` (interval-censored
    `ictest()` p-value missing) use it instead of the bootstrap, which stays available as
    `compute_bootstrap_two_sided_pval()`. Gehan's right-censored fallback to `survdiff(rho = 1)` is the same asymptotic
    test and stays. A sweep of the other rank and nonparametric classes found no other such fallback; interval-censored
    KMDiff / RMST keep the bootstrap by design. Tests: 4 new blocks in
    `R/package_tests/testthat_bulk/test-wald-se-unavailable-returns-na-never-bootstrap.R` (63 pass); 9 related survival
    files pass. NEWS bullet added. Rd to regenerate: `InferenceSurvivalLogRank.Rd`, `InferenceSurvivalGehanWilcox.Rd`.

### Follow-ups from the v1.0.6-TODO-410 measurement, 2026-11-23 (TODO-419..422)

- [ ] TODO-419 (added 2026-11-23, agent, from the v1.0.6-TODO-410 measurement): **Several L-BFGS kernels still report
  `converged = TRUE` at a wrong optimum on the colon age x 1000 / age + 1e5 designs.** With the v1.0.6-TODO-169 finish
  on, the Hessian at LBFGSpp's stop is not positive definite, so `lbfgs_finish_with_newton_decrement()` keeps the old
  "stopped before the cap" verdict. Measured (colon, etype 2, Obs vs Lev+5FU, pairs of consecutive rows in time order;
  negLL above the best fit of the same model on the `scale()`d design): `fast_ordinal_clmm_cpp` x1000 treatment 0 (+68),
  +1e5 0 (+65), truth -0.170; `fast_logistic_glmm_cpp` x1000 / +1e5 about -0.23 (+9), truth -0.263;
  `fast_clogit_plus_glmm_cpp` x1000 / +1e5 0 (+40); `fast_weibull_frailty_cpp` x1000 / +1e5 0.080 (+46 / +37), truth 0.347;
  ZINB already known (v1.0.6-TODO-169). `fast_ordinal_glmm_cpp` is also wrong there but reports `converged = FALSE`.
  Fix candidates: report not converged when the rule cannot judge a point that is far from stationary (e.g. a large
  relative gradient), retry from an internally column-scaled problem (the v1.0.6-TODO-163 Weibull approach), or use
  the expected information when the observed one is not PD. Repro scripts: the v1.0.6-TODO-410 session scratch
  (`colon.R`, not committed); the TODO-410 measurement note has the response and grouping construction.
- [ ] TODO-420 (added 2026-11-23, agent, from the v1.0.6-TODO-410 measurement): **The ZINB NaN rescue spends 12 Newton
  steps on a fit that is thrown away.** On the benchmark `InferenceCountZeroInflatedNegBin` fixture (Poisson data, so
  theta goes to its boundary) the full ZINB L-BFGS run ends non-finite, `optimize_likelihood_lbfgs` retries the
  damped-Newton finish from the start (gradient norm 669, 13 numerical Hessians, 12 steps), the rescue fails the rule,
  and the kernel falls back to the reduced model anyway: fit time 12.2 -> 24.2 ms for no change in the result. Skip the
  rescue when the start is far from stationary, or cap its steps, and check that the TODO-169 NegBin rescue cases
  (smart cold start, age x 1000 / + 1e5) still succeed.
- [ ] TODO-421 (added 2026-11-23, agent, from the v1.0.6-TODO-410 measurement): **The benchmark ordinal generators leave
  the middle category empty.** `generate_kk_ordinal_pairs_data()` and the `"ordinal"` branch of `generate_data()` in
  `R/benchmark/benchmark_model_fits.R` set p1 = 1 / (1 + exp(eta - 1)) and p2 = 1 / (1 + exp(eta + 1)) - p1, which is
  always negative, so it is clamped to 1e-6 and y takes only 1 and 3 (199 / 201 on the CLMM pairs fixture). The
  ordinal kernels then fit a boundary model (log spacing of the cutpoints about -13), and `fast_ordinal_glmm_cpp`
  differs from `ordinal::clmm` by 0.38 / 0.18 on those fixtures while matching it to 1e-5 on colon. Fix the
  probabilities (cumulative P(Y <= k) = plogis(alpha_k - eta) with increasing alpha), note that it changes every ordinal
  benchmark dataset and timing, and check the ordinal GLMM vs clmm gap on boundary data separately.
- [ ] TODO-422 (added 2026-11-23, agent, from the v1.0.6-TODO-410 measurement; unverified): **Check whether the GLMM
  kernels compute the right likelihood for groups larger than two rows.** In a first colon attempt with groups of 6
  rows, `fast_logistic_glmm_cpp` reported a negLL of 190.7 where `lme4::glmer(nAGQ = 20)` on the same data and model
  gave 200.8 (a better likelihood than the reference, which should not happen for the same model), while
  `fast_gaussian_lmm_cpp` refuses groups larger than 2. KK designs only produce pairs and singletons, but the kernels
  accept any `group_id`. Compare each GLMM kernel (logistic, Poisson, ordinal CLMM / GLMM, hurdle Poisson, frailty)
  with glmer / clmm on groups of 3-6 rows, and either fix the likelihood or reject such groups as the LMM does.

- [ ] TODO-423 (added 2026-11-23, agent; found by the v1.0.6-TODO-413 agent): **`InferenceAsympLik`'s
  `compute_asymp_*()` switch has no `stop()` default**, so a testing type with no branch returns `NULL` (the bug class
  v1.0.6-TODO-327 fixed in the subclasses). Add `stop("Unsupported testing_type: ", ...)` to both switches in
  `R/EDI/R/inference_all_abstract_asymp_lik.R` and sweep the remaining `switch(private$testing_type` sites that lack one
  (v1.0.6-TODO-327's sweep listed abstract_asymp_lik, std_mod_cache, logit, binomial_identity, log_binomial, beta, zoib,
  coxph, strat_cox). `set_testing_type()` validates names today, so this guards against a supported-type list and a
  switch drifting apart. Test: a class whose supported list names a type its switch lacks errors instead of returning
  `NULL` (inject via a test subclass).
- [x] TODO-425 (added 2026-11-24, agent; found by the dispatched R-CMD-check run 45295584606 on 8077aea1; done
  2026-11-24, agent): **Full R-CMD-check run 45295584606: valgrind and ASAN/UBSAN failures.** valgrind had 13 failures,
  ASAN/UBSAN 12 (the same set without the fork test). Neither log has a sanitizer finding: no AddressSanitizer or UBSAN
  `runtime error`, and every valgrind `ERROR SUMMARY` is 0 errors with 0 bytes definitely lost. Per file:
  - `test-design-abstract-hierarchy.R:97` (both legs, and every other leg): stale "exactly 4 rows" message; fixed on HEAD
    by 7ea2bf58.
  - `test-kk-ivwc-bayesian-bootstrap-replicates-match-estimator.R:77,84` (quantreg), `test-recorded-na-reason-warns.R:88`
    (multgee), `test-reused-worker-rank-deficient-draw-rebuilds-covariates.R:101` (aftgee),
    `test-zero-augmented-bootstrap-pval-min-fraction-usable-samples.R:36` and
    `test-zero-augmented-count-aliased-covariates-dropped-on-positive-rows.R:116` x4 (glmmTMB: the weighted
    Bayesian-bootstrap refits are NA without it), both legs: a Suggests package the hard-dependency-only images lack.
    Fixed by 8d4f8e87 with `skip_if_not_installed()` / `requireNamespace()` guards on those checks only. Verified with
    the CI's 32 missing Suggests packages hidden (a library of symlinks without them): named skips, the rest pass.
  - `test-zero-augmented-ridge-warm-start-and-zero-part-separation.R:310-311` (both legs; a real bug,
    platform-dependent): on the Poisson-like positive counts of the separated-hurdle fixture the zero-truncated
    negative-binomial count part of `InferenceCountHurdleNegBin` stops at an enormous theta (1.2e7 locally; 2e15 to
    6e15 when x1 is perturbed by 1e-12 relative, 2 of 300 perturbations) with `converged = TRUE` but no Poisson-boundary
    flag. There the C++ observed information is meaningless (entries ~1e26, negative definite), `ssq_b_j` came back
    negative, `try_hurdle_negbin_fit()` rejected the fit and `generate_mod()` fell back silently to the treatment-only
    model: estimate -0.028 instead of 0.015, and no separation flag because the treatment-only hurdle part is not
    separated. Not a threshold in the separation screen, and not caused by a commit between 8d8c5f78 and 8077aea1 (none
    touches this fit); where the optimizer stops at the boundary depends on the platform's floating point. Fix (R only,
    no rebuild): `hurdle_negbin_poisson_limit_information()` in `R/EDI/R/inference_count_hurdle.R`. When theta >= 1e4
    (`kNegBinPoissonBoundaryLogTheta`) and the reported information is not finite and positive definite, it uses the
    limit's information: the zero-truncated Poisson information of the count coefficients (count block of
    `get_zero_augmented_poisson_hessian_cpp()`), dispersion dropped, `dispersion_at_poisson_boundary = TRUE`. Fits with a
    usable information are returned unchanged (bit for bit). Test: `test-hurdle-negbin-poisson-limit-information.R`
    injects the bad kernel output so every platform runs the path; it fails without the fix (8 expectations). The
    perturbed repro now gives the covariate estimate and the warning. The count, hurdle, zero-augmented and ZINB/ZIP files
    in `tests/testthat` and 33 HurdleNegBin-related `testthat_bulk` files pass. Follow-up, not done: the C++ hessian of
    `TruncatedNegBinCount` at theta >> 1e7 cancels catastrophically; the kernel could flag the boundary itself.
  - `test-aa-fork-worker-count-invariance.R:87` (valgrind only): `InferenceContinOLS` BCa bootstrap CI at 2 fork workers
    `c(NA, NA)` (reason `bootstrap_ci_unavailable`, i.e. an error inside the parallel jackknife) while the serial CI is
    finite. Valgrind's exit reports show five pairs of fork workers in the test where two are expected, which fits
    `par_lapply()` losing its worker connections and rebuilding the cluster. Harness, not numerics: it passed under
    valgrind at 8d8c5f78 with no change to these paths since, and passes on ASAN/UBSAN (same R-devel image), on every
    other leg and locally (`_R_CHECK_LIMIT_CORES_` set). Fix: the test skips under valgrind (detected by its vgpreload
    `LD_PRELOAD`), with the reason in the test.
- [x] TODO-426 (added 2026-11-24, agent; done 2026-11-25, confirmed by the full run 45403920576 on 4e83509a, all 21 jobs green): **Full R-CMD-check run 45295584606: CRAN-extra nold, gcc16 and devel-devdeps
  failures.** All three legs failed the same way in every earlier full run since they were added (44358518303 on
  2026-11-18, 44903905332 on 2026-11-21); none has passed yet. None is a long-double or results problem.
  - [x] **nold** (workflow; fixed; passed in run 45403920576): the tests never ran. Loading `digest` failed with
    `unable to load shared object '.../digest/libs/digest.so': libc++.so.1: cannot open shared object file`. The leg
    restored the package cache that the clang23 leg saved: both are Ubuntu 26.04 R-devel 4.7.0, r-hub/actions/setup-deps
    gave both cache version "1" (the images' RHUB repo option was unset at run time), so their keys share a prefix and
    nold restored clang23's library, whose packages are built with `-stdlib=libc++`. Fix: the "Configure this leg" step
    of `R-CMD-check-cran-extra` in `.github/workflows/R-CMD-check.yaml` sets `R_LIBS_USER` to a per-leg path
    (`$HOME/R/rhub-<label>-library`); actions/cache restores only entries saved under the same paths.
  - [x] **gcc16** (C++; fixed; passed in run 45403920576): `R CMD check` WARNING at install, "significant warning"
    `emmintrin.h:135:24: array subscript 3 is outside array bounds of 'const {anonymous}::SM2 [1]' [-Warray-bounds=]`,
    inlined from `lmm_analytic_hessian` at `fast_gaussian_lmm.cpp:266` (`Xg^T * P` with `P` a 2x2-max-size dynamic
    matrix; GCC 16 -O3 vectorizes it into 2-double loads and cannot prove m <= 2). A false positive, but CRAN counts it.
    Fix: that product is built column by column as `sum_i P(i,j) * Xg.row(i)^T`. Verified: compiling
    `fast_gaussian_lmm.cpp` alone with g++-16 and the leg's flags (`-std=gnu++20 -O3 -Wall -pedantic
    -Wp,-D_FORTIFY_SOURCE=3 -fopenmp`) gave the warning before the edit and not after; a standalone Eigen check gives
    identical results (max difference 0) for m = 1, 2.
  - [x] **devel, devdeps** (workflow; outside the release gate; fixed; passed in run 45403920576): `fatal error:
    ../../contrib/Eigen/IterativeSolvers: No such file or directory`, from `RcppEigenForward.h:31`. Not upstream's bug:
    Eigen master renamed `unsupported/` to `contrib/` and left `unsupported/Eigen/*` as forwarding shims, and the
    workflow's Eigen-master overlay copied only `Eigen/` and `unsupported/Eigen/`. Fix: the overlay also copies
    `contrib/Eigen/` into the dev RcppEigen include directory.
- [x] TODO-427 (added 2026-11-24, agent; found by nightly run 45393057600 on 82ef6889): **Two new benchmark regressions:**
  `InferenceOrdinalOrderedProbitRegr` fit 0.37 -> 0.49 ms (`models-ordinal`) and the `InferenceContinOLS` randomization
  p-value at r = 1000, 32.2 -> 43.9 ms (`procedures`), both new since 38d1b90a.
  - Decided 2026-11-24 (owner): accept both and allowlist the rows; see [DECISION-v1.0.6-TODO-427](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-427).
  - DONE 2026-11-24: both rows in `R/benchmark/benchmark_regression_allowlist.csv`, citing this TODO.
- [x] TODO-428 (added 2026-11-24, agent; found by nightly run 45467685988 on a65304eb; done 2026-11-24): **The
  `InferenceContinOLS` randomization CI (r = 1000, test inversion) benchmark row regressed, 120 -> 198 ms vs v1.0.4**
  (ratios 1.66 and 1.40; at 82ef6889 the same row was slower in both comparisons but too noisy to fail). Owner chose
  to investigate before allowlisting. Cause: `rand_drop_realized_from_enumeration()` (264b95ec, v1.2.0-TODO-263,
  after v1.0.4) ran `colSums(abs(W - w))` over the whole n x r draw matrix before the O(1) tests that rule out an
  enumeration (no `m_mat`, r == choose(n, n_T)). For random draws those tests always fail, and the CI search calls it
  once per p-value evaluation, so the scan was 45% of the CI's time (profile at n = 1000, r = 1000,
  `load_all(compile = FALSE)`). Fix (`R/EDI/R/inference_all_abstract_rand.R`): the O(1) tests run first; they are
  conjunctive early returns, so no result can change. Measured: local median 576 -> 148 ms (noisy machine), the
  function gone from the profile, CI identical; the seven enumeration/realized-draw test files pass (651
  expectations). No allowlist row. Next largest cost (pre-existing, in v1.0.4 too): `stable_signature()`'s
  `serialize`, ~50% of what is left. Confirm on the next nightly's `procedures` job.
- [ ] TODO-429 (added 2026-11-25, agent; found by nightly run 45494402590 on cf2beb67): **`InferenceOrdinalStereotypeLogitRegr`
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

- [ ] TODO-430 (added 2026-11-25, agent, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 35, confirmation pending): **`InferenceContinQuantileRegr`: Wald CI undercovers the true estimand at power20, n = 200, prob_T 0.2.**
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
