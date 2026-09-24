# Investigate: `InferenceContinQuantileRegr` — Near-Universal `low_coverage` Across Every CI Method

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's `low_coverage` backlog after the
> `stale_ok_row_rows` prune. **Medium confidence on the primary claim
> (truth-mismatch hypothesis ruled out by direct distributional argument);
> low confidence on the actual root cause, which remains open.**

## The finding

33 of 33 `(formula, function_run)` cells for `InferenceContinQuantileRegr`
fail the audit's `low_coverage` check — every asymptotic method
(`asymp`, `wald`), every resampling family (`bootstrap`,
`bayesian_bootstrap` × 5 CI-construction variants, `m_out_of_n_bootstrap`,
`subsampling`, `rand_bootstrap` × 4 variants, `jackknife_wald`,
`rand`), for both `model_formula=~1` and `~.`. Coverage ranges from a mild
0.97-0.99 (over) to a severe 0.765-0.828 (under, worst:
`compute_rand_bootstrap_confidence_interval_symmetric-percentile-t`
at `~1`, `compute_bootstrap_confidence_interval_studentized` at `~.`),
with a mix of both over- and under-coverage across methods, all
`n>200` rows (some >1700), so this is not sampling noise on any single
cell.

This breadth — essentially every CI-producing method failing at once,
both formulas — is the exact symptom this codebase already has a named
pattern for: several sibling classes (`InferenceSurvivalLogRank`/
`GehanWilcox`, `InferenceOrdinalRidit`) previously showed identical
"near-universal miscoverage across every method simultaneously" and it
turned out to be a **harness truth-scale mismatch** (the audit's MC
truth registry, `COVERAGE_MC_SPEC` in `R/package_tests/comprehensive_tests.R`,
had no entry for the class, so `get_coverage_truth()` fell back to the raw
DGP shift parameter `beta_T_val` — correct for a collapsible
mean-difference estimand, wrong for a non-collapsible or differently-scaled
one), not a real CI defect.

## Truth-mismatch hypothesis: checked, RULED OUT

`InferenceContinQuantileRegr` is indeed **absent from `COVERAGE_MC_SPEC`**
(confirmed by grep — no entry, unlike its sibling
`InferencePropQuantileRegr`/`InferencePropKKQuantileRegrOneLik`, which
already got exactly this treatment), so `get_coverage_truth()` does fall
back to raw `beta_T_val` for it (`comprehensive_tests.R:3379-3396`,
`COVERAGE_CLOSED_FORM`/`COVERAGE_MC_SPEC` both miss). That looked like an
exact match to the known pattern at first glance.

**But the DGP rules this out for this specific class.** The harness's
continuous-response generator (`apply_treatment_effect_and_noise()`,
`comprehensive_tests.R:3099-3103`) is:
```r
eps = rnorm(1, 0, SD_NOISE)
bt = ifelse(w_t == 1, beta_T, 0)
return(y_t + bt + eps)
```
— a **deterministic, homogeneous, purely additive** treatment shift
(`beta_T` if treated, `0` if not), added on top of a (possibly nonlinear
in covariates) baseline `y_t` plus symmetric zero-mean noise. The median
of a random variable is shift-equivariant for *any* underlying
distribution: `median(Y + c) = median(Y) + c` for any constant `c`,
regardless of `Y`'s shape. Since `bt` depends only on `w` (never on `x`
or on any random component) and treatment is randomized (so the `x`-
distribution doesn't differ by arm), the true `tau=0.5` quantile
treatment effect equals `beta_T` **exactly** — both the marginal
(`~1`) and the `x`-conditional (`~.`) version, with no dependence on
whether `y_t(x)` is linear (`InferenceContinQuantileRegr` defaults to
`tau=0.5`, confirmed via its own roxygen docstring,
`inference_continuous_quantile_regr.R:1-40`). So, unlike `LogRank`/
`GehanWilcox`/`Ridit`, the raw-`beta_T_val` fallback is actually the
*correct* truth here in principle — there's no structural estimand-scale
mismatch to fix by adding a `COVERAGE_MC_SPEC` entry. Adding one would be
a no-op at best (an MC-fitted truth would just re-derive `beta_T`).

## What remains unexplained

The near-universal-failure symptom is real and needs a different
explanation. Two candidate, unconfirmed directions:

1. **Quantile-regression SE finite-sample breakdown under this harness's
   DGP.** `SD_NOISE = 0.1` (`comprehensive_tests.R:834`) is very small —
   this is a near-noiseless location-shift model. `quantreg`'s Powell-style
   `"nid"` sandwich SE (this class's default, per its own docstring) is a
   kernel-density/sparsity-function estimator at the target quantile;
   such estimators are known to be sensitive to bandwidth choice and can
   misbehave when the residual distribution is very concentrated. This
   would explain the `asymp`/`wald` failures (both use the same sandwich
   SE) but not obviously the independently-implemented resampling-family
   failures — unless those also route through the same asymptotic SE
   machinery internally, not verified here.
2. **Compounding with `TODO-20`'s tie-sensitivity hypothesis**
   (`release_v1_0_5.md`, with-replacement bootstrap + quantile
   regression's simplex-method tie sensitivity) for the resampling-family
   methods specifically (`bootstrap`, `m_out_of_n_bootstrap`,
   `subsampling`, `rand_bootstrap` variants all fail here too) — plausible
   but not confirmed to be the same mechanism as TODO-20's original
   `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
   finding, since this class isn't a "OneLik"/KK class and has a
   structurally different (non-matched-pair) resampling path.

Neither direction was traced to an exact line or reproduced empirically —
this fork prioritized ruling out the higher-prior truth-mismatch
hypothesis over speculative SE-formula tracing, given the time budget.

## TODOs

- [ ] TODO-1: Reproduce directly: fit `InferenceContinQuantileRegr` on a
  synthetic dataset with a known small-noise location-shift DGP matching
  the harness exactly, confirm the point estimate is itself unbiased
  (this would confirm/refute direction 1's SE-only framing vs. a
  point-estimate bias hypothesis instead).
- [ ] TODO-2: If the point estimate is unbiased, read `quantreg::summary.rq`'s
  `"nid"` SE computation directly (or however this class extracts SEs from
  `quantreg::rq`) and check its bandwidth-selection behavior specifically
  under small residual variance.
- [ ] TODO-3: Check whether the resampling-family methods
  (`bootstrap`/`subsampling`/`m_out_of_n_bootstrap`/`rand_bootstrap`)
  independently construct their own SE/CI or ultimately call back into
  the same `"nid"` sandwich machinery — if independent, direction 1 alone
  can't explain their failure and TODO-20's tie-sensitivity hypothesis
  (or a third, unidentified mechanism) becomes more likely for those
  specifically.
- [ ] TODO-4: Confirm this class is unaffected by `TODO-28`
  (`cached_design_matrix` staleness) — not checked by this fork; given the
  failure spans `asymp`/`wald` (non-bootstrap) too, TODO-28 alone cannot
  be the whole explanation even if it partially applies to the
  bootstrap-family subset, but should still be ruled in/out for
  completeness.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
