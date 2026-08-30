#' Fast Logistic Regression, Estimate Only (C++ Backend)
#'
#' Fits the standard binary logistic regression model,
#' \eqn{\mathrm{logit}(\mu_i) = \Pr(Y_i = 1) \text{'s log-odds} = x_i^\top \beta},
#' \eqn{\mu_i = \mathrm{logit}^{-1}(x_i^\top \beta)}, via maximum likelihood.
#' Coefficients are directly interpretable as \strong{log odds ratios}:
#' \eqn{e^{\beta_j}} is the multiplicative change in the odds
#' \eqn{\mu_i / (1 - \mu_i)} per unit change in covariate \eqn{j}. This is the
#' package's baseline binary-response fitting backend, used wherever an
#' incidence/binary outcome needs a logit-link fit (as opposed to the log-link
#' or identity-link constrained binomial models in
#' \code{\link{fast_log_binomial_regression_cpp}}/
#' \code{\link{fast_identity_binomial_regression_cpp}}, which target relative
#' risk / risk difference scales instead of odds ratios).
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be binary (0 or 1).
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}.
#'   If provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta}
#'   is supplied, use an OLS-based initial guess rather than a zero cold start.
#'   Default \code{FALSE} for this function (unlike most of the package's other
#'   \code{fast_*} fitters, which default this to \code{TRUE}), since IRLS
#'   (the default optimizer here) is typically robust enough from a zero start
#'   for well-behaved logistic regression problems.
#' @param  maxit Maximum number of iterations for the algorithm. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed
#'   rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default,
#'   classical iteratively-reweighted-least-squares Fisher scoring),
#'   \code{"lbfgs"}, or \code{"newton_raphson"}; see
#'   \code{\link{.normalize_optimizer_algorithm}}.
#' @param warm_start_weights Optional initial IRLS working weights for the
#'   first iteration.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information.
#' @param estimate_only Logical. If \code{TRUE}, skip the working-weights/
#'   score/Fisher-information computation after convergence, returning only
#'   \code{b}, \code{converged}, \code{num_iter}, \code{hit_iteration_cap}, and
#'   \code{gradient_norm}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated logistic regression coefficients \eqn{\hat\beta}.}
#' \item{w}{The IRLS working weights \eqn{\hat\mu_i(1-\hat\mu_i)} at the final
#'   iteration (the Bernoulli variance function evaluated at the fitted
#'   probabilities); omitted when \code{estimate_only = TRUE}.}
#' \item{num_iter}{The number of optimizer iterations performed.}
#' \item{fisher_information}{The working-weights curvature matrix
#'   \eqn{X^\top W X}; omitted when \code{estimate_only = TRUE}.}
#' \item{score}{The score (gradient of the log-likelihood) vector at the fitted
#'   coefficients; omitted when \code{estimate_only = TRUE}.}
#' \item{neg_ll}{The negative log-likelihood at the fitted coefficients;
#'   omitted when \code{estimate_only = TRUE}.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below \code{tol} (\code{gradient_norm < tol}); uniform across the
#'   \code{"irls"}/\code{"lbfgs"} optimizers.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the score vector at the returned
#'   coefficients, a diagnostic of how tightly the convergence criterion was
#'   met.}
#' }
#' @seealso \code{\link{fast_logistic_regression_with_var_cpp}} for the
#'   variance-augmented variant; \code{\link{fast_logistic_regression}} for the
#'   R-level wrapper; \code{\link{fast_log_binomial_regression_cpp}}/
#'   \code{\link{fast_identity_binomial_regression_cpp}} for the log-link/
#'   identity-link analogs targeting relative-risk/risk-difference scales.
#' @export
#' @usage fast_logistic_regression_cpp(
#'   X,
#'   y,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL,
#'   estimate_only = FALSE
#' )
#' @name fast_logistic_regression_cpp
NULL

#' Normalize and Validate an Optimizer Algorithm Name for the \code{fast_*} C++ Backends
#'
#' Internal helper shared by the package's \code{fast_*} GLM/survival/ordinal fitting
#' wrappers (e.g. \code{\link{fast_logistic_regression}},
#' \code{\link{fast_coxph_regression}}) to resolve a user-supplied
#' \code{optimization_alg} argument to one of the fixed set of optimizer names the
#' underlying C++ backends actually implement, applying a model-specific default when
#' none is supplied and rejecting anything else. This centralizes the
#' default/validation logic so each \code{fast_*} wrapper does not have to repeat it.
#'
#' @details
#' The three possible optimizer names, when supported by a given model, correspond to
#' distinct fitting algorithms in the C++ backends: \code{"newton_raphson"} (full
#' Newton-Raphson using the analytic Hessian), \code{"lbfgs"} (limited-memory
#' quasi-Newton, avoiding an explicit Hessian), and \code{"irls"} (iteratively
#' reweighted least squares, the classical GLM-fitting algorithm — only meaningful,
#' and only offered, for exponential-family GLMs, hence gated by \code{allow_irls}).
#' Which optimizers a given \code{fast_*} function actually accepts (and which is its
#' default) varies by model; this function only encodes the generic
#' irls-vs-not-irls split, not per-model specifics.
#'
#' \code{optimization_alg} is matched against the allowed set via
#' \code{\link[base]{match.arg}}, so unambiguous partial string matches (e.g.
#' \code{"newton"}) are accepted; an unmatched or ambiguous value raises
#' \code{match.arg}'s standard error rather than silently falling back to the default.
#' \code{missing(optimization_alg)} or an explicit \code{NULL} both resolve to
#' \code{default} before matching.
#'
#' @param optimization_alg Character string (possibly abbreviated) naming the desired
#'   optimizer, \code{NULL}, or missing entirely; see Details for resolution order.
#' @param allow_irls Logical. Whether \code{"irls"} is a valid choice (and the default
#'   default) for this model; \code{FALSE} restricts the allowed set to
#'   \code{c("lbfgs", "newton_raphson")}.
#' @param default Character string used when \code{optimization_alg} is missing or
#'   \code{NULL}. Defaults to \code{"irls"} when \code{allow_irls = TRUE}, else
#'   \code{"lbfgs"}.
#' @return A validated, unabbreviated character string: one of
#'   \code{"newton_raphson"}, \code{"lbfgs"}, or (only when \code{allow_irls = TRUE})
#'   \code{"irls"}.
#' @seealso \code{\link[base]{match.arg}}, which performs the validation/partial-matching.
#' @keywords internal
#' @export
.normalize_optimizer_algorithm = function(optimization_alg, allow_irls = FALSE, default = if (allow_irls) "irls" else "lbfgs"){
	if (missing(optimization_alg) || is.null(optimization_alg)) optimization_alg = default
	valid = if (allow_irls) c("irls", "lbfgs", "newton_raphson") else c("lbfgs", "newton_raphson")
	match.arg(optimization_alg, valid)
}

#' Fast Cox Proportional Hazards Regression, One-Shot Fit (C++ Backend)
#'
#' Fits the unstratified Cox proportional-hazards partial-likelihood model
#' documented in full at \code{\link{build_cox_data_cache_cpp}} — the same model,
#' Breslow tie-handling, and input conventions — in a single call that internally
#' builds the sorted risk-set cache, runs the optimizer, and discards the cache
#' afterward. Use this entry point for a one-off fit; use
#' \code{\link{build_cox_data_cache_cpp}} plus
#' \code{\link{fast_coxph_regression_prebuilt_cpp}} instead when fitting the same
#' \code{(X, y, dead)} repeatedly (e.g. across bootstrap/randomization replicates),
#' to avoid rebuilding the risk-set cache on every call. \code{\link{fast_coxph_regression}}
#' is the R-level wrapper around this backend (with an \pkg{survival}-free-of-Rcpp
#' fallback path via \pkg{glmnet}).
#'
#' @param  X A numeric matrix of predictor variables (no intercept column; see
#'   \code{\link{build_cox_data_cache_cpp}}).
#' @param  y Numeric vector of observed (event or censoring) times.
#' @param  dead Numeric vector with values in \code{{0, 1}}: event indicator
#'   (1 = event, 0 = right-censored).
#' @param warm_start_beta Optional starting values for the coefficients \eqn{\beta}.
#' @param smart_cold_start Logical. If \code{TRUE} (default) and no
#'   \code{warm_start_beta} is supplied, use an OLS-based initial guess rather than
#'   a zero cold start.
#' @param estimate_only Logical. If \code{TRUE}, skip variance-covariance
#'   matrix calculation for speed.
#' @param maxit Maximum number of Newton-Raphson/L-BFGS iterations.
#' @param tol Convergence tolerance.
#' @param cluster Optional clustering variable; when supplied, the returned
#'   variance-covariance matrix uses a cluster-robust (grouped) sandwich correction
#'   instead of the naive model-based inverse-information variance, i.e. one that
#'   remains asymptotically valid under within-cluster correlation of the
#'   martingale residuals.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather
#'   than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at; must be the same length as \code{fixed_idx}.
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information for the optimizer.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the estimated log-hazard-ratio
#'   coefficients \eqn{\hat\beta}.}
#' \item{vcov}{The variance-covariance matrix of \eqn{\hat\beta} (naive
#'   inverse-information, or cluster-robust sandwich if \code{cluster} is supplied);
#'   omitted/not computed when \code{estimate_only = TRUE}.}
#' \item{neg_ll}{The negative Cox partial log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' \item{iterations}{The number of optimizer iterations performed.}
#' \item{fisher_information}{The Hessian of the negative partial log-likelihood at
#'   the fitted coefficients (the observed information matrix).}
#' \item{gradient_norm}{The norm of the score (gradient) vector at convergence, a
#'   diagnostic of how tightly the convergence criterion was met.}
#' }
#'
#' @seealso \code{\link{build_cox_data_cache_cpp}} for the full Cox partial-likelihood
#'   model, Breslow tie-handling, and input conventions this function implements;
#'   \code{\link{fast_coxph_regression_prebuilt_cpp}} for the cache-reusing variant;
#'   \code{\link{fast_coxph_regression}} for the R-level wrapper.
#' @export
#' @usage fast_coxph_regression_cpp(
#'   X,
#'   y,
#'   dead,
#'   warm_start_beta = NULL,
#'   smart_cold_start = TRUE,
#'   estimate_only = FALSE,
#'   maxit = 20L,
#'   tol = 1e-9,
#'   cluster = NULL,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "newton_raphson",
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_coxph_regression_cpp
NULL

#' Fast Weibull Regression with General Censoring (C++ Backend)
#'
#' @param estimate_only Logical. If \code{TRUE}, skip variance-covariance
#'   matrix calculation for speed.
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the estimated Weibull regression coefficients,
#' including the intercept.}
#' \item{log_sigma}{The logarithm of the scale parameter from the Weibull distribution.}
#' \item{vcov}{The variance-covariance matrix of the estimated coefficients.}
#' \item{neg_ll}{The negative log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' }
#'
#' @export
#' @name fast_weibull_regression_general_cpp
NULL

#' Fast Beta Regression (C++ Backend)
#'
#' @param  start_phi A numeric value, the starting value for the precision parameter phi.
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the estimated beta regression coefficients.}
#' \item{phi}{The estimated precision parameter phi.}
#' \item{neg_ll}{The negative log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' }
#'
#' @export
#' @name fast_beta_regression_cpp
NULL

#' Fast Beta Regression with Variance Calculation (C++ Backend)
#'
#' @param  start_phi A numeric value, the starting value for the precision parameter phi.
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the obtained Poisson regression coefficients.}
#' \item{phi}{The estimated precision parameter phi.}
#' \item{vcov}{The variance-covariance matrix.}
#' \item{neg_ll}{The negative log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' }
#'
#' @export
#' @name fast_beta_regression_with_var_cpp
NULL

#' Fast Negative Binomial Regression, Estimate Only (C++ Backend)
#'
#' Fits the negative-binomial regression model in its mean/dispersion
#' parameterization documented in full at
#' \code{\link{fast_dnbinom_mu_vec_cpp}}: log link
#' \eqn{\log \mu_i = x_i^\top \beta} (so \eqn{e^{\beta_j}} is a multiplicative
#' change in the mean count, as in Poisson regression), with a single
#' dispersion parameter \eqn{\theta} shared across all observations and
#' \eqn{\mathrm{Var}(Y_i) = \mu_i + \mu_i^2/\theta} (smaller \eqn{\theta} means
#' more overdispersion relative to Poisson; \eqn{\theta \to \infty} recovers
#' Poisson). The optimizer's parameter vector is \code{c(beta, log(theta))}
#' (\eqn{\theta} optimized on the log scale for positivity).
#'
#' @param X A numeric matrix of predictors, \eqn{n \times p}; include an
#'   explicit intercept column if desired (no implicit intercept).
#' @param y A numeric (integer-valued) vector of non-negative observed counts,
#'   length \eqn{n}.
#' @param warm_start_params Optional starting values for coefficients and dispersion. If provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
#' @param maxit Maximum number of optimizer iterations.
#' @param eps_f Convergence tolerance on the objective (log-likelihood) value.
#' @param eps_g Convergence tolerance on the gradient norm (the tolerance
#'   actually passed through to the optimizer as its primary stopping
#'   criterion).
#' @param fixed_idx Optional integer indices (into the \code{c(beta, log(theta))}
#'   parameter layout) of parameters to hold fixed rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or \code{"newton_raphson"}.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information for the optimizer.
#' @param estimate_only Logical; if \code{TRUE}, may skip work not needed to
#'   produce point estimates (kept in sync with the package's other
#'   \code{fast_*} estimate-vs-inference split).
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated negative binomial regression coefficients \eqn{\hat\beta}.}
#' \item{theta_hat}{The estimated dispersion parameter \eqn{\hat\theta} (natural scale).}
#' \item{logLik}{The model's log-likelihood at the fitted parameters.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below the convergence tolerance (\code{gradient_norm < tol}); uniform
#'   across the \code{"lbfgs"}/\code{"newton_raphson"} optimizers.}
#' \item{num_iter}{The number of optimizer iterations performed.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the gradient at the returned parameters.}
#' \item{fisher_information}{The working-weights curvature matrix used during
#'   fitting.}
#' }
#' @seealso \code{\link{fast_dnbinom_mu_vec_cpp}} for the mean/dispersion
#'   density parameterization used here; \code{\link{fast_neg_bin_with_var_cpp}}
#'   for the variance-augmented variant.
#' @export
#' @name fast_neg_bin_cpp
NULL

#' Fast Negative Binomial Regression with Variance Calculation (C++ Backend)
#'
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the obtained Poisson regression coefficients.}
#' \item{hess_fisher_info_matrix}{The Fisher information matrix.}
#' \item{neg_ll}{The negative log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below the convergence tolerance (\code{gradient_norm < tol}); uniform
#'   across the \code{"lbfgs"}/\code{"newton_raphson"} optimizers.}
#' \item{num_iter}{The number of optimizer iterations performed.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the gradient at the returned parameters.}
#' }
#'
#' @export
#' @name fast_neg_bin_with_var_cpp
NULL

#' Fast Ordinary Least Squares (OLS) Regression, Estimate-Only (C++ Backend)
#'
#' Solves the ordinary least squares normal equations
#' \eqn{\hat\beta = (X^\top X)^{-1} X^\top y} via Eigen's \code{LDLT} Cholesky
#' decomposition of \eqn{X^\top X}; if that decomposition fails (e.g. \eqn{X}
#' is rank-deficient), it falls back to a column-pivoted QR decomposition of
#' \eqn{X} directly (\code{Eigen::ColPivHouseholderQR}), which returns a
#' minimum-norm least-squares solution even when \eqn{X} is not full rank.
#' Estimate-only: no standard errors or covariance matrix are computed, only
#' the coefficient vector \eqn{\hat\beta}.
#'
#' @section Fixed (offset) coefficients:
#' \code{fixed_idx} (1-indexed columns
#'   of \code{X}) and \code{fixed_values} optionally hold a subset of coefficients at
#'   caller-supplied constant values rather than estimating them: those columns'
#'   contribution \eqn{X_{\mathrm{fixed}} \beta_{\mathrm{fixed}}} is subtracted out of
#'   \code{y} first, and only the remaining ("free") columns are fit by least squares;
#'   the fixed coefficients are then copied back into \eqn{\hat\beta} unchanged. This is
#'   used, e.g., to fit a model with a known/offset intercept without re-estimating it.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the (continuous) response variable.
#' @param fixed_idx Optional integer vector of 1-indexed columns of \code{X} whose
#'   coefficients should be held fixed at \code{fixed_values} rather than estimated.
#' @param fixed_values Optional numeric vector, parallel to \code{fixed_idx}, of the
#'   fixed coefficient values.
#'
#' @return  A list containing the following component:
#' \describe{
#' \item{b}{A numeric vector of the estimated regression coefficients \eqn{\hat\beta}
#'   (with any \code{fixed_idx} entries set to \code{fixed_values}); if the solve
#'   produces non-finite values, this is instead a vector of \code{NaN}.}
#' }
#'
#' @seealso \code{\link{fast_ols_with_var_cpp}} for the variance-computing counterpart.
#'
#' @usage fast_ols_cpp(X, y, fixed_idx = NULL, fixed_values = NULL)
#' @name fast_ols_cpp
#' @rdname fast_ols_cpp
#' @export
NULL

#' Fast Ordinary Least Squares (OLS) Regression with Variance (C++ Backend)
#'
#' As \code{\link{fast_ols_cpp}}, but additionally computes the classical OLS
#' variance estimate \eqn{\hat\sigma^2 = \mathrm{SSE} / (n - p)} (with
#' \eqn{\mathrm{SSE} = y^\top y - \hat\beta^\top X^\top y} on the fixed-parameter-adjusted
#' response, and \eqn{p} the number of \strong{free} — non-fixed — columns) and the
#' sampling variance of two coefficients, \eqn{\widehat{\mathrm{Var}}(\hat\beta_k) =
#' \hat\sigma^2 \, [(X^\top X)^{-1}]_{kk}}, obtained from the same Cholesky (\code{LDLT})
#' factorization used to solve for \eqn{\hat\beta}, without forming the full inverse
#' matrix. If the \code{LDLT} decomposition fails (rank-deficient \eqn{X}), this function
#' falls back to a QR solve exactly as \code{\link{fast_ols_cpp}} does, but in that case
#' \strong{no variance quantities are computed}: \code{ssq_b_j}, \code{ssq_b_2}, and
#' \code{XtX} are omitted from the result and \code{converged} is \code{FALSE}.
#'
#' @inheritSection fast_ols_cpp Fixed (offset) coefficients
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the (continuous) response variable.
#' @param j This function will compute the variance of the jth (1-indexed) coefficient
#'   estimator. Default is 2 (conventionally the treatment effect).
#' @param fixed_idx Optional integer vector of 1-indexed columns of \code{X} whose
#'   coefficients should be held fixed at \code{fixed_values} rather than estimated.
#' @param fixed_values Optional numeric vector, parallel to \code{fixed_idx}, of the
#'   fixed coefficient values.
#'
#' @return  A list containing the following components (the last four only present
#'   when the \code{LDLT} solve succeeds):
#' \describe{
#' \item{b}{A numeric vector of the estimated regression coefficients \eqn{\hat\beta}.}
#' \item{converged}{\code{TRUE} if the \code{LDLT} solve succeeded, \code{FALSE} if the
#'   QR fallback was used.}
#' \item{sigma2_hat}{The estimated residual variance \eqn{\hat\sigma^2}.}
#' \item{XtX}{The (free-coefficient) \eqn{X^\top X} matrix, expanded back to full
#'   \eqn{p \times p} shape with zeros in the fixed-coefficient rows/columns.}
#' \item{ssq_b_j}{The variance of the \eqn{j}-th coefficient estimator, \code{NA} if
#'   \code{j} indexes a fixed coefficient.}
#' \item{ssq_b_2}{The variance of the second coefficient estimator specifically
#'   (typically the treatment effect), regardless of what \code{j} is; equal to
#'   \code{ssq_b_j} when \code{j = 2}. \code{NA} if the second column is a fixed
#'   coefficient.}
#' }
#'
#' @seealso \code{\link{fast_ols_cpp}} for the estimate-only counterpart.
#'
#' @usage fast_ols_with_var_cpp(X, y, j = 2L, fixed_idx = NULL, fixed_values = NULL)
#' @name fast_ols_with_var_cpp
#' @rdname fast_ols_with_var_cpp
#' @export
NULL

#' Fast Poisson Regression, Estimate-Only (C++ Backend)
#'
#' Fits a Poisson regression with the canonical log link, \eqn{Y_i \sim
#' \mathrm{Poisson}(\mu_i)}, \eqn{\mu_i = \exp(x_i^\top\beta)} (with \eqn{\eta_i =
#' x_i^\top\beta} clamped above at 700 before exponentiating, to avoid overflow),
#' by maximum likelihood. By default (\code{optimization_alg = "irls"}), fitting
#' uses iteratively reweighted least squares: at each iteration the Fisher-scoring
#' (Poisson canonical-link, so Fisher = observed) system \eqn{X^\top W X \, \delta =
#' X^\top(y - \mu)} is solved via \code{Eigen::LDLT}, with a backtracking
#' step-halving line search (up to 10 halvings) accepting the step only if it does
#' not increase the negative log-likelihood; convergence is declared when the score
#' norm falls below \code{tol}. Passing \code{optimization_alg = "lbfgs"} or
#' \code{"newton_raphson"} instead routes through the generic likelihood optimizer
#' (\code{\link[EDI:.normalize_optimizer_algorithm]{.normalize_optimizer_algorithm}}) on the raw (non-IRLS)
#' negative log-likelihood/gradient/Hessian.
#'
#' @section Fixed parameters, warm starts:
#' \code{fixed_idx} and \code{fixed_values} optionally hold a subset of coefficients
#' fixed at caller-supplied constant values (their contribution is folded into the
#' linear predictor as an offset) rather than estimated. \code{warm_start_beta}
#' supplies starting coefficients directly; otherwise, if \code{smart_cold_start =
#' TRUE}, a Poisson-specific heuristic start is used, and if
#' \code{warm_start_fisher_info} is also supplied (or, absent that, when
#' \code{smart_cold_start = TRUE}), it seeds the curvature estimate used for the
#' very first IRLS step (or first quasi-Newton step, for the non-IRLS algorithms).
#' \code{warm_start_weights} is accepted for interface parity with sibling
#' functions but is \strong{not consulted anywhere} in this function's fitting
#' logic.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be nonnegative-integer counts.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
#'   provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta} is
#'   supplied, use a Poisson-specific heuristic initial guess rather than a zero cold start.
#' @param  maxit Maximum number of iterations. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default), \code{"lbfgs"}, or \code{"newton_raphson"}.
#' @param warm_start_weights Accepted but unused; see Details.
#' @param warm_start_fisher_info Optional initial curvature (information) matrix to warm-start the first iteration.
#' @param estimate_only If \code{TRUE}, skip computing \code{mu}, \code{XtWX}/\code{fisher_information},
#'   and \code{score}, returning only \code{b}, \code{converged},
#'   \code{num_iter}, \code{hit_iteration_cap}, and \code{gradient_norm}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated Poisson regression coefficients \eqn{\hat\beta}.}
#' \item{mu}{(omitted if \code{estimate_only = TRUE}) The fitted means \eqn{\hat\mu_i}.}
#' \item{XtWX, fisher_information}{(omitted if \code{estimate_only = TRUE}) Two aliases for the
#'   same curvature matrix \eqn{X^\top W X} (\eqn{W = \mathrm{diag}(\hat\mu_i)}) at the fitted
#'   coefficients — the Fisher information, which for the canonical log link coincides with the
#'   observed information.}
#' \item{score}{(omitted if \code{estimate_only = TRUE}) The score vector \eqn{X^\top(y - \hat\mu)}
#'   at the fitted coefficients.}
#' \item{neg_ll}{(omitted if \code{estimate_only = TRUE}) The negative log-likelihood at the fitted coefficients.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below \code{tol} (\code{gradient_norm < tol}); uniform across the
#'   \code{"irls"}/\code{"lbfgs"}/\code{"newton_raphson"} optimizers.}
#' \item{num_iter}{The number of iterations performed.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the score vector at the returned
#'   coefficients.}
#' }
#' @seealso \code{\link{fast_poisson_regression_weighted_cpp}} for the observation-weighted
#'   variant; \code{\link{fast_poisson_regression_with_var_cpp}} for the variance-computing
#'   variant; \code{\link{fast_quasipoisson_regression_with_var_cpp}} for the
#'   overdispersion-corrected variant.
#'
#' @export
#' @usage fast_poisson_regression_cpp(
#'   X,
#'   y,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL,
#'   estimate_only = FALSE
#' )
#' @name fast_poisson_regression_cpp
NULL

#' Fast Poisson Regression with Variance Calculation (C++ Backend)
#'
#' Fits the same Poisson log-link model as \code{\link{fast_poisson_regression_cpp}}
#' (see that page for the full model and optimizer contract; always with
#' \code{estimate_only = FALSE}), and additionally inverts the fitted Fisher
#' information matrix (\code{Eigen::LDLT} on the free-coefficient submatrix, via
#' \code{compute_diagonal_inverse_entry}) to report the variance of two
#' coefficients.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be nonnegative-integer counts.
#' @param  j The 1-indexed coefficient whose variance to compute in \code{ssq_b_j}. Defaults to 2.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
#'   provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta} is
#'   supplied, use a Poisson-specific heuristic initial guess rather than a zero cold start.
#' @param  maxit Maximum number of iterations. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default), \code{"lbfgs"}, or \code{"newton_raphson"}.
#' @param warm_start_weights Accepted but unused; see \code{\link{fast_poisson_regression_cpp}} Details.
#' @param warm_start_fisher_info Optional initial curvature (information) matrix to warm-start the first iteration.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b, params}{A numeric vector of the estimated Poisson regression coefficients \eqn{\hat\beta} (both aliases of the same vector).}
#' \item{ssq_b_j}{The variance of the \eqn{j}-th coefficient estimator; \code{NA} if \code{j} indexes a fixed coefficient.}
#' \item{ssq_b_2}{The variance of the second coefficient estimator specifically (typically the
#'   treatment effect), regardless of what \code{j} is; equal to \code{ssq_b_j} when \code{j = 2}.
#'   \code{NA} if the second column is a fixed coefficient.}
#' \item{mu}{The fitted means \eqn{\hat\mu_i}.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below \code{tol} (\code{gradient_norm < tol}); uniform across the
#'   \code{"irls"}/\code{"lbfgs"}/\code{"newton_raphson"} optimizers.}
#' \item{num_iter}{The number of iterations performed.}
#' \item{score}{The score vector at the fitted coefficients.}
#' \item{observed_information, fisher_information, information}{Three aliases for the same
#'   \eqn{X^\top W X} curvature matrix (\code{information_type} is always \code{"fisher"}).}
#' \item{hessian}{The negative of that same matrix (the actual Hessian of the log-likelihood).}
#' \item{neg_loglik, neg_ll}{The negative log-likelihood at the fitted coefficients (two aliases).}
#' \item{loglik}{The log-likelihood (\code{-neg_ll}), or \code{NA} if \code{neg_ll} is non-finite.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the score vector at the returned
#'   coefficients.}
#' }
#' @seealso \code{\link{fast_poisson_regression_cpp}} for the estimate-only variant and full
#'   model documentation; \code{\link{fast_quasipoisson_regression_with_var_cpp}} for the
#'   overdispersion-corrected variant.
#'
#' @export
#' @usage fast_poisson_regression_with_var_cpp(
#'   X,
#'   y,
#'   j = 2L,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_poisson_regression_with_var_cpp
NULL

#' Fast Quasi-Poisson Regression with Variance Calculation (C++ Backend)
#'
#' Fits the same Poisson log-link mean model as \code{\link{fast_poisson_regression_cpp}}
#' (see that page for the full model and optimizer contract; point estimates \eqn{\hat\beta}
#' are identical to what that function would return), but instead of the plain Poisson
#' Fisher-information-based variance, scales it by an estimated \strong{overdispersion}
#' parameter to obtain quasi-likelihood standard errors that are robust to
#' variance-mean deviations from the strict Poisson assumption
#' \eqn{\mathrm{Var}(Y_i) = \mu_i}. The dispersion is the Pearson-statistic-based
#' moment estimator,
#' \deqn{\hat\phi = \frac{1}{n-p}\sum_{i=1}^n \frac{(y_i - \hat\mu_i)^2}{\hat\mu_i},}
#' computed only when the residual degrees of freedom \eqn{n - p > 0}; the reported
#' coefficient variances are then \eqn{\widehat{\mathrm{Var}}(\hat\beta_k) = \hat\phi
#' \, [(X^\top \hat W X)^{-1}]_{kk}} (the ordinary Poisson Fisher information scaled by
#' \eqn{\hat\phi}), matching the standard quasi-Poisson GLM correction (as in
#' \code{stats::glm(family = quasipoisson())}). If \eqn{n \le p}, or \eqn{\hat\phi}
#' comes out non-finite or non-positive, \code{ssq_b_j}/\code{ssq_b_2}/\code{dispersion}
#' are left at their \code{NA} defaults (point estimates \code{b} and \code{mu} are
#' still returned).
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be nonnegative-integer counts.
#' @param  j The 1-indexed coefficient whose variance to compute in \code{ssq_b_j}. Defaults to 2.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
#'   provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta} is
#'   supplied, use a Poisson-specific heuristic initial guess rather than a zero cold start.
#' @param  maxit Maximum number of iterations. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default), \code{"lbfgs"}, or \code{"newton_raphson"}.
#' @param warm_start_weights Accepted but unused; see \code{\link{fast_poisson_regression_cpp}} Details.
#' @param warm_start_fisher_info Optional initial curvature (information) matrix to warm-start the first iteration.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated Poisson regression coefficients \eqn{\hat\beta}
#'   (point estimates, unaffected by the dispersion correction).}
#' \item{ssq_b_j}{The dispersion-scaled variance of the \eqn{j}-th coefficient estimator;
#'   \code{NA} if \code{j} indexes a fixed coefficient or the dispersion estimate is unusable.}
#' \item{ssq_b_2}{The dispersion-scaled variance of the second coefficient estimator
#'   specifically (typically the treatment effect), regardless of what \code{j} is; equal to
#'   \code{ssq_b_j} when \code{j = 2}.}
#' \item{dispersion}{The estimated Pearson-based overdispersion parameter \eqn{\hat\phi}, or
#'   \code{NA} if the residual degrees of freedom are not positive.}
#' \item{mu}{The fitted means \eqn{\hat\mu_i}.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' \item{iterations}{The number of iterations performed.}
#' \item{gradient_norm}{The norm of the score vector at convergence.}
#' }
#' @seealso \code{\link{fast_poisson_regression_with_var_cpp}} for the plain
#'   (non-overdispersion-corrected) variance variant; \code{\link{fast_poisson_regression_cpp}}
#'   for the estimate-only variant and full mean-model documentation.
#'
#' @export
#' @usage fast_quasipoisson_regression_with_var_cpp(
#'   X,
#'   y,
#'   j = 2L,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_quasipoisson_regression_with_var_cpp
NULL

#' Fast Weighted Logistic Regression, Estimate Only (C++ Backend)
#'
#' Fits the same logistic regression model as
#' \code{\link{fast_logistic_regression_cpp}} (see that page for the full
#' model, log-odds-ratio interpretation, and optimizer contract), with each
#' observation's contribution to the log-likelihood and IRLS working weights
#' multiplied by a row weight \code{weights[i]}. Setting all weights to 1
#' recovers \code{\link{fast_logistic_regression_cpp}} exactly; this is the
#' backend used when the logistic model must be fit on bootstrap-reweighted or
#' otherwise weighted data.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be binary (0 or 1).
#' @param  weights A numeric vector of weights for each observation.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}.
#'   If provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta}
#'   is supplied, use an OLS-based initial guess rather than a zero cold start.
#' @param  maxit Maximum number of iterations for the IRLS algorithm. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed
#'   rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default),
#'   \code{"lbfgs"}, or \code{"newton_raphson"}; see
#'   \code{\link{.normalize_optimizer_algorithm}}.
#' @param warm_start_weights Optional initial IRLS working weights for the
#'   first iteration.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated logistic regression coefficients \eqn{\hat\beta}.}
#' \item{mu}{The fitted probabilities \eqn{\hat\mu_i}.}
#' \item{XtWX, fisher_information}{Two aliases for the same working-weights
#'   curvature matrix \eqn{X^\top W X} at the final iteration.}
#' \item{score}{The (weighted) score vector at the fitted coefficients.}
#' \item{neg_ll}{The weighted negative log-likelihood at the fitted coefficients.}
#' \item{converged}{A logical value indicating whether the final gradient norm
#'   was below \code{tol} (\code{gradient_norm < tol}); uniform across the
#'   \code{"irls"}/\code{"lbfgs"} optimizers.}
#' \item{num_iter}{The number of optimizer iterations performed.}
#' \item{hit_iteration_cap}{A logical value, mutually exclusive with
#'   \code{converged}: \code{TRUE} iff the optimizer exhausted \code{maxit}
#'   iterations without meeting the gradient-norm convergence criterion.}
#' \item{gradient_norm}{The norm of the score vector at the returned
#'   coefficients.}
#' }
#' @seealso \code{\link{fast_logistic_regression_cpp}} for the unweighted model
#'   and full documentation.
#' @export
#' @usage fast_logistic_regression_weighted_cpp(
#'   X,
#'   y,
#'   weights,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_logistic_regression_weighted_cpp
NULL

#' Fast Weighted Poisson Regression (C++ Backend)
#'
#' Fits the same Poisson log-link model as \code{\link{fast_poisson_regression_cpp}}
#' (see that page for the full model and optimizer contract), with each
#' observation's contribution to the log-likelihood, score, and IRLS working
#' weights multiplied by a row weight \code{weights[i]}. Setting all weights to 1
#' recovers \code{\link{fast_poisson_regression_cpp}} exactly. Always fits with
#' \code{estimate_only = FALSE} (there is no flag to skip the post-fit \code{mu}/
#' \code{XtWX}/\code{score} computation for this variant).
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be nonnegative-integer counts.
#' @param  weights A numeric vector of nonnegative weights, one per observation.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
#'   provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta} is
#'   supplied, use a Poisson-specific heuristic initial guess rather than a zero cold start.
#' @param  maxit Maximum number of iterations. Defaults to 100.
#' @param  tol Convergence tolerance. Defaults to 1e-8.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default), \code{"lbfgs"}, or \code{"newton_raphson"}.
#' @param warm_start_weights Accepted but unused; see \code{\link{fast_poisson_regression_cpp}} Details.
#' @param warm_start_fisher_info Optional initial curvature (information) matrix to warm-start the first iteration.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated Poisson regression coefficients \eqn{\hat\beta}.}
#' \item{mu}{The fitted means \eqn{\hat\mu_i}.}
#' \item{XtWX, fisher_information}{Two aliases for the same (weighted) curvature matrix
#'   \eqn{X^\top W X}, \eqn{W = \mathrm{diag}(\code{weights}_i \hat\mu_i)}, at the fitted
#'   coefficients.}
#' \item{score}{The weighted score vector at the fitted coefficients.}
#' \item{neg_ll}{The weighted negative log-likelihood at the fitted coefficients.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' \item{iterations}{The number of iterations performed.}
#' \item{gradient_norm}{The norm of the score vector at convergence.}
#' }
#' @seealso \code{\link{fast_poisson_regression_cpp}} for the unweighted variant and full
#'   model documentation.
#'
#' @export
#' @usage fast_poisson_regression_weighted_cpp(
#'   X,
#'   y,
#'   weights,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   maxit = 100L,
#'   tol = 1e-8,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_poisson_regression_weighted_cpp
NULL

#' Fast Logistic Regression, Estimate Only (R Wrapper)
#'
#' Fits the logistic regression model documented in full at
#' \code{\link{fast_logistic_regression_cpp}} (log-odds-ratio interpretation,
#' IRLS/L-BFGS/Newton-Raphson optimization) via that C++ backend, returning
#' only the point estimate \eqn{\hat\beta} — no variance-covariance matrix or
#' per-coefficient standard errors are computed. Unlike
#' \code{\link{fast_logistic_regression_with_var}}, this function does
#' \strong{not} attempt to detect or retry on (quasi-)complete separation; if
#' the underlying C++ fit errors for any reason, this function silently
#' returns \code{b} as a vector of \code{NA}s (of length \code{ncol(X)})
#' rather than raising an error or retrying with fewer covariates.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be binary (0 or 1).
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default), \code{"newton_raphson"}, or \code{"irls"}.
#' @param warm_start_beta Optional starting values for the coefficients.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix.
#'
#' @return  A list containing the following component:
#' \describe{
#' \item{b}{A numeric vector of the estimated logistic regression coefficients
#'   \eqn{\hat\beta}, or a vector of \code{NA_real_} (length \code{ncol(X)})
#'   if the underlying fit errored.}
#' }
#' @seealso \code{\link{fast_logistic_regression_cpp}} for the underlying
#'   backend and full model documentation;
#'   \code{\link{fast_logistic_regression_with_var}} for the variance-
#'   augmented, separation-retrying variant.
#'
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = rbinom(100, 1, 0.5)
#' fast_logistic_regression(X, y)
#' @export
fast_logistic_regression = function(X, y, optimization_alg = "lbfgs", warm_start_beta = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = TRUE, default = "lbfgs")
	tryCatch({
		res = fast_logistic_regression_cpp(X, as.numeric(y), optimization_alg = optimization_alg, warm_start_beta = warm_start_beta, warm_start_fisher_info = warm_start_fisher_info)
		list(b = as.vector(res$b))
	}, error = function(e) list(b = rep(NA_real_, ncol(X))))
}

#' Fast Logistic Regression with Variance, Auto-Retrying on Separation (R Wrapper)
#'
#' Fits the logistic regression model documented in full at
#' \code{\link{fast_logistic_regression_cpp}} (log-odds-ratio interpretation,
#' IRLS/L-BFGS/Newton-Raphson optimization) via
#' \code{\link{fast_logistic_regression_with_var_cpp}}, and additionally
#' \strong{detects and automatically retries on (quasi-)complete separation} —
#' the well-known logistic-regression failure mode where the MLE does not
#' exist because some linear combination of covariates perfectly (or
#' near-perfectly) predicts the outcome, causing the optimizer's coefficient
#' estimates to diverge to a large-but-finite value that would otherwise
#' silently pass ordinary \code{is.finite()} convergence checks and corrupt
#' downstream confidence intervals.
#'
#' @details
#' \strong{Separation detection and retry.} After each fit attempt,
#' \code{is_separated_coefficient_magnitude()} checks whether any fitted
#' coefficient exceeds a fixed separation-detection threshold
#' (\code{EDI_SEPARATION_THRESHOLD}); if so, the fit is treated as
#' \code{converged = FALSE} regardless of what the underlying C++ optimizer
#' itself reported. On non-convergence (including detected separation), the
#' \strong{covariate (column index \eqn{\ge} 3, i.e. never the intercept in
#' column 1 or the treatment column in column 2) with the largest absolute
#' fitted coefficient} is dropped, and the model is refit on the reduced
#' design; this repeats until either the fit converges or only the intercept
#' and treatment columns remain. If separation persists even with just those
#' two columns, this function \code{stop()}s with an explicit
#' "complete separation detected" error rather than returning a corrupted
#' variance estimate.
#'
#' \strong{Interpretation caveat.} Because covariates can be silently dropped
#' by this retry loop, the returned \code{b} may have fewer coefficients than
#' \code{ncol(X)} implies, and the fitted model's covariate adjustment set can
#' differ from what was requested; callers relying on a specific covariate
#' being present in the final fit should check for this rather than assume it
#' always is.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be binary (0 or 1).
#' @param  j The index of the coefficient to compute the variance for. Defaults to 2.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default), \code{"irls"}, or \code{"newton_raphson"}.
#' @param warm_start_beta Optional starting values for the coefficients.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix.
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the obtained logistic regression coefficients
#'   \eqn{\hat\beta}, from whichever (possibly covariate-reduced) fit in the
#'   retry sequence ultimately converged.}
#' \item{ssq_b_j}{The squared standard error (variance) of the j-th estimated coefficient.}
#' \item{ssq_b_2}{The squared standard error (variance) of the second estimated coefficient,
#'   which typically corresponds to the treatment effect.}
#' }
#' @seealso \code{\link{fast_logistic_regression_with_var_cpp}} for the
#'   underlying single-fit (no retry) backend and its variance-computation
#'   details; \code{\link{fast_logistic_regression_cpp}} for the full model
#'   documentation.
#'
#' @examples
#' X = matrix(rnorm(100), 10, 10)
#' y = rbinom(10, 1, 0.5)
#' fast_logistic_regression_with_var(X, y)
#' @export
fast_logistic_regression_with_var = function(X, y, j = 2, optimization_alg = "lbfgs", warm_start_beta = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = TRUE, default = "lbfgs")
	# Coefficients beyond EDI_SEPARATION_THRESHOLD indicate complete/quasi-complete
	# separation: the MLE does not exist and the IWLS optimizer has diverged to a large
	# but finite value (which passes is.finite() checks and would silently corrupt CIs).

	# Attempt a single fit on matrix X; always returns a list with (b, ssq_b_j, ssq_b_2, converged).
	# 'converged' is FALSE when separation is detected so the caller can retry with fewer covariates.
	try_fit = function(X){
		tryCatch({
			mod = fast_logistic_regression_with_var_cpp(X, as.numeric(y), j = j, optimization_alg = optimization_alg, warm_start_beta = warm_start_beta, warm_start_fisher_info = warm_start_fisher_info)
			b = as.vector(mod$b)
			list(b = b, ssq_b_j = mod$ssq_b_j, ssq_b_2 = mod$ssq_b_2, converged = (is.null(mod$converged) || isTRUE(mod$converged)) && !is_separated_coefficient_magnitude(b))
		}, error = function(e) {
			list(b = rep(NA_real_, ncol(X)), ssq_b_j = NA_real_, ssq_b_2 = NA_real_, converged = FALSE)
		})
	}

	# Iteratively drop the covariate (column >= 3) with the largest absolute coefficient
	# until the model converges or only the intercept + treatment remain.
	X_curr = X
	repeat {
	fit = try_fit(X_curr)
	if (fit$converged) return(list(b = fit$b, ssq_b_j = fit$ssq_b_j, ssq_b_2 = fit$ssq_b_2))
	if (ncol(X_curr) <= 2){
		stop("complete separation detected: logistic regression coefficients diverged (MLE does not exist)")
	}
	covariate_cols = 3:ncol(X_curr)
	coef_mags = abs(fit$b[covariate_cols])
	worst_idx = if (all(is.na(coef_mags))) length(covariate_cols) else which.max(coef_mags)
	X_curr = X_curr[, -covariate_cols[worst_idx], drop = FALSE]
	}
}

#' Fast Weibull AFT Regression (R Wrapper: Rcpp Backend or \pkg{survival})
#'
#' Fits the Weibull accelerated failure time model documented in full at
#' \code{\link{fast_weibull_regression_general_cpp}} (\eqn{\log T_i = \eta_i +
#' \sigma W_i}, \eqn{\eta_i = x_i^\top\beta}, right-censoring only), via either
#' that C++ backend (\code{use_rcpp = TRUE}, the default) or
#' \code{\link[survival]{survreg}} with \code{dist = "weibull"}
#' (\code{use_rcpp = FALSE}) as a fallback/cross-check implementation.
#'
#' @details When \code{use_rcpp = TRUE}, an intercept column is prepended to
#'   \code{X} automatically if not already present (detected as a first column
#'   of all 1s), fitting always starts from a zero cold start
#'   (\code{smart_cold_start = FALSE} is hardcoded, regardless of whether
#'   \code{warm_start_params} is supplied), and a non-\code{converged} C++ fit is
#'   escalated to an R-level \code{stop()} rather than returned silently.
#'
#'   When \code{use_rcpp = FALSE}, any existing intercept column is stripped and
#'   \code{survreg} is left to add its own; remaining covariate columns are first
#'   passed through \code{drop_linearly_dependent_cols} to remove
#'   collinear columns before fitting (silently — no error or warning is raised
#'   for dropped columns). \code{estimate_only}, \code{optimization_alg},
#'   \code{warm_start_params}, and \code{warm_start_fisher_info} have \strong{no
#'   effect} on this path — \code{survreg} always computes the full
#'   variance-covariance matrix, and \code{std_errs} (from \code{sqrt(diag(vcov))})
#'   is included only in this path's return value, not the Rcpp path's. Both
#'   non-finite coefficients and (unless \code{estimate_only = TRUE}, which is
#'   ignored on this path regardless) non-finite variance-covariance entries from
#'   \code{survreg} are escalated to an R-level \code{stop()}.
#'
#' @param  y Observed survival/censoring times (must be positive).
#' @param  dead Event indicator: 1 for an exactly observed event, 0 for
#'   right-censored (survival known only to exceed \code{y[i]}).
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param use_rcpp Logical. If \code{TRUE} (default), use the optimized Rcpp
#'   implementation. If \code{FALSE}, use \code{\link[survival]{survreg}}.
#' @param estimate_only Logical. If \code{TRUE}, skip variance-covariance
#'   matrix calculation for speed. Only has an effect when \code{use_rcpp = TRUE}.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or
#'   \code{"newton_raphson"}. Only has an effect when \code{use_rcpp = TRUE}.
#' @param warm_start_params Optional starting values for \eqn{[\beta,
#'   \log\sigma]}. Only has an effect when \code{use_rcpp = TRUE}.
#' @param warm_start_fisher_info Optional initial curvature (Fisher/observed
#'   information) matrix. Only has an effect when \code{use_rcpp = TRUE}.
#' @return  A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the estimated Weibull regression coefficients
#' \eqn{\hat\beta}, including the intercept.}
#' \item{log_sigma}{The logarithm of the fitted scale parameter \eqn{\hat\sigma} of the
#'   Weibull AFT distribution.}
#' \item{vcov}{The variance-covariance matrix of the estimated coefficients, or \code{NULL}
#'   if \code{estimate_only = TRUE} (Rcpp path only).}
#' \item{neg_log_lik}{(Rcpp path only) The negative log-likelihood at the fitted parameters.}
#' \item{fisher_information}{(Rcpp path only) The observed information matrix, or \code{NULL}
#'   if \code{estimate_only = TRUE}.}
#' \item{std_errs}{(\pkg{survival} path only) The coefficient standard errors,
#'   \code{sqrt(diag(vcov))}.}
#' }
#' @seealso \code{\link{fast_weibull_regression_general_cpp}} for the full model documentation
#'   and Rcpp backend contract.
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = runif(100)
#' dead = rbinom(100, 1, 0.5)
#' fast_weibull_regression(y, dead, X)
#' @export
fast_weibull_regression = function(y, dead, X, use_rcpp = TRUE, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	X = as.matrix(X)
	
	if (use_rcpp) {
		# Ensure intercept is present
		if (NCOL(X) == 0 || !all(X[, 1] == 1)) {
			X = cbind("(Intercept)" = 1, X)
		}
		
		y = as.numeric(y)
		dead = as.numeric(dead)
		# This wrapper's signature only ever carries (y, dead) -- it can never
		# receive left-/interval-censored data -- so route through the fast
		# exact/right-censored-only kernel (TODO-28) rather than the general
		# one; no y_exact/y_L/y_R conversion needed.
		res = tryCatch(
			fast_weibull_regression_cpp(X = X, y = y, dead = dead,
			                            warm_start_params = warm_start_params,
			                            smart_cold_start = FALSE,
			                            estimate_only = estimate_only,
			                            optimization_alg = optimization_alg,
			                            warm_start_fisher_info = warm_start_fisher_info),
			error = function(e) stop("Weibull regression (Rcpp) failed to converge: ", e$message)
		)
		if (is.null(res) || !isTRUE(res$converged)) {
			stop("Weibull regression (Rcpp) failed to converge.")
		}
		
		p = ncol(X)
		coefficients = as.numeric(if (estimate_only) res$b else res$params[seq_len(p)])
		names(coefficients) = colnames(X)
		log_sigma_val = as.numeric(if (estimate_only) res$log_sigma else res$params[p + 1L])

		return(list(
			coefficients = coefficients,
			log_sigma = log_sigma_val,
			vcov = if (estimate_only) NULL else res$vcov,
			neg_log_lik = as.numeric(res$neg_ll),
			fisher_information = if (estimate_only) NULL else res$information
		))
	}

	# Check if X has an intercept column (a column of all ones)
	# Assuming intercept is the first column if present
	if (NCOL(X) > 0 && all(X[, 1] == 1)) {
	# If an intercept is present, remove it as survreg adds one automatically
	X_no_intercept = X[, -1, drop = FALSE]
	} else {
	X_no_intercept = X
	}

	# Drop linearly dependent columns before passing to survreg
	X_no_intercept = drop_linearly_dependent_cols(X_no_intercept)$M

	# Use survreg (not survreg.fit) to handle parameter defaults properly
	if (NCOL(X_no_intercept) > 0) {
	# Preserve or create column names
	original_colnames = colnames(X_no_intercept)
	if (is.null(original_colnames)) {
		original_colnames = paste0("X", 1:NCOL(X_no_intercept))
	}

	# Create a data frame for survreg
	df = as.data.frame(X_no_intercept)
	colnames(df) = original_colnames
	df$y = y
	df$dead = dead
	# Wrap column names in backticks to handle special characters
	backticked_colnames = paste0("`", original_colnames, "`")
	formula_str = paste("survival::Surv(y, dead) ~", paste(backticked_colnames, collapse = " + "))
	mod <- tryCatch(
		survival::survreg(as.formula(formula_str), data = df, dist = "weibull"),
		error = function(e) {
		msg = if (nzchar(trimws(e$message))) e$message else "survreg returned no error message"
		stop("Weibull regression failed to converge: ", msg)
		}
	)

	# Extract coefficients and preserve names
	coefficients = as.vector(mod$coefficients)
	names(coefficients) = c("(Intercept)", original_colnames)
	} else {
	# Intercept-only model
	mod <- tryCatch(
		survival::survreg(survival::Surv(y, dead) ~ 1, dist = "weibull"),
		error = function(e) {
		msg = if (nzchar(trimws(e$message))) e$message else "survreg returned no error message"
		stop("Weibull regression failed to converge: ", msg)
		}
	)
	coefficients = as.vector(mod$coefficients)
	names(coefficients) = "(Intercept)"
	}

	vcov = mod$var
	std_errs = if (is.matrix(vcov)) sqrt(diag(vcov)) else rep(NA_real_, length(coefficients) + 1)
	log_sigma = log(mod$scale)
	neg_log_lik = if (!is.null(mod$loglik) && length(mod$loglik) >= 2) -mod$loglik[2] else NA_real_

	# Throw (rather than silently return NaN) so callers like the bootstrap tryCatch can handle failure
	if (any(!is.finite(coefficients))) {
	stop("Weibull regression failed to converge: survreg returned non-finite coefficients")
	}
	if (!estimate_only && is.matrix(vcov) && any(!is.finite(diag(vcov)))) {
	stop("Weibull regression failed to converge: survreg returned non-finite variance-covariance")
	}

	list(
		coefficients = coefficients,
		log_sigma = log_sigma,
		std_errs = std_errs,
		vcov = vcov,
		neg_log_lik = neg_log_lik,
		b = coefficients,
		ssq_b_2 = if (is.matrix(vcov) && nrow(vcov) >= 2) vcov[2, 2] else NA_real_
	)
}

# Internal helper for beta regression safety.
sanitize_beta_response = function(y){
	y = as.numeric(y)
	if (any(!is.finite(y))){
	stop("y must be finite for beta regression")
	}
	eps = .Machine$double.eps
	if (any(y <= 0 | y >= 1)){
	n = length(y)
	if (n > 1){
		y = (y * (n - 1) + 0.5) / n
	}
	y = pmin(pmax(y, eps), 1 - eps)
	}
	y
}

#' Fast Beta Regression (R Wrapper)
#'
#' Fits the beta regression model of Ferrari and Cribari-Neto (2004) for a
#' continuous response strictly in \eqn{(0, 1)}, with mean linked to the covariates
#' via the logit link and a single (constant) precision parameter \eqn{\phi}. See
#' \code{\link{fast_beta_regression_cpp}} for the full model equation, parameter
#' layout, and optimizer contract implemented by the C++ backend this function
#' wraps; this page documents only the R-level fallback chain and response-scale
#' conventions.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, with values strictly between 0 and 1.
#'   See \code{sanitize_beta_response()} (internal) for how boundary values (exact 0s/1s)
#'   are handled before fitting.
#' @param  start_phi A numeric value, the starting value for the precision parameter phi.
#'   Defaults to 10.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or
#'   \code{"newton_raphson"}; see \code{\link{.normalize_optimizer_algorithm}}.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix, used to
#'   warm-start curvature information for the optimizer.
#'
#' @return  A list containing the following components:
#' \item{b}{A numeric vector of the estimated beta regression coefficients \eqn{\hat\beta}
#'   (on the logit-of-mean scale: \code{plogis(X \%*\% b)} gives the fitted mean
#'   \eqn{\hat\mu}), from whichever stage of the fallback chain (see Details)
#'   ultimately succeeded.}
#' \item{phi}{The estimated precision parameter \eqn{\hat\phi} (only present when the
#'   C++ backend or the \pkg{betareg} fallback succeeds; absent from the final
#'   OLS-on-\code{logit(y)} fallback, which has no precision parameter).}
#' \item{fisher_information}{The working-weights Fisher information matrix from the
#'   C++ backend (see \code{\link{fast_beta_regression_cpp}}); only present when that
#'   backend succeeds.}
#'
#' @details
#' \strong{Fallback chain.} The primary implementation uses the C++ backend
#' (\code{\link{fast_beta_regression_cpp}}). If that fails to converge or errors, the
#' function falls back to \pkg{betareg}, which is listed in Suggests and is not
#' installed automatically with \pkg{EDI}. If \pkg{betareg} is also unavailable (or
#' itself fails), a final fallback of OLS on \code{logit(y)} is used — this last
#' resort is always available (no external dependency) but does not respect the beta
#' distribution's mean-variance relationship or estimate \eqn{\phi} at all, so its
#' coefficients should be treated as an approximate, non-model-based summary rather
#' than a true beta-regression fit. Install \pkg{betareg} manually to
#' enable the intermediate fallback. A \code{warning()} is issued whenever a fallback
#' stage is used, naming which stage and the triggering error, so callers can detect
#' when the primary fit failed even though a result was still returned.
#'
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = runif(100)
#' fast_beta_regression(X, y)
#' @export
fast_beta_regression = function(X, y, start_phi = 10, optimization_alg = "lbfgs", warm_start_beta = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = sanitize_beta_response(y)
	tryCatch({
	res = fast_beta_regression_cpp(X, y, start_phi = start_phi, optimization_alg = optimization_alg, warm_start_beta = warm_start_beta, warm_start_fisher_info = warm_start_fisher_info)
	list(b = res$coefficients, phi = res$phi, fisher_information = res$fisher_information)
	}, error = function(e) {
	warning("fast_beta_regression_cpp failed, falling back to betareg. Error: ", e$message)
	if (!check_package_installed("betareg")) {
		warning("Package 'betareg' is not installed; skipping betareg fallback and using OLS on logit(y). Install it with install.packages(\"betareg\") for a better fallback.")
		return(list(b = fast_ols_cpp(X, logit(y))$b))
	}
	# create a data frame for betareg, removing the intercept from X
	data_df <- as.data.frame(cbind(y, X[, -1, drop = FALSE]))
	# rename columns for formula
	colnames(data_df) <- c("y", paste0("x", 1:(ncol(X)-1)))
	# fit model with control to suppress precision parameter warning
	tryCatch({
		suppressWarnings({
		fit <- betareg::betareg(y ~ ., data = data_df,
								control = betareg::betareg.control(start = list(phi = start_phi)))
		})
		list(b = coef(fit), phi = as.numeric(coef(fit)["(phi)"]))
	}, error = function(e2) {
		warning("betareg fallback failed, using OLS on logit(y). Error: ", e2$message)
		list(b = fast_ols_cpp(X, logit(y))$b)
	})
	})
}

#' Fast Beta Regression with Variance Calculation (R Wrapper)
#'
#' Fits the same beta regression model as \code{\link{fast_beta_regression}} (see
#' \code{\link{fast_beta_regression_cpp}} for the full model equation and
#' parameterization) and additionally reports the estimated variance of a
#' caller-selected coefficient, extracted from the fitted parameter
#' variance-covariance matrix (see
#' \code{\link{fast_beta_regression_with_var_cpp}} for how that matrix is computed
#' and its plain-inverse numerical caveat on rank-deficient designs).
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, with values strictly between 0 and 1.
#'   See \code{sanitize_beta_response()} (internal) for boundary-value handling.
#' @param  start_phi A numeric value, the starting value for the precision parameter phi.
#'   Defaults to 10.
#' @param  j The 1-based index (into \code{X}'s columns, i.e. into \eqn{\beta}) of
#'   the coefficient to report the variance of as \code{ssq_b_j}. Defaults to 2
#'   (the package's usual convention for the treatment-effect column when an
#'   intercept occupies column 1).
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or
#'   \code{"newton_raphson"}; see \code{\link{.normalize_optimizer_algorithm}}.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix, used to
#'   warm-start curvature information for the optimizer.
#'
#' @return  A list containing the following components:
#' \item{b}{A numeric vector of the estimated beta regression coefficients \eqn{\hat\beta}
#'   (logit-of-mean scale).}
#' \item{ssq_b_j}{The estimated variance (squared standard error) of the \code{j}-th
#'   coefficient, \eqn{\widehat{\mathrm{Var}}(\hat\beta_j)}, i.e. the \code{j}-th
#'   diagonal entry of \code{vcov}. \code{NA} if the primary C++ fit failed and a
#'   fallback stage without a variance estimate was used (see Details).}
#' \item{ssq_b_2}{The estimated variance of the second coefficient specifically
#'   (\eqn{\widehat{\mathrm{Var}}(\hat\beta_2)}), regardless of the \code{j} argument
#'   — provided as a convenience since column 2 is the package's usual
#'   treatment-effect position. Identical to \code{ssq_b_j} when \code{j = 2}.}
#'
#' @details
#' The primary implementation uses a C++ backend. If that fails, the function falls back
#' to \pkg{betareg}, which is listed in Suggests and is not installed automatically
#' with \pkg{EDI}. If \pkg{betareg} is also unavailable, a final fallback of OLS on
#' \code{logit(y)} is used. Install \pkg{betareg} manually to
#' enable the intermediate fallback.
#'
#' @importFrom	stats vcov
#' @examples
#' X = matrix(rnorm(100), 10, 10)
#' y = runif(10)
#' fast_beta_regression_with_var(X, y)
#' @export
fast_beta_regression_with_var = function(X, y, start_phi = 10, j = 2, optimization_alg = "lbfgs", warm_start_beta = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = sanitize_beta_response(y)
	tryCatch({
	mod = fast_beta_regression_with_var_cpp(X, y, start_phi = start_phi, optimization_alg = optimization_alg, warm_start_beta = warm_start_beta)
	list(
		b = mod$coefficients,
		phi = mod$phi,
		ssq_b_j = mod$vcov[j, j],
		ssq_b_2 = if (nrow(mod$vcov) >= 2) mod$vcov[2, 2] else NA_real_
	)
	}, error = function(e) {
	warning("fast_beta_regression_with_var_cpp failed, falling back to betareg. Error: ", e$message)
	if (!check_package_installed("betareg")) {
		warning("Package 'betareg' is not installed; skipping betareg fallback and using OLS on logit(y). Install it with install.packages(\"betareg\") for a better fallback.")
		mod = fast_ols_with_var_cpp(X, logit(y), j = as.integer(j))
		return(list(b = mod$b, phi = NA_real_, ssq_b_j = mod$ssq_b_j, ssq_b_2 = if (length(mod$b) >= 2) fast_ols_with_var_cpp(X, logit(y), j = 2L)$ssq_b_j else NA_real_))
	}
	# create a data frame for betareg, removing the intercept from X
	data_df <- as.data.frame(cbind(y, X[, -1, drop = FALSE]))
	# rename columns for formula
	colnames(data_df) <- c("y", paste0("x", 1:(ncol(X)-1)))
	# fit model with control to suppress precision parameter warning
	tryCatch({
		suppressWarnings({
		fit <- betareg::betareg(y ~ ., data = data_df,
								control = betareg::betareg.control(start = list(phi = start_phi)))
		})
		# Get the variance of the j-th coefficient
		vcov_matrix <- vcov(fit)
		list(b = coef(fit), phi = as.numeric(coef(fit)["(phi)"]), ssq_b_j = vcov_matrix[j, j], ssq_b_2 = if (nrow(vcov_matrix) >= 2) vcov_matrix[2, 2] else NA_real_)
	}, error = function(e2) {
		warning("betareg fallback failed, using OLS on logit(y). Error: ", e2$message)
		mod = fast_ols_with_var_cpp(X, logit(y), j = as.integer(j))
		list(b = mod$b, phi = NA_real_, ssq_b_j = mod$ssq_b_j, ssq_b_2 = if (length(mod$b) >= 2) fast_ols_with_var_cpp(X, logit(y), j = 2L)$ssq_b_j else NA_real_)
	})
	})
}

#' Fast Cox Proportional Hazards Regression (R Wrapper)
#'
#' Fits the Cox proportional-hazards partial-likelihood model documented in full at
#' \code{\link{build_cox_data_cache_cpp}} (model equation, Breslow tie-handling, and
#' input conventions). This R-level wrapper dispatches to either the package's own
#' native C++ implementation (\code{\link{fast_coxph_regression_cpp}}, the default
#' and recommended path) or, for cross-checking or when the Rcpp path is
#' unavailable, an elastic-net-with-zero-penalty Cox fit via \pkg{glmnet}
#' (\code{use_rcpp = FALSE}) — \strong{not} \pkg{survival::coxph}, despite that
#' being the more commonly used reference implementation for Cox models in R.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept term
#'   is handled implicitly by the Cox model and should not be included in \code{X}.
#' @param  y A numeric vector representing the observed time (event time or censoring time).
#' @param  dead A numeric vector (0 or 1) indicating event status (1 for event, 0 for censored).
#' @param use_rcpp Logical. If \code{TRUE} (default), use the optimized Rcpp
#'   implementation (\code{\link{fast_coxph_regression_cpp}}). If \code{FALSE}, use
#'   \pkg{glmnet}'s Cox path at zero penalty (\code{glmnet(..., family = "cox",
#'   lambda = 0)}) instead.
#' @param estimate_only Logical. If \code{TRUE}, skip variance-covariance
#'   matrix calculation for speed. Only affects the \code{use_rcpp = TRUE} path;
#'   the \pkg{glmnet} fallback path does not compute a variance-covariance matrix
#'   at all (\code{vcov} is never populated when \code{use_rcpp = FALSE}, regardless
#'   of \code{estimate_only}).
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#'   Only affects the \code{use_rcpp = TRUE} path; unused when
#'   \code{use_rcpp = FALSE}.
#' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
#'   Only affects the \code{use_rcpp = TRUE} path.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix. Only
#'   affects the \code{use_rcpp = TRUE} path.
#' @param smart_cold_start Logical. If \code{TRUE} (default), use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if \code{warm_start_beta} is provided.
#'   Only affects the \code{use_rcpp = TRUE} path.
#'
#' @return  A list. When \code{use_rcpp = TRUE} (default), a list with components
#' \describe{
#' \item{b, coefficients}{A numeric vector of the estimated log-hazard-ratio
#'   coefficients \eqn{\hat\beta} (\code{b} and \code{coefficients} are identical;
#'   both are populated for interface consistency with the package's other
#'   \code{fast_*} wrappers).}
#' \item{vcov}{The variance-covariance matrix of \eqn{\hat\beta}, or \code{NULL}
#'   when \code{estimate_only = TRUE}.}
#' \item{neg_log_lik}{The negative Cox partial log-likelihood at the fitted
#'   coefficients.}
#' \item{fisher_information}{The Hessian of the negative partial log-likelihood at
#'   the fitted coefficients.}
#' }
#' When \code{use_rcpp = FALSE}, only a single component,
#' \code{b} (the \pkg{glmnet}-fitted coefficient vector via \code{coef()}, in
#' \pkg{glmnet}'s own sparse-matrix representation rather than a plain numeric
#' vector) — none of \code{coefficients}/\code{vcov}/\code{neg_log_lik}/
#' \code{fisher_information} are present on this path.
#'
#' @details
#' \strong{Failure semantics.} If the C++ fit (\code{use_rcpp = TRUE}) errors or
#' fails to report \code{converged}, this function stops with an error rather than
#' silently falling back to \pkg{glmnet} — the two code paths are alternative
#' \emph{caller choices}, not an automatic fallback chain (contrast with, e.g.,
#' \code{\link{fast_beta_regression}}'s automatic \pkg{betareg} fallback).
#'
#' \strong{\pkg{glmnet} dependency.} When \code{use_rcpp = FALSE}, this function requires the \pkg{glmnet} package,
#' which is listed in Suggests and is not installed automatically with \pkg{EDI}; it errors immediately if
#' \pkg{glmnet} is not installed.
#'
#' @seealso \code{\link{build_cox_data_cache_cpp}} for the full Cox partial-likelihood
#'   model, Breslow tie-handling, and input conventions;
#'   \code{\link{fast_coxph_regression_cpp}} for the native C++ backend this
#'   wrapper calls by default.
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = runif(100)
#' dead = rbinom(100, 1, 0.5)
#' fast_coxph_regression(y, dead, X)
#' @export
fast_coxph_regression = function(X, y, dead, use_rcpp = TRUE, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_beta = NULL, warm_start_fisher_info = NULL, smart_cold_start = TRUE){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	if (use_rcpp) {
		X = as.matrix(X)
		res = tryCatch(
			fast_coxph_regression_cpp(X = X, y = as.numeric(y), dead = as.numeric(dead),
			                          estimate_only = estimate_only,
			                          optimization_alg = optimization_alg,
			                          warm_start_beta = warm_start_beta,
			                          warm_start_fisher_info = warm_start_fisher_info,
			                          smart_cold_start = smart_cold_start),
			error = function(e) stop("Cox PH regression (Rcpp) failed to converge: ", e$message)
		)
		if (is.null(res) || !isTRUE(res$converged)) {
			stop("Cox PH regression (Rcpp) failed to converge.")
		}

		b = as.numeric(res$coefficients)
		names(b) = colnames(X)

		return(list(
			b = b,
			coefficients = b,
			vcov = if (estimate_only) NULL else res$vcov,
			neg_log_lik = as.numeric(res$neg_ll),
			fisher_information = res$fisher_information
		))
	}
	if (!check_package_installed("glmnet")) {
		stop("Package 'glmnet' is required for fast_coxph_regression when use_rcpp = FALSE. Please install it.")
	}
	mod = glmnet::glmnet(X, survival::Surv(y, dead), family = "cox", lambda = 0)
	list(b = stats::coef(mod))
}

#' Fast Negative Binomial Regression, Estimate-Only (R Wrapper)
#'
#' This function provides a fast implementation of mean/dispersion-parameterized
#' negative binomial regression, wrapping a C++ backend
#' (\code{\link{fast_neg_bin_cpp}}; see that page, and
#' \code{\link{fast_dnbinom_mu_vec_cpp}}, for the full model). It returns point
#' estimates only (no standard errors) — see \code{\link{fast_negbin_regression_with_var}}
#' for the variance-computing counterpart. Columns 1 and 2 of \code{X} (conventionally
#' the intercept and treatment indicator) are always kept; this wrapper adds automatic,
#' silent handling of \strong{rank-deficient or numerically unstable covariate sets}
#' beyond those first two columns: (1) if \code{warm_start_params} is supplied, a single
#' fit is attempted on the full matrix using the warm start, and its result is returned
#' if successful; (2) otherwise, upfront, any covariate columns (3 onward) found
#' rank-deficient by \code{\link[base]{qr}} are dropped before the first fit attempt;
#' (3) if the C++ fit still fails (e.g. an L-BFGS line-search failure), covariates are
#' dropped one at a time, in reverse QR-pivot order (most redundant first), retrying
#' after each drop, until the fit succeeds or only the intercept and treatment columns
#' remain — at which point, if it still fails, this function \code{stop()}s with an
#' explicit error rather than returning a corrupted fit.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, representing count data.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or \code{"newton_raphson"}.
#' @param warm_start_params Optional starting values for coefficients and \code{log_theta}, passed
#'   straight through to the C++ backend for a single warm-started fit attempt (bypassing the
#'   QR-dropping retry sequence).
#' @param warm_start_fisher_info Optional initial Fisher information matrix, used only together
#'   with \code{warm_start_params}.
#'
#' @return  A list containing the following components:
#' \item{b}{A numeric vector of the estimated negative binomial regression coefficients
#'   \eqn{\hat\beta} (and \code{log_theta}), from whichever (possibly covariate-reduced)
#'   fit in the retry sequence ultimately succeeded.}
#' \item{fisher_information}{The C++ backend's returned Fisher information matrix for the
#'   successful fit.}
#'
#' @seealso \code{\link{fast_negbin_regression_with_var}} for the variance-computing,
#'   similarly retry-hardened wrapper; \code{\link{fast_neg_bin_cpp}} for the underlying
#'   backend and full model documentation.
#'
#' @importFrom	stats glm.fit
#' @importFrom	MASS negative.binomial
#' @examples
#' X = matrix(rnorm(100), 10, 10)
#' y = rpois(10, 2)
#' fast_negbin_regression(X, y)
#' @export
fast_negbin_regression <- function(X, y, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL) {
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	X_full = as.matrix(X)
	X_fit = X_full
	
	# If warm start is provided, we use the full matrix and don't attempt QR dropping initially
	if (!is.null(warm_start_params)) {
		res = tryCatch(fast_neg_bin_cpp(X_fit, as.integer(y), warm_start_params = warm_start_params, smart_cold_start = FALSE, optimization_alg = optimization_alg, warm_start_fisher_info = warm_start_fisher_info), error = function(e) NULL)
		if (!is.null(res)) return(list(b = as.numeric(res$b), fisher_information = res$fisher_information))
	}

	if (ncol(X_full) > 2L) {
		X_cov = X_full[, -(1:2), drop = FALSE]
		if (ncol(X_cov) > 0L) {
			qr_cov = qr(X_cov)
			r_cov = qr_cov$rank
			if (r_cov < ncol(X_cov)) {
				keep_cov = sort(qr_cov$pivot[seq_len(r_cov)])
				X_fit = if (length(keep_cov) > 0L) {
					cbind(X_full[, 1:2, drop = FALSE], X_cov[, keep_cov, drop = FALSE])
				} else {
					X_full[, 1:2, drop = FALSE]
				}
			}
		}
	}
	res = tryCatch(fast_neg_bin_cpp(X_fit, as.integer(y), smart_cold_start = FALSE, optimization_alg = optimization_alg), error = function(e) NULL)
	if (!is.null(res)) return(list(b = as.numeric(res$b), fisher_information = res$fisher_information))
	# Progressive QR-ordered column dropping: intercept (col 1) and treatment (col 2) are fixed;
	# drop covariates one at a time in reverse QR-pivot order (most redundant first)
	if (ncol(X_fit) > 2L) {
		X_cov = X_fit[, -(1:2), drop = FALSE]
		keep_js = qr(X_cov)$pivot
		while (length(keep_js) > 0L) {
			keep_js = keep_js[-length(keep_js)]
			X_try = if (length(keep_js) > 0L) {
				cbind(X_fit[, 1:2, drop = FALSE], X_cov[, keep_js, drop = FALSE])
			} else {
				X_fit[, 1:2, drop = FALSE]
			}
			res = tryCatch(fast_neg_bin_cpp(X_try, as.integer(y), smart_cold_start = FALSE, optimization_alg = optimization_alg), error = function(e) NULL)
			if (!is.null(res)) return(list(b = as.numeric(res$b), fisher_information = res$fisher_information))
		}
	}
	stop("Negative binomial regression failed to converge: L-BFGS line search failed after dropping all covariates")
}

#' Fast Negative Binomial Regression with Variance Calculation (R Wrapper)
#'
#' This function provides a fast implementation of negative binomial regression, wrapping
#' a C++ backend (\code{\link{fast_neg_bin_with_var_cpp}}; see that page, and
#' \code{\link{fast_dnbinom_mu_vec_cpp}}, for the full mean/dispersion
#' negative-binomial model). Columns 1 and 2 of \code{X} (conventionally the
#' intercept and treatment indicator) are always kept; this wrapper adds
#' automatic, silent handling of \strong{rank-deficient or numerically
#' unstable covariate sets} beyond those first two columns: (1) upfront, any
#' covariate columns (3 onward) found rank-deficient by \code{\link[base]{qr}}
#' are dropped before the first fit attempt; (2) if the C++ fit still fails
#' (e.g. an L-BFGS line-search failure), covariates are dropped one at a time,
#' in reverse QR-pivot order (most redundant first), retrying after each drop,
#' until the fit succeeds or only the intercept and treatment columns remain —
#' at which point, if it still fails, this function \code{stop()}s with an
#' explicit error rather than returning a corrupted fit.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, representing count data.
#' @param  j The index of the coefficient to compute the variance for. Defaults to 2.
#' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or \code{"newton_raphson"}.
#'
#' @return  A list containing the following components:
#' \describe{
#' \item{b}{A numeric vector of the estimated negative binomial regression
#'   coefficients \eqn{\hat\beta}, from whichever (possibly covariate-reduced)
#'   fit in the retry sequence ultimately succeeded.}
#' \item{ssq_b_j}{The variance of the j-th estimated coefficient, computed by
#'   inverting the C++ backend's returned Hessian/Fisher-information matrix
#'   directly (via \code{\link[base]{solve}}, not the backend's own
#'   \code{vcov}); \code{NA} if that inversion fails or \code{j} exceeds the
#'   number of columns remaining after covariate-dropping.}
#' \item{ssq_b_2}{The variance of the second estimated coefficient
#'   specifically (typically the treatment effect), computed the same way,
#'   regardless of what \code{j} is.}
#' }
#' @seealso \code{\link{fast_neg_bin_with_var_cpp}} for the underlying
#'   backend (no automatic rank-deficiency retry) and full model
#'   documentation; \code{\link{fast_negbin_regression}} for the
#'   estimate-only, similarly retry-hardened wrapper.
#'
#' @importFrom	stats coef
#' @examples
#' X = matrix(rnorm(100), 10, 10)
#' y = rpois(10, 2)
#' fast_negbin_regression_with_var(X, y)
#' @export
fast_negbin_regression_with_var <- function(X, y, j = 2, optimization_alg = "lbfgs") {
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	X_full = as.matrix(X)
	X_curr = X_full
	if (ncol(X_full) > 2L) {
		X_cov = X_full[, -(1:2), drop = FALSE]
		if (ncol(X_cov) > 0L) {
			qr_cov = qr(X_cov)
			r_cov = qr_cov$rank
			if (r_cov < ncol(X_cov)) {
				keep_cov = sort(qr_cov$pivot[seq_len(r_cov)])
				X_curr = if (length(keep_cov) > 0L) {
					cbind(X_full[, 1:2, drop = FALSE], X_cov[, keep_cov, drop = FALSE])
				} else {
					X_full[, 1:2, drop = FALSE]
				}
			}
		}
	}
	res = tryCatch(fast_neg_bin_with_var_cpp(X_curr, as.integer(y), smart_cold_start = FALSE, optimization_alg = optimization_alg), error = function(e) NULL)
	if (is.null(res)) {
		# Progressive QR-ordered column dropping: intercept (col 1) and treatment (col 2) are fixed;
		# drop covariates one at a time in reverse QR-pivot order (most redundant first)
		if (ncol(X_curr) > 2L) {
			X_cov = X_curr[, -(1:2), drop = FALSE]
			keep_js = qr(X_cov)$pivot
			while (length(keep_js) > 0L && is.null(res)) {
				keep_js = keep_js[-length(keep_js)]
				X_curr = if (length(keep_js) > 0L) {
					cbind(X_curr[, 1:2, drop = FALSE], X_cov[, keep_js, drop = FALSE])
				} else {
					X_curr[, 1:2, drop = FALSE]
				}
				res = tryCatch(fast_neg_bin_with_var_cpp(X_curr, as.integer(y), smart_cold_start = FALSE, optimization_alg = optimization_alg), error = function(e) NULL)
			}
		}
		if (is.null(res))
			stop("Negative binomial regression failed to converge: L-BFGS line search failed after dropping all covariates")
	}
	
	# Extract vcov from the Fisher information matrix (Hessian of -logLik)
	# The Hessian returned by C++ is for [beta, log_theta]
	hess = res$hess_fisher_info_matrix
	vcov = tryCatch(solve(hess), error = function(e) matrix(NA_real_, nrow(hess), ncol(hess)))
	
	list(
		b = as.numeric(res$b),
		ssq_b_j = if (j <= ncol(X_curr)) as.numeric(vcov[j, j]) else NA_real_,
		ssq_b_2 = if (ncol(X_curr) >= 2) as.numeric(vcov[2, 2]) else NA_real_
	)
}



































# fast_beta_regression <- function(X, y,
#                              start_phi = 10,
#                              bounds_logphi = c(log(1e-3), log(1e4)),
#                              control = stats::glm.control(epsilon=1e-8, maxit=100)) {

#   weights <- rep(1, nrow(X))

#   # Use C++ logistic regression to find beta (quasi-likelihood, independent of phi)
#   # This replaces the repetitive glm.fit calls inside the optimization loop
#   mod_log = fast_logistic_regression_cpp(as.matrix(X), as.numeric(y), maxit = control$maxit, tol = control$epsilon)
#   b = mod_log$b
#   mu = 1 / (1 + exp(-drop(X %*% b)))
#   # guard against numerical drift to 0/1
#   mu <- pmin(pmax(mu, 1e-12), 1 - 1e-12)

#   # objective: negative log-likelihood profiled over beta (beta is fixed now)
#   obj <- function(logphi) {
#     phi = exp(logphi)
#     # return NEGATIVE log-likelihood
#     -beta_loglik_cpp(y, mu, phi, wt = weights)
#   }

#   opt <- stats::nlminb(start = log(start_phi), objective = obj,
#                 lower = bounds_logphi[1], upper = bounds_logphi[2])

#   phi_hat <- as.numeric(exp(opt$par))

#   # Construct weights for the object matching beta_family/glm.fit behavior
#   # weights = (1+phi) * mu * (1-mu)
#   w_final = (1 + phi_hat) * mod_log$w

#   out <- list(
#     b = b,
#     phi = phi_hat,
#     converged_inner = TRUE,
#     w = w_final
#   )
#   class(out) <- "beta_glm_profile"
#   out
# }

# fast_beta_regression_with_var <- function(X, y,
#                              start_phi = 10,
#                              bounds_logphi = c(log(1e-3), log(1e4)),
#                              control = stats::glm.control(epsilon=1e-8, maxit=100)) {
#     fit_hat = fast_beta_regression(X, y, start_phi = start_phi, bounds_logphi = bounds_logphi, control = control)
#     XtWX <- crossprod(sqrt(fit_hat$w) * X)
#     fit_hat$ssq_b_2 = eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp(XtWX, 2)
#     fit_hat
# }

# binomial_link_cache = binomial()

# beta_family <- function(link = "logit", phi = 10) {
#   linkobj <- stats::make.link(link)

#   variance <- function(mu) {
#     mu * (1 - mu) / (1 + phi)
#   }

#   dev.resids <- function(y, mu, wt) {
#     # negative twice log-likelihood contribution
# #    2 * wt * (lbeta(mu * phi, (1 - mu) * phi) -
# #              (mu * phi - 1) * log(y) -
# #              ((1 - mu) * phi - 1) * log(1 - y))
# 	beta_dev_resids_cpp(y, mu, phi, wt)
#   }

#   aic <- function(y, n, mu, wt, dev) {
#     # -2*logLik + 2*edf
# #    -2 * sum(wt * (
# #      lgamma(phi) - lgamma(mu * phi) - lgamma((1 - mu) * phi) +
# #      (mu * phi - 1) * log(y) + ((1 - mu) * phi - 1) * log(1 - y)
# #    )) + 2 * (length(mu) + 1)
#     beta_aic_cpp(y, mu, phi, wt)
#   }

#   mu.eta <- linkobj$mu.eta

#   structure(
#     list(
#       family = "Beta",
#       link = linkobj$name,
#       linkfun = linkobj$linkfun,
#       linkinv = linkobj$linkinv,
#       variance = variance,
#       dev.resids = dev.resids,
#       aic = aic,
#       mu.eta = mu.eta,
#       initialize = expression({
#         if (any(y <= 0 | y >= 1))
#           stop("y values must be in (0,1) for beta regression")
#         mustart <- (y + 0.5) / 2  # crude initialization
#       })
#     ),
#     class = "family"
#   )
# }

#beta_loglik <- function(y, mu, phi, wt = 1) {
#  sum(wt * (
#    lgamma(phi) - lgamma(mu * phi) - lgamma((1 - mu) * phi) +
#      (mu * phi - 1) * log(y) + ((1 - mu) * phi - 1) * log1p(-y)
#  ))
#}

# fast_beta_regression_mle_r <- function(X, y, start_phi = 10) {
#   # Get starting values for beta from a quick logistic regression
#   warm_start_beta <- fast_logistic_regression(X, y)$b

#   # Call the full MLE in C++ without computing standard errors
#   mod_cpp = fast_beta_regression_mle(y, X, warm_start_beta = warm_start_beta, start_phi = start_phi, compute_std_errs = FALSE)

#   out <- list(
#     b = mod_cpp$coefficients,
#     phi = mod_cpp$phi
#   )
#   out
# }

# fast_beta_regression_mle_r_with_var <- function(X, y, start_phi = 10) {
#   # Get starting values for beta from a quick logistic regression
#   warm_start_beta <- fast_logistic_regression(X, y)$b

#   # Call the full MLE in C++ and compute standard errors
#   mod_cpp = fast_beta_regression_mle(y, X, warm_start_beta = warm_start_beta, start_phi = start_phi, compute_std_errs = TRUE)

#   out <- list(
#     b = mod_cpp$coefficients,
#     phi = mod_cpp$phi,
#     # ssq_b_2 is the squared standard error of the treatment effect, which is the second coefficient
#     # The std_errs from C++ includes standard errors for all coefficients and log(phi)
#     # We assume the second element of std_errs corresponds to the treatment effect std error
#     ssq_b_2 = mod_cpp$std_errs[2]^2
#   )
#   class(out) <- "beta_glm_mle"
#   out
# }


#fast_glm_with_var = function(X, y, glm_function){
#	mod = glm_function(X, y)
#	XtWX = eigen_Xt_times_diag_w_times_X_cpp(X, mod$w)
#	mod$ssq_b_2 = eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp(XtWX, 2)
#	mod
#}
#
#fast_glm_nb <- function(X, y, maxit = 50, tol = 1e-8, trace = FALSE) {
#  stopifnot(is.matrix(X), is.numeric(y), length(y) == nrow(X))
#
#  n <- length(y)
#  p <- ncol(X)
#
#  beta <- rep(0, p)
#  avg_y = mean(y)
#  theta <- avg_y^2  / (var(y) - avg_y) #method of moments estimate to start
#  for (i in 1 : maxit) {
#    mu <- exp(X %*% beta)
#    W <- mu / (1 + mu / theta)
#    z <- X %*% beta + (y - mu) / mu
#    fit <- lm.wfit(X, z, w = as.vector(W))
#    beta_new <- fit$coefficients
#
#    if (any(is.na(beta_new))) stop("NA in coefficients; possibly singular matrix")
#
#	opt <- optim(par = theta, fn = neg_loglik_nb_cpp, beta = beta_new, X = X, y = y, method = "L-BFGS-B", lower = 1e-8)
#    theta_new <- opt$par
#
#    if (trace) cat(sprintf("Iter %d: logLik=%.4f  theta=%.4f\n", i, loglik_nb(beta_new, theta_new), theta_new))
#
#    if (max(abs(beta_new - beta)) < tol && abs(theta_new - theta) < tol)
#      break
#
#    beta <- beta_new
#    theta <- theta_new
#  }
#
#  eta <- as.vector(X %*% beta)
#  mu <- exp(eta)
#
#  # Standard errors via observed information
#  W <- mu / (1 + mu / theta)
##  cov_beta <- tryCatch(solve(crossprod(X, X * W)), error = function(e) matrix(NA, p, p))
##  se <- sqrt(diag(cov_beta))
#
#  list(
#    b = beta,
#    ssq_b_2 = eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp(crossprod(X, X * W), 2)
#  )
#}


#	loglik <- function(n, th, mu, y, w) sum(w * (lgamma(th +
#        y) - lgamma(th) - lgamma(y + 1) + th * log(th) + y *
#        log(mu + (y == 0)) - (th + y) * log(th + mu)))
#    link <- log
#    fam0 <- if (missing(init.theta))
#        do.call("poisson", list(link = link))
#    else do.call("negative.binomial", list(theta = init.theta,
#        link = link))
#    mf <- Call <- match.call()
#    m <- match(c("formula", "data", "subset", "weights", "na.action",
#        "etastart", "mustart", "offset"), names(mf), 0)
#    mf <- mf[c(1, m)]
#    mf$drop.unused.levels <- TRUE
#    mf[[1L]] <- quote(stats::model.frame)
#    mf <- eval.parent(mf)
#    Terms <- attr(mf, "terms")
#    if (method == "model.frame")
#        return(mf)
#    Y <- model.response(mf, "numeric")
#    X <- if (!is.empty.model(Terms))
#        model.matrix(Terms, mf, contrasts)
#    else matrix( NROW(Y), 0)
#    w <- model.weights(mf)
#    if (!length(w))
#        w <- rep(1, nrow(mf))
#    else if (any(w < 0))
#        stop("negative weights not allowed")
#    offset <- model.offset(mf)
#    mustart <- model.extract(mf, "mustart")
#    etastart <- model.extract(mf, "etastart")
#    n <- length(Y)
#    if (!missing(method)) {
#        if (!exists(method, mode = "function"))
#            stop(gettextf("unimplemented method: %s", sQuote(method)),
#                domain = NA)
#        glm.fitter <- get(method)
#    }
#    else {
#        method <- "glm.fit"
#        glm.fitter <- stats::glm.fit
#    }
#    if (control$trace > 1)
#        message("Initial fit:")
#    fit <- glm.fitter(x = X, y = Y, weights = w, start = start,
#        etastart = etastart, mustart = mustart, offset = offset,
#        family = fam0, control = list(maxit = control$maxit,
#            epsilon = control$epsilon, trace = control$trace >
#                1), intercept = attr(Terms, "intercept") > 0)
#    class(fit) <- c("glm", "lm")
#    mu <- fit$fitted.values
#    th <- as.vector(theta.ml(Y, mu, sum(w), w, limit = control$maxit,
#        trace = control$trace > 2))
#    if (control$trace > 1)
#        message(gettextf("Initial value for 'theta': %f", signif(th)),
#            domain = NA)
#    fam <- do.call("negative.binomial", list(theta = th, link = link))
#    iter <- 0
#    d1 <- sqrt(2 * max(1, fit$df.residual))
#    d2 <- del <- 1
#    g <- fam$linkfun
#    Lm <- loglik(n, th, mu, Y, w)
#    Lm0 <- Lm + 2 * d1
#    while ((iter <- iter + 1) <= control$maxit && (abs(Lm0 -
#        Lm)/d1 + abs(del)/d2) > control$epsilon) {
#        eta <- g(mu)
#        fit <- glm.fitter(x = X, y = Y, weights = w, etastart = eta,
#            offset = offset, family = fam, control = list(maxit = control$maxit,
#                epsilon = control$epsilon, trace = control$trace >
#                  1), intercept = attr(Terms, "intercept") >
#                0)
#        t0 <- th
#        th <- theta.ml(Y, mu, sum(w), w, limit = control$maxit,
#            trace = control$trace > 2)
#        fam <- do.call("negative.binomial", list(theta = th,
#            link = link))
#        mu <- fit$fitted.values
#        del <- t0 - th
#        Lm0 <- Lm
#        Lm <- loglik(n, th, mu, Y, w)
#        if (control$trace) {
#            Ls <- loglik(n, th, Y, Y, w)
#            Dev <- 2 * (Ls - Lm)
#            message(sprintf("Theta(%d) = %f, 2(Ls - Lm) = %f",
#                iter, signif(th), signif(Dev)), domain = NA)
#        }
#    }
#    if (!is.null(attr(th, "warn")))
#        fit$th.warn <- attr(th, "warn")
#    if (iter > control$maxit) {
#        warning("alternation limit reached")
#        fit$th.warn <- gettext("alternation limit reached")
#    }
#    if (length(offset) && attr(Terms, "intercept")) {
#        null.deviance <- if (length(Terms))
#            glm.fitter(X[, "(Intercept)", drop = FALSE], Y, w,
#                offset = offset, family = fam, control = list(maxit = control$maxit,
#                  epsilon = control$epsilon, trace = control$trace >
#                    1), intercept = TRUE)$deviance
#        else fit$deviance
#        fit$null.deviance <- null.deviance
#    }
#    class(fit) <- c("negbin", "glm", "lm")
#    fit$terms <- Terms
#    fit$formula <- as.vector(attr(Terms, "formula"))
#    Call$init.theta <- signif(as.vector(th), 10)
#    Call$link <- link
#    fit$call <- Call
#    if (model)
#        fit$model <- mf
#    fit$na.action <- attr(mf, "na.action")
#    if (x)
#        fit$x <- X
#    if (!y)
#        fit$y <- NULL
#    fit$theta <- as.vector(th)
#    fit$SE.theta <- attr(th, "SE")
#    fit$twologlik <- as.vector(2 * Lm)
#    fit$aic <- -fit$twologlik + 2 * fit$rank + 2
#    fit$contrasts <- attr(X, "contrasts")
#    fit$xlevels <- .getXlevels(Terms, mf)
#    fit$method <- method
#    fit$control <- control
#    fit$offset <- offset
#    fit

#' Conditional logistic regression for matched pairs
#'
#' @name clogit_helper
#' @description Internal method.
#' Replaces bclogit::clogit. For matched pairs (exactly 2 subjects per stratum),
#' the conditional log-likelihood depends only on discordant pairs. Within each
#' discordant pair the contribution reduces to ordinary logistic regression on
#' signed within-pair differences with no intercept.
#'
#' @param y_m       Binary outcome vector (0/1) for matched subjects.
#' @param X_m       Covariate matrix or data.frame (may have 0 columns).
#' @param w_m       Treatment indicator (0/1) for matched subjects.
#' @param strata_m  Integer stratum IDs (pair labels) for matched subjects.
#' @return          Result list from fast_logistic_regression_with_var:
#'                  b[1] = beta_T, ssq_b_j = Var(beta_T). NULL on failure.
#' @keywords internal
clogit_helper = function(y_m, X_m, w_m, strata_m){
	p     = if (is.null(X_m) || ncol(X_m) == 0L) 0L else ncol(X_m)
	X_mat = if (p > 0L) as.matrix(X_m) else matrix(nrow = length(y_m), ncol = 0L)

	res = collect_discordant_pairs_cpp(as.double(y_m), as.double(w_m), X_mat, as.integer(strata_m))
	nd  = res$nd
	if (nd < p + 5L) return(NULL)         # too few discordant pairs

	X_full = if (p > 0L) cbind(res$t_diffs, res$X_diffs) else matrix(res$t_diffs, ncol = 1L)

	tryCatch(
		fast_logistic_regression_with_var(X_full, res$y_01, j = 1L),
		error = function(e) NULL
	)
}

#' Fast Logistic Regression with Targeted Variance (C++ Backend)
#'
#' Fits the same logistic regression model as
#' \code{\link{fast_logistic_regression_cpp}} (see that page for the full
#' model and log-odds-ratio interpretation) and additionally computes the
#' variance of two coefficients — the caller-selected \code{j}-th coefficient
#' and, separately, the 2nd coefficient (the package's usual treatment-effect
#' position) — via a targeted diagonal-entry inversion of the working-weights
#' Fisher information, rather than a full matrix inverse. Unlike
#' \code{\link{fast_logistic_regression_cpp}}, \code{maxit} and \code{tol} are
#' not exposed here: they are fixed internally at 100 iterations and
#' \code{1e-8} tolerance.
#'
#' @details
#' \strong{Variance computation.} The working-weights Fisher information
#' \eqn{X^\top W X} is restricted to the free (non-\code{fixed_idx})
#' parameters; \code{ssq_b_j} and \code{ssq_b_2} are each obtained via a
#' single targeted diagonal-entry inversion
#' (\code{compute_diagonal_inverse_entry()}) at the free-parameter position
#' corresponding to \code{j} and to column 2, respectively — \code{NA} if the
#' relevant coefficient is out of range or was itself fixed via
#' \code{fixed_idx}. \code{ssq_b_2} is always computed (when \code{ncol(X) >= 2})
#' regardless of what \code{j} is, so a caller interested in the treatment
#' effect's variance does not need to pass \code{j = 2} explicitly.
#'
#' @param  X A numeric matrix of predictor variables. It is assumed that an intercept column
#'   (e.g., a column of ones) is already included in \code{X} if desired.
#' @param  y A numeric vector of the response variable, expected to be binary (0 or 1).
#' @param j 1-based index (into \code{X}'s columns) of the coefficient to
#'   compute \code{ssq_b_j} for. Defaults to 2.
#' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}.
#'   If provided, \code{smart_cold_start} is ignored.
#' @param smart_cold_start Logical. If \code{TRUE} and no \code{warm_start_beta}
#'   is supplied, use an OLS-based initial guess rather than a zero cold start.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed
#'   rather than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at.
#' @param optimization_alg Optimization algorithm: \code{"irls"} (default),
#'   \code{"lbfgs"}, or \code{"newton_raphson"}; see
#'   \code{\link{.normalize_optimizer_algorithm}}.
#' @param warm_start_weights Optional initial IRLS working weights for the
#'   first iteration.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information.
#' @return A list with components \code{b}/\code{params} (estimated
#'   coefficients \eqn{\hat\beta}, identical to each other),
#'   \code{ssq_b_j}/\code{ssq_b_2} (the two targeted coefficient variances
#'   described in Details), \code{score} (the score vector at
#'   \eqn{\hat\beta}), \code{observed_information}/\code{fisher_information}/
#'   \code{information} (three aliases for the same working-weights curvature
#'   matrix, tagged \code{information_type = "fisher"}), \code{hessian} (the
#'   negative of that matrix), \code{neg_loglik}/\code{neg_ll} (aliases for the
#'   negative log-likelihood), \code{loglik} (its negation), \code{converged}
#'   (logical, \code{gradient_norm < tol}, uniform across optimizers),
#'   \code{num_iter}, \code{hit_iteration_cap} (logical, mutually exclusive
#'   with \code{converged}), and \code{gradient_norm}.
#' @seealso \code{\link{fast_logistic_regression_cpp}} for the estimate-only
#'   variant and the full model documentation.
#' @usage fast_logistic_regression_with_var_cpp(
#'   X,
#'   y,
#'   j = 2L,
#'   warm_start_beta = NULL,
#'   smart_cold_start = FALSE,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "irls",
#'   warm_start_weights = NULL,
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_logistic_regression_with_var_cpp
#' @export
NULL

#' Export of C++ function fast_probit_regression_with_var_cpp
#' @name fast_probit_regression_with_var_cpp
#' @export
NULL

#' Export of C++ function fast_continuation_ratio_regression_with_var_cpp
#' @name fast_continuation_ratio_regression_with_var_cpp
#' @export
NULL

#' Build a Reusable Stratified Cox Data Cache (C++ Backend)
#'
#' Precomputes and caches, per stratum, the sorted risk-set structure needed
#' to evaluate the stratified Cox partial-likelihood, score, and Hessian, so
#' that repeated Newton-Raphson or L-BFGS fits on the same
#' \code{(X, y, dead, strata)} data (e.g. across bootstrap/randomization
#' replicates of the treatment column) do not repeat the per-stratum sort and
#' event-time tabulation on every call. This is the stratified counterpart of
#' \code{\link{build_cox_data_cache_cpp}}; the returned cache is consumed by
#' \code{\link{fast_coxph_regression_prebuilt_cpp}}, which implements the
#' same partial-likelihood family as \code{\link{fast_coxph_regression}} and
#' \code{\link{fast_coxph_regression_cpp}}, extended to sum the log-partial-
#' likelihood, score, and Hessian across independent strata-specific risk
#' sets while sharing a single regression coefficient vector \eqn{\beta}
#' across all strata (a shared-\eqn{\beta}, per-stratum-baseline-hazard
#' stratified Cox model).
#'
#' @details
#' \strong{Model.} No fitting happens here; this function only partitions
#' subjects into per-stratum risk sets and prepares each one for the
#' Breslow-tied stratified Cox partial likelihood
#' \deqn{\ell(\beta) = \sum_{s} \sum_{k \in s} \Big[ \big(\textstyle\sum_{i \in D_{sk}} x_i\big)^\top \beta - d_{sk} \log\!\big(\textstyle\sum_{j \in R_{sk}} e^{x_j^\top \beta}\big) \Big],}
#' where the outer sum runs over strata \eqn{s} (distinct baseline hazards),
#' \eqn{D_{sk}} is the set of subjects with an event at the \eqn{k}-th unique
#' event time within stratum \eqn{s}, and \eqn{R_{sk}} is the corresponding
#' within-stratum risk set (subjects in stratum \eqn{s} with \code{y >= }
#' that event time). Risk sets never cross strata, so subjects are only ever
#' compared to other subjects in the same stratum; \eqn{\beta} is shared
#' across strata while the baseline hazard is allowed to differ arbitrarily
#' by stratum. See \code{\link{fast_coxph_regression}} for the unstratified
#' model, scale, and optimizer contract; this page documents only the
#' per-stratum cache construction.
#'
#' \strong{What is cached.} Subjects are grouped into strata by their
#' integer \code{strata} label (via an ordered \code{std::map<int, ...>},
#' so strata are processed and stored in ascending label order). Within each
#' stratum, a \code{CoxData} record is built exactly as in
#' \code{\link{build_cox_data_cache_cpp}}: subjects are sorted by ascending
#' \code{y}, ties broken by placing events before censored observations,
#' and the per-stratum unique event times and tied-event counts
#' (\code{event_counts}) are tabulated to drive the within-stratum Breslow
#' tie-handling correction.
#'
#' \strong{Input conventions.} \code{X} is an \eqn{n \times p} design matrix
#' with one row per subject and \strong{no intercept column}. \code{y} is
#' the observed time (event or censoring time) and \code{dead} is a 0/1
#' event indicator (1 = event, 0 = right-censored); both have length
#' \eqn{n} matching \code{nrow(X)}. \code{strata} is a length-\eqn{n}
#' integer vector of stratum (block/cluster) labels; labels need not be
#' contiguous or start at 1, and a stratum with a single subject or with no
#' observed events contributes an empty or degenerate risk set that carries
#' no information to the partial likelihood, score, or Hessian (its rows
#' are still stored, but they will not affect the fit). Callers are
#' expected to have already dropped uninformative strata upstream (see
#' \code{get_informative_rows()} in the stratified-Cox inference class) when
#' that matters for numerical stability; this function does not filter
#' strata itself. As with \code{\link{build_cox_data_cache_cpp}}, tied
#' event times use the Breslow approximation, there is no support for left-
#' or interval-censored data at this layer, and \code{NA}/non-finite values
#' in \code{X}, \code{y}, \code{dead}, or \code{strata} are not checked or
#' handled here.
#'
#' \strong{Return value and object lifetime.} Returns an \code{externalptr}
#' (\code{Rcpp::XPtr}) wrapping a heap-allocated
#' \code{std::vector<CoxData>} with one element per distinct stratum label
#' (ordered ascending by label), consumed by
#' \code{fast_coxph_regression_prebuilt_cpp} exactly like the length-1
#' vector returned by \code{\link{build_cox_data_cache_cpp}}. Lifetime,
#' garbage-collection, and non-serializability semantics are identical to
#' \code{\link{build_cox_data_cache_cpp}}: the cache is immutable once
#' built and safe to reuse across repeated fits as long as \code{X},
#' \code{y}, \code{dead}, and \code{strata} have not changed; callers (e.g.
#' \code{InferenceStratifiedCoxPH$private$strat_cox_data_cache}) are
#' responsible for invalidating and rebuilding it when the treatment
#' assignment, covariates, or stratification changes.
#'
#' \strong{Complexity.} \eqn{O(n \log(n/S))} for the per-stratum sorts plus
#' \eqn{O(n)} for the tabulation passes, where \eqn{n} is the number of
#' subjects and \eqn{S} is the number of distinct strata; memory use is
#' \eqn{O(np)} for the per-stratum row-major copies of \code{X} plus
#' \eqn{O(n)} for the sorted \code{y}/\code{dead} and event-time tables.
#'
#' @param X A numeric matrix of predictor variables (no intercept column);
#'   \eqn{n} rows, one per subject.
#' @param y A numeric vector of length \eqn{n} giving the observed
#'   (event or censoring) time for each subject.
#' @param dead A numeric vector of length \eqn{n} with values in \code{{0, 1}}
#'   indicating event status (1 = event/death, 0 = right-censored).
#' @param strata An integer vector of length \eqn{n} giving the stratum
#'   (block/cluster) label of each subject. Risk sets are formed
#'   separately within each distinct label.
#'
#' @return An \code{externalptr} to a cached, per-stratum sorted Cox
#'   risk-set representation of \code{(X, y, dead, strata)}, for use as the
#'   \code{cox_data_xptr} argument of
#'   \code{\link{fast_coxph_regression_prebuilt_cpp}}.
#'
#' @seealso \code{\link{build_cox_data_cache_cpp}} for the unstratified
#'   (single risk-set) analog, \code{\link{fast_coxph_regression_prebuilt_cpp}}
#'   for the fitting routine that consumes this cache, and
#'   \code{\link{fast_coxph_regression}} for the full Cox model documentation,
#'   including the partial-likelihood derivation, tie-handling, and references.
#'   Analogous Python API:
#'   \href{https://lifelines.readthedocs.io/en/latest/fitters/regression/CoxPHFitter.html}{lifelines CoxPHFitter}
#'   (stratified fits via the \code{strata} argument) and
#'   \href{https://www.statsmodels.org/dev/duration.html}{statsmodels duration models}.
#' @usage build_stratified_cox_data_cache_cpp(X, y, dead, strata)
#' @name build_stratified_cox_data_cache_cpp
#' @export
NULL

#' Build a Reusable Unstratified Cox Data Cache (C++ Backend)
#'
#' Precomputes and caches the sorted risk-set structure needed to evaluate the
#' Cox partial-likelihood, score, and Hessian, so that repeated Newton-Raphson
#' or L-BFGS fits on the same \code{(X, y, dead)} data (e.g. across
#' bootstrap/randomization replicates of the treatment column, or successive
#' \code{estimate_only} vs. full-variance calls) do not repeat the
#' \eqn{O(n \log n)} sort and event-time tabulation on every call. This is the
#' unstratified counterpart of \code{\link{build_stratified_cox_data_cache_cpp}};
#' the returned cache is consumed by \code{\link{fast_coxph_regression_prebuilt_cpp}},
#' which implements the same Cox partial-likelihood as
#' \code{\link{fast_coxph_regression}} and \code{\link{fast_coxph_regression_cpp}}.
#'
#' @details
#' \strong{Model.} No fitting happens here; this function only prepares the
#' single risk set (stratum) used by the Breslow-tied Cox partial likelihood
#'  \deqn{\ell(\beta) = \sum_{k} \Big[ \big(\textstyle\sum_{i \in D_k} x_i\big)^\top \beta - d_k \log\!\big(\textstyle\sum_{j \in R_k} e^{x_j^\top \beta}\big) \Big],}
#' where \eqn{D_k} is the set of subjects with an event at the \eqn{k}-th
#' unique event time and \eqn{R_k} is the risk set (all subjects with
#' \code{y >= } that event time). See
#' \code{\link{fast_coxph_regression}} for the full model, scale, and
#' optimizer contract; this page documents only the cache construction.
#'
#' \strong{What is cached.} Internally builds a single \code{CoxData} record
#' that: (1) sorts subjects by ascending \code{y} (observed/censoring time),
#' breaking ties by placing events (\code{dead == 1}) before censored
#' observations at the same time; (2) stores the sort-permuted \code{y},
#' \code{dead}, and row-major copy of \code{X}; and (3) tabulates the vector
#' of unique event times and, for each, the number of tied events
#' (\code{event_counts}), which drives the Breslow tie-handling correction in
#' the partial-likelihood, score, and Hessian.
#'
#' \strong{Input conventions.} \code{X} is an \eqn{n \times p} design matrix
#' with one row per subject and \strong{no intercept column} (Cox models are
#' fit on the partial likelihood, which has no intercept). \code{y} is the
#' observed time (event or censoring time), and \code{dead} is a 0/1 event
#' indicator (1 = event, 0 = right-censored); both must have length \eqn{n}
#' matching \code{nrow(X)}. Tied event times are handled via the Breslow
#' approximation (via \code{event_counts}), not the exact (Cox) or Efron
#' method. There is no support for left- or interval-censored data at this
#' layer; classes with more general censoring (see
#' \code{supports_interval_or_left_censored_data()} in
#' \code{InferenceEngine}) bypass this cache and dispatch to
#' \pkg{icenReg} instead. \code{NA}/non-finite values in \code{X}, \code{y},
#' or \code{dead} and negative values of \code{y} are not checked or handled
#' at this layer; callers are responsible for filtering or imputing upstream.
#'
#' \strong{Return value and object lifetime.} Returns an \code{externalptr}
#' (\code{Rcpp::XPtr}) wrapping a heap-allocated \code{std::vector<CoxData>}
#' of length 1 (a single unstratified stratum), so that
#' \code{fast_coxph_regression_prebuilt_cpp} can share the same stratified
#' interface as the stratified cache. The pointer owns its memory (finalizer
#' registered via \code{XPtr(..., true)}) and is freed automatically by R's
#' garbage collector; it must not be serialized (e.g. via \code{saveRDS})
#' or reused after the R session that created it exits. The cache is
#' immutable once built and safe to reuse across many calls to
#' \code{fast_coxph_regression_prebuilt_cpp} as long as \code{X}, \code{y},
#' and \code{dead} have not changed; callers (e.g.
#' \code{InferenceCoxPH$private$cox_data_cache}) are responsible for
#' invalidating and rebuilding the cache when the treatment assignment or
#' covariates change.
#'
#' \strong{Complexity.} \eqn{O(n \log n)} for the sort plus \eqn{O(n)} for
#' the tabulation pass, where \eqn{n} is the number of subjects; memory use
#' is \eqn{O(np)} for the row-major copy of \code{X} plus \eqn{O(n)} for the
#' sorted \code{y}/\code{dead} and event-time tables.
#'
#' @param X A numeric matrix of predictor variables (no intercept column);
#'   \eqn{n} rows, one per subject.
#' @param y A numeric vector of length \eqn{n} giving the observed
#'   (event or censoring) time for each subject.
#' @param dead A numeric vector of length \eqn{n} with values in \code{{0, 1}}
#'   indicating event status (1 = event/death, 0 = right-censored).
#'
#' @return An \code{externalptr} to a cached, sorted Cox risk-set
#'   representation of \code{(X, y, dead)}, for use as the \code{cox_data_xptr}
#'   argument of \code{\link{fast_coxph_regression_prebuilt_cpp}}.
#'
#' @seealso \code{\link{build_stratified_cox_data_cache_cpp}} for the
#'   stratified (multiple risk-set) analog, \code{\link{fast_coxph_regression_prebuilt_cpp}}
#'   for the fitting routine that consumes this cache, and
#'   \code{\link{fast_coxph_regression}} for the full Cox model documentation,
#'   including the partial-likelihood derivation, tie-handling, and references.
#'   Analogous Python API: \href{https://lifelines.readthedocs.io/en/latest/fitters/regression/CoxPHFitter.html}{lifelines CoxPHFitter}.
#' @usage build_cox_data_cache_cpp(X, y, dead)
#' @name build_cox_data_cache_cpp
#' @export
NULL

#' Fast Cox Proportional Hazards Regression, Cache-Reusing Fit (C++ Backend)
#'
#' Fits the same unstratified-\emph{or}-stratified Cox partial-likelihood model
#' documented at \code{\link{build_cox_data_cache_cpp}} /
#' \code{\link{build_stratified_cox_data_cache_cpp}}, but takes a
#' \strong{pre-built} risk-set cache (\code{cox_data_xptr}, an \code{externalptr}
#' produced by one of those two functions) instead of raw \code{(X, y, dead)}
#' data, skipping the sort/tabulation step on every call. This is the entry point
#' the package's Cox inference classes (e.g. \code{InferenceCoxPH},
#' \code{InferenceStratifiedCoxPH}) use for repeated fits on the same data
#' (successive \code{estimate_only} vs. full-variance calls, or bootstrap/
#' randomization replicates that only change the treatment column of \code{X},
#' rebuilding the cache only when the covariates or assignment actually change).
#' \code{\link{fast_coxph_regression_cpp}} is the equivalent one-shot entry point
#' that builds and discards the cache internally, for callers that only need a
#' single fit.
#'
#' @details
#' Because \code{cox_data_xptr} carries a fixed, already-sorted risk-set structure
#' (whether unstratified — one risk set — or stratified — one risk set per
#' stratum, depending on which cache-building function produced it), the number
#' and identity of subjects/strata are entirely determined by the cache; only the
#' optimization behavior (warm starts, convergence, algorithm) is configurable
#' through this function's own arguments. Passing a stale cache (built from data
#' that has since changed) silently fits the model to the \emph{cached} data, not
#' the caller's current \code{X}/\code{y}/\code{dead} — callers are responsible for
#' invalidating and rebuilding the cache when the underlying data changes; see
#' \code{\link{build_cox_data_cache_cpp}} for the exact caching/mutation contract.
#'
#' @param cox_data_xptr An \code{externalptr} to a cached Cox risk-set
#'   representation, as returned by \code{\link{build_cox_data_cache_cpp}}
#'   (unstratified) or \code{\link{build_stratified_cox_data_cache_cpp}}
#'   (stratified).
#' @param warm_start_beta Optional starting values for the coefficients \eqn{\beta}.
#' @param smart_cold_start Logical. If \code{TRUE} (default) and no
#'   \code{warm_start_beta} is supplied, use an OLS-based initial guess rather than
#'   a zero cold start.
#' @param estimate_only Logical. If \code{TRUE}, skip variance-covariance
#'   matrix calculation for speed.
#' @param maxit Maximum number of Newton-Raphson/L-BFGS iterations.
#' @param tol Convergence tolerance.
#' @param fixed_idx Optional integer indices of coefficients to hold fixed rather
#'   than estimate.
#' @param fixed_values Optional values to fix the parameters named by
#'   \code{fixed_idx} at; must be the same length as \code{fixed_idx}.
#' @param optimization_alg Optimization algorithm: \code{"newton_raphson"} (default) or \code{"lbfgs"}.
#' @param warm_start_fisher_info Optional initial Fisher Information matrix to
#'   warm-start curvature information for the optimizer.
#'
#' @return A list containing the following components:
#' \describe{
#' \item{coefficients}{A numeric vector of the estimated log-hazard-ratio
#'   coefficients \eqn{\hat\beta}.}
#' \item{vcov}{The variance-covariance matrix of \eqn{\hat\beta}; omitted when
#'   \code{estimate_only = TRUE}.}
#' \item{neg_ll}{The negative Cox partial log-likelihood at the final iteration.}
#' \item{converged}{A logical value indicating whether the algorithm converged.}
#' \item{iterations}{The number of optimizer iterations performed.}
#' \item{fisher_information}{The Hessian of the negative partial log-likelihood at
#'   the fitted coefficients.}
#' \item{gradient_norm}{The norm of the score (gradient) vector at convergence.}
#' }
#' @seealso \code{\link{build_cox_data_cache_cpp}}/
#'   \code{\link{build_stratified_cox_data_cache_cpp}} for building the required
#'   cache and the full Cox partial-likelihood model documentation;
#'   \code{\link{fast_coxph_regression_cpp}} for the one-shot (build-and-discard)
#'   variant.
#' @usage fast_coxph_regression_prebuilt_cpp(
#'   cox_data_xptr,
#'   warm_start_beta = NULL,
#'   smart_cold_start = TRUE,
#'   estimate_only = FALSE,
#'   maxit = 20L,
#'   tol = 1e-9,
#'   fixed_idx = NULL,
#'   fixed_values = NULL,
#'   optimization_alg = "newton_raphson",
#'   warm_start_fisher_info = NULL
#' )
#' @name fast_coxph_regression_prebuilt_cpp
#' @export
NULL

#' Export of C++ function newcombe_independent_ci_cpp
#' @name newcombe_independent_ci_cpp
#' @export
NULL

#' Export of C++ function mn_pvalue_cpp
#' @name mn_pvalue_cpp
#' @export
NULL

#' Export of C++ function ols_hc2_post_fit_cpp
#' @name ols_hc2_post_fit_cpp
#' @export
NULL

#' Export of C++ function gcomp_logistic_post_fit_cpp
#' @name gcomp_logistic_post_fit_cpp
#' @export
NULL

#' Export of C++ function gcomp_ordinal_proportional_odds_post_fit_cpp
#' @name gcomp_ordinal_proportional_odds_post_fit_cpp
#' @export
NULL

#' Exact Two-Group Jonckheere-Terpstra Test via Full Randomization Enumeration (C++ Backend)
#'
#' Computes the exact randomization-distribution p-value and a probabilistic-index
#' effect size for the two-group Jonckheere-Terpstra statistic — which, with exactly
#' two groups (\code{w} in \code{{0, 1}}), coincides with the Wilcoxon-Mann-Whitney
#' \eqn{U} statistic generalized to handle ties (repeated ordinal levels in \code{y}):
#' \deqn{U = \sum_{k} t_k \big(2 L_k + (n_k - t_k)\big) / 2,}
#' summed over the \eqn{K} distinct observed levels of \code{y} (in increasing order),
#' where \eqn{n_k} is the total count at level \eqn{k}, \eqn{t_k} is the observed count
#' of \code{w == 1} subjects at level \eqn{k}, and \eqn{L_k} is the number of subjects
#' at strictly lower levels (this is the standard "number of favorable comparisons"
#' Mann-Whitney statistic, adapted for tied/grouped ordinal data — a tie at the same
#' level contributes \eqn{1/2} rather than 0 or 1). The exact (not asymptotic,
#' not Monte Carlo) null/reference distribution of this statistic under the sharp null
#' of no treatment effect is obtained by enumerating, via a dynamic-programming
#' recursion over levels (\code{recurse_jt_distribution()}), every way to distribute
#' \code{n_treat} "treated" labels among the \eqn{n} subjects consistent with the fixed
#' per-level totals \eqn{n_k} — i.e. the exact multivariate hypergeometric
#' randomization distribution of the statistic conditional on the observed level
#' counts, with each configuration's probability computed in log-space from
#' log-binomial-coefficient weights to avoid overflow for larger \eqn{n}.
#'
#' @details
#' \strong{Randomization test, not a model-based test.} This is a randomization
#' (permutation) test in the Fisherian sense: it conditions on the observed marginal
#' level counts \eqn{n_k} and the group sizes \code{n_treat}/\code{n_control}, and asks
#' how extreme the observed statistic is relative to every other way those same labels
#' could have been randomly assigned, so its validity does not depend on any
#' distributional assumption about \code{y} beyond exchangeability under the null. The
#' two-sided p-value is \eqn{p_{\mathrm{exact}} = \min(1, 2 \min(p_{\mathrm{lower}},
#' p_{\mathrm{upper}}))}, where \eqn{p_{\mathrm{lower}}}/\eqn{p_{\mathrm{upper}}} are
#' the exact one-sided tail probabilities of the randomization distribution at or below
#' / at or above the observed statistic.
#'
#' \strong{Effect size (\code{superiority}).} \code{superiority} is the probabilistic
#' index \eqn{\Pr(Y_T > Y_C) + \tfrac{1}{2}\Pr(Y_T = Y_C)} (equivalently \eqn{U}
#' rescaled to \eqn{[0, 1]} by dividing by \eqn{n_{\mathrm{treat}} \cdot
#' n_{\mathrm{control}}}), the probability a randomly chosen treated subject's ordinal
#' outcome exceeds a randomly chosen control subject's, counting ties as half a win;
#' \code{0.5} indicates no stochastic ordering between groups, and \code{1}/\code{0}
#' indicate the treated group's outcomes are uniformly higher/lower.
#'
#' \strong{Input conventions.} \code{y} is coerced to integer and treated as an ordinal
#' (or any orderable-by-integer-value) response with an arbitrary number of tied
#' levels; \code{w} must be an integer/coercible-to-integer vector of \code{{0, 1}}
#' values with both groups non-empty. \code{NA} in either \code{y} or \code{w} is not
#' permitted and raises an error, as does a non-\code{{0,1}} value in \code{w} or an
#' empty input.
#'
#' \strong{Complexity.} The recursion's state space scales with the number of distinct
#' possible statistic values (\eqn{O(n_{\mathrm{treat}} \cdot n_{\mathrm{control}})}
#' many), and thread-local buffers are reused (not reallocated) across repeated calls
#' within the same thread for the same or smaller problem sizes; this exact enumeration
#' is exponential in the number of distinct levels/group sizes in the worst case
#' (unlike an asymptotic normal-approximation JT test), so it is intended for small-to-
#' moderate \eqn{n} where exactness matters more than raw speed.
#'
#' @param y Integer (or integer-coercible) vector of length \eqn{n} giving each
#'   subject's ordinal response value; ties (repeated values) are handled via the
#'   grouped Mann-Whitney formula above. Must not contain \code{NA}.
#' @param w Integer (or integer-coercible) vector of length \eqn{n} with values in
#'   \code{{0, 1}} giving each subject's group membership; both groups must be
#'   non-empty and no \code{NA} is permitted.
#' @return A list with components \code{stat2} (twice the observed \eqn{U} statistic,
#'   an integer, used internally to keep the enumeration in integer arithmetic),
#'   \code{n_treat}, \code{n_control} (the two group sizes), \code{superiority} (the
#'   probabilistic-index effect size described above), \code{p_lower}, \code{p_upper}
#'   (the exact one-sided randomization-distribution tail probabilities), and
#'   \code{p_exact} (the exact two-sided p-value).
#' @seealso \href{https://en.wikipedia.org/wiki/Mann\%E2\%80\%93Whitney_U_test}{Mann-Whitney
#'   U test} and
#'   \href{https://en.wikipedia.org/wiki/Jonckheere\%27s_trend_test}{Jonckheere's trend
#'   test} for background; analogous Python API:
#'   \href{https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.mannwhitneyu.html}{SciPy
#'   \code{mannwhitneyu}} (\code{method="exact"} for the same exact-enumeration
#'   approach, though SciPy's exact path does not handle ties the same way).
#' @usage exact_jonckheere_terpstra_pval_cpp(y, w)
#' @name exact_jonckheere_terpstra_pval_cpp
#' @export
NULL
