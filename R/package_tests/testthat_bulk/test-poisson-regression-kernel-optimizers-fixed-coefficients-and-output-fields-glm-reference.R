library(testthat)
library(EDI)

# fast_poisson_regression_cpp: output fields (mu, XtWX = fisher_information = X'diag(mu)X, score, gradient_norm) recomputed from the
# coefficients; neg_ll is the log-likelihood WITHOUT the log(y!) constant (differences between fits are still exact LR statistics);
# irls / newton_raphson / lbfgs reach the glm MLE (other optimizer names are rejected); fixed coefficients equal glm(offset =);
# estimate_only returns the short field set; maxit = 1 reports the iteration cap. Reference: stats::glm(family = poisson()).

f <- get("fast_poisson_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 200L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
y <- rpois(n, exp(X %*% c(0.2, 0.3, 0.4)))
g <- glm(y ~ X - 1, family = poisson())
b_ref <- unname(coef(g))

test_that("default fit matches glm and its reported fields are consistent with the coefficients", {
	r <- f(X, y)
	expect_equal(r$b, b_ref, tolerance = 1e-8)
	mu <- exp(as.numeric(X %*% r$b))
	expect_equal(as.numeric(r$mu), mu, tolerance = 1e-8)
	expect_equal(unname(r$XtWX), unname(crossprod(X * sqrt(mu))), tolerance = 1e-6)
	expect_equal(r$fisher_information, r$XtWX)
	expect_equal(as.numeric(r$score), as.numeric(t(X) %*% (y - mu)), tolerance = 1e-6, scale = 1)
	expect_lt(max(abs(r$score)), 1e-6); expect_lt(r$gradient_norm, 1e-6)
	expect_true(r$converged); expect_false(r$hit_iteration_cap)
})

test_that("neg_ll drops the log(y!) constant: neg_ll = -sum(y * eta - mu) = -logLik(glm) - sum(lfactorial(y))", {
	r <- f(X, y); eta <- as.numeric(X %*% r$b)
	expect_equal(r$neg_ll, -sum(y * eta - exp(eta)), tolerance = 1e-8)
	expect_equal(r$neg_ll, -as.numeric(logLik(g)) - sum(lfactorial(y)), tolerance = 1e-6)
	r0 <- f(X, y, fixed_idx = 2L, fixed_values = 0)
	expect_equal(2 * (r0$neg_ll - r$neg_ll), as.numeric(2 * (logLik(g) - logLik(glm(y ~ X[, c(1, 3)] - 1, family = poisson())))), tolerance = 1e-6)
})

test_that("irls, newton_raphson and lbfgs reach the glm MLE (lbfgs deterministically); unknown optimizers are rejected", {
	for (alg in c("irls", "newton_raphson")) expect_equal(f(X, y, optimization_alg = alg)$b, b_ref, tolerance = 1e-6, info = alg)
	for (i in 1:10) expect_equal(f(X, y, optimization_alg = "lbfgs")$b, b_ref, tolerance = 1e-4)
	expect_identical(f(X, y, optimization_alg = "lbfgs")$b, f(X, y, optimization_alg = "lbfgs")$b)
	expect_error(f(X, y, optimization_alg = "bfgs"), "optimization_alg must be one of")
})

test_that("fixed coefficients reproduce the profile fit with the fixed term as an offset", {
	for (j in 1:3) {
		r <- f(X, y, fixed_idx = j, fixed_values = 0.5)
		expect_equal(r$b[j], 0.5)
		free <- setdiff(1:3, j)
		ref <- glm(y ~ X[, free] - 1, offset = 0.5 * X[, j], family = poisson())
		expect_equal(r$b[free], unname(coef(ref)), tolerance = 1e-6, info = as.character(j))
	}
})

test_that("estimate_only returns the short field set; maxit = 1 from a cold start reports the iteration cap", {
	e <- f(X, y, estimate_only = TRUE)
	expect_named(e, c("b", "converged", "num_iter", "hit_iteration_cap", "gradient_norm", "min_eigenvalue_information"))
	expect_equal(e$b, f(X, y)$b, tolerance = 1e-8)
	r <- f(X, y, maxit = 1L, smart_cold_start = FALSE)
	expect_equal(r$num_iter, 1L); expect_true(r$hit_iteration_cap); expect_false(r$converged)
})
