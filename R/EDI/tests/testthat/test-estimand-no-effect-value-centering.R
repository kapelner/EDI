library(testthat)
library(EDI)

# v1.0.6-TODO-179: every p-value path must default to the estimand's own no-effect value.
# Audit (2026-11-19) of EDI_INFERENCE_ESTIMAND_TAGS: the only tag whose reported estimate has
# a no-effect value other than 0 is "RR" (raw risk ratio, null 1), used by the two
# g-computation risk-ratio classes, which resolve `delta = NULL` through
# `default_null_value()`. The stochastic-superiority estimands (mann_whitney_effect,
# stochastic_ordering_trend, sign_test_effect; probability null 0.5) are reported already
# centered (theta - 0.5), so 0 is their correct default. Every other tag is a difference or a
# log / link-scale coefficient (null 0). A new tag must be classified here before it ships.

estimand_tags_null_zero = c(
	"mean_difference", "hodges_lehmann_shift", "quantile_regression_effect",
	"log_rate_ratio_conditional", "log_rate_ratio_marginal", "log_risk_ratio",
	"log_odds_ratio_conditional", "log_odds_ratio_marginal", "log_odds_ratio_adjacent_category",
	"log_odds_ratio_adjacent_category_conditional", "log_odds_ratio_continuation_ratio",
	"log_odds_ratio_proportional", "log_odds_ratio_proportional_conditional",
	"log_odds_ratio_partial_proportional", "logit_effect_proportion_mean_conditional",
	"probit_effect_marginal", "probit_effect_ordinal", "probit_effect_ordinal_conditional",
	"cauchit_link_effect", "cauchit_link_effect_conditional", "cloglog_link_effect",
	"cloglog_link_effect_conditional", "stereotype_link_effect",
	"log_hazard_ratio", "log_time_ratio", "gehan_wilcoxon_statistic",
	"log_rank_martingale_difference", "survival_median_difference",
	"restricted_mean_survival_time_difference",
	# probability-scale estimands reported centered as theta - 0.5
	"mann_whitney_effect", "stochastic_ordering_trend", "sign_test_effect"
)
estimand_tags_null_nonzero = c(RR = 1)

test_that("every estimand tag has a classified no-effect value", {
	tags = unique(unlist(EDI:::EDI_INFERENCE_ESTIMAND_TAGS))
	unclassified = setdiff(tags, c(estimand_tags_null_zero, names(estimand_tags_null_nonzero)))
	expect_identical(unclassified, character(0))
})

rr_fixture = function(cl, n = 60L) {
	set.seed(17)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = if (grepl("KK", cl)) {
		DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	} else {
		DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	}
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.5 * X$x1)))
	get(cl)$new(des, verbose = FALSE)
}

nonzero_null_classes = names(Filter(function(tag) tag %in% names(estimand_tags_null_nonzero),
	EDI:::EDI_INFERENCE_ESTIMAND_TAGS))

test_that("the nonzero-null classes are exactly the two raw risk-ratio g-computation classes", {
	expect_setequal(nonzero_null_classes, c("InferenceIncidGCompRiskRatio", "InferenceIncidKKGCompRiskRatio"))
})

for (cl in nonzero_null_classes) {
	test_that(paste(cl, "declares its no-effect value and every delta-taking p-value defaults to it"), {
		inf = rr_fixture(cl)
		priv = inf$.__enclos_env__$private
		null_value = estimand_tags_null_nonzero[[EDI:::EDI_INFERENCE_ESTIMAND_TAGS[[cl]]]]
		expect_equal(priv$default_null_value(), null_value)
		# Public p-value methods with a `delta` formal must default to NULL (resolved by
		# default_null_value()). Excluded: the *_generic pass-throughs (internal plumbing the
		# overrides call with delta resolved) and the randomization tests, whose `delta` is a
		# sharp-null shift on the response scale, where 0 is no effect.
		pval_methods = grep("_two_sided_pval$", ls(inf), value = TRUE)
		pval_methods = setdiff(pval_methods, c("compute_rand_two_sided_pval", "compute_rand_bootstrap_two_sided_pval"))
		for (m in pval_methods) {
			fm = formals(inf[[m]])
			if (!("delta" %in% names(fm))) next
			expect_null(fm$delta, info = paste(cl, m))
		}
	})

	test_that(paste(cl, "p-values at the default null equal those at delta = RR = 1, not RR = 0"), {
		skip_on_cran()
		inf = rr_fixture(cl)
		B = 49L
		# v1.0.6-TODO-191: subsampling / m-out-of-n RR draws with an empty or all-event arm or a
		# separated fit are unusable, and below the usable-draw cap (0.8 by default since v1.0.6-TODO-230)
		# the p-value is NA by design. On
		# this n = 60 fixture over 5% of the size-17 draws are degenerate (7 of 49 for the non-KK
		# class), so drop the cap here. This test is about the default null (delta = RR = 1), not the usable-draw rule, which
		# test-gcomp-risk-ratio-subsampling-degenerate-draws.R covers.
		frac = 0
		calls = list(
			asymp = function(d) if (is.null(d)) inf$compute_asymp_two_sided_pval() else inf$compute_asymp_two_sided_pval(delta = d),
			jackknife = function(d) if (is.null(d)) inf$compute_jackknife_wald_two_sided_pval() else inf$compute_jackknife_wald_two_sided_pval(delta = d),
			bootstrap = function(d) { set.seed(3); inf$compute_bootstrap_two_sided_pval(delta = d, B = B, na.rm = TRUE, show_progress = FALSE) },
			bayes = function(d) { set.seed(3); inf$compute_bayesian_bootstrap_two_sided_pval(delta = d, B = B, na.rm = TRUE, show_progress = FALSE) },
			subsampling = function(d) { set.seed(3); inf$compute_subsampling_two_sided_pval(delta = d, B = B, show_progress = FALSE, min_fraction_usable_samples = frac) },
			m_out_of_n = function(d) { set.seed(3); inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = d, B = B, show_progress = FALSE, min_fraction_usable_samples = frac) }
		)
		for (nm in names(calls)) {
			p_default = suppressWarnings(calls[[nm]](NULL))
			p_one = suppressWarnings(calls[[nm]](1))
			expect_true(is.finite(p_default), info = paste(cl, nm))
			expect_equal(p_default, p_one, info = paste(cl, nm))
		}
		# A 'null' of RR = 0 is far away and would reject on any data; the default does not.
		expect_gt(inf$compute_asymp_two_sided_pval(), 0.01)
	})
}

test_that("stochastic-superiority estimands are reported centered, so delta = 0 is no effect", {
	n = 40L
	set.seed(23)
	x_dat = data.frame(x1 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	# identical category multisets in the two arms: zero stochastic superiority
	y = integer(n)
	cats = rep(1:4, length.out = max(sum(w == 1), sum(w == 0)))
	y[w == 1] = cats[seq_len(sum(w == 1))]
	y[w == 0] = cats[seq_len(sum(w == 0))]
	expect_equal(sum(w == 1), sum(w == 0))
	des$add_all_subject_responses(y)
	for (cl in c("InferenceOrdinalRidit", "InferenceOrdinalJonckheereTerpstraTest")) {
		inf = get(cl)$new(des, verbose = FALSE)
		expect_equal(inf$compute_estimate(), 0, info = cl)
		expect_equal(inf$compute_asymp_two_sided_pval(), 1, info = cl)
	}

	des_m = DesignFixedBinaryMatch$new(n = 8L, response_type = "ordinal", verbose = FALSE)
	des_m$add_all_subjects_to_experiment(data.frame(x = rnorm(8L)))
	des_m$assign_w_to_all_subjects()
	des_m$add_all_subject_responses(sample(1:4, 8L, replace = TRUE))
	inf = InferenceOrdinalPairedSignTest$new(des_m, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$cached_values$KKstats = list(y_matched_diffs = c(2, -1, 1, -2))
	priv$cached_values$beta_hat_T = NULL
	priv$cached_values$s_beta_hat_T = NULL
	expect_equal(inf$compute_estimate(), 0)
	expect_equal(inf$compute_asymp_two_sided_pval(), 1)
})
