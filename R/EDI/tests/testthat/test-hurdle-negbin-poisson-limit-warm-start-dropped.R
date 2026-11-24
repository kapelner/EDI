library(testthat)
library(EDI)

# v1.0.6-TODO-411: a warm start at the Poisson limit (log theta past
# HURDLE_NEGBIN_POISSON_BOUNDARY_LOG_THETA, e.g. theta ~ 1e8 carried over from the previous
# fit) left the count optimizer where the observed information is meaningless, and its
# Newton-decrement finish then summed the expected-information series on every iteration: one
# refit inside a randomization-CI bound search took 25 s to hours (the nightly Ubuntu
# reproducibility leg hung on InferenceCountHurdleNegBin rand_ci_parallel). try_hurdle_negbin_fit()
# now drops such a start (and its Fisher information) and fits from the cold start.

hurdle_negbin_warm_start_probe = function(warm_params) {
	set.seed(20261124)
	n = 40
	x1 = rnorm(n)
	w = rep(0:1, n / 2)
	y = ifelse(runif(n) < 0.3, 0, 1 + rpois(n, exp(0.4 + 0.3 * w + 0.2 * x1)))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	X_f = cbind(1, w, x1)
	seen = list()
	real_kernel = EDI:::fast_hurdle_negbin_with_var_cpp
	testthat::local_mocked_bindings(
		fast_hurdle_negbin_with_var_cpp = function(X_r, y_r, X_hurdle_r, ...) {
			args = list(...)
			seen <<- list(warm_start_params = args$warm_start_params, warm_start_fisher_info = args$warm_start_fisher_info)
			real_kernel(X_r, y_r, X_hurdle_r, ...)
		},
		.package = "EDI"
	)
	for (nm in c("get_fit_warm_start_for_length", "get_fit_warm_start_fisher")) unlockBinding(nm, priv)
	priv$get_fit_warm_start_for_length = function(type = "params", expected_length = NULL) warm_params
	priv$get_fit_warm_start_fisher = function(expected_dim = NULL) diag(length(warm_params))
	fit = priv$try_hurdle_negbin_fit(X_f, X_f, 2L)
	list(seen = seen, fit = fit)
}

test_that("a hurdle NB warm start past the Poisson boundary is dropped for the cold start", {
	out = hurdle_negbin_warm_start_probe(c(0.4, 0.3, 0.2, 18.4))
	expect_null(out$seen$warm_start_params)
	expect_null(out$seen$warm_start_fisher_info)
	expect_false(is.null(out$fit))
	expect_true(all(is.finite(out$fit$b)))
})

test_that("a non-finite warm-start dispersion is dropped too", {
	out = hurdle_negbin_warm_start_probe(c(0.4, 0.3, 0.2, Inf))
	expect_null(out$seen$warm_start_params)
})

test_that("an ordinary hurdle NB warm start is still passed to the kernel", {
	ws = c(0.4, 0.3, 0.2, 1)
	out = hurdle_negbin_warm_start_probe(ws)
	expect_equal(out$seen$warm_start_params, ws)
	expect_equal(out$seen$warm_start_fisher_info, diag(4))
})
