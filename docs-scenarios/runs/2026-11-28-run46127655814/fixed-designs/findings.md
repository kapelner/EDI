# Findings: fixed-designs (run 2026-11-28)

### F1: With `equal_block_sizes = TRUE`, `DesignFixedBlocking(exact_num_blocks = TRUE)` errors with a false block count ("produced 2 blocks instead of the requested 4"), although the same strata produce exactly 4 blocks; the real problem is unequal block sizes
- Kind: false message
- Expected (?DesignFixedBlocking, Description "Block construction" and argument `exact_num_blocks`): `exact_num_blocks = TRUE` "hard-fails if the greedy construction does not land on exactly `B_target` blocks". So the error should appear only when the construction lands on a different count. When the 4 blocks are unequal in size, the error should be the unequal-size message, which the same call without `exact_num_blocks` gives.
- Observed: `strata_cols = c("weight","age"), B_target = 4` gives `This design requires equal block sizes but the strata produced unequal block sizes (4, 10, 16) for n = 40 (4 blocks from strata_cols = weight, age). With B_target = 4 ...`. Adding `exact_num_blocks = TRUE` gives instead `exact_num_blocks = TRUE but the greedy blocking key construction produced 2 blocks instead of the requested 4.` With `exact_num_blocks = TRUE, equal_block_sizes = FALSE`, the construction yields 4 blocks. With another data seed the message says "produced 1 blocks". `exact_num_blocks = TRUE` also changes the blocking it builds, not just the check: with `B_target = 8, equal_block_sizes = FALSE` it gives 4 blocks without `exact_num_blocks` and 8 blocks with it.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1)
  n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  blk <- function(...) { d <- DesignFixedBlocking$new(response_type = "continuous", seed = 5, ...)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d }
  nb <- function(d) length(d$summarize_blocks())
  tryCatch(blk(strata_cols = c("weight","age"), B_target = 4), error = function(e) conditionMessage(e))
  tryCatch(blk(strata_cols = c("weight","age"), B_target = 4, exact_num_blocks = TRUE), error = function(e) conditionMessage(e))
  nb(blk(strata_cols = c("weight","age"), B_target = 4, exact_num_blocks = TRUE, equal_block_sizes = FALSE))  # 4
  nb(blk(strata_cols = c("weight","age"), B_target = 8, equal_block_sizes = FALSE))                           # 4
  nb(blk(strata_cols = c("weight","age"), B_target = 8, exact_num_blocks = TRUE, equal_block_sizes = FALSE))  # 8
  ```
- Workaround used, if any: drop `exact_num_blocks`, and use `equal_block_sizes = FALSE` or a user `m`.

### F2: In `DesignFixedBlocking`, a numeric column that is categorical on its own ("integer-valued with at most 10 distinct values") is silently quantile-binned when combined with another stratum under `B_target`, instead of being kept at its levels or skipped
- Kind: false docs
- Expected (?DesignFixedBlocking, arguments `strata_cols` and `B_target`): an integer column with at most 10 distinct values "is also treated as categorical, one stratum per value". Under `B_target`, "each column being included only if it does not push the total number of unique blocks beyond this target. For categorical covariates their natural levels are used". With `strata_cols = c("weight","age")`, where age has 7 whole-week values, and `B_target = 4`, weight gives 2 bins and age (7 levels → 14 cells) should be skipped, leaving 2 blocks.
- Observed: 4 blocks. Age is split into two halves (block mean ages 11.5, 11.75, 8.5, 8.0), so age enters as a 2-bin binned covariate. The same happens at `B_target = 7`. With `strata_cols = "age"` alone, age gives 7 blocks (categorical). With `c("age","weight"), B_target = 7`, it gives 7 blocks, one per age.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1)
  n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  blk <- function(...) { d <- DesignFixedBlocking$new(response_type = "continuous", seed = 5, equal_block_sizes = FALSE, ...)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d }
  length(blk(strata_cols = "age")$summarize_blocks())                       # 7: age is categorical
  s <- blk(strata_cols = c("weight","age"), B_target = 4)$summarize_blocks()
  length(s)                                                                  # 4, expected 2
  sapply(s, function(z) z$mean_or_pct[z$variable == "age"])                  # 11.5 11.75 8.5 8.0: age was binned
  ```
- Workaround used, if any: pass explicit block ids with `m`.

### F3: The default `DesignFixedBlocking` (no `strata_cols`, no `B_target`) errors at the first assignment on ordinary data, and the error reports `B_target = NA`, although the docs say the default B_target is resolved when the subjects are added and "always satisfies equal_block_sizes = TRUE"
- Kind: false message
- Expected (?DesignFixedBlocking, argument `B_target`): "If `strata_cols = NULL` ... the default is the largest divisor of `n` that is at most `floor(sqrt(n))` (so it always satisfies `equal_block_sizes = TRUE`); if `n` is not yet known it is resolved to `floor(sqrt(n))` when subjects are added." For n = 40 the error should therefore name B_target 5 or 6, not NA.
- Observed: `DesignFixedBlocking$new(response_type = "continuous")` with the documented default `n = NULL` errors at `assign_w_to_all_subjects()` with `This design requires equal block sizes but the strata produced unequal block sizes (4, 10, 16) for n = 40 (4 blocks from strata_cols = weight, age). With B_target = NA the chosen blocks still have unequal sizes. ...`. With `n = 40` supplied, the same message says `B_target = 5`, and the design still lands on 4 blocks. So the default blocking design cannot be used with equal-size blocks on two continuous covariates. The docs also give two different defaults (5 with `n` known, `floor(sqrt(40)) = 6` with `n = NULL`) for the same data.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1)
  n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  for (nn in list(NULL, 40)) {
    d <- DesignFixedBlocking$new(response_type = "continuous", n = nn, seed = 5)
    d$add_all_subjects_to_experiment(X)
    print(tryCatch({d$assign_w_to_all_subjects(); "ok"}, error = function(e) conditionMessage(e)))
  }
  ```
- Workaround used, if any: name `strata_cols = "weight"` with `B_target = 2` (equal halves), or pass `m`.

### F4: `DesignFixediBCRD` built with the documented default `n = NULL` cannot run any bootstrap: `compute_bootstrap_confidence_interval()`, `compute_bootstrap_two_sided_pval()` and `compute_rand_bootstrap_confidence_interval()` all fail with "Block identifiers are undefined for this design."; with `n = 40` passed, they work
- Kind: documented option fails
- Expected (?DesignFixed / ?DesignFixediBCRD, argument `n`): "If `NULL` (default), `n` is set to `nrow(X_all)` when the subjects are added with `add_all_subjects_to_experiment()`". So a design built with `n = NULL` should behave like one built with `n = nrow(X_all)`. `d$capabilities()` lists `"resampling"` and `d$supports_resampling()` is `TRUE` in both cases.
- Observed: with `n = NULL`, `Error: Block identifiers are undefined for this design.` from every bootstrap entry point, both for `InferenceAllSimpleMeanDiffPooledVar` and for `InferenceContinOLS`, at `prob_T = 0.5` and `0.4`. The message names an internal concept (block ids) that an unblocked iBCRD design does not have, and does not mention `n`. With `n = 40`, the same calls return finite intervals (e.g. `-0.505 0.515`). `capabilities()` also differs: `resampling,randomization_draw,resampling_replay` with `n = NULL`, versus `blocking,resampling,randomization_draw,resampling_replay` with `n = 40`. The other fixed designs tested (Bernoulli, Rerandomization, Greedy, GreedyDOptimal, Optimal, BinaryMatch, Blocking) give identical results at `n = NULL` and `n = 40`. This is a remaining case of the closed `ds-fixed-designs-44358267779-f6` (n = NULL); the symptom has moved from the assignment to the bootstrap.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  y <- rnorm(n)
  for (nn in list(NULL, 40)) {
    d <- DesignFixediBCRD$new(response_type = "continuous", seed = 1, n = nn)
    d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d$add_all_subject_responses(y)
    print(d$capabilities())
    inf <- InferenceAllSimpleMeanDiffPooledVar$new(d)
    print(tryCatch(inf$compute_bootstrap_confidence_interval(B = 101, type = "percentile", show_progress = FALSE), error = function(e) conditionMessage(e)))
    print(tryCatch(inf$compute_rand_bootstrap_confidence_interval(B = 101, show_progress = FALSE), error = function(e) conditionMessage(e)))
  }
  ```
- Workaround used, if any: pass `n = nrow(X)` to `DesignFixediBCRD$new()`.

### F5: `DesignFixedMatchingGreedyPairSwitching$new()` has no default for `n`, unlike every other fixed design, and omitting it gives only R's generic `argument "n" is missing, with no default`
- Kind: inconsistency
- Expected (?DesignFixed, `DesignFixed$new()` usage): fixed designs take `n = NULL`, "set to `nrow(X_all)` when the subjects are added". Every other fixed-design constructor follows this (Bernoulli, iBCRD, Blocking, Rerandomization, Greedy, GreedyDOptimal, Optimal, BinaryMatch). ?DesignFixedMatchingGreedyPairSwitching lists `n` without a default ("The sample size; must be divisible by 4"), so the code matches its own page but not the class family.
- Observed: `DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", seed = 7)`, followed by `add_all_subjects_to_experiment(X)` with 40 rows, errors in the constructor with `Error in assertCount(n, positive = TRUE, null.ok = TRUE) : argument "n" is missing, with no default`. The internal assertion says `null.ok = TRUE`, so `NULL` is meant to be accepted, but the argument has no `NULL` default. Passing `n = NULL` explicitly works: n is then taken from `X_all`, and the assignment has 20 treated.
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  tryCatch(DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", seed = 7), error = function(e) conditionMessage(e))
  d1 <- DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = NULL, seed = 7)  # explicit NULL is accepted
  d1$add_all_subjects_to_experiment(X); d1$assign_w_to_all_subjects(); sum(d1$get_w())
  d2 <- DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 40, seed = 7)
  d2$add_all_subjects_to_experiment(X); d2$assign_w_to_all_subjects(); sum(d2$get_w())   # 20
  ```
- Workaround used, if any: pass `n = nrow(X)`.

### F6: The error for a randomization test on `DesignFixedOptimal` lists asymptotic and plain bootstrap inference as alternatives, but not the bootstrap randomization test, which ?DesignFixedOptimal names as the available design-based method
- Kind: useless message
- Expected (?DesignFixedOptimal, Description "Inference"): "permutation-style randomization tests/CIs are unavailable ...; the bootstrap randomization test IS available (the mechanism - 'optimize this dataset' - is replayed on each resampled covariate matrix), as is all model-based and plain-resampling inference." An error that redirects the user should name `compute_rand_bootstrap_two_sided_pval()` / `compute_rand_bootstrap_confidence_interval()`, which work on this design.
- Observed: `compute_rand_two_sided_pval()` gives `Randomization inference is not available for this design (no randomization mechanism to draw a fresh assignment from). Use asymptotic inference, plain nonparametric/Bayesian bootstrap, or a concrete design subclass with a randomization mechanism.` On the same object, `compute_rand_bootstrap_two_sided_pval(B = 101)` returns 0.0196 and `compute_rand_bootstrap_confidence_interval(B = 101)` returns a finite interval. The message's "a concrete design subclass" also reads as if `DesignFixedOptimal` were abstract. (The 2026-11-18 run noted this message under "Confusing docs" in learnings.md but did not file it as a finding.)
- Repro:
  ```r
  .libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
  suppressPackageStartupMessages(library(EDI))
  set.seed(1); n <- 40
  X <- data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
  y0 <- 2 + 0.6 * X$weight + 0.4 * X$age + rnorm(n)
  o <- DesignFixedOptimal$new(response_type = "continuous", objective = "mahal_dist", seed = 11)
  o$add_all_subjects_to_experiment(X); o$assign_w_to_all_subjects(); o$add_all_subject_responses(y0)
  inf <- InferenceAllSimpleMeanDiffPooledVar$new(o)
  tryCatch(inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE), error = function(e) conditionMessage(e))
  inf$compute_rand_bootstrap_two_sided_pval(B = 101, show_progress = FALSE)        # works
  inf$compute_rand_bootstrap_confidence_interval(B = 101, show_progress = FALSE)   # works
  ```
- Workaround used, if any: call `compute_rand_bootstrap_confidence_interval()` directly.
