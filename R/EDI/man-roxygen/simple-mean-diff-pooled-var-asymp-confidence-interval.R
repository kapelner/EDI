#' @description Computes a \eqn{1-\alpha} level confidence interval for the
#'   simple (unadjusted) mean-difference treatment effect
#'   \eqn{\hat\beta_T = \bar y_T - \bar y_C}, using the classical
#'   \strong{pooled equal-variance} Student's t-test formula (unlike
#'   \code{\link[EDI:InferenceAllSimpleAverageDiff]{InferenceAllSimpleAverageDiff}}'s
#'   Welch unequal-variance version): the pooled variance estimate
#'   \eqn{s_p^2 = \left((n_T-1)s_T^2 + (n_C-1)s_C^2\right) / (n_T+n_C-2)}
#'   gives standard error \eqn{\widehat{\mathrm{SE}}(\hat\beta_T) =
#'   s_p\sqrt{1/n_T + 1/n_C}} with exact degrees of freedom \eqn{n_T + n_C -
#'   2}; the interval is \eqn{\hat\beta_T \pm t_{\mathrm{df}, 1-\alpha/2}\,
#'   \widehat{\mathrm{SE}}(\hat\beta_T)}. Assumes equal population
#'   variances in the two arms — use
#'   \code{\link[EDI:InferenceAllSimpleAverageDiff]{InferenceAllSimpleAverageDiff}}
#'   instead when that assumption is doubtful. Requires at least 2
#'   observations per arm; otherwise returns \code{c(NA, NA)}. See
#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
#'   asymptotic confidence-interval contract this participates in.
#' @param alpha Confidence level.
