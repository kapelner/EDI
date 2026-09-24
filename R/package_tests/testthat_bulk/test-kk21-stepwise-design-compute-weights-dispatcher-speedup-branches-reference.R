library(testthat)
library(EDI)

# DesignSeqOneByOneKK21stepwise's private compute_weights() dispatcher (design_seq_one_by_one_KK21_
# stepwise.R) has the same response-type/use_speedup branch structure already closed for its
# non-stepwise sibling DesignSeqOneByOneKK21 (test-kk21-design-compute-weights-survival-use-speedup-
# for-no-censoring-branch-reference.R / -ordinal-use-speedup-branch-reference.R / -count-and-
# proportion-use-speedup-branches-reference.R). Every existing count_use_speedup/proportion_use_
# speedup/ordinal_use_speedup reference for THIS (stepwise) class calls the per-response-type kernel
# method (compute_weights_KK21stepwise_count() etc.) directly -- confirmed by reading each reference
# file -- never the compute_weights() dispatcher itself through a real instance. Reached the same way
# as the non-stepwise class: a real design run past its matching burn-in, calling compute_weights()
# directly on its own compute_all_subject_data(), cross-checked against the underlying C++ kernels.
#
# REAL SOURCE BUG found while writing this (confirmed, NOT fixed, per instructions): kk21_stepwise_
# continuous_weights_cpp() -- the shared kernel behind every use_speedup = TRUE branch here (count,
# proportion, ordinal) and behind the plain "continuous"/survival-uncensored branches -- is NOT
# deterministic for some inputs. Calling it twice with bit-identical (xs, ys, ws) arguments (verified
# via a monkey-patched capture confirming the actual arguments compute_weights() passed were literally
# identical() across both calls) can return DIFFERENT numeric results; across 15 random seeds of a
# proportion_use_speedup = TRUE fixture, roughly half were unstable (see probe transcript). This
# affects every KK21(stepwise) matching decision made through this fast path whenever the underlying
# stepwise covariate-selection has a near-tie or rank-deficiency, silently returning a different (but
# similarly-plausible-looking) weight vector from run to run given the SAME accumulated data -- a
# reproducibility/determinism bug, not merely a numerical-precision one. This test file works around it
# by using specific fixture seeds independently confirmed (by calling compute_weights() twice on the
# same accumulated data and checking for an identical result) to land on the function's stable regime,
# so the assertions below are not flaky, but the underlying kernel bug remains.

na0 <- function(w) { w[is.na(w)] <- 0; w }

kk21sw_fixture <- function(seed, response_type, n_burn_in = 20L, y_fn, ...) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21stepwise$new(n = n_burn_in + 5L, response_type = response_type, verbose = FALSE, ...)
	for (i in seq_len(n_burn_in)) {
		x1 <- rnorm(1); x2 <- rnorm(1)
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		des$add_one_subject_response(i, y_fn(x1, x2, w))
	}
	des
}

test_that("count_use_speedup = TRUE matches kk21_stepwise_continuous_weights_cpp on log(y + 1)", {
	des <- kk21sw_fixture(1L, "count", y_fn = function(x1, x2, w) rpois(1, exp(1 + 0.3 * x1 + 0.2 * w)), count_use_speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled, log(asd$y_all + 1), asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("count_use_speedup = FALSE dispatches to kk21_stepwise_negbin_weights_cpp instead", {
	des <- kk21sw_fixture(1L, "count", y_fn = function(x1, x2, w) rpois(1, exp(1 + 0.3 * x1 + 0.2 * w)), count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_negbin_weights_cpp(asd$X_all_with_y_scaled, asd$y_all, asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("proportion_use_speedup = TRUE matches kk21_stepwise_continuous_weights_cpp on logit(y)", {
	des <- kk21sw_fixture(3L, "proportion", n_burn_in = 30L,
		y_fn = function(x1, x2, w) plogis(0.5 * x1 - 0.4 * x2 + 0.2 * w + rnorm(1, sd = 0.15)),
		proportion_use_speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	y <- asd$y_all; y[y == 0] <- .Machine$double.eps; y[y == 1] <- 1 - .Machine$double.eps
	ref <- na0(EDI:::kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled, log(y / (1 - y)), asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("proportion_use_speedup = FALSE dispatches to kk21_stepwise_beta_weights_cpp instead", {
	des <- kk21sw_fixture(1L, "proportion", y_fn = function(x1, x2, w) plogis(0.3 * x1 + 0.2 * w + rnorm(1, sd = 0.1)), proportion_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_beta_weights_cpp(asd$X_all_with_y_scaled, asd$y_all, asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("ordinal_use_speedup = TRUE matches kk21_stepwise_continuous_weights_cpp on the raw integer-coded levels", {
	levs <- c("low", "med", "high")
	des <- kk21sw_fixture(1L, "ordinal", y_fn = function(x1, x2, w) factor(sample(levs, 1), levels = levs, ordered = TRUE), ordinal_use_speedup = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled, asd$y_all, asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("ordinal_use_speedup = FALSE dispatches to kk21_stepwise_ordinal_weights_cpp instead", {
	levs <- c("low", "med", "high")
	des <- kk21sw_fixture(1L, "ordinal", y_fn = function(x1, x2, w) factor(sample(levs, 1), levels = levs, ordered = TRUE), ordinal_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_ordinal_weights_cpp(asd$X_all_with_y_scaled, asd$y_all, asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})

test_that("survival_use_speedup_for_no_censoring = TRUE with an all-uncensored sample matches kk21_stepwise_continuous_weights_cpp on log(y)", {
	des <- kk21sw_fixture(1L, "survival", y_fn = function(x1, x2, w) rexp(1, exp(-0.3 * w)), survival_use_speedup_for_no_censoring = TRUE)
	priv <- des$.__enclos_env__$private
	asd <- priv$compute_all_subject_data()
	w_out <- priv$compute_weights(asd)
	ref <- na0(EDI:::kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled, log(asd$y_all), asd$w_all_with_y_scaled))
	expect_equal(as.numeric(w_out), as.numeric(ref))
})
