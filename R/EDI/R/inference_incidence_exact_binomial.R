ExactBinomialIncidenceSource = list(
	public = list(
		#' @description Initialize exact matched-pair binomial inference for
		#'   incidence outcomes. Requires \code{des_obj} to be
		#'   \code{DesignFixedBinaryMatch} or a KK matching-on-the-fly-capable
		#'   design; errors otherwise. Requires an uncensored incidence response.
		#' @param des_obj A completed design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @return A new \code{InferenceIncidExactBinomial} object.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			if (!private$design_supports_exact_binomial()) {
				stop("Exact binomial incidence inference requires DesignFixedBinaryMatch or KK matching designs.")
			}
			# Unconditional: ensure_matching_structure_computed() is a no-op by default
			# (DesignMatching's base implementation) and only DesignFixedBinaryMatch
			# overrides it with real (lazy) work, so calling it here for every
			# exact-binomial-eligible design (already asserted above) is
			# behavior-preserving and avoids a DesignFixedBinaryMatch class-identity
			# check (fix_design_hierarchy.md, "Class-Identity Dispatch Replacement").
			private$des_obj_priv_int$ensure_matching_structure_computed()
		},
		#' @description Computes the Haldane-Anscombe continuity-corrected
		#'   matched-pair log odds ratio \eqn{\log\left((d_+ + 0.5)/(d_- + 0.5)\right)}
		#'   from the discordant matched-pair counts (see class documentation for
		#'   the full model). \code{NA} if there are no matched pairs.
		#' @param estimate_only Ignored for this estimator (the exact statistic is
		#'   always cheap to compute; there is no separate variance step to skip).
		#' @return The treatment estimate.
		compute_estimate = function(estimate_only = FALSE){
			private$get_exact_binomial_log_or_estimate()
		}
	),
	private = list(
		default_exact_type = "Binomial",
		resolve_exact_type = function(type){
			if (is.null(type)) type = private$default_exact_type
			if (should_run_asserts()) {
				assertChoice(type, c("Binomial"))
			}
			type
		},
		normalize_exact_inference_args = function(type, args_for_type = NULL){
			if (should_run_asserts()) {
				assertChoice(type, c("Binomial"))
				assertList(args_for_type, null.ok = TRUE)
			}
			utils::modifyList(setNames(list(list()), type), if (is.null(args_for_type)) list() else args_for_type)
		},
		assert_exact_inference_params = function(type, args_for_type){
			if (should_run_asserts()) {
				assertChoice(type, c("Binomial"))
				assertList(args_for_type)
				if (!(type %in% names(args_for_type))) stop("args_for_type must contain a list for ", type)
			}
			args = args_for_type[[type]]
			if (should_run_asserts()) {
				assertList(args)
				assertResponseType(private$des_obj$get_response_type(), "incidence")
				assertNoCensoring(private$any_censoring)
			}
			if (!private$design_supports_exact_binomial()) {
				stop("Exact binomial incidence inference requires DesignFixedBinaryMatch or KK matching designs.")
			}
			stats = private$get_exact_binomial_stats()
			if (should_run_asserts()) {
				if (stats$m <= 0L) {
					stop("Exact binomial incidence inference requires at least one matched pair.")
				}
				if (stats$d_plus + stats$d_minus <= 0L) {
					stop("Exact binomial incidence inference requires at least one discordant matched pair.")
				}
			}
			invisible(args)
		},
		compute_exact_confidence_interval_by_type = function(type, alpha, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Binomial = private$ci_exact_binomial(alpha)
			)
		},
		compute_exact_two_sided_pval_for_treatment_effect_by_type = function(type, delta, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Binomial = private$pval_exact_binomial(delta)
			)
		},
		design_supports_exact_binomial = function(){
			private$des_obj$is_a_kk_matching_capable()
		},
		pval_exact_binomial = function(delta_0){
			stats = private$get_exact_binomial_stats()
			if (stats$m <= 0L) {
				private$cache_nonestimable_estimate("exact_binomial_no_matched_pairs")
				return(NA_real_)
			}
			if (stats$d_plus + stats$d_minus <= 0L) {
				return(1)
			}
			zhang_exact_binom_pval_cpp(stats$d_plus, stats$d_minus, delta_0)
		},
		ci_exact_binomial = function(alpha){
			stats = private$get_exact_binomial_stats()
			d_total = stats$d_plus + stats$d_minus
			if (d_total <= 0L) {
				private$cache_nonestimable_estimate("exact_binomial_no_discordant_pairs")
				ci = c(NA_real_, NA_real_)
				names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
				return(ci)
			}
			ci_prob = stats::binom.test(stats$d_plus, d_total, conf.level = 1 - alpha)$conf.int
			ci = stats::qlogis(ci_prob)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		get_exact_binomial_log_or_estimate = function(){
			stats = private$get_exact_binomial_stats()
			if (stats$m <= 0L) {
				private$cache_nonestimable_estimate("exact_binomial_no_matched_pairs")
				return(NA_real_)
			}
			log((stats$d_plus + 0.5) / (stats$d_minus + 0.5))
		},
		get_exact_binomial_stats = function(){
			if (!is.null(private$cached_values$incidence_exact_binomial_stats)) {
				return(private$cached_values$incidence_exact_binomial_stats)
			}
			# Unconditional: ensure_matching_structure_computed() is a no-op by default
			# (DesignMatching's base implementation) and only DesignFixedBinaryMatch
			# overrides it with real (lazy) work, so calling it here is
			# behavior-preserving and avoids a DesignFixedBinaryMatch class-identity
			# check (fix_design_hierarchy.md, "Class-Identity Dispatch Replacement").
			private$des_obj_priv_int$ensure_matching_structure_computed()
			m_vec = private$des_obj_priv_int$m
			if (is.null(m_vec) || length(m_vec) == 0L) {
				stop("Matching structure is unavailable for exact binomial incidence inference.")
			}
			m_vec = as.integer(m_vec)
			m_vec[is.na(m_vec)] = 0L
			KKstats = compute_zhang_match_data_cpp(private$get_X(), private$y, private$w, m_vec)
			stats = list(
				m = as.integer(KKstats$m),
				d_plus = as.integer(KKstats$d_plus),
				d_minus = as.integer(KKstats$d_minus)
			)
			private$cached_values$incidence_exact_binomial_stats = stats
			stats
		}
	)
)

#' Exact Binomial (McNemar-Type) Incidence Inference for Matched-Pair Designs
#'
#' Performs exact matched-pair inference for binary (incidence) outcomes using
#' only \strong{discordant} matched pairs — pairs where the treated and control
#' member's outcomes differ — the same reduction classical McNemar's test makes.
#' Writing \eqn{d_+} for the count of discordant pairs where the treated
#' subject had the event and the control did not, and \eqn{d_-} for the reverse,
#' the point estimate is the Haldane-Anscombe continuity-corrected log odds
#' ratio \eqn{\log\left((d_+ + 0.5)/(d_- + 0.5)\right)}; the confidence interval
#' inverts the exact (Clopper-Pearson) binomial confidence interval for
#' \eqn{d_+ / (d_+ + d_-)} against \eqn{1/2} (via \code{stats::binom.test}) onto
#' the log-odds scale; and the two-sided p-value is an exact binomial test of
#' \eqn{d_+} vs. \eqn{d_-} (via \code{zhang_exact_binom_pval_cpp}) against a
#' null log odds ratio. This class is available for
#' \code{DesignFixedBinaryMatch} and KK matching-on-the-fly designs. For KK
#' designs, only the matched-pair data are used and the reservoir is ignored.
#' If there are no matched pairs, or no discordant pairs, the relevant
#' quantities are reported as non-estimable rather than as \code{NaN}/\code{Inf}.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'incidence')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rbinom(10, 1, 0.5))
#' inf = InferenceIncidExactBinomial$new(seq_des)
#' inf$compute_estimate()
#' }
#' @name InferenceIncidExactBinomial
#' @export
InferenceIncidExactBinomial = define_inference_class(
	classname = "InferenceIncidExactBinomial",
	inherit = Inference,
	components = "ExactBinomialIncidence",
	metadata = list(likelihood_tier = "none"),
	overrides = list(
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
