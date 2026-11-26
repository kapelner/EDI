# v1.0.6-TODO-92: when the hardened fit drops a covariate beyond the QR rank
# set (its full-rank fit diverged under separation, or was otherwise unusable)
# and reports the reduced model, the class warns once per object with class
# edi_covariate_dropped_warning (fields dropped, reason, diverged), never from
# resampling inner loops, and without changing any estimate. Plain collinear
# (rank-deficient) drops stay silent.
context("covariate dropped warning")

# Inline copy of the data-shape fixture
# data_shape__fixed_blocking__incidence__fixed__equal__none__no__<effect>
# (R/package_tests/public_argument_combination_fixtures.R, build_data_shape_fixture()).
# With effect "strong" (P(y = 1) = 0.9 treated, 0.1 control) the full probit fit
# diverges (stratumhigh about -8, beyond max_abs_reasonable_coef = 10 together with
# treatment) and the hardened refit drops stratumhigh. "null" is not separated.
fx_blocking_incidence = function(strong = TRUE){
	n = 40L
	x1 = stats::qnorm(seq(0.5, n - 0.5) / n)[c(seq(1L, n, by = 2L), seq(2L, n, by = 2L))]
	X = data.frame(
		x1 = x1,
		x2 = rep(c(0, 1), length.out = n),
		stratum = factor(ifelse(seq_len(n) <= 20L, "low", "high"), levels = c("low", "high"))
	)
	des = DesignFixedBlocking$new(
		response_type = "incidence", n = n, seed = 20260809L, design_formula = ~ x1 + x2 + stratum,
		strata_cols = "stratum", equal_block_sizes = TRUE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = as.numeric(des$get_w())
	old = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	set.seed(20261118L)
	stats::rnorm(n)
	u = stats::runif(n)
	if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv())
	p1 = if (strong) ifelse(w == 1, 0.9, 0.1) else rep(0.5, n)
	des$add_all_subject_responses(as.numeric(u < p1))
	des
}

catch_drop_warnings = function(expr){
	ws = list()
	val = withCallingHandlers(expr, warning = function(w){
		if (inherits(w, "edi_covariate_dropped_warning")) ws[[length(ws) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, warnings = ws)
}

test_that("edi_classify_hardened_drop names diverged columns", {
	cls = edi_classify_hardened_drop(list(b = c(0.1, 1, 25, -0.2)), c("(Intercept)", "treatment", "s", "x"), 10)
	expect_identical(cls$reason, "coefficient_diverged")
	expect_identical(cls$diverged, "s")
	cls = edi_classify_hardened_drop(list(coefficients = c(0.1, NA, 2)), c("a", "b", "c"), NULL)
	expect_identical(cls$reason, "coefficient_diverged")
	expect_identical(cls$diverged, "b")
	expect_identical(edi_classify_hardened_drop(list(b = c(1, 2)), c("a", "b"), 10)$reason, "full_fit_unusable")
	expect_identical(edi_classify_hardened_drop(NULL, character(), 10)$reason, "full_fit_unusable")
})

test_that("InferenceIncidProbitRegr warns once naming the separated covariate it dropped", {
	des = fx_blocking_incidence(TRUE)
	inf = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	res = catch_drop_warnings({
		c(inf$compute_estimate(), inf$compute_asymp_two_sided_pval(), inf$compute_asymp_confidence_interval())
	})
	expect_length(res$warnings, 1L)
	w = res$warnings[[1L]]
	expect_identical(w$dropped, "stratumhigh")
	expect_identical(w$reason, "coefficient_diverged")
	# the coefficient that crossed the cap was treatment (11.9); stratumhigh (-8.3) is what the loop dropped
	expect_identical(w$diverged, "treatment")
	expect_match(conditionMessage(w), "InferenceIncidProbitRegr: dropped covariate\\(s\\) stratumhigh and refit")
	expect_match(conditionMessage(w), "max_abs_reasonable_coef = 10")
	# the reported model really is the reduced one, and the estimate is unchanged
	priv = inf$.__enclos_env__$private
	expect_false("stratumhigh" %in% priv$best_X_colnames)
	inf2 = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	est2 = suppressWarnings(inf2$compute_estimate())
	expect_identical(unname(res$value[1L]), unname(est2))
	expect_equal(est2, as.numeric(inf2$.__enclos_env__$private$cached_mod$b[2L]))
})

test_that("the TODO-138 fixture keeps its estimate (3.39, p 1.5e-4); its null twin is silent", {
	res = catch_drop_warnings({
		inf = InferenceIncidProbitRegr$new(fx_blocking_incidence(TRUE), verbose = FALSE)
		c(inf$compute_estimate(), inf$compute_asymp_two_sided_pval())
	})
	expect_length(res$warnings, 1L)
	expect_equal(res$value[1L], 3.38874, tolerance = 1e-5)
	expect_equal(res$value[2L], 1.45741e-4, tolerance = 1e-3)
	# the non-separated (null-effect) twin drops nothing and stays silent
	des0 = fx_blocking_incidence(FALSE)
	for (gen in list(InferenceIncidProbitRegr, InferenceIncidLogRegr, InferenceIncidGCompRiskDiff, InferenceIncidLogBinomial)) {
		res0 = catch_drop_warnings({
			inf0 = gen$new(des0, verbose = FALSE)
			inf0$compute_estimate()
			inf0$compute_asymp_two_sided_pval()
		})
		expect_length(res0$warnings, 0L)
	}
})

test_that("non-separated data and collinear-only drops stay silent", {
	inf = InferenceIncidProbitRegr$new(fx_blocking_incidence(FALSE), verbose = FALSE)
	expect_length(catch_drop_warnings({ inf$compute_estimate(); inf$compute_asymp_two_sided_pval() })$warnings, 0L)
	# x1_copy duplicates x1: the QR step drops it (rank deficiency), which is not a model change
	set.seed(4); n = 40
	X = data.frame(x1 = rnorm(n)); X$x1_copy = 2 * X$x1
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.4 * as.numeric(des$get_w()) + 0.5 * X$x1)))
	for (gen in list(InferenceIncidProbitRegr, InferenceIncidLogRegr, InferenceIncidGCompRiskDiff)) {
		inf = gen$new(des, verbose = FALSE)
		expect_length(catch_drop_warnings({ inf$compute_estimate(); inf$compute_asymp_two_sided_pval() })$warnings, 0L)
	}
})

test_that("resampling on a dropped-covariate fit never repeats the warning", {
	des = fx_blocking_incidence(TRUE)
	inf = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf$num_cores = 1L
	res = catch_drop_warnings({
		inf$compute_estimate()
		inf$compute_bootstrap_two_sided_pval(B = 51L)
	})
	expect_length(res$warnings, 1L)
	# a resampling call first on a fresh object warns at most once (the full fit), never per draw
	inf2 = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf2$num_cores = 1L
	res2 = catch_drop_warnings(inf2$compute_bootstrap_two_sided_pval(B = 51L))
	expect_lte(length(res2$warnings), 1L)
	# the helper itself is silent while a resampling operation is active
	priv = InferenceIncidProbitRegr$new(des, verbose = FALSE)$.__enclos_env__$private
	priv$active_resampling_operation = "non_param_boot"
	expect_false(edi_warn_covariate_dropped_once(NULL, priv, "stratumhigh", "coefficient_diverged"))
})

test_that("the g-computation drop loop warns with the covariate it dropped", {
	# fake a fit returned by fit_logistic_with_sandwich() after one drop
	priv = new.env()
	priv$cached_values = list()
	priv$max_abs_reasonable_coef = 25
	self = structure(list(), class = "InferenceIncidGCompRiskDiff")
	fit = list(
		X = cbind(`(Intercept)` = 1, treatment = c(0, 1), x1 = c(1, 2)),
		qr_rank_colnames = c("(Intercept)", "treatment", "x1", "stratumhigh"),
		qr_rank_coefficients = c(0, 1, 0.5, 40)
	)
	expect_warning(
		edi_warn_gcomp_covariate_drop(self, priv, fit$X, fit, FALSE),
		"dropped covariate\\(s\\) stratumhigh and refit",
		class = "edi_covariate_dropped_warning"
	)
	expect_true(isTRUE(priv$cached_values$covariate_dropped_warned))
	# once per object
	expect_no_warning(edi_warn_gcomp_covariate_drop(self, priv, fit$X, fit, FALSE))
	priv$cached_values = list()
	w = tryCatch(
		edi_warn_gcomp_covariate_drop(self, priv, cbind(`(Intercept)` = 1, treatment = 0:1, x1 = 1:2, x2 = 3:4), list(X = cbind(`(Intercept)` = 1, treatment = 0:1)), TRUE),
		edi_covariate_dropped_warning = function(w) w
	)
	expect_identical(w$reason, "treatment_only_fallback")
	# no drop beyond the rank set: silent
	priv$cached_values = list()
	fit$qr_rank_colnames = colnames(fit$X)
	expect_no_warning(edi_warn_gcomp_covariate_drop(self, priv, fit$X, fit, FALSE))
})
