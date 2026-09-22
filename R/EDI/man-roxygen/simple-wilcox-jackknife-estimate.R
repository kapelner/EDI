#' @description Reports the jackknife point-estimate as explicitly
#'   non-estimable for this Hodges-Lehmann estimator, rather than computing
#'   a leave-one-out jackknife: the median-of-pairwise-differences
#'   functional is not smooth enough for the delete-1 jackknife's
#'   linear-approximation machinery to be reliable. This method exists
#'   purely to record that unavailability (via
#'   \code{private$cache_nonestimable_estimate()}) rather than silently
#'   returning a misleading number; see
#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
#'   jackknife contract this method participates in.
#' @param unit Deletion unit. Default \code{"auto"}.
