library(testthat)
library(EDI)

# InferenceRandCustom's fast path used to ignore `delta`: the null distribution
# was T(y_delta, w*) for every delta instead of T(y_delta + delta * w*, w*), so
# the randomization p-value was flat in delta and the CI inversion returned
# garbage (e.g. [-8.6, 10.0] vs the correct [-0.04, 1.50] for a difference-in-
# means statistic). Found 2026-09-20 via a raw comprehensive_tests results audit
# (custom rand-CI coverage of 2-13% whenever the true effect was non-zero).

mdiff_stat = function(y, w, dead = NULL) mean(y[w == 1]) - mean(y[w == 0])

custom_delta_fixture = function() {
	set.seed(5)
	n = 80L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	d$add_all_subject_responses(X$x1 + 0.5 * w + rnorm(n))
	d
}

test_that("custom-statistic randomization p-value responds to delta (small at a far null, large at the estimate)", {
	d = custom_delta_fixture()
	pv = function(delta) {
		set.seed(1)
		o = InferenceRandCustom$new(d, custom_randomization_statistic_function = mdiff_stat, verbose = FALSE)
		suppressMessages(suppressWarnings(o$compute_rand_two_sided_pval(r = 999, delta = delta, show_progress = FALSE)))
	}
	expect_gt(pv(0.73), 0.5)
	expect_lt(pv(2.2), 0.05)
	expect_lt(pv(-2), 0.05)
})

test_that("custom difference-in-means randomization CI agrees with the built-in difference-in-means CI", {
	d = custom_delta_fixture()
	set.seed(1)
	custom = InferenceRandCustom$new(d, custom_randomization_statistic_function = mdiff_stat, verbose = FALSE)
	ci_custom = as.numeric(suppressMessages(suppressWarnings(custom$compute_rand_confidence_interval(r = 499, pval_epsilon = 0.005, show_progress = FALSE))))
	set.seed(1)
	builtin = InferenceAllSimpleAverageDiff$new(d)
	ci_builtin = as.numeric(suppressMessages(suppressWarnings(builtin$compute_rand_confidence_interval(r = 499, pval_epsilon = 0.005, show_progress = FALSE))))
	expect_equal(ci_custom, ci_builtin, tolerance = 0.15)
	expect_lt(diff(ci_custom), 3)
})
