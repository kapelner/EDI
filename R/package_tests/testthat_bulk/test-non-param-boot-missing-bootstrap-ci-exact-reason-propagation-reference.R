library(testthat)
library(EDI)

# InferenceNonParamBootstrap's private missing_bootstrap_ci() (inference_all_abstract_non_param_boot.R)
# already has direct test coverage (test-non-param-boot-extreme-guards-and-replication-stats-reference.R)
# of its named-NA-interval shape and of is_nonestimable() flipping TRUE at the requested stage, but that
# test passes literal reason strings ("bootstrap_unavailable_reason" / "se_reason") without ever
# asserting that get_nonestimable_reason() actually returns the SAME string it was given -- confirmed
# via a zero-hit grep for get_nonestimable_reason()/nonestimable_reason in that file. This closes the
# exact-propagation gap directly: the "reason" argument must pass through unchanged to whichever of
# cache_nonestimable_estimate()/cache_nonestimable_se() the "stage" argument selects.

boot_priv <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.3))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("stage = 'estimate' propagates the exact reason string via get_nonestimable_reason()", {
	f <- boot_priv()
	f$priv$missing_bootstrap_ci(0.1, "bootstrap_unavailable_reason", stage = "estimate")
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_unavailable_reason")
})

test_that("stage = 'se' propagates the exact reason string via get_nonestimable_reason()", {
	f <- boot_priv()
	f$priv$missing_bootstrap_ci(0.05, "se_reason", stage = "se")
	expect_identical(f$inf$get_nonestimable_reason(), "se_reason")
})
