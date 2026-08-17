KKMeanDifferenceIVWCSource = list(
	public = list(
		#' @description Initialize KK IVWC mean-difference inference.
		#' @param des_obj A KK matching-on-the-fly design object.
		#' @param verbose Whether to print progress messages.
		#' @param harden Whether to use hardened model-matrix fitting.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			super$initialize(
				des_obj = des_obj,
				verbose = verbose,
				harden = harden,
				model_formula = model_formula,
				smart_cold_start_default = smart_cold_start_default
			)
			private$init_kk_passthrough(des_obj)
		},
		#'
		#' @description Computes the compound IVWC (inverse-variance-weighted
		#' compound) mean-difference point estimate \eqn{\hat\beta_T}: the
		#' inverse-variance-weighted combination \eqn{w^* \bar d + (1-w^*)\, \bar
		#' r} of the matched-pair mean within-pair difference \eqn{\bar d} and the
		#' reservoir treated-minus-control mean difference \eqn{\bar r}, falling
		#' back to whichever of the two is usable if the other is not (see
		#' \code{$compute_asymp_confidence_interval()} for the full weighting
		#' formula and usability conditions).
		#'
		#' @return  The setting-appropriate (see description) numeric estimate of the treatment effect
		#'
		#' @param estimate_only If \code{TRUE}, compute only the point estimate
		#'   \eqn{\hat\beta_T} and skip the variance-component computations needed
		#'   for confidence intervals or p-values (faster when only the point
		#'   estimate is needed).
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Computes a \eqn{1-\alpha} level frequentist confidence interval
		#' for the compound IVWC (inverse-variance-weighted compound) mean-difference
		#' estimator \eqn{\hat\beta_T}.
		#'
		#' @details
		#' The point estimate combines two sub-estimates depending on which are
		#' usable: the mean within-pair difference among matched subjects,
		#' \eqn{\bar d}, with estimated variance \eqn{\widehat{\mathrm{Var}}(\bar
		#' d)}, and the treated-minus-control difference in means among reservoir
		#' (unmatched) subjects, \eqn{\bar r}, with estimated variance
		#' \eqn{\widehat{\mathrm{Var}}(\bar r)}. When both are usable (at least 2
		#' matched pairs and at least 2 treated/2 control reservoir subjects, with
		#' finite positive variance estimates), they are combined by classical
		#' inverse-variance weighting,
		#' \deqn{\hat\beta_T = w^* \bar d + (1 - w^*)\, \bar r, \qquad w^* =
		#'   \frac{\widehat{\mathrm{Var}}(\bar r)}{\widehat{\mathrm{Var}}(\bar r) +
		#'   \widehat{\mathrm{Var}}(\bar d)},}
		#' with combined variance the standard inverse-variance-pooled form
		#' \eqn{\widehat{\mathrm{Var}}(\hat\beta_T) = \left(\widehat{\mathrm{Var}}(\bar
		#' r)^{-1} + \widehat{\mathrm{Var}}(\bar d)^{-1}\right)^{-1} =
		#' \widehat{\mathrm{Var}}(\bar r)\,\widehat{\mathrm{Var}}(\bar d) \big/
		#' \left(\widehat{\mathrm{Var}}(\bar r) + \widehat{\mathrm{Var}}(\bar
		#' d)\right)}. If only one of the two sub-estimates is usable (e.g. the
		#' reservoir is empty or degenerate, or no pairs matched), \eqn{\hat\beta_T}
		#' and its variance fall back to that sub-estimate alone. The compound
		#' estimator is treated as asymptotically normal, so the interval is
		#' \eqn{\hat\beta_T \pm z_{1-\alpha/2}\sqrt{\widehat{\mathrm{Var}}(\hat\beta_T)}}
		#' (or a \eqn{t}-based critical value, depending on
		#' \code{private$compute_z_or_t_ci_from_s_and_df}'s degrees-of-freedom
		#' resolution).
		#'
		#' @param alpha The confidence level in the computed confidence
		#'   interval is 1 - \code{alpha}. The default is 0.05.
		#'
		#' @return  A (1 - alpha)-sized frequentist confidence interval for the treatment effect
		#'
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
			}
			if (is.null(private$cached_values$s_beta_hat_T)){
				private$shared()
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided \strong{Wald} p-value for the compound
		#' IVWC mean-difference estimator \eqn{\hat\beta_T} testing
		#' \eqn{H_0: \beta_T = \code{delta}}, using the same asymptotically-normal
		#' point estimate and standard error (\eqn{z = (\hat\beta_T -
		#' \code{delta})/\widehat{\mathrm{SE}}(\hat\beta_T)}) that
		#' \code{$compute_asymp_confidence_interval()} inverts to form its interval
		#' — see that method's documentation for the full inverse-variance-weighted
		#' combination formula. This class has no likelihood tier
		#' (\code{likelihood_tier = "none"}), so no score, likelihood-ratio, or
		#' gradient test is available here; this is a plain Wald test, not a
		#' likelihood-backed one.
		#'
		#' @param delta   The null difference to test against. For any treatment effect at all this is
		#'   set to zero (the default).
		#'
		#' @return  The approximate frequentist p-value
		#'
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			if (is.null(private$cached_values$s_beta_hat_T)){
				private$shared()
			}
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		# Randomization CI is provided by RandomizationCI.
		NULL
	),
	private = list(
		compute_fast_bootstrap_distr = function(B, i_reservoir, n_reservoir, m, y, w, m_vec) {
			# Only safe for simple additive/linear combinations right now.
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			n = length(y)
			y_mat = matrix(0.0, nrow = n, ncol = B)
			w_mat = matrix(0L, nrow = n, ncol = B)
			m_mat = matrix(0L, nrow = n, ncol = B)
			for (b in 1:B) {
				# Resample reservoir with replacement
				i_reservoir_b = sample(i_reservoir, n_reservoir, replace = TRUE)
				# For matched pairs, sample which pairs to include (with replacement)
				if (m > 0) {
					pairs_to_include = sample_int_replace_cpp(m, m)
					i_matched_b = integer(0)
					m_vec_b_matched = integer(0)
					for (new_pair_id in 1:m) {
						original_pair_id = pairs_to_include[new_pair_id]
						pair_indices = which(m_vec == original_pair_id)
						i_matched_b = c(i_matched_b, pair_indices)
						m_vec_b_matched = c(m_vec_b_matched, new_pair_id, new_pair_id)
					}
				} else {
					i_matched_b = integer(0)
					m_vec_b_matched = integer(0)
				}
				# Combine reservoir and matched indices
				i_b = c(i_reservoir_b, i_matched_b)
				y_mat[, b] = y[i_b]
				w_mat[, b] = w[i_b]
				m_mat[, b] = c(rep(0L, n_reservoir), m_vec_b_matched)
			}
			res = compute_matching_compound_bootstrap_parallel_cpp(
				w_mat,
				m_mat,
				y_mat,
				private$n_cpp_threads(ncol(y_mat))
			)
			return(res)
		},
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps) {
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			if (delta != 0) return(NULL)
			n = length(y)
			w_mat = as.matrix(permutations$w_mat)
			storage.mode(w_mat) = "integer"
			m_mat = permutations$m_mat
			if (is.null(m_mat)) {
				m_mat = matrix(0L, nrow = n, ncol = ncol(w_mat))
			} else {
				m_mat = as.matrix(m_mat)
				m_mat[is.na(m_mat)] = 0L
				storage.mode(m_mat) = "integer"
			}
			res = compute_matching_compound_distr_parallel_cpp(
				as.numeric(y),
				w_mat,
				m_mat,
				private$n_cpp_threads(ncol(w_mat))
			)
			return(res)
		},
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			
			if (is.null(private$cached_values$KKstats)) private$compute_basic_match_data()
			if (is.null(private$cached_values$KKstats$d_bar)) private$compute_reservoir_and_match_statistics()
			
			KKstats = private$cached_values$KKstats
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			m = KKstats$m
			reservoir_unusable = !is.finite(nRT) || !is.finite(nRC) || nRT <= 1 || nRC <= 1
			no_matches = !is.finite(m) || m <= 1
			
			if (is.null(private$cached_values$beta_hat_T)){
				has_matched_est = is.finite(KKstats$d_bar)
				has_reservoir_est = is.finite(KKstats$r_bar)
				private$cached_values$beta_hat_T =
					if (reservoir_unusable && has_matched_est){
						KKstats$d_bar
					} else if (no_matches && has_reservoir_est){
						KKstats$r_bar
					} else if (has_matched_est && has_reservoir_est){
						KKstats$w_star * KKstats$d_bar + (1 - KKstats$w_star) * KKstats$r_bar #proper weighting
					} else if (has_reservoir_est){
						KKstats$r_bar
					} else if (has_matched_est){
						KKstats$d_bar
					} else {
						NA_real_
					}
			}

			if (estimate_only) return(invisible(NULL))
			
			if (is.null(private$cached_values$KKstats$ssqD_bar)) private$compute_reservoir_and_match_statistics()
			ssqD = private$cached_values$KKstats$ssqD_bar
			ssqR = private$cached_values$KKstats$ssqR
			
			private$cached_values$s_beta_hat_T =
				if (reservoir_unusable){
					# Only matched pairs are usable; fall back to ssqR if ssqD is degenerate
					if (is.finite(ssqD) && ssqD > 0) sqrt(ssqD) else if (is.finite(ssqR) && ssqR > 0) sqrt(ssqR) else NA_real_
				} else if (no_matches){
					# No matched pairs
					if (is.finite(ssqR) && ssqR > 0) sqrt(ssqR) else NA_real_
				} else {
					# Combined: require both components to be positive and finite.
					if (!is.finite(ssqD) || ssqD <= 0) {
						if (is.finite(ssqR) && ssqR > 0) sqrt(ssqR) else NA_real_
					} else if (!is.finite(ssqR) || ssqR <= 0) {
						sqrt(ssqD)
					} else {
						sqrt(ssqR * ssqD / (ssqR + ssqD))
					}
				}
		}
	)
)

KKMeanDifferenceIVWCSource$public = Filter(Negate(is.null), KKMeanDifferenceIVWCSource$public)

#' Mean-Difference IVWC Inference for KK Matching-on-the-Fly Designs
#'
#' Fits a compound (inverse-variance-weighted combination, "IVWC") mean-difference
#' estimator of the treatment effect for continuous responses under a
#' \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}}-family KK matching-on-the-fly
#' design (see \code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} and
#' \code{\link[EDI:DesignSeqOneByOneKK21]{DesignSeqOneByOneKK21}}). Such a design
#' produces two structurally different kinds of subjects: subjects successfully
#' matched into pairs during the sequential design, and unmatched "reservoir"
#' subjects randomized independently. This estimator combines both:
#' \deqn{\hat\beta_T = w^* \bar d + (1 - w^*)\, \bar r, \qquad
#'   w^* = \frac{\widehat{\mathrm{Var}}(\bar r)}{\widehat{\mathrm{Var}}(\bar r) +
#'   \widehat{\mathrm{Var}}(\bar d)},}
#' where \eqn{\bar d} is the mean within-pair (treated minus control) difference
#' among matched subjects and \eqn{\bar r} is the treated-minus-control difference
#' in means among reservoir subjects, weighted inversely by their estimated
#' variances (see \code{$compute_asymp_confidence_interval()} for the full
#' variance formula and the fallback behavior when only one of the two
#' sub-estimates is usable). Inference is Wald-only: this class has no
#' likelihood tier (\code{likelihood_tier = "none"}) and provides asymptotic
#' Wald, randomization, and bootstrap (including Bayesian bootstrap) confidence
#' intervals and p-values, but no score/likelihood-ratio/gradient tests.
#'
#' @references Kapelner, A., and Krieger, A. M. (2014). "Matching on-the-fly:
#'   Sequential allocation with higher power and efficiency." \emph{Biometrics},
#'   70(2), 378-388, \doi{10.1111/biom.12148}, for the KK matching-on-the-fly
#'   design this estimator targets, and for the inverse-variance combination of
#'   matched-pair and reservoir estimates.
#'
#' @section Legacy status: \strong{Legacy class.} Not fully tested in
#'   \code{comprehensive_tests.R}; prefer a more actively maintained KK
#'   continuous-response inference class (e.g.
#'   \code{\link[EDI:InferenceContinKKOLSIVWC]{InferenceContinKKOLSIVWC}}) for new
#'   analyses unless this specific unadjusted mean-difference estimator is
#'   required.
#' @export
#' @examples
#' \dontrun{
#' seq_des = DesignSeqOneByOneKK14$new(n = 6, response_type = "continuous")
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[1, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[2, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[3, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[4, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[5, 2 : 10])
#' seq_des$add_one_subject_to_experiment_and_assign(MASS::biopsy[6, 2 : 10])
#' seq_des$add_all_subject_responses(c(4.71, 1.23, 4.78, 6.11, 5.95, 8.43))
#'
#' seq_des_inf = InferenceAllKKMeanDiffIVWC$
#'   new(seq_des)
#' seq_des_inf$compute_estimate()
#' seq_des_inf$compute_asymp_confidence_interval()
#' seq_des_inf$compute_asymp_two_sided_pval()
#' }
#' @name InferenceAllKKMeanDiffIVWC
InferenceAllKKMeanDiffIVWC = define_inference_class(
	classname = "InferenceAllKKMeanDiffIVWC",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "KKMeanDifferenceIVWC"),
	public = list(
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval
	),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"supports_likelihood_tests",
			"compute_basic_match_data",
			"compute_fast_bootstrap_distr",
			"compute_fast_randomization_distr",
			"shared"
		)
	)
)
