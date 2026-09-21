library(testthat)
library(EDI)

# C++ kernels: get_logistic_regression_{score,hessian}_cpp (+ weighted) against numDeriv of the
# Bernoulli logit log-likelihood; fast_ols_cpp against lm (plain and with a fixed coefficient);
# and the complementary-log-log ordinal kernels. The cloglog kernel's convention is
# P(Y <= k) = 1 - exp(-exp(alpha_k + x'b)) -- the OPPOSITE sign of b to MASS::polr's
# zeta_k - x'beta (the logit / probit kernels follow polr); InferenceOrdinalCloglog negates b
# itself. Pinned here so a silent convention change is caught.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("logistic score and Hessian (plain and weighted) equal numeric derivatives", {
	set.seed(3)
	n <- 100L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	y <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.3, 0.6, 0.4)))); wt <- rexp(n)
	ll <- function(b, w = 1) { e <- X %*% b; sum(w * (y * e - log1p(exp(e)))) }
	b0 <- c(0.1, 0.2, -0.1)
	expect_equal(K("get_logistic_regression_score_cpp")(X, y, b0), numDeriv::grad(ll, b0), tolerance = 1e-6)
	expect_equal(unname(K("get_logistic_regression_hessian_cpp")(X, b0)), numDeriv::hessian(ll, b0), tolerance = 1e-5)
	expect_equal(K("get_logistic_regression_weighted_score_cpp")(X, y, wt, b0), numDeriv::grad(function(b) ll(b, wt), b0), tolerance = 1e-6)
	expect_equal(unname(K("get_logistic_regression_weighted_hessian_cpp")(X, wt, b0)), numDeriv::hessian(function(b) ll(b, wt), b0), tolerance = 1e-5)
})

test_that("fast_ols_cpp equals lm, and a fixed coefficient is held with the rest refit on the offset response", {
	set.seed(4)
	n <- 100L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	y <- as.numeric(X %*% c(1, 0.5, -0.3) + rnorm(n))
	expect_equal(as.numeric(K("fast_ols_cpp")(X, y)$b), unname(coef(lm(y ~ X - 1))), tolerance = 1e-10)
	fx <- K("fast_ols_cpp")(X, y, fixed_idx = 2L, fixed_values = 0.25)
	expect_equal(as.numeric(fx$b)[2], 0.25)
	ref <- unname(coef(lm(I(y - 0.25 * X[, 2]) ~ X[, -2] - 1)))
	expect_equal(as.numeric(fx$b)[-2], ref, tolerance = 1e-8)
})

cl_fixture <- function() {
	set.seed(9)
	n <- 100L
	Xo <- cbind(rnorm(n), rbinom(n, 1, 0.5))
	yo <- as.integer(cut(0.6 * Xo[, 1] - 0.4 * Xo[, 2] + rlogis(n), c(-Inf, -1, 0.3, 1.4, Inf)))
	list(X = Xo, y = yo, n = n)
}
ll_cloglog <- function(p, dat) {
	a <- p[1:3]; b <- p[4:5]; eta <- drop(dat$X %*% b)
	cdf <- cbind(0, vapply(a, function(t) 1 - exp(-exp(t + eta)), numeric(dat$n)), 1)
	sum(log(cdf[cbind(seq_len(dat$n), dat$y + 1L)] - cdf[cbind(seq_len(dat$n), dat$y)]))
}

test_that("cloglog score and Hessian follow the alpha + x'b convention", {
	f <- cl_fixture(); p0 <- c(-1, 0.05, 0.45, 0.4, -0.3)
	expect_equal(K("get_ordinal_cloglog_regression_score_cpp")(f$X, f$y, p0), numDeriv::grad(ll_cloglog, p0, dat = f), tolerance = 1e-5)
	expect_equal(unname(K("get_ordinal_cloglog_regression_hessian_cpp")(f$X, f$y, p0)), numDeriv::hessian(ll_cloglog, p0, dat = f), tolerance = 1e-3)
})

test_that("the cloglog fit reaches polr's likelihood with thresholds equal and coefficients of opposite sign", {
	skip_if_not_installed("MASS")
	f <- cl_fixture()
	r <- K("fast_ordinal_cloglog_regression_cpp")(f$X, f$y)
	pr <- suppressWarnings(MASS::polr(factor(f$y) ~ f$X, method = "cloglog"))
	expect_true(r$converged)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(pr)), tolerance = 1e-5)
	expect_equal(as.numeric(r$alpha), unname(pr$zeta), tolerance = 1e-3)
	expect_equal(as.numeric(r$b), -unname(coef(pr)), tolerance = 1e-3)
	expect_equal(-ll_cloglog(as.numeric(r$params), f), as.numeric(r$neg_loglik), tolerance = 1e-6)
})
