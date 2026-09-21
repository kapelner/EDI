library(testthat)
library(EDI)

# fast_ols_with_var_cpp(X, y, j, fixed_idx, fixed_values): full fit equals lm (coefficients, sigma2 = SSE / (n - p), ssq_b_j =
# sigma2 * (X'X)^-1[j, j], XtX); with fixed coefficients the profile fit equals lm(offset =) on the free columns, sigma2 uses
# n - p_free, ssq_b_2 is NA when the treatment column (2) is fixed; a rank-deficient design takes the QR fallback (no variance).
# fast_ols_cpp returns just the coefficients (same fixed-coefficient semantics).

K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(1); n <- 50L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5)); colnames(X) <- c("a", "b", "c")
y <- as.numeric(X %*% c(1, 0.5, 0.8) + rnorm(n))
m <- lm(y ~ X - 1)

test_that("full fit: coefficients, sigma2, ssq_b_j / ssq_b_2 and XtX equal the lm quantities for every j", {
	for (j in 1:3) {
		r <- K("fast_ols_with_var_cpp")(X, y, j = j)
		expect_equal(r$b, unname(coef(m)), tolerance = 1e-9)
		expect_equal(r$sigma2_hat, summary(m)$sigma^2, tolerance = 1e-9)
		expect_equal(r$ssq_b_j, unname(vcov(m)[j, j]), tolerance = 1e-9, info = as.character(j))
		expect_equal(r$ssq_b_2, unname(vcov(m)[2, 2]), tolerance = 1e-9, info = as.character(j))
		expect_equal(unname(r$XtX), unname(crossprod(X)), tolerance = 1e-10)
		expect_true(r$converged)
	}
	expect_true(is.na(K("fast_ols_with_var_cpp")(X, y, j = 4L)$ssq_b_j))            # out-of-range j
})

test_that("fixed coefficient: profile fit = lm with offset on the free columns; sigma2 uses n - p_free; XtX zeroed on the fixed row/col", {
	r <- K("fast_ols_with_var_cpp")(X, y, j = 3L, fixed_idx = 2L, fixed_values = 0.4)
	ref <- lm(y ~ X[, c(1, 3)] - 1, offset = 0.4 * X[, 2])
	expect_equal(r$b[2], 0.4); expect_equal(r$b[c(1, 3)], unname(coef(ref)), tolerance = 1e-9)
	expect_equal(r$sigma2_hat, sum(resid(ref)^2) / (n - 2), tolerance = 1e-9)
	expect_equal(r$ssq_b_j, unname(vcov(ref)[2, 2]), tolerance = 1e-9)
	expect_true(is.na(r$ssq_b_2))                                              # treatment (column 2) is the fixed one
	expect_true(all(r$XtX[2, ] == 0) && all(r$XtX[, 2] == 0))
	expect_equal(unname(r$XtX[c(1, 3), c(1, 3)]), unname(crossprod(X[, c(1, 3)])), tolerance = 1e-10)
	r2 <- K("fast_ols_with_var_cpp")(X, y, j = 2L, fixed_idx = 3L, fixed_values = 0.8)
	ref2 <- lm(y ~ X[, 1:2] - 1, offset = 0.8 * X[, 3])
	expect_equal(r2$ssq_b_j, unname(vcov(ref2)[2, 2]), tolerance = 1e-9); expect_equal(r2$ssq_b_2, r2$ssq_b_j)
	expect_true(is.na(K("fast_ols_with_var_cpp")(X, y, j = 3L, fixed_idx = 3L, fixed_values = 0.8)$ssq_b_j))   # variance of a fixed coefficient
})

test_that("fast_ols_cpp: coefficients only, with the same fixed-coefficient semantics", {
	r <- K("fast_ols_cpp")(X, y)
	expect_named(r, "b"); expect_equal(r$b, unname(coef(m)), tolerance = 1e-9)
	rf <- K("fast_ols_cpp")(X, y, fixed_idx = c(1L, 3L), fixed_values = c(1, 0.8))
	expect_equal(rf$b[c(1, 3)], c(1, 0.8))
	expect_equal(rf$b[2], unname(coef(lm(y ~ X[, 2] - 1, offset = X[, 1] * 1 + X[, 3] * 0.8))), tolerance = 1e-9)
	expect_error(K("fast_ols_cpp")(X, y, fixed_idx = 1:3, fixed_values = c(1, 2, 3)), "at least one parameter must remain free")
})

test_that("rank-deficient design: QR fallback returns finite coefficients without variance fields", {
	Xd <- cbind(X, X[, 2] * 2)
	r <- K("fast_ols_with_var_cpp")(Xd, y, j = 2L)
	expect_true(all(is.finite(r$b)))
	expect_equal(as.numeric(Xd %*% r$b), as.numeric(fitted(m)), tolerance = 1e-6)      # same fitted values as the full-rank fit
	expect_null(r$ssq_b_j)
})
