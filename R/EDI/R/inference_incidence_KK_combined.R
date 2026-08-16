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
#' @references Liang, K.-Y., and Zeger, S. L. (1986). "Longitudinal Data
#'   Analysis Using Generalized Linear Models." \emph{Biometrika}, 73(1),
#'   13-22, \doi{10.1093/biomet/73.1.13}, for the GEE estimating-equation
#'   framework and sandwich variance estimator used here.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidKKGEE$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidKKGEE = define_inference_class(
	classname = "InferenceIncidKKGEE",
	inherit = Inference,
	components = "KKGEE",
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
#' Abstract class for Conditional Logistic Combined-Likelihood Combined Inference
#'
#' @keywords internal
InferenceAbstractKKCondLogitGLMMOneLik = R6::R6Class("InferenceAbstractKKCondLogitGLMMOneLik",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
		#' @description Initialize KK combined incidence likelihood inference and set
		#'   up the conditional-logit / marginal model components used by related
		#'   \code{\link[EDI:InferenceAsympLik]{InferenceAsympLik}} methods.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param max_abs_reasonable_coef Cap for reasonable coefficient estimates.
		#' @param max_abs_log_sigma Cap for reasonable log random effect variance.
		#' @param max_abs_reasonable_se Cap for reasonable treatment standard errors.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, max_abs_reasonable_coef = 1e4, max_abs_log_sigma = 8, max_abs_reasonable_se = 1.25, verbose = FALSE, smart_cold_start_default = NULL){
			super$initialize(des_obj, model_formula = model_formula, max_abs_reasonable_coef = max_abs_reasonable_coef, max_abs_reasonable_se = max_abs_reasonable_se, max_abs_log_sigma = max_abs_log_sigma, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
		}
	),
	private = list(
		is_a_kk_cond_logit_glmm_one_lik = function() TRUE,
		supports_likelihood_tests = function() TRUE,
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			d = ctx$d
			j_treat = as.integer(ctx$j_T)
			list(
				X = d$X_conc,
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					fast_clogit_plus_glmm_cpp(
						X_disc = d$X_disc, y_disc = d$y_disc,
						X_conc = d$X_conc, y_conc = d$y_conc,
						group_conc = d$group_conc,
						has_discordant = d$has_discordant,
						has_concordant = d$has_concordant,
						warm_start_params = start %||% private$get_fit_warm_start_for_length("params", length(ctx$start)) %||% ctx$start,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(length(ctx$start)),
						estimate_only = FALSE,
						max_abs_log_sigma = private$max_abs_log_sigma,
						fixed_idx = j_treat, fixed_values = delta,
						optimization_alg = private$optimization_alg
					)
				},
				extract_start = function(fit){ as.numeric(fit$params) },
				score = function(fit){
					as.numeric(get_clogit_plus_glmm_score_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				observed_information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				fisher_information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll)
				}
			)
		}
	)
)
