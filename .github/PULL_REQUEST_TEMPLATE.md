<!--
Every checkbox below is a required step from CONTRIBUTING.md. A PR with an
unchecked box will be sent back. Check a box only after actually running the
step on the FINAL state of this branch -- not from memory, not from an
earlier commit.
-->

## What this changes

<!-- One feature or fix. What, and why. Link the issue it closes. -->

Closes #

**Plan file:** <!-- R/package_metadata/new_feature_plans/<plan>.md, or "none: trivial" -->

**Affects:** <!-- R package / edi_kernels / shared C++ kernels (R/EDI/src) -->

## Before work began (CONTRIBUTING.md §2)

- [ ] Full R test suite passed with **zero failures** — the full tier, not just what the hook runs (`EDI_PREPUSH_NO_PARALLEL=false EDI_EXHAUSTIVE_WORKER_TESTS=true`, `scripts/run_prepush_r_tests.R` from `R/EDI/tests`) — and `python -m pytest tests -q` passed.
- [ ] `cd R && Rscript fast_roxygenize.R` ran with **zero errors and zero warnings** on the clean tree.
- [ ] Captured a benchmark baseline on this machine: `benchmark/benchmark_model_fits.R` and `benchmark/benchmark_model_fits_python.py`.

## Before push (CONTRIBUTING.md §4)

- [ ] Full R test suite: **zero failures**. Python suite: passes.
- [ ] `fast_roxygenize.R`: **zero errors, zero warnings**; regenerated `man/` / `NAMESPACE` / `RcppExports*` committed.
- [ ] `EDI_PORTABLE=1 R CMD build --compact-vignettes=gs+qpdf EDI` succeeded.
- [ ] `R CMD check --as-cran --no-manual` on that tarball: **zero errors, zero warnings, zero notes** (other than the documented `unlockBinding()` NOTE in `cran-comments.md`).
- [ ] Re-ran both benchmarks against my §2 baseline: **no regressions** in any row this change touches. Regenerated reports committed if performance intentionally changed.
- [ ] `fast_roxygenize.R` once more after the above: **zero errors, zero warnings**.
- [ ] Pushed through the pre-push hook (`git config core.hooksPath .githooks`; `./gitpush_with_hooks_safe.sh`) — not `--no-verify`. Drift artifacts (`R/package_tests/drift_artifacts.sh check`) clean.
- [ ] Ran the tiers the hook skips (CONTRIBUTING.md §4.7) — **required, self-attested, verified by CI at review**: `EDI_EXHAUSTIVE_WORKER_TESTS=true` suite **and** the bulk suite (`package_tests/testthat_bulk/run_bulk_tests.R`) — zero failures.
- [ ] If parallelism was touched: real multi-worker tests run with `EDI_PREPUSH_NO_PARALLEL=false` — zero failures. <!-- or "N/A: no parallel code touched" -->
- [ ] If `R/package_tests/` or any inference/design class was touched: `run_comprehensive_suite.R smoke` → `analyze_comprehensive_suite.R` → `check_comprehensive_suite_quality_gates.R ci` all pass locally. <!-- or N/A -->
- [ ] If a quarantined test exercises a touched class: `testthat_bulk_quarantine/` run before **and** after, both outcomes reported below. <!-- or N/A -->

**Benchmark diff** (`git diff R/package_metadata/benchmark_model_fits.md`, summarize; "no change" is a valid answer):

<!-- e.g. "InferenceContinKKOLSIVWC row: 4.1ms -> 3.6ms (this PR's intent). All other rows within noise." -->

**Quarantine before/after** (if applicable):

## Change-type protocols (CONTRIBUTING.md §3b) — check the row(s) that apply

- [ ] **New / changed inference or design class:** `R/package_metadata/contracts/new_model_creation.md` **§10 Definition of Done** fully satisfied; `vignette("extending-edi")` rules followed; `vignette("validation-evidence")`-style evidence added, including a **simulation/calibration check** (`SimulationFrameworkReport$summarize()` `coverage_pval` / `size_pval`) for any new inference procedure — results pasted below.
- [ ] **C++ kernel / backend touched:** `vignette("backend-contracts")` honored; **perf profiled** via `R/profile/run_edi_perf.sh` (kernel registered in `edi_kernel_profiler.R`) with before/after numbers below; **valgrind memcheck clean** (zero definite leaks / invalid access / uninitialized jumps in EDI code); `R/scripts/check_core_no_rcpp.sh` passes (`EDI_CORE_ONLY` build); `clang-tidy performance-*` clean; both benchmark rows regenerated, not hand-edited.
- [ ] **Randomness / seeds / resampling / workers touched:** `vignette("reproducibility")` contract preserved (single-`seed` semantics, `edi_rng::RRng` stream, per-replication seeds, identical results across `num_cores`); any change to a seeded result is declared as breaking in `NEWS.md`.
- [ ] None of the above apply.

**Calibration / perf / valgrind evidence** (paste the relevant output):

<!-- SimulationFrameworkReport summary rows, perf before/after, valgrind summary line -->

**Coverage:** <!-- codecov status on this PR: must not drop (target: auto + patch gate) -->

## After opening this PR (CONTRIBUTING.md §5)

- [ ] **All** on-push CI workflows are green: `R-CMD-check` (all 10 matrix jobs), `test-bulk-non-cran`, `test-coverage-R`, `test-coverage-R-advanced`, `test-coverage-python`, `pkgdown`, `loc-badge` (and `build-wheels` if applicable).
- [ ] Any red job I believe is a pre-existing flake is linked below with the run URL, not ignored.

**CI notes:** <!-- run links for anything red, or "all green" -->

## Tests and docs

- [ ] For a bug fix: a test that failed before this change and passes after.
- [ ] Golden/baseline expected values were only changed where the change is intentional, and that is explained above.
- [ ] Registry-driven class changes declare capabilities/components in the registry and are pinned by a test; user-facing behavior is documented (roxygen) and `NEWS.md` updated.
