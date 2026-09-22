#' @description Reports the jackknife bias-correction estimate as
#'   non-estimable for this Wilcoxon compound estimator, for the same
#'   reason as \code{$compute_jackknife_estimate()} (the Hodges-Lehmann
#'   functional is not smooth enough for the delete-1 jackknife); see
#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
#'   jackknife contract.
#' @param unit Deletion unit. Default \code{"auto"}.
