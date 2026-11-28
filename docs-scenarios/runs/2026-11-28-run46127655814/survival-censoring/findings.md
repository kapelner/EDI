# Findings: survival-censoring (run 2026-11-28)

### F1: `InferenceSurvivalWeibullRegr$compute_asymp_two_sided_pval()` / `compute_asymp_confidence_interval()` ignore `set_testing_type()` and always return the Wald result, while `get_testing_type()` reports the type the user set
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceAsympLik`, `set_testing_type()`: "Sets the asymptotic testing method used by p-values and CIs"; `compute_asymp_two_sided_pval()`: "Depending on `testing_type`, this evaluates a Wald, score, likelihood-ratio, gradient, or Bartlett-corrected likelihood-ratio statistic". `?InferenceSurvivalWeibullRegr` says LR, score, gradient and Wald tests "are all available", and `get_supported_testing_types()` lists all five types. `InferenceSurvivalCoxPHRegr` does switch on the same calls.
- Observed: For every supported type (`wald`, `score`, `gradient`, `lik_ratio`, `lik_ratio_bartlett_approx`), `get_testing_type()` echoes the type, but `compute_asymp_two_sided_pval()` = 0.0544503 and `compute_asymp_confidence_interval()` = (-0.00719966, 0.761226) every time, which is the Wald result. The direct methods give the right numbers: `compute_lik_ratio_two_sided_pval()` = 0.0499552 (equal to `survreg`'s LR p, 0.0499552), and score p = 0.0404303. So a user who sets `testing_type = "lik_ratio"` gets "not significant at 5%" when the LR test they asked for says p < 0.05. There is no warning. The same holds with `set_optimization_alg("newton_raphson")`, on a fresh object whose type was set before the first compute, and on the 80-patient trial data with factor covariates (asymp p 9.297e-05 = Wald; LR 1.366e-04; score 1.490e-06).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); library(survival)
  set.seed(1)
  n = 80
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
  des$assign_w_to_all_subjects(); w = des$get_w()
  t = rweibull(n, 1.3, 10 * exp(0.6 * w)); cens = 15
  des$add_all_subject_responses(ys = ifelse(t <= cens, t, NA), y_Ls = ifelse(t <= cens, NA, cens),
                                y_Rs = ifelse(t <= cens, NA, Inf))
  inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
  for (tt in inf$get_supported_testing_types()) {
    inf$set_testing_type(tt)
    cat(sprintf("%-26s get_testing_type=%-26s asymp p=%.6g  asymp CI=%s\n", tt, inf$get_testing_type(),
        inf$compute_asymp_two_sided_pval(), paste(signif(inf$compute_asymp_confidence_interval(), 6), collapse = ", ")))
  }
  cat("direct: wald p", inf$compute_wald_two_sided_pval(), " LR p", inf$compute_lik_ratio_two_sided_pval(),
      " score p", inf$compute_score_two_sided_pval(), "\n")
  d = data.frame(y = pmin(t, cens), ev = as.integer(t <= cens), w, x = des$get_X()[, "x"])
  f1 = survreg(Surv(y, ev) ~ w + x, d, dist = "weibull"); f0 = survreg(Surv(y, ev) ~ x, d, dist = "weibull")
  cat("survreg LR p", pchisq(2 * (f1$loglik[2] - f0$loglik[2]), 1, lower.tail = FALSE), "\n")
  ic = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)   # Cox does switch
  ic$set_testing_type("wald"); a = ic$compute_asymp_two_sided_pval()
  ic$set_testing_type("lik_ratio"); b = ic$compute_asymp_two_sided_pval()
  cat("Cox asymp p wald", a, " lik_ratio", b, "\n")
  ```
- Workaround used, if any: call the direct methods (`compute_lik_ratio_two_sided_pval()`, `compute_lik_ratio_confidence_interval()`, `compute_score_*`, `compute_gradient_*`). They match `survreg` and hand-computed score/gradient tests to 6+ digits.

### F2: `?InferenceSurvivalWeibullRegr` (and `?InferenceSurvivalDepCensTransformRegr`) no longer document the constructor or the core methods, and show developer-internal text instead
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): Like `?InferenceSurvivalCoxPHRegr`, the class page should list `$new()` with its arguments (`des_obj`, `model_formula`, `verbose`, ...) and `compute_estimate()` / `compute_asymp_*`. The article "Censored Survival Outcomes" calls `InferenceSurvivalWeibullRegr$new(des_ic, verbose = FALSE)`.
- Observed: The Methods section of `?InferenceSurvivalWeibullRegr` lists only `approximate_randomization_distribution_beta_hat_T()`, `supports_rand_pval_for_incidence()`, `compute_lik_ratio_bootstrap_two_sided_pval()`, `compute_lik_ratio_bootstrap_confidence_interval()` and `clone()`. There is no `$new()`, and `formals(InferenceSurvivalWeibullRegr$new)` is just `...`, so the arguments cannot be found anywhere. The Description has orphaned method text pasted into it ("Computes the randomization distribution of the treatment effect estimate under the sharp null." and "Whether `compute_rand_two_sided_pval()` is actually usable ... (see `private$should_use_design_randomization_for_incidence()`) ... the single source of truth for both this check and ..., so the two can never drift apart."). The Value section mixes two methods' returns ("a numeric vector of length `r`" ... "A single logical."). `?InferenceSurvivalDepCensTransformRegr` likewise has no `$new()`. Separately, `?InferenceSurvivalCoxPHRegr`'s `$new()` entry begins with a developer note ("Deliberately pulled from `InferenceRand`, not `InferenceRandCI` ... its body calls `super$...()` ... merged flatly by the component system ... confirmed by tracing the body, not assumed") that is about the randomization p-value, not the constructor.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  db = tools::Rd_db("EDI")
  txt = function(n) paste(capture.output(tools::Rd2txt(db[[paste0(n, ".Rd")]], out = stdout())), collapse = "\n")
  for (n in c("InferenceSurvivalWeibullRegr", "InferenceSurvivalDepCensTransformRegr", "InferenceSurvivalCoxPHRegr"))
    cat(n, ": lists method $new() =", grepl(paste0(n, "$new()"), txt(n), fixed = TRUE),
        "; mentions private$ =", grepl("private$", txt(n), fixed = TRUE),
        "; mentions 'super$' =", grepl("super$", txt(n), fixed = TRUE), "\n")
  print(names(formals(InferenceSurvivalWeibullRegr$new)))   # "..."
  ```
- Workaround used, if any: assumed the Weibull constructor takes the same arguments as `?Inference` `$new()` (`des_obj`, `verbose`, `harden`, `model_formula`, `smart_cold_start_default`, `seed`); `model_formula` and `verbose` were accepted.

### F3: For survival classes without a Bartlett factor, `compute_lik_ratio_bartlett_exact/approx_*` warn that a null-restricted refit failed, and the "best available" method's error points to `supports_bartlett_likelihood_ratio_exact()` / `_approx()`, which do not exist on the object
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceAsympLik`, `compute_lik_ratio_bartlett_exact_two_sided_pval()`: "Returns `NA_real_` for subclasses that do not implement an exact, bespoke analytic Bartlett correction factor". The reason given should say this, and the methods the error names should exist.
- Observed: `InferenceSurvivalCoxPHRegr$compute_lik_ratio_bartlett_exact_two_sided_pval()` (and `_approx_`) return `NA` with: "InferenceSurvivalCoxPHRegr: the lik_ratio_bartlett_exact test is unavailable (NA) although the Wald result is finite. Reason: no error message was recorded (the null-restricted refit, score, or log-likelihood evaluation returned a non-finite or unusable value). ..." The real reason, per `compute_lik_ratio_bartlett_two_sided_pval()`, is "InferenceSurvivalCoxPHRegr does not support Bartlett-corrected likelihood-ratio inference (neither an exact nor an approximate factor is implemented). See supports_bartlett_likelihood_ratio_exact() / supports_bartlett_likelihood_ratio_approx()." But `ic$supports_bartlett_likelihood_ratio_exact()` fails with "attempt to apply non-function", and no `supports_bartlett*` member is in `ls(ic)`. `InferenceSurvivalWeibullRegr$compute_lik_ratio_bartlett_exact_two_sided_pval()` gives the same misleading "refit ... non-finite" warning (Weibull has only the approximate factor).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 80
  des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
  des$assign_w_to_all_subjects(); w = des$get_w()
  t = rweibull(n, 1.3, 10 * exp(0.6 * w)); cens = 15
  des$add_all_subject_responses(ys = ifelse(t <= cens, t, NA), y_Ls = ifelse(t <= cens, NA, cens),
                                y_Rs = ifelse(t <= cens, NA, Inf))
  ic = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
  print(ic$compute_lik_ratio_bartlett_exact_two_sided_pval())   # NA, warning blames a refit
  print(try(ic$compute_lik_ratio_bartlett_two_sided_pval()))   # error naming supports_bartlett_*()
  print(try(ic$supports_bartlett_likelihood_ratio_exact()))    # attempt to apply non-function
  print(grep("supports", ls(ic), value = TRUE))
  iw = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
  print(iw$compute_lik_ratio_bartlett_exact_two_sided_pval())   # NA, same misleading warning
  ```
- Workaround used, if any: for Weibull, `compute_lik_ratio_bartlett_approx_two_sided_pval(B = 99)` returns a finite value. For Cox, no Bartlett correction is available.
