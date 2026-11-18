## Covered
- `add_all_subject_responses(ys, y_Ls, y_Rs)` with mixed exact/right/interval/left (`y_L = 0`) data; `add_one_subject_response()` on `DesignSeqOneByOneBernoulli`, including overwrite (warns) and a lone `y_L` (error).
- Validation of 12 malformed response inputs: all rejected clearly except `y = 0` (F3).
- `des$clone(deep = TRUE)` before adding responses gives two designs with identical `w`: one right-censored, one interval-censored.
- Cox (Wald/LR/score, `delta`), Weibull, LogRank, KMDiff and RMST (`tau` default and user-set) vs `survival`, all matching except Weibull with L-BFGS (F1).
- Interval-censored path: Cox vs `icenReg::ic_sp`; LogRank and GehanWilcox vs `interval::ictest`; RMST and median vs hand-integrated `icfit` (all match). Weibull vs `survreg(type = "interval2")`.
- Weibull score test on interval-censored data vs a hand-computed numerical score test (matches).
- Randomization p (including Weibull `delta`), Weibull randomization CI on interval-censored data, bootstrap pct/BCa, Bayesian-bootstrap refusal, randomization-CI refusals.
- `fast_coxph_regression(X, y, dead)` and `fast_weibull_regression(y, dead, X, use_rcpp = TRUE/FALSE)`.
- `InferenceSuite` on right-censored and interval-censored designs (F8).

## Not reached
- Bartlett-corrected LR (`compute_lik_ratio_bartlett_*`) and the parametric LR bootstrap CI on right-censored Cox/Weibull vs a reference.
- Frailty/GLMM Weibull and KK survival classes; `InferenceSurvivalDepCensTransformRegr` vs a reference.
- `model_formula` with factor covariates, and missing covariates, on survival designs.
- Blocking designs with survival (RMST SE conservativeness claim).
- Small-n coverage of the interval-censored Cox SE (icenReg bootstrap); how many `bs_samples` EDI uses is undocumented.
- Recheck whether Newton-Raphson Weibull score/gradient NA on interval-censored data ("null-restricted refit failed") reproduces on other seeds.

## Workarounds
- Weibull: `inf$set_optimization_alg("newton_raphson")` gives exact `survreg` agreement (F1).
- KMDiff p-value NA: use `compute_bootstrap_two_sided_pval(na.rm = TRUE)` or the randomization p (F4).
- `survreg` interval2 coding of EDI data: `Surv(ifelse(y_L == 0, NA, y_L), ifelse(is.infinite(y_R), NA, y_R), type = "interval2")`, with exact times as L = R.
- `InferenceSuite$run_all_inference(screen = FALSE, plots = FALSE)` errors ("at least one of `screen`/`html` must be TRUE"); use `screen = TRUE`.
- Interval-censored Cox Wald results depend on the global RNG: call `set.seed()` before the first `compute_asymp_*` call (F9).

## Confusing docs
- `?InferenceSurvivalCoxPHRegr` and `?Design` (`applicable_inference_class_names`) talk about `testing_type = "wald"` as if it were a constructor argument; it is set with `set_testing_type()`, which neither page names.
- `?Inference` `set_optimization_alg`: "Valid values are configured by the concrete inference class", but no class page lists them.
- The article says "BCa needs B of at least 501", yet RMST BCa at B = 199 returns an interval silently while Cox BCa at B = 199 returns NA with a warning.
- `?InferenceSurvivalRestrictedMeanDiff` says RMST uses "trapezoidal integration of the step-function KM curve", yet the results equal `survfit`'s exact step-function area (rectangles). The wording is misleading, not the numbers.
- The task's "dead" layout appears only in backend functions and the notation glossary, not in the `Design` API.
