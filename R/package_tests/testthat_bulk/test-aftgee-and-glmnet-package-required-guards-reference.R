library(testthat)
library(EDI)

# Two final entries in this stretch's "optional package required" guard sweep:
#   1. InferenceSurvivalKKRankRegrIVWC's own initialize() (inference_survival_KK_rank_regr_ivwc_
#      abstract.R) guards on check_package_installed("aftgee") -- "Package 'aftgee' is required for
#      InferenceSurvivalKKRankRegrIVWC. Please install it." The class's 4 existing references
#      (test-kk-rank-regr-ivwc-weighted-passthrough-reference.R, migration-golden, etc.) all run with
#      the real aftgee package installed, so this branch was never exercised.
#   2. fast_coxph_regression()'s glmnet fallback (helper_glm_fit.R) guards on
#      check_package_installed("glmnet") when use_rcpp = FALSE -- "Package 'glmnet' is required for
#      fast_coxph_regression when use_rcpp = FALSE. Please install it." test-fast-coxph-regression-
#      wrapper-and-optimizer-name-normalization-reference.R already exercises this exact fallback path
#      under skip_if_not_installed("glmnet"), so the "package unavailable" branch itself was never hit.
# A codebase-wide grep confirmed neither exact message had any test reference anywhere. Both reached
# via with_mocked_bindings(check_package_installed = function(...) FALSE, .package = "EDI"), the same
# established pattern used for the nbpMatching/quantreg/geepack/icenReg/blockTools/anticlust "package
# unavailable" guards closed earlier in this stretch.

test_that("InferenceSurvivalKKRankRegrIVWC errors with the documented message when aftgee is (mocked as) unavailable", {
	set.seed(1L)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE),
				"Package 'aftgee' is required for InferenceSurvivalKKRankRegrIVWC. Please install it.",
				fixed = TRUE
			)
		}
	)
})

test_that("fast_coxph_regression(use_rcpp = FALSE) errors with the documented message when glmnet is (mocked as) unavailable, but use_rcpp = TRUE never reaches the guard", {
	set.seed(2L)
	n <- 30L
	X <- cbind(a = rnorm(n), b = rbinom(n, 1, 0.5))
	t_ <- round(rexp(n, exp(0.4 * X[, 1] - 0.3 * X[, 2])) * 5) + 1
	dead <- rbinom(n, 1, 0.75)

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				fast_coxph_regression(X, t_, dead, use_rcpp = FALSE),
				"Package 'glmnet' is required for fast_coxph_regression when use_rcpp = FALSE. Please install it.",
				fixed = TRUE
			)
			expect_no_error(fast_coxph_regression(X, t_, dead, use_rcpp = TRUE))
		}
	)
})
