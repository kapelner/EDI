library(testthat)
library(EDI)

# drop_highly_correlated_cols(M, threshold): drops constant columns, then repeatedly drops every column whose
# |correlation| with an EARLIER column exceeds the threshold (strict >). `js` maps kept columns back to the input.
# Reference: an independent R implementation of the same rule plus hand-built fixtures.

D <- get("drop_highly_correlated_cols", envir = asNamespace("EDI"))
set.seed(1); n <- 60L

test_that("later duplicates of an earlier column are dropped; the earlier column and unrelated columns stay", {
	a <- rnorm(n); b <- rnorm(n)
	M <- cbind(a = a, b = b, a_copy = a + rnorm(n, sd = 1e-4), c = rnorm(n))
	r <- D(M)
	expect_identical(r$js, c(1L, 2L, 4L))
	expect_identical(colnames(r$M), c("a", "b", "c"))
	expect_equal(r$M, M[, r$js])
})

test_that("negative correlations count (absolute value)", {
	a <- rnorm(n); M <- cbind(a = a, neg = -a + rnorm(n, sd = 1e-4), z = rnorm(n))
	expect_identical(D(M)$js, c(1L, 3L))
})

test_that("threshold is strict and adjustable", {
	a <- rnorm(n); b <- 0.9 * a + sqrt(1 - 0.81) * rnorm(n)
	M <- cbind(a, b); rho <- abs(cor(a, b))
	expect_identical(D(M, threshold = rho)$js, 1:2)                       # rho > rho is FALSE: kept
	expect_identical(D(M, threshold = rho - 1e-9)$js, 1L)
	expect_identical(D(M, threshold = 0.99)$js, 1:2)
	expect_identical(D(M, threshold = 0.5)$js, 1L)
})

test_that("constant columns are dropped first and never cause NA-driven removals; js maps to input positions", {
	a <- rnorm(n); M <- cbind(const = 1, a = a, const2 = 5, a2 = a + rnorm(n, sd = 1e-5), w = rnorm(n))
	r <- D(M)
	expect_identical(r$js, c(2L, 5L))
	expect_identical(colnames(r$M), c("a", "w"))
})

test_that("uncorrelated columns are all kept; matrix / data.frame / single-column inputs are handled", {
	M <- matrix(rnorm(n * 4), n)
	expect_identical(D(M)$js, 1:4)
	expect_identical(D(as.data.frame(M))$js, 1:4)
	expect_true(is.matrix(D(as.data.frame(M))$M))
	one <- D(matrix(rnorm(n), n)); expect_identical(one$js, 1L)
	expect_identical(D(cbind(1, 2))$js, 1:2)                              # <= 1 column at start: returned untouched
	expect_identical(D(cbind(rep(1, n), rnorm(n)))$js, 2L)               # a constant dropped, one column left
})

test_that("chain a~b~c with a !~ c: the greedy rule drops both b and c in one sweep (pinned over-dropping)", {
	set.seed(2)
	a <- rnorm(n); e1 <- rnorm(n); e2 <- rnorm(n)
	b <- a + 0.15 * e1; c3 <- b + 0.15 * e2
	M <- cbind(a, b, c3)
	R <- abs(cor(M)); th <- 0.985
	skip_if_not(R[1, 2] > th && R[2, 3] > th && R[1, 3] < th, "fixture did not realise the chain")
	expect_identical(D(M, threshold = th)$js, 1L)
})

test_that("agrees with an independent reference implementation on random collinear designs; result has no remaining pair above threshold", {
	ref <- function(M, th) {
		js <- seq_len(ncol(M)); M <- as.matrix(M)
		keep_nonconst <- which(apply(M, 2, var) > 0); M <- M[, keep_nonconst, drop = FALSE]; js <- js[keep_nonconst]
		while (ncol(M) > 1) {
			R <- abs(cor(M)); drop <- which(vapply(seq_len(ncol(M)), function(j) any(R[seq_len(j - 1L), j] > th), NA))
			if (!length(drop)) break
			M <- M[, -drop, drop = FALSE]; js <- js[-drop]
		}
		js
	}
	for (s in 1:25) {
		set.seed(100 + s); p <- sample(4:9, 1); base <- matrix(rnorm(n * 3), n)
		M <- sapply(seq_len(p), function(j) base[, sample(3, 1)] * sample(c(-1, 1), 1) + rnorm(n, sd = sample(c(0.01, 0.5, 1), 1)))
		r <- D(M, 0.95)
		expect_identical(r$js, ref(M, 0.95), info = s)
		if (ncol(r$M) > 1) expect_true(all(abs(cor(r$M))[upper.tri(diag(ncol(r$M)))] <= 0.95), info = s)
	}
})
