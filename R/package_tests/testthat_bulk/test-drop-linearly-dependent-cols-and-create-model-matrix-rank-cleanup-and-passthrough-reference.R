library(testthat)
library(EDI)

# drop_linearly_dependent_cols(M) (rank cleanup with tol 1e-7, later dependent columns dropped, `js` = kept original
# indices, non-numeric / non-finite / empty input passed through) and create_model_matrix_from_features(formula, data)
# (model.matrix without the intercept, then the same rank cleanup). References: base R qr / model.matrix.

Z <- function(x) get(x, envir = asNamespace("EDI"))
D <- Z("drop_linearly_dependent_cols")
set.seed(1); n <- 30L; a <- rnorm(n); b <- rnorm(n); cc <- rnorm(n)

test_that("a full-rank matrix is returned unchanged with js = 1..p", {
	M <- cbind(a, b, cc); r <- D(M)
	expect_identical(r$js, 1:3); expect_equal(r$M, M)
})

test_that("later linearly dependent columns are dropped and js maps to the input positions", {
	M <- cbind(a = a, ab = a + b, b = b, c = cc)
	r <- D(M)
	expect_identical(r$js, c(1L, 2L, 4L))
	expect_identical(colnames(r$M), c("a", "ab", "c"))
	expect_equal(qr(r$M)$rank, 3L)
	M2 <- cbind(a = a, b = b, dup = a, c = cc)
	expect_identical(D(M2)$js, c(1L, 2L, 4L))
	expect_identical(colnames(D(M2)$M), c("a", "b", "c"))
})

test_that("kept columns span the same space as the input (rank preserved) on random rank-deficient designs", {
	for (s in 1:20) {
		set.seed(50 + s); p0 <- sample(2:4, 1); base <- matrix(rnorm(n * p0), n)
		comb <- base %*% matrix(rnorm(p0 * 3), p0)
		M <- cbind(base, comb)                            # p0 independent + 3 dependent columns
		r <- D(M)
		expect_equal(ncol(r$M), p0, info = s)
		expect_equal(qr(M)$rank, qr(r$M)$rank, info = s)
		expect_equal(unname(r$M), unname(M[, r$js, drop = FALSE]), info = s)
		expect_identical(r$js, sort(r$js), info = s)
		expect_lt(max(abs(qr.resid(qr(r$M), M))), 1e-8)   # every dropped column lies in the span of the kept ones
	}
})

test_that("a zero column or a numerically negligible column counts as dependent", {
	expect_identical(D(cbind(z = 0, a = a))$js, 2L)
	expect_identical(D(cbind(x = 1:5, x2 = (1:5) * 2, tiny = 1e-9 * c(1, -1, 2, -2, 3)))$js, 1L)
})

test_that("non-numeric, non-finite, and empty inputs pass through untouched", {
	expect_identical(D(cbind(a = letters[1:3]))$js, 1L)
	na <- cbind(a = c(1, NA, 3), b = c(1, 2, 3)); expect_identical(D(na)$js, 1:2); expect_identical(D(na)$M, na)
	inf <- cbind(a = c(1, Inf, 3), b = c(2, 4, 6)); expect_identical(D(inf)$js, 1:2)
	expect_identical(D(matrix(0, 0, 3))$js, 1:3)
	expect_identical(D(matrix(0, 3, 0))$js, integer(0))
	expect_identical(dim(D(data.frame(x = 1:4, y = 2 * (1:4)))$M), c(4L, 1L))
})

test_that("create_model_matrix_from_features drops the intercept and expands factors like model.matrix", {
	d <- data.frame(x = a[1:12], g = factor(rep(c("u", "v", "w"), 4)))
	m <- Z("create_model_matrix_from_features")(~ x + g, d)
	ref <- model.matrix(~ x + g, d)[, -1, drop = FALSE]
	expect_equal(m, ref)
	expect_false("(Intercept)" %in% colnames(m))
	expect_identical(colnames(m), c("x", "gv", "gw"))
})

test_that("create_model_matrix_from_features applies the rank cleanup and handles a zero-column frame", {
	d <- data.frame(x = a[1:12], dup = a[1:12])
	m <- Z("create_model_matrix_from_features")(~ x + dup, d)
	expect_identical(colnames(m), "x")
	e <- Z("create_model_matrix_from_features")(~ ., data.frame(row.names = 1:4))
	expect_identical(dim(e), c(4L, 0L))
	# a no-intercept formula keeps its first column untouched
	m2 <- Z("create_model_matrix_from_features")(~ 0 + x, d[, "x", drop = FALSE])
	expect_identical(colnames(m2), "x")
})
