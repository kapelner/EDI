library(testthat)
library(EDI)

# InferenceContinLin's shared() (inference_continuous_lin.R) has a design-level guard, upstream of
# the three fit-failure branches already covered by
# test-continuous-lin-shared-fit-failure-branches-reference.R: when reduce_design_matrix_preserving_
# treatment() (inference_all_abstract.R) returns a NULL/unusable design -- X NULL, j_treat
# non-finite, or nrow(X_fit) <= ncol(X_fit) -- shared() caches "linear_model_design_unusable" before
# ever calling lm.fit(). This had no test reference anywhere. Reached two ways: (1) organically, a
# perfectly collinear treatment column gets dropped by the QR-based column-preserving reduction, and
# (2) directly, mocking reduce_design_matrix_preserving_treatment() to return the NULL-X sentinel, the
# same local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this suite.

mk_fixture <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	InferenceContinLin$new(des, verbose = FALSE)
}

test_that("a NULL/unusable reduced design (mocked) is nonestimable ('linear_model_design_unusable')", {
	inf <- mk_fixture()
	local_mocked_bindings(
		qr_reduce_preserve_cols_cpp = function(X, cols_to_preserve) {
			list(X_reduced = matrix(numeric(0), nrow = nrow(X), ncol = 0L), keep = 1L)
		},
		.package = "EDI"
	)
	p <- inf$.__enclos_env__$private
	unlockBinding("harden", p)
	p$harden <- TRUE

	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "linear_model_design_unusable")
})

test_that("directly overriding the reduced design to the NULL-X sentinel is nonestimable", {
	inf <- mk_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("reduce_design_matrix_preserving_treatment", p)
	p$reduce_design_matrix_preserving_treatment <- function(X_full) {
		list(X = NULL, keep = integer(0), j_treat = NA_integer_)
	}

	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "linear_model_design_unusable")
})
