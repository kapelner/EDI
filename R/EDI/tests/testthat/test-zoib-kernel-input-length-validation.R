library(testthat)
library(EDI)

# Regression for a heap overflow (found under valgrind, 2026-09-24):
# fast_zero_one_inflated_beta_cpp() copied a caller-supplied warm_start_params
# into its parameter vector with no length check, so a start of the wrong
# length made L-BFGS read/write past the buffer and later abort the process
# ("free(): invalid next size"). The kernel must now reject mis-sized inputs
# with an ordinary R error and still accept correctly sized ones.

zoib_fixture = function(n = 80L, seed = 1L) {
	set.seed(seed)
	X = cbind(1, rnorm(n))                        # p = 2
	Xz = cbind(1, rnorm(n))                       # p_zero_one = 2, so total = 2 + 1 + 4 = 7
	y = pmin(pmax(rbeta(n, 2, 2), 0), 1)
	y[sample(n, 8L)] = 0
	y[sample(n, 8L)] = 1
	list(X = X, Xz = Xz, y = y, total = ncol(X) + 1L + 2L * ncol(Xz))
}

test_that("a warm start of the wrong length is an error, not memory corruption", {
	f = zoib_fixture()
	K = EDI:::fast_zero_one_inflated_beta_cpp
	expect_error(K(f$X, f$Xz, f$y, warm_start_params = rep(0, f$total - 1L)), "warm_start_params")
	expect_error(K(f$X, f$Xz, f$y, warm_start_params = rep(0, f$total + 4L)), "warm_start_params")
	expect_error(K(f$X, f$Xz, f$y, warm_start_params = numeric(0)), "warm_start_params")
})

test_that("a correctly sized warm start still fits", {
	f = zoib_fixture()
	start = c(0, 0, 2, rep(0, 2 * ncol(f$Xz)))
	expect_length(start, f$total)
	fit = EDI:::fast_zero_one_inflated_beta_cpp(f$X, f$Xz, f$y, warm_start_params = start)
	expect_true(is.finite(fit$neg_loglik))
})

test_that("row-count mismatches between X, X_zero_one and y are errors", {
	f = zoib_fixture()
	K = EDI:::fast_zero_one_inflated_beta_cpp
	expect_error(K(f$X[-1, , drop = FALSE], f$Xz, f$y), "same number of rows")
	expect_error(K(f$X, f$Xz[-1, , drop = FALSE], f$y), "same number of rows")
	expect_error(K(f$X, f$Xz, f$y[-1]), "same number of rows")
})

test_that("a mis-sized warm_start_fisher_info is an error", {
	f = zoib_fixture()
	K = EDI:::fast_zero_one_inflated_beta_cpp
	expect_error(K(f$X, f$Xz, f$y, warm_start_fisher_info = diag(f$total - 1L)), "warm_start_fisher_info")
})
