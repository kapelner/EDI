library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d80cfb962 (InferencePropKKQuantileRegrIVWC,
# inference_proportion_KK_quantile_regr_ivwc.R): default tau = 0.5 (:19); any tau strictly in (0, 1) is
# accepted, 0 and 1 rejected (:26); asymptotic z-based inference (:29); requires quantreg (:31); median
# regressions on logit-scale pair differences and on logit(y) in the reservoir, combined by the
# OLS-compound inverse-variance weighting (:4). The nearest existing tests cover the continuous sibling
# or compare only with the legacy class.

skip_if_not_installed("quantreg")

prop_kk_qr_fixture <- function() {
	set.seed(4)
	n <- 120L
	des <- DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	mu <- plogis(-0.2 + 0.5 * w + 0.4 * X$x)
	y <- rbeta(n, mu * 4, (1 - mu) * 4)
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	pr <- d[d$m > 0, ]
	dd <- t(vapply(sort(unique(pr$m)), function(k) {
		a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]
		c(qlogis(t1$y) - qlogis(t0$y), t1$x - t0$x)
	}, numeric(2)))
	list(des = des, d = d, yd = dd[, 1], xd = dd[, 2], res = d[d$m == 0, ])
}

test_that("default tau is 0.5: same estimate as explicit tau = 0.5, different from tau = 0.25", {
	f <- prop_kk_qr_fixture()
	inf <- InferencePropKKQuantileRegrIVWC$new(f$des)
	expect_identical(inf$.__enclos_env__$private$tau, 0.5)
	est <- inf$compute_estimate()
	expect_identical(est, InferencePropKKQuantileRegrIVWC$new(f$des, tau = 0.5)$compute_estimate())
	expect_gt(abs(est - InferencePropKKQuantileRegrIVWC$new(f$des, tau = 0.25)$compute_estimate()), 1e-3)
})

test_that("tau = 0 and tau = 1 are rejected; tau = 0.25 and 0.75 give finite estimates", {
	f <- prop_kk_qr_fixture()
	expect_error(InferencePropKKQuantileRegrIVWC$new(f$des, tau = 0), "tau")
	expect_error(InferencePropKKQuantileRegrIVWC$new(f$des, tau = 1), "tau")
	expect_true(is.finite(InferencePropKKQuantileRegrIVWC$new(f$des, tau = 0.25)$compute_estimate()))
	expect_true(is.finite(InferencePropKKQuantileRegrIVWC$new(f$des, tau = 0.75)$compute_estimate()))
})

test_that("asymptotic CI and p-value use a z reference: estimate +/- qnorm(1 - alpha/2) * se and 2 * pnorm(-|z|)", {
	f <- prop_kk_qr_fixture()
	inf <- InferencePropKKQuantileRegrIVWC$new(f$des)
	est <- inf$compute_estimate()
	ci <- inf$compute_asymp_confidence_interval(alpha = 0.1)
	pval <- inf$compute_asymp_two_sided_pval()
	se <- inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
	expect_equal(unname(ci), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-10)
	expect_equal(pval, 2 * pnorm(-abs(est / se)), tolerance = 1e-10)
})

test_that("InferencePropKKQuantileRegrIVWC errors with the quantreg message when quantreg is (mocked as) unavailable", {
	f <- prop_kk_qr_fixture()
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = expect_error(
			InferencePropKKQuantileRegrIVWC$new(f$des, verbose = FALSE),
			"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
			fixed = TRUE
		)
	)
})

test_that("estimate is the inverse-variance combination of rq on logit pair differences and rq on logit(y) in the reservoir", {
	f <- prop_kk_qr_fixture()
	expect_gt(nrow(f$res), 3L)
	fit_m <- suppressWarnings(quantreg::rq(f$yd ~ f$xd, tau = 0.5))
	s_m <- suppressWarnings(summary(fit_m, se = "nid"))$coefficients[1, 1:2]
	fit_r <- suppressWarnings(quantreg::rq(qlogis(f$res$y) ~ f$res$w + f$res$x, tau = 0.5))
	s_r <- suppressWarnings(summary(fit_r, se = "nid"))$coefficients[2, 1:2]
	w_star <- s_r[[2]]^2 / (s_r[[2]]^2 + s_m[[2]]^2)
	ref_est <- w_star * s_m[[1]] + (1 - w_star) * s_r[[1]]
	ref_se <- sqrt(s_m[[2]]^2 * s_r[[2]]^2 / (s_m[[2]]^2 + s_r[[2]]^2))

	inf <- InferencePropKKQuantileRegrIVWC$new(f$des)
	expect_equal(inf$compute_estimate(), ref_est, tolerance = 1e-8)
	inf$compute_asymp_confidence_interval()
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, ref_se, tolerance = 1e-8)
	# both pieces matter (neither weight is 0 or 1)
	expect_true(w_star > 0.05 && w_star < 0.95)
})
