#' @description Delegates to the genuine rank-based
#'   \code{$compute_asymp_two_sided_pval()} rather than the generic
#'   Wald-component z/t formula.
#'
#'   Fixed 2026-09-06: this class did not override
#'   \code{compute_wald_two_sided_pval}, so it fell through to the
#'   composed \code{Wald} component's generic
#'   \code{(estimate - delta) / se} formula built from
#'   \code{compute_estimate()} (the Hodges-Lehmann median-of-pairwise-
#'   differences) and \code{get_standard_error()}. On heavily tied,
#'   small-integer count/ordinal data the Hodges-Lehmann estimate lands
#'   on exactly 0 far more often than a continuous estimator would, so
#'   the Wald statistic came out exactly \code{0/se = 0} regardless of
#'   \code{se}, forcing \code{p = 1} deterministically (observed:
#'   pinned at 1 in ~75-98% of runs). The rank-based
#'   \code{compute_asymp_two_sided_pval()} does not have this failure
#'   mode.
#' @param delta Null treatment effect. Default 0.
