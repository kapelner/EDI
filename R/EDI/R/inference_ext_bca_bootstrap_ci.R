#' Mixin for BCa (Bias-Corrected and Accelerated) Bootstrap Confidence Intervals and P-values
#'
#' A Pattern-1 mixin (plain list with \code{$public} and \code{$private} slots)
#' providing the generic Efron BCa correction math shared by
#' \code{InferenceNonParamBootstrap}'s plain-bootstrap \code{ci_bca()}/\code{pval_bca()}
#' and \code{InferenceBayesianBootstrap}'s \code{ci_bayesian_bca()}/\code{pval_bayesian_bca()}.
#' The two call sites differ only in where the jackknife replicate distribution comes
#' from and how a "can't compute this" failure is reported back to the caller; both
#' differences are captured by the \code{jack}/\code{reason_prefix}/\code{on_failure}
#' arguments below, so the bias-correction (z0) / acceleration (a) / adjusted-quantile
#' math itself lives in exactly one place.
#'
#' Pattern-1 file-split extension, spliced into exactly one class
#' (\code{InferenceNonParamBootstrap}) via
#' \code{private = c(InferenceExtBcaBootstrapCI$private, list(...))} -- not a
#' reusable mixin. \code{InferenceBayesianBootstrap} does not need to splice
#' this in separately -- it inherits \code{InferenceNonParamBootstrap} (via
#' \code{InferenceRandBootstrap} / \code{InferenceRandBootstrapCI}), so
#' \code{private$bca_ci_core()} / \code{private$bca_pval_core()} are already
#' visible there through ordinary R6 private-environment inheritance.
#'
#' @keywords internal
#' @noRd
InferenceExtBcaBootstrapCI = list(
	public = list(),
	private = list(
		# Shared BCa confidence-interval math (Efron 1987; Efron & Tibshirani 1993).
		# `jack` must already be the finite jackknife replicate distribution (length >= 2);
		# callers are responsible for sourcing it (plain vs. Bayesian jackknife) and for
		# handling the "too few jackknife replicates" case themselves, since that failure
		# is reported differently at each call site.
		# `on_failure(reason)` is called with a bare reason suffix (e.g.
		# "unstable_bias_or_acceleration") -- the caller supplies `reason_prefix` so the
		# cached nonestimable-reason string matches its own family's existing vocabulary
		# ("bootstrap_bca_..." vs "bayesian_bootstrap_bca_...").
		# Mid-rank bootstrap CDF at x: ties count half. With a discrete bootstrap
		# distribution (medians, quantiles, counts) many replicates equal est exactly, and
		# the strict mean(boot < est) biases z0 negative (Efron & Tibshirani 1993, 14.3).
		bca_midrank_cdf = function(boot_distr, x){
			p = mean(boot_distr < x) + 0.5 * mean(boot_distr == x)
			pmin(1 - .Machine$double.eps, pmax(.Machine$double.eps, p))
		},
		bca_ci_core = function(boot_distr, alpha, est, jack, reason_prefix, on_failure){
			z0 = stats::qnorm(private$bca_midrank_cdf(boot_distr, est))
			jack_bar = mean(jack)
			num = sum((jack_bar - jack)^3)
			den = 6 * (sum((jack_bar - jack)^2)^(3/2))
			a = if (is.finite(den) && den > 0) num / den else 0
			if (!is.finite(z0) || !is.finite(a) || abs(z0) > 2.5 || abs(a) > 1) {
				return(on_failure(paste0(reason_prefix, "unstable_bias_or_acceleration")))
			}
			alpha_vec = c(alpha / 2, 1 - alpha / 2)
			z_alpha = stats::qnorm(alpha_vec)
			denom = 1 - a * (z0 + z_alpha)
			if (any(!is.finite(denom)) || any(abs(denom) < sqrt(.Machine$double.eps))) {
				return(on_failure(paste0(reason_prefix, "unstable_bias_or_acceleration")))
			}
			adj = stats::pnorm(z0 + (z0 + z_alpha) / denom)
			prob_eps = 1 / (length(boot_distr) + 1)
			adj = pmin(1 - prob_eps, pmax(prob_eps, adj))
			adj = sort(adj)
			if (any(adj <= 2 * prob_eps) || any(adj >= 1 - 2 * prob_eps)) {
				return(on_failure(paste0(reason_prefix, "adjustment_on_boundary")))
			}
			if (diff(adj) < prob_eps) {
				return(stats::quantile(boot_distr, probs = c(alpha / 2, 1 - alpha / 2), names = FALSE, type = 8))
			}
			stats::quantile(boot_distr, probs = adj, names = FALSE, type = 8)
		},
		# Shared BCa two-sided p-value math -- see bca_ci_core() above for the shared
		# bias-correction (z0) / acceleration (a) derivation; this additionally maps a
		# tested null value `delta` through the same adjustment to get a two-sided p-value.
		bca_pval_core = function(boot_distr, est, delta, jack, reason_prefix, on_failure){
			z0 = stats::qnorm(private$bca_midrank_cdf(boot_distr, est))
			jack_bar = mean(jack)
			num = sum((jack_bar - jack)^3)
			den = 6 * (sum((jack_bar - jack)^2)^(3/2))
			a = if (is.finite(den) && den > 0) num / den else 0
			if (!is.finite(z0) || !is.finite(a) || abs(z0) > 2.5 || abs(a) > 1) {
				return(on_failure(paste0(reason_prefix, "unstable_bias_or_acceleration")))
			}
			z_alpha = stats::qnorm(c(0.025, 0.975))
			denom_ci = 1 - a * (z0 + z_alpha)
			if (any(!is.finite(denom_ci)) || any(abs(denom_ci) < sqrt(.Machine$double.eps))) {
				return(on_failure(paste0(reason_prefix, "unstable_bias_or_acceleration")))
			}
			prob_eps = 1 / (length(boot_distr) + 1)
			adj_ci = sort(stats::pnorm(z0 + (z0 + z_alpha) / denom_ci))
			if (any(!is.finite(adj_ci)) || any(adj_ci <= 2 * prob_eps) || any(adj_ci >= 1 - 2 * prob_eps)) {
				return(on_failure(paste0(reason_prefix, "adjustment_on_boundary")))
			}
			# v1.0.6-TODO-75 / v1.0.6-TODO-114: when delta cannot be reached by any BCa interval the
			# p-value is the smallest one this B can report, not NA. The BCa p-value is the alpha at
			# which a BCa endpoint equals delta. The endpoint for tail level z is
			#   z_end = z0 + (z0 + z) / (1 - a (z0 + z))   (in normal-score space of the bootstrap CDF),
			# which never leaves the bootstrap support [min, max] (its quantile is taken from the
			# draws) and, for a != 0, never crosses z0 - 1/a. So (i) a delta outside the bootstrap
			# support, and (ii) a delta with 1 + a (z_delta - z0) <= 0, lies outside every BCa interval
			# at every level: the exact BCa p-value is below anything B draws can resolve. We report
			# the 2/B floor that the percentile, symmetric and studentized types report in the same
			# situation. The old code clamped the CDF to machine epsilon (qnorm = -8.1), tripped the
			# |adj_z| > 8 check and returned NA silently. A large finite |adj_z| on the monotone
			# branch is likewise just a far-tail delta, so it also gets the floor.
			p_floor = 2 / length(boot_distr)
			F_delta = mean(boot_distr < delta) + 0.5 * mean(boot_distr == delta)
			if (F_delta <= 0 || F_delta >= 1) return(p_floor)
			z_delta = stats::qnorm(F_delta)
			s = z_delta - z0
			denom = 1 + a * s
			if (!is.finite(denom)) {
				return(on_failure(paste0(reason_prefix, "unstable_bias_or_acceleration")))
			}
			if (denom <= sqrt(.Machine$double.eps)) return(p_floor)
			adj_z = s / denom - z0
			if (!is.finite(adj_z)) {
				return(on_failure(paste0(reason_prefix, "adjustment_on_boundary")))
			}
			p_raw = min(1, 2 * min(stats::pnorm(adj_z), stats::pnorm(-adj_z)))
			min(1, max(p_floor, p_raw))
		}
	)
)
