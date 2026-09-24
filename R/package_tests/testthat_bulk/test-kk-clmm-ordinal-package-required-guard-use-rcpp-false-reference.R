library(testthat)
library(EDI)

# InferenceAbstractKKCLMM's initialize() (inference_ordinal_KK_clmm_abstract.R:36-44), spliced into
# InferenceOrdinalKKCLMM and its Probit/Cauchit/Cloglog siblings, only requires the 'ordinal' package
# when use_rcpp = FALSE (the default, use_rcpp = TRUE, uses the internal Rcpp implementation and never
# touches this guard) -- "Package 'ordinal' is required for <class>. Please install it." A codebase-
# wide grep confirmed this exact message had zero test references anywhere, unlike the identically-
# shaped 'multgee' package guard on the sibling KK_combined ordinal class (already covered) and the
# 'quantreg'/'geepack'/etc. package-required guard family closed earlier this session. Reached via the
# same with_mocked_bindings(check_package_installed = ..., .package = "EDI") technique already
# established in this suite's other package-required guard tests, constructing with use_rcpp = FALSE
# to actually reach the guard.

test_that("InferenceOrdinalKKCLMM(use_rcpp = FALSE) errors with the documented message when 'ordinal' is (mocked as) unavailable", {
	set.seed(1)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		{
			expect_error(
				InferenceOrdinalKKCLMM$new(des, use_rcpp = FALSE, verbose = FALSE),
				"Package 'ordinal' is required for InferenceOrdinalKKCLMM. Please install it.",
				fixed = TRUE
			)
		}
	)
})

test_that("the default use_rcpp = TRUE never triggers the guard, even when 'ordinal' is (mocked as) unavailable", {
	set.seed(2)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		{
			expect_no_error(InferenceOrdinalKKCLMM$new(des, verbose = FALSE))
		}
	)
})
