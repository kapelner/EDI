# Test-suite health: open findings

Written by the test-suite-health audit (`.github/workflows/audit-test-suite-health.yml`) and rewritten on each run. To reject a finding, delete its line in the audit PR: the audit will not raise it again. Fix a finding in the test itself; the line goes away on the next run.

## Skips that always run (3)

- `R/package_tests/testthat_bulk/test-prop-gcomp-bootstrap-core-count-invariance.R :: seeded prop g-computation bootstrap distribution does not depend on the core count`: `skip("open a release TODO for this")` runs unconditionally, so this test never runs
- `R/package_tests/testthat_bulk/test-run-all-inference-fork-workers-seed-core-count-invariance.R :: run_all_inference rand p-values after set.seed() do not depend on num_cores`: `skip("open a release TODO for this")` runs unconditionally, so this test never runs
- `R/package_tests/testthat_bulk/test-simulation-framework-seeded-results-core-count-invariance.R :: SimulationFramework seeded estimates do not depend on num_cores`: `skip("open a release TODO for this")` runs unconditionally, so this test never runs
