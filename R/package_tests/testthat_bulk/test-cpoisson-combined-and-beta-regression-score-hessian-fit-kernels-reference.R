library(testthat)
library(EDI)

# Direct C++ kernels of (1) the combined KK conditional-Poisson (pair Binomial) + reservoir
# Poisson likelihood -- get_cpoisson_combined_score_cpp / _hessian_cpp and
# fast_cpoisson_combined_with_var_cpp -- and (2) beta regression (logit mean, log precision):
# get_beta_regression_score_cpp / _hessian_cpp. References: hand-written log-likelihoods,
# numDeriv derivatives and a derivative-free optimum, including the variance of the treatment
# coefficient and the fixed-parameter mode.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

cp_fixture <- function() {
	set.seed(8)
	Kp <- 25L; nr <- 40L
	Xd <- matrix(rnorm(Kp * 2), Kp, 2); nk <- rpois(Kp, 4) + 1L
	yT <- rbinom(Kp, nk, plogis(0.3 + Xd %*% c(0.2, -0.1)))
	Xr <- matrix(rnorm(nr * 2), nr, 2); wr <- rbinom(nr, 1, 0.5)
	yr <- rpois(nr, exp(0.5 + 0.3 * wr + Xr %*% c(0.2, -0.1)))
	list(yT = as.numeric(yT), nk = as.numeric(nk), Xd = Xd, yr = as.numeric(yr), wr = as.numeric(wr), Xr = Xr)
}
cp_ll <- function(p, d) {
	b0 <- p[1]; bT <- p[2]; bx <- p[3:4]
	sum(dbinom(d$yT, d$nk, plogis(bT + d$Xd %*% bx), log = TRUE)) +
		sum(dpois(d$yr, exp(b0 + bT * d$wr + d$Xr %*% bx), log = TRUE))
}
cp_call <- function(fn, d, p, ...) K(fn)(d$yT, d$nk, d$Xd, d$yr, d$wr, d$Xr, p, ...)

test_that("combined conditional-Poisson score and Hessian equal numeric derivatives of the pair + reservoir log-likelihood", {
	d <- cp_fixture()
	p0 <- c(0.4, 0.25, 0.1, -0.05)
	expect_equal(cp_call("get_cpoisson_combined_score_cpp", d, p0), numDeriv::grad(cp_ll, p0, d = d), tolerance = 1e-6)
	h <- cp_call("get_cpoisson_combined_hessian_cpp", d, p0)
	expect_equal(unname(h), numDeriv::hessian(cp_ll, p0, d = d), tolerance = 1e-5)
	expect_equal(unname(h), unname(t(h)))
})

test_that("the combined fit reaches the derivative-free MLE and reports the treatment-coefficient variance", {
	d <- cp_fixture()
	r <- K("fast_cpoisson_combined_with_var_cpp")(d$yT, d$nk, d$Xd, d$yr, d$wr, d$Xr)
	o <- optim(c(0.4, 0.2, 0, 0), function(p) -cp_ll(p, d), method = "BFGS", control = list(reltol = 1e-14))
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), o$par, tolerance = 1e-5)
	# The kernel's log-likelihood omits only the parameter-free binomial coefficients of the pair component
	# (the reservoir Poisson part keeps its -log(y!) term).
	const <- sum(lchoose(d$nk, d$yT))
	expect_equal(as.numeric(r$loglik), cp_ll(o$par, d) - const, tolerance = 1e-6)
	expect_equal(as.numeric(r$neg_loglik), -(cp_ll(o$par, d) - const), tolerance = 1e-6)
	# ssq_b_j is the (2, 2) element of the inverse information (beta_T).
	info <- -numDeriv::hessian(cp_ll, o$par, d = d)
	expect_equal(as.numeric(r$ssq_b_j), solve(info)[2, 2], tolerance = 1e-4)
	expect_lt(max(abs(cp_call("get_cpoisson_combined_score_cpp", d, as.numeric(r$b)))), 1e-4)
})

test_that("fixing a parameter holds it and gives the constrained optimum for the rest; ssq_b_j is NA when beta_T is fixed", {
	d <- cp_fixture()
	r <- K("fast_cpoisson_combined_with_var_cpp")(d$yT, d$nk, d$Xd, d$yr, d$wr, d$Xr, fixed_idx = 3L, fixed_values = 0.1)
	expect_equal(as.numeric(r$b)[3], 0.1)
	o <- optim(c(0.4, 0.2, -0.05), function(q) -cp_ll(c(q[1], q[2], 0.1, q[3]), d), method = "BFGS", control = list(reltol = 1e-14))
	expect_equal(as.numeric(r$b)[-3], o$par, tolerance = 1e-4)
	fT <- K("fast_cpoisson_combined_with_var_cpp")(d$yT, d$nk, d$Xd, d$yr, d$wr, d$Xr, fixed_idx = 2L, fixed_values = 0.2)
	expect_equal(as.numeric(fT$b)[2], 0.2)
	expect_true(is.na(fT$ssq_b_j))
})

test_that("beta-regression score and Hessian (params = coefficients, log precision) equal numeric derivatives", {
	set.seed(3)
	n <- 100L
	X <- cbind(1, rnorm(n)); mu <- plogis(X %*% c(0.2, 0.5)); phi <- 8
	y <- rbeta(n, mu * phi, (1 - mu) * phi)
	ll <- function(p) { m <- plogis(X %*% p[1:2]); ph <- exp(p[3]); sum(dbeta(y, m * ph, (1 - m) * ph, log = TRUE)) }
	p0 <- c(0.1, 0.4, log(6))
	expect_equal(K("get_beta_regression_score_cpp")(X, y, p0), numDeriv::grad(ll, p0), tolerance = 1e-6)
	h <- K("get_beta_regression_hessian_cpp")(X, y, p0)
	expect_equal(unname(h), numDeriv::hessian(ll, p0), tolerance = 1e-5)
	expect_equal(unname(h), unname(t(h)))
})
