library(testthat)
library(EDI)

# generate_permutations_matching_cpp / _ibcrd_cpp / _bernoulli_cpp: structural invariants recomputed from the returned
# assignment matrices. Matching: matched pairs always get opposite arms (first pair member treated with probability
# prob_T), reservoir units and one-member "pairs" are independent Bernoulli(prob_T). iBCRD: exactly round(n * prob_T)
# treated in every column, uniform marginals. Bernoulli: independent Bernoulli(prob_T) with 0/1 corners.

Km <- get("generate_permutations_matching_cpp", envir = asNamespace("EDI"))
Ki <- get("generate_permutations_ibcrd_cpp", envir = asNamespace("EDI"))
Kb <- get("generate_permutations_bernoulli_cpp", envir = asNamespace("EDI"))
tol <- function(q, m) 4 * sqrt(q * (1 - q) / m)

test_that("matching: pair members always get opposite arms; first member is treated with probability prob_T", {
	m_vec <- as.integer(c(1, 1, 0, 2, 0, 2, 3, 3, 0, 4))       # pairs 1..3, reservoir {3,5,9}, singleton "pair" 4 (unit 10)
	set.seed(1); W <- Km(m_vec, 3000L, 0.3)$w_mat
	expect_equal(dim(W), c(10L, 3000L)); expect_true(all(W %in% 0:1))
	for (id in 1:3) {
		idx <- which(m_vec == id)
		expect_true(all(W[idx[1], ] + W[idx[2], ] == 1L), info = as.character(id))
		expect_equal(mean(W[idx[1], ]), 0.3, tolerance = tol(0.3, 3000) / 0.3)
	}
	for (i in c(3, 5, 9, 10)) expect_equal(mean(W[i, ]), 0.3, tolerance = tol(0.3, 3000) / 0.3, info = as.character(i))
	expect_lt(abs(cor(W[3, ], W[5, ])), 0.06)                # reservoir units are independent
})

test_that("matching: prob_T corners, all-reservoir and all-paired layouts, and reproducibility", {
	m_vec <- as.integer(c(1, 1, 0, 0))
	set.seed(2); expect_true(all(Km(m_vec, 20L, 1)$w_mat[3:4, ] == 1L))
	expect_true(all(Km(m_vec, 20L, 0)$w_mat[3:4, ] == 0L))
	W_all <- Km(rep(0L, 6), 50L, 0.5)$w_mat
	expect_equal(dim(W_all), c(6L, 50L))
	Wp <- Km(rep(1:3, each = 2L), 50L, 0.5)$w_mat
	expect_true(all(Wp[c(1, 3, 5), ] + Wp[c(2, 4, 6), ] == 1L))
	set.seed(3); a <- Km(m_vec, 10L, 0.5); set.seed(3); b <- Km(m_vec, 10L, 0.5)
	expect_identical(a$w_mat, b$w_mat); expect_null(a$m_mat)
})

test_that("iBCRD: exactly half-up-rounded n * prob_T treated per column (C++ std::round, not R round-half-even), uniform marginals, different columns differ", {
	set.seed(4)
	for (spec in list(c(20, 0.5), c(21, 0.5), c(25, 0.3), c(10, 0))) {
		n <- spec[1]; pt <- spec[2]
		W <- Ki(as.integer(n), 2000L, pt)$w_mat
		expect_equal(dim(W), c(n, 2000L))
		expect_true(all(colSums(W) == floor(n * pt + 0.5)), info = paste(spec, collapse = "/"))
	}
	W <- Ki(20L, 4000L, 0.4)$w_mat
	expect_true(all(abs(rowMeans(W) - 0.4) < 4 * sqrt(0.24 / 4000) * 1.5))
	expect_gt(length(unique(apply(W[, 1:50], 2, paste, collapse = ""))), 40L)
	expect_true(all(Ki(6L, 5L, 1)$w_mat == 1L))
})

test_that("Bernoulli: independent Bernoulli(prob_T) draws with degenerate corners", {
	set.seed(5); W <- Kb(30L, 3000L, 0.25)$w_mat
	expect_equal(dim(W), c(30L, 3000L)); expect_true(all(W %in% 0:1))
	expect_equal(mean(W), 0.25, tolerance = tol(0.25, 90000) / 0.25)
	expect_lt(abs(cor(W[1, ], W[2, ])), 0.06)
	expect_gt(sd(colSums(W)), 0)                             # unlike iBCRD the arm size varies
	expect_true(all(Kb(5L, 10L, 1)$w_mat == 1L)); expect_true(all(Kb(5L, 10L, 0)$w_mat == 0L))
	set.seed(6); a <- Kb(8L, 6L, 0.5); set.seed(6); b <- Kb(8L, 6L, 0.5)
	expect_identical(a$w_mat, b$w_mat); expect_null(a$m_mat)
})
