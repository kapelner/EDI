# Summary: ordinal area, EDI 1.0.4 (first run on this area)

## What I set out to do
Analyse a simulated two-arm pain trial with every ordinal inference class the docs offer, the way a careful applied statistician would. The trial has n = 90 patients (37 control, 53 treated via `DesignFixedBernoulli`), a 5-level outcome (1 = none ... 5 = severe), three covariates (age, baseline pain, sex), a strong true effect (latent shift -1.3), and level 5 unused in the treated arm. For each class: report the estimand with CI and p-value, check that the numbers are sane (CI contains the estimate, p in [0, 1]), and cross-check the proportional-odds fit against `MASS::polr` and `ordinal::clm` to 3 digits. Then go beyond the defaults: other links, PPO `nonparallel`, testing types, resampling, alpha/delta, response codings, small n, separation and constant outcomes, and `InferenceSuite`.

## What I finished
- `analysis.R` runs end to end (output in `analysis_output.txt`). It covers:
  - Wald and LR for PO, AdjCat, Cloglog, Probit, Cauchit, ContRatio and Stereotype.
  - PPO with `nonparallel = "base_pain"`.
  - GComp mean-score difference, JT (asymptotic and exact), Ridit, and Wilcoxon/HL.
  - Bootstrap (BCa; percentile for cloglog), randomization p, jackknife and LR parametric bootstrap for PO.
- Every p-value is in [0, 1] and every CI contains its estimate.
- **PO cross-check:**
  - EDI gives -2.06655, Wald CI (-2.99843, -1.13466), p = 1.3838e-05.
  - clm gives -2.06705, CI (-2.99899, -1.13512), p = 1.3786e-05; polr gives -2.06705, SE 0.47550.
  - They agree to 3 significant digits but not to 4 (see F5).
  - EDI's LR CI (-3.03379, -1.16118) and LR p (4.5567e-06) match clm's profile CI and LR test to 5-6 digits.
- **Other links vs clm:** probit -1.18259 vs -1.18260, cloglog -1.10411 vs -1.10376, cauchit -2.28926 vs -2.28959. LR CIs match the clm profile CIs to 4-5 digits.
- **VGAM checks:**
  - AdjCat -1.042564 vs `vglm(acat)` -1.042478.
  - ContRatio -1.58653 vs `vglm(cratio)` -1.586429.
  - PPO -2.061829 equals `vglm(cumulative(parallel = FALSE ~ base_pain))` (sign flipped). The PPO SE is 0.4758 vs VGAM's 0.4723; this looks like observed vs expected information, consistent with the docs.
- **Nonparametric checks:**
  - JT/Ridit estimate -0.2501275 = U/(nT nC) - 1/2.
  - The JT asymptotic p equals `clinfun::jonckheere.test` (5.764e-05).
  - The JT exact p equals my exact conditional computation (2·min one-sided).
  - Wilcoxon equals `wilcox.test`.
  - GComp -0.92423, SE 0.19655 vs my clm + delta-method computation -0.92446, SE 0.19653.
- 12 new findings (F1–F12), each with a repro that I ran in a fresh session.

## What I could not do, and why
- KK/matched-design ordinal classes (`InferenceOrdinalKKCLMM*`, `KKGEE`, `KKGLMM`, `KKCondAdjCatLogitRegr`, `PairedSignTest`) were not run: they need a KK design, which is outside the task's two-arm Bernoulli trial and I ran out of time.
- Stereotype was only run at the defaults; its docs already warn that its LR/score tests are miscalibrated with one binary regressor.
- `compute_lik_ratio_bartlett_exact_*` returns NA with a warning for PO and cloglog. It is not in `get_supported_testing_types()`, so I treated this as expected.
- Randomization CIs are "not implemented for ordinal model-coefficient estimands" (clear error, consistent with `capabilities()`).
- I could not tell which PPO backend (VGAM or clm) actually fitted: `get_mod()` returns NULL for PPO, and no getter reports the backend.

## Places I had to guess
- The sign convention: I assumed positive = higher category for every class (the docs say so for ContRatio and Ridit). It matched clm/VGAM after the documented sign flips.
- For the four classes without a documented `$new()`, I took the ?Inference constructor arguments as applying; F4 shows they don't fully.
- `delta` in `compute_rand_two_sided_pval()` for an ordinal log-odds estimand: I did not find what a shifted sharp null means for an ordinal outcome, so I did not rely on it.
- Bartlett-approx p-values vary between fresh objects unless `set_seed()` is called (4e-6 to 1e-4 with B = 99). With `set_seed(1)` they are reproducible and independent of call order. The docs say the draws come from "this object's own seed", but without `set_seed()` they did not follow the design's `seed = 11`. Too ambiguous to log as a finding; noted in learnings.

## Cross-check packages
MASS, ordinal, VGAM, clinfun and coin were all installed and used.

## Known findings re-checked
None: this is the first run for this area (known_findings.md is empty).
