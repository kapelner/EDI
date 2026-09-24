# Fix plan: `comprehensive_tests`' Monte-Carlo coverage-truth uses the wrong covariate set

Found 2026-09-22, via a raw `comprehensive_tests` results-CSV audit's `low_coverage`
check (`audit_comprehensive_results.R`), not a user report. Slated for v1.0.5
(`release_v1_0_5.md → TODO-10`, moved 2026-09-23 from
`release_v1_1_0.md → TODO-32`, bug-fix/feature split).

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

## Status (2026-09-23)

TODO-1 and TODO-2/3 are done. TODO-4/5 are not: they require an actual
`comprehensive_tests` re-run, which this session did not do (see below).

**TODO-1 (sweep, done; revised 2026-09-24).** Coverage at `beta_T = 0` vs.
`beta_T != 0` was compared for all 25 `COVERAGE_MC_SPEC` classes from the
existing raw result CSVs (no simulation needed). Pooling across datasets,
13 classes confirm the "clean at 0, collapses at non-zero, uniform across
CI methods" signature: `OrdinalKKCLMMCauchit`, `OrdinalKKGLMM`,
`OrdinalRidit`, `PropBetaRegr`, `PropFractionalLogit`, `PropKKGEE`,
`PropKKQuantileRegrOneLik`, `PropZeroOneInflatedBetaRegr`,
`SurvivalGehanWilcox`, `SurvivalKKLWACoxPHOneLik`,
`SurvivalKKStratCoxPHOneLik`, `SurvivalLogRank`, `SurvivalStratCoxPHRegr`.

**A pooled check can hide a per-dataset signature.** Re-checked the
remaining 12 by `(class, dataset)` rather than pooled: `PropQuantileRegr`
looked clean pooled (0.84 coverage at `beta_T != 0`, just above the 0.85
cutoff) but splits sharply by dataset -- `diamonds` alone is 0.93 at
`beta_T=0` vs. **0.40** at `beta_T=0.5` (n=744), while every other dataset
(`abalone`, `boston`, `ionosphere`, `pte_example`) covers 0.89-0.98. That is
the same signature, just diluted by averaging across datasets that happen
to be fine. Added to the confirmed list -- **14 classes total**, all now
covered by `stale_ok_row_rules.csv`. The other 11 (including plain
`SurvivalCoxPHRegr`/`SurvivalWeibullRegr`) were re-checked the same
per-dataset way and genuinely don't show it in any dataset slice -- their
truth is apparently close enough in practice that the mismatch doesn't
manifest as a coverage failure, even though the same code path is in
principle exposed to it.

**TODO-2 (decision).** Option 1 (match the real adjustment set), narrowed:
the per-row label already distinguishes `(model_formula=~1)` /
`[design_formula=~1]` (no adjustment -- keep the old synthetic-covariate
behavior, which was already correct for this case) from everything else,
including a bare label with no suffix (fixed-formula classes always fit
`~.` by `run_tests_for_response()`'s own default). So the fix only needs a
binary `use_real_covariates` flag per row label, not a full
formula-parametrized cache.

**TODO-3 (implementation, done).** `comprehensive_tests.R`:
- `get_coverage_truth()` derives `use_real_covariates` from the label
  (`!grepl("~1[\\)\\]]", inference_class)`) and folds it into
  `.coverage_truth_cache`'s key.
- `compute_mc_coverage_truth_simframe()` takes a new `real_X = NULL` arg;
  when supplied, its rows are recycled to `mc_n` exactly like `y_base`
  already is, `p` is set to `ncol(real_X)`, and it's passed instead of a
  synthetic `data.frame(x1 = rnorm(n))`.
- Verified directly (installed EDI bypassed a concurrently-edited dev
  source tree; re-verified against dev source once it stabilized):
  `InferenceSurvivalWeibullRegr` (a class that did NOT show the mismatch
  signature) is unaffected by the fix (old 0.507 vs. new 0.499, both near
  the true 0.5). `InferenceSurvivalKKStratCoxPHOneLik` (a confirmed
  mismatch class) changes substantially: old (synthetic covariate) truth
  -0.92 -- matching the -0.96 median already recorded in the CSVs -- vs.
  new (real, 24-covariate `diamonds` adjustment) truth -6.3, stable across
  3 seeds (-6.32, -5.91, -6.28; ~4 minutes per MC fit at `mc_n = 3000`).

**Follow-up finding, not yet resolved.** The new truth's large magnitude
is real and reproducible, not noise -- but it raises a question this plan
didn't originally anticipate: is a `~.` adjustment for all 24 of
`diamonds`' real covariates, on a 1:1-matched Cox design with a modest
per-stratum sample, even a well-posed test scenario? A log-HR this large
under that many covariates is consistent with known small-sample/
near-separation instability in high-dimensional matched Cox regression,
which would also explain why the CLASS's own individual per-row estimates
(not just the truth) are highly variable -- i.e. this fix may correct the
reference value while leaving a second, harder question open: whether the
harness should even be running `~.`-over-24-covariates as a coverage test
for KK-matched Cox classes, or whether that scenario needs its own
decision (e.g. a covariate cap, matching `KK21stepwise`'s existing
20-column truncation for a different reason -- see `X_design_sequential_strata`
in `run_tests_for_response()`).

## TODO-6 investigated (2026-09-23): the real-covariate MC truth does not converge

Before trusting the TODO-3 fix's numbers for `KKStratCoxPHOneLik`/`diamonds`,
compared the MC truth against the REAL per-row estimate distribution at
`n=148` (`beta_T=0.5`, both designs): estimates cluster tightly around
**-1.7 to -2.5** (SD 0.5-0.6, min/max -3.67/-0.86 across 150 rows) -- nowhere
near the -6.0-ish MC truth. A true large-n limit that far outside the
empirical distribution of a consistent estimator (6-9 SDs) is not plausible
on its face.

Also found: **the MC truth is not even self-consistent across resampling
schemes.** The TODO-3 implementation recycles the real 148-row `X` block
deterministically (`rep(seq_len(n0), k)`, matching the existing `y_base`
recycling pattern) to reach `mc_n`. Re-running with the real rows instead
drawn **with replacement** (bootstrap, paired `X`/`y` by row index) gives
-4.5 to -4.65 (stable across 2 seeds) -- a materially different number from
the block-cycled -5.9 to -6.3, not just sampling noise. Two different valid
large-`n` constructions of "the same" MC truth disagree by ~18%, which means
neither has actually converged to a fixed point; "stable across seeds
within one scheme" was necessary but not sufficient evidence of
correctness.

**Most likely explanation:** this isn't a convergence-rate problem fixable
by raising `mc_n` further. `KKStratCoxPHOneLik`/`diamonds` fits 24
covariates + treatment via matched-pair/stratified Cox partial likelihood
against ~74 matched pairs at the real `n=148` -- a small-pairs/many-covariates
ratio known to produce severe finite-sample attenuation bias toward zero in
conditional/partial likelihood models (the "incidental parameters" family
of problems; see also `release_v1_1_0.md`'s own already-planned "Firth"
bias-correction item). Under that explanation, the *true* large-sample
parameter genuinely is far from what `n=148` estimates show, so the
n=148 rows' empirical distribution is not (as I assumed one level up) a
safe sanity check on the truth either -- it's evidence of severe bias, not
evidence the truth is wrong. But since the MC estimate itself hasn't
converged/agreed across resampling schemes, this plan cannot currently
distinguish "the truth is ~-4.5 to -6 and n=148 estimates are badly biased"
from "the whole `~.`-over-24-covariates-on-a-matched-design MC construction
is somehow ill-posed" without more work than is in scope here.

**Recommendation (not decided, not implemented):** do not ship TODO-3's fix
for `KKStratCoxPHOneLik`-family (KK-matched, high-covariate-count) classes
until one of:
1. A proper convergence check across resampling schemes AND increasing
   `mc_n` confirms the truth actually stabilizes to one value (would
   settle whether -4.5, -6, or something else is right); or
2. A covariate cap is applied for these specific classes -- both to the MC
   truth AND the real per-row `~.` test generation -- small enough that the
   pairs-to-covariates ratio is safely large (e.g. 5-8 covariates against
   ~74 pairs, versus 24 today), sidestepping the attenuation-bias regime
   entirely rather than trying to characterize it. This mirrors
   `KK21stepwise`'s existing covariate truncation in
   `run_tests_for_response()` (`X_design = X_design[, seq_len(20L), ...]`),
   though that one is for runtime, not statistical, reasons -- a fresh cap
   for a fresh (statistical) reason, not reuse of the same one; or
3. Firth-type bias correction lands for these classes first (already
   separately planned in this release's scope per `../new_feature_plans/_master.md`'s theme
   list), which would make the finite-sample estimates themselves less
   biased and the coverage question meaningful again without touching the
   harness's covariate-adjustment set at all.

For the 12 other confirmed classes (fewer/no covariates involved, or not
matched-pair-structured), this convergence problem was not observed
(`InferenceSurvivalWeibullRegr`'s Bernoulli-design check above converged to
~0.5 as expected) and TODO-3's fix should be trustworthy as implemented --
this caveat is specific to the KK-matched + many-real-covariates
combination, not to the fix's general approach.

## TODO (remaining)

4. Re-run `comprehensive_tests` for the confirmed classes and confirm
   coverage returns to nominal at `beta_T != 0`. **Split by TODO-6's
   finding:** the 13 non-KK-matched/high-`p` classes (e.g.
   `PropBetaRegr`, `PropQuantileRegr`, `SurvivalLogRank`,
   `SurvivalGehanWilcox`, `SurvivalStratCoxPHRegr`, ordinal
   `KKGLMM`/`KKCLMMCauchit`/`Ridit`, proportion
   `KKGEE`/`KKQuantileRegrOneLik`/`ZeroOneInflatedBetaRegr`)
   can proceed now -- the fix is trustworthy for them (their raw-CSV rows
   are already pruned, see `stale_ok_row_rules.csv`; only running the
   harness remains). `KKStratCoxPHOneLik`
   and `KKLWACoxPHOneLik` (KK-matched, many real covariates) must wait on
   TODO-6's own resolution (item 6 below) first, or they'll re-record a
   truth that hasn't actually been shown to be correct. **Cost note:** the
   real-covariate MC fit is far more expensive than the old synthetic one
   -- minutes, not under a second, per (class, dataset, beta_T) cell on a
   many-covariate dataset. Across datasets/beta_T values this could be a
   multi-hour run; needs an explicit go-ahead given it touches the shared
   result CSVs other sessions/CI also read.
5. Re-audit and prune `comprehensive_results_audit_baseline.csv` /
   `stale_ok_row_rules.csv` for findings TODO-4 closes.
6. Resolve the KK-matched/high-covariate-count open question (see "TODO-6
   investigated" above): confirm convergence across resampling schemes and
   `mc_n`, apply a covariate cap, or wait on Firth-type bias correction --
   pick one, with maintainer sign-off, before including
   `KKStratCoxPHOneLik`/`KKLWACoxPHOneLik` in TODO-4's re-run.

7. **New class found 2026-09-24**, via this session's new `biased_estimate`
   audit check (independently corroborated by a separate survival-class
   coverage investigation the same day): `InferenceSurvivalKMDiff` shows
   large apparent bias (`compute_estimate` +0.39, `compute_jackknife_estimate`
   +0.57 — both large relative to RMSE, a real systematic shift not
   outlier noise) that traces to the SAME mismatch this plan already
   documents for other classes, not a new estimator bug. Confirmed
   directly: at `beta_T=0` (true null) the estimator itself is essentially
   unbiased (mean estimate −0.016); the "bias" only appears when compared
   against `coverage_truth`, which is confirmed identical to raw `beta_T`
   for 100% of rows (`beta_T` ranges `[0, 0.5]` while raw `compute_estimate`
   values range up to 2.64 — a scale mismatch, KM-difference being a
   non-collapsible survival-probability-scale quantity being compared
   against a hazard-ratio-scale `beta_T` with no MC adjustment at all).
   Add `InferenceSurvivalKMDiff` to this plan's affected-class list and
   scope it into TODO-4/5 above the same way the other listed classes are
   handled.

Independent of every other 1.1.0 item; depends on nothing else in this
release.
