#' @description Computes a two-sided \strong{Wald} p-value for the compound
#' IVWC mean-difference estimator \eqn{\hat\beta_T} testing
#' \eqn{H_0: \beta_T = \code{delta}}, using the same asymptotically-normal
#' point estimate and standard error (\eqn{z = (\hat\beta_T -
#' \code{delta})/\widehat{\mathrm{SE}}(\hat\beta_T)}) that
#' \code{$compute_asymp_confidence_interval()} inverts to form its interval
#' — see that method's documentation for the full inverse-variance-weighted
#' combination formula. This class has no likelihood tier
#' (\code{likelihood_tier = "none"}), so no score, likelihood-ratio, or
#' gradient test is available here; this is a plain Wald test, not a
#' likelihood-backed one.
#'
#' @param delta   The null difference to test against. For any treatment effect at all this is
#'   set to zero (the default).
#'
#' @return  The approximate frequentist p-value
#'
