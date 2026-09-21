library(testthat)
library(EDI)

# compute_matching_lin_match_data_cpp and compute_matching_lin_wy_stats_cpp on random pair/reservoir layouts,
# including pairs with both rows in one arm, sparse pair ids (gaps), and non-pair-ordered rows.
# Reference: independent R derivation; the wy-stats kernel must equal the y/w part of the full kernel.

L <- get("compute_matching_lin_match_data_cpp", envir = asNamespace("EDI"))
WY <- get("compute_matching_lin_wy_stats_cpp", envir = asNamespace("EDI"))

ref <- function(X, y, w, m) {
	m[is.na(m)] <- 0L
	M <- max(0L, m); res <- which(m <= 0L)
	yT <- rep(NA_real_, M); yC <- rep(NA_real_, M); Xd <- matrix(0, M, ncol(X)); Xm <- Xd
	for (i in which(m > 0L)) {
		k <- m[i]
		if (w[i] == 1) { yT[k] <- y[i]; Xd[k, ] <- Xd[k, ] + X[i, ] } else { yC[k] <- y[i]; Xd[k, ] <- Xd[k, ] - X[i, ] }
		Xm[k, ] <- Xm[k, ] + X[i, ] / 2
	}
	list(M = M, res = res, yT = yT, yC = yC, yd = ifelse(!is.na(yT) & !is.na(yC), yT - yC, NA_real_), Xd = Xd, Xm = Xm)
}

layout <- function(seed) {
	set.seed(seed)
	n <- sample(12:40, 1); P <- sample(2:6, 1)
	m <- rep(NA_integer_, n)
	ids <- sample(n, 2 * P); m[ids] <- sample(rep(seq_len(P), each = 2))       # rows of a pair need not be adjacent
	if (seed %% 3 == 0) m[m == 2L & !is.na(m)] <- NA                            # empties a pair id -> gap in ids
	list(X = matrix(rnorm(n * 3), n, 3), y = rnorm(n), w = sample(0:1, n, TRUE), m = m)
}

test_that("full kernel matches the reference for random layouts", {
	for (s in 1:30) {
		d <- layout(s); r <- ref(d$X, d$y, d$w, d$m); g <- L(d$X, d$y, d$w, d$m)
		expect_equal(g$m, r$M, info = s)
		expect_equal(g$yTs_matched, r$yT); expect_equal(g$yCs_matched, r$yC); expect_equal(g$y_matched_diffs, r$yd)
		expect_equal(unname(g$X_matched_diffs_full), unname(r$Xd)); expect_equal(unname(g$X_matched_means_full), unname(r$Xm))
		expect_equal(unname(g$X_reservoir), unname(d$X[r$res, , drop = FALSE]))
		expect_equal(g$y_reservoir, d$y[r$res]); expect_equal(g$w_reservoir, d$w[r$res])
		expect_equal(g$nRT, sum(d$w[r$res] == 1)); expect_equal(g$nRC, sum(d$w[r$res] != 1))
	}
})

test_that("wy-stats kernel equals the outcome-side fields of the full kernel", {
	for (s in 31:60) {
		d <- layout(s); g <- L(d$X, d$y, d$w, d$m); h <- WY(d$w, d$y, d$m)
		for (nm in c("y_matched_diffs", "yTs_matched", "yCs_matched", "y_reservoir", "w_reservoir", "nRT", "nRC"))
			expect_equal(h[[nm]], g[[nm]], info = paste(s, nm))
		expect_null(h$m)
	}
})

test_that("a gap in the pair ids leaves an all-NA slot and zero X row (m is the maximum id)", {
	X <- cbind(1:4, 4:1); y <- c(5, 3, 9, 2); w <- c(1L, 0L, 1L, 0L); m <- c(1L, 1L, 3L, 3L)
	g <- L(X, y, w, m)
	expect_equal(g$m, 3L)
	expect_true(is.na(g$y_matched_diffs[2]) && is.na(g$yTs_matched[2]) && is.na(g$yCs_matched[2]))
	expect_equal(unname(g$X_matched_diffs_full[2, ]), c(0, 0))
	expect_equal(g$y_matched_diffs[c(1, 3)], c(2, 7))
	expect_equal(unname(g$X_matched_means_full[3, ]), c((3 + 4) / 2, (2 + 1) / 2))
})

test_that("m_vec entries that are NA, 0 or negative are all reservoir", {
	X <- matrix(1:5, 5); y <- c(1, 2, 3, 4, 5); w <- c(1L, 0L, 1L, 0L, 1L)
	g <- L(X, y, w, c(NA, 0L, -1L, 1L, 1L))
	expect_equal(g$nRT + g$nRC, 3L)
	expect_equal(g$y_reservoir, c(1, 2, 3)); expect_equal(g$w_reservoir, c(1L, 0L, 1L))
	expect_equal(g$y_matched_diffs, 5 - 4)
})
