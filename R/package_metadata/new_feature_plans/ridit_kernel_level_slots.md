# Ridit Randomization Kernel: Precomputed Level Slots for `reference = "control"` / `"treatment"`

> **Release:** v1.4.0 (`../future_release_plans/release_v1_4_0.md → TODO-11f`;
> 2026-08-30, user decision). Kernel-internal rewrite of the live
> `compute_ridit_distr_parallel_cpp()` (and its bootstrap sibling) in
> `src/ridit_distr_parallel.cpp`. Two tiers: a **bit-identical** tier that
> keeps the existing floating-point operation order, and an optional
> tolerance-equal tier that reorders the sum. Phase 4 kernel/perf lane of
> `_master.md`; no dependencies; sibling of `wilcox_hl_kernel_hoisting.md`
> (`→ TODO-11e`).

Date: 2026-08-30

## Where the time goes today

`InferenceOrdinalRidit` defaults to `reference = "control"`
(`inference_ordinal_ridit.R:70`) and its
`compute_fast_randomization_distr()` (`:235-243`) calls
`compute_ridit_distr_parallel_cpp(y, w_mat, reference, num_cores)`
(`ridit_distr_parallel.cpp:87`). The kernel has a hoisted fast path — but
only for `reference == "pooled"` (`:102-104`, used at `:121-128`), where the
reference set is the whole of `y` and therefore permutation-invariant.

For `"control"` (the default) and `"treatment"`, every replicate runs
`compute_single_ridit_estimate_cpp()` (`:57-84`), which:

1. partitions `y` into `y_ref` (control) and `y_t` (treated) with
   `push_back` — O(n), and a `std::string` comparison per element (`:70-75`);
2. calls `get_ridit_map_cpp(y_ref, …)` (`:13-34`): copies `y_ref`,
   `std::sort`s it, `unique`s it to get the present levels, then one
   `lower_bound` per reference subject to build `counts`, then the cumsum —
   O(n log n + n log K);
3. calls `compute_mean_ridit_with_map_cpp(y_t, …)` (`:36-55`): one
   `lower_bound` per treated subject, with an interpolation rule for treated
   values not present among the reference levels — O(n log K).

The buffers are already per-thread (`:108-119`), so allocation is not the
problem; the per-replicate sort and the ~n binary searches are.

## What is permutation-invariant

The level set of `y` and each subject's position in it. Precompute once:

- `levels_all`: sorted distinct values of `y` (K of them, K ≤ n, typically
  3–7 for an ordinal response);
- `slot[i]`: index of `y[i]` in `levels_all`, for every subject.

Per replicate, with `w_b`:

- `cnt_ref[k]` = number of reference-arm subjects at level `k`: one O(n)
  pass incrementing `cnt_ref[slot[i]]` for `w_b[i] == 0` (control) —
  or, for `"control"`, by subtraction from the fixed total histogram
  `cnt_all[k]` after counting the treated, whichever arm is smaller;
- reference levels present = `{k : cnt_ref[k] > 0}` (a subset of
  `levels_all`; this is what `get_ridit_map_cpp` computes by sort+unique);
- `ridit_score[k]` for present `k`: the same cumulative loop as `:29-33`, in
  the same order, with the same `p_k = cnt_ref[k] / n_ref` arithmetic;
- for **absent** `k` (a level with zero reference count, which can only
  arise for treated values): the interpolation rule of `:44-52` — `0` if
  below the lowest present level, `1` if above the highest, else the mean of
  the nearest present neighbours' scores. Fill these in one O(K) pass over
  `levels_all` carrying "last present score" and looking ahead to the next
  present one, so the per-subject `lower_bound` disappears entirely;
- the mean over treated subjects.

Cost per replicate: O(n + K). Before: O(n log n + n log K).

## Two tiers, one contract each

**Tier A — bit-identical (the deliverable).** Reproduce the exact
floating-point operations of the current code:

- `ridit_score[k]` is built by the identical `cumulative_p += p_k` loop over
  present levels in ascending order — identical values.
- The treated mean is accumulated **in subject order**, `sum_t +=
  score_of_level[slot[i]]` for `i = 0..n−1` with `w_b[i] == 1`, then divided
  by `n_t` — identical values to `:40` / `:54`, because the current code
  visits `y_t` in the same order it was pushed (subject order) and adds the
  same score per subject.
- `− 0.5` last, as at `:83`.

This is what the tests assert with `identical()`.

**Tier B — histogram sum (optional, tolerance-equal).** `sum_t = Σ_k
cnt_t[k] · score[k]` is O(K) instead of O(n) for the mean, but reorders the
additions; results differ at the ulp. Ship only behind a flag, or skip: at
K ≪ n the O(n) subject-order sum is already a single tight loop and Tier A
captures ~all of the win. Recommendation: **skip Tier B** unless TODO-4's
benchmark shows the mean loop is still >20 % of the replicate.

## Items

- [ ] **TODO-1: Precompute level slots.** Before the parallel region: sort
  distinct `y` → `levels_all`, `cnt_all[k]`, and `slot[i]` (one
  `lower_bound` per subject, once). Handle `n = 0` and a single level.
- [ ] **TODO-2: Replace `compute_single_ridit_estimate_cpp` for
  `"control"`/`"treatment"`.** Per-thread `cnt_ref[K]`, `score[K]` (and
  `present[K]`). Per replicate: count the reference arm (or subtract),
  `n_ref`, `n_t`; early `NA_REAL` if either is 0 (matches `:79`); build
  present-level scores in ascending order (Tier A arithmetic); fill absent
  levels by the `:44-52` rule; subject-order treated mean; `− 0.5`. Hoist
  the `reference` string comparison to one `enum` outside the loop
  (`:70-75` compares a `std::string` per element per replicate). Keep the
  pooled path as is (it is already O(n log K); optionally reuse `slot[]` to
  make it O(n), also bit-identical).
- [ ] **TODO-3: Same for `compute_ridit_bootstrap_parallel_cpp`**
  (`:143+`). Rows are resampled there, so `cnt_ref`/`cnt_t` come from the
  index matrix — still one O(B_n) pass with `slot[]`, no sort. Same Tier A
  arithmetic.
- [ ] **TODO-4: Tests.** `test-ridit-kernel-level-slots.R`: for fixed seed,
  `w_mat`, and `y` with (a) all levels present in both arms, (b) a level
  present only among treated (exercises every branch of the interpolation
  rule: below-lowest, above-highest, interior), (c) a level present only
  among controls, (d) K = 1, (e) K = n (all distinct — the ordinal-as-
  continuous edge), (f) unbalanced 5/95 `w`, and for `reference ∈
  {"control", "treatment", "pooled"}`: new output `identical()` to the old
  kernel's (retain the old body as a test-only reference). Also the
  bootstrap kernel with duplicated and missing (`−1`) indices.
- [ ] **TODO-5: Benchmark.** Kernel-only, old vs. new, `n ∈ {100, 500,
  1000, 5000}`, `K ∈ {3, 5, 10}`, `B = 1000`, 1 and 4 threads, `→ TODO-135`
  protocol. Expect ~8–10× at `n = 500, K = 5` (sort + 2n binary searches →
  two linear passes). Record in `benchmark_model_fits.md`.

## Explicitly out of scope

- Any change to the ridit definition or the interpolation rule for absent
  levels — that rule is reproduced, not revisited.
- Tier B unless the benchmark demands it.
- The observed-data estimate (`shared()`), one call not `B`.
