#' Conditional Logistic Regression Inference for KK Designs (IVWC Variant)
#'
#' Fits a conditional logistic regression to the \strong{discordant matched
#' pairs} of an incidence response under a KK matching-on-the-fly design: for a
#' pair whose two outcomes differ, the likelihood is
#' \eqn{P(\mathrm{treated\ member\ is\ the\ success}) =
#' \mathrm{logistic}(\beta_T + \beta_x^\top(x_T - x_C))}. The pair's own
#' intercept cancels, so no assumption is made about how outcomes vary between
#' pairs. Concordant pairs carry no information under this model and reservoir
#' (unmatched) subjects are not used (\code{private$combine_reservoir_into_glmm()
#' == FALSE}). The returned estimate is the conditional log odds ratio
#' \eqn{\beta_T}. Contrast with
#' \code{\link[EDI:InferenceIncidKKCondLogitGLMMOneLik]{InferenceIncidKKCondLogitGLMMOneLik}},
#' which adds the reservoir subjects through a logistic regression term sharing
#' the same coefficients.
#'
#' Up to v1.0.4 the concordant pairs (and, for the OneLik variant, the
#' reservoir) entered a random-intercept logistic GLMM. Concordant pairs agree
#' on outcome by definition, so with pairs grouped correctly the
#' random-intercept variance estimate diverges, the GLMM term stops depending
#' on the coefficients, and the fit reduces to conditional logit (it was often
#' reported nonestimable at the variance bound). Under a free pair effect a
#' concordant pair's conditional likelihood is 1, so dropping them loses no
#' information. The class name is kept for compatibility; \code{max_abs_log_sigma}
#' is accepted but unused.
#'
#' \strong{Legacy class.} Not fully tested in \code{comprehensive_tests.R}.
#' See \code{\link[EDI:InferenceAbstractKKCondLogitGLMM]{InferenceAbstractKKCondLogitGLMM}}'s
#' known estimability limitation at high covariate counts, which applies here
#' too.
#'
#' @examples
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidKKCondLogitGLMMIVWC$new(seq_des)
#' inf$compute_estimate()
#' @export
InferenceIncidKKCondLogitGLMMIVWC = R6::R6Class("InferenceIncidKKCondLogitGLMMIVWC",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
	),
	private = list(
		combine_reservoir_into_glmm = function() FALSE,
		uses_reservoir_logit = function() TRUE
	)
)

#' Conditional Logistic Plus Reservoir Logistic Inference for KK Designs
#'
#' Fits one likelihood for an incidence response under a KK
#' matching-on-the-fly design, made of two parts that share the treatment
#' coefficient \eqn{\beta_T} and the covariate coefficients \eqn{\beta_x}:
#' \itemize{
#'   \item \strong{Discordant matched pairs:} conditional logit,
#'     \eqn{P(\mathrm{treated\ member\ is\ the\ success}) =
#'     \mathrm{logistic}(\beta_T + \beta_x^\top(x_T - x_C))}. The pair's own
#'     intercept cancels. Concordant pairs carry no information under this
#'     model and are left out.
#'   \item \strong{Reservoir (unmatched) subjects:} ordinary logistic
#'     regression, \eqn{\mathrm{logit}\,P(y = 1) = \alpha + \beta_T w +
#'     \beta_x^\top x}, with its own intercept \eqn{\alpha}
#'     (\code{private$combine_reservoir_into_glmm() == TRUE}).
#' }
#' The two parts are independent (disjoint subjects; KK matching depends on
#' covariates, not on a subject's own outcome), so their log-likelihoods add.
#' The joint maximum is one logistic regression on stacked rows, and Wald,
#' score, gradient and likelihood-ratio inference use its ordinary
#' information. When the reservoir's outcomes do not vary, its intercept
#' estimate is infinite and it carries no information about the coefficients,
#' so it is left out and the fit is conditional logit alone. With
#' \code{DesignFixedBinaryMatch} (no reservoir) this class equals
#' \code{\link[EDI:InferenceIncidKKCondLogitGLMMIVWC]{InferenceIncidKKCondLogitGLMMIVWC}}.
#'
#' \strong{Caveat: two estimands are pooled.} Conditional logit estimates a
#' pair-conditional log odds ratio. Logistic regression on the reservoir
#' estimates a log odds ratio given only the modelled covariates. Because the
#' odds ratio is non-collapsible, these are the same number only if the linear
#' logistic model in \eqn{x} is correct, i.e. no outcome-relevant variation is
#' left between pairs beyond what \eqn{\beta_x^\top x} explains. With residual
#' pair-level heterogeneity of standard deviation \eqn{\sigma}, the reservoir's
#' coefficient is attenuated toward zero, roughly
#' \eqn{\beta_{cond} / \sqrt{1 + 0.35\sigma^2}} (Zeger, Liang and Albert,
#' 1988). The joint estimate is then a precision-weighted mix of two different
#' estimands. The test of no treatment effect is unaffected: under
#' \eqn{H_0: \beta_T = 0} with randomized treatment both parts are centred at
#' zero even when the logistic model in \eqn{x} is wrong. KK reservoir
#' subjects are the ones that found no close match, so they tend to lie in
#' sparse regions of \eqn{x}, where a linear logistic model is most likely to
#' be wrong. The reservoir is usually a small share of \eqn{n}, so its weight
#' in the pooled estimate is usually small.
#'
#' Up to v1.0.4 the concordant pairs (and, for the OneLik variant, the
#' reservoir) entered a random-intercept logistic GLMM. Concordant pairs agree
#' on outcome by definition, so with pairs grouped correctly the
#' random-intercept variance estimate diverges, the GLMM term stops depending
#' on the coefficients, and the fit reduces to conditional logit (it was often
#' reported nonestimable at the variance bound). Under a free pair effect a
#' concordant pair's conditional likelihood is 1, so dropping them loses no
#' information. The class name is kept for compatibility; \code{max_abs_log_sigma}
#' is accepted but unused.
#'
#' See \code{\link[EDI:InferenceAbstractKKCondLogitGLMM]{InferenceAbstractKKCondLogitGLMM}}'s
#' known estimability limitation at high covariate counts, which applies
#' here too.
#'
#' @references Zeger, S. L., Liang, K.-Y. and Albert, P. S. (1988). Models for
#'   longitudinal data: a generalized estimating equation approach.
#'   \emph{Biometrics}, 44(4), 1049--1060.
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
#' @eval rd_small_sample_section("InferenceIncidKKCondLogitGLMMOneLik")
#' @export
InferenceIncidKKCondLogitGLMMOneLik = R6::R6Class("InferenceIncidKKCondLogitGLMMOneLik",
	lock_objects = FALSE,
	inherit = InferenceAbstractKKCondLogitGLMM,
	public = list(
		#' @description Initialize inference for the conditional-logit
		#'   (discordant matched pairs) plus logistic-regression (reservoir
		#'   subjects) incidence model; see
		#'   \code{\link[EDI:InferenceIncidKKCondLogitGLMMOneLik]{InferenceIncidKKCondLogitGLMMOneLik}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an incidence response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param max_abs_reasonable_coef Cap for reasonable coefficient estimates.
		#' @param max_abs_reasonable_se Cap for reasonable treatment standard errors.
		#' @param max_abs_log_sigma Unused since v1.0.5 (the model has no random
		#'   effect); accepted for compatibility.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart optimizer start values.
		#' @param optimization_alg Character. Optimization algorithm (default "lbfgs").
		initialize = function(des_obj, model_formula = NULL, max_abs_reasonable_coef = 50, max_abs_reasonable_se = 1.25, max_abs_log_sigma = 8, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, max_abs_reasonable_coef = max_abs_reasonable_coef, max_abs_reasonable_se = max_abs_reasonable_se, max_abs_log_sigma = max_abs_log_sigma, verbose = verbose, smart_cold_start_default = smart_cold_start_default, optimization_alg = optimization_alg)
		}
	),
	private = list(
		combine_reservoir_into_glmm = function() TRUE,
		uses_reservoir_logit = function() TRUE
	)
)
