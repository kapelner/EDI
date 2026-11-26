library(testthat)
library(EDI)

# v1.0.6-TODO-157: when the combined (matched pairs + reservoir) exact test rejects every log odds
# ratio, InferenceIncidExactZhang's exact CI used to collapse onto the rejected maximiser of the
# combined p-value, giving a "CI" of width ~1e-6 (comprehensive_tests KK21stepwise `~.`, pima,
# beta_T 0.5: rep 6 [0.1933261, 0.1933269], rep 14 [-0.2623787, -0.2623780]). The fixtures below
# rebuild those two cases' exact tables (the CI depends on nothing else): the discordant pairs
# point one way, the reservoir the other, and the largest combined p-value is 0.0022 and 0.043.
# The confidence set is empty, so the CI is NA with a recorded reason and an
# edi_procedure_na_warning.

zhang_table_fx <- function(m, d_plus, d_minus, n11, n10, n01, n00) {
	# Pairs: d_plus (treated 1, control 0), d_minus (0, 1), the rest concordant (1, 1);
	# then the reservoir 2x2 table.
	conc <- m - d_plus - d_minus
	yT <- c(rep(1L, d_plus), rep(0L, d_minus), rep(1L, conc))
	yC <- c(rep(0L, d_plus), rep(1L, d_minus), rep(1L, conc))
	w <- c(rep(c(1L, 0L), m), rep(1L, n11 + n10), rep(0L, n01 + n00))
	y <- c(as.vector(rbind(yT, yC)), rep(1L, n11), rep(0L, n10), rep(1L, n01), rep(0L, n00))
	m_vec <- c(rep(seq_len(m), each = 2L), rep(0L, n11 + n10 + n01 + n00))
	n <- length(w)
	set.seed(1)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$w <- w
	des$.__enclos_env__$private$m <- m_vec
	des$add_all_subject_responses(y)
	InferenceIncidExactZhang$new(des, verbose = FALSE)
}
rep6_fx <- function() zhang_table_fx(66L, 13L, 7L, 0L, 6L, 9L, 1L)
rep14_fx <- function() zhang_table_fx(67L, 9L, 13L, 6L, 2L, 0L, 6L)
max_combined_pval <- function(inf, grid = seq(-6, 6, by = 1e-3)) {
	max(vapply(grid, function(d) EDI:::zhang_pval_exact_combined(inf, d, "Fisher"), numeric(1)))
}

test_that("the fixtures rebuild the comprehensive cases' exact tables and p-value at 0", {
	st <- EDI:::zhang_get_exact_stats(rep6_fx())
	expect_identical(unlist(st), c(m = 66L, nRT = 6L, nRC = 10L, d_plus = 13L, d_minus = 7L, n11 = 0L, n10 = 6L, n01 = 9L, n00 = 1L))
	expect_equal(rep6_fx()$compute_exact_two_sided_pval_for_treatment_effect(), 0.002157219, tolerance = 1e-6)
	st <- EDI:::zhang_get_exact_stats(rep14_fx())
	expect_identical(unlist(st), c(m = 67L, nRT = 8L, nRC = 6L, d_plus = 9L, d_minus = 13L, n11 = 6L, n10 = 2L, n01 = 0L, n00 = 6L))
})

test_that("the combined p-value never reaches alpha = 0.05 on either case (empty confidence set)", {
	expect_lt(max_combined_pval(rep6_fx()), 0.003)
	p14 <- max_combined_pval(rep14_fx())
	expect_lt(p14, 0.05)
	expect_gt(p14, 0.04)
})

test_that("an empty confidence set gives NA bounds, a recorded reason and an edi_procedure_na_warning", {
	for (fx in list(rep6_fx, rep14_fx)) {
		inf <- fx()
		expect_warning(ci <- inf$compute_exact_confidence_interval(), class = "edi_procedure_na_warning")
		expect_length(ci, 2L)
		expect_true(all(is.na(ci)))
		expect_identical(
			inf$.__enclos_env__$private$cached_values$procedure_failure_reason$compute_exact_confidence_interval,
			"exact_ci_empty_acceptance_set"
		)
		# The estimate and the p-value are unaffected.
		expect_true(is.finite(inf$compute_estimate()))
		expect_true(is.finite(inf$compute_exact_two_sided_pval_for_treatment_effect()))
	}
})

test_that("at a level the test does accept, the same case gives a real interval and the stale reason is cleared", {
	inf <- rep14_fx()
	expect_warning(inf$compute_exact_confidence_interval(0.05), class = "edi_procedure_na_warning")
	expect_no_warning(ci <- inf$compute_exact_confidence_interval(0.01))
	expect_true(all(is.finite(ci)))
	expect_gt(ci[2] - ci[1], 0.1)
	p_fn <- function(d) EDI:::zhang_pval_exact_combined(inf, d, "Fisher")
	expect_gt(p_fn(mean(ci)), 0.01)
	expect_lte(p_fn(ci[1] - 1e-4), 0.01)
	expect_lte(p_fn(ci[2] + 1e-4), 0.01)
	expect_null(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$compute_exact_confidence_interval)
})

test_that("a narrow acceptance set that optimize() misses is found by the grid search, not collapsed to a point", {
	# Before the fix this case (Fisher, alpha = 0.1) gave [-0.2033252, -0.2033242], a point the test
	# rejects; the accepted set is about [0.319, 0.358].
	inf <- zhang_table_fx(24L, 1L, 5L, 16L, 2L, 13L, 8L)
	expect_no_warning(ci <- inf$compute_exact_confidence_interval(0.1))
	expect_equal(as.numeric(ci), c(0.3180, 0.3584), tolerance = 1e-3)
	expect_gt(EDI:::zhang_pval_exact_combined(inf, mean(ci), "Fisher"), 0.1)
})

test_that("the grid search returns NA with the largest p-value seen when nothing is accepted", {
	p_at <- function(d) 0.02 * exp(-d^2)
	out <- EDI:::zhang_ci_inside_point_grid(p_at, c(-1, 2), alpha = 0.05, p_best = 0.001)
	expect_true(is.na(out))
	expect_equal(attr(out, "max_pval"), 0.02, tolerance = 1e-6)
	# A spike wider than one grid step (5 / 2000) is found.
	p_at <- function(d) if (abs(d - 1.2345) < 3e-3) 0.5 else 0.01
	expect_lt(abs(EDI:::zhang_ci_inside_point_grid(p_at, c(-1, 2), alpha = 0.05, p_best = 0.01) - 1.2345), 3e-3)
})
