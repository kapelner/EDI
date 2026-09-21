library(testthat)
library(EDI)

# compute_zhang_match_data_cpp(X, y, w, m_vec) and compute_matching_wy_stats_cpp(w, y, m_vec): pair-id-indexed
# treated/control outcomes, X differences (treated minus control), reservoir tallies, and discordant counts.
# Reference: independent R re-derivation; the wy-stats kernel must equal the y/w part of the full kernel.

Z <- get("compute_zhang_match_data_cpp", envir = asNamespace("EDI"))
WY <- get("compute_matching_wy_stats_cpp", envir = asNamespace("EDI"))
succ <- function(v) is.finite(v) & v != 0

ref <- function(X, y, w, m) {
	m[is.na(m)] <- 0L
	M <- max(0L, m); res <- which(m <= 0L)
	yT <- rep(NA_real_, M); yC <- rep(NA_real_, M); Xd <- matrix(0, M, ncol(X))
	for (i in which(m > 0L)) {
		if (w[i] == 1) { yT[m[i]] <- y[i]; Xd[m[i], ] <- Xd[m[i], ] + X[i, ] }
		else { yC[m[i]] <- y[i]; Xd[m[i], ] <- Xd[m[i], ] - X[i, ] }
	}
	both <- !is.na(yT) & !is.na(yC)
	list(m = M, yT = yT, yC = yC, yd = ifelse(both, yT - yC, NA_real_), Xd = Xd, res = res,
		nRT = sum(w[res] == 1), nRC = sum(w[res] != 1),
		n11 = sum(w[res] == 1 & succ(y[res])), n10 = sum(w[res] == 1 & !succ(y[res])),
		n01 = sum(w[res] != 1 & succ(y[res])), n00 = sum(w[res] != 1 & !succ(y[res])),
		dp = sum(both & succ(yT) & !succ(yC)), dm = sum(both & !succ(yT) & succ(yC)))
}

fixture <- function(seed, n = 30L, pairs = 8L) {
	set.seed(seed)
	m <- rep(NA_integer_, n)
	ids <- sample(n, 2 * pairs); m[ids] <- rep(seq_len(pairs), each = 2)
	w <- integer(n); for (k in seq_len(pairs)) w[which(m == k)[1]] <- 1L   # first row of each pair treated
	nz <- setdiff(seq_len(n), which(m > 0)); w[nz] <- sample(0:1, length(nz), TRUE)
	list(X = cbind(a = rnorm(n), b = rnorm(n), k = 2), y = rbinom(n, 1, 0.5) * sample(c(1, 2.5), n, TRUE), w = w, m = m)
}

test_that("full kernel matches the reference across random pair / reservoir layouts", {
	for (s in 1:15) {
		d <- fixture(s); r <- ref(d$X, d$y, d$w, d$m)
		g <- Z(d$X, d$y, d$w, d$m)
		expect_equal(g$m, r$m)
		expect_equal(g$yTs_matched, r$yT); expect_equal(g$yCs_matched, r$yC); expect_equal(g$y_matched_diffs, r$yd)
		expect_equal(unname(g$X_matched_diffs_full), unname(r$Xd))
		expect_equal(unname(g$X_reservoir), unname(d$X[r$res, ])); expect_equal(g$y_reservoir, d$y[r$res])
		expect_equal(g$w_reservoir, d$w[r$res])
		for (nm in c("nRT", "nRC", "n11", "n10", "n01", "n00")) expect_equal(g[[nm]], r[[nm]], info = nm)
		expect_equal(g$d_plus, r$dp); expect_equal(g$d_minus, r$dm)
	}
})

test_that("wy-stats kernel equals the outcome-side fields of the full kernel", {
	for (s in 1:15) {
		d <- fixture(s + 100); g <- Z(d$X, d$y, d$w, d$m); h <- WY(d$w, d$y, d$m)
		for (nm in c("yTs_matched", "yCs_matched", "y_matched_diffs", "y_reservoir", "w_reservoir",
			"nRT", "nRC", "d_plus", "d_minus", "n11", "n10", "n01", "n00")) expect_equal(h[[nm]], g[[nm]], info = nm)
	}
})

test_that("X_matched_diffs drops all-zero columns (constant covariate cancels) and keeps the rest in order", {
	d <- fixture(3); g <- Z(d$X, d$y, d$w, d$m)
	keep <- which(colSums(abs(g$X_matched_diffs_full)) > 0)
	expect_false(3L %in% keep)
	expect_equal(unname(g$X_matched_diffs), unname(g$X_matched_diffs_full[, keep, drop = FALSE]))
})

test_that("m_vec of all NA / zero is all-reservoir; m = 0 keeps every column", {
	d <- fixture(5); n <- length(d$y)
	g <- Z(d$X, d$y, d$w, rep(NA_integer_, n))
	expect_equal(g$m, 0L); expect_equal(g$nRT + g$nRC, n)
	expect_equal(dim(g$X_matched_diffs), c(0L, 3L))
	expect_equal(g$w_reservoir, d$w)
	g0 <- Z(d$X, d$y, d$w, rep(0L, n)); expect_equal(g0$nRT, g$nRT)
})

test_that("an incomplete pair (one arm missing) yields NA difference and no discordance", {
	X <- cbind(1:4, c(2, 4, 1, 3)); y <- c(1, 0, 1, 1); w <- c(1L, 1L, 0L, 1L); m <- c(1L, 1L, 2L, 2L)
	g <- Z(X, y, w, m)
	expect_true(is.na(g$y_matched_diffs[1])); expect_false(is.na(g$y_matched_diffs[2]))
	expect_equal(g$y_matched_diffs[2], 0)
	expect_equal(c(g$d_plus, g$d_minus), c(0L, 0L))
	expect_equal(g$yTs_matched, c(0, 1))          # last treated row in a pair wins
	expect_true(is.na(g$yCs_matched[1]))
})

test_that("discordance uses finite-non-zero success: Inf and NA outcomes count as failures", {
	X <- matrix(1:6, 6); w <- rep(1:0, 3); m <- c(1L, 1L, 2L, 2L, 3L, 3L)
	y <- c(1, 0, Inf, 2, 3, NA)
	g <- Z(X, y, w, m)
	expect_equal(g$d_plus, 2L)     # pair 1: 1 vs 0; pair 3: 3 vs NA (NA is a failure, arm still present)
	expect_equal(g$d_minus, 1L)    # pair 2: Inf (fail) vs 2 (success)
})

test_that("dimension mismatches are rejected with clear messages", {
	d <- fixture(2); n <- length(d$y)
	expect_error(Z(d$X, d$y, d$w, d$m[-1]), "m_vec size must match w size")
	expect_error(Z(d$X, d$y[-1], d$w, d$m), "y size must match w size")
	expect_error(Z(d$X[-1, ], d$y, d$w, d$m), "X row count must match w size")
})
