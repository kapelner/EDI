library(testthat)
library(EDI)

# v1.0.6-TODO-90: InferenceSurvivalKMDiff returned NA with no warning on interval-censored data
# (asymptotic CI/p-value and the bootstrap CI), although the Turnbull path documents a bootstrap
# fallback. The cause was the bootstrap outcome scale (all-NA private$y -> scale 1 -> any CI wider
# than 5 time units discarded as "extreme"), fixed for general censoring under v1.0.6-TODO-91 /
# v1.0.6-TODO-115. This file pins every KMDiff result on the visit-schedule repro as finite, or NA
# with a warning / clear error; the Bayesian-bootstrap p-value (which cannot weight interval::icfit())
# now stops up front instead of returning a silent NA.

make_km_visit_schedule_design = function(){
	set.seed(7); n = 120
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	t_event = rweibull(n, 1.5, 12 * exp(0.4 * w))
	L = floor(t_event / 3) * 3
	des$add_all_subject_responses(y_Ls = L, y_Rs = L + 3)
	des
}

test_that("KMDiff asymptotic CI and p-value fall back to a real bootstrap on interval-censored data", {
	skip_if_not_installed("interval")
	des = make_km_visit_schedule_design()
	inf = InferenceSurvivalKMDiff$new(des)
	est = inf$compute_estimate()
	expect_true(is.finite(est))

	# The fallback draws B resamples: all finite and not a single repeated value.
	set.seed(1)
	distr = inf$approximate_bootstrap_distribution_beta_hat_T(B = 101, show_progress = FALSE)
	expect_length(distr, 101L)
	expect_true(all(is.finite(distr)))
	expect_gt(length(unique(distr)), 1L)

	expect_no_warning({
		set.seed(1); ci_asymp = InferenceSurvivalKMDiff$new(des)$compute_asymp_confidence_interval()
	})
	set.seed(1)
	ci_boot = InferenceSurvivalKMDiff$new(des)$compute_bootstrap_confidence_interval(show_progress = FALSE)
	expect_true(all(is.finite(ci_asymp)))
	expect_equal(ci_asymp, ci_boot)
	expect_lte(ci_asymp[1], est)
	expect_gte(ci_asymp[2], est)
	expect_gt(ci_asymp[2], ci_asymp[1])

	expect_no_warning({
		set.seed(1); p_asymp = InferenceSurvivalKMDiff$new(des)$compute_asymp_two_sided_pval()
	})
	expect_true(is.finite(p_asymp))
	expect_gte(p_asymp, 0)
	expect_lte(p_asymp, 1)
})

test_that("KMDiff percentile/basic bootstrap and randomization results are finite on interval-censored data", {
	skip_if_not_installed("interval")
	des = make_km_visit_schedule_design()
	for (type in c("percentile", "basic")) {
		set.seed(1)
		ci = InferenceSurvivalKMDiff$new(des)$compute_bootstrap_confidence_interval(B = 101, type = type, show_progress = FALSE)
		expect_true(all(is.finite(ci)), info = type)
	}
	set.seed(1)
	p = InferenceSurvivalKMDiff$new(des)$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE)
	expect_true(is.finite(p))
	set.seed(1)
	p_rand = InferenceSurvivalKMDiff$new(des)$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)
	expect_true(is.finite(p_rand))
})

test_that("KMDiff results without a usable interval-censored method warn or stop, never a silent NA", {
	skip_if_not_installed("interval")
	des = make_km_visit_schedule_design()
	# No per-replicate standard error on the Turnbull path.
	set.seed(1)
	expect_warning(
		{ci = InferenceSurvivalKMDiff$new(des)$compute_bootstrap_confidence_interval(B = 51, type = "studentized", show_progress = FALSE)},
		class = "edi_procedure_na_warning"
	)
	expect_true(all(is.na(ci)))
	# Jackknife of a median: NA with the class's own reason.
	expect_warning(
		{ci_jk = InferenceSurvivalKMDiff$new(des)$compute_jackknife_wald_confidence_interval()},
		class = "edi_km_jackknife_na_warning"
	)
	expect_true(all(is.na(ci_jk)))
	# Bayesian bootstrap cannot weight interval::icfit(): stop up front (was a silent NA p-value).
	inf = InferenceSurvivalKMDiff$new(des)
	expect_error(inf$compute_bayesian_bootstrap_two_sided_pval(B = 21, show_progress = FALSE), "Bayesian bootstrap is not supported")
	# The inherited CI also stops up front now (v1.0.6-TODO-141; was an NA with the misleading
	# "bayesian_bootstrap_too_few_finite_estimates" reason).
	expect_error(
		InferenceSurvivalKMDiff$new(des)$compute_bayesian_bootstrap_confidence_interval(B = 21, show_progress = FALSE),
		"Bayesian bootstrap is not supported"
	)
	expect_error(inf$compute_rand_confidence_interval(), "not supported")
})

test_that("KMDiff Bayesian bootstrap is still available on right-censored data", {
	set.seed(3); n = 60
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	t = rexp(n, 0.1); dead = rbinom(n, 1, 0.8) == 1
	des$add_all_subject_responses(ys = ifelse(dead, t, NA), y_Ls = ifelse(dead, NA, t), y_Rs = ifelse(dead, NA, Inf))
	inf = InferenceSurvivalKMDiff$new(des)
	set.seed(1)
	p = inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, show_progress = FALSE)
	expect_true(is.finite(p))
})
