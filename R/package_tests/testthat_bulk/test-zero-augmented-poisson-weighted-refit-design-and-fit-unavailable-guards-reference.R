library(testthat)
library(EDI)

# InferenceCountZeroInflatedPoisson$compute_estimate_with_bootstrap_weights()
# (inference_count_zero_augmented_poisson_abstract.R) has 3 sequential nonestimable guards before it
# ever calls glmmTMB, none of which had a test reference anywhere:
#   1. "zero_augmented_poisson_design_unusable": the count-submodel design matrix can't be built.
#   2. "zero_augmented_poisson_aux_design_unusable": the count-submodel design succeeds, but the
#      zero-inflation-submodel design matrix can't be built.
#   3. "zero_augmented_poisson_weighted_fit_unavailable": both designs are usable, but
#      fit_zero_augmented_model() itself returns NULL.
# Reached via InferenceCountZeroInflatedPoisson by mocking the exact private method each site calls
# (build_component_matrix, called once per submodel -- branch 2's fixture lets the first call
# through to the real implementation and only fails the second; fit_zero_augmented_model), the same
# techniques already used elsewhere in this suite (including this session's InferenceCountHurdleNegBin
# reference test, which closed the identically-shaped sibling guards on that class) for analogous
# unreachable-in-practice failure paths. The public method runs isolated (the isolation-wrapper
# mechanism documented in inference_all_abstract.R), so private$weighted_refit_impl() -- the pre-wrap
# implementation -- is called directly to inspect the cache it fills.

zap_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.3 * X$x1 + 0.5 * des$get_w() + 1)) * rbinom(n, 1, 0.7))
	des
}

test_that("'zero_augmented_poisson_design_unusable' fires when the count-submodel design can't be built", {
	des <- zap_fixture()
	inf <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	unlockBinding("build_component_matrix", p)
	p$build_component_matrix <- function(...) NULL

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "zero_augmented_poisson_design_unusable")
})

test_that("'zero_augmented_poisson_aux_design_unusable' fires when only the zero-inflation-submodel design fails", {
	des <- zap_fixture(seed = 2L)
	inf <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	orig <- p$build_component_matrix
	call_count <- 0
	unlockBinding("build_component_matrix", p)
	p$build_component_matrix <- function(...) {
		call_count <<- call_count + 1
		if (call_count == 1) orig(...) else NULL  # count submodel succeeds, zero-inflation submodel fails
	}

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "zero_augmented_poisson_aux_design_unusable")
	expect_equal(call_count, 2L)
})

test_that("'zero_augmented_poisson_weighted_fit_unavailable' fires when fit_zero_augmented_model() fails", {
	des <- zap_fixture(seed = 3L)
	inf <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	unlockBinding("fit_zero_augmented_model", p)
	p$fit_zero_augmented_model <- function(...) NULL

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "zero_augmented_poisson_weighted_fit_unavailable")
})
