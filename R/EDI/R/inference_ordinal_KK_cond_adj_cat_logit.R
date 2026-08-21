#' Adjacent Category Logit Inference for KK Matching-on-the-fly Designs
#'
#' Fits a conditional (stratified) adjacent-category logit model for ordinal
#' responses under a KK matching-on-the-fly design:
#' \deqn{\log\frac{\Pr(Y_i = j+1 \mid Y_i \in \{j, j+1\})}{\Pr(Y_i = j \mid Y_i
#' \in \{j, j+1\})} = \alpha_j + \beta_T W_i + X_i^\top \gamma,} for adjacent
#' category comparisons \eqn{j = 1, \dots, K-1}, with cut-specific intercepts
#' \eqn{\alpha_j} and a treatment coefficient \eqn{\beta_T} constrained equal
#' across all cuts (the parallel/proportional adjacent-category assumption).
#' \eqn{\exp(\hat\beta_T)} is the common adjacent-category odds ratio. Fitting
#' proceeds by \code{\link{expand_adjacent_category_data_cpp}}'s stacked-binary
#' expansion (each subject contributes a 0/1 row per adjacent cut they border,
#' stratified by matched pair) followed by conditional logistic regression on
#' the expanded data — the matched-pair identity becomes the conditioning
#' stratum, so the pair's shared nuisance intercept is conditioned out exactly
#' as in a single binary conditional-logit KK model, and reservoir (unmatched)
#' subjects each form their own singleton stratum. \code{likelihood_tier =
#' "partial"} (a conditional/partial likelihood, matched-set effects are
#' profiled out rather than estimated); \code{supports_likelihood_tests()} is
#' hard \code{FALSE} — only Wald inference is exposed, not likelihood-ratio,
#' score, or gradient tests. Validity requires the adjacent-category
#' proportionality assumption (a common \eqn{\beta_T} across all \eqn{K-1}
#' cuts) in addition to the usual conditional-logit exchangeability-within-strata
#' assumption induced by the KK design.
#'
#' @references Agresti, A. (2010). \emph{Analysis of Ordinal Categorical Data}
#'   (2nd ed.). Wiley, for the adjacent-category logit model family; Kapelner,
#'   A. and Krieger, A. M. (2014). "Matching on-the-fly: Sequential allocation
#'   with higher power and efficiency." \emph{Biometrics}, 70(2), 378-388,
#'   \doi{10.1111/biom.12148}, for the KK matching-on-the-fly design this
#'   class is built for.
#'
#' @seealso \code{\link[EDI:InferenceOrdinalAdjCatLogitRegr]{InferenceOrdinalAdjCatLogitRegr}}
#'   for the non-KK analog. See also:
#'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal regression}
#'   (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalKKCondAdjCatLogitRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalKKCondAdjCatLogitRegr = define_inference_class(
	classname = "InferenceOrdinalKKCondAdjCatLogitRegr",
	inherit = Inference,
	# 2026-08-19 (fix_inference_hierarchy.md "Partial-Likelihood Estimators",
	# "Migrate KK partial-likelihood classes"): flipped from the hybrid
	# `define_inference_class(inherit = InferenceAsympLik, components =
	# c("OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"))` state
	# (already a factory call composing the right domain components, but
	# still R6-inheriting the deep InferenceAsympLik/InferenceAsymp/.../Wald
	# ladder for compute_z_or_t_*/get_standard_error/etc.) to `inherit =
	# Inference` with `Wald` composed explicitly -- unlike the KKGLMM-family
	# migrations earlier this stretch, `supports_likelihood_tests()` is
	# hard-`FALSE` here (this class never gets ParametricLikelihoodBootstrap,
	# whose LikelihoodTests dependency pulls Wald in transitively), so Wald
	# must be listed directly, same as every other Wald-only KK IVWC class
	# (e.g. InferenceAllKKMeanDiffIVWC's `c("BayesianBootstrap", "Wald",
	# "KKMeanDifferenceIVWC")`).
	components = c("BayesianBootstrap", "Wald", "OrdinalConditionalLogitPartialLikelihood", "KKPassThrough"),
	public = list(
		# Pinned from InferenceRandCI (confirmed via the pre-migration R6
		# ancestor walk, same verification step as the KKCondLogitGLMM
		# family's identical pin) -- not InferenceRand's raw version, even
		# though this class is ordinal (not incidence): InferenceRandCI's
		# wrapper still resolves correctly here since
		# should_use_zhang_incidence_randomization() is false for ordinal
		# responses, falling through to the same core permutation logic: the
		# pin is chosen to exactly match the confirmed legacy resolution,
		# not assumed equivalent.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the conditional adjacent-category
		#'   logit model \eqn{\log(\Pr(Y_i = j+1 \mid Y_i \in \{j,j+1\}) / \Pr(Y_i =
		#'   j \mid Y_i \in \{j,j+1\})) = \alpha_j + \beta_T W_i + X_i^\top \gamma}
		#'   and prepare KK matched-pair structure for the stratified conditional-logit
		#'   fit. Does not fit the model; the fit is deferred to the first call to
		#'   \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed KK \code{DesignSeqOneByOne} object with an
		#'   ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment.
		#' @param verbose Flag for progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @param harden Whether to apply robustness measures.
		initialize = function(des_obj, verbose = FALSE, harden = TRUE, model_formula = NULL, smart_cold_start_default = NULL){
			# No per-class assertResponseType() here: the root
			# Inference$initialize() enforces the registry's response_types
			# metadata for every class uniformly (2026-08-21 -- this class was
			# one of four the discovery-vs-constructibility audit caught with
			# the per-class assert missing, which motivated the root-level gate).
			super$initialize(des_obj, verbose = verbose, harden = harden, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_passthrough(des_obj)
		},
		#' @description Fits the conditional adjacent-category logit model via
		#'   stacked-binary expansion (\code{\link{expand_adjacent_category_data_cpp}})
		#'   plus conditional logistic regression, and returns the shared
		#'   log-odds-ratio estimate \eqn{\hat\beta_T}.
		#' @param estimate_only If \code{TRUE}, skip standard-error computation and
		#'   cache only the point estimate; used by randomization and bootstrap
		#'   resampling paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the treatment estimate under subject/block-level
		#'   bootstrap weights (Bayesian-bootstrap or nonparametric-bootstrap draw
		#'   weights, expanded to row level via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}). When
		#'   weights are effectively constant, this collapses to the unweighted
		#'   \code{compute_estimate()} call. Otherwise, rather than refitting the
		#'   full expanded conditional-logit model under weights, it calls
		#'   \code{weighted_ordinal_bootstrap_surrogate_fit()} — a fast weighted
		#'   ordinal-logistic surrogate fit on the raw (unexpanded) design matrix —
		#'   as an approximation to the weighted adjacent-category likelihood; this
		#'   trades exact reweighted refitting for speed across many bootstrap
		#'   replicates. No standard error is computed (\code{s_beta_hat_T} is
		#'   always \code{NA}); the surrogate returns \code{NA} if the fit fails.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					return(private$cached_values$beta_hat_T)
				}
			}
			X = private$create_design_matrix()[, -1, drop = FALSE]
			fit = weighted_ordinal_bootstrap_surrogate_fit(X, private$y, row_weights, method = "logistic")
			private$cached_values$beta_hat_T = if (is.null(fit)) NA_real_ else as.numeric(fit$beta_hat)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for the shared adjacent-category
		#'   log-odds-ratio \eqn{\beta_T}, using the conditional-logit model's
		#'   standard error; see \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}
		#'   for the shared Wald contract. Fits the model first if not already
		#'   cached.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared()
			ordinal_cond_clogit_assert_finite_se(private, class(self)[1])
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Return the adjacent-category conditional-logit asymptotic
		#'   p-value for the treatment coefficient, using the shared Wald semantics
		#'   documented in \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Null hypothesis treatment effect.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared()
			ordinal_cond_clogit_assert_finite_se(private, class(self)[1])
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		supports_likelihood_tests = function() FALSE,
		shared = function(estimate_only = FALSE){
			ordinal_cond_clogit_shared_multi(private, expand_adjacent_category_data_cpp, function(y_i, n_alpha) {
				trials = integer(0)
				if (y_i <= n_alpha) trials = c(trials, y_i)
				if (y_i > 1) trials = c(trials, y_i - 1L)
				sort(unique(trials))
			})
		}
	),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval",
			"approximate_bootstrap_distribution_beta_hat_T"
		),
		private = c(
			"compute_basic_match_data",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl"
		)
	),
	metadata = list(likelihood_tier = "partial")
)
