library(testthat)
library(EDI)

# helper_zoib.R's .fit_zero_one_inflated_beta() validates its arguments -- matching row counts
# between y and X, matching row counts between y and X_zero_one, and y in [0, 1] -- entirely in pure
# R, before ever calling the risky fast_zero_one_inflated_beta_cpp() kernel (that call happens much
# later in the function body, on line 126, only after all three checks below pass). These guards are
# therefore safe to test directly despite the C++ kernel's known intermittent memory-safety issue
# (this session's job instructions avoid exercising that kernel itself) -- none of the three inputs
# constructed here ever reaches it. Zero test references anywhere for all three messages.

test_that(".fit_zero_one_inflated_beta(): mismatched y/X row counts errors with the documented message", {
	f <- getFromNamespace(".fit_zero_one_inflated_beta", "EDI")
	expect_error(
		f(y = c(0.5, 0.5, 0.5), X = matrix(1, 2, 1)),
		"Zero/one-inflated beta fit inputs must have matching row counts\\."
	)
})

test_that(".fit_zero_one_inflated_beta(): mismatched y/X_zero_one row counts errors with the documented message", {
	f <- getFromNamespace(".fit_zero_one_inflated_beta", "EDI")
	expect_error(
		f(y = c(0.5, 0.5), X = matrix(1, 2, 1), X_zero_one = matrix(1, 3, 1)),
		"Zero/one-inflated beta auxiliary inputs must have matching row counts\\."
	)
})

test_that(".fit_zero_one_inflated_beta(): a y value outside [0, 1] errors with the documented message", {
	f <- getFromNamespace(".fit_zero_one_inflated_beta", "EDI")
	expect_error(
		f(y = c(0.5, 1.5), X = matrix(1, 2, 1)),
		"Zero/one-inflated beta requires y in \\[0, 1\\]\\."
	)
	expect_error(
		f(y = c(0.5, -0.1), X = matrix(1, 2, 1)),
		"Zero/one-inflated beta requires y in \\[0, 1\\]\\."
	)
	expect_error(
		f(y = c(0.5, NA_real_), X = matrix(1, 2, 1)),
		"Zero/one-inflated beta requires y in \\[0, 1\\]\\."
	)
})
