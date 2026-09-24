library(testthat)
library(EDI)

# Design's private covariate_impute_if_necessary_and_then_create_model_matrix() (design_abstract.R,
# missingness_method = "impute" path) has a documented missRanger()-fails-fallback-to-missForest()
# cascade ("fast but fragile" -> "slow but more robust") that had no test reference anywhere.
# test-design-covariate-missingness-methods-and-subject-data-cache-reference.R already covers the
# "error"/"drop_column" branches and the impute HAPPY path (missRanger succeeding), including the
# missingness-indicator-column logic, but never forces missRanger() to fail. Reached here by mocking
# missRanger() to always throw (the only realistic way to reach this branch -- missRanger failing
# organically on ordinary data isn't something a fixture can reliably construct), while missForest()
# itself is only wrapped (not replaced) so the real fallback imputation actually runs and is verified
# for real, not just dispatch-checked.
#   1. When missRanger() throws, missForest() is invoked exactly once (a call-count probe) and the
#      resulting Ximp has no missing values, with every observed (non-NA) value preserved exactly.
#   2. The same fallback also runs correctly when there is a response column to condition on
#      (get_effective_time() non-NA), matching the happy path's own y-conditioning behavior.

miss_covariates <- function(n = 30L, seed = 3L) {
	set.seed(seed)
	X <- data.frame(a = rnorm(n), b = rnorm(n), cc = rep(1, n), d = sample(c("u", "v"), n, TRUE))
	X$a[c(2, 5)] <- NA
	X$d[4] <- NA
	X
}

miss_design <- function(X = miss_covariates(), response = NULL) {
	des <- DesignFixedBernoulli$new(
		n = nrow(X), response_type = "continuous", missingness_method = "impute",
		include_is_missing_as_a_new_feature = FALSE, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	if (!is.null(response)) des$add_all_subject_responses(response)
	des
}

test_that("when missRanger() throws, missForest() is invoked exactly once and produces a fully-imputed, value-preserving Ximp", {
	X <- miss_covariates()
	des <- miss_design(X)
	priv <- des$.__enclos_env__$private

	orig_missForest <- missForest::missForest
	mf_calls <- 0L
	local_mocked_bindings(
		missRanger = function(...) stop("forced missRanger failure"),
		missForest = function(...) { mf_calls <<- mf_calls + 1L; orig_missForest(...) },
		.package = "EDI"
	)
	priv$covariate_impute_if_necessary_and_then_create_model_matrix()

	expect_equal(mf_calls, 1L)
	expect_false(anyNA(priv$Ximp))
	obs_a <- !is.na(X$a)
	expect_equal(priv$Ximp$a[obs_a], X$a[obs_a], tolerance = 1e-12)
	expect_equal(priv$Ximp$b, X$b, tolerance = 1e-12)
	obs_d <- !is.na(X$d)
	expect_equal(as.character(priv$Ximp$d[obs_d]), X$d[obs_d])
	expect_true(as.character(priv$Ximp$d[4]) %in% c("u", "v"))
})

test_that("the same fallback runs correctly when there is a response column to condition on", {
	X <- miss_covariates(seed = 4L)
	des <- miss_design(X, response = rnorm(nrow(X)))
	priv <- des$.__enclos_env__$private

	orig_missForest <- missForest::missForest
	mf_calls <- 0L
	local_mocked_bindings(
		missRanger = function(...) stop("forced missRanger failure"),
		missForest = function(...) { mf_calls <<- mf_calls + 1L; orig_missForest(...) },
		.package = "EDI"
	)
	priv$covariate_impute_if_necessary_and_then_create_model_matrix()

	expect_equal(mf_calls, 1L)
	expect_false(anyNA(priv$Ximp))
	obs_a <- !is.na(X$a)
	expect_equal(priv$Ximp$a[obs_a], X$a[obs_a], tolerance = 1e-12)
})
