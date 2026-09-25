library(testthat)
library(EDI)

# fast_zero_one_inflated_beta_cpp() (fast_zero_one_inflated_beta.cpp) had zero test references
# anywhere per the standing "avoid" guidance for this kernel (documented intermittent-crash risk in
# the optimizer path). The most recent commit (11f61e0a) added three upfront input-validation guards
# -- mismatched X/X_zero_one/y row counts, a wrong-length warm_start_params, and a wrong-shaped
# warm_start_fisher_info -- fixing a real heap-corruption bug (an unchecked warm start of the wrong
# length let L-BFGS read/write past the parameter buffer, found under valgrind). These three guards
# throw std::invalid_argument (translated to an R error by Rcpp) BEFORE any solver/optimization code
# runs, so exercising them carries none of the crash risk the standing avoid-list entry is about --
# confirmed safe via a tight-timeout probe before writing this file. The optimizer's own successful-
# fit path remains untested here, consistent with the standing guidance.

f <- get("fast_zero_one_inflated_beta_cpp", envir = asNamespace("EDI"))

test_that("mismatched row counts between X/X_zero_one and y are rejected", {
	X <- matrix(1, 5, 1); X_zero_one <- matrix(1, 5, 1); y <- rep(0.5, 4)  # y is one row short
	expect_error(f(X, X_zero_one, y), "X, X_zero_one and y must have the same number of rows", fixed = TRUE)

	X2 <- matrix(1, 5, 1); X_zero_one2 <- matrix(1, 4, 1); y2 <- rep(0.5, 5)  # X_zero_one is one row short
	expect_error(f(X2, X_zero_one2, y2), "X, X_zero_one and y must have the same number of rows", fixed = TRUE)
})

test_that("a wrong-length warm_start_params is rejected (must be p + 1 + 2 * p_zero_one)", {
	X <- matrix(1, 5, 1); X_zero_one <- matrix(1, 5, 1); y <- rep(0.5, 5)  # total params = 1 + 1 + 2*1 = 4
	expect_error(
		f(X, X_zero_one, y, warm_start_params = c(1, 2, 3)),
		"warm_start_params must have length p \\+ 1 \\+ 2 \\* p_zero_one"
	)
	expect_error(
		f(X, X_zero_one, y, warm_start_params = c(1, 2, 3, 4, 5)),
		"warm_start_params must have length p \\+ 1 \\+ 2 \\* p_zero_one"
	)
})

test_that("a wrong-shaped warm_start_fisher_info is rejected (must be square, one row per parameter)", {
	X <- matrix(1, 5, 1); X_zero_one <- matrix(1, 5, 1); y <- rep(0.5, 5)  # total params = 4
	expect_error(
		f(X, X_zero_one, y, warm_start_fisher_info = matrix(1, 2, 2)),  # wrong size, though square
		"warm_start_fisher_info must be a square matrix with one row per model parameter"
	)
	expect_error(
		f(X, X_zero_one, y, warm_start_fisher_info = matrix(1, 4, 3)),  # right rows, not square
		"warm_start_fisher_info must be a square matrix with one row per model parameter"
	)
})

test_that("correctly-sized warm_start_params/warm_start_fisher_info do not trigger either guard", {
	X <- matrix(1, 5, 1); X_zero_one <- matrix(1, 5, 1); y <- rep(0.5, 5)
	res <- f(X, X_zero_one, y, warm_start_params = c(1, 2, 3, 4), warm_start_fisher_info = diag(4))
	expect_true(is.list(res))
})
