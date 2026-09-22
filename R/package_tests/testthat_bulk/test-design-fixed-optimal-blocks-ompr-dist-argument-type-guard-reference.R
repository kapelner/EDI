library(testthat)
library(EDI)

# DesignFixedOptimalBlocks$new(method = "ompr", dist = ...): dist must be either a function or a length-1
# character string; anything else (a number, a multi-element character vector, etc.) is rejected with an explicit
# type-error message BEFORE the string is checked against the allowed choices ("euclidean"/"sum_abs_diff"/"mahal")
# and before the optional ompr/ompr.roi/ROI.plugin.glpk packages are even checked for installation -- so this
# guard is reachable regardless of whether those optional dependencies are present. Had no test triggering it;
# existing coverage of this class's dist argument only exercises valid function/string values and the (distinct)
# assertChoice() error for an unrecognised-but-still-scalar-character dist value.

test_that("a non-function, non-scalar-character dist is rejected with the type-error message, before any package-installed check", {
	expect_error(
		DesignFixedOptimalBlocks$new(method = "ompr", dist = 123, response_type = "continuous", n = 8, B = 2, verbose = FALSE),
		"dist must be a function or one of 'euclidean', 'sum_abs_diff', or 'mahal'\\."
	)
	expect_error(
		DesignFixedOptimalBlocks$new(method = "ompr", dist = c("euclidean", "mahal"), response_type = "continuous", n = 8, B = 2, verbose = FALSE),
		"dist must be a function or one of 'euclidean', 'sum_abs_diff', or 'mahal'\\."
	)
	expect_error(
		DesignFixedOptimalBlocks$new(method = "ompr", dist = list("euclidean"), response_type = "continuous", n = 8, B = 2, verbose = FALSE),
		"dist must be a function or one of 'euclidean', 'sum_abs_diff', or 'mahal'\\."
	)
	expect_error(
		DesignFixedOptimalBlocks$new(method = "ompr", dist = TRUE, response_type = "continuous", n = 8, B = 2, verbose = FALSE),
		"dist must be a function or one of 'euclidean', 'sum_abs_diff', or 'mahal'\\."
	)
})

test_that("an unrecognised but still scalar-character dist gets the DIFFERENT assertChoice() error, not the type-error message", {
	err <- tryCatch(
		DesignFixedOptimalBlocks$new(method = "ompr", dist = "bogus", response_type = "continuous", n = 8, B = 2, verbose = FALSE),
		error = function(e) e
	)
	expect_true(inherits(err, "error"))
	expect_false(grepl("dist must be a function or one of", conditionMessage(err), fixed = TRUE))
	expect_match(conditionMessage(err), "euclidean")
})

test_that("a real function or a valid scalar-character dist both pass this guard without error", {
	skip_if(!all(vapply(c("ompr", "ompr.roi", "ROI.plugin.glpk"), requireNamespace, logical(1), quietly = TRUE)))
	expect_no_error(DesignFixedOptimalBlocks$new(method = "ompr", dist = function(x, y) sum((x - y)^2), response_type = "continuous", n = 8, B = 2, verbose = FALSE))
	expect_no_error(DesignFixedOptimalBlocks$new(method = "ompr", dist = "euclidean", response_type = "continuous", n = 8, B = 2, verbose = FALSE))
})

test_that("this guard is specific to method = 'ompr': an invalid-typed dist is silently ignored under 'greedy'/'K-way'", {
	skip_if(!requireNamespace("blockTools", quietly = TRUE))
	expect_no_error(DesignFixedOptimalBlocks$new(method = "greedy", dist = 123, response_type = "continuous", n = 8, B = 2, verbose = FALSE))
})
