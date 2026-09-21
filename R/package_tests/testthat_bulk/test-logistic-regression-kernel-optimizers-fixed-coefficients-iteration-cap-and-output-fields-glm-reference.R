library(testthat)
library(EDI)

# fast_logistic_regression_cpp: output fields (w = mu(1 - mu), fisher_information = X'WX, score ~ 0, neg_ll, gradient_norm)
# recomputed from the returned coefficients; irls / newton / bfgs / lbfgs all reach the glm MLE (lbfgs deterministically);
# fixed_idx / fixed_values equal glm(offset =); estimate_only returns the short field set; maxit = 1 reports the iteration cap.
# Reference: stats::glm(family = binomial()).

f <- get("fast_logistic_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 200L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
y <- rbinom(n, 1, plogis(X %*% c(-0.2, 0.7, 0.4)))
g <- glm(y ~ X - 1, family = binomial())
b_ref <- unname(coef(g))

test_that("default fit matches glm and its reported fields are consistent with the coefficients", {
	r <- f(X, y)
	expect_equal(r$b, b_ref, tolerance = 1e-6)
	mu <- plogis(as.numeric(X %*% r$b)); w <- mu * (1 - mu)
	expect_equal(r$w, w, tolerance = 1e-8)
	expect_equal(unname(r$fisher_information), unname(crossprod(X * sqrt(w))), tolerance = 1e-6)
	expect_equal(r$neg_ll, -sum(dbinom(y, 1, mu, log = TRUE)), tolerance = 1e-8)
	expect_equal(r$neg_ll, -as.numeric(logLik(g)), tolerance = 1e-6)
	expect_equal(as.numeric(r$score), as.numeric(t(X) %*% (y - mu)), tolerance = 1e-6, scale = 1)
	expect_lt(max(abs(r$score)), 1e-5)
	expect_true(r$converged); expect_false(r$hit_iteration_cap); expect_lt(r$gradient_norm, 1e-5)
})

test_that("all optimizers reach the glm MLE; lbfgs is deterministic across repeated cold and warm calls", {
	for (alg in c("irls", "newton", "bfgs")) expect_equal(f(X, y, optimization_alg = alg)$b, b_ref, tolerance = 1e-6, info = alg)
	for (i in 1:10) {
		expect_equal(f(X, y, optimization_alg = "lbfgs")$b, b_ref, tolerance = 1e-4)
		expect_equal(f(X, y, optimization_alg = "lbfgs", smart_cold_start = TRUE)$b, b_ref, tolerance = 1e-4)
		expect_equal(f(X, y, optimization_alg = "lbfgs", warm_start_beta = b_ref)$b, b_ref, tolerance = 1e-4)
	}
	a <- f(X, y, optimization_alg = "lbfgs")
	expect_identical(a$b, f(X, y, optimization_alg = "lbfgs")$b)
	expect_true(is.finite(a$neg_ll)); expect_equal(a$neg_ll, -as.numeric(logLik(g)), tolerance = 1e-6)
})

test_that("fixed coefficients reproduce the profile fit with the fixed term as an offset", {
	for (j in 1:3) {
		r <- f(X, y, fixed_idx = j, fixed_values = 0.5)
		expect_equal(r$b[j], 0.5)
		free <- setdiff(1:3, j)
		ref <- glm(y ~ X[, free] - 1, offset = 0.5 * X[, j], family = binomial())
		expect_equal(r$b[free], unname(coef(ref)), tolerance = 1e-6, info = as.character(j))
		expect_equal(r$neg_ll, -as.numeric(logLik(ref)), tolerance = 1e-6, info = as.character(j))
	}
	r2 <- f(X, y, fixed_idx = c(1L, 3L), fixed_values = c(0, 0))
	expect_equal(r2$b[c(1, 3)], c(0, 0))
	expect_equal(r2$b[2], unname(coef(glm(y ~ X[, 2] - 1, family = binomial()))), tolerance = 1e-6)
})

test_that("warm start at the optimum converges immediately and estimate_only returns the short field set", {
	r <- f(X, y, warm_start_beta = b_ref)
	expect_lte(r$num_iter, 2L)
	e <- f(X, y, estimate_only = TRUE)
	expect_true(all(c("b", "converged", "num_iter", "hit_iteration_cap", "gradient_norm") %in% names(e)))
	expect_false(any(c("w", "fisher_information", "score", "neg_ll") %in% names(e)))
	expect_equal(e$b, f(X, y)$b, tolerance = 1e-8)
})

test_that("maxit = 1 from a cold start reports the iteration cap and non-convergence", {
	r <- f(X, y, maxit = 1L, smart_cold_start = FALSE)
	expect_equal(r$num_iter, 1L)
	expect_true(r$hit_iteration_cap); expect_false(r$converged)
})
