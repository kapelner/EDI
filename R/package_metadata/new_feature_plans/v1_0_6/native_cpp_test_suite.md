# Native C++ Test Suite for the R-Free Core

> **Release:** v1.0.6 TODO-15 (`../../future_release_plans/release_v1_0_6.md`). Owner decision 2026-11-10,
> taken as an exception to that file's entry rule (new test infrastructure normally waits for v1.1.0). Phase 1
> adds tests and a CI job only. No package code, API or result changes.
>
> **Depends on:** none for Phase 1. Phase 2 needs a refactor of the design kernels, so it is **not** v1.0.6
> scope; it is recorded here so it is not lost.
>
> **Related:**
> - `../v4_0_0/migrate_EDI_into_shared_cpp_backend.md` → "Repository layout": this suite moves to `core/tests/`
>   when the R-free core moves to `core/`.
> - `../v1_1_0/cross_platform_reproducibility.md` (`release_v1_1_0.md` TODO-48).
> - `../../bug_fix_plans/v1_0_5/design_draws_depend_on_thread_count.md` (v1.0.5 TODO-95, closed).
> - `scripts/check_core_no_rcpp.py`: checks that the core includes no R headers. This suite checks that the core
>   builds, runs and behaves.

## Why

Every C++ kernel is tested today only through R (testthat) or Python (pytest, partly against R goldens). That
leaves gaps:

- **Templated internals are reached only through whole model fits.** `optimize_likelihood_newton` and the
  helpers in `_helper_functions_core.h` carry the v1.0.5 G1 fixes (patch 01's Newton-stall fix), but their edge
  cases are hard to set up from R: a stalled step, a non-descent direction, a maximum on the boundary,
  non-finite input. The same goes for the Cox Newton descent guard (patch 08).
- **Sanitizers and fuzzing are slow through R.** ASan, UBSan and libFuzzer run much faster on a native binary.
  Most memory bugs found so far (the probit lbfgs use-after-free, the unprotected temporaries in KK21) were in
  kernel code.
- **No one runs the R-free surface as it is.** `EDI_CORE_ONLY` code is compiled only inside the Python wheel.
  The v4.0.0 migration will build on it, so regressions there should be caught now.

What this suite is **not**: a C++ copy of the kernel-result tests. testthat and pytest already check fitted
values against goldens. Duplicating them adds maintenance and catches nothing new.

## Feasibility (checked 2026-11-10)

- The R-free core is the `EDI_CORE_ONLY` surface: 63 files in `R/EDI/src` carry the guard. `python/CMakeLists.txt`
  already builds about 40 kernels from it with `EDI_SRC_DIR` set to `../R/EDI/src`. Reuse that source list rather
  than keeping a second one (for example, factor it into a shared `.cmake` file both builds include).
- `_helper_functions_core.h` is in the core (8 `EDI_CORE_ONLY` guards; used by the Python build), so the
  optimizer targets are buildable natively.
- `fast_coxph_regression.cpp` has core-only parts (4 guards) and is in the Python build.
- **Not buildable natively yet:**
  - The design kernels (`design_fixed_greedy.cpp`, `design_optimal_annealing_search.cpp`,
    `rerandomization_helpers.cpp`, `optimal_design_search.cpp`) use Rcpp throughout and have no core-only path.
  - `RNG.h` has no core-only guard. It is extracted from R's GPL sources and is used only by the R build.
  - Both are Phase 2.

## Layout

```text
cpp_tests/                 root; moves to core/tests/ at v4.0.0
  CMakeLists.txt           builds the EDI_CORE_ONLY sources from R/EDI/src + the test binaries
  optimizer/               Phase 1 target A
  cox/                     Phase 1 target B
  fuzz/                    Phase 1 target C (libFuzzer harnesses)
  README.md                how to build and run; the compile rule below
```

**Framework: Catch2 v3** (owner decision, 2026-11-10), run through CTest (`catch_discover_tests`).

- Vendor the amalgamated `catch_amalgamated.hpp`/`.cpp` pair at a pinned release under `cpp_tests/third_party/`.
  Don't use CMake `FetchContent`: sandboxed agents have no network, and vendoring keeps CI reproducible.
- Compile the amalgamated `.cpp` once, as its own static library, shared by every test target.
- Float checks:
  - `WithinRel`/`WithinAbs` for D2-tolerance comparisons;
  - `WithinULP` or plain `==` for same-binary bit-for-bit comparisons.
- Edge-case tables use `GENERATE` and `SECTION`.
- Catch2 has no death tests. Where a test must crash (v4.0.0 ABI misuse), rely on the sanitizer build, or register
  a CTest test with `WILL_FAIL`.

Why Catch2 over GoogleTest:

- It has built-in matchers for both comparison kinds above. GoogleTest has only `EXPECT_NEAR` and a fixed 4-ULP
  `EXPECT_DOUBLE_EQ`.
- Edge-case tables take less boilerplate than GoogleTest's `TEST_P`.
- The vendored pair is small.
- GoogleTest's extras (death tests, GMock) aren't needed for testing pure functions.

## Phase 1 (v1.0.6)

### Target A: optimizer edge cases (`_helper_functions_core.h`)

Direct tests of `optimize_likelihood_newton` and its Newton-then-L-BFGS fallback on small analytic objectives with
known optima:

- a step that stalls before the gradient tolerance (patch 01's false non-convergence): it must report
  `converged = false`, not `true`;
- a non-descent Newton direction: it must fall back, not accept the step;
- an optimum on the parameter boundary;
- non-finite objective, gradient or Hessian on entry and mid-run: classed failure, no crash;
- the gradient-tolerance stop vs the max-iteration stop, each reporting the right reason.

### Target B: Cox Newton descent guard (`fast_coxph_regression.cpp`, core-only parts)

The patch-08 descent guard and the patch-08c backward-sum negative log-likelihood, tested on tiny risk sets where
the exact values can be worked out by hand:

- all ties;
- a single event;
- an empty risk set at the last time.

### Target C: sanitizers and fuzzing

- ASan and UBSan builds of every Phase 1 test, in CI.
- libFuzzer harnesses for two or three kernel entry points that take raw arrays (design matrix, response, weights).
  They feed random shapes, NaN/Inf and extreme values, and the kernel must either return a classed failure or a
  finite result, never crash or read out of bounds. Run locally and as a short CI job (time-boxed, for example
  60 s per harness); keep a corpus of past crashes as regression cases.

### CI

One new workflow job, separate from the R and Python jobs:

- CMake configure, build, ctest;
- a second build with `-fsanitize=address,undefined` running the same tests plus the time-boxed fuzz run;
- Linux first; add macOS if the Python wheel matrix already covers it cheaply.

It does not become a required check until it has been green for a few weeks.

### Compile rule (CLAUDE.md)

Building this suite compiles `R/EDI/src` files. `CLAUDE.md` whitelists it (owner, 2026-11-10) only for the subset of
files each test needs. Agents:

- build only the target being worked on, never `all`;
- use a build directory outside the checkout (`$TMPDIR`);
- never touch `EDI.so`, `configure`, the R package or the Python wheel;
- cap the build at `-j2`;
- time-box fuzz runs at 60 s.

So each CMake test target must list **only the `EDI_CORE_ONLY` sources it needs**, not the full shared core list.
TODO-2's shared source list is for the Python build and for CI's full run; per-target lists are subsets of it.

## Phase 2 (not v1.0.6; needs a refactor first)

Thread-count determinism of design draws: run the same seed at 1, 2 and 8 OpenMP threads in the same binary and
compare the allocations bit for bit (allowed under D3: same binary).

- This is a regression guard for the v1.0.5 TODO-95 fix (seeded per draw index, not per thread).
- It needs the parallel draw loops of the greedy, D-optimal, pair-switching and rerandomization kernels split into
  `EDI_CORE_ONLY` functions with no Rcpp.
- That split is a refactor, so it belongs in v1.1.0 (with `cross_platform_reproducibility.md`, TODO-48 there) or in
  the v4.0.0 migration, not here.
- `RNG.h` reference vectors belong to the same phase. Per owner decision D3 (`cross_platform_reproducibility.md`),
  require bit-for-bit only within the same binary. Across platforms, compare under D3's tolerances, because libm
  differs (glibc/Apple/UCRT) and Apple arm64 contracts floating-point operations.

## Done when (Phase 1)

- `cpp_tests/` builds with CMake from a clean checkout, reusing the Python build's core source list.
- Targets A and B pass.
- The sanitizer build runs them clean.
- Each fuzz harness runs its time box without a finding, or every finding is fixed or filed as a TODO.
- The CI job is green on the commit that adds it.
- Every test target builds from its own minimal source subset (the CLAUDE.md whitelist depends on it).

## TODOs

- [x] TODO-1: Owner decides (all decided 2026-11-10, owner):
  - ~~Catch2 or GoogleTest~~ decided: Catch2 v3, vendored (see "Layout");
  - ~~`cpp_tests/` as the location~~ decided: `cpp_tests/`;
  - ~~whether to whitelist agent builds of the suite in CLAUDE.md~~ decided 2026-11-10: whitelisted for the
    per-target file subset only (see "Compile rule").
- [ ] TODO-2: Shared core source list for the Python build and `cpp_tests/`; CMake scaffold; one trivial test
  green.
- [ ] TODO-3: Target A (optimizer edge cases).
- [ ] TODO-4: Target B (Cox descent guard and backward sum).
- [ ] TODO-5: Target C (ASan/UBSan build; 2-3 fuzz harnesses with a crash corpus).
- [ ] TODO-6: CI job; promote it to a required check after a green streak.
- [x] TODO-7: File Phase 2 (design-draw thread determinism, `RNG.h` vectors) as a v1.1.0 TODO next to TODO-48. Done 2026-11-10: `release_v1_1_0.md` TODO-193, target 1 of `../v1_1_0/native_cpp_tests_v1_1_0.md`.
