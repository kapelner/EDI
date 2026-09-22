#' @description Computes a centered m-out-of-n bootstrap two-sided p-value.
#'
#' @param delta Null treatment effect. Default 0.
#' @param B Number of resamples. Default 501.
#' @param m Number of exchangeable units drawn with replacement. If
#'   \code{NULL} (default), use \code{floor(n_units^0.7)} subject to the
#'   validation bounds documented for
#'   \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()}.
#' @param type P-value type. Currently only \code{"centered"} is supported.
#' @param show_progress A flag indicating whether a progress bar should be
#'   displayed.
#' @param min_number_usable_samples Minimum number of finite resampled
#'   estimates required after filtering. Default 5.
#' @param bootstrap_type Optional empirical-resampling scheme.
#' @param scaling Scaling sequence for centered m-out-of-n pivots.
#'
#' @details The default \code{m = NULL} follows the intermediate-sequence
#'   convention from the m-out-of-n bootstrap literature:
#'   \eqn{m \to \infty} and \eqn{m / n \to 0}. The deterministic exponent
#'   0.7 is a first-pass default; for unstable paths prefer the
#'   minimum-volatility selector.
#'
#' @return A numeric two-sided p-value, or \code{NA_real_} if the path is
#'   non-estimable.
