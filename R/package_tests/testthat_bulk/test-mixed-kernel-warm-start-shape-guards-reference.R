# Regression coverage for the sibling audit prompted by the ZOIB wrong-length
# warm-start crash.  These calls must reject malformed inputs before an
# optimizer or Eigen expression can consume them.

make_mixed_kernel_guard_fixture <- function() {
	n <- 18L
	x <- rep(c(-1, 0, 1), length.out = n)
	list(
		X = cbind(1, x),
		X_no_intercept = matrix(x, ncol = 1L),
		group = rep(seq_len(6L), each = 3L),
		# fast_gaussian_lmm_cpp is a closed-form solution specific to KK-design
		# groups (matched pairs / reservoir singletons): any group of size > 2
		# throws before the warm-start-shape guards this file is testing even
		# run. The other kernels below tolerate the plain size-3 `group`
		# above; only gaussian_lmm needs this size-2 variant.
		group_pairs = rep(seq_len(9L), each = 2L),
		y_binary = rep(c(0, 1, 0), 6L),
		y_count = rep(c(1, 2, 3), 6L),
		y_hurdle = rep(c(0, 1, 2), 6L),
		y_ordinal = rep(1:3, 6L),
		y_survival = exp(seq(-0.5, 0.5, length.out = n)),
		dead = rep(c(1, 0, 1), 6L)
	)
}

test_that("mixed-model kernels reject wrong-length warm_start_params", {
	d <- make_mixed_kernel_guard_fixture()
	cases <- list(
		gaussian_lmm = list(
			call = function(z) EDI:::fast_gaussian_lmm_cpp(d$X, seq_len(nrow(d$X)), d$group_pairs, warm_start_params = z),
			n_params = ncol(d$X) + 2L),
		hurdle_negbin = list(
			call = function(z) EDI:::fast_hurdle_negbin_cpp(d$X, d$y_hurdle, d$X, warm_start_params = z),
			n_params = ncol(d$X) + 1L),
		hurdle_poisson_glmm = list(
			call = function(z) EDI:::fast_hurdle_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_params = z),
			n_params = ncol(d$X) + 1L),
		logistic_glmm = list(
			call = function(z) EDI:::fast_logistic_glmm_cpp(d$X, d$y_binary, d$group, 1L, warm_start_params = z),
			n_params = ncol(d$X) + 1L),
		ordinal_glmm = list(
			call = function(z) EDI:::fast_ordinal_glmm_cpp(d$X_no_intercept, d$y_ordinal, d$group, 3L, 0L, warm_start_params = z),
			n_params = 2L + ncol(d$X_no_intercept) + 1L),
		poisson_glmm = list(
			call = function(z) EDI:::fast_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_params = z),
			n_params = ncol(d$X) + 1L),
		weibull_frailty = list(
			call = function(z) EDI:::fast_weibull_frailty_cpp(d$X, d$y_survival, d$dead, d$group, warm_start_params = z),
			n_params = ncol(d$X) + 2L)
	)

	for (case_name in names(cases)) {
		case <- cases[[case_name]]
		expect_error(case$call(numeric(case$n_params - 1L)), "warm_start_params must have length", info = case_name)
		expect_error(case$call(numeric(case$n_params + 1L)), "warm_start_params must have length", info = case_name)
	}

	# This wrapper deliberately converts native optimizer exceptions into a
	# diagnostic result so callers still receive terminal fit metadata.
	zap <- EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_params = numeric(2L * ncol(d$X) - 1L))
	expect_false(zap$converged)
	expect_match(zap$exception_message, "warm_start_params must have length")
})

test_that("mixed-model kernels reject wrong-shaped warm_start_fisher_info", {
	d <- make_mixed_kernel_guard_fixture()
	cases <- list(
		gaussian_lmm = list(
			call = function(H) EDI:::fast_gaussian_lmm_cpp(d$X, seq_len(nrow(d$X)), d$group_pairs, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 2L),
		hurdle_negbin = list(
			call = function(H) EDI:::fast_hurdle_negbin_cpp(d$X, d$y_hurdle, d$X, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L),
		hurdle_poisson_glmm = list(
			call = function(H) EDI:::fast_hurdle_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L),
		logistic_glmm = list(
			call = function(H) EDI:::fast_logistic_glmm_cpp(d$X, d$y_binary, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L),
		ordinal_glmm = list(
			call = function(H) EDI:::fast_ordinal_glmm_cpp(d$X_no_intercept, d$y_ordinal, d$group, 3L, 0L, warm_start_fisher_info = H),
			n_params = 2L + ncol(d$X_no_intercept) + 1L),
		poisson_glmm = list(
			call = function(H) EDI:::fast_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L),
		weibull_frailty = list(
			call = function(H) EDI:::fast_weibull_frailty_cpp(d$X, d$y_survival, d$dead, d$group, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 2L)
	)

	for (case_name in names(cases)) {
		case <- cases[[case_name]]
		bad <- matrix(0, nrow = case$n_params, ncol = case$n_params - 1L)
		expect_error(case$call(bad), "warm_start_fisher_info must be square", info = case_name)
	}

	zap <- EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_fisher_info = matrix(0, 4L, 3L))
	expect_false(zap$converged)
	expect_match(zap$exception_message, "warm_start_fisher_info must be square")
})
