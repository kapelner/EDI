#' @description Computes the simple (unadjusted) mean-difference point
#'   estimate \eqn{\hat\beta_T = \bar y_T - \bar y_C}, the difference in
#'   sample means between the treated and control arms. \code{NA} if
#'   either arm has zero observations. See
#'   \code{\link[EDI:InferenceMLEorKMSummaryTable]{InferenceMLEorKMSummaryTable}}
#'   for the shared estimate-contract this participates in.
#'
#' @return    The difference in sample means (treated minus control) as a single
#'   number, or \code{NA_real_} if either arm has no observations.
#'
#' @param estimate_only If TRUE, skip variance component calculations.
