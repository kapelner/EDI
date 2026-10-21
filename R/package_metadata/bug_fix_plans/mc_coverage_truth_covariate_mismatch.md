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

**What this evidence does not yet establish:** deterministic block cycling
keeps the paired empirical `(X, y_base)` distribution fixed, whereas the
bootstrap construction changes its realized row weights on each fit. Those
are not interchangeable finite-sample experiments, and the evidence above
does not record a multi-`mc_n` convergence curve or per-fit optimizer/Hessian
diagnostics. Before treating cross-scheme agreement as an acceptance test,
the target population must be stated: the fixed empirical dataset
distribution, or a specified superpopulation for `(X, y_base)`. The
comprehensive harness currently carries the finite dataset rows into its
coverage setup, but the plan does not establish maintainer approval that
this finite empirical projection is the intended matched-Cox truth.

**Safe next step:** obtain that target-population decision first. If the
finite empirical distribution is intended, the controlled convergence
experiment should preserve paired rows and their weights, vary only `mc_n`
and independent simulation seeds, and retain coefficient, convergence,
and Hessian/usable-fit diagnostics for each fit; bootstrap-resampled rows
would be a separately labeled sensitivity analysis, not a competing truth
definition. If a superpopulation is intended, its joint covariate/outcome
generator must be specified before any run. Until this choice is made, keep
the two matched-Cox truths unavailable and do not spend another long fit on
an ambiguous target.

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

## Implementation audit, 2026-10-08

The remaining registry gaps are now closed in the harness:

- `InferenceSurvivalKMDiff` uses a survival MC-refit truth rather than raw
  `beta_T` (TODO-7).
- `InferenceIncidLogRegr` moved from the marginal closed-form odds contrast
  to an MC-refit truth matching its default conditional estimand (TODO-8).
- `InferenceOrdinalCauchitRegr`, `InferenceOrdinalAdjCatLogitRegr`,
  `InferenceOrdinalContRatioRegr`, and
  `InferenceOrdinalPartialProportionalOddsRegr` now have MC-refit registry
  entries (TODO-10).
- `InferenceOrdinalCloglogRegr` and `InferenceOrdinalOrderedProbitRegr`
  now use the same MC-refit truth. Both fit a different cumulative-link
  family from the harness's cumulative-logit DGP; grading either against raw
  `beta_T` confounded link misspecification with interval coverage. This
  closes the truth-scale portions of
  `ordinal_cumulative_link_null_refit_multistart.md` TODO-14/17.
- The unresolved TODO-6 matched-Cox cells now return an explicitly unavailable
  (`NA`) coverage truth. This prevents both known-bad alternatives: caching an
  unconverged real-X MC target or silently falling back to raw `beta_T`.
  Coverage for these two classes remains intentionally ungraded until a
  converged target or a revised test scenario exists.

Focused source-loaded tests exercise all six new MC dispatches, cache/logging
lookup, real-covariate forwarding, and the two unavailable matched-Cox cases.
The prior proportion-truth regression remains green. The multi-hour TODO-4
result regeneration and TODO-5 baseline re-audit are still release-validation
work; no shared result CSV or audit baseline was rewritten in this change.

**Artifact readiness audit, 2026-10-16 (read-only):** The retained
`comprehensive_tests_results_nc_1_survival.csv` is 372,209,537 bytes with
mtime 2026-09-27 11:19:22 +0300, predating the 2026-10-08 real-covariate
truth implementation. `comprehensive_results_audit_baseline.csv` is 756,199
bytes with mtime 2026-09-24 15:59:56 +0300; it predates both that fix and the
retained survival results. `stale_ok_row_rules.csv` is 18,702 bytes with
mtime 2026-10-09 01:13:40 +0300, but its later timestamp does not make the
underlying coverage results current. These artifacts therefore cannot
validate TODO-4 or serve as TODO-5's post-fix re-audit; both depend on a
canonical rerun followed by audit regeneration. The plan estimates that
rerun as multi-hour and explicitly notes it writes shared result CSVs, so it
was not started here.

The matched-Cox convergence gate is also not resolved by the current source
guard: `KKStratCoxPHOneLik` and `KKLWACoxPHOneLik` now yield unavailable
(`NA`) coverage truths, which prevents grading against either known-bad
candidate but establishes no converged target. Per the existing TODO-6
warning, no speculative class rerun or covariate-cap choice was made. Keep
TODO-4/5 pending canonical post-fix artifacts and TODO-6 pending either the
specified convergence evidence or a maintainer-approved revised scenario.

**Harness/output-path audit, 2026-10-16 (read-only):** the retained survival
CSV's first rows record commit `8918bada0547a6bfb5454b8623c69e8d50ccc6b5`
and timestamps from 2026-08-24; the `InferenceSurvivalKMDiff` example row
has `coverage_truth = 0`, consistent with the pre-TODO-7 raw-`beta_T`
fallback. The current harness fixes `max_n_dataset = 148`, uses
`beta_T_values = c(0, 0.5)`, and its survival MC-refit entries use
`mc_n = 20,000` for Bernoulli-design classes (3,000 for matched classes).
It writes to a path derived from the script's parent repository, not an
output-directory argument. A `response=survival`/class-filtered run writes a
new `_filtered_...csv`; `audit_comprehensive_results.R` reads only the
canonical `comprehensive_tests_results_nc_1_<response>.csv` files, so such a
filtered file is diagnostic evidence, not TODO-4/5 completion. The audit's
`--write-baseline` likewise writes the baseline beside itself after reading
the canonical response files.

An isolated diagnostic is feasible without redirecting or risking the live
CSV: stage the harness, `_dataset_load.R`, its likelihood-smoke helper, and
watchdog under a disposable repository/worktree in `/tmp`, retaining Git
metadata because startup invokes the dry-run stale-row checker. The runner
then derives both result and baseline paths from that staged root. A bounded
first probe should use one non-KK survival MC-refit class, one dataset, one
replicate, and `beta_T=0.5`; verify that its filtered output is created only
under the staged root, records the expected HEAD commit and finite MC truth,
and preserve the staged source diff/hash plus `packageVersion("EDI")`,
`.libPaths()`, and the installed `EDI.so` hash separately (the CSV records
the Git HEAD, not the dirty patch or installed-package identity). Do not
count this filtered probe as coverage confirmation. Before the canonical
run, enumerate the full stale-row set:
the current `stale_ok_row_rules.csv` includes the original three survival
classes but has no `SurvivalKMDiff` rule, and it also lacks the four ordinal
classes added by TODO-10 (`OrdinalCauchitRegr`, `OrdinalAdjCatLogitRegr`,
`OrdinalContRatioRegr`, `OrdinalPartialProportionalOddsRegr`). The canonical
response-file regeneration and audit-baseline rewrite remain a separate,
explicitly approved multi-hour step; neither was launched here.

**Bounded isolated diagnostic, 2026-10-16:** Ran exactly one filtered
survival class/dataset/replicate at `beta_T=0.5`, one core, Wald family:
`InferenceSurvivalKMDiff` / `cars` / rep 1. The disposable clone lives at
`/tmp/edi-todo10-diagnostic.C97NQu/repo` and retains Git metadata; its HEAD
is `430c19bcdb0702d998c79f9058c449449034134c`. The checked-out harness and
watchdog files were copied into it byte-for-byte (SHA-256
`3a870d1c980505b0b4df01430264d4a969f442111d7258daeb7cab7918c122b4` and
`6059cbe88972f252e884c9c26c3b13876a13ca5f3f5b6b2a78e44fe0b50a3157`,
respectively). The filtered output is only in that clone:
`comprehensive_tests_results_nc_1_survival_filtered_design-Bernoulli_class-InferenceSurvivalKMDiff_dataset-cars_beta-0.5_rep-1_family-wald.csv`.
Both formula branches returned `status=ok`; the `~1` truth was `0.6141116`
with CI `[-0.1872613, 0.7778929]`, and the `~.` truth was `0.5755462` with
CI `[0.3911263, 1.2957628]`; each CI contains its reported MC truth. The
installed package was EDI 1.0.3 at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with `.libPaths()`
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7`,
`/usr/local/lib/R/site-library`, and `/usr/lib/R/library`; installed
`libs/EDI.so` SHA-256 was
`20f5713ae07cf3c7f53b7e5b66657bce028183a1b74d778d83fe0b061135f3a9`.
This is only a one-replicate diagnostic (and used the installed package),
not coverage confirmation or canonical regeneration. The canonical survival
CSV still has its prior 2026-09-27 mtime; no canonical CSV or audit baseline
was written, and no build/install was run. TODO-4/5 remain open.

**TODO-10 stale-stratum inventory, 2026-10-16 (read-only):** the retained
survival file is 372,209,537 bytes (mtime 2026-09-27) and the retained
ordinal file is 417,165,307 bytes (mtime 2026-10-09); among the affected
classes, the newest row in either file is dated 2026-09-27. The new
2026-10-16 isolated-seed MC truth therefore has no canonical row yet. The
harness has 12 survival and 9 ordinal `COVERAGE_MC_SPEC` classes. Existing
class-wide stale rules are present for only six of them, all with the old
2026-09-24 cutoff: survival `SurvivalLogRank` (15,666 rows),
`SurvivalGehanWilcox` (13,425), `SurvivalStratCoxPHRegr` (38,059); ordinal
`OrdinalRidit` (22,138), `OrdinalKKGLMM` (8,020), and
`OrdinalKKCLMMCauchit` (7,722). Those six cutoff dates must advance to
2026-10-16 to expire the retained pre-seed rows; the current rows begin on
2026-09-24, so the existing cutoff does not expire the post-cutoff portion.

No class-wide rule currently covers these nine survival MC-truth strata
(row counts in the retained file): `SurvivalKMDiff` (52,262),
`SurvivalCoxPHRegr` (64,898), `SurvivalWeibullRegr` (120,317),
`SurvivalDepCensTransformRegr` (50,919), `SurvivalKKLWACoxPHOneLik`
(12,689), `SurvivalKKStratCoxPHOneLik` (13,744),
`SurvivalGLMMWeibullFrailtyLoggammaOneLik` (5,186),
`SurvivalGLMMWeibullFrailtyNormalOneLik` (12,268), and
`SurvivalKKWeibullMarginal` (10,214). Existing function-specific rules for
KKLWA and the log-gamma frailty class cover only selected randomization/score
operations, not every `function_run` whose row stores `coverage_truth`.
Class-wide rules are also missing for six ordinal MC-truth strata:
`OrdinalCauchitRegr` (44,111), `OrdinalCloglogRegr` (44,110),
`OrdinalOrderedProbitRegr` (44,111), `OrdinalAdjCatLogitRegr` (42,682),
`OrdinalContRatioRegr` (66,981), and
`OrdinalPartialProportionalOddsRegr` (26,951). Thus 15 classes (611,443
retained rows) need new class-wide rules; the other six classes (105,030
rows) need their existing class-wide cutoff advanced. This inventory includes
all four TODO-10 classes; their old rows are still present despite the source
registry fix.

The exact pruning scope is one rule per affected response/class with blank
`function_run` (all functions), cutoff `before_timestamp=2026-10-16`, and a
`tracked_in` reference to the committed seed-isolation change once that source
change has a commit. A blank function filter is required because the harness
records `coverage_truth` on estimate, p-value, CI, and other function rows,
not just CIs. Full regeneration filters must cover both response types,
all registered datasets, both `beta_T` values (0 and 0.5), every replicate,
and every supported function family; the prior diagnostic filter
`survival / Bernoulli / InferenceSurvivalKMDiff / cars / beta=.5 / rep=1 /
family=wald` is only four rows and is not representative coverage. The two
matched Cox classes currently have numeric `coverage_truth` in all retained
rows but the post-fix unavailable-truth guard returns `NA`; their stale rows
must be expired class-wide as well. No stale-rule CSV or shared result file
was changed during this audit. Add the rule rows only after the source commit
exists so `--check-rules` can validate `tracked_in`; then run the canonical
survival/ordinal regeneration and audit separately under explicit approval.

**Stale-rule metadata follow-up, 2026-10-18:** the historical inventory above
predates the rule-file update. `R/package_tests/stale_ok_row_rules.csv` now has
class-wide, blank-`function_run` rules for all 12 survival and 9 ordinal
`COVERAGE_MC_SPEC` strata at the `2026-10-16` cutoff, each tied to the
committed seed-isolation change `05117b6bea93921669f061067a9eefb9d22cb8ac`.
This closes the rule-inventory gap only; it does not validate or replace any
canonical rows, and comprehensive regeneration plus baseline re-audit remain
open.

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

## TODO-10 (added 2026-09-24, high confidence for the mechanism; source fix implemented 2026-10-08, release validation pending): 3 more classes with the same missing-MC-truth pattern as Ridit

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
parameter). Test-harness-only change; does not touch `R/EDI` source.

**Implemented, 2026-10-08:** all four registry entries are now present in
`COVERAGE_MC_SPEC`. The focused source-loaded registry tests cover their
dispatches along with the linked KMDiff and conditional-incidence entries;
see “Implementation audit, 2026-10-08” above. This closes the source-level
TODO-10 action. It does not close the plan's release-validation TODO-4/5:
the shared comprehensive-results regeneration and its baseline re-audit are
still required and remain deliberately unclaimed here.

**Adjacent test scope check, 2026-10-18:**
`test-comprehensive-proportion-coverage-truth-reference.R` passed 18
assertions against current harness source after `pkgload::load_all("R/EDI",
compile = FALSE)` at HEAD `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`. Its
fixture covers the separate proportion mean-difference truth and Wilcox
response-qualified MC path; it does not exercise this TODO's four ordinal
MC-truth entries, so it is not TODO-10 validation. Installed EDI was 1.0.3;
the installed DLL and `pkgload`'s source-session DLL had matching MD5
`dd43c5d0e11708aea17ba82b900f66d1`. This harness-only test does not call
native code. The ordinal source-level registry evidence remains the focused
registry test recorded above; the outstanding TODO-10 gates are comprehensive
result regeneration and baseline re-audit.

**Direct TODO-10 registry recheck, 2026-10-18:**
`test-comprehensive-coverage-mc-registry-gaps-reference.R` passed all 50
assertions (0 failures, warnings, or skips) after
`pkgload::load_all("R/EDI", compile = FALSE)` at the same checkout HEAD.
This directly exercises all four TODO-10 ordinal class dispatches through
`get_coverage_truth()` and `get_estimate_logging_theta()`, including the
20,000-draw argument and real-covariate fixture, plus key-specific RNG
isolation/cache behavior. Installed EDI was 1.0.3; its DLL and the DLL loaded
by `pkgload` both had MD5 `dd43c5d0e11708aea17ba82b900f66d1`. The test
evaluates selected harness assignments with a stubbed MC function; it does
not run the 20,000-draw simulation or call native code. Thus it strengthens
source-level dispatch evidence only; comprehensive result regeneration and
baseline re-audit remain open.

**Deterministic MC-truth retry/cache/RNG regression, 2026-10-21:** the same
focused registry test now also drives the bounded retry loop with a stubbed
sequence of implausible finite, non-finite, and plausible MC results. Its
independent test-side seed oracle checks the per-attempt seed states derived
from the complete cache key; assertions cover accepting and caching only the
first plausible result, a cache hit without a fourth fit, exhausting all five
attempts without caching, and restoring the caller's `.Random.seed`. The
focused command
`Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-coverage-mc-registry-gaps-reference.R")'`
passed 89 expectations (0 failures, warnings, or skips; exit 0) with installed
EDI 1.0.3 attached. The test evaluates selected current harness assignments
in a local fixture and stubs MC fitting; it calls no native kernel and runs
no calibration. This is only deterministic source-contract evidence; affected
result regeneration and baseline re-audit remain open.

**Adjacent ordinal attempt-roster input contract, 2026-10-21:** the same
source-only test file also checks the reduced ordinal expected-attempt roster
fixture's explicit-flag guards: omitting `skip_slow` or supplying a nonlogical
`has_compute_estimate` is rejected with the helper's documented errors. The
focused `testthat::test_file(...)` run passed with no failures, warnings, or
skips against installed EDI 1.0.3; this roster assertion parses the runner and
calls the pure-R manifest helper, not an inference fitter or native kernel.
It guards fixture validity only: it does not establish concrete runtime class
capabilities, emitted-attempt completeness, comprehensive row regeneration,
or baseline re-audit.

**Default-formula dispatch regression, 2026-10-20:** broadened the same
registry test to cover the bare `InferenceIncidLogRegr` label. The harness
defaults bare fixed-formula labels to `~.`, so this path must forward the
real covariate matrix just like an explicit `model_formula=~.` label. The
focused test passed 53 expectations after loading installed EDI 1.0.3
(`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-coverage-mc-registry-gaps-reference.R")'`;
loaded DLL MD5 `dfd5bf4384b5a0cc0d430fd70dab2a59`). The test evaluates selected
assignments from the current `comprehensive_tests.R` in a stub environment;
it does not call the installed package or native code and makes no coverage
or calibration claim. TODO-4/5 regeneration and TODO-6 matched-Cox
convergence/policy remain open.

**Checkout-R source-overlay recheck, 2026-10-20:** the same test passed 53
expectations with checkout R sources loaded by
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. R was
`R Under development (unstable) (2026-10-13 r90668)`, and the loaded
namespace path was `/home/kapelner/workspace/EDI/R/EDI` (package version
1.0.3). `comprehensive_tests.R` SHA-256 was
`0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`; the
test SHA-256 was
`e392d6fafe916fdc2f15daf088aef6f83c79a3b5eb32990014c3b789c2d9510b`.
The loaded temporary DLL SHA-256 was
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`,
matching the existing installed EDI DLL. The test parses the current harness
and evaluates only selected assignments in a stub environment; the MC fit is
stubbed, so no native fitting or calibration run occurred. This is
source-level harness-dispatch evidence only; result regeneration and baseline
re-audit remain open. No build/install or canonical result write occurred.

**Cache adjustment-set isolation regression, 2026-10-20:** extended the
same focused test with a paired `model_formula=~.` / `model_formula=~1`
case for the same class, dataset, effect, and response. It confirms that the
real-covariate and intercept-only routes receive distinct MC truths, pass
`real_X` versus `NULL` to the stub, and each reuse only its own cached value.
`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-coverage-mc-registry-gaps-reference.R")'`
passed 59 expectations (0 failures, warnings, or skips) against installed
EDI 1.0.3. The test evaluates selected current-checkout harness assignments
with a stubbed MC fit; it does not fit models, call native kernels, or
validate calibration. The linked result-regeneration and baseline
reconciliation gates remain open.

**Bounded actual-attempt artifact audit, 2026-10-20:** read-only inspection of
the existing source-overlay pilot at `/tmp/edi-todo10-row-pilot.WQ09ZP`
reconciled its four selected `compute_estimate` natural keys exactly: two
`InferenceSurvivalKMDiff`/`cars`/survival/Bernoulli rows (design formula
`~1`, `~.`) and two `InferenceOrdinalRidit`/`diamonds`/ordinal/Bernoulli rows
with the same formula pair. Each CSV had two unique full keys, both `status=ok`,
unique `id` and `run_row_id`, and no missing, extra, or duplicate keys against
the explicitly reconstructed four-key target. For both CSVs, the sidecar's
recorded path, byte count, and SHA-256 match the file; the before/after R
version, EDI version, DLL hash, checkout HEAD/diff hash, and runner hash also
match. Provenance records R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
CSV/sidecar hashes are `e467af71f4ae3755d5e97bf8f403d8e91d11880b531c962845eae114ad77bbc5` /
`b0397e49108d5610b405d6f134327f937f71736f17750768cd81012139c6511e` for the
survival slice and `aa042a5bdac1ca0a30be61065a2250070672e7c59ec4245928956c83785da3e5` /
`a677c6ddf0d115320981d016c01f9e0c47b51ae6271d389108450b2d86dadc41` for the
ordinal slice. Important limitation: these retained sidecars use provenance
schema 1, whereas the current `validate_comprehensive_result_artifact()`
requires schema 2, so this manual identity/key audit is not current-validator
acceptance. It is limited to these two estimate-only cases and does not
reconcile the full affected class/family/dataset/beta/replicate grid or the
baseline audit. No fit was rerun and no artifact or canonical output was
written. The next bounded step is to produce these same isolated candidate
rows with the current schema-2 harness sidecar, then continue to the full
accepted result matrix and baseline re-audit.

**Retained-artifact inventory recheck, 2026-10-21:** the schema-2 cohort at
`/tmp/edi-todo10-schema2.HNmaUs` remains limited to four selected
`compute_estimate` rows for SurvivalKMDiff/cars and OrdinalRidit/diamonds
(two design formulas per slice). The CSV and sidecar hashes match the
recorded pilot, but the sidecars identify only the captured run: their runner
SHA-256 is `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`,
while the current raw `comprehensive_tests.R` file hashes to
`72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`. The
20,160-row source case lattice is candidate scope, not an emitted-attempt
roster: setup/class eligibility, `function_run` emission, and runtime skips
remain unresolved. Canonical `R/package_tests/comprehensive_tests_results_nc_1_survival.csv`
(372,209,537 bytes; 2026-09-27) and `..._ordinal.csv` (417,165,307 bytes;
2026-10-09) have no adjacent provenance sidecars. Thus no current-source
complete or reconcilable result exists beyond the four-key pilot. Full
attempt-roster derivation, setup/outcome capture, current-source schema-2
regeneration, exact key/status/value reconciliation, and baseline re-audit
remain open. This inventory was read-only; no result or canonical file was
changed.

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

**Read-only artifact/provenance audit, 2026-10-21:** the only retained
proportion comprehensive-results snapshot located for this finding is the
ignored local file
`R/package_tests/comprehensive_tests_results_nc_1_proportion.csv` (84,170,816
bytes; SHA-256
`cd5bbd589816657930eb8e4aa5ae92b9f4fe8de02084dcfa21548a37d9edc6ba`, mtime
2026-10-09). Its 1,438 `ionosphere`, beta_T=0.5 rows for the two affected
classes comprise 854 `PropBetaRegr` rows and 584 `PropFractionalLogit` rows.
Rows cite checkout commit `95e5203765fde92b5d501c0e93139603c2a95bf1`
(2026-09-23), but the snapshot has no provenance sidecar and no loaded
package/DLL identity; its recorded temporary heartbeat log is absent. It is
therefore historical exploratory evidence, not a provenance-matched
post-fix comparison. The retained `/tmp/edi-todo7-coverage-20261018/merged-coverage.rds`
and `/tmp/edi-todo10-coverage-merged-391356/merged-coverage.rds` are code-
coverage reports, not statistical CI-coverage runs, and do not close this
gap. The observed ionosphere pattern remains about 0.79--0.81 for asymptotic,
Wald, likelihood-ratio, and subsampling CIs, versus 1.00 for
jackknife-Wald/LR-bootstrap; it is consistent with, but does not prove, a
high-p/n SE limitation. No lower-covariate-count dataset comparison with
matched runtime provenance was found.

**Acceptance gap remains:** run a provenance-matched beta_T=0.5 comparison
for both classes on at least one lower-p/n dataset (the plan's examples are
`pima`/`boston`), with enough replicates and the same coverage-truth
construction, to determine whether under-coverage is ionosphere-specific or
also appears at lower covariate counts. Then obtain the maintainer's
disposition: either document a reproducible high-p/n small-sample limitation,
or investigate a finite-sample correction to the beta/fractional-logit SE
formula. If the lower-p/n slice also under-covers, reopen the shared
truth/SE-bug hypothesis before choosing either path. No simulation or result
file modification occurred for this audit.
