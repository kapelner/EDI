library(testthat)
library(EDI)

# InferenceIncidLogBinomial (inference_incidence_log_binomial.R) has 2 distinct
# "log_binomial_..._fit_unavailable" nonestimable guards -- generate_mod()'s own fit-reasonableness
# check (via is_log_binomial_fit_reasonable()), reached whether or not hardening is exhausted, and
# compute_estimate_with_bootstrap_weights()'s identically-shaped weighted-refit guard -- neither of
# which had a test reference anywhere.
#
# generate_mod()'s own guard is structurally real but its cached reason is always immediately
# overwritten by a more generic "model_fit_unavailable" set by the shared generate_mod()-wrapping
# InferenceAsympLikStdModCache mixin (inference_all_abstract_asymp_lik_std_mod_cache.R) once it
# observes generate_mod() returned NULL -- the same "reason gets clobbered by an outer wrapper"
# situation this suite has already documented for other classes' internal guards. Calling
# private$generate_mod() directly (bypassing the outer wrapper, the same technique already used
# elsewhere in this suite) observes the specific reason before it's overwritten.
#
# The guards are driven by mocking the three log-binomial kernels to return a non-converged fit,
# which is_log_binomial_fit_reasonable() rejects. Until 2026-11-18 an all-ones response did this
# for real (the cold start sat outside the mean support and the fit never moved); since
# v1.0.6-TODO-142 pulls such a start into the support, that fit converges to the correct boundary
# MLE (log RR = 0, with the boundary warning), checked by the last test below.
mock_unconverged_log_binomial <- function() {
	bad <- function(X, ...) list(b = rep(0, NCOL(X)), converged = FALSE, ssq_b_j = NA_real_)
	local_mocked_bindings(
		fast_log_binomial_regression_cpp = bad,
		fast_log_binomial_regression_with_var_cpp = bad,
		fast_log_binomial_regression_weighted_cpp = bad,
		.package = "EDI", .env = parent.frame()
	)
}

test_that("generate_mod()'s own fit-reasonableness guard fires with 'log_binomial_fit_unavailable' before the outer wrapper's generic reason overwrites it", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))

	mock_unconverged_log_binomial()
	for (harden in c(TRUE, FALSE)) {
		inf <- InferenceIncidLogBinomial$new(des, harden = harden, verbose = FALSE)
		p <- inf$.__enclos_env__$private
		res <- p$generate_mod(estimate_only = TRUE)
		expect_null(res, info = paste("harden =", harden))
		expect_identical(inf$get_nonestimable_reason(), "log_binomial_fit_unavailable", info = paste("harden =", harden))

		# through the public API, the outer wrapper's own NULL-mod check re-caches a generic reason
		inf2 <- InferenceIncidLogBinomial$new(des, harden = harden, verbose = FALSE)
		expect_true(is.na(inf2$compute_estimate()))
		expect_identical(inf2$get_nonestimable_reason(), "model_fit_unavailable", info = paste("harden =", harden))
	}
})

test_that("compute_estimate_with_bootstrap_weights()'s own guard fires with 'log_binomial_weighted_fit_unavailable'", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))

	inf <- InferenceIncidLogBinomial$new(des, harden = TRUE, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	mock_unconverged_log_binomial()
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	set.seed(2); wt <- rexp(n)
	res <- p$weighted_refit_impl(wt)
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "log_binomial_weighted_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T))
})

test_that("an all-ones response now fits: log RR = 0 at the boundary, with the boundary warning (v1.0.6-TODO-142)", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))
	inf <- InferenceIncidLogBinomial$new(des, harden = TRUE, verbose = FALSE)
	expect_warning(est <- inf$compute_estimate(), class = "edi_binomial_mle_boundary_warning")
	expect_equal(est, 0, tolerance = 1e-8)
	expect_false(inf$is_nonestimable("estimate"))
})
