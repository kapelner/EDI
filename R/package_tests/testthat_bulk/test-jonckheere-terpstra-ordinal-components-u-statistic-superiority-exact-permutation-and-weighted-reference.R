library(testthat)
library(EDI)

# InferenceOrdinalJonckheereTerpstraTest private components: compute_asymptotic_jt_components (Mann-Whitney U with mid-ranks ties,
# superiority = U / (nT nC), beta = superiority - 1/2, no-tie-correction null variance nT nC (nT + nC + 1) / 12),
# compute_exact_jt_components (exact permutation p-values: upper / lower tail and doubled minimum), weighted_superiority (weighted
# pairwise concordance with half credit for ties). References: stats::wilcox.test U, brute-force enumeration of all assignments, hand sums.

mk <- function(y, w, n = length(y)) {
	d <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n))); d$assign_w_to_all_subjects()
	d$overwrite_all_subject_assignments(as.integer(w))
	d$add_all_subject_responses(factor(y, levels = sort(unique(y)), ordered = TRUE))
	inf <- InferenceOrdinalJonckheereTerpstraTest$new(d, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, y = as.integer(factor(y, levels = sort(unique(y)))), w = as.integer(w))
}
set.seed(4); n <- 40L
w40 <- rep(0:1, length.out = n); y40 <- pmin(4, pmax(1, round(rnorm(n, 2.2 + 0.6 * w40, 1))))
f <- mk(y40, w40)

test_that("asymptotic components: U equals the Mann-Whitney W, superiority and beta follow, SE uses the no-tie-correction variance", {
	f$p$compute_asymptotic_jt_components()
	cv <- f$p$cached_values
	nT <- sum(f$w == 1); nC <- sum(f$w == 0)
	W <- unname(wilcox.test(f$y[f$w == 1], f$y[f$w == 0], exact = FALSE)$statistic)
	expect_equal(cv$jt_u_stat, W); expect_equal(cv$superiority, W / (nT * nC)); expect_equal(cv$beta_hat_T, W / (nT * nC) - 0.5)
	expect_identical(cv$jt_n_treat, nT); expect_identical(cv$jt_n_control, nC)
	expect_equal(cv$s_beta_hat_T, sqrt(nT * nC * (nT + nC + 1) / 12) / (nT * nC), tolerance = 1e-12)
	expect_true(is.na(cv$df))
})

test_that("class estimate, asymptotic p-value and CI use those components", {
	nT <- sum(f$w == 1); nC <- sum(f$w == 0)
	W <- unname(wilcox.test(f$y[f$w == 1], f$y[f$w == 0], exact = FALSE)$statistic)
	z <- (W - nT * nC / 2) / sqrt(nT * nC * (nT + nC + 1) / 12)
	g <- mk(y40, w40)
	expect_equal(g$inf$compute_estimate(), W / (nT * nC) - 0.5, tolerance = 1e-12)
	expect_equal(g$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(z)), tolerance = 1e-8)
	ci <- g$inf$compute_asymp_confidence_interval(0.05)
	se <- sqrt(nT * nC * (nT + nC + 1) / 12) / (nT * nC)
	expect_equal(unname(ci), (W / (nT * nC) - 0.5) + c(-1, 1) * qnorm(0.975) * se, tolerance = 1e-8)
})

test_that("estimate-only mode caches the point estimate without the variance; an empty arm is nonestimable", {
	g <- mk(y40, w40); g$p$compute_asymptotic_jt_components(estimate_only = TRUE)
	expect_false(is.null(g$p$cached_values$beta_hat_T)); expect_null(g$p$cached_values$s_beta_hat_T)
	h <- mk(y40, rep(1L, n)); h$p$compute_asymptotic_jt_components()
	expect_true(is.na(h$p$cached_values$beta_hat_T)); expect_true(isTRUE(h$inf$is_nonestimable("estimate")))
})

test_that("exact permutation p-values equal brute-force enumeration over all assignments (small tied sample)", {
	y <- c(1, 1, 2, 2, 2, 3, 3, 4, 1, 3); w <- c(1, 0, 1, 0, 0, 1, 0, 1, 0, 1)
	g <- mk(y, w); g$p$compute_exact_jt_components()
	yi <- g$y; nT <- sum(w); n <- length(y)
	U <- function(ww) { t <- yi[ww == 1]; cc <- yi[ww == 0]; sum(outer(t, cc, ">") + 0.5 * outer(t, cc, "==")) }
	obs <- U(w)
	all_u <- apply(combn(n, nT), 2, function(i) { ww <- integer(n); ww[i] <- 1L; U(ww) })
	p_up <- mean(all_u >= obs - 1e-9); p_lo <- mean(all_u <= obs + 1e-9)
	cv <- g$p$cached_values
	expect_equal(cv$p_upper, p_up, tolerance = 1e-10); expect_equal(cv$p_lower, p_lo, tolerance = 1e-10)
	expect_equal(cv$p_exact, min(1, 2 * min(p_up, p_lo)), tolerance = 1e-10)
	expect_equal(cv$superiority, obs / (nT * (n - nT)), tolerance = 1e-12); expect_equal(cv$beta_hat_T, obs / (nT * (n - nT)) - 0.5, tolerance = 1e-12)
	expect_equal(cv$jt_stat2, 2 * obs, tolerance = 1e-10)
	before <- cv$p_exact; g$p$compute_exact_jt_components(); expect_identical(g$p$cached_values$p_exact, before)          # cached
})

test_that("weighted superiority: weighted share of treated-above-control pairs with half credit for ties; unit weights give the plain value", {
	y <- c(1, 2, 2, 3, 1, 3, 2, 4); w <- c(1, 1, 0, 0, 1, 0, 0, 1); n <- length(y)
	g <- mk(y, w)
	rw <- c(0.5, 2, 1, 1.5, 1, 0.25, 3, 1)
	it <- which(w == 1); ic <- which(w == 0)
	comp <- outer(y[it], y[ic], ">") + 0.5 * outer(y[it], y[ic], "==")
	wp <- outer(rw[it], rw[ic], "*")
	expect_equal(g$p$weighted_superiority(y, w, rw), sum(comp * wp) / sum(wp), tolerance = 1e-12)
	expect_equal(g$p$weighted_superiority(y, w, rep(1, n)), mean(comp), tolerance = 1e-12)
	expect_equal(g$p$weighted_superiority(y, w, 5 * rw), g$p$weighted_superiority(y, w, rw), tolerance = 1e-12)        # scale-free
	rn <- rw; rn[2] <- NA                                             # a non-finite weight drops that subject
	expect_equal(g$p$weighted_superiority(y, w, rn), {ii <- setdiff(it, 2); cc <- outer(y[ii], y[ic], ">") + 0.5 * outer(y[ii], y[ic], "=="); sum(cc * outer(rw[ii], rw[ic])) / sum(outer(rw[ii], rw[ic]))}, tolerance = 1e-12)
	expect_true(is.na(g$p$weighted_superiority(y, w, ifelse(w == 1, 0, 1)))); expect_true(is.na(g$p$weighted_superiority(y, rep(1L, n), rw)))
})
