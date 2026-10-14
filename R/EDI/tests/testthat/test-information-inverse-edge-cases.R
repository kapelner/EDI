library(testthat)
library(EDI)

test_that("a boundary-excluded all-fixed information block is accepted as zero-dimensional", {
	f <- get("fast_neg_bin_with_var_cpp", envir = asNamespace("EDI"))
	set.seed(1)
	n <- 300L
	X <- cbind(1)
	y <- rpois(n, sample(c(2, 5, 10, 20, 50), 1))

	# Pin the only coefficient and cap the dispersion fit at the established
	# Poisson-boundary fixture. The information spec then excludes its only
	# remaining (dispersion) parameter, so the inverse helper receives a 0 x 0
	# block even though the optimizer itself retains one free parameter.
	r <- f(X, y, maxit = 15L, eps_g = 1e-9,
		fixed_idx = 1L, fixed_values = log(mean(y)))
	skip_if(is.null(r$information_invertible), "requires the guarded native library")

	expect_true(isTRUE(r$dispersion_at_poisson_boundary))
	expect_true(r$information_invertible)
	expect_identical(dim(r$vcov), c(2L, 2L))
	expect_true(all(is.nan(r$vcov)))
})

test_that("non-finite information after an overflowing warm start is rejected", {
	f <- get("fast_neg_bin_with_var_cpp", envir = asNamespace("EDI"))
	set.seed(17)
	n <- 80L
	X <- cbind(1, rnorm(n))
	y <- rpois(n, exp(0.1))

	# This finite design and response are valid; the warm-start intercept makes
	# exp(eta) overflow for some rows during the initial fit evaluation.
	r <- f(X, y, warm_start_params = c(710, 0, log(2)), maxit = 1L)
	skip_if(is.null(r$information_invertible), "requires the guarded native library")

	expect_false(r$information_invertible)
	expect_true(any(!is.finite(r$hess_fisher_info_matrix)))
	expect_true(all(is.nan(r$vcov)))
})

test_that("literal Inf in finite-input information is rejected", {
	f <- get("fast_neg_bin_with_var_cpp", envir = asNamespace("EDI"))
	# X remains finite and the warm start keeps the linear predictor moderate,
	# but the squared covariate contribution to Fisher information overflows.
	X <- cbind(intercept = 1, large_but_finite = rep(1e200, 80L))
	y <- rep(2L, nrow(X))
	r <- suppressWarnings(f(
		X, y, warm_start_params = c(0, 0, log(2)), maxit = 1L
	))
	skip_if(is.null(r$information_invertible), "requires the guarded native library")

	expect_true(all(is.finite(X)))
	expect_true(any(is.infinite(r$hess_fisher_info_matrix)))
	expect_false(r$information_invertible)
	expect_true(all(is.nan(r$vcov)))
})
