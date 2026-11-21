# Findings: simulation-framework (run of 2026-11-21)

### F1: The notation-glossary vignette says `SimulationFramework` custom hooks receive `w` in {-1,+1}, but they receive {0,1} (as `?SimulationFramework` says)
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `vignette("notation-glossary")`, symbol table row "`SimulationFramework` custom hooks": "`custom_apply_treatment_and_noise`/`make_estimand_fn` receive `w` in {-1,+1} format ... convert with `(w+1)/2`". `?SimulationFramework` (arguments `custom_apply_treatment_and_noise`, `make_estimand_fn`) says the opposite: "`w` uses {0, 1} encoding". The two documents contradict each other; a user following the vignette's `(w+1)/2` advice would turn control into 0.5 and treated into 1, which halves the planted effect.
- Observed: both hooks receive `w` with values `0,1` and 25 ones for n = 50 under `DesignFixediBCRD`:
  ```
  W VALUES: 0,1  n1= 25
  ESTIMAND w: 0,1
  ```
  So the help page is right and the glossary row is wrong.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  gen = function(state, rep) { X = data.frame(x1 = rnorm(state$n)); list(X = X, y_linear_model = X$x1) }
  noise = function(y_linear_model, w, rep_data, state) {
    cat("noise hook w values:", sort(unique(w)), "\n")
    list(y = y_linear_model + state$betaT * w + rnorm(length(w)), dead = rep(1, length(w)))
  }
  est = function(beta_T) function(y_linear_model, X, w, rep_data, state) {
    cat("estimand hook w values:", sort(unique(w)), "\n"); beta_T }
  sim = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 1L, betaT = 0.8, Nrep_W = 1L, custom_replication_data_generator = gen,
    custom_apply_treatment_and_noise = noise, make_estimand_fn = est,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)
  sim$run()
  # prints "noise hook w values: 0 1" and "estimand hook w values: 0 1"
  ```
- Workaround used, if any: trusted the help page ({0,1}) and used `w` as-is.

### F2: `?SimulationFramework` tells users to call `$get_errors()` after `$run()`, but `SimulationFramework` objects have no `get_errors` method
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, argument `stop_on_error`: "If FALSE, the framework records the error ... Use `$get_errors()` after `$run()` to inspect the captured errors." The method list of the same page (new, run, get_all_intermediate_data, clear_all_intermediate_data_and_gc, clone) has no `get_errors`; it exists only on `SimulationFrameworkReport` (`?SimulationFrameworkReport`, `$get_errors()`).
- Observed: `sim$get_errors()` fails with `Error: attempt to apply non-function` (an R-internal message that does not point to the report class). `names(sim)` is `".__enclos_env__" "clone" "clear_all_intermediate_data_and_gc" "get_all_intermediate_data" "run" "initialize"`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  sim = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 2L, stop_on_error = FALSE,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)
  sim$run()
  try(sim$get_errors())                         # Error: attempt to apply non-function
  SimulationFrameworkReport$new(sim)$get_errors()   # works
  ```
- Workaround used, if any: `SimulationFrameworkReport$new(sim)$get_errors()`.

### F3: `?SimulationFramework` says `$run()` returns a `SimulationFrameworkReport`, and also that it returns the `SimulationFramework` object; the second is true
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, method `run()`: description "Execute the configured simulation replications ... and return a `SimulationFrameworkReport`." The "Returns" line of the same method says "The `SimulationFramework` object itself (invisibly)."
- Observed: `out = sim$run(); identical(out, sim)` is `TRUE`, `inherits(out, "SimulationFrameworkReport")` is `FALSE`. A user who reads the description and writes `rep = sim$run(); rep$summarize()` gets `attempt to apply non-function`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  sim = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 2L,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)
  out = sim$run()
  class(out)                      # "SimulationFramework" "R6"
  try(out$summarize())            # Error: attempt to apply non-function
  ```
- Workaround used, if any: `SimulationFrameworkReport$new(sim)$summarize()`, as the article does.

### F4: With `num_cores = 1`, `SimulationFramework` does not seed replication i with `seed + i`, so the same `seed` gives different results at `num_cores = 1` and `num_cores = 2`
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `vignette("reproducibility")`, section "Simulation (`SimulationFramework`): per-replication and per-cache-job seeds": "Each replication `i` ... is dispatched with `rep_seed = seed + i`, and the worker executing that replication calls `set.seed(rep_seed)` itself", which "makes a `SimulationFramework` run reproducible **regardless of `num_cores`**"; same vignette, "Reproducing a documented example" item 3: "`num_cores` ... do[es] not need to match the original run". The planning-a-study article says the same: "`seed` gives every replication its own seed (`seed + i`), so the run is reproducible whatever `num_cores` is".
- Observed: the 2-core run follows the documented rule (first covariate draw of rep i equals `set.seed(77 + i); rnorm(1)`), the serial run does not (rep 1 equals `set.seed(77); rnorm(1)`, later reps continue one stream). Every estimate differs between the two:
  ```
  cores1:  rep true_estimand(=X[1,1])  estimate      cores2: rep true_estimand  estimate
             1    -0.5496380 1.1029427                       1     0.7172775 0.8277331
             2     0.3304505 1.1953549                       2     1.1073639 0.6192724
             3    -0.2536702 0.6416456                       3    -0.1519526 0.8933295
             4     2.2691350 0.9493186                       4    -1.0350747 0.5659804
  set.seed(77+i) first rnorm, i = 1..4: 0.7172775 1.107364 -0.1519526 -1.035075
  ```
  The same happens with the built-in data generator and with `DesignFixediBCRD`, `DesignFixedBinaryMatch` and `DesignFixedBernoulli` (all estimates differ between 1 and 2 cores). A rerun at the same `num_cores` is identical, so each setting is reproducible only with itself.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  rec = function(state, rep) { x1 = rnorm(state$n); list(X = data.frame(x1 = x1), y_linear_model = x1, x11 = x1[1]) }
  est = function(beta_T) function(y_linear_model, X, w, rep_data, state) rep_data$x11   # records X[1,1] as true_estimand
  mk = function(cores) SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 1L, betaT = 0.8, Nrep_W = 4L, custom_replication_data_generator = rec, make_estimand_fn = est,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 77L, num_cores = cores, verbose = FALSE)
  key = function(s) { r = as.data.frame(SimulationFrameworkReport$new(s)$get_results()); r[order(r$rep), c("rep", "true_estimand", "estimate")] }
  a = mk(1L); a$run(); b = mk(2L); b$run()
  print(key(a)); print(key(b))                       # all rows differ
  sapply(1:4, function(i) { set.seed(77 + i); rnorm(1) })  # matches the 2-core run only
  ```
- Workaround used, if any: ran every reported simulation with `num_cores = 2` and compared reproducibility only at equal `num_cores`.

### F5: Resuming a serial (`num_cores = 1`) run with `continue_from_last_result_row = TRUE` replays the first replications' data as the new replications, so the "extra" replications are duplicates
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, `continue_from_last_result_row`: "loads existing results ... and skips previously completed replications"; planning-a-study article, "Practical tips": "an interrupted run resumes where it stopped". A run of 3 reps resumed to 6 should equal a fresh 6-rep run with the same seed (it does at `num_cores = 2`), and in any case reps 4-6 must be new, independent draws.
- Observed: at `num_cores = 1`, after a 3-rep run and a resume to `Nrep_W = 6`, reps 4, 5, 6 have exactly the same covariates and estimates as reps 1, 2, 3; no message:
  ```
  cores 1 : resumed vs fresh
    rep true_estimand  estimate  fresh_x11 fresh_est
  1   1    -0.5496380 1.1029427 -0.5496380 1.1029427
  2   2     0.3304505 1.1953549  0.3304505 1.1953549
  3   3    -0.2536702 0.6416456 -0.2536702 0.6416456
  4   4    -0.5496380 1.1029427  2.2691350 0.9493186
  5   5     0.3304505 1.1953549  0.2492946 0.7721138
  6   6    -0.2536702 0.6416456  0.4717237 0.9659317
  ```
  At `num_cores = 2` the resumed run equals the fresh run row for row. A user who extends a serial run (say from 500 to 1000 reps to tighten a power estimate) gets the same 500 trials twice: the point estimate does not change and the Monte Carlo interval computed from `n_pow = 1000` is too narrow by a factor of about sqrt(2).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  rec = function(state, rep) { x1 = rnorm(state$n); list(X = data.frame(x1 = x1), y_linear_model = x1, x11 = x1[1]) }
  est = function(beta_T) function(y_linear_model, X, w, rep_data, state) rep_data$x11
  mk = function(Nrep, file, cont) SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 1L, betaT = 0.8, Nrep_W = Nrep, custom_replication_data_generator = rec, make_estimand_fn = est,
    inference_types_and_params = list(asymp_pval = list()), save_to_disk_every_n_rep = 1L,
    results_filename = file, continue_from_last_result_row = cont, seed = 77L, num_cores = 1L, verbose = FALSE)
  f = tempfile(fileext = ".csv")
  mk(3L, f, TRUE)$run()
  b = mk(6L, f, TRUE); b$run()
  r = as.data.frame(SimulationFrameworkReport$new(b)$get_results())
  r[order(r$rep), c("rep", "true_estimand", "estimate")]   # reps 4:6 repeat reps 1:3
  ```
- Workaround used, if any: none needed for the main analysis (fresh runs, `num_cores = 2`).

### F6: `alpha` is checked with a message about `'p'` (which is also the name of the covariate-count argument), and `alpha = 0` is accepted, giving infinite CIs that `summarize()` then reports as coverage `NA`
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, argument `alpha`: "Numeric in (0,1)". `alpha = 1.5` should fail with a message that names `alpha`; `alpha = 0` is outside (0,1) and should be rejected too.
- Observed: `alpha = 1.5` fails with `'p' must be a single number between 0 and 1`. In this constructor `p` is the number of covariates, so the message points the user at the wrong argument. `alpha = 0` is accepted without a word: every `asymp_ci` row has `ci_lo = -Inf, ci_hi = Inf`, and `summarize()` reports `coverage = NA`, `ci_length = NA` (an interval of (-Inf, Inf) does contain `betaT`), and `power = 0`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  mk = function(a) SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 5L, alpha = a,
    inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)
  try(mk(1.5))      # Error: 'p' must be a single number between 0 and 1
  s = mk(0); s$run()
  r = SimulationFrameworkReport$new(s)
  head(as.data.frame(r$get_results())[, c("inference_type", "estimate", "ci_lo", "ci_hi")])  # -Inf, Inf
  as.data.frame(r$summarize())[, c("inference_type", "coverage", "ci_length", "power")]     # coverage NA
  ```
- Workaround used, if any: none needed; used `alpha = 0.05`.

### F7: A negative `sd_noise` is not rejected; the run then fails with a message about missing outcomes and a link to the missing-data article
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, argument `sd_noise`: "Numeric > 0". A value of -1 should be rejected at construction with a message naming `sd_noise`, as `betaT = NA` ("betaT must contain finite numeric values") and `Nrep_W = 0` ("Nrep_W must be a positive integer") are.
- Observed: the constructor accepts `sd_noise = -1`; `run()` fails with
  ```
  SimulationFramework stopped on error.
  stage: design_build
  ...
  message: The response for subject 1 is NA, but responses may not be NA for response_type = "continuous". EDI has no method for missing outcomes; handle them before the data reach EDI (see "What EDI does not handle: missing outcomes" in https://kapelner.github.io/EDI/articles/missing-covariates.html).
  ```
  The user did not supply responses; the NAs come from `rnorm(sd = -1)`, and the message sends them to a page about missing data.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  sim = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 5L, sd_noise = -1,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)        # accepted
  sim$run()                            # error about NA responses / missing outcomes
  ```
- Workaround used, if any: none needed.

### F8: A design parameter the constructor does not accept makes the whole cell vanish with a warning about design/inference compatibility, even with `stop_on_error = TRUE`; the real cause (unused argument) is never shown
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, `design_classes_and_params`: "Each generator must be constructable with only `response_type` and `n` plus any extra params supplied in this list"; `stop_on_error`: "If TRUE (default), any error raised during a simulation path aborts the run immediately." A typo in a design parameter should stop the run with the constructor's error (`DesignFixediBCRD$new(..., foo = 1)` gives `unused argument (foo = 1)`), just as a bad `inference_types_and_params` argument does ("contains argument(s) not accepted by compute_asymp_two_sided_pval(): foo").
- Observed: no error; `run()` finishes, the cell has zero result rows, and the only output is
  ```
  Warning: SimulationFramework: every design/inference combo was filtered out as invalid for cell (response_type=continuous, n=50, p=2, cond_exp_func_model=linear, betaT=0.8) -- designs tried: DesignFixediBCRD (foo=1); inferences tried: InferenceContinOLS. This cell will contribute ZERO result rows. If this is unexpected, check design/inference compatibility (e.g. an inference class requiring a KK matching-on-the-fly design paired with a non-matching design).
  ```
  `SimulationFrameworkReport$new(sim)$get_errors()` is empty. The message suggests a compatibility problem, not a bad argument. The same warning appears for an `incidence` response with `InferenceContinOLS`, where it is right; here it hides a typo. If a run has several designs, a misspelled parameter (e.g. `prop_acceptible`) silently drops that design from the comparison and leaves only a warning.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  sim = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list(foo = 1)),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 5L, stop_on_error = TRUE,
    inference_types_and_params = list(asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, verbose = FALSE)
  sim$run()                                     # only the "filtered out as invalid" warning
  r = SimulationFrameworkReport$new(sim)
  nrow(r$get_results()); length(r$get_errors()) # 0 rows, 0 errors
  ```
- Workaround used, if any: check each design's parameters by calling its constructor directly before passing them to the framework.

### F9: `SimulationFrameworkReport$new(sim, alpha = a)` keeps the CIs built at the framework's alpha but tests their coverage against `1 - a`, so `coverage_pval` flags correctly calibrated intervals
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFrameworkReport`, `new()`, argument `alpha`: "Significance level for coverage and power calculations"; `summarize()`: "`coverage_pval` is the exact two-sided binomial test p-value of H0: true coverage = 1 - alpha". Either the report should refuse an `alpha` different from the one the CIs were built at, or say that only power/size use it.
- Observed: for a run at `alpha = 0.05` (40 reps, 95% Wald CIs, coverage 0.925): the report with `alpha = 0.10` or `0.20` shows the same `coverage` 0.925 (CIs are not rebuilt) but `coverage_pval` changes to 0.794 and then 0.0479. That last value equals `binom.test(37, 40, 0.80)$p.value`: the 95% intervals are tested as if they were 80% intervals and look miscalibrated at the 5% level. `power` does change with `alpha` (0.800 to 0.875), as it should.
  ```
  report alpha NA  : coverage 0.925  coverage_pval 0.4517764  power 0.8
  report alpha 0.1 : coverage 0.925  coverage_pval 0.794113   power 0.875
  report alpha 0.2 : coverage 0.925  coverage_pval 0.04786946 power 0.875
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  s = SimulationFramework$new(response_type = "continuous",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceContinOLS = list()),
    n = 50L, p = 2L, betaT = 0.8, Nrep_W = 40L, alpha = 0.05,
    inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 1L, num_cores = 1L, verbose = FALSE)
  s$run()
  for (a in c(0.05, 0.10, 0.20)) print(as.data.frame(SimulationFrameworkReport$new(s, alpha = a)$summarize())[,
    c("inference_type", "coverage", "coverage_pval", "power")])
  ```
- Workaround used, if any: built every report at the framework's own alpha.

### F10: For `response_type = "incidence"`, `SimulationFramework` scores `InferenceIncidGCompRiskDiff` against the logit-scale `betaT` instead of a risk difference, so its reported coverage is 0 and its MSE is wrong
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?SimulationFramework`, `betaT`: "on the logit scale for incidence"; `make_estimand_fn`: "Default NULL uses beta_T directly as the ground truth", with an "is_mean_diff gate" mentioned but not explained. The framework already converts the truth for `InferenceIncidNewcombeRiskDiff` (its `true_estimand` is the marginal risk difference, about 0.197 for `betaT = 1`). `InferenceIncidGCompRiskDiff` estimates the same kind of quantity, a marginal risk difference (planning-a-study article, Worked example 2: "a logistic model with the covariates, standardized to a marginal risk difference"), so it should be scored against the same truth.
- Observed (n = 50, `betaT = 1`, built-in DGP, 100 reps, `DesignFixediBCRD`):
  ```
                         inference        MSE coverage coverage_pval
  1    InferenceIncidGCompRiskDiff 0.67554017     0.00 7.888609e-131
  2 InferenceIncidNewcombeRiskDiff 0.02049645     0.92  1.650417e-01
  mean of get_results():   estimate  true_estimand
    InferenceIncidGCompRiskDiff   0.190   1.000
    InferenceIncidNewcombeRiskDiff 0.195  0.198
  ```
  The two estimators agree (0.190 vs 0.195), but G-computation is compared with 1.0, so `summarize()` reports 0% coverage, an MSE about 33 times too large, and a `coverage_pval` that says the method is badly miscalibrated. At `betaT = 0` both report about 94% coverage, so a size-only check would not catch this. There is no warning. Both objects report `get_estimand()` = `"conditional"`, so nothing visible to the user explains why they are treated differently.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  s = SimulationFramework$new(response_type = "incidence",
    design_classes_and_params = list(DesignFixediBCRD = list()),
    inference_classes_and_params = list(InferenceIncidNewcombeRiskDiff = list(), InferenceIncidGCompRiskDiff = list()),
    n = 50L, p = 2L, betaT = 1, Nrep_W = 100L, inference_types_and_params = list(asymp_ci = list()),
    results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
    seed = 3L, num_cores = 2L, verbose = FALSE)
  s$run(); r = SimulationFrameworkReport$new(s)
  as.data.frame(r$summarize())[, c("inference", "MSE", "coverage", "coverage_pval")]
  res = as.data.frame(r$get_results())
  aggregate(cbind(estimate, true_estimand) ~ inference, data = res, FUN = mean)
  ```
- Workaround used, if any: supply `make_estimand_fn` returning the marginal risk difference (not run for lack of time), or read G-comp coverage from `get_results()` against Newcombe's `true_estimand`.
