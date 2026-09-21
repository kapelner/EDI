library(testthat)
library(EDI)

# DesignSeqOneByOneKK21 get_covariate_weights() / get_iteration_weights(): before enough responses accrue the weights
# are NULL (KK14 fallback regime); afterwards every assignment stores a normalised (sum 1, non-negative, covariate-
# named) weight vector at list position t, the last of which is the current covariate weight vector. The burn-in is
# at least 2 * (p + 2) collected responses. Reference: invariants stated from the class documentation.

run <- function(p, n = 60L, seed = 3L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
	first_seen <- NA_integer_
	for (i in seq_len(n)) {
		x <- as.data.frame(matrix(rnorm(p), 1, dimnames = list(NULL, paste0("x", seq_len(p)))))
		w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 1.5 * x$x1 + w + rnorm(1))
		if (is.na(first_seen) && !is.null(des$get_covariate_weights())) first_seen <- i
	}
	list(des = des, first_seen = first_seen, p = p, n = n)
}

test_that("weights are NULL and the history empty before any assignment", {
	des <- DesignSeqOneByOneKK21$new(n = 20L, response_type = "continuous", verbose = FALSE)
	expect_null(des$get_covariate_weights()); expect_identical(des$get_iteration_weights(), list())
})

test_that("burn-in: no weights until at least 2 * (p + 2) responses are collected, for several p", {
	for (p in c(1L, 2L, 4L)) {
		r <- run(p)
		expect_false(is.na(r$first_seen), info = p)
		expect_gt(r$first_seen, 2L * (p + 2L))            # the current subject's response is still missing when it is assigned
	}
})

test_that("stored history: NULL padding before the burn-in, then one normalised named vector per assignment call", {
	r <- run(3L); it <- r$des$get_iteration_weights()
	expect_length(it, r$n)
	filled <- which(!vapply(it, is.null, NA))
	expect_identical(min(filled), r$first_seen)
	expect_identical(filled, seq(min(filled), r$n))                       # contiguous from first weighting to the last subject
	for (v in it[filled]) {
		expect_identical(names(v), c("x1", "x2", "x3"))
		expect_equal(sum(v), 1, tolerance = 1e-10)
		expect_true(all(v >= 0))
	}
	expect_true(all(vapply(it[seq_len(min(filled) - 1L)], is.null, NA)))
})

test_that("the current weight vector equals the last history entry and the weights evolve as data accrue", {
	r <- run(3L); it <- r$des$get_iteration_weights()
	expect_identical(r$des$get_covariate_weights(), it[[r$n]])
	distinct <- unique(lapply(it[!vapply(it, is.null, NA)], function(v) round(v, 8)))
	expect_gt(length(distinct), 1L)
})

test_that("the outcome-relevant covariate gets the largest weight when the response depends mostly on it", {
	r <- run(3L, n = 80L)
	w <- r$des$get_covariate_weights()
	expect_identical(names(which.max(w)), "x1")
})

test_that("the history getter returns the stored list (a modified copy does not alter the design)", {
	r <- run(2L, n = 40L); it <- r$des$get_iteration_weights(); before <- r$des$get_iteration_weights()
	it[[length(it)]] <- NULL
	expect_identical(r$des$get_iteration_weights(), before)
})
