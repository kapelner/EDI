# Findings: clusters-blocking (EDI 1.0.4)

### F1: DesignFixedBlockedCluster with unequal block sizes errors with a message telling the user to set `equal_block_sizes = FALSE` or pass `B_target`, but the class accepts neither argument (not in the constructor, not in `assign_w_to_all_subjects()`)
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): the article "Cluster-Randomized and Factorial Experiments", section "Blocking the clusters", says "The design has no `equal_block_sizes` argument, so with blocks of different sizes it errors". `?DesignFixedBlockedCluster` `$new()` usage lists no `equal_block_sizes` or `B_target`. The error message should give a fix that works for this class (or say that unequal blocks are not supported yet), not point to arguments of `DesignFixedBlocking`.
- Observed: `assign_w_to_all_subjects()` errors with: `equal_block_sizes = TRUE but the strata produced unequal block sizes (106, 131, 184, 216) for n = 637 (4 blocks from strata_cols = district). Because strata_cols was named without B_target, all of it is used and the block sizes are determined by the data. Set equal_block_sizes = FALSE to allow unequal blocks, or adjust the strata_cols / covariate binning (or pass an explicit B_target) so that every block has the same size.` Doing what it says: `DesignFixedBlockedCluster$new(..., equal_block_sizes = FALSE)` -> `unused argument (equal_block_sizes = FALSE)`; `$new(..., B_target = 4)` -> `unused argument (B_target = 4)`; `assign_w_to_all_subjects(equal_block_sizes = FALSE)` -> `unused argument`. The public method `set_m(as.integer(district))` (listed by `names()`, not documented on this page) is accepted but the same error follows.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(2026)
  size = sample(12:40, 24, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:24), times = size))
  district = factor(rep(rep(c("North","South","East","West"), times = c(8,6,6,4)), times = size))
  n = length(school)
  X = data.frame(school = school, district = district, pretest = round(rnorm(n, 50, 10)))
  d = DesignFixedBlockedCluster$new(n = n, response_type = "continuous",
                                    strata_cols = "district", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  try(d$assign_w_to_all_subjects())        # message says: set equal_block_sizes = FALSE / pass B_target
  try(DesignFixedBlockedCluster$new(n = n, response_type = "continuous", strata_cols = "district",
                                    cluster_col = "school", equal_block_sizes = FALSE))  # unused argument
  try(DesignFixedBlockedCluster$new(n = n, response_type = "continuous", strata_cols = "district",
                                    cluster_col = "school", B_target = 4))               # unused argument
  ```
- Workaround used, if any: none inside the blocked-cluster class. Analysed the unequal-district trial with `DesignFixedCluster` (ignores the blocking in the re-randomization) and separately simulated a trial whose districts have equal pupil totals but unequal school sizes.

### F2: `approximate_bootstrap_distribution_beta_hat_T(bootstrap_type = ...)` returns the cached draws from an earlier call with a different `bootstrap_type` on the same inference object, so `"resample_blocks"` silently gives the `"within_blocks"` distribution (or vice versa)
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceNonParamBootstrap`, `approximate_bootstrap_distribution_beta_hat_T()`, argument `bootstrap_type`: `"within_blocks"` resamples clusters within strata, `"resample_blocks"` "Resamples entire observed blocks/strata with replacement rather than resampling units within each block". These are different resampling schemes and should give different draws whichever was called first.
- Observed: in the trial below, after one call with `"within_blocks"`, a call with `"resample_blocks"` (same seed) returns an object `identical()` to the first one (SD 0.531). A fresh inference object with `"resample_blocks"` and the same seed gives SD 0.430. In my main 24-school trial the same happened: NULL / `"within_blocks"` / `"resample_blocks"` on one object all gave SD 1.4726; a fresh object with `"resample_blocks"` gave SD 2.22, close to my hand-coded block bootstrap (SD 2.09; hand-coded within-district school bootstrap SD 1.44). No warning or message.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(1)
  school = factor(rep(sprintf("S%02d", 1:16), each = 10))
  district = factor(rep(c("A","B"), each = 80))
  n = length(school)
  X = data.frame(school = school, district = district, x = rnorm(n))
  d = DesignFixedBlockedCluster$new(n = n, response_type = "continuous",
                                    strata_cols = "district", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  d$assign_w_to_all_subjects()
  w = d$get_w()
  d$add_all_subject_responses(2 * w + X$x + rnorm(16)[school] + rnorm(n))
  inf = InferenceContinOLS$new(d)
  inf$set_seed(1); a = inf$approximate_bootstrap_distribution_beta_hat_T(B = 200, show_progress = FALSE, bootstrap_type = "within_blocks")
  inf$set_seed(1); b = inf$approximate_bootstrap_distribution_beta_hat_T(B = 200, show_progress = FALSE, bootstrap_type = "resample_blocks")
  fresh = InferenceContinOLS$new(d)
  fresh$set_seed(1); c = fresh$approximate_bootstrap_distribution_beta_hat_T(B = 200, show_progress = FALSE, bootstrap_type = "resample_blocks")
  identical(a, b)     # TRUE: the second call returned the within_blocks draws
  identical(b, c)     # FALSE
  c(sd(a), sd(b), sd(c))   # 0.531 0.531 0.430
  ```
- Also: the cached draws leak into `compute_bootstrap_confidence_interval()`, which has no `bootstrap_type` argument. In the 24-school trial, `compute_bootstrap_confidence_interval(B = 601, type = "percentile")` with seed 1 gave (-2.598, 3.575) on a fresh object, but (-2.252, 5.679) on an object where `approximate_bootstrap_distribution_beta_hat_T(B = 601, bootstrap_type = "resample_blocks")` had been called first. So the reported interval depends on an earlier diagnostic call, and nothing says so. Add to the repro above:
  ```r
  i1 = InferenceContinOLS$new(d); i1$set_seed(1)
  invisible(i1$approximate_bootstrap_distribution_beta_hat_T(B = 200, show_progress = FALSE, bootstrap_type = "resample_blocks"))
  i1$set_seed(1); i1$compute_bootstrap_confidence_interval(B = 200, type = "percentile", show_progress = FALSE)
  i2 = InferenceContinOLS$new(d)
  i2$set_seed(1); i2$compute_bootstrap_confidence_interval(B = 200, type = "percentile", show_progress = FALSE)  # differs
  ```
- Workaround used, if any: use a new inference object for each `bootstrap_type`, and a separate one for the reported bootstrap CI.

### F3: On `DesignFixedBlockedCluster`, the cluster warnings lead in a circle: `edi_cluster_independence_warning` recommends the jackknife with `unit = "cluster"`, which returns NA and says to use `unit = "block"`, which returns NA and says to use "the model-based standard error", the very SE the first warning said is too narrow
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): the article section "Blocking the clusters" says the cluster jackknife is not available on this design. The warning on this design should not recommend it, and the follow-up NA warning should not recommend the model-based SE on a class whose Wald SE treats pupils as independent. Separately, the reason "because its blocks hold more than one subject" does not explain why leave-one-*cluster*-out is refused (24 clusters here, 6 per block).
- Observed (in order):
  1. `compute_asymp_confidence_interval()` -> `InferenceAllSimpleAverageDiff on a cluster design: the Wald standard error, p-value and confidence interval treat subjects as independent ... Cluster-aware alternatives: ... or compute_jackknife_wald_two_sided_pval() / compute_jackknife_wald_confidence_interval() with unit = "cluster".`
  2. `compute_jackknife_wald_confidence_interval(unit = "cluster")` -> `c(NA, NA)` + `jackknife returned NA (reason: jackknife_block_size_gt_one_not_supported). Deletion unit "cluster" is not supported on this blocking design because its blocks hold more than one subject; use unit = "block" (leave-one-block-out).`
  3. `unit = "block"` -> `c(NA, NA)` + `The jackknife has only 4 deletion units (unit = "block"); at least 5 are needed. ... Use a randomization test (compute_rand_two_sided_pval()) or the model-based standard error.`
  The same `unit = "cluster"` advice appears in the `InferenceContinOLS` likelihood-family warning on this design.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(3)
  school = factor(rep(sprintf("S%02d", 1:24), each = 15))
  district = factor(rep(c("A","B","C","D"), each = 90))
  n = length(school)
  X = data.frame(school = school, district = district, x = rnorm(n))
  d = DesignFixedBlockedCluster$new(n = n, response_type = "continuous",
                                    strata_cols = "district", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  d$assign_w_to_all_subjects()
  w = d$get_w()
  d$add_all_subject_responses(2 * w + X$x + rnorm(24)[school] + rnorm(n))
  inf = InferenceAllSimpleAverageDiff$new(d)
  inf$compute_asymp_confidence_interval()                          # recommends jackknife unit = "cluster"
  inf$compute_jackknife_wald_confidence_interval(unit = "cluster") # NA, says use unit = "block"
  inf$compute_jackknife_wald_confidence_interval(unit = "block")   # NA, says use model-based SE
  ```
- Workaround used, if any: randomization test and within-block cluster bootstrap; CR2 Wald from `InferenceContinOLS`/`InferenceContinLin`.

### F4: `assign_w_to_all_subjects(w_precomputed = )` accepts a 1/2-coded treatment on `DesignFixedCluster`, keeps it as 1/2, and `InferenceAllSimpleAverageDiff` then returns `NA` estimate and `NA` randomization p-value with no warning
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixed`, `assign_w_to_all_subjects()`: "`w_precomputed` Optional {0,1} numeric vector of length n". A vector with values 1/2 should be rejected (or at least warned about).
- Observed: no error or warning; `table(d$get_w())` shows `1: 274, 2: 350`; `InferenceAllSimpleAverageDiff$compute_estimate()` -> `NA`; `compute_rand_two_sided_pval()` -> `NA`; nothing explains it. (`InferenceContinOLS` happens to give the right slope, 2.946, because the coding is linear, so the problem is easy to miss.)
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(11)
  size = sample(12:40, 24, TRUE)
  school = factor(rep(sprintf("S%02d", 1:24), times = size)); n = length(school)
  X = data.frame(school = school, pretest = round(rnorm(n, 50, 10)))
  wcl = rep(sample(rep(0:1, 12)), times = size)
  y = 50 + 3 * wcl + rnorm(24, sd = 3)[school] + rnorm(n, sd = 6)
  d = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  d$assign_w_to_all_subjects(w_precomputed = wcl + 1)   # accepted silently
  table(d$get_w())                                      # 1 / 2
  d$add_all_subject_responses(y)
  inf = InferenceAllSimpleAverageDiff$new(d)
  inf$compute_estimate()                                # NA, no warning (true diff = 2.92)
  inf$set_seed(1); inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE)   # NA
  ```
- Workaround used, if any: recode to 0/1 before passing.

### F5: `n = NULL`, the default shown in `?DesignFixedCluster` and `?DesignFixedBlockedCluster`, fails at the first step, and the follow-up error is unhelpful
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): both `$new()` usages show `n = NULL` as the default and describe `n` only as "The sample size", which suggests `n` can be left out and taken from the data, or else that it is required (in which case it should not have a default and the constructor should say so).
- Observed: the constructor succeeds silently; `add_all_subjects_to_experiment(X)` errors with `This type of design currently only works with fixed sample, i.e., you must specify n upon initialization`; calling `assign_w_to_all_subjects()` afterwards errors with `argument is of length zero`. The same first error occurs for `DesignFixedBlockedCluster`.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(11)
  school = factor(rep(sprintf("S%02d", 1:24), times = sample(12:40, 24, TRUE)))
  X = data.frame(school = school, pretest = round(rnorm(length(school), 50, 10)))
  d = DesignFixedCluster$new(response_type = "continuous", cluster_col = "school")   # n left at default NULL
  try(d$add_all_subjects_to_experiment(X))   # "you must specify n upon initialization"
  try(d$assign_w_to_all_subjects())          # "argument is of length zero"
  ```
- Workaround used, if any: pass `n = nrow(X)`.

### F6: `DesignFixedCluster$assign_w_to_all_subjects(w_precomputed = )` accepts a pupil-level assignment that varies within schools, with no warning, and cluster inference runs on it
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?DesignFixedCluster` Description: "every subject in a given cluster always receives the same treatment assignment". The design knows `cluster_col`, so a `w` that varies within a cluster contradicts the declared design and should at least warn. (The article checklist asks the analyst to check this by hand, so a design-level check would be cheap and match the docs.)
- Observed: `assign_w_to_all_subjects(w_precomputed = rbinom(n, 1, 0.5))` returns silently; `get_w()` differs within every school; `InferenceContinOLS` then reports a CR2 interval and a randomization p-value whose reference draws (whole schools) cannot produce the observed assignment.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(11)
  school = factor(rep(sprintf("S%02d", 1:24), times = sample(12:40, 24, TRUE))); n = length(school)
  X = data.frame(school = school, pretest = round(rnorm(n, 50, 10)))
  d = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  d$assign_w_to_all_subjects(w_precomputed = rbinom(n, 1, 0.5))   # no warning
  table(tapply(d$get_w(), school, function(s) length(unique(s))))  # 2 arms inside every school
  d$add_all_subject_responses(rnorm(n))
  inf = InferenceContinOLS$new(d)
  inf$compute_asymp_confidence_interval()
  inf$set_seed(1); inf$compute_rand_two_sided_pval(r = 200, show_progress = FALSE)
  ```
- Workaround used, if any: check `tapply(w, school, function(s) length(unique(s)))` by hand before assigning.

### F7: On a blocked-cluster trial, `compute_bootstrap_confidence_interval(type = "prepivoted" | "double-bootstrap" | "calibrated")` returns `c(NA, NA)` with only the reason "bootstrap_ci_unavailable", even though `get_supported_bootstrap_ci_types()` lists these types and the percentile interval on the same object is finite
- Kind: useless message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceNonParamBootstrap`, `compute_bootstrap_confidence_interval()`, `type`: these types are listed as "Supported values", and `get_supported_bootstrap_ci_types()` returns them for this object. If they cannot be computed here, the warning should say why (as the BCa warnings do) and what to do; the help page documents NA reasons for BCa but none for these three.
- Observed: `InferenceContinOLS: bootstrap confidence interval returned NA (reason: bootstrap_ci_unavailable). Suppress with suppressWarnings(expr, classes = "edi_procedure_na_warning").` for each of the three types; `type = "percentile"` gives (-0.712, 2.654). On another blocked-cluster data set (24 equal schools, 6 per district) the same three types are finite, so it depends on the data in a way the user cannot see. On `DesignFixedCluster` with the same 672 pupils, `prepivoted` and `double-bootstrap` were finite but took about 1.9 minutes each at B = 41 (with 2 cores), which the help page does not warn about.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  set.seed(424242)
  nsch = c(North = 8, South = 6, East = 6, West = 4)   # unequal schools per district
  sizes = unlist(lapply(nsch, function(k) { repeat { s = round(rmultinom(1, 168 - 10 * k, rep(1, k))[, 1]) + 10; if (all(s <= 60)) return(s) } }))
  G = sum(nsch)
  school = factor(rep(sprintf("S%02d", 1:G), times = sizes))
  district = factor(rep(rep(names(nsch), nsch), times = sizes))   # 168 pupils per district
  n = length(school)
  X = data.frame(school = school, district = district, pretest = round(rnorm(n, 50, 10)))
  d = DesignFixedBlockedCluster$new(n = n, response_type = "continuous",
                                    strata_cols = "district", cluster_col = "school", seed = 7)
  d$add_all_subjects_to_experiment(X)
  d$assign_w_to_all_subjects(); w = d$get_w()
  y = 60 + 4 * w + 0.5 * (X$pretest - 50) + rnorm(G, sd = 4)[as.integer(school)] + rnorm(n, sd = 8)
  d$add_all_subject_responses(y)
  for (ty in c("prepivoted", "double-bootstrap", "calibrated", "percentile")) {
    inf = InferenceContinOLS$new(d); inf$set_seed(1)
    print(c(type = ty, inf$compute_bootstrap_confidence_interval(B = 21, type = ty, show_progress = FALSE)))
  }
  ```
- Workaround used, if any: reported the percentile interval (and the CR2 Wald and randomization intervals).

### F8: `?DesignFixedBlockedCluster` does not say that every block must hold the same number of subjects, or that the jackknife (every `unit`) returns NA on this design; both are stated only in the web article
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): the article "Cluster-Randomized and Factorial Experiments", section "Blocking the clusters", states: "every block must have the same number of subjects ... with blocks of different sizes it errors" and "The cluster jackknife is not available on this design". The reference page should carry these restrictions. Instead it describes per-block randomization of clusters with `prob_T` and documents `prob_T` as varying "with unequal cluster sizes", which reads as if unequal blocks were fine. Unequal pupils per district is the normal case for a district-blocked school trial.
- Observed: `?DesignFixedBlockedCluster` (Description, `$new()` arguments) contains no mention of equal block sizes or of the jackknife. A user following it hits the F1 error with a 24-school, 4-district trial whose districts hold 106/131/184/216 pupils.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  library(EDI)
  help("DesignFixedBlockedCluster")   # no equal-block-size or jackknife restriction mentioned
  set.seed(2026)
  size = sample(12:40, 24, replace = TRUE)
  school = factor(rep(sprintf("S%02d", 1:24), times = size))
  district = factor(rep(rep(c("North","South","East","West"), times = c(8,6,6,4)), times = size))
  X = data.frame(school = school, district = district, pretest = round(rnorm(length(school), 50, 10)))
  d = DesignFixedBlockedCluster$new(n = nrow(X), response_type = "continuous",
                                    strata_cols = "district", cluster_col = "school")
  d$add_all_subjects_to_experiment(X)
  try(d$assign_w_to_all_subjects())   # errors: unequal block sizes
  ```
- Workaround used, if any: see F1.
