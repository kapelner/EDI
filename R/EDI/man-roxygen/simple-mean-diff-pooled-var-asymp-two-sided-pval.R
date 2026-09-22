#' @description Computes a two-sided pooled-variance Student's t-test
#'   p-value testing \eqn{H_0: \beta_T = \code{delta}}, from the same
#'   pooled standard error and exact \eqn{n_T+n_C-2} degrees of freedom
#'   used by \code{$compute_asymp_confidence_interval()} — see that
#'   method's documentation for the full formula. See
#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
#'   asymptotic two-sided p-value contract this participates in.
#' @param delta Null treatment effect value.
