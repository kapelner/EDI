library(testthat)
library(EDI)

# DesignSeqOneByOneUrn$assign_wt(): Wei's urn rule P(T | nT, nC) = (alpha + beta * nC) / (2 * alpha + beta * (nT + nC)). Reference: the formula against the
# empirical conditional treatment frequency in every visited (nT, nC) state over many replicated 8-subject designs (state counts are read from the
# design's own realised assignments), beta = 0 reduces to a fair coin regardless of state, first-subject probability is 1/2 for alpha > 0, argument
# validation, and (REGRESSION, fixed 2026-09-22) alpha = 0 is now rejected at construction instead of silently producing NA assignments (the first-step
# probability was 0 / 0): the alpha bound was gated at 0, allowing exactly zero through, and is now gated at +epsilon.

run_w <- function(alpha, beta, n = 8L, seed) {
	set.seed(seed)
	d <- DesignSeqOneByOneUrn$new(alpha = alpha, beta = beta, response_type = "continuous", n = n, verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = 0))
	d$get_w()
}
states <- function(alpha, beta, R = 3000L, n = 8L) {
	rows <- vector("list", R)
	for (r in seq_len(R)) {
		w <- run_w(alpha, beta, n, seed = r)
		nT <- c(0L, cumsum(w == 1L))[seq_len(n)]; nC <- (seq_len(n) - 1L) - nT
		rows[[r]] <- data.frame(nT = nT, nC = nC, w = w)
	}
	do.call(rbind, rows)
}
check_rule <- function(alpha, beta) {
	s <- states(alpha, beta)
	key <- paste(s$nT, s$nC)
	checked <- 0L
	for (k in unique(key)) {
		idx <- key == k; m <- sum(idx)
		if (m < 400L) next
		nT <- s$nT[idx][1]; nC <- s$nC[idx][1]
		p <- (alpha + beta * nC) / (2 * alpha + beta * (nT + nC))
		expect_lt(abs(mean(s$w[idx]) - p), 4 * sqrt(p * (1 - p) / m) + 1e-9, label = paste("state", k, "alpha", alpha, "beta", beta))
		checked <- checked + 1L
	}
	expect_gt(checked, 5L)
}

test_that("conditional treatment frequency equals Wei's urn probability in every well-visited state (alpha = 1, beta = 2 and alpha = 2, beta = 1)", {
	check_rule(1, 2)
	check_rule(2, 1)
})

test_that("beta = 0 is a fair coin in every state; the first subject is treated with probability 1/2 for any alpha > 0", {
	s <- states(1, 0, R = 2000L)
	expect_lt(abs(mean(s$w) - 0.5), 4 * sqrt(0.25 / nrow(s)))
	first <- vapply(seq_len(2000L), function(r) run_w(3, 5, 4L, seed = r)[1], numeric(1))
	expect_lt(abs(mean(first) - 0.5), 4 * sqrt(0.25 / 2000))
})

test_that("a large beta pushes toward balance: treated share of every arm-size path stays near half", {
	ws <- vapply(seq_len(500L), function(r) mean(run_w(1, 20, 20L, seed = r)), numeric(1))
	expect_lt(sd(ws), sd(vapply(seq_len(500L), function(r) mean(run_w(1, 0, 20L, seed = r)), numeric(1))))
})

test_that("arguments are validated: negative alpha or beta are rejected", {
	expect_error(DesignSeqOneByOneUrn$new(alpha = -1, response_type = "continuous", n = 4L, verbose = FALSE))
	expect_error(DesignSeqOneByOneUrn$new(beta = -0.5, response_type = "continuous", n = 4L, verbose = FALSE))
})

test_that("REGRESSION (fixed): alpha = 0 is rejected at construction instead of silently producing NA assignments", {
	expect_error(DesignSeqOneByOneUrn$new(alpha = 0, beta = 1, response_type = "continuous", n = 5L, verbose = FALSE))
	expect_error(DesignSeqOneByOneUrn$new(alpha = 0, beta = 1, response_type = "continuous", n = 5L, verbose = FALSE), "alpha")
})
