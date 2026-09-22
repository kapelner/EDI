#' @description Reports the jackknife point-estimate as explicitly
#'   non-estimable for this compound Hodges-Lehmann estimator, rather than
#'   computing a leave-one-out jackknife. Deletion-based (jackknife)
#'   resampling of a Hodges-Lehmann/Wilcoxon-derived statistic is known to
#'   behave poorly — the median-of-Walsh-averages functional is not smooth
#'   enough for the delete-1 jackknife's linear-approximation machinery to
#'   be reliable at the small matched-pair/reservoir sample sizes typical of
#'   KK designs, and combining two already-jackknife-unstable sub-estimates
#'   compounds the problem. This method exists purely to record that
#'   unavailability (via \code{private$cache_nonestimable_estimate()}) rather
#'   than silently returning a misleading number; see
#'   \code{\link[EDI:InferenceJackknife]{InferenceJackknife}} for the shared
#'   jackknife contract this method participates in.
#' @param unit Deletion unit. Default \code{"auto"}.
