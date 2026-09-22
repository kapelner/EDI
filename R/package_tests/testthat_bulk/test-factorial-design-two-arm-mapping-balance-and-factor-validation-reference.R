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
	d2 <- mk(10L, list(dose = 1, arm = 2))                                  # two factors, one with a single level: still exactly two combinations
	g2 <- d2$get_w_factorial()
	expect_named(g2, c("dose", "arm")); expect_true(all(g2$dose == 1L)); expect_equal(as.integer(g2$arm), as.integer(d2$get_w()) + 1L)
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
