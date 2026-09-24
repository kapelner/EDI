library(testthat)
library(EDI)

# Design's private covariate_impute_if_necessary_and_then_create_model_matrix() (design_abstract.R)
# has a defensive "should never happen" guard: model.matrix() is documented to always return a numeric
# matrix, but this function double-checks and stops with "model.matrix returned a character matrix -
# this should not happen." if create_model_matrix_from_features() ever hands back a character matrix.
# Unreachable in practice (confirmed via a zero-hit grep for the exact message across the whole test
# suite) -- reached here by mocking create_model_matrix_from_features() (a top-level free function, not
# a private method, so local_mocked_bindings() rather than unlockBinding()) to return a character
# matrix directly, the same "force an internally-trusted dependency to violate its contract" technique
# already used elsewhere in this suite for analogous defensive guards.

test_that("a character model matrix from create_model_matrix_from_features() triggers the documented defensive guard", {
	local_mocked_bindings(create_model_matrix_from_features = function(...) matrix("a", 2L, 1L), .package = "EDI")
	set.seed(1L); n <- 10L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	expect_error(
		des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))),
		"model\\.matrix returned a character matrix - this should not happen\\."
	)
})

test_that("a genuine numeric model matrix does not trigger the guard", {
	set.seed(2L); n <- 10L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	expect_no_error(des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))))
})
