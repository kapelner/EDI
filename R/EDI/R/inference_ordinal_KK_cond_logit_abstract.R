ordinal_cond_clogit_compute_setup = function(private_env){
	m_vec = private_env$m
	if (is.null(m_vec)) m_vec = rep(NA_integer_, private_env$n)
	m_vec[is.na(m_vec)] = 0L

	strata_ids = m_vec
	reservoir_idx = which(strata_ids == 0L)
	if (length(reservoir_idx) > 0L){
		strata_ids[reservoir_idx] = max(strata_ids) + seq_along(reservoir_idx)
	}

	y_ord = as.integer(factor(private_env$y, ordered = TRUE))
	K = max(y_ord)

	list(
		strata_ids = strata_ids,
		y_ord = y_ord,
		K = K,
		n_alpha = K - 1L
	)
}





ordinal_cond_clogit_shared_multi = function(private_env, expand_fun, trials_fun){
	if (!is.null(private_env$cached_values$beta_hat_T)) return(invisible(NULL))

	setup = ordinal_cond_clogit_compute_setup(private_env)
	if (setup$K < 2L){
		private_env$cache_nonestimable_estimate("ordinal_cond_clogit_too_few_categories")
		return(invisible(NULL))
	}

	expanded = expand_fun(
		as.integer(setup$y_ord),
		as.integer(private_env$w),
		as.integer(setup$strata_ids),
		as.integer(setup$K)
	)

	X = private_env$get_X()
	X_stack_list = list()
	for (i in seq_len(private_env$n)) {
		trials_i = trials_fun(setup$y_ord[i], setup$n_alpha)
		if (length(trials_i) > 0L) {
			X_stack_list[[i]] = matrix(rep(X[i, ], each = length(trials_i)), nrow = length(trials_i))
		}
	}
	X_stack = do.call(rbind, X_stack_list)
	X_full = cbind(treatment = expanded$w, X_stack)
	attempt = private_env$fit_with_hardened_qr_column_dropping(
		X_full = X_full,
		required_cols = 1L,
		fit_fun = function(X_fit){
			clogit_helper(
				expanded$y,
				as.data.frame(X_fit[, -1, drop = FALSE]),
				X_fit[, 1],
				expanded$strata
			)
		},
		fit_ok = function(mod, X_fit, keep){
			# The |beta| <= 10 ceiling mirrors the divergence guard used by
			# InferenceOrdinalStereotypeLogitRegr's stereotype_fit_is_usable():
			# a conditional-logit MLE under quasi-complete separation (small
			# strata, sparse categories) can converge to a large but
			# technically finite, technically-estimable coefficient. Finiteness
			# and a positive variance alone don't catch that; reject it as
			# unusable the same way the stereotype model does.
			!is.null(mod) &&
				is.finite(mod$b[1]) &&
				abs(mod$b[1]) <= 10 &&
				is.finite(mod$ssq_b_j) &&
				mod$ssq_b_j > 0
		}
	)
	mod = attempt$fit
	if (is.null(mod) || !is.finite(mod$b[1]) || !is.finite(mod$ssq_b_j) || mod$ssq_b_j <= 0){
		private_env$cache_nonestimable_estimate("ordinal_cond_clogit_fit_unavailable")
		return(invisible(NULL))
	}

	private_env$cached_values$beta_hat_T   = as.numeric(mod$b[1])
	private_env$cached_values$s_beta_hat_T = sqrt(as.numeric(mod$ssq_b_j))
}

OrdinalConditionalLogitPartialLikelihoodSource = list(
	public = list(),
	private = list(
		ordinal_cond_clogit_compute_setup = function() {
			ordinal_cond_clogit_compute_setup(private)
		},
		ordinal_cond_clogit_shared_multi = function(expand_fun, trials_fun) {
			ordinal_cond_clogit_shared_multi(private, expand_fun, trials_fun)
		}
	)
)
