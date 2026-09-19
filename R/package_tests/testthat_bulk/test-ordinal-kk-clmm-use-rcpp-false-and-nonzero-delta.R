library(testthat)
library(EDI)

# inference_ordinal_KK_clmm_abstract.R's use_rcpp = FALSE path (shared_clmm(),
# fit_clmm()/fit_clm_fallback() via ordinal::clmm/clm, and the non-rcpp branch
# of compute_treatment_estimate_during_randomization_inference()) has no
# existing test anywhere in this suite (verified: every existing ordinal/CLMM
# bulk test either omits use_rcpp or passes use_rcpp = TRUE; grep confirms no
# `use_rcpp = FALSE` for any CLMM class). compute_asymp_two_sided_pval()'s
# nonzero-delta branch (the "TO-DO" stop()) and the constant-weight fast path
# in compute_estimate_with_bootstrap_weights() are also untested.

kk_clmm_rcpp_false_fixture <- function() {
	withr::local_seed(715, .local_envir = parent.frame())
	y <- rep(1:3, length.out = 37L)
	des <- DesignSeqOneByOneKK14$new(n = length(y), response_type = "ordinal", verbose = FALSE)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
		des$add_one_subject_response(i, y[i])
	}
	list(des = des, y = y)
}

test_that("use_rcpp = FALSE estimate/CI/p-value match an independent ordinal::clm reference after the clmm-SE fallback", {
	f <- kk_clmm_rcpp_false_fixture()
	inf <- InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, use_rcpp = FALSE, verbose = FALSE)
	est <- suppressWarnings(inf$compute_estimate(estimate_only = FALSE))
	ci <- suppressWarnings(inf$compute_asymp_confidence_interval())
	pval <- suppressWarnings(inf$compute_asymp_two_sided_pval())

	# The reference clmm fit's Std. Error is non-finite for this fixture (an
	# already-observed, genuine ordinal::clmm numerical-Hessian limitation),
	# which is exactly why shared_clmm() falls back to a fixed-effects
	# ordinal::clm fit for the standard error -- so the independent reference
	# is the clm fit, not the clmm fit, matching the class's own documented
	# fallback contract (see fit_ok's se check in inference_ordinal_KK_clmm_abstract.R).
	dat <- data.frame(y = ordered(f$y), w = f$des$get_w())
	ref <- summary(ordinal::clm(y ~ w, data = dat, link = "logit"))$coefficients["w", ]

	expect_equal(est, unname(ref["Estimate"]), tolerance = 1e-6)
	z <- qnorm(0.975)
	expect_equal(unname(ci), unname(ref["Estimate"]) + c(-1, 1) * z * unname(ref["Std. Error"]), tolerance = 1e-5)
	expect_equal(pval, unname(ref["Pr(>|z|)"]), tolerance = 1e-6)
})

test_that("use_rcpp = FALSE and use_rcpp = TRUE agree on the point estimate for the same fixture", {
	f <- kk_clmm_rcpp_false_fixture()
	est_rcpp <- InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, use_rcpp = TRUE, verbose = FALSE)$compute_estimate(estimate_only = TRUE)
	est_clmm <- suppressWarnings(InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, use_rcpp = FALSE, verbose = FALSE)$compute_estimate(estimate_only = TRUE))
	expect_equal(est_clmm, est_rcpp, tolerance = 1e-3)
})

test_that("the non-rcpp randomization-inference private path reproduces the same clm-fallback estimate", {
	f <- kk_clmm_rcpp_false_fixture()
	inf <- InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, use_rcpp = FALSE, verbose = FALSE)
	direct_est <- suppressWarnings(inf$compute_estimate(estimate_only = TRUE))
	ri_est <- suppressWarnings(inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE))
	expect_equal(ri_est, direct_est, tolerance = 1e-6)
})

test_that("compute_asymp_two_sided_pval refuses a nonzero delta with an explicit stop under assertions", {
	f <- kk_clmm_rcpp_false_fixture()
	inf <- InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(delta = 0.5), "TO-DO")
})

test_that("effectively-constant nonzero bootstrap weights take the fast identical-to-direct-estimate path", {
	f <- kk_clmm_rcpp_false_fixture()
	inf <- InferenceOrdinalKKCLMM$new(f$des, model_formula = ~ 1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	context <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- context
	direct_est <- inf$compute_estimate(estimate_only = TRUE)

	constant_weights <- rep(5, context$n_units)
	fast_est <- inf$compute_estimate_with_bootstrap_weights(constant_weights, estimate_only = TRUE)
	expect_equal(fast_est, direct_est)
	# The fast path explicitly skips variance-component work.
	expect_true(is.na(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
})
