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

	# This wrapper converts native optimizer exceptions into a diagnostic
	# result, but argument-contract violations error like every other kernel.
	expect_error(EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_params = numeric(2L * ncol(d$X) - 1L)),
		"warm_start_params must have length")
})

test_that("mixed-model kernels reject wrong-shaped warm_start_fisher_info", {
	d <- make_mixed_kernel_guard_fixture()
	cases <- list(
		gaussian_lmm = list(
			call = function(H) EDI:::fast_gaussian_lmm_cpp(d$X, seq_len(nrow(d$X)), d$group_pairs, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 2L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 2 rows"),
		hurdle_negbin = list(
			call = function(H) EDI:::fast_hurdle_negbin_cpp(d$X, d$y_hurdle, d$X, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 1 rows"),
		hurdle_poisson_glmm = list(
			call = function(H) EDI:::fast_hurdle_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 1 rows"),
		logistic_glmm = list(
			call = function(H) EDI:::fast_logistic_glmm_cpp(d$X, d$y_binary, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 1 rows"),
		ordinal_glmm = list(
			call = function(H) EDI:::fast_ordinal_glmm_cpp(d$X_no_intercept, d$y_ordinal, d$group, 3L, 0L, warm_start_fisher_info = H),
			n_params = 2L + ncol(d$X_no_intercept) + 1L,
			dimension_error = "warm_start_fisher_info must be square with (K - 1) + ncol(X) + 1 rows"),
		poisson_glmm = list(
			call = function(H) EDI:::fast_poisson_glmm_cpp(d$X, d$y_count, d$group, 1L, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 1L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 1 rows"),
		weibull_frailty = list(
			call = function(H) EDI:::fast_weibull_frailty_cpp(d$X, d$y_survival, d$dead, d$group, warm_start_fisher_info = H),
			n_params = ncol(d$X) + 2L,
			dimension_error = "warm_start_fisher_info must be square with ncol(X) + 2 rows")
	)

	for (case_name in names(cases)) {
		case <- cases[[case_name]]
		bad <- matrix(0, nrow = case$n_params, ncol = case$n_params - 1L)
		expect_error(case$call(bad), "warm_start_fisher_info must be square", info = case_name)

		# A square matrix can still have the wrong parameter dimension. Check
		# the kernel's specific dimension-contract error, not just squareness.
		wrong_size_square <- diag(case$n_params + 1L)
		actual_error <- tryCatch({
			case$call(wrong_size_square)
			NA_character_
		}, error = function(e) conditionMessage(e))
		expect_identical(actual_error, case$dimension_error, info = case_name)
	}

	expect_error(EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_fisher_info = matrix(0, 4L, 3L)),
		"warm_start_fisher_info must have dimensions")
	zip_wrong_size_square_error <- tryCatch({
		EDI:::fast_zero_augmented_poisson_cpp(
			d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
			warm_start_fisher_info = diag(5L))
		NA_character_
	}, error = function(e) conditionMessage(e))
	expect_identical(zip_wrong_size_square_error,
		"warm_start_fisher_info must have dimensions 4 x 4")
})

test_that("mixed-model kernels reject non-finite warm-start inputs", {
	d <- make_mixed_kernel_guard_fixture()
	parameter_cases <- list(
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
	fisher_cases <- list(
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

	for (case_name in names(parameter_cases)) {
		case <- parameter_cases[[case_name]]
		bad <- numeric(case$n_params)
		bad[[1L]] <- NaN
		expect_error(case$call(bad), "warm_start_params must contain only finite values", info = case_name)
	}
	for (case_name in names(fisher_cases)) {
		case <- fisher_cases[[case_name]]
		bad <- diag(case$n_params)
		bad[[1L, 1L]] <- Inf
		expect_error(case$call(bad), "warm_start_fisher_info must contain only finite values", info = case_name)
	}

	# The zero-augmented wrapper returns a structured diagnostic for native
	# parameter/finiteness failures, unlike the sibling wrappers' thrown errors.
	zoib_params <- rep(0, 2L * ncol(d$X))
	zoib_params[[1L]] <- NaN
	zoib_fit <- EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_params = zoib_params)
	expect_match(zoib_fit$exception_message,
		"warm_start_params must contain only finite values")
	zoib_info <- diag(length(zoib_params))
	zoib_info[[1L, 1L]] <- Inf
	zoib_fit <- EDI:::fast_zero_augmented_poisson_cpp(
		d$X, d$y_hurdle, d$X, is_hurdle = TRUE,
		warm_start_fisher_info = zoib_info)
	expect_match(zoib_fit$exception_message,
		"warm_start_fisher_info must contain only finite values")
})
