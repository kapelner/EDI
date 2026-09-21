library(testthat)
library(EDI)

# InferenceNonParamBoot$ci_bca() / pval_bca() (jackknife-fed wrappers) and the shared
# bca_ci_core() / bca_pval_core() math. Independent BCa reference: bias z0 = qnorm(P(boot < est)),
# acceleration from the jackknife third/second moments, adjusted percentiles
# pnorm(z0 + (z0 + z_a) / (1 - a (z0 + z_a))) read with quantile(type = 8); p-value
# 2 * min(Phi(adj), 1 - Phi(adj)) with adj = s / (1 + a s) - z0. Jackknife draws are stubbed.
# Unstable / boundary / unavailable-jackknife branches return NA and record the reason.

fx <- function(jack) {
	set.seed(3)
	n <- 30L
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE, seed = 3L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", p)
	p$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack
	list(inf = inf, p = p)
}
ref_ci <- function(boot, jack, est, alpha) {
	z0 <- qnorm(mean(boot < est)); jb <- mean(jack)
	a <- sum((jb - jack)^3) / (6 * sum((jb - jack)^2)^1.5)
	adj <- pnorm(z0 + (z0 + qnorm(c(alpha / 2, 1 - alpha / 2))) / (1 - a * (z0 + qnorm(c(alpha / 2, 1 - alpha / 2)))))
	quantile(boot, adj, type = 8, names = FALSE)
}
ref_p <- function(boot, jack, est, delta) {
	z0 <- qnorm(mean(boot < est)); jb <- mean(jack)
	a <- sum((jb - jack)^3) / (6 * sum((jb - jack)^2)^1.5)
	s <- qnorm(mean(boot < delta)) - z0
	adj <- s / (1 + a * s) - z0
	min(1, max(2 / length(boot), 2 * min(pnorm(adj), 1 - pnorm(adj))))
}
set.seed(5)
boot <- rnorm(400, 0.5, 0.3)
jack <- rnorm(30, 0.5, 0.1)
est <- 0.5

test_that("ci_bca reproduces the hand-computed BCa interval for several alphas", {
	f <- fx(jack)
	for (alpha in c(0.05, 0.1, 0.2)) {
		expect_equal(f$p$ci_bca(boot, alpha, est), ref_ci(boot, jack, est, alpha), tolerance = 1e-9, info = alpha)
	}
})

test_that("pval_bca reproduces the hand-computed BCa p-value, is floored at 2 / B, and is symmetric-ish about the centre", {
	f <- fx(jack)
	for (delta in c(-0.2, 0.2, 0.45, 0.9)) {
		expect_equal(f$p$pval_bca(boot, est, delta), ref_p(boot, jack, est, delta), tolerance = 1e-9, info = delta)
	}
	expect_equal(f$p$pval_bca(boot, est, -0.4), 2 / length(boot))         # far in the lower tail: hits the 2 / B floor
	expect_lte(f$p$pval_bca(boot, est, -0.4), f$p$pval_bca(boot, est, -0.2))
	expect_true(is.na(f$p$pval_bca(boot, est, 5)))                        # beyond every draw: |adj z| > 8 -> unstable
})

test_that("non-finite jackknife draws are dropped; fewer than two usable ones make the result NA with a reason", {
	f <- fx(c(jack, NA, Inf))
	expect_equal(f$p$ci_bca(boot, 0.05, est), ref_ci(boot, jack, est, 0.05), tolerance = 1e-9)
	g <- fx(0.5)
	expect_equal(g$p$ci_bca(boot, 0.05, est), c(NA_real_, NA_real_))
	expect_equal(g$p$cached_values$nonestimable_reason, "bootstrap_bca_jackknife_unavailable")
	h <- fx(c(0.5, NA))
	expect_true(is.na(h$p$pval_bca(boot, est, 0.2)))
	expect_equal(h$p$cached_values$nonestimable_reason, "bootstrap_bca_jackknife_unavailable")
})

test_that("a block-size > 1 jackknife that is unsupported gets its own reason", {
	f <- fx(numeric(0))
	unlockBinding("jackknife_block_size_gt_one_unsupported", f$p)
	f$p$jackknife_block_size_gt_one_unsupported <- function(unit = "auto") TRUE
	expect_true(all(is.na(f$p$ci_bca(boot, 0.05, est))))
	expect_equal(f$p$cached_values$nonestimable_reason, "jackknife_block_size_gt_one_not_supported")
})

test_that("core: extreme bias (|z0| > 2.5) or acceleration (|a| > 1) is unstable; boundary adjustments are rejected", {
	f <- fx(jack)
	fail <- function(reason) reason
	ci_core <- function(b, e, j) f$p$bca_ci_core(b, 0.05, e, j, "bca_", fail)
	# All bootstrap draws above the estimate: z0 = qnorm(eps) is huge negative.
	expect_equal(ci_core(boot + 5, est, jack), "bca_unstable_bias_or_acceleration")
	# Modest acceleration but a tiny bootstrap sample pushes adjusted probabilities to the boundary.
	tiny <- c(0.1, 0.2, 0.3, 0.4, 0.6, 0.7)
	expect_equal(ci_core(tiny, 0.5, jack), "bca_adjustment_on_boundary")
	expect_equal(f$p$bca_pval_core(boot + 5, est, 0.2, jack, "bca_", fail), "bca_unstable_bias_or_acceleration")
	expect_equal(f$p$bca_pval_core(tiny, 0.5, 0.2, jack, "bca_", fail), "bca_adjustment_on_boundary")
})

test_that("core p-value: a delta below every draw saturates at the 2 / B floor", {
	f <- fx(jack)
	out <- f$p$bca_pval_core(boot, est, min(boot) - 1, jack, "bca_", function(reason) reason)
	expect_equal(out, 2 / length(boot))
})
