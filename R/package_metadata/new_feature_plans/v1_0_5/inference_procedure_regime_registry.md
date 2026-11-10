# Inference procedure regime registry (asymptotic vs finite-sample)

> **Release:** v1.0.5 TODO-192 (`future_release_plans/release_v1_0_5.md`).
> **Depends on:** nothing. **Consumers:** the published calibration study
> (`release_v1_2_0.md` TODO-36, `R/package_tests/calibration/`), later the
> comprehensive suite.

Status: sections 1-3 and Tests IMPLEMENTED 2026-11-10; section 4 not implemented (owner decision).

## Why

The first real calibration campaign (`2026-11-09-8c32d060`) flagged 736 of
2,946 null cells at n = 50 after wave 3. About 550 of them are ordinary
small-sample excess (size 0.06-0.10) in asymptotic tests (Wald, score,
likelihood ratio, gradient) with seven coefficients at n = 50. That is how
those procedures behave, not a defect, and failing them buries the real
defects (randomization tests at 0.07-0.17, ExtendedRobins on pairs at 0.15-0.18,
the KK conditional-logit classes at 0.19-0.29, ContinLin HC2 Wald at 0.17).

Owner ruling 2026-11-10: asymptotic procedures pass at small n unless
egregious, and the real test for them is large n. Finite-sample procedures
(exact, randomization) are held to nominal at every n. The regime is a
property of the **procedure** (the `run_all_inference()` sentinel label), not
of the class.

Today there is no single classification:

* `R/EDI/R/inference_suite.R`, `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY` /
  `EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY`: the 14 procedure labels with
  their capability and method, load-time checked against
  `contracts_mixins.R`'s `public_methods_for_capability` and completeness
  checked by `run_all_inference_check_sentinel_completeness()`. No regime.
* `R/package_tests/comprehensive_suite_registry.R:86` guesses "asymptotic" from
  a regex on method names.
* The calibration scripts hard-code `wald, score, lik_ratio, gradient, exact,
  rand` (e.g. `plot_calibration_study.R:205`, `render_calibration_study_readme.R:101`).

## Design

### 1. The registry: `R/EDI/R/inference_procedure_regime.R` (new)

A self-contained file: base R only, no R6, no package internals, no side
effects beyond defining objects. Self-contained because the calibration
publish job runs the gate scripts **without EDI installed** (it installs only
ggplot2 and data.table), so the scripts `sys.source()` this file from the
checkout instead of calling `EDI:::`.

```r
EDI_INFERENCE_PROCEDURE_REGIMES = c("asymptotic", "finite_sample")

# One entry per run_all_inference() sentinel label.
EDI_INFERENCE_PROCEDURE_REGIME = c(
	exact                     = "finite_sample",
	rand                      = "finite_sample",
	wald                      = "asymptotic",
	jackknife                 = "asymptotic",
	score                     = "asymptotic",
	lik_ratio                 = "asymptotic",
	gradient                  = "asymptotic",
	lik_ratio_bartlett_approx = "asymptotic",
	lik_ratio_bartlett_exact  = "asymptotic",
	param_boot                = "asymptotic",
	param_boot_direct         = "asymptotic",
	bootstrap                 = "asymptotic",
	bayes_boot                = "asymptotic",
	rand_bootstrap            = "asymptotic"
)

inference_procedure_regime = function(procedure) { ... }  # vectorised; NA_character_ for unknown labels
```

Each entry gets a one-line comment saying why (e.g. Bartlett: one order better,
still asymptotic; `rand_bootstrap`: resamples the data, so it does not inherit
the randomization test's exactness; `rand`: exact under the sharp null by
construction).

Known per-cell exceptions are **not** encoded here: an `exact` procedure that
falls back to a normal approximation (JT past its enumeration limit), or a
randomization test that drops failed-fit draws, is still `finite_sample`, and
when it misbehaves that is a defect to fix or a cell to accept in
`calibration_study_accepted.csv`.

### 2. Tie it to the sentinel tables (package, load time)

In `inference_suite.R`, after the two priority tables are built, `stopifnot`
(with a clear message) that the union of their labels equals
`names(EDI_INFERENCE_PROCEDURE_REGIME)` exactly, and that every value is in
`EDI_INFERENCE_PROCEDURE_REGIMES`. Adding a sentinel without a regime, or
leaving a stale regime entry, fails package load. Add the new file to
`DESCRIPTION`'s `Collate` before `inference_suite.R`.

No user-visible behaviour changes. Internal (`@noRd`); no export.

### 3. Calibration gate (`R/package_tests/calibration/`)

* `calibration_study_stats.R` (or the gate script directly) sources
  `R/EDI/R/inference_procedure_regime.R` relative to the script directory.
* A tolerance schedule, one constant, for asymptotic procedures:

  | n | size level | coverage level |
  |---|---|---|
  | < 200 | 0.10 | 0.90 |
  | 200 to < 1000 | 0.075 | 0.925 |
  | >= 1000 | 0.05 | 0.95 |

  Finite-sample procedures: 0.05 / 0.95 at every n. A procedure label not in
  the registry stops the gate with an error (never silently strict or lax).
  (The n = 200 level was proposed, not yet explicitly confirmed by the owner;
  keep it a single named constant so it is a one-line change.)
* `analyze_calibration_study.R:83-84` sets `size_null` / `coverage_null` from
  the schedule instead of 0.05 / 0.95; rows of `calibration_study_accepted.csv`
  still override per cell. Applies to both gate stages (screen and
  confirmation) and to non-null coverage (`pw`), which use the same levels.
* Summary tables and the campaign README show the level each cell was tested
  against (e.g. a `level` column, and "size 0.07 (level 0.10)" in the failing
  table), so a pass at n = 50 does not look unexplained.
* `render_calibration_study_readme.R` "About" text: explain the schedule and
  the regime split, citing the registry file.
* Replace the hard-coded procedure lists in the plot/readme scripts with the
  registry's names where they mean "all procedures" (keep display order).

### 4. Open decision for the owner (do not implement without asking)

The publish job checks out the **campaign's pinned commit**
(`calibration-study.yml`, `ref: needs.plan.outputs.sha`), so gate changes reach
only campaigns started after they land. The running campaign
(`2026-11-09-8c32d060`) will keep the strict gate unless the publish job is
changed to run the analysis scripts from `main`. Reproducibility argues for
the pinned commit; the owner decides.

## Tests

* `R/package_tests/testthat_bulk/test-inference-procedure-regime-registry.R`
  (or under `R/EDI/tests/testthat/` for the package part):
  * every sentinel label of both priority tables has a regime, and every
    regime entry is a sentinel label (the same check as load time, asserted
    directly);
  * values are only `asymptotic` / `finite_sample`; `exact` and `rand` are
    `finite_sample`; `wald`, `score`, `lik_ratio`, `gradient` are `asymptotic`;
  * `inference_procedure_regime()` is vectorised and returns NA for unknown
    labels;
  * the file sources cleanly into an empty environment with base R only (what
    the publish job does).
* Calibration gate test (bulk): a synthetic stats table with one asymptotic
  and one finite-sample cell at each n, showing size 0.07 at n = 50 passes for
  wald and fails for rand, and 0.07 at n = 1000 fails for both; an accepted
  row still overrides; an unknown procedure label errors.
* Re-run the gate on the published wave-3 tables of `2026-11-09-8c32d060`:
  expect roughly 98 flagged cells in 10 classes at n = 50 (the estimate from
  the proposal), and record the actual numbers here.

## Constraints

* R only. No C++ change, no `R CMD INSTALL`, no `load_all()` without
  `compile = FALSE` (project CLAUDE.md). Verify package-side changes with
  `pkgload::load_all("R/EDI", compile = FALSE)`.
* Do not run roxygen; the owner's pre-push regenerates Rd.
* Test file names carry no TODO number; cite the TODO in a top comment.
* NEWS.md (EDI 1.0.5, an internal-change bullet).

## Done

Implemented 2026-11-10 (sections 1-3 and Tests; section 4 left alone, `.github/` untouched).

**What changed**

* `R/EDI/R/inference_procedure_regime.R` (new): `EDI_INFERENCE_PROCEDURE_REGIMES`, `EDI_INFERENCE_PROCEDURE_REGIME` (14 labels, one-line reason each), `inference_procedure_regime()`. Base R only.
* `R/EDI/DESCRIPTION`: file added to `Collate` before `inference_suite.R`.
* `R/EDI/R/inference_suite.R` (new `local({...})` block just before `EDI_INFERENCE_SUITE_METHOD_SENTINELS`): load-time `stop()` if the union of both priority tables' labels differs from the registry's names, or a value is outside `EDI_INFERENCE_PROCEDURE_REGIMES`. Checked with `pkgload::load_all("R/EDI", compile = FALSE)`: loads, 14 sentinels.
* `R/package_tests/calibration/calibration_study_stats.R`: `CAL_GATE_ASYMPTOTIC_SCHEDULE` (the single named constant; n = 200 row still unconfirmed by owner), `CAL_GATE_FINITE_SAMPLE_LEVELS`, `cal_gate_levels(procedure, n, regimes)` (errors on an unregistered label).
* `analyze_calibration_study.R`: sources the registry from `../../../EDI/R/inference_procedure_regime.R` relative to the script; `size_null` / `coverage_null` come from `cal_gate_levels()` on `n_nominal` (accepted rows still override per cell); the non-null coverage (`pw`) test and its gate rows use the schedule (new `pw$coverage_null`); new `regime` column in `calibration_summary.csv` and `power_summary.csv` (with `coverage_null`); failing tables show "size 0.07 (level 0.10)" style values; header comment updated.
* `render_calibration_study_readme.R`: About text explains the schedule and regime split and links the registry; the null bullet no longer says 5% / 95%.
* `plot_calibration_study.R`: sources the registry; the p-value curve procedure factor levels come from the registry (tier-1 six first, rest in registry order).
* Left as is on purpose: `CAL_STUDY_TIER1_METHODS` (the six procedures the monthly tier runs, not "all procedures") and the raw-data column description in the readme.
* Tests: `R/package_tests/testthat_bulk/test-inference-procedure-regime-registry.R`, `test-calibration-gate-regime-levels.R` (the latter runs the real analysis script on a synthetic stats dir).
* `R/EDI/NEWS.md`: Internal bullet under 1.0.5.

**Tests** (run from the repo root, `testthat::test_file(..., reporter = "silent")`)

* `test-calibration-gate-regime-levels.R`: 5 tests, 17 expectations, 0 failed.
* `test-inference-procedure-regime-registry.R`: 6 tests, 14 expectations, 0 failed (under the installed EDI 1.0.4 the last test skips because 1.0.4 predates the registry; run under `load_all(compile = FALSE)` it executes and passes).
* Existing: `test-inference-suite-run-all-inference-case-30.R` 4 expectations pass; `case-31.R` (sentinel completeness) 1 pass under `load_all(compile = FALSE)` (it calls internals, so it errors against the installed package, as before); `test-inference-suite-class-predicates-acronym-split-priority-derivation-...reference.R` 35 pass; `test-inference-suite-bootstrap-helper-contracts.R` 46 pass. No existing bulk test exercises the calibration scripts.

**Wave-3 re-gate** (`Rscript R/package_tests/calibration/analyze_calibration_study.R --stats-dir <results-branch clone>/campaigns/2026-11-09-8c32d060/stats --out-dir <scratch>`, no `--final`, default accepted file): failing cells 98 (was 736) in 10 classes; 89 at n = 50 and 9 at n = 52 (pair-switching, n_nominal 50); 0 power-coverage failures. By regime: 87 asymptotic, 11 finite-sample (all `rand`); by procedure: score 32, gradient 20, lik_ratio 19, wald 16, rand 11. Classes: CountZeroInflatedNegBin 46, CountZeroInflatedPoisson 19, CountHurdlePoisson 15, OrdinalCauchitRegr 7, IncidExtendedRobins 4, IncidKKCondLogitGLMMOneLik 2, IncidLogBinomial 2, ContinLin 1, IncidBinomialIdentityRiskDiff 1, IncidKKCondLogitOneLik 1. 168 tests flagged at screen (provisional; confirmation pending as in the published run). This matches the proposal's estimate (about 98 in 10 classes).

**Deviations / notes**

* The schedule lives in `calibration_study_stats.R` and the registry is sourced by the scripts that gate or plot, not by the stats file, because other scripts source the stats file and need no registry.
* The schedule keys on `n_nominal`, not `n`, so pair-switching's n = 52 is tested as 50.
* Section 4 (campaign pinned commit vs `main`) is untouched: the running campaign keeps the strict gate until the owner decides.

