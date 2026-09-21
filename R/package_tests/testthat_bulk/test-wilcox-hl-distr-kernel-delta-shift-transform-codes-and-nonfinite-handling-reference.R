library(testthat)
library(EDI)

# compute_wilcox_hl_distr_parallel_cpp: HL statistic (median of all treated-minus-control differences) per
# permutation column, with the treated responses shifted by delta under the response transform code
# (0 additive, 1 multiplicative exp(delta), 2 logit-additive, 3 (y+1)*exp(delta)-1, 4 rounded multiplicative).
# Reference: the same statistic computed in R from the closed-form shift. Non-finite responses are dropped
# and assignment entries other than 0/1 are ignored.

K <- EDI:::compute_wilcox_hl_distr_parallel_cpp
set.seed(41); n <- 24L; r <- 6L
W <- matrix(0L, n, r); for (b in 1:r) W[, b] <- sample(rep(0:1, each = n / 2))
hl <- function(yt, yc) median(outer(yt, yc, "-"))
ref <- function(y, W, shift) vapply(seq_len(ncol(W)), function(b) {
	ok <- is.finite(y)
	hl(shift(y[W[, b] == 1L & ok]), y[W[, b] == 0L & ok])
}, numeric(1))

test_that("delta = 0 ignores the transform code", {
	y <- rnorm(n)
	for (code in 0:4) expect_equal(K(W, y, 0, code, 1e-8, 1L), ref(y, W, identity), tolerance = 1e-12)
})

test_that("each transform code shifts the treated responses as documented", {
	d <- 0.35
	yc <- rpois(n, 4) + 0                       # counts, valid for every code except logit
	expect_equal(K(W, yc + 0, d, 0L, 1e-8, 1L), ref(yc, W, function(v) v + d), tolerance = 1e-10)
	expect_equal(K(W, yc + 0, d, 1L, 1e-8, 1L), ref(yc, W, function(v) v * exp(d)), tolerance = 1e-10)
	expect_equal(K(W, yc + 0, d, 3L, 1e-8, 1L), ref(yc, W, function(v) (v + 1) * exp(d) - 1), tolerance = 1e-10)
	expect_equal(K(W, yc + 0, d, 4L, 1e-8, 1L), ref(yc, W, function(v) round(v * exp(d))), tolerance = 1e-10)
	p <- runif(n, 0.05, 0.95)
	expect_equal(K(W, p, d, 2L, 1e-8, 1L), ref(p, W, function(v) plogis(qlogis(v) + d)), tolerance = 1e-9)
})

test_that("non-finite responses are skipped and assignment codes other than 0/1 are ignored", {
	y <- rnorm(n); y[c(3, 9)] <- c(NA, Inf)
	expect_equal(K(W, y, 0.5, 0L, 1e-8, 1L), ref(y, W, function(v) v + 0.5), tolerance = 1e-10)
	W2 <- W; W2[1:2, ] <- 2L
	yy <- rnorm(n)
	expect_equal(K(W2, yy, 0, 0L, 1e-8, 1L), vapply(1:r, function(b) hl(yy[W2[, b] == 1L], yy[W2[, b] == 0L]), numeric(1)), tolerance = 1e-12)
})

test_that("a permutation with an empty arm yields NA and thread count does not change the result", {
	y <- rnorm(n)
	W3 <- cbind(W[, 1], rep(1L, n))
	out <- K(W3, y, 0, 0L, 1e-8, 1L)
	expect_true(is.na(out[2])); expect_true(is.finite(out[1]))
	expect_equal(K(W, y, 0.2, 0L, 1e-8, 2L), K(W, y, 0.2, 0L, 1e-8, 1L), tolerance = 1e-14)
})
