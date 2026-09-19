library(testthat)
library(EDI)

# The exchangeable-resampling mixin's private compute_resampling_draw_distribution()
# (plain, debug and cached paths), the centered-pivot cache accessors, and
# resampling_effective_p(). They were only reached through the public
# m-out-of-n / subsampling wrappers with smoke-level assertions. Values are
# checked against a from-scratch mean-difference computed on each draw's rows.

resampling_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.05)
	for (t in seq_len(n)) des$add_one_subject_response(t, y[t])
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	priv <- inf$.__enclos_env__$private
	set.seed(1)
	draws <- priv$generate_exchangeable_resampling_draws(
		priv$get_exchangeable_units("auto"), B = 6, size = 8, replace = TRUE, size_label = "m"
	)
	list(inf = inf, priv = priv, draws = draws, w = w, y = y)
}

ref_draw_stat <- function(f, draw) {
	i <- draw$i_b
	v <- mean(f$y[i][f$w[i] == 1]) - mean(f$y[i][f$w[i] == 0])
	if (is.finite(v)) v else NA_real_
}

test_that("plain path returns each draw's mean difference (non-finite -> NA) and handles empty draws", {
	f <- resampling_fixture()
	vals <- f$priv$compute_resampling_draw_distribution(f$draws, "m_out_of_n_boot", show_progress = FALSE)
	expect_equal(vals, vapply(f$draws, function(d) ref_draw_stat(f, d), numeric(1)), tolerance = 1e-10)
	expect_identical(
		f$priv$compute_resampling_draw_distribution(list(), "m_out_of_n_boot", show_progress = FALSE),
		numeric(0)
	)
})

test_that("cache_key stores and reuses the distribution; debug = TRUE bypasses the read but still stores", {
	f <- resampling_fixture()
	first <- f$priv$compute_resampling_draw_distribution(f$draws, "m_out_of_n_boot", show_progress = FALSE, cache_key = "k1")
	# Same key with different draws returns the cached values (no recompute).
	again <- f$priv$compute_resampling_draw_distribution(f$draws[1:2], "m_out_of_n_boot", show_progress = FALSE, cache_key = "k1")
	expect_identical(again, first)
	# A different key recomputes.
	other <- f$priv$compute_resampling_draw_distribution(f$draws[1:2], "m_out_of_n_boot", show_progress = FALSE, cache_key = "k2")
	expect_length(other, 2L)
	# debug = TRUE ignores the cached entry and returns the diagnostic list.
	dbg <- f$priv$compute_resampling_draw_distribution(f$draws[1:2], "m_out_of_n_boot", show_progress = FALSE, debug = TRUE, cache_key = "k1")
	expect_true(is.list(dbg))
	expect_length(dbg$values, 2L)
	expect_equal(dbg$values, other, tolerance = 1e-10)
})

test_that("debug path records per-draw errors, warnings and illegal values", {
	f <- resampling_fixture()
	calls <- 0L
	real_subset <- f$priv$bootstrap_subset_inference
	unlockBinding("bootstrap_subset_inference", f$priv)
	f$priv$bootstrap_subset_inference <- function(draw, smooth = FALSE) {
		calls <<- calls + 1L
		if (calls == 2L) stop("boom in draw 2")
		if (calls == 3L) warning("careful in draw 3")
		real_subset(draw, smooth = smooth)
	}
	dbg <- f$priv$compute_resampling_draw_distribution(f$draws[1:4], "m_out_of_n_boot", show_progress = FALSE, debug = TRUE)
	expect_equal(dbg$num_errors, c(0L, 1L, 0L, 0L))
	expect_equal(dbg$num_warnings, c(0L, 0L, 1L, 0L))
	expect_match(dbg$errors[[2]], "boom in draw 2")
	expect_match(dbg$warnings[[3]], "careful in draw 3")
	expect_true(is.na(dbg$values[2]))
	expect_equal(dbg$prop_iterations_with_errors, 0.25)
	expect_equal(dbg$prop_iterations_with_warnings, 0.25)
	expect_equal(dbg$prop_illegal_values, mean(!is.finite(dbg$values)))
	expect_equal(dbg$finite_fraction, mean(is.finite(dbg$values)))
})

test_that("centered-pivot cache accessors round-trip per operation and key", {
	f <- resampling_fixture()
	expect_null(f$priv$get_cached_centered_resampling_pivot("subsample", "a"))
	f$priv$set_cached_centered_resampling_pivot("subsample", "a", c(1, 2, 3))
	f$priv$set_cached_centered_resampling_pivot("subsample", "b", 9)
	f$priv$set_cached_centered_resampling_pivot("m_out_of_n_boot", "a", "other-op")
	expect_equal(f$priv$get_cached_centered_resampling_pivot("subsample", "a"), c(1, 2, 3))
	expect_equal(f$priv$get_cached_centered_resampling_pivot("subsample", "b"), 9)
	expect_equal(f$priv$get_cached_centered_resampling_pivot("m_out_of_n_boot", "a"), "other-op")
	expect_null(f$priv$get_cached_centered_resampling_pivot("subsample", "missing"))
	expect_identical(f$priv$set_cached_centered_resampling_pivot("subsample", "c", 1), 1)
})

test_that("resampling_effective_p follows the design matrix width and falls back to 1", {
	f <- resampling_fixture()
	expect_equal(f$priv$resampling_effective_p(), max(1L, NCOL(f$priv$get_X())))

	unlockBinding("get_X", f$priv)
	f$priv$get_X <- function() matrix(0, nrow = 20, ncol = 4)
	expect_equal(f$priv$resampling_effective_p(), 4L)
	f$priv$get_X <- function() NULL
	f$priv$X <- NULL
	expect_equal(f$priv$resampling_effective_p(), 1L)
	f$priv$get_X <- function() stop("no X")
	expect_equal(f$priv$resampling_effective_p(), 1L)
	f$priv$get_X <- function() matrix(0, nrow = 20, ncol = 0)
	expect_equal(f$priv$resampling_effective_p(), 1L)
})
