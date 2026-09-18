# Contributing to EDI

Thanks for contributing — human or agent. This document is the single
contributor workflow for both packages in this repo: the `EDI` R package
(`R/EDI/`) and the `edi_kernels` Python package (`python/`), which share one
C++ kernel tree (`R/EDI/src/`). It assumes you've read [`AGENTS.md`](AGENTS.md)
(repo layout, entry points, the compilation rule) — this file is the
*procedure*; that one is the *map*.

Nothing here is optional. Every checkbox in the
[pull request template](.github/PULL_REQUEST_TEMPLATE.md) maps to a step
below, and a PR that skips one will be sent back.

## 0. Setup

The fastest path to a working environment is the devcontainer
(`.devcontainer/`): open the repo in VS Code / Codespaces, or any
devcontainer-aware agent runtime, and it installs R, Python, every
dependency, LaTeX, the profiling toolchain and `ccache`, then builds both
packages once. Alternatively, on a machine with R and Python already
present:

```sh
# R package dependencies (Imports + Suggests + LinkingTo) -- pak also
# apt-installs any missing system library on Debian/Ubuntu
Rscript -e 'pak::local_install_deps("R/EDI", dependencies = TRUE, ask = FALSE)'
# Contributor tools not in DESCRIPTION (they aren't needed to check the package)
Rscript -e 'install.packages(c("roxygen2", "devtools", "pkgdown", "profvis", "proftools",
                               "microbenchmark", "DescTools"))'
# Python package, editable, with test deps
pip install -e "./python[test]"
# Local pre-push gate (see §4)
git config core.hooksPath .githooks
```

`EDI_PORTABLE=1` in your environment gives the portable build CI uses
(skips `-march=native`; see `R/EDI/configure`). Leave it unset for a
machine-tuned build when benchmarking on your own hardware.

## 1. The compilation rule (read before touching `R/EDI/src/`)

`R/EDI/src/` has 100+ `.cpp` files. A full rebuild (`R CMD INSTALL`,
`R CMD build`, `pkgbuild::compile_dll()`, or `devtools::load_all()` /
`pkgload::load_all()` **without an explicit `compile = FALSE`**) recompiles
all of them and takes minutes.

- **If you are an agent working inside the maintainer's own live checkout**
  (the situation `AGENTS.md` and `CLAUDE.md` describe): never run any of
  those without the maintainer's explicit permission *in the current
  conversation* — their own build tooling may be running concurrently and a
  second full build races it. This is a hard rule, and it has been broken
  before by saying the right thing and then running the wrong command; check
  the actual command before running it, every time. Building in a `/tmp`
  copy or a worktree does not make it exempt.
- **On your own clone or in the devcontainer**, the full build is yours to
  run — and §4 *requires* it before you push. The rule above is about not
  racing someone else's build, not about full builds being bad.

For the inner edit–compile–test loop on either setup, compile only what you
touched: delete just the stale object(s), recompile those file(s) with the
exact flags `R/EDI/src/Makevars` shows (`PKG_CXXFLAGS`/`PKG_LIBS` plus R's
own `R CMD config CXX20FLAGS`), then relink `EDI.so` from the full existing
`.o` set — the touched objects plus every untouched, already-built one.
With `EDI_UNITY=0` (see below) that is a one-file recompile; the pattern is:

```sh
cd R/EDI/src
rm -f touched_file.o                                   # only the stale object(s)
R CMD SHLIB -o EDI.so $(ls *.cpp | grep -v '^unity_')   # remakes what's missing, relinks the rest
```

and load the result without compiling:

```r
pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)
```

If `library(EDI)` fails or the `.o` set looks partial (fewer `.o` than
`.cpp`), that is a sign a build is in progress or was interrupted — don't
"finish" it by compiling the rest yourself; ask.

Note the unity build: by default `configure` merges kernel files into
`src/unity_NN.cpp` groups (`EDI_UNITY=1`). Editing one member `.cpp` does
not bump its wrapper's mtime, so an *incremental* install won't notice.
For a targeted single-file loop set `EDI_UNITY=0`; a fresh/full build is
always correct either way.

## 2. Before you start

Establish that the tree is green and capture a performance baseline, so
that anything you break or slow down is unambiguously yours.

1. **Run the full R test suite — zero failures.** Same entry point the
   pre-push hook uses, but the *full* tier — real multi-worker tests and
   the exhaustive reused-worker sweeps on (the hook itself runs only the
   fast tier; cwd must be `R/EDI/tests`) — so your "green before I
   started" is the same bar CI holds the PR to:
   ```sh
   cd R/EDI/tests && NOT_CRAN=true EDI_PREPUSH_NO_PARALLEL=false \
     EDI_EXHAUSTIVE_WORKER_TESTS=true Rscript ../../../scripts/run_prepush_r_tests.R
   ```
   and the Python suite:
   ```sh
   cd python && python -m pytest tests -q
   ```
   For one file while iterating:
   `Rscript -e 'testthat::test_file("R/EDI/tests/testthat/test-<name>.R")'`.
   `R/EDI/tests/` is the CRAN-facing suite; `R/package_tests/testthat_bulk/`
   holds the extended non-CRAN suites (run by the `test-bulk-non-cran`
   workflow).
2. **Run `fast_roxygenize` — zero errors *and* zero warnings.** It
   regenerates `man/*.Rd`, `NAMESPACE` and `RcppExports.*`; roxygen reports
   doc problems (e.g. an undocumented R6 method) as *warnings* with exit
   code 0, so read the output, don't trust the exit code:
   ```sh
   cd R && Rscript fast_roxygenize.R
   ```
   A clean tree should produce no diff. Don't run it mid-way through a
   batch of documentation edits — once, at the checkpoints in this file.
3. **Capture the benchmark baseline.** Both scripts write committed report
   files, so the baseline *is* the current committed state — but run them
   once on your machine so the before/after comparison in §4 is
   like-for-like (same hardware, same load):
   ```sh
   cd R && Rscript benchmark/benchmark_model_fits.R          # needs installed EDI
   cd R && python3 benchmark/benchmark_model_fits_python.py  # rebuilds _core itself
   ```
   Outputs: `R/package_metadata/benchmark_model_fits.md` (combined R +
   Python table; the file to compare), plus
   `R/benchmark/benchmark_model_fits_R.html` and
   `python/benchmark/benchmark_model_fits_python.html`. Commit nothing yet;
   `git stash` or note the numbers.

## 3. Doing the work

- **Plan first for anything non-trivial.** Feature/fix plans live in
  `R/package_metadata/new_feature_plans/` (one `.md` per feature; completed
  ones move to `finished_features/`; release scoping in
  `future_release_plans/`, summarized in [`ROADMAP.md`](ROADMAP.md)). If
  your change implements a plan, link it; if it's new, add one. Plans
  record *why*, not just what — the audit trail in `finished_features/` is
  how later contributors avoid re-deriving decisions.
- **Design/inference class changes:** both class families are
  registry-driven (`R/EDI/R/design_class_registry.R`,
  `inference_class_registry.R`). Capabilities, components and
  response-type support are declared, then audited by tests
  (`test-design-inference-introspection-audit.R` and the golden-migration
  suites). Add the declaration, then the test that pins it — don't bypass
  the registry.
- **C++ kernels** are shared by R and Python. A change under `R/EDI/src/`
  must keep both `python/tests` and the R suite green, and both benchmark
  reports non-regressed. Keep `EDI_CORE_ONLY` guards intact: anything
  R-specific (Rcpp entry points, `R::` calls) goes inside them.
- **Tests before fixes.** For a bug, first add a test that fails, then fix
  it. Golden/baseline tests (`*-migration-golden.R`,
  `*-migration-baseline.R`) pin structure and numbers deliberately; update
  their expected values only when the change is intentional, and say so in
  the PR.
- Use the `Design<Fixed|SeqOneByOne><Method>` /
  `Inference<ResponseType><Method>` naming and the existing `checkmate`
  argument-contract style; the contract registry
  (`R/package_tests/`) is regenerated and diffed by the pre-push hook.

### 3b. Change-type protocols (in addition to everything above)

Some kinds of change carry their own, longer contract that already lives in
this repo. These are not suggestions; the PR template asks you to attest to
the one that applies.

| If your change… | you must also satisfy |
|---|---|
| **adds or materially changes an inference or design class** | [`R/package_metadata/contracts/new_model_creation.md`](R/package_metadata/contracts/new_model_creation.md) end to end — its **§10 Definition of Done** is the checklist, covering registry metadata, argument contracts, documentation standard, harness registration, the argument-combination suite, Python bindings, cold/warm starts and `path_audits.html`. It builds on `vignette("extending-edi")` (class architecture, capability/registry rules — read it first; its last section is the hand-off to the contract) and on `vignette("validation-evidence")`: a new class needs independent evidence of the four kinds that page indexes, and for any new *inference procedure* that includes a **simulation/calibration check** — `SimulationFramework$new(...)$run()` + `SimulationFrameworkReport$new(sim)$summarize()` showing `coverage_pval`/`size_pval` consistent with nominal, reported in the PR (a correct point estimate does not prove a correct standard error). |
| **touches or adds a C++ kernel / backend** (`R/EDI/src/`, `python/cpp/`) | `vignette("backend-contracts")` (the R6-wrapper-vs-raw-backend validation boundary, argument dimensions and storage order, numeric-domain safeguards, convergence flags, `NA`/`NaN` handling, wrapper-to-backend equivalence) **plus** `new_model_creation.md` §5: **perf profiling is mandatory** (register the kernel in `R/profile/edi_kernel_profiler.R`, add it to `R/profile/run_edi_perf.sh`, run it, and put before/after numbers in the PR), **valgrind memcheck is mandatory** (zero definite leaks, zero invalid reads/writes, zero uninitialized-value jumps originating in EDI code; the devcontainer has valgrind), the core must still compile under `EDI_CORE_ONLY` (`R/scripts/check_core_no_rcpp.sh` passes), `clang-tidy performance-*` clean, and both benchmark rows (§7.1) regenerated — never hand-edited. |
| **involves randomness, seeds, resampling or parallel workers** | `vignette("reproducibility")`: the single-`seed` contract, the portable cross-language `edi_rng::RRng` stream (and its one documented exception), per-replication and per-cache-job seeds in `SimulationFramework`, seed-reproducibility across `num_cores` settings, and the Monte Carlo-error section for how many replications a calibration claim needs. A change that makes a seeded result differ from before is a breaking change and must say so in `NEWS.md`. |

## 4. Before you push

All of these, in order, on the final state of your branch. None may be
skipped.

1. **Full R test suite and Python suite — zero failures** (commands in §2.1).
2. **`fast_roxygenize` — zero errors, zero warnings** (§2.2). Commit any
   regenerated `man/`/`NAMESPACE`/`RcppExports` changes.
3. **`R CMD build`, then `R CMD check --as-cran` — zero errors, zero
   warnings, zero notes.** Exactly what CI's main matrix runs:
   ```sh
   cd R
   EDI_PORTABLE=1 R CMD build --compact-vignettes=gs+qpdf EDI
   EDI_PORTABLE=1 _R_CHECK_DONTTEST_EXAMPLES_=true NOT_CRAN=true \
     R CMD check --as-cran --no-manual EDI_*.tar.gz
   ```
   The one exception is the pre-existing `unlockBinding()`
   "possibly unsafe calls" NOTE, which is deliberate (EDI's
   lazy-component loading) and documented in `R/EDI/cran-comments.md` —
   any *other* NOTE is yours to fix. `--no-manual` matches CI; drop it to
   also build the PDF manual (needs LaTeX; the devcontainer has it).
4. **Re-run both benchmarks — no regressions from your baseline:**
   ```sh
   cd R && Rscript benchmark/benchmark_model_fits.R
   cd R && python3 benchmark/benchmark_model_fits_python.py
   git diff R/package_metadata/benchmark_model_fits.md
   ```
   A slowdown in any row your change touches must be explained in the PR
   or fixed. Timing noise is real: re-run before concluding, and compare
   against *your own* §2.3 baseline, not the committed numbers from someone
   else's machine. If you intentionally changed performance, commit the
   regenerated reports.
5. **`fast_roxygenize` once more — zero errors, zero warnings.** Steps 3–4
   can regenerate files; this confirms the docs are still consistent with
   the final tree.
6. **Run the pre-push hook checks.** With `core.hooksPath` set (§0), the
   hook runs automatically on `git push`. It is deliberately a *fast,
   diff-gated* gate, not the full test matrix: based on what changed it
   runs the doc-link and `@references`/`REFERENCES.md` sync checks,
   `fast_roxygenize`, an install, the R suite (fast tier — with
   `EDI_PREPUSH_NO_PARALLEL=true`, i.e. the real multi-worker tests
   skipped), the Python suite (gated on not regressing the coverage floor —
   see §4.8), and — if `R/package_tests/` is affected —
   the comprehensive-suite smoke tier plus the drift-artifact regeneration
   (`bash R/package_tests/drift_artifacts.sh regenerate` then `check`).
   **It does not run the tiers in §4.7** (bulk, exhaustive sweeps,
   multi-worker, quarantine); those are your responsibility before you
   push, and the on-push CI at PR time is where they are verified.
   Push through the wrapper so hook-regenerated files land in the same
   push instead of failing it:
   ```sh
   ./gitpush_with_hooks_safe.sh
   ```
   `git push --no-verify` is for deliberate WIP branches only, never for a
   PR.
7. **Run the tiers the hook skips — required, not enforced locally.** The
   hook (step 6) is the fast gate; these tiers are *policy*: you run them
   before pushing, attest to them in the PR template, and the on-push CI
   at PR review is where they are verified (`test-bulk-non-cran`,
   `test-coverage-R-advanced`, and the sanitizer/valgrind jobs). A PR whose
   CI is red on one of these is treated as if the step was skipped:
   - **Always:** the exhaustive reused-bootstrap-worker sweeps (skipped
     unless opted in) and the bulk suite (`R/package_tests/testthat_bulk/`,
     88 files, ~1h20–1h40; the hook never runs it, CI does):
     ```sh
     cd R/EDI/tests && NOT_CRAN=true EDI_EXHAUSTIVE_WORKER_TESTS=true \
       EDI_PREPUSH_NO_PARALLEL=false Rscript ../../../scripts/run_prepush_r_tests.R
     cd R && Rscript package_tests/testthat_bulk/run_bulk_tests.R
     ```
   - **If you touched parallelism** (`set_num_cores()`, fork/mirai
     dispatch, `SimulationFramework` workers, OpenMP in a kernel): also run
     the real multi-worker tests. The hook skips them
     (`EDI_PREPUSH_NO_PARALLEL=true` is its default) and so does the main
     CI check matrix — only the sanitizer/valgrind CI jobs run them — so
     run them yourself with `EDI_PREPUSH_NO_PARALLEL=false` in the command
     above (already shown that way).
   - **If you touched a class a quarantined test exercises**
     (`R/package_tests/testthat_bulk_quarantine/`, never run by CI or the
     hook): run that directory before and after your change per its
     `README.md` and report both outcomes — a flaky test that gets *worse*
     is a regression even though it isn't a CI failure.
   - **If you touched `R/package_tests/` or any inference/design class:**
     the comprehensive suite's smoke tier, its analysis, and its quality
     gates must all pass locally — the same sequence
     `test-coverage-R-advanced` runs post-push (the hook runs this only
     when `R/package_tests/` itself changed, so a class change alone
     won't trigger it locally):
     ```sh
     cd R
     Rscript package_tests/run_comprehensive_suite.R smoke "" 300 --force
     Rscript package_tests/analyze_comprehensive_suite.R
     Rscript package_tests/check_comprehensive_suite_quality_gates.R ci
     bash package_tests/drift_artifacts.sh check     # regenerated CSVs committed, no diff
     ```
8. **Coverage must not drop.** Two independent gates enforce this. Codecov's
   `target: auto` patch check (`codecov.yml`) requires new/changed lines to
   have tests and the aggregate not to go down — check the `codecov` status
   on the PR; a drop is a blocker, not a note. Separately, this repo's own
   hard gate (`R/package_tests/ci/check_coverage_floor.R`/`.py`, TODO-9 in
   `full_test_coverage.md`) fails `test-coverage-R`/`test-coverage-python`
   outright if aggregate coverage drops below the best-ever figure recorded
   in `R/package_tests/ci/coverage_baseline.json`. On a new high, the job
   log/summary says so — bump that file's entry by hand and commit it; the
   CI job never writes it itself. The pre-push hook also runs the Python
   half of this check locally (cheap, no rebuild — `pytest-cov`, not
   `covr`) before any push that touches Python/kernel code, so a regression
   is caught before it's even pushed, not just after.

## 5. Opening the pull request

- `main` has branch protection: a PR needs 1 approving review and the
  `coverage` (`test-coverage-python.yml`) check green before it can merge —
  it's the only workflow that actually runs on `pull_request` events, so
  it's the only one GitHub can enforce this way. Repo admins bypass this
  (`enforce_admins: false`) and can still push directly to `main`; everyone
  else goes through a PR. Every other job below is still required by
  policy, just not by GitHub — self-verify it the same as before.
- Fill in the [PR template](.github/PULL_REQUEST_TEMPLATE.md) completely —
  every checkbox is one of the steps above.
- **All on-push CI must be green** before requesting review — not just the
  jobs that look related. That is the full set:
  `R-CMD-check` (10-job matrix: macOS/Windows/Ubuntu × release/devel/
  oldrel-1, no-Suggests, ASAN/UBSAN, valgrind, CRAN-incoming),
  `test-bulk-non-cran`, `test-coverage-R`, `test-coverage-R-advanced`,
  `test-coverage-python`, `build-wheels` (on `main`/tags),
  `pkgdown`, `loc-badge`. A red job you believe is a pre-existing flake
  (the Windows `--run-donttest` stall is a known one — see
  `R-CMD-check.yaml`'s comments) still needs to be called out in the PR
  with the run link, not ignored.
- Keep PRs scoped: one feature or fix, its tests, its docs, its plan-file
  update. Regenerated artifacts (`man/`, drift CSVs, benchmark reports)
  belong in the same PR as the change that caused them.
- Commit messages: imperative subject, body explaining *why*. Agent-authored
  commits and PRs should carry the attribution trailers their tooling adds.

## 6. Reporting bugs and proposing features

Use the issue forms — they ask for the response type, design class,
inference class and a minimal reproducer, which is what a fix actually
needs. Good first contributions are labeled
[`good first issue`](https://github.com/kapelner/EDI/labels/good%20first%20issue)
and [`help wanted`](https://github.com/kapelner/EDI/labels/help%20wanted);
the [`ROADMAP.md`](ROADMAP.md) and `new_feature_plans/` are the longer
backlog. Questions go to
[Discussions](https://github.com/kapelner/EDI/discussions).

By contributing you agree your work is licensed under the repo's
[GPL-3](LICENSE) and that you'll follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
