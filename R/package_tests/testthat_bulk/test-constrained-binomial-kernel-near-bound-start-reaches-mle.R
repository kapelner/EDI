library(testthat)
library(EDI)

# v1.0.6-TODO-162: the constrained binomial kernels (fast_log_binomial_regression.cpp) score with the expected
# information, whose working weight is ~1 / (distance to the mean bound). From a start with a row within ~1e-6 of a
# bound that the MLE does not hold there, every Fisher-scoring increment was tiny, so the relative-change test passed
# and the kernel reported converged = TRUE short of the MLE (the identity-link fixture below: treatment 0.0906 vs
# MLE 0.0912, log-likelihood 3e-4 lower). Convergence now also needs the observed-information Newton step to agree
# (decrement or relative increment), and the fit continues with observed-information Newton steps when it does not.
# Needs the owner's build (the installed kernel fails the first test until then).

near_bound_loglik = function(b, X, y, link, wts = rep(1, length(y))) {
	eta = drop(X %*% b)
	if (link == "identity") sum(wts * (y * log(eta) + (1 - y) * log1p(-eta)))
	else sum(wts * (y * eta + (1 - y) * log1p(-exp(eta))))
}

test_that("identity-binomial kernel does not stop short of the MLE from a warm start next to mu = 0", {
	# Randomization draw 17 of the v1.0.6-TODO-146 fixture (Bernoulli design, n = 20, seed 1; draws seed 5),
	# warm-started from the fit on the previous draw (a start with one row next to mu = 0).
	set.seed(1L)
	x1 = rnorm(20L)
	wb = c(0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)
	y = c(1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1)
	X = cbind(1, wb, x1)
	ws = c(0.7009303323812841, -0.32658823513339114, 0.1690257474382906)
	expect_lt(min(X %*% ws), 1e-6)  # the fixture's point: one y = 0 row starts at mu ~ 8e-7
	warm = fast_identity_binomial_regression_cpp(X = X, y = y, warm_start_beta = ws)
	tight = fast_identity_binomial_regression_cpp(X = X, y = y, tol = 1e-12, maxit = 5000L)
	expect_true(isTRUE(tight$converged))
	expect_true(isTRUE(warm$converged))
	expect_equal(warm$b[2], tight$b[2], tolerance = 1e-6)
	expect_gt(near_bound_loglik(warm$b, X, y, "identity"), near_bound_loglik(tight$b, X, y, "identity") - 1e-8)
})

for (link in c("identity", "log")) for (weighted in c(FALSE, TRUE)) local({
	fname = paste0("fast_", link, "_binomial_regression", if (weighted) "_weighted" else "", "_cpp")
	test_that(paste(fname, "never reports convergence well short of the MLE from near-bound warm starts"), {
		kernel = get(fname, envir = asNamespace("EDI"))
		n_short = 0L
		n_checked = 0L
		for (seed in 1:4) {
			set.seed(seed)
			n = 30L
			x1 = rnorm(n)
			w = rbinom(n, 1, 0.5)
			y = rbinom(n, 1, if (link == "log") pmin(0.9, 0.3 * exp(0.3 * x1)) else pmin(0.9, pmax(0.05, 0.3 + 0.1 * x1)))
			wts = if (weighted) rexp(n) else rep(1, n)
			call = function(X, ...) if (weighted) kernel(X = X, y = y, weights = wts, ...) else kernel(X = X, y = y, ...)
			obs = call(cbind(1, w, x1))
			set.seed(100L + seed)
			for (b in 1:15) {
				wb = rbinom(n, 1, 0.5)
				if (sum(wb) %in% c(0L, n)) next
				Xb = cbind(1, wb, x1)
				tight = call(Xb, tol = 1e-12, maxit = 5000L)
				if (!isTRUE(tight$converged)) next
				ll_mle = near_bound_loglik(tight$b, Xb, y, link, wts)
				for (warm in list(call(Xb, warm_start_beta = obs$b), call(Xb, warm_start_beta = obs$b, warm_start_fisher_info = obs$fisher_information))) {
					if (!isTRUE(warm$converged)) next
					n_checked = n_checked + 1L
					if (near_bound_loglik(warm$b, Xb, y, link, wts) < ll_mle - 1e-4) n_short = n_short + 1L
				}
				obs_next = call(Xb, warm_start_beta = obs$b)
				if (isTRUE(obs_next$converged)) obs = obs_next  # vary the warm start across draws
			}
		}
		expect_gt(n_checked, 20L)
		expect_identical(n_short, 0L)
	})
})
