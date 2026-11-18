# v1.0.6-TODO-134: InferencePropGCompMeanDiff (and the incidence G-computation RD/RR classes,
# same cause) left cached_values$s_beta_hat_T unset, so the studentized nonparametric bootstrap
# (replicate and original SEs) and the studentized Bayesian bootstrap were NA on every design.
# The weighted refit (compute_estimate_with_bootstrap_weights) also returned no SE.

gcomp_studentized_design = function(response_type, kind = "bernoulli", n = 78L, seed = 1L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), stratum = rep(letters[1:6], length.out = n))
	if (identical(kind, "bernoulli")) {
		des = DesignFixedBernoulli$new(response_type = response_type, n = n, verbose = FALSE)
		des$add_all_subjects_to_experiment(X[, c("x1", "x2")])
	} else {
		des = DesignFixedBlocking$new(strata_cols = "stratum", response_type = response_type, n = n, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
	}
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = -0.3 + 0.8 * w + 0.6 * X$x1
	y = if (identical(response_type, "incidence")) rbinom(n, 1, plogis(eta)) else plogis(eta + rnorm(n, 0, 0.5))
	des$add_all_subject_responses(y)
	des
}

gcomp_studentized_cases = list(
	list(cls = "InferencePropGCompMeanDiff", rt = "proportion"),
	list(cls = "InferenceIncidGCompRiskDiff", rt = "incidence"),
	list(cls = "InferenceIncidGCompRiskRatio", rt = "incidence")
)

test_that("a full fit mirrors the Wald standard error into s_beta_hat_T", {
	for (cs in gcomp_studentized_cases) {
		inf = get(cs$cls)$new(gcomp_studentized_design(cs$rt))
		se = inf$get_standard_error()
		expect_true(is.finite(se) && se > 0, info = cs$cls)
		expect_identical(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, se, info = cs$cls)
	}
})

test_that("the weighted refit's standard error equals the unweighted one at unit weights and ignores weight scale", {
	for (cs in gcomp_studentized_cases) for (kind in c("bernoulli", "blocking")) for (fm in list(NULL, ~ 1)) {
		info = paste(cs$cls, kind, if (is.null(fm)) "default" else "~1")
		inf = get(cs$cls)$new(gcomp_studentized_design(cs$rt, kind), model_formula = fm)
		se = inf$get_standard_error()
		priv = inf$.__enclos_env__$private
		priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
		n_units = priv$current_bayesian_bootstrap_context$n_units
		inf$compute_estimate_with_bootstrap_weights(rep(1, n_units), estimate_only = FALSE)
		expect_equal(priv$weighted_refit_se(), se, tolerance = 1e-10, info = info)
		inf$compute_estimate_with_bootstrap_weights(rep(3.7, n_units), estimate_only = FALSE)
		expect_equal(priv$weighted_refit_se(), se, tolerance = 1e-10, info = info)
		set.seed(9)
		g = stats::rgamma(n_units, 1)
		inf$compute_estimate_with_bootstrap_weights(g, estimate_only = FALSE)
		se_g = priv$weighted_refit_se()
		expect_true(is.finite(se_g) && se_g > 0, info = info)
		inf$compute_estimate_with_bootstrap_weights(g, estimate_only = TRUE)
		expect_true(is.na(priv$weighted_refit_se()), info = info)
		# The weighted refit must not leak into the unweighted cache.
		expect_identical(priv$cached_values$s_beta_hat_T, se, info = info)
	}
})

test_that("studentized nonparametric and Bayesian bootstrap intervals and p-values are finite", {
	for (cs in gcomp_studentized_cases) for (kind in c("bernoulli", "blocking")) {
		info = paste(cs$cls, kind)
		mk = function() get(cs$cls)$new(gcomp_studentized_design(cs$rt, kind))
		set.seed(2)
		ci = mk()$compute_bootstrap_confidence_interval(B = 61, type = "studentized", show_progress = FALSE)
		expect_true(all(is.finite(ci)) && ci[1] < ci[2], info = info)
		set.seed(2)
		expect_true(is.finite(mk()$compute_bootstrap_two_sided_pval(B = 61, type = "studentized", show_progress = FALSE)), info = info)
		set.seed(2)
		ci = mk()$compute_bayesian_bootstrap_confidence_interval(B = 61, type = "studentized", show_progress = FALSE)
		expect_true(all(is.finite(ci)) && ci[1] < ci[2], info = info)
		set.seed(2)
		expect_true(is.finite(mk()$compute_bayesian_bootstrap_two_sided_pval(B = 61, type = "studentized", show_progress = FALSE)), info = info)
	}
})
