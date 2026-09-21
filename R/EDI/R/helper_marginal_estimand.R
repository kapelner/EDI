#' Central-difference numerical gradient
#'
#' @description Computes the gradient of a scalar function \code{f} at
#' \code{theta} via central differences, one coordinate at a time. Used by
#' the marginal-estimand delta-method helpers
#' (\code{marginal_estimand_delta_se()}) where an analytic gradient of a
#' g-computation mean-difference/ratio functional is impractical to derive
#' and verify by hand for a multi-part mixture likelihood; the numerical
#' gradient is checked against a real fitted model's finite-difference
#' behavior before being trusted (see \code{marginal_estimand_report.md ->
#' TODO-4}).
#'
#' @param f A function of a single numeric vector argument, returning a
#'   numeric scalar.
#' @param theta Numeric vector, the point at which to differentiate.
#' @param eps Step size for the central difference. Default \code{1e-5}.
#' @return A numeric vector the same length as \code{theta}.
#' @keywords internal
#' @noRd
numerical_gradient_central = function(f, theta, eps = 1e-5) {
	p = length(theta)
	g = numeric(p)
	for (i in seq_len(p)) {
		theta_up = theta
		theta_up[i] = theta_up[i] + eps
		theta_dn = theta
		theta_dn[i] = theta_dn[i] - eps
		g[i] = (f(theta_up) - f(theta_dn)) / (2 * eps)
	}
	g
}

#' Delta-method standard error for a scalar functional of fitted parameters
#'
#' @description Given a fitted parameter vector \code{theta_hat}, its
#' covariance matrix \code{vcov}, and a scalar \code{functional} of
#' \code{theta} (e.g. a g-computation mean-difference or log-rate-ratio),
#' returns the delta-method point estimate and standard error:
#' \eqn{\widehat{se} = \sqrt{\nabla functional(\hat\theta)^\top \, \widehat{\mathrm{Var}}(\hat\theta) \, \nabla functional(\hat\theta)}}.
#' The gradient is computed numerically via
#' \code{numerical_gradient_central()} rather than derived analytically per
#' family — the mixture likelihoods this is used for (zero/one-inflated
#' beta, zero-augmented Poisson/negative-binomial) have enough
#' parameterization variants that a hand-derived analytic gradient is a
#' realistic source of a silent sign or index error, whereas a central
#' difference is mechanically checkable against the functional itself. Not
#' used inside any resampling loop (bootstrap/randomization use the point
#' estimate only, never this SE), so a handful of extra functional
#' evaluations per call is not a performance concern.
#'
#' @param theta_hat Numeric vector, the fitted parameter vector (in the same
#'   order/parameterization \code{vcov} and \code{functional} expect).
#' @param vcov Numeric matrix, the covariance matrix of \code{theta_hat}
#'   (same order/dimension as \code{theta_hat}).
#' @param functional A function of \code{theta} returning a numeric scalar
#'   (the estimand as a function of the parameter vector).
#' @param eps Step size for the numerical gradient. Default \code{1e-5}.
#' @return A list with \code{estimate} (\code{functional(theta_hat)}),
#'   \code{se} (the delta-method standard error, or \code{NA_real_} if the
#'   quadratic form is not finite/non-negative), and \code{gradient} (the
#'   numerical gradient, for diagnostics).
#' @keywords internal
#' @noRd
marginal_estimand_delta_se = function(theta_hat, vcov, functional, eps = 1e-5) {
	theta_hat = as.numeric(theta_hat)
	vcov = as.matrix(vcov)
	estimate = tryCatch(as.numeric(functional(theta_hat))[1L], error = function(e) NA_real_)
	if (!is.finite(estimate) || is.null(vcov) || nrow(vcov) != length(theta_hat) || ncol(vcov) != length(theta_hat)) {
		return(list(estimate = estimate, se = NA_real_, gradient = rep(NA_real_, length(theta_hat))))
	}
	grad = tryCatch(numerical_gradient_central(functional, theta_hat, eps = eps), error = function(e) NULL)
	if (is.null(grad) || !all(is.finite(grad))) {
		return(list(estimate = estimate, se = NA_real_, gradient = grad %||% rep(NA_real_, length(theta_hat))))
	}
	var_hat = as.numeric(t(grad) %*% vcov %*% grad)
	se = if (is.finite(var_hat) && var_hat >= 0) sqrt(var_hat) else NA_real_
	list(estimate = estimate, se = se, gradient = grad)
}

#' Model-implied mean for a log-link count model
#'
#' @description Shared by the Poisson-family classes (\code{InferenceCountPoisson},
#' \code{InferenceCountQuasiPoisson}), whose mean model is \eqn{E[Y|w,x] = \exp(X\beta)}.
#'
#' @param beta Numeric coefficient vector.
#' @param X Design matrix.
#' @return Numeric vector of fitted means.
#' @keywords internal
#' @noRd
poisson_family_mean_from_coefs = function(beta, X) {
	exp(as.numeric(X %*% beta))
}

#' G-computation marginal functional for a log-link count model
#'
#' @description Average of the fitted mean over the empirical covariate
#' distribution with every subject plugged in at treatment = 1 and = 0 (the
#' treatment is column 2 of the fitting design matrix, per each class's
#' \code{generate_mod()} convention), returned as the mean difference or, for
#' \code{"marginal_ratio"}, the log ratio. Any other estimand name falls
#' through to the mean difference.
#'
#' @param beta Numeric coefficient vector.
#' @param X Design matrix with the treatment in column 2 (not modified).
#' @param estimand \code{"marginal_mean_diff"} or \code{"marginal_ratio"}.
#' @return A numeric scalar.
#' @keywords internal
#' @noRd
poisson_family_marginal_functional = function(beta, X, estimand) {
	X1 = X; X1[, 2L] = 1
	X0 = X; X0[, 2L] = 0
	mu1 = mean(poisson_family_mean_from_coefs(beta, X1))
	mu0 = mean(poisson_family_mean_from_coefs(beta, X0))
	if (identical(estimand, "marginal_ratio")) log(mu1 / mu0) else mu1 - mu0
}

#' Marginal-estimand estimate and delta-method SE from a cached log-link fit
#'
#' @description The \code{compute_marginal_estimand_estimate()} body shared by
#' the Poisson-family classes: a pure post-fit transform of the single cached
#' fit (no refit). The point estimate is the g-computed functional at the
#' fitted coefficients; the SE is the delta-method SE against the fit's own
#' coefficient covariance (\code{mod$vcov}), so a class controls its variance
#' model (plain information inverse for Poisson, dispersion-scaled for
#' quasi-Poisson) purely through what it stores in \code{mod$vcov}. Degrees of
#' freedom are \code{Inf}, the convention of every delta-method Wald path here.
#' Results and failure states are written to the caller's private environment.
#'
#' @param private_env The class's private environment (uses
#'   \code{cached_values}, \code{cache_nonestimable_estimate()},
#'   \code{cache_nonestimable_se()}, \code{clear_nonestimable_state()}).
#' @param mod The cached fit: a list with \code{b}, \code{X} (the exact fitting
#'   design) and, for an SE, \code{vcov}.
#' @param estimand \code{"marginal_mean_diff"} or \code{"marginal_ratio"}.
#' @param estimate_only If \code{TRUE}, cache and return only the point estimate.
#' @param reason_prefix Prefix of the non-estimable reason codes
#'   (\code{<prefix>_marginal_fit_unavailable}, \code{_point_unavailable},
#'   \code{_vcov_unavailable}, \code{_se_unavailable}).
#' @return The marginal point estimate (\code{NA_real_} if unavailable).
#' @keywords internal
#' @noRd
poisson_family_marginal_estimand_estimate = function(private_env, mod, estimand, estimate_only = FALSE, reason_prefix = "poisson") {
	reason = function(suffix) paste0(reason_prefix, "_marginal_", suffix)
	if (is.null(mod) || is.null(mod$b) || is.null(mod$X)) {
		private_env$cache_nonestimable_estimate(reason("fit_unavailable"))
		return(NA_real_)
	}
	functional = function(theta) poisson_family_marginal_functional(theta, mod$X, estimand)
	point = tryCatch(functional(mod$b), error = function(e) NA_real_)
	if (!is.finite(point)) {
		private_env$cache_nonestimable_estimate(reason("point_unavailable"))
		return(NA_real_)
	}
	private_env$cached_values$beta_hat_T = point
	if (estimate_only) return(point)
	if (is.null(mod$vcov)) {
		private_env$cache_nonestimable_se(reason("vcov_unavailable"))
		return(point)
	}
	dm = marginal_estimand_delta_se(mod$b, mod$vcov, functional)
	private_env$cached_values$df = Inf
	if (is.finite(dm$se) && dm$se >= 0) {
		private_env$cached_values$s_beta_hat_T = dm$se
		private_env$clear_nonestimable_state()
	} else {
		private_env$cache_nonestimable_se(reason("se_unavailable"))
	}
	point
}
