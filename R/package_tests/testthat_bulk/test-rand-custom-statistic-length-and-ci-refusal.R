library(testthat)
library(EDI)

# v1.0.6-TODO-83: an InferenceRandCustom statistic returning several values was
# silently cut to its first value (estimate 1 for function(y, w, dead) c(1, 2)).
# It is now an error naming the statistic argument and the length.
# v1.0.6-TODO-84: the count/proportion randomization-CI refusal told
# InferenceRandCustom users the randomization-bootstrap CI "remains available",
# but this class has no bootstrap. The message now names only the p-value, and
# the capability lookups agree with what runs.

rand_custom_fixture = function(response_type = "continuous") {
	set.seed(5)
	n = 30L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	y = switch(response_type,
		continuous = X$x1 + rnorm(n),
		count = rpois(n, 3),
		proportion = runif(n, 0.1, 0.9)
	)
	d$add_all_subject_responses(y)
	d
}

mean_diff_stat = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0])

test_that("an R statistic returning two values is an error naming the argument and the length", {
	d = rand_custom_fixture()
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) c(1, 2))
	expect_error(o$compute_estimate(), "custom_randomization_statistic_function.*returned 2 values")
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) c(1, 2))
	expect_error(o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE), "returned 2 values")
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) numeric(0))
	expect_error(o$compute_estimate(), "returned 0 values")
})

test_that("a C++ statistic returning two values is an error naming custom_randomization_statistic_cpp", {
	d = rand_custom_fixture()
	# A pre-compiled function goes through the same C++ dispatch as a compiled source string.
	o = InferenceRandCustom$new(d, custom_randomization_statistic_cpp = function(y, w) c(1, 2))
	expect_error(o$compute_estimate(), "custom_randomization_statistic_cpp.*returned 2 values")
})

test_that("a C++ source-string statistic returning a length-2 NumericVector is refused", {
	skip_on_cran()
	skip_if_not_installed("Rcpp")
	src = paste(
		"Rcpp::NumericVector two_vals(Rcpp::NumericVector y, Rcpp::IntegerVector w) {",
		"  return Rcpp::NumericVector::create(1.0, 2.0);",
		"}", sep = "\n")
	d = rand_custom_fixture()
	o = tryCatch(InferenceRandCustom$new(d, custom_randomization_statistic_cpp = src), error = function(e) NULL)
	skip_if(is.null(o), "C++ toolchain unavailable")
	expect_error(o$compute_estimate(), "custom_randomization_statistic_cpp.*returned 2 values")
})

test_that("a scalar statistic is unaffected", {
	d = rand_custom_fixture()
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = mean_diff_stat)
	y = d$get_y(); w = d$get_w()
	expect_equal(o$compute_estimate(), mean(y[w == 1]) - mean(y[w == 0]))
	o$set_seed(1)
	pv = o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("count/proportion randomization-CI refusal names only what InferenceRandCustom can run", {
	for (rt in c("count", "proportion")) {
		d = rand_custom_fixture(rt)
		o = InferenceRandCustom$new(d, custom_randomization_statistic_function = mean_diff_stat)
		expect_false(o$supports("randomization_ci"))
		expect_true(o$supports("randomization_test"))
		expect_false("randomization_ci" %in% o$capabilities())
		expect_false("randomization_ci" %in% EDI:::get_effective_capabilities_for_response_type("InferenceRandCustom", rt))
		err = tryCatch(o$compute_rand_confidence_interval(r = 51, show_progress = FALSE), error = function(e) conditionMessage(e))
		expect_match(err, "not supported for InferenceRandCustom")
		expect_match(err, "compute_rand_two_sided_pval", fixed = TRUE)
		expect_no_match(err, "bootstrap")
		# What it does advertise still runs.
		o$set_seed(1)
		pv = o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)
		expect_true(is.finite(pv))
	}
	# Continuous keeps the CI capability and the CI runs.
	d = rand_custom_fixture("continuous")
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = mean_diff_stat)
	expect_true(o$supports("randomization_ci"))
	o$set_seed(1)
	ci = o$compute_rand_confidence_interval(r = 51, show_progress = FALSE)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
})

test_that("a class with a randomization bootstrap still gets the bootstrap wording", {
	d = rand_custom_fixture("count")
	o = InferenceAllSimpleAverageDiff$new(d, verbose = FALSE)
	err = tryCatch(o$compute_rand_confidence_interval(r = 51, show_progress = FALSE), error = function(e) conditionMessage(e))
	expect_match(err, "randomization-bootstrap CI remain available", fixed = TRUE)
})
