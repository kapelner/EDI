## Covered
- Cox all four testing types vs `coxph` (Wald, hand-rolled profile LR CI, score at the restricted fit, LR at `delta = -0.5`), with a 3-level factor covariate. All exact.
- Weibull score/gradient vs a hand-computed observed-information score and gradient statistic (exact). `get_supported_information_preferences()` is `auto`/`observed` (it resolves to observed).
- `set_testing_type()` dispatch through `compute_asymp_*`. It works for Cox but not for Weibull (F1).
- Bartlett exact / approx / best-available on Cox and Weibull (F3). Parametric LR bootstrap p for Cox and Weibull (both return 2/(B+1) for a strong effect). Weibull parametric-bootstrap refusal on interval-censored data (clear message).
- `model_formula` variants (`~age`, `~ecog`, `~age*ecog`, `~1`, `~log(age)+I(age^2)`) on Cox and Weibull vs references. All match.
- `missingness_method` `"drop_column"` (drops the column; matches `coxph` without it), `"impute"`, and `"error"` (clear message, raised at inference construction, not at `add_all_subjects_to_experiment`).
- `DesignFixedBlocking(strata_cols = "ecog", equal_block_sizes = FALSE)` with a null effect: Cox, StratCox (auto-strata = `coxph(strata(ecog))`), RMST asymptotic / bootstrap / randomization, LogRank.
- KMDiff MOVER CI reproduced by hand from `survfit`'s Brookmeyer-Crowley limits.
- `InferenceSurvivalGehanWilcox` estimate = mean of S(t-)·martingale residual (reproduced by hand); p = `survdiff(rho = 1)`.
- LogRank estimate = mean martingale-residual difference using Breslow/Nelson-Aalen (not coxph's default Efron).

## Not reached
- `InferenceSuite` (F8 recheck); frailty, KK and DepCens classes on right-censored data.
- A reference for the Weibull Bartlett-approx p-value (e.g. a parametric simulation of E[LR] by hand).
- The KMDiff asymptotic p-value formula (undocumented how it is formed from the lopsided MOVER interval).
- Weibull `compute_lik_ratio_bootstrap_confidence_interval()` and `compute_rand_confidence_interval()` on right-censored data with covariates.
- Sequential designs with `add_one_subject_response()` mixing censoring types; small n (< 30) with many ties.

## Workarounds
- For Weibull LR/score/gradient, call `compute_lik_ratio_*` / `compute_score_*` / `compute_gradient_*` directly. `compute_asymp_*` is always Wald (F1).
- `get_covariates()` reports the design's covariates even when `model_formula` selects fewer, so check `model_formula` effects against the reference fit instead.
- `DesignFixedBlocking` with a factor stratum: unequal strata need `equal_block_sizes = FALSE`, exactly as the error says.

## Confusing docs
- `?Design` documents `include_is_missing_as_a_new_feature = FALSE`, but every concrete design (`DesignFixediBCRD`, `DesignFixedBlocking`, `DesignSeqOneByOne*`, ...) defaults to `TRUE`. So `"impute"` silently adds an `age_is_missing` column, and the argument's only description is "Flag for missingness indicators".
- The `?InferenceSurvivalLogRank` description says "The p-value uses the classic log-rank score statistic", but `compute_asymp_two_sided_pval()` is a Wald test on the martingale-residual difference (0.001423 vs `survdiff`'s 0.001599). The log-rank p is `compute_asymp_log_rank_two_sided_pval_for_treatment_effect()`. The method entry says this, the class description does not.
- `?InferenceSurvivalRestrictedMeanDiff` and `?InferenceSurvivalLogRank` describe behaviour "before EDI 1.0.6" and cite internal TODO ids (v1.0.6-TODO-380, -417), while `packageVersion("EDI")` reports 1.0.5.
- `?InferenceAsympLik` says `get_supported_testing_types()` governs `set_testing_type()`, but Cox lists no Bartlett type and Weibull lists only `lik_ratio_bartlett_approx`, while all six `compute_lik_ratio_bartlett_*` methods exist on both objects (the unsupported ones return NA with a misleading warning, F3).
