library(testthat)
library(EDI)

# base_bootstrap_loop_cpp and matching_bootstrap_loop_cpp were deleted
# 2026-10-22 (TODO-3) as unused legacy callback loops. The matching loop's
# per-replicate payload came straight from match_stats_from_indices_cpp, so its
# exact paired/reservoir assertions are kept here against that live kernel.
test_that("match statistics from resampled indices return exact paired and reservoir summaries", {
	X <- cbind(x = 1:8, constant = rep(2, 8))
	y <- c(10, 4, 20, 8, 30, 12, 40, 16)
	w <- c(1, 0, 0, 1, 1, 0, 0, 1)
	m <- c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L)
	indices <- rbind(1:8, c(3L, 4L, 1L, 2L, 8L, 8L, 5L, 6L))
	storage.mode(indices) <- "integer"
	observed <- vapply(seq_len(nrow(indices)), function(b) {
		data <- EDI:::match_stats_from_indices_cpp(X, y, w, m, indices[b, ], 2L)
		expect_equal(data$y_matched_diffs, c(6, -12))
		expect_equal(data$X_matched_diffs_full, rbind(c(-1, 0), c(1, 0)))
		expect_equal(data$X_matched_diffs, matrix(c(-1, 1), ncol = 1))
		r <- indices[b, 5:8]
		expect_equal(data$y_reservoir, y[r])
		expect_equal(data$X_reservoir, unname(X[r, , drop = FALSE]))
		expect_equal(data$w_reservoir, as.integer(w[r]))
		mean(data$y_matched_diffs) + mean(y[r][w[r] == 1]) - mean(y[r][w[r] == 0])
	}, numeric(1))
	expect_equal(observed, c(-6, 17 / 3))
})

test_that("randomization callback maintains both copied objects across iterations", {
	observed <- EDI:::randomization_loop_cpp(4L,
		function() { e <- new.env(); e$allocation <- 0L; e },
		function() { e <- new.env(); e$previous <- 0L; e },
		function(objects) {
			objects$design$allocation <- objects$design$allocation + 1L
			objects$inference$previous <- objects$inference$previous + objects$design$allocation
			c(objects$inference$previous, -99)
		}, 2L)
	expect_equal(observed, c(1, 3, 6, 10))
})
