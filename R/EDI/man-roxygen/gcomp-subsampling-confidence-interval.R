#' @description Computes a PRW subsampling confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of subsamples.
#' @param b Subsample size. See \code{InferenceNonParamBootstrap$compute_subsampling_confidence_interval}.
#' @param type Confidence-interval type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite subsampled estimates required.
#' @param subsampling_type Optional empirical-resampling scheme.
