#' Paired Sign Test Inference for KK Designs with Ordinal Response
#'
#' Fits the classical paired sign test for ordinal responses under a KK
#' matching-on-the-fly design. For each matched pair \eqn{i} with treated
#' member response \eqn{Y_{i,T}} and control member response \eqn{Y_{i,C}},
#' only the sign of the within-pair difference \eqn{Y_{i,T} - Y_{i,C}} is
#' used; tied pairs (\eqn{Y_{i,T} = Y_{i,C}}) are dropped from the effective
#' sample. The estimand is \eqn{\theta = P(Y_T > Y_C \mid \text{pair
#' untied})}, and the reported treatment effect is \eqn{\hat\beta_T = \hat p -
#' 0.5}, where \eqn{\hat p} is the sample proportion of untied pairs favoring
#' treatment; \eqn{\beta_T = 0} corresponds to \eqn{\theta = 0.5} (no
#' directional preference). The standard error is the usual binomial-proportion
#' formula \eqn{\sqrt{\hat p (1 - \hat p) / n_{\text{eff}}}}, where
#' \eqn{n_{\text{eff}}} is the number of untied pairs.
#' \strong{Reservoir (unmatched) subjects are not included} — this is a purely
#' within-pair test, unlike the IVWC-style classes elsewhere in the KK family
#' that combine matched-pair and reservoir information.
#' \code{likelihood_tier = "none"} (\code{supports_likelihood_tests()} is hard
#' \code{FALSE}): only Wald inference on the proportion scale is exposed.
#' Bootstrap and jackknife are deliberately unsupported and throw explicit
#' errors (see \code{approximate_bootstrap_distribution_beta_hat_T()} and
#' \code{approximate_jackknife_distribution_beta_hat_T()}), since subject-level
#' resampling or deletion would violate the matched-pair design's dependence
#' structure; randomization inference (\code{compute_rand_two_sided_pval()})
#' remains available since it permutes treatment assignment within the design's
#' own randomization mechanism rather than resampling subjects. Requires a KK
#' matching-on-the-fly design (\code{DesignSeqOneByOneKK14}/\code{KK21}) or
#' \code{DesignFixedBinaryMatch}; a design with no discordant (untied) pairs is
#' cached as nonestimable for the standard error (point estimate \code{0}) or
#' fully nonestimable, per \code{harden}.
#'
#' @references Dixon, W. J., and Mood, A. M. (1946). "The Statistical Sign
#'   Test." \emph{Journal of the American Statistical Association}, 41(236),
#'   557-566, \doi{10.2307/2280577}, for the classical paired sign test;
#'   Kapelner, A. and Krieger, A. M. (2014). "Matching on-the-fly: Sequential
#'   allocation with higher power and efficiency." \emph{Biometrics}, 70(2),
#'   378-388, \doi{10.1111/biom.12148}, for the KK matching-on-the-fly design
#'   this class is built for.
#'
#' @seealso \href{https://en.wikipedia.org/wiki/Sign_test}{Sign test}
#'   (Wikipedia).
#'
#' @export
#' @examples
#' set.seed(1)
#' x_dat <- data.frame(
#'   x1 = c(-1.2, -0.7, -0.2, 0.3, 0.8, 1.3, 1.8, 2.3),
#'   x2 = c(0, 1, 0, 1, 0, 1, 0, 1)
#' )
#' seq_des <- DesignSeqOneByOneKK21$new(n = nrow(x_dat), response_type = "ordinal",
#' verbose = FALSE)
#' for (i in seq_len(nrow(x_dat))) {
#'   seq_des$add_one_subject_to_experiment_and_assign(x_dat[i, , drop = FALSE])
#' }
#' seq_des$add_all_subject_responses(as.integer(c(1, 2, 2, 3, 3, 4, 4, 5)))
#' infer <- InferenceOrdinalPairedSignTest$
#'   new(seq_des, verbose = FALSE)
#' infer
#'
InferenceOrdinalPairedSignTest = define_inference_class("InferenceOrdinalPairedSignTest",
	inherit = Inference,
	# 2026-08-21 (fix_inference_hierarchy.md per-class migration ladders):
	# flipped from `inherit = InferenceAsympLik` (the last concrete class
	# package-wide still descending through the algorithmic-compatibility
	# ladder) to composing the rand/bootstrap chain via `BayesianBootstrap`
	# and the z/t Wald helpers via `Wald` (source `InferenceAsymp` -- this
	# class's own compute_asymp_* methods call
	# private$compute_z_or_t_{ci,two_sided_pval}_from_s_and_df directly and
	# never used any InferenceAsympLik likelihood machinery; its
	# supports_likelihood_tests() has always been FALSE).
	components = c("BayesianBootstrap", "Wald", "KKPassThrough"),
	public = list(
		#' @description Uses the shared randomization-test two-sided p-value
		#'   contract; see \code{\link[EDI:InferenceRand]{InferenceRand}}.
		#'   Pinned from plain \code{InferenceRand} (not \code{InferenceRandCI})
		#'   per the established ordinal-class precedent -- Zhang dispatch is
		#'   incidence-only.
		#' @param r Number of randomization draws.
		#' @param delta Null treatment effect.
		#' @param transform_responses Optional response transformation.
		#' @param na.rm Whether to drop non-finite draws.
		#' @param show_progress Whether to show a progress bar.
		#' @param permutations Optional pre-computed permutations.
		#' @param zero_one_logit_clamp Clamp for logit transforms.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the paired sign test on within-pair
		#'   response differences \eqn{Y_{i,T} - Y_{i,C}}; see
		#'   \code{\link[EDI:InferenceOrdinalPairedSignTest]{InferenceOrdinalPairedSignTest}}
		#'   for the model form. Requires a KK matching-on-the-fly design
		#'   (\code{DesignSeqOneByOneKK14}/\code{KK21}) or
		#'   \code{DesignFixedBinaryMatch}. Does not compute the sign-test statistic;
		#'   that is deferred to the first call to \code{compute_estimate()} or a
		#'   method that requires it.
		#' @param  des_obj  	A completed KK matching-on-the-fly design object.
		#' @param  verbose  		Whether to print progress messages.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
				stop_if_design_incompatible(private$design_compatibility_reason, des_obj, list(
					paired_sign_test_requires_matching_design = paste0(
						class(self)[1], " requires a KK matching-on-the-fly design (DesignSeqOneByOneKK14) or DesignFixedBinaryMatch."
					)
				))
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Computes the pair-sign counts (\code{pos}/\code{neg}, ties
		#'   dropped) from the design's matched-pair structure and returns
		#'   \eqn{\hat\beta_T = \hat p - 0.5}, where \eqn{\hat p} is the proportion
		#'   of untied pairs favoring treatment. If every pair is tied, the
		#'   estimate is \code{0} (no directional preference) and the fit is
		#'   cached as standard-error-nonestimable (or fully nonestimable when
		#'   \code{harden = FALSE}).
		#' @param estimate_only If TRUE, skip the standard-error computation and
		#'   cache only the point estimate.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes \eqn{\hat\beta_T} under subject/block-level
		#'   bootstrap weights (Bayesian-bootstrap draw weights, expanded to row
		#'   level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}): for
		#'   each matched pair, a weighted vote is cast toward whichever member has
		#'   the higher response, using the mean bootstrap weight of the pair's two
		#'   rows; \eqn{\hat\beta_T^{(w)}} is the weighted proportion of
		#'   treatment-favoring pairs minus \code{0.5}. No standard error is
		#'   computed (\code{s_beta_hat_T} is always \code{NA}). Pairs with no
		#'   discordant (untied) weighted votes are cached as nonestimable.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			m_vec = private$m
			if (is.null(m_vec)) {
				private$compute_basic_match_data()
				m_vec = private$m
			}
			if (is.null(m_vec)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			pair_ids = sort(unique(m_vec[m_vec > 0L]))
			if (!length(pair_ids)) {
				private$cache_nonestimable_estimate("ordinal_paired_sign_test_no_discordant_pairs")
				return(NA_real_)
			}
			pos_w = 0
			neg_w = 0
			for (pid in pair_ids) {
				idx = which(m_vec == pid)
				if (length(idx) < 2L) next
				i_t = idx[private$w[idx] == 1L][1L]
				i_c = idx[private$w[idx] == 0L][1L]
				if (!is.finite(i_t) || !is.finite(i_c)) next
				diff = as.numeric(private$y[i_t]) - as.numeric(private$y[i_c])
				pair_w = mean(row_weights[c(i_t, i_c)])
				if (!is.finite(pair_w) || pair_w <= 0) next
				if (diff > 0) pos_w = pos_w + pair_w
				if (diff < 0) neg_w = neg_w + pair_w
			}
			n_eff = pos_w + neg_w
			if (!is.finite(n_eff) || n_eff <= 0) {
				private$cached_values$beta_hat_T = 0
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(private$cached_values$beta_hat_T)
			}
			p_hat = pos_w / n_eff
			private$cached_values$beta_hat_T = as.numeric(p_hat - 0.5)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for \eqn{\beta_T = \theta - 0.5}
		#'   (equivalently, for \eqn{\theta = P(Y_T > Y_C \mid \text{pair
		#'   untied})}), using the binomial-proportion standard error; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared Wald
		#'   contract. Fits (computes the pair-sign counts) first if not already
		#'   cached.
		#' @param  alpha  				Two-sided miscoverage rate; the returned interval
		#'   targets \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald test of \eqn{H_0: \theta = 0.5} (equal
		#'   chance of favoring treatment vs. control among untied pairs) against
		#'   \eqn{H_1: \theta \ne 0.5}, using the binomial-proportion standard
		#'   error; see \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the
		#'   shared Wald contract. Only \code{delta = 0} is supported (the sign
		#'   test's null is fixed at no directional preference; a non-zero
		#'   \code{delta} throws).
		#' @param  delta  				The null value for \eqn{\beta_T}; must be \code{0}.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
				if (delta != 0) stop("Sign test only supports testing against delta = 0.")
			}
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Uses the shared nonparametric bootstrap distribution contract; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#'   Note that Bootstrap is disabled for this class as subject-level resampling violates the
		#'   matched-pair design constraint.
		#' @param B  					Number of bootstrap samples.
		#' @param show_progress Whether to show a progress bar.
		#' @param debug         Whether to return diagnostics.
		#' @param bootstrap_type Optional resampling scheme.
		#' @return A numeric vector of bootstrap estimates.
		approximate_bootstrap_distribution_beta_hat_T = function(B = 501, show_progress = TRUE, debug = FALSE, bootstrap_type = NULL){
			stop("Bootstrap inference is not supported for InferenceOrdinalPairedSignTest because subject-level resampling violates the matched-pair design constraint.")
		},
		#' @description Creates the jackknife distribution of the estimate for the treatment effect.
		#'   Note that Jackknife is disabled for this class as subject-level deletion violates the
		#'   matched-pair design constraint.
		#' @param unit Deletion unit.
		#' @return A numeric vector of jackknife estimates.
		approximate_jackknife_distribution_beta_hat_T = function(unit = "auto"){
			stop("Jackknife inference is not supported for InferenceOrdinalPairedSignTest because subject-level deletion violates the matched-pair design constraint.")
		}
	),
	private = list(
		# Self/private-free so it's safe to call unbound against a candidate
		# des_obj before construction, same "safe invoke without construction"
		# contract as design_compatibility_reason() elsewhere (Wilcox/CMH/
		# ExtendedRobins/ExactBinomial/ExactFisher). Mirrors the shared
		# KKPassThrough mixin's own init_kk_passthrough() guard exactly (both
		# read only des_obj$is_a_kk_matching_capable()) -- this class is the
		# one KKPassThrough-composing class whose name doesn't contain "KK",
		# so the registry's name-based requires_kk filter misses it, which is
		# exactly why this class-level predicate is needed here specifically
		# even though every other KKPassThrough-composing class is already
		# covered by that name heuristic. See infer_inference_design_
		# compatibility_reason_fn() in inference_class_registry.R.
		design_compatibility_reason = function(des_obj){
			if (!isTRUE(des_obj$is_a_kk_matching_capable())) {
				return("paired_sign_test_requires_matching_design")
			}
			NA_character_
		},
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		supports_likelihood_tests = function() FALSE,
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			
			if (is.null(private$cached_values$KKstats)){
				private$compute_basic_match_data()
			}
			
			diffs = private$cached_values$KKstats$y_matched_diffs
			# Sign test on matched pairs: ignore ties (diff == 0)
			pos = sum(diffs > 0)
			neg = sum(diffs < 0)
			n_eff = pos + neg
			
			if (n_eff == 0){
				if (private$harden && length(diffs) > 0){
					# If all pairs are tied, the most natural estimate is 0 (p_hat = 0.5)
					# but we have no variance information.
					private$cached_values$beta_hat_T = 0
					private$cache_nonestimable_se("ordinal_paired_sign_test_no_discordant_pairs")
				} else {
					private$cache_nonestimable_estimate("ordinal_paired_sign_test_no_discordant_pairs")
				}
				return(invisible(NULL))
			}
			
			# Estimate: proportion of non-tied pairs favoring treatment
			p_hat = pos / n_eff
			# Beta is usually defined as p_hat - 0.5 for centered tests
			private$cached_values$beta_hat_T = p_hat - 0.5
			# Standard error for proportion
			se = sqrt(p_hat * (1 - p_hat) / n_eff)
			
			private$cached_values$s_beta_hat_T = if (is.finite(se) && se > 0) se else NA_real_
		}
	),
	overrides = list(
		public = c(
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights",
			"compute_rand_two_sided_pval",
			"approximate_jackknife_distribution_beta_hat_T",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_estimate"
		),
		private = c(
			"compute_basic_match_data",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl"
		)
	)
)
