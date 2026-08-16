# Internal fitters for dependent-censoring/Weibull-AFT and Cox-related simulation machinery.

.weibull_aft_margin_terms = function(y, eta, sigma){
	y = pmax(as.numeric(y), .Machine$double.xmin)
	log_t = log(y)
	log_H = (log_t - eta) / sigma
	H = exp(pmin(log_H, 700))
	log_f = log_H - log(sigma) - log_t - H
	list(H = H, log_f = log_f)
}

.clayton_copula_logA = function(H1, H2, theta){
	h1 = theta * H1
	h2 = theta * H2
	m = pmax(h1, h2, 0)
	inner = exp(h1 - m) + exp(h2 - m) - exp(-m)
	inner = pmax(inner, .Machine$double.xmin)
	m + log(inner)
}

.extract_survreg_start = function(y, dead, X){
	full_names = c("(Intercept)", colnames(X))
	warm_start_beta = stats::setNames(rep(0, length(full_names)), full_names)
	start_log_sigma = 0

	mod_fast = tryCatch(fast_weibull_regression(y, dead, X), error = function(e) NULL)
	if (!is.null(mod_fast) && !is.null(mod_fast$coefficients)){
		common = intersect(names(warm_start_beta), names(mod_fast$coefficients))
		warm_start_beta[common] = mod_fast$coefficients[common]
		if (!is.null(mod_fast$log_sigma) && is.finite(mod_fast$log_sigma)){
			start_log_sigma = mod_fast$log_sigma
		}
		return(list(beta = warm_start_beta, log_sigma = start_log_sigma))
	}

	mod = robust_survreg_with_surv_object(survival::Surv(y, dead), X)
	if (is.null(mod)) return(list(beta = warm_start_beta, log_sigma = start_log_sigma))

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	common = intersect(names(warm_start_beta), names(mod_coef))
	warm_start_beta[common] = mod_coef[common]
	if (is.finite(mod_coef["log(scale)"])){
		start_log_sigma = mod_coef["log(scale)"]
	}
	list(beta = warm_start_beta, log_sigma = start_log_sigma)
}

.fit_standard_weibull_aft_from_matrix = function(y, dead, X, estimate_only = FALSE, starts = NULL, warm_start_fisher_info = NULL){
	if (length(y) == 0L || sum(dead) == 0L) return(NULL)
	mod_fast = tryCatch(
		fast_weibull_regression(
			y, dead, X,
			warm_start_params = if (length(starts) > 0) starts[[1]] else NULL,
			warm_start_fisher_info = warm_start_fisher_info,
			estimate_only = estimate_only
		),
		error = function(e) NULL
	)
	if (!is.null(mod_fast) &&
	    !is.null(mod_fast$coefficients) &&
	    (isTRUE(estimate_only) || !is.null(mod_fast$vcov)) &&
	    "w" %in% names(mod_fast$coefficients) &&
	    (isTRUE(estimate_only) || "w" %in% rownames(mod_fast$vcov))){
		beta = as.numeric(mod_fast$coefficients["w"])
		ssq = if (isTRUE(estimate_only)) NA_real_ else as.numeric(mod_fast$vcov["w", "w"])
		if (is.finite(beta) && (isTRUE(estimate_only) || (is.finite(ssq) && ssq > 0))){
			return(list(beta = beta, ssq = ssq))
		}
	}

	mod = robust_survreg_with_surv_object(survival::Surv(y, dead), X)
	if (is.null(mod) || is.null(mod$coefficients) || is.null(mod$var)) return(NULL)

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	mod_vcov = mod$var
	coef_names = c(names(mod$coefficients), "log(scale)")
	colnames(mod_vcov) = rownames(mod_vcov) = coef_names
	if (!("w" %in% names(mod_coef)) || !("w" %in% rownames(mod_vcov))) return(NULL)

	beta = as.numeric(mod_coef["w"])
	ssq = as.numeric(mod_vcov["w", "w"])
	if (!is.finite(beta) || !is.finite(ssq) || ssq <= 0) return(NULL)
	list(beta = beta, ssq = ssq)
}

.extract_lognormal_start = function(y, dead, X, event_indicator){
	full_names = c("(Intercept)", colnames(X))
	warm_start_beta = stats::setNames(rep(0, length(full_names)), full_names)
	start_log_sigma = 0

	mod = robust_survreg_with_surv_object(
		survival::Surv(y, event_indicator),
		X,
		dist = "lognormal"
	)
	if (is.null(mod)) return(list(beta = warm_start_beta, log_sigma = start_log_sigma))

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	common = intersect(names(warm_start_beta), names(mod_coef))
	warm_start_beta[common] = mod_coef[common]
	if (is.finite(mod_coef["log(scale)"])){
		start_log_sigma = mod_coef["log(scale)"]
	}
	list(beta = warm_start_beta, log_sigma = start_log_sigma)
}

.fit_dep_cens_transform_model = function(y, dead, X, estimate_only = FALSE, optimization_alg = "lbfgs"){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = pmax(as.numeric(y), .Machine$double.xmin)
	dead = as.integer(dead > 0)
	X = as.matrix(X)
	if (length(y) != nrow(X) || length(dead) != nrow(X)){
		stop("Dependent censoring transformation fit inputs must have matching row counts.")
	}
	if (sum(dead) == 0L || sum(1L - dead) == 0L) return(NULL)

	if (is.null(colnames(X))){
		full_names = c("treatment", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}

	X = cbind("(Intercept)" = 1, X)
	num_beta = ncol(X)
	log_y = log(y)

	start_event = .extract_lognormal_start(y, dead, X, dead)
	start_cens = .extract_lognormal_start(y, dead, X, 1L - dead)
	base_start = c(
		unname(start_event$beta),
		unname(start_cens$beta),
		start_event$log_sigma,
		start_cens$log_sigma
	)

	neg_loglik = function(par){
		beta_event = par[seq_len(num_beta)]
		beta_cens = par[num_beta + seq_len(num_beta)]
		log_sigma_event = par[2L * num_beta + 1L]
		log_sigma_cens = par[2L * num_beta + 2L]
		atanh_rho = par[2L * num_beta + 3L]

		if (!is.finite(log_sigma_event) || !is.finite(log_sigma_cens) ||
		    log_sigma_event < -8 || log_sigma_event > 8 ||
		    log_sigma_cens < -8 || log_sigma_cens > 8 ||
		    !is.finite(atanh_rho) || abs(atanh_rho) > 8){
			return(1e100)
		}

		sigma_event = exp(log_sigma_event)
		sigma_cens = exp(log_sigma_cens)
		rho = tanh(atanh_rho)
		one_minus_rho_sq = pmax(1 - rho^2, .Machine$double.eps)
		sd_cond = sqrt(one_minus_rho_sq)

		mu_event = as.vector(X %*% beta_event)
		mu_cens = as.vector(X %*% beta_cens)
		z_event = (log_y - mu_event) / sigma_event
		z_cens = (log_y - mu_cens) / sigma_cens

		log_f_event = stats::dnorm(z_event, log = TRUE) - log_sigma_event - log_y
		log_f_cens = stats::dnorm(z_cens, log = TRUE) - log_sigma_cens - log_y
		log_surv_cens_cond = stats::pnorm((rho * z_event - z_cens) / sd_cond, log.p = TRUE)
		log_surv_event_cond = stats::pnorm((rho * z_cens - z_event) / sd_cond, log.p = TRUE)

		loglik = dead * (log_f_event + log_surv_cens_cond) +
			(1 - dead) * (log_f_cens + log_surv_event_cond)
		if (any(!is.finite(loglik))) return(1e100)
		-sum(loglik)
	}

	starts = if (isTRUE(estimate_only)) {
		# For bootstrap iterations, use only one start (no correlation) for speed.
		list(c(base_start, 0))
	} else {
		list(
			c(base_start, 0),
			c(base_start, atanh(0.25)),
			c(base_start, atanh(-0.25))
		)
	}
	best = NULL
	# Attempt C++ fast path first
	for (start_par in starts) {
		fit = tryCatch(
			fast_dep_cens_transform_optim_cpp(
				y = y, dead = dead, X = X, warm_start_params = start_par,
				maxit = 2000, reltol = if (isTRUE(estimate_only)) 1e-7 else 1e-9,
				optimization_alg = optimization_alg
			),
			error = function(e) NULL
		)
		if (!is.null(fit) && isTRUE(fit$converged) && is.finite(fit$value)) {
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}

	# Fallback to R optim if C++ failed to converge
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "BFGS",
					hessian = !isTRUE(estimate_only),
					control = list(
						maxit = 2000, 
						# Tight tolerance for main estimate, looser for bootstrap iterations
						reltol = if (isTRUE(estimate_only)) 1e-7 else 1e-9
					)
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}
	if (is.null(best)) return(NULL)

	if (isTRUE(estimate_only)) {
		coefficients = best$par
		event_names = colnames(X)
		cens_names = paste0("censoring_", event_names)
		param_names = c(event_names, cens_names, "log_scale_event", "log_scale_censoring", "atanh_rho")
		names(coefficients) = param_names
		return(list(coefficients = coefficients, vcov = NULL))
	}

	hess = best$hessian
	vcov_full = tryCatch(solve(hess), error = function(e) NULL)
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))) return(NULL)

	event_names = colnames(X)
	cens_names = paste0("censoring_", event_names)
	param_names = c(event_names, cens_names, "log_scale_event", "log_scale_censoring", "atanh_rho")
	rownames(vcov_full) = colnames(vcov_full) = param_names

	coefficients = best$par
	names(coefficients) = param_names
	list(coefficients = coefficients, vcov = vcov_full)
}

.fit_clayton_weibull_aft = function(y, dead, X, pair_id, include_singletons = FALSE, starts = NULL, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = as.numeric(y)
	dead = as.integer(dead > 0)
	X = as.matrix(X)
	if (is.null(colnames(X))){
		full_names = c("w", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}
	if (length(y) != nrow(X) || length(dead) != nrow(X) || length(pair_id) != nrow(X)){
		stop("Clayton copula fit inputs must have matching row counts.")
	}

	pair_idx = .complete_pair_index_matrix(pair_id)
	if (nrow(pair_idx) == 0L && !include_singletons) return(NULL)

	pair_rows = if (nrow(pair_idx) > 0L) sort(unique(as.vector(pair_idx))) else integer(0)
	singleton_rows = if (include_singletons) setdiff(seq_len(nrow(X)), pair_rows) else integer(0)
	rows_used = sort(unique(c(pair_rows, singleton_rows)))
	if (length(rows_used) == 0L || sum(dead[rows_used]) == 0L) return(NULL)

	X = cbind("(Intercept)" = 1, X)
	num_beta = ncol(X)

	# Pre-extract constant indices and values for the likelihood function to avoid overhead
	has_pairs = nrow(pair_idx) > 0L
	if (has_pairs){
		i1 = pair_idx[, 1]
		i2 = pair_idx[, 2]
		d1 = dead[i1]
		d2 = dead[i2]
		mask00 = d1 == 0L & d2 == 0L
		mask10 = d1 == 1L & d2 == 0L
		mask01 = d1 == 0L & d2 == 1L
		mask11 = d1 == 1L & d2 == 1L
	}
	has_singletons = length(singleton_rows) > 0L
	if (has_singletons){
		d_sg = dead[singleton_rows]
		d_sg_comp = 1 - d_sg
	}

	neg_loglik = function(par){
		log_sigma = par[num_beta + 1L]
		log_theta = par[num_beta + 2L]
		if (!is.finite(log_sigma) || !is.finite(log_theta) ||
		    log_sigma < -8 || log_sigma > 8 || log_theta < -12 || log_theta > 6){
			return(1e100)
		}
		sigma = exp(log_sigma)
		theta = exp(log_theta)
		eta = as.vector(X %*% par[seq_len(num_beta)])
		margin_terms = .weibull_aft_margin_terms(y, eta, sigma)
		H = margin_terms$H
		log_f = margin_terms$log_f

		loglik = 0
		if (has_pairs){
			H1 = H[i1]
			H2 = H[i2]
			logf1 = log_f[i1]
			logf2 = log_f[i2]
			logA = .clayton_copula_logA(H1, H2, theta)
			pair_ll = numeric(length(i1))

			pair_ll[mask00] = -(1 / theta) * logA[mask00]
			pair_ll[mask10] = logf1[mask10] + (-1 / theta - 1) * logA[mask10] + (theta + 1) * H1[mask10]
			pair_ll[mask01] = logf2[mask01] + (-1 / theta - 1) * logA[mask01] + (theta + 1) * H2[mask01]
			pair_ll[mask11] = log(theta + 1) + logf1[mask11] + logf2[mask11] +
				(-1 / theta - 2) * logA[mask11] + (theta + 1) * (H1[mask11] + H2[mask11])

			if (any(!is.finite(pair_ll))) return(1e100)
			loglik = loglik + sum(pair_ll)
		}

		if (has_singletons){
			sg_ll = d_sg * log_f[singleton_rows] - d_sg_comp * H[singleton_rows]
			if (any(!is.finite(sg_ll))) return(1e100)
			loglik = loglik + sum(sg_ll)
		}

		if (!is.finite(loglik)) return(1e100)
		-loglik
	}

	if (is.null(starts)){
		X_no_int = X[rows_used, -1L, drop = FALSE]
		start = .extract_survreg_start(y[rows_used], dead[rows_used], X_no_int)
		start_par_base = c(unname(start$beta), start$log_sigma)
		starts = list(
			c(start_par_base, log(0.10)),
			c(start_par_base, log(0.50)),
			c(start_par_base, log(1.50))
		)
	}

	best = NULL
	# Use a slightly coarser tolerance for randomization draws if nsim is high
	control_list = list(maxit = 2000, reltol = 1e-9)

	# Attempt C++ fast path first
	for (start_par in starts) {
		fit = tryCatch(
			fast_clayton_weibull_aft_optim_cpp(
				y = y, dead = dead, X = X,
				pair_idx = if (has_pairs) pair_idx - 1L else matrix(0L, 0, 2),
				singleton_rows = if (has_singletons) singleton_rows - 1L else integer(0),
				warm_start_params = start_par,
				maxit = 2000, reltol = 1e-9,
				optimization_alg = optimization_alg,
				warm_start_fisher_info = warm_start_fisher_info
			),
			error = function(e) NULL
		)
		if (!is.null(fit) && isTRUE(fit$converged) && is.finite(fit$value)) {
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}

	# Fallback to R optim (BFGS) if C++ failed to converge
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "BFGS",
					hessian = !isTRUE(estimate_only),
					control = control_list
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value){
				best = fit
			}
		}
	}
	# Final fallback to Nelder-Mead (derivative-free, more robust)
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "Nelder-Mead",
					hessian = FALSE,
					control = list(maxit = 10000, reltol = 1e-8)
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value){
				best = fit
			}
		}
	}
	if (is.null(best)) return(NULL)

	beta_hat = best$par[seq_len(num_beta)]
	names(beta_hat) = colnames(X)
	
	if (isTRUE(estimate_only)){
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	vcov_full = NULL
	if (!is.null(best$vcov)) {
		vcov_cpp = tryCatch(as.matrix(best$vcov), error = function(e) NULL)
		if (!is.null(vcov_cpp) && nrow(vcov_cpp) == num_beta + 2L && all(is.finite(diag(vcov_cpp)))) {
			vcov_full = vcov_cpp
		}
	}
	if (is.null(vcov_full)) {
		hess = best$hessian
		vcov_full = tryCatch(solve(hess), error = function(e) NULL)
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))) {
		X_no_int = X[, -1L, drop = FALSE]
		hess_cpp = tryCatch(
			get_clayton_weibull_aft_hessian_cpp(
				X_no_int, y, dead,
				if (has_pairs) pair_idx - 1L else matrix(0L, 0, 2),
				if (has_singletons) singleton_rows - 1L else integer(0),
				best$par
			),
			error = function(e) NULL
		)
		if (!is.null(hess_cpp)) {
			vcov_full = tryCatch(solve(-hess_cpp), error = function(e) NULL)
			if (!is.null(vcov_full) && any(!is.finite(diag(vcov_full)))) vcov_full = NULL
		}
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	rownames(vcov_full) = colnames(vcov_full) = c(colnames(X), "log_sigma", "log_theta")
	ssq = as.numeric(vcov_full["w", "w"])
	if (!is.finite(beta_hat["w"]) || !is.finite(ssq) || ssq <= 0) {
		# If w is not finite or ssq is not valid, we still return the best_par for potential reuse
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	list(
		beta = as.numeric(beta_hat["w"]),
		ssq = ssq,
		theta = exp(best$par[num_beta + 2L]),
		log_sigma = best$par[num_beta + 1L],
		best_par = best$par,
		best_fit = best
	)
}

.fit_weibull_frailty = function(y, dead, X, pair_id, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL){
	.fit_weibull_frailty_rcpp(
		y = y,
		dead = dead,
		X = X,
		pair_id = pair_id,
		estimate_only = estimate_only,
		optimization_alg = optimization_alg,
		warm_start_params = warm_start_params,
		warm_start_fisher_info = warm_start_fisher_info
	)
}

.fit_weibull_frailty_rcpp = function(y, dead, X, pair_id, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	if (length(y) == 0L || sum(dead) == 0L) return(NULL)

	X = as.matrix(X)
	if (!("w" %in% colnames(X))){
		stop("X must include a treatment column named 'w'.")
	}
	if (!identical(colnames(X)[1L], "w")){
		X = X[, c("w", setdiff(colnames(X), "w")), drop = FALSE]
	}

	group_id = as.integer(factor(pair_id))
	if (anyNA(group_id)) return(NULL)

	mod = tryCatch(
		fast_weibull_frailty_cpp(
			y = as.numeric(y),
			dead = as.numeric(dead),
			X = X,
			group_id = group_id,
			warm_start_params = warm_start_params,
			warm_start_fisher_info = warm_start_fisher_info,
			estimate_only = estimate_only,
			optimization_alg = optimization_alg
		),
		error = function(e) NULL
	)
	if (is.null(mod) || !isTRUE(mod$converged) || length(mod$b) < 1L) return(NULL)

	beta = as.numeric(mod$b[1L])
	if (!is.finite(beta)) return(NULL)

	ssq = if (estimate_only) NA_real_ else as.numeric(mod$ssq_b_T)
	if (!estimate_only && (!is.finite(ssq) || ssq <= 0)) return(NULL)

	list(
		beta = beta,
		ssq = ssq,
		log_sigma_eps = as.numeric(mod$log_sigma_eps),
		log_sigma_u = as.numeric(mod$log_sigma_u),
		neg_loglik = as.numeric(mod$neg_loglik),
		best_par = c(as.numeric(mod$b), as.numeric(mod$log_sigma_eps), as.numeric(mod$log_sigma_u)),
		mod = mod
	)
}

# Breslow non-parametric baseline hazard estimate for Cox PH simulation.
# Returns list(times, cumhaz) with the cumulative baseline hazard at each unique event time.
.breslow_hazard = function(y, dead, X, b_null){
	if (length(y) == 0L || sum(dead) == 0L) return(list(times = numeric(0), cumhaz = numeric(0)))
	eta = as.numeric(X %*% b_null)
	risk = exp(eta - max(eta))
	o = order(y, -dead)
	y_o = y[o]; dead_o = dead[o] > 0.5; risk_o = risk[o]
	event_times = unique(y_o[dead_o])
	if (length(event_times) == 0L) return(list(times = numeric(0), cumhaz = numeric(0)))
	cumhaz = numeric(length(event_times))
	h_acc = 0
	for (k in seq_along(event_times)){
		at_risk = y_o >= event_times[k]
		R_k = sum(risk_o[at_risk])
		d_k = sum(dead_o[y_o == event_times[k]])
		h_acc = h_acc + d_k / max(R_k, 1e-10)
		cumhaz[k] = h_acc
	}
	list(times = event_times, cumhaz = cumhaz)
}

# Simulate survival times under a stratified Cox model using per-stratum Breslow baselines.
.cox_simulate_stratified = function(y_obs, dead_obs, X_null, b_null, strata){
	n = nrow(X_null)
	eta = as.numeric(X_null %*% b_null)
	risk_i = exp(eta - max(eta))
	max_time = max(y_obs) * 2
	T_sim = rep(max_time, n)
	for (s in unique(strata)){
		idx = which(strata == s)
		breslow_s = .breslow_hazard(y_obs[idx], dead_obs[idx], X_null[idx, , drop = FALSE], b_null)
		if (length(breslow_s$times) == 0L) next
		for (i in idx){
			U = runif(1L)
			tgt = -log(max(U, 1e-10)) / risk_i[i]
			j_k = which(breslow_s$cumhaz >= tgt)
			T_sim[i] = if (length(j_k) == 0L) max_time else breslow_s$times[j_k[1L]]
		}
	}
	C_i = ifelse(dead_obs == 0, y_obs, Inf)
	y_sim = pmin(T_sim, C_i)
	dead_sim = as.numeric(T_sim <= C_i)
	list(y_sim = y_sim, dead_sim = dead_sim)
}

# Simulate survival times by inverting the Breslow baseline hazard.
# Returns list(y_sim, dead_sim) applying observed censoring times.
.cox_simulate_from_breslow = function(breslow, y_obs, dead_obs, X_null, b_null){
	n = nrow(X_null)
	eta = as.numeric(X_null %*% b_null)
	risk_i = exp(eta - max(eta))
	U = runif(n)
	target = -log(pmax(U, 1e-10))
	times = breslow$times
	cumhaz = breslow$cumhaz
	max_time = max(y_obs) * 2
	T_sim = vapply(seq_len(n), function(i){
		tgt = target[i] / risk_i[i]
		idx = which(cumhaz >= tgt)
		if (length(idx) == 0L) max_time else times[idx[1L]]
	}, numeric(1L))
	C_i = ifelse(dead_obs == 0, y_obs, Inf)
	y_sim = pmin(T_sim, C_i)
	dead_sim = as.numeric(T_sim <= C_i)
	list(y_sim = y_sim, dead_sim = dead_sim)
}

