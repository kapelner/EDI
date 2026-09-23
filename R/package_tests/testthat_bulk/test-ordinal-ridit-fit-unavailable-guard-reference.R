library(testthat)
library(EDI)

# InferenceOrdinalRidit$shared() (inference_ordinal_ridit.R) caches "ordinal_ridit_fit_unavailable"
# when fast_ridit_analysis_cpp() returns NULL or an empty result. This had no test reference
# anywhere. Reached by mocking fast_ridit_analysis_cpp() directly, the same
# local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this suite for
# analogous unreachable-in-practice failure paths.

test_that("shared() caches 'ordinal_ridit_fit_unavailable' when fast_ridit_analysis_cpp() fails", {
	set.seed(1); n <- 20L
	des <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	inf <- InferenceOrdinalRidit$new(des, verbose = FALSE)
	local_mocked_bindings(fast_ridit_analysis_cpp = function(...) NULL, .package = "EDI")

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "ordinal_ridit_fit_unavailable")
})
