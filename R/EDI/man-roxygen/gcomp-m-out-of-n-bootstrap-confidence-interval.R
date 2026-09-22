#' @description Computes an m-out-of-n bootstrap confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of resamples.
#' @param m Resample size. See \code{InferenceNonParamBootstrap$compute_m_out_of_n_bootstrap_confidence_interval}.
#' @param type Confidence-interval type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite resampled estimates required.
#' @param bootstrap_type Optional empirical-resampling scheme.
