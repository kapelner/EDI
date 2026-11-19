library(testthat)
library(EDI)

# v1.0.6-TODO-203: the fixed-link cumulative ordinal kernels (cauchit, cloglog, probit; shared pipeline in
# R/EDI/src/ordinal_fixed_link_internal.h) used to differ on edge cases, kept as FixedLinkFitSpec policy flags by the
# v1.0.6-TODO-193 refactor. One behavior for all three now:
#   * inputs are validated before the K < 2 early return (cauchit returned first);
#   * y with fewer than 2 levels gives an empty list (probit fitted a threshold-free model and returned b = 0);
#   * a non-finite or non-positive ssq_b_j is NaN (cauchit and cloglog returned e.g. 0);
#   * the _with_var exports return list(b = NA, ssq_b_2 = NA) for such y (probit returned the full fit).
# Needs the owner's build.

fixed_link_kernels = function(link) {
	ns = asNamespace("EDI")
	list(
		fit = get(sprintf("fast_ordinal_%s_regression_cpp", link), envir = ns),
		with_var = get(sprintf("fast_ordinal_%s_regression_with_var_cpp", link), envir = ns)
	)
}

fixed_link_edge_data = function() {
	set.seed(1)
	n = 60L
	list(w = rbinom(n, 1, 0.5), x = rnorm(n), y = sample(1:3, n, TRUE), y1 = rep(2, n))
}

for (link in c("cauchit", "cloglog", "probit")) local({
	k = fixed_link_kernels(link)
	d = fixed_link_edge_data()
	X = cbind(d$w, d$x)

	test_that(paste(link, "kernel: y with one level gives an empty fit and an NA with_var list"), {
		expect_length(k$fit(X, d$y1), 0L)
		expect_length(k$fit(X, d$y1, estimate_only = TRUE), 0L)
		wv = k$with_var(X, d$y1)
		expect_identical(names(wv), c("b", "ssq_b_2"))
		expect_true(is.na(wv$b) && is.na(wv$ssq_b_2))
	})

	test_that(paste(link, "kernel: inputs are validated before the one-level early return"), {
		expect_error(k$fit(X, d$y1, warm_start_fisher_info = diag(5)), "warm_start_fisher_info")
		expect_error(k$fit(X, d$y1, warm_start_params = rep(0, 7)), "warm_start_params")
		expect_error(k$fit(X, d$y1, fixed_idx = 9L, fixed_values = 0), "fixed_idx")
		expect_error(k$with_var(X, d$y1, warm_start_fisher_info = diag(5)), "warm_start_fisher_info")
	})

	test_that(paste(link, "kernel: a non-positive treatment variance is reported as NaN"), {
		# duplicated treatment column: the information is singular, so the treatment variance is not positive
		wv = k$with_var(cbind(d$w, d$w, d$x), d$y)
		expect_true(is.nan(wv$ssq_b_j))
		fit = k$fit(cbind(d$w, d$w, d$x), d$y)
		expect_true(is.nan(fit$ssq_b_j))
	})

	test_that(paste(link, "kernel: an ordinary fit is unaffected"), {
		wv = k$with_var(X, d$y)
		expect_true(isTRUE(wv$converged))
		expect_true(is.finite(wv$ssq_b_j) && wv$ssq_b_j > 0)
		expect_equal(wv$b, k$fit(X, d$y)$b)
	})
})
