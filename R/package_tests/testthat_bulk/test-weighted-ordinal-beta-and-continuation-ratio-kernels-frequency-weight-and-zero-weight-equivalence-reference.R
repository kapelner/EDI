library(testthat)
library(EDI)

# Companion to the GLM-family weighted-kernel equivalence file: the weighted ordinal (proportional-odds), beta and continuation-ratio
# kernels. Integer weights must equal row replication; zero-weight rows must drop out (these links carry no support constraint, unlike the
# log / identity binomial kernels). Independent reference: the corresponding unweighted kernel on replicated / subsetted data.

set.seed(2); n <- 120L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n)); Xo <- X[, -1]                                   # ordinal models carry no intercept column
yo <- pmin(4, pmax(1, round(rnorm(n, 2.3 + 0.7 * X[, 2] + 0.4 * X[, 3], 1))))
yp <- pmin(0.99, pmax(0.01, rbeta(n, 2 + X[, 2], 3)))
wt <- sample(1:3, n, TRUE); idx <- rep(seq_len(n), wt); keep <- seq_len(n) > 25; w0 <- as.numeric(keep)
K <- function(nm) get(nm, envir = asNamespace("EDI"))
par_of <- function(r) as.numeric(if (!is.null(r$params)) r$params else if (!is.null(r$coefficients)) r$coefficients else r$b)

test_that("ordinal (proportional odds): frequency weights = replication, zero weights = subset, threshold + slope parameters", {
	a <- K("fast_ordinal_regression_weighted_cpp")(Xo, yo, as.numeric(wt)); b <- K("fast_ordinal_regression_cpp")(Xo[idx, ], yo[idx])
	expect_true(isTRUE(a$converged)); expect_equal(par_of(a), par_of(b), tolerance = 2e-3)
	z <- K("fast_ordinal_regression_weighted_cpp")(Xo, yo, w0); u <- K("fast_ordinal_regression_cpp")(Xo[keep, ], yo[keep])
	expect_equal(par_of(z), par_of(u), tolerance = 2e-3)
	expect_equal(par_of(K("fast_ordinal_regression_weighted_cpp")(Xo, yo, rep(1, n))), par_of(K("fast_ordinal_regression_cpp")(Xo, yo)), tolerance = 1e-3)
})

test_that("beta regression: coefficients and precision follow the same equivalences", {
	a <- K("fast_beta_regression_weighted_cpp")(X, yp, as.numeric(wt)); b <- K("fast_beta_regression_cpp")(X[idx, ], yp[idx])
	expect_true(isTRUE(a$converged)); expect_equal(as.numeric(a$coefficients), as.numeric(b$coefficients), tolerance = 5e-3)
	expect_equal(a$phi, b$phi, tolerance = 2e-2)
	z <- K("fast_beta_regression_weighted_cpp")(X, yp, w0); u <- K("fast_beta_regression_cpp")(X[keep, ], yp[keep])
	expect_equal(as.numeric(z$coefficients), as.numeric(u$coefficients), tolerance = 5e-3); expect_equal(z$phi, u$phi, tolerance = 2e-2)
	expect_gt(a$phi, 0)
})

test_that("continuation-ratio regression: frequency weights = replication and zero weights = subset", {
	a <- K("fast_continuation_ratio_regression_weighted_cpp")(Xo, yo, as.numeric(wt)); b <- K("fast_continuation_ratio_regression_cpp")(Xo[idx, ], yo[idx])
	expect_true(isTRUE(a$converged)); expect_equal(par_of(a), par_of(b), tolerance = 1e-3)
	z <- K("fast_continuation_ratio_regression_weighted_cpp")(Xo, yo, w0); u <- K("fast_continuation_ratio_regression_cpp")(Xo[keep, ], yo[keep])
	expect_equal(par_of(z), par_of(u), tolerance = 1e-3)
})

test_that("weights change the fit: unequal weights differ from unit weights", {
	for (nm in c("ordinal", "continuation_ratio")) {
		wf <- K(sprintf("fast_%s_regression_weighted_cpp", nm)); set.seed(9); rw <- runif(n, 0.2, 3)
		expect_gt(max(abs(par_of(wf(Xo, yo, rw)) - par_of(wf(Xo, yo, rep(1, n))))), 1e-3)
	}
})
