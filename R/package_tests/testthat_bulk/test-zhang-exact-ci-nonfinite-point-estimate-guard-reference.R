library(testthat)
library(EDI)

# zhang_ci_exact_combined(inf_obj, alpha, pval_epsilon, combination_method): before running the exact CI bisection
# search, it computes the Haldane-Anscombe continuity-corrected log odds ratio point estimate and asserts it is
# finite, erroring otherwise rather than bisecting around a non-finite center. With the +0.5 continuity correction,
# this is unreachable via any realistic (non-negative integer) 2x2 table -- the guard only fires on already-
# corrupted/degenerate cached stats -- but it is a real, reachable branch (defensive against a future caller
# passing a bad stats object) with no test exercising it. Also confirms the ordinary path is unaffected.

fx <- function(seed = 321L, n = 24L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	treatment <- des$.__enclos_env__$private$w
	prob <- plogis(-0.2 + 0.8 * treatment)
	for (i in seq_len(n)) des$add_one_subject_response(i, rbinom(1, 1, prob[i]))
	InferenceIncidExactZhang$new(des, verbose = FALSE)
}

test_that("a non-finite point estimate (from corrupted/degenerate cached stats) errors with the documented message", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	zhang_ci_exact_combined <- get("zhang_ci_exact_combined", envir = asNamespace("EDI"))
	p$cached_values$incid_exact_zhang_stats <- list(n11 = Inf, n10 = 0, n01 = 0, n00 = 0, m = 0, nRT = 0, nRC = 0, d_plus = 0, d_minus = 0)
	expect_error(
		zhang_ci_exact_combined(inf, alpha = 0.05, pval_epsilon = 0.01),
		"Cannot compute exact CI: point estimate is not finite\\."
	)

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	p2$cached_values$incid_exact_zhang_stats <- list(n11 = 0, n10 = NA_real_, n01 = 0, n00 = 0, m = 0, nRT = 0, nRC = 0, d_plus = 0, d_minus = 0)
	expect_error(
		zhang_ci_exact_combined(inf2, alpha = 0.05, pval_epsilon = 0.01),
		"Cannot compute exact CI: point estimate is not finite\\."
	)
})

test_that("the ordinary path (real, non-degenerate stats) runs without error and returns finite bounds", {
	inf <- fx()
	zhang_ci_exact_combined <- get("zhang_ci_exact_combined", envir = asNamespace("EDI"))
	ci <- zhang_ci_exact_combined(inf, alpha = 0.05, pval_epsilon = 0.01)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
	expect_lte(ci[1], ci[2])
})
