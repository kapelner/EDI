#' Exact Zhang incidence component source
#'
#' Source list for the exact Zhang incidence component.
#'
#' @keywords internal
ExactZhangIncidenceSource = list(
	public = list(
		# Initialize exact Zhang combined-test incidence inference.
		# Documented via @R6method below (see InferenceIncidExactZhang$initialize).
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
				stop_if_design_incompatible(private$design_compatibility_reason, des_obj, list(
					exact_zhang_requires_bernoulli_or_matching_design = "Zhang incidence inference requires Bernoulli or matching designs."
				))
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		# Computes the exact-Zhang estimate. Documented via @R6method
		# below (see InferenceIncidExactZhang$compute_estimate).
		compute_estimate = function(estimate_only = FALSE){
			# Pooled table over all subjects, as documented (v1.0.6-TODO-147); the
			# reservoir-only table gave 0 whenever every subject was matched.
			zhang_incid_treatment_estimate(zhang_get_pooled_table(self))
		},
		# Computes an exact confidence interval for the log odds ratio.
		# Documented via @R6method below (see
		# InferenceIncidExactZhang$compute_exact_confidence_interval).
		compute_exact_confidence_interval = function(alpha = 0.05, pval_epsilon = 1e-6, type = NULL, args_for_type = NULL){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
				assertNumeric(pval_epsilon, len = 1, lower = .Machine$double.xmin, upper = 1, any.missing = FALSE)
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
		# Self/private-free so it's safe to call unbound against a candidate
		# des_obj before construction, same "safe invoke without construction"
		# contract as design_compatibility_reason() elsewhere (Wilcox/CMH/
		# ExtendedRobins/ExactBinomial/ExactFisher/PairedSignTest). Mirrors
		# zhang_assert_exact_inference_params()'s own compute-time gate
		# (`is_a_bernoulli_capable() || has_match_structure`, where
		# has_match_structure is verbatim des_obj$is_a_kk_matching_capable())
		# -- found 2026-08-21 via a user-reported run_all_inference() row on
		# an ObservationalDesignBlocks design where this class constructed
		# and estimated fine but every exact CI/p-value silently degraded to
		# NA (the compute-time stop() swallowed by the suite's tryCatch),
		# exactly the ExactFisher shape. The compute-time gate remains as
		# defense-in-depth for directly-constructed instances.
		design_compatibility_reason = function(des_obj){
			if (!isTRUE(des_obj$is_a_bernoulli_capable()) && !isTRUE(des_obj$is_a_kk_matching_capable())) {
				return("exact_zhang_requires_bernoulli_or_matching_design")
			}
			NA_character_
		},
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
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
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
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
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
#' Both component p-values are two-sided "minimum likelihood" exact p-values
#' (as in \code{stats::binom.test} and \code{stats::fisher.test}), which jump
#' wherever another outcome ties the observed one in probability, so the
#' combined p-value is not monotone in the log odds ratio and the set of values
#' the test accepts can have gaps. The confidence interval is the convex hull
#' of that set: the smallest interval containing every log odds ratio whose
#' combined p-value is at least \code{alpha}. This is the usual convention for
#' inverting such tests (Blaker 2000; Fay 2010); it can be slightly
#' conservative, and it keeps the interval consistent with the test (a value
#' the test accepts is never outside the interval). An endpoint that falls on
#' one of these jumps is reported at the jump itself, where the test accepts.
#'
#' On a matching design the point estimate and the exact confidence interval
#' are different quantities: the estimate is the log odds ratio of the pooled
#' table over all subjects, while the interval inverts the combined test, which
#' uses only the discordant matched pairs and the reservoir table. The estimate
#' therefore is not guaranteed to lie inside the exact confidence interval,
#' although it usually does.
#'
#' @references
#' Blaker, H. (2000). Confidence curves and improved exact confidence intervals
#' for discrete distributions. \emph{Canadian Journal of Statistics}, 28(4),
#' 783--798. \doi{10.2307/3315916}
#'
#' Fay, M. P. (2010). Two-sided exact tests and matching confidence intervals for
#' discrete data. \emph{The R Journal}, 2(1), 53--58. \doi{10.32614/RJ-2010-008}
#'
#' @examples
#' seq_des = DesignSeqOneByOneKK14$new(n = 20, response_type = 'incidence')
#' for (i in 1:20) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(20, 1, 0.5))
#' inf = InferenceIncidExactZhang$new(seq_des)
#' inf$compute_estimate()
#' inf$compute_exact_two_sided_pval_for_treatment_effect()
#' @name InferenceIncidExactZhang
#' @eval rd_small_sample_section("InferenceIncidExactZhang")
#' @export
InferenceIncidExactZhang = define_inference_class(
	classname = "InferenceIncidExactZhang",
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

#' @R6method InferenceIncidExactZhang$initialize
#' @template exact-zhang-initialize
NULL

#' @R6method InferenceIncidExactZhang$compute_estimate
#' @template exact-zhang-compute-estimate
NULL

#' @R6method InferenceIncidExactZhang$compute_exact_confidence_interval
#' @template exact-zhang-compute-exact-confidence-interval
NULL
