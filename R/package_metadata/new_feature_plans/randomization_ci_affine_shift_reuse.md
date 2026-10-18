# Randomization CI: Reuse One Null Distribution Across the Whole Search (Affine-Shift Shortcut)

> **Release:** v1.0.5 (`../future_release_plans/release_v1_0_5.md → TODO-2`,
> moved 2026-09-23 from `release_v1_1_0.md → TODO-17o`, bug-fix/feature
> split; 2026-08-30, user decision). R-level inference change with no new kernel;
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

Date: 2026-08-30. **Updated 2026-09-04** (user question, "since we're
implementing Brent, should this plan change?"): added the "Interaction with
the CI-search-driver plans" section — Brent does not apply here, RM is moot
on tier-1 classes — and the decision-gated TODO-8 (direct order-statistic
inversion). TODO-1..7 are unchanged.

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
research-plan audit (`new_research_ideas/paper/fast_randomization_inference/fast_randomization_inference.md`),
which also found a **second read site this plan did not own**:
`inference_mixin_kk_gee_shared.R:167-169` — the KK-GEE mixin's own copy of
`compute_rand_two_sided_pval()` carries the identical
`t0s_rand[seq_len(r)] + delta` branch, guarded only by
`transform_responses == "none"` (the "no-custom-statistic" half of this
guard was dropped 2026-09-13, `fix_custom_randomization_statistic.md`:
`custom_randomization_statistic_function` can no longer exist on a
KK-GEE-composing class at all, so the check was dead weight there too),
with **no hook for the TODO-1 predicate**. Today it is equally dead. But its guard sits *after*
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

> **Correction (2026-09-05) — the identity below needs a `(1 − c_b)` factor.**
> The paragraph that follows states EDI's convention as `y_sim = y + δ·w_b`
> (citing `inference_all_abstract_rand.R:763`). That is a misreading: the
> line above it (`:738`, `w_priv$y = as.numeric(y)`) assigns the **imputed**
> responses `y_delta = y − δ·w_obs` (built by
> `setup_randomization_template_and_shifts()`, `:1079-1089`, `inverse = TRUE`)
> into the worker, and every other path — `load_randomization_perm_into_worker()`,
> the C++ fast kernels fed `setup$y_delta`, the randomization-bootstrap
> `y0_full` — does the same. The actual construction is impute-then-permute,
> `y_sim = y − δ·w_obs + δ·w_b` (pinned by
> `tests/testthat/test-rand-null-construction.R`). For the linear
> statistics this section covers, the exact identity is therefore
>
> ```
> t0_b(δ) = coef_{w_b}(y − δ·w_obs + δ·w_b) = t0_b(0) + δ·(1 − c_b),
> c_b = coefficient on w_b when the fixed vector w_obs is regressed on the permuted design [1, w_b, X]
>     (simple mean difference: c_b = mean(w_obs | w_b = 1) − mean(w_obs | w_b = 0))
> ```
>
> Everything this plan promises survives — one cached `δ = 0` distribution
> serves the whole search — but the per-permutation slope is `1 − c_b`, not
> `1`. `c_b` is computed once per permutation set: a single `O(nB)` dot
> product `wᵀ_obs W` for the mean difference, one small solve per
> permutation for OLS/Lin (`w_obs` regressed on `[1, w_b, X]`; `X` fixed,
> so `(XᵀX)`-type factorisations are shared). **Implementing the identity
> without this factor would silently replace the exact construction with
> shift-the-null** (wider intervals, correct p-values at `δ = 0` only);
> the test above fails in that case. Every TODO below that wires the
> identity must compute and apply `c_b`; the equivalence contract is
> against the current impute-then-permute numbers, not against `+δ`.
> See `randomization_ci_construction_audit.md → §B.3`.

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
- ~~custom randomization statistics (R or compiled) — unknown functional
  form~~ **moot as of 2026-09-13** (`fix_custom_randomization_statistic.md`,
  `finished_features/`): `custom_randomization_statistic_function`/
  `compiled_cpp_stat_fn` no longer exist on any of the tier-1 classes below
  (or on any class outside the new, standalone `InferenceRandCustom`), so
  this exclusion is now structurally unreachable for them and needs no
  guard — see TODO-1/TODO-2's updated notes;
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

- [x] **TODO-1: `supports_additive_delta_shift()` predicate.** Implemented
  2026-10-09: the private predicate is registered for the four tier-1 classes
  and is gated on the resolved untransformed response scale and non-Zhang
  randomization path. Registry metadata exposes the same capability.
  New private
  method on the inference abstract, default `FALSE`. Returns `TRUE` for
  `InferenceAllSimpleMeanDiffPooledVar`, `InferenceAllSimpleAverageDiff`,
  `InferenceContinOLS`, `InferenceContinLin` (tier 1). ~~Must also be
  `FALSE` whenever `custom_randomization_statistic_function` or
  `compiled_cpp_stat_fn` is set~~ (no longer needed as of 2026-09-13,
  `fix_custom_randomization_statistic.md`: none of the tier-1 classes above
  can have either field set anymore — only the new, standalone
  `InferenceRandCustom` can, and it does not compose this predicate's host
  hierarchy at all). Must still be `FALSE` whenever `transform_responses
  != "none"` resolves for the response type, and whenever the design uses
  the Zhang
  incidence exact path (`should_use_zhang_incidence_randomization()`,
  `:415`). Registered through the inference-class registry metadata so the
  `InferenceSuite` and the path audits can see it (the same way
  `supports_reusable_bootstrap_worker` is surfaced).
- [x] **TODO-2: Populate on the δ = 0 full-`r` path.** Implemented
  2026-10-09 with a full-content permutation signature and exact
  per-permutation slopes. The cache is written only after a full distribution
  and read only for the identical permutation set. In
  `compute_rand_two_sided_pval()`, after
  `get_randomization_distribution_prefix()` returns `t0s` (`:526-534`), if
  `delta == 0`, `transform_responses == "none"`,
  `supports_additive_delta_shift()`, and `length(t0s) == r` (full, not an MC
  prefix), store `private$cached_values$t0s_rand = t0s` together with the
  permutation signature (`stable_signature(permutations)`) so a different
  permutation set cannot be served a stale vector. Extend the read-side
  guard (line numbers have shifted post-`fix_custom_randomization_
  statistic.md`; re-locate the `transform_responses == "none" &&
  !is.null(private$cached_values$t0s_rand) && ...` check in
  `compute_rand_two_sided_pval()`) to check that signature — no
  `compiled_cpp_stat_fn` exclusion needed any more, since that field no
  longer exists on this class family (see TODO-1's note). Invalidate on
  every path that already resets `t0s_rand = NULL` (`set_seed`, response
  mutation — the custom-statistic setters this used to also list are gone).
- [x] **TODO-3: Make the CI search use it.** Implemented 2026-10-09: a
  qualifying CI creates one fixed permutation set, disables sequential MC for
  the one delta-zero warm-up, then reuses the affine cache for the search. In
  `build_randomization_ci_search_bounds()` (`inference_all_abstract_rand_ci.R:425`),
  when the class qualifies, run the δ = 0 call with sequential MC disabled
  (full `r`) so TODO-2 fires. A complete cache counts as warm only when both
  vectors and its full-content permutation signature match the CI's fixed
  permutation set; otherwise the warm-up replaces the stale cache. Then leave
  the search loop untouched — every
  subsequent `compute_randomization_ci_pval_cached()` call hits the `:436`
  branch. Log the hit (`verbose`) so the benchmark can confirm the path is
  taken. Remove the now-redundant "warm" comment at `:431`.
- [x] **TODO-4: Tests.** Added 2026-10-09 in `test-ci-rand.R`: fixed-seed
  tier-1 distribution equivalence at five deltas, one-distribution CI reuse,
  a stale-complete-cache/different-permutation signature regression, negative
  capability/MC-prefix checks, and the separate KK OLS reference test. (a)
  Unit: for each tier-1 class on a fixed seed,
  assert `compute_rand_two_sided_pval(r, delta = d)` with the shortcut equals
  the value with `t0s_rand` forcibly `NULL`-ed, for `d ∈ {−1, −0.1, 0, 0.1, 1}`,
  to `1e-12` on the p-value (ties aside — assert on the sorted `t0s`
  vectors to `1e-12`, which is the real equivalence). (b) Integration:
  `compute_confidence_interval_rand()` endpoints with vs without, within
  `pval_epsilon`-implied tolerance. (c) Negative: Wilcoxon, ridit, Poisson,
  a proportion class, and (no longer "a custom-statistic OLS" — that
  combination can't exist post-2026-09-13, `fix_custom_randomization_
  statistic.md`; use an `InferenceRandCustom` instance instead, confirming
  it reports `FALSE`/has no such predicate at all rather than accidentally
  inheriting `TRUE`) all report `supports_additive_delta_shift() == FALSE`
  and never populate `t0s_rand`.
  (d) MC guard: with `mc_enable = TRUE` and a small `mc_batch_size`, a δ = 0
  p-value call that stops early leaves `t0s_rand` `NULL`. (e) Count the
  number of distribution computations in one CI (spy on
  `get_randomization_distribution_prefix`) — expect exactly 1 for a tier-1
  class, ≥ 10 for Wilcoxon. Lives in `test-ci-rand.R` or a new
  `test-rand-ci-affine-reuse.R`.
- [x] **TODO-5: Tier 2 (opt-in after numerical verification).** Completed
  2026-10-09: fixed-permutation numerical checks select
  `InferenceContinKKOLSOneLik` at `1e-10`; `InferenceContinKKOLSIVWC` and
  `InferenceAllKKMeanDiffIVWC` remain deliberately excluded and are asserted
  false by the reference test.
  `InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`,
  `InferenceAllKKMeanDiffIVWC`: run TODO-4(a) against them first; flip the
  predicate to `TRUE` only for those that pass to `1e-10` across the fixture
  set. Record the result here either way.
- [ ] **TODO-6: Benchmark + doc.** The benchmark script
  `R/benchmark/benchmark_randomization_ci_affine_reuse.R` and README/roxygen
  documentation were added 2026-10-09. A full source-loaded, `compile = FALSE`
  run completed 2026-10-13 with three interleaved repetitions per cell at
  `n ∈ {100, 500, 1000}`, `r ∈ {201, 1001, 2001}`. The measured affine/general
  median speedup ranges were 1.13–1.59× for `InferenceAllSimpleAverageDiff`
  and 1.05–2.14× for `InferenceContinOLS`; thus the projected 20–30× is not
  supported by this implementation/environment and remains an open acceptance
  gate, not a claimed result. To reduce avoidable OLS overhead, affine slopes
  now residualize the fixed covariate block once and use vectorized
  permutation-column inner products; a per-permutation QR reference test and
  the tier-1 distribution-equivalence tests pass. The harness was strengthened
  2026-10-14 with one unmeasured warm-up for each route on fresh objects and
  alternating measured order (two pairs in quick mode, four in full mode).
  The bounded quick rerun measured 1.33× for mean difference and 1.42× for OLS;
  this small sample is consistent with the full run and does not support the
  projected 20–30× target. Keep the checkbox open until the measured gain and
  the README/roxygen claim are reconciled with the original target (or the
  owner explicitly accepts the smaller measured gain). **Installed-package
  check, 2026-10-15:** one bounded three-pair run against EDI 1.0.3 at
  `n=500, r=1001` (fixed permutations, one warm-up per path, alternating
  order; no compilation) measured affine/general medians of 0.108/0.121 s
  for `InferenceAllSimpleAverageDiff` (1.12×) and 0.084/0.153 s for
  `InferenceContinOLS` (1.82×). The current installed DLL's mtime was
  2026-10-15 14:09:05 +0300. This confirms the modest gain on the installed
  package but does not meet the projected target. No call-level profiler was
  collected, so the residual time is not attributable to a single function;
  the modest end-to-end gain is consistent with shared CI setup/search and
  p-value counting limiting the realized benefit at this workload. CSV:
  `/tmp/edi-todo2-installed-benchmark-20261015.csv`; harness:
  `/tmp/edi-todo2-installed-benchmark.R`. **Exploratory profile, 2026-10-16:**
  one warmed call per route on installed EDI 1.0.3 at `n=500, r=1001`,
  `InferenceContinOLS`, with the same fixed permutation matrix, measured
  0.180 s affine and 0.213 s general under `Rprof` (10 ms sampling; this is
  not a benchmark acceptance run). Both profiles retained substantial
  allocation/GC cost (35–40% sampled self time); affine still spent about
  43% of sampled total in the CI p-value/cache path, including cache-key and
  stable-signature work, while the general path spent about 38% in randomization
  distribution-prefix/kernel work. This localizes plausible remaining shared
  overhead but does not establish a stable per-function cost: the profiles
  contain few samples, GC is material, and they do not substitute for a
  repeated paired benchmark. Raw profiles and runner scratch are under
  `scratch/todo2_profile_20261016/`. **Source-level cache-key optimization,
  2026-10-16:** `compute_rand_two_sided_pval()` now computes the full-content
  permutation signature once and supplies it to the private distribution
  cache-key builder, which retains its old hash-on-omitted/NULL behavior for
  other callers. The stable-signature regression now checks precomputed-key
  identity, full-content mutation sensitivity, and the NULL signature. The
  edited R files parse and their scoped `git diff --check` is clean; the
  installed EDI 1.0.3 cannot validate unbuilt checkout edits, so the focused
  test remains unrun pending an authorized source/native validation path. No
  benchmark followed this change; it makes no speedup claim and leaves the
  20–30× target open. **CI inventory cross-check, 2026-10-18:** at checkout
  `66379c40`, `test-ci-rand.R` is scheduled in the correctness tier (5.0 s)
  and coverage tier (9.8 s); the stable-signature regression is scheduled in
  correctness (1 s) and coverage (`bootstrap`). These manifest rows establish
  that CI will schedule the focused tests, not that a particular branch was
  exercised or that the unbuilt cache-key change passed. After authorized
  native validation, retain the current full paired benchmark protocol and
  report its result separately; neither the manifest nor the prior installed
  EDI 1.0.3 profile closes the speed/documentation gate.
  **Post-cache-key rerun runbook (prepared 2026-10-18; not run):** the target
  is the unchanged full 18-cell grid (`InferenceAllSimpleAverageDiff` and
  `InferenceContinOLS`; `n = {100, 500, 1000}` × `r = {201, 1001, 2001}`),
  not quick mode. At current checkout `66379c40`, the source-level cache-key
  reuse optimization is present (introduced at `51d9167c`); the harness is
  `R/benchmark/benchmark_randomization_ci_affine_reuse.R` with blob
  `c12bb19c5c469b1ca683008af1ff9a6e18f419e4`. Each cell fixes one generated
  design/permutation set, warms both fresh-object routes, then alternates four
  measured affine/general pairs. After TODO-56 is terminal and compute is
  authorized, run from the checkout with `EDI_BENCHMARK_QUICK=0`, one BLAS/
  OpenMP thread, and `TMPDIR` set to a fresh unique child of `/tmp`; the
  no-canonical-write invocation is:

  ```sh
  bench_dir="$(mktemp -d /tmp/edi-todo2-rerun.XXXXXX)"
  mkdir "$bench_dir/tmp"
  TMPDIR="$bench_dir/tmp" OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    EDI_BENCHMARK_QUICK=0 Rscript R/benchmark/benchmark_randomization_ci_affine_reuse.R \
    > "$bench_dir/run.log" 2>&1
  ```

  The harness uses `pkgload::load_all(..., compile = FALSE)` and writes its
  cell summaries to stdout, so the log is the raw artifact; do not redirect it
  over a tracked/canonical result. Record
  checkout SHA, harness blob, R/package and loaded-DLL provenance, thread
  settings, complete log, per-cell medians and speedup ratios. Historical
  comparison anchors remain the 2026-10-13 full-grid ranges (1.13–1.59× mean
  difference; 1.05–2.14× OLS) and 2026-10-15 installed three-pair cell
  (1.12× mean difference; 1.82× OLS); the latter is not the same full grid.
  The script emits cell summaries/medians, not individual pair durations, so
  retain the full log and do not imply paired uncertainty estimates. Keep the
  original 20–30× target and documentation reconciliation open unless the
  owner explicitly accepts a revised target; this rerun alone cannot change
  that decision.

  **Maintainer target decision — pending (no option selected):** the full-grid
  source-loaded benchmark measured 1.05–2.14× for OLS and 1.13–1.59× for
  average difference, versus the original projected 20–30× gain. The owner
  must either (a) accept the measured, workload-specific gain and restate the
  acceptance target/documentation accordingly, or (b) retain the 20–30× target
  and authorize further optimization; until decided, TODO-6 and release
  TODO-2 remain open. Record owner, date, selected option, and rationale here.
  This is a target/acceptance decision only, not benchmark evidence or
  authorization to run another benchmark.

- [x] **TODO-7: Reconcile the KK-GEE mixin read site.** Completed 2026-10-09:
  the never-populated legacy `t0s_rand + delta` branch was removed from the
  KK-GEE mixin. Thus an incidence KK-combined object cannot consume this cache;
  only the verified predicate-bearing classes use the abstract implementation.
  Either (a) gate
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

- [ ] **TODO-8 (decision-gated, optional): direct order-statistic inversion
  — no search at all for tier-1 classes.** See "Interaction with the
  CI-search-driver plans" below for the derivation. Not part of the
  TODO-1..7 deliverable; opened as a user decision once TODO-3's benchmark
  is in, because its gain over TODO-3 is *exactness and the removal of the
  bracket/expansion failure modes*, not wall time. If adopted: (a) new
  private method `compute_rand_confidence_interval_direct()` that takes the
  full-`r` δ = 0 `t0s`, the per-permutation slopes `1 − c_b` (computed once
  per permutation set by TODO-2 under the corrected identity), and the
  observed `t`; **refuses (falls back to the TODO-3 search) unless
  `min_b (1 − c_b) > 0`**; drops non-finite `t0s` exactly as the p-value
  path does; sorts `z_b = (t − t0_b(0)) / (1 − c_b)` once; and returns the
  two order statistics — with the **index and the `>=`/`<=` tie convention derived
  from `compute_rand_two_sided_pval()`'s comparison line
  (`2 * min(sum(t0s >= t), sum(t0s <= t)) / nsim_adj`, floored at
  `2 / nsim_adj`), not assumed**; (b) dispatched from
  `compute_rand_confidence_interval()` only when
  `supports_additive_delta_shift()` is `TRUE` and no `ci_search_control`
  override is set; (c) equivalence test: the direct bound lies within the
  `pval_epsilon`-implied tolerance of the TODO-3 bisection bound *and* is a
  genuine jump — `p(bound) >= alpha` and `p(bound ∓ 1e-9) < alpha` on the
  outward side; (d) documented as a default change for those classes (the
  endpoints move *toward* the exact answer, off the bisection's
  `pval_epsilon` grid), with the existing `pval_epsilon` / `max_expansions`
  parameters documented as no-ops on this path.

## Interaction with the CI-search-driver plans (added 2026-09-04)

Once TODO-1..3 land, the object the CI search inverts for a tier-1 class
changes character: with a fixed permutation set, `p(δ)` is no longer a
Monte-Carlo estimate that costs a distribution per evaluation — it is an
**exact step function of δ**, computable in O(r) from the cached `t0s`
and the per-permutation slopes `1 − c_b` (see the 2026-09-05 correction
above): `p(δ) = 2 · min(#{t0_b(0) + δ·(1 − c_b) ≥ t}, #{t0_b(0) + δ·(1 − c_b) ≤ t}) / r`,
each term affine in δ, so the jumps sit at `δ_b = (t − t0_b(0)) / (1 − c_b)`
with flat plateaus between. *(Section corrected 2026-09-05: the original
2026-09-04 text used the shift-the-null form `t0_b + δ`, jumps at
`t − t0_b`, which the same-day correction to the identity superseded.)*
That single fact settles how each of the three sibling CI-search plans
relates to this one:

- **Brent (`brent_ci_inversion.md`, `release_v1_1_0.md → TODO-17w`): not
  applicable, in code or in principle.** In code: Brent replaces the
  bisection phase of `pval_invert_ci_cpp()` (`src/lrt_ci_newton.cpp`), the
  inverter for the likelihood-based score / gradient / Bartlett-LR CIs; the
  randomization CI search is a different driver
  (`compute_rand_confidence_interval()` →
  `build_randomization_ci_search_bounds()` in
  `inference_all_abstract_rand_ci.R`) and Brent never touches it. In
  principle: Brent's secant / inverse-quadratic steps assume a smooth
  `f(δ) = p(δ) − α`; on a step function every interpolated trial lands on a
  plateau, the acceptance test rejects it, and the iteration degrades to
  bisection — same evaluation count, more code. **Do not port Brent to this
  search.** No change to this plan on Brent's account.
- **Robbins–Monro (`garthwaite_buckland_ci_search.md`, `→ TODO-17u`): moot
  on tier-1 classes, live everywhere else.** RM's economy is "one replicate
  draw per step instead of a full-`r` distribution per bisection step." On
  a tier-1 class after this plan, one bisection step is O(r) vector
  arithmetic on an already-computed distribution — *cheaper than a single
  RM step*, which needs one fresh replicate fit. RM cannot win there, and
  an A/B corpus that mixes tier-1 and non-tier-1 classes would report a
  confounded verdict. The RM plan therefore (i) keys its dispatch off this
  plan's `supports_additive_delta_shift()` predicate — the RM driver is not
  offered when it is `TRUE` — and (ii) stratifies its A/B corpus on the same
  predicate, promoting on the non-tier-1 stratum only. Those edits are made
  in that plan (2026-09-04); this plan's only obligation is that the
  predicate is registry-visible (TODO-1 already requires it).
- **The genuinely new option this plan opens — direct inversion, no search
  (TODO-8).** Because `p(δ)` is a step function whose jumps are the sorted
  values `z_b = (t − t0_b(0)) / (1 − c_b)`, **provided every slope is
  positive** (`min_b (1 − c_b) > 0` — automatic for the simple mean
  difference, where `c_b ∈ (−1, 1)`; a per-permutation-set check for
  OLS/Lin, where `c_b` is a regression coefficient), each term is
  increasing in δ, the confidence set `{δ : p(δ) ≥ α}` is an interval,
  and its two endpoints are two order statistics of the `z_b` (lower-tail
  and upper-tail, at the `α/2` level). One sort, O(r log r), no bracket,
  no `max_expansions`, no `pval_epsilon`, no bisection at all. If any
  slope is non-positive the interval structure is not guaranteed and the
  direct path must fall back to the TODO-3 search — that guard is part of
  TODO-8's contract, not an afterthought. TODO-3 already gets ~all of the *wall-time* win (25
  O(r) shifts are negligible next to the one distribution computation), so
  TODO-8's value is that it returns the exact jump rather than a
  `pval_epsilon`-grid neighbour and eliminates the bracket-search failure
  branches for these classes. That is a change to the returned endpoints
  (toward the exact answer), which is why it is decision-gated rather than
  folded into TODO-3.

Net: **no change to TODO-1..7 because of Brent**; the RM plan is corrected
to dispatch around tier-1 classes; and the direct inversion is recorded as
an explicit, gated follow-on rather than left implicit.

## Explicitly out of scope

- Wiring `compute_ols_distr_parallel_cpp` (the unused C++ batch kernel for the
  OLS δ = 0 distribution itself) — a separate, independent win; its own plan.
- Extending the identity to transformed scales (log-link Poisson without
  covariates would actually qualify; with covariates it does not) — not worth
  a special case.
- The BRT CI, which already does this.
- Porting Brent's method to the randomization CI search — see the
  interaction section: it is a different code path and gains nothing on a
  step function.
