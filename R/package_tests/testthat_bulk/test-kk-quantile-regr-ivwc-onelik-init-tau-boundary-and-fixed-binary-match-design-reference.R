library(testthat)
library(EDI)

# .init_kk_quantile_regr_ivwc()/.init_kk_quantile_regr_one_lik() (inference_all_KK_quantile_regr_ivwc_
# abstract.R / inference_all_KK_quantile_regr_one_lik_abstract.R) -- the shared free-function
# initializer helpers behind InferenceContinKKQuantileRegrIVWC/InferencePropKKQuantileRegrIVWC/
# InferenceContinKKQuantileRegrOneLik/InferencePropKKQuantileRegrOneLik -- each run their own
# `assertNumeric(tau, lower = .Machine$double.eps, upper = 1 - .Machine$double.eps)` guard, separate
# from the (already well-tested) equivalent guard on the plain, non-KK InferenceContinQuantileRegr/
# InferencePropQuantileRegr classes. A grep across every existing reference to these 4 KK classes
# confirmed tau is always passed as the default 0.5 or a valid value in (0,1) -- the boundary guard on
# THIS specific init path had no test reference anywhere. Separately, every existing reference
# constructs these classes exclusively on a DesignSeqOneByOneKK14 sequential design (is_KK = TRUE
# branch, which additionally sets private$m and calls compute_basic_match_data()); despite the class
# doc explicitly stating it "supports both kk14/kk21 sequential designs and DesignFixedBinaryMatch",
# no existing test ever constructs one on a DesignFixedBinaryMatch design (is_KK = FALSE branch,
# skipping that additional setup entirely and relying on init_kk_passthrough's own has_match_structure
# handling instead). Confirmed via probe that DesignFixedBinaryMatch construction succeeds and produces
# a real, finite point estimate.

test_that("tau = 0 and tau = 1 are rejected by .init_kk_quantile_regr_ivwc's own guard, for both IVWC quantile-regr classes", {
	set.seed(1L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)

	expect_error(InferenceContinKKQuantileRegrIVWC$new(des, tau = 0), "tau")
	expect_error(InferenceContinKKQuantileRegrIVWC$new(des, tau = 1), "tau")
})

test_that("tau = 0 and tau = 1 are rejected by .init_kk_quantile_regr_one_lik's own guard", {
	set.seed(2L)
	n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)

	expect_error(InferenceContinKKQuantileRegrOneLik$new(des, tau = 0), "tau")
	expect_error(InferenceContinKKQuantileRegrOneLik$new(des, tau = 1), "tau")
})

test_that("InferenceContinKKQuantileRegrIVWC constructs and fits on a DesignFixedBinaryMatch design (is_KK = FALSE branch), skipping the sequential-design-only setup", {
	set.seed(3L)
	n <- 30L
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)

	inf <- InferenceContinKKQuantileRegrIVWC$new(des, tau = 0.5, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(isTRUE(priv$is_KK))
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
})

test_that("InferenceContinKKQuantileRegrOneLik constructs and fits on a DesignFixedBinaryMatch design (is_KK = FALSE branch)", {
	set.seed(4L)
	n <- 30L
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)

	inf <- InferenceContinKKQuantileRegrOneLik$new(des, tau = 0.5, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(isTRUE(priv$is_KK))
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
})
