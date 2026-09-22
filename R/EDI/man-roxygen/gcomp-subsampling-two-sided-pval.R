#' @description Computes a PRW subsampling two-sided p-value for the treatment effect.
#' @param delta Null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of subsamples.
#' @param b Subsample size. See \code{InferenceNonParamBootstrap$compute_subsampling_two_sided_pval}.
#' @param type P-value type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite subsampled estimates required.
#' @param subsampling_type Optional empirical-resampling scheme.
