# Binary/KK matching structure builders and the KK matched-pair reservoir/bootstrap internals.

# Compute non-bipartite pair-matching structure from a covariate matrix.
# Returns a list with $indicies_pairs (n/2 x 2 integer matrix, 1-based row indices).
# Uses squared Euclidean distance by default; Mahalanobis if mahal_match = TRUE.
# For p == 1 the subjects are simply ordered and paired consecutively.
compute_binary_match_structure = function(X, mahal_match = FALSE) {
	assert_nbpmatching_installed("compute_binary_match_structure")
	n = nrow(X)
	p = ncol(X)
	if (n %% 2L != 0L) {
		stop("Design matrix must have an even number of rows for binary matching.")
	}
	if (p == 1L) {
		indicies_pairs = matrix(order(X[, 1L]), ncol = 2L, byrow = TRUE)
	} else {
		if (mahal_match) {
			S = stats::var(X)
			S_inv = tryCatch(solve(S), error = function(e) NULL)
			if (is.null(S_inv)) {
				ridge = 1e-8
				for (i in seq_len(6L)) {
					S_inv = tryCatch(solve(S + diag(ridge, ncol(S))), error = function(e) NULL)
					if (!is.null(S_inv)) break
					ridge = ridge * 10
				}
			}
			if (is.null(S_inv)) stop("Covariance matrix is singular; cannot compute Mahalanobis distances.")
			# d_Mahal(xi,xj)^2 = ||U(xi-xj)||^2 where U = chol(S_inv) (U'U = S_inv).
			# Transform X -> X %*% t(U) so squared Euclidean == squared Mahalanobis.
			U = chol(S_inv)
			D = as.matrix(stats::dist(X %*% t(U)))^2
		} else {
			D = as.matrix(stats::dist(X))^2
		}
		diag(D) = .Machine$double.xmax
		indicies_pairs = as.matrix(
			nbpMatching::nonbimatch(nbpMatching::distancematrix(D))$matches[, c("Group1.Row", "Group2.Row")]
		)
		for (i in seq_len(n)) {
			indicies_pairs[i, ] = sort(indicies_pairs[i, ])
		}
		indicies_pairs = unique(indicies_pairs)
	}
	list(indicies_pairs = indicies_pairs, indices_pairs = indicies_pairs, n = n, p = p)
}

# Classifies which custom-DGP hooks (if any) are active for a run/cell.
# Shared by the SimulationFramework worker (tags each result row) and the
# report's reference-combo grid (must agree on the same value to join on it).
compute_simulation_mode = function(custom_dgp, custom_replication_data_generator, custom_apply_treatment_and_noise, make_estimand_fn) {
	if (!is.null(custom_dgp)) {
		return("custom_dgp")
	}
	parts = c(
		if (!is.null(custom_replication_data_generator)) "crdg",
		if (!is.null(custom_apply_treatment_and_noise))  "catn",
		if (!is.null(make_estimand_fn))                  "cte"
	)
	if (length(parts) == 0L) "standard" else paste(parts, collapse = "+")
}

.compute_kk_basic_match_data = function(X, n, y, w, m_vec){
	if (is.null(m_vec)){
		m_vec = rep(NA_integer_, n)
	}
	m_vec[is.na(m_vec)] = 0
	compute_zhang_match_data_cpp(X, y, w, m_vec)
}

# Normalizes a raw KK matching-on-the-fly pair-id vector (possibly NULL, possibly
# containing NAs for unmatched subjects) and splits it into matched vs. reservoir
# subject indices. This is the boilerplate every IVWC-style KK inference class
# repeats before fitting a matched-pairs component and a separate reservoir
# component (interval_censored_survival_response.md TODO-25): normalize m_vec,
# then matched_idx/i_matched = which(m_vec > 0L), reservoir_idx/i_reservoir =
# which(m_vec == 0L). Deliberately does NOT also subset y/dead/w/X — call sites
# need those sliced into different shapes (some build a KKstats-style list, some
# call straight into a fit_cox_model()-style helper, some need bare X[idx, ]), so
# only the index computation itself is centralized here.
split_kk_matched_reservoir_idx = function(m_vec, n){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec = as.integer(m_vec)
	m_vec[is.na(m_vec)] = 0L
	list(
		m_vec = m_vec,
		matched_idx = which(m_vec > 0L),
		reservoir_idx = which(m_vec == 0L)
	)
}

# Cached variant: the X/m structural part (X_matched_diffs, X_matched_diffs_full,
# X_reservoir, m) depends only on m_vec and X, never on y or w.
#
# Cache hierarchy:
#   1. des_priv (design object's private env) — shared across ALL inference objects
#      on the same design.  Used when the current m_vec equals the design's own m_vec,
#      i.e., for the original inference and every randomization iteration (m_vec fixed,
#      only y/w permuted).
#   2. private_env (inference object's private env) — local fallback for bootstrap
#      resamples, which have a different m_vec_b and must not corrupt the design cache.
#
# Data is NEVER written to the global environment.
.compute_kk_basic_match_data_cached = function(private_env, des_priv, X, n, y, w, m_vec){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec[is.na(m_vec)] = 0L

	# --- Fast path 1: design-level structural cache ---
	if (!is.null(des_priv) &&
	    !is.null(des_priv$xm_structural) &&
	    identical(m_vec, des_priv$xm_m_vec) &&
	    ncol(X) == ncol(des_priv$xm_structural$X_reservoir)){
		wy = compute_matching_wy_stats_cpp(as.integer(w), as.numeric(y), as.integer(m_vec))
		return(c(des_priv$xm_structural, wy))
	}

	# --- Fast path 2: inference-level structural cache (bootstrap case) ---
	# --- Full computation ---
	full = compute_zhang_match_data_cpp(as.matrix(X), as.numeric(y), as.integer(w), as.integer(m_vec))
	structural = full[c("m", "X_matched_diffs", "X_matched_diffs_full", "X_reservoir")]

	# Store in the design when the current m_vec is the design's own m_vec (so all
	# inference objects on this design share it); otherwise store locally (bootstrap).
	if (!is.null(des_priv)){
		des_m = des_priv$m
		if (is.null(des_m)) des_m = rep(NA_integer_, n)
		des_m[is.na(des_m)] = 0L
		if (identical(m_vec, des_m)){
			des_priv$xm_structural = structural
			des_priv$xm_m_vec      = m_vec
		}
	}
	full
}

.compute_kk_lin_basic_match_data = function(X, n, y, w, m_vec){
	if (is.null(m_vec)){
		m_vec = rep(NA_integer_, n)
	}
	m_vec[is.na(m_vec)] = 0
	compute_matching_lin_match_data_cpp(X, y, w, m_vec)
}

# Cached variant for the lin (means + diffs) C++ path. Same hierarchy as above.
.compute_kk_lin_basic_match_data_cached = function(private_env, des_priv, X, n, y, w, m_vec){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec[is.na(m_vec)] = 0L

	if (!is.null(des_priv) &&
	    !is.null(des_priv$lin_xm_structural) &&
	    identical(m_vec, des_priv$lin_xm_m_vec) &&
	    ncol(X) == ncol(des_priv$lin_xm_structural$X_reservoir)){
		wy = compute_matching_lin_wy_stats_cpp(as.integer(w), as.numeric(y), as.integer(m_vec))
		return(c(des_priv$lin_xm_structural, wy))
	}

	full = compute_matching_lin_match_data_cpp(as.matrix(X), as.numeric(y), as.integer(w), as.integer(m_vec))
	structural = full[c("m", "X_matched_diffs_full", "X_matched_means_full", "X_reservoir")]

	if (!is.null(des_priv)){
		des_m = des_priv$m
		if (is.null(des_m)) des_m = rep(NA_integer_, n)
		des_m[is.na(des_m)] = 0L
		if (identical(m_vec, des_m)){
			des_priv$lin_xm_structural = structural
			des_priv$lin_xm_m_vec      = m_vec
		}
	}
	full
}

# Computes and caches the structural bootstrap components (i_reservoir, pair_rows, n_reservoir)
# for designs with a match vector (KK14, FixedBinaryMatch). Idempotent: no-op if already cached.
.init_kk_bootstrap_structure = function(des_priv){
	if (!is.null(des_priv$boot_pair_rows)) return(invisible(NULL))
	m_vec = des_priv$m
	n = des_priv$n
	if (is.null(m_vec)){
		des_priv$boot_i_reservoir  = seq_len(n)
		des_priv$boot_n_reservoir  = n
		des_priv$boot_pair_rows    = matrix(integer(0), nrow = 0L, ncol = 2L)
		return(invisible(NULL))
	}
	m_vec_int = as.integer(m_vec)
	m_vec_int[is.na(m_vec_int)] = 0L
	i_reservoir = which(m_vec_int == 0L)
	m_max = max(m_vec_int)
	pair_rows = if (m_max > 0L) {
		pr = matrix(integer(0), nrow = m_max, ncol = 2L)
		for (pid in seq_len(m_max)) pr[pid, ] = which(m_vec_int == pid)
		pr
	} else {
		matrix(integer(0), nrow = 0L, ncol = 2L)
	}
	des_priv$boot_i_reservoir = i_reservoir
	des_priv$boot_n_reservoir = length(i_reservoir)
	des_priv$boot_pair_rows   = pair_rows
	invisible(NULL)
}

# Draws a KK-aware bootstrap sample: resamples reservoir subjects iid and matched pairs as units.
# Returns list(i_b, m_vec_b) compatible with bootstrap_subset_inference.
.draw_kk_bootstrap_indices = function(des_priv){
	.init_kk_bootstrap_structure(des_priv)
	draw_matching_bootstrap_sample_cpp(
		i_reservoir  = des_priv$boot_i_reservoir,
		pair_rows    = des_priv$boot_pair_rows,
		n_reservoir  = des_priv$boot_n_reservoir
	)
}

.extract_se_from_rq_fit = function(fit, coef_name){
	is_bad_se = function(x) !is.finite(x) || x <= 0 || x > EDI_SEPARATION_THRESHOLD

	se = tryCatch({
		s_fit = suppressWarnings(summary(fit, se = "nid"))
		ct = s_fit$coefficients
		if (coef_name %in% rownames(ct)) ct[coef_name, "Std. Error"] else NA_real_
	}, error = function(e) NA_real_)

	if (is_bad_se(se)){
		se = tryCatch({
			s_fit = suppressWarnings(summary(fit, se = "iid"))
			ct = s_fit$coefficients
			if (coef_name %in% rownames(ct)) ct[coef_name, "Std. Error"] else NA_real_
		}, error = function(e) NA_real_)
	}

	if (is_bad_se(se)) NA_real_ else se
}

.complete_pair_index_matrix = function(pair_id){
	pair_id = as.integer(pair_id)
	valid = !is.na(pair_id) & pair_id > 0L
	if (!any(valid)) return(matrix(integer(0), ncol = 2))
	pair_rows = split(which(valid), pair_id[valid])
	pair_rows = pair_rows[lengths(pair_rows) == 2L]
	if (length(pair_rows) == 0L) return(matrix(integer(0), ncol = 2))
	pair_mat = do.call(rbind, lapply(pair_rows, function(idx) sort(as.integer(idx))))
	storage.mode(pair_mat) = "integer"
	pair_mat
}

