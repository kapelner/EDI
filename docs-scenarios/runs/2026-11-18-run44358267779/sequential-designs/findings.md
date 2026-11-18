# Findings: sequential-designs (EDI 1.0.4)

### F1: With the documented default `n = NULL`, every completeness check and every Inference constructor fails with "argument is of length zero", so an open-enrollment trial can never be analyzed
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOne` ("Sample size and stopping") and every `DesignSeqOneByOne*$new()` list `n = NULL` as the default: "If `NULL`, the final sample size is left to the caller; the class does not provide a stopping rule." `?DesignSeqOneByOneBernoulli` ("Nonparametric bootstrap") says that with `n = NULL` "the bootstrap method is not blocked at runtime", which implies inference runs. `?Design` documents `check_experiment_completed()` as returning `TRUE`/`FALSE`. At minimum, a clear error saying "n = NULL designs cannot be analyzed; ..." was expected.
- Observed: After all 40 subjects are assigned and all 40 responses recorded (`get_n()` returns `40L`):
  ```
  check_experiment_completed : ERROR: argument is of length zero
  assert_all_subjects_arrived : ERROR: argument is of length zero
  assert_all_responses_recorded : ERROR: argument is of length zero
  InferenceContinOLS$new(d)  -> Error: argument is of length zero
  ```
  The error call shown by R is `if (private$fixed_sample & private$t < private$n) stop(...)`. Same for `DesignSeqOneByOneEfron`, `DesignSeqOneByOneAtkinson`, and with `InferenceAllSimpleMeanDiffPooledVar`. So `n = NULL` lets you enroll and assign but nothing can ever be analyzed, and the message does not say why or what to do.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  X = data.frame(x1 = rnorm(40), x2 = rnorm(40)); y = X$x1 + rnorm(40)
  d = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = NULL, seed = 1)
  for (t in 1:40) { w = d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]); d$add_one_subject_response(t, y[t] + 0.5 * w) }
  d$get_n()                         # 40
  try(d$check_experiment_completed())   # Error: argument is of length zero
  try(InferenceContinOLS$new(d, verbose = FALSE))  # Error: argument is of length zero
  ```
- Workaround used, if any: Ran the actual trial with `n = 60` fixed in advance (as the "Running a Sequential Trial" article recommends). For an analysis of the n = NULL Atkinson trial, copied covariates / realized w / y into an analysis-only `DesignFixedBernoulli` (article "When some outcomes never arrive") and used asymptotic results only.

### F2: KK14 / KK21 accept `n = NULL` at construction but the 5th assignment fails with "missing value where TRUE/FALSE needed" and leaves the design corrupted (t advances, no w stored)
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOneKK14` / `?DesignSeqOneByOneKK21` usage shows `n = NULL` as the default and the constructor prints "Initialized a DesignSeqOneByOneKK14 experiment with response type continuous and not fixed sample." The article "Running a Sequential Trial" says "The Kapelner–Krieger designs need [n]" (burn-in `t_0_pct * n`). If `n` is required, the constructor should refuse `n = NULL` with a message saying so; if not required, assignment should work. Also, a failed assignment should not leave the subject half-added.
- Observed: Subjects 1-4 are assigned; subject 5 (first post-"few subjects" step, two covariates) gives `Error: missing value where TRUE/FALSE needed`. Same with `t_0_pct = 0.35` given explicitly, and for KK21. After the error `get_t()` is 5 but `get_w()` has length 4; `get_block_ids()` then errors "Block identifiers are improperly sized for this design."; every further call to `add_one_subject_to_experiment_and_assign()` errors the same way and increments `get_t()` again (6, ...).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026)
  X = data.frame(age = round(rnorm(10, 55, 10)), sev = round(rnorm(10), 2))
  d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = NULL, verbose = TRUE, seed = 11)
  for (t in 1:6) print(tryCatch(d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]),
                                error = function(e) conditionMessage(e)))
  d$get_t(); d$get_w()          # 6 vs. length-4 w
  try(d$get_block_ids())        # "Block identifiers are improperly sized for this design."
  ```
- Workaround used, if any: Used `n = 60` for KK14 and KK21.

### F3: KK14/KK21 constructors accept `lambda` outside [0, 1] (and `t_0_pct` outside [0, 1]); the failure surfaces later, mid-trial, as base-R messages that do not name the argument
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignSeqOneByOneKK14` argument `lambda`: "The F-distribution quantile level ... (default 0.1)"; `?DesignSeqOneByOneKK21`: "the `lambda` quantile (default 10%)"; `t_0_pct`: "The fraction of `n` subjects to randomize into the reservoir before matching begins". A quantile level / fraction must lie in [0, 1]; the constructor validates `seed` and Efron's `weighted_coin_prob` with clear messages ("weighted_coin_prob must be a single number with 0.5 < weighted_coin_prob <= 1."), so the same was expected for `lambda` and `t_0_pct`.
- Observed: `DesignSeqOneByOneKK14$new(..., lambda = -1)` (also 1.5, 2, NA) constructs silently. The first post-burn-in assignment then emits `Warning: NaNs produced` and fails with `Error: missing value where TRUE/FALSE needed`, i.e. after a third of the patients have been enrolled. KK21 with `lambda = -1` or `1.5` fails at the first matching attempt with `Error: 'probs' outside [0,1]`. `t_0_pct = -0.2` and `t_0_pct = 1.5` are accepted without a word (`1.5` silently gives a design that never matches: 0 pairs out of 30).
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(3)
  X = data.frame(age = round(rnorm(30, 55, 10)), sev = round(rnorm(30), 2)); y = X$sev + rnorm(30)
  d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = 30, lambda = -1, seed = 1)   # no error
  try(for (t in 1:30) d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]))
  # Warning: NaNs produced ; Error: missing value where TRUE/FALSE needed
  d21 = DesignSeqOneByOneKK21$new(response_type = "continuous", n = 30, lambda = 1.5, seed = 1)
  try(for (t in 1:30) { d21$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE]); d21$add_one_subject_response(t, y[t]) })
  # Error: 'probs' outside [0,1]
  d3 = DesignSeqOneByOneKK14$new(response_type = "continuous", n = 30, t_0_pct = 1.5, seed = 1)
  for (t in 1:30) d3$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
  max(d3$get_block_ids())   # 0 pairs, no warning
  ```
- Workaround used, if any: Used the defaults / values in (0, 1).

### F4: `InferenceContinKKGLMM` parametric bootstrap has almost no spread: the 95% CI is ~70x narrower than the Wald CI and the p-value sits at its minimum
- Kind: reference mismatch
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceParamBootstrap`, `compute_param_bootstrap_confidence_interval()` / `compute_param_bootstrap_pval()`: simulate B datasets from the fitted model and refit. The replicate estimates should spread like the estimator's sampling distribution, i.e. with SD close to the model SE. For comparison, on the same design `InferenceContinKKOLSOneLik`'s parametric bootstrap CI [-0.277, 0.777] is close to its Wald CI [-0.311, 0.806], and the GLMM's own Wald SE (0.2300) matches `lme4::lmer(y ~ w + age + severity + (1|pair), REML = FALSE)` (SE 0.2300).
- Observed: KK14 design, n = 60, 26 pairs + 8 reservoir. GLMM estimate 0.2202, Wald CI [-0.238, 0.679], p = 0.347. Parametric bootstrap: CI `0.2140066 0.2273261` (B = 199, seed 1) and `0.2135321 0.2273291` (B = 499, seed 2); `compute_param_bootstrap_pval(delta = 0, B = 199)` = `0.01` (the smallest value possible, 2/200). `get_last_param_bootstrap_estimate_diagnostics()$replicate_estimates` = 0.217 0.223 0.219 0.220 0.222 ... (n_success 499, no failures), so the replicate SD is about 0.003 against a model SE of 0.23. `InferenceSuite` reports the same `param_boot_direct` p = 0.01 with status "ok". By contrast `compute_lik_ratio_bootstrap_two_sided_pval()` gives 0.345, which is consistent with Wald.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(20261118)
  n = 60
  X = data.frame(age = round(rnorm(n, 55, 10)), severity = round(rnorm(n), 2))
  y0 = 0.05 * (X$age - 55) + 1.2 * X$severity + rnorm(n)
  d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 7041)
  for (i in 1:n) { w = d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); d$add_one_subject_response(i, y0[i] + 0.6 * w) }
  g = InferenceContinKKGLMM$new(d, verbose = FALSE); g$set_seed(1)
  g$compute_asymp_confidence_interval(0.05)                        # -0.238  0.679
  g$compute_param_bootstrap_confidence_interval(alpha = 0.05, B = 199)  # 0.214 0.227
  g$compute_param_bootstrap_pval(delta = 0, B = 199)              # 0.01
  sd(g$get_last_param_bootstrap_estimate_diagnostics()$replicate_estimates)  # ~0.003
  k = InferenceContinKKOLSOneLik$new(d, verbose = FALSE); k$set_seed(1)
  k$compute_param_bootstrap_confidence_interval(alpha = 0.05, B = 199)  # -0.277 0.777 (sane)
  ```
- Workaround used, if any: Reported Wald / likelihood-ratio results for the GLMM; did not use its parametric bootstrap.

### F5: `InferenceSuite$run_all_inference()` with `max_secs_per_class` and `num_cores = 2` prints the whole report and then fails with "arguments imply differing number of rows: 1, 0", so no results object is returned
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `run_all_inference()` argument `max_secs_per_class`: "Optional per-class elapsed-time limit in seconds ..., after which that class's row gets `status = "timeout"` instead of hanging the whole report." `num_cores` is a documented argument. A results list with `results_table` should come back.
- Observed: With `num_cores = 2L, compute_conf_intervals = TRUE, max_secs_per_class = 20` on a completed KK14 design, the per-row table prints ("Status: Completed in ...") and then: `Error in data.frame(inference_class = r$inference_class, method = r$method, : arguments imply differing number of rows: 1, 0`. The same call with `num_cores = 1L` (3 rows) or without `max_secs_per_class` (3 rows) works. In the full 13-class run (2 min 13 s) all results were lost. That run also printed `Error in sendMaster(...): write error, closing pipe to the master` from a forked worker.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set_num_cores(2)
  set.seed(20261118)
  n = 60
  X = data.frame(age = round(rnorm(n, 55, 10)), severity = round(rnorm(n), 2))
  y0 = 0.05 * (X$age - 55) + 1.2 * X$severity + rnorm(n)
  d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 7041)
  for (i in 1:n) { w = d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); d$add_one_subject_response(i, y0[i] + 0.6 * w) }
  suite = InferenceSuite$new(d)
  res = suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinRobustRegr",
                                num_cores = 2L, compute_conf_intervals = TRUE, max_secs_per_class = 20)
  # Error in data.frame(...): arguments imply differing number of rows: 1, 0
  ```
- Workaround used, if any: Dropped `max_secs_per_class` (or used `num_cores = 1L`).

### F6: With `n = NULL`, outcomes can only be recorded in enrollment order; an out-of-order outcome for an enrolled subject is refused with the false message "subject that has not yet arrived"
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?Design` `add_one_subject_response(t, y)`: "`t` The subject index." The article "Running a Sequential Trial", "Outcomes that arrive late or out of order": "`add_one_subject_response(t, y)` records the outcome of the subject enrolled `t`-th, whenever it arrives; `t` must be a subject who has already enrolled." (It adds "With `n` set, the outcomes can come in any order", but neither the article nor any help page says that with `n = NULL` they cannot.) Expected: either accept the outcome, or give an error that states the real rule (outcomes must be entered in enrollment order when `n = NULL`).
- Observed: Efron or Bernoulli design with `n = NULL`, 3 subjects enrolled (`get_t()` = 3). Recording the outcome of subject 3 first gives `Error: You cannot add a response for a subject that has not yet arrived when the sample size is not fixed in advance.` Subjects 1 and 2 are accepted, and then 3 is too. Order 2, 1, 3: 2 is refused, 1 is accepted, 3 is refused (because 2 is still missing). Subject 3 has clearly arrived (it was assigned). With `n = 60` the same sequence is accepted in any order.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  X = data.frame(x1 = rnorm(5), x2 = rnorm(5))
  d = DesignSeqOneByOneEfron$new(response_type = "continuous", n = NULL, seed = 1)
  for (t in 1:3) d$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
  d$get_t()                                   # 3
  try(d$add_one_subject_response(3, 1.5))     # Error: ... subject that has not yet arrived ...
  d$add_one_subject_response(1, 1.5)          # ok
  d$add_one_subject_response(2, 1.5)          # ok
  d$add_one_subject_response(3, 1.5)          # now ok
  ```
- Workaround used, if any: In analysis.R, buffered the late outcomes and entered each one only once all earlier subjects' outcomes were in (in enrollment order). This is harmless for Atkinson, which ignores outcomes, but would change KK21's allocation.
