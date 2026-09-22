#' @description Computes a bootstrap confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of bootstrap samples.
#' @param type Bootstrap CI type. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
#' @param na.rm Whether to remove non-finite bootstrap replicates.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
