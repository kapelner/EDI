library(testthat)
library(EDI)

information_guard_source_dir = function() {
	candidates = c(
		file.path("R", "EDI", "src"),
		file.path("..", "..", "src"),
		file.path("..", "src"),
		"src"
	)
	hit = candidates[dir.exists(candidates)]
	if (!length(hit)) return(NA_character_)
	hit[[1L]]
}

read_information_guard_source = function(name) {
	dir = information_guard_source_dir()
	if (is.na(dir)) return(NA_character_)
	paste(readLines(file.path(dir, name), warn = FALSE), collapse = "\n")
}

test_that("all formerly bare information inverses use the shared guard", {
	dir = information_guard_source_dir()
	skip_if(is.na(dir), "native source tree is unavailable")

	helper = read_information_guard_source("_helper_functions_core.h")
	expect_match(helper, "invert_free_information", fixed = TRUE)
	expect_match(helper, "information.allFinite()", fixed = TRUE)
	expect_match(helper, "FullPivLU", fixed = TRUE)
	expect_match(helper, "lu.isInvertible()", fixed = TRUE)
	expect_match(helper, "return information.inverse()", fixed = TRUE)
	expect_match(helper, "Eigen::MatrixXd(0, 0)", fixed = TRUE)

	targets = c(
		"fast_negbin_regression.cpp",
		"fast_zinb.cpp",
		"fast_zero_augmented_poisson.cpp",
		"fast_beta_regression.cpp"
	)
	text = vapply(targets, read_information_guard_source, character(1L))
	expect_false(any(grepl("H_free.inverse()", text, fixed = TRUE)))
	expect_equal(sum(lengths(regmatches(text, gregexpr(
		"invert_free_information(H_free, information_invertible)",
		text, fixed = TRUE
	)))), 5L)
	expect_true(all(grepl("information_invertible", text, fixed = TRUE)))
})

test_that("the inverse audit leaves only already-guarded or elementwise sites", {
	dir = information_guard_source_dir()
	skip_if(is.na(dir), "native source tree is unavailable")

	atkinson = read_information_guard_source("atkinson_assign.cpp")
	permutations = read_information_guard_source("generate_permutations.cpp")
	cox = read_information_guard_source("fast_coxph_regression.cpp")
	ordinal = read_information_guard_source("fast_ordinal_regression.cpp")
	zoib = read_information_guard_source("fast_zero_one_inflated_beta.cpp")
	gamma = read_information_guard_source("fast_gamma_functions.h")
	expect_match(atkinson, "if (!lu.isInvertible())", fixed = TRUE)
	expect_match(permutations, "if (!lu.isInvertible())", fixed = TRUE)
	expect_gte(lengths(regmatches(cox, gregexpr("isInvertible()", cox, fixed = TRUE))), 2L)
	expect_gte(lengths(regmatches(ordinal, gregexpr("isInvertible()", ordinal, fixed = TRUE))), 2L)
	expect_match(zoib, "lu.isInvertible()", fixed = TRUE)
	expect_match(gamma, "Eigen::ArrayXd ix = xx.inverse()", fixed = TRUE)
})

test_that("R wrappers use the shared typed standard-error rejection", {
	dir = information_guard_source_dir()
	skip_if(is.na(dir), "native source tree is unavailable")
	r_dir = file.path(dirname(dir), "R")
	if (!dir.exists(r_dir)) skip("R source tree is unavailable")
	read_r = function(name) paste(readLines(file.path(r_dir, name), warn = FALSE), collapse = "\n")

	expect_match(
		read_r("inference_all_abstract_asymp_lik_std_mod_cache.R"),
		'cache_nonestimable_se("model_standard_error_unavailable")', fixed = TRUE
	)
	for (name in c("inference_count_zero_inflated.R", "inference_count_hurdle.R")) {
		expect_match(
			read_r(name),
			'cache_nonestimable_se("model_standard_error_unavailable")', fixed = TRUE
		)
	}
})

test_that("rebuilt count kernels return NaN covariance for duplicated columns", {
	set.seed(20261008L)
	n = 100L
	w = rep(c(0, 1), length.out = n)
	x = rnorm(n)
	X_singular = cbind(`(Intercept)` = 1, treatment = w, x = x, x_duplicate = x)
	Xzi = cbind(`(Intercept)` = 1, treatment = w)
	y_nb = as.integer(rnbinom(n, mu = exp(0.3 + 0.2 * w + 0.1 * x), size = 3))
	probe = fast_neg_bin_with_var_cpp(
		X_singular[, -4L, drop = FALSE], y_nb, smart_cold_start = TRUE
	)
	skip_if(is.null(probe$information_invertible), "requires the rebuilt native library")

	nb = fast_neg_bin_with_var_cpp(
		X_singular,
		y_nb,
		smart_cold_start = TRUE
	)
	expect_false(nb$information_invertible)
	expect_true(all(is.nan(nb$vcov)))

	y_beta = rbeta(n, plogis(0.2 + 0.3 * w) * 8, (1 - plogis(0.2 + 0.3 * w)) * 8)
	beta = fast_beta_regression_with_var_cpp(X_singular, y_beta)
	expect_false(beta$information_invertible)
	expect_true(all(is.nan(beta$vcov)))

	y_count = as.numeric(rpois(n, exp(0.3 + 0.2 * w + 0.1 * x)))
	zap = fast_zero_augmented_poisson_cpp(
		X_singular, y_count, Xzi, is_hurdle = FALSE, estimate_only = FALSE
	)
	expect_false(zap$information_invertible)
	expect_true(all(is.nan(zap$vcov)))

	zinb = fast_zinb_cpp(
		X_singular, Xzi, y_count, estimate_only = FALSE
	)
	expect_false(zinb$information_invertible)
	expect_true(all(is.nan(zinb$vcov)))
})
