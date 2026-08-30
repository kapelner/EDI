# Wilcoxon–Hodges–Lehmann Randomization Kernel: Hoist the Permutation-Invariant Work

> **Release:** v1.4.0 (`../future_release_plans/release_v1_4_0.md → TODO-11e`;
> 2026-08-30, user decision). Kernel-internal rewrite of the live
> `compute_wilcox_hl_distr_parallel_cpp()` in `src/fast_wilcox_hl.cpp`; every
> change is exact (bit-identical output). Phase 4 kernel/perf lane of
> `_master.md`. No dependency on other plans; the v1.1.0 dead-kernel triage
> (`ols_randomization_distr_cpp_wiring.md → TODO-4`) deletes the *unused*
> `fast_wilcox_parallel.cpp` kernels and does not touch this file.

Date: 2026-08-30

## Where the time goes today

`InferenceAllSimpleWilcox$compute_fast_randomization_distr()`
(`inference_all_simple_wilcox.R:262-274`) calls
`compute_wilcox_hl_distr_parallel_cpp(w_mat, y, delta, transform_code = 0L, …)`
(`fast_wilcox_hl.cpp:445`). Per replicate `b` (`:470-486`):

1. `std::vector<double> y_t, y_c;` declared **inside** the `omp for` —
   two heap allocations (plus `reserve(n)`) per replicate.
2. A pass over `n` pushing each finite `y[i]` into `y_t` or `y_c` by
   `w_b[i]`, applying the δ-shift to treated values from a precomputed
   `y_shifted` (`:457-462`).
3. `hl_from_groups()` (`:186-211`): when `n_t·n_c > kExactMedianMaterializeLimit
   = 4096` (`:27`) — i.e. for any `n ≳ 130` balanced, so always in the
   regime that matters — it `std::sort`s `y_t` and `y_c` (`:205-206`) and then
   calls `select_pairwise_diff_sorted()` once (odd `n_t·n_c`) or twice (even:
   ranks `mid` and `mid−1`, `:208-210`).
4. `select_pairwise_diff_sorted()` (`:102-123`) bisects on the value axis
   from the full bracket `[y_t.front() − y_c.back(), y_t.back() − y_c.front()]`
   (`:107-108`) until floating-point exhaustion (`mid == lo || mid == hi`,
   ~53 halvings for doubles) or 96 iterations. Each halving is one
   `count_pairwise_diffs_leq()` two-pointer pass, O(n_t + n_c). It then snaps
   `hi` to the largest realised pairwise difference `≤ hi` with one more
   pass (`:120`).

So per replicate: 2 mallocs + O(n) partition + 2·O(n log n) sorts + (1 or 2)
× (~53 + 1) × O(n) counting passes. At `n = 500` the counting passes (~54–108
× 500 ≈ 27–54k comparisons) and the sorts (~2 × 250·8 ≈ 4k comparisons plus
their poor branch behaviour) dominate; the partition is ~500.

## What is permutation-invariant

- **The sorted order of `y`.** `y` is fixed across all `B` permutations.
  Only the *labels* change. If `y` is sorted once (indices, `O(n log n)`,
  once per call), then walking the indices in that order and appending to
  `y_t` or `y_c` according to `w_b` produces both vectors **already
  sorted** — no per-replicate sort at all. With `delta ≠ 0`, treated values
  come from `y_shifted`; `apply_shift_hl()` is monotone increasing in `y`
  for every `transform_code` (additive, logit-shift, log-shift), so the
  sorted order of `y` is also the sorted order of `y_shifted`, and the
  partition remains sorted. (If a non-monotone transform is ever added,
  fall back to the per-replicate sort for that code.)
- **The buffers.** Two per-thread `std::vector<double>` of capacity `n`,
  allocated once inside `#pragma omp parallel` and `clear()`ed per
  replicate — the idiom `ridit_distr_parallel.cpp:132-141` already uses.
- **The bracket scale.** Under the sharp null every permutation's HL
  estimate is a draw from the same null distribution, so consecutive
  replicates' values cluster tightly (their spread is O(σ/√n), while the
  full bracket is O(range(y))). A warm bracket around the previous
  replicate's value is valid ~always and, when it is not, can be widened
  geometrically before falling back to the full range.

## Exactness argument for the warm bracket

`select_pairwise_diff_sorted()` returns the `rank`-th smallest pairwise
difference. Bisection on the value axis with a *valid* bracket — one with
`count(lo) < rank + 1 ≤ count(hi)` — converges to the same `hi` (the smallest
double with `count(hi) ≥ rank + 1`, up to the floating-point stopping rule)
from any valid starting bracket, and the final snap to
`max_pairwise_diff_leq(hi)` then returns the identical realised difference.
The result is therefore bit-identical to the cold-bracket result provided the
bracket is validated by two counting passes before bisection begins. If the
validation fails, double the half-width and re-validate (galloping); after a
bounded number of failures, use the full bracket. Under
`schedule(dynamic)` the "previous replicate" is per-thread state; that is
fine — any recent null value is a good seed.

Expected iteration count: the full bracket spans ~`2·range(y)`; the answer
is known to within a few `σ/√n`; so a warm bracket saves ~`log2(range/(σ/√n))`
≈ 6–8 halvings of the ~53, **but** bisection continues to floating-point
exhaustion regardless of where it starts, so the raw saving is modest. The
real win comes from a second change: **stop bisecting once the bracket
contains exactly one realised pairwise difference**, i.e. when
`count(hi) − count(lo) == 1` — at that point `hi`'s snap is already
determined and the remaining ~40 halvings are wasted. With that stopping
rule, ~53 passes → ~10–14 passes from the full bracket and ~6–10 from a warm
one. This rule is exact by construction (the snap returns the unique
difference in `(lo, hi]`). The two rank searches for even `n_t·n_c` (`mid−1`,
`mid`) share the bracket: seed the second from the first's result.

## Items

- [ ] **TODO-1: Hoist the sort.** Before the `omp for`, build `order` =
  indices of finite `y` sorted by `y` (stable). Per replicate, walk `order`
  and append to `y_t`/`y_c`; remove the `std::sort` calls from
  `hl_from_groups()` for this call path (keep them for the other public
  callers of `hl_from_groups()`, or add a `presorted` flag). Bit-identical.
  `O(n log n)` → `O(n)` per replicate.
- [ ] **TODO-2: Hoist the buffers.** Per-thread `y_t`/`y_c` (and any scratch
  the selection needs) inside `#pragma omp parallel { … #pragma omp for … }`,
  `clear()` per replicate. Bit-identical. Removes 2 mallocs/replicate.
- [ ] **TODO-3: Early-stop bisection.** In `select_pairwise_diff_sorted()`,
  track `count(lo)` and `count(hi)` (already computed as the loop runs) and
  exit when `count(hi) − count(lo) == 1`, then snap. Bit-identical. ~53 →
  ~10–14 passes. This is the largest single win and is independent of the
  warm start.
- [ ] **TODO-4: Warm bracket.** Per-thread `last_hl` (and `last_half_width`
  seeded from the first replicate's converged bracket). Validate with two
  counting passes; gallop on failure; full bracket after 4 failures. Seed
  the `mid` search from the `mid−1` result. Bit-identical by the argument
  above; must be **tested** as bit-identical, not tolerance-equal.
- [ ] **TODO-5: Tests.** `test-wilcox-hl-kernel-hoisting.R`: (a) for fixed
  seed, `w_mat`, `y` with ties and duplicated values, and `δ ∈ {0, 0.3}`, the
  new kernel's output `identical()` to the old kernel's (keep the old body
  as a `_reference` function under `#ifdef EDI_TESTING` or in a test-only
  `sourceCpp`); across `n ∈ {20, 130, 500, 2000}` so both sides of
  `kExactMedianMaterializeLimit` are covered; balanced and 10/90
  unbalanced `w`; (b) `NA` handling unchanged (non-finite `y` skipped);
  (c) a pathological `y` (all equal; two clusters far apart) where the warm
  bracket must fail validation and fall back; (d) the `transform_code ≠ 0`
  path (`compute_wilcox_hl_distr_parallel_cpp` is also reachable with logit/
  log codes from the proportion/count Wilcoxon classes — grep callers) gives
  identical output.
- [ ] **TODO-6: Benchmark.** Kernel-only, old vs. new, `n ∈ {100, 500, 1000,
  5000}`, `B = 1000`, single thread and 4 threads, under the `→ TODO-135`
  noise protocol. Expect ~3–4× at `n = 500` (TODO-3 ≈ 2–2.5×, TODO-1 ≈
  1.3×, TODO-2/4 the remainder). Record in `benchmark_model_fits.md`.

## Explicitly out of scope

- Replacing value-axis bisection with an `O(n log n)` exact selection on the
  sorted-sums matrix (Johnson–Mizoguchi 1978 / Frederickson–Johnson 1984).
  Asymptotically better, but a large, subtle implementation for a kernel
  that after TODO-1..4 costs ~10 passes of a two-pointer loop; revisit only
  if `n ≥ 10⁴` becomes a target.
- The dead `fast_wilcox_parallel.cpp` kernels (deleted in v1.1.0).
- The HL point estimate on the observed data (`shared()`), which is one
  call, not `B`.
- Anything that changes the returned values: this plan's contract is
  `identical()`.
