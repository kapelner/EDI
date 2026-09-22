#' @description Computes a bootstrap two-sided p-value for the treatment effect.
#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of bootstrap samples.
#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
#' @param na.rm Whether to remove non-finite bootstrap replicates.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
