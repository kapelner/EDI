# Findings: factorial (2 x 2 marketing test, binary purchase outcome)

### F1: Randomization tests refuse every incidence analysis on `DesignFixedFactorial` and `DesignFixedBlocking`, yet `supports("randomization_test")` is TRUE and the factorial article says these designs work like any two-arm design
- Kind: documented option fails
- Expected (and where the docs say so): article "Cluster-Randomized and Factorial Experiments", section "What `DesignFixedFactorial` supports today": "It works with every inference class, like any other two-arm design"; section "Running a 2 x 2 factorial with blocked designs / Main effects" uses `compute_rand_two_sided_pval()` on the `DesignFixedBlocking` main-effect design and says "The randomization test permutes A within the levels of B". `?InferenceRand` says "The p-value always comes from randomization draws of the assignment vector w from the design, for every response type including incidence". `inf$capabilities()` lists `"randomization_test"` and `inf$supports("randomization_test")` is `TRUE`.
- Observed: for a binary (`response_type = "incidence"`) outcome, on both a one-factor `DesignFixedFactorial` and the main-effect `DesignFixedBlocking` design, every class tried (`InferenceIncidRiskDiff`, `InferenceAllSimpleAverageDiff`, `InferenceIncidLogRegr`, `InferenceIncidGCompRiskDiff`, `InferenceIncidCMH`, `InferenceIncidNewcombeRiskDiff`) errors:
  `Randomization tests are not supported for incidence. Use Zhang method.`
  At the same time `inf$supports("randomization_test")` returns `TRUE` and only the separate `inf$supports_rand_pval_for_incidence()` returns `FALSE`. So the article's 2 x 2 recipe cannot give a randomization p-value for a binary outcome, and the capability check says it can. `compute_rand_confidence_interval()` is also refused for incidence ("temporarily disabled for incidence responses (2026-08-27)..."); neither restriction is mentioned in the factorial article or on `?DesignFixedFactorial`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40
  des = DesignFixedFactorial$new(n = n, response_type = "incidence", factors = list(subject_line = 2))
  des$add_all_subjects_to_experiment(data.frame(age = rnorm(n)))
  des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rbinom(n, 1, 0.3))
  inf = InferenceIncidRiskDiff$new(des)
  inf$supports("randomization_test")          # TRUE
  inf$supports_rand_pval_for_incidence()      # FALSE
  inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE)
  # Error: Randomization tests are not supported for incidence. Use Zhang method.
  ```
- Workaround used, if any: used `InferenceIncidExactFisher` (stratified exact test, matches `mantelhaen.test(exact = TRUE)`), `InferenceIncidCMH` and bootstrap p-values instead of a randomization test.

### F2: The error tells the user to "Use Zhang method", but `type = "Zhang"` then fails with a message claiming the outcome is not incidence
- Kind: false message
- Expected (and where the docs say so): the error from F1 says "Use Zhang method"; `?InferenceIncidRiskDiff` (`compute_rand_two_sided_pval`) documents `type`: "Optional exact-inference type for incidence dispatch". Following the message should either work or explain why Zhang is not available here (`?InferenceIncidExactZhang` says it needs a Bernoulli- or matching-capable design).
- Observed: `inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE, type = "Zhang")` errors with
  `Randomization type dispatch is only supported for incidence outcomes.`
  although the response *is* incidence. Same message for `type = "Fisher"`, `"exact"`. On `InferenceIncidGCompRiskDiff` and `InferenceIncidNewcombeRiskDiff` the same call gives `unused argument (type = "Zhang")`. `InferenceIncidExactZhang` is not in `des$applicable_inference_class_names()` for these designs. The valid values of `type` are not listed anywhere I could find.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40
  des = DesignFixedFactorial$new(n = n, response_type = "incidence", factors = list(subject_line = 2))
  des$add_all_subjects_to_experiment(data.frame(age = rnorm(n)))
  des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rbinom(n, 1, 0.3))
  inf = InferenceIncidRiskDiff$new(des)
  des$get_response_type()                     # "incidence"
  inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE, type = "Zhang")
  # Error: Randomization type dispatch is only supported for incidence outcomes.
  ```
- Workaround used, if any: none; dropped the randomization p-value for the binary outcome.

### F3: On the 2 x 2 main-effect design (`DesignFixedBlocking` with 2 blocks) the default bootstrap CI and p-value (BCa) and every jackknife unit return NA, and the warning recommends a randomization test that errors for this outcome
- Kind: useless message
- Expected (and where the docs say so): `?DesignFixedBlocking`, "How inference accounts for the blocks": "Block-aware: randomization inference (re-draws within blocks), the bootstrap and the jackknife (resample within blocks)", and `draw_bootstrap_indices()` "resamples within each block by default". The article's 2 x 2 recipe always has exactly two blocks (the levels of the other factor), so the documented default should work there, or the NA warning should point to something that works.
- Observed: `compute_bootstrap_confidence_interval(B = 999)` (default type) and `compute_bootstrap_two_sided_pval(B = 999)` return `NA` with
  `InferenceIncidRiskDiff: bootstrap confidence interval (type = "bca") returned NA (reason: bootstrap_bca_jackknife_too_few_deletion_units). The BCa acceleration is estimated from the jackknife replicates, and there are only 2 deletion units (unit = "block"); at least 5 are needed. With so few units the acceleration is unreliable (identically 0 with 2) and the bootstrap itself resamples only those units. Use a randomization test or interval (compute_rand_two_sided_pval(), compute_rand_confidence_interval()); ...`
  (a) "the bootstrap itself resamples only those units" contradicts the help, which says the default bootstrap resamples subjects within blocks (the percentile bootstrap does give a sensible interval, 0.151 to 0.370). (b) Both suggested remedies error for an incidence outcome (F1). The jackknife has no usable unit: `unit = "auto"`/`"block"` gives NA ("only 2 deletion units"; message again says "Use a randomization test"), and `unit = "observation"` gives NA with `Deletion unit "observation" is not supported on this blocking design because its blocks hold more than one subject; use unit = "block"`, i.e. it sends the user to the unit that just failed. The help's "the jackknife (resample within blocks)" is therefore not what happens.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2); n = 80
  A = sample(rep(0:1, 40)); B = integer(n)
  for (a in 0:1) B[A == a] = sample(rep(0:1, 20))
  y = rbinom(n, 1, 0.1 + 0.2 * A)
  des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B")
  des$add_all_subjects_to_experiment(data.frame(age = rnorm(n), B = factor(B)))
  des$assign_w_to_all_subjects(w_precomputed = A)
  des$add_all_subject_responses(y)
  inf = InferenceIncidRiskDiff$new(des)
  inf$set_seed(1)
  inf$compute_bootstrap_confidence_interval(B = 999, show_progress = FALSE)   # NA NA + warning
  inf$compute_jackknife_wald_confidence_interval()                          # NA NA + warning
  inf$compute_jackknife_wald_confidence_interval(unit = "observation")      # NA NA, "use unit = \"block\""
  inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE)          # the suggested remedy: error
  ```
- Workaround used, if any: `type = "percentile"` (or `"studentized"`) for the bootstrap; no jackknife.

### F4: `DesignFixedFactorial` accepts a non-integer number of levels (`list(subject = 2.5)`) and silently runs it as a two-level factor
- Kind: accepted bad input
- Expected (and where the docs say so): `?DesignFixedFactorial`, argument `factors`: "values are number of levels ... The product of levels across all factors must currently equal exactly 2 ... the constructor errors otherwise." 2.5 is not a number of levels and its product is 2.5, not 2.
- Observed: no error, no warning; `get_w_factorial()` returns a column `subject` with levels 1/2 and the design runs as a balanced two-arm design. (By contrast `list(a = 0.5, b = 4)` and `list(a = -2, b = -1)` are correctly refused.) Also, an unnamed `list(2)` is accepted and `get_w_factorial()` names the column `Var1`, though the help says the names are the factor names.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  d = DesignFixedFactorial$new(n = 10, response_type = "incidence", factors = list(subject = 2.5))
  d$add_all_subjects_to_experiment(data.frame(x = 1:10))
  d$assign_w_to_all_subjects()
  table(d$get_w_factorial()$subject)   # 1: 5, 2: 5 -- no error or warning
  ```
- Workaround used, if any: none needed (used `list(subject_line = 2)`).

### F5: The same marginal risk ratio is reported on the log scale by `InferenceIncidLogRegr` (`estimand = "marginal_ratio"`) but on the ratio scale by `InferenceIncidGCompRiskRatio`
- Kind: inconsistency
- Expected (and where the docs say so): `?InferenceIncidLogRegr`, "Estimand": under `"marginal_ratio"` "the log of the corresponding marginal risk ratio". `?InferenceIncidGCompRiskRatio`: "estimates the marginal (standardized) risk ratio RR = mean risk_1 / mean risk_0" from the same logistic working model. Both compute the identical g-computation quantity from the identical fit, so one would expect the same scale (or a clear note that they differ).
- Observed: on the main-effect-of-A design, `InferenceIncidLogRegr` with `set_estimand("marginal_ratio")` returns estimate `1.359686`, CI `[0.6832, 2.0361]`; `InferenceIncidGCompRiskRatio` returns estimate `3.89497`, CI `[1.9589, 7.7447]` (= exp of a CI with the HC0 sandwich SE). Same estimand, two scales; `delta` for a p-value test therefore also means different things in the two classes. A user comparing a "risk ratio" across classes in a factorial report gets 1.36 vs 3.89. (Both numbers were cross-checked by hand: manual g-computation from `glm()` gives log RR 1.359686, delta-method SE 0.34513 with the model covariance and 0.35068 with `sandwich::sandwich()`, matching the two classes exactly.)
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(4); n = 200
  w = sample(rep(0:1, n / 2)); x = rnorm(n)
  y = rbinom(n, 1, plogis(-2 + 1.3 * w + 0.3 * x))
  des = DesignFixediBCRD$new(n = n, response_type = "incidence")
  des$add_all_subjects_to_experiment(data.frame(x = x))
  des$assign_w_to_all_subjects(w_precomputed = w)
  des$add_all_subject_responses(y)
  lr = InferenceIncidLogRegr$new(des); lr$set_estimand("marginal_ratio")
  gr = InferenceIncidGCompRiskRatio$new(des)
  c(LogRegr_marginal_ratio = lr$compute_estimate(), GCompRiskRatio = gr$compute_estimate())
  # first is log(second)
  ```
- Workaround used, if any: exponentiated the `InferenceIncidLogRegr` result by hand.

### F6: The unequal-block error says "strata_cols was named without B_target" even when `B_target` was passed, and suggests passing `B_target`, which does not help; the help also says the check fires when subjects are added, but it fires at assignment
- Kind: false message
- Expected (and where the docs say so): `?DesignFixedBlocking`, argument `equal_block_sizes`: "A second check fires when subjects are added: if the covariate-based strata produce unequal block sizes the design errors at that point". This matters for the factorial recipe when `n` is not divisible by 4 (the article's "What this recipe does not cover: Unequal cells"): the main-effect design for A is blocked on B, whose levels then have unequal sizes.
- Observed: `add_all_subjects_to_experiment()` succeeds silently; the error comes only at `assign_w_to_all_subjects()` (with or without `w_precomputed`). With `B_target = 2` given explicitly, the message still reads:
  `equal_block_sizes = TRUE but the strata produced unequal block sizes (98, 100) for n = 198 (2 blocks from strata_cols = B). Because strata_cols was named without B_target, all of it is used and the block sizes are determined by the data. Set equal_block_sizes = FALSE to allow unequal blocks, or adjust the strata_cols / covariate binning (or pass an explicit B_target) so that every block has the same size.`
  The "Because strata_cols was named without B_target" clause is false for this call, and the "pass an explicit B_target" advice was just followed and did not help (a categorical column with 98/100 subjects can never be equalised by `B_target`). `equal_block_sizes = FALSE` does work.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(5); n = 198
  X = data.frame(age = rnorm(n), B = factor(rep(0:1, c(100, 98))))
  d = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B", B_target = 2)
  d$add_all_subjects_to_experiment(X)       # no error here, contrary to the help
  d$assign_w_to_all_subjects()              # error: "...Because strata_cols was named without B_target..."
  ```
- Workaround used, if any: `equal_block_sizes = FALSE` (then `InferenceIncidCMH` and `InferenceIncidExtendedRobins` refuse, as documented).

### F7: `InferenceIncidExactFisher$compute_estimate()` returns a bare `NA` with no warning when one arm has no events, while its exact CI and p-value are finite and `fisher.test`/`mantelhaen.test` give an odds ratio of `Inf`
- Kind: silent NA
- Expected (and where the docs say so): `?InferenceIncidExactFisher`: the estimate is "the log of the (conditional MLE, or common-odds-ratio if stratified) odds ratio from `fisher.test` or `mantelhaen.test`". With zero events in the control arm those give OR = `Inf`, so the log is `Inf` (the CI's upper bound is indeed reported as `Inf`). If EDI prefers `NA`, it should warn (other classes raise `edi_procedure_na_warning` / `edi_logistic_separation_warning` in this situation) or mark the result non-estimable.
- Observed: on a small 2 x 2 test (n = 40, the A = 0 arm had 0 of 20 purchases), `compute_estimate()` returns `NA` with no warning or message; `compute_exact_confidence_interval()` returns `0.5511387 Inf` (= `log(1.735228)` from `mantelhaen.test(exact = TRUE)`, matches) and the p-value `0.00912498` (matches). Same `NA` on an unstratified `DesignFixediBCRD`. The CI therefore has no point estimate to contain, and code that checks `is.na(est)` will treat a significant, very strong effect as missing.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(9); n = 40
  A = sample(rep(0:1, 20)); B = integer(n); for (a in 0:1) B[A == a] = sample(rep(0:1, 10))
  y = ifelse(A == 0, 0L, rbinom(n, 1, 0.4))     # no purchases at all in the A = 0 arm
  des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B")
  des$add_all_subjects_to_experiment(data.frame(age = rnorm(n), B = factor(B)))
  des$assign_w_to_all_subjects(w_precomputed = A)
  des$add_all_subject_responses(y)
  fe = InferenceIncidExactFisher$new(des)
  fe$compute_estimate()                         # NA, no warning
  fe$compute_exact_confidence_interval()        # 0.551 Inf
  fe$compute_exact_two_sided_pval_for_treatment_effect()   # 0.009125
  mantelhaen.test(table(factor(A, 1:0), factor(y, 1:0), B), exact = TRUE)$estimate   # Inf
  ```
- Workaround used, if any: reported the risk difference (Newcombe / Miettinen-Nurminen / CMH) instead of the odds ratio for that sparse case.
