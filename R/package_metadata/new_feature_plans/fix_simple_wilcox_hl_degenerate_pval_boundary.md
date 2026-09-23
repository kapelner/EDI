# Fix: `InferenceAllSimpleWilcox` Resampling-Family p-Values Collapse to 1 — Hodges-Lehmann Estimator Ties at Zero

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-17`. Found 2026-09-23, surfaced by the new
> `pval_miscalibration` audit check's extreme-violation triage (ACAT-
> combined p as low as 2.5e-300, see
> `fix_stale_worker_cache_resampling.md`'s audit-tooling work); root-caused
> same day. **This is a resurfacing of an already-partially-fixed bug**:
> the Wald-family variant of this exact mechanism, in this same file, was
> already found and fixed 2026-09-06 (`inference_all_simple_wilcox.R:119-131,
> 141-151`) — the resampling-family methods were simply never touched by
> that fix and still carry the identical defect.

## The bug, confirmed by direct reproduction

`InferenceAllSimpleWilcox`'s point estimate is the Hodges-Lehmann location
shift (median of all pairwise treatment-minus-control differences,
`inference_all_simple_wilcox.R:250-278`). On heavily-tied, small-integer
count/ordinal data, this median frequently lands on **exactly 0** (many
pairwise differences tie at 0).

`compute_rand_two_sided_pval` delegates to the generic randomization
p-value formula (`inference_all_abstract_rand.R:317`):
```r
p = min(1, max(2/n, 2 * min(mean(t0s >= t), mean(t0s <= t))))
```
When the observed statistic `t` is exactly 0 — the same degeneracy that
afflicts the null-distribution draws `t0s` too, since they're computed on
permutations of the identical tied data — both tail proportions
`mean(t0s >= 0)` and `mean(t0s <= 0)` collapse toward 1, so
`2 * min(~1, ~1)` saturates the `min(1, ...)` clamp and returns exactly
`p = 1`. The same underlying mechanism (not the same code path) drives the
bootstrap-family methods (`compute_bootstrap_two_sided_pval_studentized`/
`_symmetric`, `compute_m_out_of_n_bootstrap_two_sided_pval`,
`compute_subsampling_two_sided_pval`) — all built on the same HL point
estimate.

**Direct reproduction confirms this exactly**: 25 fresh true-null `count`
datasets (Poisson(2), n=60): `beta_hat_T == 0` in 80% of reps, and **every
single one of those (100%) produced `compute_rand_two_sided_pval() == 1`
exactly**. Matches the historical audit's 80-99.6% p=1 rates precisely
(e.g. `compute_bootstrap_two_sided_pval_studentized`: 504 pooled rows,
only 3 distinct p-values, 99.6% exactly `p=1`).

## Not the stale-cache bug, not a fast-path bug — ruled out directly

`shared()` (`:299-352`) guards on the standard `beta_hat_T`/`s_beta_hat_T`
keys, already correctly reset by every loader this session's cache fix
touched — this class was correctly in scope for that fix's sweep and is
unaffected by it. `compute_fast_randomization_distr` (`:287-298`) is a
dedicated vectorized C++ kernel
(`compute_wilcox_hl_distr_parallel_cpp`), not the reused-worker
`cached_values` path at all — so this is not the same shape of bug as
`InferencePropGCompMeanDiff`'s fast-path-never-adapted defect either.

## Not new — the Wald-family half of this exact bug was already fixed

Lines 119-131 and 141-151 of `inference_all_simple_wilcox.R` (dated
2026-09-06) explicitly document fixing the **identical** HL-degenerates-to-0
mechanism for `compute_wald_two_sided_pval`/
`compute_wald_confidence_interval` ("Wald statistic came out exactly
0/se=0... observed: pinned at 1 in ~75-98% of runs"). That fix only
covered the Wald-family delegation; the resampling-family methods (`rand`,
`bootstrap*`, `m_out_of_n_bootstrap`, `subsampling`) were never touched and
still carry the same defect.

## Sibling classes not affected — confirmed empirically

Same 25-rep test on `InferenceAllSimpleAverageDiff` (4% `beta_hat_T==0`, 8%
`p==1`) and `InferenceAllSimpleMeanDiffPooledVar` (4%/4%) — both
near-nominal. They use a mean-difference estimator, which essentially
never lands exactly on 0 for arithmetic reasons a median-of-ties estimator
does. Confirms this is specific to the Hodges-Lehmann estimator, not a
shared mixin issue.

## Proposed fix — two options

**Option A (recommended) — mid-p / tie-splitting correction.** The
standard textbook fix for a permutation statistic landing exactly on a
boundary/mode of its own null distribution:
```r
p = min(1, 2 * min(
  mean(t0s > t) + 0.5 * mean(t0s == t),
  mean(t0s < t) + 0.5 * mean(t0s == t)
))
```
This is likely a fix to the **generic** `compute_rand_two_sided_pval`/
bootstrap-family formula (shared machinery), not something patched only in
this class's file — worth checking whether other classes with discrete or
tie-prone statistics could hit the same boundary-collapse pattern on
sufficiently tied data, in which case the generic fix protects all of
them, not just this one.

**Option B — route resampling-family methods through
`stats::wilcox.test()`'s own rank-based p-value machinery**, mirroring how
the Wald-family fix (2026-09-06) moved away from the naive HL-point-
estimate-based formula. Narrower, more class-specific, doesn't generalize
to other classes that might share the generic-formula boundary problem.

Not yet decided/reviewed — flagged here, not fixed.

## TODOs

- [ ] TODO-1: Confirm the trace above with a direct repro:
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, see top-level `CLAUDE.md`).
  Reproduce on both `count` and `ordinal` response types (the class is
  response-type-generic — confirm which types it actually supports).
- [ ] TODO-2: Check whether the generic `compute_rand_two_sided_pval`/
  bootstrap-family p-value formulas (`inference_all_abstract_rand.R:317`
  and the bootstrap-family equivalents) are shared by other classes with
  discrete or tie-prone point estimates (e.g. exact/rank-based methods)
  that could hit the same boundary-collapse pattern on sufficiently tied
  data — this determines whether Option A's fix belongs in the generic
  formula (protects everyone) or needs to stay class-scoped.
- [ ] TODO-3: Implement Option A (or B if TODO-2 finds a reason A is
  unsafe generically — e.g. it changes results for currently-correct,
  non-degenerate cases in a way that needs its own verification pass).
- [ ] TODO-4: Verify the fix doesn't change p-values for the
  non-degenerate case (`t != 0`, no boundary collapse) — bit-for-bit or
  within floating-point tolerance, since the mid-p correction should be a
  no-op when `mean(t0s == t)` is 0 or negligible.
- [ ] TODO-5: Re-run the true-null repro (25+ reps, `count` and `ordinal`)
  and confirm the resampling-family methods' rejection rate returns to
  nominal ~5% even conditional on `beta_hat_T == 0` draws, not just
  unconditionally.
- [ ] TODO-6: Add a permanent regression test (same style as
  `fix_stale_worker_cache_resampling.md`'s TODO-6) that constructs a
  heavily-tied fixture forcing `beta_hat_T == 0` and confirms the
  resampling-family p-value is NOT pinned at exactly 1 across repeated
  draws — this general shape (boundary-collapse under ties) wasn't caught
  by the existing non-degeneracy test either, since that test checks for a
  constant distribution, not a distribution collapsed onto one specific
  value with only a handful of others present.
- [ ] TODO-7: Regenerate the affected `comprehensive_tests` CSV rows for
  `InferenceAllSimpleWilcox`'s resampling-family methods once fixed and
  installed (only after install, not before, same caution as the sibling
  plans this session produced).

## Standing constraints

Same as `fix_stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. The
non-degenerate case's p-values must not change (TODO-4 verifies this) —
only the previously-pinned-at-1 boundary case should change.
