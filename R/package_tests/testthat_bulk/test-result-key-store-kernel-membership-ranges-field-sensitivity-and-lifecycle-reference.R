library(testthat)
library(EDI)

# Global result-key store (result_key_store.cpp): init / add / check / size / clear. Reference: an R set of
# pasted key strings. Checks membership per row, 1-based inclusive start/end windows, sensitivity of the hash
# to every one of the nine key fields (incl. betaT at 15 significant digits), idempotent inserts, and lifecycle.

E <- asNamespace("EDI")
init <- get("init_result_key_store_cpp", E); clr <- get("clear_result_key_store_cpp", E)
add <- get("add_to_result_key_store_cpp", E); chk <- get("check_in_result_key_store_cpp", E)
sz <- get("result_key_store_size_cpp", E)
withr::defer(clr(), teardown_env())

mk <- function(k = 6L, ...) {
	d <- data.frame(response_type = rep(c("continuous", "incidence"), length.out = k),
		cond_exp = rep(c("linear", "nonlinear"), length.out = k), n = 100L + seq_len(k), p = 3L + seq_len(k) %% 2L,
		betaT = seq_len(k) / 10, rep = seq_len(k), design = rep(c("CRD", "KK14"), length.out = k),
		inference = rep(c("A", "B", "C"), length.out = k), itype = rep(c("mle", "rand"), length.out = k),
		stringsAsFactors = FALSE)
	for (nm in names(list(...))) d[[nm]] <- list(...)[[nm]]
	d
}
A <- function(d, ...) add(d$response_type, d$cond_exp, as.integer(d$n), as.integer(d$p), d$betaT, as.integer(d$rep),
	d$design, d$inference, d$itype, ...)
C <- function(d, ...) chk(d$response_type, d$cond_exp, as.integer(d$n), as.integer(d$p), d$betaT, as.integer(d$rep),
	d$design, d$inference, d$itype, ...)

test_that("empty / absent store: size 0, add is a no-op, check returns all FALSE of the right length", {
	clr()
	expect_equal(sz(), 0L)
	d <- mk(); A(d); expect_equal(sz(), 0L)
	expect_identical(C(d), rep(FALSE, 6L))
})

test_that("membership is per row: inserted rows are found, others are not", {
	init(20L); d <- mk(6L)
	A(d[1:3, ])
	expect_equal(sz(), 3L)
	expect_identical(C(d), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
	A(d[1:3, ]); expect_equal(sz(), 3L)                     # idempotent
})

test_that("start/end are 1-based inclusive windows for both add and check", {
	init(0L); d <- mk(8L)
	A(d, start = 3L, end = 5L)
	expect_equal(sz(), 3L)
	expect_identical(C(d), c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
	expect_identical(C(d, start = 4L, end = 6L), c(TRUE, TRUE, FALSE))
	expect_identical(C(d, start = 7L), c(FALSE, FALSE))
	expect_length(C(d, start = 1L, end = 100L), 8L)          # end clipped to n rows
	expect_length(C(d, start = 9L), 0L)
})

test_that("every key field changes the hash: perturbing any one field misses", {
	init(10L); base <- mk(1L); A(base); expect_true(C(base))
	pert <- list(
		response_type = "count", cond_exp = "other", n = 999L, p = 9L, betaT = 0.1000001, rep = 77L,
		design = "iBCRD", inference = "Z", itype = "boot")
	for (nm in names(pert)) {
		d <- base; d[[nm]] <- pert[[nm]]
		expect_false(C(d), info = nm)
	}
	d <- base; d$betaT <- 0.1 + 1e-17; expect_true(C(d))     # below 15 significant digits: same key
})

test_that("field boundaries are separated: concatenation-ambiguous keys stay distinct", {
	init(10L)
	a <- mk(1L, response_type = "ab", cond_exp = "c"); b <- mk(1L, response_type = "a", cond_exp = "bc")
	A(a); expect_true(C(a)); expect_false(C(b))
})

test_that("agrees with an R set reference on random rows", {
	set.seed(9); init(200L)
	d <- mk(60L); d$rep <- sample(1:8, 60, TRUE); d$n <- sample(c(50L, 100L), 60, TRUE); d$betaT <- sample(c(0, 0.5, 1), 60, TRUE)
	key <- function(x) do.call(paste, c(x, sep = "|"))
	ins <- d[1:30, ]; A(ins)
	expect_equal(sz(), length(unique(key(ins))))
	expect_identical(C(d), key(d) %in% key(ins))
})

test_that("init clears prior contents; clear resets the size to zero", {
	init(5L); d <- mk(3L); A(d); expect_equal(sz(), 3L)
	init(5L); expect_equal(sz(), 0L); expect_false(any(C(d)))
	A(d); clr(); expect_equal(sz(), 0L); expect_false(any(C(d)))
})
