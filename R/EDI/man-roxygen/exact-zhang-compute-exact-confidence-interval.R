#' @description Computes an exact confidence interval for the log odds
#'   ratio by inverting the combined matched-pairs + Fisher-exact p-value
#'   (see class documentation for the full combination methodology). The
#'   combined p-value is not monotone in the log odds ratio, so the set it
#'   accepts can have gaps; the interval returned is the convex hull of that
#'   set, the smallest interval containing every log odds ratio the test does
#'   not reject (Blaker 2000; Fay 2010). On a matching design the interval is
#'   not guaranteed to contain \code{compute_estimate()}, which uses the
#'   pooled table over all subjects.
#' @param alpha Significance level.
#' @param pval_epsilon Bisection tolerance for the inversion routine, on the
#'   log odds ratio scale (capped at \code{1e-6}).
#' @param type Exact inference type; only \code{"Zhang"} (the default) is supported.
#' @param args_for_type Optional arguments keyed by exact type; recognizes
#'   \code{combination_method} (\code{"Fisher"} (default), \code{"Stouffer"},
#'   or \code{"min_p"}) inside the \code{"Zhang"} entry.
#' @return A confidence interval. When the matched pairs and the reservoir
#'   point to incompatible effects, the combined test can reject every log
#'   odds ratio at level \code{alpha}; the confidence set is then empty and
#'   both bounds are \code{NA}, with the reason
#'   \code{"exact_ci_empty_acceptance_set"} recorded and an
#'   \code{edi_procedure_na_warning}.
