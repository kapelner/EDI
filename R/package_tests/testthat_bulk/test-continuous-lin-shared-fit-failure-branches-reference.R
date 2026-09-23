library(testthat)
library(EDI)

# InferenceContinLin's shared()/compute_estimate() (inference_continuous_lin.R) has three distinct
# "give up and cache nonestimable" branches after the design matrix is already known usable, none of
# which had a test reference anywhere:
#   1) stats::lm.fit() itself returns a non-finite or wrong-length coefficient vector
#      ("linear_model_coefficients_unavailable").
#   2) ols_hc2_post_fit_cpp() (the HC2 sandwich post-fit step) errors
#      ("linear_model_post_fit_unavailable").
#   3) the post-fit step succeeds but returns a non-finite or negative ssq_hat, which clears
#      beta_hat/ssq_hat to NA even though the point estimate itself was fine.
# All three are reached by mocking the exact function this method calls, the same
# local_mocked_bindings(..., .package = "EDI"/"stats") technique already used elsewhere in this
# suite for analogous unreachable-in-practice failure paths.

mk_fixture <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	InferenceContinLin$new(des, verbose = FALSE)
}

test_that("a non-finite/wrong-length lm.fit() coefficient vector is nonestimable", {
	inf <- mk_fixture()
	local_mocked_bindings(`lm.fit` = function(...) list(coefficients = c(1, NA_real_, 3)), .package = "stats")
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "linear_model_coefficients_unavailable")
})

test_that("an ols_hc2_post_fit_cpp() error is nonestimable", {
	inf <- mk_fixture(seed = 2L)
	local_mocked_bindings(ols_hc2_post_fit_cpp = function(...) stop("forced failure"), .package = "EDI")
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "linear_model_post_fit_unavailable")
})

test_that("a negative or non-finite ssq_hat from a successful post-fit clears both beta_hat and ssq_hat to NA", {
	inf <- mk_fixture(seed = 3L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(
		ols_hc2_post_fit_cpp = function(X, y, b, j) list(
			vcov = diag(length(b)), ssq_hat = -1,
			std_err = rep(NA_real_, length(b)), z_vals = rep(NA_real_, length(b))
		),
		.package = "EDI"
	)
	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
})
