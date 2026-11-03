#' Abstract Conditional Logistic GLMM Inference
#'
#' Shared base of the KK conditional-logit classes. The model depends on the
#' response type:
#' \itemize{
#'   \item \strong{Incidence}
#'     (\code{\link[EDI:InferenceIncidKKCondLogitGLMMOneLik]{InferenceIncidKKCondLogitGLMMOneLik}},
#'     \code{\link[EDI:InferenceIncidKKCondLogitGLMMIVWC]{InferenceIncidKKCondLogitGLMMIVWC}};
#'     since v1.0.5): conditional logit on the discordant matched pairs plus,
#'     for OneLik, an ordinary logistic regression on the reservoir subjects,
#'     sharing the treatment and covariate coefficients. Concordant pairs are
#'     not used. See \code{InferenceIncidKKCondLogitGLMMOneLik} for the model
#'     and its caveat about pooling a pair-conditional and a covariate-conditional
#'     odds ratio.
#'   \item \strong{Proportion}
#'     (\code{\link[EDI:InferencePropKKGLMM]{InferencePropKKGLMM}}): one
#'     likelihood with a conditional-logistic contribution from discordant
#'     matched pairs and a random-intercept logistic GLMM contribution from
#'     concordant matched pairs and reservoir subjects. A proportion pair is
#'     never exactly discordant, so in practice every subject enters the GLMM.
#' }
#'
#' \strong{Known estimability limitation at high covariate counts.} The
#' treatment effect is identified from the discordant-pair conditional-logit
#' term alone (the shared pair-level intercept cancels only for pairs that
#' disagree on outcome), so that term alone must identify treatment plus
#' every adjustment covariate from however many pairs happen to be
#' discordant for a given incidence response, typically a modest fraction of
#' \eqn{n}. With \code{model_formula = ~.} on a dataset with many covariates,
#' the number of free parameters the discordant term must help identify can
#' approach or exceed the number of discordant pairs, and the joint fit then
#' frequently converges to an out-of-bounds coefficient (or, for the
#' proportion GLMM, random-effect log-variance) and is correctly reported as
#' nonestimable rather than returned. This was measured directly
#' (\code{comprehensive_tests.R} repro, 2026-10, with the pre-v1.0.5 GLMM
#' model for incidence): the identical design/response/n was estimable in 39
#' of 40 null replicates with one covariate, but only 22 of 40 with ten
#' covariates under \code{model_formula = ~.}. A covariate the design matched
#' exactly (zero within-pair differences) is not identified by conditional
#' logit; for incidence it is dropped from the fit rather than making the fit
#' fail. This is treated as an accepted property of this
#' estimator in this regime, not a defect to be patched; when the cause is
#' specifically this parameter-to-discordant-pair imbalance, the cached
#' nonestimability reason names it explicitly
#' (\code{joint_likelihood_nonestimable_high_dimensional_relative_to_discordant_pairs},
#' with the actual counts) rather than the generic
#' \code{joint_likelihood_nonestimable} that covers every other cause of the
#' same two bound checks.
#'
#' @keywords internal
InferenceAbstractKKCondLogitGLMM = define_inference_class(
	classname = "InferenceAbstractKKCondLogitGLMM",
	inherit = Inference,
	# 2026-08-19 (fix_inference_hierarchy.md "KK And IVWC Estimators",
	# "Migrate KK GEE and GLMM classes"): flipped from the hybrid
	# `define_inference_class(inherit = InferenceParamBootstrap, components =
	# "KKPassThrough")` state (already a factory call, but still
	# R6-inheriting BayesianBootstrap/ParametricLikelihoodBootstrap instead
	# of composing them) to composing them directly -- same hybrid-state fix
	# as InferenceContinKKGLMM/InferenceCountKKGLMM/InferenceOrdinalKKGLMM
	# earlier this stretch. This abstract base has 3 real concrete
	# descendants (plain R6::R6Class leaves, same pattern as
	# InferenceAsympLikStdModCache's descendants): InferencePropKKGLMM,
	# InferenceIncidKKCondLogitGLMMIVWC, InferenceIncidKKCondLogitGLMMOneLik
	# -- none of the three call `super$...()` anywhere in their own bodies
	# (verified by grep), so no generic-alias overrides were needed for this
	# migration.
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"ParametricLikelihoodBootstrap",
		"KKPassThrough"
	),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache) this stretch.
	metadata = list(likelihood_tier = "partial", capabilities = "likelihood_ratio"),
	public = list(
		# Pinned from InferenceRandCI (NOT InferenceRand, unlike every other
		# KK GLMM migration this stretch): this abstract base serves both
		# incidence and proportion response types, and its pre-migration
		# resolution (walked via the R6 inheritance chain of the hybrid
		# `inherit = InferenceParamBootstrap` state) landed on
		# InferenceRandCI's compute_rand_two_sided_pval -- the
		# Zhang-incidence-aware wrapper -- not InferenceRand's raw
		# permutation-only version. Confirmed via golden-test failure:
		# InferenceRand's version threw "Randomization tests are not
		# supported for incidence. Use Zhang method." on incidence designs
		# where the legacy class succeeded with a real Zhang p-value.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize KK conditional-logit inference for an incidence
		#'   or proportion response and validate the design; the model (conditional
		#'   logit plus reservoir logistic regression for incidence, conditional
		#'   logit plus random-intercept GLMM for proportions) is fit on first use. See
		#'   \code{\link[EDI:InferenceAbstractKKCondLogitGLMM]{InferenceAbstractKKCondLogitGLMM}}.
		#' @param des_obj A completed \code{Design} object with an incidence or proportion response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param max_abs_reasonable_coef Cap for reasonable coefficient estimates.
		#' @param max_abs_reasonable_se Cap for reasonable treatment standard errors.
		#' @param max_abs_log_sigma Cap for reasonable log random effect variance.
		#' @param verbose Logical. Whether to print progress messages.
		#' @param smart_cold_start_default Logical. Whether to use smart starting values for the optimizer.
		#' @param optimization_alg Character. Optimization algorithm (default "lbfgs").
		initialize = function(des_obj, model_formula = NULL, max_abs_reasonable_coef = 50, max_abs_reasonable_se = 10, max_abs_log_sigma = 8, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), c("incidence", "proportion"))
			}
			self$set_optimization_alg(optimization_alg, allow_irls = FALSE, default = "lbfgs")
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$max_abs_reasonable_coef = max_abs_reasonable_coef
			private$max_abs_reasonable_se = max_abs_reasonable_se
			private$max_abs_log_sigma = max_abs_log_sigma
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$init_kk_passthrough(des_obj)
		},
		#' @description Computes the class-specific treatment-effect estimate; see
		#'   \code{\link[EDI:Inference]{Inference}}.
		#' @param estimate_only Logical. If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the class-specific treatment estimate for a bootstrap sample; see
		#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
		#' @param subject_or_block_weights Numeric vector. Row weights for bootstrap.
		#' @param estimate_only Logical. If TRUE, skip variance component calculations.
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
			if (private$uses_reservoir_logit()) {
				return(private$compute_clogit_reservoir_logit_weighted_estimate(row_weights))
			}
			# Preserve the reported estimand in every nonconstant bootstrap draw:
			# the observed fit is the 20-node joint conditional-logit + random-
			# intercept likelihood, so a weighted draw must not substitute the
			# all-row Laplace glmmTMB likelihood.  A matched pair contributes one
			# conditional-logit observation and gets the mean of its member weights,
			# matching kk_pair_and_reservoir_bootstrap_weights(); GLMM rows retain
			# their individual weights.  Zero-weight likelihood rows are omitted.
			d = private$prepare_clogit_plus_glmm_data()
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			disc_weights = vapply(d$i_m_disc, function(pair_id) {
				mean(row_weights[m_vec == pair_id], na.rm = TRUE)
			}, numeric(1))
			conc_weights = as.numeric(row_weights[d$i_glmm])
			keep_disc = is.finite(disc_weights) & disc_weights > 0
			keep_conc = is.finite(conc_weights) & conc_weights > 0 & is.finite(d$y_conc)
			d$X_disc = d$X_disc[keep_disc, , drop = FALSE]
			d$y_disc = d$y_disc[keep_disc]
			d$X_conc = d$X_conc[keep_conc, , drop = FALSE]
			d$y_conc = d$y_conc[keep_conc]
			d$group_conc = d$group_conc[keep_conc]
			disc_weights = disc_weights[keep_disc]
			conc_weights = conc_weights[keep_conc]
			d$has_discordant = length(disc_weights) > 0L
			d$has_concordant = length(conc_weights) > 0L
			if (!d$has_discordant && !d$has_concordant) return(NA_real_)
			n_params = if (d$has_concordant) ncol(d$X_conc) + 1L else ncol(d$X_disc)
			fit = tryCatch(
				fast_clogit_plus_glmm_cpp(
					X_disc = d$X_disc, y_disc = d$y_disc,
					X_conc = d$X_conc, y_conc = d$y_conc,
					group_conc = d$group_conc,
					has_discordant = d$has_discordant,
					has_concordant = d$has_concordant,
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					estimate_only = TRUE,
					max_abs_log_sigma = private$max_abs_log_sigma,
					optimization_alg = private$optimization_alg,
					weights_disc = disc_weights,
					weights_conc = conc_weights
				),
				error = function(e) NULL
			)
			beta = if (isTRUE(fit$converged)) {
				j_T = if (d$has_concordant) 2L else 1L
				as.numeric(fit$params)[j_T]
			} else NA_real_
			max_abs_boot_coef = min(private$max_abs_reasonable_coef, private$bootstrap_extreme_estimate_threshold)
			if (!is.finite(beta) || abs(beta) > max_abs_boot_coef) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			private$cached_values$beta_hat_T = if (is.finite(beta)) as.numeric(beta) else NA_real_
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha Numeric. Significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			# TODO-121: dispatch on the testing type (was: always Wald).
			switch(
				private$testing_type,
				wald = {
					private$shared(estimate_only = FALSE)
					private$compute_z_or_t_ci_from_s_and_df(alpha)
				},
				score = private$compute_score_confidence_interval_impl(alpha),
				gradient = private$compute_gradient_confidence_interval_impl(alpha),
				lik_ratio = private$compute_lik_ratio_confidence_interval_impl(alpha),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_confidence_interval_impl(alpha),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_confidence_interval_impl(alpha),
				stop("Unsupported testing_type: ", private$testing_type)
			)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Numeric. Null treatment effect value (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			# TODO-121: dispatch on the testing type (was: always Wald).
			switch(
				private$testing_type,
				wald = {
					private$shared(estimate_only = FALSE)
					private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
				},
				score = private$compute_score_two_sided_pval_impl(delta),
				gradient = private$compute_gradient_two_sided_pval_impl(delta),
				lik_ratio = private$compute_lik_ratio_two_sided_pval_impl(delta),
				lik_ratio_bartlett_approx = private$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(delta),
				lik_ratio_bartlett_exact = private$compute_lik_ratio_bartlett_exact_two_sided_pval_impl(delta),
				stop("Unsupported testing_type: ", private$testing_type)
			)
		}
	),
	private = list(
		is_a_kk_cond_logit_glmm = function() TRUE,
		# 2026-08-19 (fix_inference_hierarchy.md "KK And IVWC Estimators",
		# "Migrate KK GEE and GLMM classes"): moved from `public` to `private`
		# during this migration. It was public-only pre-migration, which was
		# harmless only because the `KKPassThrough`-only composition never
		# pulled in a competing private `get_standard_error` (the canonical
		# location for this method everywhere else in the codebase --
		# see e.g. Wald's `get_standard_error` in
		# inference_all_abstract_asymp.R). Composing
		# `ParametricLikelihoodBootstrap` (which depends on `LikelihoodTests`
		# -> `Wald`) now pulls in a real private `get_standard_error`, so the
		# public/private duplicate must be resolved by picking one location;
		# grepped the whole tree first to confirm no caller uses
		# `$get_standard_error()` publicly on any of this abstract base's
		# descendants (every caller uses `private$get_standard_error()` /
		# `.__enclos_env__$private$get_standard_error()`), so moving it to
		# `private` (host wins the collision, declared below) preserves
		# behavior exactly.
		get_standard_error = function(){
			private$shared(estimate_only = FALSE)
			se = private$cached_values$s_beta_hat_T
			if (is.null(se) || length(se) == 0L) {
				return(NA_real_)
			}
			as.numeric(se)[1L]
		},
		max_abs_reasonable_coef = 50,
		max_abs_reasonable_se = 10,
		max_abs_log_sigma = 8,
		bootstrap_extreme_estimate_threshold = 8,
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && isTRUE(private$cached_values$s_beta_hat_T > 0)) return(invisible(NULL))
			private$clear_nonestimable_state()
			private$cached_mod = NULL
			private$cached_values$likelihood_test_context = NULL
			if (private$uses_reservoir_logit()) return(private$shared_clogit_reservoir_logit(estimate_only))

			d = private$prepare_clogit_plus_glmm_data()
			if (!d$has_discordant && !d$has_concordant) {
				private$cache_nonestimable_estimate("no_data_for_clogit_plus_glmm")
				return(invisible(NULL))
			}
			
			n_params = ncol(d$X_conc) + 1L # betas + log_sigma
			fit = tryCatch(
				fast_clogit_plus_glmm_cpp(
					X_disc = d$X_disc, y_disc = d$y_disc,
					X_conc = d$X_conc, y_conc = d$y_conc,
					group_conc = d$group_conc,
					has_discordant = d$has_discordant,
					has_concordant = d$has_concordant,
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					estimate_only = estimate_only,
					max_abs_log_sigma = private$max_abs_log_sigma,
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !isTRUE(fit$converged)) {
				private$cache_nonestimable_estimate("joint_likelihood_failed_to_converge")
				return(invisible(NULL))
			}
			
			# Treatment effect index:
			# If has_concordant is true, shared beta starts at par[0] (intercept), so treatment is par[1].
			# If has_concordant is false, shared beta starts at par[0], so treatment is par[0].
			j_T = if (d$has_concordant) 2L else 1L
			
			params = as.numeric(fit$params)
			coef_params = if (length(params) > 1L) params[-length(params)] else params
			if (any(!is.finite(coef_params)) || any(abs(coef_params) > private$max_abs_reasonable_coef)) {
				private$cache_nonestimable_estimate(private$joint_likelihood_nonestimable_reason(d))
				return(invisible(NULL))
			}
			log_sigma = if (length(params) > 1L) params[length(params)] else NA_real_
			if (!is.finite(log_sigma) || abs(log_sigma) > private$max_abs_log_sigma) {
				private$cache_nonestimable_estimate(private$joint_likelihood_nonestimable_reason(d))
				return(invisible(NULL))
			}
			beta_hat_T = as.numeric(params[j_T])
			
			private$cached_mod = fit
			private$set_fit_warm_start(as.numeric(fit$params), "params", fisher = fit$fisher_information)
			private$cached_values$likelihood_test_context = list(
				d = d,
				j_T = j_T,
				start = as.numeric(fit$params)
			)
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$df   = Inf
			if (estimate_only) return(invisible(NULL))
			ssq = fit$ssq_b_j 
			se = if (!is.null(ssq) && is.finite(ssq) && ssq > 0) sqrt(ssq) else NA_real_
			if (!is.finite(se) || se <= 0 || se > private$max_abs_reasonable_se) {
				private$cache_nonestimable_se("joint_likelihood_standard_error_unavailable")
				return(invisible(NULL))
			}
			private$cached_values$s_beta_hat_T = se
		},
		# `joint_likelihood_nonestimable` (both call sites above, an out-of-bounds
		# beta coefficient or log_sigma) is a known, accepted property of this
		# estimator at high covariate counts, not a defect: the treatment effect
		# is identified only from discordant matched pairs (a conditional-logit
		# likelihood that drops the pair's shared intercept), so with p covariates
		# plus treatment, the discordant part alone must identify p+1 parameters
		# from however many pairs actually disagree on outcome -- frequently a
		# small fraction of n for a binary response. Confirmed directly
		# (comprehensive_tests.R repro, 2026-10): the same design/response/n with
		# 1 covariate was estimable in 39/40 null replicates; with 10 covariates
		# and model_formula = ~., estimable in only 22/40. When that's the
		# explanation -- discordant pairs exist but are already outnumbered by
		# the discordant likelihood's own free parameters (treatment + covariates,
		# no intercept) -- say so by name instead of the generic reason, which
		# otherwise still covers every other cause unchanged (including the
		# `has_discordant = FALSE` case, where this diagnosis does not apply).
		joint_likelihood_nonestimable_reason = function(d){
			n_disc_params = ncol(d$X_disc)
			n_discordant_pairs = nrow(d$X_disc)
			if (isTRUE(d$has_discordant) && is.finite(n_discordant_pairs) && n_discordant_pairs > 0L &&
					is.finite(n_disc_params) && n_disc_params >= n_discordant_pairs) {
				return(sprintf(
					"joint_likelihood_nonestimable_high_dimensional_relative_to_discordant_pairs (n_disc_params=%d, n_discordant_pairs=%d)",
					n_disc_params, n_discordant_pairs
				))
			}
			"joint_likelihood_nonestimable"
		},
		get_likelihood_test_spec = function(){
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			if (private$uses_reservoir_logit()) return(private$get_clogit_reservoir_logit_spec(ctx))
			d = ctx$d
			j_treat = as.integer(ctx$j_T)
			list(
				X = d$X_conc, 
				j = j_treat,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					fast_clogit_plus_glmm_cpp(
						X_disc = d$X_disc, y_disc = d$y_disc,
						X_conc = d$X_conc, y_conc = d$y_conc,
						group_conc = d$group_conc,
						has_discordant = d$has_discordant,
						has_concordant = d$has_concordant,
						warm_start_params = start %||% private$get_fit_warm_start_for_length("params", length(ctx$start)) %||% ctx$start,
						warm_start_fisher_info = private$get_fit_warm_start_fisher(length(ctx$start)),
						estimate_only = FALSE,
						max_abs_log_sigma = private$max_abs_log_sigma,
						fixed_idx = j_treat, fixed_values = delta,
						optimization_alg = private$optimization_alg
					)
				},
				extract_start = function(fit){ as.numeric(fit$params) },
				score = function(fit){
					as.numeric(get_clogit_plus_glmm_score_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				observed_information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				fisher_information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				information = function(fit){
					as.matrix(get_clogit_plus_glmm_hessian_cpp(
						d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
						as.numeric(fit$params), d$has_discordant, d$has_concordant,
						private$max_abs_log_sigma
					))
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll)
				}
			)
		},
		prepare_clogit_plus_glmm_data = function(){
			private$compute_basic_match_data()
			KKstats = private$cached_values$KKstats
			
			# Discordant pairs
			yTs = as.numeric(KKstats$yTs_matched)
			yCs = as.numeric(KKstats$yCs_matched)
			y_m = yTs - yCs # 1 if (1,0), -1 if (0,1)
			
			i_m_disc = which(abs(y_m) == 1)
			X_disc_cov = KKstats$X_matched_diffs_full[i_m_disc, , drop = FALSE]
			# Prepend 1 for the treatment effect in clogit part. 
			# Use a guard to avoid recycling warnings if i_m_disc is empty.
			X_disc = if (length(i_m_disc) > 0L) {
				cbind(treatment = 1, X_disc_cov)
			} else {
				matrix(0, 0, ncol(X_disc_cov) + 1L)
			}
			# y for clogit should be 1 if (1,0) and 0 if (0,1)
			y_disc = (y_m[i_m_disc] + 1) / 2
			
			# Concordant pairs and reservoir for GLMM part
			m_vec = private$m
			# For proportions, differences might not be exactly 0, 1, or -1. 
			# We treat all non-discordant pairs as "concordant" (meaning they go to the GLMM).
			i_m_conc = setdiff(seq_along(y_m), i_m_disc)
			
			i_conc_pair = which(m_vec %in% i_m_conc)
			i_res = which(is.na(m_vec) | m_vec == 0L)
			
			i_glmm = if (private$combine_reservoir_into_glmm()) c(i_conc_pair, i_res) else i_conc_pair

			group_glmm = m_vec[i_glmm]
			i_glmm_res = which(is.na(group_glmm) | group_glmm == 0L)
			if (length(i_glmm_res) > 0L) {
				group_glmm[i_glmm_res] = max(c(0L, m_vec), na.rm = TRUE) + seq_along(i_glmm_res)
			}
			# 2026-11-03 (v1.0.5 TODO-173): fast_clogit_plus_glmm_cpp() builds its
			# random-intercept groups from RUNS of equal group_conc
			# (build_contiguous_group_layout), unlike the sibling GLMM kernels, which
			# sort internally. i_conc_pair is in subject order, so a pair's two rows
			# were usually not adjacent and each became its own one-row group: the
			# kernel fitted a per-observation random intercept instead of a per-pair
			# one (rep-2 calibration data: nll 92.04 vs 70.06 with true pairs; LR
			# p-values depended on the optimizer's start). Order rows by group so the
			# layout sees each pair as one group. Every consumer indexes through
			# d$i_glmm (bootstrap weights) or uses the returned columns together, so
			# reordering here keeps them aligned.
			ord_glmm = order(group_glmm, method = "radix")
			i_glmm = i_glmm[ord_glmm]
			group_glmm = group_glmm[ord_glmm]

			X_glmm_cov = private$get_X()[i_glmm, , drop = FALSE]
			y_glmm = private$y[i_glmm]
			w_glmm = private$w[i_glmm]

			X_glmm = if (length(i_glmm) > 0L) {
				cbind(`(Intercept)` = 1, treatment = w_glmm, X_glmm_cov)
			} else {
				matrix(0, 0, ncol(X_glmm_cov) + 2L)
			}
			
			list(
				X_disc = as.matrix(X_disc),
				y_disc = as.numeric(y_disc),
				X_conc = as.matrix(X_glmm),
				y_conc = as.numeric(y_glmm),
				group_conc = as.integer(group_glmm),
				i_m_disc = as.integer(i_m_disc),
				i_glmm = as.integer(i_glmm),
				has_discordant = length(i_m_disc) > 0L,
				has_concordant = length(i_glmm) > 0L
			)
		},
		combine_reservoir_into_glmm = function() stop("must implement combine_reservoir_into_glmm()"),
		# ---- Conditional logit + reservoir logistic regression (incidence leaves) ----
		# 2026-11-03 (v1.0.5 TODO-173): the incidence leaves no longer fit the
		# random-intercept GLMM on concordant pairs. With pairs grouped correctly,
		# concordant pairs agree within the pair by definition, so they look like
		# an intra-pair correlation of 1: sigma_hat -> Inf, the GLMM term stops
		# depending on beta, and the joint fit collapsed to conditional logit
		# anyway (often past max_abs_log_sigma, i.e. reported nonestimable). The
		# discordant pairs alone already carry all of the pairs' information under
		# a free pair effect (a concordant pair's conditional likelihood is 1).
		# The likelihood is now
		#   l(beta) = sum over discordant pairs of log logistic(+-(beta_T + beta_x'(x_T - x_C)))
		#           + sum over reservoir subjects of the ordinary logistic log-likelihood
		#             with intercept alpha and the SAME beta_T, beta_x,
		# which is one logistic regression on stacked rows: a discordant pair is a
		# row (intercept 0, treatment 1, covariate differences) whose response is
		# "the treated member is the success"; a reservoir subject is a row
		# (1, w, x) with response y. combine_reservoir_into_glmm() (kept for the
		# proportion class's GLMM) decides whether reservoir rows enter: TRUE for
		# OneLik, FALSE for IVWC (pure conditional logit). The proportion class
		# keeps the GLMM: a proportion pair is never exactly discordant.
		uses_reservoir_logit = function() FALSE,
		prepare_clogit_reservoir_logit_data = function(){
			private$compute_basic_match_data()
			KKstats = private$cached_values$KKstats
			y_m = as.numeric(KKstats$yTs_matched) - as.numeric(KKstats$yCs_matched)
			i_m_disc = which(abs(y_m) == 1)
			X_diff = as.matrix(KKstats$X_matched_diffs_full[i_m_disc, , drop = FALSE])
			X_all = as.matrix(private$get_X())
			if (ncol(X_diff) == ncol(X_all)) colnames(X_diff) = colnames(X_all)
			X_disc = cbind(treatment = rep(1, length(i_m_disc)), X_diff)
			m_vec = private$m
			i_res = if (isTRUE(private$combine_reservoir_into_glmm())) which(is.na(m_vec) | m_vec == 0L) else integer(0)
			list(
				X_disc = X_disc,
				y_disc = (y_m[i_m_disc] + 1) / 2,
				i_m_disc = as.integer(i_m_disc),
				X_res = X_all[i_res, , drop = FALSE],
				w_res = as.numeric(private$w[i_res]),
				y_res = as.numeric(private$y[i_res]),
				i_res = as.integer(i_res),
				has_discordant = length(i_m_disc) > 0L
			)
		},
		# Builds the stacked design for the given (optional) pair and reservoir
		# weights. Reservoir rows enter only when their positive-weight outcomes
		# vary: with all-0 or all-1 reservoir outcomes the intercept MLE is at
		# -Inf/+Inf and the reservoir then contributes nothing about beta, so
		# leaving it out is that likelihood's limit (and keeps the information
		# matrix nonsingular).
		assemble_clogit_reservoir_logit = function(dat, w_disc = NULL, w_res = NULL){
			n_disc = nrow(dat$X_disc)
			n_res = length(dat$y_res)
			if (is.null(w_disc)) w_disc = rep(1, n_disc)
			if (is.null(w_res)) w_res = rep(1, n_res)
			kd = is.finite(w_disc) & w_disc > 0
			kr = is.finite(w_res) & w_res > 0 & is.finite(dat$y_res)
			use_res = sum(kr) > 0L && length(unique(dat$y_res[kr])) > 1L
			Z_disc = dat$X_disc[kd, , drop = FALSE]
			if (use_res) {
				Z_res = cbind(1, dat$w_res[kr], dat$X_res[kr, , drop = FALSE])
				Z = rbind(cbind(0, Z_disc), Z_res)
				colnames(Z) = c("(Intercept)", colnames(dat$X_disc))
				y = c(dat$y_disc[kd], dat$y_res[kr])
				wt = c(w_disc[kd], w_res[kr])
			} else {
				Z = Z_disc
				y = dat$y_disc[kd]
				wt = w_disc[kd]
			}
			if (nrow(Z) == 0L) return(NULL)
			# Drop aliased columns (e.g. a covariate the design matched exactly, whose
			# within-pair differences are all 0: under a free pair effect its
			# coefficient is absorbed into the pair intercepts and is not identified
			# without a usable reservoir). Pivoted QR keeps the column order of the
			# identified columns; the treatment column must survive.
			qr_Z = qr(Z * sqrt(wt), tol = 1e-7)
			keep = sort(qr_Z$pivot[seq_len(qr_Z$rank)])
			if (!(which(colnames(Z) == "treatment")[1L] %in% keep)) return(NULL)
			Z = Z[, keep, drop = FALSE]
			list(Z = Z, y = as.numeric(y), wt = as.numeric(wt), j = which(colnames(Z) == "treatment")[1L],
				use_res = use_res, n_disc = sum(kd), n_res = if (use_res) sum(kr) else 0L)
		},
		# Logistic MLE on the stacked rows; with `delta`, beta_T is fixed at delta
		# (an offset) and the remaining parameters are refit. Returns NULL when the
		# fit fails outright.
		fit_clogit_reservoir_logit = function(a, delta = NULL, start = NULL){
			Z = a$Z
			j = a$j
			fixed = !is.null(delta)
			Z_free = if (fixed) Z[, -j, drop = FALSE] else Z
			offset = if (fixed) delta * Z[, j] else rep(0, nrow(Z))
			start_free = NULL
			if (!is.null(start) && length(start) == ncol(Z) && all(is.finite(start))) {
				start_free = if (fixed) start[-j] else start
			}
			coef_free = numeric(0)
			converged = TRUE
			if (ncol(Z_free) > 0L) {
				g = tryCatch(suppressWarnings(stats::glm.fit(
					x = Z_free, y = a$y, weights = a$wt, start = start_free, offset = offset,
					family = stats::binomial(), control = stats::glm.control(maxit = 100L)
				)), error = function(e) NULL)
				if (is.null(g) && !is.null(start_free)) {
					g = tryCatch(suppressWarnings(stats::glm.fit(
						x = Z_free, y = a$y, weights = a$wt, offset = offset,
						family = stats::binomial(), control = stats::glm.control(maxit = 100L)
					)), error = function(e) NULL)
				}
				if (is.null(g)) return(NULL)
				coef_free = as.numeric(g$coefficients)
				converged = isTRUE(g$converged)
			}
			params = if (fixed) append(coef_free, delta, after = j - 1L) else coef_free
			names(params) = colnames(Z)
			if (any(!is.finite(params))) {
				return(list(params = params, neg_loglik = NA_real_, converged = FALSE))
			}
			eta = as.numeric(Z %*% params)
			neg_loglik = -sum(a$wt * (a$y * eta - private$log1pexp(eta)))
			info = private$clogit_reservoir_logit_information(a, params)
			list(params = params, neg_loglik = neg_loglik, converged = converged && is.finite(neg_loglik),
				fisher_information = info, information = info, observed_information = info)
		},
		clogit_reservoir_logit_score = function(a, params){
			eta = as.numeric(a$Z %*% params)
			as.numeric(crossprod(a$Z, a$wt * (a$y - stats::plogis(eta))))
		},
		# Canonical link: observed and expected information coincide.
		clogit_reservoir_logit_information = function(a, params){
			mu = stats::plogis(as.numeric(a$Z %*% params))
			info = crossprod(a$Z * sqrt(a$wt * mu * (1 - mu)))
			dimnames(info) = list(colnames(a$Z), colnames(a$Z))
			info
		},
		# Coefficients checked against max_abs_reasonable_coef: all but the
		# reservoir intercept, a nuisance parameter that can legitimately be large.
		clogit_reservoir_logit_coefs_out_of_bounds = function(a, params){
			coefs = params[colnames(a$Z) != "(Intercept)"]
			any(!is.finite(coefs)) || any(abs(coefs) > private$max_abs_reasonable_coef)
		},
		shared_clogit_reservoir_logit = function(estimate_only){
			dat = private$prepare_clogit_reservoir_logit_data()
			a = private$assemble_clogit_reservoir_logit(dat)
			if (is.null(a)) {
				private$cache_nonestimable_estimate("no_data_for_clogit_plus_reservoir_logit")
				return(invisible(NULL))
			}
			fit = private$fit_clogit_reservoir_logit(a, start = private$get_fit_warm_start_for_length("params", ncol(a$Z)))
			if (is.null(fit) || !isTRUE(fit$converged)) {
				private$cache_nonestimable_estimate("joint_likelihood_failed_to_converge")
				return(invisible(NULL))
			}
			params = as.numeric(fit$params)
			if (private$clogit_reservoir_logit_coefs_out_of_bounds(a, params)) {
				private$cache_nonestimable_estimate(private$joint_likelihood_nonestimable_reason(dat))
				return(invisible(NULL))
			}
			private$cached_mod = fit
			private$set_fit_warm_start(params, "params", fisher = fit$fisher_information)
			private$cached_values$likelihood_test_context = list(a = a, j_T = a$j, start = params)
			private$cached_values$beta_hat_T = params[a$j]
			private$cached_values$df = Inf
			if (estimate_only) return(invisible(NULL))
			vcov = tryCatch(solve(fit$fisher_information), error = function(e) NULL)
			se = if (!is.null(vcov) && is.finite(vcov[a$j, a$j]) && vcov[a$j, a$j] > 0) sqrt(vcov[a$j, a$j]) else NA_real_
			if (!is.finite(se) || se <= 0 || se > private$max_abs_reasonable_se) {
				private$cache_nonestimable_se("joint_likelihood_standard_error_unavailable")
				return(invisible(NULL))
			}
			private$cached_values$s_beta_hat_T = se
		},
		# Bootstrap refit of the same likelihood: a discordant pair is one row and
		# gets the mean of its members' weights (as kk_pair_and_reservoir_bootstrap_weights()
		# does); reservoir rows keep their own weights; zero-weight rows drop out.
		compute_clogit_reservoir_logit_weighted_estimate = function(row_weights){
			dat = private$prepare_clogit_reservoir_logit_data()
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			w_disc = vapply(dat$i_m_disc, function(pair_id) mean(row_weights[m_vec == pair_id], na.rm = TRUE), numeric(1))
			w_res = as.numeric(row_weights[dat$i_res])
			a = private$assemble_clogit_reservoir_logit(dat, w_disc, w_res)
			fit = if (is.null(a)) NULL else private$fit_clogit_reservoir_logit(a, start = private$get_fit_warm_start_for_length("params", ncol(a$Z)))
			beta = if (!is.null(fit) && isTRUE(fit$converged)) as.numeric(fit$params[a$j]) else NA_real_
			max_abs_boot_coef = min(private$max_abs_reasonable_coef, private$bootstrap_extreme_estimate_threshold)
			if (!is.finite(beta) || abs(beta) > max_abs_boot_coef) beta = NA_real_
			private$cached_values$beta_hat_T = beta
			private$cached_values$s_beta_hat_T = NA_real_
			beta
		},
		get_clogit_reservoir_logit_spec = function(ctx){
			a = ctx$a
			list(
				X = a$Z,
				j = as.integer(ctx$j_T),
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					fit = private$fit_clogit_reservoir_logit(a, delta = delta, start = start %||% ctx$start)
					if (is.null(fit) || !is.finite(fit$neg_loglik)) return(NULL)
					fit
				},
				extract_start = function(fit){ as.numeric(fit$params) },
				score = function(fit){ private$clogit_reservoir_logit_score(a, as.numeric(fit$params)) },
				observed_information = function(fit){ private$clogit_reservoir_logit_information(a, as.numeric(fit$params)) },
				fisher_information = function(fit){ private$clogit_reservoir_logit_information(a, as.numeric(fit$params)) },
				information = function(fit){ private$clogit_reservoir_logit_information(a, as.numeric(fit$params)) },
				neg_loglik = function(fit){ as.numeric(fit$neg_loglik) }
			)
		},
		log_sum_exp = function(x){
			m = max(x)
			if (!is.finite(m)) return(m)
			m + log(sum(exp(x - m)))
		},
		log1pexp = function(x){
			ifelse(x > 0, x + log1p(exp(-x)), log1p(exp(x)))
		}
	),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval",
			"get_supported_testing_types", "set_testing_type",
			"approximate_bootstrap_distribution_beta_hat_T"
		),
		private = c(
			"bootstrap_extreme_estimate_threshold",
			"compute_basic_match_data",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"supports_lik_ratio_param_bootstrap",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"get_likelihood_test_spec",
			"shared",
			"get_complexity_tier"
		)
	)
)
