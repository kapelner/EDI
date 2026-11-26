library(testthat)
library(EDI)

# v1.0.6-TODO-65: an InferenceRandCustom statistic (R or C++) that is NA/NaN on
# the observed data gave an NA estimate and an NA randomization p-value with no
# warning (only the nonestimable reason "custom_estimate_unavailable" was
# recorded). It now warns, naming which statistic argument returned the value.

nonfinite_stat_fixture = function() {
	set.seed(11)
	n = 30L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(X$x1 + rnorm(n))
	d
}

test_that("an all-NA R custom statistic warns (naming the function argument) and returns NA", {
	d = nonfinite_stat_fixture()
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) NA_real_)
	expect_warning(est <- o$compute_estimate(), "custom_randomization_statistic_function.*returned NA")
	expect_true(is.na(est))
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) NA_real_)
	expect_warning(
		pv <- o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE),
		"custom_randomization_statistic_function.*returned NA"
	)
	expect_true(is.na(pv))
})

test_that("a NaN statistic supplied through custom_randomization_statistic_cpp warns naming that argument", {
	d = nonfinite_stat_fixture()
	# A pre-compiled function goes through the same C++ dispatch as a compiled
	# source string, without needing a compiler.
	o = InferenceRandCustom$new(d, custom_randomization_statistic_cpp = function(y, w) NaN)
	expect_warning(
		pv <- o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE),
		"custom_randomization_statistic_cpp.*returned NaN"
	)
	expect_true(is.na(pv))
})

test_that("an all-NA C++ source-string statistic warns naming custom_randomization_statistic_cpp", {
	skip_on_cran()
	skip_if_not_installed("Rcpp")
	d = nonfinite_stat_fixture()
	src = "double all_na_stat(const Rcpp::NumericVector& y, const Rcpp::IntegerVector& w){
		return NA_REAL;
	}"
	o = InferenceRandCustom$new(d, custom_randomization_statistic_cpp = src)
	expect_warning(est <- o$compute_estimate(), "custom_randomization_statistic_cpp.*returned NA")
	expect_true(is.na(est))
})

test_that("a finite custom statistic does not warn", {
	d = nonfinite_stat_fixture()
	o = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0]))
	expect_no_warning(pv <- o$compute_rand_two_sided_pval(r = 51, show_progress = FALSE))
	expect_true(is.finite(pv))
})
