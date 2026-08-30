# OLS Randomization Kernel: Frisch–Waugh–Lovell Per-Replicate Algebra

> **Release:** v1.2.0 (`../future_release_plans/release_v1_2_0.md → TODO-9`;
> 2026-08-30, user decision). Kernel-internal rewrite of
> `src/ols_distr_parallel.cpp`. **Depends on**
> `ols_randomization_distr_cpp_wiring.md` (v1.1.0, `→ TODO-17p`) — until that
> lands the kernel is never executed, so nothing here is measurable. Phase 4
> kernel/perf lane of `_master.md`.

Date: 2026-08-30

## Where the kernel stands after v1.1.0

`compute_ols_distr_parallel_cpp()` already hoists the permutation-invariant
pieces `Xᵀ1` and `X_cᵀX_c` (`ols_distr_parallel.cpp:55-57`). Per replicate
(`:60-103`) it still:

- allocates six Eigen objects on the heap (`w_d`, `y_sim`, `Xt_w`, `XtX`,
  `Xty`, plus the QR's internals);
- forms `Xᵀy_sim` with a full O(np) GEMV even though `y_sim = y + δ·w_b`;
- assembles the full (p+2)×(p+2) `XᵀX` and runs `ColPivHouseholderQR` on it
  — O(p³) with pivoting — to extract a single scalar, `beta[1]`.

At `n = 500, p = 10` the O(np) work is ~5k flops and the QR ~1.7k flops plus
pivot bookkeeping; the allocations and the QR's constant factor dominate,
and none of it vectorises well. Expected kernel-level gain from the rewrite:
**5–10×**. This is a second-order win (the v1.1.0 wiring is the first-order
one), which is why it is in 1.2.0.

## What can and cannot be hoisted — precisely

Write the design as `[X_c | w_b]` with `X_c = [1, X]` fixed and `w_b` the
only column that changes. By Frisch–Waugh–Lovell the coefficient on `w_b` is

    β_T,b = (w_bᵀ M y_sim) / (w_bᵀ M w_b),   M = I − X_c (X_cᵀX_c)⁻¹ X_cᵀ.

With `y_sim = y + δ·w_b`: `w_bᵀ M y_sim = w_bᵀ M y + δ·w_bᵀ M w_b`, so

    β_T,b = (w_bᵀ y_res) / (w_bᵀ M w_b) + δ,     y_res := M y.

**Hoistable (once per call):**
- Cholesky `L` of `X_cᵀX_c` ((p+1)×(p+1)); replaces the per-replicate pivoted
  QR of the (p+2)×(p+2) bordered matrix. Fail the whole call with
  `NA` for every replicate if `X_cᵀX_c` is not SPD — that is a full-data
  rank problem the hardened R side should already have removed.
- `y_res = y − X_c (X_cᵀX_c)⁻¹ X_cᵀ y` — one solve, one GEMV, O(np + p²).
- `Xᵀy` — but note it is no longer needed at all once `y_res` exists; the
  numerator uses `y_res` directly.

**Per replicate (unavoidable):**
- Numerator `w_bᵀ y_res = Σ_{i: w_b[i]=1} y_res[i]` — an O(n) masked sum, no
  GEMV.
- Denominator `w_bᵀ M w_b = n_T,b − ‖L⁻¹ X_cᵀ w_b‖²` — one O(np) GEMV
  (`X_cᵀ w_b`, which is `[n_T, Σ_{treated} X]`, computable as a masked
  column sum rather than a GEMV) and one O(p²) forward triangular solve.
  **This term cannot be hoisted**: permuting `w` changes its projection onto
  the covariate space, so `w_bᵀ M w_b` genuinely differs across replicates.
  The FWL framing is sometimes read as "residualise once"; that is true of
  `y`, not of `w_b`.
- `+ δ` — O(1), and exact.

**Complexity:** O(np + p³) with pivoting and six allocations → O(np + p²)
with zero allocations per replicate (per-thread scratch of size p+1,
allocated once inside `#pragma omp parallel`, as `ridit_distr_parallel.cpp:132`
does).

## Equivalence and guards

- Same estimator to floating point. FWL is an algebraic identity; the
  differences are accumulation order and Cholesky vs. pivoted QR. Test
  tolerance `1e-10` relative on `t0s`, as in the v1.1.0 wiring tests.
- **Rank guard.** ColPivQR's `rank()` detected per-replicate collinearity of
  `w_b` with `X_c`. In the FWL form that shows up as `w_bᵀ M w_b ≈ 0`.
  Return `NA` when `w_bᵀ M w_b ≤ ε · n_T,b` (ε ≈ 1e-12; `n_T` is the
  natural scale since `w_bᵀ M w_b ≤ n_T`), and when `n_T,b ∈ {0, n}`. Also
  keep `min(diag(L)) > ε` at hoist time. These must reproduce the `NA`
  pattern of the v1.1.0 kernel on the singular-permutation test fixture.
- **Bit-for-bit is not the goal**; this is a documented numerics change
  with tolerances, same policy as the wiring plan.

## Items

- [ ] **TODO-1: Rewrite the loop.** Hoist `L`, `y_res`; per replicate
  compute `n_T`, the masked sums `Σ_treated y_res` and `Σ_treated X` (one
  pass over `n`), the triangular solve, the denominator, the guard, and
  `num/den + δ`. Per-thread scratch vectors allocated once. Keep the OpenMP
  structure and `should_parallelize_replicates()` threshold unchanged.
  Targeted compile of this one file only, per `CLAUDE.md`.
- [ ] **TODO-2: Tests.** Extend `test-ols-rand-distr-kernel.R` from the
  wiring plan: the rewritten kernel vs. the reused-worker path to `1e-10`
  on sorted `t0s` at `p ∈ {0, 1, 5, 10}`, `harden ∈ {TRUE, FALSE}`,
  `δ ∈ {−1, 0, 0.5}`; identical `NA` pattern on the singular-permutation
  fixture; identical `NA` for all-treated / all-control permutations;
  `p = 0` (denominator reduces to `n_T·n_C/n`, numerator to
  `Σ_treated (y − ȳ)` — check against the closed-form mean difference).
- [ ] **TODO-3: Benchmark.** Kernel-only microbenchmark (`benchmark/*.cpp`
  style) old vs. new at `n ∈ {100, 500, 1000, 5000}`, `p ∈ {0, 5, 10, 20}`,
  `B = 1000`, single thread, under the `→ TODO-135` noise protocol. Expect
  5–10× at `p = 10`; the gap widens with `p` (the p³ term) and narrows at
  `p = 0`. Record in `benchmark_model_fits.md`.
- [ ] **TODO-4: Same treatment for the bootstrap sibling** if
  `compute_ols_bootstrap_parallel_cpp` was wired in by the v1.1.0 plan.
  There the rows change, so `X_cᵀX_c` is *not* hoistable; the honest
  shortcut is the multinomial-weight form `X_cᵀ diag(c_b) X_c` with counts
  `c_b`, built by one DSYRK-style accumulation over the n distinct rows
  (O(np²)) instead of materialising the resampled matrix. Separate
  microbenchmark; skip if the wiring plan deleted the kernel.
- [ ] **TODO-5 (optional): Lin.** If the wiring plan's stretch item left Lin
  on the reused-worker path, do the Lin kernel here using the same FWL
  structure with `X_c = [1, Xc]` fixed and the changing block
  `[w_b, w_b·Xc]` — a (p+1)-column update rather than one column, so the
  denominator becomes a (p+1)×(p+1) Schur complement solve per replicate,
  still O(np + p³) but without pivoting or allocation.

## Explicitly out of scope

- Reusing the δ = 0 distribution across bisection steps — that is
  `randomization_ci_affine_shift_reuse.md` (v1.1.0), and the `+ δ` term here
  is exactly what makes it valid.
- Fixed-size Eigen specialisation of the (p+1)×(p+1) solve —
  `fixed_size_eigen_small_p.md`; if that plan's TODO-1 gate passes, this
  kernel is a natural first customer.
