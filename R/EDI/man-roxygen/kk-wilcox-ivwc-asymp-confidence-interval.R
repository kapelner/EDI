#' @description Computes a \eqn{1-\alpha} level confidence interval for the
#'   compound Hodges-Lehmann treatment effect estimator. Although each
#'   sub-estimate is itself derived from a non-parametric rank test, the
#'   inverse-variance-weighted \strong{combination} \eqn{\hat\beta_T} (see
#'   \code{$compute_estimate()} for the full formula) is treated as
#'   asymptotically normal, so the interval is
#'   \eqn{\hat\beta_T \pm z_{1-\alpha/2}\sqrt{\widehat{\mathrm{Var}}(\hat\beta_T)}}
#'   (or a \eqn{t}-based critical value, depending on
#'   \code{private$compute_z_or_t_ci_from_s_and_df}'s degrees-of-freedom
#'   resolution).
#' @param alpha The confidence level in the computed confidence
#'   interval is 1 - \code{alpha}. The default is 0.05.
