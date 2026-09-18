# Full Test Coverage: 65% → Near 100%

> **Depends on:** none directly -- builds on the already-fixed
> `test-coverage-R.yaml` pipeline (the `stop_on_failure = FALSE` fix so a
> single bulk-suite failure no longer blocks the Codecov upload entirely,
> and folding `R/package_tests/testthat_bulk/` into the `code=` coverage
> pass, both 2026-08-28). Independent of any other open plan; this is pure
> test-writing/triage work, not a source-behavior change. Slated for
> **v1.2.0** (`release_v1_2_0.md → TODO-18`; moved from v1.1.0
> `release_v1_1_0.md → TODO-17m` on 2026-09-06, lighten-1.1.0 pass, user
> decision — this plan's own zero-dependency status is exactly why moving
> it cost nothing), reframed as a rolling non-gating track.

## Status

**Current coverage: 64.79%** (run against commit `d41880c1`, 2026-08-28 --
the first successful upload after the pipeline fixes above). This remains
the historical measured baseline; new tests do not establish a new percentage
until the instrumented coverage workflow runs.

**First test-writing batch (2026-09-16):** five focused bulk files add 99 passing
assertions, validated together through `ci/run_selected_tests.R` against the
already-installed package, without compilation:

- `test-resampling-parallel-threshold-contracts.R`: cross the real parallel
  work thresholds for OLS, ridit and Wilcoxon kernels; check bootstrap indexing,
  noisy random-bootstrap fits, degenerate resamples and nonfinite bisection
  midpoints against independent R references.
- `test-jonckheere-exact-enumeration.R`: exact ordinal tails against exhaustive
  individual allocations, including ties, unequal arms and repeated calls.
- `test-matching-ols-degenerate-geometry.R`: pair-only, reservoir-only and
  zero-covariate combined OLS designs, with an independent treatment estimate.
- `test-random-block-unbalanced-allocation.R`: interleaved strata, rounded
  treatment probability, reproducibility, all-control and empty streams.
- `test-quantile-rand-ci-coverage.R`: analytic inversion references for matched,
  reservoir and Fisher-combined p-values, bracketing fallbacks, failed estimates,
  validation and a completed KK quantile inference workflow.

**Continued batches (2026-09-16):** the initial 34-file batch passed 608
assertions through the shard runner. Further tests cover callback recovery and
joint survival-field resampling, R bootstrap CI missing-value recovery/deadlines,
KK compound inverse-variance weighting, independently calculated KK Wilcoxon
statistics and sharp-null transformations, survival stepwise OLS fallback,
beta boundary safeguards, ordinal CLMM integrated likelihood/score/curvature,
sparse matching data and invariant-column filtering, sequential covariate
schema changes, gcomp risk-ratio log-scale resampling and weighted RMST with
Greenwood-to-bootstrap fallback. Local timings continue to feed the correctness
manifest; coverage runtimes remain unmeasured conservative defaults.

The latest batch adds endpoint-only zero-one-inflated beta score/Hessian
references, weighted hurdle Poisson GLMM likelihood/score/Hessian references,
KK CLMM response-cardinality diagnostics, and serial Hodges-Lehmann bootstrap
pairwise-median references. An unfinished nonlogit weighted CLMM comparison
exposed a cold-start fitting defect; its failing regression is preserved in the
findings report rather than weakening its statistical reference or leaving the
bulk suite failing. The three delegated agents subsequently hit the account
usage limit; the remaining written files were reviewed and validated locally.

Local continuation adds binary/no-covariate adjacent-category and stereotype
likelihood references, disjoint-interval Turnbull statistics, independently
integrated Weibull frailty likelihood derivatives, weighted Poisson estimates
and uncertainty, interleaved SPBR redraws, partial-odds backend diagnostics,
reservoir variance boundaries, negative-binomial dispersion profiling,
Cauchy combined-evidence grouping, adjacent-category randomization against
independent multinomial fits, and binary stereotype profile/randomization
likelihoods against logistic regression, plus simulation-report finite-value
denominators, exact calibration p-values, custom-null classification, compressed
result imports and empty-file handling.
The partial-odds weighted MASS fallback exposed another data-environment defect;
its failing statistical regression is also preserved in the findings report.

Separate defects and historical triage corrections are recorded in
[`coverage_gap_findings_20260916.md`](../reports/coverage_gap_findings_20260916.md).
Those initial batches contained no production fixes or exclusions.

**Authorized fix-and-regression continuation (2026-09-17):** source fixes now
accompany active regressions for the six original defects and additional
first-arrival, empty-report, worker-error, multinomial-sampler and uniform-weight
cases. Eight additional files bring this session's additions to 42 bulk files.
After the user rebuilt the package, eight verification files pass 341
assertions through the shard runner against the installed package, including
the latest tiny-interval and multicategory sampler regressions. No checkout
R definitions are substituted in this verification. The broader shipped Bayesian
bootstrap suite also passes (its mirai case is skipped under the default CRAN
flag), after correcting a separated finite-MLE smoke fixture.
All 42 added files now pass together against the user's rebuilt package
(887 assertions). The earlier parallel-threshold bisection test now checks
actual two-sided crossings rather than preserving the former upper-tail bug.
No compilation has been run by this team.
Sharding continues to include every new file in correctness and coverage tiers.

Further continuation adds independent weighted constrained-binomial fits (58
passing assertions) and simulation worker stage/recovery/cache contracts (128
passing assertions), both verified against the rebuilt installed package.
Weighted beta fitting adds 47 passing assertions against independent density
and Hessian references; worker inference dispatch adds another 64. An
independently profiled conditional-Poisson reference adds 18 assertions and
exposes a point-estimate weight-scale defect. Its later R-only normalization
fix is verified against the user's rebuilt installed package (2026-09-18).
Mixed-endpoint/interior ZOIB likelihoods add 31 installed-package assertions.
Conditional-logistic weighted references add 35 assertions and expose discarded
concordant-pair weight misalignment. That shared R helper now aligns retained
pairs, normalizes fitting weights and restores uncertainty scale; its later
fix also passes against the rebuilt installed package.
Further tests cover general Weibull exact/left/right/interval censoring (47
assertions), actual serial custom-data resume with Welch statistical references,
and proportion g-computation standardization (35 assertions). The serial run
exposes dropped simulation-mode metadata; the R loader now preserves the mode
and infers it for legacy schemas, while reports safely classify missing modes.
The g-computation point-estimate fit now normalizes tiny bootstrap weights.
These later R-only fixes now pass against the rebuilt installed package,
without method substitution.

Before the following batch, the continuation totalled 53 added bulk files. The constrained-Weibull
review exposes unrestricted covariance under fixed parameters in both native
fitting cores. Source now inverts only the free information block and marks
fixed covariance entries NA. Independent mixed/right-censoring references
reproduced 11 covariance failures on the pre-fix binary. The user's latest
rebuild passes all 90 assertions in those two files. Eight verification files
pass together against the installed package, covering native covariance and
the latest weighting/resume/report fixes without source-method substitution.

**Further continuation (2026-09-18):** InferenceSuite method selection/error
contracts add 32 passing assertions; independent Cox tied/stratified risk-set
references add 186; actual custom-noise/heterogeneous-estimand simulation
references add 56. Callback documentation now states the observed 0/1
assignment encoding. Incidence g-computation tests expose another shared
point-estimate tiny-weight convergence defect, with a later R-only weight
normalization fix verified against independent weighted GLM fits for actual
risk-difference and risk-ratio classes (91 assertions). Empty draws also
expose fallback reduction-cache poisoning in incidence and proportion
g-computation; scoped cache restoration lets subsequent valid draws retain
their full covariate model (the proportion file now has 38 assertions).
These later R-only fixes pass through isolated source-method substitution
and are not yet installed.
Constrained Cox cluster covariance also propagates fixed-parameter NA values
into free standard errors. A free-block sandwich correction and enabled
independent regressions reproduce 12 failures on the current native binary;
that later C++ fix requires another user-managed rebuild. The continuation
now totals 58 added bulk files, all registered in both runtime tiers.
A broader 57-file verification batch passes 1845 assertions against the
installed native package with only the latest incidence/proportion R methods
temporarily substituted. The remaining Cox sandwich file intentionally
reproduces 12 native covariance failures until the next rebuild.

The runtime manifest includes every new file in both correctness and coverage
tiers. Correctness estimates use measured local timings with 30% headroom;
coverage estimates remain conservative, unmeasured defaults. Both shard planners
validate. The TODO-4 Bai classes already have migration goldens under their current
names, `InferenceBaiAdjustedTKK14` and `InferenceBaiAdjustedTKK21`; ordinary mixed
quantile CI workflows also already have migration tests. The additions target
missing branches rather than duplicating those goldens. Registry entries remain
`in_progress` until a real coverage measurement confirms movement.

## Investigation summary (2026-08-29)

Before writing this plan, the coverage pipeline itself was audited to rule
out a tooling bug masquerading as a real gap:

- **R and C++ are covered almost identically** (66.3% average over 178 R
  files vs. 64.7% average over 124 `src/` files, unweighted by line count).
  This rules out a systemic gcov/unity-build misattribution problem
  favoring one language over the other -- gcov correctly splits unity
  translation units back into per-original-file `.gcov` output (verified:
  every "suspicious" 0%-covered `.cpp` file has its own `Creating
  'foo.cpp.gcov'` line in the run log, not lumped into a `unity_NN.cpp`
  wrapper). The 64.79% number is real, not an artifact.
- **31 of 302 tracked files sit at literal 0.00%** -- not just low, never
  executed at all during the full test suite (pre-push `testthat/` +
  CI-only `testthat_bulk/` combined). These cluster into three groups (see
  Phase 2 below for the full file list):
  1. Performance-dispatch C++ kernels (`kk_bootstrap_loop.cpp`,
     `base_bootstrap_loop.cpp`, `bisection_ci_loop.cpp`,
     `randomization_loop.cpp`, `ols_distr_parallel.cpp`,
     `ridit_distr_parallel.cpp`, and others) that likely only engage above
     a size/`B`/`r`/`num_cores` threshold the test suite deliberately stays
     under for speed (tests use `B = 9L`/`r = 9L` throughout).
  2. A handful of R classes with seemingly no dedicated test at all
     (`InferenceContinuousKK14Bai`/`KK21Bai`, the quantile randomization CI
     abstract classes).
  3. Diagnostic/build-metadata code (`build_info.cpp`) that nothing calls
     in a test.
- **Beyond the zeros, coverage is broadly thin, not concentrated** -- many
  files sit in the 0.17%-20% range (`inference_incidence_gcomp_abstract.R`
  at 0.17%, `inference_survival_rmst.R` at 3.7%,
  `inference_ordinal_KK_clmm_abstract.R` at 4.6%, etc.), spread across the
  codebase. This is real untested code (error paths, rarer
  response-type/design/inference-class combinations, defensive branches),
  not a bug -- expected for a ~96k-line statistical package with this much
  dispatch/branching logic.

## Goal

Get aggregate line coverage from 64.79% into the high 90s. **Literal 100%
is explicitly not the target** -- see Non-goals below.

## Approach / Phases

### Phase 1: Triage and build a tracked backlog

- **TODO-1.** Regenerate the full per-file coverage list (already captured
  once, 2026-08-28, against commit `d41880c1`) and classify every file
  below some threshold (proposed: <80%) into one of:
  - (a) needs a new, straightforward test -- code just was never exercised;
  - (b) reachable only via a specific dispatch/threshold condition --
    needs a test deliberately written to cross that threshold;
  - (c) genuinely dead/unreachable code -- candidate for removal or a
    documented `covr` exclusion, not a test;
  - (d) diagnostic/introspection-only code -- needs only a trivial smoke
    test.
- **TODO-2.** Produce a tracked artifact,
  `R/package_tests/coverage_gap_registry.csv`, mapping
  `file -> category -> owning TODO -> status`, mirroring this repo's
  existing registry pattern (`comprehensive_suite_registry.csv`,
  `comprehensive_suite_baseline_audit.csv`, etc.) so progress is
  measurable file-by-file, not only via the one aggregate percentage.
  Regenerate it the same way those other registries are regenerated
  (a `package_tests/*.R` script reading the covr output), so it can be
  drift-checked in CI the same way, rather than hand-maintained and going
  stale.


  **TODO-2 progress (2026-09-16):** The generator now tallies unique source
  lines with `covr::tally_coverage(..., by = "line")`, handles omitted CLI
  arguments and empty reports, reads bare covr objects and CI report wrappers,
  refreshes `measured_commit`/`measured_at`, and preserves baseline provenance
  and manual triage. Tracked files reaching the threshold remain `addressed`;
  a later regression reopens them as `pending`. Files absent from a measurement
  retain their previous numbers and provenance. `excluded` remains a manual
  decision. A new report's measured commit never inherits the previous commit;
  it stays blank if the input provides no commit and no override is supplied.

  Usage from the repository root (report processing does not compile):
  `Rscript R/package_tests/coverage_gap_registry.R <report.rds|report.csv> [output.csv] [threshold=80] [measured_commit] [measured_at]`.
  For CSV, provide either `filename,line,value` line rows or covr's expression
  source-span columns. Bare reports/CSVs default to the processing time in UTC;
  supply the actual measurement time and commit explicitly when known.

  The scheduled coverage workflow regenerates a candidate CSV from all merged
  shards, compares backlog fields against the tracked CSV (excluding changing
  measurement provenance), warns on drift in the job summary, and uploads the
  candidate plus `coverage-registry-drift.txt` as the `coverage-registry`
  artifact. It does not automatically commit measurements. Standalone
  regression checks run in CI and locally with
  `Rscript R/package_tests/ci/test_coverage_gap_registry.R`.

  **Still pending:** replace the 31 historical seed rows with the full backlog
  from a complete, provenance-bearing coverage run, including measured line
  counts and all files below 80%, then review the new files' categories/owners
  (TODO-1). The available local full report has no measured-commit provenance;
  the corrected local report inspected is only one shard. Neither establishes
  a verified full refresh. TODO-2 remains in progress until that candidate is
  reviewed and committed.

### Phase 2: Zero-coverage files (highest ROI -- 31 whole files)

- **TODO-3.** Performance-dispatch C++ kernels. Full list from the
  2026-08-29 investigation: `kk_bootstrap_loop.cpp`,
  `base_bootstrap_loop.cpp`, `bisection_ci_loop.cpp`, `bisection_ci.cpp`,
  `randomization_loop.cpp`, `ols_distr_parallel.cpp`,
  `ridit_distr_parallel.cpp`, `fast_kk_wilcox_parallel.cpp`,
  `fast_wilcox_parallel.cpp`, `KK_bootstrap_helper_fillin.cpp`,
  `kk_bootstrap_reservoir_stats.cpp`, `kk_lin_match_data.cpp`,
  `kk21_stepwise_survival.cpp`, `random_block_size_speedups.cpp`,
  `which_cols_vary.cpp`, `match_data_compute_speedup.cpp`,
  `build_kk_combined_ols_design.cpp`, `log_lik_nb.cpp`,
  `fast_jonckheere_terpstra.cpp`, `fast_ordinal_clmm.cpp`,
  `fast_scale_cols.cpp`, `fast_shuffle.cpp`, `fast_math_utils.cpp`,
  `beta_regression_helpers.cpp`, `_glmm_links.h`,
  `zero_one_logit_transform.h`. For each: find the actual dispatch
  condition gating it (grep its call site(s) for the size/count check),
  then add at least one dedicated test in
  `R/package_tests/testthat_bulk/` (CI-only, per the existing fast/pre-push
  vs. slow/bulk split -- these are deliberately expensive paths, don't pull
  them into the always-run pre-push suite) that crosses that threshold and
  asserts a real result (not just "didn't error").
- **TODO-4.** Confirm whether `InferenceContinuousKK14Bai`,
  `InferenceContinuousKK21Bai`, `InferenceExtQuantileRandCI`, and the
  quantile-rand-CI abstract base genuinely have no test anywhere (they may
  and this run simply didn't reach them for an unrelated reason -- verify
  before writing anything new). If genuinely untested, write focused tests
  against each class's public contract, following the existing
  migration-golden/focused-test pattern used for sibling classes.
- **TODO-5.** `build_info.cpp` / `edi_build_info_cpp()`: add a one-line
  smoke test asserting the accessor returns a well-formed list. Check the
  public API inventory first to confirm the current exported wrapper name.

### Phase 3: The broadly-thin long tail

- **TODO-6.** Sort the Phase 1 registry by **weighted opportunity**
  (`(1 - coverage) * lines_of_code`), not raw percentage, so effort goes
  toward files where a new test recovers the most absolute lines first,
  not just whichever file has the lowest %.
- **TODO-7.** For each low-coverage file, distinguish two different root
  causes before choosing a fix: (i) the code path already runs under an
  existing comprehensive-suite/argument-combination fixture, but the
  specific branch covr flags isn't the one that fixture's assertions
  target -- fix is to broaden that existing test's inputs/assertions; vs.
  (ii) the code path is never invoked by anything -- fix is a wholly new
  test. Conflating these wastes effort (broadening a test that never
  reaches the branch at all does nothing; writing a whole new test for
  something an existing fixture already exercises duplicates coverage
  without closing the gap it looked like it would).
- **TODO-8.** For genuinely-defensive/impossible-state `stop()`/assertion
  branches (the kind CLAUDE.md's own guardrail-pattern documents
  elsewhere in this codebase), decide case by case: (a) write a test that
  reaches the branch via a deliberately malformed internal state (via
  `.__enclos_env__$private` manipulation, matching patterns already used
  in this test suite), or (b) mark it excluded via `covr`'s
  `line_exclusions`/`function_exclusions` (would need adding that
  parameter to the `covr::codecov()` call in `test-coverage-R.yaml`, not
  currently passed). Every exclusion needs an inline comment stating why
  it's excluded, matching this repo's comment-density convention -- an
  unexplained exclusion is indistinguishable from someone hiding a real
  gap.

### Phase 4: Guardrails against regression

- **TODO-9.** Add a coverage floor check to `test-coverage-R.yaml`: fail
  (or at minimum loudly warn in the job summary) if aggregate coverage
  drops below the best figure achieved so far, not just report the number
  and move on. Needs a decision on hard-gate-vs-advisory, consistent with
  this repo's existing tiered quality-gate philosophy elsewhere
  (`comprehensive_suite_quality_gates.csv`'s hard/soft split).

  **TODO-9 done (2026-09-18):** hard gate, both languages. New
  `R/package_tests/ci/coverage_baseline.json` (seeded from this doc's
  64.79% figure) plus `check_coverage_floor.R`/`.py`, wired into
  `test-coverage-R.yaml`'s `merge` job and `test-coverage-python.yml` —
  either fails the job outright on a regression vs. the recorded best-ever
  percentage. A new high prints instructions rather than auto-committing
  (mirrors `check_coverage_registry.R`'s existing measure-then-human-commits
  pattern). The Python half also runs from `.githooks/pre-push` (pytest-cov
  is cheap; R stays CI-only since covr needs an instrumented rebuild). See
  `R/package_tests/ci/README.md`'s "Coverage floor" section and
  `CONTRIBUTING.md` §4.8. No GitHub branch protection changes were bundled
  into this TODO; that was handled as a separate decision.
- **TODO-10.** Once Phases 2-3's backlog is substantially cleared, re-run
  the same 0%/low-% triage once more before declaring this plan done --
  this is an actively-developed codebase and new files/functions land
  continuously; confirm nothing new crept in unaddressed while this plan
  was being executed.

## Testing/verification plan

- Track the aggregate percentage after each phase via the real
  `test-coverage-R.yaml` run (or a local `covr::package_coverage()` dry
  run against the same `code=` invocation) rather than estimating.
- `coverage_gap_registry.csv` (TODO-2) is the source of truth for "is this
  file done" -- a file counts as addressed only when its fix has landed
  **and** its coverage number visibly moved in a real run, not just when
  a test was written that looked like it should help.

## Non-goals

- **Literal 100% is not the target.** Some code -- a `stop()` guarding an
  R6 private invariant no public code path can ever violate, for instance
  -- is legitimately excluded rather than artificially tested via
  reflection hacks that don't reflect any real usage. The realistic target
  is: every file has a *deliberate, documented* reason for whatever
  coverage percentage it sits at, either "well-tested" or "excluded with a
  stated reason" -- never "nobody got around to it, and nobody knows why
  either."
- This plan does not change any source behavior. Every TODO here is
  test-writing, triage, or CI-plumbing (the coverage floor gate) --
  if a gap investigation surfaces what looks like an actual bug (dead
  code that should be reachable but isn't due to a real logic error,
  not just "nobody wrote the test yet"), that becomes its own separate
  plan/fix, not folded into this one.
