library(testthat)
library(EDI)

# v1.0.6-TODO-64 / v1.0.6-TODO-42: on an incidence response, InferenceRandCustom
# with a C++ statistic refused compute_rand_two_sided_pval() even at delta = 0
# ("Use Zhang method"), while the R-function form slipped past the documented ban
# on nonzero delta. One guard now applies to both forms: delta = 0 runs, nonzero
# delta errors.

incid_custom_fixture = function() {
	set.seed(3)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rbinom(n, 1, 0.5))
	d
}

incid_mdiff_r = function(y, w, dead = NULL) mean(y[w == 1]) - mean(y[w == 0])
incid_mdiff_cpp = "double incid_md(const Rcpp::NumericVector& y, const Rcpp::NumericVector& w){
	double s1 = 0, s0 = 0; int n1 = 0, n0 = 0;
	for (int i = 0; i < y.size(); i++) { if (w[i] == 1) { s1 += y[i]; n1++; } else { s0 += y[i]; n0++; } }
	return s1 / n1 - s0 / n0; }"

incid_pval = function(o, delta) {
	set.seed(1)
	suppressMessages(suppressWarnings(o$compute_rand_two_sided_pval(r = 199, delta = delta, show_progress = FALSE)))
}

test_that("R-function custom statistic on incidence: delta = 0 runs, nonzero delta errors", {
	o = InferenceRandCustom$new(incid_custom_fixture(), custom_randomization_statistic_function = incid_mdiff_r, verbose = FALSE)
	expect_true(o$supports_rand_pval_for_incidence())
	p = incid_pval(o, 0)
	expect_true(is.finite(p) && p > 0 && p <= 1)
	expect_error(incid_pval(o, 0.1), "delta nonzero not supported for incidence")
})

test_that("C++ custom statistic on incidence: delta = 0 runs (same p as the R form), nonzero delta errors", {
	skip_on_cran()
	skip_if_not_installed("Rcpp")
	d = incid_custom_fixture()
	o = InferenceRandCustom$new(d, custom_randomization_statistic_cpp = incid_mdiff_cpp, verbose = FALSE)
	expect_true(o$supports_rand_pval_for_incidence())
	p = incid_pval(o, 0)
	expect_true(is.finite(p) && p > 0 && p <= 1)
	o_r = InferenceRandCustom$new(d, custom_randomization_statistic_function = incid_mdiff_r, verbose = FALSE)
	expect_equal(p, incid_pval(o_r, 0))
	expect_error(incid_pval(o, 0.1), "delta nonzero not supported for incidence")
})
