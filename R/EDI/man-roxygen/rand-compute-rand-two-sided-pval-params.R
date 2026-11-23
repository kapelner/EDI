#' @description Computes a randomization-based p-value.
#' @param r  	Number of randomization vectors.
#' @param delta  				Null difference.
#' @param transform_responses  Transformation.
#' @param na.rm 				Remove NAs.
#' @param show_progress  	Show progress.
#' @param permutations  	Pre-computed permutations.
#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
#' @param alternative \code{"two.sided"} (default), \code{"greater"} or \code{"less"}; use
#'   \code{"greater"} for a non-negative, one-tailed-by-construction statistic.
#'   The observed allocation counts as one of the \eqn{B} finite draws: two-sided is
#'   \eqn{\min(1, 2(1 + \min(b_{\ge}, b_{\le}))/(1 + B))}{min(1, 2 (1 + min(b_ge, b_le)) / (1 + B))}
#'   (doubled smaller tail, smallest value \eqn{2/(B + 1)}); \code{"greater"} is
#'   \eqn{(1 + b_{\ge})/(1 + B)}{(1 + b_ge) / (1 + B)} (smallest \eqn{1/(B + 1)}), where
#'   \eqn{b_{\ge}}{b_ge} and \eqn{b_{\le}}{b_le} count the draws at least as large / as
#'   small as the observed statistic. This exact Monte Carlo p-value (Phipson and Smyth
#'   2010) has size at most \eqn{\alpha} and is never 0; see
#'   \code{InferenceRand$compute_rand_two_sided_pval()}.
#' @return 	Randomization p-value.
