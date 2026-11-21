# Summary: incidence (binary outcomes), EDI 1.0.4

## Goal
A vaccine trial, n = 150, infection yes/no, with infections rare on vaccine. A careful applied statistician would want:
- the risk difference (Wald, Newcombe, Miettinen-Nurminen, covariate-adjusted LPM/g-computation)
- the odds ratio (exact conditional Fisher, logistic Wald/score/LR)
- the relative risk (log-binomial, modified Poisson, g-computation)

each with estimate, CI and p-value, exact methods where offered, every number cross-checked against a standard package, and a sensible response from each class when one arm has zero events.

## Data (decisions logged)
- All data simulated with base R and fixed seeds: `set.seed(2026)`, age ~ N(45, 12), female ~ Bern(0.5). I never used EDI to generate data.
- Main design: `DesignFixediBCRD` (complete randomization, 75/75, `seed = 1`). Infection risk was 0.03 on vaccine vs 0.18 on placebo, which gave 2/75 vs 14/75 (scenario A).
- Zero-cell scenario B: same subjects, with the vaccine arm's infections set to 0 deterministically (`y[w == 1] = 0L`, giving 0/75 vs 14/75). I forced the zero instead of searching for a seed so the scenario is exact and reproducible.
- `InferenceIncidExactZhang` refuses iBCRD and `InferenceIncidExactFisher` refuses Bernoulli designs, so I also ran:
  - a `DesignFixedBernoulli` (`prob_T = 0.6`, unequal arms 81/69, with and without a zero cell) for Zhang
  - a `DesignFixedBinaryMatch` (75 pairs, with and without a zero cell) for the exact McNemar-type class, the stratified Fisher/MH test and the KK classes.

## What I finished (all in `analysis.R`; every check prints MATCH)
- **Risk difference.** Wald (estimate, CI, p, `delta = -0.05`), Newcombe (CI vs `DescTools` "score"; the p-value from inverting the CI matches a uniroot on DescTools to 6 digits), Miettinen-Nurminen (CI at alpha 0.05/0.10 vs `DescTools` "mn"; p at `delta = -0.05` 0.020548 vs 0.020557), LPM with HC0 (vs `lm` + `sandwich::vcovHC`), GComp RD (vs hand-coded g-computation + sandwich delta method), jackknife SE (vs hand jackknife), bootstrap CI. All match to 4 or more digits, on both scenarios.
- **Odds ratio.**
  - Exact Fisher: CI at alpha 0.05/0.10/0.01, p at delta 0, log 0.5, log 0.2, -1. All identical to `fisher.test` and `exact2x2`.
  - Logistic regression: Wald CI vs `confint.default`; LR CI vs MASS profile `confint` (-4.1206/-0.8832 vs -4.1207/-0.8832); LR and score (Rao) p vs `anova(glm)`; Wald/LR at `delta = -1` vs an offset glm.
  - Probit: vs glm. KK conditional logit: vs `survival::clogit` with covariates (exact match).
  - Stratified Fisher on matched pairs: vs `mantelhaen.test(exact = TRUE)` (exact match).
  - Zhang: CI vs `exact2x2`/`exactci` minlike, agreeing to 3 significant digits.
  - ExactBinomial: vs `binom.test` and `mcnemar.exact`, including its documented "central" p-value at `delta != 0`.
- **Relative risk.** Modified Poisson (vs glm Poisson + `sandwich`), log-binomial (vs `glm(binomial("log"))`), GComp RR (vs hand g-computation + sandwich delta method), `LogRegr` `estimand = "marginal_ratio"`/`"marginal_mean_diff"` (vs delta method with model vcov). All match.
- **Zero cell.** Ran every applicable class on iBCRD, Bernoulli and matched-pair zero-cell data. Recorded estimate/CI/p, warnings and `get_nonestimable_reason()` (findings F2, F3, F4, F6).
- **Other options and methods.** Testing types (wald/score/gradient/lik_ratio/lik_ratio_bartlett_approx/bartlett_exact), `set_seed` reproducibility of Bartlett-approx, `combination_method` Fisher/Stouffer/min_p for Zhang, `pval_epsilon`, bad `alpha`/`type` inputs, nonparametric bootstrap (BCa, then percentile as the warning advised), parametric bootstrap, randomization p-values (iBCRD and Bernoulli), `InferenceSuite$run_all_inference()` on both scenarios.
- **iBCRD rounding claim** (`n = 21`, `prob_T = 0.5` gives 10 treated): confirmed.

## Findings (10 new, see findings.md)
- F1: inconsistent risk-ratio scale across classes
- F2: log-binomial silent NA on zero cell
- F3: modified Poisson gives p = 0 and a narrow CI at -22 with no warning
- F4: Fisher estimate silently NA on zero cell
- F5: Bartlett-exact NA with a "no error message was recorded" warning, and a contradictory `testing_type` list
- F6: KK conditional-logit classes silent NA on zero-cell pairs
- F7: "Use Zhang method" error, and following it gives a false "only for incidence outcomes" error
- F8: parametric bootstrap uses separated replicates (sign-flipped bias correction, CI upper bound +21, `n_extreme = 0`)
- F9: InferenceSuite drops the valid exact Fisher result on zero cell but keeps p = 0 separated fits; per-estimand p = NA for single-inference groups
- F10: Wald and RiskDiff help pages list constructor arguments `$new()` rejects

## What I could not do / did not reach
- No exact or score-based CI for the RR or RD is offered (only the OR has exact methods), so I couldn't compare "exact RR" or "exact RD" (e.g. `exact2x2::uncondExact2x2` / Chan-Zhang) against EDI.
- Randomization tests and randomization CIs on iBCRD: refused (F7; the CI says it is "temporarily disabled ... 2026-08-27"). On Bernoulli the default randomization p-value worked (0.01001 with r = 999), but I had no external reference for its draw mechanism.
- `compute_lik_ratio_bootstrap_*` (parametric LR calibration), Bayesian bootstrap, m-out-of-n and subsampling were not run, for lack of time.
- I did not check the gradient-test p/CI and the Bartlett-approx factor against an outside package (none installed).
- `InferenceIncidCMH`/`ExtendedRobins` on real blocked designs were not run, only on iBCRD and matched pairs. On pairs, ExtendedRobins is anti-conservative, as its help page documents.
- No cross-check package was missing for what I ran: exact2x2, exactci, DescTools, sandwich, MASS, survival and coin are installed.

## Places I had to guess
- What `type` values the inherited exact/randomization methods accept: the class help pages don't list the inherited `compute_exact_*` arguments, so I read their signatures with `formals()` (argument names and defaults only, no bodies).
- Whether `InferenceIncidGCompRiskRatio`'s `delta` is on the ratio or the log scale. The doc says "Defaults to 0 for RD and 1 for RR", but the formal default is `NULL`. I confirmed by testing that `delta = 1` equals the default.
- Whether `pval_epsilon` matters for `InferenceIncidExactFisher`'s exact CI. It doesn't: results were identical for 0.5, 0.005 and 1e-6, because fisher.test's CI is used directly. This isn't stated on its page.
- The suite's estimand label "logodds marginal" for `InferenceIncidLogRegr`, whose own default estimand is "conditional". I left this as a docs-confusion note rather than a finding.

## Known findings re-checked
None. This is the first run for this area (`known_findings.md` is empty).
