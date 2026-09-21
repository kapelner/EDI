library(testthat)
library(EDI)

# helper_robust_sandwich.R: robust_sandwich_meat_from_residuals (X' diag(e^2) X), robust_sandwich_vcov (bread * meat * bread),
# robust_sandwich_variance (element j, NA below the absolute variance floor or when invalid) and
# robust_sandwich_variance_from_xtwx (composition). References: sandwich::vcovHC(type = "HC0") on an lm fit, and hand
# matrix algebra for the guard branches.

Z <- function(x) get(x, envir = asNamespace("EDI"))
meat_f <- Z("robust_sandwich_meat_from_residuals"); vcov_f <- Z("robust_sandwich_vcov")
var_f <- Z("robust_sandwich_variance"); comp_f <- Z("robust_sandwich_variance_from_xtwx")

set.seed(1); n <- 50L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5)); y <- X %*% c(1, 0.5, -1) + rnorm(n) * (1 + abs(X[, 2]))
fit <- lm(y ~ X - 1); res <- residuals(fit)

test_that("meat equals X' diag(e^2) X; HC0 sandwich from the pieces equals sandwich::vcovHC(type = 'HC0')", {
	skip_if_not_installed("sandwich")
	meat <- meat_f(X, res)
	expect_equal(unname(meat), unname(t(X) %*% diag(res^2) %*% X), tolerance = 1e-10)
	expect_true(isSymmetric(unname(meat)))
	bread <- solve(crossprod(X))
	vc <- vcov_f(bread, meat)
	expect_equal(unname(vc), unname(sandwich::vcovHC(fit, type = "HC0")), tolerance = 1e-8)
	for (j in 1:3) {
		expect_equal(var_f(vc, j), unname(sandwich::vcovHC(fit, type = "HC0")[j, j]), tolerance = 1e-8)
		expect_equal(comp_f(X, res, crossprod(X), j), var_f(vc, j), tolerance = 1e-10)
	}
})

test_that("meat guards: empty, length mismatch, non-finite entries give NULL; data.frame input is accepted", {
	expect_null(meat_f(matrix(0, 0, 2), numeric(0)))
	expect_null(meat_f(matrix(0, 3, 0), c(1, 2, 3)))
	expect_null(meat_f(X, res[-1]))
	Xn <- X; Xn[2, 2] <- NA; expect_null(meat_f(Xn, res))
	rn <- res; rn[3] <- Inf; expect_null(meat_f(X, rn))
	expect_equal(unname(meat_f(as.data.frame(X), res)), unname(meat_f(X, res)))
})

test_that("vcov guards: empty, dimension mismatch, non-square, non-finite pieces, and overflow give NULL", {
	expect_null(vcov_f(matrix(0, 0, 0), matrix(0, 0, 0)))
	expect_null(vcov_f(diag(2), diag(3)))
	expect_null(vcov_f(matrix(1, 2, 3), matrix(1, 2, 3)))
	b <- diag(2); m <- diag(2); m[1, 1] <- NaN; expect_null(vcov_f(b, m))
	b2 <- diag(2); b2[2, 2] <- Inf; expect_null(vcov_f(b2, diag(2)))
	expect_null(vcov_f(diag(2) * 1e200, diag(2) * 1e200))                            # product overflows to Inf
	expect_equal(vcov_f(diag(2), diag(2) * 3), diag(2) * 3)
})

test_that("variance: index validation, negative or non-finite entries, and the absolute floor at machine epsilon", {
	vc <- diag(c(4, 9))
	expect_equal(var_f(vc, 1), 4); expect_equal(var_f(vc, 2L), 9); expect_equal(var_f(vc, 2.0), 9)
	expect_true(is.na(var_f(vc, 0))); expect_true(is.na(var_f(vc, 3))); expect_true(is.na(var_f(vc, NA)))
	expect_true(is.na(var_f(vc, c(1, 2)))); expect_true(is.na(var_f(vc, -1)))
	expect_true(is.na(var_f(diag(c(-1, 1)), 1)))
	expect_true(is.na(var_f(diag(c(NaN, 1)), 1)))
	expect_true(is.na(var_f(diag(c(0, 1)), 1)))
	expect_true(is.na(var_f(diag(c(.Machine$double.eps / 2, 1)), 1)))            # below the floor: perfect-fit collapse
	expect_equal(var_f(diag(c(.Machine$double.eps, 1)), 1), .Machine$double.eps)  # at the floor: kept
	expect_equal(var_f(as.matrix(5), 1), 5)
})

test_that("perfect fit (all-zero residuals) is reported as NA rather than a zero-width interval", {
	expect_true(is.na(comp_f(X, rep(0, n), crossprod(X), 2)))
})

test_that("composition guards: singular XtWX, bad residual length, non-finite inputs give NA", {
	expect_true(is.na(comp_f(X, res, matrix(0, 3, 3), 2)))
	expect_true(is.na(comp_f(X, res[-1], crossprod(X), 2)))
	rn <- res; rn[1] <- NA; expect_true(is.na(comp_f(X, rn, crossprod(X), 2)))
	expect_true(is.na(comp_f(X, res, crossprod(X), 9)))
})

test_that("the RobustSandwichSource private methods delegate to the helpers", {
	src <- Z("RobustSandwichSource")$private
	expect_named(src, c("robust_sandwich_meat_from_residuals", "robust_sandwich_vcov", "robust_sandwich_variance", "robust_sandwich_variance_from_xtwx"))
	expect_equal(src$robust_sandwich_meat_from_residuals(X, res), meat_f(X, res))
	expect_equal(src$robust_sandwich_variance_from_xtwx(X, res, crossprod(X), 3), comp_f(X, res, crossprod(X), 3))
})
