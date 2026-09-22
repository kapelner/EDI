#' @description Computes a two-sided Welch's t-test p-value testing
#'   \eqn{H_0: \beta_T = \code{delta}}, from the same Welch
#'   unequal-variance standard error and Satterthwaite-Welch degrees of
#'   freedom used by \code{$compute_asymp_confidence_interval()} — see that
#'   method's documentation for the full formula. See
#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
#'   asymptotic two-sided p-value contract this delegates to.
#' @param delta Null treatment effect value.
