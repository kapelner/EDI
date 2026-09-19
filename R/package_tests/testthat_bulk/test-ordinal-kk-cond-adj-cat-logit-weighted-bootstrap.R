library(testthat)
library(EDI)

# InferenceOrdinalKKCondAdjCatLogitRegr$compute_estimate_with_bootstrap_weights()
# has no existing test anywhere in the suite (grep confirms
# test-ordinal-kk-cond-adj-cat-logit-migration-golden.R and siblings only
# exercise compute_estimate()/asymptotic paths, not the weighted-bootstrap
# wrapper). It expands subject-level weights to row weights and delegates to
# the shared weighted_ordinal_bootstrap_surrogate_fit() helper on the raw
# (unexpanded) design matrix -- already independently verified elsewhere
# (test-weighted-ordinal-surrogate-cold-start-reference.R) -- so this file
# checks the wrapper-level plumbing (weight expansion, design-matrix
# selection, cached-value population, short-circuit/degenerate contracts)
# against a direct call to that already-verified shared helper, matching the
# pattern used for the cauchit/cloglog/adjcat and stereotype-logit wrappers.

make_kk_cond_adj_cat_fixture <- function(n_pairs = 25L, n_single = 10L, seed = 20260918) {
	set.seed(seed)
	n <- 2L * n_pairs + n_single
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))

	priv0 <- des$.__enclos_env__$private
	w <- priv0$w
	eta <- 0.4 * w + 0.3 * X$x1
	cut1 <- plogis(-1 - eta); cut2 <- plogis(0.2 - eta); cut3 <- plogis(1.1 - eta)
	u <- runif(n)
	y <- ifelse(u <= cut1, 1L, ifelse(u <= cut2, 2L, ifelse(u <= cut3, 3L, 4L)))
	des$add_all_subject_responses(y)
	list(des = des, y = y)
}

install_bb_context <- function(inf) {
	priv <- inf$.__enclos_env__$private
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	ctx
}

test_that("weighted bootstrap wrapper matches a direct call to the shared surrogate helper", {
	fx <- make_kk_cond_adj_cat_fixture()

	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(fx$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	ctx <- install_bb_context(inf)

	set.seed(1)
	weights <- stats::runif(ctx$n_units, 0.3, 2)
	beta <- inf$compute_estimate_with_bootstrap_weights(weights)

	row_weights <- weights[ctx$row_to_unit]
	X <- priv$create_design_matrix()[, -1, drop = FALSE]
	direct <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, priv$y, row_weights, method = "logistic")

	expect_equal(beta, as.numeric(direct$beta_hat))
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
})

test_that("effectively-constant weights short-circuit to the unweighted estimate", {
	fx <- make_kk_cond_adj_cat_fixture()

	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(fx$des, verbose = FALSE)
	ctx <- install_bb_context(inf)

	est_unit <- inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	est_plain <- inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est_unit, as.numeric(est_plain)[1], tolerance = 1e-8)

	est_scaled <- inf$compute_estimate_with_bootstrap_weights(rep(2.5, ctx$n_units))
	expect_equal(est_scaled, as.numeric(est_plain)[1], tolerance = 1e-8)
})

test_that("all-zero weights are treated as effectively constant, not filtered out", {
	# Non-obvious contract, matching the same short-circuit shape confirmed for
	# other KK ordinal wrappers this session: the tolerance check on the row
	# weights' range fires before any positive-weight filtering, so an
	# all-zero weight vector reuses the unweighted estimate rather than
	# producing NA.
	fx <- make_kk_cond_adj_cat_fixture(n_pairs = 10L, n_single = 4L)

	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(fx$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	ctx <- install_bb_context(inf)

	est_zero <- inf$compute_estimate_with_bootstrap_weights(rep(0, ctx$n_units))
	est_plain <- inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est_zero, as.numeric(est_plain)[1], tolerance = 1e-8)
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
})

test_that("genuinely varying weights diverge from the unweighted estimate", {
	fx <- make_kk_cond_adj_cat_fixture()

	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(fx$des, verbose = FALSE)
	ctx <- install_bb_context(inf)

	# The unweighted estimate must be captured BEFORE the weighted call: both
	# methods cache into the same private$cached_values$beta_hat_T slot, and
	# compute_estimate()'s shared() helper skips refitting once that slot is
	# non-NULL -- so calling compute_estimate() after
	# compute_estimate_with_bootstrap_weights() on the same object silently
	# returns the stale weighted value instead of recomputing (confirmed by
	# reading ordinal_cond_clogit_shared_multi()'s cache check; not a bug in
	# scope to fix here, just a real call-order-dependent quirk).
	est_plain <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1]

	set.seed(2)
	weights <- stats::runif(ctx$n_units, 0.1, 10)
	est_weighted <- inf$compute_estimate_with_bootstrap_weights(weights)

	expect_true(abs(est_weighted - est_plain) > 1e-6)

	# Pin the stale-cache quirk itself: a compute_estimate() call issued after
	# the weighted call returns the weighted value, not a fresh unweighted fit.
	est_plain_after_weighted_call <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1]
	expect_equal(est_plain_after_weighted_call, est_weighted)
})
