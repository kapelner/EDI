library(testthat)
library(EDI)

# fast_logistic_regression[_with_var], fast_beta_regression[_with_var],
# fast_negbin_regression[_with_var], and clogit_helper have zero direct
# test references anywhere (verified via repo-wide grep) despite being
# called internally by many higher-level inference classes -- those
# indirect callers exercise the happy path but not every branch a direct
# call surfaces (e.g. negative binomial's rank-deficient covariate
# auto-drop). Exercised here directly against independent references.

test_that("fast_logistic_regression and _with_var match glm exactly", {
	set.seed(42)
	n <- 100
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	y <- rbinom(n, 1, plogis(X %*% c(-0.3, 0.8, 0.5)))

	fit <- glm.fit(X, y, family = binomial())
	res <- EDI:::fast_logistic_regression(X, y)
	expect_equal(res$b, unname(fit$coefficients), tolerance = 1e-4)

	v <- summary(glm(y ~ X - 1, family = binomial()))$cov.unscaled
	resv <- EDI:::fast_logistic_regression_with_var(X, y, j = 2L)
	expect_equal(resv$b, unname(fit$coefficients), tolerance = 1e-4)
	expect_equal(resv$ssq_b_j, v[2, 2], tolerance = 1e-4)
	expect_equal(resv$ssq_b_2, v[2, 2], tolerance = 1e-4)

	# optimization_alg variants agree with each other
	res_irls <- EDI:::fast_logistic_regression(X, y, optimization_alg = "irls")
	res_newton <- EDI:::fast_logistic_regression_with_var(X, y, optimization_alg = "newton_raphson")
	expect_equal(res_irls$b, unname(fit$coefficients), tolerance = 1e-4)
	expect_equal(res_newton$b, unname(fit$coefficients), tolerance = 1e-4)
})

test_that("fast_beta_regression and _with_var match an independent betareg fit", {
	skip_if_not_installed("betareg")
	set.seed(42)
	n <- 100
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	y <- rbeta(n, 3, 5)

	df <- data.frame(y = y, x1 = X[, 2], x2 = X[, 3])
	fit <- betareg::betareg(y ~ x1 + x2, data = df)

	res <- EDI:::fast_beta_regression(X, y)
	expect_equal(res$b, unname(coef(fit)[1:3]), tolerance = 1e-3)

	resv <- EDI:::fast_beta_regression_with_var(X, y, j = 2L)
	expect_equal(resv$b, unname(coef(fit)[1:3]), tolerance = 1e-3)
	expect_equal(resv$ssq_b_j, unname(vcov(fit)[2, 2]), tolerance = 1e-2)
	expect_equal(resv$ssq_b_2, resv$ssq_b_j)
})

test_that("fast_negbin_regression and _with_var match an independent glm.nb fit", {
	skip_if_not_installed("MASS")
	set.seed(42)
	n <- 150
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	y <- rnbinom(n, size = 2, mu = exp(X %*% c(0.5, 0.3, 0.2)))

	fit <- MASS::glm.nb(y ~ X[, 2] + X[, 3])
	res <- EDI:::fast_negbin_regression(X, y)
	expect_equal(res$b, unname(coef(fit)), tolerance = 1e-3)

	resv <- EDI:::fast_negbin_regression_with_var(X, y, j = 2L)
	expect_equal(resv$b, unname(coef(fit)), tolerance = 1e-3)
	expect_true(is.finite(resv$ssq_b_j))
	expect_equal(resv$ssq_b_2, resv$ssq_b_j)
})

test_that("fast_negbin_regression auto-drops rank-deficient covariates beyond the treatment column", {
	set.seed(42)
	n <- 150
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	y <- rnbinom(n, size = 2, mu = exp(X %*% c(0.5, 0.3, 0.2)))

	# Column 4 is an exact linear multiple of column 3: rank-deficient beyond
	# the always-kept intercept/treatment columns.
	X_collinear <- cbind(X, X[, 3] * 2)
	res <- EDI:::fast_negbin_regression(X_collinear, y)
	expect_length(res$b, 3L)
	expect_equal(res$b, EDI:::fast_negbin_regression(X, y)$b, tolerance = 1e-6)

	resv <- EDI:::fast_negbin_regression_with_var(X_collinear, y, j = 2L)
	expect_length(resv$b, 3L)
})

test_that("clogit_helper's discordant-pairs fit matches an independent survival::clogit fit", {
	skip_if_not_installed("survival")
	# clogit()/coxph() internally reference unqualified symbols (coxph, strata)
	# that only resolve when survival is attached, not merely namespaced.
	library(survival)
	set.seed(42)
	n_pairs <- 60
	strata_m <- rep(seq_len(n_pairs), each = 2)
	w_m <- rep(c(0, 1), n_pairs)
	x_m <- rnorm(2 * n_pairs)
	eta <- 0.7 * w_m + 0.4 * x_m
	y_m <- rbinom(2 * n_pairs, 1, plogis(eta))

	res <- EDI:::clogit_helper(y_m, matrix(x_m, ncol = 1), w_m, strata_m)
	fit <- clogit(y_m ~ w_m + x_m + strata(strata_m))
	expect_equal(res$b, unname(coef(fit)), tolerance = 1e-4)
})

test_that("clogit_helper returns NULL when too few discordant pairs exist relative to the parameter count", {
	# A single matched pair with p=3 covariates gives at most 1 discordant
	# comparison per stratum -- far below the nd < p+5 floor.
	strata_m <- c(1L, 1L)
	w_m <- c(0, 1)
	y_m <- c(0, 1)
	X_m <- matrix(rnorm(2 * 3), nrow = 2, ncol = 3)
	expect_null(EDI:::clogit_helper(y_m, X_m, w_m, strata_m))
})
