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
# v1.0.6-TODO-217 (2026-11-19): that fallback was a raw mean difference of the
# responses pooled with the observed w_star, not this class's quantile
# estimator, and is gone. With no weighted refit of the quantile halves (their
# standard errors come from rq sparsity, then an IQR fallback), the class now
# opts out of the Bayesian bootstrap. The tests below pin the refusal.

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

test_that("InferenceContinKKQuantileRegrIVWC refuses the Bayesian bootstrap instead of returning a raw mean difference", {
	des <- kk_quantile_regr_ivwc_fixture()
	inf <- InferenceContinKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$supports_bayesian_bootstrap())
	expect_true("bayesian_bootstrap" %in% EDI:::EDI_INFERENCE_EXCLUDED_CAPABILITIES[["InferenceContinKKQuantileRegrIVWC"]])
	expect_error(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 5, show_progress = FALSE),
		"does not support Bayesian bootstrap")
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	set.seed(1)
	expect_error(inf$compute_estimate_with_bootstrap_weights(runif(ctx$n_units, 0.5, 2), estimate_only = TRUE),
		"has no weighted refit of its estimator")
})
