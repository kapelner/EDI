# Fix plan: `comprehensive_tests`' Monte-Carlo coverage-truth uses the wrong covariate set

Found 2026-09-22, via a raw `comprehensive_tests` results-CSV audit's `low_coverage`
check (`audit_comprehensive_results.R`), not a user report. Slated for v1.1.0
(`release_v1_1_0.md → TODO-32`).

## Symptom

`InferenceSurvivalKKStratCoxPHOneLik` covers its own coverage-truth target
correctly at `beta_T = 0` (0.93-1.00 across every one of its ~14 CI methods)
but collapses at `beta_T = 0.5` (0.04-0.65 across the same methods, all at
once). The coverage-truth value the harness computed for `beta_T = 0.5` is
**negative** (median -0.96 to -1.62 across designs/methods) despite the
generating shift being positive -- every CI method is being graded against a
target of the wrong sign/magnitude, not failing independently. (The sign
itself is not the bug: a positive multiplicative *time* shift under this
class's Cox proportional-hazards model legitimately corresponds to a negative
log-hazard-ratio, since living longer means lower hazard. The bug is that the
magnitude the harness computed doesn't match what the class's own estimator
converges to on the actual per-row data.)

## Root cause

`get_coverage_truth()` (comprehensive_tests.R:3287) dispatches non-collapsible
link-scale classes (Cox, logit/probit, GLMM/GEE -- everything in
`COVERAGE_MC_SPEC`, ~25 classes) to `compute_mc_coverage_truth_simframe()`,
which fits the class's own estimator once at large `n` and uses the fitted
coefficient as the "least false"/KL-projection truth a correctly-calibrated CI
should cover.

That MC fit's `custom_data` generator (comprehensive_tests.R:3210) builds
`X = data.frame(x1 = rnorm(n))` -- **one synthetic Gaussian covariate** -- and
lets the class's default formula (`~.`) fit against it. But the actual
per-row results being coverage-checked are generated with `design_formula =
~.` (comprehensive_tests.R:3585) over the **real dataset's full covariate
matrix** (e.g. diamonds' several real columns), reported in the `dataset`
column of the results CSV.

For a non-collapsible marginal/conditional coefficient, the adjustment set
changes what "the" coefficient even is (omitted-variable attenuation, or for
Cox specifically, non-collapsibility of the hazard ratio itself under
covariate adjustment). So the MC truth (one synthetic covariate) and the
real per-row truth (many real covariates) are for two different fitted
models, not two draws from the same one. At `beta_T = 0` this doesn't matter
-- with no true effect, every reasonable adjustment set's expected
coefficient is ~0 -- so coverage there is unaffected and clean, which is
exactly the pattern observed (this is why the bug was invisible until a
non-null `beta_T` was checked). This is the harness-side counterpart of the
`InferenceAllSimpleMeanDiffPooledVar` truth-scale bug found 2026-09-06
(comprehensive_tests.R:3290's comment) -- another case where a coverage
target used the wrong scale/model for a subset of `beta_T` values, not the
CI code.

## Suspected scope

Every class in `COVERAGE_MC_SPEC` is exposed to this same mismatch whenever
its per-row test uses `design_formula = ~.` over a real multi-column
dataset, which is the harness's default. Directly confirmed on
`InferenceSurvivalKKStratCoxPHOneLik`. The audit's low-coverage findings for
other MC-truth classes with the "fine at beta_T=0, bad at 0.5 across every
method at once" signature are consistent with the same cause (not yet
individually confirmed): most of the ~93 previously-unexplained
`survival`/`ordinal`/`incidence`/`proportion` low-coverage baseline entries
match this shape.

## Options (not decided)

1. **Match the adjustment set exactly per row.** Have
   `compute_mc_coverage_truth_simframe()` take the real dataset's covariate
   matrix (already loaded as `datasets_and_response_models[[dataset_name]]$X`)
   instead of a synthetic `x1`, and cache the MC-fitted truth per
   `(class, dataset, design_formula, beta_T)` instead of per `(class,
   dataset, beta_T)` alone. Correct, but multiplies the number of expensive
   MC fits by the number of distinct `design_formula`/covariate-subset
   combinations actually exercised (currently the cache key is
   `paste(base_class, dataset_name, beta_T_val)` -- see
   `.coverage_truth_cache`, comprehensive_tests.R:3306).
2. **Restrict per-row coverage checking for these classes to `~.` only** (if
   the harness already mostly uses one formula per class) and just widen
   `custom_data` to use the real `X`, without a cache-key change, if `~1`
   variants are rare/skippable for these specific classes.
3. **Give up on point-truth coverage for non-collapsible classes** and check
   a coarser invariant instead (e.g. CI contains the class's own MC-fitted
   `beta_T=0` truth at `beta_T=0`, and monotonic CI-location movement with
   `beta_T`, without claiming a numeric coverage rate at `beta_T != 0`).
   Cheaper, but throws away real coverage information the harness currently
   almost has.

## TODO

1. Exhaustive sweep: for every class in `COVERAGE_MC_SPEC`, compare
   `low_coverage` findings at `beta_T = 0` vs. `beta_T != 0`; classes
   matching the "clean at 0, bad at non-zero, uniform across CI methods"
   signature confirm the same root cause rather than an independent CI bug.
2. Decide among the options above (likely (1), scoped to the
   `design_formula` values actually used per class, to bound the added MC
   cost).
3. Implement the chosen fix in `compute_mc_coverage_truth_simframe()` /
   `get_coverage_truth()` / `.coverage_truth_cache`.
4. Re-run `comprehensive_tests` for the affected classes and confirm
   coverage returns to nominal at `beta_T != 0`.
5. Re-audit and prune `comprehensive_results_audit_baseline.csv` /
   `stale_ok_row_rules.csv` for findings this closes.

Independent of every other 1.1.0 item; depends on nothing else in this
release.
