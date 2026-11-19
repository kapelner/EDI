library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dc3d122d8 (InferencePropKKQuantileRegrOneLik,
# inference_proportion_KK_quantile_regr_one_lik.R): standard errors use Powell's sandwich ("nid") (:13);
# requires quantreg (:16); tau strictly between 0 and 1 (:91). The nearest existing tests cover only the
# shared SE helper or the continuous sibling. Stacked logit-scale fixture as in
# test-proportion-kk-classes-match-logit-stacked-quantile-and-quasibinomial-references.R.

skip_if_not_installed("quantreg")

prop_kk_onelik_fixture <- function() {
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
	res <- d[d$m == 0, ]
	list(des = des, Xs = rbind(cbind(0, 1, dd[, 2]), cbind(1, res$w, res$x)), ys = c(dd[, 1], qlogis(res$y)))
}

test_that("SE, asymptotic CI and p-value use the Powell 'nid' sandwich SE of the stacked rq fit", {
	f <- prop_kk_onelik_fixture()
	Xs <- f$Xs
	ys <- f$ys
	fit <- suppressWarnings(quantreg::rq(ys ~ Xs - 1, tau = 0.5))
	ref <- suppressWarnings(summary(fit, se = "nid"))$coefficients[2, ]
	inf <- InferencePropKKQuantileRegrOneLik$new(f$des)
	est <- inf$compute_estimate()
	ci <- inf$compute_asymp_confidence_interval(alpha = 0.1)
	pval <- inf$compute_asymp_two_sided_pval()
	se <- inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	expect_equal(est, unname(ref[1]), tolerance = 1e-6)
	expect_equal(se, unname(ref[2]), tolerance = 1e-6)
	# not the iid SE
	iid <- suppressWarnings(summary(fit, se = "iid"))$coefficients[2, 2]
	expect_gt(abs(se - iid), 1e-4)
	expect_equal(unname(ci), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-8)
	expect_equal(pval, 2 * pnorm(-abs(est / se)), tolerance = 1e-8)
})

test_that("InferencePropKKQuantileRegrOneLik errors with the quantreg message when quantreg is (mocked as) unavailable", {
	f <- prop_kk_onelik_fixture()
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = expect_error(
			InferencePropKKQuantileRegrOneLik$new(f$des, verbose = FALSE),
			"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
			fixed = TRUE
		)
	)
})

test_that("tau = 0 and 1 are rejected; tau = 0.75 matches the stacked rq at tau = 0.75", {
	f <- prop_kk_onelik_fixture()
	expect_error(InferencePropKKQuantileRegrOneLik$new(f$des, tau = 0), "tau")
	expect_error(InferencePropKKQuantileRegrOneLik$new(f$des, tau = 1), "tau")
	Xs <- f$Xs
	ys <- f$ys
	ref <- unname(suppressWarnings(coef(quantreg::rq(ys ~ Xs - 1, tau = 0.75)))[2])
	est <- InferencePropKKQuantileRegrOneLik$new(f$des, tau = 0.75)$compute_estimate()
	expect_equal(est, ref, tolerance = 1e-6)
	expect_gt(abs(est - InferencePropKKQuantileRegrOneLik$new(f$des)$compute_estimate()), 1e-3)
})
