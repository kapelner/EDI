#' Zero-Inflated Poisson Regression Inference for Count Responses
#'
#' Fits a zero-inflated Poisson regression for count responses: a binary
#' excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' Poisson count submodel \eqn{\log E[Y_i \mid \text{not structural zero},
#' W_i, X_i] = \beta_0 + \beta_T W_i + X_i^\top \gamma}. Unlike a hurdle
#' model, zero counts can arise from either the structural-zero mechanism or
#' from an ordinary Poisson draw of \eqn{0}, so the two mixture components are
#' not identified by disjoint support. The hurdle and count submodels may use
#' different covariate formulas (\code{model_formula}/\code{model_formula_zero}).
#' The reported treatment effect is the coefficient from the conditional count
#' component, on the log-rate scale, \strong{conditional on the response
#' coming from the count process, not the excess-zero-inflation mechanism}:
#' it is not the effect on the unconditional mean \eqn{E[Y]}, which also
#' depends on how treatment shifts the excess-zero probability. A marginal
#' (unconditional-mean) estimand is not yet implemented for this class (see
#' \code{marginal_estimand_report.md}). \code{likelihood_tier = "full"}:
#' Wald, gradient, and (bootstrap-calibrated) likelihood-ratio tests are
#' available for the count submodel's treatment coefficient; a plain score
#' test is not exposed. \strong{Jackknife inference is not supported}:
#' delete-one refits of this two-part mixture model are numerically
#' unstable, so \code{compute_jackknife_estimate()} and related methods
#' report explicit non-estimability rather than attempting delete-one
#' refits.
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
#'   for the overdispersion-robust negative-binomial variant.
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
InferenceCountZeroInflatedPoisson = R6::R6Class("InferenceCountZeroInflatedPoisson",
	lock_objects = FALSE,
	inherit = InferenceCountZeroAugmentedPoissonAbstract,
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
		}
	),
	private = list(
		za_family = function() stats::poisson(link = "log"),
		za_description = function() "Zero-Inflated Poisson"
	)
)
#' Zero-Inflated Negative Binomial Regression Inference for Count Responses
#'
#' Fits a zero-inflated negative binomial regression for count responses: a
#' binary excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' negative-binomial count submodel \eqn{\log E[Y_i \mid \text{not structural
#' zero}, W_i, X_i] = \beta_0 + \beta_T W_i + X_i^\top \gamma},
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
