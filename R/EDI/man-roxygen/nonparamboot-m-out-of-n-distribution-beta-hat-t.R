#' @description Creates the m-out-of-n bootstrap distribution of the
#'   treatment-effect estimate.
#'
#' @param B Number of resamples. Default 501.
#' @param m Number of exchangeable resampling units drawn with replacement.
#'   If \code{NULL} (default), use the deterministic intermediate-size rule
#'   \code{floor(n_units^0.7)}, where \code{n_units} is the number of
#'   exchangeable units used by the design (observations, clusters, pairs, or
#'   matched sets). The resolved value must satisfy
#'   \code{max(5, p_eff + 2) <= m <= floor(n_units / 2)}.
#' @param show_progress A flag indicating whether a progress bar should be
#'   displayed.
#' @param debug If \code{TRUE}, return distribution diagnostics in addition
#'   to the resampled estimates.
#' @param bootstrap_type Optional empirical-resampling scheme. See
#'   \code{approximate_bootstrap_distribution_beta_hat_T()}.
#' @param scaling Scaling sequence for centered m-out-of-n pivots. The
#'   default \code{"sqrt_n"} uses \code{sqrt(m)} for the m-sample
#'   distribution and converts back to the full-sample scale using
#'   \code{sqrt(n_units)}.
#' @param center Centering convention for diagnostics and cache keys.
#'
#' @details The default \code{m = NULL} rule is a cheap deterministic
#'   intermediate sequence: \eqn{m \to \infty} and \eqn{m / n \to 0}, as
#'   required by the standard m-out-of-n bootstrap asymptotic setup
#'   (Bickel, Gotze, and van Zwet; Bickel and Sakov). The exponent 0.7 is a
#'   pragmatic interior point in \eqn{(0, 1)}; it is not a silver-bullet
#'   optimal choice. Use \code{select_optimal_m_out_of_n_bootstrap()} for
#'   data-adaptive minimum-volatility selection.
#'
#' @return A numeric vector of bootstrap estimates, or when
#'   \code{debug = TRUE}, a diagnostic list.
#'
#' @references Bickel, P. J., Gotze, F., and van Zwet, W. R. (1997).
#'   Resampling fewer than n observations: gains, losses, and remedies for
#'   losses. \emph{Statistica Sinica}.
#'
#' @references Bickel, P. J. and Sakov, A. (2008). On the choice of m in
#'   the m out of n bootstrap. \emph{The Annals of Statistics}.
