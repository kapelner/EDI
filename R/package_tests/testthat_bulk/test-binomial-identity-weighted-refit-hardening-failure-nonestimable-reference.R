library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's compute_estimate_with_bootstrap_weights()
# (inference_incidence_binomial_identity.R, registry weighted_opportunity 35) is exercised
# extensively under normal/moderate weights in test-binomial-identity-weighted-refit-reference.R and
# R/EDI/tests/testthat/test-bayesian-bootstrap.R, but always against a fit that converges and passes
# is_identity_binomial_fit_reasonable(). The registry flagged the "weighted-refit hardening failure
# path (fit_ok returning FALSE after column-dropping)" as untested: when the weighted identity-link
# binomial fit does NOT converge (or its fitted mu falls outside [0, 1] even after
# fit_with_hardened_qr_column_dropping()'s rank-based column dropping), the class caches the result
# as nonestimable via cache_nonestimable_estimate("binomial_identity_weighted_fit_unavailable") and
# returns NA_real_, rather than propagating a garbage/non-converged coefficient.
#
# Extreme bootstrap weights put nearly all weight on the two most extreme-leverage rows (opposite
# responses, opposite ends of a wide covariate range), so the full-model weighted kernel fails to
# converge (verified directly below: fit$converged == FALSE). Until 2026-11-18 every hardened
# column subset failed too; since v1.0.6-TODO-142 pulls infeasible starts into the mean support,
# hardening drops x1 and converges to the correct boundary MLE (y == w in this fixture, so the risk
# difference is 1), checked by the last test below. The nonestimable branch is therefore driven by
# mocking the identity-binomial kernels to return a non-converged fit. Since
# compute_estimate_with_bootstrap_weights() runs through the shared weighted-refit
# snapshot/restore wrapper (inference_all_abstract.R, around line 530), the nonestimable
# reason/stage land on private$last_weighted_refit, not private$cached_values (which is rolled back
# to its pre-call state) -- confirmed directly this is NOT the main cache the class's own point
# estimate uses.

binomial_identity_extreme_fixture <- function() {
	n <- 12L
	x1 <- c(-50, -40, -30, -20, -10, 0, 0, 10, 20, 30, 40, 50)
	w <- rep(0:1, 6)
	y <- c(0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~x1, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, n = n)
}

mock_unconverged_identity_binomial <- function() {
	bad <- function(X, ...) list(b = rep(0, NCOL(X)), converged = FALSE, ssq_b_j = NA_real_)
	local_mocked_bindings(
		fast_identity_binomial_regression_cpp = bad,
		fast_identity_binomial_regression_with_var_cpp = bad,
		fast_identity_binomial_regression_weighted_cpp = bad,
		.package = "EDI", .env = parent.frame()
	)
}

extreme_weights <- function(n) {
	weights <- rep(0.0001, n)
	weights[c(1L, n)] <- 1000  # the two most extreme-leverage rows, opposite y values
	weights
}

test_that("an extreme weight concentration that fails to converge is cached as nonestimable and returns NA, not a garbage estimate", {
	f <- binomial_identity_extreme_fixture()
	mock_unconverged_identity_binomial()

	est <- f$inf$compute_estimate_with_bootstrap_weights(extreme_weights(f$n), estimate_only = TRUE)
	expect_true(is.na(est))

	refit <- f$inf$.__enclos_env__$private$last_weighted_refit
	expect_true(isTRUE(refit$nonestimable))
	expect_identical(refit$nonestimable_stage, "estimate")
	expect_identical(refit$nonestimable_reason, "binomial_identity_weighted_fit_unavailable")

	# the main point-estimate cache must be unaffected (rolled back by the snapshot/restore wrapper),
	# confirming this is a bootstrap-replicate-local failure, not corruption of the class's own state
	expect_null(f$inf$.__enclos_env__$private$cached_mod)
})

test_that("the same extreme weights genuinely fail to converge at the underlying kernel level (not merely rejected by a stricter downstream check)", {
	f <- binomial_identity_extreme_fixture()
	priv <- f$inf$.__enclos_env__$private
	weights <- rep(0.0001, f$n)
	weights[c(1L, 12L)] <- 1000
	row_weights <- priv$expand_subject_or_block_weights_to_row_weights(weights)
	X_full <- priv$build_design_matrix()

	fit <- fast_identity_binomial_regression_weighted_cpp(
		X = as.matrix(X_full), y = as.numeric(priv$y), weights = as.numeric(row_weights),
		warm_start_beta = NULL, warm_start_fisher_info = NULL
	)
	expect_false(isTRUE(fit$converged))
	expect_false(isTRUE(priv$is_identity_binomial_fit_reasonable(fit, X_full, 2L)))
})

test_that("with the real kernels, hardening drops x1 and the extreme-weight refit reaches the boundary MLE (v1.0.6-TODO-142)", {
	f <- binomial_identity_extreme_fixture()
	est <- suppressWarnings(
		f$inf$compute_estimate_with_bootstrap_weights(extreme_weights(f$n), estimate_only = TRUE),
		classes = "edi_covariate_dropped_warning"
	)
	expect_equal(est, 1, tolerance = 1e-5)
	refit <- f$inf$.__enclos_env__$private$last_weighted_refit
	expect_false(isTRUE(refit$nonestimable))
	expect_equal(length(refit$cached_mod$b), 2L)
})

test_that("moderate (non-extreme) weights on an ordinary well-behaved fixture converge normally and do not trigger the nonestimable path", {
	withr::local_seed(999)
	n <- 60L
	x1 <- rnorm(n, sd = 0.3)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, pmin(pmax(0.3 + 0.15 * w + 0.1 * x1, 0.02), 0.98))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~x1, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)

	est <- inf$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)
	expect_true(is.finite(est))
	refit <- inf$.__enclos_env__$private$last_weighted_refit
	expect_false(isTRUE(refit$nonestimable))
})
