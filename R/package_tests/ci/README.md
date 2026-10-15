# Runtime-balanced R CI

`test-bulk-non-cran.yml` runs all bulk correctness tests on PRs and pushes.
`test-coverage-R.yaml` runs all package and bulk tests under covr on every
push to main touching R code (2026-09-18 -- previously nightly/on-demand
only), plus a nightly backstop and on-demand via workflow_dispatch; not on
PRs, since covr's instrumented rebuild is too slow for that feedback loop.
The nightly backstop's `check` job (2026-09-19) re-applies the push
trigger's own path filters against the last successful run's commit, so an
idle repo doesn't pay for a full coverage run every night -- it only
actually runs when a relevant path changed since that commit (or there is no
prior successful run to compare against). `workflow_dispatch` always runs
regardless.
The advanced smoke/gate workflow remains separate.
Quarantined tests remain outside these inventories.

Each matrix is generated deterministically from `test_runtimes.csv`, packing
the longest files first into the fewest evenly loaded buckets that each stay within 2,400 estimated seconds (shard count starts at ceil(total / 2400); each file goes to the least-loaded shard, so there is no short tail shard).
Jobs have a 60-minute timeout, including dependency setup and compilation.
The test step has a 45-minute timeout so timing uploads can still run when
that step times out, provided the overall job budget has not expired.
Six jobs run concurrently. Estimates cannot enforce a wall-clock limit;
newly slow files can still time out and should be split or re-estimated.

Initial estimates are labelled `bootstrap`, not measured CI runtimes.
The first 18 integration cases receive larger estimates. Their assertions
are unchanged; shared definitions live in `helper-run-all-inference.R`.

After adding/removing tests, refresh the inventory (no compilation):

```sh
python3 R/package_tests/ci/refresh_manifest.py
```

Download timing artifacts from successful CI runs and import them separately
for correctness and coverage. The tier is recorded in each CSV. Import uses
the largest completed runtime for each file plus 30% headroom:

```sh
python3 R/package_tests/ci/refresh_manifest.py --timings downloaded/*/timings.csv
python3 R/package_tests/ci/plan_shards.py correctness --output /tmp/edi-plan
python3 R/package_tests/ci/plan_shards.py coverage --output /tmp/edi-coverage-plan
```

Commit the updated manifest. Inventory drift, duplicate files, and estimates
above the bucket budget fail planning, so tests cannot silently disappear.
The pre-push hook runs both planners with `--check-only` when test directories,
CI sharding files, the hook, or the two shard workflows change. It checks before
builds and R tests, writes no files, and blocks stale inventories with the refresh
command. It does not regenerate or commit the manifest automatically.
In-progress timing rows identify a file interrupted by a timeout; they are
not imported as completed measurements.

Correctness loads the checkout with `pkgload::load_all(compile = FALSE)`,
preserving the bulk runner's access to internal functions; CI first compiles
the current commit into an isolated scratch library and the source tree. Coverage
uses covr's instrumented scratch install, explicit selected test code, and
repository-relative source paths. Per-shard RDS reports carry commit, covr
version, compiler flags, and shard ID. Coverage builds override covr's `-O0`
default with `-O2 --coverage` through `configure_coverage_compiler.R` so Eigen
kernels remain practical to test. Optimization can change native line attribution;
compare coverage measurements made with the same compiler settings.
Each shard also writes a compact `coverage_values.rds` sidecar (occurrence-unique
covr element keys + counts, under 1 MB) beside the full `coverage.rds` (~55 MB
compressed, ~1.6 GB of R heap once deserialized -- 100 of them cannot coexist
on a 16 GB runner, which is why the merge job silently died with "the runner
has received a shutdown signal" on every run from 2026-09-25 to 2026-10-12).
The merge job (`merge_coverage.R`) requires every expected shard and matching
provenance, sums the sidecar counts by key over the union of keys (shards
legitimately differ in which C++ files gcov reports), reads ONE full
`coverage.rds` as the srcref-bearing skeleton (plus, one at a time, any shard
holding keys the skeleton lacks), writes the summed counts back into it, and
uploads one combined report under the Codecov `r` flag. It deliberately does
not use covr's own `merge_coverage()`: that takes ~2 minutes per pair of these
objects and mis-sums the ~9.6k gcov entries whose names are duplicated (one per
translation unit including a header). Per-line totals are exact since every
consumer aggregates by filename+line. Keep all coverage jobs on the same covr
version. Set `EDI_SKIP_CODECOV_UPLOAD=1` to dry-run the merge locally.
Test failures are visible in coverage logs but do not abort measurement;
correctness shards fail on failed expectations and test errors.

Local compilation/installation still requires explicit user permission.
The CI workflow installation steps do not authorize local compilation.

## Coverage floor (TODO-9)

`coverage_baseline.json` tracks the best-ever aggregate coverage percentage
for each language. `check_coverage_floor.R`/`.py` compare a freshly measured
percentage against it and fail loudly on a regression (a hard gate, run in
the `merge` job of `test-coverage-R.yaml` and in `test-coverage-python.yml`).
On a new high, they print instructions instead of writing the file — like
`check_coverage_registry.R`, this is measure-then-a-human-commits, not an
auto-committing CI step. The Python half also runs from `scripts/pre-push`
(pytest-cov is cheap; covr needs an instrumented rebuild, so R coverage
stays CI-only). Self-tests (`test_check_coverage_floor.R`/`.py`) build
synthetic coverage reports rather than real instrumentation.

## PR coverage job (`test-coverage-R-pr.yaml`, 2026-10-15)

The full measurement above never runs on pull requests (~100 shards, ~1.5 h).
Instead `test-coverage-R-pr.yaml` runs **one** coverage shard per PR, chosen by
`select_pr_coverage_tests.py` (stdlib Python, no R):

- every fast-tier file (`R/EDI/tests/testthat/`, ~1,100 manifest-estimated
  seconds under `covr`), never budgeted;
- bulk tests under one `--budget-seconds` (900 by default): the PR's own
  added/edited bulk tests first, then the files most related to the changed
  R/C++ sources -- ranked by how many of the names those files define
  (top-level assignments, `define_inference_class()`/`R6Class()` class names,
  `[[Rcpp::export]]` kernels, the file's own basename) each test mentions.
  Generated files (`RcppExports.*`, `unity_*.cpp`) contribute no names, and a
  name matching more than a quarter of candidates (e.g. `Inference`) is
  dropped as non-discriminative -- both guards came from dry-running the
  selector on real commits, where they turned a 163-minute selection into 34.

The shard JSON has `plan_shards.py`'s shape, so `run_shard.R` runs it unchanged
(same env as the full run: `EDI_PORTABLE=1`, thread pins). The report is
exported with `covr::to_cobertura()` and uploaded by `codecov-action` under flag
`r` -- that action maps a merge-commit upload back onto the PR head; a
`covr::codecov()` upload would report the merge SHA. The `pr-coverage` artifact
carries `selection_report.json` (every file selected or dropped, with its
score and the names it matched) and `timings.csv`; the job log shouts when a
test the PR itself edits was dropped for budget.

Consequences encoded in `codecov.yml`: the `r` **project** status is restricted
to `main`/`master` (a partial PR upload would otherwise read as a project
regression on every PR), and `codecov/patch/r` is `informational: true` until a
few real PRs show the selection covers changed lines reliably. Note that
Codecov can post *no* status checks at all until the Codecov GitHub App is
installed (verified on PR #6, 2026-10-15: token-only mode comments but never
posts statuses); until then the PR comment is the only visible output. Self-
test: `python3 R/package_tests/ci/test_select_pr_coverage_tests.py` (runs first
in the workflow). Dry-run locally against any two commits:

```sh
python3 R/package_tests/ci/select_pr_coverage_tests.py --base <sha>^ --head <sha> --output /tmp/prsel
```

## macOS reports (R-CMD-check's plain macOS leg)

Two informational steps write to the job summary on the `macos-latest`
(release) leg, the one that matches CRAN's OpenMP-free macOS R:

- `simd_vectorization_report.sh` compiles the files holding `EDI_SIMD` hints
  (`R/EDI/src/edi_simd.h`) with clang `-Rpass=loop-vectorize` into a temp dir
  and tabulates which hinted loops vectorized (arm_hardware.md TODO-7). Runs
  locally too: `SIMD_REPORT_CXX="clang++ -std=gnu++17" SIMD_REPORT_OPENMP=""
  R/package_tests/ci/simd_vectorization_report.sh` checks the no-OpenMP path.
- `accelerate_thread_probe.R` times `crossprod()` in fresh R processes under
  each BLAS thread control and reports CPU/elapsed (arm_hardware.md TODO-21).
