library(testthat)
library(EDI)

# fast_poisson_glmm_cpp(X, y, group, j_T, n_gh = ...): with enough Gauss-Hermite nodes the ML fit
# reaches lme4::glmer's optimum (same value of the exact marginal likelihood), the reported
# negative log-likelihood is the full likelihood, ssq_b_T is the (0-based j_T) diagonal of vcov, and
# coarse quadrature visibly moves the estimates (recorded: the default 20 nodes shifts the intercept
# by ~0.07 on this fixture). j_T is a 0-based coefficient index (an out-of-range index gives NaN).

skip_if_not_installed("lme4")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	G <- 12L; g <- rep(seq_len(G), each = 5L)
	X <- cbind(1, rnorm(60)); u <- rnorm(G, 0, 0.6)[g]
	list(X = X, y = as.numeric(rpois(60, exp(X %*% c(0.2, 0.4) + u))), g = as.integer(g), G = G)
}
exact_nll <- function(p, dat) {
	b <- p[1:2]; s <- exp(p[3])
	-sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k
		log(integrate(function(z) vapply(z, function(zz) prod(dpois(dat$y[i], exp(dat$X[i, , drop = FALSE] %*% b + zz))) * dnorm(zz, 0, s), 0),
			-Inf, Inf, rel.tol = 1e-10)$value)
	}, 0))
}

test_that("with 160 nodes the fit equals glmer: coefficients, log sigma, and the exact marginal negative log-likelihood", {
	f <- fx()
	r <- K("fast_poisson_glmm_cpp")(f$X, f$y, f$g, 1L, n_gh = 160L)
	d <- data.frame(y = f$y, x = f$X[, 2], g = factor(f$g))
	m <- suppressMessages(lme4::glmer(y ~ x + (1 | g), family = poisson, data = d, nAGQ = 25))
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), unname(lme4::fixef(m)), tolerance = 2e-2, ignore_attr = TRUE)
	expect_equal(as.numeric(r$b)[2], unname(lme4::fixef(m))[2], tolerance = 1e-3)
	expect_equal(as.numeric(r$log_sigma), log(as.data.frame(lme4::VarCorr(m))$sdcor), tolerance = 2e-2)
	p_pkg <- c(as.numeric(r$b), as.numeric(r$log_sigma))
	expect_equal(as.numeric(r$neg_loglik), exact_nll(p_pkg, f), tolerance = 1e-6)
	# The package optimum is at least as good as glmer's own solution on the exact likelihood.
	p_glmer <- c(unname(lme4::fixef(m)), log(as.data.frame(lme4::VarCorr(m))$sdcor))
	expect_lte(exact_nll(p_pkg, f), exact_nll(p_glmer, f) + 1e-4)
})

test_that("ssq_b_T is vcov[j_T + 1, j_T + 1] for a 0-based j_T, and NaN for an out-of-range index", {
	f <- fx()
	r <- K("fast_poisson_glmm_cpp")(f$X, f$y, f$g, 1L)
	expect_equal(r$ssq_b_T, r$vcov[2, 2])
	r0 <- K("fast_poisson_glmm_cpp")(f$X, f$y, f$g, 0L)
	expect_equal(r0$ssq_b_T, r0$vcov[1, 1])
	expect_true(is.nan(K("fast_poisson_glmm_cpp")(f$X, f$y, f$g, 2L)$ssq_b_T))
	expect_true(all(is.finite(diag(r$vcov))) && all(diag(r$vcov) > 0))
})

test_that("coarse quadrature moves the estimates: the intercept error shrinks from 10 to 80 nodes", {
	f <- fx()
	fit <- function(ng) as.numeric(K("fast_poisson_glmm_cpp")(f$X, f$y, f$g, 1L, n_gh = ng)$b)
	ref <- fit(160L)
	e10 <- abs(fit(10L)[1] - ref[1]); e80 <- abs(fit(80L)[1] - ref[1])
	expect_gt(e10, 0.05)
	expect_lt(e80, 0.005)
	expect_lt(e80, e10)
})
