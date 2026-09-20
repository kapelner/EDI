library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullMarginal$compute_estimate_with_bootstrap_weights()
# (inference_survival_KK_weibull_marginal.R:63-82) is exercised indirectly by
# the class's migration-golden test via approximate_bootstrap_distribution_beta_hat_T(),
# but that only checks legacy-vs-migrated equivalence under random weights, never
# an independent numerical reference. It also differs from the already-covered
# InferenceSurvivalWeibullRegr caller of the shared weighted_weibull_bootstrap_surrogate_fit()
# helper: here the Bayesian-bootstrap "units" are KK pair/reservoir clusters
# (private$get_cluster_ids()), not individual subjects, so row weights are
# constant WITHIN a matched pair -- a distinct expansion path
# (expand_subject_or_block_weights_to_row_weights() against a match-structure
# context) worth its own direct verification.

make_kk_weibull_marginal_fixture <- function(n = 24L, seed = 20260918L) {
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
	inf <- InferenceSurvivalKKWeibullMarginal$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(inf = inf, priv = priv)
}

test_that("compute_estimate_with_bootstrap_weights matches an independent survreg fit with pair-constant row weights", {
	f <- make_kk_weibull_marginal_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	# Bootstrap units are KK clusters (pairs + reservoir singletons), not subjects.
	expect_true(ctx$n_units < f$priv$des_obj$get_n())
	expect_equal(ctx$n_units, length(unique(f$priv$get_cluster_ids())))

	set.seed(1)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(unit_weights)
	# Both members of a matched pair receive the identical expanded weight.
	cluster_ids <- f$priv$get_cluster_ids()
	for (cid in unique(cluster_ids)) {
		rw_in_cluster <- row_weights[cluster_ids == cid]
		expect_equal(length(unique(rw_in_cluster)), 1L)
	}

	est <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	X_fit <- cbind(treatment = f$priv$w, f$priv$get_X())
	ref <- survival::survreg(survival::Surv(f$priv$y, f$priv$dead) ~ X_fit, weights = row_weights, dist = "weibull")
	expect_equal(est, unname(coef(ref)["X_fittreatment"]), tolerance = 1e-8)

	# estimate_only doesn't change the point estimate for this fast surrogate path
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE), est)
	# this fast surrogate path never populates an SE
	expect_true(is.na(f$priv$last_weighted_refit$s_beta_hat_T))
})

test_that("effectively-constant unit weights shortcut to the primary MLE rather than the cluster surrogate", {
	f <- make_kk_weibull_marginal_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	direct <- f$inf$compute_estimate(estimate_only = TRUE)

	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_equal(shortcut, direct)

	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(3.5, ctx$n_units))
	expect_equal(scaled, direct)

	set.seed(2)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	expect_false(isTRUE(all.equal(weighted, direct)))
})
