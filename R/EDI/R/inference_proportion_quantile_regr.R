#' Quantile Regression Inference for Proportion Responses
#'
#' Fits a quantile regression for proportion responses (constrained to (0, 1)) using
#' the treatment indicator and, optionally, all recorded covariates as predictors.
#' Inference is performed on the \strong{logit (log-odds) scale}: responses
#' \eqn{y \in (0,1)} are transformed via \eqn{\text{logit}(y) = \log(y/(1-y))} before
#' quantile regression, so the estimated treatment effect is a \strong{log-odds-ratio
#' shift} at quantile \code{tau}; by default \code{tau = 0.5}, so this is a median
#' log-odds-ratio shift.
#'
#' Fitting is via \pkg{quantreg} (method \code{"fn"}, the Frisch-Newton interior-point
#' algorithm, for both the estimate-only \code{rq.fit} call and the variance-computing
#' \code{\link[quantreg]{rq}} fit; the Bayesian-bootstrap reweighted fit uses
#' \code{rq}'s default \code{"br"} method) on \code{logit(y) ~ w + covariates}
#' with no intercept column (the design matrix already carries one). Standard errors use
#' \pkg{quantreg}'s Powell (1991) kernel sandwich \code{"nid"} estimator (heteroskedasticity-
#' and design-robust, valid under non-i.i.d. errors) when available, falling back to the
#' i.i.d.-errors \code{"iid"} estimator if \code{"nid"} extraction fails; inference on the
#' resulting standard error uses the asymptotic normal (Wald) approximation, not a
#' resampling-based reference distribution, for the asymptotic CI/p-value paths.
#' \code{compute_asymp_confidence_interval}/\code{compute_asymp_two_sided_pval} use the
#' fit's residual degrees of freedom \eqn{n - p} in a \eqn{t}-reference (via
#' \code{compute_z_or_t_ci_from_s_and_df}) rather than a plain normal reference, so the
#' interval/test remain slightly conservative in small samples relative to a bare Wald z.
#'
#' This class requires the \pkg{quantreg} package, which is listed under
#' \code{Suggests} and is not installed automatically with \pkg{EDI}.
#' Install \pkg{quantreg} manually before use. Only uncensored proportion responses are
#' supported (checked via \code{assertNoCensoring} at construction).
#'
#' @references Koenker, R. and Bassett, G. (1978). "Regression Quantiles."
#'   \emph{Econometrica}, 46(1), 33-50, \doi{10.2307/1913643}, for quantile regression itself.
#'   Powell, J. L. (1991). "Estimation of Monotonic Regression Models under Quantile
#'   Restrictions," in \emph{Nonparametric and Semiparametric Methods in Econometrics and
#'   Statistics}, Cambridge University Press, for the \code{"nid"} sandwich standard error.
#' @seealso \code{\link[EDI:InferenceContinQuantileRegr]{InferenceContinQuantileRegr}} for the
#'   untransformed (continuous-scale) analogue of this class.
#' @examples
#' if (requireNamespace("quantreg", quietly = TRUE)) {
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 10, response_type = 'proportion')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(runif(10))
#' inf = InferencePropQuantileRegr$new(seq_des)
#' inf$compute_estimate()
#' }
#' }
#' @concept quantile regression
#' @inheritSection InferenceContinOLS Blocking designs
#' @eval rd_small_sample_section("InferencePropQuantileRegr")
#' @export
InferencePropQuantileRegr = define_inference_class(
	classname = "InferencePropQuantileRegr",
	inherit = Inference,
	components = c(
		"RandomizationCI",
		"RandomizationBootstrapCI",
		"BayesianBootstrap",
		"Jackknife",
		"Wald"
	),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,

		#' @description Initialize a quantile-regression inference object for a completed design
		#' with a proportion response.
		#' @param des_obj A completed \code{Design} object with a proportion response.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param tau The quantile to estimate. Default 0.5.
		#' @param verbose Whether to print progress messages. Default FALSE.
		initialize = function(des_obj, model_formula = NULL, tau = 0.5,  verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "proportion")
				assertNumeric(tau, len = 1, lower = .Machine$double.eps, upper = 1 - .Machine$double.eps, any.missing = FALSE)
				assertFormula(model_formula, null.ok = TRUE)
			}
			if (should_run_asserts()) {
				if (!check_package_installed("quantreg")) {
					stop("Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").")
				}
			}
			super$initialize(des_obj, model_formula = model_formula, verbose = verbose)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}


			private$tau = tau
		},
		#' @description Computes the fitted treatment coefficient of the \code{tau}-quantile
		#'   regression of \code{logit(y)} on the treatment indicator (plus any adjustment
		#'   covariates) — a \strong{log-odds-ratio shift at quantile \code{tau}} of the
		#'   proportion response, not a difference in means or in the raw-scale quantile.
		#'   Caches \code{beta_hat_T} (and, unless \code{estimate_only}, the standard error
		#'   and residual degrees of freedom) so repeated calls are cheap; returns
		#'   \code{NA_real_} if the reduced design matrix is degenerate (fewer usable rows
		#'   than columns) or the \pkg{quantreg} fit fails/errors.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes \code{compute_estimate}'s treatment log-odds-ratio-shift
		#'   coefficient with each subject's (or block's) contribution to the \code{tau}-quantile
		#'   fit reweighted by \code{subject_or_block_weights} (expanded to per-row weights and
		#'   passed as \code{quantreg::rq(..., weights = ...)}), for the Bayesian bootstrap
		#'   contract; see \code{\link[EDI:InferenceBayesianBootstrap]{InferenceBayesianBootstrap}}.
		#'   \strong{Writes into the same \code{beta_hat_T}/\code{s_beta_hat_T}/\code{df} cache
		#'   fields that \code{compute_estimate} reads from} — a call to this method overwrites
		#'   the cached original-data estimate with the bootstrap-reweighted one, so a subsequent
		#'   \code{compute_estimate()} call will return the \emph{bootstrap replicate's} value
		#'   from cache rather than recomputing on the original data, until the cache is reset by
		#'   whatever higher-level bootstrap driver owns this object's lifecycle. Returns
		#'   \code{NA_real_} under the same degenerate-design/fit-failure conditions as
		#'   \code{compute_estimate}.
		#' @param subject_or_block_weights Bootstrap weights at the subject or block level.
		#' @param estimate_only If TRUE, skip variance calculations.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			private$compute_quantile_estimate_with_bootstrap_weights(subject_or_block_weights, estimate_only = estimate_only)
		},
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha The confidence level in the computed confidence
		#'   interval is 1 - \code{alpha}. The default is 0.05.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			if (should_run_asserts()) {
				assertNumeric(alpha, len = 1, lower = .Machine$double.xmin, upper = 1 - .Machine$double.eps, any.missing = FALSE)
			}
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta The null difference to test against. Default is zero.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1, finite = TRUE, any.missing = FALSE)
			}
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	# Shared with the other quantile class (QuantileRegrSharedPrivate,
	# v1.0.6-TODO-193); only the response scale and the quantreg solvers differ.
	private = c(QuantileRegrSharedPrivate, list(
		quantile_logit_response = TRUE,
		quantile_estimate_method = "fn",
		quantile_full_method = "fn"
	)),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"get_standard_error", "get_degrees_of_freedom",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate",
			"compute_fast_randomization_distr",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported"
		)
	),
	metadata = list(likelihood_tier = "none")
)
