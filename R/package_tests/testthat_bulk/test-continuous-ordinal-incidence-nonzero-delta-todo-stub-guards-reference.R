library(testthat)
library(EDI)

# Three sibling compute_asymp_two_sided_pval(delta) implementations -- InferenceContinKKOLSIVWC's own
# (inference_continuous_KK_ols_ivwc.R), the ordinal KK CLMM family's shared version (inference_
# ordinal_KK_clmm_abstract.R, composed into InferenceOrdinalKKCLMM/Probit/Cauchit/Cloglog), and the
# KK-GEE shared mixin's own (inference_mixin_kk_gee_shared.R, composed into InferenceIncidKKGEE and
# its siblings) -- each only support testing against the sharp null (delta = 0); a nonzero delta falls
# to a `should_run_asserts()`-gated `stop("TO-DO")` documented-but-unimplemented stub (the same pattern
# and literal message already tested for the sibling classes InferenceMLEorKMSummaryTable and
# InferenceSurvivalRestrictedMeanDiff, both in test-mle-or-km-summary-table-shared-and-extract-vcov-
# reference.R / test-gcomp-rmst-ordinal-clmm-contracts.R). A codebase-wide check confirmed
# InferenceContinKKOLSIVWC has ZERO references to compute_asymp_two_sided_pval anywhere at all; the
# ordinal KK CLMM family's only reference to the class names (test-gcomp-rmst-ordinal-clmm-
# contracts.R) checks only their documented link functions, never this guard; and InferenceIncidKKGEE
# is otherwise extensively tested but never with a nonzero delta on this method (distinct from the
# transform_responses guard on its sibling compute_rand_two_sided_pval(), already closed).

test_that("InferenceContinKKOLSIVWC rejects a nonzero delta with the documented TO-DO stub", {
	set.seed(1L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(delta = 0.5), "TO-DO")
})

test_that("InferenceOrdinalKKCLMM rejects a nonzero delta with the documented TO-DO stub", {
	set.seed(2L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	y <- factor(sample(c("a", "b", "c"), n, replace = TRUE), levels = c("a", "b", "c"), ordered = TRUE)
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(delta = 0.5), "TO-DO")
})

test_that("InferenceIncidKKGEE rejects a nonzero delta on compute_asymp_two_sided_pval() with the documented TO-DO stub", {
	set.seed(3L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))
	inf <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(delta = 0.5), "TO-DO")
})

test_that("delta = 0 (the default) never triggers any of the three guards", {
	set.seed(4L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	expect_no_error(inf$compute_asymp_two_sided_pval(delta = 0))
})
