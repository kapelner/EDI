# Runtime-balanced R CI

`test-bulk-non-cran.yml` runs all bulk correctness tests on PRs and pushes.
`test-coverage-R.yaml` runs all package and bulk tests under covr on every
push to main touching R code (2026-09-18 -- previously nightly/on-demand
only), plus a nightly backstop and on-demand via workflow_dispatch; not on
PRs, since covr's instrumented rebuild is too slow for that feedback loop.
The advanced smoke/gate workflow remains separate.
Quarantined tests remain outside these inventories.

Each matrix is generated deterministically from `test_runtimes.csv`, packing
the longest files first into buckets with at most 2,400 estimated seconds.
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
The merge job requires every expected shard and matching
provenance, uses covr's internal `merge_coverage` implementation to add counters,
and uploads one combined report under the Codecov `r` flag. Keep all coverage
jobs on the same covr version; changes to its internal merger need validation.
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
auto-committing CI step. The Python half also runs from `.githooks/pre-push`
(pytest-cov is cheap; covr needs an instrumented rebuild, so R coverage
stays CI-only). Self-tests (`test_check_coverage_floor.R`/`.py`) build
synthetic coverage reports rather than real instrumentation.
