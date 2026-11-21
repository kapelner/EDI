# Learnings: incidence

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- iBCRD 75/75, Bernoulli `prob_T = 0.6` and DesignFixedBinaryMatch (75 pairs), each with rare events and with a forced zero cell (`y[w == 1] = 0L`).
- Exact OR: `InferenceIncidExactFisher` (iBCRD: fisher.test; matched: exact MH) for alpha, delta and `pval_epsilon`; `InferenceIncidExactZhang` (Bernoulli/matched, all three `combination_method`s, alpha, delta); `InferenceIncidExactBinomial` (central p at delta != 0). All match fisher.test / mantelhaen.test / exact2x2 / exactci / binom.test.
- RD: Wald, Newcombe, Miettinen-Nurminen, RiskDiff (LPM HC0), BinomialIdentity, GCompRiskDiff, CMH, ExtendedRobins. All checked against DescTools::BinomDiffCI / lm+sandwich / hand formulas.
- RR: LogBinomial, ModifiedPoisson (sandwich), GCompRiskRatio, LogRegr `set_estimand("marginal_ratio")`.
- LogRegr testing types wald/score/gradient/lik_ratio/lik_ratio_bartlett_approx vs glm Rao/LRT/MASS profile; param bootstrap; nonparam bootstrap (BCa, percentile); jackknife SE.
- KK classes on DesignFixedBinaryMatch: CondLogit OneLik/IVWC/GLMM, GEE, KK ModPoisson, KK GComp RD/RR, KK Newcombe. CondLogit matches `clogit(y ~ w + age + female + strata(pid))`.
- InferenceSuite `run_all_inference(methods = c("wald","exact","score","lik_ratio"), compute_conf_intervals = TRUE)` on rare-event and zero-cell data.

## Not reached
- `compute_lik_ratio_bootstrap_two_sided_pval/confidence_interval`, Bayesian bootstrap, m-out-of-n and subsampling on incidence.
- CMH / ExtendedRobins / stratified Fisher on a real `DesignFixedBlocking` (unequal block sizes, a block with no events).
- Sequential designs (KK14, Efron, Atkinson) with incidence: Zhang with both pairs and reservoir, where `combination_method` actually matters.
- A missing covariate value (imputation path) and `model_formula = ~ 1` versus covariate adjustment for LogRegr/GComp.
- Gradient test and Bartlett-approx factor (no installed reference). `exact2x2::uncondExact2x2` could serve as an exact RD/RR reference if EDI ever adds those.

## Workarounds
- On an iBCRD design the randomization p-value is refused (see F7). `InferenceIncidExactFisher`'s exact p is the conditional randomization test for the 2x2 table. On `DesignFixedBernoulli` the default randomization p and `type = "Zhang"` both work.
- The class help pages don't document inherited methods. `ls(obj)` lists them and `formals(obj$method)` gives the signature without reading bodies.
- Rendering help to text: `tools::Rd2txt(utils:::.getHelpFile(utils:::index.search(topic, find.package("EDI"))), out = file)` makes the long R6 pages greppable.
- `run_all_inference()` needs `screen = TRUE` or `html = TRUE` (it errors if both are FALSE). Use `plots = FALSE` in CI.

## Confusing docs
- `?InferenceIncidWald` `$new()` (beyond F10) has long internal-rationale paragraphs ("Pins asymptotic CI dispatch ... SimpleMeanDifference component ... silently wins") under `new()`.
- `?DesignFixediBCRD` says "Before v1.0.6 a .5 tie was rounded up" while the installed version is 1.0.4.
- The randomization-CI error message points to an internal repo file (`R/package_metadata/new_feature_plans/v1_1_0/incidence_randomization_cis.md`).
- `?InferenceIncidGCompRiskRatio`: `delta` "Defaults to 0 for RD and 1 for RR", but the formal default is `NULL`. `?InferenceParamBootstrap`: `compute_param_bootstrap_pval(delta)` has no default, unlike every other p-value method (`delta = 0`).
- The InferenceSuite table labels `InferenceIncidLogRegr` and `InferenceIncidProbitRegr` as "logodds marginal" / "probit marginal", although their default estimand is "conditional". Exact Fisher is "logodds cond".
- Bartlett-approx (`B = 99` default) p-values vary a lot by seed (0.00024 to 0.0021 on the same data), and no page says how big `B` should be.
