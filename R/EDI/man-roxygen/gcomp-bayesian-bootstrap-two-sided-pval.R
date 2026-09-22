#' @description Computes a Bayesian-bootstrap two-sided p-value for the treatment effect.
#' @param delta The null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of Bayesian-bootstrap samples.
#' @param type Bayesian-bootstrap p-value type. See \code{InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval}.
#' @param na.rm Whether to remove non-finite bootstrap replicates.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples required.
#' @param weighting_unit_type Optional resampling unit override.
