# Findings: survival-censoring

### F1: `InferenceSurvivalWeibullRegr` with its default L-BFGS optimizer stops short of the Weibull MLE, so the time-ratio estimate and Wald CI disagree with `survival::survreg` in the 3rd significant digit
- Kind: reference mismatch
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSurvivalWeibullRegr` Description: the Weibull AFT model is fitted "by maximum likelihood (`fast_weibull_regression_cpp`)"; the fit should be the MLE, i.e. the same coefficient `survreg(..., dist = "weibull")` reports (to at least 3 digits). `?fast_weibull_regression` presents `survreg` as the "fallback/cross-check implementation".
- Observed (exact output, including the exact message text): on an n = 80 right-censored trial (59 events, 21 censored) the default fit gives log time ratio 0.4776586 (CI 0.1456572, 0.8096599); survreg gives 0.4771847 (CI 0.1452363, 0.8091330). Rounded to 3 digits: 0.478 vs 0.477. The profile log-likelihood at EDI's value (-187.521984957) is lower than at survreg's (-187.521981043), so EDI's value is not the maximum. No warning is given. After `inf$set_optimization_alg("newton_raphson")` EDI returns 0.4771847, identical to survreg. The exported `fast_weibull_regression(..., optimization_alg = "lbfgs")` gives yet another value on the same data (0.4767957). The likelihood-ratio p-value agrees (0.00442102 vs 0.00442148), so only the point estimate / Wald path is off.
```
                         2.5%     97.5%
EDI_lbfgs 0.4776586 0.1456572 0.8096599
survreg   0.4771847 0.1452363 0.8091330
    loglik_at_EDI loglik_at_survreg 
   -187.521984957    -187.521981043 
[1] 0.4771847
```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages({library(EDI); library(survival)})
  set.seed(20261118); n = 80
  X = data.frame(age = round(rnorm(n, 62, 9)), ecog = sample(0:1, n, replace = TRUE))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t_ev = rweibull(n, shape = 1.3, scale = 10 * exp(0.5 * w - 0.02 * (X$age - 62) - 0.3 * X$ecog))
  fu = round(18 - runif(n, 0, 10), 2); obs = t_ev <= fu; tm = ifelse(obs, round(t_ev, 2), fu)
  des$add_all_subject_responses(ys = ifelse(obs, tm, NA), y_Ls = ifelse(obs, NA, tm), y_Rs = ifelse(obs, NA, Inf))
  inf = InferenceSurvivalWeibullRegr$new(des)
  edi = c(inf$compute_estimate(), inf$compute_asymp_confidence_interval())
  g = survreg(Surv(tm, as.integer(obs)) ~ w + age + ecog, data = X, dist = "weibull")
  ref = c(coef(g)["w"], confint(g)["w", ])
  print(rbind(EDI_lbfgs = edi, survreg = ref), digits = 7)
  prof = function(b) survreg(Surv(tm, as.integer(obs)) ~ age + ecog + offset(b * w), data = X, dist = "weibull")$loglik[2]
  print(c(loglik_at_EDI = prof(edi[1]), loglik_at_survreg = prof(ref[1])), digits = 12)
  inf$set_optimization_alg("newton_raphson"); print(inf$compute_estimate(), digits = 7)
  ```
  The interval-censored example in the "Censored Survival Outcomes" article (chunk `ic-weibull`, `set.seed(7)`, visit-grid data) shows it too, and more strongly: EDI default 0.4444174 (CI 0.2159627, 0.6728722); `survreg(Surv(L, R, type = "interval2") ~ w + age, dist = "weibull")` gives 0.4430507 (CI 0.2142598, 0.6718417); EDI with `newton_raphson` gives 0.4430507. Second repro (the article's data):
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages({library(EDI); library(survival)})
  set.seed(7); n = 120
  X = data.frame(age = round(rnorm(n, 60, 10)))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t_event = rweibull(n, shape = 1.5, scale = 12 * exp(0.4 * w - 0.02 * (X$age - 60)))
  visits = seq(3, 24, by = 3)
  y_L = sapply(t_event, function(t) max(c(0, visits[visits < t])))
  y_R = sapply(t_event, function(t) if (t > max(visits)) Inf else min(visits[visits >= t]))
  des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
  inf = InferenceSurvivalWeibullRegr$new(des)
  print(c(EDI_default = inf$compute_estimate(), inf$compute_asymp_confidence_interval()), digits = 7)
  g = survreg(Surv(ifelse(y_L == 0, NA, y_L), ifelse(is.infinite(y_R), NA, y_R), type = "interval2") ~ w + age, data = X, dist = "weibull")
  print(c(survreg = coef(g)["w"], confint(g)["w", ]), digits = 7)
  inf$set_optimization_alg("newton_raphson"); print(inf$compute_estimate(), digits = 7)
  ```
- Workaround used, if any: `inf$set_optimization_alg("newton_raphson")` before estimating. The help page does not list the valid optimizer names for this class (`?Inference` says "Valid values are configured by the concrete inference class"); I took `"newton_raphson"` from `?fast_weibull_regression`'s `optimization_alg` argument.

### F2: `fast_weibull_regression(use_rcpp = FALSE)` reports "failed to converge" when the real problem is an empty column name in `X`
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?fast_weibull_regression` Arguments: `X` is "A numeric matrix of predictor variables"; `use_rcpp = FALSE` uses `survreg` as the cross-check. Any numeric matrix should fit (the Rcpp path accepts the same matrix), or the error should say that column names must be non-empty.
- Observed (exact output, including the exact message text): with `X = cbind(w, d$age)` (column names `"w"`, `""`, the normal result of `cbind` on an expression) the Rcpp path fits fine, but the survreg path stops with `Error in value[[3L]](cond) : Weibull regression failed to converge: attempt to use zero-length variable name`. Nothing failed to converge; the message points at the wrong problem. A matrix with no column names at all works.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); d = data.frame(age = rnorm(100, 60, 10)); w = rbinom(100, 1, 0.5)
  y = rexp(100, 0.1); dead = rbinom(100, 1, 0.7)
  X = cbind(w, d$age)            # colnames c("w", "")
  print(fast_weibull_regression(y, dead, X)$coefficients)                 # Rcpp path: fine
  print(try(fast_weibull_regression(y, dead, X, use_rcpp = FALSE)))       # survreg path: "failed to converge"
  ```
- Workaround used, if any: give every column a name (`colnames(X) = c("w", "age")`).

### F3: An exact event time of 0 is accepted by the design, and `InferenceSurvivalWeibullRegr` then returns `NA` estimate, CI and p-value with no warning
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): either `add_all_subject_responses()` rejects `y = 0` for a survival response (a Weibull time must be > 0; `survreg` stops with "Invalid survival times for this distribution"), or the Weibull class warns/errors saying why it cannot fit. The rule in the task brief and the Inference docs is that an `NA` on finite inputs should come with a reason.
- Observed (exact output, including the exact message text): `add_all_subject_responses(ys = y)` with `y[1] = 0` is accepted (the assertion is only `y >= 0`). `InferenceSurvivalWeibullRegr` then prints `est NA, NA, NA, p NA` with no warning or message. Only `inf$is_nonestimable()` = `TRUE` and `get_nonestimable_reason()` = `"model_fit_unavailable"` hint at it, and that reason does not mention the zero time. Cox, log-rank and RMST give finite results on the same design.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(3); n = 60
  X = data.frame(age = rnorm(n, 60, 10))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  y = round(rweibull(n, 1.3, 10 * exp(0.5 * w)), 2)
  y[1] = 0                                   # accepted by add_all_subject_responses (y >= 0)
  des$add_all_subject_responses(ys = y)
  inf = InferenceSurvivalWeibullRegr$new(des)
  withCallingHandlers({
    print(c(est = inf$compute_estimate(), inf$compute_asymp_confidence_interval(),
            p = inf$compute_asymp_two_sided_pval()))
  }, warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
  print(inf$is_nonestimable()); print(inf$get_nonestimable_reason())
  ```
- Workaround used, if any: none needed for the main analysis (no zero times). A user would record a progression found at time 0 as left-censored (`y_L = 0, y_R = <first assessment>`).

### F4: `InferenceSurvivalKMDiff$compute_asymp_two_sided_pval()` returns `NA` while `compute_asymp_confidence_interval()` on the same object is finite, and the warning's fix (`na.rm = TRUE`) cannot be passed to the method the user called
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSurvivalKMDiff` Description: when a Brookmeyer-Crowley bound is non-finite, "the Wald-style confidence interval and p-value methods (`$compute_asymp_confidence_interval()`, `$compute_asymp_two_sided_pval()`) fall back to a nonparametric bootstrap instead of returning `NA`". Both should fall back the same way and give a usable result.
- Observed (exact output, including the exact message text): the asymptotic CI is `2.246333 8.740000`, but the asymptotic p-value is `NA` with:
  `InferenceSurvivalKMDiff: compute_bootstrap_two_sided_pval() returned NA because 2 of 501 bootstrap replicates were non-finite (na.rm = FALSE, the default, returns NA if any replicate is non-finite). The bootstrap confidence interval drops non-finite replicates, so it can be finite for the same object; na.rm = TRUE would drop them here too ...`
  Following the message on the method I called fails: `km$compute_asymp_two_sided_pval(na.rm = TRUE)` gives `unused argument (na.rm = TRUE)`. Only calling a different method, `compute_bootstrap_two_sided_pval(na.rm = TRUE)`, gives a p-value (0.004008016). The same happens on interval-censored data, where this method always uses the bootstrap.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(20261118); n = 80
  X = data.frame(age = round(rnorm(n, 62, 9)), ecog = sample(0:1, n, replace = TRUE))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t_ev = rweibull(n, shape = 1.3, scale = 10 * exp(0.5 * w - 0.02 * (X$age - 62) - 0.3 * X$ecog))
  fu = round(18 - runif(n, 0, 10), 2); obs = t_ev <= fu; tm = ifelse(obs, round(t_ev, 2), fu)
  des$add_all_subject_responses(ys = ifelse(obs, tm, NA), y_Ls = ifelse(obs, NA, tm), y_Rs = ifelse(obs, NA, Inf))
  km = InferenceSurvivalKMDiff$new(des)
  km$set_seed(1); print(km$compute_asymp_confidence_interval())   # finite
  km$set_seed(1); print(km$compute_asymp_two_sided_pval())        # NA + warning recommending na.rm = TRUE
  print(try(km$compute_asymp_two_sided_pval(na.rm = TRUE)))        # unused argument
  km$set_seed(1); print(km$compute_bootstrap_two_sided_pval(na.rm = TRUE))
  ```
- Workaround used, if any: `compute_bootstrap_two_sided_pval(na.rm = TRUE)`, plus the randomization p-value.

### F5: On interval-censored data, `InferenceSurvivalCoxPHRegr` lists score / gradient / lik_ratio as supported testing types and accepts `set_testing_type("score")`, but then gives NA, a Wald interval relabelled, or an error, depending on which method is called
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSurvivalCoxPHRegr` Description: on the left-/interval-censored path "only Wald inference (`testing_type = "wald"`) is supported ...; score/gradient/likelihood-ratio/Bartlett testing types raise an informative error for such data". So `get_supported_testing_types()` should return only `"wald"` for this object, and `set_testing_type("score")` or `compute_lik_ratio_two_sided_pval()` should raise that error.
- Observed (exact output, including the exact message text):
  - `get_supported_testing_types()` returns `"wald" "score" "gradient" "lik_ratio"`.
  - `compute_lik_ratio_two_sided_pval()` returns `NA` with a warning (not the documented error) that names an internal: `Reason: get_likelihood_test_spec() returned NULL (the model fit exposes no likelihood specification). ... use testing_type = "wald"`. The constructor has no `testing_type` argument (`InferenceSurvivalCoxPHRegr$new(des, testing_type = "wald")` gives `unused argument`); the setter is `set_testing_type()`, which the message does not name.
  - `compute_score_confidence_interval()` returns the Wald interval with a warning.
  - `set_testing_type("score")` is accepted silently, and only the next `compute_asymp_two_sided_pval()` raises `testing_type = 'score' is not supported for left-/interval-censored survival data ...`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(7); n = 120
  X = data.frame(age = round(rnorm(n, 60, 10)))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t_event = rweibull(n, shape = 1.5, scale = 12 * exp(0.4 * w - 0.02 * (X$age - 60)))
  visits = seq(3, 24, by = 3)
  y_L = sapply(t_event, function(t) max(c(0, visits[visits < t])))
  y_R = sapply(t_event, function(t) if (t > max(visits)) Inf else min(visits[visits >= t]))
  des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
  cox = InferenceSurvivalCoxPHRegr$new(des)
  print(cox$get_supported_testing_types())       # lists score / gradient / lik_ratio
  print(cox$compute_lik_ratio_two_sided_pval())   # NA + warning naming get_likelihood_test_spec()
  print(cox$compute_score_confidence_interval())
  cox$set_testing_type("score")                   # accepted without complaint
  print(try(cox$compute_asymp_two_sided_pval()))  # now an error
  ```
- Workaround used, if any: keep the default `"wald"` testing type for interval-censored Cox fits.

### F6: Error messages for survival classes point users to repo-internal design documents that are not shipped with the package
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): an error should point to installed documentation (a help topic or the "Censored Survival Outcomes" article, which has the "Which classes accept interval censoring" section).
- Observed (exact output, including the exact message text):
  - `InferenceSurvivalStratCoxPHRegr$new()` on interval-censored data: `... This class only accepts exact and right-censored (y_R = Inf) responses -- see interval_censored_survival_response.md for which classes support the general case.` (the same text from `InferenceSurvivalDepCensTransformRegr`)
  - `InferenceSurvivalCoxPHRegr$compute_rand_confidence_interval()`: `... See R/package_metadata/new_feature_plans/v1_0_5/randomization_ci_construction_audit.md, section A.`
  Neither file exists in the installed package (`file.exists(...)` is `FALSE FALSE`), and the user cannot get to the repo.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n = 40
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
  y = rexp(n, 0.1); yL = ifelse(seq_len(n) <= 3, floor(y), NA); yR = ifelse(seq_len(n) <= 3, floor(y) + 1, NA)
  des$add_all_subject_responses(ys = ifelse(seq_len(n) <= 3, NA, y), y_Ls = yL, y_Rs = yR)
  print(try(InferenceSurvivalStratCoxPHRegr$new(des)))
  des2 = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des2$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des2$assign_w_to_all_subjects(); des2$add_all_subject_responses(ys = y)
  print(try(InferenceSurvivalCoxPHRegr$new(des2)$compute_rand_confidence_interval(r = 99, show_progress = FALSE)))
  print(file.exists(file.path(find.package("EDI"), c("interval_censored_survival_response.md", "R/package_metadata"))))
  ```
- Workaround used, if any: used the article's class list (`censored-survival-outcomes`, "Which classes accept interval censoring").

### F7: `?InferenceSurvivalRestrictedMeanDiff` names a design class, `DesignFixedBCRD`, that does not exist
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSurvivalRestrictedMeanDiff` Description, "The standard error assumes independent arms", lists the designs where the Greenwood SE is correct: "`DesignSeqOneByOneBernoulli`, `DesignFixedBernoulli`, `DesignFixedBCRD`, `DesignFixediBCRD`, `DesignSeqOneByOneiBCRD`". Every name listed should be an exported class.
- Observed (exact output, including the exact message text): `DesignFixedBCRD$new(...)` gives `Error: object 'DesignFixedBCRD' not found`. The exported BCRD/Bernoulli designs are `DesignFixedBernoulli`, `DesignFixediBCRD`, `DesignSeqOneByOneBernoulli` and `DesignSeqOneByOneiBCRD`, and no help alias `DesignFixedBCRD` exists.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  print(grep("BCRD|Bernoulli", ls("package:EDI"), value = TRUE))
  print(exists("DesignFixedBCRD"))
  print(try(DesignFixedBCRD$new(n = 10, response_type = "survival")))
  ```
- Workaround used, if any: used `DesignFixediBCRD`.

### F8: `InferenceSuite$run_all_inference()` prints `p = NA` for every estimand that has only one inference class, although that class's p-value is finite in the same table
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): the per-estimand summary lines under the results table (cookbook-survival, "Everything at once") should show a p-value for each estimand. With one inference in the group, that is the class's own p-value (e.g. Gehan-Wilcoxon 0.561 in the table).
- Observed (exact output, including the exact message text): right-censored n = 100 trial:
  ```
  Gehan Wilcox             gehan wil…  -0.0570   0.0933    5.61e-01   wald            ok
  ...
    Estimand: gehan wilcoxon statistic (1 inferences)  : p =    NA
    Estimand: log hazard ratio (2 inferences)          : p = 0.686
    Estimand: log rank martingale Δ (1 inferences)     : p =    NA
    Estimand: log time ratio (2 inferences)            : p = 0.677
    Estimand: mean Δ (1 inferences)                    : p =    NA
    Estimand: restr mean survival time Δ (1 inferences): p =    NA
  ```
  Every "(1 inferences)" line is `NA`, and every "(2 inferences)" line is finite. No warning is given. On my interval-censored trial every estimand had one inference, so all five lines were `p = NA` while the overall combined p (0.0173) was finite. In the same suite run the Kaplan-Meier row on the interval-censored data showed `se NA, pval NA` with status `ok`, and no warning was passed on.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(2); n = 100
  X = data.frame(age = round(rnorm(n, 60, 10)))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t = rexp(n, exp(-1 - 0.6 * w)); fu = 3 - runif(n, 0, 2); obs = t <= fu
  des$add_all_subject_responses(ys = ifelse(obs, t, NA), y_Ls = ifelse(obs, NA, fu), y_Rs = ifelse(obs, NA, Inf))
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 1L,
                                                 methods = "wald", max_secs_per_class = 10)
  str(res$combined_evidence, max.level = 1)
  ```
- Workaround used, if any: read the per-class p-values from the table (`res$results_table`), not the per-estimand lines.

### F9: On interval-censored data, `InferenceSurvivalCoxPHRegr`'s Wald CI and p-value change with the global RNG state even after `set_seed()`, so the "asymptotic" p-value is not reproducible from the object's seed
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Inference` `set_seed()`: "Set the seed for reproducibility. The seed governs the parallel resampling workers ..."; the article "Censored Survival Outcomes" says the interval-censored bootstrap results are "reproducible after `set_seed()`". `?InferenceSurvivalCoxPHRegr` says the SEs on this path "come from `icenReg`'s own internal bootstrap". Since that bootstrap is resampling, it should follow the object's seed, or the docs should say that `compute_asymp_*` is random here and depends on `set.seed()`.
- Observed (exact output, including the exact message text): same design, same object seed 123, only the global seed differs:
  ```
  object seed 123, global seed 1 : -1.086698 -0.3260422 0.0002724541
  object seed 123, global seed 2 : -1.093131 -0.3196098 0.0003440785
  object seed 123, global seed 1 : -1.086698 -0.3260422 0.0002724541
  ```
  On my trial data this moved the Wald p-value across 0.05 between runs (0.0437 in one script, 0.0571 in another, and 0.0689 inside `InferenceSuite`) with no message. The result is also cached on the object after the first call, so a later `set_seed()` on the same object has no effect.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(7); n = 120
  X = data.frame(age = round(rnorm(n, 60, 10)))
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  t_event = rweibull(n, shape = 1.5, scale = 12 * exp(0.4 * w - 0.02 * (X$age - 60)))
  visits = seq(3, 24, by = 3)
  y_L = sapply(t_event, function(t) max(c(0, visits[visits < t])))
  y_R = sapply(t_event, function(t) if (t > max(visits)) Inf else min(visits[visits >= t]))
  des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
  for (global in c(1, 2, 1)) {
    inf = InferenceSurvivalCoxPHRegr$new(des); inf$set_seed(123)
    set.seed(global)                               # unrelated global RNG state
    cat("object seed 123, global seed", global, ":", inf$compute_asymp_confidence_interval(), inf$compute_asymp_two_sided_pval(), "\n")
  }
  ```
- Workaround used, if any: call `set.seed()` right before the first `compute_asymp_*` call. For the report, use a nonparametric bootstrap CI and randomization p-value from the object seed.
