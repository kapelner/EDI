# Findings: custom-statistic (InferenceRandCustom), EDI 1.0.4

Every repro below is self-contained and runs in a fresh R session.

### F1: `transform_responses = "log"` on a continuous response applies an incoherent sharp null: treated responses are divided by e^delta to impute controls, but delta is then added (not multiplied) back to the units treated in each draw.
- Kind: accepted bad input
- Expected (InferenceRandCI help, `compute_rand_confidence_interval()` and `transform_responses`; article "Shifted nulls and a confidence interval"): the null response for draw w_b is `y - delta*w_obs + delta*w_b` on the additive scale, or `y * exp(delta*(w_b - w_obs))` on the log scale; either a consistent transform or an error saying "log" is not supported for continuous responses (y here contains negative values, so a log-scale null is meaningless anyway).
- Observed: for a unit treated in both the observed and the redrawn assignment, the statistic sees `y*exp(-delta) + delta` (e.g. 2.1558 -> 1.8075 at delta = 0.5); units treated only in the draw get `y + delta`; units treated only in the observed assignment get `y*exp(-delta)`. No warning, and negative y (9 of 50 here) are accepted. The repro's last line prints `yseen` next to the additive and multiplicative nulls: rows with w = 1 match only the multiplicative column when wb = 0, rows with w = 0 match only the additive column when wb = 1, and rows with w = wb = 1 match neither.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + w + rt(n, df = 3); des$add_all_subject_responses(y)
  seen = list()
  i = InferenceRandCustom$new(des, custom_randomization_statistic_function = function(y, w, dead) {
    seen[[length(seen) + 1]] <<- list(y = y, w = w); mean(y[w == 1]) - mean(y[w == 0]) })
  i$set_seed(1)
  i$compute_rand_two_sided_pval(r = 20, delta = 0.5, transform_responses = "log", show_progress = FALSE)
  s = seen[[length(seen)]]
  round(cbind(y, w, wb = s$w, yseen = s$y, additive = y - .5*w + .5*s$w, mult = y*exp(.5*(s$w - w)))[1:15, ], 4)
  # rows with w = 1, wb = 1 show yseen = y*exp(-0.5) + 0.5, matching neither column
  ```
- Workaround used, if any: use the default `transform_responses = "none"` for continuous outcomes.

### F2: `transform_responses` accepts any string (e.g. `"bogus"`, `"sqrt"`, `"identity"`) silently, and the set of allowed values is not documented.
- Kind: accepted bad input
- Expected (InferenceCustomRand / InferenceRand help, argument `transform_responses`: "Response transformation to apply during the test" / "Transformation"): a documented list of values and an error for anything else, as `alternative` does (`'arg' should be one of "two.sided", "greater", "less"`).
- Observed: `"none"`, `"bogus"` and `"sqrt"` all return 0.944 with no message; `"logit"` returns 0.9 on a continuous response with negative values. The help never lists the allowed values (only "none" and the survival "log" are mentioned).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + w + rt(n, df = 3); des$add_all_subject_responses(y)
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  i = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
  for (t in c("none", "bogus", "sqrt", "logit")) { i$set_seed(1)
    print(c(t, i$compute_rand_two_sided_pval(r = 500, delta = 0.5, transform_responses = t, show_progress = FALSE))) }
  ```
- Workaround used, if any: none; stayed with "none".

### F3: `r` between 1 and 9 is accepted (the check is only `r >= 1`) but the p-value is then always `NA` with no warning, because at least 10 finite draws are required.
- Kind: silent NA
- Expected (InferenceRand help, Details: "At least max(10, floor(r/10)) finite reference statistics are required ... otherwise NA is returned"): since r < 10 can never satisfy this, the argument check should reject r < 10, or the NA should come with a warning naming the minimum. The same silent NA occurs whenever too many draws are non-finite (e.g. r = 200 with 19 finite draws).
- Observed: `r = 1, 2, 5, 9` each return `NA` with no warning or message; `r = 0` errors "Assertion on 'r' failed: Must be >= 1."; `r = 10` returns 0.2. `compute_rand_confidence_interval(r = 9)` likewise returns `NA NA` silently (r = 20 gives conservative bounds with a message).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + w + rt(n, df = 3); des$add_all_subject_responses(y)
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  i = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
  withCallingHandlers(for (r in c(1, 5, 9, 10)) { i$set_seed(1); print(c(r = r, p = i$compute_rand_two_sided_pval(r = r, show_progress = FALSE))) },
                      warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
  ```
- Workaround used, if any: use r >= 1000.

### F4: The CI refusal for count and proportion responses tells the user the "randomization-bootstrap CI remain[s] available", but InferenceRandCustom has no bootstrap CI (its own help and `capabilities()` say only the randomization test and CI exist); the message also points to internal repo files.
- Kind: false message
- Expected (InferenceRandCustom help: "Only a randomization test and randomization confidence interval are available - there is no ... bootstrap machinery on this class"): a refusal message that names something the user can actually call on this class (or points to the built-in class from the cookbooks, as the article does).
- Observed: `Error: Randomization confidence intervals are not supported for InferenceRandCustom with count responses: the search inverts a log shift of the count response, but this class's estimate is on the raw response scale, so the delta bounds are not on the scale of the estimate (or of its asymptotic CI). The randomization p-value and the randomization-bootstrap CI remain available. See TODO-119 in R/package_metadata/future_release_plans/release_v1_0_5.md.` `capabilities()` on this count object returns only `"randomization_test"` (no bootstrap). The incidence refusal similarly cites `R/package_metadata/new_feature_plans/v1_1_0/incidence_randomization_cis.md`, a file not shipped to users.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(5); n = 60; X = data.frame(x1 = rnorm(n))
  d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
  d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w = d$get_w()
  d$add_all_subject_responses(rpois(n, exp(1 + .5 * w)))
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  i = InferenceRandCustom$new(d, custom_randomization_statistic_function = tm)
  i$capabilities()
  try(i$compute_rand_confidence_interval(r = 300, show_progress = FALSE))
  ```
- Workaround used, if any: none needed.

### F5: For survival responses InferenceRandCustom advertises and returns a randomization CI (and accepts nonzero `delta`), although the article says these are for continuous responses only and the help says survival CIs invert a log-time shift that a raw-scale statistic cannot match; count/proportion with the same scale mismatch are refused.
- Kind: inconsistency
- Expected (article "Other response types": "Use a nonzero `delta` and `compute_rand_confidence_interval()` with **continuous responses only** ... a nonzero `delta` test is not a coherent hypothesis for those types or for survival"; InferenceRandCI help, "Estimand scale": "The same refusal applies on survival responses to classes whose estimate is a raw-scale (time-unit) mean difference"): an error, as for count and proportion, or at least `supports("randomization_ci")` = FALSE.
- Observed: `supports("randomization_ci")` is `TRUE`; `compute_rand_confidence_interval()` returns `-0.419 0.318` with no message (an interval for a log time-ratio shift, while the estimate is a trimmed-mean difference in time units, -0.118); `compute_rand_two_sided_pval(delta = 0.2)` returns 0.08 with no message.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(5); n = 60; X = data.frame(x1 = rnorm(n))
  d = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
  d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w = d$get_w()
  et = rexp(n, exp(-.7 * w)); fu = runif(n, .5, 3); cz = et > fu
  d$add_all_subject_responses(ys = ifelse(cz, NA, et), y_Ls = ifelse(cz, fu, NA), y_Rs = ifelse(cz, Inf, NA))
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  i = InferenceRandCustom$new(d, custom_randomization_statistic_function = tm)
  i$supports("randomization_ci"); i$compute_estimate()
  i$set_seed(1); i$compute_rand_two_sided_pval(r = 300, delta = 0.2, show_progress = FALSE)
  i$compute_rand_confidence_interval(r = 300, show_progress = FALSE)
  ```
- Workaround used, if any: none; reported p-value at delta = 0 only for survival.

### F6: Nonzero `delta` is silently accepted for count and proportion responses, which the article calls "not a coherent hypothesis"; incidence refuses it with an error.
- Kind: inconsistency
- Expected (article "Other response types": a nonzero `delta` test "is not a coherent hypothesis for those types"; incidence already errors "randomization tests with delta nonzero not supported for incidence"): the same refusal, or a documented meaning for delta on these scales.
- Observed: proportion `delta = 0.2` returns 0.713 (repro); a count response with `delta = 0.2` also returned a p-value (0.00667) in the analysis run; no message in either case.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(5); n = 60; X = data.frame(x1 = rnorm(n))
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  d = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
  d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w = d$get_w()
  d$add_all_subject_responses(plogis(rnorm(n, .5 * w)))
  i = InferenceRandCustom$new(d, custom_randomization_statistic_function = tm)
  i$set_seed(1); i$compute_rand_two_sided_pval(r = 300, delta = 0.2, show_progress = FALSE)
  ```
- Workaround used, if any: none.

### F7: C++ source that defines any helper function (even a forward-declared or `inline` one), or uses the usual `// [[Rcpp::export]]` tag, is rejected; the help says only "C++ source defining a function".
- Kind: insufficient docs
- Expected (InferenceRandCustom help, Description; article "Speed": C++ "pays off when the statistic loops over subjects in a way base R cannot vectorize", which is exactly when helpers are used): either support for helpers (e.g. "the last function is the statistic") or a documented rule that the source must contain exactly one function and no export attribute.
- Observed: helper first: `custom_randomization_statistic_cpp source must define a function with 2 arguments (y, w) or 3 arguments (y, w, dead); got 1.` (the 1-argument helper was taken as the statistic). With `// [[Rcpp::export]]`: a compiler error `redefinition of 'SEXPREC* sourceCpp_7_main_stat(SEXP, SEXP)'` and `Error 1 occurred building shared library.` A lambda inside the single function works (used for the trimmed mean).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnorm(n))
  src1 = "inline double helper(double a){ return a; }\ndouble stat(Rcpp::NumericVector y, Rcpp::IntegerVector w){ return helper(y[0]); }"
  try(InferenceRandCustom$new(des, custom_randomization_statistic_cpp = src1))
  src2 = "// [[Rcpp::export]]\ndouble stat(Rcpp::NumericVector y, Rcpp::IntegerVector w){ return y[0]; }"
  try(InferenceRandCustom$new(des, custom_randomization_statistic_cpp = src2))
  ```
- Workaround used, if any: put the helper logic in a lambda inside the single function.

### F8: Passing the C++ source as a character vector of several lines gives an error that says the value is "not a character", although it is one.
- Kind: useless message
- Expected (InferenceRandCustom help: "C++ source"): either paste the lines together or say "must be a single string (length 1)".
- Observed: `custom_randomization_statistic_cpp must be a C++ source string, a compiled Rcpp function, or an RcppXPtrUtils::cppXPtr() external pointer, not a character.` The message also lists two accepted input kinds (compiled Rcpp function, cppXPtr) that the help page does not document; a `Rcpp::cppFunction()` result does work.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnorm(n))
  try(InferenceRandCustom$new(des, custom_randomization_statistic_cpp =
    c("double f(Rcpp::NumericVector y,", "Rcpp::IntegerVector w) { return 1; }")))
  ```
- Workaround used, if any: `paste(lines, collapse = "\n")`.

### F9: The article says a two-argument statistic `function(y, w)` "fails with 'unused argument (dead)'", but EDI rejects it with a different message.
- Kind: false docs
- Expected (article "The statistic function"): error "unused argument (dead)".
- Observed: `custom_randomization_statistic_function must accept three arguments (y, w, dead) or `...`; it has 2.` (a better message; the doc text is stale).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnorm(n))
  try({ i = InferenceRandCustom$new(des, custom_randomization_statistic_function = function(y, w) mean(y[w == 1]) - mean(y[w == 0])); i$compute_estimate() })
  ```
- Workaround used, if any: none needed.

### F10: An `InferenceCustomRand` subclass whose `fit()` calls a user-defined helper function returns a randomization p-value (and CI) of `NA` with no warning when 2 cores are set; with 1 core it gives the correct value.
- Kind: silent NA
- Expected (extending-edi vignette, "Randomization and bootstrap shells": implement `fit()` returning `estimate` and "you get ... EDI's randomization-test machinery"; Reproducibility vignette: allocations "are identical at every `set_num_cores()` setting"; a p-value should not change from a number to NA with the core count): the same p-value for any core count, or an error naming the failure (e.g. the helper not being found in a worker).
- Observed: with `set_num_cores(2)`, `compute_rand_two_sided_pval(r = 1000)` returns `NA` and `compute_rand_confidence_interval(r = 1000)` returns `NA NA`, with no warning or message; the same class with `fit()` written inline returns 0.274, and with `set_num_cores(1)` the helper version returns 0.274 too (also equal to `InferenceRandCustom` with the same statistic and seed). `approximate_randomization_distribution_beta_hat_T(debug = TRUE)` runs serially and so shows no errors (`prop_illegal_values` 0), which hides the cause. The same silent NA was seen for subclasses of `InferenceCustomAsymp` (rand p-value) and `InferenceCustomBoot` (rand p-value; bootstrap CI `NA NA` with warning "bootstrap_too_few_finite_estimates") whose `fit()` calls a global helper.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); library(R6); set_num_cores(2)
  InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + w + rt(n, df = 3); des$add_all_subject_responses(y)
  tm = function(y, w) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  TR = R6Class("TR", inherit = InferenceCustomRand, lock_objects = FALSE,
    public = list(fit = function(estimate_only = FALSE) { d = self$get_analysis_data(); list(estimate = tm(d$y, d$w)) }))
  TRi = R6Class("TRi", inherit = InferenceCustomRand, lock_objects = FALSE,
    public = list(fit = function(estimate_only = FALSE) { d = self$get_analysis_data()
      list(estimate = mean(d$y[d$w == 1], trim = .2) - mean(d$y[d$w == 0], trim = .2)) }))
  ir = TR$new(des); ir$set_seed(1); ir$compute_rand_two_sided_pval(r = 1000, show_progress = FALSE)  # NA, silent
  ii = TRi$new(des); ii$set_seed(1); ii$compute_rand_two_sided_pval(r = 1000, show_progress = FALSE) # 0.274
  set_num_cores(1); ir2 = TR$new(des); ir2$set_seed(1); ir2$compute_rand_two_sided_pval(r = 1000, show_progress = FALSE) # 0.274
  ```
- Workaround used, if any: write the statistic inline inside `fit()`, or `set_num_cores(1)`, or use `InferenceRandCustom` (whose R statistic is called in the main session and works with 2 cores).

### F11: The `permutations` argument ("Optional pre-generated assignment draws" / "Pre-computed permutations") has no documented format; an n x r matrix fails with an unrelated error, and malformed draws (wrong length, 1/2 coding) are accepted silently.
- Kind: insufficient docs
- Expected (InferenceCustomRand / InferenceRand help, argument `permutations`): the expected structure (it turned out to be a list with element `w_mat`, an n x r 0/1 matrix, found by guessing), and validation of length, coding and number of columns.
- Observed: `permutations = P` (50 x 500 matrix) or `t(P)`: `Error: $ operator is invalid for atomic vectors`. `list(W = P)`: same error. `list(w_mat = P)` with `r = 1000` (more than the 500 columns): `subscript out of bounds`. `list(w_mat = P[1:40, ])` on n = 50: returns p = 0.268 with no message (draws of the wrong length are recycled by the statistic). `list(w_mat = P + 1)` (1/2 coding): returns `NA` with no message (one run also printed a stray `Timing stopped at: 0.028 0 0.028`).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + w + rt(n, df = 3); des$add_all_subject_responses(y)
  tm = function(y, w, dead) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2)
  i = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
  set.seed(11); P = replicate(500, rbinom(n, 1, .5))
  try(i$compute_rand_two_sided_pval(r = 500, permutations = P, show_progress = FALSE))
  i$compute_rand_two_sided_pval(r = 500, permutations = list(w_mat = P), show_progress = FALSE)          # works: 0.304
  try(i$compute_rand_two_sided_pval(r = 1000, permutations = list(w_mat = P), show_progress = FALSE))
  i$compute_rand_two_sided_pval(r = 500, permutations = list(w_mat = P[1:40, ]), show_progress = FALSE) # accepted
  i$compute_rand_two_sided_pval(r = 500, permutations = list(w_mat = P + 1), show_progress = FALSE)     # NA
  ```
- Workaround used, if any: let EDI draw the assignments (default `permutations = NULL`).

### F12: The article states the two-sided p-value has "a floor of 2/r", but when draws are dropped the floor is 2/B (B = number of finite draws), as the InferenceRand help says.
- Kind: false docs
- Expected (article "What the test does": "with a floor of 2/r"): agreement with InferenceRand help ("a floor of 2/B" over the B finite reference statistics).
- Observed: r = 1000 with 568 finite draws and an extreme observed statistic: p = 0.003521 = 2/568 (not 2/1000 = 0.002); `alternative = "greater"` gives 0.001761 = 1/568. The help is right; the article is not.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(42); n = 50; X = data.frame(x1 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  w = des$get_w(); y = 1 + X$x1 + 5 * w + rnorm(n) / 5; des$add_all_subject_responses(y)
  stat = function(y, w, dead) { if (sum(w) < 25) return(NA_real_); mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2) }
  i = InferenceRandCustom$new(des, custom_randomization_statistic_function = stat)
  i$set_seed(1); t0 = i$approximate_randomization_distribution_beta_hat_T(r = 1000, show_progress = FALSE)
  B = sum(is.finite(t0)); i$set_seed(1)
  c(p = i$compute_rand_two_sided_pval(r = 1000, show_progress = FALSE), two_over_B = 2 / B, two_over_r = 2 / 1000)
  ```
- Workaround used, if any: none needed.
