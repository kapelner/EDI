#' @description Computes the Haldane-Anscombe continuity-corrected
#'   matched-pair log odds ratio \eqn{\log\left((d_+ + 0.5)/(d_- + 0.5)\right)}
#'   from the discordant matched-pair counts (see class documentation for
#'   the full model). \code{NA} if there are no matched pairs.
#' @param estimate_only Ignored for this estimator (the exact statistic is
#'   always cheap to compute; there is no separate variance step to skip).
#' @return The treatment estimate.
