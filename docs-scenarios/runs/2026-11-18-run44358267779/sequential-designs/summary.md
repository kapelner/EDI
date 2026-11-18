# Summary: sequential-designs (EDI 1.0.4), first run on this area

## Goal
A clinic enrolls patients one at a time over about a year (60 patients, one every ~6 days). Two baseline covariates are known at arrival (age, severity). The outcome is continuous, measured 6-10 weeks later, and three outcomes arrive about 4 months late. A careful applied statistician would want:
- a covariate-balancing sequential design;
- a reproducible, auditable allocation;
- outcomes recorded whenever they arrive;
- a pre-planned interim look and a final analysis, each with estimate, 95% CI and p-value, cross-checked against standard software.

## What was done (analysis.R, output in analysis_output.txt)
- **Designs:** the same arrival/outcome event stream (seed 20261118, design seed 7041) was run under Efron, Atkinson, KK14 and KK21, all with n = 60. Atkinson was also run with n = NULL.
- **Interim look (at the 40th enrollment, 29 outcomes in):** the live design refuses inference ("This experiment is incomplete as all n subjects haven't arrived yet."). The docs say plainly that there is no interim analysis or stopping rule. So I ran the interim as a complete-case OLS on an analysis-only `DesignFixedBernoulli` (the article's workaround), asymptotic only:

  | Design | Estimate | 95% CI | p |
  |---|---|---|---|
  | Efron | 0.885 | [0.108, 1.663] | 0.027 |
  | Atkinson | -0.129 | [-0.808, 0.550] | 0.70 |
  | KK14 | -0.201 | [-0.877, 0.474] | 0.54 |
  | KK21 | 0.191 | [-0.568, 0.950] | 0.61 |

- **Final analysis (true effect 0.6):**

  | Design | Method | Estimate | 95% CI | p | Randomization p (r = 500) |
  |---|---|---|---|---|---|
  | Efron | OLS | 1.061 | [0.587, 1.535] | 3.7e-5 | 0.004 |
  | Atkinson | OLS | 0.154 | [-0.315, 0.622] | 0.51 | 0.56 |
  | KK14 (26 pairs, 8 reservoir) | KKOLSOneLik | 0.248 | [-0.311, 0.806] | 0.37 | 0.65 |
  | KK21 (23 pairs, 14 reservoir) | KKOLSOneLik | 0.321 | [-0.210, 0.852] | 0.23 | 0.38 |

  KK14's KK21-style randomization CI was [-0.525, 0.683]. The four designs give different allocations of the same patients, so their estimates differ by chance (SE ≈ 0.24-0.27); every CI covers 0.6.

- **Cross-checks:**
  - InferenceContinOLS vs `lm()`: identical to 4+ digits.
  - KKOLSOneLik (adjusted and `~ 1`) vs a hand-built stacked OLS with `sandwich::vcovHC(type = "HC2")`: same estimate and SE. EDI's CI/p use t with the residual df, not z.
  - InferenceAllKKMeanDiffIVWC vs the article's inverse-variance formula (pooled reservoir variance): matches to 4 digits.
  - InferenceContinKKGLMM vs `lme4::lmer` (ML): SE 0.2300 vs 0.2300, estimate 0.2202 vs 0.2215. lme4 reports a singular (boundary) fit, so I did not call this a finding.
- **Docs promises tested:**
  - Seed reproducibility: holds.
  - Other RNG use between assignments changes the allocation, and the seeded constructor resets the session RNG: both happen, as documented.
  - The article's save/restore of `.Random.seed` reproduces the uninterrupted allocation exactly for Atkinson, KK14 and KK21, pairs included.
  - KK21's allocation depends on outcome timing and KK14's/Atkinson's does not: holds. KK21 starts weighting at subject 22 (just after burn-in, 21).
  - Every KK pair has one treated and one control.
  - The bootstrap on a sequential design errors as documented.
  - "Overwriting previous response" warning: present.
  - `weighted_coin_prob` validation and the p = 1 deterministic limit: hold.
  - `prob_T` is not accepted by Efron, Atkinson or KK14: holds.

## Findings (findings.md)
- F1: with `n = NULL`, nothing can be analyzed ("argument is of length zero" from `check_experiment_completed()` and from every Inference constructor).
- F2: KK14/KK21 accept `n = NULL`, then fail at the 5th assignment with "missing value where TRUE/FALSE needed" and leave the design inconsistent.
- F3: KK `lambda` / `t_0_pct` outside [0, 1] are accepted; the error only comes mid-trial, as base-R messages.
- F4: InferenceContinKKGLMM's parametric bootstrap has a replicate SD of ~0.003 against a model SE of 0.23, giving a far too narrow CI and p = 0.01.
- F5: `InferenceSuite$run_all_inference(max_secs_per_class=, num_cores = 2)` loses all results with "arguments imply differing number of rows: 1, 0".
- F6: with `n = NULL`, out-of-order outcomes are refused with the false message "subject that has not yet arrived".

## Could not do / why
- Run a KK design with n = NULL (F2), or analyze any n = NULL design with EDI's own inference on the design (F1). I used an analysis-only design instead, which gives asymptotic results only.
- Run a true interim analysis on the live design: by design EDI has none. I used the complete-case workaround; for KK designs this drops the pair structure.
- No full InferenceSuite results object from the first 13-class run (F5). The printed table was inspected instead (suite_out.txt).

## Guesses / decisions
- Interim timing (40th enrollment) and the "late" subjects (5, 17, 33, +120 days) were my own choices.
- For n = NULL I buffered outcomes and entered them in enrollment order (F6 workaround).
- I treated the "ignoring SIGPIPE signal" CI-failure messages in InferenceSuite as an artifact of my piping output to `grep`, not as an EDI finding.
- I did not file the 0.6% GLMM-vs-lme4 estimate difference, because the fit is at a boundary.
- I did not file arrivals with a missing covariate column being silently imputed; the docs describe imputation of missing covariates.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area.
