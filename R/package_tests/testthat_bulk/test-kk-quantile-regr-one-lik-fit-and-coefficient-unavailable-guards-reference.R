library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrOneLik$shared_combined_likelihood()
# (inference_all_KK_quantile_regr_one_lik_abstract.R) has 3 distinct nonestimable branches around
# its quantreg::rq() fit, none of which had a test reference anywhere:
#   1. "insufficient_data_for_quantile_regr": after QR-reducing the stacked design to full rank
#      (qr_reduce_preserve_cols_cpp), there aren't more rows than parameters.
#   2. "quantile_regr_fit_unavailable": quantreg::rq() itself errors.
#   3. "quantile_regr_nonfinite_coef": rq() succeeds, but the extracted treatment coefficient is
#      non-finite (e.g. aliased by rank deficiency quantreg's own fit didn't reject outright).
# Reached via InferenceContinKKQuantileRegrOneLik, a non-IVWC concrete host of the shared abstract
# (the IVWC compound estimators are out of scope for this suite). Branches 1-3 are reached by
# mocking the exact function this method calls at each site (qr_reduce_preserve_cols_cpp,
# quantreg::rq), the same local_mocked_bindings(...) technique already used elsewhere in this suite
# for analogous unreachable-in-practice failure paths. quantreg::rq objects have no coef.rq S3
# method (confirmed: methods(coef) lists no coef.rq), so coef(fit) dispatches to coef.default,
# i.e. fit$coefficients directly -- branch 3's mock supplies that field directly rather than
# separately mocking coef() (which would also perturb rq()'s own internal fitting).

kk_qreg_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
}

test_that("shared_combined_likelihood is estimable on an ordinary fixture (sanity baseline for the fixture itself)", {
	inf <- kk_qreg_fixture()
	p <- inf$.__enclos_env__$private
	p$shared_combined_likelihood(estimate_only = TRUE)
	expect_true(is.finite(p$cached_values$beta_hat_T))
	expect_null(inf$get_nonestimable_reason())
})

test_that("a post-reduction design with no more rows than parameters is nonestimable ('insufficient_data_for_quantile_regr')", {
	inf <- kk_qreg_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(
		qr_reduce_preserve_cols_cpp = function(X, j) list(X_reduced = X[1:2, , drop = FALSE], keep = seq_len(ncol(X))),
		.package = "EDI"
	)
	p$shared_combined_likelihood(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "insufficient_data_for_quantile_regr")
})

test_that("a quantreg::rq() error is nonestimable ('quantile_regr_fit_unavailable')", {
	inf <- kk_qreg_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(rq = function(...) stop("forced failure"), .package = "quantreg")
	p$shared_combined_likelihood(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "quantile_regr_fit_unavailable")
})

test_that("a successful rq() fit with a non-finite treatment coefficient is nonestimable ('quantile_regr_nonfinite_coef')", {
	inf <- kk_qreg_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(
		rq = function(...) structure(list(coefficients = c(x1 = 1, trt__ = NA_real_)), class = "rq"),
		.package = "quantreg"
	)
	p$shared_combined_likelihood(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "quantile_regr_nonfinite_coef")
	expect_true(is.na(p$cached_values$beta_hat_T))
})
