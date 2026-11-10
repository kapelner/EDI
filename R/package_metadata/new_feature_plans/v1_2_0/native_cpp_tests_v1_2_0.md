# Native C++ Tests for v1.2.0 Core Additions

> **Release:** v1.2.0 TODO-37 (`../../future_release_plans/release_v1_2_0.md`). Added 2026-11-10 (owner), as the follow-on to
> `../v1_0_6/native_cpp_test_suite.md` for the C++ this release adds to the R-free (`EDI_CORE_ONLY`) core.
>
> **Depends on:** the v1.0.6 suite (CMake scaffold, CI job, compile rule) existing. Each target below also depends
> on its source plan landing in this release.

## Why

New core C++ in v1.2.0 should arrive with native tests for the things R and Python reach poorly, so the suite grows
with the core instead of being retrofitted at v4.0.0.

## Conventions (same as v1.0.6)

Framework: **Catch2 v3**, vendored under `cpp_tests/third_party/` (owner decision 2026-11-10). See
`../v1_0_6/native_cpp_test_suite.md` → "Layout" for the float-matcher and `GENERATE` conventions.

These follow `../v1_0_6/native_cpp_test_suite.md`:

- Tests live in `cpp_tests/` (`core/tests/` from v4.0.0).
- Each CMake target lists only the `EDI_CORE_ONLY` sources it needs. The CLAUDE.md whitelist depends on this.
- Every new target also runs in the ASan/UBSan build.
- Do not copy the R/Python result tests. Test what testthat and pytest reach poorly: invariants, identities,
  edge cases, dispatch variants, memory safety.
- Same-binary comparisons may be bit for bit. Comparisons across platforms or devices use the D2/D3 tolerances
  (`../v1_1_0/cross_platform_reproducibility.md`).
- A target for a plan is written in the same change that adds that plan's C++, not afterwards. If a listed plan
  slips to another release, its targets move with it.

### Standard checks for any new likelihood kernel

- Analytic gradient and Hessian vs central finite differences at several random points, including near the
  parameter boundary.
- The log-likelihood is finite, or the failure is classed (not a crash), on degenerate inputs: all-equal
  response, a single observation per group, zero weights.
- Weights of all 1 reproduce the unweighted fit (same binary: bit for bit).

## Targets

1. **Dispatch variants** (`more_simd_optimization.md`, `fixed_size_eigen_small_p.md`,
   `memory_layout_row_major_irls.md`, `arm_hardware.md`, `intel_hardware.md`).
   - Force each code path in turn (SIMD vs scalar, fixed-size vs dynamic Eigen, row- vs column-major, AMX/NEON
     vs generic) in one binary.
   - Every path must match the scalar reference within D2. This is the most valuable target in this release:
     R and Python only ever run whichever path the machine picks.
2. **`quantile_regression_cpp_kernel_spec.md`: Barrodale-Roberts simplex.**
   - On small n, the objective equals a brute-force search over basic solutions.
   - Degenerate cases: an exact fit, a tied response, quantiles 0 and 1. Each returns a finite result or a classed
     failure.
3. **`ordinal_gee_cpp_kernel_spec.md`.**
   - The estimating equations are zero at the solution.
   - Working-correlation edge cases: one cluster, clusters of size 1, independence equals GLM.
4. **`robust_regression_perf_optimization_spec.md`.**
   - The weight functions behave correctly at their thresholds.
   - IRLS has the same fixed point as the pre-optimization reference.
5. **`kk14_incremental_covariance.md`.**
   - After k incremental updates the covariance matches a batch recompute within D2.
   - Rank-deficient updates are handled.
6. **`exact_randomization_nulls_closed_form.md`, `exact_rank_tests_shift_algorithm.md`.**
   - For small n, the exact null distribution and p-values equal brute-force enumeration of every assignment.
7. **`ols_distr_kernel_fwl.md`.**
   - The Frisch-Waugh-Lovell (FWL) treatment coefficient equals the full-regression coefficient.
8. **`em_algorithm_zero_inflated_mixtures.md`.**
   - EM never decreases the log-likelihood.
   - EM-then-Newton reaches the same optimum as Newton from a good start.
9. **`cold_starts.md`.**
   - Every start heuristic gives finite values on edge data (all zeros, separation, one level).
10. **`ordinal_*_bayesian_bootstrap.md` (three plans).**
    - Weighted refits with all weights 1 equal the unweighted fit.
    - A zero weight equals dropping that row.
11. **`garthwaite_buckland_ci_search.md`, `randomization_ci_search_precision.md`:** only the parts implemented in
    C++. Test search convergence on known monotone p-value curves.

## TODOs

- [ ] TODO-1: For each target above whose source plan is in this release, write the tests in the same change as the
  C++.
- [ ] TODO-2: Move the targets of any plan that slips out of this release into that release's equivalent plan.
- [ ] TODO-3: Sanitizer build clean; CI job green at the release SHA.
