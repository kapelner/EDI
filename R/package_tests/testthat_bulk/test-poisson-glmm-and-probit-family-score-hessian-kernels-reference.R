library(testthat)
library(EDI)

# C++ kernels: get_poisson_glmm_score_cpp / _hessian_cpp (random-intercept Poisson, params = beta,
# log sigma, Gauss-Hermite with n_gh nodes) against numDeriv of the group-by-group marginal
# likelihood integral; get_probit_regression_score_cpp and the ordinal-probit score / Hessian against
# numDeriv of hand-written log-likelihoods. Quadrature accuracy: the GLMM kernels converge to the
# integral as n_gh grows (n_gh = 80 agrees to ~1e-6; the default 20 nodes is visibly less accurate on
# this count fixture -- recorded, not asserted).

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

pg_fixture <- function() {
	set.seed(4)
	G <- 12L; g <- rep(seq_len(G), each = 5L)
	X <- cbind(1, rnorm(60)); u <- rnorm(G, 0, 0.6)[g]
	list(X = X, y = as.numeric(rpois(60, exp(X %*% c(0.2, 0.4) + u))), g = as.integer(g), G = G)
}
pg_nll <- function(p, dat) {
	b <- p[1:2]; s <- exp(p[3])
	-sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k
		log(integrate(function(z) vapply(z, function(zz) prod(dpois(dat$y[i], exp(dat$X[i, , drop = FALSE] %*% b + zz))) * dnorm(zz, 0, s), 0),
			-Inf, Inf, rel.tol = 1e-10)$value)
	}, 0))
}
q0 <- c(0.1, 0.3, log(0.5))

test_that("Poisson GLMM score and Hessian equal numeric derivatives of the marginal likelihood at high quadrature order", {
	f <- pg_fixture()
	expect_equal(K("get_poisson_glmm_score_cpp")(f$X, f$y, f$g, q0, 80L), -numDeriv::grad(pg_nll, q0, dat = f), tolerance = 1e-5)
	h <- K("get_poisson_glmm_hessian_cpp")(f$X, f$y, f$g, q0, 80L)
	expect_equal(unname(h), -numDeriv::hessian(pg_nll, q0, dat = f), tolerance = 1e-4)
	expect_equal(unname(h), unname(t(h)), tolerance = 1e-8)
})

test_that("the quadrature error of the score shrinks as the node count grows", {
	f <- pg_fixture()
	ref <- -numDeriv::grad(pg_nll, q0, dat = f)
	err <- vapply(c(20L, 40L, 80L), function(ng) max(abs(K("get_poisson_glmm_score_cpp")(f$X, f$y, f$g, q0, ng) - ref)), 0)
	expect_true(err[2] < err[1] && err[3] < err[2])
	expect_lt(err[3], 1e-4)
})

test_that("probit score equals the numeric gradient", {
	set.seed(5)
	n <- 150L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	y <- as.numeric(rbinom(n, 1, pnorm(X %*% c(-0.1, 0.5, 0.3))))
	ll <- function(b) { p <- pnorm(X %*% b); sum(y * log(p) + (1 - y) * log(1 - p)) }
	b0 <- c(0.1, 0.2, -0.1)
	expect_equal(K("get_probit_regression_score_cpp")(X, y, b0), numDeriv::grad(ll, b0), tolerance = 1e-6)
})

test_that("ordinal-probit score and Hessian equal numeric derivatives (params = thresholds, coefficients)", {
	set.seed(5)
	n <- 150L
	X <- cbind(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
	y <- as.integer(cut(0.6 * X[, 1] - 0.4 * X[, 2] + rnorm(n), c(-Inf, -1, 0.3, 1.4, Inf)))
	ll <- function(p) {
		a <- p[1:3]; b <- p[4:5]; eta <- drop(X %*% b)
		cdf <- cbind(0, vapply(a, function(t) pnorm(t - eta), numeric(n)), 1)
		sum(log(cdf[cbind(seq_len(n), y + 1L)] - cdf[cbind(seq_len(n), y)]))
	}
	p0 <- c(-1, 0.3, 1.4, 0.5, -0.3)
	expect_equal(K("get_ordinal_probit_regression_score_cpp")(X, y, p0), numDeriv::grad(ll, p0), tolerance = 1e-6)
	h <- K("get_ordinal_probit_regression_hessian_cpp")(X, y, p0)
	expect_equal(unname(h), numDeriv::hessian(ll, p0), tolerance = 1e-4)
	expect_equal(unname(h), unname(t(h)), tolerance = 1e-8)
})
