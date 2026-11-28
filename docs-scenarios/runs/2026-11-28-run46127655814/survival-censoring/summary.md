# Summary: survival-censoring (2026-11-28, EDI 1.0.5 as reported by `packageVersion`)

## Goal
I analyzed an 80-patient two-arm oncology trial with time to progression as the outcome, using a `DesignFixediBCRD` design with covariates age and a 3-level ECOG factor. The data are simulated with base R and a fixed seed. A careful applied statistician wants three things here:
- A hazard ratio (Cox), a time ratio (Weibull AFT) and a model-free contrast (RMST, KM median difference, log-rank), each with a 95% CI and a p-value.
- Correct handling of every censoring type, without imputing midpoints.
- The chosen test (Wald vs LR vs score) actually used.
- Agreement with `survival` and the interval-censored reference packages.

## What I finished (`analysis.R`)
- **Layout 1 (exact + right-censored, 67 events / 80, tied times):**
  - Cox: Wald and LR, CI and p.
  - Weibull: Wald and LR.
  - RMST with prespecified `tau = 18`.
  - KM median difference: the MOVER CI, checked by hand.
  - Log-rank chi-square and the Peto-Prentice test.
  - Randomization p-values, and `fast_coxph_regression(X, y, dead)` (the "dead" layout).
  - All match `coxph` / `survreg` / `survfit` / `survdiff` to 5+ significant digits. Profile-likelihood CIs were computed by hand with `uniroot`.
- **Layout 2 (57 exact, 13 right, 7 interval, 3 left with `y_L = 0`):**
  - Weibull Wald/LR matches `survreg(type = "interval2")` exactly, now with the default L-BFGS too.
  - The Cox estimate matches `icenReg::ic_sp`.
  - The Sun log-rank matches `interval::ictest` exactly.
  - RMST uses a Turnbull bootstrap percentile CI.
- **Also exercised:**
  - All Cox testing types vs `coxph` (score test at the restricted fit, LR at `delta = -0.5`).
  - Weibull score and gradient tests vs a hand-computed observed-information score / gradient statistic (match).
  - `model_formula` (`~age`, `~ecog`, `~age*ecog`, `~1`, `~log(age)+I(age^2)`) on Cox and Weibull vs `coxph` / `survreg` (match).
  - `missingness_method` = `"drop_column"` / `"impute"` / `"error"`, and `include_is_missing_as_a_new_feature`.
  - A null-effect `DesignFixedBlocking` on ECOG: following the error's advice `equal_block_sizes = FALSE` worked. StratCox matches `coxph(... + strata(ecog))`.
  - Bartlett exact/approx/best-available and the parametric LR bootstrap for Cox and Weibull, plus the parametric-bootstrap refusal on interval-censored data.
  - `coin::logrank_test` Peto-Prentice vs EDI Gehan p (0.01018 vs coin's permutation-asymptotic 0.01022; `survdiff(rho = 1)` is exact).

## New findings (see findings.md)
- **F1:** the Weibull `compute_asymp_*` ignores `set_testing_type()`. It always returns the Wald result, which can flip the 5% decision: Wald p = 0.054 while the LR p = 0.0499.
- **F2:** the Weibull and DepCens help pages have lost the `$new()` and core-method docs, and contain developer-internal text. The Cox `$new()` entry also has a developer note.
- **F3:** the Bartlett NA warnings give a false reason ("refit returned non-finite"), and an error points to `supports_bartlett_likelihood_ratio_*()` methods that do not exist.

## Could not do / not reached
- `InferenceSuite` (known F8) was not re-run, to save time.
- I did not try the frailty, KK or DepCens classes beyond the interval-censoring refusal.
- The Weibull Bartlett-approx p (6.1e-4 vs LR 1.4e-4 on the first data set) has no reference package, so I could not check it.
- The KMDiff asymptotic p-value has no simple reference (the CI was checked by hand).
- The interval-censored Cox SE is a bootstrap SE in both EDI and icenReg (EDI 0.294 vs icenReg `bs_samples = 200` 0.343), so I could not compare them to 3 digits. The number of bootstrap samples EDI uses is still undocumented.
- `survRM2` is not installed. RMST was checked against `survfit(rmean = tau)` instead.

## Guesses
- **Weibull constructor arguments:** undocumented (F2). I assumed the `?Inference` `$new()` arguments.
- **The estimand behind `compute_asymp_two_sided_pval()` for LogRank and Gehan:** the method docs say it is a Wald test on the martingale-residual difference. So I compared the dedicated `compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` to `survdiff`, and EDI's Gehan asymp p (which equals `survdiff(rho = 1)`) directly.
- **KM MOVER reference:** built from `survfit`'s default log-transformed median CIs, as the help page states.

## Known findings re-checked
- `ds-survival-censoring-44358267779-f1` (closed): fixed in substance. The default L-BFGS Weibull now agrees with `survreg` to 4 significant digits (0.6516151 vs 0.6516036 on a treatment-only fit; on full models it agrees exactly). Newton-Raphson is exact.
- `ds-survival-censoring-44358267779-f2` (closed): fixed. `fast_weibull_regression(use_rcpp = FALSE)` with an empty column name now returns coefficients.
- `ds-survival-censoring-44358267779-f3` (filed): still reproduces. An exact time of 0 gives Weibull estimate and p = `NA` with no warning.
- `ds-survival-censoring-44358267779-f4` (closed): fixed. The KMDiff right-censored asymp p is finite (6.7e-4).
- `ds-survival-censoring-44358267779-f5` (filed): still reproduces in its current form. The interval-censored Cox lists score/gradient/lik_ratio in `get_supported_testing_types()`, but `compute_asymp_two_sided_pval()` after `set_testing_type("score")` errors ("not supported for left-/interval-censored survival data ...").
- `ds-survival-censoring-44358267779-f6` (filed): still reproduces. The StratCox and DepCens refusals say "see interval_censored_survival_response.md".
- `ds-survival-censoring-44358267779-f8` (closed): not re-checked this run.
- `ds-survival-censoring-44358267779-f9` (closed): fixed. The interval-censored Cox Wald p is identical under different global RNG states after `set_seed(5)`.
- `ds-survival-censoring-44358267779-f7` (dismissed): not re-argued.
