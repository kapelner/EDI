library(testthat)
library(EDI)

# TODO-128 (v1.0.5, 2026-10-22): independent reference for the constrained
# log-binomial MLE. nloptr's SLSQP maximizes the log-binomial log-likelihood
# subject to X b <= -1e-8 (the fitting kernel's own mean-support bound,
# exp(X b) < 1) from several starts with tight tolerances. EDI's full-data
# fit (InferenceIncidLogBinomial, ~ .) must reach the reference log-likelihood
# and coefficients.
#
# The interior dataset runs now. The three boundary datasets (MLE with a
# subject on exp(X b) = 1) only pass once G1 applies and builds C++ patch 14
# (R/package_metadata/bug_fix_plans/cpp_patches_v105/14-log-binomial-active-
# set-step.patch: active-set step + KKT convergence gate): the unpatched
# Fisher-scoring loop stalls at the bound and reports convergence short of the
# MLE (log-lik gaps 1.8e-4, 0.45 and 0.50 on these three sets). The boundary
# block detects the patched kernel through the `kkt_converged` field the patch
# adds to the kernel's result and skips with a message otherwise (fails
# instead under EDI_REQUIRE_CPP_PATCHES=true, as the patch bundle README asks).

skip_on_cran()
skip_if_not_installed("nloptr")

todo128_ref_design = function(seed, n){
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

log_binomial_loglik = function(X, y, b){
	eta = as.numeric(X %*% b)
	if (any(eta >= -1e-8)) return(-Inf)
	sum(y * eta + (1 - y) * log1p(-exp(eta)))
}

# Constrained MLE by SLSQP (analytic gradient and constraint Jacobian), best
# feasible solution over several starts.
log_binomial_nloptr_reference = function(X, y, starts){
	nll = function(b){
		eta = pmin(as.numeric(X %*% b), -1e-300)
		-sum(y * eta + (1 - y) * log1p(-exp(eta)))
	}
	grad = function(b){
		eta = pmin(as.numeric(X %*% b), -1e-300)
		mu = exp(eta)
		-as.numeric(crossprod(X, y - (1 - y) * mu / (1 - mu)))
	}
	best = NULL
	for (b0 in starts) {
		r = nloptr::nloptr(
			x0 = b0, eval_f = nll, eval_grad_f = grad,
			eval_g_ineq = function(b) as.numeric(X %*% b) + 1e-8,
			eval_jac_g_ineq = function(b) X,
			opts = list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-15, ftol_rel = 1e-16, maxeval = 50000L)
		)
		if (max(X %*% r$solution) > -1e-8 + 1e-12) next
		if (is.null(best) || r$objective < best$objective) best = r
	}
	list(b = best$solution, ll = -best$objective)
}

edi_log_binomial_fit = function(des){
	inf = InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
	inf$num_cores = 1L
	est = suppressWarnings(inf$compute_estimate(), classes = "edi_binomial_mle_boundary_warning")
	priv = inf$.__enclos_env__$private
	X = priv$cached_values$likelihood_test_context$X %||% priv$build_design_matrix()
	list(est = est, X = X, y = as.numeric(priv$y), b = as.numeric(priv$cached_mod$b))
}

compare_to_reference = function(fit, label, ll_tol, b_tol){
	X = fit$X
	y = fit$y
	k = ncol(X)
	ref = log_binomial_nloptr_reference(X, y, list(
		fit$b,
		fit$b - c(0.05, rep(0, k - 1L)),
		c(log(mean(y)) - 0.3, rep(0, k - 1L))
	))
	expect_true(is.finite(fit$est), info = label)
	ll_edi = log_binomial_loglik(X, y, fit$b)
	expect_true(is.finite(ll_edi), info = label)
	expect_gte(ll_edi, ref$ll - ll_tol)
	expect_lte(max(abs(fit$b - ref$b)), b_tol)
	expect_equal(fit$est, ref$b[2], tolerance = b_tol)
	invisible(ref)
}

test_that("interior covariate-adjusted log-binomial MLE matches the nloptr constrained reference (TODO-128)", {
	fit = edi_log_binomial_fit(todo128_ref_design(11L, 200L))
	expect_lt(max(fit$X %*% fit$b), -1e-3) # interior: no subject near exp(X b) = 1
	compare_to_reference(fit, "interior seed 11", ll_tol = 1e-6, b_tol = 1e-4)
})

test_that("boundary log-binomial MLEs match the nloptr constrained reference after G1 patch 14 (TODO-128)", {
	des0 = todo128_ref_design(20261022L, 120L)
	X0 = cbind(1, des0$get_w(), as.matrix(des0$get_X()))
	probe = fast_log_binomial_regression_cpp(X0, as.numeric(des0$get_y()))
	if (!("kkt_converged" %in% names(probe))) {
		if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) {
			fail("EDI_REQUIRE_CPP_PATCHES=true but the installed log-binomial kernel has no `kkt_converged` field: cpp_patches_v105 patch 14 is not built (TODO-128)")
			return(invisible(NULL))
		}
		skip("installed EDI DLL lacks the KKT-gated log-binomial kernel: pending G1 build of cpp_patches_v105 patch 14 (14-log-binomial-active-set-step.patch, TODO-128)")
	}
	for (cfg in list(c(20261022L, 120L), c(7L, 200L), c(20L, 120L))) {
		label = paste0("boundary seed ", cfg[1], " n = ", cfg[2])
		des = todo128_ref_design(cfg[1], cfg[2])
		fit = edi_log_binomial_fit(des)
		expect_gt(max(fit$X %*% fit$b), -1e-6 - 1e-8) # MLE has a subject on the bound
		expect_lte(max(fit$X %*% fit$b), -1e-8)
		kern = fast_log_binomial_regression_cpp(fit$X, fit$y)
		expect_true(isTRUE(kern$converged) && isTRUE(kern$kkt_converged), info = label)
		expect_gte(kern$n_active_bounds, 1L)
		compare_to_reference(fit, label, ll_tol = 1e-4, b_tol = 1e-3)
	}
})
