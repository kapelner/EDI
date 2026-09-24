library(testthat)
library(EDI)

# get_restricted_mean_se_diff(y, dead, w) (fast_survival_stats.cpp) splits y/dead by arm and calls
# get_restricted_mean_se_for_group() on each arm; that per-group function throws
# "get_restricted_mean_se_for_group: y contains NA/NaN event times; ..." when its own y argument has
# a NaN. test-restricted-mean-se-group-and-diff-kernels-match-survfit-per-group-truncation-
# reference.R already covers this guard for the group function directly ("NaN times are rejected"),
# but never calls get_restricted_mean_se_diff() itself with a NaN time in either arm -- so the
# diff-wrapper's own propagation of that same guard (an uncaught C++ exception bubbling straight
# through, not caught/re-thrown/swallowed by the diff wrapper) had no test reference anywhere
# (confirmed via grep).

D <- get("get_restricted_mean_se_diff", envir = asNamespace("EDI"))

test_that("a NaN event time in the treatment arm propagates the group-level NA/NaN error through get_restricted_mean_se_diff", {
	y <- c(1, NaN, 2, 3)
	dead <- c(1L, 1L, 0L, 1L)
	w <- c(0L, 0L, 1L, 1L)   # the NaN falls in the control (w = 0) arm
	expect_error(D(y, dead, w), "NA/NaN event times")
})

test_that("a NaN event time in the control arm also propagates the same error", {
	y <- c(1, 2, NaN, 3)
	dead <- c(1L, 1L, 0L, 1L)
	w <- c(0L, 1L, 1L, 1L)   # the NaN falls in the treatment (w = 1) arm
	expect_error(D(y, dead, w), "NA/NaN event times")
})

test_that("well-formed, NaN-free times do not trigger the guard", {
	y <- c(1, 2, 3, 4)
	dead <- c(1L, 1L, 0L, 1L)
	w <- c(0L, 0L, 1L, 1L)
	expect_true(is.finite(D(y, dead, w)))
})
