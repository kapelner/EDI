library(testthat)
library(EDI)

make_kk_quantile_onelik_rand_ci_design = function(
		response_type, seed, n = 24L, effect = 0.6) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(
		n = n, response_type = response_type, verbose = FALSE
	)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = effect * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8)
		y_i = if (identical(response_type, "continuous")) eta else plogis(eta)
		des$add_one_subject_response(i, y_i)
	}
	des
}

make_kk_quantile_onelik_inference = function(response_type, seed, n = 24L, effect = 0.6) {
	des = make_kk_quantile_onelik_rand_ci_design(response_type, seed, n, effect)
	cls = if (identical(response_type, "continuous")) {
		InferenceContinKKQuantileRegrOneLik
	} else {
		InferencePropKKQuantileRegrOneLik
	}
	cls$new(des, verbose = FALSE)
}

compute_focused_kk_quantile_onelik_rand_ci = function(inf, alpha = 0.2, r = 101L) {
	suppressMessages(inf$compute_rand_confidence_interval(
		alpha = alpha,
		r = r,
		pval_epsilon = 0.05,
		show_progress = FALSE,
		ci_search_control = list(mc_enable = FALSE, high_precision_confirm = FALSE)
	))
}

test_that("KK quantile OneLik classes use generic stacked-estimator randomization inversion", {
	skip_if_not_installed("quantreg")

	expect_identical(
		EDI:::EDI_COMPONENT_SPECS$KKQuantileRegrOneLik$dependencies,
		c("KKCompound", "RandomizationCI")
	)
	for (cls in list(
		InferenceContinKKQuantileRegrOneLik,
		InferencePropKKQuantileRegrOneLik
	)) {
		expect_identical(
			cls$public_methods$compute_rand_confidence_interval,
			EDI:::InferenceRandCI$public_methods$compute_rand_confidence_interval
		)
	}
	# The split-and-combine IVWC estimand still owns the Zhang implementation.
	expect_identical(
		body(InferenceContinKKQuantileRegrIVWC$public_methods$compute_rand_confidence_interval),
		body(EDI:::InferenceExtQuantileRandCI$public$compute_rand_confidence_interval)
	)
})

test_that("KK quantile OneLik randomization CIs are non-degenerate for both response types", {
	skip_if_not_installed("quantreg")

	for (response_type in c("continuous", "proportion")) {
		inf = make_kk_quantile_onelik_inference(response_type, seed = 20260817L)
		inf$set_seed(91L)
		ci = compute_focused_kk_quantile_onelik_rand_ci(inf)
		wald_ci = inf$compute_wald_confidence_interval(alpha = 0.2)
		est = inf$compute_estimate()

		expect_length(ci, 2L)
		expect_true(all(is.finite(ci)))
		expect_gt(ci[2L] - ci[1L], 1e-8)
		expect_lte(ci[1L], est)
		expect_gte(ci[2L], est)
		# A deliberately loose plausibility check: the two interval procedures
		# need only overlap, not agree endpoint-for-endpoint.
		expect_lte(ci[1L], wald_ci[2L])
		expect_gte(ci[2L], wald_ci[1L])
	}
})

test_that("KK quantile OneLik randomization CI coverage no longer collapses near zero", {
	skip_on_cran()
	skip_if_not_installed("quantreg")

	# Twenty seeded repetitions are enough to distinguish the old deterministic
	# zero-width failure (~0% coverage) from a usable 95% CI without turning this
	# focused regression into a full simulation study. Both response classes use
	# the same generic inversion; the test above exercises each concrete leaf.
	truth = 0.4
	covered = logical(20L)
	width = numeric(20L)
	for (rep in seq_along(covered)) {
		inf = make_kk_quantile_onelik_inference(
			"continuous", seed = 9100L + rep, n = 18L, effect = truth
		)
		inf$set_seed(12000L + rep)
		ci = suppressMessages(inf$compute_rand_confidence_interval(
			alpha = 0.05,
			r = 101L,
			pval_epsilon = 0.1,
			show_progress = FALSE,
			ci_search_control = list(
				mc_enable = FALSE, high_precision_confirm = FALSE,
				max_expansions = 3L
			)
		))
		covered[rep] = all(is.finite(ci)) && ci[1L] <= truth && truth <= ci[2L]
		width[rep] = if (all(is.finite(ci))) diff(ci) else NA_real_
	}

	expect_true(all(is.finite(width)))
	expect_true(all(width > 1e-8))
	expect_gte(mean(covered), 0.65)
})
