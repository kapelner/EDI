# v1.0.6-TODO-204: the usable-draw cap of the generic subsampling / m-out-of-n pivots of the
# ratio-estimand classes (v1.0.6-TODO-164; fixed at ratio_resampling_min_fraction_usable = 0.8)
# is the user argument min_fraction_usable_samples on the four public methods, default 0.8.
# A class with a degenerate-draw rule returns NA (reason <family>_too_few_usable_draws_fraction,
# one edi_procedure_na_warning) below the cap; the cap replaces the fixed 50% failure gate there,
# and is applied on every call, also when the pivot comes from the cache. Other classes ignore it.

library(testthat)
library(EDI)

ratio_cap_methods = c(
	"compute_subsampling_two_sided_pval", "compute_subsampling_confidence_interval",
	"compute_m_out_of_n_bootstrap_two_sided_pval", "compute_m_out_of_n_bootstrap_confidence_interval"
)

# n = 60, 25% events: at b = m = 8 about 45% / 35% of the draws are usable, at 14 about 72% /
# 67%, at 20 about 88% / 81% (B = 101, seed 1; degenerate draws are an arm without events).
ratio_cap_logit_design = function() {
	set.seed(269)
	n = 60L
	d = DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$overwrite_all_subject_assignments(rep(c(1, 0), n / 2L))
	d$add_all_subject_responses(rbinom(n, 1, 0.25))
	d
}

ratio_cap_call = function(o, method, size, cap = NULL, B = 101L) {
	args = list(B = B, show_progress = FALSE)
	args[[if (grepl("m_out_of_n", method)) "m" else "b"]] = size
	if (!is.null(cap)) args$min_fraction_usable_samples = cap
	set.seed(1)
	do.call(o[[method]], args)
}

ratio_cap_usable_fraction = function(o, method, size, B = 101L) {
	set.seed(1)
	draws = if (grepl("m_out_of_n", method)) {
		o$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = B, m = size, show_progress = FALSE)
	} else {
		o$approximate_subsampling_distribution_beta_hat_T(B = B, b = size, show_progress = FALSE)
	}
	mean(is.finite(draws))
}

test_that("the four generic methods take min_fraction_usable_samples with default 0.8", {
	for (method in ratio_cap_methods) {
		f = formals(InferenceNonParamBootstrap$public_methods[[method]])
		expect_true("min_fraction_usable_samples" %in% names(f), info = method)
		expect_identical(f$min_fraction_usable_samples, 0.8, info = method)
		# The g-computation overrides keep the same default.
		expect_identical(formals(InferenceIncidGCompRiskRatio$public_methods[[method]])$min_fraction_usable_samples, 0.8, info = method)
	}
	expect_identical(EDI:::ratio_resampling_min_fraction_usable, 0.8)
})

test_that("min_fraction_usable_samples is validated", {
	o = InferenceIncidLogRegr$new(ratio_cap_logit_design(), verbose = FALSE)
	for (method in ratio_cap_methods) {
		for (bad in list(-0.1, 1.5, NA_real_, "0.5", c(0.5, 0.6), Inf)) {
			expect_error(ratio_cap_call(o, method, 20L, cap = bad, B = 21L), "min_fraction_usable_samples", info = method)
		}
	}
})

test_that("the default equals an explicit 0.8, and the cap decides NA vs a value", {
	d = ratio_cap_logit_design()
	for (method in ratio_cap_methods) {
		is_ci = grepl("confidence_interval", method)
		size = 14L
		frac = ratio_cap_usable_fraction(InferenceIncidLogRegr$new(d, verbose = FALSE), method, size)
		expect_true(frac > 0.5 && frac < 0.8, info = method)
		# Default (0.8) and explicit 0.8: NA with the classed warning naming the reason.
		reason = paste0(if (grepl("m_out_of_n", method)) "m_out_of_n" else "subsampling", "_too_few_usable_draws_fraction")
		expect_warning(v_default <- ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, size),
			reason, class = "edi_procedure_na_warning")
		expect_warning(v_08 <- ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, size, cap = 0.8),
			reason, class = "edi_procedure_na_warning")
		expect_true(all(is.na(v_default)), info = method)
		expect_identical(v_default, v_08)
		# A cap below the usable fraction gives a finite result.
		expect_no_warning(v_low <- ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, size, cap = frac - 0.05))
		expect_true(all(is.finite(v_low)), info = method)
		if (is_ci) expect_length(v_low, 2L)
		# With enough usable draws the default and 0.8 agree on a finite value.
		v20_default = ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, 20L)
		v20_08 = ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, 20L, cap = 0.8)
		expect_true(all(is.finite(v20_default)), info = method)
		expect_identical(v20_default, v20_08)
	}
})

test_that("a cap below 0.5 replaces the fixed 50% failure gate for a ratio estimand", {
	d = ratio_cap_logit_design()
	for (method in ratio_cap_methods) {
		frac = ratio_cap_usable_fraction(InferenceIncidLogRegr$new(d, verbose = FALSE), method, 8L)
		expect_true(frac < 0.5, info = method)
		o = InferenceIncidLogRegr$new(d, verbose = FALSE)
		msgs = character()
		v = withCallingHandlers(ratio_cap_call(o, method, 8L, cap = frac - 0.05),
			warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
		# Neither the usable-draw cap nor the 50% gate fires. (The m-out-of-n CI at m = 8 can
		# still be NA for its own reason, an interval wider than the stability cap.)
		expect_false(any(grepl("too_few_usable_draws_fraction|high_replicate_failure_rate", msgs)), info = method)
		if (method != "compute_m_out_of_n_bootstrap_confidence_interval") expect_true(all(is.finite(v)), info = method)
		expect_true(all(is.na(ratio_cap_call(InferenceIncidLogRegr$new(d, verbose = FALSE), method, 8L, cap = frac + 0.05) |>
			suppressWarnings(classes = "edi_procedure_na_warning"))), info = method)
	}
})

test_that("the cap is applied on every call, also to a cached pivot", {
	d = ratio_cap_logit_design()
	for (method in ratio_cap_methods) {
		o = InferenceIncidLogRegr$new(d, verbose = FALSE)
		v0 = ratio_cap_call(o, method, 14L, cap = 0)
		expect_true(all(is.finite(v0)), info = method)
		# Same B and size: the pivot comes from the cache, but the stricter cap still applies.
		expect_warning(v1 <- ratio_cap_call(o, method, 14L, cap = 1), "too_few_usable_draws_fraction",
			class = "edi_procedure_na_warning")
		expect_true(all(is.na(v1)), info = method)
		expect_identical(ratio_cap_call(o, method, 14L, cap = 0), v0)
	}
})

test_that("a class without a degenerate-draw rule ignores the argument", {
	set.seed(2269)
	n = 40L
	d = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$overwrite_all_subject_assignments(rep(c(1, 0), n / 2L))
	d$add_all_subject_responses(rnorm(n))
	for (method in ratio_cap_methods) {
		v_default = ratio_cap_call(InferenceContinOLS$new(d, verbose = FALSE), method, 15L, B = 51L)
		v_one = ratio_cap_call(InferenceContinOLS$new(d, verbose = FALSE), method, 15L, cap = 1, B = 51L)
		expect_true(all(is.finite(v_default)), info = method)
		expect_identical(v_default, v_one)
	}
})
