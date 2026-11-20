# v1.0.6-TODO-276: compute_objective_vals_cpp divided each abs_sum_diff column by its SD with no
# zero-variance guard, so a constant covariate column gave 0/0 = NaN for every draw. A constant
# column reaches the kernel through a design_formula term such as I(x^0) (the default ~ . path drops
# constant columns upstream). With every value NaN, the prop_acceptable path's order() kept the
# first r candidates unfiltered. The kernel now leaves a zero-variance column unscaled, the rule
# rerandomization_search_cpp and DesignFixedRerandomization's R path already use.
# Needs an EDI.so rebuilt with the fix.

library(testthat)
library(EDI)

# The abs_sum_diff rule shared by all paths: SD over all n rows (n - 1 denominator), zero-variance
# columns unscaled.
abs_sum_diff_reference = function(X, indicTs) {
	v = apply(X, 2L, stats::var)
	inv_sd = ifelse(v >= 1e-24, 1 / sqrt(v), 1)
	apply(indicTs, 1L, function(w) {
		sum(abs(colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])) * inv_sd)
	})
}

test_that("a constant column gives finite abs_sum_diff values equal to dropping it", {
	set.seed(11)
	n = 20L
	X = cbind(rnorm(n), 3, runif(n), 0.1)
	indicTs = EDI:::complete_randomization_forced_balanced_cpp(n, 40L, 1L)
	vals = EDI:::compute_objective_vals_cpp(X, indicTs, "abs_sum_diff")
	expect_true(all(is.finite(vals)))
	expect_equal(vals, EDI:::compute_objective_vals_cpp(X[, c(1L, 3L)], indicTs, "abs_sum_diff"), tolerance = 1e-12)
	expect_equal(vals, abs_sum_diff_reference(X, indicTs), tolerance = 1e-12)
	# Unbalanced arms too (the prop_acceptable path at odd n or prob_T != 0.5).
	indicTs_unbal = EDI:::complete_randomization_imbalanced_cpp(n, 7L, 40L, 2L)
	vals_unbal = EDI:::compute_objective_vals_cpp(X, indicTs_unbal, "abs_sum_diff")
	expect_true(all(is.finite(vals_unbal)))
	expect_equal(vals_unbal, abs_sum_diff_reference(X, indicTs_unbal), tolerance = 1e-12)
})

test_that("the search kernel's accepted draws score within the cutoff when a column is constant", {
	set.seed(12)
	n = 24L
	X = cbind(rnorm(n), -2.5, rexp(n))
	cutoff_user = 0.6
	# rerandomization_search_cpp's abs_sum_diff objective is the user-facing value / 2.
	w_mat = EDI:::rerandomization_search_cpp(X_raw = X, r = 20L, objective = "abs_sum_diff",
		cutoff = cutoff_user / 2, max_draws = 100000L)
	expect_equal(ncol(w_mat), 20L)
	vals = EDI:::compute_objective_vals_cpp(X, t(w_mat), "abs_sum_diff")
	expect_true(all(is.finite(vals)))
	expect_true(all(vals <= cutoff_user + 1e-12))
})

test_that("prop_acceptable with a constant design_formula term filters like the formula without it", {
	set.seed(13)
	n = 20L
	Xdf = data.frame(x1 = rnorm(n), x2 = runif(n))
	draw = function(f) {
		des = DesignFixedRerandomization$new(n = n, response_type = "continuous", prop_acceptable = 0.1,
			objective = "abs_sum_diff", seed = 5L, design_formula = f)
		des$add_all_subjects_to_experiment(Xdf)
		des$draw_ws_according_to_design(10)
	}
	ws_const = draw(~ x1 + x2 + I(x2^0))
	ws_plain = draw(~ x1 + x2)
	expect_identical(ws_const, ws_plain)
	X = as.matrix(Xdf)
	scores = abs_sum_diff_reference(X, t(ws_const))
	# Kept draws are the best 10 of 100; unfiltered draws would score like a random allocation.
	all_draws = EDI:::complete_randomization_forced_balanced_cpp(n, 100L, 5L)
	expect_true(max(scores) <= sort(abs_sum_diff_reference(X, all_draws))[10] + 1e-12)
})
