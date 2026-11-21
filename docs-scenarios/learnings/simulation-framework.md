# Learnings: simulation-framework

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- Continuous outcome, n = 50, `DesignFixediBCRD` and `DesignFixedBinaryMatch` × `InferenceAllSimpleMeanDiffPooledVar`, `InferenceContinOLS`, `InferenceContinKKOLSOneLik`, betaT = c(0, 0.8), 1000 reps on 2 cores in under a minute; the hand-rolled iBCRD cell agrees.
- All eight `inference_types_and_params` names (boot percentile, rand_ci, rand_pval with `r_rand`/`B_boot` 199) at 150 reps, about 50 s on 2 cores.
- `Nrep_Y_w`, `n` vector, `X_mat`, `random_X_draws = FALSE`, report-from-file, report `alpha` override, resume, `custom_apply_treatment_and_noise`, `make_estimand_fn`, bad-input validation for alpha/betaT/Nrep_W/p/sd_noise.
- Incidence built-in DGP with Newcombe and G-comp risk differences (F10).

## Not reached
- `custom_dgp`; sequential designs (KK21, Efron) in the framework; survival (`prob_censoring`), count, ordinal, proportion response types; `save_model_control_fits` output; `reuse_cache = FALSE`; `inference_classes_and_params = NULL` / `design_classes_and_params = NULL` defaults (probably slow).
- Whether F4/F5 also affect cache-job seeds (`seed + 1000003 + job_idx`) and `Nrep_Y_w > 1`.
- Whether other risk-difference / marginal-effect classes (e.g. `InferenceIncidRiskDiff`, count/survival marginal estimators) are also scored against the raw betaT as in F10.

## Workarounds
- Record what a replication drew: return an extra field from `custom_replication_data_generator` and echo it through `make_estimand_fn` (it shows up as `true_estimand` in `get_results()`). This works at `num_cores > 1`, where `keep_all_intermediate_data` is not allowed.
- Use `SimulationFrameworkReport$new(sim)$get_errors()`; `sim$get_errors()` does not exist.
- Inference objects use `compute_estimate()` (not `compute_treatment_estimate()`); asymp p-values and CIs of MeanDiffPooledVar and ContinOLS are t-based (they match `t.test` and `lm`).

## Confusing docs
- `?SimulationFramework` mentions an "is_mean_diff gate" for the default ground truth but never says which classes pass it or what truth the others get.
- `simulation_mode` column in results/summaries is not documented.
- `vignette("notation-glossary")` hook row contradicts `?SimulationFramework` on the w encoding (F1).
- `?SimulationFramework` does not say whether `y_linear_model` returned by a custom generator is on the link scale for non-continuous responses.
