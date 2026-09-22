#' @description Computes a centered PRW subsampling two-sided p-value.
#'
#' @param delta Null treatment effect. Default 0.
#' @param B Number of subsamples. Default 501.
#' @param b Number of exchangeable units drawn without replacement. If
#'   \code{NULL} (default), use \code{floor(n_units^0.7)} subject to the
#'   validation bounds documented for
#'   \code{approximate_subsampling_distribution_beta_hat_T()}.
#' @param type P-value type. Currently only \code{"centered"} is supported.
#' @param show_progress A flag indicating whether a progress bar should be
#'   displayed.
#' @param min_number_usable_samples Minimum number of finite subsampled
#'   estimates required after filtering. Default 5.
#' @param subsampling_type Optional empirical-resampling scheme.
#' @param scaling Scaling sequence for centered subsampling pivots.
#'
#' @details The default \code{b = NULL} follows the intermediate-sequence
#'   convention from the Politis/Romano/Wolf subsampling literature:
#'   \eqn{b \to \infty} and \eqn{b / n \to 0}. The deterministic exponent
#'   0.7 is a first-pass default; for unstable paths prefer the
#'   minimum-volatility selector.
#'
#' @return A numeric two-sided p-value, or \code{NA_real_} if the path is
#'   non-estimable.
