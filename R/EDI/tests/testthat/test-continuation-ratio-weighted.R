make_weighted_continuation_ratio_data <- function() {
	set.seed(6204)
	n <- 160L
	X <- cbind(
		treatment = rep(c(0, 1), length.out = n),
		x = rnorm(n, sd = 0.6)
	)
	eta <- 0.7 * X[, "treatment"] - 0.25 * X[, "x"]
	hazards <- cbind(
		plogis(-1.0 + eta),
		plogis(-0.5 + eta),
		plogis(0.1 + eta)
	)
	y <- integer(n)
	for (i in seq_len(n)) {
		y[i] <- 4L
		for (k in seq_len(3L)) {
			if (runif(1) < hazards[i, k]) {
				y[i] <- k
				break
			}
		}
	}
	list(X = X, y = as.numeric(y))
}

test_that("unit-weight continuation-ratio fit reproduces the unweighted fit", {
	d <- make_weighted_continuation_ratio_data()
	unweighted <- EDI:::fast_continuation_ratio_regression_cpp(
		d$X, d$y, maxit = 250L, tol = 1e-10
	)
	weighted <- EDI:::fast_continuation_ratio_regression_weighted_cpp(
		d$X, d$y, rep(1, nrow(d$X)), maxit = 250L, tol = 1e-10
	)

	expect_true(unweighted$converged)
	expect_true(weighted$converged)
	expect_equal(weighted$params, unweighted$params, tolerance = 1e-8)
	expect_equal(weighted$neg_loglik, unweighted$neg_loglik, tolerance = 1e-8)
	expect_equal(weighted$fisher_information, unweighted$fisher_information, tolerance = 1e-8)
	expect_equal(weighted$weights_aug, rep(1, length(weighted$z)))
})

test_that("continuation-ratio estimates are invariant to weight scale", {
	d <- make_weighted_continuation_ratio_data()
	weights <- seq(0.25, 2.25, length.out = nrow(d$X))
	fit <- EDI:::fast_continuation_ratio_regression_weighted_cpp(
		d$X, d$y, weights, maxit = 250L, tol = 1e-10
	)
	fit_scaled <- EDI:::fast_continuation_ratio_regression_weighted_cpp(
		d$X, d$y, 7 * weights,
		maxit = 250L,
		tol = 1e-10,
		warm_start_beta = fit$params
	)

	expect_true(fit$converged)
	expect_true(fit_scaled$converged)
	expect_equal(fit_scaled$params, fit$params, tolerance = 1e-7)
	expect_equal(fit_scaled$neg_loglik, 7 * fit$neg_loglik, tolerance = 1e-6)
	expect_equal(
		fit_scaled$fisher_information,
		7 * fit$fisher_information,
		tolerance = 1e-6
	)
})

test_that("integer subject weights match explicit subject replication", {
	d <- make_weighted_continuation_ratio_data()
	weights <- rep(c(1, 2, 3, 1), length.out = nrow(d$X))
	replicated_rows <- rep(seq_len(nrow(d$X)), times = weights)

	weighted <- EDI:::fast_continuation_ratio_regression_weighted_cpp(
		d$X, d$y, weights, maxit = 250L, tol = 1e-10
	)
	replicated <- EDI:::fast_continuation_ratio_regression_cpp(
		d$X[replicated_rows, , drop = FALSE],
		d$y[replicated_rows],
		maxit = 250L,
		tol = 1e-10
	)

	expect_true(weighted$converged)
	expect_true(replicated$converged)
	expect_equal(weighted$params, replicated$params, tolerance = 1e-7)
	expect_equal(weighted$neg_loglik, replicated$neg_loglik, tolerance = 1e-7)
	expect_equal(weighted$fisher_information, replicated$fisher_information, tolerance = 1e-6)

	levels_y <- sort(unique(d$y))
	n_alpha <- length(levels_y) - 1L
	augmented_rows_per_subject <- pmin(match(d$y, levels_y), n_alpha)
	expect_equal(
		weighted$weights_aug,
		rep(weights, times = augmented_rows_per_subject)
	)
})
