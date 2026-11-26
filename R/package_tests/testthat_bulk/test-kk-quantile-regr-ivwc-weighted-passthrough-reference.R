library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrIVWC's compute_estimate_with_bootstrap_weights()
# was previously only referenced in a migration-golden legacy/migrated output
# comparison that never exercises this specific method (grep confirms zero
# hits for compute_estimate_with_bootstrap_weights in
# test-kk-quantile-regr-ivwc-migration-golden.R). No registered class defines
# a specialized private$compute_weighted_estimate_ivwc anywhere in the
# package (confirmed via repo-wide grep), so this class falls through to the
# shared generic fallback in inference_all_abstract_KK_passthrough_compound.R:
# a weighted combination of the matched-pair diff mean and the reservoir
# treatment/control mean-diff, using the fixed w_star from the original
# (unweighted) quantile-regression fit -- not a re-fit quantreg::rq() call.
# This tests that generic fallback formula directly, reading the class's own
# cached KKstats as ground truth for the match/reservoir partition.
#
# v1.0.6-TODO-158 (2026-11-19): that fallback was a raw mean difference of the
# responses pooled with the observed w_star, not this class's quantile
# estimator, and is gone; the class then refused the Bayesian bootstrap.
# v1.0.6-TODO-169 (2) (2026-11-20): the class now has compute_weighted_estimate_ivwc(),
# a weighted quantreg::rq() refit of both halves. The test below checks a replicate
# against an independent weighted-rq reference.

# Independent reference for one Bayesian-bootstrap replicate: weighted rq() on the
# matched-pair differences (pair weight = mean of the pair's row weights) and on the
# reservoir, "nid" standard errors from each weighted fit, inverse-variance pooling.
kk_quantile_ivwc_weighted_reference <- function(inf, unit_weights, fn) {
	priv <- inf$.__enclos_env__$private
	K <- priv$cached_values$KKstats
	rw <- priv$expand_subject_or_block_weights_to_row_weights(unit_weights)
	m_vec <- priv$m
	pid <- sort(unique(m_vec[!is.na(m_vec) & m_vec > 0]))
	pw <- vapply(pid, function(j) mean(rw[m_vec == j]), numeric(1))
	res_idx <- which(is.na(m_vec) | m_vec <= 0)
	half <- function(fit, nm) {
		ct <- suppressWarnings(summary(fit, se = "nid"))$coefficients
		c(beta = unname(coef(fit)[nm]), ssq = ct[nm, "Std. Error"]^2)
	}
	dm <- data.frame(K$X_matched_diffs)
	dm$yd <- fn(K$yTs_matched) - fn(K$yCs_matched)
	hm <- half(suppressWarnings(quantreg::rq(yd ~ ., data = dm, weights = pw / mean(pw), tau = 0.5)), "(Intercept)")
	dr <- data.frame(trt = K$w_reservoir, K$X_reservoir)
	dr$yr <- fn(K$y_reservoir)
	wr <- rw[res_idx]
	hr <- half(suppressWarnings(quantreg::rq(yr ~ ., data = dr, weights = wr / mean(wr), tau = 0.5)), "trt")
	w_star <- hr[["ssq"]] / (hr[["ssq"]] + hm[["ssq"]])
	w_star * hm[["beta"]] + (1 - w_star) * hr[["beta"]]
}

kk_quantile_regr_ivwc_fixture <- function(n = 24L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	y <- numeric(n)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y[i] <- 0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i] + rnorm(1)
	}
	des$add_all_subject_responses(y)
	des
}

test_that("InferenceContinKKQuantileRegrIVWC: a Bayesian-bootstrap replicate is the weighted-rq IVWC refit", {
	skip_if_not_installed("quantreg")
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	expect_true(priv$supports_bayesian_bootstrap())
	expect_false("bayesian_bootstrap" %in% EDI:::EDI_INFERENCE_EXCLUDED_CAPABILITIES[["InferenceContinKKQuantileRegrIVWC"]])
	est <- inf$compute_estimate()
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	set.seed(1)
	u <- runif(ctx$n_units, 0.5, 2)
	rep <- suppressWarnings(inf$compute_estimate_with_bootstrap_weights(u, estimate_only = TRUE))
	expect_equal(rep, kk_quantile_ivwc_weighted_reference(inf, u, identity), tolerance = 1e-8)
	expect_false(isTRUE(all.equal(rep, est)))
	expect_identical(inf$compute_estimate(), est)
})
