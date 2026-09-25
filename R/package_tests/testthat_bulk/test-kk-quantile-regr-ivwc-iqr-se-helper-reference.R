library(testthat)
library(EDI)

# InferenceAbstractKKQuantileRegrIVWC's private iqr_se(x, n) (inference_all_KK_quantile_regr_ivwc_
# abstract.R:322-328) computes an IQR-based CLT-approximation standard error for a sample quantile:
# SE = IQR(x) / (2 * qnorm(0.75)) / sqrt(n), returning NA_real_ when n < 2 or the IQR is non-finite
# or non-positive (e.g. a degenerate/constant sample). A codebase-wide grep confirmed this helper
# had zero test references anywhere, despite the class family it's spliced into (InferenceContinKK
# QuantileRegrIVWC and siblings) being otherwise well exercised. Exercised via direct private-method
# calls on a real InferenceContinKKQuantileRegrIVWC instance, independent reference computed inline.

test_that("iqr_se() matches the documented IQR/(2*qnorm(0.75))/sqrt(n) formula", {
	skip_if_not_installed("quantreg")
	set.seed(1)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	x <- rnorm(50)
	expect_equal(priv$iqr_se(x, length(x)), IQR(x) / (2 * qnorm(0.75)) / sqrt(length(x)))
})

test_that("iqr_se() returns NA_real_ for n < 2", {
	skip_if_not_installed("quantreg")
	set.seed(2)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_true(is.na(priv$iqr_se(c(1, 2), 1)))
})

test_that("iqr_se() returns NA_real_ for a degenerate (zero-IQR) sample", {
	skip_if_not_installed("quantreg")
	set.seed(3)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_true(is.na(priv$iqr_se(rep(5, 10), 10)))
})
