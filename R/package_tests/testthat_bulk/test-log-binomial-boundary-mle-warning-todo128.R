library(testthat)
library(EDI)

# TODO-128 (v1.0.5, 2026-10-22): when the full-data log-binomial fit has a
# subject on the exp(X b) <= 1 boundary (the MLE is on the edge of the
# parameter space), InferenceIncidLogBinomial warns once per object that the
# Wald/score SEs and CIs may be unreliable. The warning never changes a
# number and is silent inside resampling refits (jackknife, bootstrap,
# randomization workers). The identity-link sibling
# InferenceIncidBinomialIdentityRiskDiff uses the same helper with bounds at
# mu = 0 and mu = 1.

todo128_boundary_design = function(seed = 20261022L, n = 120L){
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

count_boundary_warnings = function(expr){
	n_warn = 0L
	withCallingHandlers(
		force(expr),
		edi_binomial_mle_boundary_warning = function(w){
			n_warn <<- n_warn + 1L
			invokeRestart("muffleWarning")
		}
	)
	n_warn
}

test_that("log-binomial warns once when the full-data MLE is on the boundary (TODO-128)", {
	des = todo128_boundary_design()
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	inf$num_cores = 1L

	expect_warning(est <- inf$compute_estimate(), class = "edi_binomial_mle_boundary_warning")
	priv = inf$.__enclos_env__$private
	X = priv$build_design_matrix()
	expect_gt(max(X %*% priv$cached_mod$b), -1e-6)

	# No numeric change: the estimate is the kernel's own full-data fit.
	direct = fast_log_binomial_regression_cpp(X, as.numeric(priv$y))
	expect_identical(est, as.numeric(direct$b[2]))

	# Once per object: SE/CI, jackknife, bootstrap and randomization refits
	# (resampling workers) add no further boundary warnings.
	n_more = count_boundary_warnings({
		inf$compute_asymp_confidence_interval()
		inf$compute_jackknife_estimate()
		set.seed(1)
		suppressWarnings(inf$compute_bootstrap_confidence_interval(type = "percentile", B = 21, show_progress = FALSE),
			classes = "edi_bootstrap_bca_boundary_warning")
		inf$compute_rand_two_sided_pval(r = 21, show_progress = FALSE)
	})
	expect_identical(n_more, 0L)

	# A fresh object warns exactly once over the same sequence of calls.
	fresh = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	fresh$num_cores = 1L
	n_fresh = count_boundary_warnings({
		fresh$compute_estimate()
		fresh$compute_asymp_confidence_interval()
		fresh$compute_jackknife_estimate()
	})
	expect_identical(n_fresh, 1L)

	# The condition carries the link and the number of subjects on the bound.
	cond = tryCatch(
		InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)$compute_estimate(),
		edi_binomial_mle_boundary_warning = function(w) w
	)
	expect_s3_class(cond, "edi_binomial_mle_boundary_warning")
	expect_identical(cond$link, "log")
	expect_gte(cond$n_on_boundary, 1L)
	expect_match(conditionMessage(cond), "boundary of the parameter space", fixed = TRUE)
})

test_that("log-binomial is silent when the MLE is interior (TODO-128)", {
	des = todo128_boundary_design()
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ 1, verbose = FALSE)
	inf$num_cores = 1L
	expect_identical(count_boundary_warnings({
		inf$compute_estimate()
		inf$compute_asymp_confidence_interval()
		inf$compute_jackknife_estimate()
	}), 0L)
	priv = inf$.__enclos_env__$private
	expect_lt(max(priv$build_design_matrix() %*% priv$cached_mod$b), -1e-3)
})

test_that("boundary-warning helper: identity link bounds at 0 and 1, resampling silence, once per object (TODO-128)", {
	set.seed(3)
	n = 60L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = runif(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(stats::rbinom(n, 1, 0.4))
	X = cbind(1, des$get_w(), as.matrix(des$get_X())[, 1L])
	b_int = c(0.3, 0.1, 0.2)
	b_low = c(-min(X[, -1] %*% b_int[-1]), 0.1, 0.2) + c(1e-8, 0, 0)
	b_high = c(1 - max(X[, -1] %*% b_int[-1]), 0.1, 0.2) - c(1e-8, 0, 0)

	for (b_bound in list(b_low, b_high)) {
		inf = InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
		priv = inf$.__enclos_env__$private
		expect_false(edi_warn_binomial_mle_boundary_once(self = inf, private = priv, X, b_int, "identity"))
		priv$active_resampling_operation = "jackknife"
		expect_false(edi_warn_binomial_mle_boundary_once(self = inf, private = priv, X, b_bound, "identity"))
		priv$active_resampling_operation = NULL
		expect_warning(
			expect_true(edi_warn_binomial_mle_boundary_once(self = inf, private = priv, X, b_bound, "identity")),
			class = "edi_binomial_mle_boundary_warning"
		)
		expect_false(edi_warn_binomial_mle_boundary_once(self = inf, private = priv, X, b_bound, "identity"))
	}
})
