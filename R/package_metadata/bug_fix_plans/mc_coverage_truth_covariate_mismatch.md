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

8. **New class found 2026-09-24**, via a follow-up fork closing out
   `investigate_incid_logregr_probitregr_coverage.md`'s `low_coverage`
   cluster: `InferenceIncidLogRegr`'s closed-form truth
   (`compute_incid_logit_coverage_truth()`, `comprehensive_tests.R:3207`)
   computes the **marginal** log-odds-ratio contrast
   (`qlogis(mean(p_t)) - qlogis(mean(p_c))`), while `compute_estimate()`
   defaults to `estimand = "conditional"`
   (`inference_incidence_logit.R:429`) and `comprehensive_tests.R` never
   calls `set_estimand()` for this class (confirmed via grep — zero
   hits). This is a genuine truth/estimand scale mismatch, same shape as
   this plan's other entries — **but confirmed NOT to be the primary
   driver of the class's actual audit findings**: `InferenceIncidProbitRegr`
   (MC-refit truth, immune to this specific closed-form mismatch) shows
   the identical broad over-coverage pattern, so the dominant symptom is
   separately explained as benign finite-sample GLM-CI conservativeness
   (closed as not-a-bug in the linked investigation file). This entry is
   tracked here purely as a **harness truth-definition accuracy issue**
   worth fixing independently of any symptom it does or doesn't explain —
   either make `compute_incid_logit_coverage_truth()` compute the
   conditional log-odds truth to match the estimator's actual default
   estimand, or have the harness call `set_estimand("marginal_mean_diff")`
   explicitly so the estimate and truth are provably on the same scale by
   construction. Low priority relative to this plan's other items, since
   it isn't gating any currently-open coverage finding.

## Cross-validation, 2026-09-24: fresh full-package audit confirms this plan already explains the new findings

A fresh `low_coverage` audit run surfaced new findings for
`InferenceSurvivalKKStratCoxPHOneLik` (5), `InferenceSurvivalKKLWACoxPHOneLik`
(3), and `InferenceSurvivalKMDiff` (8) — all three already on this plan's
confirmed-affected-class list (TODO-1's 14-class sweep for the first two;
TODO-7 for KMDiff). Checked each against this plan's own numbers:
`KKStratCoxPHOneLik`'s new findings (`bayesian_bootstrap`/`_basic`
0.81-0.87, `bootstrap_basic` 0.90, `m_out_of_n_bootstrap` 0.88,
`subsampling` 0.86) land inside the ranges `survival_kk_cox_coverage_variance.md`
already documented for this class. `KKLWACoxPHOneLik`'s new findings
(`bayesian_bootstrap_basic` 0.87, `param_bootstrap` 0.79,
`rand_bootstrap_smoothed` 0.80) likewise match that same plan's numbers
closely. `KMDiff`'s 8 new findings (all bootstrap/jackknife-family, under
0.77-0.89) are consistent with this plan's TODO-7 truth-scale-mismatch
finding. **No new information from any of these three — pure
confirmation, still blocked on the same open items (TODO-4/5/6 above).**

## TODO-10 (added 2026-09-24, high confidence for the mechanism, fix not implemented): 3 more classes with the same missing-MC-truth pattern as Ridit

A follow-up fork investigating `ordinal_cumulative_link_null_refit_multistart.md`'s
TODO-13 (a suspected shared package-level SE bug across 4 ordinal
cumulative-link classes) found the real mechanism is a **harness gap**,
not a package bug — the exact same shape as `InferenceOrdinalRidit`'s
already-fixed truth mismatch (see this file's registry-comment precedent
in `comprehensive_tests.R`, "found 2026-09-06"). None of
`InferenceOrdinalCauchitRegr`, `InferenceOrdinalAdjCatLogitRegr`,
`InferenceOrdinalContRatioRegr` appear in `COVERAGE_CLOSED_FORM`/
`COVERAGE_MC_SPEC`, so all fall back to raw `beta_T` — but the harness's
ordinal DGP generates data under a cumulative-**logit** (proportional-
odds) shift model, and all 3 of these classes fit a **different, genuinely
misspecified link/model family**: Cauchit uses `pcauchy`; adjacent-
category logit and continuation-ratio are documented (package's own
`inference_ordinal_stereotype_logit.R:463`) as distinct ordinal families
from proportional-odds/cumulative-logit despite naming similarity. Under
model misspecification the MLE targets a KL-divergence-minimizing
pseudo-true value, not `beta_T` — confirmed by direct code reading, not
just analogy to Ridit. Design-pooling was independently ruled out first
via direct empirical stratification (Bernoulli coverage 0.832 ≈
non-Bernoulli pooled average 0.820), eliminating the alternative
hypothesis before landing on this one.

**`InferenceOrdinalPartialProportionalOddsRegr` was initially thought NOT
covered by this fix** (uses `VGAM::cumulative(link = "logitlink", ...)`,
same link as the DGP, correctly nests the true model) — **correction,
2026-09-24: it IS a 4th instance of this same class of harness gap, via a
different specific mechanism.** `TODO-18` (in the linked ordinal plan)
resolved this: `comprehensive_tests.R` never passes `nonparallel` to this
class, so it always fits via the plain full-proportional-odds fast path
(same kernel as `InferenceOrdinalPropOddsRegr`), ruling out a VGAM/partial-
model-specific bug. `beta_T`-stratified querying (not pooled) showed
coverage is nominal (~0.95) in every cell EXCEPT `(model_formula=~.,
beta_T=0.5)`, where it collapses to **0.283** — the textbook signature of
**non-collapsibility**: a correctly-specified cumulative-logit treatment
coefficient under covariate adjustment is NOT equal to the raw DGP
parameter used to generate the data, except when that parameter is 0
(invariant to conditioning) or there are no covariates to condition on.
Same fix category as the other 3 (MC-refit truth), just needed at
nonzero `beta_T` specifically rather than for the whole class uniformly.

**Fix**: add `InferenceOrdinalCauchitRegr`/`InferenceOrdinalAdjCatLogitRegr`/
`InferenceOrdinalContRatioRegr`/`InferenceOrdinalPartialProportionalOddsRegr`
(4 classes total) to `COVERAGE_MC_SPEC` in `comprehensive_tests.R`,
mirroring the existing `InferenceOrdinalRidit` entry (MC-refit truth via
simulation under the class's own fitted model, not the raw DGP
parameter). Test-harness-only change; does not touch `R/EDI` source. Not
yet implemented — this is a real, confirmed, low-risk fix but was out of
scope for the investigating fork to also apply.

## TODO-11 (added 2026-09-25, investigated at user request from the live TODO-4 re-run's first partial results): `PropBetaRegr`/`PropFractionalLogit` residual under-coverage on `ionosphere` is NOT TODO-6's mechanism -- a distinct, likely real, small-sample CI-calibration gap

The TODO-4 re-run's first batch (proportion only so far, `ionosphere`
dataset only so far, `n=128-177` at `beta_T=0.5`) showed `PropBetaRegr` at
0.84 and `PropFractionalLogit` at 0.85 coverage (nominal 0.95) -- much
better than the pre-fix near-collapse, but not yet at nominal, and
`ionosphere` (33 real covariates after the design matrix expansion, more
than `diamonds`' 24) was an obvious candidate for TODO-6's "many real
covariates -> MC truth doesn't converge" mechanism recurring here.

**Checked directly, same method as TODO-6's Cox investigation.** Re-ran
`compute_mc_coverage_truth_simframe()` for `PropBetaRegr`/`ionosphere`
under both the block-recycled (TODO-3's implementation) and
bootstrap-resampled (TODO-6's alternative) constructions:

| construction | truth |
|---|---|
| synthetic single covariate (old, pre-TODO-3) | 0.333 |
| real covariates, block-recycled, seed 5 | 0.403 |
| real covariates, block-recycled, seed 11 | 0.370 |
| real covariates, bootstrap, seed 5 | 0.425 |
| real covariates, bootstrap, seed 11 | 0.374 |

Unlike Cox (`-6.0` vs. `-4.5`, an 18% disagreement on a value the real
n=148 estimator never got within several SDs of), these four real-covariate
values cluster in a modest 0.37-0.43 range, and the REAL per-row estimates
at `n=148`/`ionosphere`/`beta_T=0.5` (33 reps so far) have mean 0.411,
median 0.407, SD 0.143 -- **every one of the four MC-truth draws falls
within about half an SD of the real estimator's own mean.** This construction
has converged to something consistent with the actual estimator, in sharp
contrast to TODO-6. **TODO-3's fix is doing its job correctly here.**

**So why is coverage still ~0.79-0.88, not ~0.95?** Breaking down the
current (partial, `ionosphere`-only) data by `function_run`: `asymp`,
`wald`, `lik_ratio`, and `subsampling` all land at the *same* ~0.79-0.81
(uniform across 4 independently-derived CI constructions -- not one
method's quirk), while `jackknife_wald` and `lik_ratio_bootstrap` *over*-cover
at 1.00. That pattern -- several asymptotic/model-based methods sharing one
systematically-low coverage number, resampling-based methods over-covering
-- is the signature of an asymptotic standard error that is too small
(anti-conservative) at this `n`/covariate-count ratio (`ionosphere`: 33
covariates, `n=148`, ~4.5 observations per parameter), not a wrong
reference value. This is a plausible, known statistical phenomenon (model-based
SEs under-stating uncertainty as `p/n` grows) rather than a harness truth
bug -- but it has NOT been confirmed as such; it is a hypothesis consistent
with the evidence available so far, not a proven root cause. Also
`FixedMatchingGreedy` (0.77) is notably lower than `Bernoulli` (0.88) within
this same `ionosphere` slice -- consistent with matching adding its own
extra variance/bias on top, but again only one dataset's worth of data.

**Status: open, not a TODO-6 duplicate, not yet resolved.** Only one of
several datasets has produced `beta_T != 0` rows so far in the live
re-run (`survival`, `ordinal`, and 3 of the 9 proportion classes had zero
alt-beta rows at the time of this check); `PropZeroOneInflatedBetaRegr`, by
contrast, already covers at 0.94 on the same `ionosphere` slice, so this is
not a blanket harness problem, it is specific to at least
`PropBetaRegr`/`PropFractionalLogit`.

**TODO:**
1. Wait for the re-run to produce more datasets (lower covariate counts,
   e.g. `pima`/`boston`) for these two classes and re-check whether the
   ~0.80 asymptotic-method coverage is `ionosphere`-specific (supporting
   the high-`p/n` hypothesis) or appears everywhere (which would instead
   point back toward a shared truth/SE bug, reopening this).
2. If it is `ionosphere`-specific and reproducible: this becomes either (a)
   an accepted, documented small-sample limitation of `PropBetaRegr`/
   `PropFractionalLogit`'s asymptotic CIs at high `p/n` (no fix needed, just
   an honest baseline-accepted finding), or (b) grounds to investigate
   `fast_beta_regression`/`fast_fractional_logit`'s SE formula for a
   known finite-sample correction (e.g. a sandwich/bias-corrected variance)
   -- a package-code question, not a harness one, if pursued.
3. Do not conflate with TODO-6: that item is about MC-truth
   non-convergence for KK-matched Cox classes specifically; this item is
   about real-estimator CI under-coverage at high covariate counts on a
   *converged*, trustworthy truth. Different mechanism, different classes,
   should be tracked and (if warranted) fixed independently.
