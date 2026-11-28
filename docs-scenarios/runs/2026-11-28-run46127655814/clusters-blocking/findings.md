# Findings: clusters-blocking (run 2026-11-28, EDI 1.0.5)

### F1: On `DesignFixedCluster` the Bayesian bootstrap (default `weighting_unit_type = NULL`) puts Dirichlet weights on pupils, not on clusters, so its SD, CI and p-value ignore the clustering, and it raises no warning
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceBayesianBootstrap`, `compute_estimate_with_bootstrap_weights()`: "For blocking, clustering, or matching designs these may instead be block-, cluster-, pair-, or matched-set-level weights". `?DesignFixedCluster` (Interim warning): only Wald and likelihood-based procedures treat subjects as independent and warn; "Randomization, bootstrap and jackknife routes do not warn", implying they respect the clusters. The article (cluster-and-factorial-experiments, "Which inference respects the clustering") lists bootstrap routes as cluster-aware. On `DesignFixedBlockedCluster` the same method does use cluster-within-stratum weights (SD 1.23 here vs hand cluster-weighted 1.20). On the unblocked cluster design `weighting_unit_type` cannot be set to anything else ("bootstrap_type can only be set for blocking designs: ..."), so the user cannot ask for cluster weights.
- Observed (exact output, including the exact message text): 24 schools (12-60 pupils), ICC about 0.2, true effect 0. EDI Bayesian-bootstrap SD 0.643 equals hand pupil-weight Bayesian bootstrap 0.626; the cluster nonparametric bootstrap gives 1.780, hand school-weight Bayesian bootstrap 1.597, leave-one-school-out jackknife 1.955. Bayesian-bootstrap 95% CI (-1.36, 1.10) is about 3 times narrower than the CR2 CI (-4.15, 3.77). No warning of any class. In the main analysis (true effect 3, same assignment declared as DesignFixedCluster) the Bayesian-bootstrap CI was (1.21, 3.75) against the CR2 CI (-2.10, 7.16), so it "finds" an effect the cluster-aware procedures do not.
  ```
      EDI_bayes_boot_sd   EDI_cluster_boot_sd  hand_pupil_weight_sd 
                  0.643                 1.780                 0.626 
  hand_school_weight_sd  jackknife_cluster_se 
                  1.597                 1.955 
       2.5%     97.5%      (CR2 Wald)
  -4.151168  3.774208 
       2.5%     97.5%      (Bayesian bootstrap)
  -1.362354  1.104077 
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1)
  G = 24; size = sample(12:60, G, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:G), times = size)); n = length(school)
  X = data.frame(school = school, pretest = rnorm(n, 50, 10))
  des = DesignFixedCluster$new(response_type = "continuous", cluster_col = "school")
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()
  w = des$get_w()
  y = 60 + 0.5 * (X$pretest - 50) + rnorm(G, sd = 4)[as.integer(school)] + rnorm(n, sd = 8)  # true effect 0
  des$add_all_subject_responses(y)
  inf = InferenceContinOLS$new(des)
  inf$set_seed(1); bb = inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 400, show_progress = FALSE)
  inf2 = InferenceContinOLS$new(des); inf2$set_seed(1); nb = inf2$approximate_bootstrap_distribution_beta_hat_T(B = 400, show_progress = FALSE)
  df = data.frame(X, y, w)
  set.seed(2); pupil_bb = replicate(400, coef(lm(y ~ w + pretest, df, weights = rexp(n)))["w"])
  set.seed(2); school_bb = replicate(400, coef(lm(y ~ w + pretest, df, weights = rexp(G)[as.integer(school)]))["w"])
  round(c(EDI_bayes_boot_sd = sd(bb), EDI_cluster_boot_sd = sd(nb), hand_pupil_weight_sd = sd(pupil_bb),
          hand_school_weight_sd = sd(school_bb), jackknife_cluster_se = inf$compute_jackknife_std_error(unit = "cluster")), 3)
  inf3 = InferenceContinOLS$new(des)
  print(inf3$compute_asymp_confidence_interval())          # CR2
  inf3$set_seed(1); print(inf3$compute_bayesian_bootstrap_confidence_interval(B = 400, show_progress = FALSE))  # no warning
  inf3$set_seed(1); print(inf3$compute_bayesian_bootstrap_two_sided_pval(B = 400, show_progress = FALSE))
  ```
- Workaround used, if any: use the cluster nonparametric bootstrap, the cluster jackknife or the randomization test; on DesignFixedCluster do not report the Bayesian bootstrap.

### F2: `DesignFixedBlockedCluster$assign_w_to_all_subjects(w_precomputed = )` accepts an assignment that the declared blocked design can never produce (all treated schools in one district), and inference then runs on it without a word: the treatment is collinear with a block dummy, and the randomization p-value is 0.008 with no treatment effect
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedBlockedCluster` Description: "Within each resulting block, whole clusters ... are randomized to treatment with probability prob_T ... so that, subject to rounding, the target proportion prob_T of clusters in that block is treated". The article (cluster-and-factorial-experiments, checklist) tells users to declare `DesignFixedBlockedCluster` for an existing trial and pass the recorded `w` as `w_precomputed`. Since 1.0.5 `w_precomputed` is already checked to be 0/1 and constant within clusters, so I expected a check (an error, or at least a warning) when the per-block number of treated clusters cannot come from the design, as here: block North 7/7 treated, all other blocks 0. The randomization test's reference distribution comes from `draw_ws_according_to_design()`, which always treats about half the clusters in every block. The observed allocation has probability 0 under that distribution, so the p-value is not valid.
- Observed (exact output, including the exact message text): no error and no warning anywhere. The treatment equals the `districtNorth` dummy. EDI's estimate (3.007) equals `lm()`'s, which drops `districtNorth` as aliased (estimatr says "districtNorth is identical to w"). EDI drops it silently, and `get_covariates()` still lists `districtNorth`. The estimate is the North district effect (4 in the simulation), not a treatment effect (true effect 0). The randomization p-value is 0.008 because the redraws spread treatment over every district.
  ```
          treated
  district 0 1
     East  6 0
     North 0 7
     South 6 0
     West  5 0
  [1] 12 12 12 12 12          # treated schools in 5 design redraws
  [1] 3.007462                # estimate
  [1] "districtNorth" "districtSouth" "districtWest"  "pretest"
       2.5%     97.5% 
  -1.730187  7.745111 
  [1] 0.007984032             # randomization p, true effect 0
  ```
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1)
  G = 24; dist_of_school = rep(c("North", "South", "East", "West"), times = c(7, 6, 6, 5))
  size = sample(12:60, G, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:G), times = size)); n = length(school)
  district = factor(rep(dist_of_school, times = size))
  X = data.frame(school = school, district = district, pretest = rnorm(n, 50, 10))
  w_recorded = as.integer(district == "North")   # every North school treated, no other school treated
  des = DesignFixedBlockedCluster$new(response_type = "continuous", strata_cols = "district", cluster_col = "school")
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects(w_precomputed = w_recorded)      # accepted, no warning
  y = 60 + c(North = 4, South = -1, East = 0, West = -2)[as.character(district)] +
      rnorm(G, sd = 2)[as.integer(school)] + rnorm(n, sd = 8)   # no treatment effect at all
  des$add_all_subject_responses(y)
  table(district = dist_of_school, treated = tapply(w_recorded, school, max))
  colSums(des$draw_ws_according_to_design(5)[!duplicated(school), ])   # design never treats only 7 schools
  inf = InferenceContinOLS$new(des)
  inf$compute_estimate()              # = North district effect; no warning
  colnames(inf$get_covariates())      # districtNorth is still listed, but must have been dropped
  inf$compute_asymp_confidence_interval()
  inf$set_seed(1); inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
  ```
- Workaround used, if any: check by hand that the treated-cluster count per block is what the design would give (`table(block, tapply(w, cluster, max))`) before analyzing a recorded assignment.

### F3: On a cluster design, `InferenceSuite`'s procedure-validity columns describe the subject-level Wald test and the subject-weighted Bayesian bootstrap as cluster-asymptotic (`n_eff = "n_clusters = 24"`, `size_order = "O(n_eff^-1)"`), although EDI itself warns that the Wald test treats subjects as independent; their size error does not vanish as clusters grow
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceSuite`, `run_all_inference()` Value: `size_order` is "the expected order of the size / coverage error in n_eff ... "O(1)" when the error does not vanish". `?DesignFixedCluster` (Interim warning) and the `edi_cluster_independence_warning` raised in this same run say that `InferenceAllSimpleAverageDiff`'s Wald SE treats subjects as independent and may be too narrow. With a positive ICC that error does not shrink as clusters are added, so the row should read `O(1)` (or at least not claim cluster-level asymptotics). The same holds for the Bayesian bootstrap, which weights subjects on this design (F1). The rows also disagree among themselves: the randomization test, which re-randomizes whole clusters, is the one row labelled `n = 888` (subjects).
- Observed (exact output, including the exact message text): the Wald row is the subject-level interval (-1.75, 0.94), the cluster bootstrap gives (-4.72, 3.96)
  ```
         wald       <NA> -1.746681 0.944708 0.5588148    asymptotic
         rand       <NA> -5.093309 3.422551 0.7800000 finite_sample
    bootstrap percentile -4.724758 3.957744 0.7939698    asymptotic
   bayes_boot percentile -1.599610 1.211410 0.6030151    asymptotic
             n_eff  size_order
   n_clusters = 24 O(n_eff^-1)
           n = 888       exact
   n_clusters = 24 O(n_eff^-1)
   n_clusters = 24 O(n_eff^-1)
  ```
  The Bayesian-bootstrap CI (-1.60, 1.21) is about a third as wide as the cluster bootstrap's (-4.72, 3.96), yet both rows carry the same validity label.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1)
  G = 24; size = sample(12:60, G, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:G), times = size)); n = length(school)
  X = data.frame(school = school, pretest = rnorm(n, 50, 10))
  des = DesignFixedCluster$new(response_type = "continuous", cluster_col = "school")
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()
  y = 60 + 0.5 * (X$pretest - 50) + rnorm(G, sd = 4)[as.integer(school)] + rnorm(n, sd = 8)
  des$add_all_subject_responses(y)
  suite = InferenceSuite$new(des)
  set.seed(1)
  res = suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceAllSimpleAverageDiff",
          methods = list(wald = NULL, rand = NULL, bootstrap = "percentile", bayes_boot = "percentile"),
          compute_conf_intervals = TRUE, r = 199, B = 199)
  print(res$results_table[, c("method", "type", "ci_a", "ci_b", "pval", "regime", "n_eff", "size_order")], row.names = FALSE)
  ```
- Workaround used, if any: ignore `n_eff`/`size_order` for cluster designs; rely on the `warnings` column and on which procedures the design docs call cluster-aware.

### F4: On `DesignFixedCluster` and `DesignFixedBlockedCluster` with an incidence outcome, `compute_rand_two_sided_pval()` errors ("Randomization tests are not supported for incidence"), although `supports("randomization_test")` is `TRUE`, `?InferenceRand` says it works for every response type, and the cluster-independence warning names it as the cluster-aware alternative
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRand` Description: "The p-value always comes from randomization draws of the assignment vector w from the design, for every response type including incidence". Article cluster-and-factorial-experiments, "Which inference respects the clustering": the randomization test is "Cluster-aware on every inference class that offers them". `inf$supports("randomization_test")` and `capabilities()` both report it as offered. The `edi_cluster_independence_warning` raised by the same object says "Cluster-aware alternatives: compute_rand_two_sided_pval(), ...".
- Observed (exact output, including the exact message text):
  ```
  DesignFixedCluster 
   supports randomization_test: TRUE  in capabilities(): TRUE 
   Wald warning: InferenceIncidRiskDiff on a cluster design: the Wald standard error, p-value and confidence interval treat subjects as independent, ... Cluster-aware alternatives: compute_rand_two_sided_pval(), compute_bootstrap_two_sided_pval() / ...
   rand p: ERROR: Randomization tests are not supported for incidence. Use Zhang method. 
  DesignFixedBlockedCluster 
   supports randomization_test: TRUE  in capabilities(): TRUE 
   rand p: ERROR: Randomization tests are not supported for incidence. Use Zhang method. 
  ```
  The same error came from `InferenceIncidLogRegr` in the main analysis, and from `InferenceIncidRiskDiff` on a plain `DesignFixedBlocking` (it works on `DesignFixedBernoulli`), so the cause seems to be blocking or clustering in general, not only clusters. For a cluster trial with a binary outcome this removes the only exact cluster-aware test. On the blocked design the other route the warning offers, the cluster jackknife, is NA (known finding f3), which leaves only the cluster bootstrap. The docs call that bootstrap anti-conservative below about 30 clusters, and this trial has 24.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1)
  G = 24; size = sample(12:60, G, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:G), times = size)); n = length(school)
  district = factor(rep(rep(c("North", "South", "East", "West"), times = c(7, 6, 6, 5)), times = size))
  X = data.frame(school = school, district = district, pretest = rnorm(n, 50, 10))
  p = plogis(-0.3 + rnorm(G, sd = 0.7)[as.integer(school)])
  for (des_name in c("DesignFixedCluster", "DesignFixedBlockedCluster")) {
    des = if (des_name == "DesignFixedCluster") DesignFixedCluster$new(response_type = "incidence", cluster_col = "school") else
      DesignFixedBlockedCluster$new(response_type = "incidence", strata_cols = "district", cluster_col = "school")
    des$add_all_subjects_to_experiment(X)
    des$assign_w_to_all_subjects()
    des$add_all_subject_responses(rbinom(n, 1, p))
    inf = InferenceIncidRiskDiff$new(des)
    cat(des_name, "\n supports randomization_test:", inf$supports("randomization_test"),
        " in capabilities():", "randomization_test" %in% inf$capabilities(), "\n")
    w = tryCatch(inf$compute_asymp_confidence_interval(), warning = function(w) conditionMessage(w))
    cat(" Wald warning:", w, "\n")
    inf$set_seed(1)
    cat(" rand p:", tryCatch(inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE), error = function(e) paste("ERROR:", conditionMessage(e))), "\n")
    cat(" rand p type='Zhang':", tryCatch(inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE, type = "Zhang"), error = function(e) paste("ERROR:", conditionMessage(e))), "\n")
    cat(" formals of compute_rand_two_sided_pval:", names(formals(inf$compute_rand_two_sided_pval)), "\n")
  }
  ```
- Workaround used, if any: none inside EDI. A hand-coded randomization test (redraws from `des$draw_ws_according_to_design()`, statistic = risk difference) is possible.

### F5: Following the error "Use Zhang method" with `compute_rand_two_sided_pval(type = "Zhang")` on an incidence outcome errors with "Randomization type dispatch is only supported for incidence outcomes", which is false: the outcome is incidence
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRand` Description: the Zhang exact combined test "is still available explicitly through the `type = "Zhang"` argument of classes that offer it". `compute_rand_two_sided_pval()` on `InferenceIncidRiskDiff` has a `type` argument. Either the Zhang test runs, or the message says that the class or the cluster design does not offer it and what to use instead.
- Observed (exact output, including the exact message text):
  ```
   rand p: ERROR: Randomization tests are not supported for incidence. Use Zhang method. 
   rand p type='Zhang': ERROR: Randomization type dispatch is only supported for incidence outcomes. 
   formals of compute_rand_two_sided_pval: r delta transform_responses na.rm show_progress permutations type args_for_type zero_one_logit_clamp alternative 
  ```
  (identical on DesignFixedCluster and DesignFixedBlockedCluster, response_type = "incidence")
- Repro: same script as F4 (the `type = "Zhang"` line).
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI); set_num_cores(2)
  set.seed(1)
  G = 24; size = sample(12:60, G, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:G), times = size)); n = length(school)
  district = factor(rep(rep(c("North", "South", "East", "West"), times = c(7, 6, 6, 5)), times = size))
  X = data.frame(school = school, district = district, pretest = rnorm(n, 50, 10))
  p = plogis(-0.3 + rnorm(G, sd = 0.7)[as.integer(school)])
  for (des_name in c("DesignFixedCluster", "DesignFixedBlockedCluster")) {
    des = if (des_name == "DesignFixedCluster") DesignFixedCluster$new(response_type = "incidence", cluster_col = "school") else
      DesignFixedBlockedCluster$new(response_type = "incidence", strata_cols = "district", cluster_col = "school")
    des$add_all_subjects_to_experiment(X)
    des$assign_w_to_all_subjects()
    des$add_all_subject_responses(rbinom(n, 1, p))
    inf = InferenceIncidRiskDiff$new(des)
    cat(des_name, "\n supports randomization_test:", inf$supports("randomization_test"),
        " in capabilities():", "randomization_test" %in% inf$capabilities(), "\n")
    w = tryCatch(inf$compute_asymp_confidence_interval(), warning = function(w) conditionMessage(w))
    cat(" Wald warning:", w, "\n")
    inf$set_seed(1)
    cat(" rand p:", tryCatch(inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE), error = function(e) paste("ERROR:", conditionMessage(e))), "\n")
    cat(" rand p type='Zhang':", tryCatch(inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE, type = "Zhang"), error = function(e) paste("ERROR:", conditionMessage(e))), "\n")
    cat(" formals of compute_rand_two_sided_pval:", names(formals(inf$compute_rand_two_sided_pval)), "\n")
  }
  ```
- Workaround used, if any: none; used the cluster bootstrap for the binary outcome and noted its small-G caveat.

