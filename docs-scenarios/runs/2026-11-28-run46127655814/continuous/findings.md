# Findings: continuous

### F1: `InferenceContinRobustRegr` default backend (`use_rcpp = TRUE`) with `method = "MM"` does not reproduce MM estimation; it gives a different estimate from `MASS::rlm(method = "MM")` and from `use_rcpp = FALSE`
- Kind: reference mismatch
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceContinRobustRegr` Description: "The `method` argument is passed through to either backend and may be either "M" (Huber's psi function) or "MM" (Tukey's bisquare weight, the default — higher breakdown point than "M" ...)". That implies the default backend fits the same MM-estimator as `MASS::rlm(method = "MM")`, the `use_rcpp = FALSE` path. `?ContinKKRobustRegrIVWCSource` also says '"MM" (the default) uses an LQS-based high-breakdown start'. But `?fast_robust_regression_cpp` describes "MM" as a bisquare IRLS whose scale is "fixed once at the start value", seeded by OLS (`smart_cold_start = TRUE`). That is a bisquare M-estimator started from OLS, with no high-breakdown S/LQS start, so the "higher breakdown point" claim does not hold for the default backend.
- Observed (n = 70, 3 covariates, 3 gross outliers): treatment coefficient and SE
  - `use_rcpp = TRUE, method = "MM"` (default): est 2.152502, SE 0.469222
  - `use_rcpp = FALSE, method = "MM"`: est 2.111722, SE 0.475785
  - `MASS::rlm(method = "MM")`: est 2.111722, SE 0.475785
  - `method = "M"`: both backends and `MASS::rlm` agree (2.23406 vs 2.23411)
  The default and MASS MM estimates differ in the 2nd significant digit. No message says the default backend fits a different estimator.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); library(MASS); set_num_cores(2)
  set.seed(2026); n = 70
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 27, 4), 1), sbp = rnorm(n, 130, 15))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  y = 5 + 2*w + 0.1*X$age - 0.2*X$bmi + 0.05*X$sbp + rnorm(n, sd = 2)
  y[c(3, 17, 44)] = y[c(3, 17, 44)] + c(25, -20, 30)
  des$add_all_subject_responses(y)
  InferenceContinRobustRegr$new(des, method = "MM")$compute_estimate()                   # C++ default
  InferenceContinRobustRegr$new(des, method = "MM", use_rcpp = FALSE)$compute_estimate() # MASS path
  coef(rlm(y ~ w + age + bmi + sbp, data.frame(y, w, X), method = "MM"))["w"]
  ```
  (With this seed the design draws the same `w` as in the observed run. Any seed shows the gap whenever outliers are present.)
- Same gap in the KK classes (KK21 design, n = 70, 29 pairs + 12 reservoir, 3 outliers): `InferenceContinKKRobustRegrOneLik` default gives 2.141596, while `use_rcpp = FALSE` and `MASS::rlm(method = "MM")` on the documented stacked design both give 2.120893. `InferenceContinKKRobustRegrIVWC` default gives 1.854756, while the IVW combination of two `MASS::rlm(method = "MM")` fits gives 1.973837. `method = "M"` agrees with MASS in both KK classes.
- Workaround used, if any: `use_rcpp = FALSE` to get the textbook MM estimator.


### F2: `InferenceContinKKQuantileRegrIVWC$compute_rand_confidence_interval()` can return an infinite upper bound (`Inf`) with no message, though the randomization test rejects well inside the search radius
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCI`, `compute_rand_confidence_interval()`, `ci_search_control`: the search radius is `max(25 * se_guess, 6 * sd(y), 1)` (about 33 here). "When the randomization p-value does not drop below alpha anywhere within the search radius ... a conservative CI bound is returned at the search boundary rather than NA. This guarantees a valid (though possibly wide) interval. Each such event emits a message()". So the result should be finite, or at least a finite search-boundary bound plus a message.
- Observed: `0.4558115 Inf`, with no message and no warning (both handlers were installed). With the same object, `compute_rand_two_sided_pval(r = 199, delta = d)` is 0.19 at d = 4, 0.03 at d = 6 and 0.02 at d = 10, 20, 40 and 80. So the test rejects from about d = 6 on, well inside the radius. Other seeds give finite upper bounds of 7.45 (seed 2) and 9.17 (seed 3), and `r = 499` gives 5.28.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(77); n = 70
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 27, 4), 1), sbp = rnorm(n, 130, 15))
  eps = rnorm(n, sd = 2); eps[c(5, 30, 61)] = eps[c(5, 30, 61)] + c(25, -20, 30)
  des = DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
  w = integer(n); for (i in 1:n) w[i] = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
  y = 5 + 2*w + 0.1*X$age - 0.2*X$bmi + 0.05*X$sbp + eps
  for (i in 1:n) des$add_one_subject_response(i, y[i])
  inf = InferenceContinKKQuantileRegrIVWC$new(des)
  inf$set_seed(1)
  withCallingHandlers(inf$compute_rand_confidence_interval(r = 99, show_progress = FALSE),
                      message = function(m) cat("MSG:", conditionMessage(m)))
  #      2.5%     97.5%
  # 0.4558115       Inf
  inf$compute_rand_two_sided_pval(r = 199, delta = 10, show_progress = FALSE)   # 0.02
  ```
- Workaround used, if any: larger `r` (499) gave a finite interval. The p-value at a few deltas is the only way to tell that `Inf` is spurious.

### F3: `?InferenceAllKKMeanDiffIVWC` promises "the full variance formula" but never says which estimator of Var(r̄) is used (it is the pooled-variance one, not Welch), and it delegates z vs t to a private method
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceAllKKMeanDiffIVWC` Description says "see `$compute_asymp_confidence_interval()` for the full variance formula". Details gives only an unspecified "estimated variance Var(r̄)" and says the critical value is "z ... (or a t-based critical value, depending on `private$compute_z_or_t_ci_from_s_and_df`'s degrees-of-freedom resolution)". A user cannot reproduce the CI from this. The sibling `InferenceAllSimpleAverageDiff` uses Welch, which is the natural guess.
- Observed: on KK21 data (29 pairs; reservoir 8 treated, 4 control), EDI gives estimate 0.1616518 and CI (-1.699373, 2.022677). With Var(d̄) = var(d)/m and the documented IVW weights, the Welch reservoir variance gives 0.1564851, which does not match. The pooled variance s_p^2 (1/n_T + 1/n_C) gives 0.1616518 and SE 0.9495201, and the CI equals est ± qnorm(0.975) * SE: an exact match. The method sections for `compute_asymp_confidence_interval()` contain no such formula. `?InferenceContinKKOLSIVWC` documents no asymptotic CI method at all. Its CI (-1.807044, 2.505829) is wider than est ± 1.96 * SE_HC2 (SE_HC2 = 1.0327 from lm + sandwich, IVW combined; the estimate 0.3493926 matches exactly), which implies a t critical value of about 2.088 (df ≈ 20) whose df is undocumented.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(77); n = 70
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 27, 4), 1), sbp = rnorm(n, 130, 15))
  eps = rnorm(n, sd = 2); eps[c(5, 30, 61)] = eps[c(5, 30, 61)] + c(25, -20, 30)
  des = DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
  w = integer(n); for (i in 1:n) w[i] = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
  y = 5 + 2*w + 0.1*X$age - 0.2*X$bmi + 0.05*X$sbp + eps
  for (i in 1:n) des$add_one_subject_response(i, y[i])
  ids = des$get_matching_cluster_ids(); tb = table(ids); pid = as.integer(names(tb)[tb == 2])
  d = sapply(pid, function(k) { ii = which(ids == k); y[ii[w[ii] == 1]] - y[ii[w[ii] == 0]] })
  r = which(!(ids %in% pid)); yr = y[r]; wr = w[r]; nT = sum(wr); nC = sum(1 - wr)
  vd = var(d) / length(d); rbar = mean(yr[wr == 1]) - mean(yr[wr == 0])
  v_welch  = var(yr[wr == 1]) / nT + var(yr[wr == 0]) / nC
  v_pooled = ((nT - 1) * var(yr[wr == 1]) + (nC - 1) * var(yr[wr == 0])) / (nT + nC - 2) * (1/nT + 1/nC)
  ivw = function(vr) (vr * mean(d) + vd * rbar) / (vr + vd)
  inf = InferenceAllKKMeanDiffIVWC$new(des)
  c(EDI = inf$compute_estimate(), welch = ivw(v_welch), pooled = ivw(v_pooled))
  # EDI 0.1616518, welch 0.1564851, pooled 0.1616518
  ```
- Workaround used, if any: reverse-engineered the pooled-variance formula by trying the candidate estimators.

### F4: `compute_bootstrap_confidence_interval()` / `compute_bootstrap_two_sided_pval()` document `type = NULL` without saying what NULL resolves to, and the default silently differs between sibling continuous classes (BCa for OLS, percentile for Lin, robust and quantile)
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceNonParamBootstrap` lists the supported `type` values for both methods but never says what the default `NULL` means. `vignette("cookbook-continuous")` ("Inference: covariate-adjusted OLS") says "The default interval type is BCa". The rule is only discoverable from `?get_bootstrap_dispatch_policy`, which neither method page links to.
- Observed (same data and `set_seed(1)`, `B = 501`): for `InferenceContinOLS` the default CI is (1.105163, 8.228637), equal to `type = "bca"`. For `InferenceContinLin` the default CI is (0.7634463, 7.4684255), equal to `type = "percentile"`, while `"bca"` gives (0.9614146, 7.8475847). `InferenceContinQuantileRegr` and `InferenceContinRobustRegr` also default to percentile. The default p-value follows the same split: Lin's default is 0.0479 (percentile), while its bca p-value is 0.0072. The returned value does not say which type was used. `get_bootstrap_dispatch_policy()$inference_class_overrides` explains it (`^InferenceContinLin$`, `^InferenceContinRobustRegr$` and the quantile pattern map to "percentile").
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(2026); n = 70
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 27, 4), 1), sbp = rnorm(n, 130, 15))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  y = 5 + 2*w + 0.1*X$age - 0.2*X$bmi + 0.05*X$sbp + rnorm(n, sd = 2)
  y[c(3, 17, 44)] = y[c(3, 17, 44)] + c(25, -20, 30)
  des$add_all_subject_responses(y)
  for (cl in c("InferenceContinOLS", "InferenceContinLin")) {
    a = get(cl)$new(des); a$set_seed(1)
    print(rbind(default = a$compute_bootstrap_confidence_interval(B = 501, show_progress = FALSE),
                bca = a$compute_bootstrap_confidence_interval(B = 501, type = "bca", show_progress = FALSE),
                pct = a$compute_bootstrap_confidence_interval(B = 501, type = "percentile", show_progress = FALSE)))
  }
  ```
- Workaround used, if any: always pass `type` explicitly.

### F5: `InferenceContinQuantileRegr$new(tau = 1)` is rejected with the false message "Element 1 is not <= 1"
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceContinKKQuantileRegrIVWC` / `?InferenceContinKKQuantileRegrOneLik` say "Any value strictly between 0 and 1 is accepted", so rejecting `tau = 1` is right. The message should state the real constraint (tau must be < 1, i.e. in (0, 1)).
- Observed: `Error: Assertion on 'tau' failed: Element 1 is not <= 1.`, which is false, since 1 <= 1. The lower bound reads correctly: `tau = 0` gives "Element 1 is not >= 2.22045e-16."
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1); n = 20
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
  des$assign_w_to_all_subjects(); des$add_all_subject_responses(rnorm(n))
  InferenceContinQuantileRegr$new(des, tau = 1)
  # Error: Assertion on 'tau' failed: Element 1 is not <= 1.
  ```
- Workaround used, if any: none needed (use tau in (0, 1)).

### F6: `compute_asymp_confidence_interval()` of `InferenceContinOLS` and `InferenceAllSimpleAverageDiff` accepts `alpha` outside [0, 1] and returns an inverted or NaN interval; sibling classes reject the same input
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceContinOLS`, `compute_asymp_confidence_interval()`: "The confidence level in the computed confidence interval is 1 - alpha". So alpha must be in (0, 1). `InferenceContinLin`, `InferenceContinRobustRegr`, `InferenceContinQuantileRegr`, and the bootstrap / randomization / jackknife CI methods of `InferenceContinOLS` itself all reject `alpha = 1.2` with "Assertion on 'alpha' failed: Element 1 is not <= 1."
- Observed: `InferenceContinOLS$new(des)$compute_asymp_confidence_interval(alpha = 1.2)` returns `60% 4.040349, 40% 3.359134`: lower > upper, with no warning. `alpha = -0.1` returns `-5% NaN, 105% NaN` with only R's generic "NaNs produced" warning. `InferenceAllSimpleAverageDiff` returns `60% 2.992213, 40% 2.224214` for `alpha = 1.2`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(1 + des$get_w() + X$x1 + rnorm(n))
  InferenceContinOLS$new(des)$compute_asymp_confidence_interval(alpha = 1.2)             # inverted interval, silent
  InferenceAllSimpleAverageDiff$new(des)$compute_asymp_confidence_interval(alpha = 1.2)  # inverted interval, silent
  InferenceContinOLS$new(des)$compute_asymp_confidence_interval(alpha = -0.1)            # NaN NaN
  InferenceContinLin$new(des)$compute_asymp_confidence_interval(alpha = 1.2)             # error, as expected
  ```
- Workaround used, if any: none needed (validate alpha yourself).

### F7: The jackknife NA warning for `InferenceContinQuantileRegr` blames "separation (one arm almost entirely in one outcome category)", which cannot apply to a continuous median regression
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): a reason that fits the class. Here the real cause is that the leave-one-out jackknife is unreliable for the non-smooth quantile estimator: the jackknife bias is -2.04 against a jackknife SE of 0.42, so |bias|/SE is 4.8.
- Observed: `compute_jackknife_std_error()`, `compute_jackknife_wald_confidence_interval()`, `compute_jackknife_wald_two_sided_pval()`, `compute_jackknife_bias_estimate()` and `compute_jackknife_estimate()` all return NA with the warning: "InferenceContinQuantileRegr: compute_jackknife_std_error() returned NA (reason: jackknife_extreme_summary). The jackknife bias exceeds twice its standard error, or the jackknife estimate or standard error is extreme; this is typical when the full-data fit is at or near separation (e.g. one arm almost entirely in one outcome category), where no finite estimate is trustworthy." There is no outcome category or separation in a continuous response. A manual leave-one-out `quantreg::rq` jackknife gives a finite SE of 0.4220, so the NA is a policy choice; only its explanation is wrong.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(2026); n = 70
  X = data.frame(age = round(rnorm(n, 50, 10)), bmi = round(rnorm(n, 27, 4), 1), sbp = rnorm(n, 130, 15))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
  y = 5 + 2*w + 0.1*X$age - 0.2*X$bmi + 0.05*X$sbp + rnorm(n, sd = 2)
  y[c(3, 17, 44)] = y[c(3, 17, 44)] + c(25, -20, 30)
  des$add_all_subject_responses(y)
  InferenceContinQuantileRegr$new(des)$compute_jackknife_std_error()   # NA + "separation" warning
  ```
- Workaround used, if any: use the asymptotic `nid`, bootstrap or randomization intervals instead.

### F8: Passing a bare matrix as `permutations` (which the docs say is not accepted) fails with the uninformative error "$ operator is invalid for atomic vectors"
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRand` / `?InferenceRandCI`, argument `permutations`: "Otherwise a list with element `w_mat` ... A bare matrix is not accepted." The error should say that `permutations` must be `list(w_mat = ...)`.
- Observed: `Error: $ operator is invalid for atomic vectors`. With `list(w_mat = Wm)` the same draws work: p = 0.01 in the repro. On the 70-subject analysis data, the list form gave 0.008, equal to a manual `lm` permutation p-value computed with the documented formula.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1); n = 40
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(1 + des$get_w() + X$x1 + rnorm(n))
  Wm = replicate(199, rbinom(n, 1, 0.5))
  inf = InferenceContinOLS$new(des)
  inf$compute_rand_two_sided_pval(r = 199, permutations = list(w_mat = Wm), show_progress = FALSE)  # works
  inf$compute_rand_two_sided_pval(r = 199, permutations = Wm, show_progress = FALSE)
  # Error: $ operator is invalid for atomic vectors
  ```
- Workaround used, if any: wrap in `list(w_mat = Wm)`.

### F9: The help pages of `InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`, `InferenceContinKKRobustRegrIVWC` and `InferenceContinKKRobustRegrOneLik` have no `$new()` usage or argument list, though their text refers to constructor arguments
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): each class page should show `$new()` with its arguments, as `?InferenceContinKKQuantileRegrIVWC` and `?InferenceContinOLS` do. The Details text of `?InferenceContinKKRobustRegrOneLik` and `?ContinKKRobustRegrIVWCSource` refers to `method`, `use_rcpp` and `start_with_ols`, and the OLS pages refer to `model_formula`, but none of these is listed. "Methods" lists only `approximate_randomization_distribution_beta_hat_T()`, `supports_rand_pval_for_incidence()`, `compute_rand_two_sided_pval()` and `clone()` (each argument appears twice). The super class is given as `Inference` directly. `compute_estimate()` and `compute_asymp_confidence_interval()`, the methods a user calls first, are not documented on these pages, so the CI construction (z vs t, df) is undocumented (see F3).
- Observed: output of the repro below:
  ```
  InferenceContinKKOLSIVWC             documents $new(): FALSE  documents compute_asymp_confidence_interval(): FALSE
  InferenceContinKKOLSOneLik           documents $new(): FALSE  documents compute_asymp_confidence_interval(): FALSE
  InferenceContinKKRobustRegrIVWC      documents $new(): FALSE  documents compute_asymp_confidence_interval(): FALSE
  InferenceContinKKRobustRegrOneLik    documents $new(): FALSE  documents compute_asymp_confidence_interval(): FALSE
  InferenceContinKKQuantileRegrIVWC    documents $new(): TRUE   documents compute_asymp_confidence_interval(): FALSE
  ```
  By trial, `model_formula`, `method`, `use_rcpp` and `start_with_ols` are all accepted, and `use_rcpp = FALSE` reproduces `MASS::rlm`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  db = tools::Rd_db("EDI")
  for (cl in c("InferenceContinKKOLSIVWC", "InferenceContinKKOLSOneLik", "InferenceContinKKRobustRegrIVWC",
               "InferenceContinKKRobustRegrOneLik", "InferenceContinKKQuantileRegrIVWC")) {
    txt = capture.output(tools::Rd2txt(db[[paste0(cl, ".Rd")]]))
    cat(sprintf("%-36s documents $new(): %-5s  documents compute_asymp_confidence_interval(): %s\n", cl,
                any(grepl(paste0(cl, "\\$new\\($"), txt)), any(grepl("compute_asymp_confidence_interval\\(alpha", txt))))
  }
  ```
- Workaround used, if any: passed the arguments named in the prose and checked the results against manual fits.
