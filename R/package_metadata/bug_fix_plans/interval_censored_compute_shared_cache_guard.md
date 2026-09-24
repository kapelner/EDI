# Interval-Censored Log-Rank/Gehan: `compute_shared_icen()` Blanket Cache Guard Leaves `s_beta_hat_T` Unset

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-34`. Added 2026-09-24
> from the test-comment audit: "Confirmed source bug, NOT fixed here" in
> `test-survival-logrank-gehan-interval-censored-compute-shared-icen-vs-ictest-reference.R`,
> pinned as current (buggy) behavior. Same family as the stale-cache plans
> (`stale_worker_cache_resampling.md`, `cox_risk_set_cache_staleness.md`):
> a memoization guard keyed on too little.

## The finding

`compute_shared_icen()`'s third cache guard,
`if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))`,
fires whenever `beta_hat_T` is already cached, regardless of the
`estimate_only` flag. Unlike the right-censoring `compute_shared()`, it has
no such blanket guard. So once `compute_estimate(estimate_only = TRUE)` has
cached `beta_hat_T` under general (interval) censoring, a later full call
never computes `s_beta_hat_T`, and `compute_asymp_confidence_interval()`
crashes with "missing value where TRUE/FALSE needed" on
`!is.finite(private$cached_values$s_beta_hat_T)`.

Affects `InferenceSurvivalLogRank` and `InferenceSurvivalGehanWilcox` under
general censoring (and any class sharing that method; the sweep is TODO-2).

## Items

- [ ] **TODO-1: Fix the guard** to short-circuit only when the cached value
  satisfies the requested `estimate_only` (mirror `compute_shared()`).
- [ ] **TODO-2: Sweep** every `*_icen` / general-censoring `compute_shared`
  variant for the same blanket guard.
- [ ] **TODO-3: Flip the pinned test** to assert that a full call after an
  `estimate_only` call yields a finite SE and a working asymptotic CI.
- [ ] **TODO-4: Regression test** in the structural gate suite (an
  `estimate_only`-then-full call ordering check across the general-censoring
  classes), since this bug is order-dependent and easy to miss.
