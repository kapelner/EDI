library(testthat)
library(EDI)

# inference_all_abstract_rand.R's compute_randomization_worker_estimate() -- the reusable-worker
# estimator entry point for randomization draws (used only when supports_reusable_bootstrap_worker()
# is TRUE) -- delegates to private$compute_bootstrap_worker_estimate() and stop()s "No reusable-
# worker estimator is available for randomization draws." if that method isn't a function. Every
# concrete class composing InferenceNonParamBootstrap always has compute_bootstrap_worker_estimate
# defined (either a real override or the shared base stub that itself stop()s "Reusable bootstrap
# workers are not implemented for this class."), so this guard is never naturally reachable through
# any current class's construction -- exercised the same way this session has tested other
# structurally-real-but-not-naturally-reachable guards: directly nulling the private method on an
# already-constructed object. Zero test references anywhere.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("compute_randomization_worker_estimate(): a normal instance has a real estimator function, no error dispatching to it", {
	priv <- fx(seed = 1L)
	expect_true(is.function(priv[["compute_bootstrap_worker_estimate"]]))
})

test_that("compute_randomization_worker_estimate(): a missing estimator function errors with the documented message", {
	priv <- fx(seed = 2L)
	unlockBinding("compute_bootstrap_worker_estimate", priv)
	priv$compute_bootstrap_worker_estimate <- NULL

	expect_error(
		priv$compute_randomization_worker_estimate(list()),
		"No reusable-worker estimator is available for randomization draws\\."
	)
})
