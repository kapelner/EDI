library(testthat)
library(EDI)

# v1.0.6-TODO-174: both IRLS loops in R/EDI/src/fast_log_binomial_regression.cpp ran while
# `iter < maxit || kkt_confirm_pending`, and a small step next to a mean bound sets that flag, so the loop had no
# hard bound. With tol < 0.9 the flag cannot be set twice in a row (the confirmation iteration either stops or takes
# an observed-information Newton step too large to pass the relative-change test), so fits end by maxit + 1; the
# loop is now also capped at kKktConfirmMaxExtraIter (3) iterations past maxit, after which a still-pending fit
# reports converged = FALSE and hit_iteration_cap = TRUE.
#
# Normal inputs cannot keep the flag set, so the cap past maxit + 1 is not exercised here (the owner chose not to keep
# a compile-time test seam in the kernel for it).

test_that("constrained binomial kernels end at most one confirmation iteration past maxit", {
	max_over = -Inf
	n_extra = 0L
	for (fname in c("fast_log_binomial_regression_cpp", "fast_identity_binomial_regression_cpp",
	                "fast_log_binomial_regression_weighted_cpp", "fast_identity_binomial_regression_weighted_cpp")) {
		kernel = get(fname, envir = asNamespace("EDI"))
		weighted = grepl("weighted", fname)
		for (seed in 1:12) {
			set.seed(seed)
			n = 30L
			x1 = rnorm(n)
			w = rbinom(n, 1, 0.5)
			y = rbinom(n, 1, if (grepl("_log_", fname)) pmin(0.95, 0.4 * exp(0.5 * x1)) else pmin(0.95, pmax(0.02, 0.4 + 0.2 * x1)))
			wts = rexp(n)
			X = cbind(1, w, x1)
			call = function(...) if (weighted) kernel(X = X, y = y, weights = wts, ...) else kernel(X = X, y = y, ...)
			full = call(maxit = 200L, tol = 1e-8)
			starts = list(NULL)
			if (all(is.finite(full$b))) starts = c(starts, list(full$b, full$b * 1.3))
			for (st in starts) for (maxit in c(1L, 2L, 3L, 5L)) {
				fit = if (is.null(st)) call(maxit = maxit) else call(maxit = maxit, warm_start_beta = st)
				over = fit$num_iter - maxit
				max_over = max(max_over, over)
				if (over == 1) {
					n_extra = n_extra + 1L
				}
			}
		}
	}
	expect_lte(max_over, 1)
	expect_gt(n_extra, 0L)  # the pending-at-maxit path was exercised
})
