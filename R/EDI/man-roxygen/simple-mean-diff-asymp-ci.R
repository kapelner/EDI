#' @description Computes a \eqn{1-\alpha} level confidence interval for the
#'   simple (unadjusted) mean-difference treatment effect
#'   \eqn{\hat\beta_T = \bar y_T - \bar y_C}, using \strong{Welch's
#'   unequal-variance} formula: standard error
#'   \eqn{\widehat{\mathrm{SE}}(\hat\beta_T) = \sqrt{s_T^2/n_T + s_C^2/n_C}}
#'   (sample variances \eqn{s_T^2}, \eqn{s_C^2} computed separately per arm,
#'   not pooled) with Satterthwaite-Welch degrees of freedom
#'   \eqn{\mathrm{df} = (s_T^2/n_T + s_C^2/n_C)^2 \big/ \left(\frac{(s_T^2/n_T)^2}{n_T-1}
#'   + \frac{(s_C^2/n_C)^2}{n_C-1}\right)}; the interval is
#'   \eqn{\hat\beta_T \pm t_{\mathrm{df}, 1-\alpha/2}\,\widehat{\mathrm{SE}}(\hat\beta_T)}.
#'   Requires at least 2 observations per arm; otherwise the standard error
#'   and interval are \code{NA}. See
#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared
#'   asymptotic confidence-interval contract this delegates to.
#' @param alpha Confidence level.
