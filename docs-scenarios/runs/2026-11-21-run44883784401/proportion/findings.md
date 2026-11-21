# Findings: proportion (EDI v1.0.4)

### F1: `InferencePropBetaRegr` silently rewrites every response with the Smithson-Verkuilen squeeze when the data has exact 0s or 1s, and the help page points to a `sanitize_beta_response()` that has no documentation
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropBetaRegr`, Description, says only "Y_i values of exactly 0 or 1 ... are handled by `sanitize_beta_response()`'s boundary adjustment before fitting". `sanitize_beta_response` is not exported, has no help topic (`help.search("sanitize", package = "EDI")` returns 0 rows), and no vignette explains it. I expected the page to say what the adjustment is, and a warning or message when the response is changed, because the adjustment can flip the sign of the treatment effect.
- Observed (exact output, including the exact message text): no warning and no message. The estimate equals `betareg` on `(y*(n-1)+0.5)/n` to 7 digits, so every response is moved (interior ones too), not just the 0s and 1s. With 12/100 boundary values: EDI gives `0.1908109` (CI -0.242, 0.624), `betareg` on the squeezed y gives `0.1908109`, `betareg` on the interior rows gives `0.8017052`. In my main data set (9 zeros, 8 ones, n = 150, true logit shift +0.6), EDI gave -0.110 (p = 0.53), while the fractional logit gave +0.303 and the ZOIB interior coefficient +0.702.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages({library(EDI); library(betareg)})
  set.seed(1)
  n = 100
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
  des$assign_w_to_all_subjects(); w = des$get_w()
  y = rbeta(n, 8 * plogis(-0.5 + 0.7 * w), 8 * (1 - plogis(-0.5 + 0.7 * w)))
  y[1:6] = 0; y[7:12] = 1                       # 12 exact boundary values
  des$add_all_subject_responses(y)
  inf = InferencePropBetaRegr$new(des)
  withCallingHandlers(print(c(est = inf$compute_estimate(), inf$compute_asymp_confidence_interval())),
    warning = function(w) cat("WARNING:", conditionMessage(w), "\n"),
    message = function(m) cat("MESSAGE:", conditionMessage(m), "\n"))
  ysv = (y * (n - 1) + 0.5) / n                 # Smithson-Verkuilen squeeze
  print(coef(betareg(ysv ~ w + x, data = data.frame(ysv, w, x = des$get_X()[, "x"])))["w"])
  print(coef(betareg(y ~ w + x, data = data.frame(y, w, x = des$get_X()[, "x"]), subset = y > 0 & y < 1))["w"])
  ```
- Workaround used, if any: worked out the transform by matching `betareg` on several candidate squeezes; used `InferencePropZeroOneInflatedBetaRegr` or `InferencePropFractionalLogit` for the boundary data.

### F2: `InferencePropQuantileRegr` silently clamps exact 0s/1s to machine epsilon before the logit, so at a low or high `tau` the "log-odds shift" is about ±34 with p ~ 1e-117 and no warning
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropQuantileRegr`, Description: "proportion responses (constrained to (0, 1))", "responses y in (0,1) are transformed via logit(y)". Nothing is said about exact 0 or 1. I expected either an error or a warning that boundary values were moved, or a documented, sensible adjustment. The design accepts y = 0 and y = 1 for `response_type = "proportion"`, and the other proportion classes take them.
- Observed (exact output, including the exact message text): no warning or message. The estimate equals `quantreg::rq` on `qlogis(pmin(pmax(y, .Machine$double.eps), 1 - .Machine$double.eps))` (logit(0) is then -36.04). Repro output: `est -3.408015e+01, CI (-3.452322e+01, -3.363708e+01), p 2.275936e-117`. With a 1e-6 clamp, `rq` gives -11.85, so the answer depends on an undocumented constant. On my main data (9 zeros, 8 ones, n = 150): tau = 0.03 gave -34.01 (p 9e-131) and tau = 0.97 gave -35.06 (p 5e-109). At tau = 0.1 and 0.9 the point estimate is not affected, but the ±36 outliers make the "nid" CI (-18.6, 18.7).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages({library(EDI); library(quantreg)})
  set.seed(2)
  n = 100
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
  des$assign_w_to_all_subjects(); w = des$get_w()
  y = rbeta(n, 3, 5); y[which(w == 1)[1:6]] = 0      # 6 exact zeros, all treated
  des$add_all_subject_responses(y)
  inf = InferencePropQuantileRegr$new(des, tau = 0.05)
  withCallingHandlers(print(c(est = inf$compute_estimate(), inf$compute_asymp_confidence_interval(),
                              p = inf$compute_asymp_two_sided_pval())),
    warning = function(w) cat("WARNING:", conditionMessage(w), "\n"),
    message = function(m) cat("MESSAGE:", conditionMessage(m), "\n"))
  x = des$get_X()[, "x"]; e = .Machine$double.eps
  print(coef(rq(qlogis(pmin(pmax(y, e), 1 - e)) ~ w + x, tau = 0.05))["w"])    # same as EDI
  print(coef(rq(qlogis(pmin(pmax(y, 1e-6), 1 - 1e-6)) ~ w + x, tau = 0.05))["w"]) # clamp choice drives the answer
  ```
- Workaround used, if any: used tau = 0.25 / 0.5 / 0.75 only, where the point estimate does not depend on the clamp.

### F3: `InferencePropQuantileRegr$new(tau = 1)` is rejected with "Element 1 is not <= 1", which is false for 1
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropQuantileRegr`, `new()` argument `tau`: "The quantile to estimate. Default 0.5." No range is given. Rejecting tau = 1 is fine, but the message should give the real rule (0 < tau < 1).
- Observed (exact output, including the exact message text): `Assertion on 'tau' failed: Element 1 is not <= 1.` For tau = 0 the message is `Element 1 is not >= 2.22045e-16.`, which is true but does not state the rule either.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(3)
  des = DesignFixedBernoulli$new(n = 20, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
  des$assign_w_to_all_subjects(); des$add_all_subject_responses(rbeta(20, 2, 3))
  tryCatch(InferencePropQuantileRegr$new(des, tau = 1), error = function(e) conditionMessage(e))
  ```
- Workaround used, if any: none needed.

### F4: `InferencePropZeroOneInflatedBetaRegr` returns an NA CI and p-value with no warning when the data has exact 1s but no exact 0s and a covariate is on its natural scale (age in years); centring the covariate gives a finite answer for the same model
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropZeroOneInflatedBetaRegr` says the class handles data with point masses at 0 and 1. A study with a few exact 1s and no exact 0s is ordinary. The model is invariant to an affine change of a covariate, so the treatment CI should not depend on whether age is centred. If the SE cannot be computed, I expected a warning (the help page's mixture note says the information "can be singular", but nothing tells the user at run time).
- Observed (exact output, including the exact message text): with raw age, `est 0.5437211, CI NA NA, p NA`, no warning or message, and `is_nonestimable()` is `TRUE` with reason `model_standard_error_unavailable`. With centred age: `est 0.5437211, CI (0.3423056, 0.7451366), p 1.217013e-07`, `is_nonestimable()` is `FALSE`. `betareg` on the interior rows gives the same 0.5437211. This happened in 5 of 6 seeds (1, 2, 4, 5, 6). Seed 3 shows a second problem: the CI and p are finite and equal the centred-age answer, but `is_nonestimable()` still returns `TRUE` / `model_standard_error_unavailable`. The same happened on my main data with no 0s and no 1s at all, and there the point estimate was also slightly off (0.0646116 vs 0.0645556 from `betareg` and from the centred fit). With `model_formula_zero_one = ~ 1` it works. The case with exact 0s but no 1s worked on the same data.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages({library(EDI); library(betareg)})
  fit = function(y, w, X, ...) {
    des = DesignFixedBernoulli$new(n = length(y), response_type = "proportion", verbose = FALSE)
    des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
    des$add_all_subject_responses(y)
    inf = InferencePropZeroOneInflatedBetaRegr$new(des, ...)
    r = withCallingHandlers(c(est = inf$compute_estimate(), inf$compute_asymp_confidence_interval(),
                          p = inf$compute_asymp_two_sided_pval()),
      warning = function(w) cat("WARNING:", conditionMessage(w), "\n"),
      message = function(m) cat("MESSAGE:", conditionMessage(m), "\n"))
    print(r); cat("is_nonestimable:", inf$is_nonestimable(), format(inf$get_nonestimable_reason()), "\n")
  }
  set.seed(1)
  n = 150
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  mu = plogis(-0.8 + 0.6 * w - 0.02 * (X$age - 45) + 0.3 * X$female)
  y = rbeta(n, mu * 12, (1 - mu) * 12)
  y[sample(which(w == 0), 7)] = 1; y[sample(which(w == 1), 1)] = 1   # 8 exact ones, no zeros
  fit(y, w, X)                                             # age in years: NA CI/p, no warning
  Xc = transform(X, age = (age - 45) / 12)
  fit(y, w, Xc)                                            # same model, centred age: works
  print(coef(betareg(y ~ w + age + female, data = data.frame(y, w, X), subset = y < 1))["w"])
  
  ```
- Workaround used, if any: centre/scale covariates before `add_all_subjects_to_experiment()`, or set `model_formula_zero_one = ~ 1`.

### F5: `InferencePropGCompMeanDiff` with `variance_fallback_methods = character(0)` returns an NA point estimate, not just an NA variance, and gives no warning
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropGCompMeanDiff`, Description ("Variance fallback cascade"): "an empty `variance_fallback_methods` vector always returns `NA` variance rather than erroring". The `new()` argument text says the same. The point estimate does not depend on the variance, so I expected the g-computation mean difference with an NA SE.
- Observed (exact output, including the exact message text): `compute_estimate(estimate_only = TRUE)` gives `0.1218369`, but `compute_estimate()` gives `NA`. There is no warning, and `is_nonestimable()` is `FALSE`. The default object gives `0.1218369`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(5)
  n = 80
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  y = rbeta(n, 10 * plogis(-0.5 + 0.5 * w), 10 * (1 - plogis(-0.5 + 0.5 * w)))
  y[1:4] = 0; y[5:7] = 1
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf = InferencePropGCompMeanDiff$new(des, variance_fallback_methods = character(0))
  inf$compute_estimate(estimate_only = TRUE)   # finite
  inf$compute_estimate()                       # NA, no warning
  inf$is_nonestimable()
  inf_default = InferencePropGCompMeanDiff$new(des)
  inf_default$compute_estimate()
  ```
- Workaround used, if any: call `compute_estimate(estimate_only = TRUE)` for the point estimate.

### F6: `InferencePropZeroOneInflatedBetaRegr` accepts a `model_formula_zero_one` that names an unknown variable and returns `NA` with no error or warning; the same typo in `model_formula` gives a clear error
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropZeroOneInflatedBetaRegr`, `new()` argument `model_formula_zero_one`: "Formula for the zero/one inflation submodels". I expected the same validation as `model_formula`, which errors with "model_formula contains variables not present in the available covariates: bogus."
- Observed (exact output, including the exact message text): `compute_estimate()` returns `[1] NA`, with no warning and no message.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(5)
  n = 80
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  y = rbeta(n, 10 * plogis(-0.5 + 0.5 * w), 10 * (1 - plogis(-0.5 + 0.5 * w)))
  y[1:4] = 0; y[5:7] = 1
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf = InferencePropZeroOneInflatedBetaRegr$new(des, model_formula_zero_one = ~ bogus)
  withCallingHandlers(print(inf$compute_estimate()),
    warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
  tryCatch(InferencePropZeroOneInflatedBetaRegr$new(des, model_formula = ~ bogus)$compute_estimate(),
    error = function(e) conditionMessage(e))
  ```
- Workaround used, if any: none; I checked the formula by hand.

### F7: The `"model_based"` variance fallback of `InferencePropGCompMeanDiff` uses the unscaled Bernoulli information, which the fractional-logit help page calls wrong for a fractional response; on this data it is 2.5 times the sandwich SE
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropFractionalLogit`, Description, says the SE is "scaled by an estimated quasi-binomial dispersion parameter ... the unscaled Bernoulli-based variance systematically overstates Var(beta_T) for a genuinely fractional response, since Bernoulli is the maximum-variance distribution on [0,1]". `?InferencePropGCompMeanDiff` says it fits "the same mean-model idea as `InferencePropFractionalLogit`", but its `"model_based"` strategy (and `"model_based_fd"`, `"*_strong_clip"`) is "Fisher-information (IWLS) covariance" with weights mu(1-mu) and no dispersion. When the robust SE is not finite, the cascade falls back to this SE without a word.
- Observed (exact output, including the exact message text): `robust = 0.04713472`, `model_based = 0.11743497`. The references: unscaled binomial delta-method SE `0.11743493` (this is what EDI uses), quasibinomial-scaled SE `0.05072927`, HC0 sandwich SE `0.04713473`. On my main data: robust 0.0345, model_based 0.0795 (p 0.037 vs 0.365).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(5)
  n = 80
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  y = rbeta(n, 10 * plogis(-0.5 + 0.5 * w), 10 * (1 - plogis(-0.5 + 0.5 * w)))
  y[1:4] = 0; y[5:7] = 1
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  df = data.frame(y, w, X)
  inf_r = InferencePropGCompMeanDiff$new(des, variance_fallback_methods = "robust")
  inf_m = InferencePropGCompMeanDiff$new(des, variance_fallback_methods = "model_based")
  inf_r$compute_estimate(); inf_m$compute_estimate()
  c(robust = inf_r$get_standard_error(), model_based = inf_m$get_standard_error())
  # reference: delta method with glm covariance, unscaled binomial vs quasibinomial dispersion
  g  = glm(y ~ w + age + female, family = quasibinomial, data = df)
  X1 = model.matrix(g); X1[, "w"] = 1; X0 = model.matrix(g); X0[, "w"] = 0; b = coef(g)
  gr = colMeans(X1 * as.vector(dlogis(X1 %*% b))) - colMeans(X0 * as.vector(dlogis(X0 %*% b)))
  c(unscaled_binomial = sqrt(drop(t(gr) %*% (vcov(g) / summary(g)$dispersion) %*% gr)),
    quasibinomial     = sqrt(drop(t(gr) %*% vcov(g) %*% gr)),
    HC0_sandwich      = sqrt(drop(t(gr) %*% sandwich::vcovHC(g, type = "HC0") %*% gr)))
  ```
- Workaround used, if any: kept the default (`"robust"` first). Do not rely on the model-based fallback.

### F8: `get_supported_estimands()` throws an error on `InferencePropFractionalLogit` instead of returning `"conditional"`, while the other `get_supported_*()` getters return vectors
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): a capability getter should report the capability. `get_supported_testing_types()` on the same object returns `"wald"`, and `InferencePropBetaRegr$get_supported_estimands()` returns `c("conditional", "marginal_mean_diff")`. `?InferencePropFractionalLogit` does not mention estimands. I expected `"conditional"`, so code that loops over the proportion classes and asks what they support does not need a `tryCatch`.
- Observed (exact output, including the exact message text): `InferencePropFractionalLogit does not support get_supported_estimands(): only its default ("conditional") estimand is available, i.e. the treatment effect the class reports (for a regression model, the model-scale coefficient); marginal estimands are not available for this class in this release.` The method is still listed by `names()` on the object.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(5)
  n = 80
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  y = rbeta(n, 10 * plogis(-0.5 + 0.5 * w), 10 * (1 - plogis(-0.5 + 0.5 * w)))
  y[1:4] = 0; y[5:7] = 1
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  tryCatch(InferencePropFractionalLogit$new(des)$get_supported_estimands(), error = function(e) conditionMessage(e))
  InferencePropFractionalLogit$new(des)$get_supported_testing_types()
  InferencePropBetaRegr$new(des)$get_supported_estimands()
  ```
- Workaround used, if any: wrapped the call in `tryCatch`.

### F9: The jackknife methods of `InferencePropQuantileRegr` return NA even on clean interior data, and the warning blames separation, which a quantile regression on logit(y) cannot have
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?InferencePropQuantileRegr`, "Small-sample behaviour" table, lists `jackknife` as an available procedure ("asymptotic, O(n_eff^-1)"). With y strictly inside (0, 1), 120 subjects and a balanced design, I expected a jackknife CI. If the jackknife is not valid for a non-smooth quantile estimator (it is known to be inconsistent for sample quantiles), I expected the warning or the docs to say so.
- Observed (exact output, including the exact message text): `compute_jackknife_wald_confidence_interval()` returns `NA NA`, and `compute_jackknife_std_error()` returns `NA`, each with: `InferencePropQuantileRegr: compute_jackknife_wald_confidence_interval() returned NA (reason: jackknife_extreme_summary). The jackknife bias exceeds twice its standard error, or the jackknife estimate or standard error is extreme; this is typical when the full-data fit is at or near separation (e.g. one arm almost entirely in one outcome category), where no finite estimate is trustworthy.` The leave-one-out estimates take only 6 distinct values, and the jackknife bias (about 1.8) is 7 times its SE (about 0.25), so the cause is the non-smooth estimator, not separation. It was NA at tau = 0.25, 0.5 and 0.75 on two data sets. The asymptotic CI on the same object is finite: (0.230, 0.923).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(6)
  n = 120
  X = data.frame(x = rnorm(n)); w = rep(0:1, n / 2)
  y = rbeta(n, 8 * plogis(-0.5 + 0.6 * w), 8 * (1 - plogis(-0.5 + 0.6 * w)))   # strictly inside (0, 1)
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf = InferencePropQuantileRegr$new(des, tau = 0.5)
  inf$compute_estimate(); inf$compute_asymp_confidence_interval()
  inf$compute_jackknife_wald_confidence_interval()
  inf$compute_jackknife_std_error()
  ```
- Workaround used, if any: used the bootstrap / Bayesian bootstrap CIs.

### F10: The proportion cookbook says fractional logit requires open-interval data, but the class help page says Y in [0, 1], and the class fits exact 0s and 1s correctly
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `vignette("cookbook-proportion")`, section "Fixed design, fractional logit": "kept strictly inside (0, 1) — fractional logit and Beta regression require open-interval data; the zero/one-inflated class handles exact boundary values". `?InferencePropFractionalLogit` says "proportion responses Y_i in [0, 1]". The two pages contradict each other. The help page is right: the quasi-likelihood is well defined at 0 and 1, and EDI matches `glm(quasibinomial)` on data with exact 0s/1s. For beta regression the vignette sentence is also misleading, because EDI does not refuse 0/1; it silently squeezes them (F1). A reader who follows the vignette would clip their data with `pmin(pmax(y, 1e-4), 1 - 1e-4)` for no reason.
- Observed (exact output, including the exact message text): on data with 4 zeros and 3 ones (n = 80), EDI fractional logit gives `0.49780993 (0.08865199, 0.90696788)` and `glm` quasibinomial with `confint.default` gives `0.49780993 (0.08865193, 0.90696793)`. No warning.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(5)
  n = 80
  X = data.frame(age = round(rnorm(n, 45, 12)), female = rbinom(n, 1, 0.5))
  w = rbinom(n, 1, 0.5)
  y = rbeta(n, 10 * plogis(-0.5 + 0.5 * w), 10 * (1 - plogis(-0.5 + 0.5 * w)))
  y[1:4] = 0; y[5:7] = 1
  des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(y)
  inf = InferencePropFractionalLogit$new(des)
  c(inf$compute_estimate(), inf$compute_asymp_confidence_interval())
  g = glm(y ~ w + age + female, family = quasibinomial, data = data.frame(y, w, X))
  c(coef(g)["w"], confint.default(g)["w", ])   # identical: exact 0s/1s are fine for fractional logit
  ```
- Workaround used, if any: followed the help page and passed exact 0s/1s to the fractional logit.

