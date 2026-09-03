test_that("ZINB fit reduced to the ZIP limit returns a full-length score conformable with its information", {
	# Equidispersed counts with a few extra zeros push the ZINB dispersion to
	# the Poisson boundary, so fast_zinb_cpp refits as a ZIP and reports the
	# result as a ZINB fit. The score it returns must still have one entry per
	# ZINB parameter (dispersion included), matching the zero-padded Hessian.
	set.seed(1)
	n <- 30
	x <- rnorm(n)
	w <- rbinom(n, 1, 0.5)
	y <- rpois(n, exp(0.3 + 0.2 * x))
	y[sample(n, 5)] <- 0
	X <- cbind(1, w, x)
	Xzi <- cbind(1, w, x)
	n_par <- ncol(X) + ncol(Xzi) + 1L

	fit <- EDI:::fast_zinb_cpp(X = X, Xzi = Xzi, y = as.numeric(y), fixed_idx = 2L, fixed_values = 0, estimate_only = FALSE)
	expect_identical(fit$reduced_model, "ZIP")
	expect_true(isTRUE(fit$dispersion_at_poisson_boundary))
	expect_length(fit$params, n_par)
	# The reduced ZIP refit must honour the requested fixed parameter (the
	# treatment coefficient, index 2), not the one before it (the intercept).
	expect_identical(fit$params[2], 0)
	expect_false(identical(fit$params[1], 0))
	expect_length(fit$score, n_par)
	expect_identical(dim(fit$observed_information), c(n_par, n_par))
	expect_identical(fit$score[n_par], 0)

	res <- EDI:::score_test_from_score_information_cpp(fit$score, fit$observed_information, 2L)
	expect_true(is.finite(res$p_value))
	expect_gte(res$p_value, 0)
	expect_lte(res$p_value, 1)
})

test_that("InferenceCountZeroInflatedNegBin score test works at the Poisson dispersion boundary", {
	# Before the fix this seed errored with
	# "tested_idx must be a one-based index within the parameter vector"
	# because the ZIP-reduced null fit returned a (p-1)-length score.
	set.seed(2)
	n <- 30
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	y <- rpois(n, exp(0.3 + 0.2 * x))
	y[sample(n, 5)] <- 0
	des$add_all_subject_responses(ys = y)

	inf <- InferenceCountZeroInflatedNegBin$new(des)
	expect_true(is.finite(inf$compute_estimate()))
	pval <- inf$compute_score_two_sided_pval()
	expect_true(is.finite(pval))
	expect_gte(pval, 0)
	expect_lte(pval, 1)
})
