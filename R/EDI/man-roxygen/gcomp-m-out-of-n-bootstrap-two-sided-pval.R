#' @description Computes an m-out-of-n bootstrap two-sided p-value for the treatment effect.
#' @param delta Null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of resamples.
#' @param m Resample size. See \code{InferenceNonParamBootstrap$compute_m_out_of_n_bootstrap_two_sided_pval}.
#' @param type P-value type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite resampled estimates required.
#' @param bootstrap_type Optional empirical-resampling scheme.
