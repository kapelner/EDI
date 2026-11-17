# Numerical-robustness review audit, 2026-11-17: cluster_robust_cr2_variance() returns NULL whenever
# the CR2 variance is below the absolute floor .Machine$double.eps, so a continuous response measured
# in small units (e.g. y * 1e-8) is declared not estimable. The CR2 variance is well defined and
# scales exactly with y^2. When the result is NULL, InferenceContinuousOLS / Lin silently keep the
# homoskedastic independent-subjects SE on a cluster design instead of the cluster-robust one.
# Where: R/EDI/R/helper_robust_sandwich.R:155 (kind: na_where_defined).
# On commit 4fc58cd063bc this test failed with: Expected `is.null(cr_small)` to be FALSE.
# Differences: `actual`: TRUE `expected`: FALSE
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("CR2 cluster-robust variance is scale-equivariant for responses in small units", {
	skip("open a release TODO for this")
		set.seed(1)
		n = 60
		cluster = rep(1:6, each = 10)
		w = rep(c(0, 1), 30)
		x = rnorm(n)
		X = cbind(1, w, x)
		y = 1 + 0.5 * w + 0.3 * x + rnorm(6)[cluster] + rnorm(n)
		coef_hat = as.numeric(qr.coef(qr(X), y))
		cr = EDI:::cluster_robust_cr2_variance(X, y, coef_hat, cluster, 2L)
		expect_false(is.null(cr))
		s = 1e-8
		cr_small = EDI:::cluster_robust_cr2_variance(X, y * s, coef_hat * s, cluster, 2L)
		expect_false(is.null(cr_small))
		if (!is.null(cr_small)) {
			expect_equal(cr_small$ssq, cr$ssq * s^2, tolerance = 1e-6)
			expect_equal(cr_small$df, cr$df, tolerance = 1e-6)
		}
})
