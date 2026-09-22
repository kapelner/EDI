#'
#' @description Computes the compound IVWC (inverse-variance-weighted
#' compound) mean-difference point estimate \eqn{\hat\beta_T}: the
#' inverse-variance-weighted combination \eqn{w^* \bar d + (1-w^*)\, \bar
#' r} of the matched-pair mean within-pair difference \eqn{\bar d} and the
#' reservoir treated-minus-control mean difference \eqn{\bar r}, falling
#' back to whichever of the two is usable if the other is not (see
#' \code{$compute_asymp_confidence_interval()} for the full weighting
#' formula and usability conditions).
#'
#' @return  The setting-appropriate (see description) numeric estimate of the treatment effect
#'
#' @param estimate_only If \code{TRUE}, compute only the point estimate
#'   \eqn{\hat\beta_T} and skip the variance-component computations needed
#'   for confidence intervals or p-values (faster when only the point
#'   estimate is needed).
