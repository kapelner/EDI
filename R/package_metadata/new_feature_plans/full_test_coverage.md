# Full Test Coverage: 65% → Near 100%

> **Depends on:** none directly -- builds on the already-fixed
> `test-coverage-R.yaml` pipeline (the `stop_on_failure = FALSE` fix so a
> single bulk-suite failure no longer blocks the Codecov upload entirely,
> and folding `R/package_tests/testthat_bulk/` into the `code=` coverage
> pass, both 2026-08-28). Independent of any other open plan; this is pure
> test-writing/triage work, not a source-behavior change. Slated for
> **v1.1.0** (user decision, 2026-08-29) -- `release_v1_1_0.md` should pick
> this up as an additional TODO; not yet cross-referenced there as of this
> writing.

## Status

**Current coverage: 64.79%** (run against commit `d41880c1`, 2026-08-28 --
the first successful upload after the pipeline fixes above). Not yet
started: this plan is triage + a phased backlog, no implementation has
landed yet.

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
