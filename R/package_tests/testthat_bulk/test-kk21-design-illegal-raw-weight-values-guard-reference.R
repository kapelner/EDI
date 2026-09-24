library(testthat)
library(EDI)

# DesignSeqOneByOneKK21's own assign_wt() (design_seq_one_by_one_KK21.R) validates private$compute_weights()'s
# output before normalizing it into private$covariate_weights: any NA, Inf, NaN, or negative entry stop()s with
# "raw weight values illegal in design <classname>" -- confirmed reachable via a zero-hit grep for the exact
# message across the whole test suite. Under normal operation compute_weights() (KK21's own bootstrapped
# per-covariate weight estimator) never actually produces an illegal value, so this guard is only reachable by
# stubbing compute_weights() directly -- the same technique already used by
# test-kk21-design-assign-wt-nearest-reservoir-match-opposite-arm-and-new-id-with-stubbed-weights-reference.R
# for the (legal-weights) matching-arithmetic path, just with an illegal return value here instead.
#   1. Each of NA, Inf, NaN, and a negative weight independently triggers the guard, with the design's own
#      class name interpolated into the message.
#   2. The identical fixture with a normal (all-positive, finite) stubbed weight vector does NOT error.

kk21_past_burn_in <- function(seed, n_burn_in = 15L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n_burn_in + 5L, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n_burn_in)) {
		x1 <- rnorm(1); x2 <- rnorm(1)
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		des$add_one_subject_response(i, x1 + w + rnorm(1))
	}
	des
}

test_that("NA, Inf, NaN and a negative raw weight each trigger the illegal-weights guard with the class name interpolated", {
	bad_vals <- list(na = NA_real_, inf = Inf, nan = NaN, negative = -1)
	for (nm in names(bad_vals)) {
		des <- kk21_past_burn_in(seed = 1L)
		p <- des$.__enclos_env__$private
		unlockBinding("compute_weights", p)
		p$compute_weights <- local({
			bad <- bad_vals[[nm]]
			function(all_subject_data) {
				v <- numeric(ncol(all_subject_data$X_all_with_y_scaled)); v[1L] <- bad; v
			}
		})
		expect_error(
			{
				x1 <- rnorm(1); x2 <- rnorm(1)
				w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
				des$add_one_subject_response(16L, x1 + w + rnorm(1))
			},
			"raw weight values illegal in design DesignSeqOneByOneKK21",
			info = nm
		)
	}
})

test_that("a normal (all-positive, finite) stubbed weight vector does not trigger the guard", {
	des <- kk21_past_burn_in(seed = 2L)
	p <- des$.__enclos_env__$private
	unlockBinding("compute_weights", p)
	p$compute_weights <- function(all_subject_data) {
		v <- numeric(ncol(all_subject_data$X_all_with_y_scaled)); v[1L] <- 1; v
	}
	expect_no_error({
		x1 <- rnorm(1); x2 <- rnorm(1)
		w <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		des$add_one_subject_response(16L, x1 + w + rnorm(1))
	})
})
