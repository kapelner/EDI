library(testthat)
library(EDI)

# v1.0.6-TODO-70 (GitHub issue #28): DesignFixedRerandomization's abs_sum_diff objective.
# Both C++ kernels (rerandomization_search_cpp on the balanced fast path and
# compute_objective_vals_cpp on the prop_acceptable path) divide each covariate's mean
# difference by its SD, as DesignFixedGreedy's abs_sum_diff does. The pure-R path (odd n or
# prob_T != 0.5 with obj_val_cutoff) and the private compute_obj() used raw differences, so
# the same cutoff accepted different allocations depending on the path. Every path now uses
#   M(w) = sum_j |mean_T,j - mean_C,j| / sd_j.
# Also: an objective other than "mahal_dist"/"abs_sum_diff" used to reach the fast path's
# C++ search unchecked (silently filtering on abs_sum_diff); it now errors in the constructor.

std_abs = function(X, w) {
	sum(abs(colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])) / apply(X, 2, sd))
}

# Covariates with SDs far from 1, so the standardized and raw criteria disagree.
wide_X = function(n) {
	set.seed(17)
	data.frame(x1 = rnorm(n, sd = 5), x2 = rnorm(n, sd = 0.2), x3 = rexp(n, rate = 0.1))
}

abs_design = function(n, prob_T, cutoff, X = wide_X(n), seed = 3L) {
	des = DesignFixedRerandomization$new(response_type = "continuous", n = n, prob_T = prob_T,
		obj_val_cutoff = cutoff, objective = "abs_sum_diff", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des
}

test_that("every obj_val_cutoff path filters abs_sum_diff on standardized mean differences", {
	cutoff = 0.4
	# balanced even n (C++ fast path), odd n and unequal prob_T (pure-R path)
	for (cfg in list(c(20, 0.5), c(21, 0.5), c(20, 0.3))) {
		n = cfg[1]
		des = abs_design(n, cfg[2], cutoff)
		W = des$draw_ws_according_to_design(r = 150)
		Xm = as.matrix(wide_X(n))
		objs = apply(W, 2, function(w) std_abs(Xm, w))
		expect_true(all(objs <= cutoff + 1e-9), info = paste("n", n, "prob_T", cfg[2]))
		# a cutoff this tight is binding: the accepted draws are not just any draws
		expect_gt(mean(objs), 0.05)
	}
})

test_that("the fast path's C++ search and the R objective accept the same allocations", {
	n = 20L; K = 3000L; cutoff = 0.5
	Xm = as.matrix(wide_X(n))
	# With cutoff = Inf the search returns its first K candidates in draw order; under the
	# same RNG state and a finite cutoff it must return exactly those that pass M(w) <= a.
	set.seed(99); stream = EDI:::rerandomization_search_cpp(Xm, K, "abs_sum_diff", Inf, K)
	set.seed(99); kept = EDI:::rerandomization_search_cpp(Xm, K, "abs_sum_diff", cutoff / 2, K)
	objs = apply(stream, 2, function(w) std_abs(Xm, w))
	expect_gt(ncol(kept), 50L)
	expect_lt(ncol(kept), K)
	expect_identical(unname(kept), unname(stream[, objs <= cutoff, drop = FALSE]))
	# and the class's own (pure-R) objective is the same function
	priv = abs_design(n, 0.5, cutoff)$.__enclos_env__$private
	expect_equal(apply(stream[, 1:200], 2, function(w) priv$compute_obj(Xm, w)), objs[1:200], tolerance = 1e-12)
})

test_that("abs_sum_diff draws are scale-invariant on the pure-R and prop_acceptable paths", {
	X = wide_X(21)
	# moderate factors: the design's model-matrix step drops near-collinear columns on a
	# scale-dependent rule, which is not what this test is about
	X_rescaled = transform(X, x1 = x1 * 7, x2 = x2 / 3)
	expect_identical(ncol(abs_design(21, 0.5, 0.5, X = X_rescaled)$get_X()), 3L)
	expect_identical(
		abs_design(21, 0.5, 0.5, X = X)$draw_ws_according_to_design(r = 30),
		abs_design(21, 0.5, 0.5, X = X_rescaled)$draw_ws_according_to_design(r = 30)
	)
	prop = function(X) {
		des = DesignFixedRerandomization$new(response_type = "continuous", n = 21, prob_T = 0.3,
			prop_acceptable = 0.1, objective = "abs_sum_diff", seed = 5L, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$draw_ws_according_to_design(r = 10)
	}
	expect_identical(prop(X), prop(X_rescaled))
})

test_that("an unsupported objective errors in the constructor, before any C++ search", {
	for (bad in list("bogus", "D", c("mahal_dist", "abs_sum_diff"), NA_character_, 1)) {
		expect_error(
			DesignFixedRerandomization$new(response_type = "continuous", n = 20, obj_val_cutoff = 1, objective = bad),
			'objective must be "mahal_dist" or "abs_sum_diff"'
		)
	}
	# A design whose objective was changed after construction still errors at draw time on
	# the balanced fast path (it used to filter silently on abs_sum_diff there).
	des = abs_design(20, 0.5, 1)
	des$.__enclos_env__$private$objective = "bogus"
	expect_error(des$draw_ws_according_to_design(r = 2), 'objective must be "mahal_dist" or "abs_sum_diff"')
	expect_no_error(abs_design(20, 0.5, 1)$draw_ws_according_to_design(r = 2))
})
