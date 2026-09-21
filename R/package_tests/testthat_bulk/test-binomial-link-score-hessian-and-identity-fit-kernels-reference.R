library(testthat)
library(EDI)

# Direct C++ kernels of the log- and identity-link binomial regressions:
# get_{log,identity}_binomial_regression_{score,hessian} and their weighted versions against
# numDeriv of the hand-written Bernoulli log-likelihood, plus
# fast_identity_binomial_regression_cpp() (plain, weighted, fixed coefficient) against a
# derivative-free optimum and the expected Fisher information X' diag(w / (mu (1 - mu))) X.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(3)
	n <- 80L
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	b <- c(-1.2, -0.3, -0.2)
	y <- rbinom(n, 1, pmin(exp(X %*% b), 0.95))
	list(X = X, y = y, w = rexp(n), n = n, b_log = b, b_id = c(0.2, 0.1, 0.05))
}
ll_link <- function(link) function(b, X, y, w) {
	m <- if (link == "log") exp(X %*% b) else X %*% b
	sum(w * (y * log(m) + (1 - y) * log(1 - m)))
}

test_that("log-link score and Hessian (unweighted and weighted) equal numeric derivatives of the log-likelihood", {
	f <- fx(); ll <- ll_link("log"); one <- rep(1, f$n)
	expect_equal(K("get_log_binomial_regression_score_cpp")(f$X, f$y, f$b_log),
		numDeriv::grad(ll, f$b_log, X = f$X, y = f$y, w = one), tolerance = 1e-6)
	expect_equal(unname(K("get_log_binomial_regression_hessian_cpp")(f$X, f$y, f$b_log)),
		numDeriv::hessian(ll, f$b_log, X = f$X, y = f$y, w = one), tolerance = 1e-5)
	expect_equal(K("get_log_binomial_regression_weighted_score_cpp")(f$X, f$y, f$w, f$b_log),
		numDeriv::grad(ll, f$b_log, X = f$X, y = f$y, w = f$w), tolerance = 1e-6)
	expect_equal(unname(K("get_log_binomial_regression_weighted_hessian_cpp")(f$X, f$y, f$w, f$b_log)),
		numDeriv::hessian(ll, f$b_log, X = f$X, y = f$y, w = f$w), tolerance = 1e-5)
	# Unit weights reproduce the unweighted kernels; the Hessian is symmetric.
	expect_equal(K("get_log_binomial_regression_weighted_score_cpp")(f$X, f$y, one, f$b_log),
		K("get_log_binomial_regression_score_cpp")(f$X, f$y, f$b_log))
	h <- K("get_log_binomial_regression_hessian_cpp")(f$X, f$y, f$b_log)
	expect_equal(unname(h), unname(t(h)))
})

test_that("identity-link score and Hessian (unweighted and weighted) equal numeric derivatives", {
	f <- fx(); ll <- ll_link("identity"); one <- rep(1, f$n)
	expect_equal(K("get_identity_binomial_regression_score_cpp")(f$X, f$y, f$b_id),
		numDeriv::grad(ll, f$b_id, X = f$X, y = f$y, w = one), tolerance = 1e-6)
	expect_equal(unname(K("get_identity_binomial_regression_hessian_cpp")(f$X, f$y, f$b_id)),
		numDeriv::hessian(ll, f$b_id, X = f$X, y = f$y, w = one), tolerance = 1e-4)
	expect_equal(K("get_identity_binomial_regression_weighted_score_cpp")(f$X, f$y, f$w, f$b_id),
		numDeriv::grad(ll, f$b_id, X = f$X, y = f$y, w = f$w), tolerance = 1e-6)
	expect_equal(unname(K("get_identity_binomial_regression_weighted_hessian_cpp")(f$X, f$y, f$w, f$b_id)),
		numDeriv::hessian(ll, f$b_id, X = f$X, y = f$y, w = f$w), tolerance = 1e-4)
})

id_fixture <- function() {
	set.seed(9)
	n <- 300L
	X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
	y <- rbinom(n, 1, pmin(pmax(0.45 + 0.1 * X[, 2] + 0.05 * X[, 3], 0.05), 0.95))
	list(X = X, y = y, w = rexp(n), n = n)
}
opt_id <- function(f, w, fixed = NULL) {
	ll <- function(b) {
		bb <- if (is.null(fixed)) b else { v <- numeric(3); v[fixed$idx] <- fixed$val; v[-fixed$idx] <- b; v }
		m <- f$X %*% bb
		if (any(m <= 0 | m >= 1)) return(-1e10)
		sum(w * (f$y * log(m) + (1 - f$y) * log(1 - m)))
	}
	start <- if (is.null(fixed)) c(0.45, 0.1, 0.05) else c(0.45, 0.05)
	optim(start, ll, method = "Nelder-Mead", control = list(fnscale = -1, reltol = 1e-14, maxit = 5000))$par
}

test_that("the identity-link fit reaches the derivative-free optimum, converges, and reports the expected Fisher information", {
	f <- id_fixture()
	r <- K("fast_identity_binomial_regression_cpp")(f$X, f$y)
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), opt_id(f, rep(1, f$n)), tolerance = 1e-5)
	mu <- as.numeric(f$X %*% r$b)
	expect_equal(unname(r$fisher_information), unname(crossprod(f$X / sqrt(mu * (1 - mu)))), tolerance = 1e-5)
	expect_equal(as.numeric(r$mu_hat), mu, tolerance = 1e-8)
})

test_that("the weighted identity-link fit reaches the weighted optimum", {
	f <- id_fixture()
	r <- K("fast_identity_binomial_regression_weighted_cpp")(f$X, f$y, f$w)
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), opt_id(f, f$w), tolerance = 1e-5)
	mu <- as.numeric(f$X %*% r$b)
	expect_equal(unname(r$fisher_information), unname(crossprod(f$X * sqrt(f$w / (mu * (1 - mu))))), tolerance = 1e-5)
})

test_that("a fixed coefficient is honoured and the remaining ones are the constrained optimum", {
	f <- id_fixture()
	r <- K("fast_identity_binomial_regression_cpp")(f$X, f$y, fixed_idx = 2L, fixed_values = 0.1)
	expect_equal(as.numeric(r$b)[2], 0.1)
	expect_equal(as.numeric(r$b)[-2], opt_id(f, rep(1, f$n), list(idx = 2L, val = 0.1)), tolerance = 1e-4)
})
