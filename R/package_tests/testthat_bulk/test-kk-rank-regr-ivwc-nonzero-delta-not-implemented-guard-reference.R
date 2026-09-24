library(testthat)
library(EDI)

# InferenceSurvivalKKRankRegrIVWC's own compute_asymp_two_sided_pval(delta) (inference_survival_KK_
# rank_regr_ivwc_abstract.R) only supports testing against the sharp null (delta = 0); a nonzero delta
# falls to a should_run_asserts()-gated stop(): "Testing non-zero delta is not yet implemented for
# this class." -- the same message text as the sibling guards on InferenceCountKKHurdlePoissonIVWC/
# InferenceSurvivalKKStratCoxPHIVWC/InferenceSurvivalKKLWACoxPHIVWC closed last iteration in test-kk-
# ivwc-compound-classes-nonzero-delta-not-implemented-guards-reference.R, but THIS class's own copy of
# the guard (a separate source line) was not exercised by that file. The class's 3 existing references
# (weighted-passthrough, migration-golden, leaf-and-transform-contracts) all use delta = 0.

test_that("InferenceSurvivalKKRankRegrIVWC rejects a nonzero delta with the documented message", {
	set.seed(1L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE)
	expect_error(
		inf$compute_asymp_two_sided_pval(delta = 0.5),
		"Testing non-zero delta is not yet implemented for this class.",
		fixed = TRUE
	)
})

test_that("delta = 0 (the default) never triggers the guard", {
	set.seed(2L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE)
	expect_no_error(inf$compute_asymp_two_sided_pval(delta = 0))
})
