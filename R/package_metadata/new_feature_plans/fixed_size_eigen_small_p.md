# Fixed-Size Eigen Specializations for Small `p`

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-4d`;
> 2026-08-30, user decision). Phase 4 kernel/perf lane of `_master.md`,
> alongside `performance_profiling_and_upgrades.md` §8 (`→ TODO-4b`) and
> `more_simd_optimization.md` (`→ TODO-4c`). No Phase 0 dependency;
> measurement-first, and gated on its own TODO-1 benchmark.
>
> **Ownership split (no duplication):** `performance_profiling_and_upgrades.md
> → TODO-155` owns the *audit* of which decompositions/inversions run at
> which sizes (and already names "a fixed-size `Matrix<double,2,2>` would
> do" as one of its findings). This file owns the *general mechanism* —
> a compile-time-`p` dispatch for the IRLS/Newton inner algebra — and
> consumes TODO-155's list of candidate call sites rather than re-auditing.

Date: 2026-08-30

## Premise

Every model-fit kernel in `src/` does its per-iteration algebra on fully
dynamic Eigen types (`MatrixXd`/`VectorXd`: ~1,500 uses across `src/*.cpp`).
The only fixed-size or bounded-size Eigen types in the tree are three
hand-placed exceptions: `Matrix2d`/`Vector2d` in `kk21_weights.cpp:803-807`
and a `MaxRows=2` bounded vector in `fast_gaussian_lmm.cpp:200-202` (comment
there: "tells Eigen to use internal fixed storage even for dynamic size").

Eigen generates materially better code when a dimension is known at compile
time: no heap allocation for temporaries, fully unrolled `p×p` products and
solves, no runtime loop bounds, and vectorization over the small dimension.
For the `p×p` pieces of an IRLS/Newton step — `XᵀWX` accumulation, the
Cholesky/LDLᵀ solve, the step `H⁻¹g`, the score update — this is typically a
2–3× win on that algebra at `p ≤ 8`. It does **not** touch the `O(np)` passes
over the data (link/variance evaluation, residuals), which are already the
dominant cost at `n` in the hundreds, so the end-to-end fit speedup is
smaller than the per-step algebra speedup and must be measured, not assumed.

Cost side: every specialized kernel becomes a template instantiated once per
supported `p`, plus the dynamic fallback. That is compile time (already
mitigated by the unity build, `EDI_UNITY=1`), binary size, and a second code
path to keep bit-for-bit equivalent with the dynamic one. The honest prior
is **real headroom, questionable ROI at EDI's scale**; TODO-1 exists to
settle it with numbers before any kernel is touched.

## Items

- [ ] **TODO-1: Microbenchmark the mechanism in isolation (gate).** One
  standalone C++ harness (under `benchmark/`, same style as the existing
  `benchmark/*.cpp`): a synthetic IRLS step — `XᵀWX`, LDLᵀ solve, `H⁻¹g` —
  for `p ∈ {2, 3, 4, 5, 6, 8, 10}` and `n ∈ {100, 500, 1000}`, dynamic vs.
  `Matrix<double, Dynamic, P>` / `Matrix<double, P, P>`, single-threaded,
  pinned, under the `→ TODO-4b` noise-floor protocol
  (`performance_profiling_and_upgrades.md → TODO-135`). Report per-step and
  whole-fit (including the `O(np)` link pass) speedups. **Exit:** a table
  with the `p` at which the per-fit gain drops below 10%; if that `p` is
  ≤ 3, or the whole-fit gain never exceeds 10%, record "measured and
  dropped" here and skip TODO-2..5.
- [ ] **TODO-2: Dispatch design.** A single helper, e.g.
  `template<int P> fit_irls_fixed(...)` plus
  `dispatch_on_p(p, [&](auto P_tag){...})` that switches on runtime `p` to a
  compile-time `P` for `P ≤ P_MAX` (from TODO-1) and falls through to the
  existing dynamic path otherwise. Lives in `_helper_functions_core.h` so it
  is `EDI_CORE_ONLY`-compatible (Rcpp-free, per
  `sexp_removal_rcppeigen_conversion_spec.md`). No kernel changes yet.
- [ ] **TODO-3: Apply to the two highest-traffic kernels first.** `fast_ols`
  and `fast_logistic_regression` (the kernels every bootstrap/randomization
  replicate loop and `SimulationFramework` hit most). Bit-for-bit equivalence
  against the dynamic path on the existing fixtures; the fixed-size path
  must produce identical results, not tolerance-equal, because it is the
  same arithmetic in a different order only if care is taken (accumulation
  order in `XᵀWX` must match). Re-run `→ TODO-1`'s whole-fit numbers on the
  real kernels.
- [ ] **TODO-4: Extend to the rest of the GLM family** (Poisson, negbin,
  probit, log-binomial, beta, ordinal links) only if TODO-3's end-to-end
  gain holds on real fits; otherwise stop at TODO-3 and record why.
- [ ] **TODO-5: Build-cost accounting.** Before/after `configure` + install
  wall time and `.so` size under `EDI_UNITY=1`; if instantiations push
  install time up by more than ~15%, cap `P_MAX` lower or drop the
  lowest-traffic kernels from TODO-4.

## Explicitly out of scope

- The `O(np)` data passes (link/variance/residual loops) — those are
  `more_simd_optimization.md` / `→ TODO-4b` territory.
- Any change to results: the fixed-size path must be bit-for-bit with the
  dynamic path (v1.1.0 additive constraint). If it cannot be made so, it
  ships behind a build flag, not as the default.
- Runtime ISA dispatch — settled as "not needed" in
  `more_simd_optimization.md`.
