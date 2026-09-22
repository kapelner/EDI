# Fix: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` Randomization Distribution All-NA — `estimate_only` Pooling-Weight NA Propagation

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_1_0.md → TODO-36`. Found 2026-09-22, surfaced as a
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

## TODOs

- [ ] TODO-1: Apply the fix — guard `shared()`'s `w_star` computation
  (`inference_survival_GLMM_weibull_frailty_loggamma.R:296-300`) the same
  way `compute_treatment_estimate_during_randomization_inference()` already
  does: equal-weight fallback (`0.5 * beta_m + 0.5 * beta_r`) when
  `ssq_m`/`ssq_r` aren't both finite (i.e. under `estimate_only = TRUE`).
  Verify via `pkgload::load_all(".", compile = FALSE)` only (never
  `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project rule,
  see top-level `CLAUDE.md`).
- [ ] TODO-2: Grep the file (and package) for the same
  `w_star`/inverse-variance-pooling shape to confirm no other function or
  class shares this exact NA-propagation bug (the investigation checked
  only the one sibling class, `...OneLik`, which uses a structurally
  different single-fit estimator and is not affected).
- [ ] TODO-3: Re-run the golden fixture repro from this plan
  (`clayton_golden_design(n=24, seed=20260817)`,
  `compute_estimate(estimate_only = TRUE)`) and confirm it now returns a
  finite value close to the `estimate_only = FALSE` result (`-0.2164`) —
  the equal-weight fallback won't be numerically identical to the
  inverse-variance-weighted `FALSE` path, so define what "close enough"
  means before treating this as passing (e.g. same sign, same order of
  magnitude, or compare against a small-`n` case where `w_star` is close to
  0.5 anyway so the two paths nearly coincide).
- [ ] TODO-4: Confirm the standing-constraint discipline this plan's sibling
  fixes used: does `estimate_only = FALSE`'s result change at all? It
  should not — the fix only touches the `estimate_only = TRUE` branch.
- [ ] TODO-5: Re-run the reused-worker `rand` distribution for this class
  (the golden fixture, `r` small) and confirm it's now non-degenerate
  (`sd() > 0`), matching `fix_stale_worker_cache_resampling.md`'s TODO-5/6
  verification style.
- [ ] TODO-6: Remove
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` from
  `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
  `R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R` once
  fixed — the test's `expect_identical` against that list will fail loudly
  if this isn't done, forcing the update.
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
