# Numerical-robustness review audit, 2026-11-18: The full-data multistart
# `.cloglog_full_data_multistart()` does nothing when `estimate_only = TRUE`. The estimate-only
# cloglog kernel never returns `neg_loglik`, so `primary_nll` is NA and the helper returns the
# primary fit at line 6. The candidate restarts (also estimate-only) would have NA nll too, so none
# of them could be accepted either. A stalled primary fit is therefore returned unchanged on every
# estimate-only path: compute_estimate(estimate_only = TRUE), and the randomization, bootstrap and
# jackknife draws that go through generate_mod.
# Where: R/EDI/R/inference_ordinal_cloglog.R:5 (kind: other_numerical).
# On commit 4ce2b7126d36 this test failed with: Expected `as.numeric(out$b[1])` to equal
# `as.numeric(mle$b[1])`. Differences: 1/1 mismatches [1] 1.64 - -0.357 == 2
# Tracked as v1.0.6-TODO-392; remove the skip() when it is fixed.

test_that("cloglog full-data multistart repairs a stalled primary fit on the estimate-only path", {
	skip("v1.0.6-TODO-392: the estimate-only kernel returns no neg_loglik, so the multistart is a no-op")
		set.seed(20261118)
		n = 300
		w = rbinom(n, 1, 0.5)
		x1 = rnorm(n)
		latent = 0.8 * w + 0.5 * x1 + rlogis(n)
		y = as.numeric(cut(latent, breaks = c(-Inf, stats::quantile(latent, c(0.25, 0.5, 0.75)), Inf), labels = FALSE))
		X = cbind(treatment = w, x1 = x1)
		# Converged reference MLE (variance path returns neg_loglik).
		mle = EDI:::fast_ordinal_cloglog_regression_cpp(X, y)
		expect_true(isTRUE(mle$converged))
		n_alpha = length(unique(y)) - 1L
		j = n_alpha + 1L
		# A primary estimate-only fit that stalled away from the optimum: same shape as
		# the kernel's estimate_only output (params and b, no neg_loglik).
		primary = list(params = as.numeric(mle$params), b = as.numeric(mle$b), alpha = as.numeric(mle$alpha), converged = FALSE)
		primary$params[j] = primary$params[j] + 2
		primary$b[1] = primary$b[1] + 2
		out = EDI:::.cloglog_full_data_multistart(X, y, primary, TRUE)
		expect_equal(as.numeric(out$b[1]), as.numeric(mle$b[1]), tolerance = 1e-3)
})
