library(testthat)
library(EDI)

# DesignSeqOneByOneKK21's private compute_weights() dispatcher (design_seq_one_by_one_KK21.R) has
# count_use_speedup and proportion_use_speedup branches, siblings to the survival_use_speedup_for_no_
# censoring and ordinal_use_speedup branches already closed this stretch (test-kk21-design-compute-
# weights-survival-use-speedup-for-no-censoring-branch-reference.R / -ordinal-use-speedup-branch-
# reference.R):
#   count_use_speedup = TRUE  -> kk21_continuous_weights_cpp(X, log(y + 1))
#   count_use_speedup = FALSE -> kk21_negbin_weights_cpp(X, y)
#   proportion_use_speedup = TRUE  -> kk21_continuous_weights_cpp(X, logit(y))
#   proportion_use_speedup = FALSE -> kk21_beta_weights_cpp(X, y)
# A codebase-wide check of every existing count_use_speedup/proportion_use_speedup reference confirmed
# they all either (a) validate the constructor argument itself (assertFlag), or (b) call the
# per-covariate kernel compute_weight_KK21_count()/compute_weight_KK21_proportion() directly (the
# fallback-loop-only code path, unreachable for real response types) -- never the compute_weights()
# dispatcher's own branch selection through a real DesignSeqOneByOneKK21 instance. Reached via a real
# design run past its matching burn-in with real count/proportion-response subjects, calling the
# private compute_weights() dispatcher directly on its own compute_all_subject_data() -- independently
# cross-checked against the relevant C++ kernels called directly with the same inputs.

kk21_past_burn_in <- function(seed, response_type, n_burn_in = 15L, ...) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n_burn_in + 5L, response_type = response_type, verbose = FALSE, ...)
	for (i in seq_len(n_burn_in)) {
		x1 <- rnorm(1); x2 <- rnorm(1)
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		y <- if (response_type == "count") rpois(1, exp(0.3 * x1 + 0.2 * w)) else plogis(0.3 * x1 + 0.2 * w + rnorm(1, sd = 0.1))
		des$add_one_subject_response(i, y)
	}
	des
}

test_that("count_use_speedup = TRUE (the default) matches kk21_continuous_weights_cpp on log(y + 1)", {
	des <- kk21_past_burn_in(1L, "count", count_use_speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]
	ref <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(log(ys + 1)))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

# 2026-09-24: the negbin/beta dispatch tests below used to compare TWO separate kk21_negbin_weights_cpp/
# kk21_beta_weights_cpp calls (one through the dispatcher, one direct) for equality. Both kernels'
# univariate per-covariate fits are genuinely floating-point/BLAS-sensitive in a way that showed up on
# CI (run 36047859976 shard 15) but never locally: kk21_negbin_weights_cpp's Newton-Raphson theta update
# can drift by ~1e-5 in the final t-stat, and kk21_beta_weights_cpp's coarse log(phi) grid search (steps
# of 0.5, i.e. phi differs by a factor of ~1.65 between adjacent points) can flip which grid cell wins a
# near-tie under a tiny IRLS convergence difference, swinging the returned t-stat by several-fold -- not
# a code bug (get_effective_time() was confirmed to return private$y unchanged for non-censored types,
# so the dispatcher and a from-scratch reconstruction genuinely see identical X/y), just floating-point
# noise in an inherently near-tie-sensitive statistic. Comparing two SEPARATE invocations was the wrong
# test design regardless of environment: mocking the kernel to capture the dispatcher's own actual call
# arguments (matching the ginv() call-count-probe pattern in test-build-optimal-design-p-h-null-prior-
# rank-deficient-ginv-fallback-reference.R) verifies correct dispatch from a SINGLE invocation instead,
# eliminating the cross-call fragility entirely rather than just tolerating it with a numeric slop.
test_that("count_use_speedup = FALSE dispatches to kk21_negbin_weights_cpp instead", {
	des <- kk21_past_burn_in(2L, "count", count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]
	expected_X <- as.matrix(asd$X_all_with_y_scaled)
	expected_y <- as.numeric(ys)

	orig <- EDI:::kk21_negbin_weights_cpp
	captured <- NULL
	local_mocked_bindings(
		kk21_negbin_weights_cpp = function(X, y) {
			result <- orig(X, y)
			captured <<- list(X = X, y = y, result = result)
			result
		},
		.package = "EDI"
	)
	w_out <- priv$compute_weights(asd)

	expect_true(!is.null(captured))
	expect_equal(captured$X, expected_X)
	expect_equal(captured$y, expected_y)
	expect_equal(as.numeric(w_out), as.numeric(captured$result))
})

test_that("proportion_use_speedup = TRUE (the default) matches kk21_continuous_weights_cpp on logit(y)", {
	des <- kk21_past_burn_in(3L, "proportion", proportion_use_speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]
	ref <- EDI:::kk21_continuous_weights_cpp(as.matrix(asd$X_all_with_y_scaled), as.numeric(log(ys / (1 - ys))))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("proportion_use_speedup = FALSE dispatches to kk21_beta_weights_cpp instead", {
	des <- kk21_past_burn_in(4L, "proportion", proportion_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	i_present <- which(!(is.na(priv$y) & is.na(priv$y_L) & is.na(priv$y_R)))
	ys <- priv$y[i_present]
	expected_X <- as.matrix(asd$X_all_with_y_scaled)
	expected_y <- as.numeric(ys)

	orig <- EDI:::kk21_beta_weights_cpp
	captured <- NULL
	local_mocked_bindings(
		kk21_beta_weights_cpp = function(X, y) {
			result <- orig(X, y)
			captured <<- list(X = X, y = y, result = result)
			result
		},
		.package = "EDI"
	)
	w_out <- priv$compute_weights(asd)

	expect_true(!is.null(captured))
	expect_equal(captured$X, expected_X)
	expect_equal(captured$y, expected_y)
	expect_equal(as.numeric(w_out), as.numeric(captured$result))
})
