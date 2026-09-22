library(testthat)
library(EDI)

# InferenceSurvivalLogRank$compute_asymp_log_rank_two_sided_pval_for_treatment_effect() and
# InferenceSurvivalKMDiff's own identically-named method each reject a nonzero null delta with an
# explicit "not yet implemented" error before any computation (only reached when
# should_run_asserts() is TRUE, the default) -- the same guard shape already covered for the
# sibling InferenceSurvivalGehanWilcox class (test-gehan-wilcox-nonzero-delta-not-yet-implemented-
# reference.R), whose own header comment claims "the identical-shaped guard on the sibling
# InferenceSurvivalLogRank class... is already tested" -- but a repo-wide grep for both classes'
# exact messages ("Testing non-zero delta is not yet implemented for InferenceSurvivalLogRank." /
# "Log-rank p-value for non-zero delta is not yet implemented.") turns up zero hits anywhere; that
# claim appears to be stale/incorrect. Neither guard had any test triggering it.

fx <- function(cls_name, seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
}

test_that("InferenceSurvivalLogRank: a nonzero delta errors with the exact documented message; delta = 0 runs normally", {
	inf <- fx("InferenceSurvivalLogRank", seed = 1L)
	expect_error(
		inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.3),
		"Testing non-zero delta is not yet implemented for InferenceSurvivalLogRank\\."
	)
	inf2 <- fx("InferenceSurvivalLogRank", seed = 1L)
	expect_error(inf2$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = -1), "not yet implemented")

	inf3 <- fx("InferenceSurvivalLogRank", seed = 1L)
	pv <- inf3$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
	inf4 <- fx("InferenceSurvivalLogRank", seed = 1L)
	expect_equal(inf4$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0), pv, tolerance = 1e-12)
})

test_that("InferenceSurvivalKMDiff: a nonzero delta errors with the exact documented message; delta = 0 runs normally", {
	inf <- fx("InferenceSurvivalKMDiff", seed = 2L)
	expect_error(
		inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.3),
		"Log-rank p-value for non-zero delta is not yet implemented\\."
	)
	inf2 <- fx("InferenceSurvivalKMDiff", seed = 2L)
	expect_error(inf2$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = -1), "not yet implemented")

	inf3 <- fx("InferenceSurvivalKMDiff", seed = 2L)
	pv <- inf3$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
	inf4 <- fx("InferenceSurvivalKMDiff", seed = 2L)
	expect_equal(inf4$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0), pv, tolerance = 1e-12)
})

test_that("with assertions disabled, a nonzero delta silently falls through instead of erroring (both classes)", {
	old <- getOption("edi.run_asserts")
	on.exit(options(edi.run_asserts = old), add = TRUE)
	options(edi.run_asserts = FALSE)

	lr <- fx("InferenceSurvivalLogRank", seed = 3L)
	expect_no_error(lr$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.5))

	km <- fx("InferenceSurvivalKMDiff", seed = 4L)
	expect_no_error(km$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.5))
})
