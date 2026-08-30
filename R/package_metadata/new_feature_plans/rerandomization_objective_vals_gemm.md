# Rerandomization `compute_objective_vals_cpp`: GEMM Accumulation and Whitened Mahalanobis

> **Release:** v1.4.0 (`../future_release_plans/release_v1_4_0.md → TODO-11h`;
> 2026-08-30, user decision). Kernel-internal rewrite of
> `compute_objective_vals_cpp()` (`src/rerandomization_helpers.cpp:~90-165`),
> called from `DesignFixedRerandomization` (`design_fixed_rerandomization.R:181`).
> Phase 4 kernel/perf lane of `_master.md`; no dependencies. **Not**
> bit-identical (see "Equivalence" — this is the one plan in the v1.4.0
> hoisting batch whose output is tolerance-equal, and the values are used
> for *ranking* allocations, so the plan says what that means).

Date: 2026-08-30

## Where the time goes today

`compute_objective_vals_cpp(X, indicTs, objective, inv_cov_X)` scores `r`
candidate allocations (rows of the `r×n` integer matrix `indicTs`) against
the covariate matrix `X` (`n×p`) under `"abs_sum_diff"` or `"mahal_dist"`:

1. `sum_all`, `sumsq_all` over `X` — O(np), once. Fine.
2. **`sum_T` accumulation** (`:127-137`): for each subject `i`, copy its row
   into `x_row`, then for each draw `row` with `indicTs(row, i) == 1`, add
   `x_row` into `sum_T[row, ]`. That is a hand-rolled O(r·n·p) triple loop
   with a data-dependent branch per (i, row) — **the dominant cost** (at
   `n = 500, p = 10` it is 5,000 flops per draw). It is, exactly,
   `sum_T = indicTs · X` — one GEMM, which Eigen vectorises and blocks.
3. Per draw (`:139-163`): `diff = mean_T − mean_C` in O(p), then either
   `Σ|diff_j / sd_j|` (abs mode) or the unwhitened quadratic form
   `Σ_i Σ_k diff_i · Sinv(i,k) · diff_k` (`:158-163`) using
   `Rcpp::NumericMatrix::operator()` — bounds-checked, non-vectorised,
   O(p²). At `p = 10` this is 100 multiply-adds per draw: a small term next
   to (2), but with a bad constant.

The sibling `rerandomization_search_cpp()` in the same file (`:185-300`)
already does the right thing for its own loop: centre `X`, Cholesky the
covariance, whiten once (`M = L⁻¹Xᵀ/n`, `:199`), and score each draw with
`(M · dbl_w).squaredNorm()` (`:296-298`). **But** that formulation uses
`dbl_w = 2w − 1` and assumes a balanced `n_T = n/2` allocation (`:188`);
`compute_objective_vals_cpp` accepts arbitrary `n_T` per draw (`nT_by_row`),
so the sibling's `M` cannot be reused verbatim — the whitening has to be
applied to `X` and the mean difference formed per draw.

## The rewrite

Map the R inputs as Eigen (`Map<const MatrixXd> X`, and `indicTs` cast once
to a `MatrixXd` of 0/1 — O(rn), or use a `Map<const MatrixXi>` and
`.cast<double>()` in the product).

- **Mahalanobis mode.** Given `Sinv` (p×p SPD), take its Cholesky
  `Sinv = RᵀR` once (`LLT`, O(p³)); whiten `X_w = X·Rᵀ` once (O(np²));
  then `sum_T,w = indicTs · X_w` (one GEMM, O(rnp)); per draw
  `diff_w = sum_T,w/n_T − (sum_all,w − sum_T,w)/n_C` and
  `val = diff_w.squaredNorm()` — O(p). Algebraically
  `diff_wᵀ diff_w = diffᵀ Rᵀ R diff = diffᵀ Sinv diff`, the same quantity.
  If `LLT` fails (`Sinv` not SPD — it is an inverse covariance so it should
  be, but the R side may pass a pseudo-inverse), fall back to the existing
  unwhitened form computed with Eigen (`diff.transpose() * Sinv * diff`).
- **Abs mode.** `sum_T = indicTs · X` (GEMM), then the existing per-draw
  O(p) loop with `sd_all`; nothing else changes.
- **`n_T` per draw** = row sums of `indicTs` (one O(rn) pass, or
  `indicTs.rowwise().sum()`). Preserve the current behaviour for
  `n_T ∈ {0, n}` (today: division by zero → `Inf`/`NaN`; keep it or return
  `Inf` explicitly so the ranking treats it as worst — document whichever).

Complexity: O(rnp) scalar-with-branches + O(rp²) bounds-checked → O(rnp)
GEMM + O(rp). Expected **5–15×** on this function, almost all from (2).

## Equivalence — read before implementing

The output is **not bit-identical**: GEMM changes the accumulation order of
`sum_T`, and the whitened quadratic form is a different (mathematically
equal) expression. Differences are at the ~1e-13 relative level.

That matters here more than in the other v1.4.0 kernel plans because
`DesignFixedRerandomization` **ranks** these values and keeps the `r`
smallest (`design_fixed_rerandomization.R:71`). Two draws whose objectives
differ by less than the floating-point noise could swap order, changing
*which* allocations are selected for a given seed. This is a legitimate
reproducibility change and must be handled as one:

- Treat it as a documented default change under the release's additive
  constraint, with a CHANGELOG note that rerandomization designs may select
  a different allocation than 1.x at exact objective ties.
- Alternatively, keep the old code path reachable behind an option for one
  release so users can reproduce prior designs; recommendation: **do not**
  — the tie case is measure-zero for continuous covariates, and carrying two
  code paths is worse than one line in the CHANGELOG.
- Tests compare objective *values* to `1e-10` relative, and compare the
  *selected allocations* for equality on fixtures with well-separated
  objectives (assert the minimum gap between adjacent sorted objectives
  exceeds `1e-8` in the fixture, so the equality test is meaningful).

## Items

- [ ] **TODO-1: GEMM for `sum_T`** (both modes). Replace `:127-137` with an
  Eigen product. Keep `sum_all`/`sumsq_all` (or get them as
  `X.colwise().sum()` / `X.colwise().squaredNorm()`). Row sums for `n_T`.
- [ ] **TODO-2: Whitened Mahalanobis.** Cholesky of `Sinv` once, `X_w`
  once, `squaredNorm()` per draw; `LLT` failure falls back to the Eigen
  unwhitened form. Delete the `Sinv(i,k)` scalar loop.
- [ ] **TODO-3: Tests.** `test-rerandomization-objective-vals.R`: (a) values
  vs. the old implementation (retained as a test-only reference) to
  `1e-10` relative, for `p ∈ {1, 3, 10}`, `n ∈ {20, 200}`, `r ∈ {1, 50,
  1000}`, both objectives, unbalanced allocations included; (b) selected
  allocations identical on a well-separated fixture (gap assertion above);
  (c) `n_T ∈ {0, n}` rows behave as documented; (d) a non-SPD `Sinv`
  exercises the fallback; (e) a seeded end-to-end
  `DesignFixedRerandomization` run reproduces the same design before/after
  on the well-separated fixture.
- [ ] **TODO-4: Benchmark.** Old vs. new, `n ∈ {100, 500, 1000}`,
  `p ∈ {3, 10, 20}`, `r ∈ {100, 1000, 10000}`, single thread, `→ TODO-135`
  protocol. Expect 5–15×, growing with `p`. Record in
  `benchmark_model_fits.md`'s design-search section.
- [ ] **TODO-5: Consider unifying with the sibling.** After TODO-1/2, the
  two functions share centring + whitening; extract a helper so the search
  path (`:185+`) and the scoring path cannot drift apart again. Optional.

## Explicitly out of scope

- `rerandomization_search_cpp` itself (already whitened and vectorised).
- OpenMP over draws: the GEMM is already multithreaded by Eigen when
  `Eigen::setNbThreads()` is set (`omp_control.cpp:24`); do not add an
  outer `omp for` on top of it.
- Changing the objective definitions.
