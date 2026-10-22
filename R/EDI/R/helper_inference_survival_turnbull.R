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
# Exact events (y finite, y_L/y_R NA in the design's storage) are folded in as
# degenerate intervals [y, y] by turnbull_effective_interval(); passing only
# y_L/y_R silently discards them (TODO-109). Right-censored subjects are
# [y_L, Inf).
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

#' Fold exact events into the (y_L, y_R) interval representation as [y, y].
#' @keywords internal
#' @noRd
turnbull_effective_interval = function(y_L, y_R, y = NULL) {
	if (is.null(y)) return(list(y_L = as.numeric(y_L), y_R = as.numeric(y_R)))
	y = as.numeric(y)
	exact = is.finite(y)
	list(
		y_L = ifelse(exact, y, as.numeric(y_L)),
		y_R = ifelse(exact, y, as.numeric(y_R))
	)
}

# Follow-up horizon of one arm: the largest finite observed time (exact
# time, finite right endpoint, or right-censoring time).
#' @keywords internal
#' @noRd
turnbull_arm_horizon = function(y_L, y_R) {
	v = c(y_L[is.finite(y_L)], y_R[is.finite(y_R)])
	if (length(v) == 0L) return(NA_real_)
	max(v)
}

#' @keywords internal
#' @noRd
turnbull_npmle_group_stat = function(y_L, y_R, requested_stat = c("median", "restricted_mean"), tau = NULL) {
	requested_stat = match.arg(requested_stat)
	# y_R == y_L is an exact event (degenerate interval); y_R = Inf is
	# right-censored. Rows that cannot be used are excluded with a warning.
	usable = is.finite(y_L) & y_L >= 0 & !is.na(y_R) & y_R >= y_L
	n_bad = sum(!usable)
	if (n_bad > 0L) {
		warning("Turnbull NPMLE: excluded ", n_bad, " row(s) with a missing/invalid (y_L, y_R) interval.", call. = FALSE)
	}
	keep = usable
	if (sum(keep) < 2L) return(NA_real_)
	y_L = y_L[keep]
	y_R = y_R[keep]
	if (is.null(tau)) tau = turnbull_arm_horizon(y_L, y_R)
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
	if (!is.finite(tau)) return(NA_real_)
	times = c(0, L_k)
	surv_vals = c(1, surv_after)
	keep_t = times < tau
	times = times[keep_t]
	surv_vals = surv_vals[keep_t]
	if (length(times) < 1L) return(NA_real_)
	# Integrate the step function all the way to tau (not just to the last
	# left endpoint <= tau).
	times = c(times, tau)
	area = 0
	for (i in seq_len(length(times) - 1L)) {
		area = area + surv_vals[i] * (times[i + 1L] - times[i])
	}
	as.numeric(area)
}

#' @param y optional exact responses (NA for censored); exact events are
#'   folded in as [y, y]. @param tau optional shared horizon; default is the
#'   smaller of the two arms' maximum follow-up times.
#' @keywords internal
#' @noRd
turnbull_npmle_stat_diff = function(y_L, y_R, w, requested_stat = c("median", "restricted_mean"), y = NULL, tau = NULL) {
	requested_stat = match.arg(requested_stat)
	iv = turnbull_effective_interval(y_L, y_R, y)
	y_L = iv$y_L
	y_R = iv$y_R
	idx_t = w == 1
	idx_c = w == 0
	if (!any(idx_t) || !any(idx_c)) return(NA_real_)
	if (requested_stat == "restricted_mean" && is.null(tau)) {
		# One horizon shared by both arms (TODO-23 convention).
		tau = min(turnbull_arm_horizon(y_L[idx_t], y_R[idx_t]), turnbull_arm_horizon(y_L[idx_c], y_R[idx_c]))
	}
	stat_t = turnbull_npmle_group_stat(y_L[idx_t], y_R[idx_t], requested_stat, tau)
	stat_c = turnbull_npmle_group_stat(y_L[idx_c], y_R[idx_c], requested_stat, tau)
	if (!is.finite(stat_t) || !is.finite(stat_c)) return(NA_real_)
	as.numeric(stat_t - stat_c)
}
