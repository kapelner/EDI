library(testthat)
library(EDI)

# Gaussian random-intercept LMM kernels for KK designs (matched pairs + reservoir singletons):
# get_gaussian_lmm_score_cpp / get_gaussian_lmm_fisher_cpp (params = beta, log sigma_e, log sigma_b),
# fast_gaussian_lmm_gls_cpp (GLS coefficients at fixed variance components) and fast_gaussian_lmm_cpp
# (ML fit). References: the marginal multivariate-normal likelihood written out per group (numDeriv
# score), the GLS normal equations, and lme4::lmer(REML = FALSE).

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	G <- 30L
	m <- c(rep(2L, 20L), rep(1L, 10L))
	g <- rep(seq_len(G), times = m); n <- length(g)
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	u <- rnorm(G, 0, 0.8)[g]
	y <- as.numeric(X %*% c(1, 0.5, -0.3) + u + rnorm(n, 0, 0.6))
	list(X = X, y = y, g = as.integer(g), G = G, n = n)
}
group_sigma <- function(k, dat, se, sb) { i <- dat$g == k; se^2 * diag(sum(i)) + sb^2 * matrix(1, sum(i), sum(i)) }
loglik <- function(p, dat) {
	b <- p[1:3]; se <- exp(p[4]); sb <- exp(p[5]); r <- dat$y - dat$X %*% b
	sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k; Sg <- group_sigma(k, dat, se, sb)
		as.numeric(-0.5 * (determinant(Sg)$modulus + t(r[i]) %*% solve(Sg) %*% r[i] + sum(i) * log(2 * pi)))
	}, 0))
}

test_that("the score is the gradient of the marginal log-likelihood", {
	f <- fx(); p0 <- c(0.9, 0.4, -0.2, log(0.7), log(0.9))
	expect_equal(K("get_gaussian_lmm_score_cpp")(f$X, f$y, f$g, p0), numDeriv::grad(loglik, p0, dat = f), tolerance = 1e-5)
})

test_that("the Fisher matrix has the GLS information X' V^-1 X in its beta block, is symmetric and positive definite", {
	f <- fx(); p0 <- c(0.9, 0.4, -0.2, log(0.7), log(0.9))
	fi <- K("get_gaussian_lmm_fisher_cpp")(f$X, f$y, f$g, p0)
	A <- Reduce(`+`, lapply(seq_len(f$G), function(k) {
		i <- f$g == k; Si <- solve(group_sigma(k, f, exp(p0[4]), exp(p0[5])))
		t(f$X[i, , drop = FALSE]) %*% Si %*% f$X[i, , drop = FALSE]
	}))
	expect_equal(unname(fi[1:3, 1:3]), unname(A), tolerance = 1e-4)
	expect_equal(unname(fi), unname(t(fi)), tolerance = 1e-6)
	expect_true(all(eigen(fi, symmetric = TRUE)$values > 0))
})

test_that("GLS coefficients at fixed variance components solve the generalized normal equations", {
	f <- fx()
	se <- 0.7; sb <- 0.9
	A <- matrix(0, 3, 3); bv <- numeric(3)
	for (k in seq_len(f$G)) {
		i <- f$g == k; Si <- solve(group_sigma(k, f, se, sb)); Xi <- f$X[i, , drop = FALSE]
		A <- A + t(Xi) %*% Si %*% Xi; bv <- bv + t(Xi) %*% Si %*% f$y[i]
	}
	gl <- K("fast_gaussian_lmm_gls_cpp")(f$X, f$y, f$g, log(se), log(sb))
	expect_equal(as.numeric(gl), as.numeric(solve(A, bv)), tolerance = 1e-8)
})

test_that("the ML fit equals lme4::lmer(REML = FALSE): coefficients, variance components, log-likelihood, treatment-slope variance", {
	skip_if_not_installed("lme4")
	f <- fx()
	r <- K("fast_gaussian_lmm_cpp")(f$X, f$y, f$g)
	d <- data.frame(y = f$y, x1 = f$X[, 2], x2 = f$X[, 3], g = factor(f$g))
	fit <- suppressMessages(lme4::lmer(y ~ x1 + x2 + (1 | g), data = d, REML = FALSE))
	expect_true(r$converged)
	expect_equal(as.numeric(r$b)[1:3], unname(lme4::fixef(fit)), tolerance = 2e-3)
	expect_equal(exp(as.numeric(r$params)[4:5]), rev(as.data.frame(lme4::VarCorr(fit))$sdcor), tolerance = 2e-3)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(fit)), tolerance = 1e-5)
	expect_equal(sqrt(as.numeric(r$vcov[2, 2])), sqrt(as.matrix(vcov(fit))[2, 2]), tolerance = 5e-3)
	# The score vanishes at the ML solution.
	expect_lt(max(abs(K("get_gaussian_lmm_score_cpp")(f$X, f$y, f$g, as.numeric(r$params)))), 5e-2)
})

test_that("groups larger than a pair are rejected", {
	f <- fx()
	expect_error(K("fast_gaussian_lmm_cpp")(f$X, f$y, as.integer(rep(1:10, each = 6L)[seq_len(f$n)])), "only matched pairs")
})
