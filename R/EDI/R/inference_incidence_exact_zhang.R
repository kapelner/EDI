ExactZhangIncidenceSource = list(
	public = list(
		#' @description Initialize exact Zhang combined-test incidence inference.
		#'   Requires \code{des_obj} to be Bernoulli-capable or
		#'   matching-capable, an uncensored incidence response.
		#' @param des_obj A completed design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @return A new \code{InferenceIncidenceExactZhang} object.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the Haldane-Anscombe continuity-corrected log odds
		#'   ratio \eqn{\log\left((n_{11}+0.5)(n_{00}+0.5) /
		#'   \left((n_{10}+0.5)(n_{01}+0.5)\right)\right)} from the pooled
		#'   \eqn{2\times2} table across all subjects (matched and reservoir
		#'   combined) — see class documentation for the full combined-test model.
		#' @param estimate_only Ignored for this estimator (the exact statistic is
		#'   always cheap to compute; there is no separate variance step to skip).
		#' @return The treatment estimate.
		compute_estimate = function(estimate_only = FALSE){
			stats = zhang_get_exact_stats(self)
			zhang_incid_treatment_estimate(stats)
		},
		#' @description Computes an exact confidence interval for the log odds
		#'   ratio by bisection-inverting the combined matched-pairs +
		#'   Fisher-exact p-value (see class documentation for the full
		#'   combination methodology).
		#' @param alpha Significance level.
		#' @param pval_epsilon Bisection tolerance for the inversion routine.
		#' @param type Exact inference type; only \code{"Zhang"} (the default) is supported.
		#' @param args_for_type Optional arguments keyed by exact type; recognizes
		#'   \code{combination_method} (\code{"Fisher"} (default), \code{"Stouffer"},
		#'   or \code{"min_p"}) inside the \code{"Zhang"} entry.
		#' @return A confidence interval.
		compute_exact_confidence_interval = function(alpha = 0.05, pval_epsilon = 0.005, type = NULL, args_for_type = NULL){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				assertNumeric(pval_epsilon, lower = .Machine$double.xmin, upper = 1)
			}
			exact_type = private$resolve_exact_type(type)
			exact_args = private$normalize_exact_inference_args(
				exact_type,
				args_for_type = args_for_type,
				pval_epsilon = pval_epsilon
			)
			private$compute_exact_confidence_interval_by_type(exact_type, alpha, exact_args)
		}
	),
	private = list(
		default_exact_type = "Zhang",
		supports_bayesian_bootstrap = function() FALSE,
		resolve_exact_type = function(type){
			if (is.null(type)) type = private$default_exact_type
			if (should_run_asserts()) {
				assertChoice(type, c("Zhang"))
			}
			type
		},
		normalize_exact_inference_args = function(type, args_for_type = NULL, pval_epsilon = NULL){
			zhang_normalize_exact_inference_args(type, args_for_type = args_for_type, pval_epsilon = pval_epsilon)
		},
		assert_exact_inference_params = function(type, args_for_type){
			zhang_assert_exact_inference_params(self, type, args_for_type)
		},
		compute_exact_confidence_interval_by_type = function(type, alpha, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Zhang = zhang_ci_exact_combined(
					self,
					alpha = alpha,
					pval_epsilon = args_for_type[[type]]$pval_epsilon,
					combination_method = args_for_type[[type]]$combination_method
				)
			)
		},
		compute_exact_two_sided_pval_for_treatment_effect_by_type = function(type, delta, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Zhang = zhang_pval_exact_combined(
					self,
					delta_0 = delta,
					combination_method = args_for_type[[type]]$combination_method
				)
			)
		}
	)
)

#' Exact Zhang Combined-Test Incidence Inference
#'
#' Performs exact inference for a binary (incidence) outcome that
#' \strong{combines} two exact component tests when the design has both
#' matched-pair and reservoir (unmatched) subjects — an internal-to-this-package
#' method (not drawn from external literature) analogous in spirit to
#' \code{\link[EDI:InferenceIncidExactBinomial]{InferenceIncidExactBinomial}}
#' (matched pairs) and \code{\link[EDI:InferenceIncidExactFisher]{InferenceIncidExactFisher}}
#' (unmatched 2x2 table), fused into one combined exact test rather than a
#' Wald-style variance combination. The point estimate is always the
#' Haldane-Anscombe continuity-corrected log odds ratio \eqn{\log\left((n_{11} +
#' 0.5)(n_{00} + 0.5) / \left((n_{10}+0.5)(n_{01}+0.5)\right)\right)} from the
#' pooled \eqn{2\times2} table across all subjects (matched and reservoir
#' together). For \strong{p-values} and \strong{confidence intervals}, the two
#' subsets are tested separately (an exact matched-pairs binomial test, as in
#' \code{InferenceIncidExactBinomial}, on discordant pairs; an exact Fisher test
#' on the reservoir \eqn{2\times2} table, as in \code{InferenceIncidExactFisher}),
#' and their p-values are combined via \code{combination_method}: \code{"Fisher"}
#' (default; \eqn{-2(\log p_M + \log p_R) \sim \chi^2_4} under independence),
#' \code{"Stouffer"} (averaged z-scores), or \code{"min_p"} (Šidák-style
#' \eqn{1-(1-\min(p_M,p_R))^2}). If only one of the two subsets is informative
#' (e.g. a pure-Bernoulli design with no matching, or no discordant pairs), the
#' combined p-value degenerates to that one component's p-value. Confidence
#' intervals are obtained by numerically inverting (bisection) the combined
#' p-value as a function of the hypothesized log odds ratio, starting from a
#' normal-approximation (Haldane-Anscombe MLE) interval as the search bracket.
#' Requires a Bernoulli-capable or matching-capable design.
#'
#' @examples
#' \dontrun{
#' # Example for InferenceIncidenceExactZhang
#' }
#' @name InferenceIncidenceExactZhang
#' @export
InferenceIncidenceExactZhang = define_inference_class(
	classname = "InferenceIncidenceExactZhang",
	inherit = Inference,
	components = "ExactZhangIncidence",
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = "compute_exact_confidence_interval",
		private = c(
			"default_exact_type",
			"resolve_exact_type",
			"normalize_exact_inference_args",
			"assert_exact_inference_params",
			"compute_exact_confidence_interval_by_type",
			"compute_exact_two_sided_pval_for_treatment_effect_by_type"
		)
	)
)
