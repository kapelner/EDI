library(testthat)
library(EDI)

# DesignSeqOneByOneKK21$compute_weight_KK21_proportion() (design_seq_one_by_one_KK21.R) tries
# fast_beta_regression_with_var() first and only falls back to
# compute_weight_KK21_continuous(xs_to_date, logit(ys_to_date), ...) when that attempt errors OR
# returns a non-finite (NA/NaN) weight. The existing reference tests (test-kk21-design-generic-per-
# covariate-weight-reference.R and its survival/ordinal/count sibling) only exercise the beta-
# regression SUCCESS path; the fallback branch itself had no test reference anywhere.
#
# A single-row design makes fast_beta_regression_with_var() return ssq_b_2 = -Inf (as verified
# directly below), so sqrt(ssq_b_2) is NaN and the resulting weight is NaN -- is.na(NaN) is TRUE in
# R, so `!is.na(weight)` is FALSE and the function falls through to the continuous-logit fallback,
# which itself has its own already-tested single-row degenerate branch returning
# .Machine$double.eps.

test_that("fast_beta_regression_with_var on a single-row design gives a non-finite weight (ssq_b_2 = -Inf)", {
	br <- EDI:::fast_beta_regression_with_var(X = matrix(c(1, 1), 1, 2), y = 0.5)
	expect_true(is.infinite(br$ssq_b_2) && br$ssq_b_2 < 0)
	expect_true(is.nan(suppressWarnings(sqrt(br$ssq_b_2))))
})

test_that("compute_weight_KK21_proportion on a single-row design falls back to compute_weight_KK21_continuous's own degenerate branch", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "proportion")
	priv <- des$.__enclos_env__$private

	# the internal sqrt(ssq_b_2) on ssq_b_2 = -Inf raises a "NaNs produced" warning, exactly as
	# the direct fast_beta_regression_with_var() call above does
	actual <- suppressWarnings(priv$compute_weight_KK21_proportion(matrix(1, 1, 1), 0.5, 1, 1L))
	expect_equal(actual, .Machine$double.eps)

	# independent reference: exactly what the fallback call computes directly
	ref <- priv$compute_weight_KK21_continuous(matrix(1, 1, 1), EDI:::logit(0.5), 1, 1L)
	expect_equal(actual, ref)
})

test_that("compute_weight_KK21_proportion's fallback also fires for a different single-row proportion value", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "proportion")
	priv <- des$.__enclos_env__$private
	actual <- suppressWarnings(priv$compute_weight_KK21_proportion(matrix(1, 1, 1), 0.2, 1, 1L))
	expect_equal(actual, .Machine$double.eps)
})
