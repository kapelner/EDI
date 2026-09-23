library(testthat)
library(EDI)

# InferencePropZeroOneInflatedBetaRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_proportion_zero_one_inflated_beta.R) had no test reference anywhere. Unlike every
# sibling class in this session's randomization-estimate series, this method calls
# fast_zero_one_inflated_beta_cpp() directly -- the exact function this session's standing Avoid
# list flags as intermittently crash-prone. To stay safely away from that crash risk entirely (not
# just in the method under test, but also in the compute_estimate() call needed to first populate
# private$best_X_colnames), fast_zero_one_inflated_beta_cpp() is mocked to a cheap deterministic stub
# for the full duration of every test_that() block here, including the initial compute_estimate()
# call -- the real backend is never invoked anywhere in this file.
#   1. A finite private$cached_vc_params of the right length takes the fixed-dispersion path:
#      fixed_idx/fixed_values are passed to the fitter, covering the full vc_start:(vc_start+n_vc-1)
#      range -- verified by capturing the mock's own call arguments directly.
#   2. Without a usable cached_vc_params, no fixed_idx/fixed_values are passed.
#   3. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   4. A fitter failure (res NULL, too-short res$b, or non-finite res$b[2]) returns NA.

zoib_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(response_type = "proportion", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(plogis(rnorm(n) + 0.5 * des$get_w()))
	InferencePropZeroOneInflatedBetaRegr$new(des, verbose = FALSE)
}

mock_zoib_fit <- function(b2 = 0.4) {
	function(X, X_zero_one, y, ..., fixed_idx = NULL, fixed_values = NULL) {
		p <- ncol(X); q <- ncol(X_zero_one)
		start_len <- p + 1L + 2L * q
		list(
			b = c(0, b2, rep(0, p - 2L)),
			params = rep(0.1, start_len),
			phi = 5,
			fisher_information = diag(start_len),
			converged = TRUE
		)
	}
}

test_that("a finite cached_vc_params of the right length takes the fixed-dispersion path (fixed_idx/fixed_values passed)", {
	f <- local({
		local_mocked_bindings(fast_zero_one_inflated_beta_cpp = mock_zoib_fit(), .package = "EDI")
		inf <- zoib_fixture()
		inf$compute_estimate()
		inf
	})
	p <- f$.__enclos_env__$private
	p_ncol <- length(p$best_X_colnames) + 2L
	q_ncol <- length(p$best_X_zero_one_colnames) + 2L
	n_vc <- 1L + 2L * q_ncol
	p$cached_vc_params <- rep(0.2, n_vc)

	captured <- NULL
	local_mocked_bindings(
		fast_zero_one_inflated_beta_cpp = function(X, X_zero_one, y, ..., fixed_idx = NULL, fixed_values = NULL) {
			captured <<- list(fixed_idx = fixed_idx, fixed_values = fixed_values)
			mock_zoib_fit()(X, X_zero_one, y, fixed_idx = fixed_idx, fixed_values = fixed_values)
		},
		.package = "EDI"
	)
	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.4)
	expect_equal(captured$fixed_idx, as.integer((p_ncol + 1L):(p_ncol + n_vc)))
	expect_equal(captured$fixed_values, rep(0.2, n_vc))
})

test_that("without a usable cached_vc_params, no fixed_idx/fixed_values are passed", {
	f <- local({
		local_mocked_bindings(fast_zero_one_inflated_beta_cpp = mock_zoib_fit(), .package = "EDI")
		inf <- zoib_fixture(seed = 2L)
		inf$compute_estimate()
		inf
	})
	p <- f$.__enclos_env__$private
	p$cached_vc_params <- NULL

	captured <- NULL
	local_mocked_bindings(
		fast_zero_one_inflated_beta_cpp = function(X, X_zero_one, y, ..., fixed_idx = NULL, fixed_values = NULL) {
			captured <<- list(fixed_idx = fixed_idx, fixed_values = fixed_values)
			mock_zoib_fit()(X, X_zero_one, y, fixed_idx = fixed_idx, fixed_values = fixed_values)
		},
		.package = "EDI"
	)
	p$compute_treatment_estimate_during_randomization_inference()
	expect_null(captured$fixed_idx)
	expect_null(captured$fixed_values)
})

test_that("without prior column selection it calls shared() first", {
	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = mock_zoib_fit(), .package = "EDI")
	f <- zoib_fixture(seed = 3L)
	p <- f$.__enclos_env__$private
	expect_null(p$best_X_colnames)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(res))
	expect_false(is.null(p$best_X_colnames))
})

test_that("a fitter failure (res NULL, too-short res$b, or non-finite res$b[2]) returns NA", {
	f <- local({
		local_mocked_bindings(fast_zero_one_inflated_beta_cpp = mock_zoib_fit(), .package = "EDI")
		inf <- zoib_fixture(seed = 4L)
		inf$compute_estimate()
		inf
	})
	p <- f$.__enclos_env__$private

	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) list(b = c(0.5)), .package = "EDI")
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_zero_one_inflated_beta_cpp = function(X, ...) list(b = c(0, NA_real_, rep(0, ncol(X) - 2L)), params = rep(0, 5), phi = 5),
		.package = "EDI"
	)
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})
