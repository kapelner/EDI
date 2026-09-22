#' @description Returns the \strong{Hodges-Lehmann} estimate of location
#'   shift: the median of all pairwise treatment-minus-control differences
#'   \eqn{y_{T,i} - y_{C,j}} (via \code{wilcox_hl_point_estimate_cpp()}), the
#'   standard point estimate associated with the Wilcoxon rank-sum test.
#'   Robust to outliers and does not assume normality or equal variances.
#' @param estimate_only If TRUE, skip variance component calculations.
