#' Robust sandwich variance helpers
#'
#' @keywords internal
#' @noRd
robust_sandwich_meat_from_residuals = function(X, residuals) {
	X = as.matrix(X)
	residuals = as.numeric(residuals)
	if (nrow(X) == 0L || ncol(X) == 0L || length(residuals) != nrow(X)) {
		return(NULL)
	}
	if (any(!is.finite(X)) || any(!is.finite(residuals))) {
		return(NULL)
	}
	crossprod(X, X * (residuals^2))
}

#' @keywords internal
#' @noRd
robust_sandwich_vcov = function(bread, meat) {
	bread = as.matrix(bread)
	meat = as.matrix(meat)
	if (nrow(bread) == 0L || ncol(bread) == 0L || !identical(dim(bread), dim(meat))) {
		return(NULL)
	}
	if (nrow(bread) != ncol(bread) || any(!is.finite(bread)) || any(!is.finite(meat))) {
		return(NULL)
	}
	vcov = bread %*% meat %*% bread
	if (any(!is.finite(vcov))) {
		return(NULL)
	}
	vcov
}

#' @keywords internal
#' @noRd
robust_sandwich_variance = function(vcov, j) {
	j = as.integer(j)
	if (length(j) != 1L || !is.finite(j) || j < 1L) {
		return(NA_real_)
	}
	vcov = as.matrix(vcov)
	if (j > nrow(vcov) || j > ncol(vcov)) {
		return(NA_real_)
	}
	ssq = as.numeric(vcov[j, j])
	if (!is.finite(ssq) || ssq < 0) {
		return(NA_real_)
	}
	# A perfect fit (all residuals ~0, e.g. y exactly determined by w) collapses
	# HC0 to a numerically-zero variance that still passes `> 0` and yields a
	# zero-width CI with p = 0. Not estimable. The floor is on the variance
	# (ssq < eps, i.e. SE < sqrt(eps)) and is absolute, appropriate for the
	# probability/log-scale coefficients this is used on; a response in tiny
	# units would need a scale-relative floor instead.
	if (ssq < .Machine$double.eps) {
		return(NA_real_)
	}
	ssq
}

#' @keywords internal
#' @noRd
robust_sandwich_variance_from_xtwx = function(X, residuals, XtWX, j) {
	meat = robust_sandwich_meat_from_residuals(X, residuals)
	if (is.null(meat)) {
		return(NA_real_)
	}
	bread = tryCatch(
		solve(XtWX),
		error = function(e) {
			if (is_edi_control_condition(e)) stop(e)
			NULL
		}
	)
	if (is.null(bread)) {
		return(NA_real_)
	}
	vcov = robust_sandwich_vcov(bread, meat)
	if (is.null(vcov)) {
		return(NA_real_)
	}
	robust_sandwich_variance(vcov, j)
}

RobustSandwichSource = list(
	public = list(),
	private = list(
		robust_sandwich_meat_from_residuals = function(X, residuals) {
			robust_sandwich_meat_from_residuals(X, residuals)
		},
		robust_sandwich_vcov = function(bread, meat) {
			robust_sandwich_vcov(bread, meat)
		},
		robust_sandwich_variance = function(vcov, j) {
			robust_sandwich_variance(vcov, j)
		},
		robust_sandwich_variance_from_xtwx = function(X, residuals, XtWX, j) {
			robust_sandwich_variance_from_xtwx(X, residuals, XtWX, j)
		}
	)
)

#' CR2 (Bell-McCaffrey) cluster-robust variance for one OLS coefficient
#'
#' Bias-reduced linearization sandwich clustered on `cluster`. Returns the
#' variance of coefficient `j` and Bell-McCaffrey (Satterthwaite) degrees of
#' freedom computed under the identity working model, as in
#' `clubSandwich::coef_test(vcov = "CR2", test = "Satterthwaite")`. The df falls
#' back to the conventional G - 1 when the Satterthwaite computation is not
#' finite/positive. Returns NULL when not estimable (fewer than 3 clusters,
#' non-finite input).
#'
#' @keywords internal
#' @noRd
cluster_robust_cr2_variance = function(X, y, coef_hat, cluster, j) {
	X = as.matrix(X)
	y = as.numeric(y)
	cluster = as.character(cluster)
	if (length(cluster) != nrow(X) || length(y) != nrow(X) || anyNA(cluster)) return(NULL)
	if (any(!is.finite(X)) || any(!is.finite(y)) || any(!is.finite(coef_hat))) return(NULL)
	groups = split(seq_len(nrow(X)), cluster)
	G = length(groups)
	if (G < 3L) return(NULL)
	XtX_inv = tryCatch(solve(crossprod(X)), error = function(e) NULL)
	if (is.null(XtX_inv)) return(NULL)
	e = y - as.numeric(X %*% coef_hat)
	meat = matrix(0, ncol(X), ncol(X))
	n = nrow(X)
	xc = as.numeric(XtX_inv[, j])            # XtX^{-1} e_j
	Umat = matrix(0, n, G)                   # columns u_g, V = sum_g (u_g' eps)^2
	gi = 0L
	for (idx in groups) {
		gi = gi + 1L
		Xg = X[idx, , drop = FALSE]
		M = diag(length(idx)) - Xg %*% XtX_inv %*% t(Xg)
		M = (M + t(M)) / 2
		eg = eigen(M, symmetric = TRUE)
		keep = eg$values > 1e-10 * max(1, max(eg$values))
		inv_sqrt = if (any(keep)) {
			eg$vectors[, keep, drop = FALSE] %*% (t(eg$vectors[, keep, drop = FALSE]) / sqrt(eg$values[keep]))
		} else {
			matrix(0, length(idx), length(idx))
		}
		s = crossprod(Xg, inv_sqrt %*% e[idx])
		meat = meat + s %*% t(s)
		# Satterthwaite pieces: w = A_g d_g, u_g = (I - H)' E_g' w
		w = inv_sqrt %*% as.numeric(Xg %*% xc)
		ug = numeric(n)
		ug[idx] = w
		Umat[, gi] = ug - as.numeric(X %*% (XtX_inv %*% crossprod(Xg, w)))
	}
	vcov = XtX_inv %*% meat %*% XtX_inv
	ssq = as.numeric(vcov[j, j])
	if (!is.finite(ssq) || ssq < .Machine$double.eps) return(NULL)
	df = G - 1L
	K = crossprod(Umat)
	df_sat = sum(diag(K))^2 / sum(K^2)
	if (is.finite(df_sat) && df_sat > 0) df = df_sat
	list(ssq = ssq, df = df, vcov = vcov)
}

#' Cluster ids of the design behind an Inference object, or NULL when the
#' design is not cluster-capable / ids are unavailable.
#'
#' @keywords internal
#' @noRd
design_cluster_ids_for_inference = function(des_obj, des_priv, n) {
	if (is.null(des_obj) || is.null(des_priv)) return(NULL)
	if (!isTRUE(tryCatch(des_obj$is_a_cluster_capable(), error = function(e) FALSE))) return(NULL)
	col = des_priv$cluster_col
	Xraw = des_priv$Xraw
	if (is.null(col) || is.null(Xraw) || !(col %in% names(Xraw))) return(NULL)
	ids = as.character(Xraw[seq_len(n), ][[col]])
	if (anyNA(ids)) return(NULL)
	ids
}

#' Interim warning (TODO-103): classes whose Wald SE or likelihood-based
#' (score / gradient / LR / Bartlett / parametric-bootstrap) procedures treat
#' subjects as independent, used on a cluster-capable design.
#'
#' Called from the shared entry points (the Wald helpers in \code{InferenceAsymp},
#' the likelihood-test / CI-inversion helpers, and the parametric-bootstrap
#' public methods). Warns at most once per inference object per procedure
#' \code{family}. Silent on non-cluster designs, while a resampling operation
#' (rand / bootstrap / jackknife / parametric-bootstrap worker) is active, and
#' for Wald inference whose SE is already cluster-robust (OLS / Lin CR2).
#' The condition has class \code{edi_cluster_independence_warning}, so
#' \code{suppressWarnings(expr, classes = "edi_cluster_independence_warning")}
#' silences it selectively.
#'
#' @keywords internal
#' @noRd
edi_warn_cluster_independence_once = function(self, private, family = c("wald", "likelihood")) {
	family = match.arg(family)
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	des = private$des_obj
	if (is.null(des) || !isTRUE(tryCatch(des$is_a_cluster_capable(), error = function(e) FALSE))) return(invisible(FALSE))
	if (family == "wald" && isTRUE(private$cached_values$cluster_robust_se_applied)) return(invisible(FALSE))
	if (family %in% private$cluster_independence_warned) return(invisible(FALSE))
	private$cluster_independence_warned = c(private$cluster_independence_warned, family)
	what = if (family == "wald") {
		"Wald standard error, p-value and confidence interval"
	} else {
		"likelihood-based (score, gradient, likelihood-ratio, Bartlett, parametric-bootstrap) tests and intervals"
	}
	msg = paste0(
		class(self)[1L], " on a cluster design: the ", what, " treat subjects as independent, ",
		"ignoring within-cluster correlation, so they may be too narrow (p-values too small). ",
		"Cluster-aware alternatives: compute_rand_two_sided_pval() / compute_rand_confidence_interval(), ",
		"compute_bootstrap_two_sided_pval() / compute_bootstrap_confidence_interval() (these resample whole clusters), ",
		"or compute_jackknife_wald_two_sided_pval() / compute_jackknife_wald_confidence_interval() with unit = \"cluster\". ",
		"Suppress with suppressWarnings(expr, classes = \"edi_cluster_independence_warning\")."
	)
	warning(structure(
		class = c("edi_cluster_independence_warning", "warning", "condition"),
		list(message = msg, call = NULL)
	))
	invisible(TRUE)
}

#' Record why a swallowed likelihood-test computation failed (TODO-115).
#'
#' Called from the \code{tryCatch} error handlers of the shared likelihood-test
#' machinery so that \code{edi_warn_lik_test_unavailable_once()} can quote the
#' reason. Stored in \code{private$cached_values$likelihood_test_failure_reason},
#' a character vector named by testing type. \code{overwrite = FALSE} keeps an
#' earlier (more specific) message. Never errors and never changes results.
#'
#' @keywords internal
#' @noRd
edi_note_lik_test_failure = function(private, testing_type, reason, overwrite = TRUE) {
	try({
		if (is.null(private$cached_values)) return(invisible(NULL))
		msg = if (inherits(reason, "condition")) conditionMessage(reason) else as.character(reason)[1L]
		if (is.na(msg) || !nzchar(msg)) return(invisible(NULL))
		testing_type = as.character(testing_type)[1L]
		cur = private$cached_values$likelihood_test_failure_reason
		if (is.null(cur)) cur = character()
		if (!overwrite && testing_type %in% names(cur)) return(invisible(NULL))
		cur[testing_type] = msg
		private$cached_values$likelihood_test_failure_reason = cur
	}, silent = TRUE)
	invisible(NULL)
}

#' Testing type encoded in a warm-start cache key such as
#' \code{"likelihood_test:score"} or \code{"lik_ratio_ci"}.
#'
#' @keywords internal
#' @noRd
edi_lik_test_type_from_cache_key = function(cache_key) {
	sub("_ci$", "", sub("^likelihood_test:", "", as.character(cache_key)[1L]))
}

#' General guard (TODO-115): a likelihood test (score / gradient / LR /
#' Bartlett) came back NA although the Wald result for the same estimate is
#' finite. Emits a classed warning \code{edi_lik_test_unavailable_warning}
#' (fields \code{testing_type}, \code{reason}) at most once per inference
#' object and testing type. Never changes any returned value; call it BEFORE
#' \code{cache_nonestimable_se()}/\code{cache_nonestimable_estimate()}, which
#' blank the Wald quantities.
#'
#' Silent while a resampling operation (rand / bootstrap / jackknife /
#' parametric-bootstrap worker) is active, when the estimate itself is
#' non-estimable, when the Wald p-value is not finite either (legitimate
#' non-estimability), and when \code{edi_lik_test_wald_fallback} already
#' announced this testing type. If an earlier likelihood-test failure already
#' blanked the Wald SE (reason ending in \code{_test_unavailable}), Wald is
#' treated as having been finite.
#'
#' @keywords internal
#' @noRd
edi_warn_lik_test_unavailable_once = function(self, private, testing_type, delta = 0, reason = NULL) {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	testing_type = as.character(testing_type)[1L]
	if (is.na(testing_type) || identical(testing_type, "wald")) return(invisible(FALSE))
	cv = private$cached_values
	if (is.null(cv)) return(invisible(FALSE))
	if (testing_type %in% (cv$lik_test_unavailable_warned %||% character())) return(invisible(FALSE))
	if (testing_type %in% (cv$lik_test_wald_fallback_warned %||% character())) return(invisible(FALSE))
	if (isTRUE(self$is_nonestimable("estimate"))) return(invisible(FALSE))
	prior_lik_failure = isTRUE(cv$nonestimable) && grepl("_test_unavailable$", as.character(cv$nonestimable_reason %||% ""))
	if (!prior_lik_failure) {
		if (isTRUE(self$is_nonestimable())) return(invisible(FALSE))
		wald_p = tryCatch(suppressWarnings(as.numeric(private$compute_wald_two_sided_pval_impl(delta))[1L]), error = function(e) NA_real_)
		if (!is.finite(wald_p)) return(invisible(FALSE))
	}
	private$cached_values$lik_test_unavailable_warned = c(cv$lik_test_unavailable_warned %||% character(), testing_type)
	if (is.null(reason) || !nzchar(reason)) {
		reason = (cv$likelihood_test_failure_reason %||% character())[testing_type]
		if (is.null(reason) || length(reason) == 0L || is.na(reason)) {
			reason = "no error message was recorded (the null-restricted refit, score, or log-likelihood evaluation returned a non-finite or unusable value)"
		}
	}
	reason = unname(as.character(reason)[1L])
	warning(structure(
		class = c("edi_lik_test_unavailable_warning", "warning", "condition"),
		list(
			message = paste0(
				class(self)[1L], ": the ", testing_type, " test is unavailable (NA) although the Wald result is finite. ",
				"Reason: ", reason, ". The NA is returned unchanged; use testing_type = \"wald\" (or a resampling-based ",
				"p-value / interval) if you need a result for this estimate. ",
				"Suppress with suppressWarnings(expr, classes = \"edi_lik_test_unavailable_warning\")."
			),
			call = NULL,
			testing_type = testing_type,
			reason = reason
		)
	))
	invisible(TRUE)
}

#' Make a Wald-interval substitution under a likelihood label visible (TODO-115).
#'
#' Called by \code{finalize_inverted_ci()} when an inverted score / gradient /
#' LR / Bartlett interval is unusable and the Wald interval is returned in its
#' place, and by \code{invert_test_pval_confidence_interval()} when there is no
#' likelihood specification and Wald p-values are inverted under a likelihood
#' label. The reason is always recorded in
#' \code{private$cached_values$ci_fallback_reason} (character vector named by
#' testing type, first reason wins) so callers and tests can inspect it. A
#' classed warning (\code{edi_lik_ci_wald_fallback}, which also inherits
#' \code{edi_lik_test_wald_fallback}; fields \code{testing_type}, \code{reason})
#' is emitted at most once per object and testing type, sharing the
#' \code{lik_test_wald_fallback_warned} ledger with the p-value fallback so the
#' same substitution never warns twice, and never inside a resampling worker.
#' The returned interval is never changed.
#'
#' @keywords internal
#' @noRd
edi_warn_ci_wald_fallback_once = function(self, private, testing_type, reason) {
	testing_type = as.character(testing_type)[1L]
	if (is.na(testing_type) || identical(testing_type, "wald")) return(invisible(FALSE))
	cv = private$cached_values
	if (is.null(cv)) return(invisible(FALSE))
	reason = unname(as.character(reason)[1L])
	fail = unname((cv$likelihood_test_failure_reason %||% character())[testing_type])
	if (length(fail) == 1L && !is.na(fail) && nzchar(fail)) reason = paste0(reason, "; underlying failure: ", fail)
	rec = cv$ci_fallback_reason %||% character()
	if (!(testing_type %in% names(rec))) {
		rec[testing_type] = reason
		private$cached_values$ci_fallback_reason = rec
	}
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	warned = cv$lik_test_wald_fallback_warned %||% character()
	if (testing_type %in% warned) return(invisible(FALSE))
	private$cached_values$lik_test_wald_fallback_warned = c(warned, testing_type)
	warning(structure(
		class = c("edi_lik_ci_wald_fallback", "edi_lik_test_wald_fallback", "warning", "condition"),
		list(
			message = paste0(
				class(self)[1L], ": the ", testing_type, " confidence interval could not be obtained by test inversion (",
				reason, "), so the returned interval is the Wald interval, NOT a ", testing_type, " interval. ",
				"Use compute_wald_confidence_interval() explicitly if that is what you want. ",
				"Suppress with suppressWarnings(expr, classes = \"edi_lik_test_wald_fallback\")."
			),
			call = NULL,
			testing_type = testing_type,
			reason = reason
		)
	))
	invisible(TRUE)
}

#' Explain a bootstrap p-value that is \code{NA} only because some replicates
#' were non-finite (TODO-116 follow-up).
#'
#' \code{compute_bootstrap_two_sided_pval()} and
#' \code{compute_bayesian_bootstrap_two_sided_pval()} default to
#' \code{na.rm = FALSE} and return \code{NA} if any replicate is non-finite,
#' while the matching confidence-interval methods always drop non-finite
#' replicates. Emits a classed warning \code{edi_bootstrap_nonfinite_na_warning}
#' (fields \code{n_nonfinite}, \code{n_total}) at most once per inference
#' object, saying how many replicates were non-finite and that
#' \code{na.rm = TRUE} would drop them. Never changes any returned value.
#' Silent while a resampling operation is active.
#'
#' @keywords internal
#' @noRd
edi_warn_bootstrap_nonfinite_na_once = function(self, private, boot_distr, fn = "compute_bootstrap_two_sided_pval") {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(private$cached_values$bootstrap_nonfinite_na_warned)) return(invisible(FALSE))
	boot_distr = as.numeric(boot_distr)
	k = sum(!is.finite(boot_distr))
	if (k == 0L) return(invisible(FALSE))
	private$cached_values$bootstrap_nonfinite_na_warned = TRUE
	msg = paste0(
		class(self)[1L], ": ", fn, "() returned NA because ", k, " of ", length(boot_distr),
		" bootstrap replicates were non-finite (na.rm = FALSE, the default, returns NA if any replicate is non-finite). ",
		"The bootstrap confidence interval drops non-finite replicates, so it can be finite for the same object; ",
		"na.rm = TRUE would drop them here too (with fewer usable replicates the result is less reliable). ",
		"Suppress with suppressWarnings(expr, classes = \"edi_bootstrap_nonfinite_na_warning\")."
	)
	warning(structure(
		class = c("edi_bootstrap_nonfinite_na_warning", "warning", "condition"),
		list(message = msg, call = NULL, n_nonfinite = k, n_total = length(boot_distr))
	))
	invisible(TRUE)
}

#' Warn once per object and type when a BCa CI is NA on the boundary (TODO-101)
#'
#' Emits one classed warning (\code{edi_bootstrap_bca_boundary_warning}, fields
#' \code{B}, \code{type}, \code{reason}) at most once per inference object and
#' CI type when the BCa adjusted probabilities land on the order-statistic
#' boundary (reason ending in \code{adjustment_on_boundary}) while every
#' bootstrap draw is finite. Never changes any returned value. Silent while a
#' resampling operation is active.
#'
#' @keywords internal
#' @noRd
edi_warn_bca_boundary_once = function(self, private, B, type = "bca", reason, alpha = 0.05) {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (!grepl("adjustment_on_boundary$", as.character(reason)[1L])) return(invisible(FALSE))
	ledger = private$cached_values$bca_boundary_warned
	key = paste0(type, ":", reason)
	if (is.character(ledger) && key %in% ledger) return(invisible(FALSE))
	private$cached_values$bca_boundary_warned = c(if (is.character(ledger)) ledger, key)
	k = round(alpha / 2 * (B + 1), 1)
	msg = paste0(
		class(self)[1L], ": BCa adjustment on the boundary at B = ", B,
		": the nominal tail is only ~", k, " order statistics; increase B (>= 501 recommended) ",
		"or use type = \"percentile\". The returned interval is NA. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_bootstrap_bca_boundary_warning\")."
	)
	warning(structure(
		class = c("edi_bootstrap_bca_boundary_warning", "warning", "condition"),
		list(message = msg, call = NULL, B = B, type = type, reason = as.character(reason)[1L])
	))
	invisible(TRUE)
}

#' Resampling procedure that owns a failure reason (TODO-116)
#'
#' Maps a resampling-failure reason string to the procedure it belongs to
#' (\code{"bootstrap"}, \code{"bayesian_bootstrap"}, \code{"param_bootstrap"},
#' \code{"lik_ratio_bootstrap"}, \code{"rand_bootstrap"},
#' \code{"rand_bootstrap_ci"}). Returns \code{NULL} for reasons that describe
#' a failure of the primary fit itself (unavailable original estimate or
#' original standard error) and for reasons outside the core
#' bootstrap-family procedures.
#'
#' @keywords internal
#' @noRd
edi_resampling_procedure_for_reason = function(reason) {
	reason = as.character(reason)[1L]
	if (is.na(reason)) return(NULL)
	if (grepl("(^|_)(estimate|original_standard_error)_unavailable$", reason)) return(NULL)
	if (grepl("^rand_bootstrap_ci_", reason)) return("rand_bootstrap_ci")
	if (grepl("^rand_ci_", reason)) return("rand_ci")
	if (grepl("^rand_bootstrap_", reason)) return("rand_bootstrap")
	if (grepl("^lik_ratio_bootstrap_", reason)) return("lik_ratio_bootstrap")
	if (grepl("^param_bootstrap_", reason)) return("param_bootstrap")
	if (grepl("^bayesian_bootstrap_", reason)) return("bayesian_bootstrap")
	if (grepl("^bootstrap_", reason)) return("bootstrap")
	if (grepl("^dep_cens_transform_bootstrap_", reason)) return("bootstrap")
	if (grepl("^kk_count_gee_jackknife_", reason)) return("jackknife")
	if (grepl("^jackknife_(too_few_positive_risk_ratio_estimates|log_risk_ratio_(standard_error|null)_unavailable)$", reason)) return("jackknife")
	if (grepl("^subsampling_", reason)) return("subsampling")
	if (grepl("^randomization_", reason)) return("randomization")
	if (grepl("^m_out_of_n_", reason)) return("m_out_of_n")
	NULL
}

#' Record a bootstrap-family procedure failure without wiping the Wald state
#'
#' A failing resampling procedure (bootstrap, Bayesian bootstrap, parametric /
#' LR-calibrated bootstrap, randomization bootstrap and its CI) used to call
#' \code{cache_nonestimable_se()} / \code{cache_nonestimable_estimate()},
#' wiping a perfectly valid Wald estimate/SE and flipping
#' \code{is_nonestimable()}. When the reason belongs to such a procedure AND
#' the primary fit is currently valid (finite cached estimate, SE finite or not
#' yet computed, not already nonestimable) only
#' \code{cached_values$procedure_failure_reason[[procedure]]} is written.
#' Otherwise (primary fit already invalid, or an unrecognised reason) the
#' historical nonestimable behaviour is kept so a real primary failure is
#' never masked.
#'
#' @keywords internal
#' @noRd
edi_record_procedure_failure = function(self, private, reason, stage = c("se", "estimate"), procedure = NULL) {
	stage = match.arg(stage)
	reason = as.character(reason)[1L]
	proc = edi_resampling_procedure_for_reason(reason)
	# Explicit owner for reasons shared across procedures (e.g. the risk-ratio
	# pivot's "resampling_too_few_finite_estimates"); primary-fit reasons
	# (proc == NULL) are never reclassified.
	if (is.null(proc) && !is.null(procedure) && !is.na(reason) &&
		!grepl("(^|_)(estimate|original_standard_error)_unavailable$", reason)) proc = procedure
	cv = private$cached_values
	# Wald estimate not computed yet (e.g. a parametric bootstrap run first on a
	# fresh object): compute it so a procedure failure is not mistaken for a
	# primary failure.
	if (!is.null(proc) && is.null(cv$beta_hat_T)) {
		tryCatch(suppressWarnings(self$compute_estimate()), error = function(e) NULL)
		cv = private$cached_values
	}
	est = suppressWarnings(as.numeric(cv$beta_hat_T))
	se = suppressWarnings(as.numeric(cv$s_beta_hat_T))
	wald_ok = !is.null(proc) && !isTRUE(cv$nonestimable) &&
		length(est) == 1L && is.finite(est) &&
		(length(se) == 0L || (length(se) == 1L && is.finite(se)))
	if (wald_ok) private$cache_procedure_failure(proc, reason)
	else if (identical(stage, "se")) private$cache_nonestimable_se(reason)
	else private$cache_nonestimable_estimate(reason)
	invisible(NULL)
}

#' Forget a stale procedure failure before the procedure re-runs (TODO-116)
#' @keywords internal
#' @noRd
edi_clear_procedure_failure = function(private, procedure) {
	pf = private$cached_values$procedure_failure_reason
	if (is.list(pf) && !is.null(pf[[procedure]])) {
		pf[[procedure]] = NULL
		private$cached_values$procedure_failure_reason = pf
	}
	invisible(NULL)
}

#' Has a procedure already recorded a failure reason? (TODO-116)
#' @keywords internal
#' @noRd
edi_has_procedure_failure = function(private, procedure) {
	pf = private$cached_values$procedure_failure_reason
	is.list(pf) && !is.null(pf[[procedure]])
}
