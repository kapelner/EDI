library(testthat)
library(EDI)

test_that("KK robust regression muffles MM non-convergence and falls back internally", {
	skip_if_not_installed("MASS")
	skip_if_not_installed("nbpMatching")

	des = DesignFixedBinaryMatch$new(response_type = "continuous", n = 4, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = c(-1, -0.5, 0.5, 1)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(c(0, 0, 100, 100))

	inf_one = InferenceContinKKRobustRegrOneLik$new(des, method = "MM", maxit = 1, acc = 1e-12, verbose = FALSE)
	inf_ivwc = InferenceContinKKRobustRegrIVWC$new(des, method = "MM", maxit = 1, acc = 1e-12, verbose = FALSE)

	X = cbind(1, stats::rnorm(20))
	y = c(rep(0, 10), rep(100, 10))

	fit_one = expect_no_warning(inf_one$.__enclos_env__$private$fit_rlm(X, y, j_treat = 2L, estimate_only = FALSE))
	fit_ivwc = expect_no_warning(inf_ivwc$.__enclos_env__$private$fit_rlm_with_treatment(X, y, j_treat = 2L, estimate_only = FALSE))

	# The Rcpp kernel's MM (OLS start) cannot converge in maxit = 1 at
	# acc = 1e-12. An unconverged robust fit is nonestimable (NULL), the rule
	# the MASS::rlm path already applied; the Rcpp path used to return the
	# unconverged iterate as if it were the estimate (v1.0.6-TODO-50). No
	# warning escapes.
	expect_null(fit_one)
	expect_null(fit_ivwc)

	# With an adequate iteration cap the same fit is estimable without a warning.
	inf_ok = InferenceContinKKRobustRegrIVWC$new(des, method = "MM", verbose = FALSE)
	fit_ok = expect_no_warning(inf_ok$.__enclos_env__$private$fit_rlm_with_treatment(X, y, j_treat = 2L, estimate_only = FALSE))
	expect_true(is.list(fit_ok))
	expect_true(is.finite(fit_ok$beta))
	expect_true(is.finite(fit_ok$ssq))
})

test_that("KK hurdle-Poisson combined-likelihood Wald gives NA, never a bootstrap result, when the SE is unavailable", {
	# v1.0.6-TODO-380: the Wald CI / p-value used to fall back to the bootstrap here.
	skip_if_not_installed("nbpMatching")

	des = DesignFixedBinaryMatch$new(response_type = "count", n = 4, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = c(-1, -0.5, 0.5, 1)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(c(0L, 1L, 2L, 0L))

	inf = InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE, use_rcpp = TRUE)
	priv = inf$.__enclos_env__$private
	suppressWarnings(inf$compute_estimate())
	priv$cached_values$s_beta_hat_T = NA_real_
	unlockBinding("compute_bootstrap_confidence_interval", inf)
	inf$compute_bootstrap_confidence_interval = function(...) stop("bootstrap must not be called")
	unlockBinding("compute_bootstrap_two_sided_pval", inf)
	inf$compute_bootstrap_two_sided_pval = function(...) stop("bootstrap must not be called")

	expect_warning(ci <- inf$compute_wald_confidence_interval(), class = "edi_wald_unavailable_warning")
	expect_true(all(is.na(ci)))
	expect_true(is.na(inf$compute_wald_two_sided_pval()))
	expect_identical(priv$cached_values$procedure_failure_reason$wald, "wald_standard_error_unavailable")
	expect_false(exists("warn_bootstrap_fallback_once", envir = priv, inherits = FALSE))
})

test_that("KK count one-likelihood paths produce finite estimates", {
	skip_if_not_installed("nbpMatching")

	des = DesignFixedBinaryMatch$new(response_type = "count", n = 6, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = c(-1, -0.5, 0.25, 0.75, 1.5, 2)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(c(1, 3, 2, 1, 4, 2))

	inf_hurdle = InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE, use_rcpp = TRUE)
	inf_cpois = InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)

	beta_hurdle = inf_hurdle$compute_estimate()
	beta_cpois = inf_cpois$compute_estimate()

	expect_true(is.finite(beta_hurdle))
	expect_true(is.finite(beta_cpois))
	expect_true("lik_ratio" %in% inf_hurdle$get_supported_testing_types())
	expect_true("lik_ratio" %in% inf_cpois$get_supported_testing_types())
})
