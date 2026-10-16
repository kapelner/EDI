library(testthat)
library(EDI)

K <- function(nm) get(nm, envir = asNamespace("EDI"))

# DesignSeqOneByOneAtkinson$assign_wt() (design_seq_one_by_one_atkinson.R, registry weighted_opportunity
# 7) has a tryCatch around its call to atkinson_assign_weight_cpp(): if the C++ call throws (a
# non-invertible/non-finite-bias design), it falls back to an unbiased coin flip
# (rbinom(1, 1, private$prob_T)) rather than propagating the error and aborting enrollment. This
# branch was untested -- reading atkinson_assign.cpp shows the C++ kernel itself is written to degrade
# gracefully on non-invertible/non-finite cases (falling back to its own internal coin flip rather than
# throwing), so no R-constructible Xraw/w history was found that makes it actually throw; the guard is
# exercised here instead via a mocked atkinson_assign_weight_cpp that deliberately throws, which is a
# legitimate way to confirm the *design's own* tryCatch/fallback wiring works, independent of whether
# the underlying kernel can currently be driven into throwing.

test_that("assign_wt()'s post-warm-up call to atkinson_assign_weight_cpp is wrapped: a forced kernel error is caught and enrollment falls back to an unbiased coin flip rather than aborting", {
	call_count <- 0
	local_mocked_bindings(
		atkinson_assign_weight_cpp = function(...) {
			call_count <<- call_count + 1
			stop("forced failure for coverage of assign_wt()'s tryCatch fallback")
		},
		.package = "EDI"
	)

	set.seed(1L)
	n <- 30L
	des <- DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", verbose = FALSE, prob_T = 0.5)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	ws <- integer(n)
	for (i in seq_len(n)) {
		ws[i] <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}

	# the mock must actually have been reached (i.e. we exercised the post-warm-up branch, not just
	# the early t <= ncol(Xraw) + 3 fallback, which never calls atkinson_assign_weight_cpp at all)
	expect_gt(call_count, 0)
	expect_equal(des$get_n(), n)
	expect_true(all(ws %in% c(0L, 1L)))
})

test_that("without the mock, the same fixture completes normally (sanity check that the mocked test above isn't accidentally testing something already broken)", {
	set.seed(1L)
	n <- 30L
	des <- DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", verbose = FALSE, prob_T = 0.5)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	expect_equal(des$get_n(), n)
})

atkinson_assignment_probability_reference <- function(w_prev, X_prev, xt_prev, t) {
	# Direct translation of the documented D-optimal leverage update, independent of the C++ RNG.
	# The treatment, intercept, and covariate columns form Z; M=(t-1)(Z'Z)^-1.
	Z <- cbind(w_prev, 1, X_prev)
	M <- (t - 1) * solve(crossprod(Z))
	x <- c(1, xt_prev)
	A <- sum(M[1, -1] * x)
	v <- M[1, 1] / A + 1
	v^2 / (v^2 + 1)
}

test_that("the live Atkinson assignment kernel samples its independent D-optimal probability", {
	set.seed(25L)
	n <- 30L
	w_prev <- rep(0:1, length.out = n)
	X_prev <- cbind(x = seq(-1, 1, length.out = n))
	xt_prev <- 0.35
	t <- n + 1L
	p_ref <- atkinson_assignment_probability_reference(w_prev, X_prev, xt_prev, t)
	expect_true(is.finite(p_ref) && p_ref > 0 && p_ref < 1)

	# Atkinson's first-stage gate is already past: t = n + 1 > ncol(X_prev) + 3.
	set.seed(26L)
	draws <- replicate(2000L, K("atkinson_assign_weight_cpp")(w_prev, X_prev, xt_prev, ncol(X_prev), t))
	expect_true(all(draws %in% c(0, 1)))
	expect_equal(mean(draws), p_ref, tolerance = 0.04)
})
