# Release Scope: v1.2.0 — Performance, Kernels, and Engines

> **Depends on:** `release_v1_1_0.md`. Release index over plans in
> `../new_feature_plans/`; not new work of its own. (Global ordering: see
> `../new_feature_plans/_master.md`.)

Rewritten 2026-08-27 (user decision: the 1.x backlog is split
thematically into 1.1.0 inference quality / **1.2.0 performance &
engines** / 1.3.0 design theory / 1.4.0 response & data extensions;
2.0.0 remains the architecture release). Rule for all 1.x releases:
improvements on the current codebase plus simple additions on the
existing architecture and the six scalar response types; every default
reproduces the prior release bit-for-bit.

**Theme.** Everything that makes existing classes faster or replaces an
R/Fortran dependency path with an exact-parity native kernel, plus the
one engine-level design refactor (the greedy merge) that later design
work builds on. No new statistical functionality.

## In scope (by plan)

`ols_distr_kernel_fwl.md` (added 2026-08-30; `→ TODO-1..5`; see `TODO-9`
below) — FWL per-replicate algebra for the OLS randomization kernel, gated on
v1.1.0's wiring of that kernel.

`kk14_incremental_covariance.md` (added 2026-08-30; `→ TODO-1..5`; see
`TODO-10` below) — O(p²)-per-subject running covariance for the sequential
KK14 matching design, replacing O(t·p²) recomputation.

- `quantile_regression_cpp_kernel_spec.md` — Barrodale-Roberts simplex
  port of `quantreg::rq.fit(method = "br")` and the `nid`/`iid` sandwich
  SEs, `use_rcpp` on all quantile classes (incl. the 1.1.0 count-QR and
  1.4.0 survival-QR classes once they exist).
- `ordinal_gee_cpp_kernel_spec.md` — native ordinal GEE kernel replacing
  `multgee::ordLORgee` in `InferenceOrdinalKKGEE`.
- `robust_regression_perf_optimization_spec.md` — bootstrap-loop
  allocation and warm-start work for the M/MM-regression classes.
- `cold_starts.md` — smart cold-start strategies across the optimizer-
  based kernels.
- `design_fixed_greedy_pair_switch_merge.md` — merge `DesignFixedGreedy`
  + `DesignFixedGreedyDOptimal` into `DesignFixedGreedyPairSwitch` with the
  general-`prob_T` swap-delta rederivation; **soft-deprecation only**
  (aliases + warnings for the two old names); the hard deletion is
  `release_v2_0_0.md → TODO-7`. This is the engine that 1.3.0's unequal-
  allocation and objective-extension plans extend.
- `parallel_fork_cluster_test_safety.md` — fully closed (6/6); move to
  `../finished_features/` as part of this release's housekeeping.
- `arm_hardware.md` — AArch64/Apple Silicon first-class targeting,
  compiler-target detection, Accelerate/BLAS dispatch, and portable fallback
  behavior.
- `intel_hardware.md` — Intel AMX/matrix-engine detection and size-gated GEMM
  dispatch, sharing the architecture-neutral dense-linear-algebra backend
  with the ARM plan.
- `memory_side_improvements.md` — NUMA placement, first-touch allocation,
  huge-page advice, HBM/Xeon Max handling, and portable stubs when OS/runtime
  capabilities are unavailable.

## Implementation TODOs (dependency order)

Ticked in owning plans; this list is the index.

- [ ] TODO-1: **Quantile-regression kernel**
  `quantile_regression_cpp_kernel_spec.md → TODO-1..6` (LP solver →
  weighted → SEs → R integration → parity suite → audit rows).
- [ ] TODO-2: **Ordinal GEE kernel** `ordinal_gee_cpp_kernel_spec.md →
  TODO-1..5`.
- [ ] TODO-3: **Robust-regression perf**
  `robust_regression_perf_optimization_spec.md → TODO-1..4` (profile
  before SIMD).
- [ ] TODO-4: **Cold starts** `cold_starts.md → TODO-2..14`.
- [ ] TODO-5: **Greedy engine merge** `design_fixed_greedy_pair_switch_merge.md
  → TODO-1..10` — TODO-2's `pair_mode` investigation first (its
  relationship to `DesignFixedMatchingGreedyPairSwitching` decides how
  1.3.0's unequal-allocation plan handles matched pairs); deprecation
  shims, not deletions.
- [ ] TODO-6: Move `parallel_fork_cluster_test_safety.md` to
  `../finished_features/`.
- [ ] TODO-7: **Release mechanics** per `release.md`.
- [ ] TODO-8: **Architecture-specific CPU and memory engines**
  `arm_hardware.md → TODO-1..` (AArch64/Apple/Graviton/Grace detection and
  dispatch), `intel_hardware.md → TODO-1..` (AMX capability checks and GEMM
  thresholds), and `memory_side_improvements.md → TODO-1..` (NUMA/HBM/huge
  pages). Extract shared detection, dispatch, benchmark, and override logic
  once; retain scalar/portable fallbacks and require benchmark evidence before
  changing defaults.

- [ ] TODO-9: **OLS randomization kernel FWL rewrite** (added 2026-08-30,
  user decision): `ols_distr_kernel_fwl.md → TODO-1..5`. Rewrites the
  per-replicate algebra of `compute_ols_distr_parallel_cpp`
  (`src/ols_distr_parallel.cpp:60-103`): hoist the Cholesky of `X_cᵀX_c`
  and `y_res = My` once; per replicate only a masked sum for the numerator
  `w_bᵀy_res`, one masked column sum plus one O(p²) triangular solve for
  the denominator `w_bᵀMw_b` (which cannot be hoisted — permuting `w`
  changes its residual), then `num/den + δ`. O(np + p³) with pivoted QR and
  six heap allocations → O(np + p²) with none. Same estimator to floating
  point; rank guard on `w_bᵀMw_b ≈ 0` replaces ColPivQR's `rank()`.
  Expected 5–10× on the kernel. **Depends on** v1.1.0's
  `ols_randomization_distr_cpp_wiring.md` (`release_v1_1_0.md → TODO-17p`)
  — the kernel is never executed until that lands. Optional TODO-4/5 cover
  the bootstrap sibling (multinomial-weight form) and Lin.
- [ ] TODO-10: **Sequential KK14 incremental covariance** (added 2026-08-30,
  user decision): `kk14_incremental_covariance.md → TODO-1..5`. Per
  arriving subject, `DesignSeqOneByOneKK14$assign_wt()` recomputes from
  scratch on all previous subjects: `compute_all_subject_data_cpp` (copy +
  varying-column scan + rank-revealing QR, O(t·p²)), `var(X_prev)`
  (O(t·p²)), then `solve()` (O(p³)) — O(n²·p²) over a run, plus an O(n²·p)
  per-`t` cache. Maintain the centred scatter matrix incrementally (Welford
  form, O(p²) per subject; the naive `Σxxᵀ − t·x̄x̄ᵀ` is rejected because the
  code already notes `diag ~ 1e6` covariate scales), track varying columns
  and rank monotonically so the QR runs only on change, and keep a
  reservoir-only `X_prev`. Expected 5–10× on a sequential run at `n = 1000`,
  growing with `n`; KK21 shares the `compute_all_subject_data()` path and
  benefits too. Sherman–Morrison on the inverse is explicitly out of scope
  (the regulariser changes every step; O(p³) is negligible at `p ≤ 20`) —
  and the class's unused `morrison` argument is Morrison & Owen threshold
  calibration, not Sherman–Morrison. Tolerance-equal; match decisions at
  exact distance ties are a documented reproducibility change.
## Standing constraints

Additive; bit-for-bit defaults (kernel parity tests are the gate); every
new C++ kernel per `sexp_removal_rcppeigen_conversion_spec.md`; targeted
compile only — never `R CMD INSTALL` / `pkgbuild::compile_dll()` /
`load_all(compile = TRUE)`.
