# Zero-one-inflated beta regression internals (start values, log-likelihood, and fitter).

.sanitize_proportion_response = function(y, interior = FALSE){
	if (should_run_asserts()) {
		assertNumeric(y, any.missing = FALSE)
	}
	y = as.numeric(y)
	if (length(y) == 0L) return(y)
	if (isTRUE(interior)) {
		eps = .Machine$double.eps
		return(pmin(1 - eps, pmax(eps, y)))
	}
	pmin(1, pmax(0, y))
}

.softmax_three_from_logits = function(alpha0, alpha1){
	m = max(0, alpha0, alpha1)
	e0 = exp(alpha0 - m)
	e1 = exp(alpha1 - m)
	e2 = exp(-m)
	den = e0 + e1 + e2
	c(pi0 = e0 / den, pi1 = e1 / den, pib = e2 / den)
}

.build_zoib_start = function(y, X, X_zero_one = X){
	y = as.numeric(y)
	X_zero_one = as.matrix(X_zero_one)
	eps = .Machine$double.eps
	y_clip = pmin(pmax(y, eps), 1 - eps)
	beta_start = rep(0, ncol(X) + 1L)
	names(beta_start) = c("(Intercept)", colnames(X))

	glm_start = tryCatch(
		fast_logistic_regression_cpp(
			cbind(1, X),
			y_clip
		),
		error = function(e) NULL
	)
	if (!is.null(glm_start) && length(glm_start$b) == length(beta_start)){
		if (all(is.finite(glm_start$b))){
			beta_start = as.numeric(glm_start$b)
			names(beta_start) = c("(Intercept)", colnames(X))
		}
	}

	pi0 = mean(y == 0)
	pi1 = mean(y == 1)
	pib = max(1 - pi0 - pi1, 1e-4)
	pi0 = min(max(pi0, 1e-4), 1 - 2e-4)
	pi1 = min(max(pi1, 1e-4), 1 - pi0 - 1e-4)
	pib = max(1 - pi0 - pi1, 1e-4)

	alpha0 = rep(0, ncol(X_zero_one))
	alpha1 = rep(0, ncol(X_zero_one))
	if (length(alpha0) > 0L) {
		alpha0[1L] = log(pi0 / pib)
		alpha1[1L] = log(pi1 / pib)
	}
	c(
		unname(beta_start),
		log_phi = log(10),
		setNames(alpha0, paste0("alpha0_", seq_along(alpha0))),
		setNames(alpha1, paste0("alpha1_", seq_along(alpha1)))
	)
}

.neg_loglik_zoib = function(par, p, p_zero_one, is_zero, is_one, y_beta, X_beta, X_zero_one) {
	beta = par[seq_len(p)]
	phi = exp(par[p + 1L])
	a0 = par[p + 1L + seq_len(p_zero_one)]
	a1 = par[p + 1L + p_zero_one + seq_len(p_zero_one)]
	eta0 = as.vector(X_zero_one %*% a0)
	eta1 = as.vector(X_zero_one %*% a1)
	m = pmax(0, eta0, eta1)
	denom = exp(-m) + exp(eta0 - m) + exp(eta1 - m)
	log_p0 = eta0 - m - log(denom)
	log_p1 = eta1 - m - log(denom)
	log_pb = -m - log(denom)

	ll = sum(log_p0[is_zero]) + sum(log_p1[is_one])

	if (length(y_beta) > 0L) {
		mu = as.vector(stats::plogis(X_beta %*% beta))
		mu = pmin(pmax(mu, .Machine$double.eps), 1 - .Machine$double.eps)
		shape1 = mu * phi
		shape2 = (1 - mu) * phi
		ll = ll + sum(log_pb[!(is_zero | is_one)]) + sum(stats::dbeta(y_beta, shape1, shape2, log = TRUE))
	}
	-ll
}

.fit_zero_one_inflated_beta = function(y, X, X_zero_one = X, estimate_only = FALSE, starts = NULL, optimization_alg = "lbfgs"){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = as.numeric(y)
	X = as.matrix(X)
	X_without_intercept = X
	X_zero_one = as.matrix(X_zero_one)
	if (length(y) != nrow(X)){
		stop("Zero/one-inflated beta fit inputs must have matching row counts.")
	}
	if (nrow(X_zero_one) != length(y)){
		stop("Zero/one-inflated beta auxiliary inputs must have matching row counts.")
	}
	if (!all(is.finite(y)) || any(y < 0 | y > 1)){
		stop("Zero/one-inflated beta requires y in [0, 1].")
	}
	if (sum(y > 0 & y < 1) == 0L) return(NULL)

	if (is.null(colnames(X))){
		full_names = c("treatment", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}

	X = cbind("(Intercept)" = 1, X)
	p = ncol(X)
	is_zero = y == 0
	is_one = y == 1
	is_beta = !(is_zero | is_one)
	y_beta = y[is_beta]
	X_beta = X[is_beta, , drop = FALSE]

	if (is.null(starts)){
		start0 = .build_zoib_start(y, X_without_intercept, X_zero_one)
		starts = list(start0)
	}

	best = NULL
	best_val = Inf
	for (start_par in starts){
		fit = tryCatch(
			fast_zero_one_inflated_beta_cpp(X, X_zero_one, y, warm_start_params = start_par, optimization_alg = optimization_alg),
			error = function(e) NULL
		)
		if (is.null(fit) || !is.finite(fit$neg_loglik) || length(fit$coefficients) == 0L) next
		if (is.null(best) || fit$neg_loglik < best_val){
			best = fit
			best_val = fit$neg_loglik
		}
	}
	if (is.null(best)) return(NULL)

	best_params = as.numeric(best$coefficients)
	zero_one_names = colnames(X_zero_one)
	if (is.null(zero_one_names)) zero_one_names = paste0("x", seq_len(ncol(X_zero_one)))
	param_names = c(colnames(X), "log_phi", paste0("zero_", zero_one_names), paste0("one_", zero_one_names))
	coef_full = best_params
	names(coef_full) = param_names

	if (estimate_only) {
		return(list(
			coefficients = coef_full,
			vcov = NULL
		))
	}

	vcov_full = best$vcov
	if (!is.matrix(vcov_full) || any(dim(vcov_full) != length(param_names))){
		vcov_full = NULL
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		vcov_full = tryCatch(numDeriv::hessian(.neg_loglik_zoib, best_params, p = p, p_zero_one = ncol(X_zero_one), is_zero = is_zero, is_one = is_one, y_beta = y_beta, X_beta = X_beta, X_zero_one = X_zero_one), error = function(e) NULL)
		vcov_full = tryCatch(solve(vcov_full), error = function(e) NULL)
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		hess_alt = tryCatch(numDeriv::hessian(.neg_loglik_zoib, best_params, p = p, p_zero_one = ncol(X_zero_one), is_zero = is_zero, is_one = is_one, y_beta = y_beta, X_beta = X_beta, X_zero_one = X_zero_one), error = function(e) NULL)
		if (!is.null(hess_alt)){
			vcov_full = tryCatch(MASS::ginv(hess_alt), error = function(e) NULL)
		}
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		# Keep the MLE when curvature is too unstable for a usable covariance matrix.
		vcov_full = matrix(NA_real_, nrow = length(param_names), ncol = length(param_names))
	}
	rownames(vcov_full) = colnames(vcov_full) = param_names

	list(
		coefficients = coef_full,
		vcov = vcov_full
	)
}

