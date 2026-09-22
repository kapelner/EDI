#' @description Computes the simple (unadjusted) mean-difference point
#'   estimate \eqn{\hat\beta_T = \bar y_T - \bar y_C}, the difference in
#'   sample means between the treated and control arms. \code{NA} if
#'   either arm has zero observations. See
#'   \code{\link[EDI:InferenceMLEorKMSummaryTable]{InferenceMLEorKMSummaryTable}}
#'   for the shared estimate-contract this participates in.
#'
#' @return    The setting-appropriate (see description) numeric estimate of the treatment effect
#'
#' @param estimate_only If TRUE, skip variance component calculations.
