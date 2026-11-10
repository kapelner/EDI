# Native C++ Tests for v2.0.0 Core Additions

> **Release:** v2.0.0 TODO-10 (`../../future_release_plans/release_v2_0_0.md`). Added 2026-11-10 (owner), as the follow-on to
> `../v1_0_6/native_cpp_test_suite.md` for the C++ this release adds to the R-free (`EDI_CORE_ONLY`) core.
>
> **Depends on:** the v1.0.6 suite (CMake scaffold, CI job, compile rule) existing. Each target below also depends
> on its source plan landing in this release.

## Why

New core C++ in v2.0.0 should arrive with native tests for the things R and Python reach poorly, so the suite grows
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

1. **Device back ends** (`gpu_optimizations.md`, `npu_ai_engine_optimizations.md`, if their decision gates say
   build).
   - Device results match the CPU reference within each plan's stated tolerance.
   - With no device present, the code falls back to CPU and records the reason.
   - Allocation failures on the device are handled.
   - These tests skip, rather than fail, on CI runners with no device. Run them on hardware before each release.
2. **New response-type kernels** (`censored_ordinal_response_models.md`, `multivariate_response_type_report.md`,
   `multivariate_response_modeling.md`, `longitudinal_repeated_measures_response_type_report.md`,
   `compositional_response_type_report.md`, `rank_choice_response_type_report.md`): apply the standard checks
   above.
   - One endpoint or one time point must reduce to the existing univariate kernel.
3. **`streaming_inference.md`** (C++ parts).
   - Incremental updates equal a batch recompute.
   - The result does not depend on chunk boundaries.
4. **`sequential_inference.md`** (C++ parts).
   - Interim-look boundaries match published tables for the standard spending functions.

## TODOs

- [ ] TODO-1: For each target above whose source plan is in this release, write the tests in the same change as the
  C++.
- [ ] TODO-2: Move the targets of any plan that slips out of this release into that release's equivalent plan.
- [ ] TODO-3: Sanitizer build clean; CI job green at the release SHA.
