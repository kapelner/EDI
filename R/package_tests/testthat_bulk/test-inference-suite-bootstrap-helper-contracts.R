library(testthat)
library(EDI)

make_bootstrap_helper_probe = function(n = 24L, seed = 940L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(0.5 * des$get_w() + rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

test_that("InferenceSuite normalizers preserve requested methods and formulas", {
	all_methods = EDI:::run_all_inference_normalize_methods(NULL)
	expect_identical(all_methods$sentinels, EDI:::EDI_INFERENCE_SUITE_METHOD_SENTINELS)
	expect_identical(all_methods$type_requests, list())

	plain = EDI:::run_all_inference_normalize_methods(c("wald", "bootstrap"))
	expect_identical(plain$sentinels, c("wald", "bootstrap"))
	expect_identical(plain$type_requests, list())

	typed = EDI:::run_all_inference_normalize_methods(list(
		bootstrap = c("basic", "bca"), rand_bootstrap = "studentized"
	))
	expect_identical(typed$sentinels, c("bootstrap", "rand_bootstrap"))
	expect_identical(typed$type_requests$bootstrap, c("basic", "bca"))

	expect_null(EDI:::run_all_inference_normalize_formulas(NULL))
	one = EDI:::run_all_inference_normalize_formulas(~ x + z)
	expect_length(one, 1L)
	expect_s3_class(one[[1]], "formula")
	mixed = EDI:::run_all_inference_normalize_formulas(list("~ 1", ~ .))
	expect_true(all(vapply(mixed, inherits, logical(1), "formula")))
})

test_that("InferenceSuite estimand plotting and evidence helpers handle boundaries", {
	expect_true(EDI:::run_all_inference_estimand_use_log10("RR", c(0.5, 1, 2)))
	expect_false(EDI:::run_all_inference_estimand_use_log10("RR", c(0, 1)))
	expect_false(EDI:::run_all_inference_estimand_use_log10("mean_difference", c(1, 2)))
	expect_false(EDI:::run_all_inference_estimand_use_log10(NA_character_, 1))

	expect_equal(EDI:::run_all_inference_combine_pvalues(c(0.1, 0.2)),
		EDI:::run_all_inference_combine_pvalues(c(0.1, 0.2), c(1, 1)))
	empty = EDI:::run_all_inference_combine_pvalues(c(NA, NaN))
	expect_true(is.na(empty$pval))
	expect_identical(empty$n_used, 0L)
	one_weight = EDI:::run_all_inference_combine_pvalues(c(0.1, 0.2), c(1))
	expect_identical(one_weight$n_used, 2L)
	expect_true(is.na(one_weight$pval))

	expect_identical(EDI:::run_all_inference_fmt_secs(0.012), "0s")
	expect_match(EDI:::run_all_inference_fmt_secs(65), "m")
	expect_identical(EDI:::run_all_inference_truncate_1line("abcdef", 4L), "abc…")
	expect_identical(EDI:::run_all_inference_plot_safe_text(c("a", NA)), c("a", NA_character_))
})

test_that("comprehensive slow-path detection respects method types and exact rules", {
	empty_rules = lapply(EDI:::EDI_COMPREHENSIVE_SLOW_PATHS, function(x) character())
	empty_rules$exact_operations = character()
	task = list(cls_name = "ProbeClass", method = "bootstrap", type = "bca", model_formula = NULL)
	expect_false(EDI:::run_all_inference_task_is_comprehensive_slow_path(task, "continuous", empty_rules))

	rules = empty_rules
	rules$boot_ci_bca = "ProbeClass"
	expect_true(EDI:::run_all_inference_task_is_comprehensive_slow_path(task, "continuous", rules))

	rules = empty_rules
	rules$exact_operations = "continuous||ProbeClass||compute_estimate"
	expect_true(EDI:::run_all_inference_task_is_comprehensive_slow_path(task, "continuous", rules))

	unknown = list(cls_name = "ProbeClass", method = "unknown", type = NA_character_, model_formula = NULL)
	expect_false(EDI:::run_all_inference_task_is_comprehensive_slow_path(unknown, "continuous", empty_rules))
})

test_that("sequential Monte Carlo controls and confidence-band stopping are explicit", {
	p = make_bootstrap_helper_probe()$.__enclos_env__$private
	expect_false(p$sequential_mc_control_enabled(NULL))
	expect_false(p$sequential_mc_control_enabled(list(mc_enable = FALSE, mc_stop_threshold = 0.05)))
	expect_false(p$sequential_mc_control_enabled(list(mc_enable = TRUE, mc_stop_threshold = Inf)))
	expect_true(p$sequential_mc_control_enabled(list(mc_enable = TRUE, mc_stop_threshold = 0.05)))

	far = rep(10, 200)
	expect_true(p$sequential_mc_band_excludes_threshold(far, t = 0, threshold = 0.05, conf_level = 0.95))
	mixed = rep(c(-1, 1), 100)
	expect_false(p$sequential_mc_band_excludes_threshold(mixed, t = 0, threshold = 1, conf_level = 0.95))
})

test_that("shared BCa helpers return finite inference and report unstable adjustments", {
	p = make_bootstrap_helper_probe()$.__enclos_env__$private
	set.seed(941)
	boot = rnorm(999, 0.2, 1)
	jack = seq(-1, 1, length.out = 30)
	failures = character()
	on_failure = function(reason) { failures <<- c(failures, reason); c(NA_real_, NA_real_) }
	ci = p$bca_ci_core(boot, 0.05, 0.2, jack, "probe_", on_failure)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
	expect_lte(ci[[1]], ci[[2]])
	expect_length(failures, 0L)

	pval_failure = function(reason) { failures <<- c(failures, reason); NA_real_ }
	pval = p$bca_pval_core(boot, 0.2, 0, jack, "probe_", pval_failure)
	expect_true(is.finite(pval))
	expect_true(pval >= 0 && pval <= 1)

	bad_boot = rep(1, 100)
	bad_ci = p$bca_ci_core(bad_boot, 0.05, 0, jack, "probe_", on_failure)
	expect_true(all(is.na(bad_ci)))
	expect_match(tail(failures, 1), "probe_unstable_bias_or_acceleration")
})

test_that("bootstrap-family introspection exposes distinct supported type sets", {
	inf = make_bootstrap_helper_probe()
	expect_setequal(inf$get_supported_bootstrap_pval_types(), c("percentile", "symmetric", "studentized", "bootstrap-t", "bca"))
	expect_true(all(c("percentile", "basic", "bca", "studentized") %in% inf$get_supported_bootstrap_ci_types()))
	expect_true(all(c("percentile", "studentized", "symmetric-percentile-t", "smoothed") %in%
		inf$get_supported_rand_bootstrap_pval_types()))
	expect_identical(inf$get_supported_rand_bootstrap_ci_types(), inf$get_supported_rand_bootstrap_pval_types())
	expect_true(all(c("percentile", "basic", "bca", "studentized") %in%
		inf$get_supported_bayesian_bootstrap_ci_types()))
})
