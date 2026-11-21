# Learnings: count

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- Poisson, QuasiPoisson, RobustPoisson, NegBin, ZIP, ZINB, HurdlePoisson, HurdleNegBin on DesignFixedBernoulli(prob_T = 0.4, n = 160): estimate, asymp CI and p cross-checked against glm / glm.nb / pscl / sandwich.
- set_testing_type wald/score/lik_ratio/gradient on NegBin. LR p equals the MASS LR test exactly.
- Poisson jackknife-Wald (compared with a manual jackknife), and Poisson + ZIP marginal estimands (compared with a manual delta method).
- Randomization p, bootstrap CI, NB lik_ratio_bootstrap p, set_seed reproducibility.
- model_formula with covariate subsets and with offset(); model_formula_zero / model_formula_hurdle = ~1, ~0, ~prior; use_rcpp = FALSE (ZINB, KK GLMM).
- Bad inputs: non-integer, negative and NA counts are all rejected with clear messages.
- Separation: all-zero control arm (n = 30), and small n = 24 with prob_T = 1/3 under a null effect.
- KK14 sequential designs: KKGLMM (vs glmer nAGQ = 25), PoissonKKGEE (vs geepack), KKCondPoissonOneLik, KKHurdlePoissonIVWC / OneLik (run only).
- InferenceSuite run_all_inference (cookbook call).

## Not reached
- Cross-checks for KKCondPoissonOneLik (could use survival::clogit or a conditional binomial on the pairs plus Poisson on the reservoir) and for the KK hurdle classes.
- Bartlett exact/approx and param_boot CIs on fixed-design count classes; Bayesian bootstrap; rand CI.
- Whether the F7 stuck-warm-start problem also hits bootstrap draws and the NB/ZI classes under other separation patterns.
- DesignFixedBlocking / cluster designs with count outcomes (jackknife unit choices); missing covariates with count response.
- The `robust_negbinreg` helper (column-dropping fallback).
- The InferenceSuite estimand grouping ("log rate ratio cond (4)" vs "marginal (10)") looked odd; not checked.

## Workarounds
- No offset is available, and offset() in model_formula is silently ignored (F4). Use log(follow-up) as an ordinary covariate.
- The KK pair ids come from `des$get_matching_cluster_ids()` (shown only in the ?DesignSeqOneByOneKK14 example).
- The model-based Poisson SE is not in the CI (that is the union with the jackknife). Read it from `get_summary()`.
- The ZIP / hurdle Poisson Wald SE is the sandwich SE. Compare with `sandwich::sandwich(pscl_fit)`, not with `summary(pscl_fit)`.
- The NegBin SE uses observed information; compare with a numerical Hessian of the joint NB log-likelihood (glm.nb differs in the 3rd digit).
- To render help as text without HTML: `tools::Rd2txt(tools::Rd_db("EDI")[["Topic.Rd"]])`.

## Confusing docs
- vignette("cookbook-count") points to `ROADMAP.md` for offsets, but that file is not installed.
- ?InferenceCountZeroInflatedPoisson / ?InferenceCountHurdlePoisson: `model_formula_zero` / `model_formula_hurdle` do not say that treatment is always added (F1).
- ?InferenceCountZeroInflatedNegBin / ?InferenceCountHurdleNegBin do not say which covariance the Wald test uses (it is model-based, unlike their Poisson siblings, which use the sandwich).
- ?InferenceCountNegBin does not say whether the SE is from observed or expected information.
- ?InferenceCountKKGLMM says the Wald SE is model-based; it is the jackknife SE (F5).
- ?InferenceCountPoisson: the union-with-jackknife rule means the "Wald/LR/score" CIs are often all identical (the jackknife CI). Non-obvious, though documented.
