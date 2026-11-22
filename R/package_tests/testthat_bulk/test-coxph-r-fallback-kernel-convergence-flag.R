# Numerical-robustness review audit, 2026-11-19: `.fit_survival_coxph_kernel()` hard-codes `converged
# = TRUE` (lines 44 and 69) and wraps `survival::coxph.fit()` in `suppressWarnings()`, so it never
# checks whether coxph.fit actually met its convergence criterion. Take a monotone likelihood where
# the partial loglik tends to 0, such as a covariate that strictly decreases with event time and has
# no censoring. There coxph.fit uses all `iter.max` = 20 iterations and warns "Ran out of iterations
# and did not converge", yet the kernel reports a finite coefficient with `converged = TRUE`.
# `.fit_survival_coxph_fixed_kernel()` (line 105) inherits the same flag.
# Where: R/EDI/R/inference_survival_coxph.R:69 (kind: converged_unchecked).
# On commit 0231668c948b this test failed with: Expected `fit_converged` to be identical to
# `ref_converged`. Differences: 1 element mismatch
# Tracked as v1.0.6-TODO-387; remove the skip() when it is fixed.

test_that("Cox R fallback kernel reports convergence only when survival::coxph.fit converged", {
	skip("v1.0.6-TODO-387: .fit_survival_coxph_kernel() hard-codes converged = TRUE")
		# Each event subject has the strictly largest covariate in its risk set, so the
		# Breslow partial loglik increases toward 0 as beta -> Inf (monotone likelihood).
		X = matrix(c(4, 3, 2, 1), ncol = 1, dimnames = list(NULL, "x1"))
		y = c(1, 2, 3, 4)
		dead = c(1, 1, 1, 1)
		ctrl = survival::coxph.control()
		ref = suppressWarnings(survival::coxph.fit(
			x = X,
			y = survival::Surv(y, dead),
			strata = NULL,
			offset = NULL,
			init = NULL,
			control = ctrl,
			weights = NULL,
			method = "breslow",
			rownames = as.character(seq_along(y)),
			resid = FALSE
		))
		ref_converged = as.numeric(ref$iter) < ctrl$iter.max
		fit = EDI:::.fit_survival_coxph_kernel(X, y, dead)
		fit_converged = isTRUE(fit$converged)
		expect_identical(fit_converged, ref_converged)
})
