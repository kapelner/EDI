library(testthat)
library(EDI)

make_ci_recovery_probe <- function(inference_class = InferenceAllSimpleAverageDiff) {
	set.seed(20260917)
	d <- DesignFixedBernoulli$new(n = 20L, response_type = "continuous", seed = 20260917L)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(20))
	inference_class$new(d)
}

test_that("bootstrap CI inversion converges on both tails after missing endpoint or midpoint evaluations", {
	p <- make_ci_recovery_probe()$.__enclos_env__$private
	lower <- function(delta) if (delta == 0) numeric() else delta
	upper <- function(delta) if (delta == 1) NA_real_ else 1 - delta
	expect_equal(p$invert_rand_bootstrap_test_bisection(0, 1, .6, .001, TRUE, FALSE, lower), .6, tolerance = .002)
	expect_equal(p$invert_rand_bootstrap_test_bisection(0, 1, .6, .001, FALSE, FALSE, upper), .4, tolerance = .002)
	# Width convergence also terminates when the missing midpoint is exactly
	# the cutoff, so its substituted zero p-value never needs to converge.
	lower_mid <- function(delta) if (delta == .5) NA_real_ else delta
	upper_mid <- function(delta) if (delta == .5) NA_real_ else 1 - delta
	expect_equal(p$invert_rand_bootstrap_test_bisection(0, 1, .5, .001, TRUE, FALSE, lower_mid), .5)
	expect_equal(p$invert_rand_bootstrap_test_bisection(0, 1, .5, .001, FALSE, FALSE, upper_mid), .5)
	calls <- 0L
	missing <- function(delta) { calls <<- calls + 1L; NA_real_ }
	expect_true(is.na(p$invert_rand_bootstrap_test_bisection(0, 1, .5, .001, TRUE, FALSE, missing)))
	expect_equal(calls, 62L) # two endpoints and 30 attempts on each missing endpoint
})

test_that("bootstrap CI conservative bounds report and count each search limit", {
	p <- make_ci_recovery_probe()$.__enclos_env__$private
	# The public CI entry point initializes this counter before inversion.
	p$rand_bootstrap_ci_conservative_count <- 0L
	before <- p$rand_bootstrap_ci_conservative_count
	expect_message(lo <- p$invert_rand_bootstrap_test_bisection(-4, 0, .05, .001, TRUE, FALSE, function(delta) .2), "lower bound is conservative")
	expect_message(hi <- p$invert_rand_bootstrap_test_bisection(0, 7, .05, .001, FALSE, FALSE, function(delta) .2), "upper bound is conservative")
	expect_equal(c(lo, hi), c(-4, 7))
	expect_equal(p$rand_bootstrap_ci_conservative_count, before + 2L)
	# A failed bracket is distinct from a finite conservative search limit.
	expect_true(is.na(p$invert_rand_bootstrap_test_bisection(-Inf, 0, .05, .001, TRUE, FALSE, function(delta) .2)))
	expect_equal(p$rand_bootstrap_ci_conservative_count, before + 2L)
})

test_that("bootstrap CI deadlines interrupt evaluation and failed cache entries are reusable", {
	calls <- 0L
	probe_class <- R6::R6Class("BootstrapCICacheProbe", inherit = InferenceAllSimpleAverageDiff,
		public = list(compute_rand_bootstrap_two_sided_pval = function(...) {
		calls <<- calls + 1L
		args <- list(...)
		expect_identical(args$show_progress, FALSE)
		expect_identical(args$na.rm, TRUE)
		if (args$delta == 0) stop("unavailable fit")
		if (args$delta == 1) return(numeric())
		c(.2, .7)
	}))
	inf <- make_ci_recovery_probe(probe_class)
	p <- inf$.__enclos_env__$private
	expect_false(p$check_rand_bootstrap_ci_deadline(Inf))
	expect_false(p$check_rand_bootstrap_ci_deadline(NA_real_))
	expect_error(p$invert_rand_bootstrap_test_bisection(0, 1, .5, .001, TRUE, FALSE, function(delta) delta, timeout_deadline = -1), "reached elapsed time limit")
	expect_error(p$expand_rand_bootstrap_bound(-1, 0, .05, TRUE, 10, 3L, function(delta) .2, timeout_deadline = -1), "bound expansion reached elapsed time limit")
	cache <- new.env(parent = emptyenv())
	for (delta in c(0, 1, 2)) {
		first <- p$compute_rand_bootstrap_ci_pval_cached(delta, 9L, "none", list(), .001, cache)
		second <- p$compute_rand_bootstrap_ci_pval_cached(delta, 9L, "none", list(), .001, cache)
		expect_identical(second, first)
		if (delta < 2) expect_true(is.na(first)) else expect_equal(first, .2)
	}
	expect_equal(calls, 3L)
})
