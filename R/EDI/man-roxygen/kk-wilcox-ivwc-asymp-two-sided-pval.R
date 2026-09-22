#' @description Compute the KK Wilcoxon compound two-sided p-value testing
#'   \eqn{H_0: \beta_T = \code{delta}}, from the same asymptotically-normal
#'   compound estimate/variance (\eqn{z = (\hat\beta_T -
#'   \code{delta})/\widehat{\mathrm{SE}}(\hat\beta_T)}) that
#'   \code{$compute_asymp_confidence_interval()} inverts to form its
#'   interval — see that method's documentation, and
#'   \code{$compute_estimate()}, for the compound Hodges-Lehmann estimator's
#'   full formula. Only \code{delta = 0} is currently supported: a non-zero
#'   null shift raises an error (when assertions are enabled) rather than
#'   testing it, because the underlying Wilcoxon tests' null-shift handling
#'   has not been extended to the compound combined estimator. See related
#'   simple Wilcoxon behavior in
#'   \code{\link[EDI:InferenceAllSimpleWilcox]{InferenceAllSimpleWilcox}}.
#' @param delta The null difference to test against. For any
#'   treatment effect at all this is set to zero (the default).
