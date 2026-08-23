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
