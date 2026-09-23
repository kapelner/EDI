library(testthat)
library(EDI)

# InferenceContinRobustRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_continuous_robust_regr.R) had no test reference anywhere -- test-rand-bootstrap.R already
# exercises it indirectly via compute_rand_bootstrap_two_sided_pval()'s BRT fast-kernel smoke tests,
# but nothing asserts on this method's own branches directly. Both backends reached (this class,
# unlike most siblings in this session's series, dispatches on use_rcpp at the top of the method
# rather than always using one fitter):
#   1. use_rcpp = FALSE: the refit IS a direct MASS::rlm() call, so it matches an independent
#      MASS::rlm() fit closely (small numerical differences from the class's own warm-start/scale
#      handling, hence a modest tolerance).
#   2. use_rcpp = TRUE: the fast fit_rlm_model() fitter approximates the same M-estimator; matches
#      MASS::rlm() to a looser tolerance (confirmed via a standalone probe: ~1e-3 absolute
#      difference on typical simulated data, well under the 0.02 tolerance used here).
#   3. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   4. A fitter failure (fit_rlm_model()/MASS::rlm() returns NULL, or a non-finite coefficient)
#      returns NA, for both backends.

robust_regr_fixture <- function(seed = 1L, n = 80L, use_rcpp = TRUE) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 0.5 * w + 0.3 * X$x1 + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceContinRobustRegr$new(des, use_rcpp = use_rcpp, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = X$x1, y = y, w = w)
}

test_that("use_rcpp = FALSE: the refit matches an independent MASS::rlm() fit closely, on the current and a permuted w", {
	f <- robust_regr_fixture(use_rcpp = FALSE)
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x1")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(MASS::rlm(x = cbind(1, f$w, f$x), y = f$y, method = f$priv$rlm_method, scale.est = "mad", maxit = 20))[2])
	expect_equal(est, ref, tolerance = 0.01)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(MASS::rlm(x = cbind(1, w2, f$x), y = f$y, method = f$priv$rlm_method, scale.est = "mad", maxit = 20))[2])
	expect_equal(est2, ref2, tolerance = 0.01)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("use_rcpp = TRUE: the fast refit approximates an independent MASS::rlm() fit", {
	f <- robust_regr_fixture(seed = 2L, use_rcpp = TRUE)
	f$inf$compute_estimate()

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(MASS::rlm(x = cbind(1, f$w, f$x), y = f$y, method = f$priv$rlm_method, scale.est = "mad", maxit = 20))[2])
	expect_equal(est, ref, tolerance = 0.02)
})

test_that("without prior column selection it calls shared() first", {
	f <- robust_regr_fixture(seed = 3L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("a fitter failure returns NA, for both backends", {
	f_rcpp <- robust_regr_fixture(seed = 4L, use_rcpp = TRUE)
	f_rcpp$inf$compute_estimate()
	unlockBinding("fit_rlm_model", f_rcpp$priv)
	f_rcpp$priv$fit_rlm_model <- function(...) NULL
	expect_true(is.na(f_rcpp$priv$compute_treatment_estimate_during_randomization_inference()))

	f_r <- robust_regr_fixture(seed = 5L, use_rcpp = FALSE)
	f_r$inf$compute_estimate()
	local_mocked_bindings(rlm = function(...) stop("forced failure"), .package = "MASS")
	expect_true(is.na(f_r$priv$compute_treatment_estimate_during_randomization_inference()))
})
