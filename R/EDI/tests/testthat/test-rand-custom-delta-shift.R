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

# TODO-100: the CI search used to be seeded on compute_estimate(), i.e. the
# statistic's own value. A Welch t statistic (1.5) is not in delta units, so the
# search ran in the wrong place and returned a band (1.35, 1.81) of rejected
# deltas that excluded delta = 0. The search is now centred on the delta-scale
# mean difference and requires an accepted interior point.
welch_t_stat = function(y, w, dead = NULL) {
	y1 = y[w == 1]; y0 = y[w == 0]
	(mean(y1) - mean(y0)) / sqrt(stats::var(y1) / length(y1) + stats::var(y0) / length(y0))
}
neg10_stat = function(y, w, dead = NULL) -10 * (mean(y[w == 1]) - mean(y[w == 0]))

custom_scale_fixture = function() {
	set.seed(1)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	d$add_all_subject_responses(X$x1 + 0.5 * w + rnorm(n))
	d
}

test_that("custom-statistic randomization CI is on the delta scale whatever the statistic's units", {
	d = custom_scale_fixture()
	ci_of = function(fn) {
		set.seed(1)
		o = InferenceRandCustom$new(d, custom_randomization_statistic_function = fn, verbose = FALSE)
		as.numeric(suppressMessages(suppressWarnings(o$compute_rand_confidence_interval(r = 499, pval_epsilon = 0.005, show_progress = FALSE))))
	}
	ci_mean = ci_of(mdiff_stat)
	ci_t = ci_of(welch_t_stat)
	ci_neg = ci_of(neg10_stat)
	for (ci in list(ci_t, ci_neg)) {
		expect_true(all(is.finite(ci)))
		expect_lt(ci[1], 0)   # the mean-difference CI covers delta = 0 (p = 0.144)
		expect_gt(ci[2], 0)
		expect_equal(ci, ci_mean, tolerance = 0.2)
	}
})

test_that("custom-statistic randomization CI errors rather than returning a band of rejected deltas", {
	d = custom_scale_fixture()
	# Ignores the shift entirely, so the test rejects (p tiny) or accepts at every
	# delta alike; use a statistic that is rejected everywhere: constant large
	# observed value vs a degenerate permutation distribution is not shift-based,
	# so instead force rejection with a statistic of the permuted w only.
	always_extreme = function(y, w, dead = NULL) if (all(w == get("w_obs", envir = globalenv()))) 1e6 else 0
	assign("w_obs", d$get_w(), envir = globalenv())
	on.exit(rm("w_obs", envir = globalenv()), add = TRUE)
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = always_extreme, verbose = FALSE)
	res = tryCatch(suppressMessages(suppressWarnings(o$compute_rand_confidence_interval(r = 199, show_progress = FALSE))), error = function(e) e)
	expect_true(inherits(res, "error") || all(is.na(as.numeric(res))))
})

# TODO-100 plan fixture: DesignFixedRerandomization, n = 60, seed 1 (observed
# mean difference 0.452, Welch t 1.505). Pre-fix the Welch-t CI was
# (1.353, 1.808), a band of rejected deltas excluding delta = 0 (p = 0.144).
rerand_scale_fixture = function() {
	set.seed(1)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedRerandomization$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	d$add_all_subject_responses(X$x1 + 0.5 * w + rnorm(n))
	d
}

test_that("Welch-t custom randomization CI on the rerandomization fixture covers delta = 0 and matches the mean-difference CI", {
	d = rerand_scale_fixture()
	ci_of = function(fn) {
		set.seed(1)
		o = InferenceRandCustom$new(d, custom_randomization_statistic_function = fn, verbose = FALSE)
		as.numeric(suppressMessages(suppressWarnings(o$compute_rand_confidence_interval(r = 499, pval_epsilon = 0.005, show_progress = FALSE))))
	}
	ci_mean = ci_of(mdiff_stat)
	ci_t = ci_of(welch_t_stat)
	expect_lt(ci_t[1], 0)
	expect_gt(ci_t[2], 0)
	expect_equal(ci_t, ci_mean, tolerance = 0.2)
})

test_that("custom_randomization_statistic_cpp with a scaled, sign-flipped statistic gives the delta-scale CI", {
	skip_on_cran()
	skip_if_not_installed("Rcpp")
	d = rerand_scale_fixture()
	src = "double neg10(const Rcpp::NumericVector& y, const Rcpp::NumericVector& w){
		double s1 = 0, s0 = 0; int n1 = 0, n0 = 0;
		for (int i = 0; i < y.size(); i++) { if (w[i] == 1) { s1 += y[i]; n1++; } else { s0 += y[i]; n0++; } }
		return -10.0 * (s1 / n1 - s0 / n0); }"
	set.seed(1)
	o = InferenceRandCustom$new(d, custom_randomization_statistic_cpp = src, verbose = FALSE)
	ci = as.numeric(suppressMessages(suppressWarnings(o$compute_rand_confidence_interval(r = 499, pval_epsilon = 0.005, show_progress = FALSE))))
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], 0)
	expect_gt(ci[2], 0)
	expect_lt(diff(ci), 3)
})

# TODO-113: compute_rand_two_sided_pval() doubled the smaller tail for every
# statistic. For a non-negative, one-tailed-by-construction statistic (squared
# mean difference) the lower tail is uninformative, so an observed statistic at
# the bottom of the null distribution (strong support for H0) got a small
# "two-sided" p (~0.1 here) instead of the upper-tail p (~0.94).
test_that("alternative = 'greater' gives the single upper-tail p-value for a non-negative statistic", {
	set.seed(5)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	y = rnorm(n)
	y[w == 1] = y[w == 1] - (mean(y[w == 1]) - mean(y[w == 0])) + 0.02   # observed mean diff ~ 0
	d$add_all_subject_responses(y)
	sq_stat = function(y, w, dead = NULL) (mean(y[w == 1]) - mean(y[w == 0]))^2
	mk = function() InferenceRandCustom$new(d, custom_randomization_statistic_function = sq_stat, verbose = FALSE)
	pv = function(...) { set.seed(1); suppressMessages(suppressWarnings(mk()$compute_rand_two_sided_pval(r = 999, show_progress = FALSE, ...))) }
	p_two = pv()
	p_gt = pv(alternative = "greater")
	p_lt = pv(alternative = "less")
	expect_gt(p_gt, 0.8)                     # the correct one-sided p: t_obs sits at the bottom of the null
	expect_lt(p_two, 0.5)                    # default keeps the historical doubled-tail behaviour
	expect_equal(p_two, pv(alternative = "two.sided"))
	expect_lt(p_lt, 0.1)
	expect_error(pv(alternative = "bogus"))
})

test_that("alternative = 'greater' / 'less' single tails equal the tail proportions and the default is unchanged", {
	f = EDI:::rand_pval_from_tail_counts
	expect_equal(f(30, 80, 100), 0.6)
	expect_equal(f(30, 80, 100, "greater"), 0.3)
	expect_equal(f(30, 80, 100, "less"), 0.8)
	expect_equal(f(0, 100, 100, "greater"), 0.01)   # 1/n floor
	expect_equal(f(0, 100, 100), 0.02)              # 2/n floor
	expect_equal(f(90, 20, 100), 0.4)
})
