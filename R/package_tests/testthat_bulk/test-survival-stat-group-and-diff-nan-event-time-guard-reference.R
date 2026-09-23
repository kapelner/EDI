library(testthat)
library(EDI)

# fast_survival_stats.cpp's any_nan_time() guard exists because a NaN survival time hangs the KM
# group-walk loop (grp[i].time == ct never advances past a NaN) and breaks std::sort's strict-weak-
# ordering precondition; get_survival_stat_for_group() and get_survival_stat_diff() (the R-exported
# median/RMST kernels) both reject NaN input up front with a documented error, before that unsafe
# code ever runs. The existing reference test for these two kernels
# (test-km-group-and-diff-kernels-restricted-mean-median-and-arm-split-survfit-reference.R) exercises
# empty groups and unknown stat names but never a NaN time, so this guard had no test reference for
# either kernel -- unlike its sibling get_restricted_mean_se_for_group(), whose own identical guard
# is already tested.

G <- get("get_survival_stat_for_group", envir = asNamespace("EDI"))
D <- get("get_survival_stat_diff", envir = asNamespace("EDI"))

test_that("get_survival_stat_for_group rejects a NaN event time with the documented message, for both stats", {
	for (stat in c("median", "restricted_mean")) {
		expect_error(G(c(1, NaN, 2), c(1L, 1L, 0L), stat), "NA/NaN event times", info = stat)
	}
	# NA_real_ is also NaN at the C level and is rejected the same way
	expect_error(G(c(1, NA_real_, 2), c(1L, 1L, 0L), "median"), "NA/NaN event times")
	# a finite-only vector is unaffected
	expect_true(is.finite(G(c(1, 3, 2), c(1L, 1L, 0L), "median")))
})

test_that("get_survival_stat_diff rejects a NaN event time in either arm with the documented message", {
	w <- c(1L, 0L, 1L, 0L)
	y_bad_treated <- c(NaN, 2, 3, 4)
	y_bad_control <- c(1, NaN, 3, 4)
	for (stat in c("median", "restricted_mean")) {
		expect_error(D(y_bad_treated, c(1L, 1L, 1L, 0L), w, stat), "NA/NaN event times", info = stat)
		expect_error(D(y_bad_control, c(1L, 1L, 1L, 0L), w, stat), "NA/NaN event times", info = stat)
	}
	expect_true(is.finite(D(c(1, 2, 3, 4), c(1L, 1L, 1L, 0L), w, "median")))
})
