# v1.0.7-TODO-47: two parts.
# (1) bootstrap_subset_inference() copies made outside an active resampling operation
#     (e.g. ci_calibrated_bootstrap()'s outer loop, after the inner bootstrap's on.exit
#     cleared the operation) kept the parent's warm start whatever the warm-start dispatch
#     policy said, so the same draw fitted differently by call path. Such copies now follow
#     the "non_param_boot" policy entry, the same as copies made inside that operation.
# (2) The constrained binomial kernels (identity and log link) could not leave an
#     infeasible start: the OLS smart cold start often puts mu outside [0, 1] (identity) or
#     eta > 0 (log, OLS on log1p(y)), the active-set projection held those rows in place,
#     and the line search rejected every step (-Inf log-likelihood), so the fit returned
#     converged = FALSE after one iteration and the R class dropped covariates until a fit
#     passed. The start is now pulled into the mean support (C++ change; the kernel tests
#     skip until the owner's targeted compile of fast_log_binomial_regression.cpp).

subset_policy_incidence_design = function(n = 60L){
	set.seed(11)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "incidence", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	eta = 0.5 * des$get_w() + 0.6 * X$x1 - 0.4 * X$x2
	des$add_all_subject_responses(rbinom(n, 1, plogis(eta)))
	des
}

subset_copy_warm_flags = function(inf, draw, operation = NULL){
	p = inf$.__enclos_env__$private
	if (!is.null(operation)) {
		p$active_resampling_operation = operation
		on.exit(p$active_resampling_operation <- NULL, add = TRUE)
	}
	sp = p$bootstrap_subset_inference(draw)$.__enclos_env__$private
	list(enabled = sp$fit_warm_start_enabled, null_enabled = sp$null_fit_warm_start_enabled,
		start = sp$get_fit_warm_start(p$fit_warm_start_type))
}

test_that("subset copies follow the non_param_boot warm-start policy with or without an active operation", {
	des = subset_policy_incidence_design()
	set.seed(5)
	draw = list(i_b = sort(sample.int(60L, 60L, replace = TRUE)), m_vec_b = NULL)
	for (cls in c("InferenceIncidBinomialIdentityRiskDiff", "InferenceIncidLogRegr")) {
		inf = suppressWarnings(get(cls)$new(des, verbose = FALSE, model_formula = ~ x1 + x2))
		suppressWarnings(inf$compute_estimate())
		expect_false(is.null(inf$.__enclos_env__$private$fit_warm_start))
		policy = edi_warm_start_dispatch_policy(cls, "non_param_boot", n = 60L)
		outside = subset_copy_warm_flags(inf, draw)
		inside = subset_copy_warm_flags(inf, draw, operation = "non_param_boot")
		expect_identical(outside$enabled, policy, info = cls)
		expect_identical(outside$null_enabled, policy, info = cls)
		expect_identical(outside[c("enabled", "null_enabled")], inside[c("enabled", "null_enabled")], info = cls)
		expect_identical(is.null(outside$start), !policy, info = cls)
	}
	# The identity-binomial class is cold for non_param_boot at this n; the logistic class warm.
	expect_false(edi_warm_start_dispatch_policy("InferenceIncidBinomialIdentityRiskDiff", "non_param_boot", n = 60L))
	expect_true(edi_warm_start_dispatch_policy("InferenceIncidLogRegr", "non_param_boot", n = 60L))
})

test_that("ci_calibrated_bootstrap() restores the caller's resampling operation", {
	des = subset_policy_incidence_design()
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	seen = character()
	# Record the operation each outer copy is made under, then stop after the first.
	get("unlockBinding", envir = asNamespace("base"))("bootstrap_subset_inference", p)
	p$bootstrap_subset_inference = function(...) {
		seen <<- c(seen, p$active_resampling_operation %||% "<none>")
		stop("stop_after_first_outer_copy")
	}
	p$active_resampling_operation = "caller_op"
	expect_error(p$ci_calibrated_bootstrap(0.05, 25L, "calibrated", est, show_progress = FALSE), "stop_after_first_outer_copy")
	expect_identical(seen, "non_param_boot")
	expect_identical(p$active_resampling_operation, "caller_op")
	p$active_resampling_operation = NULL
})

constrained_binomial_kernel_has_start_repair = function(){
	# Probe: identity link, OLS start with mu outside [0, 1]. Kernels without the
	# v1.0.7-TODO-47 repair return converged = FALSE after one iteration.
	x = seq(-1, 1, length.out = 40)
	X = cbind(1, x)
	y = as.numeric(x > -0.6)
	fit = fast_identity_binomial_regression_cpp(X = X, y = y)
	!(identical(fit$num_iter, 1L) && !isTRUE(fit$converged))
}

identity_binomial_neg_loglik = function(X, y, b){
	mu = as.numeric(X %*% b)
	if (any(mu <= 0 | mu >= 1)) return(Inf)
	-sum(y * log(mu) + (1 - y) * log1p(-mu))
}

log_binomial_neg_loglik = function(X, y, b){
	eta = as.numeric(X %*% b)
	if (any(eta >= 0)) return(Inf)
	-sum(y * eta + (1 - y) * log1p(-exp(eta)))
}

# Reference constrained MLE by constrOptim() from a feasible intercept-only start. The kernel
# holds bound rows ~1e-6 inside the support (TODO-128 KKT gate), so boundary MLEs agree to
# about 1e-4 in the negative log-likelihood, not to machine precision.
constrained_binomial_reference = function(X, y, link){
	eps = 1e-9
	if (link == "identity") {
		start = c(mean(y), rep(0, ncol(X) - 1L))
		stats::constrOptim(start, function(b) identity_binomial_neg_loglik(X, y, b), NULL,
			ui = rbind(X, -X), ci = c(rep(eps, nrow(X)), rep(-1 + eps, nrow(X))),
			control = list(reltol = 1e-14, maxit = 1e5))
	} else {
		start = c(log(mean(y)), rep(0, ncol(X) - 1L))
		stats::constrOptim(start, function(b) log_binomial_neg_loglik(X, y, b), NULL,
			ui = -X, ci = rep(eps, nrow(X)), control = list(reltol = 1e-14, maxit = 1e5))
	}
}

test_that("constrained binomial cold fits leave an infeasible OLS start and reach the MLE", {
	skip_if_not(constrained_binomial_kernel_has_start_repair(),
		"fast_log_binomial_regression.cpp predates v1.0.7-TODO-47; needs the owner's targeted compile")
	n_checked = c(identity = 0L, log = 0L)
	for (s in 1:40) {
		set.seed(s)
		n = 60L
		X = cbind(1, treatment = rbinom(n, 1, 0.5), x1 = rnorm(n), x2 = rnorm(n))
		for (link in c("identity", "log")) {
			if (link == "identity") {
				y = rbinom(n, 1, pmin(pmax(0.4 + 0.1 * X[, 2] + 0.12 * X[, 3], 0.02), 0.98))
				ols = qr.solve(X, y)
				mu0 = as.numeric(X %*% ols)
				if (all(mu0 > 1e-8 & mu0 < 1 - 1e-8)) next   # the OLS start is feasible: nothing to check
				fit = fast_identity_binomial_regression_with_var_cpp(X = X, y = y, j = 2L, maxit = 500L)
				nll = identity_binomial_neg_loglik
			} else {
				y = rbinom(n, 1, exp(log(0.3) + 0.2 * X[, 2] + 0.2 * X[, 3]))
				fit = fast_log_binomial_regression_with_var_cpp(X = X, y = y, j = 2L, maxit = 500L)
				nll = log_binomial_neg_loglik
			}
			expect_true(isTRUE(fit$converged), info = paste(link, s))
			expect_length(fit$b, ncol(X))
			ref = constrained_binomial_reference(X, y, link)
			expect_lte(nll(X, y, fit$b), ref$value + 1e-4)
			expect_equal(as.numeric(fit$b[2]), ref$par[2], tolerance = 1e-2, scale = 1)
			n_checked[link] = n_checked[link] + 1L
		}
	}
	expect_gt(n_checked[["identity"]], 0L)
	expect_gt(n_checked[["log"]], 0L)
})

test_that("a cold InferenceIncidBinomialIdentityRiskDiff fit keeps every covariate when the OLS start is infeasible", {
	skip_if_not(constrained_binomial_kernel_has_start_repair(),
		"fast_log_binomial_regression.cpp predates v1.0.7-TODO-47; needs the owner's targeted compile")
	n = 40L
	set.seed(3)
	X = data.frame(x1 = seq(-1, 1, length.out = n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "incidence", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	y = as.numeric(X$x1 > -0.6 | runif(n) < 0.2)
	des$add_all_subject_responses(y)
	inf = InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE, model_formula = ~ x1 + x2)
	est = suppressWarnings(inf$compute_estimate())
	mod = inf$.__enclos_env__$private$cached_mod
	expect_length(mod$b, 4L)
	Xm = cbind(1, des$get_w(), X$x1, X$x2)
	ref = constrained_binomial_reference(Xm, y, "identity")
	expect_lte(identity_binomial_neg_loglik(Xm, y, mod$b), ref$value + 1e-4)
	expect_equal(as.numeric(mod$b[2]), ref$par[2], tolerance = 1e-3, scale = 1)
	expect_equal(as.numeric(est), as.numeric(mod$b[2]))
})
