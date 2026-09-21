library(testthat)
library(EDI)

# compute_survival_strata_ids_cpp(X, max_unique_per_col, max_strata_cols, min_count_per_level): picks low-cardinality
# numeric columns (finite, 2..max_unique levels, every level >= min_count), keeps the max_strata_cols with the fewest
# levels (ties by column index), and returns first-appearance-ordered stratum ids of their joint levels.
# Reference: base-R interaction() / table() over the same selected columns.

K0 <- get("compute_survival_strata_ids_cpp", envir = asNamespace("EDI"))
K <- function(X, ...) { storage.mode(X) <- "double"; K0(X, ...) }      # the kernel maps a double matrix

ref_partition_equal <- function(ids, X, cols) {
	key <- do.call(paste, c(lapply(cols, function(j) X[, j]), sep = "|"))
	expect_identical(as.integer(factor(key, levels = unique(key))), as.integer(ids))      # first-appearance order
}

set.seed(1); n <- 60L
X <- cbind(cont = rnorm(n), bin = rbinom(n, 1, 0.5), tri = sample(1:3, n, TRUE), five = sample(1:5, n, TRUE), const = 7)

test_that("selects low-cardinality columns fewest-levels first and ids equal the joint-level partition", {
	r <- K(X)
	# eligible: bin (2), tri (3); five has 5 > max_unique 4; cont is continuous; const has one level
	expect_identical(r$selected_cols, c(2L, 3L))
	ref_partition_equal(r$strata_id, X, r$selected_cols)
	expect_identical(r$num_strata, length(unique(paste(X[, 2], X[, 3]))))
	expect_identical(r$num_strata, max(r$strata_id))
	expect_identical(min(r$strata_id), 1L)
})

test_that("max_strata_cols truncates to the fewest-level columns; a tie is resolved by column index", {
	Xt <- cbind(a = sample(0:2, n, TRUE), b = sample(0:1, n, TRUE), c = sample(0:1, n, TRUE), d = sample(0:2, n, TRUE))
	r <- K(Xt, max_strata_cols = 2L)
	expect_identical(r$selected_cols, c(2L, 3L))
	ref_partition_equal(r$strata_id, Xt, r$selected_cols)
	r3 <- K(Xt, max_strata_cols = 3L)
	expect_identical(r3$selected_cols, c(2L, 3L, 1L))
	r1 <- K(Xt, max_strata_cols = 1L)
	expect_identical(r1$selected_cols, 2L); expect_identical(r1$num_strata, 2L)
})

test_that("max_unique_per_col and min_count_per_level gate eligibility", {
	expect_identical(K(X, max_unique_per_col = 5L)$selected_cols, c(2L, 3L, 4L))
	Xr <- cbind(rare = c(rep(0, n - 1), 1), bin = rep(0:1, length.out = n))         # 'rare' has a level with count 1
	expect_identical(K(Xr)$selected_cols, 2L)
	expect_identical(K(Xr, min_count_per_level = 1L)$selected_cols, c(1L, 2L))
})

test_that("stratum ids are numbered by first appearance in row order", {
	Xo <- cbind(g = c(2, 2, 1, 1, 3, 3, 2, 1, 3, 1, 2, 3))
	r <- K(Xo, min_count_per_level = 1L)
	expect_identical(r$strata_id, c(1L, 1L, 2L, 2L, 3L, 3L, 1L, 2L, 3L, 2L, 1L, 3L))
	expect_identical(r$num_strata, 3L)
})

test_that("columns with non-finite entries are skipped", {
	Xn <- cbind(withna = c(NA, rep(0:1, length.out = n - 1)), inf = c(Inf, rep(0:1, length.out = n - 1)), ok = rep(0:1, length.out = n))
	expect_identical(K(Xn)$selected_cols, 3L)
})

test_that("no eligible column, empty input, or degenerate limits give the single default stratum", {
	def <- function(r) { expect_identical(r$selected_cols, integer(0)); expect_identical(r$num_strata, 1L); expect_true(all(r$strata_id == 1L)) }
	def(K(cbind(rnorm(n), rnorm(n))))
	def(K(matrix(0, 0, 2))); expect_length(K(matrix(0, 0, 2))$strata_id, 0L)
	def(K(X, max_unique_per_col = 1L)); def(K(X, max_strata_cols = 0L))
	expect_length(K(X, max_strata_cols = 0L)$strata_id, n)
	def(K(cbind(rep(3, n))))
})

test_that("mixed-radix combination never merges distinct level combinations (random columns)", {
	for (s in 1:15) {
		set.seed(s); Xs <- cbind(sample(0:3, 80, TRUE), sample(0:2, 80, TRUE), sample(0:1, 80, TRUE), sample(0:3, 80, TRUE))
		r <- K(Xs, max_unique_per_col = 4L, max_strata_cols = 4L)
		key <- do.call(paste, c(lapply(r$selected_cols, function(j) Xs[, j]), sep = "|"))
		expect_identical(length(unique(r$strata_id)), length(unique(key)), info = s)
		expect_identical(nrow(unique(cbind(r$strata_id, key))), length(unique(key)), info = s)
	}
})

test_that("an integer-typed matrix is rejected by the Eigen mapping (callers pass double matrices)", {
	Xi <- matrix(sample(0:1, 20, TRUE), 10)
	storage.mode(Xi) <- "integer"
	expect_error(K0(Xi), "Wrong R type for mapped matrix")
})
