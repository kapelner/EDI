library(testthat)
library(EDI)

# fast_logistic_glmm_cpp(X, y, group, j_T, ...): a warm start at lme4::glmer's optimum recovers the
# exact ML solution (coefficients, log sigma, negative log-likelihood, standard errors). The
# deterministic log-sigma multistart must make the default L-BFGS and Newton fits select that same
# finite basin instead of accepting a lower-variance local optimum.

skip_if_not_installed("lme4")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	G <- 40L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n)); u <- rnorm(G, 0, 0.9)[g]
	y <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.2, 0.7) + u)))
	d <- data.frame(y = y, x = X[, 2], g = factor(g))
	m1 <- suppressWarnings(suppressMessages(lme4::glmer(y ~ x + (1 | g), family = binomial, data = d, nAGQ = 25)))
	list(X = X, y = y, g = as.integer(g), glmer = m1,
		p_glmer = c(unname(lme4::fixef(m1)), log(as.data.frame(lme4::VarCorr(m1))$sdcor)))
}

test_that("started at glmer's optimum, the fit stays there: same estimates, log sigma, likelihood and standard errors", {
	f <- fx()
	r <- K("fast_logistic_glmm_cpp")(f$X, f$y, f$g, 1L, n_gh = 40L, warm_start_params = f$p_glmer)
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), f$p_glmer[1:2], tolerance = 2e-3)
	expect_equal(as.numeric(r$log_sigma), f$p_glmer[3], tolerance = 2e-2)
	ref_nll <- K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, f$p_glmer, 40L)
	expect_equal(as.numeric(r$neg_loglik), ref_nll, tolerance = 1e-3)
	expect_equal(sqrt(diag(r$vcov))[1:2], unname(sqrt(diag(as.matrix(vcov(f$glmer)))))[1:2], tolerance = 0.15)
	# The score is small at the solution.
	expect_lt(max(abs(K("get_logistic_glmm_score_cpp")(f$X, f$y, f$g, c(as.numeric(r$b), as.numeric(r$log_sigma)), 40L)[1:2])), 0.5)
})

test_that("the Newton optimizer reaches essentially the ML likelihood from the smart cold start", {
	f <- fx()
	ref_nll <- K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, f$p_glmer, 40L)
	r <- K("fast_logistic_glmm_cpp")(f$X, f$y, f$g, 1L, n_gh = 40L, optimization_alg = "newton")
	expect_lt(as.numeric(r$neg_loglik) - ref_nll, 0.5)
	expect_gt(as.numeric(r$log_sigma), -1)
})

test_that("the default cold-start fit selects the glmer likelihood basin with finite covariance", {
	f <- fx()
	ref_nll <- K("get_logistic_glmm_neg_loglik_cpp")(f$X, f$y, f$g, f$p_glmer, 40L)
	r <- K("fast_logistic_glmm_cpp")(f$X, f$y, f$g, 1L, n_gh = 40L)
	expect_true(r$converged)
	expect_gt(as.numeric(r$log_sigma), -1)
	expect_equal(as.numeric(r$neg_loglik), ref_nll, tolerance = 1e-3)
	expect_true(all(is.finite(diag(r$vcov))))
	expect_true(all(diag(r$vcov) > 0))
})
