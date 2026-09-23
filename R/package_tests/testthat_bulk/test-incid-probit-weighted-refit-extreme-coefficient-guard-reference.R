library(testthat)
library(EDI)

# InferenceIncidProbitRegr$compute_estimate_with_bootstrap_weights() (inference_incidence_probit.R)
# uses the same is_probit_fit_reasonable() coefficient-plausibility guard as generate_mod(), caching
# "probit_regression_weighted_extreme_coefficients" when the hardened weighted refit is unreasonable.
# The unweighted sibling guard ("probit_regression_extreme_coefficients") is already covered
# (test-incid-probit-is-fit-reasonable-and-extreme-coefficient-nonestimable-wiring-reference.R,
# including its own "reason gets clobbered by the outer shared() wrapper" behavior), but this
# weighted-refit call site had no test reference anywhere. Reached the same way: overriding the
# private predicate via unlockBinding() to force every candidate fit to be rejected. The public
# compute_estimate_with_bootstrap_weights() method runs isolated (the isolation-wrapper mechanism
# documented in inference_all_abstract.R and already used by this session's InferenceContinLin/
# InferenceIncidBinomialIdentityRiskDiff tests), so private$weighted_refit_impl() -- the pre-wrap
# implementation -- is called directly to inspect the cache it fills.

test_that("compute_estimate_with_bootstrap_weights()'s own guard fires with 'probit_regression_weighted_extreme_coefficients'", {
	set.seed(7); n <- 60L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.5 * w)))

	inf <- InferenceIncidProbitRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	unlockBinding("is_probit_fit_reasonable", p)
	p$is_probit_fit_reasonable <- function(mod) FALSE  # force every candidate fit to be rejected

	res <- p$weighted_refit_impl(rep(1, n))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "probit_regression_weighted_extreme_coefficients")
	expect_true(is.na(p$cached_values$beta_hat_T))
})

test_that("a caller-supplied max_abs_reasonable_coef also governs the weighted-refit guard, matching the already-tested unweighted predicate", {
	set.seed(8); n <- 40L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.5 * w)))

	inf <- InferenceIncidProbitRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	p$max_abs_reasonable_coef <- 0  # any nonzero fitted coefficient is now "extreme"

	res <- p$weighted_refit_impl(rep(1, n))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "probit_regression_weighted_extreme_coefficients")
})
