library(testthat)
library(EDI)

# fast_weibull_regression()'s use_rcpp = FALSE fallback path (survival::survreg
# wrapper in R/EDI/R/helper_glm_fit.R) had zero test references anywhere --
# every existing test exercises the default use_rcpp = TRUE Rcpp kernel or a
# different function (fast_weibull_regression_general_cpp / _cpp directly).

make_weibull_fixture <- function(seed, n = 80) {
	set.seed(seed)
	X <- cbind(w = rep(0:1, n / 2), x1 = rnorm(n))
	beta_true <- c(1, 0.5, -0.3)
	lp <- cbind(1, X) %*% beta_true
	sigma <- 0.7
	y <- rweibull(n, shape = 1 / sigma, scale = exp(lp))
	cens <- rexp(n, rate = 0.02)
	dead <- as.numeric(y <= cens)
	list(X = X, y = pmin(y, cens), dead = dead)
}

test_that("use_rcpp = FALSE reproduces an independent survival::survreg(dist='weibull') fit exactly", {
	f <- make_weibull_fixture(1L)
	res <- EDI:::fast_weibull_regression(f$y, f$dead, f$X, use_rcpp = FALSE)

	df <- data.frame(w = f$X[, "w"], x1 = f$X[, "x1"], y = f$y, dead = f$dead)
	mod <- survival::survreg(survival::Surv(y, dead) ~ w + x1, data = df, dist = "weibull")

	expect_equal(unname(res$coefficients), unname(mod$coefficients), tolerance = 1e-10)
	expect_equal(res$log_sigma, log(mod$scale), tolerance = 1e-10)
	expect_equal(res$vcov, mod$var, tolerance = 1e-10)
	expect_equal(res$neg_log_lik, -mod$loglik[2], tolerance = 1e-10)
})

test_that("use_rcpp = FALSE intercept-only model reproduces survreg(~1)", {
	f <- make_weibull_fixture(2L)
	res <- EDI:::fast_weibull_regression(f$y, f$dead, matrix(nrow = length(f$y), ncol = 0), use_rcpp = FALSE)

	mod <- survival::survreg(survival::Surv(f$y, f$dead) ~ 1, dist = "weibull")

	expect_equal(unname(res$coefficients), unname(mod$coefficients), tolerance = 1e-10)
	expect_equal(res$log_sigma, log(mod$scale), tolerance = 1e-10)
	expect_named(res$coefficients, "(Intercept)")
})

test_that("use_rcpp = FALSE strips a caller-supplied intercept column before refitting", {
	f <- make_weibull_fixture(3L)
	X_with_intercept <- cbind("(Intercept)" = 1, f$X)
	res <- EDI:::fast_weibull_regression(f$y, f$dead, X_with_intercept, use_rcpp = FALSE)

	df <- data.frame(w = f$X[, "w"], x1 = f$X[, "x1"], y = f$y, dead = f$dead)
	mod <- survival::survreg(survival::Surv(y, dead) ~ w + x1, data = df, dist = "weibull")

	expect_equal(unname(res$coefficients), unname(mod$coefficients), tolerance = 1e-10)
})

test_that("use_rcpp = FALSE drops linearly dependent columns before fitting", {
	f <- make_weibull_fixture(4L)
	X_collinear <- cbind(f$X, x2 = 2 * f$X[, "x1"])
	res <- EDI:::fast_weibull_regression(f$y, f$dead, X_collinear, use_rcpp = FALSE)

	expect_equal(names(res$coefficients), c("(Intercept)", "w", "x1"))
})

test_that("use_rcpp = FALSE ignores estimate_only -- unlike the Rcpp path, vcov is always computed", {
	# Real, documented-by-this-test quirk: the R survreg fallback path (unlike
	# the Rcpp path) always fits the full model and returns vcov regardless of
	# estimate_only -- it only gates a post-hoc finiteness check on it.
	f <- make_weibull_fixture(5L)
	r_estimate_only <- EDI:::fast_weibull_regression(f$y, f$dead, f$X, use_rcpp = FALSE, estimate_only = TRUE)
	r_full <- EDI:::fast_weibull_regression(f$y, f$dead, f$X, use_rcpp = FALSE, estimate_only = FALSE)

	expect_false(is.null(r_estimate_only$vcov))
	expect_equal(r_estimate_only$coefficients, r_full$coefficients)
	expect_equal(r_estimate_only$vcov, r_full$vcov)
})
