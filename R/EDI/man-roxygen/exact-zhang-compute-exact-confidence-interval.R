#' @description Computes an exact confidence interval for the log odds
#'   ratio by bisection-inverting the combined matched-pairs +
#'   Fisher-exact p-value (see class documentation for the full
#'   combination methodology).
#' @param alpha Significance level.
#' @param pval_epsilon Bisection tolerance for the inversion routine.
#' @param type Exact inference type; only \code{"Zhang"} (the default) is supported.
#' @param args_for_type Optional arguments keyed by exact type; recognizes
#'   \code{combination_method} (\code{"Fisher"} (default), \code{"Stouffer"},
#'   or \code{"min_p"}) inside the \code{"Zhang"} entry.
#' @return A confidence interval.
