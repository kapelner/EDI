library(testthat)
library(EDI)

# v1.0.6-TODO-285: the hull scan of the Zhang exact CI (zhang_ci_hull_endpoint()) evaluates the
# minimum-likelihood p-value of each component at many deltas with zhang_minlike_pval_vec_cpp(), and
# its scan cut uses the tail bound kernels zhang_pval_exact_tail_bound_cpp() / zhang_hull_scan_cut_cpp().
# They replaced R code (an outcomes x deltas matrix, and an R bisection on an R bound) and must give
# the same doubles, so the CI endpoints do not move. The R references below are those replaced
# versions, verbatim. The vector kernel must also agree with the scalar kernels the endpoints are
# refined with, within the "rel_err" bound that lets the endpoint snap take its accept/reject
# decisions from the vector p-value (zhang_accepts_certified()).

ref_minlike <- function(comp, deltas) {
	rel_tol_log <- log1p(1e-7)
	logw <- comp$cj + outer(seq_along(comp$cj) - 1L, deltas)
	K <- nrow(logw)
	mx <- logw[cbind(max.col(t(logw), ties.method = "first"), seq_len(ncol(logw)))]
	e <- exp(logw - rep(mx, each = K))
	keep <- logw <= rep(logw[comp$x, ] + rel_tol_log, each = K)
	pmin(1, colSums(e * keep) / colSums(e))
}

ref_bound <- function(comp, delta, direction) {
	K <- length(comp$cj)
	x <- comp$x
	lw <- comp$cj + (seq_len(K) - 1L) * delta
	mode <- which.max(lw)
	if (direction * (mode - x) < 0) return(1)
	e <- exp(lw - lw[mode])
	side <- if (direction > 0) seq_len(x) else x:K
	n_other <- if (direction > 0) K - x else x - 1L
	min(1, sum(e[side]) / sum(e) * (1 + n_other * (1 + 1e-7)) * (1 + 1e-6))
}

ref_combined_bound <- function(comps, delta, direction, st, cm) {
	bM <- if (is.null(comps$M)) NA_real_ else ref_bound(comps$M, delta, direction)
	bR <- if (is.null(comps$R)) NA_real_ else ref_bound(comps$R, delta, direction)
	g <- EDI:::zhang_combine_exact_pvals(bM, bR, st$m, st$nRT, st$nRC, cm)
	max(c(g, bM, bR), na.rm = TRUE)
}

ref_cut <- function(p_bound, r, t_far, direction, pval_th, n_iter = 12L) {
	if (p_bound(t_far, direction) >= pval_th) return(t_far)
	lo <- r
	hi <- t_far
	for (iter in seq_len(n_iter)) {
		mid <- (lo + hi) / 2
		if (p_bound(mid, direction) >= pval_th) lo <- mid else hi <- mid
	}
	hi
}

# Random exact tables: matched-pair discordant counts and a reservoir 2x2 table, as
# zhang_get_exact_stats() returns them; sometimes without one of the two components.
random_stats <- function(s) {
	k <- sample(c(1:15, 60, 400), 1)
	dp <- sample(0:k, 1)
	r1 <- sample(c(1:40, 500), 1)
	r2 <- sample(c(1:40, 500), 1)
	c1 <- sample(seq_len(r1 + r2 - 1L), 1)
	n11 <- sample(max(0L, c1 - r2):min(r1, c1), 1)
	list(m = if (s %% 5L == 0L) 0L else k + 2L, d_plus = dp, d_minus = k - dp,
		nRT = if (s %% 7L == 0L) 0L else r1, nRC = r2,
		n11 = n11, n01 = r1 - n11, n10 = c1 - n11, n00 = r2 - (c1 - n11))
}

test_that("the vector kernel gives the replaced R matrix values bit for bit", {
	set.seed(2851)
	for (s in 1:300) {
		st <- random_stats(s)
		comps <- EDI:::zhang_exact_pval_components(st)
		bp <- EDI:::zhang_exact_pval_breakpoints(st, comps)
		d <- c(runif(40, -8, 8), rnorm(20, 0, 0.2), sample(bp, min(10L, length(bp))), -900, 900, 0)
		for (comp in Filter(Negate(is.null), comps)) {
			expect_identical(EDI:::zhang_minlike_pval_vec_cpp(comp$cj, comp$x, d), ref_minlike(comp, d))
		}
	}
})

test_that("the vector kernel matches the scalar binomial and Fisher kernels, ties at breakpoints included", {
	set.seed(2852)
	for (s in 1:60) {
		st <- random_stats(s)
		comps <- EDI:::zhang_exact_pval_components(st)
		bp <- EDI:::zhang_exact_pval_breakpoints(st, comps)
		d <- c(seq(-4, 4, length.out = 41), sample(bp, min(15L, length(bp))))
		if (!is.null(comps$M)) {
			expect_equal(EDI:::zhang_minlike_pval_vec_cpp(comps$M$cj, comps$M$x, d),
				vapply(d, function(z) EDI:::zhang_exact_binom_pval_cpp(st$d_plus, st$d_minus, z), numeric(1)),
				tolerance = 1e-12)
		}
		if (!is.null(comps$R)) {
			expect_equal(EDI:::zhang_minlike_pval_vec_cpp(comps$R$cj, comps$R$x, d),
				vapply(d, function(z) EDI:::zhang_exact_fisher_pval_cpp(st$n11, st$n10, st$n01, st$n00, z), numeric(1)),
				tolerance = 1e-12)
		}
	}
})

test_that("the vector kernel returns NA for a non-finite delta or an observed index out of range", {
	cj <- lchoose(6, 0:6)
	expect_identical(EDI:::zhang_minlike_pval_vec_cpp(cj, 3L, c(NA_real_, Inf, -Inf, NaN)), rep(NA_real_, 4))
	expect_identical(EDI:::zhang_minlike_pval_vec_cpp(cj, 0L, 0.5), NA_real_)
	expect_identical(EDI:::zhang_minlike_pval_vec_cpp(cj, 8L, 0.5), NA_real_)
	expect_identical(EDI:::zhang_minlike_pval_vec_cpp(cj, 3L, numeric(0)), numeric(0))
})

test_that("the tail bound and the scan cut give the replaced R values bit for bit", {
	set.seed(2853)
	for (s in 1:200) {
		st <- random_stats(s)
		comps <- EDI:::zhang_exact_pval_components(st)
		if (is.null(comps$M) && is.null(comps$R)) next
		for (comp in Filter(Negate(is.null), comps)) for (dd in runif(4, -6, 6)) for (dir in c(-1, 1)) {
			expect_identical(EDI:::zhang_minlike_tail_bound_cpp(comp$cj, comp$x, dd, dir), ref_bound(comp, dd, dir))
		}
		for (cm in c("Fisher", "Stouffer", "min_p")) {
			p_bound <- EDI:::zhang_pval_exact_tail_bound_fn(st, cm, comps)
			for (dd in runif(4, -6, 6)) for (dir in c(-1, 1)) {
				expect_identical(p_bound(dd, dir), ref_combined_bound(comps, dd, dir, st, cm))
				expect_identical(EDI:::zhang_pval_exact_tail_bound(comps, dd, dir, st, cm), ref_combined_bound(comps, dd, dir, st, cm))
			}
			for (dir in c(-1, 1)) {
				r <- runif(1, -1, 1)
				t_far <- r + dir * runif(1, 0.5, 8)
				th <- sample(c(0.01, 0.05, 0.1), 1)
				ref <- ref_cut(function(d, di) ref_combined_bound(comps, d, di, st, cm), r, t_far, dir, th)
				expect_identical(EDI:::zhang_hull_scan_cut(p_bound, r, t_far, dir, th), ref)
				expect_identical(EDI:::zhang_hull_scan_cut(p_bound, r, t_far, dir, th, b_far = p_bound(t_far, dir)), ref)
			}
		}
	}
})

test_that("the combined tail bound is an upper bound on the combined p-value going outward", {
	set.seed(2854)
	for (s in 1:80) {
		st <- random_stats(s)
		comps <- EDI:::zhang_exact_pval_components(st)
		if (is.null(comps$M) && is.null(comps$R)) next
		for (cm in c("Fisher", "Stouffer", "min_p")) {
			p_bound <- EDI:::zhang_pval_exact_tail_bound_fn(st, cm, comps)
			d <- seq(-6, 6, length.out = 61)
			p <- EDI:::zhang_pval_exact_combined_vec(st, d, cm, comps)
			for (dir in c(-1, 1)) {
				b <- vapply(d, function(z) p_bound(z, dir), numeric(1))
				expect_true(all(b >= p))
				expect_true(all(dir * diff(b) <= 0))  # nonincreasing outward
			}
		}
	}
})

test_that("the vectorised combination equals the scalar one elementwise", {
	set.seed(2855)
	pM <- c(runif(30), 0, NA, 1e-300, 1, NaN, 0.3)
	pR <- c(runif(30), 0.2, 0.4, NA, 0, 0.5, NA)
	for (cm in c("Fisher", "Stouffer", "min_p")) for (m in c(0L, 3L)) for (nRT in c(0L, 4L)) {
		expect_identical(EDI:::zhang_combine_exact_pvals_vec(pM, pR, m, nRT, 5L, cm),
			vapply(seq_along(pM), function(i) EDI:::zhang_combine_exact_pvals(pM[i], pR[i], m, nRT, 5L, cm), numeric(1)))
	}
})

test_that("the vector p-value is within its rel_err bound of the scalar kernels, and certified decisions match them", {
	set.seed(2856)
	for (s in 1:80) {
		st <- random_stats(s)
		comps <- EDI:::zhang_exact_pval_components(st)
		if (is.null(comps$M) && is.null(comps$R)) next
		bp <- EDI:::zhang_exact_pval_breakpoints(st, comps)
		d <- c(seq(-12, 12, length.out = 49), sample(bp, min(10L, length(bp))))
		for (cm in c("Fisher", "Stouffer", "min_p")) {
			p_at <- function(z) {
				p_M <- if (!is.null(comps$M)) EDI:::zhang_exact_binom_pval_cpp(st$d_plus, st$d_minus, z) else NA_real_
				p_R <- if (!is.null(comps$R)) EDI:::zhang_exact_fisher_pval_cpp(st$n11, st$n10, st$n01, st$n00, z) else NA_real_
				p <- EDI:::zhang_combine_exact_pvals(p_M, p_R, st$m, st$nRT, st$nRC, cm)
				if (is.na(p) || !is.finite(p)) 0 else p
			}
			pv <- EDI:::zhang_pval_exact_combined_vec(st, d, cm, comps)
			ps <- vapply(d, p_at, numeric(1))
			err <- attr(pv, "rel_err")
			ok <- is.finite(err)
			expect_true(all(abs(pv[ok] - ps[ok]) <= err[ok] * pmax(ps[ok], 1e-300)))
			p_vec <- function(z) EDI:::zhang_pval_exact_combined_vec(st, z, cm, comps)
			for (th in c(0.01, 0.05, 0.1)) {
				# thresholds at the p-values themselves force the scalar fallback
				for (t in c(th, pv[sample(length(pv), 3)])) if (t > 0) {
					expect_identical(EDI:::zhang_accepts_certified(p_at, p_vec, d, t), ps >= t)
				}
			}
		}
	}
})
