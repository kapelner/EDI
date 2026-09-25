library(testthat)
library(EDI)

# InferenceIncidKKCondLogitOneLik's compute_weighted_combined_estimate() ->
# conditional_logit_weighted_combined_estimate() (inference_incidence_KK_cond_logit.R) dispatches on
# the same 3 usability regimes as the class's own unweighted shared_combined_likelihood()
# (has_reservoir && m>0 combined design / m>0-only discordant-pairs-only design / reservoir-only
# design), via conditional_logit_prepare_combined_design()'s has_reservoir = nRT>0 && nRC>0 flag. The
# only existing weighted-combined-estimate test reference
# (test-kk-clogit-onelik-weighted-combined-informative-data-and-positive-weights-guards-reference.R)
# only exercises the "no_informative_data"/"no_positive_weights" early-NA guards, both forced via an
# artificially degenerate design with no covariates and zero matches -- it never reaches the real
# matched-only or reservoir-only regime dispatch with genuinely varying weights on real match data
# (confirmed via grep: no test constructs a fixture where nRT/nRC or m is forced to 0 while calling
# compute_estimate_with_bootstrap_weights() with non-constant weights). Verified indirectly: since
# neither regime has a simple closed-form weighted reference (the combined design is a matching-
# stratified conditional-logistic fit, not an ordinary weighted GLM), each regime's weighted path is
# instead cross-checked against the SAME regime's own already-tested unweighted
# compute_estimate()/shared_combined_likelihood() under unit weights, which must agree exactly by
# construction (a weight of 1 for every row is a no-op reweighting). Reached via KKstats private-
# cache injection (nRT/nRC or m forced to 0 after a real compute_basic_match_data() call), the
# technique already established throughout this session for this class family.

mk_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(0.5 * w))
	des$add_all_subject_responses(y)
	des
}

test_that("matched-pairs-only regime (nRT=nRC=0): the weighted (unit-weight) estimate matches the same regime's own unweighted compute_estimate() exactly", {
	des <- mk_fixture(1L)
	inf_w <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_w <- inf_w$.__enclos_env__$private
	priv_w$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(60L), unit_group_id = rep(1L, 60L), n_units = 60L)
	invisible(priv_w$compute_basic_match_data())
	priv_w$cached_values$KKstats$nRT <- 0L
	priv_w$cached_values$KKstats$nRC <- 0L
	weighted_est <- inf_w$compute_estimate_with_bootstrap_weights(rep(1, 60L), estimate_only = FALSE)

	inf_direct <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_direct <- inf_direct$.__enclos_env__$private
	invisible(priv_direct$compute_basic_match_data())
	priv_direct$cached_values$KKstats$nRT <- 0L
	priv_direct$cached_values$KKstats$nRC <- 0L
	direct_est <- inf_direct$compute_estimate(estimate_only = FALSE)

	expect_true(is.finite(weighted_est))
	expect_equal(weighted_est, direct_est, tolerance = 1e-8)
})

test_that("reservoir-only regime (m=0): the weighted (unit-weight) estimate matches the same regime's own unweighted compute_estimate() exactly", {
	des <- mk_fixture(1L)
	inf_w <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_w <- inf_w$.__enclos_env__$private
	priv_w$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(60L), unit_group_id = rep(1L, 60L), n_units = 60L)
	invisible(priv_w$compute_basic_match_data())
	priv_w$cached_values$KKstats$m <- 0L
	weighted_est <- inf_w$compute_estimate_with_bootstrap_weights(rep(1, 60L), estimate_only = FALSE)

	inf_direct <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_direct <- inf_direct$.__enclos_env__$private
	invisible(priv_direct$compute_basic_match_data())
	priv_direct$cached_values$KKstats$m <- 0L
	direct_est <- inf_direct$compute_estimate(estimate_only = FALSE)

	expect_true(is.finite(weighted_est))
	expect_equal(weighted_est, direct_est, tolerance = 1e-8)
})

test_that("genuinely varying (non-constant) weights change the matched-only and reservoir-only estimates away from the unweighted value", {
	des <- mk_fixture(1L)
	set.seed(42L)
	weights <- runif(60L, 0.3, 3)

	inf_m <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_m <- inf_m$.__enclos_env__$private
	priv_m$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(60L), unit_group_id = rep(1L, 60L), n_units = 60L)
	invisible(priv_m$compute_basic_match_data())
	priv_m$cached_values$KKstats$nRT <- 0L
	priv_m$cached_values$KKstats$nRC <- 0L
	weighted_matched <- inf_m$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	unweighted_matched <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_um <- unweighted_matched$.__enclos_env__$private
	invisible(priv_um$compute_basic_match_data())
	priv_um$cached_values$KKstats$nRT <- 0L
	priv_um$cached_values$KKstats$nRC <- 0L
	unweighted_matched_est <- unweighted_matched$compute_estimate(estimate_only = FALSE)
	expect_true(is.finite(weighted_matched))
	expect_false(isTRUE(all.equal(weighted_matched, unweighted_matched_est)))

	inf_r <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_r <- inf_r$.__enclos_env__$private
	priv_r$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(60L), unit_group_id = rep(1L, 60L), n_units = 60L)
	invisible(priv_r$compute_basic_match_data())
	priv_r$cached_values$KKstats$m <- 0L
	weighted_reservoir <- inf_r$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	unweighted_reservoir <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~1, verbose = FALSE)
	priv_ur <- unweighted_reservoir$.__enclos_env__$private
	invisible(priv_ur$compute_basic_match_data())
	priv_ur$cached_values$KKstats$m <- 0L
	unweighted_reservoir_est <- unweighted_reservoir$compute_estimate(estimate_only = FALSE)
	expect_true(is.finite(weighted_reservoir))
	expect_false(isTRUE(all.equal(weighted_reservoir, unweighted_reservoir_est)))
})
