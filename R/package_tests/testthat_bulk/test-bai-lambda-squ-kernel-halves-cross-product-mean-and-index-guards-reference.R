library(testthat)
library(EDI)

# compute_lambda_squ_cpp(d_i, halves): mean over half-pairs (id1, id2) of d_i[id1] * d_i[id2]
# (Bai's lambda^2 cross-product term). Out-of-range / non-positive ids are dropped from the sum but still
# counted in the divisor (pinned below); an empty halves matrix gives 0.

L <- get("compute_lambda_squ_cpp", envir = asNamespace("EDI"))

test_that("equals the mean of d[id1] * d[id2] over the half-pairs, matching a vectorised R reference", {
	set.seed(1)
	for (i in 1:25) {
		m <- sample(3:30, 1); d <- rnorm(m)
		h <- cbind(sample(m, 12, TRUE), sample(m, 12, TRUE))
		storage.mode(h) <- "integer"
		expect_equal(L(d, h), mean(d[h[, 1]] * d[h[, 2]]), tolerance = 1e-12)
	}
})

test_that("hand-computed case and symmetry in the two columns", {
	d <- c(2, -1, 3)
	h <- matrix(c(1L, 2L, 2L, 3L), ncol = 2, byrow = TRUE)   # (1,2),(2,3)
	expect_equal(L(d, h), (2 * -1 + -1 * 3) / 2)
	expect_equal(L(d, h[, 2:1]), L(d, h))
})

test_that("a pair of identical ids gives the mean of squares; constant d gives d^2", {
	d <- c(1, 2, 3); h <- cbind(1:3, 1:3); storage.mode(h) <- "integer"
	expect_equal(L(d, h), mean(d^2))
	expect_equal(L(rep(4, 5), cbind(1:4, 2:5) |> `storage.mode<-`("integer")), 16)
})

test_that("empty halves returns exactly 0", {
	expect_identical(L(c(1, 2), matrix(integer(0), ncol = 2)), 0)
})

test_that("invalid ids (zero, negative, beyond length) add nothing to the sum but stay in the divisor", {
	d <- c(2, 3)
	h <- matrix(c(1L, 2L,  0L, 1L,  3L, 1L,  -1L, 2L), ncol = 2, byrow = TRUE)
	expect_equal(L(d, h), (2 * 3) / 4)
})

test_that("NA in d_i propagates to NA (no silent dropping)", {
	expect_true(is.na(L(c(1, NA, 3), matrix(c(1L, 2L), ncol = 2))))
})
