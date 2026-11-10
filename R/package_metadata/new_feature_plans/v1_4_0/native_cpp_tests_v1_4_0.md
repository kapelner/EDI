# Native C++ Tests for v1.4.0 Core Additions

> **Release:** v1.4.0 TODO-19 (`../../future_release_plans/release_v1_4_0.md`). Added 2026-11-10 (owner), as the follow-on to
> `../v1_0_6/native_cpp_test_suite.md` for the C++ this release adds to the R-free (`EDI_CORE_ONLY`) core.
>
> **Depends on:** the v1.0.6 suite (CMake scaffold, CI job, compile rule) existing. Each target below also depends
> on its source plan landing in this release.

## Why

New core C++ in v1.4.0 should arrive with native tests for the things R and Python reach poorly, so the suite grows
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

1. **New likelihood kernels:** apply the standard checks above to each.
   - `censored_continuous_response.md`, `censored_count_response.md`, `betaregscale_duplication.md`: also check the
     interval-censored likelihood against numerical integration on small cases.
   - `full_glmm_for_weibull_frailty.md`: k-strata frailty with one stratum equals the existing single-stratum kernel.
   - `kk_beta_regression_one_lik_derivation.md`.
   - `cure_fraction_survival_inference.md` (native kernel only): a cure fraction of 0 reduces to Weibull AFT.
   - `survival_quantile_regression.md` (self-consistent EM): EM step monotonicity; with no censoring it reduces to
     ordinary quantile regression.
   - `competing_risks_response.md` (counting-process Cox kernel, if it lands here): one cause reduces to ordinary
     Cox.
2. **`l1_l2_penalties_all_likelihood_paths_report.md`.**
   - The KKT conditions hold at the solution.
   - A zero penalty equals the unpenalized fit.
   - The solution path is continuous in lambda.
3. **The hoisting batch** (`wilcox_hl_kernel_hoisting.md`, `kk_signed_rank_hoisting.md`,
   `ridit_kernel_level_slots.md`, `small_kernel_hoists_batch.md`, `rerandomization_objective_vals_gemm.md`).
   - Each hoisted kernel equals its pre-hoist reference bit for bit in the same binary, which is what those plans
     promise.
   - Keep the pre-hoist reference as a test-only copy.

## TODOs

- [ ] TODO-1: For each target above whose source plan is in this release, write the tests in the same change as the
  C++.
- [ ] TODO-2: Move the targets of any plan that slips out of this release into that release's equivalent plan.
- [ ] TODO-3: Sanitizer build clean; CI job green at the release SHA.
