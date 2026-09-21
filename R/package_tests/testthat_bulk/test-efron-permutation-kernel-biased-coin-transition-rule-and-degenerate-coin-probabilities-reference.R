library(testthat)
library(EDI)

# generate_permutations_efron_cpp(n, nsim, prob_T, weighted_coin_prob): each column is a sequential Efron biased-
# coin assignment. Reference: the rule applied to the returned columns themselves. Deterministic corners
# (weighted_coin_prob = 1 forces the underrepresented arm, 0 forces the overrepresented arm, prob_T in {0, 1} on
# ties), transition frequencies for the interior rule, reproducibility under set.seed, and the design-level
# draw_ws_raw() wiring.
# NOTE (source inconsistency, not pinned): the kernel's imbalance state is prob_T-weighted (nT*prob_T vs nC*(1-prob_T))
# whereas DesignSeqOneByOneEfron$assign_wt() compares raw nT with nC, so for prob_T != 0.5 the randomization
# null draws do not follow the sequential design's own assignment rule. (uses the design's prob_T / weighted_coin_prob).

K <- get("generate_permutations_efron_cpp", envir = asNamespace("EDI"))
# The kernel's imbalance state is nT * prob_T - nC * (1 - prob_T) (sign only); it equals nT - nC when prob_T = 0.5.
trans <- function(W, pt = 0.5) {
	# returns data.frame(imb = sign of the state before step t, w = assignment at t) pooled over columns and steps
	n <- nrow(W); out <- list()
	for (b in seq_len(ncol(W))) {
		nT <- c(0, cumsum(W[, b] == 1L))[seq_len(n)]; nC <- (seq_len(n) - 1) - nT
		out[[b]] <- data.frame(imb = sign(nT * pt - nC * (1 - pt)), w = W[, b], nd = nT - nC)
	}
	do.call(rbind, out)
}

test_that("shape, binary values and set.seed reproducibility", {
	set.seed(1); r1 <- K(20L, 50L, 0.5, 2/3)
	expect_equal(dim(r1$w_mat), c(20L, 50L)); expect_true(all(r1$w_mat %in% 0:1)); expect_null(r1$m_mat)
	set.seed(1); r2 <- K(20L, 50L, 0.5, 2/3)
	expect_identical(r1$w_mat, r2$w_mat)
	set.seed(2); expect_false(identical(K(20L, 50L, 0.5, 2/3)$w_mat, r1$w_mat))
})

test_that("weighted_coin_prob = 1 forces the underrepresented arm at every imbalanced step (|nT - nC| <= 1 always)", {
	set.seed(3); W <- K(31L, 200L, 0.5, 1)$w_mat
	tr <- trans(W)
	expect_true(all(tr$w[tr$imb > 0] == 0L))
	expect_true(all(tr$w[tr$imb < 0] == 1L))
	expect_true(all(abs(tr$nd) <= 1L))
})

test_that("weighted_coin_prob = 0 forces the overrepresented arm at every imbalanced step", {
	set.seed(4); tr <- trans(K(31L, 100L, 0.5, 0)$w_mat)
	expect_true(all(tr$w[tr$imb > 0] == 1L))
	expect_true(all(tr$w[tr$imb < 0] == 0L))
})

test_that("ties use prob_T: prob_T = 1 / 0 make the first subject T / C with certainty", {
	set.seed(5)
	expect_true(all(K(21L, 100L, 1, 2/3)$w_mat[1, ] == 1L))
	expect_true(all(K(21L, 100L, 0, 2/3)$w_mat[1, ] == 0L))
})

test_that("interior rule: P(T | nT > nC) = 1 - p, P(T | nT < nC) = p and P(T | tie) = prob_T", {
	set.seed(6); p <- 0.7; pt <- 0.4
	tr <- trans(K(40L, 4000L, pt, p)$w_mat, pt)
	se <- function(q, m) 4 * sqrt(q * (1 - q) / m)
	for (spec in list(list(tr$imb > 0, 1 - p), list(tr$imb < 0, p), list(tr$imb == 0, pt))) {
		idx <- spec[[1]]; q <- spec[[2]]
		expect_equal(mean(tr$w[idx]), q, tolerance = se(q, sum(idx)) / q)
	}
})

test_that("DesignSeqOneByOneEfron$draw_ws_raw draws with the design's own coin probabilities", {
	des <- DesignSeqOneByOneEfron$new(response_type = "continuous", n = 30L, weighted_coin_prob = 1, prob_T = 0.5, verbose = FALSE)
	p <- des$.__enclos_env__$private
	set.seed(7); W <- p$draw_ws_raw(r = 60L)
	expect_equal(dim(W), c(30L, 60L))
	expect_true(all(abs(trans(W)$nd) <= 1L))
})
