library(testthat)
library(EDI)

test_that("fixed design core enforces arrival and single-ingestion contracts", {
  des <- DesignFixedBernoulli$new(response_type = "continuous", n = 4, seed = 101)
  expect_error(des$add_all_subjects_to_experiment(data.frame(x = 1:3)), "exactly 4 rows")
  des$add_all_subjects_to_experiment(data.frame(x = 1:4))
  expect_error(des$add_all_subjects_to_experiment(data.frame(x = 1:4)), "already been added")
  des$assign_w_to_all_subjects()
  expect_length(des$get_w(), 4L)
  expect_true(all(des$get_w() %in% c(0, 1)))
})

test_that("matching helpers classify simulation hooks deterministically", {
  f <- function(...) NULL
  expect_identical(EDI:::compute_simulation_mode(NULL, NULL, NULL, NULL), "standard")
  expect_identical(EDI:::compute_simulation_mode(f, f, f, f), "custom_dgp")
  expect_identical(EDI:::compute_simulation_mode(NULL, f, NULL, f), "crdg+cte")
  expect_identical(EDI:::compute_simulation_mode(NULL, NULL, f, NULL), "catn")
})

test_that("matching index helpers normalize reservoirs and incomplete pairs", {
  split <- EDI:::split_kk_matched_reservoir_idx(c(1, 1, NA, 0, 2, 2), 6)
  expect_identical(split$m_vec, c(1L, 1L, 0L, 0L, 2L, 2L))
  expect_identical(split$matched_idx, c(1L, 2L, 5L, 6L))
  expect_identical(split$reservoir_idx, c(3L, 4L))
  all_reservoir <- EDI:::split_kk_matched_reservoir_idx(NULL, 3)
  expect_identical(all_reservoir$reservoir_idx, 1:3)

  pairs <- EDI:::.complete_pair_index_matrix(c(2, 1, 1, 2, 3, NA, 3, 3))
  expect_identical(as.integer(pairs), c(2L, 1L, 3L, 4L))
  expect_equal(dim(EDI:::.complete_pair_index_matrix(c(0, NA, 1))), c(0L, 2L))
})

test_that("one-dimensional binary matching pairs adjacent ordered subjects", {
  skip_if_not_installed("nbpMatching")
  X <- matrix(c(9, 1, 7, 3), ncol = 1)
  match <- EDI:::compute_binary_match_structure(X)
  expect_equal(match$indicies_pairs, matrix(c(2L, 4L, 3L, 1L), ncol = 2, byrow = TRUE))
  expect_identical(match$indices_pairs, match$indicies_pairs)
  expect_error(EDI:::compute_binary_match_structure(matrix(1:3, ncol = 1)), "even number")
})

test_that("optimal objective validation resolves supported interest forms", {
  args <- EDI:::validate_optimal_design_objective_args(
    "D", "x1 + x2", NULL, TRUE, allowed_objectives = c("D", "A")
  )
  expect_s3_class(args$interest, "formula")
  expect_identical(args$interest_kind, "subset")
  expect_identical(EDI:::validate_optimal_design_objective_args(
    "A", "all", 0.5, FALSE, c("D", "A"))$interest_kind, "all")
  expect_error(EDI:::validate_optimal_design_objective_args("bad", "all", NULL, TRUE, c("D", "A")), "objective")
  expect_error(EDI:::validate_optimal_design_objective_args("D", diag(2), NULL, TRUE, c("D")), "Contrast-matrix")
  expect_error(EDI:::validate_optimal_design_objective_args("D", "all", -1, TRUE, c("D")), "prior_precision")
  expect_error(EDI:::validate_optimal_design_objective_args("D", "all", NULL, NA, c("D")), "TRUE or FALSE")
})

test_that("optimal interest columns and P/H matrices have expected geometry", {
  X <- cbind(x1 = c(-1, 0, 1, 2), x2 = c(2, -1, 0, 1))
  expect_identical(EDI:::resolve_optimal_interest_z0_columns(X, c("x2", "x1")), c(3L, 2L))
  expect_error(EDI:::resolve_optimal_interest_z0_columns(unname(X), "x1"), "no column names")
  expect_error(EDI:::resolve_optimal_interest_z0_columns(X, "missing"), "not found")

  ph <- EDI:::build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
  expect_equal(ph$P, t(ph$P), tolerance = 1e-12)
  expect_equal(ph$P %*% ph$P, ph$P, tolerance = 1e-10)
  expect_equal(dim(ph$H), c(4L, 4L))
  p_only <- EDI:::build_optimal_design_P_H(X, "treatment", 0.2, TRUE, need_H = FALSE)
  expect_null(p_only$H)
  expect_equal(dim(p_only$P), c(4L, 4L))
})

test_that("annealing argument and treated-count checks reject invalid controls", {
  expect_true(EDI:::assert_annealing_args(2, 100, NULL, 0.99))
  expect_error(EDI:::assert_annealing_args(0, 100, NULL, 0.99), "n_chains")
  expect_error(EDI:::assert_annealing_args(2, 0, NULL, 0.99), "max_iter")
  expect_error(EDI:::assert_annealing_args(2, 100, -1, 0.99), "initial_temp")
  expect_error(EDI:::assert_annealing_args(2, 100, NULL, 1), "cooling_rate")
  expect_identical(EDI:::assert_optimal_milp_n_T(2, 5), 2L)
  expect_error(EDI:::assert_optimal_milp_n_T(0, 5), "1 <= n_T")
  expect_error(EDI:::assert_optimal_roi_solver("typo"), "must be one of")
})

test_that("annealing temperature calibration is positive and reproducible", {
  objective <- function(w) sum((seq_along(w) * w)^2)
  set.seed(102)
  first <- EDI:::estimate_annealing_initial_temp(objective, n = 8, n_T = 4, n_probe = 8)
  set.seed(102)
  second <- EDI:::estimate_annealing_initial_temp(objective, n = 8, n_T = 4, n_probe = 8)
  expect_identical(first, second)
  expect_gt(first, 0)
})

test_that("optimal objective matrices select quadratic and singular fallback paths", {
  X <- cbind(x1 = c(-2, -1, 1, 2), x2 = c(1, -2, 2, -1))
  quadratic <- EDI:::prepare_optimal_objective_matrices(X, "mahal_dist")
  expect_identical(quadratic$kind, "quadratic")
  expect_equal(quadratic$Q, t(quadratic$Q), tolerance = 1e-12)

  singular <- EDI:::prepare_optimal_objective_matrices(cbind(x = 1:4, duplicate = 1:4), "mahal_dist")
  expect_identical(singular$kind, "l1")
  expect_true(singular$mahal_fell_back)
  absolute <- EDI:::prepare_optimal_objective_matrices(X, "abs_sum_diff")
  expect_identical(absolute$kind, "l1")
  expect_equal(dim(absolute$A), c(2L, 4L))
})
