# KK Matched-Pair Signed-Rank Kernel: Hoist the Permutation-Invariant Ranks

> **Release:** v1.4.0 (`../future_release_plans/release_v1_4_0.md → TODO-11g`;
> 2026-08-30, user decision). Kernel-internal rewrite of the fixed-matching
> fast path in `compute_matching_wilcox_distr_parallel_cpp()`
> (`src/fast_kk_wilcox_parallel.cpp:74-236`); bit-identical output. Phase 4
> kernel/perf lane of `_master.md`; no dependencies; third sibling of
> `wilcox_hl_kernel_hoisting.md` (`→ TODO-11e`) and
> `ridit_kernel_level_slots.md` (`→ TODO-11f`).

Date: 2026-08-30

## Where the time goes today

`InferenceAllKKWilcoxIVWC$compute_fast_randomization_distr()`
(`inference_all_KK_wilcox_ivwc.R:273`) calls the kernel with
`is_fixed_matching = TRUE` for fixed-pair designs, which takes the
"ULTRA-FAST PATH" (`:95-236`). That path already does the right thing for the
**reservoir** component: when `delta == 0` it ranks the reservoir responses
once, outside the replicate loop (`:129-142`), and per replicate only sums
`res_ranks[i]` over treated reservoir subjects (`:192-194`).

It does **not** do the same for the **matched-pair** component. Per
replicate (`:151-183`) it:

1. allocates `abs_diffs`, `signs` (`:156-157`) and `d_val_idx` (`:170`) on
   the heap — three mallocs per replicate inside the `omp for`;
2. for each pair, computes `diff = (w_b[idx1] == 1) ? (y1 − y2) : (y2 − y1)`,
   its absolute value, its sign, and an `all_zero` flag (`:158-168`);
3. `std::sort`s the pairs by `|diff|` (`:171`) and walks tie groups to
   assign average ranks (`:173-180`), accumulating `W_plus` from pairs with
   positive sign (full rank) or zero sign (half rank).

Step 3 is O(m log m) per replicate with m = number of pairs.

## What is permutation-invariant at `delta == 0`

At `δ = 0`, `y1` and `y2` are the raw responses (`:160-161` select
`y_shifted` only when `delta != 0`), so for pair `i = (idx1, idx2)`:

    diff_b(i) = ±(y[idx1] − y[idx2]),  sign chosen by which member w_b treats.

Hence `|diff_b(i)| = |y[idx1] − y[idx2]|` **does not depend on `b`**. The
tie structure, the average ranks, and the `all_zero` flag are therefore
fixed across all replicates; only `signs[i]` flips. Precisely:

    s0[i]     = sign(y[idx1] − y[idx2])                (once)
    signs_b[i] = (w_b[idx1] == 1) ? s0[i] : −s0[i]     (per replicate, O(1))

and `W_plus,b = Σ_i rank[i]·[signs_b[i] > 0] + 0.5·rank[i]·[signs_b[i] == 0]`.
Zero-difference pairs have `signs_b[i] == 0` for every `b`, so their
half-rank contribution is a constant that can be folded in once.

This is exactly the reservoir treatment at `:129-142`, applied to the pairs.

At `δ ≠ 0` the identity fails — shifting the treated member changes
`|diff|` depending on which member is treated — so the existing
per-replicate path stays for that case, just as the reservoir already
branches on `delta == 0` (`:190`).

## Why it is bit-identical (not merely tolerance-equal)

Average ranks `(i + j + 1)/2` are multiples of `0.5`; each term added to
`W_plus` is `rank` or `0.5·rank`, a multiple of `0.25`; and
`W_plus ≤ m(m+1)/2`. Every partial sum is therefore an exact dyadic rational
far below 2⁵³, so floating-point addition is exact regardless of order. The
subsequent standardisation `(W_plus − m(m+1)/4) / sqrt(m(m+1)(2m+1)/24)` is
unchanged. `identical()` is the test contract, not a tolerance. (The same
argument already justifies the reservoir hoist's exactness.)

## Items

- [ ] **TODO-1: Hoist pair ranks at `delta == 0`.** After `pairs` is built
  (`:120-123`), if `delta == 0 && !pairs.empty()`: compute `abs0[i]`,
  `s0[i]`, `all_zero0`, sort once by `abs0` with the same tie-group walk
  (`:171-180`) to produce `pair_rank[i]`; precompute
  `W_zero = 0.5·Σ_{s0[i]==0} pair_rank[i]`. Per replicate:
  `W_plus = W_zero + Σ_{s0[i]≠0, oriented sign > 0} pair_rank[i]` — one O(m)
  pass reading `w_col[idx1]` only (the orientation flip needs just the
  first member's assignment; `idx2` is the complement within the pair).
  `all_zero0` short-circuits the component exactly as `:169` does.
- [ ] **TODO-2: Hoist per-thread buffers for the `delta ≠ 0` path.** Move
  `abs_diffs`, `signs`, `d_val_idx` (and the reservoir's `r_val_idx`,
  `:197`) into a `#pragma omp parallel { … #pragma omp for … }` block,
  sized once per thread, as `ridit_distr_parallel.cpp:108-119` does.
  Bit-identical; removes 3–4 mallocs per replicate.
- [ ] **TODO-3: Leave the non-fixed-matching path alone.** When
  `is_fixed_matching == FALSE` the pairing `m_col` changes per replicate
  (`:240`), so nothing is invariant; note this in a comment so nobody
  "hoists" it later.
- [ ] **TODO-4: Tests.** `test-kk-signed-rank-hoisting.R`: for fixed seed,
  `w_mat`, `m_mat`, and `y` with (a) distinct pair differences, (b) tied
  `|diff|` across pairs, (c) zero-difference pairs, (d) all pairs
  zero-difference (`all_zero` short-circuit), (e) a reservoir present and
  absent, (f) `δ ∈ {0, 0.3}` and `transform_code ∈ {0, logit-code}`: new
  output `identical()` to the old kernel's (retain the old fixed-matching
  body as a test-only reference). Also `is_fixed_matching = FALSE` still
  matches.
- [ ] **TODO-5: Benchmark.** Kernel-only, old vs. new, `m ∈ {50, 250, 500}`
  pairs with a reservoir of 0 and 20 %, `B = 1000`, 1 and 4 threads, `→
  TODO-135` protocol. Expect ~4–5× on the pair component at `m = 250`
  (sort + 3 mallocs → one O(m) pass); the end-to-end gain depends on the
  reservoir share. Record in `benchmark_model_fits.md`.

## Explicitly out of scope

- The `δ ≠ 0` pair path's algorithm (only its allocations, TODO-2).
- The reservoir component, already hoisted.
- The `InferenceAllKKWilcoxIVWC` IVW combination on the R side.
