#' GEE Inference for KK Designs with Binary Response
#'
#' Fits a Generalized Estimating Equations (GEE) model with a binomial family
#' and logit link, \eqn{\mathrm{logit}\,\Pr(Y_i = 1 \mid x_i) = x_i^\top\beta},
#' for binary (incidence) responses under a KK matching-on-the-fly design, using
#' an \strong{exchangeable} working correlation structure where each cluster is
#' either a matched pair (2 members) or a reservoir singleton (1 member) — see
#' \code{$compute_estimate()}'s method-level documentation for the full fitting
#' contract (internal Rcpp solver vs. \pkg{geepack} fallback, hardening/retry
#' behavior). GEE is used here purely to fit one marginal model jointly across
#' matched-pair and reservoir subjects while accounting for the within-pair
#' correlation the matching induces, not as a longitudinal/repeated-measures
#' tool. Inference is quasi-likelihood/estimating-equation based
#' (\code{likelihood_tier = "quasi"}): standard errors are GEE sandwich (robust)
#' standard errors, not model-likelihood-based.
#'
#' Under (quasi-)complete separation (fitted probabilities numerically 0 or
#' 1) the logit GEE has no finite solution: the fitter stops at a huge estimate and
#' the sandwich standard error collapses with it. The standard error is then treated
#' as unavailable, so the asymptotic p-value and confidence interval are \code{NA}
#' (not a spurious \eqn{p \approx 0}), with one warning of class
#' \code{edi_logistic_separation_warning} per object (silent inside resampling).
#' The point estimate is returned unchanged. Use a randomization test
#' (\code{$compute_rand_two_sided_pval()}), an exact incidence method, or fewer
#' covariates instead.
#'
#' @references Liang, K.-Y., and Zeger, S. L. (1986). "Longitudinal Data
#'   Analysis Using Generalized Linear Models." \emph{Biometrika}, 73(1),
#'   13-22, \doi{10.1093/biomet/73.1.13}, for the GEE estimating-equation
#'   framework and sandwich variance estimator used here.
#'
#' @examples
#' seq_des = DesignSeqOneByOneKK14$new(n = 30, response_type = 'incidence')
#' \donttest{
#' for (i in 1:30) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(30, 1, 0.5))
#' inf = InferenceIncidKKGEE$new(seq_des)
#' inf$compute_estimate()
#' }
#' @section Subsampling and m-out-of-n:
#' (v1.0.6-TODO-230.) At the default size \eqn{b = m = \lfloor n^{0.7} \rfloor} a draw can be
#' \emph{degenerate}: a treatment arm with no events or only events. Its log odds ratio then sits where the fitter stopped (about \eqn{\pm 20}),
#' not in the sampling law the pivot estimates, so the draw is \code{NaN} in
#' \code{approximate_subsampling_distribution_beta_hat_T()} and
#' \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()} (also with \code{debug = TRUE})
#' and is not used. If fewer than 80\% of the \code{B} draws are usable (degenerate and failed draws
#' both count against it), the subsampling / m-out-of-n p-value or interval is \code{NA} with reason
#' \code{"subsampling_too_few_usable_draws_fraction"} or \code{"m_out_of_n_too_few_usable_draws_fraction"}
#' and one \code{edi_procedure_na_warning}. The p-value is symmetric: the share of usable pivot draws
#' \eqn{\sqrt{b}(\hat\theta^* - \hat\theta)} (subsampling also divides by \eqn{\sqrt{1 - b/n}}) at
#' least as large in absolute value as \eqn{\sqrt{n}(\hat\theta - \delta)}, floored at \eqn{1/B}, rather
#' than the equal-tailed \eqn{2\min\{\cdot\}}, because at small \eqn{b} the law of a log ratio is skewed
#' toward the observed effect and the equal-tailed rule doubles the heavy tail. The interval is the basic
#' (equal-tailed) one. Null size at \eqn{n = 80} (200 data sets, \code{B = 199}, nominal 0.05, before and
#' after): Wald 0.055; subsampling 0.000 to 0.005, m-out-of-n 0.000 before and after (the pivot is wider than the Wald scale at this size); intervals that were \code{NA} (2\% and 10\%) are now finite. The ordinary bootstrap is the better resampling method for this estimand.
#' @eval rd_small_sample_section("InferenceIncidKKGEE")
#' @export
InferenceIncidKKGEE = define_inference_class(
	classname = "InferenceIncidKKGEE",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"Jackknife",
		"KKGEE"
	),
	public = list(
		#' @description Initialize KK binary-response GEE inference, validate the
		#'   matched/reservoir design, and prepare the exchangeable-working-correlation
		#'   binomial (logit-link) GEE fitting machinery used by
		#'   \code{\link[EDI:InferenceIncidKKGEE]{InferenceIncidKKGEE}}.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose Whether to print progress messages.
		#' @param use_rcpp Whether to use the internal Rcpp GEE solver (\code{TRUE},
		#'   default) with automatic fallback to \code{geepack::geeglm} on failure,
		#'   or always use \code{geepack::geeglm} directly (\code{FALSE}).
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_gee_shared(des_obj, use_rcpp = use_rcpp, model_formula = model_formula)
		}
	),
	private = list(
		gee_response_type = function() "incidence",
		gee_family        = function() stats::binomial(link = "logit"),
		shared_gee_dispatch = function(estimate_only = FALSE) private$shared_gee_default(estimate_only)
	),
	metadata = list(likelihood_tier = "quasi"),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"shared",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"jackknife_full_fit_is_separated",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_wald_confidence_interval_impl",
			"compute_wald_two_sided_pval_impl",
			"get_complexity_tier"
		)
	)
)
