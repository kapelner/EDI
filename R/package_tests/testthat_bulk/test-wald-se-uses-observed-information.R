# v1.0.6-TODO-156 item (1) (owner decision 2026-11-19, option b): Wald standard
# errors, p-values and CIs always use the observed information, whatever
# set_information_preference() says; the preference ("fisher" by default where
# the class supports it) applies to score tests and score CIs only. Covers the
# fallback Wald path used when the fit's own ssq_b_j is not finite, the
# information-matrix SE helper, and get_information_source_used().
library(testthat)
library(EDI)

wald_obs_ordinal_design = function(seed = 8L, n = 60L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(as.numeric(cut(0.7 * w + 0.6 * X$x1 + rlogis(n), c(-Inf, -1, 0, 1, Inf), labels = FALSE)))
	des
}

wald_obs_ordinal_classes = c(
	"InferenceOrdinalPropOddsRegr", "InferenceOrdinalOrderedProbitRegr",
	"InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr"
)

wald_obs_se_from = function(inf, preference){
	priv = inf$.__enclos_env__$private
	spec = priv$get_likelihood_test_spec()
	info = priv$get_information_matrix(spec = spec, preference = preference)
	sqrt(solve(info)[spec$j, spec$j])
}

test_that("ordinal cumulative-link Wald inference uses the observed information under every preference", {
	des = wald_obs_ordinal_design()
	for (cls in wald_obs_ordinal_classes) {
		gen = get(cls, envir = asNamespace("EDI"))
		inf_f = gen$new(des, verbose = FALSE)
		inf_f$set_information_preference("fisher")
		inf_o = gen$new(des, verbose = FALSE)
		inf_o$set_information_preference("observed")
		priv_f = inf_f$.__enclos_env__$private

		expect_identical(inf_f$compute_asymp_confidence_interval(), inf_o$compute_asymp_confidence_interval(), info = cls)
		expect_identical(inf_f$compute_asymp_two_sided_pval(), inf_o$compute_asymp_two_sided_pval(), info = cls)
		expect_identical(inf_f$compute_asymp_two_sided_pval(delta = 0.2), inf_o$compute_asymp_two_sided_pval(delta = 0.2), info = cls)

		se_obs = wald_obs_se_from(inf_f, "observed")
		se_fisher = wald_obs_se_from(inf_f, "fisher")
		# The fixture is chosen so the two informations differ visibly.
		expect_gt(abs(se_fisher / se_obs - 1), 1e-4, label = cls)
		# get_standard_error() (Wald fallback, CI-inversion seeds, InferenceSuite's se)
		# is the observed SE, equal to the C++ ssq_b_j SE, not the Fisher one.
		expect_equal(priv_f$get_standard_error(), se_obs, tolerance = 1e-6, info = cls)
		expect_equal(priv_f$get_standard_error(), priv_f$cached_values$s_beta_hat_T, tolerance = 1e-6, info = cls)
		# The summary table reports the same observed SE.
		invisible(utils::capture.output(summ <- inf_f$get_summary()))
		expect_equal(unname(summ["treatment", 2]), priv_f$cached_values$s_beta_hat_T, info = cls)
	}
})

test_that("the Wald fallback used when ssq_b_j is not finite uses the observed information under 'fisher'", {
	des = wald_obs_ordinal_design()
	for (cls in wald_obs_ordinal_classes) {
		gen = get(cls, envir = asNamespace("EDI"))
		inf = gen$new(des, verbose = FALSE)
		inf$set_information_preference("fisher")
		priv = inf$.__enclos_env__$private
		est = inf$compute_estimate()
		priv$shared(estimate_only = FALSE)
		se_obs = wald_obs_se_from(inf, "observed")
		se_fisher = wald_obs_se_from(inf, "fisher")
		# Simulate a fit whose own treatment variance is unavailable.
		priv$cached_values$s_beta_hat_T = NA_real_
		ci = inf$compute_asymp_confidence_interval(alpha = 0.05)
		half_width = unname(diff(ci)) / 2 / stats::qnorm(0.975)
		expect_equal(half_width, se_obs, tolerance = 1e-8, info = cls)
		expect_false(isTRUE(all.equal(half_width, se_fisher, tolerance = 1e-6)), info = cls)
		expect_equal(inf$compute_asymp_two_sided_pval(), 2 * stats::pnorm(-abs(est / se_obs)), tolerance = 1e-8, info = cls)
	}
})

test_that("the score test still follows the information preference, and Wald calls do not change the source used", {
	des = wald_obs_ordinal_design()
	inf_f = InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)
	inf_o = InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)
	inf_o$set_information_preference("observed")
	expect_identical(inf_f$get_information_preference(), "auto")
	p_f = inf_f$compute_score_two_sided_pval()
	expect_identical(inf_f$get_information_source_used(), "fisher")
	p_o = inf_o$compute_score_two_sided_pval()
	expect_identical(inf_o$get_information_source_used(), "observed")
	expect_false(isTRUE(all.equal(p_f, p_o)))

	# A Wald SE computed after the score test leaves the reported source alone.
	priv = inf_f$.__enclos_env__$private
	invisible(priv$get_standard_error())
	invisible(inf_f$compute_asymp_confidence_interval())
	expect_identical(inf_f$get_information_source_used(), "fisher")

	fresh = InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)
	invisible(fresh$.__enclos_env__$private$get_standard_error())
	expect_null(fresh$get_information_source_used())
})

test_that("the information-matrix SE helper prefers observed, and falls back when a class has no observed information", {
	set.seed(3)
	n = 40L
	des = DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	fisher = diag(c(2, 4))
	observed = diag(c(3, 9))
	both = list(full_fit = list(fisher_information = fisher, observed_information = observed), j = 2L)
	for (pref in c("auto", "fisher", "observed")) {
		p$information_preference = pref
		expect_equal(p$compute_standard_error_from_information_matrix(spec = both), 1 / 3, info = pref)
	}
	fisher_only = list(full_fit = list(fisher_information = fisher), j = 2L)
	p$information_preference = "fisher"
	expect_equal(p$compute_standard_error_from_information_matrix(spec = fisher_only), 0.5)
	p$information_preference = "auto"
	expect_equal(p$compute_standard_error_from_information_matrix(spec = fisher_only), 0.5)
	# The score-test information still follows the preference.
	p$information_preference = "fisher"
	expect_equal(p$get_score_test_information_matrix(both, NULL), fisher)
})
