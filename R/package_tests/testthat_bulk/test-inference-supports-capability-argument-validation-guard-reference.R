library(testthat)
library(EDI)

# inference_all_abstract.R's base Inference$supports(capability) validates its argument before
# checking against self$capabilities(): non-character, zero-length, or NA-containing input errors
# "`capability` must be a non-empty character vector with no missing values." A public method
# inherited by every concrete inference class, yet the guard itself had zero test references
# anywhere -- existing coverage only exercises well-formed capability queries.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceContinLin$new(des, verbose = FALSE)
}

test_that("supports(): non-character, zero-length, and NA-containing input each error with the documented message", {
	inf <- fx(seed = 1L)

	expect_error(inf$supports(123), "`capability` must be a non-empty character vector with no missing values\\.")
	expect_error(inf$supports(character(0)), "`capability` must be a non-empty character vector with no missing values\\.")
	expect_error(inf$supports(NA_character_), "`capability` must be a non-empty character vector with no missing values\\.")
	expect_error(inf$supports(c("wald", NA_character_)), "`capability` must be a non-empty character vector with no missing values\\.")
})

test_that("supports(): a valid character vector returns a named logical vector aligned with the input", {
	inf <- fx(seed = 2L)
	res <- inf$supports(c("wald", "not_a_real_capability_xyz"))
	expect_type(res, "logical")
	expect_identical(names(res), c("wald", "not_a_real_capability_xyz"))
	expect_true(res[["wald"]])
	expect_false(res[["not_a_real_capability_xyz"]])
})
