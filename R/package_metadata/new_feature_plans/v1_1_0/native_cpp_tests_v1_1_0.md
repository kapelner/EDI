# Native C++ Tests for v1.1.0 Core Additions

> **Release:** v1.1.0 TODO-193 (`../../future_release_plans/release_v1_1_0.md`). Added 2026-11-10 (owner), as the follow-on to
> `../v1_0_6/native_cpp_test_suite.md` for the C++ this release adds to the R-free (`EDI_CORE_ONLY`) core.
>
> **Depends on:** the v1.0.6 suite (CMake scaffold, CI job, compile rule) existing. Each target below also depends
> on its source plan landing in this release.

## Why

New core C++ in v1.1.0 should arrive with native tests for the things R and Python reach poorly, so the suite grows
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

1. **Phase 2 of the v1.0.6 plan: design-draw thread determinism** (with `release_v1_1_0.md` TODO-48 and
   `cross_platform_reproducibility.md`).
   - First move the parallel draw loops of the greedy, D-optimal, pair-switching and rerandomization kernels into
     `EDI_CORE_ONLY` functions. That refactor is part of this TODO.
   - Then run the same seed at 1, 2 and 8 OpenMP threads in the same binary: the allocations must match bit for
     bit. This guards the v1.0.5 TODO-95 fix.
   - Add `RNG.h` reference vectors: bit for bit in the same binary, D3 tolerance across platforms.
2. **`brent_ci_inversion.md`: the Brent root finder.**
   - A root at a bracket end.
   - No sign change in the bracket: classed failure.
   - A flat function.
   - Tolerance reached vs iteration cap, each with the right stop reason.
   - Agreement with bisection on smooth monotone functions.
3. **`multistart_nonconcave_likelihoods.md` (first tranche): multistart wrappers.**
   - On analytic bimodal objectives, multistart returns the global optimum.
   - It is deterministic for a fixed seed and start set.
   - It reports how many starts converged.
4. **`optimizer_diagnostics_report.md` / `public_diagnostics_api_spec.md`: solver diagnostics filled in C++.**
   - `converged`, the boundary flag and the stop reason are set correctly for each way an optimizer can end (the
     same scenarios as the v1.0.6 target A).
5. **The corrections family** (`bias_correction_cox_snell.md`, `cordeiro_mccullagh_bias_correction_report.md`,
   `score_correction_cordeiro_ferrari.md`, `gradient_correction_lemonte.md`, `likrat_correction_bartlett.md`,
   `firth_penalties_report.md`): only the parts implemented in C++.
   - Check against cases with closed-form answers. For example, the exponential-rate MLE bias, and a finite Firth
     estimate under complete separation in logistic regression.
6. **`quantum_upgrade.md`:** only if its decision gate says build. Test the classical fallback path.

## TODOs

- [ ] TODO-1: For each target above whose source plan is in this release, write the tests in the same change as the
  C++.
- [ ] TODO-2: Move the targets of any plan that slips out of this release into that release's equivalent plan.
- [ ] TODO-3: Sanitizer build clean; CI job green at the release SHA.
