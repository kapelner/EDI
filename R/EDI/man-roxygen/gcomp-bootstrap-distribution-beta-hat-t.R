#' @description Uses the shared nonparametric bootstrap distribution contract; see
#'   \code{\link[EDI:InferenceNonParamBootstrap]{InferenceNonParamBootstrap}}.
#' @param B  					Number of bootstrap samples.
#' @param show_progress Whether to show a progress bar.
#' @param debug         Whether to return diagnostics.
#' @param bootstrap_type Optional resampling scheme.
#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
#' @return A numeric vector of bootstrap estimates.
