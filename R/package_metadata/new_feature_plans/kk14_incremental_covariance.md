# Sequential KK14 Matching: Incremental Covariance Instead of Per-Subject Recomputation

> **Release:** v1.2.0 (`../future_release_plans/release_v1_2_0.md → TODO-10`;
> 2026-08-30, user decision). R + one small C++ helper; touches
> `design_seq_one_by_one_KK14.R` and the shared
> `compute_all_subject_data()` path in `design_abstract.R:1102`, so every
> sequential class that calls it benefits. Phase 4 kernel/perf lane of
> `_master.md`; no dependencies. **Tolerance-equal, not bit-identical**, and
> the values drive match-accept decisions — see "Equivalence".
>
> **Naming note.** The audit that produced this item read the class's unused
> `morrison` constructor argument (`design_seq_one_by_one_KK14.R:90`) as a
> Sherman–Morrison stub. It is not: per the KK21 docs
> (`design_seq_one_by_one_KK21_stepwise.R:44`) it refers to Morrison & Owen
> (2025) *threshold calibration*, reserved for a different feature. Do not
> repurpose it; this plan adds no constructor argument.

Date: 2026-08-30

## Where the time goes today

`DesignSeqOneByOneKK14$assign_wt()` (`design_seq_one_by_one_KK14.R:130-185`)
runs once per arriving subject `t` after burn-in. Each call does, from
scratch on the `t−1` previous subjects:

1. `private$compute_all_subject_data()` (`design_abstract.R:1102-1135`) →
   `compute_all_subject_data_cpp(X[1:t, ], t, …)`: copies the `t×p` block,
   finds the varying columns (`compute_all_subject_data.cpp:7`), and takes a
   rank-revealing `ColPivHouseholderQR` (`:73-79`) to get `rank_prev` /
   `cols_prev` and the projected `X_prev`, `xt_prev`. **O(t·p²).** The
   result is cached by `t` (`:1110-1112`) — which helps *repeat* calls at
   the same `t` (randomization replay) but not the forward march, and means
   the cache holds every `t`'s `X_prev`: **O(n²·p) memory** over a run.
2. `S_xs = var(all_subject_data$X_prev)` (`:139`) — a two-pass centred
   covariance, **O(t·p²)**.
3. `S_xs_inv = solve(S_xs + diag(reg_eps, rank_prev))` (`:143`) — O(p³),
   with `reg_eps` scaled to `mean(diag(S_xs))`, so the regulariser itself
   changes every step.
4. `compute_proportional_mahal_distances_cpp(xt_prev, X_prev, reservoir,
   S_xs_inv)` (`:150`) — batched Eigen, O(|R|·p²) with |R| the current
   reservoir size. Already well written.
5. The F-threshold, argmin, and bookkeeping — O(|R|).

Summed over a run of `n` subjects: (1) + (2) are **O(n²·p²)**; (3) is
O(n·p³); (4) is O(n·|R|·p²). At `n = 1000, p = 10`: (1)+(2) ≈ 10⁸ flops
(two to four passes over a growing block each step), (3) ≈ 10⁶, (4) ≈
3·10⁷ for a reservoir of a few hundred. The audit's Sherman–Morrison
suggestion targets (3), the smallest term. The win is in (1)+(2): maintain
the sufficient statistics incrementally so each step costs O(p²) instead of
O(t·p²), after which (4) dominates and the run is ~5–10× faster overall.

## The rewrite

Maintain, across subjects, the running mean `x̄_t` and the centred scatter
matrix `M_t = Σ_{i≤t} (x_i − x̄_t)(x_i − x̄_t)ᵀ` over the **full** `p`
columns, updated per subject with the numerically stable Welford form

    d      = x_t − x̄_{t−1}
    x̄_t    = x̄_{t−1} + d / t
    M_t    = M_{t−1} + d (x_t − x̄_t)ᵀ

— O(p²) per subject, no cancellation (the naive `Σxxᵀ − t·x̄x̄ᵀ` form is
**not** acceptable: the code comment at `:138-141` notes covariate scales
with `diag ~ 1e6`, exactly where that form loses digits). Then
`S_xs = M_{t−1}[cols, cols] / (t − 2)` restricted to the current
`cols_prev`, which is what `var(X_prev)` computes (up to summation order).

`cols_prev` / `rank_prev` change rarely and monotonically as rows arrive: a
constant column can only *start* varying, and rank can only *increase*. So:

- track "varying" per column incrementally (a column becomes varying the
  first time a value differs from the first row — O(p) per subject);
- recompute the rank-revealing QR **only** when the varying set changes or
  the previous Cholesky of `S_xs` fails (a cheap SPD check that also serves
  step 3). In the common case (all columns varying, full rank from early
  on) the QR runs once.

`X_prev` (the `t−1 × rank` projected matrix) is still needed by the distance
kernel (4) — but only the **reservoir rows**, and only in the kept columns.
Keep a reservoir-only matrix appended to when a subject enters the
reservoir (O(p) per subject) instead of re-materialising all of `X[1:t, ]`
each step; when `cols_prev` changes (rare), rebuild it once. This removes
the per-`t` cache and its O(n²·p) memory.

Step 3 stays an O(p³) Cholesky solve per subject. Sherman–Morrison would
require a fixed regulariser (today's `reg_eps` tracks `mean(diag(S_xs))`,
so `S + reg·I` is not a rank-1 update of the previous step's matrix) and
would change results for no measurable gain at `p ≤ 20` (a 20³ solve is
~8k flops next to a 300-row distance batch at 40k). **Out of scope.**

## Equivalence — read before implementing

Welford vs. `var()`'s two-pass differ at ~1e-15 relative; the Cholesky
solve vs. `solve()`'s LU differ similarly. The Mahalanobis distances
therefore differ at the ulp, and two decisions depend on them: the
accept/reject test `min_dist < T_cutoff_sq` (`:158`) and the argmin over
reservoir subjects (`:156-157`). A distance within ~1e-13 of the cutoff, or
two reservoir subjects at equal distance, could flip — changing the design
produced for a given seed. As with
`rerandomization_objective_vals_gemm.md`, this is a documented
reproducibility change at exact ties (measure-zero for continuous
covariates, but real for discrete ones — say so in the CHANGELOG), not a
silent one. Tests assert equality of the produced `w` and `m` vectors on
fixtures whose closest decision margin is checked to exceed `1e-8`, and
tolerance-equality of the intermediate `S_xs_inv` and distances otherwise.

## Items

- [ ] **TODO-1: Incremental sufficient statistics in `design_abstract.R`.**
  A small C++ helper (`update_running_scatter_cpp(xbar, M, x_t, t)` in
  `compute_all_subject_data.cpp`, Welford form) or plain R — at O(p²) per
  call either is fine; prefer C++ for the `p = 50` end. Private fields
  `running_xbar`, `running_M`, `varying_cols`, `t_seen`; updated inside
  `add_one_subject_to_experiment_and_assign()` before `assign_wt()`.
  Handle missingness the way `compute_all_subject_data_cpp` does today
  (`is_missing` indicator columns are just columns; verify no row-dropping
  for `X` happens in the current path — `i_all_y_present` filters on `y`,
  which affects `X_all`/`y` outputs, not `X_prev`; confirm and mirror).
- [ ] **TODO-2: `compute_all_subject_data()` fast path.** When the running
  statistics are available, return `S_xs` (from `M`), `cols_prev`,
  `rank_prev`, `xt_prev`, and the **reservoir-only** `X_prev` from the
  incremental state; recompute rank via QR only on a varying-set change or
  Cholesky failure. Keep the old full recomputation as the fallback (and
  for the `X_all`/`y`-present outputs other callers need — audit callers
  with `graft callers compute_all_subject_data` first; KK21
  (`design_seq_one_by_one_KK21.R:230`) uses it too and gets the same
  speedup for its covariance part). Drop the per-`t` cache once no caller
  needs replay of a past `t`; if one does, cache only the small objects
  (`cols_prev`, `rank_prev`), not `X_prev`.
- [ ] **TODO-3: KK14 uses it.** Replace `var()` + `solve()` at `:139-143`
  with the incremental `S_xs` and a Cholesky solve (same `reg_eps` rule).
  Pass the reservoir-only matrix to the distance kernel with local indices.
- [ ] **TODO-4: Tests.** `test-kk14-incremental-covariance.R`: (a) `S_xs`,
  `S_xs_inv`, and the distance vector at every `t` vs. the old path to
  `1e-10` relative, on fixtures with `diag ~ 1e6` scales (the cancellation
  case), a column constant for the first 40 subjects, a column that makes
  `X` rank-deficient until subject 60, and missingness indicators; (b)
  produced `w`/`m` identical to the old path on a well-separated fixture
  (margin assertion); (c) KK21 unaffected in outputs on its fixtures; (d)
  `all_subject_data_cache` memory no longer grows with `t` (object size
  assertion).
- [ ] **TODO-5: Benchmark.** Full sequential run, old vs. new, `n ∈ {200,
  500, 1000, 2000}`, `p ∈ {3, 10, 20}`, `t_0_pct = 0.35`, single thread,
  `→ TODO-135` protocol; and one `SimulationFramework` design bake-off with
  KK14 to show the end-to-end multiplier. Expect 5–10× at `n = 1000, p =
  10`, growing with `n` (the removed term is quadratic in `n`). Record in
  `benchmark_model_fits.md`'s design section.

## Explicitly out of scope

- Sherman–Morrison / rank-1 updates of `S_xs_inv` (see above).
- Reducing the distance kernel below O(|R|·p²) per step (would need a
  whitened reservoir re-whitened whenever `S_xs` changes — same cost).
- The matching rule, threshold, or `lambda`/`t_0_pct` semantics.
- The `morrison` / `p` constructor arguments (reserved for their own
  feature).
