#' @description Recomputes the simple mean-difference estimate under
#'   subject/block bootstrap weights (used by the Bayesian bootstrap and
#'   related weighted-resampling machinery — see
#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}).
#'   The weighted point estimate is \eqn{\hat\beta_T = \bar y_T^w - \bar
#'   y_C^w}, weighted arm means \eqn{\bar y_T^w = \sum_i r_i y_i \mathbb{1}[w_i=1]
#'   / \sum_i r_i \mathbb{1}[w_i=1]} (and analogously for control), where
#'   \eqn{r_i} are the expanded row weights. Unless \code{estimate_only =
#'   TRUE}, the standard error treats the bootstrap weights as frequency
#'   weights. Within each arm, with total weight \eqn{W = \sum r_i} and
#'   weighted residual sum of squares \eqn{Q = \sum r_i(y_i - \bar y_w)^2},
#'   the variance contribution is \eqn{Q / [W(W - 1)]}; the
#'   Satterthwaite-Welch degrees of freedom likewise use \eqn{W - 1}.
#'   This reduces exactly to the ordinary Welch formula for unit weights.
#'   Rows with non-finite or non-positive weight, or a
#'   non-finite response, are dropped before computing; if no rows survive,
#'   returns \code{NA} with all cached variance components set to \code{NA}.
#' @param subject_or_block_weights Row weights for the bootstrap sample.
#' @param estimate_only If TRUE, skip variance calculations.
