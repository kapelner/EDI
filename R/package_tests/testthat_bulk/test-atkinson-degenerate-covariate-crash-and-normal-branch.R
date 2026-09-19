library(testthat)
library(EDI)

# DesignSeqOneByOneAtkinson's assign_wt() normal branch (t > ncol(Xraw)+3):
# per coverage_gap_registry.csv's own note, existing coverage
# (test-sequential-design-branches.R) only drives the early-fallback branch
# via private-field manipulation; the normal C++-backed path and its
# tryCatch error-fallback were never exercised by any located test.

test_that("assign_wt()'s normal branch (t past the early-fallback threshold) runs via real add_one_subject calls", {
	set.seed(11)
	des <- DesignSeqOneByOneAtkinson$new(response_type = "continuous", n = 15L, prob_T = 0.5, seed = 11)
	priv <- des$.__enclos_env__$private
	ws <- integer(8L)
	for (i in 1:8) {
		ws[i] <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	# threshold = ncol(Xraw) + 3 = 5; subjects 6-8 must have gone through the
	# real atkinson_assign_weight_cpp path, not the early rbinom fallback.
	expect_true(priv$t > ncol(priv$Xraw) + 3)
	expect_true(all(ws %in% c(0L, 1L)))
})

test_that("a genuinely singular/all-constant covariate history no longer crashes assign_wt() past the fallback threshold (bug fixed)", {
	# Previously: assign_wt()'s structure had compute_all_subject_data() called
	# BEFORE the tryCatch that only guarded atkinson_assign_weight_cpp(), so a
	# singular/all-constant covariate history's "subscript out of bounds" error
	# from compute_all_subject_data() propagated uncaught, aborting
	# add_one_subject_to_experiment_and_assign() entirely. Fixed by moving
	# compute_all_subject_data() inside the same tryCatch, so any error from
	# either call now falls back to the documented unbiased Bernoulli(prob_T)
	# draw, same as a failure inside atkinson_assign_weight_cpp() itself.
	des <- DesignSeqOneByOneAtkinson$new(response_type = "continuous", n = 15L, prob_T = 0.5, seed = 12)
	priv <- des$.__enclos_env__$private
	n_before_threshold <- 5L # ncol(Xraw)=2 -> threshold t <= 2+3=5 uses fallback
	for (i in seq_len(n_before_threshold)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1, x2 = 1))
	}
	expect_equal(priv$t, n_before_threshold)
	expect_true(priv$t <= ncol(priv$Xraw) + 3)

	# The next subject (t = 6) crosses into the normal branch; the singular
	# history would previously crash compute_all_subject_data() uncaught --
	# now it falls back gracefully to a valid 0/1 assignment instead.
	w6 <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1, x2 = 1))
	expect_true(w6 %in% c(0L, 1L))
})
