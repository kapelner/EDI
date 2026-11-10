# Native C++ Tests for the v4.0.0 Shared Core

> **Release:** v4.0.0 TODO-4 (`../../future_release_plans/release_v4_0_0.md`). Added 2026-11-10 (owner), as the follow-on to
> `../v1_0_6/native_cpp_test_suite.md` for the C++ this release adds to the R-free (`EDI_CORE_ONLY`) core.
>
> **Depends on:** the v1.0.6 suite (CMake scaffold, CI job, compile rule) existing. Each target below also depends
> on its source plan landing in this release.

## Why

New core C++ in v4.0.0 should arrive with native tests for the things R and Python reach poorly, so the suite grows
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

1. **Move the suite** from `cpp_tests/` to `core/tests/` alongside the core move
   (`migrate_EDI_into_shared_cpp_backend.md` → "Repository layout").
   - Update the CLAUDE.md whitelist path in the same change.
2. **C ABI contract tests.**
   - Handle lifecycle: create, use, free, double free, use after free (ASan must catch misuse in test builds).
   - Every status and error code is reachable and classed.
   - Versioned struct layout: an old-version struct is accepted or rejected as specified.
   - No C++ exception crosses the ABI.
   - Buffer ownership rules hold.
3. **Inference-engine layers** (score/LR tests, CI inversion, the bootstrap and randomization executors).
   - Native results match the R reference goldens within D2.
   - Executors are deterministic for a fixed seed and give the same result at any thread count in the same binary.
4. **Binding smoke tests** (`more_language_bindings.md`).
   - A minimal C caller links the ABI and runs one fit and one test, so each new language binding starts from a
     known-good C path.

## TODOs

- [ ] TODO-1: For each target above whose source plan is in this release, write the tests in the same change as the
  C++.
- [ ] TODO-2: Move the targets of any plan that slips out of this release into that release's equivalent plan.
- [ ] TODO-3: Sanitizer build clean; CI job green at the release SHA.
