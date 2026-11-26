library(testthat)
library(EDI)

# v1.0.6-TODO-60: transform_y() ran assert_y() (any.missing = FALSE) over the
# whole transformed vector, but y_original is NA for every censored survival row
# (entered through y_L/y_R), so transform_y() errored ("Contains missing
# values") on any survival design with a censored subject. It now checks only
# the rows with an observed y_original.

ty_censored_design = function() {
	set.seed(106)
	n = 10L
	d = DesignFixedBernoulli$new(response_type = "survival", n = n, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	d$assign_w_to_all_subjects()
	ys = rexp(n) + 0.1
	ys[3] = NA
	y_Ls = rep(NA_real_, n); y_Rs = rep(NA_real_, n)
	y_Ls[3] = 1; y_Rs[3] = Inf
	d$add_all_subject_responses(ys, y_Ls, y_Rs)
	d
}

test_that("transform_y works on a survival design with a censored subject", {
	d = ty_censored_design()
	y0 = d$get_y()
	d$transform_y(function(y_original) y_original * 2, "survival")
	expect_equal(d$get_y()[-3], 2 * y0[-3])
	expect_true(is.na(d$get_y()[3]))
})

test_that("transform_y still rejects a transform that gives an invalid value on an observed row", {
	d = ty_censored_design()
	expect_error(d$transform_y(function(y_original) -y_original, "survival"), "Element")
	d = ty_censored_design()
	expect_error(d$transform_y(function(y_original) { y = y_original; y[1] = NA; y }, "survival"), "missing values")
	d = ty_censored_design()
	expect_error(d$transform_y(function(y_original) log(y_original - y_original), "continuous"), "Must be finite")
})
