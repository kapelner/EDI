#' Zero-Inflated Poisson Regression Inference for Count Responses
#'
#' Fits a zero-inflated Poisson regression for count responses: a binary
#' excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' Poisson count submodel \eqn{\log E[Y_i \mid \text{not structural zero},
#' w_i, x_i] = \beta_0 + \beta_T w_i + x_i^\top \gamma}. Unlike a hurdle
#' model, zero counts can arise from either the structural-zero mechanism or
#' from an ordinary Poisson draw of \eqn{0}, so the two mixture components are
#' not identified by disjoint support. The hurdle and count submodels may use
#' different covariate formulas (\code{model_formula}/\code{model_formula_zero}).
#' The reported treatment effect is the coefficient from the conditional count
#' component, on the log-rate scale, \strong{conditional on the response
#' coming from the count process, not the excess-zero-inflation mechanism}:
#' it is not the effect on the unconditional mean \eqn{E[Y]}, which also
#' depends on how treatment shifts the excess-zero probability, under the
#' default \code{estimand = "conditional"}. \code{likelihood_tier = "full"}:
#' Wald, gradient, and (bootstrap-calibrated) likelihood-ratio tests are
#' available for the count submodel's treatment coefficient under that
#' estimand; a plain score test is not exposed. \strong{Jackknife inference
#' is not supported}: delete-one refits of this two-part mixture model are
#' numerically unstable, so \code{compute_jackknife_estimate()} and related
#' methods report explicit non-estimability rather than attempting
#' delete-one refits.
#'
#' \strong{Marginal (unconditional-mean) estimand.} Via
#' \code{\link[EDI:InferenceMarginalEstimand]{set_estimand()}}, this class
#' also supports \code{estimand = "marginal_mean_diff"} and
#' \code{"marginal_ratio"}: the g-computation average, over the empirical
#' covariate distribution, of the model-implied unconditional mean
#' \eqn{E[Y_i \mid w_i, x_i] = (1 - \pi(x_i)) \lambda(x_i)} (the untruncated
#' Poisson mean weighted by the non-structural-zero probability) at
#' \eqn{w_i = 1} vs. \eqn{w_i = 0} — a mean difference or, on the log scale,
#' a mean ratio. This is a pure post-fit transform of the same maximum-
#' likelihood fit (no refit), with a delta-method standard error computed
#' against the sandwich-robust covariance matrix already used for this
#' class's conditional Wald inference. Only \code{"wald"}-type inference is
#' available under a marginal estimand (no likelihood-ratio/score/gradient
#' test, since the marginal quantity is a functional of the fitted
#' parameters, not itself a likelihood).
#'
#' @references Lambert, D. (1992). "Zero-Inflated Poisson Regression, with an
#'   Application to Defects in Manufacturing." \emph{Technometrics}, 34(1),
#'   1-14, \doi{10.2307/1269547}, for the zero-inflated count-model
#'   framework.
#'
#' @seealso \code{\link[EDI:InferenceCountPoisson]{InferenceCountPoisson}} for
#'   the single-part Poisson model this class's count submodel generalizes;
#'   \code{\link[EDI:InferenceCountHurdlePoisson]{InferenceCountHurdlePoisson}}
#'   for the related hurdle (disjoint-support) variant;
#'   \code{\link[EDI:InferenceCountZeroInflatedNegBin]{InferenceCountZeroInflatedNegBin}}
#'   for the overdispersion-robust negative-binomial variant (does not
#'   support a marginal estimand — the mean-function derivation here is
#'   Poisson-specific).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountZeroInflatedPoisson$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountZeroInflatedPoisson = define_inference_class(
	classname = "InferenceCountZeroInflatedPoisson",
	inherit = InferenceCountZeroAugmentedPoissonAbstract,
	# 2026-08-23 (marginal_estimand_report.md TODO-5): converted from a plain
	# R6::R6Class leaf of the abstract to a real define_inference_class()
	# call of its own, the only way to compose a new component
	# ("MarginalEstimand") on top of an already-factory-built abstract
	# without silently handing the (Poisson-specific, NegBin-invalid)
	# capability to the NegBin sibling sharing the same abstract. Mirrors
	# InferencePropZeroOneInflatedBetaRegr's TODO-4 conversion exactly.
	components = "MarginalEstimand",
	# metadata$likelihood_tier must be restated explicitly here even though
	# the inherited abstract's own effective tier is already "full" --
	# MarginalEstimand's allowed_likelihood_tiers = c("partial", "full") is
	# validated against THIS class's own declared metadata at
	# define_inference_class() time, not the inherited value (same reason
	# ZOIB's TODO-4 conversion needed to restate it).
	metadata = list(likelihood_tier = "full"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		private = "get_supported_estimands_impl"
	),
	public = list(
		#' @description Initialize inference for the zero-inflated Poisson model
		#'   (binary excess-zero submodel mixed with a Poisson count submodel); see
		#'   \code{\link[EDI:InferenceCountZeroInflatedPoisson]{InferenceCountZeroInflatedPoisson}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula Optional formula for the count submodel.
		#' @param model_formula_zero Formula for the zero-inflation submodel. If
		#'   \code{NULL} (default), it uses the same formula as \code{model_formula}.
		#' @param use_rcpp Logical. If \code{TRUE} (default), use our internal Rcpp
		#'   implementation. If \code{FALSE}, use \pkg{glmmTMB}.
		#' @param verbose Whether to print progress messages.
		#' @param optimization_alg Optimization algorithm. Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero = NULL, use_rcpp = TRUE, verbose = FALSE, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, model_formula_zero = model_formula_zero, use_rcpp = use_rcpp, verbose = verbose, optimization_alg = optimization_alg)
		},
		#' @description Fits the zero-inflated Poisson model. Under the default
		#'   \code{estimand = "conditional"}, returns \eqn{\hat\beta_T}, the
		#'   treatment log-rate coefficient from the conditional count submodel
		#'   (see the class-level caveat that this is conditional on the response
		#'   coming from the count process, not an unconditional-mean effect).
		#'   Under \code{estimand = "marginal_mean_diff"} or
		#'   \code{"marginal_ratio"} (set via \code{set_estimand()}), returns the
		#'   g-computation marginal mean difference or log-scale marginal ratio
		#'   of the unconditional mean \eqn{E[Y \mid w, x] = (1-\pi(x))\lambda(x)}
		#'   instead — a pure post-fit transform of the same cached fit, no refit.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap
		#'   resampling paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			estimand = self$get_estimand()
			if (estimand %in% c("marginal_mean_diff", "marginal_ratio")) {
				return(private$compute_marginal_estimand_estimate(estimand, estimate_only = estimate_only))
			}
			# 2026-08-23 (marginal_estimand_report.md TODO-5): re-derive the
			# conditional beta_hat_T/s_beta_hat_T from the estimand-invariant
			# private$cached_mod every call (same fix as ZOIB's TODO-4
			# compute_estimate()) so switching the estimand back to
			# "conditional" after a marginal computation doesn't return stale
			# marginal numbers left in private$cached_values by shared()'s own
			# short-circuit guard.
			mod = private$cached_mod
			if (!is.null(mod)) {
				private$cached_values$beta_hat_T = as.numeric(mod$beta_hat_T %||% mod$params[2L])[1L]
				if (!estimate_only) {
					ssq = mod$ssq_b_j
					ssq = if (length(ssq) >= 1L) as.numeric(ssq)[1L] else NA_real_
					if (is.finite(ssq) && ssq > 0) {
						private$cached_values$s_beta_hat_T = sqrt(ssq)
						private$clear_nonestimable_state()
					} else {
						private$cache_nonestimable_se("model_standard_error_unavailable")
					}
				}
			}
			private$cached_values$beta_hat_T
		},
		#' @description Asymptotic confidence interval. Under the conditional
		#'   estimand, delegates to the shared zero-augmented count-model Wald/
		#'   bootstrap-fallback contract; under a marginal estimand, the
		#'   delta-method interval computed by \code{compute_estimate()}. Calls
		#'   \code{self$compute_estimate()} first (not \code{private$shared()}
		#'   directly) so the estimand-aware cache is always current regardless
		#'   of call order.
		#' @param alpha The significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			self$compute_estimate(estimate_only = FALSE)
			if (self$get_estimand() %in% c("marginal_mean_diff", "marginal_ratio")) {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_ci_from_s_and_df(alpha))
				}
				return(private$count_likelihood_missing_ci(alpha))
			}
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) {
				return(private$count_likelihood_missing_ci(alpha))
			}
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				warning(private$za_description(), ": falling back to bootstrap because standard error is unavailable.")
				return(self$compute_bootstrap_confidence_interval(alpha = alpha))
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Asymptotic two-sided p-value, dispatched exactly as
		#'   \code{compute_asymp_confidence_interval()}; see that method's
		#'   description for the marginal-estimand path.
		#' @param delta The null treatment effect under the current estimand
		#'   (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			self$compute_estimate(estimate_only = FALSE)
			if (self$get_estimand() %in% c("marginal_mean_diff", "marginal_ratio")) {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_two_sided_pval_from_s_and_df(delta))
				}
				return(NA_real_)
			}
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				warning(private$za_description(), ": falling back to bootstrap because standard error is unavailable.")
				return(self$compute_bootstrap_two_sided_pval(delta = delta, na.rm = TRUE))
			}
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		za_family = function() stats::poisson(link = "log"),
		za_description = function() "Zero-Inflated Poisson",
		# 2026-08-23 (marginal_estimand_report.md TODO-5): every class
		# composing MarginalEstimand supports only "conditional" by default
		# (the component's own get_supported_estimands_impl()); overridden
		# here to add the g-computation marginal mean difference and
		# log-scale marginal ratio of the unconditional mean.
		get_supported_estimands_impl = function(){
			c("conditional", "marginal_mean_diff", "marginal_ratio")
		}
	)
)
#' Zero-Inflated Negative Binomial Regression Inference for Count Responses
#'
#' Fits a zero-inflated negative binomial regression for count responses: a
#' binary excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' negative-binomial count submodel \eqn{\log E[Y_i \mid \text{not structural
#' zero}, w_i, x_i] = \beta_0 + \beta_T w_i + x_i^\top \gamma},
#' \eqn{\mathrm{Var}(Y_i \mid \text{not structural zero}) = \mu_i + \mu_i^2 /
#' \theta}. Unlike a hurdle model, zero counts can arise from either the
#' structural-zero mechanism or from an ordinary negative-binomial draw of
#' \eqn{0}. The hurdle and count submodels may use different covariate
#' formulas (\code{model_formula}/\code{model_formula_zero}). The reported
#' treatment effect is the coefficient from the conditional count component,
#' on the log-rate scale, \strong{conditional on the response coming from the
#' count process, not the excess-zero-inflation mechanism}: it is not the
#' effect on the unconditional mean \eqn{E[Y]}, which also depends on how
#' treatment shifts the excess-zero probability. A marginal
#' (unconditional-mean) estimand is not yet implemented for this class (see
#' \code{marginal_estimand_report.md}). \code{likelihood_tier = "full"}:
#' Wald, gradient, score, and (bootstrap-calibrated) likelihood-ratio tests
#' are all available for the count submodel's treatment coefficient (unlike
#' the Poisson variant, this class's private
#' \code{get_supported_testing_types_impl()} includes \code{"score"}).
#' \strong{Jackknife inference is not supported}: delete-one refits of this
#' two-part mixture model with a jointly-estimated dispersion parameter are
#' numerically unstable, so \code{compute_jackknife_estimate()} and related
#' methods report explicit non-estimability rather than attempting
#' delete-one refits.
#'
#' @references Lambert, D. (1992). "Zero-Inflated Poisson Regression, with an
#'   Application to Defects in Manufacturing." \emph{Technometrics}, 34(1),
#'   1-14, \doi{10.2307/1269547}, for the zero-inflated count-model
#'   framework.
#'
#' @seealso \code{\link[EDI:InferenceCountNegBin]{InferenceCountNegBin}} for
#'   the single-part negative binomial model this class's count submodel
#'   generalizes;
#'   \code{\link[EDI:InferenceCountZeroInflatedPoisson]{InferenceCountZeroInflatedPoisson}}
#'   for the Poisson (equidispersed) variant.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'count')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rpois(10, 2))
#' inf = InferenceCountZeroInflatedNegBin$new(seq_des, model_formula = ~ x1)
#' inf$compute_estimate()
#' }
#' @export
InferenceCountZeroInflatedNegBin = R6::R6Class("InferenceCountZeroInflatedNegBin",
	lock_objects = FALSE,
	inherit = InferenceCountZeroAugmentedPoissonAbstract,
	public = list(
		#' @description Initialize inference for the zero-inflated negative
		#'   binomial model (binary excess-zero submodel mixed with a
		#'   negative-binomial count submodel); see
		#'   \code{\link[EDI:InferenceCountZeroInflatedNegBin]{InferenceCountZeroInflatedNegBin}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param model_formula_zero Formula for the zero-inflation submodel. If
		#'   \code{NULL} (default), it uses the same formula as \code{model_formula}.
		#' @param use_rcpp Logical. If \code{TRUE} (default), use our internal Rcpp
		#'   implementation. If \code{FALSE}, use \pkg{glmmTMB}.
		#' @param verbose Whether to print progress messages.
		#' @param optimization_alg Optimization algorithm. Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero = NULL, use_rcpp = TRUE, verbose = FALSE, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, model_formula_zero = model_formula_zero, use_rcpp = use_rcpp, verbose = verbose, optimization_alg = optimization_alg)
		}
	),
	private = list(
		za_family = function() glmmTMB::nbinom2(link = "log"),
		za_description = function() "Zero-Inflated Negative Binomial",
		get_supported_testing_types_impl = function(){
			c("wald", "score", "lik_ratio", "gradient")
		}
	)
)
