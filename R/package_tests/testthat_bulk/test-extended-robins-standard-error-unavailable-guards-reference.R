library(testthat)
library(EDI)

# InferenceIncidExtendedRobins$get_standard_error() (inference_incidence_extended_robins.R) has two
# distinct sites that cache "extended_robins_standard_error_unavailable" when the block SE comes out
# non-finite or non-positive -- structurally identical to InferenceIncidCMH's own two-site SE guard
# closed earlier this session:
#   1. a fast-path re-check: if private$cached_values$robins_s_beta_hat_T is already cached but
#      non-finite/<=0, it's rejected immediately without recomputing.
#   2. after a fresh computation via compute_extended_robins_block_se_cpp(), the result is rejected
#      the same way if it's non-finite/<=0.
# Neither had a test reference anywhere. Branch 1 is reached by directly seeding the cache with an
# invalid value; branch 2 is reached by mocking compute_extended_robins_block_se_cpp() to return 0,
# the same local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this
# suite for analogous unreachable-in-practice failure paths.

extended_robins_fixture <- function() {
	des <- DesignFixedBlocking$new(strata_cols = "stratum", n = 8, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(stratum = c(rep("A", 4), rep("B", 4))))
	des$overwrite_all_subject_assignments(c(1, 0, 1, 0, 1, 0, 1, 0))
	des$add_all_subject_responses(c(1, 0, 1, 0, 1, 1, 0, 0))
	des
}

test_that("a cached-but-invalid SE is rejected without recomputing (fast-path guard)", {
	des <- extended_robins_fixture()
	inf <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$cached_values$robins_s_beta_hat_T <- 0

	res <- p$get_standard_error()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "extended_robins_standard_error_unavailable")
})

test_that("a freshly computed non-positive SE is rejected the same way", {
	des <- extended_robins_fixture()
	inf <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_values$robins_s_beta_hat_T)  # confirms this exercises the "no cache yet" path
	local_mocked_bindings(compute_extended_robins_block_se_cpp = function(...) 0, .package = "EDI")

	res <- p$get_standard_error()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "extended_robins_standard_error_unavailable")
	expect_true(is.na(p$cached_values$robins_s_beta_hat_T))
})
