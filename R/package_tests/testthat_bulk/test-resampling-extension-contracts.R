library(testthat)
library(EDI)

make_extension_probe = function(n = 20L, seed = 710L, parametric = FALSE) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.7 * w + rnorm(n))
	if (parametric) InferenceContinOLS$new(des) else InferenceAllSimpleAverageDiff$new(des)
}

test_that("exchangeable-unit helpers resolve, allocate, and materialize observation draws", {
	inf = make_extension_probe()
	p = inf$.__enclos_env__$private
	p$shared()

	expect_identical(p$resolve_resampling_unit("AUTO"), "observation")
	expect_identical(p$resolve_resampling_unit("block"), "block")
	expect_error(p$resolve_resampling_unit("subject"), "unit")
	units = p$get_exchangeable_units("observation")
	expect_identical(units$unit_type, "observation")
	expect_identical(units$n_units, 20L)
	expect_identical(units$units[[7]], 7L)

	expect_identical(p$resolve_resampling_size(NULL, 20L, "m"), 8L)
	expect_error(p$resolve_resampling_size(list(select = TRUE), 20L, "m"), "resolved before drawing")
	expect_error(p$resolve_resampling_size(4L, 20L, "m"), "5 <= m <= 10")

	stratified = units
	stratified$strata_ids = rep(c("a", "b"), c(8, 12))
	alloc = p$allocate_resampling_sizes_by_stratum(7L, stratified$strata_ids, replace = FALSE)
	expect_equal(unname(alloc), c(3L, 4L))
	expect_equal(sum(alloc), 7L)
	set.seed(1)
	ids = p$sample_exchangeable_unit_ids(stratified, 7L, replace = FALSE, stratified = TRUE)
	expect_length(ids, 7L)
	expect_false(anyDuplicated(ids) > 0L)

	draw = p$build_resampling_draw_from_units(units, c(5L, 2L), "m", preserve_order = TRUE)
	expect_identical(draw$i_b, c(2L, 5L))
	expect_identical(draw$unit_ids, c(5L, 2L))
	expect_identical(draw$m, 2L)
	empty = p$build_resampling_draw_from_units(units, integer(), "m")
	expect_identical(empty, list(i_b = integer(), m_vec_b = NULL))
})

test_that("minimum-volatility selection applies tie, failure, and no-selection contracts", {
	p = make_extension_probe()$.__enclos_env__$private
	evaluator = function(size) list(
		estimate = size / 10, ci = c(-size, size), pval = 0.5,
		n_finite = 10L, finite_fraction = 1, status = "ok"
	)
	selected = p$select_optimal_resample_size(
		c(5L, 3L, 4L, 4L, 6L), evaluator,
		objective = "pval_stability", volatility_window = 3L,
		size_name = "m", exponent_grid = c(.5, .3, .4, .9, .6)
	)
	expect_s3_class(selected, "EDIResampleSizeSelection")
	expect_identical(selected$status, "ok")
	expect_identical(selected$m_optimal, 4L)
	expect_equal(selected$m_pow_of_n_optimal, .4)
	expect_identical(selected$tie_rule, "smallest_size")

	failed = p$select_optimal_resample_size(
		3:5, function(size) stop("deliberate evaluator failure"),
		min_finite_fraction = 1
	)
	expect_identical(failed$status, "nonestimable")
	expect_match(failed$grid_table$dominant_failure_reason[[1]], "deliberate")

	unselected = p$select_optimal_resample_size(3:5, evaluator, select = FALSE)
	expect_null(unselected$status)
	expect_null(unselected$size_optimal)
	expect_error(p$select_optimal_resample_size(1:4, evaluator, volatility_window = 2L), "odd integer")
	expect_error(p$select_optimal_resample_size(1:2, evaluator), "at least volatility_window")
})

test_that("parametric-bootstrap coefficient and hardening helpers reject malformed extremes", {
	p = make_extension_probe(parametric = TRUE)$.__enclos_env__$private
	expect_equal(p$extract_param_bootstrap_estimate_coef(list(b = c(2, 7)), 2L), 7)
	expect_equal(p$extract_param_bootstrap_estimate_coef(list(params = c(3, 8)), 1L), 3)
	expect_equal(p$extract_param_bootstrap_estimate_coef(list(coefficients = c(4, 9)), 2L), 9)
	expect_true(is.na(p$extract_param_bootstrap_estimate_coef(NULL, 1L)))
	expect_true(is.na(p$extract_param_bootstrap_estimate_coef(list(b = 1), 2L)))
	expect_true(is.na(p$extract_param_bootstrap_estimate_coef(list(b = 1), integer())))

	expect_false(p$param_bootstrap_estimate_extreme(c(NA, Inf), max_abs = 10))
	expect_false(p$param_bootstrap_estimate_extreme(c(-2, 2), max_abs = 10))
	expect_true(p$param_bootstrap_estimate_extreme(c(1, 11), max_abs = 10))
	expect_false(p$param_bootstrap_confidence_interval_extreme(c(NA, 1), max_abs = 10))
	expect_false(p$param_bootstrap_confidence_interval_extreme(c(-2, 2), max_abs = 10))
	expect_true(p$param_bootstrap_confidence_interval_extreme(c(-11, 1), max_abs = 10))
	expect_true(is.finite(p$param_bootstrap_estimate_threshold()))
})

test_that("m-out-of-n and PRW extensions validate scaling, centering, and sizes", {
	inf = make_extension_probe()
	p = inf$.__enclos_env__$private
	expect_equal(p$resampling_scaling_factor(9L, "sqrt_n"), 3)
	expect_equal(p$resampling_scaling_factor(9L, list(rate_exponent = 1)), 9)
	expect_equal(p$resampling_scaling_factor(9L, function(n) n / 3), 3)
	expect_error(p$resampling_scaling_factor(9L, "linear"), "Unsupported resampling scaling")
	expect_error(
		inf$approximate_subsampling_distribution_beta_hat_T(B = 3, b = 11, show_progress = FALSE),
		"b must satisfy"
	)
	expect_error(
		inf$compute_m_out_of_n_bootstrap_two_sided_pval(type = "basic", B = 5, m = 8, show_progress = FALSE),
		"type"
	)
	expect_error(
		inf$compute_subsampling_confidence_interval(type = "studentized", B = 5, b = 8, show_progress = FALSE),
		"type"
	)
})

test_that("abstract summary and KK compound ladders expose their defining contracts", {
	expect_identical(EDI:::InferenceMLEorKMSummaryTable$get_inherit(), EDI:::InferenceAsymp)
	expect_identical(EDI:::InferenceKKPassThroughCompound$get_inherit(), EDI:::InferenceParamBootstrap)
	expect_identical(EDI:::InferenceKKPassThroughCompoundNoParamBootstrap$get_inherit(), EDI:::InferenceAsympLik)
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(EDI:::InferenceKKPassThroughCompound$public_methods))
	expect_true("compute_asymp_confidence_interval" %in% names(EDI:::InferenceMLEorKMSummaryTable$public_methods))
})
