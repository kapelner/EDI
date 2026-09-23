library(testthat)
library(EDI)

# InferenceCountKKGLMM's compute_treatment_estimate_during_randomization_inference()
# (inference_count_KK_combined.R) had no test reference anywhere.
#
# GOTCHA (not a bug, same shape as the InferenceOrdinalKKGEE case closed earlier this session):
# when ncol(X) > 0 the design matrix is built via create_design_matrix() (inference_all_abstract.R),
# which memoizes on private$cached_design_matrix. Permuting private$w directly after that cache is
# already populated has no effect until private$cached_design_matrix is also cleared -- this file
# does so explicitly, matching what the real compute_rand_two_sided_pval() worker machinery does
# internally before every permutation replicate.
#
#   1. On the same w it matches compute_estimate()'s own value (self-consistency: no independent
#      GLMM-Poisson-with-random-intercept reference package is used elsewhere in this suite for this
#      class); on a permuted w (with the design-matrix cache cleared) it differs and stays finite.
#   2. use_rcpp = FALSE falls back to self$compute_estimate() directly (the fast rcpp path is gated
#      on private$use_rcpp).
#   3. A NULL/unset cached_vc_params also falls back to self$compute_estimate() directly (the fast
#      path additionally requires a cached variance-component estimate to fix).
#   4. A fitter failure/non-convergence/extreme coefficient also falls back to self$compute_estimate()
#      -- unlike most sibling classes in this session's series, this method has NO bare NA-return
#      branch at all; every failure mode falls through to the same public compute_estimate() call.

kk_glmm_count_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * X$x1 + 0.5 * w + 0.5)))
	inf <- InferenceCountKKGLMM$new(des, use_rcpp = TRUE, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

test_that("on the same w it matches compute_estimate()'s own value; on a permuted w (with the design-matrix cache cleared) it differs and stays finite", {
	f <- kk_glmm_count_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))
	expect_true(is.finite(f$priv$cached_vc_params[1L]))

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-6)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	f$priv$cached_design_matrix <- NULL
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(est2))
	expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("use_rcpp = FALSE falls back to self$compute_estimate() directly", {
	f <- kk_glmm_count_fixture(seed = 2L)
	f$inf$compute_estimate()
	p <- f$priv
	unlockBinding("use_rcpp", p)
	p$use_rcpp <- FALSE

	called <- FALSE
	unlockBinding("compute_estimate", f$inf)
	f$inf$compute_estimate <- function(estimate_only = FALSE) { called <<- TRUE; 0.99 }

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_true(called)
	expect_equal(res, 0.99)
})

test_that("a NULL cached_vc_params falls back to self$compute_estimate() directly", {
	f <- kk_glmm_count_fixture(seed = 3L)
	f$inf$compute_estimate()
	p <- f$priv
	p$cached_vc_params <- NULL

	called <- FALSE
	unlockBinding("compute_estimate", f$inf)
	f$inf$compute_estimate <- function(estimate_only = FALSE) { called <<- TRUE; 0.88 }

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_true(called)
	expect_equal(res, 0.88)
})

test_that("a fitter failure/extreme coefficient falls back to self$compute_estimate() (no bare NA-return branch)", {
	f <- kk_glmm_count_fixture(seed = 4L)
	f$inf$compute_estimate()

	called <- FALSE
	unlockBinding("compute_estimate", f$inf)
	f$inf$compute_estimate <- function(estimate_only = FALSE) { called <<- TRUE; 0.77 }

	local_mocked_bindings(fast_poisson_glmm_cpp = function(...) NULL, .package = "EDI")
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(), 0.77)
	expect_true(called)

	called <- FALSE
	local_mocked_bindings(
		fast_poisson_glmm_cpp = function(X, ...) list(converged = TRUE, b = c(0, 1e5, rep(0, ncol(X) - 1L))),
		.package = "EDI"
	)
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(), 0.77)
	expect_true(called)
})
