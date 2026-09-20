library(testthat)
library(EDI)

# InferenceAllSimpleWilcox's private hl_point_estimate() (unweighted C++ path and
# the weighted R branch used by weighted resampling), its shared() estimate-only
# and full paths (SE back-solved from wilcox.test's CI width), and the stale
# compute_fast_bootstrap_distr() helper. References are from-scratch pairwise
# differences and stats::wilcox.test.

wilcox_fixture <- function(seed = 3L, n = 20L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, y = y, n = n)
}

ref_weighted_hl <- function(y, w, wt) {
	it <- which(w == 1 & is.finite(y) & is.finite(wt) & wt > 0)
	ic <- which(w == 0 & is.finite(y) & is.finite(wt) & wt > 0)
	if (!length(it) || !length(ic)) return(NA_real_)
	d <- as.numeric(outer(y[it], y[ic], "-"))
	ww <- as.numeric(outer(wt[it], wt[ic], "*"))
	o <- order(d)
	cw <- cumsum(ww[o]) / sum(ww)
	d[o][which(cw >= 0.5)[1L]]
}

test_that("unweighted hl_point_estimate is the median of all treated-minus-control differences", {
	f <- wilcox_fixture()
	ref <- median(outer(f$y[f$w == 1], f$y[f$w == 0], "-"))
	expect_equal(f$priv$hl_point_estimate(f$y, f$w), ref, tolerance = 1e-12)
	expect_equal(f$inf$compute_estimate(), ref, tolerance = 1e-12)
})

test_that("weighted hl_point_estimate equals the independent weighted median of pairwise differences", {
	f <- wilcox_fixture()
	set.seed(4)
	wt <- runif(f$n, 0.3, 2)
	expect_equal(f$priv$hl_point_estimate(f$y, f$w, wt), ref_weighted_hl(f$y, f$w, wt), tolerance = 1e-12)
	# Unit weights select the lower weighted median of the differences.
	d <- sort(as.numeric(outer(f$y[f$w == 1], f$y[f$w == 0], "-")))
	expect_equal(f$priv$hl_point_estimate(f$y, f$w, rep(1, f$n)), d[ceiling(length(d) / 2)], tolerance = 1e-12)
	# A dominant weight on one treated/control pair pulls the estimate to that difference.
	wt2 <- rep(1e-6, f$n)
	it <- which(f$w == 1)[1]; ic <- which(f$w == 0)[1]
	wt2[c(it, ic)] <- 1e3
	expect_equal(f$priv$hl_point_estimate(f$y, f$w, wt2), f$y[it] - f$y[ic], tolerance = 1e-12)
})

test_that("weighted hl_point_estimate returns NA for empty arms, dropped weights and non-finite inputs", {
	f <- wilcox_fixture()
	wt <- rep(1, f$n)
	expect_true(is.na(f$priv$hl_point_estimate(f$y, rep(1L, f$n), wt)))
	expect_true(is.na(f$priv$hl_point_estimate(f$y, f$w, rep(0, f$n))))
	wt_no_control <- ifelse(f$w == 0, 0, 1)
	expect_true(is.na(f$priv$hl_point_estimate(f$y, f$w, wt_no_control)))
	wt_na <- rep(NA_real_, f$n)
	expect_true(is.na(f$priv$hl_point_estimate(f$y, f$w, wt_na)))
	# Non-finite responses are ignored, not propagated.
	y_bad <- f$y; y_bad[which(f$w == 1)[1]] <- NA
	expect_equal(f$priv$hl_point_estimate(y_bad, f$w, wt), ref_weighted_hl(y_bad, f$w, wt), tolerance = 1e-12)
})

test_that("shared() caches only the estimate for estimate_only and back-solves the SE from wilcox.test's CI otherwise", {
	f <- wilcox_fixture()
	f$priv$shared(estimate_only = TRUE)
	expect_true(is.finite(f$priv$cached_values$beta_hat_T))
	expect_null(f$priv$cached_values$s_beta_hat_T)

	f$priv$shared()
	tt <- stats::wilcox.test(f$y[f$w == 1], f$y[f$w == 0], conf.int = TRUE, exact = FALSE)
	expect_equal(f$priv$cached_values$s_beta_hat_T, diff(tt$conf.int) / (2 * 1.96), tolerance = 1e-8)
	expect_equal(f$priv$cached_values$wilcox_asymp_pval, tt$p.value, tolerance = 1e-10)
	expect_equal(f$priv$cached_values$wilcox_conf_int, as.numeric(tt$conf.int), tolerance = 1e-8)
})

test_that("an empty treatment arm makes both shared() paths nonestimable", {
	f <- wilcox_fixture()
	f$priv$w <- rep(0L, f$n)
	f$priv$shared(estimate_only = TRUE)
	expect_true(f$inf$is_nonestimable("estimate"))
	f2 <- wilcox_fixture()
	f2$priv$w <- rep(0L, f2$n)
	f2$priv$shared()
	expect_true(f2$inf$is_nonestimable("estimate"))
})

test_that("compute_fast_bootstrap_distr opts out (NULL) instead of inheriting the mean-difference kernel", {
	f <- wilcox_fixture()
	expect_null(f$priv$compute_fast_bootstrap_distr(3, 10L, rnorm(10), rep(1, 10), c(1, rep(0, 9))))
})
