library(testthat)
library(EDI)

# compute_ci_by_inverting_the_randomization_test_iteratively() and
# high_precision_confirm_and_refine_ci_bound() (InferenceRandCI): bisection to the delta where a
# smooth p-value crosses the threshold (closed form for a normal-shaped p-value), NA endpoints
# re-probed by halving, the conservative-boundary message + counter, the deadline stop, and the
# high-precision pass (refine on a verified sign change, else return the outer end).
# compute_randomization_ci_pval_cached() is stubbed with an analytic p-value.

est <- 0.5; sdv <- 0.8
pnorm_p <- function(d) 2 * pnorm(-abs(d - est) / sdv)

fx <- function(pfun = pnorm_p) {
	set.seed(1)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	calls <- new.env(); calls$deltas <- numeric(0); calls$controls <- list()
	unlockBinding("compute_randomization_ci_pval_cached", p)
	p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		calls$deltas <- c(calls$deltas, delta)
		calls$controls[[length(calls$controls) + 1L]] <- ci_search_control
		pfun(delta)
	}
	list(p = p, calls = calls)
}
bisect <- function(f, l, u, lower, th = 0.05, tol = 1e-7, ctrl = list(high_precision_confirm = FALSE)) {
	f$p$compute_ci_by_inverting_the_randomization_test_iteratively(r = 100L, l = l, u = u, pval_th = th, tol = tol,
		transform_responses = "none", lower = lower, show_progress = FALSE, ci_search_control = ctrl)
}

test_that("the lower and upper bounds converge to the normal-theory crossing points", {
	f <- fx()
	z <- qnorm(1 - 0.05 / 2)
	expect_equal(bisect(f, est - 6, est, TRUE), est - z * sdv, tolerance = 1e-4)
	expect_equal(bisect(f, est, est + 6, FALSE), est + z * sdv, tolerance = 1e-4)
	f2 <- fx()
	expect_equal(bisect(f2, est - 6, est, TRUE, th = 0.2), est - qnorm(0.9) * sdv, tolerance = 1e-4)
})

test_that("non-finite endpoint p-values are re-probed by moving that end to the midpoint", {
	pf <- function(d) if (d < est - 4) NA_real_ else pnorm_p(d)
	f <- fx(pf)
	got <- bisect(f, est - 6, est, TRUE)
	expect_equal(got, est - qnorm(0.975) * sdv, tolerance = 1e-4)
	expect_true(is.na(bisect(fx(function(d) NA_real_), est - 6, est, TRUE)))
})

test_that("a still-accepted search boundary is returned as a conservative bound with a message and counter", {
	flat <- function(d) 0.5
	f <- fx(flat)
	expect_message(lo <- bisect(f, est - 6, est, TRUE), "lower bound is conservative")
	expect_equal(lo, est - 6)
	expect_equal(f$p$rand_ci_conservative_count, 1L)
	expect_message(up <- bisect(f, est, est + 6, FALSE), "upper bound is conservative")
	expect_equal(up, est + 6)
	expect_equal(f$p$rand_ci_conservative_count, 2L)
})

test_that("an elapsed deadline stops the search with the step label", {
	f <- fx()
	ctrl <- list(high_precision_confirm = FALSE, timeout_deadline = unname(proc.time()[["elapsed"]]) - 10)
	expect_error(bisect(f, est - 6, est, TRUE, ctrl = ctrl), "Randomization CI bisection reached elapsed time limit")
})

test_that("high-precision confirmation is skipped unless requested (returns the bracket end for the bound's side)", {
	f <- fx()
	p <- f$p
	expect_equal(p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, list(high_precision_confirm = FALSE), 0.05, 1e-6), 1)
	expect_equal(p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, list(), 0.05, 1e-6), 2)
	expect_length(f$calls$deltas, 0L)
})

test_that("with confirmation on, the bound is refined on a fresh un-early-stopped evaluation", {
	f <- fx()
	z <- qnorm(0.975)
	ctrl <- list(high_precision_confirm = TRUE, mc_enable = TRUE)
	out <- f$p$high_precision_confirm_and_refine_ci_bound(est - z * sdv - 0.3, est - z * sdv + 0.3, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-8)
	expect_equal(out, est - z * sdv, tolerance = 1e-3)
	expect_true(all(vapply(f$calls$controls, function(cc) identical(cc$mc_enable, FALSE), logical(1))))
})

test_that("SOURCE BUG (pinned, not fixed): the high-precision refinement ignores `lower`, so an upper bound converges to the wrong end of its bracket", {
	# The refinement loop always sets u2 <- m when p(m) >= threshold. That is right for a lower bound
	# (accepted side is the upper end of the bracket) but for an upper bound the accepted side is the
	# LOWER end, so it walks u2 down to l2 instead of up to the crossing.
	z <- qnorm(0.975)
	f <- fx()
	ctrl <- list(high_precision_confirm = TRUE, mc_enable = TRUE)
	l0 <- est + z * sdv - 0.3; u0 <- est + z * sdv + 0.3
	out <- f$p$high_precision_confirm_and_refine_ci_bound(l0, u0, FALSE, 100L, "none", NULL, ctrl, 0.05, 1e-8)
	expect_lt(abs(out - l0), 1e-3)                       # collapses to the accepted end
	expect_gt(abs(out - (est + z * sdv)), 0.2)           # not the true crossing
})

test_that("same-side full-precision p-values return the conservative outer end; non-finite ones return the input end", {
	ctrl <- list(high_precision_confirm = TRUE)
	f <- fx(function(d) 0.9)                      # both ends accepted
	expect_equal(f$p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 1)
	expect_equal(f$p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 2)
	g <- fx(function(d) 0.001)                    # both ends rejected
	expect_equal(g$p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 1)
	h <- fx(function(d) NA_real_)
	expect_equal(h$p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 2)
})
