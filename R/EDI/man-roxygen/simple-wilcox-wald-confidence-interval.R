#' @description Delegates to the genuine rank-based
#'   \code{$compute_asymp_confidence_interval()} rather than the
#'   generic Wald normal-approximation interval, for the same reason
#'   as \code{compute_wald_two_sided_pval} above.
#'
#'   Fixed 2026-09-06: the generic Wald component's normal-approximation
#'   interval is built from \code{get_standard_error()}, which this
#'   class derives by back-solving \code{se = (ci[2]-ci[1]) /
#'   (2*1.96)} from \code{stats::wilcox.test()}'s own asymptotic CI
#'   width. Under heavy ties, that root search can converge to a
#'   numerically near-zero-width interval as a search artifact, not a
#'   real sampling-uncertainty statement; that spurious near-zero SE
#'   then produced a near-\code{[0,0]} Wald interval (observed in
#'   over 1,200 rows of comprehensive-results data). The rank-based
#'   \code{compute_asymp_confidence_interval()} inverts the rank-sum
#'   test directly and does not go through this derived SE at all.
#' @param alpha Significance level. Default 0.05.
