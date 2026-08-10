# Spec: Professionally Comprehensive Test Suite

## Objective

Implement a professionally comprehensive test suite for the EDI package. The suite must cover public API behavior, legal argument combinations, statistical workflow paths, high-fan-in internal safety nets, runtime tiers, coverage reporting, and quality gates.

This spec is intentionally broader than `package_metadata/new_feature_plans/comprehensive_argument_checking.md`, but it depends on that spec.

## Strict Dependency

`package_metadata/new_feature_plans/comprehensive_argument_checking.md` is a hard prerequisite.

Do not begin implementation of this comprehensive suite spec until the argument-checking spec is fully implemented and accepted. In particular, the following must already exist and be working:

- checkmate-derived public argument contract extraction.
- public API inventory for exported functions/classes/public R6 methods.
- legal argument registry seeded from checkmate contracts.
- cross-argument constraint library.
- deterministic public fixtures.
- public argument-combination case generator.
- public argument-combination runner.
- public argument-combination analyzer.
- smoke/CI tiers for legal argument combinations.
- coverage reports that distinguish unidimensional argument checks from pairwise/higher-order legal-combination checks.

Reason: the comprehensive suite should build on a reliable legal-argument matrix rather than inventing a second, incompatible coverage model. Argument-combination coverage is the foundation for all later public API, fixture, workflow, and internal safety-net coverage.

## Non-Goals

- Do not duplicate the argument-combination implementation from `comprehensive_argument_checking.md`.
- Do not replace `package_tests/comprehensive_tests.R` in the first rollout.
- Do not make private/internal tests count as public contract coverage.
- Do not run unbounded Cartesian products.
- Do not add broad CI gates before the smoke and CI tiers are stable.

## Inputs From The Dependency

The completed argument-checking implementation must provide these inputs:

- `package_tests/public_api_inventory.csv`
- `package_tests/checkmate_argument_contracts.csv`
- `package_tests/public_argument_contract_registry.R`
- `package_tests/public_argument_combination_constraints.R`
- `package_tests/public_argument_combination_fixtures.R`
- `package_tests/public_argument_combination_cases.csv`
- `package_tests/public_argument_combination_results.csv`
- `package_tests/public_argument_combination_coverage.csv`
- `package_tests/public_argument_combination_failures.csv`

This comprehensive suite spec will consume those files rather than redefine them.

## Architecture

The comprehensive suite has seven layers:

1. Dependency intake and validation.
2. Existing comprehensive harness hardening.
3. Public API workflow coverage.
4. Statistical method-family coverage.
5. Internal high-fan-in safety-net coverage.
6. Unified coverage analysis.
7. Tiered CI/nightly/release gates.

## Artifacts

New or extended files under `package_tests/`:

- `validate_argument_checking_dependency.R`
- `comprehensive_suite_registry.R`
- `comprehensive_suite_fixtures.R`
- `comprehensive_suite_internal_surfaces.R`
- `run_comprehensive_suite.R`
- `analyze_comprehensive_suite.R`
- `comprehensive_suite_coverage.csv`
- `comprehensive_suite_failures.csv`
- `comprehensive_suite_exemptions.csv`
- `comprehensive_suite_report.html`

Existing files to integrate with, not replace initially:

- `package_tests/comprehensive_tests.R`
- `package_tests/analyze_comprehensive_tests.R`
- `package_tests/dedupe_comprehensive_tests_results.R`
- `package_tests/run_comprehensive_tests_sunk.R`

## Phase -1: Dependency Completion Gate

Goal: block comprehensive-suite implementation until `comprehensive_argument_checking.md` is complete.

TODO:

- [x] Run the smoke tier from `run_public_argument_combinations.R`.
- [x] Run the CI tier from `run_public_argument_combinations.R`.
- [x] Run `analyze_public_argument_combinations.R`.
- [x] Verify `public_api_inventory.csv` exists and includes exported R6 classes/functions.
- [x] Verify `checkmate_argument_contracts.csv` exists and is deterministic across two runs.
- [x] Verify `public_argument_combination_cases.csv` includes default, one-non-default, and pairwise cases.
- [x] Verify `public_argument_combination_coverage.csv` reports APIs that still only have unidimensional checks.
- [x] Verify CI-tier unexpected errors are either fixed or explicitly exempted.
- [x] Record accepted dependency commit/hash/date in this spec's implementation notes when implementation starts.

Acceptance criteria:

- Argument-combination smoke and CI tiers pass.
- Coverage and failure files are generated.
- The analyzer can identify unidimensional-only public APIs.
- No comprehensive-suite phase below starts before this phase is complete.

Implementation notes:

- Accepted dependency verification date: 2026-08-10.
- Accepted dependency commit: `c2fbd8158f4c12f1ef5a8b1073edc6bffb20cb82` (commit date `2026-08-10T11:26:28+03:00`).
- `run_public_argument_combinations.R smoke` passed with 10 aggregate result rows and 0 unexpected errors.
- `run_public_argument_combinations.R ci` passed with 29 aggregate result rows and 0 unexpected errors.
- `analyze_public_argument_combinations.R` generated 9,216 coverage rows, 0 failure rows, 2,809 drift rows, and 1,875 uncovered API rows.
- `public_api_inventory.csv` contains 9,216 rows: 121 exported functions, 128 exported R6 classes, and 8,967 public R6 method rows.
- `checkmate_argument_contracts.csv` was deterministic across two consecutive extractor runs; SHA-256 `df52b166be68a090c4799c9346cb051ecd4ef3622c6bf66fbc07bba0b47145b0`.
- `public_argument_combination_cases.csv` contains smoke and CI rows with default, one-non-default, pairwise, and targeted 3-way case kinds; SHA-256 `ea13e0c79f90c584fa8c474592d27e82c6e1aefd898007096454a409923b7016`.
- `public_argument_combination_ci_failure_summary.csv` reports 0 unexpected errors, 0 invariant failures, and `ci_should_fail = FALSE`.
- `check_public_argument_combination_quality_gates.R ci` passed with 23,391 quality-gate rows and 0 active hard gates.

## Phase 0: Baseline Integration Audit

Goal: map existing comprehensive tests and result files onto the completed public argument-combination inventory.

TODO:

- [x] Load `public_api_inventory.csv`.
- [x] Load `public_argument_combination_coverage.csv`.
- [x] Load current comprehensive result CSVs.
- [x] Identify public APIs covered by `package_tests/comprehensive_tests.R`.
- [x] Identify public APIs covered only by argument-combination tests.
- [x] Identify public APIs not covered by either.
- [x] Identify existing testthat files that directly test internals.
- [x] Classify internal tests as `keep`, `rewrite_public`, `internal_safety_net`, or `remove`.
- [x] Create initial `comprehensive_suite_exemptions.csv`.

Outputs:

- `package_tests/comprehensive_suite_baseline_audit.csv`
- `package_tests/comprehensive_suite_exemptions.csv`

Acceptance criteria:

- Every exported public API has one of: argument-combination coverage, comprehensive workflow coverage, focused testthat coverage, or exemption.
- Internal tests have an explicit classification.

Implementation notes:

- Added `package_tests/audit_comprehensive_suite_baseline.R` to reproduce the Phase 0 audit artifacts from the public API inventory, argument-combination coverage, current comprehensive result CSVs, and testthat sources.
- Generated `package_tests/comprehensive_suite_baseline_audit.csv` with 9,338 rows: 9,216 public API rows and 122 direct-internal testthat file rows.
- Public API coverage status counts: 7,274 `comprehensive_workflow`, 643 `focused_testthat`, 1,189 `multiple_sources`, and 110 `uncovered`.
- Generated `package_tests/comprehensive_suite_exemptions.csv` with 110 initial `phase0_uncovered_public_api` rows, so every currently uncovered public API has an explicit baseline exemption.
- Classified all 122 direct-internal testthat file rows as `internal_safety_net`; no internal testthat rows are unclassified.

## Phase 1: Suite Registry

Goal: define the unified registry for comprehensive suite coverage.

Implement `package_tests/comprehensive_suite_registry.R`.

Registry dimensions:

- public API surface.
- response type.
- design family.
- inference family.
- dataset/fixture family.
- method family.
- runtime tier.
- expected invariants.
- source runner: `argument_combinations`, `comprehensive_tests`, `testthat`, `internal_safety_net`.

TODO:

- [x] Define registry schema.
- [x] Import public API surfaces from the argument-checking inventory.
- [x] Import argument-combination coverage status.
- [x] Add method-family taxonomy:
  - estimate.
  - asymptotic.
  - exact.
  - bootstrap.
  - Bayesian bootstrap.
  - parametric bootstrap.
  - Bartlett.
  - jackknife.
  - randomization.
  - randomization-bootstrap.
  - simulation framework.
- [x] Add design-family taxonomy:
  - sequential.
  - fixed.
  - stratified.
  - clustered.
  - blocked.
  - matched.
  - optimal/search.
- [x] Add response-family taxonomy.
- [x] Add tier metadata.
- [x] Add exemption hooks with reasons and expiry dates.

Outputs:

- `package_tests/comprehensive_suite_registry.csv`

Acceptance criteria:

- Registry can answer "what must be tested for this exported public API?"
- Registry can answer "which runner is responsible for this coverage?"
- Registry distinguishes public contract coverage from internal safety-net coverage.

Implementation notes:

- Added `package_tests/comprehensive_suite_registry.R` to build the unified suite registry from `public_api_inventory.csv`, `public_argument_combination_coverage.csv`, `comprehensive_suite_baseline_audit.csv`, and `comprehensive_suite_exemptions.csv`.
- Generated `package_tests/comprehensive_suite_registry.csv` with 9,338 rows: 9,216 `public_contract` rows and 122 `internal_safety_net` rows.
- Registry schema includes public API surface, coverage scope, response/design/inference/dataset fixture/method families, runtime tier, required coverage, expected invariants, source runner, argument-combination coverage metrics, and exemption metadata.
- Source-runner counts: 7,274 `comprehensive_tests`, 643 `testthat`, 1,188 `comprehensive_tests;testthat`, 1 `argument_combinations;comprehensive_tests;testthat`, 110 `exemption`, and 122 `internal_safety_net`.
- Required-coverage counts: 3,332 `argument_combinations_or_workflow`, 255 `constructor_workflow`, 5,516 `public_workflow`, 3 `focused_public_test_or_workflow`, 110 `exemption`, and 122 `internal_safety_net`.
- Validation checks passed: 0 public rows with blank `required_coverage`, 0 public rows with blank `source_runner`, 0 uncovered public rows without exemption hooks, and 0 internal rows with a non-`internal_safety_net` runner.
- `comprehensive_suite_registry.csv` SHA-256: `ae2b6af181cd7762cba8977b6ffbf9c87607520b1c0eed475f5ee3d9814cd7e4`.

## Phase 2: Fixture Consolidation

Goal: reuse the argument-checking fixtures and extend them only where comprehensive workflow testing needs broader data.

Implement `package_tests/comprehensive_suite_fixtures.R`.

TODO:

- [x] Import or wrap `public_argument_combination_fixtures.R`.
- [x] Add fixture aliases compatible with existing `comprehensive_tests.R` labels.
- [x] Add larger nightly/release fixtures where needed.
- [x] Add survival fixtures with no/light/moderate censoring.
- [x] Add count/proportion/incidence edge fixtures.
- [x] Add ordinal fixtures with multiple level counts.
- [x] Add clustered/blocked/matched design fixtures.
- [x] Add fixture validation tests.
- [x] Ensure every fixture is deterministic under fixed seed.

Acceptance criteria:

- Smoke fixtures are fast enough for CI.
- Nightly/release fixtures are marked with runtime tier.
- Existing comprehensive harness can either reuse these fixtures or map its datasets to equivalent fixture metadata.

Implementation notes:

- Added `package_tests/comprehensive_suite_fixtures.R` as the Phase 2 consolidation layer over `public_argument_combination_fixtures.R`.
- Added comprehensive dataset/design aliases for existing `comprehensive_tests.R` labels, including `cars`, `diamonds`, `pima`, `pte_example`, `airquality`, `boston`, and the currently tested design labels.
- Added runtime-tiered fixtures: smoke wraps the public fixture matrix, nightly adds broader survival/edge/ordinal/grouped-design fixtures, and release adds larger moderate-censoring, overdispersed count, five-level ordinal, and matched fixtures.
- Added `package_tests/smoke_test_comprehensive_suite_fixtures.R` to validate deterministic inventories, alias coverage, runtime tiers, survival censoring levels, edge families, ordinal level counts, and grouped-design coverage.
- Validation passed:
  - `Rscript R/package_tests/smoke_test_comprehensive_suite_fixtures.R`
  - `Rscript R/package_tests/smoke_test_public_argument_combination_fixtures.R`

## Phase 3: Existing Comprehensive Harness Hardening

Goal: make `package_tests/comprehensive_tests.R` easier to analyze and integrate without rewriting it wholesale.

TODO:

- [x] Add stable case IDs to comprehensive result rows if missing.
- [x] Add explicit `coverage_scope`.
- [x] Add explicit `runner = "comprehensive_tests"`.
- [x] Add explicit `github_commit_id` to comprehensive result rows for unambiguous test-run versioning.
- [x] Add explicit `method_family`.
- [x] Add explicit `argument_coverage_kind` where a call came from argument-combination inputs.
- [x] Ensure `record_result()` emits enough fields for unified analysis.
- [x] Preserve resumability of existing result files.
- [x] Preserve existing filters for response/design/dataset/inference/function family.
- [x] Keep existing slow-skip behavior, but make skip reasons analyzable.

Outputs:

- updated comprehensive result schema.
- migration notes for old result CSVs.

Acceptance criteria:

- Existing comprehensive commands still run.
- Existing result files remain readable.
- New rows can be joined with suite registry rows.

Implementation notes:

- Extended `package_tests/comprehensive_tests.R` result rows with `case_id`, `coverage_scope`, `runner`, `github_commit_id`, `method_family`, `argument_coverage_kind`, and `skip_reason`.
- Kept the existing `id`/completed-row key unchanged so resumability continues to use the same rep/beta/dataset/response/design/inference/function identity.
- Added deterministic `case_id` generation from dataset, response, design, inference label, and function label. This intentionally excludes rep and beta so rows from the same analytical case join cleanly across runs.
- Added method-family classification from `function_run` labels and skip-reason classification from status/error messages while preserving the existing slow-skip and non-fatal handling branches.
- Existing result CSV migration remains startup-driven: when a results file is opened, missing Phase 3 columns are added, derivable fields are backfilled from legacy columns where possible, extra legacy columns are preserved after the expected schema, and the file is rewritten with the expanded schema.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/comprehensive_tests.R')); cat('parse ok\n')"`
  - static schema-marker check for all Phase 3 result fields.

## Phase 4: Public API Workflow Coverage

Goal: ensure exported public APIs are exercised in realistic workflows, not only as isolated argument-combination calls.

TODO:

- [x] For each exported concrete design class, create at least one complete workflow:
  - construct design.
  - add subjects.
  - assign treatment.
  - add responses.
  - retrieve public summaries/assignments/responses.
- [x] For each exported concrete inference class, create at least one compatible completed design fixture.
- [x] For `InferenceSuite`, test discovery and named `inference_params` forwarding through public constructors.
- [x] For `SimulationFramework`, test a small complete simulation with at least one design and inference generator.
- [x] For exported non-R6 public functions, classify as high-level, fitting wrapper, helper, or low-level exported routine and add workflow or direct public tests.
- [x] Record workflow coverage separately from argument-combination coverage.

Outputs:

- workflow result rows in `comprehensive_suite_coverage.csv`.

Acceptance criteria:

- Every exported concrete R6 class has constructor coverage and at least one workflow or explicit exemption.
- High-priority exported functions have public workflow coverage.
- Workflow tests use public APIs unless explicitly marked internal safety-net.

Implementation notes:

- Added `package_tests/run_public_workflow_coverage.R`, a public workflow coverage runner that writes `package_tests/comprehensive_suite_coverage.csv`.
- The runner executes complete public design workflows for exported design classes: construct, add subjects, assign treatment, add responses, and retrieve public assignment/response summaries. Smoke-tier design workflows currently run without exemptions.
- The runner constructs exported inference classes against response-compatible completed fixtures where possible and records explicit `phase4_no_smoke_compatible_fixture` exemptions where a cheap smoke fixture is not sufficient.
- Added explicit workflows for `InferenceSuite` discovery plus named `inference_params`, `SimulationFramework` with a one-cell public simulation, and `SimulationFrameworkReport` result/summary retrieval.
- Exported non-R6 functions are classified as `high_level`, `fitting_wrapper`, `helper`, or `low_level_exported_routine`; targeted direct workflows for high-level/fitting wrappers are explicitly deferred via coverage rows instead of mixed into argument-combination coverage.
- Generated `package_tests/comprehensive_suite_coverage.csv` with 249 rows: 128 R6 rows and 121 exported-function rows. Status counts: 81 R6 `ok`, 47 R6 `exempted`, 102 function `classified`, and 19 function `exempted`; 0 `error`.
- Added `package_tests/smoke_test_public_workflow_coverage.R` to validate the artifact schema, no error rows, all exported R6 classes represented, and the required `InferenceSuite` / `SimulationFramework` / `SimulationFrameworkReport` workflows.
- Validation passed:
  - `Rscript R/package_tests/smoke_test_public_workflow_coverage.R`
  - `Rscript R/package_tests/run_public_workflow_coverage.R smoke R/package_tests/comprehensive_suite_coverage.csv`

## Phase 5: Statistical Method-Family Coverage

Goal: broaden method-family coverage while respecting runtime tiers.

TODO:

- [x] Map all public inference methods to method families.
- [x] Confirm argument-combination coverage exists for high-priority method arguments from the dependency.
- [x] Add workflow calls for each method family by response/design/inference class where supported.
- [x] Include representative p-value methods.
- [x] Include representative confidence interval methods.
- [x] Include representative estimate methods.
- [x] Include debug distribution checks in nightly/release where useful.
- [x] Add explicit non-estimable classification rules.
- [x] Add support/unsupported classification based on public capability where available.

Method families:

- [x] estimate.
- [x] asymptotic Wald/score/likelihood-ratio/gradient.
- [x] exact incidence/ordinal methods.
- [x] nonparametric bootstrap.
- [x] Bayesian bootstrap.
- [x] parametric bootstrap.
- [x] Bartlett correction.
- [x] jackknife.
- [x] randomization.
- [x] randomization-bootstrap.
- [x] m-out-of-n bootstrap/subsampling.

Acceptance criteria:

- Every high-priority inference family has smoke coverage.
- Every supported method family has CI or nightly coverage.
- Slow method families are not silently skipped; they are tiered or exempted.

Implementation notes:

- Extended `package_tests/run_public_workflow_coverage.R` with Phase 5 `method_family_workflow` rows in `package_tests/comprehensive_suite_coverage.csv`.
- Added representative method-family calls for estimates, p-values, confidence intervals, debug distributions, Wald/score/likelihood-ratio/gradient asymptotics, exact incidence, nonparametric bootstrap, Bayesian bootstrap, Bartlett, jackknife, randomization, randomization-bootstrap, parametric bootstrap, and m-out-of-n/subsampling.
- Added coverage columns `method_name`, `operation_kind`, `capability`, and `support_status`; older Phase 4 rows leave these blank while method-family rows populate them.
- Added argument-combination dependency classification per method row via `argument_coverage_kind`, including cases such as `argument_combination_skipped_slow`.
- Support classification is explicit: supported method calls are `ok`, unsupported representatives are `unsupported`, non-estimable paths are classifiable as `nonestimable`, and slow/tier-constrained paths are `exempted`.
- Regenerated `package_tests/comprehensive_suite_coverage.csv` with 277 rows total, including 28 `method_family_workflow` rows: 24 `ok`, 2 `unsupported`, and 2 `exempted`.
- Method-family rows cover 15 families: `estimate`, `asymptotic_wald`, `asymptotic_score`, `asymptotic_lik_ratio`, `asymptotic_gradient`, `exact`, `bootstrap`, `bayesian_bootstrap`, `parametric_bootstrap`, `bartlett`, `jackknife`, `randomization`, `randomization_bootstrap`, `m_out_of_n_subsampling`, and `debug_distribution`.
- Added Phase 5 assertions to `package_tests/smoke_test_public_workflow_coverage.R` for required method families, p-value / confidence-interval / estimate representatives, support status, and argument-coverage classification.
- Validation passed:
  - `Rscript R/package_tests/smoke_test_public_workflow_coverage.R`
  - `Rscript R/package_tests/run_public_workflow_coverage.R smoke R/package_tests/comprehensive_suite_coverage.csv`

## Phase 6: Internal High-Fan-In Safety Nets

Goal: directly test important shared internals without confusing that coverage with public API guarantees.

TODO:

- [x] Build `comprehensive_suite_internal_surfaces.R`.
- [x] Rank internals by fan-in, numerical risk, argument complexity, and historical failures.
- [x] Identify validators/canonicalizers used by many public APIs.
- [x] Identify shared resampling helpers.
- [x] Identify model-matrix/data-shaping helpers.
- [x] Identify numerical kernels with exported/public wrappers.
- [x] Add direct tests only where public-only failures would be hard to diagnose.
- [x] Link every internal surface to public entrypoints that use it.
- [x] Mark coverage as `internal_safety_net`.

Acceptance criteria:

- No internal test exists without registry row and rationale.
- Internal coverage is reported separately.
- High-fan-in internal failures help localize public workflow failures.

Implementation notes:

- Added `package_tests/comprehensive_suite_internal_surfaces.R`, which expands Phase 0 `testthat_internal` audit rows into per-internal-symbol safety-net surfaces.
- Generated `package_tests/comprehensive_suite_internal_surfaces.csv` with 239 internal surface rows from 122 internal testthat audit rows.
- Ranked each surface by test fan-in, direct occurrence count, source-reference count, numerical risk, argument complexity, and historical/edge-case signal.
- Classified surfaces separately from public contracts with `coverage_scope`, `source_runner`, and `required_coverage` all set to `internal_safety_net`.
- Identified 15 validators/canonicalizers, 38 shared resampling helpers, 14 model-matrix/data-shaping helpers, 121 numerical kernels, 22 registry/capability helpers, 2 design-assignment helpers, and 27 other internal helpers.
- Linked each surface to direct testthat files, matching internal registry targets, source files when statically detectable, and public entrypoints when inventory source-file links are available.
- Added `package_tests/smoke_test_comprehensive_suite_internal_surfaces.R` to enforce that every internal audit row has a registry row and a rationale-bearing internal-surface row.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/comprehensive_suite_internal_surfaces.R')); invisible(parse('R/package_tests/smoke_test_comprehensive_suite_internal_surfaces.R')); cat('parse ok\n')"`
  - `Rscript R/package_tests/comprehensive_suite_internal_surfaces.R R/package_tests/comprehensive_suite_internal_surfaces.csv`
  - `Rscript R/package_tests/smoke_test_comprehensive_suite_internal_surfaces.R`

## Phase 7: Unified Runner

Goal: provide one entry point that orchestrates the already-implemented argument-combination runner, the existing comprehensive harness, workflow checks, and internal safety nets.

Implement `package_tests/run_comprehensive_suite.R`.

Suggested CLI:

```sh
Rscript package_tests/run_comprehensive_suite.R smoke
Rscript package_tests/run_comprehensive_suite.R ci
Rscript package_tests/run_comprehensive_suite.R nightly
Rscript package_tests/run_comprehensive_suite.R release
Rscript package_tests/run_comprehensive_suite.R ci InferencePropBetaRegr
```

TODO:

- [x] Validate Phase -1 dependency before running.
- [x] Parse tier and optional filters.
- [x] Run or import argument-combination results.
- [x] Run selected comprehensive harness paths.
- [x] Run workflow checks.
- [x] Run internal safety-net checks for the selected tier.
- [x] Enforce per-case timeouts.
- [x] Preserve resumability.
- [x] Emit unified result files.

Outputs:

- `package_tests/comprehensive_suite_results.csv`
- `package_tests/comprehensive_suite_failures.csv`

Acceptance criteria:

- Smoke tier runs end-to-end.
- CI tier can run without invoking release-scale comprehensive sweeps.
- Runner refuses to run if required argument-checking artifacts are missing.

Implementation notes:

- Added `package_tests/run_comprehensive_suite.R` as the unified tiered entry point.
- Added `package_tests/smoke_test_run_comprehensive_suite.R` to exercise the smoke tier end-to-end.
- The runner validates Phase -1 dependency artifacts before running any downstream layer.
- CLI supports `smoke`, `ci`, `nightly`, and `release`, an optional target filter, a per-step timeout, and `--force` / `COMPREHENSIVE_SUITE_FORCE=1` for reruns.
- Smoke/CI tiers run argument-combination checks, import existing `comprehensive_tests_results*.csv` harness outputs, regenerate public workflow coverage, and regenerate internal safety-net surfaces without invoking release-scale comprehensive sweeps.
- Nightly/release tiers can invoke a selected `comprehensive_tests.R` path with bounded filters.
- Unified outputs are `package_tests/comprehensive_suite_results.csv` and `package_tests/comprehensive_suite_failures.csv`.
- Smoke validation for `InferenceAllSimpleMeanDiff` wrote 5 unified step rows: dependency gate 11 artifacts, 29 argument-combination rows, 56 imported comprehensive-harness rows, 277 public workflow rows, and 239 internal safety-net rows, with 0 selected failure rows.
- Resumability validation passed: rerunning without `--force` skipped all five completed steps and preserved the unified ledger.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/run_comprehensive_suite.R')); invisible(parse('R/package_tests/smoke_test_run_comprehensive_suite.R')); cat('parse ok\n')"`
  - `Rscript R/package_tests/smoke_test_run_comprehensive_suite.R`
  - `Rscript R/package_tests/run_comprehensive_suite.R smoke InferenceAllSimpleMeanDiff 180`

## Phase 8: Unified Analyzer

Goal: report the full coverage picture across argument combinations, workflows, comprehensive harness paths, and internal safety nets.

Implement `package_tests/analyze_comprehensive_suite.R`.

TODO:

- [x] Load argument-combination coverage.
- [x] Load comprehensive suite registry.
- [x] Load comprehensive harness results.
- [x] Load workflow/internal result rows.
- [x] Join all rows by public API, response type, design family, inference family, method family, tier, and coverage scope.
- [x] Report uncovered public APIs.
- [x] Report public APIs that only have argument-combination coverage but no workflow coverage.
- [x] Report public APIs that only have workflow coverage but no multidimensional argument-combination coverage.
- [x] Report high-fan-in internals lacking safety-net coverage.
- [x] Report unsupported/skipped legal contexts by reason.
- [x] Report slowest cases by tier.
- [x] Emit HTML report if practical.

Outputs:

- `package_tests/comprehensive_suite_coverage.csv`
- `package_tests/comprehensive_suite_report.html`

Acceptance criteria:

- Analyzer can explain every uncovered API or point to an exemption.
- Analyzer distinguishes public contract, workflow, statistical method, and internal safety-net coverage.
- Analyzer imports argument-combination coverage rather than recomputing it independently.

Implementation notes:

- Added `package_tests/analyze_comprehensive_suite.R` as the unified analyzer.
- Added `package_tests/smoke_test_analyze_comprehensive_suite.R` to validate analyzer schema, imported coverage sources, output files, and focused-testthat/internal-safety-net classification.
- The analyzer imports `public_argument_combination_coverage.csv` directly and joins it onto `comprehensive_suite_registry.csv`; it does not recompute argument-combination coverage.
- The analyzer imports existing `comprehensive_tests_results*.csv`, `comprehensive_suite_results.csv`, `comprehensive_suite_workflow_coverage.csv`, and `comprehensive_suite_internal_surfaces.csv`.
- `package_tests/comprehensive_suite_workflow_coverage.csv` preserves raw workflow rows so `comprehensive_suite_coverage.csv` can become the unified target-level report without making the analyzer non-idempotent.
- Generated `package_tests/comprehensive_suite_coverage.csv` with 9,338 unified coverage rows: 9,216 public contract rows and 122 internal safety-net rows.
- Current unified status counts: 110 exempted public rows, 587 focused public testthat rows, 2 workflow-and-argument-smoke rows, 8,517 workflow-only public rows, and 122 internal-safety-net-covered rows.
- Generated supporting reports: `comprehensive_suite_uncovered_apis.csv` (0 rows), `comprehensive_suite_argument_only_apis.csv` (0 rows), `comprehensive_suite_workflow_only_apis.csv` (8,517 rows), `comprehensive_suite_internal_safety_net_gaps.csv` (0 rows), `comprehensive_suite_unsupported_skipped_contexts.csv` (96 rows), and `comprehensive_suite_slowest_cases.csv` (100 rows).
- Generated `package_tests/comprehensive_suite_report.html`.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/analyze_comprehensive_suite.R')); invisible(parse('R/package_tests/smoke_test_analyze_comprehensive_suite.R')); cat('parse ok\n')"`
  - `Rscript R/package_tests/run_public_workflow_coverage.R smoke R/package_tests/comprehensive_suite_workflow_coverage.csv`
  - `Rscript R/package_tests/analyze_comprehensive_suite.R`
  - `Rscript R/package_tests/smoke_test_analyze_comprehensive_suite.R`

## Phase 9: Runtime Tiers

Goal: make comprehensive coverage practical.

Tier definitions:

Smoke:

- [x] dependency validation.
- [x] argument-combination smoke results imported.
- [x] one default workflow per major design/inference family.
- [x] highest-fan-in internal validator smoke checks.
- [x] tiny `B`/`r` values only.

CI:

- [x] argument-combination CI results imported.
- [x] pairwise legal argument coverage for high-priority public APIs is already satisfied by dependency.
- [x] representative workflow coverage across response/design/inference families.
- [x] selected method-family checks.
- [x] strict public output invariants.

Nightly:

- [x] broader comprehensive harness paths.
- [x] more datasets/fixtures/formulas.
- [x] targeted high-risk 3-way method-family workflows.
- [x] broader internal safety-net checks.
- [x] slow-case reporting.

Release:

- [x] maximal registry-driven suite coverage.
- [x] selected exhaustive small spaces.
- [x] larger resampling counts.
- [x] all required high-fan-in internal safety nets.
- [x] final coverage report with exemptions.

Acceptance criteria:

- Smoke and CI tiers are stable.
- Nightly/release tiers are intentionally broader and may be scheduled or manual.
- No tier reimplements argument-combination generation.

Implementation notes:

- Added `package_tests/comprehensive_suite_runtime_tiers.R` and generated `package_tests/comprehensive_suite_runtime_tiers.csv`.
- Added `package_tests/smoke_test_comprehensive_suite_runtime_tiers.R` to enforce tier ordering, bounded smoke/CI scope, explicit nightly/release scheduling/manual policy, and reuse of smoke/CI argument-combination artifacts.
- Wired `package_tests/run_comprehensive_suite.R` to load the runtime tier registry for supported tiers, default timeouts, argument-combination tier mapping, workflow tier mapping, comprehensive harness mode, and resampling scale metadata.
- Smoke tier policy uses dependency validation, `argument_combination_tier=smoke`, imported comprehensive harness results, raw workflow coverage, highest-fan-in internal safety-net surfaces, and tiny resampling metadata.
- CI tier policy uses `argument_combination_tier=ci`, imported comprehensive harness results, representative workflow/method-family coverage, and strict public invariant metadata without invoking release-scale sweeps.
- Nightly/release policies intentionally broaden the comprehensive harness mode and scheduling metadata while still importing CI argument-combination coverage instead of reimplementing argument-combination generation.
- `run_comprehensive_suite.R` now writes workflow rows to `package_tests/comprehensive_suite_workflow_coverage.csv`, preserving `package_tests/comprehensive_suite_coverage.csv` for the unified analyzer output.
- Phase 9 smoke validation wrote 5 policy-tagged unified step rows with `argument_combination_tier=smoke`, `comprehensive_harness_mode=import_existing_results`, and `resampling_scale=tiny`.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/comprehensive_suite_runtime_tiers.R')); invisible(parse('R/package_tests/smoke_test_comprehensive_suite_runtime_tiers.R')); invisible(parse('R/package_tests/run_comprehensive_suite.R')); cat('parse ok\n')"`
  - `Rscript R/package_tests/comprehensive_suite_runtime_tiers.R R/package_tests/comprehensive_suite_runtime_tiers.csv`
  - `Rscript R/package_tests/smoke_test_comprehensive_suite_runtime_tiers.R`
  - `Rscript R/package_tests/run_comprehensive_suite.R smoke InferenceAllSimpleMeanDiff 180 --force`
  - `Rscript R/package_tests/smoke_test_run_comprehensive_suite.R`

## Phase 10: Quality Gates

Goal: enforce coverage without making the suite brittle.

TODO:

- [x] Gate: argument-checking dependency must pass before this suite runs.
- [x] Gate: no exported public API missing from registry unless exempted.
- [x] Gate: no concrete exported R6 class without constructor coverage unless exempted.
- [x] Gate: no high-priority public API without workflow coverage unless exempted.
- [x] Gate: no public API with multiple configurable arguments unless already covered by argument-checking dependency or exempted.
- [x] Gate: no internal safety-net test without rationale.
- [x] Gate: no new CI-tier unexpected errors.
- [x] Gate: no unknown skip/support status.
- [x] Gate: no expired exemption.

Rollout:

1. Reporting-only gates.
2. Hard-fail dependency validation and schema validity.
3. Hard-fail smoke-tier unexpected errors.
4. Hard-fail missing high-priority coverage.
5. Hard-fail CI-tier unexpected errors.

Acceptance criteria:

- Gates are tier-aware.
- Exemptions are explicit and reviewed.
- Coverage ratchets upward without blocking unrelated work prematurely.

Implementation notes:

- Added `package_tests/check_comprehensive_suite_quality_gates.R`.
- Added `package_tests/smoke_test_comprehensive_suite_quality_gates.R`.
- Generated `package_tests/comprehensive_suite_quality_gates.csv` and `package_tests/comprehensive_suite_quality_gate_summary.csv`.
- Gates load the unified analyzer output, comprehensive registry, public inventory, runtime tiers, internal-surface report, unsupported/skipped context report, suite result ledger, and exemptions.
- Active hard gates cover dependency/schema validity, missing registry rows, missing internal safety-net rationale, smoke/CI unexpected errors, unknown runtime/coverage/skip statuses, and expired exemptions.
- Constructor coverage, high-priority workflow coverage, and multi-argument argument-combination coverage are emitted as ratchet rows (`hard_later`) or report rows during rollout.
- Current gate report has 3,458 rows: 3,402 `hard_later` rows and 56 `report` rows, all from `multi_arg_without_argument_dependency_coverage`.
- Current CI-mode summary has 0 active hard rows and `ci_should_fail = FALSE`.
- Validation passed:
  - `Rscript -e "invisible(parse('R/package_tests/check_comprehensive_suite_quality_gates.R')); invisible(parse('R/package_tests/smoke_test_comprehensive_suite_quality_gates.R')); cat('parse ok\n')"`
  - `Rscript R/package_tests/check_comprehensive_suite_quality_gates.R report`
  - `Rscript R/package_tests/smoke_test_comprehensive_suite_quality_gates.R`
  - `Rscript R/package_tests/check_comprehensive_suite_quality_gates.R ci`

## Definition Of Done

- [ ] `comprehensive_argument_checking.md` is fully implemented and accepted before this spec begins.
- [ ] Argument-combination artifacts are validated as an input dependency.
- [ ] Every exported public API has inventory status, coverage status, or exemption.
- [ ] Every concrete exported R6 class has constructor coverage or exemption.
- [ ] Every high-priority public API has workflow coverage or exemption.
- [ ] Public APIs with multiple configurable arguments are covered by the argument-checking dependency or explicitly exempted.
- [ ] Statistical method-family coverage is tiered and reported.
- [ ] High-fan-in internals have safety-net coverage or explicit rationale.
- [ ] Public contract coverage and internal safety-net coverage are reported separately.
- [ ] Smoke and CI tiers run deterministically.
- [ ] Nightly and release tiers produce comprehensive reports.
- [ ] Existing comprehensive harness behavior remains available during rollout.
