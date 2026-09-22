#' @description Wilcoxon rank-sum test two-sided p-value testing
#'   \eqn{H_0: \beta_T = \code{delta}} (via \code{stats::wilcox.test(yT, yC -
#'   delta, exact = FALSE)$p.value}, the normal approximation with
#'   continuity correction) — a genuine rank-based test, \strong{not} a
#'   Wald test built from the Hodges-Lehmann estimate and its standard
#'   error, despite living alongside \code{$compute_asymp_confidence_interval()}
#'   in this class's "asymptotic" method family. For \code{delta != 0}, the
#'   control arm's values are shifted by \code{delta} before testing, so the
#'   test checks whether \eqn{y_T} and \eqn{y_C + \code{delta}} come from
#'   the same distribution.
#' @param delta Null treatment effect. Default 0.
