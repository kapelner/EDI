library(testthat)
library(EDI)

# get_logistic_glmm_neg_loglik_cpp / _score_cpp / _hessian_cpp (random-intercept logistic model,
# params = [beta, log sigma], adaptive-free Gauss-Hermite with n_gh nodes). References: the
# marginal likelihood evaluated group by group with integrate(), and numDeriv of it. The
# neg-loglik, score, and full Hessian (including the log-sigma row/column) agree.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	G <- 12L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n))
	u <- rnorm(G, 0, 0.8)[g]
	y <- rbinom(n, 1, plogis(X %*% c(-0.2, 0.7) + u))
	list(X = X, y = as.numeric(y), g = as.integer(g), G = G)
}
hand_nll <- function(p, dat) {
	b <- p[1:2]; s <- exp(p[3])
	-sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k
		log(integrate(function(z) vapply(z, function(zz) prod(dbinom(dat$y[i], 1, plogis(dat$X[i, , drop = FALSE] %*% b + zz))) * dnorm(zz, 0, s), 0),
			-Inf, Inf, rel.tol = 1e-10)$value)
	}, 0))
}
p0 <- c(-0.1, 0.5, log(0.7))

test_that("the negative log-likelihood equals the per-group marginal-likelihood integral", {
	f <- fx()
	expect_equal(K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, p0), hand_nll(p0, f), tolerance = 1e-6)
	p1 <- c(-0.5, 1.1, log(1.3))
	expect_equal(K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, p1), hand_nll(p1, f), tolerance = 1e-6)
})

test_that("the quadrature order is not a material source of error beyond 20 nodes", {
	f <- fx()
	a <- K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, p0, 20L)
	b <- K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, p0, 40L)
	expect_equal(a, b, tolerance = 1e-8)
})

test_that("the score is the gradient of the log-likelihood (minus the neg-loglik gradient)", {
	f <- fx()
	expect_equal(K("get_logistic_glmm_score_cpp")(f$X, f$y, f$g, p0), -numDeriv::grad(hand_nll, p0, dat = f), tolerance = 1e-5)
})

test_that("the full Hessian equals the score Jacobian and numeric log-likelihood Hessian", {
	f <- fx()
	h <- K("get_logistic_glmm_hessian_cpp")(f$X, f$y, f$g, p0)
	hn <- -numDeriv::hessian(hand_nll, p0, dat = f)
	jac <- numDeriv::jacobian(function(p) K("get_logistic_glmm_score_cpp")(f$X, f$y, f$g, p), p0)
	expect_equal(unname(h), unname(hn), tolerance = 1e-4)
	expect_equal(unname(h), unname(jac), tolerance = 1e-4)
	expect_equal(unname(h), unname(t(h)), tolerance = 1e-8)
})
