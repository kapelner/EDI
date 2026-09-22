#' @description Creates the Politis/Romano/Wolf subsampling distribution of
#'   the treatment-effect estimate.
#'
#' @param B Number of subsamples. Default 501.
#' @param b Number of exchangeable units drawn without replacement. If
#'   \code{NULL} (default), use the deterministic intermediate-size rule
#'   \code{floor(n_units^0.7)}, where \code{n_units} is the number of
#'   exchangeable units used by the design (observations, clusters, pairs, or
#'   matched sets). The resolved value must satisfy
#'   \code{max(5, p_eff + 2) <= b <= floor(n_units / 2)}.
#' @param show_progress A flag indicating whether a progress bar should be
#'   displayed.
#' @param debug If \code{TRUE}, return distribution diagnostics in addition
#'   to the subsampled estimates.
#' @param subsampling_type Optional empirical-resampling scheme. See
#'   \code{approximate_bootstrap_distribution_beta_hat_T()}.
#' @param scaling Scaling sequence for centered subsampling pivots. The
#'   default \code{"sqrt_n"} uses \code{sqrt(b)} for the subsample
#'   distribution and converts back to the full-sample scale using
#'   \code{sqrt(n_units)}.
#' @param center Centering convention for diagnostics and cache keys.
#'
#' @details The default \code{b = NULL} rule is a cheap deterministic
#'   intermediate sequence: \eqn{b \to \infty} and \eqn{b / n \to 0}, as
#'   required by the Politis, Romano, and Wolf subsampling framework. The
#'   exponent 0.7 is a pragmatic interior point in \eqn{(0, 1)}; it is not a
#'   universal optimum. Use \code{select_optimal_b_subsampling()} for
#'   data-adaptive minimum-volatility selection.
#'
#' @return A numeric vector of subsampled estimates, or when
#'   \code{debug = TRUE}, a diagnostic list.
#'
#' @references Politis, D. N., Romano, J. P., and Wolf, M. (1999).
#'   \emph{Subsampling}. Springer.
