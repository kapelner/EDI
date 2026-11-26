#' @description Computes a basic m-out-of-n bootstrap confidence interval.
#'
#' @param alpha Significance level. Default 0.05.
#' @param B Number of resamples. Default 501.
#' @param m Number of exchangeable units drawn with replacement. If
#'   \code{NULL} (default), use \code{floor(n_units^0.7)} subject to the
#'   validation bounds documented for
#'   \code{approximate_m_out_of_n_bootstrap_distribution_beta_hat_T()}.
#' @param type Confidence-interval type. Currently only \code{"basic"} is
#'   supported.
#' @param show_progress A flag indicating whether a progress bar should be
#'   displayed.
#' @param min_number_usable_samples Minimum number of finite resampled
#'   estimates required after filtering. Default 5.
#' @param bootstrap_type Optional empirical-resampling scheme.
#' @param scaling Scaling sequence for centered m-out-of-n pivots.
#' @param min_fraction_usable_samples Ratio estimands only (\code{InferenceIncidLogRegr},
#'   \code{InferenceIncidKKGEE}, \code{InferenceIncidModifiedPoisson},
#'   \code{InferenceIncidLogBinomial}, \code{InferenceCountPoisson}): minimum fraction of the
#'   \code{B} resamples that must be usable (not degenerate, fit not failed). Below it the method
#'   returns \code{NA} with reason \code{"m_out_of_n_too_few_usable_draws_fraction"} and one
#'   \code{edi_procedure_na_warning}. Default 0.8 (v1.0.6-TODO-164 / 269). Other classes ignore it.
#'
#' @details The \code{NULL} default is grounded in the standard m-out-of-n
#'   asymptotic condition \eqn{m \to \infty} and \eqn{m / n \to 0}. The
#'   minimum-volatility selector is available when a fixed deterministic
#'   exponent is too brittle for a specific estimator/design path.
#'
#' @return A length-2 numeric confidence interval, or
#'   \code{c(NA_real_, NA_real_)} if the path is non-estimable.
