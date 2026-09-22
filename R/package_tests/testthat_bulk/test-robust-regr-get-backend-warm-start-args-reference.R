library(testthat)
library(EDI)

# InferenceContinRobustRegr's own get_backend_warm_start_args() (a thin private delegator to the
# shared InferenceAsymp$get_optimal_warm_start_config(), tier "medium" for this class) is only ever
# invoked internally by fit_rlm_model() when warm_start = TRUE -- but every existing fit_rlm_model()
# test (test-robust-regr-private-fit-rlm-model-backends-ci-controls-and-failed-cache-reference.R)
# calls it with the default warm_start = FALSE, so this class's own copy of the method (one of 4
# duplicate definitions of get_backend_warm_start_args() across the package) had never actually run.
# Before any fit, fit_warm_start_enabled is FALSE so every component is NULL; after a fit populates
# the shared warm-start cache via set_fit_warm_start(..., "beta"), a matching expected_length returns
# the cached beta as both start_beta/warm_start_beta (medium tier has no start_params/weights source
# here, since this class never calls set_fit_warm_start with a "params" type or weights), while a
# mismatched expected_length still returns all-NULL (the shared get_fit_warm_start_for_length() length
# guard).

fx <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w + 0.3 * X$x1)
	inf <- InferenceContinRobustRegr$new(d, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("get_backend_warm_start_args(): before any fit, every component is NULL", {
	f <- fx(seed = 1L)
	res <- f$priv$get_backend_warm_start_args(3L)
	expect_identical(res, list(start_beta = NULL, warm_start_beta = NULL, start_params = NULL, warm_start_weights = NULL))
})

test_that("get_backend_warm_start_args(): after a fit, a matching expected_length returns the cached beta", {
	f <- fx(seed = 2L)
	est <- f$inf$compute_estimate()
	expect_true(is.finite(as.numeric(est)[1]))
	expect_true(isTRUE(f$priv$fit_warm_start_enabled))
	expect_identical(f$priv$fit_warm_start_type, "beta")

	p <- length(f$priv$fit_warm_start)
	expect_gte(p, 3L)                                         # intercept + treatment + >=1 covariate

	res <- f$priv$get_backend_warm_start_args(p)
	expect_identical(res$start_beta, f$priv$fit_warm_start)
	expect_identical(res$warm_start_beta, f$priv$fit_warm_start)
	expect_null(res$start_params)
	expect_null(res$warm_start_weights)
})

test_that("get_backend_warm_start_args(): after a fit, a mismatched expected_length still returns all-NULL", {
	f <- fx(seed = 3L)
	f$inf$compute_estimate()
	p <- length(f$priv$fit_warm_start)

	res <- f$priv$get_backend_warm_start_args(p + 5L)
	expect_identical(res, list(start_beta = NULL, warm_start_beta = NULL, start_params = NULL, warm_start_weights = NULL))
})

test_that("integration: fit_rlm_model(warm_start = TRUE) runs to completion using the cached warm start, no error", {
	f <- fx(seed = 4L)
	f$inf$compute_estimate()
	X_fit <- cbind(1, treatment = f$priv$w, f$priv$get_X()[, f$priv$best_X_colnames, drop = FALSE])
	expect_no_error(fit2 <- f$priv$fit_rlm_model(X_fit, estimate_only = FALSE, warm_start = TRUE))
	expect_true(!is.null(fit2))
})
