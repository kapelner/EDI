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
# An all-ones incidence response (mu pinned at the probability boundary) reliably makes the IRLS
# fitter fail to converge, driving both guards.

test_that("generate_mod()'s own fit-reasonableness guard fires with 'log_binomial_fit_unavailable' before the outer wrapper's generic reason overwrites it", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(1L, n))

	for (harden in c(TRUE, FALSE)) {
		inf <- InferenceIncidLogBinomial$new(des, harden = harden, verbose = FALSE)
		p <- inf$.__enclos_env__$private
		res <- p$generate_mod(estimate_only = TRUE)
		expect_null(res, info = harden)
		expect_identical(inf$get_nonestimable_reason(), "log_binomial_fit_unavailable", info = harden)

		# through the public API, the outer wrapper's own NULL-mod check re-caches a generic reason
		inf2 <- InferenceIncidLogBinomial$new(des, harden = harden, verbose = FALSE)
		expect_true(is.na(inf2$compute_estimate()))
		expect_identical(inf2$get_nonestimable_reason(), "model_fit_unavailable", info = harden)
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
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	set.seed(2); wt <- rexp(n)
	res <- p$weighted_refit_impl(wt)
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "log_binomial_weighted_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T))
})
