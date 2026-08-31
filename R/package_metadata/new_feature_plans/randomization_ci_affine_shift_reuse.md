# Randomization CI: Reuse One Null Distribution Across the Whole Search (Affine-Shift Shortcut)

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-17o`;
> 2026-08-30, user decision). R-level inference change with no new kernel;
> no Phase 0 dependency. Bit-for-bit on the default path is **not** the goal
> here — the goal is the *same estimator and the same p-value to floating
> point* at 20–30× less work; see "Equivalence contract" below for exactly
> what is and is not preserved.
>
> **Ownership:** this plan owns the plain randomization CI
> (`compute_confidence_interval_rand()` → `compute_rand_confidence_interval()`
> in `inference_all_abstract_rand_ci.R`). The rand-*bootstrap* (BRT) CI already
> has its own affine decomposition (`compute_rand_bootstrap_ci_affine_coefs()`
> in `inference_continuous_ols.R:222-254` and `inference_continuous_lin.R:222`)
> and is not touched.

Date: 2026-08-30

## The finding

`inference_all_abstract_rand.R:436-437` contains a fast path in
`compute_rand_two_sided_pval()`:

```r
if (transform_responses == "none" && is.null(private[["custom_randomization_statistic_function"]]) &&
    !is.null(private$cached_values$t0s_rand) && length(private$cached_values$t0s_rand) >= r) {
    t0s = private$cached_values$t0s_rand[seq_len(r)] + delta
```

It is dead. `cached_values$t0s_rand` is **never assigned a non-`NULL` value
anywhere in the package** (repo-wide grep; and `git log -G` back to the
2026-04-06 rename finds only `= NULL` resets, the clone-copy at
`inference_all_abstract.R:255`, and the `always_keep` preservation at
`inference_all_abstract_rand.R:701`). The read side, the cache-preservation
side, and the CI search's attempt to warm it
(`inference_all_abstract_rand_ci.R:431-432`, which runs one δ = 0 p-value
"to populate" it and populates nothing) were all built; the write side never
landed.

**Re-confirmed 2026-08-30** by an independent repo-wide grep during the
research-plan audit (`new_research_ideas/paper_fast_randomization_inference/paper_fast_randomization_inference.md`),
which also found a **second read site this plan did not own**:
`inference_mixin_kk_gee_shared.R:167-169` — the KK-GEE mixin's own copy of
`compute_rand_two_sided_pval()` carries the identical
`t0s_rand[seq_len(r)] + delta` branch, guarded only by
`transform_responses == "none"` and no-custom-statistic, with **no hook for
the TODO-1 predicate**. Today it is equally dead. But its guard sits *after*
the mixin resolves `transform_responses` per response type (`:156-165`):
count → `"log"`, proportion → `"logit"`, ordinal → (per its own resolution),
so those stay dead-by-transform — while **incidence** falls through the
`switch` default to `"none"`. If TODO-2's write side lands on the abstract
without per-object gating, an incidence KK-combined object could populate
`t0s_rand` and the mixin would serve shifted distributions for IVW
estimators whose equivariance is only tier-2-conjectured (TODO-5). See
TODO-7.

Consequence: `build_randomization_distribution_cache_key()`
(`inference_all_abstract_rand.R:949-953`) keys the distribution cache on
`delta`, so every new δ the CI search visits is a cache miss and costs a full
`r`-permutation distribution. The search visits δ = 0, two seed bounds, up to
`max_expansions = 7` expansions, and ~8–15 bisection steps per bound
(`pval_epsilon = 0.05` default), i.e. **~20–35 full distributions per CI**.
Every one of them, for the classes below, is the δ = 0 distribution plus a
constant.

## Why `t0_b(δ) = t0_b(0) + δ` is exact (and for whom)

EDI's null-shift convention (`inference_all_abstract_rand.R:763`, and the
same in every `compute_fast_randomization_distr` kernel that takes `delta`):
for permutation `b`, `y_sim = y + δ·w_b` where `w_b` is the **permuted**
assignment, and the statistic is then computed with `w_b` in the design.

For any statistic that is (i) linear in `y` and (ii) the coefficient on `w_b`
in a design that contains `w_b` as a column, adding `δ·w_b` to `y` moves that
coefficient by exactly `δ` and nothing else: `(XᵀX)⁻¹Xᵀ(y + δ·w_b) =
β + δ·e_w` because `w_b` is a column of `X`. This is an algebraic identity,
not an approximation, and it holds with covariates, with Lin's centred
interactions (`δ·w_b` lies in the span of the `w_b` column, so the
interaction coefficients are unchanged), and for the simple mean difference
(the `p = 0` case).

It does **not** hold for:

- rank statistics (Wilcoxon, KK signed-rank, ridit, Jonckheere–Terpstra) —
  a shift of the treated changes ranks non-affinely;
- `transform_responses != "none"` (logit for proportions, log for counts and
  survival — `inference_all_abstract_rand.R:427-434`) — the shift is applied
  on the transformed scale and the statistic is not linear in it; the
  existing branch already excludes this;
- custom randomization statistics (R or compiled) — unknown functional form;
  the existing branch already excludes the R kind, and must also exclude
  `compiled_cpp_stat_fn`;
- non-linear model coefficients (logistic, Poisson, ordinal, Cox): with
  covariates the shifted-data MLE is not the original MLE plus δ (the
  treated-subset score does not vanish column-wise);
- g-computation on non-linear models (`InferenceIncidGComp*`,
  `InferenceOrdinalGCompMeanDiff`, `InferencePropGCompMeanDiff`), for the same
  reason;
- KK combined estimators (`InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`,
  `InferenceAllKKMeanDiffIVWC`): the pair-difference and reservoir components
  each shift by exactly δ, and the IVW weights depend only on variances that
  are shift-invariant, so the identity *should* hold — but it is opt-in in a
  second tier after being verified numerically (TODO-5), not assumed.

## Equivalence contract

With the shortcut on, for a qualifying class and a given permutation set, the
p-value at every δ is computed from **the same** `t0s` vector that the slow
path would compute (the δ = 0 distribution) plus `δ`, versus the slow path's
independently computed `t0s(δ)`. These agree to floating point (one addition
vs. a re-solve), so p-values agree up to ties at the resolution of `1/r` —
which can flip a comparison `t0s >= t` when `t0_b(δ)` lands within ~1e-15 of
`t`. The CI endpoints therefore agree to well inside `pval_epsilon`, but not
bit-for-bit. Per the v1.1.0 additive constraint this ships either (a) as a
documented default change with the equivalence test tolerances set
accordingly, or (b) opt-in via `ci_search_control$reuse_null_distribution`
defaulting to `FALSE` in 1.1.0 and flipped in 1.2.0. **Recommendation: (a)**
— the identity is exact, the difference is at the ulp, and the existing
δ-keyed p-value cache (`normalize_delta_for_cache`, resolution
`pval_cache_resolution`) already accepts far coarser agreement.

The sequential-Monte-Carlo early-stopping path
(`compute_two_sided_pval_with_sequential_mc`, `:881`) can return a p-value
from **fewer than `r`** draws. A partial distribution must never be cached as
`t0s_rand` (the read side already guards with `length(...) >= r`, but the
write side must not store a prefix). In the CI search this means: for a
qualifying class, force the δ = 0 call to compute the full `r` (one full
distribution is far cheaper than 20–35 MC-shortened ones), then every later δ
is O(r) arithmetic and MC is moot.

## Items

- [ ] **TODO-1: `supports_additive_delta_shift()` predicate.** New private
  method on the inference abstract, default `FALSE`. Returns `TRUE` for
  `InferenceAllSimpleMeanDiffPooledVar`, `InferenceAllSimpleAverageDiff`,
  `InferenceContinOLS`, `InferenceContinLin` (tier 1). Must also be `FALSE`
  whenever `custom_randomization_statistic_function` or
  `compiled_cpp_stat_fn` is set, whenever `transform_responses != "none"`
  resolves for the response type, and whenever the design uses the Zhang
  incidence exact path (`should_use_zhang_incidence_randomization()`,
  `:415`). Registered through the inference-class registry metadata so the
  `InferenceSuite` and the path audits can see it (the same way
  `supports_reusable_bootstrap_worker` is surfaced).
- [ ] **TODO-2: Populate on the δ = 0 full-`r` path.** In
  `compute_rand_two_sided_pval()`, after
  `get_randomization_distribution_prefix()` returns `t0s` (`:526-534`), if
  `delta == 0`, `transform_responses == "none"`,
  `supports_additive_delta_shift()`, and `length(t0s) == r` (full, not an MC
  prefix), store `private$cached_values$t0s_rand = t0s` together with the
  permutation signature (`stable_signature(permutations)`) so a different
  permutation set cannot be served a stale vector. Extend the read-side
  guard at `:436` to check that signature and the `compiled_cpp_stat_fn`
  exclusion. Invalidate on every path that already resets `t0s_rand = NULL`
  (custom-statistic setters, `set_seed`, response mutation).
- [ ] **TODO-3: Make the CI search use it.** In
  `build_randomization_ci_search_bounds()` (`inference_all_abstract_rand_ci.R:425`),
  when the class qualifies, run the δ = 0 call with sequential MC disabled
  (full `r`) so TODO-2 fires; then leave the search loop untouched — every
  subsequent `compute_randomization_ci_pval_cached()` call hits the `:436`
  branch. Log the hit (`verbose`) so the benchmark can confirm the path is
  taken. Remove the now-redundant "warm" comment at `:431`.
- [ ] **TODO-4: Tests.** (a) Unit: for each tier-1 class on a fixed seed,
  assert `compute_rand_two_sided_pval(r, delta = d)` with the shortcut equals
  the value with `t0s_rand` forcibly `NULL`-ed, for `d ∈ {−1, −0.1, 0, 0.1, 1}`,
  to `1e-12` on the p-value (ties aside — assert on the sorted `t0s`
  vectors to `1e-12`, which is the real equivalence). (b) Integration:
  `compute_confidence_interval_rand()` endpoints with vs without, within
  `pval_epsilon`-implied tolerance. (c) Negative: Wilcoxon, ridit, Poisson,
  a proportion class, and a custom-statistic OLS all report
  `supports_additive_delta_shift() == FALSE` and never populate `t0s_rand`.
  (d) MC guard: with `mc_enable = TRUE` and a small `mc_batch_size`, a δ = 0
  p-value call that stops early leaves `t0s_rand` `NULL`. (e) Count the
  number of distribution computations in one CI (spy on
  `get_randomization_distribution_prefix`) — expect exactly 1 for a tier-1
  class, ≥ 10 for Wilcoxon. Lives in `test-ci-rand.R` or a new
  `test-rand-ci-affine-reuse.R`.
- [ ] **TODO-5: Tier 2 (opt-in after numerical verification).**
  `InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`,
  `InferenceAllKKMeanDiffIVWC`: run TODO-4(a) against them first; flip the
  predicate to `TRUE` only for those that pass to `1e-10` across the fixture
  set. Record the result here either way.
- [ ] **TODO-6: Benchmark + doc.** Before/after wall time of
  `compute_confidence_interval_rand()` for OLS and mean-diff at
  `n ∈ {100, 500, 1000}`, `r ∈ {201, 1001, 2001}`, via
  `R/scripts/benchmark_randomization_ci_ordinal_ppo.R`'s pattern with
  `EDI_INFERENCE_CLASS` extended to accept the tier-1 classes. Expect
  20–30×. Add a sentence to the `compute_confidence_interval_rand()` roxygen
  and the README's CPU section noting that linear-statistic CIs cost one
  null distribution.

- [ ] **TODO-7: Reconcile the KK-GEE mixin read site.** Either (a) gate
  `inference_mixin_kk_gee_shared.R:167-169` on the same
  `supports_additive_delta_shift()` predicate as the abstract's read
  (correct if any KK-GEE class ever passes TODO-5's numerical
  verification), or (b) delete the branch from the mixin outright and let
  those classes take the slow path unconditionally (simplest; nothing is
  lost since the branch has never fired). Decide when TODO-5's tier-2
  results are in; default to (b) if tier 2 stays closed. Either way, add a
  negative test: an incidence KK-combined object must never populate or
  consume `t0s_rand` unless its predicate says so — this is the one
  response type whose transform resolves to `"none"` in the mixin, so it is
  the only live hazard if TODO-2 ships ungated.

## Explicitly out of scope

- Wiring `compute_ols_distr_parallel_cpp` (the unused C++ batch kernel for the
  OLS δ = 0 distribution itself) — a separate, independent win; its own plan.
- Extending the identity to transformed scales (log-link Poisson without
  covariates would actually qualify; with covariates it does not) — not worth
  a special case.
- The BRT CI, which already does this.
