#' @description Computes the Haldane-Anscombe continuity-corrected log odds
#'   ratio \eqn{\log\left((n_{11}+0.5)(n_{00}+0.5) /
#'   \left((n_{10}+0.5)(n_{01}+0.5)\right)\right)} from the pooled
#'   \eqn{2\times2} table across all subjects (matched and reservoir
#'   combined) — see class documentation for the full combined-test model.
#'   On a matching design this estimate is not the quantity the exact
#'   confidence interval inverts (that uses only the discordant pairs and the
#'   reservoir), so it is not guaranteed to lie inside that interval.
#' @param estimate_only Ignored for this estimator (the exact statistic is
#'   always cheap to compute; there is no separate variance step to skip).
#' @return The treatment estimate.
