library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullMarginal's compute_treatment_estimate_during_randomization_inference()
# (inference_survival_KK_weibull_marginal.R) had no test reference anywhere. Its public
# compute_rand_bootstrap_two_sided_pval() is exercised elsewhere (test-rand-bootstrap.R's "Weibull
# marginal BRT fast kernel" tests), which indirectly calls this method internally, but no test
# asserts on this method's own specific branches -- the fixed-VC fast path
# (fast_weibull_regression_cpp with fixed_idx/fixed_values), the two-backend fallback
# (fit_weibull_marginal_cpp then fit_weibull_marginal_survreg), or fit-failure -> NA.
#   1. On the same w it matches compute_estimate()'s own value (both call chains independently
#      assemble the design and call the same underlying fitters); on a permuted w it differs and
#      stays finite -- confirmed via a standalone probe that, unlike InferenceOrdinalKKGEE's
#      randomization-estimate method (closed earlier this session), this class's X_fit is assembled
#      directly from private$w on every call with no design-matrix memoization gotcha to work around.
#   2. A finite cached_vc_params[1] takes the fast fixed-dispersion path: fixed_idx/fixed_values are
#      passed, and a converged finite result short-circuits without calling either fallback fitter.
#   3. Without a usable cached_vc_params, both fallback fitters are attempted in order
#      (fit_weibull_marginal_cpp first, then fit_weibull_marginal_survreg if the first returns NULL).
#   4. Both fallback fitters failing (or a non-finite beta_T) returns NA.

weibull_marginal_fixture <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.9))
	inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

test_that("on the same w it matches compute_estimate()'s own value; on a permuted w it differs and stays finite", {
	f <- weibull_marginal_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-4)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(est2))
	expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("a finite cached_vc_params[1] takes the fixed-dispersion fast path and short-circuits both fallback fitters", {
	f <- weibull_marginal_fixture(seed = 3L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- 0.3

	cpp_called <- FALSE
	fallback_called <- FALSE
	local_mocked_bindings(
		fast_weibull_regression_cpp = function(y, dead, X, ..., fixed_idx = NULL, fixed_values = NULL) {
			cpp_called <<- TRUE
			expect_equal(fixed_idx, ncol(X) + 1L)
			expect_equal(fixed_values, 0.3)
			list(converged = TRUE, b = c(0.1, 0.64, 0))
		},
		.package = "EDI"
	)
	unlockBinding("fit_weibull_marginal_cpp", p)
	p$fit_weibull_marginal_cpp <- function(...) { fallback_called <<- TRUE; NULL }

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.64)
	expect_true(cpp_called)
	expect_false(fallback_called)
})

test_that("without a usable cached_vc_params, the two-backend fallback is attempted (cpp first, then survreg)", {
	f <- weibull_marginal_fixture(seed = 4L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- NA_real_

	unlockBinding("fit_weibull_marginal_cpp", p)
	unlockBinding("fit_weibull_marginal_survreg", p)
	p$fit_weibull_marginal_cpp <- function(...) NULL
	p$fit_weibull_marginal_survreg <- function(...) list(beta_T = -0.42)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, -0.42)
})

test_that("both fallback fitters failing (or a non-finite beta_T) returns NA", {
	f <- weibull_marginal_fixture(seed = 5L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- NA_real_

	unlockBinding("fit_weibull_marginal_cpp", p)
	unlockBinding("fit_weibull_marginal_survreg", p)
	p$fit_weibull_marginal_cpp <- function(...) NULL
	p$fit_weibull_marginal_survreg <- function(...) NULL
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	p$fit_weibull_marginal_survreg <- function(...) list(beta_T = NA_real_)
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})
