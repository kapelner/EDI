# KKQuantileRegrOneLik Randomization CI: Missing Composition Hooks

> **Depends on:** none (touches `InferenceExtQuantileRandCI$compute_rand_confidence_interval()`
> in `inference_ext_quantile_rand_ci.R` and the `KKQuantileRegrOneLik` component in
> `inference_all_KK_quantile_regr_one_lik_abstract.R`); independent of
> `incidence_randomization_cis.md` and `randomization_ci_construction_audit.md` --
> same *symptom family* (a randomization CI silently reporting a wrong-but-
> plausible-looking answer instead of erroring) but a different *mechanism*
> (missing component hooks, not a scale/parameterization mismatch). Slated for
> **v1.0.5** (`release_v1_0_5.md → TODO-7`, moved 2026-09-23 from
> `release_v1_1_0.md → TODO-25`, bug-fix/feature split; user decision,
> 2026-09-17).

## Status

**Randomization confidence intervals are hard-disabled for
`InferenceContinKKQuantileRegrOneLik` and `InferencePropKKQuantileRegrOneLik`**
(`compute_rand_confidence_interval()` throws immediately for these two classes,
per user decision 2026-09-17) as an emergency stopgap, same pattern as
`incidence_randomization_cis.md`'s stopgap. `compute_rand_two_sided_pval()` is
untouched and still works -- it uses a completely different, unrelated code
path (see Root cause) and was already confirmed correct by the audit that
found this bug (zero p-value-range anomalies across ~3.97M audited rows).
`compute_estimate()` and every other CI/pval method on these two classes are
unaffected.

## Symptom (2026-09-16/17, found via a raw `comprehensive_tests_results_nc_1_*.csv`
results audit, not a user report)

Across every audited row for `InferenceContinKKQuantileRegrOneLik` (1,180 rows,
`compute_rand_confidence_interval`, `status == "ok"`) and
`InferencePropKKQuantileRegrOneLik` (464 finite-result rows out of 507; the
remaining ~8.5% returned `NA`/`NA`), the returned interval was **exactly the
point estimate on both bounds** (`result_1 == result_2`, zero width) 100% of
the time. Empirical coverage of the true value
(`mean(beta_T_in_confidence_interval)`) was **~0-1%** against the ~95% nominal
target -- confirmed against raw rows, not just the aggregate:

```
   beta_T result_1 result_2 beta_T_in_confidence_interval status
1:      0    0.212    0.212                         FALSE     ok
2:      0    0.038    0.038                         FALSE     ok
3:      0    0.112    0.112                         FALSE     ok
...
```

Other CI methods on the same classes (`compute_asymp_confidence_interval`,
`compute_wald_confidence_interval`) sit at ~93.7% coverage -- unaffected.

## Root cause

`InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
compose `KKQuantileRegrOneLik` (+ `BayesianBootstrap`, `Wald`;
`inference_continuous_KK_quantile_regr_one_lik.R:60`,
`inference_proportion_KK_quantile_regr_one_lik.R`), which itself depends on
`c("KKCompound", "QuantileRandomizationCI")`
(`inference_all_KK_quantile_regr_one_lik_abstract.R:24`).

`QuantileRandomizationCI` (= `InferenceExtQuantileRandCI`,
`inference_ext_quantile_rand_ci.R`) implements
`compute_rand_confidence_interval()` via Zhang's test-inversion bisection
(`ci_exact_zhang_combined()` → `zhang_bisect_ci_boundary()`,
`inference_helpers_zhang.R:44-71`). Its `p_fn(delta_0)` calls
`private$compute_rand_pval_matched_pairs(delta_0)` /
`private$compute_rand_pval_reservoir(delta_0)` -- methods it expects its
**host** to supply.

**`KKQuantileRegrOneLikSource`
(`inference_all_KK_quantile_regr_one_lik_abstract.R:63-353`) never defines
either method** (nor their `qr_intercept_pairs`/`qr_trt_coef_reservoir`
helpers). Confirmed at runtime against an actual instantiated object:

```r
inf = InferenceContinKKQuantileRegrOneLik$new(des)
is.function(inf$.__enclos_env__$private$compute_rand_pval_matched_pairs)  # FALSE
is.function(inf$.__enclos_env__$private$compute_rand_pval_reservoir)      # FALSE
```

So `p_fn(mid)` throws `"attempt to apply non-function"` on every call.
`zhang_bisect_ci_boundary()` swallows this via
`tryCatch(p_fn(mid), error = function(e) NA_real_)`, then
`if (is.na(p_mid)) p_mid = 0`. A p-value of exactly 0 is always `<= alpha`, so
the bisection treats every midpoint as significant/rejected: `outside`
collapses toward `inside` (seeded at the point estimate) on every one of the
loop's up to 50 iterations, converging both bounds onto the point estimate --
exactly the observed zero-width result.

**Contrast with the working sibling.** `InferenceContinKKQuantileRegrIVWC`
*does* define these methods
(`inference_all_KK_quantile_regr_ivwc_abstract.R:336,364,400,421`) and
produces a real, non-degenerate interval on the same dataset (width 2.26 vs.
0 for OneLik in a direct side-by-side run).

**Why the fix isn't "reuse IVWC's methods."** IVWC's
`compute_rand_pval_matched_pairs`/`compute_rand_pval_reservoir` run *separate*
permutation tests on matched-pair-difference rows vs. reservoir rows
(consistent with IVWC's split-then-combine "inverse-variance-weighted
combination" design). OneLik's estimator is structurally different: a single
**stacked** joint quantile regression fit jointly over both data sources in
one `quantreg::rq()` call
(`shared_combined_likelihood()`,
`inference_all_KK_quantile_regr_one_lik_abstract.R:182-269`). Testing OneLik's
point estimate against IVWC's split-model null would test the wrong null
hypothesis relative to what `compute_estimate()` actually estimates for this
class. The would-be analogous sibling with the same "OneLik: one stacked fit"
pattern, `InferenceContinKKOLSOneLik`
(`inference_continuous_KK_ols_one_lik.R:609`), doesn't compose
`QuantileRandomizationCI` at all -- it has no existing stacked-model
randomization-CI pattern to copy either.

## Why this was never caught

- The existing migration golden test
  (`test-kk-quantile-regr-onelik-migration-golden.R:162-174`,
  `"InferenceContinKKQuantileRegrOneLik randomization CI matches"`) only
  asserts the migrated class's CI equals a reconstructed "Legacy" R6 class's
  CI to `tolerance = 1e-6` -- and that Legacy class is built from the *same*
  `EDI:::InferenceAbstractQuantileRandCI`/`KKQuantileRegrOneLikSource$public/private`
  objects as the migrated one (see that file's header comment on why: a
  faithful golden reconstruction of the pre-migration R6 inheritance chain,
  not an independently-sourced reference implementation). Both sides call
  into the identical broken engine, so both sides are identically degenerate
  and the test passes.
- Nothing previously checked CI *width* or *empirical coverage* -- only that
  results were internally consistent (in range, ordered, matching a
  parallel implementation). `check_anomalies.R`'s own pre-existing checks
  (p-value range, CI order, extreme width, extreme estimate) are all
  satisfied by a zero-width interval sitting exactly on a finite point
  estimate -- none of them test coverage against the ground-truth `beta_T`
  a simulation study already carries. The coverage check that caught this
  (category 5 in `check_anomalies.R`, `coverage < 0.70`) exists in that
  script but had apparently never been run over the full raw
  `comprehensive_tests_results_nc_1_*.csv` files before 2026-09-16/17 --
  only smaller/filtered subsets.
- `zhang_bisect_ci_boundary()`'s `tryCatch(..., error = function(e) NA_real_)`
  followed by `if (is.na(p_mid)) p_mid = 0` treats *any* p-value-computation
  failure (a genuinely inestimable p-value at that `delta_0`, vs. a hard
  composition error) identically -- both quietly steer the bisection instead
  of surfacing a diagnosable error. This masking is legitimate for the
  incidence Zhang path's own `NA` semantics (`p_M`/`p_R` genuinely absent
  when `m == 0` or `nRT/nRC == 0` is a normal, expected outcome there) but
  turned a "these methods don't exist" *programming* error into silent,
  plausible-looking wrong output here.

## Remediation options

1. **Stop composing `QuantileRandomizationCI`'s CI for OneLik; let
   `compute_rand_confidence_interval` fall through to the generic
   `InferenceRandCI` bisection instead.** `KKQuantileRegrOneLikSource`
   already implements the hooks the *generic* (non-Zhang) randomization
   machinery needs: `compute_treatment_estimate_during_randomization_inference`
   (`inference_all_KK_quantile_regr_one_lik_abstract.R:152-155`) and
   `compute_fast_randomization_distr`
   (`inference_all_KK_quantile_regr_one_lik_abstract.R:156-158`, delegating to
   `compute_fast_randomization_distr_via_reused_worker`). These are exactly
   the hooks the generic `InferenceRandCI`/`InferenceRand` bisection
   (`inference_all_abstract_rand_ci.R`, used by every non-incidence,
   non-quantile response type) needs from a host to invert
   `compute_rand_two_sided_pval()` at each candidate `delta` using the host's
   *own* point estimate under permuted assignments -- genuinely
   estimand-correct by construction for the stacked model, no bespoke math
   required. `compute_rand_two_sided_pval` is already pinned from
   `InferenceRand$public_methods$compute_rand_two_sided_pval`
   (`inference_continuous_KK_quantile_regr_one_lik.R:92`) and already works
   (confirmed by the audit: zero p-value-range anomalies for these classes).
   Concretely: drop `QuantileRandomizationCI` from
   `KKQuantileRegrOneLik`'s `dependencies` (or otherwise stop routing
   `compute_rand_confidence_interval` there), and remove
   `"compute_rand_confidence_interval"` from the leaf classes'
   `overrides$public` list so the generic mixin's version wins instead of a
   collision. **Likely the cheap, largely-already-working fix** -- but
   unverified: needs to actually run and be checked against a Wald CI for
   plausibility and a coverage simulation before trusting it, since "the
   hooks exist" is necessary but not sufficient evidence the generic
   bisection behaves correctly end-to-end for this class (no smoke test has
   ever exercised this combination).
2. **Real bespoke fix: a stacked-model Zhang-style permutation test.**
   Generalize `compute_rand_pval_matched_pairs`/`compute_rand_pval_reservoir`
   for OneLik's stacked model: permute the treatment assignment within
   `KKstats` and refit the *single* stacked check-function loss under the
   null-shifted response (mirroring `shared_combined_likelihood()`'s own
   stacking, not IVWC's split-then-Fisher-combine), producing one exact (or
   Monte-Carlo permutation) p-value per `delta_0` directly from the stacked
   fit rather than combining two component p-values. Preserves Zhang's
   *exactness* (no generic Monte Carlo bisection precision questions,
   `randomization_ci_search_precision.md`'s open track) at the cost of real
   new derivation and implementation work -- and needs its own validation
   against a brute-force/simulation check the way the existing exact
   kernels presumably went through (see
   `incidence_randomization_cis.md`'s TODO-3 for the same caveat on a
   sibling problem).
3. **Do nothing beyond the stopgap; leave both classes' rand CI permanently
   unsupported.** Cheapest option. These two classes already have a
   parametric Wald CI and a bootstrap CI (`slow_methods` in
   `path_audits_source.R` already flags the bootstrap CI as slow for both);
   randomization inference is not these classes' only CI story. Worth
   considering if option 1 turns out not to check out empirically and
   option 2's cost isn't justified by demand.

**No option has been chosen yet.** Option 1 is the natural first thing to try
given how much machinery is already in place -- if it validates cleanly, it
may make option 2 unnecessary.

## Implementation TODOs

1. **Decision:** try option 1 first (cheap validation of already-composed
   machinery); fall back to option 2 or 3 depending on what that validation
   shows.
2. If option 1: make the composition change, then verify end-to-end --
   `compute_rand_confidence_interval()` returns a non-degenerate interval,
   roughly overlapping that class's own Wald CI on a handful of datasets, and
   a coverage simulation (many reps, one design/formula) lands near the
   nominal 95% (not just "not exactly 0%"). Add the regression test from
   TODO-3 either way.
3. **Regression test that would have caught this bug** (applies to any
   option chosen): assert `compute_rand_confidence_interval()` returns a
   *non-degenerate* interval (`result[2] > result[1]` beyond floating-point
   tolerance) for both classes, and that a small coverage simulation (e.g.
   50-100 reps) lands within a wide sanity band of 95% (not a tight bound --
   just enough to catch "collapsed to zero width" again). The existing
   migration golden test's CI comparison
   (`test-kk-quantile-regr-onelik-migration-golden.R:162-174`) should also be
   revisited: it will keep passing unless its own "Legacy" reconstruction
   stops sharing the same underlying (fixed) engine, so it's not a
   substitute for this new test.
4. If option 2: derive the stacked-model exact/permutation shift model and
   validate it against a brute-force check for a small `n` before trusting
   any C++ kernel, same caveat as `incidence_randomization_cis.md`'s TODO-3.
5. Once a real fix ships: remove this plan's stopgap `stop()` in
   `InferenceExtQuantileRandCI$compute_rand_confidence_interval()`
   (`inference_ext_quantile_rand_ci.R`), remove the two
   `not_implemented_methods` entries in `path_audits_source.R`'s
   `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
   rows, and regenerate `path_audits.html`. Re-run the TODO-3 regression test
   to confirm it now passes for real.
6. Cross-reference this plan from `release_v1_1_0.md`/`_master.md` (done,
   `TODO-25`).

## Testing/verification plan

- The TODO-3 regression test (non-degenerate width + coverage sanity check)
  is the load-bearing test -- it directly encodes "this bug cannot silently
  reappear," the same way `incidence_randomization_cis.md`'s analogous TODO
  does for its own bug.
- Whichever option ships, spot-check against the audit's original numbers:
  refit `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
  many times on one shared design/formula and confirm empirical coverage is
  no longer ~0-1% (roughly near 95%, not exact -- Monte Carlo noise at
  realistic rep counts).
- No change expected outside these two classes' `compute_rand_confidence_interval`
  -- `compute_rand_two_sided_pval`, every other CI method on these classes,
  and `InferenceContinKKQuantileRegrIVWC`/`InferencePropKKQuantileRegrIVWC`
  (which already supply the Zhang hooks correctly) are unaffected by both the
  stopgap and the eventual real fix.
