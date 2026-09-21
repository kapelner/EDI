library(testthat)
library(EDI)

# helper_matching.R: .compute_kk_basic_match_data() / .compute_kk_lin_basic_match_data()
# against a from-scratch pair decomposition, their cached variants (design-level
# structural cache reuse vs local bootstrap non-caching, and value equality with a
# fresh computation for new y / w), .init_kk_bootstrap_structure() and
# .draw_kk_bootstrap_indices() (pairs resampled as units, reservoir iid).

Z <- function(x) get(x, envir = asNamespace("EDI"))

kk_data <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	list(n = n, X = matrix(rnorm(n * 2), n, 2, dimnames = list(NULL, c("a", "b"))),
		w = c(0, 1, 1, 0, 0, 1, 0, 1, 1, 0), y = rnorm(n), m = c(1, 1, 2, 2, 3, 3, 0, 0, 0, 0))
}

ref_pairs <- function(d) {
	pids <- sort(unique(d$m[d$m > 0]))
	do.call(rbind, lapply(pids, function(p) {
		i <- which(d$m == p); it <- i[d$w[i] == 1]; ic <- i[d$w[i] == 0]
		list(xd = d$X[it, ] - d$X[ic, ], yT = d$y[it], yC = d$y[ic])
	}))
}

test_that("basic match data: pair differences (treated - control), pair outcomes and the reservoir", {
	d <- kk_data()
	r <- Z(".compute_kk_basic_match_data")(d$X, d$n, d$y, d$w, d$m)
	rp <- ref_pairs(d)
	expect_equal(r$m, 3L)
	expect_equal(unname(r$X_matched_diffs), unname(do.call(rbind, rp[, "xd"])), tolerance = 1e-12)
	expect_equal(as.numeric(r$yTs_matched), unlist(rp[, "yT"]), tolerance = 1e-12)
	expect_equal(as.numeric(r$yCs_matched), unlist(rp[, "yC"]), tolerance = 1e-12)
	expect_equal(as.numeric(r$y_matched_diffs), unlist(rp[, "yT"]) - unlist(rp[, "yC"]), tolerance = 1e-12)
	res <- which(d$m == 0)
	expect_equal(unname(r$X_reservoir), unname(d$X[res, ]), tolerance = 1e-12)
	expect_equal(as.numeric(r$y_reservoir), d$y[res])
	expect_equal(as.integer(r$w_reservoir), as.integer(d$w[res]))
	expect_equal(c(r$nRT, r$nRC), c(sum(d$w[res] == 1), sum(d$w[res] == 0)))
	# NULL or NA match ids mean everything is reservoir.
	r0 <- Z(".compute_kk_basic_match_data")(d$X, d$n, d$y, d$w, NULL)
	expect_equal(r0$m, 0L); expect_equal(nrow(r0$X_reservoir), d$n)
	mna <- d$m; mna[mna == 0] <- NA
	expect_equal(Z(".compute_kk_basic_match_data")(d$X, d$n, d$y, d$w, mna)$m, 3L)
})

test_that("lin match data adds pair covariate means and agrees with the basic decomposition", {
	d <- kk_data()
	l <- Z(".compute_kk_lin_basic_match_data")(d$X, d$n, d$y, d$w, d$m)
	b <- Z(".compute_kk_basic_match_data")(d$X, d$n, d$y, d$w, d$m)
	expect_equal(l$X_matched_diffs_full, b$X_matched_diffs_full)
	expect_equal(l$y_matched_diffs, b$y_matched_diffs)
	pids <- 1:3
	means <- t(vapply(pids, function(p) colMeans(d$X[d$m == p, ]), numeric(2)))
	expect_equal(unname(l$X_matched_means_full), unname(means), tolerance = 1e-12)
	expect_equal(l$m, 3L)
	expect_equal(l$X_reservoir, b$X_reservoir)
})

test_that("cached variant: fills the design cache only for the design's own m, reuses it, and matches a fresh computation", {
	d <- kk_data()
	des <- new.env(); des$m <- d$m
	priv <- new.env()
	cached <- Z(".compute_kk_basic_match_data_cached")
	first <- cached(priv, des, d$X, d$n, d$y, d$w, d$m)
	expect_false(is.null(des$xm_structural))
	expect_equal(des$xm_m_vec, as.integer(d$m))
	expect_equal(names(des$xm_structural), c("m", "X_matched_diffs", "X_matched_diffs_full", "X_reservoir"))
	expect_equal(first, Z(".compute_kk_basic_match_data")(d$X, d$n, d$y, d$w, d$m))

	# New responses and assignments (permutation-style call): structural part reused, y / w parts recomputed.
	set.seed(9)
	y2 <- rnorm(d$n); w2 <- c(1, 0, 0, 1, 1, 0, 1, 0, 0, 1)
	des$xm_structural$X_matched_diffs[1, 1] <- 12345                        # sentinel: proves the cached copy is what is returned
	again <- cached(priv, des, d$X, d$n, y2, w2, d$m)
	expect_equal(again$X_matched_diffs[1, 1], 12345)
	expect_equal(again$m, 3L)
	fresh <- Z(".compute_kk_basic_match_data")(d$X, d$n, y2, w2, d$m)
	expect_equal(as.numeric(again$y_matched_diffs), as.numeric(fresh$y_matched_diffs), tolerance = 1e-12)
	expect_equal(as.numeric(again$yTs_matched), as.numeric(fresh$yTs_matched), tolerance = 1e-12)
})

test_that("cached variant does not write a bootstrap resample's structure into the design cache", {
	d <- kk_data()
	des <- new.env(); des$m <- d$m
	m_b <- c(1, 1, 2, 2, 0, 0, 0, 0, 0, 0)
	res <- Z(".compute_kk_basic_match_data_cached")(new.env(), des, d$X, d$n, d$y, d$w, m_b)
	expect_null(des$xm_structural)
	expect_equal(res$m, 2L)
	# With no design environment at all the call just computes.
	expect_equal(Z(".compute_kk_basic_match_data_cached")(new.env(), NULL, d$X, d$n, d$y, d$w, d$m)$m, 3L)
	# A cache built for a different column count is ignored (recomputed).
	des2 <- new.env(); des2$m <- d$m
	Z(".compute_kk_basic_match_data_cached")(new.env(), des2, d$X, d$n, d$y, d$w, d$m)
	X3 <- cbind(d$X, c = rnorm(d$n))
	out <- Z(".compute_kk_basic_match_data_cached")(new.env(), des2, X3, d$n, d$y, d$w, d$m)
	expect_equal(ncol(out$X_reservoir), 3L)
})

test_that("lin cached variant mirrors the same caching contract", {
	d <- kk_data()
	des <- new.env(); des$m <- d$m
	cached <- Z(".compute_kk_lin_basic_match_data_cached")
	first <- cached(new.env(), des, d$X, d$n, d$y, d$w, d$m)
	expect_equal(names(des$lin_xm_structural), c("m", "X_matched_diffs_full", "X_matched_means_full", "X_reservoir"))
	expect_equal(first, Z(".compute_kk_lin_basic_match_data")(d$X, d$n, d$y, d$w, d$m))
	y2 <- rnorm(d$n)
	again <- cached(new.env(), des, d$X, d$n, y2, d$w, d$m)
	fresh <- Z(".compute_kk_lin_basic_match_data")(d$X, d$n, y2, d$w, d$m)
	expect_equal(as.numeric(again$y_matched_diffs), as.numeric(fresh$y_matched_diffs), tolerance = 1e-12)
	expect_equal(again$X_matched_means_full, fresh$X_matched_means_full)
	other <- new.env(); other$m <- rep(NA_integer_, d$n)
	cached(new.env(), other, d$X, d$n, d$y, d$w, d$m)
	expect_null(other$lin_xm_structural)
})
