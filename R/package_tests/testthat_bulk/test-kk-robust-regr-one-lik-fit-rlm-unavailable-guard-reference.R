library(testthat)
library(EDI)

# InferenceContinKKRobustRegrOneLik's private fit_rlm() (inference_continuous_KK_robust_regr_one_lik.R)
# is the robust-regression fitter behind the combined matched/reservoir likelihood: returns NULL
# immediately if the design isn't over-determined (nrow(X) <= ncol(X)), before either backend
# (fast_robust_regression_cpp or MASS::rlm) ever runs. shared() then caches "rlm_fit_unavailable"
# when fit_rlm() returns NULL. Neither fit_rlm()'s own degenerate branch nor this end-to-end wiring
# had any test reference anywhere -- same shape as the sibling fit_ols()/"ols_fit_unavailable" guard
# on InferenceContinKKOLSOneLik, closed in a previous iteration. Reached via
# InferenceContinKKRobustRegrOneLik, a non-IVWC concrete host of the shared KK-compound machinery
# (the IVWC compound estimators are out of scope for this suite).

test_that("fit_rlm returns NULL when the design isn't over-determined (nrow(X) <= ncol(X))", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	p <- InferenceContinKKRobustRegrOneLik$new(des, verbose = FALSE)$.__enclos_env__$private

	Xbad <- matrix(rnorm(6), 2, 3)  # 2 rows, 3 columns
	expect_null(p$fit_rlm(Xbad, rnorm(2), j_treat = 1L))
})

test_that("estimate-only robust fits retain the configured MM estimator", {
	# Randomization workers request estimate_only = TRUE. Their statistic must
	# use the same M/MM objective as the observed estimate, not Huber M for speed.
	set.seed(17L); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n) + 0.7 * des$get_w())
	p <- InferenceContinKKRobustRegrOneLik$new(des, method = "MM", use_rcpp = FALSE, verbose = FALSE)$.__enclos_env__$private
	X <- cbind(`(Intercept)` = 1, w = rep(c(0, 1), length.out = n), x1 = rnorm(n))
	y <- 0.7 * X[, "w"] + rnorm(n)
	full <- p$fit_rlm(X, y, j_treat = 2L, estimate_only = FALSE)
	point <- p$fit_rlm(X, y, j_treat = 2L, estimate_only = TRUE)
	expect_false(is.null(full))
	expect_false(is.null(point))
	expect_equal(point$beta, full$beta, tolerance = 1e-10)
	expect_true(is.na(point$se))
})

test_that("shared() caches 'rlm_fit_unavailable' end-to-end when fit_rlm() fails", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())

	inf <- InferenceContinKKRobustRegrOneLik$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_rlm", p)
	p$fit_rlm <- function(...) NULL

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "rlm_fit_unavailable")
})
