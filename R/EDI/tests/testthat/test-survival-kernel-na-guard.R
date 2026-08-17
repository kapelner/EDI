library(testthat)
library(EDI)

# NA/NaN event-time guards in fast_survival_stats.cpp (fix_inference_
# hierarchy.md, Follow-Ups, "NA-y subset-clone bootstrap hang", 2026-08-17).
# Before these guards, an NA survival time made the KM group-walk's
# `while (time[j] == current_time)` comparison false even at j == i, so the
# outer loop never advanced -- an infinite, uninterruptible C++ hang (no R
# checkpoints, so not even setTimeLimit() could break it), plus undefined
# behavior in std::sort's NaN comparisons. Every R-facing kernel entry point
# must now reject NA input with a clear error instead; the OpenMP-parallel
# BRT kernel additionally NA-guards per replicate inside the loop (throwing
# inside a parallel region is not an option) with its pre-loop y0 stop()
# as the loud first line of defense.
#
# NOTE: against a stale EDI.so compiled before these guards, the "expect an
# error" cases below do not fail -- they hang. A hanging test run on this
# file means the DLL predates the guard, not that the guard regressed.

test_that("survival kernels reject NA/NaN event times instead of hanging", {
	y_bad = c(1.0, NA_real_, 3.0, 4.0, 5.0, 6.0)
	dead = c(1L, 1L, 1L, 1L, 1L, 1L)
	w = c(0L, 1L, 0L, 1L, 0L, 1L)

	expect_error(
		EDI:::get_survival_stat_for_group(y_bad, dead, "median"),
		"NA/NaN event times"
	)
	expect_error(
		EDI:::get_survival_stat_diff(y_bad, dead, w, "median"),
		"NA/NaN event times"
	)
	expect_error(
		EDI:::get_restricted_mean_se_for_group(y_bad, dead),
		"NA/NaN event times"
	)
	# se_diff delegates to se_for_group, whose guard fires with its own name
	expect_error(
		EDI:::get_restricted_mean_se_diff(y_bad, dead, w),
		"NA/NaN event times"
	)

	i_mat = matrix(rep(1:6, 3), ncol = 3)
	w_mat = matrix(rep(w, 3), ncol = 3)
	expect_error(
		EDI:::compute_survival_stat_diff_rand_bootstrap_parallel_cpp(
			y_bad, dead, i_mat, w_mat, 0.0, FALSE, NULL, 1L
		),
		"NA/NaN event times"
	)
	expect_error(
		EDI:::compute_survival_stat_diff_rand_bootstrap_serial_cpp(
			y_bad, dead, i_mat, w_mat, 0.0, "median"
		),
		"NA/NaN event times"
	)
})

test_that("survival kernels still produce correct results on finite input", {
	y = c(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
	dead = rep(1L, 6L)
	w = c(0L, 1L, 0L, 1L, 0L, 1L)

	# all-events KM median of 1..6: curve hits exactly 0.5 at t=3, so the
	# survfit-matching semantics average with the next event time -> 3.5
	expect_equal(EDI:::get_survival_stat_for_group(y, dead, "median"), 3.5)
	expect_true(is.finite(EDI:::get_survival_stat_diff(y, dead, w, "median")))
	expect_true(is.finite(EDI:::get_restricted_mean_se_for_group(y, dead)))
})
