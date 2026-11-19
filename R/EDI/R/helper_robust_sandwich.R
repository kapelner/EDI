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
	# Not estimable when the variance is at the floating-point noise floor of the fit (a perfect fit, whose
	# residuals are rounding error). The floor is relative to the scale of y and the fitted values, so the
	# variance stays equivariant under rescaling y (v1.0.6-TODO-58: the old absolute .Machine$double.eps
	# floor called y * 1e-8 not estimable). Rounding error in each residual is about eps * max|y|, and the
	# CR2 sandwich of residuals bounded by r has variance at most about n * r^2 * (X'X)^{-1}_jj.
	fit_scale = max(abs(y), abs(y - e))
	noise_ssq = n * (100 * .Machine$double.eps * fit_scale)^2 * abs(XtX_inv[j, j])
	if (!is.finite(ssq) || ssq <= noise_ssq || ssq <= 0) return(NULL)
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
	# Suggest only the procedures this class supports (v1.0.6-TODO-125: RMST, LogRank etc.
	# refuse compute_rand_confidence_interval()).
	has = function(cap) isTRUE(tryCatch(self$supports(cap)[[1L]], error = function(e) FALSE))
	alternatives = c(
		if (has("randomization_test") && has("randomization_ci")) "compute_rand_two_sided_pval() / compute_rand_confidence_interval()"
		else if (has("randomization_test")) "compute_rand_two_sided_pval()",
		if (has("nonparametric_bootstrap")) paste0("compute_bootstrap_two_sided_pval() / ",
			"compute_bootstrap_confidence_interval() (these resample whole clusters)"),
		if (has("jackknife")) paste0("compute_jackknife_wald_two_sided_pval() / ",
			"compute_jackknife_wald_confidence_interval() with unit = \"cluster\"")
	)
	alt_text = if (length(alternatives) == 0L) "" else paste0("Cluster-aware alternatives: ",
		if (length(alternatives) == 1L) alternatives else paste0(
			paste(alternatives[-length(alternatives)], collapse = ", "), ", or ", alternatives[length(alternatives)]), ". ")
	msg = paste0(
		class(self)[1L], " on a cluster design: the ", what, " treat subjects as independent, ",
		"ignoring within-cluster correlation, so they may be too narrow (p-values too small). ",
		alt_text,
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

#' TODO-177 (2026-11-07): TRUE when a null-refit warm start can be reused:
#' a non-empty numeric vector with every element finite. An empty vector
#' (\code{as.numeric(NULL$b)} from a failed refit) or a NaN / Inf start is
#' never stored and never passed on.
#'
#' @keywords internal
#' @noRd
edi_warm_start_usable = function(start) {
	is.numeric(start) && length(start) > 0L && all(is.finite(start))
}

#' TODO-177 (2026-11-07): TRUE when a null refit may seed the next warm
#' start: non-NULL and not reporting \code{converged = FALSE}.
#'
#' @keywords internal
#' @noRd
edi_null_refit_usable = function(fit) {
	if (is.null(fit)) return(FALSE)
	conv = tryCatch(fit[["converged"]], error = function(e) NULL)
	!isFALSE(conv)
}

#' TODO-177 (2026-11-07): one null-restricted refit for the warm-start
#' wrappers (\code{make_warm_fit_null_wrapper}). An unusable start (see
#' \code{edi_warm_start_usable}) is dropped. If a warm-started refit fails
#' (error, NULL or \code{converged = FALSE}) it is retried once with
#' \code{start = NULL}, which is what a fresh object does, so a failed or
#' stale warm start cannot make \code{p(delta)} depend on the call history.
#' When the first attempt succeeds the result is exactly the old one-attempt
#' result. An error is recorded only when the final attempt has no fit.
#'
#' @keywords internal
#' @noRd
edi_fit_null_with_warm_retry = function(private, spec, cache_key, delta, start, accepts_start) {
	attempt = function(st) {
		err = NULL
		fit = tryCatch(
			if (accepts_start) spec$fit_null(delta, start = st) else spec$fit_null(delta),
			error = function(e) { err <<- e; NULL }
		)
		list(fit = fit, err = err)
	}
	if (!isTRUE(accepts_start) || !edi_warm_start_usable(start)) start = NULL
	res = attempt(start)
	first_err = res$err
	if (!is.null(start) && !edi_null_refit_usable(res$fit)) {
		res = attempt(NULL)
	}
	if (is.null(res$fit)) {
		err = res$err %||% first_err
		if (!is.null(err)) edi_note_lik_test_failure(private, edi_lik_test_type_from_cache_key(cache_key), err)
	}
	res$fit
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

#' Warn once per object and type when a BCa CI or p-value is NA on the boundary (TODO-101)
#'
#' Emits one classed warning (\code{edi_bootstrap_bca_boundary_warning}, fields
#' \code{B}, \code{type}, \code{reason}, \code{what} = \code{"interval"} or
#' \code{"p-value"}) at most once per inference object, type and \code{what}
#' when the BCa adjusted probabilities land on the order-statistic boundary (reason ending in \code{adjustment_on_boundary}) while every
#' bootstrap draw is finite. Never changes any returned value. Silent while a
#' resampling operation is active.
#'
#' @keywords internal
#' @noRd
edi_warn_bca_boundary_once = function(self, private, B, type = "bca", reason, alpha = 0.05, what = "interval") {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (grepl("unstable_bias_or_acceleration$", as.character(reason)[1L])) {
		return(edi_warn_bca_unstable_once(self, private, B, type, reason, what))
	}
	if (!grepl("adjustment_on_boundary$", as.character(reason)[1L])) return(invisible(FALSE))
	ledger = private$cached_values$bca_boundary_warned
	# The CI and the p-value each warn once (v1.0.6-TODO-114); the CI keeps its original key.
	key = paste0(type, if (!identical(what, "interval")) paste0("/", what), ":", reason)
	if (is.character(ledger) && key %in% ledger) return(invisible(FALSE))
	private$cached_values$bca_boundary_warned = c(if (is.character(ledger)) ledger, key)
	# v1.0.6-TODO-92: "increase B" is advice only when B is below the recommended 501. At
	# B >= 501 the boundary comes from the data (an extreme bias correction or acceleration),
	# not from too few order statistics, so recommending the B just used is wrong.
	advice = if (B < 501) {
		k = round(alpha / 2 * (B + 1), 1)
		paste0(": the nominal tail is only ~", k, " order statistics; increase B (>= 501 recommended) ",
			"or use type = \"percentile\". ")
	} else {
		paste0(": the bias correction and acceleration estimated from these data push the adjusted tail ",
			"onto the most extreme bootstrap draws, so a larger B will not fix it; use type = \"percentile\". ")
	}
	msg = paste0(
		class(self)[1L], ": BCa adjustment on the boundary at B = ", B, advice,
		"The returned ", what, " is NA. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_bootstrap_bca_boundary_warning\")."
	)
	warning(structure(
		class = c("edi_bootstrap_bca_boundary_warning", "warning", "condition"),
		list(message = msg, call = NULL, B = B, type = type, reason = as.character(reason)[1L], what = what)
	))
	invisible(TRUE)
}

#' Warn once per object when a BCa CI or p-value is NA because the bias correction or
#' acceleration is unstable (v1.0.6-TODO-116)
#'
#' \code{bca_ci_core()} / \code{bca_pval_core()} return NA with a reason ending in
#' \code{unstable_bias_or_acceleration} when \eqn{|z_0| > 2.5}, \eqn{|a| > 1}, either is
#' not finite, or the BCa denominator \eqn{1 - a(z_0 + z)} is (near) zero. Emits one
#' \code{edi_bootstrap_bca_unstable_warning} (fields \code{B}, \code{type}, \code{reason},
#' \code{what} = \code{"interval"} or \code{"p-value"}) per object, type and \code{what}.
#' Called through \code{edi_warn_bca_boundary_once()}, so it shares its "silent while a
#' resampling operation is active" guard. Never changes any returned value.
#'
#' @keywords internal
#' @noRd
edi_warn_bca_unstable_once = function(self, private, B, type = "bca", reason, what = "interval") {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	ledger = private$cached_values$bca_boundary_warned
	key = paste0(type, "/", what, ":", reason)
	if (is.character(ledger) && key %in% ledger) return(invisible(FALSE))
	private$cached_values$bca_boundary_warned = c(if (is.character(ledger)) ledger, key)
	msg = paste0(
		class(self)[1L], ": BCa bias correction or acceleration is unstable at B = ", B,
		" (the estimate lies in the far tail of the bootstrap draws, or the jackknife acceleration ",
		"is extreme), so the BCa adjustment is undefined; use type = \"percentile\". ",
		"The returned ", what, " is NA. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_bootstrap_bca_unstable_warning\")."
	)
	warning(structure(
		class = c("edi_bootstrap_bca_unstable_warning", "warning", "condition"),
		list(message = msg, call = NULL, B = B, type = type, reason = as.character(reason)[1L], what = what)
	))
	invisible(TRUE)
}

#' Number of subjects whose fitted constrained-binomial MLE sits on the
#' parameter-space boundary (TODO-128 / TODO-179, v1.0.5)
#'
#' Log link: \eqn{\eta = X\beta \ge -(10^{-8} + margin)} (fitted probability
#' \eqn{\exp(\eta) = 1}); identity link: \eqn{\mu \ge 1 - (10^{-8} + margin)}
#' or \eqn{\mu \le 10^{-8} + margin}. The fitting kernels stop \code{1e-8}
#' short of the bound. Returns \code{NA_integer_} when the linear predictor
#' cannot be formed.
#'
#' @keywords internal
#' @noRd
edi_binomial_mle_n_on_boundary = function(X_fit, b, link = c("log", "identity"), margin = 1e-6) {
	link = match.arg(link)
	if (is.null(X_fit) || is.null(b)) return(NA_integer_)
	eta = tryCatch(as.numeric(as.matrix(X_fit) %*% as.numeric(b)), error = function(e) NULL)
	if (!length(eta) || anyNA(eta)) return(NA_integer_)
	edge = 1e-8 + margin
	as.integer(if (link == "log") sum(eta >= -edge) else sum(eta >= 1 - edge) + sum(eta <= edge))
}

#' Warn once per object when a constrained-binomial MLE sits on the
#' parameter-space boundary (TODO-128, v1.0.5)
#'
#' Called right after the full-data fit of \code{InferenceIncidLogBinomial}
#' (log link: \eqn{\exp(X\beta) \le 1}, bound at \eqn{\eta = 0}) and
#' \code{InferenceIncidBinomialIdentityRiskDiff} (identity link: bounds at
#' \eqn{\mu = 0} and \eqn{\mu = 1}). If any fitted linear predictor lies
#' within \code{margin} of a bound (the fitting kernels stop \code{1e-8}
#' short of it), the MLE is on the boundary, so the Wald and score standard
#' errors and intervals, which assume an interior maximum, may be
#' unreliable. Emits one classed warning
#' \code{edi_binomial_mle_boundary_warning} (fields \code{link},
#' \code{n_on_boundary}) at most once per inference object. Never changes any
#' returned value. Silent while a resampling operation is active.
#'
#' @keywords internal
#' @noRd
edi_warn_binomial_mle_boundary_once = function(self, private, X_fit, b, link = c("log", "identity"), margin = 1e-6) {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(private$cached_values$binomial_mle_boundary_warned)) return(invisible(FALSE))
	link = match.arg(link)
	n_on_boundary = edi_binomial_mle_n_on_boundary(X_fit, b, link, margin)
	if (is.na(n_on_boundary) || n_on_boundary == 0L) return(invisible(FALSE))
	private$cached_values$binomial_mle_boundary_warned = TRUE
	bound_txt = if (link == "log") "fitted probability exp(X b) = 1" else "fitted probability 0 or 1"
	# v1.0.5 TODO-179 (owner decision 2026-11-09): the log-link class returns NA
	# for its Wald p-value and interval at a boundary MLE (see
	# edi_log_binomial_wald_unavailable_at_boundary()).
	wald_txt = if (link == "log") {
		"The Wald p-value and confidence interval are NA here (the inverse information is too small at the boundary); score standard errors, p-values and confidence intervals assume an interior maximum and may be unreliable. "
	} else {
		"Wald and score standard errors, p-values and confidence intervals assume an interior maximum and may be unreliable. "
	}
	msg = paste0(
		class(self)[1L], ": the maximum-likelihood estimate is on the boundary of the parameter space (",
		n_on_boundary, " subject(s) at ", bound_txt, "). ", wald_txt,
		"Consider bootstrap ",
		"(compute_bootstrap_confidence_interval()) or likelihood-ratio (set_testing_type(\"lik_ratio\")) intervals. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_binomial_mle_boundary_warning\")."
	)
	warning(structure(
		class = c("edi_binomial_mle_boundary_warning", "warning", "condition"),
		list(message = msg, call = NULL, link = link, n_on_boundary = n_on_boundary)
	))
	invisible(TRUE)
}

#' Number of subjects whose fitted logistic probability is numerically 0 or 1
#' (v1.0.6-TODO-109)
#'
#' Counts rows of \code{X_fit} with fitted probability
#' \eqn{\mathrm{plogis}(X\beta)} below \code{eps} or above \code{1 - eps},
#' i.e. \eqn{|X\beta| \ge \mathrm{qlogis}(1 - eps)} (about 18.4 at the default
#' \code{eps = 1e-8}). Under (quasi-)complete separation the maximum
#' likelihood estimate does not exist and the fitter stops with some fitted
#' probabilities on the edge. \code{glm()}'s check uses \code{eps = 10 *
#' .Machine$double.eps}, but the EDI fitters stop earlier (a fit separated on
#' treatment alone ends near \eqn{|X\beta| \approx 23}), so a looser edge is
#' used. Returns \code{NA_integer_} when the linear predictor cannot be formed.
#' \code{link = "probit"} (v1.0.6-TODO-119) uses \eqn{\Phi(X\beta)} instead,
#' i.e. \eqn{|X\beta| \ge \Phi^{-1}(1 - eps)} (about 5.6 at the default; a
#' probit fit separated on treatment alone ends near \eqn{|X\beta| \approx 7}).
#'
#' @keywords internal
#' @noRd
edi_logistic_n_fitted_extreme = function(X_fit, b, eps = 1e-8, link = c("logit", "probit")) {
	link = match.arg(link)
	if (is.null(X_fit) || is.null(b)) return(NA_integer_)
	eta = tryCatch(as.numeric(as.matrix(X_fit) %*% as.numeric(b)), error = function(e) NULL)
	if (!length(eta) || anyNA(eta)) return(NA_integer_)
	edge = if (link == "probit") stats::qnorm(1 - eps) else stats::qlogis(1 - eps)
	as.integer(sum(abs(eta) >= edge))
}

#' Warn once per object when a logistic fit shows (quasi-)complete separation
#' (v1.0.6-TODO-109)
#'
#' Called right after a full-data logistic fit is accepted. If any fitted
#' probability is numerically 0 or 1 (see
#' \code{edi_logistic_n_fitted_extreme()}), the data are (quasi-)completely
#' separated: the MLE does not exist, the reported coefficient is wherever the
#' fitter stopped, and Wald standard errors, p-values and intervals are not
#' meaningful. This is the condition \code{glm()} reports as "fitted
#' probabilities numerically 0 or 1 occurred". Emits one classed warning
#' \code{edi_logistic_separation_warning} (fields \code{n_extreme},
#' \code{n}) at most once per inference object. Never changes any returned
#' value. Silent while a resampling operation is active, so resampling inner
#' loops never repeat it. \code{advice}, when given, replaces the default
#' "Consider ..." sentence (v1.0.6-TODO-118: the KK GEE classes, which have no
#' likelihood-ratio test and return NA Wald results under separation).
#' \code{link = "probit"} (v1.0.6-TODO-119, \code{InferenceIncidProbitRegr})
#' checks \eqn{\Phi(X\beta)} instead; the warning keeps the class
#' \code{edi_logistic_separation_warning} for every binary link (one class to
#' catch or suppress) and carries the link in its \code{link} field.
#'
#' @keywords internal
#' @noRd
edi_warn_logistic_separation_once = function(self, private, X_fit, b, eps = 1e-8, advice = NULL, link = c("logit", "probit")) {
	link = match.arg(link)
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(private$cached_values$logistic_separation_warned)) return(invisible(FALSE))
	n_extreme = edi_logistic_n_fitted_extreme(X_fit, b, eps, link = link)
	if (is.na(n_extreme) || n_extreme == 0L) return(invisible(FALSE))
	private$cached_values$logistic_separation_warned = TRUE
	n = nrow(as.matrix(X_fit))
	msg = paste0(
		class(self)[1L], ": fitted probabilities numerically 0 or 1 occurred (", n_extreme, " of ", n,
		" subject(s)); the data look (quasi-)completely separated, so the maximum-likelihood estimate does not exist ",
		"and the reported estimate is where the fitter stopped. Wald standard errors, p-values and confidence ",
		"intervals are not meaningful here. ",
		if (length(advice) && nzchar(advice[1L])) paste0(advice[1L], " ") else paste0(
			"Consider a likelihood-ratio test (set_testing_type(\"lik_ratio\")), ",
			"a randomization test (compute_rand_two_sided_pval()), an exact incidence method, or fewer covariates. "
		),
		"Suppress with suppressWarnings(expr, classes = \"edi_logistic_separation_warning\")."
	)
	warning(structure(
		class = c("edi_logistic_separation_warning", "warning", "condition"),
		list(message = msg, call = NULL, n_extreme = n_extreme, n = n, link = link)
	))
	invisible(TRUE)
}

#' Warn once per object when the hardened refit drops a covariate
#' (v1.0.6-TODO-138)
#'
#' The hardened fitting paths (\code{fit_with_hardened_qr_column_dropping()}
#' and the g-computation drop loops) first drop columns that are linearly
#' dependent (QR rank) and then, if the fit on the remaining full-rank design
#' is still unusable, drop further covariates one at a time and refit. Only
#' that second kind of drop changes the model the user asked for, so only it
#' warns: \code{dropped} are the covariate columns removed beyond the QR rank
#' set. Plain collinearity drops do not warn (they are routine with factor
#' dummies or a strata column already in the design, and the dropped column
#' carries no information the kept ones lack).
#'
#' \code{reason} is \code{"coefficient_diverged"} (some coefficient of the
#' full-rank fit was non-finite or beyond \code{max_abs_reasonable_coef}, as
#' under (quasi-)complete separation; \code{diverged} names those columns,
#' which need not be the dropped ones: the loop drops covariates from the end
#' of the QR pivot until the fit is usable),
#' \code{"full_fit_unusable"} (the full-rank fit failed or was rejected by the
#' class's fit checks for another reason, e.g. no usable standard error), or
#' \code{"treatment_only_fallback"} (every covariate was dropped after the
#' covariate-adjusted fit failed). Emits one classed warning
#' \code{edi_covariate_dropped_warning} (fields \code{dropped}, \code{reason},
#' \code{diverged}) at most once per inference object, never inside a
#' resampling operation, and never changes any returned value.
#'
#' @keywords internal
#' @noRd
edi_warn_covariate_dropped_once = function(self, private, dropped, reason = c("coefficient_diverged", "full_fit_unusable", "treatment_only_fallback"), diverged = character()) {
	reason = match.arg(reason)
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(private$cached_values$covariate_dropped_warned)) return(invisible(FALSE))
	dropped = setdiff(as.character(dropped), c("(Intercept)", "treatment", ""))
	if (!length(dropped)) return(invisible(FALSE))
	diverged = as.character(diverged)
	private$cached_values$covariate_dropped_warned = TRUE
	cap = suppressWarnings(as.numeric(private$max_abs_reasonable_coef))
	cap_txt = if (length(cap) == 1L && is.finite(cap)) paste0(" (max_abs_reasonable_coef = ", format(cap), ")") else ""
	why = switch(reason,
		coefficient_diverged = paste0(
			"the fit with all covariates had non-finite or implausibly large coefficients", cap_txt,
			if (length(diverged)) paste0(" for ", paste(diverged, collapse = ", ")) else "",
			", which usually means (quasi-)complete separation"
		),
		full_fit_unusable = "the fit with all covariates failed or did not pass the fit checks (e.g. no convergence or no usable standard error)",
		treatment_only_fallback = "the covariate-adjusted fit failed, so the treatment-only model was fit instead"
	)
	msg = paste0(
		class(self)[1L], ": dropped covariate(s) ", paste(dropped, collapse = ", "),
		" and refit because ", why, ". The reported results are for the reduced model. ",
		"Suppress with suppressWarnings(expr, classes = \"edi_covariate_dropped_warning\")."
	)
	warning(structure(
		class = c("edi_covariate_dropped_warning", "warning", "condition"),
		list(message = msg, call = NULL, dropped = dropped, reason = reason, diverged = diverged)
	))
	invisible(TRUE)
}

#' Covariate-drop warning for the g-computation drop loops (v1.0.6-TODO-138)
#'
#' \code{fit} is the accepted fit from a g-computation
#' \code{fit_*_with_sandwich()} loop, which records the QR-rank column names
#' and coefficients of its first fit (\code{qr_rank_colnames},
#' \code{qr_rank_coefficients}). Covariates in that rank set but not in
#' \code{colnames(fit$X)} were dropped by the loop; with
#' \code{treatment_only_fallback = TRUE} every covariate of \code{X_full} was.
#' Calls \code{edi_warn_covariate_dropped_once()}.
#'
#' @keywords internal
#' @noRd
edi_warn_gcomp_covariate_drop = function(self, private, X_full, fit, treatment_only_fallback = FALSE) {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	if (isTRUE(private$cached_values$covariate_dropped_warned)) return(invisible(FALSE))
	if (is.null(fit) || is.null(fit$X)) return(invisible(FALSE))
	if (isTRUE(treatment_only_fallback)) {
		return(edi_warn_covariate_dropped_once(self, private, setdiff(colnames(X_full), colnames(fit$X)), "treatment_only_fallback"))
	}
	rank_cols = fit$qr_rank_colnames
	if (is.null(rank_cols)) return(invisible(FALSE))
	dropped = setdiff(rank_cols, colnames(fit$X))
	if (!length(dropped)) return(invisible(FALSE))
	cls = edi_classify_hardened_drop(list(b = fit$qr_rank_coefficients), rank_cols, private$max_abs_reasonable_coef)
	edi_warn_covariate_dropped_once(self, private, dropped, cls$reason, cls$diverged)
}

#' Reason and diverged columns for a hardened drop (v1.0.6-TODO-138)
#'
#' Reads the coefficients of the rejected full-rank fit (\code{b},
#' \code{coefficients}, \code{beta} or \code{coef}) and reports
#' \code{"coefficient_diverged"} with the offending column names when any is
#' non-finite or beyond \code{max_abs} (when \code{max_abs} is a finite
#' number), else \code{"full_fit_unusable"}.
#'
#' @keywords internal
#' @noRd
edi_classify_hardened_drop = function(fit, col_names, max_abs = NULL) {
	coefs = NULL
	if (is.list(fit)) {
		for (nm in c("b", "coefficients", "beta", "coef")) {
			v = tryCatch(fit[[nm]], error = function(e) NULL)
			if (is.numeric(v) && length(v)) { coefs = as.numeric(v); break }
		}
	}
	if (is.null(coefs)) return(list(reason = "full_fit_unusable", diverged = character()))
	cap = suppressWarnings(as.numeric(max_abs))
	has_cap = length(cap) == 1L && is.finite(cap)
	bad = !is.finite(coefs) | (if (has_cap) abs(coefs) > cap else FALSE)
	if (!any(bad)) return(list(reason = "full_fit_unusable", diverged = character()))
	nms = if (length(col_names) == length(coefs)) as.character(col_names)[bad] else character()
	list(reason = "coefficient_diverged", diverged = nms)
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
	# Likelihood tests (2026-10-22, TODO-116 lik-test stage): a failed score /
	# gradient / LR / Bartlett test or test-inversion CI is a failure of that
	# test, owned by the procedure named after the testing type. "wald_*"
	# reasons are deliberately not mapped (a failed Wald test is the primary
	# fit failing). Shared reasons ("test_inversion_confidence_interval_
	# unavailable", "*likelihood_test_spec_unavailable") carry no testing type
	# and are routed with an explicit `procedure = edi_lik_test_procedure(.)`.
	lik = regmatches(reason, regexec("^(lik_ratio_bartlett_approx|lik_ratio_bartlett_exact|score|gradient|lik_ratio)_(test_unavailable|confidence_interval_unavailable|ci_inversion_failed)$", reason))[[1L]]
	if (length(lik) == 3L) return(lik[2L])
	if (grepl("^dep_cens_transform_score_", reason)) return("score")
	if (grepl("^dep_cens_transform_lik_ratio_", reason)) return("lik_ratio")
	NULL
}

#' Procedure name for a likelihood testing type (TODO-116)
#'
#' Returns \code{testing_type} when it names a likelihood test (score,
#' gradient, lik_ratio, or a Bartlett-corrected LR) and \code{NULL} otherwise
#' (Wald, unknown, NULL), so a Wald failure is never reclassified away from the
#' primary fit.
#'
#' @keywords internal
#' @noRd
edi_lik_test_procedure = function(testing_type) {
	tt = as.character(testing_type %||% NA_character_)[1L]
	if (!is.na(tt) && tt %in% c("score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact")) tt else NULL
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

#' Warn that a public method is returning NA for a recorded reason
#' (v1.0.6-TODO-113, the v1.0.6-TODO-95 rule)
#'
#' Call it right where a public method records a reason
#' (\code{cache_procedure_failure()} / \code{edi_record_procedure_failure()})
#' and hands the caller \code{NA}, so the user sees why instead of a silent
#' \code{NA}. Emits one warning of class \code{warning_class} (default
#' \code{edi_procedure_na_warning}) with fields \code{procedure} and
#' \code{reason}. Never changes any returned value or recorded state. Silent
#' while a resampling operation is active
#' (\code{private$active_resampling_operation}), so replicate fits in
#' bootstrap, jackknife or randomization inner loops never repeat it.
#'
#' @keywords internal
#' @noRd
edi_warn_procedure_na = function(self, private, procedure, reason, detail = NULL, warning_class = "edi_procedure_na_warning") {
	if (!is.null(private$active_resampling_operation)) return(invisible(FALSE))
	reason = as.character(reason)[1L]
	cls = unique(c(warning_class, "edi_procedure_na_warning"))
	msg = paste0(
		class(self)[1L], ": ", procedure, " returned NA (reason: ", reason, ").",
		if (length(detail) && nzchar(detail)) paste0(" ", detail) else "",
		" Suppress with suppressWarnings(expr, classes = \"", cls[1L], "\")."
	)
	warning(structure(
		class = c(cls, "warning", "condition"),
		list(message = msg, call = NULL, procedure = procedure, reason = reason)
	))
	invisible(TRUE)
}

#' Has a procedure already recorded a failure reason? (TODO-116)
#' @keywords internal
#' @noRd
edi_has_procedure_failure = function(private, procedure) {
	pf = private$cached_values$procedure_failure_reason
	is.list(pf) && !is.null(pf[[procedure]])
}
