# v1.0.6-TODO-108: on a DesignFixedBlocking whose design_formula names the strata column,
# the BCa bootstrap CI and the jackknife-Wald CI were NA with no warning. Leave-one-block-out
# leaves the strata column constant; the design dropped it before applying the formula, so
# model.matrix() failed in every jackknife replicate (same cause as v1.0.6-TODO-107, fixed in
# Design's covariate_impute_if_necessary_and_then_create_model_matrix()). InferenceContinLin
# also read private$X directly, which a reusable worker sets to NULL on a rank-deficient draw.

fx_blocking_strata_formula = function(response_type, y_fun, seed = 1L, n = 40L){
	set.seed(seed)
	X = data.frame(x = rnorm(n), s = factor(rep(c("a", "b"), each = n / 2)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = response_type, n = n, seed = seed,
		design_formula = ~ x + s, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(y_fun(n, des$get_w()))
	des
}

blocking_strata_formula_specs = list(
	InferenceContinOLS = list("continuous", function(n, w) rnorm(n) + w),
	InferenceContinLin = list("continuous", function(n, w) rnorm(n) + w),
	InferenceContinRobustRegr = list("continuous", function(n, w) rnorm(n) + w),
	InferencePropFractionalLogit = list("proportion", function(n, w) stats::plogis(rnorm(n) + w)),
	InferenceSurvivalCoxPHRegr = list("survival", function(n, w) stats::rexp(n, exp(-0.5 * w))),
	InferenceCountPoisson = list("count", function(n, w) stats::rpois(n, exp(0.5 + 0.4 * w)))
)

for (cls in names(blocking_strata_formula_specs)) local({
	cls = cls
	spec = blocking_strata_formula_specs[[cls]]
	test_that(paste0(cls, ": leave-one-block-out jackknife replicates are finite when design_formula names the strata"), {
		des = fx_blocking_strata_formula(spec[[1L]], spec[[2L]])
		inf = get(cls)$new(des, verbose = FALSE)
		inf$num_cores = 1L
		# v1.0.6-TODO-4 (5bdb9dfb): the automatic unit on DesignFixedBlocking is now one subject
		# within its stratum, so ask for leave-one-block-out explicitly; deleting a whole block
		# is what leaves the strata column constant (the v1.0.6-TODO-108 case).
		jack = inf$approximate_jackknife_distribution_beta_hat_T(unit = "block")
		expect_length(jack, 2L)
		expect_true(all(is.finite(jack)))
		# v1.0.6-TODO-135: 2 blocks are too few deletion units for a jackknife variance, so the
		# jackknife-Wald CI is NA with a warning; the replicates above (the v1.0.6-TODO-108 fix)
		# stay finite.
		expect_warning(jci <- inf$compute_jackknife_wald_confidence_interval(unit = "block"),
			"jackknife_too_few_deletion_units", class = "edi_procedure_na_warning")
		expect_true(all(is.na(jci)))
		# BCa takes its acceleration from the automatic unit: n = 40 within-stratum deletions
		# (v1.0.6-TODO-4), well above the minimum, so the interval is finite with no failure.
		bci = inf$compute_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE)
		expect_true(all(is.finite(bci)))
		expect_null(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap)
	})
})

test_that("InferenceContinLin reusable worker rebuilds the model matrix on a rank-deficient draw", {
	des = fx_blocking_strata_formula("continuous", function(n, w) rnorm(n) + w)
	inf = InferenceContinLin$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	draws = p$build_jackknife_deletion_draws(unit = "block")
	ws = p$create_reusable_bootstrap_worker()
	p$load_bootstrap_sample_into_worker(ws, draws[[1L]])
	expect_null(ws$worker_priv$X)
	expect_true(is.finite(p$compute_bootstrap_worker_estimate(ws)))
})

test_that("a BCa interval or p-value that is NA for lack of jackknife replicates warns", {
	des = fx_blocking_strata_formula("continuous", function(n, w) rnorm(n) + w)
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", p)
	p$approximate_jackknife_distribution_beta_hat_T_private = function(unit = "auto") c(NA_real_, NA_real_)
	expect_warning(
		ci <- inf$compute_bootstrap_confidence_interval(B = 51, type = "bca", show_progress = FALSE),
		"bootstrap_bca_jackknife_unavailable", class = "edi_procedure_na_warning"
	)
	expect_true(all(is.na(ci)))
	expect_warning(
		pv <- inf$compute_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE),
		"bootstrap_bca_jackknife_unavailable", class = "edi_procedure_na_warning"
	)
	expect_true(is.na(pv))
})

test_that("a jackknife deletion unit the blocking design does not support warns and names unit = \"block\"", {
	des = fx_blocking_strata_formula("continuous", function(n, w) rnorm(n) + w)
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	expect_warning(
		ci <- inf$compute_jackknife_wald_confidence_interval(unit = "observation"),
		"unit = \"block\"", class = "edi_procedure_na_warning"
	)
	expect_true(all(is.na(ci)))
	# With unit = "block" the unit is supported, but 2 blocks are too few (v1.0.6-TODO-135).
	expect_warning(ci_block <- inf$compute_jackknife_wald_confidence_interval(unit = "block"),
		"jackknife_too_few_deletion_units", class = "edi_procedure_na_warning")
	expect_true(all(is.na(ci_block)))
})
