# Learnings: inference-suite

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- Count outcome, `DesignFixediBCRD` (60/60), n = 120, NB-overdispersed counts, 2 covariates. 11 applicable classes; `unavailable_due_to_missing_packages` was empty. Suite class list equals `des$applicable_inference_class_names()`.
- Full default `run_all_inference()` (methods = NULL, CIs off, num_cores = 2): 300 rows, about 6 min. A CI-enabled run with `methods = list(wald, score, lik_ratio, jackknife, rand, bootstrap = c("percentile","bca"))`, r = B = 501: 66 rows, 2.6 min.
- `html = TRUE` (writes the file; `browseURL` fails harmlessly with no browser), `pdf = TRUE`, `save_results_as_JSON = TRUE`, `output_dir = getwd()`, `plots = TRUE` (also leaves an `Rplots.pdf` in a non-interactive session).
- `classes`, `exclude_classes` and their error messages (good: they list the valid names); unknown sentinel; type on an untyped sentinel; `B = 3` guard; `param_boot` CI `B >= 39` guard; `inference_params` with a bad class or argument (good messages); `formulas = c(~1, ~.)` and a character vector of formulas; `combined_evidence_weighting` equal/custom (custom checked by hand against the Cauchy formula: matches); `combined_evidence_estimands`; `basic_bootstrap = TRUE`; `alpha`; `max_secs_per_class`; `model_formula` (ignored, as documented).
- Reproducibility promise: a task's result is identical whether it runs alone or in the full suite, and with num_cores 1 or 2 (after `set.seed(1)`). Holds.
- Suite vs one-by-one: all deterministic rows (wald/jackknife/score/LR/gradient) agree exactly.
- Reference checks: Welch and pooled t, wilcox.test, MASS::glm.nb (LR matches; the Wald SE matches the full observed-information Hessian, not MASS's theta-fixed vcov), quasipoisson (EDI uses z, not t), sandwich HC0 for robust Poisson, pscl hurdle/zeroinfl (NB versions match model SE; the Poisson versions match `sandwich::sandwich(pscl fit)`, as their help says).
- `get_procedure_validity()` and the `regime`/`n_eff`/`size_order`/`rate_basis` columns (hurdle classes use `n_nonzero = 84`).

## Not reached
- `lik_ratio_bartlett_exact`, `exact` (no count class offers it), `param_boot` CIs, `rand_bootstrap` CIs, the slow paths in `EDI_COMPREHENSIVE_SLOW_PATHS` requested explicitly.
- Other designs with the suite: a KK matching design (adds the KK count classes), blocking/cluster designs, unequal `prob_T` (n_eff = smaller arm), a missing covariate, a null effect, small n.
- `inference_params` used to change an estimand (e.g. `estimand = "marginal_mean_diff"`) and how the suite labels and groups it (see F2).
- `combined_evidence_weights` naming a `results` key such as `"Class{wald}"` instead of a class name.
- Whether `max_secs_per_class` works with `num_cores > 1`.

## Workarounds
- To get the list of `methods` sentinels: pass a bogus one (`methods = "walds"`); the error lists them all (`EDI_INFERENCE_SUITE_METHOD_SENTINELS` is not exported).
- `screen = FALSE` alone errors; use `screen = TRUE` inside `capture.output()` for quiet scripts.
- Do not call `set_num_cores()` in a session that runs the suite with `num_cores > 1` (F11).
- NA rows in `results_table`: the reason is in `message` for real failures; rows with NA `pval` and NA `message` are CI-only types with CIs off (F1) or swallowed errors (F7).
- `unname()` values before comparing across classes (RobustPoisson names its outputs "treatment").

## Confusing docs
- `?InferenceSuite` is very long and names internals users cannot see (`inference_class_registry.R`, `infer_inference_requires_blocking_design()`, `is_inference_class_compatible_with_design_metadata()`, TODO numbers, dated change notes like "per user request, 2026-08-19").
- `?InferenceCountPoisson`: the Wald/score/LR/gradient/param_boot p-values are all max(model, jackknife), so on overdispersed data they are all identical and the `se` column (model SE) does not match the reported p or CI. The behaviour is documented, but nothing in the suite table says so; it looks like a bug at first.
- `?DesignFixediBCRD` talks about behaviour "before v1.0.6" in the 1.0.4 install (n = 21 gives 10 treated, as described).
- The suite footer says "Combined evidence against the sharp null" even when it combines weak-null asymptotic tests; the help page itself says that reading is only coherent for randomization procedures.
