library(testthat)
library(EDI)

# Two sibling families of C++ ordinal-regression kernels each guard on having at least 2 distinct
# observed outcome levels before fitting: fast_adjacent_category_logit_cpp()/_with_var_cpp()
# ("Adjacent-category logits require at least two observed outcome categories.") and
# fast_stereotype_logit_cpp()/_with_var_cpp()/fast_stereotype_profile_loglik_cpp() ("Stereotype
# logistic regression requires at least two observed outcome categories."). A codebase-wide grep
# confirmed neither guard message had any test reference anywhere, despite all 5 exported functions
# being otherwise well-tested (1-2 references each) -- every existing reference fits on a response with
# genuine variation across at least 2 levels, so this single-level degenerate-response guard was never
# exercised on any of them.

test_that("fast_adjacent_category_logit_cpp() and its _with_var sibling both reject a single-level response", {
	X <- cbind(1, rnorm(20))
	y <- rep(1, 20)
	expect_error(
		EDI:::fast_adjacent_category_logit_cpp(X, y),
		"Adjacent-category logits require at least two observed outcome categories.",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_adjacent_category_logit_with_var_cpp(X, y),
		"Adjacent-category logits require at least two observed outcome categories.",
		fixed = TRUE
	)
})

test_that("fast_stereotype_logit_cpp(), its _with_var sibling, and fast_stereotype_profile_loglik_cpp() all reject a single-level response", {
	X <- cbind(1, rnorm(20))
	y <- rep(1, 20)
	expect_error(
		EDI:::fast_stereotype_logit_cpp(X, y),
		"Stereotype logistic regression requires at least two observed outcome categories.",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_stereotype_logit_with_var_cpp(X, y),
		"Stereotype logistic regression requires at least two observed outcome categories.",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_stereotype_profile_loglik_cpp(X, y, beta_fixed = 0.5),
		"Stereotype logistic regression requires at least two observed outcome categories.",
		fixed = TRUE
	)
})

test_that("a response with genuine 2+ level variation triggers neither guard", {
	X <- cbind(1, rnorm(20))
	y <- rep(c(1, 2, 3), length.out = 20)
	expect_no_error(EDI:::fast_adjacent_category_logit_cpp(X, y))
	expect_no_error(EDI:::fast_stereotype_logit_cpp(X, y))
})
