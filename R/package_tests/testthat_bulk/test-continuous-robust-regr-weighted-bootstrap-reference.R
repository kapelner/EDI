library(testthat)
library(EDI)

# InferenceContinRobustRegr had zero test-file references anywhere in the
# suite prior to this file (confirmed via repo-wide grep), despite having
# both an rcpp and an MASS::rlm backend and a documented weighted-bootstrap
# reproduction of rlm's wt.method = "inv.var" scheme.

make_robust_regr_fixture <- function(seed = 42, n = 80L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	x1 <- rnorm(n)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w <- des$get_w()
	y <- 2 + 1.5 * w + 0.7 * x1 + rnorm(n, sd = 1)
	y[1:3] <- y[1:3] + 20  # heavy-tailed outliers motivate the robust fit
	des$add_all_subject_responses(y)
	list(des = des, w = w, x1 = x1, y = y, X = cbind(1, treatment = w, x1 = x1))
}

install_bayesian_bootstrap_context <- function(inf) {
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	invisible(inf)
}

test_that("rlm-backend point estimate matches an independent MASS::rlm fit (MM method)", {
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = FALSE)
	est <- inf$compute_estimate()
	ref <- suppressWarnings(MASS::rlm(x = f$X, y = f$y, method = "MM"))
	expect_equal(est, unname(coef(ref)[2]), tolerance = 1e-6)
})

test_that("rlm-backend cold-start fit with method = \"M\" now succeeds instead of silently returning NA (bug fixed)", {
	# Previously: private$fit_rlm_model() passed init = ws_args$start_beta to
	# MASS::rlm() unconditionally; on a cold start (no warm-start beta
	# available) that resolved to literal init = NULL, which overrode
	# rlm.default's own default of init = "ls". MASS::rlm(..., method = "MM",
	# init = NULL) tolerates this (its internal psi.bisquare path ignores a
	# NULL init), but MASS::rlm(..., method = "M", init = NULL) throws ("x %*%
	# coef: requires numeric/complex matrix/vector arguments") because "M"
	# without an initial LS fit has nothing to iterate from. fit_rlm_model()
	# caught that error and returned NULL, so every cold (non-warm-started)
	# fit with method = "M" and use_rcpp = FALSE silently returned NA instead
	# of a real estimate. Fixed by falling back to init = "ls" (matching
	# rlm.default's own default, already used at another call site in the
	# same file) whenever no warm-start beta is available.
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "M", use_rcpp = FALSE)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))

	ref_ok <- suppressWarnings(MASS::rlm(x = f$X, y = f$y, method = "M", init = "ls"))
	expect_equal(est, unname(coef(ref_ok)[2]), tolerance = 1e-6)
})

test_that("rcpp-backend point estimate agrees closely with the rlm-backend on the same data", {
	f <- make_robust_regr_fixture()
	inf_rcpp <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = TRUE)
	inf_rlm <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = FALSE)
	expect_equal(inf_rcpp$compute_estimate(), inf_rlm$compute_estimate(), tolerance = 1e-2)
})

test_that("weighted-bootstrap refit (rlm backend) matches an independent weighted MASS::rlm fit", {
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = FALSE)
	install_bayesian_bootstrap_context(inf)

	set.seed(7)
	wts <- runif(length(f$w), 0.5, 1.5)
	est_w <- inf$compute_estimate_with_bootstrap_weights(wts)
	ref <- suppressWarnings(MASS::rlm(x = f$X, y = f$y, weights = wts, method = "MM", init = "ls"))
	expect_equal(est_w, unname(coef(ref)[2]), tolerance = 1e-6)

	# This variant is documented as estimate-only by construction: SE/df stay NA.
	priv <- inf$.__enclos_env__$private
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
	expect_true(is.na(priv$cached_values$df))
})

test_that("weighted-bootstrap refit (rcpp backend) reproduces rlm's sqrt(weight)-transform scheme", {
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = TRUE)
	install_bayesian_bootstrap_context(inf)

	set.seed(7)
	wts <- runif(length(f$w), 0.5, 1.5)
	est_w <- inf$compute_estimate_with_bootstrap_weights(wts)

	# Independent reference: the documented behaviour is "pre-multiply X and y
	# by sqrt(weight) and run unweighted M-estimation" -- reproduce that with
	# MASS::rlm (a different M-estimator implementation) on the transformed data.
	sw <- sqrt(wts)
	ref <- suppressWarnings(MASS::rlm(x = f$X * sw, y = f$y * sw, method = "MM"))
	# Two independent MM-estimator implementations (this package's C++ IRLS vs
	# MASS::rlm) on the same transformed data; a looser tolerance than the
	# rlm-vs-rlm checks above since they are genuinely different optimizers,
	# not a re-derivation of the same computation.
	expect_equal(est_w, unname(coef(ref)[2]), tolerance = 0.05)
})

test_that("unit bootstrap weights reproduce the unweighted rlm-backend estimate", {
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = FALSE)
	unweighted_est <- inf$compute_estimate()
	install_bayesian_bootstrap_context(inf)
	unit_est <- inf$compute_estimate_with_bootstrap_weights(rep(1, length(f$w)))
	expect_equal(unit_est, unweighted_est, tolerance = 1e-6)
})

test_that("asymptotic CI/p-value use the documented Wald normal-theory contract with n-p df", {
	f <- make_robust_regr_fixture()
	inf <- InferenceContinRobustRegr$new(f$des, method = "MM", use_rcpp = FALSE)
	ci <- inf$compute_asymp_confidence_interval(alpha = 0.05)
	ref <- suppressWarnings(MASS::rlm(x = f$X, y = f$y, method = "MM"))
	st <- summary(ref)
	est <- unname(coef(ref)[2])
	se <- st$coefficients[2, "Std. Error"]
	df <- nrow(f$X) - ncol(f$X)
	tcrit <- qt(0.975, df)
	expect_equal(unname(ci), c(est - tcrit * se, est + tcrit * se), tolerance = 1e-4)

	pval <- inf$compute_asymp_two_sided_pval(delta = 0)
	tstat <- (est - 0) / se
	expect_equal(pval, 2 * pt(-abs(tstat), df), tolerance = 1e-4)
})
