#' @description Computes a bootstrap two-sided p-value for the treatment effect.
#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of bootstrap samples.
#' @param type Bootstrap p-value type. See \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
#' @param na.rm Whether to remove non-finite bootstrap replicates.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
#' @param min_fraction_usable_samples Minimum fraction of the \code{B} replicates that must be
#'   finite when \code{na.rm = TRUE}. Default 0.95. See
#'   \code{InferenceNonParamBootstrap$compute_bootstrap_two_sided_pval}.
#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
#'   (default) keeps the design's original imputation in every resample, \code{TRUE} re-runs it per
#'   resample. See \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
