library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrOneLik$compute_estimate_with_bootstrap_weights() -- the single-fit
# stacked quantreg estimator (matched-pair diffs + reservoir rows) shared via inference_all_KK_
# quantile_regr_one_lik_abstract.R's compute_weighted_combined_estimate() -- had zero functional test
# coverage: test-continuous-estimator-contracts.R only asserts the method NAME exists on this class
# (and separately tests an unrelated missing-Bayesian-bootstrap-context error guard on a different
# class), never calls it with genuinely varying weights. The sibling InferencePropKKQuantileRegrOneLik
# already has this exact coverage (test-prop-kk-quantreg-onelik-stacked-weighted-reference.R, closed
# earlier this session); this file is the same technique applied to the continuous-response class,
# whose transform_y_fn is identity() (not qlogis()) since continuous responses need no link-scale
# transform. Verify the weighted refit by independently rebuilding the same stacked design from the
# class's own cached KKstats partition and fitting quantreg::rq() directly, rather than reusing the
# private compute_weighted_combined_estimate() method itself.

make_contin_kk_qr_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	w <- des$get_w()
	y <- 0.5 * w + 0.3 * rnorm(n)
	des$add_all_subject_responses(y)
	des
}

install_bb_context <- function(inf, n_rows) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n_rows), unit_group_id = rep(1L, n_rows), n_units = n_rows
	)
	inf
}

independent_stacked_rq_beta <- function(inf, row_weights, tau = 0.5) {
	priv <- inf$.__enclos_env__$private
	if (is.null(priv$cached_values$KKstats)) priv$compute_basic_match_data()
	KK <- priv$cached_values$KKstats
	kk_w <- EDI:::kk_pair_and_reservoir_bootstrap_weights(priv, row_weights)

	yd <- KK$yTs_matched - KK$yCs_matched                                          # identity transform for continuous responses
	Xd <- as.matrix(KK$X_matched_diffs_full)
	y_r <- KK$y_reservoir
	w_r <- KK$w_reservoir
	X_r <- as.matrix(KK$X_reservoir)

	X_pairs <- cbind(intercept = 0, trt__ = 1, Xd)
	X_res <- cbind(intercept = 1, trt__ = w_r, X_r)
	X_stack <- rbind(X_pairs, X_res)
	y_stack <- c(yd, y_r)
	w_stack <- c(kk_w$pair_weights, kk_w$reservoir_weights)

	ok <- is.finite(w_stack) & w_stack > 0 & is.finite(y_stack)
	dat <- as.data.frame(X_stack[ok, , drop = FALSE])
	dat$y_stack__ <- y_stack[ok]
	fit <- quantreg::rq(y_stack__ ~ . - 1, tau = tau, data = dat, weights = w_stack[ok])
	unname(coef(fit)["trt__"])
}

test_that("weighted stacked quantreg refit matches an independently rebuilt reference", {
	des <- make_contin_kk_qr_fixture(1L)
	inf <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	n <- des$get_t()
	install_bb_context(inf, n)
	set.seed(2L)
	weights <- runif(n, 0.3, 2.5)

	est <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	ref <- independent_stacked_rq_beta(inf, weights)

	expect_equal(as.numeric(est), ref, tolerance = 1e-6)
})

test_that("unit weights reproduce compute_estimate() via the effectively-constant shortcut", {
	des <- make_contin_kk_qr_fixture(3L)
	inf <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	unweighted <- as.numeric(inf$compute_estimate(estimate_only = TRUE))

	inf2 <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	n <- des$get_t()
	install_bb_context(inf2, n)
	weighted_unit <- inf2$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)

	expect_equal(as.numeric(weighted_unit), unweighted, tolerance = 1e-8)
})

test_that("genuinely varying weights diverge from the unweighted estimate", {
	des <- make_contin_kk_qr_fixture(4L)
	inf <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	unweighted <- as.numeric(inf$compute_estimate(estimate_only = TRUE))

	set.seed(5L)
	n <- des$get_t()
	weights <- runif(n, 0.1, 5)
	inf2 <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	install_bb_context(inf2, n)
	weighted <- as.numeric(inf2$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))

	expect_true(abs(weighted - unweighted) > 1e-4)
})
