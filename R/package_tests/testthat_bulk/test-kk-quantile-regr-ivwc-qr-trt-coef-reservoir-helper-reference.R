library(testthat)
library(EDI)

# InferenceAbstractKKQuantileRegrIVWC's private qr_trt_coef_reservoir(y_adj, X_full, tau)
# (inference_all_KK_quantile_regr_ivwc_abstract.R:424-432), the reservoir-side sibling of
# qr_intercept_pairs() (closed the previous iteration), fits rq(yr__ ~ . - 1, tau) over the full
# design (including a "trt__" treatment column, no intercept) and extracts the treatment
# coefficient. A codebase-wide grep confirmed this helper had zero test references anywhere.
# Exercised via a direct private-method call on a real InferenceContinKKQuantileRegrIVWC instance,
# matching an independent quantreg::rq() call with identical inputs.

test_that("qr_trt_coef_reservoir() matches an independent no-intercept rq() fit's treatment coefficient", {
	skip_if_not_installed("quantreg")
	set.seed(1)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	set.seed(10)
	m <- 20L
	y_adj <- rnorm(m)
	X_full <- cbind(trt__ = rbinom(m, 1, 0.5), x1 = rnorm(m))
	res <- suppressWarnings(priv$qr_trt_coef_reservoir(y_adj, X_full, tau = 0.5))

	dat <- as.data.frame(X_full)
	dat$yr__ <- y_adj
	ref <- unname(suppressWarnings(coef(quantreg::rq(yr__ ~ . - 1, tau = 0.5, data = dat)))[["trt__"]])
	expect_equal(res, ref)
})

test_that("qr_trt_coef_reservoir() returns NA_real_ when the fit fails (e.g. a rank-deficient design)", {
	skip_if_not_installed("quantreg")
	set.seed(2)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	m <- 20L
	y_adj <- rep(1, m)
	X_full <- cbind(trt__ = rep(1, m), x1 = rep(1, m)) # duplicate columns -> singular design
	res <- suppressWarnings(priv$qr_trt_coef_reservoir(y_adj, X_full, tau = 0.5))
	expect_true(is.na(res))
})
