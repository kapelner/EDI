library(testthat)
library(EDI)

test_that("base bootstrap resamples survival fields together and reuses the inference copy", {
	X <- cbind(x = c(3, 6, 9, 12))
	y <- c(5, 10, 20, 40)
	dead <- c(0, 1, 1, 0)
	w <- c(1, 0, 1, 0)
	indices <- matrix(c(4L, 1L, 4L, 2L, 2L, 3L, 1L, 3L), nrow = 2, byrow = TRUE)
	copies <- 0L
	iteration <- 0L
	observed <- EDI:::base_bootstrap_loop_cpp(X, y, dead, w, indices,
		function() { copies <<- copies + 1L; e <- new.env(); e$calls <- 0L; e },
		function(data) {
			iteration <<- iteration + 1L
			i <- indices[iteration, ]
			expect_equal(data$y, y[i])
			expect_equal(data$dead, dead[i])
			expect_equal(data$w, w[i])
			expect_equal(data$X, X[i, , drop = FALSE])
			data$inf_obj$calls <- data$inf_obj$calls + 1L
			expect_equal(data$inf_obj$calls, iteration)
			sum(data$y * data$dead * data$w)
		}, 2L)
	expect_equal(observed, c(0, 40))
	expect_identical(copies, 1L)
})

test_that("base bootstrap survives unavailable inference copies and empty callback results", {
	X <- matrix(1:3, ncol = 1)
	indices <- matrix(rep(1:3, 4), nrow = 4, byrow = TRUE)
	storage.mode(indices) <- "integer"
	for (duplicate in list(function() NULL, function() list())) {
		iteration <- 0L
		observed <- EDI:::base_bootstrap_loop_cpp(X, c(1, 2, 4), c(1, 0, 1), c(1, 0, 1), indices,
			duplicate, function(data) {
				expect_false("inf_obj" %in% names(data))
				iteration <<- iteration + 1L
				if (iteration == 1L) return(NA_real_)
				if (iteration == 2L) return(numeric())
				if (iteration == 3L) return(c(sum(data$y), 100))
				mean(data$y)
			}, 1L)
		expect_equal(observed, c(NA, NA, 7, 7 / 3))
		expect_identical(iteration, 4L)
	}
})

test_that("matching bootstrap returns exact paired and reservoir sample summaries", {
	X <- cbind(x = 1:8, constant = rep(2, 8))
	y <- c(10, 4, 20, 8, 30, 12, 40, 16)
	w <- c(1, 0, 0, 1, 1, 0, 0, 1)
	m <- c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L)
	indices <- rbind(1:8, c(3L, 4L, 1L, 2L, 8L, 8L, 5L, 6L))
	storage.mode(indices) <- "integer"
	iteration <- 0L
	copies <- 0L
	observed <- EDI:::matching_bootstrap_loop_cpp(X, y, w, m, indices, 2L,
		function() { copies <<- copies + 1L; new.env() },
		function(data) {
			iteration <<- iteration + 1L
			expect_equal(data$y_matched_diffs, c(6, -12))
			expect_equal(data$X_matched_diffs_full, rbind(c(-1, 0), c(1, 0)))
			expect_equal(data$X_matched_diffs, matrix(c(-1, 1), ncol = 1))
			r <- indices[iteration, 5:8]
			expect_equal(data$y_reservoir, y[r])
			expect_equal(data$X_reservoir, unname(X[r, , drop = FALSE]))
			expect_equal(data$w_reservoir, as.integer(w[r]))
			mean(data$y_matched_diffs) + mean(y[r][w[r] == 1]) - mean(y[r][w[r] == 0])
		}, 2L)
	expect_equal(observed, c(-6, 17 / 3))
	expect_identical(copies, 1L)
	expect_true(is.na(EDI:::matching_bootstrap_loop_cpp(X, y, w, m, indices[1, , drop = FALSE], 2L, function() new.env(), function(data) numeric(), 1L)))
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
