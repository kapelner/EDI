library(testthat)
library(EDI)

# C++ kernels: get_poisson_regression_{score,hessian} (+ weighted) against numDeriv of the Poisson
# log-likelihood; get_probit_regression_hessian_cpp (expected Fisher information) and
# fast_probit_regression_cpp / _weighted_cpp against glm(family = binomial("probit"));
# wilcox_hl_point_estimate_cpp / wilcox_hl_signed_rank_point_estimate_cpp against the definition of
# the Hodges-Lehmann estimators (and wilcox.test); eigen_Xt_times_X / _diag_w_ helpers, mean_cpp,
# var_cpp; columns_have_missingness_cpp / create_missingness_indicators_cpp.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(3)
	n <- 90L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	list(X = X, n = n, yc = as.numeric(rpois(n, exp(X %*% c(0.2, 0.3, -0.2)))),
		yb = as.numeric(rbinom(n, 1, pnorm(X %*% c(-0.1, 0.5, 0.3)))), w = rexp(n))
}

test_that("Poisson score and Hessian (plain and weighted) equal numeric derivatives", {
	f <- fx(); b0 <- c(0.1, 0.2, -0.1)
	ll <- function(b, w = 1) sum(w * dpois(f$yc, exp(f$X %*% b), log = TRUE))
	expect_equal(K("get_poisson_regression_score_cpp")(f$X, f$yc, b0), numDeriv::grad(ll, b0), tolerance = 1e-6)
	expect_equal(unname(K("get_poisson_regression_hessian_cpp")(f$X, b0)), numDeriv::hessian(ll, b0), tolerance = 1e-5)
	expect_equal(K("get_poisson_regression_weighted_score_cpp")(f$X, f$yc, f$w, b0), numDeriv::grad(function(b) ll(b, f$w), b0), tolerance = 1e-6)
	expect_equal(unname(K("get_poisson_regression_weighted_hessian_cpp")(f$X, f$w, b0)), numDeriv::hessian(function(b) ll(b, f$w), b0), tolerance = 1e-5)
})

test_that("the probit Hessian is minus the expected Fisher information X' diag(phi^2 / (Phi (1 - Phi))) X", {
	f <- fx(); b0 <- c(0.1, 0.2, -0.1)
	eta <- f$X %*% b0; p <- pnorm(eta)
	wi <- as.numeric(dnorm(eta)^2 / (p * (1 - p)))
	expect_equal(unname(K("get_probit_regression_hessian_cpp")(f$X, b0)), -crossprod(f$X * wi, f$X), tolerance = 1e-8)
})

test_that("the probit fits (plain and weighted) equal glm(family = binomial('probit'))", {
	f <- fx()
	r <- K("fast_probit_regression_cpp")(f$X, f$yb)
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), unname(coef(glm(f$yb ~ f$X - 1, family = binomial("probit")))), tolerance = 1e-5)
	rw <- K("fast_probit_regression_weighted_cpp")(f$X, f$yb, f$w)
	expect_equal(as.numeric(rw$b), unname(coef(suppressWarnings(glm(f$yb ~ f$X - 1, family = binomial("probit"), weights = f$w)))), tolerance = 1e-4)
})

test_that("Hodges-Lehmann estimators: two-sample median of all pairwise differences; one-sample median of Walsh averages", {
	set.seed(4)
	w <- rep(0:1, each = 15L); y <- c(rnorm(15), rnorm(15, 0.8))
	hl2 <- median(outer(y[w == 1], y[w == 0], "-"))
	expect_equal(K("wilcox_hl_point_estimate_cpp")(w, y), hl2, tolerance = 1e-10)
	expect_equal(K("wilcox_hl_point_estimate_cpp")(w, y), unname(wilcox.test(y[w == 1], y[w == 0], conf.int = TRUE)$estimate), tolerance = 1e-6)
	dy <- rnorm(17, 0.3)
	wa <- outer(dy, dy, "+") / 2
	expect_equal(K("wilcox_hl_signed_rank_point_estimate_cpp")(dy), median(wa[upper.tri(wa, diag = TRUE)]), tolerance = 1e-10)
	expect_equal(K("wilcox_hl_signed_rank_point_estimate_cpp")(dy), unname(wilcox.test(dy, conf.int = TRUE)$estimate), tolerance = 1e-6)
	# Shift equivariance.
	expect_equal(K("wilcox_hl_point_estimate_cpp")(w, y + 5 * w), hl2 + 5, tolerance = 1e-10)
})

test_that("small linear-algebra / moment helpers agree with base R", {
	f <- fx()
	expect_equal(unname(K("eigen_Xt_times_X_cpp")(f$X)), crossprod(f$X), tolerance = 1e-10)
	expect_equal(unname(K("eigen_Xt_times_diag_w_times_X_cpp")(f$X, f$w)), crossprod(f$X * f$w, f$X), tolerance = 1e-10)
	set.seed(5); x <- rnorm(20)
	expect_equal(K("mean_cpp")(x), mean(x), tolerance = 1e-12)
	expect_equal(K("var_cpp")(x), var(x), tolerance = 1e-12)
})

test_that("missingness helpers flag columns with NA and build 0/1 indicators for the chosen columns", {
	df <- data.frame(a = c(1, NA, 3), b = c("x", "y", NA), c = 1:3)
	flags <- K("columns_have_missingness_cpp")(df)
	expect_equal(flags, c(a = TRUE, b = TRUE, c = FALSE))
	ind <- K("create_missingness_indicators_cpp")(df, c(1L, 2L))
	expect_equal(names(ind), c("a_is_missing", "b_is_missing"))
	expect_equal(as.numeric(ind$a_is_missing), c(0, 1, 0))
	expect_equal(as.numeric(ind$b_is_missing), c(0, 0, 1))
})
