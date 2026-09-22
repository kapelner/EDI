library(testthat)
library(EDI)

# DesignSeqOneByOneRandomBlockSize$assign_wt(): each stratum's assignment sequence is a concatenation of permuted blocks whose sizes are drawn from
# block_sizes and which contain exactly round(size * prob_T) treated units (the last block may be incomplete). Reference: a dynamic-programming
# check that the observed sequence admits such a decomposition (independent of the class's own state), per stratum; both block sizes must appear
# over a long run; the running arm imbalance never exceeds the largest block's slack; argument validation.

decomposes <- function(w, sizes, pT) {
	n <- length(w); cs <- c(0L, cumsum(w == 1L)); reach <- logical(n + 1L); reach[1] <- TRUE
	for (p in 0:n) {
		if (!reach[p + 1L]) next
		for (bs in sizes) {
			nT <- round(bs * pT); nC <- bs - nT
			if (p + bs <= n && (cs[p + bs + 1L] - cs[p + 1L]) == nT) reach[p + bs + 1L] <- TRUE
			if (p + bs > n) {                                  # trailing incomplete block: prefix must be consistent with some permuted block
				len <- n - p; t <- cs[n + 1L] - cs[p + 1L]
				if (t <= nT && (len - t) <= nC) reach[n + 1L] <- TRUE
			}
		}
	}
	reach[n + 1L]
}
mk <- function(n, sizes, pT = 0.5, X = NULL, strata_cols = NULL, seed = 1L) {
	set.seed(seed)
	d <- DesignSeqOneByOneRandomBlockSize$new(strata_cols = strata_cols, block_sizes = sizes, prob_T = pT, response_type = "continuous", n = n, verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(if (is.null(X)) data.frame(x = 0) else X[i, , drop = FALSE])
	d$get_w()
}

test_that("a single stratum's sequence decomposes into balanced permuted blocks of the allowed sizes, over several seeds and sizes", {
	for (seed in 1:15) {
		w <- mk(60L, c(4, 6), seed = seed)
		expect_true(decomposes(w, c(4, 6), 0.5), info = paste("seed", seed))
	}
	for (seed in 1:10) expect_true(decomposes(mk(50L, c(4, 8), 0.25, seed = seed), c(4, 8), 0.25), info = paste("pT 0.25 seed", seed))
	expect_false(decomposes(rep(1L, 12), c(4, 6), 0.5))                                       # the reference is discriminating
})

test_that("the design is balanced: running imbalance stays within the largest block's slack and the final share is near prob_T", {
	for (seed in 1:10) {
		w <- mk(120L, c(4, 6, 8), seed = seed)
		imb <- abs(cumsum(ifelse(w == 1L, 1, -1)))
		expect_lte(max(imb), 4L)                                                              # never more than half the largest block
		expect_lte(abs(mean(w) - 0.5), 4 / 120)
	}
})

test_that("both block sizes are actually used over a long run (completed blocks of size 4 and of size 6 both occur)", {
	used <- character()
	for (seed in 1:20) {
		w <- mk(60L, c(4, 6), seed = seed)
		# a boundary after position 4 with a balanced first 4 (and not 6-decomposable start) reveals size 4 first blocks
		used <- c(used, if (sum(w[1:4]) == 2L && sum(w[1:6]) != 3L) "4" else if (sum(w[1:6]) == 3L && sum(w[1:4]) != 2L) "6" else "?")
	}
	expect_true(all(c("4", "6") %in% used))
})

test_that("strata_cols: every stratum's own subsequence decomposes independently", {
	set.seed(3); n <- 90L
	g <- sample(c("a", "b", "c"), n, TRUE); X <- data.frame(g = factor(g))
	w <- mk(n, c(4, 6), X = X, strata_cols = "g", seed = 4L)
	for (lv in c("a", "b", "c")) expect_true(decomposes(w[g == lv], c(4, 6), 0.5), info = lv)
})

test_that("block sizes must give an integer number of treated units and must be positive integers", {
	expect_error(DesignSeqOneByOneRandomBlockSize$new(block_sizes = c(5, 6), prob_T = 0.5, response_type = "continuous", n = 10L, verbose = FALSE), "integer number")
	expect_error(DesignSeqOneByOneRandomBlockSize$new(block_sizes = c(0, 4), response_type = "continuous", n = 10L, verbose = FALSE))
	expect_error(DesignSeqOneByOneRandomBlockSize$new(block_sizes = 2.5, response_type = "continuous", n = 10L, verbose = FALSE))
})
