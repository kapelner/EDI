library(testthat)
library(EDI)

build_resampling_smoke_inference = function(n = 20L, seed = 123L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	for (t in seq_len(n)) {
		des$add_one_subject_response(t, w[t] + stats::rnorm(1, sd = 0.05))
	}
	inf = InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores = 1L
	inf$.__enclos_env__$private$seed = seed
	inf
}

test_that("m-out-of-n bootstrap methods are available and return scalar inference", {
	inf = build_resampling_smoke_inference()
	expect_true(is.function(inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T))
	expect_true(is.function(inf$compute_m_out_of_n_bootstrap_two_sided_pval))
	expect_true(is.function(inf$compute_m_out_of_n_bootstrap_confidence_interval))
	expect_true(is.function(inf$select_optimal_m_out_of_n_bootstrap))

	d = inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 11, m = 8, show_progress = FALSE)
	expect_length(d, 11)
	expect_true(any(is.finite(d)))

	ci = inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 21, m = 8, show_progress = FALSE)
	expect_length(ci, 2)
	expect_true(all(is.finite(ci)))
	expect_lte(ci[1], ci[2])

	p = inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 21, m = 8, show_progress = FALSE)
	expect_true(is.finite(p))
	expect_gte(p, 0)
	expect_lte(p, 1)
})

test_that("NULL is the only automatic m/b size sentinel", {
	inf = build_resampling_smoke_inference()
	expected_size = as.integer(floor(20 ^ 0.7))

	expect_null(formals(inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T)$m)
	expect_null(formals(inf$compute_m_out_of_n_bootstrap_two_sided_pval)$m)
	expect_null(formals(inf$compute_m_out_of_n_bootstrap_confidence_interval)$m)
	expect_null(formals(inf$approximate_subsampling_distribution_beta_hat_T)$b)
	expect_null(formals(inf$compute_subsampling_two_sided_pval)$b)
	expect_null(formals(inf$compute_subsampling_confidence_interval)$b)

	m_dbg = inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 7, show_progress = FALSE, debug = TRUE)
	expect_equal(m_dbg$m, expected_size)

	b_dbg = inf$approximate_subsampling_distribution_beta_hat_T(B = 7, show_progress = FALSE, debug = TRUE)
	expect_equal(b_dbg$b, expected_size)

	expect_error(
		suppressWarnings(inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 7, m = "auto", show_progress = FALSE)),
		"m must satisfy",
		fixed = TRUE
	)
	expect_error(
		suppressWarnings(inf$approximate_subsampling_distribution_beta_hat_T(B = 7, b = "auto", show_progress = FALSE)),
		"b must satisfy",
		fixed = TRUE
	)
})

test_that("PRW subsampling methods are available and return scalar inference", {
	inf = build_resampling_smoke_inference()
	expect_true(is.function(inf$approximate_subsampling_distribution_beta_hat_T))
	expect_true(is.function(inf$compute_subsampling_two_sided_pval))
	expect_true(is.function(inf$compute_subsampling_confidence_interval))
	expect_true(is.function(inf$select_optimal_b_subsampling))
	expect_true(is.function(inf$compute_subsampling_sensitivity))

	d = inf$approximate_subsampling_distribution_beta_hat_T(B = 11, b = 8, show_progress = FALSE)
	expect_length(d, 11)
	expect_true(any(is.finite(d)))

	ci = inf$compute_subsampling_confidence_interval(B = 21, b = 8, show_progress = FALSE)
	expect_length(ci, 2)
	expect_true(all(is.finite(ci)))
	expect_lte(ci[1], ci[2])

	p = inf$compute_subsampling_two_sided_pval(B = 21, b = 8, show_progress = FALSE)
	expect_true(is.finite(p))
	expect_gte(p, 0)
	expect_lte(p, 1)
})

test_that("m-out-of-n and PRW CIs reject extreme finite intervals under hardening", {
	inf = build_resampling_smoke_inference()
	priv = inf$.__enclos_env__$private
	priv$harden = TRUE
	old_width_threshold = priv$bootstrap_extreme_ci_width_threshold
	on.exit({
		priv$bootstrap_extreme_ci_width_threshold = old_width_threshold
	})
	priv$bootstrap_extreme_ci_width_threshold = 1e-12

	m_ci = inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 21, m = 8, show_progress = FALSE)
	expect_true(all(is.na(m_ci)))
	expect_true(inf$is_nonestimable("estimate"))
	expect_match(inf$get_nonestimable_reason(), "m_out_of_n_extreme_confidence_interval", fixed = TRUE)

	inf_sub = build_resampling_smoke_inference()
	priv_sub = inf_sub$.__enclos_env__$private
	priv_sub$harden = TRUE
	old_sub_width_threshold = priv_sub$bootstrap_extreme_ci_width_threshold
	on.exit({
		priv_sub$bootstrap_extreme_ci_width_threshold = old_sub_width_threshold
	}, add = TRUE)
	priv_sub$bootstrap_extreme_ci_width_threshold = 1e-12
	sub_ci = inf_sub$compute_subsampling_confidence_interval(B = 21, b = 8, show_progress = FALSE)
	expect_true(all(is.na(sub_ci)))
	expect_true(inf_sub$is_nonestimable("estimate"))
	expect_match(inf_sub$get_nonestimable_reason(), "subsampling_extreme_confidence_interval", fixed = TRUE)
})

test_that("minimum-volatility selector is shared by m and b methods", {
	inf = build_resampling_smoke_inference()

	m_sel = inf$select_optimal_m_out_of_n_bootstrap(
		B = 9,
		m_grid = c(6L, 7L, 8L),
		show_progress = FALSE,
		min_finite_fraction = 0
	)
	expect_s3_class(m_sel, "EDIMOutOfNBootstrapMSelection")
	expect_true(is.finite(m_sel$m_optimal))
	expect_true(m_sel$m_optimal %in% c(6L, 7L, 8L))
	expect_true(all(c("m", "ci_width", "objective_value", "volatility", "eligible") %in% names(m_sel$grid_table)))

	b_sel = inf$select_optimal_b_subsampling(
		B = 9,
		b_grid = c(6L, 7L, 8L),
		show_progress = FALSE,
		min_finite_fraction = 0
	)
	expect_s3_class(b_sel, "EDISubsamplingBSelection")
	expect_true(is.finite(b_sel$b_optimal))
	expect_true(b_sel$b_optimal %in% c(6L, 7L, 8L))
	expect_true(all(c("b", "ci_width", "objective_value", "volatility", "eligible") %in% names(b_sel$grid_table)))

	sens = inf$compute_subsampling_sensitivity(
		B = 9,
		b_grid = c(6L, 7L, 8L),
		show_progress = FALSE
	)
	expect_s3_class(sens, "EDISubsamplingSensitivity")
	expect_true("grid_table" %in% names(sens))
})

test_that("debug distributions include centered scaled diagnostics", {
	inf = build_resampling_smoke_inference()

	m_dbg = inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 7, m = 8, show_progress = FALSE, debug = TRUE)
	expect_true(all(c("values", "centered_scaled_values", "finite_fraction", "m", "n_units") %in% names(m_dbg)))
	expect_length(m_dbg$values, 7)
	expect_length(m_dbg$centered_scaled_values, 7)

	b_dbg = inf$approximate_subsampling_distribution_beta_hat_T(B = 7, b = 8, show_progress = FALSE, debug = TRUE)
	expect_true(all(c("values", "centered_scaled_values", "finite_fraction", "b", "n_units") %in% names(b_dbg)))
	expect_length(b_dbg$values, 7)
	expect_length(b_dbg$centered_scaled_values, 7)
})

test_that("replacement semantics are explicit: m-out-of-n draws with replacement, PRW subsampling without", {
	inf = build_resampling_smoke_inference()
	priv = inf$.__enclos_env__$private
	priv$shared()

	# m-out-of-n: with replacement. Drawing m = n = 20 units, the probability of
	# seeing NO duplicate unit is 20!/20^20 (~2e-8) per draw -- across 5 draws,
	# a duplicate is a statistical certainty for a with-replacement sampler and
	# impossible for a without-replacement one.
	set.seed(20260814)
	saw_duplicate = FALSE
	for (r in 1:5) {
		m_draw = priv$m_out_of_n_bootstrap_sample_indices(m = 20L)
		expect_length(m_draw$i_b, 20L)
		if (any(duplicated(m_draw$i_b))) saw_duplicate = TRUE
	}
	expect_true(saw_duplicate)

	# PRW subsampling: without replacement. No draw may ever repeat a unit, and
	# each draw has exactly b rows for this observation-level design.
	for (r in 1:20) {
		b_draw = priv$subsampling_sample_indices(b = 12L)
		expect_length(b_draw$i_b, 12L)
		expect_false(any(duplicated(b_draw$i_b)))
	}
})

test_that("m-out-of-n bootstrap and PRW subsampling gate on replicate failure fraction, not just absolute count", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# min_number_usable_samples only checked the ABSOLUTE count of finite
	# replicates (default 5), so even a large majority of resampled fits
	# failing/degenerating still cleared that bar with B in the hundreds --
	# the pivot then got silently built from a small, unrepresentative
	# surviving subset. Found on InferenceIncidKKGEE under a many-covariate
	# formula, where a too-small default m caused ~24% of resampled GEE
	# refits to fail, producing a degenerate two-sided p-value (~0%
	# rejection under both H0 and H1) instead of an honest non-estimable
	# result. Fixed by requiring a majority of replicates to succeed.
	n <- 60L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 456L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	for (t in seq_len(n)) des$add_one_subject_response(t, w[t] + stats::rnorm(1, sd = 0.05))

	ext_env <- new.env(parent = globalenv())
	ext_env$R6Class <- R6::R6Class
	ext_env$InferenceContinOLS <- InferenceContinOLS
	evalq({
		HighFailureResamplingProbe <- R6Class(
			"HighFailureResamplingProbe",
			inherit = InferenceContinOLS,
			public = list(
				approximate_m_out_of_n_bootstrap_distribution_beta_hat_T = function(B = 501, m = NULL, show_progress = TRUE, bootstrap_type = NULL, scaling = "sqrt_n") {
					boot <- rep(NA_real_, B)
					n_finite <- floor(0.3 * B)
					boot[seq_len(n_finite)] <- rnorm(n_finite)
					boot
				},
				approximate_subsampling_distribution_beta_hat_T = function(B = 501, b = NULL, show_progress = TRUE, subsampling_type = NULL, scaling = "sqrt_n") {
					sub <- rep(NA_real_, B)
					n_finite <- floor(0.3 * B)
					sub[seq_len(n_finite)] <- rnorm(n_finite)
					sub
				}
			)
		)
	}, envir = ext_env)

	inf <- ext_env$HighFailureResamplingProbe$new(des, verbose = FALSE)

	p_mn <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 300, show_progress = FALSE)
	expect_true(is.na(p_mn))
	expect_true(inf$is_nonestimable())
	expect_equal(inf$get_nonestimable_reason(), "m_out_of_n_high_replicate_failure_rate")

	inf2 <- ext_env$HighFailureResamplingProbe$new(des, verbose = FALSE)
	p_sub <- inf2$compute_subsampling_two_sided_pval(B = 300, show_progress = FALSE)
	expect_true(is.na(p_sub))
	expect_true(inf2$is_nonestimable())
	expect_equal(inf2$get_nonestimable_reason(), "subsampling_high_replicate_failure_rate")
})

test_that("PRW subsampling applies a finite-population correction so Type-I error is not inflated", {
	# Regression for 2026-09-07 fix: subsampling_centered_pivot() and
	# evaluate_subsampling_size() previously reused the m-out-of-n
	# bootstrap's sqrt(b)-scaling formula verbatim, which assumes
	# with-replacement draws. PRW subsampling draws b units WITHOUT
	# replacement, which shrinks the subsample statistic's variance by a
	# factor of ~(1 - b/n) relative to that assumption, making the raw
	# centered pivot too narrow and inflating Type-I error (confirmed via
	# simulation: ~9.75% observed vs 5% nominal at b/n ~ 0.4 before the fix).
	# Dividing the pivot by sqrt(1 - b/n) restores calibration.
	n <- 60L
	b <- floor(n^0.7)
	R <- 60L
	reject <- 0L
	for (r in seq_len(R)) {
		set.seed(90000L + r)
		des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 90000L + r)
		des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
		des$assign_w_to_all_subjects()
		for (t in seq_len(n)) des$add_one_subject_response(t, rnorm(1)) # H0: no treatment effect
		inf <- InferenceAllSimpleAverageDiff$new(des)
		inf$num_cores <- 1L
		p <- tryCatch(inf$compute_subsampling_two_sided_pval(B = 201, b = b, show_progress = FALSE), error = function(e) NA_real_)
		if (is.finite(p) && p < 0.05) reject <- reject + 1L
	}
	expect_lt(reject / R, 0.15)
})

test_that("PRW subsampling FPC factor matches the direct formula", {
	# b is constrained to <= floor(n_units / 2), so the FPC factor never
	# blows up in practice, but subsampling_centered_pivot() still guards
	# the b == n_units edge case with .Machine$double.eps to avoid a
	# division by zero if that constraint is ever relaxed.
	inf <- build_resampling_smoke_inference(n = 20L)
	priv <- inf$.__enclos_env__$private
	unit_info <- priv$get_exchangeable_units(unit = "auto", resampling_type = NULL)
	b <- 8L
	pivot <- priv$subsampling_centered_pivot(B = 51, b = b, unit_info = unit_info, show_progress = FALSE)
	expect_true(isTRUE(pivot$ok))
	raw_scale <- priv$resampling_scaling_factor(b, "sqrt_n") * (pivot$finite - pivot$est)
	fpc <- 1 / sqrt(1 - b / unit_info$n_units)
	expect_equal(pivot$centered_scaled, fpc * raw_scale)
})
