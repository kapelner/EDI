library(testthat)
library(EDI)

# lrt_ci_nr_cpp(): likelihood-ratio confidence interval by bracket search + Newton-Raphson /
# bisection, calling back into R for the constrained fit, negative log-likelihood and score.
# Reference: the profile-likelihood interval of a logistic-regression treatment coefficient
# (stats::confint on a glm, which profiles the likelihood), including different alphas, Wald
# seeds, and failure handling.

skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(7)
	n <- 120L
	x <- rnorm(n); w <- rbinom(n, 1, 0.5)
	y <- rbinom(n, 1, plogis(-0.3 + 0.5 * w + 0.4 * x))
	X <- cbind(1, w, x)
	g1 <- glm(y ~ w + x, family = binomial())
	calls <- new.env(); calls$n <- 0L
	fit_null <- function(delta) {
		calls$n <- calls$n + 1L
		g0 <- glm(y ~ x + offset(delta * w), family = binomial())
		list(mu = fitted(g0), nll = -as.numeric(logLik(g0)))
	}
	list(g1 = g1, X = X, y = y, fit_null = fit_null, calls = calls, est = unname(coef(g1)[2]), full = -as.numeric(logLik(g1)),
		nll_fn = function(fit) fit$nll, score_fn = function(fit) as.numeric(crossprod(X, y - fit$mu)))
}
lrt <- function(f, alpha = 0.05, lower = NA_real_, upper = NA_real_, ...) {
	K("lrt_ci_nr_cpp")(f$fit_null, f$nll_fn, f$score_fn, f$est, f$full, alpha, 0.1, lower, upper, 2L, ...)
}

test_that("the interval equals the profile-likelihood interval, for several alphas", {
	f <- fx()
	for (alpha in c(0.05, 0.2, 0.01)) {
		ref <- unname(suppressMessages(confint(f$g1, level = 1 - alpha))[2, ])
		expect_equal(lrt(f, alpha), ref, tolerance = 2e-4, info = as.character(alpha))
	}
})

test_that("Wald seeds change the search path but not the answer, and the bounds bracket the estimate", {
	f <- fx()
	ref <- unname(suppressMessages(confint(f$g1))[2, ])
	seeded <- lrt(f, 0.05, f$est - 0.5, f$est + 0.5)
	expect_equal(seeded, ref, tolerance = 2e-4)
	expect_lt(seeded[1], f$est); expect_gt(seeded[2], f$est)
	# The likelihood-ratio statistic at each bound is the chi-square(1) critical value.
	crit <- qchisq(0.95, 1)
	for (b in seeded) expect_equal(2 * (f$fit_null(b)$nll - f$full), crit, tolerance = 1e-3)
})

test_that("the constrained fit is called a modest number of times (Newton steps, not a grid)", {
	f <- fx()
	lrt(f)
	expect_lt(f$calls$n, 40L)
})

test_that("an interval that cannot be bracketed (the LR never leaves zero) gives NA bounds", {
	f <- fx()
	flat <- function(delta) list(mu = fitted(f$g1), nll = f$full)         # the LR never leaves zero
	expect_true(all(is.na(K("lrt_ci_nr_cpp")(flat, f$nll_fn, function(fit) c(0, 0, 0), f$est, f$full, 0.05, 0.1, NA_real_, NA_real_, 2L, 5L))))
})
