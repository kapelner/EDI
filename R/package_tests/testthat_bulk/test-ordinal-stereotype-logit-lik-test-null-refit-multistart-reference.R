library(testthat)
library(EDI)

# InferenceOrdinalStereotypeLogitRegr's get_likelihood_test_spec()$fit_null(delta) (inference_ordinal_
# stereotype_logit.R:286-335) tries TWO starting points for the delta-constrained null refit -- the
# caller-supplied/warm-started point and a nudged version of the full unconstrained fit -- and keeps
# whichever converges to the lower neg_loglik. This is the ORIGINAL multi-start fix this session's
# InferenceOrdinalCloglogRegr fix explicitly cites as its own precedent ("same mechanism, same fix, as
# InferenceOrdinalStereotypeLogitRegr's null-refit"), and per its own comment is high-impact: a
# single-start constrained refit spuriously marked the null refit unusable and returned NA for
# compute_lik_ratio_two_sided_pval() on ~2/3 of real fits (200/300 in a direct reproduction) before the
# fix. Despite this severity, a codebase-wide grep confirmed zero test references anywhere for the
# multi-start SELECTION mechanic itself: the class is exercised in the generic parametric-bootstrap-LR
# smoke test and several other reference files, but none of them mock the underlying kernel to verify
# fit_null() actually picks the better of its two starts (as opposed to merely running without
# erroring). Exercised via the same technique as the cloglog sibling: mocking fast_stereotype_logit_cpp()
# to return controlled, distinguishable neg_loglik values per call, independent of any real optimization
# landscape. (stereotype_fit_is_usable()'s own guards are already covered elsewhere; called here with
# check_treatment = FALSE, require_information_pd = FALSE exactly as fit_null() does, so a converged
# mock fit with no fisher_information field passes it trivially.)

fx <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$compute_estimate()
	inf$.__enclos_env__$private$get_likelihood_test_spec()
}

test_that("when the second (nudged-full-fit) start converges to the lower neg_loglik, its fit is returned, not the first start's", {
	spec <- fx()
	call_n <- 0L
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(converged = TRUE, params = rep(0, length(warm_start_params)), neg_loglik = 100) else list(converged = TRUE, params = rep(1, length(warm_start_params)), neg_loglik = 50)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 50)
	expect_equal(call_n, 2L)  # both starts are always tried
})

test_that("when the first (caller-supplied/warm-started) start converges to the lower neg_loglik, its fit is returned instead", {
	spec <- fx()
	call_n <- 0L
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(converged = TRUE, params = rep(9, length(warm_start_params)), neg_loglik = 10) else list(converged = TRUE, params = rep(1, length(warm_start_params)), neg_loglik = 999)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 10)
})

test_that("when one start doesn't converge, the other's (successful) fit is used", {
	spec <- fx()
	call_n <- 0L
	local_mocked_bindings(
		fast_stereotype_logit_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(converged = FALSE) else list(converged = TRUE, params = rep(2, length(warm_start_params)), neg_loglik = 77)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 77)
})

test_that("when neither start converges, fit_null returns NULL", {
	spec <- fx()
	local_mocked_bindings(fast_stereotype_logit_cpp = function(...) list(converged = FALSE), .package = "EDI")
	expect_null(spec$fit_null(0.3))
})
