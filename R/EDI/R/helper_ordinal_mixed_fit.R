# Internal weighted cumulative-link mixed-model refit shared by the ordinal
# KKGLMM and KKCLMM Bayesian-bootstrap paths.  The native ordinal kernels do
# not yet accept row weights; ordinal::clmm provides the matching conditional
# random-intercept estimand and supports all four links used by the CLMM family.
weighted_ordinal_random_intercept_fit = function(y, predictors_df, group_id,
		row_weights, link = "logit", nAGQ = 20L, estimate_only = TRUE){
	if (!check_package_installed("ordinal")) {
		return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	}
	predictors_df = as.data.frame(predictors_df)
	ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(y))
	if (!any(ok)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	levels_y = sort(unique(y[ok]))
	if (length(levels_y) < 2L || !("w" %in% colnames(predictors_df))) {
		return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	}
	dat = data.frame(
		y = ordered(y[ok], levels = levels_y),
		predictors_df[ok, , drop = FALSE],
		group_id = factor(group_id[ok]),
		.bootstrap_weight__ = as.numeric(row_weights[ok])
	)
	fixed_terms = setdiff(colnames(dat), c("y", "group_id", ".bootstrap_weight__"))
	form = stats::as.formula(paste(
		"y ~", paste(c(fixed_terms, "(1 | group_id)"), collapse = " + ")
	))
	fit_clmm = function(start = NULL){
		tryCatch({
			args = list(
				formula = form,
				data = dat,
				weights = dat$.bootstrap_weight__,
				link = link,
				nAGQ = as.integer(nAGQ),
				Hess = !estimate_only
			)
			if (!is.null(start)) args$start = start
			utils::capture.output(fit <- suppressMessages(suppressWarnings(
				do.call(ordinal::clmm, args)
			)))
			fit
		}, error = function(e) NULL)
	}
	mod = fit_clmm()
	if (is.null(mod)) {
		fixed_form = stats::as.formula(paste("y ~", paste(fixed_terms, collapse = " + ")))
		fixed_fit = tryCatch({
			utils::capture.output(fit <- suppressMessages(suppressWarnings(
				ordinal::clm(
					fixed_form, data = dat, weights = .bootstrap_weight__,
					link = link, Hess = FALSE
				)
			)))
			fit
		}, error = function(e) NULL)
		if (!is.null(fixed_fit)) {
			candidates = lapply(c(-5, -3, -1, 0, 1), function(log_sigma){
				fit_clmm(c(stats::coef(fixed_fit), log_sigma))
			})
			candidates = Filter(Negate(is.null), candidates)
			if (length(candidates) > 0L) {
				loglik = vapply(candidates, function(fit){
					as.numeric(tryCatch(stats::logLik(fit), error = function(e) NA_real_))
				}, numeric(1L))
				if (any(is.finite(loglik))) mod = candidates[[which.max(loglik)]]
			}
		}
	}
	if (is.null(mod)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	beta = suppressWarnings(as.numeric(stats::coef(mod)["w"]))
	if (!is.finite(beta)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	variance = if (estimate_only) NA_real_ else tryCatch({
		v = stats::vcov(mod)["w", "w"]
		if (is.finite(v) && v > 0) as.numeric(v) else NA_real_
	}, error = function(e) NA_real_)
	list(beta = beta, se = sqrt(variance), variance = variance)
}
