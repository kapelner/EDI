# Summary: proportion outcomes (EDI 1.0.4), first run for this area

## Goal
The response is each participant's share of the day spent active, a proportion in [0, 1], with a few exact 0s and 1s (9 zeros and 8 ones in n = 150; true logit shift +0.6; age in years and sex as covariates). For each EDI proportion class I wanted:
- an estimate, CI and p-value;
- a statement of which estimand the class reports;
- a cross-check against a standard package to 3+ digits;
- what the class does with the exact 0s and 1s.

## What I finished (`analysis.R`)
Cross-checks, all on the same simulated data:

| EDI class | Reference | Agreement |
|---|---|---|
| `InferencePropFractionalLogit` | `glm(quasibinomial)` + `confint.default` | estimate and CI to 7 digits |
| `InferencePropBetaRegr`, data with 0/1 | `betareg` on the Smithson–Verkuilen-squeezed y | 7 digits; this is how I learned what EDI does (F1) |
| `InferencePropBetaRegr`, interior rows only | `betareg` | estimate to 7 digits; Wald SE to 3 digits (EDI uses observed information, betareg uses expected) |
| `InferencePropBetaRegr`, interior rows only | `lmtest::lrtest`, LR CI by profile with `offset()` | LR p-value and LR CI to 4–5 digits |
| same, score test | observed-information score statistic computed by hand with `numDeriv` | matches (1.80e-22) |
| same, `marginal_mean_diff` | delta method by hand | to 3 digits |
| `InferencePropZeroOneInflatedBetaRegr` | `gamlss(family = BEINF)` | conditional estimate and SE to 6 digits; `marginal_mean_diff` to 6 digits |
| `InferencePropQuantileRegr` (tau 0.25 / 0.5 / 0.75) | `quantreg::rq(method = "fn")`, `summary(se = "nid")`, t(n−p) reference | estimate, CI and p exact |
| `InferencePropGCompMeanDiff` | glm quasibinomial + delta method with HC0 sandwich | estimate, CI and p to 7 digits |

Also exercised:
- **Testing types:** all supported types on beta and ZOIB (wald, score, gradient, lik_ratio, lik_ratio_bartlett_approx).
- **Information preference:** `set_information_preference`.
- **Estimand switching**, including the error when setting a non-Wald test under a marginal estimand.
- **Formulas:** `model_formula` with interactions, `log()`, `I()`, `~ 1` and a misspelled variable; `model_formula_zero_one` with `~1`, `~age`, `~female`. Treatment is always added to the inflation submodels, which matches gamlss with `+ w`.
- **Quantile `tau`:** 0.03 to 0.97 and invalid values.
- **GComp:** `variance_fallback_methods` (empty, single, invalid) and `prob_clip_eps`.
- **Frac logit:** `harden = FALSE` and `estimate_only = TRUE`.
- **Response validation:** y = 1.2, -0.1, NA and 1+1e-12 are all rejected with clear messages.
- **Resampling:** randomization p (reproducible with `set_seed`), bootstrap CI and p, jackknife and Bayesian bootstrap for all 5 classes.
- **Hard data shapes:** n = 20 and 24, null and strong effects, `prob_T = 1/3`, ZOIB on zeros-only, ones-only, no-boundary data and with separation of the zero part.

## What each class does with exact 0s and 1s
- **Fractional logit:** uses them directly, as it should. This matches glm.
- **Beta regression:** silently squeezes *every* y to (y(n−1)+0.5)/n. With boundary data this can flip the sign: here it gave −0.110 against the interior effect of +0.70 (F1).
- **ZOIB:** models them as point masses. It is fine in most cases, but the SE silently comes out NA when one boundary class is empty and a covariate is uncentred (F4).
- **Quantile regression:** silently clamps them to machine epsilon (logit about ±36). At extreme tau this gives absurd, "significant" estimates (F2).
- **GComp:** uses them directly via the fractional-logit working model.

## Not done / could not do
- The `InferenceSuite$run_all_inference` and sequential (KK14) designs from the cookbook: skipped for time.
- The KK proportion classes (`InferencePropKKGEE`, `KKGLMM`, `KKQuantileRegr*`): outside the five classes named in the task; skipped for time.
- `compute_lik_ratio_bartlett_exact_*`: it is not in the supported list for beta/ZOIB, so I did not call it.
- No cross-check package was missing. `betareg`, `quantreg`, `sandwich`, `gamlss`, `lmtest`, `numDeriv` and `glmmTMB` are all installed.

## Guesses and judgement calls
- **Beta transform:** the docs do not define the boundary adjustment. I identified the Smithson–Verkuilen transform by matching `betareg` to 7 digits.
- **Quantile clamp:** I identified `.Machine$double.eps` the same way, by matching `rq`.
- **Fractional-logit p-value:** EDI uses a normal reference (p 0.0419), while `summary.glm` uses t(n−p) (p 0.0437). I judged this a convention (Papke–Wooldridge / statsmodels use z), not a finding. Note that the quantile class does use t(n−p).
- **Optimizer tolerance:** with uncentred age (n = 120, interior data), EDI's beta-regression log-likelihood stopped 1.8e-5 below `betareg`'s optimum. The treatment estimate still agreed to 3 digits (0.5918 vs 0.5917) but the intercept differed in its 3rd digit (0.3298 vs 0.3311). I did not report it as a finding.
- **Non-unique quantile solutions:** for median regression with a non-unique solution, EDI's "fn" answer differs from `rq`'s default "br" answer (0.577 vs 0.530) with no message. The help page does say "fn", so this is not a finding.
- **Assignments:** I used `overwrite_all_subject_assignments()` to fix `w` from base R for the repros. Its name is listed by `names(design)`; I found no help text read for it.

## Known findings re-checked
None: `known_findings.md` lists no earlier findings for this area.
