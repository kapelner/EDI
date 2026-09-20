library(testthat)
library(EDI)

test_that("uniform-weight shortcuts require positive finite relative uniformity", {
  constant <- EDI:::weights_are_effectively_constant
  for (invalid in list(numeric(), c(0, 0), c(-1, -1), c(1, NA), c(1, Inf))) {
    expect_false(constant(invalid))
  }
  for (scale in c(1e-300, 1, 1e300)) {
    expect_true(constant(scale * c(1, 1, 1)))
    expect_true(constant(scale * c(1, 1 + 1e-9)))
    expect_false(constant(scale * c(1, 2, 3)))
  }
})

test_that("KK weighted OLS retains nonuniform treatment effects on tiny weight scales", {
  withr::local_seed(715)
  n <- 37L
  des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
  for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
  w <- des$get_w()
  y <- cos(seq_len(n)) + w * (1 + seq_len(n) %% 5)
  des$add_all_subject_responses(y)
  inf <- InferenceContinKKOLSOneLik$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  context <- private$build_bayesian_bootstrap_context()
  private$current_bayesian_bootstrap_context <- context
  units <- split(seq_len(n), context$row_to_unit)
  pairs <- units[lengths(units) == 2L]
  reservoir <- unlist(units[lengths(units) == 1L], use.names = FALSE)
  expect_true(length(pairs) > 0L)
  expect_setequal(unique(w[reservoir]), c(0, 1))
  weights <- rep(c(1, 2, 3, 4), length.out = context$n_units)
  # Independent weighted normal equations for pair differences stacked with
  # unpaired subjects. Pair rows have zero intercept and treatment coding one.
  differences <- vapply(pairs, function(idx) y[idx[w[idx] == 1]] - y[idx[w[idx] == 0]], numeric(1))
  Z <- rbind(cbind(0, rep(1, length(pairs))), cbind(1, w[reservoir]))
  outcome <- c(differences, y[reservoir])
  row_weight <- c(weights[as.integer(names(pairs))], weights[context$row_to_unit[reservoir]])
  expected <- solve(crossprod(Z, Z * row_weight), crossprod(Z, outcome * row_weight))[2L]
  expect_equal(inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE), expected, tolerance = 1e-10)
  expect_equal(inf$compute_estimate_with_bootstrap_weights(1e-12 * weights, estimate_only = TRUE), expected, tolerance = 1e-10)
  expect_equal(inf$compute_estimate_with_bootstrap_weights(1e-200 * weights, estimate_only = TRUE), expected, tolerance = 1e-10)
  expect_true(is.na(inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  expect_true(is.na(private$weighted_refit_se()))
})
