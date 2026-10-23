library(testthat)
library(EDI)

# Regression test (2026-10-23, release_v1_0_5.md TODO-23 / G4-C runbook R4 smoke).
# InferenceSurvivalRestrictedMeanDiff$compute_estimate_with_bootstrap_weights()
# hard-coded s_beta_hat_T = NA, so the studentized / bootstrap-t Bayesian-bootstrap
# CI (and p-value) were nonestimable on every call, with no error or warning. The
# weighted refit now carries a frequency-weighted Greenwood-type (Uno et al.) RMST
# SE that equals the unweighted compute_s_beta_hat_T() at unit weights.

rmst_fixture_design = function(seed = 23001L, n = 120L) {
	set.seed(seed)
	des = DesignFixediBCRD$new(response_type = "survival", n = n)
	des$add_all_subjects_to_experiment(data.frame(x1 = stats::rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	t_event = stats::rexp(n, ifelse(w == 1, 0.3, 0.4))
	cens = ifelse(w == 1, 10, 4)
	time = pmin(t_event, cens)
	for (i in seq_len(n)) {
		if (t_event[i] <= cens[i]) des$add_one_subject_response(i, y = time[i]) else
			des$add_one_subject_response(i, y_L = time[i], y_R = Inf)
	}
	des
}

test_that("weighted RMST SE at unit weights equals the Greenwood SE (default and user tau)", {
	des = rmst_fixture_design()
	for (tau in list(NULL, 3)) {
		inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau)
		priv = inf$.__enclos_env__$private
		inf$compute_estimate()
		se_greenwood = priv$cached_values$s_beta_hat_T
		expect_true(is.finite(se_greenwood) && se_greenwood > 0)
		expect_equal(priv$weighted_restricted_mean_se_diff(rep(1, length(priv$y))), se_greenwood, tolerance = 1e-12)
	}
})

test_that("weighted RMST refit populates a finite SE only when the SE is requested", {
	des = rmst_fixture_design()
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
	set.seed(5)
	wts = stats::rexp(des$get_n())
	wts = wts / mean(wts)
	inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)
	se_w = priv$weighted_refit_se()
	expect_true(is.finite(se_w) && se_w > 0)
	inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE)
	expect_true(is.na(priv$weighted_refit_se()))
})

test_that("RMST Bayesian-bootstrap studentized / bootstrap-t CI and p-value are estimable", {
	des = rmst_fixture_design()
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	est = inf$compute_estimate()
	for (type in c("studentized", "bootstrap-t")) {
		set.seed(11)
		ci = inf$compute_bayesian_bootstrap_confidence_interval(B = 99, type = type, show_progress = FALSE)
		expect_true(all(is.finite(ci)), info = type)
		expect_lt(ci[1L], est)
		expect_gt(ci[2L], est)
	}
	set.seed(11)
	p = inf$compute_bayesian_bootstrap_two_sided_pval(B = 99, type = "studentized", show_progress = FALSE)
	expect_true(is.finite(p) && p >= 0 && p <= 1)
})
