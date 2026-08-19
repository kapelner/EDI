#' Conditional Logistic Plus GLMM IVWC Inference for KK Designs
#'
#' Fits a combined conditional-logit-plus-random-intercept-GLMM likelihood for
#' incidence responses under a KK matching-on-the-fly design, where
#' \strong{reservoir (unmatched) subjects are excluded from the GLMM
#' component} (\code{private$combine_reservoir_into_glmm() == FALSE}): only
#' concordant matched pairs contribute their random-intercept GLMM likelihood
#' alongside the discordant-pair conditional-logit term, both sharing a single
#' treatment coefficient \eqn{\beta_T}. See
#' \code{\link[EDI:InferencePropKKGLMM]{InferencePropKKGLMM}} for the full
#' model form (conditional-logit-on-discordant plus random-intercept-GLMM,
#' jointly maximized) and
#' \code{\link[EDI:InferenceAbstractKKCondLogitGLMM]{InferenceAbstractKKCondLogitGLMM}}
#' for the shared fitting/caching contract. Contrast with the sibling
#' \code{\link[EDI:InferenceIncidKKCondLogitGLMMOneLik]{InferenceIncidKKCondLogitGLMMOneLik}},
#' which instead includes reservoir subjects in the GLMM component
#' (\code{combine_reservoir_into_glmm() == TRUE}) — this class's naming
#' ("IVWC") reflects that reservoir information, when used, is intended to be
#' combined with this fit's estimate via inverse-variance weighting rather
#' than folded into the same likelihood.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#'
#' @examples
#' \dontrun{
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidKKCondLogitGLMMIVWC$new(seq_des)
#' inf$compute_estimate()
#' }
#' }
#' @export
InferenceIncidKKCondLogitGLMMIVWC = R6::R6Class("InferenceIncidKKCondLogitGLMMIVWC",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
	),
	private = list(
		combine_reservoir_into_glmm = function() FALSE
	)
)

#' Conditional Logistic Plus GLMM Combined-Likelihood Inference for KK Designs
#'
#' Fits a combined conditional-logit-plus-random-intercept-GLMM likelihood for
#' incidence responses under a KK matching-on-the-fly design, where
#' \strong{reservoir (unmatched) subjects are included in the GLMM component}
#' (\code{private$combine_reservoir_into_glmm() == TRUE}), so all subjects
#' (discordant matched pairs, concordant matched pairs, and reservoir) enter
#' one joint likelihood with a single treatment coefficient \eqn{\beta_T}. See
#' \code{\link[EDI:InferencePropKKGLMM]{InferencePropKKGLMM}} for the full
#' model form (conditional-logit-on-discordant plus random-intercept-GLMM,
#' jointly maximized) and
#' \code{\link[EDI:InferenceAbstractKKCondLogitGLMM]{InferenceAbstractKKCondLogitGLMM}}
#' for the shared fitting/caching contract. Contrast with the sibling
#' \code{\link[EDI:InferenceIncidKKCondLogitGLMMIVWC]{InferenceIncidKKCondLogitGLMMIVWC}},
#' which excludes reservoir subjects from the GLMM component.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidKKCondLogitGLMMOneLik$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceIncidKKCondLogitGLMMOneLik = R6::R6Class("InferenceIncidKKCondLogitGLMMOneLik",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
		#' @description Initialize inference for the combined conditional-logit
		#'   (discordant matched pairs) plus random-intercept-GLMM (concordant pairs
		#'   and reservoir subjects) incidence model; see
		#'   \code{\link[EDI:InferenceIncidKKCondLogitGLMMOneLik]{InferenceIncidKKCondLogitGLMMOneLik}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param max_abs_reasonable_coef Cap for reasonable coefficient estimates.
		#' @param max_abs_reasonable_se Cap for reasonable treatment standard errors.
		#' @param max_abs_log_sigma Cap for reasonable log random effect variance.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart optimizer start values.
		#' @param optimization_alg Character. Optimization algorithm (default "lbfgs").
		initialize = function(des_obj, model_formula = NULL, max_abs_reasonable_coef = 50, max_abs_reasonable_se = 1.25, max_abs_log_sigma = 8, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, max_abs_reasonable_coef = max_abs_reasonable_coef, max_abs_reasonable_se = max_abs_reasonable_se, max_abs_log_sigma = max_abs_log_sigma, verbose = verbose, smart_cold_start_default = smart_cold_start_default, optimization_alg = optimization_alg)
		}
	),
	private = list(
		combine_reservoir_into_glmm = function() TRUE
	)
)
