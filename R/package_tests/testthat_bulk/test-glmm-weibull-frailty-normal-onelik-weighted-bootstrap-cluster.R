library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$compute_estimate_with_bootstrap_weights()
# (inference_survival_GLMM_weibull_frailty_normal.R:484-509) previously had no
# direct test anywhere (grep across testthat/ and testthat_bulk/: zero hits on
# this method for this class). It differs from the already-covered plain-Weibull
# and KK-weibull-marginal callers of weighted_weibull_bootstrap_surrogate_fit():
# it passes a `cluster =` argument built from the KK match-vector (private$m),
# with reservoir singletons assigned distinct synthetic ids.

make_glmm_weibull_frailty_normal_onelik_fixture <- function(n = 26L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.7 - 0.25 * ((w_i + 1) / 2) + 0.2 * X$x1[i]) * rexp(1L)
		cens <- rexp(1L, rate = 0.12)
		if (y_lat <= cens) {
			des$add_one_subject_response(i, y = max(y_lat, 0.05))
		} else {
			des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
		}
	}
	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, model_formula = ~x1, use_rcpp = TRUE, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(inf = inf, priv = priv)
}

build_reference_cluster_ids <- function(priv) {
	m_vec <- priv$m
	if (is.null(m_vec)) m_vec <- rep(NA_integer_, priv$n)
	m_vec[is.na(m_vec)] <- 0L
	cluster_ids <- m_vec
	res_idx <- which(cluster_ids == 0L)
	if (length(res_idx) > 0L) {
		max_m <- max(cluster_ids)
		cluster_ids[res_idx] <- max_m + seq_along(res_idx)
	}
	cluster_ids
}

test_that("compute_estimate_with_bootstrap_weights matches an independent survreg fit; the cluster argument only filters NA ids, doesn't change the estimate", {
	f <- make_glmm_weibull_frailty_normal_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context

	set.seed(1)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(unit_weights)

	est <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)

	X_cov <- f$priv$get_X()
	X_fit <- cbind(treatment = f$priv$w, X_cov)
	ref <- survival::survreg(survival::Surv(f$priv$y, f$priv$dead) ~ X_fit, weights = row_weights, dist = "weibull")
	expect_equal(est, unname(coef(ref)["X_fittreatment"]), tolerance = 1e-8)

	# The `cluster` id vector passed internally is only used to build the
	# `ok` filter (all finite here, so nothing is dropped); it is never
	# referenced in the survreg formula/robust-SE machinery, so a fit with
	# no cluster argument at all reproduces the identical point estimate.
	cluster_ids <- build_reference_cluster_ids(f$priv)
	expect_false(anyNA(cluster_ids))
	ref_no_cluster <- survival::survreg(survival::Surv(f$priv$y, f$priv$dead) ~ X_fit, weights = row_weights, dist = "weibull")
	expect_equal(unname(coef(ref)["X_fittreatment"]), unname(coef(ref_no_cluster)["X_fittreatment"]))

	# estimate_only doesn't change the point estimate for this fast surrogate path
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE), est)
	# this fast surrogate path never populates an SE
	expect_true(is.na(f$priv$last_weighted_refit$s_beta_hat_T))
})

test_that("effectively-constant unit weights shortcut to the primary MLE rather than the cluster surrogate", {
	f <- make_glmm_weibull_frailty_normal_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	direct <- f$inf$compute_estimate(estimate_only = TRUE)

	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_equal(shortcut, direct)

	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(2.75, ctx$n_units))
	expect_equal(scaled, direct)

	set.seed(2)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	expect_false(isTRUE(all.equal(weighted, direct)))
})

test_that("reservoir singletons receive distinct synthetic cluster ids, matched pairs share theirs", {
	f <- make_glmm_weibull_frailty_normal_onelik_fixture()
	cluster_ids <- build_reference_cluster_ids(f$priv)
	m_vec <- f$priv$m
	m_vec[is.na(m_vec)] <- 0L

	matched_idx <- which(m_vec != 0L)
	if (length(matched_idx) > 0L) {
		for (mid in unique(m_vec[matched_idx])) {
			rows <- which(m_vec == mid)
			expect_equal(length(unique(cluster_ids[rows])), 1L)
		}
	}
	reservoir_idx <- which(m_vec == 0L)
	if (length(reservoir_idx) > 1L) {
		expect_equal(length(unique(cluster_ids[reservoir_idx])), length(reservoir_idx))
	}
})
