# Fix: `InferenceAllSimpleWilcox` Resampling-Family p-Values Collapse to 1 — Hodges-Lehmann Estimator Ties at Zero

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-17`. Found 2026-09-23, surfaced by the new
> `pval_miscalibration` audit check's extreme-violation triage (ACAT-
> combined p as low as 2.5e-300, see
> `stale_worker_cache_resampling.md`'s audit-tooling work); root-caused
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

## Update 2026-09-24: the same HL-ties-at-zero mechanism ALSO breaks CI coverage, not just p-values

Surfaced by the new `low_coverage` audit check (two-sided exact-binomial
test, H0: coverage=0.95): `InferenceAllSimpleWilcox` shows ~48-57%
coverage (target 95%) across `compute_bootstrap_confidence_interval_basic`
(n=570), `compute_bootstrap_confidence_interval_studentized` (n=552,
n=130), and `compute_subsampling_confidence_interval` (n=130).

Traced directly, high confidence — **same root cause as the p-value
bug above, a second downstream symptom, not a separate mechanism**:
`compute_bootstrap_confidence_interval(type="basic")` calls
`private$ci_from_boot_distribution(boot_distr, alpha, "basic", est=est)`
→ `bootstrap_ci_from_distribution()` (`helper_bootstrap_ci.R:5-20`),
whose `"basic"` formula is `2*est - quantile(boot_distr, c(1-alpha/2,
alpha/2))`. `boot_distr` is built by
`approximate_bootstrap_distribution_beta_hat_T()`, which re-invokes
`compute_bootstrap_worker_estimate()` per with-replacement draw
(`inference_all_abstract_non_param_boot.R:1124`) — i.e. re-runs the
identical tie-prone HL statistic on each resampled (duplicate-containing)
dataset. Since with-replacement resampling of already-tied, small-integer
data reproduces the same zero-collapse property that makes the point
estimate land on exactly 0, `boot_distr` piles up heavily at 0 (or a
narrow discrete set), making `quantile()`'s spread artificially narrow —
directly producing an over-narrow, mis-centered CI. Same applies to
`compute_subsampling_confidence_interval` via the identical distribution-
generating call.

**This does not need a separate plan file or separate fix** — it's the
same estimator degeneracy (Option A/B above), just a second symptom to
verify against. TODO-4 and TODO-6 below are updated accordingly.

## `InferenceAllSimpleMeanDiffPooledVar` — separate, partially-confirmed finding, tracked here rather than a new plan

Also surfaced by the coverage audit: ~55% coverage on
`compute_bayesian_bootstrap_confidence_interval_basic` (n=202). This class
does **NOT** share Wilcox's HL-ties mechanism (confirmed: mean-difference
estimators essentially never land exactly on 0) — investigated
independently.

**A real, independently-confirmed bug was found, but it does not appear
to explain the specific flagged symptom.** Live introspection
(`InferenceAllSimpleMeanDiffPooledVar$public_methods$compute_estimate_with_bootstrap_weights`)
confirms this class's Bayesian-bootstrap weighted estimator is
**bit-for-bit identical to `InferenceAllSimpleAverageDiff`'s Welch
(unequal-variance) formula** (`s_T_sq + s_C_sq`, unpooled, Satterthwaite-
Welch df) — not its own documented **pooled**-variance formula
(`s_p^2 = ((n_T-1)s_T^2+(n_C-1)s_C^2)/(n_T+n_C-2)`) that
`compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`
correctly use. `overrides$public` in
`inference_all_simple_mean_diff_pooled_var.R:203-225` *declares*
`compute_estimate_with_bootstrap_weights` as overridden for this class,
but no such override actually exists in the file (only `initialize`/
`compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval` are
defined) — it silently falls through to the generic Welch-based
component. Real inconsistency: asymptotic inference uses pooled variance,
resampling-based inference uses Welch, for the same nominally-"pooled-
variance" class.

**However**: the flagged method, `compute_bayesian_bootstrap_confidence_interval_basic`,
is a `"basic"` percentile-type bootstrap CI, built purely from
`2*est - quantile(boot_distr, ...)` (same formula traced for Wilcox
above) — it **never consumes the per-replicate SE at all**. So the
Welch/pooled inconsistency is real and independently worth fixing (it
would bite `studentized`/`symmetric-percentile-t`-type CIs, which DO read
`s_beta_hat_T`), but it does NOT explain the `"_basic"` coverage finding
specifically. What actually explains `"_basic"` undercoverage for this
class is unknown — candidates not yet checked:
`expand_subject_or_block_weights_to_row_weights()` (the Dirichlet/
bootstrap-weight generation itself, shared with the whole
`BayesianBootstrap` component — if buggy there, a much broader
shared-machinery finding, not PooledVar-specific), or a live reproduction.

## Cross-validation against the fresh full-package audit run, 2026-09-24

A fresh `audit_comprehensive_results.R` run (first pass against the
`low_coverage` check since it was added, post stale-row-pruning) surfaced
39 combined new findings for these two classes (22 Wilcox, 17
MeanDiffPooledVar) never before baselined. Cross-checked against this
file's existing analysis:

**Confirms the existing findings (same mechanism, still real):**
- `InferenceAllSimpleWilcox`'s bootstrap-family CIs (`compute_bootstrap_confidence_interval`/`_basic`/`_studentized`/`_bca`,
  `compute_m_out_of_n_bootstrap_confidence_interval`,
  `compute_subsampling_confidence_interval`) show UNDER-coverage
  (0.84-0.93 across continuous/count/proportion) — same direction, same
  HL-ties-at-zero mechanism already root-caused above. Magnitude is less
  severe than the ~48-57% cited above (likely because this run is against
  a larger/different post-pruning row set — direction and mechanism
  match, not a discrepancy worth chasing).
- `InferenceAllSimpleMeanDiffPooledVar`'s `compute_bayesian_bootstrap_confidence_interval_studentized`
  shows UNDER-coverage (0.850, continuous, n=2346) — same component
  (`BayesianBootstrap`) as the already-flagged `_basic` finding (TODO-9,
  still open/unexplained), consistent with a shared-machinery issue in
  that component, not resolving TODO-9 but confirming it's still live.

**NOT explained by the existing writeup — genuinely new, unconfirmed:**
- Both classes show mild but real OVER-coverage (0.96-0.995) on
  `compute_asymp_confidence_interval`/`compute_wald_confidence_interval`/
  `compute_rand_confidence_interval`/the `compute_rand_bootstrap_confidence_interval*`
  family. These are NOT with-replacement-bootstrap-of-tied-data paths (asymp/wald
  are closed-form; `rand`/`rand_bootstrap` permute rather than resample
  with replacement) — the HL-ties-at-zero mechanism explains
  under-coverage from an artificially narrow `boot_distr`, not
  over-coverage from a different code path entirely. This is a
  genuinely separate, unexplained pattern, not investigated further here.
- `InferenceAllSimpleMeanDiffPooledVar`'s `compute_wald_confidence_interval`
  shows a striking response-type-dependent DIRECTION FLIP: OVER-coverage
  (0.962) on `continuous`, but UNDER-coverage (0.862) on `count` — same
  function, opposite miscalibration direction depending on response type.
  Not explained by anything in this file; worth its own look.
- `InferenceAllSimpleMeanDiffPooledVar ~ compute_jackknife_wald_confidence_interval`
  shows UNDER-coverage (0.892, continuous) — raises a possible connection
  to `release_v1_0_5.md`'s `TODO-29` (`InferenceAllSimpleAverageDiff`'s
  separate, also-unexplained `jackknife_wald` coverage finding) — two
  sibling "AllSimple" classes both showing `jackknife_wald` problems is
  suggestive of a shared mechanism in whatever jackknife-Wald machinery
  they share, but NOT confirmed — flagging the connection, not claiming it.

**Net**: roughly half of the 39 new findings (the bootstrap-family/
Bayesian-bootstrap-studentized undercoverage, ~18-20 of 39) are explained
by mechanisms already documented in this file. The other half — the
asymp/wald/rand-family over-coverage, the count-response wald direction
flip, and the jackknife_wald under-coverage — are NEW, unexplained, and
not covered by TODO-1..9. Do not treat this file as closing out all 39
findings; only the originally-documented HL-ties bug (Wilcox) and the
Welch/pooled-variance override gap (MeanDiffPooledVar TODO-8) are
confirmed, fixable bugs as of this cross-validation.

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
- [ ] TODO-4: Verify the fix doesn't change p-values (or CI bounds — per
  the 2026-09-24 update, `boot_distr` feeds both) for the non-degenerate
  case (`t != 0`, no boundary collapse) — bit-for-bit or within
  floating-point tolerance, since the mid-p correction should be a no-op
  when `mean(t0s == t)` is 0 or negligible.
- [ ] TODO-5: Re-run the true-null repro (25+ reps, `count` and `ordinal`)
  and confirm the resampling-family methods' rejection rate returns to
  nominal ~5% even conditional on `beta_hat_T == 0` draws, not just
  unconditionally.
- [ ] TODO-6: Add a permanent regression test (same style as
  `stale_worker_cache_resampling.md`'s TODO-6) that constructs a
  heavily-tied fixture forcing `beta_hat_T == 0` and confirms BOTH (a) the
  resampling-family p-value is NOT pinned at exactly 1, and (b) the
  resampling-family CI is not degenerately narrow/mis-centered, across
  repeated draws — this general shape (boundary-collapse under ties)
  wasn't caught by the existing non-degeneracy test either, since that
  test checks for a constant distribution, not a distribution collapsed
  onto one specific value with only a handful of others present, and it
  doesn't check CI width/centering at all.
- [ ] TODO-7: Regenerate the affected `comprehensive_tests` CSV rows for
  `InferenceAllSimpleWilcox`'s resampling-family methods (p-value AND CI)
  once fixed and installed (only after install, not before, same caution
  as the sibling plans this session produced).
- [ ] TODO-8 (`InferenceAllSimpleMeanDiffPooledVar`, independent of
  TODO-1..7 above): give this class its own pooled-variance
  `compute_estimate_with_bootstrap_weights()` override, mirroring its
  already-correct `compute_asymp_confidence_interval`/
  `compute_asymp_two_sided_pval` overrides, instead of silently falling
  through to `InferenceAllSimpleAverageDiff`'s Welch-based generic
  component despite `overrides$public` declaring an override that doesn't
  actually exist (`inference_all_simple_mean_diff_pooled_var.R:203-225`).
  Real, confirmed bug — fix regardless of TODO-9's outcome.
- [ ] TODO-9 (`InferenceAllSimpleMeanDiffPooledVar`): TODO-8 is NOT
  confirmed to explain the flagged `compute_bayesian_bootstrap_confidence_interval_basic`
  coverage finding (that CI type never reads `s_beta_hat_T`, so the
  Welch/pooled inconsistency can't reach it). Investigate
  `expand_subject_or_block_weights_to_row_weights()` (shared Dirichlet/
  bootstrap-weight generation — a defect there would be a broader
  shared-machinery finding, not specific to this class) and/or reproduce
  directly before treating the coverage finding as explained.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. The
non-degenerate case's p-values must not change (TODO-4 verifies this) —
only the previously-pinned-at-1 boundary case should change.
