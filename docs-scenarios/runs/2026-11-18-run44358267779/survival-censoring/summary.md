# Summary: survival-censoring (EDI 1.0.4)

## Goal
A careful applied statistician analysing an n = 80 oncology trial of time to progression (randomised with `DesignFixediBCRD`, covariates age and ECOG) would want:
- the hazard ratio (Cox), the time ratio (Weibull AFT) and a model-free contrast (log-rank, RMST, median difference), each with a 95% CI and a p-value;
- censoring handled as recorded: administrative right censoring, events found only between scans (interval censoring), and events known only to have happened before a first assessment (left censoring, `y_L = 0`);
- agreement with `survival`, `icenReg` and `interval` to 3 digits;
- randomization and bootstrap inference that is reproducible from a seed.

Data: simulated with base R (`set.seed(20261118)`, Weibull shape 1.3, true log time ratio 0.5). Mixed data set: 51 exact, 21 right-censored, 4 interval-censored, 4 left-censored. For the right-censored-only analyses I used a copy where the interval- and left-censored subjects get their true times. The data are saved to `trial_data.csv`.

## What I finished (all in `analysis.R`)
- **Recording.** I entered responses with `add_all_subject_responses(ys, y_Ls, y_Rs)` on cloned designs, and per subject with `add_one_subject_response()` on a sequential Bernoulli design (mixed censoring, including left-censored `y_L = 0`). For the `(X, y, dead)` layout I used `fast_coxph_regression()` and `fast_weibull_regression()`.
- **Input validation.** I tested 12 malformed inputs: `y_L > y_R`, `y_L == y_R`, negative or infinite `y_L`, a lone bound, `y` together with bounds, `NaN`, `y = Inf`. All were rejected with clear messages. `y = 0` is accepted (see F3).
- **Right-censored cross-checks:**
  - Cox log HR −0.6413 (HR 0.527), with Wald, LR and score CIs and p-values: all match `coxph(ties = "breslow")` to 6 digits, including Wald `delta = 0.3`.
  - Weibull log time ratio: default 0.47766 vs survreg 0.47718 (F1). With `newton_raphson` the two are identical. LR p matches.
  - Log-rank p 0.017305: matches `survdiff`. The martingale-residual difference matches `coxph(~1, ties = "breslow")` residuals.
  - RMST difference (default tau = 15.12 and tau = 12): estimate, CI and p match `survfit(rmean = )` exactly.
  - KM median difference 5.47: matches `survfit`.
  - `fast_coxph_regression` matches `coxph`.
- **Mixed-censoring cross-checks:**
  - Weibull: matches `survreg(type = "interval2")` with `newton_raphson`; the default L-BFGS is slightly off (F1). Score-test p (0.0024861) matches my own numerical score test (0.0024858). LR p matches.
  - Cox (icenReg path): the estimate matches `ic_sp` to 6 digits. The SE is a random icenReg bootstrap (F9).
  - Sun log-rank: estimate and p match `interval::ictest`. Gehan-Wilcoxon p matches `ictest(scores = "wmw")`.
  - Turnbull RMST (tau = 12 and default tau) and median difference: match my own `icfit`-based calculation.
- **Resampling.**
  - Randomization p-values for Cox, Weibull, log-rank, KM and RMST, including Weibull with `delta = 0.47` (p 0.76).
  - Weibull randomization CI on interval-censored data, which contains the estimate.
  - Nonparametric bootstrap (percentile and BCa) and the Bayesian bootstrap. The Bayesian bootstrap is refused on interval-censored data, as documented.
  - Randomization CIs are refused for Cox, RMST and KM, as documented.
  - Parametric LR bootstrap is refused for interval-censored Weibull, as documented.
- **Class acceptance.** The interval-censored class list matches the article: StratCox and DepCens refuse at construction.
- **InferenceSuite** on right-censored and mixed data (F8).

## Results reported (mixed-censoring data, the realistic analysis)
| Estimand | Estimate | 95% CI | p |
|---|---|---|---|
| log HR, Cox (icenReg; SE random, F9) | −0.601 | (−1.22, 0.018) in the final run | 0.057 (0.044 in another run) |
| log time ratio, Weibull (Newton) | 0.473 | (0.126, 0.820) | 0.0075 |
| Sun log-rank score difference | −0.409 | (−0.775, −0.043) | 0.0287 |
| RMST difference, tau = 12 months | 1.95 months | BCa (0.048, 3.52) | randomization 0.020 |
| Median difference (Turnbull) | 4.36 months | bootstrap (1.89, 8.82) | randomization 0.020 |

## What I could not do / skipped
- `survRM2` is not installed. I cross-checked RMST against `survival::survfit(rmean = )` and against my own Turnbull integration instead.
- I did not check the Bartlett-corrected and parametric-bootstrap LR intervals against a reference, or the frailty and KK survival classes.
- I did not run a size or coverage simulation.

## Places I had to guess
- Which optimizer names `set_optimization_alg()` accepts for the Weibull class. They are not listed anywhere; I used `"newton_raphson"` from `?fast_weibull_regression`.
- Where the `dead` layout fits: the task brief mentions it, but the user-facing `Design` API has only `y`/`y_L`/`y_R`. The notation glossary says `dead` belongs to the backend layer, so I exercised it through `fast_coxph_regression` and `fast_weibull_regression`.
- The sign convention of the Sun log-rank estimate. EDI = −(ictest estimate): `ictest` reports group 0 minus group 1, and EDI reports treated minus control.
- Whether the article's "BCa needs B of at least 501" is a hard rule. RMST BCa at B = 199 returned an interval with no warning, while Cox BCa at B = 199 returned NA with a warning. I treated the sentence as advice, not a rule, and did not log it.
- A second issue I did not log as a finding: on my mixed data, after `set_optimization_alg("newton_raphson")`, the Weibull score and gradient p-values were NA (warned: "null-restricted refit ... failed"), while L-BFGS gave a correct score p. It did not reproduce on the article's data, and the optimizer value is undocumented, so I left it out.

## Known findings re-checked
None: this is the first run on this area (known_findings.md is empty).
