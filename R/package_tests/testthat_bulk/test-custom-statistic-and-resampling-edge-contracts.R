library(testthat)
library(EDI)

test_that("user C++ signature matching ignores whitespace and argument names", {
	expect_true(EDI:::user_cpp_xptr_args_match(
		c("const Eigen::VectorXd & y", "const Eigen::VectorXd& w"),
		EDI:::EDI_USER_CPP_SIGNATURES$rand_stat$args
	))
	expect_false(EDI:::user_cpp_xptr_args_match("const Eigen::VectorXd& y", EDI:::EDI_USER_CPP_SIGNATURES$rand_stat$args))
	expect_false(EDI:::user_cpp_xptr_args_match(c("int y", "int w"), EDI:::EDI_USER_CPP_SIGNATURES$rand_stat$args))
	expect_error(EDI:::normalize_user_cpp_fn(1, "probe", "unknown"), "Unknown user")
	expect_error(EDI:::normalize_user_cpp_fn(function(x) x, "probe", "rand_stat"), "not an R function")
	expect_error(EDI:::normalize_user_cpp_fn(c("a", "b"), "probe", "rand_stat"), "single string")
	expect_error(EDI:::normalize_user_cpp_fn(1, "probe", "rand_stat"), "got a numeric")
	expect_error(EDI:::assert_custom_objective_xptr(NULL), "custom_objective is required")
	ptr = new("externalptr")
	normalized = EDI:::normalize_user_cpp_fn(ptr, "probe", "rand_stat")
	expect_identical(normalized$xptr, ptr)
	expect_null(normalized$src)
})

test_that("custom randomization statistics evaluate both callback arities without compilation", {
	set.seed(1101)
	des = DesignFixedBernoulli$new(n = 12L, response_type = "continuous", seed = 1101L)
	des$add_all_subjects_to_experiment(data.frame(x = 1:12))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.numeric(1:12))
	stat = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0])
	inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = stat)
	p = inf$.__enclos_env__$private
	expect_equal(inf$fit()$estimate, stat(1:12, des$get_w(), NULL))
	expect_equal(p$evaluate_stat(1:4, c(0, 0, 1, 1), NULL, function(y, w) sum(y * w)), 7)
	expect_equal(p$evaluate_stat(1:4, c(0, 0, 1, 1), c(1, 0, 1, 0), function(y, w, dead) sum(y * dead)), 4)
	expect_error(InferenceRandCustom$new(des), "requires")
	expect_error(InferenceRandCustom$new(des, stat, function(y, w) 1), "not both")
	expect_error(p$install_stat_cpp(function(y) 1), "2 arguments")
	expect_error(p$install_stat_cpp(1), "not a numeric")
	expect_error(p$install_stat_cpp(new("externalptr")), "recorded signature")
})

test_that("resample-size selector distinguishes objectives and finite eligibility", {
	set.seed(1102)
	des = DesignFixedBernoulli$new(n = 20L, response_type = "continuous", seed = 1102L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(20))
	inf = InferenceContinOLS$new(des)
	p = inf$.__enclos_env__$private
	eval = function(size) list(estimate = 2, ci = c(0, 4), pval = .25, finite_fraction = .5, n_finite = 5L, status = "ok")
	penalized = p$select_optimal_resample_size(3:5, eval, objective = "finite_fraction_penalized_ci_width", min_finite_fraction = .4)
	expect_equal(penalized$grid_table$objective_value, rep(8, 3))
	expect_identical(penalized$size_optimal, 4L)
	stability = p$select_optimal_resample_size(3:5, eval, objective = "estimate_stability", min_finite_fraction = .8)
	expect_equal(stability$grid_table$objective_value, rep(2, 3))
	expect_identical(stability$status, "nonestimable")
	expect_null(p$get_bartlett_factor_approx(NULL, 0, NULL, NULL, B = 5L))
	expect_true(is.logical(p$supports_bartlett_likelihood_ratio_approx()))

	expect_identical(p$resampling_scaling_key(function(n) sqrt(n)), "<function>")
	expect_identical(p$resampling_scaling_key(list(rate_exponent = .5)), "rate_exponent 0.5")
	expect_true(is.na(p$resampling_centered_pval(numeric(), 1, 0, 20L)))
	expect_true(all(is.na(p$resampling_ci_from_centered_distribution(numeric(), .05, 1, 20L))))
})
