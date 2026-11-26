library(testthat)
library(EDI)

# v1.0.6-TODO-164: the degenerate-draw rule of v1.0.6-TODO-137 extended to the other ratio
# estimands' subsampling and m-out-of-n paths (InferenceIncidLogRegr, InferenceIncidKKGEE,
# InferenceIncidModifiedPoisson, InferenceIncidLogBinomial, InferenceCountPoisson). A draw in
# which a treatment arm has no events (logit scale: or only events; count: a zero total) or,
# for the logistic regression, a separated fit is NaN (unusable); below 80% usable draws
# (failed NA fits count too) the p-value / interval is NA with a recorded reason and one
# edi_procedure_na_warning. The debug = TRUE distribution path marks the same draws.

make_ratio_design = function(seed, n, response_type = "incidence", p = NULL, kk = FALSE){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = if (kk) {
		DesignFixedBinaryMatch$new(n = n, response_type = response_type, verbose = FALSE)
	} else {
		DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	}
	des$add_all_subjects_to_experiment(X)
	suppressWarnings(des$assign_w_to_all_subjects())
	if (identical(response_type, "count")) {
		des$add_all_subject_responses(rpois(n, if (is.null(p)) exp(-0.5 + 0.3 * X$x1) else p))
	} else {
		des$add_all_subject_responses(rbinom(n, 1, if (is.null(p)) plogis(-0.4 + 0.5 * X$x1) else p))
	}
	des
}

collect_na_warnings = function(expr){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

rule_for = function(inf) EDI:::edi_ratio_resampling_degenerate_rule(inf, inf$.__enclos_env__$private)

test_that("each ratio class has the arm rule of its scale; additive estimands have none", {
	des = make_ratio_design(1, 40)
	logit = rule_for(InferenceIncidLogRegr$new(des, verbose = FALSE))
	w = c(0, 0, 0, 1, 1, 1)
	expect_false(logit$arm(c(1, 0, 0, 1, 0, 1), w))
	expect_true(logit$arm(c(0, 0, 0, 1, 0, 1), w))  # control arm has no events
	expect_true(logit$arm(c(1, 0, 0, 1, 1, 1), w))  # treated arm has only events
	expect_true(is.function(logit$fit))
	for (cls in c("InferenceIncidModifiedPoisson", "InferenceIncidLogBinomial")) {
		log_link = rule_for(get(cls)$new(des, verbose = FALSE))
		expect_true(log_link$arm(c(0, 0, 0, 1, 0, 1), w), info = cls)
		# A risk of 1 in an arm has a finite log risk ratio.
		expect_false(log_link$arm(c(1, 0, 0, 1, 1, 1), w), info = cls)
	}
	count = rule_for(InferenceCountPoisson$new(make_ratio_design(1, 40, "count"), verbose = FALSE))
	expect_true(count$arm(c(0, 0, 0, 2, 0, 1), w))
	expect_false(count$arm(c(3, 0, 0, 2, 2, 1), w))
	expect_false(is.null(rule_for(InferenceIncidKKGEE$new(suppressWarnings(make_ratio_design(1, 40, kk = TRUE)), verbose = FALSE))))
	inf_md = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf_md$set_estimand("marginal_mean_diff")
	expect_null(rule_for(inf_md))
	expect_null(rule_for(InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)))
	expect_null(rule_for(InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)))
})

test_that("logistic subsampling marks degenerate draws NaN and keeps a finite p-value", {
	inf = InferenceIncidLogRegr$new(make_ratio_design(1005, 80), verbose = FALSE)
	inf$num_cores = 1L
	set.seed(2)
	draws = inf$approximate_subsampling_distribution_beta_hat_T(B = 199, show_progress = FALSE)
	expect_gt(sum(is.nan(draws)), 0L)
	expect_lt(mean(is.nan(draws)), 0.2)
	res = collect_na_warnings(inf$compute_subsampling_two_sided_pval(B = 199, show_progress = FALSE))
	expect_true(is.finite(res$value))
	expect_length(res$na, 0L)
})

test_that("debug = TRUE marks the same draws as the reused worker (logistic and g-computation RR)", {
	des = make_ratio_design(1005, 80)
	for (cls in c("InferenceIncidLogRegr", "InferenceIncidGCompRiskRatio")) {
		inf = get(cls)$new(des, verbose = FALSE)
		inf$num_cores = 1L
		set.seed(3)
		plain = inf$approximate_subsampling_distribution_beta_hat_T(B = 100, show_progress = FALSE)
		set.seed(3)
		dbg = inf$approximate_subsampling_distribution_beta_hat_T(B = 100, show_progress = FALSE, debug = TRUE)
		expect_gt(sum(is.nan(plain)), 0L, label = cls)
		expect_identical(is.nan(dbg$values), is.nan(plain), info = cls)
		expect_identical(dbg$num_degenerate, sum(is.nan(plain)), info = cls)
	}
})

test_that("too few usable draws: NA with a recorded reason and one warning (p-value and CI, both families)", {
	# About half of the B = 100 draws are usable at n = 40 with an event rate of 0.15.
	inf = InferenceIncidLogRegr$new(make_ratio_design(1, 40, p = 0.15), verbose = FALSE)
	inf$num_cores = 1L
	set.seed(1)
	res = collect_na_warnings(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 100, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "m_out_of_n_too_few_usable_draws_fraction")
	expect_match(conditionMessage(res$na[[1L]]), "degenerate")
	expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason[["m_out_of_n"]],
		"m_out_of_n_too_few_usable_draws_fraction")
	res_ci = collect_na_warnings(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 100, show_progress = FALSE))
	expect_true(all(is.na(res_ci$value)))
	expect_length(res_ci$na, 1L)
	set.seed(1)
	res_sub = collect_na_warnings(inf$compute_subsampling_two_sided_pval(B = 100, show_progress = FALSE))
	expect_true(is.na(res_sub$value))
	expect_identical(res_sub$na[[1L]]$reason, "subsampling_too_few_usable_draws_fraction")
	# The estimate survives a procedure failure.
	expect_true(is.finite(inf$compute_estimate()))
})

test_that("the ordinary bootstrap and additive estimands keep every draw", {
	des = make_ratio_design(1, 40, p = 0.2)
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$num_cores = 1L
	set.seed(1)
	expect_false(any(is.nan(inf$approximate_bootstrap_distribution_beta_hat_T(B = 40, show_progress = FALSE))))
	inf_md = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf_md$num_cores = 1L
	inf_md$set_estimand("marginal_mean_diff")
	set.seed(1)
	expect_false(any(is.nan(inf_md$approximate_subsampling_distribution_beta_hat_T(B = 40, show_progress = FALSE))))
})

# v1.0.6-TODO-164 (owner decision 2026-11-20): ratio subsampling / m-out-of-n p-values are
# symmetric, mean(|pivot| >= |t_obs|); additive estimands keep the equal-tailed 2 * min(.).
test_that("symmetric centered p-value: formula, floor, and which classes use it", {
	inf = InferenceIncidLogRegr$new(make_ratio_design(1005, 80), verbose = FALSE)
	inf$num_cores = 1L
	priv = inf$.__enclos_env__$private
	cs = c(-3, -1, -0.5, 0, 0.5, 1, 2.5, 4)
	expect_identical(priv$resampling_centered_pval(cs, est = 0.25, delta = 0, n_units = 16, symmetric = TRUE),
		mean(abs(cs) >= 1))
	expect_identical(priv$resampling_centered_pval(cs, est = 0.25, delta = 0, n_units = 16),
		2 * min(mean(cs <= 1), mean(cs >= 1)))
	expect_identical(priv$resampling_centered_pval(cs, est = 10, delta = 0, n_units = 16, symmetric = TRUE), 1 / 8)
	# End to end on the logistic regression's own draws (cached distribution reused).
	set.seed(2)
	p_sub = inf$compute_subsampling_two_sided_pval(B = 199, show_progress = FALSE)
	set.seed(2)
	d = inf$approximate_subsampling_distribution_beta_hat_T(B = 199, show_progress = FALSE)
	est = inf$compute_estimate()
	n_units = priv$get_exchangeable_units(unit = "auto", resampling_type = NULL)$n_units
	b = priv$resolve_resampling_size(NULL, n_units, "b")
	piv = sqrt(b) * (d[is.finite(d)] - est) / sqrt(1 - b / n_units)
	expect_equal(p_sub, max(1 / length(piv), mean(abs(piv) >= abs(sqrt(n_units) * est))), tolerance = 1e-12)
	# The risk difference keeps the equal-tailed rule.
	inf_rd = InferenceIncidGCompRiskDiff$new(make_ratio_design(1005, 80), verbose = FALSE)
	inf_rd$num_cores = 1L
	p_rd = inf_rd$.__enclos_env__$private
	set.seed(2)
	pv_rd = inf_rd$compute_subsampling_two_sided_pval(B = 99, show_progress = FALSE)
	set.seed(2)
	d_rd = inf_rd$approximate_subsampling_distribution_beta_hat_T(B = 99, show_progress = FALSE)
	est_rd = inf_rd$compute_estimate()
	n_rd = p_rd$get_exchangeable_units(unit = "auto", resampling_type = NULL)$n_units
	b_rd = p_rd$resolve_resampling_size(NULL, n_rd, "b")
	cs_rd = sqrt(b_rd) * (d_rd[is.finite(d_rd)] - est_rd) / sqrt(1 - b_rd / n_rd)
	t_rd = sqrt(n_rd) * est_rd
	expect_equal(pv_rd, min(1, max(2 / length(cs_rd), 2 * min(mean(cs_rd <= t_rd), mean(cs_rd >= t_rd)))), tolerance = 1e-12)
})
