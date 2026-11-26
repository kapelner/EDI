# Numerical-robustness review audit, 2026-11-19: cox_partial_likelihood_fit_estimate_only_fast()
# always returns converged = TRUE after survival::coxph.fit(), even when coxph.fit stopped at
# control$iter.max short of the optimum (flag/iter not checked). On data where one Newton step does
# not reach the MLE (iter.max = 1, or the default 20 on badly conditioned data) it returns the
# unconverged coefficient flagged as converged.
# Where: R/EDI/R/inference_survival_strat_cox.R:92 (kind: converged_unchecked).
# On commit 0231668c948b this test failed with: Expected `is.null(res) || !isTRUE(res$converged)` to
# be TRUE. Differences: `actual`: FALSE `expected`: TRUE
# Tracked as v1.0.7-TODO-95; remove the skip() when it is fixed.

test_that("estimate-only coxph.fit helper does not report convergence when the iteration cap is hit", {
	skip("v1.0.7-TODO-95: the estimate-only coxph.fit helper hard-codes converged = TRUE")
		set.seed(1)
		n = 60
		w = rep(c(0, 1), n / 2)
		y = stats::rexp(n, rate = exp(3 * w))
		dead = rep(1, n)
		X = matrix(w, ncol = 1, dimnames = list(NULL, "w"))
		surv_y = survival::Surv(y, dead)
		fit_with = function(ctrl) suppressWarnings(survival::coxph.fit(
			x = X, y = surv_y, strata = NULL, offset = NULL, init = NULL,
			control = ctrl, weights = NULL, method = "breslow",
			rownames = as.character(seq_len(n)), resid = FALSE
		))
		ref_full = fit_with(survival::coxph.control())
		ref_capped = fit_with(survival::coxph.control(iter.max = 1))
		gap = abs(as.numeric(ref_capped$coefficients) - as.numeric(ref_full$coefficients))
		# sanity: one Newton step does not reach the MLE on this data
		expect_true(gap > 1e-3)
		res = suppressWarnings(EDI:::cox_partial_likelihood_fit_estimate_only_fast(
			X, surv_y, coxph_control = survival::coxph.control(iter.max = 1)
		))
		# either refuse the fit (NULL) or report it as not converged
		expect_true(is.null(res) || !isTRUE(res$converged))
})
