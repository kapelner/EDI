library(testthat)
library(EDI)

# fast_quasipoisson_regression_with_var_cpp(X, y, j, ...): Poisson-log MLE with the Pearson-dispersion-scaled variance
# ssq_b_j = dispersion * (X'WX)^-1[j, j]. Reference: stats::glm(family = quasipoisson) (coefficients, summary()$dispersion, vcov, mu) for every j;
# ssq_b_2 mirrors ssq_b_j for j = 2 and is NaN when column 2 is fixed; fixed coefficients equal the offset glm. The kernel's Pearson
# dispersion divides by n - p (the FULL column count) even for a profile fit, whereas glm(offset =) divides by n - p_free, so its
# fixed-coefficient dispersion is glm's times (n - p_free) / (n - p); the OLS with_var kernel uses n - p_free (pinned as an inconsistency
# between the kernels, not changed).

f <- get("fast_quasipoisson_regression_with_var_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 200L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
y <- rnbinom(n, mu = exp(X %*% c(0.4, 0.4, 0.2)), size = 2)
g <- glm(y ~ X - 1, family = quasipoisson())

test_that("coefficients, mu, dispersion and the j-th / treatment variances equal glm(quasipoisson) for every j", {
	for (j in 1:3) {
		r <- f(X, y, j = j)
		expect_true(r$converged)
		expect_equal(r$b, unname(coef(g)), tolerance = 1e-6)
		expect_equal(as.numeric(r$mu), unname(fitted(g)), tolerance = 1e-6)
		expect_equal(r$dispersion, summary(g)$dispersion, tolerance = 1e-4)
		expect_equal(r$ssq_b_j, unname(vcov(g)[j, j]), tolerance = 1e-5, info = as.character(j))
		expect_equal(r$ssq_b_2, unname(vcov(g)[2, 2]), tolerance = 1e-5, info = as.character(j))
	}
	pearson <- sum((y - fitted(g))^2 / fitted(g)) / (n - 3)
	expect_equal(f(X, y, j = 2L)$dispersion, pearson, tolerance = 1e-6)
})

test_that("fixed coefficient: profile fit equals the offset glm; dispersion uses the full-p degrees of freedom; ssq_b_2 is NaN when column 2 is fixed", {
	r <- f(X, y, j = 3L, fixed_idx = 2L, fixed_values = 0.3)
	ref <- glm(y ~ X[, c(1, 3)] - 1, offset = 0.3 * X[, 2], family = quasipoisson())
	expect_equal(r$b[2], 0.3); expect_equal(r$b[c(1, 3)], unname(coef(ref)), tolerance = 1e-6)
	expect_equal(r$dispersion, summary(ref)$dispersion * (n - 2) / (n - 3), tolerance = 1e-4)
	expect_equal(r$ssq_b_j, unname(vcov(ref)[2, 2]) * (n - 2) / (n - 3), tolerance = 1e-5)
	expect_true(is.nan(r$ssq_b_2) || is.na(r$ssq_b_2))
	r2 <- f(X, y, j = 2L, fixed_idx = 3L, fixed_values = 0.2)
	ref2 <- glm(y ~ X[, 1:2] - 1, offset = 0.2 * X[, 3], family = quasipoisson())
	expect_equal(r2$ssq_b_j, unname(vcov(ref2)[2, 2]) * (n - 2) / (n - 3), tolerance = 1e-5); expect_equal(r2$ssq_b_2, r2$ssq_b_j)
})

test_that("Poisson data give dispersion near 1 and identical coefficients to the plain Poisson kernel; optimizers agree", {
	set.seed(3); yp <- rpois(n, exp(X %*% c(0.4, 0.4, 0.2)))
	rq <- f(X, yp, j = 2L)
	expect_equal(rq$dispersion, summary(glm(yp ~ X - 1, family = quasipoisson()))$dispersion, tolerance = 1e-6)
	expect_equal(rq$b, as.numeric(get("fast_poisson_regression_cpp", envir = asNamespace("EDI"))(X, yp)$b), tolerance = 1e-8)
	for (alg in c("irls", "newton_raphson", "lbfgs")) expect_equal(f(X, y, j = 2L, optimization_alg = alg)$b, unname(coef(g)), tolerance = 1e-4, info = alg)
})

test_that("maxit = 1 from a cold start reports the iteration cap; estimate_only is not an argument", {
	r <- f(X, y, j = 2L, maxit = 1L, smart_cold_start = FALSE)
	expect_equal(r$num_iter, 1L); expect_true(r$hit_iteration_cap); expect_false(r$converged)
	expect_false("estimate_only" %in% names(formals(f)))
})
