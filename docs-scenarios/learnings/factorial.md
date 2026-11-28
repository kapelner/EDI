# Learnings: factorial

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

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

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

## Covered
- InferenceSuite on the 2 x 2 main-effect design with `methods = c("wald","exact")` (the default runs 323 rows, ~25 min; always restrict `methods`). `run_all_inference(screen = FALSE, html = FALSE)` errors: one of them must be TRUE.
- Estimand labelling: `get_estimand()`, `get_supported_estimands()`, `set_estimand()` on LogRegr (3 estimands) vs GComp/CMH/RiskDiff (always "conditional"), and the suite's `estimand` column.
- LogRegr marginal SE = delta method with model vcov; GCompRiskDiff SE = delta method with HC0 (both match by hand).
- ExactFisher on DesignFixedBlocking(strata_cols) = `mantelhaen.test(exact=TRUE)`; with `m=` = pooled `fisher.test`.
- `prob_T = 0.3` in the B step, `m =` blocks (+ errors without n / wrong length), `missingness_method` impute/drop_column/error, NA strata value, NA incidence response, unbalanced `w_precomputed`, `n = NULL` with odd n, Bayesian bootstrap, jackknife units incl. `observation_within_block`.
- Coverage sim (300 reps) of RiskDiff/CMH/GComp main effects: 0.93-0.95.

## Not reached
- Continuous or count outcome on the 2 x 2 recipe with rand test and rand CI with `delta` (still untested).
- Main-effect analysis when B was assigned with `prob_T = 0.3` (unequal arms in the B design), and coverage there.
- `equal_block_sizes = FALSE` with unequal cells (n = 198) together with `m =`, and how CMH/ExtendedRobins react.
- `InferenceSuite` `combined_evidence_*` options and `classes=` validation messages.
- `get_procedure_validity()` on the main-effect objects.

## Workarounds
- Interaction: `lm(y ~ A*B + covs)` + `sandwich::vcovHC(type = "HC0")` (RD scale) or `glm` logit; EDI refuses `w` in `model_formula`.
- Fisher with blocks: give the other factor in `X` + `strata_cols`, not `m =`.
- Jackknife on a 2-block design: `unit = "auto"` / `"observation_within_block"`.

## Confusing docs
- `?Inference` `get_estimand()`: "conditional" is a placeholder for "the class default", which is wrong for marginal classes (GComp); the suite uses a different vocabulary (`log_odds_ratio_marginal`, `mean_difference`, `RR`).
- `?InferenceIncidExactFisher`: "per block-defining covariate stratum" quietly excludes `m =` blocks.
- `?Design` `missingness_method = "error"`: "thrown as soon as any missing value is detected", but the design accepts the data and the error fires only at `Inference$new()`.
- The NA-response error points to a web article (`missing-covariates.html`) that is not an installed vignette.
