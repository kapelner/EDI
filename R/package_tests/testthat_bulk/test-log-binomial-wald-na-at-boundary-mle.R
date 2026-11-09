library(testthat)
library(EDI)

# v1.0.5 TODO-179 (owner decision 2026-11-09): InferenceIncidLogBinomial's Wald
# p-value and Wald CI are NA when the full-data MLE is on the boundary of the
# parameter space (some fitted probability exp(X b) = 1, i.e. a linear
# predictor within 1e-8 + 1e-6 of 0, the criterion of the TODO-128 boundary
# warning). The inverse information is too small there (1000-rep null study,
# n = 200, `~.`: Wald size 0.17 in boundary reps, 0.050 in interior reps). The
# object warns once (class edi_wald_mle_boundary_unavailable) and points to the
# likelihood-ratio test / interval, records the reason in
# cached_values$procedure_failure_reason[["wald"]], and leaves the estimate, its
# SE and is_nonestimable() unchanged. The LR null refit also gained a strictly
# feasible last-resort start, so the LR interval is a real LR interval here (it
# used to fall back to the Wald interval).

wald_boundary_design = function(seed = 20261022L, n = 120L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rnorm(n))
	X = as.data.frame(scale(X) / ncol(X))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = qlogis(0.35) + 2 * X$x1 - 1.5 * X$x2 + X$x3 + 0.3 * w + rnorm(n, 0, 0.5)
	des$add_all_subject_responses(stats::rbinom(n, 1, plogis(eta)))
	des
}

# Runs expr, muffling and recording the classes of every warning it raises.
collect_warning_classes = function(expr){
	cls = character()
	value = withCallingHandlers(
		force(expr),
		warning = function(w){
			cls <<- c(cls, class(w)[1L])
			invokeRestart("muffleWarning")
		}
	)
	list(value = value, classes = cls)
}

test_that("boundary MLE (`~.`): Wald p-value and CI are NA with a classed warning; LR is a real LR interval", {
	des = wald_boundary_design()
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	inf$num_cores = 1L
	est = suppressWarnings(inf$compute_estimate(), classes = "edi_binomial_mle_boundary_warning")
	expect_true(is.finite(est))
	priv = inf$.__enclos_env__$private
	expect_gt(max(priv$build_design_matrix() %*% priv$cached_mod$b), -1e-6)
	expect_gte(priv$cached_values$logbin_mle_n_on_boundary, 1L)

	cond = tryCatch(inf$compute_asymp_two_sided_pval(), edi_wald_mle_boundary_unavailable = function(w) w)
	expect_s3_class(cond, "edi_wald_mle_boundary_unavailable")
	expect_identical(cond$testing_type, "wald")
	expect_identical(cond$substitute, "lik_ratio")
	expect_gte(cond$n_on_boundary, 1L)
	expect_match(conditionMessage(cond), "lik_ratio", fixed = TRUE)

	# Once per object: every Wald entry point now returns NA silently.
	got = collect_warning_classes(list(
		p = inf$compute_asymp_two_sided_pval(),
		ci = inf$compute_asymp_confidence_interval(),
		p_w = inf$compute_wald_two_sided_pval(delta = 0.1),
		ci_w = inf$compute_wald_confidence_interval(alpha = 0.1)
	))
	expect_false("edi_wald_mle_boundary_unavailable" %in% got$classes)
	expect_true(is.na(got$value$p))
	expect_true(is.na(got$value$p_w))
	expect_identical(unname(got$value$ci), c(NA_real_, NA_real_))
	expect_identical(names(got$value$ci), c("2.5%", "97.5%"))
	expect_identical(unname(got$value$ci_w), c(NA_real_, NA_real_))
	expect_identical(names(got$value$ci_w), c("5%", "95%"))

	# Reason recorded; the estimate, SE and nonestimable state are untouched.
	cv = priv$cached_values
	expect_identical(cv$procedure_failure_reason[["wald"]], "wald_mle_on_parameter_space_boundary")
	expect_match(cv$wald_unavailable_reason, "boundary of the parameter space", fixed = TRUE)
	expect_false(inf$is_nonestimable())
	expect_identical(inf$compute_estimate(), est)
	expect_true(is.finite(cv$s_beta_hat_T) && cv$s_beta_hat_T > 0)

	# The likelihood-ratio test and interval the warning points to are finite,
	# and the interval is the LR inversion, not a Wald fallback.
	lr = collect_warning_classes(list(
		p = inf$compute_lik_ratio_two_sided_pval(),
		ci = inf$compute_lik_ratio_confidence_interval()
	))
	expect_false("edi_lik_ci_wald_fallback" %in% lr$classes)
	expect_true(is.finite(lr$value$p))
	expect_true(all(is.finite(lr$value$ci)))
	expect_lt(lr$value$ci[[1L]], est)
	expect_gt(lr$value$ci[[2L]], est)
	expect_null(priv$cached_values$ci_fallback_reason[["lik_ratio"]])
	spec = priv$get_likelihood_test_spec()
	lr_at = function(d) 2 * (spec$neg_loglik(spec$fit_null(d)) - spec$neg_loglik(spec$full_fit))
	expect_equal(lr_at(lr$value$ci[[2L]]), qchisq(0.95, 1), tolerance = 1e-3)
	expect_equal(lr_at(lr$value$ci[[1L]]), qchisq(0.95, 1), tolerance = 1e-3)

	# A fresh object with testing_type = "lik_ratio" never warns about Wald.
	lr_obj = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	lr_obj$set_testing_type("lik_ratio")
	got_lr = collect_warning_classes(lr_obj$compute_asymp_two_sided_pval())
	expect_false("edi_wald_mle_boundary_unavailable" %in% got_lr$classes)
	expect_equal(got_lr$value, lr$value$p, tolerance = 1e-10)
})

test_that("interior MLE (`~1`): Wald unchanged and no Wald-boundary warning", {
	des = wald_boundary_design()
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ 1, verbose = FALSE)
	got = collect_warning_classes(list(
		est = inf$compute_estimate(),
		p = inf$compute_asymp_two_sided_pval(),
		ci = inf$compute_asymp_confidence_interval(),
		p_w = inf$compute_wald_two_sided_pval(),
		ci_w = inf$compute_wald_confidence_interval()
	))
	expect_length(got$classes, 0L)
	priv = inf$.__enclos_env__$private
	expect_identical(priv$cached_values$logbin_mle_n_on_boundary, 0L)
	expect_null(priv$cached_values$procedure_failure_reason[["wald"]])
	se = priv$cached_values$s_beta_hat_T
	z = qnorm(0.975)
	expect_equal(unname(got$value$ci), got$value$est + c(-1, 1) * z * se, tolerance = 1e-12)
	expect_equal(got$value$p, 2 * pnorm(-abs(got$value$est / se)), tolerance = 1e-12)
	# compute_wald_*() use the information-matrix SE (pre-existing ~1e-8 difference)
	expect_equal(got$value$p_w, got$value$p, tolerance = 1e-6)
	expect_equal(got$value$ci_w, got$value$ci, tolerance = 1e-6)
	expect_lt(max(priv$build_design_matrix() %*% priv$cached_mod$b), -1e-3)
})

test_that("interior MLE with covariates (`~ x1`): Wald unchanged and no Wald-boundary warning", {
	set.seed(11L)
	n = 200L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(stats::rbinom(n, 1, exp(-1.5 + 0.2 * X$x1)))
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	got = collect_warning_classes(list(
		est = inf$compute_estimate(),
		p = inf$compute_asymp_two_sided_pval(),
		ci = inf$compute_asymp_confidence_interval()
	))
	expect_length(got$classes, 0L)
	priv = inf$.__enclos_env__$private
	expect_identical(priv$cached_values$logbin_mle_n_on_boundary, 0L)
	se = priv$cached_values$s_beta_hat_T
	expect_equal(unname(got$value$ci), got$value$est + c(-1, 1) * qnorm(0.975) * se, tolerance = 1e-12)
	expect_true(is.finite(got$value$p))
})

test_that("the Wald-boundary NA is silent inside a resampling operation but still NA", {
	des = wald_boundary_design()
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	suppressWarnings(inf$compute_estimate(), classes = "edi_binomial_mle_boundary_warning")
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "jackknife"
	got = collect_warning_classes(inf$compute_wald_two_sided_pval())
	priv$active_resampling_operation = NULL
	expect_true(is.na(got$value))
	expect_length(got$classes, 0L)
	expect_warning(inf$compute_wald_two_sided_pval(), class = "edi_wald_mle_boundary_unavailable")
})
