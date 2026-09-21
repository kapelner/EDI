library(testthat)
library(EDI)

# compute_bootstrap_matching_stats_cpp(X, y, w, i_b, n_reservoir): first n_reservoir entries of i_b are the reservoir,
# the rest are consecutive (row1,row2) pairs. Reference: a plain-R re-derivation of every returned field.

K <- get("compute_bootstrap_matching_stats_cpp", envir = asNamespace("EDI"))

ref <- function(X, y, w, i_b, nr) {
	n <- length(i_b); m <- max(0L, n - nr) %/% 2L; p <- ncol(X)
	res <- i_b[seq_len(nr)]
	succ <- function(v) is.finite(v) & v != 0
	out <- list(nRT = sum(w[res] == 1), nRC = sum(w[res] != 1),
		n11 = sum(w[res] == 1 & succ(y[res])), n10 = sum(w[res] == 1 & !succ(y[res])),
		n01 = sum(w[res] != 1 & succ(y[res])), n00 = sum(w[res] != 1 & !succ(y[res])))
	Xd <- matrix(0, m, p); Xm <- matrix(0, m, p)
	yT <- rep(NA_real_, m); yC <- rep(NA_real_, m); dp <- 0L; dm <- 0L
	for (k in seq_len(m)) for (r in i_b[nr + 2 * (k - 1) + 1:2]) {
		if (w[r] == 1) { yT[k] <- y[r]; Xd[k, ] <- Xd[k, ] + X[r, ] } else { yC[k] <- y[r]; Xd[k, ] <- Xd[k, ] - X[r, ] }
		Xm[k, ] <- Xm[k, ] + X[r, ] / 2
	}
	both <- !is.na(yT) & !is.na(yC)
	yd <- ifelse(both, yT - yC, NA_real_)
	dp <- sum(both & succ(yT) & !succ(yC)); dm <- sum(both & !succ(yT) & succ(yC))
	c(out, list(m = m, Xd = Xd, Xm = Xm, yT = yT, yC = yC, yd = yd, dp = dp, dm = dm))
}

set.seed(21)
n <- 14L
X <- cbind(a = rnorm(n), b = rnorm(n), c = rep(3, n))
y <- c(rbinom(n - 2, 1, 0.5), 0, NA)[seq_len(n)]
y[5] <- 2.5; y[6] <- Inf
w <- rep(c(1L, 0L), length.out = n)

check <- function(i_b, nr, X = X, y = y, w = w) {
	got <- K(X, y, w, as.integer(i_b), nr)
	r <- ref(X, y, w, i_b, nr)
	expect_equal(got$m, r$m)
	expect_equal(got$X_matched_diffs_full, r$Xd, ignore_attr = TRUE)
	expect_equal(got$X_matched_means_full, r$Xm, ignore_attr = TRUE)
	expect_equal(got$yTs_matched, r$yT); expect_equal(got$yCs_matched, r$yC)
	expect_equal(got$y_matched_diffs, r$yd)
	for (nm in c("nRT", "nRC", "n11", "n10", "n01", "n00")) expect_equal(got[[nm]], r[[nm]], info = nm)
	expect_equal(got$d_plus, r$dp); expect_equal(got$d_minus, r$dm)
	got
}

test_that("well-formed pair draws (one treated, one control per pair) match the reference", {
	# reservoir rows 1..4; pairs (1,2)-style rows with opposite arms
	i_b <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	got <- check(i_b, 4L, X, y, w)
	expect_equal(got$m, 4L)
	expect_equal(unname(got$X_reservoir), unname(X[1:4, ]))
	expect_equal(got$y_reservoir, y[1:4]); expect_equal(got$w_reservoir, w[1:4])
})

test_that("pair row order does not matter and resampled (repeated) rows are honoured", {
	set.seed(4)
	for (rep in 1:20) {
		i_b <- c(sample(n, 4, TRUE), as.vector(rbind(sample(which(w == 1), 4, TRUE), sample(which(w == 0), 4, TRUE))))
		swap <- sample(c(TRUE, FALSE), 4, TRUE)
		idx <- 4 + 2 * (seq_len(4) - 1) + 1
		for (k in which(swap)) i_b[idx[k] + 0:1] <- i_b[idx[k] + 1:0]
		yy <- y; yy[is.na(yy)] <- 0
		check(i_b, 4L, X, yy, w)
	}
})

test_that("a pair whose rows share an arm yields NA diffs and no d_plus/d_minus contribution", {
	yy <- c(1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0)
	i_b <- c(1, 3, 5, 1, 3, 2, 4)             # pairs (1,3) both treated, (2,4) both control
	got <- check(i_b, 3L, X, yy, w)
	expect_true(is.na(got$y_matched_diffs[1]))
	expect_true(is.na(got$yCs_matched[1]) && !is.na(got$yTs_matched[1]))
	expect_equal(got$d_plus + got$d_minus, 0L)
})

test_that("success is a finite non-zero outcome: Inf and NA count as failures, 2.5 as success", {
	yy <- rep(0, n); yy[1] <- 2.5; yy[3] <- Inf; yy[5] <- NA
	got <- check(c(1, 3, 5, 2, 4), 3L, X, yy, w)
	expect_equal(got$n11, 1L)      # rows 1,3,5 treated: 2.5 success; Inf, NA failures
	expect_equal(got$n10, 2L)
})

test_that("X_matched_diffs drops all-zero columns; constant covariates cancel within pairs", {
	got <- K(X, replace(y, is.na(y), 0), w, as.integer(1:12), 4L)
	expect_equal(colnames(got$X_matched_diffs), NULL)
	expect_lt(ncol(got$X_matched_diffs), ncol(X) + 1L)
	# column c is constant 3: diff of (3 - 3) = 0 for every opposite-arm pair -> dropped
	keep <- which(colSums(abs(got$X_matched_diffs_full)) > 0)
	expect_equal(ncol(got$X_matched_diffs), length(keep))
	expect_equal(got$X_matched_diffs, got$X_matched_diffs_full[, keep, drop = FALSE], ignore_attr = TRUE)
	expect_false(3L %in% keep)
})

test_that("no reservoir, all-reservoir and odd-leftover sizes behave sanely", {
	g0 <- K(X, replace(y, is.na(y), 0), w, as.integer(1:8), 0L)
	expect_equal(g0$m, 4L); expect_equal(g0$nRT + g0$nRC, 0L)
	g1 <- K(X, replace(y, is.na(y), 0), w, as.integer(1:6), 6L)
	expect_equal(g1$m, 0L); expect_equal(g1$nRT + g1$nRC, 6L)
	expect_equal(nrow(g1$X_matched_diffs), 0L)
	g2 <- K(X, replace(y, is.na(y), 0), w, as.integer(1:7), 2L)     # 5 leftover rows -> 2 pairs, last row ignored
	expect_equal(g2$m, 2L)
})
