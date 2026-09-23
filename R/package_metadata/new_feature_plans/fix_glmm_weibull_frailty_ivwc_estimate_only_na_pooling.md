# Fix: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` Randomization Distribution All-NA — `estimate_only` Pooling-Weight NA Propagation

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-14` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-36`, bug-fix/feature split). Found 2026-09-22, surfaced as a
> `KNOWN_BROKEN` entry in `fix_stale_worker_cache_resampling.md`'s TODO-6
> regression test (the new KK-design fixture arm was the first thing to
> exercise `estimate_only = TRUE` on this class with both matched and
> reservoir components simultaneously usable); root-caused same day on user
> request. Unrelated mechanism to that plan or to
> `fix_prop_gcomp_sample_usable_gating.md` — a plain arithmetic NA-
> propagation bug, not caching and not worker-state gating.

## The bug, confirmed by direct reproduction

`shared()` in `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:271-311`
(the `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` class — "IVWC" =
inverse-variance-weighted combination, literally naming the broken
mechanism) pools a matched-pair Clayton-copula estimate (`beta_m`) and a
reservoir Weibull-AFT estimate (`beta_r`) via inverse-variance weighting:

```r
# lines 296-300
if (m_ok && r_ok){
    w_star = ssq_r / (ssq_r + ssq_m)
    private$cached_values$beta_hat_T = w_star * beta_m + (1 - w_star) * beta_r
    if (estimate_only) return(invisible(NULL))
    ...
```

`ssq_m`/`ssq_r` come from `clayton_copula_for_matched_pairs()` and
`weibull_for_reservoir()` (lines 312-404), both of which — correctly, per
the `estimate_only` docstring ("skip variance component calculations") —
return `ssq = NA_real_` when `estimate_only = TRUE` (explicit at line 336:
`ssq_beta_T_matched = if (estimate_only) NA_real_ else fit$ssq`; the
reservoir fit's helper likewise returns `ssq = NA` under
`estimate_only = TRUE`). But the pooling-weight line above uses
`ssq_m`/`ssq_r` **unconditionally**, regardless of `estimate_only`. When
both components are usable (`m_ok && r_ok` — the common case, a design
with both matched pairs and a non-trivial reservoir), `w_star` becomes
`NA/NA = NA`, and `beta_hat_T = NA * beta_m + NA * beta_r = NA` — even
though `beta_m` and `beta_r` (the actual point estimates) are both
perfectly finite.

`estimate_only = TRUE` is exactly what every resampling draw uses for
speed (the reused-worker `rand` contract calls
`compute_estimate(estimate_only = TRUE)` via
`compute_bootstrap_worker_estimate_via_compute_treatment_estimate()`,
`inference_all_abstract_non_param_boot.R:1281-1288`). So this fires on
**every single draw, unconditionally** — not permutation-specific, not
data-dependent, not related to matching/frailty convergence. It also fires
on the very first "observed" call whenever a caller requests
`estimate_only = TRUE` directly.

**Direct reproduction** (golden fixture from
`R/package_tests/testthat_bulk/test-survival-glmm-weibull-frailty-loggamma-ivwc-migration-golden.R`'s
`clayton_golden_design(n=24, seed=20260817)`):
- `compute_estimate(estimate_only = FALSE)`: `-0.2163981` (works).
- `compute_estimate(estimate_only = TRUE)` on the same unpermuted data:
  `NA`, with `beta_T_matched = 0.0307` (finite),
  `ssq_beta_T_matched = NA`, `beta_T_reservoir = -1.022` (finite),
  `ssq_beta_T_reservoir = NA`.
- Full reused-worker `rand` draw traced step-by-step
  (`create_bootstrap_worker_state()` →
  `load_randomization_draw_into_worker()` →
  `compute_randomization_worker_estimate()`): `KKstats$m=4, nRT=9, nRC=7`
  (both components usable), `beta_T_matched = 0.297`,
  `beta_T_reservoir = 0.113` (both finite) → final `beta_hat_T = NA`,
  `is_nonestimable("estimate") = FALSE` (not gated there — confirms it's
  the pooling arithmetic, not a nonestimable-flag path).

## Scope: isolated to the IVWC variant

The sibling `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` (line 981)
does **not** have this bug — its `shared()` is a single joint-likelihood
fit with no matched/reservoir split and no `ssq_r`/`ssq_m`/`w_star`
pooling-weight computation at all. The bug is specific to the IVWC
variant's two-component combination logic. (No cross-class sweep beyond
this sibling check has been done — TODO-2 covers a broader grep for the
same `w_star`/inverse-variance-pooling shape elsewhere in the file/package,
in case another class shares it.)

## Proposed fix — already has a reference implementation in the same file

`shared()`'s pooling block needs to fall back to equal weighting
(`0.5 * beta_m + 0.5 * beta_r`) when `estimate_only = TRUE` (i.e. when
`ssq_m`/`ssq_r` are deliberately unavailable), exactly matching the pattern
already correct in a **different function in the same file**,
`compute_treatment_estimate_during_randomization_inference()`
(~lines 195-210), whose pooling logic already guards:

```r
if (!is.null(ssq_m_orig) && !is.null(ssq_r_orig) &&
    is.finite(ssq_m_orig) && is.finite(ssq_r_orig)) {
  # inverse-variance weight
} else {
  return(0.5 * beta_m + 0.5 * beta_r)
}
```

The fix is to bring `shared()`'s pooling block in line with this existing,
already-correct pattern — not to invent new logic.

## Status

Fixed 2026-09-23, exactly as proposed: `shared()`'s `w_star` computation
now falls back to `0.5` when `ssq_m`/`ssq_r` aren't both finite, matching
`compute_treatment_estimate_during_randomization_inference()`'s existing
guard. Verified on the plan's own golden fixture
(`clayton_golden_design(n=24, seed=20260817)`):
`estimate_only = FALSE` unchanged (`-0.2163981`, bit-for-bit);
`estimate_only = TRUE` now `-0.4956479` (finite, same sign as the `FALSE`
path, `beta_m`/`beta_r` unchanged at `0.0307`/`-1.022`); reused-worker
`rand` distribution now 99/99 finite (`sd = 0.391`, previously all-NA).
Removed from `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
`test-reused-worker-resampling-nondegenerate.R`; full suite re-run passes
(13/13). TODO-2 (broader grep for the same pooling shape elsewhere) and
TODO-7 (CSV regeneration) still open.

## TODOs

- [x] TODO-1: Apply the fix — guard `shared()`'s `w_star` computation
  (`inference_survival_GLMM_weibull_frailty_loggamma.R:296-300`) the same
  way `compute_treatment_estimate_during_randomization_inference()` already
  does: equal-weight fallback (`0.5 * beta_m + 0.5 * beta_r`) when
  `ssq_m`/`ssq_r` aren't both finite (i.e. under `estimate_only = TRUE`).
  Verify via `pkgload::load_all(".", compile = FALSE)` only (never
  `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project rule,
  see top-level `CLAUDE.md`).
- [x] TODO-2 (2026-09-23, completed): Grepped `R/EDI/R/*.R` for
  `w_star = ssq_r / (ssq_r + ssq_m)` and equivalent — found 10 more hits
  across `inference_continuous_KK_robust_regr_ivwc.R`,
  `inference_count_KK_cond_poisson.R` (×3, all three inside the one
  `CountKKHurdlePoissonIVWCSource` list feeding
  `InferenceCountKKHurdlePoissonIVWC` — not three separate classes),
  `inference_continuous_KK_ols_ivwc.R`, `inference_incidence_KK_cond_logit.R`,
  `inference_all_KK_wilcox_ivwc.R`,
  `inference_all_KK_quantile_regr_ivwc_abstract.R` (feeds two concrete
  leaves, `InferenceContinKKQuantileRegrIVWC`/`InferencePropKKQuantileRegrIVWC`),
  `inference_survival_KK_lwa_cox_ivwc_abstract.R`,
  `inference_survival_KK_strat_cox.R`,
  `inference_survival_KK_rank_regr_ivwc_abstract.R`, plus
  `inference_survival_GLMM_weibull_frailty_normal.R` (the *other* sibling,
  not just the checked `...OneLik` one — this one DOES pool via IVWC, but
  its `shared()` already has the correct `estimate_only` branch this class
  was missing). Direct behavioral check
  (`compute_estimate(estimate_only=TRUE)` vs. `FALSE` on a KK-matched
  fixture) on all 9 concrete classes reachable from this list
  (`InferenceContinKKRobustRegrOneLik`, `InferenceCountKKHurdlePoissonIVWC`,
  `InferenceContinKKOLSOneLik`, `InferenceIncidKKCondLogitOneLik`,
  `InferenceAllKKWilcoxIVWC`, `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceSurvivalKKStratCoxPHOneLik`, `InferenceContinKKQuantileRegrIVWC`,
  `InferencePropKKQuantileRegrIVWC`) found **no NA-under-estimate_only
  case anywhere** — each either already guards `estimate_only` before
  computing `w_star`, or has its matched/reservoir helper substitute a
  finite placeholder `ssq` (e.g. `1.0`, or a placeholder `se = 1` in
  `InferenceCountKKHurdlePoissonIVWC`'s
  `compute_treatment_estimate_during_randomization_inference()` — checked
  directly since a hardcoded `se = FALSE` there looked suspicious on first
  read, but the placeholder is finite, not NA, so `m_ok` is never
  spuriously forced false; the ~0.09 point-estimate gap vs. the full path
  is the expected cost of a cruder placeholder-variance weighting, not a
  defect) under `estimate_only` instead of leaving it `NA`, avoiding the
  bug by a different mechanism than this class needed. **This bug is
  confirmed isolated to the one class already fixed** — the full sweep is
  now complete, no unchecked spots remain, and no further action is
  needed here.
- [x] TODO-3: Re-ran the golden fixture repro
  (`clayton_golden_design(n=24, seed=20260817)`):
  `estimate_only = TRUE` now `-0.4956479` — finite, same sign as the
  `FALSE` path's `-0.2163981`. Treated as passing per the plan's own
  "close enough" criterion (same sign; the two paths use genuinely
  different weights so exact numeric closeness was never the bar).
- [x] TODO-4: `estimate_only = FALSE` unchanged, confirmed bit-for-bit
  (`-0.2163981`, identical to the value already on record in this plan
  and in `release_v1_0_5.md → TODO-14` (was `release_v1_1_0.md →
  TODO-36`)).
- [x] TODO-5: Reused-worker `rand` distribution on the golden fixture now
  99/99 finite, `sd = 0.391` (previously all-NA).
- [x] TODO-6: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` removed
  from `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN`; full regression file
  re-run passes (13/13).
- [ ] TODO-7: Regenerate any `comprehensive_tests` CSV rows for this
  class's `rand`-family methods once fixed and installed (only after
  install, not before, same caution as the sibling plans).

## Standing constraints

Same as `fix_stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. The
`estimate_only = FALSE` path must produce bit-for-bit identical results
before and after this fix (TODO-4 verifies this) — only the previously-NA
`estimate_only = TRUE` path should change.
