#' @param r Number of randomization vectors.
#' @param delta Null treatment effect value.
#' @param transform_responses Response transformation to apply during the test. For
#'   survival responses the default \code{"log"} multiplies the recorded times of the
#'   units treated under each reference allocation by \eqn{e^\delta}, event and
#'   censoring times alike, with censoring indicators unchanged -- the rank-based
#'   AFT residual construction (Tsiatis 1990; Wei, Ying and Lin 1990; Jin, Lin, Wei
#'   and Ying 2003); see \code{compute_rand_confidence_interval()} for the assumptions.
#' @param na.rm Whether to remove non-finite simulated statistics.
#' @param show_progress Whether to show progress.
#' @param permutations Optional pre-generated assignment draws.
#' @param type \code{NULL} (default) or \code{"Zhang"}, the only accepted value.
#'   \code{NULL} computes the p-value from the randomization draws. \code{"Zhang"}
#'   instead returns the Zhang exact combined test (see
#'   \code{\link[EDI:InferenceIncidExactZhang]{InferenceIncidExactZhang}}); it applies
#'   only to incidence responses on a Bernoulli or matching design. For any other
#'   response or design, a non-\code{NULL} \code{type} is an error; other strings
#'   (for example \code{"Fisher"} or \code{"exact"}) are rejected.
#' @param args_for_type \code{NULL} or a list keyed by \code{type}, used only with
#'   \code{type = "Zhang"}: \code{list(Zhang = list(combination_method = "Stouffer"))},
#'   where \code{combination_method} is \code{"Fisher"} (default), \code{"Stouffer"}
#'   or \code{"min_p"}.
#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
#' @param alternative \code{"two.sided"} (default), \code{"greater"} or \code{"less"};
#'   use \code{"greater"} for a non-negative, one-tailed-by-construction statistic.
#'   The observed allocation counts as one of the \eqn{B} finite draws: two-sided is
#'   \eqn{\min(1, 2(1 + \min(b_{\ge}, b_{\le}))/(1 + B))}{min(1, 2 (1 + min(b_ge, b_le)) / (1 + B))}
#'   (doubled smaller tail, smallest value \eqn{2/(B + 1)}); \code{"greater"} is
#'   \eqn{(1 + b_{\ge})/(1 + B)}{(1 + b_ge) / (1 + B)} (smallest \eqn{1/(B + 1)}), where
#'   \eqn{b_{\ge}}{b_ge} and \eqn{b_{\le}}{b_le} count the draws at least as large / as
#'   small as the observed statistic. This exact Monte Carlo p-value (Phipson and Smyth
#'   2010) has size at most \eqn{\alpha} and is never 0; the realized allocation is never
#'   counted twice (a seeded design's replay of it is skipped, a full enumeration's copy
#'   removed); see
#'   \code{InferenceRand$compute_rand_two_sided_pval()}.
