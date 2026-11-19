# v1.0.6-TODO-195 (3): a zero-truncated count density at y = 1 only increases as
# the rate goes to 0, so when every positive count of one arm equals 1 the hurdle
# count part has no finite treatment MLE (pscl::hurdle() "converges" to about -12
# or +12 with a standard error in the hundreds; when every positive count is 1 the
# intercept runs off and the treatment coefficient is arbitrary). Before, only the
# SE was dropped (zero_augmented_data_has_no_mle(), all-ones case only) and the
# optimizer's stopping point was returned as the estimate. Now the estimate is NA
# with a recorded reason and one edi_procedure_na_warning; the resampling paths
# agree (NA on replicates that keep an arm's positive counts all equal to 1).

hurdle_ones_design = function(y, x, w) {
	des = DesignFixediBCRD$new(n = length(y), response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

hurdle_ones_data = function() {
	set.seed(7)
	n = 60
	x = rnorm(n)
	w = sample(rep(0:1, n / 2))
	y = rpois(n, exp(0.4 + 0.3 * w + 0.2 * x)) * rbinom(n, 1, 0.65)
	list(n = n, x = x, w = w, y = y)
}

hurdle_ones_classes = c(InferenceCountHurdlePoisson = "hurdle_count_mle_not_finite",
	InferenceCountHurdleNegBin = "hurdle_negbin_count_mle_not_finite")

test_that("the arms whose positive counts all equal 1 are found from the data", {
	X = cbind(1, w = c(1, 0, 1, 0, 1, 0), x = c(0.1, 0.5, -0.3, 0.2, 0.9, -1))
	expect_equal(zero_augmented_count_mle_infinite_arms(X, c(1, 2, 1, 3, 0, 2)), 1)
	expect_equal(zero_augmented_count_mle_infinite_arms(X, c(2, 1, 3, 1, 0, 0)), 0)
	expect_equal(zero_augmented_count_mle_infinite_arms(X, c(1, 1, 1, 1, 0, 0)), c(0, 1))
	expect_length(zero_augmented_count_mle_infinite_arms(X, c(2, 1, 1, 3, 0, 2)), 0L)
	# an arm without positive rows is the unidentified case, not this one
	expect_length(zero_augmented_count_mle_infinite_arms(X, c(1, 0, 1, 0, 1, 0)), 0L)
	# zero-weight rows do not count
	expect_equal(zero_augmented_count_mle_infinite_arms(X, c(2, 2, 1, 3, 1, 2), weights = c(0, 1, 1, 1, 1, 1)), 1)
	expect_true(zero_augmented_count_mle_infinite(X, c(1, 2, 1, 3, 0, 2)))
})

test_that("pscl::hurdle has no finite count-part treatment estimate on such data", {
	skip_if_not_installed("pscl")
	d = hurdle_ones_data()
	y = d$y
	y[d$w == 1 & y > 0] = 1
	fit = suppressWarnings(pscl::hurdle(y ~ w + x, data = data.frame(y = y, w = d$w, x = d$x), dist = "poisson"))
	# (suppressWarnings: pscl itself warns ".Names is deprecated" on current R)
	expect_gt(abs(suppressWarnings(coef(fit))[["count_w"]]), 8)
	expect_gt(suppressWarnings(sqrt(diag(vcov(fit))))[["count_w"]], 50)
})

test_that("an arm whose positive counts all equal 1 gives NA, a reason and one warning; ordinary data are unchanged", {
	d = hurdle_ones_data()
	for (arm in c(1, 0)) {
		y = d$y
		y[d$w == arm & y > 0] = 1
		for (cls in names(hurdle_ones_classes)) {
			inf = get(cls)$new(hurdle_ones_design(y, d$x, d$w), verbose = FALSE)
			w = tryCatch(inf$compute_estimate(), edi_hurdle_count_mle_not_finite_warning = function(w) w)
			expect_s3_class(w, "edi_procedure_na_warning")
			est = inf$compute_estimate()
			expect_identical(w$reason, hurdle_ones_classes[[cls]])
			expect_true(is.na(est), info = paste(cls, arm))
			expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason, hurdle_ones_classes[[cls]])
			expect_true(is.na(suppressWarnings(inf$compute_asymp_confidence_interval())[1L]), info = paste(cls, arm))
			# the warning is not repeated on later calls
			expect_no_warning(inf$compute_estimate())
		}
	}
	# the untouched data still fit, and match pscl
	for (cls in names(hurdle_ones_classes)) {
		est = suppressWarnings(get(cls)$new(hurdle_ones_design(d$y, d$x, d$w), verbose = FALSE)$compute_estimate())
		expect_true(is.finite(est), info = cls)
		if (requireNamespace("pscl", quietly = TRUE)) {
			ref = suppressWarnings(coef(pscl::hurdle(y ~ w + x, data = data.frame(y = d$y, w = d$w, x = d$x),
				dist = if (grepl("NegBin", cls)) "negbin" else "poisson")))[["count_w"]]
			expect_equal(est, ref, tolerance = 1e-3, info = cls)
		}
	}
})

test_that("bootstrap and randomization replicates agree with the full fit", {
	d = hurdle_ones_data()
	y_t = d$y
	y_t[d$w == 1 & y_t > 0] = 1
	y_all = pmin(d$y, 1)
	for (cls in names(hurdle_ones_classes)) {
		# every positive count is 1: every replicate keeps that, so every one is NA
		inf = get(cls)$new(hurdle_ones_design(y_all, d$x, d$w), verbose = FALSE)
		suppressWarnings(inf$compute_estimate(), classes = "edi_hurdle_count_mle_not_finite_warning")
		set.seed(3)
		expect_true(all(is.na(suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 8, show_progress = FALSE)))), info = cls)
		# treated positives all 1: a bootstrap draw keeps that (NA), a permutation mixes them (finite)
		inf = get(cls)$new(hurdle_ones_design(y_t, d$x, d$w), verbose = FALSE)
		suppressWarnings(inf$compute_estimate(), classes = "edi_hurdle_count_mle_not_finite_warning")
		set.seed(3)
		boot = suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE))
		expect_true(all(is.na(boot)), info = cls)
		set.seed(3)
		rand = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 8, show_progress = FALSE))
		expect_true(all(is.finite(rand)), info = cls)
		expect_lt(max(abs(rand)), 3)
	}
})
