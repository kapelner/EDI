# Findings: observational (existing-experiment / observational data)

### F1: `n = NULL`, the documented default of every fixed design constructor (incl. `ObservationalDesign`), fails as soon as the data are added
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?ObservationalDesign`, `?DesignFixed`, `?DesignFixedBernoulli`, `?DesignFixediBCRD`, `?DesignFixedBlocking` all show `n = NULL` as the default in Usage. `?DesignFixedBlocking` argument `B_target` says outright "if `n` is not yet known it is resolved to `floor(sqrt(n))` when subjects are added". For an analyst with an existing data frame, `n` is just `nrow(X)`, so `add_all_subjects_to_experiment(X)` should be able to fill it in. If it can't, `n` should be a required argument and the constructor should say so.
- Observed: the constructor accepts `n = NULL`; then `add_all_subjects_to_experiment()` stops with
  `Error in self$assert_fixed_sample() : This type of design currently only works with fixed sample, i.e., you must specify n upon initialization`
  The same happens for `ObservationalDesign`, `DesignFixedBernoulli`, `DesignFixediBCRD` and `DesignFixedBlocking`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); X = data.frame(x1 = rnorm(10), g = factor(rep(c("a", "b"), 5)))
  for (cl in c("ObservationalDesign", "DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking")) {
    des = get(cl)$new(response_type = "continuous")          # n = NULL (documented default)
    cat(cl, ": ", tryCatch({des$add_all_subjects_to_experiment(X); "OK"},
                           error = function(e) conditionMessage(e)), "\n")
  }
  ```
- Workaround used, if any: pass `n = nrow(X)` explicitly.

### F2: On an `ObservationalDesign`, the inference object's `capabilities()` / `supports()` still report randomization tests, randomization CIs and randomization bootstrap, which then refuse to run
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Inference` `capabilities()`: "Returns the effective metadata-backed capabilities for this inference object". `?ObservationalDesign` says randomization tests, randomization CIs and the randomization bootstrap "throw" for this design. The design itself gets this right (`supports_randomization_draw()` is `FALSE`), and so do `get_procedure_validity()` and `InferenceSuite` (both leave out the randomization procedures). An "effective" capability list for this object should leave them out too.
- Observed: `inf$capabilities()` includes `"randomization_test"`, `"randomization_ci"`, `"randomization_bootstrap"`, `"randomization_bootstrap_ci"`, and `inf$supports(...)` returns `TRUE` for each. Then `compute_rand_two_sided_pval()` errors with `Randomization inference is not available for this design (no randomization mechanism to draw a fresh assignment from). Use asymptotic inference, plain nonparametric/Bayesian bootstrap, or a concrete design subclass with a randomization mechanism.`
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1); n = 40; x = rnorm(n); w = rbinom(n, 1, plogis(x)); y = 1 + w + x + rnorm(n)
  des = ObservationalDesign$new(n = n, response_type = "continuous")
  des$add_all_subjects_to_experiment(data.frame(x = x))
  des$assign_w_to_all_subjects(w_precomputed = w)
  des$add_all_subject_responses(y)
  inf = InferenceContinOLS$new(des)
  inf$supports(c("randomization_test", "randomization_ci", "randomization_bootstrap"))  # all TRUE
  des$supports_randomization_draw()                                                    # FALSE
  try(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE))                 # errors
  ```
- Workaround used, if any: use `des$supports_randomization_draw()` or `inf$get_procedure_validity()` to decide what is valid.

### F3: `InferenceSuite$run_all_inference(num_cores = 2)` after `set_num_cores(2)` silently loses some p-values (`NA`, status `"ok"`) and gives the message "ignoring SIGPIPE signal"
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite` `run_all_inference()` `num_cores`: parallel forked workers, and "a task gives the same result whichever other tasks run with it", "with any `num_cores`". The task statement for this run asks for `set_num_cores(2)` (the documented global core budget). The same run with `num_cores = 1L`, or without the global `set_num_cores(2)`, gives finite p-values for these rows.
- Observed: with `set_num_cores(2)` plus `num_cores = 2L`, the `InferenceAllSimpleAverageDiff` jackknife and bootstrap-percentile rows have `pval = NA`, `status = "ok"`, and `message = "p-value (jackknife) failed: ignoring SIGPIPE signal"` (and the same for bootstrap). The serial run gives 2.03e-58 and 0.0202. Which rows are hit varies between runs. In an earlier run of the same kind (two classes, all methods), the NA rows had `message = NA`, with nothing at all to explain them. The "SIGPIPE" message is about the worker process, not the statistics, and it does not tell the user what to change.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(42); n = 150
  x = rnorm(n); w = rbinom(n, 1, plogis(x)); y = 1 + 2*w + x + rnorm(n)
  des = ObservationalDesign$new(n = n, response_type = "continuous")
  des$add_all_subjects_to_experiment(data.frame(x = x))
  des$assign_w_to_all_subjects(w_precomputed = w)
  des$add_all_subject_responses(y)
  run = function(k) { set.seed(3); s = InferenceSuite$new(des)
    invisible(capture.output(r <- s$run_all_inference(screen = TRUE, plots = FALSE, num_cores = k,
       classes = c("InferenceContinOLS", "InferenceAllSimpleAverageDiff"),
       methods = c("wald", "jackknife", "bootstrap"), B = 99)))
    tb = r$results_table
    tb[tb$method != "bootstrap" | tb$type == "percentile", c("inference_class","method","type","pval","status","message")] }
  set_num_cores(2)
  print(run(1L))   # all finite
  print(run(2L))   # some NA with status "ok", message "... failed: ignoring SIGPIPE signal"
  ```
- Workaround used, if any: `num_cores = 1L` in `run_all_inference()` (keeping `set_num_cores(2)`).

### F4: Help pages for the observational / existing-data path point users to internal developer files that are not shipped with the package
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): references a user can follow. `?ObservationalDesign` (`supports_randomization_draw()`), `?Design` (`capabilities()`, `supports_resampling()`, `supports_randomization_draw()`, `randomization_family()`) and `?DesignFixedBinaryMatch` (Batch pregeneration) send the reader to `fix_design_hierarchy.md` ("Observational Design Migration", "Capability Model", "TODO-28", "AllocationMatrixValidation"), and to source files (`inference_suite.R`, `inference_all_abstract_rand_bootstrap.R`, `design_class_registry.R`) for the explanation.
- Observed: no such document is installed (`list.files(system.file(package = "EDI"), recursive = TRUE, pattern = "fix_design|TODO", ignore.case = TRUE)` returns `character(0)`). The pages also describe "the live bug this fixes" and internal stubs (`draw_ws_raw()`), which a user cannot check. So the explanation of *why* observational designs support some resampling and not others is partly off-page.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  txt = capture.output(tools::Rd2txt(utils:::.getHelpFile(help("ObservationalDesign", package = "EDI"))))
  grep("fix_design_hierarchy", txt, value = TRUE)
  list.files(system.file(package = "EDI"), recursive = TRUE, pattern = "fix_design", ignore.case = TRUE)  # character(0)
  ```
- Workaround used, if any: relied on the parts of `?ObservationalDesign` and `?Design` that stand on their own.

### F5: With `w_precomputed` all 0 (nobody treated), `InferenceContinOLS` reports a covariate's slope as the "treatment effect", with a CI and p-value and no warning
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?Inference` describes estimating "a treatment effect in a completed design", and there is a non-estimability API (`is_nonestimable()`, `get_nonestimable_reason()`). With no treated subject the effect cannot be estimated: `lm(y ~ w + x)` gives `NA` for `w`. EDI should either reject the assignment or mark the fit non-estimable. This is realistic for existing data, e.g. a mis-coded treatment column, or a subset with one arm only.
- Observed: `assign_w_to_all_subjects(w_precomputed = rep(0, n))` is accepted. In the repro below, `compute_estimate()` returns `1.362234`, which is exactly the coefficient of `x` in `lm(y ~ x)`. `compute_asymp_confidence_interval()` gives `0.977 1.748`, the p-value is `6.96e-08`, `is_nonestimable()` is `FALSE`, and there is no warning. `InferenceAllSimpleAverageDiff` on the same design returns `NA`, also without a warning.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(5); n = 30; x = rnorm(n); y = 1 + x + rnorm(n)
  d = ObservationalDesign$new(n = n, response_type = "continuous")
  d$add_all_subjects_to_experiment(data.frame(x = x))
  d$assign_w_to_all_subjects(w_precomputed = rep(0, n))
  d$add_all_subject_responses(y)
  i = InferenceContinOLS$new(d)
  i$compute_estimate(); i$is_nonestimable()
  i$compute_asymp_confidence_interval(); i$compute_asymp_two_sided_pval()
  coef(lm(y ~ x))["x"]                                      # same number as the "treatment effect"
  InferenceAllSimpleAverageDiff$new(d)$compute_estimate()   # NA, silent
  ```
- Workaround used, if any: check `table(w)` before loading the data.

### F6: `assign_w_to_all_subjects(w_precomputed = )` accepts treatment codes other than 0/1 (1/2, a factor, 0.5) without a word, while `overwrite_all_subject_assignments()` rejects them
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixed` `assign_w_to_all_subjects`: "`w_precomputed`: Optional {0,1} numeric vector of length n". `?Design` `overwrite_all_subject_assignments`: "A {0,1} vector". The article "Analyzing an Experiment You Already Ran" says the data has "a 0/1 treatment column". Existing data sets often code arms 1/2 (e.g. `survival::veteran$trt`), so a check matters here.
- Observed: `w + 1` (codes 1/2), `factor(w)` and a vector containing `0.5` are all stored as given (`get_w()` returns `2 1 2 2 ...` and `1 0 0.5 1 1`). Downstream results are then inconsistent with each other. With 1/2 codes, `InferenceContinOLS` gives the same estimate as with 0/1 (0.90196), but `InferenceAllSimpleAverageDiff` and `InferenceAllSimpleWilcox` silently return `NA`. With a 0.5 entry, OLS treats `w` as a dose (estimate 0.94044) and the mean difference returns 1.0036. By contrast, `overwrite_all_subject_assignments(c(1, 0, rep(2, n - 2)))` errors with `Assertion on 'w' failed: Element 3 is not <= 1.`. The same holds for `DesignFixediBCRD` and `DesignFixedBernoulli`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(5); n = 30; x = rnorm(n); w = rbinom(n, 1, 0.4); y = 1 + w + x + rnorm(n)
  mk = function(wv) { d = ObservationalDesign$new(n = n, response_type = "continuous")
    d$add_all_subjects_to_experiment(data.frame(x = x))
    d$assign_w_to_all_subjects(w_precomputed = wv); d$add_all_subject_responses(y); d }
  d12 = mk(w + 1); head(d12$get_w())                       # 2 1 2 2 2 2 : accepted
  InferenceContinOLS$new(d12)$compute_estimate()           # 0.90196 (same as 0/1)
  InferenceAllSimpleAverageDiff$new(d12)$compute_estimate()# NA, no warning
  InferenceAllSimpleWilcox$new(d12)$compute_estimate()     # NA, no warning
  head(mk(factor(w))$get_w())                              # 2 1 2 ... accepted
  mk(replace(w, 3, 0.5))$get_w()[1:5]                      # 1 0 0.5 1 1 accepted
  d = mk(w); try(d$overwrite_all_subject_assignments(c(1, 0, rep(2, n - 2))))  # rejected here
  ```
- Workaround used, if any: recode to integer 0/1 before loading (`as.integer(trt == 2)`).

### F7: A `w_precomputed` of the wrong length is silently recycled to length n; the only signal is base R's recycling warning
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixed`: "`w_precomputed`: Optional {0,1} numeric vector of length n". A vector of length n - 1 (e.g. one row dropped from the treatment column but not from the covariates) should be rejected, with a message naming `w_precomputed` and both lengths.
- Observed: only `Warning message: In private$w[1:self$get_n()] = as.numeric(w_precomputed) : number of items to replace is not a multiple of replacement length` is shown (it also names an internal field). The design then holds a length-30 `w` whose last entry is a recycled copy of the first, and analysis goes ahead on it.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(5); n = 30; x = rnorm(n); w = rbinom(n, 1, 0.4); y = 1 + w + x + rnorm(n)
  d = ObservationalDesign$new(n = n, response_type = "continuous")
  d$add_all_subjects_to_experiment(data.frame(x = x))
  d$assign_w_to_all_subjects(w_precomputed = w[-1])   # length 29, only a base-R warning
  d$add_all_subject_responses(y)
  length(d$get_w()); tail(d$get_w()); tail(w[-1])
  InferenceContinOLS$new(d)$compute_estimate()        # runs on the recycled w
  ```
- Workaround used, if any: check `length(w) == nrow(X)` yourself.

### F8: An `NA` in `w_precomputed` is accepted and stored; it fails only later, inside the model fit, with "Error in qr.default(X_mat) : NA/NaN/Inf in foreign function call (arg 1)"
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixed`: `w_precomputed` is a "{0,1} numeric vector of length n". A missing treatment code is common in received data sets. The assignment call should reject it, with a message naming `w_precomputed` and the position of the `NA`, as `overwrite_all_subject_assignments()` does for other bad codes (checkmate-style `Assertion on 'w' failed: ...`).
- Observed: `assign_w_to_all_subjects(w_precomputed = replace(w, 3, NA))` and `add_all_subject_responses()` both succeed, and `get_w()` shows the `NA`. Constructing `InferenceContinOLS` then stops with `Error in qr.default(X_mat) : NA/NaN/Inf in foreign function call (arg 1)`, which names internals and not the treatment vector. The behaviour is the same for `DesignFixediBCRD` and `DesignFixedBernoulli`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(5); n = 30; x = rnorm(n); w = rbinom(n, 1, 0.4); y = 1 + w + x + rnorm(n)
  d = ObservationalDesign$new(n = n, response_type = "continuous")
  d$add_all_subjects_to_experiment(data.frame(x = x))
  d$assign_w_to_all_subjects(w_precomputed = replace(w, 3, NA))   # accepted
  head(d$get_w())                                                  # 1 0 NA 1 1 1
  d$add_all_subject_responses(y)                                   # accepted
  try(InferenceContinOLS$new(d))                                   # qr.default error
  ```
- Workaround used, if any: drop or impute subjects with missing treatment before loading.

### F9: `DesignFixedBinaryMatch` with an explicit pairing `m` accepts a `w_precomputed` that treats both members of one pair and neither of another, then runs a within-pair randomization test on it
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedBinaryMatch`: "for pair k, one of its two members is assigned to treatment and the other to control". The article "Analyzing an Experiment You Already Ran" table says to use this design for "Pairs formed first, one of each pair treated". An observed `w` that breaks the pairs cannot come from this design. The `m` argument is validated strictly ("each pair ID must occur exactly twice"), but the `w` given with it is not checked against it. For the randomization test, the reference distribution then does not contain the observed assignment.
- Observed: no error or warning. `tapply(d$get_w(), pair, sum)` shows pairs with 2 and 0 treated. `compute_rand_two_sided_pval(r = 199)` returns 0.01005, a p-value against draws that all have one treated per pair.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(7); npair = 15; n = 2 * npair; pair = rep(1:npair, each = 2)
  x = rnorm(n); w = as.vector(sapply(1:npair, function(i) sample(0:1))); y = 5 + w + x + rnorm(n)
  w[1:2] = 1; w[3:4] = 0                       # pair 1 both treated, pair 2 both control
  d = DesignFixedBinaryMatch$new(n = n, response_type = "continuous", m = pair)
  d$add_all_subjects_to_experiment(data.frame(x = x))
  d$assign_w_to_all_subjects(w_precomputed = w)   # accepted silently
  d$add_all_subject_responses(y)
  tapply(d$get_w(), pair, sum)[1:3]               # 2 0 1
  i = InferenceAllSimpleAverageDiff$new(d); i$set_seed(1)
  i$compute_rand_two_sided_pval(r = 199, show_progress = FALSE)
  ```
- Workaround used, if any: check `all(tapply(w, pair, sum) == 1)` before loading.

### F10: With unequal strata and the default `equal_block_sizes = TRUE`, the error comes neither "when subjects are added" (help page) nor at "an inference fit" (article); it comes only at the first bootstrap or randomization call
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedBlocking`, argument `equal_block_sizes`: "A second check fires when subjects are added: if the covariate-based strata produce unequal block sizes the design errors at that point with a message suggesting `equal_block_sizes = FALSE`." The article "Analyzing an Experiment You Already Ran", section Pitfalls / Stratified and blocked experiments, says it errors "not when the data are added but the first time the blocks are used (a redraw, a randomization test or an inference fit)". The two pages contradict each other.
- Observed: `add_all_subjects_to_experiment()`, `assign_w_to_all_subjects(w_precomputed = )`, `add_all_subject_responses()`, `InferenceContinOLS$new()`, `compute_estimate()` (2.7325), the Wald CI and the (block-aware) jackknife CI all run without error. Only `compute_bootstrap_confidence_interval()` and `compute_rand_two_sided_pval()` stop, with `This design requires equal block sizes but the strata produced unequal block sizes (8, 12, 20, 30) for n = 70 (4 blocks from strata_cols = site). ... Set equal_block_sizes = FALSE to allow unequal blocks, ...`. Following that message (`equal_block_sizes = FALSE`) works: redraws keep 4/6/10/15 treated per site, and the randomization p-value of the mean difference (0.14, r = 2000) agrees with a hand-coded within-site permutation test (0.153, 4000 draws). So the analyst can get a full analysis whose Wald and jackknife parts used a design that the bootstrap and randomization parts later reject.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(11); sizes = c(8, 12, 20, 30); n = sum(sizes)
  site = factor(rep(c("A","B","C","D"), sizes)); age = round(rnorm(n, 50, 10))
  w = unlist(lapply(sizes, function(s) sample(rep(0:1, each = s/2))))
  y = 20 + 3*w + 0.2*age + c(0,6,12,-6)[site] + rnorm(n, sd = 4)
  d = DesignFixedBlocking$new(n = n, response_type = "continuous", strata_cols = "site")  # equal_block_sizes = TRUE
  d$add_all_subjects_to_experiment(data.frame(site = site, age = age))   # no error (help says it errors here)
  d$assign_w_to_all_subjects(w_precomputed = w)
  d$add_all_subject_responses(y)
  inf = InferenceContinOLS$new(d)                 # no error (article says an inference fit errors)
  inf$compute_estimate(); inf$compute_asymp_confidence_interval()
  inf$compute_jackknife_wald_confidence_interval()
  inf$set_seed(1); try(inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE))
  try(inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE))
  ```
- Workaround used, if any: `equal_block_sizes = FALSE`, as the message says.

### F11: The article says the default BCa bootstrap interval for the four-site trial is `NA` with a warning (leave-one-site-out jackknife needs at least 5 sites); it actually returns a finite interval with no warning
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): article "Analyzing an Experiment You Already Ran", section "Randomization test": "The default type, BCa, takes its acceleration from a leave-one-site-out jackknife and needs at least 5 sites, so with four sites it returns `NA` with a warning." (`?InferenceJackknife` says instead that the automatic unit on `DesignFixedBlocking` is one subject, `"observation_within_block"`. That would explain the behaviour below, but then the article is out of date.)
- Observed: on the article's own data and code, `compute_bootstrap_confidence_interval(alpha = 0.05, B = 501)` (default type) returns `0.4764505 3.34324` with no warning. The percentile interval is `0.4851443 3.344995`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(20261117); n = 80
  trial = data.frame(site = rep(c("A","B","C","D"), each = 20), age = round(rnorm(n, 50, 10)),
                     bmi = round(rnorm(n, 28, 4), 1), smoker = rbinom(n, 1, 0.3))
  trial$treated = unlist(lapply(1:4, function(s) sample(rep(0:1, each = 10))))
  trial$bmi[sample(n, 6)] = NA
  site_effect = c(A = 0, B = 6, C = 12, D = -6)
  trial$score = 20 + 3 * trial$treated + 0.2 * trial$age + site_effect[trial$site] + rnorm(n, sd = 4)
  des = DesignFixedBlocking$new(n = n, response_type = "continuous", strata_cols = "site", prob_T = 0.5)
  des$add_all_subjects_to_experiment(trial[, c("site", "age", "bmi", "smoker")])
  des$assign_w_to_all_subjects(w_precomputed = trial$treated)
  des$add_all_subject_responses(trial$score)
  inf = InferenceContinOLS$new(des); inf$num_cores = 1L; inf$set_seed(1)
  inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 501, show_progress = FALSE)  # finite, no warning
  ```
- Workaround used, if any: none needed.

### F12: `InferenceIncidCMH` is listed as applicable to an `ObservationalDesign`, but its asymptotic (Wald) p-value tries to redraw `w` and fails with an internal design error
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Design` `applicable_inference_class_names()` lists classes "legal for this design object", and `incompatible_inference_classes_due_to_design_structure()` exists "so callers can tell exactly why a class is missing ... instead of only discovering it as a construction-time error". `?ObservationalDesign` says only procedures that redraw `w` (randomization tests/CIs/randomization bootstrap) are unavailable; an asymptotic p-value is not one of them. The error text should at least name the class and the procedure.
- Observed: `"InferenceIncidCMH" %in% d$applicable_inference_class_names()` is `TRUE`, and CMH is not in the incompatible list (which does list the exact Fisher/Zhang classes with reasons). `compute_estimate()` returns 0.1828, with the warning `InferenceIncidCMH: this non-blocking design's realized treatment allocation is not exactly balanced (n_T = 61, n_C = 59); ...`. `compute_asymp_two_sided_pval()` then fails with `Error in private$draw_ws_raw(r) : This operation is not supported. Observational designs are not controlled designs based on randomized allocations.` In `InferenceSuite` the row has `pval = NA` but `status = "ok"`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(21); n = 120
  x1 = rnorm(n); x2 = rbinom(n, 1, 0.4); w = rbinom(n, 1, plogis(0.7 * x1))
  y = rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.6 * x1 - 0.5 * x2))
  d = ObservationalDesign$new(n = n, response_type = "incidence")
  d$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
  d$assign_w_to_all_subjects(w_precomputed = w)
  d$add_all_subject_responses(y)
  "InferenceIncidCMH" %in% d$applicable_inference_class_names()   # TRUE
  names(d$incompatible_inference_classes_due_to_design_structure()) # CMH not listed
  i = InferenceIncidCMH$new(d)
  i$compute_estimate()
  try(i$compute_asymp_two_sided_pval())                            # draw_ws_raw error
  ```
- Workaround used, if any: use `InferenceIncidLogRegr` (agrees with `glm(binomial)` to about 5 digits: Wald CI -0.63458 vs -0.63458, LR CI -0.64473 1.08328 vs profile `confint()` -0.64476 1.08329, LR p 0.60896 vs 0.60896).
