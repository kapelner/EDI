# Runtime-balanced R CI

`test-bulk-non-cran.yml` runs all bulk correctness tests on PRs and pushes.
`test-coverage-R.yaml` runs all package and bulk tests under covr nightly
and on demand. The advanced smoke/gate workflow remains separate.
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
version, and shard ID. The merge job requires every expected shard and matching
provenance, uses covr's internal `merge_coverage` implementation to add counters,
and uploads one combined report under the Codecov `r` flag. Keep all coverage
jobs on the same covr version; changes to its internal merger need validation.
Test failures are visible in coverage logs but do not abort measurement;
correctness shards fail on failed expectations and test errors.

Local compilation/installation still requires explicit user permission.
The CI workflow installation steps do not authorize local compilation.
