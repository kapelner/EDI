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
	list(inf = inf, p = p, calls = calls)
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

test_that("high-precision lower and upper refinements converge to mirrored crossings", {
	z <- qnorm(0.975)
	f <- fx()
	ctrl <- list(high_precision_confirm = TRUE, mc_enable = TRUE)
	lower_crossing <- est - z * sdv
	upper_crossing <- est + z * sdv
	lower <- f$p$high_precision_confirm_and_refine_ci_bound(
		lower_crossing - 0.3, lower_crossing + 0.3, TRUE,
		100L, "none", NULL, ctrl, 0.05, 1e-8
	)
	upper <- f$p$high_precision_confirm_and_refine_ci_bound(
		upper_crossing - 0.3, upper_crossing + 0.3, FALSE,
		100L, "none", NULL, ctrl, 0.05, 1e-8
	)
	expect_equal(lower, lower_crossing, tolerance = 1e-3)
	expect_equal(upper, upper_crossing, tolerance = 1e-3)
	expect_equal(lower + upper, 2 * est, tolerance = 1e-3)
})

test_that("public randomization CI reaches both refinement directions when cheap p-values hide a wide crossing", {
	f <- fx()
	center <- f$inf$compute_estimate()
	threshold <- 0.05
	entry_widths <- numeric(0)
	f$p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		full_p <- 2 * pnorm(-abs(delta - center) / sdv)
		if (isTRUE(ci_search_control$mc_enable)) {
			return(if (full_p >= threshold) threshold + 0.001 else threshold - 0.001)
		}
		full_p
	}
	original_refine <- f$p$high_precision_confirm_and_refine_ci_bound
	unlockBinding("high_precision_confirm_and_refine_ci_bound", f$p)
	f$p$high_precision_confirm_and_refine_ci_bound <- function(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol) {
		entry_widths <<- c(entry_widths, u - l)
		original_refine(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol)
	}
	ci <- f$inf$compute_rand_confidence_interval(
		alpha = 0.10, r = 201L, pval_epsilon = 0.01, show_progress = FALSE,
		ci_search_control = list(mc_enable = TRUE, high_precision_confirm = TRUE, seed = "none")
	)
	expect_length(entry_widths, 2L)
	expect_true(all(entry_widths > 0.01))
	expect_equal(as.numeric(ci), center + c(-1, 1) * qnorm(0.975) * sdv, tolerance = 1e-2)
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
