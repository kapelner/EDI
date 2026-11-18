## Covered
- Binary (incidence) outcome on the article's 2 x 2 recipe (DesignFixedFactorial for A, then DesignFixedBlocking on A for B), n = 200, plus n = 198 (unequal cells) and n = 40 (zero events in one arm, NA covariates).
- `factors` input validation: 2x2, 3 levels, `list(a=2,b=1)`, unnamed `list(2)`, non-list, character, 2.5, 0.5*4, negatives.
- `get_w_factorial()` before/after assignment, `seed=` reproducibility, `draw_ws_according_to_design()` cell counts on the main-effect design.
- Main-effect classes: IncidRiskDiff, GCompRiskDiff/RiskRatio, CMH, ExtendedRobins, LogRegr (all 3 estimands), ExactFisher, Newcombe, Miettinen-Nurminen, Wald, BinomialIdentityRiskDiff, SimpleAverageDiff; all cross-checked against lm+sandwich / glm / mantelhaen.test / DescTools.
- Bootstrap CI types percentile/studentized/basic/bca and p-value types; jackknife units auto/block/observation; `model_formula = ~ B` and `~ 1`.

## Not reached
- Continuous or count outcome on the 2 x 2 recipe (randomization test should work there; check rand CI with `delta`).
- `prob_T != 0.5` in the B step, `m =` explicit blocks instead of strata_cols, `missingness_method` options, missing responses.
- `InferenceSuite` over the main-effect design; Bayesian bootstrap; `compute_rand_two_sided_pval(type=)` on a Bernoulli design where Zhang is allowed.
- Coverage simulation of the per-factor blocked analysis vs lm with interaction.

## Workarounds
- Binary outcome: no randomization test on these designs (F1); use InferenceIncidExactFisher (`compute_exact_confidence_interval()`, `compute_exact_two_sided_pval_for_treatment_effect()` — the latter name is only in the help Example) or CMH, and `type = "percentile"` bootstraps (default BCa is NA with 2 blocks).
- `model.matrix(glm_fit, newdata)` ignores newdata: build counterfactual matrices with `model.matrix(~ formula, d1)` when hand-checking g-computation SEs.

## Confusing docs
- `?InferenceIncidExactFisher`: lists no exact CI / p-value methods under Methods; method names only discoverable from `capabilities()` and the Example.
- `?InferenceIncidRiskDiff` `compute_rand_two_sided_pval(type=)`: valid values never listed.
- `?DesignFixedBlocking` / `?InferenceRand` refer to "Changed in 1.0.5"/"Before EDI 1.0.5" while installed version is 1.0.4.
- Bootstrap p-value `type` set (`percentile, symmetric, studentized, bootstrap-t, bca`) differs from CI `type` set (adds `basic`, `symmetric-percentile-t`, ...).
- `?DesignFixedFactorial` and the rand-CI error message point to internal `package_metadata/...md` plan files a user cannot read.
