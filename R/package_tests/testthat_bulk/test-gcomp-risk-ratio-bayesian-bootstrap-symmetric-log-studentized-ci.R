# v1.0.6-TODO-116 (a): the g-computation risk-ratio classes (InferenceIncidGCompRiskRatio,
# InferenceIncidKKGCompRiskRatio) get a symmetric studentized Bayesian-bootstrap interval built on
# log(RR), type = "symmetric-percentile-t" of compute_bayesian_bootstrap_confidence_interval().
# The raw-scale "studentized" type undercovers at small n (0.89 at n = 60); the symmetric log-scale
# pivot covered 0.93. The new type runs the replicate guard and the interval check; the existing
# types are unchanged.

rr_sym_design = function(kk = FALSE, n = 60L, seed = 1L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	if (kk) {
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	} else {
		des = DesignFixedBernoulli$new(response_type = "incidence", n = n, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
	}
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w + 0.4 * X$x1)))
	des
}

rr_sym_cases = list(
	list(cls = "InferenceIncidGCompRiskRatio", kk = FALSE),
	list(cls = "InferenceIncidKKGCompRiskRatio", kk = TRUE)
)

rr_sym_override_private = function(priv, name, fn){
	if (bindingIsLocked(name, priv)) unlockBinding(name, priv)
	assign(name, fn, envir = priv)
}

rr_sym_ci_and_reason = function(f){
	reason = NULL
	ci = withCallingHandlers(f(),
		edi_procedure_na_warning = function(cond){ reason <<- cond$reason; invokeRestart("muffleWarning") })
	list(ci = unname(ci), reason = reason)
}

test_that("only the risk-ratio classes advertise and accept symmetric-percentile-t", {
	for (cs in rr_sym_cases) {
		inf = get(cs$cls)$new(rr_sym_design(cs$kk), verbose = FALSE)
		types = inf$get_supported_bayesian_bootstrap_ci_types()
		expect_true("symmetric-percentile-t" %in% types, info = cs$cls)
		expect_true(all(c("percentile", "basic", "wald", "studentized", "bootstrap-t", "bca") %in% types), info = cs$cls)
	}
	for (cls in c("InferenceIncidGCompRiskDiff", "InferenceIncidKKGCompRiskDiff")) {
		inf = get(cls)$new(rr_sym_design(grepl("KK", cls)), verbose = FALSE)
		expect_false("symmetric-percentile-t" %in% inf$get_supported_bayesian_bootstrap_ci_types(), info = cls)
		expect_error(inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 21, show_progress = FALSE),
			info = cls)
	}
})

test_that("the interval is the symmetric log(RR) percentile-t formula and is symmetric on the log scale", {
	for (cs in rr_sym_cases) {
		inf = get(cs$cls)$new(rr_sym_design(cs$kk), verbose = FALSE)
		inf$num_cores = 1L
		B = 199L
		set.seed(11)
		ci = inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = B, show_progress = FALSE)
		expect_identical(names(ci), c("2.5%", "97.5%"), info = cs$cls)
		est = as.numeric(inf$compute_estimate())
		se = as.numeric(inf$get_standard_error())
		expect_true(all(is.finite(ci)) && ci[1] > 0 && ci[1] < est && est < ci[2], info = cs$cls)
		expect_equal(log(est) - log(ci[[1]]), log(ci[[2]]) - log(est), tolerance = 1e-10, info = cs$cls)
		# Recompute from the same (cached) replicates.
		priv = inf$.__enclos_env__$private
		st = priv$approximate_bayesian_bootstrap_statistics_beta_hat_T(B = B, show_progress = FALSE, na.rm = TRUE, require_se = TRUE)
		ok = is.finite(st$theta) & st$theta > 0 & is.finite(st$se) & st$se > 0
		t_abs = abs(log(st$theta[ok]) - log(est)) / (st$se[ok] / st$theta[ok])
		q = stats::quantile(t_abs, 0.95, names = FALSE, type = 8)
		expect_equal(unname(ci), exp(log(est) + c(-1, 1) * q * se / est), tolerance = 1e-10, info = cs$cls)
		# The raw-scale studentized type is unchanged (still built on the raw scale).
		ci_st = inf$compute_bayesian_bootstrap_confidence_interval(type = "studentized", B = B, show_progress = FALSE)
		expect_equal(unname(ci_st), EDI:::bootstrap_ci_studentized(st, 0.05, est, se, 5L), tolerance = 1e-10, info = cs$cls)
	}
})

test_that("alpha changes the quantile and the interval narrows as alpha grows", {
	inf = InferenceIncidGCompRiskRatio$new(rr_sym_design(), verbose = FALSE)
	inf$num_cores = 1L
	set.seed(3)
	ci05 = inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, type = "symmetric-percentile-t", B = 199, show_progress = FALSE)
	ci20 = inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.2, type = "symmetric-percentile-t", B = 199, show_progress = FALSE)
	expect_identical(names(ci20), c("10%", "90%"))
	expect_true(ci20[[1]] > ci05[[1]] && ci20[[2]] < ci05[[2]])
})

test_that("the replicate guard and the extreme-interval check run for the new type", {
	for (cs in rr_sym_cases) {
		inf = get(cs$cls)$new(rr_sym_design(cs$kk), verbose = FALSE)
		inf$num_cores = 1L
		priv = inf$.__enclos_env__$private
		rr_sym_override_private(priv, "bootstrap_confidence_interval_extreme", function(ci, est = NA_real_, max_abs = NULL, theta = NULL) TRUE)
		set.seed(5)
		r = rr_sym_ci_and_reason(function() inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 101, show_progress = FALSE))
		expect_true(all(is.na(r$ci)), info = cs$cls)
		expect_identical(r$reason, "bayesian_bootstrap_extreme_confidence_interval", info = cs$cls)

		inf = get(cs$cls)$new(rr_sym_design(cs$kk), verbose = FALSE)
		inf$num_cores = 1L
		priv = inf$.__enclos_env__$private
		rr_sym_override_private(priv, "bootstrap_ci_estimates_extreme", function(theta, est = NA_real_) TRUE)
		set.seed(5)
		r = rr_sym_ci_and_reason(function() inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 101, show_progress = FALSE))
		expect_true(all(is.na(r$ci)), info = cs$cls)
		expect_identical(r$reason, "bayesian_bootstrap_extreme_finite_estimates", info = cs$cls)
	}
})

test_that("too few usable replicates gives NA with a reason, not an error", {
	inf = InferenceIncidGCompRiskRatio$new(rr_sym_design(), verbose = FALSE)
	inf$num_cores = 1L
	set.seed(2)
	r = rr_sym_ci_and_reason(function() inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 9,
		min_number_usable_samples = 50L, show_progress = FALSE))
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bayesian_bootstrap_too_few_finite_standard_errors")
})

test_that("argument checks reject bad alpha, B and flags", {
	skip_if_not(EDI:::should_run_asserts())
	inf = InferenceIncidGCompRiskRatio$new(rr_sym_design(), verbose = FALSE)
	f = function(...) inf$compute_bayesian_bootstrap_confidence_interval(type = "symmetric-percentile-t", show_progress = FALSE, ...)
	expect_error(f(alpha = 0, B = 21))
	expect_error(f(alpha = 1.2, B = 21))
	expect_error(f(B = 0))
	expect_error(f(B = 21, na.rm = NA))
	expect_error(f(B = 21, min_number_usable_samples = 0L))
})
