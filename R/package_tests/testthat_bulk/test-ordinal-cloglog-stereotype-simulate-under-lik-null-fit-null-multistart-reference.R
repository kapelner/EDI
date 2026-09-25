library(testthat)
library(EDI)

# InferenceOrdinalCloglogRegr and InferenceOrdinalStereotypeLogitRegr each have a SECOND copy of the
# multi-start fit_null(delta, start) closure -- inside simulate_under_lik_null() (inference_ordinal_
# cloglog.R:113-.../inference_ordinal_stereotype_logit.R:353-...), used by the parametric-bootstrap
# null-simulation path, distinct from the get_likelihood_test_spec() copy this session's two prior
# iterations already closed for both classes. Both copies were fixed together in the same commits (the
# ordinal_cumulative_link_null_refit_multistart.md bug-fix plan explicitly says "both fit_null closures
# now also try a second start"), but the two prior test files deliberately left this second copy
# untested to stay focused, confirmed via a codebase-wide grep to still have zero test references
# anywhere. Reached by calling simulate_under_lik_null(spec, delta, null_fit) directly (using the
# class's own real get_likelihood_test_spec() output as spec/null_fit) and mocking the underlying C++
# kernel to distinguish the unconstrained full refit (no fixed_idx) from the two constrained-refit
# starting points (fixed_idx present, distinguished by call order), verifying the SAME multi-start
# selection contract as the get_likelihood_test_spec() copy: keeps whichever start converges lower,
# falls back correctly when one fails, and returns NULL when both fail.

cloglog_sim <- function() {
	set.seed(1L); n <- 60L
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", seed = 1L, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(rnorm(n) + 0.3 * w, breaks = c(-Inf, -0.5, 0.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalCloglogRegr$new(des, model_formula = ~x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	inf$compute_estimate()
	spec <- priv$get_likelihood_test_spec()
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL, warm_start_params = NULL, smart_cold_start = TRUE) {
			list(params = rep(0.1, ncol(X)), neg_loglik = 42)  # the unconstrained full refit on simulated data
		},
		.package = "EDI"
	)
	list(priv = priv, sim = priv$simulate_under_lik_null(spec, delta = 0.3, null_fit = spec$full_fit))
}

stereotype_sim <- function() {
	set.seed(4L); n <- 200L
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	inf$compute_estimate()
	spec <- priv$get_likelihood_test_spec()
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, estimate_only = FALSE, warm_start_params = NULL, warm_start_fisher_info = NULL, fixed_idx = NULL, fixed_values = NULL) {
			list(converged = TRUE, b = 0.1, params = rep(0.1, length(warm_start_params)), neg_loglik = 42)  # the unconstrained full refit
		},
		.package = "EDI"
	)
	list(priv = priv, sim = priv$simulate_under_lik_null(spec, delta = 0.3, null_fit = spec$full_fit))
}

test_that("InferenceOrdinalCloglogRegr: simulate_under_lik_null() succeeds and its own fit_null() picks the lower-neg_loglik start, falls back on failure, and returns NULL if both fail", {
	f <- cloglog_sim()
	expect_false(is.null(f$sim))

	call_n <- 0L
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL, warm_start_params = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(params = rep(9, length(warm_start_params)), neg_loglik = 10) else list(params = rep(1, length(warm_start_params)), neg_loglik = 999)
		},
		.package = "EDI"
	)
	expect_equal(f$sim$fit_null(0.3)$neg_loglik, 10)

	call_n2 <- 0L
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL, warm_start_params = NULL, smart_cold_start = TRUE) {
			call_n2 <<- call_n2 + 1L
			if (call_n2 == 1L) stop("boom") else list(params = rep(2, length(warm_start_params)), neg_loglik = 77)
		},
		.package = "EDI"
	)
	expect_equal(f$sim$fit_null(0.3)$neg_loglik, 77)

	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL, warm_start_params = NULL, smart_cold_start = TRUE) NULL,
		.package = "EDI"
	)
	expect_null(f$sim$fit_null(0.3))
})

test_that("InferenceOrdinalStereotypeLogitRegr: simulate_under_lik_null() succeeds and its own fit_null() picks the lower-neg_loglik start, falls back on failure, and returns NULL if both fail", {
	f <- stereotype_sim()
	expect_false(is.null(f$sim))

	call_n <- 0L
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, estimate_only = FALSE, warm_start_params = NULL, warm_start_fisher_info = NULL, fixed_idx = NULL, fixed_values = NULL) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(converged = TRUE, params = rep(9, length(warm_start_params)), neg_loglik = 10) else list(converged = TRUE, params = rep(1, length(warm_start_params)), neg_loglik = 999)
		},
		.package = "EDI"
	)
	expect_equal(f$sim$fit_null(0.3)$neg_loglik, 10)

	call_n2 <- 0L
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, estimate_only = FALSE, warm_start_params = NULL, warm_start_fisher_info = NULL, fixed_idx = NULL, fixed_values = NULL) {
			call_n2 <<- call_n2 + 1L
			if (call_n2 == 1L) list(converged = FALSE) else list(converged = TRUE, params = rep(2, length(warm_start_params)), neg_loglik = 77)
		},
		.package = "EDI"
	)
	expect_equal(f$sim$fit_null(0.3)$neg_loglik, 77)

	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, estimate_only = FALSE, warm_start_params = NULL, warm_start_fisher_info = NULL, fixed_idx = NULL, fixed_values = NULL) list(converged = FALSE),
		.package = "EDI"
	)
	expect_null(f$sim$fit_null(0.3))
})
