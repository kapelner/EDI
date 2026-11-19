library(testthat)
library(EDI)

# InferencePropKKQuantileRegrIVWC's compute_estimate_with_bootstrap_weights()
# was previously only ever referenced by name (a method-name-inventory check
# in test-proportion-count-family-contracts.R), never actually invoked with
# genuinely varying weights. This class defines no specialized
# compute_weighted_estimate_ivwc, so it falls through to the shared
# InferenceMixinKKPassThrough generic: a weighted combination of the matched-
# pair diff mean and the reservoir treatment/control mean-diff, both already
# on the logit scale (compute_basic_match_data() applies qlogis() for
# proportion responses before caching KKstats). Same pattern as the
# already-covered KKOLSIVWC/KKRankRegrIVWC/KKQuantileRegrIVWC(continuous)
# siblings -- read the class's own cached KKstats as ground truth for the
# match/reservoir partition and independently recompute the weighted-
# combination formula from scratch.
#
# v1.0.6-TODO-217 (2026-11-19): that fallback was a raw mean difference of the
# responses pooled with the observed w_star, not this class's quantile
# estimator, and is gone. With no weighted refit of the quantile halves (their
# standard errors come from rq sparsity, then an IQR fallback), the class now
# opts out of the Bayesian bootstrap. The tests below pin the refusal.

prop_kk_quantregr_ivwc_fixture <- function(n = 24L, seed = 20260918L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		des$add_one_subject_response(i, plogis(-0.2 + 0.4 * ((w_i + 1) / 2) + 0.3 * rnorm(1)))
	}
	des
}

test_that("InferencePropKKQuantileRegrIVWC refuses the Bayesian bootstrap instead of returning a raw mean difference", {
	des <- prop_kk_quantregr_ivwc_fixture()
	inf <- InferencePropKKQuantileRegrIVWC$new(des)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$supports_bayesian_bootstrap())
	expect_true("bayesian_bootstrap" %in% EDI:::EDI_INFERENCE_EXCLUDED_CAPABILITIES[["InferencePropKKQuantileRegrIVWC"]])
	expect_error(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 5, show_progress = FALSE),
		"does not support Bayesian bootstrap")
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	set.seed(1)
	expect_error(inf$compute_estimate_with_bootstrap_weights(runif(ctx$n_units, 0.5, 2), estimate_only = TRUE),
		"has no weighted refit of its estimator")
})
