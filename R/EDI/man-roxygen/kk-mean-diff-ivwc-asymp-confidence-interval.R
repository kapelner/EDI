#' @description Computes a \eqn{1-\alpha} level frequentist confidence interval
#' for the compound IVWC (inverse-variance-weighted compound) mean-difference
#' estimator \eqn{\hat\beta_T}.
#'
#' @details
#' The point estimate combines two sub-estimates depending on which are
#' usable: the mean within-pair difference among matched subjects,
#' \eqn{\bar d}, with estimated variance \eqn{\widehat{\mathrm{Var}}(\bar
#' d)}, and the treated-minus-control difference in means among reservoir
#' (unmatched) subjects, \eqn{\bar r}, with estimated variance
#' \eqn{\widehat{\mathrm{Var}}(\bar r)}. When both are usable (at least 2
#' matched pairs and at least 2 treated/2 control reservoir subjects, with
#' finite positive variance estimates), they are combined by classical
#' inverse-variance weighting,
#' \deqn{\hat\beta_T = w^* \bar d + (1 - w^*)\, \bar r, \qquad w^* =
#'   \frac{\widehat{\mathrm{Var}}(\bar r)}{\widehat{\mathrm{Var}}(\bar r) +
#'   \widehat{\mathrm{Var}}(\bar d)},}
#' with combined variance the standard inverse-variance-pooled form
#' \eqn{\widehat{\mathrm{Var}}(\hat\beta_T) = \left(\widehat{\mathrm{Var}}(\bar
#' r)^{-1} + \widehat{\mathrm{Var}}(\bar d)^{-1}\right)^{-1} =
#' \widehat{\mathrm{Var}}(\bar r)\,\widehat{\mathrm{Var}}(\bar d) \big/
#' \left(\widehat{\mathrm{Var}}(\bar r) + \widehat{\mathrm{Var}}(\bar
#' d)\right)}. If only one of the two sub-estimates is usable (e.g. the
#' reservoir is empty or degenerate, or no pairs matched), \eqn{\hat\beta_T}
#' and its variance fall back to that sub-estimate alone. The compound
#' estimator is treated as asymptotically normal, so the interval is
#' \eqn{\hat\beta_T \pm z_{1-\alpha/2}\sqrt{\widehat{\mathrm{Var}}(\hat\beta_T)}}
#' (or a \eqn{t}-based critical value, depending on
#' \code{private$compute_z_or_t_ci_from_s_and_df}'s degrees-of-freedom
#' resolution).
#'
#' @param alpha The confidence level in the computed confidence
#'   interval is 1 - \code{alpha}. The default is 0.05.
#'
#' @return  A (1 - alpha)-sized frequentist confidence interval for the treatment effect
#'
