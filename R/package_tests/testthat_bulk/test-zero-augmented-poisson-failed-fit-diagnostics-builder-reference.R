library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract's private zero_augmented_failed_fit_diagnostics(fit,
# exception_message) (inference_count_zero_augmented_poisson_abstract.R) shapes a diagnostic summary
# list from a (possibly partial/failed) fit object -- called from generate_mod()'s error-handling
# paths whenever the hurdle/zero-inflated Poisson optimizer fails to converge or throws, to attach
# useful diagnostics to the cached failure rather than a bare NA. A codebase-wide grep confirmed this
# method had zero test references anywhere. Exercised here via direct private-method calls on a real
# InferenceCountHurdlePoisson instance with hand-built `fit` objects, independent of the real
# optimizer's actual failure modes (already tested elsewhere):
#   1. A complete fit object populates every field, preferring the caller-supplied exception_message
#      over the fit's own, and using "fisher_information" for the information field.
#   2. A minimal/empty fit object (only its own exception_message) falls back to NA/NULL/FALSE
#      defaults everywhere else, and falls back to the fit's own exception_message when the caller
#      doesn't supply one.
#   3. The information field falls back through information -> fisher_information -> observed_
#      information, in that priority order (via %||%).

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * w)))
	InferenceCountHurdlePoisson$new(des, verbose = FALSE)
}

test_that("a complete fit object populates every diagnostic field, preferring the caller-supplied exception_message", {
	inf <- fx(1L)
	priv <- inf$.__enclos_env__$private
	fit <- list(
		converged = FALSE, hit_iteration_cap = TRUE, num_iter = 100L,
		gradient_norm = 0.5, min_eigenvalue_information = -0.1,
		params = c(1, 2, 3), fisher_information = diag(3),
		exception_message = "fit's own message"
	)
	out <- priv$zero_augmented_failed_fit_diagnostics(fit, exception_message = "caller message")
	expect_identical(out$family, priv$za_description())
	expect_false(out$converged)
	expect_true(out$hit_iteration_cap)
	expect_equal(out$num_iter, 100L)
	expect_equal(out$gradient_norm, 0.5)
	expect_equal(out$min_eigenvalue_information, -0.1)
	expect_equal(out$params, c(1, 2, 3))
	expect_identical(out$params_origin, "optimizer terminal state")
	expect_equal(out$information, diag(3))
	expect_identical(out$exception_message, "caller message")
})

test_that("a minimal fit object falls back to NA/NULL/FALSE defaults, and falls back to the fit's own exception_message when the caller supplies none", {
	inf <- fx(2L)
	priv <- inf$.__enclos_env__$private
	fit_minimal <- list(exception_message = "inner failure")
	out <- priv$zero_augmented_failed_fit_diagnostics(fit_minimal, exception_message = NULL)
	expect_false(out$converged)
	expect_false(out$hit_iteration_cap)
	expect_true(is.na(out$num_iter))
	expect_true(is.na(out$gradient_norm))
	expect_true(is.na(out$min_eigenvalue_information))
	expect_null(out$params)
	expect_null(out$information)
	expect_identical(out$exception_message, "inner failure")
})

test_that("the information field falls back through information -> fisher_information -> observed_information in priority order", {
	inf <- fx(3L)
	priv <- inf$.__enclos_env__$private

	out_info <- priv$zero_augmented_failed_fit_diagnostics(list(information = matrix(1, 1, 1), fisher_information = matrix(2, 1, 1)))
	expect_equal(out_info$information, matrix(1, 1, 1))

	out_fisher <- priv$zero_augmented_failed_fit_diagnostics(list(fisher_information = matrix(2, 1, 1), observed_information = matrix(3, 1, 1)))
	expect_equal(out_fisher$information, matrix(2, 1, 1))

	out_observed <- priv$zero_augmented_failed_fit_diagnostics(list(observed_information = matrix(3, 1, 1)))
	expect_equal(out_observed$information, matrix(3, 1, 1))
})
