library(testthat)
library(EDI)

# Poisson regression kernels: fast_poisson_regression_cpp / _weighted_cpp return XtWX = X' diag(w * mu) X (unit weights when unweighted) and
# a fisher_information equal to it; fast_poisson_regression_with_var_cpp returns ssq_b_j = [inverse Fisher information]_jj. References: glm
# (poisson, weights) coefficients and hand-computed X' diag(w mu) X.

set.seed(1); n <- 80L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n)); y <- rpois(n, exp(0.2 + 0.3 * X[, 2] + 0.2 * X[, 3])); wt <- runif(n, 0.5, 2)
K <- function(nm) get(nm, envir = asNamespace("EDI"))

test_that("unweighted kernel: coefficients equal glm; XtWX = X' diag(mu) X and equals the reported Fisher information", {
	r <- K("fast_poisson_regression_cpp")(X, y); ref <- glm(y ~ X[, -1], family = poisson)
	expect_equal(as.numeric(r$b), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(as.numeric(r$mu), unname(fitted(ref)), tolerance = 1e-6)
	expect_equal(unname(r$XtWX), unname(crossprod(X, X * as.numeric(r$mu))), tolerance = 1e-8)
	expect_equal(unname(r$fisher_information), unname(r$XtWX), tolerance = 1e-8)
	expect_true(isTRUE(r$converged))
})

test_that("weighted kernel: coefficients equal weighted glm; XtWX = X' diag(w mu) X", {
	r <- K("fast_poisson_regression_weighted_cpp")(X, y, weights = wt)
	ref <- suppressWarnings(glm(y ~ X[, -1], family = poisson, weights = wt))
	expect_equal(as.numeric(r$b), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(unname(r$XtWX), unname(crossprod(X, X * (wt * as.numeric(r$mu)))), tolerance = 1e-8)
	expect_equal(unname(solve(r$XtWX)), unname(vcov(ref)), tolerance = 1e-5)
})

test_that("with-var kernel: ssq_b_j is the jth diagonal of the inverse Fisher information (and equals glm's vcov entry)", {
	ref <- glm(y ~ X[, -1], family = poisson)
	for (j in 1:3) {
		v <- K("fast_poisson_regression_with_var_cpp")(X, y, j = j)
		expect_equal(v$ssq_b_j, solve(v$fisher_information)[j, j], tolerance = 1e-8, info = j)
		expect_equal(v$ssq_b_j, unname(vcov(ref)[j, j]), tolerance = 1e-4, info = j)
		expect_equal(v$ssq_b_2, unname(vcov(ref)[2, 2]), tolerance = 1e-4)
	}
})

test_that("unit weights make the weighted kernel agree with the unweighted one", {
	a <- K("fast_poisson_regression_cpp")(X, y); b <- K("fast_poisson_regression_weighted_cpp")(X, y, weights = rep(1, n))
	expect_equal(as.numeric(b$b), as.numeric(a$b), tolerance = 1e-6); expect_equal(unname(b$XtWX), unname(a$XtWX), tolerance = 1e-6)
})
