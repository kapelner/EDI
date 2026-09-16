library(testthat)
library(EDI)

test_that("synthetic fixtures complete every supported response family reproducibly", {
  for (type in c("continuous", "incidence", "count", "proportion", "ordinal", "survival")) {
    first <- EDI:::inference_migration_complete_design(type, n = 12, seed = 401)
    second <- EDI:::inference_migration_complete_design(type, n = 12, seed = 401)
    expect_equal(first$get_w(), second$get_w())
    expect_equal(first$get_y(), second$get_y())
    expect_equal(first$get_t(), 12)
    expect_true(first$check_experiment_completed())
  }
})

test_that("fixture seed wrapper restores caller RNG state on success and error", {
  set.seed(402)
  before <- .Random.seed
  value <- EDI:::inference_migration_with_seed(999, runif(2))
  expect_length(value, 2L)
  expect_identical(.Random.seed, before)
  expect_error(EDI:::inference_migration_with_seed(999, stop("fixture failure")), "fixture failure")
  expect_identical(.Random.seed, before)
})

test_that("KK21 stepwise speedup paths yield normalized outcome-informed weights", {
  for (type in c("continuous", "count", "proportion", "ordinal")) {
    des <- DesignSeqOneByOneKK21stepwise$new(response_type = type, n = 18,
                                             num_boot = 5, t_0_pct = 0, seed = 403)
    for (i in 1:18) {
      des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i), z = cos(i)))
      y <- switch(type, continuous = sin(i) + 0.1 * i,
                  count = as.integer(i %% 5), proportion = (i %% 8 + 1) / 10,
                  ordinal = as.integer(i %% 3 + 1))
      des$add_one_subject_response(i, y)
    }
    weights <- des$get_covariate_weights()
    expect_true(all(is.finite(weights)))
    expect_equal(sum(weights), 1, tolerance = 1e-12)
    expect_true(length(des$get_iteration_weights()) > 0)
  }
})

test_that("matching pair-switch search respects its fixed pair exchangeability", {
  skip_if_not_installed("nbpMatching")
  des <- DesignFixedMatchingGreedyPairSwitching$new("continuous", n = 8,
                                                   n_iter = 2, seed = 404)
  des$add_all_subjects_to_experiment(data.frame(x = 1:8))
  des$assign_w_to_all_subjects()
  pair_ids <- des$get_matching_cluster_ids()
  expect_equal(as.numeric(rowsum(des$get_w(), pair_ids)), rep(1, 4))
  expect_equal(length(unique(pair_ids)), 4L)
})

test_that("Bayesian subset D-optimal design preserves supplied configuration", {
  des <- DesignFixedGreedyDOptimal$new("continuous", objective = "A", interest = c("x"),
                                       prior_precision = 0.3, n = 8, seed = 405)
  expect_identical(des$get_objective(), "A")
  expect_identical(des$get_interest(), "x")
  expect_equal(des$get_prior_precision(), 0.3)
  des$add_all_subjects_to_experiment(data.frame(x = 1:8))
  des$assign_w_to_all_subjects()
  expect_equal(sum(des$get_w()), 4)
})

test_that("observational matching preserves pairs under overwritten exposure", {
  des <- ObservationalDesignMatching$new("continuous", n = 6)
  des$add_all_subjects_to_experiment(data.frame(x = 1:6))
  des$assign_w_to_all_subjects(w_precomputed = c(1, 0, 1, 0, 1, 0))
  des$overwrite_all_subject_assignments(c(0, 1, 0, 1, 0, 1))
  expect_equal(des$get_matching_cluster_ids(), rep(1:3, each = 2))
  expect_equal(des$get_w(), c(0, 1, 0, 1, 0, 1))
})

test_that("optimal blocks checks minimum feasible block sizes", {
  skip_if_not_installed("anticlust")
  expect_error(DesignFixedOptimalBlocks$new(B = 4, response_type = "continuous", n = 6),
               "block|size")
})
