library(testthat)
library(EDI)

# TODO-115 (CI half): finalize_inverted_ci() can return the Wald interval under a
# score / gradient / LR / Bartlett label (inversion could not bracket), and
# invert_test_pval_confidence_interval() with no likelihood spec inverts Wald
# p-values under such a label. Both are deliberate fallbacks (documented in
# inference_ext_ci_inversion.R) but used to be silent. They now emit a classed
# warning (edi_lik_ci_wald_fallback, which inherits edi_lik_test_wald_fallback)
# once per object and testing type, record cached_values$ci_fallback_reason, and
# leave the returned interval unchanged. Silent in resampling workers and for
# healthy fits.

make_t115c_logit = function() {
	set.seed(2)
	n = 60L
	des = DesignFixediBCRD$new(response_type = "incidence", n = n, design_formula = ~ x1, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = sample(rep(0:1, n / 2L))
	des$assign_w_to_all_subjects(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	des
}

t115c_priv = function(inf) inf$.__enclos_env__$private

t115c_override_spec = function(inf, fn) {
	priv = t115c_priv(inf)
	orig = priv$get_likelihood_test_spec
	if (bindingIsLocked("get_likelihood_test_spec", priv)) unlockBinding("get_likelihood_test_spec", priv)
	priv$get_likelihood_test_spec = function() fn(orig())
	invisible(inf)
}

# Null refit works at the estimate (so the test p-value there is finite) but fails
# everywhere else, so the root search cannot bracket and the Wald CI is returned.
t115c_fail_off_estimate = function(inf, est) {
	t115c_override_spec(inf, function(spec) {
		f0 = spec$fit_null
		spec$fit_null = function(delta, start = NULL) {
			if (abs(delta - est) < 1e-10) f0(delta, start) else stop("forced off-estimate null-fit failure")
		}
		spec
	})
}

t115c_collect = function(expr) {
	conds = list()
	val = withCallingHandlers(expr, warning = function(w) {
		if (inherits(w, "edi_lik_test_wald_fallback")) conds[[length(conds) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, conds = conds)
}

for (tt in c("score", "gradient", "lik_ratio")) {
	test_that(paste0(tt, " CI: Wald interval substituted -> value unchanged, warns once with the reason, reason recorded"), {
		inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
		est = inf$compute_estimate()
		t115c_fail_off_estimate(inf, est)
		inf$set_testing_type(tt)
		wald = inf$compute_wald_confidence_interval()
		r = t115c_collect(inf$compute_asymp_confidence_interval())
		expect_equal(as.numeric(r$value), as.numeric(wald), tolerance = 1e-12)
		expect_length(r$conds, 1L)
		expect_s3_class(r$conds[[1L]], "edi_lik_ci_wald_fallback")
		expect_identical(r$conds[[1L]]$testing_type, tt)
		expect_match(r$conds[[1L]]$reason, "forced off-estimate null-fit failure", fixed = TRUE)
		expect_match(conditionMessage(r$conds[[1L]]), "Wald interval, NOT a", fixed = TRUE)
		rec = t115c_priv(inf)$cached_values$ci_fallback_reason
		expect_true(tt %in% names(rec))
		expect_match(rec[[tt]], "no finite bounds")
		# second call: same testing type does not warn again, value still the Wald interval
		r2 = t115c_collect(inf$compute_asymp_confidence_interval())
		expect_length(r2$conds, 0L)
		expect_equal(as.numeric(r2$value), as.numeric(wald), tolerance = 1e-12)
	})
}

test_that("NULL likelihood spec: Wald p-values inverted under a likelihood label warn once, value unchanged", {
	for (tt in c("score", "lik_ratio_bartlett_approx")) {
		inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
		inf$compute_estimate()
		t115c_override_spec(inf, function(spec) NULL)
		priv = t115c_priv(inf)
		r = t115c_collect(priv$invert_test_pval_confidence_interval(0.05, testing_type = tt))
		expect_length(r$conds, 1L)
		expect_identical(r$conds[[1L]]$testing_type, tt)
		expect_match(r$conds[[1L]]$reason, "returned NULL")
		expect_true(tt %in% names(priv$cached_values$ci_fallback_reason))
		expect_true(all(is.finite(r$value)))
		r2 = t115c_collect(priv$invert_test_pval_confidence_interval(0.05, testing_type = tt))
		expect_length(r2$conds, 0L)
		expect_equal(as.numeric(r2$value), as.numeric(r$value))
	}
	# testing_type = "wald" is not a substitution: silent
	inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
	inf$compute_estimate()
	t115c_override_spec(inf, function(spec) NULL)
	r = t115c_collect(t115c_priv(inf)$invert_test_pval_confidence_interval(0.05, testing_type = "wald"))
	expect_length(r$conds, 0L)
})

test_that("healthy fit: no Wald-fallback warning and no recorded reason", {
	inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
	for (tt in c("score", "gradient", "lik_ratio")) {
		inf$set_testing_type(tt)
		r = t115c_collect(inf$compute_asymp_confidence_interval())
		expect_true(all(is.finite(r$value)), info = tt)
		expect_length(r$conds, 0L)
	}
	expect_null(t115c_priv(inf)$cached_values$ci_fallback_reason)
})

test_that("resampling worker context: substitution is recorded but never warns", {
	inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
	est = inf$compute_estimate()
	t115c_fail_off_estimate(inf, est)
	priv = t115c_priv(inf)
	priv$active_resampling_operation = "bootstrap"
	inf$set_testing_type("lik_ratio")
	wald = inf$compute_wald_confidence_interval()
	r = t115c_collect(inf$compute_asymp_confidence_interval())
	expect_length(r$conds, 0L)
	expect_equal(as.numeric(r$value), as.numeric(wald), tolerance = 1e-12)
})

test_that("a p-value Wald fallback warning already issued for a type suppresses the CI duplicate", {
	inf = InferenceIncidLogRegr$new(make_t115c_logit(), verbose = FALSE)
	est = inf$compute_estimate()
	t115c_fail_off_estimate(inf, est)
	priv = t115c_priv(inf)
	priv$cached_values$lik_test_wald_fallback_warned = "lik_ratio"
	inf$set_testing_type("lik_ratio")
	r = t115c_collect(inf$compute_asymp_confidence_interval())
	expect_length(r$conds, 0L)
})
