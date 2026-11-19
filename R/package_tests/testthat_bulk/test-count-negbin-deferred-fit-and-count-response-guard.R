library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dd9d12703 (InferenceCountNegBin, R/EDI/R/inference_count_negbin.R initialize()):
#   - initialize() does not fit the model; the fit is deferred to the first compute_estimate();
#   - des_obj must be a completed Design with a count response.

nb_design <- function(response_type = "count", n = 60L, seed = 5L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = response_type, n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	y <- switch(response_type,
		count = rnbinom(n, mu = exp(0.5 + 0.4 * w), size = 2),
		incidence = rbinom(n, 1, 0.4),
		continuous = rnorm(n))
	d$add_all_subject_responses(y)
	d
}

test_that("construction does not fit; the first compute_estimate() does", {
	inf <- InferenceCountNegBin$new(nb_design(), verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_mod)
	expect_null(p$cached_values$beta_hat_T)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
	expect_false(is.null(p$cached_mod))
	expect_equal(p$cached_values$beta_hat_T, est)
})

test_that("non-count designs are rejected at construction", {
	expect_error(InferenceCountNegBin$new(nb_design("incidence")), "count")
	expect_error(InferenceCountNegBin$new(nb_design("continuous")), "count")
})
