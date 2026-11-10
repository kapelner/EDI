# Repository Layout Cleanup: Project-Wide `metadata/` at the Root, R-Only Material Under `R/`

> **Release:** v1.0.6 TODO-14 (`../../future_release_plans/release_v1_0_6.md`). Owner decision 2026-11-10,
> taken as an exception to that file's entry rule (refactors normally stay in v1.1.0): this changes repository
> layout only, no package code, API or results.
>
> **Depends on:** the 2026-11-10 per-release subfolder reorganization of `new_feature_plans/`, `bug_fix_plans/`
> and `finished_features/` being committed first. Do this as its own cleanup commit, after that one.
>
> **Related:** `../v4_0_0/migrate_EDI_into_shared_cpp_backend.md` → "Repository layout (owner decision,
> 2026-11-10)" records the later step (a root `core/` for the R-free C++, with `core/tests/`). This plan does
> not move any C++.

## Goal

`R/` should hold the R package and the files that only make sense with it. Material about the project as a
whole (R package, shared C++ kernels, Python bindings) goes at the repository root.

## The rule

- **Root `metadata/`:** anything about the project as a whole.
- **`R/metadata/`:** only things that would be meaningless without the R package.
- **Each component owns its tests**, next to its code. There is no root `tests/`.
- **Root `scripts/`:** cross-cutting CI and pre-push tooling, with its own tests (it already holds
  `test_check_doc_links.py` and `run_prepush_r_tests.R`).

## Target layout

```text
metadata/            project-wide plans, releases, audits, datasets, contracts
scripts/             CI and pre-push tooling, incl. the coverage-floor gate
R/EDI/               the package (with its CRAN tests/)
R/metadata/          R-only notes (~10 files)
R/dev_tests/         was R/package_tests (name still open, see Decisions)
R/benchmark/, R/profile/
python/              unchanged; gets benchmark_model_fits_python.py
```

## What moves where

### `R/package_metadata/` → root `metadata/`

- Every plan folder: `new_feature_plans/`, `bug_fix_plans/`, `finished_features/`, `future_release_plans/`
  (with their per-release subfolders).
- `audits/`, `contracts/`, `reports/`, `feasibility_reports/`.
- The dataset catalogs and license audit: `experimental_datasets.{md,csv}`,
  `observational_datasets.{md,csv}`, the two `*_missingness.csv` sidecars, `dataset_license_audit.md`,
  `randomized_experiment_datasets/`, `observational_design_datasets/`.

The plans are **not** split by language, even the mostly-R ones:

- Most plans touch R and the C++ kernels at once, so "R-only" would be a per-file judgment call and the
  boundary would drift.
- The release files are one index across everything; splitting would make every release point into two trees.
- The 2026-11-10 subfolder pass already rewrote ~200 references; a language split would mean doing that again,
  then maintaining it.

### `R/package_metadata/` → `R/metadata/` (R-only, ~10 files)

- `R_OPTIMIZATION.md`
- `benchmark_model_fits.md`, `benchmark_model_fits_R.html`
- `demo_helpers/`
- `formal_specs/mirai_lifecycle/` (models R's mirai worker pool)
- `figures/` (one R `InferenceSuite` plot)
- Possibly the R dataset scripts: `download_*_datasets.R`, `build_*_datasets_csv.R`,
  `compute_covariate_missingness.R`, `icpsr_card_parser.R`. The catalogs they write stay at the root. See
  Decisions.

### `R/package_tests/` → `R/dev_tests/` (rename only; stays under `R/`)

Nearly all of it drives the R6 API: `testthat_bulk/` (~1,250 files), the comprehensive suite, the
public-argument-combination harness, path audits, calibration studies, power simulations, coverage registries.
It is R-package supporting material, so it stays under `R/`.

Why not the bare name `R/tests/`: it would sit next to `R/EDI/tests/`, the CRAN `testthat` suite (324 files),
which is a different thing. The two are already easy to confuse (the bulk goldens load fixtures from
`testthat_bulk/fixtures/`, not `R/EDI/tests/testthat/fixtures/`).

### Shared or Python pieces leave the R tree

- Coverage-floor gate → `scripts/`: `R/package_tests/ci/check_coverage_floor.py`, its tests
  (`test_check_coverage_floor.py`, and `test_check_coverage_floor.R` with its R twin
  `check_coverage_floor.R`), and `coverage_baseline.json`. `test-coverage-python.yml` runs the gate on
  `python/coverage.xml`, so both languages use it.
- `R/benchmark/benchmark_model_fits_python.py` → `python/benchmark/` (its output already lives there).

### Stays where it is

- `R/benchmark/` and `R/profile/`: R-hosted. The `fast_*.cpp` microbenchmarks exercise shared C++ but run
  through Rcpp, and the profiler drives kernels from R.
- `R/fast_roxygenize.R`.
- All C++ (see the v4.0.0 plan).

## Touchpoints (counted 2026-11-10)

- `package_metadata`: ~550 reference lines, in ~90 files outside the folder.
- `package_tests`: ~3,600 reference lines, in ~120 files outside the folder.

Files outside both folders that need updating:

- **CI:**
  - workflows: `R-CMD-check`, `algorithm-audit-drift`, `build-wheels`, `calibration-fast-tier`,
    `calibration-study`, `formal-spec-tlc`, `test-bulk-non-cran`, `test-coverage-R*` (3), `test-coverage-python`
  - `.github/scripts/algorithm_audit_drift.py` (its `META` path)
  - `codecov.yml`
- **Hooks and scripts:** `scripts/pre-push`, `check_doc_links.py` and its baseline CSV, `check_core_no_rcpp.*`,
  `check_unity_build_safety.sh`, `generate_loc_badge_data.sh`, `gitpush_with_hooks_safe.sh`,
  `sanitizer_valgrind_check.sh`.
- **Contributor and agent docs:** `AGENTS.md`, `CONTRIBUTING.md`, `GEMINI.md`, `README.md`, `.cursor/rules/edi.mdc`,
  `.github/copilot-instructions.md`, the issue and PR templates, `.devcontainer/post-create.sh`, `.gitignore`.
- **Inside the package:**
  - roxygen in `R/EDI/R/*.R`, so the Rd files must be regenerated (G6)
  - `R/EDI/vignettes/` (`extending-edi.Rmd`, `procedure-trust.Rmd`), `R/EDI/REFERENCES.md`,
    `R/EDI/pkgdown/assets/llms.txt`
  - five `R/EDI/tests/testthat/` files
  - `R/EDI/configure`
- **C++ comments:** `R/EDI/src/` `.cpp` files and the headers `RNG.h`, `_helper_functions.h`, `na_real_core.h`,
  `result_map.h`.
- **Python:** `python/CHANGELOG.md`, `python/CMakeLists.txt`, `python/README*.md`.
- **Not in git** (update by hand or leave): Claude memory files, `.trail/` learnings (never edited; they keep
  the old paths as history), `graft/` (regenerated), and the owner's own build and test tooling.

## Method (from the 2026-11-10 subfolder pass)

The script used for that pass is the template (rewrite references first, then `git mv`).

1. Rewrite every `R/package_metadata/...` and `package_tests/...` reference repo-wide, including line-wrapped
   comment paths (`package_metadata/` + newline + comment prefix + filename).
2. In moved files, re-resolve relative paths (`../...` prose paths and markdown links) against the new
   location. **Only rewrite a relative path that resolved from the old location.** Many plan files carry
   `../EDI/...` or `../R/EDI/src` paths that are relative to some other directory (CMake's `python/`, or long
   broken). Shifting those breaks them; the subfolder pass had to revert 58 such rewrites.
3. R scripts that build paths from the working directory (`file.path("package_tests", ...)`,
   `"../EDI"`, `setwd()`) cannot be found by a path regex alone. Grep for `package_tests`, `package_metadata`,
   `here::`, `setwd` and `file.path` in every moved `.R`, `.py` and `.sh` file, and read each hit.
4. C++ headers: a comment edit in a header recompiles every file that includes it. Leave header comments
   unchanged unless the change goes in with a user-run build (G1). The 2026-11-10 pass left `RNG.h` and
   `na_real_core.h` stale for this reason.
5. While there, fix `.github/workflows/build-wheels.yml` line 6, which already points to the wrong path
   (`R/package_metadata/python_bindings_package_spec.md`).

## Verification

- `git grep` finds no `package_metadata` or `package_tests` references, apart from intentional ones such as
  this plan's history.
- `scripts/pre-push` runs end to end. This covers the drift, wiring and parity tests, the calibration
  pre-push check and the doc-link checker.
- `python3 .github/scripts/algorithm_audit_drift.py` exits 0.
- One bulk test shard, the comprehensive-suite smoke tests (`smoke_test_*.R`) and the calibration fast-tier
  planner run from their new paths.
- Every workflow touched gets a green run on the cleanup commit (G5). `workflow_dispatch` covers the scheduled
  ones (calibration study, formal spec).
- Roxygen and Rd are regenerated with 0 warnings (G6). The package tarball is unchanged except for doc paths.

## Decisions (owner, before starting)

1. New name for `R/package_tests/`: `R/dev_tests/`, `R/extended_tests/`, or keep the current name.
2. Whether the R dataset download/build scripts go to `R/metadata/` (they are R code) or stay with the catalogs
   at the root.

## TODOs

- [ ] TODO-1: Owner decides the two items above.
- [ ] TODO-2: Move `R/package_metadata/` to `metadata/` and `R/metadata/` per this plan; rewrite references.
- [ ] TODO-3: Rename `R/package_tests/` (if decided); move the coverage-floor gate to `scripts/` and
  `benchmark_model_fits_python.py` to `python/benchmark/`; rewrite references, including the working-directory
  path audit (Method step 3).
- [ ] TODO-4: Update the agent/contributor docs and the owner-side memory notes that name the old paths.
- [ ] TODO-5: Run Verification; record the results here.
- [ ] TODO-6: Fix the stale plan paths in the C++ header comments, in a change that goes with a user-run build (G1):
  - `R/EDI/src/na_real_core.h` L19 → `metadata/finished_features/v1_0_0/unity_build_collision_audit.md`;
  - `R/EDI/src/RNG.h` L17-18 → `metadata/finished_features/v1_0_0/sexp_removal_rcppeigen_conversion_spec.md`
    (already wrong before 2026-11-10);
  - any other `R/EDI/src/*.h` comment this TODO's move makes stale (Method step 4).
