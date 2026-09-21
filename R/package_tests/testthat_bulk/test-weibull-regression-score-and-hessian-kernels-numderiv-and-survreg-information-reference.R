library(testthat)
library(EDI)

# get_weibull_regression_score_cpp / get_weibull_regression_hessian_cpp: gradient and Hessian of the Weibull AFT
# log-likelihood in (beta, log sigma). Independent references: an R log-likelihood differentiated by numDeriv, and
# survival::survreg (score ~ 0 at its MLE; -Hessian equals the inverse of survreg's vcov).

E <- asNamespace("EDI")
S <- get("get_weibull_regression_score_cpp", E); H <- get("get_weibull_regression_hessian_cpp", E)

set.seed(1); n <- 60L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
y <- rexp(n) * exp(0.3 * X[, 2]) + 0.05
dead <- rbinom(n, 1, 0.7)
ll <- function(pr, dat = NULL) {
	s <- exp(pr[4]); z <- (log(y) - X %*% pr[1:3]) / s
	sum(dead * (z - log(s) - log(y)) - exp(z))
}

test_that("score equals the numerical gradient of the log-likelihood at several parameter points", {
	for (p in list(c(0.2, 0.1, -0.1, -0.2), c(0, 0, 0, 0), c(-0.5, 0.4, 0.3, 0.5))) {
		expect_equal(as.numeric(S(X, y, as.numeric(dead), p)), numDeriv::grad(ll, p), tolerance = 1e-6)
	}
})

test_that("Hessian equals the numerical Hessian of the log-likelihood and is symmetric", {
	for (p in list(c(0.2, 0.1, -0.1, -0.2), c(-0.5, 0.4, 0.3, 0.5))) {
		h <- H(X, y, as.numeric(dead), p)
		expect_equal(h, numDeriv::hessian(ll, p), tolerance = 1e-5)
		expect_equal(h, t(h), tolerance = 1e-10)
	}
})

test_that("at the survreg MLE the score vanishes and -Hessian is the inverse of survreg's vcov", {
	f <- survival::survreg(survival::Surv(y, dead) ~ X[, -1], dist = "weibull")
	pm <- c(coef(f), log(f$scale))
	expect_lt(max(abs(S(X, y, as.numeric(dead), pm))), 1e-4)
	expect_equal(unname(-H(X, y, as.numeric(dead), pm)), unname(solve(f$var)), tolerance = 1e-4)
	expect_true(all(eigen(-H(X, y, as.numeric(dead), pm), only.values = TRUE)$values > 0))
})

test_that("all-censored and all-event samples still give finite score and Hessian", {
	for (dd in list(rep(0, n), rep(1, n))) {
		expect_true(all(is.finite(S(X, y, dd, c(0, 0, 0, 0)))))
		expect_true(all(is.finite(H(X, y, dd, c(0, 0, 0, 0)))))
	}
})
