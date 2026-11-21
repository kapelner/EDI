# Findings: InferenceSuite and reporting an analysis (EDI 1.0.4)

### F1: With `compute_conf_intervals = FALSE`, `run_all_inference()` still emits rows for CI-only bootstrap types (`basic`, `calibrated`, `prepivoted`, ...) with `pval = NA`, no message, `status = "ok"`, and `pval_method`/`ci_method` filled in, contrary to the help page
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `run_all_inference()` argument `methods`: "pval-side `type` is a smaller set - `"percentile"`, `"symmetric"`, `"studentized"`, `"bootstrap-t"`, `"bca"` - neither `"basic"` nor the other CI-only variants apply on the pval side", and "`ci_method`/`pval_method` on a given row now always match that row's own `method` (or are `NA` if this class lacks that half of the sentinel's capability, *including* when `type` is valid on one side but not the other)". Argument `compute_conf_intervals`: "When `FALSE` ... `ci_a`/`ci_b`/`ci_method` stay present but always `NA`". So with CIs off, a CI-only type has nothing to compute: either no row, or a row with `pval_method = NA` and `ci_method = NA` and some explanation.
- Observed (exact output, including the exact message text): one row per CI-only type, `pval = NA`, `pval_method = "bootstrap"`, `ci_method = "bootstrap"` (even though CIs were off), `status = "ok"`, `message = NA`. In the default run on my 120-subject count trial (`methods = NULL`, CIs off), 76 of the 300 rows are such empty rows (6 bootstrap CI-only types + bayes_boot `basic`, for each of 11 classes), which makes up most of the NA p-values in the printed table with no reason given. Repro output:
  ```
       method       type       pval pval_method ci_a ci_method status message
  1 bootstrap percentile 0.05940594   bootstrap   NA bootstrap     ok    <NA>
  2 bootstrap      basic         NA   bootstrap   NA bootstrap     ok    <NA>
  3 bootstrap calibrated         NA   bootstrap   NA bootstrap     ok    <NA>
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  set.seed(1)
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE,
    classes = "InferenceCountPoisson", methods = list(bootstrap = c("percentile", "basic", "calibrated")),
    B = 101, compute_conf_intervals = FALSE)
  print(res$results_table[, c("method", "type", "pval", "pval_method", "ci_a", "ci_method", "status", "message")])
  ```
- Workaround used, if any: filter rows with `is.na(pval) & is.na(message)` out of the report, or request only pval-side types in `methods`.

### F2: The suite's `estimand` column labels Poisson, negative-binomial and hurdle-Poisson fits as `log_rate_ratio_marginal`, while the objects themselves report `get_estimand() == "conditional"`; hurdle NB (same kind of coefficient as hurdle Poisson) is labelled `log_rate_ratio_conditional`, so Combined Evidence groups and weights are built on inconsistent labels
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceCountHurdlePoisson`, Description: "Under the default `estimand = "conditional"`, the reported treatment effect is the coefficient from the conditional (truncated, Y > 0) count component ... *conditional on clearing the hurdle*: it is not the effect on the unconditional mean E[Y]". `?InferenceCountPoisson`: "Under the default `estimand = "conditional"`, beta_T is the log-rate-ratio". `InferenceCountNegBin$get_supported_estimands()` errors with "only its default ("conditional") estimand is available ... marginal estimands are not available for this class in this release". `?InferenceSuite` (`combined_evidence_weighting = "estimand_grouped"`, `w_i = 1/(G*m_i)`) groups rows by this label.
- Observed:
  ```
                inference_class                   estimand object_get_estimand
  1  InferenceCountHurdleNegBin log_rate_ratio_conditional         conditional
  2 InferenceCountHurdlePoisson    log_rate_ratio_marginal         conditional
  3        InferenceCountNegBin    log_rate_ratio_marginal         conditional
  4       InferenceCountPoisson    log_rate_ratio_marginal         conditional
  ```
  On the full 120-subject run the same split puts HurdleNegBin + ZeroInflatedNegBin in a "cond" group (35 rows, weight 0.0071 each) and HurdlePoisson + ZeroInflatedPoisson + Poisson + NegBin + QuasiPoisson + RobustPoisson in a "marginal" group (117 rows, weight 0.0021 each). The hurdle-Poisson count-part coefficient is explicitly *not* a marginal effect per its own help page, and NegBin does not support a marginal estimand at all.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnbinom(n, mu = exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1), size = 2))
  cls = c("InferenceCountPoisson", "InferenceCountNegBin", "InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin")
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, classes = cls, methods = "wald")
  tab = res$results_table[, c("inference_class", "estimand")]
  tab$object_get_estimand = sapply(tab$inference_class, function(cl) get(cl)$new(des, verbose = FALSE)$get_estimand())
  print(tab)
  ```
- Workaround used, if any: none; I did not use the Combined Evidence p-value in the report.

### F3: `max_secs_per_class` does not give a `"timeout"` row: when the limit fires it escapes `run_all_inference()` (and an enclosing `tryCatch`) and aborts the R session, and classes that run far past the limit are still reported `ok`
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `run_all_inference()` argument `max_secs_per_class`: "after which that class's row gets `status = "timeout"` instead of hanging the whole report"; Details: "A single class's construction or fit failure never aborts the report - it is caught and recorded as that class's `status`/`message`." The documented known limitation only says a single long native call may not be interrupted.
- Observed (exact output, including the exact message text): ZINB (first class) took ~69 s with `max_secs_per_class = 2` and is reported `ok`; then while the next class (Poisson) is fitting:
  ```
  Classes 1/2   [============ 50%              ] Estimated Time Left: 1m 9sError in .Call(`_EDI_fast_poisson_regression_cpp`, X, y, warm_start_beta,  :
    reached elapsed time limit
  Execution halted
  ```
  The `tryCatch(..., error = ...)` around the call never runs its handler (the "CAUGHT ERROR" line is not printed) and the script exits with status 1. In a second run (`classes = c("InferenceCountPoisson", "InferenceCountNegBin")`, same arguments) each class took ~13 s, both rows came back `status = "ok"`, and no timeout was recorded at all. The default 11-class suite with `max_secs_per_class = 200` finished normally.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 120
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnbinom(n, mu = exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1), size = 2))
  suite = InferenceSuite$new(des)
  res = tryCatch(
    suite$run_all_inference(screen = TRUE, plots = FALSE,
      classes = c("InferenceCountZeroInflatedNegBin", "InferenceCountPoisson"),
      methods = "rand", r = 2000, compute_conf_intervals = TRUE, max_secs_per_class = 2),
    error = function(e) { cat("CAUGHT ERROR:", conditionMessage(e), "\n"); NULL })
  cat("returned; class:", class(res), "\n")
  if (!is.null(res)) print(res$results_table[, c("inference_class", "pval", "ci_a", "status", "message")])
  ```
- Workaround used, if any: Do not use `max_secs_per_class`. Control run time with `methods`, `r`, `B` and `compute_conf_intervals` instead.

### F4: A misspelled `type` in a list-shaped `methods` (e.g. `bootstrap = "percentil"`) is silently accepted: the row comes back with `type = NA`, a numeric p-value from an unnamed bootstrap flavour, `status = "ok"` and no message
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `methods`: "a typed sentinel with zero resulting types, still gets exactly one row with `method`/`type = NA_character_` ... rather than being silently dropped". So an unknown type should give zero types, an NA row and no p-value, or better an error like the one for an unknown sentinel (`methods = "walds"` errors and lists the valid sentinels).
- Observed (exact output, including the exact message text): ```
          inference_class    method type  estimate       pval status message
  1 InferenceCountPoisson bootstrap <NA> 0.3381951 0.05940594     ok    <NA>
  ```
  `method` is `"bootstrap"`, not NA, and a p-value was computed. The report does not say which type produced it.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE,
    classes = "InferenceCountPoisson", methods = list(bootstrap = "percentil"), B = 101)   # typo
  print(res$results_table[, c("inference_class", "method", "type", "estimate", "pval", "status", "message")])
  ```
- Workaround used, if any: Check the spelling of every type against the help page by hand.

### F5: `print()`, `summary()` and `combined_evidence` count result rows as "classes": the header says "300 class(es)" for 11 classes, `summary()` says "classes: 2" then "ok: 6", and `n_classes_used` includes rows that got weight 0
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?print.EDIInferenceSuiteResults`/`?summary.EDIInferenceSuiteResults` ("counts by `status`"). `?InferenceSuite`, `combined_evidence_weights`: "an unnamed usable class defaults to weight `0` (excluded)". So an excluded row should not count in `n_classes_used`, and a class count should count classes.
- Observed (exact output, including the exact message text): ```
  rows: 6  classes: 2
  <EDIInferenceSuiteResults> 6 class(es) -- Design: iBCRD Fixed (response: count), n = 60
  ...
  InferenceSuite$run_all_inference() summary
    classes:            2
      ok:           6
  ...
   $ n_classes_used: int 6
   $ weights_used  : Named num [1:6] 0 0 0 1 1 1
  ```
  On the full default run: header `300 class(es)`, `summary()` `classes: 11` / `ok: 300`, `n_classes_used: 195`. The printed footer also says "(6 inferences, weighting = custom)" although only 3 have weight > 0.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE,
    classes = c("InferenceCountPoisson", "InferenceCountNegBin"),
    methods = c("wald", "score", "lik_ratio"), combined_evidence_weighting = "custom",
    combined_evidence_weights = c(InferenceCountPoisson = 1))
  cat("rows:", nrow(res$results_table), " classes:", length(unique(res$results_table$inference_class)), "\n")
  print(res)                                   # header says "6 class(es)"
  print(summary(res))                          # "classes: 2" but "ok: 6"
  str(res$combined_evidence[c("n_classes_used", "weights_used")])  # 6 'classes used' although 3 rows have weight 0
  ```
- Workaround used, if any: Count rows and classes myself from `results_table`.

### F6: The printed per-estimand Combined Evidence line shows `p = NA` for an estimand group with a single inference, although that p-value is valid and is used in the overall combined p-value
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, Returns: `combined_evidence` is `NA` only "if fewer than 2 rows are usable" overall. A Cauchy combination of one p-value is that p-value. The overall combination does use the single row with weight 0.5.
- Observed (exact output, including the exact message text): ```
    Estimand: log rate ratio cond (1 inferences)    : p =     NA
    Estimand: log rate ratio marginal (2 inferences): p = 0.0425
  Combined evidence against the sharp null across 2 estimands
  (3 inferences, weighting = uniform within estimand):
  p = 0.0579
  ...
  CCT of the single 'cond' p-value (should equal it): 0.09023947
  overall manual: 0.05789562  suite: 0.05789562
  ```
  The same happens in the CI-enabled run of F7 (both groups have one row; each prints `p = NA` while the overall is 0.114). There is no warning or note.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rnbinom(n, mu = exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1), size = 2))
  cls = c("InferenceCountPoisson", "InferenceCountNegBin", "InferenceCountHurdleNegBin")
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, classes = cls, methods = "wald")
  tab = res$results_table
  print(tab[, c("inference_class", "estimand", "pval", "weight")])
  cct = function(p, w) { s = sum(w * tan((0.5 - p) * pi)) / sum(w); 0.5 - atan(s) / pi }
  g = tab$estimand == "log_rate_ratio_conditional"
  cat("CCT of the single 'cond' p-value (should equal it):", cct(tab$pval[g], 1), "\n")
  cat("overall manual:", cct(tab$pval, tab$weight), " suite:", res$combined_evidence$pval, "\n")
  ```
- Workaround used, if any: Read the single row's own `pval` from `results_table`.

### F7: When a class's randomization CI errors ("not supported"), `run_all_inference(compute_conf_intervals = TRUE)` reports `ci_a = ci_b = NA` with `ci_method = "rand"`, `status = "ok"`, an empty `message` and no warning, so the explanation is lost
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `run_all_inference()`: "A single class's construction or fit failure never aborts the report - it is caught and recorded as that class's `status`/`message`." Other failed procedures in the same table do get a `message` (e.g. "CI (jackknife) failed: ... unavailable (negbin_jackknife_not_supported)"). Calling the same method directly raises a clear error (see F8).
- Observed (exact output, including the exact message text): ```
                  inference_class method      pval ci_a ci_b ci_method status message
  1    InferenceCountQuasiPoisson   rand 0.1005025   NA   NA      rand     ok    <NA>
  2 InferenceAllSimpleAverageDiff   rand 0.1306533   NA   NA      rand     ok    <NA>
  > res$results_table$warnings
  [1] NA NA
  ```
  On my 120-subject trial the same silent NA rand CI appears for InferenceAllSimpleAverageDiff, InferenceAllSimpleMeanDiffPooledVar, InferenceAllSimpleWilcox, InferenceCountQuasiPoisson and InferenceCountRobustPoisson.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  set.seed(1)
  res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE,
    classes = c("InferenceCountQuasiPoisson", "InferenceAllSimpleAverageDiff"), methods = "rand",
    r = 199, compute_conf_intervals = TRUE)
  print(res$results_table[, c("inference_class", "method", "pval", "ci_a", "ci_b", "ci_method", "status", "message")])
  print(res$results_table$warnings)
  ```
- Workaround used, if any: I called `compute_rand_confidence_interval()` on the object directly to get the reason.

### F8: The "Randomization confidence intervals are not supported" error for InferenceCountQuasiPoisson says the class's estimate "is on the raw response scale", which is false (it is a log rate ratio, identical to InferenceCountPoisson's, whose randomization CI works), and it points to an internal TODO file path
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceCountQuasiPoisson` is a log-link quasi-Poisson regression; `compute_estimate()` returns the same log-rate-ratio coefficient as `InferenceCountPoisson`, for which `compute_rand_confidence_interval()` works on the same design. A user-facing error should not send the user to `R/package_metadata/future_release_plans/release_v1_0_5.md`, which is not in the installed package.
- Observed (exact output, including the exact message text): ```
  [1] 0.3381951      # QuasiPoisson estimate
  [1] 0.3381951      # Poisson estimate
  Error : Randomization confidence intervals are not supported for InferenceCountQuasiPoisson with count responses: the search inverts a log shift of the count response, but this class's estimate is on the raw response scale, so the delta bounds are not on the scale of the estimate (or of its asymptotic CI). The randomization p-value and the randomization-bootstrap CI remain available. See TODO-119 in R/package_metadata/future_release_plans/release_v1_0_5.md.
        2.5%      97.5%
  -0.2232718  0.9196604   # Poisson rand CI on the same data
  ```
  The same message is raised for InferenceCountRobustPoisson (also a log-rate-ratio estimate). For InferenceAllSimpleAverageDiff (a raw mean difference) the explanation is correct.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  inf = InferenceCountQuasiPoisson$new(des, verbose = FALSE); inf$num_cores = 1L
  print(inf$compute_estimate())                # a log rate ratio (same as InferenceCountPoisson)
  print(InferenceCountPoisson$new(des, verbose = FALSE)$compute_estimate())
  inf$set_seed(1)
  try(inf$compute_rand_confidence_interval(r = 199, show_progress = FALSE))
  inf2 = InferenceCountPoisson$new(des, verbose = FALSE); inf2$num_cores = 1L; inf2$set_seed(1)
  print(inf2$compute_rand_confidence_interval(r = 199, show_progress = FALSE))
  ```
- Workaround used, if any: Use InferenceCountPoisson's randomization CI for the same log-rate-ratio estimate.

### F9: The printed suite table wraps a negative number in scientific notation across two lines and mangles it: `-4.22e-06` is shown as `-4.22e--` with `06` on the next line (`-8.47e-05` as `-8.47e--` / `05` on my trial)
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?print.EDIInferenceSuiteResults`: prints "a readable table"; positive values in the same column (`4.22e-06`) print intact.
- Observed (exact output, including the exact message text): ```
  Wilcox                   HL shift    0.0       2.15e-06  -4.22e--  4.22e-06  1.00e+00   wald                            ok
                                                           06
  ```
  `results_table` holds the right value (`ci_a = -4.21557e-06`). On the 120-subject trial the Wilcoxon Wald CI upper bound `-8.469374e-05` printed as `-8.47e--` / `05`. A reader copying the printed table would read a wrong number.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  d2 = DesignFixediBCRD$new(response_type = "count", n = 40, seed = 1)
  d2$add_all_subjects_to_experiment(data.frame(x = rnorm(40))); d2$assign_w_to_all_subjects()
  d2$add_all_subject_responses(c(rep(0, 15), rep(1, 5), rep(0, 5), rep(1, 15))[order(-d2$get_w())])
  res = InferenceSuite$new(d2)$run_all_inference(screen = TRUE, plots = FALSE,
    classes = "InferenceAllSimpleWilcox", methods = "wald", compute_conf_intervals = TRUE)
  print(res$results_table[, c("estimate", "ci_a", "ci_b")])
  ```
- Workaround used, if any: Report from `results_table`, not from the printed table.

### F10: `?InferenceSuite` tells users to consult `EDI_INFERENCE_SUITE_METHOD_SENTINELS` and `is_inference_class_compatible_with_design_metadata()`, but neither is exported or documented, so neither can be inspected
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `methods`: "`NULL` considers every sentinel in `EDI_INFERENCE_SUITE_METHOD_SENTINELS`"; Description: "*Compatibility rules* (see `is_inference_class_compatible_with_design_metadata()` ...)". The sibling registry `EDI_COMPREHENSIVE_SLOW_PATHS` cited in the same paragraph is exported and has a help page.
- Observed (exact output, including the exact message text): ```
  [1] FALSE
  [1] FALSE
  No documentation for 'EDI_INFERENCE_SUITE_METHOD_SENTINELS' in specified packages and libraries
  [1] TRUE
  ```
  I needed the sentinel list to choose `methods` and could only get it from the error message for an invalid sentinel (`methods = "walds"`), which lists the valid sentinels. The Description also names an internal source file (`inference_class_registry.R`) and functions (`infer_inference_requires_blocking_design()`) that users cannot see.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  exists("EDI_INFERENCE_SUITE_METHOD_SENTINELS")          # FALSE: referenced by ?InferenceSuite (methods argument)
  exists("is_inference_class_compatible_with_design_metadata")  # FALSE: referenced by ?InferenceSuite (Compatibility rules)
  help("EDI_INFERENCE_SUITE_METHOD_SENTINELS", package = "EDI")  # no documentation
  exists("EDI_COMPREHENSIVE_SLOW_PATHS")                   # TRUE (the sibling registry is exported)
  ```
- Workaround used, if any: Pass a bogus sentinel and read the valid list from the error message.

### F11: After `set_num_cores(2)`, `run_all_inference(num_cores = 2L)` breaks the persistent cluster: one class's randomization p-value fails with "ignoring SIGPIPE signal" while its row stays `status = "ok"`, and later direct `compute_rand_two_sided_pval()` calls in the same session fail too
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?set_num_cores`: "initializes a persistent parallel cluster ... to be used by all Design and Inference objects". `?InferenceSuite`, `num_cores`: "If greater than `1`, fit classes in parallel across this many forked workers"; the Reproducibility paragraph promises the same results with any `num_cores`. Each setting works alone (`set_num_cores(2)` + suite `num_cores = 1`, or suite `num_cores = 2` with no `set_num_cores`): every p-value is 0.0201005. A failed procedure should not be `status = "ok"`.
- Observed (exact output, including the exact message text):
  ```
                inference_class method      pval status                                        message
  1  InferenceCountQuasiPoisson   rand        NA     ok p-value (rand) failed: ignoring SIGPIPE signal
  2 InferenceCountRobustPoisson   rand 0.1005025     ok                                           <NA>
  Error in serialize(data, node$con, xdr = FALSE) : ignoring SIGPIPE signal
  ```
  The last line comes from a plain `InferenceCountQuasiPoisson$compute_rand_two_sided_pval()` after the suite returned: the session's cluster is now unusable. In my final analysis script (which starts with `set_num_cores(2)` as the CI instructions require) the QuasiPoisson and RobustPoisson randomization p-values and CIs all came back `NA`, and the combined-evidence p-value silently lost those rows. Which class fails varies from run to run.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  set_num_cores(2)                      # the documented global core setting
  suite = InferenceSuite$new(des)
  set.seed(1)
  res = suite$run_all_inference(screen = TRUE, plots = FALSE,
    classes = c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson"),
    methods = "rand", r = 199, num_cores = 2L)
  print(res$results_table[, c("inference_class", "method", "pval", "status", "message")])
  inf = InferenceCountQuasiPoisson$new(des, verbose = FALSE); inf$set_seed(1)
  try(inf$compute_rand_two_sided_pval(r = 199, show_progress = FALSE))   # same session, no suite involved
  ```
- Workaround used, if any: do not call `set_num_cores()` in a session that runs `run_all_inference(num_cores > 1)`; or keep the suite at `num_cores = 1L`.

### F12: `InferenceCountRobustPoisson` returns its estimate and p-values as a value named `"treatment"`, while every other class (Poisson, QuasiPoisson, NegBin, ...) returns unnamed numbers
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): the reporting article ("From one inference object") says each `compute_*_two_sided_pval()` returns "a single number", and it builds a results table from such values across classes. The same accessor should return the same shape in every class.
- Observed (exact output, including the exact message text):
  ```
  InferenceCountRobustPoisson  estimate names: "treatment" pval names: "treatment"
  InferenceCountPoisson        estimate names: NULL       pval names: NULL
  InferenceCountQuasiPoisson   estimate names: NULL       pval names: NULL
  InferenceCountNegBin         estimate names: NULL       pval names: NULL
  ```
  This made `all.equal(suite_pval, one_by_one_pval)` report a mismatch for the RobustPoisson row ("names for current but not for target") in my suite-vs-one-by-one check, although the numbers are identical (0.02579754).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  for (cl in c("InferenceCountRobustPoisson", "InferenceCountPoisson", "InferenceCountQuasiPoisson", "InferenceCountNegBin")) {
    inf = get(cl)$new(des, verbose = FALSE)
    cat(sprintf("%-28s estimate names: %-10s pval names: %s\n", cl, deparse(names(inf$compute_estimate())),
                deparse(names(inf$compute_asymp_two_sided_pval()))))
  }
  ```
- Workaround used, if any: `unname()` every returned value.

### F13: `InferenceCountNegBin`'s score p-value depends on whether the score CI was computed first on the object, so the same suite row differs between `compute_conf_intervals = FALSE` and `TRUE`
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): the score test is a deterministic function of the data (no resampling). The reporting article ("From one inference object") calls the CI and p-value methods in any order and treats each as fixed. `?InferenceSuite` promises the same task result "whichever other tasks run with it".
- Observed (exact output, including the exact message text):
  ```
            p_before         p_after_ci p_new_obj_ci_first
      0.102496276724     0.102496276724     0.102563451776
  ```
  On my 120-subject trial, `InferenceCountNegBin{score}` has `pval = 0.009492170545` in the CI-off suite run and in a one-by-one call, but `0.009492578964` in the CI-on suite run. The difference is small (a relative 4e-5 and 7e-4 here), but it made the suite-vs-one-by-one check fail for exactly this row, and a reported p-value should not depend on call order.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  n = 60
  X = data.frame(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
  des = DesignFixediBCRD$new(response_type = "count", n = n, seed = 3)
  des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
  des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1)))
  a = InferenceCountNegBin$new(des, verbose = FALSE)
  p_before = a$compute_score_two_sided_pval()
  ci = a$compute_score_confidence_interval()
  p_after = a$compute_score_two_sided_pval()
  b = InferenceCountNegBin$new(des, verbose = FALSE); invisible(b$compute_score_confidence_interval())
  p_fresh_after_ci = b$compute_score_two_sided_pval()
  print(c(p_before = p_before, p_after_ci = p_after, p_new_obj_ci_first = p_fresh_after_ci), digits = 12)
  ```
- Workaround used, if any: compute the p-value on a fresh object before any CI call.
