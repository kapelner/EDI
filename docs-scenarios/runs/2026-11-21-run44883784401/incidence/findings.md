# Findings: incidence (EDI 1.0.4)

### F1: Risk-ratio classes report the treatment effect on different scales: `InferenceIncidGCompRiskRatio` returns the raw ratio (null 1, `delta = 0` errors), while `InferenceIncidLogBinomial`, `InferenceIncidModifiedPoisson` and `InferenceIncidLogRegr` with `estimand = "marginal_ratio"` return the log ratio (null 0)
- Kind: inconsistency
- Expected: one convention for "risk ratio" across the `InferenceIncid*` family, or at least a pointer on each page. `?InferenceIncidLogBinomial` says beta_T "is a *log risk ratio*"; `?InferenceIncidLogRegr` (Estimand) says `"marginal_ratio"` gives "the log of the corresponding marginal risk ratio"; `?InferenceIncidGCompRiskRatio` estimates "RR = risk_1 / risk_0" and its `delta` "Defaults to 0 for RD and 1 for RR". The three pages don't mention each other's scale. Code that loops over classes and compares `compute_estimate()` (or passes the same `delta`) gets results that can't be compared.
- Observed (same data: 2/75 infected on vaccine, 14/75 on placebo, covariates age + female):
  - `InferenceIncidGCompRiskRatio`: estimate `0.1358805`, CI `0.03138708 0.58825202`; `compute_asymp_two_sided_pval(delta = 0)` gives `Error: For RR inference, delta must be strictly positive.`
  - `InferenceIncidLogRegr` + `set_estimand("marginal_ratio")`: estimate `-1.995979` (= log 0.1358805), CI `-3.436 -0.556`, so the same estimand is on the log scale.
  - `InferenceIncidLogBinomial`: `-2.001729`; `InferenceIncidModifiedPoisson`: `-1.992243` (log scale).
  - The values themselves are correct: the GComp RR matches a hand-coded g-computation with sandwich delta method (CI 0.031387, 0.588253; p 0.0075931), and LogRegr marginal_ratio matches the same calculation with model-based vcov (p 0.006603).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); des$add_all_subject_responses(y)
  rr = InferenceIncidGCompRiskRatio$new(des)
  rr$compute_estimate()                          # 0.1358805  (ratio scale)
  try(rr$compute_asymp_two_sided_pval(delta = 0)) # error: delta must be strictly positive
  lr = InferenceIncidLogRegr$new(des); lr$set_estimand("marginal_ratio")
  lr$compute_estimate()                          # -1.995979  (log scale, same estimand)
  InferenceIncidLogBinomial$new(des)$compute_estimate()     # -2.001729 (log scale)
  InferenceIncidModifiedPoisson$new(des)$compute_estimate() # -1.992243 (log scale)
  ```
- Workaround used, if any: exponentiate the log-scale classes (or take the log of GComp RR) before comparing; pass `delta = 1` to GComp RR and `delta = 0` to the others.

### F2: `InferenceIncidLogBinomial` returns `NA` estimate, `c(NA, NA)` CI and `NA` p-value without any warning when one arm has zero events; `glm(binomial(link = "log"))` gives a finite boundary fit
- Kind: silent NA
- Expected: `?InferenceIncidLogBinomial` says that when the MLE is on the boundary "the object warns once (`edi_binomial_mle_boundary_warning`)", and that implausible fits are "rejected as nonestimable". A rejected fit should at least warn (other classes raise `edi_procedure_na_warning`, see `?InferenceIncidExactZhang`). The reason `model_fit_unavailable` also doesn't say what caused it (zero events in one arm, so log RR = -Inf).
- Observed: vaccine arm 0/75, placebo 14/75. `compute_estimate()` gives `NA`, `compute_asymp_confidence_interval()` gives `NA NA`, `compute_asymp_two_sided_pval()` gives `NA`. No warning or message, even with `verbose = TRUE`. Only `get_summary()` prints `Note: the most recent fit was flagged non-estimable (model_fit_unavailable).` For reference, `glm(y ~ w + age + female, binomial(link = "log"))` converges with coefficient -18.71 on `w`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); y[w == 1] = 0L
  des$add_all_subject_responses(y)
  o = InferenceIncidLogBinomial$new(des, verbose = TRUE)
  o$compute_estimate()                    # NA, no warning
  o$compute_asymp_confidence_interval()   # NA NA, no warning
  o$compute_asymp_two_sided_pval()        # NA, no warning
  o$get_nonestimable_reason()             # "model_fit_unavailable"
  ```
- Workaround used, if any: none inside the class. Used `InferenceIncidExactFisher` (exact CI) and the risk-difference classes for the zero-cell data.

### F3: `InferenceIncidModifiedPoisson` on zero-cell data reports log RR = -22.3, 95% CI (-22.85, -21.80) and p-value exactly 0, with no boundary or separation warning
- Kind: inconsistency
- Expected: when fitted means are numerically 0 for a whole arm, warn as the sibling classes do. `InferenceIncidLogRegr`, `InferenceIncidProbitRegr` and `InferenceIncidGCompRisk*` raise `edi_logistic_separation_warning` ("Wald standard errors, p-values and confidence intervals are not meaningful here"), and `InferenceIncidLogBinomial` documents `edi_binomial_mle_boundary_warning`. `?InferenceIncidModifiedPoisson` says fits with implausible coefficients "are cached as nonestimable rather than returned". A log risk ratio of -22.3 (RR about 2e-10) with an interval of width 1 is implausible.
- Observed: the only warning is `edi_covariate_dropped_warning` ("dropped covariate(s) age, female and refit because the fit with all covariates failed ..."). The reduced model then returns `-22.32157`, CI `-22.84539 -21.79775`, p `0`, and `get_summary()` shows `Std. Error 0.2672612  z value -83.51966  Pr(>|z|) 0`. The SE equals `sandwich::sandwich(glm(y ~ w, poisson))` (0.2672612), so the arithmetic is "right", but the estimate is where the fitter stopped (glm stops at -18.62). The user gets a confident, highly significant, finite answer and no hint that the MLE is -Inf.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); y[w == 1] = 0L
  des$add_all_subject_responses(y)
  o = InferenceIncidModifiedPoisson$new(des)
  o$compute_estimate()                    # -22.32 (only a covariate-dropped warning)
  o$compute_asymp_confidence_interval()   # -22.85 -21.80
  o$compute_asymp_two_sided_pval()        # 0
  ```
- Also affected: the matched-pair sibling `InferenceIncidKKModifiedPoisson` on a `DesignFixedBinaryMatch` with 0 events on treatment (repro in F6's setup) returns `-24.88011`, CI `-25.40812 -24.35210`, p `6.408703e-132`, with no warning at all.
- Workaround used, if any: none. Reported RR only from the exact Fisher CI on the OR scale and from the risk-difference classes.

### F4: `InferenceIncidExactFisher$compute_estimate()` returns `NA` without a warning when a cell is zero, although `fisher.test` gives a conditional MLE of 0 (log OR = -Inf) and the class's own exact CI has lower bound `-Inf`
- Kind: silent NA
- Expected: `?InferenceIncidExactFisher` says the estimate is "the log of the ... conditional MLE ... odds ratio from `fisher.test`". With a zero cell that is `log(0) = -Inf`, which is consistent with the exact CI `(-Inf, -1.34632)` the same object returns. If `NA` is intended, the help page doesn't say so, and nothing warns. The reason only shows up in `get_nonestimable_reason()` / `get_summary()`.
- Observed: `compute_estimate()` gives `NA`, with no warning or message (`verbose = TRUE`). `get_nonestimable_reason()` gives `"exact_fisher_conditional_mle_infinite"`. `compute_exact_confidence_interval()` gives `-Inf -1.34632`, which matches `log(fisher.test(tab)$conf.int)`. `compute_exact_two_sided_pval_for_treatment_effect()` gives `6.26053e-05`, which matches `fisher.test`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); y[w == 1] = 0L
  des$add_all_subject_responses(y)
  o = InferenceIncidExactFisher$new(des, verbose = TRUE)
  o$compute_estimate()                    # NA, silently
  o$get_nonestimable_reason()             # "exact_fisher_conditional_mle_infinite"
  o$compute_exact_confidence_interval()   # -Inf -1.34632
  fisher.test(table(factor(w, 1:0), factor(y, 1:0)))$estimate   # 0
  ```
- Workaround used, if any: reported the exact CI and p-value and took the point estimate as -Inf by hand.

### F5: The public `compute_lik_ratio_bartlett_exact_*()` methods of `InferenceIncidLogRegr` return `NA` with the warning text "Reason: no error message was recorded", and the `set_testing_type()` error lists `lik_ratio_bartlett_exact` as allowed although the class then refuses it
- Kind: useless message
- Expected: `?InferenceIncidLogRegr` (Small-sample behaviour) says "an object can still report a procedure (for example a Bartlett correction) as unavailable through `get_supported_testing_types()`", so it is fine for the procedure to be unavailable. But the direct method should say *why* (for example "the exact Bartlett correction is not implemented for this class; use `lik_ratio_bartlett_approx`"), and a bad `testing_type` should list only values this class accepts.
- Observed:
  - `compute_lik_ratio_bartlett_exact_two_sided_pval()` gives `NA` with warning `InferenceIncidLogRegr: the lik_ratio_bartlett_exact test is unavailable (NA) although the Wald result is finite. Reason: no error message was recorded (the null-restricted refit, score, or log-likelihood evaluation returned a non-finite or unusable value). ...`. The CI method gives `NA NA`. This happens on ordinary, well-conditioned data (2/75 vs 14/75, no separation).
  - `set_testing_type("bogus")` gives `testing_type must be one of: wald, score, gradient, lik_ratio, lik_ratio_bartlett_approx, lik_ratio_bartlett_exact`.
  - `set_testing_type("lik_ratio_bartlett_exact")` then gives `InferenceIncidLogRegr does not support testing_type = "lik_ratio_bartlett_exact". Supported values are: wald, score, gradient, lik_ratio, lik_ratio_bartlett_approx`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); des$add_all_subject_responses(y)
  lr = InferenceIncidLogRegr$new(des)
  lr$compute_lik_ratio_bartlett_exact_two_sided_pval()      # NA + "no error message was recorded"
  lr$compute_lik_ratio_bartlett_exact_confidence_interval() # NA NA
  try(lr$set_testing_type("bogus"))                         # lists lik_ratio_bartlett_exact
  try(lr$set_testing_type("lik_ratio_bartlett_exact"))      # ... then refuses it
  ```
- Workaround used, if any: used `lik_ratio` and `lik_ratio_bartlett_approx` instead.

### F6: On matched-pair data with zero events in the treated arm, the KK conditional-logit classes return `NA` estimate/CI/p-value (OneLik, GLMM) or a meaningless CI of about ±21 500 (IVWC) with no warning at all
- Kind: silent NA
- Expected: a warning that the conditional MLE does not exist (separation), as the non-matched `InferenceIncidLogRegr` and the matched `InferenceIncidKKGEE` / `InferenceIncidKKGCompRisk*` raise on the same data (`edi_logistic_separation_warning`), or the `edi_procedure_na_warning` described in `?InferenceIncidExactZhang`. The rules of this API (NA on finite input) call for a message.
- Observed (`DesignFixedBinaryMatch`, n = 150, 75 pairs, treated 0/75, control 14/75), every call silent:
  - `InferenceIncidKKCondLogitOneLik`: estimate `NA`, CI `NA NA`, p `NA`; `get_nonestimable_reason()` gives `"kk_clogit_combined_extreme_treatment_coefficient"`
  - `InferenceIncidKKCondLogitGLMMOneLik` and `...GLMMIVWC`: estimate `-25.56607`, CI `NA NA`, p `NA`; reason `"joint_likelihood_standard_error_unavailable"`
  - `InferenceIncidKKCondLogitIVWC`: estimate `-21.20289`, CI `-21505.78 21463.37`, p `0.9984567`, `get_nonestimable_reason()` is `NULL`
  - `InferenceIncidExactBinomial` on the same data works: estimate -3.367 (Haldane), exact p `0.0001220703`, CI `-Inf -1.199098`, all matching `binom.test(0, 14)`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", seed = 5)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  set.seed(12); y = rbinom(n, 1, plogis(-1.3 - 1.2 * w + 0.04 * (X$age - 45))); y[w == 1] = 0L
  des$add_all_subject_responses(y)
  for (cl in c("InferenceIncidKKCondLogitOneLik", "InferenceIncidKKCondLogitGLMMOneLik",
               "InferenceIncidKKCondLogitIVWC")) {
    o = get(cl)$new(des)
    print(c(o$compute_estimate(), o$compute_asymp_confidence_interval(), o$compute_asymp_two_sided_pval()))
    print(o$get_nonestimable_reason())
  }   # no warnings printed
  ```
- Workaround used, if any: used `InferenceIncidExactBinomial` (exact McNemar-type) for the matched zero-cell data.

### F7: On a complete-randomization (`DesignFixediBCRD`) incidence design, `compute_rand_two_sided_pval()` says "Use Zhang method", but passing `type = "Zhang"` fails with "Randomization type dispatch is only supported for incidence outcomes" although the outcome is incidence
- Kind: false message
- Expected: `?InferenceIncidWald` and `?InferenceIncidRiskDiff` (`$new()` section) say "for incidence responses it does not refuse outright; the default p-value comes from the randomization draws, and the Zhang exact randomization test is used only when `type = "Zhang"` is passed explicitly". So either the default should work, or the error should point to something that works. iBCRD is the textbook design for a randomization test (`?DesignFixediBCRD`: "what makes exact permutation/randomization tests ... well-defined"). On a `DesignFixedBernoulli` design the same calls work (default p 0.01001, `type = "Zhang"` p 0.01199 = Fisher).
- Observed (iBCRD, n = 150, 2/75 vs 14/75):
  - `InferenceIncidWald$new(des)$compute_rand_two_sided_pval(r = 999, show_progress = FALSE)` gives `Error: Randomization tests are not supported for incidence. Use Zhang method.`
  - Doing what the message says, `...compute_rand_two_sided_pval(r = 999, show_progress = FALSE, type = "Zhang")`, gives `Error: Randomization type dispatch is only supported for incidence outcomes.`
  - Same pair of errors for `InferenceIncidRiskDiff` and `InferenceIncidLogRegr` (first error).
  - The Zhang class itself refuses this design: `InferenceIncidExactZhang$new(des)` gives `Zhang incidence inference requires Bernoulli or matching designs.`
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); des$add_all_subject_responses(y)
  wd = InferenceIncidWald$new(des); wd$set_seed(1)
  try(wd$compute_rand_two_sided_pval(r = 999, show_progress = FALSE))                 # "Use Zhang method."
  try(wd$compute_rand_two_sided_pval(r = 999, show_progress = FALSE, type = "Zhang")) # "only supported for incidence outcomes"
  ```
- Workaround used, if any: used the exact Fisher p-value (`InferenceIncidExactFisher`, which matches `fisher.test`) as the conditional randomization test, and checked it against my own 1999-draw permutation of the risk difference (p = 0.002).

### F8: `InferenceIncidLogRegr`'s parametric-bootstrap estimate and CI silently include near-separated replicates (log OR about -25). The "bias-corrected" estimate flips the sign of a strong protective effect (-2.23 becomes +1.03) and the CI upper bound is +21, while the diagnostics report `n_extreme = 0`
- Kind: inconsistency
- Expected: `?InferenceParamBootstrap` documents `compute_param_bootstrap_estimate()` as `2*theta_hat - mean(theta_hat_star)` and the CI as the "basic" interval. Replicates where the fitter stopped at separation (an arm with 0 simulated events) are not usable estimates. The nonparametric bootstrap on the same object detects this ("bootstrap_extreme_confidence_interval ... typically a few resamples near separation", NA plus `edi_procedure_na_warning`), and the estimate diagnostics have an `n_extreme` field. So the parametric path should either drop or flag these replicates, or warn.
- Observed (iBCRD, 2/75 vaccine vs 14/75 placebo, glm log OR -2.2297):
  - `compute_param_bootstrap_confidence_interval()` gives `-3.413887 21.0238` (seed 1), `-3.419185 21.08386` (seed 2), `-3.5325 21.02679` (seed 3), with no warning. exp(21) is an odds ratio of about 1e9 at the upper end.
  - `compute_param_bootstrap_estimate()` gives `1.028001`, with no warning, from raw estimate -2.23.
  - `get_last_param_bootstrap_estimate_diagnostics()` gives `n_success 199, n_failure 0, n_extreme 0`, but `replicate_estimates` contains values like `-25.57`.
  - My own parametric bootstrap from the glm fit (199 draws) has 10.6% of replicates below -10, which explains the +21 bound (2*(-2.23) - q_0.025 ≈ -4.46 + 25).
  - On the same object, `compute_bootstrap_confidence_interval(B = 501, type = "percentile")` warns and returns `NA NA`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); des$add_all_subject_responses(y)
  lr = InferenceIncidLogRegr$new(des)
  lr$compute_estimate()                                   # -2.229663
  lr$set_seed(1); lr$compute_param_bootstrap_confidence_interval()   # -3.41 21.02, no warning
  lr$set_seed(1); lr$compute_param_bootstrap_estimate()   # 1.028 (sign flipped), no warning
  d = lr$get_last_param_bootstrap_estimate_diagnostics(); d$n_extreme; min(d$replicate_estimates)  # 0, about -25
  ```
- Workaround used, if any: did not use the parametric bootstrap. Reported the profile-likelihood (`lik_ratio`) CI, which matches `MASS` profile `confint(glm)` to 3 decimals (-4.1206 vs -4.1207, -0.8832 vs -0.8832).

### F9: On zero-cell data `InferenceSuite$run_all_inference()` marks `InferenceIncidExactFisher` "nonest" and drops its valid exact p-value and CI from the table and from the combined evidence, but keeps separated fits flagged by their own warnings (GComp RR p = 0, CI 2.7e-10 to 7.6e-10) as "ok" with full weight
- Kind: inconsistency
- Expected: the exact Fisher p-value (6.26e-05) and exact CI (-Inf, -1.346) are finite and correct (they match `fisher.test`), and the same object returns them when called directly. The only thing that is not finite is the point estimate (conditional MLE = -Inf, see F4). The suite should report the exact p-value/CI, or at least not rank an exact test below fits whose own warning says "Wald standard errors, p-values and confidence intervals are not meaningful here". `?InferenceSuite` says the combined p-value summarizes "all applicable inference procedures".
- Observed (iBCRD, 0/75 vs 14/75, `methods = c("wald","exact","score","lik_ratio")`, `compute_conf_intervals = TRUE`):
  - The Fisher row has `estimate NA, ci_a NA, ci_b NA, pval NA, status "nonest", message "exact_fisher_conditional_mle_infinite"`, and `combined_evidence$weights_used["InferenceIncidExactFisher"]` is `NA`.
  - The `InferenceIncidGCompRiskRatio` row has `estimate 4.49e-10, pval 0, status "ok"` (its `warnings` column holds the separation warning) and weight 0.2 (its own estimand group `"RR"`).
  - The `InferenceIncidModifiedPoisson{wald}` row has `-22.3, CI -22.8 -21.8, pval 0, status "ok"`.
  - Separately, the printed per-estimand summary shows `p = NA` for every estimand group with a single inference, even when that inference's p-value is finite and is used in the overall combination. In scenario A (no zero cell), `Estimand: logodds cond (1 inferences) : p = NA` is printed although Fisher p = 0.00253 has weight 0.1667 in `combined_evidence`, and the same happens for `risk ratio (1 inferences)`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)); y[w == 1] = 0L
  des$add_all_subject_responses(y)
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2L,
          methods = c("wald", "exact"), compute_conf_intervals = TRUE, max_secs_per_class = 20)
  res$results[["InferenceIncidExactFisher"]][c("pval", "ci_a", "ci_b", "status")]   # NA NA NA "nonest"
  res$combined_evidence$weights_used["InferenceIncidExactFisher"]                    # NA
  res$results[["InferenceIncidGCompRiskRatio"]][c("estimate", "pval", "status")]    # 4.5e-10, 0, "ok"
  f = InferenceIncidExactFisher$new(des)
  f$compute_exact_two_sided_pval_for_treatment_effect(); f$compute_exact_confidence_interval()  # 6.26e-05; -Inf -1.346
  ```
- Workaround used, if any: called the exact classes directly instead of relying on the suite.

### F10: `?InferenceIncidWald` and `?InferenceIncidRiskDiff` document constructor arguments (`alpha`, `delta`; `r`, `delta`, `type`, `permutations`, ...) that `$new()` does not accept
- Kind: false docs
- Expected: the Arguments list under `$new()` should match its Usage. `?InferenceIncidWald` `$new()` Arguments lists `alpha` ("The confidence level in the computed confidence interval is 1 - alpha") and `delta`. `?InferenceIncidRiskDiff` `$new()` Arguments lists `r`, `delta`, `transform_responses`, `na.rm`, `show_progress`, `permutations`, `type`, `args_for_type`, `zero_one_logit_clamp`. Both Usage blocks show only `des_obj, model_formula, verbose(, smart_cold_start_default)`.
- Observed: `InferenceIncidWald$new(des, alpha = 0.1)` gives `Error: unused argument (alpha = 0.1)`. `InferenceIncidRiskDiff$new(des, r = 10)` gives `Error: unused argument (r = 10)`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026); n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence", prob_T = 0.5, seed = 1)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); des$add_all_subject_responses(rbinom(n, 1, ifelse(w == 1, 0.03, 0.18)))
  try(InferenceIncidWald$new(des, alpha = 0.1))   # unused argument (alpha = 0.1)
  try(InferenceIncidRiskDiff$new(des, r = 10))    # unused argument (r = 10)
  ```
- Workaround used, if any: passed `alpha`/`delta`/`r` to the `compute_*` methods instead.
