library(testthat)
library(EDI)

# v1.0.6-TODO-191 (owner decision 2026-11-19): the g-computation risk-ratio subsampling and
# m-out-of-n p-values and intervals treat a degenerate draw (an arm with no events or only
# events, or a non-converged or separated logistic fit) as unusable. The replicate comes back
# NaN; when fewer than min_fraction_usable_samples (default 0.8 since v1.0.6-TODO-230; it was 0.95) of
# the B draws are usable the
# method returns NA with a recorded reason and one edi_procedure_na_warning, otherwise the
# pivot uses the usable draws only. The risk difference is unchanged.

make_incid_design = function(seed, n, p = NULL, kk = FALSE){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = if (kk) {
		DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	} else {
		DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	}
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	prob = if (is.null(p)) plogis(-0.4 + 0.5 * X$x1) else rep(p, n)
	des$add_all_subject_responses(rbinom(n, 1, prob))
	des
}

collect_warnings = function(expr){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

failure_reason = function(inf, procedure){
	inf$.__enclos_env__$private$cached_values$procedure_failure_reason[[procedure]]
}

fake_worker_priv = function(y, w, converged = TRUE, n_extreme = 0L){
	env = new.env()
	env$y = y
	env$w = w
	env$cached_values = list(gcomp_fit_converged = converged, gcomp_fit_n_extreme = n_extreme)
	env
}

test_that("degeneracy rule: empty-arm events, all-event arm, non-convergence and separation", {
	is_deg = EDI:::gcomp_rr_resample_is_degenerate
	w = c(0, 0, 0, 1, 1, 1)
	expect_false(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 0), w)))
	expect_true(is_deg(fake_worker_priv(c(0, 0, 0, 1, 1, 0), w)))  # control arm has no events
	expect_true(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 1), w)))  # treated arm has only events
	expect_true(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 0), c(1, 1, 1, 1, 1, 1))))  # one arm empty
	expect_true(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 0), w, converged = FALSE)))
	expect_true(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 0), w, n_extreme = 2L)))
	expect_false(is_deg(fake_worker_priv(c(1, 0, 0, 1, 1, 0), w, converged = NA)))
})

test_that("RR subsampling drops degenerate draws and the p-value uses the usable ones", {
	des = make_incid_design(1005, 80)
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	set.seed(2)
	draws = inf$approximate_subsampling_distribution_beta_hat_T(B = 199, show_progress = FALSE)
	est = inf$compute_estimate()
	expect_gt(sum(is.nan(draws)), 0L)
	expect_lt(sum(is.nan(draws)), 0.05 * 199)
	# The usable draws contain none of the +/-20 atoms.
	usable = draws[is.finite(draws)]
	expect_lt(max(abs(log(usable) - log(est))), 5)
	# The p-value is built from the usable draws only (cached distribution reused).
	set.seed(2)
	res = collect_warnings(inf$compute_subsampling_two_sided_pval(B = 199, show_progress = FALSE))
	priv = inf$.__enclos_env__$private
	n_units = priv$get_exchangeable_units(unit = "auto", resampling_type = NULL)$n_units
	b = priv$resolve_resampling_size(NULL, n_units, "b")
	expected = priv$resampling_centered_pval(sqrt(b) * (log(usable) - log(est)), est = log(est), delta = 0,
		n_units = n_units, scaling = "sqrt_n", symmetric = TRUE)  # v1.0.6-TODO-230
	expect_identical(res$value, expected)
	expect_length(res$na, 0L)
	ci = inf$compute_subsampling_confidence_interval(B = 199, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
})

test_that("more than 20% unusable draws: NA with a recorded reason and one warning (both families, CI too)", {
	des = make_incid_design(1, 40, p = 0.2)
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	set.seed(1)
	res = collect_warnings(inf$compute_subsampling_two_sided_pval(B = 100, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "subsampling_too_few_usable_draws_fraction")
	expect_match(conditionMessage(res$na[[1L]]), "degenerate")
	expect_identical(failure_reason(inf, "subsampling"), "subsampling_too_few_usable_draws_fraction")
	# The Wald estimate survives a procedure failure.
	expect_true(is.finite(inf$compute_estimate()))
	res_ci = collect_warnings(inf$compute_subsampling_confidence_interval(B = 100, show_progress = FALSE))
	expect_true(all(is.na(res_ci$value)))
	expect_length(res_ci$na, 1L)
	# User-settable: min_fraction_usable_samples = 0 keeps the usable draws.
	expect_true(is.finite(suppressWarnings(inf$compute_subsampling_two_sided_pval(B = 100, show_progress = FALSE, min_fraction_usable_samples = 0))))
	set.seed(1)
	res_mn = collect_warnings(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 100, show_progress = FALSE))
	expect_true(is.na(res_mn$value))
	expect_length(res_mn$na, 1L)
	expect_identical(failure_reason(inf, "m_out_of_n"), "m_out_of_n_too_few_usable_draws_fraction")
	res_mn_ci = collect_warnings(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 100, show_progress = FALSE))
	expect_true(all(is.na(res_mn_ci$value)))
	expect_length(res_mn_ci$na, 1L)
})

test_that("KK risk ratio applies the same rule", {
	des = suppressWarnings(make_incid_design(1, 40, p = 0.2, kk = TRUE))
	inf = InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	set.seed(1)
	draws = inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 100, show_progress = FALSE)
	expect_gt(sum(is.nan(draws)), 5L)
	# Between 5% and 20% of the draws are degenerate here: the 0.8 default (v1.0.6-TODO-230)
	# uses the usable ones, a stricter user cap returns NA.
	expect_lt(sum(!is.finite(draws)), 20L)
	res_default = collect_warnings(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 100, show_progress = FALSE))
	expect_true(is.finite(res_default$value))
	expect_length(res_default$na, 0L)
	res = collect_warnings(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 100, show_progress = FALSE, min_fraction_usable_samples = 0.95))
	expect_true(is.na(res$value))
	expect_identical(failure_reason(inf, "m_out_of_n"), "m_out_of_n_too_few_usable_draws_fraction")
})

test_that("risk difference and the ordinary bootstrap never mark draws degenerate", {
	des = make_incid_design(1, 40, p = 0.2)
	inf_rd = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)
	inf_rd$num_cores = 1L
	set.seed(1)
	d_rd = inf_rd$approximate_subsampling_distribution_beta_hat_T(B = 100, show_progress = FALSE)
	expect_false(any(is.nan(d_rd)))
	inf_rr = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf_rr$num_cores = 1L
	set.seed(1)
	d_boot = inf_rr$approximate_bootstrap_distribution_beta_hat_T(B = 50, show_progress = FALSE)
	expect_false(any(is.nan(d_boot)))
})

test_that("min_fraction_usable_samples is validated", {
	des = make_incid_design(1005, 80)
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	expect_error(inf$compute_subsampling_two_sided_pval(B = 20, show_progress = FALSE, min_fraction_usable_samples = NA_real_))
	expect_error(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 20, show_progress = FALSE, min_fraction_usable_samples = 1.5))
})
