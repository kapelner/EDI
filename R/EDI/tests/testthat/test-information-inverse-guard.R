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
	# The zero-dimensional block is the all-fixed / boundary-excluded case. It
	# is valid, while malformed or non-finite free blocks must be rejected before
	# Eigen's inverse can manufacture an apparently usable covariance.
	expect_match(helper, "if (n == 0)", fixed = TRUE)
	expect_match(helper, "information.cols() != n || !information.allFinite()", fixed = TRUE)
	expect_match(helper, "std::numeric_limits<double>::quiet_NaN()", fixed = TRUE)

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
	if (is.null(zinb$covariance_type)) {
		# kernels without cpp patch 07 (TODO-4 ZINB note): the whole covariance is NaN
		expect_true(all(is.nan(zinb$vcov)))
	} else {
		# cpp patch 07: pseudo-inverse covariance; only coordinates loading on the null
		# direction (the duplicated columns 3 and 4: x, x_duplicate) are NaN, the identified
		# intercept / treatment / zero-inflation / dispersion block is finite.
		expect_identical(zinb$covariance_type, "pseudo_inverse_identified_coordinates")
		# 2026-10-23 post-build verification (G1, patch 07 + B07b): y_count is Poisson, so the
		# fit lands on the zero-inflation boundary (zero_inflation_at_boundary = TRUE, zi
		# intercept -10). zinb_zi_information_spec() then conditions on the zi coordinates
		# and expand_free_covariance() leaves them NaN, exactly as on the pre-existing
		# invertible boundary path ("observed_conditional_on_zero_inflation_boundary"); B07b
		# assumed they would be finite. Only intercept / treatment / dispersion are finite here.
		dup = c(3L, 4L)
		zi = if (isTRUE(zinb$zero_inflation_at_boundary)) ncol(X_singular) + seq_len(ncol(Xzi)) else integer(0)
		ok = setdiff(seq_len(nrow(zinb$vcov)), c(dup, zi))
		expect_true(all(is.nan(zinb$vcov[dup, ])))
		expect_true(all(is.nan(zinb$vcov[, dup])))
		if (length(zi)) expect_true(all(is.nan(zinb$vcov[zi, ])))
		expect_true(all(is.finite(zinb$vcov[ok, ok])))
	}
})

test_that("Negative Binomial maps a guarded singular covariance to typed SE non-estimability", {
	set.seed(20261009L)
	n <- 100L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	x <- des$.__enclos_env__$private$Xraw[["x"]]
	des$add_all_subject_responses(as.integer(rpois(n, exp(0.3 + 0.2 * w + 0.1 * x))))
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$harden <- FALSE
	X_data <- private$get_X()
	X_full <- cbind(`(Intercept)` = 1, treatment = private$w,
		as.matrix(X_data), duplicate = as.numeric(X_data[, 1L]))
	colnames(X_full)[ncol(X_full)] <- "x_duplicate"
	private$negbin_X_full_cache <- X_full
	private$negbin_w_cache <- private$w
	private$negbin_X_cov_cache <- X_data

	ci <- inf$compute_asymp_confidence_interval()
	expect_true(all(is.na(ci)))
	expect_true(isTRUE(private$cached_values$nonestimable))
	expect_identical(private$cached_values$nonestimable_reason, "model_standard_error_unavailable")
	expect_identical(private$cached_values$nonestimable_stage, "se")
})
