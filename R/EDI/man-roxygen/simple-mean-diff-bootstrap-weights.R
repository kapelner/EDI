#' @description Recomputes the simple mean-difference estimate under
#'   subject/block bootstrap weights (used by the Bayesian bootstrap and
#'   related weighted-resampling machinery — see
#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}).
#'   The weighted point estimate is \eqn{\hat\beta_T = \bar y_T^w - \bar
#'   y_C^w}, weighted arm means \eqn{\bar y_T^w = \sum_i r_i y_i \mathbb{1}[w_i=1]
#'   / \sum_i r_i \mathbb{1}[w_i=1]} (and analogously for control), where
#'   \eqn{r_i} are the expanded row weights. Unless \code{estimate_only =
#'   TRUE}, the standard error uses a \strong{weighted, effective-sample-size}
#'   Welch formula: \eqn{n_{\mathrm{eff}} = (\sum r_i)^2 / \sum r_i^2}
#'   (the usual Kish effective-sample-size correction for unequal weights)
#'   in place of the raw \eqn{n} in both the per-arm weighted variance
#'   denominator and the Satterthwaite-Welch degrees-of-freedom formula (see
#'   \code{$compute_asymp_confidence_interval()} for the unweighted version
#'   of the same formula). Rows with non-finite or non-positive weight, or a
#'   non-finite response, are dropped before computing; if no rows survive,
#'   returns \code{NA} with all cached variance components set to \code{NA}.
#' @param subject_or_block_weights Row weights for the bootstrap sample.
#' @param estimate_only If TRUE, skip variance calculations.
