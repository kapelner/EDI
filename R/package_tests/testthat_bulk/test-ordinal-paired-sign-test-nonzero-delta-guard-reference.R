library(testthat)
library(EDI)

# InferenceOrdinalPairedSignTest$compute_asymp_two_sided_pval(): the sign test's null is fixed at "no directional
# preference" (theta = 0.5); a non-zero delta is documented as unsupported and rejected with an explicit error
# before any computation, only reached when should_run_asserts() is TRUE (the default). Had no test calling this
# method with a nonzero delta; existing coverage of this class only exercises delta = 0 (the default) and the
# NA-pair-differences regression.

fx <- function(seed = 11L, n = 20L) {
	set.seed(seed)
	x_dat <- data.frame(x = rnorm(n))
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
}

test_that("a nonzero delta errors with the exact documented message", {
	inf <- fx()
	expect_error(inf$compute_asymp_two_sided_pval(0.3), "Sign test only supports testing against delta = 0\\.")
	inf2 <- fx()
	expect_error(inf2$compute_asymp_two_sided_pval(-1), "Sign test only supports testing against delta = 0\\.")
})

test_that("delta = 0 (the default) runs normally and returns a finite p-value in [0, 1]", {
	inf <- fx()
	pv <- inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
	inf2 <- fx()
	pv2 <- inf2$compute_asymp_two_sided_pval(delta = 0)
	expect_equal(pv2, pv, tolerance = 1e-12)
})

test_that("with assertions disabled, a nonzero delta silently falls through instead of erroring, and is genuinely used (unlike the analogous GehanWilcox guard, where a bypassed delta is ignored)", {
	inf <- fx()
	old <- getOption("edi.run_asserts")
	on.exit(options(edi.run_asserts = old), add = TRUE)
	options(edi.run_asserts = FALSE)
	out <- tryCatch(inf$compute_asymp_two_sided_pval(0.3), error = function(e) e)
	expect_false(inherits(out, "error"))
	expect_true(is.finite(out))
	inf2 <- fx()
	pv0 <- inf2$compute_asymp_two_sided_pval(0)
	expect_false(isTRUE(all.equal(out, pv0)))                                    # delta = 0.3 genuinely shifts the z-test, not silently dropped
})
