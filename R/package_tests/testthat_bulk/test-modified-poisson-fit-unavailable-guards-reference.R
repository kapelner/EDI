library(testthat)
library(EDI)

# InferenceIncidModifiedPoisson (inference_incidence_modified_poisson.R) has 2 distinct
# "modified_poisson_..._fit_unavailable" nonestimable guards -- generate_mod()'s own fit-
# reasonableness check (via is_modified_poisson_fit_reasonable(), reached whether or not hardening
# is exhausted) and compute_estimate_with_bootstrap_weights()'s identically-shaped weighted-refit
# guard -- neither of which had a test reference anywhere, unlike the sibling extreme-coefficient
# guards already covered for InferenceIncidProbit and (this session) InferenceIncidLogBinomial.
#
# Unlike log-link binomial/binomial-identity, no organic fixture reliably drove
# is_modified_poisson_fit_reasonable() to reject a real fit within the class's default thresholds
# (max_abs_reasonable_coef/max_abs_reasonable_linear_predictor = 25): even fully separated response
# data converged to coefficients just under the default cap once hardening dropped a column. The
# guard is real and independently unit-tested via its own logic (component checks: NULL/non-finite
# coefficients, non-convergence, |coefficient| or |linear predictor| too large), so it is exercised
# here directly by overriding the private predicate to force a rejection -- the same
# unlockBinding()-based private-method-override technique this suite already uses for other
# structurally-real-but-not-organically-reachable guards.

test_that("generate_mod()'s own fit-reasonableness guard fires with 'modified_poisson_fit_unavailable'", {
	set.seed(1); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	for (harden in c(TRUE, FALSE)) {
		inf <- InferenceIncidModifiedPoisson$new(des, harden = harden, verbose = FALSE)
		p <- inf$.__enclos_env__$private
		unlockBinding("is_modified_poisson_fit_reasonable", p)
		p$is_modified_poisson_fit_reasonable <- function(...) FALSE

		res <- p$generate_mod(estimate_only = TRUE)
		expect_null(res, info = harden)
		expect_identical(inf$get_nonestimable_reason(), "modified_poisson_fit_unavailable", info = harden)
	}
})

test_that("compute_estimate_with_bootstrap_weights()'s own guard fires with 'modified_poisson_weighted_fit_unavailable'", {
	set.seed(2); n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 2L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	inf <- InferenceIncidModifiedPoisson$new(des, harden = TRUE, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	unlockBinding("is_modified_poisson_fit_reasonable", p)
	p$is_modified_poisson_fit_reasonable <- function(...) FALSE

	res <- p$weighted_refit_impl(rep(1, n))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "modified_poisson_weighted_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T))
})
