#' @description Computes the log of the (conditional MLE, or common-odds-ratio
#'   if stratified) odds ratio from \code{\link[stats]{fisher.test}} or
#'   \code{\link[stats]{mantelhaen.test}} (see class documentation for which
#'   applies and why).
#' @param estimate_only Ignored for this estimator (the exact statistic is
#'   always cheap to compute; there is no separate variance step to skip).
#' @return The treatment estimate.
