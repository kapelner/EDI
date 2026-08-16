#' GEE Inference for KK Designs with Count Response
#'
#' Fits a Generalized Estimating Equations (GEE) model with a Poisson family and
#' log link, \eqn{\log E[Y_i \mid x_i] = x_i^\top\beta}, for count responses
#' under a KK matching-on-the-fly design, using an \strong{exchangeable} working
#' correlation structure where each cluster is either a matched pair (2 members)
#' or a reservoir singleton (1 member) — see
#' \code{$compute_estimate()}'s method-level documentation for the full fitting
#' contract (internal Rcpp solver vs. \pkg{geepack} fallback, hardening/retry
#' behavior). GEE is used here purely to fit one marginal model jointly across
#' matched-pair and reservoir subjects while accounting for the within-pair
#' correlation the matching induces, not as a longitudinal/repeated-measures
#' tool. Inference is quasi-likelihood/estimating-equation based
#' (\code{likelihood_tier = "quasi"}): standard errors are GEE sandwich (robust)
#' standard errors, not model-likelihood-based.
#'
#' @references Liang, K.-Y., and Zeger, S. L. (1986). "Longitudinal Data
#'   Analysis Using Generalized Linear Models." \emph{Biometrika}, 73(1),
#'   13-22, \doi{10.1093/biomet/73.1.13}, for the GEE estimating-equation
#'   framework and sandwich variance estimator used here.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountPoissonKKGEE$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountPoissonKKGEE = define_inference_class(
	classname = "InferenceCountPoissonKKGEE",
	inherit = Inference,
	components = "KKGEE",
	public = list(
		#' @description Initialize KK count-response GEE inference, validate the
		#'   matched/reservoir design, and prepare the exchangeable-working-correlation
		#'   Poisson (log-link) GEE fitting machinery used by
		#'   \code{\link[EDI:InferenceCountPoissonKKGEE]{InferenceCountPoissonKKGEE}}.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param use_rcpp Whether to use the internal Rcpp GEE solver (\code{TRUE},
		#'   default) with automatic fallback to \code{geepack::geeglm} on failure,
		#'   or always use \code{geepack::geeglm} directly (\code{FALSE}).
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_gee_shared(des_obj, use_rcpp = use_rcpp, model_formula = model_formula)
		}
	),
	private = list(
		gee_response_type = function() "count",
		gee_family        = function() stats::poisson(link = "log"),
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
