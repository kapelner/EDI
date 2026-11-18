# Findings: fixed-designs (run 2026-11-18, EDI v1.0.4 as printed at load)

### F1: After `compute_rand_two_sided_pval()`, `InferenceAllSimpleMeanDiffPooledVar`'s asymptotic p-value and CI silently become `NA`
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceAsymp` / `?Inference` describe `compute_asymp_two_sided_pval()` and `compute_asymp_confidence_interval()` as independent methods of the same object; nothing says one call invalidates another. Calling them on a fresh object gives the pooled-variance t-test result (matches `t.test(var.equal = TRUE)` exactly: p = 0.9359437).
- Observed: on the same object, after one `compute_rand_two_sided_pval(r = 101)` call, `compute_asymp_two_sided_pval()` returns `NA` and `compute_asymp_confidence_interval()` returns `NA NA`, with no warning or message; `is_nonestimable()` is `FALSE` and `compute_estimate()` still returns the number. It happens on both `DesignFixediBCRD` and `DesignFixedRerandomization`. `InferenceAllSimpleAverageDiff` and `InferenceContinOLS` are not affected, and neither is `compute_rand_confidence_interval()` (asymptotic p stays 0.9359 after it). In a 200-replicate simulation loop that computed the randomization p-value first and then the asymptotic one, all 200 asymptotic p-values were `NA`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(1)
  n = 20
  X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
  y = X$x1 + rnorm(n)
  d = DesignFixediBCRD$new(response_type = "continuous", n = n, seed = 1)
  d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
  d$add_all_subject_responses(y)
  inf = InferenceAllSimpleMeanDiffPooledVar$new(d)
  inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE)   # 0.871
  inf$compute_asymp_two_sided_pval()          # NA, no warning
  inf$compute_asymp_confidence_interval()     # NA NA, no warning
  inf$is_nonestimable()                       # FALSE
  InferenceAllSimpleMeanDiffPooledVar$new(d)$compute_asymp_two_sided_pval()  # 0.9359437 on a fresh object
  w = d$get_w(); t.test(y[w == 1], y[w == 0], var.equal = TRUE)$p.value      # 0.9359437
  ```
- Workaround used, if any: compute the asymptotic results first, or build a new inference object for each procedure.

### F2: `DesignFixedRerandomization` with `prop_acceptable` assigns the real allocation from a different distribution than the one its randomization test uses as reference, and the randomization test over-rejects
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedRerandomization`, Description: rerandomization "filters the design's own randomization distribution, which is what makes it directly compatible with Fisherian/randomization-based inference (the accepted allocations remain a well-defined — if truncated — randomization distribution, valid for randomization tests/CIs restricted to that truncated support)". The `prop_acceptable` paragraph says it "draws r / prop_acceptable candidates and keeps the r with the lowest M(w)", "equivalent in the large-draw limit to an implied cutoff at the prop_acceptable quantile". So the observed allocation and the reference allocations should come from the same law, and the randomization test should have size close to alpha.
- Observed: `assign_w_to_all_subjects()` uses r = 1. That gives the best of `1/prop_acceptable` = 100 draws, which is not a draw from the lowest 1%: with n = 40 and two covariates, 31.7% of assigned allocations (300 seeds) had M(w) above the base distribution's 1% quantile (0.00177). The randomization reference from `draw_ws_according_to_design(501)` (best 501 of 50,100) never did (0 of 501). Two-sample KS between the two M distributions: D = 0.317, p < 2.2e-16. As a result, the randomization test of `InferenceAllSimpleMeanDiffPooledVar` (r = 201) under a true null with prognostic covariates rejected at nominal 5% in **7.25%** of 800 trials (MCSE 0.77%). With `obj_val_cutoff` set to the same 1% quantile it rejected in 5.88%. The docs' "large-draw limit" caveat does not cover this, because the observed assignment is always a one-draw (r = 1) case.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(20261118)
  n = 40
  X = data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  M = function(w) { d = colMeans(X[w == 1, ]) - colMeans(X[w == 0, ]); drop(t(d) %*% solve(cov(X)) %*% d) }
  Wb = replicate(50000, { w = rep(0, n); w[sample(n, 20)] = 1; w }); q01 = quantile(apply(Wb, 2, M), 0.01)
  M_assigned = sapply(1:300, function(s) {
    d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.01, seed = s)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); M(d$get_w()) })
  d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.01, seed = 1)
  d$add_all_subjects_to_experiment(X)
  M_ref = apply(d$draw_ws_according_to_design(501), 2, M)
  c(q01 = unname(q01), assigned_outside = mean(M_assigned > q01), reference_outside = mean(M_ref > q01))
  # ~0.0018, ~0.32, 0
  # size of the randomization test under H0 (takes ~20 s)
  pv = sapply(1:800, function(s) {
    d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.01, seed = s)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
    set.seed(1000 + s); d$add_all_subject_responses(2 * scale(X$weight)[, 1] + 2 * scale(X$age)[, 1] + rnorm(n))
    inf = InferenceAllSimpleMeanDiffPooledVar$new(d); inf$set_seed(s)
    inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE) })
  mean(pv < 0.05)   # 0.0725
  ```
- Workaround used, if any: use `obj_val_cutoff` (a fixed acceptance region, so observed and reference draws share one law) in the main analysis.

### F3: `DesignFixedGreedy` and `DesignFixedGreedyDOptimal` with defaults and the same seed do not return the same allocations when covariates have ties
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedGreedy`, "Same draws as DesignFixedGreedyDOptimal at the defaults": "With objective = "mahal_dist" and n_iter = Inf (the defaults), this class returns exactly the same allocations as DesignFixedGreedyDOptimal with its defaults ... for the same seed." No condition on the covariates is stated.
- Observed: with realistic lab covariates (weight to 0.1 g, age in whole weeks, so many tied values), only 10 of 20 draws from `draw_ws_according_to_design(20)` are identical, none of the others are mirrors, and the single `assign_w_to_all_subjects()` allocation differs too. Their Mahalanobis imbalances differ by up to 3.9e-5, so the two searches end at different local optima, not just at equally good ones. With continuous covariates (no ties) all 20 draws are identical, as documented.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(20261118)
  X = data.frame(weight = round(rnorm(40, 25, 3), 1), age = sample(6:12, 40, replace = TRUE))
  g  = DesignFixedGreedy$new(response_type = "continuous", n = 40, seed = 7);         g$add_all_subjects_to_experiment(X)
  gd = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 40, seed = 7); gd$add_all_subjects_to_experiment(X)
  Wg = g$draw_ws_according_to_design(20); Wd = gd$draw_ws_according_to_design(20)
  sum(colSums(Wg != Wd) == 0)   # 10, docs imply 20
  ```
- Workaround used, if any: none needed for the analysis; treat the two classes as giving different draws.

### F4: `DesignFixedOptimal(objective = "abs_sum_diff")` with the default `solver = "auto"` does not finish for n = 40, with no message
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedOptimal`, "Solvers and certificates": `solver = "auto"` uses the exact MILP "wherever tractable - always for "abs_sum_diff" (pure linear MILP)". For the quadratic criteria, auto switches to annealing above `linearization_max_n = 20` and prints a message saying so. For n = 40 (a normal lab size) the default should either finish or say it may be slow.
- Observed: n = 16 solves in 0.35 s, n = 24 in 3.7 s, but n = 40, `prob_T = 0.3` had not returned after more than 400 s (stopped by hand), with no message, progress or time limit. `solver_args` documents no time limit for the MILP path. `solver = "annealing"` solves the same problem in 0.01 s.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(20261118)
  n = 40
  X = data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  o = DesignFixedOptimal$new(response_type = "continuous", n = n, objective = "abs_sum_diff", prob_T = 0.3, seed = 3)
  o$add_all_subjects_to_experiment(X)
  system.time(o$assign_w_to_all_subjects())   # did not finish in > 400 s; with solver = "annealing": 0.01 s
  ```
- Workaround used, if any: `solver = "annealing"`.

### F5: `get_optimization_diagnostics()$objective_value` is not the documented objective M(w): it is M/4 for "mahal_dist" and M/2 for "abs_sum_diff"
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedOptimal`, `get_optimization_diagnostics()`: "the achieved objective value". The class docs say the "mahal_dist"/"abs_sum_diff" criteria are "definitionally identical" to `DesignFixedGreedy`'s, and `?DesignFixedRerandomization` defines the user-facing M(w) (squared Mahalanobis distance of mean differences; sum of absolute standardized mean differences) and says the C++ rescaling (M/4, M/2) is internal. A user would compare the diagnostic with a rerandomization `obj_val_cutoff` on the M scale.
- Observed: for the optimal allocation, the Mahalanobis M(w) computed by hand is 0.0005879, but `objective_value` is 0.000147 (= M/4). For "abs_sum_diff", the hand-computed sum of |std. mean diffs| is 0.02651, but `objective_value` is 0.0133 (= M/2). The scale is not documented.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(20261118)
  n = 40
  X = data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  for (obj in c("mahal_dist", "abs_sum_diff")) {
    o = DesignFixedOptimal$new(response_type = "continuous", n = n, objective = obj, solver = "annealing", seed = 3)
    o$add_all_subjects_to_experiment(X); o$assign_w_to_all_subjects(); w = o$get_w()
    dm = colMeans(X[w == 1, ]) - colMeans(X[w == 0, ])
    M = if (obj == "mahal_dist") drop(t(dm) %*% solve(cov(X)) %*% dm) else sum(abs(dm) / apply(X, 2, sd))
    cat(obj, ": M(w) =", M, " objective_value =", o$get_optimization_diagnostics()$objective_value,
        " ratio =", M / o$get_optimization_diagnostics()$objective_value, "\n")
  }
  ```
- Workaround used, if any: compute M(w) by hand to compare designs.

### F6: Every fixed design's constructor takes the default `n = NULL`, then the first `add_all_subjects_to_experiment()` errors, although `X_all` supplies n
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixed`, `?DesignFixediBCRD`, `?DesignFixedRerandomization`, `?DesignFixedGreedy`, `?DesignFixedOptimal` etc. all list `n = NULL` as the default in Usage. The argument text is only "The sample size" (Optimal: "Sample size (if fixed)") and does not say it is required. `?Design`, `capabilities()`, even describes "DesignFixediBCRD constructed with an unknown n" as a supported state. `add_all_subjects_to_experiment(X_all)` gets the full covariate data, so n = nrow(X_all) is known. (Only `?DesignFixedMatchingGreedyPairSwitching` shows `n` with no default.)
- Observed: construction succeeds, and then for Bernoulli, iBCRD, Rerandomization, Greedy, GreedyDOptimal, BinaryMatch, Optimal and Blocking: `Error in self$assert_fixed_sample(): This type of design currently only works with fixed sample, i.e., you must specify n upon initialization`. The message is clear, but it contradicts the documented default and comes one step later than the constructor that should have rejected it.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressMessages(library(EDI))
  set.seed(1); X = data.frame(weight = rnorm(40, 25, 3), age = sample(6:12, 40, TRUE))
  d = DesignFixediBCRD$new(response_type = "continuous")      # n = NULL default: accepted
  d$add_all_subjects_to_experiment(X)                          # Error: ... you must specify n upon initialization
  ```
- Workaround used, if any: always pass `n = nrow(X)`.
