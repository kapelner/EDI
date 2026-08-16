# Shared Turnbull-NPMLE helpers for left-/interval-censored survival data
# (interval_censored_survival_response.md TODO-8), used by both
# InferenceSurvivalKMDiff (median contrast) and
# InferenceSurvivalRestrictedMeanDiff (restricted-mean contrast).
#
# interval::icfit() has no weights= argument (confirmed by reading its
# signature before writing this dispatch, the same "confirm the input
# contract, don't assume" discipline TODO-6/7 used) -- so unlike the
# right-censored (y, dead) kernels these mirror, there is no weighted
# variant here. That is why compute_estimate_with_bootstrap_weights()
# (Bayesian-bootstrap re-estimation) is blocked outright for both classes
# under general censoring rather than routed through these helpers: an
# icfit() call ignoring weights would silently misuse them.
#
# Turnbull's NPMLE only identifies the survival function S(t) up to the
# probability mass pf[k] on each maximal Turnbull interval
# [intmap[1,k], intmap[2,k]] -- S is undetermined strictly inside a
# non-degenerate interval. Both statistics below make the same modeling
# choice: treat S as stepping down to its post-interval value at each
# interval's LEFT endpoint (the "S_L" / left-continuous convention), which
# mirrors this package's own ordinary-censoring restricted-mean code
# (`times = c(0, fit$time); surv_vals = c(1, fit$surv)`, a left-continuous
# step at each event time). This is a documented modeling decision, not
# the only defensible one -- Turnbull literature also uses S_U (step at the
# right endpoint) or the interval midpoint.

#' @keywords internal
#' @noRd
turnbull_npmle_group_stat = function(y_L, y_R, requested_stat = c("median", "restricted_mean")) {
	requested_stat = match.arg(requested_stat)
	keep = is.finite(y_L) & y_L >= 0 & !is.na(y_R) & y_R > y_L
	if (sum(keep) < 2L) return(NA_real_)
	y_L = y_L[keep]
	y_R = y_R[keep]
	fit = tryCatch(interval::icfit(y_L, y_R), error = function(e) NULL)
	if (is.null(fit) || is.null(fit$intmap) || is.null(fit$pf)) return(NA_real_)
	intmap = fit$intmap
	pf = as.numeric(fit$pf)
	ord = order(intmap[1, ])
	L_k = as.numeric(intmap[1, ord])
	R_k = as.numeric(intmap[2, ord])
	pf = pf[ord]
	# Survival just after each Turnbull interval has "used up" its mass.
	surv_after = 1 - cumsum(pf)
	if (requested_stat == "median") {
		idx = which(surv_after <= 0.5 + sqrt(.Machine$double.eps))
		if (length(idx) == 0L) return(NA_real_)
		k = idx[1L]
		if (!is.finite(R_k[k])) return(NA_real_)
		return(as.numeric((L_k[k] + R_k[k]) / 2))
	}
	finite_R = R_k[is.finite(R_k)]
	if (length(finite_R) == 0L) return(NA_real_)
	tau = max(finite_R)
	times = c(0, L_k)
	surv_vals = c(1, surv_after)
	keep_t = times <= tau
	times = times[keep_t]
	surv_vals = surv_vals[keep_t]
	if (length(times) < 2L) return(NA_real_)
	area = 0
	for (i in seq_len(length(times) - 1L)) {
		area = area + surv_vals[i] * (times[i + 1L] - times[i])
	}
	as.numeric(area)
}

#' @keywords internal
#' @noRd
turnbull_npmle_stat_diff = function(y_L, y_R, w, requested_stat = c("median", "restricted_mean")) {
	requested_stat = match.arg(requested_stat)
	idx_t = w == 1
	idx_c = w == 0
	if (!any(idx_t) || !any(idx_c)) return(NA_real_)
	stat_t = turnbull_npmle_group_stat(y_L[idx_t], y_R[idx_t], requested_stat)
	stat_c = turnbull_npmle_group_stat(y_L[idx_c], y_R[idx_c], requested_stat)
	if (!is.finite(stat_t) || !is.finite(stat_c)) return(NA_real_)
	as.numeric(stat_t - stat_c)
}
