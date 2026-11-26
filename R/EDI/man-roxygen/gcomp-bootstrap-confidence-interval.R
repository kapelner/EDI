#' @description Computes a bootstrap confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of bootstrap samples.
#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
#' @param na.rm Whether to remove non-finite bootstrap replicates.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
