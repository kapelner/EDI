library(testthat)
library(EDI)

# InferenceAbstractKKQuantileRegrIVWC's private qr_intercept_pairs(yd, Xd, tau, m) (inference_all_
# KK_quantile_regr_ivwc_abstract.R:403-421), used during the matched-pairs randomization test, fits
# a quantile regression and extracts the intercept coefficient, with two distinct branches:
#   1. p == 0 (no covariate columns) or m <= p + 1 (too few matched pairs for the full model):
#      fits the intercept-only model rq(yd ~ 1, tau).
#   2. Otherwise: fits the full model rq(yd ~ ., tau) over the covariate columns (renamed via
#      set_colnames_safely()) and extracts the "(Intercept)" coefficient.
# A codebase-wide grep confirmed this helper had zero test references anywhere, despite the class
# family it's spliced into being otherwise well exercised (its sibling iqr_se() helper was closed
# the previous iteration). Exercised via direct private-method calls on a real InferenceContinKK
# QuantileRegrIVWC instance, matching an independent quantreg::rq() call with identical inputs.

test_that("qr_intercept_pairs() with zero covariate columns matches an independent intercept-only rq() fit", {
	skip_if_not_installed("quantreg")
	set.seed(1)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	set.seed(10)
	yd <- rnorm(12)
	Xd0 <- matrix(numeric(0), nrow = 12, ncol = 0)
	res <- suppressWarnings(priv$qr_intercept_pairs(yd, Xd0, tau = 0.5, m = 12))
	ref <- unname(suppressWarnings(coef(quantreg::rq(yd ~ 1, tau = 0.5)))[1])
	expect_equal(res, ref)
})

test_that("qr_intercept_pairs() with covariates and enough pairs matches an independent full-formula rq() fit", {
	skip_if_not_installed("quantreg")
	set.seed(2)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	set.seed(20)
	m <- 20L
	yd <- rnorm(m)
	Xd <- matrix(rnorm(m * 2), m, 2)
	res <- suppressWarnings(priv$qr_intercept_pairs(yd, Xd, tau = 0.5, m = m))

	dat <- as.data.frame(Xd)
	names(dat) <- c("xd1", "xd2")
	dat$yd__ <- yd
	ref <- unname(suppressWarnings(coef(quantreg::rq(yd__ ~ ., tau = 0.5, data = dat)))[["(Intercept)"]])
	expect_equal(res, ref)
})

test_that("qr_intercept_pairs() falls back to the intercept-only branch when m <= p + 1, even with covariates present", {
	skip_if_not_installed("quantreg")
	set.seed(3)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	set.seed(30)
	m <- 2L
	yd <- rnorm(m)
	Xd <- matrix(rnorm(m * 2), m, 2) # p = 2, m = 2 <= p + 1 = 3
	res <- suppressWarnings(priv$qr_intercept_pairs(yd, Xd, tau = 0.5, m = m))
	ref <- unname(suppressWarnings(coef(quantreg::rq(yd ~ 1, tau = 0.5)))[1])
	expect_equal(res, ref)
})
