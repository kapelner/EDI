library(testthat)
library(EDI)

# InferenceSurvivalGehanWilcox$compute_asymp_two_sided_pval(): a nonzero null delta is rejected with an explicit
# "not yet implemented" error before any computation, only reached when should_run_asserts() is TRUE (the
# default). The identical-shaped guard on the sibling InferenceSurvivalLogRank class (via its own
# compute_asymp_log_rank_two_sided_pval_for_treatment_effect()) is already tested; this class's own copy, on its
# plain compute_asymp_two_sided_pval(), had no test calling it at all.

fx <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	InferenceSurvivalGehanWilcox$new(des, verbose = FALSE)
}

test_that("a nonzero delta errors with the exact documented message", {
	inf <- fx()
	expect_error(
		inf$compute_asymp_two_sided_pval(delta = 0.3),
		"Testing non-zero delta is not yet implemented for InferenceSurvivalGehanWilcox\\."
	)
	inf2 <- fx()
	expect_error(inf2$compute_asymp_two_sided_pval(delta = -1), "not yet implemented")
})

test_that("delta = 0 (the default) runs normally and returns a finite p-value", {
	inf <- fx()
	pv <- inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
	inf2 <- fx()
	pv2 <- inf2$compute_asymp_two_sided_pval(delta = 0)
	expect_equal(pv2, pv, tolerance = 1e-12)
})

test_that("with assertions disabled, a nonzero delta silently falls through instead of erroring", {
	inf <- fx()
	old <- getOption("edi.run_asserts")
	on.exit(options(edi.run_asserts = old), add = TRUE)
	options(edi.run_asserts = FALSE)
	out <- tryCatch(inf$compute_asymp_two_sided_pval(delta = 0.3), error = function(e) e)
	expect_false(inherits(out, "error"))
})
