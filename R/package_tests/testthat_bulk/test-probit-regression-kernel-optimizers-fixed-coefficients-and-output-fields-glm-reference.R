library(testthat)
library(EDI)

# fast_probit_regression_cpp: output fields (w, fisher_information, score, neg_ll, gradient_norm) recomputed from
# the returned coefficients; irls/newton/bfgs reach the glm
# probit MLE; fixed_idx/fixed_values (1-based) equal the profile fit glm(offset = ...); estimate_only returns the
# short field set. Reference: stats::glm(family = binomial("probit")).
# Regression: optimization_alg = "lbfgs" used to return different (up to ~0.14 off) coefficients on identical calls and
# NaN neg_ll / gradient_norm because its objective held a dangling Eigen::Ref to a temporary row-major copy of X; the
# objective now owns its matrix. min_eigenvalue_information is NaN by design (the diagnostic is disabled in v1.0.0).

f <- get("fast_probit_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 200L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
y <- rbinom(n, 1, pnorm(X %*% c(-0.2, 0.7, 0.4)))
g <- glm(y ~ X - 1, family = binomial("probit"))
b_ref <- unname(coef(g))

test_that("default fit matches glm and its reported fields are consistent with the coefficients", {
	r <- f(X, y)
	expect_equal(r$b, b_ref, tolerance = 1e-5)
	eta <- as.numeric(X %*% r$b); phi <- dnorm(eta); Phi <- pnorm(eta)
	w <- phi^2 / (Phi * (1 - Phi))
	expect_equal(r$w, w, tolerance = 1e-8)
	expect_equal(unname(r$fisher_information), unname(crossprod(X * sqrt(w))), tolerance = 1e-6)
	expect_equal(r$neg_ll, -sum(dbinom(y, 1, Phi, log = TRUE)), tolerance = 1e-8)
	expect_equal(r$neg_ll, -as.numeric(logLik(g)), tolerance = 1e-5)
	score <- as.numeric(t(X) %*% (phi * (y - Phi) / (Phi * (1 - Phi))))
	expect_equal(as.numeric(r$score), score, tolerance = 1e-6, scale = 1)
	expect_lt(max(abs(score)), 1e-4)
	expect_true(r$converged); expect_false(r$hit_iteration_cap)
})

test_that("irls, newton, bfgs and lbfgs (cold, no smart start, warm) agree with the glm MLE and lbfgs is deterministic", {
	for (alg in c("irls", "newton", "bfgs")) expect_equal(f(X, y, optimization_alg = alg)$b, b_ref, tolerance = 1e-4, info = alg)
	for (i in 1:15) {
		expect_equal(f(X, y, optimization_alg = "lbfgs")$b, b_ref, tolerance = 1e-4)
		expect_equal(f(X, y, optimization_alg = "lbfgs", smart_cold_start = FALSE)$b, b_ref, tolerance = 1e-4)
		expect_equal(f(X, y, optimization_alg = "lbfgs", warm_start_beta = b_ref)$b, b_ref, tolerance = 1e-4)
	}
	r <- f(X, y, optimization_alg = "lbfgs")
	expect_true(is.finite(r$neg_ll)); expect_true(is.finite(r$gradient_norm))
	expect_equal(r$neg_ll, -as.numeric(logLik(g)), tolerance = 1e-6)
	expect_identical(f(X, y, optimization_alg = "lbfgs")$b, f(X, y, optimization_alg = "lbfgs")$b)
	expect_true(is.nan(f(X, y)$min_eigenvalue_information))       # documented: diagnostic disabled, not computed
})

test_that("fixed coefficients reproduce the profile fit with the fixed term as an offset", {
	for (j in 1:3) {
		r <- f(X, y, fixed_idx = j, fixed_values = 0.5)
		expect_equal(r$b[j], 0.5)
		free <- setdiff(1:3, j)
		ref <- glm(y ~ X[, free] - 1, offset = 0.5 * X[, j], family = binomial("probit"))
		expect_equal(r$b[free], unname(coef(ref)), tolerance = 1e-4, info = j)
		expect_equal(r$neg_ll, -as.numeric(logLik(ref)), tolerance = 1e-5, info = j)
	}
	r2 <- f(X, y, fixed_idx = c(1L, 3L), fixed_values = c(0, 0))
	expect_equal(r2$b[c(1, 3)], c(0, 0))
	expect_equal(r2$b[2], unname(coef(glm(y ~ X[, 2] - 1, family = binomial("probit")))), tolerance = 1e-4)
})

test_that("estimate_only returns the short field set with the same coefficients", {
	r <- f(X, y, estimate_only = TRUE)
	expect_named(r, c("b", "converged", "num_iter", "hit_iteration_cap", "gradient_norm", "min_eigenvalue_information"))
	expect_equal(r$b, f(X, y)$b, tolerance = 1e-8)
})
