# Fix: KK21 Weibull AFT fits converge to the wrong point (wrong IRLS working response and wrong scale score)

> **Depends on:** none. Release index:
> `../future_release_plans/release_v1_0_5.md → TODO-67`. Found 2026-10-09 by two independent subagents in the
> algorithm-catalog sweep (`../new_feature_plans/algorithm_choice_audit.md`,
> per-kernel appendix). Confirmed by the coordinator with a hand derivation
> and a pure-R port checked against `survival::survreg` (no EDI build).

## Where

The same two update formulas appear in both places, copy-pasted:

- `R/EDI/src/kk21_stepwise_survival.cpp:21-86`,
  `weibull_reduced_fit_for_score_test()`: the reduced-model fit that the KK21
  stepwise survival score test is evaluated at (callers `:145`, `:204`).
- `R/EDI/src/kk21_weights.cpp:744-840`, `univariate_weibull_tstat()`: the
  per-covariate Weibull Wald t used for KK21 survival weights (caller `:883`).

## The math

Weibull AFT: `log T = xβ + σε`, `ε` standard minimum-extreme-value. With
`z = (log y − xβ)/σ` and `w = e^z`, the per-observation log-likelihood is
`δ(z − log σ) − e^z`, so:

- β-score ∝ `Σ x (w − δ)`; observed weight `w/σ²`; the correct IRLS working
  response is `η + σ(1 − δ/w)`.
- σ-score `= Σ [ −δ(z + 1) + z w ] / σ`.

The code uses:

- working response `log_y − σ·adj/w`, with `adj = δ ? (z − 1 + w) : w`. Its
  fixed point is `Σ x (z − 1)(w − δ) = 0`, not `Σ x (w − δ) = 0`.
- `score_s = Σ [ δ(z − 1) − z w ] / σ`. The sign convention is flipped
  (consistent with the `σ − score/info` step), but the δ constant term has the
  wrong sign, so the score is off by `2Σδ/σ`.

Neither error is a censoring-only effect. The `(z − 1)` factor is present for
every observation.

## Evidence

Script: a pure-R port of the C++ loop
(session scratchpad `weibull_check.R`; rerun recipe below). n = 400,
true β = (1, .5, −.3), σ = .7:

| | β₀ | β₁ | β₂ | σ |
|---|---|---|---|---|
| `survreg` MLE (24% censored) | 1.006 | 0.465 | −0.296 | 0.692 |
| EDI loop as written | **−9.481** | 0.283 | −0.134 | **10.0** (clamp) |
| same loop, corrected formulas | 1.006 | 0.465 | −0.296 | 0.692 |

With **no** censoring, the as-written loop drives σ to the clamp and the
weights underflow until `XᵀWX` is singular, so `univariate_weibull_tstat`
would return its `−1.0` sentinel and the reduced fit would return `false`.

## Impact

- KK21 survival covariate weights (`univariate_weibull_tstat`) and the KK21
  stepwise survival variable ordering (score test at a non-MLE reduced fit)
  are not what they claim to be. This affects **design efficiency only**
  (which covariates get weight in the matching metric). Randomization
  validity is untouched, because the weights are functions of the covariate
  history, not of the treatment assignments under test.
- `tests/testthat/test-kk21-weighted-crossprod.R:59`
  (`kk21_weibull_weight_reference`) re-implements the **same** wrong
  updates, so its parity check passes and cannot catch this.
- Memory/plan `project_kk21_speedup_vs_glm_weights_20261008` compared
  speedup weights to GLM weights. Its survival rows were computed against this
  buggy fit and should be re-run after the fix.

## Fix

- [ ] TODO-1: Replace both loops with one shared helper. Either use the
  correct IRLS working response `η + σ(1 − δ/w)` plus the correct σ-score and
  information (`Σ[δ + z²w]/σ²`-type observed information, or Newton on
  `(β, log σ)` jointly), **or**, preferably, reuse the existing Weibull
  likelihood and Newton path in `fast_weibull_regression.cpp` rather than a
  third hand-rolled copy.
- [ ] TODO-2: Replace `kk21_weibull_weight_reference` in
  `test-kk21-weighted-crossprod.R` with a `survival::survreg(dist = "weibull")`
  oracle (coefficient z-statistic), on censored **and** uncensored fixtures.
- [ ] TODO-3: Add a reduced-fit parity test for
  `weibull_reduced_fit_for_score_test` vs `survreg` on the same fixtures.
- [ ] TODO-4: Fix the start constant `+0.5722` (Weibull start, flagged in
  the designs catalog). It looks like a typo for Euler's γ = 0.5772. Harmless
  once the fit converges correctly, but fix it while there.
- [ ] TODO-5: Re-run the KK21 survival weight comparison
  (`project_kk21_speedup_vs_glm_weights_20261008`) and any `package_tests`
  CSV rows for KK21 stepwise survival designs.

Build/verify per `CLAUDE.md`: targeted compile of the two touched `.cpp`
files plus relink only. No full rebuild.
