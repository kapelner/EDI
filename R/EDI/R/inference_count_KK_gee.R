#' GEE Inference for KK Designs with Count Response
#'
#' Fits a Generalized Estimating Equations (GEE) model (using an internal Rcpp
#' solver or \pkg{geepack}) for Poisson (count) responses under a KK 
#' matching-on-the-fly design using the treatment indicator and, optionally,
#' all recorded covariates as predictors.
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
		#'   matched/reservoir design, and prepare the working correlation structure
		#'   used by \code{\link[EDI:InferenceCountPoissonKKGEE]{InferenceCountPoissonKKGEE}}.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param use_rcpp Whether to use the internal Rcpp solver.
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
