# Learnings: proportion

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- All five non-KK proportion classes on one data set with exact 0s and 1s, cross-checked against: `glm(quasibinomial)` (frac logit), `betareg` (beta), `gamlss(BEINF)` (ZOIB conditional and marginal_mean_diff), `rq(method = "fn")` + `summary(se = "nid")` (quantile), and glm + HC0 delta method (GComp). All match to 3–7 digits once you know the boundary handling.
- Beta regression: every supported testing type, cross-checked (LR via `lmtest::lrtest` and an offset profile; score vs a hand-computed observed-information score test). Also `set_information_preference`, and `marginal_mean_diff` vs a hand delta method.
- ZOIB: `model_formula_zero_one` with `~1`, `~age`, `~female` (treatment is always added); zeros-only, ones-only and no-boundary data; separation in the zero part.
- Quantile: tau from 0.03 to 0.97, plus invalid tau (0, 1, 1.5, NA, length 2).
- GComp: `variance_fallback_methods` (empty, `robust`, `model_based`, `model_based_fd`, invalid) and `prob_clip_eps` validation.
- Response validation on the design: out-of-range, NA and 1+1e-12 are all rejected clearly.
- Resampling: rand p, bootstrap CI and p, jackknife, Bayesian bootstrap for all five classes (B = r = 199, about 15 s in total).
- Small n (20, 24), a null effect, and `prob_T = 1/3`.

## Not reached
- `InferenceSuite$run_all_inference` on proportion data with 0/1, and the sequential KK14 path from the cookbook.
- The KK proportion classes: `InferencePropKKGEE`, `InferencePropKKGLMM`, `InferencePropKKQuantileRegrIVWC` / `OneLik`.
- Beta / ZOIB `compute_param_bootstrap_*` and `compute_lik_ratio_bootstrap_*`; subsampling and m-out-of-n bootstrap.
- Blocking or cluster designs with proportion outcomes; `optimization_alg` / `smart_cold_start_default` options of the beta class.
- Whether ZOIB `compute_estimate_with_bootstrap_weights` (separate fits, per the docs) biases the bootstrap CI: on the main data the bootstrap CI (0.504, 0.844) was shifted left of the Wald CI (0.525, 0.879).
- GComp: what happens when the robust variance is non-finite and the cascade silently falls to the unscaled model-based SE (F7).

## Workarounds
- To control `w` from base R: `des$overwrite_all_subject_assignments(w)` after `add_all_subjects_to_experiment()`.
- Beta regression with 0/1 data: EDI = `betareg` on `(y*(n-1)+0.5)/n`. Quantile regression: EDI = `rq` on `qlogis(pmin(pmax(y, .Machine$double.eps), 1-.Machine$double.eps))`.
- ZOIB NA SE: centre/scale covariates, or set `model_formula_zero_one = ~ 1`.
- GComp with an empty fallback: use `compute_estimate(estimate_only = TRUE)` for the point estimate.
- Wrapping a constructor in your own `tryCatch` that returns a string, then calling `$compute_estimate()`, gives "$ operator is invalid for atomic vectors". That is your own bug, not EDI's.

## Confusing docs
- `?InferencePropBetaRegr` names `sanitize_beta_response()`, but it has no help page and is not exported.
- `vignette("cookbook-proportion")` says fractional logit needs open-interval data; `?InferencePropFractionalLogit` says [0, 1] (the help page is right).
- `?InferencePropQuantileRegr` says y is "constrained to (0, 1)" but does not say what happens to 0/1 (they are clamped).
- `?InferencePropGCompMeanDiff`: `des_obj` is documented as "A completed `DesignSeqOneByOne` object", but a `DesignFixedBernoulli` works.
- `?InferencePropZeroOneInflatedBetaRegr`: it is not stated that treatment is always added to a user-supplied `model_formula_zero_one`.
- The error for NA responses points to a web article (`missing-covariates.html`) that is not among the installed vignettes.
