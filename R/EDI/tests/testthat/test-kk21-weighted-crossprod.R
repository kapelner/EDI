library(testthat)
library(EDI)

kk21_logistic_reduced_fit_reference <- function(X, y, beta) {
	for (iteration in seq_len(100L)) {
		eta <- drop(X %*% beta)
		prob <- plogis(eta)
		weights <- pmax(1e-10, prob * (1 - prob))
		z <- eta + (y - prob) / weights
		information <- crossprod(X, X * weights)
		beta_new <- drop(solve(information, crossprod(X, weights * z)))
		if (sqrt(sum((beta - beta_new)^2)) < 1e-8) {
			beta <- beta_new
			break
		}
		beta <- beta_new
	}
	eta <- drop(X %*% beta)
	prob <- plogis(eta)
	weights <- pmax(1e-10, prob * (1 - prob))
	list(
		beta = beta,
		weights = weights,
		residuals = y - prob,
		information = crossprod(X, X * weights)
	)
}

kk21_stepwise_logistic_reference <- function(X, y, treatment) {
	p <- ncol(X)
	selected <- integer()
	unused <- seq_len(p)
	weights_out <- rep(NA_real_, p)
	model <- cbind(1, treatment)
	beta <- numeric(2L)

	for (step in seq_len(p)) {
		fit <- kk21_logistic_reduced_fit_reference(model, y, beta)
		stats <- vapply(unused, function(j) {
			x <- X[, j]
			score <- sum(x * fit$residuals)
			v <- drop(crossprod(model, fit$weights * x))
			adjusted_information <- sum(fit$weights * x^2) -
				drop(crossprod(v, solve(fit$information, v)))
			if (adjusted_information <= 0) return(0)
			abs(score) / sqrt(adjusted_information)
		}, numeric(1L))
		best_position <- which.max(stats)
		best <- unused[best_position]
		weights_out[best] <- stats[best_position]
		selected <- c(selected, best)
		unused <- unused[-best_position]
		model <- cbind(model, X[, best])
		beta <- c(fit$beta, 0)
	}
	weights_out
}

kk21_weibull_weight_reference <- function(x, time, event) {
	fit <- survival::survreg(survival::Surv(time, event) ~ x, dist = "weibull")
	abs(unname(summary(fit)$table["x", "z"]))
}

test_that("KK21 stepwise logistic weights match an R score-test reference", {
	set.seed(79)
	n <- 100L
	X <- cbind(x1 = rnorm(n), x2 = runif(n, -1, 1), x3 = rep(c(-1, 1, 1, -1), length.out = n))
	treatment <- rep(c(0, 1), n / 2L)
	y <- rbinom(n, 1, plogis(-0.2 + 0.5 * treatment + 0.7 * X[, 1L]))

	expected <- kk21_stepwise_logistic_reference(X, y, treatment)
	actual <- EDI:::kk21_stepwise_logistic_weights_cpp(X, y, treatment)
	expect_equal(as.numeric(actual), expected, tolerance = 1e-8)
})

test_that("KK21 survival weights match a survreg Weibull MLE with and without censoring", {
	set.seed(791)
	n <- 100L
	X <- cbind(x1 = rnorm(n), x2 = runif(n, -1, 1), x3 = rep(c(-1, 1), n / 2L))
	time <- rexp(n, rate = exp(0.3 * X[, 1L] - 0.2 * X[, 2L]))
	for (event in list(censored = rbinom(n, 1, 0.8), uncensored = rep(1L, n))) {
		expected <- apply(X, 2L, kk21_weibull_weight_reference, time = time, event = event)
		actual <- EDI:::kk21_survival_weights_cpp(X, time, event)
		expect_equal(as.numeric(actual), unname(expected), tolerance = 1e-5)
	}
})
