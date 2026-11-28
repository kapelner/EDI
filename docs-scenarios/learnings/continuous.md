# Learnings: continuous

Appended by each weekly docs-only scenario run.

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

## Covered
- Fixed `DesignFixedBernoulli`, n = 70 with 3 outliers. Classes: `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`, `InferenceContinOLS`, `InferenceContinLin`, `InferenceContinRobustRegr` (MM/M × use_rcpp), `InferenceContinQuantileRegr` (tau .25/.5/.75/.9).
- Methods on those classes:
  - asymptotic CI / p (`alpha`, `delta`);
  - randomization p (`delta`, `alternative`, `permutations = list(w_mat=)`);
  - randomization CI (r = 30 conservative-bound message, r = 99/199/499);
  - bootstrap CI (default/percentile/bca/basic) and all 5 bootstrap p types;
  - Bayesian bootstrap CI;
  - jackknife SE/CI/p.
- Cross-checks to 4+ dp, all exact: `t.test` (Welch and pooled), `lm` (OLS incl. `model_formula` with interactions, `I()` and `~ 1`), `lm(y ~ w*Xc)` + `vcovHC("HC2")` (Lin), `rq` + `summary(se = "nid")` with t(n−p) (quantile), `MASS::rlm` (robust, `use_rcpp = FALSE`), manual leave-one-out OLS jackknife.
- `DesignSeqOneByOneKK21` (n = 70 and n = NULL) and `DesignSeqOneByOneKK14`. Classes: all KK continuous classes (`KKMeanDiffIVWC`, `KKOLSIVWC/OneLik`, `KKRobustRegrIVWC/OneLik`, `KKQuantileRegrIVWC/OneLik`, `KKGLMM` both backends, `BaiAdjustedTKK14/21`), each with asymptotic CI/p plus randomization p and CI.
- KK manual cross-checks (exact): OLS IVWC (HC2 IVW), OLS OneLik (stacked lm + HC2, t df = rows − p), quantile IVWC and OneLik (rq nid, z critical value), robust OneLik with use_rcpp = FALSE (rlm on the stacked design).
- `InferenceSuite$run_all_inference(classes=, methods = "wald")`: its table matches the individual classes.
- Bad inputs that are rejected cleanly: w coded 1/2 or logical, NA/Inf response, tau out of range, method "S", B < min_number_usable_samples.

## Not reached
- Missing covariate: imputation runs (estimate 3.75), but I did not cross-check the imputation rule or `include_is_missing_as_a_new_feature = FALSE`.
- Score / LR / gradient / Bartlett testing types for OLS, Lin and KK OLS OneLik (documented "full" likelihood tier), and `param_boot`.
- `compute_m_out_of_n_bootstrap_*`, subsampling, rand-bootstrap CI (`InferenceRandBootstrapCI`), `bootstrap_type` argument.
- Other bootstrap CI types: studentized, symmetric-percentile-t, prepivoted, double-bootstrap, calibrated, smoothed.
- KK designs with `lambda`, `t_0_pct` and `morrison`; KK21stepwise; tiny KK n where only pairs or only reservoir exist (fallback paths).
- `InferenceBaiAdjustedTKK21` formula check; `InferenceContinKKGLMM` score/LR tests.
- Blocking / cluster designs with continuous regressions: the policy table forces percentile there, and the docs discuss block fixed effects.
- Whether F2 (`Inf` randomization CI bound) also occurs for other non-affine classes (robust, KK robust) at small r.

## Workarounds
- Robust MM matching `MASS::rlm`: pass `use_rcpp = FALSE`. The default C++ "MM" is a bisquare IRLS started from OLS, not MASS MM.
- Default bootstrap type per class: `get_bootstrap_dispatch_policy()$inference_class_overrides`. Pass `type` explicitly.
- Matched-pair structure for manual KK cross-checks: `des$get_matching_cluster_ids()` (pairs share an id, reservoir subjects get singleton ids).
- KK stacked design that reproduces `InferenceContinKKOLSOneLik` / `KKQuantileRegrOneLik` exactly: `rbind(cbind(0, 1, Xdiff), cbind(1, w_res, X_res))`, regressed without an extra intercept; the treatment is column 2.
- KK mean-diff IVWC: Var(r̄) is the pooled-variance two-sample formula, and the CI uses z.
- To replay a fixed assignment on a new design object: `des$overwrite_all_subject_assignments(w)`.
- Avoid printing the inference object (e.g. wrapping `$new()` in a helper that prints): it dumps the whole R6 method list.

## Confusing docs
- `?InferenceNonParamBootstrap`: `type = NULL` is not explained; the rule is only in `?get_bootstrap_dispatch_policy`.
- `?InferenceContinRobustRegr` says method is "passed through to either backend", but `?fast_robust_regression_cpp` shows the C++ "MM" is not MASS MM.
- `?InferenceAllKKMeanDiffIVWC` points to "the full variance formula" that is not there, and cites `private$compute_z_or_t_ci_from_s_and_df`.
- `?InferenceRandCI` (`ci_search_control`) cites `high_precision_confirm_and_refine_ci_bound()`'s "own comment" and `R/package_metadata/new_feature_plans/`, i.e. source code that users cannot read.
- KK OLS/robust class pages: no `$new()` section, duplicated argument entries, and the super class shown as `Inference`.
- The cookbook says "The default interval type is BCa". That is true for OLS only, not for Lin, robust or quantile.
