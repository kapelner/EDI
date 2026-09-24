library(testthat)
library(EDI)

# fast_ordinal_regression_weighted_cpp (fast_ordinal_regression.cpp, the observation-weighted
# proportional-odds ordinal logistic kernel) validates weights's length against nrow(X) before
# passing it into the shared internal fitter: `if (map_weights.size() != map_X.rows()) stop("weights
# must have length equal to nrow(X)")`. A codebase-wide grep across testthat_bulk/,
# R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms this exact function is called by 3
# existing reference files, all with correctly-sized weights vectors -- the length-mismatch guard
# itself had no test reference anywhere. (The sibling internal-only guard inside
# fast_ordinal_regression_internal() at line 153 is unreachable from R -- every R-facing caller other
# than the weighted export always passes weights = std::nullopt -- so it is not a coverable gap here.)

f <- get("fast_ordinal_regression_weighted_cpp", envir = asNamespace("EDI"))
set.seed(41); n <- 80L
X <- cbind(rnorm(n))
y <- as.numeric(cut(X[, 1] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))
w <- runif(n, 0.3, 3)

test_that("weights shorter than nrow(X) throws the length-mismatch error", {
	expect_error(f(X, y, weights = w[1:10]), "weights must have length equal to nrow\\(X\\)")
})

test_that("weights longer than nrow(X) throws the same length-mismatch error", {
	expect_error(f(X, y, weights = c(w, 1)), "weights must have length equal to nrow\\(X\\)")
})

test_that("the guard fires identically under every optimization_alg", {
	for (alg in c("lbfgs", "newton", "bfgs")) {
		expect_error(f(X, y, weights = w[1:10], optimization_alg = alg), "weights must have length equal to nrow\\(X\\)", info = alg)
	}
})

test_that("correctly-sized weights do not trigger the guard and the fit matches the unweighted kernel under unit weights", {
	f_unweighted <- get("fast_ordinal_regression_cpp", envir = asNamespace("EDI"))
	r_weighted <- f(X, y, weights = rep(1, n))
	r_unweighted <- f_unweighted(X, y)
	expect_true(r_weighted$converged)
	expect_equal(r_weighted$params, r_unweighted$params, tolerance = 1e-6)
})
