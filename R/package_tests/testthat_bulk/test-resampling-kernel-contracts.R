library(testthat)
library(EDI)

test_that("match-index fill helper selects both members of sampled pairs", {
	i_b = integer(6)
	result = EDI:::fill_i_b_with_matches_loop_cpp(
		i_b,
		as.integer(c(1, 1, 2, 2, 0, 0)),
		as.integer(c(2, 1)),
		0L
	)

	expect_null(result)
	expect_identical(i_b, as.integer(c(3, 4, 1, 2, 0, 0)))
})

test_that("matching linear-data kernels separate pairs and reservoir", {
	X = cbind(x1 = 1:6, x2 = c(2, 4, 6, 8, 10, 12))
	y = c(10, 4, 20, 8, 30, 12)
	w = as.integer(c(1, 0, 0, 1, 1, 0))
	m_vec = as.integer(c(1, 1, 2, 2, 0, NA))

	full = EDI:::compute_matching_lin_match_data_cpp(X, y, w, m_vec)
	expect_equal(full$yTs_matched, c(10, 8))
	expect_equal(full$yCs_matched, c(4, 20))
	expect_equal(full$y_matched_diffs, c(6, -12))
	expect_equal(full$X_matched_diffs_full, rbind(c(-1, -2), c(1, 2)))
	expect_equal(full$X_matched_means_full, rbind(c(1.5, 3), c(3.5, 7)))
	expect_equal(full$X_reservoir, X[5:6, , drop = FALSE], check.attributes = FALSE)
	expect_equal(full$y_reservoir, c(30, 12))
	expect_identical(full$w_reservoir, as.integer(c(1, 0)))
	expect_identical(c(full$nRT, full$nRC, full$m), c(1L, 1L, 2L))

	wy = EDI:::compute_matching_lin_wy_stats_cpp(w, y, m_vec)
	expect_equal(wy$yTs_matched, full$yTs_matched)
	expect_equal(wy$yCs_matched, full$yCs_matched)
	expect_equal(wy$y_matched_diffs, full$y_matched_diffs)
	expect_equal(wy$y_reservoir, full$y_reservoir)
	expect_identical(wy$w_reservoir, full$w_reservoir)
})

test_that("reservoir statistics cover estimable and undersized samples", {
	stats = EDI:::compute_matching_reservoir_stats_cpp(
		c(2, 4, 6),
		c(10, 14, 3, 7),
		c(1, 1, 0, 0)
	)
	expect_equal(stats$d_bar, 4)
	expect_equal(stats$ssqD_bar, var(c(2, 4, 6)) / 3)
	expect_equal(stats$r_bar, 7)
	expect_equal(stats$ssqR, 8)
	expect_equal(stats$w_star, 8 / (8 + var(c(2, 4, 6)) / 3))
	expect_identical(c(stats$nRT, stats$nRC), c(2L, 2L))

	small = EDI:::compute_matching_reservoir_stats_cpp(numeric(), 5, 1)
	expect_true(all(is.na(unlist(small[c("d_bar", "ssqD_bar", "r_bar", "ssqR", "w_star")]))))
	expect_identical(c(small$nRT, small$nRC), c(1L, 0L))
})

test_that("combined KK OLS builder has the documented row scaling and layout", {
	yd = c(2, -4)
	Xd = matrix(c(1, 3, 2, 4), nrow = 2)
	yr = c(7, 9)
	wr = as.integer(c(0, 1))
	Xr = matrix(c(5, 7, 6, 8), nrow = 2)
	result = EDI:::build_matching_combined_ols_design_cpp(yd, Xd, yr, wr, Xr)
	s = sqrt(2)

	expect_equal(result$X_comb, rbind(
		c(0, 1 / s, Xd[1, ] / s),
		c(0, 1 / s, Xd[2, ] / s),
		c(1, 0, Xr[1, ]),
		c(1, 1, Xr[2, ])
	))
	expect_equal(as.numeric(result$y_comb), c(yd / s, yr))
})

test_that("base bootstrap loop resamples all fields and handles callback results", {
	X = cbind(a = 1:3, b = 4:6)
	indices = matrix(as.integer(c(1, 2, 3, 3, 3, 1, 2, 1, 2)), nrow = 3, byrow = TRUE)
	dup = function() new.env(parent = emptyenv())
	estimate = function(d) {
		expect_named(d, c("y", "dead", "X", "w", "inf_obj"))
		expect_identical(colnames(d$X), colnames(X))
		c(mean(d$y), 999)
	}
	observed = EDI:::base_bootstrap_loop_cpp(
		X, c(2, 4, 8), c(0, 1, 0), c(1, 0, 1), indices, dup, estimate, 2L
	)
	expect_equal(observed, c(mean(c(2, 4, 8)), mean(c(8, 8, 2)), mean(c(4, 2, 4))))

	empty_result = EDI:::base_bootstrap_loop_cpp(
		X, 1:3, rep(0, 3), c(1, 0, 1), indices[1, , drop = FALSE],
		function() NULL, function(d) numeric(), 1L
	)
	expect_true(is.na(empty_result))
})

test_that("matching bootstrap loop passes match statistics and handles invalid objects", {
	X = cbind(x = 1:6)
	y = c(10, 4, 20, 8, 30, 12)
	w = c(1, 0, 0, 1, 1, 0)
	m_vec = as.integer(c(1, 1, 2, 2, 0, 0))
	indices = matrix(as.integer(c(1, 2, 3, 4, 5, 6, 3, 4, 1, 2, 6, 5)), nrow = 2, byrow = TRUE)

	observed = EDI:::matching_bootstrap_loop_cpp(
		X, y, w, m_vec, indices, 2L,
		function() new.env(parent = emptyenv()),
		function(stats) {
			expect_true(stats$thread_safe_inf_obj_valid)
			expect_true(is.environment(stats$inf_obj))
			c(mean(stats$y_matched_diffs), 123)
		},
		2L
	)
	expect_length(observed, 2)
	expect_true(all(is.finite(observed)))

	invalid = EDI:::matching_bootstrap_loop_cpp(
		X, y, w, m_vec, indices, 2L, function() NULL, function(stats) 1, 1L
	)
	expect_true(all(is.na(invalid)))
})

test_that("randomization loop reuses duplicated objects and returns first estimate", {
	design_calls = 0L
	inference_calls = 0L
	iteration = 0L
	observed = EDI:::randomization_loop_cpp(
		4L,
		function() { design_calls <<- design_calls + 1L; new.env() },
		function() { inference_calls <<- inference_calls + 1L; new.env() },
		function(objects) {
			iteration <<- iteration + 1L
			expect_named(objects, c("design", "inference"))
			c(iteration, -1)
		},
		2L
	)
	expect_equal(observed, 1:4)
	expect_identical(design_calls, 1L)
	expect_identical(inference_calls, 1L)
})

test_that("bisection kernels call the requested interfaces and return bounded values", {
	pval3 = function(r, delta, transform_responses) {
		expect_identical(r, 7L)
		expect_identical(transform_responses, "none")
		delta
	}
	expect_equal(EDI:::bisection_ci_loop_cpp(pval3, 7L, 0, 1, 0.5, 0.01, "none", TRUE), 0.5, tolerance = 0.02)
	pval3_upper = function(r, delta, transform_responses) pval3(r, 1 - delta, transform_responses)
	expect_equal(EDI:::bisection_ci_loop_cpp(pval3_upper, 7L, 0, 1, 0.5, 0.01, "none", FALSE), 0.5, tolerance = 0.02)

	pval4 = function(r, delta, transform_responses, num_cores) {
		expect_identical(c(r, num_cores), c(9L, 3L))
		expect_identical(transform_responses, "log")
		1 - abs(delta)
	}
	parallel = EDI:::bisection_ci_parallel_cpp(pval4, 9L, -1, 0, 0, 1, 0.5, 0.01, "log", 3L)
	expect_equal(parallel, c(-0.5, 0.5), tolerance = 0.02)
	expect_equal(EDI:::bisection_ci_single_bound_cpp(pval4, 9L, -1, 0, 0.5, 0.01, "log", TRUE, 3L), -0.5, tolerance = 0.02)

	nonfinite_endpoint = function(r, delta, transform_responses, num_cores) NA_real_
	expect_equal(EDI:::bisection_ci_single_bound_cpp(nonfinite_endpoint, 1L, 0, 1, 0.5, 0.01, "none", TRUE, 1L), 0)
	expect_equal(EDI:::bisection_ci_single_bound_cpp(nonfinite_endpoint, 1L, 0, 1, 0.5, 0.01, "none", FALSE, 1L), 1)
})
