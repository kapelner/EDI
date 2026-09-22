#' @description Override to avoid O(n^2) per-resample HL computation during the bootstrap warm-start
#' inside compute_rand_confidence_interval. The asymptotic MLE CI is a perfectly
#' adequate starting bound for the bisection and is computed in O(1).
#' @param alpha  				The confidence level. Default is 0.05.
#' @param ... 					Additional arguments passed to super.
