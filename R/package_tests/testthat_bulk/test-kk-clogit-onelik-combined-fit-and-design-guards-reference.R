library(testthat)
library(EDI)

# InferenceIncidKKCondLogitOneLik (inference_incidence_KK_cond_logit.R) has a family of
# "kk_clogit_combined_*" nonestimable guards in its own private block (shared_combined_likelihood()
# and compute_weighted_combined_estimate()), none of which had a test reference anywhere:
#   1. "kk_clogit_combined_match_data_unavailable": compute_basic_match_data() leaves cached KKstats
#      NULL.
#   2. "kk_clogit_combined_no_informative_data": the module-level conditional_logit_prepare_combined_
#      design() helper (called directly, not through a private wrapper -- confirmed by inspecting
#      ls(private), which has no "conditional_logit_prepare_combined_design" binding on this class)
#      returns a NULL design (no discordant pairs, no reservoir).
#   3. "kk_clogit_combined_weighted_match_data_unavailable": same shape as (1) but on the weighted
#      refit path.
# Two sibling guards on the same class ("kk_clogit_combined_likelihood_test_spec_unavailable" via
# get_likelihood_test_spec(), "kk_clogit_combined_randomization_observed_statistic_unavailable" via
# compute_rand_two_sided_pval()'s observed-statistic preflight) were investigated but NOT pursued
# here: both compute_likelihood_test_two_sided_pval() and compute_rand_two_sided_pval() go through a
# memoized likelihood-test-pval cache keyed by object identity, and repeated calls to either across
# multiple test_that() blocks in the same R session intermittently produced
# "attempt to apply non-function" from a stale cached closure -- reproducible even in a single fresh
# top-level call, not an artifact of test ordering. Left untested rather than risk a flaky/misleading
# assertion; worth a source-level look at the memoization keying in a future iteration.
# The natural DesignFixedBinaryMatch fixture below (same shape as
# test-incid-kk-cond-logit-onelik-fit-acceptance.R's pathology fixture) already yields a genuinely
# nonestimable fit ("kk_clogit_combined_extreme_treatment_coefficient", the assess_combined_fit()
# paste0-built generic-reason family -- already covered by that acceptance test, not re-tested here),
# so (1)/(2) require directly overriding cached state / mocking the module-level design helper rather
# than relying on organic fit failure.

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

test_that("shared_combined_likelihood caches 'kk_clogit_combined_match_data_unavailable' when KKstats stays NULL", {
	inf <- kk_clogit_onelik_fixture()
	p <- inf$.__enclos_env__$private
	# The constructor already eagerly populates cached_values$KKstats, so overriding
	# compute_basic_match_data() alone (the no-op-if-already-cached guard) would never fire it;
	# clear the cache too.
	p$cached_values$KKstats <- NULL
	unlockBinding("compute_basic_match_data", p)
	p$compute_basic_match_data <- function(...) invisible(NULL)

	p$shared_combined_likelihood(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_clogit_combined_match_data_unavailable")
})

test_that("shared_combined_likelihood caches 'kk_clogit_combined_no_informative_data' when the combined design is empty", {
	inf <- kk_clogit_onelik_fixture()
	local_mocked_bindings(
		conditional_logit_prepare_combined_design = function(private_env, KKstats) {
			list(X = NULL, y = NULL, j_beta_T = 2L, has_reservoir = FALSE)
		},
		.package = "EDI"
	)

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_clogit_combined_no_informative_data")
})

test_that("compute_weighted_combined_estimate caches 'kk_clogit_combined_weighted_match_data_unavailable' when KKstats stays NULL", {
	inf <- kk_clogit_onelik_fixture()
	p <- inf$.__enclos_env__$private
	p$cached_values$KKstats <- NULL
	unlockBinding("compute_basic_match_data", p)
	p$compute_basic_match_data <- function(...) invisible(NULL)
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()

	res <- p$weighted_refit_impl(c(1, 1, 1, 2))  # non-constant: forces the weighted-refit path
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "kk_clogit_combined_weighted_match_data_unavailable")
})
