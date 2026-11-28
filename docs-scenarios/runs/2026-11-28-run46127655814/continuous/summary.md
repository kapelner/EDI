# Summary: continuous outcomes (EDI 1.0.5), first run on this area

## What I set out to do
I analysed a two-arm trial with n = 70, three covariates (age, bmi, sbp) and a continuous outcome with three gross outliers (+25, -20, +30), the way a careful applied statistician would. That meant:
- an unadjusted mean difference;
- covariate-adjusted OLS and Lin (HC2);
- outlier-resistant estimators (robust M/MM, median regression);
- KK matched-pair estimators after a KK matching-on-the-fly design.

Each gets an estimate, a 95% CI and a p-value from the asymptotic, bootstrap and randomization paths. OLS, Lin, quantile and robust were cross-checked against lm + sandwich, quantreg and MASS. Data were simulated with base R and fixed seeds (2026 for the fixed design, 77 for KK21).

## What I finished (see `analysis.R`)
- **Fixed `DesignFixedBernoulli` (38 control / 32 treated)**, run through all eight classes and variants:
  - `InferenceAllSimpleAverageDiff` and `InferenceAllSimpleMeanDiffPooledVar`;
  - `InferenceContinOLS` and `InferenceContinLin`;
  - `InferenceContinRobustRegr` with MM/M × `use_rcpp` TRUE/FALSE;
  - `InferenceContinQuantileRegr` at tau 0.25, 0.5, 0.75 and 0.9.
- **Methods run on those classes:**
  - asymptotic CI and p-value, with `alpha` 0.05 / 0.1 and `delta` 0 / 1;
  - randomization p-value with `delta` and `alternative` two.sided / greater / less, and user `permutations`;
  - randomization CI;
  - nonparametric bootstrap CI (default, percentile, bca, basic) and all 5 bootstrap p-value types;
  - Bayesian bootstrap CI;
  - jackknife SE / CI / p-value;
  - `InferenceSuite` restricted to Wald.
- **Cross-checks, all to at least 4 decimals (max absolute difference 0 at 4 dp):**
  - Welch and pooled t against `t.test`;
  - OLS against `lm`, including `model_formula = ~ age + bmi` and `~ age * bmi + I(sbp^2)`;
  - Lin against `lm(y ~ w * Xc)` + `vcovHC(type = "HC2")`, including `model_formula` and `~ 1`;
  - quantile regression against `quantreg::rq` + `summary(se = "nid")` with a t(n − p) critical value, at all four taus;
  - robust with `use_rcpp = FALSE` against `MASS::rlm` (MM and M);
  - OLS jackknife SE against a manual leave-one-out (1.67265);
  - OLS and Lin randomization distributions with user draws against manual refits (identical).
- **`DesignSeqOneByOneKK21` (29 pairs, 12 reservoir)**, run through nine KK classes: `InferenceAllKKMeanDiffIVWC`, `InferenceContinKKOLSIVWC` / `OneLik`, `InferenceContinKKRobustRegrIVWC` / `OneLik`, `InferenceContinKKQuantileRegrIVWC` / `OneLik`, `InferenceContinKKGLMM` and `InferenceBaiAdjustedTKK21`. I ran the asymptotic and randomization paths, plus options:
  - `tau` 0.25 / 0.75 on the KK quantile classes;
  - `model_formula = ~ age` on the KK OLS classes;
  - `method = "M"`, `start_with_ols` and `use_rcpp = FALSE` on the KK robust classes;
  - `use_rcpp = FALSE` (glmmTMB) on `InferenceContinKKGLMM`.
- **KK cross-checks against manual constructions** from the documented stacked / IVWC descriptions:
  - KK OLS IVWC and OneLik estimates, and the OneLik HC2 SE, match `lm` + sandwich exactly;
  - KK quantile IVWC and OneLik match `rq` + nid exactly, including the CI;
  - KK robust with `use_rcpp = FALSE` matches `MASS::rlm`;
  - KK GLMM (Rcpp) gives −0.02831 against lme4 / glmmTMB ML −0.02530. The profile log-likelihood is identical at both values (−214.0523, flat likelihood, SE 1.23), so I treated it as optimizer tolerance and did not report it.
- **Also checked:**
  - `DesignSeqOneByOneKK14` and `KK21` with `n = NULL`;
  - a null effect at n = 24 with `prob_T = 0.3` (14/10 split) and rounded t3 errors with ties (OLS, Lin and quantile match lm / HC2 / rq);
  - bad inputs: tau 0/1/1.5/−0.2/NA, method "S", w coded 1/2 or logical, NA or Inf response, a missing covariate, B = 3, B = 50 with BCa, r = 30 for the randomization CI, alpha 0 / −0.1 / 1.2.

## Results (fixed design, true effect 2)
| class | est | 95% asymp CI | p |
|---|---|---|---|
| mean diff (Welch) | 2.608 | (−0.444, 5.661) | 0.092 |
| OLS | 3.700 | (1.026, 6.374) | 0.0074 |
| Lin (HC2) | 3.706 | (0.428, 6.984) | 0.027 |
| robust MM (MASS backend) | 2.112 | (1.162, 3.062) | 3.6e-5 |
| median regression | 2.128 | (1.023, 3.232) | 2.8e-4 |

As expected, the outliers pull the mean-based estimators away from 2; the robust and quantile fits stay close to it. Every CI contains its estimate, and every p-value is in [0, 1], apart from the F2 `Inf` bound and the F6 bad-alpha cases.

## New findings (details in findings.md)
- F1: the default C++ "MM" robust backend does not reproduce MASS MM (2.1525 vs 2.1117). This affects the fixed-design robust class and both KK robust classes.
- F2: the KK quantile IVWC randomization CI returns an `Inf` upper bound silently.
- F3: the KK mean-diff IVWC reservoir variance is pooled, which the docs never say; z vs t is delegated to a private method; the KK OLS IVWC df is undocumented.
- F4: the bootstrap `type = NULL` default is undocumented on the method page and differs by class (BCa for OLS, percentile for Lin, robust and quantile).
- F5: `tau = 1` is rejected with the false message "Element 1 is not <= 1".
- F6: the OLS and simple-mean-difference asymptotic CIs accept alpha outside [0, 1] and return inverted or NaN intervals, while sibling classes reject it.
- F7: the quantile-regression jackknife NA warning blames "separation / outcome category".
- F8: a bare-matrix `permutations` argument fails with "$ operator is invalid for atomic vectors".
- F9: four KK continuous help pages document no `$new()` and no `compute_asymp_*`.

## Could not do and why
- The nonparametric bootstrap on KK21 / KK14 errors with "This method is not supported for DesignSeqOneByOne designs.", as the cookbook documents, so there are no bootstrap CIs for the KK estimators.
- I did not cross-check `InferenceBaiAdjustedTKK21` against an external package, because its formula is not on the class page.
- I did not cross-check the missing-covariate imputation, because the imputation rule (`missingness_method = "impute"`) was not read in detail.
- The `InferenceSuite` HTML option tried to open a browser through xdg-open (harmless in CI). I used `screen = FALSE, html = TRUE` only because one of screen/html must be TRUE.
- The context file list mentions `context/articles/`, but that folder does not exist; I used the installed vignettes instead.

## Places I had to guess
- Bootstrap `type = NULL`: the meaning was found through `?get_bootstrap_dispatch_policy` (F4).
- KK stacked design layout for the manual OneLik cross-check: I guessed columns [reservoir intercept (0 for pair rows), treatment (1 for pair rows, w for reservoir), covariate differences / raw covariates]. It matched EDI exactly.
- KK mean-diff IVWC variance: found by trying Welch, pooled and MLE variants (F3).
- Robust Wald df: assumed n − p with a t critical value, from the help text. It matched MASS for `use_rcpp = FALSE`.
- KK constructor arguments (`method`, `use_rcpp`, `start_with_ols`, `model_formula`): passed by trial, because the pages have no usage section (F9).
- I deliberately did not call `formals()` or `args()` on R6 methods, to stay within the no-source rule.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area (first run).
