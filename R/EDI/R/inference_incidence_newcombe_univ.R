newcombe_independent_ci_stable_r = function(x_t, n_t, x_c, n_c, alpha) {
	wilson = function(x, n) {
		p = x / n
		z = stats::qnorm(alpha / 2, lower.tail = FALSE)
		z2 = z^2
		denom = 1 + z2 / n
		center = p + z2 / (2 * n)
		adj = z * sqrt(p * (1 - p) / n + z2 / (4 * n^2))
		pmax(0, pmin(1, c(center - adj, center + adj) / denom))
	}
	p_t = x_t / n_t
	p_c = x_c / n_c
	ci_t = wilson(x_t, n_t)
	ci_c = wilson(x_c, n_c)
	diff = p_t - p_c
	c(
		max(-1, diff - sqrt((p_t - ci_t[1])^2 + (ci_c[2] - p_c)^2)),
		min(1, diff + sqrt((ci_t[2] - p_t)^2 + (p_c - ci_c[1])^2))
	)
}

#' Newcombe Risk-Difference Inference for Binary Responses
#'
#' Fits the Newcombe hybrid score method (Method 10) for the risk difference in a
#' two-arm binary trial. This method constructs a confidence interval for the
#' difference between two independent proportions by combining Wilson score intervals
#' for each group.
#'
#' @details
#' This class is unadjusted and assumes independent samples (e.g. from a
#' Bernoulli design). It ignores any matched-pair structure if present; for
#' matched data, use \code{InferenceIncidKKNewcombeRiskDiff}. The point
#' estimate is the plain risk difference \eqn{\hat p_T - \hat p_C}. The
#' confidence interval (\code{newcombe_independent_ci_cpp}) is Newcombe's
#' "Method 10" hybrid score interval: separate Wilson score intervals
#' \eqn{[\ell_T, u_T]} and \eqn{[\ell_C, u_C]} are computed for each arm's
#' proportion individually, then combined into a difference interval via
#' \eqn{[\hat p_T - \hat p_C - \sqrt{(\hat p_T - \ell_T)^2 + (u_C - \hat
#' p_C)^2},\ \hat p_T - \hat p_C + \sqrt{(u_T - \hat p_T)^2 + (\hat p_C -
#' \ell_C)^2}]} — this avoids the boundary/coverage problems of the naive
#' Wald interval on a risk difference while remaining closed-form (no
#' iterative score-test inversion, unlike the Miettinen-Nurminen method in
#' \code{\link[EDI:InferenceIncidMiettinenNurminenRiskDiff]{InferenceIncidMiettinenNurminenRiskDiff}}).
#' The two-sided p-value has no closed form here: it is obtained by
#' numerically inverting the confidence interval (bisection via
#' \code{stats::uniroot}) to find the significance level at which \code{delta}
#' falls exactly on the interval boundary.
#'
#' @references Newcombe, R. G. (1998). "Interval Estimation for the Difference
#'   Between Independent Proportions: Comparison of Eleven Methods."
#'   \emph{Statistics in Medicine}, 17(8), 873-890,
#'   \doi{10.1002/(SICI)1097-0258(19980430)17:8<873::AID-SIM779>3.0.CO;2-I},
#'   for "Method 10", the hybrid Wilson-score interval used here.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidNewcombeRiskDiff$new(seq_des)
#' inf$compute_estimate()
#' }
#' @concept risk difference
#' @concept Wilson score interval
#' @export
InferenceIncidNewcombeRiskDiff = define_inference_class(
	classname = "InferenceIncidNewcombeRiskDiff",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize a Newcombe risk-difference inference object for a
		#'   completed design with an uncensored incidence response.
		#' @param des_obj A completed \code{DesignSeqOneByOne} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the observed (unadjusted) risk-difference estimate
		#'   \eqn{\hat p_T - \hat p_C} (see class documentation for the full
		#'   Newcombe interval method).
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the risk-difference estimate under subject/block
		#'   bootstrap weights: the weighted event proportions \eqn{\hat p_T^w =
		#'   \sum_i r_i y_i \mathbb{1}[w_i=1] / \sum_i r_i \mathbb{1}[w_i=1]} (and
		#'   analogously for control), differenced. Used by the Bayesian bootstrap
		#'   and related weighted-resampling machinery; see
		#'   \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   Always leaves the standard error and degrees of freedom unavailable
		#'   (\code{NA}) regardless of \code{estimate_only} — the Newcombe interval
		#'   method has no separate variance quantity to compute on this path.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			i_t = private$w == 1
			i_c = private$w == 0
			w_t = sum(row_weights[i_t])
			w_c = sum(row_weights[i_c])
			if (!is.finite(w_t) || !is.finite(w_c) || w_t <= 0 || w_c <= 0) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			p_t = sum(row_weights[i_t] * as.numeric(private$y[i_t])) / w_t
			p_c = sum(row_weights[i_c] * as.numeric(private$y[i_c])) / w_c
			private$cached_values$counts = list(
				n_t = w_t, n_c = w_c,
				x_t = sum(row_weights[i_t] * as.numeric(private$y[i_t])),
				x_c = sum(row_weights[i_c] * as.numeric(private$y[i_c])),
				p_t = p_t, p_c = p_c
			)
			private$cached_values$beta_hat_T = p_t - p_c
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} Newcombe hybrid Wilson-score
		#'   confidence interval for the risk difference (see class documentation
		#'   for the full formula), via \code{newcombe_independent_ci_cpp}.
		#' @param alpha The significance level.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			private$shared()
			counts = private$cached_values$counts
			if (is.null(counts)) return(c(NA_real_, NA_real_))
			
			ci = newcombe_independent_ci_cpp(counts$x_t, counts$n_t, counts$x_c, counts$n_c, alpha)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		#' @description Computes a two-sided p-value testing \eqn{H_0: p_T - p_C =
		#'   \code{delta}} by numerically finding (\code{stats::uniroot}) the
		#'   significance level \eqn{\alpha} at which \code{delta} falls exactly on
		#'   the boundary of the Newcombe confidence interval (see class
		#'   documentation) — there is no closed-form p-value for this method.
		#'   The search is carried out on \eqn{\log(\alpha)} so that very small
		#'   p-values are resolved accurately. If the null is already outside the
		#'   interval at the numerical \eqn{\alpha} floor, that floor is returned;
		#'   if it remains inside as \eqn{\alpha} approaches one, the p-value is
		#'   \eqn{1}.
		#' @param delta The null risk difference.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, any.missing = FALSE)
			}
			private$shared()
			counts = private$cached_values$counts
			if (is.null(counts) || counts$n_t == 0 || counts$n_c == 0) return(NA_real_)
			
			# Invert the Newcombe CI on the log-alpha scale.  A linear-alpha
			# uniroot search both fails to bracket very strong effects and has an
			# absolute tolerance that is much too coarse for small p-values.
			p_fn = function(a) {
				# The native Wilson helper forms 1 - alpha / 2, which rounds to one
				# for the log-scale tail values needed here. This R implementation
				# instead asks qnorm for its upper tail directly and remains finite.
				ci = newcombe_independent_ci_stable_r(counts$x_t, counts$n_t, counts$x_c, counts$n_c, a)
				if (delta < private$cached_values$beta_hat_T) ci[1] - delta else ci[2] - delta
			}
			alpha_floor = 1e-300
			alpha_ceiling = 1 - .Machine$double.eps
			at_floor = p_fn(alpha_floor)
			at_ceiling = p_fn(alpha_ceiling)
			is_lower_boundary = delta < private$cached_values$beta_hat_T
			outside_at_floor = if (is_lower_boundary) at_floor >= 0 else at_floor <= 0
			inside_at_ceiling = if (is_lower_boundary) at_ceiling <= 0 else at_ceiling >= 0
			if (!is.finite(at_floor) || !is.finite(at_ceiling)) return(NA_real_)
			if (outside_at_floor) return(alpha_floor)
			if (inside_at_ceiling) return(1.0)

			res = tryCatch(
				stats::uniroot(
					function(log_alpha) p_fn(exp(log_alpha)),
					interval = log(c(alpha_floor, alpha_ceiling)), tol = 1e-12
				)$root,
				error = function(e) NA_real_
			)
			if (!is.finite(res)) return(NA_real_)
			exp(res)
		}
	),
	private = list(
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		get_counts = function(){
			i_t = private$w == 1
			i_c = private$w == 0
			n_t = sum(i_t)
			n_c = sum(i_c)
			x_t = sum(private$y[i_t])
			x_c = sum(private$y[i_c])
			list(
				n_t = n_t, n_c = n_c,
				x_t = x_t, x_c = x_c,
				p_t = if (n_t > 0) x_t / n_t else NA_real_,
				p_c = if (n_c > 0) x_c / n_c else NA_real_
			)
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			counts = private$get_counts()
			if (counts$n_t == 0 || counts$n_c == 0 || !is.finite(counts$p_t) || !is.finite(counts$p_c)){
				private$cached_values$counts = counts
				private$cache_nonestimable_estimate("newcombe_riskdiff_empty_arm")
				return(invisible(NULL))
			}
			private$cached_values$counts = counts
			private$cached_values$beta_hat_T = counts$p_t - counts$p_c
			if (estimate_only) return(invisible(NULL))
		},
		get_supported_testing_types_impl = function(){
			character(0)
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
		)
	),
	metadata = list(likelihood_tier = "none")
)
