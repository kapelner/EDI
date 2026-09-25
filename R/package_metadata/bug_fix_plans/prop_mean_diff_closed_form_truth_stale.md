# Fix plan: proportion mean-diff closed-form coverage truth is stale relative to the 2026-09-15 DGP fix

Found 2026-09-25, investigated at user request while checking other proportion
classes for the pattern behind `mc_coverage_truth_covariate_mismatch.md`'s
TODO-11. Not the same bug -- this one uses the `COVERAGE_CLOSED_FORM` path,
not the Monte-Carlo path, and is more severe (0.00-0.33 coverage on affected
rows, not ~0.80).

## Symptom

`InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`, and
`InferencePropGCompMeanDiff` show near-zero coverage on `boston` (0.00, 0.00,
0.00 respectively, hundreds of rows each) at `beta_T = 0.5`, while showing
0.95-0.97 on `diamonds` and (mostly) `abalone`. Every CI method for a given
(class, dataset) agrees closely with every other method -- e.g. on
`AllSimpleAverageDiff`/`boston`, `asymp`/`wald`/`bootstrap`/`bootstrap_bca`/
`subsampling`/`bayesian_bootstrap` all return intervals in `[0.04, 0.17]`,
consistently -- so the CIs are not independently broken; they're all being
graded against the same wrong reference value.

## Root cause

`compute_prop_mean_diff_coverage_truth()` (`comprehensive_tests.R:3191`):

```r
compute_prop_mean_diff_coverage_truth = function(dataset_name, beta_T_val){
	y_p = datasets_and_response_models[[dataset_name]]$y_original$proportion
	mu_c = y_p
	mu_t = pmin(1, pmax(0, y_p + beta_T_val))
	mean(mu_t - mu_c)
}
```

computes the truth as a **raw additive shift clamped to [0, 1]**. But the
actual proportion DGP, `apply_treatment_effect_and_noise()`
(`comprehensive_tests.R:3128-3130`), was fixed on 2026-09-15 (per its own
code comment) to shift on the **logit scale**, with the baseline clamped to
`[0.05, 0.95]` first:

```r
p_base = pmin(0.95, pmax(0.05, y_t))
p_t = plogis(qlogis(p_base) + bt + eps)
```

specifically to avoid the boundary-clamping distortion a raw additive shift
causes. The truth function was never updated to match -- it still implements
the pre-fix formula. The sibling incidence function,
`incid_p_base_and_treated()` (`comprehensive_tests.R:3170-3174`), already
implements the *correct* pattern (`pmin(0.95, pmax(0.05, ...))` +
`plogis(qlogis(...) + beta_T_val)`); this looks like an omission when the
2026-09-15 fix was applied -- the incidence-side closed forms were updated
(or already correct) and the proportion mean-diff one was missed.

## Why some datasets look unaffected

Checked row timestamps directly: `diamonds` rows (2026-08-24 to 09-21, but
the ones checked here from before 09-13) and most `abalone` rows (09-02) for
these classes predate the 2026-09-15 DGP fix -- they are self-consistently
generated *and* graded under the old (raw-additive) DGP, so they coincidentally
pass. `boston`'s rows (09-15/09-16) are entirely post-fix: generated under the
corrected logit-scale DGP, graded against the still-uncorrected truth formula.
`AllSimpleMeanDiffPooledVar`/`abalone` (0.00 despite predating 09-15) is a
separate, already-diagnosed staleness layer -- those specific rows also
predate the 2026-09-06 fix that added `InferenceAllSimpleMeanDiffPooledVar`
to the `COVERAGE_CLOSED_FORM` fallback at all (see that fix's own code
comment at `comprehensive_tests.R:3200-3210`ish); before that fix this class
fell back to raw `beta_T_val` as truth, a third, compounding staleness.

## Verified

Directly recomputed the truth both ways for `boston` (`beta_T=0.5`):

| formula | truth |
|---|---|
| stale (raw additive, current code) | 0.466 |
| corrected (logit-scale, matching the actual DGP) | 0.112 |
| real per-row estimate (n=122) | mean 0.109, median 0.108, SD 0.021 |

The corrected formula matches the real estimator's behavior almost exactly;
the stale one is 17+ SDs off.

## Fix (not yet implemented -- comprehensive_tests.R was live/running at
investigation time, deliberately not edited)

Replace `compute_prop_mean_diff_coverage_truth()`'s body with the same
pattern `incid_p_base_and_treated()` already uses:

```r
compute_prop_mean_diff_coverage_truth = function(dataset_name, beta_T_val){
	y_p = datasets_and_response_models[[dataset_name]]$y_original$proportion
	p_base = pmin(0.95, pmax(0.05, y_p))
	p_t = stats::plogis(stats::qlogis(p_base) + beta_T_val)
	mean(p_t - p_base)
}
```

Test-harness-only change; does not touch `R/EDI` source.

## TODO

1. Apply the fix above once it's safe to edit `comprehensive_tests.R`
   (not mid-run).
2. Add `stale_ok_row_rules.csv` rules to expire the affected pre-fix rows
   for `AllSimpleAverageDiff`/`AllSimpleMeanDiffPooledVar`/`PropGCompMeanDiff`
   on every dataset (they were generated under the wrong DGP, not just
   graded with the wrong truth -- unlike TODO-11's classes, these need
   full regeneration, not just a re-audit, since the raw response values
   themselves came from the old DGP).
3. Check whether `InferenceAllSimpleWilcox` (also showing low coverage on
   `boston`/`abalone`/`diamonds`, e.g. 0.12-0.33) shares this bug or has an
   unrelated cause -- Wilcox's estimand is rank/median-based, not a mean
   difference, so `compute_prop_mean_diff_coverage_truth` may never have
   been the right truth for it even before this bug; not yet investigated.
4. Check `InferenceIncidGCompRiskDiff`/`InferenceIncidKKGCompRiskDiff` and
   any other class sharing `compute_prop_mean_diff_coverage_truth` or a
   similarly-shaped closed form for the same "DGP changed, truth function
   didn't" pattern -- this investigation only checked the proportion
   mean-diff family, not a full sweep.
5. Re-audit and prune `comprehensive_results_audit_baseline.csv` for
   findings this closes.

Independent of `mc_coverage_truth_covariate_mismatch.md`'s TODO-6/TODO-11
(different mechanism, different classes) -- do not conflate when resolving
either.
