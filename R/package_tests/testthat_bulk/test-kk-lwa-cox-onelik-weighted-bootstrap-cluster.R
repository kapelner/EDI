library(testthat)
library(EDI)

# InferenceSurvivalKKLWACoxPHOneLik$compute_estimate_with_bootstrap_weights()
# (inference_survival_KK_lwa_cox_one_lik_abstract.R) dispatches to the shared
# weighted_cox_bootstrap_surrogate_fit() helper (globals.R), which is only
# helper-level tested elsewhere (test-cox-component-composition.R, no cluster
# argument) and only class-referenced by name in migration-golden/mixin-
# contract tests -- grepped for "KKLWACox" together with "bootstrap_weights"
# across testthat/testthat_bulk/R/EDI/tests/testthat: no direct call found.
# Like the already-covered KK-Weibull-marginal sibling, the Bayesian-bootstrap
# "units" here are KK pair/reservoir clusters (private$m), not individual
# subjects, so row weights are constant WITHIN a matched pair -- a distinct
# expansion path worth its own direct verification against an independent
# weighted survival::coxph fit.

make_kk_lwa_cox_onelik_fixture <- function(n = 24L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i]) * rexp(1L)
		cens <- rexp(1L, rate = 0.15)
		if (y_lat <= cens) {
			des$add_one_subject_response(i, y = max(y_lat, 0.05))
		} else {
			des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
		}
	}
	inf <- InferenceSurvivalKKLWACoxPHOneLik$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(inf = inf, priv = priv)
}

test_that("compute_estimate_with_bootstrap_weights matches an independent weighted coxph fit with pair-constant row weights", {
	f <- make_kk_lwa_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	expect_true(ctx$n_units < f$priv$n)

	set.seed(1)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(unit_weights)

	# Both members of a matched pair receive the identical expanded weight.
	m_vec <- f$priv$m
	m_vec[is.na(m_vec)] <- 0L
	for (m0 in setdiff(unique(m_vec), 0L)) {
		expect_equal(length(unique(row_weights[m_vec == m0])), 1L)
	}

	est <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	X_fit <- cbind(treatment = f$priv$w, f$priv$get_X())
	dat <- as.data.frame(X_fit)
	dat$time <- f$priv$y
	dat$dead <- f$priv$dead
	ref <- survival::coxph(
		stats::as.formula(paste0("Surv(time, dead) ~ ", paste(colnames(X_fit), collapse = " + "))),
		data = dat, weights = row_weights
	)
	expect_equal(est, unname(coef(ref)["treatment"]), tolerance = 1e-6)

	# estimate_only doesn't change the point estimate for this fast surrogate path.
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE), est)
	# this fast surrogate path never populates an SE.
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})

test_that("effectively-constant unit weights shortcut to the primary MLE rather than the cluster surrogate", {
	f <- make_kk_lwa_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	direct <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))[1L]

	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_equal(shortcut, direct, tolerance = 1e-8)

	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(3.5, ctx$n_units))
	expect_equal(scaled, direct, tolerance = 1e-8)

	set.seed(2)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	expect_false(isTRUE(all.equal(weighted, direct)))
})

test_that("degenerate all-zero unit weights make the surrogate fit fail and return NA", {
	f <- make_kk_lwa_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	result <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, ctx$n_units))
	expect_true(is.na(result))
})
