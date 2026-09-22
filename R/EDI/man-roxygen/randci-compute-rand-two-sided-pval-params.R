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
#' @param type Optional incidence-specific exact randomization type.
#' @param args_for_type Optional arguments keyed by \code{type}.
#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
#' @return A two-sided p-value.
