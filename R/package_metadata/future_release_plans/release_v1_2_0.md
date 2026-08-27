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

## Standing constraints

Additive; bit-for-bit defaults (kernel parity tests are the gate); every
new C++ kernel per `sexp_removal_rcppeigen_conversion_spec.md`; targeted
compile only — never `R CMD INSTALL` / `pkgbuild::compile_dll()` /
`load_all(compile = TRUE)`.
