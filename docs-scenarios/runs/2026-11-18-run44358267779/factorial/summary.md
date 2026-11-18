# Summary: factorial area, 2 x 2 marketing test with a binary outcome (EDI 1.0.4)

## What I set out to do
Test two factors on 200 customers: email subject line (A) and send time (B), with a binary purchase outcome. A careful applied statistician would want: a balanced 2 x 2 randomization (50 per cell); the risk-difference main effect of each factor, averaged over the other factor, with a CI and p-value, preferably design-based (a randomization test that re-randomizes A within B, as the article describes); the A x B interaction with a CI; a clear statement of which estimand each EDI object targets (risk difference vs. conditional log-OR vs. marginal ratio); and cross-checks against `lm`+`sandwich`, `glm`, `mantelhaen.test`, `fisher.test` and `DescTools::BinomDiffCI`.

## What I finished (analysis.R)
- Data: base-R simulation, seed 20261118, covariates age and loyal. True risks are 0.10 + 0.04 loyal + 0.15 A + 0.06 A·B. Observed cell means: (0.08, 0.10 / 0.32, 0.36).
- `DesignFixedFactorial` with the documented 2 x 2 input `list(subject=2, time=2)` errors as the article says. Following the article's recipe: A was assigned with `DesignFixedFactorial(list(subject_line = 2))`, then B with `DesignFixedBlocking(strata_cols = "A")`. Result: 50 in every cell. `draw_ws_according_to_design()` on the main-effect design kept all 200 redraws at 50/50/50/50, which confirms the article's claim. Seed reproducibility (`seed=`) holds.
- Main effects: each is analyzed on `DesignFixedBlocking` with the other factor as stratum and `w_precomputed`.
  - A: RD 0.256 (HC0 Wald CI 0.147 to 0.364, p 3.8e-6); percentile bootstrap 0.151 to 0.370; g-comp RD 0.256 (0.149 to 0.363); CMH 0.250 (0.136 to 0.364); conditional log-OR 1.733; exact stratified Fisher log-OR 1.636 (0.80 to 2.57, p 2.5e-5).
  - B: RD 0.024 (−0.084 to 0.133, p 0.66), with the other classes similar. This is a correct null result.
- Cross-checks, all agreeing to at least 4 digits:
  - InferenceIncidRiskDiff = `lm` + `vcovHC(HC0)` with a z reference.
  - LogRegr = `glm`.
  - LogRegr `marginal_mean_diff`/`marginal_ratio` = manual g-computation with delta-method SE (model vcov).
  - GCompRiskDiff/RiskRatio = the same with `sandwich()`.
  - CMH p = `mantelhaen.test(correct=FALSE)`, and its SE = the documented formula.
  - ExactFisher = `mantelhaen.test(exact=TRUE)`.
  - Newcombe/MN/Wald = `DescTools::BinomDiffCI`.
  - With `model_formula = ~ B`, the RD equals the cell-mean main effect 0.25 exactly.
- Every CI contained its estimate and every p-value was in [0,1], except the F7 case (estimate NA).
- Interaction: the article says no EDI class estimates it, so I used `lm` (HC0) and `glm`. The RD-scale interaction is 0.033 (−0.180 to 0.246, p 0.76); the log-OR scale is −0.003 (p 0.997); the effect-coded LPM gives 0.02 with SE 0.111 (twice the main-effect SE, as the article says).
- What each object targets, per the docs, confirmed against the numbers:
  - RiskDiff: covariate-adjusted RD coefficient. In a balanced 2 x 2 this is the main effect.
  - GCompRD: standardized marginal RD.
  - CMH: unadjusted mean difference with a block-stratified SE.
  - LogRegr: conditional log-OR. This is *not* the RD main effect; use `set_estimand("marginal_mean_diff")` for that.
  - ExactFisher: log common OR across strata of the other factor.
  - Newcombe/MN/Wald: pooled unstratified RD.
- Extra cases: n = 198 (unequal cells; F6); a sparse n = 40 case with zero events in one arm and NA covariates (F7). With separation, the LogRegr and GComp separation warnings fire as documented.

## What I could not do and why
- No randomization p-value or randomization CI for the binary outcome on either design (F1, F2). The article's main design-based route is not available for incidence. I used exact Fisher/CMH/bootstrap instead.
- No jackknife and no default (BCa) bootstrap on the 2-block main-effect designs (F3).
- I tried no Python area and no sequential designs.

## Places I had to guess
- The valid values of `type` in `compute_rand_two_sided_pval(type=)`: none are listed. I tried "Zhang", "Fisher" and "exact".
- How the article's "average over the other factor" maps to a binary outcome: I took the risk-difference scale as the main-effect scale.
- Whether "Changed in 1.0.5" / "Before EDI 1.0.5" notes in `?DesignFixedBlocking` and `?InferenceRand` apply to the installed 1.0.4. The integer-site-code behaviour described as new in 1.0.5 is already present in 1.0.4, so I took the docs to describe this build.

## Known findings re-checked
None. This is the first run for this area (known_findings.md is empty).

## Cross-check packages
`sandwich`, `lmtest`, `DescTools` and `exact2x2` were available; `PropCIs`, `emmeans` and `marginaleffects` are not installed (I did not need them).
