library(testthat)
library(EDI)

# v1.0.6-TODO-2 (owner decision 2026-11-19): a bootstrap-family p-value computed with
# na.rm = TRUE needs at least min_fraction_usable_samples (default 0.95) of its replicates to
# be finite. Below it the p-value is NA, the classed reason is recorded in
# procedure_failure_reason, and one edi_procedure_na_warning is raised (silent inside an outer
# resampling operation). na.rm = FALSE is unchanged, and at or above the threshold the p-value
# is bit-identical to the unguarded one (min_fraction_usable_samples = 0). Covers the
# nonparametric bootstrap, the Bayesian bootstrap and the randomization bootstrap. Draws are
# stubbed so the finite fraction is exact.

make_cont_design = function(){
	set.seed(3); n = 60
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	des
}

stub_method = function(env, name, f){
	unlockBinding(name, env)
	assign(name, f, envir = env)
	lockBinding(name, env)
}

collect_warnings = function(expr){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns), all = warns)
}

# B draws, n_finite of them finite (deterministic, centred near the estimate), the rest NA.
draws_with_finite = function(B, n_finite){
	set.seed(11)
	c(0.5 + rnorm(n_finite, sd = 0.3), rep(NA_real_, B - n_finite))
}

failure_reason = function(inf, procedure){
	inf$.__enclos_env__$private$cached_values$procedure_failure_reason[[procedure]]
}

B = 100L  # 0.95 * B = 95 finite draws needed

# ---- nonparametric bootstrap -------------------------------------------------------------

np_inf = function(n_finite){
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	inf$num_cores = 1L
	stub_method(inf, "approximate_bootstrap_distribution_beta_hat_T", function(...) draws_with_finite(B, n_finite))
	inf
}

test_that("bootstrap p-value: just below 95% valid is NA with a recorded reason and one warning", {
	inf = np_inf(94L)
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "bootstrap_too_few_valid_replicates_fraction")
	expect_identical(failure_reason(inf, "bootstrap"), "bootstrap_too_few_valid_replicates_fraction")
	expect_false(inf$is_nonestimable("any"))  # a procedure failure keeps the Wald state
})

test_that("bootstrap p-value: at and above 95% valid is finite, silent and bit-identical to the unguarded value", {
	for (k in c(95L, 96L, 100L)) for (type in c("percentile", "symmetric")) {
		inf = np_inf(k)
		res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = type, na.rm = TRUE, show_progress = FALSE))
		expect_length(res$all, 0L)
		expect_true(is.finite(res$value))
		unguarded = inf$compute_bootstrap_two_sided_pval(B = B, type = type, na.rm = TRUE, show_progress = FALSE,
			min_fraction_usable_samples = 0)
		expect_identical(res$value, unguarded)
		expect_null(failure_reason(inf, "bootstrap"))
	}
	# the percentile formula on the 95 finite draws, written out
	inf = np_inf(95L)
	est = as.numeric(inf$compute_estimate())[1L]
	d = draws_with_finite(B, 95L); d = d[is.finite(d)]
	null = d - mean(d)
	expected = min(1, max(2 / 95, 2 * min(sum(null >= est) / 95, sum(null <= est) / 95)))
	expect_identical(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE), expected)
})

test_that("bootstrap p-value: user-set thresholds 0.5 and 1", {
	inf = np_inf(50L)
	expect_true(is.finite(suppressWarnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE,
		show_progress = FALSE, min_fraction_usable_samples = 0.5))))
	inf = np_inf(49L)
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE,
		show_progress = FALSE, min_fraction_usable_samples = 0.5))
	expect_true(is.na(res$value))
	expect_identical(res$na[[1L]]$reason, "bootstrap_too_few_valid_replicates_fraction")
	inf = np_inf(99L)
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE,
		show_progress = FALSE, min_fraction_usable_samples = 1))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	inf = np_inf(100L)
	expect_true(is.finite(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE,
		show_progress = FALSE, min_fraction_usable_samples = 1)))
})

test_that("bootstrap p-value: na.rm = FALSE is unchanged (NA on any non-finite draw, nonfinite warning only)", {
	inf = np_inf(94L)
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = FALSE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
	expect_true(any(vapply(res$all, inherits, logical(1), "edi_bootstrap_nonfinite_na_warning")))
	expect_null(failure_reason(inf, "bootstrap"))
	# and the threshold argument does not matter there
	inf = np_inf(100L)
	expect_identical(
		inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = FALSE, show_progress = FALSE),
		inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = FALSE, show_progress = FALSE, min_fraction_usable_samples = 1))
})

test_that("bootstrap p-value: too few for min_number_usable_samples keeps its own reason", {
	inf = np_inf(3L)
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "bootstrap_too_few_finite_estimates")
})

test_that("bootstrap p-value: studentized path applies the fraction to estimate-and-SE replicates", {
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	priv = inf$.__enclos_env__$private
	stub_method(priv, "approximate_bootstrap_statistics_beta_hat_T", function(B = 501, na.rm = TRUE, ...) {
		theta = draws_with_finite(B, 90L); se = ifelse(is.finite(theta), 0.3, NA_real_)
		if (isTRUE(na.rm)) { ok = is.finite(theta); theta = theta[ok]; se = se[ok] }
		list(theta = theta, se = se)
	})
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "studentized", na.rm = TRUE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "bootstrap_too_few_valid_replicates_fraction")
})

test_that("bootstrap p-value: silent inside an outer resampling operation (reason still recorded)", {
	inf = np_inf(94L)
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "jackknife"
	res = collect_warnings(inf$compute_bootstrap_two_sided_pval(B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE))
	priv$active_resampling_operation = NULL
	expect_true(is.na(res$value))
	expect_length(res$all, 0L)
	expect_identical(failure_reason(inf, "bootstrap"), "bootstrap_too_few_valid_replicates_fraction")
})

test_that("min_fraction_usable_samples is validated", {
	inf = np_inf(100L)
	for (bad in list(-0.01, 1.01, NA_real_, c(0.5, 0.9), "0.95", Inf)) {
		expect_error(inf$compute_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE, min_fraction_usable_samples = bad))
		expect_error(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE, min_fraction_usable_samples = bad))
		expect_error(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE, min_fraction_usable_samples = bad))
	}
})

# ---- Bayesian bootstrap -------------------------------------------------------------------

bb_inf = function(n_finite){
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	inf$num_cores = 1L
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(...) draws_with_finite(B, n_finite))
	inf
}

test_that("Bayesian-bootstrap p-value: boundary fractions, reason, warning once, identical above", {
	inf = bb_inf(94L)
	res = collect_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "Bayesian bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "bayesian_bootstrap_too_few_valid_replicates_fraction")
	expect_identical(failure_reason(inf, "bayesian_bootstrap"), "bayesian_bootstrap_too_few_valid_replicates_fraction")
	for (k in c(95L, 96L)) for (type in c("percentile", "symmetric", "wald")) {
		inf = bb_inf(k)
		res = collect_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, type = type, na.rm = TRUE, show_progress = FALSE))
		expect_length(res$all, 0L)
		expect_true(is.finite(res$value))
		expect_identical(res$value, inf$compute_bayesian_bootstrap_two_sided_pval(B = B, type = type, na.rm = TRUE,
			show_progress = FALSE, min_fraction_usable_samples = 0))
	}
	inf = bb_inf(50L)
	expect_true(is.finite(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE,
		min_fraction_usable_samples = 0.5)))
	inf = bb_inf(99L)
	expect_true(is.na(suppressWarnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = TRUE,
		show_progress = FALSE, min_fraction_usable_samples = 1))))
	# na.rm = FALSE unchanged
	inf = bb_inf(94L)
	res = collect_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = FALSE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
	expect_identical(failure_reason(inf, "bayesian_bootstrap"), "bayesian_bootstrap_nonfinite_estimates")
	# silent inside an outer resampling operation
	inf = bb_inf(94L)
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "non_param_boot"
	res = collect_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE))
	priv$active_resampling_operation = NULL
	expect_true(is.na(res$value))
	expect_length(res$all, 0L)
})

# ---- randomization bootstrap --------------------------------------------------------------

rb_inf = function(n_finite){
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	inf$num_cores = 1L
	stub_method(inf, "approximate_rand_bootstrap_distribution_beta_hat_T", function(B = 501, ...) draws_with_finite(B, n_finite) - 0.5)
	inf
}

test_that("randomization-bootstrap p-value: boundary fractions, reason, warning once, identical above", {
	inf = rb_inf(94L)
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE))  # na.rm = TRUE is its default
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "randomization-bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "rand_bootstrap_too_few_valid_replicates_fraction")
	expect_identical(failure_reason(inf, "rand_bootstrap"), "rand_bootstrap_too_few_valid_replicates_fraction")
	for (k in c(95L, 96L, 100L)) {
		inf = rb_inf(k)
		res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE))
		expect_length(res$all, 0L)
		expect_true(is.finite(res$value))
		expect_identical(res$value, inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE,
			min_fraction_usable_samples = 0))
	}
	inf = rb_inf(50L)
	expect_true(is.finite(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE, min_fraction_usable_samples = 0.5)))
	inf = rb_inf(99L)
	expect_true(is.na(suppressWarnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE,
		min_fraction_usable_samples = 1))))
	# below the randomization floor (max(10, 10%)) the existing reason is kept
	inf = rb_inf(5L)
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "randomization_too_few_finite_estimates")
	# na.rm = FALSE unchanged: NA, no fraction reason
	inf = rb_inf(94L)
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
	expect_null(failure_reason(inf, "rand_bootstrap"))
	# silent inside an outer resampling operation
	inf = rb_inf(94L)
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "non_param_boot"
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE))
	priv$active_resampling_operation = NULL
	expect_true(is.na(res$value))
	expect_length(res$all, 0L)
})
