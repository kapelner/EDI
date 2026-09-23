library(testthat)
library(EDI)

# The module-level conditional_logit_weighted_combined_estimate() helper (inference_incidence_KK_
# cond_logit.R, lines ~52-101) is called directly (not through a private-method wrapper) by
# InferenceIncidKKCondLogitOneLik's own compute_weighted_combined_estimate(). Two of its guards had
# no test reference anywhere (distinct from the "kk_clogit_combined_weighted_match_data_unavailable"
# guard already closed in test-kk-clogit-onelik-combined-fit-and-design-guards-reference.R, which is
# a different, upstream check in the OneLik class's own compute_weighted_combined_estimate()):
#   1. "kk_clogit_combined_weighted_no_informative_data": conditional_logit_prepare_combined_design()
#      returns a NULL design (mocked, same technique as the sibling non-weighted guard).
#   2. "kk_clogit_combined_weighted_no_positive_weights": the combined design is usable, but every
#      combined row weight is non-finite or <= 0. An all-zero weight vector works here: bootstrap
#      weights are asserted >= 0 at the public boundary (so a negative vector is out), and
#      weights_are_effectively_constant() explicitly excludes non-positive weights from its
#      "equivalent to unweighted" shortcut (it requires every weight > 0), so an all-zero vector is
#      simultaneously all <= 0 AND *not* treated as the constant-weight fast path -- it still reaches
#      the real weighted-refit branch, where every combined weight ends up 0.

kk_clogit_onelik_fixture <- function() {
	X <- data.frame(x1 = c(-2.0, -1.9, -1.0, -0.9, 0.9, 1.0, 1.9, 2.0))
	des <- DesignFixedBinaryMatch$new(
		response_type = "incidence", n = nrow(X),
		m = rep(seq_len(nrow(X) / 2L), each = 2L),
		design_formula = ~ ., verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(c(1, 0, 0, 1, 1, 0, 0, 1))
	des$add_all_subject_responses(c(1, 0, 0, 1, 1, 0, 0, 1))
	InferenceIncidKKCondLogitOneLik$new(des, verbose = FALSE)
}

test_that("compute_weighted_combined_estimate caches 'kk_clogit_combined_weighted_no_informative_data' when the combined design is empty", {
	inf <- kk_clogit_onelik_fixture()
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	local_mocked_bindings(
		conditional_logit_prepare_combined_design = function(private_env, KKstats) {
			list(X = NULL, y = NULL, j_beta_T = 2L, has_reservoir = FALSE)
		},
		.package = "EDI"
	)

	res <- p$weighted_refit_impl(c(1, 1, 1, 2))  # non-constant (block-level): forces the weighted path
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "kk_clogit_combined_weighted_no_informative_data")
})

test_that("compute_weighted_combined_estimate caches 'kk_clogit_combined_weighted_no_positive_weights' when every combined weight is non-positive", {
	inf <- kk_clogit_onelik_fixture()
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	# all-zero is NOT "effectively constant" (weights_are_effectively_constant() requires all > 0),
	# so this still takes the weighted-refit path, and every combined weight ends up <= 0.
	res <- p$weighted_refit_impl(c(0, 0, 0, 0))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "kk_clogit_combined_weighted_no_positive_weights")
})
