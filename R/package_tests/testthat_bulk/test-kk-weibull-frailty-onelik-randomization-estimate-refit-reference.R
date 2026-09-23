library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik's compute_treatment_estimate_during_randomization_
# inference() (inference_survival_GLMM_weibull_frailty_normal.R) had no test reference anywhere.
# Unlike every sibling class in this session's randomization-estimate-override series, this one does
# NOT fall back to self$compute_estimate() when best_X_colnames stays unavailable -- it returns
# NA_real_ directly. It also, unlike any sibling except InferencePropBetaRegr/InferenceCountNegBin,
# has a fast fixed-dispersion path (fixed_idx/fixed_values pinning log_sigma_eps/log_sigma_u from
# private$cached_vc_params) that's tried FIRST and, if it converges, short-circuits the full refit
# entirely (the siblings' fixed-dispersion paths only pin a single scalar and still make one
# fitter call either way). Because this is a random-intercept frailty Weibull model without the main
# fit's hardened QR column-dropping retry ladder, organic convergence on freshly-simulated data is
# unreliable enough (confirmed empirically: even n = 150 with a 90% event rate sometimes failed to
# converge where the main hardened fit succeeded) that every branch here is reached by mocking
# fast_weibull_frailty_cpp() directly (unlockBinding is not needed -- local_mocked_bindings suffices)
# rather than relying on an independent-reference happy path.
#   1. best_X_colnames still unavailable after shared_combined_likelihood() -> NA_real_ directly (no
#      compute_estimate() fallback, unlike every sibling).
#   2. A finite cached_vc_params takes the fast fixed-dispersion path FIRST: fixed_idx/fixed_values
#      are passed, and a converged finite result short-circuits without ever calling the fitter a
#      second time.
#   3. The fast path's converged-but-then-fallthrough case: if the fixed-dispersion attempt fails (or
#      cached_vc_params isn't finite), the full (unfixed) refit is attempted instead.
#   4. Both attempts failing (NULL, not converged, or non-finite b[1]) returns NA.

frailty_fixture <- function(seed = 2L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))
	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("returns NA_real_ directly (no compute_estimate() fallback) when best_X_colnames stays unavailable", {
	f <- frailty_fixture()
	p <- f$priv
	unlockBinding("shared_combined_likelihood", p)
	p$shared_combined_likelihood <- function(...) invisible(NULL)  # never populates best_X_colnames

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.na(res))
})

test_that("a finite cached_vc_params takes the fast fixed-dispersion path and short-circuits on convergence", {
	f <- frailty_fixture(seed = 3L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- c(-0.2, -0.5)

	call_count <- 0
	local_mocked_bindings(
		fast_weibull_frailty_cpp = function(X, y, dead, group_id, ..., fixed_idx = NULL, fixed_values = NULL) {
			call_count <<- call_count + 1
			expect_equal(fixed_idx, c(ncol(X) + 1L, ncol(X) + 2L))
			expect_equal(fixed_values, c(-0.2, -0.5))
			list(converged = TRUE, b = c(0.42, rep(0, ncol(X) - 1L)))
		},
		.package = "EDI"
	)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.42)
	expect_equal(call_count, 1L)  # short-circuited: the full (unfixed) refit was never attempted
})

test_that("without a usable cached_vc_params, the full (unfixed) refit is attempted directly", {
	f <- frailty_fixture(seed = 4L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- NA_real_

	local_mocked_bindings(
		fast_weibull_frailty_cpp = function(X, y, dead, group_id, ..., fixed_idx = NULL, fixed_values = NULL) {
			expect_null(fixed_idx)
			expect_null(fixed_values)
			list(converged = TRUE, b = c(-0.17, rep(0, ncol(X) - 1L)))
		},
		.package = "EDI"
	)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, -0.17)
})

test_that("a failed refit (NULL, not converged, or non-finite b[1]) returns NA", {
	f <- frailty_fixture(seed = 5L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- NA_real_

	local_mocked_bindings(fast_weibull_frailty_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_weibull_frailty_cpp = function(X, ...) list(converged = FALSE, b = c(0.1, rep(0, ncol(X) - 1L))),
		.package = "EDI"
	)
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_weibull_frailty_cpp = function(X, ...) list(converged = TRUE, b = c(NA_real_, rep(0, ncol(X) - 1L))),
		.package = "EDI"
	)
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})
