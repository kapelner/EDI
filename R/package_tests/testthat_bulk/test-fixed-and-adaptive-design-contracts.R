library(testthat)
library(EDI)

test_that("binary-match constructor validates explicit pairing metadata", {
  expect_error(DesignFixedBinaryMatch$new("continuous", prob_T = 0.4, n = 4), "prob_T = 0.5")
  expect_error(DesignFixedBinaryMatch$new("continuous", m = c(1, 1)), "n must also be supplied")
  expect_error(DesignFixedBinaryMatch$new("continuous", n = 4, m = c(1, 1)), "length\\(m\\) must equal n")
  expect_error(DesignFixedBinaryMatch$new("continuous", n = 4, m = c(1, 1, 1, 2)), "exactly twice")
})

test_that("binary match with explicit pairs assigns one treated subject per pair", {
  m <- rep(1:4, each = 2)
  des <- DesignFixedBinaryMatch$new("continuous", n = 8, m = m, seed = 301)
  expect_true(des$supports_batch_w_pregeneration())
  des$add_all_subjects_to_experiment(data.frame(x = 1:8))
  des$assign_w_to_all_subjects()
  expect_equal(as.numeric(rowsum(des$get_w(), m)), rep(1, 4))
  expect_equal(des$get_matching_cluster_ids(), m)
})

test_that("fixed blocking validates explicit blocks and balances within them", {
  expect_error(DesignFixedBlocking$new(response_type = "continuous", m = c(1, 1)), "n must also be supplied")
  expect_error(DesignFixedBlocking$new(response_type = "continuous", n = 6, B_target = 4,
                                       equal_block_sizes = TRUE), "not divisible")
  m <- rep(1:3, each = 4)
  des <- DesignFixedBlocking$new(response_type = "continuous", n = 12, B_target = 3,
                                 m = m, seed = 302)
  des$add_all_subjects_to_experiment(data.frame(x = 1:12))
  des$assign_w_to_all_subjects()
  expect_equal(as.numeric(rowsum(des$get_w(), m)), rep(2, 3))
  expect_equal(des$get_block_ids(), m)
})

test_that("rerandomization rejects ambiguous thresholds and falls back without covariates", {
  expect_error(DesignFixedRerandomization$new("continuous", obj_val_cutoff = 1,
                                              prop_acceptable = 0.1, n = 10), "both")
  des <- DesignFixedRerandomization$new("continuous", prob_T = 0.3, n = 10,
                                        design_formula = ~ 0, seed = 303)
  des$add_all_subjects_to_experiment(data.frame(x = 1:10))
  des$assign_w_to_all_subjects()
  expect_equal(sum(des$get_w()), 3)
})

test_that("fixed optimal validates solver surface without invoking a solver", {
  expect_error(DesignFixedOptimal$new("continuous", objective = "unknown", n = 8), "objective must be")
  expect_error(DesignFixedOptimal$new("continuous", objective = "mahal_dist", interest = "all", n = 8),
               "interest is only meaningful")
  expect_error(DesignFixedOptimal$new("continuous", solver = "bad", n = 8), "solver must be")
  expect_error(DesignFixedOptimal$new("continuous", objective = "custom", solver = "ompr",
                                      custom_objective = "code", n = 8), "cannot be solved")
  expect_error(DesignFixedOptimal$new("continuous", solver_args = list(unknown = 1), n = 8), "Unknown solver_args")

  des <- DesignFixedOptimal$new("continuous", objective = "D", interest = "treatment",
                                prior_precision = 0.1, solver = "annealing", mirror_coin = FALSE, n = 8)
  expect_identical(des$get_objective(), "D")
  expect_identical(des$get_interest(), "treatment")
  expect_equal(des$get_prior_precision(), 0.1)
  expect_identical(des$get_solver(), "annealing")
  expect_false(des$get_mirror_coin())
  expect_null(des$get_optimization_diagnostics())
})

test_that("iBCRD reaches its exact terminal treatment count and tracks one block", {
  des <- DesignSeqOneByOneiBCRD$new("continuous", prob_T = 0.3, n = 10, seed = 304)
  for (i in 1:10) des$add_one_subject_to_experiment_and_assign(data.frame(x = i))
  expect_equal(sum(des$get_w()), 3)
  expect_equal(des$get_block_ids(), rep(1L, 10))
  expect_true(des$is_blocking_design())
})

test_that("KK14 burn-in records reservoir membership and matching capabilities", {
  des <- DesignSeqOneByOneKK14$new("continuous", n = 8, lambda = 0.2,
                                   t_0_pct = 1, seed = 305)
  for (i in 1:4) {
    assignment <- des$add_one_subject_to_experiment_and_assign(data.frame(x = i))
    expect_true(assignment %in% c(0, 1))
  }
  # Public matching IDs normalize reservoir singletons to distinct positive IDs.
  expect_equal(des$get_matching_cluster_ids(), 1:4)
  expect_true(des$is_matching_design())
  expect_true(des$is_blocking_design())
})

test_that("fixed design preserves the trusted precomputed-assignment contract", {
  des <- DesignFixedBernoulli$new("continuous", n = 4)
  des$add_all_subjects_to_experiment(data.frame(x = 1:4))
  des$assign_w_to_all_subjects(c(0, 1))
  expect_equal(des$get_w(), c(0, 1, 0, 1))
})
