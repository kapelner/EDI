library(testthat)
library(EDI)

test_that("fixed design constructors enforce structural allocation constraints", {
  expect_error(DesignFixedGreedy$new("continuous", prob_T = 0.4, n = 8), "prob_T = 0.5")
  expect_error(DesignFixedGreedy$new("continuous", n_iter = 1.5, n = 8), "positive integer")
  expect_error(DesignFixedMatchingGreedyPairSwitching$new("continuous", prob_T = 0.4, n = 8), "balanced")
  expect_error(DesignFixedMatchingGreedyPairSwitching$new("continuous", n_iter = 0, n = 8), "positive integer")
  expect_error(DesignFixedGreedyDOptimal$new("continuous", prob_T = 0, n = 8), "strictly between")
  expect_error(DesignFixedGreedyDOptimal$new("continuous", n_iter = 10, n = 8), "Finite n_iter")
  expect_error(DesignFixedFactorial$new(list(A = 2, B = 2), "continuous", n = 8), "two total")
  expect_error(ObservationalDesignMatching$new("continuous", n = 7), "even n")
})

test_that("factorial assignment decodes to its documented factor levels", {
  des <- DesignFixedFactorial$new(list(treatment = 2), "continuous", n = 10, seed = 91)
  expect_null(des$get_w_factorial())
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(10)))
  des$assign_w_to_all_subjects()
  decoded <- des$get_w_factorial()
  expect_s3_class(decoded, "data.frame")
  expect_equal(decoded$treatment, des$get_w() + 1L)
  expect_equal(tabulate(des$get_w() + 1L), c(5L, 5L))
})

test_that("cluster randomization is constant within each cluster", {
  skip_if_not_installed("randomizr")
  X <- data.frame(cluster = rep(letters[1:4], each = 3), x = seq_len(12))
  des <- DesignFixedCluster$new("cluster", "continuous", n = 12, seed = 92)
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()
  expect_true(all(vapply(split(des$get_w(), X$cluster), function(z) length(unique(z)) == 1L, logical(1))))

  bad <- DesignFixedCluster$new("cluster", "continuous", n = 4)
  bad$add_all_subjects_to_experiment(data.frame(cluster = c("a", NA, "b", "b")))
  expect_error(bad$assign_w_to_all_subjects(), "missing")
})

test_that("blocked-cluster randomization preserves cluster assignments", {
  skip_if_not_installed("randomizr")
  X <- data.frame(stratum = rep(c("north", "south"), each = 8),
                  cluster = rep(letters[1:8], each = 2), x = rnorm(16))
  des <- DesignFixedBlockedCluster$new("stratum", "cluster", "continuous", n = 16,
                                        num_bins_for_continuous_covariate = 3, seed = 93)
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()
  expect_true(all(vapply(split(des$get_w(), X$cluster), function(z) length(unique(z)) == 1L, logical(1))))
  expect_error(DesignFixedBlockedCluster$new("cluster", "cluster", "continuous", n = 8),
               "strata|cluster")
})

test_that("greedy designs expose batching and reject infeasible sample sizes", {
  greedy <- DesignFixedGreedy$new("continuous", n = 7, seed = 94)
  expect_true(greedy$supports_batch_w_pregeneration())
  greedy$add_all_subjects_to_experiment(data.frame(x = seq_len(7)))
  expect_error(greedy$assign_w_to_all_subjects(), "even number")

  pair_switch <- DesignFixedMatchingGreedyPairSwitching$new("continuous", n = 6, seed = 95)
  expect_true(pair_switch$supports_batch_w_pregeneration())
  pair_switch$add_all_subjects_to_experiment(data.frame(x = seq_len(6)))
  expect_error(pair_switch$assign_w_to_all_subjects(), "divisible by 4")
})

test_that("D-optimal design accessors and no-covariate allocation agree", {
  des <- DesignFixedGreedyDOptimal$new("continuous", prob_T = 0.3, objective = "D",
                                       interest = "treatment", prior_precision = 0.2,
                                       n = 10, design_formula = ~ 0, seed = 96)
  expect_identical(des$get_objective(), "D")
  expect_identical(des$get_interest(), "treatment")
  expect_equal(des$get_prior_precision(), 0.2)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(10)))
  des$assign_w_to_all_subjects()
  expect_equal(sum(des$get_w()), 3)
})

test_that("observational matching fixes pair IDs and accepts supplied exposure", {
  des <- ObservationalDesignMatching$new("continuous", n = 8, seed = 97)
  expect_equal(des$get_matching_cluster_ids(), rep(1:4, each = 2))
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(8)))
  w <- rep(c(0, 1), 4)
  des$assign_w_to_all_subjects(w_precomputed = w)
  expect_equal(des$get_w(), w)
  expect_equal(des$get_matching_cluster_ids(), rep(1:4, each = 2))
})

test_that("optimal-block constructor validates method and block feasibility", {
  expect_error(DesignFixedOptimalBlocks$new(B = 2, method = "unknown", response_type = "continuous", n = 8),
               "Must be element")
  expect_error(DesignFixedOptimalBlocks$new(B = NULL, method = "unknown", response_type = "continuous"),
               "Must be element")
})
