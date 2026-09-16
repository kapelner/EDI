library(testthat)
library(EDI)

test_that("annealing L1 search reports the objective of its returned allocation", {
  A <- rbind(c(-3, -1, 1, 3), c(1, -1, -1, 1))
  allocations <- combn(4, 2, function(idx) as.numeric(1:4 %in% idx))
  reference <- apply(allocations, 2, function(w) sum(abs(A %*% w)))
  set.seed(501)
  fit <- EDI:::annealing_solve_l1(A, 2, n_chains = 2, max_iter = 200,
                                  initial_temp = 1, cooling_rate = 0.95)
  expect_equal(sum(fit$w), 2)
  expect_true(all(fit$w %in% c(0, 1)))
  expect_equal(fit$objective_value, sum(abs(A %*% fit$w)), tolerance = 1e-12)
  expect_gte(fit$objective_value, min(reference) - 1e-12)
  expect_lte(fit$objective_value, max(reference) + 1e-12)
  expect_equal(fit$objective_value, min(fit$chain_values), tolerance = 1e-12)
})

test_that("auto search crosses the quadratic and ratio annealing cutoff", {
  Q <- diag(c(1, 2, 4, 8))
  P <- matrix(0, 4, 4)
  H <- diag(4)
  for (kind in c("quadratic", "ratio")) {
    set.seed(502)
    expect_message(fit <- EDI:::optimal_solve_auto(
      kind, Q = Q, P = P, H = H, n_T = 2, linearization_max_n = 0,
      n_chains = 2, max_iter = 100, initial_temp = 1, cooling_rate = 0.95
    ), "exceeds linearization_max_n")
    expect_identical(fit$solver, "annealing")
    expect_identical(fit$certificate, "annealing_converged")
    expect_equal(sum(fit$w), 2)
    expected <- if (kind == "quadratic") drop(t(fit$w) %*% Q %*% fit$w) else 1.5
    expect_equal(fit$objective_value, expected, tolerance = 1e-10)
  }
})

test_that("Bayesian optimal matrices match ridge inverse references without scaling", {
  X <- cbind(x = c(-2, 0, 1, 3), z = c(1, -1, 2, 0))
  Z <- cbind(1, X)
  prior <- diag(c(0.2, 0.3, 0.4))
  V <- solve(crossprod(Z) + prior)
  fit <- EDI:::build_optimal_design_P_H(X, "all", prior, FALSE, TRUE)
  expect_equal(fit$P, Z %*% V %*% t(Z), tolerance = 1e-12)
  expect_equal(fit$H, Z %*% V %*% V %*% t(Z), tolerance = 1e-12)
  subset <- EDI:::build_optimal_design_P_H(X, "z", prior, FALSE, TRUE)
  expect_equal(subset$H, tcrossprod((Z %*% V)[, 3, drop = FALSE]), tolerance = 1e-12)
})

test_that("optimal blocks no-covariate path caches round-robin blocks", {
  skip_if_not_installed("anticlust")
  skip_if_not_installed("randomizr")
  des <- DesignFixedOptimalBlocks$new(B = 2, response_type = "continuous", n = 8,
                                       design_formula = ~ 0, seed = 503)
  des$add_all_subjects_to_experiment(data.frame(x = 1:8))
  des$assign_w_to_all_subjects()
  blocks <- des$get_block_ids()
  expect_equal(as.integer(blocks), rep(1:2, 4))
  expect_equal(as.numeric(rowsum(des$get_w(), blocks)), c(2, 2))
  des$assign_w_to_all_subjects()
  expect_identical(des$get_block_ids(), blocks)
})
