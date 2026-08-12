#' GEE Inference for KK Designs with Proportion Response
#'
#' Fits a Generalized Estimating Equations (GEE) model (using \pkg{geepack})
#' for proportion (continuous values in (0, 1)) responses under a KK
#' matching-on-the-fly design using the treatment indicator and, optionally,
#' all recorded covariates as predictors.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropKKGEE$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferencePropKKGEE = define_inference_class(
	classname = "InferencePropKKGEE",
	inherit = Inference,
	components = "KKGEE",
	public = list(
		#' @description Initialize KK proportion-response GEE inference, validate the
		#'   matched/reservoir design, and prepare the working estimating-equation
		#'   model used by \code{\link[EDI:InferencePropKKGEE]{InferencePropKKGEE}}.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose Whether to print progress messages.
		#' @param use_rcpp Whether to use the internal Rcpp solver.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts() && !use_rcpp) {
				if (!check_package_installed("geepack")){
					stop("Package 'geepack' is required for ", class(self)[1], ". Please install it.")
				}
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_gee_shared(des_obj, use_rcpp = use_rcpp, model_formula = model_formula)
		}
	),
	private = list(
		gee_response_type = function() "proportion",
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
#' KK GLMM Inference for Proportion Responses
#'
#' Fits a logistic GLMM-style combined likelihood for KK designs with
#' proportion responses, combining matched-pair and reservoir information in
#' one model.
#'
#' @export
InferencePropKKGLMM = R6::R6Class("InferencePropKKGLMM",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
		#' @description Initialize KK proportion-response GLMM inference and prepare
		#'   the mixed-model likelihood used by
		#'   \code{\link[EDI:InferencePropKKGLMM]{InferencePropKKGLMM}}.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param max_abs_reasonable_coef Cap for reasonable coefficient estimates.
		#' @param max_abs_log_sigma Cap for reasonable log random effect variance.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		#' @param optimization_alg Character. Optimization algorithm (default "lbfgs").
		initialize = function(des_obj, model_formula = NULL, max_abs_reasonable_coef = 1e4, max_abs_log_sigma = 8, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, max_abs_reasonable_coef = max_abs_reasonable_coef, max_abs_log_sigma = max_abs_log_sigma, verbose = verbose, smart_cold_start_default = smart_cold_start_default, optimization_alg = optimization_alg)
		}
	),
	private = list(
		combine_reservoir_into_glmm = function() TRUE,
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
				d = d,
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
		},
		supports_lik_ratio_param_bootstrap = function() TRUE,
		simulate_under_lik_null = function(spec, delta, null_fit){
			d = spec$d
			params_null = as.numeric(null_fit$params)
			p = ncol(d$X_conc)
			beta_null = params_null[seq_len(p)]
			log_sigma = params_null[p + 1L]
			sigma = exp(min(log_sigma, private$max_abs_log_sigma))
			if (!is.finite(sigma) || sigma < 0) return(NULL)
			j = spec$j
			n_params = length(params_null)

			y_disc_sim = if (d$has_discordant && nrow(d$X_disc) > 0) {
				eta_disc = as.numeric(d$X_disc %*% beta_null)
				as.numeric(rbinom(length(eta_disc), 1L, plogis(eta_disc)))
			} else {
				d$y_disc
			}

			y_conc_sim = if (d$has_concordant && nrow(d$X_conc) > 0) {
				G = max(d$group_conc)
				u = rnorm(G, 0, sigma)
				eta_conc = as.numeric(d$X_conc %*% beta_null) + u[d$group_conc]
				as.numeric(rbinom(length(eta_conc), 1L, plogis(eta_conc)))
			} else {
				d$y_conc
			}

			d_sim = utils::modifyList(d, list(y_disc = y_disc_sim, y_conc = y_conc_sim))

			full_res = tryCatch(
				fast_clogit_plus_glmm_cpp(
					X_disc = d_sim$X_disc, y_disc = d_sim$y_disc,
					X_conc = d_sim$X_conc, y_conc = d_sim$y_conc,
					group_conc = d_sim$group_conc,
					has_discordant = d_sim$has_discordant,
					has_concordant = d_sim$has_concordant,
					warm_start_params = params_null,
					max_abs_log_sigma = private$max_abs_log_sigma,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(full_res) || !isTRUE(full_res$converged)) return(NULL)
			full_fit_boot = list(params = as.numeric(full_res$params), neg_loglik = as.numeric(full_res$neg_loglik %||% full_res$neg_ll))
			if (!is.finite(full_fit_boot$neg_loglik)) return(NULL)

			list(
				full_fit = full_fit_boot,
				fit_null = function(d2, start = NULL){
					res = tryCatch(
						fast_clogit_plus_glmm_cpp(
							X_disc = d_sim$X_disc, y_disc = d_sim$y_disc,
							X_conc = d_sim$X_conc, y_conc = d_sim$y_conc,
							group_conc = d_sim$group_conc,
							has_discordant = d_sim$has_discordant,
							has_concordant = d_sim$has_concordant,
							warm_start_params = start %||% full_fit_boot$params,
							max_abs_log_sigma = private$max_abs_log_sigma,
							fixed_idx = j, fixed_values = d2,
							optimization_alg = private$optimization_alg
						),
						error = function(e) NULL
					)
					if (is.null(res) || !isTRUE(res$converged)) return(NULL)
					list(params = as.numeric(res$params), neg_loglik = as.numeric(res$neg_loglik %||% res$neg_ll))
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		}
	)
)
