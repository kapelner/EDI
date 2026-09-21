library(testthat)
library(EDI)

# fast_hurdle_negbin_cpp / fast_hurdle_negbin_with_var_cpp: the hurdle negative-binomial model fitted
# as a zero-truncated NB count part (b, theta_hat) plus a separate binomial hurdle part (hurdle_b,
# modelling P(y > 0), the SAME sign convention as pscl -- unlike the zero-augmented Poisson kernel,
# whose zero model is P(structural zero)). Reference: pscl::hurdle(dist = "negbin", zero.dist =
# "binomial"): coefficients, theta, and the variances of the requested coefficients.

skip_if_not_installed("pscl")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed) {
	set.seed(seed)
	n <- 300L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5)); Xh <- cbind(1, X[, 2])
	mu <- exp(X %*% c(0.8, 0.3, -0.2)); pos <- rbinom(n, 1, plogis(Xh %*% c(0.3, -0.4)))
	yc <- rnbinom(n, size = 2, mu = mu); yc[yc == 0] <- 1
	y <- as.numeric(ifelse(pos == 1, yc, 0))
	list(X = X, Xh = Xh, y = y, d = data.frame(y = y, x1 = X[, 2], x2 = X[, 3]))
}

test_that("count coefficients, theta and hurdle coefficients equal pscl::hurdle on several datasets", {
	for (s in c(4L, 6L, 9L)) {
		f <- fx(s)
		hu <- suppressWarnings(pscl::hurdle(y ~ x1 + x2 | x1, data = f$d, dist = "negbin", zero.dist = "binomial"))
		r <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 2L)
		expect_true(r$converged && r$hurdle_converged, info = as.character(s))
		expect_equal(as.numeric(r$b), unname(coef(hu))[1:3], tolerance = 2e-3, info = as.character(s))
		expect_equal(as.numeric(r$theta_hat), unname(hu$theta), tolerance = 5e-3, info = as.character(s))
		expect_equal(as.numeric(r$hurdle_b), unname(coef(hu))[4:5], tolerance = 2e-3, info = as.character(s))
	}
})

test_that("the reported variances are those of the requested coefficient in each part (1-based j)", {
	f <- fx(4L)
	hu <- suppressWarnings(pscl::hurdle(y ~ x1 + x2 | x1, data = f$d, dist = "negbin", zero.dist = "binomial"))
	r <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 2L)
	expect_equal(as.numeric(r$ssq_b_j), unname(vcov(hu)["count_x1", "count_x1"]), tolerance = 1e-3)
	expect_equal(as.numeric(r$ssq_b_2), as.numeric(r$ssq_b_j))
	expect_equal(as.numeric(r$hurdle_ssq_b_j), unname(vcov(hu)["zero_x1", "zero_x1"]), tolerance = 1e-3)
	r1 <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 3L)
	expect_equal(as.numeric(r1$ssq_b_j), unname(vcov(hu)["count_x2", "count_x2"]), tolerance = 1e-3)
})

test_that("the lean fit returns the same estimates without variances", {
	f <- fx(4L)
	lean <- K("fast_hurdle_negbin_cpp")(f$X, f$y, f$Xh)
	full <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 2L)
	expect_equal(as.numeric(lean$b), as.numeric(full$b), tolerance = 1e-4)
	expect_equal(as.numeric(lean$theta_hat), as.numeric(full$theta_hat), tolerance = 1e-3)
})

test_that("a fixed count coefficient is held exactly and the remaining coefficients are re-estimated", {
	f <- fx(4L)
	free <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 2L)
	fix <- K("fast_hurdle_negbin_with_var_cpp")(f$X, f$y, f$Xh, 2L, fixed_idx = 2L, fixed_values = 0.25)
	expect_equal(as.numeric(fix$b)[2], 0.25)
	expect_false(isTRUE(all.equal(as.numeric(fix$b)[c(1, 3)], as.numeric(free$b)[c(1, 3)], tolerance = 1e-3)))
	# Constrained refit: the intercept / x2 coefficients equal an NB fit with the slope pinned via an offset on the positive counts.
	pos <- f$y > 0
	Xp <- f$X[pos, ]; yp <- f$y[pos]
	nll <- function(par) {                                     # zero-truncated NB, coefficient 2 fixed at 0.25
		b <- c(par[1], 0.25, par[2]); th <- exp(par[3]); mu <- as.numeric(exp(Xp %*% b))
		-sum(dnbinom(yp, size = th, mu = mu, log = TRUE) - log1p(-dnbinom(0, size = th, mu = mu)))
	}
	o <- optim(c(0.7, -0.3, log(1.3)), nll, method = "BFGS", control = list(reltol = 1e-12))
	expect_equal(as.numeric(fix$b)[c(1, 3)], o$par[1:2], tolerance = 2e-3)
})
