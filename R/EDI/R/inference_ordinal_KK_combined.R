#' GEE Inference for KK Designs with Ordinal Response
#'
#' Fits a \strong{proportional-odds local-odds-ratio} Generalized Estimating
#' Equations model, via \code{multgee::ordLORgee}, for ordinal responses under a
#' KK matching-on-the-fly design, using the treatment indicator and,
#' optionally, all recorded covariates as predictors. Each GEE cluster is
#' either a matched pair (2 members) or a reservoir singleton (1 member) — GEE
#' is used here purely to fit one marginal cumulative-logit model jointly
#' across matched-pair and reservoir subjects while accounting for the
#' within-pair correlation the matching induces, not as a
#' longitudinal/repeated-measures tool. Unlike the other \verb{Inference*KKGEE}
#' classes in this family (continuous/count/incidence/proportion, which use an
#' internal Rcpp solver or \code{geepack::geeglm} with an exchangeable working
#' correlation), this ordinal class always requires the \pkg{multgee} package
#' and has no \code{use_rcpp} option. The raw \pkg{multgee} treatment coefficient
#' is negated when reported so that, consistently with EDI's other ordinal
#' estimators, a positive estimate means movement toward higher response
#' categories. Inference is quasi-likelihood/
#' estimating-equation based (\code{likelihood_tier = "quasi"}): standard
#' errors are GEE sandwich (robust) standard errors, not model-likelihood-based.
#' Bayesian-bootstrap inference is temporarily unavailable because
#' \code{multgee::ordLORgee} does not accept the non-uniform observation
#' weights needed to refit the same clustered estimator. It will remain
#' disabled until the weighted ordinal-GEE implementation planned for v1.1.0
#' is complete.
#'
#' @references Touloumis, A. (2015). "R Package multgee: A Generalized
#'   Estimating Equations Solver for Multinomial Responses." \emph{Journal of
#'   Statistical Software}, 64(8), 1-14, \doi{10.18637/jss.v064.i08}, for the
#'   local-odds-ratio GEE solver used here; Liang, K.-Y., and Zeger, S. L.
#'   (1986). "Longitudinal Data Analysis Using Generalized Linear Models."
#'   \emph{Biometrika}, 73(1), 13-22, \doi{10.1093/biomet/73.1.13}, for the
#'   underlying GEE estimating-equation framework.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalKKGEE$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalKKGEE = define_inference_class(
	classname = "InferenceOrdinalKKGEE",
	inherit = Inference,
	components = "KKGEE",
	public = list(
		#' @description Initialize KK ordinal GEE inference, validate the ordinal
		#'   matched/reservoir design, and prepare the \code{multgee::ordLORgee}
		#'   proportional-odds local-odds-ratio GEE fitting machinery used by
		#'   \code{\link[EDI:InferenceOrdinalKKGEE]{InferenceOrdinalKKGEE}}. Requires
		#'   the \pkg{multgee} package; errors at construction if it is not installed.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				if (!check_package_installed("multgee")){
					stop("Package 'multgee' is required for ", class(self)[1], ". Please install it.")
				}
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_gee_shared(des_obj, use_rcpp = FALSE)
		},
		#' @description Recomputes the KK ordinal treatment estimate under
		#'   subject/block bootstrap weights, used by the Bayesian bootstrap and
		#'   related weighted-resampling machinery. If the supplied weights are all
		#'   (numerically) equal, this short-circuits to the unweighted
		#'   \code{$compute_estimate(estimate_only = TRUE)} (the \code{multgee}
		#'   proportional-odds GEE fit) rather than refitting. Otherwise, since
		#'   \code{multgee::ordLORgee} does not support observation weights, this
		#'   falls back to a \strong{different, approximating} model: a plain
		#'   (non-GEE, no matched-pair clustering) weighted proportional-odds
		#'   ordinal logistic regression via
		#'   \code{\link{fast_ordinal_regression_weighted_cpp}}, treating the
		#'   coefficient on the first predictor column as the treatment effect.
		#'   This always leaves the standard error and degrees of freedom
		#'   unavailable (\code{s_beta_hat_T = NA}, \code{df = Inf}) regardless of
		#'   \code{estimate_only}, since it is a point-estimate-only fallback path.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate. Has no effect on the weighted (non-uniform-weight) fallback
		#'   path, which never computes a standard error regardless.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (length(row_weights) > 0L && all(is.finite(row_weights)) &&
			    (max(row_weights) - min(row_weights)) <= sqrt(.Machine$double.eps)) {
				beta_hat_T = as.numeric(self$compute_estimate(estimate_only = TRUE))[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$beta_hat_T = beta_hat_T
					private$cached_values$s_beta_hat_T = NA_real_
					private$cached_values$df = Inf
					private$cached_values$summary_table = NULL
					return(private$cached_values$beta_hat_T)
				}
			}
			pred_df = private$gee_predictors_df()
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(private$y)
			if (!any(ok)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			X_fit = as.matrix(pred_df[ok, , drop = FALSE])
			y_fit = as.numeric(private$y[ok])
			n_params = ncol(X_fit) + length(sort(unique(y_fit))) - 1L
			mod = tryCatch(
				fast_ordinal_regression_weighted_cpp(
					X = X_fit,
					y = y_fit,
					weights = as.numeric(row_weights[ok]),
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			if (!is.null(mod) && !is.null(mod$params)) {
				private$set_fit_warm_start(as.numeric(mod$params), "params", fisher = mod$fisher_information)
			}
			beta_hat_T = if (is.null(mod) || length(mod$b) < 1L) NA_real_ else as.numeric(mod$b[1L])
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = Inf
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		# Bayesian bootstrap is deliberately disabled for this class because the
		# primary estimator is multgee::ordLORgee whereas non-uniform weighted
		# refits currently use a non-GEE surrogate. See the v1.1.0 implementation
		# plan in package_metadata/new_feature_plans.
		supports_bayesian_bootstrap = function() FALSE,
		gee_response_type = function() "ordinal",
		gee_family        = function() stats::binomial(link = "logit"),
		# Ordinal response requires ordLORgee, not geeglm.
		fit_ordinal_gee_mod = function(bstart = NULL){
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			pred_df = private$gee_predictors_df()
			dat = data.frame(y = factor(private$y, ordered = TRUE), pred_df, group_id = group_id)
			dat = dat[order(dat$group_id), ]
			id_sorted = dat$group_id

			fixed_terms = setdiff(colnames(dat), c("y", "group_id"))
			formula_gee = stats::as.formula(paste("y ~", paste(fixed_terms, collapse = " + ")))

			tryCatch({
				utils::capture.output(m <- suppressMessages(suppressWarnings(
					multgee::ordLORgee(
						formula_gee,
						data   = dat,
						id     = id_sorted,
						LORstr = "uniform",
						link   = "logit",
						bstart = bstart
					)
				)))
				m
			}, error = function(e) NULL)
		},
		# Randomization inference must reuse the ordLORgee fit (not the generic
		# geeglm-based mixin fallback, which errors on >2-level responses and
		# silently returns NA for every permutation replicate) and must not
		# write into cached_values, since permuted data is fit repeatedly.
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			mod = private$fit_ordinal_gee_mod()
			if (is.null(mod)) return(NA_real_)
			beta = stats::coef(mod)
			j_treat = private$gee_treatment_index(beta)
			if (!is.finite(j_treat) || is.na(j_treat) || j_treat < 1L || j_treat > length(beta)) return(NA_real_)
			# multgee parameterizes cumulative links as
			#   F^{-1}{Pr(Y <= j | x)} = alpha_j + x' beta,
			# whereas EDI's ordinal estimand convention uses alpha_j - x' beta,
			# so positive effects consistently mean movement toward higher categories.
			-as.numeric(beta[[j_treat]])
		},
		shared_gee_dispatch = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			n_beta = ncol(private$gee_predictors_df()) + length(unique(private$y)) - 1L
			bstart = private$get_fit_warm_start_for_length("beta", n_beta)
			mod = private$fit_ordinal_gee_mod(bstart = bstart)
			if (is.null(mod)){
				private$cache_nonestimable_estimate("ordinal_kk_gee_fit_unavailable")
				return(invisible(NULL))
			}
			beta = stats::coef(mod)
			private$set_fit_warm_start(beta, "beta")

			j_treat = private$gee_treatment_index(beta)
			# Convert multgee's positive-toward-lower cumulative-link coefficient
			# to EDI's positive-toward-higher ordinal estimand convention.
			private$cached_values$beta_hat_T = -as.numeric(beta[j_treat])
			if (estimate_only) return(invisible(NULL))
			vcov_robust = tryCatch(stats::vcov(mod), error = function(e) NULL)
			if (is.null(vcov_robust)) {
				private$cached_values$s_beta_hat_T = NA_real_
			} else {
				private$cached_values$s_beta_hat_T = sqrt(as.numeric(vcov_robust[j_treat, j_treat]))
			}
			private$cached_values$df = Inf
			private$cached_values$summary_table = summary(mod)$coefficients
		}
	),
	metadata = list(likelihood_tier = "quasi"),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"supports_bayesian_bootstrap",
			"shared",
			"compute_treatment_estimate_during_randomization_inference",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"compute_wald_confidence_interval_impl",
			"compute_wald_two_sided_pval_impl",
			"get_complexity_tier"
		)
	)
)
#' GLMM Inference for KK Designs with Ordinal Response
#'
#' Fits a cumulative-logit random-intercept mixed model (proportional odds) for
#' ordinal responses under a KK matching-on-the-fly design:
#' \eqn{\mathrm{logit}(P(Y_i \le k \mid w_i, x_i, b_{g(i)})) = \alpha_k - (\beta_T
#' w_i + x_i^\top \gamma) - b_{g(i)}}, for cutpoints \eqn{\alpha_1 < \cdots <
#' \alpha_{K-1}}, treatment indicator \eqn{w_i}, covariates \eqn{x_i}, and a
#' matched-pair random intercept \eqn{b_g \sim N(0, \sigma_b^2)} that is
#' integrated out of the marginal likelihood (either by adaptive Gauss-Hermite
#' quadrature when \code{use_rcpp = TRUE}, the default; see
#' \code{\link{fast_ordinal_glmm_cpp}} for the quadrature order and optimizer
#' details, or by \pkg{glmmTMB}'s Laplace approximation when \code{use_rcpp =
#' FALSE}). \eqn{g(i)} is subject \eqn{i}'s matched-pair group id; reservoir
#' (unmatched) subjects each get their own singleton group, contributing no
#' within-group correlation but still entering the joint likelihood. The
#' treatment coefficient \eqn{\beta_T} is a log-odds-ratio: \eqn{\exp(\beta_T)}
#' is the (conditional-on-\eqn{b_g}) odds ratio of being at or above any given
#' response category. \code{likelihood_tier = "full"}: likelihood-ratio, score,
#' Wald, and gradient tests are available when \code{use_rcpp = TRUE} and the
#' fit converges; \code{use_rcpp = FALSE} disables likelihood-test support
#' (\code{private$supports_likelihood_tests()} returns \code{FALSE}) because
#' \pkg{glmmTMB}'s Laplace-approximate likelihood is not wired into this
#' package's score/gradient/LR machinery. Validity requires the random-intercept
#' structure to correctly capture the design's matching dependence, proportional
#' odds (the treatment/covariate effect is constant across cutpoints), and
#' correct specification of the fixed-effects formula.
#'
#' This differs from the GEE sibling
#' \code{\link[EDI:InferenceOrdinalKKGEE]{InferenceOrdinalKKGEE}} (documented
#' above) in estimand and inference basis: the GLMM's \eqn{\beta_T} is a
#' subject-specific (conditional) log-odds-ratio with model-likelihood-based
#' inference, while the GEE's is a population-averaged (marginal) log-odds-ratio
#' with sandwich-based inference; the two need not numerically agree even on the
#' same data, and the correct choice depends on whether a
#' subject-specific/conditional or population-averaged/marginal treatment
#' effect is of interest.
#'
#' @references Hedeker, D., and Gibbons, R. D. (1994). "A Random-Effects
#'   Ordinal Regression Model for Multilevel Analysis." \emph{Biometrics},
#'   50(4), 933-944, \doi{10.2307/2533433}, for the random-effects
#'   cumulative-logit model; Pinheiro, J. C., and Bates, D. M. (1995).
#'   "Approximations to the Log-Likelihood Function in the Nonlinear
#'   Mixed-Effects Model." \emph{Journal of Computational and Graphical
#'   Statistics}, 4(1), 12-35, \doi{10.1080/10618600.1995.10474663}, for the
#'   adaptive Gauss-Hermite quadrature approximation used to integrate out the
#'   random intercept.
#'
#' @seealso Comparable Python API:
#'   \href{https://www.statsmodels.org/stable/mixed_linear.html}{statsmodels
#'   MixedLM} (continuous analog; no ordinal-GLMM in \pkg{statsmodels}).
#'   See also: \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal
#'   regression} and \href{https://en.wikipedia.org/wiki/Mixed_model}{Mixed
#'   model} (Wikipedia).
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'ordinal')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(sample(1:4, 10, replace = TRUE))
#' inf = InferenceOrdinalKKGLMM$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
InferenceOrdinalKKGLMM = define_inference_class("InferenceOrdinalKKGLMM",
	inherit = Inference,
	# 2026-08-19 (fix_inference_hierarchy.md "KK And IVWC Estimators", "Migrate
	# KK GEE and GLMM classes"): flipped from the raw-splice
	# `utils::modifyList(as.list(InferenceMixinKKGLMMShared$public), list(...))`
	# state (manual harvesting of the KKGLMM raw source under
	# `inherit = InferenceParamBootstrap`) to composing the registered `KKGLMM`
	# component directly, plus `BayesianBootstrap`/`ParametricLikelihoodBootstrap`
	# -- same hybrid-state fix as InferenceContinKKGLMM/InferenceCountKKGLMM
	# earlier this stretch.
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "KKGLMM"),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache) this stretch.
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as
		# every other KK GLMM migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize inference for the cumulative-logit random-intercept
		#'   mixed model \eqn{\mathrm{logit}(P(Y_i \le k)) = \alpha_k - (\beta_T W_i +
		#'   X_i^\top \gamma) - b_{g(i)}}, \eqn{b_g \sim N(0, \sigma_b^2)}, where
		#'   \eqn{g(i)} is subject \eqn{i}'s matched-pair group id (reservoir subjects
		#'   get singleton groups). Does not fit the model; the fit is deferred to
		#'   the first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with an ordinal response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param use_rcpp Logical. If \code{TRUE} (default), use internal Rcpp.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertFormula(model_formula, null.ok = TRUE)
				assertFlag(use_rcpp)
			}
			if (use_rcpp) private$skip_glmm_pkg_check = TRUE
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose, smart_cold_start_default = smart_cold_start_default)
			private$init_kk_glmm_shared(des_obj)
			private$use_rcpp = use_rcpp
		},
		#' @description Fits the cumulative-logit random-intercept mixed model by
		#'   (adaptive-Gauss-Hermite- or Laplace-)approximate maximum likelihood and
		#'   returns \eqn{\hat\beta_T}, the estimated treatment log-odds-ratio,
		#'   conditional on the matched-pair random intercept. Caches the fitted
		#'   model object, full parameter vector, and (when \code{estimate_only =
		#'   FALSE}) the standard error and degrees of freedom for reuse by
		#'   \code{compute_asymp_confidence_interval()},
		#'   \code{compute_asymp_two_sided_pval()}, and likelihood-test methods; a
		#'   fit that fails the kernel's projected-gradient convergence check,
		#'   produces non-finite parameters, reaches the upper random-effect variance
		#'   boundary, exceeds \code{private$max_abs_reasonable_coef}, or lacks a
		#'   finite positive treatment-coefficient variance is cached as nonestimable
		#'   rather than returned. A valid near-zero random-effect variance boundary
		#'   is accepted using conditional fixed-effect information. The native
		#'   optimizer retains multistart L-BFGS for basin selection and, only when
		#'   its finite selected point fails the projected-score tolerance, applies
		#'   a damped-Newton polish using the numerical Hessian. The polished point
		#'   is retained only if it remains finite and does not increase the
		#'   negative log-likelihood; at a valid lower variance boundary, the
		#'   KKT-satisfied variance coordinate is excluded from that Newton system.
		#' @param estimate_only If \code{TRUE}, skip standard-error/variance-component
		#'   computation and cache only the point estimate; used by randomization and
		#'   bootstrap resampling paths where only \eqn{\hat\beta_T} is needed per
		#'   replicate.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Wald confidence interval for \eqn{\beta_T} using the fitted
		#'   model's standard error and degrees of freedom; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   \eqn{\hat\beta_T \pm t_{\alpha/2, df} \cdot \widehat{se}(\hat\beta_T)}
		#'   (or z-based when \code{df = Inf}) contract. Fits the model first if not
		#'   already cached.
		#' @param alpha Two-sided miscoverage rate; the returned interval targets
		#'   \code{1 - alpha} coverage.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald test of \eqn{H_0: \beta_T = \code{delta}}
		#'   against \eqn{H_1: \beta_T \ne \code{delta}}, using the fitted model's
		#'   standard error and degrees of freedom; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
		#'   \eqn{t}/\eqn{z} test contract. Fits the model first if not already
		#'   cached.
		#' @param delta Treatment log-odds-ratio value under the null hypothesis.
		compute_asymp_two_sided_pval = function(delta = 0){
			private$shared(estimate_only = FALSE)
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Refits the mixed model with subject/block-level weights
		#'   applied to each row's contribution to the marginal likelihood
		#'   (Bayesian-bootstrap or nonparametric-bootstrap draw weights, expanded
		#'   from subject/block level to individual rows via
		#'   \code{private$expand_subject_or_block_weights_to_row_weights()}) and
		#'   returns the reweighted estimate \eqn{\hat\beta_T^{(w)}}. Uses
		#'   \code{\link{fast_ordinal_regression_weighted_cpp}} — an ordinary
		#'   (non-mixed-effects) weighted cumulative-logit fit, not a reweighted
		#'   GLMM refit — as a fast approximation to the weighted marginal
		#'   likelihood; this trades exact random-effects refitting for speed across
		#'   many bootstrap replicates. When weights are effectively constant, this
		#'   collapses to the unweighted \code{compute_estimate()} call (returns
		#'   \code{df = Inf} to signal a degenerate/skipped bootstrap replicate
		#'   rather than refitting). Rows with non-finite or non-positive weight, or
		#'   non-finite response, are dropped from the weighted fit; if no rows
		#'   remain, the estimate is \code{NA}.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only If \code{TRUE}, compute only the weighted point
		#'   estimate.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights)
			if (weights_are_effectively_constant(row_weights)) {
				self$compute_estimate(estimate_only = estimate_only)
				beta_hat_T = as.numeric(private$cached_values$beta_hat_T)[1L]
				if (is.finite(beta_hat_T)) {
					private$cached_values$df = Inf
					private$cached_values$summary_table = NULL
					return(private$cached_values$beta_hat_T)
				}
			}
			pred_df = private$glmm_predictors_df()
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(private$y)
			if (!any(ok)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				return(NA_real_)
			}
			X_fit = as.matrix(pred_df[ok, , drop = FALSE])
			y_fit = as.numeric(private$y[ok])
			n_params = ncol(X_fit) + length(sort(unique(y_fit))) - 1L
			mod = tryCatch(
				fast_ordinal_regression_weighted_cpp(
					X = X_fit,
					y = y_fit,
					weights = as.numeric(row_weights[ok]),
					warm_start_params = private$get_fit_warm_start_for_length("params", n_params),
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					smart_cold_start = private$smart_cold_start_default
				),
				error = function(e) NULL
			)
			mod_ok = !is.null(mod) && isTRUE(mod$converged) &&
				!is.null(mod$params) && all(is.finite(as.numeric(mod$params))) &&
				length(mod$b) >= 1L && is.finite(as.numeric(mod$b[1L])) &&
				abs(as.numeric(mod$b[1L])) <= private$max_abs_reasonable_coef
			if (mod_ok) {
				private$set_fit_warm_start(as.numeric(mod$params), "params", fisher = mod$fisher_information)
			}
			beta_hat_T = if (mod_ok) as.numeric(mod$b[1L]) else NA_real_
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = Inf
			private$cached_values$summary_table = NULL
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		use_rcpp = TRUE,
		glmm_response_type  = function() "ordinal",
		glmm_family         = function() glmmTMB::cumulative(link = "logit"),
		supports_likelihood_tests = function(){
			isTRUE(private$use_rcpp)
		},
		shared = function(estimate_only = FALSE){
			if (private$use_rcpp) {
				private$shared_rcpp(estimate_only)
			} else {
				private$shared_glmm_tmb(estimate_only)
			}
		},
		shared_rcpp = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			private$clear_nonestimable_state()
			private$cached_mod = NULL
			private$cached_values$likelihood_test_context = NULL
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec[is.na(m_vec)] = 0L
			group_id = m_vec
			reservoir_idx = which(group_id == 0L)
			if (length(reservoir_idx) > 0L)
				group_id[reservoir_idx] = max(group_id) + seq_along(reservoir_idx)
			# X WITHOUT intercept (cutpoints serve as intercepts)
			if (ncol(as.matrix(private$X)) > 0){
				X_fit = as.matrix(private$glmm_predictors_df())  # [w, cov1, ...]
			} else {
				X_fit = matrix(private$w, ncol = 1L, dimnames = list(NULL, "w"))
			}
			# Convert y to 1-indexed integers
			y_levels = sort(unique(private$y))
			K = length(y_levels)
			y = as.integer(match(private$y, y_levels))
			n_alpha = K - 1L
			# Treatment is always the first column of X_fit (j_T = 0, 0-based)
			j_T = 0L
			
			start_len = n_alpha + ncol(X_fit) + 1L
			warm_start = private$get_fit_warm_start_for_length("params", start_len)
			
			# Warm start from fixed-effects ordinal MLE to avoid divergence if no cache
			start = if (!is.null(warm_start)) warm_start else tryCatch({
				nore = fast_ordinal_regression_cpp(X_fit, as.numeric(y) - 1L)
				alpha_direct = as.numeric(nore$alpha)  # K-1 direct cutpoints
				beta_nore    = as.numeric(nore$b)      # p betas
				# Convert direct alphas to log-diff parameterization
				alpha_par = numeric(n_alpha)
				if (n_alpha >= 1L) alpha_par[1L] = alpha_direct[1L]
				if (n_alpha >= 2L) {
					for (k in 2L:n_alpha) {
						diff_k = alpha_direct[k] - alpha_direct[k - 1L]
						alpha_par[k] = if (diff_k > 0) log(diff_k) else 0.0
					}
				}
				c(alpha_par, beta_nore, -3.0)  # log_sigma = -3 (small random effect)
			}, error = function(e) NULL)
			
			fit = tryCatch(
				fast_ordinal_glmm_cpp(
					X          = X_fit,
					y          = y,
					group_id   = as.integer(group_id),
					K          = K,
					j_T        = j_T,
					smart_cold_start = private$smart_cold_start_default,
					estimate_only = estimate_only,
					warm_start_params = start,
					eps_g      = 1e-6,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(start_len),
					optimization_alg = private$optimization_alg
				),
				error = function(e) NULL
			)
			private$cached_values$optimizer_diagnostics = if (is.null(fit)) NULL else list(
				converged = fit$converged %||% FALSE,
				num_iter = fit$num_iter %||% NA_integer_,
				hit_iteration_cap = fit$hit_iteration_cap %||% NA,
				gradient_norm = fit$gradient_norm %||% NA_real_,
				neg_loglik = fit$neg_loglik %||% NA_real_,
				log_sigma = fit$log_sigma %||% NA_real_,
				newton_polish_attempted = fit$newton_polish_attempted %||% FALSE,
				newton_polish_accepted = fit$newton_polish_accepted %||% FALSE,
				newton_polish_iterations = fit$newton_polish_iterations %||% 0L,
				variance_boundary_hit = fit$variance_boundary_hit %||% NA
			)
			if (is.null(fit) || !isTRUE(fit$converged) ||
				!isFALSE(fit$hit_iteration_cap) || !is.finite(as.numeric(fit$gradient_norm)[1L])) {
				private$cache_nonestimable_estimate("kk_glmm_rcpp_failed")
				return(invisible(NULL))
			}
			# b is the beta vector (no cutpoints); treatment is at index j_T+1 (1-based R)
			beta_hat_T = as.numeric(fit$b[j_T + 1L])
			fit_params = as.numeric(c(fit$alpha, fit$b, fit$log_sigma))
			upper_variance_boundary = is.finite(fit$log_sigma) &&
				fit$log_sigma >= 8.0 - 1e-4
			if (any(!is.finite(fit_params)) || !is.finite(beta_hat_T) ||
				abs(beta_hat_T) > private$max_abs_reasonable_coef || upper_variance_boundary) {
				private$cache_nonestimable_estimate("kk_glmm_rcpp_nonestimable")
				return(invisible(NULL))
			}
			private$cached_mod = fit
			full_params = fit_params
			private$set_fit_warm_start(full_params, "params", fisher = fit$fisher_information)

			private$cached_values$likelihood_test_context = list(
				X = X_fit,
				y = y,
				group_id = as.integer(group_id),
				K = K,
				j_treat = length(fit$alpha) + 1L,
				n_gh = 20L,
				start = full_params
			)
			private$cached_values$beta_hat_T = beta_hat_T
			private$cached_values$df   = Inf
			if (estimate_only) return(invisible(NULL))
			ssq = as.numeric(fit$ssq_b_T)[1L]
			if (!is.null(ssq) && is.finite(ssq) && ssq > 0) {
				private$cached_values$s_beta_hat_T = sqrt(ssq)
			} else {
				j_in_full = length(fit$alpha) + 1L
				hess = tryCatch(as.matrix(fit$fisher_information), error = function(e) NULL)
				se_fallback = NA_real_
				if (!is.null(hess) && is.matrix(hess) && nrow(hess) >= j_in_full) {
					vcov_hess = tryCatch(solve(hess), error = function(e) NULL)
					if (!is.null(vcov_hess) && is.finite(vcov_hess[j_in_full, j_in_full]) && vcov_hess[j_in_full, j_in_full] > 0) {
						se_fallback = sqrt(vcov_hess[j_in_full, j_in_full])
					}
				}
				private$cached_values$s_beta_hat_T = se_fallback
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) ||
				private$cached_values$s_beta_hat_T <= 0 ||
				private$cached_values$s_beta_hat_T > private$max_abs_reasonable_coef) {
				private$cache_nonestimable_estimate("kk_glmm_rcpp_variance_nonestimable")
				return(invisible(NULL))
			}
		},
		get_likelihood_test_spec = function(){
			if (!isTRUE(private$use_rcpp)) return(NULL)
			private$shared(estimate_only = FALSE)
			ctx = private$cached_values$likelihood_test_context
			if (is.null(ctx) || is.null(private$cached_mod)) return(NULL)
			X_fit = ctx$X
			y = as.integer(ctx$y)
			group_id = as.integer(ctx$group_id)
			K = as.integer(ctx$K)
			j_treat = as.integer(ctx$j_treat)
			n_gh = as.integer(ctx$n_gh %||% 20L)
			list(
				X = X_fit,
				y = y,
				group_id = group_id,
				K = K,
				j = j_treat,
				n_gh = n_gh,
				full_fit = private$cached_mod,
				fit_null = function(delta, start = NULL){
					run_fit = function(s){
						n_params = length(ctx$start)
						tryCatch(
							fast_ordinal_glmm_cpp(
								X = X_fit,
								y = y,
								group_id = group_id,
								K = K,
								j_T = 0L,
								smart_cold_start = private$smart_cold_start_default,
								estimate_only = FALSE,
								n_gh = n_gh,
								max_abs_log_sigma = 8.0,
								maxit = 300L,
								eps_g = 1e-6,
								warm_start_params = s,
								warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
								optimization_alg = private$optimization_alg %||% "lbfgs",
								fixed_idx = j_treat,
								fixed_values = delta
							),
							error = function(e) NULL
						)
					}
					warm_start = start %||% private$get_fit_warm_start_for_length("params", length(ctx$start)) %||% ctx$start
					fit = run_fit(warm_start)
					# If warm start caused failure, retry with the canonical default start
					if (is.null(fit) || !isTRUE(fit$converged)) {
						if (!identical(warm_start, ctx$start)) {
							fit2 = run_fit(ctx$start)
							if (!is.null(fit2) && isTRUE(fit2$converged)) fit = fit2
						}
					}
					fit_ok = !is.null(fit) && isTRUE(fit$converged) &&
						isFALSE(fit$hit_iteration_cap) &&
						all(is.finite(as.numeric(c(fit$alpha, fit$b, fit$log_sigma)))) &&
						is.finite(as.numeric(fit$neg_loglik)[1L]) &&
						is.finite(as.numeric(fit$gradient_norm)[1L]) &&
						is.finite(as.numeric(fit$b[1L])) &&
						abs(as.numeric(fit$b[1L])) <= private$max_abs_reasonable_coef &&
						as.numeric(fit$log_sigma)[1L] < 8.0 - 1e-4
					if (!fit_ok) return(NULL)
					if (!is.null(fit)) {
						fit$params = tryCatch(as.numeric(c(fit$alpha, fit$b, fit$log_sigma)), error = function(e) NULL)
					}
					fit
				},
				extract_start = function(fit){
					as.numeric(c(fit$alpha, fit$b, fit$log_sigma))
				},
				score = function(fit){
					as.numeric(fit$score)
				},
				observed_information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information)
				},
				fisher_information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information)
				},
				information = function(fit){
					as.matrix(fit$fisher_information %||% fit$information %||% fit$observed_information)
				},
				neg_loglik = function(fit){
					as.numeric(fit$neg_loglik %||% fit$neg_ll)
				}
			)
		},
		supports_lik_ratio_param_bootstrap = function() isTRUE(private$use_rcpp),
		simulate_under_lik_null = function(spec, delta, null_fit){
			if (!isTRUE(private$use_rcpp)) return(NULL)
			params_null = as.numeric(c(null_fit$alpha, null_fit$b, null_fit$log_sigma))
			y = as.integer(spec$y)
			K = as.integer(spec$K)
			group_id = as.integer(spec$group_id)
			X_fit = spec$X
			j_treat = spec$j
			n = nrow(X_fit)
			G = max(group_id)
			n_alpha = K - 1L
			n_gh = as.integer(spec$n_gh %||% 20L)
			n_params = length(params_null)

			alpha_par = params_null[seq_len(n_alpha)]
			alpha_direct = numeric(n_alpha)
			alpha_direct[1L] = alpha_par[1L]
			if (n_alpha >= 2L) {
				for (k in seq(2L, n_alpha))
					alpha_direct[k] = alpha_direct[k - 1L] + exp(alpha_par[k])
			}
			betas = params_null[(n_alpha + 1L):(n_alpha + ncol(X_fit))]
			log_sigma = params_null[length(params_null)]
			sigma = exp(min(log_sigma, 8.0))
			if (!is.finite(sigma) || sigma <= 0) return(NULL)

			u = rnorm(G, 0, sigma)
			eta = as.numeric(X_fit %*% betas) + u[group_id]
			y_sim = integer(n)
			for (i in seq_len(n)) {
				cum_p = plogis(alpha_direct - eta[i])
				cat_p = pmax(c(cum_p[1L], diff(cum_p), 1 - cum_p[n_alpha]), 0)
				s = sum(cat_p)
				y_sim[i] = if (is.finite(s) && s > 0) sample.int(K, 1L, prob = cat_p / s) else 1L
			}
			if (length(unique(y_sim)) < K) return(NULL)

			warm_start = private$get_fit_warm_start_for_length("params", n_params) %||% params_null
			fit = tryCatch(
				fast_ordinal_glmm_cpp(
					X = X_fit, y = y_sim, group_id = group_id, K = K,
					j_T = 0L,
					smart_cold_start = private$smart_cold_start_default,
					estimate_only = FALSE,
					n_gh = n_gh,
					warm_start_params = warm_start,
					warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
					optimization_alg = private$optimization_alg %||% "lbfgs"
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !isTRUE(fit$converged) || !isFALSE(fit$hit_iteration_cap) ||
				any(!is.finite(as.numeric(c(fit$alpha, fit$b, fit$log_sigma)))) ||
				!is.finite(as.numeric(fit$gradient_norm)[1L]) ||
				as.numeric(fit$log_sigma)[1L] >= 8.0 - 1e-4 ||
				abs(as.numeric(fit$b[1L])) > private$max_abs_reasonable_coef) return(NULL)
			full_fit_boot = list(
				alpha = fit$alpha, b = fit$b, log_sigma = fit$log_sigma,
				params = as.numeric(c(fit$alpha, fit$b, fit$log_sigma)),
				neg_loglik = as.numeric(fit$neg_loglik %||% fit$neg_ll)
			)
			if (!is.finite(full_fit_boot$neg_loglik)) return(NULL)

			list(
				full_fit = full_fit_boot,
				fit_null = function(d, start = NULL){
					ws = start %||% private$get_fit_warm_start_for_length("params", n_params) %||% params_null
					fit2 = tryCatch(
						fast_ordinal_glmm_cpp(
							X = X_fit, y = y_sim, group_id = group_id, K = K,
							j_T = 0L,
							smart_cold_start = TRUE,
							estimate_only = FALSE,
							n_gh = n_gh,
							warm_start_params = ws,
							warm_start_fisher_info = private$get_fit_warm_start_fisher(n_params),
							optimization_alg = private$optimization_alg %||% "lbfgs",
							fixed_idx = j_treat, fixed_values = d
						),
						error = function(e) NULL
					)
					if (is.null(fit2) || !isTRUE(fit2$converged) || !isFALSE(fit2$hit_iteration_cap) ||
						any(!is.finite(as.numeric(c(fit2$alpha, fit2$b, fit2$log_sigma)))) ||
						!is.finite(as.numeric(fit2$gradient_norm)[1L]) ||
						as.numeric(fit2$log_sigma)[1L] >= 8.0 - 1e-4 ||
						abs(as.numeric(fit2$b[1L])) > private$max_abs_reasonable_coef) return(NULL)
					list(
						alpha = fit2$alpha, b = fit2$b, log_sigma = fit2$log_sigma,
						params = as.numeric(c(fit2$alpha, fit2$b, fit2$log_sigma)),
						neg_loglik = as.numeric(fit2$neg_loglik %||% fit2$neg_ll)
					)
				},
				neg_loglik = function(fit) as.numeric(fit$neg_loglik)
			)
		}
	),
	overrides = list(
		public = c(
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval",
			"get_supported_testing_types", "set_testing_type"
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
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"assert_finite_se",
			"supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"get_likelihood_test_spec",
			"simulate_under_lik_null",
			"shared",
			"get_complexity_tier"
		)
	)
)
