library(testthat)
library(EDI)

# DesignFixedFactorial (currently exactly two factor-level combinations): get_w_factorial() maps the {0,1} assignment onto the expand.grid combination table
# (row w + 1), returns NULL before assignment; draw_ws_raw() gives balanced two-arm allocations (n/2 each, floor/ceil for odd n) that differ across
# columns and are reproducible under the design seed; factors validation (numeric list; exactly two total combinations).

mk <- function(n = 20L, factors = list(A = 2), seed = 1L, assign = TRUE) {
	d <- DesignFixedFactorial$new(factors = factors, response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	if (assign) d$assign_w_to_all_subjects()
	d
}

test_that("get_w_factorial() is NULL before assignment and afterwards the combination row of w + 1, one row per subject", {
	expect_null(mk(assign = FALSE)$get_w_factorial())
	d <- mk(20L, list(A = 2))
	gf <- d$get_w_factorial(); w <- d$get_w()
	expect_equal(nrow(gf), 20L); expect_named(gf, "A")
	expect_equal(as.integer(gf$A), as.integer(w) + 1L)
	expect_equal(sort(unique(as.integer(gf$A))), 1:2)
	# a single-level factor (list(dose = 1, arm = 2)) used to be accepted as a constant column; since
	# v1.0.6-TODO-190 every factor needs >= 2 levels
	expect_error(mk(10L, list(dose = 1, arm = 2)), "factors\\$dose must be a whole number of levels >= 2")
})

test_that("draw_ws_raw: every column is a balanced permutation of {0, 1} (n / 2 each; floor / ceiling for odd n), columns differ, dimensions r x n", {
	p <- mk(20L)$.__enclos_env__$private
	W <- p$draw_ws_raw(r = 50L)
	expect_equal(dim(W), c(20L, 50L)); expect_true(all(W %in% 0:1))
	expect_true(all(colSums(W) == 10L))
	expect_gt(length(unique(apply(W, 2, paste, collapse = ""))), 40L)
	Wo <- mk(21L)$.__enclos_env__$private$draw_ws_raw(r = 30L)
	expect_true(all(colSums(Wo) %in% c(10L, 11L)))
	expect_equal(mean(W), 0.5)
})

test_that("assignment is reproducible under the design seed and differs across seeds", {
	w1 <- mk(30L, seed = 5L)$get_w(); w2 <- mk(30L, seed = 5L)$get_w(); w3 <- mk(30L, seed = 6L)$get_w()
	expect_identical(w1, w2); expect_false(identical(w1, w3))
	expect_equal(sum(w1), 15L)
})

test_that("factors validation: must be a non-empty numeric list with exactly two total combinations", {
	mkd <- function(f) DesignFixedFactorial$new(factors = f, response_type = "continuous", n = 10L, verbose = FALSE)
	expect_error(mkd(list(A = 3)), "exactly two total factor-level")
	expect_error(mkd(list(A = 2, B = 2)), "implies 4 combinations")
	expect_error(mkd(list()))
	expect_error(mkd(list(A = "x")))
	expect_error(mkd(2))
})

# v1.0.6-TODO-190 (docs-scenarios factorial F4): list(subject = 2.5) ran as a two-level factor and an
# unnamed list(2) got the column name Var1.
test_that("factors must be whole numbers of levels >= 2 in a fully named list", {
	mkd <- function(f) DesignFixedFactorial$new(factors = f, response_type = "continuous", n = 10L, verbose = FALSE)
	for (bad in list(2.5, 1, 0, NA_real_, -2, Inf)) {
		expect_error(mkd(list(subject = bad)), "factors\\$subject must be a whole number of levels >= 2", info = format(bad))
	}
	expect_error(mkd(list(2)), "fully named list")
	expect_error(mkd(setNames(list(2), "")), "fully named list")
	d <- mkd(list(subject_line = 2))
	X <- data.frame(x = rnorm(10))
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	expect_identical(names(d$get_w_factorial()), "subject_line")
})
