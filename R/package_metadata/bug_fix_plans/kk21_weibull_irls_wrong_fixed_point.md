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

- [x] TODO-1: Replace both loops with one shared helper. Either use the
  correct IRLS working response `η + σ(1 − δ/w)` plus the correct σ-score and
  information (`Σ[δ + z²w]/σ²`-type observed information, or Newton on
  `(β, log σ)` jointly), **or**, preferably, reuse the existing Weibull
  likelihood and Newton path in `fast_weibull_regression.cpp` rather than a
  third hand-rolled copy.
- [x] TODO-2: Replace `kk21_weibull_weight_reference` in
  `test-kk21-weighted-crossprod.R` with a `survival::survreg(dist = "weibull")`
  oracle (coefficient z-statistic), on censored **and** uncensored fixtures.
- [x] TODO-3: Add a reduced-fit parity test for
  `weibull_reduced_fit_for_score_test` vs `survreg` on the same fixtures.
- [x] TODO-4: Fix the start constant `+0.5722` (Weibull start, flagged in
  the designs catalog). It looks like a typo for Euler's γ = 0.5772. Harmless
  once the fit converges correctly, but fix it while there.
- [ ] TODO-5: Re-run the KK21 survival weight comparison
  (`project_kk21_speedup_vs_glm_weights_20261008`) and any `package_tests`
  CSV rows for KK21 stepwise survival designs.

### Source-status reconciliation (2026-10-11)

TODO-1's two hand-written alternating loops are replaced by the shared
`WeibullAFTLikelihood` used by `fast_weibull_regression.cpp`, fitted through
the established damped-Newton-with-L-BFGS-fallback path on `(beta, log_sigma)`.
The univariate Wald statistic now inverts the full observed information, which
retains beta/log-scale cross-information. TODO-2 now uses a direct
`survival::survreg(dist = "weibull")` coefficient-z oracle on both censored
and uncensored fixtures. TODO-3 adds the corresponding native stepwise-score
parity test, with its reduced-model MLE supplied independently by `survreg`.
TODO-4 corrects the smart-start offset to Euler's gamma
(`0.5772156649015329`).

The native oracle gate was subsequently exercised by CI: successful
`test-bulk-non-cran` run
[#38808821543](https://github.com/kapelner/EDI/actions/runs/38808821543)
used checkout HEAD `430c19bcdb0702d998c79f9058c449449034134c`, where both the
source fix and the oracle test were present. The run installed that commit in
an isolated library, planned the correctness suite, and passed all five
correctness shards; the test manifest classifies the oracle file in that
correctness tier. This satisfies the native oracle execution gate. TODO-5 and
the required regeneration of the affected benchmark/CSV evidence remain
pending.

### Installed-package baseline diagnosis (2026-10-16)

Three independent runs of
`Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-kk21-stepwise-survival-weibull-mle-score-reference.R")'`
against installed EDI 1.0.3 reproduced the same first-fixture mismatch:
the installed stepwise kernel returns 6.1 while the test's independent
`survival::survreg(dist = "weibull")` reduced-model score reference is 6.45
(difference −0.345). Its separate fallback assertions pass. This is a stable
old-binary correctness discrepancy, not timing noise: the statistic is
computed deterministically from the fixed-seed fixture. The test oracle's
6.45 is the intended corrected value because it evaluates the score and
efficient information at the independently fitted Weibull MLE; current
checkout source now obtains that reduced fit from the shared
`WeibullAFTLikelihood`/optimizer and uses the same score/information formulas.
Since installed EDI 1.0.3 predates that checkout implementation, these runs
confirm only the historical baseline behavior. The post-fix native oracle
execution is now confirmed by CI run #38808821543 above; TODO-5
benchmark/CSV regeneration remains required.

### TODO-5 fixture/provenance audit (2026-10-16)

The named `project_kk21_speedup_vs_glm_weights_20261008` comparison has no
tracked fixture, raw output, or provenance record in the checked-in metadata,
benchmark, and package-test paths inspected for this audit. The existing
`test-kk21-stepwise-design-survival-weight-selection-reference.R` is a
fixed-seed `survival::survreg` correctness oracle (n=60); it does not compare
pre-fix with corrected weights or evaluate downstream matching quality. It
must not be treated as a substitute for TODO-5, and this is not a timing
acceptance question.

To make the historical comparison reproducible, retain the original fixture
(or its exact generator, seed, and input hash), old and corrected source/package
identities, and identical method options and RNG state. Record the old and
corrected survival weight vectors/ranks and the originally specified
downstream matching-quality metric, with row-level case/method identifiers,
status/errors, and a summary. Record R and `survival` versions, OS/compiler,
thread settings, commit and loaded package/DLL provenance. If the historical
fixture or metric cannot be recovered, obtain a maintainer-selected replacement
fixture and metric; neither the correctness oracle alone nor timing results
close this gate. The requested comparison is matching-quality validation, not
an A/B speed test.

The linked algorithm-sweep/TODO-31 reference is mismatched: release TODO-31
currently links to `glmm_variance_component_sigma_collapse.md` and concerns
GLMM/CLMM random-effect variance collapse, not KK21 survival weights. This
cross-reference does not change TODO-5 scope or acceptance.

### TODO-5 affected-artifact preflight (2026-10-18)

A fresh filename-only search of accessible `/tmp` paths found no retained
`project_kk21_speedup_vs_glm_weights_20261008` output or survival-weight
comparison artifact; some system-private `/tmp` directories are not readable,
so this is not proof that no such file exists anywhere on the host. The
checked-in package-test outputs available for a future reconciliation are
`comprehensive_tests_results_nc_1_survival.csv` and the aggregate
`comprehensive_tests_{coverage,mse,power,size}.csv` files. Their headers support
targeting raw rows by `response_type=survival` and `design=KK21stepwise`; the
aggregate schemas also carry these fields, with `function_run` available in
coverage, power, and size but not MSE. No row counts or duplicate-key audit was
performed, and no result file was changed. These selectors identify the
potentially affected scope only; they are not sufficient grounds to delete or
replace rows. After the comparison fixture/metric is recovered or maintainer
approved, run the post-fix comparison with row-level provenance, then reconcile
only confirmed affected keys and regenerate the corresponding aggregate values.

Build/verify per `CLAUDE.md`: rebuild the affected native translation
units (`fast_weibull_regression.cpp`, `kk21_stepwise_survival.cpp`, and
`kk21_weights.cpp`) and their shared `_helper_functions_core.h` dependents,
then relink. No full rebuild.

### TODO-5 replacement fixture and metric proposal (2026-10-18)

The checked-in oracle fixtures provide a reproducible starting point, but do
not themselves measure matching quality. In particular,
`test-kk21-stepwise-survival-weibull-mle-score-reference.R` uses
`set.seed(6721)`, `n = 120`, balanced treatment, `x ~ N(0,1)`, and a Weibull
time with shape 1.4 and scale `exp(0.35 * treatment + 0.55 * x)`; it compares
the native stepwise score with score arithmetic using the independently
estimated reduced-model `survival::survreg` MLE. The separate private-weight
oracle fixture (`set.seed(20)`, n = 60) verifies a per-covariate
`survreg` coefficient statistic. Neither fixture compares pre/post-fix
weights or resulting matched samples.

If the original `project_kk21_speedup_vs_glm_weights_20261008` inputs and
metric cannot be recovered, a reproducible replacement should extend the
seed-6721 generator to several named covariates with distinct prespecified
Weibull effects, preserve balanced treatment and the event/censoring
mechanism, and record the generated input hash and realized censoring rate.
For each covariate, compute an independent reference importance from a
`survival::survreg(dist = "weibull")` fit (the existing reduced-model score
reference is the closest test precedent), then run the same fixed-seed KK21
matching procedure with the old and corrected weight vectors. A defensible
primary matching-quality outcome is mean absolute standardized mean
difference (mASMD) across the prespecified covariates in the resulting
matched pairs; also retain the per-covariate `survreg`-reference ranks and
weight ranks as a diagnostic that ties the changed weights to the oracle.
Report raw values and paired case-level differences, not only an aggregate.

This is a proposal, not an approved replacement for the missing historical
estimand: no acceptance threshold, minimum improvement, or equivalence margin
is specified here. A maintainer must confirm the replacement fixture and
primary metric before execution. The already-installed EDI 1.0.3 binary does
not contain the checkout's Weibull fix, so it cannot produce valid post-fix
weight/matching evidence. No native comparison or canonical CSV regeneration
was run for this audit; preserve the TODO-5 gate until a current-code native
run, with old/new implementation identities and row-level provenance, is
available.
