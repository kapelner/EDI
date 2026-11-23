#' Zero-Inflated Poisson Regression Inference for Count Responses
#'
#' Fits a zero-inflated Poisson regression for count responses: a binary
#' excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' Poisson count submodel \eqn{\log E[Y_i \mid \text{not structural zero},
#' w_i, x_i] = \beta_0 + \beta_T w_i + x_i^\top \gamma}. Unlike a hurdle
#' model, zero counts can arise from either the structural-zero mechanism or
#' from an ordinary Poisson draw of \eqn{0}, so the two mixture components are
#' not identified by disjoint support. The zero-inflation and count submodels may use
#' different covariate formulas (\code{model_formula}/\code{model_formula_zero}).
#' The reported treatment effect is the coefficient from the conditional count
#' component, on the log-rate scale, \strong{conditional on the response
#' coming from the count process, not the excess-zero-inflation mechanism}:
#' it is not the effect on the unconditional mean \eqn{E[Y]}, which also
#' depends on how treatment shifts the excess-zero probability, under the
#' default \code{estimand = "conditional"}. \code{likelihood_tier = "full"}:
#' Wald, score, gradient, and (bootstrap-calibrated) likelihood-ratio tests
#' are available for the count submodel's treatment coefficient under that
#' estimand. \strong{Jackknife inference
#' is not supported}: delete-one refits of this two-part mixture model are
#' numerically unstable, so \code{compute_jackknife_estimate()} and related
#' methods report explicit non-estimability rather than attempting
#' delete-one refits.
#'
#' \strong{Data with no zeros.} A zero-inflated mixture needs zero counts:
#' with none, the maximum-likelihood structural-zero probability is 0 (its
#' logits diverge to \eqn{-\infty}) and the zero-inflation submodel is not
#' identified. The constructor therefore stops with an error when the
#' response has no zeros (as \code{pscl::zeroinfl()} does); use
#' \code{\link[EDI:InferenceCountPoisson]{InferenceCountPoisson}} instead. \strong{Inside
#' resampling} -- a nonparametric- or Bayesian-bootstrap replicate, or a
#' parametric-bootstrap simulation, that happens to contain no zeros (common
#' when the data have few) -- the replicate is \strong{not} dropped and does
#' not error: it falls back to the non-inflated Poisson fit of the count
#' part (the zero-inflation coefficients are fixed so that the structural-zero
#' probability is effectively 0). That is the boundary value of the
#' zero-inflated MLE, so the treatment coefficient is the Poisson
#' regression's; dropping such replicates would bias the resampling
#' distribution toward replicates that happen to contain zeros.
#'
#' \strong{Marginal (unconditional-mean) estimand.} Via
#' \code{\link[EDI:InferenceMarginalEstimand]{set_estimand()}}, this class
#' also supports \code{estimand = "marginal_mean_diff"} and
#' \code{"marginal_ratio"}: the g-computation average, over the empirical
#' covariate distribution, of the model-implied unconditional mean
#' \eqn{E[Y_i \mid w_i, x_i] = (1 - \pi(x_i)) \lambda(x_i)} (the untruncated
#' Poisson mean weighted by the non-structural-zero probability) at
#' \eqn{w_i = 1} vs. \eqn{w_i = 0} — a mean difference or, on the log scale,
#' a mean ratio. This is a pure post-fit transform of the same maximum-
#' likelihood fit (no refit), with a delta-method standard error computed
#' against the sandwich-robust covariance matrix already used for this
#' class's conditional Wald inference. Only \code{"wald"}-type inference is
#' available under a marginal estimand (no likelihood-ratio/score/gradient
#' test, since the marginal quantity is a functional of the fitted
#' parameters, not itself a likelihood).
#'
#' \strong{Omitted covariates.} When covariates that drive the outcome are
#' left out of the formula (for example \code{~ 1}), the Poisson count part is
#' overdispersed (in the calibration study's design, variance about twice the
#' mean), so the model-based standard error is too small. The score, gradient
#' and likelihood-ratio tests then reject a true null about 16-17\% of the time
#' at a nominal 5\% level, at n = 50, 200 and 1000 alike. This is model
#' misspecification, so it does not go away with more data. The Wald test,
#' which uses a sandwich covariance, stays calibrated in this setting: prefer
#' it, adjust for the prognostic covariates, or use
#' \code{\link[EDI:InferenceCountZeroInflatedNegBin]{InferenceCountZeroInflatedNegBin}},
#' which models the overdispersion.
#'
#' \strong{Aliased count-part covariates.} The count-part coefficients are
#' learned from the subjects with a positive count: the zero counts inform them
#' only through the mixture with the excess-zero part, which leaves a direction
#' those subjects do not identify essentially flat (the fit used to wander along
#' it, with no usable standard error). A count-part covariate can be aliased on
#' those subjects (constant among them, or a linear combination of the intercept,
#' the treatment and the covariates before it) even when it varies over the whole
#' sample.
#' Such a covariate has no identified count-part coefficient, so it is dropped
#' from the count part before fitting, with one warning of class
#' \code{edi_covariate_dropped_warning} naming it (silent inside resampling;
#' every randomization, bootstrap and Bayesian-bootstrap refit applies the same
#' rule to its own data). This is the same as what \code{\link[stats]{glm}} does:
#' with its default \code{singular.ok = TRUE}, \code{glm} fits a singular design
#' by leaving the aliased columns out of its pivoted QR decomposition and reports
#' their coefficients as \code{NA} (with \code{singular.ok = FALSE} a singular fit
#' is an error); the dropped count-part coefficients are likewise \code{NA} in
#' this class's coefficient vector. As in \code{glm}, columns are checked in
#' design order (intercept, treatment, then the covariates), and a column is
#' dropped when it adds nothing given the columns kept before it. The treatment
#' is never dropped: when it is itself aliased on those subjects (for example,
#' all of them are in one arm), its count-part coefficient is not identified and
#' the estimate is \code{NA}.
#'
#' \strong{Separated zero-inflation part.} The zero-inflation logit often has no
#' finite maximum: some fitted zero-inflation probabilities run off to 0 or 1
#' (for example no excess zeros in one arm), and the likelihood keeps rising
#' along a flat ridge. The class then (i) also fits from
#' \code{pscl::zeroinfl()}'s default start (a Poisson GLM for the count part, a
#' logistic GLM of \eqn{1(y = 0)} for the zero part) with L-BFGS, and again
#' from that start with its zero part multiplied by 10, and keeps the fit with
#' the lowest negative log-likelihood, which also escapes an interior local
#' maximum of the default start (see "Small samples" below for the limit of
#' this); (ii) reports the zero-inflation coefficients as \code{NA} when a
#' fitted zero-inflation probability is numerically 0 or 1, or the fit stopped on such a ridge, and says why once per
#' object: when the ridge points only toward no inflation (every subject it
#' drives to the boundary goes to probability 0, and no fitted zero-inflation
#' probability exceeds 5\%; typical of data without excess zeros), with a
#' message of class \code{edi_no_zero_inflation_message} ("no evidence of zero
#' inflation"); otherwise (some subject pushed to a structural zero, or sizeable
#' inflation next to subjects pushed to 0) with a warning of class
#' \code{edi_zero_part_separation_warning} (a subclass of
#' \code{edi_logistic_separation_warning}); in both cases the count-part
#' treatment estimate is kept, since the count part is identified in the ridge
#' limit; and (iii) never warm-starts a randomization, bootstrap or
#' parametric-bootstrap refit from a full-data fit whose zero part is on the
#' ridge (a fitted zero-inflation logit of 10 or more in absolute value): such a
#' refit could not move its zero part and stopped below the maximum, so it is
#' cold-started like a fresh fit (v1.0.6-TODO-30, v1.0.6-TODO-152).
#'
#' \strong{Small samples with covariates in the zero-inflation formula.} At
#' small \eqn{n} with continuous covariates in \code{model_formula_zero} (the
#' default, which copies \code{model_formula}), the ZIP maximum-likelihood
#' estimate often does not exist: the likelihood is highest on a separated
#' zero-part ridge, where the zero-inflation part sorts some zeros away from
#' every positive count, and it can also have several interior local maxima.
#' EDI tries several starts and warns
#' (\code{edi_zero_part_separation_warning}) when the fit reaches the ridge, but
#' some fits can still stop at a lower interior local maximum without any
#' warning: about 41 of 602 unflagged fits in a 1,197-dataset simulation sweep
#' (\eqn{n} = 24 to 400). \code{pscl::zeroinfl()} stops at the same kind of
#' point, so agreement with pscl does not rule this out. On a ridge the
#' count-part treatment estimate is only weakly defined: different ridges give
#' different limits. In this setting use a treatment-only zero-inflation
#' formula, \code{model_formula_zero = ~ 1} (the zero part always includes the
#' treatment, so this fits an intercept and the treatment), and keep the
#' covariates in the count part (v1.0.6-TODO-232).
#'
#' @references Lambert, D. (1992). "Zero-Inflated Poisson Regression, with an
#'   Application to Defects in Manufacturing." \emph{Technometrics}, 34(1),
#'   1-14, \doi{10.2307/1269547}, for the zero-inflated count-model
#'   framework.
#'
#' @seealso \code{\link[EDI:InferenceCountPoisson]{InferenceCountPoisson}} for
#'   the single-part Poisson model this class's count submodel generalizes;
#'   \code{\link[EDI:InferenceCountHurdlePoisson]{InferenceCountHurdlePoisson}}
#'   for the related hurdle (disjoint-support) variant;
#'   \code{\link[EDI:InferenceCountZeroInflatedNegBin]{InferenceCountZeroInflatedNegBin}}
#'   for the overdispersion-robust negative-binomial variant (does not
#'   support a marginal estimand — the mean-function derivation here is
#'   Poisson-specific).
#'
#' @examples
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 30, response_type = 'count')
#' for (i in 1:30) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' # about 30% structural zeros in both arms, so the zero part is identified
#' y = rpois(30, 3)
#' y[rbinom(30, 1, 0.3) == 1] = 0L
#' y[1:2] = 0L # a zero-inflated model needs zero counts
#' seq_des$add_all_subject_responses(y)
#' inf = InferenceCountZeroInflatedPoisson$new(seq_des, model_formula_zero = ~ 1)
#' inf$compute_estimate()
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceCountZeroInflatedPoisson")
#' @export
InferenceCountZeroInflatedPoisson = define_inference_class(
	classname = "InferenceCountZeroInflatedPoisson",
	inherit = InferenceCountZeroAugmentedPoissonAbstract,
	# 2026-08-23 (marginal_estimand_report.md TODO-5): converted from a plain
	# R6::R6Class leaf of the abstract to a real define_inference_class()
	# call of its own, the only way to compose a new component
	# ("MarginalEstimand") on top of an already-factory-built abstract
	# without silently handing the (Poisson-specific, NegBin-invalid)
	# capability to the NegBin sibling sharing the same abstract. Mirrors
	# InferencePropZeroOneInflatedBetaRegr's TODO-4 conversion exactly.
	components = "MarginalEstimand",
	# metadata$likelihood_tier must be restated explicitly here even though
	# the inherited abstract's own effective tier is already "full" --
	# MarginalEstimand's allowed_likelihood_tiers = c("partial", "full") is
	# validated against THIS class's own declared metadata at
	# define_inference_class() time, not the inherited value (same reason
	# ZOIB's TODO-4 conversion needed to restate it).
	metadata = list(likelihood_tier = "full"),
	overrides = list(
		public = c(
			"compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		private = "get_supported_estimands_impl"
	),
	public = list(
		#' @description Initialize inference for the zero-inflated Poisson model
		#'   (binary excess-zero submodel mixed with a Poisson count submodel); see
		#'   \code{\link[EDI:InferenceCountZeroInflatedPoisson]{InferenceCountZeroInflatedPoisson}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula Optional formula for the count submodel.
		#' @param model_formula_zero Formula for the zero-inflation submodel. If
		#'   \code{NULL} (default), it uses the same formula as \code{model_formula}.
		#'   The treatment is always included. At small \eqn{n} with continuous
		#'   covariates here the maximum-likelihood estimate often does not exist,
		#'   and a fit can stop at an interior local maximum without a warning;
		#'   prefer \code{~ 1} (treatment only) there (see "Small samples with
		#'   covariates in the zero-inflation formula" in the class Details).
		#' @param use_rcpp Logical. If \code{TRUE} (default), use our internal Rcpp
		#'   implementation. If \code{FALSE}, use \pkg{glmmTMB}.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		#' @param optimization_alg Optimization algorithm. Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, model_formula_zero = model_formula_zero, use_rcpp = use_rcpp, verbose = verbose, smart_cold_start_default = smart_cold_start_default, optimization_alg = optimization_alg)
		},
		#' @description Fits the zero-inflated Poisson model. Under the default
		#'   \code{estimand = "conditional"}, returns \eqn{\hat\beta_T}, the
		#'   treatment log-rate coefficient from the conditional count submodel
		#'   (see the class-level caveat that this is conditional on the response
		#'   coming from the count process, not an unconditional-mean effect).
		#'   Under \code{estimand = "marginal_mean_diff"} or
		#'   \code{"marginal_ratio"} (set via \code{set_estimand()}), returns the
		#'   g-computation marginal mean difference or log-scale marginal ratio
		#'   of the unconditional mean \eqn{E[Y \mid w, x] = (1-\pi(x))\lambda(x)}
		#'   instead — a pure post-fit transform of the same cached fit, no refit.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap
		#'   resampling paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			estimand = self$get_estimand()
			if (estimand %in% c("marginal_mean_diff", "marginal_ratio")) {
				return(private$compute_marginal_estimand_estimate(estimand, estimate_only = estimate_only))
			}
			# 2026-08-23 (marginal_estimand_report.md TODO-5): re-derive the
			# conditional beta_hat_T/s_beta_hat_T from the estimand-invariant
			# private$cached_mod every call (same fix as ZOIB's TODO-4
			# compute_estimate()) so switching the estimand back to
			# "conditional" after a marginal computation doesn't return stale
			# marginal numbers left in private$cached_values by shared()'s own
			# short-circuit guard.
			mod = private$cached_mod
			if (!is.null(mod)) {
				private$cached_values$beta_hat_T = as.numeric(mod$beta_hat_T %||% mod$params[2L])[1L]
				if (!estimate_only) {
					ssq = mod$ssq_b_j
					ssq = if (length(ssq) >= 1L) as.numeric(ssq)[1L] else NA_real_
					if (is.finite(ssq) && ssq > .Machine$double.eps) {
						private$cached_values$s_beta_hat_T = sqrt(ssq)
						private$clear_nonestimable_state()
					} else {
						private$cache_nonestimable_se("model_standard_error_unavailable")
					}
				}
			}
			private$cached_values$beta_hat_T
		},
		#' @description Asymptotic confidence interval. Under the conditional
		#'   estimand, the interval of the test chosen with \code{set_testing_type()}:
		#'   score, gradient, likelihood-ratio and Bartlett-corrected
		#'   likelihood-ratio give the same interval as the matching
		#'   \code{compute_<type>_confidence_interval()} (before 1.0.6 every type
		#'   returned Wald, v1.0.6-TODO-413); the default Wald interval is \code{NA},
		#'   with the reason recorded and an \code{edi_wald_unavailable_warning}, when
		#'   the model standard error is unavailable (no bootstrap is substituted,
		#'   v1.0.6-TODO-380). Under a marginal estimand (Wald only), the
		#'   delta-method interval computed by \code{compute_estimate()}. Calls
		#'   \code{self$compute_estimate()} first (not \code{private$shared()}
		#'   directly) so the estimand-aware cache is always current regardless
		#'   of call order.
		#' @param alpha The significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			self$compute_estimate(estimate_only = FALSE)
			if (self$get_estimand() %in% c("marginal_mean_diff", "marginal_ratio")) {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_ci_from_s_and_df(alpha))
				}
				return(private$count_likelihood_missing_ci(alpha))
			}
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) {
				return(private$count_likelihood_missing_ci(alpha))
			}
			# v1.0.6-TODO-413: honor set_testing_type() (this always returned Wald).
			if (!identical(private$testing_type, "wald")) {
				return(za_count_asymp_by_testing_type(self, private, ci = TRUE, value = alpha))
			}
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				# v1.0.6-TODO-380: a Wald request gets Wald or NA, never the bootstrap
				# interval this used to substitute (see edi_wald_unavailable_na()).
				return(edi_wald_unavailable_na(self, private, alpha = alpha))
			}
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Asymptotic two-sided p-value, dispatched exactly as
		#'   \code{compute_asymp_confidence_interval()}; see that method's
		#'   description for the marginal-estimand path.
		#' @param delta The null treatment effect under the current estimand
		#'   (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			self$compute_estimate(estimate_only = FALSE)
			if (self$get_estimand() %in% c("marginal_mean_diff", "marginal_ratio")) {
				if (is.finite(private$cached_values$s_beta_hat_T %||% NA_real_)) {
					return(private$compute_z_or_t_two_sided_pval_from_s_and_df(delta))
				}
				return(NA_real_)
			}
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			if (private$mark_count_likelihood_block_asymp_nonestimable()) return(NA_real_)
			# v1.0.6-TODO-413: see compute_asymp_confidence_interval().
			if (!identical(private$testing_type, "wald")) {
				return(za_count_asymp_by_testing_type(self, private, ci = FALSE, value = delta))
			}
			se = private$get_standard_error()
			if (is.finite(se) && se > 0) {
				private$cached_values$s_beta_hat_T = se
			}
			if (!is.finite(private$cached_values$s_beta_hat_T) || private$cached_values$s_beta_hat_T <= 0){
				# v1.0.6-TODO-380: see compute_asymp_confidence_interval().
				return(edi_wald_unavailable_na(self, private))
			}
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		za_family = function() stats::poisson(link = "log"),
		za_description = function() "Zero-Inflated Poisson",
		# 2026-08-23 (marginal_estimand_report.md TODO-5): every class
		# composing MarginalEstimand supports only "conditional" by default
		# (the component's own get_supported_estimands_impl()); overridden
		# here to add the g-computation marginal mean difference and
		# log-scale marginal ratio of the unconditional mean.
		get_supported_estimands_impl = function(){
			c("conditional", "marginal_mean_diff", "marginal_ratio")
		}
	)
)
#' Zero-Inflated Negative Binomial Regression Inference for Count Responses
#'
#' Fits a zero-inflated negative binomial regression for count responses: a
#' binary excess-zero submodel \eqn{P(\text{structural zero}_i) =
#' \mathrm{logit}^{-1}(X_i^{h\top} \gamma^h)} mixed with a (non-truncated)
#' negative-binomial count submodel \eqn{\log E[Y_i \mid \text{not structural
#' zero}, w_i, x_i] = \beta_0 + \beta_T w_i + x_i^\top \gamma},
#' \eqn{\mathrm{Var}(Y_i \mid \text{not structural zero}) = \mu_i + \mu_i^2 /
#' \theta}. Unlike a hurdle model, zero counts can arise from either the
#' structural-zero mechanism or from an ordinary negative-binomial draw of
#' \eqn{0}. The zero-inflation and count submodels may use different covariate
#' formulas (\code{model_formula}/\code{model_formula_zero}). The reported
#' treatment effect is the coefficient from the conditional count component,
#' on the log-rate scale, \strong{conditional on the response coming from the
#' count process, not the excess-zero-inflation mechanism}: it is not the
#' effect on the unconditional mean \eqn{E[Y]}, which also depends on how
#' treatment shifts the excess-zero probability. A marginal
#' (unconditional-mean) estimand is not yet implemented for this class (see
#' \code{marginal_estimand_report.md}). \code{likelihood_tier = "full"}:
#' Wald, gradient, score, and (bootstrap-calibrated) likelihood-ratio tests
#' are all available for the count submodel's treatment coefficient, as for
#' the Poisson variant.
#' \strong{Jackknife inference is not supported}: delete-one refits of this
#' two-part mixture model with a jointly-estimated dispersion parameter are
#' numerically unstable, so \code{compute_jackknife_estimate()} and related
#' methods report explicit non-estimability rather than attempting
#' delete-one refits.
#'
#' \strong{Data with no zeros.} A zero-inflated mixture needs zero counts:
#' with none, the maximum-likelihood structural-zero probability is 0 (its
#' logits diverge to \eqn{-\infty}) and the zero-inflation submodel is not
#' identified. The constructor therefore stops with an error when the
#' response has no zeros (as \code{pscl::zeroinfl()} does); use
#' \code{\link[EDI:InferenceCountNegBin]{InferenceCountNegBin}} instead. \strong{Inside
#' resampling} -- a nonparametric- or Bayesian-bootstrap replicate, or a
#' parametric-bootstrap simulation, that happens to contain no zeros (common
#' when the data have few) -- the replicate is \strong{not} dropped and does
#' not error: it falls back to the non-inflated negative binomial fit of the count
#' part (the zero-inflation coefficients are fixed so that the structural-zero
#' probability is effectively 0). That is the boundary value of the
#' zero-inflated MLE, so the treatment coefficient is the negative binomial
#' regression's; dropping such replicates would bias the resampling
#' distribution toward replicates that happen to contain zeros.
#'
#' \strong{Many covariates in small samples.} With few subjects per parameter
#' the zero-inflated negative binomial fit is often degenerate: in the
#' calibration study at n = 50 with 5 covariates (15 parameters), about half the
#' fits had a separated zero-inflation logit (a coefficient beyond 10 in
#' absolute value) and about a quarter had the dispersion at its Poisson
#' boundary. The model-based tests are then oversized at a nominal 5\% level:
#' Wald and score reject a true null about 18-19\% of the time, likelihood-ratio
#' about 14\% and gradient about 15\%. On the non-degenerate fits the
#' likelihood-ratio test is close to nominal (about 5\%), but Wald and score stay
#' high because the model-based standard error is about 35\% too small. This is
#' a small-sample property of the model, not a defect of the fit; it fades by
#' n = 200. At small n, adjust for fewer covariates or prefer the likelihood-ratio
#' test.
#'
#' \strong{Fitting.} The default Newton-Raphson fitter can stop at a fit that is
#' not the maximum-likelihood fit: at the zero-inflation-off negative binomial
#' fit, or on a ridge where the zero-inflation logit is separated. This happens
#' most often on the permuted or resampled data of randomization and bootstrap
#' draws. Every fit the class makes is therefore checked: a fit that did not
#' converge, sits at the zero-inflation boundary, has a zero-inflation
#' coefficient beyond 10 in absolute value, or has a gradient norm above
#' \eqn{10^{-5}} is refit with L-BFGS from a cold start and from the warm start,
#' and the fit with the highest likelihood is kept. The estimates then agree with
#' \code{pscl::zeroinfl()}. The extra refits make small, sparse samples slower.
#'
#' \strong{Aliased count-part covariates.} The count-part coefficients are
#' learned from the subjects with a positive count: the zero counts inform them
#' only through the mixture with the excess-zero part, which leaves a direction
#' those subjects do not identify essentially flat (the fit used to wander along
#' it, with no usable standard error). A count-part covariate can be aliased on
#' those subjects (constant among them, or a linear combination of the intercept,
#' the treatment and the covariates before it) even when it varies over the whole
#' sample.
#' Such a covariate has no identified count-part coefficient, so it is dropped
#' from the count part before fitting, with one warning of class
#' \code{edi_covariate_dropped_warning} naming it (silent inside resampling;
#' every randomization, bootstrap and Bayesian-bootstrap refit applies the same
#' rule to its own data). This is the same as what \code{\link[stats]{glm}} does:
#' with its default \code{singular.ok = TRUE}, \code{glm} fits a singular design
#' by leaving the aliased columns out of its pivoted QR decomposition and reports
#' their coefficients as \code{NA} (with \code{singular.ok = FALSE} a singular fit
#' is an error); the dropped count-part coefficients are likewise \code{NA} in
#' this class's coefficient vector. As in \code{glm}, columns are checked in
#' design order (intercept, treatment, then the covariates), and a column is
#' dropped when it adds nothing given the columns kept before it. The treatment
#' is never dropped: when it is itself aliased on those subjects (for example,
#' all of them are in one arm), its count-part coefficient is not identified and
#' the estimate is \code{NA}.
#'
#' \strong{Separated zero-inflation part.} The zero-inflation logit often has no
#' finite maximum: some fitted zero-inflation probabilities run off to 0 or 1
#' (for example no excess zeros in one arm). The class then reports the
#' zero-inflation coefficients as \code{NA} when a fitted zero-inflation
#' probability is numerically 0 or 1, the fit stopped on such a ridge, or it is
#' the zero-inflation-off boundary fit, and says why once per object: a message
#' of class \code{edi_no_zero_inflation_message} ("no evidence of zero
#' inflation") when the ridge points only toward no inflation (the boundary fit,
#' or every subject driven to probability 0 with no fitted zero-inflation
#' probability above 5\%), otherwise a warning of class
#' \code{edi_zero_part_separation_warning} (a subclass of
#' \code{edi_logistic_separation_warning}). The count-part treatment estimate is
#' kept. It never warm-starts a randomization, bootstrap or parametric-bootstrap
#' refit from a full-data fit whose zero part is on the ridge (a fitted
#' zero-inflation logit of 10 or more in absolute value): such a refit could not
#' move its zero part, so it is cold-started like a fresh fit (v1.0.6-TODO-30,
#' v1.0.6-TODO-152).
#'
#' @references Lambert, D. (1992). "Zero-Inflated Poisson Regression, with an
#'   Application to Defects in Manufacturing." \emph{Technometrics}, 34(1),
#'   1-14, \doi{10.2307/1269547}, for the zero-inflated count-model
#'   framework.
#'
#' @seealso \code{\link[EDI:InferenceCountNegBin]{InferenceCountNegBin}} for
#'   the single-part negative binomial model this class's count submodel
#'   generalizes;
#'   \code{\link[EDI:InferenceCountZeroInflatedPoisson]{InferenceCountZeroInflatedPoisson}}
#'   for the Poisson (equidispersed) variant.
#'
#' @examples
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 40, response_type = 'count')
#' for (i in 1:40) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' # overdispersed counts with about 30% structural zeros in both arms
#' y = rnbinom(40, mu = 5, size = 2)
#' y[rbinom(40, 1, 0.3) == 1] = 0L
#' y[1:2] = 0L # a zero-inflated model needs zero counts
#' seq_des$add_all_subject_responses(y)
#' \donttest{
#' inf = InferenceCountZeroInflatedNegBin$new(seq_des, model_formula = ~ x1, model_formula_zero = ~ 1)
#' inf$compute_estimate()
#' }
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferenceCountZeroInflatedNegBin")
#' @export
InferenceCountZeroInflatedNegBin = R6::R6Class("InferenceCountZeroInflatedNegBin",
	lock_objects = FALSE,
	inherit = InferenceCountZeroAugmentedPoissonAbstract,
	public = list(
		#' @description Initialize inference for the zero-inflated negative
		#'   binomial model (binary excess-zero submodel mixed with a
		#'   negative-binomial count submodel); see
		#'   \code{\link[EDI:InferenceCountZeroInflatedNegBin]{InferenceCountZeroInflatedNegBin}}
		#'   for the model form. Does not fit the model; the fit is deferred to the
		#'   first call to \code{compute_estimate()} or a method that requires it.
		#' @param des_obj A completed \code{Design} object with a count response.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param model_formula_zero Formula for the zero-inflation submodel. If
		#'   \code{NULL} (default), it uses the same formula as \code{model_formula}.
		#'   The treatment is always included, so \code{~ 1} fits the zero-inflation
		#'   probability on the treatment only.
		#' @param use_rcpp Logical. If \code{TRUE} (default), use our internal Rcpp
		#'   implementation. If \code{FALSE}, use \pkg{glmmTMB}.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		#' @param optimization_alg Optimization algorithm. Default is dispatched via policy.
		initialize = function(des_obj, model_formula = NULL, model_formula_zero = NULL, use_rcpp = TRUE, verbose = FALSE, smart_cold_start_default = NULL, optimization_alg = NULL){
			super$initialize(des_obj, model_formula = model_formula, model_formula_zero = model_formula_zero, use_rcpp = use_rcpp, verbose = verbose, smart_cold_start_default = smart_cold_start_default, optimization_alg = optimization_alg)
		},
		#' @description Fits the zero-inflated negative binomial model and returns
		#'   \eqn{\hat\beta_T}, the treatment log-rate coefficient from the
		#'   conditional count submodel. This class supports only the
		#'   \code{"conditional"} estimand; a marginal (unconditional-mean)
		#'   estimand is not yet implemented.
		#' @param estimate_only If TRUE, skip standard-error computation and cache
		#'   only the point estimate; used by randomization and bootstrap
		#'   resampling paths.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			# No marginal-estimand branch: ZINB does not compose MarginalEstimand,
			# so get_estimand() is always "conditional" (Inference base) and
			# set_estimand() stops (docs-claims-d03ccf4c6).
			# Keep the point estimate when the native ZINB fit is usable but its
			# guarded covariance is not. This mirrors the ZIP/Hurdle-Poisson
			# wrappers and records typed SE nonestimability for the public API.
			mod = private$cached_mod
			if (!is.null(mod)) {
				private$cached_values$beta_hat_T = as.numeric(mod$beta_hat_T %||% mod$params[2L])[1L]
				if (!estimate_only) {
					ssq = mod$ssq_b_j
					ssq = if (length(ssq) >= 1L) as.numeric(ssq)[1L] else NA_real_
					if (is.finite(ssq) && ssq > .Machine$double.eps) {
						private$cached_values$s_beta_hat_T = sqrt(ssq)
						private$clear_nonestimable_state()
					} else {
						private$cache_nonestimable_se("model_standard_error_unavailable")
					}
				}
			}
			private$cached_values$beta_hat_T
		}
	),
	private = list(
		za_family = function() glmmTMB::nbinom2(link = "log"),
		za_description = function() "Zero-Inflated Negative Binomial",
		get_supported_testing_types_impl = function(){
			c("wald", "score", "lik_ratio", "gradient")
		}
	)
)
