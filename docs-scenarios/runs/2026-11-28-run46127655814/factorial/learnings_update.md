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
